local mod = get_mod("enemies_improved")
mod:io_dofile("enemies_improved/scripts/mods/enemies_improved/enemies_improved_localization")
local next = next

-----------------------------------------------------------------------
-- Settings changed
-----------------------------------------------------------------------

-- list of settings to monitor PER enemy type, needs to be updated if more types are added...
-- REQUIRES "_type_" AS THAT IS WHERE THE SPECIFIC ENEMY GROUP NAME IS PLACED...
local enemy_type_settings = {
	["outline_type_enable"] = true,
	["outline_type_colour_R"] = 50,
	["outline_type_colour_G"] = 10,
	["outline_type_colour_B"] = 0,

	["healthbar_type_enable"] = true,
	["healthbar_type_colour_R"] = 255,
	["healthbar_type_colour_G"] = 0,
	["healthbar_type_colour_B"] = 0,

	["healthbar_icon_type_enable"] = true,
	["healthbar_icon_type_scale"] = 1,
	["healthbar_icon_type_glow_intensity"] = 1,
	["healthbar_icon_type_colour_R"] = 200,
	["healthbar_icon_type_colour_G"] = 150,
	["healthbar_icon_type_colour_B"] = 0,

	["reset_type_to_default"] = false,
}

-- REQUIRES "_individual_" AS THAT IS WHERE THE SPECIFIC ENEMY NAME IS PLACED...
local enemy_override_settings = {

	["markers_individual_toggle"] = true,
	["healthbar_individual_enable"] = true,
	["healthbar_individual_colour_R"] = 255,
	["healthbar_individual_colour_G"] = 0,
	["healthbar_individual_colour_B"] = 0,

	["outline_individual_enable"] = false,
	["outline_individual_colour_R"] = 255,
	["outline_individual_colour_G"] = 50,
	["outline_individual_colour_B"] = 10,

	["reset_individual_to_default"] = false,
}

mod.reset_type_to_default = function(enemy_type)
	-- reset all options to nil so that the defaults will be loaded...
	mod:set("healthbar_" .. enemy_type .. "_colour_R", nil)
	mod:set("healthbar_" .. enemy_type .. "_enable", nil)

	mod:set("healthbar_icon_" .. enemy_type .. "_enable", nil)
	mod:set("healthbar_icon_" .. enemy_type .. "_scale", nil)
	mod:set("healthbar_icon_" .. enemy_type .. "_glow_intensity", nil)
	mod:set("healthbar_icon_" .. enemy_type .. "_colour_R", nil)

	mod:set("outline_" .. enemy_type .. "_enable", nil)
	mod:set("outline_" .. enemy_type .. "_colour_R", nil)

	local reset_message = mod:localize("reset_type_to_default_message") or ""
	mod:notify(reset_message:gsub("_type_", "_" .. enemy_type .. "_"))

	mod.init_healthbar_defaults()
end

mod.reset_individual_to_default = function(enemy_type)
	-- reset all options to nil so that the defaults will be loaded...
	mod:set("healthbar_" .. enemy_type .. "_colour_R", nil)

	local reset_message = mod:localize("reset_individual_to_default_message") or ""
	mod:notify(reset_message:gsub("_individual_", "_" .. enemy_type .. "_"))

	mod.init_healthbar_defaults()
end

local BreedQueries = require("scripts/utilities/breed_queries")
local minion_breeds = BreedQueries.minion_breeds_by_name()

mod.init_healthbar_defaults = function()
	-- bar colours
	for breed, color in next, mod.BREED_COLOURS_DEFAULT do
		local r = color[2]
		local g = color[3]
		local b = color[4]

		-- only set if not already saved
		if mod:get("healthbar_" .. breed .. "_colour_R") == nil then
			mod:set("healthbar_" .. breed .. "_colour_R", r)
			mod:set("healthbar_" .. breed .. "_colour_G", g)
			mod:set("healthbar_" .. breed .. "_colour_B", b)
		end
	end

	-- icon settings
	for breed, settings in next, mod.ICON_SETTINGS_DEFAULT do
		if mod:get("healthbar_icon_" .. breed .. "_enable") == nil then
			mod:set("healthbar_icon_" .. breed .. "_enable", settings.enabled)
		end
		if mod:get("healthbar_icon_" .. breed .. "_scale") == nil then
			mod:set("healthbar_icon_" .. breed .. "_scale", settings.scale)
		end
		if mod:get("healthbar_icon_" .. breed .. "_glow_intensity") == nil then
			mod:set("healthbar_icon_" .. breed .. "_glow_intensity", settings.glow_intensity)
		end
	end

	-- icon colours
	for breed, color in next, mod.ICON_COLOURS_DEFAULT do
		local r = color[2]
		local g = color[3]
		local b = color[4]

		-- only set if not already saved
		if mod:get("healthbar_icon_" .. breed .. "_colour_R") == nil then
			mod:set("healthbar_icon_" .. breed .. "_colour_R", r)
			mod:set("healthbar_icon_" .. breed .. "_colour_G", g)
			mod:set("healthbar_icon_" .. breed .. "_colour_B", b)
		end
	end

	-- individual override colours
	for _, options in next, mod.breed_names do
		local enemy_individual = options.value

		if enemy_individual then
			local breed_settings = minion_breeds[enemy_individual]

			if breed_settings then
				local tags = breed_settings.tags
				local breed_type = mod.find_breed_category_by_tags(tags)

				-- healthbar
				for breed, color in next, mod.BREED_COLOURS_DEFAULT do
					if breed_type == breed then
						local r = color[2]
						local g = color[3]
						local b = color[4]

						-- only set if not already saved
						if mod:get("healthbar_" .. enemy_individual .. "_colour_R") == nil then
							mod:set("healthbar_" .. enemy_individual .. "_colour_R", r)
							mod:set("healthbar_" .. enemy_individual .. "_colour_G", g)
							mod:set("healthbar_" .. enemy_individual .. "_colour_B", b)
						end
					end
				end

				-- outlines
				for breed, color in next, mod.OUTLINE_COLOURS_DEFAULT do
					if breed_type == breed then
						local r = color[2]
						local g = color[3]
						local b = color[4]

						-- only set if not already saved
						if mod:get("outline_" .. enemy_individual .. "_colour_R") == nil then
							mod:set("outline_" .. enemy_individual .. "_colour_R", r)
							mod:set("outline_" .. enemy_individual .. "_colour_G", g)
							mod:set("outline_" .. enemy_individual .. "_colour_B", b)
						end
					end
				end
			end
		end
	end
end

mod.update_breed_colours = function()
	-- BREED GROUPS
	for breed, default_color in next, mod.BREED_COLOURS do
		local r = mod:get("healthbar_" .. breed .. "_colour_R")
		local g = mod:get("healthbar_" .. breed .. "_colour_G")
		local b = mod:get("healthbar_" .. breed .. "_colour_B")
		local a = default_color[1] or 255

		if r and g and b then
			mod.BREED_COLOURS[breed] = { a, r, g, b }
		end
	end

	-- INDIVIDUAL HEALTHBAR OVERRIDES
	for _, options in next, mod.breed_names do
		local enemy_individual = options.value

		if enemy_individual then
			local r = mod:get("healthbar_" .. enemy_individual .. "_colour_R")
			local g = mod:get("healthbar_" .. enemy_individual .. "_colour_G")
			local b = mod:get("healthbar_" .. enemy_individual .. "_colour_B")
			local a = 255

			if r and g and b then
				mod.BREED_COLOURS_OVERRIDE[enemy_individual] = { a, r, g, b }
			end
		end
	end

	-- INDIVIDUAL OUTLINE OVERRIDES
	for _, options in next, mod.breed_names do
		local enemy_individual = options.value

		if enemy_individual then
			r = mod:get("outline_" .. enemy_individual .. "_colour_R")
			g = mod:get("outline_" .. enemy_individual .. "_colour_G")
			b = mod:get("outline_" .. enemy_individual .. "_colour_B")
			local a = 255

			if r and g and b then
				mod.OUTLINE_COLOURS_OVERRIDE[enemy_individual] = { a, r, g, b }
			end
		end
	end
end

mod.update_breed_icons = function()
	-- settings
	for breed, settings in next, mod.ICON_SETTINGS do
		local enabled = mod:get("healthbar_icon_" .. breed .. "_enable")
		local scale = mod:get("healthbar_icon_" .. breed .. "_scale")
		local glow_intensity = mod:get("healthbar_icon_" .. breed .. "_glow_intensity")

		mod.ICON_SETTINGS[breed].enabled = enabled
		mod.ICON_SETTINGS[breed].scale = scale
		mod.ICON_SETTINGS[breed].glow_intensity = glow_intensity
		mod.ICON_SETTINGS[breed].default_glow_intensity = glow_intensity
	end

	-- colours
	for breed, default_color in next, mod.ICON_COLOURS do
		local r = mod:get("healthbar_icon_" .. breed .. "_colour_R")
		local g = mod:get("healthbar_icon_" .. breed .. "_colour_G")
		local b = mod:get("healthbar_icon_" .. breed .. "_colour_B")
		local a = default_color[1] or 255

		if r and g and b then
			mod.ICON_COLOURS[breed][1] = a
			mod.ICON_COLOURS[breed][2] = r
			mod.ICON_COLOURS[breed][3] = g
			mod.ICON_COLOURS[breed][4] = b
		end
	end
end

-- set on game load...
mod.load_debuff_colours = function()
	-- colours
	for group_name, style in next, mod.debuff_styles do
		local r = mod:get("debuff_group_" .. group_name .. "_colour_R")
		local g = mod:get("debuff_group_" .. group_name .. "_colour_G")
		local b = mod:get("debuff_group_" .. group_name .. "_colour_B")
		local a = 255

		if style and style.colour and r and g and b then
			style.colour[1] = a
			style.colour[2] = r
			style.colour[3] = g
			style.colour[4] = b
		end
	end
end

-- update ui sliders to current group...
mod.update_debuff_colours = function(group_name)
	mod:set("debuff_group_colour_R", mod.debuff_styles[group_name].colour[2])
	mod:set("debuff_group_colour_G", mod.debuff_styles[group_name].colour[3])
	mod:set("debuff_group_colour_B", mod.debuff_styles[group_name].colour[4])

	mod.update_dmf_settings_colours("debuff_group_colour_R")
end

-- set group specific settings when sliders change...
mod.set_debuff_colours = function(group_name)
	local r = mod:get("debuff_group_colour_R")
	local g = mod:get("debuff_group_colour_G")
	local b = mod:get("debuff_group_colour_B")
	local a = 255

	mod:set("debuff_group_" .. group_name .. "_colour_R", r)
	mod:set("debuff_group_" .. group_name .. "_colour_G", g)
	mod:set("debuff_group_" .. group_name .. "_colour_B", b)

	if mod.debuff_styles[group_name] and r and g and b then
		mod.debuff_styles[group_name].colour[1] = a
		mod.debuff_styles[group_name].colour[2] = r
		mod.debuff_styles[group_name].colour[3] = g
		mod.debuff_styles[group_name].colour[4] = b
	end
end

mod.update_settings_values = function(setting_id)
	-- GROUP OVERRIDES
	local selected_enemy_type = mod:get("enemy_group")
	if not selected_enemy_type then
		return
	end

	local reset_string = "reset_type_to_default"
	local reset_setting_id = reset_string:gsub("_type_", "_" .. selected_enemy_type .. "_")

	-- Set the enemy type widgets when a group is selected
	for setting_name, default_value in next, enemy_type_settings do
		local type_value = mod:get(setting_name)

		local enemy_type = setting_name:gsub("_type_", "_" .. selected_enemy_type .. "_")
		local enemy_type_value = mod:get(enemy_type)

		if enemy_type_value == nil then
			enemy_type_value = default_value
		end

		-- STORE VALUES WHEN CHANGED
		if setting_id == setting_name then
			if enemy_type_value ~= type_value then
				--mod:error("set " .. tostring(enemy_type) .. " to " .. tostring(type_value))
				mod:set(enemy_type, type_value)
			end
		end

		-- SET UI VALUES WHEN DROPDOWN IS SELECTED...
		if setting_id == "enemy_group" or mod:get(reset_setting_id) == true or setting_id == nil then
			if type_value ~= enemy_type_value then
				--mod:error("LOADED VALUES: " .. tostring(setting_name) .. " to " .. tostring(enemy_type_value))
				mod:set(setting_name, enemy_type_value)
			end
		end
	end

	-- INDIVIDUAL OVERRIDES
	local selected_enemy_individual = mod:get("individual_overrides")
	if not selected_enemy_individual then
		return
	end

	local reset_string = "reset_individual_to_default"
	local reset_setting_id = reset_string:gsub("_individual_", "_" .. selected_enemy_individual .. "_")

	-- Set the enemy individual widgets when a new enemy is selected
	for setting_name, default_value in next, enemy_override_settings do
		local individual_value = mod:get(setting_name)

		local enemy_individual = setting_name:gsub("_individual_", "_" .. selected_enemy_individual .. "_")
		local enemy_individual_value = mod:get(enemy_individual)

		if enemy_individual_value == nil then
			enemy_individual_value = default_value
		end

		-- STORE VALUES WHEN CHANGED
		if setting_id == setting_name then
			if enemy_individual_value ~= individual_value then
				--mod:error("set " .. tostring(enemy_individual) .. " to " .. tostring(individual_value))
				mod:set(enemy_individual, individual_value)
			end
		end

		-- SET UI VALUES WHEN DROPDOWN IS SELECTED...
		if setting_id == "individual_overrides" or mod:get(reset_setting_id) == true or setting_id == nil then
			if individual_value ~= enemy_individual_value then
				--mod:error("LOADED VALUES: " .. tostring(setting_name) .. " to " .. tostring(enemy_individual_value))
				mod:set(setting_name, enemy_individual_value)
			end
		end
	end
end

mod.update_dmf_settings_colours = function(setting_id)
	-- Only trigger for color settings
	if
		string.find(setting_id, "_colour_R")
		or string.find(setting_id, "_colour_G")
		or string.find(setting_id, "_colour_B")
	then
		local dmf = get_mod("DMF")
		local mod_name = mod:get_name()

		-- extract base key (e.g. "marker_colour")
		local base_key = string.gsub(setting_id, "_R$", "")
		base_key = string.gsub(base_key, "_G$", "")
		base_key = string.gsub(base_key, "_B$", "")

		local old_title = mod:localize(base_key)
		local new_title = nil

		-- Recompute localization table
		local updated_localization = mod.apply_colours()

		-- GET CURRENT UPDATED VALUE FROM UPDATED_LOCALIZATION
		for id, data in next, updated_localization do
			if id == base_key then
				local lang = Managers.localization:language()
				local text = data[lang] or data.en

				new_title = text
			end
		end

		if not new_title then
			return
		end

		-- OVERRIDE CURRENT DISPLAYED TEXT VALUES ON THE SETTINGS PAGES IN DMF
		for i, mod_data in next, dmf.options_widgets_data do
			if mod_data[1] and mod_data[1].mod_name == mod_name then
				for j = 1, #mod_data do
					if mod_data[j].setting_id == base_key then
						mod_data[j].title = new_title
						break
					end
				end
			end
		end

		local view = Managers.ui:view_instance("dmf_options_view")

		if view and view._settings_category_widgets and view._settings_category_widgets[mod:localize("mod_name")] then
			for _, data in next, view._settings_category_widgets[mod:localize("mod_name")] do
				local widget = data.widget
				if not widget then
					break
				end

				local clean = string.gsub(new_title, "{#.-}", "")
				local clean2 = string.gsub(widget.content.text, "{#.-}", "")

				if clean == clean2 then
					if widget.content.entry then
						widget.content.entry.display_name = new_title
					end
					widget.content.text = new_title
					break
				end
			end
		end
	end
end

mod.update_debuff_toggles = function(debuff_name, toggle_state)
	if toggle_state then
		mod.debuffs[debuff_name] = mod.default_debuffs[debuff_name]
	else
		mod.debuffs[debuff_name] = nil
	end
end

mod.load_toggled_debuffs_state = function()
	for _, debuff in next, mod.default_debuffs do
		local debuff_toggle_setting_string = debuff.name .. "_toggle_state"
		local debuff_setting = mod:get(debuff_toggle_setting_string)

		if debuff_setting ~= nil then
			mod.update_debuff_toggles(debuff.name, debuff_setting)
		end
	end
end

mod.on_setting_changed = function(setting_id)
	local fs = mod.frame_settings

	if setting_id == "debuff_toggles" then
		local selected_option = mod:get("debuff_toggles")
		local debuff_toggle_setting_string = selected_option .. "_toggle_state"
		local setting = mod:get(debuff_toggle_setting_string)

		if setting ~= nil then
			mod:set("debuff_selected_enable", setting)
		else
			mod:set("debuff_selected_enable", true)
		end
	end

	if setting_id == "debuff_selected_enable" then
		local selected_option = mod:get("debuff_toggles")
		local selected_toggle_state = mod:get("debuff_selected_enable")
		local debuff_toggle_setting_string = selected_option .. "_toggle_state"

		mod:set(debuff_toggle_setting_string, selected_toggle_state)

		mod.update_debuff_toggles(selected_option, selected_toggle_state)
	end

	if setting_id == "debuff_group_selected" then
		mod.update_debuff_colours(mod:get("debuff_group_selected"))
	end

	if
		setting_id == "debuff_group_colour_R"
		or setting_id == "debuff_group_colour_G"
		or setting_id == "debuff_group_colour_B"
	then
		mod.set_debuff_colours(mod:get("debuff_group_selected"))
	end
	local selected_enemy_type = mod:get("enemy_group")
	if not selected_enemy_type then
		return
	end

	mod.update_settings_values(setting_id)

	local reset_string = "reset_type_to_default"
	local reset_setting_id = reset_string:gsub("_type_", "_" .. selected_enemy_type .. "_")

	-- HANDLE GROUP RESET TO DEFAULT LOGIC...
	if mod:get(reset_setting_id) == true then
		mod.reset_type_to_default(mod:get("enemy_group"))
		mod.update_settings_values(reset_setting_id)
	end

	local selected_enemy_individual = mod:get("individual_overrides")
	local reset_string_individual = "reset_individual_to_default"
	local reset_setting_id_individual = reset_string:gsub("_individual_", "_" .. selected_enemy_individual .. "_")

	-- HANDLE INDIVIDUAL RESET TO DEFAULT LOGIC...
	if mod:get(reset_setting_id_individual) == true then
		--mod.reset_individual_to_default(selected_enemy_individual)
		--mod.update_settings_values(reset_setting_id_individual)
	end
	mod.update_breed_colours()

	-- rebuild outlines
	local outline_settings = require("scripts/settings/outline/outline_settings")
	mod.apply_enemy_outlines(outline_settings)

	-- update breed settings
	mod.update_breed_icons()

	-- clear all caches to reload data with new values
	mod.clear_caches()

	mod.font_type = mod:get("font_type")
	fs.text_scale = mod:get("text_scale")

	if mod:get(reset_setting_id) == true then
		mod:set(reset_setting_id, false)
	end
	if mod:get(reset_setting_id_individual) == true then
		mod:set(reset_setting_id_individual, false)
	end

	mod.update_settings_values()

	-- update colours when the dropdown selectors are changed...
	if setting_id == "individual_overrides" or setting_id == "enemy_group" then
		-- GROUPS
		if setting_id == "enemy_group" then
			for setting_name, default_value in next, enemy_type_settings do
				mod.update_dmf_settings_colours(setting_name)
			end
		end

		if setting_id == "individual_overrides" then
			for setting_name, default_value in next, enemy_override_settings do
				mod.update_dmf_settings_colours(setting_name)
			end
		end
	end

	mod.update_dmf_settings_colours(setting_id)

	mod.build_frame_settings()
end

-- Rebuilds all enemies improved UI stuff if the settings menu is closed, as by default the UI elements go invisible
mod:hook_safe(CLASS.UIViewHandler, "close_view", function(self, view_name, ...)
	if view_name == "dmf_options_view" or view_name == "options_view" then
		mod.clear_caches()
		mod.build_frame_settings()
	end
end)

--[[
mod.dmf = get_mod("DMF")
mod:hook_safe(mod.dmf, "create_mod_options_settings", function(self, options_templates)
	dbg_self = self
	dbg_opt = options_templates
	for _, setting in ipairs(options_templates.settings or {}) do
		if setting.on_activated then
			local original = setting.on_activated

			setting.on_activated = function(value, ...)
				--mod:error("SETTING RESET: " .. setting.display_name .. tostring(value))
				return original(value, ...)
			end
		end
	end
end)]]
