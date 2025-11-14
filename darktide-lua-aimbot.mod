return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`darktide-lua-aimbot` encountered an error loading the Darktide Mod Framework.")

		new_mod("darktide-lua-aimbot", {
			mod_script       = "darktide-lua-aimbot/scripts/mods/gir489/gambits",
			mod_data         = "darktide-lua-aimbot/scripts/mods/gir489/gambits_data",
			mod_localization = "darktide-lua-aimbot/scripts/mods/gir489/gambits_localization",
		})
	end,
	packages = {},
}
