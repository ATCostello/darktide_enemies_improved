local mod = get_mod("enemies_improved")

local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}
local BuffSettings = require("scripts/settings/buff/buff_settings")
local stat_buff_types = BuffSettings.stat_buff_types
local MinionState = require("scripts/utilities/minion_state")

-----------------------------------------------------------------------
-- Cached settings
-----------------------------------------------------------------------
local NAME_FADE_IN = 0.15
local NAME_VISIBLE = 4.0
local NAME_FADE_OUT = 1
local NAME_TOTAL = NAME_FADE_IN + NAME_VISIBLE + NAME_FADE_OUT

local max_visible_rows_setting = 10
local fs = mod.frame_settings

local function calculate_icon_size()
	if fs.debuff_icon_scale < 1 then
		return 0
	else
		return 13 * fs.debuff_icon_scale
	end
end

local hb_size_width = fs.hb_size_width
local hb_size_height = fs.hb_size_height
local draw_distance_setting = fs.draw_distance_broadphase or fs.draw_distance
local size = {
	200,
	hb_size_height,
}
local base_y = (fs.hb_text_top_left_01 and -hb_size_height - 40) or (-hb_size_height - 16)
local row_step = (hb_size_height + 8 * fs.debuff_gap_padding_scale) + (calculate_icon_size()) * fs.text_scale
local col_step = (calculate_icon_size() + (20 * fs.debuff_gap_padding_scale)) * fs.text_scale
local base_offset = (-size[1] * fs.debuff_x_offset) * fs.text_scale
local base_gap = -40 * fs.text_scale
local name_x = (size[1] - 25) * fs.text_scale + base_gap
local icon_x = (size[1] + (1 * (fs.debuff_gap_name_icon_offset * 10))) * fs.text_scale + base_gap
local stack_x = (size[1] + (120 * fs.debuff_gap_icon_stack_offset)) * fs.text_scale + base_gap
if fs.debuff_stack_on_icon then
	stack_x = ((size[1] + (100 * fs.debuff_gap_icon_stack_offset)) + (calculate_icon_size())) * fs.text_scale + base_gap
end

local active_pool = {}

template.size = size
template.name = "enemy_debuff"

template.unit_node = "root_point"
template.position_offset = { 0, 0, fs.hb_y_offset }


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
local next = next
local Localize = Localize
local ScriptUnit_extension = ScriptUnit.extension

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
		local icon_id = "debuff_icon_" .. i
		local stack_text_id = "stack_counter_" .. i
		local name_text_id = "debuff_name_" .. i

		local row_offset_y = base_y - ((i - 1) * row_step)

		content[icon_id] = nil
		content[stack_text_id] = ""
		content[name_text_id] = ""

		-- ICON SHADOW
		passes[#passes + 1] = {
			pass_type = "texture",
			style_id = icon_id .. "_shadow",
			value_id = icon_id,
			visibility_function = function(content, style)
				return content.dbf_built and content[icon_id] ~= nil and fs.debuff_icons
			end,
		}

		style[icon_id .. "_shadow"] = {
			scale_to_material = true,
			horizontal_alignment = "right",
			vertical_alignment = "center",

			offset = {
				icon_x + base_offset + 1,
				row_offset_y + 1,
				5,
			},

			default_offset = {
				icon_x + base_offset + 1,
				row_offset_y + 1,
				5,
			},

			size = {
				28 * fs.debuff_icon_scale * fs.text_scale,
				28 * fs.debuff_icon_scale * fs.text_scale,
			},

			default_size = {
				28 * fs.debuff_icon_scale * fs.text_scale,
				28 * fs.debuff_icon_scale * fs.text_scale,
			},

			color = { 255, 0, 0, 0 },
			default_alpha = 255,
		}

		-- ICON
		passes[#passes + 1] = {
			pass_type = "texture",
			style_id = icon_id,
			value_id = icon_id,
			visibility_function = function(content, style)
				return content.dbf_built and content[icon_id] ~= nil and fs.debuff_icons
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
			size = { 27 * fs.debuff_icon_scale * fs.text_scale, 27 * fs.debuff_icon_scale * fs.text_scale },
			default_size = { 27 * fs.debuff_icon_scale * fs.text_scale, 27 * fs.debuff_icon_scale * fs.text_scale },

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
				return content.dbf_built and v ~= nil and v ~= ""
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
				8,
			},
			default_offset = {
				stack_x + base_offset,
				row_offset_y,
				8,
			},
			font_type = mod.font_type,
			font_size = fs.debuff_stacks_font_size * fs.text_scale,
			default_font_size = fs.debuff_stacks_font_size * fs.text_scale,

			text_color = fs.secondary_colour or { 220, 220, 220, 220 },
			size = { bar_width * 0.5 * fs.text_scale, 20 },
			default_size = { bar_width * 0.5 * fs.text_scale, 20 },

			drop_shadow = true,
			shadow_offset = { 1, 1 },
			shadow_color = { 255, 0, 0, 0 },
			default_alpha = 255,
		}

		-- DEBUFF NAME
		passes[#passes + 1] = {
			pass_type = "text",
			style_id = name_text_id,
			value_id = name_text_id,
			visibility_function = function(content, style)
				if fs.debuff_horizontal then
					return false
				end
				if not fs.debuff_names then
					return false
				end
				local v = content[name_text_id]
				return content.dbf_built and v ~= nil and v ~= ""
			end,
		}

		style[name_text_id] = {
			horizontal_alignment = "right",
			vertical_alignment = "center",
			text_horizontal_alignment = "right",
			text_vertical_alignment = "center",
			offset = {
				name_x + base_offset,
				row_offset_y,
				7,
			},
			default_offset = {
				name_x + base_offset,
				row_offset_y,
				7,
			},

			font_type = mod.font_type,
			font_size = fs.debuff_names_font_size * fs.text_scale,
			default_font_size = fs.debuff_names_font_size * fs.text_scale,

			text_color = fs.main_colour or { 220, 220, 220, 220 },
			size = { (name_x * 2) * fs.text_scale, 22 },
			default_size = { (name_x * 2) * fs.text_scale, 22 },

			truncated = true,
			max_lines = 1,

			drop_shadow = true,
			shadow_offset = { 1, 1 },
			shadow_color = { 255, 0, 0, 0 },
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
	local fs = mod.frame_settings

	template.position_offset = { 0, 0, fs.hb_y_offset }


	local content = widget.content
	local style = widget.style
	local unit = marker.unit
	local unit_data_extension = ScriptUnit_extension(unit, "unit_data_system")
	local breed = unit_data_extension and unit_data_extension:breed()
	local buff_extension = ScriptUnit_extension(unit, "buff_system")
	content.dbf_built = false
	content.draw_dbf  = false

	hb_size_width = fs.hb_size_width
	hb_size_height = fs.hb_size_height
	draw_distance_setting = fs.draw_distance_broadphase or fs.draw_distance
	size = {
		200,
		hb_size_height,
	}
	base_y = (fs.hb_text_top_left_01 and -hb_size_height - 80) * fs.debuff_y_offset
		or (-hb_size_height - 16) * fs.debuff_y_offset
	row_step = (hb_size_height + 8 * fs.debuff_gap_padding_scale) + (calculate_icon_size()) * fs.text_scale

	base_offset = (-size[1] * fs.debuff_x_offset) * fs.text_scale

	if fs.debuff_horizontal then
		base_offset = (-hb_size_width * 3 * fs.debuff_x_offset) * fs.text_scale
	end

	base_gap = -40 * fs.text_scale
	name_x = (size[1] - 15) * fs.text_scale + base_gap
	icon_x = ((size[1] + (1 * (fs.debuff_gap_name_icon_offset * 15))) + (calculate_icon_size())) * fs.text_scale
		+ base_gap
	stack_x = ((size[1] + (fs.debuff_gap_icon_stack_offset * 20)) + (calculate_icon_size())) * fs.text_scale - base_gap

	if fs.debuff_stack_on_icon then
		stack_x = ((size[1] + ((fs.debuff_gap_name_icon_offset * 10))) + (calculate_icon_size() * 2)) * fs.text_scale - base_gap
	end

	if fs.debuff_stack_on_icon then
		col_step = ((calculate_icon_size() + (30 * fs.debuff_gap_padding_scale))) * fs.text_scale
	else
		col_step = ((calculate_icon_size() + (60 * fs.debuff_gap_padding_scale))) * fs.text_scale
	end

	content.breed_tags = mod.get_breed_tags(unit)
	content.unit_data_extension = unit_data_extension
	content.breed = breed
	content.debuffs = buff_extension and buff_extension:buffs()
	content.keywords = buff_extension and buff_extension:keywords()
end

-- debug function to monitor the actual amount of buffs applied to enemies (So it can be checked against my calculations)
--[[
mod:hook_safe(CLASS.Buff, "_calculate_stat_buffs", function(self, current_stat_buffs, stat_buffs, conditional)
	if not stat_buffs then
		return
	end
	dbg_a = current_stat_buffs
end)
]]


-- Calculate the stack buff percentage (Clamped to nearest 10 if close enough due to rounding)
local function calc_stack_buff_percentage(val, stacks, stat_name)
	local stat_buff_type = stat_buff_types[stat_name]
	local perc = 0

	if stat_buff_type == "multiplicative_multiplier" then
		perc = (val ^ stacks - 1) * 100
	elseif stat_buff_type == "additive_multiplier" then
		perc = (val * stacks) * 100
	end

	local nearest = math_floor((perc + 5) / 10) * 10
	if math.abs(perc - nearest) <= 1 then
		perc = nearest
	end

	return math_floor(perc * 10 + 0.5) * 0.1
end

-----------------------------------------------------------------------
-- Update function
-----------------------------------------------------------------------

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	if not marker or not widget then
		return
	end

	widget._next_update = widget._next_update or 0
	if t < widget._next_update then
		return
	end

	-- if not on screen or draw == false, throttle heavily....
	if not marker.is_inside_frustum then
		widget._next_update = t + fs.off_screen_throttle_rate
		return
	-- distance based updates
	elseif marker.distance < 50 then
		widget._next_update = t + fs.general_throttle_rate
	elseif marker.distance < 70 then
		widget._next_update = t + fs.general_throttle_rate * 1.5
	else
		widget._next_update = t + fs.general_throttle_rate * 2
	end

	local unit = marker.unit
	local content = widget.content

	local need_sort = false
	local fs = mod.frame_settings

	content.draw_dbf  = true
	content.dbf_built = false
	
	if not unit then
		content.dbf_built  = false
		return
	end

	local is_alive = mod.detect_alive(unit)

	if not is_alive then
		content.dead = true
		content.dbf_built = false
		return
	end

	-- don't process hordes if disabled
	if
		fs.debuff_horde_enable == false
		and (content.breed_tags and (content.breed_tags.horde or content.breed_tags.roamer))
	then
		content.dbf_built  = false
		return
	end

	local line_of_sight_progress = content.line_of_sight_progress or 0

	if template.check_line_of_sight then
		if marker.raycast_initialized then
			local raycast_result = marker.raycast_result
			local line_of_sight_speed = 8

			if raycast_result then
				line_of_sight_progress = math.max(line_of_sight_progress - dt * line_of_sight_speed, 0)
			else
				line_of_sight_progress = math.min(line_of_sight_progress + dt * line_of_sight_speed, 1)
			end
		end
	elseif not template.check_line_of_sight then
		line_of_sight_progress = 1
	end

	local split_debuff_types = fs.split_debuff_types

	-------------------------------------------------------------------
	-- Breed / type
	-------------------------------------------------------------------
	local unit_data_extension = content.unit_data_extension
	local breed = content.breed
	local debuffs = content.debuffs or {}
	local keywords = content.keywords or {}
	--dbg_b =content
	
	local entry = mod.enemy_cache[unit]

	-- Per-individual debuff toggle (explicit disable overrides type)
	local breed_name = entry and entry.breed_name
	if breed_name and fs.breed_debuff_toggle[breed_name] == false then
		content.dbf_built  = false
		return
	end

	-- Per-type debuff toggle
	local breed_type = entry and entry.breed_type
	if breed_type and fs.breed_type_debuff_enabled[breed_type] == false then
		content.dbf_built  = false
		return
	end

	-- Gather active debuffs that we care about
	widget._active = widget._active or {}
	local active = widget._active
	local active_count = 0

	-- clear without reallocating
	for i = 1, #active do
		active[i] = nil
	end

	-- get from keywords
	if keywords then
		for keyword, _ in pairs(keywords) do
			local name = keyword
			
			-- DOT STUFF
			if mod.debuffs[name] and mod.debuffs[name].type == "dot" and fs.debuff_dot_enable then
				local stacks = 1

				active_count = active_count + 1
				local entry = active_pool[#active_pool]
				if entry then
					active_pool[#active_pool] = nil
				else
					entry = {}
				end

				entry.name = name
				entry.stacks = stacks
				entry.max_stacks = 1
				entry.type = "dot"

				active[active_count] = entry
			end

			-- UTILITY STUFF
			if mod.debuffs[name] and mod.debuffs[name].type == "utility" and fs.debuff_utility_enable then
				local stacks = 1

				active_count = active_count + 1
				local entry = active_pool[#active_pool]
				if entry then
					active_pool[#active_pool] = nil
				else
					entry = {}
				end

				entry.name = name
				entry.stacks = stacks
				entry.max_stacks = 1
				entry.type = "utility"

				active[active_count] = entry
			end
		end
	end

	-- Get from debuffs
	for i = 1, #debuffs do
		local buff = debuffs[i]
		local name = buff:template_name()
		local template = buff:template()
		local stat_buffs = template.stat_buffs
		local conditional_stat_buffs = template.conditional_stat_buffs

		-- DOT STUFF
		if mod.debuffs[name] and mod.debuffs[name].type == "dot" and fs.debuff_dot_enable then
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

			local real_max = buff.max_stacks and buff:max_stacks() or template.max_stacks

			entry.name = name
			entry.stacks = stacks
			entry.max_stacks = real_max
			entry.stat_buffs = stat_buffs
			entry.conditional_stat_buffs = conditional_stat_buffs
			entry.type = "dot"

		end

		-- UTILITY STUFF
		if mod.debuffs[name] and mod.debuffs[name].type == "utility" and fs.debuff_utility_enable then
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

			local real_max = buff.max_stacks and buff:max_stacks() or template.max_stacks

			entry.name = name
			entry.stacks = stacks
			entry.max_stacks = real_max
			entry.stat_buffs = stat_buffs
			entry.conditional_stat_buffs = conditional_stat_buffs
			entry.type = "utility"

		end
	end
	
	-- CUSTOM STAGGER DEBUFF
	local enemyentry = mod.enemy_cache[unit]
	
	if enemyentry and fs.debuff_stagger_enable then
		if enemyentry.staggered then
			local now = mod.get_time()

			if enemyentry.stagger_timer and now >= enemyentry.stagger_timer then
				enemyentry.staggered = false
				enemyentry.stagger_type = nil
				enemyentry.stagger_duration = 0
				enemyentry.stagger_timer = 0

				if widget._active_lookup then
					if widget._active_lookup["staggered"] then
						widget._active_lookup["staggered"] = false
					end
				end

				if widget._state then
					if widget._state["staggered"] then
						--widget._state["staggered"] = nil
					end
				end
			else
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


				local stagger_time_rounded = math.floor((enemyentry.stagger_timer - now) * 10) / 10
				if stagger_time_rounded <= 0 then
					stagger_time_rounded = 0.00
				end

				-- set the stack timer to the amount of time the enemy is staggered if available...
				entry.name = "staggered"
				entry.stacks = 1
				entry.duration = stagger_time_rounded
				entry.max_stacks = 1
				entry.stat_buffs = {}
				entry.conditional_stat_buffs = {}
				entry.type = "utility"
			end
		end
	end

	-- dont draw or do calculations if there are no debuffs applied..
	if #active < 1 then
		content.draw_dbf  = false
	end

	for i = active_count + 1, #active do
		active_pool[#active_pool + 1] = active[i]
		active[i] = nil
	end

	-------------------------------------------------------------------
	-- COMBINE SAME ICONS AND CALCULATE COMBINED STACKS/PERCENTAGE
	-------------------------------------------------------------------
	if fs.debuffs_combine and active_count > 1 then
		local combined_count = 0

		widget._combined = widget._combined or {}
		widget._grouped_dot = widget._grouped_dot or {}
		widget._grouped_util = widget._grouped_util or {}

		local combined = widget._combined
		local grouped_dot_map = widget._grouped_dot
		local grouped_utility_map = widget._grouped_util

		for k in next, grouped_dot_map do
			grouped_dot_map[k] = nil
		end
		for k in next, grouped_utility_map do
			grouped_utility_map[k] = nil
		end

		for i = 1, active_count do
			local entry = active[i]
			local name = entry.name
			local max_stacks = entry.max_stacks
			local icon = mod.debuffs and mod.debuffs[name] and mod.debuffs[name].group and mod.debuff_styles[mod.debuffs[name].group] and mod.debuff_styles[mod.debuffs[name].group].icon or nil
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

				-- calculate duration
				local duration = nil
				if existing.duration or entry.duration then
					duration = (existing.duration or 0) + (entry.duration or 0)
				end

				existing.duration = duration

				-- merge stat_buffs from all sources (do not overwrite)
				if entry.stat_buffs then
					existing.stat_buffs = existing.stat_buffs or {}
					for stat_name, val in pairs(entry.stat_buffs) do
						existing.stat_buffs[stat_name] = val
					end
				end
				if entry.conditional_stat_buffs then
					existing.conditional_stat_buffs = existing.conditional_stat_buffs or {}
					for stat_name, val in pairs(entry.conditional_stat_buffs) do
						existing.conditional_stat_buffs[stat_name] = val
					end
				end

				-- accumulate actual stat contributions (capped per source) for correct combined percentage
				existing._stat_contributions = existing._stat_contributions or {}
				if entry.stat_buffs then
					for stat_name, val in pairs(entry.stat_buffs) do
						local effective_stacks = math.min(entry.stacks or 1, entry.max_stacks or math.huge)
						existing._stat_contributions[stat_name] = {
							val = val,
							stacks = effective_stacks,
						}
					end
				end
				if entry.conditional_stat_buffs then
					for stat_name, val in pairs(entry.conditional_stat_buffs) do
						local effective_stacks = math.min(entry.stacks or 1, entry.max_stacks or math.huge)
						existing._stat_contributions[stat_name] = {
							val = val,
							stacks = effective_stacks,
						}
					end
				end
			else
				combined_count = combined_count + 1

				local new_entry = {
					name = name,
					stacks = entry.stacks,
					max_stacks = entry.max_stacks,
					duration = entry.duration,
					stat_buffs = entry.stat_buffs and table.clone(entry.stat_buffs) or nil,
					conditional_stat_buffs = entry.conditional_stat_buffs and table.clone(entry.conditional_stat_buffs) or nil,
					combined = true,
					type = debuff_type,
				}

				new_entry._stat_contributions = {}
				if entry.stat_buffs then
					for stat_name, val in pairs(entry.stat_buffs) do
						local effective_stacks = math.min(entry.stacks or 1, entry.max_stacks or math.huge)
						new_entry._stat_contributions[stat_name] = {
							val = val,
							stacks = effective_stacks,
						}
					end
				end
				if entry.conditional_stat_buffs then
					for stat_name, val in pairs(entry.conditional_stat_buffs) do
						local effective_stacks = math.min(entry.stacks or 1, entry.max_stacks or math.huge)
						new_entry._stat_contributions[stat_name] = {
							val = val,
							stacks = effective_stacks,
						}
					end
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

	for k in next, active_lookup do
		active_lookup[k] = nil
	end

	-------------------------------------------------------------------
	-- Pre-compute body center screen offset for debuff_show_on_body
	-- Uses Camera.world_to_screen to get the true perspective-projected
	-- delta between head and body center, then pre-divides by marker.scale
	-- to compensate for the downstream scale multiplication on offsets.
	-------------------------------------------------------------------
	local _body_screen_offset_y = nil
	if fs.debuff_show_on_body then
		local camera = parent._parent and parent._parent:player_camera()
		local breed = content.breed
		local head_pos = marker.world_position and marker.world_position:unbox()
		if camera and breed and breed.base_height and head_pos and unit then
			local root_pos = Unit.world_position(unit, 1)
			if root_pos then
				local body_center = Vector3(root_pos.x, root_pos.y, root_pos.z + breed.base_height * 0.5)
				local head_screen = Camera.world_to_screen(camera, head_pos)
				local body_screen = Camera.world_to_screen(camera, body_center)
				if head_screen and body_screen and marker.scale and marker.scale > 0.001 then
					_body_screen_offset_y = (body_screen.y - head_screen.y) / marker.scale
				end
			end
		end
	end

	-------------------------------------------------------------------
	-- UPDATE STATE (KEYED BY DEBUFF NAME)
	-------------------------------------------------------------------
	for index = 1, active_count do
		local debuff = active[index]
		local name = debuff.name
		local stacks = debuff.stacks
		local duration = debuff.duration
		local y_base = 0

		if fs.debuff_show_on_body then
			-- Pin debuffs to body center using camera-projected screen delta
			if _body_screen_offset_y then
				y_base = _body_screen_offset_y
			else
				-- Fallback: approximate body center offset
				y_base = -(content.breed and content.breed.base_height or 1) * 20 * fs.text_scale
			end
		else
			if split_debuff_types then
				if debuff.type == "dot" then
					if fs.healthbar_enable and fs.hb_text_top_left_01 == "nothing" then
						y_base = (-hb_size_height - 16) * fs.text_scale
					elseif fs.markers_enable and not fs.healthbar_enable then
						y_base = (-hb_size_height - (15 * fs.marker_size)) * fs.text_scale
					else
						y_base = (-hb_size_height - 34) * fs.text_scale
					end
				elseif debuff.type == "utility" then
					if
						fs.healthbar_enable
						and fs.hb_text_bottom_left_02 == "nothing"
						and fs.hb_text_bottom_left_01 == "nothing"
					then
						y_base = (hb_size_height + 16) * fs.text_scale
					elseif
						fs.healthbar_enable
						and fs.hb_text_bottom_left_02 == "nothing"
						and fs.hb_text_bottom_left_01 ~= "nothing"
					then
						y_base = (hb_size_height + 40) * fs.text_scale
					elseif fs.markers_enable and not fs.healthbar_enable then
						y_base = (hb_size_height + (15 * fs.marker_size)) * fs.text_scale
					else
						y_base = (hb_size_height + 60) * fs.text_scale
					end
				end
			else
				if (fs.healthbar_enable and fs.hb_text_top_left_01 == "nothing") then
					y_base = (-hb_size_height - 16) * fs.text_scale
				elseif fs.markers_enable and not fs.healthbar_enable then
					y_base = (-hb_size_height - (15 * fs.marker_size)) * fs.text_scale
				else
					y_base = (-hb_size_height - 34) * fs.text_scale
				end
			end

			y_base = y_base * fs.debuff_y_offset * marker.scale
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
	-- Always position above head (does NOT affect debuff screen-space y offsets)
	-------------------------------------------------------------------
	if content.breed and is_alive then
		local root_position = Unit.world_position(unit, 1)
		root_position.z = root_position.z + content.breed.base_height + 0.5

		if not marker.world_position then
			marker.world_position = Vector3Box(root_position)
		else
			marker.world_position:store(root_position)
		end
	end

	-------------------------------------------------------------------
	-- DRAW ROWS
	-------------------------------------------------------------------
	local dot_index = 0
	local util_index = 0

	for i = 1, max_rows do
		local icon_id = "debuff_icon_" .. i
		local stack_text_id = "stack_counter_" .. i
		local name_text_id = "debuff_name_" .. i

		local icon_style = style[icon_id]
		local icon_shadow_style = style[icon_id .. "_shadow"]
		local stack_text_style = style[stack_text_id]
		local name_text_style = style[name_text_id]

		local debuff = active[i]

		local row_i = 0

		if debuff then
			if split_debuff_types then
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

			if fs.debuff_horizontal then
				-- HORIZONTAL DEBUFFS
				local name = debuff.name
				local state = state_table[name]

				local col_i = (row_i - 1)
				local col_offset_x = col_i * col_step

				local base_y_fixed = state.y

				if split_debuff_types then
					if debuff.type == "dot" then
						base_y_fixed = state.y - (calculate_icon_size() * fs.text_scale)
					elseif debuff.type == "utility" then
						base_y_fixed = state.y + (calculate_icon_size() * 1.1 * fs.text_scale)
						if fs.hb_damage_number_type == "readable" and mod.num_damage_numbers and mod.num_damage_numbers > 0 then
							base_y_fixed = base_y_fixed + 16 * fs.debuff_y_offset
						end
					end
				end				

				-- ICON SHADOW
				local o = icon_shadow_style.offset
				o[1] = icon_x + col_offset_x + base_offset + 1
				o[2] = base_y_fixed * fs.debuff_y_offset + 1

				local o = icon_shadow_style.default_offset
				o[1] = icon_x + col_offset_x + base_offset + 1
				o[2] = base_y_fixed * fs.debuff_y_offset + 1

				-- ICON
				local o = icon_style.offset
				o[1] = icon_x + col_offset_x + base_offset
				o[2] = base_y_fixed * fs.debuff_y_offset

				local o = icon_style.default_offset
				o[1] = icon_x + col_offset_x + base_offset
				o[2] = base_y_fixed * fs.debuff_y_offset

				-- STACK
				if fs.debuff_stack_on_icon then
					local o = stack_text_style.offset
					o[1] = stack_x + col_offset_x + base_offset - (calculate_icon_size()) 
					o[2] = base_y_fixed * fs.debuff_y_offset + (calculate_icon_size() / 1.5) 

					local o = stack_text_style.default_offset
					o[1] = stack_x + col_offset_x + base_offset - (calculate_icon_size()) 
					o[2] = base_y_fixed	* fs.debuff_y_offset + (calculate_icon_size() / 1.5) 
				else
					local o = stack_text_style.offset
					o[1] = stack_x + col_offset_x + base_offset
					o[2] = base_y_fixed * fs.debuff_y_offset

					local o = stack_text_style.default_offset
					o[1] = stack_x + col_offset_x + base_offset
					o[2] = base_y_fixed * fs.debuff_y_offset
				end

				-- FORCE NO NAME
				content[name_text_id] = ""
			else
				-- VERTICAL DEBUFFS
				-- split different debuff types (one goes up, one goes down ;))
				if split_debuff_types then
					if debuff.type == "dot" then
						local row_offset_y = state.y - ((row_i - 1) * row_step)

						local o = icon_shadow_style.offset
						o[1] = icon_x + base_offset + 1
						o[2] = row_offset_y + 1
						local o = icon_shadow_style.default_offset
						o[1] = icon_x + base_offset + 1
						o[2] = row_offset_y + 1


						local o = icon_style.offset
						o[1] = icon_x + base_offset
						o[2] = row_offset_y
						local o = icon_style.default_offset
						o[1] = icon_x + base_offset
						o[2] = row_offset_y

						if fs.debuff_stack_on_icon then
							local o = stack_text_style.offset
							o[2] = row_offset_y + (calculate_icon_size() / 1.5)
							local o = stack_text_style.default_offset
							o[2] = row_offset_y + (calculate_icon_size() / 1.5)
						else
							local o = stack_text_style.offset
							o[1] = stack_x + base_offset
							o[2] = row_offset_y
							local o = stack_text_style.default_offset
							o[1] = stack_x + base_offset
							o[2] = row_offset_y
						end

						local o = name_text_style.offset
						o[1] = name_x + base_offset
						o[2] = row_offset_y
						local o = name_text_style.default_offset
						o[1] = name_x + base_offset
						o[2] = row_offset_y
					elseif debuff.type == "utility" then
						local row_offset_y = state.y + ((row_i - 1) * row_step)

						if fs.hb_damage_number_type == "readable" and mod.num_damage_numbers and mod.num_damage_numbers > 0 then
							row_offset_y = state.y + 16 * fs.debuff_y_offset + ((row_i - 1) * row_step)
						end

						local o = icon_shadow_style.offset
						o[1] = icon_x + base_offset + 1
						o[2] = row_offset_y + 1
						local o = icon_shadow_style.default_offset
						o[1] = icon_x + base_offset + 1
						o[2] = row_offset_y + 1

						local o = icon_style.offset
						o[1] = icon_x + base_offset
						o[2] = row_offset_y
						local o = icon_style.default_offset
						o[1] = icon_x + base_offset
						o[2] = row_offset_y

						if fs.debuff_stack_on_icon then
							local o = stack_text_style.offset
							o[2] = row_offset_y + (calculate_icon_size() / 1.5)
							local o = stack_text_style.default_offset
							o[2] = row_offset_y + (calculate_icon_size() / 1.5)
						else
							local o = stack_text_style.offset
							o[1] = stack_x + base_offset
							o[2] = row_offset_y
							local o = stack_text_style.default_offset
							o[1] = stack_x + base_offset
							o[2] = row_offset_y
						end
						local o = name_text_style.offset
						o[1] = name_x + base_offset
						o[2] = row_offset_y
						local o = name_text_style.default_offset
						o[1] = name_x + base_offset
						o[2] = row_offset_y
					end
				else
					local row_offset_y = state.y - ((row_i - 1) * row_step)

					local o = icon_shadow_style.offset
					o[1] = icon_x + base_offset + 1
					o[2] = row_offset_y + 1
					local o = icon_shadow_style.default_offset
					o[1] = icon_x + base_offset + 1
					o[2] = row_offset_y + 1

					local o = icon_style.offset
					o[1] = icon_x + base_offset
					o[2] = row_offset_y
					local o = icon_style.default_offset
					o[1] = icon_x + base_offset
					o[2] = row_offset_y

					if fs.debuff_stack_on_icon then
						local o = stack_text_style.offset
						o[2] = row_offset_y + (calculate_icon_size() / 1.5)
						local o = stack_text_style.default_offset
						o[2] = row_offset_y + (calculate_icon_size() / 1.5)
					else
						local o = stack_text_style.offset
						o[1] = stack_x + base_offset
						o[2] = row_offset_y
						local o = stack_text_style.default_offset
						o[1] = stack_x + base_offset
						o[2] = row_offset_y
					end

					local o = name_text_style.offset
					o[1] = name_x + base_offset
					o[2] = row_offset_y
					local o = name_text_style.default_offset
					o[1] = name_x + base_offset
					o[2] = row_offset_y
				end
			end

			local at_max_stacks = false

			if not duration and max_stacks and stacks >= max_stacks then
				stacks = max_stacks
				at_max_stacks = true
			end

			if state then
				content[icon_id] = mod.debuffs and mod.debuffs[name] and mod.debuffs[name].group and mod.debuff_styles[mod.debuffs[name].group] and mod.debuff_styles[mod.debuffs[name].group].icon
					or "content/ui/materials/icons/generic/danger"

				-- Add percentage text
				local stack_buff_percentage = ""

				if debuff.combined and debuff._stat_contributions then
					local total_perc = 0
					for stat_name, contrib in pairs(debuff._stat_contributions) do
						if stat_name and contrib and contrib.val and contrib.stacks then
							local stat_buff_type = stat_buff_types[stat_name]
							local raw = 0
							if stat_buff_type == "multiplicative_multiplier" then
								raw = (contrib.val ^ contrib.stacks - 1) * 100
							else
								raw = contrib.val * contrib.stacks * 100
							end
							local nearest = math_floor((raw + 5) / 10) * 10
							if math.abs(raw - nearest) <= 1 then
								raw = nearest
							end
							total_perc = total_perc + math_floor(raw * 10 + 0.5) * 0.1
						end
					end
					if total_perc ~= 0 then
						stack_buff_percentage = total_perc
					end
				elseif stat_buffs then
					for stat_name, val in next, stat_buffs do
						if stat_name and val then
							local loc = mod.custom_localize(stat_name)
							stack_buff_percentage = calc_stack_buff_percentage(val, stacks, stat_name)
						end
					end
				elseif conditional_stat_buffs then
					for stat_name, val in next, conditional_stat_buffs do
						if stat_name and val then
							local loc = mod.custom_localize(stat_name)
							stack_buff_percentage = calc_stack_buff_percentage(val, stacks, stat_name)
						end
					end
				end

				-- Update stack text
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

				-- Update debuff name
				if fs.debuff_names then
					if state.name_visible and name_text_style then
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

				-- colour mutation
				local colour = (mod.debuffs and mod.debuffs[name] and mod.debuffs[name].group and mod.debuff_styles[mod.debuffs[name].group] and mod.debuff_styles[mod.debuffs[name].group].colour)
					or { 255, 255, 255, 255 }

				icon_style.color[2] = colour[2] or 255
				icon_style.color[3] = colour[3] or 255
				icon_style.color[4] = colour[4] or 255

				-- Staggered colour should follow the stagger colour specifically
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
					stack_text_style.text_color[2] = fs.secondary_colour[2] or 255
					stack_text_style.text_color[3] = fs.secondary_colour[3] or 255
					stack_text_style.text_color[4] = fs.secondary_colour[4] or 255
				end

				if #widget._active > 0 then
					content.draw_dbf  = true
				else
					content.draw_dbf  = false
				end

				if not marker.is_inside_frustum then
					content.draw_dbf  = false
				end

				-- apply scaling
				if content.draw_dbf  then
					local scale = marker.scale
					content.dbf_built = true

					icon_style.size[1] = icon_style.default_size[1] * scale
					icon_style.size[2] = icon_style.default_size[2] * scale
					icon_shadow_style.size[1] = icon_shadow_style.default_size[1] * scale
					icon_shadow_style.size[2] = icon_shadow_style.default_size[2] * scale

					if fs.debuff_max_stacks_scale and at_max_stacks then
						if fs.debuff_stack_on_icon then
							stack_text_style.font_size = (
								(stack_text_style.default_font_size * (fs.debuff_icon_scale * 0.6)) * scale
							) * 1.1
						else
							stack_text_style.font_size = (stack_text_style.default_font_size * scale) * 1.1
						end
					else
						if fs.debuff_stack_on_icon then
							stack_text_style.font_size = (
								stack_text_style.default_font_size * (fs.debuff_icon_scale * 0.6)
							) * scale
						else
							stack_text_style.font_size = stack_text_style.default_font_size * scale
						end
					end

					name_text_style.font_size = name_text_style.default_font_size * scale

					icon_shadow_style.offset[1] = math.floor(icon_shadow_style.default_offset[1] * scale)
					icon_shadow_style.offset[2] = math.floor(icon_shadow_style.default_offset[2] * scale)

					icon_style.offset[1] = math.floor(icon_style.default_offset[1] * scale)
					icon_style.offset[2] = math.floor(icon_style.default_offset[2] * scale)

					stack_text_style.offset[1] = math.floor(stack_text_style.default_offset[1] * scale)
					stack_text_style.offset[2] = math.floor(stack_text_style.default_offset[2] * scale)

					name_text_style.offset[1] = math.floor(name_text_style.default_offset[1] * scale)
					name_text_style.offset[2] = math.floor(name_text_style.default_offset[2] * scale)
				else
					content.dbf_built = false
				end
			end
		else
			content[icon_id] = nil
			content[stack_text_id] = nil
			content[name_text_id] = nil
		end
	end
end

return template
