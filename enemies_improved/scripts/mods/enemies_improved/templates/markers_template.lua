local mod = get_mod("enemies_improved")

local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}
local BreedQueries = require("scripts/utilities/breed_queries")
local minion_breeds = BreedQueries.minion_breeds_by_name()

local MARKER_TYPE_ICONS = {
	boss = "content/ui/materials/icons/difficulty/flat/difficulty_skull_damnation",
	elite = "content/ui/materials/hud/interactions/icons/enemy_priority",
	far = "content/ui/materials/icons/circumstances/assault_01",
	special = "content/ui/materials/icons/difficulty/flat/difficulty_skull_uprising",
	disabler = "content/ui/materials/icons/generic/exclamation_mark",
	sniper = "content/ui/materials/icons/weapons/actions/ads",
	captain = "content/ui/materials/icons/difficulty/flat/difficulty_skull_auric",
	witch = "content/ui/materials/hud/icons/speaker",
	shield = "content/ui/materials/hud/interactions/icons/void_shield",
	horde = "content/ui/materials/icons/system/page_indicator_02_idle"
}

-----------------------------------------------------------------------
-- Cached settings / constants
-----------------------------------------------------------------------
local fs = mod.frame_settings

local max_size_value = 32 * fs.marker_size

local size = { max_size_value, max_size_value }
local ping_size = { max_size_value, max_size_value }
local arrow_size = { max_size_value * 8, max_size_value * 8 }
local icon_size = { max_size_value / 2, max_size_value / 2 }
local background_size = { max_size_value, max_size_value }
local scale_fraction = 1

local ScriptUnit_extension = ScriptUnit.extension
local ScriptUnit_has_extension = ScriptUnit.has_extension

local math_min = math.min
local math_max = math.max
local math_sin = math.sin
local math_floor = math.floor

-----------------------------------------------------------------------
-- Template static data
-----------------------------------------------------------------------

template.name = "enemy_markers"
template.unit_node = "root_point"
template.min_distance = 0
template.position_offset = { 0, 0, fs.hb_y_offset }

template.size = size
template.icon_size = icon_size
template.ping_size = ping_size

template.alerted = false

template.check_line_of_sight = fs.check_line_of_sight
template.screen_clamp = true
template.max_distance = fs.draw_distance_broadphase or fs.draw_distance

template.scale = 1

template.min_size = { size[1] * scale_fraction, size[2] * scale_fraction }
template.max_size = { size[1], size[2] }

template.icon_min_size = {
	icon_size[1] * scale_fraction,
	icon_size[2] * scale_fraction,
}
template.icon_max_size = { icon_size[1], icon_size[2] }

template.background_min_size = {
	background_size[1] * scale_fraction,
	background_size[2] * scale_fraction,
}
template.background_max_size = { background_size[1], background_size[2] }

template.ping_min_size = {
	ping_size[1] * scale_fraction,
	ping_size[2] * scale_fraction,
}
template.ping_max_size = { ping_size[1], ping_size[2] }

--template.screen_margins = {
--	down = 0.23148148148148148,
--	left = 0.234375,
--	right = 0.234375,
--	up = 0.23148148148148148,
--}

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
-- Widget creation
-----------------------------------------------------------------------

-- Fatshark typo: world markers expect `create_widget_defintion`
template.create_widget_defintion = function(template, scenegraph_id)
	local fs = mod.frame_settings
	local mkr_y_offset = fs.marker_y_offset * 100 or 0

	return UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id = "background",
			value = "content/ui/materials/hud/interactions/frames/point_of_interest_back",
			value_id = "background",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = background_size,
				default_size = background_size,

				offset = { 0, mkr_y_offset, 1 },
				default_offset = { 0, mkr_y_offset, 1 },

				color = fs.marker_bg_colour,
				default_alpha = fs.marker_bg_colour[1],
			},
			change_function = function(content, style)
				if fs.marker_visual_style == "simple_health" then
					content.background = "content/ui/materials/hud/interactions/frames/point_of_interest_back"
				else
					content.background = "content/ui/materials/icons/system/page_indicator_02_idle"
				end
			end,
			visibility_function = function(content, style)
				return content.m_built and fs.marker_visual_style ~= "type_icon"
			end,
		},

		-- ONE WIDGET ONLY...
		{
			pass_type = "rotated_texture",
			style_id = "marker_health",
			value = "content/ui/materials/icons/perks/perk_level_05",
			value_id = "marker_health",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = { background_size[1] / 2, background_size[2] / 2 },
				default_size = { background_size[1] / 2, background_size[2] / 2 },

				offset = { 0, mkr_y_offset, 2 },
				default_offset = { 0, mkr_y_offset, 2 },

				color = { 200, 220, 0, 0 },
				default_alpha = 200,
			},

			change_function = function(content, style)
				local health_extension = content.health_extension
				local health_current = 0
				local health_max = 0
				local health_percent = 0
				local is_dead = true
				local unit = content.unit
				local breed = content.breed

				if unit and health_extension and mod.detect_alive(unit) then
					health_current = health_extension:current_health() or 0
					health_max = health_extension:max_health() or 0
					health_percent = health_extension:current_health_percent() or 0
					if health_percent == 0 then
						health_percent = health_current / health_max
					end
				end

				-- set styling depending on health percentage...
				if health_percent then
					if health_percent > 0.75 then
						content.marker_health = "content/ui/materials/icons/perks/perk_level_04"
					elseif health_percent > 0.50 then
						content.marker_health = "content/ui/materials/icons/perks/perk_level_03"
					elseif health_percent > 0.25 then
						content.marker_health = "content/ui/materials/icons/perks/perk_level_02"
					elseif health_percent > 0 then
						content.marker_health = "content/ui/materials/icons/perks/perk_level_01"
					end
				end
			end,

			visibility_function = function(content, style)
				return fs.marker_visual_style == "simple_health" and content.m_built
			end,
		},

		{
			pass_type = "texture",
			style_id = "ring",
			value = "content/ui/materials/hud/interactions/frames/point_of_interest_top",
			value_id = "ring",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = size,
				default_size = size,

				offset = { 0, mkr_y_offset, 5 },
				default_offset = { 0, mkr_y_offset, 5 },

				color = { 0, 255, 255, 255 },
				default_alpha = 0,
			},
			visibility_function = function(content, style)
				return false
			end,
		},
		{
			pass_type = "rotated_texture",
			style_id = "ping",
			value = "content/ui/materials/hud/interactions/frames/point_of_interest_tag",
			value_id = "ping",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = ping_size,
				default_size = ping_size,

				offset = { 0, mkr_y_offset, 0 },
				default_offset = { 0, mkr_y_offset, 0 },

				color = { 255, 255, 255, 255 },
				default_alpha = 255,
			},
			visibility_function = function(content, style)
				return false
			end,
		},
		{
			pass_type = "texture",
			style_id = "icon",
			value = "content/ui/materials/hud/interactions/icons/enemy",
			value_id = "icon",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = icon_size,
				default_size = icon_size,

				offset = { 0, mkr_y_offset, 3 },
				default_offset = { 0, mkr_y_offset, 3 },

				color = { 0, 200, 175, 0 },
				default_alpha = 0,
			},
			visibility_function = function(content, style)
				return false
			end,
		},
		{
			pass_type = "rotated_texture",
			style_id = "arrow",
			value = "content/ui/materials/hud/interactions/frames/direction",
			value_id = "arrow",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = arrow_size,
				default_size = arrow_size,

				offset = { 0, mkr_y_offset, 2 },
				default_offset = { 0, mkr_y_offset, 2 },

				color = { 255, 255, 255, 255 },
				default_alpha = 255,
			},
			visibility_function = function(content, style)
				return content.special_attack_imminent and content.is_clamped and content.m_built
			end,
			change_function = function(content, style)
				style.angle = content.angle
			end,
		},
		{
			pass_type = "texture",
			style_id = "type_icon",
			value = "content/ui/materials/icons/system/page_indicator_02_idle",
			value_id = "type_icon",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = icon_size,
				default_size = icon_size,

				offset = { 0, mkr_y_offset, 4 },
				default_offset = { 0, mkr_y_offset, 4 },

				color = { 255, 255, 255, 255 },
				default_alpha = 255,
			},
			change_function = function(content, style)
				if content.type_icon_path then
					content.type_icon = content.type_icon_path
				end
			end,
			visibility_function = function(content, style)
				return fs.marker_visual_style == "type_icon" and content.m_built and content.marker_type_icon_show
			end,
		},
	}, scenegraph_id)
end

-----------------------------------------------------------------------
-- Lifecycle
-----------------------------------------------------------------------

local Unit_alive = Unit.alive

template.on_enter = function(widget, marker, template)
	local content = widget.content
	local fs = mod.frame_settings

	if not marker.unit or not Unit_alive(marker.unit) then
		content.draw_mkr = false
		content.m_built = false
		return
	end

	template.position_offset = { 0, 0, fs.hb_y_offset }
	content.m_built = false
	content.draw_mkr = false -- force hidden until ready...

	local unit = marker.unit
	content.unit = unit
	local unit_data_extension = ScriptUnit_extension(unit, "unit_data_system")
	local breed = unit_data_extension and unit_data_extension:breed()
	content.health_extension = ScriptUnit_has_extension(unit, "health_system")
	content.breed = breed
	content.breed_type = mod.find_breed_category(unit)
	content.breed_settings = content.breed and minion_breeds[content.breed.name]

	if content.breed and content.breed.name then
		content.healthbar_enabled = fs.breed_healthbar_enabled[content.breed.name]
	end

	content.m_allowed = true

	local enemy_individual = content.breed and content.breed.name

	if enemy_individual then
		local enabled = fs.breed_marker_toggle and fs.breed_marker_toggle[enemy_individual] or nil

		if enabled ~= nil then
			content.m_allowed = enabled
		end
	end

	content.special_attack_imminent = false

	max_size_value = 32 * fs.marker_size
	size[1], size[2] = max_size_value, max_size_value
	ping_size[1], ping_size[2] = max_size_value, max_size_value
	arrow_size[1], arrow_size[2] = max_size_value * 8, max_size_value * 8
	icon_size[1], icon_size[2] = max_size_value / 2, max_size_value / 2
	background_size[1], background_size[2] = max_size_value, max_size_value
end

-----------------------------------------------------------------------
-- Update
-----------------------------------------------------------------------

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	if not marker or not widget then
		return
	end

	widget._next_update = widget._next_update or 0

	if t < widget._next_update then
		return
	end

	local content = widget.content
	local distance = content.distance or 0
	local unit = marker.unit
	local style = widget.style
	local marker_scale = marker.scale

	-- if not on screen or draw == false, throttle heavily....
	if not marker.is_inside_frustum or content.draw_mkr == false then
		widget._next_update = t + fs.off_screen_throttle_rate
	-- distance based updates
	elseif marker.distance < 50 then
		widget._next_update = t + fs.general_throttle_rate
	elseif marker.distance < 70 then
		widget._next_update = t + fs.general_throttle_rate * 2
	else
		widget._next_update = t + fs.general_throttle_rate * 3
	end

	local entry = mod.enemy_cache[unit]

	if not unit or not Unit_alive(unit) then
		content.draw_mkr = false
		content.m_built = false
		return
	end

	local breed_name = entry and entry.breed_name
	local breed_type = entry and entry.breed_type

	local override_enabled = nil

	-- group override
	if breed_type then
		local enabled = fs.breed_marker_type_enabled and fs.breed_marker_type_enabled[breed_type] or nil

		if enabled ~= nil then
			override_enabled = enabled
		end
	end

	-- individual override
	if breed_name then
		local enabled = fs.breed_marker_toggle and fs.breed_marker_toggle[breed_name] or nil

		if enabled and enabled == true then
			override_enabled = enabled
		end
	end

	-- Horde filter
	if entry and entry.is_horde and not fs.markers_horde_enable and not override_enabled then
		content.draw_mkr = false
		content.m_built = false
		return
	end

	-- Non-horde filter (elites, specials, monsters, etc.)
	if entry and not entry.is_horde and not fs.markers_non_horde_enable and not override_enabled then
		content.draw_mkr = false
		content.m_built = false
		return
	end

	local health_extension = content.health_extension
	if not health_extension then
		health_extension = ScriptUnit_has_extension(unit, "health_system")
		content.health_extension = health_extension
	end

	local style = widget.style

	if content.m_allowed == false then
		content.draw_mkr = false
		content.m_built = false
		return
	end

	local is_alive = mod.detect_alive(unit)

	if not is_alive then
		content.draw_mkr = false
		content.m_built = false
		return
	end

	if is_alive then
		local marker_display = fs.marker_display_option or "always_show"

		if marker_display ~= "always_show" then
			local time_since_last_damage = t - (content.last_damage_taken_time or 0)

			local health_ext = content.health_extension
			if not health_ext then
				health_ext = ScriptUnit_has_extension(unit, "health_system")
				content.health_extension = health_ext
			end

			-- Only show if they ARE damaged
			if marker_display == "hide_unless_damaged" and time_since_last_damage > 5 then
				content.draw_mkr = false
				content.m_built = false
				return
			end

			-- Hide if they are damaged
			if marker_display == "hide_when_damaged" and time_since_last_damage < 5 then
				content.draw_mkr = false
				content.m_built = false
				return
			end
		end
	end

	template.max_distance = fs.draw_distance_broadphase or fs.draw_distance

	local line_of_sight_progress = content.line_of_sight_progress or 0

	-- line-of-sight fade
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

	local bar_color = mod.BREED_COLOURS[content.breed_type] or mod.BREED_COLOURS.horde

	-- INDIVIDUAL COLOUR OVERRIDES
	local enemy_individual = content.breed.name

	if enemy_individual then
		local breed_settings = content.breed_settings
		if breed_settings then
			local tags = breed_settings.tags
			local individual_breed_type = mod.find_breed_category_by_tags(tags)

			if breed_settings.name == "renegade_vanguard" or breed_settings.name == "cultist_vanguard" then
				individual_breed_type = "elite"
			end

			if individual_breed_type == content.breed_type then
				if content.healthbar_enabled then
					bar_color = mod.BREED_COLOURS_OVERRIDE[enemy_individual]
				end
			end
		end
	end

	style.background.color[1] = fs.marker_bg_colour[1]
	style.background.color[2] = fs.marker_bg_colour[2]
	style.background.color[3] = fs.marker_bg_colour[3]
	style.background.color[4] = fs.marker_bg_colour[4]

	-- adjust colour of overhead marker to healthbar colour
	if fs.overhead_marker_uses_healthbar_colour then
		if fs.marker_visual_style == "simple_health" then
			style.marker_health.color[2] = bar_color[2]
			style.marker_health.color[3] = bar_color[3]
			style.marker_health.color[4] = bar_color[4]
		else
			style.background.color[2] = bar_color[2]
			style.background.color[3] = bar_color[3]
			style.background.color[4] = bar_color[4]
		end
	end

	-----------------------------------------------------------------------
	-- Special attack warning pulse
	-----------------------	------------------------------------------------
	local entry = mod.enemy_cache[unit]

	if entry and fs.marker_specials_enable and entry.alert_outline then
		content.special_attack_imminent = true

		local spec_col = fs.outline_specials_colour
		style.arrow.color[2] = spec_col[2]
		style.arrow.color[3] = spec_col[3]
		style.arrow.color[4] = spec_col[4]

		style.background.color[2] = spec_col[2]
		style.background.color[3] = spec_col[3]
		style.background.color[4] = spec_col[4]
	else
		--content.is_clamped = false
	content.special_attack_imminent = false
	content.marker_type_icon_show = false
	content.type_icon_path = nil

		style.arrow.color[2] = 255
		style.arrow.color[3] = 255
		style.arrow.color[4] = 255

		style.marker_health.size[1] = (background_size[1] / 2) * marker_scale
		style.marker_health.size[2] = (background_size[2] / 2) * marker_scale
	end

	-----------------------------------------------------------------------
	-- Enemy type icon on overhead marker (non-boss enemies)
	-----------------------------------------------------------------------
	content.marker_type_icon_show = true

	if fs.marker_visual_style == "type_icon" then
		local icon_breed_type = breed_type or content.breed_type

		if icon_breed_type and icon_breed_type ~= "monster" and icon_breed_type ~= "horde" then
			local icon_settings = mod.ICON_SETTINGS[icon_breed_type]
			local icon_path = MARKER_TYPE_ICONS[icon_breed_type]

			if icon_settings and icon_settings.enabled and icon_path then
				--content.marker_type_icon_show = true
				content.type_icon_path = icon_path
				content.type_icon = icon_path

				local icon_color = mod.ICON_COLOURS[icon_breed_type]
				if icon_color then
					style.type_icon.color[2] = icon_color[2]
					style.type_icon.color[3] = icon_color[3]
					style.type_icon.color[4] = icon_color[4]
				end
			end
		end
	end

	if not marker.is_inside_frustum then
		content.draw_mkr = false
		content.m_built = false
		return
	end

	content.draw_mkr = true

	if content.draw_mkr then
		content.m_built = true
	else
		content.m_built = false
	end
end

return template
