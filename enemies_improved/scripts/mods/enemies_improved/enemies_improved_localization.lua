local mod = get_mod("enemies_improved")
mod.version = "1.4.15"
mod:info("Enemies Improved is installed, using version: " .. tostring(mod.version))

local next = next

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

	for font_name, _ in next, fonts do
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

	for _, data in next, fonts_data do
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

-- Get all enemy names from breeds, to allow specific enemy colour changes.
local Breeds = require("scripts/settings/breed/breeds")
local BreedQueries = require("scripts/utilities/breed_queries")
local minion_breeds = BreedQueries.minion_breeds_by_name()

mod.find_breed_category_by_tags = function(tags)
	if tags then
		if tags.horde or tags.roamer then
			return "horde"
		elseif tags.captain or tags.cultist_captain then
			return "captain"
		elseif tags.witch then
			return "witch"
		elseif tags.monster then
			return "monster"
		elseif tags.disabler then
			return "disabler"
		elseif tags.special and tags.sniper then
			return "sniper"
		elseif tags.elite and tags.far or tags.special and tags.far or tags.elite and tags.close then
			return "far"
		elseif tags.elite then
			return "elite"
		elseif tags.special then
			return "special"
		else
			return "enemy"
		end
	end
end

mod.gather_enemy_names_by_breed_types = function()
	local enemies = {}
	enemies[1] = { text = "SELECT ENEMY", value = "select" }

	local i = 2

	for name, options in next, minion_breeds do
		-- skip things that shouldn't be here
		if name ~= "attack_valkyrie" then
			local tags = options.tags
			local breed_type = mod.find_breed_category_by_tags(tags)

			if breed_type then
				enemies[i] =
					{ text = options.display_name, value = options.name, sort = Localize(options.display_name) }
				i = i + 1
			end
		end
	end

	table.sort(enemies, function(a, b)
		if a.value == "select" and b.value ~= "select" then
			return true
		elseif b.value == "select" and a.value ~= "select" then
			return false
		end

		return a.sort < b.sort
	end)

	return enemies
end

local insert_enemy_names = function(localisation_table)
	local enemies_data = mod.gather_enemy_names_by_breed_types()

	for _, data in next, enemies_data do
		if data.value ~= "select" then
			local new_localised_readable_text = {
				en = Localize(data.text),
			}

			if not localisation_table[data.text] then
				localisation_table[data.text] = new_localised_readable_text
			end
		end
	end
end

-- base localisations
mod.localisation = {
	mod_name = {
		en = "Enemies Improved",
	},
	mod_name_pizazz = {
		en = "{#color("
			.. colours.title
			.. ")} {#color(255,0,0)}E{#color(248,0,14)}n{#color(240,0,29)}e{#color(233,0,43)}m{#color(225,0,57)}i{#color(218,0,71)}e{#color(210,0,86)}s {#color(203,0,100)}I{#color(195,0,114)}m{#color(188,0,129)}p{#color(180,0,143)}r{#color(173,0,157)}o{#color(165,0,171)}v{#color(158,0,186)}e{#color(150,0,200)}d{#reset()}",
		["zh-cn"] = "{#color("
			.. colours.title
			.. ")} {#color(255,0,0)}敌{#color(248,0,14)}人{#color(240,0,29)}增{#color(233,0,43)}强{#reset()}",
	},
	mod_name_boring = {
		en = "Enemies Improved",
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

		["zh-cn"] = "{#color("
			.. colours.text
			.. ")}"
			.. "血条、减益、轮廓、标记、特殊攻击预警等功能，全面优化暗潮敌人显示体验。"
			.. "{#reset()}\n\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}作者: "
			.. "{#color("
			.. colours.text
			.. ")}Alfthebigheaded\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}版本: {#color("
			.. colours.text
			.. ")}"
			.. mod.version
			.. "{#reset()}",
	},
	mod_name_pizazz_toggle = {
		en = "Enable Name Pizazz",
	},
	mod_name_pizazz_tooltip = {
		en = "Toggles the rainbow colours effect on the mod name text. Requires a reload.\nIf enabled, you will get a small euphoric experience everytime you scroll through the mod menu, \nIf disabled - you will be a John Darktide and have no rainbow sprinkles (but I'll love you anyway).",
	},
}

-- Group localisations so they can be managed easier.
local localisations_to_add = {}

-- debuff names and groups localisations
table.insert(localisations_to_add, {
	-- Debuff Groups
	generic = {
		en = "Generic",
	},

	bleed = {
		en = "Bleed",
	},

	fire = {
		en = "Fire",
	},

	warp = {
		en = "Warp",
	},

	shock = {
		en = "Shock/Lightning",
	},

	toxin = {
		en = "Toxin/Poison",
	},

	rending = {
		en = "Rending",
	},

	damage_taken = {
		en = "+ Damage",
	},

	melee_damage_taken = {
		en = "+ Melee Damage",
	},

	stagger_damage = {
		en = "+ Stagger Damage",
	},

	bleed_damage = {
		en = "+ Bleeding Damage",
	},

	toxin_damage = {
		en = "+ Toxin Damage",
	},

	arbites = {
		en = "Arbites",
	},

	rage = {
		en = "Hive Scum",
	},

	stagger = {
		en = "Stagger",
	},

	blind = {
		en = "Blind",
	},

	-- Debuffs Localisation
	bleed = {
		en = "Bleed",
		["zh-cn"] = "流血",
	},
	flamer_assault = {
		en = "Burning",
		["zh-cn"] = "燃烧",
	},
	flame_grenade_liquid_area = {
		en = "Burning (Fire Grenade)",
		["zh-cn"] = "燃烧（燃烧雷）",
	},
	in_smoke_fog = {
		en = "Blinded (Smoke Grenade)",
		["zh-cn"] = "致盲（烟雾雷）",
	},
	warp_fire = {
		en = "Warpfire",
		["zh-cn"] = "亚空间火焰",
	},
	neurotoxin_interval_buff = {
		en = "Neurotoxin",
		["zh-cn"] = "神经毒素",
	},
	neurotoxin_interval_buff2 = {
		en = "Neurotoxin II",
		["zh-cn"] = "神经毒素 II",
	},
	neurotoxin_interval_buff3 = {
		en = "Neurotoxin III",
		["zh-cn"] = "神经毒素 III",
	},
	exploding_toxin_interval_buff = {
		en = "Exploding Toxin",
		["zh-cn"] = "爆炸毒素",
	},

	psyker_discharge_damage_debuff = {
		en = "Increased Damage (Warp Rupture)",
		["zh-cn"] = "增伤（亚空间破裂）",
	},
	psyker_discharge_damage_debuff_abrv = {
		en = "+ Damage",
		["zh-cn"] = "+伤害",
	},
	psyker_force_staff_quick_attack_debuff = {
		en = "Increased Warp Damage (Empyric Shock)",
		["zh-cn"] = "亚空间增伤（帝皇冲击）",
	},
	psyker_force_staff_quick_attack_debuff_abrv = {
		en = "+ Warp Damage",
		["zh-cn"] = "+亚空间伤害",
	},

	toxin_damage_debuff = {
		en = "Weakened (Targeted Toxin)",
		["zh-cn"] = "虚弱（定向毒素）",
	},
	toxin_damage_debuff_monster = {
		en = "Weakened Monster (Targeted Toxin)",
		["zh-cn"] = "虚弱（定向毒素）",
	},

	broker_passive_toxin_infected_enemies_take_increased_damage_debuff = {
		en = "Increased Damage (Virulent Strain)",
		["zh-cn"] = "增伤（剧毒菌株）",
	},
	broker_passive_toxin_infected_enemies_take_increased_damage_debuff_abrv = {
		en = "+ Damage (Toxin)",
		["zh-cn"] = "+伤害（毒素）",
	},

	shock_effect = {
		en = "Electrocuted",
		["zh-cn"] = "触电",
	},

	-- Rending / “take more damage”, tags, etc.
	rending_debuff = {
		en = "Brittleness",
		["zh-cn"] = "碎裂",
	},
	rending_debuff_medium = {
		en = "Brittleness (Medium)",
		["zh-cn"] = "碎裂",
	},
	rending_burn_debuff = {
		en = "Brittleness (Burn)",
		["zh-cn"] = "碎裂",
	},
	saw_rending_debuff = {
		en = "Brittleness (Saw Blade)",
		["zh-cn"] = "碎裂",
	},

	increase_impact_received_while_staggered = {
		en = "Increased Impact Taken",
		["zh-cn"] = "受到冲击提升",
	},
	increase_impact_received_while_staggered_abrv = {
		en = "+ Impact",
		["zh-cn"] = "+冲击",
	},
	increase_damage_received_while_staggered = {
		en = "Increased Damage Taken (Staggered)",
		["zh-cn"] = "受到伤害提升（硬直）",
	},
	increase_damage_received_while_staggered_abrv = {
		en = "+ Damage (Staggered)",
		["zh-cn"] = "+伤害（踉跄）",
	},
	power_maul_sticky_tick = {
		en = "Power Maul Impact",
		["zh-cn"] = "动力锤冲击",
	},
	increase_damage_taken = {
		en = "Increased Damage Taken",
		["zh-cn"] = "受到伤害提升",
	},
	increase_damage_taken_abrv = {
		en = "+ Damage",
		["zh-cn"] = "+伤害",
	},

	-- Psyker utility / chain lightning etc.
	psyker_protectorate_spread_chain_lightning_interval_improved = {
		en = "Chain Lightning (Improved)",
		["zh-cn"] = "连锁闪电",
	},
	psyker_protectorate_spread_charged_chain_lightning_interval_improved = {
		en = "Charged Chain Lightning (Improved)",
		["zh-cn"] = "蓄力连锁闪电",
	},
	psyker_protectorate_spread_chain_lightning_interval = {
		en = "Chain Lightning",
		["zh-cn"] = "连锁闪电",
	},
	psyker_protectorate_spread_charged_chain_lightning_interval = {
		en = "Charged Chain Lightning",
		["zh-cn"] = "蓄力连锁闪电",
	},
	psyker_heavy_swings_shock = {
		en = "Charged Strike",
		["zh-cn"] = "蓄力打击",
	},
	psyker_heavy_swings_shock_improved = {
		en = "Charged Strike (Improved)",
		["zh-cn"] = "蓄力打击",
	},

	-- Ogryn
	ogryn_recieve_damage_taken_increase_debuff = {
		en = "Increased Damage Taken (Soften Them Up)",
		["zh-cn"] = "受到伤害提升（削弱敌人）",
	},
	ogryn_recieve_damage_taken_increase_debuff_abrv = {
		en = "+ Damage",
		["zh-cn"] = "+伤害",
	},
	ogryn_taunt_increased_damage_taken_buff = {
		en = "Increased Damage Taken (Valuable Distraction)",
		["zh-cn"] = "受到伤害提升（宝贵牵制）",
	},
	ogryn_taunt_increased_damage_taken_buff_abrv = {
		en = "+ Damage",
		["zh-cn"] = "+伤害",
	},
	ogryn_staggering_damage_taken_increase = {
		en = "Increased Melee Damage Taken (Hard Knocks)",
		["zh-cn"] = "近战伤害提升（沉重打击）",
	},
	ogryn_staggering_damage_taken_increase_abrv = {
		en = "+ Melee Damage",
		["zh-cn"] = "+近战伤害",
	},

	-- Veteran
	veteran_improved_tag_debuff = {
		en = "Increased Damage Taken (Tagged Target)",
		["zh-cn"] = "受到伤害提升（标记目标）",
	},
	veteran_improved_tag_debuff_abrv = {
		en = "+ Damage",
		["zh-cn"] = "+伤害",
	},

	-- Zealot
	zealot_bled_enemies_take_more_damage_effect = {
		en = "Increased Damage Taken (Bleeding)",
		["zh-cn"] = "受到伤害提升（流血）",
	},
	zealot_bled_enemies_take_more_damage_effect_abrv = {
		en = "+ Damage (Bleeding)",
		["zh-cn"] = "+伤害（流血）",
	},

	-- Arbite
	adamant_drone_enemy_debuff = {
		en = "Drone Marked",
		["zh-cn"] = "无人机标记",
	},
	adamant_drone_talent_debuff = {
		en = "Drone Suppressed",
		["zh-cn"] = "无人机压制",
	},
	adamant_melee_weakspot_hits_count_as_stagger_debuff = {
		en = "Weakspot Stagger",
		["zh-cn"] = "弱点硬直",
	},
	adamant_staggered_enemies_deal_less_damage_debuff = {
		en = "Weak (Suppression Force)",
		["zh-cn"] = "虚弱（压制力）",
	},
	adamant_staggering_increases_damage_taken = {
		en = "Increased Damage (Break Dissent)",
		["zh-cn"] = "增伤（粉碎异心）",
	},
	adamant_staggering_increases_damage_taken_abrv = {
		en = "+ Damage (Staggered)",
		["zh-cn"] = "+伤害（踉跄）",
	},

	-- Broker
	broker_punk_rage_improved_shout_debuff = {
		en = "Forge's Bellow",
		["zh-cn"] = "熔炉咆哮",
	},

	shock_grenade_interval = {
		en = "Shock Grenade Stagger",
		["zh-cn"] = "震撼手雷硬直",
	},
})

-- enemy type localisations
table.insert(localisations_to_add, {
	["SELECT AN ENEMY TYPE"] = {
		en = "SELECT AN ENEMY TYPE",
		["zh-cn"] = "选择敌人类型",
	},
	select = {
		en = "SELECT AN ENEMY TYPE",
		["zh-cn"] = "选择敌人类型",
	},
	monster = {
		en = "miniboss",
		["zh-cn"] = "小BOSS",
	},
	captain = {
		en = "boss",
		["zh-cn"] = "BOSS",
	},
	disabler = {
		en = "disabler",
		["zh-cn"] = "控制专家",
	},
	witch = {
		en = "daemonhost",
		["zh-cn"] = "恶魔宿主",
	},
	sniper = {
		en = "sniper",
		["zh-cn"] = "狙击手",
	},
	far = {
		en = "ranged elite",
		["zh-cn"] = "远程精英",
	},
	elite = {
		en = "melee elite",
		["zh-cn"] = "近战精英",
	},
	special = {
		en = "special",
		["zh-cn"] = "输出专家",
	},
	horde = {
		en = "horde",
		["zh-cn"] = "尸潮怪",
	},
	enemy = {
		en = "ritualist",
		["zh-cn"] = "仪式者",
	},
})

-- damage  number type localisations
table.insert(localisations_to_add, {
	readable = {
		en = "Readable",
		["zh-cn"] = "清晰",
	},
	floating = {
		en = "floating",
		["zh-cn"] = "浮动",
	},
	flashy = {
		en = "flashy",
		["zh-cn"] = "炫丽",
	},
})

-- frame options localisations
table.insert(localisations_to_add, {
	panel_main_lower_frame = {
		en = "Gritty texture",
		["zh-cn"] = "粗糙纹理",
	},
	heavy_frame_back = {
		en = "No Frame",
		["zh-cn"] = "无框",
	},
	heavy_frame_top = {
		en = "Riveted panel",
		["zh-cn"] = "铆钉面板",
	},
	simple = {
		en = "Simple black box",
		["zh-cn"] = "简约黑框",
	},
	contracts_progress_overall_fill = {
		en = "White box",
		["zh-cn"] = "白色框体",
	},
})

-- enemy type options localisations
table.insert(localisations_to_add, {
	enemy_type = {
		en = "Enemy Type",
		["zh-cn"] = "敌人类型",
	},
	enemy_name = {
		en = "Name",
		["zh-cn"] = "名称",
	},
	armour_type = {
		en = "Armour Type",
		["zh-cn"] = "护甲类型",
	},
	health = {
		en = "Current Health",
		["zh-cn"] = "当前血量",
	},
	nothing = {
		en = "Don't Show",
		["zh-cn"] = "不显示",
	},
})

-- general settings localisations
table.insert(localisations_to_add, {
	general_settings = {
		en = "{#color(" .. colours.title .. ")}General Settings{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}通用设置{#reset()}",
	},
	draw_distance = {
		en = "Draw Distance (Global)",
		["zh-cn"] = "显示距离（全局）",
	},
	draw_distance_tooltip = {
		en = "The distance (in Metres) from the player to draw enemy information.\nThis setting is global and will effect all enemy types.",
		["zh-cn"] = "显示敌人信息的最大距离（米）。\n此为全局设置，影响所有敌人类型。",
	},
	global_opacity = {
		en = "Global Opacity",
		["zh-cn"] = "全局透明度",
	},
	global_opacity_tooltip = {
		en = "Set a global opacity slider for Enemies Improved UI elements. This will scale the opacity of all elements from their max (1) to their minimal value (0.1).",
		["zh-cn"] = "设置模组UI全局透明度。所有元素透明度将按此比例缩放（0.1~1）。",
	},
	enable_depth_fading = {
		en = "Distance Fading?",
		["zh-cn"] = "距离渐隐",
	},
	enable_depth_fading_tooltip = {
		en = "Toggle distance fading for all Enemies Improved UI elements, so that enemies far away will be more transparent than closer ones. Also includes 'stack fading' which fades out UI elements for enemies that are behind other enemies, so that the closer enemy is easier to see.",
		["zh-cn"] = "开启后远处敌人UI会更透明，同时后方敌人UI会渐隐，优先显示近处敌人。",
	},
	check_line_of_sight = {
		en = "Check for line of sight?",
		["zh-cn"] = "检查视线",
	},
	check_line_of_sight_tooltip = {
		en = "Require line of sight checks for enemies?",
		["zh-cn"] = "仅在能直接看到敌人时显示UI。",
	},
	outlines_enable = {
		en = "Enable Outlines (Global)",
		["zh-cn"] = "启用轮廓（全局）",
	},
	outlines_enable_tooltip = {
		en = "Global toggle for outlines of enemies. Specific enemy types may be disabled or configured further below.",
		["zh-cn"] = "全局开关敌人轮廓，可在下方单独配置各类型敌人。",
	},
	font_type = {
		en = "Choose a font style (Global)",
		["zh-cn"] = "字体样式（全局）",
	},
	font_type_tooltip = {
		en = "The global font style to use. This will apply to all text elements from Enemies Improved.",
		["zh-cn"] = "模组所有文本使用的统一字体。",
	},
	font_no_longer_available = {
		en = "Selected font type is no longer available, resetting to a default option.",
	},
	text_scale = {
		en = "Scale the text sizes (Global)",
		["zh-cn"] = "文本缩放（全局）",
	},
	text_scale_tooltip = {
		en = "A global scale that applies to ALL text used in Enemies Improved. Think of this is an 'x' scaler. E.g. a value of 1.2 is 1.2x the font sizes. ",
		["zh-cn"] = "所有文本大小的全局倍率，例如1.2=1.2倍大小。",
	},
	main_font_colour = {
		en = "Colour for main text font (Global)",
		["zh-cn"] = "主文本颜色（全局）",
	},
	main_font_colour_R = {
		en = "Main Font: Red",
		["zh-cn"] = "主文本：红",
	},
	main_font_colour_G = {
		en = "Main Font: Green",
		["zh-cn"] = "主文本：绿",
	},
	main_font_colour_B = {
		en = "Main Font: Blue",
		["zh-cn"] = "主文本：蓝",
	},
	secondary_font_colour_tooltip = {
		en = "Pick a colour to apply as the 'secondary' font colour throughout enemies improved elements.",
		["zh-cn"] = "设置次要文本的全局颜色。",
	},
	secondary_font_colour = {
		en = "Colour for secondary text font (Global)",
		["zh-cn"] = "次要文本颜色（全局）",
	},
	secondary_font_colour_R = {
		en = "Main Font: Red",
		["zh-cn"] = "次要文本：红",
	},
	secondary_font_colour_G = {
		en = "Main Font: Green",
		["zh-cn"] = "次要文本：绿",
	},
	secondary_font_colour_B = {
		en = "Main Font: Blue",
		["zh-cn"] = "次要文本：蓝",
	},
	secondary_font_colour_tooltip = {
		en = "Pick a colour to apply as the 'secondary' font colour throughout enemies improved elements.",
		["zh-cn"] = "选择用于敌人增强模组所有元素的次要字体颜色。",
	},
})

-- special attacks settings localisations
table.insert(localisations_to_add, {
	special_attack_settings = {
		en = "{#color(" .. colours.title .. ")}Special Attacks{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}特殊攻击{#reset()}",
	},
	marker_specials_enable = {
		en = "Toggle overhead markers special attack indicators (Global)",
		["zh-cn"] = "启用头顶标记预警（全局）",
	},
	marker_specials_enable_tooltip = {
		en = "Affects only 'Enemy Overhead Markers'. \nApplies a pulsating effect when a special attack is detected, to help you get out of the way!",
		["zh-cn"] = "仅作用于头顶标记。\n敌人释放特殊攻击时标记闪烁，提醒躲避。",
	},
	outline_specials_enable = {
		en = "Toggle enemy outline special attack indicators (Global)",
		["zh-cn"] = "启用轮廓预警（全局）",
	},
	outline_specials_enable_tooltip = {
		en = "Applies an outline effect when a special attack is detected, to help distinguish a 'special attack' enemy from a crowd.",
		["zh-cn"] = "敌人释放特殊攻击时高亮轮廓，便于在人群中识别。",
	},
	healthbar_specials_enable = {
		en = "Toggle healthbar special attack indicators (Global)",
		["zh-cn"] = "启用血条预警（全局）",
	},
	healthbar_specials_enable_tooltip = {
		en = "Toggle special attack indicators on the healthbar. \nApplies a pulsating effect when a special attack is detected, to help you get out of the way!",
		["zh-cn"] = "敌人释放特殊攻击时血条闪烁提醒。",
	},
	specials_flash = {
		en = "Enable flashing for special attacks (Global)",
		["zh-cn"] = "启用闪烁效果（全局）",
	},
	specials_flash_tooltip = {
		en = "Applies a flashing effect to the special attack indicators. \n\nDisable for a solid colour instead.",
		["zh-cn"] = "开启预警闪烁，关闭则为纯色显示。",
	},
	special_attack_pulse_speed = {
		en = "Special Attack Pulse Speed",
		["zh-cn"] = "预警闪烁速度",
	},
	special_attack_pulse_speed_tooltip = {
		en = "Set a speed for the flashing of the special attack warnings. With a lower value being faster flashing.",
		["zh-cn"] = "数值越低，闪烁速度越快。",
	},
	outline_specials_colour = {
		en = "Colour for special attacks (Global)",
		["zh-cn"] = "特殊攻击颜色（全局）",
	},
	outline_specials_colour_tooltip = {
		en = "Adjust the colour to apply to all indicators for special attacks.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
		["zh-cn"] = "设置所有特殊攻击预警的颜色，数值0~255。",
	},
	outline_specials_colour_R = {
		en = "Special Attack Colour: Red",
		["zh-cn"] = "预警颜色：红",
	},
	outline_specials_colour_G = {
		en = "Special Attack Colour: Green",
		["zh-cn"] = "预警颜色：绿",
	},
	outline_specials_colour_B = {
		en = "Special Attack Colour: Blue",
		["zh-cn"] = "预警颜色：蓝",
	},
})

-- Overhead Enemy Markers settings
table.insert(localisations_to_add, {
	markers_settings = {
		en = "{#color(" .. colours.title .. ")}Enemy Overhead Markers{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}敌人头顶标记{#reset()}",
	},
	markers_enable = {
		en = "Enable Overhead Markers?",
		["zh-cn"] = "启用头顶标记",
	},
	markers_enable_tooltip = {
		en = "Toggles a diamond shape overhead marker for enemies, which can be used to help pin-point specific enemy locations from afar or in a group.",
		["zh-cn"] = "在敌人头顶显示菱形标记，便于远距离或人群中定位目标。",
	},
	markers_horde_enable = {
		en = "Enable Overhead Markers for horde enemies?",
		["zh-cn"] = "尸潮怪显示头顶标记",
	},
	markers_horde_enable_tooltip = {
		en = "Enables the overhead marker for horde enemies, such as poxwalkers.",
		["zh-cn"] = "为疫变步行者等尸潮怪显示头顶标记。",
	},
	marker_size = {
		en = "Marker Scale",
	},
	marker_size_tooltip = {
		en = "Adjust the scale of the overhead marker.",
	},
	markers_health_enable = {
		en = "Toggle simple health tracker",
	},
	markers_health_enable_tooltip = {
		en = "Toggles a simple quadrant-based (25, 50, 75, 100) health tracker on the overhead marker. \n\nUses the healthbar colours. \n\nCan be useful if you want a minimal way to get an insight on the health of enemies.",
	},
	marker_y_offset = {
		en = "Adjust Y offset for overhead markers",
	},
	marker_y_offset_tooltip = {
		en = "Sets the Y offset or height from the ground for the overhead markers.",
	},
	marker_bg_colour = {
		en = "Colour for marker background",
	},
	marker_bg_colour_A = {
		en = "Alpha",
	},
	marker_bg_colour_R = {
		en = "Red",
	},
	marker_bg_colour_G = {
		en = "Green",
	},
	marker_bg_colour_B = {
		en = "Blue",
	},
	marker_bg_colour_tooltip = {
		en = "Select a colour for the background of the overhead markers.",
	},
})

-- Healthbar settings
table.insert(localisations_to_add, {
	healthbar_settings = {
		en = "{#color(" .. colours.title .. ")}Healthbars{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}血条{#reset()}",
	},
	healthbar_text_settings = {
		en = "{#color(" .. colours.title .. ")}Healthbar Text Options{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}血条文本设置{#reset()}",
	},
	healthbar_enable = {
		en = "Enable Healthbars? (Global)",
		["zh-cn"] = "启用血条（全局）",
	},
	healthbar_enable_tooltip = {
		en = "Globally toggles healthbars for enemies. Specific enemy types can be enabled/disabled further below.",
		["zh-cn"] = "全局开关敌人血条，可在下方单独配置各类型。",
	},
	hb_y_offset = {
		en = "Adjust Y offset for healthbars",
	},
	hb_y_offset_tooltip = {
		en = "Sets the Y offset or height from the ground for the healthbars.",
	},
	hb_text_show_max_health = {
		en = "Show Max Health?",
	},
	hb_text_show_max_health_tooltip = {
		en = "Toggles displaying the max health on the current health text elements.",
	},
	hb_gap_padding_scale = {
		en = "Healthbar widget gap scale",
	},
	hb_gap_padding_scale_tooltip = {
		en = "Adjust the scale of the gap between the healthbar widgets. A lower number will make the text elements closer and 'tighter'.",
	},
	healthbar_type_icon_enable = {
		en = "Enable healthbar enemy type icon?",
		["zh-cn"] = "显示敌人类型图标",
	},
	healthbar_type_icon_enable_tooltip = {
		en = "Toggles a class-based icon next to the healthbar as an option to track enemy types from afar.",
		["zh-cn"] = "在血条旁显示敌人类型图标，便于远距离识别。",
	},
	hb_toggle_ghostbar = {
		en = "Enable Ghost Healthbar?",
	},
	hb_toggle_ghostbar_tooltip = {
		en = "Toggles a dark 'ghost' bar next to the current health bar, when you deal large amounts of damage to an enemy.",
	},
	hb_padding_scale = {
		en = "Scale for the decorative frame around the healthbar (Global)",
		["zh-cn"] = "血条外框缩放（全局）",
	},
	hb_padding_scale_tooltip = {
		en = "A global scale for the decorative frame element around the enemies current health.\n\n1 = Default\n2 = 2x size ",
		["zh-cn"] = "血条装饰外框的全局大小，1=默认，2=双倍。",
	},
	hb_text_top_left_01 = {
		en = "Above Healthbar Text option",
		["zh-cn"] = "血条上方文本",
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
		["zh-cn"] = "选择血条上方显示内容：\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}敌人类型：{#reset()}精英、特殊怪等\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}敌人名称：{#reset()}碾碎者、疫变者等\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}护甲类型：{#reset()}甲壳、防弹甲、无甲等",
	},
	hb_text_bottom_left_01 = {
		en = "Below Healthbar Text option 1",
		["zh-cn"] = "血条下方文本1",
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
		["zh-cn"] = "选择血条下方第一行显示内容。",
	},
	hb_text_bottom_left_02 = {
		en = "Below Healthbar Text option 2",
		["zh-cn"] = "血条下方文本2",
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
		["zh-cn"] = "选择血条下方第二行显示内容。",
	},

	healthbar_segments_enable = {
		en = "Toggle Healthbar Segments",
	},
	healthbar_segments_enable_tooltip = {
		en = "Adds small lines to the healthbar to indicate percentages of 25, 50 and 75.",
	},
	hb_horde_enable = {
		en = "Enable individual horde healthbars?",
		["zh-cn"] = "尸潮怪显示独立血条",
	},
	hb_horde_enable_tooltip = {
		en = "Toggles individual healthbars for horde enemies.\nWarning: This can have a hit to performance if staring directly at a large group of horde enemies, without the clustering enabled.",
		["zh-cn"] = "为每个尸潮小怪显示独立血条。",
	},
	hb_horde_clusters_enable = {
		en = "Enable clustered horde healthbars?",
		["zh-cn"] = "尸潮血条聚合",
	},
	hb_horde_clusters_enable_tooltip = {
		en = "Toggles clustered healthbars for horde enemies.\nThis works when there is a large gathering of 'horde' type enemies in close proximity.\n\nTheir healthbar will combine into one large healthbar and follow around the horde.",
		["zh-cn"] = "大量尸潮怪聚集时，合并为一个聚合血条。",
	},
	hb_hide_after_no_damage = {
		en = "Hide healthbars after no damage received?",
		["zh-cn"] = "无伤害后隐藏血条",
	},
	hb_hide_after_no_damage_tooltip = {
		en = "Toggle hiding of healthbars for non-horde enemies after a short delay of no damage taken. Can be used to reduce visual clutter.\n\nIf disabled, healthbars will always be visible.",
		["zh-cn"] = "停止攻击后短暂延迟自动隐藏血条，减少画面杂乱。关闭则永久显示。",
	},
	hb_horde_hide_after_no_damage = {
		en = "Hide horde healthbars after no damage received?",
	},
	hb_horde_hide_after_no_damage_tooltip = {
		en = "Toggle hiding of healthbars for horde enemies after a short delay of no damage taken. Can be used to reduce visual clutter.\n\nIf disabled, healthbars will always be visible.",
	},
	damage_number_settings = {
		en = "{#color(" .. colours.title .. ")}Damage Numbers{#reset()}",
	},
	hb_show_damage_numbers = {
		en = "Show damage numbers?",
		["zh-cn"] = "显示浮动伤害数字",
	},
	hb_show_damage_numbers_tooltip = {
		en = "Toggles damage numbers when attacking enemies showing how much damage you are dealing.\n\nSee 'Damage type' for more options.",
		["zh-cn"] = "攻击敌人时显示伤害数值，可在下方选择样式。",
	},
	hb_damage_numbers_track_friendly = {
		en = "Show Friendly Damage?",
	},
	hb_damage_numbers_track_friendly_tooltip = {
		en = "Whether damage on enemies will be shown if friendly players harm them, or if damage should only show if you are the one to damage the enemy.",
	},
	hb_damage_numbers_add_total = {
		en = "Add together damage numbers",
	},
	hb_damage_numbers_add_total_tooltip = {
		en = "Whether the damage numbers in a small timeframe should be added together into one larger number, or if each damage should be shown individually.",
	},
	hb_damage_show_only_latest = {
		en = "Only show last damaged enemies?",
	},
	hb_damage_show_only_latest_tooltip = {
		en = "Toggle showing the healthbars of only the last damaged enemies. See below for a slider to control how many last damaged enemies to track.",
	},
	hb_damage_show_only_latest_value = {
		en = "Number of last damaged enemies to track",
	},
	hb_damage_show_only_latest_value_tooltip = {
		en = "Set the amount of last damaged enemies to track for the 'Only show last damaged enemies' setting.\n\nSetting this too low may cause a flickering effect, as damage-over-time effects still count as player damage.",
	},
	hb_text_show_health = {
		en = "Show current health on healthbar?",
		["zh-cn"] = "显示当前血量数值",
	},
	hb_text_show_damage_tooltip = {
		en = "Toggles a text-based indicator near the healthbar showing the current health and max health.",
		["zh-cn"] = "在血条旁显示当前/最大血量。",
	},
	hb_text_show_damage = {
		en = "Show current damage next to health?",
		["zh-cn"] = "显示伤害数值",
	},
	hb_text_show_damage_tooltip = {
		en = "Toggles a text-based indicator alongside the current/max health displaying current damage received.",
		["zh-cn"] = "在血量旁显示已承受伤害。",
	},
	hb_damage_number_types = {
		en = "Damage type",
		["zh-cn"] = "伤害数字样式",
	},
	hb_damage_number_types_tooltip = {
		en = "Options for the varying forms of damage numbers.\n\nTry them out in the range to see which one suits you best!",
		["zh-cn"] = "选择伤害数字显示样式，可在靶场测试效果。",
	},
	hb_show_armour_types = {
		en = "Show armour type",
		["zh-cn"] = "显示护甲类型",
	},
	hb_show_armour_types_tooltip = {
		en = "Toggles a text-based indicator near the healthbar showing the type of armour you hit when damaging enemies.\n\nCan be useful to see what weapons to use.",
		["zh-cn"] = "显示攻击命中的护甲类型，便于选择对应武器。",
	},
	hb_frame = {
		en = "Healthbar background frame",
		["zh-cn"] = "血条背景框",
	},
	hb_frame_tooltip = {
		en = "A section of frames that are used as a background for the healthbars.\n\nTry them out to see the difference.",
		["zh-cn"] = "选择血条背景框样式，可切换查看效果。",
	},
	hb_size_width = {
		en = "Healthbar width",
		["zh-cn"] = "血条宽度",
	},
	hb_size_width_tooltip = {
		en = "The max width of the healthbar.\n\nThe information scales with this too, so try different sizes to see what suits you best.",
		["zh-cn"] = "血条最大宽度，文本会随宽度自动适配。",
	},
	hb_size_height = {
		en = "Healthbar height",
		["zh-cn"] = "血条高度",
	},
	hb_size_height_tooltip = {
		en = "The max height of the healthbar.\n\nThe information scales with this too, so try different sizes to see what suits you best.",
		["zh-cn"] = "血条最大高度，文本会随高度自动适配。",
	},
	damage_number_duration = {
		en = "Duration to show numbers",
	},
	damage_number_duration_tooltip = {
		en = "Set a duration for damage numbers to show for.\n\nThe numbers will fade out after this amount of time.",
	},
	hb_ghostbar_opacity = {
		en = "Ghostbar opacity",
	},
	hb_ghostbar_opacity_tooltip = {
		en = "Adjust the opacity of the ghostbar. 0 = transparent, 1 = opaque.",
	},
	hb_toggle_ghostbar_colour = {
		en = "Ghostbar uses colour?",
	},
	hb_toggle_ghostbar_colour_tooltip = {
		en = "Should the ghostbar use the colour of the healthbar of the enemy?\n\nIf disabled, the ghostbar will be white.",
	},
	readable_max_damage_numbers = {
		en = "Max numbers to show",
	},
	readable_max_damage_numbers_tooltip = {
		en = "Set a cap for the max damage numbers to show for the Readable damage number type.",
	},
	toughness_colour = {
		en = "Toughness Bar Settings",
	},
	toughness_enabled = {
		en = "Toggle Toughness Features",
	},
	toughness_enabled_tooltip = {
		en = "Overlays a toughness bar over the healthbar if the enemy has toughness.",
	},
	toughness_colour_tooltip = {
		en = "Select a colour for the toughness bar.",
	},
	toughness_colour_R = {
		en = "Toughness Bar: Red",
	},
	toughness_colour_G = {
		en = "Toughness Bar: Green",
	},
	toughness_colour_B = {
		en = "Toughness Bar: Blue",
	},
	toughness_text_enabled = {
		en = "Adjust health text to show the toughness values?",
	},
	toughness_text_enabled_tooltip = {
		en = "Swaps out the healtbar text 'health' options to their toughness, if the enemy has toughness.",
	},
	toughness_text_colour_enabled = {
		en = "Change health text to use toughness colour?",
	},
	toughness_text_colour_enabled_tooltip = {
		en = "Swaps out the healtbar text 'health' colour to the toughness colour, if the enemy has toughness.",
	},
	hb_show_dps = {
		en = "Show DPS",
	},
	hb_show_dps_tooltip = {
		en = "Displays a brief damage-per-second text element after you kill an enemy.\n\nUses the damage number duration as a timer for how long to display.",
	},
	damage_number_scale = {
		en = "Damage number scale",
	},
	damage_number_scale_tooltip = {
		en = "Adjust the scale of the damage numbers. Multiplies with the global text scale too...",
	},
	damage_number_y_offset = {
		en = "Damage number y offset",
	},
	damage_number_y_offset_tooltip = {
		en = "Adjust the up/down position of the damage numbers. \n\nA value of 0 will be close to the top of the enemy, the higher the value, the lower the position. Only effects the floating or flashy damage numbers.",
	},
	healthbar_type_icon_scale = {
		en = "Type icon scale",
	},
	healthbar_type_icon_scale_tooltip = {
		en = "Adjust the scale of the type icon.",
	},
})

-- Debuff settings
table.insert(localisations_to_add, {
	debuff_settings = {
		en = "{#color(" .. colours.title .. ")}Debuffs{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}减益效果{#reset()}",
	},
	debuff_enable = {
		en = "Enable debuffs (Global)",
		["zh-cn"] = "启用减益（全局）",
	},
	debuff_enable_tooltip = {
		en = "Global toggle for debuff display.\n\nDebuffs are grouped into two categories, Damage over Time (DoT) and Utility. DoT debuffs are displayed upwards, whereas utility debuffs display downwards.\n\nDoT debuffs include things like bleeding, fire, electricity. Whereas utility includes rending, talent debuffs etc.",
		["zh-cn"] = "全局开关减益显示。\n减益分为持续伤害（向上显示）和功能减益（向下显示）。\n持续伤害：流血、燃烧、触电；功能减益：碎裂、增伤、虚弱等。",
	},
	debuff_dot_enable = {
		en = "Enable Damage-Over-Time debuffs",
		["zh-cn"] = "显示持续伤害减益",
	},
	debuff_dot_enable_tooltip = {
		en = "DoT debuffs are displayed upwards and include things like bleeding, fire, electricity.",
		["zh-cn"] = "流血、燃烧、触电等持续伤害效果向上显示。",
	},
	debuff_utility_enable = {
		en = "Enable Utility debuffs",
		["zh-cn"] = "显示功能减益",
	},
	debuff_utility_enable_tooltip = {
		en = "Utility debuffs are displayed downwards and include things like rending, damage increases, weakening.",
		["zh-cn"] = "碎裂、增伤、虚弱等功能效果向下显示。",
	},
	split_debuff_types = {
		en = "Split DoT and Utility debuffs?",
		["zh-cn"] = "分离持续伤害与功能型减益？",
	},
	split_debuff_types_tooltip = {
		en = "Choose to split the damage-over-time and utility debuffs into two different groups, or to keep them together as one group.",
		["zh-cn"] = "选择将持续伤害减益与功能型减益分为两组，或合并为一组显示。",
	},
	debuff_names = {
		en = "Show Debuff Names",
		["zh-cn"] = "显示减益名称",
	},
	debuff_names_tooltip = {
		en = "Toggles a text display of different debuffs applied to enemies.",
		["zh-cn"] = "显示敌人身上的减益效果文本。",
	},
	debuffs_abrv = {
		en = "Abbreviate Debuff Names?",
		["zh-cn"] = "减益名称缩写",
	},
	debuffs_abrv_tooltip = {
		en = "Should the debuff names use abbreviated (shortend) versions if available? \nIf disabled, the full text name will show - with the talent name too. e.g. 'Increased Damage Taken (Soften Them Up)' \nIf enabled, it will be shortened to just the effect e.g. '+ Damage'",
		["zh-cn"] = "开启后使用缩写（如+伤害），关闭则显示完整名称。",
	},
	debuffs_combine = {
		en = "Combine similar debuffs?",
		["zh-cn"] = "合并同类减益",
	},
	debuffs_combine_tooltip = {
		en = "Should multiple debuffs that apply a similar effect be combined into one entry?\nFor example, if enabled, multiple '+ Damage Taken' debuffs applied via different sources would combine into one value.",
		["zh-cn"] = "多个同类增伤/减益合并显示为一个数值。",
	},
	debuff_names_fade = {
		en = "Fade out debuffs",
		["zh-cn"] = "减益自动淡出",
	},
	debuff_names_fade_tooltip = {
		en = "Toggles fading out of the text-based debuff names after a short delay.\n\nIf this is disabled, debuff names will always show when applied.",
		["zh-cn"] = "减益效果短暂显示后自动消失，关闭则持续显示。",
	},
	debuff_show_on_body = {
		en = "Show debuffs on body of enemy?",
		["zh-cn"] = "减益显示在敌人身上",
	},
	debuff_show_on_body_tooltip = {
		en = "Toggles positioning of the debuff tracker.\n\nIf enabled, the debuffs will be displays in the middle of the enemy model, allowing for easier tracking - but may get in the way.\n\nIf disabled, the debuffs will be placed alongside the healthbar above the head of the enemy.",
		["zh-cn"] = "开启：减益显示在敌人身体中央；关闭：显示在头顶血条旁。",
	},
	debuff_horde_enable = {
		en = "Enable debuffs for horde enemies?",
		["zh-cn"] = "尸潮怪显示减益",
	},
	debuff_horde_enable_tooltip = {
		en = "Toggle to show debuffs for horde enemies.\nWarning: This can have a hit to performance if staring directly at a large group of horde enemies.",
		["zh-cn"] = "为尸潮小怪显示减益效果。",
	},
	debuff_toggles = {
		en = "Choose a debuff to toggle",
	},
	debuff_toggles_tooltip = {
		en = "Pick a debuff here to be able to toggle it on or off in the option below.",
	},
	debuff_selected_enable = {
		en = "Selected debuff toggle",
	},
	debuff_selected_enable_tooltip = {
		en = "Toggle the selected debuff on or off.",
	},
	debuff_icons = {
		en = "Toggle Debuff Icons",
	},
	debuff_icons_tooltip = {
		en = "Decide whether to show the debuff icons or not.",
	},
	debuff_stacks_icon_colour = {
		en = "Debuff Stacks use Icon Colour?",
	},
	debuff_stacks_icon_colour_tooltip = {
		en = "Decide whether to use the debuff icon category colour on the stack/percentage display?",
	},

	debuff_group_colour = {
		en = "Debuff Group Overrides",
	},
	debuff_group_selected = {
		en = "Debuff Group",
	},
	debuff_group_selected_tooltip = {
		en = "Select a debuff group to adjust settings for.",
	},
	debuff_group_colour_R = {
		en = "Debuff Icon Colour: Red",
	},
	debuff_group_colour_G = {
		en = "Debuff Icon Colour: Green",
	},
	debuff_group_colour_B = {
		en = "Debuff Icon Colour: Blue",
	},
	debuff_group_colour_tooltip = {
		en = "Adjust the colour of the chosen debuff group above.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
	},
	debuff_max_stacks_colour = {
		en = "Debuff Max Stacks Settings",
	},
	debuff_max_stacks_colour_tooltip = {
		en = "Adjust the colour of the stack text when at max stacks.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
	},
	debuff_max_stacks_scale = {
		en = "Increase text scale?",
	},
	debuff_max_stacks_scale_tooltip = {
		en = "Increases the scale of the text for stacks that are at their max stacks value.",
	},
	debuff_max_stacks_colour_toggle = {
		en = "Toggle max stacks colour?",
	},
	debuff_max_stacks_colour_toggle_tooltip = {
		en = "Toggle to adjust the colour of the stacks when at max stacks.",
	},
	debuff_max_stacks_colour_R = {
		en = "Debuff Max Stacks Colour: Red",
	},
	debuff_max_stacks_colour_G = {
		en = "Debuff Max Stacks Colour: Green",
	},
	debuff_max_stacks_colour_B = {
		en = "Debuff Max Stacks Colour: Blue",
	},
	debuff_x_offset = {
		en = "Debuffs X offset scale",
	},
	debuff_x_offset_tooltip = {
		en = "Adjust the left + right position of the debuffs. A lower value moves right, a higher value moves left. Adjust to your liking, or to fit to your widget config.",
	},
	debuff_y_offset = {
		en = "Debuffs Y offset scale",
	},
	debuff_y_offset_tooltip = {
		en = "Adjust the up + down position of the debuffs.\n\nOnly applies if debuffs are shown on the body, not stuck to the healthbar.\n\nAdjust to your liking, or to fit to your widget config. Can have a different effect depending on your other settings, so just play around a bit :)",
	},
	debuff_gap_name_icon_offset = {
		en = "Adjust the gap between the Name and Icon",
	},
	debuff_gap_name_icon_offset_tooltip = {
		en = "Adjust the size of the gap between the debuff names and debuff icons. A lower value will be tighter together, a higher value will be further away. Adjust to your liking, or to fit to your widget config.",
	},
	debuff_gap_icon_stack_offset = {
		en = "Adjust the gap between the Icon and Stacks",
	},
	debuff_gap_icon_stack_offset_tooltip = {
		en = "Adjust the size of the gap between the debuff icon and debuff stacks. A lower value will be tighter together, a higher value will be further away. Adjust to your liking, or to fit to your widget config.",
	},
	debuff_stacks_show_x = {
		en = "Show 'X' on stacks?",
	},
	debuff_stacks_show_x_tooltip = {
		en = "Toggle to show the 'X' on the debuff stacks, meaning the multiplier. If disabled, will just show the number.",
	},
	debuff_stacks_show_x_space = {
		en = "Add a space after 'X' on stacks?",
	},
	debuff_stacks_show_x_space_tooltip = {
		en = "Toggle to add a space between the 'X' and the stack counter on the debuff stacks, meaning the multiplier. If disabled, there will be no space.",
	},
	debuff_icon_scale = {
		en = "Debuff Icon Scale",
	},
	debuff_icon_scale_tooltip = {
		en = "Adjust the scale of the debuff icons. A lower value will be smaller, a higher value will be bigger. Adjust to your liking, or to fit to your widget config.",
	},
	debuff_stack_on_icon = {
		en = "Show stacks on icon?",
	},
	debuff_stack_on_icon_tooltip = {
		en = "Toggle to move the stacks on top of the debuff icon.",
	},
	debuff_gap_padding_scale = {
		en = "Row padding scale",
	},
	debuff_gap_padding_scale_tooltip = {
		en = "Adjust the padding gap between the rows of debuffs. A lower value will make the rows tighter together, a higher number will make them move apart.",
	},
})

-- Group settings
table.insert(localisations_to_add, {
	group_settings = {
		en = "{#color(" .. colours.title .. ")}All below settings apply ONLY to the selected enemy type{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}以下设置仅对选中的敌人类型生效{#reset()}",
	},
	enemy_group = {
		en = "Selected Enemy Type",
		["zh-cn"] = "选择敌人类型",
	},
	enemy_group_tooltip = {
		en = "Select an enemy type/class here to adjust their specific settings below.\n\nEnemy types can be seen on the healthbar with the 'Display enemy type' toggle enabled.",
		["zh-cn"] = "选择敌人类型，下方设置仅对该类型生效。\n可开启血条的敌人类型显示查看分类。",
	},
	reset_type_to_default_message = {
		en = "Reset settings for type '_type_' to default.",
		["zh-cn"] = "重置_type_类型的设置为默认值。",
	},
	reset_type_to_default = {
		en = "{#color(" .. colours.subtitle .. ")}Warning: {#reset()}Reset to defaults",
		["zh-cn"] = "{#color(" .. colours.subtitle .. ")}警告：{#reset()}恢复默认设置",
	},
	reset_type_to_default_tooltip = {
		en = "Reset all enemy type specific settings to their default values.\n\nNote: This only affects the enemy type selected above.",
		["zh-cn"] = "将当前选中敌人类型的所有设置重置为默认。",
	},

	-- outlines
	outline_type_enable = {
		en = "Enable outline?",
		["zh-cn"] = "启用轮廓",
	},
	outline_type_enable_tooltip = {
		en = "Toggle outlines for your selected enemy type/class",
		["zh-cn"] = "为当前选中敌人类型开启/关闭轮廓。",
	},

	outline_type_colour = {
		en = "Outline colour (Enemy Type Specific)",
		["zh-cn"] = "轮廓颜色（类型专属）",
	},
	outline_type_colour_tooltip = {
		en = "Adjust the colour of the enemy type specific outline.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
		["zh-cn"] = "设置当前敌人类型的轮廓颜色，数值0~255。",
	},

	outline_type_colour_R = {
		en = "Outline Colour: Red",
		["zh-cn"] = "轮廓颜色：红",
	},
	outline_type_colour_G = {
		en = "Outline Colour: Green",
		["zh-cn"] = "轮廓颜色：绿",
	},
	outline_type_colour_B = {
		en = "Outline Colour: Blue",
		["zh-cn"] = "轮廓颜色：蓝",
	},

	-- healthbars
	healthbar_type_enable = {
		en = "Enable healthbars?",
		["zh-cn"] = "启用血条",
	},
	healthbar_type_enable_tooltip = {
		en = "Toggle healthbars for your selected enemy type/class",
		["zh-cn"] = "为当前选中敌人类型开启/关闭血条。",
	},
	healthbar_type_colour = {
		en = "Healthbar colour (Enemy Type Specific)",
		["zh-cn"] = "血条颜色（类型专属）",
	},
	healthbar_type_colour_tooltip = {
		en = "Adjust the colour of the enemy type specific healthbar's current health value.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
		["zh-cn"] = "设置当前敌人类型的血条颜色，数值0~255。",
	},
	healthbar_type_colour_R = {
		en = "Healthbar Colour: Red",
		["zh-cn"] = "血条颜色：红",
	},
	healthbar_type_colour_G = {
		en = "Healthbar Colour: Green",
		["zh-cn"] = "血条颜色：绿",
	},
	healthbar_type_colour_B = {
		en = "Healthbar Colour: Blue",
		["zh-cn"] = "血条颜色：蓝",
	},

	healthbar_icon_type_enable = {
		en = "Enable enemy type icons?",
		["zh-cn"] = "启用类型图标",
	},
	healthbar_icon_type_enable_tooltip = {
		en = "Toggle icon indicators for your selected enemy type/class.",
		["zh-cn"] = "为当前选中敌人类型开启/关闭类型图标。",
	},
	healthbar_icon_type_scale = {
		en = "Type icon scale",
		["zh-cn"] = "图标大小",
	},
	healthbar_icon_type_scale_tooltip = {
		en = "Set the scale of the enemy type icons. 1 being 1x scale.",
		["zh-cn"] = "设置敌人类型图标缩放，1=默认大小。",
	},
	healthbar_icon_type_glow_intensity = {
		en = "Type icon glow intensity",
		["zh-cn"] = "图标发光强度",
	},
	healthbar_icon_type_glow_intensity_tooltip = {
		en = "Set the intensity of the glow.\n\n0 = Off\n100 = Max intensity",
		["zh-cn"] = "设置图标发光强度，0=关闭，100=最大。",
	},
	healthbar_icon_type_colour = {
		en = "Healthbar Icon Colour",
		["zh-cn"] = "图标颜色",
	},
	healthbar_icon_type_colour_R = {
		en = "Type Icon Colour: Red",
		["zh-cn"] = "图标颜色：红",
	},
	healthbar_icon_type_colour_G = {
		en = "Type Icon Colour: Green",
		["zh-cn"] = "图标颜色：绿",
	},
	healthbar_icon_type_colour_B = {
		en = "Type Icon Colour: Blue",
		["zh-cn"] = "图标颜色：蓝",
	},
	healthbar_icon_type_colour_tooltip = {
		en = "Adjust the colour of the enemy type specific icon.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
		["zh-cn"] = "设置当前敌人类型的图标颜色，数值0~255。",
	},
})

-- enemy individual overrides localisations
table.insert(localisations_to_add, {
	["SELECT ENEMY"] = {
		en = "SELECT AN ENEMY",
	},
	individual_override_settings = {
		en = "OVERRIDE SPECIFIC ENEMIES",
	},
	individual_overrides = {
		en = "Selected Enemy",
	},
	individual_overrides_tooltip = {
		en = "Selectively override specific enemy settings. These settings override the group settings above.",
	},
	reset_individual_to_default = {
		en = "{#color(" .. colours.subtitle .. ")}Warning: {#reset()}Reset to defaults",
		["zh-cn"] = "{#color(" .. colours.subtitle .. ")}警告：{#reset()}恢复默认设置",
	},
	reset_individual_to_default_tooltip = {
		en = "Reset settings for individual '_individual_' to default.",
	},
	healthbar_individual_enable = {
		en = "Enable healthbars override?",
	},
	healthbar_individual_enable_tooltip = {
		en = "Toggle healthbars overriding for your selected enemy",
	},
	healthbar_individual_colour = {
		en = "Healthbar colour (Enemy Specific)",
	},
	healthbar_individual_colour_R = {
		en = "Healthbar Colour: Red",
		["zh-cn"] = "血条颜色：红",
	},
	healthbar_individual_colour_G = {
		en = "Healthbar Colour: Green",
		["zh-cn"] = "血条颜色：绿",
	},
	healthbar_individual_colour_B = {
		en = "Healthbar Colour: Blue",
		["zh-cn"] = "血条颜色：蓝",
	},
	healthbar_individual_colour_tooltip = {
		en = "Adjust the colour of the overrided enemy healthbar's current health value.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
	},
	outline_individual_enable = {
		en = "Enable outline override?",
	},
	outline_individual_enable_tooltip = {
		en = "Toggle outline overriding for your selected enemy. Note: Only enables or changes colours, disabling will not override the group settings.",
	},
	outline_individual_colour = {
		en = "Outline colour (Enemy Specific)",
	},
	outline_individual_colour_R = {
		en = "Outline Colour: Red",
	},
	outline_individual_colour_G = {
		en = "Outline Colour: Green",
	},
	outline_individual_colour_B = {
		en = "Outline Colour: Blue",
	},
	outline_individual_colour_tooltip = {
		en = "Adjust the colour of the overrided enemy outline.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
	},
	markers_individual_toggle = {
		en = "Overhead markers override?",
	},
	markers_individual_toggle_tooltip = {
		en = "Toggle the overhead markers overriding for your selected enemy. This will take effect whether the global overhead markers are enabled or not. To allow only specific enemies to have the overhead markers.",
	},
})

table.insert(localisations_to_add, {
	throttle_timings = {
		en = "{#color(" .. colours.title .. ")}WARNING: Throttle Timings{#reset()}",
	},
	general_throttle_rate = {
		en = "General Throttle Rate",
	},
	general_throttle_rate_tooltip = {
		en = "Adjust the rate at which all on-screen elements in enemies improved are updated.\n\nMaking this higher may help gain some fps in dense situations, but may introduce 'stuttering' on the widgets, as they will have a longer delay between updates.\n\nThis slider is shown roughly in milliseconds, so a value of 100 will update roughly 10 times per second, a value of 50 will update roughly 20 times per second etc. ",
	},
	off_screen_throttle_rate = {
		en = "Off Screen Throttle Rate",
	},
	off_screen_throttle_rate_tooltip = {
		en = "Adjust the rate at which all off-screen elements in enemies improved are updated. This only affects enemies that you cannot currently see in your view.\n\nMaking this higher may help gain some fps in dense situations, but may introduce a delay to the widgets appearing, as they will have a longer delay between updates.\n\nThis slider is shown roughly in milliseconds, so a value of 100 will update roughly 10 times per second, a value of 50 will update roughly 20 times per second etc. ",
	},
})

-- add localisations to main map
for i = 1, #localisations_to_add do
	if localisations_to_add[i] then
		for key, value in next, localisations_to_add[i] do
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
	for key, values in next, mod.localisation do
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
				for language, text in next, values do
					local clean = string.gsub(text, "{#.-}", "")
					clean = string.gsub(clean, "{#reset%(%)%}", "")
					text = apply_color_to_text(clean, r, g, b)

					mod.localisation[key][language] = text
				end
			end
		end

		-- apply border colours
		if key == "Gold" or key == "Silver" or key == "Steel" or key == "Tarnished" then
			for language, text in next, values do
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
			for language, text in next, values do
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

mod.toggle_pizazz = function()
	for key, values in next, mod.localisation do
		if key == "mod_name" then
			for language, text in next, values do
				if mod:get("mod_name_pizazz_toggle") then
					mod.localisation[key][language] = mod.localisation["mod_name_pizazz"][language]
				else
					mod.localisation[key][language] = mod.localisation["mod_name_boring"][language]
				end
			end
		end
	end
end

mod.toggle_pizazz()

-- Insert font localisation
insert_fonts(mod.localisation)

-- Insert enemy names localisation
insert_enemy_names(mod.localisation)

apply_colours()

mod.apply_colours = function()
	apply_colours()
	return mod.localisation
end

return mod.localisation
