local mod = get_mod("darktide-lua-gambits")

local priority_options = {
    { text = "Off",      value = 0 },
    { text = "Lowest",   value = 1 },
    { text = "Lower",    value = 2 },
    { text = "Low",      value = 3 },
    { text = "Medium",   value = 4 },
    { text = "Elevated", value = 5 },
    { text = "High",     value = 6 },
    { text = "Extreme",  value = 7 },
    { text = "Ultra",    value = 8 },
    { text = "Critical", value = 9 },
}

local profile_options = {
    { text = "AutoClass",    value = "auto"    },
    { text = "CustomClass",  value = "custom"  },
    { text = "VeteranClass", value = "veteran" },
    { text = "ZealotClass",  value = "zealot"  },
    { text = "PsykerClass",  value = "psyker"  },
    { text = "OgrynClass",   value = "ogryn"   },
    { text = "ArbitratorClass",   value = "adamant"   },
    { text = "BrokerClass",   value = "broker"   },
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
    veteran = { bosses=3, berzerkers=4, hounds=9, netgunners=9, flamers=5, snipers=9, bombers=7, poxwalkers=9, gunners=6, mutants=3, crushers=2, bulwarks=2, reapers=5, mauler=3, melee_regular=0, ranged_regular=1 },
    zealot  = { bosses=4, berzerkers=6, hounds=9, netgunners=9, flamers=6, snipers=8, bombers=6, poxwalkers=8, gunners=4, mutants=6, crushers=4, bulwarks=3, reapers=4, mauler=5, melee_regular=1, ranged_regular=1 },
    psyker  = { bosses=3, berzerkers=6, hounds=9, netgunners=9, flamers=7, snipers=9, bombers=6, poxwalkers=9, gunners=5, mutants=6, crushers=3, bulwarks=2, reapers=5, mauler=3, melee_regular=0, ranged_regular=2 },
    ogryn   = { bosses=5, berzerkers=5, hounds=9, netgunners=9, flamers=7, snipers=8, bombers=7, poxwalkers=9, gunners=6, mutants=5, crushers=5, bulwarks=4, reapers=6, mauler=5, melee_regular=1, ranged_regular=1 },
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
                -- "Custom" profile — the original per-enemy dropdowns.
                -- Only active when priority_profile == "custom" (or as
                -- the auto fallback when no archetype can be detected).
                setting_id = "priority_targets",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "priority_profile",
                        type = "dropdown",
                        options = profile_options,
                        default_value = "auto"
                    },
                    { setting_id = "target_bosses",         type = "dropdown", options = priority_options, default_value = 2 },
                    { setting_id = "target_berzerkers",     type = "dropdown", options = priority_options, default_value = 4 },
                    { setting_id = "target_hounds",         type = "dropdown", options = priority_options, default_value = 7 },
                    { setting_id = "target_netgunners",     type = "dropdown", options = priority_options, default_value = 7 },
                    { setting_id = "target_flamers",        type = "dropdown", options = priority_options, default_value = 4 },
                    { setting_id = "target_snipers",        type = "dropdown", options = priority_options, default_value = 8 },
                    { setting_id = "target_bombers",        type = "dropdown", options = priority_options, default_value = 6 },
                    { setting_id = "target_poxwalkers",     type = "dropdown", options = priority_options, default_value = 9 },
                    { setting_id = "target_gunners",        type = "dropdown", options = priority_options, default_value = 5 },
                    { setting_id = "target_mutants",        type = "dropdown", options = priority_options, default_value = 3 },
                    { setting_id = "target_crushers",       type = "dropdown", options = priority_options, default_value = 3 },
                    { setting_id = "target_bulwarks",       type = "dropdown", options = priority_options, default_value = 3 },
                    { setting_id = "target_reapers",        type = "dropdown", options = priority_options, default_value = 5 },
                    { setting_id = "target_mauler",         type = "dropdown", options = priority_options, default_value = 3 },
                    { setting_id = "target_melee_regular",  type = "dropdown", options = priority_options, default_value = 0 },
                    { setting_id = "target_ranged_regular", type = "dropdown", options = priority_options, default_value = 0 },
                }
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
        }
    }
}