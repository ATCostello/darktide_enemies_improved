local mod = get_mod("enemy_markers")

-- list of debuffs to show
mod.debuffs = {
	-- DoT (Show above health bar as cool icons with stacks)
	"bleed",
	"flamer_assault",
	"rending_debuff",
	"warp_fire",
	"neurotoxin_interval_buff",
	"neurotoxin_interval_buff2",
	"neurotoxin_interval_buff3",
	"exploding_toxin_interval_buff",

	-- Weapons/Blessings
	--"increase_impact_received_while_staggered",
	--"increase_damage_received_while_staggered",
	--"power_maul_sticky_tick",
	--"increase_damage_taken",

	-- Psyker
	--"psyker_discharge_damage_debuff",
	--"psyker_protectorate_spread_chain_lightning_interval_improved",
	--"psyker_protectorate_spread_charged_chain_lightning_interval_improved",
	--"psyker_force_staff_quick_attack_debuff",

	-- Ogryn
	--"ogryn_recieve_damage_taken_increase_debuff",
	--"ogryn_taunt_increased_damage_taken_buff",
	--"ogryn_staggering_damage_taken_increase",

	-- Veteran
	--"veteran_improved_tag_debuff",

	-- Zealot
	--"zealot_bled_enemies_take_more_damage_effect",

	-- Arbite
	--"adamant_drone_enemy_debuff",
	--"adamant_drone_talent_debuff",
	--"adamant_melee_weakspot_hits_count_as_stagger_debuff",
	--"adamant_staggered_enemies_deal_less_damage_debuff",
	--"adamant_staggering_increases_damage_taken",

	-- Broker
	--"broker_punk_rage_improved_shout_debuff",
	--"toxin_damage_debuff",
	--"toxin_damage_debuff_monster",

	-- "stagger",
	-- "suppression",
}

mod.debuff_icons = {
	-- Weaponry
	melee = "content/ui/materials/icons/weapons/actions/linesman",
	melee_headshot = "content/ui/materials/icons/weapons/actions/smiter",
	headshot = "content/ui/materials/icons/weapons/actions/ads",
	ranged = "content/ui/materials/icons/weapons/actions/hipfire",
	-- Bleeding
	bleed = "content/ui/materials/icons/presets/preset_13",
	-- Electricity
	electricity = "content/ui/materials/icons/presets/preset_11",
	psyker_heavy_swings_shock = "content/ui/materials/icons/presets/preset_11",
	powermaul_p2_stun_interval = "content/ui/materials/icons/presets/preset_11",
	powermaul_p2_stun_interval_basic = "content/ui/materials/icons/presets/preset_11",
	shockmaul_stun_interval_damage = "content/ui/materials/icons/presets/preset_11",
	shock_grenade_stun_interval = "content/ui/materials/icons/presets/preset_11",
	protectorate_force_field = "content/ui/materials/icons/presets/preset_11",
	-- Explosion
	broker_flash_grenade_impact = "content/ui/materials/icons/presets/preset_19",
	explosion = "content/ui/materials/icons/presets/preset_19",
	barrel_explosion_close = "content/ui/materials/icons/presets/preset_19",
	barrel_explosion = "content/ui/materials/icons/presets/preset_19",
	poxwalker_explosion_close = "content/ui/materials/icons/presets/preset_19",
	poxwalker_explosion = "content/ui/materials/icons/presets/preset_19",
	default = "content/ui/materials/icons/presets/preset_19",
	-- Burn
	flame_grenade_liquid_area_fire_burning = "content/ui/materials/icons/presets/preset_20",
	liquid_area_fire_burning_barrel = "content/ui/materials/icons/presets/preset_20",
	liquid_area_fire_burning = "content/ui/materials/icons/presets/preset_20",
	burning = "content/ui/materials/icons/presets/preset_20",
	warpfire = "content/ui/materials/icons/presets/preset_20",
	-- Toxin
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
}

mod.debuff_colours = {
	-- Weaponry
	melee = { 255, 150, 150, 150 },
	melee_headshot = { 255, 150, 150, 150 },
	headshot = { 255, 150, 150, 150 },
	ranged = { 255, 150, 150, 150 },
	-- Bleeding
	bleed = { 255, 255, 0, 0 },
	-- Electricity
	electricity = { 255, 255, 255, 0 },
	psyker_heavy_swings_shock = { 255, 150, 150, 150 },
	powermaul_p2_stun_interval = { 255, 150, 150, 150 },
	powermaul_p2_stun_interval_basic = { 255, 150, 150, 150 },
	shockmaul_stun_interval_damage = { 255, 150, 150, 150 },
	shock_grenade_stun_interval = { 255, 150, 150, 150 },
	protectorate_force_field = { 255, 150, 150, 150 },
	-- Explosion
	broker_flash_grenade_impact = { 255, 150, 150, 150 },
	explosion = { 255, 250, 250, 20 },
	barrel_explosion_close = { 255, 250, 250, 20 },
	barrel_explosion = { 255, 250, 250, 20 },
	poxwalker_explosion_close = { 255, 250, 250, 20 },
	poxwalker_explosion = { 255, 250, 250, 20 },
	default = { 255, 250, 250, 20 },
	-- Burn
	flame_grenade_liquid_area_fire_burning = { 255, 250, 150, 20 },
	liquid_area_fire_burning_barrel = { 255, 250, 150, 20 },
	liquid_area_fire_burning = { 255, 250, 150, 20 },
	burning = { 255, 250, 150, 20 },
	warpfire = { 255, 250, 150, 20 },
	-- Toxin
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
}

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
		text = "content/ui/materials/bars/heavy/frame_effect_smoke",
		value = "content/ui/materials/bars/heavy/frame_effect_smoke",
	},
	{
		text = "content/ui/materials/bars/heavy/frame_effect_electric",
		value = "content/ui/materials/bars/heavy/frame_effect_electric",
	},
	{
		text = "content/ui/materials/frames/masteries/panel_main_top_frame",
		value = "content/ui/materials/frames/masteries/panel_main_top_frame",
	},
	{
		text = "content/ui/materials/effects/masteries/panel_main_lower_frame_candles",
		value = "content/ui/materials/effects/masteries/panel_main_lower_frame_candles",
	},
	{
		text = "content/ui/materials/dividers/skull_center_02",
		value = "content/ui/materials/dividers/skull_center_02",
	},
	{
		text = "content/ui/materials/bars/simple/frame",
		value = "content/ui/materials/bars/simple/frame",
	},
}

local lookup_border_color = function(colour_string)
	local border_colours = {
		["Gold"] = {
			255,
			232,
			188,
			109,
		},
		["Silver"] = {
			255,
			187,
			198,
			201,
		},
		["Steel"] = {
			255,
			161,
			166,
			169,
		},
	}
	return border_colours[colour_string]
end

local apply_color_to_text = function(text, r, g, b)
	return "{#color(" .. r .. "," .. g .. "," .. b .. ")}" .. text .. "{#reset()}"
end

local Gold = lookup_border_color("Gold")
local Silver = lookup_border_color("Silver")
local Steel = lookup_border_color("Steel")

local border_colours = {
	{
		text = apply_color_to_text(mod:localize("Gold"), Gold[2], Gold[3], Gold[4]),
		value = "Gold",
	},
	{
		text = apply_color_to_text(mod:localize("Silver"), Silver[2], Silver[3], Silver[4]),
		value = "Silver",
	},
	{
		text = apply_color_to_text(mod:localize("Steel"), Steel[2], Steel[3], Steel[4]),
		value = "Steel",
	},
}

local chest_icons = {
	{
		text = "Default",
		value = "content/ui/materials/hud/interactions/icons/default",
	},
	{
		text = "Video",
		value = "content/ui/materials/icons/system/settings/category_video",
	},
	{
		text = "Loot",
		value = "content/ui/materials/icons/generic/loot",
	},
}

local luggable_icons = {
	{
		text = "Exclamation",
		value = "content/ui/materials/hud/interactions/icons/environment_alert",
	},
	{
		text = "Hands",
		value = "content/ui/materials/hud/communication_wheel/icons/thanks",
	},
	{
		text = "Fist",
		value = "content/ui/materials/icons/presets/preset_18",
	},
}

local background_colours = {
	{
		text = "Black",
		value = "Black",
	},
	{
		text = "Terminal",
		value = "Terminal",
	},
}

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	options = {
		widgets = {
			{
				setting_id = "general_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id = "los_fade_enable",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "los_opacity",
						type = "numeric",
						default_value = 50,
						range = {
							0,
							100,
						},
					},
					{
						setting_id = "ads_los_opacity",
						type = "numeric",
						default_value = 25,
						range = {
							0,
							100,
						},
					},
					{
						setting_id = "marker_background_colour",
						type = "dropdown",
						options = background_colours,
						default_value = "Black",
					},
				},
			},
			{
				setting_id = "markers_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id = "markers_enable",
						type = "checkbox",
						default_value = true,
					},
				},
			},
			{
				setting_id = "healthbar_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id = "healthbar_enable",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "hb_horde_enable",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "hb_hide_after_no_damage",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "hb_show_damage_numbers",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "hb_show_armour_types",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "hb_frame",
						type = "dropdown",
						options = hb_frames,
						default_value = "content/ui/materials/frames/masteries/panel_main_lower_frame",
					},
					{
						setting_id = "hb_size_width",
						type = "numeric",
						default_value = 200,
						range = {
							100,
							400,
						},
					},
					{
						setting_id = "hb_size_height",
						type = "numeric",
						default_value = 15,
						range = {
							4,
							30,
						},
					},
				},
			},
			{
				setting_id = "debuff_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id = "debuff_enable",
						type = "checkbox",
						default_value = true,
					},
				},
			},
		},
	},
}
