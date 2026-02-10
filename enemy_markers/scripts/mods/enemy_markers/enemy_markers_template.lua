local mod = get_mod("enemy_markers")

local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}

local max_size_value = 32

local size = { max_size_value, max_size_value }
local ping_size = { max_size_value, max_size_value }
local arrow_size = { max_size_value, max_size_value }
local icon_size = { max_size_value / 2, max_size_value / 2 }
local background_size = { max_size_value, max_size_value }
local line_size = { 250, 5 }
local bar_size = { 210, 10 }
local scale_fraction = 0.75

template.size = size
template.name = "enemy_markers"
template.unit_node = "j_head"
template.min_distance = 0
template.size = size
template.icon_size = icon_size
template.ping_size = ping_size

template.check_line_of_sight = mod:get("enemy_markers_require_line_of_sight") or false
template.screen_clamp = mod:get("enemy_markers_keep_on_screen") or false

template.evolve_distance = 1
template.max_distance = mod:get("draw_distance") or 25
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
template.screen_margins = { down = 0.23148148148148148, left = 0.234375, right = 0.234375, up = 0.23148148148148148 }

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

-- Fatshark typo: world markers expect `create_widget_defintion`
template.create_widget_defintion = function(template, scenegraph_id)
	local size = template.size

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

template.on_enter = function(widget)
	local content = widget.content

	content.spawn_progress_timer = 0
end

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	local content = widget.content
	local distance = content.distance
	local data = marker.data

	local evolve_distance = template.evolve_distance
	local style = widget.style

	local can_interact = false

	local scale_speed = 8
	local scale_progress = content.scale_progress or 0
	local line_of_sight_progress = content.line_of_sight_progress or 0

	if distance <= evolve_distance and can_interact then
		scale_progress = math.min(scale_progress + dt * scale_speed, 1)
	else
		scale_progress = math.max(scale_progress - dt * scale_speed, 0)
	end

	marker.ignore_scale = false

	local global_scale = marker.ignore_scale and 1 or marker.scale

	if marker.raycast_initialized then
		local raycast_result = marker.raycast_result
		local line_of_sight_speed = 8

		if raycast_result and not can_interact then
			line_of_sight_progress = math.max(line_of_sight_progress - dt * line_of_sight_speed, 0)
		else
			line_of_sight_progress = math.min(line_of_sight_progress + dt * line_of_sight_speed, 1)
		end
	elseif not template.check_line_of_sight then
		line_of_sight_progress = 1
	end

	local default_size = template.min_size
	local max_size = template.max_size
	local ring_size = style.ring.size

	ring_size[1] = (default_size[1] + (max_size[1] - default_size[1]) * scale_progress) * global_scale
	ring_size[2] = (default_size[2] + (max_size[2] - default_size[2]) * scale_progress) * global_scale

	local ping_min_size = template.ping_min_size
	local ping_max_size = template.ping_max_size
	local ping_style = style.ping
	local ping_size = ping_style.size
	local ping_speed = 7
	local ping_anim_progress = 0.5 + math.sin(Application.time_since_launch() * ping_speed) * 0.5
	local ping_pulse_size_increase = ping_anim_progress * 15

	ping_size[1] = (
		ping_min_size[1]
		+ (ping_max_size[1] - ping_min_size[1]) * scale_progress
		+ ping_pulse_size_increase
	) * global_scale
	ping_size[2] = (
		ping_min_size[2]
		+ (ping_max_size[2] - ping_min_size[2]) * scale_progress
		+ ping_pulse_size_increase
	) * global_scale

	local ping_pivot = ping_style.pivot

	ping_pivot[1] = ping_size[1] * 0.5
	ping_pivot[2] = ping_size[2] * 0.5

	local icon_max_size = template.icon_max_size
	local icon_min_size = template.icon_min_size
	local background_max_size = template.background_max_size
	local background_min_size = template.background_min_size
	local icon_size = style.icon.size

	icon_size[1] = (icon_min_size[1] + (icon_max_size[1] - icon_min_size[1]) * scale_progress) * global_scale
	icon_size[2] = (icon_min_size[2] + (icon_max_size[2] - icon_min_size[2]) * scale_progress) * global_scale

	local background_size = style.background.size

	background_size[1] = (background_min_size[1] + (background_max_size[1] - background_min_size[1]) * scale_progress)
		* global_scale
	background_size[2] = (background_min_size[2] + (background_max_size[2] - background_min_size[2]) * scale_progress)
		* global_scale

	local animating = scale_progress ~= content.scale_progress

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
