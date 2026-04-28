local mod = get_mod("enemies_improved")
local next = next

mod.debuff_styles = {
	generic = {
		icon = "content/ui/materials/icons/weapons/actions/linesman",
		colour = { 255, 150, 150, 150 },
	},

	bleed = {
		icon = "content/ui/materials/icons/presets/preset_13",
		colour = { 255, 255, 0, 0 },
	},

	fire = {
		icon = "content/ui/materials/icons/presets/preset_20",
		colour = { 255, 250, 150, 20 },
	},

	warp = {
		icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_ember",
		colour = { 255, 120, 200, 255 },
	},

	shock = {
		icon = "content/ui/materials/icons/presets/preset_11",
		colour = { 255, 255, 255, 0 },
	},

	toxin = {
		icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
		colour = { 255, 50, 255, 20 },
	},

	rending = {
		icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_rotten_armor",
		colour = { 255, 172, 115, 255 },
	},

	arbites = {
		icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_rampaging_enemies",
		colour = { 255, 0, 144, 255 },
	},

	rage = {
		icon = "content/ui/materials/icons/presets/preset_18",
		colour = { 255, 255, 117, 255 },
	},

	stagger = {
		icon = "content/ui/materials/icons/throwables/hud/small/party_non_grenade",
		colour = { 255, 100, 200, 255 },
	},

	blind = {
		icon = "content/ui/materials/icons/circumstances/ventilation_purge_01",
		colour = { 255, 200, 200, 200 },
	},

	damage_taken = {
		icon = "content/ui/materials/hud/interactions/icons/enemy",
		colour = { 255, 255, 185, 100 },
	},

	melee_damage_taken = {
		icon = "content/ui/materials/hud/interactions/icons/enemy_priority",
		colour = { 255, 255, 242, 99 },
	},

	stagger_damage = {
		icon = "content/ui/materials/hud/interactions/icons/enemy",
		colour = { 255, 255, 185, 100 },
	},

	bleed_damage = {
		icon = "content/ui/materials/hud/interactions/icons/enemy",
		colour = { 255, 255, 185, 100 },
	},

	toxin_damage = {
		icon = "content/ui/materials/hud/interactions/icons/enemy",
		colour = { 255, 255, 185, 100 },
	},
}

mod.debuffs = {
	-- DOT
	bleed = { name = "bleed", type = "dot", group = "bleed" },
	flamer_assault = { name = "flamer_assault", type = "dot", group = "fire" },
	flame_grenade_liquid_area = { name = "flame_grenade_liquid_area", type = "dot", group = "fire" },
	warp_fire = { name = "warp_fire", type = "dot", group = "warp" },
	shock_effect = { name = "shock_effect", type = "dot", group = "shock" },

	neurotoxin_interval_buff = { name = "neurotoxin_interval_buff", type = "dot", group = "toxin" },
	neurotoxin_interval_buff2 = { name = "neurotoxin_interval_buff2", type = "dot", group = "toxin" },
	neurotoxin_interval_buff3 = { name = "neurotoxin_interval_buff3", type = "dot", group = "toxin" },
	exploding_toxin_interval_buff = { name = "exploding_toxin_interval_buff", type = "dot", group = "toxin" },

	-- UTILITY
	rending_debuff = { name = "rending_debuff", type = "utility", group = "rending" },
	rending_debuff_medium = { name = "rending_debuff_medium", type = "utility", group = "rending" },
	rending_burn_debuff = { name = "rending_burn_debuff", type = "utility", group = "rending" },
	saw_rending_debuff = { name = "saw_rending_debuff", type = "utility", group = "rending" },

	increase_impact_received_while_staggered = {
		name = "increase_impact_received_while_staggered",
		type = "utility",
		group = "rending",
	},
	increase_damage_received_while_staggered = {
		name = "increase_damage_received_while_staggered",
		type = "utility",
		group = "stagger_damage",
	},

	power_maul_sticky_tick = { name = "power_maul_sticky_tick", type = "utility", group = "generic" },

	increase_damage_taken = { name = "increase_damage_taken", type = "utility", group = "damage_taken" },
	psyker_force_staff_quick_attack_debuff = {
		name = "psyker_force_staff_quick_attack_debuff",
		type = "utility",
		group = "warp",
	},

	psyker_heavy_swings_shock = { name = "psyker_heavy_swings_shock", type = "utility", group = "shock" },
	psyker_heavy_swings_shock_improved = {
		name = "psyker_heavy_swings_shock_improved",
		type = "utility",
		group = "shock",
	},
	psyker_protectorate_spread_chain_lightning_interval = {
		name = "psyker_protectorate_spread_chain_lightning_interval",
		type = "utility",
		group = "shock",
	},
	psyker_protectorate_spread_chain_lightning_interval_improved = {
		name = "psyker_protectorate_spread_chain_lightning_interval_improved",
		type = "utility",
		group = "shock",
	},
	psyker_protectorate_spread_charged_chain_lightning_interval = {
		name = "psyker_protectorate_spread_charged_chain_lightning_interval",
		type = "utility",
		group = "shock",
	},
	psyker_protectorate_spread_charged_chain_lightning_interval_improved = {
		name = "psyker_protectorate_spread_charged_chain_lightning_interval_improved",
		type = "utility",
		group = "shock",
	},

	psyker_discharge_damage_debuff = {
		name = "psyker_discharge_damage_debuff",
		type = "utility",
		group = "damage_taken",
	},

	ogryn_recieve_damage_taken_increase_debuff = {
		name = "ogryn_recieve_damage_taken_increase_debuff",
		type = "utility",
		group = "damage_taken",
	},
	ogryn_taunt_increased_damage_taken_buff = {
		name = "ogryn_taunt_increased_damage_taken_buff",
		type = "utility",
		group = "damage_taken",
	},
	ogryn_staggering_damage_taken_increase = {
		name = "ogryn_staggering_damage_taken_increase",
		type = "utility",
		group = "melee_damage_taken",
	},

	veteran_improved_tag_debuff = { name = "veteran_improved_tag_debuff", type = "utility", group = "damage_taken" },

	zealot_bled_enemies_take_more_damage_effect = {
		name = "zealot_bled_enemies_take_more_damage_effect",
		type = "utility",
		group = "bleed_damage",
	},

	adamant_drone_enemy_debuff = { name = "adamant_drone_enemy_debuff", type = "utility", group = "damage_taken" },
	adamant_drone_talent_debuff = { name = "adamant_drone_talent_debuff", type = "utility", group = "arbites" },

	adamant_melee_weakspot_hits_count_as_stagger_debuff = {
		name = "adamant_melee_weakspot_hits_count_as_stagger_debuff",
		type = "utility",
		group = "rending",
	},
	adamant_staggered_enemies_deal_less_damage_debuff = {
		name = "adamant_staggered_enemies_deal_less_damage_debuff",
		type = "utility",
		group = "rending",
	},
	adamant_staggering_increases_damage_taken = {
		name = "adamant_staggering_increases_damage_taken",
		type = "utility",
		group = "stagger_damage",
	},

	broker_punk_rage_improved_shout_debuff = {
		name = "broker_punk_rage_improved_shout_debuff",
		type = "utility",
		group = "rage",
	},

	shock_grenade_interval = { name = "shock_grenade_interval", type = "utility", group = "stagger" },
	staggered = { name = "staggered", type = "utility", group = "stagger" },

	in_smoke_fog = { name = "in_smoke_fog", type = "utility", group = "blind" },

	toxin_damage_debuff = { name = "toxin_damage_debuff", type = "utility", group = "toxin" },
	toxin_damage_debuff_monster = { name = "toxin_damage_debuff_monster", type = "utility", group = "toxin" },
	broker_passive_toxin_infected_enemies_take_increased_damage_debuff = {
		name = "broker_passive_toxin_infected_enemies_take_increased_damage_debuff",
		type = "utility",
		group = "toxin_damage",
	},
}

mod.default_debuffs = table.clone(mod.debuffs)

-- add debuff selector entries
mod.debuff_list = {}

for _, debuff in next, mod.debuffs do
	mod.debuff_list[#mod.debuff_list + 1] =
		{ text = debuff.name, value = debuff.name, sort = mod:localize(debuff.name) or debuff.name }
end

table.sort(mod.debuff_list, function(a, b)
	return a.sort < b.sort
end)

-- add debuff group selector entries
mod.debuff_groups_list = {}

for group_name, debuff in next, mod.debuff_styles do
	mod.debuff_groups_list[#mod.debuff_groups_list + 1] =
		{ text = group_name, value = group_name, sort = mod:localize(group_name) or group_name }
end

table.sort(mod.debuff_groups_list, function(a, b)
	return a.sort < b.sort
end)

mod.BREED_COLOURS = {
	horde = { 255, 150, 60, 60 },
	elite = { 255, 0, 120, 255 },
	captain = { 255, 255, 140, 0 },
	disabler = { 255, 255, 255, 0 },
	witch = { 255, 255, 0, 180 },
	monster = { 255, 180, 0, 255 },
	sniper = { 255, 255, 0, 0 },
	far = { 255, 0, 255, 120 },
	special = { 255, 255, 0, 255 },
	enemy = { 255, 200, 200, 200 },
}

mod.ICON_COLOURS = {
	horde = { 255, 150, 60, 60 },
	elite = { 255, 0, 120, 255 },
	captain = { 255, 255, 140, 0 },
	disabler = { 255, 255, 255, 0 },
	witch = { 255, 255, 0, 180 },
	monster = { 255, 180, 0, 255 },
	sniper = { 255, 255, 0, 0 },
	far = { 255, 0, 255, 120 },
	special = { 255, 255, 0, 255 },
	enemy = { 255, 200, 200, 200 },
	glow = { 255, 200, 170, 80 },
	glow_default = { 255, 200, 170, 80 },
}

mod.ICON_SETTINGS = {
	horde = {
		enabled = false,
		scale = 1,
		icon_scale = 1,
		glow_intensity = 0,
		default_glow_intensity = 0,
	},
	elite = {
		enabled = true,
		scale = 1,
		icon_scale = 1,
		glow_intensity = 50,
		default_glow_intensity = 50,
	},
	captain = {
		enabled = true,
		scale = 1,
		icon_scale = 1,
		glow_intensity = 100,
		default_glow_intensity = 100,
	},
	disabler = {
		enabled = true,
		scale = 1,
		icon_scale = 1.2,
		glow_intensity = 0,
		default_glow_intensity = 0,
	},
	witch = {
		enabled = true,
		scale = 1,
		icon_scale = 1.2,
		glow_intensity = 100,
		default_glow_intensity = 100,
	},
	monster = {
		enabled = true,
		scale = 1,
		icon_scale = 1,
		glow_intensity = 100,
		default_glow_intensity = 100,
	},
	sniper = {
		enabled = true,
		scale = 1,
		icon_scale = 1,
		glow_intensity = 0,
		default_glow_intensity = 0,
	},
	far = {
		enabled = true,
		scale = 1,
		icon_scale = 0.8,
		glow_intensity = 0,
		default_glow_intensity = 0,
	},
	special = {
		enabled = true,
		scale = 1,
		icon_scale = 1,
		glow_intensity = 0,
		default_glow_intensity = 0,
	},
	enemy = {
		enabled = false,
		scale = 1,
		icon_scale = 1,
		glow_intensity = 0,
		default_glow_intensity = 0,
	},
}

mod.OUTLINE_COLOURS = {
	horde = { 255, 50, 10, 0 },
	elite = { 255, 50, 10, 0 },
	captain = { 255, 50, 10, 0 },
	disabler = { 255, 50, 10, 0 },
	witch = { 255, 50, 10, 0 },
	monster = { 255, 50, 10, 0 },
	sniper = { 255, 50, 10, 0 },
	far = { 255, 50, 10, 0 },
	special = { 255, 50, 10, 0 },
	enemy = { 255, 50, 10, 0 },
}

mod.BREED_COLOURS_DEFAULT = table.clone(mod.BREED_COLOURS)
mod.ICON_COLOURS_DEFAULT = table.clone(mod.ICON_COLOURS)
mod.ICON_SETTINGS_DEFAULT = table.clone(mod.ICON_SETTINGS)
mod.OUTLINE_COLOURS_DEFAULT = table.clone(mod.OUTLINE_COLOURS)
mod.breed_names = mod.gather_enemy_names_by_breed_types()
mod.BREED_COLOURS_OVERRIDE = {}
mod.OUTLINE_COLOURS_OVERRIDE = {}

local hb_frames = {
	{
		text = "panel_main_lower_frame",
		value = "content/ui/materials/frames/masteries/panel_main_lower_frame",
	},
	{
		text = "heavy_frame_top",
		value = "content/ui/materials/bars/heavy/frame_top",
	},
	{
		text = "simple",
		value = "content/ui/materials/bars/simple/frame",
	},
	{
		text = "contracts_progress_overall_fill",
		value = "content/ui/materials/bars/contracts_progress_overall_fill",
	},
	{
		text = "nothing",
		value = "",
	},
}

local damage_number_types = {
	{
		text = "readable",
		value = "readable",
	},
	{
		text = "floating",
		value = "floating",
	},
	{
		text = "flashy",
		value = "flashy",
	},
}

local enemy_type_options = {
	{
		text = "enemy_type",
		value = "enemy_type",
	},
	{
		text = "enemy_name",
		value = "enemy_name",
	},
	{
		text = "armour_type",
		value = "armour_type",
	},
	{
		text = "health",
		value = "health",
	},
	{
		text = "nothing",
		value = "nothing",
	},
}

mod.outline_types = {
	{ text = "minion_outline", value = "minion_outline" },
	{ text = "minion_outline_reversed_depth", value = "minion_outline_reversed_depth" },
	{ text = "minion_outline_combat_ability", value = "minion_outline_combat_ability" },
	{ text = "minion_outline_combat_ability_reversed_depth", value = "minion_outline_combat_ability_reversed_depth" },
	{ text = "minion_outline_psyker", value = "minion_outline_psyker" },

	{ text = "scanning", value = "scanning" },
	{ text = "scanning_reversed_depth", value = "scanning_reversed_depth" },

	{ text = "player_outline_target", value = "player_outline_target" },
	{ text = "player_outline_knocked_down", value = "player_outline_knocked_down" },
	{ text = "player_outline_knocked_down_reversed_depth", value = "player_outline_knocked_down_reversed_depth" },
	{ text = "player_outline_general", value = "player_outline_general" },
	{ text = "player_outline_general_depth", value = "player_outline_general_depth" },
}

mod.settings_widgets = {}

local fonts = mod._get_font_options()

-- GENERAL SETTINGS
table.insert(mod.settings_widgets, {
	setting_id = "general_settings",
	type = "group",
	sub_widgets = {
		{
			setting_id = "draw_distance",
			type = "numeric",
			default_value = 30,
			range = {
				15,
				100,
			},
			tooltip = "draw_distance_tooltip",
		},
		{
			setting_id = "global_opacity",
			type = "numeric",
			default_value = 1,
			decimals_number = 2,
			step_size_value = 0.1,
			range = {
				0.1,
				1,
			},
			tooltip = "global_opacity_tooltip",
		},
		{
			setting_id = "enable_depth_fading",
			type = "checkbox",
			default_value = true,
			tooltip = "enable_depth_fading_tooltip",
		},
		{
			setting_id = "spatial_culling",
			type = "checkbox",
			default_value = true,
			tooltip = "spatial_culling_tooltip",
		},
		{
			setting_id = "only_in_meatgrinder",
			type = "checkbox",
			default_value = false,
			tooltip = "only_in_meatgrinder_tooltip",
		},
		--[[{
			setting_id = "check_line_of_sight",
			type = "checkbox",
			default_value = true,
			tooltip = "check_line_of_sight_tooltip",
		},]]
		{
			setting_id = "outlines_enable",
			type = "checkbox",
			default_value = true,
			tooltip = "outlines_enable_tooltip",
		},
		--[[{
			setting_id = "outlines_style",
			type = "dropdown",
			options = mod.outline_types,
			default_value = "minion_outline",
			tooltip = "outlines_style_tooltip",
		},]]
		{
			setting_id = "font_type",
			type = "dropdown",
			options = fonts,
			default_value = "mono_tide_bold",
			tooltip = "font_type_tooltip",
		},
		{
			setting_id = "mod_name_pizazz_toggle",
			type = "checkbox",
			default_value = true,
			tooltip = "mod_name_pizazz_tooltip",
		},
		{
			setting_id = "text_scale",
			type = "numeric",
			default_value = 1,
			decimals_number = 2,
			step_size_value = 0.1,
			range = {
				0.5,
				1.5,
			},
			tooltip = "text_scale_tooltip",
		},
		--[[{
			setting_id = "global_scale",
			type = "numeric",
			default_value = 1,
			decimals_number = 2,
			step_size_value = 0.1,
			range = {
				0.5,
				1.5,
			},
			tooltip = "global_scale_tooltip",
		},]]
		{
			setting_id = "main_font_colour",
			type = "group",
			sub_widgets = {
				{
					setting_id = "main_font_colour_R",
					type = "numeric",
					default_value = 255,
					range = {
						0,
						255,
					},
					tooltip = "main_font_colour_tooltip",
				},
				{
					setting_id = "main_font_colour_G",
					type = "numeric",
					default_value = 255,
					range = {
						0,
						255,
					},
					tooltip = "main_font_colour_tooltip",
				},
				{
					setting_id = "main_font_colour_B",
					type = "numeric",
					default_value = 255,
					range = {
						0,
						255,
					},
					tooltip = "main_font_colour_tooltip",
				},
			},
		},
		{
			setting_id = "secondary_font_colour",
			type = "group",
			sub_widgets = {
				{
					setting_id = "secondary_font_colour_R",
					type = "numeric",
					default_value = 255,
					range = {
						0,
						255,
					},
					tooltip = "secondary_font_colour_tooltip",
				},
				{
					setting_id = "secondary_font_colour_G",
					type = "numeric",
					default_value = 225,
					range = {
						0,
						255,
					},
					tooltip = "secondary_font_colour_tooltip",
				},
				{
					setting_id = "secondary_font_colour_B",
					type = "numeric",
					default_value = 150,
					range = {
						0,
						255,
					},
					tooltip = "secondary_font_colour_tooltip",
				},
			},
		},
	},
})

-- SPECIAL ATTACKS
table.insert(mod.settings_widgets, {
	setting_id = "special_attack_settings",
	type = "group",
	sub_widgets = {
		{
			setting_id = "marker_specials_enable",
			type = "checkbox",
			default_value = true,
			tooltip = "marker_specials_enable_tooltip",
		},
		{
			setting_id = "healthbar_specials_enable",
			type = "checkbox",
			default_value = true,
			tooltip = "healthbar_specials_enable_tooltip",
		},
		{
			setting_id = "outline_specials_enable",
			type = "checkbox",
			default_value = true,
			tooltip = "outline_specials_enable_tooltip",
		},
		{
			setting_id = "specials_flash",
			type = "checkbox",
			default_value = true,
			tooltip = "specials_flash_tooltip",
		},
		{
			setting_id = "special_attack_pulse_speed",
			type = "numeric",
			default_value = 0.2,
			range = {
				0.05,
				0.5,
			},
			decimals_number = 2,
			step_size_value = 0.05,
			tooltip = "special_attack_pulse_speed_tooltip",
		},
		{
			setting_id = "outline_specials_colour",
			type = "group",
			sub_widgets = {
				{
					setting_id = "outline_specials_colour_R",
					type = "numeric",
					default_value = 255,
					range = {
						0,
						255,
					},
					tooltip = "outline_specials_colour_tooltip",
				},
				{
					setting_id = "outline_specials_colour_G",
					type = "numeric",
					default_value = 100,
					range = {
						0,
						255,
					},
					tooltip = "outline_specials_colour_tooltip",
				},
				{
					setting_id = "outline_specials_colour_B",
					type = "numeric",
					default_value = 0,
					range = {
						0,
						255,
					},
					tooltip = "outline_specials_colour_tooltip",
				},
			},
		},
	},
})

-- STAGGER
table.insert(mod.settings_widgets, {
	setting_id = "stagger_settings",
	type = "group",
	sub_widgets = {
		{
			setting_id = "debuff_stagger_enable",
			type = "checkbox",
			default_value = true,
			tooltip = "debuff_stagger_enable_tooltip",
		},
		{
			setting_id = "outline_stagger_enable",
			type = "checkbox",
			default_value = true,
			tooltip = "outline_stagger_enable_tooltip",
		},
		{
			setting_id = "outline_stagger_horde_enable",
			type = "checkbox",
			default_value = false,
			tooltip = "outline_stagger_horde_enable_tooltip",
		},
		{
			setting_id = "stagger_flash",
			type = "checkbox",
			default_value = true,
			tooltip = "stagger_flash_tooltip",
		},
		{
			setting_id = "stagger_pulse_speed",
			type = "numeric",
			default_value = 0.1,
			range = {
				0.05,
				0.5,
			},
			decimals_number = 2,
			step_size_value = 0.05,
			tooltip = "stagger_pulse_speed_tooltip",
		},
		{
			setting_id = "outline_stagger_colour",
			type = "group",
			sub_widgets = {
				{
					setting_id = "outline_stagger_colour_R",
					type = "numeric",
					default_value = 0,
					range = {
						0,
						255,
					},
					tooltip = "outline_stagger_colour_tooltip",
				},
				{
					setting_id = "outline_stagger_colour_G",
					type = "numeric",
					default_value = 200,
					range = {
						0,
						255,
					},
					tooltip = "outline_stagger_colour_tooltip",
				},
				{
					setting_id = "outline_stagger_colour_B",
					type = "numeric",
					default_value = 200,
					range = {
						0,
						255,
					},
					tooltip = "outline_stagger_colour_tooltip",
				},
			},
		},
	},
})

-- MARKERS
table.insert(mod.settings_widgets, {
	setting_id = "markers_settings",
	type = "group",
	sub_widgets = {
		{
			setting_id = "markers_enable",
			type = "checkbox",
			default_value = false,
			tooltip = "markers_enable_tooltip",
		},

		{
			setting_id = "markers_horde_enable",
			type = "checkbox",
			default_value = false,
			tooltip = "markers_horde_enable_tooltip",
		},
		{
			setting_id = "marker_size",
			type = "numeric",
			default_value = 1.5,
			decimals_number = 1,
			step_size_value = 1,
			range = {
				1,
				6,
			},
			tooltip = "marker_size_tooltip",
		},
		{
			setting_id = "marker_y_offset",
			type = "numeric",
			default_value = 0,
			range = {
				-1,
				1,
			},
			decimals_number = 1,
			step_size_value = 0.1,
			tooltip = "marker_y_offset_tooltip",
		},
		{
			setting_id = "markers_health_enable",
			type = "checkbox",
			default_value = false,
			tooltip = "markers_health_enable_tooltip",
		},
		{
			setting_id = "overhead_marker_uses_healthbar_colour",
			type = "checkbox",
			default_value = true,
			tooltip = "overhead_marker_uses_healthbar_colour_tooltip",
		},
		{
			setting_id = "marker_bg_colour",
			type = "group",
			sub_widgets = {
				{
					setting_id = "marker_bg_colour_A",
					type = "numeric",
					default_value = 200,
					range = {
						0,
						255,
					},
					tooltip = "marker_bg_colour_tooltip",
				},
				{
					setting_id = "marker_bg_colour_R",
					type = "numeric",
					default_value = 200,
					range = {
						0,
						255,
					},
					tooltip = "marker_bg_colour_tooltip",
				},
				{
					setting_id = "marker_bg_colour_G",
					type = "numeric",
					default_value = 200,
					range = {
						0,
						255,
					},
					tooltip = "marker_bg_colour_tooltip",
				},
				{
					setting_id = "marker_bg_colour_B",
					type = "numeric",
					default_value = 200,
					range = {
						0,
						255,
					},
					tooltip = "marker_bg_colour_tooltip",
				},
			},
		},
	},
})

-- HEALTHBAR
table.insert(mod.settings_widgets, {
	setting_id = "healthbar_settings",
	type = "group",
	sub_widgets = {
		{
			setting_id = "healthbar_enable",
			type = "checkbox",
			default_value = true,
			tooltip = "healthbar_enable_tooltip",
		},

		{
			setting_id = "healthbar_type_icon_enable",
			type = "checkbox",
			default_value = false,
			tooltip = "healthbar_type_icon_enable_tooltip",
		},
		{
			setting_id = "healthbar_type_icon_scale",
			type = "numeric",
			default_value = 1.3,
			range = {
				1,
				3,
			},
			decimals_number = 1,
			step_size_value = 0.1,
			tooltip = "healthbar_type_icon_scale_tooltip",
		},
		{
			setting_id = "hb_toggle_base_boss_healthbar",
			type = "checkbox",
			default_value = true,
			tooltip = "hb_toggle_base_boss_healthbar_tooltip",
		},
		{
			setting_id = "hb_endcaps_enabled",
			type = "checkbox",
			default_value = true,
			tooltip = "hb_endcaps_enabled_tooltip",
		},
		{
			setting_id = "healthbar_segments_enable",
			type = "checkbox",
			default_value = true,
			tooltip = "healthbar_segments_enable_tooltip",
		},
		{
			setting_id = "hb_horde_enable",
			type = "checkbox",
			default_value = false,
			tooltip = "hb_horde_enable_tooltip",
		},
		{
			setting_id = "hb_horde_clusters_enable",
			type = "checkbox",
			default_value = true,
			tooltip = "hb_horde_clusters_enable_tooltip",
		},
		{
			setting_id = "hb_hide_after_no_damage",
			type = "checkbox",
			default_value = false,
			tooltip = "hb_hide_after_no_damage_tooltip",
		},
		{
			setting_id = "hb_horde_hide_after_no_damage",
			type = "checkbox",
			default_value = false,
			tooltip = "hb_horde_hide_after_no_damage_tooltip",
		},
		{
			setting_id = "hb_toggle_ghostbar",
			type = "checkbox",
			default_value = true,
			tooltip = "hb_toggle_ghostbar_tooltip",
		},
		{
			setting_id = "hb_ghostbar_opacity",
			type = "numeric",
			default_value = 0.7,
			range = {
				0.1,
				1,
			},
			decimals_number = 1,
			step_size_value = 0.1,
			tooltip = "hb_ghostbar_opacity_tooltip",
		},
		{
			setting_id = "hb_toggle_ghostbar_colour",
			type = "checkbox",
			default_value = false,
			tooltip = "hb_toggle_ghostbar_colour_tooltip",
		},
		{
			setting_id = "hb_text_show_damage",
			type = "checkbox",
			default_value = false,
			tooltip = "hb_text_show_damage_tooltip",
		},
		{
			setting_id = "hb_text_show_max_health",
			type = "checkbox",
			default_value = true,
			tooltip = "hb_text_show_max_health_tooltip",
		},
		{
			setting_id = "hb_damage_show_only_latest",
			type = "checkbox",
			default_value = false,
			tooltip = "hb_damage_show_only_latest_tooltip",
		},
		{
			setting_id = "hb_damage_show_only_latest_value",
			type = "numeric",
			default_value = 3,
			range = {
				1,
				10,
			},
			decimals_number = 0,
			step_size_value = 1,
			tooltip = "hb_damage_show_only_latest_value_tooltip",
		},
		{
			setting_id = "hb_gap_padding_scale",
			type = "numeric",
			default_value = 1,
			range = {
				0.9,
				1.2,
			},
			decimals_number = 2,
			step_size_value = 0.1,
			tooltip = "hb_gap_padding_scale_tooltip",
		},
		{
			setting_id = "hb_frame",
			type = "dropdown",
			options = hb_frames,
			default_value = "content/ui/materials/bars/simple/frame",
			tooltip = "hb_frame_tooltip",
		},
		{
			setting_id = "hb_padding_scale",
			type = "numeric",
			default_value = 1.25,
			range = {
				0.5,
				10,
			},
			decimals_number = 2,
			step_size_value = 0.1,
			tooltip = "hb_padding_scale_tooltip",
		},
		{
			setting_id = "hb_y_offset",
			type = "numeric",
			default_value = 0,
			range = {
				-1,
				2,
			},
			decimals_number = 1,
			step_size_value = 0.1,
			tooltip = "hb_y_offset_tooltip",
		},
		{
			setting_id = "hb_size_width",
			type = "numeric",
			default_value = 180,
			range = {
				100,
				400,
			},
			tooltip = "hb_size_width_tooltip",
		},
		{
			setting_id = "hb_size_height",
			type = "numeric",
			default_value = 8,
			range = {
				4,
				25,
			},
			tooltip = "hb_size_height_tooltip",
		},
	},
})

-- TOUGHNESS
table.insert(mod.settings_widgets, {
	setting_id = "toughness_colour",
	type = "group",
	sub_widgets = {
		{
			setting_id = "toughness_enabled",
			type = "checkbox",
			default_value = true,
			tooltip = "toughness_enabled_tooltip",
		},
		{
			setting_id = "toughness_electric",
			type = "checkbox",
			default_value = false,
			tooltip = "toughness_electric_tooltip",
		},
		{
			setting_id = "toughness_text_enabled",
			type = "checkbox",
			default_value = true,
			tooltip = "toughness_text_enabled_tooltip",
		},
		{
			setting_id = "toughness_text_colour_enabled",
			type = "checkbox",
			default_value = false,
			tooltip = "toughness_text_colour_enabled_tooltip",
		},
		{
			setting_id = "toughness_colour_R",
			type = "numeric",
			default_value = 50,
			range = {
				0,
				255,
			},
			tooltip = "toughness_colour_tooltip",
		},
		{
			setting_id = "toughness_colour_G",
			type = "numeric",
			default_value = 225,
			range = {
				0,
				255,
			},
			tooltip = "toughness_colour_tooltip",
		},
		{
			setting_id = "toughness_colour_B",
			type = "numeric",
			default_value = 255,
			range = {
				0,
				255,
			},
			tooltip = "toughness_colour_tooltip",
		},
	},
})

table.insert(mod.settings_widgets, {
	setting_id = "healthbar_text_settings",
	type = "group",
	sub_widgets = {
		{
			setting_id = "hb_text_top_left_01",
			type = "dropdown",
			options = table.clone(enemy_type_options),
			default_value = "enemy_name",
			tooltip = "hb_text_top_left_01_tooltip",
		},
		{
			setting_id = "hb_text_bottom_left_01",
			type = "dropdown",
			options = table.clone(enemy_type_options),
			default_value = "health",
			tooltip = "hb_text_bottom_left_01_tooltip",
		},
		{
			setting_id = "hb_text_bottom_left_02",
			type = "dropdown",
			options = table.clone(enemy_type_options),
			default_value = "nothing",
			tooltip = "hb_text_bottom_left_02_tooltip",
		},
	},
})

-- DAMAGE NUMBERS
table.insert(mod.settings_widgets, {
	setting_id = "damage_number_settings",
	type = "group",
	sub_widgets = {
		{
			setting_id = "hb_show_damage_numbers",
			type = "checkbox",
			default_value = true,
			tooltip = "hb_show_damage_numbers_tooltip",
		},
		{
			setting_id = "show_dn_in_range_only",
			type = "checkbox",
			default_value = false,
			tooltip = "show_dn_in_range_only_tooltip",
		},
		--[[{
			setting_id = "hb_damage_numbers_track_friendly",
			type = "checkbox",
			default_value = true,
			tooltip = "hb_damage_numbers_track_friendly_tooltip",
		},]]
		{
			setting_id = "hb_show_dps",
			type = "checkbox",
			default_value = false,
			tooltip = "hb_show_dps_tooltip",
		},
		{
			setting_id = "hb_damage_numbers_add_total",
			type = "checkbox",
			default_value = true,
			tooltip = "hb_damage_numbers_add_total_tooltip",
		},
		{
			setting_id = "hb_damage_number_types",
			type = "dropdown",
			options = damage_number_types,
			default_value = "readable",
			tooltip = "hb_damage_number_types_tooltip",
		},
		{
			setting_id = "damage_number_scale",
			type = "numeric",
			default_value = 1.2,
			decimals_number = 2,
			step_size_value = 0.25,
			range = {
				0.5,
				3,
			},
			tooltip = "damage_number_scale_tooltip",
		},
		{
			setting_id = "damage_number_y_offset",
			type = "numeric",
			default_value = 1.2,
			decimals_number = 2,
			step_size_value = 0.25,
			range = {
				0,
				3,
			},
			tooltip = "damage_number_y_offset_tooltip",
		},
		{
			setting_id = "damage_number_duration",
			type = "numeric",
			default_value = 2,
			decimals_number = 2,
			step_size_value = 0.25,
			range = {
				1,
				5,
			},
			tooltip = "damage_number_duration_tooltip",
		},
		{
			setting_id = "readable_max_damage_numbers",
			type = "numeric",
			default_value = 6,
			decimals_number = 0,
			step_size_value = 1,
			range = {
				1,
				10,
			},
			tooltip = "readable_max_damage_numbers_tooltip",
		},
	},
})
-- DEBUFFS
table.insert(mod.settings_widgets, {
	setting_id = "debuff_settings",
	type = "group",
	sub_widgets = {
		{
			setting_id = "debuff_enable",
			type = "checkbox",
			default_value = true,
			tooltip = "debuff_enable_tooltip",
		},
		{
			setting_id = "debuff_dot_enable",
			type = "checkbox",
			default_value = true,
			tooltip = "debuff_dot_enable_tooltip",
		},
		{
			setting_id = "debuff_utility_enable",
			type = "checkbox",
			default_value = true,
			tooltip = "debuff_utility_enable_tooltip",
		},
		{
			setting_id = "debuff_horde_enable",
			type = "checkbox",
			default_value = false,
			tooltip = "debuff_horde_enable_tooltip",
		},
		{
			setting_id = "debuff_horizontal",
			type = "checkbox",
			default_value = true,
			tooltip = "debuff_horizontal_tooltip",
		},
		{
			setting_id = "split_debuff_types",
			type = "checkbox",
			default_value = true,
			tooltip = "split_debuff_types_tooltip",
		},
		{
			setting_id = "debuffs_abrv",
			type = "checkbox",
			default_value = true,
			tooltip = "debuffs_abrv_tooltip",
		},
		{
			setting_id = "debuffs_combine",
			type = "checkbox",
			default_value = true,
			tooltip = "debuffs_combine_tooltip",
		},
		{
			setting_id = "debuff_names",
			type = "checkbox",
			default_value = true,
			tooltip = "debuff_names_tooltip",
		},
		{
			setting_id = "debuff_icons",
			type = "checkbox",
			default_value = true,
			tooltip = "debuff_icons_tooltip",
		},
		{
			setting_id = "debuff_stacks_show_x",
			type = "checkbox",
			default_value = true,
			tooltip = "debuff_stacks_show_x_tooltip",
		},
		{
			setting_id = "debuff_stacks_show_x_space",
			type = "checkbox",
			default_value = true,
			tooltip = "debuff_stacks_show_x_space_tooltip",
		},
		{
			setting_id = "debuff_stack_on_icon",
			type = "checkbox",
			default_value = false,
			tooltip = "debuff_stack_on_icon_tooltip",
		},
		{
			setting_id = "debuff_stacks_icon_colour",
			type = "checkbox",
			default_value = false,
			tooltip = "debuff_stacks_icon_colour_tooltip",
		},
		{
			setting_id = "debuff_names_fade",
			type = "checkbox",
			default_value = false,
			tooltip = "debuff_names_fade_tooltip",
		},
		{
			setting_id = "debuff_show_on_body",
			type = "checkbox",
			default_value = false,
			tooltip = "debuff_show_on_body_tooltip",
		},

		{
			setting_id = "debuff_icon_scale",
			type = "numeric",
			default_value = 1,
			range = {
				0.8,
				2,
			},
			decimals_number = 2,
			step_size_value = 0.1,
			tooltip = "debuff_icon_scale_tooltip",
		},
		{
			setting_id = "debuff_gap_name_icon_offset",
			type = "numeric",
			default_value = 0,
			range = {
				-1.5,
				1.5,
			},
			decimals_number = 2,
			step_size_value = 0.1,
			tooltip = "debuff_gap_name_icon_offset_tooltip",
		},
		{
			setting_id = "debuff_gap_icon_stack_offset",
			type = "numeric",
			default_value = 0.9,
			range = {
				-1.5,
				1.5,
			},
			decimals_number = 2,
			step_size_value = 0.1,
			tooltip = "debuff_gap_icon_stack_offset_tooltip",
		},
		{
			setting_id = "debuff_gap_padding_scale",
			type = "numeric",
			default_value = 1,
			range = {
				0.5,
				2,
			},
			decimals_number = 2,
			step_size_value = 0.1,
			tooltip = "debuff_gap_padding_scale_tooltip",
		},
		{
			setting_id = "debuff_x_offset",
			type = "numeric",
			default_value = 0.45,
			range = {
				0.1,
				2,
			},
			decimals_number = 2,
			step_size_value = 0.1,
			tooltip = "debuff_x_offset_tooltip",
		},
		{
			setting_id = "debuff_y_offset",
			type = "numeric",
			default_value = 1,
			range = {
				0.1,
				2,
			},
			decimals_number = 2,
			step_size_value = 0.1,
			tooltip = "debuff_y_offset_tooltip",
		},
		{
			setting_id = "debuff_toggles",
			type = "dropdown",
			options = mod.debuff_list,
			default_value = "bleed",
			tooltip = "debuff_toggles_tooltip",
		},
		{
			setting_id = "debuff_selected_enable",
			type = "checkbox",
			default_value = true,
			tooltip = "debuff_selected_enable_tooltip",
		},
		{
			setting_id = "debuff_max_stacks_colour",
			type = "group",
			sub_widgets = {
				{
					setting_id = "debuff_max_stacks_scale",
					type = "checkbox",
					default_value = true,
					tooltip = "debuff_max_stacks_scale_tooltip",
				},
				{
					setting_id = "debuff_max_stacks_colour_toggle",
					type = "checkbox",
					default_value = true,
					tooltip = "debuff_max_stacks_colour_toggle_tooltip",
				},
				{
					setting_id = "debuff_max_stacks_colour_R",
					type = "numeric",
					default_value = 255,
					range = {
						0,
						255,
					},
					tooltip = "debuff_max_stacks_colour_tooltip",
				},
				{
					setting_id = "debuff_max_stacks_colour_G",
					type = "numeric",
					default_value = 200,
					range = {
						0,
						255,
					},
					tooltip = "debuff_max_stacks_colour_tooltip",
				},
				{
					setting_id = "debuff_max_stacks_colour_B",
					type = "numeric",
					default_value = 0,
					range = {
						0,
						255,
					},
					tooltip = "debuff_max_stacks_colour_tooltip",
				},
			},
		},
		{
			setting_id = "debuff_group_colour",
			type = "group",
			sub_widgets = {
				{
					setting_id = "debuff_group_selected",
					type = "dropdown",
					options = mod.debuff_groups_list,
					default_value = "generic",
					tooltip = "debuff_group_selected_tooltip",
				},
				{
					setting_id = "debuff_group_colour_R",
					type = "numeric",
					default_value = 50,
					range = {
						0,
						255,
					},
					tooltip = "debuff_group_colour_tooltip",
				},
				{
					setting_id = "debuff_group_colour_G",
					type = "numeric",
					default_value = 10,
					range = {
						0,
						255,
					},
					tooltip = "debuff_group_colour_tooltip",
				},
				{
					setting_id = "debuff_group_colour_B",
					type = "numeric",
					default_value = 0,
					range = {
						0,
						255,
					},
					tooltip = "debuff_group_colour_tooltip",
				},
			},
		},
	},
})

-- PER-ENEMY TYPE SELECTOR LOGIC
mod.breed_types = {
	{ text = "SELECT AN ENEMY TYPE", value = "select" },
	{ text = "horde", value = "horde" },
	{ text = "monster", value = "monster" },
	{ text = "captain", value = "captain" },
	{ text = "disabler", value = "disabler" },
	{ text = "witch", value = "witch" },
	{ text = "sniper", value = "sniper" },
	{ text = "far", value = "far" },
	{ text = "elite", value = "elite" },
	{ text = "special", value = "special" },
	{ text = "enemy", value = "enemy" },
}

mod.group_settings_widgets = {
	{
		setting_id = "enemy_group",
		type = "dropdown",
		options = mod.breed_types,
		default_value = "select",
		tooltip = "enemy_group_tooltip",
	},

	{
		setting_id = "reset_type_to_default",
		type = "checkbox",
		default_value = false,
		tooltip = "reset_type_to_default_tooltip",
	},

	-- outline
	{
		setting_id = "outline_type_enable",
		type = "checkbox",
		default_value = true,
		tooltip = "outline_type_enable_tooltip",
	},

	{
		setting_id = "outline_type_colour",
		type = "group",
		sub_widgets = {
			{
				setting_id = "outline_type_colour_R",
				type = "numeric",
				default_value = 50,
				range = {
					0,
					255,
				},
				tooltip = "outline_type_colour_tooltip",
			},
			{
				setting_id = "outline_type_colour_G",
				type = "numeric",
				default_value = 10,
				range = {
					0,
					255,
				},
				tooltip = "outline_type_colour_tooltip",
			},
			{
				setting_id = "outline_type_colour_B",
				type = "numeric",
				default_value = 0,
				range = {
					0,
					255,
				},
				tooltip = "outline_type_colour_tooltip",
			},
		},
	},

	-- healthbar
	{
		setting_id = "healthbar_type_enable",
		type = "checkbox",
		default_value = true,
		tooltip = "healthbar_type_enable_tooltip",
	},
	{
		setting_id = "healthbar_type_colour",
		type = "group",
		sub_widgets = {
			{
				setting_id = "healthbar_type_colour_R",
				type = "numeric",
				default_value = 150,
				range = {
					0,
					255,
				},
				tooltip = "healthbar_type_colour_tooltip",
			},
			{
				setting_id = "healthbar_type_colour_G",
				type = "numeric",
				default_value = 75,
				range = {
					0,
					255,
				},
				tooltip = "healthbar_type_colour_tooltip",
			},
			{
				setting_id = "healthbar_type_colour_B",
				type = "numeric",
				default_value = 0,
				range = {
					0,
					255,
				},
				tooltip = "healthbar_type_colour_tooltip",
			},
		},
	},

	-- healthbar icon
	{
		setting_id = "healthbar_icon_type_enable",
		type = "checkbox",
		default_value = true,
		tooltip = "healthbar_icon_type_enable_tooltip",
	},
	{
		setting_id = "healthbar_icon_type_scale",
		type = "numeric",
		default_value = 1,
		range = {
			0.6,
			2,
		},
		decimals_number = 2,
		step_size_value = 0.1,
		tooltip = "healthbar_icon_type_scale_tooltip",
	},
	{
		setting_id = "healthbar_icon_type_glow_intensity",
		type = "numeric",
		default_value = 0,
		range = {
			0,
			100,
		},
		tooltip = "healthbar_icon_type_glow_intensity_tooltip",
	},
	{
		setting_id = "healthbar_icon_type_colour",
		type = "group",
		sub_widgets = {
			{
				setting_id = "healthbar_icon_type_colour_R",
				type = "numeric",
				default_value = 200,
				range = {
					0,
					255,
				},
				tooltip = "healthbar_icon_type_colour_tooltip",
			},
			{
				setting_id = "healthbar_icon_type_colour_G",
				type = "numeric",
				default_value = 150,
				range = {
					0,
					255,
				},
				tooltip = "healthbar_icon_type_colour_tooltip",
			},
			{
				setting_id = "healthbar_icon_type_colour_B",
				type = "numeric",
				default_value = 0,
				range = {
					0,
					255,
				},
				tooltip = "healthbar_icon_type_colour_tooltip",
			},
		},
	},
}

table.insert(mod.settings_widgets, {
	setting_id = "group_settings",
	type = "group",
	sub_widgets = mod.group_settings_widgets,
})

mod.individual_override_settings = {
	{
		setting_id = "individual_overrides",
		type = "dropdown",
		options = mod.breed_names,
		default_value = "select",
		tooltip = "individual_overrides_tooltip",
	},

	{
		setting_id = "markers_individual_toggle",
		type = "checkbox",
		default_value = false,
		tooltip = "markers_individual_toggle_tooltip",
	},

	--{
	--	setting_id = "reset_individual_to_default",
	--	type = "checkbox",
	--	default_value = false,
	--	tooltip = "reset_individual_to_default_tooltip",
	--},

	{
		setting_id = "healthbar_individual_colour",
		type = "group",
		sub_widgets = {
			{
				setting_id = "healthbar_individual_enable",
				type = "checkbox",
				default_value = false,
				tooltip = "healthbar_individual_enable_tooltip",
			},
			{
				setting_id = "healthbar_individual_colour_R",
				type = "numeric",
				default_value = 150,
				range = {
					0,
					255,
				},
				tooltip = "healthbar_individual_colour_tooltip",
			},
			{
				setting_id = "healthbar_individual_colour_G",
				type = "numeric",
				default_value = 75,
				range = {
					0,
					255,
				},
				tooltip = "healthbar_individual_colour_tooltip",
			},
			{
				setting_id = "healthbar_individual_colour_B",
				type = "numeric",
				default_value = 0,
				range = {
					0,
					255,
				},
				tooltip = "healthbar_individual_colour_tooltip",
			},
		},
	},
	-- outline

	{
		setting_id = "outline_individual_colour",
		type = "group",
		sub_widgets = {
			{
				setting_id = "outline_individual_enable",
				type = "checkbox",
				default_value = false,
				tooltip = "outline_individual_enable_tooltip",
			},
			{
				setting_id = "outline_individual_colour_R",
				type = "numeric",
				default_value = 50,
				range = {
					0,
					255,
				},
				tooltip = "outline_individual_colour_tooltip",
			},
			{
				setting_id = "outline_individual_colour_G",
				type = "numeric",
				default_value = 10,
				range = {
					0,
					255,
				},
				tooltip = "outline_individual_colour_tooltip",
			},
			{
				setting_id = "outline_individual_colour_B",
				type = "numeric",
				default_value = 0,
				range = {
					0,
					255,
				},
				tooltip = "outline_individual_colour_tooltip",
			},
		},
	},
}

table.insert(mod.settings_widgets, {
	setting_id = "individual_override_settings",
	type = "group",
	sub_widgets = mod.individual_override_settings,
})

-- THROTTLE TIMINGS
table.insert(mod.settings_widgets, {
	setting_id = "throttle_timings",
	type = "group",
	sub_widgets = {
		{
			setting_id = "general_throttle_rate",
			type = "numeric",
			default_value = 20,
			range = {
				10,
				100,
			},
			decimals_number = 0,
			step_size_value = 1,
			tooltip = "general_throttle_rate_tooltip",
		},
		{
			setting_id = "off_screen_throttle_rate",
			type = "numeric",
			default_value = 120,
			range = {
				10,
				300,
			},
			decimals_number = 0,
			step_size_value = 1,
			tooltip = "off_screen_throttle_rate_tooltip",
		},
	},
})

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = mod.settings_widgets,
	},
}
