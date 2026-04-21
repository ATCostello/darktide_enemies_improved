local mod = get_mod("enemies_improved")
mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/enemies_improved_localization")

-- Cache
local Managers = Managers
mod.enemy_healthbars = mod.enemy_healthbars or {}
mod.marked_dead = mod.marked_dead or {}
mod.active_markers = mod.active_markers or {}

local function _on_healthbar_created(marker_id, entry, unit)
	entry.healthbar = mod.get_marker_by_id(marker_id)
	mod.enemy_healthbars[unit] = marker_id
	mod.active_markers[marker_id] = true
	entry._healthbar_created = true
	entry._healthbar_pending = nil
	--mod:echo("Healthbar created for " .. tostring(unit) .. " (" .. marker_id .. ")")
end

-----------------------------------------------------------------------
-- Enemy healthbars
-----------------------------------------------------------------------
local Managers_event = Managers.event

mod.update_enemy_healthbars = function(entry, t)
	local fs = mod.frame_settings

	if not fs.healthbar_enable and not fs.show_damage_numbers then
		return
	end

	if entry.is_horde and (not fs.horde_enable and not fs.horde_clusters_enable) then
		return
	end

	if entry._healthbar_created or entry._healthbar_pending then
		return
	end

	local unit = entry.unit

	if fs.horde_clusters_enable then
		local cluster = mod.get_horde_cluster_for_unit(unit)
		if cluster and cluster.rep_unit ~= unit then
			return
		end
	end

	local enemy_healthbars = mod.enemy_healthbars
	local marked_dead = mod.marked_dead

	if enemy_healthbars[unit] or marked_dead[unit] then
		return
	end

	entry._healthbar_pending = true

	Managers_event:trigger("add_world_marker_unit", "enemy_healthbar", unit, function(marker_id)
		_on_healthbar_created(marker_id, entry, unit)
	end)
end
