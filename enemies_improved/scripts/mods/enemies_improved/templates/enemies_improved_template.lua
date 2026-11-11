local mod = get_mod("enemies_improved")

local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}
local fs = mod.frame_settings
local EnemyHealthbarTemplate =
	mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/templates/healthbars/healthbar_template")
local EnemyMarkersTemplate = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/templates/markers_template")
local EnemyDebuffTemplate = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/templates/debuff_template")
local ScriptUnit_extension = ScriptUnit.extension

local function refresh_marker_distance(template, breed)
	local broadphase = fs.draw_distance_broadphase or fs.draw_distance

	if broadphase and template.max_distance ~= broadphase then
		template.max_distance = broadphase
	end

	local draw_distance = fs.draw_distance

	if breed then
		local breed_name = breed.name

		if breed_name and fs.breed_dist_enabled and fs.breed_dist_enabled[breed_name] then
			local individual_distance = fs.breed_dist_value and fs.breed_dist_value[breed_name]

			if individual_distance then
				draw_distance = individual_distance
			end
		end
	end

	local fade_settings = template.fade_settings

	if fade_settings and draw_distance and fade_settings.distance_max ~= draw_distance then
		fade_settings.distance_max = draw_distance
		fade_settings.distance_min = draw_distance - template.evolve_distance * 2
	end
end

template.name = "enemies_improved"
template.unit_node = "root_point"
template.position_offset = { 0, 0, fs.hb_y_offset }
template.check_line_of_sight = fs.check_line_of_sight
template.max_distance = fs.draw_distance_broadphase or fs.draw_distance
template.screen_clamp = false
template.evolve_distance = 1
template.size = { fs.hb_size_width, fs.hb_size_height }

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

template.show_dps = fs.hb_show_dps
template.skip_damage_from_others = true

template.damage_number_settings = {
	add_numbers_together_timer = 1,
	add_numbers_together_timer_flashy = 0,
	crit_color = "orange",
	crit_hit_size_scale = 1.5,
	default_color = "white",
	default_font_size = 16 * fs.text_scale,
	dps_font_size = 26 * fs.text_scale,
	dps_y_offset = -36,
	duration = fs.damage_number_duration,
	expand_bonus_scale = 4,
	expand_duration = 0.2,
	fade_delay = 2,
	first_hit_size_scale = 1.2,
	has_taken_damage_timer_remove_after_time = 5,
	has_taken_damage_timer_y_offset = 34,
	hundreds_font_size = 16 * fs.text_scale,
	max_float_y = 20,
	shrink_duration = 0.5,
	visibility_delay = 2,
	weakspot_color = "yellow",
	x_offset = 0,
	x_offset_between_numbers = 14 * fs.text_scale * 3,
	y_offset = 0,
	flashy_font_size_dmg_multiplier = { 1, 1.2 },
	flashy_font_size_dmg_scale_range = { 15, 50 },
}

local damage_number_functions =
	mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/templates/healthbars/damage_numbers")
damage_number_functions.init(template)

template.max_visible_rows = 10

template.create_widget_defintion = function(template, scenegraph_id)
	local hb_def = EnemyHealthbarTemplate.create_widget_defintion(EnemyHealthbarTemplate, scenegraph_id)
	local marker_def = EnemyMarkersTemplate.create_widget_defintion(EnemyMarkersTemplate, scenegraph_id)
	local debuff_def = EnemyDebuffTemplate.create_widget_defintion(EnemyDebuffTemplate, scenegraph_id)

	for k, v in pairs(marker_def.content) do
		hb_def.content[k] = v
	end
	for k, v in pairs(marker_def.style) do
		hb_def.style[k] = v
	end

	for k, v in pairs(debuff_def.content) do
		hb_def.content[k] = v
	end
	for k, v in pairs(debuff_def.style) do
		hb_def.style[k] = v
	end

	for i = 1, #marker_def.passes do
		UIWidget.add_definition_pass(hb_def, marker_def.passes[i])
	end

	for i = 1, #debuff_def.passes do
		UIWidget.add_definition_pass(hb_def, debuff_def.passes[i])
	end

	for i = 1, template.max_visible_rows do
		hb_def.content["debuff_icon_" .. i] = nil
	end

	return hb_def
end

template.on_enter = function(widget, marker, template)
	marker.draw = false
	marker.alpha_multiplier = 0
	widget.alpha_multiplier = 0

	local content = widget.content

	content._ei_scale_snapped = false
	content._ei_dead_at = nil

	local unit = marker.unit

	if not unit then
		marker.remove = true
		return
	end

	local unit_data_extension = ScriptUnit_extension(unit, "unit_data_system")
	local breed = unit_data_extension and unit_data_extension:breed()

	local y_offset = fs.hb_y_offset

	if breed then
		local breed_name = breed.name

		if breed_name then
			local breed_offsets = fs.breed_healthbar_y_offset
			local breed_enabled = fs.breed_healthbar_y_offset_enabled

			if breed_enabled and breed_enabled[breed_name] and breed_offsets then
				local individual_offset = breed_offsets[breed_name]

				if individual_offset then
					y_offset = individual_offset
				end
			else
				local breed_type = mod.find_breed_category(unit)

				local type_enabled = fs.breed_type_healthbar_y_offset_enabled
				local type_offsets = fs.breed_type_healthbar_y_offset

				if
					breed_type
					and type_enabled
					and type_enabled[breed_type]
					and type_offsets
					and type_offsets[breed_type]
				then
					y_offset = type_offsets[breed_type]
				end
			end
		end
	end

	template.position_offset = { 0, 0, y_offset }

	refresh_marker_distance(template, breed)

	local check_los = fs.check_line_of_sight

	if template.check_line_of_sight ~= check_los then
		template.check_line_of_sight = check_los
	end

	if breed then
		local root_position = Unit.world_position(unit, 1)

		if root_position then
			root_position.z = root_position.z + breed.base_height + 0.5
			marker.world_position = Vector3Box(root_position)
		end
	end

	EnemyHealthbarTemplate.on_enter(widget, marker, EnemyHealthbarTemplate)

	EnemyMarkersTemplate.on_enter(widget, marker, EnemyMarkersTemplate)

	EnemyDebuffTemplate.on_enter(widget, marker, EnemyDebuffTemplate)
end

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	local next_update = widget._next_update

	if next_update and t < next_update then
		return
	end

	local content = widget.content
	local unit = marker.unit

	if not unit then
		marker.draw = false
		marker.alpha_multiplier = 0
		widget.alpha_multiplier = 0
		marker.remove = true
		return
	end

	if not marker.is_inside_frustum then
		widget._next_update = t + fs.off_screen_throttle_rate
		marker.draw = false
		marker.alpha_multiplier = 0
		widget.alpha_multiplier = 0
		return
	end

	local breed = content.breed
	local distance = marker.distance
	local alive = mod.detect_alive(unit)

	if alive then
		content._ei_dead_at = nil
	else
		content._ei_dead_at = content._ei_dead_at or t
	end

	local dps_visible = fs.hb_show_dps
	local dead_visible = dps_visible or fs.widget_removal_delay > 0

	if not alive and not dead_visible then
		marker.draw = false
		marker.alpha_multiplier = 0
		widget.alpha_multiplier = 0
		return
	end

	local aimed_filter = fs.markers_show_only_aimed
	local tagged_filter = fs.only_tagged_enemies

	local is_aimed = not aimed_filter or mod.aimed_unit[unit]
	local is_tagged = not tagged_filter or mod.tagged_units[unit]

	local passes_visibility_filters = is_aimed and is_tagged

	local saved_next_update = widget._next_update
	local saved_draw = marker.draw

	widget._next_update = 0
	marker.draw = false

	if breed and alive then
		local root_position = Unit.world_position(unit, 1)

		if root_position then
			root_position.z = root_position.z + breed.base_height + 0.5

			local world_position = marker.world_position

			if world_position then
				world_position:store(root_position)
			else
				marker.world_position = Vector3Box(root_position)
			end
		end
	end

	if distance and template.scale_settings and parent._get_scale then
		if marker.ignore_scale then
			marker.scale = 1
		else
			marker.scale = parent:_get_scale(template.scale_settings, distance)
		end
	end

	local initial_scale = marker.scale or 1

	for _, style in pairs(widget.style) do
		if style.default_font_size then
			style.font_size = style.default_font_size * initial_scale
		end
	end

	if fs.healthbar_enable then
		EnemyHealthbarTemplate.update_function(parent, ui_renderer, widget, marker, EnemyHealthbarTemplate, dt, t)
	end

	widget._next_update = 0

	local markers_enabled = fs.markers_enable

	if markers_enabled then
		EnemyMarkersTemplate.update_function(parent, ui_renderer, widget, marker, EnemyMarkersTemplate, dt, t)
	else
		content.m_built = false
	end

	widget._next_update = 0

	local debuffs_enabled = fs.debuff_enable

	local entry = mod.enemy_cache and mod.enemy_cache[unit]
	local breed_name = breed and breed.name
	local breed_type = entry and entry.breed_type

	local individual_state = breed_name and fs.breed_debuff_toggle and fs.breed_debuff_toggle[breed_name]

	local type_state = breed_type and fs.breed_type_debuff_enabled and fs.breed_type_debuff_enabled[breed_type]

	if individual_state == "true_override" or type_state == "true_override" then
		debuffs_enabled = true
	elseif (individual_state == "false_override" or type_state == "false_override") and not fs.force_on_in_training then
		debuffs_enabled = false
	end

	if debuffs_enabled then
		EnemyDebuffTemplate.update_function(parent, ui_renderer, widget, marker, EnemyDebuffTemplate, dt, t)
	else
		content.dbf_built = false
	end

	if saved_next_update and t < saved_next_update then
		widget._next_update = saved_next_update
	elseif distance and distance < 50 then
		widget._next_update = t + fs.general_throttle_rate
	elseif distance and distance < 70 then
		widget._next_update = t + fs.general_throttle_rate * 1.5
	else
		widget._next_update = t + fs.general_throttle_rate * 2
	end

	refresh_marker_distance(template, breed)

	local check_los = fs.check_line_of_sight

	if template.check_line_of_sight ~= check_los then
		template.check_line_of_sight = check_los
	end

	local los = content.line_of_sight_progress or 1

	local has_healthbar = fs.healthbar_enable and (content.hb_built or false) or false

	local has_markers = content.m_built or false

	local active = widget._active

	local has_debuffs = content.dbf_built and debuffs_enabled and active and #active > 0 or false

	if not passes_visibility_filters then
		has_healthbar = false
		has_markers = false
		has_debuffs = false
		dps_visible = false
		dead_visible = false
	end

	local visible = (alive or dead_visible)
			and (saved_draw or has_healthbar or has_markers or has_debuffs or dead_visible)
		or false

	marker.draw = visible

	marker.block_fade_settings = not fs.enable_depth_fading

	if visible and not content._ei_scale_snapped then
		local snap_scale = marker.scale or 1

		for _, pass_style in pairs(widget.style) do
			local default_size = pass_style.default_size

			if default_size then
				local current_size = pass_style.area_size or pass_style.texture_size or pass_style.size

				if current_size then
					current_size[1] = default_size[1] * snap_scale
					current_size[2] = default_size[2] * snap_scale
				end
			end

			local default_offset = pass_style.default_offset

			if default_offset and pass_style.offset then
				pass_style.offset[1] = default_offset[1] * snap_scale
				pass_style.offset[2] = default_offset[2] * snap_scale
			end

			local default_pivot = pass_style.default_pivot

			if default_pivot and pass_style.pivot then
				pass_style.pivot[1] = default_pivot[1] * snap_scale
				pass_style.pivot[2] = default_pivot[2] * snap_scale
			end

			if pass_style.default_font_size then
				pass_style.font_size = pass_style.default_font_size * snap_scale
			end
		end

		content._ei_scale_snapped = true
	elseif not visible then
		content._ei_scale_snapped = false
	end

	local fade_alpha = (fs.enable_depth_fading and marker._ei_fade_alpha) or 1

	if visible then
		widget.alpha_multiplier = los * fade_alpha
		marker.alpha_multiplier = los
	elseif not dead_visible then
		widget.alpha_multiplier = 0
		marker.alpha_multiplier = 0
	end

	local health_extension = ScriptUnit.has_extension(unit, "health_system")
	local is_dead = not health_extension or not health_extension:is_alive()

	if is_dead and not dead_visible then
		marker.alpha_multiplier = 0
		widget.alpha_multiplier = 0
		marker.remove = true
	end
end

mod.ei_template = setmetatable({
	sub = { healthbar = EnemyHealthbarTemplate, markers = EnemyMarkersTemplate, debuffs = EnemyDebuffTemplate },
}, { __index = template })

return template
