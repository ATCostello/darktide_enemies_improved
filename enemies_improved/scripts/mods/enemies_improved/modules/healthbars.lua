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

	local unit = entry.unit

	-- Handle cluster invalidation
	if mod.frame_settings.horde_clusters_enable and entry.is_horde then
		local cluster = mod.get_horde_cluster_for_unit(unit)

		-- If this unit HAD a healthbar but is no longer a valid cluster rep then remove it
		if entry._healthbar_created then
			if not cluster or cluster.rep_unit ~= unit then
				local marker_id = mod.enemy_healthbars[unit]

				if marker_id then
					Managers.event:trigger("remove_world_marker", marker_id)
					mod.active_markers[marker_id] = nil
					mod.enemy_healthbars[unit] = nil
				end

				entry._healthbar_created = false
				entry._healthbar_pending = nil

				return
			end
		end
	end

	if entry._healthbar_created or entry._healthbar_pending then
		return
	end

	if fs.horde_clusters_enable and entry.is_horde then
		local cluster = mod.get_horde_cluster_for_unit(unit)

		-- If clustering is enabled but no cluster yet, DO NOT create bars
		if not cluster then
			return
		end

		-- Only the representative unit is allowed to create a healthbar
		if cluster.rep_unit ~= unit then
			return
		end

		-- Prevent duplicate creation for same cluster
		if cluster._healthbar_created then
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

		-- Mark cluster as having a healthbar
		if mod.frame_settings.horde_clusters_enable and entry.is_horde then
			local cluster = mod.get_horde_cluster_for_unit(unit)
			if cluster then
				cluster._healthbar_created = true
				cluster._healthbar_marker_id = marker_id
			end
		end
		-- DEBUG
		if mod.DEBUG then
			-- debug to add outlines to enemies that have been processed, and should have a healthbar...
			local extension_manager = Managers.state.extension
			mod.add_outline(unit, "enemies_improved_alert", extension_manager:system("outline_system"))
		end
	end)
end
