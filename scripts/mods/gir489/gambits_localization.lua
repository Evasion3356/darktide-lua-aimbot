local mod = get_mod("darktide-lua-aimbot")

local loc = {
    mod_name = {
        en = "Priority Target Auto-Aim",
        ru = "Автонаведение на приоритетные цели",
        de = "Automatisches Zielen auf Prioritätsziele"
    },
    mod_description = {
        en = "Automatically aims at priority special enemies when right-clicking or using a custom keybind.",
        ru = "Автоматически наводится на приоритетных особых врагов при нажатии ПКМ или пользовательской клавиши.",
        de = "Zielt automatisch auf priorisierte Spezialgegner beim Rechtsklick oder mit einer benutzerdefinierten Taste."
    },

    -- Priority Levels
    Off = {
        en = "Off",
        ru = "Выкл",
        de = "Aus"
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
        ru = "Наводиться на Покс-гончих",
        de = "Pox-Hunde anvisieren"
    },
    target_hounds_description = {
        en = "Automatically aim at Pox Hounds",
        ru = "Автоматически наводиться на Покс-гончих",
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
    target_ogryns_melee = {
        en = "Target Ogryns",
        ru = "Наводиться на Огринов",
        de = "Ogryns anvisieren"
    },
    target_ogryns_melee_description = {
        en = "Automatically aim at Ogryns. (Bulwark/Crusher)",
        ru = "Автоматически наводиться на Огринов (Щитоносец/Дробитель).",
        de = "Automatisch Ogryns anvisieren (Bulwark/Crusher)."
    }
}

return loc