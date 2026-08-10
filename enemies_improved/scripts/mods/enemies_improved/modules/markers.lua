local mod = get_mod("enemies_improved")
mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/enemies_improved_localization")

-- Cache
local Managers = Managers
mod.enemy_markers = mod.enemy_markers or {}
mod.marked_dead = mod.marked_dead or {}

local function _on_ei_marker_created(marker_id, entry, unit)
	mod._on_ei_marker_created(marker_id, entry, unit)
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

	-- Safety: clear stuck pending state after short time
	if entry._ei_marker_pending and entry._ei_marker_pending_t then
		if t - entry._ei_marker_pending_t > 2 then
			entry._ei_marker_pending = nil
		end
	end

	--local unit_data_extension = ScriptUnit.extension(unit, "unit_data_system")
	--local breed = unit_data_extension and unit_data_extension:breed()
	--local enemy_individual = breed and breed.name

	-- Horde filter: block unless horde enabled, clusters enabled, an individual or group override is on, or debuffed
	local breed_name = entry.breed_name
	local individual_enabled = breed_name and fs.breed_marker_toggle and fs.breed_marker_toggle[breed_name]
	local group_enabled = fs.breed_marker_type_enabled and fs.breed_marker_type_enabled["horde"]
	local unit = entry.unit
	local debuffed_override = fs.hb_show_when_debuffed and mod.unit_has_active_debuff(unit)

	if
		entry.is_horde
		and (not fs.markers_horde_enable)
		and not individual_enabled
		and not group_enabled
		and not debuffed_override
	then
		return
	end

	if
		not entry.is_horde
		and (not fs.markers_non_horde_enable)
		and not individual_enabled
		and not group_enabled
		and not debuffed_override
	then
		return
	end

	if entry._ei_marker_created or entry._ei_marker_pending then
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

	entry._ei_marker_pending = true
	entry._ei_marker_pending_t = t

	event_manager:trigger("add_world_marker_unit", "enemies_improved", unit, function(marker_id)
		_on_ei_marker_created(marker_id, entry, unit)
	end)
end
