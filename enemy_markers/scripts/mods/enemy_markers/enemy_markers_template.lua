local mod = get_mod("enemy_markers")

local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}

-----------------------------------------------------------------------
-- Cached settings / constants (evaluated once)
-----------------------------------------------------------------------

local max_size_value = 32

local size = { max_size_value, max_size_value }
local ping_size = { max_size_value, max_size_value }
local arrow_size = { max_size_value, max_size_value }
local icon_size = { max_size_value / 2, max_size_value / 2 }
local background_size = { max_size_value, max_size_value }
local scale_fraction = 0.75

-- Settings that were previously mod:get() inline
local CHECK_LOS = mod:get("enemy_markers_require_line_of_sight") or false
local SCREEN_CLAMP = mod:get("enemy_markers_keep_on_screen") or false
local MAX_DISTANCE_SETTING = mod:get("draw_distance") or 25

-- Pre-cache math & Application globals used every frame
local math_min = math.min
local math_max = math.max
local math_sin = math.sin
local Application_time_since_launch = Application.time_since_launch

-----------------------------------------------------------------------
-- Template static data
-----------------------------------------------------------------------

template.name = "enemy_markers"
template.unit_node = "j_head"
template.min_distance = 0

template.size = size
template.icon_size = icon_size
template.ping_size = ping_size

template.alerted = false

template.check_line_of_sight = CHECK_LOS
template.screen_clamp = SCREEN_CLAMP
template.max_distance = MAX_DISTANCE_SETTING

template.data = {}
template.scale = 1
template.line_of_sight_speed = 15

template.min_size = { size[1] * scale_fraction, size[2] * scale_fraction }
template.max_size = { size[1], size[2] }

template.icon_min_size = { icon_size[1] * scale_fraction, icon_size[2] * scale_fraction }
template.icon_max_size = { icon_size[1], icon_size[2] }

template.background_min_size = { background_size[1] * scale_fraction, background_size[2] * scale_fraction }
template.background_max_size = { background_size[1], background_size[2] }

template.ping_min_size = { ping_size[1] * scale_fraction, ping_size[2] * scale_fraction }
template.ping_max_size = { ping_size[1], ping_size[2] }

template.position_offset = { 0, 0, 0.2 }
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
	distance_max = template.max_distance,
	distance_min = template.evolve_distance,
	easing_function = math.easeCubic,
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
	-- use the shared size table from outer scope
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
				offset = { 0, 0, 1 },
				color = { 200, 255, 255, 255 },
			},
			visibility_function = function(content, style)
				return content.background ~= nil
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
				offset = { 0, 0, 5 },
				color = { 0, 255, 255, 255 },
			},
			visibility_function = function(content, style)
				return content.ring ~= nil
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
				offset = { 0, 0, 0 },
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
				offset = { 0, 0, 3 },
				color = { 0, 200, 175, 0 },
			},
			visibility_function = function(content, style)
				return content.icon ~= nil
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
				offset = { 0, 0, 2 },
				color = Color.ui_hud_green_super_light(255, true),
			},
			visibility_function = function(content, style)
				return content.is_clamped and content.arrow ~= nil
			end,
			change_function = function(content, style)
				style.angle = content.angle
			end,
		},
	}, scenegraph_id)
end

-----------------------------------------------------------------------
-- Lifecycle
-----------------------------------------------------------------------

template.on_enter = function(widget)
	local content = widget.content
	content.spawn_progress_timer = 0
end

-----------------------------------------------------------------------
-- Update
-----------------------------------------------------------------------

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	local content = widget.content
	local distance = content.distance or 0
	local data = marker.data

	local evolve_distance = template.evolve_distance
	local style = widget.style

	-- currently always false; kept for compatibility / future use
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

	-- scaling controlled by marker.scale unless explicitly ignored
	marker.ignore_scale = false
	local global_scale = (marker.ignore_scale and 1) or marker.scale or 1

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
	ring_size[1] = sx * global_scale
	ring_size[2] = sy * global_scale

	-- ping scaling + pulsing
	local ping_min_size = template.ping_min_size
	local ping_max_size = template.ping_max_size
	local ping_style = style.ping
	local ping_size_local = ping_style.size

	local ping_speed = 7
	local ping_anim_progress = 0.5 + math_sin(Application_time_since_launch() * ping_speed) * 0.5
	local ping_pulse_size_increase = ping_anim_progress * 15

	local p_sx = ping_min_size[1] + (ping_max_size[1] - ping_min_size[1]) * scale_progress + ping_pulse_size_increase
	local p_sy = ping_min_size[2] + (ping_max_size[2] - ping_min_size[2]) * scale_progress + ping_pulse_size_increase

	ping_size_local[1] = p_sx * global_scale
	ping_size_local[2] = p_sy * global_scale

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
	icon_style_size[1] = i_sx * global_scale
	icon_style_size[2] = i_sy * global_scale

	local b_sx = background_min_size[1] + (background_max_size[1] - background_min_size[1]) * scale_progress
	local b_sy = background_min_size[2] + (background_max_size[2] - background_min_size[2]) * scale_progress
	bg_style_size[1] = b_sx * global_scale
	bg_style_size[2] = b_sy * global_scale

	local animating = (scale_progress ~= content.scale_progress)

	content.line_of_sight_progress = line_of_sight_progress
	content.scale_progress = scale_progress

	widget.alpha_multiplier = line_of_sight_progress or 1
	widget.visible = true

	if data then
		data.distance = distance
	end

	return animating
end

return template