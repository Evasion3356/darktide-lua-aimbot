local mod = get_mod("darktide-lua-aimbot")

local loc = {
    mod_name = {
        en = "Priority Target Auto-Aim"
    },
    mod_description = {
        en = "Automatically aims at priority special enemies when right-clicking or using a custom keybind."
    },

    -- Priority Levels
    Off = {
        en = "Off"
    },
    Low = {
        en = "Low"
    },
    Medium = {
        en = "Medium"
    },
    High = {
        en = "High"
    },
    Extreme = {
        en = "Extreme"
    },
    
    -- General Settings
    general_settings = {
        en = "General Settings"
    },
    enable_fov_check = {
        en = "Enable Field of View Check"
    },
    enable_fov_check_description = {
        en = "Only target enemies within your field of view cone"
    },
    fov_angle = {
        en = "Field of View Angle"
    },
    fov_angle_description = {
        en = "Angle in degrees for field of view targeting (10-360)"
    },
    use_custom_aim_key = {
        en = "Use Custom Aim Key"
    },
    use_custom_aim_key_description = {
        en = "Enable to use a custom keybind instead of right mouse button"
    },
    aim_key = {
        en = "Custom Aim Key"
    },
    aim_key_description = {
        en = "Key to activate auto-aim (only if custom key is enabled)"
    },
	use_mouse2_fallback = {
		en = "Use Mouse2 (Right Click)."
	},
	use_mouse2_fallback_description = {
		en = "If enabled, auto-aim will trigger when holding Mouse2 (right click). If disabled, uses custom keybind."
	},
    
    -- Priority Targets
    priority_targets = {
        en = "Priority Targets"
    },
    target_hounds = {
        en = "Target Pox Hounds"
    },
    target_hounds_description = {
        en = "Automatically aim at Pox Hounds (chaos_hound)"
    },
    target_netgunners = {
        en = "Target Trappers"
    },
    target_netgunners_description = {
        en = "Automatically aim at Trappers with net guns (renegade_netgunner)"
    },
    target_flamers = {
        en = "Target Flamers"
    },
    target_flamers_description = {
        en = "Automatically aim at Flamer enemies (cultist_flamer, renegade_flamer)"
    },
    target_snipers = {
        en = "Target Snipers"
    },
    target_snipers_description = {
        en = "Automatically aim at Sniper enemies (renegade_sniper)"
    },
    target_bombers = {
        en = "Target Bombers"
    },
    target_bombers_description = {
        en = "Automatically aim at Bombers and Grenadiers (poxwalker_bomber, grenadiers)"
    },
    target_gunners = {
        en = "Target Gunners"
    },
    target_gunners_description = {
        en = "Automatically aim at Gunner enemies (cultist_gunner, renegade_gunner, plasma_gunner)"
    },
    target_mutants = {
        en = "Target Mutants"
    },
    target_mutants_description = {
        en = "Automatically aim at Mutants and Shocktroops (cultist_mutant, shocktrooper)"
    },
    target_ogryns = {
        en = "Target Ogryns"
    },
    target_ogryns_description = {
        en = "Automatically aim at Ogryn elites (bulwark, executor, gunner)"
    }
}

return loc