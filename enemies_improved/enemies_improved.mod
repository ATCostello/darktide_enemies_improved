return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`enemies_improved` encountered an error loading the Darktide Mod Framework.")

		new_mod("enemies_improved", {
			mod_script       = "enemies_improved/scripts/mods/enemies_improved/enemies_improved",
			mod_data         = "enemies_improved/scripts/mods/enemies_improved/enemies_improved_data",
			mod_localization = "enemies_improved/scripts/mods/enemies_improved/enemies_improved_localization",
		})
	end,
	packages = {},
}
