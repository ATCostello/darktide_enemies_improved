local mod = get_mod("enemies_improved")
local fs = mod.frame_settings
local UIRenderer = require("scripts/managers/ui/ui_renderer")

local template = {}
local damage_number_types = table.enum("readable", "floating", "flashy")

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

local temp_vec3 = Vector3(0, 0, 0)

-- grab passed template values
local function _init(passed_template)
    template = passed_template
end

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
	local y_position = position[2]
	local x_position = position[1]
	local dt = ui_renderer.dt

	if ui_content.alpha_multiplier then
		--text_color[1] = text_color[1] * ui_content.alpha_multiplier
	end

	local flashy_font_size_dmg_multiplier = damage_number_settings.flashy_font_size_dmg_multiplier
	local flashy_font_size_dmg_scale_range = damage_number_settings.flashy_font_size_dmg_scale_range

	local max_damage_numbers = fs.readable_max_damage_numbers
	local dn_count = #damage_numbers

	if dn_count > max_damage_numbers then
		for j = max_damage_numbers + 1, dn_count do
			damage_numbers[j] = nil
		end
	end

	for i = num_damage_numbers, 1, -1 do
		local damage_number = damage_numbers[i]

		local duration = damage_number.duration / 2
		local time = damage_number.time
		local progress = math_clamp(time / duration, 0, 1)
		local max_damage_numbers = fs.readable_max_damage_numbers

		if progress >= 1 then
			damage_numbers[i] = damage_numbers[#damage_numbers]
			damage_numbers[#damage_numbers] = nil			
		else
			damage_number.time = time + dt
		end

		local c = default_color

		if damage_number.was_critical then
			c = crit_color
		elseif damage_number.hit_weakspot then
			c = weakspot_color
		end

		text_color[2] = c[2]
		text_color[3] = c[3]
		text_color[4] = c[4]

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
	local y_position = position[2]
	local x_position = position[1]
	local dt = ui_renderer.dt

	local max_damage_numbers = fs.readable_max_damage_numbers
	local dn_count = #damage_numbers

	if dn_count > max_damage_numbers then
		for j = max_damage_numbers + 1, dn_count do
			damage_numbers[j] = nil
		end
	end


	for i = num_damage_numbers, 1, -1 do
		local damage_number = damage_numbers[i]
		local duration = damage_number.duration / 2
		local time = damage_number.time
		local progress = math_clamp(time / duration, 0, 1)
		local max_damage_numbers = fs.readable_max_damage_numbers

		if progress >= 1 then
			damage_numbers[i] = damage_numbers[#damage_numbers]
			damage_numbers[#damage_numbers] = nil		
		else
			damage_number.time = time + dt
		end

		local c = default_color

		if damage_number.was_critical then
			c = crit_color
		elseif damage_number.hit_weakspot then
			c = weakspot_color
		end

		text_color[2] = c[2]
		text_color[3] = c[3]
		text_color[4] = c[4]

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
		position[2] = y_position - 35 * time
		position[1] = x_position + current_order * damage_number_settings.x_offset_between_numbers

		UIRenderer.draw_text(ui_renderer, text, font_size, font_type, position, size, text_color, {})
	end

	position[3] = z_position
	position[2] = y_position
	position[1] = x_position
end

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
	local y_position = position[2]
	local x_position = position[1]
	local dt = ui_renderer.dt

	local max_damage_numbers = fs.readable_max_damage_numbers
	local dn_count = #damage_numbers

	if dn_count > max_damage_numbers then
		for j = max_damage_numbers + 1, dn_count do
			damage_numbers[j] = nil
		end
	end


	for i = num_damage_numbers, 1, -1 do
		local damage_number = damage_numbers[i]
		local duration = damage_number.duration
		local time = damage_number.time
		local progress = math_clamp(time / duration, 0, 1)
		local max_damage_numbers = fs.readable_max_damage_numbers

		if progress >= 1 then
			damage_numbers[i] = damage_numbers[#damage_numbers]
			damage_numbers[#damage_numbers] = nil	
		else
			damage_number.time = time + dt
		end

		local c = default_color

		if damage_number.was_critical then
			c = crit_color
		elseif damage_number.hit_weakspot then
			c = weakspot_color
		end

		text_color[2] = c[2]
		text_color[3] = c[3]
		text_color[4] = c[4]

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

		temp_vec3.x = x_position + current_order * damage_number_settings.x_offset_between_numbers
		temp_vec3.y = y_position
		temp_vec3.z = z_position + current_order

		UIRenderer.draw_text(ui_renderer, text, font_size, font_type, temp_vec3, size, text_color, {})
	end

	position[3] = z_position
	position[2] = y_position
	position[1] = x_position
end

local _damage_number_function = function(pass, ui_renderer, ui_style, ui_content, position, size)
	--if ui_renderer.alpha_multiplier and ui_renderer.alpha_multiplier <= 0 then
	--	return
	--end
	if fs.hb_damage_number_type == damage_number_types.readable then
		return
	end

	if fs.hb_damage_number_type ~= damage_number_types.readable then

		if not ui_content.damage_numbers or #ui_content.damage_numbers == 0 then
			return
		end

		local damage_numbers = ui_content.damage_numbers

		if (not damage_numbers or #damage_numbers == 0) and not (template.show_dps and ui_content.damage_has_started) then
			ui_style.font_size = template.damage_number_settings.default_font_size * RESOLUTION_LOOKUP.scale
			return
		end

		local damage_number_settings = template.damage_number_settings
		local scale = ui_content.scale
		local default_font_size = damage_number_settings.default_font_size * fs.damage_number_scale
		local dps_font_size = damage_number_settings.dps_font_size * fs.damage_number_scale
		local hundreds_font_size = damage_number_settings.hundreds_font_size * fs.damage_number_scale
		local font_type = mod.font_type

		_init_damage_colors()

		local default_color = CACHED_DAMAGE_COLORS.default
		local crit_color = CACHED_DAMAGE_COLORS.crit
		local weakspot_color = CACHED_DAMAGE_COLORS.weakspot

		-- reuse same table reference
		local text_color = ui_style.text_color

		local num_damage_numbers = #damage_numbers

		position[1] = position[1] + (fs.hb_size_width * 0.4)
		position[2] = position[2] + ((ui_content.breed and ui_content.breed.base_height * 40 * fs.damage_number_y_offset or 100 * fs.damage_number_y_offset)) * ui_content.scale

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
				local dps_y_offset = damage_number_settings.dps_y_offset
				local damage_has_started_position

				if ui_content._last_dps_value ~= dps_value then
					ui_content._last_dps_value = dps_value
					ui_content._last_dps_text = string_format("%d DPS", dps_value)
				end

				local text = ui_content._last_dps_text

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

				return
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
end

local _readable_damage_number_function = function(pass, ui_renderer, ui_style, ui_content, position, size)
	--if ui_renderer.alpha_multiplier and ui_renderer.alpha_multiplier <= 0 then
	--	return
	--end
	-- in _readable_damage_number_function
	if fs.hb_damage_number_type ~= damage_number_types.readable then
		return
	end

	if fs.hb_damage_number_type == damage_number_types.readable then

		if not ui_content.damage_numbers or #ui_content.damage_numbers == 0 then
			return
		end

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

		local default_font_size = damage_number_settings.default_font_size * scale * fs.damage_number_scale
		local dps_font_size = damage_number_settings.dps_font_size * scale * fs.damage_number_scale
		local hundreds_font_size = damage_number_settings.hundreds_font_size * scale * fs.damage_number_scale
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
				local dps_y_offset = damage_number_settings.dps_y_offset
				local damage_has_started_position

				if ui_content._last_dps_value ~= dps_value then
					ui_content._last_dps_value = dps_value
					ui_content._last_dps_text = string_format("%d DPS", dps_value)
				end

				local text = ui_content._last_dps_text

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
end

return {
    init = _init,
    damage_number_function = _damage_number_function,
    readable_damage_number_function = _readable_damage_number_function
}
