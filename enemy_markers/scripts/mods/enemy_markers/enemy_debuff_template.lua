local mod = get_mod("enemy_markers")

local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}

-- The size for the debuff indicator widget
local size = {
	mod:get("hb_size_width") or 200,
	mod:get("hb_size_height") or 6,
}

template.size = size
template.name = "enemy_debuff"
template.unit_node = "j_neck"
template.position_offset = { 0, 0, 0.8 }

template.check_line_of_sight = true
template.max_distance = mod:get("draw_distance") or 25
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
			pass_type = "texture",
			style_id = "debuff_icon",
			value = "content/ui/materials/icons/generic/danger",
			style = {
				horizontal_alignment = "right",
				vertical_alignment = "center",
				text_horizontal_alignment = "right",
				text_vertical_alignment = "center",
				offset = {
					bar_width * 0.5 - 35,
					-bar_height - 8,
					6,
				},
				font_type = "proxima_nova_bold",
				font_size = 16,
				default_font_size = 16,
				text_color = { 220, 220, 220, 220 },
				default_text_color = { 220, 220, 220, 220 },
				size = { 20, 20 },
				drop_shadow = true,
			},
		},
		-- ICON BACKGROUND (FOR VISIBILITY)
		{
			pass_type = "texture",
			style_id = "debuff_icon_background",
			value = "content/ui/materials/effects/terminal_header_glow",
			style = {
				scale_to_material = true,
				horizontal_alignment = "right",
				vertical_alignment = "center",
				offset = {
					bar_width * 0.5 - 35,
					-bar_height - 8,
					4,
				},
				color = {
					20,
					255,
					255,
					150,
				},

				size = { 30, 30 },
			},
		},
		-- DEBUFF NAME
		{
			pass_type = "text",
			style_id = "debuff_name",
			value = "",
			value_id = "debuff_name",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "top",
				offset = {
					0,
					-bar_height - 8,
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
			value = "",
			value_id = "stack_counter",
			style = {
				horizontal_alignment = "right",
				vertical_alignment = "center",
				text_horizontal_alignment = "right",
				text_vertical_alignment = "top",
				offset = {
					(bar_width * 0.5),
					-bar_height - 8,
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

	-- Fetch all buffs, stat buffs, and keywords from the buff extension
	local debuffs = buff_extension:buffs()
	local stat_buffs = buff_extension:stat_buffs()
	local keywords = buff_extension:keywords()

	-- Reset debuff icon and stack counter
	local debuff_count = 0
	local default_debuff_icon = "content/ui/materials/icons/generic/danger"
	local default_debuff_color = { 255, 150, 150, 150 }

	if debuffs then
		for _, buff in ipairs(debuffs) do
			local buff_name = buff:template_name()

			if table.find(mod.debuffs, buff_name) then
				-- count stacks of current buff applied to unit
				local stack_count = buff_extension:current_stacks(buff_name) or 1

				-- Add counter of current buffs
				debuff_count = debuff_count + 1

				-- Update debuff icon and color
				content.debuff_icon = mod.debuff_icons[buff_name] or default_debuff_icon
				if content.value_id_1 then
					content.value_id_1 = mod.debuff_icons[buff_name] or default_debuff_icon
				end

				style.debuff_icon.color = mod.debuff_colours[buff_name] or default_debuff_color

				-- Update stack counter text
				content.stack_counter = "x " .. tostring(stack_count)

				-- update debuff name
				--content.debuff_name = buff_name
			end
		end
	end

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

	-- hide if debuff counter is at 0
	if debuff_count <= 0 then
		marker.draw = false
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
