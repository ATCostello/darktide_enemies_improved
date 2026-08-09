local mod = get_mod("enemies_improved")

local DEBUG = mod.DEBUG

local mem_profile = {}

mod.mem_profile_sizes = mod.mem_profile_sizes or {}

local tracked = {}
local order = {}
local history = {}
local sample_interval = 1
local next_sample_time = 0
local MAX_HISTORY = 360
local auto_report_interval = 30
local auto_report_timer = 0
local gui_open = false
local gui_render_error = false
local pinned_suspects = {}
local EST_SUBTREE_NODE_BUDGET = 500000
local est_budget_count = { n = 0 }

-- Rough byte estimate of a value's memory footprint. The root table's own entries are always counted fully
local function est_bytes(value, visited, depth)
	depth = depth or 0

	if depth > 3 then
		return 0
	end

	if est_budget_count.n >= EST_SUBTREE_NODE_BUDGET then
		return 0
	end

	est_budget_count.n = est_budget_count.n + 1

	local tv = type(value)

	if tv == "table" then
		if visited[value] then
			return 0
		end

		visited[value] = true

		local bytes = 48

		if depth == 0 then
			-- Count every top-level entry (cheap, scales with table size only).
			for k in pairs(value) do
				bytes = bytes + 8
			end

			-- Then recurse into a budgeted sample of the subtree.
			for k, v in pairs(value) do
				if est_budget_count.n >= EST_SUBTREE_NODE_BUDGET then
					break
				end

				bytes = bytes + est_bytes(k, visited, depth + 1) + est_bytes(v, visited, depth + 1)
			end
		else
			for k, v in pairs(value) do
				if est_budget_count.n >= EST_SUBTREE_NODE_BUDGET then
					break
				end

				bytes = bytes + 8 + est_bytes(k, visited, depth + 1) + est_bytes(v, visited, depth + 1)
			end
		end

		return bytes
	elseif tv == "string" then
		return 24 + #value
	elseif tv == "userdata" then
		return 96
	elseif tv == "function" or tv == "thread" then
		return 64
	else
		return 8
	end
end

local function measure(value)
	est_budget_count.n = 0
	return est_bytes(value, {})
end

local function fmt_bytes(n)
	if n >= 1024 * 1024 then
		return string.format("%.1fM", n / (1024 * 1024))
	elseif n >= 1024 then
		return string.format("%.1fK", n / 1024)
	else
		return tostring(math.floor(n + 0.5)) .. "B"
	end
end

local function fmt_delta(n)
	if n > 0 then
		return "+" .. fmt_bytes(n)
	elseif n < 0 then
		return "-" .. fmt_bytes(-n)
	else
		return "0B"
	end
end

local function slope_bytes_per_sec(entries, getter)
	local n = #entries

	if n < 2 then
		return 0
	end

	local t0 = entries[1].t
	local sx, sy, sxx, sxy = 0, 0, 0, 0

	for i = 1, n do
		local x = entries[i].t - t0
		local y = getter(entries[i]) or 0
		sx = sx + x
		sy = sy + y
		sxx = sxx + x * x
		sxy = sxy + x * y
	end

	local denom = n * sxx - sx * sx

	if denom == 0 then
		return 0
	end

	return (n * sxy - sx * sy) / denom
end

local LEAK_MIN_SAMPLES = 100
local LEAK_WINDOW = 10
local LEAK_MIN_UP_FRACTION = 0.6

local GROW_RECENT_WINDOW = 4

local function is_leak_suspect(entries, name)
	local n = #entries

	if n < LEAK_MIN_SAMPLES then
		return false
	end

	local window = math.min(LEAK_WINDOW, n - 1)
	local start = n - window
	local up_count = 0

	for i = start + 1, n do
		local prev = entries[i - 1].values[name] or 0
		local cur = entries[i].values[name] or 0

		if cur > prev then
			up_count = up_count + 1
		end
	end

	local recent_delta = (entries[n].values[name] or 0) - (entries[start].values[name] or 0)

	return recent_delta > 0 and (up_count / window) >= LEAK_MIN_UP_FRACTION
end

local function compute_values()
	local values = {}

	for i = 1, #order do
		local name = order[i]
		local value = tracked[name]

		if value ~= nil then
			values[name] = measure(value)
		end
	end

	local ok, wm = pcall(function()
		local ui_manager = Managers.ui
		local hud = ui_manager and ui_manager:get_hud()
		return hud and hud:element("HudElementWorldMarkers")
	end)

	if ok and wm then
		values["world_markers._widgets_by_name"] = measure(wm._widgets_by_name)
		values["world_markers._markers_by_id"] = measure(wm._markers_by_id)
		values["world_markers._markers_by_type"] = measure(wm._markers_by_type)
		values["world_markers._markers"] = measure(wm._markers)
		values["world_markers._widgets"] = measure(wm._widgets)
	end

	return values
end

local function update_sizes(values)
	table.clear(mod.mem_profile_sizes)

	for name, bytes in pairs(values) do
		mod.mem_profile_sizes[name] = bytes
	end
end

local function sample()
	local values = compute_values()
	update_sizes(values)

	local total = 0

	for _, bytes in pairs(values) do
		total = total + bytes
	end

	table.insert(history, {
		t = mod.get_time(),
		values = values,
		total = total,
	})

	if #history > MAX_HISTORY then
		table.remove(history, 1)
	end
end

mem_profile.refresh_sizes = function()
	if not DEBUG then
		return
	end

	update_sizes(compute_values())
end

mem_profile.track = function(name, value)
	if not DEBUG then
		return
	end

	if not tracked[name] then
		order[#order + 1] = name
	end

	tracked[name] = value
end

mem_profile.untrack = function(name)
	if not DEBUG then
		return
	end

	tracked[name] = nil

	for i = 1, #order do
		if order[i] == name then
			table.remove(order, i)
			break
		end
	end
end

mem_profile.tick = function(dt)
	if not DEBUG then
		return
	end

	next_sample_time = next_sample_time - dt

	if next_sample_time <= 0 then
		next_sample_time = sample_interval
		sample()

		if auto_report_interval > 0 and not gui_open then
			auto_report_timer = auto_report_timer + sample_interval

			if auto_report_timer >= auto_report_interval then
				auto_report_timer = 0
				mem_profile.report()
			end
		end
	end
end

mem_profile.set_auto_report = function(seconds)
	if not DEBUG then
		return
	end

	auto_report_interval = seconds or 0
	auto_report_timer = 0
end

mem_profile.set_budget = function(nodes)
	if not DEBUG then
		return
	end

	EST_SUBTREE_NODE_BUDGET = nodes or 800
end

mem_profile.sample_now = function()
	if not DEBUG then
		return
	end

	sample()
	mem_profile.report()
end

mem_profile.interval = function(seconds)
	sample_interval = seconds or 5
end

mem_profile.clear_history = function()
	if not DEBUG then
		return
	end

	table.clear(history)
	table.clear(pinned_suspects)
end

local function collect_stats()
	local stats = { n = #history }

	if stats.n == 0 then
		return stats
	end

	stats.first = history[1]
	stats.last = history[stats.n]
	stats.recent = history[math.max(1, stats.n - GROW_RECENT_WINDOW)]
	stats.dur = stats.last.t - stats.first.t
	stats.suspects = {}
	stats.growing = {}
	stats.grew = {}
	stats.shrunk = {}
	stats.flat_count = 0
	stats.total_first = 0
	stats.total_last = 0
	local names = {}

	for name in pairs(stats.last.values) do
		names[#names + 1] = name
	end

	for _, name in ipairs(names) do
		local f = stats.first.values[name] or 0
		local l = stats.last.values[name] or 0
		local delta = l - f
		local recent_delta = l - (stats.recent.values[name] or 0)
		stats.total_first = stats.total_first + f
		stats.total_last = stats.total_last + l

		-- Pin as a possible leak only once there is a lot of history AND the table is still growing (sustained). Once pinned it stays pinned.
		if is_leak_suspect(history, name) then
			pinned_suspects[name] = true
		end

		if pinned_suspects[name] then
			stats.suspects[#stats.suspects + 1] = {
				name = name,
				now = l,
				delta = delta,
				recent = recent_delta,
				rate = slope_bytes_per_sec(history, function(entry) return entry.values[name] end),
			}
		elseif recent_delta > 0 and delta > 0 then
			stats.growing[#stats.growing + 1] = {
				name = name,
				now = l,
				delta = delta,
				recent = recent_delta,
				rate = slope_bytes_per_sec(history, function(entry) return entry.values[name] end),
			}
		elseif recent_delta < 0 then
			stats.shrunk[#stats.shrunk + 1] = { name = name, now = l, delta = l - f, recent = recent_delta }
		elseif delta > 0 then
			stats.grew[#stats.grew + 1] = { name = name, now = l, delta = delta }
		else
			stats.flat_count = stats.flat_count + 1
		end
	end

	table.sort(stats.suspects, function(a, b)
		return a.rate > b.rate
	end)
	table.sort(stats.growing, function(a, b)
		return a.rate > b.rate
	end)
	table.sort(stats.grew, function(a, b)
		return a.delta > b.delta
	end)
	table.sort(stats.shrunk, function(a, b)
		return a.delta < b.delta
	end)

	return stats
end

mem_profile.report = function()
	if not DEBUG then
		return nil
	end

	local stats = collect_stats()

	if stats.n == 0 then
		return "no samples recorded yet"
	end

	if stats.n < 3 then
		return string.format("not enough samples yet (%d), wait a bit or run dbg_mod.mem_profile_now()", stats.n)
	end

	local lines = {}

	local function line(fmt, ...)
		lines[#lines + 1] = string.format(fmt, ...)
	end

	line(
		"LEAK SCAN - %d sample(s) over %.1f min - total %s",
		stats.n,
		stats.dur / 60,
		fmt_delta(stats.total_last - stats.total_first)
	)

	if #stats.suspects > 0 then
		line("PINNED SUSPECTS (possible leaks):")
		for _, s in ipairs(stats.suspects) do
			line(
				"  * %-42s now %8s  session %8s  ~%8s/s",
				s.name,
				fmt_bytes(s.now),
				fmt_delta(s.delta),
				fmt_bytes(s.rate)
			)
		end
	end

	if #stats.growing > 0 then
		line("GROWING NOW (not flagged as a leak):")
		for _, s in ipairs(stats.growing) do
			line(
				"    %-42s now %8s  session %8s  ~%8s/s",
				s.name,
				fmt_bytes(s.now),
				fmt_delta(s.delta),
				fmt_bytes(s.rate)
			)
		end
	end

	if #stats.grew > 0 then
		line("GREW THEN STABILIZED:")
		for _, s in ipairs(stats.grew) do
			line("    %-42s now %8s  session %8s", s.name, fmt_bytes(s.now), fmt_delta(s.delta))
		end
	end

	if #stats.shrunk > 0 then
		line("SHRINKING:")
		for _, s in ipairs(stats.shrunk) do
			line("    %-42s now %8s  session %8s", s.name, fmt_bytes(s.now), fmt_delta(s.delta))
		end
	end

	if stats.flat_count > 0 then
		line("%d table(s) flat (no change)", stats.flat_count)
	end

	return table.concat(lines, "\n")
end

mem_profile.list = function()
	if not DEBUG then
		return nil
	end

	if #order == 0 then
		return "no tables tracked"
	end

	local lines = { string.format("tracked tables (%d):", #order) }

	for i = 1, #order do
		local name = order[i]
		local value = tracked[name]

		if value ~= nil then
			lines[#lines + 1] = string.format("  %-42s %s", name, fmt_bytes(measure(value)))
		else
			lines[#lines + 1] = string.format("  %-42s (nil)", name)
		end
	end

	return table.concat(lines, "\n")
end

local GUI_FONT_SCALE = 1.0
local GUI_NAME_COLUMN_PX = 250

local function open_gui()
	if not Imgui then
		return false
	end

	gui_open = true
	gui_render_error = false
	Imgui.open_imgui()
	mem_profile.refresh_sizes()

	return true
end

local function close_gui()
	gui_open = false
	Imgui.close_imgui()
end

mem_profile.toggle_gui = function()
	if not DEBUG then
		return false
	end

	if gui_open then
		close_gui()
		return false
	end

	return open_gui()
end

mem_profile.gui_is_open = function()
	return gui_open
end

mem_profile.force_sample = function()
	if not DEBUG then
		return
	end

	sample()
end

local function gui_row(name, now, delta, rate, marker)
	local name_w = Imgui.calculate_text_size(name)
	local dot_w = Imgui.calculate_text_size(".")
	local dots = ""

	if name_w < GUI_NAME_COLUMN_PX and dot_w > 0 then
		dots = string.rep(".", math.max(1, math.floor((GUI_NAME_COLUMN_PX - name_w) / dot_w)))
	else
		dots = " "
	end

	local line = marker .. " " .. name .. dots .. " " .. fmt_bytes(now) .. "  " .. fmt_delta(delta)

	if rate and rate > 0 then
		line = line .. "  ~" .. fmt_bytes(rate) .. "/s"
	end

	Imgui.text(line)
end

mem_profile.render_gui = function()
	if not DEBUG or not gui_open or not Imgui then
		return
	end

	local ok = pcall(function()
		Imgui.set_next_window_size(680, 0)
		Imgui.set_next_window_pos(48, 48)

		local _, closed = Imgui.begin_window("Mem Profile", "always_auto_resize")

		if closed then
			close_gui()
			return
		end

		Imgui.set_window_font_scale(GUI_FONT_SCALE)

		local stats = collect_stats()

		if stats.n >= 3 then
			Imgui.text(string.format(
				"%d sample(s) over %.1f min - total %s (%s)",
				stats.n,
				stats.dur / 60,
				fmt_bytes(stats.total_last),
				fmt_delta(stats.total_last - stats.total_first)
			))
		elseif stats.n > 0 then
			Imgui.text(string.format("collecting samples... %d/3", stats.n))
		else
			Imgui.text("no samples yet - press Sample")
		end

		Imgui.text("")

		local rows = {}
		local seen = {}

		local function add_row(name, now, delta, rate, marker)
			rows[#rows + 1] = { name = name, now = now, delta = delta, rate = rate, marker = marker }
		end

		local function push_list(list, marker)
			for _, s in ipairs(list) do
				seen[s.name] = true
				add_row(s.name, s.now, s.delta, s.rate, marker)
			end
		end

		if stats.n >= 3 then
			-- Leak suspects first, then plain growth, then the rest (flat rows
			-- are appended from the live sizes view).
			push_list(stats.suspects, "!")
			push_list(stats.growing, ">>")
			push_list(stats.grew, "+")
			push_list(stats.shrunk, "-")

			for name, now in pairs(mod.mem_profile_sizes) do
				if not seen[name] then
					add_row(name, now, 0, nil, " ")
				end
			end
		else
			for name, now in pairs(mod.mem_profile_sizes) do
				add_row(name, now, 0, nil, " ")
			end
		end

		for i = 1, #rows do
			local r = rows[i]
			gui_row(r.name, r.now, r.delta, r.rate, r.marker)
		end

		Imgui.text("")
		Imgui.text("[!] pinned possible leak   [>>] growing now   [+] grew then flat   [-] shrank")

		if Imgui.button("Sample", 110) then
			sample()
		end

		Imgui.same_line()

		if Imgui.button("Refresh", 110) then
			mem_profile.refresh_sizes()
		end

		Imgui.same_line()

		if Imgui.button("Clear", 110) then
			mem_profile.clear_history()
		end

		Imgui.same_line()

		local budget_str = Imgui.input_text("budget", tostring(EST_SUBTREE_NODE_BUDGET))
		local parsed_budget = tonumber(budget_str)

		if parsed_budget and parsed_budget > 0 then
			EST_SUBTREE_NODE_BUDGET = parsed_budget
		end

		Imgui.end_window()
	end)

	if not ok and not gui_render_error then
		gui_render_error = true
		close_gui()
	end
end

mem_profile.samples = function(limit)
	if not DEBUG then
		return nil
	end

	local n = #history
	local count = limit or n
	local lines = {}

	for i = math.max(1, n - count + 1), n do
		local entry = history[i]
		local total = 0

		for _, bytes in pairs(entry.values) do
			total = total + bytes
		end

		lines[#lines + 1] = string.format("t=%.1f total=%s", entry.t, fmt_bytes(total))
	end

	return table.concat(lines, "\n")
end

if DEBUG then
	mod.mem_profile_report = mem_profile.report
	mod.mem_profile_samples = mem_profile.samples
	mod.mem_profile_now = mem_profile.sample_now
	mod.mem_profile_interval = mem_profile.interval
	mod.mem_profile_set_auto_report = mem_profile.set_auto_report
	mod.mem_profile_clear = mem_profile.clear_history
	mod.mem_profile_list = mem_profile.list
	mod.mem_profile_track = mem_profile.track
	mod.mem_profile_untrack = mem_profile.untrack
	mod.mem_profile_sizes_refresh = mem_profile.refresh_sizes
	mod.mem_profile_budget = mem_profile.set_budget
	mod.mem_profile_gui = mem_profile.toggle_gui
	mod.mem_profile_force_sample = mem_profile.force_sample
end

if DEBUG then
	pcall(mem_profile.toggle_gui)
end

return mem_profile
