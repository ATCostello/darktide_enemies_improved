local mod = get_mod("enemies_improved")
mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/enemies_improved_localization")

-- Cache
local Managers = Managers
mod.enemy_debuffs = mod.enemy_debuffs or {}
mod.marked_dead = mod.marked_dead or {}
mod.active_markers = mod.active_markers or {}

local function _on_debuff_created(debuff_id, entry, unit)
	entry.dot_debuffs = mod.get_marker_by_id(debuff_id)
	mod.enemy_debuffs[unit] = debuff_id
	mod.active_markers[debuff_id] = true
	entry._debuff_pending = nil
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

	if entry._debuff_pending then
		return
	end

	local unit = entry.unit

	local enemy_debuffs = mod.enemy_debuffs
	local marked_dead = mod.marked_dead

	if enemy_debuffs[unit] then
		return
	end

	-- Only block if ACTUALLY dead
	if mod.marked_dead[unit] and not mod.detect_alive(unit) then
		return
	end

	entry._debuff_pending = true

	Managers_event:trigger("add_world_marker_unit", "enemy_debuff", unit, function(debuff_id)
		_on_debuff_created(debuff_id, entry, unit)
	end)
end
