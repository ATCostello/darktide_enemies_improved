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

local function extract_locals(level_base)
	local level = level_base
	local res = {}
	local return_value = nil

	while debug.getinfo(level) ~= nil do
		local v = 1

		while true do
			local name, value = debug.getlocal(level, v)

			if not name then
				break
			end

			res[name] = value

			-- check for specifics...
			-- Check for exact unit (Works for grabbing sniper unit from the weapon sound)
			if type(value) == "userdata" and name == "unit" and Unit_alive(value) then
				return value -- early return
			end
			v = v + 1
		end

		level = level + 1
	end

	return return_value
end

mod.handle_special_attacks = function(event_name, source_unit)
	if mod.special_attack_events[event_name] then
		local unit = nil

		-- Try to get unit from sourceunit
		if type(source_unit) == "userdata" and Unit_alive(source_unit) then
			unit = source_unit
		else
			local flow_unit = Application.flow_callback_context_unit()
			if flow_unit and type(flow_unit) == "userdata" and Unit_alive(flow_unit) then
				unit = flow_unit
			end
		end

		-- If not, try to get from local debugs
		if
			(
				event_name == "wwise/events/minions/play_weapon_netgunner_wind_up"
				or event_name == "wwise/events/weapon/play_special_sniper_flash"
			) and not unit
		then
			for i = 6, 12 do
				local _, value = debug.getlocal(i, 1)
				if type(value) == "table" then
					local u = rawget(value, "_unit")
					if u and Unit.alive(u) then
						unit = u
						break
					end
				end
			end
		end

		-- if not, try to get from all locals
		if not unit then
			unit = extract_locals(1)
		end

		if unit and mod.detect_alive(unit) then
			local entry = mod.enemy_cache[unit]

			if entry and not entry.special_attack_imminent then
				entry.special_attack_event = event_name
				entry.special_attack_imminent = true

				local now = mod.get_time()

				entry.special_attack_timer = now + 1.5
			end
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
