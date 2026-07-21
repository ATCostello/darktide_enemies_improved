local mod = get_mod("enemies_improved")
mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/enemies_improved_localization")

local table_remove = table.remove
local table_index_of = table.index_of

-- Cache
local Managers = Managers
mod.enemy_healthbars = mod.enemy_healthbars or {}
mod.marked_dead = mod.marked_dead or {}

local function _on_ei_marker_created(marker_id, entry, unit)
	mod._on_ei_marker_created(marker_id, entry, unit)
end

-----------------------------------------------------------------------
-- Enemy healthbars
-----------------------------------------------------------------------
local Managers_event = Managers.event

mod.update_enemy_healthbars = function(entry, t)
	local fs = mod.frame_settings

	-- Safety: clear stuck pending state after short time
	if entry._ei_marker_pending and entry._ei_marker_pending_t then
		if t - entry._ei_marker_pending_t > 2 then
			entry._ei_marker_pending = nil
		end
	end

	if not fs.healthbar_enable and not fs.show_damage_numbers then
		return
	end

	if fs.healthbar_only_in_meatgrinder then
		local current_level = Managers.state.mission and Managers.state.mission:mission()
		if not (current_level and current_level.game_mode_name and current_level.game_mode_name == "shooting_range") then
			return
		end
	end

	if entry.is_horde and (not fs.horde_enable and not fs.horde_clusters_enable) then
		return
	end

	local unit = entry.unit

	-- Handle cluster invalidation: non-rep horde units should not have a healthbar,
	-- but the world marker must stay alive so overhead markers and debuffs still work.
	if mod.frame_settings.horde_clusters_enable and entry.is_horde then
		local cluster = mod.get_horde_cluster_for_unit(unit)

		if entry._ei_marker_created then
			if not cluster or cluster.rep_unit ~= unit then
				mod.enemy_healthbars[unit] = nil
				return
			end
		end
	end

	if entry._ei_marker_created or entry._ei_marker_pending then
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

	if enemy_healthbars[unit] then
		return
	end

	-- Only block if ACTUALLY dead
	if mod.marked_dead[unit] and not mod.detect_alive(unit) then
		return
	end

	entry._ei_marker_pending = true
	entry._ei_marker_pending_t = t

	Managers_event:trigger("add_world_marker_unit", "enemies_improved", unit, function(marker_id)
		_on_ei_marker_created(marker_id, entry, unit)

		-- Mark cluster as having a healthbar
		if mod.frame_settings.horde_clusters_enable and entry.is_horde then
			local cluster = mod.get_horde_cluster_for_unit(unit)
			if cluster then
				cluster._healthbar_created = true
				cluster._healthbar_marker_id = marker_id
			end
		end
	end)
end
