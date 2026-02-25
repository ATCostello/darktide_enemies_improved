local mod = get_mod("enemy_markers")

local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}

-----------------------------------------------------------------------
-- Cached settings
-----------------------------------------------------------------------

local hb_size_width = mod:get("hb_size_width") or 200
local hb_size_height = mod:get("hb_size_height") or 6
local max_visible_rows_setting = mod:get("max_visible_rows") or 5
local draw_distance_setting = mod:get("draw_distance") or 25
local show_names = mod:get("debuff_names") == true
local names_fade = mod:get("debuff_names_fade") == true
local enable_horde = mod:get("debuff_horde_enable") or false

local NAME_FADE_IN = 0.15
local NAME_VISIBLE = 1.0
local NAME_FADE_OUT = 0.4
local NAME_TOTAL = NAME_FADE_IN + NAME_VISIBLE + NAME_FADE_OUT

local size = {
	hb_size_width,
	hb_size_height,
}

template.size = size
template.name = "enemy_debuff"
template.unit_node = "root_point"
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
	distance_max = 25,
	distance_min = 0.5,
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
local math_floor = math.floor
local pairs = pairs
local Localize = Localize

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

	local base_y = -bar_height - 8
	local row_step = bar_height + 8
	local icon_x = bar_width * 0.5 - 50
	local name_x = bar_width * 0.5 - 100
	local stack_x = bar_width * 0.5 + 20

	for i = 1, max_rows do
		local icon_bg_id = "debuff_icon_background_" .. i
		local icon_id = "debuff_icon_" .. i
		local stack_text_id = "stack_counter_" .. i
		local name_text_id = "debuff_name_" .. i

		local row_offset_y = base_y - ((i - 1) * row_step)

		content[icon_bg_id] = "content/ui/materials/effects/terminal_header_glow"
		content[icon_id] = ""
		content[stack_text_id] = ""
		content[name_text_id] = ""

		-- ICON BACKGROUND
		passes[#passes + 1] = {
			pass_type = "texture",
			style_id = icon_bg_id,
			value_id = icon_bg_id,
			visibility_function = function(content, style)
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
				4,
			},
			default_offset = {
				icon_x,
				row_offset_y,
				4,
			},
			color = { 20, 0, 0, 0 },
			size = { 30, 30 },
			default_size = { 30, 30 },
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
			default_offset = {
				icon_x,
				row_offset_y,
				6,
			},
			size = { 20, 20 },
			default_size = { 20, 20 },

			color = { 255, 255, 255, 255 },
		}

		-- STACK COUNTER
		passes[#passes + 1] = {
			pass_type = "text",
			style_id = stack_text_id,
			value_id = stack_text_id,
			visibility_function = function(content, style)
				local v = content[stack_text_id]
				return v ~= nil and v ~= ""
			end,
		}

		style[stack_text_id] = {
			horizontal_alignment = "right",
			vertical_alignment = "center",
			text_horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = {
				stack_x,
				row_offset_y,
				6,
			},
			default_offset = {
				stack_x,
				row_offset_y,
				6,
			},
			font_type = "proxima_nova_bold",
			font_size = 18,
			default_font_size = 18,

			text_color = { 0, 255, 255, 255 },
			size = { bar_width * 0.25, 20 },
			default_size = { bar_width * 0.25, 20 },

			drop_shadow = true,
			shadow_offset = { 1, -1 },
			shadow_color = { 200, 0, 0, 0 },
		}

		-- DEBUFF NAME
		passes[#passes + 1] = {
			pass_type = "text",
			style_id = name_text_id,
			value_id = name_text_id,
			visibility_function = function(content, style)
				if not show_names then
					return false
				end
				local v = content[name_text_id]
				return v ~= nil and v ~= ""
			end,
		}

		style[name_text_id] = {
			horizontal_alignment = "right",
			vertical_alignment = "center",
			text_horizontal_alignment = "right",
			text_vertical_alignment = "center",
			offset = {
				name_x,
				row_offset_y,
				7,
			},
			font_type = "proxima_nova_bold",
			font_size = 18,
			default_font_size = 18,

			text_color = { 0, 255, 255, 255 },
			size = { 260, 22 },
			default_size = { 260, 22 },

			truncated = true,
			max_lines = 1,

			drop_shadow = true,
			shadow_offset = { 1, -1 },
			shadow_color = { 200, 0, 0, 0 },
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
	local content = widget.content

	if not unit then
		marker.draw = false
		return
	end

	-- don't process hordes if disabled
	local breed_tags = mod.get_breed_tags(unit)
	if enable_horde == false and (breed_tags and (breed_tags.horde or breed_tags.roamer)) then
		marker.draw = false

		return
	end

	-------------------------------------------------------------------
	-- Breed / type
	-------------------------------------------------------------------
	local unit_data_extension = content.unit_data_extension or ScriptUnit_has_extension(unit, "unit_data_system")
	content.unit_data_extension = unit_data_extension
	local breed = content.breed or (unit_data_extension and unit_data_extension:breed())
	content.breed = breed

	local buff_extension = ScriptUnit.extension(unit, "buff_system")

	if not buff_extension then
		marker.draw = false
		return
	end

	local debuffs = buff_extension:buffs()
	local keywords = buff_extension and buff_extension:keywords()

	if not debuffs or #debuffs == 0 then
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

		if array_contains(mod.dot_debuffs, name) then
			local stacks = buff.stack_count and buff:stack_count() or buff.stacks and buff:stacks() or 1

			active_count = active_count + 1
			active[active_count] = {
				name = name,
				stacks = stacks,
			}
		end
	end

	-- get from keywords
	if keywords and #keywords > 0 then
		for i = 1, #keywords do
			local keyword = keywords[i]
			local name = keyword

			if array_contains(mod.dot_debuffs, name) then
				local stacks = 1

				active_count = active_count + 1
				active[active_count] = {
					name = name,
					stacks = stacks,
				}
			end
		end
	end

	if active_count == 0 then
		marker.draw = false
	end

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
		local y_base = -bar_height - 8 - ((index - 1) * row_height)

		local state = state_table[name]
		if not state then
			state = {
				alpha = 0,
				scale = 0,
				icon_scale = 1.25,
				prev_stacks = stacks,
				y = y_base,
				name_time = 0,
				name_visible = show_names,
			}
			state_table[name] = state
		end

		-- Fade in
		local alpha = state.alpha + dt * 255 * fade_speed
		state.alpha = (alpha < 255) and alpha or 255

		-- Target Y per debuff
		local target_y = y_base
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

		-- Update name pop timer if enabled
		if show_names and state.name_visible then
			state.name_time = state.name_time + dt
			if state.name_time >= NAME_TOTAL and names_fade == true then
				state.name_visible = false
			end
		end

		active_lookup[name] = true
		marker.draw = true
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
	-- Height / healthbar position logic
	-------------------------------------------------------------------
	local root_position = Unit.world_position(unit, 1)

	if not marker.world_position then
		root_position.z = root_position.z + content.breed.base_height
		marker.world_position = Vector3Box(root_position)
	else
		root_position.z = root_position.z + content.breed.base_height

		marker.world_position:store(root_position)
	end

	-------------------------------------------------------------------
	-- DRAW ROWS
	-------------------------------------------------------------------
	local template_size_1 = template.size[1]

	for i = 1, max_rows do
		local icon_id = "debuff_icon_" .. i
		local stack_text_id = "stack_counter_" .. i
		local name_text_id = "debuff_name_" .. i

		local icon_style = style[icon_id]
		local stack_text_style = style[stack_text_id]
		local name_text_style = style[name_text_id]

		local debuff = active[i]

		if debuff then
			local name = debuff.name
			local stacks = debuff.stacks
			local state = state_table[name]

			if state then
				-- Horizontal slide on appear
				local alpha_factor = state.alpha / 255
				local appear_offset = 15 * (alpha_factor - 1)

				local icon_offset_x = template_size_1 * 0.5 - 45 + appear_offset
				local stack_offset_x = template_size_1 * 0.5 + 20 + appear_offset
				local name_offset_x = template_size_1 * 0.5 - 70 + appear_offset

				icon_style.offset[1] = icon_offset_x
				icon_style.offset[2] = state.y

				stack_text_style.offset[1] = stack_offset_x
				stack_text_style.offset[2] = state.y

				if name_text_style then
					name_text_style.offset[1] = name_offset_x
					name_text_style.offset[2] = state.y
				end

				content[icon_id] = mod.debuff_icons and mod.debuff_icons[name]
					or "content/ui/materials/icons/generic/danger"

				content[stack_text_id] = "x " .. stacks

				if show_names then
					if state.name_visible and name_text_style then
						local loc_id = name
						content[name_text_id] = mod:localize(loc_id)

						-- compute name alpha based on timer
						local t_name = state.name_time or 0
						local a = 0

						if t_name <= NAME_FADE_IN then
							a = (t_name / NAME_FADE_IN) -- fade in
						elseif t_name <= NAME_FADE_IN + NAME_VISIBLE then
							a = 1 -- fully visible
						elseif t_name <= NAME_TOTAL then
							local remain = NAME_TOTAL - t_name
							a = remain / NAME_FADE_OUT -- fade out
						else
							a = 0
						end

						-- clamp & apply
						if a < 0 then
							a = 0
						elseif a > 1 then
							a = 1
						end

						name_text_style.text_color[1] = math_floor(255 * a + 0.5)
					else
						content[name_text_id] = ""
						if name_text_style then
							name_text_style.text_color[1] = 0
						end
					end
				else
					content[name_text_id] = ""
					if name_text_style then
						name_text_style.text_color[1] = 0
					end
				end

				-- colour mutation
				local colour = (mod.debuff_colours and mod.debuff_colours[name]) or { 255, 255, 255, 255 }

				local c = icon_style.color

				c[1] = state.alpha
				c[2] = colour[2] or colour[1] or 255
				c[3] = colour[3] or colour[2] or 255
				c[4] = colour[4] or colour[3] or 255

				-- Glow effect
				if stacks >= glow_threshold then
					c[1] = (c[1] + 40 < 255) and (c[1] + 40) or 255
					c[2] = (c[2] + 40 < 255) and (c[2] + 40) or 255
					c[3] = (c[3] + 40 < 255) and (c[3] + 40) or 255
				end

				-- Background moves with icon
				local bg_style = style["debuff_icon_background_" .. i]
				if bg_style then
					bg_style.offset[1] = icon_offset_x
					bg_style.offset[2] = state.y
				end

				-- change text scale
				local draw = marker.draw

				if draw then
					local scale = marker.scale

					local stack_counter = style["stack_counter_" .. i]

					if stack_counter then
						stack_counter.font_size = stack_counter.default_font_size * scale
					end

					local debuff_name = style["debuff_name_" .. i]

					if debuff_name then
						debuff_name.font_size = debuff_name.default_font_size * scale
					end
				end

				-- Stack pulse
				local scale = 1
				stack_text_style.font_size = stack_text_style.font_size * scale
				stack_text_style.text_color[1] = state.alpha

				-- Icon pulse
				--local icon_scale = marker.scale + state.icon_scale
				--icon_style.size[1] = icon_style.size[1] * icon_scale
				--icon_style.size[2] = icon_style.size[2] * icon_scale
			end
		else
			content[icon_id] = nil
			content[stack_text_id] = nil
			if name_text_style then
				content[name_text_id] = ""
				name_text_style.text_color[1] = 0
			end
		end
	end
end

return template
