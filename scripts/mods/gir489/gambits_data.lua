local mod = get_mod("darktide-lua-aimbot")

local priority_options = {
    {
        text = "Off",
        value = 0
    },
    {
        text = "Low",
        value = 1
    },
    {
        text = "Medium",
        value = 2
    },
    {
        text = "High",
        value = 3
    },
    {
        text = "Extreme",
        value = 4
    }
}

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "general_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "enable_fov_check",
                        type = "checkbox",
                        default_value = true
                    },
                    {
                        setting_id = "fov_angle",
                        type = "numeric",
                        default_value = 90,
                        range = {
                            10,
                            360
                        }
                    },
					{
						setting_id = "use_mouse2_fallback",
						type = "checkbox",
						default_value = true
					},
                    {
						setting_id = "use_custom_aim_key",
                        type = "keybind",
                        default_value = {},
                        keybind_global = true,
                        keybind_trigger = "held",
                        keybind_type = "function_call",
                        function_name = "toggle_aim"
                    }
                }
            },
            {
                setting_id = "priority_targets",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "target_hounds",
                        type = "dropdown",
                        options = priority_options,
                        default_value = 4
                    },
                    {
                        setting_id = "target_netgunners",
                        type = "dropdown",
                        options = priority_options,
                        default_value = 4
                    },
                    {
                        setting_id = "target_flamers",
                        type = "dropdown",
                        options = priority_options,
                        default_value = 2
                    },
                    {
                        setting_id = "target_snipers",
                        type = "dropdown",
                        options = priority_options,
                        default_value = 3
                    },
                    {
                        setting_id = "target_bombers",
                        type = "dropdown",
                        options = priority_options,
                        default_value = 2
                    },
                    {
                        setting_id = "target_gunners",
                        type = "dropdown",
                        options = priority_options,
                        default_value = 2
                    },
                    {
                        setting_id = "target_mutants",
                        type = "dropdown",
                        options = priority_options,
                        default_value = 4
                    },
                    {
                        setting_id = "target_ogryns",
                        type = "dropdown",
                        options = priority_options,
                        default_value = 1
                    }
                }
            }
        }
    }
}