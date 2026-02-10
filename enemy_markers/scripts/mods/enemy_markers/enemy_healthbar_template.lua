local mod = get_mod("enemy_markers")

local HudHealthBarLogic = require("scripts/ui/hud/elements/hud_health_bar_logic")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}
local size = {
	200,
	6,
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
	0.5,
}
template.check_line_of_sight = true
template.max_distance = 20
template.screen_clamp = false
template.bar_settings = {
	alpha_fade_delay = 2.6,
	alpha_fade_duration = 0.6,
	alpha_fade_min_value = 50,
	animate_on_health_increase = true,
	bar_spacing = 2,
	duration_health = 1,
	duration_health_ghost = 2.5,
	health_animation_threshold = 0.1,
}
template.fade_settings = {
	default_fade = 0,
	fade_from = 0,
	fade_to = 1,
	distance_max = template.max_distance,
	distance_min = template.max_distance * 0.5,
	easing_function = math.ease_exp,
}

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
					255,
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

		-- TOP EDGE HIGHLIGHT
		{
			pass_type = "rect",
			style_id = "edge_highlight",
			value = "content/ui/materials/frames/line_thin_sharp_edges",
			style = {
				vertical_alignment = "center",
				offset = {
					bar_offset[1],
					bar_offset[2] + bar_height - 1,
					4,
				},
				size = {
					bar_width,
					1,
				},
				color = {
					120,
					255,
					180,
					180,
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
			value = "<header_text>",
			value_id = "header_text",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "bottom",
				offset = {
					-bar_width * 0.5,
					bar_height + 4,
					6,
				},
				font_type = "proxima_nova_bold",
				font_size = 16,
				default_font_size = 16,
				text_color = { 220, 220, 220, 220 },
				default_text_color = { 220, 220, 220, 220 },
				size = { 400, 20 },
			},
		},

		-- Health text
		{
			pass_type = "text",
			style_id = "health_counter",
			value = "<health_counter>",
			value_id = "health_counter",
			style = {
				horizontal_alignment = "right",
				vertical_alignment = "center",
				text_horizontal_alignment = "right",
				text_vertical_alignment = "bottom",
				offset = {
					bar_width * 0.5,
					bar_height + 4,
					6,
				},
				font_type = "proxima_nova_bold",
				font_size = 14,
				default_font_size = 14,
				text_color = { 220, 220, 220, 220 },
				default_text_color = { 220, 220, 220, 220 },
				size = { 100, 20 },
			},
		},
	}, scenegraph_id)
end

template.on_enter = function(widget, marker, template)
	local content = widget.content

	content.spawn_progress_timer = 0

	local bar_settings = template.bar_settings

	marker.bar_logic = HudHealthBarLogic:new(bar_settings)
end

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	local content = widget.content
	local style = widget.style
	local unit = marker.unit
	local health_extension = ScriptUnit.has_extension(unit, "health_system")
	local health_percent = health_extension and health_extension:current_health_percent() or 0
	local bar_logic = marker.bar_logic

	bar_logic:update(dt, t, health_percent)

	local health_fraction, health_ghost_fraction, health_max_fraction = bar_logic:animated_health_fractions()

	-- Track damage
	local damage_taken = 0
	if previous_health[unit] then
		damage_taken = previous_health[unit] - health_extension:current_health()
	end
	previous_health[unit] = health_extension:current_health()

	-- Update health fraction and damage counter
	if health_fraction then
		-- Set the health bar size and color
		local bar_width = template.size[1]
		style.bar.size[1] = bar_width * health_fraction

		-- Health counter
		content.health_counter =
			string.format("%d / %d", health_extension:current_health(), health_extension:max_health())
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

	-- Detect breed
	local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = unit_data_extension and unit_data_extension:breed()

	local breed_type = "enemy"

	if breed then
		local tags = breed.tags

		if tags.horde then
			breed_type = "horde"
		elseif tags.ogryn then
			breed_type = "ogryn"
		elseif tags.elite then
			breed_type = "elite"
		elseif tags.monster then
			breed_type = "monster"
		elseif tags.disabler then
			breed_type = "disabler"
		end

		content.header_text = tostring(breed_type)
	end

	-- Reset icon visibility
	style.icon_elite.color[1] = 0
	style.icon_boss.color[1] = 0
	style.icon_shield.color[1] = 0

	-- ELITE / SPECIAL
	if breed_type == "elite" or breed_type == "ogryn" then
		style.icon_elite.color[1] = 255
	end

	-- MONSTER / BOSS
	if breed_type == "monster" then
		style.icon_boss.color[1] = 255
	end

	local bar_color = BREED_COLORS[breed_type] or BREED_COLORS.horde
	style.bar.color = bar_color

	style.ghost_bar.color = {
		bar_color[1],
		bar_color[2] * 0.7,
		bar_color[3] * 0.7,
		bar_color[4] * 0.7,
	}

	if breed_type == "elite" or breed_type == "ogryn" then
		style.edge_highlight.color = { 180, 255, 120, 60 }
	else
		style.edge_highlight.color = { 80, 255, 180, 180 }
	end

	if breed_type == "monster" then
		style.frame.color = { 255, 200, 60, 200 }
	end

	local icon_offset_y = 0

	if style.icon_shield.color[1] > 0 then
		style.icon_shield.offset[2] = icon_offset_y
		icon_offset_y = icon_offset_y + 16
	end

	if style.icon_elite.color[1] > 0 then
		style.icon_elite.offset[2] = icon_offset_y
	end

	-- hide if not damaged recently
	-- If the unit is damaged, update the last damaged time to current time
	if damage_taken > 0 then
		last_damaged_time[unit] = t
	end

	-- Hide health bar if no damage for the last 5 seconds
	local time_since_last_damage = t - (last_damaged_time[unit] or 0)

	if mod:get("hb_hide_after_no_damage") == true then
		if time_since_last_damage > 5 then
			marker.draw = false -- Hide the health bar if no damage in the last 5 seconds
		else
			marker.draw = true -- Otherwise, show the health bar
		end
	end

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
		if mod:get("hb_horde_enable") == false then
			marker.draw = false
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
