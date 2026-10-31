local mod = get_mod("enemies_improved")

local BreedQueries = require("scripts/utilities/breed_queries")
local BossNameTemplates = require("scripts/settings/boss/boss_name_templates")
local minion_breeds = BreedQueries.minion_breeds_by_name()
local Text = require("scripts/utilities/ui/text")

local custom_name_by_breed = {}
local custom_name_by_loc_key = {}
local custom_name_set = {}
local name_keys_by_breed = {}
local key_custom_names = {}

local function add_name_keys(keys, value)
	if type(value) == "string" then
		keys[value] = true
	elseif type(value) == "table" then
		for i = 1, #value do
			add_name_keys(keys, value[i])
		end
	end
end

local function gather_name_keys(breed)
	local breed_name = breed.name
	local keys = name_keys_by_breed[breed_name]

	if not keys then
		keys = {}
		add_name_keys(keys, breed.display_name)
		add_name_keys(keys, breed.boss_display_name)
		add_name_keys(keys, BossNameTemplates["havoc_" .. breed_name])
		name_keys_by_breed[breed_name] = keys
	end

	return keys
end

mod.get_custom_name_for_breed = function(breed)
	return breed and custom_name_by_breed[breed.name]
end

mod.refresh_custom_names = function()
	table.clear(custom_name_by_breed)
	table.clear(custom_name_by_loc_key)
	table.clear(custom_name_set)
	table.clear(key_custom_names)

	for breed_name, breed in next, minion_breeds do
		local custom = mod.enemy_custom_name(breed)

		if custom then
			custom_name_by_breed[breed_name] = custom
			custom_name_set[custom] = true

			for key in next, gather_name_keys(breed) do
				local existing = key_custom_names[key]

				if existing == nil then
					key_custom_names[key] = custom
				elseif existing ~= custom then
					key_custom_names[key] = false
				end
			end
		end
	end

	for key, custom in next, key_custom_names do
		if custom then
			custom_name_by_loc_key[key] = custom
		end
	end
end

mod:hook(CLASS.LocalizationManager, "localize", function(func, self, key, no_cache, context)
	if key then
		local custom = custom_name_by_loc_key[key]

		if custom then
			return custom
		end

		if custom_name_set[key] then
			return key
		end
	end

	return func(self, key, no_cache, context)
end)

mod:hook("HudElementCombatFeed", "_get_unit_presentation_name", function(func, self, unit)
	local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = unit_data_extension and unit_data_extension:breed()
	local custom = mod.get_custom_name_for_breed(breed)

	if custom then
		local color = self:_color_by_enemy_tags(breed.tags)

		return Text.apply_color_to_text(custom, color)
	end

	return func(self, unit)
end)

mod:hook("SmartTagExtension", "display_name", function(func, self, tagger_unit)
	local custom = mod.get_custom_name_for_breed(self._breed)

	if custom then
		return custom
	end

	return func(self, tagger_unit)
end)

mod:hook("BossExtension", "display_name", function(func, self)
	local custom = mod.get_custom_name_for_breed(self._breed)

	if custom then
		return custom
	end

	return func(self)
end)
