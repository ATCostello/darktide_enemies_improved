local mod = get_mod("enemies_improved")

local fs = mod.frame_settings

local ScriptUnit_has_extension = ScriptUnit.has_extension
local table_clear = table.clear
local math_floor = math.floor
local Unit_alive = Unit.alive

-----------------------------------------------------------------------
-- Horde clustering helpers
-----------------------------------------------------------------------

local CLUSTER_RADIUS = 25
local CLUSTER_RADIUS_SQ = CLUSTER_RADIUS * CLUSTER_RADIUS
local HASH_CELL_SIZE = CLUSTER_RADIUS
local INV_HASH_CELL_SIZE = 2 / HASH_CELL_SIZE
local HORDE_MIN_UNITS_FOR_CLUSTER = fs.hb_horde_clusters_size or 8

local function _build_horde_clusters(units, num_units)
	local old_rep_of = mod.clusters._old_rep_of
	table_clear(old_rep_of)
	for _, _c in ipairs(mod.clusters._horde_clusters) do
		if _c and _c.units and _c.rep_unit then
			for _, _u in ipairs(_c.units) do
				old_rep_of[_u] = _c.rep_unit
			end
		end
	end

	table_clear(mod.clusters._horde_clusters)
	table_clear(mod.clusters._horde_cluster_by_unit)

	HORDE_MIN_UNITS_FOR_CLUSTER = fs.hb_horde_clusters_size

	local player = Managers.player:local_player(1)
	if not player then
		return
	end
	local player_unit = player.player_unit
	if not player_unit or not mod.detect_alive(player_unit) then
		return
	end

	local player_pos = Unit.world_position(player_unit, 1)

	if num_units < HORDE_MIN_UNITS_FOR_CLUSTER then
		return
	end

	local clusters = mod.clusters._horde_clusters
	local spatial = mod.clusters._spatial_hash
	local visited = mod.clusters._visited

	for _, cell in pairs(spatial) do
		table_clear(cell)
	end
	table_clear(spatial)
	table_clear(visited)

	for i = 1, num_units do
		local unit = units[i]

		if unit and HEALTH_ALIVE[unit] and Unit_alive(unit) then
			local entry = mod.enemy_cache[unit]

			local breed
			if entry then
				breed = entry.breed
			else
				local ext = ScriptUnit_has_extension(unit, "unit_data_system")
				breed = ext and ext:breed()
			end

			local tags = breed and breed.tags

			if tags and (tags.horde or tags.roamer) then
				local wp = Unit.world_position(unit, 1, _pos_vec)

				if wp then
					local pos_x = wp.x
					local pos_y = wp.y

					local gx = math_floor(pos_x * INV_HASH_CELL_SIZE)
					local gy = math_floor(pos_y * INV_HASH_CELL_SIZE)
					local key = gx * 73856093 + gy * 19349663

					if key then
						local cell = spatial[key]
						if not cell then
							cell = {}
							spatial[key] = cell
						end

						cell[#cell + 1] = unit
					end
				end
			end
		end
	end

	for i = 1, num_units do
		local unit = units[i]

		if not visited[unit] and mod.detect_alive(unit) then
			local entry = mod.enemy_cache[unit]
			local breed = entry and entry.breed
			local tags = breed and breed.tags

			if not (tags and (tags.horde or tags.roamer)) then
				goto continue
			end

			local z_samples = mod.clusters._z_samples
			table_clear(z_samples)

			local cluster_units = mod.clusters._cluster_units_scratch
			table_clear(cluster_units)
			local queue = mod.clusters._bfs_queue
			table_clear(queue)
			queue[1] = unit
			visited[unit] = true

			local sum_x, sum_y, sum_z = 0, 0, 0
			local count = 0

			local max_z = 0

			local min_x = math.huge
			local max_x = -math.huge
			local min_y = math.huge
			local max_y = -math.huge

			-- Track top 2 heights
			--local highest_z = -math.huge
			--local second_highest_z = -math.huge

			while #queue > 0 do
				local current = queue[#queue]
				queue[#queue] = nil

				local e = mod.enemy_cache[current]
				local wp = Unit.world_position(current, 1, _bfs_pos)

				if wp then
					local cx = wp.x
					local cy = wp.y
					local cz = wp.z

					if e then
						mod.store_enemy_position(e, cx, cy, cz)
					end

					cluster_units[#cluster_units + 1] = current

					sum_x = sum_x + cx
					sum_y = sum_y + cy
					sum_z = sum_z + cz
					count = count + 1
					z_samples[#z_samples + 1] = cz

					if cx < min_x then
						min_x = cx
					end
					if cx > max_x then
						max_x = cx
					end
					if cy < min_y then
						min_y = cy
					end
					if cy > max_y then
						max_y = cy
					end

					local gx = math_floor(cx * INV_HASH_CELL_SIZE)
					local gy = math_floor(cy * INV_HASH_CELL_SIZE)

					for dx = -1, 1 do
						for dy = -1, 1 do
							local key = (gx + dx) * 73856093 + (gy + dy) * 19349663
							local cell = spatial[key]

							if cell then
								local num_in_cell = #cell

								for j = 1, num_in_cell do
									local other = cell[j]

									if not visited[other] then
										local oe = mod.enemy_cache[other]
										if oe and oe.breed == breed and mod.detect_alive(other) then
											local op = Unit.world_position(other, 1, _bfs_other_pos)

											if op then
												local odx = op.x - cx
												local ody = op.y - cy
												local dist_sq = odx * odx + ody * ody

												if dist_sq <= CLUSTER_RADIUS_SQ then
													mod.store_enemy_position(oe, op.x, op.y, op.z)
													visited[other] = true
													queue[#queue + 1] = other
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end

			if count >= HORDE_MIN_UNITS_FOR_CLUSTER then
				local in_cluster = mod.clusters._cluster_members
				table_clear(in_cluster)

				for j = 1, #cluster_units do
					in_cluster[cluster_units[j]] = true
				end

				local rep_unit = nil
				for _j = 1, #cluster_units do
					local _r = old_rep_of[cluster_units[_j]]
					if _r and in_cluster[_r] and mod.detect_alive(_r) then
						rep_unit = _r
						break
					end
				end

				if not rep_unit and player_pos then
					local best_d = math.huge
					for _j = 1, #cluster_units do
						local _u = cluster_units[_j]
						local _wp = Unit.world_position(_u, 1, _pos_vec)
						if _wp then
							local _dx = _wp.x - player_pos.x
							local _dy = _wp.y - player_pos.y
							local _dz = _wp.z - player_pos.z
							local _d = _dx * _dx + _dy * _dy + _dz * _dz
							if _d < best_d then
								best_d = _d
								rep_unit = _u
							end
						end
					end
				end

				if not rep_unit then
					rep_unit = cluster_units[1]
				end

				local inv = 1 / count

				local cx = (min_x + max_x) * 0.5
				local cy = (min_y + max_y) * 0.5
				local avg_z = sum_z * inv

				local width = max_x - min_x
				local height = max_y - min_y

				if width < 1.5 or height < 1.5 then
					local rep = cluster_units[1]
					if rep then
						local entry = mod.enemy_cache[rep]
						local pos = entry and entry.pos
						if pos then
							cx = cx * 0.7 + pos.x * 0.3
							cy = cy * 0.7 + pos.y * 0.3
						end
					end
				end

				-- average
				--local target_z = avg_z + 2.0

				--max
				--local target_z = max_z + 2.0

				-- tallest / second tallest
				-- Fallback if cluster is tiny or something went weird
				--local base_z
				--if second_highest_z > -math.huge then
				--	base_z = (highest_z + second_highest_z) * 0.5
				--else
				--	base_z = highest_z
				--end

				--local target_z = base_z + 2.0

				table.sort(z_samples)

				local trim = math.floor(#z_samples * 0.2) -- trim 20% top/bottom
				local start_i = 1 + trim
				local end_i = #z_samples - trim

				local trimmed_sum = 0
				local trimmed_count = 0

				for i = start_i, end_i do
					trimmed_sum = trimmed_sum + z_samples[i]
					trimmed_count = trimmed_count + 1
				end

				local avg_z = trimmed_count > 0 and (trimmed_sum / trimmed_count) or (sum_z * inv)
				local target_z = avg_z + 2.0

				local idx = #clusters + 1

				local prev = clusters[idx] and clusters[idx].center

				local smooth_z = target_z
				if prev then
					smooth_z = prev.z + (target_z - prev.z) * 0.2
				end

				local units_copy = {}

				for j = 1, #cluster_units do
					units_copy[j] = cluster_units[j]
				end

				local cluster = {
					breed_name = breed.name,
					units = units_copy,
					count = count,
					rep_unit = rep_unit,
					center = {
						x = cx,
						y = cy,
						z = smooth_z,
					},
					total_current = 0,
					total_max = 0,
				}

				clusters[idx] = cluster

				for j = 1, #cluster_units do
					mod.clusters._horde_cluster_by_unit[cluster_units[j]] = idx
				end

				local total_current = 0
				local total_max = 0

				for j = 1, #cluster_units do
					local u = cluster_units[j]
					local e = mod.enemy_cache[u]

					if e and mod.detect_alive(u) then
						local he = e.health_ext
						if he then
							local current_health = he:current_health() or 0
							if current_health then
								total_current = total_current + current_health
							end

							local max_health = he:max_health() or 0
							if max_health then
								total_max = total_max + max_health
							end
						end
					end
				end

				cluster.total_current = total_current
				cluster.total_max = total_max
			end
		end

		::continue::
	end
end

mod.get_horde_cluster_for_unit = function(unit)
	local idx = mod.clusters._horde_cluster_by_unit[unit]
	return idx and mod.clusters._horde_clusters[idx] or nil
end

mod.update_horde_clusters = function(temp, to_process)
	if fs.horde_clusters_enable then
		_build_horde_clusters(temp, to_process)
	else
		table_clear(mod.clusters._horde_clusters)
		table_clear(mod.clusters._horde_cluster_by_unit)
	end
end
