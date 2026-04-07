local mod = get_mod("enemies_improved")
mod.version = "1.0test2"
mod:info("Enemies Improved is installed, using version: " .. tostring(mod.version))

local colours = {
	title = "200,140,20",
	subtitle = "226,199,126",
	text = "169,191,153",
}

-- Always use an updated font list.
-- Thanks to GideonAriphael on Nexusmods for recommendation
mod._get_font_options = function()
	local FontDefinitions = require("scripts/managers/ui/ui_fonts_definitions")
	local fonts = FontDefinitions.fonts or {}
	local options = {}
	local i = 1

	for font_name, _ in pairs(fonts) do
		options[i] = { text = font_name, value = font_name }
		i = i + 1
	end

	-- Sort alphabetically by the underlying font name for consistency
	table.sort(options, function(a, b)
		return a.value < b.value
	end)

	return options
end

-- function to apply font face to localisation text
local apply_font_to_text = function(text, font_name)
	return string.format("{#font(%s)}%s{#reset()}", font_name, text)
end

local insert_fonts = function(localisation_table)
	local fonts_data = mod._get_font_options()

	for _, data in pairs(fonts_data) do
		-- Convert snake_case to Title Case for display (e.g. proxima_nova_bold -> Proxima Nova Bold)
		local readable = data.text:gsub("_", " "):gsub("(%a)([%w]*)", function(first, rest)
			return first:upper() .. rest
		end)

		local text = string.format("%s", readable)

		local new_localised_readable_text = {
			en = apply_font_to_text(text, data.value),
		}
		localisation_table[data.value] = new_localised_readable_text
	end
end

-- base localisations
mod.localisation = {
	mod_name = {
		en = "{#color("
			.. colours.title
			.. ")} {#color(255,0,0)}E{#color(248,0,14)}n{#color(240,0,29)}e{#color(233,0,43)}m{#color(225,0,57)}i{#color(218,0,71)}e{#color(210,0,86)}s {#color(203,0,100)}I{#color(195,0,114)}m{#color(188,0,129)}p{#color(180,0,143)}r{#color(173,0,157)}o{#color(165,0,171)}v{#color(158,0,186)}e{#color(150,0,200)}d{#reset()}",
	},
	mod_description = {
		en = "{#color("
			.. colours.text
			.. ")}"
			.. "Healthbars, debuffs, outlines, markers, special attack alerts and more, to improve the enemies throughout Darktide."
			.. "{#reset()}\n\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Author: "
			.. "{#color("
			.. colours.text
			.. ")}Alfthebigheaded\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Version: {#color("
			.. colours.text
			.. ")}"
			.. mod.version
			.. "{#reset()}",
	},
}

-- Group localisations so they can be managed easier.
local localisations_to_add = {}

-- debuff name localisations
table.insert(localisations_to_add, {
	-- Debuffs Localisation
	bleed = {
		en = "Bleed",
	},
	flamer_assault = {
		en = "Burning",
	},
	warp_fire = {
		en = "Warpfire",
	},
	neurotoxin_interval_buff = {
		en = "Neurotoxin",
	},
	neurotoxin_interval_buff2 = {
		en = "Neurotoxin II",
	},
	neurotoxin_interval_buff3 = {
		en = "Neurotoxin III",
	},
	exploding_toxin_interval_buff = {
		en = "Exploding Toxin",
	},

	psyker_discharge_damage_debuff = {
		en = "Discharge",
	},
	psyker_force_staff_quick_attack_debuff = {
		en = "Warpfire Brand",
	},

	toxin_damage_debuff = {
		en = "Toxin",
	},
	toxin_damage_debuff_monster = {
		en = "Toxin (Elite)",
	},

	-- Rending / “take more damage”, tags, etc.
	rending_debuff = {
		en = "Rending",
	},
	increase_impact_received_while_staggered = {
		en = "Increased Impact Taken",
	},
	increase_damage_received_while_staggered = {
		en = "Increased Damage Taken (Staggered)",
	},
	power_maul_sticky_tick = {
		en = "Power Maul Impact",
	},
	increase_damage_taken = {
		en = "Increased Damage Taken",
	},

	-- Psyker utility / chain lightning etc.
	psyker_protectorate_spread_chain_lightning_interval_improved = {
		en = "Chain Lightning",
	},
	psyker_protectorate_spread_charged_chain_lightning_interval_improved = {
		en = "Charged Chain Lightning",
	},

	-- Ogryn
	ogryn_recieve_damage_taken_increase_debuff = {
		en = "Softened Up",
	},
	ogryn_taunt_increased_damage_taken_buff = {
		en = "Taunted",
	},
	ogryn_staggering_damage_taken_increase = {
		en = "Staggering Blows",
	},

	-- Veteran
	veteran_improved_tag_debuff = {
		en = "Tagged Target",
	},

	-- Zealot
	zealot_bled_enemies_take_more_damage_effect = {
		en = "Bled for the Emperor",
	},

	-- Arbite
	adamant_drone_enemy_debuff = {
		en = "Drone Marked",
	},
	adamant_drone_talent_debuff = {
		en = "Drone Suppressed",
	},
	adamant_melee_weakspot_hits_count_as_stagger_debuff = {
		en = "Weakspot Stagger",
	},
	adamant_staggered_enemies_deal_less_damage_debuff = {
		en = "Weakened Strikes",
	},
	adamant_staggering_increases_damage_taken = {
		en = "Stagger Vulnerability",
	},

	-- Broker
	broker_punk_rage_improved_shout_debuff = {
		en = "Rage Shout",
	},
})

-- enemy type localisations
table.insert(localisations_to_add, {
	["SELECT AN ENEMY TYPE"] = {
		en = "SELECT AN ENEMY TYPE",
	},
	select = {
		en = "SELECT AN ENEMY TYPE",
	},
	monster = {
		en = "miniboss",
	},
	captain = {
		en = "boss",
	},
	disabler = {
		en = "disabler",
	},
	witch = {
		en = "daemonhost",
	},
	sniper = {
		en = "sniper",
	},
	far = {
		en = "ranged elite",
	},
	elite = {
		en = "melee elite",
	},
	special = {
		en = "special",
	},
	horde = {
		en = "horde",
	},
	enemy = {
		en = "ritualist",
	},
})

-- damage  number type localisations
table.insert(localisations_to_add, {
	readable = {
		en = "Readable",
	},
	floating = {
		en = "floating",
	},
	flashy = {
		en = "flashy",
	},
})

-- general settings localisations
table.insert(localisations_to_add, {
	general_settings = {
		en = "{#color(" .. colours.title .. ")}General Settings{#reset()}",
	},
	draw_distance = {
		en = "Draw Distance (Global)",
	},
	draw_distance_tooltip = {
		en = "The distance (in Metres) from the player to draw enemy information.\nThis setting is global and will effect all enemy types.",
	},
	global_opacity = {
		en = "Global Opacity",
	},
	global_opacity_tooltip = {
		en = "Set a global opacity slider for Enemies Improved UI elements. This will scale the opacity of all elements from their max (1) to their minimal value (0.1).",
	},
	enable_depth_fading = {
		en = "Distance Fading?",
	},
	enable_depth_fading_tooltip = {
		en = "Toggle distance fading for all Enemies Improved UI elements, so that enemies far away will be more transparent than closer ones. Also includes 'stack fading' which fades out UI elements for enemies that are behind other enemies, so that the closer enemy is easier to see.",
	},
	check_line_of_sight = {
		en = "Check for line of sight?",
	},
	check_line_of_sight_tooltip = {
		en = "Require line of sight checks for enemies?",
	},
	outlines_enable = {
		en = "Enable Outlines (Global)",
	},
	outlines_enable_tooltip = {
		en = "Global toggle for outlines of enemies. Specific enemy types may be disabled or configured further below.",
	},
	font_type = {
		en = "Choose a font style (Global)",
	},
	font_type_tooltip = {
		en = "The global font style to use. This will apply to all text elements from Enemies Improved.",
	},
	text_scale = {
		en = "Scale the text sizes (Global)",
	},
	text_scale_tooltip = {
		en = "A global scale that applies to ALL text used in Enemies Improved. Think of this is an 'x' scaler. E.g. a value of 1.2 is 1.2x the font sizes. ",
	},
	main_font_colour = {
		en = "Colour for main text font (Global)",
	},
	main_font_colour_R = {
		en = "Main Font: Red",
	},
	main_font_colour_G = {
		en = "Main Font: Green",
	},
	main_font_colour_B = {
		en = "Main Font: Blue",
	},
	secondary_font_colour_tooltip = {
		en = "Pick a colour to apply as the 'secondary' font colour throughout enemies improved elements.",
	},
	secondary_font_colour = {
		en = "Colour for secondary text font (Global)",
	},
	secondary_font_colour_R = {
		en = "Main Font: Red",
	},
	secondary_font_colour_G = {
		en = "Main Font: Green",
	},
	secondary_font_colour_B = {
		en = "Main Font: Blue",
	},
	secondary_font_colour_tooltip = {
		en = "Pick a colour to apply as the 'secondary' font colour throughout enemies improved elements.",
	},
})

-- special attacks settings localisations
table.insert(localisations_to_add, {
	special_attack_settings = {
		en = "{#color(" .. colours.title .. ")}Special Attacks{#reset()}",
	},
	marker_specials_enable = {
		en = "Toggle overhead markers special attack indicators (Global)",
	},
	marker_specials_enable_tooltip = {
		en = "Affects only 'Enemy Overhead Markers'. \nApplies a pulsating effect when a special attack is detected, to help you get out of the way!",
	},
	outline_specials_enable = {
		en = "Toggle enemy outline special attack indicators (Global)",
	},
	outline_specials_enable_tooltip = {
		en = "Applies an outline effect when a special attack is detected, to help distinguish a 'special attack' enemy from a crowd.",
	},
	healthbar_specials_enable = {
		en = "Toggle healthbar special attack indicators (Global)",
	},
	healthbar_specials_enable_tooltip = {
		en = "Toggle special attack indicators on the healthbar. \nApplies a pulsating effect when a special attack is detected, to help you get out of the way!",
	},
	specials_flash = {
		en = "Enable flashing for special attacks (Global)",
	},
	specials_flash_tooltip = {
		en = "Applies a flashing effect to the special attack indicators. \n\nDisable for a solid colour instead.",
	},
	outline_specials_colour = {
		en = "Colour for special attacks (Global)",
	},
	outline_specials_colour_tooltip = {
		en = "Adjust the colour to apply to all indicators for special attacks.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all. Check an RGB calculator to help pick exact colours.",
	},
	outline_specials_colour_R = {
		en = "Special Attack Colour: Red",
	},
	outline_specials_colour_G = {
		en = "Special Attack Colour: Green",
	},
	outline_specials_colour_B = {
		en = "Special Attack Colour: Blue",
	},
})

-- Overhead Enemy Markers settings
table.insert(localisations_to_add, {
	markers_settings = {
		en = "{#color(" .. colours.title .. ")}Enemy Overhead Markers{#reset()}",
	},
	markers_enable = {
		en = "Enable Overhead Markers?",
	},
	markers_enable_tooltip = {
		en = "Toggles a diamond shape overhead marker for enemies, which can be used to help pin-point specific enemy locations from afar or in a group.",
	},
	markers_horde_enable = {
		en = "Enable Overhead Markers for horde enemies?",
	},
	markers_horde_enable_tooltip = {
		en = "Enables the overhead marker for horde enemies, such as poxwalkers.",
	},
})

-- Healthbar settings
table.insert(localisations_to_add, {
	healthbar_settings = {
		en = "{#color(" .. colours.title .. ")}Healthbars{#reset()}",
	},
	healthbar_text_settings = {
		en = "{#color(" .. colours.title .. ")}Healthbar Text Options{#reset()}",
	},
	healthbar_enable = {
		en = "Enable Healthbars? (Global)",
	},
	healthbar_enable_tooltip = {
		en = "Globally toggles healthbars for enemies. Specific enemy types can be enabled/disabled further below.",
	},
	healthbar_type_icon_enable = {
		en = "Enable healthbar enemy type icon?",
	},
	healthbar_type_icon_enable_tooltip = {
		en = "Toggles a class-based icon next to the healthbar as an option to track enemy types from afar.",
	},
	hb_padding_scale = {
		en = "Scale for the decorative frame around the healthbar (Global)",
	},
	hb_padding_scale_tooltip = {
		en = "A global scale for the decorative frame element around the enemies current health.\n\n1 = Default\n2 = 2x size ",
	},
	hb_text_top_left_01 = {
		en = "Above Healthbar Text option",
	},
	hb_text_top_left_01_tooltip = {
		en = "Pick a text option to display in the text slot above the healthbar.\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}"
			.. "Enemy Type: {#reset()}Displays the class/category of this enemy. e.g. Elite, Specialist etc.\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}"
			.. "Enemy Name: {#reset()}Displays the name of the enemy. e.g. Crusher, Poxwalker etc.\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}"
			.. "Armour Type: {#reset()}Display the previously hit armour zone type e.g. Carapace, Flak etc.",
	},
	hb_text_bottom_left_01 = {
		en = "Below Healthbar Text option 1",
	},
	hb_text_bottom_left_01_tooltip = {
		en = "Pick a text option to display in the text slot below the healthbar.\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}"
			.. "Enemy Type: {#reset()}Displays the class/category of this enemy. e.g. Elite, Specialist etc.\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}"
			.. "Enemy Name: {#reset()}Displays the name of the enemy. e.g. Crusher, Poxwalker etc.\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}"
			.. "Armour Type: {#reset()}Display the previously hit armour zone type e.g. Carapace, Flak etc.",
	},
	hb_text_bottom_left_02 = {
		en = "Below Healthbar Text option 2",
	},
	hb_text_bottom_left_02_tooltip = {
		en = "Pick a text option to display in the second text slot below the healthbar.\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}"
			.. "Enemy Type: {#reset()}Displays the class/category of this enemy. e.g. Elite, Specialist etc.\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}"
			.. "Enemy Name: {#reset()}Displays the name of the enemy. e.g. Crusher, Poxwalker etc.\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}"
			.. "Armour Type: {#reset()}Display the previously hit armour zone type e.g. Carapace, Flak etc.",
	},
	enemy_type = {
		en = "Enemy Type",
	},
	enemy_name = {
		en = "Name",
	},
	armour_type = {
		en = "Armour Type",
	},
	health = {
		en = "Current Health",
	},
	nothing = {
		en = "Don't Show",
	},
	hb_horde_enable = {
		en = "Enable individual healthbars on horde enemies?",
	},
	hb_horde_enable_tooltip = {
		en = "Toggles individual healthbars for horde enemies.",
	},
	hb_horde_clusters_enable = {
		en = "Cluster horde healthbars?",
	},
	hb_horde_clusters_enable_tooltip = {
		en = "Toggles clustered healthbars for horde enemies.\nThis works when there is a large gathering of 'horde' type enemies in close proximity.\n\nTheir healthbar will combine into one large healthbar and follow around the horde.",
	},
	hb_hide_after_no_damage = {
		en = "Hide healthbars after no damage received?",
	},
	hb_hide_after_no_damage_tooltip = {
		en = "Toggle hiding of healthbars after a short delay of no damage taken. Can be used to reduce visual clutter.\n\nIf disabled, healthbars will always be visible.",
	},
	hb_show_damage_numbers = {
		en = "Show floating damage numbers?",
	},
	hb_show_damage_numbers_tooltip = {
		en = "Toggles damage numbers when attacking enemies showing how much damage you are dealing.\n\nSee 'Floating damage type' for more options.",
	},
	hb_text_show_health = {
		en = "Show current health on healthbar?",
	},
	hb_text_show_damage_tooltip = {
		en = "Toggles a text-based indicator near the healthbar showing the current health and max health.",
	},
	hb_text_show_damage = {
		en = "Show current damage next to health?",
	},
	hb_text_show_damage_tooltip = {
		en = "Toggles a text-based indicator alongside the current/max health displaying current damage received.",
	},
	hb_damage_number_types = {
		en = "Floating damage type",
	},
	hb_damage_number_types_tooltip = {
		en = "Options for the varying forms of damage numbers.\n\nTry them out in the range to see which one suits you best!",
	},
	hb_show_armour_types = {
		en = "Show armour type",
	},
	hb_show_armour_types_tooltip = {
		en = "Toggles a text-based indicator near the healthbar showing the type of armour you hit when damaging enemies.\n\nCan be useful to see what weapons to use.",
	},
	hb_frame = {
		en = "Healthbar background frame",
	},
	hb_frame_tooltip = {
		en = "A section of frames that are used as a background for the healthbars.\n\nTry them out to see the difference.",
	},
	hb_size_width = {
		en = "Healthbar width",
	},
	hb_size_width_tooltip = {
		en = "The max width of the healthbar.\n\nThe information scales with this too, so try different sizes to see what suits you best.",
	},
	hb_size_height = {
		en = "Healthbar height",
	},
	hb_size_height_tooltip = {
		en = "The max height of the healthbar.\n\nThe information scales with this too, so try different sizes to see what suits you best.",
	},
})

-- Debuff settings
table.insert(localisations_to_add, {
	debuff_settings = {
		en = "{#color(" .. colours.title .. ")}Debuffs{#reset()}",
	},
	debuff_enable = {
		en = "Enable debuffs (Global)",
	},
	debuff_enable_tooltip = {
		en = "Global toggle for debuff display.\n\nDebuffs are grouped into two categories, Damage over Time (DoT) and Utility. DoT debuffs are displayed upwards, whereas utility debuffs display downwards.\n\nDoT debuffs include things like bleeding, fire, electricity. Whereas utility includes rending, talent debuffs etc.",
	},
	debuff_dot_enable = {
		en = "Enable Damage-Over-Time debuffs",
	},
	debuff_dot_enable_tooltip = {
		en = "DoT debuffs are displayed upwards and include things like bleeding, fire, electricity.",
	},
	debuff_utility_enable = {
		en = "Enable Utility debuffs",
	},
	debuff_utility_enable_tooltip = {
		en = "Utility debuffs are displayed downwards and include things like rending, damage increases, weakening.",
	},
	debuff_names = {
		en = "Show debuff names",
	},
	debuff_names_tooltip = {
		en = "Toggles a text display of different debuffs applied to enemies.",
	},
	debuff_names_fade = {
		en = "Fade out debuffs",
	},
	debuff_names_fade_tooltip = {
		en = "Toggles fading out of the text-based debuff names after a short delay.\n\nIf this is disabled, debuff names will always show when applied.",
	},
	debuff_show_on_body = {
		en = "Show debuffs on body of enemy?",
	},
	debuff_show_on_body_tooltip = {
		en = "Toggles positioning of the debuff tracker.\n\nIf enabled, the debuffs will be displays in the middle of the enemy model, allowing for easier tracking - but may get in the way.\n\nIf disabled, the debuffs will be placed alongside the healthbar above the head of the enemy.",
	},
	debuff_horde_enable = {
		en = "Enable debuffs for horde enemies?",
	},
	debuff_horde_enable_tooltip = {
		en = "Toggle to show debuffs for horde enemies.",
	},
})

-- Group settings
table.insert(localisations_to_add, {
	group_settings = {
		en = "{#color(" .. colours.title .. ")}All below settings apply ONLY to the selected enemy type{#reset()}",
	},
	enemy_group = {
		en = "Selected Enemy Type",
	},
	enemy_group_tooltip = {
		en = "Select an enemy type/class here to adjust their specific settings below.\n\nEnemy types can be seen on the healthbar with the 'Display enemy type' toggle enabled.",
	},
	reset_type_to_default_message = {
		en = "Reset settings for type '_type_' to default.",
	},
	reset_type_to_default = {
		en = "{#color(" .. colours.subtitle .. ")}Warning: {#reset()}Reset to defaults",
	},
	reset_type_to_default_tooltip = {
		en = "Reset all enemy type specific settings to their default values.\n\nNote: This only affects the enemy type selected above.",
	},

	-- outlines
	outline_type_enable = {
		en = "Enable outline?",
	},
	outline_type_enable_tooltip = {
		en = "Toggle outlines for your selected enemy type/class",
	},

	outline_type_colour = {
		en = "Outline colour (Enemy Type Specific)",
	},
	outline_type_colour_tooltip = {
		en = "Adjust the colour of the enemy type specific outline.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all. Check an RGB calculator to help pick exact colours.",
	},

	outline_type_colour_R = {
		en = "Outline Colour: Red",
	},
	outline_type_colour_G = {
		en = "Outline Colour: Green",
	},
	outline_type_colour_B = {
		en = "Outline Colour: Blue",
	},

	-- healthbars
	healthbar_type_enable = {
		en = "Enable healthbars?",
	},
	healthbar_type_enable_tooltip = {
		en = "Toggle healthbars for your selected enemy type/class",
	},
	healthbar_type_colour = {
		en = "Healthbar colour (Enemy Type Specific)",
	},
	healthbar_type_colour_tooltip = {
		en = "Adjust the colour of the enemy type specific healthbar's current health value.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all. Check an RGB calculator to help pick exact colours.",
	},
	healthbar_type_colour_R = {
		en = "Healthbar Colour: Red",
	},
	healthbar_type_colour_G = {
		en = "Healthbar Colour: Green",
	},
	healthbar_type_colour_B = {
		en = "Healthbar Colour: Blue",
	},

	healthbar_icon_type_enable = {
		en = "Enable enemy type icons?",
	},
	healthbar_icon_type_enable_tooltip = {
		en = "Toggle icon indicators for your selected enemy type/class.",
	},
	healthbar_icon_type_scale = {
		en = "Type icon scale",
	},
	healthbar_icon_type_scale_tooltip = {
		en = "Set the scale of the enemy type icons. 1 being 1x scale.",
	},
	healthbar_icon_type_glow_intensity = {
		en = "Type icon glow intensity",
	},
	healthbar_icon_type_glow_intensity_tooltip = {
		en = "Set the intensity of the glow.\n\n0 = Off\n100 = Max intensity",
	},
	healthbar_icon_type_colour = {
		en = "Healthbar Icon Colour",
	},
	healthbar_icon_type_colour_R = {
		en = "Type Icon Colour: Red",
	},
	healthbar_icon_type_colour_G = {
		en = "Type Icon Colour: Green",
	},
	healthbar_icon_type_colour_B = {
		en = "Type Icon Colour: Blue",
	},
	healthbar_icon_type_colour_tooltip = {
		en = "Adjust the colour of the enemy type specific icon.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all. Check an RGB calculator to help pick exact colours.",
	},
})

-- add localisations to main map
for i = 1, #localisations_to_add do
	if localisations_to_add[i] then
		for key, value in pairs(localisations_to_add[i]) do
			if key and value then
				mod.localisation[key] = value
			end
		end
	end
end

local apply_color_to_text = function(text, r, g, b)
	return "{#color(" .. r .. "," .. g .. "," .. b .. ")}" .. text .. "{#reset()}"
end

local apply_colours = function()
	for key, values in pairs(mod.localisation) do
		-- apply rgb colours
		if
			string.find(key, "colour")
			and not string.find(key, "colour_R")
			and not string.find(key, "colour_G")
			and not string.find(key, "colour_B")
		then
			local r = mod:get(key .. "_R")
			local g = mod:get(key .. "_G")
			local b = mod:get(key .. "_B")

			if r ~= nil and g ~= nil and b ~= nil then
				for language, text in pairs(values) do
					local clean = string.gsub(text, "{#.-}", "")
					clean = string.gsub(clean, "{#reset%(%)%}", "")
					text = apply_color_to_text(clean, r, g, b)

					mod.localisation[key][language] = text
				end
			end
		end

		-- apply border colours
		if key == "Gold" or key == "Silver" or key == "Steel" or key == "Tarnished" then
			for language, text in pairs(values) do
				local argb = mod.lookup_border_color(key)

				if argb ~= nil then
					local temp = apply_color_to_text(key, argb[2], argb[3], argb[4])

					if mod.localisation[temp] == nil then
						mod.localisation[temp] = {}
						mod.localisation[temp][language] = temp
					else
						mod.localisation[temp][language] = temp
					end
				end
			end
		end

		-- adjust tooltip text opacity
		if string.find(key, "_tooltip") then
			for language, text in pairs(values) do
				local rgb = { 144, 155, 136 }

				if rgb ~= nil then
					local text = apply_color_to_text(text, rgb[1], rgb[2], rgb[3])

					if mod.localisation[key] == nil then
						mod.localisation[key] = {}
						mod.localisation[key][language] = text
					else
						mod.localisation[key][language] = text
					end
				end
			end
		end
	end

	return mod.localisation
end

-- Insert font localisation
insert_fonts(mod.localisation)

apply_colours()

mod.apply_colours = function()
	apply_colours()
	return mod.localisation
end

return mod.localisation
