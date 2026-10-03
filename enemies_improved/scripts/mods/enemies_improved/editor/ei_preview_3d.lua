-- Enemies Improved editor: 3D enemy for the preview panel.
--
-- One level-less UIWorldSpawner world + one viewport (rect = the preview stage) + one spawned minion
-- (base unit + state machine + the wielded/body items of its visual loadout) with the same outline
-- material layers the real OutlineSystem toggles. The world carries a small light rig of its own
-- (see LIGHT_RIG), a level-less world has nothing lighting it.
--
-- An unloaded resource crashes the engine and pcall cannot catch that, so:
--  * every unit / package is gated with Application.can_get_resource, a unit is only spawned after the
--    packages report loaded, partially resident items are dropped instead of spawned;
--  * a persisted crash guard (ei_preview_3d_pending) disables 3D after an attempt that never finished;
--  * mod:info breadcrumbs ("[ei_preview] ...") name the last step before a crash;
--  * every engine call that can raise a Lua error is pcall'd; destroy is idempotent.
--
-- Public API (used by ei_preview.lua):
--   P3D.supported(breed) -> ok, reason       P3D.pending() -> breed name | nil
--   P3D.trip_guard() -> name, disabled_all   (previous attempt never finished: block that enemy, or 3D, clear, save)
--   P3D.clear_blocked()                      (user re-enabled 3D: retry blocked enemies)
--   P3D.new(view)       -> obj | nil, reason
--   obj:set_breed(breed_name)   obj:set_rect(x, y, w, h, aspect)  (0..1 screen fractions)
--   obj:set_outline(r, g, b | nil)   obj:set_yaw(rad)   obj:update(dt, t)
--   obj:state() -> "idle" | "loading" | "ready" | "failed", reason
--   obj:frame() -> centre_z, visible_span_z (world metres, valid when ready)   obj:destroy()

local mod = get_mod("enemies_improved")

local P3D = {}
P3D.__index = P3D

local PENDING_KEY = "ei_preview_3d_pending"
local PACKAGE_REF = "enemies_improved_preview"
-- the weapon preview puts its item world at view layer + 35 (view_element_inventory_weapon_preview.lua:13);
-- the 2D overlay (ei_preview.lua) sits above at +45
local WORLD_LAYER = 35
local CAMERA_FOV = 30 -- vertical degrees (UIWorldSpawner._set_fov takes degrees, ui_world_spawner.lua:515)
local GUARD_FRAMES = 30
local LOAD_TIMEOUT = 30
local SPAWN_SEED = 7
local BASE_YAW = math.pi + 0.45 -- minion units face +y, the camera looks along +y from -y: turn around, 3/4 view
-- a minion state machine runs a looping idle, so the model never stops moving and the preview smears;
-- let the spawn animation play, then hold the pose (same call ui_profile_spawner.lua:1422 uses on a slot)
local FREEZE_ANIM_DELAY = 0.8
-- The preview world is level-less, so nothing lights the models; the vanilla item / character previews get their
-- lights by spawning a level. Core light units do the same job here: a fixed key / fill / rim rig around the
-- enemy, which stands at the origin, so a model reads the same whatever it is up to. Omni on purpose, a spot or
-- directional one would depend on the light unit's forward axis.
-- { position, colour, intensity, falloff_end } - intensities and ranges in the same ballpark as the lantern mods.
local LIGHT_UNIT = "core/units/light"
local LIGHT_FALLOFF_START = 1
local LIGHT_RIG = {
	{ Vector3(-1.1, -1.5, 2.3), { 1, 0.95, 0.88 }, 250, 12 }, -- key, warm, high front left
	{ Vector3(1.5, -1.3, 1.1), { 0.72, 0.8, 1 }, 90, 10 }, -- fill, cool, low front right
	{ Vector3(0.4, 2.2, 1.9), { 0.85, 0.9, 1 }, 140, 11 }, -- rim, from behind
}
-- same layers OutlineSystem toggles for minions (scripts/settings/outline/outline_settings.lua:33-34)
local OUTLINE_LAYERS = { "minion_outline", "minion_outline_reversed_depth" }

local world_counter = 0

local function crumb(msg)
	mod:info("[ei_preview] %s", msg)
end

local function save_settings()
	local S = mod.settings_api

	if S and S.save then
		pcall(S.save)

		return
	end

	local dmf = get_mod("DMF")

	if dmf and dmf.save_unsaved_settings_to_file then
		pcall(dmf.save_unsaved_settings_to_file)
	end
end

local function set_pending(value)
	if mod:get(PENDING_KEY) ~= value then
		mod:set(PENDING_KEY, value)
		save_settings()
	end
end

-- Application.can_get_resource(type, name): true only when the resource is resident (decal_manager.lua:75 uses
-- the "package" type; "unit" is the engine resource type name). A wrong type string just returns false.
local function can_get(kind, name)
	if not name or name == "" then
		return false
	end

	local ok, res = pcall(Application.can_get_resource, kind, name)

	return (ok and res) and true or false
end

-----------------------------------------------------------------------
-- Game modules (lazy: a missing/changed module must degrade to "3D unavailable", not break mod load)
-----------------------------------------------------------------------

local deps, deps_error

local function get_deps()
	if deps then
		return deps
	end

	if deps_error then
		return nil, deps_error
	end

	local ok, res = pcall(function()
		return {
			UIWorldSpawner = require("scripts/managers/ui/ui_world_spawner"),
			MinionVisualLoadout = require("scripts/utilities/minion_visual_loadout"),
			VisualLoadoutCustomization = require(
				"scripts/extension_systems/visual_loadout/utilities/visual_loadout_customization"
			),
			VisualLoadoutLodGroup = require(
				"scripts/extension_systems/visual_loadout/utilities/visual_loadout_lod_group"
			),
			ItemPackage = require("scripts/foundation/managers/package/utilities/item_package"),
			MasterItems = require("scripts/backend/master_items"),
			Items = require("scripts/utilities/items"),
			BreedQueries = require("scripts/utilities/breed_queries"),
		}
	end)

	if ok then
		deps = res

		return deps
	end

	deps_error = "game modules: " .. tostring(res)

	return nil, deps_error
end

-----------------------------------------------------------------------
-- Static helpers
-----------------------------------------------------------------------

-- Units of script-component breeds (beast of nurgle) can fire the script-component flow nodes. In a UI world those
-- run UIFlowCallbacks.enable_script_component & co, which index the world's extension manager
-- (ui_flow_callbacks.lua:58-93); a level-less preview world has none -> nil index error inside the spawn.
-- Wrap them ONCE on the global table (flag on the table survives mod reloads; DMF warns on re-hooking) so they are
-- no-ops for worlds without an extension manager. Worlds that have one (vanilla UI levels) are unchanged.
local FLOW_COMPONENT_CALLBACKS = {
	"enable_script_component",
	"disable_script_component",
	"call_script_component",
	"register_extensions",
	"delete_extension_registered_unit",
}

local function context_world_has_extension_manager()
	return Managers.ui:world_extension_manager(Application.flow_callback_context_world()) ~= nil
end

local function install_flow_guard()
	local callbacks = rawget(_G, "UIFlowCallbacks")

	if not callbacks or rawget(callbacks, "__ei_preview_guarded") then
		return
	end

	callbacks.__ei_preview_guarded = true

	for i = 1, #FLOW_COMPONENT_CALLBACKS do
		local name = FLOW_COMPONENT_CALLBACKS[i]
		local orig = callbacks[name]

		if type(orig) == "function" then
			callbacks[name] = function(params)
				local ok, has = pcall(context_world_has_extension_manager)

				if ok and has then
					return orig(params)
				end
			end
		end
	end
end

local BLOCK_KEY = "ei_preview_3d_blocked"

function P3D.supported(breed)
	if not breed then
		return false, "unknown enemy"
	end

	if not breed.base_unit or breed.base_unit == "" then
		return false, "no model"
	end

	local blocked = mod:get(BLOCK_KEY)

	if type(blocked) == "table" and blocked[breed.name] then
		return false, "skipped after a crash (toggle 3D to retry)"
	end

	return true
end

function P3D.pending()
	return mod:get(PENDING_KEY)
end

-- The previous attempt never finished. A named enemy only blocks that enemy; a world-level failure, or a second
-- blocked enemy (the world itself is the likely culprit), turns 3D off. Returns name, disabled_all.
function P3D.trip_guard()
	local name = mod:get(PENDING_KEY)
	local disable_all = true

	if type(name) == "string" and name ~= "(world)" then
		local blocked = mod:get(BLOCK_KEY)

		blocked = type(blocked) == "table" and blocked or {}

		if next(blocked) == nil then
			disable_all = false
		end

		blocked[name] = true

		mod:set(BLOCK_KEY, blocked)
	end

	if disable_all then
		mod:set("ei_preview_3d_enabled", false)
	end

	mod:set(PENDING_KEY, nil)
	save_settings()

	return name, disable_all
end

-- the user re-enabled 3D: give every enemy another try
function P3D.clear_blocked()
	if mod:get(BLOCK_KEY) ~= nil then
		mod:set(BLOCK_KEY, nil)
		save_settings()
	end
end

-----------------------------------------------------------------------
-- Creation / teardown
-----------------------------------------------------------------------

function P3D.new(view)
	local d, err = get_deps()

	if not d then
		return nil, err
	end

	if not (Managers.ui and Managers.package and Application.can_get_resource and GameParameters) then
		return nil, "engine managers missing"
	end

	install_flow_guard()

	world_counter = world_counter + 1

	local self = setmetatable({
		view = view,
		world_name = "ei_preview_world_" .. world_counter,
		viewport_name = "ei_preview_viewport_" .. world_counter,
		_state = "idle",
		_ids = {},
		_wait = {},
		_parts = {},
		_frames = 0,
		_yaw = 0,
		aspect = 0.8,
	}, P3D)

	set_pending("(world)")
	crumb("create world " .. self.world_name)

	-- level-less world, default flags = proven path (ui_world_spawner.lua:11-24, 291-302)
	local ok, ws = pcall(d.UIWorldSpawner.new, d.UIWorldSpawner, self.world_name, WORLD_LAYER, "ui", view.view_name)

	if not ok or not ws then
		set_pending(nil)

		return nil, "world: " .. tostring(ws)
	end

	self.ws = ws
	self._guard_set = true

	crumb("create viewport")

	-- camera_unit nil: ScriptWorld.create_viewport spawns core/units/camera itself (script_world.lua:60-64);
	-- the always-resident default UI shading environment (default_game_parameters.lua:45)
	local vok, vres = pcall(
		ws.create_viewport,
		ws,
		nil,
		self.viewport_name,
		"default_with_alpha",
		1,
		GameParameters.default_ui_shading_environment
	)

	if not vok then
		pcall(ws.destroy, ws)

		self.ws = nil

		set_pending(nil)

		return nil, "viewport: " .. tostring(vres)
	end

	-- _set_fov(deg): a raw Camera.set_vertical_fov would be overwritten by UIWorldSpawner._update_camera every frame
	pcall(ws._set_fov, ws, CAMERA_FOV)
	pcall(ws.set_viewport_size, ws, 0.01, 0.01)
	pcall(ws.set_viewport_position, ws, 0, 0)
	pcall(ws.set_camera_rotation, ws, Quaternion.identity())
	pcall(ws.set_camera_position, ws, Vector3(0, -6, 1.2))

	pcall(self._spawn_lighting, self)

	return self
end

-- Core light units in the preview world. They live as long as the world does, so nothing has to move them when
-- the enemy changes; a failure here only means a dark preview, never a broken one.
function P3D:_spawn_lighting()
	local ws = self.ws

	if self._lights_spawned or not ws then
		return
	end

	local world = ws:world()

	if not world then
		return
	end

	self._lights_spawned = true
	self._lights = {}

	for i = 1, #LIGHT_RIG do
		local spec = LIGHT_RIG[i]
		local ok, unit = pcall(World.spawn_unit_ex, world, LIGHT_UNIT, nil, spec[1], Quaternion.identity())

		if not ok or not unit or not Unit.alive(unit) then
			crumb("light unit " .. i .. " failed: " .. tostring(unit))

			return
		end

		self._lights[#self._lights + 1] = unit

		local colour = spec[2]
		local configured = pcall(function()
			local light = Unit.light(unit, 1)

			Light.set_enabled(light, true)
			Light.set_type(light, "omni")
			Light.set_color_filter(light, Vector3(colour[1], colour[2], colour[3]))
			Light.set_intensity(light, spec[3])
			Light.set_falloff_start(light, LIGHT_FALLOFF_START)
			Light.set_falloff_end(light, spec[4])
			Light.set_volumetric_intensity(light, 0)
			Light.set_casts_shadows(light, false)
		end)

		if not configured then
			crumb("light unit " .. i .. " has no usable light")
		end
	end

	crumb("lighting rig on (" .. #self._lights .. " lights)")
end

function P3D:_destroy_lighting()
	local world = self.ws and self.ws:world()
	local lights = self._lights

	if world and lights then
		for i = #lights, 1, -1 do
			if Unit.alive(lights[i]) then
				pcall(World.destroy_unit, world, lights[i])
			end
		end
	end

	self._lights = nil
end

function P3D:_release_packages()
	local pm = Managers.package
	local ids = self._ids

	for i = #ids, 1, -1 do
		pcall(pm.release, pm, ids[i])

		ids[i] = nil
	end

	self._wait = {}
end

-- units first (attachments, items, root), flushed through the spawner's deletion queue, then the package refs
function P3D:_clear_subject()
	local ws = self.ws
	local spawner = ws and ws:unit_spawner()
	local parts = self._parts

	if spawner then
		for i = #parts, 1, -1 do
			local part = parts[i]
			local atts = part.attachments

			if atts then
				for j = #atts, 1, -1 do
					if Unit.alive(atts[j]) then
						spawner:mark_for_deletion(atts[j])
					end
				end
			end

			if Unit.alive(part.unit) then
				spawner:mark_for_deletion(part.unit)
			end
		end

		if self.unit and Unit.alive(self.unit) then
			spawner:mark_for_deletion(self.unit)
		end

		pcall(spawner.remove_pending_units, spawner)
	end

	self._parts = {}
	self.unit = nil
	self._ol_applied = nil
	self._yaw_applied = nil
	self.head_z = nil

	self:_release_packages()
end

function P3D:destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true

	pcall(self._clear_subject, self)
	pcall(self._destroy_lighting, self)

	if self.ws then
		crumb("destroy world")
		pcall(self.ws.destroy, self.ws)

		self.ws = nil
	end

	-- torn down cleanly: the attempt finished, nothing to flag after a later crash
	pcall(set_pending, nil)
end

-----------------------------------------------------------------------
-- Subject
-----------------------------------------------------------------------

function P3D:_fail(reason)
	self._state = "failed"
	self.reason = reason
	self._frames = 0

	crumb("failed: " .. tostring(reason))
end

function P3D:state()
	return self._state, self.reason
end

-- pure data: loadout items + the minimal package set (BreedResourceDependencies.generate would also pull
-- behaviour-tree fx/sfx, so it is not used)
function P3D:_plan(breed)
	local d = deps
	local defs = d.MasterItems.get_cached()
	local picks = {}
	local inventory = breed.inventory
		and d.MinionVisualLoadout.resolve(breed.inventory, nil, nil, breed.name, SPAWN_SEED)
	local slots = inventory and inventory.slots

	if slots then
		local names = {}

		for slot_name in pairs(slots) do
			names[#names + 1] = slot_name
		end

		table.sort(names)

		for i = 1, #names do
			local slot_name = names[i]
			local slot = slots[slot_name]
			local items = slot.items
			-- same exclusions as the research: material override / gib slots, fx sources, unused weapon slots
			local skip = slot.is_material_override_slot
				or slot.starts_invisible
				or type(items) ~= "table"
				or items.is_material_override_slot
				or #items == 0
				or string.find(slot_name, "^slot_fx_") ~= nil
				or (slot.is_weapon and slot_name ~= breed.spawn_inventory_slot)

			if not skip then
				local item_name = items[1]
				local item = type(item_name) == "string" and defs[item_name] or nil

				if item then
					-- untagged slot on a breed the base game forgot to tag: same breeds as the HUD's
					-- fix_missing_outline_tag (outlines.lua), which cannot tag this world's live slots
					local outline = slot.use_outline

					if outline == nil and mod.breed_missing_outline_tag(breed.name) then
						outline = true
					end

					picks[#picks + 1] = { slot = slot_name, name = item_name, item = item, outline = outline }
				end
			end
		end
	end

	local set = {}

	set[breed.base_unit] = true

	if breed.state_machine then
		set[breed.state_machine] = true
	end

	for i = 1, #picks do
		pcall(d.ItemPackage.compile_item_dependencies, picks[i].item, defs, set)
	end

	local names = {}

	for name in pairs(set) do
		names[#names + 1] = name
	end

	table.sort(names)

	self._picks = picks
	self._defs = defs
	self._names = names
end

function P3D:_request_packages()
	local pm = Managers.package
	local names = self._names
	local ids, wait = self._ids, self._wait
	local skipped = 0

	for i = 1, #names do
		local name = names[i]

		-- prioritized load, same call the BBM editor uses for its icon package
		if can_get("package", name) then
			local ok, id = pcall(pm.load, pm, name, PACKAGE_REF, nil, true)

			if ok and id then
				ids[#ids + 1] = id
				wait[#wait + 1] = name
			end
		else
			skipped = skipped + 1
		end
	end

	crumb(string.format("requested %d packages (%d without package) for %s", #wait, skipped, self.breed_name))
end

function P3D:set_breed(breed_name)
	if self._destroyed or not self.ws then
		return
	end

	self:_clear_subject()

	self.breed_name = breed_name
	self.breed = nil
	self.reason = nil
	self._state = "loading"
	self._load_time = 0
	self._frames = 0

	local breed = deps.BreedQueries.minion_breeds_by_name()[breed_name]
	local ok, why = P3D.supported(breed)

	if not ok then
		return self:_fail(why)
	end

	self.breed = breed

	set_pending(breed_name)

	self._guard_set = true

	local pok, perr = pcall(self._plan, self, breed)

	if not pok then
		return self:_fail("loadout: " .. tostring(perr))
	end

	crumb("request packages " .. breed_name)

	local rok, rerr = pcall(self._request_packages, self)

	if not rok then
		return self:_fail("packages: " .. tostring(rerr))
	end
end

-- ItemPackage resolves attachment children recursively; every unit it will spawn must be resident
local function slot_units_ok(d, slot_data, defs, breed_name, depth)
	if depth > 8 then
		return true
	end

	local sub = slot_data.item

	if type(sub) == "string" then
		sub = (sub ~= "") and defs[sub] or nil
	end

	if sub then
		local base = d.Items.base_unit(sub, breed_name, false)

		if base and base ~= "" and not can_get("unit", base) then
			return false, base
		end

		if sub.attachments then
			for _, child in pairs(sub.attachments) do
				local ok, miss = slot_units_ok(d, child, defs, breed_name, depth + 1)

				if not ok then
					return false, miss
				end
			end
		end
	end

	if slot_data.children then
		for _, child in pairs(slot_data.children) do
			local ok, miss = slot_units_ok(d, child, defs, breed_name, depth + 1)

			if not ok then
				return false, miss
			end
		end
	end

	return true
end

local function item_units_ok(d, item, defs, breed_name)
	local base = d.Items.base_unit(item, breed_name, false)

	if base and base ~= "" and not can_get("unit", base) then
		return false, base
	end

	if item.attachments then
		for _, slot_data in pairs(item.attachments) do
			local ok, miss = slot_units_ok(d, slot_data, defs, breed_name, 1)

			if not ok then
				return false, miss
			end
		end
	end

	return true
end

function P3D:_outline_set_layers(unit, on)
	for i = 1, #OUTLINE_LAYERS do
		Unit.set_material_layer(unit, OUTLINE_LAYERS[i], on)
	end

	-- same pair OutlineSystem._set_material_layers does (outline_system.lua:79-87)
	Unit.set_unit_culling(unit, not on, true)
end

local function set_outline_colour(unit, vec)
	for i = 1, #OUTLINE_LAYERS do
		Unit.set_vector3_for_material(unit, OUTLINE_LAYERS[i], "outline_color", vec)
	end
end

function P3D:_apply_outline()
	local unit = self.unit

	if not unit then
		return
	end

	local want = self._ol_on and true or false
	local key = want and (self._ol_r * 65536 + self._ol_g * 256 + self._ol_b) or -1
	local prev = self._ol_applied -- nil = never applied (layers default off), -1 = applied off, >= 0 = applied on

	if prev == key then
		return
	end

	-- layers only on the root unit like vanilla, only toggled when on/off changes
	if want ~= (prev ~= nil and prev ~= -1) then
		crumb(want and "outline layers on" or "outline layers off")
		self:_outline_set_layers(unit, want)
	end

	if want then
		local vec = Vector3(self._ol_r / 255, self._ol_g / 255, self._ol_b / 255)

		-- colour on the root and on every slot unit / attachment flagged use_outline (outline_system.lua:89-133)
		set_outline_colour(unit, vec)

		local parts = self._parts

		for i = 1, #parts do
			local part = parts[i]

			if part.outline then
				set_outline_colour(part.unit, vec)

				local atts = part.attachments

				if atts then
					for j = 1, #atts do
						set_outline_colour(atts[j], vec)
					end
				end
			end
		end
	end

	self._ol_applied = key
end

function P3D:set_outline(r, g, b)
	if r == nil then
		self._ol_on = false
	else
		self._ol_on = true
		self._ol_r, self._ol_g, self._ol_b = r, g, b
	end

	if self._state == "ready" then
		local ok, err = pcall(self._apply_outline, self)

		if not ok then
			crumb("outline error: " .. tostring(err))
		end
	end
end

function P3D:set_yaw(yaw)
	self._yaw = yaw

	local unit = self.unit

	if unit and self._yaw_applied ~= yaw then
		self._yaw_applied = yaw

		pcall(Unit.set_local_rotation, unit, 1, Quaternion.axis_angle(Vector3(0, 0, 1), BASE_YAW + yaw))
	end
end

-- Frame the unit: it fills ~60% of the stage height (feet at ~8% from the bottom), vertical fov is constant so the
-- visible vertical span at the unit plane is exactly 2*d*tan(fov/2).
function P3D:_frame()
	local ws, unit, breed = self.ws, self.unit, self.breed

	if not (ws and unit and breed) then
		return
	end

	local base_h = breed.base_height or 1.8
	local head = base_h

	if Unit.has_node(unit, "j_head") then
		head = Unit.world_position(unit, Unit.node(unit, "j_head")).z
	end

	self.head_z = head

	local tan_half = math.tan(math.rad(CAMERA_FOV) * 0.5)
	local height = math.max(head + 0.25, base_h)
	local span = (height + 0.15) / 0.6
	-- wide silhouettes (ogryns / monsters) must also fit horizontally
	local width = height * (base_h > 2.3 and 0.9 or 0.6)

	span = math.max(span, (width * 1.15) / math.max(self.aspect, 0.2))

	local centre = span * 0.42
	local dist = (span * 0.5) / tan_half

	self.centre_z = centre
	self.span_z = span

	pcall(ws.set_camera_position, ws, Vector3(0, -dist, centre))
end

function P3D:frame()
	return self.centre_z, self.span_z
end

function P3D:set_rect(x, y, w, h, aspect)
	self.aspect = aspect or self.aspect

	local ws = self.ws

	if not ws then
		return
	end

	-- size first: UIWorldSpawner._update_viewport_rect clamps an unset width to 0
	pcall(ws.set_viewport_size, ws, w, h)
	pcall(ws.set_viewport_position, ws, x, y)

	if self._state == "ready" then
		pcall(self._frame, self)
	end
end

function P3D:_spawn()
	local d, ws, breed = deps, self.ws, self.breed
	local pm = Managers.package

	if not can_get("unit", breed.base_unit) then
		return self:_fail("model not resident")
	end

	-- drop items whose units are not resident rather than spawn them
	local valid = {}

	for i = 1, #self._picks do
		local pick = self._picks[i]
		local ok, missing = item_units_ok(d, pick.item, self._defs, breed.name)

		if ok then
			valid[#valid + 1] = pick
		else
			crumb("skip item " .. pick.name .. " (unit not resident: " .. tostring(missing) .. ")")
		end
	end

	set_pending(breed.name)

	self._guard_set = true

	crumb("spawn " .. breed.name)

	local rotation = Quaternion.axis_angle(Vector3(0, 0, 1), BASE_YAW + self._yaw)
	-- World.spawn_unit_ex(world, unit, nil, position, rotation): same call UIProfileSpawner uses
	-- (ui_profile_spawner.lua:1124) through UIUnitSpawner.spawn_unit (ui_unit_spawner.lua:77)
	local spawner = ws:unit_spawner()
	local ok, unit = pcall(spawner.spawn_unit, spawner, breed.base_unit, Vector3(0, 0, 0), rotation)

	if not ok or not unit then
		return self:_fail("spawn: " .. tostring(unit))
	end

	self.unit = unit
	self._yaw_applied = self._yaw

	local sm = breed.state_machine

	-- minion_animation_extension.lua:23-25; only when its package really loaded
	if sm and pm:has_loaded(sm) then
		pcall(Unit.set_animation_state_machine, unit, sm)
	end

	local ev = breed.spawn_anim_state

	-- minion_spawn_manager.lua:192-197; guard form from ui_profile_spawner.lua:301-302
	if ev then
		pcall(function()
			if Unit.has_animation_event(unit, ev) then
				Unit.animation_event(unit, ev)
			end
		end)
	end

	local lod_group = d.VisualLoadoutLodGroup.try_init_and_fetch_lod_group(unit, "lod")
	local lod_shadow_group = d.VisualLoadoutLodGroup.try_init_and_fetch_lod_group(unit, "lod_shadow")

	if lod_group then
		pcall(LODGroup.set_static_select, lod_group, 0)
	else
		-- no LOD group on the body: pin its own LOD object instead (player_customization.lua:162-186)
		pcall(function()
			if Unit.has_lod_object(unit, "lod") then
				LODObject.set_static_select(Unit.lod_object(unit, "lod"), 0)
			end
		end)
	end

	if lod_shadow_group then
		pcall(LODGroup.set_static_select, lod_shadow_group, 0)
	else
		pcall(function()
			if Unit.has_lod_object(unit, "lod_shadow") then
				LODObject.set_static_select(Unit.lod_object(unit, "lod_shadow"), 0)
			end
		end)
	end

	-- standalone attach mode: from_script_component spawns with World.spawn_unit_ex and links at the wielded node
	-- (visual_loadout_customization.lua:278-293); same table MinionCustomization builds (minion_customization.lua:40-52)
	local attach = {
		from_script_component = true,
		from_ui_profile_spawner = false,
		is_minion = true,
		force_highest_lod_step = true,
		world = ws:world(),
		character_unit = unit,
		item_definitions = self._defs,
		lod_group = lod_group,
		lod_shadow_group = lod_shadow_group,
	}

	for i = 1, #valid do
		local pick = valid[i]

		crumb("attach " .. pick.name)

		local iok, item_unit, atts =
			pcall(d.VisualLoadoutCustomization.spawn_item, pick.item, attach, unit, false, false, false, nil, nil)

		if iok and item_unit then
			self._parts[#self._parts + 1] = {
				unit = item_unit,
				attachments = atts and atts[item_unit],
				outline = pick.outline,
			}
		else
			crumb("attach failed " .. pick.name .. ": " .. tostring(item_unit))
		end
	end

	self:_frame()

	self._state = "ready"
	self._frames = 0
	self._freeze_in = FREEZE_ANIM_DELAY

	crumb("ready " .. breed.name)

	if self._ol_on then
		self._ol_applied = nil

		pcall(self._apply_outline, self)
	end
end

function P3D:update(dt, t)
	if self._destroyed or not self.ws then
		return
	end

	local state = self._state

	if state == "loading" then
		self._load_time = self._load_time + dt

		local pm = Managers.package
		local wait = self._wait
		local done = true

		for i = 1, #wait do
			if not pm:has_loaded(wait[i]) then
				done = false

				break
			end
		end

		if done then
			local ok, err = pcall(self._spawn, self)

			if not ok then
				self:_fail("spawn: " .. tostring(err))
			end
		elseif self._load_time > LOAD_TIMEOUT then
			self:_fail("timed out loading")
		end
	end

	if self._freeze_in then
		self._freeze_in = self._freeze_in - dt

		if self._freeze_in <= 0 then
			self._freeze_in = nil

			local frozen_unit = self.unit

			if frozen_unit then
				pcall(function()
					if Unit.has_animation_state_machine(frozen_unit) then
						Unit.disable_animation_state_machine(frozen_unit)
					end
				end)
			end
		end
	end

	local ok, err = pcall(self.ws.update, self.ws, dt, t)

	if not ok and not self._update_err then
		self._update_err = true

		crumb("world update error: " .. tostring(err))
	end

	-- crash guard: the attempt survived GUARD_FRAMES rendered frames after the last risky step
	if self._guard_set and self._state ~= "loading" then
		self._frames = self._frames + 1

		if self._frames >= GUARD_FRAMES then
			self._guard_set = false

			set_pending(nil)
		end
	end
end

return P3D
