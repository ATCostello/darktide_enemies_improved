local mod = get_mod("enemies_improved")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UIScenegraph = require("scripts/managers/ui/ui_scenegraph")
local ScriptWorld = require("scripts/foundation/utilities/script_world")
local HudHealthBarLogic = require("scripts/ui/hud/elements/hud_health_bar_logic")
local BreedQueries = require("scripts/utilities/breed_queries")

local P3D

do
	local ok, res = pcall(mod.io_dofile, mod, "enemies_improved/scripts/mods/enemies_improved/editor/ei_preview_3d")

	if ok and type(res) == "table" then
		P3D = res
	else
		mod:error("[ei_preview] 3D module failed to load: %s", tostring(res))
	end
end

local Preview = {}
local Preview_mt = { __index = Preview }

local math_floor = math.floor
local math_min = math.min
local math_max = math.max

local OVERLAY_LAYER = 45
local WIDGET_Z = 50
local DEFAULT_BREED = "renegade_executor"
local PX_PER_METRE_2D = 60

local overlay_counter = 0

local LOOP = 7.0
local DPS_AT = 6.0
local EVENTS = {
	{ at = 0.45, frac = 0.12 },
	{ at = 1.05, frac = 0.14, crit = true },
	{ at = 1.65, frac = 0.12, weak = true },
	{ at = 2.25, frac = 0.16, crit = true, weak = true },
	{ at = 2.90, frac = 0.03, dot = true },
	{ at = 3.40, frac = 0.03, dot = true },
	{ at = 3.90, frac = 0.03, dot = true },
	{ at = 4.50, frac = 0.10 },
}
local MAX_HEALTH_BY_TYPE = {
	horde = 250,
	enemy = 500,
	disabler = 700,
	special = 600,
	sniper = 500,
	far = 800,
	elite = 1100,
	shield = 1500,
	witch = 3500,
	captain = 8000,
	monster = 15000,
}
local TOUGHNESS_TYPES = { captain = true, monster = true }

local ICON_TEXTURES = {
	"content/ui/textures/frames/horde/hex_frame_horde",
	"content/ui/textures/frames/horde/hex_frame_horde_mask",
	"content/ui/textures/frames/horde/hex_frame_horde_glow",
}

local CARD_FONT = "proxima_nova_bold"
local COLOR_CARD = { 235, 14, 16, 20 }
local COLOR_FRAME = { 255, 70, 74, 80 }
local COLOR_FRAME_OUTLINE = { 255, 0, 0, 0 }
local COLOR_TITLE = { 255, 235, 235, 235 }
local COLOR_SUB = { 255, 150, 154, 160 }

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------

local function can_get(kind, name)
	local ok, res = pcall(Application.can_get_resource, kind, name)

	return (ok and res) and true or false
end

local function log_once(self, where, err)
	local errors = self._errors

	if not errors[where] then
		errors[where] = true

		mod:error("[ei_preview] %s: %s", where, tostring(err))
	end
end

local function localized(key)
	if not key then
		return nil
	end

	if mod.custom_localize then
		local ok, res = pcall(mod.custom_localize, key)

		if ok and type(res) == "string" and res ~= "" and res:sub(1, 1) ~= "<" then
			return res
		end
	end

	if Localize then
		local ok, res = pcall(Localize, key)

		if ok and type(res) == "string" and res ~= "" and res:sub(1, 1) ~= "<" then
			return res
		end
	end

	return nil
end

local function pulse_on(time, flash, speed)
	if not flash then
		return true
	end

	if not speed or speed <= 0 then
		speed = 0.2
	end

	return math_floor(time / speed) % 2 == 0
end

local function make_buff(name, max_stacks, stat_buffs, conditional_stat_buffs)
	local template =
		{ max_stacks = max_stacks, stat_buffs = stat_buffs, conditional_stat_buffs = conditional_stat_buffs }
	local buff = { stacks = 1 }

	buff.template_name = function()
		return name
	end
	buff.template = function()
		return template
	end
	buff.stack_count = function()
		return buff.stacks
	end
	buff.max_stacks = function()
		return max_stacks
	end

	return buff
end

local buff_templates

local function buff_template_of(name)
	if buff_templates == nil then
		local ok, res = pcall(require, "scripts/settings/buff/buff_templates")

		buff_templates = ok and type(res) == "table" and res or false
	end

	return buff_templates and buff_templates[name] or nil
end

local CARRY_KEYS = {
	"damage_taken",
	"damage_has_started",
	"damage_has_started_timer",
	"last_damage_taken_time",
	"dead",
	"last_hit_zone_name",
	"_last_health_current",
	"_last_health_max",
	"_last_damage_value",
}

local function default_resolve(fs, breed_name, breed_type)
	return {
		breed = breed_name,
		type = breed_type,
		outline = { on = false, source = "off" },
		bar = { visible = fs.healthbar_enable ~= false, y = fs.hb_y_offset or 0 },
		icon = { on = true },
		debuffs = { on = fs.debuff_enable ~= false, on_body = fs.debuff_show_on_body and true or false },
		marker = { on = fs.markers_enable and true or false },
	}
end

-----------------------------------------------------------------------
-- Construction / teardown
-----------------------------------------------------------------------

function Preview.new(view, opts)
	opts = opts or {}

	local self = setmetatable({
		view = view,
		stage_id = opts.stage_id or "pv_stage",
		anchor_id = opts.anchor_id or "pv_anchor",
		flags = { combat = true, alert = false, stagger = false, tagged = false, threed = true },
		breed_name = DEFAULT_BREED,
		_time = 0,
		_acc_dt = 0,
		_next_tick = 0,
		_loop_t = 0,
		_ev_i = 1,
		_hits = 0,
		_yaw = 0,
		_ctx = { breed = nil, show_on_body = false, draw = true },
		_text_opts = {},
		_errors = {},
		_buff_list = {},
		_nact = 0,
		_status = "",
		_layout_dirty = true,
		_need_sync = true,
	}, Preview_mt)

	self.flags.threed = mod:get("ei_preview_3d_enabled") ~= false

	if P3D then
		local ok, pending = pcall(P3D.pending)

		if ok and pending then
			local name, disabled_all = P3D.trip_guard()

			if disabled_all then
				self.flags.threed = false
				self._guard_msg = "3D preview disabled: the last attempt ("
					.. tostring(name)
					.. ") did not finish. Toggle 3D to retry."
			end
		end
	end

	self._buffs = {
		bleed = make_buff("bleeding", 16),
		burn = make_buff("burning", 31),
		rend = make_buff("rending_debuff", 16, { rending_multiplier = 0.025 }),
	}

	self:_create_overlay()

	local ok, err = pcall(self._apply_subject, self)

	if not ok then
		log_once(self, "subject", err)
	end

	return self
end

function Preview:_create_overlay()
	local view = self.view
	local ui = Managers and Managers.ui

	self._renderer = view._ui_renderer

	if not (ui and view.view_name and ui.create_world and ui.create_viewport and ui.create_renderer) then
		return
	end

	overlay_counter = overlay_counter + 1

	local ov = {
		world_name = "ei_preview_overlay_world_" .. overlay_counter,
		viewport_name = "ei_preview_overlay_vp_" .. overlay_counter,
		renderer_name = "ei_preview_overlay_renderer_" .. overlay_counter,
	}

	local ok, err = pcall(function()
		ov.world = ui:create_world(ov.world_name, OVERLAY_LAYER, "ui", view.view_name)
		ov.viewport = ui:create_viewport(ov.world, ov.viewport_name, "overlay", 1)
		ov.renderer = ui:create_renderer(ov.renderer_name, ov.world)
	end)

	if ok and ov.renderer then
		self._ov = ov
		self._renderer = ov.renderer
	else
		self:_destroy_overlay(ov)
		log_once(self, "overlay", err)
	end
end

function Preview:_destroy_overlay(ov)
	ov = ov or self._ov

	if not ov then
		return
	end

	local ui = Managers and Managers.ui

	if ui then
		if ov.renderer then
			pcall(ui.destroy_renderer, ui, ov.renderer_name)
		end

		if ov.viewport then
			pcall(ScriptWorld.destroy_viewport, ov.world, ov.viewport_name)
		end

		if ov.world then
			pcall(ui.destroy_world, ui, ov.world)
		end
	end

	if ov == self._ov then
		self._ov = nil
		self._renderer = self.view._ui_renderer
	end
end

function Preview:_destroy_widget()
	local widget = self._widget

	if widget then
		pcall(UIWidget.destroy, self._wrenderer, widget)

		self._widget = nil
	end
end

function Preview:destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true

	self:_destroy_widget()

	if self._p3d then
		pcall(self._p3d.destroy, self._p3d)

		self._p3d = nil
	end

	self:_destroy_overlay()
end

-----------------------------------------------------------------------
-- Subject / settings
-----------------------------------------------------------------------

function Preview:set_subject(subject)
	local name = subject and subject.breed_name

	if not name or self._destroyed then
		return
	end

	if name == self.breed_name and self._breed then
		return
	end

	self.breed_name = name

	local ok, err = pcall(self._apply_subject, self)

	if not ok then
		log_once(self, "subject", err)
	end
end

function Preview:set_flags(flags)
	if not flags or self._destroyed then
		return
	end

	local f = self.flags

	if flags.combat ~= nil and (flags.combat and true or false) ~= f.combat then
		f.combat = flags.combat and true or false
		self._reset_pending = true
	end

	if flags.alert ~= nil then
		f.alert = flags.alert and true or false
	end

	if flags.stagger ~= nil then
		f.stagger = flags.stagger and true or false
	end

	if flags.tagged ~= nil then
		f.tagged = flags.tagged and true or false
	end

	if flags.threed ~= nil and (flags.threed and true or false) ~= f.threed then
		local want = flags.threed and true or false

		if want and mod:get("ei_preview_3d_enabled") == false then
			want = false
		end

		if want ~= f.threed then
			f.threed = want
			self._guard_msg = nil
			self._need_sync = true

			if want and P3D and P3D.clear_blocked then
				pcall(P3D.clear_blocked)
			end
		end
	end

	self:_refresh_status()
end

function Preview:_refresh_resolve()
	local name = self.breed_name
	local S = mod.settings_api
	local fs = mod.frame_settings
	local res

	if S and S.resolve then
		local ok, r = pcall(S.resolve, name)

		if ok then
			res = r
		else
			log_once(self, "resolve", r)
		end
	end

	self._res = res or default_resolve(fs, name, self._type)

	local tag

	if S and S.get_colour then
		local ok, c = pcall(S.get_colour, "outline_tagged_colour")

		if ok then
			tag = c
		end
	end

	self._tag_rgb = tag or { 255, 255, 1, 0 }
end

function Preview:_apply_subject()
	local name = self.breed_name
	local breed = BreedQueries.minion_breeds_by_name()[name]
	local S = mod.settings_api
	local breed_type

	if S and S.type_of then
		local ok, res = pcall(S.type_of, name)

		breed_type = ok and res or nil
	end

	if not breed_type and breed and mod.find_breed_category_by_tags then
		local ok, res = pcall(mod.find_breed_category_by_tags, breed.tags, breed.name)

		breed_type = ok and res or nil
	end

	self._breed = breed
	self._type = breed_type or "enemy"
	self._title = (breed and localized(breed.display_name)) or name
	self._type_label = localized(self._type) or self._type
	self._weak_zone = "head"

	if breed and breed.hit_zone_weakspot_types then
		for zone in pairs(breed.hit_zone_weakspot_types) do
			self._weak_zone = zone

			break
		end
	end

	self._3d_breed = nil

	self:_refresh_resolve()
	self:_rebuild_widget()

	self._need_sync = true
	self._layout_dirty = true

	self:_refresh_status()
end

function Preview:settings_changed()
	if self._destroyed then
		return
	end

	local ok, err = pcall(function()
		self:_refresh_resolve()
		self:_rebuild_widget(true)

		if self._widget and not self._widget_err then
			self:_tick_widget(0, self._t or 0)
		end
	end)

	if not ok then
		log_once(self, "settings_changed", err)
	end

	self._layout_dirty = true

	self:_refresh_status()
end

function Preview:set_focus_debuff(name)
	if self._destroyed or name == self._focus_name then
		return
	end

	self._focus_name = name
	self._focus_buff = nil
	self._next_tick = 0

	if name then
		local template = buff_template_of(name)
		local max = template and template.max_stacks
		local stacks = type(max) == "number" and max >= 1 and math_min(max, 31) or 1
		local buff =
			make_buff(name, stacks, template and template.stat_buffs, template and template.conditional_stat_buffs)

		buff.stacks = stacks
		self._focus_buff = buff
	end
end

local function preview_debuff_row(name)
	local template = buff_template_of(name)
	local max = template and template.max_stacks
	local stacks = type(max) == "number" and max >= 1 and math_min(max, 31) or 1
	local def = mod.default_debuffs and mod.default_debuffs[name]

	return {
		name = name,
		stacks = stacks,
		max_stacks = stacks,
		type = (def and def.type) or "utility",
		stat_buffs = template and template.stat_buffs,
		conditional_stat_buffs = template and template.conditional_stat_buffs,
	}
end

function Preview:set_debuffs(names)
	if self._destroyed then
		return
	end

	local old = self._debuff_names

	if old and #old == #names then
		local same = true

		for i = 1, #names do
			if old[i] ~= names[i] then
				same = false

				break
			end
		end

		if same then
			return
		end
	end

	self._debuff_names = names
	self._debuff_rows = {}

	for i = 1, #names do
		self._debuff_rows[#self._debuff_rows + 1] = preview_debuff_row(names[i])
	end

	self._next_tick = 0
end

function Preview:on_resolution_modified()
	self._layout_dirty = true
end

-----------------------------------------------------------------------
-- The EI widget
-----------------------------------------------------------------------
local function template_api()
	local tpl = mod.ei_template
	local sub = tpl and tpl.sub

	if not (tpl and tpl.create_widget_defintion and sub) then
		return nil, "ei_template"
	end

	local HB, MK, DB = sub.healthbar, sub.markers, sub.debuffs

	if not (HB and HB.apply_breed_style and HB.apply_state and HB.push_damage_number and HB.bar_settings) then
		return nil, "healthbar template"
	end

	return { tpl = tpl, HB = HB, MK = MK, DB = DB }
end

function Preview:_rebuild_widget(keep)
	local old = keep and self._widget or nil

	self:_destroy_widget()

	self._note = nil
	self._widget_err = nil
	self._draw_err = nil

	local breed = self._breed

	if not breed then
		self._note = "Unknown enemy"

		return
	end

	local api, missing = template_api()

	if not api then
		self._note = "Preview needs the updated templates (" .. tostring(missing) .. " missing)"

		return
	end

	local ok, err = pcall(self._build_widget, self, api, old)

	if not ok then
		self:_destroy_widget()

		self._note = "Preview error (see log)"

		log_once(self, "build", err)
	end
end

function Preview:_build_widget(api, old)
	local tpl, HB, MK, DB = api.tpl, api.HB, api.MK, api.DB
	local breed = self._breed

	if MK and MK.refresh_sizes then
		MK.refresh_sizes()
	end

	if DB and DB.refresh_layout then
		DB.refresh_layout()
	end

	local def = tpl.create_widget_defintion(tpl, self.anchor_id)
	local widget = UIWidget.init("ei_preview", def)
	local content = widget.content

	widget.offset[3] = WIDGET_Z

	content.breed = breed
	content._breed_type = self._type
	content.hb_built = false
	content.draw_hb = true
	content.damage_taken = 0
	content.damage_numbers = {}
	content.spawn_progress_timer = 0
	content.special_attack_imminent = false
	content.frame = mod.frame_settings.frame_type
	content.is_in_shooting_range = true
	content.in_horde_cluster = false
	content.dead = false
	content.player_camera = nil
	widget._active = {}
	widget._active_count = 0
	widget._state = {}

	HB.apply_breed_style(widget, breed, self._type, 1)

	self._widget = widget
	self._wrenderer = self._renderer
	self._HB, self._MK, self._DB = HB, MK, DB
	self._next_tick = 0

	self._icons_ok = true

	for i = 1, #ICON_TEXTURES do
		if not can_get("texture", ICON_TEXTURES[i]) then
			self._icons_ok = false

			break
		end
	end

	if old and self._bar then
		self:_restore_scenario(widget, old)
	else
		self:_reset_scenario()
	end
end

-----------------------------------------------------------------------
-- Scenario
-----------------------------------------------------------------------
function Preview:_restore_scenario(widget, old)
	local c, oc = widget.content, old.content
	local fs = mod.frame_settings
	local HB = self._HB
	local t = self._t or 0
	local loop_t = self._loop_t
	local max = self._max_hp
	local window = fs.damage_number_duration or 2

	for i = 1, #CARRY_KEYS do
		local key = CARRY_KEYS[i]

		c[key] = oc[key]
	end

	for i = 1, self._ev_i - 1 do
		local ev = EVENTS[i]
		local age = loop_t - ev.at

		if age <= window then
			HB.push_damage_number(
				widget,
				math_floor(ev.frac * max),
				t - age,
				ev.crit or false,
				ev.weak or false,
				ev.dot or false,
				max
			)

			local numbers = c.damage_numbers
			local dn = numbers and numbers[#numbers]

			if dn then
				dn.time = age
				dn.expand_time = age
			end
		end
	end

	local numbers, onumbers = c.damage_numbers, oc.damage_numbers

	if numbers and onumbers and #numbers == #onumbers then
		for i = 1, #numbers do
			numbers[i].random_number = onumbers[i].random_number
			numbers[i].float_right = onumbers[i].float_right
		end
	end

	c.last_damage_taken_time = oc.last_damage_taken_time
	widget._state = old._state or widget._state -- debuff row animation
end

function Preview:_reset_scenario()
	self._reset_pending = nil
	self._loop_t = 0
	self._ev_i = 1
	self._hits = 0
	self._dead = false
	self._total_damage = 0

	local max = MAX_HEALTH_BY_TYPE[self._type] or 600

	self._max_hp = max
	self._hp = max
	self._tough_max = TOUGHNESS_TYPES[self._type] and max * 0.3 or 0
	self._tough = self._tough_max

	local HB = self._HB

	if HB and HB.bar_settings then
		self._bar = HudHealthBarLogic:new(HB.bar_settings)
	end

	local widget = self._widget

	if widget then
		local c = widget.content
		local numbers = c.damage_numbers

		if numbers then
			for i = #numbers, 1, -1 do
				numbers[i] = nil
			end
		end

		c.damage_taken = 0
		c.damage_has_started = nil
		c.damage_has_started_timer = nil
		c.dead = false
		c._last_health_current = nil
		c._last_health_max = nil
		c._last_damage_value = nil
		c.last_hit_zone_name = nil
		c.add_on_next_number = nil

		widget._active_count = 0
		widget._state = {}

		local active = widget._active

		if active then
			for i = #active, 1, -1 do
				active[i] = nil
			end
		end
	end

	local act = self._buff_list

	for i = self._nact, 1, -1 do
		act[i] = nil
	end

	self._nact = 0
end

function Preview:_hit(ev, t)
	local widget = self._widget
	local c = widget.content
	local max = self._max_hp
	local damage = math_floor(ev.frac * max)
	local rest = damage

	if self._tough > 0 then
		local absorbed = math_min(rest, self._tough)

		self._tough = self._tough - absorbed
		rest = rest - absorbed
	end

	self._hp = math_max(self._hp - rest, max * 0.2)
	self._total_damage = self._total_damage + damage
	self._hits = self._hits + 1

	c.damage_taken = self._total_damage
	c.damage_has_started = true
	c.last_hit_zone_name = ev.weak and self._weak_zone or "center_mass"
	c._last_health_current = self._hp
	c._last_health_max = max
	c._last_damage_value = damage

	self._HB.push_damage_number(widget, damage, t, ev.crit or false, ev.weak or false, ev.dot or false, max)
end

function Preview:_outline_colour(fs)
	if not fs.outlines_enable then
		return nil
	end

	local flags = self.flags
	local time = self._time

	if
		flags.alert
		and fs.outline_specials_enable
		and pulse_on(time, fs.specials_flash, fs.special_attack_pulse_speed)
	then
		local c = fs.outline_specials_colour

		return c[2], c[3], c[4]
	end

	local stagger_enabled

	if self._type == "horde" then
		stagger_enabled = fs.outline_stagger_horde_enable
	else
		stagger_enabled = fs.outline_stagger_enable
	end

	if flags.stagger and stagger_enabled and pulse_on(time, fs.stagger_flash, fs.stagger_pulse_speed) then
		local c = fs.outline_stagger_colour

		return c[2], c[3], c[4]
	end

	if flags.tagged then
		local c = self._tag_rgb

		return c[2], c[3], c[4]
	end

	local outline = self._res and self._res.outline

	if outline and outline.on and outline.rgb then
		local c = outline.rgb

		return c[2], c[3], c[4]
	end

	return nil
end

function Preview:_tick_outline(fs)
	local r, g, b = self:_outline_colour(fs)

	if r ~= self._ol_r or g ~= self._ol_g or b ~= self._ol_b then
		self._ol_r, self._ol_g, self._ol_b = r, g, b

		local p3d = self._p3d

		if p3d then
			p3d:set_outline(r, g, b)
		end
	end
end

local function apply_depth_fade(widget, fs)
	local opacity = fs.global_opacity or 1

	if not fs.enable_depth_fading or opacity > 0.98 then
		return
	end

	for key, style in next, widget.style do
		if key ~= "damage_numbers" and style.default_alpha then
			local a = style.default_alpha * opacity

			if style.color then
				style.color[1] = a
			end

			if style.text_color then
				style.text_color[1] = a
			end
		end
	end
end

local function fill_worn_rows(rows, count, worn, skip_stagger)
	for i = 1, #worn do
		local f = worn[i]
		local shown = skip_stagger and f.name == "staggered" or false

		for k = 1, count do
			if rows[k].name == f.name then
				shown = true

				break
			end
		end

		if not shown then
			count = count + 1

			local entry = rows[count]

			if not entry then
				entry = {}
				rows[count] = entry
			end

			entry.name = f.name
			entry.stacks = f.stacks
			entry.max_stacks = f.max_stacks
			entry.type = f.type
			entry.duration = nil
			entry.stat_buffs = f.stat_buffs
			entry.conditional_stat_buffs = f.conditional_stat_buffs
			entry.combined = nil
			entry.from_keyword = nil
		end
	end

	return count
end

function Preview:_apply_widget_state(fs, dt, t)
	local widget, HB, MK, DB = self._widget, self._HB, self._MK, self._DB
	local c = widget.content
	local style = widget.style
	local flags = self.flags
	local res = self._res
	local time = self._time

	local alert_on = flags.alert and pulse_on(time, fs.specials_flash, fs.special_attack_pulse_speed)

	local debuffs_on = res.debuffs.on and true or false
	local n = 0

	if debuffs_on and mod.collect_debuffs and DB and DB.layout_rows then
		local act = self._buff_list
		local buffs = self._buffs
		local lt = self._loop_t

		if flags.combat then
			local s = lt < 0.3 and 0 or math_min(16, 1 + math_floor((lt - 0.3) * 3))

			if s > 0 then
				buffs.bleed.stacks = s
				n = n + 1
				act[n] = buffs.bleed
			end

			s = lt < 1.0 and 0 or math_min(31, 1 + math_floor((lt - 1.0) * 5))

			if s > 0 then
				buffs.burn.stacks = s
				n = n + 1
				act[n] = buffs.burn
			end

			s = self._hits > 0 and math_min(16, self._hits * 3) or 0

			if s > 0 then
				buffs.rend.stacks = s
				n = n + 1
				act[n] = buffs.rend
			end
		end

		local focus = self._focus_buff
		local fname = focus and focus.template_name()

		if fname and mod.debuffs and mod.debuffs[fname] and not (fname == "staggered" and flags.stagger) then
			local shown = false

			for i = 1, n do
				if act[i].template_name() == fname then
					shown = true

					break
				end
			end

			if not shown then
				n = n + 1
				act[n] = focus
			end
		end

		for i = n + 1, self._nact do
			act[i] = nil
		end

		self._nact = n

		mod.collect_debuffs(widget, act, nil, nil, false)

		if flags.stagger and fs.debuff_stagger_enable and fs.debuff_utility_enable then
			local count = (widget._active_count or 0) + 1
			local rows = widget._active
			local entry = rows[count]

			if not entry then
				entry = {}
				rows[count] = entry
			end

			entry.name = "staggered"
			entry.stacks = 1
			entry.max_stacks = 1
			entry.type = "utility"
			entry.duration = math_floor((2.5 - time % 2.5) * 10) / 10
			entry.stat_buffs = nil
			entry.conditional_stat_buffs = nil
			entry.combined = nil
			entry.from_keyword = nil

			widget._active_count = count
		end
	elseif DB and DB.layout_rows then
		if self._nact > 0 then
			local act = self._buff_list

			for i = self._nact, 1, -1 do
				act[i] = nil
			end

			self._nact = 0
			widget._active = widget._active or {}

			for i = #widget._active, 1, -1 do
				widget._active[i] = nil
			end

			widget._active_count = 0
		end
	end

	local worn = self._debuff_rows

	if worn and #worn > 0 then
		if debuffs_on then
			local rows = widget._active or {}

			widget._active_count = fill_worn_rows(rows, widget._active_count or 0, worn, flags.stagger)
			widget._active = rows
		else
			local rows = {}

			widget._active_count = fill_worn_rows(rows, 0, worn, false)
			widget._active = rows
		end
	end

	if DB and DB.layout_rows and (debuffs_on or (worn and #worn > 0)) then
		local ctx = self._ctx

		ctx.breed = self._breed
		ctx.show_on_body = res.debuffs.on_body and true or false
		ctx.body_offset_y = self._body_offset_y
		ctx.draw = true

		DB.layout_rows(widget, 1, dt, ctx)
	end

	HB.apply_state(widget, 1, dt, t, alert_on and true or false)

	local bar_visible = fs.healthbar_enable and res.bar.visible and true or false

	c.hb_built = bar_visible and not self._dead
	c.dn_built = bar_visible and fs.show_damage_numbers and true or false

	if not self._icons_ok then
		c.icon_enabled = false
	end

	if alert_on and fs.healthbar_specials_enable then
		local glow = style.icon_background1
		local spec = fs.outline_specials_colour

		if glow then
			glow.default_alpha = 255
			glow.color[1] = 255
			glow.color[2] = spec[2]
			glow.color[3] = spec[3]
			glow.color[4] = spec[4]
		end

		c.alert_healthbar = true
	end

	-- overhead marker
	local marker_on = res.marker.on

	if marker_on then
		local opt = fs.marker_display_option
		local damaged = self._hp < self._max_hp

		if (opt == "hide_unless_damaged" and not damaged) or (opt == "hide_when_damaged" and damaged) then
			marker_on = false
		end
	end

	if MK and MK.apply_state then
		local alert_marker = alert_on and fs.marker_specials_enable and true or false

		MK.apply_state(widget, style.current_health.color, alert_marker and fs.outline_specials_colour or nil, 1)

		if MK.health_glyph then
			c.marker_health = MK.health_glyph(c.health_fraction or 1) or c.marker_health
		end

		c.special_attack_imminent = alert_marker
		c.m_built = marker_on and true or false
	else
		c.m_built = false
	end

	apply_depth_fade(widget, fs)
end

function Preview:_tick_widget(dt, t)
	local widget = self._widget

	if not widget then
		return
	end

	local fs = mod.frame_settings
	local c = widget.content
	local flags = self.flags

	if self._reset_pending then
		self:_reset_scenario()
	end

	if flags.combat then
		local lt = self._loop_t + dt

		if lt >= LOOP then
			self:_reset_scenario()

			lt = dt
		end

		self._loop_t = lt

		local ev = EVENTS[self._ev_i]

		while ev and lt >= ev.at do
			self:_hit(ev, t)

			self._ev_i = self._ev_i + 1
			ev = EVENTS[self._ev_i]
		end

		if lt >= DPS_AT and not self._dead and fs.hb_show_dps then
			self._dead = true
			c.dead = true
		end
	end

	local max = self._max_hp
	local percent = self._hp / max

	c.health_current = self._hp
	c.health_max = max
	c.health_percent = percent
	c.max_toughness = self._tough_max
	c.current_toughness = self._tough
	c.toughness_fraction = self._tough_max > 0 and self._tough / self._tough_max or 0

	local bar = self._bar
	local health_fraction, ghost_fraction = percent, percent

	if bar then
		bar:update(dt, t, percent)

		local hf, gf = bar:animated_health_fractions()

		if hf then
			health_fraction, ghost_fraction = hf, gf
		end
	end

	c.health_fraction = health_fraction
	c.health_ghost_fraction = ghost_fraction

	self._acc_dt = self._acc_dt + dt

	if self._time >= self._next_tick then
		self:_apply_widget_state(fs, self._acc_dt, t)

		self._acc_dt = 0

		local rate = fs.general_throttle_rate or 0.02

		self._next_tick = self._time + math_min(math_max(rate, 0), 0.1)
	end
end

-----------------------------------------------------------------------
-- 3D
-----------------------------------------------------------------------

function Preview:_sync_3d()
	self._need_sync = false
	self._p3d_err = nil
	self._3d_reason = nil

	local p3d = self._p3d

	if not self.flags.threed then
		if p3d then
			pcall(p3d.destroy, p3d)

			self._p3d = nil
		end

		self._layout_dirty = true
		self:_refresh_status()

		return
	end

	if not P3D then
		self._3d_reason = "module missing"
	elseif not self._ov then
		self._3d_reason = "no overlay"
	elseif not self._breed then
		self._3d_reason = "unknown enemy"
	else
		local ok, why = P3D.supported(self._breed)

		if not ok then
			self._3d_reason = why
		end
	end

	self._p3d_state, self._p3d_reason = nil, nil

	if self._3d_reason then
		if p3d then
			-- keep the world, drop the previous unit
			pcall(p3d.set_breed, p3d, self.breed_name)
		end

		self._layout_dirty = true
		self:_refresh_status()

		return
	end

	if not p3d then
		local obj, err = P3D.new(self.view)

		if not obj then
			self._3d_reason = err
			self._layout_dirty = true
			self:_refresh_status()

			return
		end

		p3d = obj
		self._p3d = obj
		self._3d_breed = nil
		self._ol_r, self._ol_g, self._ol_b = nil, nil, nil
	end

	if self._3d_breed ~= self.breed_name then
		self._3d_breed = self.breed_name

		p3d:set_breed(self.breed_name)
		p3d:set_yaw(self._yaw)
	end

	self._layout_dirty = true
	self:_refresh_status()
end

function Preview:_drag(input_service)
	local p3d = self._p3d

	if not (p3d and input_service) then
		return
	end

	if input_service:get("left_hold") then
		local cursor = input_service:get("cursor")
		local x = cursor and cursor[1]

		if x then
			if self._drag_x then
				self._yaw = self._yaw + (x - self._drag_x) * 0.012

				p3d:set_yaw(self._yaw)
			end

			self._drag_x = x
		end
	else
		self._drag_x = nil
	end
end

function Preview:_tick_3d(dt, t, input_service)
	local p3d = self._p3d

	if not p3d then
		return
	end

	p3d:update(dt, t)

	local state, reason = p3d:state()

	if state ~= self._p3d_state or reason ~= self._p3d_reason then
		self._p3d_state, self._p3d_reason = state, reason
		self._layout_dirty = true

		if state == "ready" then
			p3d:set_outline(self._ol_r, self._ol_g, self._ol_b)
		end

		self:_refresh_status()
	end

	if state == "ready" then
		pcall(self._drag, self, input_service)
	end
end

-----------------------------------------------------------------------
-- Placement
-----------------------------------------------------------------------
function Preview:_relayout()
	self._layout_dirty = false

	local view = self.view
	local sg = view._ui_scenegraph
	local node = sg and sg[self.stage_id]
	local anchor = sg and sg[self.anchor_id]

	if not (node and anchor) then
		return
	end

	pcall(view._force_update_scenegraph, view)

	local scale = view._render_scale or 1
	local wp, size = node.world_position, node.size
	local sw, sh = size[1], size[2]
	local p3d = self._p3d
	local state = p3d and p3d:state()
	local ready = state == "ready"
	local stage_px_h
	local loading = state == "loading"

	if p3d then
		local xs, ys, w_scale, h_scale = UIScenegraph.get_scenegraph_id_screen_scale(sg, self.stage_id, scale)
		local _, render_h = UIScenegraph.get_render_size(sg, self.stage_id, scale)

		p3d:set_rect(xs, ys, w_scale, h_scale, sw / sh)

		stage_px_h = render_h
	end

	local res = self._res
	local breed = self._breed
	local by = res and res.bar and res.bar.y or 0
	local frac

	-- on-body debuff placement: the same projection as the HUD's camera path, from the 3D frame instead.
	-- + = below the bar (the HUD's body-minus-bar screen delta, in reference units).
	self._body_offset_y = nil

	if ready then
		local centre, span = p3d:frame()

		if centre then
			local az = ((breed and breed.base_height) or 1.8) + 0.5 + by

			frac = 0.5 - (az - centre) / span

			if span and span > 0.001 and stage_px_h and scale > 0.001 then
				local body_z = (breed and breed.base_height or 1.8) * 0.8

				self._body_offset_y = ((az - body_z) / span) * stage_px_h / scale
			end
		end
	end

	frac = frac or (0.30 - by * PX_PER_METRE_2D / sh)
	frac = math_min(math_max(frac, 0.08), 0.85)

	local tx = wp[1] + sw * 0.5
	local ty = wp[2] + sh * frac
	local aw = anchor.world_position
	local pos = anchor.position

	if not (loading and self._anchor_placed) then
		view:_set_scenegraph_position(self.anchor_id, pos[1] + (tx - aw[1]), pos[2] + (ty - aw[2]))
		pcall(view._force_update_scenegraph, view)

		self._anchor_placed = true
	end

	self._show_card = not ready and not loading
	self._cx = wp[1] + 40
	self._cw = sw - 80
	self._cy = ty + 70
	self._ch = math_max(wp[2] + sh - 24 - self._cy, 0)
end

-----------------------------------------------------------------------
-- Update / draw
-----------------------------------------------------------------------

function Preview:update(dt, t, input_service)
	if self._destroyed then
		return
	end

	if dt > 0.1 then
		dt = 0.1
	end

	self._time = self._time + dt
	self._t = t

	if self._need_sync then
		local ok, err = pcall(self._sync_3d, self)

		if not ok then
			log_once(self, "3d sync", err)

			self._3d_reason = "error (see log)"

			self:_refresh_status()
		end
	end

	if self._layout_dirty then
		local ok, err = pcall(self._relayout, self)

		if not ok then
			self._layout_dirty = false

			log_once(self, "layout", err)
		end
	end

	if self._widget and not self._widget_err then
		local ok, err = pcall(self._tick_widget, self, dt, t)

		if not ok then
			self._widget_err = err

			log_once(self, "widget update", err)

			self._note = "Preview error (see log)"

			self:_refresh_status()
		end
	end

	local ok, err = pcall(self._tick_outline, self, mod.frame_settings)

	if not ok then
		log_once(self, "outline", err)
	end

	if self._p3d and not self._p3d_err then
		local ok3, err3 = pcall(self._tick_3d, self, dt, t, input_service)

		if not ok3 then
			self._p3d_err = err3

			log_once(self, "3d update", err3)

			self._3d_reason = "error (see log)"

			self:_refresh_status()
		end
	end
end

function Preview:_draw_card(renderer)
	local x, y, w, h = self._cx, self._cy, self._cw, self._ch

	if not x or w < 40 or h < 40 then
		return
	end

	local frame, thickness = COLOR_FRAME, 2

	if self._ol_r then
		frame, thickness = COLOR_FRAME_OUTLINE, 5
		frame[2], frame[3], frame[4] = self._ol_r, self._ol_g, self._ol_b
	end

	UIRenderer.draw_rect(renderer, Vector3(x, y, 1), Vector2(w, h), COLOR_CARD)
	UIRenderer.draw_rect(renderer, Vector3(x, y, 2), Vector2(w, thickness), frame)
	UIRenderer.draw_rect(renderer, Vector3(x, y + h - thickness, 2), Vector2(w, thickness), frame)
	UIRenderer.draw_rect(renderer, Vector3(x, y, 2), Vector2(thickness, h), frame)
	UIRenderer.draw_rect(renderer, Vector3(x + w - thickness, y, 2), Vector2(thickness, h), frame)

	local opts = self._text_opts

	UIRenderer.draw_text(
		renderer,
		self._title or "",
		30,
		CARD_FONT,
		Vector3(x + 18, y + 16, 3),
		Vector2(w - 36, 40),
		COLOR_TITLE,
		opts
	)
	UIRenderer.draw_text(
		renderer,
		self._type_label or "",
		18,
		CARD_FONT,
		Vector3(x + 18, y + 58, 3),
		Vector2(w - 36, 26),
		COLOR_SUB,
		opts
	)

	local note = self._card_note

	if note and note ~= "" then
		UIRenderer.draw_text(
			renderer,
			note,
			16,
			CARD_FONT,
			Vector3(x + 18, y + 86, 3),
			Vector2(w - 36, 24),
			COLOR_SUB,
			opts
		)
	end
end

function Preview:_draw_all(renderer)
	if self._show_card then
		local ok, err = pcall(self._draw_card, self, renderer)

		if not ok then
			log_once(self, "card draw", err)
		end
	end

	local widget = self._widget

	if widget and not self._widget_err then
		UIWidget.draw(widget, renderer)
	end
end

function Preview:draw(dt, t, input_service, render_settings)
	if self._destroyed then
		return
	end

	local renderer = self._renderer
	local view = self.view

	if not (renderer and render_settings and view._ui_scenegraph) then
		return
	end

	local service = input_service

	if service and service.null_service then
		service = service:null_service()
	end

	-- an error inside UIWidget.draw leaves these changed: restore them
	local alpha = render_settings.alpha_multiplier
	local flags = render_settings.material_flags
	local intensity = render_settings.color_intensity_multiplier

	UIRenderer.begin_pass(renderer, view._ui_scenegraph, service, dt, render_settings)

	local ok, err = pcall(self._draw_all, self, renderer)

	UIRenderer.end_pass(renderer)

	render_settings.alpha_multiplier = alpha
	render_settings.material_flags = flags
	render_settings.color_intensity_multiplier = intensity

	if not ok then
		if not self._draw_err then
			self._draw_err = true

			log_once(self, "draw", err)
			self:_refresh_status()
		end
	elseif self._draw_err then
		self._draw_err = nil -- e.g. the material finished loading

		self:_refresh_status()
	end
end

-----------------------------------------------------------------------
-- Status
-----------------------------------------------------------------------

function Preview:_refresh_status()
	local p3d = self._p3d
	local state, reason

	if p3d then
		state, reason = p3d:state()
	end

	local text = ""
	local card_note = ""

	if self._guard_msg then
		text = self._guard_msg
	elseif self._note then
		text = self._note
	elseif self._draw_err then
		text = "Preview draw error (see log)"
	elseif not self.flags.threed then
		text = "3D preview off"
	elseif self._3d_reason then
		text = "3D unavailable: " .. tostring(self._3d_reason)
		card_note = "no 3D model: " .. tostring(self._3d_reason)
	elseif state == "failed" then
		text = "3D unavailable: " .. tostring(reason)
		card_note = "no 3D model: " .. tostring(reason)
	elseif state == "loading" or (self.flags.threed and not state) then
		text = "Loading " .. tostring(self._title or self.breed_name) .. "..."
	end

	local res = self._res

	if text == "" and res and res.bar and not res.bar.visible then
		text = res.bar.horde_blocked and "Healthbar hidden: horde healthbars are off"
			or "Healthbar hidden for this enemy"
	end

	if text == "" and self._widget and self._icons_ok == false then
		text = "Type icon hidden: its textures are not loaded"
	end

	self._status = text
	self._card_note = card_note
end

function Preview:status()
	return self._status or ""
end

return Preview
