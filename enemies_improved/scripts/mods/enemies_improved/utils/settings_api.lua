local mod = get_mod("enemies_improved")

local BreedQueries = require("scripts/utilities/breed_queries")
local minion_breeds = BreedQueries.minion_breeds_by_name()

local next = next
local type = type
local pcall = pcall
local math_abs = math.abs
local math_floor = math.floor
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match
local string_upper = string.upper
local string_lower = string.lower
local table_sort = table.sort

local schema = mod.setting_schema
local defaults = mod.setting_defaults

local S = {}

S.serial = 0
S.rev = 0

local dirty = false

local function touch()
	dirty = true
	S.rev = S.rev + 1
end

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------

local function clone(value)
	if type(value) == "table" then
		return table.clone(value)
	end

	return value
end

local function equal(a, b)
	if type(a) == "table" and type(b) == "table" then
		for i = 1, 4 do
			if a[i] ~= b[i] then
				return false
			end
		end

		return true
	end

	if type(a) == "number" and type(b) == "number" then
		return math_abs(a - b) < 1e-6
	end

	return a == b
end

local function strip(text)
	if type(text) ~= "string" then
		return text
	end

	return (string_gsub(text, "{#[^}]*}", ""))
end

-- mod:localize returns "<key>" for a missing key
local function loc(key)
	if not key then
		return nil
	end

	local text = mod:localize(key)

	if text == nil or text == "<" .. key .. ">" then
		return nil
	end

	return text
end

local function prettify(id)
	local text = string_gsub(id, "_", " ")

	return (string_gsub(text, "(%a)([%w]*)", function(first, rest)
		return string_upper(first) .. rest
	end))
end

local function round(value, decimals)
	local m = 10 ^ decimals

	return math_floor(value * m + 0.5) / m
end

local function clamp(value, min, max)
	if value < min then
		return min
	elseif value > max then
		return max
	end

	return value
end

local num_specs = {}

local function num_spec(widget)
	local spec = num_specs[widget.setting_id]

	if spec then
		return spec
	end

	local range = widget.range or { 0, 1 }
	local decimals = widget.decimals_number or 0
	local step = widget.step_size_value or 10 ^ -decimals
	local needed = 0

	while needed < 4 and math_abs(step * 10 ^ needed - math_floor(step * 10 ^ needed + 0.5)) > 1e-6 do
		needed = needed + 1
	end

	local default = widget.default_value

	if type(default) == "number" then
		while needed < 4 and math_abs(default * 10 ^ needed - math_floor(default * 10 ^ needed + 0.5)) > 1e-6 do
			needed = needed + 1
		end
	end

	spec = { min = range[1], max = range[2], step = step, decimals = decimals > needed and decimals or needed }
	num_specs[widget.setting_id] = spec

	return spec
end

-----------------------------------------------------------------------
-- Schema / labels
-----------------------------------------------------------------------

function S.schema(id)
	return schema[id]
end

function S.num_spec(id)
	local widget = schema[id]

	return widget and widget.type == "numeric" and num_spec(widget) or nil
end

function S.label(id)
	local widget = schema[id]
	local key = widget and widget.title or id

	return strip(loc(key) or key)
end

function S.tooltip(id)
	local widget = schema[id]
	local text = widget and loc(widget.tooltip)

	return text and strip(text) or nil
end

local options_cache = {}

function S.options(id)
	local cached = options_cache[id]

	if cached then
		return cached
	end

	local widget = schema[id]
	local list = widget and widget.options
	local result = {}

	if list then
		local keep_markup = id == "font_type"

		for i = 1, #list do
			local option = list[i]
			local text = loc(option.text) or option.text

			result[i] = { value = option.value, label = keep_markup and text or strip(text) }
		end
	end

	options_cache[id] = result

	return result
end

-----------------------------------------------------------------------
-- Colours
-----------------------------------------------------------------------
local colour_default_of_other_base

local function colour_base(id)
	local base = string_match(id, "^(.+)_rgb$")

	if base and schema[id] and schema[id].type == "color" then
		return base
	end

	return nil
end

S.colour_base = colour_base

function S.colour_has_alpha(base)
	local widget = schema[base .. "_rgb"]

	return widget and widget.has_alpha or false
end

function S.default_colour(base)
	local widget = schema[base .. "_rgb"]

	if widget then
		return clone(widget.default_value)
	end

	return colour_default_of_other_base(base)
end

local function read_colour(base, default, alpha)
	local r = mod:get(base .. "_R")
	local g = mod:get(base .. "_G")
	local b = mod:get(base .. "_B")

	if r == nil or g == nil or b == nil then
		return clone(default)
	end

	local a = 255

	if alpha then
		a = mod:get(base .. "_A")

		if a == nil then
			a = default and default[1] or 255
		end
	end

	return { a, r, g, b }
end

local function write_colour(base, colour, alpha)
	mod:set(base .. "_R", clamp(round(colour[2], 0), 0, 255))
	mod:set(base .. "_G", clamp(round(colour[3], 0), 0, 255))
	mod:set(base .. "_B", clamp(round(colour[4], 0), 0, 255))

	if alpha then
		mod:set(base .. "_A", clamp(round(colour[1] or 255, 0), 0, 255))
	end

	touch()
end

function S.get_colour(base)
	return read_colour(base, S.default_colour(base), S.colour_has_alpha(base))
end

function S.set_colour(base, colour)
	write_colour(base, colour, S.colour_has_alpha(base))
end

-----------------------------------------------------------------------
-- Scalar settings
-----------------------------------------------------------------------

function S.default(id)
	return clone(defaults[id])
end

function S.get(id)
	local base = colour_base(id)

	if base then
		return S.get_colour(base)
	end

	local value = mod:get(id)

	if value == nil then
		return clone(defaults[id])
	end

	return value
end

local migrate_breed_colours

function S.set(id, value)
	local base = colour_base(id)

	if base then
		return S.set_colour(base, value)
	end

	local widget = schema[id]

	if widget and widget.type == "numeric" and type(value) == "number" then
		local spec = num_spec(widget)

		value = round(clamp(value, spec.min, spec.max), spec.decimals)
	end

	local old_preset = id == "healthbar_colour_preset" and mod.breed_colour_preset_table(mod:get(id)) or nil

	mod:set(id, value)
	touch()

	if old_preset then
		mod.healthbar_colour_preset_changed()
		migrate_breed_colours(old_preset)
	end
end

function S.is_default(id)
	return equal(S.get(id), defaults[id])
end

function S.reset(id)
	S.set(id, S.default(id))
end

-----------------------------------------------------------------------
-- Apply
-----------------------------------------------------------------------

function S.is_dirty()
	return dirty
end

local function step(name, fn, ...)
	local ok, err = pcall(fn, ...)

	if not ok then
		mod:error("[settings_api] %s failed: %s", name, tostring(err))
	end
end

function S.apply()
	if not dirty then
		return false
	end

	dirty = false

	step("build_frame_settings", mod.build_frame_settings)
	step("update_breed_colours", mod.update_breed_colours)
	step("update_breed_icons", mod.update_breed_icons)
	step("apply_enemy_outlines", function()
		mod.apply_enemy_outlines(require("scripts/settings/outline/outline_settings"))
	end)
	step("load_debuff_colours", mod.load_debuff_colours)

	mod.font_type = mod:get("font_type")

	S.serial = S.serial + 1

	return true
end

function S.save()
	local dmf = get_mod("DMF")
	local save = dmf and dmf.save_unsaved_settings_to_file

	if save then
		pcall(save)
	end
end

-----------------------------------------------------------------------
-- Enemies: types / breeds
-----------------------------------------------------------------------

local types_cache
local type_set = {}

function S.types()
	if types_cache then
		return types_cache
	end

	types_cache = {}

	for _, entry in next, mod.breed_types do
		local id = entry.value

		if id ~= "select" then
			types_cache[#types_cache + 1] = { id = id, label = strip(loc(id) or id) }
			type_set[id] = true
		end
	end

	return types_cache
end

function S.type_of(breed_name)
	local breed = minion_breeds[breed_name]

	return breed and mod.find_breed_category_by_tags(breed.tags, breed.name) or nil
end

local breeds_all
local breeds_by_type
local breed_label_of = {}

local function build_breeds()
	breeds_all = {}
	breeds_by_type = {}

	local suffix = loc("ei_mutator_suffix") or "(mutator)"

	for _, option in next, mod.breed_names do
		local name = option.value
		local breed = name ~= "select" and minion_breeds[name]

		if breed then
			local label = strip(loc(breed.display_name) or Localize(breed.display_name) or name)

			if breed.tags and breed.tags.mutator then
				label = label .. " " .. strip(suffix)
			end

			local category = mod.find_breed_category_by_tags(breed.tags, breed.name)
			local entry = { name = name, label = label, type = category, breed = breed }

			breeds_all[#breeds_all + 1] = entry
			breed_label_of[name] = label
		end
	end

	table_sort(breeds_all, function(a, b)
		local la, lb = string_lower(a.label), string_lower(b.label)

		if la ~= lb then
			return la < lb
		end

		return a.name < b.name
	end)

	for i = 1, #breeds_all do
		local entry = breeds_all[i]
		local list = breeds_by_type[entry.type]

		if not list then
			list = {}
			breeds_by_type[entry.type] = list
		end

		list[#list + 1] = entry
	end
end

function S.breeds(type_id)
	if not breeds_all then
		build_breeds()
	end

	if type_id then
		return breeds_by_type[type_id] or {}
	end

	return breeds_all
end

local REPRESENTATIVE = {
	horde = "chaos_poxwalker",
	elite = "renegade_executor",
	special = "renegade_grenadier",
	disabler = "chaos_hound",
	witch = "chaos_daemonhost",
	monster = "chaos_plague_ogryn",
	captain = "renegade_captain",
	sniper = "renegade_sniper",
	far = "renegade_gunner",
	shield = "renegade_vanguard",
	enemy = "cultist_ritualist",
}

function S.representative(type_id)
	local name = REPRESENTATIVE[type_id]

	if name and minion_breeds[name] then
		return name
	end

	local first = S.breeds(type_id)[1]

	return first and first.name or nil
end

local function breed_label(name)
	if not breeds_all then
		build_breeds()
	end

	return breed_label_of[name] or name
end

-----------------------------------------------------------------------
-- Per type / per breed overrides
-----------------------------------------------------------------------
local TRI_TRUE = "true_override"
local TRI_FALSE = "false_override"
local TRI_NONE = "dont_override"

local function tri_from_storage(value)
	if value == TRI_TRUE then
		return true
	elseif value == TRI_FALSE then
		return false
	end

	return nil
end

local function tri_to_storage(value)
	if value == true then
		return TRI_TRUE
	elseif value == false then
		return TRI_FALSE
	end

	return TRI_NONE
end

local function tri_read(spec, value)
	if spec.bool_store then
		return value == true
	end

	return tri_from_storage(value)
end

local function tri_write(spec, value)
	if spec.bool_store then
		return value == true
	end

	return tri_to_storage(value)
end

local function type_default_icon(key)
	return mod.ICON_SETTINGS_DEFAULT[key]
end

local function seed_type(breed_name)
	local category = S.type_of(breed_name) or "enemy"

	return category == "shield" and "elite" or category
end

function migrate_breed_colours(old)
	local new = mod.breed_colour_preset_table(mod:get("healthbar_colour_preset"))
	local list = S.breeds()

	for i = 1, #list do
		local name = list[i].name
		local seed = seed_type(name)
		local o, n = old[seed], new[seed]

		if o and n then
			local base = string_format("healthbar_%s_colour", name)

			if mod:get(base .. "_R") == o[2] and mod:get(base .. "_G") == o[3] and mod:get(base .. "_B") == o[4] then
				write_colour(base, n, false)
			end
		end
	end
end

local TYPE_FIELDS = {
	{
		key = "outline_on",
		kind = "tri",
		id = "outline_%s_enable",
		label = "outline_type_enable",
		tooltip = "outline_type_enable_tooltip",
		group = "outline",
	},
	{
		key = "outline_rgb",
		kind = "rgb",
		id = "outline_%s_colour",
		label = "outline_type_colour",
		tooltip = "outline_type_colour_tooltip",
		toggle = "outline_on",
		group = "outline",
		default = function(key)
			return mod.OUTLINE_COLOURS_DEFAULT[key]
		end,
	},
	{
		key = "bar_on",
		kind = "tri",
		id = "healthbar_%s_enable",
		label = "healthbar_type_enable",
		tooltip = "healthbar_type_enable_tooltip",
		group = "healthbar",
	},
	{
		key = "bar_rgb",
		kind = "rgb",
		id = "healthbar_%s_colour",
		label = "healthbar_type_colour",
		tooltip = "healthbar_type_colour_tooltip",
		group = "healthbar",
		default = function(key)
			return mod.breed_colour_preset_table(mod:get("healthbar_colour_preset"))[key]
		end,
	},
	{
		key = "bar_y_on",
		kind = "bool",
		id = "healthbar_%s_y_offset_enabled",
		label = "healthbar_type_y_offset_enabled",
		tooltip = "healthbar_type_y_offset_enabled_tooltip",
		default = false,
		group = "healthbar",
	},
	{
		key = "bar_y",
		kind = "num",
		id = "healthbar_%s_y_offset",
		label = "healthbar_type_y_offset",
		tooltip = "healthbar_type_y_offset_tooltip",
		default = 0,
		min = -1,
		max = 2,
		step = 0.01,
		decimals = 2,
		toggle = "bar_y_on",
		group = "healthbar",
	},
	{
		key = "icon_on",
		kind = "bool",
		id = "healthbar_icon_%s_enable",
		label = "healthbar_icon_type_enable",
		tooltip = "healthbar_icon_type_enable_tooltip",
		group = "icon",
		default = function(key)
			return type_default_icon(key).enabled
		end,
	},
	{
		key = "icon_scale",
		kind = "num",
		id = "healthbar_icon_%s_scale",
		label = "healthbar_icon_type_scale",
		tooltip = "healthbar_icon_type_scale_tooltip",
		min = 0.6,
		max = 2,
		step = 0.05,
		decimals = 2,
		group = "icon",
		default = function(key)
			return type_default_icon(key).scale
		end,
	},
	{
		key = "icon_glow",
		kind = "int",
		id = "healthbar_icon_%s_glow_intensity",
		label = "healthbar_icon_type_glow_intensity",
		tooltip = "healthbar_icon_type_glow_intensity_tooltip",
		min = 0,
		max = 100,
		step = 1,
		decimals = 0,
		group = "icon",
		default = function(key)
			return type_default_icon(key).glow_intensity
		end,
	},
	{
		key = "icon_rgb",
		kind = "rgb",
		id = "healthbar_icon_%s_colour",
		label = "healthbar_icon_type_colour",
		tooltip = "healthbar_icon_type_colour_tooltip",
		group = "icon",
		default = function(key)
			return mod.ICON_COLOURS_DEFAULT[key]
		end,
	},
	{
		key = "debuff_on",
		kind = "tri",
		id = "debuff_%s_enable",
		label = "debuff_type_enable",
		tooltip = "debuff_type_enable_tooltip",
		group = "debuff",
		alias = { horde = "debuff_horde_global_enable" },
		bool_store = true,
		default = function(key)
			return key ~= "horde"
		end,
	},
	{
		key = "debuff_body",
		kind = "bool",
		id = "debuff_%s_show_on_body_override",
		label = "debuff_type_show_on_body_override",
		tooltip = "debuff_show_on_body_tooltip",
		default = false,
		group = "debuff",
	},
	{
		key = "marker_on",
		kind = "tri",
		id = "marker_%s_enable",
		label = "marker_type_enable",
		tooltip = "marker_type_enable_tooltip",
		group = "marker",
	},
}

local BREED_FIELDS = {
	{
		key = "outline_on",
		kind = "tri",
		id = "outline_%s_enable",
		label = "outline_individual_enable",
		tooltip = "outline_individual_enable_tooltip",
		group = "outline",
	},
	{
		key = "outline_rgb",
		kind = "rgb",
		id = "outline_%s_colour",
		label = "outline_individual_colour",
		tooltip = "outline_individual_colour_tooltip",
		toggle = "outline_on",
		group = "outline",
		default = function(key)
			return mod.OUTLINE_COLOURS_DEFAULT[seed_type(key)]
		end,
	},
	{
		key = "bar_rgb_on",
		kind = "bool",
		id = "healthbar_%s_enable",
		label = "healthbar_individual_enable",
		tooltip = "healthbar_individual_enable_tooltip",
		default = false,
		group = "healthbar",
	},
	{
		key = "bar_rgb",
		kind = "rgb",
		id = "healthbar_%s_colour",
		label = "healthbar_individual_colour",
		tooltip = "healthbar_individual_colour_tooltip",
		toggle = "bar_rgb_on",
		group = "healthbar",
		default = function(key)
			return mod.breed_colour_preset_table(mod:get("healthbar_colour_preset"))[seed_type(key)]
		end,
	},
	{
		key = "bar_force",
		kind = "tri",
		id = "healthbar_%s_force",
		label = "healthbar_individual_force",
		tooltip = "healthbar_individual_force_tooltip",
		group = "healthbar",
	},
	{
		key = "bar_y_on",
		kind = "bool",
		id = "healthbar_%s_y_offset_enabled",
		label = "healthbar_individual_y_offset_enabled",
		tooltip = "healthbar_individual_y_offset_enabled_tooltip",
		default = false,
		group = "healthbar",
	},
	{
		key = "bar_y",
		kind = "num",
		id = "healthbar_%s_y_offset",
		label = "healthbar_individual_y_offset",
		tooltip = "healthbar_individual_y_offset_tooltip",
		default = 0,
		min = -1,
		max = 2,
		step = 0.01,
		decimals = 2,
		toggle = "bar_y_on",
		group = "healthbar",
	},
	{
		key = "marker_on",
		kind = "tri",
		id = "markers_%s_toggle",
		label = "markers_individual_toggle",
		tooltip = "markers_individual_toggle_tooltip",
		group = "marker",
	},
	{
		key = "debuff_on",
		kind = "tri",
		id = "debuff_%s_enable",
		label = "debuff_individual_enable",
		tooltip = "debuff_individual_enable_tooltip",
		group = "debuff",
	},
	{
		key = "debuff_body",
		kind = "bool",
		id = "debuff_%s_show_on_body_override",
		label = "debuff_individual_show_on_body_override",
		tooltip = "debuff_show_on_body_tooltip",
		default = false,
		group = "debuff",
	},
	{
		key = "dist_on",
		kind = "bool",
		id = "distance_%s_enable",
		label = "distance_individual_enable",
		tooltip = "distance_individual_enable_tooltip",
		default = false,
		group = "distance",
	},
	{
		key = "dist",
		kind = "int",
		id = "distance_%s_value",
		label = "distance_individual_value",
		tooltip = "distance_individual_value_tooltip",
		default = 30,
		min = 5,
		max = 100,
		step = 5,
		decimals = 0,
		toggle = "dist_on",
		group = "distance",
	},
	{
		key = "odist_on",
		kind = "bool",
		id = "outline_distance_%s_enable",
		label = "outline_distance_individual_enable",
		tooltip = "outline_distance_individual_enable_tooltip",
		default = false,
		group = "distance",
	},
	{
		key = "odist",
		kind = "int",
		id = "outline_distance_%s_value",
		label = "outline_distance_individual_value",
		tooltip = "outline_distance_individual_value_tooltip",
		default = 30,
		min = 5,
		max = 100,
		step = 5,
		decimals = 0,
		toggle = "odist_on",
		group = "distance",
	},
}

local FIELDS = { type = TYPE_FIELDS, breed = BREED_FIELDS }
local SPEC = { type = {}, breed = {} }

for scope, list in next, FIELDS do
	for i = 1, #list do
		SPEC[scope][list[i].key] = list[i]
	end
end

local NO_ICON = { horde = true, enemy = true }

local function ov_id(spec, key)
	return spec.alias and spec.alias[key] or string_format(spec.id, key)
end

local function localized(spec)
	if not spec.label_text then
		spec.label_text = strip(loc(spec.label) or spec.label)
		spec.tooltip_text = spec.tooltip and strip(loc(spec.tooltip)) or nil
	end

	return spec
end

local fields_cache = {}

function S.ov_fields(scope, key)
	local cache_key = scope .. "|" .. (scope == "type" and NO_ICON[key] and "noicon" or "all")
	local cached = fields_cache[cache_key]

	if cached then
		return cached
	end

	cached = {}

	local list = FIELDS[scope]

	for i = 1, #list do
		local spec = list[i]

		if not (scope == "type" and NO_ICON[key] and spec.group == "icon") then
			cached[#cached + 1] = localized(spec)
		end
	end

	fields_cache[cache_key] = cached

	return cached
end

local function spec_of(scope, field)
	return SPEC[scope][field]
end

function S.ov_default(scope, key, field)
	local spec = spec_of(scope, field)
	local default = spec.default

	if type(default) == "function" then
		default = default(key)
	end

	return clone(default)
end

function S.ov_get(scope, key, field)
	local spec = spec_of(scope, field)
	local id = ov_id(spec, key)

	if spec.kind == "rgb" then
		return read_colour(id, S.ov_default(scope, key, field), false)
	end

	local value = mod:get(id)

	if spec.kind == "tri" then
		return tri_read(spec, value)
	end

	if value == nil then
		return S.ov_default(scope, key, field)
	end

	return value
end

function S.ov_set(scope, key, field, value)
	local spec = spec_of(scope, field)
	local id = ov_id(spec, key)
	local kind = spec.kind

	if kind == "rgb" then
		return write_colour(id, value, false)
	end

	if kind == "bool" then
		value = value and true or false
	elseif kind == "tri" then
		value = tri_write(spec, value)
	elseif kind == "num" or kind == "int" then
		value = round(clamp(value, spec.min, spec.max), kind == "int" and 0 or spec.decimals)
	end

	mod:set(id, value)
	touch()
end

function S.ov_is_default(scope, key, field)
	local spec = spec_of(scope, field)

	if scope == "breed" and spec.kind == "rgb" and spec.toggle and S.ov_get(scope, key, spec.toggle) ~= true then
		return true
	end

	return equal(S.ov_get(scope, key, field), S.ov_default(scope, key, field))
end

function S.ov_reset(scope, key)
	local list = FIELDS[scope]

	for i = 1, #list do
		local spec = list[i]
		local field = spec.key
		local id = ov_id(spec, key)

		if spec.kind == "rgb" then
			write_colour(id, S.ov_default(scope, key, field), false)
		elseif spec.kind == "tri" then
			mod:set(id, tri_write(spec, S.ov_default(scope, key, field)))
		elseif spec.nil_default and not (spec.alias and spec.alias[key]) then
			mod:set(id, nil)
		else
			mod:set(id, S.ov_default(scope, key, field))
		end
	end

	mod.init_healthbar_defaults()
	touch()
end

local modified_cache = {}
local modified_rev = -1

function S.ov_is_modified(scope, key)
	if modified_rev ~= S.rev then
		modified_cache = {}
		modified_rev = S.rev
	end

	local cache_key = scope .. "|" .. key
	local result = modified_cache[cache_key]

	if result == nil then
		result = false

		local fields = S.ov_fields(scope, key)

		for i = 1, #fields do
			if not S.ov_is_default(scope, key, fields[i].key) then
				result = true

				break
			end
		end

		modified_cache[cache_key] = result
	end

	return result
end

function colour_default_of_other_base(base)
	-- debuff_group_<group>_colour
	local group = string_match(base, "^debuff_group_(.+)_colour$")

	if group and mod.debuff_style_default_colours[group] then
		return clone(mod.debuff_style_default_colours[group])
	end

	if not next(type_set) then
		S.types()
	end

	for _, scope in next, { "type", "breed" } do
		local list = FIELDS[scope]

		for i = 1, #list do
			local spec = list[i]

			if spec.kind == "rgb" then
				local key = string_match(base, "^" .. string_gsub(spec.id, "%%s", "(.+)") .. "$")

				if key and ((scope == "type" and type_set[key]) or (scope == "breed" and minion_breeds[key])) then
					return S.ov_default(scope, key, spec.key)
				end
			end
		end
	end

	return { 255, 255, 255, 255 }
end

local function raw(scope, key, field)
	local spec = spec_of(scope, field)
	local id = ov_id(spec, key)

	if spec.kind == "tri" then
		return tri_read(spec, mod:get(id))
	end

	return mod:get(id)
end

function S.resolve(breed_name)
	local breed_type = S.type_of(breed_name) or "enemy"
	local is_horde = breed_type == "horde"
	local result = { breed = breed_name, type = breed_type, label = breed_label(breed_name) }

	local outline = { on = false, source = "off" }
	local breed_outline = S.ov_get("breed", breed_name, "outline_on")
	local type_outline = S.ov_get("type", breed_type, "outline_on")

	if S.get("outlines_enable") then
		if breed_outline ~= nil then
			outline = {
				on = breed_outline,
				rgb = breed_outline and S.ov_get("breed", breed_name, "outline_rgb") or nil,
				source = breed_outline and "breed" or "off",
			}
		elseif type_outline then
			outline = { on = true, rgb = S.ov_get("type", breed_type, "outline_rgb"), source = "type" }
		end
	end

	result.outline = outline

	local force_state = S.ov_get("breed", breed_name, "bar_force")
	local type_state = S.ov_get("type", breed_type, "bar_on")
	local effective = force_state ~= nil and force_state or type_state
	local forced_on = effective == true -- a real "force on" also beats the horde gate
	local horde_blocked = effective ~= true
		and is_horde
		and not (S.get("hb_horde_enable") or S.get("hb_horde_clusters_enable"))

	local y
	local breed_y = S.ov_get("breed", breed_name, "bar_y_on") and raw("breed", breed_name, "bar_y")
	local type_y = S.ov_get("type", breed_type, "bar_y_on") and raw("type", breed_type, "bar_y")

	if breed_y ~= nil and breed_y ~= false then
		y = -breed_y
	elseif type_y ~= nil and type_y ~= false then
		y = -type_y
	else
		y = -(S.get("hb_y_offset") or 0)
	end

	if y == 0 then
		y = 0 -- no negative zero
	end

	result.bar = {
		visible = S.get("healthbar_enable") and effective ~= false and not horde_blocked or false,
		rgb = S.ov_get("breed", breed_name, "bar_rgb_on") and S.ov_get("breed", breed_name, "bar_rgb")
			or S.ov_get("type", breed_type, "bar_rgb"),
		y = y,
		forced = forced_on,
		horde_blocked = horde_blocked or false,
	}

	local icon_on = not NO_ICON[breed_type]
		and S.get("healthbar_type_icon_enable")
		and S.ov_get("type", breed_type, "icon_on")

	result.icon = {
		on = icon_on and true or false,
		scale = S.ov_get("type", breed_type, "icon_scale")
			* (S.get("healthbar_type_icon_scale") or 1)
			* (mod.ICON_SETTINGS_DEFAULT[breed_type] and mod.ICON_SETTINGS_DEFAULT[breed_type].icon_scale or 1),
		glow = S.ov_get("type", breed_type, "icon_glow"),
		rgb = S.ov_get("type", breed_type, "icon_rgb"),
	}

	local individual = S.ov_get("breed", breed_name, "debuff_on")
	local type_debuff = S.ov_get("type", breed_type, "debuff_on")
	local on

	if is_horde and not S.get("debuff_horde_global_enable") then
		on = false
	elseif individual == true or type_debuff == true then
		on = true
	elseif individual == false or type_debuff == false then
		on = false
	else
		on = S.get("debuff_enable") and true or false
	end

	result.debuffs = {
		on = on and true or false,
		on_body = (S.get("debuff_show_on_body") or S.ov_get("breed", breed_name, "debuff_body") or S.ov_get(
			"type",
			breed_type,
			"debuff_body"
		)) and true or false,
	}

	local breed_marker = S.ov_get("breed", breed_name, "marker_on")
	local marker_override = breed_marker ~= nil and breed_marker or S.ov_get("type", breed_type, "marker_on")
	local filter = is_horde and S.get("markers_horde_enable") or (not is_horde and S.get("markers_non_horde_enable"))

	result.marker = {
		on = S.get("markers_enable") and marker_override ~= false and (filter or marker_override == true) and true
			or false,
		forced = marker_override == true or false,
	}

	result.draw_distance = S.ov_get("breed", breed_name, "dist_on") and S.ov_get("breed", breed_name, "dist")
		or S.get("draw_distance")
	result.outline_distance = S.ov_get("breed", breed_name, "odist_on") and S.ov_get("breed", breed_name, "odist")
		or nil

	return result
end

-----------------------------------------------------------------------
-- Debuffs
-----------------------------------------------------------------------

local debuff_groups_cache

function S.debuff_label(name)
	return strip(loc(name) or prettify(name))
end

function S.debuff_groups()
	if debuff_groups_cache then
		return debuff_groups_cache
	end

	local by_group = {}

	for name, debuff in next, mod.default_debuffs do
		local list = by_group[debuff.group]

		if not list then
			list = {}
			by_group[debuff.group] = list
		end

		list[#list + 1] = name
	end

	debuff_groups_cache = {}

	for group, names in next, by_group do
		local labels = {}

		for i = 1, #names do
			labels[names[i]] = S.debuff_label(names[i])
		end

		table_sort(names, function(a, b)
			if labels[a] ~= labels[b] then
				return labels[a] < labels[b]
			end

			return a < b
		end)

		local style = mod.debuff_styles[group]

		debuff_groups_cache[#debuff_groups_cache + 1] = {
			group = group,
			label = strip(loc("debuff_group_" .. group) or prettify(group)),
			icon = style and style.icon,
			names = names,
		}
	end

	table_sort(debuff_groups_cache, function(a, b)
		if a.label ~= b.label then
			return a.label < b.label
		end

		return a.group < b.group
	end)

	return debuff_groups_cache
end

function S.debuff_enabled(name)
	return mod:get(name .. "_toggle_state") ~= false
end

function S.set_debuff_enabled(name, enabled)
	enabled = enabled and true or false

	mod:set(name .. "_toggle_state", enabled)
	mod.update_debuff_toggles(name, enabled)
	touch()
end

function S.default_debuff_group_colour(group)
	local default = mod.debuff_style_default_colours[group]

	return clone(default) or { 255, 255, 255, 255 }
end

function S.debuff_group_colour(group)
	return read_colour("debuff_group_" .. group .. "_colour", S.default_debuff_group_colour(group), false)
end

function S.set_debuff_group_colour(group, colour)
	write_colour("debuff_group_" .. group .. "_colour", colour, false)

	local style = mod.debuff_styles[group]

	if style and style.colour then
		style.colour[1] = 255
		style.colour[2] = mod:get("debuff_group_" .. group .. "_colour_R")
		style.colour[3] = mod:get("debuff_group_" .. group .. "_colour_G")
		style.colour[4] = mod:get("debuff_group_" .. group .. "_colour_B")
	end
end

return S
