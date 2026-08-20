local mod = get_mod("enemies_improved")
mod.version = "2.1.5"
mod:info("Enemies Improved is installed, using version: " .. tostring(mod.version))

local next = next

local colours = {
	title = "200,140,20",
	subtitle = "226,199,126",
	text = "169,191,153",
}

local function lerp(a, b, t)
	return a + (b - a) * t
end

mod.gradientText = function(text, startColor, endColor, colorSpaces)
	local result = ""
	local length = #text
	local visibleIndex = 0

	-- Count visible characters
	for i = 1, length do
		local char = text:sub(i, i)
		if colorSpaces or char ~= " " then
			visibleIndex = visibleIndex + 1
		end
	end

	local currentIndex = 0

	for i = 1, length do
		local char = text:sub(i, i)

		if not colorSpaces and char == " " then
			result = result .. char
		else
			currentIndex = currentIndex + 1
			local t = (visibleIndex <= 1) and 0 or (currentIndex - 1) / (visibleIndex - 1)

			local r = math.floor(lerp(startColor[1], endColor[1], t))
			local g = math.floor(lerp(startColor[2], endColor[2], t))
			local b = math.floor(lerp(startColor[3], endColor[3], t))

			result = result .. string.format("{#color(%d,%d,%d)}%s", r, g, b, char)
		end
	end

	result = "{#color(" .. colours.title .. ")} " .. result .. "{#reset()}"
	return result
end

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
			ru = apply_font_to_text(text, data.value), -- одинаково для всех языков
		}
		localisation_table[data.value] = new_localised_readable_text
	end
end

-- Get all enemy names from breeds, to allow specific enemy colour changes.
local Breeds = require("scripts/settings/breed/breeds")
local BreedQueries = require("scripts/utilities/breed_queries")
local minion_breeds = BreedQueries.minion_breeds_by_name()
local ScriptUnit_has_extension = ScriptUnit.has_extension

mod.is_vanguard = function(unit)
	if not unit then
		return false
	end
	local unit_data_extension = ScriptUnit_has_extension(unit, "unit_data_system")
	if unit_data_extension then
		local breed = unit_data_extension:breed()
		if breed and (breed.name == "cultist_vanguard" or breed.name == "renegade_vanguard") then
			return true
		end
	end
	return false
end

mod.find_breed_category_by_tags = function(tags, breed_name)
	if tags then
		if breed_name == "cultist_vanguard" or breed_name == "renegade_vanguard" then
			return "shield"
		end

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
			local breed_type = mod.find_breed_category_by_tags(tags, name)
			--if name == "renegade_vanguard" or name == "cultist_vanguard" then
			--	breed_type = "elite"
			--end

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
				ru = Localize(data.text), -- одно и то же имя
			}

			if not localisation_table[data.text] then
				localisation_table[data.text] = new_localised_readable_text
			end
		end
	end
end

local mod_name = {
	en = "Enemies Improved",
	ru = "Улучшенные враги",
	["zh-cn"] = "敌人增强",
}

-- base localisations
mod.localisation = {
	mod_name = {
		en = mod_name["en"],
		ru = mod_name["ru"],
		["zh-cn"] = mod_name["zh-cn"],
	},
	mod_name_pizazz = {
		en = mod.gradientText(mod_name["en"], { 255, 0, 0 }, { 150, 0, 200 }, true),
		ru = mod.gradientText(mod_name["ru"], { 255, 0, 0 }, { 150, 0, 200 }, true),
		["zh-cn"] = mod.gradientText(mod_name["zh-cn"], { 255, 0, 0 }, { 150, 0, 200 }, true),
	},
	mod_name_boring = {
		en = mod_name["en"],
		ru = mod_name["ru"],
		["zh-cn"] = mod_name["zh-cn"],
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

		ru = "{#color("
			.. colours.text
			.. ")}"
			.. "Enemies Improved - Полоски здоровья, ослабления, контуры, маркеры, предупреждения о специальных атаках и многое другое для улучшения восприятия врагов в Darktide."
			.. "{#reset()}\n\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Автор: "
			.. "{#color("
			.. colours.text
			.. ")}Alfthebigheaded\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Версия: {#color("
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
		ru = "Включить яркое название",
		["zh-cn"] = "启用彩色标题",
	},
	mod_name_pizazz_tooltip = {
		en = "Toggles the rainbow colours effect on the mod name text. Requires a reload.\nIf enabled, you will get a small euphoric experience everytime you scroll through the mod menu, \nIf disabled - you will be a John Darktide and have no rainbow sprinkles (but I'll love you anyway).",
		ru = "Включает радужный эффект для названия мода. Требует перезагрузки.\nПри включении вы будете испытывать маленькую эйфорию каждый раз, когда листаете меню модов.\nПри отключении — вы станете Джоном Дарктайдом без радужных блёсток (но я всё равно буду вас любить).",
		["zh-cn"] = "切换模组名称的彩虹彩色效果，需要重新加载。\n启用后在模组菜单中会更美观，关闭则显示普通文本。",
	},
}

-- Group localisations so they can be managed easier.
local localisations_to_add = {}

-- debuff names and groups localisations
table.insert(localisations_to_add, {
	-- Debuff Groups
	generic = {
		en = "Generic",
		ru = "Общее",
		["zh-cn"] = "通用",
	},

	bleed = {
		en = "Bleed",
		ru = "Кровотечение",
		["zh-cn"] = "流血",
	},

	fire = {
		en = "Fire",
		ru = "Огонь",
		["zh-cn"] = "火焰",
	},

	phosphor_burn = {
		en = "Phosphor Burn",
		ru = "Фосфорный ожог",
		["zh-cn"] = "磷火",
	},

	warp = {
		en = "Warp",
		ru = "Варп",
		["zh-cn"] = "亚空间",
	},

	shock = {
		en = "Shock/Lightning",
		ru = "Шок/Молния",
		["zh-cn"] = "电击/闪电",
	},

	toxin = {
		en = "Toxin/Poison",
		ru = "Токсин/Яд",
		["zh-cn"] = "毒素/剧毒",
	},

	rending = {
		en = "Rending",
		ru = "Пробивание",
		["zh-cn"] = "脆弱",
	},

	damage_taken = {
		en = "+ Damage",
		ru = "+ Урон",
		["zh-cn"] = "+伤害",
	},

	melee_damage_taken = {
		en = "+ Melee Damage",
		ru = "+ Ближний урон",
		["zh-cn"] = "+近战伤害",
	},

	hit_mass_multiplier = {
		en = "Hit Mass Multiplier",
		ru = "Множитель ударной массы",
		["zh-cn"] = "打击质量倍率",
	},

	stagger_damage = {
		en = "+ Stagger Damage",
		ru = "+ Урон от ошеломления",
		["zh-cn"] = "+硬直伤害",
	},

	bleed_damage = {
		en = "+ Bleeding Damage",
		ru = "+ Урон от кровотечения",
		["zh-cn"] = "+流血伤害",
	},

	toxin_damage = {
		en = "+ Toxin Damage",
		ru = "+ Урон от токсина",
		["zh-cn"] = "+毒素伤害",
	},

	arbites = {
		en = "Arbites",
		ru = "Арбитрес",
		["zh-cn"] = "法务官",
	},

	rage = {
		en = "Hive Scum",
		ru = "Отребье Улья",
		["zh-cn"] = "巢都渣滓",
	},

	stagger = {
		en = "Staggered",
		ru = "Ошеломлён",
		["zh-cn"] = "踉跄",
	},
	staggered = {
		en = "Staggered",
		ru = "Ошеломлён",
		["zh-cn"] = "踉跄",
	},
	blind = {
		en = "Blind",
		ru = "Ослеплён",
		["zh-cn"] = "致盲",
	},

	-- Debuffs Localisation
	bleed = {
		en = "Bleed",
		ru = "Кровотечение",
		["zh-cn"] = "流血",
	},
	bleed_long = {
		en = "Bleed (Long)",
		ru = "Кровотечение (долгое)",
		["zh-cn"] = "流血（持续）",
	},
	bleeding = {
		en = "Bleeding",
		ru = "Кровотечение",
		["zh-cn"] = "流血",
	},
	burning = {
		en = "Burning",
		ru = "Горение",
		["zh-cn"] = "燃烧",
	},
	electrocuted = {
		en = "Electrocuted",
		ru = "Электрошок",
		["zh-cn"] = "触电",
	},
	flamer_assault = {
		en = "Burning(Flamer)",
		ru = "Горение (Огнемёт)",
		["zh-cn"] = "燃烧（喷火器）",
	},
	flame_grenade_liquid_area = {
		en = "Burning (Fire Grenade)",
		ru = "Горение (Зажигательная граната)",
		["zh-cn"] = "燃烧（燃烧雷）",
	},
	in_smoke_fog = {
		en = "Blinded (Smoke Grenade)",
		ru = "Ослеплён (Дымовая граната)",
		["zh-cn"] = "致盲（烟雾雷）",
	},
	warp_fire = {
		en = "Warpfire",
		ru = "Варп-огонь",
		["zh-cn"] = "亚空间火焰",
	},
	neurotoxin_interval_buff = {
		en = "Neurotoxin",
		ru = "Нейротоксин",
		["zh-cn"] = "神经毒素",
	},
	neurotoxin_interval_buff2 = {
		en = "Neurotoxin II",
		ru = "Нейротоксин II",
		["zh-cn"] = "神经毒素 II",
	},
	neurotoxin_interval_buff3 = {
		en = "Neurotoxin III",
		ru = "Нейротоксин III",
		["zh-cn"] = "神经毒素 III",
	},
	exploding_toxin_interval_buff = {
		en = "Exploding Toxin",
		ru = "Взрывающийся токсин",
		["zh-cn"] = "爆炸毒素",
	},

	psyker_discharge_damage_debuff = {
		en = "Increased Damage (Warp Rupture)",
		ru = "Увеличенный урон (Разрыв варпа)",
		["zh-cn"] = "增伤（亚空间破裂）",
	},
	psyker_discharge_damage_debuff_abrv = {
		en = "+ Damage",
		ru = "+ Урон",
		["zh-cn"] = "+伤害",
	},
	psyker_force_staff_quick_attack_debuff = {
		en = "Increased Warp Damage (Empyric Shock)",
		ru = "Увеличенный варп-урон (Эмпирический шок)",
		["zh-cn"] = "亚空间增伤（帝皇冲击）",
	},
	psyker_force_staff_quick_attack_debuff_abrv = {
		en = "+ Warp Damage",
		ru = "+ Варп-урон",
		["zh-cn"] = "+亚空间伤害",
	},

	toxin_damage_debuff = {
		en = "Weakened (Targeted Toxin)",
		ru = "Ослаблен (Точечный токсин)",
		["zh-cn"] = "虚弱（定向毒素）",
	},
	toxin_damage_debuff_monster = {
		en = "Weakened Monster (Targeted Toxin)",
		ru = "Ослабленное чудовище (Точечный токсин)",
		["zh-cn"] = "虚弱（定向毒素）",
	},

	broker_passive_toxin_infected_enemies_take_increased_damage_debuff = {
		en = "Increased Damage (Virulent Strain)",
		ru = "Увеличенный урон (Вирулентный штамм)",
		["zh-cn"] = "增伤（剧毒菌株）",
	},
	broker_passive_toxin_infected_enemies_take_increased_damage_debuff_abrv = {
		en = "+ Damage (Toxin)",
		ru = "+ Урон (Токсин)",
		["zh-cn"] = "+伤害（毒素）",
	},

	shock_effect = {
		en = "Electrocuted (Shocked)",
		ru = "Электрошок (Шокирован)",
		["zh-cn"] = "触电",
	},

	-- Rending / “take more damage”, tags, etc.
	rending_debuff = {
		en = "Brittleness",
		ru = "Хрупкость",
		["zh-cn"] = "脆弱",
	},
	rending_debuff_medium = {
		en = "Brittleness (Medium)",
		ru = "Хрупкость (средняя)",
		["zh-cn"] = "脆弱",
	},
	rending_burn_debuff = {
		en = "Brittleness (Burn)",
		ru = "Хрупкость (ожог)",
		["zh-cn"] = "脆弱",
	},
	saw_rending_debuff = {
		en = "Brittleness (Saw Blade)",
		ru = "Хрупкость (пила)",
		["zh-cn"] = "脆弱",
	},
	shotgun_special_rending_debuff = {
		en = "Brittleness (Shotgun)",
		ru = "Хрупкость (дробовик)",
		["zh-cn"] = "脆弱",
	},

	increase_impact_received_while_staggered = {
		en = "Increased Impact Taken",
		ru = "Увеличенное получаемое выведение из равновесия",
		["zh-cn"] = "受到冲击提升",
	},
	increase_impact_received_while_staggered_abrv = {
		en = "+ Impact",
		ru = "+ Выведение из равновесия",
		["zh-cn"] = "+冲击",
	},
	increase_damage_received_while_staggered = {
		en = "Increased Damage Taken (Staggered)",
		ru = "Увеличенный получаемый урон (ошеломлён)",
		["zh-cn"] = "受到伤害提升（硬直）",
	},
	increase_damage_received_while_staggered_abrv = {
		en = "+ Damage (Staggered)",
		ru = "+ Урон (ошеломлён)",
		["zh-cn"] = "+伤害（踉跄）",
	},
	power_maul_sticky_tick = {
		en = "Power Maul Impact",
		ru = "Выведение из равновесия силовой булавой",
		["zh-cn"] = "动力锤冲击",
	},
	increase_damage_taken = {
		en = "Increased Damage Taken",
		ru = "Увеличенный получаемый урон",
		["zh-cn"] = "受到伤害提升",
	},
	increase_damage_taken_abrv = {
		en = "+ Damage",
		ru = "+ Урон",
		["zh-cn"] = "+伤害",
	},

	-- Psyker utility / chain lightning etc.
	psyker_protectorate_spread_chain_lightning_interval_improved = {
		en = "Chain Lightning (Improved)",
		ru = "Цепная молния (улучшенная)",
		["zh-cn"] = "连锁闪电",
	},
	psyker_protectorate_spread_charged_chain_lightning_interval_improved = {
		en = "Charged Chain Lightning (Improved)",
		ru = "Заряженная цепная молния (улучшенная)",
		["zh-cn"] = "蓄力连锁闪电",
	},
	psyker_protectorate_spread_chain_lightning_interval = {
		en = "Chain Lightning",
		ru = "Цепная молния",
		["zh-cn"] = "连锁闪电",
	},
	psyker_protectorate_spread_charged_chain_lightning_interval = {
		en = "Charged Chain Lightning",
		ru = "Заряженная цепная молния",
		["zh-cn"] = "蓄力连锁闪电",
	},
	psyker_heavy_swings_shock = {
		en = "Charged Strike",
		ru = "Заряженный удар",
		["zh-cn"] = "蓄力打击",
	},
	psyker_heavy_swings_shock_improved = {
		en = "Charged Strike (Improved)",
		ru = "Заряженный удар (улучшенный)",
		["zh-cn"] = "蓄力打击",
	},

	-- Ogryn
	ogryn_recieve_damage_taken_increase_debuff = {
		en = "Increased Damage Taken (Soften Them Up)",
		ru = "Увеличенный получаемый урон (Ослабить их)",
		["zh-cn"] = "受到伤害提升（削弱敌人）",
	},
	ogryn_recieve_damage_taken_increase_debuff_abrv = {
		en = "+ Damage",
		ru = "+ Урон",
		["zh-cn"] = "+伤害",
	},
	ogryn_taunt_increased_damage_taken_buff = {
		en = "Increased Damage Taken (Valuable Distraction)",
		ru = "Увеличенный получаемый урон (Ценное отвлечение)",
		["zh-cn"] = "受到伤害提升（宝贵牵制）",
	},
	ogryn_taunt_increased_damage_taken_buff_abrv = {
		en = "+ Damage",
		ru = "+ Урон",
		["zh-cn"] = "+伤害",
	},
	ogryn_staggering_damage_taken_increase = {
		en = "Increased Melee Damage Taken (Hard Knocks)",
		ru = "Увеличенный получаемый ближний урон (Тяжёлые удары)",
		["zh-cn"] = "近战伤害提升（沉重打击）",
	},
	ogryn_staggering_damage_taken_increase_abrv = {
		en = "+ Melee Damage",
		ru = "+ Урон ближнего боя",
		["zh-cn"] = "+近战伤害",
	},

	-- Veteran
	veteran_improved_tag_debuff = {
		en = "Increased Damage Taken (Tagged Target)",
		ru = "Увеличенный получаемый урон (Отмеченная цель)",
		["zh-cn"] = "受到伤害提升（标记目标）",
	},
	veteran_improved_tag_debuff_abrv = {
		en = "+ Damage",
		ru = "+ Урон",
		["zh-cn"] = "+伤害",
	},

	-- Zealot
	zealot_bled_enemies_take_more_damage_effect = {
		en = "Increased Damage Taken (Bleeding)",
		ru = "Увеличенный получаемый урон (Кровотечение)",
		["zh-cn"] = "受到伤害提升（流血）",
	},
	zealot_bled_enemies_take_more_damage_effect_abrv = {
		en = "+ Damage (Bleeding)",
		ru = "+ Урон (кровотечение)",
		["zh-cn"] = "+伤害（流血）",
	},

	-- Arbite
	adamant_drone_enemy_debuff = {
		en = "Increased Damage Taken (Drone Marked)",
		ru = "Увеличенный получаемый урон (Отмечен дроном)",
		["zh-cn"] = "无人机标记·增伤",
	},
	adamant_drone_enemy_debuff_abrv = {
		en = "+ Damage",
		ru = "+ Урон",
		["zh-cn"] = "+ 受到伤害",
	},
	adamant_drone_talent_debuff = {
		en = "Drone Suppressed",
		ru = "Дрон подавлен",
		["zh-cn"] = "无人机压制",
	},
	adamant_melee_weakspot_hits_count_as_stagger_debuff = {
		en = "Weakspot Stagger",
		ru = "Ошеломление в уязвимое место",
		["zh-cn"] = "弱点硬直",
	},
	adamant_staggered_enemies_deal_less_damage_debuff = {
		en = "Weak (Suppression Force)",
		ru = "Ослаблен (Сила подавления)",
		["zh-cn"] = "虚弱（压制力）",
	},
	adamant_staggering_increases_damage_taken = {
		en = "Increased Damage (Break Dissent)",
		ru = "Увеличенный урон (Подавление инакомыслия)",
		["zh-cn"] = "增伤（粉碎异心）",
	},
	adamant_staggering_increases_damage_taken_abrv = {
		en = "+ Damage (Staggered)",
		ru = "+ Урон (ошеломлён)",
		["zh-cn"] = "+伤害（踉跄）",
	},

	-- Broker
	broker_punk_rage_improved_shout_debuff = {
		en = "Forge's Bellow",
		ru = "Рёв горна",
		["zh-cn"] = "熔炉咆哮",
	},

	shock_grenade_interval = {
		en = "Shock Grenade Stagger",
		ru = "Ошеломление шоковой гранатой",
		["zh-cn"] = "震撼手雷硬直",
	},

	weapon_malfunction = {
		en = "Malfunction",
		ru = "Сбой",
		["zh-cn"] = "故障",
	},

	-- Skitarii
	phosphor_rending_debuff = {
		en = "Brittleness (Phosphor)",
		ru = "Хрупкость (Фосфор)",
		["zh-cn"] = "脆弱（磷火）",
	},
	cryptic_servo_skull_debuff = {
		en = "Increased Damage (Servo Skull)",
		ru = "Увеличенный урон (Сервочереп)",
		["zh-cn"] = "伺服头骨增伤",
	},
	cryptic_servo_skull_debuff_abrv = {
		en = "+ Damage (Servo Skull)",
		ru = "+ Урон (Сервочереп)",
		["zh-cn"] = "+增伤（伺服头骨）",
	},
	cryptic_overload_keystone_increase_damage_taken_debuff = {
		en = "Increased Damage (Overload)",
		ru = "Увеличенный урон (Перегрузка)",
		["zh-cn"] = "过载增伤",
	},
	cryptic_overload_keystone_increase_damage_taken_debuff_abrv = {
		en = "+ Damage (Overload)",
		ru = "+ Урон (Перегрузка)",
		["zh-cn"] = "+增伤（过载）",
	},
})

-- enemy type localisations
table.insert(localisations_to_add, {
	["SELECT AN ENEMY TYPE"] = {
		en = "SELECT AN ENEMY TYPE",
		ru = "ВЫБЕРИТЕ ТИП ВРАГА",
		["zh-cn"] = "选择敌人类型",
	},
	select = {
		en = "SELECT AN ENEMY TYPE",
		ru = "ВЫБЕРИТЕ ТИП ВРАГА",
		["zh-cn"] = "选择敌人类型",
	},
	-- New Vanguard breed display names (added as safety net for breed localization)
	loc_breed_display_name_cultist_vanguard = {
		en = "Cultist Vanguard",
		ru = "Авангард культа",
		["zh-cn"] = "渣滓盾卫",
	},
	loc_breed_display_name_renegade_vanguard = {
		en = "Renegade Vanguard",
		ru = "Авангард ренегатов",
		["zh-cn"] = "血痂盾卫",
	},
	monster = {
		en = "miniboss",
		ru = "мини-босс",
		["zh-cn"] = "小BOSS",
	},
	captain = {
		en = "boss",
		ru = "босс",
		["zh-cn"] = "BOSS",
	},
	disabler = {
		en = "disabler",
		ru = "обездвиживатель",
		["zh-cn"] = "控制专家",
	},
	witch = {
		en = "daemonhost",
		ru = "демонхост",
		["zh-cn"] = "恶魔宿主",
	},
	sniper = {
		en = "sniper",
		ru = "снайпер",
		["zh-cn"] = "狙击手",
	},
	far = {
		en = "ranged elite",
		ru = "стрелок элитный",
		["zh-cn"] = "远程精英",
	},
	elite = {
		en = "melee elite",
		ru = "боец элитный",
		["zh-cn"] = "近战精英",
	},
	special = {
		en = "special",
		ru = "специалист",
		["zh-cn"] = "输出专家",
	},
	horde = {
		en = "horde",
		ru = "орда",
		["zh-cn"] = "尸潮怪",
	},
	enemy = {
		en = "ritualist",
		ru = "ритуалист",
		["zh-cn"] = "仪式者",
	},
	shield = {
		en = "vanguard (shields)",
		ru = "авангард (щиты)",
		["zh-cn"] = "盾卫",
	},
})

-- damage  number type localisations
table.insert(localisations_to_add, {
	readable = {
		en = "Readable",
		ru = "Читаемый",
		["zh-cn"] = "清晰",
	},
	floating = {
		en = "floating",
		ru = "Плавающий",
		["zh-cn"] = "浮动",
	},
	flashy = {
		en = "flashy",
		ru = "Мерцающий",
		["zh-cn"] = "炫丽",
	},
})

-- frame options localisations
table.insert(localisations_to_add, {
	panel_main_lower_frame = {
		en = "Gritty texture",
		ru = "Грубая текстура",
		["zh-cn"] = "粗糙纹理",
	},
	heavy_frame_back = {
		en = "No Frame",
		ru = "Без рамки",
		["zh-cn"] = "无框",
	},
	heavy_frame_top = {
		en = "Riveted panel",
		ru = "Клёпаная панель",
		["zh-cn"] = "铆钉面板",
	},
	simple = {
		en = "Simple black box",
		ru = "Простая чёрная рамка",
		["zh-cn"] = "简约黑框",
	},
	contracts_progress_overall_fill = {
		en = "Colourful box",
		ru = "Цветная рамка",
		["zh-cn"] = "彩色框体",
	},
})

-- enemy type options localisations
table.insert(localisations_to_add, {
	enemy_type = {
		en = "Enemy Type",
		ru = "Тип врага",
		["zh-cn"] = "敌人类型",
	},
	enemy_name = {
		en = "Name",
		ru = "Название",
		["zh-cn"] = "名称",
	},
	armour_type = {
		en = "Armour Type",
		ru = "Тип брони",
		["zh-cn"] = "护甲类型",
	},
	health = {
		en = "Current Health",
		ru = "Текущее здоровье",
		["zh-cn"] = "当前血量",
	},
	nothing = {
		en = "Don't Show",
		ru = "Не показывать",
		["zh-cn"] = "不显示",
	},
})

-- general settings localisations
table.insert(localisations_to_add, {
	general_settings = {
		en = "{#color(" .. colours.title .. ")}General Settings{#reset()}",
		ru = "{#color(" .. colours.title .. ")}Основные настройки{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}通用设置{#reset()}",
	},
	draw_distance = {
		en = "Draw Distance (Global)",
		ru = "Дистанция отрисовки (глобальная)",
		["zh-cn"] = "显示距离（全局）",
	},
	draw_distance_tooltip = {
		en = "The distance (in Metres) from the player to draw enemy information.\nThis setting is global and will effect all enemy types.",
		ru = "Расстояние (в метрах) от игрока, на котором отображается информация о врагах.\nЭто глобальная настройка, влияющая на все типы врагов.",
		["zh-cn"] = "显示敌人信息的最大距离（米）。\n此为全局设置，影响所有敌人类型。",
	},
	global_opacity = {
		en = "Global Opacity",
		ru = "Глобальная прозрачность",
		["zh-cn"] = "全局透明度",
	},
	global_opacity_tooltip = {
		en = "Set a global opacity slider for Enemies Improved UI elements. This will scale the opacity of all elements from their max (1) to their minimal value (0.1).",
		ru = "Установите глобальную прозрачность для элементов интерфейса Улучшенных врагов. Все элементы будут масштабироваться от максимума (1) до минимума (0.1).",
		["zh-cn"] = "设置模组UI全局透明度。所有元素透明度将按此比例缩放（0.1~1）。",
	},
	enable_depth_fading = {
		en = "Enable Distance Fading?",
		ru = "Включить затухание по расстоянию?",
		["zh-cn"] = "距离渐隐",
	},
	enable_depth_fading_tooltip = {
		en = "Toggle distance fading for all Enemies Improved UI elements, so that enemies far away will be more transparent than closer ones. Also includes 'stack fading' which fades out UI elements for enemies that are behind other enemies, so that the closer enemy is easier to see.",
		ru = "Включает затухание по расстоянию для всех элементов Улучшенных врагов: дальнобойные враги становятся более прозрачными. Также включает «затухание стака» — элементы интерфейса врагов, находящихся за другими врагами, становятся прозрачнее, чтобы ближние враги были лучше видны.",
		["zh-cn"] = "开启后远处敌人UI会更透明，同时后方敌人UI会渐隐，优先显示近处敌人。",
	},
	spatial_culling = {
		en = "Enable Spatial Culling?",
		ru = "Включить пространственное отсечение?",
		["zh-cn"] = "启用空间筛选",
	},
	spatial_culling_tooltip = {
		en = "Toggle spatial culling for Enemies Improved UI elements.\n\nThe culling essentially gives each enemy a priority based on their distance to the player, their class, and if you're looking close to them… and then hides ones that are further/less priority. So in a dense cluster, you'll see all the front running enemies, and important elites like disablers, snipers, daemonhosts etc. But the others at the back/in the middle of the group won't even get counted/included until they become at the front.\n\nShould help FPS in dense elite hordes.",
		ru = "Включает пространственное отсечение для элементов интерфейса Улучшенных врагов. Каждому врагу присваивается приоритет на основе расстояния до игрока, его класса и того, смотрите ли вы на него. Враги с более низким приоритетом скрываются. Это позволяет видеть передних врагов и важных элитных (обездвиживателей, снайперов, демонхостов) в плотной группе, а задние/средние не отображаются, пока не окажутся спереди. Помогает сохранить FPS в плотных скоплениях элитной орды.",
		["zh-cn"] = "为UI元素启用空间筛选，根据距离、类型优先级隐藏远处敌人，提升密集怪群时的帧率。",
	},
	check_line_of_sight = {
		en = "Check for line of sight?",
		ru = "Проверять прямую видимость?",
		["zh-cn"] = "检查视线",
	},
	check_line_of_sight_tooltip = {
		en = "Require line of sight checks for enemies?",
		ru = "Требовать прямую видимость для отображения информации о врагах?",
		["zh-cn"] = "仅在能直接看到敌人时显示UI。",
	},
	outlines_enable = {
		en = "Enable Outlines (Global)",
		ru = "Включить контуры (глобально)",
		["zh-cn"] = "启用轮廓（全局）",
	},
	outlines_enable_tooltip = {
		en = "Global toggle for outlines of enemies. Head to the group/individual override sections to adjust outlines per enemy.",
		ru = "Глобальное включение контуров врагов. Перейдите в разделы групповых/индивидуальных переопределений для настройки контуров для каждого врага.",
		["zh-cn"] = "全局开关敌人轮廓，可在下方单独配置各类型敌人。",
	},
	outline_tagged_enable = {
		en = "Enable tagged enemy outline override",
		ru = "Включить переопределение контура для отмеченного врага",
		["zh-cn"] = "启用标记敌人轮廓覆盖",
	},
	outline_tagged_enable_tooltip = {
		en = "Enable the custom outline colour for enemies you actively tag.",
		ru = "Включает пользовательский цвет контура для врагов, которых вы активно отмечаете.",
		["zh-cn"] = "启用你手动标记敌人时使用的自定义轮廓颜色。",
	},
	outline_tagged_colour = {
		en = "Tagged enemy outline colour",
		ru = "Цвет контура отмеченного врага",
		["zh-cn"] = "自身标记敌人轮廓颜色",
	},
	outline_tagged_colour_R = {
		en = "Tagged Outline Colour: Red",
		ru = "Контур отмеченного врага: Красный",
		["zh-cn"] = "标记轮廓：红色",
	},
	outline_tagged_colour_G = {
		en = "Tagged Outline Colour: Green",
		ru = "Контур отмеченного врага: Зелёный",
		["zh-cn"] = "标记轮廓：绿色",
	},
	outline_tagged_colour_B = {
		en = "Tagged Outline Colour: Blue",
		ru = "Контур отмеченного врага: Синий",
		["zh-cn"] = "标记轮廓：蓝色",
	},
	outline_tagged_colour_tooltip = {
		en = "Colour of the outline when you actively tag an enemy.",
		ru = "Цвет контура, когда вы активно отмечаете врага.",
		["zh-cn"] = "你手动标记敌人时显示的轮廓颜色。",
	},

	outline_veteran_tagged_enable = {
		en = "Enable Veteran focus target outline override",
		ru = "Включить переопределение контура для цели фокуса Ветерана",
		["zh-cn"] = "启用老兵专注目标轮廓覆盖",
	},
	outline_veteran_tagged_enable_tooltip = {
		en = "Enable the custom outline colour for Veteran's Focus Target tag.",
		ru = "Включает пользовательский цвет контура для метки «Цель фокуса» Ветерана.",
		["zh-cn"] = "启用老兵「专注目标」标记使用的自定义轮廓颜色。",
	},
	outline_veteran_tagged_colour = {
		en = "Veteran's Focus Target tag outline colour",
		ru = "Цвет контура метки «Цель фокуса» Ветерана",
		["zh-cn"] = "老兵专注标记轮廓颜色",
	},
	outline_veteran_tagged_colour_R = {
		en = "Tagged Outline Colour: Red",
		ru = "Контур отмеченного врага: Красный",
		["zh-cn"] = "标记轮廓：红色",
	},
	outline_veteran_tagged_colour_G = {
		en = "Tagged Outline Colour: Green",
		ru = "Контур отмеченного врага: Зелёный",
		["zh-cn"] = "标记轮廓：绿色",
	},
	outline_veteran_tagged_colour_B = {
		en = "Tagged Outline Colour: Blue",
		ru = "Контур отмеченного врага: Синий",
		["zh-cn"] = "标记轮廓：蓝色",
	},
	outline_veteran_tagged_colour_tooltip = {
		en = "Colour for Veteran's Focus Target tag.",
		ru = "Цвет для метки «Важная цель» Ветерана.",
		["zh-cn"] = "老兵天赋「专注目标」标记对应的高亮轮廓颜色。",
	},

	outline_tagged_passive_enable = {
		en = "Enable passive tagged enemy outline override",
		ru = "Включить переопределение контура для пассивно отмеченного врага",
		["zh-cn"] = "启用队友标记敌人轮廓覆盖",
	},
	outline_tagged_passive_enable_tooltip = {
		en = "Enable the custom outline colour for enemies tagged by your teammates.",
		ru = "Включает пользовательский цвет контура для врагов, отмеченных вашими союзниками.",
		["zh-cn"] = "启用队友标记敌人时使用的自定义轮廓颜色。",
	},
	outline_tagged_passive_colour = {
		en = "Tagged enemy (Passive) outline colour",
		ru = "Цвет контура отмеченного врага (пассивно)",
		["zh-cn"] = "队友标记敌人轮廓颜色",
	},
	outline_tagged_passive_colour_R = {
		en = "Tagged Outline Colour: Red",
		ru = "Контур отмеченного врага: Красный",
		["zh-cn"] = "标记轮廓：红色",
	},
	outline_tagged_passive_colour_G = {
		en = "Tagged Outline Colour: Green",
		ru = "Контур отмеченного врага: Зелёный",
		["zh-cn"] = "标记轮廓：绿色",
	},
	outline_tagged_passive_colour_B = {
		en = "Tagged Outline Colour: Blue",
		ru = "Контур отмеченного врага: Синий",
		["zh-cn"] = "标记轮廓：蓝色",
	},
	outline_tagged_passive_colour_tooltip = {
		en = "Colour of the outline when a teammate tags an enemy (passive/focus).",
		ru = "Цвет контура, когда союзник отмечает врага (пассивно или фокус).",
		["zh-cn"] = "队友标记敌人时显示的轮廓颜色。",
	},
	outline_owned_companion_colour = {
		en = "Owned companion outline colour",
		ru = "Цвет контура собственного спутника",
		["zh-cn"] = "自身召唤物轮廓颜色",
	},
	outline_owned_companion_colour_R = {
		en = "Tagged Outline Colour: Red",
		ru = "Контур отмеченного врага: Красный",
		["zh-cn"] = "标记轮廓：红色",
	},
	outline_owned_companion_colour_G = {
		en = "Tagged Outline Colour: Green",
		ru = "Контур отмеченного врага: Зелёный",
		["zh-cn"] = "标记轮廓：绿色",
	},
	outline_owned_companion_colour_B = {
		en = "Tagged Outline Colour: Blue",
		ru = "Контур отмеченного врага: Синий",
		["zh-cn"] = "标记轮廓：蓝色",
	},

	outline_allied_companion_colour = {
		en = "Allied companion outline colour",
		ru = "Цвет контура союзного спутника",
		["zh-cn"] = "队友召唤物轮廓颜色",
	},
	outline_allied_companion_colour_R = {
		en = "Tagged Outline Colour: Red",
		ru = "Контур отмеченного врага: Красный",
		["zh-cn"] = "标记轮廓：红色",
	},
	outline_allied_companion_colour_G = {
		en = "Tagged Outline Colour: Green",
		ru = "Контур отмеченного врага: Зелёный",
		["zh-cn"] = "标记轮廓：绿色",
	},
	outline_allied_companion_colour_B = {
		en = "Tagged Outline Colour: Blue",
		ru = "Контур отмеченного врага: Синий",
		["zh-cn"] = "标记轮廓：蓝色",
	},

	outline_companion_enable = {
		en = "Enable companion outline override",
		ru = "Включить переопределение контура для спутников",
		["zh-cn"] = "启用随从单位轮廓覆盖",
	},
	outline_companion_enable_tooltip = {
		en = "Enable the custom outline colour for companion units.",
		ru = "Включает пользовательский цвет контура для спутниковых юнитов.",
		["zh-cn"] = "启用所有召唤随从单位使用的自定义轮廓颜色。",
	},
	outline_companion_colour = {
		en = "Companion tagged enemy outline colour",
		ru = "Цвет контура отмеченного врага для спутников",
		["zh-cn"] = "随从单位轮廓颜色",
	},
	outline_companion_colour_tooltip = {
		en = "Colour of the outline for companion units.",
		ru = "Цвет контура для спутников.",
		["zh-cn"] = "所有召唤随从单位的高亮轮廓颜色。",
	},
	outline_companion_colour_R = {
		en = "Tagged Outline Colour: Red",
		ru = "Контур отмеченного врага: Красный",
		["zh-cn"] = "标记轮廓：红色",
	},
	outline_companion_colour_G = {
		en = "Tagged Outline Colour: Green",
		ru = "Контур отмеченного врага: Зелёный",
		["zh-cn"] = "标记轮廓：绿色",
	},
	outline_companion_colour_B = {
		en = "Tagged Outline Colour: Blue",
		ru = "Контур отмеченного врага: Синий",
		["zh-cn"] = "标记轮廓：蓝色",
	},

	outline_settings = {
		en = "Outline Settings",
		ru = "Настройки контуров",
		["zh-cn"] = "轮廓高亮设置",
	},
	font_type = {
		en = "Choose a font style (Global)",
		ru = "Выберите стиль шрифта (глобально)",
		["zh-cn"] = "字体样式（全局）",
	},
	font_type_tooltip = {
		en = "The global font style to use. This will apply to all text elements from Enemies Improved.",
		ru = "Глобальный стиль шрифта, применяемый ко всем текстовым элементам Улучшенных врагов.",
		["zh-cn"] = "模组所有文本使用的统一字体。",
	},
	font_no_longer_available = {
		en = "Selected font type is no longer available, resetting to a default option.",
		ru = "Выбранный шрифт больше недоступен, сброс к значению по умолчанию.",
		["zh-cn"] = "选中的字体不可用，已重置为默认选项。",
	},
	text_scale = {
		en = "Scale the text sizes (Global)",
		ru = "Масштаб размера текста (глобально)",
		["zh-cn"] = "文本缩放（全局）",
	},
	text_scale_tooltip = {
		en = "A global scale that applies to ALL text used in Enemies Improved. Think of this is an 'x' scaler. E.g. a value of 1.2 is 1.2x the font sizes. ",
		ru = "Глобальный масштаб для ВСЕГО текста в Улучшенных врагах. Это коэффициент увеличения. Например, 1.2 означает увеличение размера шрифта в 1.2 раза.",
		["zh-cn"] = "所有文本大小的全局倍率，例如1.2=1.2倍大小。",
	},
	main_font_colour = {
		en = "Colour for main text font (Global)",
		ru = "Цвет шрифта основного текста (глобально)",
		["zh-cn"] = "主文本颜色（全局）",
	},
	main_font_colour_R = {
		en = "Main Font: Red",
		ru = "Основной шрифт: Красный",
		["zh-cn"] = "主文本：红",
	},
	main_font_colour_G = {
		en = "Main Font: Green",
		ru = "Основной шрифт: Зелёный",
		["zh-cn"] = "主文本：绿",
	},
	main_font_colour_B = {
		en = "Main Font: Blue",
		ru = "Основной шрифт: Синий",
		["zh-cn"] = "主文本：蓝",
	},
	secondary_font_colour_tooltip = {
		en = "Pick a colour to apply as the 'secondary' font colour throughout enemies improved elements.",
		ru = "Выберите цвет для второстепенного текста в элементах Улучшенных врагов.",
		["zh-cn"] = "设置次要文本的全局颜色。",
	},
	secondary_font_colour = {
		en = "Colour for secondary text font (Global)",
		ru = "Цвет второстепенного текста (глобально)",
		["zh-cn"] = "次要文本颜色（全局）",
	},
	secondary_font_colour_R = {
		en = "Secondary Font: Red",
		ru = "Вторичный шрифт: Красный",
		["zh-cn"] = "次要文本：红",
	},
	secondary_font_colour_G = {
		en = "Secondary Font: Green",
		ru = "Вторичный шрифт: Зелёный",
		["zh-cn"] = "次要文本：绿",
	},
	secondary_font_colour_B = {
		en = "Secondary Font: Blue",
		ru = "Вторичный шрифт: Синий",
		["zh-cn"] = "次要文本：蓝",
	},
	secondary_font_colour_tooltip = {
		en = "Pick a colour to apply as the 'secondary' font colour throughout enemies improved elements.",
		ru = "Выберите цвет для второстепенного текста в элементах Улучшенных врагов.",
		["zh-cn"] = "选择用于敌人增强模组所有元素的次要字体颜色。",
	},
	only_in_meatgrinder = {
		en = "Only show in Meat Grinder?",
		ru = "Показывать только в Мясорубке?",
		["zh-cn"] = "仅在灵能室显示？",
	},
	only_in_meatgrinder_tooltip = {
		en = "Toggle to show Enemies Improved widgets in the meat grinder ONLY. This means that in live matches, or anywhere outside the meat grinder - you will not see any enemies improved changes.",
		ru = "Включает отображение элементов Улучшенных врагов ТОЛЬКО в Мясорубке. В обычных матчах или где-либо ещё изменения не будут видны.",
		["zh-cn"] = "开启后，仅在灵能室内显示敌人增强模组的UI组件。在正式对局或灵能室以外的区域，将不会生效任何敌人增强相关改动。",
	},
	always_show_in_meatgrinder = {
		en = "Always show in Meat Grinder?",
		ru = "Всегда показывать в Мясорубке?",
		["zh-cn"] = "在灵能室内始终显示？",
	},
	always_show_in_meatgrinder_tooltip = {
		en = "While inside the Meat Grinder, skip the 'hide after no damage' logic so healthbars and damage numbers always stay visible. Useful for testing. Does nothing outside the Meat Grinder.",
		ru = "В Мясорубке отключает логику скрытия после отсутствия урона, так что полоски здоровья и цифры урона всегда видны. Полезно для тестирования. Не действует за пределами Мясорубки.",
		["zh-cn"] = "在灵能室内时，跳过“无伤害后隐藏”逻辑，使血条和伤害数字始终可见。便于测试。对灵能室以外的区域无效。",
	},
})

-- special attacks settings localisations
table.insert(localisations_to_add, {
	special_attack_settings = {
		en = "{#color(" .. colours.title .. ")}Special Attacks{#reset()}",
		ru = "{#color(" .. colours.title .. ")}Специальные атаки{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}特殊攻击{#reset()}",
	},
	marker_specials_enable = {
		en = "Toggle overhead markers special attack indicators (Global)",
		ru = "Включить индикаторы специальных атак на маркерах над головой (глобально)",
		["zh-cn"] = "启用头顶标记预警（全局）",
	},
	marker_specials_enable_tooltip = {
		en = "Affects only 'Enemy Overhead Markers'. \nApplies a pulsating effect when a special attack is detected, to help you get out of the way!",
		ru = "Влияет только на «Маркеры над головами врагов». При обнаружении специальной атаки добавляет пульсирующий эффект, помогая вам увернуться!",
		["zh-cn"] = "仅作用于头顶标记。\n敌人释放特殊攻击时标记闪烁，提醒躲避。",
	},
	outline_specials_enable = {
		en = "Toggle enemy outline special attack indicators (Global)",
		ru = "Включить индикаторы специальных атак на контурах врагов (глобально)",
		["zh-cn"] = "启用轮廓预警（全局）",
	},
	outline_specials_enable_tooltip = {
		en = "Applies an outline effect when a special attack is detected, to help distinguish a 'special attack' enemy from a crowd.",
		ru = "При обнаружении специальной атаки добавляет эффект контура, чтобы выделить врага, готовящего специальную атаку, среди толпы.",
		["zh-cn"] = "敌人释放特殊攻击时高亮轮廓，便于在人群中识别。",
	},
	healthbar_specials_enable = {
		en = "Toggle healthbar special attack indicators (Global)",
		ru = "Включить индикаторы специальных атак на полоске здоровья (глобально)",
		["zh-cn"] = "启用血条预警（全局）",
	},
	healthbar_specials_enable_tooltip = {
		en = "Toggle special attack indicators on the healthbar. \nApplies a pulsating effect when a special attack is detected, to help you get out of the way!",
		ru = "Включает индикаторы специальных атак на полоске здоровья. При обнаружении специальной атаки добавляет пульсирующий эффект, помогая вам увернуться!",
		["zh-cn"] = "敌人释放特殊攻击时血条闪烁提醒。",
	},
	specials_flash = {
		en = "Enable flashing for special attacks (Global)",
		ru = "Включить мигание для специальных атак (глобально)",
		["zh-cn"] = "启用闪烁效果（全局）",
	},
	specials_flash_tooltip = {
		en = "Applies a flashing effect to the special attack indicators. \n\nDisable for a solid colour instead.",
		ru = "Добавляет эффект мигания индикаторам специальных атак. Отключите для постоянного цвета.",
		["zh-cn"] = "开启预警闪烁，关闭则为纯色显示。",
	},
	special_attack_pulse_speed = {
		en = "Special Attack Pulse Speed",
		ru = "Скорость пульсации специальных атак",
		["zh-cn"] = "预警闪烁速度",
	},
	special_attack_pulse_speed_tooltip = {
		en = "Set a speed for the flashing of the special attack warnings. With a lower value being faster flashing.",
		ru = "Установите скорость мигания предупреждений о специальных атаках. Меньшее значение = более быстрое мигание.",
		["zh-cn"] = "数值越低，闪烁速度越快。",
	},
	outline_specials_colour = {
		en = "Colour for special attacks (Global)",
		ru = "Цвет для специальных атак (глобально)",
		["zh-cn"] = "特殊攻击颜色（全局）",
	},
	outline_specials_colour_tooltip = {
		en = "Adjust the colour to apply to all indicators for special attacks.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
		ru = "Настройте цвет для всех индикаторов специальных атак. Значения от 0 до 255, где 255 — максимальная интенсивность, 0 — отсутствие цвета.",
		["zh-cn"] = "设置所有特殊攻击预警的颜色，数值0~255。",
	},
	outline_specials_colour_R = {
		en = "Special Attack Colour: Red",
		ru = "Цвет спец атак: Красный",
		["zh-cn"] = "预警颜色：红",
	},
	outline_specials_colour_G = {
		en = "Special Attack Colour: Green",
		ru = "Цвет спец атак: Зелёный",
		["zh-cn"] = "预警颜色：绿",
	},
	outline_specials_colour_B = {
		en = "Special Attack Colour: Blue",
		ru = "Цвет спец атак: Синий",
		["zh-cn"] = "预警颜色：蓝",
	},
})

-- Overhead Enemy Markers settings
table.insert(localisations_to_add, {
	markers_settings = {
		en = "{#color(" .. colours.title .. ")}Enemy Overhead Markers{#reset()}",
		ru = "{#color(" .. colours.title .. ")}Маркеры над головами врагов{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}敌人头顶标记{#reset()}",
	},
	markers_enable = {
		en = "Enable Overhead Markers?",
		ru = "Включить маркеры над головами?",
		["zh-cn"] = "启用头顶标记",
	},
	markers_enable_tooltip = {
		en = "Toggles a diamond shape overhead marker for enemies, which can be used to help pin-point specific enemy locations from afar or in a group.",
		ru = "Включает ромбовидные маркеры над головами врагов, помогающие точно определить местоположение конкретного врага на расстоянии или в толпе.",
		["zh-cn"] = "在敌人头顶显示菱形标记，便于远距离或人群中定位目标。",
	},
	markers_horde_enable = {
		en = "Enable Overhead Markers for horde enemies?",
		ru = "Включить маркеры над головами для орды врагов?",
		["zh-cn"] = "尸潮怪显示头顶标记",
	},
	markers_horde_enable_tooltip = {
		en = "Enables the overhead marker for horde enemies, such as poxwalkers.",
		ru = "Включает маркеры над головами для орды врагов, например, чумных ходоков.",
		["zh-cn"] = "为疫变步行者等尸潮怪显示头顶标记。",
	},
	markers_non_horde_enable = {
		en = "Enable Overhead Markers for non-horde enemies?",
		ru = "Включить маркеры над головами для не-орды?",
		["zh-cn"] = "非尸潮怪启用头顶标记",
	},
	markers_non_horde_enable_tooltip = {
		en = "Enables the overhead marker for non-horde enemies, such as elites, specials, and monsters.",
		ru = "Включает маркеры над головами для не-орды: элитных, специалистов и чудовищ.",
		["zh-cn"] = "为精英、特感和巨兽等非尸潮怪显示头顶标记。",
	},
	overhead_marker_uses_healthbar_colour = {
		en = "Use healthbar colours for overhead markers?",
		ru = "Использовать цвета полосок здоровья для маркеров над головами?",
		["zh-cn"] = "头顶标记使用血条颜色？",
	},
	overhead_marker_uses_healthbar_colour_tooltip = {
		en = "Toggles the overhead markers to use the enemies' healthbar colour instead of the default colour.",
		ru = "Включает использование цвета полоски здоровья врага для маркера вместо цвета по умолчанию.",
		["zh-cn"] = "开启后头顶标记使用敌人血条颜色，而非默认颜色。",
	},
	marker_visual_style = {
		en = "Overhead Marker Style",
		ru = "Стиль маркера над головой",
		["zh-cn"] = "头顶标记样式",
	},
	marker_visual_style_tooltip = {
		en = "Selects which visual is used as the overhead marker.\n\nDiamond: The default diamond marker.\nSimple health tracker: Shows a quadrant-based (25, 50, 75, 100) health tracker using the healthbar colours.\nEnemy type icon: Replaces the marker with the enemy type icon (elite, special, sniper, etc.). Uses the healthbar icon colours and per-type icon toggles.",
		ru = "Выбирает визуальный стиль маркера над головой.\nРомб: стандартный ромбовидный маркер.\nПростой трекер здоровья: показывает здоровье по квадрантам (25, 50, 75, 100) с использованием цветов полоски здоровья.\nИконка типа врага: заменяет маркер иконкой типа врага (элитный, специалист, снайпер и т.д.). Использует цвета иконок полосы здоровья и переключатели типов.",
		["zh-cn"] = "选择头顶标记使用的样式。\n菱形：默认的菱形标记。\n简易血量：显示四段式（25/50/75/100）血量指示，使用血条颜色。\n敌人类型图标：用敌人类型图标（精英、特感、狙击手等）替换标记。使用血条的图标颜色与各类别的图标开关。",
	},
	marker_style_diamond = {
		en = "Diamond",
		ru = "Ромб",
		["zh-cn"] = "菱形",
	},
	marker_style_simple_health = {
		en = "Simple health tracker",
		ru = "Простой трекер здоровья",
		["zh-cn"] = "简易血量",
	},
	marker_style_type_icon = {
		en = "Enemy type icon",
		ru = "Иконка типа врага",
		["zh-cn"] = "敌人类型图标",
	},
	marker_size = {
		en = "Marker Scale",
		ru = "Масштаб маркера",
		["zh-cn"] = "标记大小",
	},
	marker_size_tooltip = {
		en = "Adjust the scale of the overhead marker.",
		ru = "Настройте масштаб маркера над головой.",
		["zh-cn"] = "调整头顶标记的缩放比例。",
	},
	marker_y_offset = {
		en = "Adjust Y offset for overhead markers",
		ru = "Смещение Y для маркеров над головами",
		["zh-cn"] = "标记垂直偏移",
	},
	marker_y_offset_tooltip = {
		en = "Sets the Y offset or height from the ground for the overhead markers.",
		ru = "Устанавливает вертикальное смещение (высоту от земли) для маркеров над головами.",
		["zh-cn"] = "设置头顶标记的高度偏移。",
	},
	marker_bg_colour = {
		en = "Colour for marker background",
		ru = "Цвет фона маркера",
		["zh-cn"] = "标记背景颜色",
	},
	marker_bg_colour_A = {
		en = "Alpha",
		ru = "Альфа",
		["zh-cn"] = "透明度",
	},
	marker_bg_colour_R = {
		en = "Red",
		ru = "Красный",
		["zh-cn"] = "红",
	},
	marker_bg_colour_G = {
		en = "Green",
		ru = "Зелёный",
		["zh-cn"] = "绿",
	},
	marker_bg_colour_B = {
		en = "Blue",
		ru = "Синий",
		["zh-cn"] = "蓝",
	},
	marker_bg_colour_tooltip = {
		en = "Select a colour for the background of the overhead markers.",
		ru = "Выберите цвет фона маркеров над головами.",
		["zh-cn"] = "设置头顶标记的背景颜色。",
	},
	marker_display_option = {
		en = "Overhead Marker Display Option",
		ru = "Режим отображения маркеров над головами",
		["zh-cn"] = "头顶标记显示方式",
	},
	marker_display_option_tooltip = {
		en = "Controls when overhead markers are shown.\n\nAlways show: Markers are always visible.\nHide unless damaged: Markers hide after 5 seconds of no damage taken, reappear on damage.\nHide when damaged: Markers hide after 5 seconds if damage has been taken, show otherwise.",
		ru = "Управляет отображением маркеров над головами.\nВсегда показывать: маркеры видны постоянно.\nСкрывать, если не повреждён: маркеры скрываются через 5 секунд после последнего урона, появляются при получении урона.\nСкрывать при получении урона: маркеры скрываются через 5 секунд после получения урона, в остальное время видны.",
		["zh-cn"] = "控制头顶标记的显示时机。\n永久显示：标记一直可见。\n仅受伤时显示：敌人5秒未受到伤害就隐藏标记，受到伤害后重新显示。\n受伤后隐藏：敌人受到伤害5秒后隐藏标记，未受伤时正常显示。",
	},
	always_show = {
		en = "Always show",
		ru = "Всегда показывать",
		["zh-cn"] = "永久显示",
	},
	hide_unless_damaged = {
		en = "Show only when damaged",
		ru = "Показывать только при повреждении",
		["zh-cn"] = "仅敌人受伤时显示",
	},
	hide_when_damaged = {
		en = "Hide when damaged",
		ru = "Скрывать при повреждении",
		["zh-cn"] = "敌人受伤后隐藏",
	},
	markers_show_only_aimed = {
		en = "Only show markers when aiming at enemy?",
		ru = "Показывать маркеры только при наведении на врага?",
		["zh-cn"] = "仅准星对准敌人才显示标记？",
	},
	markers_show_only_aimed_tooltip = {
		en = "Only show overhead markers and healthbars for the enemy you are currently aiming at with your crosshair.",
		ru = "Показывать маркеры над головами и полоски здоровья только для врага, на которого вы в данный момент наведены прицелом.",
		["zh-cn"] = "只对当前准星瞄准的敌人显示头顶标记和血条。",
	},
	aim_cone_angle = {
		en = "Aim detection cone angle (degrees)",
		ru = "Угол конуса обнаружения наведения (градусы)",
		["zh-cn"] = "准星瞄准判定角度（度）",
	},
	aim_cone_angle_tooltip = {
		en = "Sets the width of the cone used to decide which enemies count as 'aimed at'. Higher values make the aim filter more forgiving.",
		ru = "Устанавливает ширину конуса, используемого для определения, на какого врага «наведены». Более высокие значения делают фильтр более снисходительным.",
		["zh-cn"] = "设置判定“被瞄准”的锥形角度，数值越大越容易判定为正在瞄准。",
	},
	only_tagged_enemies = {
		en = "Only show for tagged enemies?",
		ru = "Показывать только для отмеченных врагов?",
		["zh-cn"] = "仅被标记的敌人才显示？",
	},
	only_tagged_enemies_tooltip = {
		en = "Only show overhead markers, healthbars, and debuffs for enemies that have been tagged by a teammate.",
		ru = "Показывать маркеры над головами, полоски здоровья и ослабления только для врагов, отмеченных союзником.",
		["zh-cn"] = "只有被队友标记的敌人，才会显示头顶标记、血条以及减益效果。",
	},
})

-- stagger settings localisations
table.insert(localisations_to_add, {
	stagger_settings = {
		en = "{#color(" .. colours.title .. ")}Stagger Detection{#reset()}",
		ru = "{#color(" .. colours.title .. ")}Обнаружение ошеломления{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}硬直检测{#reset()}",
	},
	debuff_stagger_enable = {
		en = "Enable custom stagger debuff?",
		ru = "Включить пользовательское ослабление ошеломления?",
		["zh-cn"] = "启用自定义硬直减益？",
	},
	debuff_stagger_enable_tooltip = {
		en = "Adds a new custom debuff to the debuff widgets to show 'staggered'.",
		ru = "Добавляет новое пользовательское ослабление в виджеты ослаблений для отображения состояния «ошеломлён».",
		["zh-cn"] = "在减益组件中添加硬直状态显示。",
	},
	outline_stagger_enable = {
		en = "Enable stagger outlines for non-horde enemies?",
		ru = "Включить контуры ошеломления для не-орды?",
		["zh-cn"] = "非尸潮怪启用硬直轮廓？",
	},
	outline_stagger_enable_tooltip = {
		en = "Adds an outline to all non-horde enemies that are staggered.",
		ru = "Добавляет контур всем не-орды врагам, находящимся в состоянии ошеломления.",
		["zh-cn"] = "为处于硬直状态的非尸潮敌人显示轮廓。",
	},
	outline_stagger_horde_enable = {
		en = "Enable stagger outlines for horde enemies?",
		ru = "Включить контуры ошеломления для орды?",
		["zh-cn"] = "尸潮怪启用硬直轮廓？",
	},
	outline_stagger_horde_enable_tooltip = {
		en = "Adds an outline to all horde enemies that are staggered",
		ru = "Добавляет контур всем врагам орды, находящимся в состоянии ошеломления.",
		["zh-cn"] = "为处于硬直状态的尸潮敌人显示轮廓。",
	},
	stagger_flash = {
		en = "Enable flashing for stagger outlines (Global)",
		ru = "Включить мигание для контуров ошеломления (глобально)",
		["zh-cn"] = "硬直轮廓闪烁（全局）",
	},
	stagger_flash_tooltip = {
		en = "Applies a flashing effect to stagger outline. \n\nDisable for a solid colour instead.",
		ru = "Добавляет эффект мигания контурам ошеломления. Отключите для постоянного цвета.",
		["zh-cn"] = "硬直轮廓启用闪烁效果，关闭则为纯色。",
	},
	stagger_pulse_speed = {
		en = "Stagger Pulse Speed",
		ru = "Скорость пульсации ошеломления",
		["zh-cn"] = "硬直闪烁速度",
	},
	stagger_pulse_speed_tooltip = {
		en = "Set a speed for the flashing of the stagger flash. With a lower value being faster flashing.",
		ru = "Установите скорость мигания индикатора ошеломления. Меньшее значение = более быстрое мигание.",
		["zh-cn"] = "设置硬直闪烁速度，数值越低越快。",
	},
	outline_stagger_colour = {
		en = "Stagger Colour",
		ru = "Цвет ошеломления",
		["zh-cn"] = "硬直颜色",
	},
	outline_stagger_colour_tooltip = {
		en = "Adjust the colour to apply to all indicators for staggers.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
		ru = "Настройте цвет для всех индикаторов ошеломления. Значения от 0 до 255, где 255 — максимальная интенсивность, 0 — отсутствие цвета.",
		["zh-cn"] = "设置硬直提示颜色，数值0~255。",
	},
	outline_stagger_colour_R = {
		en = "Stagger Colour: Red",
		ru = "Цвет ошеломления: Красный",
		["zh-cn"] = "硬直颜色：红",
	},
	outline_stagger_colour_G = {
		en = "Stagger Colour: Green",
		ru = "Цвет ошеломления: Зелёный",
		["zh-cn"] = "硬直颜色：绿",
	},
	outline_stagger_colour_B = {
		en = "Stagger Colour: Blue",
		ru = "Цвет ошеломления: Синий",
		["zh-cn"] = "硬直颜色：蓝",
	},
})

-- Healthbar settings
table.insert(localisations_to_add, {
	healthbar_settings = {
		en = "{#color(" .. colours.title .. ")}Healthbars{#reset()}",
		ru = "{#color(" .. colours.title .. ")}Полоски здоровья{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}血条{#reset()}",
	},
	healthbar_text_settings = {
		en = "{#color(" .. colours.title .. ")}Healthbar Text Options{#reset()}",
		ru = "{#color("
			.. colours.title
			.. ")}Настройки текста полосок здоровья{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}血条文本设置{#reset()}",
	},
	healthbar_enable = {
		en = "Enable Healthbars? (Global)",
		ru = "Включить полоски з��оровья? (глобально)",
		["zh-cn"] = "启用血条（全局）",
	},
	healthbar_enable_tooltip = {
		en = "Globally toggles healthbars for enemies. Specific enemy types can be enabled/disabled further below.",
		ru = "Глобальное включение/отключение полосок здоровья для врагов. Конкретные типы врагов можно включать/отключать ниже.",
		["zh-cn"] = "全局开关敌人血条，可在下方单独配置各类型。",
	},
	healthbar_only_in_meatgrinder = {
		en = "Only show healthbars in Meat Grinder?",
		ru = "Показывать полоски здоровья только в Мясорубке?",
		["zh-cn"] = "仅在灵能室显示血条？",
	},
	healthbar_only_in_meatgrinder_tooltip = {
		en = "Toggle to only show healthbars in the Meat Grinder. Other features like debuffs, markers, and outlines will still work normally in live matches.",
		ru = "Включите, чтобы показывать полоски здоровья только в Мясорубке. Другие функции, такие как ослабления, маркеры и контуры, будут работать в обычных матчах.",
		["zh-cn"] = "开启后仅在灵能室内显示血条。在正式对局中，减益、标记和轮廓等其他功能仍正常工作。",
	},
	hb_enable_bar = {
		en = "Show healthbar bar?",
		ru = "Показывать полосу здоровья?",
		["zh-cn"] = "显示血量进度条？",
	},
	hb_enable_bar_tooltip = {
		en = "Toggle the healthbar visual bar itself. If disabled, the bar will be hidden but text/numbers can still show.",
		ru = "Включает визуальную полоску здоровья. Если отключено, полоска скрыта, но текст/числа могут отображаться.",
		["zh-cn"] = "开关可视化血量条。关闭进度条后，文字和数值仍然可以正常显示。",
	},
	hb_enable_text = {
		en = "Show healthbar text?",
		ru = "Показывать текст на полоске здоровья?",
		["zh-cn"] = "显示血条文字内容？",
	},
	hb_enable_text_tooltip = {
		en = "Toggle the healthbar text (name, health numbers, armour type). If disabled, text will be hidden but the bar can still show.",
		ru = "Включает текст на полоске здоровья (имя, цифры здоровья, тип брони). Если отключено, текст скрыт, но полоса может отображаться.",
		["zh-cn"] = "开关血条上的文字（敌人名称、血量数值、护甲类型），关闭文字后血量条依旧正常显示。",
	},
	hb_y_offset = {
		en = "Adjust Y offset for healthbars",
		ru = "Смещение Y для полосок здоровья",
		["zh-cn"] = "血条垂直偏移",
	},
	hb_y_offset_tooltip = {
		en = "Sets the Y offset or height from the ground for the healthbars.",
		ru = "Устанавливает вертикальное смещение (высоту от земли) для полосок здоровья.",
		["zh-cn"] = "设置血条的高度偏移。",
	},
	hb_text_show_max_health = {
		en = "Show Max Health?",
		ru = "Показывать максимальное здоровье?",
		["zh-cn"] = "显示最大血量？",
	},
	hb_text_show_max_health_tooltip = {
		en = "Toggles displaying the max health on the current health text elements.",
		ru = "Включает отображение максимального здоровья в текущих текстовых элементах здоровья.",
		["zh-cn"] = "在当前血量旁显示最大血量。",
	},
	hb_gap_padding_scale = {
		en = "Healthbar widget gap scale",
		ru = "Масштаб промежутка между элементами полоски здоровья",
		["zh-cn"] = "血条组件间距缩放",
	},
	hb_gap_padding_scale_tooltip = {
		en = "Adjust the scale of the gap between the healthbar widgets. A lower number will make the text elements closer and 'tighter'.",
		ru = "Настройте масштаб промежутка между виджетами полоски здоровья. Меньшее значение сближает текстовые элементы, делая их более «компактными».",
		["zh-cn"] = "调整血条组件之间的间距，数值越小越紧凑。",
	},
	healthbar_type_icon_enable = {
		en = "Enable healthbar enemy type icon?",
		ru = "Включить иконку типа врага на полоске здоровья?",
		["zh-cn"] = "显示敌人类型图标",
	},
	healthbar_type_icon_enable_tooltip = {
		en = "Toggles a class-based icon next to the healthbar as an option to track enemy types from afar.",
		ru = "Включает иконку класса рядом с полоской здоровья, чтобы можно было определять типы врагов на расстоянии.",
		["zh-cn"] = "在血条旁显示敌人类型图标，便于远距离识别。",
	},
	hb_toggle_ghostbar = {
		en = "Enable Ghost Healthbar?",
		ru = "Включить «призрачную» полоску здоровья?",
		["zh-cn"] = "启用伤害延迟血条",
	},
	hb_toggle_ghostbar_tooltip = {
		en = "Toggles a dark 'ghost' bar next to the current health bar, when you deal large amounts of damage to an enemy.",
		ru = "Включает тёмную «призрачную» полоску рядом с текущей полоской здоровья, когда вы наносите большой урон врагу.",
		["zh-cn"] = "造成大额伤害时，显示灰色延迟伤害条。",
	},
	hb_padding_scale = {
		en = "Scale for the decorative frame around the healthbar (Global)",
		ru = "Масштаб декоративной рамки вокруг полоски здоровья (глобально)",
		["zh-cn"] = "血条外框缩放（全局）",
	},
	hb_padding_scale_tooltip = {
		en = "A global scale for the decorative frame element around the enemies current health.\n\n1 = Default\n2 = 2x size ",
		ru = "Глобальный масштаб декоративной рамки вокруг текущего здоровья врага.\n1 = по умолчанию, 2 = двойной размер.",
		["zh-cn"] = "血条装饰外框的全局大小，1=默认，2=双倍。",
	},
	hb_text_top_left_01 = {
		en = "Above Healthbar Text option",
		ru = "Текст над полоской здоровья",
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
		ru = "Выберите текст для отображения в слоте над полоской здоровья.\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Тип врага:{#reset()} Показывает класс/категорию врага (элитный, специалист и т.д.)\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Имя врага:{#reset()} Показывает имя врага (крушитель, ходок и т.д.)\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Тип брони:{#reset()} Показывает тип зоны брони, по которой был нанесён удар (панцирная, противоосколочная и т.д.)",
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
		ru = "Текст под полоской здоровья (опция 1)",
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
		ru = "Выберите текст для отображения в слоте под полоской здоровья (первая строка).\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Тип врага:{#reset()} Показывает класс/категорию врага (элитный, специалист и т.д.)\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Имя врага:{#reset()} Показывает имя врага (крушитель, ходок и т.д.)\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Тип брони:{#reset()} Показывает тип зоны брони, по которой был нанесён удар (панцирная, противоосколочная и т.д.)",
		["zh-cn"] = "选择血条下方第一行显示内容。",
	},
	hb_text_bottom_left_02 = {
		en = "Below Healthbar Text option 2",
		ru = "Текст под полоской здоровья (опция 2)",
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
		ru = "Выберите текст для отображения во втором слоте под полоской здоровья.\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Тип врага:{#reset()} Показывает класс/категорию врага (элитный, специалист и т.д.)\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Имя врага:{#reset()} Показывает имя врага (крушитель, ходок и т.д.)\n"
			.. "{#color("
			.. colours.subtitle
			.. ")}Тип брони:{#reset()} Показывает тип зоны брони, по которой был нанесён удар (панцирная, противоосколочная и т.д.)",
		["zh-cn"] = "选择血条下方第二行显示内容。",
	},

	healthbar_segments_enable = {
		en = "Toggle Healthbar Segments",
		ru = "Включить сегменты полоски здоровья",
		["zh-cn"] = "启用血条分段",
	},
	healthbar_segments_enable_tooltip = {
		en = "Adds small lines to the healthbar to indicate percentages of 25, 50 and 75.",
		ru = "Добавляет маленькие линии на полоску здоровья для обозначения процентов 25, 50 и 75.",
		["zh-cn"] = "在血条上添加刻度线，标记25%%/50%%/75%%血量。",
	},
	hb_horde_enable = {
		en = "Enable individual horde healthbars?",
		ru = "Включить индивидуальные полоски здоровья для орды?",
		["zh-cn"] = "尸潮怪显示独立血条",
	},
	hb_horde_enable_tooltip = {
		en = "Toggles individual healthbars for horde enemies.\nWarning: This can have a hit to performance if staring directly at a large group of horde enemies, without the clustering enabled.",
		ru = "Включает индивидуальные полоски здоровья для орды врагов. Внимание: может снизить производительность при взгляде на большую орду врагов без включённой кластеризации.",
		["zh-cn"] = "为每个尸潮小怪显示独立血条。",
	},
	hb_horde_clusters_enable = {
		en = "Enable clustered horde healthbars?",
		ru = "Включить кластеризованные полоски здоровья для орды?",
		["zh-cn"] = "尸潮血条聚合",
	},
	hb_horde_clusters_enable_tooltip = {
		en = "Toggles clustered healthbars for horde enemies.\nThis works when there is a large gathering of 'horde' type enemies in close proximity.\n\nTheir healthbar will combine into one large healthbar and follow around the horde.",
		ru = "Включает кластеризованные полоски здоровья для орды врагов. Это работает, когда большое количество врагов типа «орда» находится близко друг к другу. Их полоски здоровья объединяются в одну большую полосу, которая следует за ордой.",
		["zh-cn"] = "大量尸潮怪聚集时，合并为一个聚合血条。",
	},
	hb_horde_clusters_size = {
		en = "Cluster Size",
		ru = "Размер кластера",
		["zh-cn"] = "聚合规模",
	},
	hb_horde_clusters_size_tooltip = {
		en = "Adjust the number of the same enemies in close proximity to be considered as a 'cluster' for the clustered healthbars.",
		ru = "Настройте количество одинаковых врагов в непосредственной близости, чтобы они считались «кластером» для кластеризованных полосок здоровья.",
		["zh-cn"] = "设定触发聚合血条的同类敌人数量阈值。",
	},
	hb_hide_after_no_damage = {
		en = "Hide healthbars after no damage received?",
		ru = "Скрывать полоски здоровья при отсутствии урона?",
		["zh-cn"] = "无伤害后隐藏血条",
	},
	hb_hide_after_no_damage_tooltip = {
		en = "Toggle hiding of healthbars for non-horde enemies after a short delay of no damage taken. Can be used to reduce visual clutter.\n\nIf disabled, healthbars will always be visible.",
		ru = "Включает скрытие полосок здоровья для не-орды после короткой задержки без получения урона. Помогает уменьшить визуальный шум. Если отключено, полоски здоровья всегда видны.",
		["zh-cn"] = "停止攻击后短暂延迟自动隐藏血条，减少画面杂乱。关闭则永久显示。",
	},
	hb_show_when_debuffed = {
		en = "Show healthbars for debuffed enemies?",
		ru = "Показывать полоски здоровья для врагов с ослаблениями?",
		["zh-cn"] = "受减益效果的敌人显示血条？",
	},
	hb_show_when_debuffed_tooltip = {
		en = "Keeps healthbars visible (and shows them for horde enemies) while the enemy has an active debuff such as bleeding, burning, or being stunned. Useful for tracking damage-over-time effects.",
		ru = "Оставляет полоски здоровья видимыми (и показывает их для орды врагов), пока на враге действует ослабление, например, кровотечение, горение или ошеломление. Полезно для отслеживания эффектов длительного урона.",
		["zh-cn"] = "敌人身上存在流血、燃烧、硬控等减益效果时，保持血条显示（尸潮怪也会显示），方便追踪持续伤害。",
	},
	hb_horde_hide_after_no_damage = {
		en = "Hide horde healthbars after no damage received?",
		ru = "Скрывать полоски здоровья орды при отсутствии урона?",
		["zh-cn"] = "尸潮怪无伤害后隐藏血条",
	},
	hb_horde_hide_after_no_damage_tooltip = {
		en = "Toggle hiding of healthbars for horde enemies after a short delay of no damage taken. Can be used to reduce visual clutter.\n\nIf disabled, healthbars will always be visible.",
		ru = "Включает скрытие полосок здоровья для орды врагов после короткой задержки без получения урона. Помогает уменьшить визуальный шум. Если отключено, полоски здоровья всегда видны.",
		["zh-cn"] = "尸潮怪在无伤害后自动隐藏血条。",
	},
	damage_number_settings = {
		en = "{#color(" .. colours.title .. ")}Damage Numbers{#reset()}",
		ru = "{#color(" .. colours.title .. ")}Цифры урона{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}伤害数字{#reset()}",
	},
	hb_show_damage_numbers = {
		en = "Show damage numbers?",
		ru = "Показывать цифры урона?",
		["zh-cn"] = "显示浮动伤害数字",
	},
	hb_show_damage_numbers_tooltip = {
		en = "Toggles damage numbers when attacking enemies showing how much damage you are dealing.\n\nSee 'Damage type' for more options.",
		ru = "Включает отображение цифр урона при атаке врагов, показывая, сколько урона вы наносите. См. «Тип урона» для дополнительных опций.",
		["zh-cn"] = "攻击敌人时显示伤害数值，可在下方选择样式。",
	},
	hb_damage_numbers_track_friendly = {
		en = "Show Friendly Damage?",
		ru = "Показывать урон союзников?",
		["zh-cn"] = "显示队友伤害",
	},
	hb_damage_numbers_track_friendly_tooltip = {
		en = "Whether damage on enemies will be shown if friendly players harm them, or if damage should only show if you are the one to damage the enemy.",
		ru = "Показывать ли урон по врагам, если его наносят союзники, или только ваш собственный урон.",
		["zh-cn"] = "是否显示队友对敌人造成的伤害。",
	},
	hb_damage_numbers_add_total = {
		en = "Add together damage numbers",
		ru = "Суммировать цифры урона",
		["zh-cn"] = "伤害数字合并",
	},
	hb_damage_numbers_add_total_tooltip = {
		en = "Whether the damage numbers in a small timeframe should be added together into one larger number, or if each damage should be shown individually.",
		ru = "Суммировать ли цифры урона за короткий промежуток времени в одно большее число, или показывать каждое значение отдельно.",
		["zh-cn"] = "短时间内的伤害合并为一个总数值显示。",
	},
	damage_number_flashy_speed = {
		en = "Flashy numbers move speed",
		ru = "Скорость движения мерцающих цифр",
		["zh-cn"] = "醒目伤害数字移动速度",
	},
	damage_number_flashy_speed_tooltip = {
		en = "The speed at which the flashy damage numbers move.",
		ru = "Скорость, с которой движутся мерцающие цифры урона.",
		["zh-cn"] = "控制醒目样式伤害数字上浮移动的速度。",
	},
	hb_damage_show_only_latest = {
		en = "Only show last damaged enemies?",
		ru = "Показывать только последних врагов?",
		["zh-cn"] = "仅显示最近攻击的敌人",
	},
	hb_damage_show_only_latest_tooltip = {
		en = "Toggle showing the healthbars of only the last damaged enemies. See below for a slider to control how many last damaged enemies to track.",
		ru = "Показывать полоски здоровья только последних врагов, которым был нанесён урон. См. ниже ползунок для настройки количества отслеживаемых врагов.",
		["zh-cn"] = "仅显示最近受到伤害的敌人血条。",
	},
	hb_damage_show_only_latest_value = {
		en = "Number of last damaged enemies to track",
		ru = "Количество отслеживаемых последних врагов",
		["zh-cn"] = "最近攻击敌人追踪数量",
	},
	hb_damage_show_only_latest_value_tooltip = {
		en = "Set the amount of last damaged enemies to track for the 'Only show last damaged enemies' setting.\n\nSetting this too low may cause a flickering effect, as damage-over-time effects still count as player damage.",
		ru = "Установите количество последних врагов, которым был нанесён урон, для отслеживания в настройке «Показывать только последних врагов». Слишком низкое значение может вызвать мерцание, так как эффекты длительного урона всё ещё считаются уроном игрока.",
		["zh-cn"] = "设置追踪的最近伤害敌人数量，过低可能导致闪烁。",
	},
	hb_text_show_health = {
		en = "Show current health on healthbar?",
		ru = "Показывать текущее здоровье на полоске?",
		["zh-cn"] = "显示当前血量数值",
	},
	hb_text_show_damage_tooltip = {
		en = "Toggles a text-based indicator near the healthbar showing the current health and max health.",
		ru = "Включает текстовый индикатор рядом с полоской здоровья, показывающий текущее и максимальное здоровье.",
		["zh-cn"] = "在血条旁显示当前/最大血量。",
	},
	hb_text_show_damage = {
		en = "Show current damage next to health?",
		ru = "Показывать текущий урон рядом со здоровьем?",
		["zh-cn"] = "显示伤害数值",
	},
	hb_text_show_damage_tooltip = {
		en = "Toggles a text-based indicator alongside the current/max health displaying current damage received.",
		ru = "Включает текстовый индикатор рядом с текущим/максимальным здоровьем, показывающий полученный урон.",
		["zh-cn"] = "在血量旁显示已承受伤害。",
	},
	hb_damage_number_types = {
		en = "Damage type",
		ru = "Тип урона",
		["zh-cn"] = "伤害数字样式",
	},
	hb_damage_number_types_tooltip = {
		en = "Options for the varying forms of damage numbers.\n\nTry them out in the range to see which one suits you best!",
		ru = "Варианты отображения цифр урона. Попробуйте их в Мясорубке, чтобы выбрать подходящий!",
		["zh-cn"] = "选择伤害数字显示样式，可在靶场测试效果。",
	},
	hb_show_armour_types = {
		en = "Show armour type",
		ru = "Показывать тип брони",
		["zh-cn"] = "显示护甲类型",
	},
	hb_show_armour_types_tooltip = {
		en = "Toggles a text-based indicator near the healthbar showing the type of armour you hit when damaging enemies.\n\nCan be useful to see what weapons to use.",
		ru = "Включает текстовый индикатор рядом с полоской здоровья, показывающий тип брони, по которой вы нанесли урон. Полезно для выбора оружия.",
		["zh-cn"] = "显示攻击命中的护甲类型，便于选择对应武器。",
	},
	hb_frame = {
		en = "Healthbar background frame",
		ru = "Фоновая рамка полоски здоровья",
		["zh-cn"] = "血条背景框",
	},
	hb_frame_tooltip = {
		en = "A section of frames that are used as a background for the healthbars.\n\nTry them out to see the difference.",
		ru = "Набор рамок, используемых в качестве фона для полосок здоровья. Попробуйте их, чтобы увидеть разницу.",
		["zh-cn"] = "选择血条背景框样式，可切换查看效果。",
	},
	hb_size_width = {
		en = "Healthbar width",
		ru = "Ширина полоски здоровья",
		["zh-cn"] = "血条宽度",
	},
	hb_size_width_tooltip = {
		en = "The max width of the healthbar.\n\nThe information scales with this too, so try different sizes to see what suits you best.",
		ru = "Максимальная ширина полоски здоровья. Информация также масштабируется, поэтому попробуйте разные размеры.",
		["zh-cn"] = "血条最大宽度，文本会随宽度自动适配。",
	},
	hb_size_height = {
		en = "Healthbar height",
		ru = "Высота полоски здоровья",
		["zh-cn"] = "血条高度",
	},
	hb_size_height_tooltip = {
		en = "The max height of the healthbar.\n\nThe information scales with this too, so try different sizes to see what suits you best.",
		ru = "Максимальная высота полоски здоровья. Информация также масштабируется, поэтому попробуйте разные размеры.",
		["zh-cn"] = "血条最大高度，文本会随高度自动适配。",
	},
	damage_number_duration = {
		en = "Duration to show numbers",
		ru = "Длительность отображения цифр",
		["zh-cn"] = "伤害数字显示时长",
	},
	damage_number_duration_tooltip = {
		en = "Set a duration for damage numbers to show for.\n\nThe numbers will fade out after this amount of time.",
		ru = "Установите длительность отображения цифр урона. Цифры будут исчезать по истечении этого времени.",
		["zh-cn"] = "设置伤害数字的显示时长，超时后淡出。",
	},
	hb_ghostbar_opacity = {
		en = "Ghostbar opacity",
		ru = "Прозрачность призрачной полосы",
		["zh-cn"] = "延迟血条透明度",
	},
	hb_ghostbar_opacity_tooltip = {
		en = "Adjust the opacity of the ghostbar. 0 = transparent, 1 = opaque.",
		ru = "Настройте прозрачность призрачной полосы. 0 = прозрачная, 1 = непрозрачная.",
		["zh-cn"] = "调整延迟伤害条的透明度，0=全透明，1=不透明。",
	},
	hb_toggle_ghostbar_colour = {
		en = "Ghostbar uses colour?",
		ru = "Призрачная полоса использует цвет?",
		["zh-cn"] = "延迟血条使用彩色？",
	},
	hb_toggle_ghostbar_colour_tooltip = {
		en = "Should the ghostbar use the colour of the healthbar of the enemy?\n\nIf disabled, the ghostbar will be white.",
		ru = "Должна ли призрачная полоса использовать цвет полоски здоровья врага? Если отключено, призрачная полоса будет белой.",
		["zh-cn"] = "延迟血条使用敌人血条颜色，关闭则为白色。",
	},
	damage_number_crit_colour = {
		en = "Crit damage colour",
		ru = "Цвет критического урона",
		["zh-cn"] = "暴击伤害颜色",
	},
	damage_number_crit_colour_R = {
		en = "Crit Colour: Red",
		ru = "Цвет критического урона: Красный",
		["zh-cn"] = "暴击颜色：红",
	},
	damage_number_crit_colour_G = {
		en = "Crit Colour: Green",
		ru = "Цвет критического урона: Зелёный",
		["zh-cn"] = "暴击颜色：绿",
	},
	damage_number_crit_colour_B = {
		en = "Crit Colour: Blue",
		ru = "Цвет критического урона: Синий",
		["zh-cn"] = "暴击颜色：蓝",
	},
	damage_number_crit_colour_tooltip = {
		en = "Adjust the colour for critical hit damage numbers.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
		ru = "Настройте цвет цифр критического урона. Значения от 0 до 255, где 255 — максимальная интенсивность, 0 — отсутствие цвета.",
		["zh-cn"] = "设置暴击伤害数字的颜色，数值0~255。",
	},
	damage_number_weakspot_colour = {
		en = "Weakspot damage colour",
		ru = "Цвет урона по уязвимому месту",
		["zh-cn"] = "弱点伤害颜色",
	},
	damage_number_weakspot_colour_R = {
		en = "Weakspot Colour: Red",
		ru = "Цвет уязвимого места: Красный",
		["zh-cn"] = "弱点颜色：红",
	},
	damage_number_weakspot_colour_G = {
		en = "Weakspot Colour: Green",
		ru = "Цвет уязвимого места: Зелёный",
		["zh-cn"] = "弱点颜色：绿",
	},
	damage_number_weakspot_colour_B = {
		en = "Weakspot Colour: Blue",
		ru = "Цвет уязвимого места: Синий",
		["zh-cn"] = "弱点颜色：蓝",
	},
	damage_number_weakspot_colour_tooltip = {
		en = "Adjust the colour for weakspot hit damage numbers.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
		ru = "Настройте цвет цифр урона по слабой точке. Значения от 0 до 255, где 255 — максимальная интенсивность, 0 — отсутствие цвета.",
		["zh-cn"] = "设置弱点伤害数字的颜色，数值0~255。",
	},
	readable_max_damage_numbers = {
		en = "Max numbers to show",
		ru = "Максимальное количество отображаемых цифр",
		["zh-cn"] = "最大显示数字",
	},
	readable_max_damage_numbers_tooltip = {
		en = "Set a cap for the max damage numbers to show for the Readable damage number type.",
		ru = "Установите ограничение на максимальное количество отображаемых цифр для типа «Читаемый».",
		["zh-cn"] = "设置清晰样式伤害数字的最大显示值。",
	},
	readable_damage_number_gap = {
		en = "Readable damage number gap",
		ru = "Промежуток между читаемыми цифрами урона",
		["zh-cn"] = "清晰伤害数字间距",
	},
	readable_damage_number_gap_tooltip = {
		en = "Adjusts the horizontal spacing between each Readable damage number. Higher values spread the numbers further apart.",
		ru = "Настраивает горизонтальный промежуток между каждой читаемой цифрой урона. Более высокие значения увеличивают расстояние между цифрами.",
		["zh-cn"] = "调整清晰样式伤害数字之间的水平间距。",
	},
	toughness_colour = {
		en = "Toughness Bar Settings",
		ru = "Настройки полоски стойкости",
		["zh-cn"] = "坚韧条设置",
	},
	toughness_enabled = {
		en = "Toggle Toughness Features",
		ru = "Включить поддержку стойкости",
		["zh-cn"] = "启用坚韧条功能",
	},
	toughness_enabled_tooltip = {
		en = "Overlays a toughness bar over the healthbar if the enemy has toughness.",
		ru = "Накладывает полоску стойкости поверх полоски здоровья, если у врага есть стойкость.",
		["zh-cn"] = "为拥有坚韧值的敌人显示坚韧条。",
	},
	toughness_colour_tooltip = {
		en = "Select a colour for the toughness bar.",
		ru = "Выберите цвет для полоски стойкости.",
		["zh-cn"] = "设置坚韧条颜色。",
	},
	toughness_colour_R = {
		en = "Toughness Bar: Red",
		ru = "Полоска стойкости: Красный",
		["zh-cn"] = "坚韧条：红",
	},
	toughness_colour_G = {
		en = "Toughness Bar: Green",
		ru = "Полоска стойкости: Зелёный",
		["zh-cn"] = "坚韧条：绿",
	},
	toughness_colour_B = {
		en = "Toughness Bar: Blue",
		ru = "Полоска стойкости: Синий",
		["zh-cn"] = "坚韧条：蓝",
	},
	toughness_text_enabled = {
		en = "Adjust health text to show the toughness values?",
		ru = "Настроить текст здоровья для отображения значений стойкости?",
		["zh-cn"] = "血量文本显示坚韧值",
	},
	toughness_text_enabled_tooltip = {
		en = "Swaps out the healtbar text 'health' options to their toughness, if the enemy has toughness.",
		ru = "Заменяет текст здоровья на значения стойкости, если у врага есть стойкость.",
		["zh-cn"] = "敌人拥有坚韧值时，文本显示坚韧而非血量。",
	},
	toughness_text_colour_enabled = {
		en = "Change health text to use toughness colour?",
		ru = "Изменить цвет текста здоровья на цвет стойкости?",
		["zh-cn"] = "血量文本使用坚韧颜色",
	},
	toughness_text_colour_enabled_tooltip = {
		en = "Swaps out the healtbar text 'health' colour to the toughness colour, if the enemy has toughness.",
		ru = "Заменяет цвет текста здоровья на цвет стойкости, если у врага есть стойкость.",
		["zh-cn"] = "敌人拥有坚韧值时，文本使用坚韧条颜色。",
	},
	hb_show_dps = {
		en = "Show DPS",
		ru = "Показывать УВС",
		["zh-cn"] = "显示每秒伤害",
	},
	hb_show_dps_tooltip = {
		en = "Displays a brief damage-per-second text element after you kill an enemy.\n\nUses the damage number duration as a timer for how long to display.",
		ru = "Отображает краткий текстовый элемент урона в секунду (УВС) после убийства врага. Использует длительность отображения цифр урона как таймер.",
		["zh-cn"] = "击杀敌人后短暂显示DPS，显示时长同伤害数字。",
	},
	damage_number_scale = {
		en = "Damage number scale",
		ru = "Масштаб цифр урона",
		["zh-cn"] = "伤害数字大小",
	},
	damage_number_scale_tooltip = {
		en = "Adjust the scale of the damage numbers. Multiplies with the global text scale too...",
		ru = "Настройте масштаб цифр урона. Также умножается на глобальный масштаб текста.",
		["zh-cn"] = "调整伤害数字缩放，会与全局文本缩放相乘。",
	},
	damage_number_y_offset = {
		en = "Damage number y offset",
		ru = "Смещение Y для цифр урона",
		["zh-cn"] = "伤害数字垂直偏移",
	},
	damage_number_y_offset_tooltip = {
		en = "Adjust the up/down position of the damage numbers. \n\nA value of 0 will be close to the top of the enemy, the higher the value, the lower the position. Only effects the floating or flashy damage numbers.",
		ru = "Настройте вертикальное положение цифр урона. Значение 0 — близко к вершине врага, чем выше значение, тем ниже положение. Влияет только на плавающие или эффектные цифры.",
		["zh-cn"] = "调整伤害数字的上下位置，仅影响浮动/炫丽样式。",
	},
	healthbar_type_icon_scale = {
		en = "Healthbar Type icon scale",
		ru = "Масштаб иконки типа на полоске здоровья",
		["zh-cn"] = "血条图标大小",
	},
	healthbar_type_icon_scale_tooltip = {
		en = "Adjust the scale of the type icon.",
		ru = "Настройте масштаб иконки типа.",
		["zh-cn"] = "调整敌人类型图标的缩放。",
	},
	show_dn_in_range_only = {
		en = "Only show damage numbers in Meat Grinder?",
		ru = "Показывать цифры урона только в Мясорубке?",
		["zh-cn"] = "仅在靶场显示伤害数字",
	},
	show_dn_in_range_only_tooltip = {
		en = "Toggle to only show damage numbers in the Meat Grinder. Requires damage numbers to be enabled.",
		ru = "Включает отображение цифр урона только в Мясорубке. Требуется включение цифр урона.",
		["zh-cn"] = "仅在练靶场显示伤害数字，需要先启用伤害数字。",
	},
	hb_toggle_base_boss_healthbar = {
		en = "Show default boss healthbars?",
		ru = "Показывать стандартные полоски здоровья боссов?",
		["zh-cn"] = "显示原版头目血条？",
	},
	hb_toggle_base_boss_healthbar_tooltip = {
		en = "Toggles the base-game boss healthbars at the top of the screen. If disabled, the boss healthbars will be hidden.",
		ru = "Включает/отключает стандартные полоски здоровья боссов в верхней части экрана. При отключении они скрываются.",
		["zh-cn"] = "开启或关闭游戏原生屏幕顶部的头目血条，关闭后原版头目血条会隐藏。",
	},
	hb_endcaps_enabled = {
		en = "Toggle endcaps on healthbars?",
		ru = "Включить концевые заглушки на полосках здоровья?",
		["zh-cn"] = "启用血条末端标记？",
	},
	hb_endcaps_enabled_tooltip = {
		en = "Toggles a small white rectangle at the end of the current health/toughness to help distinguish current health against the background.",
		ru = "Включает небольшой белый прямоугольник в конце текущего здоровья/стойкости, чтобы помочь отличить текущее значение на фоне.",
		["zh-cn"] = "在当前血量和坚韧条末端添加白色短标记，便于在复杂背景下看清剩余数值边界。",
	},
	toughness_electric = {
		en = "Toggle 'lightning' effect on toughness bar?",
		ru = "Включить эффект «молнии» на полоске стойкости?",
		["zh-cn"] = "开启坚韧条闪电特效？",
	},
	toughness_electric_tooltip = {
		en = "Toggles a lightning effect that is overlayed on the current toughness bar.",
		ru = "Включает эффект молнии, накладываемый на текущую полоску стойкости.",
		["zh-cn"] = "给坚韧进度条添加一层闪电动态特效。",
	},
	healthbar_colour_preset = {
		en = "Healthbar Colour Preset",
		ru = "Пресет цветов полоски здоровья",
		["zh-cn"] = "血条配色预设",
	},
	healthbar_colour_preset_tooltip = {
		en = "Pick a preset to apply to all enemy healthbars. Note that the individual overrides will override this.\n\nWARNING: This WILL reset your group overrides to these colours.",
		ru = "Выберите пресет для применения ко всем полоскам здоровья врагов. Индивидуальные переопределения имеют приоритет. ВНИМАНИЕ: это сбросит ваши групповые настройки на эти цвета.",
		["zh-cn"] = "选择一套配色应用到全部敌人血条，单独敌人的自定义设置优先级高于该预设。\n警告：执行后会重置所有敌人分组的自定义颜色。",
	},
	red = {
		en = "Full Red",
		ru = "Полностью красный",
		["zh-cn"] = "全红色",
	},
	colourful = {
		en = "Colourful (Enemy Type Dependent)",
		ru = "Цветной (зависит от типа врага)",
		["zh-cn"] = "彩色模式（按敌人类型区分）",
	},
})

-- Debuff settings
table.insert(localisations_to_add, {
	debuff_settings = {
		en = "{#color(" .. colours.title .. ")}Debuffs{#reset()}",
		ru = "{#color(" .. colours.title .. ")}Ослабления{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}减益效果{#reset()}",
	},
	debuff_enable = {
		en = "Enable debuffs (Global)",
		ru = "Включить ослабления (глобально)",
		["zh-cn"] = "启用减益（全局）",
	},
	debuff_enable_tooltip = {
		en = "Global toggle for debuff display.\n\nDebuffs are grouped into two categories, Damage over Time (DoT) and Utility. DoT debuffs are displayed upwards, whereas utility debuffs display downwards.\n\nDoT debuffs include things like bleeding, fire, electricity. Whereas utility includes rending, talent debuffs etc.",
		ru = "Глобальное включение отображения ослаблений. Ослабления делятся на две категории: урон с течением времени (УСТВ) и полезные. УСТВ отображаются вверх, а полезные — вниз. УСТВ включают кровотечение, огонь, электричество. Полезные — пробивание, ослабления от талантов и т.д.",
		["zh-cn"] = "全局开关减益显示。\n减益分为持续伤害（向上显示）和功能减益（向下显示）。\n持续伤害：流血、燃烧、触电；功能减益：脆弱、增伤、虚弱等。",
	},
	debuff_dot_enable = {
		en = "Enable Damage-Over-Time debuffs",
		ru = "Включить ослабления с уроном с течением времени",
		["zh-cn"] = "显示持续伤害减益",
	},
	debuff_dot_enable_tooltip = {
		en = "DoT debuffs are displayed upwards and include things like bleeding, fire, electricity.",
		ru = "Ослабления урона с течением времени (УСТВ) отображаются вверх и включают кровотечение, огонь, электричество.",
		["zh-cn"] = "流血、燃烧、触电等持续伤害效果向上显示。",
	},
	debuff_utility_enable = {
		en = "Enable Utility debuffs",
		ru = "Включить полезные ослабления",
		["zh-cn"] = "显示功能减益",
	},
	debuff_utility_enable_tooltip = {
		en = "Utility debuffs are displayed downwards and include things like rending, damage increases, weakening.",
		ru = "Полезные ослабления отображаются вниз и включают пробивание, увеличение урона, ослабление.",
		["zh-cn"] = "脆弱、增伤、虚弱等功能效果向下显示。",
	},
	debuff_keyword_enable = {
		en = "Enable keyword state debuffs",
		ru = "Включить ослабления состояний по ключевым словам",
		["zh-cn"] = "显示状态减益",
	},
	debuff_keyword_enable_tooltip = {
		en = "State debuffs detected from buff keywords, such as bleeding, electrocuted and burning.",
		ru = "Ослабления состояний, определяемые по ключевым словам баффов, например, кровотечение, электрошок и горение.",
		["zh-cn"] = "通过关键字检测的状态减益，如流血、触电和燃烧。",
	},
	split_debuff_types = {
		en = "Split DoT and Utility debuffs?",
		ru = "Разделять УСТВ и полезные ослабления?",
		["zh-cn"] = "分离持续伤害与功能型减益？",
	},
	split_debuff_types_tooltip = {
		en = "Choose to split the damage-over-time and utility debuffs into two different groups, or to keep them together as one group.",
		ru = "Выберите, разделять ли ослабления урона с течением времени (УСТВ) и полезные на две разные группы, или объединить их в одну.",
		["zh-cn"] = "选择将持续伤害减益与功能型减益分为两组，或合并为一组显示。",
	},
	debuff_names = {
		en = "Show Debuff Names",
		ru = "Показывать названия ослаблений",
		["zh-cn"] = "显示减益名称",
	},
	debuff_names_tooltip = {
		en = "Toggles a text display of different debuffs applied to enemies.",
		ru = "Включает текстовое отображение различных ослаблений, наложенных на врагов.",
		["zh-cn"] = "显示敌人身上的减益效果文本。",
	},
	debuffs_abrv = {
		en = "Abbreviate Debuff Names?",
		ru = "Сокращать названия ослаблений?",
		["zh-cn"] = "减益名称缩写",
	},
	debuffs_abrv_tooltip = {
		en = "Should the debuff names use abbreviated (shortend) versions if available? \nIf disabled, the full text name will show - with the talent name too. e.g. 'Increased Damage Taken (Soften Them Up)' \nIf enabled, it will be shortened to just the effect e.g. '+ Damage'",
		ru = "Использовать ли сокращённые версии названий ослаблений, если они доступны? При отключении показывается полное название с именем таланта (например, «Увеличенный урон (Ослабить их)»). При включении — только эффект («+ Урон»).",
		["zh-cn"] = "开启后使用缩写（如+伤害），关闭则显示完整名称。",
	},
	debuffs_combine = {
		en = "Combine similar debuffs?",
		ru = "Объединять похожие ослабления?",
		["zh-cn"] = "合并同类减益",
	},
	debuffs_combine_tooltip = {
		en = "Should multiple debuffs that apply a similar effect be combined into one entry?\nFor example, if enabled, multiple '+ Damage Taken' debuffs applied via different sources would combine into one value.",
		ru = "Объединять ли несколько ослаблений с одинаковым эффектом в одну запись? Например, при включении несколько ослаблений «+ Урон» от разных источников объединятся в одно значение.",
		["zh-cn"] = "多个同类增伤/减益合并显示为一个数值。",
	},
	debuff_names_fade = {
		en = "Fade out debuffs",
		ru = "Затухание ослаблений",
		["zh-cn"] = "减益自动淡出",
	},
	debuff_names_fade_tooltip = {
		en = "Toggles fading out of the text-based debuff names after a short delay.\n\nIf this is disabled, debuff names will always show when applied.",
		ru = "Включает затухание текстовых названий ослаблений после короткой задержки. При отключении названия всегда видны.",
		["zh-cn"] = "减益效果短暂显示后自动消失，关闭则持续显示。",
	},
	debuff_show_on_body = {
		en = "Show debuffs on body of enemy?",
		ru = "Показывать ослабления на теле врага?",
		["zh-cn"] = "减益显示在敌人身上",
	},
	debuff_type_show_on_body_override = {
		en = "Override show debuffs on body of enemy?",
		ru = "Переопределить показ ослаблений на теле врага?",
		["zh-cn"] = "减益显示在敌人身上",
	},
	debuff_individual_show_on_body_override = {
		en = "Override show debuffs on body of enemy?",
		ru = "Переопределить показ ослаблений на теле врага?",
		["zh-cn"] = "减益显示在敌人身上",
	},
	debuff_show_on_body_tooltip = {
		en = "Toggles positioning of the debuff tracker.\n\nIf enabled, the debuffs will be displays in the middle of the enemy model, allowing for easier tracking - but may get in the way.\n\nIf disabled, the debuffs will be placed alongside the healthbar above the head of the enemy.\n\nThe overrides in group/individual overrides tab will force enable this setting for your specific enemies. So disable the global option for those to work.",
		ru = "Включает позиционирование метки ослаблений. При включении ослабления отображаются в центре модели врага, что облегчает отслеживание, но может мешать. При отключении ослабления отображаются рядом с полоской здоровья над головой врага. Переопределения на вкладке групповых/индивидуальных настроек принудительно включают эту опцию для конкретных врагов, поэтому отключите глобальную опцию, чтобы они работали.",
		["zh-cn"] = "开启：减益显示在敌人身体中央；关闭：显示在头顶血条旁。",
	},
	debuff_horde_enable = {
		en = "Enable debuffs for horde enemies?",
		ru = "Включить ослабления для орды врагов?",
		["zh-cn"] = "尸潮怪显示减益",
	},
	debuff_horde_enable_tooltip = {
		en = "Toggle to show debuffs for horde enemies.\nWarning: This can have a hit to performance if staring directly at a large group of horde enemies.",
		ru = "Включает отображение ослаблений для орды врагов. Внимание: может снизить производительность при взгляде на большую группу орды врагов.",
		["zh-cn"] = "为尸潮小怪显示减益效果。",
	},
	debuff_toggles = {
		en = "Choose a debuff to toggle",
		ru = "Выберите ослабление для переключения",
		["zh-cn"] = "选择要开关的减益",
	},
	debuff_toggles_tooltip = {
		en = "Pick a debuff here to be able to toggle it on or off in the option below.",
		ru = "Выберите ослабление здесь, чтобы иметь возможность включить или отключить его в опции ниже.",
		["zh-cn"] = "选择一个减益，在下方选项中开启或关闭。",
	},
	debuff_selected_enable = {
		en = "Selected debuff toggle",
		ru = "Переключение выбранного ослабления",
		["zh-cn"] = "选中减益开关",
	},
	debuff_selected_enable_tooltip = {
		en = "Toggle the selected debuff on or off.",
		ru = "Включите или отключите выбранное ослабление.",
		["zh-cn"] = "开启或关闭选中的减益效果。",
	},
	debuff_icons = {
		en = "Toggle Debuff Icons",
		ru = "Включить иконки ослаблений",
		["zh-cn"] = "显示减益图标",
	},
	debuff_icons_tooltip = {
		en = "Decide whether to show the debuff icons or not.",
		ru = "Решите, показывать ли иконки ослаблений.",
		["zh-cn"] = "选择是否显示减益效果图标。",
	},
	debuff_stacks_icon_colour = {
		en = "Debuff Stacks use Icon Colour?",
		ru = "Количество ослаблений использует цвет иконки?",
		["zh-cn"] = "层数使用图标颜色",
	},
	debuff_stacks_icon_colour_tooltip = {
		en = "Decide whether to use the debuff icon category colour on the stack/percentage display?",
		ru = "Использовать ли цвет категории иконки ослабления для отображения количества/процента?",
		["zh-cn"] = "减益层数/百分比使用图标分类颜色。",
	},

	debuff_group_colour = {
		en = "Debuff Overrides",
		ru = "Переопределения ослаблений",
		["zh-cn"] = "减益分组颜色覆盖",
	},
	debuff_group_selected = {
		en = "Debuff",
		ru = "Ослабление",
		["zh-cn"] = "减益分组",
	},
	debuff_group_selected_tooltip = {
		en = "Select a debuff group to adjust settings for.",
		ru = "Выберите группу ослаблений для настройки.",
		["zh-cn"] = "选择一个减益分组进行设置。",
	},
	debuff_group_colour_R = {
		en = "Debuff Icon Colour: Red",
		ru = "Цвет иконки ослаблений: Красный",
		["zh-cn"] = "减益图标：红",
	},
	debuff_group_colour_G = {
		en = "Debuff Icon Colour: Green",
		ru = "Цвет иконки ослаблений: Зелёный",
		["zh-cn"] = "减益图标：绿",
	},
	debuff_group_colour_B = {
		en = "Debuff Icon Colour: Blue",
		ru = "Цвет иконки ослаблений: Синий",
		["zh-cn"] = "减益图标：蓝",
	},
	debuff_group_colour_tooltip = {
		en = "Adjust the colour of the chosen debuff group above.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
		ru = "Настройте цвет выбранной группы ослаблений выше. Значения от 0 до 255, где 255 — максимальная интенсивность, 0 — отсутствие цвета.",
		["zh-cn"] = "调整所选减益分组的图标颜色，数值0~255。",
	},
	debuff_max_stacks_colour = {
		en = "Debuff Max Stacks Settings",
		ru = "Настройки максимального количества ослаблений",
		["zh-cn"] = "减益最大层数设置",
	},
	debuff_max_stacks_colour_tooltip = {
		en = "Adjust the colour of the stack text when at max stacks.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
		ru = "Настройте цвет текста количества при достижении максимума. Значения от 0 до 255.",
		["zh-cn"] = "设置减益达到最大层数时的文字颜色。",
	},
	debuff_max_stacks_scale = {
		en = "Increase text scale?",
		ru = "Увеличить масштаб текста?",
		["zh-cn"] = "放大层数文本",
	},
	debuff_max_stacks_scale_tooltip = {
		en = "Increases the scale of the text for stacks that are at their max stacks value.",
		ru = "Увеличивает масштаб текста для количества, достигшего максимального значения.",
		["zh-cn"] = "最大层数时放大文本显示。",
	},
	debuff_max_stacks_colour_toggle = {
		en = "Toggle max stacks colour?",
		ru = "Включить цвет максимального количества?",
		["zh-cn"] = "启用最大层数颜色",
	},
	debuff_max_stacks_colour_toggle_tooltip = {
		en = "Toggle to adjust the colour of the stacks when at max stacks.",
		ru = "Включите, чтобы настроить цвет количества при достижении максимума.",
		["zh-cn"] = "开启后最大层数使用自定义颜色。",
	},
	debuff_max_stacks_colour_R = {
		en = "Debuff Max Stacks Colour: Red",
		ru = "Цвет стака ослаблений: Красный",
		["zh-cn"] = "最大层数：红",
	},
	debuff_max_stacks_colour_G = {
		en = "Debuff Max Stacks Colour: Green",
		ru = "Цвет стака ослаблений: Зелёный",
		["zh-cn"] = "最大层数：绿",
	},
	debuff_max_stacks_colour_B = {
		en = "Debuff Max Stacks Colour: Blue",
		ru = "Цвет стака ослаблений: Синий",
		["zh-cn"] = "最大层数：蓝",
	},
	debuff_x_offset = {
		en = "Debuffs X offset scale",
		ru = "Смещение по X для ослаблений",
		["zh-cn"] = "减益水平偏移",
	},
	debuff_x_offset_tooltip = {
		en = "Adjust the left + right position of the debuffs. A lower value moves right, a higher value moves left. Adjust to your liking, or to fit to your widget config.",
		ru = "Настройте горизонтальное положение ослаблений. Меньшее значение смещает вправо, большее — влево.",
		["zh-cn"] = "调整减益的左右位置，数值小右移，大左移。",
	},
	debuff_y_offset = {
		en = "Debuffs Y offset scale",
		ru = "Смещение по Y для ослаблений",
		["zh-cn"] = "减益垂直偏移",
	},
	debuff_y_offset_tooltip = {
		en = "Adjust the up + down position of the debuffs.\n\nAdjust to your liking, or to fit to your widget config. Can have a different effect depending on your other settings, so just play around a bit :)",
		ru = "Настройте вертикальное положение ослаблений. Может по-разному влиять в зависимости от других настроек, так что просто поэкспериментируйте :)",
		["zh-cn"] = "调整减益的上下位置，仅在显示在身体上时生效。",
	},
	debuff_gap_name_icon_offset = {
		en = "Adjust the gap between the Name and Icon",
		ru = "Настройте промежуток между названием и иконкой",
		["zh-cn"] = "名称与图标间距",
	},
	debuff_gap_name_icon_offset_tooltip = {
		en = "Adjust the size of the gap between the debuff names and debuff icons. A lower value will be tighter together, a higher value will be further away. Adjust to your liking, or to fit to your widget config.",
		ru = "Настройте размер промежутка между названиями и иконками ослаблений.",
		["zh-cn"] = "调整减益名称与图标之间的距离。",
	},
	debuff_gap_icon_stack_offset = {
		en = "Adjust the gap between the Icon and Stacks",
		ru = "Настройте промежуток между иконкой и количеством",
		["zh-cn"] = "图标与层数间距",
	},
	debuff_gap_icon_stack_offset_tooltip = {
		en = "Adjust the size of the gap between the debuff icon and debuff stacks. A lower value will be tighter together, a higher value will be further away. Adjust to your liking, or to fit to your widget config.",
		ru = "Настройте размер промежутка между иконкой ослабления и его количеством.",
		["zh-cn"] = "调整减益图标与层数之间的距离。",
	},
	debuff_stacks_show_x = {
		en = "Show 'X' on stacks?",
		ru = "Показывать 'X' перед количеством?",
		["zh-cn"] = "层数显示X",
	},
	debuff_stacks_show_x_tooltip = {
		en = "Toggle to show the 'X' on the debuff stacks, meaning the multiplier. If disabled, will just show the number.",
		ru = "Показывать 'X' перед количеством ослаблений, обозначая множитель. При отключении показывается только число.",
		["zh-cn"] = "层数前显示X（如X3），关闭则只显示数字。",
	},
	debuff_stacks_show_x_space = {
		en = "Add a space after 'X' on stacks?",
		ru = "Добавить пробел после 'X'?",
		["zh-cn"] = "X后添加空格",
	},
	debuff_stacks_show_x_space_tooltip = {
		en = "Toggle to add a space between the 'X' and the stack counter on the debuff stacks, meaning the multiplier. If disabled, there will be no space.",
		ru = "Добавляет пробел между 'X' и числом. При отключении пробела нет.",
		["zh-cn"] = "在X和数字之间添加空格。",
	},
	debuff_icon_scale = {
		en = "Debuff Icon Scale",
		ru = "Масштаб иконок ослаблений",
		["zh-cn"] = "减益图标大小",
	},
	debuff_icon_scale_tooltip = {
		en = "Adjust the scale of the debuff icons. A lower value will be smaller, a higher value will be bigger. Adjust to your liking, or to fit to your widget config.",
		ru = "Настройте масштаб иконок ослаблений.",
		["zh-cn"] = "调整减益图标的缩放大小。",
	},
	debuff_stack_on_icon = {
		en = "Show stacks on icon?",
		ru = "Показывать количество на иконке?",
		["zh-cn"] = "层数显示在图标上",
	},
	debuff_stack_on_icon_tooltip = {
		en = "Toggle to move the stacks on top of the debuff icon.",
		ru = "Перемещает количество поверх иконки ослабления.",
		["zh-cn"] = "将层数数字显示在减益图标上方。",
	},
	debuff_gap_padding_scale = {
		en = "Row padding scale",
		ru = "Масштаб отступов между рядами",
		["zh-cn"] = "行间距缩放",
	},
	debuff_gap_padding_scale_tooltip = {
		en = "Adjust the padding gap between the rows of debuffs. A lower value will make the rows tighter together, a higher number will make them move apart.",
		ru = "Настройте промежуток между рядами ослаблений. Меньшее значение делает ряды более плотными, большее — раздвигает их.",
		["zh-cn"] = "调整减益行之间的间距，数值越小越紧凑。",
	},
	debuff_boss_healthbar_enable = {
		en = "Show boss debuffs on base-game boss healthbar?",
		ru = "Показывать ослабления боссов на стандартной полоске здоровья босса?",
		["zh-cn"] = "在Boss原始血条上显示减益效果？",
	},
	debuff_boss_healthbar_enable_tooltip = {
		en = "Shows active debuffs (bleed, burn, rending, etc.) on the boss healthbar at the top of the screen. Uses the same debuff detection system.",
		ru = "Показывает активные ослабления (кровотечение, ожог, пробивание и т.д.) на полоске здоровья босса в верхней части экрана. Использует ту же систему обнаружения ослаблений.",
		["zh-cn"] = "在屏幕顶部的Boss原始血条上显示当前减益效果（流血、燃烧、脆弱等）。",
	},
	debuff_horizontal = {
		en = "Toggle Horizontal Debuff Mode?",
		ru = "Включить горизонтальный режим ослаблений?",
		["zh-cn"] = "开启横向减益排列？",
	},
	debuff_horizontal_tooltip = {
		en = "Toggles a horizontal mode, instead of the default vertical list. Force hides names, but shows icons and stacks in a horizontal layout instead.",
		ru = "Включает горизонтальный режим вместо вертикального списка. Принудительно скрывает названия, но показывает иконки и количество в горизонтальном макете.",
		["zh-cn"] = "切换为横向布局，替代默认的纵向列表。会强制隐藏名称，仅以横向排列展示减益图标与层数。",
	},
	debuff_stacks_font_size = {
		en = "Debuff Stacks Font Size",
		ru = "Размер шрифта количества ослаблений",
		["zh-cn"] = "减益层数字体大小",
	},
	debuff_stacks_font_size_tooltip = {
		en = "Adjust the font size of the debuff stack/percentage counters.",
		ru = "Настройте размер шрифта для счётчиков количества/процентов ослаблений.",
		["zh-cn"] = "调整减益层数与百分比数字的字体尺寸。",
	},
	debuff_names_font_size = {
		en = "Debuff Name Font Size",
		ru = "Размер шрифта названий ослаблений",
		["zh-cn"] = "减益名称字体大小",
	},
	debuff_names_font_size_tooltip = {
		en = "Adjust the font size of the debuff names (if debuff names are enabled).",
		ru = "Настройте размер шрифта названий ослаблений (если они включены).",
		["zh-cn"] = "调整减益名称文字的字体大小（前提是开启减益名称显示）。",
	},
	boss_debuff_stack_font_size = {
		en = "Boss Healthbar Debuff Stack Font Size",
		ru = "Размер шрифта количества ослаблений на полоске босса",
		["zh-cn"] = "头目血条减益层数字号",
	},
	boss_debuff_stack_font_size_tooltip = {
		en = "Adjust the font size of the stack/percentage counters on the boss healthbar debuff display.",
		ru = "Настройте размер шрифта для счётчиков количества/процентов на полоске босса.",
		["zh-cn"] = "调整显示在原版头目血条上的减益层数数字大小。",
	},
	boss_debuff_icon_size = {
		en = "Boss Debuff Icon Scale",
		ru = "Масштаб иконок ослаблений босса",
		["zh-cn"] = "Boss减益图标缩放",
	},
	boss_debuff_icon_size_tooltip = {
		en = "Adjust the size of debuff icons displayed on the boss healthbar. This only affects boss debuffs, not regular enemy debuffs.",
		ru = "Настройте размер иконок ослаблений на полоске босса. Влияет только на ослабления боссов, а не обычных врагов.",
		["zh-cn"] = "调整Boss血条上减益图标的大小。仅影响Boss减益，不影响普通敌人减益。",
	},
	boss_debuff_settings = {
		en = "Boss Debuff Settings",
		ru = "Настройки ослаблений боссов",
		["zh-cn"] = "Boss减益设置",
	},
})

-- Group settings
table.insert(localisations_to_add, {
	group_settings = {
		en = "{#color(" .. colours.title .. ")}All below settings apply ONLY to the selected enemy type{#reset()}",
		ru = "{#color("
			.. colours.title
			.. ")}Все настройки ниже применяются ТОЛЬКО к выбранному типу врага{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}以下设置仅对选中的敌人类型生效{#reset()}",
	},
	enemy_group = {
		en = "Selected Enemy Type",
		ru = "Выбранный тип врага",
		["zh-cn"] = "选择敌人类型",
	},
	enemy_group_tooltip = {
		en = "Select an enemy type/class here to adjust their specific settings below.\n\nEnemy types can be seen on the healthbar with the 'Display enemy type' toggle enabled.",
		ru = "Выберите тип/класс врага для настройки его параметров ниже. Тип врага отображается на полоске здоровья при включённом отображении типа врага.",
		["zh-cn"] = "选择敌人类型，下方设置仅对该类型生效。\n可开启血��的敌人类型显示查看分类。",
	},
	reset_type_to_default_message = {
		en = "Reset settings for type '_type_' to default.",
		ru = "Сбросить настройки для типа '_type_' к значениям по умолчанию.",
		["zh-cn"] = "重置_type_类型的设置为默认值。",
	},
	reset_type_to_default = {
		en = "{#color(" .. colours.subtitle .. ")}Warning: {#reset()}Reset to defaults",
		ru = "{#color(" .. colours.subtitle .. ")}Внимание:{#reset()} Сбросить настройки",
		["zh-cn"] = "{#color(" .. colours.subtitle .. ")}警告：{#reset()}恢复默认设置",
	},
	reset_type_to_default_tooltip = {
		en = "Reset all enemy type specific settings to their default values.\n\nNote: This only affects the enemy type selected above.",
		ru = "Сбросить все настройки для выбранного типа врага к значениям по умолчанию. Влияет только на выбранный тип.",
		["zh-cn"] = "将当前选中敌人类型的所有设置重置为默认。",
	},

	-- outlines
	outline_type_enable = {
		en = "Enable outline?",
		ru = "Включить контур?",
		["zh-cn"] = "启用轮廓",
	},
	outline_type_enable_tooltip = {
		en = "Toggle outlines for your selected enemy type/class",
		ru = "Включить/выключить контуры для выбранного типа/класса врага.",
		["zh-cn"] = "为当前选中敌人类型开启/关闭轮廓。",
	},

	outline_type_colour = {
		en = "Outline colour (Enemy Type Specific)",
		ru = "Цвет контура (для данного типа)",
		["zh-cn"] = "轮廓颜色（类型专属）",
	},
	outline_type_colour_tooltip = {
		en = "Adjust the colour of the enemy type specific outline.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
		ru = "Настройте цвет контура для данного типа врага. Значения от 0 до 255.",
		["zh-cn"] = "设置当前敌人类型的轮廓颜色，数值0~255。",
	},

	outline_type_colour_R = {
		en = "Type Outline Colour: Red",
		ru = "Цвет контура по типу: Красный",
		["zh-cn"] = "轮廓颜色：红",
	},
	outline_type_colour_G = {
		en = "Type Outline Colour: Green",
		ru = "Цвет контура по типу: Зелёный",
		["zh-cn"] = "轮廓颜色：绿",
	},
	outline_type_colour_B = {
		en = "Type Outline Colour: Blue",
		ru = "Цвет контура по типу: Синий",
		["zh-cn"] = "轮廓颜色：蓝",
	},

	-- healthbars
	healthbar_type_enable = {
		en = "Enable healthbars?",
		ru = "Включить полоски здоровья?",
		["zh-cn"] = "启用血条",
	},
	healthbar_type_enable_tooltip = {
		en = "Toggle healthbars for your selected enemy type/class",
		ru = "Включить/выключить полоски здоровья для выбранного типа/класса врага.",
		["zh-cn"] = "为当前选中敌人类型开启/关闭血条。",
	},
	healthbar_type_always_show = {
		en = "Always show healthbar?",
		ru = "Всегда показывать полоску здоровья?",
		["zh-cn"] = "始终显示血条？",
	},
	healthbar_type_always_show_tooltip = {
		en = "When enabled, the global 'Hide healthbar after no damage' setting will be ignored for this enemy type, so their healthbars never fade out.",
		ru = "При включении для этого типа врага игнорируется глобальная настройка скрытия полоски после отсутствия урона, так что полоски всегда видны.",
		["zh-cn"] = "开启后，该敌人类型将忽略全局“无伤害后隐藏血条”设置，血条不会淡出。",
	},
	healthbar_type_colour = {
		en = "Healthbar colour (Enemy Type Specific)",
		ru = "Цвет полоски здоровья (для данного типа)",
		["zh-cn"] = "血条颜色（类型专属）",
	},
	healthbar_type_colour_tooltip = {
		en = "Adjust the colour of the enemy type specific healthbar's current health value.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
		ru = "Настройте цвет текущего здоровья для полоски данного типа врага. Значения от 0 до 255.",
		["zh-cn"] = "设置当前敌人类型的血条颜色，数值0~255。",
	},
	healthbar_type_colour_R = {
		en = "Type Healthbar Colour: Red",
		ru = "Цвет полоски по типу: Красный",
		["zh-cn"] = "血条颜色：红",
	},
	healthbar_type_colour_G = {
		en = "Type Healthbar Colour: Green",
		ru = "Цвет полоски по типу: Зелёный",
		["zh-cn"] = "血条颜色：绿",
	},
	healthbar_type_colour_B = {
		en = "Type Healthbar Colour: Blue",
		ru = "Цвет полоски по типу: Синий",
		["zh-cn"] = "血条颜色：蓝",
	},

	healthbar_icon_type_enable = {
		en = "Enable enemy type icons?",
		ru = "Включить иконки типа врага?",
		["zh-cn"] = "启用类型图标",
	},
	healthbar_icon_type_enable_tooltip = {
		en = "Toggle icon indicators for your selected enemy type/class.",
		ru = "Включить/выключить иконки для выбранного типа/класса врага.",
		["zh-cn"] = "为当前选中敌人类型开启/关闭类型图标。",
	},
	healthbar_icon_type_scale = {
		en = "Type icon scale",
		ru = "Масштаб иконки типа",
		["zh-cn"] = "图标大小",
	},
	healthbar_icon_type_scale_tooltip = {
		en = "Set the scale of the enemy type icons. 1 being 1x scale.",
		ru = "Установите масштаб иконок типа врага. 1 = стандартный размер.",
		["zh-cn"] = "设置敌人类型图标缩放，1=默认大小。",
	},
	healthbar_icon_type_glow_intensity = {
		en = "Type icon glow intensity",
		ru = "Интенсивность свечения иконки типа",
		["zh-cn"] = "图标发光强度",
	},
	healthbar_icon_type_glow_intensity_tooltip = {
		en = "Set the intensity of the glow.\n\n0 = Off\n100 = Max intensity",
		ru = "Установите интенсивность свечения. 0 = выкл, 100 = макс.",
		["zh-cn"] = "设置图标发光强度，0=关闭，100=最大。",
	},
	healthbar_icon_type_colour = {
		en = "Healthbar Icon Colour",
		ru = "Цвет иконки полоски здоровья",
		["zh-cn"] = "图标颜色",
	},
	healthbar_icon_type_colour_R = {
		en = "Type Icon Colour: Red",
		ru = "Цвет иконки по типу: Красный",
		["zh-cn"] = "图标颜色：红",
	},
	healthbar_icon_type_colour_G = {
		en = "Type Icon Colour: Green",
		ru = "Цвет иконки по типу: Зелёный",
		["zh-cn"] = "图标颜色：绿",
	},
	healthbar_icon_type_colour_B = {
		en = "Type Icon Colour: Blue",
		ru = "Цвет иконки по типу: Синий",
		["zh-cn"] = "图标颜色：蓝",
	},
	healthbar_icon_type_colour_tooltip = {
		en = "Adjust the colour of the enemy type specific icon.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
		ru = "Настройте цвет иконки для данного типа врага. Значения от 0 до 255.",
		["zh-cn"] = "设置当前敌人类型的图标颜色，数值0~255。",
	},

	-- debuffs
	debuff_type_enable = {
		en = "Enable debuffs?",
		ru = "Включить ослабления?",
		["zh-cn"] = "启用减益显示？",
	},
	debuff_type_enable_tooltip = {
		en = "Toggle debuffs for your selected enemy type/class",
		ru = "Включить/выключить ослабления для выбранного типа/класса врага.",
		["zh-cn"] = "为当前选中的敌人分类开启或关闭减益显示。",
	},
	healthbar_type_y_offset = {
		en = "Healthbar Y offset (Enemy Type Specific)",
		ru = "Смещение Y для полосок здоровья (для данного типа)",
		["zh-cn"] = "血条垂直偏移（分类独立设置）",
	},
	healthbar_type_y_offset_tooltip = {
		en = "Adjust the Y offset (height) for healthbars of this enemy type. Overrides the global Y offset for this type.",
		ru = "Настройте вертикальное смещение для полосок здоровья этого типа врага. Переопределяет глобальную настройку.",
		["zh-cn"] = "调整该类型敌人血条的高度，此项优先级高于全局垂直偏移设置。",
	},
	healthbar_type_y_offset_enabled = {
		en = "Enable Y offset override?",
		ru = "Включить переопределение Y?",
		["zh-cn"] = "启用垂直偏移覆盖",
	},
	healthbar_type_y_offset_enabled_tooltip = {
		en = "Toggle the Y offset override for this specific enemy type.",
		ru = "Включает переопределение вертикального смещения для данного типа врага.",
		["zh-cn"] = "为此类型开启垂直偏移覆盖。",
	},
	healthbar_individual_y_offset_enabled = {
		en = "Enable Y offset override?",
		ru = "Включить переопределение Y?",
		["zh-cn"] = "启用垂直偏移覆盖",
	},
	healthbar_individual_y_offset_enabled_tooltip = {
		en = "Toggle the Y offset override for this specific enemy.",
		ru = "Включает переопределение вертикального смещения для данного врага.",
		["zh-cn"] = "为此敌人开启垂直偏移覆盖。",
	},

	marker_group_overrides = {
		en = "Marker Group Overrides",
		ru = "Переопределения маркеров для групп",
		["zh-cn"] = "分组标记覆盖",
	},
	marker_type_enable = {
		en = "Enable markers?",
		ru = "Включить маркеры?",
		["zh-cn"] = "启用标记",
	},
	marker_type_enable_tooltip = {
		en = "Toggle markers for your selected enemy type",
		ru = "Включить/выключить маркеры для выбранного типа врага.",
		["zh-cn"] = "开关当前选中敌人类型的头顶标记。",
	},
})

-- enemy individual overrides localisations
table.insert(localisations_to_add, {
	["SELECT ENEMY"] = {
		en = "SELECT AN ENEMY",
		ru = "ВЫБЕРИТЕ ВРАГА",
		["zh-cn"] = "选择单个敌人",
	},
	individual_override_settings = {
		en = "OVERRIDE SPECIFIC ENEMIES",
		ru = "ПЕРЕОПРЕДЕЛЕНИЕ ДЛЯ КОНКРЕТНЫХ ВРАГОВ",
		["zh-cn"] = "单独敌人设置覆盖",
	},
	individual_overrides = {
		en = "Selected Enemy",
		ru = "Выбранный враг",
		["zh-cn"] = "选中敌人",
	},
	individual_overrides_tooltip = {
		en = "Selectively override specific enemy settings. These settings override the group settings above.",
		ru = "Выборочно переопределите настройки для конкретных врагов. Эти настройки имеют приоритет над групповыми.",
		["zh-cn"] = "为特定敌人单独覆盖设置，优先级高于分组设置。",
	},
	reset_individual_to_default = {
		en = "{#color(" .. colours.subtitle .. ")}Warning: {#reset()}Reset to defaults",
		ru = "{#color(" .. colours.subtitle .. ")}Внимание:{#reset()} Сбросить настройки",
		["zh-cn"] = "{#color(" .. colours.subtitle .. ")}警告：{#reset()}恢复默认设置",
	},
	reset_individual_to_default_tooltip = {
		en = "Reset settings for individual '_individual_' to default.",
		ru = "Сбросить настройки для отдельного врага '_individual_' к значениям по умолчанию.",
		["zh-cn"] = "重置选中敌人的设置为默认值。",
	},
	healthbar_individual_enable = {
		en = "Healthbar colour override?",
		ru = "Переопределение цвета полоски здоровья?",
		["zh-cn"] = "覆盖血条设置",
	},
	healthbar_individual_enable_tooltip = {
		en = "Toggle healthbar colour overriding for your selected enemy",
		ru = "Включите переопределение цвета полоски здоровья для выбранного врага.",
		["zh-cn"] = "为选中敌人覆盖血条颜色。",
	},
	healthbar_individual_force = {
		en = "Force healthbar on?",
		ru = "Принудительно включить полоску?",
		["zh-cn"] = "强制显示血条？",
	},
	healthbar_individual_force_tooltip = {
		en = "When enabled, the healthbar will always be shown for this enemy, even if the enemy type group has healthbars disabled.",
		ru = "При включении полоска здоровья всегда будет отображаться для этого врага, даже если в группе типа она отключена.",
		["zh-cn"] = "开启后该敌人始终显示血条，即使其类型分组已禁用血条。",
	},
	healthbar_individual_always_show = {
		en = "Always show healthbar?",
		ru = "Всегда показывать полоску здоровья?",
		["zh-cn"] = "始终显示血条？",
	},
	healthbar_individual_always_show_tooltip = {
		en = "When enabled, the global 'Hide healthbar after no damage' setting will be ignored for this specific enemy, so their healthbar never fades out.",
		ru = "При включении для этого конкретного врага игнорируется глобальная настройка скрытия полоски после отсутствия урона.",
		["zh-cn"] = "开启后，该敌人将忽略全局“无伤害后隐藏血条”设置，血条不会淡出。",
	},
	healthbar_individual_colour = {
		en = "Healthbar colour (Enemy Specific)",
		ru = "Цвет полоски здоровья (для конкретного врага)",
		["zh-cn"] = "血条颜色（敌人专属）",
	},
	healthbar_individual_colour_R = {
		en = "Individual Healthbar Colour: Red",
		ru = "Цвет индивидуальной полоски: Красный",
		["zh-cn"] = "独立血条颜色：红",
	},
	healthbar_individual_colour_G = {
		en = "Individual Healthbar Colour: Green",
		ru = "Цвет индивидуальной полоски: Зелёный",
		["zh-cn"] = "独立血条颜色：绿",
	},
	healthbar_individual_colour_B = {
		en = "Individual Healthbar Colour: Blue",
		ru = "Цвет индивидуальной полоски: Синий",
		["zh-cn"] = "独立血条颜色���蓝",
	},
	healthbar_individual_colour_tooltip = {
		en = "Adjust the colour of the overrided enemy healthbar's current health value.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
		ru = "Настройте цвет текущего здоровья для переопределённой полоски данного врага. Значения от 0 до 255.",
		["zh-cn"] = "设置该敌人专属血条颜色，数值0~255。",
	},
	outline_individual_enable = {
		en = "Enable outline override?",
		ru = "Включить переопределение контура?",
		["zh-cn"] = "覆盖轮廓设置",
	},
	outline_individual_enable_tooltip = {
		en = "Toggle outline overriding for your selected enemy. Note: Only enables or changes colours, disabling will not override the group settings.",
		ru = "Включает переопределение контура для выбранного врага. Примечание: только включение или изменение цвета; отключение не переопределяет групповые настройки.",
		["zh-cn"] = "为选中敌人覆盖轮廓设置，仅支持开启/改色。",
	},
	outline_individual_colour = {
		en = "Outline colour (Enemy Specific)",
		ru = "Цвет контура (для конкретного врага)",
		["zh-cn"] = "轮廓颜色（敌人专属）",
	},
	outline_individual_colour_R = {
		en = "Individual Outline Colour: Red",
		ru = "Цвет индивидуального контура: Красный",
		["zh-cn"] = "独立轮廓颜色：红",
	},
	outline_individual_colour_G = {
		en = "Individual Outline Colour: Green",
		ru = "Цвет индивидуального контура: Зелёный",
		["zh-cn"] = "独立轮廓颜色：绿",
	},
	outline_individual_colour_B = {
		en = "Individual Outline Colour: Blue",
		ru = "Цвет индивидуального контура: Синий",
		["zh-cn"] = "独立轮廓颜色：蓝",
	},
	outline_individual_colour_tooltip = {
		en = "Adjust the colour of the overrided enemy outline.\n\nValues go between 0 and 255, with 255 being the most intense and 0 being none at all.",
		ru = "Настройте цвет переопределения контура для данного врага. Значения от 0 до 255.",
		["zh-cn"] = "设置该敌人专属轮廓颜色，数值0~255。",
	},
	markers_individual_toggle = {
		en = "Overhead markers override?",
		ru = "Переопределение маркеров над головой?",
		["zh-cn"] = "覆盖头顶标记",
	},
	markers_individual_toggle_tooltip = {
		en = "Toggle the overhead markers overriding for your selected enemy. This will take effect whether the global overhead markers are enabled or not. To allow only specific enemies to have the overhead markers.",
		ru = "Включает/выключает маркеры над головой для выбранного врага, независимо от глобальной настройки. Позволяет показывать маркеры только для определённых врагов.",
		["zh-cn"] = "为选定敌人单独强制开关头顶标记，不受全局标记总控影响，可单独指定特定敌人显示标记",
	},
	debuff_individual_enable = {
		en = "Toggle debuffs override?",
		ru = "Переопределение ослаблений?",
		["zh-cn"] = "覆盖减益设置",
	},
	debuff_individual_enable_tooltip = {
		en = "Toggle the debuff icons overriding for your selected enemy. This will take effect whether the global debuff icons are enabled or not. To allow only specific enemies to have the debuff icons.",
		ru = "Включает/выключает иконки ослаблений для выбранного врага, независимо от глобальной настройки. Позволяет показывать иконки только для определённых врагов.",
		["zh-cn"] = "为选定敌人单独强制开关减益图标，不受全局减益图标总控影响，可单独指定特定敌人显示减益图标。",
	},
	distance_individual_enable = {
		en = "Override draw distance?",
		ru = "Переопределить дистанцию отрисовки?",
		["zh-cn"] = "单独覆盖渲染距离",
	},
	distance_individual_enable_tooltip = {
		en = "Toggle the draw distance override for this enemy. When enabled, the enemy will only be visible within the specified distance below.",
		ru = "Включает переопределение дистанции отрисовки для этого врага. При включении враг будет виден только в пределах указанной дистанции.",
		["zh-cn"] = "为此敌人开启独立渲染距离。开启后，仅在下方设定距离内可见该单位。",
	},
	distance_individual_value = {
		en = "Draw distance (Enemy Specific)",
		ru = "Дистанция отрисовки (для конкретного врага)",
		["zh-cn"] = "渲染距离（敌人专属）",
	},
	distance_individual_value_tooltip = {
		en = "The max distance (in metres) this specific enemy will be visible for markers, healthbars and outlines.",
		ru = "Максимальное расстояние (в метрах), на котором для этого врага будут видны маркеры, полоски и контуры.",
		["zh-cn"] = "单位：米。超出该距离后，此敌人的标记、血条和轮廓都会隐藏。",
	},
	outline_distance_individual_enable = {
		en = "Outline draw distance (Enemy Specific)",
		ru = "Дистанция отрисовки контура (для конкретного врага)",
		["zh-cn"] = "轮廓渲染距离（敌人专属）",
	},
	outline_distance_individual_enable_tooltip = {
		en = "Toggle the outline draw distance override for this enemy. When enabled, the outline will only be visible within the specified distance below.",
		ru = "Включает переопределение дистанции отрисовки контура для этого врага. При включении контур будет виден только в пределах указанной дистанции.",
		["zh-cn"] = "为此敌人开启独立轮廓距离。开启后，仅在下方设定距离内显示轮廓。",
	},
	outline_distance_individual_value = {
		en = "Outline draw distance (Enemy Specific)",
		ru = "Дистанция отрисовки контура (для конкретного врага)",
		["zh-cn"] = "轮廓渲染距离（敌人专属）",
	},
	outline_distance_individual_value_tooltip = {
		en = "The max distance (in metres) this specific enemy's outline will be visible.",
		ru = "Максимальное расстояние (в метрах), на котором будет виден контур этого врага.",
		["zh-cn"] = "单位：米。超出该距离后，此敌人的轮廓将不再显示。",
	},
	healthbar_individual_width = {
		en = "Healthbar Width (Enemy Specific)",
		ru = "Ширина полоски здоровья (для конкретного врага)",
		["zh-cn"] = "血条宽度（敌人专属）",
	},
	healthbar_individual_width_tooltip = {
		en = "Override the width of the healthbar for this specific enemy.",
		ru = "Переопределяет ширину полоски здоровья для этого конкретного врага.",
		["zh-cn"] = "自定义该敌人血条的宽度。",
	},
	healthbar_individual_height = {
		en = "Healthbar Height (Enemy Specific)",
		ru = "Высота полоски здоровья (для конкретного врага)",
		["zh-cn"] = "血条高度（敌人专属）",
	},
	healthbar_individual_height_tooltip = {
		en = "Override the height of the healthbar for this specific enemy.",
		ru = "Переопределяет высоту полоски здоровья для этого конкретного врага.",
		["zh-cn"] = "自定义该敌人血条的高度。",
	},
	healthbar_individual_y_offset = {
		en = "Healthbar Y offset (Enemy Specific)",
		ru = "Смещение Y для полоски здоровья (для конкретного врага)",
		["zh-cn"] = "垂直偏移（独立敌人专用）",
	},
	healthbar_individual_y_offset_tooltip = {
		en = "Adjust the Y offset (height) for the healthbar of this specific enemy. Overrides both the global and type-level Y offset.",
		ru = "Настройте вертикальное смещение для полоски здоровья этого конкретного врага. Переопределяет глобальные и групповые настройки.",
		["zh-cn"] = "自定义该敌人血条的高度偏移，覆盖全局和分类级别的垂直偏移。",
	},
})

table.insert(localisations_to_add, {
	throttle_timings = {
		en = "{#color(" .. colours.title .. ")}WARNING: Throttle Timings{#reset()}",
		ru = "{#color("
			.. colours.title
			.. ")}ПРЕДУПРЕЖДЕНИЕ: Интервалы обновления{#reset()}",
		["zh-cn"] = "{#color(" .. colours.title .. ")}警告：性能节流时序{#reset()}",
	},
	general_throttle_rate = {
		en = "General Throttle Rate",
		ru = "Общая частота обновления",
		["zh-cn"] = "常规更新速率",
	},
	general_throttle_rate_tooltip = {
		en = "Adjust the rate at which all on-screen elements in enemies improved are updated.\n\nShouldn't really need to touch this, I recommend between 20-40 for a smooth experience. \n\nMaking this higher may help gain some fps in dense situations, but may introduce 'stuttering' on the widgets, as they will have a longer delay between updates.\n\nThis slider is shown roughly in milliseconds, so a value of 100 will update roughly 10 times per second, a value of 50 will update roughly 20 times per second etc. ",
		ru = "Настройте частоту обновления всех видимых элементов Улучшенных врагов.\nОбычно не требует изменения, рекомендуемый диапазон 20-40 для плавной работы.\nУвеличение может повысить FPS в плотных сценах, но может вызвать «задержки» виджетов.\nЗначения задаются в миллисекундах: 100 = ~10 обновлений в секунду, 50 = ~20 и т.д.",
		["zh-cn"] = "调整本模组所有屏幕内UI元素的更新速率。\n\n通常无需修改，为保证流畅体验，推荐值为 20-40。\n\n提高该数值可在敌人密集场景提升帧率，但会增加UI更新延迟，可能导致组件卡顿抖动。\n\n单位为毫秒，数值100代表每秒更新10次，数值50代表每秒更新20次。",
	},
	off_screen_throttle_rate = {
		en = "Off Screen Throttle Rate",
		ru = "Частота обновления для невидимых элементов",
		["zh-cn"] = "屏幕外更新速率",
	},
	off_screen_throttle_rate_tooltip = {
		en = "Adjust the rate at which all off-screen elements in enemies improved are updated. This only affects enemies that you cannot currently see in your view.\n\nShouldn't really need to touch this, I recommend between 150-200 for a smooth experience.\n\nMaking this higher may help gain some fps in dense situations, but may introduce a delay to the widgets appearing, as they will have a longer delay between updates.\n\nThis slider is shown roughly in milliseconds, so a value of 100 will update roughly 10 times per second, a value of 50 will update roughly 20 times per second etc. ",
		ru = "Настройте частоту обновления для элементов за пределами экрана. Влияет только на врагов, которых вы сейчас не видите.\nОбычно не требует изменения, рекомендуемый диапазон 150-200.\nУвеличение может повысить FPS, но может задержать появление виджетов.\nЗначения задаются в миллисекундах.",
		["zh-cn"] = "调整本模组所有屏幕外UI元素的更新速率，仅作用于视野外的敌人。\n\n通常无需修改，为保证流畅体验，推荐值为 150-200。\n\n提高该数值可在敌人密集场景提升帧率，但会延长UI显示延迟。\n\n单位为毫秒，数值100代表每秒更新10次，数值50代表每秒更新20次。",
	},
	outline_group_overrides = {
		en = "Outline Group Overrides",
		ru = "Групповые переопределения контуров",
		["zh-cn"] = "敌人分类‑轮廓独立设置",
	},
	healthbar_group_overrides = {
		en = "Healthbar Group Overrides",
		ru = "Групповые переопределения полосок здоровья",
		["zh-cn"] = "敌人分类‑血条独立设置",
	},
	healthbar_icon_group_overrides = {
		en = "Healthbar Icon Group Overrides",
		ru = "Групповые переопределения иконок полосок",
		["zh-cn"] = "敌人分类‑图标独立设置",
	},
	debuff_group_overrides = {
		en = "Debuff Group Overrides",
		ru = "Групповые переопределения ослаблений",
		["zh-cn"] = "敌人分类‑减益独立设置",
	},
	outline_individual_overrides = {
		en = "Outline Overrides",
		ru = "Индивидуальные переопределения контуров",
		["zh-cn"] = "单体敌人‑轮廓独立设置",
	},
	healthbar_individual_overrides = {
		en = "Healthbar Overrides",
		ru = "Индивидуальные переопределения полосок",
		["zh-cn"] = "单体敌人‑血条独立设置",
	},
	healthbar_icon_individual_overrides = {
		en = "Healthbar Icon Overrides",
		ru = "Индивидуальные переопределения иконок",
		["zh-cn"] = "单体敌人‑图标独立设置",
	},
	markers_individual_overrides = {
		en = "Markers Overrides",
		ru = "Индивидуальные переопределения маркеров",
		["zh-cn"] = "单体敌人‑头顶标记独立设置",
	},
	debuffs_individual_overrides = {
		en = "Debuffs Overrides",
		ru = "Индивидуальные переопределения ослаблений",
		["zh-cn"] = "单体敌人‑减益独立设置",
	},
	distance_individual_overrides = {
		en = "Distance Overrides",
		ru = "Индивидуальные переопределения дистанции",
		["zh-cn"] = "单体敌人‑渲染距离独立设置",
	},

	general_visibility_settings = {
		en = "General Visibility Settings",
		ru = "Общие настройки видимости",
		["zh-cn"] = "全局可见性设置",
	},
	general_font_settings = {
		en = "General Font Settings",
		ru = "Общие настройки шрифтов",
		["zh-cn"] = "全局字体设置",
	},
	marker_toggles = {
		en = "Marker Toggles",
		ru = "Переключатели маркеров",
		["zh-cn"] = "标记开关选项",
	},
	marker_customisation_settings = {
		en = "Marker Customisation Settings",
		ru = "Настройки внешнего вида маркеров",
		["zh-cn"] = "标记自定义设置",
	},
	healthbar_visibility_settings = {
		en = "Healthbar Visibility Settings",
		ru = "Настройки видимости полосок здоровья",
		["zh-cn"] = "血条显示控制",
	},
	healthbar_customisation_settings = {
		en = "Healthbar Customisation Settings",
		ru = "Настройки внешнего вида полосок",
		["zh-cn"] = "血条自定义选项",
	},
	healthbar_ghostbar_customisation_settings = {
		en = "Healthbar Ghostbar Customisation Settings",
		ru = "Настройки призрачной полоски",
		["zh-cn"] = "延迟虚影条自定义设置",
	},
	healthbar_icon_customisation_settings = {
		en = "Healthbar Icon Customisation Settings",
		ru = "Настройки иконок полосок",
		["zh-cn"] = "血条图标自定义设置",
	},
	healthbar_horde_customisation_settings = {
		en = "Healthbar Horde Customisation Settings",
		ru = "Настройки полосок для орды",
		["zh-cn"] = "尸潮怪血条自定义设置",
	},
	debuff_customisation_settings = {
		en = "Debuff Customisation Settings",
		ru = "Настройки внешнего вида ослаблений",
		["zh-cn"] = "减益总体自定义设置",
	},
	debuff_toggle_settings = {
		en = "Debuff Toggle Settings",
		ru = "Настройки переключения ослаблений",
		["zh-cn"] = "单独减益开关设置",
	},
	debuff_name_customisation_settings = {
		en = "Debuff Name Customisation Settings",
		ru = "Настройки названий ослаблений",
		["zh-cn"] = "减益文字自定义设置",
	},
	debuff_stacks_customisation_settings = {
		en = "Debuff Stacks Customisation Settings",
		ru = "Настройки количества ослаблений",
		["zh-cn"] = "减益层数自定义设置",
	},
	debuff_icon_customisation_settings = {
		en = "Debuff Icon Customisation Settings",
		ru = "Настройки иконок ослаблений",
		["zh-cn"] = "减益图标自定义设置",
	},
	debuff_positioning_settings = {
		en = "Debuff Positioning Settings",
		ru = "Настройки позиционирования ослаблений",
		["zh-cn"] = "减益位置偏移设置",
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
