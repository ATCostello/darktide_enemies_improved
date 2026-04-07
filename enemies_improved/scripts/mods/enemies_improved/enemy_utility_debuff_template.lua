local mod = get_mod("enemies_improved")

local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}

-----------------------------------------------------------------------
-- Cached settings
-----------------------------------------------------------------------
local fs = mod.frame_settings
local hb_size_width = fs.hb_size_width
local hb_size_height = fs.hb_size_height
local max_visible_rows_setting = 5
local draw_distance_setting = fs.draw_distance

local NAME_FADE_IN = 0.15
local NAME_VISIBLE = 4.0
local NAME_FADE_OUT = 1
local NAME_TOTAL = NAME_FADE_IN + NAME_VISIBLE + NAME_FADE_OUT

local size = {
	hb_size_width,
	hb_size_height,
}
local base_y = (fs.show_armor_types and hb_size_height + 56) or (hb_size_height + 32)

local row_step = hb_size_height + (24 * mod.text_scale)
local base_offset = (-hb_size_width * 0.5) * mod.text_scale
local icon_x = (hb_size_width - (5 * mod.text_scale))
local name_x = hb_size_width
local stack_x = hb_size_width + (60 * mod.text_scale)
local active_pool = {}

template.size = size
template.name = "enemy_utility_debuff"

if fs.debuff_show_on_body then
	template.unit_node = "root_point"
	template.position_offset = { 0, 0, 0 }
else
	template.unit_node = "root_point"
	template.position_offset = { 0, 0, 0 }
end

template.max_visible_rows = max_visible_rows_setting

template.check_line_of_sight = fs.check_line_of_sight
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
local ScriptUnit_extension = ScriptUnit.extension

-- O(1) lookup table (rebuilt only if mod.dot_debuffs changes)
local dot_lookup = {}

local function rebuild_dot_lookup()
	table.clear(dot_lookup)
	local list = mod.utility_debuffs
	if not list then
		return
	end

	for i = 1, #list do
		dot_lookup[list[i]] = true
	end
end

-- build once at load
rebuild_dot_lookup()

local localized_cache = {}
local stack_string_cache = {}
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

	for i = 1, max_rows do
		local icon_id = "util_icon_" .. i
		local stack_text_id = "stack_counter_" .. i
		local name_text_id = "util_name_" .. i

		local row_offset_y = base_y + ((i - 1) * row_step)

		content[icon_id] = nil
		content[stack_text_id] = ""
		content[name_text_id] = ""

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
			scale_to_material = true,
			horizontal_alignment = "right",
			vertical_alignment = "center",
			offset = {
				icon_x + base_offset,
				row_offset_y,
				6,
			},
			default_offset = {
				icon_x + base_offset,
				row_offset_y,
				6,
			},
			size = { 30 * mod.text_scale, 30 * mod.text_scale },
			default_size = { 30 * mod.text_scale, 30 * mod.text_scale },

			color = { 255, 255, 255, 255 },
			default_alpha = 255,
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
				stack_x + base_offset,
				row_offset_y,
				6,
			},
			default_offset = {
				stack_x + base_offset,
				row_offset_y,
				6,
			},
			font_type = mod.font_type,
			font_size = 16,
			default_font_size = 16,

			text_color = fs.secondary_colour or { 220, 220, 220, 220 },
			size = { bar_width * 0.25 * mod.text_scale, 20 },
			default_size = { bar_width * 0.25 * mod.text_scale, 20 },

			drop_shadow = true,
			shadow_offset = { 1, -1 },
			shadow_color = { 200, 0, 0, 0 },
			default_alpha = 255,
		}

		-- DEBUFF NAME
		passes[#passes + 1] = {
			pass_type = "text",
			style_id = name_text_id,
			value_id = name_text_id,
			visibility_function = function(content, style)
				if not fs.debuff_names then
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
				name_x - 40 * mod.text_scale + base_offset,
				row_offset_y,
				7,
			},
			default_offset = {
				name_x - 40 * mod.text_scale + base_offset,
				row_offset_y,
				7,
			},

			font_type = mod.font_type,
			font_size = 14,
			default_font_size = 14,

			text_color = fs.main_colour or { 220, 220, 220, 220 },
			size = { name_x * mod.text_scale, 22 },
			default_size = { name_x * mod.text_scale, 22 },

			truncated = true,
			max_lines = 1,

			drop_shadow = true,
			shadow_offset = { 1, -1 },
			shadow_color = { 200, 0, 0, 0 },
			default_alpha = 255,
		}
	end

	return {
		scenegraph_id = scenegraph_id,
		passes = passes,
		content = content,
		style = style,
	}
end

template.on_enter = function(widget, marker, template)
	local content = widget.content
	local style = widget.style
	local unit = marker.unit
	local unit_data_extension = ScriptUnit_extension(unit, "unit_data_system")
	local breed = unit_data_extension and unit_data_extension:breed()
	local buff_extension = ScriptUnit_extension(unit, "buff_system")

	content.breed_tags = mod.get_breed_tags(unit)
	content.unit_data_extension = unit_data_extension
	content.breed = breed
	content.debuffs = buff_extension:buffs()
	content.keywords = buff_extension and buff_extension:keywords()
end

-----------------------------------------------------------------------
-- Update function
-----------------------------------------------------------------------

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	widget._next_update = widget._next_update or 0
	if t < widget._next_update then
		return
	end
	widget._next_update = t + 0.02

	local unit = marker.unit
	local content = widget.content
	local need_sort = false
	local fs = mod.frame_settings

	if not unit then
		marker.draw = false
		return
	end

	-- don't process hordes if disabled
	if
		fs.debuff_horde_enable == false
		and (content.breed_tags and (content.breed_tags.horde or content.breed_tags.roamer))
	then
		marker.draw = false
		return
	end

	-------------------------------------------------------------------
	-- Breed / type
	-------------------------------------------------------------------
	local unit_data_extension = content.unit_data_extension
	local breed = content.breed
	local debuffs = content.debuffs
	local keywords = content.keywords

	if not debuffs or #debuffs == 0 then
		marker.draw = false
	else
		marker.draw = true
	end

	-- Gather active debuffs that we care about
	widget._active = widget._active or {}
	local active = widget._active
	local active_count = 0

	-- clear without reallocating
	for i = 1, #active do
		active[i] = nil
	end

	for i = 1, #debuffs do
		local buff = debuffs[i]
		local name = buff:template_name()

		if dot_lookup[name] then
			local stacks = buff.stack_count and buff:stack_count() or buff.stacks and buff:stacks() or 1

			active_count = active_count + 1
			local entry = active[active_count]
			if not entry then
				entry = active_pool[#active_pool]
				if entry then
					active_pool[#active_pool] = nil
				else
					entry = {}
				end
				active[active_count] = entry
			end

			entry.name = name
			entry.stacks = stacks
		end
	end

	for i = active_count + 1, #active do
		active_pool[#active_pool + 1] = active[i]
		active[i] = nil
	end

	-- get from keywords
	if keywords and #keywords > 0 then
		for i = 1, #keywords do
			local keyword = keywords[i]
			local name = keyword

			if dot_lookup[name] then
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
	if active_count > 1 and need_sort then
		table_sort(active, function(a, b)
			return a.stacks > b.stacks
		end)
	end

	local max_rows = template.max_visible_rows or 5
	local style = widget.style

	widget._state = widget._state or {}
	local state_table = widget._state

	local bar_height = template.size[2]
	local row_height = bar_height + 8

	local slide_speed = 16
	local fade_speed = 10
	local stack_speed = 8
	local glow_threshold = 5

	widget._active_lookup = widget._active_lookup or {}
	local active_lookup = widget._active_lookup

	for k in pairs(active_lookup) do
		active_lookup[k] = nil
	end

	-------------------------------------------------------------------
	-- UPDATE STATE (KEYED BY DEBUFF NAME)
	-------------------------------------------------------------------
	for index = 1, active_count do
		local debuff = active[index]
		local name = debuff.name
		local stacks = debuff.stacks
		local y_base = base_y + ((index - 1) * row_height)

		local state = state_table[name]
		if not state then
			state = {
				alpha = 0,
				scale = 0,
				icon_scale = 1.25,
				prev_stacks = stacks,
				y = y_base,
				name_time = 0,
				name_visible = fs.debuff_names,
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

		if stacks ~= state.prev_stacks then
			need_sort = true
		end

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
		if fs.debuff_names and state.name_visible then
			state.name_time = state.name_time + dt
			if state.name_time >= NAME_TOTAL and fs.debuff_names_fade == true then
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
	if content.breed and mod.detect_alive(unit) then
		local root_position = Unit.world_position(unit, 1)
		if not fs.debuff_show_on_body then
			root_position.z = root_position.z + content.breed.base_height + 0.5
		else
			root_position.z = root_position.z + content.breed.base_height / 1.5
		end
		if not marker.world_position then
			marker.world_position = Vector3Box(root_position)
		else
			marker.world_position:store(root_position)
		end
	end

	-------------------------------------------------------------------
	-- DRAW ROWS
	-------------------------------------------------------------------
	for i = 1, max_rows do
		local icon_id = "util_icon_" .. i
		local stack_text_id = "stack_counter_" .. i
		local name_text_id = "util_name_" .. i

		local icon_style = style[icon_id]
		local stack_text_style = style[stack_text_id]
		local name_text_style = style[name_text_id]

		local debuff = active[i]

		if debuff then
			local name = debuff.name
			local stacks = debuff.stacks
			local state = state_table[name]

			if state then
				content[icon_id] = mod.debuff_icons and mod.debuff_icons[name]
					or "content/ui/materials/icons/generic/danger"

				local stack_str = stack_string_cache[stacks]
				if not stack_str then
					stack_str = "x " .. stacks
					stack_string_cache[stacks] = stack_str
				end

				content[stack_text_id] = stack_str
				if fs.debuff_names then
					if state.name_visible and name_text_style then
						local loc = localized_cache[name]
						if not loc then
							loc = mod:localize(name) or ""
							localized_cache[name] = loc
						end

						content[name_text_id] = loc

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

						name_text_style.text_color[1] = (255 * a + 0.5)
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

				if not marker.is_inside_frustum then
					marker.draw = false
				end

				widget._last_scale = widget._last_scale or 0

				-- apply scaling
				if marker.draw then
					local scale = marker.scale

					if scale ~= widget._last_scale then
						widget._last_scale = scale

						icon_style.size[1] = icon_style.default_size[1] * scale
						icon_style.size[2] = icon_style.default_size[2] * scale

						stack_text_style.font_size = stack_text_style.default_font_size * scale
						name_text_style.font_size = name_text_style.default_font_size * scale

						icon_style.offset[1] = icon_style.default_offset[1] * scale
						icon_style.offset[2] = icon_style.default_offset[2] * scale

						stack_text_style.offset[1] = stack_text_style.default_offset[1] * scale
						stack_text_style.offset[2] = stack_text_style.default_offset[2] * scale

						name_text_style.offset[1] = name_text_style.default_offset[1] * scale
						name_text_style.offset[2] = name_text_style.default_offset[2] * scale
					end
				end
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
