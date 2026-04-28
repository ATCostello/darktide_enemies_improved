local mod = get_mod("enemies_improved")
mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/enemies_improved_localization")
local StaggerSettings = require("scripts/settings/damage/stagger_settings")
local stagger_types = StaggerSettings.stagger_types
local BreedActions = require("scripts/settings/breed/breed_actions")
--local BreedActions = table.copy(BreedActions) -- keep a local copy always...
local Stagger = require("scripts/utilities/attack/stagger")

local DMF = get_mod("DMF")

local _io = DMF and DMF:persistent_table("_io")
if _io and not _io.initialized then
	_io = DMF.deepcopy(Mods.lua.io)
end
_io = _io or Mods.lua.io

local Unit_alive = Unit.alive
local Application_flow_callback_context_unit = Application.flow_callback_context_unit
local type = type

mod.anim_db = mod.anim_db or {}
mod.anim_db_dirty = false

if mod.DEBUG then
	mod.dbg_breedactions = BreedActions
end

local function serialize_table(val, indent)
	indent = indent or 0
	local spacing = string.rep("    ", indent)

	if type(val) == "table" then
		local result = "{\n"

		for k, v in pairs(val) do
			local key
			if type(k) == "string" then
				key = string.format("[%q]", k)
			else
				key = string.format("[%s]", tostring(k))
			end

			result = result .. spacing .. "    " .. key .. " = " .. serialize_table(v, indent + 1) .. ",\n"
		end

		return result .. spacing .. "}"
	elseif type(val) == "string" then
		return string.format("%q", val)
	elseif type(val) == "number" or type(val) == "boolean" then
		return tostring(val)
	else
		return "nil"
	end
end

mod.prune_anim_db = function()
	for breed_name, db in pairs(mod.anim_db) do
		-- remove empty subtables
		if next(db.name_to_id) == nil then
			db.name_to_id = {}
		end
		if next(db.id_to_name) == nil then
			db.id_to_name = {}
		end
		if next(db.special_attacks) == nil then
			db.special_attacks = {}
		end
		if next(db.staggers) == nil then
			db.staggers = {}
		end
	end
end

mod.save_anim_db = function()
	mod:echo("[ANIM_DB] Saving...")
	if not mod.anim_db_dirty then
		return
	end
	local path = "../mods/enemies_improved/scripts/mods/enemies_improved/modules/animations/anim_db.lua"

	local file, err = _io.open(path, "w+")
	if not file then
		mod:echo("[ANIM_DB] Failed to open file: " .. tostring(err))
		return
	end

	local content = "return " .. serialize_table(mod.anim_db)

	file:write(content)
	file:close()

	mod.anim_db_dirty = false

	if mod.DEBUG then
		mod:echo("[ANIM_DB] Saved successfully")
	end
end

mod.load_anim_db = function()
	local local_anim_db = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/animations/anim_db")

	if local_anim_db then
		mod.anim_db = local_anim_db
		if mod.DEBUG then
			mod:echo("[ANIM_DB] Loaded from storage")
		end
	else
		mod.anim_db = {}
		if mod.DEBUG then
			mod:echo("[ANIM_DB] Failed to load from storage, creating new.")
		end
	end
end

mod.clean_anim_db = function()
	for breed_name, db in pairs(mod.anim_db) do
		-- clean name_to_id
		for name, id in pairs(db.name_to_id) do
			if type(name) ~= "string" or type(id) ~= "number" or id < 0 or db.id_to_name[id] ~= name then
				db.name_to_id[name] = nil
				mod.anim_db_dirty = true
			end
		end

		-- clean id_to_name
		for id, name in pairs(db.id_to_name) do
			if type(id) ~= "number" or type(name) ~= "string" or db.name_to_id[name] ~= id then
				db.id_to_name[id] = nil
				mod.anim_db_dirty = true
			end
		end
	end

	if mod.DEBUG then
		mod:echo("[ANIM_DB] Cleaned invalid mappings")
	end
end

--[[ -- mod:settings stuff, too much memory hog
mod.load_anim_db = function()
	local saved = mod:get("anim_db")

	if saved then
		mod.anim_db = saved
		if mod.DEBUG then
			mod:echo("[ANIM_DB] Loaded from storage")
		end
	else
		mod.anim_db = {}
	end

	mod.clean_anim_db()
end

mod.save_anim_db = function()
	if not mod.anim_db_dirty then
		return
	end

	mod:set("anim_db", mod.anim_db)
	mod.anim_db_dirty = false

	if mod.DEBUG then
		mod:echo("[ANIM_DB] Saved to storage")
	end
end]]

---------------------------------------------------------------------------------------------
-- ANIMATION BASED SPECIAL ATTACK DETECTION
---------------------------------------------------------------------------------------------

-- better than audio cues - but only works on local games due to event_names not being known locally :(
mod.special_attack_animations = {
	----------------------------------------------------------------
	-- DAEMONHOST
	----------------------------------------------------------------
	chaos_daemonhost = {
		to_alerted = {
			attack = "to_alerted",
			damage_time = 1.05,
			duration = 2.3333333333333335,
		},
		to_alerted_2 = {
			attack = "to_alerted_2",
			damage_time = 1.05,
			duration = 2.2222222222222223,
		},
		alerted_3 = {
			attack = "alerted_3",
			damage_time = 1.05,
			duration = 3.111111111111111,
		},
		alerted_3_short = {
			attack = "alerted_3_short",
			damage_time = 1.05,
			duration = 1.4666666666666666,
		},
	},

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
	-- CHAOS ARMOURED HOUND
	----------------------------------------------------------------
	chaos_armored_hound = {
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
	-- NETGUNNER
	----------------------------------------------------------------

	renegade_netgunner = {
		attack_netgun = {
			attack = "netgun_attack",
			damage_time = 0.95,
			duration = 2.3,
		},
		aim_loop = {
			attack = "aim_loop",
			damage_time = 0.95,
			duration = 2.3,
		},
	},

	----------------------------------------------------------------
	-- RENEGADE SNIPER
	----------------------------------------------------------------
	renegade_sniper = {
		attack_shoot = {
			attack = "attack_shoot",
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

local function collect_anim_events_recursive(t, results)
	if not t then
		return
	end

	for key, value in pairs(t) do
		local key_str = type(key) == "string" and string.lower(key) or nil
		----------	---------------------------------------
		-- Only look at keys likely to contain anim events
		-------------------------------------------------
		local is_anim_key = key_str
			and (string.find(key_str, "anim") or key_str == "animation" or key_str == "anim_event")

		if is_anim_key then
			if type(value) == "string" then
				results[value] = true
			elseif type(value) == "table" then
				for _, v in pairs(value) do
					if type(v) == "string" then
						results[v] = true
					end
				end
			end
		end

		-------------------------------------------------
		-- Recurse deeper
		-------------------------------------------------
		if type(value) == "table" then
			collect_anim_events_recursive(value, results)
		end
	end
end

mod.anim_db = mod.anim_db or {}
mod.dbg_stagger = Stagger
mod.get_stagger_calculation_results = function() end

mod.init_breed_anim_db = function(unit, breed, breed_name)
	local db = mod.anim_db[breed_name]

	if not db then
		db = {
			name_to_id = {},
			id_to_name = {},
			special_attacks = {},
			staggers = {},
		}
		mod.anim_db[breed_name] = db
	end

	-------------------------------------------------
	-- 1. Collect ALL animation events
	-------------------------------------------------
	local results = {}
	local breed_actions = BreedActions[breed_name]

	if not breed_actions then
		return
	end

	collect_anim_events_recursive(breed_actions, results)

	-------------------------------------------------
	-- 2. Resolve event_name → event_id
	-------------------------------------------------
	for event_name, _ in pairs(results) do
		if not db.name_to_id[event_name] then
			local id = Unit.animation_event(unit, event_name)

			if id and id >= 0 then
				db.name_to_id[event_name] = id
				db.id_to_name[id] = event_name
				mod.anim_db_dirty = true

				if mod.DEBUG then
					--mod:echo(string.format("[DISCOVERED][%s] %s -> %d", breed_name, event_name, id))
				end
			end
		end
	end

	-------------------------------------------------
	-- 3. Cache SPECIAL ATTACKS directly by ID
	-------------------------------------------------
	local special_table = mod.special_attack_animations[breed_name]

	if special_table then
		for event_name, attack_data in pairs(special_table) do
			local id = db.name_to_id[event_name]

			if id and not db.special_attacks[id] then
				db.special_attacks[id] = attack_data
				mod.anim_db_dirty = true
			end
		end
	end

	-------------------------------------------------
	-- 4. Cache STAGGERS directly by ID
	-------------------------------------------------
	local stagger_root = breed_actions.stagger
	local stagger_table = stagger_root and stagger_root.stagger_anims
	local breed_stagger_durations = breed and breed.stagger_durations

	local function register_stagger_anim(db, anim_name, stagger_type, duration)
		local id = db.name_to_id[anim_name]

		if not id then
			id = Unit.animation_event(unit, anim_name)

			if id and id >= 0 then
				db.name_to_id[anim_name] = id
				db.id_to_name[id] = anim_name
				mod.anim_db_dirty = true
			end
		end

		if not id then
			if mod.DEBUG then
				--mod:echo("[STAGGER MISS] no id for anim: " .. tostring(anim_name))
			end
		end

		if id and not db.staggers[id] then
			db.staggers[id] = {
				type = stagger_type,
				duration = duration,
				source_anim = anim_name,
			}

			mod.anim_db_dirty = true

			if mod.DEBUG then
				--mod:echo(string.format("[STAGGER MAP][%s] %s -> %d", tostring(stagger_type), anim_name, id))
			end
		end
	end

	local function walk_stagger_anims(tbl, stagger_type, duration)
		for k, v in pairs(tbl) do
			if type(v) == "string" then
				register_stagger_anim(db, v, stagger_type, duration)
			elseif type(v) == "table" then
				walk_stagger_anims(v, stagger_type, duration)
			end
		end
	end

	if stagger_table then
		for stagger_type, stagger_data in pairs(stagger_table) do
			local duration = nil

			if breed_stagger_durations and breed_stagger_durations[stagger_type] then
				duration = breed_stagger_durations[stagger_type]
			elseif type(stagger_data) == "table" then
				duration = stagger_data.duration
			end

			-------------------------------------------------
			-- CASE 1: simple animation field
			-------------------------------------------------
			if type(stagger_data) == "string" then
				register_stagger_anim(db, stagger_data, stagger_type, duration)
			elseif type(stagger_data) == "table" then
				if stagger_data.animation then
					if type(stagger_data.animation) == "string" then
						register_stagger_anim(db, stagger_data.animation, stagger_type, duration)
					elseif type(stagger_data.animation) == "table" then
						for _, anim in ipairs(stagger_data.animation) do
							register_stagger_anim(db, anim, stagger_type, duration)
						end
					end
				end

				-------------------------------------------------
				-- CASE 2: complex stagger_anims tree
				-------------------------------------------------
				for stagger_type, stagger_data in pairs(stagger_table) do
					local duration = nil

					if breed_stagger_durations and breed_stagger_durations[stagger_type] then
						duration = breed_stagger_durations[stagger_type]
					end

					walk_stagger_anims(stagger_data, stagger_type, duration)
				end
			end
		end
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

	local db = mod.anim_db[breed_name]
	if not db then
		return
	end

	if mod.DEBUG then
		if db.id_to_name[event_index] then
			--mod:echo(breed_name .. " : " .. db.id_to_name[event_index])
		end
	end
	-------------------------------------------------
	-- SPECIAL ATTACK (O(1))
	-------------------------------------------------
	local attack_data = db.special_attacks[event_index]

	if attack_data then
		entry.special_attack_event = db.id_to_name[event_index]
		entry.special_attack_imminent = true

		local now = mod.get_time()
		entry.special_attack_timer = now + attack_data.duration

		if mod.DEBUG then
			--mod:echo(string.format("[SPECIAL][%s] %s", breed_name, entry.special_attack_event))
		end
	end

	-------------------------------------------------
	-- STAGGER (O(1))
	-------------------------------------------------
	local stagger = db.staggers[event_index]

	if stagger then
		entry.staggered = true
		entry.stagger_type = stagger.type
		entry.stagger_duration = stagger.duration
		entry.stagger_timer = mod.get_time() + stagger.duration

		mod.get_stagger_calculation_results()

		if mod.DEBUG then
			--mod:echo(
			--	string.format(
			--		"[STAGGER][%s] type=%s duration=%.2f",
			--		breed_name,
			--		tostring(stagger.type),
			--		stagger.duration
			--	)
			--)
		end
	end
end

local function handle_animation_event_from_name(unit, event_name)
	local entry = mod.enemy_cache[unit]
	if not entry or not entry.unit_data_ext then
		return
	end

	local breed = entry.unit_data_ext:breed()
	local breed_name = breed and breed.name

	if not breed_name then
		return
	end

	local db = mod.anim_db[breed_name]
	if not db then
		return
	end

	local event_index = db.name_to_id[event_name]
	if event_index then
		handle_animation_event(unit, event_index)
	end
end

mod:hook_safe(CLASS.AnimationSystem, "rpc_minion_anim_event", function(self, channel_id, unit_id, event_index)
	local unit = Managers.state.unit_spawner:unit(unit_id)

	if not unit or not Unit.alive(unit) then
		return
	end

	handle_animation_event(unit, event_index)
end)

mod:hook_safe("Unit", "animation_event", function(unit, event_name)
	if not unit or not Unit.alive(unit) then
		return
	end

	handle_animation_event_from_name(unit, event_name)
end)
