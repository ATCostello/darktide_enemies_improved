require("scripts/ui/views/base_view")
local UIWidget = require("scripts/managers/ui/ui_widget")
local definition_path = "enemies_improved/scripts/mods/enemies_improved/editor/ei_editor_view_definitions"
local pages_path = "enemies_improved/scripts/mods/enemies_improved/editor/ei_editor_pages"
local preview_path = "enemies_improved/scripts/mods/enemies_improved/editor/ei_preview"
local View = class("EnemiesImprovedEditorView", "BaseView")

local mod = get_mod("enemies_improved")

local L
local Pages

local math_floor, math_max, math_min, math_clamp = math.floor, math.max, math.min, math.clamp

local COL = {
	default = { 255, 225, 225, 225 },
	gold = { 255, 255, 214, 96 },
	hover = { 255, 255, 255, 255 },
	grey = { 255, 150, 150, 150 },
	dim = { 255, 110, 110, 110 },
	gold_dim = { 255, 140, 118, 60 },
	header = { 255, 226, 199, 126 },
	type_row = { 255, 245, 235, 200 },
}
local SEL_EDGE = { 255, 255, 214, 96 }
local SEL_FILL = { 205, 120, 96, 30 }

local SLOT_KEYS = { "lbl", "hov", "btn", "dec", "sl", "inc", "val", "tg", "sw", "rs" }
local VIS = {
	header = { true, false, false, false, false, false, false, false, false, false },
	note = { true, true, true, false, false, false, false, false, false, false },
	bool = { true, true, true, false, false, false, false, false, false, true },
	enum = { true, true, true, false, false, false, false, false, false, true },
	tri = { true, true, true, false, false, false, false, false, false, true },
	num = { true, true, false, true, true, true, true, false, false, true },
	int = { true, true, false, true, true, true, true, false, false, true },
	color = { true, true, false, false, false, false, false, true, true, true },
}
local FMT = { [0] = "%.0f", "%.1f", "%.2f", "%.3f", "%.4f" }

local CH_IDX = { 2, 3, 4, 1 }
local CH_LETTER = { "R", "G", "B", "A" }
local CH_FILL = { { 255, 230, 70, 70 }, { 255, 70, 200, 90 }, { 255, 80, 130, 255 }, { 255, 200, 200, 200 } }

local WHEEL_ROWS = 3
local NO_ROWS = {}
local EMPTY_SUB = { label = "", rows = NO_ROWS }
local PK_ROW_H, PK_STEP, PK_ARROW_H, PK_PAD, PK_W_MIN, PK_WHEEL = 40, 42, 30, 8, 260, 2
local PK_LEFT_MIN = -276

local function fit(text, max_chars)
	if Utf8 and Utf8.string_length(text) > max_chars then
		return Utf8.sub_string(text, 1, max_chars - 2) .. ".."
	end
	return text
end

local function LOC(key)
	return mod:localize(key)
end

local function show(widget, on)
	local content = widget.content
	if content.visible ~= on then
		content.visible = on
		local hotspot = content.hotspot
		if hotspot then
			hotspot.disabled = not on
			if not on then
				hotspot.is_hover = false
				hotspot.on_pressed = false
			end
		end
	end
end

local function set_text(widget, text)
	local content = widget.content
	if content.text ~= text then
		content.text = text
	end
end

local function set_label(button, text)
	local content = button.content
	if content.original_text ~= text then
		content.original_text = text
	end
end

local function set_disabled(button, disabled)
	local hotspot = button.content.hotspot
	if hotspot.disabled ~= disabled then
		hotspot.disabled = disabled
	end
end

local function select_style(b)
	local s = b.style
	if s.frame then
		s.frame.selected_color = SEL_EDGE
	end
	if s.corner then
		s.corner.selected_color = SEL_EDGE
	end
	if s.background then
		s.background.selected_color = SEL_FILL
	end
	if s.background_gradient then
		s.background_gradient.selected_color = SEL_FILL
	end
end

local function copy_colour(c)
	return { c[1], c[2], c[3], c[4] }
end

local function ed_state()
	local st = mod._ei_ed
	if not st then
		st = {
			page = 1,
			sel_scope = "breed",
			sel_key = "renegade_executor",
			breed = "renegade_executor",
			combat = true,
			alert = false,
			stagger = false,
			tagged = false,
			sub = {},
		}
		mod._ei_ed = st
	end
	st.sub = st.sub or {}
	return st
end

View.init = function(self, settings, context)
	local definitions = require(definition_path)
	View.super.init(self, definitions, settings, context)
	L = definitions.layout
	self._mod = (context and context.mod) or mod
	self._S = mod.settings_api
	self._rows, self._subs = {}, {}
	self._first, self._sub = 1, 1
	self._tree = {}
	self._grid, self._cell_chars = nil, 20
	self._confirm = nil
	self._message = nil
	self._hover_row = nil
	self._pending, self._tree_dirty, self._draw_dirty = false, false, true
	self._acc = 0
	self._label_chars = 90
	self._ready = false
end

-- ---------------------------------------------------------------------------
-- Enter / wire
-- ---------------------------------------------------------------------------

View.on_enter = function(self)
	View.super.on_enter(self)
	local S = self._S
	local w = self._widgets_by_name
	if not S then
		mod:error("[ei_editor] mod.settings_api is missing; the editor cannot work")
		w.title.content.text = "Enemies Improved: settings API missing (Esc to close)"
		return
	end
	Pages = mod:io_dofile(pages_path)
	local st = ed_state()
	self._st = st
	st.threed = mod:get("ei_preview_3d_enabled") ~= false

	self._types = S.types()
	self._type_label = {}
	self._breeds_by_type = {}
	for i = 1, #self._types do
		local t = self._types[i]
		self._type_label[t.id] = t.label
		self._breeds_by_type[t.id] = S.breeds(t.id)
	end
	self._breeds = S.breeds()
	self._breed_label, self._breed_opts = {}, {}
	for i = 1, #self._breeds do
		local b = self._breeds[i]
		self._breed_label[b.name] = b.label
		self._breed_opts[i] = { value = b.name, label = b.label }
	end

	self._debuff_opts = {}
	local groups = S.debuff_groups()
	for i = 1, #groups do
		local names = groups[i].names
		for k = 1, #names do
			self._debuff_opts[#self._debuff_opts + 1] = { value = names[k], label = S.debuff_label(names[k]) }
		end
	end
	table.sort(self._debuff_opts, function(a, b)
		if a.label ~= b.label then
			return a.label < b.label
		end
		return a.value < b.value
	end)
	self._pv_debuffs = {}

	self._slots = {}
	for i = 1, L.ROWS do
		local slot = { i = i, y = L.LIST_TOP + L.PITCH / 2 + (i - 1) * L.PITCH, btn_w = L.X.btn[2] }
		for k = 1, #SLOT_KEYS do
			slot[SLOT_KEYS[k]] = w["r" .. i .. "_" .. SLOT_KEYS[k]]
		end
		self._slots[i] = slot
	end
	self._tree_w, self._tab_w, self._chip_w = {}, {}, {}
	for i = 1, L.TREE_ROWS do
		self._tree_w[i] = w["t_" .. i]
	end

	self._cell_w, self._cell_col = {}, {}
	for i = 1, L.CELLS do
		local cell = w["g_" .. i]
		local col, hov = { 255, 255, 255, 255 }, { 255, 255, 255, 255 }
		cell.style.text.default_color, cell.style.text.hover_color = col, hov
		self._cell_w[i], self._cell_col[i] = cell, { col = col, hov = hov }
	end
	for i = 1, L.TABS do
		self._tab_w[i] = w["tab_" .. i]
	end
	for i = 1, L.CHIPS do
		self._chip_w[i] = w["chip_" .. i]
	end
	self._cp_sl, self._cp_v, self._cp_l, self._cp_pre = {}, {}, {}, {}
	for c = 1, L.CP_CH do
		self._cp_sl[c], self._cp_v[c], self._cp_l[c] = w["cp_s" .. c], w["cp_v" .. c], w["cp_l" .. c]
		self._cp_sl[c].style.fill.color = CH_FILL[c]
		self._cp_l[c].content.text = CH_LETTER[c]
	end
	for i = 1, L.PRESETS do
		self._cp_pre[i] = w["cp_pre_" .. i]
	end
	self._cp_ids = { "cp_panel", "cp_title", "cp_swatch", "cp_default", "cp_done" }
	for c = 1, L.CP_CH do
		local ids = self._cp_ids
		ids[#ids + 1] = "cp_l" .. c
		ids[#ids + 1] = "cp_s" .. c
		ids[#ids + 1] = "cp_v" .. c
	end
	for i = 1, L.PRESETS do
		self._cp_ids[#self._cp_ids + 1] = "cp_pre_" .. i
	end
	self._pk_ids = { "pk_veil", "pk_panel", "pk_head", "pk_up", "pk_down" }
	for i = 1, L.PK_ROWS do
		self._pk_ids[#self._pk_ids + 1] = "pk_row_" .. i
	end

	self._t = {
		on = LOC("ei_on"),
		off = LOC("ei_off"),
		inherit = LOC("ei_tri_inherit"),
		force = LOC("ei_tri_force"),
		block = LOC("ei_tri_block"),
	}
	w.title.content.text = LOC("ei_editor_title")
	w.btn_close.content.original_text = "X"
	for i = 1, L.TABS do
		set_label(self._tab_w[i], LOC(Pages.list[i].title))
	end
	local reset_text = LOC("ei_reset_short")
	for i = 1, L.ROWS do
		local slot = self._slots[i]
		set_label(slot.dec, "-")
		set_label(slot.inc, "+")
		set_label(slot.rs, reset_text)
	end
	set_label(w.cp_default, LOC("ei_default"))
	set_label(w.cp_done, LOC("ei_done"))
	set_label(w.pv_debuffs, LOC("ei_preview_debuffs"))
	set_label(w.pv_combat, LOC("ei_preview_combat"))
	set_label(w.pv_alert, LOC("ei_preview_alert"))
	set_label(w.pv_stagger, LOC("ei_preview_stagger"))
	set_label(w.pv_tagged, LOC("ei_preview_tagged"))
	for i = 1, L.TREE_ROWS do
		local ts = self._tree_w[i].style.text
		ts.text_horizontal_alignment = "left"
		ts.offset[1] = 12
	end
	for i = 1, L.ROWS do
		for k = 1, #SLOT_KEYS do
			show(self._slots[i][SLOT_KEYS[k]], false)
		end
	end

	self._draw = {}

	self._serial = S.serial
	mod._ei_view = self

	self:_wire()
	self:_preview_create()
	self._ready = true
	self:_set_page(math_clamp(st.page or 1, 1, L.TABS))
end

local CONFIRM_BUTTONS = { btn_reset_page = true }

View._wire = function(self)
	local w = self._widgets_by_name
	local function bind(id, ...)
		local b = w[id]
		if b and b.content.hotspot then
			local hotspot = b.content.hotspot
			hotspot.pressed_callback = callback(self, ...)
			if not CONFIRM_BUTTONS[id] then
				hotspot.double_click_callback = hotspot.pressed_callback
			end
			return hotspot.pressed_callback
		end
	end

	bind("btn_close", "cb_close")
	bind("btn_reset_page", "cb_reset_page")
	for i = 1, L.TABS do
		bind("tab_" .. i, "cb_tab", i)
		select_style(self._tab_w[i])
	end
	for i = 1, L.CHIPS do
		bind("chip_" .. i, "cb_chip", i)
		select_style(self._chip_w[i])
	end
	for i = 1, L.ROWS do
		local p = "r" .. i .. "_"
		self._slots[i].btn_cb = bind(p .. "btn", "cb_btn", i)
		bind(p .. "dec", "cb_step", i, -1)
		bind(p .. "inc", "cb_step", i, 1)
		bind(p .. "sw", "cb_swatch", i)
		bind(p .. "tg", "cb_row_toggle", i)
		bind(p .. "rs", "cb_row_reset", i)
		select_style(self._slots[i].btn)
		select_style(self._slots[i].tg)
	end
	for i = 1, L.TREE_ROWS do
		bind("t_" .. i, "cb_tree", i)
		select_style(self._tree_w[i])
	end
	for i = 1, L.CELLS do
		bind("g_" .. i, "cb_cell", i)
		select_style(self._cell_w[i])
	end
	bind("pv_enemy", "cb_pv_enemy")
	bind("pv_debuffs", "cb_pv_debuffs")
	for _, flag in ipairs({ "combat", "alert", "stagger", "tagged" }) do
		bind("pv_" .. flag, "cb_pv_flag", flag)
		select_style(w["pv_" .. flag])
	end
	select_style(w.pv_debuffs)
	for i = 1, L.PK_ROWS do
		bind("pk_row_" .. i, "_pk_pick", i)
		select_style(w["pk_row_" .. i])
	end
	bind("pk_head", "cb_pk_head")
	select_style(w.pk_head)
	bind("pk_up", "_pk_scroll", -L.PK_ROWS)
	bind("pk_down", "_pk_scroll", L.PK_ROWS)
	for i = 1, L.PRESETS do
		bind("cp_pre_" .. i, "cb_cp_preset", i)
	end
	bind("cp_default", "cb_cp_default")
	bind("cp_done", "cb_cp_done")
end

-- ---------------------------------------------------------------------------
-- Preview
-- ---------------------------------------------------------------------------

View._pv_fail = function(self, what, err)
	self._pv_dead = true
	mod:error("[ei_editor] preview %s failed, preview disabled: %s", what, tostring(err))
end

View._pv_call = function(self, name, ...)
	local p = self._preview
	if p and not self._pv_dead then
		local ok, err = pcall(p[name], p, ...)
		if not ok then
			self:_pv_fail(name, err)
		end
	end
end

View._preview_create = function(self)
	local st = self._st
	local ok, Preview = pcall(function()
		return mod:io_dofile(preview_path)
	end)
	if not ok or not Preview or type(Preview.new) ~= "function" then
		if not ok then
			mod:error("[ei_editor] preview module failed to load: %s", tostring(Preview))
		end
		return
	end
	local created, p = pcall(Preview.new, self, { stage_id = "pv_stage", anchor_id = "pv_anchor" })
	if not created or not p then
		mod:error("[ei_editor] Preview.new failed: %s", tostring(p))
		return
	end
	self._preview = p
	st.threed = mod:get("ei_preview_3d_enabled") ~= false
	self:_pv_call("set_subject", { breed_name = st.breed })
	self:_pv_push_flags()
end

View._pv_push_flags = function(self)
	local st = self._st
	self:_pv_call("set_flags", {
		combat = st.combat,
		alert = st.alert,
		stagger = st.stagger,
		tagged = st.tagged,
		threed = st.threed,
	})
end

View._set_subject = function(self, breed_name)
	self._st.breed = breed_name
	self:_pv_call("set_subject", { breed_name = breed_name })
	self:_refresh_preview_controls()
end

View.cb_pv_flag = function(self, flag)
	self:_touch()
	local st = self._st
	st[flag] = not st[flag]
	self:_pv_push_flags()
	self:_refresh_preview_controls()
end

View.cb_pv_debuffs = function(self)
	self:_touch()
	self:picker_open("pv_debuffs", self._debuff_opts, self._pv_debuffs, nil, 560, {
		multi = true,
		head = true,
		on_toggle = function(name)
			if self._pv_debuffs[name] then
				self._pv_debuffs[name] = nil
			else
				self._pv_debuffs[name] = true
			end
			self:_pv_push_debuffs()
			self:_refresh_preview_controls()
		end,
	})
end

View.cb_pk_head = function(self)
	self:_touch()
	local st = self._st
	st.threed = not (st.threed ~= false)
	mod:set("ei_preview_3d_enabled", st.threed)
	self:_pv_push_flags()
	self:_refresh_preview_controls()

	if self._pk then
		self:_pk_refresh()
	end
end

View._pv_push_debuffs = function(self)
	local names = {}
	for name in next, self._pv_debuffs do
		names[#names + 1] = name
	end
	table.sort(names)
	self:_pv_call("set_debuffs", names)
end

View.cb_pv_enemy = function(self)
	self:_touch()
	self:picker_open("pv_enemy", self._breed_opts, self._st.breed, function(name)
		if self._is_enemies then
			self:_select_node("breed", name) -- switches to the breed's type chip
		else
			self:_set_subject(name)
		end
	end, 360)
end

View._update_focus = function(self)
	local hov = self._hover_row
	local name
	if hov then
		name = hov.debuff_name
	else
		name = self._edit_debuff
	end
	if name ~= self._focus_name then
		self._focus_name = name
		local p = self._preview
		if p and p.set_focus_debuff then
			self:_pv_call("set_focus_debuff", name)
		end
	end
end

View._refresh_preview_controls = function(self)
	local w = self._widgets_by_name
	local st = self._st
	set_label(w.pv_enemy, LOC("ei_preview_enemy") .. ": " .. fit(self._breed_label[st.breed] or st.breed, 34))
	local worn = 0
	for _ in next, self._pv_debuffs do
		worn = worn + 1
	end
	local label = LOC("ei_preview_debuffs")
	set_label(w.pv_debuffs, worn > 0 and (label .. " (" .. worn .. ")") or label)
	w.pv_debuffs.content.hotspot.is_selected = worn > 0
	for _, flag in ipairs({ "combat", "alert", "stagger", "tagged" }) do
		w["pv_" .. flag].content.hotspot.is_selected = st[flag] == true
	end
end

-- ---------------------------------------------------------------------------
-- State helpers
-- ---------------------------------------------------------------------------
View._touch = function(self)
	local had = self._confirm ~= nil or self._message ~= nil
	local row_confirm = self._confirm ~= nil and self._confirm ~= "page"
	self._confirm = nil
	self._message = nil
	if had then
		self._footer_dirty = true
	end
	if row_confirm then
		self:_refresh_rows()
	end
end

View._written = function(self, immediate)
	self._pending = true
	self._tree_dirty = true
	if immediate then
		self:_apply_now()
	end
	self:_refresh_rows()
end

View._apply_now = function(self)
	self._pending = false
	local S = self._S
	if S.is_dirty() then
		local ok, err = pcall(S.apply)
		if not ok then
			mod:error("[ei_editor] settings apply failed: %s", tostring(err))
		end
	end
	if S.serial ~= self._serial then
		self._serial = S.serial
		self:_pv_call("settings_changed")
	end
end

-- ---------------------------------------------------------------------------
-- Pages
-- ---------------------------------------------------------------------------

View._set_page = function(self, index)
	self:picker_close()
	self:_cp_close()
	self._page = index
	local st = self._st
	st.page = index
	local page = Pages.list[index]
	self._is_enemies = page.id == "enemies"
	self._hint = LOC(page.hint)
	self._confirm = nil
	self._hover_row = nil
	self._edit_debuff = nil
	local ok, subs = pcall(Pages.subpages, page.id)
	if not ok then
		mod:error("[ei_editor] page build failed (%s): %s", page.id, tostring(subs))
		subs = {}
	end
	self._subs = subs
	local sub = st.sub[index] or 1
	self._chip_mod, self._tree, self._tree_dirty = nil, {}, false
	if self._is_enemies then
		self._sub_of_type, self._type_all, self._chip_mod = {}, {}, {}
		local all = LOC("ei_type_all")
		for i = 1, #subs do
			local type_id = subs[i].type
			self._sub_of_type[type_id] = i
			self._type_all[type_id] = all .. " " .. subs[i].label
			self._chip_mod[i] = self:_type_modified(type_id)
		end
		local type_id = st.sel_scope == "type" and st.sel_key or self._S.type_of(st.sel_key)
		sub = self._sub_of_type[type_id] or sub
	else
		self:_set_subject(st.breed)
	end
	self:_layout_page()
	self:_set_sub(math_clamp(sub, 1, math_max(#subs, 1)), st.sel_scope, st.sel_key)
end

View._set_sub = function(self, i, sel_scope, sel_key)
	self:picker_close()
	self:_cp_close()
	if self._tree_dirty then
		self:_refresh_tree()
	end
	local sub = self._subs[i] or EMPTY_SUB
	self._sub = i
	self._st.sub[self._page] = i
	self._confirm = nil
	self._hover_row = nil
	self._edit_debuff = nil
	self._first = 1
	self._grid = sub.grid
	if self._is_enemies and sub.type then
		self._sub_type = sub.type
		self:_build_tree(sub.type)
		if not (sel_scope and self:_tree_index(sel_scope, sel_key)) then
			sel_scope, sel_key = "type", sub.type
		end
		self:_apply_node(sel_scope, sel_key)
	else
		self._rows = sub.rows
	end
	self:_layout_sub()
	self:_refresh_all()
end

View._layout_page = function(self)
	local enemies = self._is_enemies
	local lbl = enemies and L.LBL_NARROW or L.LBL_WIDE
	local hov = enemies and L.HOV_NARROW or L.HOV_WIDE
	for i = 1, L.ROWS do
		local p = "r" .. i .. "_"
		self:_set_scenegraph_size(p .. "lbl", lbl[2])
		self:_set_scenegraph_position(p .. "lbl", lbl[1] + lbl[2] / 2)
		self:_set_scenegraph_size(p .. "hov", hov[2])
		self:_set_scenegraph_position(p .. "hov", hov[1] + hov[2] / 2)
	end
	local lw = enemies and L.RX1 - 112 or L.RX1 - L.RX0
	self:_set_scenegraph_size("list_hov", lw)
	self:_set_scenegraph_position("list_hov", (enemies and 112 or L.RX0) + lw / 2)
	self._label_chars = enemies and 36 or 90

	if not enemies then
		for i = 1, L.TREE_ROWS do
			show(self._tree_w[i], false)
		end
	end
	show(self._widgets_by_name.btn_reset_page, not enemies)

	local n = math_min(#self._subs, L.CHIPS)
	local many = n >= 9
	local gap = many and 4 or 6
	local cw = n > 0 and math_min(160, math_floor((L.RX1 - L.RX0 - gap * (n - 1)) / n)) or 0
	local chars = math_max(8, math_floor(cw / (many and 7.2 or 8.5)))
	for i = 1, L.CHIPS do
		local chip = self._chip_w[i]
		if i <= n then
			chip.style.text.font_size = many and 13 or 14
			self:_set_scenegraph_size(chip.name, cw, 30)
			self:_set_scenegraph_position(chip.name, L.RX0 + cw / 2 + (i - 1) * (cw + gap))
			set_label(chip, fit(self._subs[i].label, chars))
		end
		show(chip, i <= n)
	end
end

View._layout_sub = function(self)
	if self._grid then
		self:_layout_grid()
	end
	self._draw_dirty = true
end

View._layout_grid = function(self)
	local n = math_min(#self._rows, L.CELLS)
	local cols = math_clamp(math.ceil(n / L.ROWS), self._grid == "colours" and 3 or 1, 5)
	local per = math_max(1, math.ceil(n / cols))
	local gap = 8
	local cw = math_floor((L.RX1 - L.RX0 - gap * (cols - 1)) / cols)
	self._cell_chars = math_max(8, math_floor(cw / 9.5))
	for i = 1, n do
		local id = self._cell_w[i].name
		local c, r = math_floor((i - 1) / per), (i - 1) % per
		self:_set_scenegraph_size(id, cw, 40)
		self:_set_scenegraph_position(id, L.RX0 + cw / 2 + c * (cw + gap), L.LIST_TOP + L.PITCH / 2 + r * L.PITCH)
	end
end

View._refresh_all = function(self)
	self:_refresh_tabs()
	self:_refresh_chips()
	self:_refresh_rows()
	self:_refresh_tree()
	self:_refresh_preview_controls()
	self:_update_footer()
	self:_update_desc()
end

View._refresh_tabs = function(self)
	for i = 1, L.TABS do
		local b = self._tab_w[i]
		local active = i == self._page
		b.content.hotspot.is_selected = active
		b.style.text.default_color = active and COL.gold or COL.default
		b.style.text.hover_color = COL.hover
	end
end

View._refresh_chips = function(self)
	local chip_mod = self._chip_mod
	for i = 1, math_min(#self._subs, L.CHIPS) do
		local chip = self._chip_w[i]
		local active = i == self._sub
		chip.content.hotspot.is_selected = active
		chip.style.text.default_color = (active or (chip_mod and chip_mod[i])) and COL.gold or COL.default
		chip.style.text.hover_color = COL.hover
	end
	self._draw_dirty = true
end

View.cb_tab = function(self, i)
	self:_touch()
	if i ~= self._page then
		self:_set_page(i)
	end
end

View.cb_chip = function(self, i)
	self:_touch()
	-- on the Enemies page a click always (re)selects the chip's type node
	if self._subs[i] and (i ~= self._sub or self._is_enemies) then
		self:_set_sub(i)
	end
end

-- ---------------------------------------------------------------------------
-- Settings rows
-- ---------------------------------------------------------------------------

local function slider_from01(row, v01)
	local lo, hi, step = row.min, row.max, row.step
	local v = lo + (hi - lo) * v01
	v = lo + math_floor((v - lo) / step + 0.5) * step
	local m = 10 ^ (row.decimals or 0)
	v = math_floor(v * m + 0.5) / m
	return math_clamp(v, lo, hi)
end

local function colour_hex(c)
	return string.format("#%02X%02X%02X", math_floor(c[2] + 0.5), math_floor(c[3] + 0.5), math_floor(c[4] + 0.5))
end

local function colour_to_swatch(widget, c, has_alpha)
	local sc = widget.style.swatch.color
	sc[2], sc[3], sc[4] = c[2], c[3], c[4]
	local tc = widget.style.text.text_color
	local dark = (c[2] * 0.3 + c[3] * 0.59 + c[4] * 0.11) > 140
	local v = dark and 0 or 255
	tc[2], tc[3], tc[4] = v, v, v
	local text = colour_hex(c)
	if has_alpha then
		text = text .. "  A" .. math_floor(c[1] + 0.5)
	end
	set_text(widget, text)
end

View._btn_width = function(self, slot, width)
	if slot.btn_w ~= width then
		slot.btn_w = width
		self:_set_scenegraph_size(slot.btn.name, width)
		self:_set_scenegraph_position(slot.btn.name, L.X.btn[1] + width / 2)
	end
end

View._fill_slot = function(self, slot, row)
	if slot.row ~= row then
		slot.sl.content.dragging = nil
	end
	slot.row = row
	local vis = row and VIS[row.kind]
	if not vis then
		slot.row = nil
		for k = 1, #SLOT_KEYS do
			show(slot[SLOT_KEYS[k]], false)
		end
		return
	end
	local S = self._S
	local kind = row.kind
	local editable = kind ~= "header" and kind ~= "note"
	local changed = editable and not row.is_default()
	local dim = editable
		and ((row.requires ~= nil and S.get(row.requires) ~= true) or (row.req_get ~= nil and not row.req_get()))

	for k = 1, #SLOT_KEYS do
		local on = vis[k]
		local key = SLOT_KEYS[k]
		if key == "btn" and kind == "note" then
			on = row.button ~= nil
		elseif key == "tg" then
			on = on and row.toggle_get ~= nil
		elseif key == "rs" then
			on = on and changed
		end
		show(slot[key], on)
	end

	-- label
	local lbl = slot.lbl
	set_text(lbl, fit(row.label or "", self._label_chars))
	local ts, line = lbl.style.text, lbl.style.line
	if kind == "header" then
		ts.font_size = 20
		ts.text_color = COL.header
		line.visible = true
	else
		ts.font_size = 17
		line.visible = false
		if kind == "note" then
			ts.text_color = COL.grey
		elseif changed then
			ts.text_color = dim and COL.gold_dim or COL.gold
		else
			ts.text_color = dim and COL.dim or COL.default
		end
	end

	local btn = slot.btn
	if kind == "bool" then
		local on = row.get() == true
		self:_btn_width(slot, L.X.btn_bool[2])
		set_label(btn, on and self._t.on or self._t.off)
		btn.content.hotspot.is_selected = on
		btn.content.hotspot.double_click_callback = slot.btn_cb
	elseif kind == "enum" then
		local v = row.get()
		local text = tostring(v)
		local options = row.options
		for i = 1, options and #options or 0 do
			if options[i].value == v then
				text = options[i].label
				break
			end
		end
		self:_btn_width(slot, L.X.btn[2])
		set_label(btn, text)
		btn.content.hotspot.is_selected = false
		btn.content.hotspot.double_click_callback = slot.btn_cb
	elseif kind == "tri" then
		local v = row.get()
		self:_btn_width(slot, L.X.btn[2])
		set_label(btn, v == nil and self._t.inherit or (v and self._t.force or self._t.block))
		btn.content.hotspot.is_selected = v ~= nil
		btn.content.hotspot.double_click_callback = slot.btn_cb
	elseif kind == "note" and row.button then
		local confirming = row.confirm ~= nil and self._confirm == row.id
		self:_btn_width(slot, L.X.btn[2])
		set_label(btn, confirming and row.confirm or row.button)
		btn.content.hotspot.is_selected = confirming
		btn.content.hotspot.double_click_callback = (row.confirm == nil) and slot.btn_cb or nil
	elseif kind == "num" or kind == "int" then
		local v = row.get() or row.min
		local sl = slot.sl
		set_text(slot.val, string.format(FMT[row.decimals or 0] or "%.2f", v))
		if not sl.content.dragging then
			sl.content.value01 = math_clamp((v - row.min) / (row.max - row.min), 0, 1)
		end
		set_disabled(slot.dec, v <= row.min)
		set_disabled(slot.inc, v >= row.max)
		slot.val.style.text.text_color = changed and COL.gold or COL.default
	elseif kind == "color" then
		colour_to_swatch(slot.sw, row.get(), row.has_alpha)
		if row.toggle_get then
			local on = row.toggle_get()
			set_label(slot.tg, on and self._t.on or self._t.off)
			slot.tg.content.hotspot.is_selected = on
		end
	end
end

View._list_total = function(self)
	return self._grid and 0 or #self._rows
end

View._fill_cell = function(self, i, row)
	local cell = self._cell_w[i]
	local cc = self._cell_col[i]
	local col, hov = cc.col, cc.hov
	local g = row.group_colour()
	local hotspot = cell.content.hotspot
	local on = true
	if row.kind == "bool" then
		on = row.get() == true
		hotspot.is_selected = on
	else
		hotspot.is_selected = not row.is_default()
	end
	local a = (row.requires ~= nil and self._S.get(row.requires) ~= true) and 130 or 255
	set_label(cell, fit(row.label or "", self._cell_chars))
	if on then
		col[1], col[2], col[3], col[4] = a, g[2], g[3], g[4]
		hov[1], hov[2], hov[3], hov[4] = a, g[2], g[3], g[4]
	else
		col[1], col[2], col[3], col[4] = a, 150, 150, 150
		hov[1], hov[2], hov[3], hov[4] = 255, 255, 255, 255
	end
end

View._refresh_cells = function(self)
	local rows = self._rows
	local n = self._grid and math_min(#rows, L.CELLS) or 0
	for i = 1, L.CELLS do
		local on = i <= n
		show(self._cell_w[i], on)
		if on then
			self:_fill_cell(i, rows[i])
		end
	end
end

View._refresh_rows = function(self)
	local rows = self._grid and NO_ROWS or self._rows
	local slots = self._slots
	local total = #rows
	local max_first = math_max(1, total - L.ROWS + 1)
	self._first = math_clamp(self._first, 1, max_first)
	local first = self._first
	for i = 1, L.ROWS do
		self:_fill_slot(slots[i], rows[first + i - 1])
	end
	self:_update_scroll(self._widgets_by_name.scroll, first, total, L.ROWS, L.LIST_H)
	self:_refresh_cells()
	self._hover_row = nil
	self._draw_dirty = true
end

View._update_scroll = function(self, widget, first, total, per, track_h)
	local c = widget.content
	local max_first = total - per + 1
	if max_first < 2 then
		show(widget, false)
		return
	end
	show(widget, true)
	local thumb_h = math_max(32, track_h * per / total)
	local travel = track_h - thumb_h
	c.track_h, c.thumb_h = track_h, thumb_h
	if not c.drag then
		c.value01 = (first - 1) / (max_first - 1)
	end
	c.thumb_y = c.value01 * travel
end

View._scroll_main = function(self, first)
	local max_first = math_max(1, self:_list_total() - L.ROWS + 1)
	first = math_clamp(first, 1, max_first)
	if first ~= self._first then
		self._first = first
		self:_refresh_rows()
	end
end

-- ---------------------------------------------------------------------------
-- Row callbacks
-- ---------------------------------------------------------------------------

View.cb_btn = function(self, i)
	local row = self._slots[i].row
	if not row then
		return
	end
	local kind = row.kind
	local armed = self._confirm == row.id
	self:_touch()
	self._edit_debuff = row.debuff_name
	self:_update_focus()
	if kind == "note" then
		if row.confirm and not armed then
			self._confirm = row.id
			self:_refresh_rows()
		else
			row.action()
		end
	elseif kind == "bool" then
		row.set(row.get() ~= true)
		self:_written(true)
	elseif kind == "tri" then
		local v = row.get()
		if v == nil then
			v = true
		elseif v == true then
			v = false
		else
			v = nil
		end
		row.set(v)
		self:_written(true)
	elseif kind == "enum" then
		self:picker_open(self._slots[i].btn.name, row.options or {}, row.get(), function(value)
			row.set(value)
			self:_written(true)
		end, L.X.btn[2])
	end
end

View.cb_step = function(self, i, dir)
	local row = self._slots[i].row
	if not row then
		return
	end
	self:_touch()
	local m = 10 ^ (row.decimals or 0)
	local v = math_floor(((row.get() or row.min) + dir * row.step) * m + 0.5) / m
	row.set(math_clamp(v, row.min, row.max))
	self:_written(true)
end

View.cb_row_toggle = function(self, i)
	local row = self._slots[i].row
	if row and row.toggle_get then
		self:_touch()
		row.toggle_set(not row.toggle_get())
		self:_written(true)
	end
end

View.cb_row_reset = function(self, i)
	local row = self._slots[i].row
	if row and row.reset then
		self:_touch()
		self._edit_debuff = row.debuff_name
		self:_update_focus()
		row.reset()
		self:_written(true)
	end
end

View.cb_swatch = function(self, i)
	self:_touch()
	local slot = self._slots[i]
	local row = slot.row
	self._edit_debuff = row and row.debuff_name
	self:_update_focus()
	self:_cp_open(row, slot.sw.name)
end

-- ---------------------------------------------------------------------------
-- Enemies page
-- ---------------------------------------------------------------------------
View._type_modified = function(self, type_id)
	local S = self._S
	if S.ov_is_modified("type", type_id) then
		return true
	end
	local breeds = self._breeds_by_type[type_id] or NO_ROWS
	for i = 1, #breeds do
		if S.ov_is_modified("breed", breeds[i].name) then
			return true
		end
	end
	return false
end

View._build_tree = function(self, type_id)
	local out = {}
	if type_id then
		out[1] = { scope = "type", key = type_id, label = self._type_all[type_id] or type_id, indent = 0 }
		local breeds = self._breeds_by_type[type_id] or NO_ROWS
		for i = 1, math_min(#breeds, L.TREE_ROWS - 1) do
			out[#out + 1] = { scope = "breed", key = breeds[i].name, label = breeds[i].label, indent = 1 }
		end
	end
	self._tree = out
end

View._tree_index = function(self, scope, key)
	local tree = self._tree
	for i = 1, #tree do
		if tree[i].scope == scope and tree[i].key == key then
			return i
		end
	end
	return nil
end

View._refresh_tree = function(self)
	if not self._is_enemies then
		return
	end
	self._tree_dirty = false
	local S = self._S
	local tree = self._tree
	local any = false
	for i = 1, L.TREE_ROWS do
		local b = self._tree_w[i]
		local entry = tree[i]
		show(b, entry ~= nil)
		if entry then
			local modified = S.ov_is_modified(entry.scope, entry.key)
			any = any or modified
			set_label(b, entry.label)
			b.style.text.offset[1] = entry.indent == 0 and 12 or 34
			b.style.text.default_color = modified and COL.gold or (entry.indent == 0 and COL.type_row or COL.default)
			b.style.text.hover_color = COL.hover
			b.content.hotspot.is_selected = entry.scope == self._sel_scope and entry.key == self._sel_key
		end
	end
	local chip_mod = self._chip_mod
	if chip_mod and chip_mod[self._sub] ~= any then
		chip_mod[self._sub] = any
		self:_refresh_chips()
	end
	self._draw_dirty = true
end

View._apply_node = function(self, scope, key)
	self._sel_scope, self._sel_key = scope, key
	local st = self._st
	st.sel_scope, st.sel_key = scope, key
	self._confirm = nil
	self._rows = Pages.enemy_rows(scope, key, {
		select_node = function(sc, k)
			self:_touch()
			self:_select_node(sc, k)
		end,
		reset_node = function()
			self._S.ov_reset(self._sel_scope, self._sel_key)
			self._message = LOC("ei_msg_node_reset")
			self:_written(true)
			self._footer_dirty = true
		end,
	})
	self._first = 1
	self:_set_subject(scope == "type" and (self._S.representative(key) or st.breed) or key)
end

View._select_node = function(self, scope, key)
	local type_id = scope == "type" and key or self._S.type_of(key)
	local index = self._sub_of_type and self._sub_of_type[type_id]
	if index and index ~= self._sub then
		self:_set_sub(index, scope, key)
		return
	end
	self:_apply_node(scope, key)
	self:_refresh_rows()
	self:_refresh_tree()
	self:_update_desc()
end

View.cb_tree = function(self, i)
	local entry = self._tree[i]
	if entry then
		self:_touch()
		self:_select_node(entry.scope, entry.key)
	end
end

View.cb_cell = function(self, i)
	local row = self._rows[i]
	if not row then
		return
	end
	self:_touch()
	self._edit_debuff = row.debuff_name
	self:_update_focus()
	if row.kind == "color" then
		self:_cp_open(row, self._cell_w[i].name)
	else
		row.set(row.get() ~= true)
		self:_written(true)
	end
end

-- ---------------------------------------------------------------------------
-- Description box + footer
-- ---------------------------------------------------------------------------

local function plain(text)
	return (string.gsub(string.gsub(text, "%s*\n+%s*", "  "), "{#.-}", ""))
end

View._update_desc = function(self)
	self:_update_focus()
	local row = self._hover_row
	local text = row and row.tooltip
	if text and text ~= "" then
		text = row._desc
		if not text then
			text = fit(plain(row.tooltip), 400)
			row._desc = text
		end
	else
		text = self._hint or ""
	end
	set_text(self._widgets_by_name.desc_text, text)
end

View._scan_hover = function(self)
	local hovered
	if self._grid then
		local rows, cells = self._rows, self._cell_w
		for i = 1, math_min(#rows, L.CELLS) do
			local c = cells[i].content
			if c.visible and c.hotspot.is_hover then
				hovered = rows[i]
				break
			end
		end
	else
		local slots = self._slots
		for i = 1, L.ROWS do
			local slot = slots[i]
			if slot.row and slot.hov.content.visible and slot.hov.content.hotspot.is_hover then
				hovered = slot.row
				break
			end
		end
	end
	if hovered ~= self._hover_row then
		self._hover_row = hovered
		self:_update_desc()
	end
end

View._update_footer = function(self)
	self._footer_dirty = false
	local w = self._widgets_by_name
	set_text(w.status, self._message or LOC("ei_footer_saved"))
	set_label(w.btn_reset_page, LOC(self._confirm == "page" and "ei_reset_page_confirm" or "ei_reset_page"))
	w.btn_reset_page.content.hotspot.is_selected = self._confirm == "page"
end

View.cb_reset_page = function(self)
	if self._confirm ~= "page" then
		self:_touch()
		self._confirm = "page"
		self._footer_dirty = true
		return
	end
	self:_touch()
	local rows = self._rows
	for i = 1, #rows do
		local row = rows[i]
		if row.reset and row.is_default and not row.is_default() then
			row.reset()
		end
	end
	self._message = LOC("ei_msg_page_reset")
	self._footer_dirty = true
	self:_written(true)
end

-- ---------------------------------------------------------------------------
-- Colour popup (right area only)
-- ---------------------------------------------------------------------------
View._cp_open = function(self, row, anchor_id)
	if self._pk or self._cp or not row or row.kind ~= "color" then
		return
	end
	local n = row.has_alpha and 4 or 3
	local W, H = L.CP_W, 208 + 38 * n
	local ax, ay = self:_scenegraph_position(anchor_id)
	local rw, rh = self:_scenegraph_size("root")
	local px = math_clamp(ax, PK_LEFT_MIN + W / 2, rw / 2 - W / 2 - 10)
	local top = ay + 22
	if top + H > rh / 2 - 10 then
		top = ay - 22 - H
	end
	top = math_clamp(top, -rh / 2 + 10, rh / 2 - 10 - H)
	local il = px - W / 2 + 18
	local y0 = top + 18
	local function put(id, x, y, w, h)
		if w then
			self:_set_scenegraph_size(id, w, h)
		end
		self:_set_scenegraph_position(id, x, y)
	end
	put("cp_panel", px, top + H / 2, W, H)
	put("cp_title", px, y0 + 15)
	put("cp_swatch", px, y0 + 58)
	for c = 1, L.CP_CH do
		local y = y0 + 90 + 38 * (c - 1) + 15
		put("cp_l" .. c, il + 12, y)
		put("cp_s" .. c, il + 177, y)
		put("cp_v" .. c, il + 356, y)
	end
	local py = y0 + 90 + 38 * n
	for k = 1, L.PRESETS do
		put("cp_pre_" .. k, il + 15 + (k - 1) * 33, py + 15)
	end
	put("cp_default", il + 95, py + 30 + 12 + 20)
	put("cp_done", il + 299, py + 30 + 12 + 20)
	self._widgets_by_name.cp_title.content.text = string.gsub(row.label or "", "^%s+", "")
	self._cp = { row = row, n = n, armed = false }
	self:_pk_block(true)
end

View._cp_close = function(self)
	if not self._cp then
		return
	end
	self._cp = nil
	self._pk_unblock = true
	local w = self._widgets_by_name
	for i = 1, #self._cp_ids do
		show(w[self._cp_ids[i]], false)
	end
	w.pk_veil.content.visible = false
	self._draw_dirty = true
end

View._cp_refresh = function(self)
	local cp = self._cp
	local row = cp.row
	local c = row.get()
	colour_to_swatch(self._widgets_by_name.cp_swatch, c, row.has_alpha)
	for ch = 1, cp.n do
		local v = c[CH_IDX[ch]]
		local sl = self._cp_sl[ch]
		if not sl.content.dragging then
			sl.content.value01 = math_clamp(v / 255, 0, 1)
		end
		set_text(self._cp_v[ch], tostring(math_floor(v + 0.5)))
	end
end

View.cb_cp_preset = function(self, k)
	local cp = self._cp
	if cp and cp.armed then
		local c = copy_colour(cp.row.get())
		local rgb = L.PRESET_RGB[k]
		c[2], c[3], c[4] = rgb[1], rgb[2], rgb[3]
		cp.row.set(c)
		self:_written(true)
		self:_cp_refresh()
	end
end

View.cb_cp_default = function(self)
	local cp = self._cp
	if cp and cp.armed then
		local d = cp.row.default_colour and cp.row.default_colour()
		if d then
			cp.row.set(copy_colour(d))
			self:_written(true)
			self:_cp_refresh()
		end
	end
end

View.cb_cp_done = function(self)
	if self._cp and self._cp.armed then
		self:_cp_close()
	end
end

View._cp_input = function(self, input_service)
	local cp = self._cp
	local w = self._widgets_by_name
	if not cp.armed then
		cp.armed = true
		w.pk_veil.content.visible = true
		for i = 1, #self._cp_ids do
			local id = self._cp_ids[i]
			local ch = tonumber(string.match(id, "^cp_[lsv](%d)$"))
			show(w[id], not ch or ch <= cp.n)
		end
		self:_cp_refresh()
		self._draw_dirty = true
		return
	end
	local inside = w.cp_panel.content.hotspot.is_hover
	if
		input_service:get("back")
		or ((input_service:get("left_pressed") or input_service:get("right_pressed")) and not inside)
	then
		self:_cp_close()
	end
end

View._cp_poll = function(self)
	local cp = self._cp
	if not (cp and cp.armed) then
		return
	end
	for ch = 1, cp.n do
		local sl = self._cp_sl[ch]
		if sl.content.dragging then
			local v = math_floor(sl.content.value01 * 255 + 0.5)
			local c = copy_colour(cp.row.get())
			if c[CH_IDX[ch]] ~= v then
				c[CH_IDX[ch]] = v
				cp.row.set(c)
				self:_written(false)
				self:_cp_refresh()
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Dropdown picker
-- ---------------------------------------------------------------------------
View.picker_open = function(self, anchor_id, options, current, on_select, width, opts)
	if self._pk or self._cp or #options == 0 then
		return
	end
	opts = opts or {}
	local head = opts.head and true or false
	local ax, ay = self:_scenegraph_position(anchor_id)
	local aw, ah = self:_scenegraph_size(anchor_id)
	local rw, rh = self:_scenegraph_size("root")
	local total = #options
	local n = math_min(total, L.PK_ROWS)
	local scroll = total > n
	local w = math_min(math_max(width or aw, PK_W_MIN), 700)
	local head_h = head and (PK_ROW_H + 4) or 0
	local h = PK_PAD * 2 + head_h + n * PK_STEP - (PK_STEP - PK_ROW_H) + (scroll and 2 * (PK_ARROW_H + 2) or 0)

	local x = math_clamp(ax, PK_LEFT_MIN + w / 2, rw / 2 - w / 2 - 10)
	local top = ay + ah / 2 + 4
	if top + h > rh / 2 - 10 then
		top = ay - ah / 2 - 4 - h
	end
	top = math_clamp(top, -rh / 2 + 10, rh / 2 - 10 - h)

	self:_set_scenegraph_size("pk_panel", w, h)
	self:_set_scenegraph_position("pk_panel", x, top + h / 2)
	local y = top + PK_PAD
	if head then
		self:_set_scenegraph_size("pk_head", w - 2 * PK_PAD, PK_ROW_H)
		self:_set_scenegraph_position("pk_head", x, y + PK_ROW_H / 2)
		y = y + head_h
	end
	if scroll then
		self:_set_scenegraph_size("pk_up", w - 2 * PK_PAD, PK_ARROW_H)
		self:_set_scenegraph_position("pk_up", x, y + PK_ARROW_H / 2)
		y = y + PK_ARROW_H + 2
	end
	for i = 1, L.PK_ROWS do
		self:_set_scenegraph_size("pk_row_" .. i, w - 2 * PK_PAD, PK_ROW_H)
		self:_set_scenegraph_position("pk_row_" .. i, x, y + PK_ROW_H / 2 + (i - 1) * PK_STEP)
	end
	if scroll then
		y = y + n * PK_STEP
		self:_set_scenegraph_size("pk_down", w - 2 * PK_PAD, PK_ARROW_H)
		self:_set_scenegraph_position("pk_down", x, y + PK_ARROW_H / 2)
	end

	local index = 1
	for i = 1, total do
		if options[i].value == current then
			index = i
			break
		end
	end

	self._pk = {
		options = options,
		current = current,
		on_select = on_select,
		multi = opts.multi and true or false,
		on_toggle = opts.on_toggle,
		head = head,
		n = n,
		scroll = scroll,
		offset = math_clamp(index - math.ceil(n / 2), 0, total - n),
		armed = false,
	}
	self:_pk_block(true)
end

View.picker_close = function(self)
	if not self._pk then
		return
	end
	self._pk = nil
	self._pk_unblock = true
	local w = self._widgets_by_name
	for i = 1, #self._pk_ids do
		w[self._pk_ids[i]].content.visible = false
	end
	self._draw_dirty = true
end

View._pk_block = function(self, on)
	local widgets = self._widgets
	for i = 1, #widgets do
		local widget = widgets[i]
		local hotspot = widget.content.hotspot
		if hotspot then
			local name = widget.name
			if not (string.find(name, "^pk_") or string.find(name, "^cp_")) then
				hotspot.force_disabled = on or nil
			end
		end
	end
end

View._pk_refresh = function(self)
	local pk, w = self._pk, self._widgets_by_name
	local total = #pk.options
	pk.offset = math_clamp(pk.offset, 0, total - pk.n)
	w.pk_veil.content.visible = true
	w.pk_panel.content.visible = true
	if pk.head then
		local threed = self._st.threed ~= false
		w.pk_head.content.visible = true
		w.pk_head.content.original_text = LOC("ei_preview_3d") .. ": " .. (threed and self._t.on or self._t.off)
		w.pk_head.content.hotspot.is_selected = threed
		w.pk_head.style.text.default_color = COL.gold
		w.pk_head.style.text.hover_color = COL.hover
	end
	for i = 1, L.PK_ROWS do
		local b = w["pk_row_" .. i]
		local o = i <= pk.n and pk.options[pk.offset + i] or nil
		b.content.visible = o ~= nil
		if o then
			local is_cur = pk.multi and pk.current[o.value] == true or o.value == pk.current
			b.content.original_text = o.label
			b.content.hotspot.is_selected = is_cur
			b.style.text.default_color = is_cur and COL.gold or COL.default
			b.style.text.hover_color = COL.hover
		end
	end
	w.pk_up.content.visible = pk.scroll
	w.pk_up.content.original_text = "^"
	w.pk_up.content.hotspot.disabled = pk.offset <= 0
	w.pk_down.content.visible = pk.scroll
	w.pk_down.content.original_text = "v"
	w.pk_down.content.hotspot.disabled = pk.offset >= total - pk.n
	self._draw_dirty = true
end

View._pk_pick = function(self, i)
	local pk = self._pk
	local o = pk and pk.armed and pk.options[pk.offset + i]
	if not o then
		return
	end
	if pk.multi then
		pk.on_toggle(o.value)
		self:_pk_refresh()

		return
	end
	local on_select = pk.on_select
	self:picker_close()
	on_select(o.value)
end

View._pk_scroll = function(self, delta)
	if self._pk and self._pk.armed then
		self._pk.offset = self._pk.offset + delta
		self:_pk_refresh()
	end
end

View._pk_input = function(self, input_service)
	local pk = self._pk
	if not pk.armed then
		pk.armed = true
		self:_pk_refresh()
		return
	end
	local inside = self._widgets_by_name.pk_panel.content.hotspot.is_hover
	if
		input_service:get("back")
		or ((input_service:get("left_pressed") or input_service:get("right_pressed")) and not inside)
	then
		self:picker_close()
		return
	end
	local ok, axis = pcall(input_service.get, input_service, "scroll_axis")
	local scroll = ok and axis and axis[2] or 0
	if scroll ~= 0 and pk.scroll then
		self:_pk_scroll(scroll > 0 and -PK_WHEEL or PK_WHEEL)
	end
end

-- ---------------------------------------------------------------------------
-- Frame
-- ---------------------------------------------------------------------------
View._rebuild_draw = function(self)
	self._draw_dirty = false
	local list = self._draw
	local widgets = self._widgets
	local n = 0
	for i = 1, #widgets do
		local widget = widgets[i]
		if widget.content.visible ~= false then
			n = n + 1
			list[n] = widget
		end
	end
	for i = n + 1, #list do
		list[i] = nil
	end
end

View._poll_inputs = function(self, dt)
	local w = self._widgets_by_name
	local slots = self._slots

	for i = 1, L.ROWS do
		local slot = slots[i]
		local row = slot.row
		if row and (row.kind == "num" or row.kind == "int") then
			local c = slot.sl.content
			if c.dragging then
				local v = slider_from01(row, c.value01)
				local cur = row.get()
				if cur == nil or math.abs(cur - v) > 1e-9 then
					row.set(v)
					self:_written(false)
				end
			end
		end
	end
	if self._cp then
		self:_cp_poll()
	end

	local sc = w.scroll.content
	if sc.visible then
		local max_first = math_max(1, self:_list_total() - L.ROWS + 1)
		if sc.drag then
			self:_scroll_main(1 + math_floor(sc.value01 * (max_first - 1) + 0.5))
		elseif sc.page then
			self:_scroll_main(self._first + sc.page * (L.ROWS - 1))
		end
		sc.page = nil
	end

	self._acc = self._acc + dt
	if self._acc >= 0.1 then
		self._acc = 0
		if self._pending or self._S.is_dirty() then
			self:_apply_now()
		end
		if self._tree_dirty then
			self:_refresh_tree()
		end
	end
end

View.update = function(self, dt, t, input_service, view_data)
	self._view_data = view_data
	if self._pv_dead and self._preview then
		pcall(self._preview.destroy, self._preview)
		self._preview = nil
	end
	if self._ready then
		self:_poll_inputs(dt)
		if not (self._pk or self._cp) then
			self:_scan_hover()
		end
		if self._footer_dirty then
			self:_update_footer()
		end
	end
	local pass_input, pass_draw = View.super.update(self, dt, t, input_service)
	if self._ready and self._draw_dirty then
		self:_rebuild_draw()
	end
	local p = self._preview
	if p and not self._pv_dead and self._ready then
		local w = self._widgets_by_name
		local pv_input = input_service
		if self._pk or self._cp or not w.pv_stage.content.hotspot.is_hover then
			pv_input = input_service:null_service()
		end
		local ok, err = pcall(p.update, p, dt, t, pv_input)
		if not ok then
			self:_pv_fail("update", err)
		else
			local ok2, status = pcall(p.status, p)
			set_text(w.pv_status, ok2 and type(status) == "string" and status or "")
		end
	elseif self._ready and (not p or self._pv_dead) then
		set_text(self._widgets_by_name.pv_status, LOC("ei_preview_unavailable"))
	end
	return pass_input, pass_draw
end

View._handle_input = function(self, input_service, dt, t)
	if not input_service or input_service:is_null_service() then
		return
	end

	if self._pk_unblock then
		self._pk_unblock = nil
		self:_pk_block(false)
	end
	if self._pk then
		self:_pk_input(input_service)
		return
	end
	if self._cp then
		self:_cp_input(input_service)
		return
	end

	if input_service:get("back") then
		self:cb_close()
		return
	end

	if self:using_cursor_navigation() then
		if self._widgets_by_name.list_hov.content.hotspot.is_hover and self:_list_total() > L.ROWS then
			local ok, axis = pcall(input_service.get, input_service, "scroll_axis")
			local scroll = ok and axis and axis[2] or 0
			if scroll ~= 0 then
				self:_scroll_main(self._first + (scroll > 0 and -WHEEL_ROWS or WHEEL_ROWS))
			end
		end
	end
end

View._draw_widgets = function(self, dt, t, input_service, ui_renderer, render_settings)
	local widgets = self._draw
	if not widgets or #widgets == 0 then
		widgets = self._widgets
	end
	for i = 1, #widgets do
		UIWidget.draw(widgets[i], ui_renderer)
	end
end

View.draw = function(self, dt, t, input_service, layer)
	View.super.draw(self, dt, t, input_service, layer)
	local p = self._preview
	if p and not self._pv_dead and self._ready then
		local ok, err = pcall(p.draw, p, dt, t, input_service, self._render_settings)
		if not ok then
			self:_pv_fail("draw", err)
		end
	end
end

View.on_resolution_modified = function(self, scale)
	local w, h = RESOLUTION_LOOKUP.width, RESOLUTION_LOOKUP.height
	if scale ~= self._rs_scale or w ~= self._rs_w or h ~= self._rs_h then
		self._rs_scale, self._rs_w, self._rs_h = scale, w, h
		self:_pv_call("on_resolution_modified")
	end
end

View.cb_close = function(self)
	pcall(function()
		Managers.ui:close_view(self.view_name)
	end)
end

View.on_exit = function(self)
	self._ready = false
	local S = self._S
	if S then
		local ok, err = pcall(function()
			S.apply()
			S.save()
		end)
		if not ok then
			mod:error("[ei_editor] final apply/save failed: %s", tostring(err))
		end
	end
	if self._preview then
		pcall(self._preview.destroy, self._preview)
		self._preview = nil
	end
	if mod._ei_view == self then
		mod._ei_view = nil
	end
	View.super.on_exit(self)
end

return View
