local mod = get_mod("enemy_markers")

local HudHealthBarLogic = require("scripts/ui/hud/elements/hud_health_bar_logic")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}

-- mod settings
template.show_damage_numbers = mod:get("hb_show_damage_numbers") or false
template.show_armor_types = mod:get("hb_show_armour_types") or false
template.hide_after_no_damage = mod:get("hb_hide_after_no_damage") or false
template.horde_enable = mod:get("hb_horde_enable") or false
template.hb_show_enemy_type = mod:get("hb_show_enemy_type") or false
template.hb_text_show_damage = mod:get("hb_text_show_damage") or false

template.frame_type = mod:get("hb_frame") or "content/ui/materials/frames/masteries/panel_main_lower_frame"

local size = {
	mod:get("hb_size_width") or 200,
	mod:get("hb_size_height") or 6,
}

local previous_health = {}
local last_damaged_time = {}

local BREED_COLORS = {
	horde = { 200, 255, 0, 0 },
	elite = { 200, 0, 255, 255 },
	ogryn = { 200, 0, 255, 255 },
	disabler = { 200, 200, 255, 0 },
	monster = { 200, 255, 255, 0 },
}

template.size = size
template.name = "enemy_healthbar"
template.unit_node = "j_neck"
template.position_offset = {
	0,
	0,
	0.8,
}

template.check_line_of_sight = true
template.max_distance = mod:get("draw_distance") or 25
template.screen_clamp = false
template.bar_settings = {
	alpha_fade_delay = 2.6,
	alpha_fade_duration = 0.5,
	alpha_fade_min_value = 50,
	animate_on_health_increase = true,
	bar_spacing = 2,
	duration_health = 1,
	duration_health_ghost = 3,
	health_animation_threshold = 0,
}

template.evolve_distance = 1

template.scale_settings = {
	scale_from = 0.4,
	scale_to = 1,
	distance_max = template.max_distance,
	distance_min = template.evolve_distance,
	easing_function = math.easeCubic,
}

template.fade_settings = {
	default_fade = 1,
	fade_from = 0,
	fade_to = 1,
	distance_max = template.max_distance,
	distance_min = template.max_distance - template.evolve_distance * 2,
	easing_function = math.easeCubic,
}

-- DAMAGE NUMBERS
local damage_number_types = table.enum("readable", "floating", "flashy")
template.show_dps = true
template.skip_damage_from_others = false

local hb_damage_number_type = mod:get("hb_damage_number_types")
if hb_damage_number_type then
	if hb_damage_number_type == "readable" then
		template.damage_number_type = damage_number_types.readable
	elseif hb_damage_number_type == "floating" then
		template.damage_number_type = damage_number_types.floating
	elseif hb_damage_number_type == "flashy" then
		template.damage_number_type = damage_number_types.flashy
	end
else
	template.damage_number_type = damage_number_types.readable
end

template.damage_number_settings = {
	add_numbers_together_timer = 3, -- change to 0.2 to make damage seperate, or super high to make it all combine into one
	add_numbers_together_timer_flashy = 0,
	crit_color = "orange",
	crit_hit_size_scale = 1.5,
	default_color = "white",
	default_font_size = 14,
	dps_font_size = 14.4,
	dps_y_offset = -36,
	duration = 3,
	expand_bonus_scale = 30,
	expand_duration = 0.2,
	fade_delay = 2,
	first_hit_size_scale = 1.2,
	has_taken_damage_timer_remove_after_time = 5,
	has_taken_damage_timer_y_offset = 34,
	hundreds_font_size = 14.4,
	max_float_y = 50,
	shrink_duration = 1,
	visibility_delay = 2,
	weakspot_color = "yellow",
	x_offset = (template.size[1] / 2) - 10,
	x_offset_between_numbers = 38,
	y_offset = -50,
	flashy_font_size_dmg_multiplier = {
		1,
		1.5,
	},
	flashy_font_size_dmg_scale_range = {
		50,
		300,
	},
}

local armor_type_string_lookup = {
	armored = "loc_weapon_stats_display_armored",
	berserker = "loc_weapon_stats_display_berzerker",
	disgustingly_resilient = "loc_weapon_stats_display_disgustingly_resilient",
	resistant = "loc_glossary_armour_type_resistant",
	super_armor = "loc_weapon_stats_display_super_armor",
	unarmored = "loc_weapon_stats_display_unarmored",
}

local function _readable_damage_number_function(
	ui_content,
	ui_renderer,
	ui_style,
	damage_number_settings,
	damage_numbers,
	num_damage_numbers,
	position,
	default_color,
	text_color,
	crit_color,
	weakspot_color,
	default_font_size,
	hundreds_font_size,
	font_type
)
	local z_position = position[3]
	local y_position = position[2] + damage_number_settings.y_offset
	local x_position = position[1] + damage_number_settings.x_offset

	for i = num_damage_numbers, 1, -1 do
		local damage_number = damage_numbers[i]
		local duration = damage_number.duration
		local time = damage_number.time
		local progress = math.clamp(time / duration, 0, 1)

		if progress >= 1 then
			table.remove(damage_numbers, i)
		else
			damage_number.time = damage_number.time + ui_renderer.dt
		end

		if damage_number.was_critical then
			text_color[2] = crit_color[2]
			text_color[3] = crit_color[3]
			text_color[4] = crit_color[4]
			damage_number.expand_duration = damage_number_settings.expand_duration
		elseif damage_number.hit_weakspot then
			text_color[2] = weakspot_color[2]
			text_color[3] = weakspot_color[3]
			text_color[4] = weakspot_color[4]
		else
			text_color[2] = default_color[2]
			text_color[3] = default_color[3]
			text_color[4] = default_color[4]
		end

		local value = damage_number.value
		local font_size = value <= 99 and default_font_size or hundreds_font_size
		local expand_duration = damage_number.expand_duration

		if expand_duration then
			local expand_time = damage_number.expand_time
			local expand_progress = math.clamp(expand_time / expand_duration, 0, 1)
			local anim_progress = 1 - expand_progress

			font_size = font_size + damage_number_settings.expand_bonus_scale * anim_progress

			if expand_progress >= 1 then
				damage_number.expand_duration = nil
				damage_number.shrink_start_t = duration - damage_number_settings.shrink_duration
			else
				damage_number.expand_time = expand_time + ui_renderer.dt
			end
		elseif damage_number.shrink_start_t and time > damage_number.shrink_start_t then
			local diff = time - damage_number.shrink_start_t
			local percentage = diff / damage_number_settings.shrink_duration
			local scale = 1 - percentage

			font_size = font_size * scale
			text_color[1] = text_color[1] * scale
		end

		local text = value
		local size = ui_style.size
		local current_order = num_damage_numbers - i

		if current_order == 0 then
			local scale_size = damage_number.was_critical and damage_number_settings.crit_hit_size_scale
				or damage_number_settings.first_hit_size_scale

			font_size = font_size * scale_size
		end

		position[3] = z_position + current_order
		position[2] = y_position
		position[1] = x_position + current_order * damage_number_settings.x_offset_between_numbers

		UIRenderer.draw_text(ui_renderer, text, font_size, font_type, position, size, text_color, {})
	end

	position[3] = z_position
	position[2] = y_position
	position[1] = x_position
end

local function _floating_damage_number_function(
	ui_content,
	ui_renderer,
	ui_style,
	damage_number_settings,
	damage_numbers,
	num_damage_numbers,
	position,
	default_color,
	text_color,
	crit_color,
	weakspot_color,
	default_font_size,
	hundreds_font_size,
	font_type
)
	local z_position = position[3]
	local y_position = position[2] - damage_number_settings.y_offset * 3
	local x_position = position[1] + damage_number_settings.x_offset

	if ui_content.alpha_multiplier then
		text_color[1] = text_color[1] * ui_content.alpha_multiplier
	end

	for i = num_damage_numbers, 1, -1 do
		local damage_number = damage_numbers[i]
		local duration = damage_number.duration / 2
		local time = damage_number.time
		local progress = math.clamp(time / duration, 0, 1)

		if progress >= 1 then
			table.remove(damage_numbers, i)
		else
			damage_number.time = damage_number.time + ui_renderer.dt
		end

		if damage_number.was_critical then
			text_color[2] = crit_color[2]
			text_color[3] = crit_color[3]
			text_color[4] = crit_color[4]
			damage_number.expand_duration = damage_number_settings.expand_duration
		elseif damage_number.hit_weakspot then
			text_color[2] = weakspot_color[2]
			text_color[3] = weakspot_color[3]
			text_color[4] = weakspot_color[4]
		else
			text_color[2] = default_color[2]
			text_color[3] = default_color[3]
			text_color[4] = default_color[4]
		end

		local value = damage_number.value
		local font_size = value <= 99 and default_font_size or hundreds_font_size
		local expand_duration = damage_number.expand_duration

		if expand_duration then
			local expand_time = damage_number.expand_time
			local expand_progress = math.clamp(expand_time / expand_duration, 0, 1)
			local anim_progress = 1 - expand_progress

			font_size = font_size + damage_number_settings.expand_bonus_scale * anim_progress

			if expand_progress >= 1 then
				damage_number.expand_duration = nil
				damage_number.shrink_start_t = duration - damage_number_settings.shrink_duration
			else
				damage_number.expand_time = expand_time + ui_renderer.dt
			end
		elseif damage_number.shrink_start_t and time > damage_number.shrink_start_t then
			local diff = time - damage_number.shrink_start_t
			local percentage = diff / damage_number_settings.shrink_duration
			local scale = 1 - percentage

			font_size = font_size * scale
			text_color[1] = text_color[1] * scale
		end

		local text = value
		local size = ui_style.size
		local current_order = num_damage_numbers - i

		if current_order == 0 then
			local scale_size = damage_number.was_critical and damage_number_settings.crit_hit_size_scale
				or damage_number_settings.first_hit_size_scale

			font_size = font_size * scale_size
		end

		position[3] = z_position + current_order * 2
		position[2] = y_position - 35 * time
		position[1] = x_position + current_order * damage_number_settings.x_offset_between_numbers

		UIRenderer.draw_text(ui_renderer, text, font_size, font_type, position, size, text_color, {})
	end

	position[3] = z_position
	position[2] = y_position
	position[1] = x_position
end

local function _flashy_damage_number_function(
	ui_content,
	ui_renderer,
	ui_style,
	damage_number_settings,
	damage_numbers,
	num_damage_numbers,
	position,
	default_color,
	text_color,
	crit_color,
	weakspot_color,
	default_font_size,
	hundreds_font_size,
	font_type
)
	local z_position = position[3]
	local y_position = position[2] - damage_number_settings.y_offset * 3
	local x_position = position[1] + damage_number_settings.x_offset

	if ui_content.alpha_multiplier then
		text_color[1] = text_color[1] * ui_content.alpha_multiplier
	end

	local flashy_font_size_dmg_multiplier = damage_number_settings.flashy_font_size_dmg_multiplier
	local flashy_font_size_dmg_scale_range = damage_number_settings.flashy_font_size_dmg_scale_range

	for i = num_damage_numbers, 1, -1 do
		local damage_number = damage_numbers[i]

		if damage_number.hit_world_position then
			local world_to_screen_position =
				Camera.world_to_screen(ui_content.player_camera, damage_number.hit_world_position:unbox())

			y_position = world_to_screen_position[2] - 75
			x_position = world_to_screen_position[1]
		end

		local duration = damage_number.duration / 2
		local time = damage_number.time
		local progress = math.clamp(time / duration, 0, 1)

		if progress >= 1 then
			table.remove(damage_numbers, i)
		else
			damage_number.time = damage_number.time + ui_renderer.dt
		end

		if damage_number.was_critical then
			text_color[2] = crit_color[2]
			text_color[3] = crit_color[3]
			text_color[4] = crit_color[4]
			damage_number.expand_duration = damage_number_settings.expand_duration
		elseif damage_number.hit_weakspot then
			text_color[2] = weakspot_color[2]
			text_color[3] = weakspot_color[3]
			text_color[4] = weakspot_color[4]
		else
			text_color[2] = default_color[2]
			text_color[3] = default_color[3]
			text_color[4] = default_color[4]
		end

		local value = damage_number.value
		local font_size = value <= 99 and default_font_size or hundreds_font_size
		local dmg_scale_multiplier = 1

		if value > flashy_font_size_dmg_scale_range[1] then
			local min = flashy_font_size_dmg_scale_range[1]
			local max = flashy_font_size_dmg_scale_range[2]
			local lerp = math.min((value - min) / (max - min), 1)
			local multiplier = math.lerp(flashy_font_size_dmg_multiplier[1], flashy_font_size_dmg_multiplier[2], lerp)

			font_size = font_size * multiplier
			dmg_scale_multiplier = multiplier
		end

		local expand_duration = damage_number.expand_duration

		if expand_duration then
			local expand_time = damage_number.expand_time
			local expand_progress = math.clamp(expand_time / expand_duration, 0, 1)
			local anim_progress = 1 - expand_progress

			font_size = font_size + damage_number_settings.expand_bonus_scale * anim_progress

			if expand_progress >= 1 then
				damage_number.expand_duration = nil
				damage_number.shrink_start_t = duration - damage_number_settings.shrink_duration
			else
				damage_number.expand_time = expand_time + ui_renderer.dt
			end
		elseif damage_number.shrink_start_t and time > damage_number.shrink_start_t then
			local diff = time - damage_number.shrink_start_t
			local percentage = diff / damage_number_settings.shrink_duration
			local scale = 1 - percentage

			font_size = font_size * scale
			text_color[1] = text_color[1] * scale
		end

		local text = value
		local size = ui_style.size
		local current_order = num_damage_numbers - i

		if current_order == 0 then
			local scale_size = damage_number.was_critical and damage_number_settings.crit_hit_size_scale
				or damage_number_settings.first_hit_size_scale

			font_size = font_size * scale_size
		end

		local random_number = damage_number.random_number
		local float_right = damage_number.float_right
		local float_value = 45 * math.lerp(0.8, 1.2, random_number) * dmg_scale_multiplier
		local float_y_value = float_value * 1.25
		local float_x_value = float_right and float_value or -float_value

		position[2] = y_position - math.ease_out_elastic(time) * float_y_value + time * float_y_value
		position[1] = x_position
			+ math.ease_out_elastic(time) * float_x_value
			+ (float_right and time * float_value or time * -float_value)
			- (not float_right and font_size * 0.5 or 0)

		UIRenderer.draw_text(ui_renderer, text, font_size, font_type, position, size, text_color, {})
	end

	position[3] = z_position
	position[2] = y_position
	position[1] = x_position
end

template.damage_number_function = function(pass, ui_renderer, ui_style, ui_content, position, size)
	local damage_numbers = ui_content.damage_numbers
	local damage_number_settings = template.damage_number_settings
	local scale = RESOLUTION_LOOKUP.scale
	local default_font_size = damage_number_settings.default_font_size * scale
	local dps_font_size = damage_number_settings.dps_font_size * scale
	local hundreds_font_size = damage_number_settings.hundreds_font_size * scale
	local font_type = ui_style.font_type
	local default_color = Color[damage_number_settings.default_color](255, true)
	local crit_color = Color[damage_number_settings.crit_color](255, true)
	local weakspot_color = Color[damage_number_settings.weakspot_color](255, true)
	local text_color = table.clone(default_color)
	local num_damage_numbers = #damage_numbers
	local z_position = position[3]
	local y_position = position[2]
	local x_position = position[1]
	local damage_has_started = ui_content.damage_has_started

	if damage_has_started then
		if not ui_content.damage_has_started_timer then
			ui_content.damage_has_started_timer = ui_renderer.dt
		elseif not ui_content.dead then
			ui_content.damage_has_started_timer = ui_content.damage_has_started_timer + ui_renderer.dt
		end

		if template.show_dps and ui_content.dead then
			if template.damage_number_type == damage_number_types.readable then
				local damage_has_started_position =
					Vector3(x_position, y_position - damage_number_settings.dps_y_offset, z_position)
				local dps = ui_content.damage_has_started_timer > 1
						and ui_content.damage_taken / ui_content.damage_has_started_timer
					or ui_content.damage_taken
				local text = string.format("%d DPS", dps)

				UIRenderer.draw_text(
					ui_renderer,
					text,
					dps_font_size,
					font_type,
					damage_has_started_position,
					size,
					ui_style.text_color,
					{}
				)
			else
				local damage_has_started_position =
					Vector3(x_position, y_position - damage_number_settings.dps_y_offset * 0.6, z_position)
				local dps = ui_content.damage_has_started_timer > 1
						and ui_content.damage_taken / ui_content.damage_has_started_timer
					or ui_content.damage_taken
				local text = string.format("%d DPS", dps)

				UIRenderer.draw_text(
					ui_renderer,
					text,
					dps_font_size,
					font_type,
					damage_has_started_position,
					size,
					ui_style.text_color,
					{}
				)
			end
		end

		if ui_content.last_hit_zone_name then
			local hit_zone_name = ui_content.last_hit_zone_name
			local breed = ui_content.breed
			local armor_type = breed.armor_type

			if breed.hitzone_armor_override and breed.hitzone_armor_override[hit_zone_name] then
				armor_type = breed.hitzone_armor_override[hit_zone_name]
			end

			if template.show_armor_types then
				local armor_type_loc_string = armor_type and armor_type_string_lookup[armor_type] or ""
				local armor_type_text = Localize(armor_type_loc_string)

				if template.damage_number_type == damage_number_types.readable then
					local armor_type_position = Vector3(
						x_position,
						y_position + damage_number_settings.has_taken_damage_timer_y_offset * 1.25,
						z_position
					)

					UIRenderer.draw_text(
						ui_renderer,
						armor_type_text,
						dps_font_size,
						font_type,
						armor_type_position,
						size,
						ui_style.text_color,
						{}
					)
				end
			end
		end
	end

	if template.show_damage_numbers then
		if template.damage_number_type == damage_number_types.readable then
			_readable_damage_number_function(
				ui_content,
				ui_renderer,
				ui_style,
				damage_number_settings,
				damage_numbers,
				num_damage_numbers,
				position,
				default_color,
				text_color,
				crit_color,
				weakspot_color,
				default_font_size,
				hundreds_font_size,
				font_type
			)
		elseif template.damage_number_type == damage_number_types.floating then
			_floating_damage_number_function(
				ui_content,
				ui_renderer,
				ui_style,
				damage_number_settings,
				damage_numbers,
				num_damage_numbers,
				position,
				default_color,
				text_color,
				crit_color,
				weakspot_color,
				default_font_size,
				hundreds_font_size,
				font_type
			)
		elseif template.damage_number_type == damage_number_types.flashy then
			_flashy_damage_number_function(
				ui_content,
				ui_renderer,
				ui_style,
				damage_number_settings,
				damage_numbers,
				num_damage_numbers,
				position,
				default_color,
				text_color,
				crit_color,
				weakspot_color,
				default_font_size,
				hundreds_font_size,
				font_type
			)
		end
	end

	ui_style.font_size = default_font_size
end

template.create_widget_defintion = function(template, scenegraph_id)
	local size = template.size
	local bar_width = size[1]
	local bar_height = size[2]

	local bar_offset = {
		-bar_width * 0.5,
		0,
		0,
	}

	return UIWidget.create_definition({
		-- METAL FRAME (back plate)
		{
			pass_type = "texture",
			style_id = "frame",
			value = "content/ui/materials/frames/masteries/panel_main_lower_frame",
			style = {
				vertical_alignment = "center",
				offset = {
					bar_offset[1] - 6,
					bar_offset[2],
					0,
				},
				size = {
					bar_width + 12,
					bar_height + 6,
				},
				color = {
					200,
					180,
					180,
					180,
				},
			},
		},

		-- BACKGROUND PLATE
		{
			pass_type = "rect",
			style_id = "background",
			style = {
				vertical_alignment = "center",
				offset = bar_offset,
				size = {
					bar_width,
					bar_height,
				},
				color = {
					200,
					20,
					20,
					20,
				},
			},
		},

		-- MAX HEALTH
		{
			pass_type = "rect",
			style_id = "health_max",
			style = {
				vertical_alignment = "center",
				offset = {
					bar_offset[1],
					bar_offset[2],
					1,
				},
				size = {
					bar_width,
					bar_height,
				},
				color = {
					160,
					90,
					90,
					90,
				},
			},
		},

		-- GHOST DAMAGE
		{
			pass_type = "rect",
			style_id = "ghost_bar",
			style = {
				vertical_alignment = "center",
				offset = {
					bar_offset[1],
					bar_offset[2],
					2,
				},
				size = {
					bar_width,
					bar_height,
				},
				color = {
					180,
					120,
					40,
					40,
				},
			},
		},

		-- TOUGHNESS OVERLAY
		{
			pass_type = "rect",
			style_id = "toughness_bar",
			style = {
				vertical_alignment = "center",
				offset = {
					bar_offset[1],
					bar_offset[2],
					3.5, -- above health
				},
				size = {
					bar_width,
					bar_height,
				},
				color = {
					200,
					90,
					160,
					220, -- Darktide toughness blue
				},
			},
		},
		-- CURRENT HEALTH (main bar)
		{
			pass_type = "rect",
			style_id = "bar",
			style = {
				vertical_alignment = "center",
				offset = {
					bar_offset[1],
					bar_offset[2],
					3,
				},
				size = {
					bar_width,
					bar_height,
				},
				color = {
					255,
					170,
					30,
					30,
				},
			},
		},
		-- SHADOW
		{
			pass_type = "texture",
			style_id = "shading1",
			value = "content/ui/materials/frames/inner_shadow_medium",
			value_id = "shading1",
			style = {
				vertical_alignment = "center",
				offset = {
					bar_offset[1],
					bar_offset[2],
					5,
				},
				size = {
					bar_width,
					bar_height,
				},
				color = {
					255,
					80,
					80,
					80,
				},
			},
		},
		-- TOP EDGE HIGHLIGHT
		{
			pass_type = "texture",
			style_id = "highlight1",
			value = "content/ui/materials/frames/frame_glow_01",
			value_id = "highlight1",
			style = {
				vertical_alignment = "center",
				offset = {
					bar_offset[1],
					bar_offset[2],
					6,
				},
				size = {
					bar_width,
					bar_height,
				},
				color = {
					200,
					255,
					255,
					255,
				},
			},
		},
		-- subtle background glowing segments
		{
			pass_type = "texture",
			style_id = "background_glow_segments",
			value = "content/ui/materials/effects/terminal_header_glow",
			value_id = "background_glow_segments",
			style = {
				scale_to_material = true,
				vertical_alignment = "center",
				offset = {
					bar_offset[1],
					bar_offset[2],
					0,
				},
				size = {
					bar_width,
					bar_height,
				},
				color = {
					0,
					255,
					255,
					255,
				},
			},
		},

		-- ELITE ICON
		{
			pass_type = "texture",
			style_id = "icon_elite",
			value = "content/ui/materials/icons/difficulty/flat/difficulty_skull_heresy",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				offset = { -bar_width * 0.5 - 16, 0, 6 },
				size = { 32, 32 },
				color = { 0, 255, 255, 255 }, -- hidden by default
			},
		},

		-- BOSS ICON
		{
			pass_type = "texture",
			style_id = "icon_boss",
			value = "content/ui/materials/icons/difficulty/flat/difficulty_skull_auric",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				offset = { -bar_width * 0.5 - 16, 0, 6 },
				size = { 32, 32 },
				color = { 0, 255, 100, 255 },
			},
		},

		-- SHIELD ICON
		{
			pass_type = "texture",
			style_id = "icon_shield",
			value = "content/ui/materials/icons/traits/trait_shield",
			style = {
				vertical_alignment = "center",
				horizontal_alignment = "center",
				offset = { -bar_width * 0.5 - 16, 0, 6 },
				size = { 32, 32 },
				color = { 0, 200, 200, 255 },
			},
		},

		-- header text
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
				offset = {
					-bar_width * 0.5,
					-bar_height - 8,
					6,
				},
				font_type = "proxima_nova_bold",
				font_size = 16,
				default_font_size = 16,
				text_color = { 220, 220, 220, 220 },
				default_text_color = { 220, 220, 220, 220 },
				size = { (bar_width / 2) - 2, 20 },
			},
		},

		-- Health text
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
				offset = {
					-bar_width * 0.5,
					bar_height + 8,
					6,
				},
				font_type = "proxima_nova_bold",
				font_size = 18,
				default_font_size = 14,
				text_color = { 220, 220, 220, 220 },
				default_text_color = { 220, 220, 220, 220 },
				size = { bar_width, 20 },
				drop_shadow = true,
			},
		},

		-- damage numbers
		{
			pass_type = "logic",
			value = template.damage_number_function,
			style = {
				horizontal_alignment = "right",
				vertical_alignment = "center",
				text_horizontal_alignment = "right",
				text_vertical_alignment = "top",
				offset = {
					bar_width * 0.5,
					-bar_height - 20,
					1,
				},
				font_type = "proxima_nova_bold",
				font_size = 18,
				default_font_size = 14,
				text_color = { 220, 220, 220, 220 },
				default_text_color = { 220, 220, 220, 220 },
				size = { bar_width, 20 },
				drop_shadow = true,
			},
		},
	}, scenegraph_id)
end

template.on_enter = function(widget, marker, template)
	local content = widget.content

	content.damage_taken = 0
	content.damage_numbers = {}

	content.spawn_progress_timer = 0

	local unit = marker.unit
	local unit_data_extension = ScriptUnit.extension(unit, "unit_data_system")
	local breed = unit_data_extension:breed()

	if template.hb_show_enemy_type then
		content.header_text = breed.name
	end

	content.breed = breed
	content.unit_data_extension = unit_data_extension

	local bar_settings = template.bar_settings

	marker.bar_logic = HudHealthBarLogic:new(bar_settings)
end

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	local content = widget.content
	local style = widget.style
	local unit = marker.unit
	local health_extension = ScriptUnit.has_extension(unit, "health_system")
	local health_percent = health_extension and health_extension:current_health_percent() or 0
	local health_current = health_extension and health_extension:current_health() or 0
	local health_max = health_extension and health_extension:max_health() or 0

	local bar_logic = marker.bar_logic

	bar_logic:update(dt, t, health_percent)

	local health_fraction, health_ghost_fraction, health_max_fraction = bar_logic:animated_health_fractions()

	-- Track damage
	local damage_taken = 0
	if previous_health[unit] then
		damage_taken = previous_health[unit] - health_current
	end
	previous_health[unit] = health_current

	-- DAMAGE NUMBERS LOGIC
	local is_dead = not health_extension or not health_extension:is_alive()
	local health_percent = is_dead and 0 or health_extension:current_health_percent()
	local max_health = Managers.state.difficulty:get_minion_max_health(content.breed.name)
	local damage_taken
	local player_camera = parent._parent and parent._parent:player_camera()

	content.player_camera = player_camera

	if not is_dead then
		damage_taken = health_extension:total_damage_taken()
	else
		damage_taken = max_health
	end

	if health_extension then
		local last_damaging_unit = health_extension:last_damaging_unit()

		if last_damaging_unit then
			content.last_hit_zone_name = health_extension:last_hit_zone_name() or "center_mass"
			content.last_damaging_unit = last_damaging_unit

			local breed = content.breed
			local hit_zone_weakspot_types = breed.hit_zone_weakspot_types

			if hit_zone_weakspot_types and hit_zone_weakspot_types[content.last_hit_zone_name] then
				content.hit_weakspot = true
			else
				content.hit_weakspot = false
			end

			content.was_critical = health_extension:was_hit_by_critical_hit_this_render_frame()

			local last_hit_world_position = health_extension:last_hit_world_position()

			if last_hit_world_position then
				if not content.last_hit_world_position then
					content.last_hit_world_position = Vector3Box(last_hit_world_position)
				else
					content.last_hit_world_position:store(last_hit_world_position)
				end
			end
		end
	end

	local old_damage_taken = content.damage_taken
	local damage_number_settings = template.damage_number_settings
	local show_damage_number = (
		not template.skip_damage_from_others
		or not content.last_damaging_unit
		or content.last_damaging_unit
			== (Managers.player:local_player(1) and Managers.player:local_player(1).player_unit)
	)

	local damage_numbers = content.damage_numbers
	local latest_damage_number = damage_numbers[#damage_numbers]

	if damage_taken and damage_taken ~= old_damage_taken then
		content.visibility_delay = damage_number_settings.visibility_delay
		content.damage_taken = damage_taken

		if show_damage_number and old_damage_taken < damage_taken then
			local damage_diff = math.ceil(damage_taken - old_damage_taken)
			local should_add = true
			local was_critical = health_extension and health_extension:was_hit_by_critical_hit_this_render_frame()

			if latest_damage_number then
				local add_numbers_together_timer = template.damage_number_type == damage_number_types.flashy
						and damage_number_settings.add_numbers_together_timer_flashy
					or damage_number_settings.add_numbers_together_timer

				if add_numbers_together_timer > t - latest_damage_number.start_time then
					should_add = false
				end
			end

			if content.add_on_next_number or was_critical or should_add then
				local damage_number = {
					expand_time = 0,
					time = 0,
					start_time = t,
					duration = damage_number_settings.duration,
					value = damage_diff,
					expand_duration = damage_number_settings.expand_duration,
					random_number = math.random(),
					float_right = math.random() > 0.5,
				}
				local breed = content.breed
				local hit_zone_weakspot_types = breed.hit_zone_weakspot_types

				if hit_zone_weakspot_types and hit_zone_weakspot_types[content.last_hit_zone_name] then
					damage_number.hit_weakspot = true
				else
					damage_number.hit_weakspot = false
				end

				damage_number.was_critical = was_critical
				damage_numbers[#damage_numbers + 1] = damage_number

				if content.add_on_next_number then
					content.add_on_next_number = nil
				end

				if was_critical then
					content.add_on_next_number = true
				end

				if content.last_hit_world_position then
					damage_number.hit_world_position = Vector3Box(content.last_hit_world_position:unbox())
				end
			else
				latest_damage_number.value = math.clamp(latest_damage_number.value + damage_diff, 0, max_health)
				latest_damage_number.time = 0
				latest_damage_number.y_position = nil
				latest_damage_number.start_time = t

				local breed = content.breed
				local hit_zone_weakspot_types = breed.hit_zone_weakspot_types

				if hit_zone_weakspot_types and hit_zone_weakspot_types[content.last_hit_zone_name] then
					latest_damage_number.hit_weakspot = true
				else
					latest_damage_number.hit_weakspot = false
				end

				latest_damage_number.was_critical = was_critical
			end
		end

		if not content.damage_has_started then
			content.damage_has_started = true
		end

		content.last_damage_taken_time = t
	end

	-- Health counter
	if template.hb_text_show_damage and (t - (content.last_damage_taken_time or 0)) > 3 then
		content.health_counter = string.format("%d / %d", health_current, health_max)
	elseif template.hb_text_show_damage and latest_damage_number then
		content.health_counter = string.format("%d / %d ({#color(255, 255, 50)}-%d)", health_current, health_max, latest_damage_number.value)
	else
		content.health_counter = string.format("%d / %d", health_current, health_max)
	end

	-- Update health bar and ghost mode
	-- Update health fraction and damage counter
	if health_fraction then
		-- Set the health bar size and color
		local bar_width = template.size[1]
		style.bar.size[1] = bar_width * health_fraction
	end

	if health_fraction and health_ghost_fraction then
		local bar_settings = template.bar_settings
		local spacing = bar_settings.bar_spacing
		local bar_width = template.size[1]
		local default_width_offset = -bar_width * 0.5
		local health_width = bar_width * health_fraction

		style.bar.size[1] = health_width

		local ghost_bar_width = math.max(bar_width * health_ghost_fraction - health_width, 0)
		local ghost_bar_style = style.ghost_bar

		ghost_bar_style.offset[1] = default_width_offset + health_width
		ghost_bar_style.size[1] = ghost_bar_width

		local background_width = math.max(bar_width - ghost_bar_width - health_width, 0)

		background_width = math.max(background_width - spacing, 0)

		local background_style = style.background

		background_style.offset[1] = default_width_offset + bar_width - background_width
		background_style.size[1] = background_width

		local health_max_style = style.health_max
		local health_max_width = bar_width - math.max(bar_width * health_max_fraction, 0)

		health_max_width = math.max(health_max_width - spacing, 0)
		health_max_style.offset[1] = default_width_offset + (bar_width - health_max_width * 0.5)
		health_max_style.size[1] = health_max_width
		marker.health_fraction = health_fraction

		-- Calculate toughness
		local toughness_extension = ScriptUnit.has_extension(unit, "toughness_system")
		local toughness_fraction = toughness_extension and toughness_extension:current_toughness_percent() or 0

		-- TOUGHNESS BAR
		local toughness_style = style.toughness_bar

		if toughness_fraction > 0 then
			local toughness_width = bar_width * toughness_fraction
			toughness_style.size[1] = toughness_width
			toughness_style.offset[1] = default_width_offset
		else
			toughness_style.size[1] = 0
		end

		-- 25% health EXECUTE mode
		if health_fraction <= 0.25 then
			style.bar.color = { 255, 255, 255, 50 }
		end
	end

	-- set frame background
	content.frame = template.frame_type

	-- Detect breed
	local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = unit_data_extension and unit_data_extension:breed()

	local breed_type = "enemy"

	if breed then
		local tags = breed.tags

		-- set breed types, with ranking list, lower tags will take priority and be more specific.
		if tags.horde then
			breed_type = "horde"
		end
		if tags.roamer then
			breed_type = "horde"
		end
		if tags.elite then
			breed_type = "elite"
		end
		if tags.special then
			breed_type = "special"
		end
		if tags.monster then
			breed_type = "monster"
		end
		if tags.captain then
			breed_type = "captain"
		end
		if tags.disabler then
			breed_type = "disabler"
		end
		if tags.witch then
			breed_type = "witch"
		end
		if template.hb_show_enemy_type then
			content.header_text = tostring(breed_type)
		end
	end

	-- Reset icon visibility
	style.icon_elite.color[1] = 0
	style.icon_boss.color[1] = 0
	style.icon_shield.color[1] = 0

	-- ELITE / SPECIAL
	if breed_type == "elite" or breed_type == "ogryn" then
		style.icon_elite.color[1] = 0
	end

	-- MONSTER / BOSS
	if breed_type == "monster" then
		style.icon_boss.color[1] = 0
		style.frame.color = { 200, 200, 60, 200 }
	end

	local bar_color = BREED_COLORS[breed_type] or BREED_COLORS.horde
	style.bar.color = bar_color

	style.ghost_bar.color = {
		bar_color[1],
		bar_color[2] * 0.5,
		bar_color[3] * 0.5,
		bar_color[4] * 0.5,
	}

	local icon_offset_y = 0

	if style.icon_shield.color[1] > 0 then
		style.icon_shield.offset[2] = icon_offset_y
		icon_offset_y = icon_offset_y + 16
	end

	if style.icon_elite.color[1] > 0 then
		style.icon_elite.offset[2] = icon_offset_y
	end

	-- Hide health bar if no damage for the last 5 seconds
	local time_since_last_damage = t - (content.last_damage_taken_time or 0)

	-- hide
	local is_inside_frustum = content.is_inside_frustum
	local distance = content.distance
	local line_of_sight_progress = content.line_of_sight_progress or 0

	if marker.raycast_initialized then
		local raycast_result = marker.raycast_result
		local line_of_sight_speed = 3

		if raycast_result then
			line_of_sight_progress = math.max(line_of_sight_progress - dt * line_of_sight_speed, 0)
		else
			line_of_sight_progress = math.min(line_of_sight_progress + dt * line_of_sight_speed, 1)
		end
	end

	if not HEALTH_ALIVE[unit] and (not marker.health_fraction or marker.health_fraction == 0) then
		marker.remove = true
	end

	-- logic to hide if disabled in options:
	if breed_type == "horde" then
		if not template.horde_enable then
			marker.draw = false
		end
	end

	-- only show if damage has been applied, has a timer until hidden again
	if template.hide_after_no_damage then
		if time_since_last_damage > 5 then
			marker.draw = false -- Hide the health bar if no damage in the last 5 seconds
		end
	end

	local draw = marker.draw

	if draw then
		local scale = marker.scale

		-- header text is optional
		local header_style = style.header_text
		if header_style then
			header_style.font_size = header_style.default_font_size * scale
		end

		content.line_of_sight_progress = line_of_sight_progress
		widget.alpha_multiplier = line_of_sight_progress
	end
end

return template
