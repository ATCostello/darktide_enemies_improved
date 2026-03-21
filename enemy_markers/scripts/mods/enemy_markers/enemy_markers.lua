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
local Component = require("scripts/utilities/component")
local MechanismManager = require("scripts/managers/mechanism/mechanism_manager")

mod.frame_settings = {}
mod.enemy_cache = {}
mod.enemy_markers = {}
mod.enemy_markers_alerted = {}
mod.enemy_healthbars = {}
mod.enemy_debuffs = {}
mod.enemy_utility_debuffs = {}
mod._broadphase_results = {}
local healthbar_ids = {}
local debuff_ids = {}
local utility_debuff_ids = {}
local marker_ids = {}

mod.marked_dead = {}
mod.source_unit_cache = mod.source_unit_cache or {}

local MAX_ENEMIES_PER_FRAME = 300
local _enemy_units_temp = {}
local _last_enemy_index = 0

local _alert_last_t = 0
local ALERT_UPDATE_INTERVAL = 0.1

local _dead_cleanup_accum = 0
local DEAD_CLEANUP_INTERVAL = 1

local HORDE_CLUSTER_RADIUS_SQ = 30 ^ 2
local HORDE_MIN_UNITS_FOR_CLUSTER = 20
local _horde_clusters = {}
local _horde_cluster_by_unit = {}
local _last_cluster_count = 0

local COLOUR_LOOKUP = {
	Gold = { 255, 232, 188, 109 },
	Silver = { 255, 187, 198, 201 },
	Steel = { 255, 161, 166, 169 },
	Black = { 255, 35, 31, 32 },
	Brass = { 255, 226, 199, 126 },
	Terminal = Color.terminal_background(200, true),
	Default = { 255, 161, 166, 169 },
}

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

-- Marker fade settings
local DIST_FADE_START = 10 -- meters where fade begins
local DIST_FADE_END = 50 -- full fade at draw distance
local MIN_ALPHA = 0.1 -- never fully invisible
local STACKING_FADE_STRENGTH = 0.1 -- extra fade per overlapping marker (optional)

local DANGEROUS_BT_ACTIONS = {
	bt_mutant_charge = true,
	bt_trapper_net = true,
	bt_sniper_shoot = true,
	bt_hound_leap = true,
	bt_poxwalker_vomit = true,
	bt_bomber_throw = true,
}

-----------------------------------------------------------------------
-- Add marker templates + preload resources
-----------------------------------------------------------------------
mod.on_game_state_changed = function(state, state_name)
	mod.on_game_state_changed = function(state, state_name)
		-- ========================
		-- EXISTING (keep)
		-- ========================
		Managers.package:load("packages/ui/views/inventory_view/inventory_view", "enemy_markers", nil, true)
		Managers.package:load(
			"packages/ui/views/inventory_weapons_view/inventory_weapons_view",
			"enemy_markers",
			nil,
			true
		)
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
		Managers.package:load(
			"packages/ui/views/cosmetics_inspect_view/cosmetics_inspect_view",
			"enemy_markers",
			nil,
			true
		)
		Managers.package:load(
			"packages/ui/views/masteries_overview_view/masteries_overview_view",
			"enemy_markers",
			nil,
			true
		)
		Managers.package:load("packages/ui/views/mastery_view/mastery_view", "enemy_markers", nil, true)
		Managers.package:load("packages/ui/views/dlc_purchase_view/dlc_purchase_view", "enemy_markers", nil, true)

		Managers.package:load("packages/ui/views/talent_builder_view/ogryn", "enemy_markers", nil, true)
		Managers.package:load("packages/ui/views/talent_builder_view/talent_builder_view", "enemy_markers", nil, true)
	end
end

mod:hook_safe(CLASS.HudElementWorldMarkers, "init", function(self)
	-- add new marker templates to templates table
	self._marker_templates[EnemyMarkersTemplate.name] = EnemyMarkersTemplate
	self._marker_templates[EnemyHealthbarTemplate.name] = EnemyHealthbarTemplate
	self._marker_templates[EnemyDebuffTemplate.name] = EnemyDebuffTemplate
	self._marker_templates[EnemyUtilityDebuffTemplate.name] = EnemyUtilityDebuffTemplate

	-- clear caches on markers init
	mod.clear_caches()
end)

-----------------------------------------------------------------------
-- Hook into the markers update to recalculate enemies.
-----------------------------------------------------------------------
mod:hook_safe(CLASS.HudElementWorldMarkers, "update", function(self, dt, t)
	-- Update enemies/markers for this frame
	mod.update_enemies(dt, t)

	local markers = self._markers
	if not markers or #markers == 0 then
		return
	end

	mod.markers = self._markers_by_type

	-- Hide default health bars (all damage_indicator variants except our custom one)
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
end)

-----------------------------------------------------------------------
-- Frame settings builder
-----------------------------------------------------------------------

local _last_draw_distance_key
local _last_draw_distance_value = 50

local function build_frame_settings(mod, dt)
	local fs = mod.frame_settings

	fs.dt = dt or 0

	-- ADS detection
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

	-- LOS stuff
	local los_enabled = mod:get("los_fade_enable") == true
	local los_opacity = (mod:get("los_opacity") or 100) / 100
	local ads_los_opacity = (mod:get("ads_los_opacity") or 100) / 100

	fs.los_enabled = los_enabled
	fs.los_opacity = los_opacity
	fs.ads_los_opacity = ads_los_opacity
	fs.ads_blend = math_lerp(fs.ads_blend or 0, is_ads and 1 or 0, 0.25)

	-- Draw distance stuff
	local draw_distance_key = mod:get("draw_distance")
	if draw_distance_key ~= _last_draw_distance_key then
		_last_draw_distance_key = draw_distance_key
		_last_draw_distance_value = mod:get(draw_distance_key) or 50
	end
	fs.draw_distance = _last_draw_distance_value

	-- Feature toggles
	fs.enable = fs.enable or {}
	local enable = fs.enable
	enable.markers = mod:get("markers_enable")
	enable.markers_horde = mod:get("marker_horde_enable") or false

	enable.healthbar = mod:get("healthbar_enable")
	enable.debuff = mod:get("debuff_enable")
	enable.hb_horde = mod:get("hb_horde_enable") or false
	enable.horde_clusters = mod:get("hb_horde_clusters_enable") or false
end

-----------------------------------------------------------------------
-- Enemy scanning
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

	local results = mod._broadphase_results
	table_clear(results)

	local num_hits = broadphase.query(broadphase, from_pos, range, results, enemy_side_names)

	local cache = mod.enemy_cache

	-- mark unseen
	for _, data in pairs(cache) do
		data.seen = false
	end

	for i = 1, num_hits do
		local unit = results[i]

		if Unit_alive(unit) then
			local entry = cache[unit]

			if not entry then
				cache[unit] = {
					unit = unit,
					seen = true,

					dead = false,
					-- cache extensions ONCE
					health_ext = ScriptUnit_has_extension(unit, "health_system"),
					unit_data_ext = ScriptUnit_has_extension(unit, "unit_data_system"),
					behavior_ext = ScriptUnit_has_extension(unit, "behavior_system"),

					-- specialist tracking
					is_specialist = mod.is_specialist_unit(unit),
					special_attack_event = nil,
					special_attack_imminent = false,
					special_attack_timer = 0,
				}
			else
				entry.seen = true
			end
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
	if id and id ~= 0 and not mod.enemy_markers_alerted[id] then
		mod.enemy_markers_alerted[id] = true
	end
end

local function remove_unit_from_alerted(unit)
	local id = get_unit_id(unit)
	if id and id ~= 0 and mod.enemy_markers_alerted[id] then
		mod.enemy_markers_alerted[id] = nil
	end
end

-----------------------------------------------------------------------
-- Horde clustering helpers
-----------------------------------------------------------------------

-- Build clusters from a compact list of units
local function _build_horde_clusters(units, num_units)
	table_clear(_horde_clusters)
	table_clear(_horde_cluster_by_unit)

	local candidates = {}
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
			local base_z = pos_i.z + 1.8

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

				-- Sum health across cluster members
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
					breed_name = breed_name,
					units = units_in_cluster,
					center = center,
					total_current = total_current,
					total_max = total_max,
					rep_unit = rep_unit,
				}

				for _, u in ipairs(units_in_cluster) do
					_horde_cluster_by_unit[u] = idx
				end
			end
		end
	end
end

mod.get_horde_cluster_for_unit = function(unit)
	local idx = _horde_cluster_by_unit[unit]
	return idx and _horde_clusters[idx] or nil
end

-----------------------------------------------------------------------
-- Enemy markers
-----------------------------------------------------------------------
mod:hook(WwiseWorld, "make_manual_source", function(func, wwise_world, unit)
	local source = func(wwise_world, unit)

	if unit and Unit_alive(unit) then
		mod.source_unit_cache[source] = unit
	end

	return source
end)

mod.get_userdata_type = function(userdata)
	if type(userdata) ~= "userdata" then
		return nil
	end

	if Unit_alive(userdata) then
		return "Unit"
	end

	return "userdata"
end

mod.find_local_unit = function()
	local level = 1

	while debug.getinfo(level) ~= nil do
		local i = 1

		while true do
			local name, value = debug.getlocal(level, i)

			if not name then
				break
			end

			if mod.get_userdata_type(value) == "Unit" then
				return value
			end

			i = i + 1
		end

		level = level + 1
	end
end

mod.find_attacking_unit = function()
	local level = 3

	while debug.getinfo(level) ~= nil do
		local i = 1

		while true do
			local name, value = debug.getlocal(level, i)

			if not name then
				break
			end

			if type(value) == "userdata" and Unit_alive(value) then
				return value
			end

			if type(value) == "table" then
				local unit = rawget(value, "_unit")

				if unit and Unit_alive(unit) then
					return unit
				end
			end

			i = i + 1
		end

		level = level + 1
	end

	return nil
end

mod.find_bt_action_unit = function()
	for level = 4, 12 do
		local name, value = debug.getlocal(level, 1)

		if type(value) == "table" then
			local unit = rawget(value, "_unit")

			if unit and Unit_alive(unit) then
				return unit
			end
		end
	end

	return nil
end

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

-- better than audio cues - but only works on local games due to event_names not being known locally :(
mod.special_attack_animations = {

	----------------------------------------------------------------
	-- CHAOS HOUND
	----------------------------------------------------------------
	chaos_hound = {
		attack_leap = {
			attack = "leap_attack",
			damage_time = 1.05,
			duration = 2.8,
		},
		attack_pounce = {
			attack = "pounce_attack",
			damage_time = 1.25,
			duration = 3.1,
		},
		attack_leap_start = {
			attack = "attack_leap_start",
			damage_time = 1.05,
			duration = 2.8,
		},
		attack_leap_short = {
			attack = "attack_leap_short",
			damage_time = 1.05,
			duration = 2.8,
		},
	},

	----------------------------------------------------------------
	-- CHAOS MUTANT
	----------------------------------------------------------------
	chaos_mutant = {
		attack_charge = {
			attack = "charge_attack",
			damage_time = 1.35,
			duration = 3.4,
		},

		attack_grab = {
			attack = "grab_attack",
			damage_time = 1.45,
			duration = 3.2,
		},

		attack_throw = {
			attack = "throw_attack",
			damage_time = 1.9,
			duration = 3.6,
		},
	},

	----------------------------------------------------------------
	-- CHAOS TRAPPER
	----------------------------------------------------------------
	chaos_trapper = {
		attack_netgun = {
			attack = "netgun_attack",
			damage_time = 0.95,
			duration = 2.3,
		},
	},

	----------------------------------------------------------------
	-- RENEGADE SNIPER
	----------------------------------------------------------------
	renegade_sniper = {
		attack_shoot = {
			attack = "shoot",
			damage_time = 0.82,
			duration = 1.9,
		},
	},

	----------------------------------------------------------------
	-- CHAOS GRENADIER
	----------------------------------------------------------------
	chaos_grenadier = {
		attack_throw_grenade = {
			attack = "grenade_throw",
			damage_time = 0.9,
			duration = 2.2,
		},
	},

	----------------------------------------------------------------
	-- POXBURSTER
	----------------------------------------------------------------
	chaos_poxwalker_bomber = {
		attack_explode = {
			attack = "suicide_attack",
			damage_time = 1.5,
			duration = 2.8,
		},
	},

	----------------------------------------------------------------
	-- MAULER
	----------------------------------------------------------------
	chaos_mauler = {
		attack_01 = {
			attack = "melee_combo",
			damage_time = 0.92,
			duration = 2.4,
		},

		attack_02 = {
			attack = "melee_combo",
			damage_time = 1.1,
			duration = 2.6,
		},
	},

	----------------------------------------------------------------
	-- RAGER
	----------------------------------------------------------------
	chaos_rager = {
		attack_01 = {
			attack = "frenzy_combo",
			damage_time = 0.4,
			duration = 1.2,
		},

		attack_02 = {
			attack = "frenzy_combo",
			damage_time = 0.55,
			duration = 1.3,
		},

		attack_03 = {
			attack = "frenzy_combo",
			damage_time = 0.7,
			duration = 1.5,
		},
	},

	----------------------------------------------------------------
	-- CHAOS OGRYN EXECUTOR (CRUSHER)
	----------------------------------------------------------------
	chaos_ogryn_executor = {

		attack_01 = {
			attack = "melee_attack_cleave",
			damage_time = 1.471,
			duration = 3.103,
		},

		attack_02 = {
			attack = "melee_attack_cleave",
			damage_time = 1.310,
			duration = 2.873,
		},

		attack_07 = {
			attack = "melee_attack_cleave",
			damage_time = 1.655,
			duration = 3.678,
		},

		attack_08 = {
			attack = "melee_attack_cleave",
			damage_time = 1.586,
			duration = 3.310,
		},

		attack_move_01 = {
			attack = "moving_melee_attack_cleave",
			damage_time = 1.531,
			duration = 2.840,
		},
	},

	----------------------------------------------------------------
	-- CHAOS OGRYN BULWARK
	----------------------------------------------------------------
	chaos_ogryn_bulwark = {

		attack_push = {
			attack = "melee_attack_push",
			damage_time = 0.93,
			duration = 2,
		},

		attack_01 = {
			attack = "melee_attack_sweep",
			damage_time = 1.2,
			duration = 3,
		},
	},

	----------------------------------------------------------------
	-- CHAOS SPAWN
	----------------------------------------------------------------
	chaos_spawn = {

		attack_01 = {
			attack = "melee_combo",
			damage_time = 0.84,
			duration = 2.4,
		},

		attack_02 = {
			attack = "melee_combo",
			damage_time = 1.02,
			duration = 2.7,
		},

		attack_grab = {
			attack = "grab_attack",
			damage_time = 1.4,
			duration = 3.5,
		},
	},

	----------------------------------------------------------------
	-- PLAGUE OGRYN
	----------------------------------------------------------------
	chaos_plague_ogryn = {

		attack_01 = {
			attack = "combo_attack",
			damage_time = 0.96,
			duration = 2.73,
		},

		attack_02 = {
			attack = "combo_attack",
			damage_time = 1.1,
			duration = 2.88,
		},

		attack_03 = {
			attack = "combo_attack",
			damage_time = 1.24,
			duration = 3.01,
		},

		attack_slam = {
			attack = "slam_attack",
			damage_time = 1.5,
			duration = 3.5,
		},

		attack_charge = {
			attack = "charge_attack",
			damage_time = 2.0,
			duration = 4.2,
		},
	},

	----------------------------------------------------------------
	-- BEAST OF NURGLE
	----------------------------------------------------------------
	chaos_beast_of_nurgle = {

		attack_tongue = {
			attack = "tongue_grab",
			damage_time = 1.8,
			duration = 3.6,
		},

		attack_eat = {
			attack = "eat_attack",
			damage_time = 2.2,
			duration = 4,
		},
	},
}

-- local games only. rpc_minion_anim_event is the networked version, but only provides event_id, which I cant find out how to get event_name from
mod:hook(Unit, "animation_event", function(func, unit, event, ...)
	local result = func(unit, event, ...)

	if not unit or not Unit_alive(unit) then
		return result
	end

	local entry = mod.enemy_cache[unit]
	if not entry then
		return result
	end

	-------------------------------------------------
	-- Get breed
	-------------------------------------------------
	local breed_name

	if entry.unit_data_ext then
		local breed = entry.unit_data_ext:breed()
		breed_name = breed and breed.name
	end

	if not breed_name then
		return result
	end

	-------------------------------------------------
	-- Lookup attack event
	-------------------------------------------------
	local breed_table = mod.special_attack_animations[breed_name]

	if not breed_table then
		return result
	end

	local attack_data = breed_table[event]

	if attack_data then
		if event then
			entry.special_attack_event = event
			entry.special_attack_imminent = true

			local now = mod.get_time()

			if attack_data.damage_time then
				entry.special_attack_timer = now + attack_data.damage_time
			else
				entry.special_attack_timer = now + 1
			end

			--[[mod:echo(
				string.format(
					"%s [ANIMATION ATTACK DETECTED] %s -> %s (damage in %.2fs)",
					mod.ts(),
					breed_name,
					event,
					attack_data.damage_time
				)
			)]]
		end
	end

	return result
end)

mod.special_attack_events = {
	-- Trapper / Netgunner
	["wwise/events/minions/play_weapon_netgunner_wind_up"] = true,

	-- Sniper
	["wwise/events/weapon/play_special_sniper_flash"] = true,
	["wwise/events/weapon/play_combat_weapon_las_sniper"] = true,
	["wwise/events/minions/play_netgunner"] = true,

	-- Mutant Charger
	["wwise/events/minions/play_enemy_mutant_charger"] = true,
	["wwise/events/minions/play_minion_special_mutant_charger_spawn"] = true, -- spawn/charge cues

	-- Chaos Hound / leap
	["wwise/events/minions/play_enemy_chaos_hound_vce_leap"] = true,
	["wwise/events/minions/play_enemy_chaos_hound"] = true,

	-- Poxwalker Bomber
	["wwise/events/minions/play_minion_poxwalker_bomber"] = true,
	["wwise/events/minions/play_enemy_combat_poxwalker_bomber"] = true,

	-- Plague Ogryn Charge
	["wwise/events/minions/play_enemy_plague_ogryn_vce_charge"] = true,

	-- Chaos Ogryn special attack vocal (heavy specials)
	["wwise/events/minions/play_enemy_chaos_ogryn_armoured_executor_a__special_attack_vce"] = true,

	-- General rares / specials
	["wwise/events/minions/play_traitor_guard_grenadier"] = true,
	["wwise/events/minions/play_enemy_daemonhost"] = true,
	["wwise/events/minions/play_enemy_traitor_berzerker"] = true,
}

mod:hook_safe(WwiseWorld, "trigger_resource_event", function(wwise_world, event_name, source)
	if mod.special_attack_events[event_name] then
		local unit = mod.source_unit_cache[source]

		if not unit then
			unit = mod.find_attacking_unit()
			if unit then
				mod.source_unit_cache[source] = unit
			end
		end

		if unit and Unit_alive(unit) then
			-- Only trigger if event not already triggered via animation data (Quicker)
			if entry and entry.special_attack_imminent ~= true then
				entry.special_attack_event = event_name
				entry.special_attack_imminent = true

				local now = mod.get_time()

				entry.special_attack_timer = now + 1.5

				--mod:echo(string.format("%s [SOUND ATTACK DETECTED] %s -> %s", mod.ts(), source, event_name))
			end
		end
	end
end)

function string.starts(String, Start)
	return string.sub(String, 1, string.len(Start)) == Start
end

mod.remove_dead = function()
	local units_to_remove = {}

	dbg_mod = mod

	-- Go through each marker type and clear caches.
	local function iterate_types_removal(unit)
		--   MARKERS
		local marker_id = marker_ids[unit]
		if marker_id then
			Managers.event:trigger("remove_world_marker", marker_id)
			mod.enemy_markers[unit] = nil
			marker_ids[unit] = nil
			mod.marked_dead[unit] = true
			table.insert(units_to_remove, unit)
		end

		--   HEALTHBARS
		local hb_id = healthbar_ids[unit]
		if hb_id then
			Managers_event:trigger("remove_world_marker", hb_id)
			healthbar_ids[unit] = nil
			mod.enemy_healthbars[unit] = nil
			table.insert(units_to_remove, unit)
		end

		--   DEBUFFS
		local debuff_id = debuff_ids[unit]
		if debuff_id then
			Managers_event:trigger("remove_world_marker", debuff_id)
			mod.enemy_debuffs[unit] = nil
			debuff_ids[unit] = nil
			mod.marked_dead[unit] = true
			table.insert(units_to_remove, unit)
		end

		-- UTILITY DEBUFFS
		local util_debuff_id = utility_debuff_ids[unit]
		if util_debuff_id then
			Managers_event:trigger("remove_world_marker", util_debuff_id)
			mod.enemy_utility_debuffs[unit] = nil
			utility_debuff_ids[unit] = nil
			mod.marked_dead[unit] = true
			table.insert(units_to_remove, unit)
		end
	end

	-- Detect if dead
	for unit, data in pairs(mod.enemy_cache) do
		if not Unit.alive(unit) or string.starts(tostring(unit), "[Unit (deleted)") then
			iterate_types_removal(unit)
		else
			local health_extension = ScriptUnit.has_extension(unit, "health_system")
			if health_extension then
				local health_percent = health_extension:current_health_percent()
				if health_percent <= 0 then
					iterate_types_removal(unit)
				end
			end
		end
	end

	-- Remove dead enemies from the cache after processing
	for _, unit in ipairs(units_to_remove) do
		mod.enemy_cache[unit] = nil
	end
end

mod.is_horde = function(unit)
	if Unit.alive(unit) then
		local entry = mod.enemy_cache[unit]
		local unit_data_extension = entry.unit_data_ext
		local breed = unit_data_extension and unit_data_extension:breed()
		local tags = breed and breed.tags
		dbg_tags = tags
		local is_horde = tags and (tags.horde or tags.roamer) or false

		return is_horde or false
	else
		return false
	end
end

mod.update_enemy_markers = function(units, num_units, t)
	local fs = mod.frame_settings
	if not (fs.enable and fs.enable.markers) then
		return
	end

	for unit, data in pairs(mod.enemy_cache) do
		local continue = true
		if mod.is_horde(unit) and not fs.enable.markers_horde then
			continue = false
		end

		if continue then
			if not mod.enemy_markers[unit] and not mod.marked_dead[unit] then
				Managers.event:trigger("add_world_marker_unit", EnemyMarkersTemplate.name, unit, function(marker_id)
					marker_ids[unit] = marker_id
				end)

				mod.enemy_markers[unit] = unit
			end
		end
	end

	---------------------------------------------------------------------------------------------------------

	local enemy_cache = mod.enemy_cache
	local now = (Managers_time and Managers_time:time("gameplay")) or t or 0
	local enemy_markers_alerted = mod.enemy_markers_alerted

	local ui_manager = Managers_ui
	local hud = ui_manager and ui_manager:get_hud()
	local world_markers = hud and hud:element("HudElementWorldMarkers")
	local markers_by_id = world_markers and world_markers._markers_by_id

	if now - _alert_last_t > ALERT_UPDATE_INTERVAL then
		_alert_last_t = now

		for i = 1, num_units do
			local unit = units[i]
			if enemy_cache[unit] then
				-------------------------------------------------------------------
				-- Special attack detection
				-------------------------------------------------------------------
				local entry = enemy_cache[unit]

				if entry.is_specialist and entry.special_attack_imminent then
					local now = mod.get_time()

					if entry.special_attack_timer and now >= entry.special_attack_timer then
						entry.special_attack_imminent = false
						entry.special_attack_timer = nil
					end
				end

				local marker_id = marker_ids[unit]
				if marker_id then
					local marker = markers_by_id[marker_id]
					if entry and marker then
						marker.special_attack_imminent = entry.special_attack_imminent
						if entry.is_specialist then
							marker.is_specialist = entry.is_specialist
						end
					end
				end

				-- behaviour stuff
				local entry = enemy_cache[unit]
				local behaviour_ext = entry.behavior_ext

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

	if next(enemy_markers_alerted) then
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
									-- color[1], color[2], color[3], color[4] = 255, 255, 50, 50
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

mod.update_enemy_healthbars = function(units, num_units)
	local fs = mod.frame_settings
	if not (fs.enable and fs.enable.healthbar) then
		return
	end

	if fs.enable.horde_clusters then
		local CLUSTER_UPDATE_INTERVAL = 0.2
		_cluster_t = (_cluster_t or 0) + fs.dt

		if _cluster_t > CLUSTER_UPDATE_INTERVAL then
			_cluster_t = 0
			_build_horde_clusters(units, num_units)
		end
	else
		table_clear(_horde_clusters)
		table_clear(_horde_cluster_by_unit)
	end

	local enemy_cache = mod.enemy_cache
	local marked_dead = mod.marked_dead

	-- Add healthbars for living enemies
	for i = 1, num_units do
		local unit = units[i]

		local continue = true
		if
			(mod.is_horde(unit) and not fs.enable.hb_horde) and (mod.is_horde(unit) and not fs.enable.horde_clusters)
		then
			continue = false
		end

		if continue and enemy_cache[unit] and not mod.enemy_healthbars[unit] and not marked_dead[unit] then
			local cluster = fs.enable.horde_clusters and mod.get_horde_cluster_for_unit(unit) or nil

			-- If this unit is part of a horde cluster, only give a healthbar to the representative
			if cluster then
				-- Clustered mode: only the representative unit gets a bar,
				-- regardless of hb_horde_enable
				if cluster.rep_unit ~= unit then
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

mod.update_enemy_debuffs = function(units, num_units)
	local fs = mod.frame_settings
	if not (fs.enable and fs.enable.debuff) then
		return
	end

	local enemy_cache = mod.enemy_cache
	local marked_dead = mod.marked_dead

	-- Second, only add debuffs for living enemies that are not dead and removed
	for i = 1, num_units do
		local unit = units[i]
		if enemy_cache[unit] and not mod.enemy_debuffs[unit] and not marked_dead[unit] then
			Managers_event:trigger("add_world_marker_unit", "enemy_debuff", unit, function(debuff_id)
				debuff_ids[unit] = debuff_id
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
-- Marker Distance
-----------------------------------------------------------------------

mod.apply_marker_fade = function()
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
	if not player_unit or not Unit_alive(player_unit) then
		return
	end

	local player_pos = Unit.world_position(player_unit, 1)

	-- Optional stacking tracking
	local screen_positions = {}

	for marker_id, marker in pairs(markers_by_id) do
		if marker and marker.unit and Unit_alive(marker.unit) then
			if
				marker.template
				and (
					marker.template.name == EnemyMarkersTemplate.name
					or marker.template.name == EnemyHealthbarTemplate.name
					or marker.template.name == EnemyDebuffTemplate.name
					or marker.template.name == EnemyUtilityDebuffTemplate.name
				)
			then
				--------------------------------------------------
				-- DISTANCE FADE
				--------------------------------------------------
				local unit_pos = Unit.world_position(marker.unit, 1)

				local dx = unit_pos.x - player_pos.x
				local dy = unit_pos.y - player_pos.y
				local dz = unit_pos.z - player_pos.z

				local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

				local fade = 1

				if dist > DIST_FADE_START then
					local t = math.clamp((dist - DIST_FADE_START) / (DIST_FADE_END - DIST_FADE_START), 0, 1)
					fade = 1 - t
				end

				fade = math.max(fade, MIN_ALPHA)

				marker.alpha_multiplier = math.clamp(fade, MIN_ALPHA, 1)

				local final_alpha = math.clamp(fade, MIN_ALPHA, 1)

				local widget = marker.widget
				if widget and widget.style then
					for _, style in pairs(widget.style) do
						if style.color then
							local base_alpha = 255
							style.color[1] = base_alpha * final_alpha
						end
					end
				end
			end
		end
	end
end

-----------------------------------------------------------------------
-- Main update orchestration
-----------------------------------------------------------------------

mod.update_enemies = function(dt, t)
	build_frame_settings(mod, dt or 0)
	local fs = mod.frame_settings
	local enable = fs.enable

	if not (enable.markers or enable.healthbar or enable.debuff) then
		return
	end

	mod.scan_enemies()

	if not next(mod.enemy_cache) then
		return
	end

	local temp = _enemy_units_temp
	local count = 0

	for unit, _ in pairs(mod.enemy_cache) do
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

	mod.remove_dead()

	-- Apply distance / stacking fade to all active markers
	mod.apply_marker_fade()

	-- Periodic cleanup of marked_dead entries for units no longer in cache
	_dead_cleanup_accum = _dead_cleanup_accum + (fs.dt or 0)
	if _dead_cleanup_accum > DEAD_CLEANUP_INTERVAL then
		_dead_cleanup_accum = 0
		for unit, _ in pairs(mod.marked_dead) do
			if not mod.enemy_cache[unit] then
				mod.marked_dead[unit] = nil
			end
		end
	end
end

-----------------------------------------------------------------------
-- Specialist detection
-----------------------------------------------------------------------

local SPECIALIST_TAGS = {
	special = true,
	disabler = true,
	monster = true,
	elite = true,
}

mod.is_specialist_unit = function(unit)
	local tags = mod.get_breed_tags(unit)

	if not tags then
		return false
	end

	for tag, enabled in pairs(SPECIALIST_TAGS) do
		if enabled and tags[tag] then
			return true
		end
	end

	return false
end
-----------------------------------------------------------------------
-- Settings changed
-----------------------------------------------------------------------

mod.on_setting_changed = function(setting_id)
	mod.clear_caches()

	_last_draw_distance_key = nil
	_last_draw_distance_value = 50
end

mod.get_breed_tags = function(unit)
	if not HEALTH_ALIVE[unit] then
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
