local mod = get_mod("enemies_improved")

mod.dot_debuffs = {
	-- DoT
	"bleed",
	"flamer_assault",
	"flame_grenade_liquid_area",
	"warp_fire",
	"shock_effect",

	"neurotoxin_interval_buff",
	"neurotoxin_interval_buff2",
	"neurotoxin_interval_buff3",
	"exploding_toxin_interval_buff",

	"psyker_force_staff_quick_attack_debuff",
}

mod.utility_debuffs = {
	-- Rending / “take more damage”, tags, etc.
	"rending_debuff",
	"increase_impact_received_while_staggered",
	"increase_damage_received_while_staggered",
	"power_maul_sticky_tick",
	"increase_damage_taken",

	-- Psyker utility / chain lightning etc.
	"psyker_heavy_swings_shock",
	"psyker_heavy_swings_shock_improved",
	"psyker_protectorate_spread_chain_lightning_interval",
	"psyker_protectorate_spread_chain_lightning_interval_improved",
	"psyker_protectorate_spread_charged_chain_lightning_interval",
	"psyker_protectorate_spread_charged_chain_lightning_interval_improved",
	"psyker_discharge_damage_debuff",

	-- Ogryn
	"ogryn_recieve_damage_taken_increase_debuff",
	"ogryn_taunt_increased_damage_taken_buff",
	"ogryn_staggering_damage_taken_increase",

	-- Veteran
	"veteran_improved_tag_debuff",

	-- Zealot
	"zealot_bled_enemies_take_more_damage_effect",

	-- Arbite
	"adamant_drone_enemy_debuff",
	"adamant_drone_talent_debuff",
	"adamant_melee_weakspot_hits_count_as_stagger_debuff",
	"adamant_staggered_enemies_deal_less_damage_debuff",
	"adamant_staggering_increases_damage_taken",

	-- Broker
	"broker_punk_rage_improved_shout_debuff",

	-- Stagger
	"shock_grenade_interval",

	-- Blinded/smoke
	"in_smoke_fog",

	-- Broker
	"toxin_damage_debuff",
	"toxin_damage_debuff_monster",
	"broker_passive_toxin_infected_enemies_take_increased_damage_debuff",
}

mod.debuffs = {}
for _, name in ipairs(mod.dot_debuffs) do
	mod.debuffs[#mod.debuffs + 1] = name
end
for _, name in ipairs(mod.utility_debuffs) do
	mod.debuffs[#mod.debuffs + 1] = name
end

mod.debuff_icons = {
	-- Weaponry / generic damage types
	melee = "content/ui/materials/icons/weapons/actions/linesman",
	melee_headshot = "content/ui/materials/icons/weapons/actions/smiter",
	headshot = "content/ui/materials/icons/weapons/actions/ads",
	ranged = "content/ui/materials/icons/weapons/actions/hipfire",

	-- Bleeding
	bleed = "content/ui/materials/icons/presets/preset_13",
	zealot_bled_enemies_take_more_damage_effect = "content/ui/materials/icons/presets/preset_13",

	-- Rending / armor shred
	rending_debuff = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_rotten_armor",
	increase_damage_taken = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_rotten_armor",
	increase_impact_received_while_staggered = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_rotten_armor",
	increase_damage_received_while_staggered = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_rotten_armor",
	adamant_melee_weakspot_hits_count_as_stagger_debuff = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_rotten_armor",
	adamant_staggered_enemies_deal_less_damage_debuff = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_rotten_armor",
	adamant_staggering_increases_damage_taken = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_rotten_armor",

	-- + damage
	veteran_improved_tag_debuff = "content/ui/materials/icons/player_states/dead",
	ogryn_recieve_damage_taken_increase_debuff = "content/ui/materials/icons/player_states/dead",
	ogryn_taunt_increased_damage_taken_buff = "content/ui/materials/icons/player_states/dead",
	ogryn_staggering_damage_taken_increase = "content/ui/materials/icons/player_states/dead",
	psyker_discharge_damage_debuff = "content/ui/materials/icons/player_states/dead",
	broker_passive_toxin_infected_enemies_take_increased_damage_debuff = "content/ui/materials/icons/player_states/dead",

	-- Electricity / shock / chain lightning
	electricity = "content/ui/materials/icons/presets/preset_11",
	shock_effect = "content/ui/materials/icons/presets/preset_11",

	psyker_heavy_swings_shock_improved = "content/ui/materials/icons/presets/preset_11",
	psyker_heavy_swings_shock = "content/ui/materials/icons/presets/preset_11",

	powermaul_p2_stun_interval = "content/ui/materials/icons/presets/preset_11",
	powermaul_p2_stun_interval_basic = "content/ui/materials/icons/presets/preset_11",
	shockmaul_stun_interval_damage = "content/ui/materials/icons/presets/preset_11",
	shock_grenade_stun_interval = "content/ui/materials/icons/presets/preset_11",
	protectorate_force_field = "content/ui/materials/icons/presets/preset_11",

	psyker_protectorate_spread_chain_lightning_interval = "content/ui/materials/icons/presets/preset_11",
	psyker_protectorate_spread_chain_lightning_interval_improved = "content/ui/materials/icons/presets/preset_11",
	psyker_protectorate_spread_charged_chain_lightning_interval = "content/ui/materials/icons/presets/preset_11",
	psyker_protectorate_spread_charged_chain_lightning_interval_improved = "content/ui/materials/icons/presets/preset_11",

	-- Explosion
	broker_flash_grenade_impact = "content/ui/materials/icons/presets/preset_19",
	explosion = "content/ui/materials/icons/presets/preset_19",
	barrel_explosion_close = "content/ui/materials/icons/presets/preset_19",
	barrel_explosion = "content/ui/materials/icons/presets/preset_19",
	poxwalker_explosion_close = "content/ui/materials/icons/presets/preset_19",
	poxwalker_explosion = "content/ui/materials/icons/presets/preset_19",
	default = "content/ui/materials/icons/presets/preset_19",

	-- FIRE Burn
	flame_grenade_liquid_area_fire_burning = "content/ui/materials/icons/presets/preset_20",
	liquid_area_fire_burning_barrel = "content/ui/materials/icons/presets/preset_20",
	liquid_area_fire_burning = "content/ui/materials/icons/presets/preset_20",
	burning = "content/ui/materials/icons/presets/preset_20",
	flamer_assault = "content/ui/materials/icons/presets/preset_20",
	flame_grenade_liquid_area = "content/ui/materials/icons/presets/preset_20",

	--  warp fire
	warpfire = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_ember",
	warp_fire = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_ember",
	psyker_force_staff_quick_attack_debuff = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_ember",

	-- Toxin / poison / chem
	toxin_variant_1 = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
	toxin_variant_2 = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
	toxin_variant_3 = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
	chem_burning = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
	chem_burning_fast = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
	chem_burning_slow = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
	broker_stimm_field = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
	broker_stimm_field_close = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
	broker_tox_grenade = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
	broker_toxin_stacks_stun_interval = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
	neurotoxin_interval_buff = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
	neurotoxin_interval_buff2 = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
	neurotoxin_interval_buff3 = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
	exploding_toxin_interval_buff = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
	toxin_damage_debuff = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
	toxin_damage_debuff_monster = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
	-- Arbite debuffs
	adamant_drone_enemy_debuff = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_rampaging_enemies",
	adamant_drone_talent_debuff = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_rampaging_enemies",

	-- Broker rage
	broker_punk_rage_improved_shout_debuff = "content/ui/materials/icons/presets/preset_18",

	-- "content/ui/materials/icons/circumstances/havoc/havoc_mutator_skin" good shield type icon

	-- Stagger
	shock_grenade_interval = "content/ui/materials/icons/throwables/hud/small/party_non_grenade",

	-- Blinded/smoke
	in_smoke_fog = "content/ui/materials/icons/circumstances/ventilation_purge_01",
}

mod.debuff_colours = {
	-- Weaponry / generic
	melee = { 255, 150, 150, 150 },
	melee_headshot = { 255, 150, 150, 150 },
	headshot = { 255, 150, 150, 150 },
	ranged = { 255, 150, 150, 150 },

	-- Bleeding
	bleed = { 255, 255, 0, 0 },
	zealot_bled_enemies_take_more_damage_effect = { 255, 255, 40, 40 },

	-- Electricity
	electricity = { 255, 255, 255, 0 },
	shock_effect = { 255, 255, 255, 0 },
	psyker_heavy_swings_shock = { 255, 255, 255, 0 },
	psyker_heavy_swings_shock_improved = { 255, 255, 255, 0 },

	powermaul_p2_stun_interval = { 255, 255, 255, 0 },
	powermaul_p2_stun_interval_basic = { 255, 255, 255, 0 },
	shockmaul_stun_interval_damage = { 255, 255, 255, 0 },
	shock_grenade_stun_interval = { 255, 255, 255, 0 },
	protectorate_force_field = { 255, 200, 230, 255 },

	psyker_protectorate_spread_chain_lightning_interval = { 255, 255, 255, 0 },
	psyker_protectorate_spread_chain_lightning_interval_improved = { 255, 255, 255, 0 },
	psyker_protectorate_spread_charged_chain_lightning_interval = { 255, 255, 255, 0 },
	psyker_protectorate_spread_charged_chain_lightning_interval_improved = { 255, 255, 255, 0 },

	-- Explosion
	broker_flash_grenade_impact = { 255, 250, 250, 20 },
	explosion = { 255, 250, 250, 20 },
	barrel_explosion_close = { 255, 250, 250, 20 },
	barrel_explosion = { 255, 250, 250, 20 },
	poxwalker_explosion_close = { 255, 250, 250, 20 },
	poxwalker_explosion = { 255, 250, 250, 20 },
	default = { 255, 250, 250, 20 },

	-- Burn
	flame_grenade_liquid_area_fire_burning = { 255, 250, 150, 20 },
	flame_grenade_liquid_area = { 255, 250, 150, 20 },
	liquid_area_fire_burning_barrel = { 255, 250, 150, 20 },
	liquid_area_fire_burning = { 255, 250, 150, 20 },
	burning = { 255, 250, 150, 20 },
	flamer_assault = { 255, 250, 150, 20 },

	-- Warpfire
	warpfire = { 255, 120, 200, 255 },
	warp_fire = { 255, 120, 200, 255 },
	psyker_force_staff_quick_attack_debuff = { 255, 120, 200, 255 },

	-- Toxin / poison
	toxin_variant_1 = { 255, 50, 255, 20 },
	toxin_variant_2 = { 255, 50, 255, 20 },
	toxin_variant_3 = { 255, 50, 255, 20 },
	chem_burning = { 255, 50, 255, 20 },
	chem_burning_fast = { 255, 50, 255, 20 },
	chem_burning_slow = { 255, 50, 255, 20 },
	broker_stimm_field = { 255, 50, 255, 20 },
	broker_stimm_field_close = { 255, 50, 255, 20 },
	broker_tox_grenade = { 255, 50, 255, 20 },
	broker_toxin_stacks_stun_interval = { 255, 50, 255, 20 },
	neurotoxin_interval_buff = { 255, 80, 255, 80 },
	neurotoxin_interval_buff2 = { 255, 80, 255, 80 },
	neurotoxin_interval_buff3 = { 255, 80, 255, 80 },
	exploding_toxin_interval_buff = { 255, 80, 255, 80 },
	toxin_damage_debuff = { 255, 80, 255, 80 },
	toxin_damage_debuff_monster = { 255, 80, 255, 80 },

	-- Rending
	rending_debuff = { 255, 185, 85, 255 },
	increase_damage_taken = { 255, 185, 85, 255 },
	increase_impact_received_while_staggered = { 255, 185, 85, 255 },
	increase_damage_received_while_staggered = { 255, 185, 85, 255 },
	adamant_melee_weakspot_hits_count_as_stagger_debuff = { 255, 185, 85, 255 },
	adamant_staggered_enemies_deal_less_damage_debuff = { 255, 185, 85, 255 },
	adamant_staggering_increases_damage_taken = { 255, 185, 85, 255 },

	-- damage taken increased
	veteran_improved_tag_debuff = { 255, 200, 185, 100 },
	ogryn_recieve_damage_taken_increase_debuff = { 255, 200, 185, 100 },
	ogryn_taunt_increased_damage_taken_buff = { 255, 200, 185, 100 },
	ogryn_staggering_damage_taken_increase = { 255, 200, 185, 100 },
	psyker_discharge_damage_debuff = { 255, 200, 185, 100 },
	broker_passive_toxin_infected_enemies_take_increased_damage_debuff = { 255, 200, 185, 100 },

	-- Arbite
	adamant_drone_enemy_debuff = { 255, 180, 180, 255 },
	adamant_drone_talent_debuff = { 255, 180, 180, 255 },

	-- Broker rage debuff
	broker_punk_rage_improved_shout_debuff = { 255, 255, 120, 40 },

	-- Stagger
	shock_grenade_interval = { 255, 100, 200, 255 },

	-- Blinded/smoke
	in_smoke_fog = { 255, 200, 200, 200 },
}

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

local hb_frames = {
	{
		text = "content/ui/materials/frames/masteries/panel_main_lower_frame",
		value = "content/ui/materials/frames/masteries/panel_main_lower_frame",
	},
	{
		text = "content/ui/materials/bars/heavy/frame_back",
		value = "content/ui/materials/bars/heavy/frame_back",
	},
	{
		text = "content/ui/materials/bars/heavy/frame_top",
		value = "content/ui/materials/bars/heavy/frame_top",
	},
	{
		text = "content/ui/materials/frames/masteries/panel_main_top_frame",
		value = "content/ui/materials/frames/masteries/panel_main_top_frame",
	},
	{
		text = "content/ui/materials/bars/simple/frame",
		value = "content/ui/materials/bars/simple/frame",
	},
	{
		text = "content/ui/materials/bars/contracts_progress_overall_fill",
		value = "content/ui/materials/bars/contracts_progress_overall_fill",
	},
	{
		text = "content/ui/materials/frames/talents/talent_icon_container",
		value = "content/ui/materials/frames/talents/talent_icon_container",
	},
	{
		text = "content/ui/materials/frames/difficulty_stepper_frame",
		value = "content/ui/materials/frames/difficulty_stepper_frame",
	},
	{
		text = "content/ui/materials/bars/heavy/frame_effect_electric",
		value = "content/ui/materials/bars/heavy/frame_effect_electric",
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
				30,
				200,
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
		{
			setting_id = "font_type",
			type = "dropdown",
			options = fonts,
			default_value = "mono_tide_bold",
			tooltip = "font_type_tooltip",
		},
		{
			setting_id = "text_scale",
			type = "numeric",
			default_value = 1.15,
			decimals_number = 2,
			step_size_value = 0.1,
			range = {
				0.5,
				1.5,
			},
			tooltip = "text_scale_tooltip",
		},
		{
			setting_id = "main_font_colour",
			type = "group",
			sub_widgets = {
				{
					setting_id = "main_font_colour_R",
					type = "numeric",
					default_value = 220,
					range = {
						0,
						255,
					},
					tooltip = "main_font_colour_tooltip",
				},
				{
					setting_id = "main_font_colour_G",
					type = "numeric",
					default_value = 220,
					range = {
						0,
						255,
					},
					tooltip = "main_font_colour_tooltip",
				},
				{
					setting_id = "main_font_colour_B",
					type = "numeric",
					default_value = 220,
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
					default_value = 180,
					range = {
						0,
						255,
					},
					tooltip = "secondary_font_colour_tooltip",
				},
				{
					setting_id = "secondary_font_colour_G",
					type = "numeric",
					default_value = 180,
					range = {
						0,
						255,
					},
					tooltip = "secondary_font_colour_tooltip",
				},
				{
					setting_id = "secondary_font_colour_B",
					type = "numeric",
					default_value = 180,
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
					default_value = 0,
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
			default_value = true,
			tooltip = "healthbar_type_icon_enable_tooltip",
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
			default_value = false,
			tooltip = "hb_horde_clusters_enable_tooltip",
		},
		{
			setting_id = "hb_hide_after_no_damage",
			type = "checkbox",
			default_value = false,
			tooltip = "hb_hide_after_no_damage_tooltip",
		},
		--[[{
			setting_id = "hb_text_show_health",
			type = "checkbox",
			default_value = true,
			tooltip = "hb_text_show_health_tooltip",
		},]]
		{
			setting_id = "hb_text_show_damage",
			type = "checkbox",
			default_value = false,
			tooltip = "hb_text_show_damage_tooltip",
		},
		{
			setting_id = "hb_show_damage_numbers",
			type = "checkbox",
			default_value = true,
			tooltip = "hb_show_damage_numbers_tooltip",
		},
		{
			setting_id = "hb_damage_number_types",
			type = "dropdown",
			options = damage_number_types,
			default_value = "floating",
			tooltip = "hb_damage_number_types_tooltip",
		},
		--[[{
			setting_id = "hb_show_armour_types",
			type = "checkbox",
			default_value = true,
			tooltip = "hb_show_armour_types_tooltip",
		},]]
		{
			setting_id = "hb_frame",
			type = "dropdown",
			options = hb_frames,
			default_value = "content/ui/materials/frames/masteries/panel_main_lower_frame",
			tooltip = "hb_frame_tooltip",
		},
		{
			setting_id = "hb_padding_scale",
			type = "numeric",
			default_value = 1.25,
			range = {
				0.5,
				3,
			},
			decimals_number = 2,
			step_size_value = 0.1,
			tooltip = "hb_padding_scale_tooltip",
		},
		{
			setting_id = "hb_size_width",
			type = "numeric",
			default_value = 220,
			range = {
				100,
				400,
			},
			tooltip = "hb_size_width_tooltip",
		},
		{
			setting_id = "hb_size_height",
			type = "numeric",
			default_value = 6,
			range = {
				4,
				25,
			},
			tooltip = "hb_size_height_tooltip",
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
			options = enemy_type_options,
			default_value = "enemy_name",
			tooltip = "hb_text_top_left_01_tooltip",
		},
		{
			setting_id = "hb_text_bottom_left_01",
			type = "dropdown",
			options = enemy_type_options,
			default_value = "health",
			tooltip = "hb_text_bottom_left_01_tooltip",
		},
		{
			setting_id = "hb_text_bottom_left_02",
			type = "dropdown",
			options = enemy_type_options,
			default_value = "armour_type",
			tooltip = "hb_text_bottom_left_02_tooltip",
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
			setting_id = "debuff_names",
			type = "checkbox",
			default_value = true,
			tooltip = "debuff_names_tooltip",
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
			setting_id = "debuff_horde_enable",
			type = "checkbox",
			default_value = false,
			tooltip = "debuff_horde_enable_tooltip",
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

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	options = {
		widgets = mod.settings_widgets,
	},
}
