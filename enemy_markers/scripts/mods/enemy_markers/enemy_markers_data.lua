local mod = get_mod("enemy_markers")

-- list of debuffs to show
mod.buffs = {
	-- DoT
	"bleed",
	"flamer_assault",
	"rending_debuff",
	"warp_fire",
	"neurotoxin_interval_buff",
	"neurotoxin_interval_buff2",
	"neurotoxin_interval_buff3",
	"exploding_toxin_interval_buff",
	-- Weapons/Blessings
	"increase_impact_received_while_staggered",
	"increase_damage_received_while_staggered",
	"power_maul_sticky_tick",
	"increase_damage_taken",
	-- Psyker
	"psyker_discharge_damage_debuff",
	"psyker_protectorate_spread_chain_lightning_interval_improved",
	"psyker_protectorate_spread_charged_chain_lightning_interval_improved",
	"psyker_force_staff_quick_attack_debuff",
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
	"toxin_damage_debuff",
	"toxin_damage_debuff_monster",
	-- "stagger",
	-- "suppression",
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
