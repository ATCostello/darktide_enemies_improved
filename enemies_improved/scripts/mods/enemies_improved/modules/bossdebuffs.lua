local mod = get_mod("enemies_improved")

local UIWidget = require("scripts/managers/ui/ui_widget")
local ScriptUnit_has_extension = ScriptUnit.has_extension
local ScriptUnit_extension = ScriptUnit.extension
local BuffSettings = require("scripts/settings/buff/buff_settings")
local stat_buff_types = BuffSettings.stat_buff_types

local table_sort = table.sort
local math_min = math.min
local math_max = math.max
local math_lerp = math.lerp
local math_floor = math.floor
local next = next

local MAX_ROWS = 10
local BOSS_DEBUFF_X_START = 50
local NAME_FADE_IN = 0.15
local NAME_VISIBLE = 4.0
local NAME_FADE_OUT = 1
local NAME_TOTAL = NAME_FADE_IN + NAME_VISIBLE + NAME_FADE_OUT

local pool = {}
local debuff_defs_cache

local function calc_stack_buff_percentage(val, stacks, stat_name)
	local stat_buff_type = stat_buff_types[stat_name]
	local perc = 0
	if stat_buff_type == "multiplicative_multiplier" then
		val = val - 1
		perc = (val * stacks) * 100
	elseif stat_buff_type == "additive_multiplier" then
		perc = (val * stacks) * 100
	end
	local nearest = math_floor((perc + 5) / 10) * 10
	if math.abs(perc - nearest) <= 1 then
		perc = nearest
	end
	return math_floor(perc * 10 + 0.5) * 0.1
end

local function create_boss_debuff_widget_definition()
	if debuff_defs_cache then
		return debuff_defs_cache
	end

	local passes = {}
	local content = {}
	local style = {}
	local base_y = 25
	local row_step = 30

	for i = 1, MAX_ROWS do
		local icon_id = "debuff_icon_" .. i
		local stack_text_id = "stack_counter_" .. i
		local name_text_id = "debuff_name_" .. i
		local row_offset_y = base_y + ((i - 1) * row_step)

		content[icon_id] = nil
		content[stack_text_id] = ""
		content[name_text_id] = ""

		passes[#passes + 1] = {
			pass_type = "texture",
			style_id = icon_id .. "_shadow",
			value_id = icon_id,
			visibility_function = function(content, style)
				return content[icon_id] ~= nil
			end,
		}
		style[icon_id .. "_shadow"] = {
			scale_to_material = true,
			horizontal_alignment = "left",
			vertical_alignment = "center",
			offset = { BOSS_DEBUFF_X_START + 1, row_offset_y + 1, 5 },
			default_offset = { BOSS_DEBUFF_X_START + 1, row_offset_y + 1, 5 },
			size = { 28, 28 },
			default_size = { 28, 28 },
			color = { 255, 0, 0, 0 },
			default_alpha = 255,
		}

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
			horizontal_alignment = "left",
			vertical_alignment = "center",
			offset = { BOSS_DEBUFF_X_START, row_offset_y, 6 },
			default_offset = { BOSS_DEBUFF_X_START, row_offset_y, 6 },
			size = { 27, 27 },
			default_size = { 27, 27 },
			color = { 255, 255, 255, 255 },
			default_alpha = 255,
		}

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
			horizontal_alignment = "left",
			vertical_alignment = "center",
			text_horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { BOSS_DEBUFF_X_START + 145, row_offset_y, 8 },
			default_offset = { BOSS_DEBUFF_X_START + 145, row_offset_y, 8 },
			font_type = "proxima_nova_bold",
			font_size = 14,
			default_font_size = 14,
			text_color = { 220, 220, 220, 220 },
			size = { 100, 20 },
			default_size = { 100, 20 },
			drop_shadow = true,
			shadow_offset = { 1, 1 },
			shadow_color = { 255, 0, 0, 0 },
			default_alpha = 255,
		}

		passes[#passes + 1] = {
			pass_type = "text",
			style_id = name_text_id,
			value_id = name_text_id,
			visibility_function = function(content, style)
				local v = content[name_text_id]
				return v ~= nil and v ~= ""
			end,
		}
		style[name_text_id] = {
			horizontal_alignment = "left",
			vertical_alignment = "center",
			text_horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { BOSS_DEBUFF_X_START + 35, row_offset_y, 7 },
			default_offset = { BOSS_DEBUFF_X_START + 35, row_offset_y, 7 },
			font_type = "proxima_nova_bold",
			font_size = 13,
			default_font_size = 13,
			text_color = { 200, 200, 200, 200 },
			size = { 110, 22 },
			default_size = { 110, 22 },
			truncated = true,
			max_lines = 1,
			drop_shadow = true,
			shadow_offset = { 1, 1 },
			shadow_color = { 255, 0, 0, 0 },
			default_alpha = 255,
		}
	end

	debuff_defs_cache = {
		scenegraph_id = "background",
		passes = passes,
		content = content,
		style = style,
	}
	return debuff_defs_cache
end

local function scan_boss_debuffs(unit, widget)
	local fs = mod.frame_settings
	local content = widget.content
	local buff_extension = ScriptUnit_has_extension(unit, "buff_system")

	if not buff_extension then
		return false
	end

	local keywords = buff_extension:keywords()
	local buffs = buff_extension:buffs()
	local active = widget._active or {}
	local active_count = 0
	local split_debuff_types = fs.split_debuff_types

	for i = 1, #active do
		active[i] = nil
	end

	if keywords then
		for keyword, _ in pairs(keywords) do
			local debuff_data = mod.debuffs[keyword]
			if debuff_data then
				local debuff_type = debuff_data.type
				if debuff_type == "dot" and fs.debuff_dot_enable ~= false then
					active_count = active_count + 1
					local entry = pool[#pool]
					if entry then
						pool[#pool] = nil
					else
						entry = {}
					end
					entry.name = keyword
					entry.stacks = 1
					entry.type = "dot"
					active[active_count] = entry
				elseif debuff_type == "utility" and fs.debuff_utility_enable ~= false then
					active_count = active_count + 1
					local entry = pool[#pool]
					if entry then
						pool[#pool] = nil
					else
						entry = {}
					end
					entry.name = keyword
					entry.stacks = 1
					entry.type = "utility"
					active[active_count] = entry
				end
			end
		end
	end

	if buffs then
		for i = 1, #buffs do
			local buff = buffs[i]
			local name = buff:template_name()
			local debuff_data = mod.debuffs[name]
			if debuff_data then
				local debuff_type = debuff_data.type
				if debuff_type == "dot" and fs.debuff_dot_enable ~= false then
					local stacks = buff.stack_count and buff:stack_count() or buff.stacks and buff:stacks() or 1
					active_count = active_count + 1
					local entry = active[active_count]
					if not entry then
						entry = pool[#pool]
						if entry then
							pool[#pool] = nil
						else
							entry = {}
						end
						active[active_count] = entry
					end
					local template = buff:template()
					entry.name = name
					entry.stacks = stacks
					entry.max_stacks = template.max_stacks
					entry.stat_buffs = template.stat_buffs
					entry.conditional_stat_buffs = template.conditional_stat_buffs
					entry.type = "dot"
				elseif debuff_type == "utility" and fs.debuff_utility_enable ~= false then
					local stacks = buff.stack_count and buff:stack_count() or buff.stacks and buff:stacks() or 1
					active_count = active_count + 1
					local entry = active[active_count]
					if not entry then
						entry = pool[#pool]
						if entry then
							pool[#pool] = nil
						else
							entry = {}
						end
						active[active_count] = entry
					end
					local template = buff:template()
					if name == "increase_damage_taken" then
						template.max_stacks = 1
					end
					entry.name = name
					entry.stacks = stacks
					entry.max_stacks = template.max_stacks
					entry.stat_buffs = template.stat_buffs
					entry.conditional_stat_buffs = template.conditional_stat_buffs
					entry.type = "utility"
				end
			end
		end
	end

	for i = active_count + 1, #active do
		pool[#pool + 1] = active[i]
		active[i] = nil
	end

	-- Combine same-type debuffs
	if fs.debuffs_combine and active_count > 1 then
		local combined_count = 0
		local combined = widget._combined or {}
		local grouped_dot_map = widget._grouped_dot or {}
		local grouped_utility_map = widget._grouped_util or {}

		for k in next, grouped_dot_map do grouped_dot_map[k] = nil end
		for k in next, grouped_utility_map do grouped_utility_map[k] = nil end

		for i = 1, active_count do
			local entry = active[i]
			local name = entry.name
			local max_stacks = entry.max_stacks
			local icon = mod.debuffs and mod.debuffs[name] and mod.debuffs[name].group
				and mod.debuff_styles[mod.debuffs[name].group]
				and mod.debuff_styles[mod.debuffs[name].group].icon or nil
			local debuff_type = entry.type

			icon = icon or name
			local existing

			if debuff_type == "dot" then
				existing = grouped_dot_map[icon]
			elseif debuff_type == "utility" then
				existing = grouped_utility_map[icon]
			end

			if existing then
				existing.stacks = (existing.stacks or 0) + (entry.stacks or 0)
				existing.max_stacks = (existing.max_stacks or 0) + (entry.max_stacks or 0)
				local duration = nil
				if existing.duration or entry.duration then
					duration = (existing.duration or 0) + (entry.duration or 0)
				end
				existing.duration = duration
				existing.stat_buffs = existing.stat_buffs or entry.stat_buffs
				existing.conditional_stat_buffs = existing.conditional_stat_buffs or entry.conditional_stat_buffs

				if entry.stat_buffs then
					existing._stat_total = existing._stat_total or {}
					for stat_name, val in pairs(entry.stat_buffs) do
						local effective_stacks = math.min(entry.stacks or 1, entry.max_stacks or math.huge)
						local sbt = stat_buff_types[stat_name]
						if sbt == "multiplicative_multiplier" then
							existing._stat_total[stat_name] = (existing._stat_total[stat_name] or 0) + (val - 1) * effective_stacks
						else
							existing._stat_total[stat_name] = (existing._stat_total[stat_name] or 0) + val * effective_stacks
						end
					end
				end
				if entry.conditional_stat_buffs then
					existing._conditional_stat_total = existing._conditional_stat_total or {}
					for stat_name, val in pairs(entry.conditional_stat_buffs) do
						local effective_stacks = math.min(entry.stacks or 1, entry.max_stacks or math.huge)
						local sbt = stat_buff_types[stat_name]
						if sbt == "multiplicative_multiplier" then
							existing._conditional_stat_total[stat_name] = (existing._conditional_stat_total[stat_name] or 0) + (val - 1) * effective_stacks
						else
							existing._conditional_stat_total[stat_name] = (existing._conditional_stat_total[stat_name] or 0) + val * effective_stacks
						end
					end
				end
			else
				combined_count = combined_count + 1
				local new_entry = {
					name = name,
					stacks = entry.stacks,
					max_stacks = entry.max_stacks,
					duration = entry.duration,
					stat_buffs = entry.stat_buffs,
					conditional_stat_buffs = entry.conditional_stat_buffs,
					combined = true,
					type = debuff_type,
				}
				if entry.stat_buffs then
					local stat_total = {}
					for stat_name, val in pairs(entry.stat_buffs) do
						local effective_stacks = math.min(entry.stacks or 1, entry.max_stacks or math.huge)
						local sbt = stat_buff_types[stat_name]
						if sbt == "multiplicative_multiplier" then
							stat_total[stat_name] = (val - 1) * effective_stacks
						else
							stat_total[stat_name] = val * effective_stacks
						end
					end
					new_entry._stat_total = stat_total
				end
				if entry.conditional_stat_buffs then
					local conditional_stat_total = {}
					for stat_name, val in pairs(entry.conditional_stat_buffs) do
						local effective_stacks = math.min(entry.stacks or 1, entry.max_stacks or math.huge)
						local sbt = stat_buff_types[stat_name]
						if sbt == "multiplicative_multiplier" then
							conditional_stat_total[stat_name] = (val - 1) * effective_stacks
						else
							conditional_stat_total[stat_name] = val * effective_stacks
						end
					end
					new_entry._conditional_stat_total = conditional_stat_total
				end
				combined[combined_count] = new_entry
				if debuff_type == "dot" then
					grouped_dot_map[icon] = new_entry
				elseif debuff_type == "utility" then
					grouped_utility_map[icon] = new_entry
				end
			end
		end

		for i = 1, combined_count do
			active[i] = combined[i]
		end
		for i = combined_count + 1, active_count do
			active[i] = nil
		end
		active_count = combined_count
	end

	if active_count > 0 then
		table_sort(active, function(a, b)
			return a.stacks > b.stacks
		end)
	end

	widget._active = active
	widget._active_count = active_count
	return active_count > 0
end

local function update_debuff_display(dt, t, widget)
	local fs = mod.frame_settings
	local content = widget.content
	local style = widget.style
	local state_table = widget._state or {}
	local active = widget._active or {}
	local active_count = widget._active_count or 0

	local slide_speed = 16
	local fade_speed = 10
	local stack_speed = 8

	local active_lookup = {}

	for index = 1, active_count do
		local debuff = active[index]
		local name = debuff.name
		local stacks = debuff.stacks
		local duration = debuff.duration
		local max_stacks = debuff.max_stacks
		local stat_buffs = debuff.stat_buffs
		local conditional_stat_buffs = debuff.conditional_stat_buffs
		local y_base = 0

		if fs.split_debuff_types then
			if debuff.type == "dot" then
				y_base = -35
			elseif debuff.type == "utility" then
				y_base = 25
			end
		end

		local state = state_table[name]
		if not state then
			state = {
				alpha = 0,
				scale = 0,
				icon_scale = 1.25,
				prev_stacks = stacks,
				y = y_base,
				name_time = 0,
				name_visible = true,
			}
			state_table[name] = state
		end

		local alpha = state.alpha + dt * 255 * fade_speed
		state.alpha = (alpha < 255) and alpha or 255

		local lerp_t = dt * slide_speed
		if lerp_t > 1 then lerp_t = 1 end
		state.y = math_lerp(state.y, y_base, lerp_t)

		if stacks ~= state.prev_stacks then
			if stacks > state.prev_stacks then
				state.scale = 1
			elseif stacks < state.prev_stacks then
				state.scale = -0.5
			end
		end
		state.prev_stacks = stacks

		local stack_lerp_t = dt * stack_speed
		if stack_lerp_t > 1 then stack_lerp_t = 1 end
		state.scale = math_lerp(state.scale, 0, stack_lerp_t)

		local icon_lerp_t = dt * 6
		if icon_lerp_t > 1 then icon_lerp_t = 1 end
		state.icon_scale = math_lerp(state.icon_scale, 0, icon_lerp_t)

		if fs.debuff_names and state.name_visible then
			state.name_time = state.name_time + dt
			if state.name_time >= NAME_TOTAL and fs.debuff_names_fade == true then
				state.name_visible = false
			end
		end

		active_lookup[name] = true
	end

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

	widget._state = state_table

	-- Draw rows
	local dot_index = 0
	local util_index = 0
	local is_horizontal = true
	local col_step = 60

	for i = 1, MAX_ROWS do
		local icon_id = "debuff_icon_" .. i
		local stack_text_id = "stack_counter_" .. i
		local name_text_id = "debuff_name_" .. i

		local icon_style = style[icon_id]
		local icon_shadow_style = style[icon_id .. "_shadow"]
		local stack_text_style = style[stack_text_id]
		local name_text_style = style[name_text_id]

		local debuff = active[i]

		if debuff then
			local row_i
			if fs.split_debuff_types then
				if debuff.type == "dot" then
					dot_index = dot_index + 1
					row_i = dot_index
				elseif debuff.type == "utility" then
					util_index = util_index + 1
					row_i = util_index
				end
			else
				row_i = i
			end

			local name = debuff.name
			local state = state_table[name]
			local stacks = debuff.stacks
			local duration = debuff.duration
			local max_stacks = debuff.max_stacks
			local stat_buffs = debuff.stat_buffs
			local conditional_stat_buffs = debuff.conditional_stat_buffs

			local col_offset = (row_i - 1) * col_step
			local row_offset_y

			if fs.split_debuff_types then
				if debuff.type == "dot" then
					row_offset_y = -35
				else
					row_offset_y = 35
				end
			else
				row_offset_y = 35
			end

			if is_horizontal then
				local o = icon_shadow_style.offset
				o[1] = BOSS_DEBUFF_X_START + 1 + col_offset
				o[2] = row_offset_y + 1
				o = icon_shadow_style.default_offset
				o[1] = BOSS_DEBUFF_X_START + 1 + col_offset
				o[2] = row_offset_y + 1

				o = icon_style.offset
				o[1] = BOSS_DEBUFF_X_START + col_offset
				o[2] = row_offset_y
				o = icon_style.default_offset
				o[1] = BOSS_DEBUFF_X_START + col_offset
				o[2] = row_offset_y

				o = stack_text_style.offset
				o[1] = BOSS_DEBUFF_X_START + 32 + col_offset
				o[2] = row_offset_y
				o = stack_text_style.default_offset
				o[1] = BOSS_DEBUFF_X_START + 32 + col_offset
				o[2] = row_offset_y

				content[name_text_id] = ""
			else
				row_offset_y = 25 + ((row_i - 1) * 30)

				if fs.split_debuff_types then
					if debuff.type == "dot" then
						row_offset_y = -35 + ((row_i - 1) * 30)
					elseif debuff.type == "utility" then
						row_offset_y = 25 + ((row_i - 1) * 30)
					end
				end

				local o = icon_shadow_style.offset
				o[1] = BOSS_DEBUFF_X_START + 1
				o[2] = row_offset_y + 1
				o = icon_shadow_style.default_offset
				o[1] = BOSS_DEBUFF_X_START + 1
				o[2] = row_offset_y + 1

				o = icon_style.offset
				o[1] = BOSS_DEBUFF_X_START
				o[2] = row_offset_y
				o = icon_style.default_offset
				o[1] = BOSS_DEBUFF_X_START
				o[2] = row_offset_y

				o = stack_text_style.offset
				o[1] = BOSS_DEBUFF_X_START + 145
				o[2] = row_offset_y
				o = stack_text_style.default_offset
				o[1] = BOSS_DEBUFF_X_START + 145
				o[2] = row_offset_y

				o = name_text_style.offset
				o[1] = BOSS_DEBUFF_X_START + 35
				o[2] = row_offset_y
				o = name_text_style.default_offset
				o[1] = BOSS_DEBUFF_X_START + 35
				o[2] = row_offset_y
			end

			local at_max_stacks = false
			if not duration and max_stacks and stacks >= max_stacks then
				stacks = max_stacks
				at_max_stacks = true
			end

			if state then
				local debuff_group = mod.debuffs and mod.debuffs[name] and mod.debuffs[name].group
				local debuff_icon = debuff_group and mod.debuff_styles[debuff_group] and mod.debuff_styles[debuff_group].icon
				content[icon_id] = debuff_icon or "content/ui/materials/icons/generic/danger"

				-- Percentage calculation
				local stack_buff_percentage = ""

				if debuff.combined and debuff._stat_total then
					for stat_name, total_val in pairs(debuff._stat_total) do
						if stat_name and total_val then
							local perc = total_val * 100
							local nearest = math_floor((perc + 5) / 10) * 10
							if math.abs(perc - nearest) <= 1 then perc = nearest end
							stack_buff_percentage = math_floor(perc * 10 + 0.5) * 0.1
						end
					end
				elseif debuff.combined and debuff._conditional_stat_total then
					for stat_name, total_val in pairs(debuff._conditional_stat_total) do
						if stat_name and total_val then
							local perc = total_val * 100
							local nearest = math_floor((perc + 5) / 10) * 10
							if math.abs(perc - nearest) <= 1 then perc = nearest end
							stack_buff_percentage = math_floor(perc * 10 + 0.5) * 0.1
						end
					end
				elseif stat_buffs then
					for stat_name, val in next, stat_buffs do
						if stat_name and val then
							stack_buff_percentage = calc_stack_buff_percentage(val, stacks, stat_name)
						end
					end
				elseif conditional_stat_buffs then
					for stat_name, val in next, conditional_stat_buffs do
						if stat_name and val then
							stack_buff_percentage = calc_stack_buff_percentage(val, stacks, stat_name)
						end
					end
				end

				local stack_str = ""
				if duration then
					stack_str = duration .. "s"
				elseif stack_buff_percentage ~= "" then
					stack_str = stack_buff_percentage .. "%"
				else
					if fs.debuff_stacks_show_x then
						if fs.debuff_stacks_show_x_space then
							stack_str = "x " .. stacks
						else
							stack_str = "x" .. stacks
						end
					else
						stack_str = tostring(stacks)
					end
				end
				content[stack_text_id] = stack_str

				if is_horizontal then
				content[name_text_id] = ""
			elseif fs.debuff_names then
				if state.name_visible then
					local loc = ""
					if fs.debuffs_abrv then
						loc = mod.custom_localize(name .. "_abrv")
					else
						loc = mod.custom_localize(name)
					end
					if loc == "" or loc == nil or string.starts(tostring(loc), "<") then
						loc = mod.custom_localize(name)
					end
					if debuff.combined then
						loc = string.gsub(loc, "%s*%b()%s*", "")
						loc = string.gsub(loc, "%s+$", "")
					end
					content[name_text_id] = loc
				else
					content[name_text_id] = ""
				end
			else
				content[name_text_id] = ""
			end

				local colour = debuff_group and mod.debuff_styles[debuff_group] and mod.debuff_styles[debuff_group].colour
					or { 255, 255, 255, 255 }

				icon_style.color[2] = colour[2] or 255
				icon_style.color[3] = colour[3] or 255
				icon_style.color[4] = colour[4] or 255

				if fs.debuff_stagger_enable and mod.debuffs[name] and mod.debuffs[name].group == "stagger" then
					icon_style.color[2] = fs.outline_stagger_colour[2] or 100
					icon_style.color[3] = fs.outline_stagger_colour[3] or 200
					icon_style.color[4] = fs.outline_stagger_colour[4] or 255
				end

				if fs.debuff_max_stacks_colour_toggle and at_max_stacks then
					stack_text_style.text_color[2] = fs.debuff_max_stacks_colour[2] or 255
					stack_text_style.text_color[3] = fs.debuff_max_stacks_colour[3] or 255
					stack_text_style.text_color[4] = fs.debuff_max_stacks_colour[4] or 255
				elseif fs.debuff_stacks_icon_colour then
					stack_text_style.text_color[2] = colour[2] or 255
					stack_text_style.text_color[3] = colour[3] or 255
					stack_text_style.text_color[4] = colour[4] or 255
				else
					stack_text_style.text_color[2] = fs.secondary_colour[2] or 220
					stack_text_style.text_color[3] = fs.secondary_colour[3] or 220
					stack_text_style.text_color[4] = fs.secondary_colour[4] or 220
				end
			end
		else
			content[icon_id] = nil
			content[stack_text_id] = nil
			content[name_text_id] = nil
		end
	end
end

-- Hooks

mod:hook_safe("HudElementBossHealth", "init", function(self, parent, draw_layer, start_scale)
	local groups = self._widget_groups
	if not groups then
		return
	end

	local def = create_boss_debuff_widget_definition()

	for i = 1, #groups do
		groups[i].boss_debuff = self:_create_widget("boss_debuffs_" .. i, def)
		groups[i].boss_debuff._active = {}
		groups[i].boss_debuff._active_count = 0
		groups[i].boss_debuff._state = {}
		groups[i].boss_debuff._combined = {}
		groups[i].boss_debuff._grouped_dot = {}
		groups[i].boss_debuff._grouped_util = {}
	end
end)

mod:hook_safe("HudElementBossHealth", "update", function(self, dt, t, ui_renderer, render_settings, input_service)
	local fs = mod.frame_settings

	if not fs.hb_toggle_base_boss_healthbar then
		self:_set_active(false)
	end
	
	if not fs.debuff_boss_healthbar_enable or not fs.debuff_enable or not self._is_active then
		return
	end

	local widget_groups = self._widget_groups
	local active_targets_array = self._active_targets_array
	if not widget_groups or not active_targets_array then
		return
	end

	local num_active_targets = #active_targets_array
	local num_health_bars_to_update = math.min(num_active_targets, self._max_health_bars or 2)

	for i = 1, num_health_bars_to_update do
		local widget_group_index = num_active_targets > 1 and i + 1 or i
		local widget_group = widget_groups[widget_group_index]
		local target = active_targets_array[i]
		local unit = target and target.unit

		if unit and ALIVE[unit] then
			local debuff_widget = widget_group and widget_group.boss_debuff
			if debuff_widget then
				scan_boss_debuffs(unit, debuff_widget)
				update_debuff_display(dt, t, debuff_widget)
			end
		end
	end
end)

mod:hook_safe("HudElementBossHealth", "event_boss_encounter_end", function(self, unit, boss_extension)
	local widget_groups = self._widget_groups
	if not widget_groups then
		return
	end
	for i = 1, #widget_groups do
		local widget = widget_groups[i] and widget_groups[i].boss_debuff
		if widget then
			for j = 1, MAX_ROWS do
				widget.content["debuff_icon_" .. j] = nil
				widget.content["stack_counter_" .. j] = nil
				widget.content["debuff_name_" .. j] = nil
			end
			widget._active = {}
			widget._active_count = 0
			widget._state = {}
		end
	end
end)
