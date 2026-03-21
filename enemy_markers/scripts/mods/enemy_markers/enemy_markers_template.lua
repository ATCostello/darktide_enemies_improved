local mod = get_mod("enemy_markers")

local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}

-----------------------------------------------------------------------
-- Cached settings / constants
-----------------------------------------------------------------------

local max_size_value = 32

local size = { max_size_value, max_size_value }
local ping_size = { max_size_value, max_size_value }
local arrow_size = { max_size_value * 8, max_size_value * 8 }
local icon_size = { max_size_value / 2, max_size_value / 2 }
local background_size = { max_size_value, max_size_value }
local scale_fraction = 0.75

local CHECK_LOS = mod:get("enemy_markers_require_line_of_sight") or false
local SCREEN_CLAMP = mod:get("enemy_markers_keep_on_screen") or false
local MAX_DISTANCE_SETTING = mod:get("draw_distance") or 25
local enable_horde = mod:get("marker_horde_enable") or false

-----------------------------------------------------------------------
-- Specialist Tracking Settings
-----------------------------------------------------------------------

local TRACK_SPECIALISTS = mod:get("track_specialists") or true
local SHOW_DISTANCE = mod:get("specialist_show_distance") or false
local SPECIAL_PULSE = mod:get("specialist_special_move_flash") or true

local ScriptUnit_extension = ScriptUnit.extension
local Unit_alive = Unit.alive

local TRACKED_ENEMY_TYPES = {
	trapper = true,
	bomber = true,
	sniper = true,
	mutant = true,
	dog = true,
}

local math_min = math.min
local math_max = math.max
local math_sin = math.sin
local Application_time_since_launch = Application.time_since_launch

-----------------------------------------------------------------------
-- Template static data
-----------------------------------------------------------------------

template.name = "enemy_markers"
template.unit_node = "root_point"
template.min_distance = 0
template.position_offset = { 0, 0, 0.8 }

template.size = size
template.icon_size = icon_size
template.ping_size = ping_size

template.alerted = false

template.check_line_of_sight = CHECK_LOS
template.screen_clamp = true
template.max_distance = MAX_DISTANCE_SETTING

template.data = {}
template.scale = 1
template.line_of_sight_speed = 15

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

template.screen_margins = {
	down = 0.23148148148148148,
	left = 0.234375,
	right = 0.234375,
	up = 0.23148148148148148,
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
-- Widget creation
-----------------------------------------------------------------------

-- Fatshark typo: world markers expect `create_widget_defintion`
template.create_widget_defintion = function(template, scenegraph_id)
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

				offset = { 0, 0, 1 },
				default_offset = { 0, 0, 1 },

				color = { 200, 255, 255, 255 },
			},
			visibility_function = function(content, style)
				return not content.is_clamped and content.background ~= nil
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

				offset = { 0, 0, 5 },
				default_offset = { 0, 0, 5 },

				color = { 0, 255, 255, 255 },
			},
			visibility_function = function(content, style)
				return content.ring == nil
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

				offset = { 0, 0, 0 },
				default_offset = { 0, 0, 0 },

				color = { 255, 255, 255, 255 },
			},
			visibility_function = function(content, style)
				return content.tagged
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

				offset = { 0, 0, 3 },
				default_offset = { 0, 0, 3 },

				color = { 0, 200, 175, 0 },
			},
			visibility_function = function(content, style)
				return content.icon == nil
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

				offset = { 0, 0, 2 },
				default_offset = { 0, 0, 2 },

				color = { 255, 255, 255, 255 },
			},
			visibility_function = function(content, style)
				return content.special_attack_imminent
			end,
			change_function = function(content, style)
				style.angle = content.angle
			end,
		},
		{
			pass_type = "text",
			style_id = "distance_text",
			value = "",
			value_id = "distance_text",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "bottom",
				offset = { 0, -2, 6 },
				default_offset = { 0, -2, 6 },
				font_type = "proxima_nova_bold",
				font_size = 14,
				default_font_size = 14,
				text_color = { 220, 220, 220, 220 },
				default_text_color = { 220, 220, 220, 220 },
				size = { 100, 32 },
				default_size = { 100, 32 },

				drop_shadow = true,
			},
			visibility_function = function(content)
				return content.is_clamped and content.show_distance
			end,
		},
	}, scenegraph_id)
end

-----------------------------------------------------------------------
-- Specialist detection
-----------------------------------------------------------------------

local function is_tracked_enemy(marker)
	if not TRACK_SPECIALISTS then
		return false
	end

	local breed_name = marker.data and marker.data.breed_name

	if not breed_name then
		return false
	end

	return TRACKED_ENEMY_TYPES[breed_name] == true
end

-----------------------------------------------------------------------
-- Lifecycle
-----------------------------------------------------------------------

template.on_enter = function(widget, marker, template)
	local content = widget.content
	content.spawn_progress_timer = 0

	local unit = marker.unit
	local unit_data_extension = ScriptUnit_extension(unit, "unit_data_system")
	local breed = unit_data_extension and unit_data_extension:breed()

	content.breed = breed

	content.distance_text = ""
	content.show_distance = false
	content.special_attack_imminent = false
end

-----------------------------------------------------------------------
-- Update
-----------------------------------------------------------------------

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	local content = widget.content
	local distance = content.distance or 0
	local data = marker.data	
	local unit = marker.unit

	local evolve_distance = template.evolve_distance
	local style = widget.style

	local can_interact = false

	local scale_speed = 8
	local scale_progress = content.scale_progress or 0
	local line_of_sight_progress = content.line_of_sight_progress or 0

	-- scale anim
	if distance <= evolve_distance and can_interact then
		scale_progress = math_min(scale_progress + dt * scale_speed, 1)
	else
		scale_progress = math_max(scale_progress - dt * scale_speed, 0)
	end

	-- marker height
	if content.breed and Unit_alive(unit) then
		local root_position = Unit.world_position(unit, 1)
		root_position.z = root_position.z + (0.7 * content.breed.base_height)

		if not marker.world_position then
			marker.world_position = Vector3Box(root_position)
		else
			marker.world_position:store(root_position)
		end
	end

	-- line-of-sight fade
	if marker.raycast_initialized then
		local raycast_result = marker.raycast_result
		local line_of_sight_speed = 8

		if raycast_result and not can_interact then
			line_of_sight_progress = math_max(line_of_sight_progress - dt * line_of_sight_speed, 0)
		else
			line_of_sight_progress = math_min(line_of_sight_progress + dt * line_of_sight_speed, 1)
		end
	elseif not template.check_line_of_sight then
		line_of_sight_progress = 1
	end

	-- ring scaling
	local default_size = template.min_size
	local max_size = template.max_size
	local ring_size = style.ring.size

	local sx = default_size[1] + (max_size[1] - default_size[1]) * scale_progress
	local sy = default_size[2] + (max_size[2] - default_size[2]) * scale_progress
	ring_size[1] = sx * marker.scale
	ring_size[2] = sy * marker.scale

	-- ping scaling + pulsing
	local ping_min_size = template.ping_min_size
	local ping_max_size = template.ping_max_size
	local ping_style = style.ping
	local ping_size_local = ping_style.size

	local ping_speed = 2
	local ping_anim_progress = 0.5 + math_sin(Application_time_since_launch() * ping_speed) * 0.5
	local ping_pulse_size_increase = ping_anim_progress * 15

	local p_sx = ping_min_size[1] + (ping_max_size[1] - ping_min_size[1]) * scale_progress + ping_pulse_size_increase
	local p_sy = ping_min_size[2] + (ping_max_size[2] - ping_min_size[2]) * scale_progress + ping_pulse_size_increase

	ping_size_local[1] = p_sx * marker.scale
	ping_size_local[2] = p_sy * marker.scale

	local ping_pivot = ping_style.pivot
	ping_pivot[1] = ping_size_local[1] * 0.5
	ping_pivot[2] = ping_size_local[2] * 0.5

	-- icon & background scaling
	local icon_max_size = template.icon_max_size
	local icon_min_size = template.icon_min_size
	local background_max_size = template.background_max_size
	local background_min_size = template.background_min_size

	local icon_style_size = style.icon.size
	local bg_style_size = style.background.size

	local i_sx = icon_min_size[1] + (icon_max_size[1] - icon_min_size[1]) * scale_progress
	local i_sy = icon_min_size[2] + (icon_max_size[2] - icon_min_size[2]) * scale_progress
	icon_style_size[1] = i_sx * marker.scale
	icon_style_size[2] = i_sy * marker.scale

	local b_sx = background_min_size[1] + (background_max_size[1] - background_min_size[1]) * scale_progress
	local b_sy = background_min_size[2] + (background_max_size[2] - background_min_size[2]) * scale_progress
	bg_style_size[1] = b_sx * marker.scale
	bg_style_size[2] = b_sy * marker.scale

	local animating = (scale_progress ~= content.scale_progress)

	-----------------------------------------------------------------------
	-- Special attack warning pulse
	-----------------------------------------------------------------------

	mod.pulse_t = (mod.pulse_t or 0) + mod.frame_settings.dt

	if SPECIAL_PULSE and marker.special_attack_imminent then
		content.special_attack_imminent = true
		local pulse = math.abs(math.sin(mod.pulse_t * 2))

		local flash = math.min(255, 150 + pulse * 100)
		local size_scale = 1 + pulse * 0.5

		local r, g, b = flash, 50, 50

		style.arrow.color[2] = r
		style.arrow.color[3] = g
		style.arrow.color[4] = b

		style.background.color[2] = r
		style.background.color[3] = g
		style.background.color[4] = b

		style.arrow.size[1] = arrow_size[1] * size_scale * marker.scale
		style.arrow.size[2] = arrow_size[2] * size_scale * marker.scale

		style.background.size[1] = background_size[1] * size_scale * marker.scale
		style.background.size[2] = background_size[2] * size_scale * marker.scale
	else
		content.special_attack_imminent = false
		style.background.color[2] = 255
		style.background.color[3] = 255
		style.background.color[4] = 255

		style.arrow.color[2] = 255
		style.arrow.color[3] = 255
		style.arrow.color[4] = 255

		style.arrow.size[1] = arrow_size[1] * marker.scale
		style.arrow.size[2] = arrow_size[2] * marker.scale

		style.background.size[1] = background_size[1] * marker.scale
		style.background.size[2] = background_size[2] * marker.scale
	end

	local angle = content.angle or 0
	local dist = style.arrow.size[2] * 0.7

	local text_offset = style.distance_text.offset
	text_offset[1] = 0
	text_offset[2] = -(style.arrow.size[2] * 0.2)

	content.line_of_sight_progress = line_of_sight_progress
	content.scale_progress = scale_progress

	widget.alpha_multiplier = line_of_sight_progress or 1
	widget.visible = true

	-- Distance text for specialists
	if SHOW_DISTANCE and marker.is_specialist then
		content.show_distance = true
		content.distance_text = string.format("%dm", math.floor(distance))
	else
		content.show_distance = false
		content.distance_text = ""
	end

	if data then
		data.distance = distance
	end

	return animating
end

return template
