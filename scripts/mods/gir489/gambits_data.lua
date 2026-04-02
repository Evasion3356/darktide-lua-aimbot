local mod = get_mod("darktide-lua-gambits")

local priority_options = {
    { text = "Off", value = 0  },
    { text = "1",   value = 1  },
    { text = "2",   value = 2  },
    { text = "3",   value = 3  },
    { text = "4",   value = 4  },
    { text = "5",   value = 5  },
    { text = "6",   value = 6  },
    { text = "7",   value = 7  },
    { text = "8",   value = 8  },
    { text = "9",   value = 9  },
    { text = "10",  value = 10 },
    { text = "11",  value = 11 },
    { text = "12",  value = 12 },
    { text = "13",  value = 13 },
    { text = "14",  value = 14 },
    { text = "15",  value = 15 },
}

local profile_options = {
    { text = "AutoClass",         value = "auto"    },
    { text = "CustomClass",       value = "custom"  },
    { text = "VeteranClass",      value = "veteran" },
    { text = "ZealotClass",       value = "zealot"  },
    { text = "PsykerClass",       value = "psyker"  },
    { text = "OgrynClass",        value = "ogryn"   },
    { text = "ArbitratorClass",   value = "adamant" },
    { text = "BrokerClass",       value = "broker"  },
}

local function make_target_widgets(prefix, d)
    return {
        { setting_id = prefix.."target_bosses",         type = "dropdown", options = priority_options, default_value = d.bosses         },
        { setting_id = prefix.."target_berzerkers",     type = "dropdown", options = priority_options, default_value = d.berzerkers     },
        { setting_id = prefix.."target_hounds",         type = "dropdown", options = priority_options, default_value = d.hounds         },
        { setting_id = prefix.."target_netgunners",     type = "dropdown", options = priority_options, default_value = d.netgunners     },
        { setting_id = prefix.."target_flamers",        type = "dropdown", options = priority_options, default_value = d.flamers        },
        { setting_id = prefix.."target_snipers",        type = "dropdown", options = priority_options, default_value = d.snipers        },
        { setting_id = prefix.."target_bombers",        type = "dropdown", options = priority_options, default_value = d.bombers        },
        { setting_id = prefix.."target_poxwalkers",     type = "dropdown", options = priority_options, default_value = d.poxwalkers     },
        { setting_id = prefix.."target_gunners",        type = "dropdown", options = priority_options, default_value = d.gunners        },
        { setting_id = prefix.."target_mutants",        type = "dropdown", options = priority_options, default_value = d.mutants        },
        { setting_id = prefix.."target_crushers",       type = "dropdown", options = priority_options, default_value = d.crushers       },
        { setting_id = prefix.."target_bulwarks",       type = "dropdown", options = priority_options, default_value = d.bulwarks       },
        { setting_id = prefix.."target_reapers",        type = "dropdown", options = priority_options, default_value = d.reapers        },
        { setting_id = prefix.."target_mauler",         type = "dropdown", options = priority_options, default_value = d.mauler         },
        { setting_id = prefix.."target_melee_regular",  type = "dropdown", options = priority_options, default_value = d.melee_regular  },
        { setting_id = prefix.."target_ranged_regular", type = "dropdown", options = priority_options, default_value = d.ranged_regular },
    }
end

-- Per-class default priorities.
-- Veteran: ranged specialist — punishes snipers/trappers/hounds hardest.
-- Zealot:  melee rusher — prioritises threats that pin or charge.
-- Psyker:  glass cannon — avoids being grabbed; snipers/trappers lethal.
-- Ogryn:   slow tank — specials exploit the lack of mobility.
local CLASS_DEFAULTS = {
    veteran = { bosses=2, berzerkers=8, hounds=12, netgunners=13, flamers=7, snipers=15, bombers=11, poxwalkers=14, gunners=9, mutants=6, crushers=2, bulwarks=5, reapers=10, mauler=4, melee_regular=0, ranged_regular=0 },
    zealot  = { bosses=2, berzerkers=8, hounds=12, netgunners=13, flamers=7, snipers=15, bombers=11, poxwalkers=14, gunners=9, mutants=6, crushers=2, bulwarks=5, reapers=10, mauler=4, melee_regular=0, ranged_regular=0 },
    psyker  = { bosses=2, berzerkers=8, hounds=12, netgunners=13, flamers=7, snipers=15, bombers=11, poxwalkers=14, gunners=9, mutants=6, crushers=2, bulwarks=5, reapers=10, mauler=4, melee_regular=0, ranged_regular=0 },
    ogryn   = { bosses=4, berzerkers=8, hounds=12, netgunners=13, flamers=7, snipers=15, bombers=11, poxwalkers=14, gunners=9, mutants=6, crushers=0, bulwarks=5, reapers=10, mauler=0, melee_regular=0, ranged_regular=3 },
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
                        range = { 10, 360 }
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
                    },
                    {
                        setting_id = "disable_when_teammates_are_dead",
                        type = "checkbox",
                        default_value = true,
                        localize = true
                    },
                    {
                        setting_id = "require_main_weapon",
                        type = "checkbox",
                        default_value = true,
                        localize = true
                    },
                    {
                        setting_id = "enable_spread_compensation",
                        type = "checkbox",
                        default_value = true
                    },
                    {
                        setting_id = "priority_profile",
                        type = "dropdown",
                        options = profile_options,
                        default_value = "auto"
                    },
                }
            },
            {
                setting_id = "triggerbot_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "enable_triggerbot",
                        type = "checkbox",
                        default_value = true
                    },
                    {
                        setting_id = "triggerbot_use_raycast",
                        type = "checkbox",
                        default_value = true
                    },
                    {
                        setting_id = "triggerbot_weakspot_only",
                        type = "checkbox",
                        default_value = true
                    },
                    {
                        setting_id = "triggerbot_respect_priority",
                        type = "checkbox",
                        default_value = false
                    },
                    {
                        setting_id = "wait_for_crits",
                        type = "checkbox",
                        default_value = true
                    },
                    {
                        setting_id = "triggerbot_keybind",
                        type = "keybind",
                        default_value = {"extra_2"},
                        keybind_global = true,
                        keybind_trigger = "held",
                        keybind_type = "function_call",
                        function_name = "toggle_triggerbot"
                    }
                }
            },
            {
                setting_id = "auto_guard_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "enable_auto_guard",
                        type = "checkbox",
                        default_value = false
                    },
                    {
                        setting_id = "auto_guard_range",
                        type = "numeric",
                        default_value = 4,
                        range = { 1, 10 }
                    },
                    {
                        setting_id = "auto_guard_heavy_only",
                        type = "checkbox",
                        default_value = true
                    },
                }
            },
            {
                -- "Custom" profile — the original per-enemy dropdowns.
                -- Only active when priority_profile == "custom" (or as
                -- the auto fallback when no archetype can be detected).
                setting_id = "priority_targets",
                type = "group",
                sub_widgets = make_target_widgets("", CLASS_DEFAULTS.veteran)
            },
            {
                setting_id = "veteran_profile_targets",
                type = "group",
                sub_widgets = make_target_widgets("veteran_", CLASS_DEFAULTS.veteran)
            },
            {
                setting_id = "zealot_profile_targets",
                type = "group",
                sub_widgets = make_target_widgets("zealot_", CLASS_DEFAULTS.zealot)
            },
            {
                setting_id = "psyker_profile_targets",
                type = "group",
                sub_widgets = make_target_widgets("psyker_", CLASS_DEFAULTS.psyker)
            },
            {
                setting_id = "ogryn_profile_targets",
                type = "group",
                sub_widgets = make_target_widgets("ogryn_", CLASS_DEFAULTS.ogryn)
            },
            {
                setting_id = "adamant_profile_targets",
                type = "group",
                sub_widgets = make_target_widgets("adamant_", CLASS_DEFAULTS.veteran)
            },
            {
                setting_id = "broker_profile_targets",
                type = "group",
                sub_widgets = make_target_widgets("broker_", CLASS_DEFAULTS.veteran)
            },
        }
    }
}