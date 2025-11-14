return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`gir489` encountered an error loading the Darktide Mod Framework.")

		new_mod("gir489", {
			mod_script       = "gir489/scripts/mods/gir489/gambits",
			mod_data         = "gir489/scripts/mods/gir489/gambits_data",
			mod_localization = "gir489/scripts/mods/gir489/gambits_localization",
		})
	end,
	packages = {},
}
