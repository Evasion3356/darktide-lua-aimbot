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

    -- Priority Levels
    Off = {
        en = "Off",
        ru = "Выкл",
        de = "Aus"
    },
    Lowest = {
        en = "Lowest",
        ru = "Самый низкий",
        de = "Am niedrigsten"
    },
    Lower = {
        en = "Lower",
        ru = "Ниже",
        de = "Niedriger"
    },
    Low = {
        en = "Low",
        ru = "Низкий",
        de = "Niedrig"
    },
    Medium = {
        en = "Medium",
        ru = "Средний",
        de = "Mittel"
    },
    Elevated = {
        en = "Elevated",
        ru = "Повышенный",
        de = "Erhöht"
    },
    High = {
        en = "High",
        ru = "Высокий",
        de = "Hoch"
    },
    Extreme = {
        en = "Extreme",
        ru = "Экстремальный",
        de = "Extrem"
    },
    Ultra = {
        en = "Ultra",
        ru = "Ультра",
        de = "Ultra"
    },
    Critical = {
        en = "Critical",
        ru = "Критический",
        de = "Kritisch"
    },
    
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
        ru = "Если включено, автонаведение будет отключено, когда любой товарищ",
        de = "Wenn aktiviert, wird das Auto-Zielen deaktiviert, wenn ein Teammitglied tot ist."
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
    target_ogryns = {
        en = "Target Ogryns (Reaper)",
        ru = "Наводиться на Огринов (Жнец)",
        de = "Ogryns anvisieren (Schnitter)"
    },
    target_ogryns_description = {
        en = "Automatically aim at Reaper Ogryns.",
        ru = "Автоматически наводиться на Жнец.",
        de = "Automatisch Ogryns-Schnitter anvisieren."
    },
    target_ogryns_melee = {
        en = "Target Ogryns (Melee)",
        ru = "Наводиться на Огринов",
        de = "Ogryns anvisieren"
    },
    target_ogryns_melee_description = {
        en = "Automatically aim at Ogryns. (Bulwark/Crusher)",
        ru = "Автоматически наводиться на Огринов (Щитоносец/Дробитель).",
        de = "Automatisch Ogryns anvisieren (Bulwark/Crusher)."
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
        en = "Automatically aim at regular melee enemies (e.g., Chaos Cultists, Plague Zombies).",
        ru = "Автоматически наводиться на обычных ближних врагов (например, культистов Хаоса, чумных зомби).",
        de = "Automatisch normale Nahkampfgegner anvisieren (z.B. Chaos-Kultisten, Seuchen-Zombies)."
    },
    target_ranged_regular = {
        en = "Target Regular Ranged Enemies",
        ru = "Наводиться на обычных дальних врагов",
        de = "Normale Fernkampfgegner anvisieren"
    },
    target_ranged_regular_description = {
        en = "Automatically aim at regular ranged enemies (e.g., Plague Monks, Chaos Warriors).",
        ru = "Автоматически наводиться на обычных дальних врагов (например, чумных монахов, воинов Хаоса).",
        de = "Automatisch normale Fernkampfgegner anvisieren (z.B. Seuchen-Mönche, Chaos-Krieger)."
    }
}

return loc