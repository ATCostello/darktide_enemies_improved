local mod = get_mod("enemies_improved")

local math_floor = math.floor
local pool = {}

local function _take_entry(active, index)
	local entry = active[index]

	if not entry then
		entry = pool[#pool]

		if entry then
			pool[#pool] = nil
		else
			entry = {}
		end

		active[index] = entry
	end

	return entry
end

local function _stacks_of(buff)
	return buff.stack_count and buff:stack_count() or buff.stacks and buff:stacks() or 1
end

mod.collect_debuffs = function(widget, debuffs, keywords, unit, include_stagger)
	local fs = mod.frame_settings

	widget._active = widget._active or {}

	local active = widget._active
	local active_count = 0

	-- clear without reallocating
	for i = 1, #active do
		active[i] = nil
	end

	-------------------------------------------------------------------
	-- From keywords
	-------------------------------------------------------------------
	if keywords and fs.debuff_keyword_enable then
		for keyword in pairs(keywords) do
			local name = keyword
			local def = mod.debuffs[name]
			local debuff_type = def and def.type

			if debuff_type == "dot" or debuff_type == "utility" then
				active_count = active_count + 1

				local entry = _take_entry(active, active_count)

				entry.name = name
				entry.stacks = 1
				entry.max_stacks = 1
				entry.type = debuff_type
				entry.duration = nil
				entry.combined = nil
			end
		end
	end

	-------------------------------------------------------------------
	-- From buffs
	-------------------------------------------------------------------
	if debuffs then
		for i = 1, #debuffs do
			local buff = debuffs[i]
			local name = buff:template_name()
			local def = mod.debuffs[name]

			if def then
				local buff_template = buff:template()
				local debuff_type = def.type
				local enabled = debuff_type == "dot" and fs.debuff_dot_enable
					or debuff_type == "utility" and fs.debuff_utility_enable

				if enabled then
					active_count = active_count + 1

					local entry = _take_entry(active, active_count)

					entry.name = name
					entry.stacks = _stacks_of(buff)
					entry.max_stacks = buff.max_stacks and buff:max_stacks() or buff_template.max_stacks
					entry.stat_buffs = buff_template.stat_buffs
					entry.conditional_stat_buffs = buff_template.conditional_stat_buffs
					entry.type = debuff_type
					entry.duration = nil
					entry.combined = nil
				end
			end
		end
	end

	-------------------------------------------------------------------
	-- Custom stagger debuff
	-------------------------------------------------------------------
	local enemy_entry = include_stagger and fs.debuff_stagger_enable and mod.enemy_cache and mod.enemy_cache[unit]

	if enemy_entry and enemy_entry.staggered then
		local now = mod.get_time()

		if enemy_entry.stagger_timer and now >= enemy_entry.stagger_timer then
			enemy_entry.staggered = false
			enemy_entry.stagger_type = nil
			enemy_entry.stagger_duration = 0
			enemy_entry.stagger_timer = 0

			local active_lookup = widget._active_lookup

			if active_lookup and active_lookup.staggered then
				active_lookup.staggered = false
			end
		else
			active_count = active_count + 1

			local entry = _take_entry(active, active_count)
			local stagger_time_rounded = math_floor((enemy_entry.stagger_timer - now) * 10) / 10

			if stagger_time_rounded <= 0 then
				stagger_time_rounded = 0.00
			end

			entry.name = "staggered"
			entry.stacks = 1
			entry.duration = stagger_time_rounded
			entry.max_stacks = 1
			entry.stat_buffs = {}
			entry.conditional_stat_buffs = {}
			entry.type = "utility"
			entry.combined = nil
		end
	end

	for i = active_count + 1, #active do
		pool[#pool + 1] = active[i]
		active[i] = nil
	end

	widget._active_count = active_count

	return active_count
end

return mod.collect_debuffs
