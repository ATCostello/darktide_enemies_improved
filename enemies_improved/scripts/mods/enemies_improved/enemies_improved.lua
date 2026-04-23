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

-- debug mode toggle!!!
mod.DEBUG = false

mod.detect_alive = function(unit)
	return unit and HEALTH_ALIVE[unit] and Unit_alive(unit)
end

-- ENEMIES IMPROVED FUNCTIONS
local FrameSettings = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/utils/frame_settings")
local SettingsFunctions = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/utils/settings_functions")
local DistanceFade = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/utils/fading")

local EnemyMarkersTemplate = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/templates/markers_template")
local EnemyHealthbarTemplate =
	mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/templates/healthbars/healthbar_template")
local EnemyDebuffTemplate = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/templates/debuff_template")

local Outlines = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/outlines")
local Healthbars = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/healthbars")
local Markers = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/markers")
local Debuffs = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/debuffs")
local SpecialAttacks = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/specialattacks")

local BreedQueries = require("scripts/utilities/breed_queries")
local minion_breeds = BreedQueries.minion_breeds_by_name()
local HudElementWorldMarkers = require("scripts/ui/hud/elements/world_markers/hud_element_world_markers")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIScenegraph = require("scripts/managers/ui/ui_scenegraph")
local HudElementSmartTagging = require("scripts/ui/hud/elements/smart_tagging/hud_element_smart_tagging")
local Component = require("scripts/utilities/component")
local MechanismManager = require("scripts/managers/mechanism/mechanism_manager")

mod._broadphase_results = {}

mod.enemy_cache = {}
mod.enemy_markers = {}
mod.enemy_healthbars = {}
mod.enemy_debuffs = {}
mod.enemy_utility_debuffs = {}

mod.active_markers = mod.active_markers or {}

mod.marked_dead = {}
mod.source_unit_cache = mod.source_unit_cache or {}

local MAX_ENEMIES_PER_FRAME = 300
local _enemy_units_temp = {}
local _last_enemy_index = 0
local _horde_units_all = {}

local _player_pos_vec = Vector3.zero()
local _pos_vec = Vector3.zero()

local _horde_clusters = {}
local _horde_cluster_by_unit = {}

local COLOUR_LOOKUP = {
	Gold = { 255, 232, 188, 109 },
	Silver = { 255, 187, 198, 201 },
	Steel = { 255, 161, 166, 169 },
	Black = { 255, 35, 31, 32 },
	Brass = { 255, 226, 199, 126 },
	Terminal = Color.terminal_background(200, true),
	Default = { 255, 161, 166, 169 },
}

-- Soft culling grid
local CULL_CELL_SIZE = 5
local INV_CULL_CELL = 1 / CULL_CELL_SIZE
local _cull_cells = {}
local MAX_PER_CELL = 3

local DEPTH_LAYERS = {
	{ max = 4, min_score = -math.huge }, -- front row ALWAYS visible
	{ max = 6, min_score = 200 }, -- mid row
	{ max = 8, min_score = 400 }, -- back row
	{ max = 100, min_score = 750 }, -- far away...
}

-- priority weights
local PRIORITY = {
	monster = 500,
	captain = 500,
	witch = 500,
	sniper = 500,
	disabler = 200,
	far = 100,
	special = 100,
	elite = 100,
	horde = 20,
	enemy = 20,
}

local function _get_priority(entry, dist_sq, forward_bonus)
	local base = PRIORITY[entry.breed_type] or 0

	-- distance bias (closer = higher priority)
	local dist_bias = 1 / (1 + dist_sq * 0.05)

	if mod.DEBUG then
		mod:echo(
			"Priority for "
				.. entry.breed_type
				.. " = "
				.. base
				.. " + "
				.. dist_bias * 100
				.. " + "
				.. forward_bonus * 50
				.. " = "
				.. base + (dist_bias * 100) + (forward_bonus * 50)
		)
	end
	return base + (dist_bias * 200) + (forward_bonus * 20)
end

-----------------------------------------------------------------------
-- preload resources + reset caches on game state change
-----------------------------------------------------------------------
mod.on_game_state_changed = function(state, state_name)
	-- ensure packages are loaded
	local pkg = Managers.package

	pkg:load("packages/ui/views/inventory_view/inventory_view", "enemies_improved", nil, true)
	pkg:load("packages/ui/views/inventory_weapons_view/inventory_weapons_view", "enemies_improved", nil, true)
	pkg:load("packages/ui/views/inventory_background_view/inventory_background_view", "enemies_improved", nil, true)
	pkg:load(
		"packages/ui/views/inventory_weapon_details_view/inventory_weapon_details_view",
		"enemies_improved",
		nil,
		true
	)
	pkg:load("packages/ui/hud/player_weapon/player_weapon", "enemies_improved", nil, true)
	pkg:load("packages/ui/views/inventory_weapon_marks_view/inventory_weapon_marks_view", "enemies_improved", nil, true)
	pkg:load("packages/ui/views/cosmetics_inspect_view/cosmetics_inspect_view", "enemies_improved", nil, true)
	pkg:load("packages/ui/views/masteries_overview_view/masteries_overview_view", "enemies_improved", nil, true)
	pkg:load("packages/ui/views/mastery_view/mastery_view", "enemies_improved", nil, true)
	pkg:load("packages/ui/views/dlc_purchase_view/dlc_purchase_view", "enemies_improved", nil, true)
	pkg:load("packages/ui/views/talent_builder_view/ogryn", "enemies_improved", nil, true)
	pkg:load("packages/ui/views/talent_builder_view/talent_builder_view", "enemies_improved", nil, true)
	pkg:load("packages/ui/views/expedition_view/expedition_view", "enemies_improved", nil, true)
	pkg:load("packages/ui/views/character_appearance_view/character_appearance_view", "enemies_improved", nil, true)

	-- empty caches
	mod.clear_caches()
	table_clear(mod.marked_dead)
end

local function check_selected_font()
	local fonts = mod._get_font_options()
	local selected_font = mod:get("font_type")
	local exists = false

	for i = 1, #fonts do
		if fonts[i].value == selected_font then
			exists = true
		end
	end

	if not exists and #fonts > 1 then
		mod:echo(mod:localize(font_no_longer_available) .. " \n" .. fonts[1].text)
		mod:set("font_type", fonts[1].value)
	end
end

mod.dmf = get_mod("DMF")

mod.on_all_mods_loaded = function()
	check_selected_font()

	mod.clear_caches()

	mod.init_healthbar_defaults()
	mod.update_breed_colours()
	mod.update_breed_icons()

	local outline_settings = require("scripts/settings/outline/outline_settings")
	mod.apply_enemy_outlines(outline_settings)

	mod.load_toggled_debuffs_state()
	mod.load_debuff_colours()

	mod.dmf = get_mod("DMF")
end

mod:hook_safe(CLASS.HudElementWorldMarkers, "init", function(self)
	-- add new marker templates to templates table
	self._marker_templates[EnemyMarkersTemplate.name] = EnemyMarkersTemplate
	self._marker_templates[EnemyHealthbarTemplate.name] = EnemyHealthbarTemplate
	self._marker_templates[EnemyDebuffTemplate.name] = EnemyDebuffTemplate
end)

-----------------------------------------------------------------------
-- Hook into the markers update to recalculate enemies.
-----------------------------------------------------------------------
mod:hook_safe(CLASS.HudElementWorldMarkers, "update", function(self, dt, t)
	-- throttle updates according to enemy amounts to help keep performance in check...
	local enemy_count = 0
	for _ in next, mod.enemy_cache do
		enemy_count = enemy_count + 1
	end
	local fs = mod.frame_settings

	local update_interval

	update_interval = fs.general_throttle_rate

	self._update_time = (self._update_time or 0) + dt

	if self._update_time > update_interval then
		self._update_time = 0
		mod.update_enemies(dt, t)
	end

	-- pulse special attacks (Outside of global throttle)
	if fs.outline_specials_enable or fs.marker_specials_enable or fs.healthbar_specials_enable then
		local interval = fs.special_attack_pulse_speed or 0.5

		for _, entry in next, mod.enemy_cache do
			if entry.special_attack_imminent then
				entry._pulse_timer = (entry._pulse_timer or 0) + dt

				if entry._pulse_timer >= interval then
					mod.pulse_enemy_outline(entry)
					entry._pulse_timer = 0
				end
			else
				mod.remove_alert_outline(entry)
			end
		end
	end

	-- Hide default health bars if custom healthbars are enabled!
	if fs.healthbar_enable then
		local markers = self._markers
		if not markers or #markers == 0 then
			return
		end

		for i = 1, #markers do
			local marker = markers[i]
			local template = marker and marker.template

			if template then
				local name = template.name
				if name and name ~= "enemy_healthbar" and string.find(name, "damage_indicator", 1, true) then
					marker.draw = false
					marker.alpha_multiplier = 0
				end
			end
		end
	end
end)

mod.get_marker_by_id = function(id)
	local ui_manager = Managers.ui
	local hud = ui_manager:get_hud()
	local world_markers = hud and hud:element("HudElementWorldMarkers")
	local markers_by_id = world_markers and world_markers._markers_by_id

	-- DEBUG TO CREATE MARKER LIST
	if mod.DEBUG then
		dbg_markers = world_markers._markers_by_type
	end
	dbg_markers = world_markers._markers_by_type

	if markers_by_id then
		return markers_by_id[id]
	else
		return nil
	end
end

mod.force_remove_unit_markers = function(unit)
	if not unit then
		return
	end

	local function remove(id)
		if id then
			Managers.event:trigger("remove_world_marker", id)
			mod.active_markers[id] = nil
		end
	end

	remove(mod.enemy_markers[unit])
	remove(mod.enemy_healthbars[unit])
	remove(mod.enemy_debuffs[unit])
	remove(mod.enemy_utility_debuffs[unit])

	mod.enemy_markers[unit] = nil
	mod.enemy_healthbars[unit] = nil
	mod.enemy_debuffs[unit] = nil
	mod.enemy_utility_debuffs[unit] = nil

	-- reset cluster state if this unit was a rep
	local cluster = mod.get_horde_cluster_for_unit(unit)
	if cluster and cluster.rep_unit == unit then
		cluster._healthbar_created = false
		cluster._healthbar_marker_id = nil
	end

	local entry = mod.enemy_cache[unit]
	if entry then
		entry._healthbar_created = false
		entry._healthbar_pending = nil
		entry._marker_created = false

		mod.disable_enemy_outlines(unit, entry)
		entry._outline_applied = false
	end
end

-----------------------------------------------------------------------
-- Enemy scanning
-----------------------------------------------------------------------

mod.scan_enemies = function()
	local fs = mod.frame_settings

	local local_player = Managers_player:local_player(1)
	if not local_player then
		return
	end

	local player_unit = local_player.player_unit
	if not player_unit or not mod.detect_alive(player_unit) then
		return
	end

	local current_pos = Unit.world_position(player_unit, 1, _player_pos_vec)

	--[[local last_pos = mod._last_scan_pos

	-- Skip scan if player hasn't moved enough
	if last_pos then
		local dx = current_pos.x - last_pos.x
		local dy = current_pos.y - last_pos.y
		local dz = current_pos.z - last_pos.z

		local dist_sq = dx * dx + dy * dy + dz * dz

		if dist_sq < 1 then
			return
		end
	end

	mod._last_scan_pos = current_pos]]

	local extension_manager = Managers_state.extension
	if not extension_manager then
		return
	end

	local broadphase_system = extension_manager:system("broadphase_system")
	local side_system = extension_manager:system("side_system")
	if not broadphase_system or not side_system then
		return
	end

	local side = side_system.side_by_unit[player_unit]
	if not side then
		return
	end

	local broadphase = broadphase_system.broadphase
	local from_pos = current_pos
	local enemy_side_names = side:relation_side_names("enemy")
	local range = mod.frame_settings.draw_distance

	local results = mod._broadphase_results
	table_clear(results)

	local num_hits = broadphase.query(broadphase, from_pos, range, results, enemy_side_names)

	if num_hits == 0 then
		return
	end

	local cache = mod.enemy_cache

	-- mark unseen
	for _, data in next, cache do
		data.seen = false
	end

	table_clear(_horde_units_all)
	table_clear(_cull_cells)

	for i = 1, num_hits do
		local unit = results[i]

		if unit and HEALTH_ALIVE[unit] and Unit_alive(unit) then
			local forward_bonus = mod.get_forward_dot and mod.get_forward_dot(player_unit, unit) or 1

			-- VIEW CONE FILTER (HARD REJECT)
			if forward_bonus <= 0 then
				mod.force_remove_unit_markers(unit)

				cache[unit] = nil
				mod.marked_dead[unit] = nil

				goto skip_breed
			end

			-- LOS FILTER (HARD REJECT)
			local world = Managers.world:world("level_world")
			local physics_world = World.get_data(world, "physics_world")

			if physics_world then
				if not mod.has_line_of_sight(player_unit, unit, physics_world) then
					mod.force_remove_unit_markers(unit)

					cache[unit] = nil
					mod.marked_dead[unit] = nil

					goto skip_breed
				end
			end

			local entry = cache[unit]

			local pos = Unit.world_position(unit, 1, _pos_vec)
			if entry then
				entry.pos = Vector3(pos.x, pos.y, pos.z)
			end

			local dx = pos.x - current_pos.x
			local dy = pos.y - current_pos.y
			local dz = pos.z - current_pos.z
			local dist_sq = dx * dx + dy * dy + dz * dz

			local unit_data_ext = ScriptUnit_has_extension(unit, "unit_data_system")
			if not unit_data_ext then
				goto skip_breed
			end

			local breed = unit_data_ext:breed()
			local breed_type = mod.find_breed_category(unit)

			-- collect ALL horde units BEFORE culling
			if breed and breed.tags and (breed.tags.horde or breed.tags.roamer) then
				_horde_units_all[#_horde_units_all + 1] = unit
			end

			-- DO NOT ADD WIDGETS FOR THESE BREEDS:
			if breed.name == "sand_vortex" or breed.name == "nurgle_flies" or breed.name == "attack_valkyrie" then
				goto skip_breed
			end

			if fs.spatial_culling then
				local gx = math_floor(pos.x * INV_CULL_CELL)
				local gy = math_floor(pos.y * INV_CULL_CELL)

				local temp_entry = entry or {
					unit = unit,
					breed = breed,
					breed_type = breed_type,
				}

				local score = _get_priority(temp_entry, dist_sq, forward_bonus)

				if entry then
					score = score + 10
				end

				temp_entry._priority_score = score

				local key = gx * 73856093 + gy * 19349663
				local list = _cull_cells[key]

				if not list then
					list = {}
					_cull_cells[key] = list
				end

				list[#list + 1] = {
					unit = unit,
					score = score,
					dist_sq = dist_sq,
					entry = entry,
					unit_data_ext = unit_data_ext,
					breed = breed,
					breed_type = breed_type,
					pos = Vector3(pos.x, pos.y, pos.z),
				}

				goto skip_breed
			else
				if not entry then
					cache[unit] = {
						unit = unit,
						seen = true,

						dead = false,

						-- cache extensions
						health_ext = ScriptUnit_has_extension(unit, "health_system"),
						unit_data_ext = unit_data_ext,
						behavior_ext = ScriptUnit_has_extension(unit, "behavior_system"),

						is_horde = mod.is_horde(unit),

						breed = breed,
						breed_type = mod.find_breed_category(unit),

						special_attack_event = nil,
						special_attack_imminent = false,
						special_attack_timer = 0,

						-- outlines
						alert_outline = false,
						outline_name = nil,

						alert_healthbar = false,

						_marker_created = false,
						_healthbar_created = false,
						_last_marker_update = 0,
						_last_healthbar_update = 0,
					}

					mod.marked_dead[unit] = nil
				else
					entry.seen = true
					mod.marked_dead[unit] = nil
				end

				-- DEBUG
				if mod.DEBUG then
					-- debug to add outlines to enemies that have been processed, and should have a healthbar...
					local extension_manager = Managers.state.extension
					mod.add_outline(unit, "enemies_improved_alert", extension_manager:system("outline_system"))
				end
			end
			::skip_breed::
		end
	end

	if fs.spatial_culling then
		for _, list in pairs(_cull_cells) do
			table.sort(list, function(a, b)
				if a.score == b.score then
					return a.dist_sq < b.dist_sq
				end
				return a.score > b.score
			end)

			for i = 1, #list do
				local data = list[i]
				local unit = data.unit

				local keep = false

				for l = 1, #DEPTH_LAYERS do
					local layer = DEPTH_LAYERS[l]

					if i <= layer.max then
						if data.score >= layer.min_score then
							keep = true
						end
						break
					end
				end

				if keep then
					local entry = mod.enemy_cache[unit]

					if not entry then
						mod.enemy_cache[unit] = {
							unit = unit,
							seen = true,
							dead = false,

							health_ext = ScriptUnit_has_extension(unit, "health_system"),
							unit_data_ext = data.unit_data_ext,
							behavior_ext = ScriptUnit_has_extension(unit, "behavior_system"),

							is_horde = mod.is_horde(unit),

							breed = data.breed,
							breed_type = data.breed_type,

							_priority_score = data.score,
							pos = data.pos,
						}
					else
						entry.seen = true
						entry._priority_score = data.score
						entry.pos = data.pos
					end

					mod.marked_dead[unit] = nil

					-- DEBUG
					if mod.DEBUG then
						-- debug to add outlines to enemies that have been processed, and should have a healthbar...
						local extension_manager = Managers.state.extension
						mod.add_outline(unit, "enemies_improved_alert", extension_manager:system("outline_system"))
					end
				else
					-- culled
					mod.force_remove_unit_markers(unit)

					local entry = mod.enemy_cache[unit]
					if entry then
						entry.seen = false
					end

					-- DEBUG
					if mod.DEBUG then
						-- debug to add outlines to enemies that have been processed, and should have a healthbar...
						local extension_manager = Managers.state.extension
						mod.remove_outline(unit, "enemies_improved_alert", extension_manager:system("outline_system"))
					end
				end
			end
		end
	end
end

-----------------------------------------------------------------------
-- Horde clustering helpers
-----------------------------------------------------------------------

-- Distance-based clustering radius (in meters)
local CLUSTER_RADIUS = 10
local CLUSTER_RADIUS_SQ = CLUSTER_RADIUS * CLUSTER_RADIUS
local HASH_CELL_SIZE = CLUSTER_RADIUS
local INV_HASH_CELL_SIZE = 1 / HASH_CELL_SIZE
local HORDE_MIN_UNITS_FOR_CLUSTER = 15

local function _build_horde_clusters(units, num_units)
	table_clear(_horde_clusters)
	table_clear(_horde_cluster_by_unit)

	if num_units < HORDE_MIN_UNITS_FOR_CLUSTER then
		return
	end

	local clusters = _horde_clusters
	local spatial = {}

	-- Step 1: build spatial hash
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
				local pos

				if entry and entry.pos then
					pos = entry.pos
				else
					pos = Unit.world_position(unit, 1, _pos_vec)
					if entry then
						entry.pos = Vector3(pos.x, pos.y, pos.z)
					end
				end

				local gx = math_floor(pos.x * INV_HASH_CELL_SIZE)
				local gy = math_floor(pos.y * INV_HASH_CELL_SIZE)
				local key = gx * 73856093 + gy * 19349663

				local cell = spatial[key]
				if not cell then
					cell = {}
					spatial[key] = cell
				end

				cell[#cell + 1] = unit
			end
		end
	end

	local visited = {}

	-- Step 2: cluster via BFS
	for i = 1, num_units do
		local unit = units[i]
		local z_samples = {}

		if not visited[unit] and mod.detect_alive(unit) then
			local entry = mod.enemy_cache[unit]
			local breed = entry and entry.breed
			local tags = breed and breed.tags

			if not (tags and (tags.horde or tags.roamer)) then
				goto continue
			end

			local cluster_units = {}
			local queue = { unit }
			visited[unit] = true

			local sum_x, sum_y, sum_z = 0, 0, 0
			local count = 0

			local max_z = 0

			-- Bounds for midpoint center
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
				local pos = e.pos or Unit.world_position(current, 1)
				e.pos = pos

				cluster_units[#cluster_units + 1] = current

				-- avg/max
				--[[sum_x = sum_x + pos.x
				sum_y = sum_y + pos.y
				sum_z = sum_z + pos.z
				count = count + 1

				if max_z < pos.z then
					max_z = pos.z
				end	

				sum_x = sum_x + pos.x]]

				-- tallest & second tallest
				--sum_x = sum_x + pos.x
				--sum_y = sum_y + pos.y
				--count = count + 1

				-- Proper centroid accumulation (X, Y, Z)
				sum_x = sum_x + pos.x
				sum_y = sum_y + pos.y
				sum_z = sum_z + pos.z
				count = count + 1
				z_samples[#z_samples + 1] = pos.z

				-- Bounds tracking (X/Y center)
				if pos.x < min_x then
					min_x = pos.x
				end
				if pos.x > max_x then
					max_x = pos.x
				end
				if pos.y < min_y then
					min_y = pos.y
				end
				if pos.y > max_y then
					max_y = pos.y
				end

				--local z = pos.z

				--if z > highest_z then
				--	second_highest_z = highest_z
				--	highest_z = z
				--elseif z > second_highest_z then
				--	second_highest_z = z
				--end

				local gx = math_floor(pos.x * INV_HASH_CELL_SIZE)
				local gy = math_floor(pos.y * INV_HASH_CELL_SIZE)

				-- check neighboring cells
				for dx = -1, 1 do
					for dy = -1, 1 do
						local key = (gx + dx) * 73856093 + (gy + dy) * 19349663
						local cell = spatial[key]

						if cell then
							for j = 1, #cell do
								local other = cell[j]

								if not visited[other] and mod.detect_alive(other) then
									local oe = mod.enemy_cache[other]
									if oe and oe.breed == breed then
										local op = oe.pos or Unit.world_position(other, 1)
										oe.pos = op

										local dx = op.x - pos.x
										local dy = op.y - pos.y
										local dist_sq = dx * dx + dy * dy

										if dist_sq <= CLUSTER_RADIUS_SQ then
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

			if count >= HORDE_MIN_UNITS_FOR_CLUSTER then
				local inv = 1 / count

				local cx = (min_x + max_x) * 0.5
				local cy = (min_y + max_y) * 0.5
				local avg_z = sum_z * inv

				local width = max_x - min_x
				local height = max_y - min_y

				-- If cluster is too thin, fall back slightly toward centroid feel
				if width < 1.5 or height < 1.5 then
					-- small bias toward first unit
					local rep = cluster_units[1]
					if rep then
						local pos = mod.enemy_cache[rep].pos
						cx = cx * 0.7 + pos.x * 0.3
						cy = cy * 0.7 + pos.y * 0.3
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

				-- smooth
				local prev = clusters[idx] and clusters[idx].center

				local smooth_z = target_z
				if prev then
					smooth_z = prev.z + (target_z - prev.z) * 0.2
				end

				local cluster = {
					breed_name = breed.name,
					units = cluster_units,
					count = count,
					rep_unit = cluster_units[1],
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
					_horde_cluster_by_unit[cluster_units[j]] = idx
				end

				-- aggregate health (cached extensions)
				local total_current = 0
				local total_max = 0

				for j = 1, #cluster_units do
					local u = cluster_units[j]
					local e = mod.enemy_cache[u]

					if e and mod.detect_alive(u) then
						local he = e.health_ext
						if he then
							total_current = total_current + (he:current_health() or 0)
							total_max = total_max + (he:max_health() or 0)
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
	local idx = _horde_cluster_by_unit[unit]
	return idx and _horde_clusters[idx] or nil
end

-----------------------------------------------------------------------
-- Enemy markers
-----------------------------------------------------------------------

mod.get_time = function()
	local tm = Managers.time
	if tm then
		return tm:time("gameplay")
	end

	return 0
end

mod.ts = function()
	return string.format("[%.3f]", mod.get_time())
end

function string.starts(String, Start)
	return string.sub(String, 1, string.len(Start)) == Start
end

mod.remove_dead = function()
	local units_to_remove = {}

	-- Get player
	local player = Managers.player:local_player(1)
	if not player then
		return
	end

	local player_unit = player.player_unit
	if not player_unit or not mod.detect_alive(player_unit) then
		return
	end

	local player_pos = Unit.world_position(player_unit, 1)
	local max_dist_sq = (mod.frame_settings.draw_distance or 50) ^ 2
	local mark_dead = false

	-- Go through each marker type and clear caches.
	local function iterate_types_removal(unit)
		local id

		id = mod.enemy_markers[unit]
		if id then
			Managers.event:trigger("remove_world_marker", id)
			mod.active_markers[id] = nil
		end

		local fs = mod.frame_settings

		id = mod.enemy_healthbars[unit]
		if id and not fs.hb_show_dps then
			Managers.event:trigger("remove_world_marker", id)
			mod.active_markers[id] = nil
		end

		id = mod.enemy_debuffs[unit]
		if id then
			Managers.event:trigger("remove_world_marker", id)
			mod.active_markers[id] = nil
		end

		id = mod.enemy_utility_debuffs[unit]
		if id then
			Managers.event:trigger("remove_world_marker", id)
			mod.active_markers[id] = nil
		end

		units_to_remove[#units_to_remove + 1] = unit
	end

	-- Main loop
	for unit, entry in next, mod.enemy_cache do
		local remove = false

		-- Dead check
		if not mod.detect_alive(unit) then
			remove = true
			mark_dead = true
		else
			local health_extension = entry and entry.health_ext
			if health_extension and health_extension:current_health_percent() <= 0 then
				remove = true
				mark_dead = true
			end
		end

		-- Distance check
		if not remove and player_pos then
			local pos = entry.pos
			if not pos then
				pos = Unit.world_position(unit, 1)
				entry.pos = pos
			end

			local dx = pos.x - player_pos.x
			local dy = pos.y - player_pos.y
			local dz = pos.z - player_pos.z
			local dist_sq = dx * dx + dy * dy + dz * dz

			if dist_sq > max_dist_sq then
				remove = true
				--mark_dead = false

				-- disable outlines too
				mod.disable_enemy_outlines(unit, entry)
				entry._outline_applied = false
			end
		end

		-- If this unit was a cluster rep, clear cluster healthbar state
		local cluster = mod.get_horde_cluster_for_unit(unit)
		if cluster and cluster.rep_unit == unit then
			cluster._healthbar_created = false
			cluster._healthbar_marker_id = nil
		end

		if remove then
			iterate_types_removal(unit)
		end
	end

	-- Cleanup
	for _, unit in next, units_to_remove do
		if mark_dead then
			mod.marked_dead[unit] = true
		else
			mod.marked_dead[unit] = nil
		end
		local fs = mod.frame_settings

		if not fs.hb_show_dps then
			mod.enemy_healthbars[unit] = nil
		end
		mod.enemy_debuffs[unit] = nil
		mod.enemy_utility_debuffs[unit] = nil
		mod.enemy_markers[unit] = nil
		mod.enemy_cache[unit] = nil
	end
end

mod.is_horde = function(unit)
	if Unit_alive(unit) then
		local tags = mod.get_breed_tags(unit)
		local is_horde = tags and (tags.horde or tags.roamer) or false

		return is_horde
	else
		return false
	end
end

-----------------------------------------------------------------------
-- Cache clearing
-----------------------------------------------------------------------

mod.clear_caches = function()
	table_clear(mod._broadphase_results)
	table_clear(mod.source_unit_cache)

	table_clear(mod.enemy_markers)
	table_clear(mod.enemy_healthbars)
	table_clear(mod.enemy_debuffs)
	table_clear(mod.enemy_utility_debuffs)
	table_clear(mod.active_markers)

	table_clear(mod.enemy_cache)
	--table_clear(mod.marked_dead)

	table_clear(_enemy_units_temp)
	table_clear(_horde_clusters)
	table_clear(_horde_cluster_by_unit)
end

mod.update_horde_clusters = function(temp, to_process)
	local fs = mod.frame_settings

	if fs.horde_clusters_enable then
		_build_horde_clusters(temp, to_process)
	else
		table_clear(_horde_clusters)
		table_clear(_horde_cluster_by_unit)
	end
end

-----------------------------------------------------------------------
-- Main update orchestration
-----------------------------------------------------------------------

mod.update_enemies = function(dt, t)
	local fs = mod.frame_settings

	for _, entry in next, mod.enemy_cache do
		entry.pos = nil
	end

	mod.scan_enemies()

	if not next(mod.enemy_cache) then
		return
	end

	local temp = _enemy_units_temp
	local count = 0

	for unit in next, mod.enemy_cache do
		count = count + 1
		temp[count] = unit
	end

	if count == 0 then
		return
	end

	-- rotate index so we don't always process the same subset first
	_last_enemy_index = (_last_enemy_index % count) + 1

	local to_process = math_min(count, MAX_ENEMIES_PER_FRAME)

	-- select a rotating window of units into first to_process entries
	if to_process < count then
		local idx = _last_enemy_index
		for i = 1, to_process do
			if idx > count then
				idx = 1
			end
			-- swap into front
			temp[i], temp[idx] = temp[idx], temp[i]
			idx = idx + 1
		end
	end

	-- trim any extra entries in temp
	for i = to_process + 1, count do
		temp[i] = nil
	end

	-- update horde clusters...
	if fs.horde_clusters_enable then
		mod.update_horde_clusters(_horde_units_all, #_horde_units_all)
	end

	local player = Managers.player:local_player(1)
	local player_unit = player and player.player_unit
	local player_pos = player_unit and Unit.world_position(player_unit, 1)
	local max_dist_sq = fs.draw_distance * fs.draw_distance

	-- go through enemy_cache and perform updates...
	for i = 1, to_process do
		local unit = temp[i]

		if player_pos and Unit_alive(unit) then
			local entry = mod.enemy_cache[unit]

			if not entry.pos then
				entry.pos = Unit.world_position(unit, 1)
			end

			local pos = entry.pos

			local dx = pos.x - player_pos.x
			local dy = pos.y - player_pos.y
			local dz = pos.z - player_pos.z
			local dist_sq = dx * dx + dy * dy + dz * dz

			-- LOD cutoff
			if dist_sq > max_dist_sq then
				goto continue_enemy_loop
			end
		end

		if mod.enemy_cache[unit] then
			local entry = mod.enemy_cache[unit]

			if not entry.seen then
				goto continue_enemy_loop
			end

			mod.update_enemy_markers(entry, t)

			if fs.outlines_enable then
				mod.update_enemy_outlines(entry)
			end

			if fs.healthbar_enable or fs.show_damage_numbers then
				mod.update_enemy_healthbars(entry)
			end

			if fs.debuff_enable then
				mod.update_enemy_debuffs(entry)
			end

			mod.update_special_attack_detection(entry)
		end

		::continue_enemy_loop::
	end

	-- Apply distance / stacking fade to all active markers
	if fs.enable_depth_fading then
		mod.apply_marker_fade(self)
	end
	mod.remove_dead()
end

mod.get_breed_tags = function(unit)
	if not mod.detect_alive(unit) then
		return nil
	end

	local unit_data_extension = ScriptUnit_has_extension(unit, "unit_data_system")

	if not unit_data_extension then
		return nil
	end

	local breed = unit_data_extension:breed()

	if breed then
		return breed.tags
	end

	return nil
end

-- Tags are ordered from priority (Top to bottom)
-- so first match is what will be returned.
-- breed points to the breed tags list, get from mod.get_breed_tags(unit)
mod.find_breed_category = function(unit)
	if unit then
		local tags = mod.get_breed_tags(unit) or {}
		if tags.horde or tags.roamer then
			return "horde"
		elseif tags.captain or tags.cultist_captain then
			return "captain"
		elseif tags.witch then
			return "witch"
		elseif tags.monster then
			return "monster"
		elseif tags.disabler then
			return "disabler"
		elseif tags.special and tags.sniper then
			return "sniper"
		elseif tags.elite and tags.far or tags.special and tags.far or tags.elite and tags.close then
			return "far"
		elseif tags.elite then
			return "elite"
		elseif tags.special then
			return "special"
		else
			return "enemy"
		end
	end
end
