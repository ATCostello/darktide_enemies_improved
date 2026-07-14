local mod = get_mod("enemies_improved")
mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/enemies_improved_localization")

-- Cache
local Managers = Managers
mod.enemy_debuffs = mod.enemy_debuffs or {}
mod.marked_dead = mod.marked_dead or {}

local function _on_ei_marker_created(marker_id, entry, unit)
	mod._on_ei_marker_created(marker_id, entry, unit)
end

-----------------------------------------------------------------------
-- Enemy debuffs
-----------------------------------------------------------------------
local Managers_event = Managers.event

mod.update_enemy_debuffs = function(entry, t)
	local fs = mod.frame_settings

	if not fs.debuff_enable then
		return
	end

	if entry.is_horde and not fs.debuff_horde_enable then
		return
	end

	-- Per-individual debuff toggle (explicit disable overrides type)
	local breed_name = entry.breed_name
	if breed_name and fs.breed_debuff_toggle[breed_name] == false then
		return
	end

	-- Per-type debuff toggle
	local breed_type = entry.breed_type
	if breed_type and fs.breed_type_debuff_enabled[breed_type] == false then
		return
	end

	-- Safety: clear stuck pending state after short time
	if entry._ei_marker_pending and entry._ei_marker_pending_t then
		if t - entry._ei_marker_pending_t > 2 then
			entry._ei_marker_pending = nil
		end
	end

	if entry._ei_marker_pending or entry._ei_marker_created then
		return
	end

	local unit = entry.unit

	if not mod.detect_alive(unit) then
		return
	end

	local enemy_debuffs = mod.enemy_debuffs
	local marked_dead = mod.marked_dead

	if enemy_debuffs[unit] then
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
	end)
end
