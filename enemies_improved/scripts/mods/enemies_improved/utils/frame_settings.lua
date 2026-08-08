local mod = get_mod("enemies_improved")
mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/enemies_improved_localization")

local function table_clear(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

local function ensure_array(t, i1, i2, i3, i4)
	if not t then
		return { i1, i2, i3, i4 }
	end
	t[1], t[2], t[3], t[4] = i1, i2, i3, i4
	return t
end

local function ensure_array_indexed(t, i2, i3, i4)
	if not t then
		return { [2] = i2, [3] = i3, [4] = i4 }
	end
	t[2], t[3], t[4] = i2, i3, i4
	return t
end

mod.font_type = mod:get("font_type")
mod.frame_settings = {}

mod.build_frame_settings = function(dt)
	local fs = mod.frame_settings

	fs.dt = dt or 0

	fs.mod_enabled = mod:get("mod_enabled")
	fs.global_scale = mod:get("global_scale") or 1

	-- Draw distance
	fs.draw_distance = mod:get("draw_distance")

	-- broadphase range: must encompass all individual distance overrides
	-- Also build per-breed cache tables to avoid mod:get() + string concat in hot paths
	fs.draw_distance_broadphase = fs.draw_distance

	-- Initialize sub-tables on first call, clear on subsequent calls
	if not fs._initialized then
		fs._initialized = true
		fs.breed_dist_enabled = {}
		fs.breed_dist_value = {}
		fs.breed_outline_dist_enabled = {}
		fs.breed_outline_dist_value = {}
		fs.breed_marker_toggle = {}
		fs.breed_outline_enabled = {}
		fs.breed_healthbar_enabled = {}
		fs.breed_healthbar_force = {}
		fs.breed_healthbar_always_show = {}
		fs.breed_type_outline_enabled = {}
		fs.breed_type_healthbar_enabled = {}
		fs.breed_type_healthbar_always_show = {}
		fs.breed_type_healthbar_y_offset = {}
		fs.breed_type_healthbar_y_offset_enabled = {}
		fs.breed_debuff_toggle = {}
		fs.breed_type_debuff_enabled = {}
		fs.breed_healthbar_y_offset = {}
		fs.breed_healthbar_y_offset_enabled = {}
		fs.breed_type_debuff_show_on_body_override = {}
		fs.breed_debuff_show_on_body_override = {}
		fs.breed_marker_type_enabled = {}
	else
		table_clear(fs.breed_dist_enabled)
		table_clear(fs.breed_dist_value)
		table_clear(fs.breed_outline_dist_enabled)
		table_clear(fs.breed_outline_dist_value)
		table_clear(fs.breed_marker_toggle)
		table_clear(fs.breed_outline_enabled)
		table_clear(fs.breed_healthbar_enabled)
		table_clear(fs.breed_healthbar_force)
		table_clear(fs.breed_healthbar_always_show)
		table_clear(fs.breed_type_outline_enabled)
		table_clear(fs.breed_type_healthbar_enabled)
		table_clear(fs.breed_type_healthbar_always_show)
		table_clear(fs.breed_type_healthbar_y_offset)
		table_clear(fs.breed_type_healthbar_y_offset_enabled)
		table_clear(fs.breed_debuff_toggle)
		table_clear(fs.breed_type_debuff_enabled)
		table_clear(fs.breed_healthbar_y_offset)
		table_clear(fs.breed_healthbar_y_offset_enabled)
		table_clear(fs.breed_type_debuff_show_on_body_override)
		table_clear(fs.breed_debuff_show_on_body_override)
		table_clear(fs.breed_marker_type_enabled)
	end

	-- INDIVIDUAL OVERRIDES
	for _, options in next, mod.breed_names do
		local enemy = options.value
		if enemy then
			local dist_enabled = mod:get("distance_" .. enemy .. "_enable")
			fs.breed_dist_enabled[enemy] = dist_enabled
			if dist_enabled then
				local ind_dist = mod:get("distance_" .. enemy .. "_value")
				fs.breed_dist_value[enemy] = ind_dist
				if ind_dist and ind_dist > fs.draw_distance_broadphase then
					fs.draw_distance_broadphase = ind_dist
				end
			end

			local outline_enabled = mod:get("outline_distance_" .. enemy .. "_enable")
			fs.breed_outline_dist_enabled[enemy] = outline_enabled
			if outline_enabled then
				local outline_dist = mod:get("outline_distance_" .. enemy .. "_value")
				fs.breed_outline_dist_value[enemy] = outline_dist
				if outline_dist and outline_dist > fs.draw_distance_broadphase then
					fs.draw_distance_broadphase = outline_dist
				end
			end

			fs.breed_marker_toggle[enemy] = mod:get("markers_" .. enemy .. "_toggle")
			fs.breed_debuff_toggle[enemy] = mod:get("debuff_" .. enemy .. "_enable")
			fs.breed_outline_enabled[enemy] = mod:get("outline_" .. enemy .. "_enable")
			fs.breed_healthbar_enabled[enemy] = mod:get("healthbar_" .. enemy .. "_enable")
			fs.breed_healthbar_force[enemy] = mod:get("healthbar_" .. enemy .. "_force")
			fs.breed_healthbar_always_show[enemy] = mod:get("healthbar_" .. enemy .. "_always_show")

			fs.breed_healthbar_y_offset_enabled[enemy] = mod:get("healthbar_" .. enemy .. "_y_offset_enabled")
			fs.breed_healthbar_y_offset[enemy] = mod:get("healthbar_" .. enemy .. "_y_offset")
					and -mod:get("healthbar_" .. enemy .. "_y_offset")
				or nil

			fs.breed_debuff_show_on_body_override[enemy] = mod:get("debuff_" .. enemy .. "_show_on_body_override")
		end
	end

	-- GROUP OVERRIDES
	for _, options in next, mod.breed_types do
		local breed = options.value
		if breed and breed ~= "select" then
			fs.breed_type_outline_enabled[breed] = mod:get("outline_" .. breed .. "_enable")
			fs.breed_type_debuff_enabled[breed] = mod:get("debuff_" .. breed .. "_enable")
			fs.breed_type_healthbar_enabled[breed] = mod:get("healthbar_" .. breed .. "_enable")
			fs.breed_type_healthbar_always_show[breed] = mod:get("healthbar_" .. breed .. "_always_show")
			fs.breed_type_healthbar_y_offset_enabled[breed] = mod:get("healthbar_" .. breed .. "_y_offset_enabled")
			fs.breed_type_healthbar_y_offset[breed] = mod:get("healthbar_" .. breed .. "_y_offset")
					and -mod:get("healthbar_" .. breed .. "_y_offset")
				or nil
			fs.breed_marker_type_enabled[breed] = mod:get("marker_" .. breed .. "_enable")
			fs.breed_type_debuff_show_on_body_override[breed] = mod:get("debuff_" .. breed .. "_show_on_body_override")
		end
	end

	fs.general_throttle_rate = mod:get("general_throttle_rate") / 1000
	fs.off_screen_throttle_rate = mod:get("off_screen_throttle_rate") / 1000

	-- GENERAL
	fs.outlines_enable = mod:get("outlines_enable")
	fs.text_scale = mod:get("text_scale") * fs.global_scale
	fs.font_type = mod:get("font_type")
	fs.check_line_of_sight = true
	fs.enable_depth_fading = mod:get("enable_depth_fading")
	fs.spatial_culling = mod:get("spatial_culling")

	local r = mod:get("main_font_colour_R")
	local g = mod:get("main_font_colour_G")
	local b = mod:get("main_font_colour_B")

	if not r or not g or not b then
		r = 220
		g = 220
		b = 220
	end

	fs.main_colour = ensure_array(fs.main_colour, 255, r, g, b)

	local rs = mod:get("secondary_font_colour_R")
	local gs = mod:get("secondary_font_colour_G")
	local bs = mod:get("secondary_font_colour_B")

	if not rs or not gs or not bs then
		rs = 150
		gs = 150
		bs = 150
	end

	fs.secondary_colour = ensure_array(fs.secondary_colour, 255, rs, gs, bs)

	fs.global_opacity = mod:get("global_opacity") or 1
	fs.only_in_meatgrinder = mod:get("only_in_meatgrinder")
	fs.always_show_in_meatgrinder = mod:get("always_show_in_meatgrinder")
	-- MARKERS
	fs.markers_enable = mod:get("markers_enable")
	fs.markers_horde_enable = mod:get("markers_horde_enable")
	fs.markers_non_horde_enable = mod:get("markers_non_horde_enable")
	fs.marker_size = mod:get("marker_size") * fs.global_scale
	fs.marker_y_offset = mod:get("marker_y_offset") * fs.global_scale
	fs.overhead_marker_uses_healthbar_colour = mod:get("overhead_marker_uses_healthbar_colour")

	local marker_visual_style = mod:get("marker_visual_style")
	if not marker_visual_style then
		if mod:get("markers_health_enable") then
			marker_visual_style = "simple_health"
		elseif mod:get("marker_type_icon_enable") then
			marker_visual_style = "type_icon"
		else
			marker_visual_style = "diamond"
		end
	end
	fs.marker_visual_style = marker_visual_style
	local a = mod:get("marker_bg_colour_A")
	local r = mod:get("marker_bg_colour_R")
	local g = mod:get("marker_bg_colour_G")
	local b = mod:get("marker_bg_colour_B")

	if not r or not g or not b then
		r = 220
		g = 220
		b = 220
	end

	fs.marker_bg_colour = ensure_array(fs.marker_bg_colour, a, r, g, b)

	fs.marker_display_option = mod:get("marker_display_option")
	fs.markers_show_only_aimed = mod:get("markers_show_only_aimed")
	fs.aim_cone_angle = mod:get("aim_cone_angle") or 8
	fs.only_tagged_enemies = mod:get("only_tagged_enemies")

	-- HEALTHBARS
	fs.healthbar_enable = mod:get("healthbar_enable")
	fs.hb_enable_bar = mod:get("hb_enable_bar")
	if fs.hb_enable_bar == nil then
		fs.hb_enable_bar = true
	end
	fs.hb_enable_text = mod:get("hb_enable_text")
	if fs.hb_enable_text == nil then
		fs.hb_enable_text = true
	end
	fs.healthbar_type_icon_enable = mod:get("healthbar_type_icon_enable")
	fs.show_damage_numbers = mod:get("hb_show_damage_numbers")
	fs.show_armor_types = mod:get("hb_show_armour_types")
	fs.hide_after_no_damage = mod:get("hb_hide_after_no_damage")
	fs.hb_show_when_debuffed = mod:get("hb_show_when_debuffed")
	fs.horde_hide_after_no_damage = mod:get("hb_horde_hide_after_no_damage")
	fs.horde_enable = mod:get("hb_horde_enable")
	fs.horde_clusters_enable = mod:get("hb_horde_clusters_enable")
	fs.hb_horde_clusters_size = mod:get("hb_horde_clusters_size")
	fs.hb_toggle_ghostbar = mod:get("hb_toggle_ghostbar")
	fs.healthbar_segments_enable = mod:get("healthbar_segments_enable")
	fs.hb_text_show_max_health = mod:get("hb_text_show_max_health")
	fs.hb_text_top_left_01 = mod:get("hb_text_top_left_01")
	fs.hb_text_bottom_left_01 = mod:get("hb_text_bottom_left_01")
	fs.hb_text_bottom_left_02 = mod:get("hb_text_bottom_left_02")
	fs.hb_gap_padding_scale = mod:get("hb_gap_padding_scale") * fs.global_scale
	fs.healthbar_type_icon_scale = (mod:get("healthbar_type_icon_scale") or 1) * fs.global_scale
	fs.hb_text_show_damage = mod:get("hb_text_show_damage")
	fs.frame_type = mod:get("hb_frame")
	fs.hb_padding_scale = mod:get("hb_padding_scale")
	fs.hb_size_width = mod:get("hb_size_width") * fs.global_scale
	fs.hb_size_height = mod:get("hb_size_height") * fs.global_scale
	fs.hb_y_offset = -mod:get("hb_y_offset")
	fs.hb_damage_number_type = mod:get("hb_damage_number_types")
	fs.hb_damage_numbers_track_friendly = mod:get("hb_damage_numbers_track_friendly")
	fs.hb_damage_numbers_add_total = mod:get("hb_damage_numbers_add_total")
	fs.hb_damage_show_only_latest = mod:get("hb_damage_show_only_latest")
	fs.hb_damage_show_only_latest_value = mod:get("hb_damage_show_only_latest_value")
	fs.damage_number_duration = mod:get("damage_number_duration")
	fs.hb_ghostbar_opacity = mod:get("hb_ghostbar_opacity")
	fs.hb_toggle_ghostbar_colour = mod:get("hb_toggle_ghostbar_colour")
	fs.readable_max_damage_numbers = mod:get("readable_max_damage_numbers")
	fs.hb_show_dps = mod:get("hb_show_dps")
	fs.damage_number_scale = mod:get("damage_number_scale")
	fs.damage_number_y_offset = mod:get("damage_number_y_offset")
	fs.show_dn_in_range_only = mod:get("show_dn_in_range_only")
	fs.damage_number_flashy_speed = mod:get("damage_number_flashy_speed")

	local r_crit = mod:get("damage_number_crit_colour_R")
	local g_crit = mod:get("damage_number_crit_colour_G")
	local b_crit = mod:get("damage_number_crit_colour_B")

	if not r_crit or not g_crit or not b_crit then
		r_crit = 247
		g_crit = 158
		b_crit = 13
	end

	fs.damage_number_crit_colour = ensure_array(fs.damage_number_crit_colour, 255, r_crit, g_crit, b_crit)

	local r_ws = mod:get("damage_number_weakspot_colour_R")
	local g_ws = mod:get("damage_number_weakspot_colour_G")
	local b_ws = mod:get("damage_number_weakspot_colour_B")

	if not r_ws or not g_ws or not b_ws then
		r_ws = 255
		g_ws = 245
		b_ws = 107
	end

	fs.damage_number_weakspot_colour = ensure_array(fs.damage_number_weakspot_colour, 255, r_ws, g_ws, b_ws)

	fs.hb_toggle_base_boss_healthbar = mod:get("hb_toggle_base_boss_healthbar")
	fs.healthbar_only_in_meatgrinder = mod:get("healthbar_only_in_meatgrinder")
	fs.hb_endcaps_enabled = mod:get("hb_endcaps_enabled")
	fs.healthbar_colour_preset = mod:get("healthbar_colour_preset")

	-- TOUGHNESS
	fs.toughness_enabled = mod:get("toughness_enabled")
	fs.toughness_text_enabled = mod:get("toughness_text_enabled")
	fs.toughness_text_colour_enabled = mod:get("toughness_text_colour_enabled")
	fs.toughness_electric = mod:get("toughness_electric")

	local r = mod:get("toughness_colour_R")
	local g = mod:get("toughness_colour_G")
	local b = mod:get("toughness_colour_B")

	if not r or not g or not b then
		r = 220
		g = 220
		b = 220
	end

	fs.toughness_colour = ensure_array(fs.toughness_colour, 255, r, g, b)

	-- SPECIAL ATTACKS
	fs.marker_specials_enable = mod:get("marker_specials_enable")
	fs.healthbar_specials_enable = mod:get("healthbar_specials_enable")
	fs.outline_specials_enable = mod:get("outline_specials_enable")
	fs.specials_flash = mod:get("specials_flash")
	fs.special_attack_pulse_speed = mod:get("special_attack_pulse_speed")

	local spec_r = mod:get("outline_specials_colour_R")
	local spec_g = mod:get("outline_specials_colour_G")
	local spec_b = mod:get("outline_specials_colour_B")
	fs.outline_specials_colour = ensure_array_indexed(fs.outline_specials_colour, spec_r or 255, spec_g or 0, spec_b or 0)

	-- STAGGER SETTINGS
	fs.debuff_stagger_enable = mod:get("debuff_stagger_enable")
	fs.outline_stagger_enable = mod:get("outline_stagger_enable")
	fs.outline_stagger_horde_enable = mod:get("outline_stagger_horde_enable")
	fs.stagger_flash = mod:get("stagger_flash")
	fs.stagger_pulse_speed = mod:get("stagger_pulse_speed")
	local r = mod:get("outline_stagger_colour_R")
	local g = mod:get("outline_stagger_colour_G")
	local b = mod:get("outline_stagger_colour_B")

	if not r or not g or not b then
		r = 220
		g = 220
		b = 220
	end

	fs.outline_stagger_colour = ensure_array(fs.outline_stagger_colour, 255, r, g, b)

	-- DEBUFFS
	fs.debuff_enable = mod:get("debuff_enable")
	fs.debuff_keyword_enable = mod:get("debuff_keyword_enable")
	fs.debuff_dot_enable = mod:get("debuff_dot_enable")
	fs.debuff_utility_enable = mod:get("debuff_utility_enable")
	fs.debuff_names = mod:get("debuff_names")
	fs.debuff_names_fade = mod:get("debuff_names_fade")
	fs.debuff_horde_enable = mod:get("debuff_horde_enable")
	fs.debuff_show_on_body = mod:get("debuff_show_on_body")
	fs.debuffs_abrv = mod:get("debuffs_abrv")
	fs.debuffs_combine = mod:get("debuffs_combine")
	fs.split_debuff_types = mod:get("split_debuff_types")
	fs.debuff_icons = mod:get("debuff_icons")
	fs.debuff_max_stacks_scale = mod:get("debuff_max_stacks_scale")
	fs.debuff_stacks_icon_colour = mod:get("debuff_stacks_icon_colour")
	fs.debuff_max_stacks_colour_toggle = mod:get("debuff_max_stacks_colour_toggle")
	fs.debuff_gap_padding_scale = mod:get("debuff_gap_padding_scale")
	fs.debuff_y_offset = mod:get("debuff_y_offset")
	fs.debuff_x_offset = mod:get("debuff_x_offset")
	fs.debuff_gap_name_icon_offset = mod:get("debuff_gap_name_icon_offset")
	fs.debuff_gap_icon_stack_offset = mod:get("debuff_gap_icon_stack_offset")
	fs.debuff_stacks_show_x = mod:get("debuff_stacks_show_x")
	fs.debuff_stacks_show_x_space = mod:get("debuff_stacks_show_x_space")
	fs.debuff_icon_scale = mod:get("debuff_icon_scale")
	fs.debuff_stack_on_icon = mod:get("debuff_stack_on_icon")
	fs.debuff_boss_healthbar_enable = mod:get("debuff_boss_healthbar_enable")
	fs.debuff_horizontal = mod:get("debuff_horizontal")
	fs.debuff_stacks_font_size = mod:get("debuff_stacks_font_size") or 16
	fs.debuff_names_font_size = mod:get("debuff_names_font_size") or 16
	fs.boss_debuff_stack_font_size = mod:get("boss_debuff_stack_font_size") or 14
	fs.boss_debuff_icon_size = mod:get("boss_debuff_icon_size") or 1

	local r = mod:get("debuff_max_stacks_colour_R")
	local g = mod:get("debuff_max_stacks_colour_G")
	local b = mod:get("debuff_max_stacks_colour_B")

	if not r or not g or not b then
		r = 220
		g = 220
		b = 220
	end

	fs.debuff_max_stacks_colour = {
		255,
		r,
		g,
		b,
	}
end

mod.build_frame_settings()
