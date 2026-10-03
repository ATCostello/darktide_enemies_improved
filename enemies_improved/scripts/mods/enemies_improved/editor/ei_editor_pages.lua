local mod = get_mod("enemies_improved")

local Pages = {}

Pages.list = {
	{ id = "general", title = "ei_page_general", hint = "ei_hint_general" },
	{ id = "healthbars", title = "ei_page_healthbars", hint = "ei_hint_healthbars" },
	{ id = "damage", title = "ei_page_damage", hint = "ei_hint_damage" },
	{ id = "debuffs", title = "ei_page_debuffs", hint = "ei_hint_debuffs" },
	{ id = "markers", title = "ei_page_markers", hint = "ei_hint_markers" },
	{ id = "outlines", title = "ei_page_outlines", hint = "ei_hint_outlines" },
	{ id = "enemies", title = "ei_page_enemies", hint = "ei_hint_enemies_tabs" },
}

Pages.missing = {}
local missing_seen = {}

local function note_missing(text)
	if not missing_seen[text] then
		missing_seen[text] = true
		Pages.missing[#Pages.missing + 1] = text
	end
end

local function LOC(key)
	return mod:localize(key)
end

local function colour_equal(a, b)
	if not (a and b) then
		return a == b
	end
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

local function step_decimals(step)
	if not step or step >= 1 and step == math.floor(step) then
		return 0
	end
	local s = string.format("%.4f", step):gsub("0+$", "")
	local dot = s:find(".", 1, true)
	return dot and (#s - dot) or 0
end

local function num_spec(S, id, w)
	local spec = S.num_spec and S.num_spec(id)
	if spec then
		return spec.min, spec.max, spec.step, math.max(spec.decimals or 0, step_decimals(spec.step))
	end
	local step = w.step_size_value or w.step or 1
	local decimals = math.max(w.decimals_number or w.decimals or 0, step_decimals(step))
	return w.range and w.range[1] or 0, w.range and w.range[2] or 1, step, decimals
end

-- ---------------------------------------------------------------------------
-- Builder
-- ---------------------------------------------------------------------------

local function new_builder(S)
	local B = { subs = {} }
	local rows

	B.sub = function(key)
		rows = {}
		B.subs[#B.subs + 1] = { label = LOC(key), rows = rows }
	end

	B.grid = function(key, kind, cells)
		B.subs[#B.subs + 1] = { label = LOC(key), rows = cells, grid = kind }
	end

	B.add = function(row)
		rows[#rows + 1] = row
		return row
	end

	B.setting = function(id, requires)
		local w = S.schema(id)
		if not w then
			note_missing(id)
			return nil
		end
		local row = { id = id, label = S.label(id), tooltip = S.tooltip(id), requires = requires }
		local t = w.type
		if t == "color" then
			local base = S.colour_base(id) or id
			row.kind = "color"
			row.has_alpha = S.colour_has_alpha(base)
			row.get = function()
				return S.get_colour(base)
			end
			row.set = function(c)
				S.set_colour(base, c)
			end
			row.is_default = function()
				return colour_equal(S.get_colour(base), S.default_colour(base))
			end
			row.reset = function()
				S.set_colour(base, S.default_colour(base))
			end
			row.default_colour = function()
				return S.default_colour(base)
			end
		else
			row.get = function()
				return S.get(id)
			end
			row.set = function(v)
				S.set(id, v)
			end
			row.is_default = function()
				return S.is_default(id)
			end
			row.reset = function()
				S.reset(id)
			end
			if t == "checkbox" then
				row.kind = "bool"
			elseif t == "numeric" then
				row.min, row.max, row.step, row.decimals = num_spec(S, id, w)
				row.kind = row.decimals > 0 and "num" or "int"
			elseif t == "dropdown" then
				row.kind = "enum"
				row.options = S.options(id)
			else
				note_missing(id .. " (unsupported type " .. tostring(t) .. ")")
				return nil
			end
		end
		return B.add(row)
	end

	B.settings = function(ids, requires)
		for i = 1, #ids do
			B.setting(ids[i], requires)
		end
	end

	return B
end

local function ov_field(S, scope, key, fk)
	local fields = S.ov_fields(scope, key)
	for i = 1, #fields do
		if fields[i].key == fk then
			return fields[i]
		end
	end
	return nil
end

local function ov_tri_row(S, scope, key, tri_fk, label, requires)
	local f = ov_field(S, scope, key, tri_fk)

	if not f then
		return nil
	end

	return {
		kind = "tri",
		label = label or f.label_text or tri_fk,
		tooltip = f.tooltip_text,
		requires = requires,
		get = function()
			return S.ov_get(scope, key, tri_fk)
		end,
		set = function(v)
			S.ov_set(scope, key, tri_fk, v)
		end,
		is_default = function()
			return S.ov_is_default(scope, key, tri_fk)
		end,
		reset = function()
			S.ov_set(scope, key, tri_fk, S.ov_default(scope, key, tri_fk))
		end,
	}
end

local function ov_colour_row(S, scope, key, label, colour_fk, toggle_fk, requires)
	local cf = ov_field(S, scope, key, colour_fk)
	if not cf then
		return nil
	end
	local row = {
		kind = "color",
		label = label,
		tooltip = cf.tooltip_text,
		requires = requires,
		has_alpha = false,
		get = function()
			return S.ov_get(scope, key, colour_fk)
		end,
		set = function(c)
			S.ov_set(scope, key, colour_fk, c)
		end,
		default_colour = function()
			return S.ov_default(scope, key, colour_fk)
		end,
	}
	if toggle_fk and ov_field(S, scope, key, toggle_fk) then
		row.toggle_get = function()
			return S.ov_get(scope, key, toggle_fk) == true
		end
		row.toggle_set = function(v)
			S.ov_set(scope, key, toggle_fk, v)
		end
		row.is_default = function()
			return S.ov_is_default(scope, key, colour_fk) and S.ov_is_default(scope, key, toggle_fk)
		end
		row.reset = function()
			S.ov_set(scope, key, colour_fk, S.ov_default(scope, key, colour_fk))
			S.ov_set(scope, key, toggle_fk, S.ov_default(scope, key, toggle_fk))
		end
	else
		row.is_default = function()
			return S.ov_is_default(scope, key, colour_fk)
		end
		row.reset = function()
			S.ov_set(scope, key, colour_fk, S.ov_default(scope, key, colour_fk))
		end
	end
	return row
end

-- ---------------------------------------------------------------------------
-- Pages
-- ---------------------------------------------------------------------------

local PAGE = {}

PAGE.general = function(B, S)
	B.sub("ei_sec_features")
	B.settings({ "healthbar_enable", "hb_show_damage_numbers", "debuff_enable", "markers_enable", "outlines_enable" })
	B.sub("ei_sec_visibility")
	B.settings({
		"draw_distance", "enable_depth_fading", "global_opacity", "markers_show_only_aimed",
		"only_tagged_enemies", "only_in_meatgrinder",
	})
	B.sub("ei_sec_text")
	B.settings({
		"font_type", "text_scale", "main_font_colour_rgb", "secondary_font_colour_rgb", "mod_name_pizazz_toggle",
	})
	B.sub("ei_sec_performance")
	B.settings({ "spatial_culling", "general_throttle_rate", "off_screen_throttle_rate" })
end

PAGE.healthbars = function(B, S)
	local HB = "healthbar_enable"
	local BAR = "hb_enable_bar"
	B.sub("ei_sec_bar")
	B.setting("healthbar_enable")
	B.setting("hb_enable_bar", HB)
	B.settings({
		"hb_size_width", "hb_size_height", "hb_y_offset", "hb_frame", "hb_padding_scale", "hb_gap_padding_scale",
		"hb_endcaps_enabled", "healthbar_segments_enable",
	}, BAR)

	B.sub("ei_sec_bar_colours")
	B.setting("healthbar_colour_preset", HB)
	local types = S.types()
	for i = 1, #types do
		local t = types[i]
		B.add(ov_colour_row(S, "type", t.id, t.label, "bar_rgb", nil, HB))
	end

	B.sub("ei_sec_ghostbar")
	B.settings({ "hb_toggle_ghostbar", "hb_ghostbar_opacity", "hb_toggle_ghostbar_colour" }, HB)
	B.sub("ei_sec_toughness")
	B.settings({
		"toughness_enabled", "toughness_electric", "toughness_text_enabled", "toughness_text_colour_enabled",
	}, HB)
	local tough = B.setting("toughness_colour_rgb", HB)
	if tough then
		tough.label = LOC("ei_lbl_toughness_colour")
	end
	B.sub("ei_sec_text_lines")
	B.settings({
		"hb_enable_text", "hb_text_top_left_01", "hb_text_bottom_left_01", "hb_text_bottom_left_02",
		"hb_text_show_max_health", "hb_text_show_damage",
	}, HB)
	B.sub("ei_sec_type_icon")
	B.settings({ "healthbar_type_icon_enable", "healthbar_type_icon_scale" }, HB)
	B.sub("ei_sec_when")
	B.settings({ "hb_hide_after_no_damage", "hb_damage_show_only_latest", "hb_damage_show_only_latest_value" }, HB)
	B.sub("ei_sec_hordes")
	B.settings({
		"hb_horde_enable", "hb_horde_clusters_enable", "hb_horde_clusters_size", "hb_horde_hide_after_no_damage",
	}, HB)
	B.sub("ei_sec_boss")
	B.setting("hb_toggle_base_boss_healthbar")
	B.setting("debuff_boss_healthbar_enable", "debuff_enable")
	B.setting("boss_debuff_stack_font_size", "debuff_enable")
end

PAGE.damage = function(B, S)
	local DN = "hb_show_damage_numbers"
	B.sub("ei_sec_numbers")
	B.setting(DN, "healthbar_enable")
	B.settings({
		"hb_damage_number_types", "hb_damage_numbers_add_total", "readable_max_damage_numbers",
		"damage_number_duration", "damage_number_flashy_speed",
	}, DN)
	B.sub("ei_sec_placement")
	B.settings({ "damage_number_scale", "damage_number_y_offset" }, DN)
	B.sub("ei_sec_dn_colours")
	B.settings({
		"damage_number_crit_colour_rgb", "damage_number_weakspot_colour_rgb",
	}, DN)
	B.sub("ei_sec_dn_extras")
	B.settings({ "hb_show_dps", "show_dn_in_range_only" }, DN)
end

local function debuff_toggle_cells(S, requires)
	local cells = {}
	local tip = LOC("ei_debuff_toggle_tip")
	local groups = S.debuff_groups()
	for i = 1, #groups do
		local g = groups[i]
		local group = g.group
		for k = 1, #g.names do
			local name = g.names[k]
			local label = S.debuff_label(name)
			cells[#cells + 1] = {
				kind = "bool",
				label = label,
				tooltip = label .. " (" .. g.label .. ") - " .. tip,
				debuff_name = name,
				requires = requires,
				group_colour = function()
					return S.debuff_group_colour(group)
				end,
				get = function()
					return S.debuff_enabled(name)
				end,
				set = function(v)
					S.set_debuff_enabled(name, v)
				end,
				is_default = function()
					return S.debuff_enabled(name) == true
				end,
				reset = function()
					S.set_debuff_enabled(name, true)
				end,
			}
		end
	end
	return cells
end

local function debuff_colour_cells(S, requires)
	local cells = {}
	local tip = LOC("ei_debuff_colour_tip")
	local groups = S.debuff_groups()
	for i = 1, #groups do
		local g = groups[i]
		local group = g.group
		cells[#cells + 1] = {
			kind = "color",
			label = g.label,
			tooltip = g.label .. " - " .. tip,
			debuff_name = g.names[1],
			requires = requires,
			has_alpha = false,
			group_colour = function()
				return S.debuff_group_colour(group)
			end,
			get = function()
				return S.debuff_group_colour(group)
			end,
			set = function(c)
				S.set_debuff_group_colour(group, c)
			end,
			default_colour = function()
				return S.default_debuff_group_colour(group)
			end,
			is_default = function()
				return colour_equal(S.debuff_group_colour(group), S.default_debuff_group_colour(group))
			end,
			reset = function()
				S.set_debuff_group_colour(group, S.default_debuff_group_colour(group))
			end,
		}
	end
	return cells
end

PAGE.debuffs = function(B, S)
	local DB = "debuff_enable"
	B.sub("ei_sec_debuffs")
	B.setting(DB)
	B.settings({ "debuff_dot_enable", "debuff_utility_enable", "debuff_horde_global_enable", "debuff_stagger_enable" }, DB)
	B.sub("ei_sec_layout")
	B.settings({
		"debuff_horizontal", "split_debuff_types", "debuffs_combine", "debuff_show_on_body", "debuff_x_offset",
		"debuff_y_offset", "debuff_gap_padding_scale", "debuff_gap_name_icon_offset", "debuff_gap_icon_stack_offset",
	}, DB)
	B.sub("ei_sec_icons")
	B.setting("debuff_icons", DB)
	B.setting("debuff_icon_scale", "debuff_icons")
	B.sub("ei_sec_names")
	B.setting("debuff_names", DB)
	B.settings({ "debuffs_abrv", "debuff_names_fade", "debuff_names_font_size" }, "debuff_names")
	B.sub("ei_sec_stacks")
	B.settings({
		"debuff_stacks_show_x", "debuff_stacks_show_x_space", "debuff_stack_on_icon", "debuff_stacks_icon_colour",
		"debuff_stacks_font_size", "debuff_max_stacks_scale", "debuff_max_stacks_colour_toggle",
	}, DB)
	local max_colour = B.setting("debuff_max_stacks_colour_rgb", "debuff_max_stacks_colour_toggle")
	if max_colour then
		max_colour.label = LOC("ei_lbl_max_stacks_colour")
	end
	B.grid("ei_sec_debuff_toggles", "toggles", debuff_toggle_cells(S, DB))
	B.grid("ei_sec_debuff_colours", "colours", debuff_colour_cells(S, DB))
end

PAGE.markers = function(B, S)
	local MK = "markers_enable"
	B.sub("ei_sec_markers")
	B.setting(MK)
	B.settings({ "markers_horde_enable", "markers_non_horde_enable", "marker_display_option" }, MK)
	B.sub("ei_sec_marker_look")
	B.settings({
		"marker_size", "marker_y_offset", "marker_visual_style", "overhead_marker_uses_healthbar_colour",
		"marker_bg_colour_rgb",
	}, MK)
end

PAGE.outlines = function(B, S)
	local OL = "outlines_enable"
	B.sub("ei_sec_outlines")
	B.setting(OL)
	local types = S.types()
	for i = 1, #types do
		local t = types[i]
		local id = t.id
		B.add(ov_tri_row(S, "type", id, "outline_on", t.label, OL))

		local colour = B.add(ov_colour_row(S, "type", id, t.label, "outline_rgb", nil, OL))

		if colour then
			colour.req_get = function()
				return S.ov_get("type", id, "outline_on") == true
			end
		end
	end
	B.sub("ei_sec_tag_colours")
	B.settings({
		"outline_tagged_colour_rgb", "outline_tagged_passive_colour_rgb", "outline_companion_colour_rgb",
		"outline_veteran_tagged_colour_rgb",
	}, OL)
	B.sub("ei_sec_specials")
	B.settings({
		"outline_specials_enable", "healthbar_specials_enable", "marker_specials_enable", "specials_flash",
		"special_attack_pulse_speed", "outline_specials_colour_rgb",
	})
	B.sub("ei_sec_stagger")
	B.settings({
		"outline_stagger_enable", "outline_stagger_horde_enable", "stagger_flash", "stagger_pulse_speed",
		"outline_stagger_colour_rgb",
	}, OL)
end

PAGE.enemies = function(B, S)
	local types = S.types()
	for i = 1, #types do
		local t = types[i]
		local label = LOC("ei_type_short_" .. t.id)
		if label == nil or label == "" or label:find("^<") then
			label = t.label
		end
		B.subs[i] = { label = label, type = t.id, rows = {} }
	end
end

Pages.subpages = function(page_id)
	local S = mod.settings_api
	local B = new_builder(S)
	local build = PAGE[page_id]
	if build then
		build(B, S)
	end
	return B.subs
end

-- ---------------------------------------------------------------------------
-- Enemies page
-- ---------------------------------------------------------------------------

local KIND_OF = { bool = "bool", num = "num", int = "int", rgb = "color", tri = "tri" }

local function master_of(field_key)
	if field_key:find("^outline") or field_key:find("^odist") then
		return "outlines_enable"
	elseif field_key:find("^bar") or field_key:find("^icon") then
		return "healthbar_enable"
	elseif field_key:find("^debuff") then
		return "debuff_enable"
	elseif field_key:find("^marker") then
		return "markers_enable"
	end
	return nil
end

Pages.enemy_rows = function(scope, key, hooks)
	local S = mod.settings_api
	local rows = {}
	local type_id = scope == "type" and key or S.type_of(key)

	if scope == "breed" and type_id then
		local type_label = type_id
		local types = S.types()
		for i = 1, #types do
			if types[i].id == type_id then
				type_label = types[i].label
			end
		end
		rows[#rows + 1] = {
			kind = "note",
			id = "select_type",
			label = LOC("ei_type_note") .. ": " .. type_label,
			tooltip = LOC("ei_scope_breed_note"),
			button = LOC("ei_select_type"),
			action = function()
				hooks.select_node("type", type_id)
			end,
		}
	end

	rows[#rows + 1] = {
		kind = "note",
		id = "reset_node",
		label = LOC(scope == "type" and "ei_overrides_type" or "ei_overrides_breed"),
		tooltip = LOC(scope == "type" and "ei_scope_type_note" or "ei_scope_breed_note"),
		button = LOC(scope == "type" and "ei_reset_type" or "ei_reset_enemy"),
		confirm = LOC("ei_reset_enemy_confirm"),
		action = function()
			hooks.reset_node()
		end,
	}

	local fields = S.ov_fields(scope, key)

	local by_key, merged = {}, {}
	for i = 1, #fields do
		by_key[fields[i].key] = fields[i]
	end
	for i = 1, #fields do
		local f = fields[i]
		local tf = f.toggle and by_key[f.toggle]
		if f.kind == "rgb" and tf and tf.kind == "bool" then
			merged[f.toggle] = true
		end
	end
	for i = 1, #fields do
		local f = fields[i]
		local fk = f.key
		local kind = KIND_OF[f.kind] or "bool"
		if merged[fk] then
			goto continue
		end
		local row = {
			kind = kind,
			id = fk,
			label = f.label_text or fk,
			tooltip = f.tooltip_text,
			requires = not (scope == "breed" and fk == "debuff_on") and master_of(fk) or nil,
			min = f.min,
			max = f.max,
			step = f.step,
			decimals = f.decimals,
			has_alpha = false,
			get = function()
				return S.ov_get(scope, key, fk)
			end,
			set = function(v)
				S.ov_set(scope, key, fk, v)
			end,
			is_default = function()
				return S.ov_is_default(scope, key, fk)
			end,
			reset = function()
				S.ov_set(scope, key, fk, S.ov_default(scope, key, fk))
			end,
		}
		if kind == "color" then
			row.default_colour = function()
				return S.ov_default(scope, key, fk)
			end
			local tf = f.toggle and by_key[f.toggle]
			if tf and tf.kind == "bool" then
				local tk = tf.key
				row.label = tf.label_text or row.label
				row.tooltip = tf.tooltip_text or row.tooltip
				row.toggle_get = function()
					return S.ov_get(scope, key, tk) == true
				end
				row.toggle_set = function(v)
					S.ov_set(scope, key, tk, v)
				end
				row.is_default = function()
					return S.ov_is_default(scope, key, fk) and S.ov_is_default(scope, key, tk)
				end
				row.reset = function()
					S.ov_set(scope, key, fk, S.ov_default(scope, key, fk))
					S.ov_set(scope, key, tk, S.ov_default(scope, key, tk))
				end
			elseif tf then
				row.req_get = function()
					return S.ov_get(scope, key, tf.key) == true
				end
			end
		elseif f.toggle and by_key[f.toggle] then
			local tk = f.toggle
			row.req_get = function()
				return S.ov_get(scope, key, tk) == true
			end
		end
		if kind == "num" or kind == "int" then
			row.min = row.min or 0
			row.max = row.max or 1
			row.step = row.step or 1
			row.decimals = math.max(row.decimals or 0, step_decimals(row.step))
		end
		rows[#rows + 1] = row
		::continue::
	end
	return rows
end

return Pages
