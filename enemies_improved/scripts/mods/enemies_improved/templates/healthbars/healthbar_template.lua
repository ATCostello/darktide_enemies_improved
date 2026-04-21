local mod = get_mod("enemies_improved")

local HudHealthBarLogic = require("scripts/ui/hud/elements/hud_health_bar_logic")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local BreedQueries = require("scripts/utilities/breed_queries")
local minion_breeds = BreedQueries.minion_breeds_by_name()

local template = {}
local fs = mod.frame_settings

local size = { fs.hb_size_width, fs.hb_size_height }

local min_size = { 0, 0 }

template.size = size

template.min_size = min_size
template.name = "enemy_healthbar"
template.unit_node = "root_point"
template.position_offset = { 0, 0, fs.hb_y_offset }

template.check_line_of_sight = fs.check_line_of_sight
template.max_distance = fs.draw_distance
template.screen_clamp = false

template.bar_settings = {
	alpha_fade_delay = 1,
	alpha_fade_duration = 0.6,
	alpha_fade_min_value = 50,
	animate_on_health_increase = true,
	bar_spacing = 0,
	duration_health = 0.1,
	duration_health_ghost = 1.5,
	health_animation_threshold = 0.1,
}

template.evolve_distance = 1

template.scale_settings = {
	scale_from = 0.4,
	scale_to = 1,
	distance_max = 25,
	distance_min = 5,
}

template.fade_settings = {
	default_fade = 1,
	fade_from = 0,
	fade_to = 1,
	distance_max = template.max_distance,
	distance_min = template.max_distance - template.evolve_distance * 2,
	easing_function = math.easeCubic,
}

-----------------------------------------------------------------------
-- Cached locals / helpers
-----------------------------------------------------------------------

local ScriptUnit_extension = ScriptUnit.extension
local ScriptUnit_has_extension = ScriptUnit.has_extension
local Managers_state = Managers.state
local Managers_player = Managers.player
local Color_color = Color
local Vector3 = Vector3
local Vector3Box = Vector3Box

local math_clamp = math.clamp
local math_lerp = math.lerp
local math_min = math.min
local math_max = math.max
local math_random = math.random
local math_sqrt = math.sqrt
local math_floor = math.floor

local string_format = string.format
local table_remove = table.remove
local table_clone = table.clone
local next = next

-----------------------------------------------------------------------
-- Damage numbers config
-----------------------------------------------------------------------

local damage_number_types = table.enum("readable", "floating", "flashy")
template.show_dps = fs.hb_show_dps
template.skip_damage_from_others = true

local hb_damage_number_type = fs.hb_damage_number_type

template.damage_number_settings = {
	add_numbers_together_timer = 1,
	add_numbers_together_timer_flashy = 0,
	crit_color = "orange",
	crit_hit_size_scale = 1.5,
	default_color = "white",
	default_font_size = 16 * fs.text_scale,
	dps_font_size = 22 * fs.text_scale,
	dps_y_offset = -36,
	duration = fs.damage_number_duration,
	expand_bonus_scale = 4,
	expand_duration = 0.2,
	fade_delay = 2,
	first_hit_size_scale = 1.2,
	has_taken_damage_timer_remove_after_time = 5,
	has_taken_damage_timer_y_offset = 34,
	hundreds_font_size = 16 * fs.text_scale,
	max_float_y = 20,
	shrink_duration = 0.5,
	visibility_delay = 2,
	weakspot_color = "yellow",
	x_offset = 0,
	x_offset_between_numbers = 14 * fs.text_scale * 3,
	y_offset = 0,
	flashy_font_size_dmg_multiplier = { 1, 1.5 },
	flashy_font_size_dmg_scale_range = { 50, 300 },
}

local previous_health = {}
local last_damaged_time = {}
local peak_cluster_max_by_rep = {}

local armor_type_string_lookup = {
	armored = "loc_weapon_stats_display_armored",
	berserker = "loc_weapon_stats_display_berzerker",
	disgustingly_resilient = "loc_weapon_stats_display_disgustingly_resilient",
	resistant = "loc_glossary_armour_type_resistant",
	super_armor = "loc_weapon_stats_display_super_armor",
	unarmored = "loc_weapon_stats_display_unarmored",
}

mod.latest_damaged_enemies = {}

-----------------------------------------------------------------------
-- Damage number dispatcher
-----------------------------------------------------------------------

local damage_number_functions =
	mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/templates/healthbars/damage_numbers")
damage_number_functions.init(template)

template.damage_number_function = function(pass, ui_renderer, ui_style, ui_content, position, size)
	damage_number_functions.damage_number_function(pass, ui_renderer, ui_style, ui_content, position, size)
end

template.readable_damage_number_function = function(pass, ui_renderer, ui_style, ui_content, position, size)
	damage_number_functions.readable_damage_number_function(pass, ui_renderer, ui_style, ui_content, position, size)
end

-----------------------------------------------------------------------
-- Widget definition
-----------------------------------------------------------------------
local healthbar_template_definition =
	mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/templates/healthbars/healthbar_template_definition")

template.create_widget_defintion = function(template, scenegraph_id)
	return healthbar_template_definition.create_definition(template, scenegraph_id)
end
-----------------------------------------------------------------------
-- Lifecycle
-----------------------------------------------------------------------

local function is_weakspot(breed, zone)
	local t = breed and breed.hit_zone_weakspot_types
	return t and t[zone]
end

local function format_number(n)
	return tostring(n):gsub("%.", ",")
end

local function get_text_option(content, option)
	if not option or option == "nothing" then
		return ""
	end

	local breed_type = content._breed_type or "enemy"
	local breed = content.breed

	if option == "enemy_type" then
		return mod:localize(breed_type) or ""
	elseif option == "enemy_name" then
		if content.in_horde_cluster then
			local cluster_string = Localize(breed.display_name) .. " " .. mod:localize("horde")

			if content.cluster_count then
				cluster_string = cluster_string .. " (x " .. content.cluster_count .. ")"
			end

			return cluster_string
		else
			return Localize(breed.display_name) or ""
		end
	elseif option == "armour_type" then
		local armor_type = breed and breed.armor_type
		local armor_type_loc_string = armor_type and armor_type_string_lookup[armor_type] or ""
		local armor_type_text = Localize(armor_type_loc_string)

		if content.last_hit_zone_name then
			local hit_zone_name = content.last_hit_zone_name

			if breed and breed.hitzone_armor_override and breed.hitzone_armor_override[hit_zone_name] then
				armor_type = breed.hitzone_armor_override[hit_zone_name]
			end

			armor_type_loc_string = armor_type and armor_type_string_lookup[armor_type] or ""
			armor_type_text = Localize(armor_type_loc_string)
		end

		return armor_type_text
	elseif option == "health" then
		local health_extension = content.health_extension
		if not health_extension then
			health_extension = ScriptUnit_has_extension(unit, "health_system")
			content.health_extension = health_extension
		end
		local health_current = content.health_current
		local health_max = content.health_max
		local health_percent = content.health_percent
		local is_dead = true
		local new_text = ""
		local show_toughness = fs.toughness_enabled
			and fs.toughness_text_enabled
			and content.current_toughness
			and content.current_toughness > 0

		if content._last_health_current and content._last_health_max and content._last_damage_value then
			if not fs.hb_text_show_damage then
				if fs.hb_text_show_max_health then
					if show_toughness then
						new_text = ""
							.. math_floor(content.current_toughness)
							.. " / "
							.. math_floor(content.max_toughness)
					else
						new_text = math_floor(content._last_health_current)
							.. " / "
							.. math_floor(content._last_health_max)
					end
				else
					if show_toughness then
						new_text = "" .. math_floor(content.current_toughness)
					else
						new_text = math_floor(content._last_health_current)
					end
				end
			else
				if fs.hb_text_show_max_health then
					if show_toughness then
						new_text = ""
							.. math_floor(content.current_toughness)
							.. " / "
							.. math_floor(content.max_toughness)
							.. " ({#color(255, 255, 50)}-"
							.. math_floor(content._last_damage_value)
							.. "{#reset()})"
					else
						new_text = math_floor(content._last_health_current)
							.. " / "
							.. math_floor(content._last_health_max)
							.. " ({#color(255, 255, 50)}-"
							.. math_floor(content._last_damage_value)
							.. "{#reset()})"
					end
				else
					if show_toughness then
						new_text = ""
							.. math_floor(content.current_toughness)
							.. " ({#color(255, 255, 50)}-"
							.. math_floor(content._last_damage_value)
							.. "{#reset()})"
					else
						new_text = math_floor(content._last_health_current)
							.. " ({#color(255, 255, 50)}-"
							.. math_floor(content._last_damage_value)
							.. "{#reset()})"
					end
				end
			end
		elseif health_current and health_max then
			if fs.hb_text_show_max_health then
				if show_toughness then
					new_text = "" .. math_floor(content.current_toughness) .. " / " .. math_floor(content.max_toughness)
				else
					new_text = math_floor(health_current) .. " / " .. math_floor(health_max)
				end
			else
				if show_toughness then
					new_text = "" .. math_floor(content.current_toughness)
				else
					new_text = math_floor(health_current)
				end
			end
		end

		return new_text
	end
end

template.on_enter = function(widget, marker, template)
	local content = widget.content
	local style = widget.style

	template.position_offset = { 0, 0, fs.hb_y_offset }

	content.hb_built = false
	marker.draw = false -- force hidden until ready...

	content.damage_taken = 0
	content.damage_numbers = {}
	content.spawn_progress_timer = 0

	local unit = marker.unit
	local unit_data_extension = ScriptUnit_extension(unit, "unit_data_system")
	local breed = unit_data_extension and unit_data_extension:breed()

	content.breed = breed
	content.unit_data_extension = unit_data_extension

	local bar_settings = template.bar_settings
	marker.bar_logic = HudHealthBarLogic:new(bar_settings)

	content._breed_type = mod.find_breed_category(unit)
	breed_type = content._breed_type

	content.special_attack_imminent = false

	content.health_extension = ScriptUnit_has_extension(unit, "health_system")
	content.toughness_extension = ScriptUnit_has_extension(unit, "toughness_system")

	-- set frame background
	content.frame = fs.frame_type

	-------------------------------------------------------------------
	-- Icon logic / colors
	-------------------------------------------------------------------

	-- default to hidden
	content.icon_special = false
	content.icon_disabler = false
	content.icon_sniper = false
	content.icon_elite = false
	content.icon_elite_ranged = false
	content.icon_boss = false
	content.icon_witch = false
	content.icon_captain = false
	content.icon_enabled = false

	-- get values from data store
	local icon_color = mod.ICON_COLOURS[breed_type]
	local icon_enabled = mod.ICON_SETTINGS[breed_type].enabled
	local icon_full_scale = mod.ICON_SETTINGS[breed_type].scale * fs.healthbar_type_icon_scale
	local icon_scale = mod.ICON_SETTINGS[breed_type].icon_scale
	local icon_glow_colour = mod.ICON_COLOURS["glow"]
	local icon_glow_intensity = mod.ICON_SETTINGS[breed_type].glow_intensity

	-- apply values to relevant icon
	local function apply_icon_settings(content_icon, style_icon)
		if content._last_icon_scale == marker.scale then
			return content_icon, style_icon
		end

		content._last_icon_scale = marker.scale

		content_icon = icon_enabled
		content.icon_enabled = content_icon

		-- set colours
		style_icon.color[2] = icon_color[2]
		style_icon.color[3] = icon_color[3]
		style_icon.color[4] = icon_color[4]

		-- apply full scale:

		style_icon.size[1] = ((style_icon.default_size[1] * icon_scale) * icon_full_scale) * marker.scale
		style_icon.size[2] = ((style_icon.default_size[2] * icon_scale) * icon_full_scale) * marker.scale
		style.icon_background1.size[1] = (style.icon_background1.default_size[1] * icon_full_scale) * marker.scale
		style.icon_background1.size[2] = (style.icon_background1.default_size[2] * icon_full_scale) * marker.scale
		style.icon_background.size[1] = (style.icon_background.default_size[1] * icon_full_scale) * marker.scale
		style.icon_background.size[2] = (style.icon_background.default_size[2] * icon_full_scale) * marker.scale

		style_icon.default_size[1] = ((style_icon.default_size[1] * icon_scale) * icon_full_scale) * marker.scale
		style_icon.default_size[2] = ((style_icon.default_size[2] * icon_scale) * icon_full_scale) * marker.scale
		style.icon_background1.default_size[1] = (style.icon_background1.default_size[1] * icon_full_scale)
			* marker.scale
		style.icon_background1.default_size[2] = (style.icon_background1.default_size[2] * icon_full_scale)
			* marker.scale
		style.icon_background.default_size[1] = (style.icon_background.default_size[1] * icon_full_scale) * marker.scale
		style.icon_background.default_size[2] = (style.icon_background.default_size[2] * icon_full_scale) * marker.scale

		style_icon.offset[1] = style_icon.default_offset[1] - (10 * icon_full_scale) * marker.scale
		style_icon.default_offset[1] = style_icon.default_offset[1] - (10 * icon_full_scale) * marker.scale
		style.icon_background1.offset[1] = style.icon_background1.default_offset[1]
			- (10 * icon_full_scale) * marker.scale
		style.icon_background1.default_offset[1] = style.icon_background1.default_offset[1]
			- (10 * icon_full_scale) * marker.scale
		style.icon_background.offset[1] = style.icon_background.default_offset[1]
			- (10 * icon_full_scale) * marker.scale
		style.icon_background.default_offset[1] = style.icon_background.default_offset[1]
			- (10 * icon_full_scale) * marker.scale

		return content_icon, style_icon
	end

	-- do stuff per breed type
	if fs.healthbar_type_icon_enable then
		if breed_type == "far" then
			content.icon_elite_ranged, style.icon_elite_ranged =
				apply_icon_settings(content.icon_elite_ranged, style.icon_elite_ranged)
		end
		if breed_type == "elite" then
			content.icon_elite, style.icon_elite = apply_icon_settings(content.icon_elite, style.icon_elite)
		end
		if breed_type == "special" then
			content.icon_special, style.icon_special = apply_icon_settings(content.icon_special, style.icon_special)
		end
		if breed_type == "disabler" then
			content.icon_disabler, style.icon_disabler = apply_icon_settings(content.icon_disabler, style.icon_disabler)
		end
		if breed_type == "sniper" then
			content.icon_sniper, style.icon_sniper = apply_icon_settings(content.icon_sniper, style.icon_sniper)
		end
		if breed_type == "captain" or breed_type == "cultist_captain" then
			content.icon_captain, style.icon_captain = apply_icon_settings(content.icon_captain, style.icon_captain)
		end
		if breed_type == "witch" then
			content.icon_witch, style.icon_witch = apply_icon_settings(content.icon_witch, style.icon_witch)
		end
		if breed_type == "monster" then
			content.icon_boss, style.icon_boss = apply_icon_settings(content.icon_boss, style.icon_boss)
		end
		if breed_type == "horde" then
			content.icon_enabled = false
		end
	end

	-- toughness bar colour
	style.current_toughness.color[2] = fs.toughness_colour[2]
	style.current_toughness.color[3] = fs.toughness_colour[3]
	style.current_toughness.color[4] = fs.toughness_colour[4]

	local bar_color = mod.BREED_COLOURS[breed_type] or mod.BREED_COLOURS.horde

	-- INDIVIDUAL COLOUR OVERRIDES
	if breed then
		local enemy_individual = breed.name

		if enemy_individual then
			local breed_settings = minion_breeds[enemy_individual]

			if breed_settings then
				local tags = breed_settings.tags
				local individual_breed_type = mod.find_breed_category_by_tags(tags)

				if individual_breed_type == breed_type then
					if mod:get("healthbar_" .. enemy_individual .. "_enable") then
						bar_color = mod.BREED_COLOURS_OVERRIDE[enemy_individual]
					end
				end
			end
		end
	end

	style.current_health.color[2] = bar_color[2]
	style.current_health.color[3] = bar_color[3]
	style.current_health.color[4] = bar_color[4]

	local ghost_color = style.ghost_bar.color

	if fs.hb_toggle_ghostbar_colour then
		-- colourful
		ghost_color[2] = bar_color[2] * fs.hb_ghostbar_opacity
		ghost_color[3] = bar_color[3] * fs.hb_ghostbar_opacity
		ghost_color[4] = bar_color[4] * fs.hb_ghostbar_opacity
	else
		-- white
		ghost_color[2] = 255 * fs.hb_ghostbar_opacity
		ghost_color[3] = 255 * fs.hb_ghostbar_opacity
		ghost_color[4] = 255 * fs.hb_ghostbar_opacity
	end

	local icon_offset_y = 0

	if style.icon_elite.color[1] > 0 then
		style.icon_elite.offset[2] = icon_offset_y
	end

	-- update damage number settings
	--template.damage_number_settings
	template.damage_number_settings.duration = fs.damage_number_duration
	template.damage_number_settings.x_offset = fs.hb_size_width * 0.35
	template.damage_number_settings.x_offset_between_numbers = 16 * fs.text_scale * fs.damage_number_scale * 3
	template.damage_number_settings.default_font_size = 16 * fs.text_scale * fs.damage_number_scale
	template.damage_number_settings.hundreds_font_size = 16 * fs.text_scale * fs.damage_number_scale
	template.damage_number_settings.dps_font_size = 18 * fs.text_scale * fs.damage_number_scale
	template.damage_number_settings.expand_bonus_scale = 4 * fs.text_scale * fs.damage_number_scale
	template.show_dps = fs.hb_show_dps

	if content.breed and mod.detect_alive(unit) then
		template.damage_number_settings.y_offset = -content.breed.base_height * 0.7

		local root_position = Unit.world_position(unit, 1)
		root_position.z = root_position.z + content.breed.base_height + 0.5

		if not marker.world_position then
			marker.world_position = Vector3Box(root_position)
		else
			marker.world_position:store(root_position)
		end
	end
end

local function _get_network_values(game_session, game_object_id)
	local toughness_damage = GameSession.game_object_field(game_session, game_object_id, "toughness_damage")
	local max_toughness = GameSession.game_object_field(game_session, game_object_id, "toughness")

	return toughness_damage, max_toughness
end

-----------------------------------------------------------------------
-- Main update
-----------------------------------------------------------------------

local DEBUG_DAMAGE = false

local function debug_damage(msg)
	if DEBUG_DAMAGE then
		mod:echo("[DMG DEBUG] " .. tostring(msg))
	end
end

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	widget._next_update = widget._next_update or 0

	if t < widget._next_update then
		return
	end

	-- if not on screen or draw == false, throttle heavily....
	if not marker.is_inside_frustum or marker.draw == false then
		widget._next_update = t + fs.off_screen_throttle_rate
		return
	-- distance based updates
	elseif marker.distance < 50 then
		widget._next_update = t + fs.general_throttle_rate
	elseif marker.distance < 70 then
		widget._next_update = t + fs.general_throttle_rate * 1.5
	else
		widget._next_update = t + fs.general_throttle_rate * 2
	end

	local content = widget.content
	local style = widget.style
	local unit = marker.unit
	fs = mod.frame_settings

	if not unit then
		marker.remove = true
		return
	end

	local entry = mod.enemy_cache[unit]

	-- early out
	if not marker.draw and not marker.is_inside_frustum and not template.check_line_of_sight then
		marker.draw = false
		return
	end

	if not mod.detect_alive(unit) then
		if not fs.hb_show_dps then
			marker.remove = true
			return
		else
			content.dead = true
			content.hb_built = false
		end
	end

	template.max_distance = fs.draw_distance

	local line_of_sight_progress = content.line_of_sight_progress or 0

	if template.check_line_of_sight then
		if marker.raycast_initialized then
			local raycast_result = marker.raycast_result
			local line_of_sight_speed = 8

			if raycast_result then
				line_of_sight_progress = math.max(line_of_sight_progress - dt * line_of_sight_speed, 0)
			else
				line_of_sight_progress = math.min(line_of_sight_progress + dt * line_of_sight_speed, 1)
			end
		end
	elseif not template.check_line_of_sight then
		line_of_sight_progress = 1
	end

	-------------------------------------------------------------------
	-- Breed / type
	-------------------------------------------------------------------
	local unit_data_extension = content.unit_data_extension
	if not unit_data_extension then
		unit_data_extension = ScriptUnit_has_extension(unit, "unit_data_system")
		content.unit_data_extension = unit_data_extension
	end
	local breed = content.breed or (unit_data_extension and unit_data_extension:breed())
	content.breed = breed

	local breed_type = content._breed_type or "enemy"

	-- if enemy group is disabled, don't show
	local group_hb_enabled = mod:get("healthbar_" .. breed_type .. "_enable")
	if group_hb_enabled ~= nil then
		if not group_hb_enabled then
			marker.draw = false
			marker.remove = true
			return
		end
	end

	-------------------------------------------------------------------
	-- Health / Toughness
	-------------------------------------------------------------------

	local health_extension = content.health_extension
	local health_current = 0
	local health_max = 0
	local health_percent = 0
	local is_dead = true

	if health_extension and mod.detect_alive(unit) then
		health_current = health_extension:current_health() or 0
		health_max = health_extension:max_health() or 0

		if health_current > health_max then
			health_max = health_current
		end

		health_percent = health_extension:current_health_percent() or 0
		is_dead = not health_extension:is_alive()
	end

	local toughness_extension = content.toughness_extension
	local toughness_max = 0
	local toughness_current = 0
	local toughness_fraction = 0

	if toughness_extension and mod.detect_alive(unit) then
		if toughness_extension.max_toughness then
			-- MinionToughnessExtension
			toughness_max = toughness_extension:max_toughness()
			toughness_damage = toughness_extension:toughness_damage()
			toughness_current = toughness_max - toughness_damage
		else
			-- MinionToughnessHuskExtension
			toughness_damage, toughness_max =
				_get_network_values(toughness_extension._game_session, toughness_extension._game_object_id)
			toughness_current = toughness_max - toughness_damage
		end
		if toughness_extension.current_toughness_percent then
			toughness_fraction = toughness_extension:current_toughness_percent() or 0
		else
			toughness_fraction = toughness_current / toughness_max
		end
	end

	content.max_toughness = toughness_max
	content.current_toughness = toughness_current
	content.toughness_fraction = toughness_fraction

	-------------------------------------------------------------------
	-- Horde cluster: pooled HP + center position with stable max
	-------------------------------------------------------------------
	local cluster = mod.get_horde_cluster_for_unit and mod.get_horde_cluster_for_unit(unit)
	local in_horde_cluster = false

	if cluster and fs.horde_clusters_enable and fs.healthbar_enable then
		in_horde_cluster = true

		-- Only the cluster representative should ever have a bar marker, because
		-- enemy_markers.lua only spawns a bar for cluster.rep_unit.
		-- Still, guard and bail out if somehow non-rep gets here.
		if cluster.rep_unit ~= unit then
			marker.draw = false
			marker.remove = true
			content.in_horde_cluster = false
			return
		end

		content.in_horde_cluster = in_horde_cluster

		-- Recompute pooled health so it stays up-to-date as members take damage/die
		-- Throttle cluster updates (VERY important for FPS)
		local next_cluster_update = content._next_cluster_update or 0

		if t >= next_cluster_update then
			content._next_cluster_update = t + 0.1 -- 100ms update interval

			local total_current = 0
			local total_max_instant = 0

			local units = cluster.units
			local unit_count = #units
			content.cluster_count = unit_count

			for i = 1, unit_count do
				local u = units[i]
				local entry = mod.enemy_cache[u]

				if entry and entry.health_ext and mod.detect_alive(u) then
					local he = entry.health_ext
					total_current = total_current + (he:current_health() or 0)
					total_max_instant = total_max_instant + (he:max_health() or 0)
				end
			end

			content._cluster_cached_current = total_current
			content._cluster_cached_max = total_max_instant
		end

		local total_current = content._cluster_cached_current or 0
		local total_max_instant = content._cluster_cached_max or 0

		-- Stable max per representative unit: never decrease while this rep is alive
		local peak = peak_cluster_max_by_rep[unit] or 0
		if total_max_instant > peak then
			peak = total_max_instant
			peak_cluster_max_by_rep[unit] = peak
		end

		if peak > 0 then
			health_current = total_current
			health_max = peak
			health_percent = total_current / peak
		else
			health_current = 0
			health_max = 0
			health_percent = 0
		end

		-- Move bar to horde center, before template.position_offset is applied
		if cluster.center then
			local c = cluster.center
			local cx, cy, cz = c.x, c.y, c.z
			if cx ~= cx or cy ~= cy or cz ~= cz then
				return
			end
			local rep_unit = cluster.rep_unit
			if rep_unit and Unit.alive(rep_unit) then
				local rp = Unit.world_position(rep_unit, 1)

				-- clamp Z so it never goes below actual unit height
				local min_z = rp.z + 1.2
				if cz < min_z then
					cz = min_z
				end
			end

			cz = cz + 0.3

			if not marker.world_position then
				marker.world_position = Vector3Box(Vector3(cx, cy, cz))
			else
				local lerp_xy = 0.25
				local lerp_z = 0.1

				local prev_pos

				if content._smoothed_pos then
					prev_pos = content._smoothed_pos:unbox()
				else
					prev_pos = Vector3(cx, cy, cz)
				end

				local smoothed = Vector3(
					prev_pos.x + (cx - prev_pos.x) * lerp_xy,
					prev_pos.y + (cy - prev_pos.y) * lerp_xy,
					prev_pos.z + (cz - prev_pos.z) * lerp_z
				)

				-- store safely
				if not content._smoothed_pos then
					content._smoothed_pos = Vector3Box(smoothed)
				else
					content._smoothed_pos:store(smoothed)
				end

				-- apply to marker
				if not marker.world_position then
					marker.world_position = Vector3Box(smoothed)
				else
					marker.world_position:store(smoothed)
				end
			end
		end
	else
		-- Non-horde or clusters disabled

		peak_cluster_max_by_rep[unit] = nil

		-- ADJUST POSITION (FOLLOW UNIT)
		if content.breed and mod.detect_alive(unit) then
			local root_position = Unit.world_position(unit, 1)
			root_position.z = root_position.z + content.breed.base_height + 0.5

			if not marker.world_position then
				marker.world_position = Vector3Box(root_position)
			else
				marker.world_position:store(root_position)
			end
		end
	end

	-- if horde individual bars is disabled, but clustered is enabled, only show clustered...
	if entry and entry.is_horde and not fs.horde_enable and fs.horde_clusters_enable and not in_horde_cluster then
		marker.draw = false
		return
	end

	local bar_logic = marker.bar_logic

	-- Failsafe percent clamp
	health_percent = health_percent or 0
	health_percent = math_clamp(health_percent, 0, 1)

	if bar_logic then
		bar_logic:update(dt, t, health_percent)
	end

	local health_fraction = 0
	local health_ghost_fraction = 0
	local health_max_fraction = 0

	if bar_logic then
		health_fraction, health_ghost_fraction, health_max_fraction = bar_logic:animated_health_fractions()
	end

	marker.health_fraction = health_fraction
	marker.health_ghost_fraction = health_ghost_fraction

	-- Fallback if animation system fails
	if not health_fraction then
		health_fraction = health_percent
		health_ghost_fraction = health_percent
		health_max_fraction = 1
	end

	local damage_taken_since_last = 0
	local prev_hp = previous_health[unit]

	if prev_hp then
		damage_taken_since_last = math.max(prev_hp - health_current, 0)
	end

	previous_health[unit] = health_current

	-------------------------------------------------------------------
	-- DAMAGE NUMBERS LOGIC
	-------------------------------------------------------------------

	local max_health_setting = health_max
	max_health_setting = (content.breed and content.breed.name and Managers.state.difficulty)
			and Managers.state.difficulty:get_minion_max_health(content.breed.name)
		or health_max

	local total_damage_taken
	local player_camera = parent._parent and parent._parent:player_camera()

	content.player_camera = player_camera

	if not is_dead and health_extension then
		total_damage_taken = health_extension:total_damage_taken()
	else
		total_damage_taken = max_health_setting or health_max
	end

	if health_extension and not is_dead then
		local last_damaging_unit = health_extension:last_damaging_unit()

		if last_damaging_unit then
			content.last_hit_zone_name = health_extension:last_hit_zone_name() or "center_mass"
			content.last_damaging_unit = last_damaging_unit

			local breed_local = content.breed
			local hit_zone_weakspot_types = breed_local and breed_local.hit_zone_weakspot_types

			if is_weakspot(breed_local, content.last_hit_zone_name) then
				content.hit_weakspot = true
			else
				content.hit_weakspot = false
			end

			content.was_critical = health_extension:was_hit_by_critical_hit_this_render_frame()

			local last_hit_world_position = health_extension:last_hit_world_position()

			if last_hit_world_position then
				local box = content.last_hit_world_position
				if not box then
					content.last_hit_world_position = Vector3Box(last_hit_world_position)
				else
					box:store(last_hit_world_position)
				end
			end
		end
	end

	local damage_number_settings = template.damage_number_settings
	local Managers_player_local = Managers_player
	local local_player = Managers_player_local:local_player(1)
	local local_player_unit = local_player and local_player.player_unit

	template.skip_damage_from_others = false --fs.hb_damage_numbers_track_friendly

	local show_damage_number = true
	local last_damaging_unit = content.last_damaging_unit
	local last_was_player_damage = false

	local owner_unit = nil

	if last_damaging_unit and local_player_unit then
		if last_damaging_unit == local_player_unit then
			last_was_player_damage = true
		end
	end

	-- DEBUG OUTPUT
	if DEBUG_DAMAGE and damage_taken_since_last > 0 then
		debug_damage("---- Damage Event ----")
		debug_damage("Damage: " .. tostring(damage_taken_since_last))
		debug_damage("Last damaging unit: " .. tostring(last_damaging_unit))
		debug_damage("Local player unit: " .. tostring(local_player_unit))
		debug_damage("Owner unit: " .. tostring(owner_unit))
		debug_damage("Is player damage: " .. tostring(last_was_player_damage))
	end

	if template.skip_damage_from_others then
		if last_was_player_damage then
			show_damage_number = true
		else
			show_damage_number = false
		end
	else
		show_damage_number = true
	end

	if DEBUG_DAMAGE and damage_taken_since_last > 0 then
		debug_damage("Skip others setting: " .. tostring(template.skip_damage_from_others))
		debug_damage("Show damage number: " .. tostring(show_damage_number))
	end

	local damage_numbers = content.damage_numbers
	if not damage_numbers then
		damage_numbers = {}
		content.damage_numbers = damage_numbers
	end
	local latest_damage_number = damage_numbers[#damage_numbers]

	if damage_taken_since_last > 0 and health_extension and not is_dead then
		content.visibility_delay = damage_number_settings.visibility_delay
		content.damage_taken = total_damage_taken

		if show_damage_number then
			if fs.hb_damage_show_only_latest then
				-- add new unit to the end
				table.insert(mod.latest_damaged_enemies, unit)

				-- remove oldest entries if we exceed the limit
				while #mod.latest_damaged_enemies > fs.hb_damage_show_only_latest_value do
					table.remove(mod.latest_damaged_enemies, 1)
				end
			end

			local damage_diff = math.ceil(damage_taken_since_last)
			local should_add = true
			local was_critical = health_extension and health_extension:was_hit_by_critical_hit_this_render_frame()

			if latest_damage_number then
				local add_numbers_together_timer = fs.hb_damage_number_type == damage_number_types.flashy
						and damage_number_settings.add_numbers_together_timer_flashy
					or damage_number_settings.add_numbers_together_timer

				if add_numbers_together_timer > t - latest_damage_number.start_time then
					should_add = false
				end
			end

			if fs.hb_damage_numbers_add_total then
				content.add_on_next_number = false
			else
				content.add_on_next_number = true
			end

			if fs.show_damage_numbers or fs.hb_text_show_damage then
				if content.add_on_next_number or was_critical or should_add then
					local damage_number = {
						expand_time = 0,
						time = 0,
						start_time = t,
						duration = damage_number_settings.duration,
						value = damage_diff,
						expand_duration = damage_number_settings.expand_duration,
						random_number = math_random(),
						float_right = math_random() > 0.5,
					}
					local breed_local = content.breed
					local hit_zone_weakspot_types = breed_local and breed_local.hit_zone_weakspot_types

					if is_weakspot(breed_local, content.last_hit_zone_name) then
						damage_number.hit_weakspot = true
					else
						damage_number.hit_weakspot = false
					end

					damage_number.was_critical = was_critical
					local dn_index = #damage_numbers + 1
					damage_numbers[dn_index] = damage_number

					-- Prevent runaway memory usage
					if #damage_numbers > 20 then
						table.remove(damage_numbers, 1)
					end

					if content.add_on_next_number then
						content.add_on_next_number = nil
					end

					if was_critical then
						content.add_on_next_number = true
					end

					if content.last_hit_world_position then
						damage_number.hit_world_position = Vector3Box(content.last_hit_world_position:unbox())
					end
				else
					latest_damage_number.value =
						math_clamp(latest_damage_number.value + damage_diff, 0, max_health_setting)
					latest_damage_number.time = 0
					latest_damage_number.expand_time = 0
					latest_damage_number.expand_duration = damage_number_settings.expand_duration
					latest_damage_number.shrink_start_t = nil
					latest_damage_number.y_position = nil
					latest_damage_number.start_time = t

					local breed_local = content.breed
					local hit_zone_weakspot_types = breed_local and breed_local.hit_zone_weakspot_types

					if is_weakspot(breed_local, content.last_hit_zone_name) then
						latest_damage_number.hit_weakspot = true
					else
						latest_damage_number.hit_weakspot = false
					end

					latest_damage_number.was_critical = was_critical
				end
			end

			if not content.damage_has_started then
				content.damage_has_started = true
			end

			content.last_damage_taken_time = t
		end

		-------------------------------------------------------------------
		-- Health counter text
		-------------------------------------------------------------------
		if
			content._last_health_current ~= health_current
			or content._last_health_max ~= health_max
			or content._last_damage_value ~= (latest_damage_number and latest_damage_number.value)
		then
			content._last_health_current = health_current
			content._last_health_max = health_max
			content._last_damage_value = latest_damage_number and latest_damage_number.value
		end
	end
	--if fs.healthbar_enable then
	-------------------------------------------------------------------
	-- Health bar / ghost / toughness
	-------------------------------------------------------------------

	local size = { fs.hb_size_width, fs.hb_size_height }
	template.size = size

	-- only do healthbar calculations if theyre enabled... Still lets the damage numbers do their thing :)
	if health_fraction and health_ghost_fraction then
		local bar_settings = template.bar_settings
		local spacing = bar_settings.bar_spacing
		local bar_width = template.size[1]
		local bar_height = template.size[2]

		local default_width_offset = -bar_width * 0.5
		local scale = marker.scale or 1
		content.scale = scale

		local health_max_style = style.health_max
		--health_max_style.default_size[1] = bar_width * scale
		health_max_style.size[1] = bar_width * scale

		health_max_style.size[2] = bar_height * scale

		local current_health_style = style.current_health
		local ghost_bar_style = style.ghost_bar

		local scaled_bar_width = health_max_style.size[1]
		content.scaled_bar_width = scaled_bar_width

		local scaled_health_width = scaled_bar_width * health_fraction

		local frame_style = style.frame
		frame_style.size[1] = (bar_width + 12) * scale

		local ghost_fraction = math_max(health_ghost_fraction - health_fraction, 0)
		local scaled_ghost_width = scaled_bar_width * ghost_fraction
	end

	content.health_fraction = health_fraction
	content.health_ghost_fraction = health_ghost_fraction
	content.toughness_fraction = toughness_fraction

	local icon_color = mod.ICON_COLOURS[breed_type]

	local icon_enabled = mod.ICON_SETTINGS[breed_type].enabled
	local icon_full_scale = mod.ICON_SETTINGS[breed_type].scale * fs.healthbar_type_icon_scale
	local icon_scale = mod.ICON_SETTINGS[breed_type].icon_scale
	local icon_glow_colour = mod.ICON_COLOURS["glow"]
	local icon_glow_colour_default = mod.ICON_COLOURS["glow_default"]
	local icon_glow_intensity = mod.ICON_SETTINGS[breed_type].glow_intensity

	-- apply values to relevant icon
	local function icon_special_attack(content_icon, style_icon)
		local update_interval = fs.special_attack_pulse_speed
		content._attack_update_time = (content._attack_update_time or 0) + dt

		if content._attack_update_time > update_interval then
			if fs.healthbar_specials_enable and marker.special_attack_imminent then
				-- get special colour
				local sr = mod:get("outline_specials_colour_R")
				local sg = mod:get("outline_specials_colour_G")
				local sb = mod:get("outline_specials_colour_B")

				if not sr then
					sr = 255
				end
				if not sg then
					sg = 0
				end
				if not sb then
					sb = 0
				end

				if not content.alert_healthbar then
					----- TURN ON
					-- set alert glow intensity
					style.icon_background1.default_alpha = 255

					-- set alert glow colour
					style.icon_background1.color[2] = sr
					style.icon_background1.color[3] = sg
					style.icon_background1.color[4] = sb
					content.alert_healthbar = true
				elseif content.alert_healthbar and fs.specials_flash then
					----- TURN OFF
					-- set alert glow intensity
					style.icon_background1.default_alpha = 0

					content.alert_healthbar = false
				end
			else
				if content.alert_healthbar then
					content.alert_healthbar = false
				end

				-- set alert glow colour
				style.icon_background1.default_alpha = icon_glow_intensity * 2.5
				style.icon_background1.color[2] = icon_glow_colour[2]
				style.icon_background1.color[3] = icon_glow_colour[3]
				style.icon_background1.color[4] = icon_glow_colour[4]

				if icon_glow_intensity > 0 then
					content.glow_enabled = true
				else
					content.glow_enabled = false
				end
			end

			content._attack_update_time = 0
		end

		-- apply full scale:

		--style_icon.size[1] = ((style_icon.default_size[1] * icon_scale) * icon_full_scale) * marker.scale * fs.healthbar_type_icon_scale
		--style_icon.size[2] = ((style_icon.default_size[2] * icon_scale) * icon_full_scale) * marker.scale * fs.healthbar_type_icon_scale
		--style.icon_background1.size[1] = (style.icon_background1.default_size[1] * icon_full_scale) * marker.scale * fs.healthbar_type_icon_scale
		--style.icon_background1.size[2] = (style.icon_background1.default_size[2] * icon_full_scale) * marker.scale * fs.healthbar_type_icon_scale
		--style.icon_background.size[1] = (style.icon_background.default_size[1] * icon_full_scale) * marker.scale * fs.healthbar_type_icon_scale
		--style.icon_background.size[2] = (style.icon_background.default_size[2] * icon_full_scale) * marker.scale * fs.healthbar_type_icon_scale

		return content_icon, style_icon
	end

	-- do stuff per breed type
	if fs.healthbar_type_icon_enable then
		if breed_type == "far" then
			content.icon_elite_ranged, style.icon_elite_ranged =
				icon_special_attack(content.icon_elite_ranged, style.icon_elite_ranged)
		end
		if breed_type == "elite" then
			content.icon_elite, style.icon_elite = icon_special_attack(content.icon_elite, style.icon_elite)
		end
		if breed_type == "special" then
			content.icon_special, style.icon_special = icon_special_attack(content.icon_special, style.icon_special)
		end
		if breed_type == "disabler" then
			content.icon_disabler, style.icon_disabler = icon_special_attack(content.icon_disabler, style.icon_disabler)
		end
		if breed_type == "sniper" then
			content.icon_sniper, style.icon_sniper = icon_special_attack(content.icon_sniper, style.icon_sniper)
		end
		if breed_type == "captain" or breed_type == "cultist_captain" then
			content.icon_captain, style.icon_captain = icon_special_attack(content.icon_captain, style.icon_captain)
		end
		if breed_type == "witch" then
			content.icon_witch, style.icon_witch = icon_special_attack(content.icon_witch, style.icon_witch)
		end
		if breed_type == "monster" then
			content.icon_boss, style.icon_boss = icon_special_attack(content.icon_boss, style.icon_boss)
		end
		if breed_type == "horde" then
			content.icon_enabled = false
		end
	end

	-------------------------------------------------------------------
	-- Height / healthbar position logic
	-------------------------------------------------------------------

	content.health_current = health_current
	content.health_max = health_max
	content.health_percent = health_percent

	if fs.hb_text_top_left_01 then
		content.header_text = get_text_option(content, fs.hb_text_top_left_01)
		if
			fs.hb_text_top_left_01 == "health"
			and fs.toughness_text_colour_enabled
			and content.current_toughness
			and content.current_toughness > 0
		then
			style.header_text.text_color[2] = fs.toughness_colour[2]
			style.header_text.text_color[3] = fs.toughness_colour[3]
			style.header_text.text_color[4] = fs.toughness_colour[4]
		else
			style.header_text.text_color[2] = fs.main_colour[2]
			style.header_text.text_color[3] = fs.main_colour[3]
			style.header_text.text_color[4] = fs.main_colour[4]
		end
	end
	if fs.hb_text_bottom_left_01 then
		content.health_counter = get_text_option(content, fs.hb_text_bottom_left_01)
		if
			fs.hb_text_bottom_left_01 == "health"
			and fs.toughness_text_colour_enabled
			and content.current_toughness
			and content.current_toughness > 0
		then
			style.health_counter.text_color[2] = fs.toughness_colour[2]
			style.health_counter.text_color[3] = fs.toughness_colour[3]
			style.health_counter.text_color[4] = fs.toughness_colour[4]
		else
			style.health_counter.text_color[2] = fs.main_colour[2]
			style.health_counter.text_color[3] = fs.main_colour[3]
			style.health_counter.text_color[4] = fs.main_colour[4]
		end
	end
	if fs.hb_text_bottom_left_02 then
		content.armour_type = get_text_option(content, fs.hb_text_bottom_left_02)
		if
			fs.hb_text_bottom_left_02 == "health"
			and fs.toughness_text_colour_enabled
			and content.current_toughness
			and content.current_toughness > 0
		then
			style.armour_type.text_color[2] = fs.toughness_colour[2]
			style.armour_type.text_color[3] = fs.toughness_colour[3]
			style.armour_type.text_color[4] = fs.toughness_colour[4]
		else
			style.armour_type.text_color[2] = fs.main_colour[2]
			style.armour_type.text_color[3] = fs.main_colour[3]
			style.armour_type.text_color[4] = fs.main_colour[4]
		end
	end

	--end

	-------------------------------------------------------------------
	-- Hide logic / LOS fade
	-------------------------------------------------------------------

	local time_since_last_damage = t - (content.last_damage_taken_time or 0)

	if not mod.detect_alive(unit) and (not marker.health_fraction or marker.health_fraction == 0) then
		if time_since_last_damage > fs.damage_number_duration then
			marker.remove = true
		end
	end

	-- only hide non-clustered horde units when horde disabled
	if breed_type == "horde" and not fs.horde_enable and not in_horde_cluster then
		marker.draw = false
	end

	if fs.horde_hide_after_no_damage and breed_type == "horde" and time_since_last_damage > 5 then
		marker.draw = false
	end

	if fs.hide_after_no_damage and breed_type ~= "horde" and time_since_last_damage > 5 then
		marker.draw = false
	end

	if not marker.is_inside_frustum then
		marker.draw = false
	end

	if fs.hb_damage_show_only_latest then
		if not table.contains(mod.latest_damaged_enemies, unit) then
			marker.draw = false
		end
	end

	content.line_of_sight_progress = line_of_sight_progress
	widget.alpha_multiplier = line_of_sight_progress or 1

	local draw = marker.draw

	if draw and line_of_sight_progress > 0 then
		if fs.healthbar_enable and not content.dead then
			content.hb_built = true
		end
		if fs.show_damage_numbers then
			content.dn_built = true
		end

		local scale = marker.scale * fs.text_scale
		content.scale = scale

		local header_style = style.header_text
		local health_counter = style.health_counter
		local armour_type = style.armour_type
		local damage_numbers = style.readable_damage_numbers

		if header_style then
			header_style.font_size = header_style.default_font_size * scale
		end
		if health_counter then
			health_counter.font_size = health_counter.default_font_size * scale
		end
		if armour_type then
			armour_type.font_size = armour_type.default_font_size * scale
		end

		if damage_numbers then
			damage_numbers.font_size = damage_numbers.default_font_size * scale
		end
	else
		content.hb_built = false
	end
end

return template
