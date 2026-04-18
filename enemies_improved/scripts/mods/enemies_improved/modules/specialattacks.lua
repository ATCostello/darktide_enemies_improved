local mod = get_mod("enemies_improved")
mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/enemies_improved_localization")

local Unit_alive = Unit.alive
local Application_flow_callback_context_unit = Application.flow_callback_context_unit
local type = type

---------------------------------------------------------------------------------------------
-- AUDIO BASED
---------------------------------------------------------------------------------------------
mod.special_attack_events = {

	-- Trapper / Netgunner
	["wwise/events/minions/play_weapon_netgunner_wind_up"] = true,
	--["wwise/events/minions/play_netgunner_run_foley_special"] = true,

	-- Daemonhost
	["wwise/events/minions/play_enemy_daemonhost_alert_scream"] = true,
	["wwise/events/minions/play_enemy_daemonhost_alert_scream_short"] = true,
	["wwise/events/minions/play_enemy_daemonhost_struggle_vce"] = true,

	-- Sniper
	["wwise/events/weapon/play_special_sniper_flash"] = true,
	["wwise/events/weapon/play_combat_weapon_las_sniper"] = true,
	["wwise/events/weapon/play_weapon_longlas_minion"] = true,

	-- Mutant Charger
	["wwise/events/minions/play_minion_special_mutant_charger_spawn"] = true,

	-- Chaos Hound / leap
	["wwise/events/minions/play_enemy_chaos_hound_vce_leap"] = true,
	["wwise/events/minions/play_enemy_chaos_hound"] = true,
	["wwise/events/minions/play_chaos_hound_armoured_vce_leap"] = true,

	-- Poxwalker Bomber
	["wwise/events/minions/play_minion_special_poxwalker_bomber_spawn"] = true,
	["wwise/events/minions/play_explosion_bomber"] = true,
	["wwise/events/minions/play_minion_poxwalker_bomber"] = true,
	["wwise/events/minions/play_enemy_combat_poxwalker_bomber"] = true,
	["wwise/events/minions/play_minion_poxwalker_bomber_footstep_boots_heavy"] = true,

	-- Plague Ogryn Charge
	["wwise/events/minions/play_enemy_plague_ogryn_vce_charge"] = true,

	-- Chaos Ogryn special attack vocal (heavy specials)
	["wwise/events/minions/play_enemy_chaos_ogryn_armoured_executor_a__special_attack_vce"] = true,

	-- renegade executor
	["wwise/events/minions/play_enemy_traitor_executor__special_attack_vce"] = true,

	-- Chaos Spawn
	--["wwise/events/minions/play_chaos_spawn_vce_3_attack_combo"] = true,
	--["wwise/events/minions/play_chaos_spawn_vce_4_attack_combo"] = true,
	["wwise/events/minions/play_chaos_spawn_vce_eat"] = true,
	["wwise/events/minions/play_chaos_spawn_vce_attack_long"] = true,
	["wwise/events/minions/play_chaos_spawn_vce_leap"] = true,
	["wwise/events/minions/play_chaos_spawn_bite_rip"] = true,

	--["wwise/events/minions/play_chaos_spawn_vce_leap_short"] = true,

	-- General rares / specials
	["wwise/events/minions/play_traitor_guard_grenadier"] = true,
	["wwise/events/minions/play_enemy_traitor_berzerker"] = true,
}

local _last_debug_lookup_t = 0
local DEBUG_LOOKUP_COOLDOWN = 0.25

local function extract_locals_throttled(level_base)
	local now = mod.get_time()
	if now - _last_debug_lookup_t < DEBUG_LOOKUP_COOLDOWN then
		return nil
	end

	_last_debug_lookup_t = now

	local level = level_base

	while debug.getinfo(level) do
		local i = 1

		while true do
			local name, value = debug.getlocal(level, i)
			if not name then
				break
			end

			if name == "unit" and type(value) == "userdata" then
				return value
			end

			i = i + 1
		end

		level = level + 1
	end
end

mod.handle_special_attacks = function(event_name, source_unit)
	if not mod.special_attack_events[event_name] then
		return
	end
	local unit = nil

	-- Try to get uni from sourceunit
	if type(source_unit) == "userdata" and Unit_alive(source_unit) then
		unit = source_unit
	else
		local flow_unit = Application_flow_callback_context_unit()
		if flow_unit and type(flow_unit) == "userdata" and Unit_alive(flow_unit) then
			unit = flow_unit
		end
	end

	-- If not, try to get from local debugs
	if
		not unit
		and (
			event_name == "wwise/events/minions/play_weapon_netgunner_wind_up"
			or event_name == "wwise/events/weapon/play_special_sniper_flash"
		)
	then
		local name, value = debug.getlocal(8, 1)
		unit = value._unit
	end

	-- if not, try to get from all locals
	if not unit then
		unit = extract_locals_throttled(1)
	end

	--extract_locals(1)

	if unit and mod.detect_alive(unit) then
		entry = mod.enemy_cache[unit]

		if entry then
			entry.special_attack_event = event_name
			entry.special_attack_imminent = true

			local now = mod.get_time()

			entry.special_attack_timer = now + 1.5
		end
	end
end

mod:hook_safe(WwiseWorld, "trigger_resource_event", function(wwise_world, event_name, source)
	mod.handle_special_attacks(event_name, source)
end)

mod:hook_safe(
	WwiseWorld,
	"trigger_resource_external_event",
	function(_wwise_world, event_name, source, path, format, source_id)
		mod.handle_special_attacks(event_name, source)
	end
)

---------------------------------------------------------------------------------------------
-- ANIMATION BASED
---------------------------------------------------------------------------------------------

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

local process_animation_event = function(unit, event)
	if not unit or not mod.detect_alive(unit) then
		return
	end

	if not event then
		return
	end

	local entry = mod.enemy_cache[unit]
	if not entry then
		return
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
		return
	end

	-------------------------------------------------
	-- Lookup attack event
	-------------------------------------------------
	local breed_table = mod.special_attack_animations[breed_name]

	if not breed_table then
		return
	end

	local attack_data = breed_table[event]

	if attack_data then
		if event then
			entry.special_attack_event = event
			entry.special_attack_imminent = true

			local now = mod.get_time()

			entry.special_attack_timer = now + 1.5
		end
	end
end

-- local games only. Needs event ID caching to work, but thats a lot of extra work ;p rpc_minion_anim_event is the networked version, but only provides event_id, which I cant find out how to get event_name from
--[[mod:hook_safe(Unit, "animation_event", function(unit, event)
	process_animation_event(unit, event)
end)

mod:hook_safe(Unit, "animation_event_by_index", function(unit, event_index)
	local event_index = event_index or 0

	local breed_name

	if entry.unit_data_ext then
		local breed = entry.unit_data_ext:breed()
		breed_name = breed and breed.name
	end

	if not breed_name then
		return
	end

	local event_name = event_index_cache_manager.get_event_name_from_index(breed_name, event_index)

	process_animation_event(unit, event_name)
end)]]
local cached_hud = nil
local cached_world_markers = nil
-------------------------------------------------------------------
-- Special attack detection
-------------------------------------------------------------------
mod.update_special_attack_detection = function(entry)
	local unit = entry.unit

	if not cached_hud then
		local ui_manager = Managers_ui
		cached_hud = ui_manager and ui_manager:get_hud()
	end

	if not cached_world_markers and cached_hud then
		cached_world_markers = cached_hud:element("HudElementWorldMarkers")
	end

	local world_markers = cached_world_markers

	local markers_by_id = world_markers and world_markers._markers_by_id

	-- remove special_attack_imminent if over the timer...
	if entry.special_attack_imminent then
		local now = mod.get_time()

		if entry.special_attack_timer and now >= entry.special_attack_timer then
			entry.special_attack_imminent = false
			entry.special_attack_timer = nil
		end

		-- update marker status...
		local marker_id = mod.enemy_markers[unit]
		local marker = marker_id and mod.get_marker_by_id(marker_id)

		if marker then
			marker.special_attack_imminent = entry.special_attack_imminent
		end

		local hb_id = mod.enemy_healthbars[unit]
		local hb_marker = hb_id and mod.get_marker_by_id(hb_id)

		if hb_marker then
			hb_marker.special_attack_imminent = entry.special_attack_imminent
		end
	end
end
