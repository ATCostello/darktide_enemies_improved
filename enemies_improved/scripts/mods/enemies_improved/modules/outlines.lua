local mod = get_mod("enemies_improved")
mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/enemies_improved_localization")

-- Cache frequently used globals
local Managers = Managers
local Unit = Unit
local World = World
local PhysicsWorld = PhysicsWorld
local ScriptUnit = ScriptUnit
local Vector3 = Vector3
local next = next
local Unit_alive = Unit.alive
local Managers_ui = Managers.ui

-- Cached systems
local _outline_system = nil
local _outline_system_checked = false
local fs = mod.frame_settings

local function get_outline_system()
	local extension_manager = Managers.state.extension

	if not extension_manager then
		return nil
	end

	if not extension_manager:has_system("outline_system") then
		return nil
	end

	return extension_manager:system("outline_system")
end

mod.remove_outline = function(unit, outline, outline_system)
	if unit and outline and outline_system and Unit.alive(unit) then
		outline_system:remove_outline(unit, outline)
	end
end

mod.add_outline = function(unit, outline, outline_system)
	if unit and outline and outline_system and Unit.alive(unit) then
		outline_system:add_outline(unit, outline)
	end
end

mod.enable_enemy_outlines = function(unit, entry)
	if not Unit.alive(unit) then
		return
	end

	if not entry or not entry.breed then
		return
	end

	local outline_system = get_outline_system()
	if not outline_system then
		return
	end

	local breed = entry.breed
	local breed_name = breed and breed.name
	local breed_type = entry.breed_type or "enemy"

	-- INDIVIDUAL OVERRIDE
	if breed_name then
		local key = "outline_" .. breed_name .. "_enable"
		if mod:get(key) then
			local outline_name = entry._outline_name_individual
			if not outline_name then
				outline_name = "enemies_" .. breed_name
				entry._outline_name_individual = outline_name
			end

			mod.remove_outline(unit, outline_name, outline_system)
			mod.add_outline(unit, outline_name, outline_system)

			return
		end
	end

	-- CATEGORY
	if mod:get("outline_" .. breed_type .. "_enable") then
		local outline_name = entry._outline_name_type
		if not outline_name then
			outline_name = "enemies_" .. breed_type
			entry._outline_name_type = outline_name
		end

		mod.remove_outline(unit, outline_name, outline_system)
		mod.add_outline(unit, outline_name, outline_system)
	end
end

mod.disable_enemy_outlines = function(unit, entry)
	if not Unit.alive(unit) then
		return
	end

	local outline_system = get_outline_system()
	if not outline_system then
		return
	end

	local breed_type = entry.breed_type or "enemy"
	local breed = entry.breed
	local breed_name = breed and breed.name

	local type_outline = entry._outline_name_type or ("enemies_" .. breed_type)
	mod.remove_outline(unit, type_outline, outline_system)

	if breed_name then
		local individual_outline = entry._outline_name_individual or ("enemies_" .. breed_name)
		mod.remove_outline(unit, individual_outline, outline_system)
	end
end

mod.pulse_enemy_outline = function(entry)
	local outline_system = get_outline_system()
	if not outline_system then
		return
	end

	local unit = entry.unit
	if not unit or not Unit.alive(unit) then
		return
	end

	if entry.special_attack_imminent then
		if not entry.alert_outline then
			if fs.outline_specials_enable then
				mod.add_outline(unit, "enemies_improved_alert", outline_system)
			end
			entry.alert_outline = true
		elseif fs.specials_flash then
			mod.remove_outline(unit, "enemies_improved_alert", outline_system)
			entry.alert_outline = false
		end
	elseif entry.staggered then
		if
			(entry.is_horde and fs.outline_stagger_horde_enable) or (not entry.is_horde and fs.outline_stagger_enable)
		then
			if not entry.stagger_outline then
				mod.add_outline(unit, "enemies_improved_staggered", outline_system)
				entry.stagger_outline = true
			elseif fs.stagger_flash then
				mod.remove_outline(unit, "enemies_improved_staggered", outline_system)
				entry.stagger_outline = false
			end
		end
	else
		mod.remove_outline(unit, "enemies_improved_alert", outline_system)
		mod.remove_outline(unit, "enemies_improved_staggered", outline_system)
		entry.alert_outline = false
		entry.stagger_outline = false
	end
end

mod.remove_stagger_outline = function(entry)
	local outline_system = get_outline_system()
	if not outline_system then
		return
	end

	local unit = entry.unit
	if not unit or not Unit.alive(unit) then
		return
	end

	if entry.stagger_outline then
		mod.remove_outline(unit, "enemies_improved_staggered", outline_system)
		entry.stagger_outline = false
	end
end

mod.remove_alert_outline = function(entry)
	local outline_system = get_outline_system()
	if not outline_system then
		return
	end

	local unit = entry.unit
	if not unit or not Unit.alive(unit) then
		return
	end

	if entry.alert_outline then
		mod.remove_outline(unit, "enemies_improved_alert", outline_system)
		entry.alert_outline = false
	end
end

mod.has_line_of_sight = function(player_unit, enemy_unit, physics_world)
	if not player_unit or not enemy_unit then
		return false
	end

	if not Unit.alive(player_unit) or not Unit.alive(enemy_unit) then
		return false
	end

	local unit_data_extension = ScriptUnit.has_extension(player_unit, "unit_data_system")
	if not unit_data_extension then
		return false
	end
	local first_person_component = unit_data_extension:read_component("first_person")
	local player_pos = first_person_component.position

	local node = Unit.has_node(enemy_unit, "j_head") and Unit.node(enemy_unit, "j_head") or 0
	local enemy_pos = Unit.world_position(enemy_unit, node)

	local direction = enemy_pos - player_pos
	local distance_sq = Vector3.length_squared(direction)

	-- avoid sqrt unless needed
	if distance_sq == 0 then
		return true
	end

	local distance = math.sqrt(distance_sq)
	local dir = direction / distance

	local hit = PhysicsWorld.raycast(
		physics_world,
		player_pos,
		dir,
		distance,
		"closest",
		"collision_filter",
		"filter_minion_line_of_sight_check"
	)

	if not hit then
		return true
	end

	if type(hit) == "table" then
		local actor = hit[4]
		local hit_unit = actor and Actor.unit(actor)
		return hit_unit == enemy_unit
	end

	return false
end

mod.get_forward_dot = function(player_unit, enemy_unit)
	if not player_unit or not enemy_unit then
		return 0
	end

	if not Unit_alive(player_unit) or not Unit_alive(enemy_unit) then
		return 0
	end

	local ui_manager = Managers_ui
	local hud = ui_manager and ui_manager:get_hud()
	local world_markers = hud and hud:element("HudElementWorldMarkers")
	if not world_markers then
		return 1
	end

	local camera = world_markers:_get_camera()
	if not camera then
		return 1
	end

	local camera_position = Camera.local_position(camera)
	local camera_rotation = Camera.local_rotation(camera)
	local forward = Quaternion.forward(camera_rotation)

	--local forward = Quaternion.forward(Unit.local_rotation(player_unit, 1))

	-- Positions
	local player_pos = POSITION_LOOKUP[player_unit]
	local enemy_pos = POSITION_LOOKUP[enemy_unit]

	if not player_pos or not enemy_pos then
		return 0
	end

	-- Flattened direction
	local to_enemy = Vector3.flat(enemy_pos - player_pos)

	local len_sq = Vector3.length_squared(to_enemy)
	if len_sq == 0 then
		return 1
	end

	to_enemy = to_enemy / math.sqrt(len_sq)

	local dot = Vector3.dot(forward, to_enemy)

	return dot
end

mod.update_enemy_outlines = function(entry)
	if not fs.outlines_enable then
		return
	end

	local unit = entry.unit
	if not unit or not Unit.alive(unit) then
		return
	end

	local player = Managers.player:local_player(1)
	local player_unit = player and player.player_unit
	if not player_unit or not mod.detect_alive(player_unit) then
		return
	end

	local world = Managers.world:world("level_world")
	local physics_world = World.get_data(world, "physics_world")

	local has_los = mod.has_line_of_sight(player_unit, unit, physics_world)

	if entry._outline_applied == nil then
		entry._outline_applied = false
	end

	--local is_tagged = mod.tagged_units[unit]

	local smart_tag_system = Managers.state.extension:system("smart_tag_system")
	local tag_id = smart_tag_system:unit_tag_id(unit)
	local is_tagged = tag_id ~= nil

	if has_los then
		if not entry._outline_applied and not is_tagged then
			mod.enable_enemy_outlines(unit, entry)
			entry._outline_applied = true
		end
	elseif entry._outline_applied then
		mod.disable_enemy_outlines(unit, entry)
		entry._outline_applied = false
	end

	-- reapply after tagged
	if is_tagged then
		entry._outline_applied = false
	end
end

-- OUTLINES
mod.default_outline_enabled = {
	horde = false,
	monster = false,
	captain = false,
	disabler = false,
	witch = false,
	sniper = false,
	far = false,
	elite = false,
	special = false,
	enemy = false,
}

mod.apply_enemy_outlines = function(settings)
	for _, entry in next, mod.breed_types do
		local breed = entry.value

		if breed ~= "select" then
			local key = "outline_" .. breed .. "_enable"
			local enabled = mod:get(key)

			-- set default from above table if not expicitly set yet.
			if enabled == nil then
				enabled = mod.default_outline_enabled[breed]

				if enabled == nil then
					enabled = true
				end

				mod:set(key, enabled)
			end

			local r = mod:get("outline_" .. breed .. "_colour_R")
			local g = mod:get("outline_" .. breed .. "_colour_G")
			local b = mod:get("outline_" .. breed .. "_colour_B")

			-- initialise to defaults if nil values...
			if r == nil or g == nil or b == nil then
				r = mod.OUTLINE_COLOURS_DEFAULT[breed][2]
				mod:set("outline_" .. breed .. "_colour_R", r)
				g = mod.OUTLINE_COLOURS_DEFAULT[breed][3]
				mod:set("outline_" .. breed .. "_colour_G", g)
				b = mod.OUTLINE_COLOURS_DEFAULT[breed][4]
				mod:set("outline_" .. breed .. "_colour_B", b)
			end

			if enabled then
				if not r then
					r = 50
				end
				if not g then
					g = 10
				end
				if not b then
					b = 0
				end

				r = r / 255
				g = g / 255
				b = b / 255

				settings.MinionOutlineExtension["enemies_" .. breed] = {
					priority = 4,
					material_layers = {
						"minion_outline",
						"minion_outline_reversed_depth",
					},
					color = { r, g, b },
					visibility_check = function()
						return true
					end,
				}
			else
				-- remove if disabled
				settings.MinionOutlineExtension["enemies_" .. breed] = nil
			end
		end
	end

	-- INDIVIDUAL COLOUR OVERRIDES
	for _, options in next, mod.breed_names do
		local enemy_individual = options.value

		if enemy_individual then
			local key = "outline_" .. enemy_individual .. "_enable"
			local enabled = mod:get(key)

			if enabled and mod.OUTLINE_COLOURS_OVERRIDE[enemy_individual] then
				local r = mod.OUTLINE_COLOURS_OVERRIDE[enemy_individual][2]
				local g = mod.OUTLINE_COLOURS_OVERRIDE[enemy_individual][3]
				local b = mod.OUTLINE_COLOURS_OVERRIDE[enemy_individual][4]

				if not r then
					r = 50
				end
				if not g then
					g = 10
				end
				if not b then
					b = 0
				end

				r = r / 255
				g = g / 255
				b = b / 255

				settings.MinionOutlineExtension["enemies_" .. enemy_individual] = {
					priority = 3,
					material_layers = {
						"minion_outline",
						"minion_outline_reversed_depth",
					},
					color = { r, g, b },

					visibility_check = function(unit)
						if not Unit.alive(unit) then
							return false
						end

						local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
						if not unit_data then
							return false
						end

						local breed = unit_data:breed()
						if not breed then
							return false
						end

						if breed.name ~= enemy_individual then
							return false
						end

						return mod:get("outline_" .. enemy_individual .. "_enable")
					end,
				}
			end
		end
	end

	-- SPECIAL ATTACK OUTLINE
	local sr = (mod:get("outline_specials_colour_R"))
	local sg = (mod:get("outline_specials_colour_G"))
	local sb = (mod:get("outline_specials_colour_B"))

	if not sr then
		sr = 255
	end
	if not sg then
		sg = 0
	end
	if not sb then
		sb = 0
	end

	sr = sr / 255
	sg = sg / 255
	sb = sb / 255

	settings.MinionOutlineExtension.enemies_improved_alert = {
		priority = 1,
		material_layers = {
			"minion_outline",
			"minion_outline_reversed_depth",
		},
		color = { sr, sg, sb },
		visibility_check = function()
			return true
		end,
	}

	-- STAGGERED OUTLINE

	sr = fs.outline_stagger_colour[2] / 255
	sg = fs.outline_stagger_colour[3] / 255
	sb = fs.outline_stagger_colour[4] / 255

	settings.MinionOutlineExtension.enemies_improved_staggered = {
		priority = 2,
		material_layers = {
			"minion_outline",
			"minion_outline_reversed_depth",
		},
		color = { sr, sg, sb },
		visibility_check = function()
			return true
		end,
	}
end

mod:hook_require("scripts/settings/outline/outline_settings", function(settings)
	mod.apply_enemy_outlines(settings)
end)
