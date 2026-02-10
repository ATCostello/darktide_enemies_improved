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

local HudElementWorldMarkers = require("scripts/ui/hud/elements/world_markers/hud_element_world_markers")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIScenegraph = require("scripts/managers/ui/ui_scenegraph")
local HudElementSmartTagging = require("scripts/ui/hud/elements/smart_tagging/hud_element_smart_tagging")

-- Per-frame computed settings
mod.frame_settings = {}

-- Lazy per-marker-type cache
mod.fc_typecache = {}

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
end)

-- Hook into the frame update
mod:hook_safe(CLASS.HudElementWorldMarkers, "update", function(self, dt, t)
	mod._frame_index = mod._frame_index + 1
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
			if name and string.find(name, "health_bar") then
				-- Allow custom bar
				if name and string.find(name, "health_bar") and name ~= "enemy_healthbar" then
					marker.draw = false
					marker.alpha_multiplier = 0
					marker.force_invisible = true
					marker.visibility_group = "never"
				end
			end
		end
	end
end)

-- Caching enemy markers and broadphase results
mod.enemy_cache = {}
mod.enemy_markers = {}
mod._broadphase_results = {}
mod.enemy_healthbars = {}
local healthbar_ids = {}

-- Per-frame update tracking
mod._frame_index = 0

-- Cache for dead enemies to avoid adding markers back for them
mod.marked_dead = {}

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

	-- LOS global settings
	fs.los_enabled = mod:get("los_fade_enable") == true
	fs.los_opacity = (mod:get("los_opacity") or 100) / 100
	fs.ads_los_opacity = (mod:get("ads_los_opacity") or 100) / 100
	fs.ads_blend = math.lerp(fs.ads_blend or 0, is_ads and 1 or 0, 0.25)

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
	local range = mod:get("enemy_marker_scan_range") or 60

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

-- example function, replace with real function that goes through the enemies in "scan_enemies" and either adds new debuff indicators to the enemy (needs a new ui element for a neat, world-friendly debuff indicator, showing the stacks of debuffs in an organised and decluttered way - maybe using emotes?) or updates the existing debuff indicators.
mod.update_enemy_debuffs = function()
	-- should check fs.debuffs to see if enabled...
	-- the buff extension can be found by:
	-- ScriptUnit.extension(enemy_unit, "buff_system")
end

-- update function to build the mod frame_settings, run scan, then update healthbars, markers and debuffs. This function may need to be called each time an enemy updates, so when they get hurt, a debuff applies, etc. the broadphase system seems good for this.
mod.update_enemies = function()
	build_frame_settings(mod)
	mod.scan_enemies()
	mod.update_enemy_markers()
	mod.update_enemy_healthbars() -- Add healthbar update call
	mod.update_enemy_debuffs() -- Add debuff update call
end
