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
