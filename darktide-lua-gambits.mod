return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`darktide-lua-gambits` encountered an error loading the Darktide Mod Framework.")

		new_mod("darktide-lua-gambits", {
			mod_script       = "darktide-lua-gambits/scripts/mods/gir489/gambits",
			mod_data         = "darktide-lua-gambits/scripts/mods/gir489/gambits_data",
			mod_localization = "darktide-lua-gambits/scripts/mods/gir489/gambits_localization",
		})
	end,
	packages = {},
}
