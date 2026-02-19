-- features to add:
--
-- MARKERS:
-- initial (unaggroed) colour
-- player aggroed colour
-- friend aggroed colour
-- pulsing on special attacks
--
-- HEALTHBARS:
-- initial colour
-- shield colour
-- 20% health execute
--
-- DEBUFFS:
-- icons (emojis?)
-- stacks
-- stack grouping for hordes?

local mod = get_mod("enemy_markers")

mod:io_dofile("enemy_markers/scripts/mods/enemy_markers/enemy_markers_localization")
local EnemyMarkersTemplate = mod:io_dofile("enemy_markers/scripts/mods/enemy_markers/enemy_markers_template")
local EnemyHealthbarTemplate = mod:io_dofile("enemy_markers/scripts/mods/enemy_markers/enemy_healthbar_template")
local EnemyDebuffTemplate = mod:io_dofile("enemy_markers/scripts/mods/enemy_markers/enemy_debuff_template")
local EnemyUtilityDebuffTemplate =
	mod:io_dofile("enemy_markers/scripts/mods/enemy_markers/enemy_utility_debuff_template")

local HudElementWorldMarkers = require("scripts/ui/hud/elements/world_markers/hud_element_world_markers")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIScenegraph = require("scripts/managers/ui/ui_scenegraph")
local HudElementSmartTagging = require("scripts/ui/hud/elements/smart_tagging/hud_element_smart_tagging")

-- Per-frame computed settings
mod.frame_settings = {}

-- Lazy per-marker-type cache
mod.fc_typecache = {}

-- Caching enemy markers and broadphase results
mod.enemy_cache = {}
mod.enemy_markers = {}
mod.enemy_markers_alerted = {}
mod.enemy_healthbars = {}
mod.enemy_debuffs = {}
mod.enemy_utility_debuffs = {}

mod._broadphase_results = {}
local healthbar_ids = {}
mod.marked_dead = {}

-- Per-frame processing cap and temp buffers (1)
local MAX_ENEMIES_PER_FRAME = 100 -- tune if needed
local _enemy_units_temp = {} -- compact list of units this frame
local _last_enemy_index = 0 -- rotating index for fairness

-- Alerted throttling (2)
local _alert_last_t = 0
local ALERT_UPDATE_INTERVAL = 0.1 -- seconds

-- Dead bookkeeping cleanup (5)
local _dead_cleanup_accum = 0
local DEAD_CLEANUP_INTERVAL = 5 -- seconds

-----------------------------------------------------------------------
-- Horde healthbar clustering
-----------------------------------------------------------------------

-- tune these defaults
local HORDE_CLUSTER_RADIUS_SQ = 15 ^ 2
local HORDE_MIN_UNITS_FOR_CLUSTER = 6     -- minimum units in a horde clump

-- Cluster data for current frame
local _horde_clusters = {}         -- { [idx] = { breed_name, units={unit,...}, center=Vector3, total_current, total_max, rep_unit } }
local _horde_cluster_by_unit = {}  -- [unit] = idx
-- Tracks the highest pooled max HP seen for each cluster index

-----------------------------------------------------------------------
-- Global colour lookup
-----------------------------------------------------------------------

local COLOUR_LOOKUP = {
	Gold = { 255, 232, 188, 109 },
	Silver = { 255, 187, 198, 201 },
	Steel = { 255, 161, 166, 169 },
	Black = { 255, 35, 31, 32 },
	Brass = { 255, 226, 199, 126 },
	Terminal = Color.terminal_background(200, true),
	Default = { 255, 161, 166, 169 },
}

-----------------------------------------------------------------------
-- Helpers to avoid repeated global table lookups
-----------------------------------------------------------------------

local Managers_player = Managers.player
local Managers_state = Managers.state
local Managers_event = Managers.event
local Managers_ui = Managers.ui
local Managers_time = Managers.time
local Unit_alive = Unit.alive
local ScriptUnit_extension = ScriptUnit.extension
local ScriptUnit_has_extension = ScriptUnit.has_extension
local table_clear = table.clear
local math_lerp = math.lerp
local math_min = math.min
local math_max = math.max
local next = next
local pairs = pairs

-----------------------------------------------------------------------
-- Add marker templates + preload resources once
-----------------------------------------------------------------------

mod:hook_safe(CLASS.HudElementWorldMarkers, "init", function(self)
	-- add new marker templates to templates table
	self._marker_templates[EnemyMarkersTemplate.name] = EnemyMarkersTemplate
	self._marker_templates[EnemyHealthbarTemplate.name] = EnemyHealthbarTemplate
	self._marker_templates[EnemyDebuffTemplate.name] = EnemyDebuffTemplate
	self._marker_templates[EnemyUtilityDebuffTemplate.name] = EnemyUtilityDebuffTemplate
	-- clear caches on markers init
	mod.clear_caches()

	-- Preload views to get textures/icons, to prevent crashing.
	-- This is all one-time, so it's fine to be a bit heavy.
	Managers.package:load("packages/ui/views/inventory_view/inventory_view", "enemy_markers", nil, true)
	Managers.package:load("packages/ui/views/inventory_weapons_view/inventory_weapons_view", "enemy_markers", nil, true)
	Managers.package:load(
		"packages/ui/views/inventory_background_view/inventory_background_view",
		"enemy_markers",
		nil,
		true
	)
	Managers.package:load(
		"packages/ui/views/inventory_weapon_details_view/inventory_weapon_details_view",
		"enemy_markers",
		nil,
		true
	)

	Managers.package:load("packages/ui/hud/player_weapon/player_weapon", "enemy_markers", nil, true)
	Managers.package:load(
		"packages/ui/views/inventory_weapon_marks_view/inventory_weapon_marks_view",
		"enemy_markers",
		nil,
		true
	)

	Managers.package:load("packages/ui/views/cosmetics_inspect_view/cosmetics_inspect_view", "enemy_markers", nil, true)
	Managers.package:load(
		"packages/ui/views/masteries_overview_view/masteries_overview_view",
		"enemy_markers",
		nil,
		true
	)
	Managers.package:load("packages/ui/views/mastery_view/mastery_view", "enemy_markers", nil, true)
	Managers.package:load("packages/ui/views/mission_board_view/mission_board_view", "enemy_markers", nil, true)
	Managers.package:load("packages/ui/views/marks_vendor_view/marks_vendor_view", "enemy_markers", nil, true)
	Managers.package:load(
		"packages/ui/views/marks_goods_vendor_view/marks_goods_vendor_view",
		"enemy_markers",
		nil,
		true
	)
	Managers.package:load(
		"packages/ui/views/premium_currency_purchase_view/premium_currency_purchase_view",
		"enemy_markers",
		nil,
		true
	)
	Managers.package:load("packages/ui/views/store_view/store_view", "enemy_markers", nil, true)
end)

-----------------------------------------------------------------------
-- Hook into the frame update
-----------------------------------------------------------------------

mod:hook_safe(CLASS.HudElementWorldMarkers, "update", function(self, dt, t)
	-- Update enemies/markers for this frame
	mod.update_enemies(dt, t)

	local markers = self._markers
	if not markers or #markers == 0 then
		return
	end

	-- Hide default health bars (all damage_indicator variants except our custom)
	for i = 1, #markers do
		local marker = markers[i]
		local template = marker and marker.template

		if template then
			local name = template.name
			-- cheap check first: avoid string.find unless "damage_indicator" might be present
			if name and name ~= "enemy_healthbar" and string.find(name, "damage_indicator", 1, true) then
				marker.draw = false
				marker.alpha_multiplier = 0
				marker.force_invisible = true
				marker.visibility_group = "never"
			end
		end
	end
end)

-----------------------------------------------------------------------
-- Frame settings builder (minimize mod:get per-frame)
-----------------------------------------------------------------------

-- Cached last-used draw distance setting key to avoid extra lookups
local _last_draw_distance_key
local _last_draw_distance_value = 50

local function build_frame_settings(mod, dt)
	local fs = mod.frame_settings

	-- Store dt for features that need time accumulation (5)
	fs.dt = dt or 0

	-- ADS detection ONCE per frame
	local is_ads = false
	local player = Managers_player:local_player(1)
	if player then
		local unit = player.player_unit
		if unit and Unit_alive(unit) then
			local ude = ScriptUnit_extension(unit, "unit_data_system")
			if ude then
				local af = ude:read_component("alternate_fire")
				is_ads = af and af.is_active or false
			end
		end
	end

	fs.is_ads = is_ads

	-- LOS fade settings (3: shared, to be respected by templates)
	local los_enabled = mod:get("los_fade_enable") == true
	local los_opacity = (mod:get("los_opacity") or 100) / 100
	local ads_los_opacity = (mod:get("ads_los_opacity") or 100) / 100

	fs.los_enabled = los_enabled
	fs.los_opacity = los_opacity
	fs.ads_los_opacity = ads_los_opacity
	fs.ads_blend = math_lerp(fs.ads_blend or 0, is_ads and 1 or 0, 0.25)

	-- Draw distance setting may itself be a key referencing another setting
	local draw_distance_key = mod:get("draw_distance")
	if draw_distance_key ~= _last_draw_distance_key then
		_last_draw_distance_key = draw_distance_key
		_last_draw_distance_value = mod:get(draw_distance_key) or 50
	end
	fs.draw_distance = _last_draw_distance_value

	-- Feature toggles (single batch of mod:get per frame)
	fs.enable = fs.enable or {}
	local enable = fs.enable
	enable.markers = mod:get("markers_enable")
	enable.healthbar = mod:get("healthbar_enable")
	enable.debuff = mod:get("debuff_enable")
	enable.horde = mod:get("hb_horde_enable") or false
	enable.horde_clusters = mod:get("hb_horde_clusters_enable") or false
end

-----------------------------------------------------------------------
-- Enemy scanning: broadphase + cache
-----------------------------------------------------------------------

mod.scan_enemies = function()
	local local_player = Managers_player:local_player(1)
	if not local_player then
		return
	end

	local player_unit = local_player.player_unit
	if not player_unit or not Unit_alive(player_unit) then
		return
	end

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
	local from_pos = Unit.world_position(player_unit, 1)
	local enemy_side_names = side:relation_side_names("enemy")
	local range = mod.frame_settings.draw_distance or 50

	-- Clear previous frame broadphase results
	table_clear(mod._broadphase_results)

	local num_hits = broadphase.query(broadphase, from_pos, range, mod._broadphase_results, enemy_side_names)

	-- Mark all cached enemies as unseen this frame
	for _, data in pairs(mod.enemy_cache) do
		data.seen = false
	end

	-- Add or update enemies in the cache
	local enemy_cache = mod.enemy_cache
	local results = mod._broadphase_results

	for i = 1, num_hits do
		local enemy_unit = results[i]

		if Unit_alive(enemy_unit) then
			local entry = enemy_cache[enemy_unit]

			if not entry then
				enemy_cache[enemy_unit] = {
					unit = enemy_unit,
					seen = true,
				}
			else
				entry.seen = true
			end
		end
	end
end

-----------------------------------------------------------------------
-- Marker / unit tracking
-----------------------------------------------------------------------

local marker_ids = {}
-- Table to map marker IDs to units
local marker_to_unit = {}

-- Unused helper retained for compatibility if referenced elsewhere
local set_marker_id = function(marker_id)
	for unit, stored_marker_id in pairs(marker_to_unit) do
		if stored_marker_id == marker_id then
			return unit
		end
	end
end

-----------------------------------------------------------------------
-- Alerted enemies
-----------------------------------------------------------------------

local ALERTED_MODES = {
	alerted = 5,
	directional_alerted = 3,
	hesitate = 4,
	instant_aggro = 1,
	moving_alerted = 2,
}

local function get_unit_id(unit)
	if unit then
		return Managers_state.unit_spawner:game_object_id(unit)
	else
		return 0
	end
end

local function add_unit_to_alerted(unit)
	local id = get_unit_id(unit)
	if id ~= 0 and not mod.enemy_markers_alerted[id] then
		mod.enemy_markers_alerted[id] = true
	end
end

local function remove_unit_from_alerted(unit)
	local id = get_unit_id(unit)
	if id ~= 0 and mod.enemy_markers_alerted[id] then
		mod.enemy_markers_alerted[id] = nil
	end
end

-----------------------------------------------------------------------
-- Horde clustering helpers
-----------------------------------------------------------------------

-- Build clusters from a compact list of units for this frame
local function _build_horde_clusters(units, num_units)
	table_clear(_horde_clusters)
	table_clear(_horde_cluster_by_unit)

	-- Collect horde candidates
	local candidates = {} -- { { unit, breed_name, pos }, ... }
	local c_count = 0

	for i = 1, num_units do
		local unit = units[i]
		if Unit_alive(unit) then
			local unit_data_extension = ScriptUnit_has_extension(unit, "unit_data_system")
			local breed = unit_data_extension and unit_data_extension:breed()
			local tags = breed and breed.tags

			if tags and (tags.horde or tags.roamer) then
				local pos = Unit.world_position(unit, 1)
				c_count = c_count + 1
				candidates[c_count] = {
					unit = unit,
					breed_name = breed.name,
					pos = pos,
				}
			end
		end
	end

	if c_count < HORDE_MIN_UNITS_FOR_CLUSTER then
		return
	end

	-- Simple clustering by (breed_name, distance)
	local used = {}

	for i = 1, c_count do
		if not used[i] then
			local seed = candidates[i]
			local breed_name = seed.breed_name
			local pos_i = seed.pos

			local units_in_cluster = { seed.unit }
			local sum_x, sum_y = pos_i.x, pos_i.y
			local base_z = pos_i.z+1.4

			local count = 1

			for j = i + 1, c_count do
				if not used[j] then
					local cand = candidates[j]
					if cand.breed_name == breed_name then
						local pos_j = cand.pos
						local dx = pos_j.x - pos_i.x
						local dy = pos_j.y - pos_i.y
						local dz = pos_j.z - pos_i.z
						local dist_sq = dx * dx + dy * dy + dz * dz

						if dist_sq ~= dist_sq or dist_sq == math.huge or dist_sq == -math.huge then
							-- NaN or inf, skip this candidate
						else
							if dist_sq <= HORDE_CLUSTER_RADIUS_SQ then
								used[j] = true
								units_in_cluster[#units_in_cluster + 1] = cand.unit
								sum_x = sum_x + pos_j.x
								sum_y = sum_y + pos_j.y
								count = count + 1
							end
						end		
					end
				end
			end

			if count >= HORDE_MIN_UNITS_FOR_CLUSTER then
				local inv = 1 / count
				local center = {
					x = sum_x * inv,
					y = sum_y * inv,
					z = base_z,
				}

				-- Sum health across cluster members (current & instantaneous max)
				local total_current = 0
				local total_max = 0

				for _, u in ipairs(units_in_cluster) do
					local he = ScriptUnit_has_extension(u, "health_system")
					if he then
						total_current = total_current + (he:current_health() or 0)
						total_max = total_max + (he:max_health() or 0)
					end
				end

				local idx = #_horde_clusters + 1
                local rep_unit = units_in_cluster[1]

                _horde_clusters[idx] = {
                    breed_name    = breed_name,
                    units         = units_in_cluster,
                    center        = center,
                    total_current = total_current,
                    total_max     = total_max,
                    rep_unit      = rep_unit,
                }

                for _, u in ipairs(units_in_cluster) do
                    _horde_cluster_by_unit[u] = idx
                end

				for _, u in ipairs(units_in_cluster) do
					_horde_cluster_by_unit[u] = idx
				end
			end
		end
	end
end

-- Public helper for the templates
mod.get_horde_cluster_for_unit = function(unit)
	local idx = _horde_cluster_by_unit[unit]
	return idx and _horde_clusters[idx] or nil
end

-----------------------------------------------------------------------
-- Enemy markers
-----------------------------------------------------------------------

-- Updated to accept compact unit list and count (1,2,4)
mod.update_enemy_markers = function(units, num_units, t)
	local fs = mod.frame_settings
	if not (fs.enable and fs.enable.markers) then
		return
	end

	local enemy_cache = mod.enemy_cache
	local marked_dead = mod.marked_dead
	local to_remove = {}

	-- First, handle the removal of markers for dead enemies
	for i = 1, num_units do
		local unit = units[i]
		local entry = enemy_cache[unit]
		if entry then
			local alive = Unit_alive(unit)
			local remove_now = false

			if not alive then
				remove_now = true
			else
				local health_extension = ScriptUnit_has_extension(unit, "health_system")
				if health_extension and health_extension:current_health_percent() <= 0 then
					remove_now = true
				end
			end

			if remove_now then
				local marker_id = marker_ids[unit]
				if marker_id then
					Managers_event:trigger("remove_world_marker", marker_id)
					mod.enemy_markers[unit] = nil
					marker_ids[unit] = nil
					marked_dead[unit] = true
				end
				to_remove[#to_remove + 1] = unit
			end
		end
	end

	-- Remove dead enemies from the cache after processing
	for i = 1, #to_remove do
		enemy_cache[to_remove[i]] = nil
	end

	-- Second, only add markers for living enemies that are not dead and removed
	for i = 1, num_units do
		local unit = units[i]
		if enemy_cache[unit] and not mod.enemy_markers[unit] and not marked_dead[unit] then
			Managers_event:trigger("add_world_marker_unit", EnemyMarkersTemplate.name, unit, function(marker_id)
				marker_ids[unit] = marker_id
				marker_to_unit[unit] = marker_id
			end)

			mod.enemy_markers[unit] = unit
		end
	end

	-- Alerted logic: build alerted set & recolor relevant markers,
	-- throttled to avoid expensive behavior checks every frame (2)
	local now = (Managers_time and Managers_time:time("gameplay")) or t or 0
	local enemy_markers_alerted = mod.enemy_markers_alerted

	if now - _alert_last_t > ALERT_UPDATE_INTERVAL then
		_alert_last_t = now

		-- First pass: build alerted set
		for i = 1, num_units do
			local unit = units[i]
			if enemy_cache[unit] then
				local behaviour_ext = ScriptUnit_has_extension(unit, "behavior_system")

				if behaviour_ext then
					local perception_component = behaviour_ext._perception_component

					local target_unit = perception_component and perception_component.target_unit
					if target_unit then
						add_unit_to_alerted(unit)
					else
						remove_unit_from_alerted(unit)
					end
				else
					remove_unit_from_alerted(unit)
				end
			end
		end
	end

	-- Second pass: recolor markers for alerted enemies
	if next(enemy_markers_alerted) then
		local ui_manager = Managers_ui
		local hud = ui_manager and ui_manager:get_hud()
		local world_markers = hud and hud:element("HudElementWorldMarkers")
		local markers_by_id = world_markers and world_markers._markers_by_id

		if markers_by_id then
			for i = 1, num_units do
				local unit = units[i]
				if enemy_cache[unit] then
					local unit_id = get_unit_id(unit)
					if enemy_markers_alerted[unit_id] then
						local marker_id = marker_ids[unit]
						if marker_id then
							local marker = markers_by_id[marker_id]
							if marker and marker.widget and marker.widget.style then
								local bg_style = marker.widget.style.background
								if bg_style and bg_style.color then
									-- Mutate existing color table to avoid allocations (4)
									local color = bg_style.color
									color[1], color[2], color[3], color[4] = 255, 255, 50, 50
								end
							end
						end
					end
				end
			end
		end
	end

	-- Special Attack sounds can be grabbed from breed -> sounds -> events -> vce_special_attack
	-- this could be used to "flash" the markers when an enemy is about to do a special attack! could be cooool
end

-----------------------------------------------------------------------
-- Enemy healthbars
-----------------------------------------------------------------------

-- Updated to accept compact unit list and count (1)
mod.update_enemy_healthbars = function(units, num_units)
	local fs = mod.frame_settings
	if not (fs.enable and fs.enable.healthbar) then
		return
	end

	if fs.enable.horde_clusters then 
		-- Build horde clusters for this frame so we know which units belong to a consolidated horde
		_build_horde_clusters(units, num_units)
	else
		table_clear(_horde_clusters)
		table_clear(_horde_cluster_by_unit)
	end

	local enemy_cache = mod.enemy_cache
	local marked_dead = mod.marked_dead
	local to_remove = {}

	-- Remove dead enemies
	for i = 1, num_units do
		local unit = units[i]
		local entry = enemy_cache[unit]
		if entry then
			local alive = Unit_alive(unit)
			local remove_now = false

			if not alive then
				remove_now = true
			else
				local health_ext = ScriptUnit_has_extension(unit, "health_system")
				if health_ext and health_ext:current_health_percent() <= 0 then
					remove_now = true
				end
			end

			if remove_now then
				local hb_id = healthbar_ids[unit]
				if hb_id then
					Managers_event:trigger("remove_world_marker", hb_id)
					healthbar_ids[unit] = nil
					mod.enemy_healthbars[unit] = nil
				end
				to_remove[#to_remove + 1] = unit
			end
		end
	end

	for i = 1, #to_remove do
		enemy_cache[to_remove[i]] = nil
	end

	-- Add healthbars for living enemies
	for i = 1, num_units do
		local unit = units[i]
		if enemy_cache[unit] and not mod.enemy_healthbars[unit] and not marked_dead[unit] then
			local cluster = fs.enable.horde_clusters and mod.get_horde_cluster_for_unit(unit) or nil

			-- If this unit is part of a horde cluster, only give a healthbar to the representative
			if cluster then
				-- Clustered mode: only the representative unit gets a bar,
				-- regardless of hb_horde_enable
				if cluster.rep_unit ~= unit then
					goto continue_healthbar_loop
				end
			else
				-- Not in a cluster (or clustering disabled): apply hb_horde_enable rules
				local unit_data_extension = ScriptUnit_has_extension(unit, "unit_data_system")
				local breed = unit_data_extension and unit_data_extension:breed()
				local tags = breed and breed.tags
				local is_horde = tags and (tags.horde or tags.roamer)

				-- If this is a horde unit and per-unit horde bars are disabled, skip
				if is_horde and not fs.enable.horde then
					goto continue_healthbar_loop
				end
			end

			Managers_event:trigger("add_world_marker_unit", "enemy_healthbar", unit, function(marker_id)
				healthbar_ids[unit] = marker_id
			end)

			mod.enemy_healthbars[unit] = unit

			::continue_healthbar_loop::
		end
	end
end

-----------------------------------------------------------------------
-- Enemy debuffs
-----------------------------------------------------------------------

local debuff_ids = {}
local utility_debuff_ids = {}

-- Updated to accept compact unit list and count (1)
mod.update_enemy_debuffs = function(units, num_units)
	local fs = mod.frame_settings
	if not (fs.enable and fs.enable.debuff) then
		return
	end

	local enemy_cache = mod.enemy_cache
	local marked_dead = mod.marked_dead
	local to_remove = {}

	-- First, handle the removal of debuffs for dead enemies
	for i = 1, num_units do
		local unit = units[i]
		local entry = enemy_cache[unit]
		if entry then
			local alive = Unit_alive(unit)
			local remove_now = false

			if not alive then
				remove_now = true
			else
				local health_extension = ScriptUnit_has_extension(unit, "health_system")
				if health_extension and health_extension:current_health_percent() <= 0 then
					remove_now = true
				end
			end

			if remove_now then
				local debuff_id = debuff_ids[unit]
				if debuff_id then
					Managers_event:trigger("remove_world_marker", debuff_id)
					mod.enemy_debuffs[unit] = nil
					debuff_ids[unit] = nil
					marked_dead[unit] = true
				end
				to_remove[#to_remove + 1] = unit
			end
		end
	end

	for i = 1, #to_remove do
		enemy_cache[to_remove[i]] = nil
	end

	-- Second, only add debuffs for living enemies that are not dead and removed
	for i = 1, num_units do
		local unit = units[i]
		if enemy_cache[unit] and not mod.enemy_debuffs[unit] and not marked_dead[unit] then
			Managers_event:trigger("add_world_marker_unit", "enemy_debuff", unit, function(debuff_id)
				debuff_ids[unit] = debuff_id
				marker_to_unit[unit] = debuff_id
			end)

			mod.enemy_debuffs[unit] = unit
		end
	end
end

mod.update_enemy_utility_debuffs = function(units, num_units)
	local fs = mod.frame_settings
	if not (fs.enable and fs.enable.debuff) then
		return
	end

	local enemy_cache = mod.enemy_cache
	local marked_dead = mod.marked_dead
	local to_remove = {}

	-- Remove on death
	for i = 1, num_units do
		local unit = units[i]
		local entry = enemy_cache[unit]
		if entry then
			local alive = Unit_alive(unit)
			local remove_now = false

			if not alive then
				remove_now = true
			else
				local health_extension = ScriptUnit_has_extension(unit, "health_system")
				if health_extension and health_extension:current_health_percent() <= 0 then
					remove_now = true
				end
			end

			if remove_now then
				local id = utility_debuff_ids[unit]
				if id then
					Managers_event:trigger("remove_world_marker", id)
					mod.enemy_utility_debuffs[unit] = nil
					utility_debuff_ids[unit] = nil
					marked_dead[unit] = true
				end
				to_remove[#to_remove + 1] = unit
			end
		end
	end

	for i = 1, #to_remove do
		enemy_cache[to_remove[i]] = nil
	end

	-- Add for living enemies
	for i = 1, num_units do
		local unit = units[i]
		if enemy_cache[unit] and not mod.enemy_utility_debuffs[unit] and not marked_dead[unit] then
			Managers_event:trigger("add_world_marker_unit", EnemyUtilityDebuffTemplate.name, unit, function(marker_id)
				utility_debuff_ids[unit] = marker_id
			end)

			mod.enemy_utility_debuffs[unit] = unit
		end
	end
end

-----------------------------------------------------------------------
-- Cache clearing
-----------------------------------------------------------------------

mod.clear_caches = function()
	table_clear(mod.enemy_markers)
	table_clear(mod.enemy_healthbars)
	table_clear(mod.enemy_debuffs)
	table_clear(mod.enemy_cache)
	table_clear(mod.marked_dead)
	if healthbar_ids then
		table_clear(healthbar_ids)
	end
	if marker_ids then
		table_clear(marker_ids)
	end
	table_clear(mod.enemy_markers_alerted)
	if debuff_ids then
		table_clear(debuff_ids)
	end
	table_clear(mod.enemy_utility_debuffs)
	if utility_debuff_ids then
		table_clear(utility_debuff_ids)
	end
	-- also compact temp unit list
	table_clear(_enemy_units_temp)

	-- clear horde cluster state
	table_clear(_horde_clusters)
	table_clear(_horde_cluster_by_unit)
end

-----------------------------------------------------------------------
-- Main update orchestration
-----------------------------------------------------------------------

mod.update_enemies = function(dt, t)
	-- Early-out: if all features disabled, skip everything
	build_frame_settings(mod, dt or 0)
	local fs = mod.frame_settings
	local enable = fs.enable

	if not (enable.markers or enable.healthbar or enable.debuff) then
		return
	end

	mod.scan_enemies()

	local enemy_cache = mod.enemy_cache

	-- If enemy cache is empty, nothing to do
	if not next(enemy_cache) then
		return
	end

	-- Build a compact list of units, capped per frame (1)
	local temp = _enemy_units_temp
	local count = 0

	for unit, _ in pairs(enemy_cache) do
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

	if enable.markers then
		mod.update_enemy_markers(temp, to_process, t)
	end

	if enable.healthbar then
		mod.update_enemy_healthbars(temp, to_process)
	end

	if enable.debuff then
		mod.update_enemy_debuffs(temp, to_process)
		mod.update_enemy_utility_debuffs(temp, to_process)
	end

	-- Periodic cleanup of marked_dead entries for units no longer in cache (5)
	_dead_cleanup_accum = _dead_cleanup_accum + (fs.dt or 0)
	if _dead_cleanup_accum > DEAD_CLEANUP_INTERVAL then
		_dead_cleanup_accum = 0
		for unit, _ in pairs(mod.marked_dead) do
			if not enemy_cache[unit] then
				mod.marked_dead[unit] = nil
			end
		end
	end
end

-----------------------------------------------------------------------
-- Settings changed
-----------------------------------------------------------------------

mod.on_setting_changed = function(setting_id)
	-- Clearing caches ensures new settings take effect cleanly.
	mod.clear_caches()

	-- Reset draw distance cache so it picks up new settings
	_last_draw_distance_key = nil
	_last_draw_distance_value = 50
end

mod.get_breed_tags = function(unit)
	local unit_data_extension = ScriptUnit_has_extension(unit, "unit_data_system")
	local breed = unit_data_extension and unit_data_extension:breed()
	if not breed then
		return
	end
	local tags = breed.tags
	return tags
end