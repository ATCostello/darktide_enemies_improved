local mod = get_mod("enemies_improved")

local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}
local BreedQueries = require("scripts/utilities/breed_queries")
local minion_breeds = BreedQueries.minion_breeds_by_name()

-----------------------------------------------------------------------
-- Cached settings / constants
-----------------------------------------------------------------------
local fs = mod.frame_settings

local max_size_value = 32 * fs.marker_size

local size = { max_size_value, max_size_value }
local ping_size = { max_size_value, max_size_value }
local arrow_size = { max_size_value * 8, max_size_value * 8 }
local icon_size = { max_size_value / 2, max_size_value / 2 }
local background_size = { max_size_value, max_size_value }
local scale_fraction = 1

local ScriptUnit_extension = ScriptUnit.extension

local math_min = math.min
local math_max = math.max
local math_sin = math.sin
local math_floor = math.floor

-----------------------------------------------------------------------
-- Template static data
-----------------------------------------------------------------------

template.name = "enemy_markers"
template.unit_node = "root_point"
template.min_distance = 0
template.position_offset = { 0, 0, fs.marker_y_offset }

template.size = size
template.icon_size = icon_size
template.ping_size = ping_size

template.alerted = false

template.check_line_of_sight = fs.check_line_of_sight
template.screen_clamp = true
template.max_distance = fs.draw_distance

template.scale = 1

template.min_size = { size[1] * scale_fraction, size[2] * scale_fraction }
template.max_size = { size[1], size[2] }

template.icon_min_size = {
	icon_size[1] * scale_fraction,
	icon_size[2] * scale_fraction,
}
template.icon_max_size = { icon_size[1], icon_size[2] }

template.background_min_size = {
	background_size[1] * scale_fraction,
	background_size[2] * scale_fraction,
}
template.background_max_size = { background_size[1], background_size[2] }

template.ping_min_size = {
	ping_size[1] * scale_fraction,
	ping_size[2] * scale_fraction,
}
template.ping_max_size = { ping_size[1], ping_size[2] }

--template.screen_margins = {
--	down = 0.23148148148148148,
--	left = 0.234375,
--	right = 0.234375,
--	up = 0.23148148148148148,
--}

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
-- Widget creation
-----------------------------------------------------------------------

-- Fatshark typo: world markers expect `create_widget_defintion`
template.create_widget_defintion = function(template, scenegraph_id)
	return UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id = "background",
			value = "content/ui/materials/hud/interactions/frames/point_of_interest_back",
			value_id = "background",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = background_size,
				default_size = background_size,

				offset = { 0, 0, 1 },
				default_offset = { 0, 0, 1 },

				color = fs.marker_bg_colour,
				default_alpha = fs.marker_bg_colour[1],
			},

			visibility_function = function(content, style)
				return content.m_built
			end,
		},

		-- ONE WIDGET ONLY...
		{
			pass_type = "rotated_texture",
			style_id = "marker_health",
			value = "content/ui/materials/icons/system/page_indicator_02_idle",
			value_id = "marker_health",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = { background_size[1] / 2, background_size[2] / 2 },
				default_size = { background_size[1] / 2, background_size[2] / 2 },

				offset = { 0, 0, 2 },
				default_offset = { 0, 0, 2 },

				color = { 200, 255, 0, 0 },
				default_alpha = 200,
			},

			change_function = function(content, style)
				local health_extension = content.health_extension
				local health_percent = 0
				local unit = content.unit
				local breed = content.breed

				local health_percent = health_extension and health_extension:current_health_percent() or 0

				-- set styling depending on health percentage...
				if health_percent then
					if health_percent > 0.75 then
						content.marker_health = "content/ui/materials/icons/perks/perk_level_04"
					elseif health_percent > 0.50 then
						content.marker_health = "content/ui/materials/icons/perks/perk_level_03"
					elseif health_percent > 0.25 then
						content.marker_health = "content/ui/materials/icons/perks/perk_level_02"
					elseif health_percent > 0 then
						content.marker_health = "content/ui/materials/icons/perks/perk_level_01"
					end
				end
			end,

			visibility_function = function(content, style)
				return fs.markers_health_enable and content.m_built
			end,
		},

		{
			pass_type = "texture",
			style_id = "ring",
			value = "content/ui/materials/hud/interactions/frames/point_of_interest_top",
			value_id = "ring",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = size,
				default_size = size,

				offset = { 0, 0, 5 },
				default_offset = { 0, 0, 5 },

				color = { 0, 255, 255, 255 },
				default_alpha = 0,
			},
			visibility_function = function(content, style)
				return false
			end,
		},
		{
			pass_type = "rotated_texture",
			style_id = "ping",
			value = "content/ui/materials/hud/interactions/frames/point_of_interest_tag",
			value_id = "ping",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = ping_size,
				default_size = ping_size,

				offset = { 0, 0, 0 },
				default_offset = { 0, 0, 0 },

				color = { 255, 255, 255, 255 },
				default_alpha = 255,
			},
			visibility_function = function(content, style)
				return false
			end,
		},
		{
			pass_type = "texture",
			style_id = "icon",
			value = "content/ui/materials/hud/interactions/icons/enemy",
			value_id = "icon",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = icon_size,
				default_size = icon_size,

				offset = { 0, 0, 3 },
				default_offset = { 0, 0, 3 },

				color = { 0, 200, 175, 0 },
				default_alpha = 0,
			},
			visibility_function = function(content, style)
				return false
			end,
		},
		{
			pass_type = "rotated_texture",
			style_id = "arrow",
			value = "content/ui/materials/hud/interactions/frames/direction",
			value_id = "arrow",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				size = arrow_size,
				default_size = arrow_size,

				offset = { 0, 0, 2 },
				default_offset = { 0, 0, 2 },

				color = { 255, 255, 255, 255 },
				default_alpha = 255,
			},
			visibility_function = function(content, style)
				return content.special_attack_imminent and content.is_clamped and content.m_built
			end,
			change_function = function(content, style)
				style.angle = content.angle
			end,
		},
	}, scenegraph_id)
end

-----------------------------------------------------------------------
-- Lifecycle
-----------------------------------------------------------------------

template.on_enter = function(widget, marker, template)
	local pos = template.position_offset
	pos[1], pos[2], pos[3] = 0, 0, fs.marker_y_offset
	widget.alpha_multiplier = 0
	local content = widget.content
	content.m_built = false

	marker.draw = false -- force hidden until ready...

	local unit = marker.unit
	content.unit = unit
	local unit_data_extension = ScriptUnit_extension(unit, "unit_data_system")
	local breed = unit_data_extension and unit_data_extension:breed()
	content.health_extension = ScriptUnit_extension(unit, "health_system")

	content.breed = breed
	content.breed_type = mod.find_breed_category(unit)
	content.breed_settings = content.breed and minion_breeds[content.breed.name]

	if content.breed and content.breed.name then
		content.healthbar_enabled = mod:get("healthbar_" .. content.breed.name .. "_enable")
	end

	content.m_allowed = true

	local enemy_individual = content.breed and content.breed.name

	if enemy_individual then
		local enabled = mod:get("markers_" .. enemy_individual .. "_toggle")

		if enabled ~= nil then
			content.m_allowed = enabled
		end
	end

	content.special_attack_imminent = false

	local fs = mod.frame_settings
	max_size_value = 32 * fs.marker_size
	ping_size[1], ping_size[2] = max_size_value, max_size_value
	arrow_size[1], arrow_size[2] = max_size_value * 8, max_size_value * 8
	icon_size[1], icon_size[2] = max_size_value / 2, max_size_value / 2
	background_size[1], background_size[2] = max_size_value, max_size_value
end

-----------------------------------------------------------------------
-- Update
-----------------------------------------------------------------------

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	widget._next_update = widget._next_update or 0

	if t < widget._next_update then
		return
	end

	-- if not on screen or draw == false, throttle heavily....
	if not marker.is_inside_frustum or marker.draw == false then
		widget._next_update = t + fs.off_screen_throttle_rate
		return
	-- distance based updates
	elseif marker.distance < 50 then
		widget._next_update = t + fs.general_throttle_rate
	elseif marker.distance < 70 then
		widget._next_update = t + fs.general_throttle_rate * 1.5
	else
		widget._next_update = t + fs.general_throttle_rate * 2
	end

	local content = widget.content
	local distance = content.distance or 0
	local data = marker.data
	local unit = marker.unit
	local marker_scale = marker.scale
	local style = widget.style

	if content.m_allowed == false then
		marker.remove = true
		return
	end

	if not mod.detect_alive(unit) then
		marker.draw = false
		marker.remove = true
		return
	end

	-- marker height
	if content.breed and mod.detect_alive(unit) then
		local root_position = Unit.world_position(unit, 1)

		if mod.frame_settings.healthbar_enable then
			root_position.z = root_position.z + content.breed.base_height + 0.1
		else
			root_position.z = root_position.z + content.breed.base_height + 0.5
		end

		if not marker.world_position then
			marker.world_position = Vector3Box(root_position)
		else
			marker.world_position:store(root_position)
		end
	end

	template.max_distance = fs.draw_distance

	local line_of_sight_progress = content.line_of_sight_progress or 0

	-- line-of-sight fade
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

	-----------------------------------------------------------------------
	-- Special attack warning pulse
	-----------------------------------------------------------------------

	mod.pulse_t = ((mod.pulse_t or 0) + mod.frame_settings.dt) % (math.pi * 2)

	if marker.special_attack_imminent then
		content.special_attack_imminent = true
		--content.is_clamped = true

		local pulse = math.abs(math.sin(mod.pulse_t * 2))

		local flash = math.min(255, 150 + pulse * 100)
		local size_scale = 1 + pulse * 0.5

		local r, g, b = flash, 50, 50

		style.arrow.color[2] = r
		style.arrow.color[3] = g
		style.arrow.color[4] = b

		style.background.color[2] = r
		style.background.color[3] = g
		style.background.color[4] = b

		style.arrow.size[2] = arrow_size[2] * size_scale / 2 * marker_scale

		style.background.size[1] = background_size[1] * size_scale * marker_scale
		style.background.size[2] = background_size[2] * size_scale * marker_scale
	else
		--content.is_clamped = false
		content.special_attack_imminent = false

		style.background.color[1] = fs.marker_bg_colour[1]
		style.background.default_alpha = fs.marker_bg_colour[1]

		style.background.color[2] = fs.marker_bg_colour[2]
		style.background.color[3] = fs.marker_bg_colour[3]
		style.background.color[4] = fs.marker_bg_colour[4]

		style.arrow.color[2] = 255
		style.arrow.color[3] = 255
		style.arrow.color[4] = 255

		style.arrow.size[1] = arrow_size[1] * marker_scale
		style.arrow.size[2] = arrow_size[2] * marker_scale

		style.background.size[1] = background_size[1] * marker_scale
		style.background.size[2] = background_size[2] * marker_scale

		style.marker_health.size[1] = (background_size[1] / 2) * marker_scale
		style.marker_health.size[2] = (background_size[2] / 2) * marker_scale
	end

	local bar_color = mod.BREED_COLOURS[content.breed_type] or mod.BREED_COLOURS.horde

	-- INDIVIDUAL COLOUR OVERRIDES
	local enemy_individual = content.breed.name

	if enemy_individual then
		local breed_settings = content.breed_settings
		if breed_settings then
			local tags = breed_settings.tags
			local individual_breed_type = mod.find_breed_category_by_tags(tags)

			if individual_breed_type == content.breed_type then
				if content.healthbar_enabled then
					bar_color = mod.BREED_COLOURS_OVERRIDE[enemy_individual]
				end
			end
		end
	end

	style.marker_health.color[2] = bar_color[2]
	style.marker_health.color[3] = bar_color[3]
	style.marker_health.color[4] = bar_color[4]

	content.line_of_sight_progress = line_of_sight_progress
	widget.alpha_multiplier = line_of_sight_progress or 1

	if not marker.is_inside_frustum then
		marker.draw = false
	end

	if marker.draw then
		content.m_built = true
	else
		content.m_built = false
	end
end

template.on_exit = function(widget, marker)
	marker.world_position = nil
end

return template
