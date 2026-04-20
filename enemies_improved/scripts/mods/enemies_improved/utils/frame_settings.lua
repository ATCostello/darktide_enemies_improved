local mod = get_mod("enemies_improved")
mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/enemies_improved_localization")

mod.text_scale = mod:get("text_scale") or 1
mod.font_type = mod:get("font_type")
mod.frame_settings = {}

mod.build_frame_settings = function(dt)
	local fs = mod.frame_settings

	fs.dt = dt or 0

	fs.mod_enabled = mod:get("mod_enabled")

	-- Draw distance
	fs.draw_distance = mod:get("draw_distance")

	-- GENERAL
	fs.outlines_enable = mod:get("outlines_enable")
	fs.text_scale = mod:get("text_scale")
	fs.font_type = mod:get("font_type")
	fs.check_line_of_sight = true
	fs.enable_depth_fading = mod:get("enable_depth_fading")

	local r = mod:get("main_font_colour_R")
	local g = mod:get("main_font_colour_G")
	local b = mod:get("main_font_colour_B")

	if not r or not g or not b then
		r = 220
		g = 220
		b = 220
	end

	fs.main_colour = {
		255,
		r,
		g,
		b,
	}

	local rs = mod:get("secondary_font_colour_R")
	local gs = mod:get("secondary_font_colour_G")
	local bs = mod:get("secondary_font_colour_B")

	if not rs or not gs or not bs then
		rs = 150
		gs = 150
		bs = 150
	end

	fs.secondary_colour = {
		255,
		rs,
		gs,
		bs,
	}

	fs.global_opacity = mod:get("global_opacity") or 1

	-- MARKERS
	fs.markers_enable = mod:get("markers_enable")
	fs.markers_horde_enable = mod:get("markers_horde_enable")
	fs.marker_size = mod:get("marker_size")
	fs.markers_health_enable = mod:get("markers_health_enable")
	fs.marker_y_offset = mod:get("marker_y_offset")
	local a = mod:get("marker_bg_colour_A")
	local r = mod:get("marker_bg_colour_R")
	local g = mod:get("marker_bg_colour_G")
	local b = mod:get("marker_bg_colour_B")

	if not r or not g or not b then
		r = 220
		g = 220
		b = 220
	end

	fs.marker_bg_colour = {
		a,
		r,
		g,
		b,
	}

	-- HEALTHBARS
	fs.healthbar_enable = mod:get("healthbar_enable")
	fs.healthbar_type_icon_enable = mod:get("healthbar_type_icon_enable")
	fs.show_damage_numbers = mod:get("hb_show_damage_numbers")
	fs.show_armor_types = mod:get("hb_show_armour_types")
	fs.hide_after_no_damage = mod:get("hb_hide_after_no_damage")
	fs.horde_hide_after_no_damage = mod:get("hb_horde_hide_after_no_damage")
	fs.horde_enable = mod:get("hb_horde_enable")
	fs.horde_clusters_enable = mod:get("hb_horde_clusters_enable")
	fs.hb_toggle_ghostbar = mod:get("hb_toggle_ghostbar")
	fs.healthbar_segments_enable = mod:get("healthbar_segments_enable")
	fs.hb_text_show_max_health = mod:get("hb_text_show_max_health")
	fs.hb_text_top_left_01 = mod:get("hb_text_top_left_01")
	fs.hb_text_bottom_left_01 = mod:get("hb_text_bottom_left_01")
	fs.hb_text_bottom_left_02 = mod:get("hb_text_bottom_left_02")
	fs.hb_gap_padding_scale = mod:get("hb_gap_padding_scale")

	fs.hb_text_show_damage = mod:get("hb_text_show_damage")
	fs.frame_type = mod:get("hb_frame")
	fs.hb_padding_scale = mod:get("hb_padding_scale")
	fs.hb_size_width = mod:get("hb_size_width")
	fs.hb_size_height = mod:get("hb_size_height")
	fs.hb_y_offset = mod:get("hb_y_offset")
	fs.hb_damage_number_type = mod:get("hb_damage_number_types")
	fs.hb_damage_numbers_track_friendly = mod:get("hb_damage_numbers_track_friendly")
	fs.hb_damage_numbers_add_total = mod:get("hb_damage_numbers_add_total")
	fs.hb_damage_show_only_latest = mod:get("hb_damage_show_only_latest")
	fs.hb_damage_show_only_latest_value = mod:get("hb_damage_show_only_latest_value")

	-- SPECIAL ATTACKS
	fs.marker_specials_enable = mod:get("marker_specials_enable")
	fs.healthbar_specials_enable = mod:get("healthbar_specials_enable")
	fs.outline_specials_enable = mod:get("outline_specials_enable")
	fs.specials_flash = mod:get("specials_flash")
	fs.special_attack_pulse_speed = mod:get("special_attack_pulse_speed")

	-- DEBUFFS
	fs.debuff_enable = mod:get("debuff_enable")
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
