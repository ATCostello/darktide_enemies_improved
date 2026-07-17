local mod = get_mod("enemies_improved")

local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}
local fs = mod.frame_settings

-- Load sub-templates
local EnemyHealthbarTemplate =
	mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/templates/healthbars/healthbar_template")
local EnemyMarkersTemplate = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/templates/markers_template")
local EnemyDebuffTemplate = mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/templates/debuff_template")
local ScriptUnit_extension = ScriptUnit.extension

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

-- Damage number functions (initialized from healthbar template)
local damage_number_functions =
	mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/templates/healthbars/damage_numbers")
damage_number_functions.init(template)

template.max_visible_rows = 10

template.create_widget_defintion = function(template, scenegraph_id)
	local hb_def = EnemyHealthbarTemplate.create_widget_defintion(EnemyHealthbarTemplate, scenegraph_id)
	local marker_def = EnemyMarkersTemplate.create_widget_defintion(EnemyMarkersTemplate, scenegraph_id)
	local debuff_def = EnemyDebuffTemplate.create_widget_defintion(EnemyDebuffTemplate, scenegraph_id)

	-- Merge content and style tables so all sub-template data is present
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

	-- Merge passes (use add_definition_pass for proper initialization)
	for i = 1, #marker_def.passes do
		UIWidget.add_definition_pass(hb_def, marker_def.passes[i])
	end

	for i = 1, #debuff_def.passes do
		UIWidget.add_definition_pass(hb_def, debuff_def.passes[i])
	end

	-- Debuff icon content entries get filled with DefaultPassValues.texture by
	-- add_definition_pass when no value is provided. Nil them out so the
	-- visibility_function (content[icon_id] ~= nil) returns false until the
	-- update function populates them with real icon materials.
	for i = 1, template.max_visible_rows do
		hb_def.content["debuff_icon_" .. i] = nil
	end

	return hb_def
end

template.on_enter = function(widget, marker, template)
	local content = widget.content

	local unit = marker.unit
	local unit_data_extension = ScriptUnit_extension(unit, "unit_data_system")
	local breed = unit_data_extension and unit_data_extension:breed()

	local y_offset = fs.hb_y_offset

	if breed then
		local breed_name = breed.name
		local breed_type = mod.find_breed_category(unit)

		if
			breed_name
			and fs.breed_healthbar_y_offset_enabled[breed_name]
			and fs.breed_healthbar_y_offset[breed_name]
		then
			y_offset = fs.breed_healthbar_y_offset[breed_name]
		elseif
			breed_type
			and fs.breed_type_healthbar_y_offset_enabled[breed_type]
			and fs.breed_type_healthbar_y_offset[breed_type]
		then
			y_offset = fs.breed_type_healthbar_y_offset[breed_type]
		end
	end

	template.position_offset = { 0, 0, y_offset }
	template.max_distance = fs.draw_distance_broadphase or fs.draw_distance
	template.check_line_of_sight = fs.check_line_of_sight

	if content.breed then
		local root_position = Unit.world_position(unit, 1)

		if root_position then
			root_position.z = root_position.z + content.breed.base_height + 0.5

			if not marker.world_position then
				marker.world_position = Vector3Box(root_position)
			else
				marker.world_position:store(root_position)
			end
		end
	end

	EnemyHealthbarTemplate.on_enter(widget, marker, EnemyHealthbarTemplate)

	EnemyMarkersTemplate.on_enter(widget, marker, EnemyMarkersTemplate)

	EnemyDebuffTemplate.on_enter(widget, marker, EnemyDebuffTemplate)
end

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	widget._next_update = widget._next_update or 0
	if t < widget._next_update then
		return
	end

	if not marker.is_inside_frustum then
		widget._next_update = t + fs.off_screen_throttle_rate
		marker.draw = false
		marker.alpha_multiplier = 0
		widget.alpha_multiplier = 0
	end

	-- Global aimed-only filter: hides ALL enemies_improved content
	local unit = marker.unit
	if not unit then
		marker.draw = false
		marker.alpha_multiplier = 0
		widget.alpha_multiplier = 0
		return
	end

	local is_alive = mod.detect_alive(unit)

	if not is_alive then
		marker.draw = false
		marker.alpha_multiplier = 0
		widget.alpha_multiplier = 0
		return
	end

	if fs.markers_show_only_aimed and unit and not mod.aimed_unit[unit] then
		marker.draw = false
		marker.alpha_multiplier = 0
		widget.alpha_multiplier = 0
	end

	-- Global tagged-only filter: hides ALL enemies_improved content for non-tagged enemies
	if fs.only_tagged_enemies and unit and not mod.tagged_units[unit] then
		marker.draw = false
		marker.alpha_multiplier = 0
		widget.alpha_multiplier = 0
	end

	-- Sub-templates check widget._next_update and marker.draw internally.
	-- Save and force them so all three run their full logic this frame.
	local saved_next_update = widget._next_update
	local saved_draw = marker.draw
	widget._next_update = 0
	marker.draw = true

	local content = widget.content

	if content.breed and mod.detect_alive(unit) then
		local root_position = Unit.world_position(unit, 1)
		root_position.z = root_position.z + content.breed.base_height + 0.5

		if not marker.world_position then
			marker.world_position = Vector3Box(root_position)
		else
			marker.world_position:store(root_position)
		end
	end

	-- Skip sub-templates when their global toggle is off.
	EnemyHealthbarTemplate.update_function(parent, ui_renderer, widget, marker, EnemyHealthbarTemplate, dt, t)

	widget._next_update = 0

	-- Markers: global toggle or per-breed individual override.
	local markers_enabled = fs.markers_enable

	if markers_enabled then
		EnemyMarkersTemplate.update_function(parent, ui_renderer, widget, marker, EnemyMarkersTemplate, dt, t)
	else
		content.m_built = false
	end

	widget._next_update = 0

	local debuffs_enabled = fs.debuff_enable

	if content.breed then
		if fs and fs.breed_debuff_toggle and fs.breed_debuff_toggle[content.breed.name] then
			debuffs_enabled = fs.breed_debuff_toggle[content.breed.name]
		end
	end

	if debuffs_enabled then
		EnemyDebuffTemplate.update_function(parent, ui_renderer, widget, marker, EnemyDebuffTemplate, dt, t)
	else
		content.dbf_built = false
	end

	-- Throttle: restore or compute the next update time.
	if saved_next_update and t < saved_next_update then
		widget._next_update = saved_next_update
	elseif marker.distance < 50 then
		widget._next_update = t + fs.general_throttle_rate
	elseif marker.distance < 70 then
		widget._next_update = t + fs.general_throttle_rate * 1.5
	else
		widget._next_update = t + fs.general_throttle_rate * 2
	end

	template.max_distance = fs.draw_distance_broadphase or fs.draw_distance
	template.check_line_of_sight = fs.check_line_of_sight

	-- Debuffs sets alpha_multiplier=0 + early-returns when no debuffs present.
	-- Save line_of_sight_progress so final state is consistent regardless of debuff count.
	local los = content.line_of_sight_progress or 1

	local has_healthbar = fs.healthbar_enable and (content.hb_built or false) or false
	local has_markers = content.m_built or false
	local has_debuffs = content.dbf_built and fs.debuff_enable and widget._active and #widget._active > 0 or false
	local dps_visible = fs.hb_show_dps and content.dead

	-- Re-apply aimed filter after sub-templates: suppress their results for non-aimed units
	if fs.markers_show_only_aimed and unit and not mod.aimed_unit[unit] then
		has_healthbar = false
		has_markers = false
		has_debuffs = false
		dps_visible = false
	end

	-- Re-apply tagged filter after sub-templates: suppress their results for non-tagged units
	if fs.only_tagged_enemies and unit and not mod.tagged_units[unit] then
		has_healthbar = false
		has_markers = false
		has_debuffs = false
		dps_visible = false
	end

	local visible = (mod.detect_alive(unit) or dps_visible)
			and (saved_draw or has_healthbar or has_markers or has_debuffs or dps_visible)
		or false

	marker.draw = visible

	if visible then
		widget.alpha_multiplier = los
		marker.alpha_multiplier = los
	elseif not fs.hb_show_dps then
		widget.alpha_multiplier = 0
		marker.alpha_multiplier = 0
	end

	local unit = marker.unit
	local health_extension = ScriptUnit.has_extension(unit, "health_system")
	local is_dead = not health_extension or not health_extension:is_alive()

	if is_dead and not fs.hb_show_dps then
		marker.alpha_multiplier = 0
		widget.alpha_multiplier = 0
		marker.remove = true
	end
end

return template
