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
mod._broadphase_results = {}
local healthbar_ids = {}
mod.marked_dead = {}

-- Global colour lookup
local COLOUR_LOOKUP = {
	Gold = { 255, 232, 188, 109 },
	Silver = { 255, 187, 198, 201 },
	Steel = { 255, 161, 166, 169 },
	Black = { 255, 35, 31, 32 },
	Brass = { 255, 226, 199, 126 },
	Terminal = Color.terminal_background(200, true),
	Default = { 255, 161, 166, 169 },
}

-- Add marker to marker templates
mod:hook_safe(CLASS.HudElementWorldMarkers, "init", function(self)
	-- add new marker templates to templates table
	self._marker_templates[EnemyMarkersTemplate.name] = EnemyMarkersTemplate
	self._marker_templates[EnemyHealthbarTemplate.name] = EnemyHealthbarTemplate
	self._marker_templates[EnemyDebuffTemplate.name] = EnemyDebuffTemplate

	-- clear caches on markers init
	table.clear(mod.enemy_markers)
	table.clear(mod.enemy_healthbars)
	table.clear(mod.enemy_debuffs)

	-- Preload views to get textures/icons, to prevent crashing.
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

-- Hook into the frame update
mod:hook_safe(CLASS.HudElementWorldMarkers, "update", function(self, dt, t)
	mod.update_enemies()

	local markers = self._markers
	if not markers then
		return
	end

	for i = 1, #markers do
		local marker = markers[i]
		if marker and marker.template then
			local name = marker.template.name

			-- Hide default health bars
			if name and string.find(name, "damage_indicator") then
				-- Allow custom bar
				if name and string.find(name, "damage_indicator") and name ~= "enemy_healthbar" then
					marker.draw = false
					marker.alpha_multiplier = 0
					marker.force_invisible = true
					marker.visibility_group = "never"
				end
			end
		end
	end
end)

-- Get type cache for marker settings
local function get_type_cache(mod, marker_type)
	local cache = mod.fc_typecache
	local tc = cache[marker_type]

	if marker_type == nil then
		return
	end

	if tc then
		return tc
	end

	tc = {
		alpha = mod:get(marker_type .. "_alpha") or 1,
		scale = (mod:get(marker_type .. "_scale") or 100) / 100,
		max_distance = mod:get(marker_type .. "_max_distance"),
		require_los = mod:get(marker_type .. "_require_line_of_sight") == true,
		keep_on_screen = mod:get(marker_type .. "_keep_on_screen") == true,
	}

	cache[marker_type] = tc
	return tc
end

-- frame settings to be used to optimise calls
local function build_frame_settings(mod)
	local fs = mod.frame_settings

	-- ADS detection ONCE per frame
	local is_ads = false
	local player = Managers.player:local_player(1)
	if player then
		local unit = player.player_unit
		if unit then
			local ude = ScriptUnit.extension(unit, "unit_data_system")
			if ude then
				local af = ude:read_component("alternate_fire")
				is_ads = af and af.is_active or false
			end
		end
	end

	fs.is_ads = is_ads
	fs.los_enabled = mod:get("los_fade_enable") == true
	fs.los_opacity = (mod:get("los_opacity") or 100) / 100
	fs.ads_los_opacity = (mod:get("ads_los_opacity") or 100) / 100
	fs.ads_blend = math.lerp(fs.ads_blend or 0, is_ads and 1 or 0, 0.25)
	fs.draw_distance = mod:get(mod:get("draw_distance")) or 50

	-- Feature toggles
	fs.enable = {
		markers = mod:get("markers_enable"),
		healthbar = mod:get("healthbar_enable"),
		debuff = mod:get("debuff_enable"),
	}
end

-- scan_enemies function: Scans for enemies and caches them using broadphase
mod.scan_enemies = function()
	local local_player = Managers.player:local_player(1)
	if not local_player then
		return
	end

	local player_unit = local_player.player_unit
	if not player_unit or not Unit.alive(player_unit) then
		return
	end

	local extension_manager = Managers.state.extension
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
	table.clear(mod._broadphase_results)

	local num_hits = broadphase.query(broadphase, from_pos, range, mod._broadphase_results, enemy_side_names)

	-- Mark all cached enemies as unseen this frame
	for unit, data in pairs(mod.enemy_cache) do
		-- Set unseen flag for dead or out of range enemies
		data.seen = false
	end

	-- Add or update enemies in the cache
	for i = 1, num_hits do
		local enemy_unit = mod._broadphase_results[i]

		if Unit.alive(enemy_unit) then
			local entry = mod.enemy_cache[enemy_unit]

			if not entry then
				mod.enemy_cache[enemy_unit] = {
					unit = enemy_unit,
					seen = true,
				}
			else
				entry.seen = true
			end
		end
	end
end

local marker_ids = {}
-- Table to map marker IDs to units
local marker_to_unit = {}

-- set_marker_id function to store marker ID and link it to the corresponding unit
local set_marker_id = function(marker_id)
	-- Find the unit associated with this marker_id from the marker_to_unit table
	for unit, stored_marker_id in pairs(marker_to_unit) do
		if stored_marker_id == marker_id then
			-- Unit found, now use the unit for further processing (e.g., removing markers)
			return unit -- Return the unit if needed
		end
	end
end

local ALERTED_MODES = {
	alerted = 5,
	directional_alerted = 3,
	hesitate = 4,
	instant_aggro = 1,
	moving_alerted = 2,
}

local get_unit_id = function(unit)
	if unit then
		return Managers.state.unit_spawner:game_object_id(unit)
	else
		return 0
	end
end

local add_unit_to_alerted = function(unit)
	if not mod.enemy_markers_alerted[get_unit_id(unit)] then
		table.insert(mod.enemy_markers_alerted, get_unit_id(unit))
		mod:echo("added unit to alerted")
	end
end

mod:hook_safe(CLASS.BtAlertedAction, "enter", function(self, unit, breed, blackboard, scratchpad, action_data, t)
	local alerted_mode = self:_select_alerted_mode(action_data)

	if alerted_mode == ALERTED_MODES.alerted then
		mod:echo("ALERTED")
		add_unit_to_alerted(unit)
	elseif alerted_mode == ALERTED_MODES.moving_alerted then
		mod:echo("MOVING ALERTED")
		add_unit_to_alerted(unit)
	elseif alerted_mode == ALERTED_MODES.hesitate then
		mod:echo("HESITATE")
		add_unit_to_alerted(unit)
	elseif alerted_mode == ALERTED_MODES.directional_alerted then
		mod:echo("DIRECTIONAL ALERTED")
		add_unit_to_alerted(unit)
	elseif alerted_mode == ALERTED_MODES.instant_aggro then
		mod:echo("INSTANT AGGRO")
		add_unit_to_alerted(unit)
	end
end)

mod:hook_safe(
	CLASS.BtAlertedAction,
	"leave",
	function(self, unit, breed, blackboard, scratchpad, action_data, t, reason, destroy)
		--template.set_alerted(false)
		mod:echo("no AGGRO")
	end
)

-- Adding markers for new enemies and storing marker_id in the map
mod.update_enemy_markers = function()
	if not mod.frame_settings.enable.markers then
		return
	end

	-- Create a list to track units to be removed
	local units_to_remove = {}

	-- First, handle the removal of markers for dead enemies
	for unit, data in pairs(mod.enemy_cache) do
		-- Check if the unit is alive
		if not Unit.alive(unit) then
			-- Immediately remove the marker when the enemy dies
			local marker_id = marker_ids[unit] -- Get marker ID from marker_ids table
			if marker_id then
				-- Trigger the event to remove the marker as soon as the enemy dies
				Managers.event:trigger("remove_world_marker", marker_id)
				mod.enemy_markers[unit] = nil -- Clear the stored marker ID
				marker_ids[unit] = nil -- Also clear the marker ID from marker_ids table
				mod.marked_dead[unit] = true -- Mark this unit as permanently dead for markers
			end
			-- Mark the unit for removal from the cache
			table.insert(units_to_remove, unit)
		else -- Check health of the unit and remove marker if health is zero
			local health_extension = ScriptUnit.has_extension(unit, "health_system")
			if health_extension then
				local health_percent = health_extension:current_health_percent()
				if health_percent <= 0 then -- Health is zero, so immediately remove the marker
					local marker_id = marker_ids[unit] -- Get marker ID from marker_ids table
					if marker_id then -- Remove the marker immediately
						Managers.event:trigger("remove_world_marker", marker_id)
						mod.enemy_markers[unit] = nil -- Clear the stored marker ID
						marker_ids[unit] = nil -- Also clear the marker ID from marker_ids table
						mod.marked_dead[unit] = true -- Mark this unit as permanently dead for markers
					end -- Mark the unit for removal from the cache
					table.insert(units_to_remove, unit)
				end
			end
		end
	end

	-- Remove dead enemies from the cache after processing
	for _, unit in ipairs(units_to_remove) do
		mod.enemy_cache[unit] = nil
	end

	-- Second, only add markers for living enemies that are not dead and removed
	for unit, data in pairs(mod.enemy_cache) do
		-- don't add markers for dead enemies or already marked as dead
		if not mod.enemy_markers[unit] and not mod.marked_dead[unit] then
			-- Trigger the event to add a marker for the unit
			Managers.event:trigger(
				"add_world_marker_unit",
				EnemyMarkersTemplate.name, -- Marker template name
				unit, -- The enemy unit
				function(marker_id)
					-- Inside this callback, store the marker_id with the unit
					marker_ids[unit] = marker_id -- Store the marker_id for the unit
					marker_to_unit[unit] = marker_id -- Link marker_id to the unit in marker_to_unit
				end
			)

			-- Save the marker ID for future reference
			mod.enemy_markers[unit] = unit
		end
	end

	-- check for alerted enemies and adjust the marker accordingly
	for unit, data in pairs(mod.enemy_cache) do
		for id, unit_id in pairs(mod.enemy_markers_alerted) do
			if unit_id == get_unit_id(unit) then
				local marker_id = marker_ids[unit] -- Get marker ID from marker_ids table

				-- need to grab marker via this id, then change the styling
				local ui_manager = Managers.ui
				local hud = ui_manager:get_hud()
				local world_markers = hud and hud:element("HudElementWorldMarkers")
				local markers_by_id = world_markers and world_markers._markers_by_id

				local marker = markers_by_id[marker_id]
				marker.widget.style.background.color = { 255, 255, 50, 50 }
			end
		end
	end
end

mod.update_enemy_healthbars = function()
	if not mod.frame_settings.enable.healthbar then
		return
	end

	local units_to_remove = {}

	-- Remove dead enemies
	for unit, data in pairs(mod.enemy_cache) do
		if not Unit.alive(unit) then
			local hb_id = healthbar_ids[unit]
			if hb_id then
				Managers.event:trigger("remove_world_marker", hb_id)
				healthbar_ids[unit] = nil
				mod.enemy_healthbars[unit] = nil
			end
			table.insert(units_to_remove, unit)
		else
			local health_ext = ScriptUnit.has_extension(unit, "health_system")
			if health_ext and health_ext:current_health_percent() <= 0 then
				local hb_id = healthbar_ids[unit]
				if hb_id then
					Managers.event:trigger("remove_world_marker", hb_id)
					healthbar_ids[unit] = nil
					mod.enemy_healthbars[unit] = nil
				end
				table.insert(units_to_remove, unit)
			end
		end
	end

	for _, unit in ipairs(units_to_remove) do
		mod.enemy_cache[unit] = nil
	end

	-- Add healthbars for living enemies
	for unit, data in pairs(mod.enemy_cache) do
		if not mod.enemy_healthbars[unit] and not mod.marked_dead[unit] then
			Managers.event:trigger("add_world_marker_unit", "enemy_healthbar", unit, function(marker_id)
				healthbar_ids[unit] = marker_id
			end)

			mod.enemy_healthbars[unit] = unit
		end
	end
end

local debuff_ids = {}
mod.update_enemy_debuffs = function()
	if not mod.frame_settings.enable.debuff then
		return
	end

	local units_to_remove = {}

	-- First, handle the removal of debuffs for dead enemies
	for unit, data in pairs(mod.enemy_cache) do
		-- Check if the unit is alive
		if not Unit.alive(unit) then
			-- Immediately remove the debuff when the enemy dies
			local debuff_id = debuff_ids[unit] -- Get debuff ID from debuff_ids table
			if debuff_id then
				-- Trigger the event to remove the debuff as soon as the enemy dies
				Managers.event:trigger("remove_world_marker", debuff_id)
				mod.enemy_debuffs[unit] = nil -- Clear the stored debuff ID
				debuff_ids[unit] = nil -- Also clear the debuff ID from debuff_ids table
				mod.marked_dead[unit] = true -- Mark this unit as permanently dead for debuffs
			end
			-- Mark the unit for removal from the cache
			table.insert(units_to_remove, unit)
		else
			-- Check the health of the unit and remove debuff if health is zero
			local health_extension = ScriptUnit.has_extension(unit, "health_system")
			if health_extension then
				local health_percent = health_extension:current_health_percent()
				if health_percent <= 0 then -- Health is zero, so immediately remove the debuff
					local debuff_id = debuff_ids[unit] -- Get debuff ID from debuff_ids table
					if debuff_id then -- Remove the debuff immediately
						Managers.event:trigger("remove_world_marker", debuff_id)
						mod.enemy_debuffs[unit] = nil -- Clear the stored debuff ID
						debuff_ids[unit] = nil -- Also clear the debuff ID from debuff_ids table
						mod.marked_dead[unit] = true -- Mark this unit as permanently dead for debuffs
					end
					-- Mark the unit for removal from the cache
					table.insert(units_to_remove, unit)
				end
			end
		end
	end

	-- Remove dead enemies from the cache after processing
	for _, unit in ipairs(units_to_remove) do
		mod.enemy_cache[unit] = nil
	end

	-- Second, only add debuffs for living enemies that are not dead and removed
	for unit, data in pairs(mod.enemy_cache) do
		-- Don't add debuffs for dead enemies or already marked as dead
		if not mod.enemy_debuffs[unit] and not mod.marked_dead[unit] then
			-- Trigger the event to add a debuff for the unit
			Managers.event:trigger(
				"add_world_marker_unit",
				"enemy_debuff", -- Debuff template name
				unit, -- The enemy unit
				function(debuff_id)
					-- Inside this callback, store the debuff_id with the unit
					debuff_ids[unit] = debuff_id -- Store the debuff_id for the unit
					marker_to_unit[unit] = debuff_id -- Link debuff_id to the unit in marker_to_unit
				end
			)

			-- Save the debuff ID for future reference
			mod.enemy_debuffs[unit] = unit
		end
	end
end

mod.clear_caches = function()
	table.clear(mod.enemy_markers)
	table.clear(mod.enemy_healthbars)
	table.clear(mod.enemy_debuffs)
	table.clear(healthbar_ids)
end

-- update function to build the mod frame_settings, run scan, then update healthbars, markers and debuffs. This function may need to be called each time an enemy updates, so when they get hurt, a debuff applies, etc. the broadphase system seems good for this.
mod.update_enemies = function()
	build_frame_settings(mod)
	mod.scan_enemies()
	mod.update_enemy_markers()
	mod.update_enemy_healthbars() -- Add healthbar update call
	mod.update_enemy_debuffs() -- Add debuff update call
end

mod.on_setting_changed = function(setting_id)
	mod.clear_caches()
end
