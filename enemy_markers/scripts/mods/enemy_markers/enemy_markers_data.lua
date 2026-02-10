local mod = get_mod("enemy_markers")

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
						setting_id = "horde_enable",
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
