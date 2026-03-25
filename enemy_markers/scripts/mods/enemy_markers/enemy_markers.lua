local mod = get_mod("enemy_markers")

mod.text_scale = mod:get("text_scale") or 1
mod.font_type = mod:get("font_type")
mod.frame_settings = {}

mod.build_frame_settings = function(dt)
	local fs = mod.frame_settings

	fs.dt = dt or 0

	-- Draw distance
	fs.draw_distance = mod:get("draw_distance")

	-- GENERAL
	fs.outlines_enable = mod:get("outlines_enable")
	fs.text_scale = mod:get("text_scale")
	fs.font_type = mod:get("font_type")

	-- MARKERS
	fs.markers_enable = mod:get("markers_enable")
	fs.marker_horde_enable = mod:get("marker_horde_enable")

	-- HEALTHBARS
	fs.healthbar_enable = mod:get("healthbar_enable")
	fs.healthbar_type_icon_enable = mod:get("healthbar_type_icon_enable")
	fs.show_damage_numbers = mod:get("hb_show_damage_numbers")
	fs.show_armor_types = mod:get("hb_show_armour_types")
	fs.hide_after_no_damage = mod:get("hb_hide_after_no_damage")
	fs.horde_enable = mod:get("hb_horde_enable")
	fs.horde_clusters_enable = mod:get("hb_horde_clusters_enable")
	fs.hb_show_enemy_type = mod:get("hb_show_enemy_type")
	fs.hb_text_show_health = mod:get("hb_text_show_health")
	fs.hb_text_show_damage = mod:get("hb_text_show_damage")
	fs.frame_type = mod:get("hb_frame")
	fs.hb_padding_scale = mod:get("hb_padding_scale")
	fs.hb_size_width = mod:get("hb_size_width")
	fs.hb_size_height = mod:get("hb_size_height")
	fs.hb_damage_number_type = mod:get("hb_damage_number_types")

	-- SPECIAL ATTACKS
	fs.marker_specials_enable = mod:get("marker_specials_enable")
	fs.healthbar_specials_enable = mod:get("healthbar_specials_enable")
	fs.outline_specials_enable = mod:get("outline_specials_enable")
	fs.specials_flash = mod:get("specials_flash")

	-- DEBUFFS
	fs.debuff_enable = mod:get("debuff_enable")
	fs.debuff_names = mod:get("debuff_names")
	fs.debuff_names_fade = mod:get("debuff_names_fade")
	fs.debuff_horde_enable = mod:get("debuff_horde_enable")
	fs.debuff_show_on_body = mod:get("debuff_show_on_body")
end

mod.build_frame_settings()

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

mod._broadphase_results = {}

mod.enemy_cache = {}
mod.enemy_markers = {}
mod.enemy_healthbars = {}
mod.enemy_debuffs = {}
mod.enemy_utility_debuffs = {}

mod.marked_dead = {}
mod.source_unit_cache = mod.source_unit_cache or {}

local MAX_ENEMIES_PER_FRAME = 500
local _enemy_units_temp = {}
local _last_enemy_index = 0

local HORDE_CLUSTER_RADIUS_SQ = 30 ^ 2
local HORDE_MIN_UNITS_FOR_CLUSTER = 20
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

-----------------------------------------------------------------------
-- Frame settings builder
-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- preload resources + reset caches on game state change
-----------------------------------------------------------------------
mod.on_game_state_changed = function(state, state_name)
	mod.on_game_state_changed = function(state, state_name)
		-- ensure packages are loaded
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

		Managers.package:load(
			"packages/ui/views/inventory_weapon_details_view/inventory_weapon_details_view",
			"enemy_markers",
			nil,
			true
		)
		Managers.package:load("packages/ui/views/expedition_view/expedition_view", "enemy_markers", nil, true)
		-- empty caches
		mod.clear_caches()
	end
end

mod.on_all_mods_loaded = function()
	mod.clear_caches()

	mod.init_healthbar_defaults()
	mod.update_breed_colours()
	mod.update_breed_icons()

	local outline_settings = require("scripts/settings/outline/outline_settings")
	mod.apply_enemy_outlines(outline_settings)
end

mod:hook_safe(CLASS.HudElementWorldMarkers, "init", function(self)
	-- add new marker templates to templates table
	self._marker_templates[EnemyMarkersTemplate.name] = EnemyMarkersTemplate
	self._marker_templates[EnemyHealthbarTemplate.name] = EnemyHealthbarTemplate
	self._marker_templates[EnemyDebuffTemplate.name] = EnemyDebuffTemplate
	self._marker_templates[EnemyUtilityDebuffTemplate.name] = EnemyUtilityDebuffTemplate
end)

-----------------------------------------------------------------------
-- Hook into the markers update to recalculate enemies.
-----------------------------------------------------------------------
mod:hook_safe(CLASS.HudElementWorldMarkers, "update", function(self, dt, t)
	-- throttle updates...
	local update_interval = 0.1 -- 1 is 1 second... do the maths ;)
	update_time = (update_time or 0) + dt

	if update_time > update_interval then
		update_time = 0

		-- Update enemies/markers for this frame
		mod.update_enemies(dt, t)
	end

	-- Hide default health bars (all damage_indicator variants except our custom one)
	local markers = self._markers
	if not markers or #markers == 0 then
		return
	end

	mod.markers = self._markers_by_type

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

	-- Apply distance / stacking fade to all active markers
	mod.apply_marker_fade()
end)

mod.get_marker_by_id = function(id)
	local ui_manager = Managers.ui
	local hud = ui_manager:get_hud()
	local world_markers = hud and hud:element("HudElementWorldMarkers")
	local markers_by_id = world_markers and world_markers._markers_by_id

	return markers_by_id[id]
end

mod.enable_enemy_outlines = function(unit, entry)
	if not Unit.alive(unit) then
		return
	end

	local has_outline_system = Managers.state.extension:has_system("outline_system")
	if not has_outline_system then
		return
	end

	local outline_system = Managers.state.extension:system("outline_system")

	-- get breed category
	local breed_name = entry.breed_type

	if not breed_name then
		breed_name = "enemy"
	end

	local new_outline = "enemies_" .. breed_name

	-- Do not enable outline if breed isn't allowed...
	local enabled = mod:get("outline_" .. breed_name .. "_enable")
	if enabled == false then
		return
	end

	-- only update if changed
	if entry.outline_name ~= new_outline then
		-- remove old
		if entry.outline_name then
			outline_system:remove_outline(unit, entry.outline_name)
		end

		-- add new
		outline_system:add_outline(unit, new_outline)

		entry.outline_name = new_outline
	end
end

mod.disable_enemy_outlines = function(unit)
	if Unit.alive(unit) then
		local has_outline_system = Managers.state.extension:has_system("outline_system")

		if has_outline_system then
			local outline_system = Managers.state.extension:system("outline_system")
			-- Force outline visible
			outline_system:remove_outline(unit, "enemies_improved")
		end
	end
end

mod.pulse_enemy_outline = function(entry)
	local unit = entry.unit
	local fs = mod.frame_settings

	if entry.special_attack_imminent then
		if not entry.alert_outline then
			local has_outline_system = Managers.state.extension:has_system("outline_system")

			if has_outline_system then
				local outline_system = Managers.state.extension:system("outline_system")
				-- Force outline visible
				outline_system:add_outline(unit, "enemies_improved_alert")
				entry.alert_outline = true
			end
		elseif entry.alert_outline and fs.specials_flash then
			local has_outline_system = Managers.state.extension:has_system("outline_system")

			if has_outline_system then
				local outline_system = Managers.state.extension:system("outline_system")
				-- Force outline visible
				outline_system:remove_outline(unit, "enemies_improved_alert")
				entry.alert_outline = false
			end
		end
	elseif not entry.special_attack_imminent and entry.alert_outline then
		local has_outline_system = Managers.state.extension:has_system("outline_system")

		if has_outline_system then
			local outline_system = Managers.state.extension:system("outline_system")
			-- Force outline visible
			outline_system:remove_outline(unit, "enemies_improved_alert")
			entry.alert_outline = false
		end
	end
end

mod.pulse_enemy_healthbar = function(entry)
	local unit = entry.unit
	local fs = mod.frame_settings

	if
		entry
		and entry.healthbar
		and entry.healthbar.widget.style.icon_background1
		and entry.healthbar.widget.style.icon_background1.color
	then
		-- get breed category
		local breed_type = entry.breed_type

		if not breed_type then
			breed_type = "enemy"
		end

		-- get settings
		local breed_settings = mod.ICON_SETTINGS[breed_type]
		local glow_colour = mod.ICON_COLOURS["glow"]
		local glow_colour_default = mod.ICON_COLOURS["glow_default"]

		if entry.special_attack_imminent then
			-- get special colour
			local sr = (mod:get("outline_specials_colour_R"))
			local sg = (mod:get("outline_specials_colour_G"))
			local sb = (mod:get("outline_specials_colour_B"))

			if not sr then
				sr = 255
			end
			if not sg then
				sg = 0
			end
			if not sb then
				sb = 0
			end

			if not entry.alert_healthbar then
				----- TURN ON
				entry.healthbar.widget.style.icon_background1.default_alpha = 255

				-- set alert glow intensity
				entry.healthbar.widget.style.icon_background1.default_alpha = 255
				entry.healthbar.widget.style.icon_background1.color[1] = 255

				-- set alert glow colour
				entry.healthbar.widget.style.icon_background1.color[2] = sr
				entry.healthbar.widget.style.icon_background1.color[3] = sg
				entry.healthbar.widget.style.icon_background1.color[4] = sb

				entry.alert_healthbar = true
			elseif entry.alert_healthbar and fs.specials_flash then
				----- TURN OFF
				-- set alert glow intensity
				entry.healthbar.widget.style.icon_background1.default_alpha = 0
				entry.healthbar.widget.style.icon_background1.color[1] = 0

				entry.alert_healthbar = false
			end
		else
			if entry.alert_healthbar then
				entry.alert_healthbar = false
			end
			entry.healthbar.widget.style.icon_background1.default_alpha = breed_settings.glow_intensity * 2.5
			entry.healthbar.widget.style.icon_background1.color = glow_colour_default
		end
	end
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

					-- cache extensions
					health_ext = ScriptUnit_has_extension(unit, "health_system"),
					unit_data_ext = ScriptUnit_has_extension(unit, "unit_data_system"),
					behavior_ext = ScriptUnit_has_extension(unit, "behavior_system"),

					is_horde = mod.is_horde(unit),

					breed = ScriptUnit_has_extension(unit, "unit_data_system"):breed(),
					breed_type = mod.find_breed_category(unit),

					special_attack_event = nil,
					special_attack_imminent = false,
					special_attack_timer = 0,

					-- outlines
					alert_outline = false,
					outline_name = nil,

					alert_healthbar = false,
				}
			else
				entry.seen = true
			end
		end
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
--[[mod:hook(Unit, "animation_event", function(func, unit, event, ...)
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
				entry.special_attack_timer = now + 1.5
			else
				entry.special_attack_timer = now + 1.5
			end

		end
	end

	return result
end)]]

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
			if value and type(value) == "userdata" and name and name == "unit" then
				return_value = value
			end
			v = v + 1
		end

		level = level + 1
	end

	dbg_locals = res

	return return_value
end

mod.handle_special_attacks = function(event_name, source_unit)
	if mod.special_attack_events[event_name] then
		local unit = nil

		-- Try to get uni from sourceunit
		if type(source_unit) == "userdata" and Unit.alive(source_unit) then
			unit = source_unit
		else
			local flow_unit = Application.flow_callback_context_unit()
			if flow_unit and type(flow_unit) == "userdata" and Unit.alive(flow_unit) then
				unit = flow_unit
			end
		end

		-- If not, try to get from local debugs
		if
			event_name
				== ("wwise/events/minions/play_weapon_netgunner_wind_up" or "wwise/events/weapon/play_special_sniper_flash")
			and not unit
		then
			local name, value = debug.getlocal(8, 1)
			unit = value._unit
		end

		-- if not, try to get from all locals
		if not unit then
			unit = extract_locals(1)
		end

		extract_locals(1)

		--mod:echo(string.format("%s [SOUND ATTACK DETECTED] %s -> %s", mod.ts(), unit, event_name))

		if unit and Unit_alive(unit) then
			entry = mod.enemy_cache[unit]

			if entry then
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

function string.starts(String, Start)
	return string.sub(String, 1, string.len(Start)) == Start
end

mod.remove_dead = function()
	local units_to_remove = {}

	dbg_mod = mod

	-- Go through each marker type and clear caches.
	local function iterate_types_removal(unit)
		local found_unit_marker = mod.enemy_markers[unit]
			or mod.enemy_healthbars[unit]
			or mod.enemy_debuffs[unit]
			or mod.enemy_utility_debuffs[unit]
			or nil

		-- try to find unit match from marker list..
		for _, markers in pairs(mod.markers) do
			for i = 1, #markers do
				local marker = markers[i]
				if marker and marker.unit == unit then
					if _ == "enemy_markers" then
						Managers.event:trigger("remove_world_marker", marker.id)
						found_unit_marker = marker.id
					elseif _ == "enemy_healthbar" then
						Managers.event:trigger("remove_world_marker", marker.id)
						found_unit_marker = marker.id
					elseif _ == "enemy_debuff" then
						Managers.event:trigger("remove_world_marker", marker.id)
						found_unit_marker = marker.id
					elseif _ == "enemy_utility_debuff" then
						Managers.event:trigger("remove_world_marker", marker.id)
						found_unit_marker = marker.id
					end
				end
			end
		end

		if found_unit_marker then
			table.insert(units_to_remove, unit)
		end
	end

	-- Detect if dead
	for unit, data in pairs(mod.enemy_cache) do
		if not HEALTH_ALIVE[unit] or not Unit.alive(unit) or string.starts(tostring(unit), "[Unit (deleted)") then
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
		mod.marked_dead[unit] = true
		mod.enemy_healthbars[unit] = nil
		mod.enemy_debuffs[unit] = nil
		mod.enemy_utility_debuffs[unit] = nil
		mod.enemy_markers[unit] = nil
		mod.enemy_cache[unit] = nil
	end
end

mod.is_horde = function(unit)
	if Unit.alive(unit) then
		local tags = mod.get_breed_tags(unit)
		local is_horde = tags and (tags.horde or tags.roamer) or false

		return is_horde or false
	else
		return false
	end
end

mod.update_enemy_outlines = function(entry)
	local unit = entry.unit

	local fs = mod.frame_settings
	if not fs.outlines_enable then
		return
	end

	if fs.outlines_enable then
		mod.enable_enemy_outlines(unit, entry)
	end
end

-------------------------------------------------------------------
-- Special attack detection
-------------------------------------------------------------------
mod.update_special_attack_detection = function(entry)
	local unit = entry.unit
	local ui_manager = Managers_ui
	local hud = ui_manager and ui_manager:get_hud()
	local world_markers = hud and hud:element("HudElementWorldMarkers")
	local markers_by_id = world_markers and world_markers._markers_by_id

	-- remove special_attack_imminent if over the timer...
	if entry.special_attack_imminent then
		local now = mod.get_time()

		if entry.special_attack_timer and now >= entry.special_attack_timer then
			entry.special_attack_imminent = false
			entry.special_attack_timer = nil
		end

		-- update marker status...
		for _, markers in pairs(mod.markers) do
			for i = 1, #markers do
				local marker = markers[i]
				if marker.unit == unit then
					if _ == "enemy_markers" or _ == "enemy_healthbar" then
						if entry and marker then
							marker.special_attack_imminent = entry.special_attack_imminent
						end
					end
				end
			end
		end
	end
end

-------------------------------------------------------------------
-- Enemy Markers
-------------------------------------------------------------------
mod.update_enemy_markers = function(entry, t)
	local unit = entry.unit

	local fs = mod.frame_settings
	if not fs.markers_enable then
		return
	end

	-- skip horde markers if not enabled
	if entry.is_horde and not fs.marker_horde_enable then
		return
	end

	-- add enemy markers if doesn't already exist
	if not mod.enemy_markers[unit] and not mod.marked_dead[unit] then
		Managers.event:trigger("add_world_marker_unit", EnemyMarkersTemplate.name, unit, function(marker_id)
			entry.marker = mod.get_marker_by_id(marker_id)
			mod.enemy_markers[unit] = marker_id
		end)
	end
end

-----------------------------------------------------------------------
-- Enemy healthbars
-----------------------------------------------------------------------

mod.update_enemy_healthbars = function(entry)
	local unit = entry.unit
	--mod:echo("update healthbars")
	local fs = mod.frame_settings
	if not fs.healthbar_enable then
		return
	end

	-- skip horde if not enabled
	if (entry.is_horde and not fs.horde_enable) and (entry.is_horde and not fs.horde_clusters_enable) then
		return
	end

	if not mod.enemy_healthbars[unit] and not mod.marked_dead[unit] then
		local cluster = fs.horde_clusters_enable and mod.get_horde_cluster_for_unit(unit) or nil

		-- If this unit is part of a horde cluster, only give a healthbar to the representative
		if cluster then
			if cluster.rep_unit ~= unit then
				goto continue_healthbar_loop
			end
		end

		Managers_event:trigger("add_world_marker_unit", "enemy_healthbar", unit, function(marker_id)
			entry.healthbar = mod.get_marker_by_id(marker_id)
			mod.enemy_healthbars[unit] = marker_id
		end)
		::continue_healthbar_loop::
	end
end

-----------------------------------------------------------------------
-- Enemy debuffs
-----------------------------------------------------------------------

mod.update_enemy_debuffs = function(entry)
	local unit = entry.unit

	local fs = mod.frame_settings
	if not fs.debuff_enable then
		return
	end

	-- only add debuffs for living enemies that are not dead and removed
	if not mod.enemy_debuffs[unit] and not mod.marked_dead[unit] then
		Managers_event:trigger("add_world_marker_unit", "enemy_debuff", unit, function(debuff_id)
			entry.dot_debuffs = mod.get_marker_by_id(marker_id)
			mod.enemy_debuffs[unit] = debuff_id
		end)
	end
end

mod.update_enemy_utility_debuffs = function(entry)
	local unit = entry.unit

	local fs = mod.frame_settings
	if not fs.debuff_enable then
		return
	end

	if not mod.enemy_utility_debuffs[unit] and not mod.marked_dead[unit] then
		Managers_event:trigger("add_world_marker_unit", EnemyUtilityDebuffTemplate.name, unit, function(marker_id)
			entry.utility_debuffs = mod.get_marker_by_id(marker_id)
			mod.enemy_utility_debuffs[unit] = marker_id
		end)
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

	table_clear(mod.enemy_cache)
	table_clear(mod.marked_dead)

	table_clear(_enemy_units_temp)
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
						local base_alpha = 255

						if style.default_alpha then
							base_alpha = style.default_alpha
						end
						if style.color then
							style.color[1] = base_alpha * final_alpha
						end
						if style.text_color then
							style.text_color[1] = base_alpha * final_alpha
						end
					end
				end
			end
		end
	end
end

mod.update_horde_clusters = function(temp, to_process)
	local fs = mod.frame_settings

	if fs.horde_clusters_enable then
		local CLUSTER_UPDATE_INTERVAL = 0.05
		_cluster_t = (_cluster_t or 0) + fs.dt

		if _cluster_t > CLUSTER_UPDATE_INTERVAL then
			_cluster_t = 0
			_build_horde_clusters(temp, to_process)
		end
	else
		table_clear(_horde_clusters)
		table_clear(_horde_cluster_by_unit)
	end
end
-----------------------------------------------------------------------
-- Main update orchestration
-----------------------------------------------------------------------

mod.update_enemies = function(dt, t)
	mod.build_frame_settings(dt or 0)
	local fs = mod.frame_settings

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

	-- update horde clusters...
	if fs.healthbar_enable and fs.horde_clusters_enable then
		mod.update_horde_clusters(temp, to_process)
	end

	-- go through enemy_cache and perform updates...
	for i = 1, to_process do
		local unit = temp[i]
		if mod.enemy_cache[unit] then
			local entry = mod.enemy_cache[unit]
			dbg_entry = entry

			if fs.markers_enable then
				mod.update_enemy_markers(entry, t)
			end

			if fs.outlines_enable then
				mod.update_enemy_outlines(entry)
			end

			if fs.healthbar_enable then
				mod.update_enemy_healthbars(entry)
			end

			if fs.debuff_enable then
				mod.update_enemy_debuffs(entry)
				mod.update_enemy_utility_debuffs(entry)
			end

			mod.update_special_attack_detection(entry)

			if fs.outline_specials_enable then
				mod.pulse_enemy_outline(entry)
			end
			if fs.healthbar_specials_enable then
				--mod.pulse_enemy_healthbar(entry)
			end
		end
	end

	mod.remove_dead()
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
		elseif tags.elite and tags.far or tags.special and tags.far then
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

-- OUTLINES
mod.default_outline_enabled = {
	horde = false,
	monster = false,
	captain = false,
	disabler = true,
	witch = true,
	sniper = true,
	far = false,
	elite = false,
	special = false,
	enemy = false,
}

mod.apply_enemy_outlines = function(settings)
	for _, entry in ipairs(mod.breed_types) do
		local breed = entry.value

		if breed ~= "select" then
			local key = "outline_" .. breed .. "_enable"
			local enabled = mod:get(key)

			-- set default from above table if not expicitly set yet.
			if enabled == nil then
				enabled = mod.default_outline_enabled[breed]

				if enabled == nil then
					enabled = true
				end

				mod:set(key, enabled)
			end

			local r = mod:get("outline_" .. breed .. "_colour_R")
			local g = mod:get("outline_" .. breed .. "_colour_G")
			local b = mod:get("outline_" .. breed .. "_colour_B")

			-- initialise to defaults if nil values...
			if r == nil or g == nil or b == nil then
				r = mod.OUTLINE_COLOURS_DEFAULT[breed][2]
				mod:set("outline_" .. breed .. "_colour_R", r)
				g = mod.OUTLINE_COLOURS_DEFAULT[breed][3]
				mod:set("outline_" .. breed .. "_colour_G", g)
				b = mod.OUTLINE_COLOURS_DEFAULT[breed][4]
				mod:set("outline_" .. breed .. "_colour_B", b)
			end

			if enabled then
				if not r then
					r = 50
				end
				if not g then
					g = 10
				end
				if not b then
					b = 0
				end

				r = r / 255
				g = g / 255
				b = b / 255

				settings.MinionOutlineExtension["enemies_" .. breed] = {
					priority = 2,
					material_layers = {
						"minion_outline",
						"minion_outline_reversed_depth",
					},
					color = { r, g, b },
					visibility_check = function()
						return true
					end,
				}
			else
				-- remove if disabled
				settings.MinionOutlineExtension["enemies_" .. breed] = nil
			end
		end
	end

	-- SPECIAL ATTACK OUTLINE
	local sr = (mod:get("outline_specials_colour_R"))
	local sg = (mod:get("outline_specials_colour_G"))
	local sb = (mod:get("outline_specials_colour_B"))

	if not sr then
		sr = 255
	end
	if not sg then
		sg = 0
	end
	if not sb then
		sb = 0
	end

	sr = sr / 255
	sg = sg / 255
	sb = sb / 255

	settings.MinionOutlineExtension.enemies_improved_alert = {
		priority = 1,
		material_layers = {
			"minion_outline",
			"minion_outline_reversed_depth",
		},
		color = { sr, sg, sb },
		visibility_check = function()
			return true
		end,
	}
end

mod:hook_require("scripts/settings/outline/outline_settings", function(settings)
	mod.apply_enemy_outlines(settings)
end)

-----------------------------------------------------------------------
-- Settings changed
-----------------------------------------------------------------------

-- list of settings to monitor PER enemy type, needs to be updated if more types are added...
-- REQUIRES "_type_" AS THAT IS WHERE THE SPECIFIC ENEMY GROUP NAME IS PLACED...
local enemy_type_settings = {
	["outline_type_enable"] = true,
	["outline_type_colour_R"] = 50,
	["outline_type_colour_G"] = 10,
	["outline_type_colour_B"] = 0,

	["healthbar_type_enable"] = true,
	["healthbar_type_colour_R"] = 255,
	["healthbar_type_colour_G"] = 0,
	["healthbar_type_colour_B"] = 0,

	["healthbar_icon_type_enable"] = true,
	["healthbar_icon_type_scale"] = 1,
	["healthbar_icon_type_glow_intensity"] = 1,
	["healthbar_icon_type_colour_R"] = 200,
	["healthbar_icon_type_colour_G"] = 150,
	["healthbar_icon_type_colour_B"] = 0,

	["reset_type_to_default"] = false,
}

mod.reset_type_to_default = function(enemy_type)
	-- reset all options to nil so that the defaults will be loaded...
	mod:set("healthbar_" .. enemy_type .. "_colour_R", nil)
	mod:set("healthbar_icon_" .. enemy_type .. "_enable", nil)
	mod:set("healthbar_icon_" .. enemy_type .. "_scale", nil)
	mod:set("healthbar_icon_" .. enemy_type .. "_glow_intensity", nil)
	mod:set("healthbar_icon_" .. enemy_type .. "_colour_R", nil)

	mod:set("outline_" .. enemy_type .. "_enable", nil)
	mod:set("outline_" .. enemy_type .. "_colour_R", nil)

	local reset_message = mod:localize("reset_type_to_default_message")
	mod:notify(reset_message:gsub("_type_", "_" .. enemy_type .. "_"))

	mod.init_healthbar_defaults()
end

mod.init_healthbar_defaults = function()
	-- bar colours
	for breed, color in pairs(mod.BREED_COLOURS_DEFAULT) do
		local r = color[2]
		local g = color[3]
		local b = color[4]

		-- only set if not already saved
		if mod:get("healthbar_" .. breed .. "_colour_R") == nil then
			mod:set("healthbar_" .. breed .. "_colour_R", r)
			mod:set("healthbar_" .. breed .. "_colour_G", g)
			mod:set("healthbar_" .. breed .. "_colour_B", b)
		end
	end

	-- icon settings
	for breed, settings in pairs(mod.ICON_SETTINGS_DEFAULT) do
		if mod:get("healthbar_icon_" .. breed .. "_enable") == nil then
			mod:set("healthbar_icon_" .. breed .. "_enable", settings.enabled)
		end
		if mod:get("healthbar_icon_" .. breed .. "_scale") == nil then
			mod:set("healthbar_icon_" .. breed .. "_scale", settings.scale)
		end
		if mod:get("healthbar_icon_" .. breed .. "_glow_intensity") == nil then
			mod:set("healthbar_icon_" .. breed .. "_glow_intensity", settings.glow_intensity)
		end
	end

	-- icon colours
	for breed, color in pairs(mod.ICON_COLOURS_DEFAULT) do
		local r = color[2]
		local g = color[3]
		local b = color[4]

		-- only set if not already saved
		if mod:get("healthbar_icon_" .. breed .. "_colour_R") == nil then
			mod:set("healthbar_icon_" .. breed .. "_colour_R", r)
			mod:set("healthbar_icon_" .. breed .. "_colour_G", g)
			mod:set("healthbar_icon_" .. breed .. "_colour_B", b)
		end
	end
end

mod.update_breed_colours = function()
	for breed, default_color in pairs(mod.BREED_COLOURS) do
		local r = mod:get("healthbar_" .. breed .. "_colour_R")
		local g = mod:get("healthbar_" .. breed .. "_colour_G")
		local b = mod:get("healthbar_" .. breed .. "_colour_B")
		local a = default_color[1] or 255

		if r and g and b then
			mod.BREED_COLOURS[breed] = { a, r, g, b }
		end
	end
end

mod.update_breed_icons = function()
	-- settings
	for breed, settings in pairs(mod.ICON_SETTINGS) do
		local enabled = mod:get("healthbar_icon_" .. breed .. "_enable")
		local scale = mod:get("healthbar_icon_" .. breed .. "_scale")
		local glow_intensity = mod:get("healthbar_icon_" .. breed .. "_glow_intensity")

		mod.ICON_SETTINGS[breed].enabled = enabled
		mod.ICON_SETTINGS[breed].scale = scale
		mod.ICON_SETTINGS[breed].glow_intensity = glow_intensity
		mod.ICON_SETTINGS[breed].default_glow_intensity = glow_intensity
	end
	-- colours
	for breed, default_color in pairs(mod.ICON_COLOURS) do
		local r = mod:get("healthbar_icon_" .. breed .. "_colour_R")
		local g = mod:get("healthbar_icon_" .. breed .. "_colour_G")
		local b = mod:get("healthbar_icon_" .. breed .. "_colour_B")
		local a = default_color[1] or 255

		if r and g and b then
			mod.ICON_COLOURS[breed] = { a, r, g, b }
		end
	end
end

mod.update_settings_values = function(setting_id)
	local selected_enemy_type = mod:get("enemy_group")
	if not selected_enemy_type then
		return
	end

	local reset_string = "reset_type_to_default"
	local reset_setting_id = reset_string:gsub("_type_", "_" .. selected_enemy_type .. "_")

	-- Set the enemy type widgets when a group is selected
	for setting_name, default_value in pairs(enemy_type_settings) do
		local type_value = mod:get(setting_name)

		local enemy_type = setting_name:gsub("_type_", "_" .. selected_enemy_type .. "_")
		local enemy_type_value = mod:get(enemy_type)

		if enemy_type_value == nil then
			enemy_type_value = default_value
		end

		-- STORE VALUES WHEN CHANGED
		if setting_id == setting_name then
			if enemy_type_value ~= type_value then
				--mod:error("set " .. tostring(enemy_type) .. " to " .. tostring(type_value))
				mod:set(enemy_type, type_value)
			end
		end

		-- SET UI VALUES WHEN DROPDOWN IS SELECTED...
		if setting_id == "enemy_group" or mod:get(reset_setting_id) == true or setting_id == nil then
			if type_value ~= enemy_type_value then
				--mod:error("LOADED VALUES: " .. tostring(setting_name) .. " to " .. tostring(enemy_type_value))
				mod:set(setting_name, enemy_type_value)
			end
		end
	end
end

mod.on_setting_changed = function(setting_id)
	local selected_enemy_type = mod:get("enemy_group")
	if not selected_enemy_type then
		return
	end

	mod.update_settings_values(setting_id)

	local reset_string = "reset_type_to_default"
	local reset_setting_id = reset_string:gsub("_type_", "_" .. selected_enemy_type .. "_")

	-- HANDLE RESET TO DEFAULT LOGIC...
	if mod:get(reset_setting_id) == true then
		mod.reset_type_to_default(mod:get("enemy_group"))
		mod.update_settings_values(reset_setting_id)
	end

	-- rebuild outlines
	local outline_settings = require("scripts/settings/outline/outline_settings")
	mod.apply_enemy_outlines(outline_settings)

	-- update breed settings
	mod.update_breed_colours()
	mod.update_breed_icons()

	-- clear all caches to reload data with new values
	mod.clear_caches()

	mod.font_type = mod:get("font_type")
	mod.text_scale = mod:get("text_scale")

	if mod:get(reset_setting_id) == true then
		mod:set(reset_setting_id, false)
	end

	mod.update_settings_values()
end
