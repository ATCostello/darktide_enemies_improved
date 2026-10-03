local UIWidget = require("scripts/managers/ui/ui_widget")
local UIResolution = require("scripts/managers/ui/ui_resolution")
local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")

local PANEL_W, PANEL_H = 1760, 920

local L = {
	PANEL_W = PANEL_W,
	PANEL_H = PANEL_H,
	ROWS = 14,
	TREE_ROWS = 13,
	TABS = 7,
	CHIPS = 11,
	CELLS = 70,
	PK_ROWS = 10,
	PRESETS = 12,
	CP_CH = 4,
	LIST_TOP = -295,
	PITCH = 46,
	RX0 = -280,
	RX1 = 858,
	X = {
		btn = { 470, 318 },
		btn_bool = { 470, 110 },
		dec = { 470, 36 },
		sl = { 512, 176 },
		inc = { 694, 36 },
		val = { 734, 54 },
		tg = { 470, 60 },
		sw = { 536, 252 },
		rs = { 794, 62 },
	},
	TREE_X0 = -280,
	TREE_W = 380,
	FIELDS_X0 = 120,
	LBL_WIDE = { -280, 740 },
	LBL_NARROW = { 120, 340 },
	HOV_WIDE = { -280, 1138 },
	HOV_NARROW = { 112, 746 },
	STAGE = { -860, -390, 560, 690 }, -- left, top, w, h
	SCROLL_X = 868,
	SCROLL_W = 10,
	PK_Z = 20,
	PK_ROW_H = 40,
	PK_ARROW_H = 30,
	PK_W_MIN = 260,
	CP_W = 430,
	CP_H = 372,
	PRESET_RGB = {
		{ 255, 255, 255 },
		{ 190, 190, 190 },
		{ 255, 40, 40 },
		{ 255, 140, 0 },
		{ 255, 225, 40 },
		{ 150, 255, 40 },
		{ 40, 200, 70 },
		{ 40, 230, 230 },
		{ 50, 110, 255 },
		{ 150, 70, 230 },
		{ 255, 50, 200 },
		{ 255, 150, 190 },
	},
}
L.LIST_H = L.ROWS * L.PITCH

local scenegraph_definition = {
	screen = { scale = "fit", size = { 1920, 1080 }, position = { 0, 0, 0 } },
	root = {
		parent = "screen",
		horizontal_alignment = "center",
		vertical_alignment = "center",
		size = { PANEL_W, PANEL_H },
		position = { 0, 0, 1 },
	},
}

local function node(id, x, y, w, h, z)
	scenegraph_definition[id] = {
		parent = "root",
		horizontal_alignment = "center",
		vertical_alignment = "center",
		size = { w, h },
		position = { x, y, z or 2 },
	}
end

local function cx(left, w)
	return left + w / 2
end

local widget_definitions = {}

local GOLD = { 255, 255, 214, 96 }
local GREY = { 255, 170, 170, 170 }
local FRAME = { 255, 120, 100, 70 }

widget_definitions.background = UIWidget.create_definition({
	{ pass_type = "rect", style = { color = { 240, 8, 10, 14 } } },
	{
		pass_type = "texture",
		value = "content/ui/materials/frames/frame_tile_2px",
		style = { color = FRAME, scale_to_material = true },
	},
}, "root", nil, { PANEL_W, PANEL_H })

local function text_widget(id, x, y, w, h, size, align, color, dynamic, valign)
	node(id, x, y, w, h, 3)
	return UIWidget.create_definition({
		{
			pass_type = "text",
			value_id = "text",
			style_id = "text",
			value = "",
			style = {
				font_type = "proxima_nova_bold",
				font_size = size or 22,
				text_horizontal_alignment = align or "center",
				text_vertical_alignment = valign or "center",
				text_color = color or { 255, 235, 235, 235 },
				drop_shadow = true,
				offset = { 0, 0, 4 },
			},
		},
	}, id, { text = "" }, (not dynamic) and { w, h } or nil)
end

local function button_widget(id, x, y, w, h, font_size, dynamic)
	node(id, x, y, w, h, 3)
	return UIWidget.create_definition(
		ButtonPassTemplates.terminal_button,
		id,
		{ original_text = "" },
		(not dynamic) and { w, h } or nil,
		font_size and { text = { font_size = font_size } } or nil
	)
end

local THUMB_W = 10
local function slider_passes(w, h)
	local travel = w - THUMB_W
	return {
		{ pass_type = "hotspot", content_id = "hotspot" },
		{
			pass_type = "rect",
			style_id = "track",
			style = { size = { w, 4 }, offset = { 0, h / 2 - 2, 1 }, color = { 255, 56, 56, 64 } },
		},
		{
			pass_type = "rect",
			style_id = "fill",
			style = { size = { w, 4 }, offset = { 0, h / 2 - 2, 2 }, color = { 255, 226, 199, 126 } },
			change_function = function(content, style)
				style.size[1] = (content.value01 or 0) * travel + THUMB_W / 2
			end,
		},
		{
			pass_type = "rect",
			style_id = "thumb",
			style = { size = { THUMB_W, h - 8 }, offset = { 0, 4, 3 }, color = { 255, 235, 235, 235 } },
			change_function = function(content, style)
				style.offset[1] = (content.value01 or 0) * travel
				local c = style.color
				c[2], c[3], c[4] = 235, 235, 235
				if content.dragging or content.hotspot.is_hover then
					c[2], c[3], c[4] = 255, 214, 96
				end
			end,
		},
		{
			pass_type = "logic",
			value = function(pass, renderer, style, content, position, size)
				if not content.dragging then
					if (content.hotspot.on_pressed or content.hotspot.on_double_click) and not content.disabled then
						content.dragging = true
					else
						return
					end
				end
				local input = renderer.input_service
				if not (input and input:get("left_hold")) then
					content.dragging = nil
					return
				end
				local cursor = UIResolution.inverse_scale_vector(input:get("cursor"), renderer.inverse_scale)
				content.value01 = math.clamp((cursor[1] - position[1] - THUMB_W / 2) / travel, 0, 1)
			end,
		},
	}
end

local function slider_widget(id, x, y, w, h)
	node(id, x, y, w, h, 3)
	return UIWidget.create_definition(slider_passes(w, h), id, { hotspot = {}, value01 = 0 }, { w, h })
end

local function scroll_widget(id, x, y, w, h)
	node(id, x, y, w, h, 3)
	return UIWidget.create_definition({
		{ pass_type = "hotspot", content_id = "hotspot" },
		{ pass_type = "rect", style_id = "track", style = { color = { 150, 40, 40, 46 } } },
		{
			pass_type = "rect",
			style_id = "thumb",
			style = { size = { nil, 40 }, offset = { 0, 0, 1 }, color = { 255, 150, 130, 80 } },
			change_function = function(content, style)
				style.size[2] = content.thumb_h or 40
				style.offset[2] = content.thumb_y or 0
				local c = style.color
				c[2], c[3], c[4] = 150, 130, 80
				if content.drag or content.hotspot.is_hover then
					c[2], c[3], c[4] = 226, 199, 126
				end
			end,
		},
		{
			pass_type = "logic",
			value = function(pass, renderer, style, content, position, size)
				local input = renderer.input_service
				if not input then
					return
				end
				if not content.drag then
					if content.hotspot.on_pressed or content.hotspot.on_double_click then
						local cursor = UIResolution.inverse_scale_vector(input:get("cursor"), renderer.inverse_scale)
						local rel = cursor[2] - position[2]
						local top = content.thumb_y or 0
						if rel >= top and rel <= top + (content.thumb_h or 40) then
							content.drag = rel - top
						else
							content.page = rel < top and -1 or 1
						end
					end
					return
				end
				if not input:get("left_hold") then
					content.drag = nil
					return
				end
				local cursor = UIResolution.inverse_scale_vector(input:get("cursor"), renderer.inverse_scale)
				local travel = math.max((content.track_h or 100) - (content.thumb_h or 40), 1)
				content.value01 = math.clamp((cursor[2] - position[2] - content.drag) / travel, 0, 1)
			end,
		},
	}, id, { hotspot = {}, value01 = 0, visible = false })
end

local function probe_widget(id, x, y, w, h, z)
	node(id, x, y, w, h, z or 1)
	return UIWidget.create_definition({
		{ pass_type = "hotspot", content_id = "hotspot" },
	}, id, { hotspot = {} })
end

local function swatch_widget(id, x, y, w, h)
	node(id, x, y, w, h, 3)
	return UIWidget.create_definition({
		{ pass_type = "hotspot", content_id = "hotspot" },
		{ pass_type = "rect", style_id = "back", style = { color = { 255, 12, 12, 14 } } },
		{
			pass_type = "rect",
			style_id = "swatch",
			style = { size = { w - 6, h - 6 }, offset = { 3, 3, 1 }, color = { 255, 255, 255, 255 } },
		},
		{
			pass_type = "texture",
			style_id = "frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = { color = FRAME, scale_to_material = true, offset = { 0, 0, 2 } },
			change_function = function(content, style)
				local c = style.color
				if content.hotspot.is_hover then
					c[2], c[3], c[4] = 255, 214, 96
				else
					c[2], c[3], c[4] = 120, 100, 70
				end
			end,
		},
		{
			pass_type = "text",
			value_id = "text",
			style_id = "text",
			value = "",
			style = {
				font_type = "proxima_nova_bold",
				font_size = 16,
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				text_color = { 255, 255, 255, 255 },
				drop_shadow = false,
				offset = { 0, 0, 4 },
			},
		},
	}, id, { hotspot = {}, text = "" }, { w, h })
end

widget_definitions.title = text_widget("title", cx(-860, 700), -420, 700, 40, 28, "left", GOLD)
widget_definitions.btn_close = button_widget("btn_close", PANEL_W / 2 - 34, -420, 46, 46)

do
	local sx, sy, sw, sh = L.STAGE[1], L.STAGE[2], L.STAGE[3], L.STAGE[4]
	node("pv_stage", cx(sx, sw), sy + sh / 2, sw, sh, 2)
	widget_definitions.pv_stage = UIWidget.create_definition({
		{ pass_type = "hotspot", content_id = "hotspot" },
		{ pass_type = "rect", style = { color = { 255, 6, 8, 12 } } },
		{
			pass_type = "texture",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = { color = FRAME, scale_to_material = true, offset = { 0, 0, 1 } },
		},
	}, "pv_stage", { hotspot = {} }, { sw, sh })
	scenegraph_definition.pv_anchor = {
		parent = "root",
		horizontal_alignment = "center",
		vertical_alignment = "center",
		size = { 0, 0 },
		position = { cx(sx, sw), sy + sh * 0.3, 10 },
	}
end

widget_definitions.pv_enemy = button_widget("pv_enemy", cx(-860, 420), 330, 420, 40, 16)
widget_definitions.pv_debuffs = button_widget("pv_debuffs", cx(-430, 130), 330, 130, 40, 16)
for i, id in ipairs({ "pv_combat", "pv_alert", "pv_stagger", "pv_tagged" }) do
	widget_definitions[id] = button_widget(id, cx(-860 + (i - 1) * 142, 134), 376, 134, 40, 15)
end
widget_definitions.pv_status = text_widget("pv_status", cx(-860, 560), 410, 560, 22, 15, "left", GREY)

local TAB_W = 162
for i = 1, L.TABS do
	widget_definitions["tab_" .. i] = button_widget("tab_" .. i, cx(-280 + (i - 1) * 163, TAB_W), -370, TAB_W, 40, 16)
end
for i = 1, L.CHIPS do
	widget_definitions["chip_" .. i] = button_widget("chip_" .. i, 0, -328, 100, 30, 14, true)
end

local function row_y(i)
	return L.LIST_TOP + L.PITCH / 2 + (i - 1) * L.PITCH
end

local X = L.X
local ROW_HOVER = { 0, 255, 255, 255 }
for i = 1, L.ROWS do
	local y = row_y(i)
	local p = "r" .. i .. "_"
	node(p .. "hov", cx(L.HOV_WIDE[1], L.HOV_WIDE[2]), y, L.HOV_WIDE[2], L.PITCH - 2, 1)
	widget_definitions[p .. "hov"] = UIWidget.create_definition({
		{ pass_type = "hotspot", content_id = "hotspot" },
		{
			pass_type = "rect",
			style_id = "tint",
			style = { color = { 0, 255, 255, 255 } },
			change_function = function(content, style)
				style.color[1] = content.hotspot.is_hover and 20 or 0
			end,
		},
	}, p .. "hov", { hotspot = {} })

	node(p .. "lbl", cx(L.LBL_WIDE[1], L.LBL_WIDE[2]), y, L.LBL_WIDE[2], L.PITCH - 2, 3)
	widget_definitions[p .. "lbl"] = UIWidget.create_definition({
		{
			pass_type = "text",
			value_id = "text",
			style_id = "text",
			value = "",
			style = {
				font_type = "proxima_nova_bold",
				font_size = 17,
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				text_color = { 255, 225, 225, 225 },
				drop_shadow = true,
				offset = { 10, 0, 4 },
			},
		},
		{
			pass_type = "rect",
			style_id = "line",
			style = {
				size = { nil, 2 },
				vertical_alignment = "bottom",
				offset = { 0, -4, 2 },
				color = { 140, 226, 199, 126 },
				visible = false,
			},
		},
	}, p .. "lbl", { text = "" })

	widget_definitions[p .. "btn"] = button_widget(p .. "btn", cx(X.btn[1], X.btn[2]), y, X.btn[2], 36, 16, true)
	widget_definitions[p .. "dec"] = button_widget(p .. "dec", cx(X.dec[1], X.dec[2]), y, X.dec[2], 32, 20)
	widget_definitions[p .. "sl"] = slider_widget(p .. "sl", cx(X.sl[1], X.sl[2]), y, X.sl[2], 32)
	widget_definitions[p .. "inc"] = button_widget(p .. "inc", cx(X.inc[1], X.inc[2]), y, X.inc[2], 32, 20)
	widget_definitions[p .. "val"] = text_widget(p .. "val", cx(X.val[1], X.val[2]), y, X.val[2], 32, 17, "center")
	widget_definitions[p .. "tg"] = button_widget(p .. "tg", cx(X.tg[1], X.tg[2]), y, X.tg[2], 36, 15)
	widget_definitions[p .. "sw"] = swatch_widget(p .. "sw", cx(X.sw[1], X.sw[2]), y, X.sw[2], 36)
	widget_definitions[p .. "rs"] = button_widget(p .. "rs", cx(X.rs[1], X.rs[2]), y, X.rs[2], 32, 14)
end

widget_definitions.list_hov =
	probe_widget("list_hov", cx(L.RX0, L.RX1 - L.RX0), L.LIST_TOP + L.LIST_H / 2, L.RX1 - L.RX0, L.LIST_H, 1)
widget_definitions.scroll = scroll_widget("scroll", L.SCROLL_X, L.LIST_TOP + L.LIST_H / 2, L.SCROLL_W, L.LIST_H)

for i = 1, L.TREE_ROWS do
	widget_definitions["t_" .. i] = button_widget("t_" .. i, cx(L.TREE_X0, L.TREE_W), row_y(i), L.TREE_W, 40, 16)
end

for i = 1, L.CELLS do
	widget_definitions["g_" .. i] = button_widget("g_" .. i, 0, 0, 100, 40, 16, true)
end

node("desc_box", cx(-280, 1140), 384, 1140, 60, 2)
widget_definitions.desc_box = UIWidget.create_definition({
	{ pass_type = "rect", style = { color = { 235, 10, 12, 16 } } },
	{
		pass_type = "texture",
		value = "content/ui/materials/frames/frame_tile_2px",
		style = { color = FRAME, scale_to_material = true, offset = { 0, 0, 1 } },
	},
}, "desc_box", nil, { 1140, 60 })
widget_definitions.desc_text =
	text_widget("desc_text", cx(-268, 1116), 384, 1116, 56, 16, "left", { 255, 215, 215, 215 }, false, "top")
widget_definitions.status = text_widget("status", cx(-860, 1300), 438, 1300, 30, 17, "left", { 255, 180, 180, 180 })
widget_definitions.btn_reset_page = button_widget("btn_reset_page", cx(640, 220), 438, 220, 34, 15)

local PK_Z = L.PK_Z

node("pk_veil", cx(-290, 1170), 0, 1170, PANEL_H, PK_Z)
node("pk_panel", 0, 0, L.PK_W_MIN, 100, PK_Z + 1)
widget_definitions.pk_veil = UIWidget.create_definition({
	{ pass_type = "rect", style = { color = { 150, 0, 0, 0 } } },
}, "pk_veil", { visible = false })
widget_definitions.pk_panel = UIWidget.create_definition({
	{ pass_type = "hotspot", content_id = "hotspot" },
	{ pass_type = "rect", style = { color = { 250, 12, 14, 20 } } },
	{
		pass_type = "texture",
		value = "content/ui/materials/frames/frame_tile_2px",
		style = { color = FRAME, scale_to_material = true },
	},
}, "pk_panel", { visible = false })

local function pk_button(id, h)
	node(id, 0, 0, L.PK_W_MIN, h, PK_Z + 2)
	widget_definitions[id] = UIWidget.create_definition(
		ButtonPassTemplates.terminal_button,
		id,
		{ original_text = "", visible = false },
		nil,
		{ text = { font_size = 19 } }
	)
end
for i = 1, L.PK_ROWS do
	pk_button("pk_row_" .. i, L.PK_ROW_H)
end
pk_button("pk_head", L.PK_ROW_H)
pk_button("pk_up", L.PK_ARROW_H)
pk_button("pk_down", L.PK_ARROW_H)

local CP_Z = PK_Z + 1
node("cp_panel", 0, 0, L.CP_W, L.CP_H, CP_Z)
widget_definitions.cp_panel = UIWidget.create_definition({
	{ pass_type = "hotspot", content_id = "hotspot" },
	{ pass_type = "rect", style = { color = { 252, 12, 14, 20 } } },
	{
		pass_type = "texture",
		value = "content/ui/materials/frames/frame_tile_2px",
		style = { color = FRAME, scale_to_material = true },
	},
}, "cp_panel", { visible = false })

local function hidden(def)
	def.content.visible = false
	return def
end

widget_definitions.cp_title = hidden(text_widget("cp_title", 0, 0, L.CP_W - 36, 30, 20, "left", GOLD))
widget_definitions.cp_swatch = hidden(swatch_widget("cp_swatch", 0, 0, L.CP_W - 36, 44))
for c = 1, L.CP_CH do
	widget_definitions["cp_l" .. c] = hidden(text_widget("cp_l" .. c, 0, 0, 24, 30, 18, "center"))
	widget_definitions["cp_s" .. c] = hidden(slider_widget("cp_s" .. c, 0, 0, 290, 30))
	widget_definitions["cp_v" .. c] = hidden(text_widget("cp_v" .. c, 0, 0, 52, 30, 17, "center"))
end
for i = 1, L.PRESETS do
	local id = "cp_pre_" .. i
	local rgb = L.PRESET_RGB[i]
	node(id, 0, 0, 30, 30, CP_Z + 1)
	widget_definitions[id] = hidden(UIWidget.create_definition({
		{ pass_type = "hotspot", content_id = "hotspot" },
		{
			pass_type = "rect",
			style_id = "swatch",
			style = { size = { 24, 24 }, offset = { 3, 3, 1 }, color = { 255, rgb[1], rgb[2], rgb[3] } },
		},
		{
			pass_type = "texture",
			style_id = "frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = { color = FRAME, scale_to_material = true, offset = { 0, 0, 2 } },
			change_function = function(content, style)
				local c = style.color
				if content.hotspot.is_hover then
					c[2], c[3], c[4] = 255, 255, 255
				else
					c[2], c[3], c[4] = 120, 100, 70
				end
			end,
		},
	}, id, { hotspot = {} }, { 30, 30 }))
end
widget_definitions.cp_default = hidden(button_widget("cp_default", 0, 0, 190, 40, 17))
widget_definitions.cp_done = hidden(button_widget("cp_done", 0, 0, 190, 40, 17))
for _, id in ipairs({ "cp_title", "cp_swatch", "cp_default", "cp_done" }) do
	scenegraph_definition[id].position[3] = CP_Z + 1
end
for c = 1, L.CP_CH do
	scenegraph_definition["cp_l" .. c].position[3] = CP_Z + 1
	scenegraph_definition["cp_s" .. c].position[3] = CP_Z + 1
	scenegraph_definition["cp_v" .. c].position[3] = CP_Z + 1
end

return {
	widget_definitions = widget_definitions,
	scenegraph_definition = scenegraph_definition,
	layout = L,
}
