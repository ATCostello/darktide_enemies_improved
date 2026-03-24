local mod = get_mod("enemy_markers")

-- base localisations
mod.localisation = {
	mod_name = {
		en = "Enemy Markers, Healthbars and Debuffs Improved",
	},
	mod_description = {
		en = "Adds markers, healthbars and debuff indicators to enemies in an optimised, customisable fashion.",
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
		en = "monster",
	},
	captain = {
		en = "captain",
	},
	disabler = {
		en = "disabler",
	},
	witch = {
		en = "witch",
	},
	sniper = {
		en = "sniper",
	},
	far = {
		en = "far",
	},
	elite = {
		en = "elite",
	},
	special = {
		en = "special",
	},
	horde = {
		en = "horde",
	},
	enemy = {
		en = "enemy",
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
		en = "General Settings",
	},
	draw_distance = {
		en = "Draw Distance (Global)",
	},
	outlines_enable = {
		en = "Enable Outlines (Global)",
	},
	font_type = {
		en = "Choose a font style (Global)",
	},
})

-- special attacks settings localisations
table.insert(localisations_to_add, {
	special_attack_settings = {
		en = "Special Attacks",
	},
	marker_specials_enable = {
		en = "Enable marker 'ping' on special attack (Global)",
	},
	outline_specials_enable = {
		en = "Enable enemy outline on special attack (Global)",
	},
	outline_specials_flash = {
		en = "Enable flash for outline (Global)",
	},
	outline_specials_colour = {
		en = "Colour for special attack outline (Global)",
	},
	outline_specials_colour_R = {
		en = "Red",
	},
	outline_specials_colour_G = {
		en = "Green",
	},
	outline_specials_colour_B = {
		en = "Blue",
	},
})

-- Overhead Enemy Markers settings
table.insert(localisations_to_add, {
	markers_settings = {
		en = "Enemy Overhead Markers",
	},
	markers_enable = {
		en = "Enable Overhead Markers?",
	},
	markers_horde_enable = {
		en = "Enable Overhead Markers for horde enemies?",
	},
})

-- Healthbar settings
table.insert(localisations_to_add, {
	healthbar_settings = {
		en = "Healthbars",
	},
	healthbar_enable = {
		en = "Enable Healthbars? (Global)",
	},
	healthbar_type_icon_enable = {
		en = "Enable healthbar enemy type icon?",
	},
	hb_show_enemy_type = {
		en = "Display enemy type?",
	},
	hb_horde_enable = {
		en = "Enable healthbars on horde enemies?",
	},
	hb_horde_clusters_enable = {
		en = "Cluster horde healthbars?",
	},
	hb_hide_after_no_damage = {
		en = "Hide healthbars after no damage received?",
	},
	hb_show_damage_numbers = {
		en = "Show floating damage numbers?",
	},
	hb_text_show_damage = {
		en = "Show current health on healthbar?",
	},
	hb_damage_number_types = {
		en = "Floating damage type",
	},
	hb_show_armour_types = {
		en = "Show armour type",
	},
	hb_frame = {
		en = "Healthbar background frame",
	},
	hb_size_width = {
		en = "Healthbar width",
	},
	hb_size_height = {
		en = "Healthbar height",
	},
})

-- Debuff settings
table.insert(localisations_to_add, {
	debuff_settings = {
		en = "Debuffs",
	},
	debuff_enable = {
		en = "Enable debuffs",
	},
	debuff_names = {
		en = "Show debuff names",
	},
	debuff_names_fade = {
		en = "Fade out debuffs",
	},
	debuff_show_on_body = {
		en = "Show debuffs on body of enemy?",
	},
	debuff_horde_enable = {
		en = "Enable debuffs for horde enemies?",
	},
})

-- Group settings
table.insert(localisations_to_add, {
	group_settings = {
		en = "ENEMY TYPE SPECIFIC SETTINGS {#color(255,185,0)}(All below settings apply ONLY to the selected enemy group){#reset()}",
	},
	enemy_group = {
		en = "PICK AN ENEMY TYPE",
	},

	-- outlines
	outline_type_enable = {
		en = "Enable outline?",
	},
	outline_type_colour = {
		en = "Outline colour (Enemy Type Specific)",
	},
	outline_type_colour_R = {
		en = "Red",
	},
	outline_type_colour_G = {
		en = "Green",
	},
	outline_type_colour_B = {
		en = "Blue",
	},

	-- healthbars
	healthbar_type_enable = {
		en = "Enable healthbars?",
	},
	healthbar_type_colour = {
		en = "Healthbar colour (Enemy Type Specific)",
	},
	healthbar_type_colour_R = {
		en = "Red",
	},
	healthbar_type_colour_G = {
		en = "Green",
	},
	healthbar_type_colour_B = {
		en = "Blue",
	},
})

-- tooltips
table.insert(localisations_to_add, {
	enemy_group_tooltip = {
		en = "Select an enemy category to adjust their specific settings. The category for each enemy can be seen by enabling 'Display enemy type?' under the Healthbar section.",
	},
})

-- fonts
table.insert(localisations_to_add, {

	proxima_nova_medium = {
		en = "Proxima Nova Medium",
	},

	proxima_nova_bold = {
		en = "Proxima Nova Bold",
	},

	proxima_nova_bold_masked = {
		en = "Proxima Nova Bold Masked",
	},

	itc_novarese_medium = {
		en = "Itc Novarese Medium",
	},

	itc_novarese_bold = {
		en = "Itc Novarese Bold",
	},

	machine_medium = {
		en = "Machine Medium",
	},

	arial = {
		en = "Arial",
	},

	mono_tide_medium = {
		en = "Mono Tide Medium",
	},

	mono_tide_regular = {
		en = "Mono Tide Regular",
	},

	mono_tide_bold = {
		en = "Mono Tide Bold",
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

return mod.localisation
