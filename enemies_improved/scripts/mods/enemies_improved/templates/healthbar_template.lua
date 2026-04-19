local mod = get_mod("enemies_improved")

local HudHealthBarLogic = require("scripts/ui/hud/elements/hud_health_bar_logic")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local BreedQueries = require("scripts/utilities/breed_queries")
local minion_breeds = BreedQueries.minion_breeds_by_name()

local template = {}
local fs = mod.frame_settings

local size = { fs.hb_size_width, fs.hb_size_height }

local min_size = { 0, 0 }
mod.scale = 1

template.size = size

template.min_size = min_size
template.name = "enemy_healthbar"
template.unit_node = "root_point"
template.position_offset = { 0, 0, fs.hb_y_offset }

template.check_line_of_sight = fs.check_line_of_sight
template.max_distance = fs.draw_distance
template.screen_clamp = false

template.bar_settings = {
	alpha_fade_delay = 1,
	alpha_fade_duration = 0.6,
	alpha_fade_min_value = 50,
	animate_on_health_increase = true,
	bar_spacing = 0,
	duration_health = 0.1,
	duration_health_ghost = 1.5,
	health_animation_threshold = 0.1,
}

template.evolve_distance = 1

template.scale_settings = {
	scale_from = 0.4,
	scale_to = 1,
	distance_max = 25,
	distance_min = 5,
}

template.fade_settings = {
	default_fade = 1,
	fade_from = 0,
	fade_to = 1,
	distance_max = template.max_distance,
	distance_min = template.max_distance - template.evolve_distance * 2,
	easing_function = math.easeCubic,
}

-----------------------------------------------------------------------
-- Cached locals / helpers
-----------------------------------------------------------------------

local ScriptUnit_extension = ScriptUnit.extension
local ScriptUnit_has_extension = ScriptUnit.has_extension
local Managers_state = Managers.state
local Managers_player = Managers.player
local Color_color = Color
local Vector3 = Vector3
local Vector3Box = Vector3Box

local math_clamp = math.clamp
local math_lerp = math.lerp
local math_min = math.min
local math_max = math.max
local math_random = math.random
local math_sqrt = math.sqrt
local math_floor = math.floor

local string_format = string.format
local table_remove = table.remove
local table_clone = table.clone
local next = next

-----------------------------------------------------------------------
-- Cached damage number colors
-----------------------------------------------------------------------

local CACHED_DAMAGE_COLORS = {}

local function _init_damage_colors()
	if next(CACHED_DAMAGE_COLORS) then
		return
	end

	local settings = template.damage_number_settings

	CACHED_DAMAGE_COLORS.default = Color_color[settings.default_color](255, true)
	CACHED_DAMAGE_COLORS.crit = Color_color[settings.crit_color](255, true)
	CACHED_DAMAGE_COLORS.weakspot = Color_color[settings.weakspot_color](255, true)
end

-----------------------------------------------------------------------
-- Damage numbers config
-----------------------------------------------------------------------

local damage_number_types = table.enum("readable", "floating", "flashy")
template.show_dps = true
template.skip_damage_from_others = true

local hb_damage_number_type = fs.hb_damage_number_type

template.damage_number_settings = {
	add_numbers_together_timer = 1,
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
	max_float_y = 20,
	shrink_duration = 0.5,
	visibility_delay = 2,
	weakspot_color = "yellow",
	x_offset = (size[1] / 2) + 10,
	x_offset_between_numbers = 40 * mod.text_scale,
	y_offset = -30,
	flashy_font_size_dmg_multiplier = { 1, 1.5 },
	flashy_font_size_dmg_scale_range = { 50, 300 },
}

local previous_health = {}
local last_damaged_time = {}
local peak_cluster_max_by_rep = {}

local armor_type_string_lookup = {
	armored = "loc_weapon_stats_display_armored",
	berserker = "loc_weapon_stats_display_berzerker",
	disgustingly_resilient = "loc_weapon_stats_display_disgustingly_resilient",
	resistant = "loc_glossary_armour_type_resistant",
	super_armor = "loc_weapon_stats_display_super_armor",
	unarmored = "loc_weapon_stats_display_unarmored",
}

mod.latest_damaged_enemies = {}

-----------------------------------------------------------------------
-- Damage number render helpers
-----------------------------------------------------------------------

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
	local base_y = position[2]
	local base_x = position[1]
	local dt = ui_renderer.dt

	for i = num_damage_numbers, 1, -1 do
		local damage_number = damage_numbers[i]
		local duration = damage_number.duration
		local time = damage_number.time
		local progress = math_clamp(time / duration, 0, 1)

		if progress >= 1 then
			table_remove(damage_numbers, i)
		else
			damage_number.time = time + dt
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
		local font_size = (value <= 99 and default_font_size) or hundreds_font_size
		local expand_duration = damage_number.expand_duration

		if expand_duration then
			local expand_time = damage_number.expand_time
			local expand_progress = math_clamp(expand_time / expand_duration, 0, 1)
			local anim_progress = 1 - expand_progress

			font_size = font_size + damage_number_settings.expand_bonus_scale * anim_progress

			if expand_progress >= 1 then
				damage_number.expand_duration = nil
				damage_number.shrink_start_t = duration - damage_number_settings.shrink_duration
			else
				damage_number.expand_time = expand_time + dt
			end
		elseif damage_number.shrink_start_t and time > damage_number.shrink_start_t then
			local diff = time - damage_number.shrink_start_t
			local percentage = diff / damage_number_settings.shrink_duration
			local scale = 1 - percentage

			font_size = font_size * scale
			--text_color[1] = text_color[1] * scale
		end

		local text = value
		local size = ui_style.size
		local current_order = num_damage_numbers - i

		if current_order == 0 then
			local scale_size = damage_number.was_critical and damage_number_settings.crit_hit_size_scale
				or damage_number_settings.first_hit_size_scale

			font_size = font_size * scale_size
		end

		local draw_pos = Vector3(
			base_x + current_order * damage_number_settings.x_offset_between_numbers,
			base_y,
			z_position + current_order
		)

		UIRenderer.draw_text(ui_renderer, text, font_size, font_type, draw_pos, size, text_color, {})
	end

	position[3] = z_position
	position[2] = base_y
	position[1] = base_x
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
	local base_y = position[2] - damage_number_settings.y_offset * 3
	local base_x = position[1] + damage_number_settings.x_offset
	local dt = ui_renderer.dt

	if ui_content.alpha_multiplier then
		--text_color[1] = text_color[1] * ui_content.alpha_multiplier
	end

	for i = num_damage_numbers, 1, -1 do
		local damage_number = damage_numbers[i]
		local duration = damage_number.duration / 2
		local time = damage_number.time
		local progress = math_clamp(time / duration, 0, 1)

		if damage_number.hit_world_position then
			local world_to_screen_position =
				Camera.world_to_screen(ui_content.player_camera, damage_number.hit_world_position:unbox())

			base_y = world_to_screen_position[2] + 60
			base_x = world_to_screen_position[1] + 190
		end

		if progress >= 1 then
			table_remove(damage_numbers, i)
		else
			damage_number.time = time + dt
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
		local font_size = (value <= 99 and default_font_size) or hundreds_font_size
		local expand_duration = damage_number.expand_duration

		if expand_duration then
			local expand_time = damage_number.expand_time
			local expand_progress = math_clamp(expand_time / expand_duration, 0, 1)
			local anim_progress = 1 - expand_progress

			font_size = font_size + damage_number_settings.expand_bonus_scale * anim_progress

			if expand_progress >= 1 then
				damage_number.expand_duration = nil
				damage_number.shrink_start_t = duration - damage_number_settings.shrink_duration
			else
				damage_number.expand_time = expand_time + dt
			end
		elseif damage_number.shrink_start_t and time > damage_number.shrink_start_t then
			local diff = time - damage_number.shrink_start_t
			local percentage = diff / damage_number_settings.shrink_duration
			local scale = 1 - percentage

			font_size = font_size * scale
			--text_color[1] = text_color[1] * scale
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
		position[2] = base_y - 35 * time
		position[1] = base_x + current_order * damage_number_settings.x_offset_between_numbers

		UIRenderer.draw_text(ui_renderer, text, font_size, font_type, position, size, text_color, {})
	end

	position[3] = z_position
	position[2] = base_y
	position[1] = base_x
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
	local base_y = position[2] - damage_number_settings.y_offset * 3
	local base_x = position[1]
	local dt = ui_renderer.dt

	if ui_content.alpha_multiplier then
		--text_color[1] = text_color[1] * ui_content.alpha_multiplier
	end

	local flashy_font_size_dmg_multiplier = damage_number_settings.flashy_font_size_dmg_multiplier
	local flashy_font_size_dmg_scale_range = damage_number_settings.flashy_font_size_dmg_scale_range

	for i = num_damage_numbers, 1, -1 do
		local damage_number = damage_numbers[i]
		local y_position = base_y
		local x_position = base_x

		if damage_number.hit_world_position then
			local world_to_screen_position =
				Camera.world_to_screen(ui_content.player_camera, damage_number.hit_world_position:unbox())

			y_position = world_to_screen_position[2] - 75
			x_position = world_to_screen_position[1]
		end

		y_position = y_position + 100
		x_position = x_position + 200

		local duration = damage_number.duration / 2
		local time = damage_number.time
		local progress = math_clamp(time / duration, 0, 1)

		if progress >= 1 then
			table_remove(damage_numbers, i)
		else
			damage_number.time = time + dt
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
		local font_size = (value <= 99 and default_font_size) or hundreds_font_size
		local dmg_scale_multiplier = 1

		if value > flashy_font_size_dmg_scale_range[1] then
			local minv = flashy_font_size_dmg_scale_range[1]
			local maxv = flashy_font_size_dmg_scale_range[2]
			local lerp = math_min((value - minv) / (maxv - minv), 1)
			local multiplier = math_lerp(flashy_font_size_dmg_multiplier[1], flashy_font_size_dmg_multiplier[2], lerp)

			font_size = font_size * multiplier
			dmg_scale_multiplier = multiplier
		end

		local expand_duration = damage_number.expand_duration

		if expand_duration then
			local expand_time = damage_number.expand_time
			local expand_progress = math_clamp(expand_time / expand_duration, 0, 1)
			local anim_progress = 1 - expand_progress

			font_size = font_size + damage_number_settings.expand_bonus_scale * anim_progress

			if expand_progress >= 1 then
				damage_number.expand_duration = nil
				damage_number.shrink_start_t = duration - damage_number_settings.shrink_duration
			else
				damage_number.expand_time = expand_time + dt
			end
		elseif damage_number.shrink_start_t and time > damage_number.shrink_start_t then
			local diff = time - damage_number.shrink_start_t
			local percentage = diff / damage_number_settings.shrink_duration
			local scale = 1 - percentage

			font_size = font_size * scale
			--text_color[1] = text_color[1] * scale
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
		local float_value = 45 * math_lerp(0.8, 1.2, random_number) * dmg_scale_multiplier
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
	position[2] = base_y
	position[1] = base_x
end

-----------------------------------------------------------------------
-- Damage number dispatcher
-----------------------------------------------------------------------

template.damage_number_function = function(pass, ui_renderer, ui_style, ui_content, position, size)
	--if ui_renderer.alpha_multiplier and ui_renderer.alpha_multiplier <= 0 then
	--	return
	--end

	local damage_numbers = ui_content.damage_numbers

	if (not damage_numbers or #damage_numbers == 0) and not (template.show_dps and ui_content.damage_has_started) then
		ui_style.font_size = template.damage_number_settings.default_font_size * RESOLUTION_LOOKUP.scale
		return
	end

	local damage_number_settings = template.damage_number_settings
	local scale = RESOLUTION_LOOKUP.scale
	if ui_content.scale then
		scale = ui_content.scale
	end
	local default_font_size = damage_number_settings.default_font_size * scale
	local dps_font_size = damage_number_settings.dps_font_size * scale
	local hundreds_font_size = damage_number_settings.hundreds_font_size * scale
	local font_type = mod.font_type

	_init_damage_colors()

	local default_color = CACHED_DAMAGE_COLORS.default
	local crit_color = CACHED_DAMAGE_COLORS.crit
	local weakspot_color = CACHED_DAMAGE_COLORS.weakspot

	-- reuse same table reference
	local text_color = ui_style.text_color

	local num_damage_numbers = #damage_numbers
	local z_position = position[3]
	local y_position = position[2]
	local x_position = position[1]
	local damage_has_started = ui_content.damage_has_started
	local dt = ui_renderer.dt

	if damage_has_started then
		if not ui_content.damage_has_started_timer then
			ui_content.damage_has_started_timer = dt
		elseif not ui_content.dead then
			ui_content.damage_has_started_timer = ui_content.damage_has_started_timer + dt
		end

		if template.show_dps and ui_content.dead then
			local dps_timer = ui_content.damage_has_started_timer or 0
			local dps_value = (dps_timer > 1 and (ui_content.damage_taken / dps_timer)) or ui_content.damage_taken or 0
			local text = string_format("%d DPS", dps_value)
			local dps_y_offset = damage_number_settings.dps_y_offset
			local damage_has_started_position

			if fs.hb_damage_number_type == damage_number_types.readable then
				damage_has_started_position = Vector3(x_position, y_position - dps_y_offset, z_position)
			else
				damage_has_started_position = Vector3(x_position, y_position - dps_y_offset * 0.6, z_position)
			end

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

		if ui_content.last_hit_zone_name then
			local hit_zone_name = ui_content.last_hit_zone_name
			local breed = ui_content.breed
			local armor_type = breed and breed.armor_type

			if breed and breed.hitzone_armor_override and breed.hitzone_armor_override[hit_zone_name] then
				--armor_type = breed.hitzone_armor_override[hit_zone_name]
			end

			if fs.show_armor_types then
				local armor_type_loc_string = armor_type and armor_type_string_lookup[armor_type] or ""
				local armor_type_text = Localize(armor_type_loc_string)

				if fs.hb_damage_number_type == damage_number_types.readable then
					local armor_type_position = Vector3(x_position, y_position, z_position)

					--[[UIRenderer.draw_text(
						ui_renderer,
						armor_type_text,
						dps_font_size,
						font_type,
						armor_type_position,
						size,
						ui_style.text_color,
						{},
						"armour_type1"
					)]]
					--ui_content.armour_type = armor_type_text
				else
					local armor_type_position = Vector3(x_position, y_position, z_position)

					--[[UIRenderer.draw_text(
						ui_renderer,
						armor_type_text,
						dps_font_size,
						font_type,
						armor_type_position,
						size,
						ui_style.text_color,
						{},
						"armour_type1"
					)]]
					--ui_content.armour_type = armor_type_text
				end
			end
		end
	end

	if fs.show_damage_numbers and num_damage_numbers > 0 then
		if fs.hb_damage_number_type == damage_number_types.floating then
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
		elseif fs.hb_damage_number_type == damage_number_types.flashy then
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

template.readable_damage_number_function = function(pass, ui_renderer, ui_style, ui_content, position, size)
	--if ui_renderer.alpha_multiplier and ui_renderer.alpha_multiplier <= 0 then
	--	return
	--end

	local damage_numbers = ui_content.damage_numbers

	if (not damage_numbers or #damage_numbers == 0) and not (template.show_dps and ui_content.damage_has_started) then
		ui_style.font_size = template.damage_number_settings.default_font_size * RESOLUTION_LOOKUP.scale
		return
	end

	local damage_number_settings = template.damage_number_settings
	local scale = RESOLUTION_LOOKUP.scale
	if ui_content.scale then
		scale = ui_content.scale
	end
	local default_font_size = damage_number_settings.default_font_size * scale
	local dps_font_size = damage_number_settings.dps_font_size * scale
	local hundreds_font_size = damage_number_settings.hundreds_font_size * scale
	local font_type = mod.font_type

	_init_damage_colors()

	local default_color = CACHED_DAMAGE_COLORS.default
	local crit_color = CACHED_DAMAGE_COLORS.crit
	local weakspot_color = CACHED_DAMAGE_COLORS.weakspot

	-- reuse same table reference
	local text_color = ui_style.text_color

	local num_damage_numbers = #damage_numbers
	local z_position = position[3]
	local y_position = position[2]
	local x_position = position[1]
	local damage_has_started = ui_content.damage_has_started
	local dt = ui_renderer.dt

	if damage_has_started then
		if not ui_content.damage_has_started_timer then
			ui_content.damage_has_started_timer = dt
		elseif not ui_content.dead then
			ui_content.damage_has_started_timer = ui_content.damage_has_started_timer + dt
		end

		if template.show_dps and ui_content.dead then
			local dps_timer = ui_content.damage_has_started_timer or 0
			local dps_value = (dps_timer > 1 and (ui_content.damage_taken / dps_timer)) or ui_content.damage_taken or 0
			local text = string_format("%d DPS", dps_value)
			local dps_y_offset = damage_number_settings.dps_y_offset
			local damage_has_started_position

			if fs.hb_damage_number_type == damage_number_types.readable then
				damage_has_started_position = Vector3(x_position, y_position - dps_y_offset, z_position)
			else
				damage_has_started_position = Vector3(x_position, y_position - dps_y_offset * 0.6, z_position)
			end

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

		if ui_content.last_hit_zone_name then
			local hit_zone_name = ui_content.last_hit_zone_name
			local breed = ui_content.breed
			local armor_type = breed and breed.armor_type

			if breed and breed.hitzone_armor_override and breed.hitzone_armor_override[hit_zone_name] then
				--armor_type = breed.hitzone_armor_override[hit_zone_name]
			end

			if fs.show_armor_types then
				local armor_type_loc_string = armor_type and armor_type_string_lookup[armor_type] or ""
				local armor_type_text = Localize(armor_type_loc_string)

				if fs.hb_damage_number_type == damage_number_types.readable then
					local armor_type_position = Vector3(x_position, y_position, z_position)

					--[[UIRenderer.draw_text(
						ui_renderer,
						armor_type_text,
						dps_font_size,
						font_type,
						armor_type_position,
						size,
						ui_style.text_color,
						{},
						"armour_type1"
					)]]
					--ui_content.armour_type = armor_type_text
				else
					local armor_type_position = Vector3(x_position, y_position, z_position)

					--[[UIRenderer.draw_text(
						ui_renderer,
						armor_type_text,
						dps_font_size,
						font_type,
						armor_type_position,
						size,
						ui_style.text_color,
						{},
						"armour_type1"
					)]]
					--ui_content.armour_type = armor_type_text
				end
			end
		end
	end

	if fs.show_damage_numbers and num_damage_numbers > 0 then
		if fs.hb_damage_number_type == damage_number_types.readable then
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
		end
	end

	ui_style.font_size = default_font_size
end

-----------------------------------------------------------------------
-- Widget definition
-----------------------------------------------------------------------

template.create_widget_defintion = function(template, scenegraph_id)
	local size = { fs.hb_size_width, fs.hb_size_height }
	local bar_width = size[1]
	local bar_height = size[2]

	local bar_offset = { -bar_width * 0.5, 0, 0 }

	local icon_style = {
		vertical_alignment = "center",
		horizontal_alignment = "center",
		offset = { -bar_width * 0.5 - 24, 0, 6 },
		default_offset = { -bar_width * 0.5 - 24, 0, 6 },
		size = { 28, 28 },
		default_size = { 28, 28 },
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
				color = { 200, 120, 40, 40 },
				default_alpha = 200,
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
				offset = { -bar_width * 0.5 - 24, 0, 0 },
				default_offset = { -bar_width * 0.5 - 24, 0, 0 },

				size = { 50, 50 },
				default_size = { 50, 50 },

				color = { 200, 15, 15, 15 },
				default_alpha = 200,

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
				offset = { -bar_width * 0.5 - 24, 0, 8 },
				default_offset = { -bar_width * 0.5 - 24, 0, 8 },

				size = { 50, 50 },
				default_size = { 50, 50 },

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
				offset = { -bar_width * 0.5, -bar_height - 10 * mod.text_scale * fs.hb_gap_padding_scale, 6 },
				default_offset = { -bar_width * 0.5, -bar_height - 10 * mod.text_scale * fs.hb_gap_padding_scale, 6 },
				font_type = mod.font_type,
				font_size = 16,
				default_font_size = 16,
				text_color = fs.main_colour or { 220, 220, 220, 220 },
				default_text_color = fs.main_colour or { 220, 220, 220, 220 },
				size = { bar_width * 4 - 2 * mod.text_scale, 20 },
				default_size = { bar_width * 4 - 2 * mod.text_scale, 20 },
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
				offset = { -bar_width * 0.5, ((bar_height + 16) * mod.text_scale) * fs.hb_gap_padding_scale, 6 },
				default_offset = { -bar_width * 0.5, ((bar_height + 16) * mod.text_scale) * fs.hb_gap_padding_scale, 6 },
				font_type = mod.font_type,
				font_size = 16,
				default_font_size = 16,
				text_color = fs.main_colour or { 220, 220, 220, 220 },
				default_text_color = fs.main_colour or { 220, 220, 220, 220 },
				size = { bar_width * 4 * mod.text_scale, 20 },
				default_size = { bar_width * 4 * mod.text_scale, 20 },

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
				offset = { -bar_width * 0.5, ((bar_height + 34) * mod.text_scale) * fs.hb_gap_padding_scale, 6 },
				default_offset = { -bar_width * 0.5, ((bar_height + 34) * mod.text_scale) * fs.hb_gap_padding_scale, 6 },
				font_type = mod.font_type,
				font_size = 16,
				default_font_size = 16,
				text_color = fs.secondary_colour or { 220, 220, 220, 220 },
				default_text_color = fs.secondary_colour or { 220, 220, 220, 220 },
				size = { bar_width * 4 * mod.text_scale, 20 },
				default_size = { bar_width * 4 * mod.text_scale, 20 },

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
				offset = { -bar_width * 0.5, bar_height + 50 * mod.text_scale * fs.hb_gap_padding_scale, 6 },
				default_offset = { -bar_width * 0.5, bar_height + 50 * mod.text_scale * fs.hb_gap_padding_scale, 6 },
				font_type = mod.font_type,
				font_size = 16,
				default_font_size = 16,
				text_color = fs.secondary_colour or { 220, 220, 220, 220 },
				default_text_color = fs.secondary_colour or { 220, 220, 220, 220 },
				size = { bar_width * 4 * mod.text_scale, 20 },
				default_size = { bar_width * 4 * mod.text_scale, 20 },

				drop_shadow = true,
				default_alpha = 255,
			},
			visibility_function = function(content)
				if content.dn_built then
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
				horizontal_alignment = "center",
				vertical_alignment = "center",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "bottom",
				offset = { 0, bar_height + 100 * mod.text_scale, 6 },
				default_offset = { 0, bar_height + 100 * mod.text_scale, 6 },
				font_type = mod.font_type,
				font_size = 16,
				default_font_size = 16,
				text_color = { 220, 220, 220, 220 },
				default_text_color = { 220, 220, 220, 220 },
				size = { bar_width * 2 * mod.text_scale, 20 },
				default_size = { bar_width * 2 * mod.text_scale, 20 },
				drop_shadow = true,
				default_alpha = 255,
			},
			visibility_function = function(content)
				if content.dn_built then
					return true
				else
					return false
				end
			end,
		},
	}, scenegraph_id)
end

-----------------------------------------------------------------------
-- Lifecycle
-----------------------------------------------------------------------

local function is_weakspot(breed, zone)
	local t = breed and breed.hit_zone_weakspot_types
	return t and t[zone]
end

local function format_number(n)
	return tostring(n):gsub("%.", ",")
end

local function get_text_option(content, option)
	if not option or option == "nothing" then
		return ""
	end

	local breed_type = content._breed_type or "enemy"
	local breed = content.breed

	if option == "enemy_type" then
		return mod:localize(breed_type) or ""
	elseif option == "enemy_name" then
		if content.in_horde_cluster then
			local cluster_string = Localize(breed.display_name) .. " " .. mod:localize("horde")

			if content.cluster_count then
				cluster_string = cluster_string .. " (x " .. content.cluster_count .. ")"
			end

			return cluster_string
		else
			return Localize(breed.display_name) or ""
		end
	elseif option == "armour_type" then
		local armor_type = breed and breed.armor_type
		local armor_type_loc_string = armor_type and armor_type_string_lookup[armor_type] or ""
		local armor_type_text = Localize(armor_type_loc_string)

		if content.last_hit_zone_name then
			local hit_zone_name = content.last_hit_zone_name

			if breed and breed.hitzone_armor_override and breed.hitzone_armor_override[hit_zone_name] then
				armor_type = breed.hitzone_armor_override[hit_zone_name]
			end

			armor_type_loc_string = armor_type and armor_type_string_lookup[armor_type] or ""
			armor_type_text = Localize(armor_type_loc_string)
		end

		return armor_type_text
	elseif option == "health" then
		local health_extension = content.health_extension
		if not health_extension then
			health_extension = ScriptUnit_has_extension(unit, "health_system")
			content.health_extension = health_extension
		end
		local health_current = content.health_current
		local health_max = content.health_max
		local health_percent = content.health_percent
		local is_dead = true
		local new_text = ""

		if content._last_health_current and content._last_health_max and content._last_damage_value then
			if not fs.hb_text_show_damage then
				if fs.hb_text_show_max_health then
					new_text = math_floor(content._last_health_current) .. " / " .. math_floor(content._last_health_max)
				else
					new_text = math_floor(content._last_health_current)
				end
			else
				if fs.hb_text_show_max_health then
					new_text = math_floor(content._last_health_current)
						.. " / "
						.. math_floor(content._last_health_max)
						.. " ({#color(255, 255, 50)}-"
						.. math_floor(content._last_damage_value)
						.. "{#reset()})"
				else
					new_text = math_floor(content._last_health_current)
						.. " ({#color(255, 255, 50)}-"
						.. math_floor(content._last_damage_value)
						.. "{#reset()})"
				end
			end
		elseif health_current and health_max then
			if fs.hb_text_show_max_health then
				new_text = math_floor(health_current) .. " / " .. math_floor(health_max)
			else
				new_text = math_floor(health_current)
			end
		end

		return new_text
	end
end

template.on_enter = function(widget, marker, template)
	local content = widget.content
	local style = widget.style

	template.position_offset = { 0, 0, fs.hb_y_offset }

	content.hb_built = false
	marker.draw = false -- force hidden until ready...

	content.damage_taken = 0
	content.damage_numbers = {}
	content.spawn_progress_timer = 0

	local unit = marker.unit
	local unit_data_extension = ScriptUnit_extension(unit, "unit_data_system")
	local breed = unit_data_extension and unit_data_extension:breed()

	content.breed = breed
	content.unit_data_extension = unit_data_extension

	local bar_settings = template.bar_settings
	marker.bar_logic = HudHealthBarLogic:new(bar_settings)

	content._breed_type = mod.find_breed_category(unit)
	breed_type = content._breed_type

	content.special_attack_imminent = false

	content.health_extension = ScriptUnit_has_extension(unit, "health_system")

	-- set frame background
	content.frame = fs.frame_type

	-------------------------------------------------------------------
	-- Icon logic / colors
	-------------------------------------------------------------------

	-- default to hidden
	content.icon_special = false
	content.icon_disabler = false
	content.icon_sniper = false
	content.icon_elite = false
	content.icon_elite_ranged = false
	content.icon_boss = false
	content.icon_witch = false
	content.icon_captain = false
	content.icon_enabled = false

	-- get values from data store
	local icon_color = mod.ICON_COLOURS[breed_type]
	local icon_enabled = mod.ICON_SETTINGS[breed_type].enabled
	local icon_full_scale = mod.ICON_SETTINGS[breed_type].scale
	local icon_scale = mod.ICON_SETTINGS[breed_type].icon_scale
	local icon_glow_colour = mod.ICON_COLOURS["glow"]
	local icon_glow_intensity = mod.ICON_SETTINGS[breed_type].glow_intensity

	-- apply values to relevant icon
	local function apply_icon_settings(content_icon, style_icon)
		if content._last_icon_scale == marker.scale then
			return content_icon, style_icon
		end

		content._last_icon_scale = marker.scale

		content_icon = icon_enabled
		content.icon_enabled = content_icon

		-- set colours
		style_icon.color[2] = icon_color[2]
		style_icon.color[3] = icon_color[3]
		style_icon.color[4] = icon_color[4]

		-- apply full scale:

		style_icon.size[1] = ((style_icon.default_size[1] * icon_scale) * icon_full_scale) * marker.scale
		style_icon.size[2] = ((style_icon.default_size[2] * icon_scale) * icon_full_scale) * marker.scale
		style.icon_background1.size[1] = (style.icon_background1.default_size[1] * icon_full_scale) * marker.scale
		style.icon_background1.size[2] = (style.icon_background1.default_size[2] * icon_full_scale) * marker.scale
		style.icon_background.size[1] = (style.icon_background.default_size[1] * icon_full_scale) * marker.scale
		style.icon_background.size[2] = (style.icon_background.default_size[2] * icon_full_scale) * marker.scale

		return content_icon, style_icon
	end

	-- do stuff per breed type
	if fs.healthbar_type_icon_enable then
		if breed_type == "far" then
			content.icon_elite_ranged, style.icon_elite_ranged =
				apply_icon_settings(content.icon_elite_ranged, style.icon_elite_ranged)
		end
		if breed_type == "elite" then
			content.icon_elite, style.icon_elite = apply_icon_settings(content.icon_elite, style.icon_elite)
		end
		if breed_type == "special" then
			content.icon_special, style.icon_special = apply_icon_settings(content.icon_special, style.icon_special)
		end
		if breed_type == "disabler" then
			content.icon_disabler, style.icon_disabler = apply_icon_settings(content.icon_disabler, style.icon_disabler)
		end
		if breed_type == "sniper" then
			content.icon_sniper, style.icon_sniper = apply_icon_settings(content.icon_sniper, style.icon_sniper)
		end
		if breed_type == "captain" or breed_type == "cultist_captain" then
			content.icon_captain, style.icon_captain = apply_icon_settings(content.icon_captain, style.icon_captain)
		end
		if breed_type == "witch" then
			content.icon_witch, style.icon_witch = apply_icon_settings(content.icon_witch, style.icon_witch)
		end
		if breed_type == "monster" then
			content.icon_boss, style.icon_boss = apply_icon_settings(content.icon_boss, style.icon_boss)
		end
		if breed_type == "horde" then
			content.icon_enabled = false
		end
	end

	local bar_color = mod.BREED_COLOURS[breed_type] or mod.BREED_COLOURS.horde

	-- INDIVIDUAL COLOUR OVERRIDES
	if breed then
		local enemy_individual = breed.name

		if enemy_individual then
			local breed_settings = minion_breeds[enemy_individual]

			if breed_settings then
				local tags = breed_settings.tags
				local individual_breed_type = mod.find_breed_category_by_tags(tags)

				if individual_breed_type == breed_type then
					if mod:get("healthbar_" .. enemy_individual .. "_enable") then
						bar_color = mod.BREED_COLOURS_OVERRIDE[enemy_individual]
					end
				end
			end
		end
	end

	style.current_health.color[2] = bar_color[2]
	style.current_health.color[3] = bar_color[3]
	style.current_health.color[4] = bar_color[4]

	local ghost_color = style.ghost_bar.color

	ghost_color[2] = bar_color[2] * 0.7
	ghost_color[3] = bar_color[3] * 0.7
	ghost_color[4] = bar_color[4] * 0.7

	local icon_offset_y = 0

	if style.icon_elite.color[1] > 0 then
		style.icon_elite.offset[2] = icon_offset_y
	end
end

-----------------------------------------------------------------------
-- Main update
-----------------------------------------------------------------------

local DEBUG_DAMAGE = false

local function debug_damage(msg)
	if DEBUG_DAMAGE then
		mod:echo("[DMG DEBUG] " .. tostring(msg))
	end
end

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	widget._next_update = widget._next_update or 0

	if t < widget._next_update then
		return
	end

	-- if not on screen or draw == false, throttle heavily....
	if not marker.is_inside_frustum or marker.draw == false then
		widget._next_update = t + 0.25
		return
	-- distance based updates
	elseif marker.distance < 50 then
		widget._next_update = t + 0.02
	elseif marker.distance < 70 then
		widget._next_update = t + 0.04
	else
		widget._next_update = t + 0.08
	end

	local content = widget.content
	local style = widget.style
	local unit = marker.unit
	fs = mod.frame_settings

	if not unit then
		marker.remove = true
		return
	end

	local entry = mod.enemy_cache[unit]

	-- early out
	if not marker.draw and not marker.is_inside_frustum and not template.check_line_of_sight then
		marker.draw = false
		return
	end

	if not mod.detect_alive(unit) then
		marker.draw = false
		marker.remove = true
		return
	end

	template.max_distance = fs.draw_distance

	local line_of_sight_progress = content.line_of_sight_progress or 0

	if template.check_line_of_sight then
		if marker.raycast_initialized then
			local raycast_result = marker.raycast_result
			local line_of_sight_speed = 8

			if raycast_result then
				line_of_sight_progress = math.max(line_of_sight_progress - dt * line_of_sight_speed, 0)
			else
				line_of_sight_progress = math.min(line_of_sight_progress + dt * line_of_sight_speed, 1)
			end
		end
	elseif not template.check_line_of_sight then
		line_of_sight_progress = 1
	end

	-------------------------------------------------------------------
	-- Health / alive
	-------------------------------------------------------------------
	local health_extension = content.health_extension
	local health_current = 0
	local health_max = 0
	local health_percent = 0
	local is_dead = true

	if health_extension and mod.detect_alive(unit) then
		health_current = health_extension:current_health() or 0
		health_max = health_extension:max_health() or 0
		health_percent = health_extension:current_health_percent() or 0
		is_dead = not health_extension:is_alive()
	end

	-------------------------------------------------------------------
	-- Breed / type
	-------------------------------------------------------------------
	local unit_data_extension = content.unit_data_extension
	if not unit_data_extension then
		unit_data_extension = ScriptUnit_has_extension(unit, "unit_data_system")
		content.unit_data_extension = unit_data_extension
	end
	local breed = content.breed or (unit_data_extension and unit_data_extension:breed())
	content.breed = breed

	local breed_type = content._breed_type or "enemy"

	-- if enemy group is disabled, don't show
	local group_hb_enabled = mod:get("healthbar_" .. breed_type .. "_enable")
	if group_hb_enabled ~= nil then
		if not group_hb_enabled then
			marker.draw = false
			marker.remove = true
			return
		end
	end

	-------------------------------------------------------------------
	-- Horde cluster: pooled HP + center position with stable max
	-------------------------------------------------------------------
	local cluster = mod.get_horde_cluster_for_unit and mod.get_horde_cluster_for_unit(unit)
	local in_horde_cluster = false

	if cluster and fs.horde_clusters_enable and fs.healthbar_enable then
		in_horde_cluster = true

		-- Only the cluster representative should ever have a bar marker, because
		-- enemy_markers.lua only spawns a bar for cluster.rep_unit.
		-- Still, guard and bail out if somehow non-rep gets here.
		if cluster.rep_unit ~= unit then
			marker.draw = false
			marker.remove = true
			content.in_horde_cluster = false
			return
		end

		content.in_horde_cluster = in_horde_cluster

		-- Recompute pooled health so it stays up-to-date as members take damage/die
		-- Throttle cluster updates (VERY important for FPS)
		local next_cluster_update = content._next_cluster_update or 0

		if t >= next_cluster_update then
			content._next_cluster_update = t + 0.1 -- 100ms update interval

			local total_current = 0
			local total_max_instant = 0

			local units = cluster.units
			local unit_count = #units
			content.cluster_count = unit_count

			for i = 1, unit_count do
				local u = units[i]
				local entry = mod.enemy_cache[u]

				if entry and entry.health_ext and mod.detect_alive(u) then
					local he = entry.health_ext
					total_current = total_current + (he:current_health() or 0)
					total_max_instant = total_max_instant + (he:max_health() or 0)
				end
			end

			content._cluster_cached_current = total_current
			content._cluster_cached_max = total_max_instant
		end

		local total_current = content._cluster_cached_current or 0
		local total_max_instant = content._cluster_cached_max or 0

		-- Stable max per representative unit: never decrease while this rep is alive
		local peak = peak_cluster_max_by_rep[unit] or 0
		if total_max_instant > peak then
			peak = total_max_instant
			peak_cluster_max_by_rep[unit] = peak
		end

		if peak > 0 then
			health_current = total_current
			health_max = peak
			health_percent = total_current / peak
		else
			health_current = 0
			health_max = 0
			health_percent = 0
		end

		-- Move bar to horde center, before template.position_offset is applied
		if cluster.center then
			local c = cluster.center
			local cx, cy, cz = c.x, c.y, c.z
			if cx ~= cx or cy ~= cy or cz ~= cz then
				return
			end
			local rep_unit = cluster.rep_unit
			if rep_unit and Unit.alive(rep_unit) then
				local rp = Unit.world_position(rep_unit, 1)

				-- clamp Z so it never goes below actual unit height
				local min_z = rp.z + 1.2
				if cz < min_z then
					cz = min_z
				end
			end

			cz = cz + 0.3

			if not marker.world_position then
				marker.world_position = Vector3Box(Vector3(cx, cy, cz))
			else
				local lerp_xy = 0.25
				local lerp_z = 0.1

				local prev_pos

				if content._smoothed_pos then
					prev_pos = content._smoothed_pos:unbox()
				else
					prev_pos = Vector3(cx, cy, cz)
				end

				local smoothed = Vector3(
					prev_pos.x + (cx - prev_pos.x) * lerp_xy,
					prev_pos.y + (cy - prev_pos.y) * lerp_xy,
					prev_pos.z + (cz - prev_pos.z) * lerp_z
				)

				-- store safely
				if not content._smoothed_pos then
					content._smoothed_pos = Vector3Box(smoothed)
				else
					content._smoothed_pos:store(smoothed)
				end

				-- apply to marker
				if not marker.world_position then
					marker.world_position = Vector3Box(smoothed)
				else
					marker.world_position:store(smoothed)
				end
			end
		end
	else
		-- Non-horde or clusters disabled

		peak_cluster_max_by_rep[unit] = nil

		if marker.world_position then
			marker.world_position = nil
		end
	end

	-- if horde individual bars is disabled, but clustered is enabled, only show clustered...
	if entry and entry.is_horde and not fs.horde_enable and fs.horde_clusters_enable and not in_horde_cluster then
		marker.draw = false
		return
	end

	local bar_logic = marker.bar_logic

	-- Failsafe percent clamp
	health_percent = health_percent or 0
	health_percent = math_clamp(health_percent, 0, 1)

	if bar_logic then
		bar_logic:update(dt, t, health_percent)
	end

	local health_fraction = 0
	local health_ghost_fraction = 0
	local health_max_fraction = 0

	if bar_logic then
		health_fraction, health_ghost_fraction, health_max_fraction = bar_logic:animated_health_fractions()
	end

	marker.health_fraction = health_fraction
	marker.health_ghost_fraction = health_ghost_fraction

	-- Fallback if animation system fails
	if not health_fraction then
		health_fraction = health_percent
		health_ghost_fraction = health_percent
		health_max_fraction = 1
	end

	local damage_taken_since_last = 0
	local prev_hp = previous_health[unit]

	if prev_hp then
		damage_taken_since_last = math.max(prev_hp - health_current, 0)
	end

	previous_health[unit] = health_current

	-------------------------------------------------------------------
	-- DAMAGE NUMBERS LOGIC
	-------------------------------------------------------------------

	local max_health_setting = health_max
	max_health_setting = (content.breed and content.breed.name and Managers.state.difficulty)
			and Managers.state.difficulty:get_minion_max_health(content.breed.name)
		or health_max

	local total_damage_taken
	local player_camera = parent._parent and parent._parent:player_camera()

	content.player_camera = player_camera

	if not is_dead and health_extension then
		total_damage_taken = health_extension:total_damage_taken()
	else
		total_damage_taken = max_health_setting or health_max
	end

	if health_extension and not is_dead then
		local last_damaging_unit = health_extension:last_damaging_unit()

		if last_damaging_unit then
			content.last_hit_zone_name = health_extension:last_hit_zone_name() or "center_mass"
			content.last_damaging_unit = last_damaging_unit

			local breed_local = content.breed
			local hit_zone_weakspot_types = breed_local and breed_local.hit_zone_weakspot_types

			if is_weakspot(breed_local, content.last_hit_zone_name) then
				content.hit_weakspot = true
			else
				content.hit_weakspot = false
			end

			content.was_critical = health_extension:was_hit_by_critical_hit_this_render_frame()

			local last_hit_world_position = health_extension:last_hit_world_position()

			if last_hit_world_position then
				local box = content.last_hit_world_position
				if not box then
					content.last_hit_world_position = Vector3Box(last_hit_world_position)
				else
					box:store(last_hit_world_position)
				end
			end
		end
	end

	local damage_number_settings = template.damage_number_settings
	local Managers_player_local = Managers_player
	local local_player = Managers_player_local:local_player(1)
	local local_player_unit = local_player and local_player.player_unit

	template.skip_damage_from_others = false --fs.hb_damage_numbers_track_friendly

	local show_damage_number = true
	local last_damaging_unit = content.last_damaging_unit
	local last_was_player_damage = false

	local owner_unit = nil

	if last_damaging_unit and local_player_unit then
		if last_damaging_unit == local_player_unit then
			last_was_player_damage = true
		else
			owner_unit = Managers.state.unit_spawner:owner(last_damaging_unit)
			if owner_unit == local_player_unit then
				last_was_player_damage = true
			end
		end
	end

	-- DEBUG OUTPUT
	if DEBUG_DAMAGE and damage_taken_since_last > 0 then
		debug_damage("---- Damage Event ----")
		debug_damage("Damage: " .. tostring(damage_taken_since_last))
		debug_damage("Last damaging unit: " .. tostring(last_damaging_unit))
		debug_damage("Local player unit: " .. tostring(local_player_unit))
		debug_damage("Owner unit: " .. tostring(owner_unit))
		debug_damage("Is player damage: " .. tostring(last_was_player_damage))
	end

	if template.skip_damage_from_others then
		if last_was_player_damage then
			show_damage_number = true
		else
			show_damage_number = false
		end
	else
		show_damage_number = true
	end

	if DEBUG_DAMAGE and damage_taken_since_last > 0 then
		debug_damage("Skip others setting: " .. tostring(template.skip_damage_from_others))
		debug_damage("Show damage number: " .. tostring(show_damage_number))
	end

	local damage_numbers = content.damage_numbers
	if not damage_numbers then
		damage_numbers = {}
		content.damage_numbers = damage_numbers
	end
	local latest_damage_number = damage_numbers[#damage_numbers]

	if damage_taken_since_last > 0 and health_extension and not is_dead then
		content.visibility_delay = damage_number_settings.visibility_delay
		content.damage_taken = total_damage_taken

		if show_damage_number then
			if fs.hb_damage_show_only_latest then
				-- add new unit to the end
				table.insert(mod.latest_damaged_enemies, unit)

				-- remove oldest entries if we exceed the limit
				while #mod.latest_damaged_enemies > fs.hb_damage_show_only_latest_value do
					table.remove(mod.latest_damaged_enemies, 1)
				end
			end

			local damage_diff = math.ceil(damage_taken_since_last)
			local should_add = true
			local was_critical = health_extension and health_extension:was_hit_by_critical_hit_this_render_frame()

			if latest_damage_number then
				local add_numbers_together_timer = fs.hb_damage_number_type == damage_number_types.flashy
						and damage_number_settings.add_numbers_together_timer_flashy
					or damage_number_settings.add_numbers_together_timer

				if add_numbers_together_timer > t - latest_damage_number.start_time then
					should_add = false
				end
			end

			if fs.hb_damage_numbers_add_total then
				content.add_on_next_number = false
			else
				content.add_on_next_number = true
			end

			if fs.show_damage_numbers or fs.hb_text_show_damage then
				if content.add_on_next_number or was_critical or should_add then
					local damage_number = {
						expand_time = 0,
						time = 0,
						start_time = t,
						duration = damage_number_settings.duration,
						value = damage_diff,
						expand_duration = damage_number_settings.expand_duration,
						random_number = math_random(),
						float_right = math_random() > 0.5,
					}
					local breed_local = content.breed
					local hit_zone_weakspot_types = breed_local and breed_local.hit_zone_weakspot_types

					if is_weakspot(breed_local, content.last_hit_zone_name) then
						damage_number.hit_weakspot = true
					else
						damage_number.hit_weakspot = false
					end

					damage_number.was_critical = was_critical
					local dn_index = #damage_numbers + 1
					damage_numbers[dn_index] = damage_number

					-- Prevent runaway memory usage
					if #damage_numbers > 20 then
						table.remove(damage_numbers, 1)
					end

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
					latest_damage_number.value =
						math_clamp(latest_damage_number.value + damage_diff, 0, max_health_setting)
					latest_damage_number.time = 0
					latest_damage_number.expand_time = 0
					latest_damage_number.expand_duration = damage_number_settings.expand_duration
					latest_damage_number.shrink_start_t = nil
					latest_damage_number.y_position = nil
					latest_damage_number.start_time = t

					local breed_local = content.breed
					local hit_zone_weakspot_types = breed_local and breed_local.hit_zone_weakspot_types

					if is_weakspot(breed_local, content.last_hit_zone_name) then
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

		-------------------------------------------------------------------
		-- Health counter text
		-------------------------------------------------------------------
		if
			content._last_health_current ~= health_current
			or content._last_health_max ~= health_max
			or content._last_damage_value ~= (latest_damage_number and latest_damage_number.value)
		then
			content._last_health_current = health_current
			content._last_health_max = health_max
			content._last_damage_value = latest_damage_number and latest_damage_number.value
		end
	end
	--if fs.healthbar_enable then
	-------------------------------------------------------------------
	-- Health bar / ghost / toughness
	-------------------------------------------------------------------

	local size = { fs.hb_size_width, fs.hb_size_height }
	template.size = size

	-- only do healthbar calculations if theyre enabled... Still lets the damage numbers do their thing :)
	if health_fraction and health_ghost_fraction then
		local bar_settings = template.bar_settings
		local spacing = bar_settings.bar_spacing
		local bar_width = template.size[1]
		local bar_height = template.size[2]

		local default_width_offset = -bar_width * 0.5
		local scale = marker.scale or 1
		content.scale = scale

		local health_max_style = style.health_max
		--health_max_style.default_size[1] = bar_width * scale
		health_max_style.size[1] = bar_width * scale

		health_max_style.size[2] = bar_height * scale

		local current_health_style = style.current_health
		local ghost_bar_style = style.ghost_bar

		local scaled_bar_width = health_max_style.size[1]
		content.scaled_bar_width = scaled_bar_width

		local scaled_health_width = scaled_bar_width * health_fraction

		local frame_style = style.frame
		frame_style.size[1] = (bar_width + 12) * scale

		local ghost_fraction = math_max(health_ghost_fraction - health_fraction, 0)
		local scaled_ghost_width = scaled_bar_width * ghost_fraction
	end

	content.health_fraction = health_fraction
	content.health_ghost_fraction = health_ghost_fraction

	local icon_color = mod.ICON_COLOURS[breed_type]

	local icon_enabled = mod.ICON_SETTINGS[breed_type].enabled
	local icon_full_scale = mod.ICON_SETTINGS[breed_type].scale
	local icon_scale = mod.ICON_SETTINGS[breed_type].icon_scale
	local icon_glow_colour = mod.ICON_COLOURS["glow"]
	local icon_glow_colour_default = mod.ICON_COLOURS["glow_default"]
	local icon_glow_intensity = mod.ICON_SETTINGS[breed_type].glow_intensity

	-- apply values to relevant icon
	local function icon_special_attack(content_icon, style_icon)
		local update_interval = fs.special_attack_pulse_speed
		content._attack_update_time = (content._attack_update_time or 0) + dt

		if content._attack_update_time > update_interval then
			if fs.healthbar_specials_enable and marker.special_attack_imminent then
				-- get special colour
				local sr = mod:get("outline_specials_colour_R")
				local sg = mod:get("outline_specials_colour_G")
				local sb = mod:get("outline_specials_colour_B")

				if not sr then
					sr = 255
				end
				if not sg then
					sg = 0
				end
				if not sb then
					sb = 0
				end

				if not content.alert_healthbar then
					----- TURN ON
					-- set alert glow intensity
					style.icon_background1.default_alpha = 255

					-- set alert glow colour
					style.icon_background1.color[2] = sr
					style.icon_background1.color[3] = sg
					style.icon_background1.color[4] = sb
					content.alert_healthbar = true
				elseif content.alert_healthbar and fs.specials_flash then
					----- TURN OFF
					-- set alert glow intensity
					style.icon_background1.default_alpha = 0

					content.alert_healthbar = false
				end
			else
				if content.alert_healthbar then
					content.alert_healthbar = false
				end

				-- set alert glow colour
				style.icon_background1.default_alpha = icon_glow_intensity * 2.5
				style.icon_background1.color[2] = icon_glow_colour[2]
				style.icon_background1.color[3] = icon_glow_colour[3]
				style.icon_background1.color[4] = icon_glow_colour[4]

				if icon_glow_intensity > 0 then
					content.glow_enabled = true
				else
					content.glow_enabled = false
				end
			end

			content._attack_update_time = 0
		end

		-- apply full scale:

		style_icon.size[1] = ((style_icon.default_size[1] * icon_scale) * icon_full_scale) * marker.scale
		style_icon.size[2] = ((style_icon.default_size[2] * icon_scale) * icon_full_scale) * marker.scale
		style.icon_background1.size[1] = (style.icon_background1.default_size[1] * icon_full_scale) * marker.scale
		style.icon_background1.size[2] = (style.icon_background1.default_size[2] * icon_full_scale) * marker.scale
		style.icon_background.size[1] = (style.icon_background.default_size[1] * icon_full_scale) * marker.scale
		style.icon_background.size[2] = (style.icon_background.default_size[2] * icon_full_scale) * marker.scale

		return content_icon, style_icon
	end

	-- do stuff per breed type
	if fs.healthbar_type_icon_enable then
		if breed_type == "far" then
			content.icon_elite_ranged, style.icon_elite_ranged =
				icon_special_attack(content.icon_elite_ranged, style.icon_elite_ranged)
		end
		if breed_type == "elite" then
			content.icon_elite, style.icon_elite = icon_special_attack(content.icon_elite, style.icon_elite)
		end
		if breed_type == "special" then
			content.icon_special, style.icon_special = icon_special_attack(content.icon_special, style.icon_special)
		end
		if breed_type == "disabler" then
			content.icon_disabler, style.icon_disabler = icon_special_attack(content.icon_disabler, style.icon_disabler)
		end
		if breed_type == "sniper" then
			content.icon_sniper, style.icon_sniper = icon_special_attack(content.icon_sniper, style.icon_sniper)
		end
		if breed_type == "captain" or breed_type == "cultist_captain" then
			content.icon_captain, style.icon_captain = icon_special_attack(content.icon_captain, style.icon_captain)
		end
		if breed_type == "witch" then
			content.icon_witch, style.icon_witch = icon_special_attack(content.icon_witch, style.icon_witch)
		end
		if breed_type == "monster" then
			content.icon_boss, style.icon_boss = icon_special_attack(content.icon_boss, style.icon_boss)
		end
		if breed_type == "horde" then
			content.icon_enabled = false
		end
	end

	-------------------------------------------------------------------
	-- Height / healthbar position logic
	-------------------------------------------------------------------

	if in_horde_cluster == false and content.breed and mod.detect_alive(unit) then
		local root_position = Unit.world_position(unit, 1)
		root_position.z = root_position.z + content.breed.base_height + 0.5

		if not marker.world_position then
			marker.world_position = Vector3Box(root_position)
		else
			marker.world_position:store(root_position)
		end
	end

	content.health_current = health_current
	content.health_max = health_max
	content.health_percent = health_percent

	if fs.hb_text_top_left_01 then
		content.header_text = get_text_option(content, fs.hb_text_top_left_01)
	end
	if fs.hb_text_bottom_left_01 then
		content.health_counter = get_text_option(content, fs.hb_text_bottom_left_01)
	end
	if fs.hb_text_bottom_left_02 then
		content.armour_type = get_text_option(content, fs.hb_text_bottom_left_02)
	end
	--end

	-------------------------------------------------------------------
	-- Hide logic / LOS fade
	-------------------------------------------------------------------

	local time_since_last_damage = t - (content.last_damage_taken_time or 0)

	if not mod.detect_alive(unit) and (not marker.health_fraction or marker.health_fraction == 0) then
		marker.remove = true
	end

	-- only hide non-clustered horde units when horde disabled
	if breed_type == "horde" and not fs.horde_enable and not in_horde_cluster then
		marker.draw = false
	end

	if fs.horde_hide_after_no_damage and breed_type == "horde" and time_since_last_damage > 5 then
		marker.draw = false
	end

	if fs.hide_after_no_damage and breed_type ~= "horde" and time_since_last_damage > 5 then
		marker.draw = false
	end

	if not marker.is_inside_frustum then
		marker.draw = false
	end

	if fs.hb_damage_show_only_latest then
		if not table.contains(mod.latest_damaged_enemies, unit) then
			marker.draw = false
		end
	end

	content.line_of_sight_progress = line_of_sight_progress
	widget.alpha_multiplier = line_of_sight_progress or 1

	local draw = marker.draw

	if draw and line_of_sight_progress > 0 then
		if fs.healthbar_enable then
			content.hb_built = true
		end
		if fs.show_damage_numbers then
			content.dn_built = true
		end

		local scale = marker.scale * mod.text_scale
		mod.scale = scale

		local header_style = style.header_text
		local health_counter = style.health_counter
		local armour_type = style.armour_type
		local damage_numbers = style.readable_damage_numbers

		if header_style then
			header_style.font_size = header_style.default_font_size * scale
		end
		if health_counter then
			health_counter.font_size = health_counter.default_font_size * scale
		end
		if damage_numbers then
			damage_numbers.font_size = damage_numbers.default_font_size * scale
		end
		if armour_type then
			armour_type.font_size = armour_type.default_font_size * scale
		end
	else
		content.hb_built = false
	end
end

return template
