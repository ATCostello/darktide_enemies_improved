local mod = get_mod("enemies_improved")

mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/enemies_improved_localization")

local Managers_player = Managers.player
local Managers_state = Managers.state
local Managers_ui = Managers.ui
local Managers_time = Managers.time
local Managers_world = Managers.world
local ScriptUnit_extension = ScriptUnit.extension
local ScriptUnit_has_extension = ScriptUnit.has_extension
local table_clear = table.clear
local table_remove = table.remove
local table_index_of = table.index_of
local math_lerp = math.lerp
local math_min = math.min
local math_max = math.max
local next = next
local math_floor = math.floor
local Unit_alive = Unit.alive
local Actor_unit = Actor.unit
local World_physics_world = World.physics_world
local Quaternion_forward = Quaternion.forward

-- debug mode toggle!!!
mod.DEBUG = false
if mod.DEBUG then
	dbg_mod = mod

	local MemProfile = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/utils/mem_profile")
	mod.mem_profile = MemProfile

	mod.update = function(dt)
		mod.mem_profile.tick(dt)
		mod.mem_profile.render_gui()
	end
end

mod.detect_alive = function(unit)
	if unit and HEALTH_ALIVE[unit] and Unit_alive(unit) then
		return true
	end
	return false
end

mod._on_ei_marker_created = function(marker_id, entry, unit)
	if not entry or not entry._ei_marker_pending then
		if marker_id then
			Managers.event:trigger("remove_world_marker", marker_id)
		end
		return
	end

	if mod.enemy_markers[unit] then
		entry._ei_marker_pending = nil
		Managers.event:trigger("remove_world_marker", marker_id)
		return
	end

	entry.marker = mod.get_marker_by_id(marker_id)

	mod.enemy_markers[unit] = marker_id
	mod.enemy_healthbars[unit] = marker_id
	mod.enemy_debuffs[unit] = marker_id

	entry._ei_marker_created = true
	entry._ei_marker_pending = nil

	if mod.frame_settings.horde_clusters_enable and entry.is_horde then
		local cluster = mod.get_horde_cluster_for_unit(unit)
		if cluster then
			cluster._healthbar_created = true
			cluster._healthbar_marker_id = marker_id
		end
	end
end

-- ENEMIES IMPROVED FUNCTIONS
local FrameSettings = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/utils/frame_settings")
local SettingsFunctions = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/utils/settings_functions")
local DistanceFade = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/utils/fading")

local Outlines = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/outlines")
local Healthbars = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/healthbars")
local Markers = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/markers")
local Debuffs = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/debuffs")
local BossDebuffs = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/bossdebuffs")

local SpecialAttacks = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/specialattacks")
local AnimationHandler =
	mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/animations/animationhandler")

local BreedQueries = require("scripts/utilities/breed_queries")
local minion_breeds = BreedQueries.minion_breeds_by_name()
local Recoil = require("scripts/utilities/recoil")
local Sway = require("scripts/utilities/sway")
local HudElementWorldMarkers = require("scripts/ui/hud/elements/world_markers/hud_element_world_markers")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIScenegraph = require("scripts/managers/ui/ui_scenegraph")
local HudElementSmartTagging = require("scripts/ui/hud/elements/smart_tagging/hud_element_smart_tagging")
local Component = require("scripts/utilities/component")
local MechanismManager = require("scripts/managers/mechanism/mechanism_manager")

mod._broadphase_results = {}

local BROADPHASE_CELL_RADIUS = 50
local BROADPHASE_LATTICE_SPACING = 50 * 1.4142135623731
local BROADPHASE_LATTICE_OFFSETS = {
	{ -1, -1 },
	{ -1, 0 },
	{ -1, 1 },
	{ 0, -1 },
	{ 0, 1 },
	{ 1, -1 },
	{ 1, 0 },
	{ 1, 1 },
}

mod._broadphase_scratch = {}
mod._broadphase_seen = {}

mod.enemy_cache = {}
mod.enemy_markers = {}
mod.enemy_healthbars = {}
mod.enemy_debuffs = {}

mod.marked_dead = {}
mod.source_unit_cache = mod.source_unit_cache or {}
mod.enabled = true

local MAX_ENEMIES_PER_FRAME = 100
local _enemy_units_temp = {}
local _last_enemy_index = 0
local _horde_units_all = {}
local _cull_pool = {}
local _cull_pool_count = 0

local _player_pos_vec = Vector3.zero()
local _pos_vec = Vector3.zero()
local _bfs_pos = Vector3.zero()
local _bfs_other_pos = Vector3.zero()

local _horde_clusters = {}
local _horde_cluster_by_unit = {}

local _spatial_hash = {}
local _visited = {}
local _z_samples = {}
local _bfs_queue = {}

if mod.DEBUG then
	local mem = mod.mem_profile
	mem.track("cluster._horde_clusters", _horde_clusters)
	mem.track("cluster._horde_cluster_by_unit", _horde_cluster_by_unit)
	mem.track("cluster._cull_pool", _cull_pool)
	mem.track("cluster._spatial_hash", _spatial_hash)
	mem.track("cluster._visited", _visited)
	mem.track("cluster._z_samples", _z_samples)
	mem.track("cluster._bfs_queue", _bfs_queue)
	mem.track("mod._broadphase_results", mod._broadphase_results)
	mem.track("mod._broadphase_scratch", mod._broadphase_scratch)
	mem.track("mod._broadphase_seen", mod._broadphase_seen)
	mem.track("mod.enemy_cache", mod.enemy_cache)
	mem.track("mod.enemy_markers", mod.enemy_markers)
	mem.track("mod.enemy_healthbars", mod.enemy_healthbars)
	mem.track("mod.enemy_debuffs", mod.enemy_debuffs)
	mem.track("mod.marked_dead", mod.marked_dead)
	mem.track("mod.source_unit_cache", mod.source_unit_cache)
end

local COLOUR_LOOKUP = {
	Gold = { 255, 232, 188, 109 },
	Silver = { 255, 187, 198, 201 },
	Steel = { 255, 161, 166, 169 },
	Black = { 255, 35, 31, 32 },
	Brass = { 255, 226, 199, 126 },
	Terminal = Color.terminal_background(200, true),
	Default = { 255, 161, 166, 169 },
}

local CULL_CELL_SIZE = 5
local INV_CULL_CELL = 1 / CULL_CELL_SIZE
local _cull_cells = {}
local MAX_PER_CELL = 3

-- depth layers, unrolled into _depth_keep below:
--   slots 1-4    always kept
--   slots 5-6    score >= 200
--   slots 7-8    score >= 400
--   slots 9-100  score >= 750

local PRIORITY = {
	monster = 500,
	captain = 500,
	witch = 500,
	sniper = 500,
	disabler = 200,
	far = 100,
	special = 100,
	elite = 100,
	shield = 50,
	horde = 20,
	enemy = 20,
}

local function _get_priority(breed_type, dist_sq, forward_bonus)
	local base = PRIORITY[breed_type] or 0
	local dist_bias = 1 / (1 + dist_sq * 0.05)

	return base + (dist_bias * 200) + (forward_bonus * 20)
end

-- keeps the per-cell cull sorts off the heap
local function _cull_sort(a, b)
	if a.score == b.score then
		return a.dist_sq < b.dist_sq
	end
	return a.score > b.score
end

local function _depth_keep(i, score)
	if i <= 4 then
		return true
	end

	-- nothing past the last layer qualifies on score alone, it can only survive as an aimed unit
	if i > 100 then
		return false
	end

	if i <= 6 then
		return score >= 200
	end

	if i <= 8 then
		return score >= 400
	end

	return score >= 750
end

local fs = mod.frame_settings

-----------------------------------------------------------------------
-- preload resources + reset caches on game state change
-----------------------------------------------------------------------
mod.on_game_state_changed = function(state, state_name)
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

	if mod.DEBUG and mod.anim_db_dirty then
		--mod.save_anim_db()
	end
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
mod.loaded = false

mod.on_unload = function()
	if mod.editor then
		mod.editor.close_all()
	end

	mod.clear_caches()
	mod.loaded = false
end

mod.on_disabled = function()
	if mod.editor then
		mod.editor.close_all()
	end
end

mod.open_editor = function()
	local editor = mod.editor

	if not editor then
		return
	end

	if editor.is_open() and editor.is_writing() then
		return
	end

	editor.toggle()
end

mod.on_all_mods_loaded = function()
	mod.migrate_override_settings()

	check_selected_font()

	mod.clear_caches()

	mod.init_healthbar_defaults()
	mod.update_breed_colours()
	mod.update_breed_icons()

	mod.build_frame_settings()

	local outline_settings = require("scripts/settings/outline/outline_settings")
	mod.apply_enemy_outlines(outline_settings)

	mod.load_toggled_debuffs_state()
	mod.load_debuff_colours()

	mod.load_anim_db()

	mod.dmf = get_mod("DMF")

	if mod.editor then
		mod.editor.register()
	end

	mod.loaded = true
end

mod.on_settings_reset = function()
	mod.reset_all_overrides()
end

mod.custom_localize = function(loc_string)
	if mod and mod.loaded then
		return mod:localize(loc_string) or ""
	else
		return ""
	end
end

local EnemyImprovedTemplate =
	mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/templates/enemies_improved_template")
mod.editor = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/editor/ei_editor")

local function add_custom_templates(self)
	if EnemyImprovedTemplate then
		if not self._marker_templates[EnemyImprovedTemplate.name] then
			self._marker_templates[EnemyImprovedTemplate.name] = EnemyImprovedTemplate
		end
	end
end

mod:hook_safe(CLASS.HudElementWorldMarkers, "init", function(self)
	add_custom_templates(self)
end)

mod:hook(CLASS.HudElementWorldMarkers, "_unregister_marker", function(previous_hook, self, marker)
	local widget = marker and marker.widget

	previous_hook(self, marker)

	if widget then
		local widgets_by_name = self._widgets_by_name

		if widgets_by_name then
			local widget_name = marker.widget_name

			if not widget_name and marker.id then
				widget_name = "marker_widget_id_" .. marker.id
			end

			if widget_name and widgets_by_name[widget_name] == widget then
				widgets_by_name[widget_name] = nil
			else
				for name, w in pairs(widgets_by_name) do
					if w == widget then
						widgets_by_name[name] = nil
						break
					end
				end
			end
		end

		local widgets = self._widgets

		if widgets then
			for i = 1, #widgets do
				if widgets[i] == widget then
					table_remove(widgets, i)
					break
				end
			end
		end
	end
end)

mod.aimed_unit = {}
mod.tagged_units = {}
mod.crosshair_target = nil
mod.crosshair_aimed = {}
mod._periodic_cache_clear_timer = 0

if mod.DEBUG then
	mod.mem_profile.track("mod.aimed_unit", mod.aimed_unit)
	mod.mem_profile.track("mod.tagged_units", mod.tagged_units)
	mod.mem_profile.track("mod.crosshair_aimed", mod.crosshair_aimed)
end

mod:hook_safe(CLASS.HudElementWorldMarkers, "update", function(self, dt, t)
	add_custom_templates(self)

	if fs.only_in_meatgrinder then
		local current_level = Managers.state.mission and Managers.state.mission:mission()

		if current_level and current_level.game_mode_name and current_level.game_mode_name == "shooting_range" then
			mod.enabled = true
		else
			mod.enabled = false
		end
	else
		mod.enabled = true
	end

	if mod.enabled then
		if fs.markers_show_only_aimed then
			mod.do_crosshair_hitscan()

			table_clear(mod.aimed_unit)
			mod.do_aim_raycast()

			for unit in next, mod.crosshair_aimed do
				mod.aimed_unit[unit] = true
			end
		end

		if fs.only_tagged_enemies then
			mod.do_tagged_scan()
		end

		self._update_time = (self._update_time or 0) + dt

		if self._update_time > fs.general_throttle_rate then
			self._update_time = 0
			mod.update_enemies(dt, t)
		end

		local has_specials = fs.outline_specials_enable or fs.marker_specials_enable or fs.healthbar_specials_enable
		local has_stagger = fs.outline_stagger_horde_enable or fs.outline_stagger_enable
		if has_specials or has_stagger then
			local pulse_interval = fs.special_attack_pulse_speed or 0.2
			local stagger_interval = fs.stagger_pulse_speed or 0.2
			local stagger_horde = fs.outline_stagger_horde_enable
			local stagger_normal = fs.outline_stagger_enable

			for _, entry in next, mod.enemy_cache do
				-- special attack pulse
				if has_specials then
					if entry.special_attack_imminent then
						entry._pulse_timer = (entry._pulse_timer or 0) + dt
						if entry._pulse_timer >= pulse_interval then
							mod.pulse_enemy_outline(entry)
							entry._pulse_timer = 0
						end
					elseif entry.alert_outline then
						-- only bother when there is actually an outline to strip
						mod.remove_alert_outline(entry)
					end
				end

				-- stagger pulse
				if has_stagger then
					if (entry.is_horde and stagger_horde) or (not entry.is_horde and stagger_normal) then
						if entry.staggered then
							entry._pulse_timer = (entry._pulse_timer or 0) + dt
							if entry._pulse_timer >= stagger_interval then
								mod.pulse_enemy_outline(entry)
								entry._pulse_timer = 0
							end
						elseif entry.stagger_outline then
							mod.remove_stagger_outline(entry)
						end
					elseif entry.stagger_outline then
						mod.remove_stagger_outline(entry)
					end
				end
			end
		end

		self._outline_safety_timer = (self._outline_safety_timer or 0) + dt
		if self._outline_safety_timer >= 2 then
			self._outline_safety_timer = 0
			mod.outline_safety_cleanup()
		end

		self._marker_cleanup_timer = (self._marker_cleanup_timer or 0) + dt
		if self._marker_cleanup_timer >= 1 then
			self._marker_cleanup_timer = 0
			mod.cleanup_orphaned_markers()
		end

		-- Hide default health bars if custom healthbars are enabled!
		local markers = self._markers
		if not markers or #markers == 0 then
			return
		end

		local hb_enabled = fs.healthbar_enable
		local hide_skulls = fs.remove_tag_skull

		if hb_enabled or hide_skulls then
			local flags = (hb_enabled and 1 or 0) + (hide_skulls and 2 or 0)

			for i = 1, #markers do
				local marker = markers[i]
				local template = marker and marker.template

				if template then
					if template._ei_suppress_flags ~= flags then
						local name = template.name

						-- REMOVE BASE HEALTHBAR
						template._ei_suppress_hb = hb_enabled
							and name ~= nil
							and name ~= "enemies_improved"
							and string.find(name, "damage_indicator", 1, true) ~= nil

						-- REMOVE THREAT SKULLS
						template._ei_suppress_skull = hide_skulls
							and marker.type ~= nil
							and string.find(marker.type, "unit_threat", 1, true) ~= nil

						template._ei_suppress_flags = flags
					end

					if template._ei_suppress_hb or template._ei_suppress_skull then
						marker.draw = false
						marker.alpha_multiplier = 0
					end
				end
			end
		end

		mod._periodic_cache_clear_timer = mod._periodic_cache_clear_timer + dt
		if mod._periodic_cache_clear_timer >= 60 then
			mod._periodic_cache_clear_timer = 0
			mod.clear_caches()
		end
	end
end)

mod.get_marker_by_id = function(id)
	local markers_by_id = mod._markers_by_id

	if not markers_by_id then
		local ui_manager = Managers.ui
		local hud = ui_manager and ui_manager:get_hud()
		local world_markers = hud and hud:element("HudElementWorldMarkers")
		markers_by_id = world_markers and world_markers._markers_by_id
	end

	if markers_by_id then
		return markers_by_id[id]
	else
		return nil
	end
end

local function _trigger_remove_marker(id)
	if id then
		Managers.event:trigger("remove_world_marker", id)
	end
end

mod.force_remove_unit_markers = function(unit)
	if not unit then
		return
	end

	local entry = mod.enemy_cache[unit]
	if entry then
		if entry.marker then
			_trigger_remove_marker(entry.marker.id)
		end

		mod.enemy_markers[unit] = nil
		mod.enemy_healthbars[unit] = nil
		mod.enemy_debuffs[unit] = nil

		local cluster = mod.get_horde_cluster_for_unit(unit)
		if cluster and cluster.rep_unit == unit then
			cluster._healthbar_created = false
			cluster._healthbar_marker_id = nil
		end

		entry._ei_marker_created = false
		entry._ei_marker_pending = nil
		entry.marker = nil

		mod.disable_enemy_outlines(unit, entry)
		mod.remove_alert_outline(entry)
		mod.remove_stagger_outline(entry)
	end
end

mod.remove_all_ei_markers = function()
	local ui_manager = Managers.ui
	local hud = ui_manager and ui_manager:get_hud()
	local world_markers = hud and hud:element("HudElementWorldMarkers")
	if not world_markers then
		return
	end

	local event = Managers.event

	local by_type = world_markers._markers_by_type
	local ei_list = by_type and by_type["enemies_improved"]
	if ei_list then
		local ids = {}
		local n = 0
		for i = 1, #ei_list do
			local m = ei_list[i]
			local id = m and (m.id or m)
			if id then
				n = n + 1
				ids[n] = id
			end
		end
		for i = 1, n do
			event:trigger("remove_world_marker", ids[i])
		end
	end

	table_clear(mod.enemy_markers)
	table_clear(mod.enemy_healthbars)
	table_clear(mod.enemy_debuffs)

	local widgets_by_name = world_markers._widgets_by_name
	local markers_by_id = world_markers._markers_by_id

	if widgets_by_name and markers_by_id then
		local prefix = "marker_widget_id_"

		for name, w in pairs(widgets_by_name) do
			if type(name) == "string" and string.sub(name, 1, #prefix) == prefix then
				local id = tonumber(string.sub(name, #prefix + 1))
				if id and not markers_by_id[id] then
					widgets_by_name[name] = nil
				end
			end
		end
	end
end

mod.cleanup_orphaned_markers = function()
	local to_remove = {}
	local count = 0

	for unit, marker_id in pairs(mod.enemy_markers) do
		if not mod.enemy_cache[unit] then
			count = count + 1
			to_remove[count] = unit
		end
	end

	for unit, marker_id in pairs(mod.enemy_healthbars) do
		if not mod.enemy_markers[unit] and not mod.enemy_cache[unit] then
			count = count + 1
			to_remove[count] = unit
		end
	end

	for unit, marker_id in pairs(mod.enemy_debuffs) do
		if not mod.enemy_markers[unit] and not mod.enemy_cache[unit] then
			count = count + 1
			to_remove[count] = unit
		end
	end

	for i = 1, count do
		mod.force_remove_unit_markers(to_remove[i])
	end
end

-----------------------------------------------------------------------
-- Enemy scanning
-----------------------------------------------------------------------
local function _is_finite_number(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function _is_finite_vector3(v)
	return v ~= nil and _is_finite_number(v.x) and _is_finite_number(v.y) and _is_finite_number(v.z)
end

-- broadphase now has a hard limit of 50m, so if you have more than 50m distance, I now need to do a ring of offset queries
mod.query_broadphase_covered = function(broadphase, from_pos, radius, results, side_names)
	if not broadphase or not broadphase.query then
		return 0
	end

	if not _is_finite_vector3(from_pos) then
		return 0
	end

	if not _is_finite_number(radius) or radius <= 0 then
		return 0
	end

	if type(results) ~= "table" or not side_names then
		return 0
	end

	if radius <= BROADPHASE_CELL_RADIUS then
		local hits = broadphase.query(broadphase, from_pos, radius, results, side_names)
		return _is_finite_number(hits) and hits or 0
	end

	local scratch = mod._broadphase_scratch
	local seen = mod._broadphase_seen

	if not scratch or not seen then
		return 0
	end

	table_clear(seen)

	local total = 0

	local function collect(centre, query_radius)
		if not _is_finite_vector3(centre) or not _is_finite_number(query_radius) or query_radius <= 0 then
			return
		end

		table_clear(scratch)

		local hits = broadphase.query(broadphase, centre, query_radius, scratch, side_names)

		if not _is_finite_number(hits) then
			return
		end

		for i = 1, hits do
			local unit = scratch[i]

			if unit and not seen[unit] then
				seen[unit] = true
				total = total + 1
				results[total] = unit
			end
		end
	end

	collect(from_pos, BROADPHASE_CELL_RADIUS)

	local outer_radius = math_min(radius, BROADPHASE_CELL_RADIUS)
	local spacing = BROADPHASE_LATTICE_SPACING

	for i = 1, #BROADPHASE_LATTICE_OFFSETS do
		local offset = BROADPHASE_LATTICE_OFFSETS[i]

		if offset and _is_finite_number(offset[1]) and _is_finite_number(offset[2]) then
			collect(
				Vector3(from_pos.x + offset[1] * spacing, from_pos.y + offset[2] * spacing, from_pos.z),
				outer_radius
			)
		end
	end

	return total
end

mod.scan_enemies = function()
	table_clear(_horde_units_all)
	table_clear(_cull_pool)

	local local_player = Managers_player:local_player(1)
	if not local_player then
		return
	end

	local player_unit = local_player.player_unit
	if not player_unit or not mod.detect_alive(player_unit) then
		return
	end

	mod.set_is_ads(player_unit)

	local wp = Unit.world_position(player_unit, 1, _player_pos_vec)
	local current_pos = wp and Vector3(wp.x, wp.y, wp.z) or nil

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
	local range = mod.frame_settings.draw_distance_broadphase or mod.frame_settings.draw_distance
	local range_sq = range * range

	local results = mod._broadphase_results
	table_clear(results)

	local num_hits = mod.query_broadphase_covered(broadphase, from_pos, range, results, enemy_side_names)

	if num_hits == 0 then
		return
	end

	local cache = mod.enemy_cache

	for _, data in next, cache do
		if not data._dead_at then
			data.seen = false
		end
	end

	for key, list in pairs(_cull_cells) do
		for i = 1, #list do
			local e = list[i]
			_cull_pool_count = _cull_pool_count + 1
			_cull_pool[_cull_pool_count] = e
		end
		table_clear(list)
	end
	table_clear(_cull_cells)

	if _cull_pool_count > 512 then
		for i = 513, _cull_pool_count do
			_cull_pool[i] = nil
		end
		_cull_pool_count = 512
	end

	local world = Managers.world:world("level_world")
	local physics_world_cache = world and World.get_data(world, "physics_world")
	local camera_forward = mod.get_camera_forward()
	local player_los_pos = mod.get_los_origin and mod.get_los_origin(player_unit)

	for i = 1, num_hits do
		local unit = results[i]

		if unit and HEALTH_ALIVE[unit] and Unit_alive(unit) then
			local pos = Unit.world_position(unit, 1, _pos_vec)

			local los_ok = false

			if pos then
				local edx = current_pos.x - pos.x
				local edy = current_pos.y - pos.y
				local edz = current_pos.z - pos.z

				if edx * edx + edy * edy + edz * edz > range_sq then
					goto skip_breed
				end
			end

			local forward_bonus = 1
			if camera_forward then
				forward_bonus = mod.get_forward_dot(player_unit, unit, camera_forward)
			end

			local is_crosshair_target = mod.crosshair_aimed[unit] == true

			-- VIEW CONE FILTER
			if forward_bonus <= 0 and not is_crosshair_target then
				mod.force_remove_unit_markers(unit)

				if mod._cleanup_unit_health_data then
					mod._cleanup_unit_health_data(unit)
				end

				cache[unit] = nil
				mod.marked_dead[unit] = nil
				goto skip_breed
			end

			-- LOS FILTER
			if physics_world_cache and not is_crosshair_target then
				if not mod.has_line_of_sight(player_unit, unit, physics_world_cache, player_los_pos) then
					mod.force_remove_unit_markers(unit)

					if mod._cleanup_unit_health_data then
						mod._cleanup_unit_health_data(unit)
					end

					cache[unit] = nil
					mod.marked_dead[unit] = nil
					goto skip_breed
				end

				los_ok = true
			end

			local entry = cache[unit]

			if not pos then
				pos = Unit.world_position(unit, 1, _pos_vec)
				if not pos then
					goto skip_breed
				end
			end

			local px, py, pz = pos.x, pos.y, pos.z
			local dx = px - current_pos.x
			local dy = py - current_pos.y
			local dz = pz - current_pos.z
			local dist_sq = dx * dx + dy * dy + dz * dz

			local unit_data_ext = ScriptUnit_has_extension(unit, "unit_data_system")
			if not unit_data_ext then
				goto skip_breed
			end

			local breed = unit_data_ext:breed()

			local breed_type = entry and entry.breed_type or mod.find_breed_category(unit)

			-- build animation map for this enemy
			if mod.DEBUG then
				--mod.init_breed_anim_db(unit, breed, breed.name)
			end

			-- collect ALL horde units BEFORE culling
			local breed_tags = breed and breed.tags
			if breed_tags and (breed_tags.horde or breed_tags.roamer) then
				_horde_units_all[#_horde_units_all + 1] = unit
			end

			-- DO NOT ADD WIDGETS FOR THESE BREEDS:
			if breed.name == "sand_vortex" or breed.name == "nurgle_flies" or breed.name == "attack_valkyrie" then
				goto skip_breed
			end

			if fs.spatial_culling then
				local gx = math_floor(px * INV_CULL_CELL)
				local gy = math_floor(py * INV_CULL_CELL)

				local score = _get_priority(breed_type, dist_sq, forward_bonus)

				if entry then
					score = score + 5 -- small boost if already has a marker. Just to make hordes act a little more stable.
				end

				local key = gx * 73856093 + gy * 19349663
				local list = _cull_cells[key]

				if not list then
					list = {}
					_cull_cells[key] = list
				end

				local e = _cull_pool[_cull_pool_count]
				if e then
					_cull_pool[_cull_pool_count] = nil
					_cull_pool_count = _cull_pool_count - 1
				else
					e = {}
				end
				e.unit = unit
				e.score = score
				e.dist_sq = dist_sq
				e.entry = entry
				e.unit_data_ext = unit_data_ext
				e.breed = breed
				e.breed_type = breed_type
				e.pos = Vector3(px, py, pz)
				e.los_ok = los_ok
				list[#list + 1] = e

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
						breed_name = breed and breed.name,
						breed_type = breed_type,

						special_attack_event = nil,
						special_attack_imminent = false,
						special_attack_timer = 0,

						-- outlines
						alert_outline = false,
						stagger_outline = false,
						outline_name = nil,

						alert_healthbar = false,

						_ei_marker_created = false,
						_los_ok = los_ok,
					}

					mod.marked_dead[unit] = nil
				else
					entry.seen = true
					entry.pos = Vector3(px, py, pz)
					entry._los_ok = los_ok
					mod.marked_dead[unit] = nil
					entry._dead_at = nil
				end
			end
			::skip_breed::
		end
	end

	if fs.spatial_culling then
		for _, list in pairs(_cull_cells) do
			local num_in_list = #list

			if num_in_list > 1 then
				table.sort(list, _cull_sort)
			end

			for i = 1, num_in_list do
				local data = list[i]
				local unit = data.unit
				local keep = _depth_keep(i, data.score)

				if not keep then
					keep = mod.crosshair_aimed[unit] == true
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
							breed_name = data.breed and data.breed.name,
							breed_type = data.breed_type,

							_priority_score = data.score,
							pos = data.pos,
							_ei_marker_created = false,
							_los_ok = data.los_ok,
						}
					else
						entry.seen = true
						entry._priority_score = data.score
						entry._los_ok = data.los_ok

						if entry.pos ~= data.pos then
							entry.pos = data.pos
							data.pos = nil
						end

						entry._dead_at = nil
					end

					mod.marked_dead[unit] = nil
				else
					-- culled
					mod.force_remove_unit_markers(unit)
				end

				data.entry = nil
				data.unit_data_ext = nil
				data.breed = nil
				data.pos = nil
				data.los_ok = nil
				_cull_pool[_cull_pool_count + 1] = data
				_cull_pool_count = _cull_pool_count + 1
			end

			table_clear(list)
		end
	end
end

-----------------------------------------------------------------------
-- Horde clustering helpers
-----------------------------------------------------------------------

local CLUSTER_RADIUS = 10
local CLUSTER_RADIUS_SQ = CLUSTER_RADIUS * CLUSTER_RADIUS
local HASH_CELL_SIZE = CLUSTER_RADIUS
local INV_HASH_CELL_SIZE = 1 / HASH_CELL_SIZE
local HORDE_MIN_UNITS_FOR_CLUSTER = fs.hb_horde_clusters_size or 8

local function _build_horde_clusters(units, num_units)
	table_clear(_horde_clusters)
	table_clear(_horde_cluster_by_unit)

	HORDE_MIN_UNITS_FOR_CLUSTER = fs.hb_horde_clusters_size

	local player = Managers.player:local_player(1)
	if not player then
		return
	end
	local player_unit = player.player_unit
	if not player_unit or not mod.detect_alive(player_unit) then
		return
	end

	if num_units < HORDE_MIN_UNITS_FOR_CLUSTER then
		return
	end

	local clusters = _horde_clusters
	local spatial = _spatial_hash
	local visited = _visited

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
				local pos

				if entry and entry.pos then
					pos = entry.pos
				else
					local wp = Unit.world_position(unit, 1, _pos_vec)
					pos = wp and Vector3(wp.x, wp.y, wp.z) or nil
					if entry then
						entry.pos = pos
					end
				end

				if pos then
					local gx = math_floor(pos.x * INV_HASH_CELL_SIZE)
					local gy = math_floor(pos.y * INV_HASH_CELL_SIZE)
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

			local z_samples = _z_samples
			table_clear(z_samples)

			local cluster_units = {}
			local queue = _bfs_queue
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
						e.pos = Vector3(cx, cy, cz)
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
													oe.pos = Vector3(op.x, op.y, op.z)
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

				local total_current = 0
				local total_max = 0

				for j = 1, #cluster_units do
					local u = cluster_units[j]
					local e = mod.enemy_cache[u]

					if e and mod.detect_alive(u) then
						local he = e.health_ext
						if he then
							local ok, v = pcall(he.current_health, he)
							if ok then
								total_current = total_current + (v or 0)
							end
							ok, v = pcall(he.max_health, he)
							if ok then
								total_max = total_max + (v or 0)
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
	local idx = _horde_cluster_by_unit[unit]
	return idx and _horde_clusters[idx] or nil
end

-----------------------------------------------------------------------
-- Enemy markers
-----------------------------------------------------------------------

mod.get_time = function()
	local tm = Managers and Managers.time
	local fallback = os.clock() or 0
	if tm then
		if tm:has_timer("gameplay") then
			return tm:time("gameplay") or fallback
		end
		if tm:has_timer("ui") then
			return tm:time("ui") or fallback
		end
		if tm:has_timer("main") then
			return tm:time("main") or fallback
		end
	end
	return fallback
end

mod.ts = function()
	return string.format("[%.3f]", mod.get_time())
end

function string.starts(String, Start)
	return string.sub(String, 1, string.len(Start)) == Start
end

local _units_to_remove = {}

mod.remove_dead = function()
	table_clear(_units_to_remove)

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
	local fs = mod.frame_settings
	local max_dist_sq = (fs.draw_distance or 50) ^ 2
	local keep_dead_window = fs.hb_show_dps or fs.widget_removal_delay > 0
	local breed_dist_enabled = fs.breed_dist_enabled
	local breed_dist_value = fs.breed_dist_value
	local dead_window = math.max(fs.damage_number_duration or 0, fs.widget_removal_delay or 0)
	local t = mod.get_time()
	local mark_dead = false
	local remove_table = _units_to_remove
	local clusters_enable = fs.horde_clusters_enable

	-- Main loop
	for unit, entry in next, mod.enemy_cache do
		local remove = false
		local alive = mod.detect_alive(unit)

		-- Dead check
		if not alive then
			if keep_dead_window then
				if not entry._dead_at then
					entry._dead_at = t
				end
			else
				remove = true
				mark_dead = true
			end
		else
			local health_extension = entry and entry.health_ext
			if health_extension then
				local ok, pct = pcall(health_extension.current_health_percent, health_extension)
				if ok and pct <= 0 then
					if keep_dead_window then
						if not entry._dead_at then
							entry._dead_at = t
						end
					else
						remove = true
						mark_dead = true
					end
				end
			else
				remove = true
				mark_dead = true
			end
		end

		if not remove and entry._dead_at then
			if dead_window > 0 and t - entry._dead_at > dead_window then
				remove = true
				mark_dead = true
			end
		end

		-- Distance check
		if not remove and player_pos and alive then
			local wp = Unit.world_position(unit, 1, _pos_vec)
			if wp then
				entry.pos = Vector3(wp.x, wp.y, wp.z)
			end
			local pos = entry.pos

			if pos then
				local dx = pos.x - player_pos.x
				local dy = pos.y - player_pos.y
				local dz = pos.z - player_pos.z
				local dist_sq = dx * dx + dy * dy + dz * dz
				local breed_name = entry.breed_name
				local effective_max_dist_sq = max_dist_sq
				if breed_name and breed_dist_enabled[breed_name] then
					local ind_dist = breed_dist_value[breed_name]
					if ind_dist then
						effective_max_dist_sq = ind_dist * ind_dist
					end
				end

				if dist_sq > effective_max_dist_sq then
					remove = true

					-- disable outlines too
					mod.disable_enemy_outlines(unit, entry)
					mod.remove_alert_outline(entry)
					mod.remove_stagger_outline(entry)
				end
			end
		end

		if clusters_enable then
			local cluster = mod.get_horde_cluster_for_unit(unit)
			if cluster and cluster.rep_unit == unit then
				cluster._healthbar_created = false
				cluster._healthbar_marker_id = nil
			end
		end

		if remove then
			local id
			id = mod.enemy_markers[unit]
			if id then
				Managers.event:trigger("remove_world_marker", id)
			end
			id = mod.enemy_healthbars[unit]
			if id then
				Managers.event:trigger("remove_world_marker", id)
			end
			id = mod.enemy_debuffs[unit]
			if id then
				Managers.event:trigger("remove_world_marker", id)
			end

			remove_table[#remove_table + 1] = unit
		end
	end

	-- Cleanup
	for _, unit in next, remove_table do
		if mark_dead then
			mod.marked_dead[unit] = true
		else
			mod.marked_dead[unit] = nil
		end

		mod.enemy_healthbars[unit] = nil
		mod.enemy_debuffs[unit] = nil
		mod.enemy_markers[unit] = nil

		if mod._cleanup_unit_health_data then
			mod._cleanup_unit_health_data(unit)
		end

		mod.enemy_cache[unit] = nil
	end
end

mod.is_horde = function(unit)
	if Unit_alive(unit) then
		local tags = mod.get_breed_tags(unit)
		local is_horde = tags and (tags.horde or tags.roamer) or false
		if mod.is_vanguard(unit) then
			is_horde = false
		end
		return is_horde
	else
		return false
	end
end

-----------------------------------------------------------------------
-- Cache clearing
-----------------------------------------------------------------------

mod.clear_caches = function()
	mod.remove_all_ei_markers()

	table_clear(mod._broadphase_results)
	table_clear(mod.source_unit_cache)
	table_clear(mod.enemy_markers)
	table_clear(mod.enemy_healthbars)
	table_clear(mod.enemy_debuffs)
	table_clear(mod.enemy_cache)
	table_clear(mod.marked_dead)

	--table_clear(mod.latest_damaged_enemies)
	--table_clear(mod.latest_damaged_enemies_set)
	table_clear(mod.aimed_unit)
	table_clear(mod.tagged_units)
	table_clear(mod.crosshair_aimed)
	mod.crosshair_target = nil

	if mod._clear_unit_health_data then
		mod._clear_unit_health_data()
	end

	table_clear(_enemy_units_temp)
	table_clear(_horde_clusters)
	table_clear(_horde_cluster_by_unit)

	table_clear(_spatial_hash)
	table_clear(_visited)
	table_clear(_z_samples)
	table_clear(_bfs_queue)

	table_clear(_cull_pool)
	table_clear(_cull_cells)
	table_clear(_units_to_remove)

	mod._markers_by_id = nil
	mod._world_markers = nil

	if mod._clear_outline_caches then
		mod._clear_outline_caches()
	end
end

mod.update_horde_clusters = function(temp, to_process)
	if fs.horde_clusters_enable then
		_build_horde_clusters(temp, to_process)
	else
		table_clear(_horde_clusters)
		table_clear(_horde_cluster_by_unit)
	end
end

mod.get_crosshair_shooting_vector = function(hud)
	local player_extensions = hud and hud:player_extensions()

	if player_extensions then
		local unit_data_extension = player_extensions.unit_data
		local first_person_extension = player_extensions.first_person
		local weapon_extension = player_extensions.weapon

		if unit_data_extension and first_person_extension and weapon_extension then
			local first_person_unit = first_person_extension:first_person_unit()

			if first_person_unit and Unit_alive(first_person_unit) then
				local shoot_position = Unit.world_position(first_person_unit, 1)
				local shoot_rotation = Unit.world_rotation(first_person_unit, 1)

				shoot_rotation = Recoil.apply_weapon_recoil_rotation(
					weapon_extension:recoil_template(),
					unit_data_extension:read_component("recoil"),
					unit_data_extension:read_component("movement_state"),
					unit_data_extension:read_component("locomotion"),
					unit_data_extension:read_component("inair_state"),
					shoot_rotation
				)

				shoot_rotation = Sway.apply_sway_rotation(
					weapon_extension:sway_template(),
					unit_data_extension:read_component("sway"),
					shoot_rotation
				)

				return shoot_position, Quaternion_forward(shoot_rotation)
			end
		end
	end

	local camera = hud and hud:player_camera()

	if camera then
		return Camera.local_position(camera), Quaternion_forward(Camera.local_rotation(camera))
	end

	return nil, nil
end

mod.do_crosshair_hitscan = function()
	mod.crosshair_target = nil
	table_clear(mod.crosshair_aimed)

	local ui_manager = Managers.ui
	local hud = ui_manager and ui_manager:get_hud()
	if not hud then
		return
	end

	local world = Managers.world:world("level_world")
	local physics_world = world and World.get_data(world, "physics_world")
	if not physics_world then
		return
	end

	local player = Managers.player:local_player(1)
	local player_unit = player and player.player_unit
	if not player_unit or not mod.detect_alive(player_unit) then
		return
	end

	local shoot_position, shoot_direction = mod.get_crosshair_shooting_vector(hud)
	if not shoot_position or not shoot_direction then
		return
	end

	local max_dist = fs.draw_distance_broadphase or fs.draw_distance

	local hits = PhysicsWorld.raycast(
		physics_world,
		shoot_position,
		shoot_direction,
		max_dist,
		"all",
		"max_hits",
		64,
		"collision_filter",
		"filter_player_character_shooting_raycast"
	)

	if not hits then
		return
	end
	local closest_dist = math.huge
	local num_hits = #hits

	for i = 1, num_hits do
		local hit = hits[i]
		local hit_dist = hit[2]
		local hit_actor = hit[4]
		local hit_unit = hit_actor and Actor_unit(hit_actor)

		if hit_dist and hit_dist > 0.1 and hit_unit ~= player_unit and hit_dist < closest_dist then
			closest_dist = hit_dist
		end
	end

	if closest_dist == math.huge then
		return
	end

	for i = 1, num_hits do
		local hit = hits[i]
		local hit_dist = hit[2]
		local hit_actor = hit[4]
		local hit_unit = hit_actor and Actor_unit(hit_actor)

		if hit_unit and hit_unit ~= player_unit and hit_dist and hit_dist <= closest_dist + 0.05 then
			if HEALTH_ALIVE[hit_unit] and Unit_alive(hit_unit) then
				mod.crosshair_aimed[hit_unit] = true

				if not mod.crosshair_target then
					mod.crosshair_target = hit_unit
				end
			end
		end
	end
end

mod.do_aim_raycast = function()
	local ui_manager = Managers.ui
	local hud = ui_manager and ui_manager:get_hud()
	local world_markers = hud and hud:element("HudElementWorldMarkers")
	if not world_markers then
		return
	end

	local camera = world_markers:_get_camera()
	if not camera then
		return
	end

	local cam_pos = Camera.local_position(camera)
	local px, py, pz = cam_pos.x, cam_pos.y, cam_pos.z
	local forward = Quaternion.forward(Camera.local_rotation(camera))
	local cone_cos = math.cos(math.rad(fs.aim_cone_angle or 8))
	local draw_dist_sq = fs.draw_distance * fs.draw_distance

	for unit in pairs(mod.enemy_cache) do
		if Unit_alive(unit) then
			local enemy_pos = POSITION_LOOKUP[unit]
			if enemy_pos then
				local dx = enemy_pos.x - px
				local dy = enemy_pos.y - py
				local dz = (enemy_pos.z - pz) * 0.3
				local dist_sq = dx * dx + dy * dy + dz * dz
				local entry = mod.enemy_cache[unit]
				local effective_max_dist_sq = draw_dist_sq
				local breed_name = entry and entry.breed_name
				if breed_name and fs.breed_dist_enabled and fs.breed_dist_enabled[breed_name] then
					local ind_dist = fs.breed_dist_value[breed_name]
					if ind_dist then
						effective_max_dist_sq = ind_dist * ind_dist
					end
				end

				if dist_sq < effective_max_dist_sq and dist_sq > 0 then
					local dist = math.sqrt(dist_sq)
					local dot = (dx * forward.x + dy * forward.y + dz * forward.z) / dist
					if dot > cone_cos then
						mod.aimed_unit[unit] = true
					end
				end
			end
		end
	end
end

-- Build a set of units that are currently tagged via the smart-tag system.
mod.do_tagged_scan = function()
	table_clear(mod.tagged_units)

	local smart_tag_system = Managers.state.extension:system("smart_tag_system")
	if not smart_tag_system then
		return
	end

	for unit in next, mod.enemy_cache do
		if Unit_alive(unit) then
			local tag_id = smart_tag_system:unit_tag_id(unit)
			if tag_id then
				mod.tagged_units[unit] = true
			end
		end
	end
end

-----------------------------------------------------------------------
-- Main update orchestration
-----------------------------------------------------------------------

mod.update_enemies = function(dt, t)
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
	local wp = player_unit and Unit.world_position(player_unit, 1)
	local player_pos = wp and Vector3(wp.x, wp.y, wp.z) or nil

	local base_dist_sq = fs.draw_distance * fs.draw_distance
	local breed_dist_enabled = fs.breed_dist_enabled
	local breed_dist_value = fs.breed_dist_value
	local outlines_enable = fs.outlines_enable
	local healthbars_enable = fs.healthbar_enable or fs.show_damage_numbers
	local debuffs_enable = fs.debuff_enable

	local ui_manager = Managers_ui
	local hud = ui_manager and ui_manager:get_hud()
	local world_markers = hud and hud:element("HudElementWorldMarkers")
	mod._markers_by_id = world_markers and world_markers._markers_by_id

	-- go through enemy_cache and perform updates...
	for i = 1, to_process do
		local unit = temp[i]
		local entry = mod.enemy_cache[unit]

		if entry then
			if player_pos and Unit_alive(unit) then
				local wp = Unit.world_position(unit, 1, _pos_vec)
				if wp then
					entry.pos = Vector3(wp.x, wp.y, wp.z)
				else
					goto continue_enemy_loop
				end
				local pos = entry.pos

				local dx = pos.x - player_pos.x
				local dy = pos.y - player_pos.y
				local dz = pos.z - player_pos.z
				local dist_sq = dx * dx + dy * dy + dz * dz

				local breed_name = entry.breed_name
				local effective_max_dist_sq = base_dist_sq
				if breed_name and breed_dist_enabled[breed_name] then
					local ind_dist = breed_dist_value[breed_name]
					if ind_dist then
						effective_max_dist_sq = ind_dist * ind_dist
					end
				end

				if dist_sq > effective_max_dist_sq then
					goto continue_enemy_loop
				end
			end

			if entry.seen then
				mod.update_enemy_markers(entry, t)

				if outlines_enable then
					mod.update_enemy_outlines(entry, player_unit)
				end

				if healthbars_enable then
					mod.update_enemy_healthbars(entry, t)
				end

				if debuffs_enable then
					mod.update_enemy_debuffs(entry, t)
				end

				mod.update_special_attack_detection(entry)
			end
		end

		::continue_enemy_loop::
	end

	-- Apply distance / stacking fade to all active markers
	if fs.enable_depth_fading then
		mod.apply_marker_fade()
	end

	mod._markers_by_id = nil
	mod.remove_dead()
end

mod.get_unit_breed = function(unit)
	if not mod.detect_alive(unit) then
		return nil
	end

	local unit_data_extension = ScriptUnit_has_extension(unit, "unit_data_system")

	if not unit_data_extension then
		return nil
	end

	return unit_data_extension:breed()
end

mod.get_breed_tags = function(unit)
	local breed = mod.get_unit_breed(unit)

	if breed and breed.tags then
		return breed.tags
	end

	return nil
end

mod.find_breed_category = function(unit)
	if unit then
		if mod.is_vanguard(unit) then
			return "shield"
		end

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

-- Returns true if the unit is a weakened boss (spawned with reduced max health).
mod.is_weakened = function(unit, breed)
	local breed = breed or mod.get_unit_breed(unit)

	if not breed or not breed.is_boss or breed.ignore_weakened_boss_name then
		return false
	end

	local health_extension = ScriptUnit_has_extension(unit, "health_system")

	if not health_extension then
		return false
	end

	local ok, max_health = pcall(health_extension.max_health, health_extension)

	if not ok or not max_health then
		return false
	end

	local difficulty = Managers.state.difficulty

	if not (breed.name and difficulty) then
		return false
	end

	local initial_max_health = math.floor(difficulty:get_minion_max_health(breed.name))

	if max_health < initial_max_health then
		return true
	end

	local ok_havoc, parsed_havoc = pcall(function()
		return difficulty:get_parsed_havoc_data()
	end)

	if ok_havoc and parsed_havoc then
		local ok_game_mode, game_mode = pcall(function()
			return Managers.state.game_mode:game_mode()
		end)

		if ok_game_mode and game_mode and game_mode.extension then
			local ok_havoc_ext, havoc_extension = pcall(function()
				return game_mode:extension("havoc")
			end)

			if ok_havoc_ext and havoc_extension then
				local ok_value, havoc_health_override_value = pcall(function()
					return havoc_extension:get_modifier_value("modify_monster_health")
				end)

				if ok_value and havoc_health_override_value then
					local multiplied_max_health = initial_max_health + initial_max_health * havoc_health_override_value

					if max_health < multiplied_max_health then
						return true
					end
				end
			end
		end
	end

	return false
end

local DEBUFF_CACHE_TTL = 0.2

-- Returns true if the unit currently has any active debuff tracked by the mod
mod.unit_has_active_debuff = function(unit, t)
	local debuffs = mod.debuffs

	if not unit or not debuffs then
		return false
	end

	local entry = mod.enemy_cache and mod.enemy_cache[unit]
	local cached = entry and entry._debuff_cached

	if cached ~= nil then
		local now = t or mod.get_time()
		if (now - (entry._debuff_cached_t or 0)) < DEBUFF_CACHE_TTL then
			return cached
		end
	end

	local result = false
	local buff_extension = ScriptUnit_has_extension(unit, "buff_system")

	if buff_extension then
		local ok, keywords = pcall(buff_extension.keywords, buff_extension)
		if ok and keywords then
			for name, _ in pairs(keywords) do
				if debuffs[name] then
					result = true
					break
				end
			end
		end

		if not result then
			local ok2, buffs = pcall(buff_extension.buffs, buff_extension)
			if ok2 and buffs then
				local num_buffs = #buffs

				for i = 1, num_buffs do
					local buff = buffs[i]
					local ok3, name = pcall(buff.template_name, buff)
					if ok3 and name and debuffs[name] then
						result = true
						break
					end
				end
			end
		end
	end

	if entry then
		entry._debuff_cached = result
		entry._debuff_cached_t = t or mod.get_time()
	end

	return result
end
