local mod = get_mod("enemy_markers")

local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}

-- Debuff colors for different types of debuffs
local DEBUFF_COLORS = {
	poison = { 255, 0, 255, 0 },
	burn = { 255, 255, 0, 0 },
	slow = { 255, 0, 0, 255 },
	bleed = { 255, 255, 0, 255 },
}

-- The size for the debuff indicator widget
local size = {
	200, -- Width
	6, -- Height
}

template.size = size
template.name = "enemy_debuff"
template.unit_node = "j_neck"
template.position_offset = { 0, 0, 0.5 }

template.check_line_of_sight = true
template.max_distance = 20
template.screen_clamp = false
template.bar_settings = {
	alpha_fade_delay = 2.6,
	alpha_fade_duration = 0.6,
	alpha_fade_min_value = 50,
	animate_on_health_increase = true,
	bar_spacing = 2,
	duration_health = 1,
	duration_health_ghost = 2.5,
	health_animation_threshold = 0.1,
}

template.fade_settings = {
	default_fade = 0,
	fade_from = 0,
	fade_to = 1,
	distance_max = template.max_distance,
	distance_min = template.max_distance * 0.5,
	easing_function = math.ease_exp,
}

-- Icon size and spacing between debuff icons
local DEBUFF_ICON_SIZE = 32
local DEBUFF_SPACING = 5

-- The template for debuff indicators
template.create_widget_defintion = function(template, scenegraph_id)
	local size = template.size
	local bar_width = size[1]
	local bar_height = size[2]

	local debuff_offset = {
		-bar_width * 0.5,
		0,
		0,
	}

	return UIWidget.create_definition({
		-- DEBUFF ICONS
		{
			pass_type = "text",
			style_id = "debuff_icon",
			value = "😍",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "top",
				offset = {
					-bar_width * 0.5,
					-bar_height - 4,
					6,
				},
				font_type = "proxima_nova_bold",
				font_size = 16,
				default_font_size = 16,
				text_color = { 220, 220, 220, 220 },
				default_text_color = { 220, 220, 220, 220 },
				size = { 400, 20 },
			},
		},
		-- DEBUFF NAME
		{
			pass_type = "text",
			style_id = "debuff_name",
			value = "<debuff_name>",
			value_id = "debuff_name",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "top",
				offset = {
					0,
					-bar_height - 4,
					6,
				},
				font_type = "proxima_nova_bold",
				font_size = 16,
				default_font_size = 16,
				text_color = { 220, 220, 220, 220 },
				default_text_color = { 220, 220, 220, 220 },
				size = { 400, 20 },
			},
		},

		-- DEBUFF STACK COUNTER
		{
			pass_type = "text",
			style_id = "stack_counter",
			value = "<stack_counter>",
			value_id = "stack_counter",
			style = {
				horizontal_alignment = "right",
				vertical_alignment = "center",
				text_horizontal_alignment = "right",
				text_vertical_alignment = "top",
				offset = {
					bar_width * 0.5,
					-bar_height - 4,
					6,
				},
				font_type = "proxima_nova_bold",
				font_size = 16,
				default_font_size = 16,
				text_color = { 220, 220, 220, 220 },
				default_text_color = { 220, 220, 220, 220 },
				size = { 400, 20 },
			},
		},
	}, scenegraph_id)
end

-- Function to update the debuff indicator widget
template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	local content = widget.content
	local style = widget.style
	local unit = marker.unit
	local buff_extension = ScriptUnit.has_extension(unit, "buff_system")

	-- Early exit if there's no buff system
	if not buff_extension then
		return
	end

	-- Track all debuffs

	-- Fetch all buffs, stat buffs, and keywords from the buff extension
	local debuffs = buff_extension:buffs()
	local stat_buffs = buff_extension:stat_buffs()
	local keywords = buff_extension:keywords()

	-- Reset debuff icon and stack counter
	local debuff_count = 0
	local debuff_icon = "content/ui/materials/icons/traits/trait_poison" -- Default icon (poison)
	local debuff_color = { 255, 255, 255, 255 }

	if buffs then
		for _, buff in ipairs(debuffs) do
			local buff_name = buff:template_name()

			if table.find(mod.buffs, buff_name) then
				mod:echo(buff_name)
				content.debuff_name = buff_name
				debuff_count = debuff_count + 1
			end
		end
	end

	-- Update debuff icon and color
	style.debuff_icon.value = debuff_icon
	style.debuff_icon.color = debuff_color

	-- Update stack counter text
	content.stack_counter = tostring(debuff_count)

	-- hide
	local is_inside_frustum = content.is_inside_frustum
	local distance = content.distance
	local line_of_sight_progress = content.line_of_sight_progress or 0

	if marker.raycast_initialized then
		local raycast_result = marker.raycast_result
		local line_of_sight_speed = 3

		if raycast_result then
			line_of_sight_progress = math.max(line_of_sight_progress - dt * line_of_sight_speed, 0)
		else
			line_of_sight_progress = math.min(line_of_sight_progress + dt * line_of_sight_speed, 1)
		end
	end

	local draw = marker.draw

	if draw then
		local scale = marker.scale

		-- header text is optional
		local header_style = style.header_text
		if header_style then
			header_style.font_size = header_style.default_font_size * scale
		end

		content.line_of_sight_progress = line_of_sight_progress
		widget.alpha_multiplier = line_of_sight_progress
	end
end

return template
