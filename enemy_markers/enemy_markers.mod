return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`enemy_markers` encountered an error loading the Darktide Mod Framework.")

		new_mod("enemy_markers", {
			mod_script       = "enemy_markers/scripts/mods/enemy_markers/enemy_markers",
			mod_data         = "enemy_markers/scripts/mods/enemy_markers/enemy_markers_data",
			mod_localization = "enemy_markers/scripts/mods/enemy_markers/enemy_markers_localization",
		})
	end,
	packages = {},
}
