local mod = get_mod("enemy_markers")

local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}

-----------------------------------------------------------------------
-- Cached settings (evaluated once at load; cheap and static)
-----------------------------------------------------------------------

local hb_size_width = mod:get("hb_size_width") or 200
local hb_size_height = mod:get("hb_size_height") or 6
local max_visible_rows_setting = mod:get("max_visible_rows") or 5
local draw_distance_setting = mod:get("draw_distance") or 25

local size = {
	hb_size_width,
	hb_size_height,
}

template.size = size
template.name = "enemy_debuff"
template.unit_node = "j_neck"
template.position_offset = { 0, 0, 0.8 }
template.max_visible_rows = max_visible_rows_setting

template.check_line_of_sight = true
template.max_distance = draw_distance_setting
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

-----------------------------------------------------------------------
-- Small local helpers / cached globals to avoid repeated lookups
-----------------------------------------------------------------------

local ScriptUnit_has_extension = ScriptUnit.has_extension
local table_sort = table.sort
local math_min = math.min
local math_max = math.max
local math_lerp = math.lerp
local ipairs = ipairs
local pairs = pairs

-- Cheap table.find replacement to avoid generic helper overhead
local function array_contains(tbl, value)
	if not tbl or not value then
		return false
	end

	for i = 1, #tbl do
		if tbl[i] == value then
			return true
		end
	end

	return false
end

-----------------------------------------------------------------------
-- Widget definition
-----------------------------------------------------------------------

template.create_widget_defintion = function(template, scenegraph_id)
	local size = template.size
	local bar_width = size[1]
	local bar_height = size[2]
	local max_rows = template.max_visible_rows or 5

	local passes = {}
	local content = {}
	local style = {}

	-- Precompute constant offsets
	local base_y = -bar_height - 8
	local row_step = bar_height + 8
	local icon_x = bar_width * 0.5 - 35
	local text_x = bar_width * 0.5

	for i = 1, max_rows do
		local icon_bg_id = "debuff_icon_background_" .. i
		local icon_id = "debuff_icon_" .. i
		local text_id = "stack_counter_" .. i

		local row_offset_y = base_y - ((i - 1) * row_step)

		content[icon_bg_id] = "content/ui/materials/effects/terminal_header_glow"
		content[icon_id] = "" -- no icon by default
		content[text_id] = "" -- no text by default

		-- ICON BACKGROUND
		passes[#passes + 1] = {
			pass_type = "texture",
			style_id = icon_bg_id,
			value_id = icon_bg_id,
			visibility_function = function(content, style)
				-- visible only if its icon is present
				return content[icon_id] ~= nil
			end,
		}

		style[icon_bg_id] = {
			scale_to_material = true,
			horizontal_alignment = "right",
			vertical_alignment = "center",
			offset = {
				icon_x,
				row_offset_y,
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
				icon_x,
				row_offset_y,
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
				local v = content[text_id]
				return v ~= nil and v ~= ""
			end,
		}

		style[text_id] = {
			horizontal_alignment = "right",
			vertical_alignment = "center",
			text_horizontal_alignment = "right",
			text_vertical_alignment = "top",
			offset = {
				text_x,
				row_offset_y,
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

-----------------------------------------------------------------------
-- Update function
-----------------------------------------------------------------------

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	local unit = marker.unit
	if not unit then
		marker.draw = false
		return
	end

	local buff_extension = ScriptUnit_has_extension(unit, "buff_system")
	if not buff_extension then
		marker.draw = false
		return
	end

	local debuffs = buff_extension:buffs()
	if not debuffs or #debuffs == 0 then
		-- no debuffs at all; we can early out and just fade existing ones
		marker.draw = false
	else
		marker.draw = true
	end

	-- Gather active debuffs that we care about
	local active = {}
	local active_count = 0

	for i = 1, #debuffs do
		local buff = debuffs[i]
		local name = buff:template_name()

		-- use cheaper contains helper
		if array_contains(mod.debuffs, name) then
			local stacks = buff.stack_count and buff:stack_count()
				or buff.stacks and buff:stacks()
				or 1

			active_count = active_count + 1
			active[active_count] = {
				name = name,
				stacks = stacks,
			}
		end
	end

	if active_count == 0 then
		-- No relevant debuffs: fade any existing state and hide
		marker.draw = false
	end

	-- Truncate 'active' length (important if previous frame had more)
	for i = active_count + 1, #active do
		active[i] = nil
	end

	-- Sort by stack count desc
	if active_count > 1 then
		table_sort(active, function(a, b)
			return a.stacks > b.stacks
		end)
	end

	local max_rows = template.max_visible_rows or 5
	local content = widget.content
	local style = widget.style

	widget._state = widget._state or {}
	local state_table = widget._state

	local bar_height = template.size[2]
	local row_height = bar_height + 8

	local slide_speed = 16
	local fade_speed = 10
	local stack_speed = 8
	local glow_threshold = 5

	local active_lookup = {}

	-------------------------------------------------------------------
	-- UPDATE STATE (KEYED BY DEBUFF NAME)
	-------------------------------------------------------------------
	for index = 1, active_count do
		local debuff = active[index]
		local name = debuff.name
		local stacks = debuff.stacks

		local state = state_table[name]
		if not state then
			state = {
				alpha = 0,
				scale = 0,
				icon_scale = 1.25,
				prev_stacks = stacks,
				y = -bar_height - 8 - ((index - 1) * row_height),
			}
			state_table[name] = state
		end

		-- Fade in
		local alpha = state.alpha + dt * 255 * fade_speed
		state.alpha = (alpha < 255) and alpha or 255

		-- Target Y per debuff
		local target_y = -bar_height - 8 - ((index - 1) * row_height)
		local lerp_t = dt * slide_speed
		if lerp_t > 1 then
			lerp_t = 1
		end
		state.y = math_lerp(state.y, target_y, lerp_t)

		-- Stack change animation
		if stacks > state.prev_stacks then
			state.scale = 1
		elseif stacks < state.prev_stacks then
			state.scale = -0.5
		end

		state.prev_stacks = stacks

		local stack_lerp_t = dt * stack_speed
		if stack_lerp_t > 1 then
			stack_lerp_t = 1
		end
		state.scale = math_lerp(state.scale, 0, stack_lerp_t)

		local icon_lerp_t = dt * 6
		if icon_lerp_t > 1 then
			icon_lerp_t = 1
		end
		state.icon_scale = math_lerp(state.icon_scale, 0, icon_lerp_t)

		active_lookup[name] = true
	end

	-- Fade out removed debuffs
	for name, state in pairs(state_table) do
		if not active_lookup[name] then
			local alpha = state.alpha - dt * 255 * fade_speed
			if alpha <= 0 then
				state_table[name] = nil
			else
				state.alpha = alpha
			end
		end
	end

	-------------------------------------------------------------------
	-- DRAW ROWS
	-------------------------------------------------------------------
	local template_size_1 = template.size[1]

	for i = 1, max_rows do
		local icon_id = "debuff_icon_" .. i
		local text_id = "stack_counter_" .. i

		local icon_style = style[icon_id]
		local text_style = style[text_id]

		local debuff = active[i]

		if debuff then
			local name = debuff.name
			local stacks = debuff.stacks
			local state = state_table[name]

			if state then
				-- Horizontal slide on appear
				local alpha_factor = state.alpha / 255
				local appear_offset = 15 * (alpha_factor - 1)

				local icon_offset_x = template_size_1 * 0.5 - 35 + appear_offset
				local text_offset_x = template_size_1 * 0.5 + appear_offset

				icon_style.offset[1] = icon_offset_x
				icon_style.offset[2] = state.y

				text_style.offset[1] = text_offset_x
				text_style.offset[2] = state.y

				content[icon_id] = mod.debuff_icons and mod.debuff_icons[name]
					or "content/ui/materials/icons/generic/danger"

				content[text_id] = "x " .. stacks

				-- colour mutation
				local colour = (mod.debuff_colours and mod.debuff_colours[name])
					or { 255, 255, 255, 255 }

				local c = icon_style.color

				-- A
				c[1] = state.alpha
				-- R, G, B with fallbacks
				c[2] = colour[2] or colour[1] or 255
				c[3] = colour[3] or colour[2] or 255
				c[4] = colour[4] or colour[3] or 255

				-- Glow effect
				if stacks >= glow_threshold then
					c[1] = (c[1] + 40 < 255) and (c[1] + 40) or 255
					c[2] = (c[2] + 40 < 255) and (c[2] + 40) or 255
					c[3] = (c[3] + 40 < 255) and (c[3] + 40) or 255
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
					bg_style.offset[1] = icon_offset_x
					bg_style.offset[2] = state.y
				end
			end
		else
			content[icon_id] = nil
			content[text_id] = nil
		end
	end
end

return template