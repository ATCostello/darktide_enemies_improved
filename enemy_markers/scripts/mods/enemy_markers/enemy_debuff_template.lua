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
template.max_visible_rows = mod:get("max_visible_rows") or 5

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

-- The template for debuff indicators
template.create_widget_defintion = function(template, scenegraph_id)
	local size = template.size
	local bar_width = size[1]
	local bar_height = size[2]
	local max_rows = template.max_visible_rows or 5

	local passes = {}
	local content = {}
	local style = {}

	for i = 1, max_rows do
		local icon_bg_id = "debuff_icon_background_" .. i
		local icon_id = "debuff_icon_" .. i
		local text_id = "stack_counter_" .. i

		local row_offset = -bar_height - 8 - ((i - 1) * (bar_height + 8))

		content[icon_bg_id] = "content/ui/materials/effects/terminal_header_glow"
		content[icon_id] = ""
		content[text_id] = ""

		-- ICON BACKGROUND
		passes[#passes + 1] = {
			pass_type = "texture",
			style_id = icon_bg_id,
			value_id = icon_bg_id,
			visibility_function = function(content, style)
				return content[icon_id] ~= nil -- visible only if icon exists
			end,
		}

		style[icon_bg_id] = {
			scale_to_material = true,
			horizontal_alignment = "right",
			vertical_alignment = "center",
			offset = {
				bar_width * 0.5 - 35,
				row_offset,
				4, -- behind icon
			},
			color = { 20, 0, 0, 0 },
			size = { 30, 30 },
		}

		-- ICON
		passes[#passes + 1] = {
			pass_type = "texture",
			style_id = icon_id,
			value_id = icon_id,
			visibility_function = function(content, style)
				return content[icon_id] ~= nil
			end,
		}

		style[icon_id] = {
			horizontal_alignment = "right",
			vertical_alignment = "center",
			offset = {
				bar_width * 0.5 - 35,
				row_offset,
				6,
			},
			size = { 20, 20 },
			color = { 255, 255, 255, 255 },
		}

		-- STACK COUNTER
		passes[#passes + 1] = {
			pass_type = "text",
			style_id = text_id,
			value_id = text_id,
			visibility_function = function(content, style)
				return content[text_id] ~= nil and content[text_id] ~= ""
			end,
		}

		style[text_id] = {
			horizontal_alignment = "right",
			vertical_alignment = "center",
			text_horizontal_alignment = "right",
			text_vertical_alignment = "top",
			offset = {
				bar_width * 0.5,
				row_offset,
				6,
			},
			font_type = "proxima_nova_bold",
			font_size = 18,
			text_color = { 255, 220, 220, 220 },
			size = { 200, 20 },
		}
	end

	return {
		scenegraph_id = scenegraph_id,
		passes = passes,
		content = content,
		style = style,
	}
end

-- Function to update the debuff indicator widget
template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	local unit = marker.unit
	local buff_extension = ScriptUnit.has_extension(unit, "buff_system")

	if not buff_extension then
		marker.draw = false
		return
	end

	local debuffs = buff_extension:buffs()
	local active = {}

	if debuffs then
		for _, buff in ipairs(debuffs) do
			local name = buff:template_name()

			if table.find(mod.debuffs, name) then
				local stacks = buff.stack_count and buff:stack_count() or buff.stacks and buff:stacks() or 1

				active[#active + 1] = {
					name = name,
					stacks = stacks,
				}
			end
		end
	end

	table.sort(active, function(a, b)
		return a.stacks > b.stacks
	end)

	local max_rows = template.max_visible_rows or 5
	marker.draw = (#active > 0)

	local content = widget.content
	local style = widget.style

	widget._state = widget._state or {}

	local bar_height = template.size[2]
	local row_height = bar_height + 8

	local slide_speed = 16
	local fade_speed = 10
	local stack_speed = 8
	local glow_threshold = 5

	local active_lookup = {}

	-- =========================================
	-- UPDATE STATE (KEYED BY DEBUFF NAME)
	-- =========================================
	for index, debuff in ipairs(active) do
		local state = widget._state[debuff.name]

		if not state then
			state = {
				alpha = 0,
				scale = 0,
				icon_scale = 1.25,
				prev_stacks = debuff.stacks,
				y = -bar_height - 8 - ((index - 1) * row_height),
			}
			widget._state[debuff.name] = state
		end

		-- Fade in
		state.alpha = math.min(state.alpha + dt * 255 * fade_speed, 255)

		-- Target Y per debuff
		local target_y = -bar_height - 8 - ((index - 1) * row_height)
		state.y = math.lerp(state.y, target_y, math.min(dt * slide_speed, 1))

		-- Stack change animation
		if debuff.stacks > state.prev_stacks then
			state.scale = 1
		elseif debuff.stacks < state.prev_stacks then
			state.scale = -0.5
		end

		state.prev_stacks = debuff.stacks
		state.scale = math.lerp(state.scale, 0, math.min(dt * stack_speed, 1))
		state.icon_scale = math.lerp(state.icon_scale, 0, math.min(dt * 6, 1))

		active_lookup[debuff.name] = true
	end

	-- Fade out removed debuffs
	for name, state in pairs(widget._state) do
		if not active_lookup[name] then
			state.alpha = math.max(state.alpha - dt * 255 * fade_speed, 0)
			if state.alpha <= 0 then
				widget._state[name] = nil
			end
		end
	end

	-- =========================================
	-- DRAW ROWS
	-- =========================================
	for i = 1, max_rows do
		local icon_id = "debuff_icon_" .. i
		local text_id = "stack_counter_" .. i

		local icon_style = style[icon_id]
		local text_style = style[text_id]

		local debuff = active[i]

		if debuff then
			local state = widget._state[debuff.name]

			-- Horizontal slide on appear
			local appear_offset = 15 * (state.alpha / 255 - 1)

			icon_style.offset[1] = template.size[1] * 0.5 - 35 + appear_offset
			icon_style.offset[2] = state.y

			text_style.offset[1] = template.size[1] * 0.5 + appear_offset
			text_style.offset[2] = state.y

			content[icon_id] = mod.debuff_icons[debuff.name] or "content/ui/materials/icons/generic/danger"

			content[text_id] = "x " .. debuff.stacks

			-- colour mutation
			local colour = mod.debuff_colours and mod.debuff_colours[debuff.name]
			colour = colour or { 255, 255, 255, 255 }

			local c = icon_style.color

			c[1] = state.alpha -- A
			c[2] = colour[2] or colour[1] or 255 -- R
			c[3] = colour[3] or colour[2] or 255 -- G
			c[4] = colour[4] or colour[3] or 255 -- B

			-- Glow effect
			if debuff.stacks >= glow_threshold then
				c[1] = math.min(c[1] + 40, 255)
				c[2] = math.min(c[2] + 40, 255)
				c[3] = math.min(c[3] + 40, 255)
			end

			-- Stack pulse
			local scale = 1 + (0.35 * state.scale)
			text_style.font_size = 18 * scale
			text_style.text_color[1] = state.alpha

			-- Icon pulse
			local icon_scale = 1 + state.icon_scale
			icon_style.size[1] = 20 * icon_scale
			icon_style.size[2] = 20 * icon_scale

			-- Background moves with icon
			local bg_style = style["debuff_icon_background_" .. i]
			if bg_style then
				bg_style.offset[1] = template.size[1] * 0.5 - 35 + appear_offset
				bg_style.offset[2] = state.y
			end
		else
			content[icon_id] = nil
			content[text_id] = nil
		end
	end
end

return template
