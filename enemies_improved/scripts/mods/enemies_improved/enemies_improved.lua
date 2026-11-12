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
local os_clock = os.clock

-- debug mode toggle!!!
mod.DEBUG = false

if mod.DEBUG then
	dbg_mod = mod
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

local FrameSettings = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/utils/frame_settings")
local SettingsFunctions = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/utils/settings_functions")
local DistanceFade = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/utils/fading")

local Outlines = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/outlines")
local Healthbars = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/healthbars")
local Markers = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/markers")
local Debuffs = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/debuffs")
local BossDebuffs = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/bossdebuffs")

local SpecialAttacks = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/specialattacks")
local CustomNames = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/custom_names")
local AnimationHandler =
	mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/modules/animations/animationhandler")
local HordeClusters = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/utils/horde_clusters")

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

mod.aimed_unit = {}
mod.tagged_units = {}
mod._periodic_cache_clear_timer = 0

local AIM_SCAN_INTERVAL = 0.15
local TAG_SCAN_INTERVAL = 0.15
local _aim_scan_timer = 0
local _tag_scan_timer = 0

local _outline_update_timer = 0
local OUTLINE_UPDATE_INTERVAL = 0.05

local MAX_ENEMIES_PER_FRAME = 100
local _enemy_units_temp = {}
local _last_enemy_index = 0
local _horde_units_all = {}
local _cull_cells = {}

local CULL_CELL_SIZE = 1
local INV_CULL_CELL = 1 / CULL_CELL_SIZE
local MAX_PER_CELL = 3

local MAX_ACTIVE_ENEMIES = mod.frame_settings.max_active_enemies or 20

local AIMED_PRIORITY_BONUS = 100000
local TAGGED_PRIORITY_BONUS = 5000
local CLUSTER_REP_PRIORITY_BONUS = 2000
local EXISTING_PRIORITY_BONUS = 100

local _cull_candidates = {}
local _cull_candidate_count = 0

local _cull_pool = {}
local _cull_pool_count = 0
local MAX_CULL_POOL = 512

local _cull_cell_pool = {}
local _cull_cell_pool_count = 0
local MAX_CULL_CELL_POOL = 256

local CLUSTER_UPDATE_INTERVAL = 0.5
local _cluster_update_timer = 0

local DEAD_CLEANUP_INTERVAL = 0.5
local _dead_cleanup_timer = 0

local _enemy_list = {}
local _enemy_list_index = {}
local _active_widget_units = {}

mod.clusters = {}
mod.clusters._horde_clusters = {}
mod.clusters._horde_cluster_by_unit = {}

mod.clusters._old_rep_of = {}
mod.clusters._cluster_members = {}
mod.clusters._cluster_units_scratch = {}

mod.clusters._spatial_hash = {}
mod.clusters._visited = {}
mod.clusters._z_samples = {}
mod.clusters._bfs_queue = {}

local _orphan_units = {}
local _orphan_seen = {}

local _player_pos_vec = Vector3.zero()
local _pos_vec = Vector3.zero()
local _bfs_pos = Vector3.zero()
local _bfs_other_pos = Vector3.zero()

local MAX_ENEMY_UPDATE_TIME = 0.0025
local ENEMY_TIME_CHECK_INTERVAL = 2

local LOS_CACHE_INTERVAL = 0.25

local COLOUR_LOOKUP = {
	Gold = { 255, 232, 188, 109 },
	Silver = { 255, 187, 198, 201 },
	Steel = { 255, 161, 166, 169 },
	Black = { 255, 35, 31, 32 },
	Brass = { 255, 226, 199, 126 },
	Terminal = Color.terminal_background(200, true),
	Default = { 255, 161, 166, 169 },
}

local PRIORITY = {
	monster = 100,
	captain = 100,
	witch = 100,
	sniper = 100,
	disabler = 75,
	far = 50,
	special = 50,
	elite = 50,
	shield = 50,
	melee_horde = 20,
	ranged_horde = 20,
	enemy = 20,
}

local function _recycle_cull_cells()
	local pool = _cull_pool
	local pool_count = _cull_pool_count

	local cell_pool = _cull_cell_pool
	local cell_pool_count = _cull_cell_pool_count

	for key, list in pairs(_cull_cells) do
		local n = #list

		for i = 1, n do
			if pool_count < MAX_CULL_POOL then
				pool_count = pool_count + 1
				pool[pool_count] = list[i]
			end
		end

		table_clear(list)

		if cell_pool_count < MAX_CULL_CELL_POOL then
			cell_pool_count = cell_pool_count + 1
			cell_pool[cell_pool_count] = list
		end

		_cull_cells[key] = nil
	end

	_cull_pool_count = pool_count
	_cull_cell_pool_count = cell_pool_count
end

local function _get_cull_cell(key)
	local list = _cull_cells[key]

	if list then
		return list
	end

	local count = _cull_cell_pool_count

	if count > 0 then
		list = _cull_cell_pool[count]
		_cull_cell_pool[count] = nil
		_cull_cell_pool_count = count - 1
	else
		list = {}
	end

	_cull_cells[key] = list

	return list
end

mod.store_enemy_position = function(entry, x, y, z)
	local pos = entry.pos

	if type(pos) ~= "table" then
		pos = {}
		entry.pos = pos
	end

	pos.x = x
	pos.y = y
	pos.z = z

	return pos
end

local function _refresh_enemy_position(unit, entry)
	local pos = Unit.world_position(unit, 1, _pos_vec)

	if not pos then
		return nil
	end

	local px = pos.x
	local py = pos.y
	local pz = pos.z

	mod.store_enemy_position(entry, px, py, pz)

	return px, py, pz
end

local function _register_enemy(unit)
	if _enemy_list_index[unit] ~= nil then
		return
	end

	local index = #_enemy_list + 1

	_enemy_list[index] = unit
	_enemy_list_index[unit] = index
end

local function _unregister_enemy(unit)
	local index = _enemy_list_index[unit]

	if not index then
		return
	end

	local last_index = #_enemy_list
	local last_unit = _enemy_list[last_index]

	if index ~= last_index then
		_enemy_list[index] = last_unit
		_enemy_list_index[last_unit] = index
	end

	_enemy_list[last_index] = nil
	_enemy_list_index[unit] = nil
end

local function _is_horde_from_breed(unit, breed)
	if not breed then
		return false
	end

	local tags = breed.tags

	if not tags or not (tags.horde or tags.roamer) then
		return false
	end

	if mod.is_vanguard(unit) then
		return false
	end

	return true
end

local function _get_enemy_max_dist_sq(entry, base_dist_sq, breed_dist_enabled, breed_dist_value)
	local breed_name = entry.breed_name

	if breed_name and breed_dist_enabled[breed_name] then
		local distance = breed_dist_value[breed_name]

		if distance then
			return distance * distance
		end
	end

	return base_dist_sq
end

local _active_special_outlines = {}
local _active_stagger_outlines = {}

local function _remove_active_outline(list, entry, index_field)
	local index = entry[index_field]

	if not index then
		return
	end

	local last_index = #list
	local last_entry = list[last_index]

	if index ~= last_index then
		list[index] = last_entry
		last_entry[index_field] = index
	end

	list[last_index] = nil
	entry[index_field] = nil
end

local function _add_active_outline(list, entry, index_field)
	if entry[index_field] then
		return
	end

	local index = #list + 1

	list[index] = entry
	entry[index_field] = index
end

local function _refresh_outline_tracking(entry)
	-- Special attack / alert outlines
	if entry.seen and (entry.special_attack_imminent or entry.alert_outline) then
		_add_active_outline(_active_special_outlines, entry, "_ei_special_outline_index")
	else
		_remove_active_outline(_active_special_outlines, entry, "_ei_special_outline_index")
	end

	-- Stagger outlines
	if entry.seen and (entry.staggered or entry.stagger_outline) then
		_add_active_outline(_active_stagger_outlines, entry, "_ei_stagger_outline_index")
	else
		_remove_active_outline(_active_stagger_outlines, entry, "_ei_stagger_outline_index")
	end
end

local function _clear_active_outline_tracking()
	local special = _active_special_outlines
	local stagger = _active_stagger_outlines

	for i = 1, #special do
		special[i]._ei_special_outline_index = nil
	end

	for i = 1, #stagger do
		stagger[i]._ei_stagger_outline_index = nil
	end

	table_clear(special)
	table_clear(stagger)
end

local function _get_priority(breed_type, dist_sq, forward_bonus, unit)
	local base = PRIORITY[breed_type] or 0

	local distance_score = 1000 / (1 + dist_sq * 0.05)

	local score = base + distance_score

	if mod.aimed_unit[unit] then
		score = score + AIMED_PRIORITY_BONUS
	end

	if mod.tagged_units[unit] then
		score = score + TAGGED_PRIORITY_BONUS
	end

	if mod.enemy_cache[unit] then
		score = score + EXISTING_PRIORITY_BONUS
	end

	return score
end

local function _cull_sort(a, b)
	local a_aimed = mod.aimed_unit[a.unit] == true
	local b_aimed = mod.aimed_unit[b.unit] == true

	if a_aimed ~= b_aimed then
		return a_aimed
	end

	local a_tagged = mod.tagged_units[a.unit] == true
	local b_tagged = mod.tagged_units[b.unit] == true

	if a_tagged ~= b_tagged then
		return a_tagged
	end

	if a.score ~= b.score then
		return a.score > b.score
	end

	return a.dist_sq < b.dist_sq
end

local function _depth_keep(i, score)
	if i <= MAX_PER_CELL then
		return true
	end

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

local outline_settings = require("scripts/settings/outline/outline_settings")

mod.on_all_mods_loaded = function()
	mod.migrate_override_settings()

	check_selected_font()

	mod.clear_caches()

	mod.init_healthbar_defaults()
	mod.update_breed_colours()
	mod.update_breed_icons()

	mod.build_frame_settings()

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

mod.enemy_custom_name = function(breed, breed_type)
	local breed_name = breed and breed.name

	if breed_name then
		local custom = mod:get("healthbar_" .. breed_name .. "_custom_name")

		if type(custom) == "string" and custom ~= "" then
			return custom
		end
	end

	if breed_type then
		local custom = mod:get("healthbar_" .. tostring(breed_type) .. "_custom_name")

		if type(custom) == "string" and custom ~= "" then
			return custom
		end
	end

	return nil
end

local EnemyImprovedTemplate =
	mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/templates/enemies_improved_template")

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

mod.hit_positions = {}
mod.HIT_POSITION_MAX_AGE = 1.0

mod:hook_safe(
	"AttackReportManager",
	"add_attack_result",
	function(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position)
		if not attacked_unit or not hit_world_position then
			return
		end

		local entry = mod.hit_positions[attacked_unit]

		if entry then
			entry.position:store(hit_world_position)
			entry.time = mod.get_time()
		else
			mod.hit_positions[attacked_unit] = {
				position = Vector3Box(hit_world_position),
				time = mod.get_time(),
			}
		end
	end
)

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

mod:hook_safe(CLASS.HudElementWorldMarkers, "update", function(self, dt, t)
	add_custom_templates(self)

	local current_level = Managers.state.mission and Managers.state.mission:mission()
	local in_shooting_range = (current_level and current_level.game_mode_name == "shooting_range") or false

	fs.force_on_in_training = (fs.always_show_in_meatgrinder and in_shooting_range) or false

	if fs.only_in_meatgrinder then
		mod.enabled = in_shooting_range
	else
		mod.enabled = true
	end

	if mod.enabled then
		-- Target scanning
		if not fs.spatial_culling then
			_aim_scan_timer = _aim_scan_timer + dt

			if _aim_scan_timer >= AIM_SCAN_INTERVAL then
				_aim_scan_timer = _aim_scan_timer % AIM_SCAN_INTERVAL

				mod.do_aim_raycast()
			end

			if fs.only_tagged_enemies then
				_tag_scan_timer = _tag_scan_timer + dt

				if _tag_scan_timer >= TAG_SCAN_INTERVAL then
					_tag_scan_timer = _tag_scan_timer % TAG_SCAN_INTERVAL

					mod.do_tagged_scan()
				end
			else
				_tag_scan_timer = 0
				table_clear(mod.tagged_units)
			end
		end

		self._update_time = (self._update_time or 0) + dt

		local throttle = fs.general_throttle_rate or 0.1

		if self._update_time >= throttle then
			local elapsed = self._update_time

			self._update_time = self._update_time % throttle

			mod.update_enemies(elapsed, t)
		end

		local has_specials = fs.outline_specials_enable or fs.marker_specials_enable or fs.healthbar_specials_enable

		local stagger_horde = fs.outline_stagger_horde_enable
		local stagger_normal = fs.outline_stagger_enable

		local has_stagger = stagger_horde or stagger_normal

		if has_specials or has_stagger then
			_outline_update_timer = _outline_update_timer + dt

			if _outline_update_timer >= OUTLINE_UPDATE_INTERVAL then
				local elapsed = _outline_update_timer

				_outline_update_timer = _outline_update_timer % OUTLINE_UPDATE_INTERVAL

				local pulse_interval = fs.special_attack_pulse_speed or 0.2
				local stagger_interval = fs.stagger_pulse_speed or 0.2

				-- SPECIAL / ALERT OUTLINES
				if has_specials then
					local list = _active_special_outlines

					for i = #list, 1, -1 do
						local entry = list[i]

						if not entry.seen or not entry.unit then
							_remove_active_outline(list, entry, "_ei_special_outline_index")
						elseif entry.special_attack_imminent then
							local timer = (entry._special_pulse_timer or 0) + elapsed

							if timer >= pulse_interval then
								timer = timer % pulse_interval
								mod.pulse_enemy_outline(entry)
							end

							entry._special_pulse_timer = timer
						elseif entry.alert_outline then
							mod.remove_alert_outline(entry)
						end

						_refresh_outline_tracking(entry)
					end
				end

				-- STAGGER OUTLINES
				if has_stagger then
					local list = _active_stagger_outlines

					for i = #list, 1, -1 do
						local entry = list[i]

						if not entry.seen or not entry.unit then
							_remove_active_outline(list, entry, "_ei_stagger_outline_index")
						else
							local should_process = (entry.is_horde and stagger_horde)
								or (not entry.is_horde and stagger_normal)

							if should_process and entry.staggered then
								local timer = (entry._stagger_pulse_timer or 0) + elapsed

								if timer >= stagger_interval then
									timer = timer % stagger_interval
									mod.pulse_enemy_outline(entry)
								end

								entry._stagger_pulse_timer = timer
							elseif entry.stagger_outline then
								mod.remove_stagger_outline(entry)
							end
						end

						_refresh_outline_tracking(entry)
					end
				end
			end
		else
			_outline_update_timer = 0
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

	local markers = mod.enemy_markers
	local healthbars = mod.enemy_healthbars
	local debuffs = mod.enemy_debuffs

	local marker_id = markers[unit]
	local healthbar_id = healthbars[unit]
	local debuff_id = debuffs[unit]

	local last_removed_id = nil

	if entry and entry.marker then
		local id = entry.marker.id

		if id then
			_trigger_remove_marker(id)
			last_removed_id = id
		end
	end

	if marker_id and marker_id ~= last_removed_id then
		_trigger_remove_marker(marker_id)
		last_removed_id = marker_id
	end

	if healthbar_id and healthbar_id ~= last_removed_id then
		_trigger_remove_marker(healthbar_id)
		last_removed_id = healthbar_id
	end

	if debuff_id and debuff_id ~= last_removed_id then
		_trigger_remove_marker(debuff_id)
	end

	markers[unit] = nil
	healthbars[unit] = nil
	debuffs[unit] = nil

	if mod.hit_positions then
		mod.hit_positions[unit] = nil
	end

	local cluster = mod.get_horde_cluster_for_unit(unit)

	if cluster and cluster.rep_unit == unit then
		cluster._healthbar_created = false
		cluster._healthbar_marker_id = nil
	end

	if entry then
		entry._ei_marker_created = false
		entry._ei_marker_pending = nil
		entry.marker = nil

		mod.disable_enemy_outlines(unit, entry)
		mod.remove_alert_outline(entry)
		mod.remove_stagger_outline(entry)
		_refresh_outline_tracking(entry)
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
	local cache = mod.enemy_cache
	local seen = _orphan_seen
	local remove = _orphan_units

	table_clear(seen)
	table_clear(remove)

	local count = 0

	for unit in next, mod.enemy_markers do
		if not cache[unit] and not seen[unit] then
			seen[unit] = true
			count = count + 1
			remove[count] = unit
		end
	end

	for unit in next, mod.enemy_healthbars do
		if not cache[unit] and not seen[unit] then
			seen[unit] = true
			count = count + 1
			remove[count] = unit
		end
	end

	for unit in next, mod.enemy_debuffs do
		if not cache[unit] and not seen[unit] then
			seen[unit] = true
			count = count + 1
			remove[count] = unit
		end
	end

	for i = 1, count do
		mod.force_remove_unit_markers(remove[i])
	end

	table_clear(remove)
	table_clear(seen)
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

local BROADPHASE_QUERY_RADIUS = 50
local BROADPHASE_QUERY_RADIUS_SQ = 2500
local BROADPHASE_LATTICE_SPACING = 70
local INV_BROADPHASE_SPACING = 1 / BROADPHASE_LATTICE_SPACING

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

	local query = broadphase.query

	if radius <= BROADPHASE_QUERY_RADIUS then
		local hits = query(broadphase, from_pos, radius, results, side_names)

		return _is_finite_number(hits) and hits or 0
	end

	local scratch = mod._broadphase_scratch
	local seen = mod._broadphase_seen

	table_clear(seen)

	local total = 0

	local px = from_pos.x
	local py = from_pos.y
	local pz = from_pos.z

	local max_offset = radius + BROADPHASE_QUERY_RADIUS
	local max_offset_sq = max_offset * max_offset

	local max_cells = math.ceil(max_offset * INV_BROADPHASE_SPACING)

	for gx = -max_cells, max_cells do
		local ox = gx * BROADPHASE_LATTICE_SPACING
		local ox_sq = ox * ox

		for gy = -max_cells, max_cells do
			local oy = gy * BROADPHASE_LATTICE_SPACING

			if ox_sq + oy * oy <= max_offset_sq then
				table_clear(scratch)

				local centre

				if gx == 0 and gy == 0 then
					centre = from_pos
				else
					centre = Vector3(px + ox, py + oy, pz)
				end

				local hits = query(broadphase, centre, BROADPHASE_QUERY_RADIUS, scratch, side_names)

				if _is_finite_number(hits) then
					for i = 1, hits do
						local unit = scratch[i]

						if unit and not seen[unit] then
							seen[unit] = true

							total = total + 1
							results[total] = unit
						end
					end
				end
			end
		end
	end

	return total
end

mod.scan_enemies = function()
	table_clear(_horde_units_all)
	_recycle_cull_cells()

	local local_player = Managers_player:local_player(1)
	if not local_player then
		return
	end

	local player_unit = local_player.player_unit
	if not player_unit or not mod.detect_alive(player_unit) then
		return
	end

	mod.set_is_ads(player_unit)

	local current_pos = Unit.world_position(player_unit, 1, _player_pos_vec)

	if not current_pos then
		return
	end

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

	if not fs.spatial_culling then
		table_clear(_active_widget_units)
	end

	local results = mod._broadphase_results
	table_clear(results)

	local num_hits = mod.query_broadphase_covered(broadphase, from_pos, range, results, enemy_side_names)

	local cache = mod.enemy_cache
	local enemy_list = _enemy_list

	local scan_time = mod.get_time()

	for i = 1, #enemy_list do
		local data = cache[enemy_list[i]]

		if data and not data._dead_at then
			data.seen = false
		end
	end

	if num_hits == 0 then
		if fs.spatial_culling then
			local active = _active_widget_units
			local cache = mod.enemy_cache

			for i = 1, #active do
				local unit = active[i]
				local entry = cache[unit]

				if entry then
					entry._ei_widget_active = false
					mod.force_remove_unit_markers(unit)
				end
			end

			table_clear(active)
		end

		return
	end

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

			local is_aimed = mod.aimed_unit[unit] == true

			local entry = cache[unit]
			local now = scan_time

			-- LOS CHECK
			local los_ok = false
			local should_check_los = true

			if entry and entry._los_checked_at then
				if now - entry._los_checked_at < LOS_CACHE_INTERVAL then
					should_check_los = false
					los_ok = entry._los_ok
				end
			end

			if should_check_los then
				if physics_world_cache then
					los_ok = mod.has_line_of_sight(player_unit, unit, physics_world_cache, player_los_pos)
				else
					los_ok = true
				end

				if entry then
					entry._los_ok = los_ok
					entry._los_checked_at = now
				end
			end

			if not los_ok and not fs.spatial_culling then
				if entry or mod.enemy_markers[unit] or mod.enemy_healthbars[unit] or mod.enemy_debuffs[unit] then
					mod.force_remove_unit_markers(unit)

					if mod._cleanup_unit_health_data then
						mod._cleanup_unit_health_data(unit)
					end
				end

				_unregister_enemy(unit)
				cache[unit] = nil
				mod.marked_dead[unit] = nil

				goto skip_breed
			end

			-------------------------

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

			local unit_data_ext = entry and entry.unit_data_ext

			if not unit_data_ext then
				unit_data_ext = ScriptUnit_has_extension(unit, "unit_data_system")
			end

			if not unit_data_ext then
				goto skip_breed
			end

			local breed = entry and entry.breed

			if not breed then
				breed = unit_data_ext:breed()
			end

			if not breed then
				goto skip_breed
			end

			local breed_type = entry and entry.breed_type

			if not breed_type then
				breed_type = mod.find_breed_category(unit, breed)
			end

			if entry then
				mod.store_enemy_position(entry, px, py, pz)
			end

			-- build animation map for this enemy
			if mod.DEBUG then
				--mod.init_breed_anim_db(unit, breed, breed.name)
			end

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

				local score = _get_priority(breed_type, dist_sq, forward_bonus, unit)

				local key = gx * 73856093 + gy * 19349663
				local list = _get_cull_cell(key)

				local pool_count = _cull_pool_count
				local e = _cull_pool[pool_count]

				if e then
					_cull_pool[pool_count] = nil
					_cull_pool_count = pool_count - 1
				else
					e = {}
				end

				e.unit = unit
				e.score = score
				e.dist_sq = dist_sq
				e.forward_bonus = forward_bonus

				e.unit_data_ext = unit_data_ext
				e.breed = breed
				e.breed_type = breed_type

				e.x = px
				e.y = py
				e.z = pz

				e.los_ok = los_ok

				list[#list + 1] = e

				goto skip_breed
			else
				if not entry then
					cache[unit] = {
						unit = unit,
						seen = true,

						dead = false,

						health_ext = ScriptUnit_has_extension(unit, "health_system"),
						unit_data_ext = unit_data_ext,
						behavior_ext = ScriptUnit_has_extension(unit, "behavior_system"),

						is_horde = _is_horde_from_breed(unit, breed),

						breed = breed,
						breed_name = breed and breed.name,
						breed_type = breed_type,

						special_attack_event = nil,
						special_attack_imminent = false,
						special_attack_timer = 0,

						alert_outline = false,
						stagger_outline = false,
						outline_name = nil,

						alert_healthbar = false,

						_ei_marker_created = false,
						_los_ok = los_ok,

						_ei_widget_active = true,
					}
					_register_enemy(unit)
					mod.marked_dead[unit] = nil
				else
					entry.seen = true
					mod.store_enemy_position(entry, px, py, pz)
					entry._los_ok = los_ok
					mod.marked_dead[unit] = nil
					entry._dead_at = nil
					entry._ei_widget_active = true
					_active_widget_units[#_active_widget_units + 1] = unit
				end
			end
			::skip_breed::
		end
	end

	if fs.spatial_culling then
		MAX_ACTIVE_ENEMIES = math_max(1, fs.max_active_enemies or 20)

		local candidates = _cull_candidates
		local candidate_count = 0

		for _, list in pairs(_cull_cells) do
			for i = 1, #list do
				candidate_count = candidate_count + 1
				candidates[candidate_count] = list[i]
			end

			table_clear(list)
		end

		mod.do_aim_raycast(candidates, candidate_count)
		mod.do_tagged_scan(candidates, candidate_count)

		for i = 1, candidate_count do
			local data = candidates[i]
			local unit = data.unit

			data.score = _get_priority(data.breed_type, data.dist_sq, data.forward_bonus or 0, unit)

			if fs.horde_clusters_enable and mod.get_horde_cluster_for_unit then
				local cluster = mod.get_horde_cluster_for_unit(unit)

				if cluster then
					data.cluster = cluster

					if cluster.rep_unit == unit then
						data.cluster_rep = true
						data.score = data.score + CLUSTER_REP_PRIORITY_BONUS
					else
						data.cluster_member = true
					end
				end
			end
		end

		if candidate_count > 1 then
			table.sort(candidates, _cull_sort)
		end

		local cache = mod.enemy_cache
		local active = _active_widget_units

		table_clear(active)

		local kept = 0

		for i = 1, candidate_count do
			local data = candidates[i]
			local unit = data.unit

			if unit and HEALTH_ALIVE[unit] and Unit_alive(unit) then
				local entry = cache[unit]

				if not entry then
					local breed = data.breed

					entry = {
						unit = unit,
						seen = true,
						dead = false,

						health_ext = ScriptUnit_has_extension(unit, "health_system"),
						unit_data_ext = data.unit_data_ext,
						behavior_ext = ScriptUnit_has_extension(unit, "behavior_system"),

						is_horde = _is_horde_from_breed(unit, breed),

						breed = breed,
						breed_name = breed and breed.name,
						breed_type = data.breed_type,

						_priority_score = data.score,

						pos = {
							x = data.x,
							y = data.y,
							z = data.z,
						},

						_ei_marker_created = false,
						_los_ok = data.los_ok,
						_los_checked_at = scan_time,

						_ei_widget_active = false,
					}

					cache[unit] = entry
					_register_enemy(unit)
				else
					entry.seen = true
					entry._priority_score = data.score
					entry._los_ok = data.los_ok
					entry._dead_at = nil

					mod.store_enemy_position(entry, data.x, data.y, data.z)
				end

				local is_aimed = mod.aimed_unit[unit] == true
				local is_tagged = mod.tagged_units[unit] == true
				local is_cluster_member = data.cluster_member == true

				local keep_widgets = kept < MAX_ACTIVE_ENEMIES

				if fs.markers_show_only_aimed then
					keep_widgets = is_aimed
				end

				if not data.los_ok and (not is_aimed or not is_tagged) then
					keep_widgets = false
				end

				if is_tagged then
					keep_widgets = true
				end

				if is_cluster_member and not is_tagged and not is_aimed then
					keep_widgets = false
				end

				if keep_widgets then
					if not entry._ei_widget_active then
						entry._ei_widget_active = true
					end

					active[#active + 1] = unit

					if not is_cluster_member then
						kept = kept + 1
					end
				else
					if entry._ei_widget_active then
						mod.force_remove_unit_markers(unit)
					end

					entry._ei_widget_active = false
				end

				mod.marked_dead[unit] = nil
			end

			data.unit = nil
			data.unit_data_ext = nil
			data.breed = nil
			data.breed_type = nil

			data.x = nil
			data.y = nil
			data.z = nil
			data.dist_sq = nil
			data.score = nil
			data.forward_bonus = nil
			data.los_ok = nil
			data.cluster = nil
			data.cluster_rep = nil
			data.cluster_member = nil

			local pool_count = _cull_pool_count

			if pool_count < MAX_CULL_POOL then
				pool_count = pool_count + 1
				_cull_pool[pool_count] = data
				_cull_pool_count = pool_count
			end

			candidates[i] = nil
		end

		_cull_candidate_count = 0
	end
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
local _dead_cleanup_cursor = 1

local MAX_DEAD_CHECKS_PER_TICK = 32
local DEAD_CLEANUP_INTERVAL = 0.1

mod.remove_dead = function()
	local player = Managers_player:local_player(1)

	if not player then
		return
	end

	local player_unit = player.player_unit

	if not player_unit or not mod.detect_alive(player_unit) then
		return
	end

	local player_pos = Unit.world_position(player_unit, 1, _player_pos_vec)

	if not player_pos then
		return
	end

	local player_x = player_pos.x
	local player_y = player_pos.y
	local player_z = player_pos.z

	local settings = fs

	local max_dist = settings.draw_distance or 50
	local max_dist_sq = max_dist * max_dist

	local keep_dead_window = settings.hb_show_dps or settings.widget_removal_delay > 0

	local dead_window = math_max(settings.damage_number_duration or 0, settings.widget_removal_delay or 0)

	local t = mod.get_time()

	local cache = mod.enemy_cache
	local enemy_list = _enemy_list

	local markers = mod.enemy_markers
	local healthbars = mod.enemy_healthbars
	local debuffs = mod.enemy_debuffs

	local clusters_enable = settings.horde_clusters_enable
	local cleanup_health = mod._cleanup_unit_health_data

	local breed_dist_enabled = settings.breed_dist_enabled
	local breed_dist_value = settings.breed_dist_value

	local count = #enemy_list

	if count == 0 then
		_dead_cleanup_cursor = 1
		return
	end

	local index = _dead_cleanup_cursor

	if index > count then
		index = 1
	end

	local checked = 0
	local visited = 0

	while checked < MAX_DEAD_CHECKS_PER_TICK and visited < count do
		local unit = enemy_list[index]
		local entry = cache[unit]

		local remove = false
		local mark_dead = false

		if not entry then
			remove = true
		else
			local alive = HEALTH_ALIVE[unit] and Unit_alive(unit)

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
				local health_ext = entry.health_ext

				if health_ext then
					local health_percent = health_ext:current_health_percent() or 0

					if health_percent and health_percent <= 0 then
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

			-- Expired dead window
			if not remove and entry._dead_at then
				if dead_window <= 0 or t - entry._dead_at > dead_window then
					remove = true
					mark_dead = true
				end
			end

			-- Distance cleanup using cached position
			if not remove and alive then
				local pos = entry.pos

				if pos then
					local dx = pos.x - player_x
					local dy = pos.y - player_y
					local dz = pos.z - player_z

					local dist_sq = dx * dx + dy * dy + dz * dz

					local effective_dist_sq = max_dist_sq
					local breed_name = entry.breed_name

					if breed_name and breed_dist_enabled[breed_name] then
						local individual_distance = breed_dist_value[breed_name]

						if individual_distance then
							effective_dist_sq = individual_distance * individual_distance
						end
					end

					if dist_sq > effective_dist_sq then
						remove = true

						mod.disable_enemy_outlines(unit, entry)
						mod.remove_alert_outline(entry)
						mod.remove_stagger_outline(entry)
					end
				end
			end
		end

		if remove then
			if entry and clusters_enable then
				local cluster = mod.get_horde_cluster_for_unit(unit)

				if cluster and cluster.rep_unit == unit then
					cluster._healthbar_created = false
					cluster._healthbar_marker_id = nil
				end
			end

			local id = markers[unit]

			if id then
				Managers.event:trigger("remove_world_marker", id)
			end

			id = healthbars[unit]

			if id then
				Managers.event:trigger("remove_world_marker", id)
			end

			id = debuffs[unit]

			if id then
				Managers.event:trigger("remove_world_marker", id)
			end

			markers[unit] = nil
			healthbars[unit] = nil
			debuffs[unit] = nil

			if cleanup_health then
				cleanup_health(unit)
			end

			_unregister_enemy(unit)

			cache[unit] = nil

			if mark_dead then
				mod.marked_dead[unit] = true
			else
				mod.marked_dead[unit] = nil
			end

			-- Swap removal: process the replacement at this index next.
			count = #enemy_list

			if index > count then
				index = 1
			end
		else
			index = index + 1

			if index > count then
				index = 1
			end
		end

		checked = checked + 1
		visited = visited + 1

		if count == 0 then
			index = 1
			break
		end
	end

	_dead_cleanup_cursor = index
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

	if mod.hit_positions then
		table_clear(mod.hit_positions)
	end

	table_clear(_enemy_list)
	table_clear(_enemy_list_index)
	table_clear(_enemy_units_temp)
	table_clear(_active_widget_units)

	_last_enemy_index = 0

	table_clear(_cull_cell_pool)
	_cull_cell_pool_count = 0
	table_clear(mod.clusters._old_rep_of)
	table_clear(mod.clusters._cluster_members)

	table_clear(mod.aimed_unit)
	table_clear(mod.tagged_units)

	if mod._clear_unit_health_data then
		mod._clear_unit_health_data()
	end

	table_clear(_enemy_units_temp)
	table_clear(mod.clusters._horde_clusters)
	table_clear(mod.clusters._horde_cluster_by_unit)

	table_clear(mod.clusters._spatial_hash)
	table_clear(mod.clusters._visited)
	table_clear(mod.clusters._z_samples)
	table_clear(mod.clusters._bfs_queue)

	table_clear(_cull_pool)
	table_clear(_cull_cells)
	table_clear(_units_to_remove)

	_clear_active_outline_tracking()
	_dead_cleanup_cursor = 1

	mod._markers_by_id = nil

	if mod._clear_outline_caches then
		mod._clear_outline_caches()
	end

	if mod.refresh_custom_names then
		mod.refresh_custom_names()
	end
end

-----------------------------------------------------------------------
-- Candidate targeting
-----------------------------------------------------------------------

mod.do_aim_raycast = function(candidates, candidate_count)
	local ui_manager = Managers_ui
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
	local forward = Quaternion_forward(Camera.local_rotation(camera))

	local px, py, pz = cam_pos.x, cam_pos.y, cam_pos.z

	local cone_fov = (fs.markers_show_only_aimed and (fs.aim_cone_angle or 16)) or 45
	local cone_cos = math.cos(math.rad(cone_fov))
	local cone_cos_sq = cone_cos * cone_cos

	local draw_dist_sq = fs.draw_distance * fs.draw_distance
	local breed_dist_enabled = fs.breed_dist_enabled
	local breed_dist_value = fs.breed_dist_value

	local aimed = mod.aimed_unit

	table_clear(aimed)

	if candidates then
		for i = 1, candidate_count do
			local data = candidates[i]
			local unit = data.unit

			if unit then
				local dx = data.x - px
				local dy = data.y - py
				local dz = (data.z - pz) * 0.3

				local dist_sq = dx * dx + dy * dy + dz * dz

				local max_dist_sq = draw_dist_sq
				local breed_name = data.breed and data.breed.name

				if breed_name and breed_dist_enabled[breed_name] then
					local individual_distance = breed_dist_value[breed_name]

					if individual_distance then
						max_dist_sq = individual_distance * individual_distance
					end
				end

				if dist_sq > 0 and dist_sq <= max_dist_sq then
					local dot = dx * forward.x + dy * forward.y + dz * forward.z

					if dot > 0 and dot * dot > cone_cos_sq * dist_sq then
						aimed[unit] = true
					end
				end
			end
		end
	else
		local enemy_list = _enemy_list
		local cache = mod.enemy_cache

		for i = 1, #enemy_list do
			local unit = enemy_list[i]
			local entry = cache[unit]

			if entry and entry.seen and mod.detect_alive(unit) then
				local pos = entry.pos

				if pos then
					local dx = pos.x - px
					local dy = pos.y - py
					local dz = (pos.z - pz) * 0.3

					local dist_sq = dx * dx + dy * dy + dz * dz
					local max_dist_sq =
						_get_enemy_max_dist_sq(entry, draw_dist_sq, breed_dist_enabled, breed_dist_value)

					if dist_sq > 0 and dist_sq <= max_dist_sq then
						local dot = dx * forward.x + dy * forward.y + dz * forward.z

						if dot > 0 and dot * dot > cone_cos_sq * dist_sq then
							aimed[unit] = true
						end
					end
				end
			end
		end
	end
end

mod.do_tagged_scan = function(candidates, candidate_count)
	local tagged = mod.tagged_units

	table_clear(tagged)

	local extension_manager = Managers_state.extension

	if not extension_manager then
		return
	end

	local smart_tag_system = extension_manager:system("smart_tag_system")

	if not smart_tag_system then
		return
	end

	if candidates then
		for i = 1, candidate_count do
			local unit = candidates[i].unit

			if unit and HEALTH_ALIVE[unit] and Unit_alive(unit) then
				if smart_tag_system:unit_tag_id(unit) then
					tagged[unit] = true
				end
			end
		end
	else
		local enemy_list = _enemy_list
		local cache = mod.enemy_cache

		for i = 1, #enemy_list do
			local unit = enemy_list[i]
			local entry = cache[unit]

			if entry and entry.seen and mod.detect_alive(unit) then
				if smart_tag_system:unit_tag_id(unit) then
					tagged[unit] = true
				end
			end
		end
	end
end

mod.update_enemies = function(dt, t)
	mod.scan_enemies()

	local cache = mod.enemy_cache
	local temp = _active_widget_units
	local count = #temp
	local cache_count = #_enemy_list

	if cache_count == 0 then
		_last_enemy_index = 0
		table_clear(mod.clusters._horde_clusters)
		table_clear(mod.clusters._horde_cluster_by_unit)
		return
	end

	local start_index = 1

	if count > 0 then
		start_index = (_last_enemy_index % count) + 1
	end

	if fs.horde_clusters_enable then
		_cluster_update_timer = _cluster_update_timer + dt

		if _cluster_update_timer >= CLUSTER_UPDATE_INTERVAL then
			_cluster_update_timer = _cluster_update_timer % CLUSTER_UPDATE_INTERVAL

			mod.update_horde_clusters(_horde_units_all, #_horde_units_all)
		end
	else
		_cluster_update_timer = 0

		if next(mod.clusters._horde_clusters) then
			table_clear(mod.clusters._horde_clusters)
			table_clear(mod.clusters._horde_cluster_by_unit)
		end
	end

	local player = Managers_player:local_player(1)
	local player_unit = player and player.player_unit

	local player_pos = nil

	if player_unit and Unit_alive(player_unit) then
		player_pos = Unit.world_position(player_unit, 1, _player_pos_vec)
	end

	local base_dist_sq = fs.draw_distance * fs.draw_distance

	local breed_dist_enabled = fs.breed_dist_enabled
	local breed_dist_value = fs.breed_dist_value

	local outlines_enable = fs.outlines_enable
	local healthbars_enable = fs.healthbar_enable or fs.show_damage_numbers
	local debuffs_enable = fs.debuff_enable
	local markers_enable = fs.markers_enable
	local specials_enable = fs.marker_specials_enable or fs.outline_specials_enable or fs.healthbar_specials_enable

	local update_markers = mod.update_enemy_markers
	local update_outlines = mod.update_enemy_outlines
	local update_healthbars = mod.update_enemy_healthbars
	local update_debuffs = mod.update_enemy_debuffs
	local update_special = mod.update_special_attack_detection

	local is_alive = mod.detect_alive
	local get_position = Unit.world_position

	local hud = Managers_ui and Managers_ui:get_hud()
	local world_markers = hud and hud:element("HudElementWorldMarkers")

	mod._markers_by_id = world_markers and world_markers._markers_by_id

	local idx = start_index

	local processed = 0
	local start_clock = os_clock()

	while processed < count and processed < MAX_ENEMIES_PER_FRAME do
		local unit = temp[idx]
		local entry = cache[unit]

		if entry and entry.seen then
			if is_alive(unit) then
				local widget_active = entry._ei_widget_active ~= false

				if fs.markers_show_only_aimed then
					widget_active = widget_active and mod.aimed_unit[unit]
				end

				if fs.only_tagged_enemies then
					local is_tagged = mod.tagged_units[unit] == true

					if not is_tagged then
						if
							entry._ei_marker_created
							or mod.enemy_markers[unit]
							or mod.enemy_healthbars[unit]
							or mod.enemy_debuffs[unit]
						then
							mod.force_remove_unit_markers(unit)
						end
					end

					widget_active = widget_active and is_tagged
				end

				if player_pos then
					local pos = entry.pos

					if pos then
						local px = pos.x
						local py = pos.y
						local pz = pos.z

						local dx = px - player_pos.x
						local dy = py - player_pos.y
						local dz = pz - player_pos.z

						local dist_sq = dx * dx + dy * dy + dz * dz

						local max_dist_sq =
							_get_enemy_max_dist_sq(entry, base_dist_sq, breed_dist_enabled, breed_dist_value)

						if dist_sq <= max_dist_sq and widget_active then
							if markers_enable then
								update_markers(entry, t)
							end

							if outlines_enable then
								update_outlines(entry, player_unit)
								_refresh_outline_tracking(entry)
							end

							if healthbars_enable then
								update_healthbars(entry, t)
							end

							if debuffs_enable then
								update_debuffs(entry, t)
							end

							if specials_enable then
								update_special(entry)
							end
						end
					end
				elseif widget_active then
					if markers_enable then
						update_markers(entry, t)
					end

					if outlines_enable then
						update_outlines(entry, player_unit)
						_refresh_outline_tracking(entry)
					end

					if healthbars_enable then
						update_healthbars(entry, t)
					end

					if debuffs_enable then
						update_debuffs(entry, t)
					end

					if specials_enable then
						update_special(entry)
					end
				end
			end
		end

		idx = idx + 1

		if idx > count then
			idx = 1
		end

		processed = processed + 1

		if processed % ENEMY_TIME_CHECK_INTERVAL == 0 then
			if os_clock() - start_clock >= MAX_ENEMY_UPDATE_TIME then
				break
			end
		end
	end

	if count > 0 then
		_last_enemy_index = (idx - 2) % count + 1
	else
		_last_enemy_index = 0
	end

	if fs.enable_depth_fading then
		mod.apply_marker_fade()
	end

	mod._markers_by_id = nil

	_dead_cleanup_timer = _dead_cleanup_timer + dt

	if _dead_cleanup_timer >= DEAD_CLEANUP_INTERVAL then
		_dead_cleanup_timer = _dead_cleanup_timer % DEAD_CLEANUP_INTERVAL

		mod.remove_dead()
	end
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

mod.find_breed_category = function(unit, breed)
	if not unit then
		return nil
	end

	if mod.is_vanguard(unit) then
		return "shield"
	end

	breed = breed or mod.get_unit_breed(unit)

	if not breed then
		return nil
	end

	local tags = breed.tags

	if not tags then
		return "enemy"
	end

	if tags.horde or tags.roamer then
		if tags.far or tags.close or breed.breed_name == "renegade_assault" then
			return "ranged_horde"
		end

		return "melee_horde"
	end

	if tags.captain or tags.cultist_captain then
		return "captain"
	elseif tags.witch then
		return "witch"
	elseif tags.monster then
		return "monster"
	elseif tags.disabler then
		return "disabler"
	elseif tags.special and tags.sniper then
		return "sniper"
	elseif
		(tags.elite and tags.far)
		or (tags.special and tags.far)
		or (tags.special and tags.close)
		or (tags.elite and tags.close)
	then
		return "far"
	elseif tags.elite then
		return "elite"
	elseif tags.special then
		return "special"
	end

	return "enemy"
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

	if not health_extension:max_health() then
		return false
	end

	local difficulty = Managers.state.difficulty

	if not difficulty then
		return false
	end

	if not (breed.name and difficulty) then
		return false
	end

	local initial_max_health = math.floor(difficulty:get_minion_max_health(breed.name))

	if health_extension:max_health() < initial_max_health then
		return true
	end

	if difficulty:get_parsed_havoc_data() then
		local game_mode = Managers.state.game_mode:game_mode()

		if game_mode and game_mode.extension then
			local havoc_extension = game_mode:extension("havoc")

			if havoc_extension then
				local havoc_health_override_value = havoc_extension:get_modifier_value("modify_monster_health")

				if havoc_health_override_value then
					local multiplied_max_health = initial_max_health + initial_max_health * havoc_health_override_value

					if health_extension:max_health() < multiplied_max_health then
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
		local keywords = buff_extension.keywords
		if keywords then
			for name, _ in pairs(keywords) do
				if debuffs[name] then
					result = true
					break
				end
			end
		end

		if not result then
			local buffs = buff_extension.buffs
			if buffs then
				local num_buffs = #buffs

				for i = 1, num_buffs do
					local buff = buffs[i]
					if buff then
						local name = buff.template_name
						if name and debuffs[name] then
							result = true
							break
						end
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
