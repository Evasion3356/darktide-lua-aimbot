local mod = get_mod("darktide-lua-gambits")

local loc = {
    mod_name = {
        en = "Priority Target Auto-Aim",
        ru = "Автонаведение на приоритетные цели",
        de = "Automatisches Zielen auf Prioritätsziele"
    },
    mod_description = {
        en = "Automatically aims at priority special enemies when right-clicking or using a custom keybind. Includes optional triggerbot.",
        ru = "Автоматически наводится на приоритетных особых врагов при нажатии ПКМ или пользовательской клавиши. Включает опциональный триггербот.",
        de = "Zielt automatisch auf priorisierte Spezialgegner beim Rechtsklick oder mit einer benutzerdefinierten Taste. Enthält optionalen Triggerbot."
    },

    -- Priority Levels (0 = Off, 1–15 = numeric priority; higher wins)
    Off   = { en = "Off", ru = "Выкл", de = "Aus" },
    ["1"]  = { en = "1"  },
    ["2"]  = { en = "2"  },
    ["3"]  = { en = "3"  },
    ["4"]  = { en = "4"  },
    ["5"]  = { en = "5"  },
    ["6"]  = { en = "6"  },
    ["7"]  = { en = "7"  },
    ["8"]  = { en = "8"  },
    ["9"]  = { en = "9"  },
    ["10"] = { en = "10" },
    ["11"] = { en = "11" },
    ["12"] = { en = "12" },
    ["13"] = { en = "13" },
    ["14"] = { en = "14" },
    ["15"] = { en = "15" },
    
    -- General Settings
    general_settings = {
        en = "General Settings",
        ru = "Общие настройки",
        de = "Allgemeine Einstellungen"
    },
    enable_fov_check = {
        en = "Enable Field of View Check",
        ru = "Включить проверку поля зрения",
        de = "Sichtfeldprüfung aktivieren"
    },
    enable_fov_check_description = {
        en = "Only target enemies within your field of view cone",
        ru = "Наводиться только на врагов в пределах вашего поля зрения",
        de = "Nur Gegner im Sichtfeldkegel anvisieren"
    },
    fov_angle = {
        en = "Field of View Angle",
        ru = "Угол поля зрения",
        de = "Sichtfeldwinkel"
    },
    fov_angle_description = {
        en = "Angle in degrees for field of view targeting (10-360)",
        ru = "Угол в градусах для наведения по полю зрения (10–360)",
        de = "Winkel in Grad für das Sichtfeld-Zielen (10–360)"
    },
    use_custom_aim_key = {
        en = "Use Custom Aim Key",
        ru = "Использовать пользовательскую клавишу прицеливания",
        de = "Benutzerdefinierte Zieltaste verwenden"
    },
    use_custom_aim_key_description = {
        en = "Enable to use a custom keybind instead of right mouse button",
        ru = "Включите, чтобы использовать пользовательскую клавишу вместо правой кнопки мыши",
        de = "Aktivieren, um eine benutzerdefinierte Taste statt der rechten Maustaste zu verwenden"
    },
    aim_key = {
        en = "Custom Aim Key",
        ru = "Пользовательская клавиша прицеливания",
        de = "Benutzerdefinierte Zieltaste"
    },
    aim_key_description = {
        en = "Key to activate auto-aim (only if custom key is enabled)",
        ru = "Клавиша для активации автонаведения (только если включена пользовательская клавиша)",
        de = "Taste zum Aktivieren des Auto-Zielens (nur wenn benutzerdefinierte Taste aktiviert ist)"
    },
    use_mouse2_fallback = {
        en = "Use Mouse2 (Right Click).",
        ru = "Использовать Mouse2 (ПКМ).",
        de = "Mouse2 (Rechtsklick) verwenden."
    },
    use_mouse2_fallback_description = {
        en = "If enabled, auto-aim will trigger when holding Mouse2 (right click). If disabled, uses custom keybind.",
        ru = "Если включено, автонаведение активируется при удержании ПКМ. Если выключено — используется пользовательская клавиша.",
        de = "Wenn aktiviert, wird Auto-Zielen beim Halten von Mouse2 (Rechtsklick) ausgelöst. Wenn deaktiviert, wird die benutzerdefinierte Taste verwendet."
    },
    disable_when_teammates_are_dead = {
        en = "Disable auto-aim When Teammates Are Dead",
        ru = "Отключить автонаведение, когда товарищи по команде мертвы",
        de = "Auto-Zielen deaktivieren, wenn Teammitglieder tot sind"
    },
    disable_when_teammates_are_dead_description = {
        en = "If enabled, auto-aim will be disabled when any teammate is dead.",
        ru = "Если включено, автонаведение будет отключено, когда любой товарищ по команде мёртв или связан.",
        de = "Wenn aktiviert, wird das Auto-Zielen deaktiviert, wenn ein Teammitglied tot ist."
    },
    specials_only = {
        en = "Specials Only",
        ru = "Только особые враги",
        de = "Nur Spezials"
    },
    specials_only_description = {
        en = "If enabled, specials are always targeted. Non-specials are only targeted if they are actively targeting a player.",
        ru = "Если включено, особые враги всегда являются целями. Обычные враги — только если они атакуют игрока.",
        de = "Wenn aktiviert, werden Spezials immer anvisiert. Nicht-Spezials nur, wenn sie aktiv einen Spieler angreifen."
    },

    boss_lock_keybind = {
        en = "Boss Lock Keybind",
        ru = "Клавиша блокировки на босса",
        de = "Boss-Sperre Taste"
    },
    boss_lock_keybind_description = {
        en = "While held, only target boss enemies (ignores priority settings and specials-only filter).",
        ru = "Пока удерживается, наводиться только на врагов-боссов (игнорирует приоритеты и фильтр особых врагов).",
        de = "Solange gehalten: nur Bossgegner anvisieren (ignoriert Prioritätseinstellungen und Spezials-Filter)."
    },

    -- Triggerbot Settings
    triggerbot_settings = {
        en = "Triggerbot Settings",
        ru = "Настройки триггербота",
        de = "Triggerbot-Einstellungen"
    },
    enable_triggerbot = {
        en = "Enable Triggerbot",
        ru = "Включить триггербот",
        de = "Triggerbot aktivieren"
    },
    enable_triggerbot_description = {
        en = "Automatically fire weapon when conditions are met.",
        ru = "Автоматически стрелять из оружия при выполнении условий.",
        de = "Automatisches Feuern der Waffe, wenn Bedingungen erfüllt sind."
    },
    triggerbot_use_raycast = {
        en = "Use Raycast Mode",
        ru = "Использовать режим трассировки луча",
        de = "Raycast-Modus verwenden"
    },
    triggerbot_use_raycast_description = {
        en = "If enabled, fires when crosshair is directly on an enemy. If disabled, fires when aimbot has locked onto a target.",
        ru = "Если включено, стреляет, когда прицел наведён прямо на врага. Если выключено — стреляет, когда аимбот захватил цель.",
        de = "Wenn aktiviert, feuert bei direktem Fadenkreuz auf Feind. Wenn deaktiviert, feuert wenn Aimbot ein Ziel erfasst hat."
    },
    triggerbot_keybind = {
        en = "Triggerbot Keybind",
        ru = "Клавиша триггербота",
        de = "Triggerbot-Taste"
    },
    triggerbot_keybind_description = {
        en = "If unbound, triggerbot will activate automatically when enabled.",
        ru = "Если не привязана, триггербот будет активироваться автоматически при включении.",
        de = "Wenn nicht gebunden, aktiviert sich der Triggerbot automatisch, wenn er aktiviert ist."
    },
    triggerbot_weakspot_only = {
        en = "Weakspot Only",
        ru = "Только слабые места",
        de = "Nur Schwachstellen"
    },
    triggerbot_weakspot_only_description = {
        en = "If enabled, triggerbot will only fire when aiming at enemy weakspots.",
        ru = "Если включено, триггербот будет стрелять только при наведении на слабые места врагов.",
        de = "Wenn aktiviert, feuert der Triggerbot nur beim Zielen auf feindliche Schwachstellen."
    },
    triggerbot_respect_priority = {
        en = "Respect Priority Targets",
        ru = "Учитывать приоритетные цели",
        de = "Prioritätsziele beachten"
    },
    triggerbot_respect_priority_description = {
        en = "If enabled, triggerbot will only fire at enemies marked as priority targets. This only applies to Raycast Mode.",
        ru = "Если включено, триггербот будет стрелять только по врагам, отмеченным как приоритетные цели. Это применимо только к режиму Raycast.",
        de = "Wenn aktiviert, feuert der Triggerbot nur auf als Prioritätsziele markierte Gegner. Dies gilt nur für den Raycast-Modus."
    },
    require_main_weapon = {
        en = "Require Main Weapon",
        ru = "Требовать основное оружие",
        de = "Hauptwaffe erforderlich"
    },
    require_main_weapon_description = {
        en = "If enabled, aimbot will only activate when your main weapon (slot 2) is equipped.",
        ru = "Если включено, аимбот будет активироваться только при экипировке основного оружия (слот 2).",
        de = "Wenn aktiviert, wird der Aimbot nur aktiviert, wenn Ihre Hauptwaffe (Slot 2) ausgerüstet ist."
    },
    enable_spread_compensation = {
        en = "Enable Spread Compensation",
        ru = "Включить компенсацию разброса",
        de = "Streuungskompensation aktivieren"
    },
    enable_spread_compensation_description = {
        en = "If enabled, aim and triggerbot raycast will predict and compensate for weapon spread.",
        ru = "Если включено, прицел и луч триггербота будут предсказывать и компенсировать разброс оружия.",
        de = "Wenn aktiviert, werden Zielen und Triggerbot-Raycast die Waffenstreuung vorhersagen und kompensieren."
    },
    wait_for_crits = {
        en = "Wait for Surgical Crits",
        ru = "Ждать критов (Хирург)",
        de = "Auf Chirurgie-Krit warten"
    },
    wait_for_crits_description = {
        en = "If enabled, triggerbot will hold fire when aiming longer will guarantee a critical hit via the Surgical perk.",
        ru = "Если включено, триггербот удерживает огонь, если дополнительное время прицеливания гарантирует критический удар через перк «Хирург».",
        de = "Wenn aktiviert, hält der Triggerbot das Feuer zurück, wenn längeres Zielen durch den Chirurgie-Perk einen kritischen Treffer garantiert."
    },

    -- Auto Guard Settings
    auto_guard_settings = {
        en = "Auto Guard Settings",
        ru = "Настройки автоблока",
        de = "Auto-Block-Einstellungen"
    },
    enable_auto_guard = {
        en = "Enable Auto Guard",
        ru = "Включить автоблок",
        de = "Auto-Block aktivieren"
    },
    enable_auto_guard_description = {
        en = "Automatically block when a nearby enemy is performing a power attack.",
        ru = "Автоматически блокировать атаку, если ближайший враг наносит усиленный удар.",
        de = "Automatisch blocken, wenn ein nahegelegener Feind einen Kraftangriff ausführt."
    },
    auto_guard_range = {
        en = "Guard Detection Range (meters)",
        ru = "Дальность обнаружения (метры)",
        de = "Erkennungsreichweite (Meter)"
    },
    auto_guard_range_description = {
        en = "Radius in meters to scan for incoming enemy attacks.",
        ru = "Радиус в метрах для обнаружения вражеских атак.",
        de = "Radius in Metern zum Scannen nach eingehenden feindlichen Angriffen."
    },
    auto_guard_heavy_only = {
        en = "Power Attacks Only",
        ru = "Только усиленные атаки",
        de = "Nur Kraftangriffe"
    },
    auto_guard_heavy_only_description = {
        en = "If enabled, only block attacks with a heavy damage profile or running charge. If disabled, block any melee attack.",
        ru = "Если включено, блокировать только удары с тяжёлым профилем урона или атаки с разбега. Если выключено — блокировать любую атаку в ближнем бою.",
        de = "Wenn aktiviert, nur Angriffe mit schwerem Schadensprofil oder Anrennangriff blocken. Wenn deaktiviert, jeden Nahkampfangriff blocken."
    },

    -- Priority Targets
    priority_targets = {
        en = "Priority Targets",
        ru = "Приоритетные цели",
        de = "Prioritätsziele"
    },
    target_bosses = {
        en = "Target Bosses",
        ru = "Наводиться на боссов",
        de = "Bosse anvisieren"
    },
    target_bosses_description = {
        en = "Automatically aim at Champions/Beast of Nurgle/Chaos Spawn/Plague Ogryn/Rinda and Rodin/Captains.",
        ru = "Автоматически наводиться на Чемпионов/Зверя Нургла/Порождение Хаоса/Чумного Огрина/Ринду и Родина/Капитанов.",
        de = "Automatisch Champions/Bestie des Nurgle/Chaosbrut/Seuchen-Ogryn/Rinda und Rodin/Kapitäne anvisieren."
    },
    target_berzerkers = {
        en = "Target Ragers",
        ru = "Наводиться на Берсерков",
        de = "Rasende anvisieren"
    },
    target_berzerkers_description = {
        en = "Automatically aim at Ragers",
        ru = "Автоматически наводиться на Берсерков",
        de = "Automatisch Rasende anvisieren"
    },
    target_hounds = {
        en = "Target Pox Hounds",
        ru = "Наводиться на Чумных-гончих",
        de = "Pox-Hunde anvisieren"
    },
    target_hounds_description = {
        en = "Automatically aim at Pox Hounds",
        ru = "Автоматически наводиться на Чумных-гончих",
        de = "Automatisch Pox-Hunde anvisieren"
    },
    target_netgunners = {
        en = "Target Trappers",
        ru = "Наводиться на Ловчих",
        de = "Fänger anvisieren"
    },
    target_netgunners_description = {
        en = "Automatically aim at Trappers",
        ru = "Автоматически наводиться на Ловчих",
        de = "Automatisch Fänger anvisieren"
    },
    target_flamers = {
        en = "Target Flamers",
        ru = "Наводиться на Огнемётчиков",
        de = "Flammenwerfer anvisieren"
    },
    target_flamers_description = {
        en = "Automatically aim at Flamers.",
        ru = "Автоматически наводиться на Огнемётчиков.",
        de = "Automatisch Flammenwerfer anvisieren."
    },
    target_snipers = {
        en = "Target Snipers",
        ru = "Наводиться на Снайперов",
        de = "Scharfschützen anvisieren"
    },
    target_snipers_description = {
        en = "Automatically aim at Snipers.",
        ru = "Автоматически наводиться на Снайперов.",
        de = "Automatisch Scharfschützen anvisieren."
    },
    target_bombers = {
        en = "Target Bombers",
        ru = "Наводиться на Бомбардиров",
        de = "Bombenschützen anvisieren"
    },
    target_bombers_description = {
        en = "Automatically aim at Bombers and Grenadiers.",
        ru = "Автоматически наводиться на Бомбардиров и Гренадёров.",
        de = "Automatisch Bombenschützen und Grenadiere anvisieren."
    },
    target_poxwalkers = {
        en = "Target Poxbursters"
    },
    target_poxwalkers_description = {
        en = "Automatically aim at Poxbursters."
    },
    target_gunners = {
        en = "Target Gunners",
        ru = "Наводиться на Стрелков",
        de = "Schützen anvisieren"
    },
    target_gunners_description = {
        en = "Automatically aim at Elite Gunner enemies.",
        ru = "Автоматически наводиться на Элитных Стрелков.",
        de = "Automatisch Elite-Schützen anvisieren."
    },
    target_mutants = {
        en = "Target Mutants",
        ru = "Наводиться на Мутантов",
        de = "Mutanten anvisieren"
    },
    target_mutants_description = {
        en = "Automatically aim at Mutants.",
        ru = "Автоматически наводиться на Мутантов.",
        de = "Automatisch Mutanten anvisieren."
    },
    target_reapers = {
        en = "Target Reapers",
        ru = "Наводиться на Жнецов",
        de = "Schnitter anvisieren"
    },
    target_reapers_description = {
        en = "Automatically aim at Reapers.",
        ru = "Автоматически наводиться на Жнецов.",
        de = "Automatisch Schnitter anvisieren."
    },
    target_crushers = {
        en = "Target Crushers",
        ru = "Наводиться на Дробителей",
        de = "Zertrümmerer anvisieren"
    },
    target_crushers_description = {
        en = "Automatically aim at Crushers.",
        ru = "Автоматически наводиться на Дробителей.",
        de = "Automatisch Zertrümmerer anvisieren."
    },
    target_bulwarks = {
        en = "Target Bulwarks",
        ru = "Наводиться на Щитоносцев",
        de = "Bulwarks anvisieren"
    },
    target_bulwarks_description = {
        en = "Automatically aim at Bulwarks.",
        ru = "Автоматически наводиться на Щитоносцев.",
        de = "Automatisch Bulwarks anvisieren."
    },
    target_mauler = {
        en = "Target Scab Maulers",
        ru = "Наводиться на Скабов-Палачей",
        de = "Scab-Maulere anvisieren"
    },
    target_mauler_description = {
        en = "Automatically aim at Scab Maulers.",
        ru = "Автоматически наводиться на Скабов-Палачей.",
        de = "Automatisch Scab-Maulere anvisieren."
    },
    target_melee_regular = {
        en = "Target Regular Melee Enemies",
        ru = "Наводиться на обычных ближних врагов",
        de = "Normale Nahkampfgegner anvisieren"
    },
    target_melee_regular_description = {
        en = "Automatically aim at regular melee enemies (e.g., Poxwalkers, Groaners, Dreg Bruisers).",
        ru = "Автоматически наводиться на обычных ближних врагов (например, Поксвокеров, Стонущих, Дрег-Громил).",
        de = "Automatisch normale Nahkampfgegner anvisieren (z.B. Poxwalker, Groaner, Dreg-Schläger)."
    },
    target_ranged_regular = {
        en = "Target Regular Ranged Enemies",
        ru = "Наводиться на обычных дальних врагов",
        de = "Normale Fernkampfgegner anvisieren"
    },
    target_ranged_regular_description = {
        en = "Automatically aim at regular ranged enemies (e.g., Dreg Stalkers, Scab Shooters, Scab Stalkers).",
        ru = "Автоматически наводиться на обычных дальних врагов (например, Дрег-Охотников, Скаб-Стрелков, Скаб-Охотников).",
        de = "Automatisch normale Fernkampfgegner anvisieren (z.B. Dreg-Jäger, Scab-Schützen, Scab-Jäger)."
    },

    -- Profile selector
    priority_profile = {
        en = "Priority Profile",
        ru = "Профиль приоритетов",
        de = "Prioritätsprofil"
    },
    priority_profile_description = {
        en = "Select a priority profile. 'Auto' detects your current class automatically. 'Custom' uses the values in the Priority Targets group.",
        ru = "Выберите профиль приоритетов. «Авто» автоматически определяет ваш класс. «Пользовательский» использует значения из группы приоритетных целей.",
        de = "Prioritätsprofil wählen. 'Auto' erkennt die aktuelle Klasse. 'Benutzerdefiniert' nutzt die Prioritätsziele-Werte."
    },

    -- Profile option labels
    AutoClass    = { en = "Auto",    ru = "Авто",              de = "Auto"              },
    CustomClass  = { en = "Custom",  ru = "Пользовательский",  de = "Benutzerdefiniert" },
    VeteranClass = { en = "Veteran", ru = "Ветеран",           de = "Veteran"           },
    ZealotClass  = { en = "Zealot",  ru = "Фанатик",           de = "Zelot"             },
    PsykerClass  = { en = "Psyker",  ru = "Псайкер",           de = "Psyker"            },
    OgrynClass   = { en = "Ogryn",   ru = "Огрин",             de = "Ogryn"             },
    ArbitratorClass   = { en = "Arbitrator",   ru = "Арбитратор",             de = "Arbitrator"             },
    BrokerClass   = { en = "Hive Scum",   ru = "Скотина улья",             de = "Hive Scum"             },

    -- Class profile group headings
    veteran_profile_targets = { en = "Veteran — Priority Targets",    ru = "Ветеран — Приоритетные цели",      de = "Veteran — Prioritätsziele"    },
    zealot_profile_targets  = { en = "Zealot — Priority Targets",     ru = "Фанатик — Приоритетные цели",      de = "Zelot — Prioritätsziele"      },
    psyker_profile_targets  = { en = "Psyker — Priority Targets",     ru = "Псайкер — Приоритетные цели",      de = "Psyker — Prioritätsziele"     },
    ogryn_profile_targets   = { en = "Ogryn — Priority Targets",      ru = "Огрин — Приоритетные цели",        de = "Ogryn — Prioritätsziele"      },
    adamant_profile_targets = { en = "Arbitrator — Priority Targets", ru = "Арбитратор — Приоритетные цели",   de = "Arbitrator — Prioritätsziele" },
    broker_profile_targets  = { en = "Hive Scum — Priority Targets",  ru = "Скотина улья — Приоритетные цели", de = "Hive Scum — Prioritätsziele"  },

    -- Per-class behavior flags
    veteran_triggerbot_use_raycast            = { en = "Use Raycast Mode"           }, veteran_triggerbot_use_raycast_description            = { en = "If enabled, fires when crosshair is directly on an enemy. If disabled, fires when aimbot has locked onto a target." },
    veteran_triggerbot_weakspot_only          = { en = "Weakspot Only"              }, veteran_triggerbot_weakspot_only_description          = { en = "If enabled, triggerbot will only fire when aiming at enemy weakspots." },
    veteran_triggerbot_respect_priority       = { en = "Respect Priority Targets"   }, veteran_triggerbot_respect_priority_description       = { en = "If enabled, triggerbot will only fire at enemies marked as priority targets. This only applies to Raycast Mode." },
    veteran_wait_for_crits                    = { en = "Wait for Surgical Crits"    }, veteran_wait_for_crits_description                    = { en = "If enabled, triggerbot will hold fire when aiming longer will guarantee a critical hit via the Surgical perk." },

    zealot_triggerbot_use_raycast             = { en = "Use Raycast Mode"           }, zealot_triggerbot_use_raycast_description             = { en = "If enabled, fires when crosshair is directly on an enemy. If disabled, fires when aimbot has locked onto a target." },
    zealot_triggerbot_weakspot_only           = { en = "Weakspot Only"              }, zealot_triggerbot_weakspot_only_description           = { en = "If enabled, triggerbot will only fire when aiming at enemy weakspots." },
    zealot_triggerbot_respect_priority        = { en = "Respect Priority Targets"   }, zealot_triggerbot_respect_priority_description        = { en = "If enabled, triggerbot will only fire at enemies marked as priority targets. This only applies to Raycast Mode." },
    zealot_wait_for_crits                     = { en = "Wait for Surgical Crits"    }, zealot_wait_for_crits_description                     = { en = "If enabled, triggerbot will hold fire when aiming longer will guarantee a critical hit via the Surgical perk." },

    psyker_triggerbot_use_raycast             = { en = "Use Raycast Mode"           }, psyker_triggerbot_use_raycast_description             = { en = "If enabled, fires when crosshair is directly on an enemy. If disabled, fires when aimbot has locked onto a target." },
    psyker_triggerbot_weakspot_only           = { en = "Weakspot Only"              }, psyker_triggerbot_weakspot_only_description           = { en = "If enabled, triggerbot will only fire when aiming at enemy weakspots." },
    psyker_triggerbot_respect_priority        = { en = "Respect Priority Targets"   }, psyker_triggerbot_respect_priority_description        = { en = "If enabled, triggerbot will only fire at enemies marked as priority targets. This only applies to Raycast Mode." },
    psyker_wait_for_crits                     = { en = "Wait for Surgical Crits"    }, psyker_wait_for_crits_description                     = { en = "If enabled, triggerbot will hold fire when aiming longer will guarantee a critical hit via the Surgical perk." },

    ogryn_triggerbot_use_raycast              = { en = "Use Raycast Mode"           }, ogryn_triggerbot_use_raycast_description              = { en = "If enabled, fires when crosshair is directly on an enemy. If disabled, fires when aimbot has locked onto a target." },
    ogryn_triggerbot_weakspot_only            = { en = "Weakspot Only"              }, ogryn_triggerbot_weakspot_only_description            = { en = "If enabled, triggerbot will only fire when aiming at enemy weakspots." },
    ogryn_triggerbot_respect_priority         = { en = "Respect Priority Targets"   }, ogryn_triggerbot_respect_priority_description         = { en = "If enabled, triggerbot will only fire at enemies marked as priority targets. This only applies to Raycast Mode." },
    ogryn_wait_for_crits                      = { en = "Wait for Surgical Crits"    }, ogryn_wait_for_crits_description                      = { en = "If enabled, triggerbot will hold fire when aiming longer will guarantee a critical hit via the Surgical perk." },

    adamant_triggerbot_use_raycast            = { en = "Use Raycast Mode"           }, adamant_triggerbot_use_raycast_description            = { en = "If enabled, fires when crosshair is directly on an enemy. If disabled, fires when aimbot has locked onto a target." },
    adamant_triggerbot_weakspot_only          = { en = "Weakspot Only"              }, adamant_triggerbot_weakspot_only_description          = { en = "If enabled, triggerbot will only fire when aiming at enemy weakspots." },
    adamant_triggerbot_respect_priority       = { en = "Respect Priority Targets"   }, adamant_triggerbot_respect_priority_description       = { en = "If enabled, triggerbot will only fire at enemies marked as priority targets. This only applies to Raycast Mode." },
    adamant_wait_for_crits                    = { en = "Wait for Surgical Crits"    }, adamant_wait_for_crits_description                    = { en = "If enabled, triggerbot will hold fire when aiming longer will guarantee a critical hit via the Surgical perk." },

    broker_triggerbot_use_raycast             = { en = "Use Raycast Mode"           }, broker_triggerbot_use_raycast_description             = { en = "If enabled, fires when crosshair is directly on an enemy. If disabled, fires when aimbot has locked onto a target." },
    broker_triggerbot_weakspot_only           = { en = "Weakspot Only"              }, broker_triggerbot_weakspot_only_description           = { en = "If enabled, triggerbot will only fire when aiming at enemy weakspots." },
    broker_triggerbot_respect_priority        = { en = "Respect Priority Targets"   }, broker_triggerbot_respect_priority_description        = { en = "If enabled, triggerbot will only fire at enemies marked as priority targets. This only applies to Raycast Mode." },
    broker_wait_for_crits                     = { en = "Wait for Surgical Crits"    }, broker_wait_for_crits_description                     = { en = "If enabled, triggerbot will hold fire when aiming longer will guarantee a critical hit via the Surgical perk." },

    -- Per-class target labels
    veteran_target_bosses         = { en = "Target Bosses"                }, veteran_target_bosses_description         = { en = "Automatically aim at Champions/Beast of Nurgle/Chaos Spawn/Plague Ogryn/Captains." },
    veteran_target_berzerkers     = { en = "Target Ragers"                }, veteran_target_berzerkers_description     = { en = "Automatically aim at Ragers." },
    veteran_target_hounds         = { en = "Target Pox Hounds"            }, veteran_target_hounds_description         = { en = "Automatically aim at Pox Hounds." },
    veteran_target_netgunners     = { en = "Target Trappers"              }, veteran_target_netgunners_description     = { en = "Automatically aim at Trappers." },
    veteran_target_flamers        = { en = "Target Flamers"               }, veteran_target_flamers_description        = { en = "Automatically aim at Flamers." },
    veteran_target_snipers        = { en = "Target Snipers"               }, veteran_target_snipers_description        = { en = "Automatically aim at Snipers." },
    veteran_target_bombers        = { en = "Target Bombers"               }, veteran_target_bombers_description        = { en = "Automatically aim at Bombers and Grenadiers." },
    veteran_target_poxwalkers     = { en = "Target Poxbursters"           }, veteran_target_poxwalkers_description     = { en = "Automatically aim at Poxbursters." },
    veteran_target_gunners        = { en = "Target Gunners"               }, veteran_target_gunners_description        = { en = "Automatically aim at Elite Gunner enemies." },
    veteran_target_mutants        = { en = "Target Mutants"               }, veteran_target_mutants_description        = { en = "Automatically aim at Mutants." },
    veteran_target_crushers       = { en = "Target Crushers"              }, veteran_target_crushers_description       = { en = "Automatically aim at Crushers." },
    veteran_target_bulwarks       = { en = "Target Bulwarks"              }, veteran_target_bulwarks_description       = { en = "Automatically aim at Bulwarks." },
    veteran_target_reapers        = { en = "Target Reapers"               }, veteran_target_reapers_description        = { en = "Automatically aim at Reapers." },
    veteran_target_mauler         = { en = "Target Scab Maulers"          }, veteran_target_mauler_description         = { en = "Automatically aim at Scab Maulers." },
    veteran_target_melee_regular  = { en = "Target Regular Melee Enemies" }, veteran_target_melee_regular_description  = { en = "Automatically aim at regular melee enemies." },
    veteran_target_ranged_regular = { en = "Target Regular Ranged Enemies"}, veteran_target_ranged_regular_description = { en = "Automatically aim at regular ranged enemies." },

    zealot_target_bosses          = { en = "Target Bosses"                }, zealot_target_bosses_description          = { en = "Automatically aim at Champions/Beast of Nurgle/Chaos Spawn/Plague Ogryn/Captains." },
    zealot_target_berzerkers      = { en = "Target Ragers"                }, zealot_target_berzerkers_description      = { en = "Automatically aim at Ragers." },
    zealot_target_hounds          = { en = "Target Pox Hounds"            }, zealot_target_hounds_description          = { en = "Automatically aim at Pox Hounds." },
    zealot_target_netgunners      = { en = "Target Trappers"              }, zealot_target_netgunners_description      = { en = "Automatically aim at Trappers." },
    zealot_target_flamers         = { en = "Target Flamers"               }, zealot_target_flamers_description         = { en = "Automatically aim at Flamers." },
    zealot_target_snipers         = { en = "Target Snipers"               }, zealot_target_snipers_description         = { en = "Automatically aim at Snipers." },
    zealot_target_bombers         = { en = "Target Bombers"               }, zealot_target_bombers_description         = { en = "Automatically aim at Bombers and Grenadiers." },
    zealot_target_poxwalkers      = { en = "Target Poxbursters"           }, zealot_target_poxwalkers_description      = { en = "Automatically aim at Poxbursters." },
    zealot_target_gunners         = { en = "Target Gunners"               }, zealot_target_gunners_description         = { en = "Automatically aim at Elite Gunner enemies." },
    zealot_target_mutants         = { en = "Target Mutants"               }, zealot_target_mutants_description         = { en = "Automatically aim at Mutants." },
    zealot_target_crushers        = { en = "Target Crushers"              }, zealot_target_crushers_description        = { en = "Automatically aim at Crushers." },
    zealot_target_bulwarks        = { en = "Target Bulwarks"              }, zealot_target_bulwarks_description        = { en = "Automatically aim at Bulwarks." },
    zealot_target_reapers         = { en = "Target Reapers"               }, zealot_target_reapers_description         = { en = "Automatically aim at Reapers." },
    zealot_target_mauler          = { en = "Target Scab Maulers"          }, zealot_target_mauler_description          = { en = "Automatically aim at Scab Maulers." },
    zealot_target_melee_regular   = { en = "Target Regular Melee Enemies" }, zealot_target_melee_regular_description   = { en = "Automatically aim at regular melee enemies." },
    zealot_target_ranged_regular  = { en = "Target Regular Ranged Enemies"}, zealot_target_ranged_regular_description  = { en = "Automatically aim at regular ranged enemies." },

    psyker_target_bosses          = { en = "Target Bosses"                }, psyker_target_bosses_description          = { en = "Automatically aim at Champions/Beast of Nurgle/Chaos Spawn/Plague Ogryn/Captains." },
    psyker_target_berzerkers      = { en = "Target Ragers"                }, psyker_target_berzerkers_description      = { en = "Automatically aim at Ragers." },
    psyker_target_hounds          = { en = "Target Pox Hounds"            }, psyker_target_hounds_description          = { en = "Automatically aim at Pox Hounds." },
    psyker_target_netgunners      = { en = "Target Trappers"              }, psyker_target_netgunners_description      = { en = "Automatically aim at Trappers." },
    psyker_target_flamers         = { en = "Target Flamers"               }, psyker_target_flamers_description         = { en = "Automatically aim at Flamers." },
    psyker_target_snipers         = { en = "Target Snipers"               }, psyker_target_snipers_description         = { en = "Automatically aim at Snipers." },
    psyker_target_bombers         = { en = "Target Bombers"               }, psyker_target_bombers_description         = { en = "Automatically aim at Bombers and Grenadiers." },
    psyker_target_poxwalkers      = { en = "Target Poxbursters"           }, psyker_target_poxwalkers_description      = { en = "Automatically aim at Poxbursters." },
    psyker_target_gunners         = { en = "Target Gunners"               }, psyker_target_gunners_description         = { en = "Automatically aim at Elite Gunner enemies." },
    psyker_target_mutants         = { en = "Target Mutants"               }, psyker_target_mutants_description         = { en = "Automatically aim at Mutants." },
    psyker_target_crushers        = { en = "Target Crushers"              }, psyker_target_crushers_description        = { en = "Automatically aim at Crushers." },
    psyker_target_bulwarks        = { en = "Target Bulwarks"              }, psyker_target_bulwarks_description        = { en = "Automatically aim at Bulwarks." },
    psyker_target_reapers         = { en = "Target Reapers"               }, psyker_target_reapers_description         = { en = "Automatically aim at Reapers." },
    psyker_target_mauler          = { en = "Target Scab Maulers"          }, psyker_target_mauler_description          = { en = "Automatically aim at Scab Maulers." },
    psyker_target_melee_regular   = { en = "Target Regular Melee Enemies" }, psyker_target_melee_regular_description   = { en = "Automatically aim at regular melee enemies." },
    psyker_target_ranged_regular  = { en = "Target Regular Ranged Enemies"}, psyker_target_ranged_regular_description  = { en = "Automatically aim at regular ranged enemies." },

    ogryn_target_bosses           = { en = "Target Bosses"                }, ogryn_target_bosses_description           = { en = "Automatically aim at Champions/Beast of Nurgle/Chaos Spawn/Plague Ogryn/Captains." },
    ogryn_target_berzerkers       = { en = "Target Ragers"                }, ogryn_target_berzerkers_description       = { en = "Automatically aim at Ragers." },
    ogryn_target_hounds           = { en = "Target Pox Hounds"            }, ogryn_target_hounds_description           = { en = "Automatically aim at Pox Hounds." },
    ogryn_target_netgunners       = { en = "Target Trappers"              }, ogryn_target_netgunners_description       = { en = "Automatically aim at Trappers." },
    ogryn_target_flamers          = { en = "Target Flamers"               }, ogryn_target_flamers_description          = { en = "Automatically aim at Flamers." },
    ogryn_target_snipers          = { en = "Target Snipers"               }, ogryn_target_snipers_description          = { en = "Automatically aim at Snipers." },
    ogryn_target_bombers          = { en = "Target Bombers"               }, ogryn_target_bombers_description          = { en = "Automatically aim at Bombers and Grenadiers." },
    ogryn_target_poxwalkers       = { en = "Target Poxbursters"           }, ogryn_target_poxwalkers_description       = { en = "Automatically aim at Poxbursters." },
    ogryn_target_gunners          = { en = "Target Gunners"               }, ogryn_target_gunners_description          = { en = "Automatically aim at Elite Gunner enemies." },
    ogryn_target_mutants          = { en = "Target Mutants"               }, ogryn_target_mutants_description          = { en = "Automatically aim at Mutants." },
    ogryn_target_crushers         = { en = "Target Crushers"              }, ogryn_target_crushers_description         = { en = "Automatically aim at Crushers." },
    ogryn_target_bulwarks         = { en = "Target Bulwarks"              }, ogryn_target_bulwarks_description         = { en = "Automatically aim at Bulwarks." },
    ogryn_target_reapers          = { en = "Target Reapers"               }, ogryn_target_reapers_description          = { en = "Automatically aim at Reapers." },
    ogryn_target_mauler           = { en = "Target Scab Maulers"          }, ogryn_target_mauler_description           = { en = "Automatically aim at Scab Maulers." },
    ogryn_target_melee_regular    = { en = "Target Regular Melee Enemies" }, ogryn_target_melee_regular_description    = { en = "Automatically aim at regular melee enemies." },
    ogryn_target_ranged_regular   = { en = "Target Regular Ranged Enemies"}, ogryn_target_ranged_regular_description   = { en = "Automatically aim at regular ranged enemies." },

    adamant_target_bosses         = { en = "Target Bosses"                }, adamant_target_bosses_description         = { en = "Automatically aim at Champions/Beast of Nurgle/Chaos Spawn/Plague Ogryn/Captains." },
    adamant_target_berzerkers     = { en = "Target Ragers"                }, adamant_target_berzerkers_description     = { en = "Automatically aim at Ragers." },
    adamant_target_hounds         = { en = "Target Pox Hounds"            }, adamant_target_hounds_description         = { en = "Automatically aim at Pox Hounds." },
    adamant_target_netgunners     = { en = "Target Trappers"              }, adamant_target_netgunners_description     = { en = "Automatically aim at Trappers." },
    adamant_target_flamers        = { en = "Target Flamers"               }, adamant_target_flamers_description        = { en = "Automatically aim at Flamers." },
    adamant_target_snipers        = { en = "Target Snipers"               }, adamant_target_snipers_description        = { en = "Automatically aim at Snipers." },
    adamant_target_bombers        = { en = "Target Bombers"               }, adamant_target_bombers_description        = { en = "Automatically aim at Bombers and Grenadiers." },
    adamant_target_poxwalkers     = { en = "Target Poxbursters"           }, adamant_target_poxwalkers_description     = { en = "Automatically aim at Poxbursters." },
    adamant_target_gunners        = { en = "Target Gunners"               }, adamant_target_gunners_description        = { en = "Automatically aim at Elite Gunner enemies." },
    adamant_target_mutants        = { en = "Target Mutants"               }, adamant_target_mutants_description        = { en = "Automatically aim at Mutants." },
    adamant_target_crushers       = { en = "Target Crushers"              }, adamant_target_crushers_description       = { en = "Automatically aim at Crushers." },
    adamant_target_bulwarks       = { en = "Target Bulwarks"              }, adamant_target_bulwarks_description       = { en = "Automatically aim at Bulwarks." },
    adamant_target_reapers        = { en = "Target Reapers"               }, adamant_target_reapers_description        = { en = "Automatically aim at Reapers." },
    adamant_target_mauler         = { en = "Target Scab Maulers"          }, adamant_target_mauler_description         = { en = "Automatically aim at Scab Maulers." },
    adamant_target_melee_regular  = { en = "Target Regular Melee Enemies" }, adamant_target_melee_regular_description  = { en = "Automatically aim at regular melee enemies." },
    adamant_target_ranged_regular = { en = "Target Regular Ranged Enemies"}, adamant_target_ranged_regular_description = { en = "Automatically aim at regular ranged enemies." },

    broker_target_bosses          = { en = "Target Bosses"                }, broker_target_bosses_description          = { en = "Automatically aim at Champions/Beast of Nurgle/Chaos Spawn/Plague Ogryn/Captains." },
    broker_target_berzerkers      = { en = "Target Ragers"                }, broker_target_berzerkers_description      = { en = "Automatically aim at Ragers." },
    broker_target_hounds          = { en = "Target Pox Hounds"            }, broker_target_hounds_description          = { en = "Automatically aim at Pox Hounds." },
    broker_target_netgunners      = { en = "Target Trappers"              }, broker_target_netgunners_description      = { en = "Automatically aim at Trappers." },
    broker_target_flamers         = { en = "Target Flamers"               }, broker_target_flamers_description         = { en = "Automatically aim at Flamers." },
    broker_target_snipers         = { en = "Target Snipers"               }, broker_target_snipers_description         = { en = "Automatically aim at Snipers." },
    broker_target_bombers         = { en = "Target Bombers"               }, broker_target_bombers_description         = { en = "Automatically aim at Bombers and Grenadiers." },
    broker_target_poxwalkers      = { en = "Target Poxbursters"           }, broker_target_poxwalkers_description      = { en = "Automatically aim at Poxbursters." },
    broker_target_gunners         = { en = "Target Gunners"               }, broker_target_gunners_description         = { en = "Automatically aim at Elite Gunner enemies." },
    broker_target_mutants         = { en = "Target Mutants"               }, broker_target_mutants_description         = { en = "Automatically aim at Mutants." },
    broker_target_crushers        = { en = "Target Crushers"              }, broker_target_crushers_description        = { en = "Automatically aim at Crushers." },
    broker_target_bulwarks        = { en = "Target Bulwarks"              }, broker_target_bulwarks_description        = { en = "Automatically aim at Bulwarks." },
    broker_target_reapers         = { en = "Target Reapers"               }, broker_target_reapers_description         = { en = "Automatically aim at Reapers." },
    broker_target_mauler          = { en = "Target Scab Maulers"          }, broker_target_mauler_description          = { en = "Automatically aim at Scab Maulers." },
    broker_target_melee_regular   = { en = "Target Regular Melee Enemies" }, broker_target_melee_regular_description   = { en = "Automatically aim at regular melee enemies." },
    broker_target_ranged_regular  = { en = "Target Regular Ranged Enemies"}, broker_target_ranged_regular_description  = { en = "Automatically aim at regular ranged enemies." },
}

return loc