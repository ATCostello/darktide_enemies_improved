-- Enemies Improved editor: view registration and open / close (the view is ei_editor_view.lua).
-- Same shape as the Better Buff Management editor module.
local mod = get_mod("enemies_improved")

local Editor = {}

local VIEW_PATH = "enemies_improved/scripts/mods/enemies_improved/editor/ei_editor_view"
local VIEW_NAME = "enemies_improved_editor"

Editor.VIEW_NAME = VIEW_NAME

Editor.register = function()
	local ok, err = pcall(function()
		mod:add_require_path(VIEW_PATH)
		mod:add_require_path(VIEW_PATH .. "_definitions")
		mod:register_view({
			view_name = VIEW_NAME,
			view_settings = {
				init_view_function = function()
					return true
				end,
				class = "EnemiesImprovedEditorView",
				path = VIEW_PATH,
				package = "packages/ui/views/options_view/options_view",
				display_name = "ei_editor_title",
				disable_game_world = false,
				game_world_blur = 1.1,
				load_always = true,
				load_in_hub = true,
				state_bound = true,
				wwise_states = { options = "ingame_menu" },
				enter_sound_events = { "wwise/events/ui/play_ui_enter_short" },
				exit_sound_events = { "wwise/events/ui/play_ui_back_short" },
			},
			view_transitions = {},
			view_options = { close_all = false, close_previous = false },
		})
		mod:io_dofile(VIEW_PATH)
	end)
	if not ok then
		mod:error("editor view registration failed: %s", tostring(err))
	end
end

Editor.is_open = function()
	local ui = Managers and Managers.ui
	return ui ~= nil and ui:view_active(VIEW_NAME)
end

-- True while one of the open editor's text fields has focus. DMF fires non-global keybinds even
-- then (keybindings.lua is_dmf_input_service_active() is a stub returning true), so the toggle
-- keybind checks this to not close the view on a typed key.
Editor.is_writing = function()
	local view = mod._ei_view
	return view ~= nil and view._writing_input ~= nil and view:_writing_input() ~= nil
end

Editor.toggle = function()
	local ui = Managers and Managers.ui
	if not ui then
		return
	end
	if ui:view_active(VIEW_NAME) then
		pcall(ui.close_view, ui, VIEW_NAME)
		return
	end
	local ok, err = pcall(function()
		ui:open_view(VIEW_NAME, nil, nil, nil, nil, { mod = mod })
	end)
	if not ok then
		mod:error("editor open failed: %s", tostring(err))
	end
end

Editor.close_all = function()
	local ui = Managers and Managers.ui
	if not ui then
		return
	end
	pcall(function()
		if ui:view_active(VIEW_NAME) then
			ui:close_view(VIEW_NAME)
		end
	end)
end

return Editor
