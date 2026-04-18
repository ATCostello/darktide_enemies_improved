local mod = get_mod("enemies_improved")
mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/enemies_improved_localization")

local Managers_player = Managers.player
local Managers_state = Managers.state
local Managers_ui = Managers.ui
local Managers_time = Managers.time
local ScriptUnit_extension = ScriptUnit.extension
local ScriptUnit_has_extension = ScriptUnit.has_extension
local table_clear = table.clear
local math_lerp = math.lerp
local math_min = math.min
local math_max = math.max
local next = next
local math_floor = math.floor
local Unit_alive = Unit.alive

-----------------------------------------------------------------------
-- Marker Distance * Fade
-----------------------------------------------------------------------
mod.world_to_screen = function(self, world_markers, world_pos)
	local camera = self:_get_camera()

	if not camera then
		return nil
	end

	return Camera.world_to_screen(camera, world_pos)
end

mod.apply_marker_fade = function(self)
	local fs = mod.frame_settings

	local ui_manager = Managers_ui
	local hud = ui_manager and ui_manager:get_hud()
	local world_markers = hud and hud:element("HudElementWorldMarkers")
	if not world_markers then
		return
	end

	local markers_by_id = world_markers._markers_by_id
	if not markers_by_id then
		return
	end

	local player = Managers_player:local_player(1)
	if not player then
		return
	end

	local player_unit = player.player_unit
	if not player_unit or not mod.detect_alive(player_unit) then
		return
	end

	local camera = world_markers:_get_camera()
	if not camera then
		return
	end

	local sqrt = math.sqrt
	local clamp = math.clamp
	local max = math.max
	local abs = math.abs

	local cam_pos = Camera.world_position(camera)
	local cam_rot = Camera.world_rotation(camera)
	local cam_forward = Quaternion.forward(cam_rot)

	local px, py, pz =
		Unit.world_position(player_unit, 1).x,
		Unit.world_position(player_unit, 1).y,
		Unit.world_position(player_unit, 1).z
	local cx, cy, cz = cam_pos.x, cam_pos.y, cam_pos.z
	local fx, fy, fz = cam_forward.x, cam_forward.y, cam_forward.z

	local draw_distance = fs.draw_distance

	local fade_start = draw_distance * 0.9 -- starts fading at 70%
	local fade_end = draw_distance -- fully invisible at max distance

	local DIST_FADE_START_SQ = fade_start * fade_start
	local DIST_FADE_END_SQ = fade_end * fade_end

	local STACK_FADE_FACTOR = 0.9
	local DEPTH_THRESHOLD = 0.05
	local MAX_STACK_DIST_SQ = 100
	local MAX_DEPTH_STACK = 100

	local ALIGNMENT_NEAR = 0.96
	local ALIGNMENT_FAR = 0.96

	local global_opacity = fs.global_opacity or 1

	local marker_list = mod._marker_list or {}
	mod._marker_list = marker_list

	for i = #marker_list, 1, -1 do
		marker_list[i] = nil
	end

	-- BUILD MARKER LIST
	for marker_id in next, mod.active_markers do
		local marker = markers_by_id[marker_id]
		if marker and marker.unit and mod.detect_alive(marker.unit) then
			local t = marker.type
			if t == "enemy_healthbar" or t == "enemy_markers" or t == "enemy_debuff" or t == "enemy_utility_debuff" then
				local pos = Unit.world_position(marker.unit, 1)
				local x, y, z = pos.x, pos.y, pos.z

				local dx = x - px
				local dy = y - py
				local dz = z - pz

				local dist_sq = dx * dx + dy * dy + dz * dz

				local tx = x - cx
				local ty = y - cy
				local tz = z - cz

				local depth = tx * fx + ty * fy + tz * fz

				local idx = #marker_list + 1
				local entry = marker_list[idx] or {}
				entry.marker = marker
				entry.x, entry.y, entry.z = x, y, z
				entry.dist_sq = dist_sq
				entry.depth = depth
				marker_list[idx] = entry
			end
		end
	end

	-- SORT
	table.sort(marker_list, function(a, b)
		return a.depth < b.depth
	end)

	-- MAIN LOOP
	for i = 1, #marker_list do
		local data = marker_list[i]
		local marker = data.marker

		local fade

		if data.dist_sq >= (DIST_FADE_END_SQ - 0.01) then
			fade = 0
		elseif data.dist_sq > DIST_FADE_START_SQ then
			local t = (data.dist_sq - DIST_FADE_START_SQ) / (DIST_FADE_END_SQ - DIST_FADE_START_SQ)
			fade = (1 - t) * (1 - t)
		else
			fade = 1
		end

		local depth_fade = 1

		for j = 1, i - 1 do
			local front = marker_list[j]

			local dx = front.x - data.x
			local dy = front.y - data.y
			local dz = front.z - data.z

			local dist_sq_between = dx * dx + dy * dy + dz * dz

			if dist_sq_between < MAX_STACK_DIST_SQ then
				local ftx = front.x - cx
				local fty = front.y - cy
				local ftz = front.z - cz

				local dtx = data.x - cx
				local dty = data.y - cy
				local dtz = data.z - cz

				local front_len_sq = ftx * ftx + fty * fty + ftz * ftz
				local data_len_sq = dtx * dtx + dty * dty + dtz * dtz

				if front_len_sq > 0 and data_len_sq > 0 then
					local inv_front_len = 1 / sqrt(front_len_sq)
					local inv_data_len = 1 / sqrt(data_len_sq)

					local alignment = (ftx * dtx + fty * dty + ftz * dtz) * (inv_front_len * inv_data_len)

					local depth_delta = data.depth - front.depth

					if depth_delta > DEPTH_THRESHOLD and depth_delta < MAX_DEPTH_STACK then
						local t = clamp(depth_delta / MAX_DEPTH_STACK, 0, 1)
						local required_alignment = ALIGNMENT_NEAR + (ALIGNMENT_FAR - ALIGNMENT_NEAR) * t

						if alignment > required_alignment then
							local scaled = 1 - (1 - STACK_FADE_FACTOR) * (1 - t) * (1 - t)
							depth_fade = depth_fade * scaled
						end
					end
				end
			end
		end

		local final_alpha = clamp(fade * depth_fade * global_opacity, 0, 1)

		if abs((marker._last_alpha or 1) - final_alpha) >= 0.02 then
			marker._last_alpha = final_alpha
			marker.alpha_multiplier = final_alpha

			local widget = marker.widget
			if widget and widget.style then
				for key, style_data in next, widget.style do
					if key ~= "damage_numbers" then
						if style_data.default_alpha then
							local a = style_data.default_alpha * final_alpha
							if style_data.color then
								style_data.color[1] = a
							end
							if style_data.text_color then
								style_data.text_color[1] = a
							end
						end
					end
				end
			end
		end
	end
end
