local mod = get_mod("enemies_improved")
mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/enemies_improved_localization")

-- Cache
local Managers = Managers
mod.enemy_markers = mod.enemy_markers or {}
mod.marked_dead = mod.marked_dead or {}
mod.active_markers = mod.active_markers or {}

local function _on_marker_created(marker_id, entry, unit)
	entry.marker = mod.get_marker_by_id(marker_id)
	mod.enemy_markers[unit] = marker_id
	mod.active_markers[marker_id] = true
	entry._marker_created = true
	entry._marker_pending = nil
end

-------------------------------------------------------------------
-- Enemy Markers
-------------------------------------------------------------------
mod.update_enemy_markers = function(entry, t)
	local fs = mod.frame_settings
	local unit = entry.unit

	if not unit then
		return
	end

	local unit_data_extension = ScriptUnit.extension(unit, "unit_data_system")
	local breed = unit_data_extension and unit_data_extension:breed()
	local enemy_individual = breed and breed.name

	-- Check individual toggle
	local individual_enabled = false
	if enemy_individual then
		local setting = mod:get("markers_" .. enemy_individual .. "_toggle")
		if setting == true then
			individual_enabled = true
		end
	end

	-- Allow if global enabled OR individual override enabled
	if not fs.markers_enable and not individual_enabled then
		return
	end

	-- Horde filter
	if entry.is_horde and not fs.markers_horde_enable then
		return
	end

	if entry._marker_created or entry._marker_pending then
		return
	end

	local enemy_markers = mod.enemy_markers
	local marked_dead = mod.marked_dead

	if enemy_markers[unit] then
		return
	end

	-- Only block if ACTUALLY dead
	if mod.marked_dead[unit] and not mod.detect_alive(unit) then
		return
	end

	local event_manager = Managers.event
	if not event_manager then
		return
	end

	entry._marker_pending = true

	event_manager:trigger("add_world_marker_unit", "enemy_markers", unit, function(marker_id)
		_on_marker_created(marker_id, entry, unit)
	end)
end
