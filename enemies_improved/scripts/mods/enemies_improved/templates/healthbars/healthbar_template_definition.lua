local mod = get_mod("enemies_improved")

local UIWidget = require("scripts/managers/ui/ui_widget")

local fs = mod.frame_settings

local _create_definition = function(template, scenegraph_id)
	local size = { fs.hb_size_width, fs.hb_size_height }
	local bar_width = size[1]
	local bar_height = size[2]

	local bar_offset = { -bar_width * 0.5, 0, 0 }

	local icon_style = {
		vertical_alignment = "center",
		horizontal_alignment = "center",
		offset = { -bar_width * 0.5 - 8, 0, 10 },
		default_offset = { -bar_width * 0.5 - 8, 0, 10 },
		size = { 24, 24 },
		default_size = { 24, 24 },
		color = { 200, 255, 200, 0 },
		default_alpha = 255,
	}

	return UIWidget.create_definition({
		-- METAL FRAME (back plate)
		{
			pass_type = "texture",
			style_id = "frame",
			value = fs.frame_type,
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = { bar_offset[1] - 6, bar_offset[2], 0 },
				default_offset = { bar_offset[1] - 6, bar_offset[2], 0 },
				size = {
					bar_width + (10 * fs.hb_padding_scale),
					bar_height + (6 * fs.hb_padding_scale),
				},
				default_size = {
					bar_width + (10 * fs.hb_padding_scale),
					bar_height + (6 * fs.hb_padding_scale),
				},
				color = { 185, 180, 180, 180 },
				default_alpha = 185,
			},
			visibility_function = function(content)
				if content.hb_built then
					return true
				else
					return false
				end
			end,
		}, -- MAX HEALTH
		{
			pass_type = "rect",
			style_id = "health_max",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = { bar_offset[1], bar_offset[2], 1 },
				default_offset = { bar_offset[1], bar_offset[2], 1 },
				size = { bar_width, bar_height },
				default_size = { bar_width, bar_height },
				color = { 200, 0, 0, 0 },
				default_alpha = 200,
			},
			visibility_function = function(content)
				if content.hb_built then
					return true
				else
					return false
				end
			end,
		}, -- GHOST DAMAGE
		{
			pass_type = "rect",
			style_id = "ghost_bar",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = { bar_offset[1], bar_offset[2], 2 },
				default_offset = { bar_offset[1], bar_offset[2], 2 },
				size = { bar_width, bar_height },
				default_size = { bar_width, bar_height },
				color = { 255, 120, 40, 40 },
				default_alpha = 255,
			},

			change_function = function(content, style)
				local health_fraction = content.health_fraction or 0
				local health_ghost_fraction = content.health_ghost_fraction or 0

				local scaled_bar_width = content.scaled_bar_width or 0
				local scaled_health_width = scaled_bar_width * health_fraction
				local scaled_ghost_width = scaled_bar_width * health_ghost_fraction

				style.size[1] = scaled_ghost_width
				style.offset[1] = -scaled_bar_width * 0.5
			end,

			visibility_function = function(content)
				if
					content.hb_built
					and fs.hb_toggle_ghostbar
					and content.health_fraction
					and content.health_ghost_fraction
					and content.health_ghost_fraction > content.health_fraction
				then
					return true
				else
					return false
				end
			end,
		}, -- CURRENT HEALTH (main bar)
		{
			pass_type = "rect",
			style_id = "current_health",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = { bar_offset[1], bar_offset[2], 3 },
				default_offset = { bar_offset[1], bar_offset[2], 3 },
				size = { bar_width, bar_height },
				default_size = { bar_width, bar_height },
				color = { 255, 170, 30, 30 },
				default_alpha = 255,
			},
			change_function = function(content, style)
				local health_fraction = content.health_fraction or 0

				local scaled_bar_width = content.scaled_bar_width or 0
				local scaled_health_width = scaled_bar_width * health_fraction

				style.size[1] = scaled_health_width
				style.offset[1] = -scaled_bar_width * 0.5
			end,

			visibility_function = function(content)
				if content.hb_built then
					return true
				else
					return false
				end
			end,
		}, -- CURRENT TOUGHNESS
		{
			pass_type = "rect",
			style_id = "current_toughness",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = { bar_offset[1], bar_offset[2], 3 },
				default_offset = { bar_offset[1], bar_offset[2], 3 },
				size = { bar_width, bar_height },
				default_size = { bar_width, bar_height },
				color = { 255, 50, 150, 255 },
				default_alpha = 255,
			},
			change_function = function(content, style)
				local toughness_fraction = content.toughness_fraction or 0

				local scaled_bar_width = content.scaled_bar_width or 0
				local scaled_toughness_width = scaled_bar_width * toughness_fraction

				style.size[1] = scaled_toughness_width
				style.offset[1] = -scaled_bar_width * 0.5
			end,

			visibility_function = function(content)
				if
					content.hb_built
					and fs.toughness_enabled
					and (content.current_toughness and content.current_toughness > 0)
				then
					return true
				else
					return false
				end
			end,
		},
		-- SEGMENT BAR 25%
		{
			pass_type = "rect",
			style_id = "health_segment_25",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = { bar_offset[1] + (bar_width * 0.25) - 5, bar_offset[2], 3 },
				default_offset = { bar_offset[1] + (bar_width * 0.25) - 5, bar_offset[2], 3 },
				size = { 5, bar_height },
				default_size = { 5, bar_height },
				color = { 200, 0, 0, 0 },
				default_alpha = 200,
			},
			visibility_function = function(content)
				if content.hb_built and fs.healthbar_segments_enable then
					return true
				else
					return false
				end
			end,
		},

		-- SEGMENT BAR 50%
		{
			pass_type = "rect",
			style_id = "health_segment_50",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = { bar_offset[1] + (bar_width * 0.50) - 2.5, bar_offset[2], 3 },
				default_offset = { bar_offset[1] + (bar_width * 0.50) - 2.5, bar_offset[2], 3 },
				size = { 5, bar_height },
				default_size = { 5, bar_height },
				color = { 200, 0, 0, 0 },
				default_alpha = 200,
			},
			visibility_function = function(content)
				if content.hb_built and fs.healthbar_segments_enable then
					return true
				else
					return false
				end
			end,
		},
		-- SEGMENT BAR 75%
		{
			pass_type = "rect",
			style_id = "health_segment_75",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = { bar_offset[1] + (bar_width * 0.75) - 2.5, bar_offset[2], 3 },
				default_offset = { bar_offset[1] + (bar_width * 0.75) - 2.5, bar_offset[2], 3 },
				size = { 5, bar_height },
				default_size = { 5, bar_height },
				color = { 200, 0, 0, 0 },
				default_alpha = 200,
			},
			visibility_function = function(content)
				if content.hb_built and fs.healthbar_segments_enable then
					return true
				else
					return false
				end
			end,
		},

		-- SHADOW
		{
			pass_type = "texture",
			style_id = "shading1",
			value = "content/ui/materials/frames/inner_shadow_medium",
			value_id = "shading1",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = { bar_offset[1], bar_offset[2], 4 },
				default_offset = { bar_offset[1], bar_offset[2], 4 },
				size = { bar_width, bar_height },
				default_size = { bar_width, bar_height },
				color = { 200, 80, 80, 80 },
				default_alpha = 200,
			},
			visibility_function = function(content)
				if content.hb_built then
					return true
				else
					return false
				end
			end,
		}, -- TOP EDGE HIGHLIGHT
		{
			pass_type = "texture",
			style_id = "highlight1",
			value = "content/ui/materials/scrollbars/scrollbar_metal_highlight",
			value_id = "highlight1",
			style = {
				vertical_alignment = "center",
				offset = { bar_offset[1], bar_offset[2], 5 },
				default_offset = { bar_offset[1], bar_offset[2], 5 },
				size = { bar_width, bar_height },
				default_size = { bar_width, bar_height },
				color = { 100, 255, 255, 255 },
				default_alpha = 100,
			},
			visibility_function = function(content)
				if content.hb_built then
					return true
				else
					return false
				end
			end,
		},
		-- ICON BACKGROUND
		{
			pass_type = "texture",
			style_id = "icon_background",
			value = "content/ui/materials/frames/talents/talent_icon_container",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				offset = { -bar_width * 0.5 - 8, 0, 8 },
				default_offset = { -bar_width * 0.5 - 8, 0, 8 },

				size = { 35, 35 },
				default_size = { 35, 35 },

				color = { 255, 15, 15, 15 },
				default_alpha = 255,

				material_values = {
					frame = "content/ui/textures/frames/horde/hex_frame_horde",
					icon_mask = "content/ui/textures/frames/horde/hex_frame_horde_mask",
					intensity = 0,
					saturation = 0.65,
				},
			},
			visibility_function = function(content)
				return content.hb_built and content.icon_enabled
			end,
		},
		{ -- icon glow
			pass_type = "texture",
			style_id = "icon_background1",
			value = "content/ui/materials/base/ui_default_base",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				offset = { -bar_width * 0.5 - 8, 0, 7 },
				default_offset = { -bar_width * 0.5 - 8, 0, 7 },

				size = { 40, 40 },
				default_size = { 40, 40 },

				color = { 255, 255, 180, 80 },
				default_alpha = 255,
				blend_mode = "add",
				scale_to_material = true,

				material_values = {
					texture_map = "content/ui/textures/frames/horde/hex_frame_horde_glow",
				},
			},
			visibility_function = function(content)
				return content.hb_built and content.icon_enabled and content.glow_enabled
			end,
		},
		-- ELITE ICON
		{
			pass_type = "texture",
			style_id = "icon_elite",
			value = "content/ui/materials/hud/interactions/icons/enemy_priority",
			style = icon_style,
			visibility_function = function(content)
				return content.hb_built and content.icon_enabled and content.icon_elite
			end,
		}, -- BOSS ICON
		{
			pass_type = "texture",
			style_id = "icon_boss",
			value = "content/ui/materials/icons/difficulty/flat/difficulty_skull_damnation",
			style = icon_style,
			visibility_function = function(content)
				return content.hb_built and content.icon_enabled and content.icon_boss
			end,
		},
		{ -- DAEMONHOST ICON
			pass_type = "texture",
			style_id = "icon_witch",
			value = "content/ui/materials/hud/icons/speaker",
			style = icon_style,
			visibility_function = function(content)
				return content.hb_built and content.icon_enabled and content.icon_witch
			end,
		},
		{ -- CAPTAIN ICON
			pass_type = "texture",
			style_id = "icon_captain",
			value = "content/ui/materials/icons/difficulty/flat/difficulty_skull_auric",
			style = icon_style,
			visibility_function = function(content)
				return content.hb_built and content.icon_enabled and content.icon_captain
			end,
		},
		{ -- Ranged elites
			pass_type = "texture",
			style_id = "icon_elite_ranged",
			value = "content/ui/materials/icons/circumstances/assault_01",
			style = icon_style,
			visibility_function = function(content)
				return content.hb_built and content.icon_enabled and content.icon_elite_ranged
			end,
		},
		{ -- specialists
			pass_type = "texture",
			style_id = "icon_special",
			value = "content/ui/materials/icons/difficulty/flat/difficulty_skull_uprising",
			style = icon_style,
			visibility_function = function(content)
				return content.hb_built and content.icon_enabled and content.icon_special
			end,
		},
		{ -- disablers
			pass_type = "texture",
			style_id = "icon_disabler",
			value = "content/ui/materials/icons/generic/exclamation_mark",
			style = icon_style,
			visibility_function = function(content)
				return content.hb_built and content.icon_enabled and content.icon_disabler
			end,
		},
		{ -- snipers
			pass_type = "texture",
			style_id = "icon_sniper",
			value = "content/ui/materials/icons/weapons/actions/ads",
			style = icon_style,
			visibility_function = function(content)
				return content.hb_built and content.icon_enabled and content.icon_sniper
			end,
		}, -- header text
		{
			pass_type = "text",
			style_id = "header_text",
			value = "",
			value_id = "header_text",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "top",
				offset = { -bar_width * 0.5, -bar_height - 8 * fs.text_scale * fs.hb_gap_padding_scale, 6 },
				default_offset = { -bar_width * 0.5, -bar_height - 8 * fs.text_scale * fs.hb_gap_padding_scale, 6 },
				font_type = mod.font_type,
				font_size = 16,
				default_font_size = 16,
				text_color = fs.main_colour or { 220, 220, 220, 220 },
				default_text_color = fs.main_colour or { 220, 220, 220, 220 },
				size = { bar_width * 4 - 2 * fs.text_scale, 20 },
				default_size = { bar_width * 4 - 2 * fs.text_scale, 20 },
				default_alpha = 255,
				drop_shadow = true,
			},
			visibility_function = function(content)
				if content.hb_built then
					return true
				else
					return false
				end
			end,
		}, -- Health text
		{
			pass_type = "text",
			style_id = "health_counter",
			value = "",
			value_id = "health_counter",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "bottom",
				offset = { -bar_width * 0.5, ((bar_height + 16) * fs.text_scale) * fs.hb_gap_padding_scale, 6 },
				default_offset = { -bar_width * 0.5, ((bar_height + 16) * fs.text_scale) * fs.hb_gap_padding_scale, 6 },
				font_type = mod.font_type,
				font_size = 16,
				default_font_size = 16,
				text_color = fs.main_colour or { 220, 220, 220, 220 },
				default_text_color = fs.main_colour or { 220, 220, 220, 220 },
				size = { bar_width * 4 * fs.text_scale, 20 },
				default_size = { bar_width * 4 * fs.text_scale, 20 },

				drop_shadow = true,
				default_alpha = 255,
			},
			visibility_function = function(content)
				if content.hb_built then
					return true
				else
					return false
				end
			end,
		},
		{ -- armour types
			pass_type = "text",
			style_id = "armour_type",
			value = "",
			value_id = "armour_type",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "bottom",
				offset = { -bar_width * 0.5, ((bar_height + 34) * fs.text_scale) * fs.hb_gap_padding_scale, 6 },
				default_offset = { -bar_width * 0.5, ((bar_height + 34) * fs.text_scale) * fs.hb_gap_padding_scale, 6 },
				font_type = mod.font_type,
				font_size = 16,
				default_font_size = 16,
				text_color = fs.secondary_colour or { 220, 220, 220, 220 },
				default_text_color = fs.secondary_colour or { 220, 220, 220, 220 },
				size = { bar_width * 4 * fs.text_scale, 20 },
				default_size = { bar_width * 4 * fs.text_scale, 20 },

				drop_shadow = true,
				default_alpha = 255,
			},
			visibility_function = function(content)
				if content.hb_built then
					return true
				else
					return false
				end
			end,
		},
		-- readable damage numbers
		{
			pass_type = "logic",
			style_id = "readable_damage_numbers",
			value = template.readable_damage_number_function,
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "bottom",
				offset = { -bar_width * 0.5, bar_height + 50 * fs.text_scale * fs.hb_gap_padding_scale, 6 },
				default_offset = { -bar_width * 0.5, bar_height + 50 * fs.text_scale * fs.hb_gap_padding_scale, 6 },
				font_type = mod.font_type,
				font_size = 16,
				default_font_size = 16,
				text_color = fs.secondary_colour or { 220, 220, 220, 220 },
				default_text_color = fs.secondary_colour or { 220, 220, 220, 220 },
				size = { bar_width * 4 * fs.text_scale, 20 },
				default_size = { bar_width * 4 * fs.text_scale, 20 },

				drop_shadow = true,
				default_alpha = 255,
			},
			change_function = function(content, style)
				if content.scale then
					if fs.hb_text_bottom_left_02 == "nothing" and fs.hb_text_bottom_left_01 == "nothing" then
						style.offset[2] = (size[2] + 12) * fs.hb_gap_padding_scale * content.scale
					elseif fs.hb_text_bottom_left_02 == "nothing" and fs.hb_text_bottom_left_01 ~= "nothing" then
						style.offset[2] = (size[2] + 34) * fs.hb_gap_padding_scale * content.scale
					else
						style.offset[2] = (size[2] + 50) * fs.hb_gap_padding_scale * content.scale
					end
				end
			end,
			visibility_function = function(content)
				if
					content.dn_built
					and (fs.show_dn_in_range_only and content.is_in_shooting_range or not fs.show_dn_in_range_only)
				then
					return true
				else
					return false
				end
			end,
		},
		-- damage numbers
		{
			pass_type = "logic",
			style_id = "damage_numbers",
			value = template.damage_number_function,
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "bottom",
				offset = {
					-size[1] * 0.5,
					-size[2],
					2,
				},
				font_type = mod.font_type,
				font_size = 30,
				text_color = { 220, 220, 220, 220 },
				default_text_color = { 220, 220, 220, 220 },
				size = { 600, size[2] },
				default_alpha = 255,
			},
			visibility_function = function(content)
				if
					content.dn_built
					and (fs.show_dn_in_range_only and content.is_in_shooting_range or not fs.show_dn_in_range_only)
				then
					return true
				else
					return false
				end
			end,
		},
	}, scenegraph_id)
end

return {
	create_definition = _create_definition,
}
