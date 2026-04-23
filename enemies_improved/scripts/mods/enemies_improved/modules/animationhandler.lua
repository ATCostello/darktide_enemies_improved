local mod = get_mod("enemies_improved")
mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/enemies_improved_localization")

local Unit_alive = Unit.alive
local Application_flow_callback_context_unit = Application.flow_callback_context_unit
local type = type

---------------------------------------------------------------------------------------------
-- ANIMATION BASED SPECIAL ATTACK DETECTION
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

mod.process_animation_event = function(unit, event_name)
	if not unit or not mod.detect_alive(unit) then
		return
	end

	if not event_name then
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

	local attack_data = breed_table[event_name]

	if attack_data then
		if event_name then
			entry.special_attack_event = event_name
			entry.special_attack_imminent = true

			local now = mod.get_time()

			entry.special_attack_timer = now + attack_data.duration
			if mod.DEBUG then
				mod:echo(
					"ANIMATION SPECIAL ATTACK: "
						.. event_name
						.. " - "
						.. attack_data.attack
						.. " - "
						.. attack_data.damage_time
						.. " - "
						.. attack_data.duration
				)
			end
		end
	end
end

local event_cache = {}
local reverse_cache = {}

-- Use a list of animation events we care about, and want to map to their event ids
local function get_possible_events_for_breed(breed_name)
	local breed_table = mod.special_attack_animations[breed_name]
	if not breed_table then
		return nil
	end

	local events = {}

	for event_name, _ in pairs(breed_table) do
		table.insert(events, event_name)
	end

	return events
end

-- Build mapping for a unit using known event names
mod.build_event_map = function(unit, breed_name)
	if not unit or not breed_name then
		return
	end

	local possible_events = get_possible_events_for_breed(breed_name)
	if not possible_events then
		return
	end

	event_cache[breed_name] = event_cache[breed_name] or {}
	reverse_cache[breed_name] = reverse_cache[breed_name] or {}

	for _, event_name in ipairs(possible_events) do
		if not event_cache[breed_name][event_name] then
			local event_index = Unit.animation_event(unit, event_name)

			if event_index and event_index >= 0 then
				event_cache[breed_name][event_name] = event_index
				reverse_cache[breed_name][event_index] = event_name
				if mod.DEBUG then
					mod:echo(string.format("[MAP] %s -> %d", event_name, event_index))
				end
			end
		end
	end
end

-- Resolve index back to name
mod.get_event_name_from_id = function(breed_name, event_index)
	if reverse_cache[breed_name] then
		return reverse_cache[breed_name][event_index]
	end
end

local function handle_animation_event(unit, event_index)
	local entry = mod.enemy_cache[unit]
	if not entry or not entry.unit_data_ext then
		return
	end

	local breed = entry.unit_data_ext:breed()
	local breed_name = breed and breed.name

	if not breed_name then
		return
	end

	-- ensure mapping exists
	mod.build_event_map(unit, breed_name)

	local event_name = mod.get_event_name_from_id(breed_name, event_index)

	if event_name then
		-- DEBUG
		if mod.DEBUG then
			mod:echo(string.format("[RESOLVED] %s -> %s", event_index, event_name))
		end
		mod.process_animation_event(unit, event_name)
	else
		--  debug
		--mod:echo(string.format("[UNKNOWN] %d (%s)", event_index, breed_name))
	end
end

mod:hook_safe(CLASS.AnimationSystem, "rpc_minion_anim_event", function(self, channel_id, unit_id, event_index)
	local unit = Managers.state.unit_spawner:unit(unit_id)

	if not unit or not Unit.alive(unit) then
		return
	end

	if mod.DEBUG then
		mod:echo("rpc anim event: " .. event_index)
	end
	handle_animation_event(unit, event_index)
end)

-- DEBUG ONLY TO SHOW ANIMATION NAMES FOR SPECIFIC ANIMATIONS
if mod.DEBUG then
	mod:hook_safe("Unit", "animation_event", function(unit, event_name)
		mod:echo("anim event: " .. event_name)
	end)
end
