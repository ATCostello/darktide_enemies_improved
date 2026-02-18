local mod = get_mod("enemy_markers")

local loc = {
	mod_name = {
		en = "Enemy Markers, Healthbars and Debuffs Improved",
	},
	mod_description = {
		en = "Adds markers, healthbars and debuff indicators to enemies in an optimised, customisable fashion.",
	},

	-- General Settings
	aio_settings = {
		en = "MARKERS IMPROVED AIO SETTINGS",
		fr = "MARKERS IMPROVED AIO SETTINGS",
		ru = "MARKERS IMPROVED AIO SETTINGS",
		["zh-tw"] = "圖標改善設定",
		["zh-cn"] = "图标改进集成设置",
	},
	los_fade_enable = {
		en = "Fade out icons out of line of sight?",
		fr = "Fade out icons out of line of sight",
		ru = "Fade out icons out of line of sight",
		["zh-tw"] = "視線外淡化圖標",
		["zh-cn"] = "视野外图标淡出",
	},
	los_opacity = {
		en = "Out of Line of sight marker opacity (percentage)",
		fr = "Line of sight alpha (percentage)",
		ru = "Line of sight alpha (percentage)",
		["zh-tw"] = "視線外圖標透明度",
		["zh-cn"] = "视野外图标透明度",
	},
	ads_los_opacity = {
		en = "ADS Line of sight marker opacity (percentage)",
		["zh-tw"] = "瞄準視線外的圖標透明度",
	},
	marker_background_colour = {
		en = "Marker background colour",
		["zh-tw"] = "標記背景顏色",
	},

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
}

local apply_color_to_text = function(text, r, g, b)
	return "{#color(" .. r .. "," .. g .. "," .. b .. ")}" .. text .. "{#reset()}"
end

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

local apply_colours = function()
	-- e.g. key = "Steel", values = "en = 'steel', fr = 'acier' etc"     ->    language = "en", text="Steel"
	for key, values in pairs(loc) do
		-- GENERAL RGB VALUES
		-- check the key contains "colour" but isnt the R/G/B values themselves...
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
					text = apply_color_to_text(text, r, g, b)
					loc[key][language] = text
				end
			end
		end

		-- BORDER COLOURS
		if key == "Gold" or key == "Silver" or key == "Steel" then
			for language, text in pairs(values) do
				local argb = lookup_border_color(key)

				if argb ~= nil then
					local temp = apply_color_to_text(key, argb[2], argb[3], argb[4])

					if loc[temp] == nil then
						loc[temp] = {}
						loc[temp][language] = temp
					else
						loc[temp][language] = temp
					end
				end
			end
		end
	end

	return loc
end

apply_colours()

mod.apply_colours = function()
	loc = apply_colours()
	dbg_loc = loc
	return loc
end

mod.get_loc = function()
	return loc
end

dbg_loc = loc

return loc
