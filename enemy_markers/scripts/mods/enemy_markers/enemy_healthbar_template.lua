local mod = get_mod("enemy_markers")

local HudHealthBarLogic = require("scripts/ui/hud/elements/hud_health_bar_logic")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}

-----------------------------------------------------------------------
-- Cached mod settings
-----------------------------------------------------------------------

template.show_damage_numbers = mod:get("hb_show_damage_numbers") or false
template.show_armor_types = mod:get("hb_show_armour_types") or false
template.hide_after_no_damage = mod:get("hb_hide_after_no_damage") or false
template.horde_enable = mod:get("hb_horde_enable") or false
template.horde_clusters_enable = mod:get("hb_horde_clusters_enable") or false

template.hb_show_enemy_type = mod:get("hb_show_enemy_type") or false
template.hb_text_show_damage = mod:get("hb_text_show_damage") or false

template.frame_type = mod:get("hb_frame") or "content/ui/materials/frames/masteries/panel_main_lower_frame"

local size = { mod:get("hb_size_width") or 200, mod:get("hb_size_height") or 6 }

local min_size = { 0, 0 }

local draw_distance_setting = mod:get("draw_distance") or 25

template.size = size

template.min_size = min_size
template.name = "enemy_healthbar"
template.unit_node = "root_point"
template.position_offset = { 0, 0, 0.5 }

template.check_line_of_sight = true
template.max_distance = draw_distance_setting
template.screen_clamp = false

template.bar_settings = {
	alpha_fade_delay = 1,
	alpha_fade_duration = 0.6,
	alpha_fade_min_value = 50,
	animate_on_health_increase = true,
	bar_spacing = 0,
	duration_health = 1,
	duration_health_ghost = 1,
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

local HEALTH_ALIVE = HEALTH_ALIVE
local ScriptUnit_extension = ScriptUnit.extension
local ScriptUnit_has_extension = ScriptUnit.has_extension
local Managers_state = Managers.state
local Managers_player = Managers.player
local Color_color = Color
local Vector3 = Vector3
local Vector3Box = Vector3Box
local Unit_alive = Unit.alive

local math_clamp = math.clamp
local math_lerp = math.lerp
local math_min = math.min
local math_max = math.max
local math_random = math.random
local math_sqrt = math.sqrt

local string_format = string.format
local table_remove = table.remove
local table_clone = table.clone

-----------------------------------------------------------------------
-- Damage numbers config
-----------------------------------------------------------------------

local damage_number_types = table.enum("readable", "floating", "flashy")
template.show_dps = true
template.skip_damage_from_others = false

do
	local hb_damage_number_type = mod:get("hb_damage_number_types")
	if hb_damage_number_type == "readable" then
		template.damage_number_type = damage_number_types.readable
	elseif hb_damage_number_type == "floating" then
		template.damage_number_type = damage_number_types.floating
	elseif hb_damage_number_type == "flashy" then
		template.damage_number_type = damage_number_types.flashy
	else
		template.damage_number_type = damage_number_types.readable
	end
end

template.damage_number_settings = {
	add_numbers_together_timer = 3,
	add_numbers_together_timer_flashy = 0,
	crit_color = "orange",
	crit_hit_size_scale = 1.5,
	default_color = "white",
	default_font_size = 14,
	dps_font_size = 14.4,
	dps_y_offset = -36,
	duration = 3,
	expand_bonus_scale = 30,
	expand_duration = 0.2,
	fade_delay = 2,
	first_hit_size_scale = 1.2,
	has_taken_damage_timer_remove_after_time = 5,
	has_taken_damage_timer_y_offset = 34,
	hundreds_font_size = 14.4,
	max_float_y = 50,
	shrink_duration = 1,
	visibility_delay = 2,
	weakspot_color = "yellow",
	x_offset = (size[1] / 2) - 10,
	x_offset_between_numbers = 38,
	y_offset = -50,
	flashy_font_size_dmg_multiplier = { 1, 1.5 },
	flashy_font_size_dmg_scale_range = { 50, 300 },
}

local previous_health = {}
local last_damaged_time = {}
local peak_cluster_max_by_rep = {}

local BREED_COLORS = {
	horde = { 200, 255, 0, 0 },
	elite = { 200, 0, 255, 255 },
	ogryn = { 200, 0, 255, 255 },
	disabler = { 200, 200, 255, 0 },
	monster = { 200, 255, 255, 0 },
}

local armor_type_string_lookup = {
	armored = "loc_weapon_stats_display_armored",
	berserker = "loc_weapon_stats_display_berzerker",
	disgustingly_resilient = "loc_weapon_stats_display_disgustingly_resilient",
	resistant = "loc_glossary_armour_type_resistant",
	super_armor = "loc_weapon_stats_display_super_armor",
	unarmored = "loc_weapon_stats_display_unarmored",
}

-----------------------------------------------------------------------
-- Damage number render helpers
-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- Cached damage number colors (NO per-frame allocation)
-----------------------------------------------------------------------

local CACHED_DAMAGE_COLORS = {}

local function _init_damage_colors()
	if next(CACHED_DAMAGE_COLORS) then
		return
	end

	local settings = template.damage_number_settings

	CACHED_DAMAGE_COLORS.default = Color_color[settings.default_color](255, true)
	CACHED_DAMAGE_COLORS.crit = Color_color[settings.crit_color](255, true)
	CACHED_DAMAGE_COLORS.weakspot = Color_color[settings.weakspot_color](255, true)
end

local function _readable_damage_number_function(
	ui_content,
	ui_renderer,
	ui_style,
	damage_number_settings,
	damage_numbers,
	num_damage_numbers,
	position,
	default_color,
	text_color,
	crit_color,
	weakspot_color,
	default_font_size,
	hundreds_font_size,
	font_type
)
	local z_position = position[3]
	local base_y = position[2] + damage_number_settings.y_offset
	local base_x = position[1] + damage_number_settings.x_offset
	local dt = ui_renderer.dt

	for i = num_damage_numbers, 1, -1 do
		local damage_number = damage_numbers[i]
		local duration = damage_number.duration
		local time = damage_number.time
		local progress = math_clamp(time / duration, 0, 1)

		if progress >= 1 then
			table_remove(damage_numbers, i)
		else
			damage_number.time = time + dt
		end

		if damage_number.was_critical then
			text_color[2] = crit_color[2]
			text_color[3] = crit_color[3]
			text_color[4] = crit_color[4]
			damage_number.expand_duration = damage_number_settings.expand_duration
		elseif damage_number.hit_weakspot then
			text_color[2] = weakspot_color[2]
			text_color[3] = weakspot_color[3]
			text_color[4] = weakspot_color[4]
		else
			text_color[2] = default_color[2]
			text_color[3] = default_color[3]
			text_color[4] = default_color[4]
		end

		local value = damage_number.value
		local font_size = (value <= 99 and default_font_size) or hundreds_font_size
		local expand_duration = damage_number.expand_duration

		if expand_duration then
			local expand_time = damage_number.expand_time
			local expand_progress = math_clamp(expand_time / expand_duration, 0, 1)
			local anim_progress = 1 - expand_progress

			font_size = font_size + damage_number_settings.expand_bonus_scale * anim_progress

			if expand_progress >= 1 then
				damage_number.expand_duration = nil
				damage_number.shrink_start_t = duration - damage_number_settings.shrink_duration
			else
				damage_number.expand_time = expand_time + dt
			end
		elseif damage_number.shrink_start_t and time > damage_number.shrink_start_t then
			local diff = time - damage_number.shrink_start_t
			local percentage = diff / damage_number_settings.shrink_duration
			local scale = 1 - percentage

			font_size = font_size * scale
			text_color[1] = text_color[1] * scale
		end

		local text = value
		local size = ui_style.size
		local current_order = num_damage_numbers - i

		if current_order == 0 then
			local scale_size = damage_number.was_critical and damage_number_settings.crit_hit_size_scale
				or damage_number_settings.first_hit_size_scale

			font_size = font_size * scale_size
		end

		position[3] = z_position + current_order
		position[2] = base_y
		position[1] = base_x + current_order * damage_number_settings.x_offset_between_numbers

		UIRenderer.draw_text(ui_renderer, text, font_size, font_type, position, size, text_color, {})
	end

	position[3] = z_position
	position[2] = base_y
	position[1] = base_x
end

local function _floating_damage_number_function(
	ui_content,
	ui_renderer,
	ui_style,
	damage_number_settings,
	damage_numbers,
	num_damage_numbers,
	position,
	default_color,
	text_color,
	crit_color,
	weakspot_color,
	default_font_size,
	hundreds_font_size,
	font_type
)
	local z_position = position[3]
	local base_y = position[2] - damage_number_settings.y_offset * 3
	local base_x = position[1] + damage_number_settings.x_offset
	local dt = ui_renderer.dt

	if ui_content.alpha_multiplier then
		text_color[1] = text_color[1] * ui_content.alpha_multiplier
	end

	for i = num_damage_numbers, 1, -1 do
		local damage_number = damage_numbers[i]
		local duration = damage_number.duration / 2
		local time = damage_number.time
		local progress = math_clamp(time / duration, 0, 1)

		if progress >= 1 then
			table_remove(damage_numbers, i)
		else
			damage_number.time = time + dt
		end

		if damage_number.was_critical then
			text_color[2] = crit_color[2]
			text_color[3] = crit_color[3]
			text_color[4] = crit_color[4]
			damage_number.expand_duration = damage_number_settings.expand_duration
		elseif damage_number.hit_weakspot then
			text_color[2] = weakspot_color[2]
			text_color[3] = weakspot_color[3]
			text_color[4] = weakspot_color[4]
		else
			text_color[2] = default_color[2]
			text_color[3] = default_color[3]
			text_color[4] = default_color[4]
		end

		local value = damage_number.value
		local font_size = (value <= 99 and default_font_size) or hundreds_font_size
		local expand_duration = damage_number.expand_duration

		if expand_duration then
			local expand_time = damage_number.expand_time
			local expand_progress = math_clamp(expand_time / expand_duration, 0, 1)
			local anim_progress = 1 - expand_progress

			font_size = font_size + damage_number_settings.expand_bonus_scale * anim_progress

			if expand_progress >= 1 then
				damage_number.expand_duration = nil
				damage_number.shrink_start_t = duration - damage_number_settings.shrink_duration
			else
				damage_number.expand_time = expand_time + dt
			end
		elseif damage_number.shrink_start_t and time > damage_number.shrink_start_t then
			local diff = time - damage_number.shrink_start_t
			local percentage = diff / damage_number_settings.shrink_duration
			local scale = 1 - percentage

			font_size = font_size * scale
			text_color[1] = text_color[1] * scale
		end

		local text = value
		local size = ui_style.size
		local current_order = num_damage_numbers - i

		if current_order == 0 then
			local scale_size = damage_number.was_critical and damage_number_settings.crit_hit_size_scale
				or damage_number_settings.first_hit_size_scale

			font_size = font_size * scale_size
		end

		position[3] = z_position + current_order * 2
		position[2] = base_y - 35 * time
		position[1] = base_x + current_order * damage_number_settings.x_offset_between_numbers

		UIRenderer.draw_text(ui_renderer, text, font_size, font_type, position, size, text_color, {})
	end

	position[3] = z_position
	position[2] = base_y
	position[1] = base_x
end

local function _flashy_damage_number_function(
	ui_content,
	ui_renderer,
	ui_style,
	damage_number_settings,
	damage_numbers,
	num_damage_numbers,
	position,
	default_color,
	text_color,
	crit_color,
	weakspot_color,
	default_font_size,
	hundreds_font_size,
	font_type
)
	local z_position = position[3]
	local base_y = position[2] - damage_number_settings.y_offset * 3
	local base_x = position[1] + damage_number_settings.x_offset
	local dt = ui_renderer.dt

	if ui_content.alpha_multiplier then
		text_color[1] = text_color[1] * ui_content.alpha_multiplier
	end

	local flashy_font_size_dmg_multiplier = damage_number_settings.flashy_font_size_dmg_multiplier
	local flashy_font_size_dmg_scale_range = damage_number_settings.flashy_font_size_dmg_scale_range

	for i = num_damage_numbers, 1, -1 do
		local damage_number = damage_numbers[i]
		local y_position = base_y
		local x_position = base_x

		if damage_number.hit_world_position then
			local world_to_screen_position =
				Camera.world_to_screen(ui_content.player_camera, damage_number.hit_world_position:unbox())

			y_position = world_to_screen_position[2] - 75
			x_position = world_to_screen_position[1]
		end

		local duration = damage_number.duration / 2
		local time = damage_number.time
		local progress = math_clamp(time / duration, 0, 1)

		if progress >= 1 then
			table_remove(damage_numbers, i)
		else
			damage_number.time = time + dt
		end

		if damage_number.was_critical then
			text_color[2] = crit_color[2]
			text_color[3] = crit_color[3]
			text_color[4] = crit_color[4]
			damage_number.expand_duration = damage_number_settings.expand_duration
		elseif damage_number.hit_weakspot then
			text_color[2] = weakspot_color[2]
			text_color[3] = weakspot_color[3]
			text_color[4] = weakspot_color[4]
		else
			text_color[2] = default_color[2]
			text_color[3] = default_color[3]
			text_color[4] = default_color[4]
		end

		local value = damage_number.value
		local font_size = (value <= 99 and default_font_size) or hundreds_font_size
		local dmg_scale_multiplier = 1

		if value > flashy_font_size_dmg_scale_range[1] then
			local minv = flashy_font_size_dmg_scale_range[1]
			local maxv = flashy_font_size_dmg_scale_range[2]
			local lerp = math_min((value - minv) / (maxv - minv), 1)
			local multiplier = math_lerp(flashy_font_size_dmg_multiplier[1], flashy_font_size_dmg_multiplier[2], lerp)

			font_size = font_size * multiplier
			dmg_scale_multiplier = multiplier
		end

		local expand_duration = damage_number.expand_duration

		if expand_duration then
			local expand_time = damage_number.expand_time
			local expand_progress = math_clamp(expand_time / expand_duration, 0, 1)
			local anim_progress = 1 - expand_progress

			font_size = font_size + damage_number_settings.expand_bonus_scale * anim_progress

			if expand_progress >= 1 then
				damage_number.expand_duration = nil
				damage_number.shrink_start_t = duration - damage_number_settings.shrink_duration
			else
				damage_number.expand_time = expand_time + dt
			end
		elseif damage_number.shrink_start_t and time > damage_number.shrink_start_t then
			local diff = time - damage_number.shrink_start_t
			local percentage = diff / damage_number_settings.shrink_duration
			local scale = 1 - percentage

			font_size = font_size * scale
			text_color[1] = text_color[1] * scale
		end

		local text = value
		local size = ui_style.size
		local current_order = num_damage_numbers - i

		if current_order == 0 then
			local scale_size = damage_number.was_critical and damage_number_settings.crit_hit_size_scale
				or damage_number_settings.first_hit_size_scale

			font_size = font_size * scale_size
		end

		local random_number = damage_number.random_number
		local float_right = damage_number.float_right
		local float_value = 45 * math_lerp(0.8, 1.2, random_number) * dmg_scale_multiplier
		local float_y_value = float_value * 1.25
		local float_x_value = float_right and float_value or -float_value

		position[2] = y_position - math.ease_out_elastic(time) * float_y_value + time * float_y_value
		position[1] = x_position
			+ math.ease_out_elastic(time) * float_x_value
			+ (float_right and time * float_value or time * -float_value)
			- (not float_right and font_size * 0.5 or 0)

		UIRenderer.draw_text(ui_renderer, text, font_size, font_type, position, size, text_color, {})
	end

	position[3] = z_position
	position[2] = base_y
	position[1] = base_x
end

-----------------------------------------------------------------------
-- Damage number dispatcher
-----------------------------------------------------------------------

template.damage_number_function = function(pass, ui_renderer, ui_style, ui_content, position, size)
	local damage_numbers = ui_content.damage_numbers
	if not damage_numbers or #damage_numbers == 0 and not (template.show_dps and ui_content.damage_has_started) then
		ui_style.font_size = template.damage_number_settings.default_font_size * RESOLUTION_LOOKUP.scale
		return
	end

	local damage_number_settings = template.damage_number_settings
	local scale = RESOLUTION_LOOKUP.scale
	local default_font_size = damage_number_settings.default_font_size * scale
	local dps_font_size = damage_number_settings.dps_font_size * scale
	local hundreds_font_size = damage_number_settings.hundreds_font_size * scale
	local font_type = ui_style.font_type

	_init_damage_colors()

	local default_color = CACHED_DAMAGE_COLORS.default
	local crit_color = CACHED_DAMAGE_COLORS.crit
	local weakspot_color = CACHED_DAMAGE_COLORS.weakspot

	-- reuse same table reference
	local text_color = ui_style.text_color

	local num_damage_numbers = #damage_numbers
	local z_position = position[3]
	local y_position = position[2]
	local x_position = position[1]
	local damage_has_started = ui_content.damage_has_started
	local dt = ui_renderer.dt

	if damage_has_started then
		if not ui_content.damage_has_started_timer then
			ui_content.damage_has_started_timer = dt
		elseif not ui_content.dead then
			ui_content.damage_has_started_timer = ui_content.damage_has_started_timer + dt
		end

		if template.show_dps and ui_content.dead then
			local dps_timer = ui_content.damage_has_started_timer or 0
			local dps_value = (dps_timer > 1 and (ui_content.damage_taken / dps_timer)) or ui_content.damage_taken or 0
			local text = string_format("%d DPS", dps_value)
			local dps_y_offset = damage_number_settings.dps_y_offset
			local damage_has_started_position

			if template.damage_number_type == damage_number_types.readable then
				damage_has_started_position = Vector3(x_position, y_position - dps_y_offset, z_position)
			else
				damage_has_started_position = Vector3(x_position, y_position - dps_y_offset * 0.6, z_position)
			end

			UIRenderer.draw_text(
				ui_renderer,
				text,
				dps_font_size,
				font_type,
				damage_has_started_position,
				size,
				ui_style.text_color,
				{}
			)
		end

		if ui_content.last_hit_zone_name then
			local hit_zone_name = ui_content.last_hit_zone_name
			local breed = ui_content.breed
			local armor_type = breed and breed.armor_type

			if breed and breed.hitzone_armor_override and breed.hitzone_armor_override[hit_zone_name] then
				armor_type = breed.hitzone_armor_override[hit_zone_name]
			end

			if template.show_armor_types and template.damage_number_type == damage_number_types.readable then
				local armor_type_loc_string = armor_type and armor_type_string_lookup[armor_type] or ""
				local armor_type_text = Localize(armor_type_loc_string)
				local armor_type_position = Vector3(
					x_position,
					y_position + damage_number_settings.has_taken_damage_timer_y_offset * 1.25,
					z_position
				)

				UIRenderer.draw_text(
					ui_renderer,
					armor_type_text,
					dps_font_size,
					font_type,
					armor_type_position,
					size,
					ui_style.text_color,
					{}
				)
			end
		end
	end

	if template.show_damage_numbers and num_damage_numbers > 0 then
		if template.damage_number_type == damage_number_types.readable then
			_readable_damage_number_function(
				ui_content,
				ui_renderer,
				ui_style,
				damage_number_settings,
				damage_numbers,
				num_damage_numbers,
				position,
				default_color,
				text_color,
				crit_color,
				weakspot_color,
				default_font_size,
				hundreds_font_size,
				font_type
			)
		elseif template.damage_number_type == damage_number_types.floating then
			_floating_damage_number_function(
				ui_content,
				ui_renderer,
				ui_style,
				damage_number_settings,
				damage_numbers,
				num_damage_numbers,
				position,
				default_color,
				text_color,
				crit_color,
				weakspot_color,
				default_font_size,
				hundreds_font_size,
				font_type
			)
		elseif template.damage_number_type == damage_number_types.flashy then
			_flashy_damage_number_function(
				ui_content,
				ui_renderer,
				ui_style,
				damage_number_settings,
				damage_numbers,
				num_damage_numbers,
				position,
				default_color,
				text_color,
				crit_color,
				weakspot_color,
				default_font_size,
				hundreds_font_size,
				font_type
			)
		end
	end

	ui_style.font_size = default_font_size
end

-----------------------------------------------------------------------
-- Widget definition
-----------------------------------------------------------------------

template.create_widget_defintion = function(template, scenegraph_id)
	local size = template.size
	local bar_width = size[1]
	local bar_height = size[2]

	local bar_offset = { -bar_width * 0.5, 0, 0 }

	return UIWidget.create_definition({
		-- METAL FRAME (back plate)
		{
			pass_type = "texture",
			style_id = "frame",
			value = "content/ui/materials/frames/masteries/panel_main_lower_frame",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = { bar_offset[1] - 6, bar_offset[2], 0 },
				default_offset = { bar_offset[1] - 6, bar_offset[2], 0 },
				size = { bar_width + 12, bar_height + 6 },
				default_size = { bar_width + 12, bar_height + 6 },
				color = { 200, 180, 180, 180 },
			},
		}, -- MAX HEALTH
		{
			pass_type = "rect",
			style_id = "health_max",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = { bar_offset[1], bar_offset[2], 1 },
				default_offset = { bar_offset[1], bar_offset[2], 1 },
				size = { bar_width, bar_height },
				default_size = { bar_width, bar_height },
				color = { 200, 0, 0, 0 },
			},
		}, -- GHOST DAMAGE
		{
			pass_type = "rect",
			style_id = "ghost_bar",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = { bar_offset[1], bar_offset[2], 2 },
				default_offset = { bar_offset[1], bar_offset[2], 2 },
				size = { bar_width, bar_height },
				default_size = { bar_width, bar_height },
				color = { 150, 120, 40, 40 },
			},
		}, -- CURRENT HEALTH (main bar)
		{
			pass_type = "rect",
			style_id = "current_health",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = { bar_offset[1], bar_offset[2], 3 },
				default_offset = { bar_offset[1], bar_offset[2], 3 },
				size = { bar_width, bar_height },
				default_size = { bar_width, bar_height },
				color = { 255, 170, 30, 30 },
			},
		}, -- SHADOW
		{
			pass_type = "texture",
			style_id = "shading1",
			value = "content/ui/materials/frames/inner_shadow_medium",
			value_id = "shading1",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = { bar_offset[1], bar_offset[2], 5 },
				default_offset = { bar_offset[1], bar_offset[2], 5 },
				size = { bar_width, bar_height },
				default_size = { bar_width, bar_height },
				color = { 255, 80, 80, 80 },
			},
		}, -- TOP EDGE HIGHLIGHT
		{
			pass_type = "texture",
			style_id = "highlight1",
			value = "content/ui/materials/frames/frame_glow_01",
			value_id = "highlight1",
			style = {
				vertical_alignment = "center",
				offset = { bar_offset[1], bar_offset[2], 6 },
				default_offset = { bar_offset[1], bar_offset[2], 6 },
				size = { bar_width, bar_height },
				default_size = { bar_width, bar_height },
				color = { 0, 255, 255, 255 },
			},
		}, -- ELITE ICON
		{
			pass_type = "texture",
			style_id = "icon_elite",
			value = "content/ui/materials/icons/difficulty/flat/difficulty_skull_heresy",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				offset = { -bar_width * 0.5 - 16, 0, 6 },
				default_offset = { -bar_width * 0.5 - 16, 0, 6 },

				size = { 32, 32 },
				default_size = { 32, 32 },

				color = { 0, 200, 200, 0 },
			},
			visibility_function = function(content)
				dbg_content = content
				return content.is_clamped and content.show_distance
			end,
		}, -- BOSS ICON
		{
			pass_type = "texture",
			style_id = "icon_boss",
			value = "content/ui/materials/icons/difficulty/flat/difficulty_skull_auric",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				offset = { -bar_width * 0.5 - 16, 0, 6 },
				default_offset = { -bar_width * 0.5 - 16, 0, 6 },

				size = { 32, 32 },
				default_size = { 32, 32 },

				color = { 0, 200, 200, 0 },
			},
			visibility_function = function(content)
				return content.is_clamped and content.show_distance
			end,
		}, -- header text
		{
			pass_type = "text",
			style_id = "header_text",
			value = "",
			value_id = "header_text",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "top",
				offset = { -bar_width * 0.5, -bar_height - 8, 6 },
				default_offset = { -bar_width * 0.5, -bar_height - 8, 6 },
				font_type = "proxima_nova_bold",
				font_size = 16,
				default_font_size = 16,
				text_color = { 220, 220, 220, 220 },
				default_text_color = { 220, 220, 220, 220 },
				size = { (bar_width / 2) - 2, 20 },
				default_size = { (bar_width / 2) - 2, 20 },
			},
		}, -- Health text
		{
			pass_type = "text",
			style_id = "health_counter",
			value = "",
			value_id = "health_counter",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "bottom",
				offset = { -bar_width * 0.5, bar_height + 8, 6 },
				default_offset = { -bar_width * 0.5, bar_height + 8, 6 },
				font_type = "proxima_nova_bold",
				font_size = 16,
				default_font_size = 16,
				text_color = { 220, 220, 220, 220 },
				default_text_color = { 220, 220, 220, 220 },
				size = { bar_width, 20 },
				default_size = { bar_width, 20 },

				drop_shadow = true,
			},
		}, -- damage numbers
		{
			pass_type = "logic",
			value = template.damage_number_function,
			style = {
				horizontal_alignment = "right",
				vertical_alignment = "center",
				text_horizontal_alignment = "right",
				text_vertical_alignment = "top",
				offset = { bar_width * 0.5, -bar_height - 20, 1 },
				default_offset = { bar_width * 0.5, -bar_height - 20, 1 },
				font_type = "proxima_nova_bold",
				font_size = 18,
				default_font_size = 18,
				text_color = { 220, 220, 220, 220 },
				default_text_color = { 220, 220, 220, 220 },
				size = { bar_width, 20 },
				default_size = { bar_width, 20 },

				drop_shadow = true,
			},
		},
	}, scenegraph_id)
end

-----------------------------------------------------------------------
-- Lifecycle
-----------------------------------------------------------------------

template.on_enter = function(widget, marker, template)
	local content = widget.content

	content.damage_taken = 0
	content.damage_numbers = {}
	content.spawn_progress_timer = 0

	local unit = marker.unit
	local unit_data_extension = ScriptUnit_extension(unit, "unit_data_system")
	local breed = unit_data_extension and unit_data_extension:breed()

	if template.hb_show_enemy_type and breed then
		content.header_text = breed.name
	end

	content.breed = breed
	content.unit_data_extension = unit_data_extension

	local bar_settings = template.bar_settings
	marker.bar_logic = HudHealthBarLogic:new(bar_settings)

	if breed then
		local tags = breed.tags or {}
		if tags.horde or tags.roamer then
			content._breed_type = "horde"
		elseif tags.monster then
			content._breed_type = "monster"
		elseif tags.captain then
			content._breed_type = "captain"
		elseif tags.disabler then
			content._breed_type = "disabler"
		elseif tags.witch then
			content._breed_type = "witch"
		elseif tags.elite then
			content._breed_type = "elite"
		elseif tags.special then
			content._breed_type = "special"
		else
			content._breed_type = "enemy"
		end
	end
end

-----------------------------------------------------------------------
-- Main update
-----------------------------------------------------------------------

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	local content = widget.content
	local style = widget.style
	local unit = marker.unit

	if not unit then
		marker.remove = true
		return
	end

	-------------------------------------------------------------------
	-- Health / alive
	-------------------------------------------------------------------
	local health_extension = ScriptUnit_has_extension(unit, "health_system")
	local health_current = 0
	local health_max = 0
	local health_percent = 0
	local is_dead = true

	if health_extension then
		health_current = health_extension:current_health() or 0
		health_max = health_extension:max_health() or 0
		health_percent = health_extension:current_health_percent() or 0
		is_dead = not health_extension:is_alive()
	end

	-------------------------------------------------------------------
	-- Breed / type
	-------------------------------------------------------------------
	local unit_data_extension = content.unit_data_extension or ScriptUnit_has_extension(unit, "unit_data_system")
	content.unit_data_extension = unit_data_extension
	local breed = content.breed or (unit_data_extension and unit_data_extension:breed())
	content.breed = breed

	local breed_type = content._breed_type or "enemy"

	if template.hb_show_enemy_type then
		content.header_text = tostring(breed_type)
	end

	-------------------------------------------------------------------
	-- Horde cluster: pooled HP + center position with stable max
	-------------------------------------------------------------------
	local cluster = mod.get_horde_cluster_for_unit and mod.get_horde_cluster_for_unit(unit)
	local in_horde_cluster = false

	if cluster and template.horde_clusters_enable then
		in_horde_cluster = true

		-- Only the cluster representative should ever have a bar marker, because
		-- enemy_markers.lua only spawns a bar for cluster.rep_unit.
		-- Still, guard and bail out if somehow non-rep gets here.
		if cluster.rep_unit ~= unit then
			marker.draw = false
			in_horde_cluster = false
		else
			marker.draw = true
		end

		-- Recompute pooled health so it stays up-to-date as members take damage/die
		local total_current = 0
		local total_max_instant = 0

		local units = cluster.units
		for i = 1, #units do
			local u = units[i]
			if HEALTH_ALIVE[u] then
				local he = ScriptUnit_has_extension(u, "health_system")
				if he then
					total_current = total_current + (he:current_health() or 0)
					total_max_instant = total_max_instant + (he:max_health() or 0)
				end
			end
		end

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

			-- Base position for bar; template.position_offset will be added later
			if not marker.world_position then
				marker.world_position = Vector3Box(Vector3(cx, cy, cz))
			else
				marker.world_position:store(Vector3(cx, cy, cz))
			end
		end
	else
		-- Non-horde or clusters disabled

		peak_cluster_max_by_rep[unit] = nil

		if marker.world_position then
			marker.world_position = nil
		end
	end

	local bar_logic = marker.bar_logic

	-- Failsafe percent clamp
	health_percent = health_percent or 0
	health_percent = math_clamp(health_percent, 0, 1)

	if bar_logic then
		bar_logic:update(dt, t, health_percent)
	end

	local health_fraction, health_ghost_fraction, health_max_fraction

	marker.health_fraction = health_fraction
	marker.health_ghost_fraction = health_ghost_fraction

	if bar_logic then
		health_fraction, health_ghost_fraction, health_max_fraction = bar_logic:animated_health_fractions()
	end

	-- Fallback if animation system fails
	if not health_fraction then
		health_fraction = health_percent
		health_ghost_fraction = health_percent
		health_max_fraction = 1
	end

	local damage_taken_since_last = 0
	local prev_hp = previous_health[unit]
	if prev_hp then
		damage_taken_since_last = prev_hp - health_current
	end
	previous_health[unit] = health_current

	-------------------------------------------------------------------
	-- DAMAGE NUMBERS LOGIC
	-------------------------------------------------------------------
	local max_health_setting = health_max
	if Unit_alive(unit) then
		max_health_setting = (content.breed and content.breed.name and Managers.state.difficulty)
				and Managers.state.difficulty:get_minion_max_health(content.breed.name)
			or health_max
	end

	local total_damage_taken
	local player_camera = parent._parent and parent._parent:player_camera()

	content.player_camera = player_camera

	if not is_dead and health_extension then
		total_damage_taken = health_extension:total_damage_taken()
	else
		total_damage_taken = max_health_setting or health_max
	end

	if health_extension then
		local last_damaging_unit = health_extension:last_damaging_unit()

		if last_damaging_unit then
			content.last_hit_zone_name = health_extension:last_hit_zone_name() or "center_mass"
			content.last_damaging_unit = last_damaging_unit

			local breed_local = content.breed
			local hit_zone_weakspot_types = breed_local and breed_local.hit_zone_weakspot_types

			if hit_zone_weakspot_types and hit_zone_weakspot_types[content.last_hit_zone_name] then
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

	local old_damage_taken = content.damage_taken or 0
	local damage_number_settings = template.damage_number_settings
	local Managers_player_local = Managers_player
	local local_player = Managers_player_local:local_player(1)
	local local_player_unit = local_player and local_player.player_unit
	local show_damage_number = (
		not template.skip_damage_from_others
		or not content.last_damaging_unit
		or content.last_damaging_unit == local_player_unit
	)

	local damage_numbers = content.damage_numbers
	local latest_damage_number = damage_numbers[#damage_numbers]

	if total_damage_taken and total_damage_taken ~= old_damage_taken then
		content.visibility_delay = damage_number_settings.visibility_delay
		content.damage_taken = total_damage_taken

		if show_damage_number and old_damage_taken < total_damage_taken then
			local damage_diff = math.ceil(total_damage_taken - old_damage_taken)
			local should_add = true
			local was_critical = health_extension and health_extension:was_hit_by_critical_hit_this_render_frame()

			if latest_damage_number then
				local add_numbers_together_timer = template.damage_number_type == damage_number_types.flashy
						and damage_number_settings.add_numbers_together_timer_flashy
					or damage_number_settings.add_numbers_together_timer

				if add_numbers_together_timer > t - latest_damage_number.start_time then
					should_add = false
				end
			end

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

				if hit_zone_weakspot_types and hit_zone_weakspot_types[content.last_hit_zone_name] then
					damage_number.hit_weakspot = true
				else
					damage_number.hit_weakspot = false
				end

				damage_number.was_critical = was_critical
				damage_numbers[#damage_numbers + 1] = damage_number

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
				latest_damage_number.value = math_clamp(latest_damage_number.value + damage_diff, 0, max_health_setting)
				latest_damage_number.time = 0
				latest_damage_number.y_position = nil
				latest_damage_number.start_time = t

				local breed_local = content.breed
				local hit_zone_weakspot_types = breed_local and breed_local.hit_zone_weakspot_types

				if hit_zone_weakspot_types and hit_zone_weakspot_types[content.last_hit_zone_name] then
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

		if
			template.hb_text_show_damage
			and latest_damage_number
			and (t - (content.last_damage_taken_time or 0)) <= 3
		then
			content.health_counter = string_format(
				"%d / %d ({#color(255, 255, 50)}-%d)",
				health_current,
				health_max,
				latest_damage_number.value
			)
		else
			content.health_counter = string_format("%d / %d", health_current, health_max)
		end
	end

	-------------------------------------------------------------------
	-- Health bar / ghost / toughness
	-------------------------------------------------------------------
	if health_fraction and health_ghost_fraction then
		local bar_settings = template.bar_settings
		local spacing = bar_settings.bar_spacing
		local bar_width = template.size[1]
		local default_width_offset = -bar_width * 0.5

		local health_max_style = style.health_max
		local current_health_style = style.current_health
		local ghost_bar_style = style.ghost_bar

		local health_width = bar_width * health_fraction

		local scale = marker.scale or 1
		local scaled_bar_width = bar_width * scale
		local scaled_health_width = scaled_bar_width * health_fraction

		current_health_style.size[1] = scaled_health_width
		current_health_style.default_size[1] = scaled_health_width

		current_health_style.offset[1] = -scaled_bar_width * 0.5

		local scaled_ghost_width = math.max(scaled_bar_width * health_ghost_fraction - scaled_health_width, 0)

		ghost_bar_style.size[1] = scaled_ghost_width
		ghost_bar_style.default_size[1] = scaled_ghost_width

		ghost_bar_style.offset[1] = -scaled_bar_width * 0.5 + scaled_health_width
	end

	-- set frame background
	content.frame = template.frame_type

	-------------------------------------------------------------------
	-- Icon logic / colors
	-------------------------------------------------------------------
	style.icon_elite.color[1] = 0
	style.icon_boss.color[1] = 0

	if breed_type == "elite" or breed_type == "ogryn" then
		style.icon_elite.color[1] = 255
	end

	if breed_type == "monster" then
		style.icon_boss.color[1] = 255
		style.frame.color = { 200, 200, 60, 200 }
	end

	local bar_color = BREED_COLORS[breed_type] or BREED_COLORS.horde
	style.current_health.color = bar_color

	local ghost_color = style.ghost_bar.color
	ghost_color[1] = bar_color[1]
	ghost_color[2] = bar_color[2] * 0.5
	ghost_color[3] = bar_color[3] * 0.5
	ghost_color[4] = bar_color[4] * 0.5

	local icon_offset_y = 0

	if style.icon_elite.color[1] > 0 then
		style.icon_elite.offset[2] = icon_offset_y
	end

	-------------------------------------------------------------------
	-- Height / healthbar position logic
	-------------------------------------------------------------------

	if in_horde_cluster == false and content.breed and Unit_alive(unit) then
		local root_position = Unit.world_position(unit, 1)
		root_position.z = root_position.z + content.breed.base_height

		if not marker.world_position then
			marker.world_position = Vector3Box(root_position)
		else
			marker.world_position:store(root_position)
		end
	end

	-------------------------------------------------------------------
	-- Hide logic / LOS fade
	-------------------------------------------------------------------
	local time_since_last_damage = t - (content.last_damage_taken_time or 0)

	if marker.raycast_initialized then
		local raycast_result = marker.raycast_result
		local line_of_sight_speed = 3
		local line_of_sight_progress = content.line_of_sight_progress or 0

		if raycast_result then
			line_of_sight_progress = math_max(line_of_sight_progress - dt * line_of_sight_speed, 0)
		else
			line_of_sight_progress = math_min(line_of_sight_progress + dt * line_of_sight_speed, 1)
		end

		content.line_of_sight_progress = line_of_sight_progress
		widget.alpha_multiplier = line_of_sight_progress
	end

	if not HEALTH_ALIVE[unit] and (not marker.health_fraction or marker.health_fraction == 0) then
		marker.remove = true
	end

	-- only hide non-clustered horde units when horde disabled
	if breed_type == "horde" and not template.horde_enable and not in_horde_cluster then
		marker.draw = false
	end

	if template.hide_after_no_damage and time_since_last_damage > 5 then
		marker.draw = false
	end

	if not marker.is_inside_frustum then
		marker.draw = false
	end

	local draw = marker.draw

	if draw then
		local scale = marker.scale

		local header_style = style.header_text
		local health_counter = style.health_counter

		if header_style then
			header_style.font_size = header_style.default_font_size * scale
		end
		if health_counter then
			health_counter.font_size = health_counter.default_font_size * scale
		end
	end
end

return template
