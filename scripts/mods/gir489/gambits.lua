local mod = get_mod("darktide-lua-gambits")
local Health = require("scripts/utilities/health")
local HitZone = require("scripts/utilities/attack/hit_zone")
local Breed = require("scripts/utilities/breed")
local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")
local Recoil = require("scripts/utilities/recoil")
local Sway = require("scripts/utilities/sway")
local Suppression = require("scripts/utilities/attack/suppression")
local WeaponMovementState = require("scripts/extension_systems/weapon/utilities/weapon_movement_state")
local CriticalStrike = require("scripts/utilities/attack/critical_strike")
local Dodge = require("scripts/extension_systems/character_state_machine/character_states/utilities/dodge")
local DamageProfile = require("scripts/utilities/attack/damage_profile")
local DamageCalculation = require("scripts/utilities/attack/damage_calculation")
local PowerLevelSettings = require("scripts/settings/damage/power_level_settings")

local HALF_PI = math.pi / 2

local aim_button_pressed = false
local triggerbot_pressed = false
local has_target = false
local last_semi_auto_fire_time = 0
-- Zone-lock hysteresis: when the preferred zone is briefly occluded by a
-- physics reaction (e.g. BoN blob dipping on hit), hold the last confirmed
-- zone for up to ZONE_GRACE_FRAMES before allowing a zone switch.
local last_aim_unit = nil
local last_aim_zone = nil
local last_aim_zone_blocked_frames = 0
local ZONE_GRACE_FRAMES = 10

local BREED_PRIORITY_MAP = {
    -- Hound
    chaos_hound = "target_hounds", --Pox Hound
    chaos_hound_mutator = "target_hounds", --Pox Hound
    chaos_armored_hound = "target_hounds", -- Armored Hound
    -- Boss Enemies
    chaos_beast_of_nurgle = "target_bosses", --Beast of Nurgle
    chaos_plague_ogryn = "target_bosses", --Plague Ogyrn
    chaos_spawn = "target_bosses", --Chaos Spawn
    cultist_captain = "target_bosses", --Admontion Champion
    renegade_captain = "target_bosses", --Scab Captain
    renegade_twin_captain = "target_bosses", --Rodin Karnak
    renegade_twin_captain_two = "target_bosses", --Rinda Karnak
    chaos_daemonhost = "target_bosses", --Daemonhost (with special check below)
    chaos_mutator_daemonhost = "target_bosses", --Daemonhost (with special check below)
    chaos_ogryn_houndmaster = "target_bosses", --Houndmaster
    -- Trappers
    renegade_netgunner = "target_netgunners", --Trapper
    -- Flamers
    cultist_flamer = "target_flamers", --Dreg Tox Flamer
    renegade_flamer = "target_flamers", --Scab Flamer
    renegade_flamer_mutator = "target_flamers", --Scab Flamer
    -- Sniper
    renegade_sniper = "target_snipers", --Sniper
    -- Poxbursters
    chaos_poxwalker_bomber = "target_poxwalkers", --Poxburster
    -- Bombers
    cultist_grenadier = "target_bombers", --Dreg Tox Bomber
    renegade_grenadier = "target_bombers", --Scab Bomber
    -- Gunners
    cultist_shocktrooper = "target_gunners", --Dreg Shotgunner
    cultist_gunner = "target_gunners", --Dreg Gunner
    renegade_gunner = "target_gunners", --Scab Gunner
    renegade_plasma_gunner = "target_gunners", --Scab Plasmer Gunner
    renegade_shocktrooper = "target_gunners", --Scab Shotgunner
    -- Ragers
    cultist_berzerker = "target_berzerkers", --Dreg Rager
    renegade_berzerker = "target_berzerkers", --Scab Rager
    -- Mauler
    renegade_executor = "target_mauler", --Scab Mauler
    -- Mutants
    cultist_mutant = "target_mutants", --Mutant
    cultist_mutant_mutator = "target_mutants", --Mutant
    -- Bulwark
    chaos_ogryn_bulwark = "target_bulwarks", --Bulwark
    --Crusher
    chaos_ogryn_executor = "target_crushers", --Crusher
    -- Reaper
    chaos_ogryn_gunner = "target_reapers", --Reaper

    -- Melee (regular)
    chaos_armored_infected = "target_melee_regular", -- Amoured Groaner
    chaos_lesser_mutated_poxwalker = "target_melee_regular", -- Mutated Poxwalker
    chaos_mutated_poxwalker = "target_melee_regular", --Tentacled Poxwalker
    chaos_mutator_ritualist = "target_melee_regular", -- Dreg Ritualist
    chaos_newly_infected = "target_melee_regular", -- Groaner
    chaos_poxwalker = "target_melee_regular", -- Poxwalker
    cultist_melee = "target_melee_regular", -- Dreg Bruiser
    cultist_ritualist = "target_melee_regular", -- Dreg Ritualist
    renegade_melee = "target_melee_regular", -- Scab Bruiser

    -- Ranged (regular)
    cultist_assault = "target_ranged_regular", -- Dreg Stalker
    renegade_assault = "target_ranged_regular", -- Scab Stalker
    renegade_radio_operator = "target_ranged_regular", -- Scab Radio Operator
    renegade_rifleman = "target_ranged_regular" -- Scab Shooter
}

local POXBURSTER_BREEDS = {
    chaos_poxwalker_bomber = true,
}

local DAEMONHOST_BREEDS = {
    chaos_daemonhost = true,
    chaos_mutator_daemonhost = true,
}

-- Per-breed ordered aim zone list. Each zone is tried front-to-back; the first
-- one with a clear line-of-sight wins. "actor" zones use Actor.world_bounds()
-- to get the actual collision-shape center (not the actor origin/attachment);
-- "node" zones use Unit.world_position() on the named skeleton node.
local BREED_AIM_ZONES = {
    chaos_beast_of_nurgle = {
        { type = "actor", name = "c_weakspot",      top_bias = 0.5 }, -- blob on back (1.0x ranged mult)
        { type = "actor", name = "c_tonguespline03"               }, -- mid-tongue (visible when BoN faces player)
        { type = "node",  name = "j_head" },
    },
}
local DEFAULT_AIM_ZONES = { { type = "node", name = "j_head" } }

-- Maps each priority_profile value to the setting-key prefix used in gambits_data.lua.
-- "custom" uses no prefix (the base priority_targets group).
local PROFILE_PREFIXES = {
    custom  = "",
    veteran = "veteran_",
    zealot  = "zealot_",
    psyker  = "psyker_",
    ogryn   = "ogryn_",
    adamant = "adamant_",
    broker  = "broker_",
}

local function get_player_archetype()
    local player = Managers.player:local_player(1)
    if not player then return nil end
    local profile = player:profile()
    return profile and profile.archetype and profile.archetype.name
end

local math_rad = math.rad
local math_cos = math.cos
local math_atan2 = math.atan2
local math_asin = math.asin
local math_sin = math.sin
local math_abs = math.abs
local math_min = math.min
local Vector3_normalize = Vector3.normalize
local Vector3_dot = Vector3.dot
local Vector3_length = Vector3.length
local ScriptUnit_has_extension = ScriptUnit.has_extension
local ScriptUnit_extension = ScriptUnit.extension
local Unit_node = Unit.node
local Unit_world_position = Unit.world_position
local Actor_unit = Actor.unit
local Actor_world_bounds = Actor.world_bounds
local PhysicsWorld_raycast = PhysicsWorld.raycast
local World_physics_world = World.physics_world
local Application_main_world = Application.main_world
local Quaternion_forward = Quaternion.forward
local table_sort = table.sort
local pairs = pairs
local next = next

-- Pre-allocated reusable table and comparator to reduce GC pressure
local reusable_enemies = {}
local function priority_comparator(a, b)
    if a.priority ~= b.priority then
        return a.priority > b.priority
    end
    return a.distance_sq < b.distance_sq
end

-- Cached settings, refreshed on change
local cached_settings = {}
local function refresh_settings()
    cached_settings.enable_triggerbot = mod:get("enable_triggerbot")
    cached_settings.triggerbot_keybind = mod:get("triggerbot_keybind")
    cached_settings.triggerbot_use_raycast = mod:get("triggerbot_use_raycast")
    cached_settings.triggerbot_weakspot_only = mod:get("triggerbot_weakspot_only")
    cached_settings.triggerbot_respect_priority = mod:get("triggerbot_respect_priority")
    cached_settings.require_main_weapon = mod:get("require_main_weapon")
    cached_settings.use_mouse2_fallback = mod:get("use_mouse2_fallback")
    cached_settings.enable_fov_check = mod:get("enable_fov_check")
    cached_settings.fov_angle = mod:get("fov_angle")
    cached_settings.disable_when_teammates_are_dead = mod:get("disable_when_teammates_are_dead")
    cached_settings.priority_profile = mod:get("priority_profile")
    cached_settings.enable_spread_compensation = mod:get("enable_spread_compensation")
    cached_settings.wait_for_crits = mod:get("wait_for_crits")
    cached_settings.enable_auto_guard = mod:get("enable_auto_guard")
    cached_settings.auto_guard_range = mod:get("auto_guard_range")
    cached_settings.auto_guard_heavy_only = mod:get("auto_guard_heavy_only")

    -- Build a [class][breed_name] -> priority lookup table for get_breed_priority.
    local pt = cached_settings.priority_target or {}
    for class, prefix in pairs(PROFILE_PREFIXES) do
        local class_tbl = pt[class] or {}
        for breed_name, base_key in pairs(BREED_PRIORITY_MAP) do
            class_tbl[breed_name] = mod:get(prefix .. base_key) or 0
        end
        pt[class] = class_tbl
    end
    cached_settings.priority_target = pt
end
refresh_settings()

mod.on_setting_changed = function(setting_id)
    refresh_settings()
end

local function get_daemonhost_priority(unit, priority)
    -- If it's been damaged, it's aggroed and should be targeted
    local health_ext = ScriptUnit_extension(unit, "health_system")
    if health_ext and health_ext:current_health_percent() <= 0.98 then
        return priority
    end
    return 0
end

local POXBURSTER_EXPLOSION_RADIUS_SQ = 42 -- 6m outer explosion radius, squared

local function is_poxburster_safe_to_target(unit)
    local pox_pos = POSITION_LOOKUP[unit]
    if not pox_pos then
        return false
    end

    local human_players = Managers.player:human_players()
    for _, player in pairs(human_players) do
        if player.player_unit and player:unit_is_alive() then
            local player_pos = POSITION_LOOKUP[player.player_unit]
            if player_pos then
                local diff = pox_pos - player_pos
                if Vector3_dot(diff, diff) <= POXBURSTER_EXPLOSION_RADIUS_SQ then
                    return false
                end
            end
        end
    end

    return true
end

local function get_breed_priority(breed_name, unit)
    local profile = cached_settings.priority_profile or "auto"
    local tbl
    if profile == "auto" then
        local archetype = get_player_archetype()
        tbl = cached_settings.priority_target[archetype or "custom"]
    else
        tbl = cached_settings.priority_target[profile]
    end

    local priority = (tbl and tbl[breed_name]) or 0
    if priority > 0 and DAEMONHOST_BREEDS[breed_name] then
        return get_daemonhost_priority(unit, priority)
    end
    return priority
end

local function get_all_enemies()
    local extension_manager = Managers.state and Managers.state.extension
    if not extension_manager then
        return reusable_enemies, 0
    end

    local entities = extension_manager:get_entities("MinionHuskLocomotionExtension")
    if not next(entities) then
        entities = extension_manager:get_entities("MinionLocomotionExtension")
        if not next(entities) then
            return reusable_enemies, 0
        end
    end

    local player = Managers.player:local_player(1)
    local player_pos = player and player.player_unit and POSITION_LOOKUP[player.player_unit]

    local n = 0

    for unit, _ in pairs(entities) do
        local health_extension = ScriptUnit_has_extension(unit, "health_system")
        if health_extension and health_extension:is_alive() then
            local unit_data_ext = ScriptUnit_extension(unit, "unit_data_system")
            local breed = unit_data_ext:breed()
            if not breed or breed.breed_type == "player" or (breed.name and breed.name:find("hazard")) then
                goto next_unit
            end

            local breed_name = breed.name
            local priority = get_breed_priority(breed_name, unit)
            if priority > 0 then
                if POXBURSTER_BREEDS[breed_name] and not is_poxburster_safe_to_target(unit) then
                    goto next_unit
                end
                local pos = POSITION_LOOKUP[unit]
                local dist_sq = 0
                if player_pos and pos then
                    local diff = pos - player_pos
                    dist_sq = Vector3_dot(diff, diff)
                end
                n = n + 1
                local entry = reusable_enemies[n]
                if entry then
                    entry.unit = unit
                    entry.position = pos
                    entry.priority = priority
                    entry.breed_name = breed_name
                    entry.distance_sq = dist_sq
                else
                    reusable_enemies[n] = {
                        unit = unit,
                        position = pos,
                        breed_name = breed_name,
                        priority = priority,
                        distance_sq = dist_sq,
                    }
                end
            end

            ::next_unit::
        end
    end

    -- Clear stale trailing entries
    for i = n + 1, #reusable_enemies do
        reusable_enemies[i] = nil
    end

    if n > 1 then
        table_sort(reusable_enemies, priority_comparator)
    end

    return reusable_enemies, n
end

local function is_in_fov(enemy_unit, camera_pos, camera_forward, min_dot)
    local head_node = Unit_node(enemy_unit, "j_head")
    if not head_node then
        return false
    end
    local head_pos = Unit_world_position(enemy_unit, head_node)
    return Vector3_dot(camera_forward, Vector3_normalize(head_pos - camera_pos)) >= min_dot
end

local PI_2 = math.pi * 2
local SPREAD_DEFAULT_MIN_RATIO = 0.25
local SPREAD_DEFAULT_RANDOM_RATIO = 0.75
local SPREAD_DEFAULT_FIRST_SHOT_MIN_RATIO = 0.25
local SPREAD_DEFAULT_FIRST_SHOT_RANDOM_RATIO = 0.4
local SPREAD_DEFAULT_MAX_YAW_DELTA = 2
local SPREAD_DEFAULT_MAX_PITCH_DELTA = 3

-- Deterministically predict the spread offset that randomized_spread will apply
-- on the next shot.  Reads component data directly via read_component to avoid
-- accessing write-handle fields outside the spread system's update phase.
-- Returns the offset quaternion (pitch_rot * yaw_rot), or nil when no spread
-- template is active.
local function predict_spread_offset(player_unit)
    local weapon_ext = ScriptUnit_has_extension(player_unit, "weapon_system")
    if not weapon_ext then
        return nil
    end

    local spread_template = weapon_ext:spread_template()
    if not spread_template then
        return nil
    end

    local unit_data_ext = ScriptUnit_extension(player_unit, "unit_data_system")
    local movement_state = unit_data_ext:read_component("movement_state")
    local locomotion = unit_data_ext:read_component("locomotion")
    local inair_state = unit_data_ext:read_component("inair_state")
    local weapon_movement_state = WeaponMovementState.translate_movement_state_component(movement_state, locomotion, inair_state)
    local spread_settings = spread_template[weapon_movement_state]

    if not spread_settings then
        return nil
    end

    local rs = spread_settings.randomized_spread or {}
    local spread_control = unit_data_ext:read_component("spread_control")
    local spread = unit_data_ext:read_component("spread")
    local shooting_status = unit_data_ext:read_component("shooting_status")
    local suppression = unit_data_ext:read_component("suppression")

    local buff_ext = ScriptUnit_extension(player_unit, "buff_system")
    local spread_modifier = buff_ext:stat_buffs().spread_modifier or 1
    local current_pitch = spread.pitch * spread_modifier
    local current_yaw = spread.yaw * spread_modifier

    current_pitch, current_yaw = Suppression.apply_suppression_offsets_to_spread(suppression, current_pitch, current_yaw)

    local first_shot = shooting_status.num_shots == 0
    local min_ratio = first_shot and (rs.first_shot_min_ratio or SPREAD_DEFAULT_FIRST_SHOT_MIN_RATIO) or (rs.min_ratio or SPREAD_DEFAULT_MIN_RATIO)
    local random_ratio = first_shot and (rs.first_shot_random_ratio or SPREAD_DEFAULT_FIRST_SHOT_RANDOM_RATIO) or (rs.random_ratio or SPREAD_DEFAULT_RANDOM_RATIO)

    local seed = spread_control.seed
    local previous_yaw = spread_control.previous_yaw_offset
    local previous_pitch = spread_control.previous_pitch_offset

    local random_value
    seed, random_value = math.next_random(seed)
    local multiplier = min_ratio + random_ratio * random_value

    seed, random_value = math.next_random(seed)
    local roll = random_value * PI_2
    local yaw_offset = math_sin(roll) * current_yaw * multiplier
    local pitch_offset = math_cos(roll) * current_pitch * multiplier

    if first_shot then
        previous_yaw = yaw_offset
        previous_pitch = pitch_offset
    end

    -- Replicate _rotation_from_offset for yaw
    local yaw_diff = math_abs(previous_yaw - yaw_offset)
    local max_yaw_delta = rs.max_yaw_delta or SPREAD_DEFAULT_MAX_YAW_DELTA
    local yaw_t = yaw_diff <= 0.00001 and 1 or math_min(max_yaw_delta / yaw_diff, 1)
    local lerped_yaw = math.lerp(previous_yaw, yaw_offset, yaw_t)
    local yaw_rot = Quaternion(Vector3.up(), math.degrees_to_radians(lerped_yaw))

    -- Replicate _rotation_from_offset for pitch
    local pitch_diff = math_abs(previous_pitch - pitch_offset)
    local max_pitch_delta = rs.max_pitch_delta or SPREAD_DEFAULT_MAX_PITCH_DELTA
    local pitch_t = pitch_diff <= 0.00001 and 1 or math_min(max_pitch_delta / pitch_diff, 1)
    local lerped_pitch = math.lerp(previous_pitch, pitch_offset, pitch_t)
    local pitch_rot = Quaternion(Vector3.right(), math.degrees_to_radians(lerped_pitch))

    -- final = input * pitch * yaw  =>  offset = pitch * yaw
    return Quaternion.multiply(pitch_rot, yaw_rot)
end

-- Surgical perk (chance_based_on_aim_time) constants
local SURGICAL_MAX_STACKS = 10
local SURGICAL_CHANCE_PER_STACK = 0.10

-- Inlined P2C table from PseudoRandomDistribution — maps floor(chance*100) to
-- the per-attempt constant C used by the PRD algorithm.  Avoids requiring the
-- game module (its transitive NetworkConstants dependency fails under the mod
-- framework's require).
local PRD_P2C = {
    0.0001560416916765, 0.0006200876164356, 0.0013861777203907, 0.0024485554716477,
    0.0038016583035531, 0.0054401086148994, 0.0073587052890401, 0.009552415696806,
    0.0120163681507952, 0.0147458447810727, 0.0177362748045691, 0.0209832281625322,
    0.0244824095022856, 0.028229652481288,  0.0322209143730877, 0.0364522709562386,
    0.0409199116686026, 0.045620135010803,  0.0505493441851718, 0.0557040429497818,
    0.0610808317144988, 0.0666764036215081, 0.0724875433984468, 0.0785111206640039,
    0.084744091852317,  0.091183460913123,  0.097826380485467,  0.104670227374915,
    0.1117117582421034, 0.118949192725404,  0.1263793161208353, 0.1340008645349125,
    0.1418051956867528, 0.1498100879493791, 0.1579830981257471, 0.166328776806438,
    0.1749092435951354, 0.1836246523722508, 0.1924859579708838, 0.201547413607754,
    0.2109200313959977, 0.2203645774003486, 0.2298986763626535, 0.2395401522844584,
    0.2493069984401633, 0.2598723505886277, 0.270452936701194,  0.2810076352015464,
    0.2915522666427177, 0.302103025348742,  0.3126766393399556, 0.3232905471447631,
    0.3341199609425926, 0.3473699930849595, 0.3603978509331687, 0.3732168294719914,
    0.3858396117819544, 0.3982783321856844, 0.4105446351769761, 0.4226497308103743,
    0.434604447180966,  0.4464192805893383, 0.4581044439647123, 0.4696699141100894,
    0.4811254783372292, 0.4924807810774478, 0.5074626865671641, 0.5294117647058825,
    0.5507246376811594, 0.5714285714285715, 0.591549295774648,  0.6111111111111113,
    0.6301369863013697, 0.6486486486486487, 0.6666666666666666, 0.6842105263157897,
    0.7012987012987013, 0.717948717948718,  0.7341772151898737, 0.75,
    0.7654320987654323, 0.7804878048780489, 0.795180722891566,  0.8095238095238093,
    0.8235294117647058, 0.8372093023255812, 0.850574712643678,  0.8636363636363638,
    0.8764044943820226, 0.8888888888888891, 0.9010989010989011, 0.9130434782608697,
    0.9247311827956991, 0.9361702127659574, 0.9473684210526315, 0.9583333333333331,
    0.9690721649484535, 0.979591836734694,  0.98989898989899,
}

-- Pure re-implementation of PseudoRandomDistribution.flip_coin.
-- Returns is_crit (bool) only — we don't need the mutated state for prediction.
local function prd_would_crit(chance, state, seed)
    if chance >= 1 then return true end
    if chance <= 0 then return false end

    local c = PRD_P2C[math.floor(chance * 100)]
    if not c then return false end

    local math_next_random = math.next_random
    local new_seed, value = math_next_random(seed)

    if value < c then
        _, value = math_next_random(new_seed)
        return value < chance
    end

    local n = state or math.floor(chance / c)
    _, value = math_next_random(new_seed)
    return value < n * c
end


-- Estimates normal damage per hit against target_unit using
-- the current weapon's damage profile and the target's armor type.
-- Returns nil when the required data is unavailable.
local function _estimate_shot_damage(player_unit, target_unit)
    local unit_data_ext = ScriptUnit_extension(player_unit, "unit_data_system")
    if not unit_data_ext then return nil end

    local weapon_action_comp = unit_data_ext:read_component("weapon_action")
    if not weapon_action_comp then return nil end

    local weapon_template = WeaponTemplate.current_weapon_template(weapon_action_comp)
    if not weapon_template or not weapon_template.actions then return nil end

    -- Prefer the zoomed (ADS) shoot action; fall back to hip-fire
    local actions = weapon_template.actions
    local shoot_action = actions.action_shoot_zoomed or actions.action_shoot_hip
    if not shoot_action then return nil end

    local fire_config = shoot_action.fire_configuration
    if not fire_config then return nil end

    local hst = fire_config.hit_scan_template
    local damage_profile = hst and hst.damage and hst.damage.impact
                           and hst.damage.impact.damage_profile
    if not damage_profile or not damage_profile.targets then return nil end

    local power_level = (hst and hst.power_level) or PowerLevelSettings.default_power_level

    local breed = Breed.unit_breed_or_nil(target_unit)
    local armor_type = (breed and breed.armor_type) or "unarmored"

    local target_settings = damage_profile.targets[1] or damage_profile.targets.default_target
    if not target_settings then return nil end

    local lerp_values = DamageProfile.lerp_values(damage_profile, player_unit)

    local base_dmg = DamageCalculation.base_ui_damage(
        damage_profile, target_settings, power_level, nil, nil, lerp_values)
    if not base_dmg or base_dmg <= 0 then return nil end

    local adm_normal = DamageProfile.armor_damage_modifier(
        "attack", damage_profile, target_settings, lerp_values,
        armor_type, false, nil, false, 0)

    return base_dmg * adm_normal
end

-- Predicts whether the next shot will crit, and if not, whether waiting for
-- additional Surgical stacks (aim-time crit chance) can produce one.
--
-- Reads the critical_strike component's seed and prd_state, then simulates
-- the PRD flip_coin at increasing chance values (one per hypothetical
-- additional Surgical stack).
--
-- Returns:
--   "fire"          -- current chance already crits, or no Surgical / not
--                      aiming / waiting won't help; fire to advance the seed
--   "wait"          -- hold fire until the next Surgical stack produces a crit
local function predict_crit_wait(player_unit)
    local player = Managers.player:local_player(1)
    if not player or not player.player_unit then
        return "fire"
    end

    local unit_data_ext = ScriptUnit_extension(player_unit, "unit_data_system")
    local buff_ext = ScriptUnit_extension(player_unit, "buff_system")

    -- Early-out: guaranteed or prevented crits
    if buff_ext:has_keyword("guaranteed_critical_strike") or
       buff_ext:has_keyword("guaranteed_ranged_critical_strike") then
        return "fire"
    end
    if buff_ext:has_keyword("prevent_critical_strike") then
        return "fire"
    end

    local critical_strike_comp = unit_data_ext:read_component("critical_strike")
    local seed = critical_strike_comp.seed
    local prd_state = critical_strike_comp.prd_state

    local weapon_ext = ScriptUnit_has_extension(player_unit, "weapon_system")
    if not weapon_ext then
        return "fire"
    end
    local weapon_handling_template = weapon_ext:weapon_handling_template() or {}

    -- Current crit chance (all active buffs including current Surgical stacks)
    local current_chance = CriticalStrike.chance(player, weapon_handling_template, true, false, false)
    local rounded = math.round_with_precision(current_chance, 2)

    -- Check if the next shot already crits at current chance
    if prd_would_crit(rounded, prd_state, seed) then
        return "fire"
    end

    -- Must be aiming to gain stacks
    local alternate_fire = unit_data_ext:read_component("alternate_fire")
    if not alternate_fire or not alternate_fire.is_active then
        return "fire"
    end

    -- Read current Surgical stack count directly from the buff.
    -- No buff found means the perk isn't equipped — fire immediately.
    local current_stacks = nil
    local buffs = buff_ext:buffs()
    for i = 1, #buffs do
        local buff = buffs[i]
        local name = buff:template().name
        if name and name:find("crit_chance_based_on_aim_time", 1, true) then
            current_stacks = buff:visual_stack_count()
            break
        end
    end

    if current_stacks == nil then
        return "fire"
    end

    -- Simulate each additional stack to see if any produces a crit
    for extra = 1, SURGICAL_MAX_STACKS - current_stacks do
        local test_chance = math.clamp(current_chance + extra * SURGICAL_CHANCE_PER_STACK, 0, 1)
        if prd_would_crit(math.round_with_precision(test_chance, 2), prd_state, seed) then
            -- Need extra more stacks; check if waiting is damage-efficient
            if last_aim_unit then
                local health_ext = ScriptUnit_has_extension(last_aim_unit, "health_system")
                if health_ext and health_ext:is_alive() then
                    local hp = health_ext:current_health()
                    local n_dmg = _estimate_shot_damage(player_unit, last_aim_unit)
                    if n_dmg and n_dmg > 0 then
                        local breed = Breed.unit_breed_or_nil(last_aim_unit)
                        local armor_type = breed and breed.armor_type
                        -- For carapace (super_armor, base ADM=0→crit floors at 0.25) and flak
                        -- (armored, base ADM=0.5, crit adds finesse ~1.5x), crits are valuable
                        -- enough that we only skip the wait if a single normal shot already kills.
                        local bypass_shots = (armor_type == "super_armor" or armor_type == "armored") and 1 or 2
                        if math.ceil(hp / n_dmg) <= bypass_shots then
                            return "fire"
                        end
                    end
                end
            end

            return "wait"
        end
    end

    -- No reachable stack count produces a crit; fire to advance the seed
    return "fire"
end

-- Returns the world-space aim position for a zone descriptor, or nil if the
-- actor/node doesn't exist on this unit. Actor zones with a top_bias field
-- offset upward by (top_bias * z_half_extent) from the AABB center, placing
-- the aim point in the visible upper portion of the collision volume.
local function get_aim_position(unit, zone)
    if zone.type == "actor" then
        local actor = Unit.actor(unit, zone.name)
        if not actor then return nil end
        if zone.top_bias and Actor.is_dynamic(actor) then
            local center, half = Actor_world_bounds(actor)
            return Vector3(center.x, center.y, center.z + half.z * zone.top_bias)
        end
        return Actor.is_dynamic(actor) and Actor.center_of_mass(actor) or Actor.position(actor)
    else
        local node = Unit_node(unit, zone.name)
        if not node then return nil end
        return Unit_world_position(unit, node)
    end
end

-- Classifies a single raycast hit actor for LOS / enemy-detection purposes.
-- Handles the universal pre-checks shared by can_see_aim_target and
-- is_reticle_on_enemy so neither caller duplicates the logic.
--   enemy_unit   � if non-nil, only a hit on this unit counts as "hit"; any
--                  other solid unit returns "blocked".
--   target_actor � only meaningful when enemy_unit is non-nil; when set the
--                  hit actor must also match exactly to return "hit".
-- Returns "skip", "blocked", or "hit".
local function classify_los_hit(actor, player_unit, enemy_unit, target_actor)
    if not actor then return "skip" end

    local hit_unit = Actor_unit(actor)
    if not hit_unit then
        return "blocked"
    end
    local zone_name = HitZone.get_name(hit_unit, actor)

    if zone_name == HitZone.hit_zone_names.afro then
        return "skip"
    end
    if zone_name == HitZone.hit_zone_names.shield or
       zone_name == HitZone.hit_zone_names.captain_void_shield then
        return "blocked"
    end
    if hit_unit == player_unit then
        return "skip"
    end
    if Health.is_ragdolled(hit_unit) then
        return "skip"
    end

    if enemy_unit then
        if hit_unit ~= enemy_unit then
            return "blocked"
        end
        if target_actor and actor ~= target_actor then
            return "blocked"
        end
    end

    return "hit"
end

-- Iterates the ordered zones list and returns (true, zone) for the first zone
-- with an unobstructed line of sight from shooting_pos, or (false, nil).
local function can_see_aim_target(enemy_unit, player, shooting_pos, zones)
    local physics_world = World_physics_world(Application_main_world())
    for _, zone in ipairs(zones) do
        local aim_pos = get_aim_position(enemy_unit, zone)
        if not aim_pos then
            goto next_zone
        end

        -- For actor zones pre-fetch the exact actor so we can confirm LOS by
        -- actor identity. This avoids relying on hit_zone_names enums which may
        -- not contain breed-specific zone names (e.g. BoN "tongue").
        local target_actor = zone.type == "actor" and Unit.actor(enemy_unit, zone.name) or nil

        do
            local dir = aim_pos - shooting_pos
            local dist = Vector3_length(dir)
            dir = Vector3_normalize(dir)

            local hits = PhysicsWorld_raycast(physics_world, shooting_pos, dir, dist, "all", "collision_filter", "filter_player_character_shooting_raycast")

            if not hits then
                return true, zone
            end

            local blocked = false
            for i = 1, #hits do
                local result = classify_los_hit(hits[i][4], player.player_unit, enemy_unit, target_actor)
                if result == "hit" then
                    return true, zone
                elseif result == "blocked" then
                    blocked = true
                    break
                end
            end

            if not blocked then
                return true, zone
            end
        end

        ::next_zone::
    end
    return false, nil
end

local function look_at_aim_target(enemy_unit, zone, player, shooting_pos, player_unit)
    local aim_pos = get_aim_position(enemy_unit, zone)
    if not aim_pos then return end

    local dir = Vector3_normalize(aim_pos - shooting_pos)
    local base_pitch = math_asin(dir.z)
    local base_yaw = math_atan2(dir.y, dir.x) - HALF_PI

    local unit_data_ext = ScriptUnit_extension(player_unit, "unit_data_system")
    local recoil_component = unit_data_ext:read_component("recoil")
    local sway_component = unit_data_ext:read_component("sway")

    if cached_settings.enable_spread_compensation then
        local spread_offset = predict_spread_offset(player_unit)
        if spread_offset then
            local desired_rot = Quaternion.look(dir, Vector3.up())
            local compensated_rot = Quaternion.multiply(desired_rot, Quaternion.inverse(spread_offset))
            local comp_fwd = Quaternion_forward(compensated_rot)
            base_pitch = math_asin(comp_fwd.z)
            base_yaw = math_atan2(comp_fwd.y, comp_fwd.x) - HALF_PI
        end
    end

    player:set_orientation(base_yaw - recoil_component.yaw_offset - sway_component.offset_x, base_pitch - recoil_component.pitch_offset - sway_component.offset_y, 0)
end

local function get_fire_interval()
    local current_time = Managers.time:time("main") or 0

    local player = Managers.player:local_player(1)
    if not player then
        return 0.1, current_time
    end

    local peer_id = player:peer_id()
    if not peer_id then
        return 0.1, current_time
    end

    local rtt = Network.ping(peer_id)
    if not rtt or rtt == 0 then
        return 0.1, current_time
    end

    return rtt * 2, current_time
end

local function are_teammates_dead()
    local local_player = Managers.player:local_player(1)
    if not local_player or not local_player.player_unit then
        return false
    end

    local human_players = Managers.player:human_players()
    local game_session_manager = Managers.state.game_session
    for _, player in pairs(human_players) do
        if player ~= local_player then
            local peer_id = player:peer_id()
            if game_session_manager:connected_to_client(peer_id) and not player:unit_is_alive() then
                return true
            end
            if player.player_unit and ScriptUnit_has_extension(player.player_unit, "unit_data_system") then
                local unit_data_extension = ScriptUnit_extension(player.player_unit, "unit_data_system")
                local character_state_component = unit_data_extension:read_component("character_state")
                if character_state_component and character_state_component.state_name == "hogtied" then
                    return true
                end
            end
        end
    end

    return false
end

local function auto_aim_priority_targets(player_unit)
    local player = Managers.player:local_player(1)
    if not player or not player.player_unit then
        has_target = false
        return
    end

    if cached_settings.disable_when_teammates_are_dead and are_teammates_dead() then
        has_target = false
        return
    end

    local unit_data_ext = ScriptUnit_extension(player_unit, "unit_data_system")
    local first_person_component = unit_data_ext:read_component("first_person")
    local shooting_pos = first_person_component.position

    local camera_forward, min_dot
    local fov_check_enabled = cached_settings.enable_fov_check
    if fov_check_enabled then
        camera_forward = Quaternion_forward(first_person_component.rotation)
        min_dot = math_cos(math_rad(cached_settings.fov_angle * 0.5))
    end

    local enemies, enemy_count = get_all_enemies()
    for i = 1, enemy_count do
        local enemy = enemies[i]
        if not fov_check_enabled or is_in_fov(enemy.unit, shooting_pos, camera_forward, min_dot) then
            local zones = (enemy.breed_name and BREED_AIM_ZONES[enemy.breed_name]) or DEFAULT_AIM_ZONES

            local visible, resolved_zone = can_see_aim_target(enemy.unit, player, shooting_pos, zones)
            local has_lock = last_aim_unit == enemy.unit and last_aim_zone ~= nil

            if visible then
                -- Determine priority indices (lower index = higher priority in zones list).
                local new_idx = #zones + 1
                for k = 1, #zones do
                    if zones[k] == resolved_zone then new_idx = k; break end
                end
                local lock_idx = #zones + 1
                if has_lock then
                    for k = 1, #zones do
                        if zones[k] == last_aim_zone then lock_idx = k; break end
                    end
                end

                if has_lock and new_idx > lock_idx and last_aim_zone_blocked_frames < ZONE_GRACE_FRAMES then
                    -- Only a lower-priority fallback is visible; hold the locked zone
                    -- to avoid downgrading due to transient occlusion (e.g. blob dip).
                    last_aim_zone_blocked_frames = last_aim_zone_blocked_frames + 1
                    has_target = true
                    look_at_aim_target(enemy.unit, last_aim_zone, player, shooting_pos, player_unit)
                    return
                end
                -- Accept resolved_zone: same/higher-priority zone, grace expired, or no lock.
                last_aim_unit = enemy.unit
                last_aim_zone = resolved_zone
                last_aim_zone_blocked_frames = 0
                has_target = true
                look_at_aim_target(enemy.unit, resolved_zone, player, shooting_pos, player_unit)
                return
            elseif has_lock and last_aim_zone_blocked_frames < ZONE_GRACE_FRAMES then
                -- Nothing visible at all; hold locked zone during grace.
                last_aim_zone_blocked_frames = last_aim_zone_blocked_frames + 1
                has_target = true
                look_at_aim_target(enemy.unit, last_aim_zone, player, shooting_pos, player_unit)
                return
            end
        end
    end

    last_aim_unit = nil
    last_aim_zone = nil
    last_aim_zone_blocked_frames = 0
    has_target = false
end

local function get_weapon_fire_mode(weapon_template, is_ads)
    if not weapon_template or not weapon_template.actions then
        return "full_auto"
    end

    local shoot_action
    if is_ads then
        shoot_action = weapon_template.actions.action_shoot_zoomed or
                       weapon_template.actions.action_zoom_shoot_charged or
                       weapon_template.actions.action_shoot_zoomed_start
    else
        shoot_action = weapon_template.actions.action_shoot_hip or
                       weapon_template.actions.action_shoot_hip_charged or
                       weapon_template.actions.action_shoot_hip_start
    end

    if not shoot_action then
        return "full_auto"
    end

    if shoot_action.kind == "charge_ammo" then
        return "charge"
    end

    local action_inputs = weapon_template.action_inputs
    if action_inputs then
        local input_check = is_ads and action_inputs.zoom_shoot or action_inputs.shoot_pressed
        if input_check and input_check.input_sequence then
            for _, input_seq in ipairs(input_check.input_sequence) do
                if input_seq.input and (input_seq.input == "action_one_pressed" or input_seq.input:find("_pressed")) then
                    return "semi_auto"
                end
            end
        end
    end

    return "full_auto"
end

local function get_current_weapon_info()
    local player = Managers.player:local_player_safe(1)
    if not player or not player.player_unit then
        return nil, "full_auto", false
    end

    local unit_data_ext = ScriptUnit_extension(player.player_unit, "unit_data_system")
    if not unit_data_ext then
        return nil, "full_auto", false
    end

    local weapon_action_component = unit_data_ext:read_component("weapon_action")
    if not weapon_action_component then
        return nil, "full_auto", false
    end

    local alternate_fire_component = unit_data_ext:read_component("alternate_fire")
    local is_ads = alternate_fire_component and alternate_fire_component.is_active or false

    local weapon_template = WeaponTemplate.current_weapon_template(weapon_action_component)

    if not weapon_template then
        return nil, "full_auto", is_ads
    end

    return weapon_template, get_weapon_fire_mode(weapon_template, is_ads), is_ads
end

local function is_main_weapon_equipped()
    local player = Managers.player:local_player_safe(1)
    if not player or not player.player_unit then
        return false
    end

    local unit_data_ext = ScriptUnit_extension(player.player_unit, "unit_data_system")
    if not unit_data_ext then
        return false
    end

    local inventory_component = unit_data_ext:read_component("inventory")
    if not inventory_component then
        return false
    end

    -- slot_secondary is the main weapon (ranged), slot_primary is the melee weapon
    local wielded_slot = inventory_component.wielded_slot
    return wielded_slot == "slot_secondary"
end

local function is_melee_weapon_equipped()
    local player = Managers.player:local_player_safe(1)
    if not player or not player.player_unit then return false end
    local unit_data_ext = ScriptUnit_extension(player.player_unit, "unit_data_system")
    if not unit_data_ext then return false end
    local inventory_component = unit_data_ext:read_component("inventory")
    if not inventory_component then return false end
    return inventory_component.wielded_slot == "slot_primary"
end

local function is_reticle_on_enemy()
    local player = Managers.player:local_player(1)
    if not player or not player.player_unit then
        return false
    end

    local unit_data_ext = ScriptUnit_extension(player.player_unit, "unit_data_system")
    local first_person_component = unit_data_ext:read_component("first_person")
    local shooting_pos = first_person_component.position
    local shooting_rot = first_person_component.rotation
    local action_component = unit_data_ext:read_component("weapon_action")

    local ray_rotation = shooting_rot
    local max_distance = 150

    if action_component then
        local weapon_template = WeaponTemplate.current_weapon_template(action_component)
        if weapon_template then
            -- Apply recoil and sway like action_shoot.lua does
            local recoil_component = unit_data_ext:read_component("recoil")
            local sway_component = unit_data_ext:read_component("sway")
            local movement_state_component = unit_data_ext:read_component("movement_state")
            local locomotion_component = unit_data_ext:read_component("locomotion")
            local inair_state_component = unit_data_ext:read_component("inair_state")

            if recoil_component and sway_component and movement_state_component then
                local weapon_extension = ScriptUnit_extension(player.player_unit, "weapon_system")
                if weapon_extension then
                    local recoil_template = weapon_extension:recoil_template()
                    local sway_template = weapon_extension:sway_template()

                    if recoil_template then
                        ray_rotation = Recoil.apply_weapon_recoil_rotation(recoil_template, recoil_component, movement_state_component, locomotion_component, inair_state_component, ray_rotation)
                    end

                    if sway_template then
                        ray_rotation = Sway.apply_sway_rotation(sway_template, sway_component, ray_rotation)
                    end
                end
            end

            if weapon_template.hit_scan_template and weapon_template.hit_scan_template.range then
                max_distance = weapon_template.hit_scan_template.range
            end
        end
    end

    local direction = Quaternion_forward(ray_rotation)

    local physics_world = World_physics_world(Application_main_world())
    local hits = PhysicsWorld_raycast(physics_world, shooting_pos, direction, max_distance, "all", "collision_filter", "filter_player_character_shooting_raycast")

    if not hits or #hits == 0 then
        return false
    end

    local weakspot_only = cached_settings.triggerbot_weakspot_only
    local respect_priority = cached_settings.triggerbot_respect_priority
    -- Tracks the first enemy unit the ray intersects (used by weakspot_only to prevent
    -- "looking through" one enemy's body to find a weakspot on the unit behind it).
    local weakspot_first_unit = nil

    for i = 1, #hits do
        local hit = hits[i]
        if hit then
            local actor = hit[4]
            local result = classify_los_hit(actor, player.player_unit, nil, nil)

            if result == "blocked" then
                return false
            elseif result == "hit" then
                local hit_unit = Actor_unit(actor)
                if not ScriptUnit_has_extension(hit_unit, "health_system") then
                    -- Solid non-health unit (prop, env piece) blocks the ray.
                    return false
                end
                local health_ext = ScriptUnit_extension(hit_unit, "health_system")
                if not health_ext:is_alive() then
                    -- Dead body (not yet ragdolled) blocks the ray.
                    return false
                end
                local breed = Breed.unit_breed_or_nil(hit_unit)
                if not breed or Breed.is_player(breed) or breed.name:find("hazard") then
                    -- Friendly or non-targetable unit blocks the ray.
                    return false
                end

                if weakspot_only then
                    local zone_name = HitZone.get_name(hit_unit, actor)
                    if zone_name ~= HitZone.hit_zone_names.head and zone_name ~= HitZone.hit_zone_names.weakspot then
                        -- Wrong zone on a valid enemy: the head actor may be a
                        -- separate hit slightly further along the same unit.
                        -- If a different enemy unit is in the way, it blocks the shot.
                        if weakspot_first_unit and hit_unit ~= weakspot_first_unit then
                            return false
                        end
                        weakspot_first_unit = hit_unit
                        goto continue_hit_loop
                    end
                    -- Correct zone, but reject if it belongs to a different enemy than
                    -- the first non-weakspot unit encountered on this ray.
                    if weakspot_first_unit and hit_unit ~= weakspot_first_unit then
                        return false
                    end
                end

                local breed_name = breed.name
                if respect_priority and get_breed_priority(breed_name, hit_unit) == 0 then
                    -- Low-priority enemy physically blocks the ray.
                    return false
                end
                if DAEMONHOST_BREEDS[breed_name] and get_daemonhost_priority(hit_unit, 1) == 0 then
                    return false
                end
                if POXBURSTER_BREEDS[breed_name] and not is_poxburster_safe_to_target(hit_unit) then
                    return false
                end

                return true
            end
        end

        ::continue_hit_loop::
    end

    return false
end

mod.toggle_aim = function(is_pressed)
    aim_button_pressed = is_pressed
end

mod.toggle_triggerbot = function(is_pressed)
    triggerbot_pressed = is_pressed
end

-- Auto guard state: true when a nearby enemy is executing a power attack
local auto_guard_blocking = false
-- True when an enemy is within the player's weapon reach
local melee_enemy_in_range = false
-- Melee auto-attack pulse: simulate press→release so the game sees a rising edge each cycle
local melee_press_last_t = 0
local MELEE_PRESS_CYCLE    = 0.35  -- seconds between press pulses
local MELEE_PRESS_DURATION = 0.05  -- seconds to hold the press true

local DEFAULT_MELEE_REACH = 2.5  -- matches bot DEFAULT_MAXIMAL_MELEE_RANGE
local DEFAULT_ENEMY_RADIUS = 0.5 -- matches bot DEFAULT_ENEMY_HITBOX_RADIUS_APPROXIMATION
-- Enemies must be within this dot-product of the camera forward to count as
-- "in range" for auto-attack.  0.0 = front hemisphere (180° total cone).
local MELEE_FOV_DOT = 0.0

local function get_melee_reach(player_unit)
    local unit_data_ext = ScriptUnit_extension(player_unit, "unit_data_system")
    if not unit_data_ext then return DEFAULT_MELEE_REACH end
    local weapon_action_component = unit_data_ext:read_component("weapon_action")
    if not weapon_action_component then return DEFAULT_MELEE_REACH end
    local weapon_template = WeaponTemplate.current_weapon_template(weapon_action_component)
    if not weapon_template then return DEFAULT_MELEE_REACH end
    -- weapon_box[3] is the OBB z-half-extent used for sweep collision geometry, not
    -- the reach from player to target. The bot reads attack_meta_data.max_range instead
    -- (bt_bot_melee_action.lua:_calculate_melee_range). Player melee weapons never define
    -- attack_meta_data, so they always fall through to DEFAULT_MELEE_REACH (2.5 m),
    -- matching DEFAULT_MAXIMAL_MELEE_RANGE in bt_bot_melee_action.lua.
    local attack_meta_data = weapon_template.attack_meta_data
    if attack_meta_data then
        local light = attack_meta_data.light_attack
        if light and light.max_range then
            return light.max_range
        end
    end
    return DEFAULT_MELEE_REACH
end

local function check_enemy_in_melee_range(player_unit)
    local player_pos = POSITION_LOOKUP[player_unit]
    if not player_pos then return false end

    local reach = get_melee_reach(player_unit)

    -- Get camera forward once for the FOV check below.
    local unit_data_ext = ScriptUnit_extension(player_unit, "unit_data_system")
    local forward = unit_data_ext and
        Quaternion_forward(unit_data_ext:read_component("first_person").rotation)

    local extension_manager = Managers.state and Managers.state.extension
    if not extension_manager then return false end

    local entities = extension_manager:get_entities("MinionHuskLocomotionExtension")
    if not next(entities) then
        entities = extension_manager:get_entities("MinionLocomotionExtension")
        if not next(entities) then return false end
    end

    for unit, _ in pairs(entities) do
        local health_ext = ScriptUnit_has_extension(unit, "health_system")
        if not (health_ext and health_ext:is_alive()) then goto continue_range end

        local enemy_pos = POSITION_LOOKUP[unit]
        if not enemy_pos then goto continue_range end

        local unit_data_ext = ScriptUnit_has_extension(unit, "unit_data_system")
        local enemy_radius = DEFAULT_ENEMY_RADIUS
        if unit_data_ext then
            local breed = unit_data_ext:breed()
            if breed and breed.bot_hitbox_radius_approximation then
                enemy_radius = breed.bot_hitbox_radius_approximation
            end
        end

        local diff = enemy_pos - player_pos
        local dist_sq = Vector3_dot(diff, diff)
        if dist_sq <= (reach + enemy_radius) ^ 2 then
            -- Reject enemies outside the front hemisphere so we don't swing at
            -- things directly behind the player.
            if forward and Vector3_dot(forward, Vector3_normalize(diff)) >= MELEE_FOV_DOT then
                return true
            end
        end

        ::continue_range::
    end

    return false
end

-- Per-unit animation attack window tracking.
local unit_attack_end_times   = {}  -- unit -> expiry time (main clock seconds)
local unit_attack_is_heavy    = {}  -- unit -> true when event was a moving/running swing
local unit_attack_start_times = {}  -- unit -> time the anim event first fired
local ATTACK_ANIM_WINDOW = 3.0   -- seconds; exceeds the longest enemy attack damage timing
-- Guard window: Layer A fires when animation_get_time[1] (elapsed in the charge state)
-- is in [GUARD_START_T, GUARD_END_T].  The attack event fires ~218 ms into the charge
-- state; the hit frame arrives ~1.2-1.3 s after the event = ~1.42-1.52 s from state entry.
local GUARD_START_T = 1.4  -- seconds from state entry → guard raises
local GUARD_END_T   = 1.5  -- seconds from state entry → guard drops

-- unit -> breed name; breed name -> {event_index -> event_name}
local _unit_breed_name        = {}
local _breed_attack_idx_cache = {}

-- Per-breed attack-state signatures: maps state node index → true.
-- Pre-seeded for known breeds; new indices learned at runtime via _on_attack_anim_event.
local _breed_attack_state_sigs = {}

-- Charge-state indices for chaos_newly_infected; states 103/108 excluded (fire during
-- locomotion transitions → false positives).  attack_run_01 learned at runtime.
_breed_attack_state_sigs["chaos_newly_infected"] = { [93]=true, [94]=true, [98]=true }

-- Pre-allocated scratch tables for GC-efficient per-frame state / time polling.
local _anim_state_scratch = {}
local _anim_time_scratch  = {}

local function check_power_attack_incoming(player_unit)
    local player_pos = POSITION_LOOKUP[player_unit]
    if not player_pos then return false end

    -- When the player is dodging, Dodge.is_dodging() returns true for melee attacks
    -- and the game's reach/cone shrinkage causes the incoming attack to miss.
    -- Raising the guard is unnecessary and suppresses the counter-swing pulse.
    if Dodge.is_dodging(player_unit, "melee") then
        return false
    end

    local range = cached_settings.auto_guard_range or 4
    local range_sq = range * range
    local heavy_only = cached_settings.auto_guard_heavy_only
    local now = Managers.time:time("main") or 0

    local extension_manager = Managers.state and Managers.state.extension
    if not extension_manager then return false end

    local entities = extension_manager:get_entities("MinionHuskLocomotionExtension")
    if not next(entities) then
        entities = extension_manager:get_entities("MinionLocomotionExtension")
        if not next(entities) then return false end
    end

    for unit, _ in pairs(entities) do
        local health_ext = ScriptUnit_has_extension(unit, "health_system")
        if not (health_ext and health_ext:is_alive()) then goto continue_guard end

        local enemy_pos = POSITION_LOOKUP[unit]
        if not enemy_pos then goto continue_guard end

        local diff = enemy_pos - player_pos
        if Vector3_dot(diff, diff) > range_sq then goto continue_guard end

        -- Expire stale event-based windows.
        local end_t = unit_attack_end_times[unit]
        if end_t and now >= end_t then
            unit_attack_end_times[unit]   = nil
            unit_attack_is_heavy[unit]    = nil
            unit_attack_start_times[unit] = nil
            end_t = nil
        end

        local breed = _unit_breed_name[unit]

        -- Primary polling: state machine node index.
        -- Fires guard when animation_get_time[1] is in [GUARD_START_T, GUARD_END_T].
        local sigs = breed and _breed_attack_state_sigs[breed]
        if sigs then
            local ok_s, s_tbl, s_n = pcall(Unit.animation_get_state, unit, _anim_state_scratch)
            if ok_s and s_n and s_n > 0 and sigs[s_tbl[1]] then
                -- Arm end_t/is_heavy for stale-window cleanup and heavy_only filtering.
                if not end_t then
                    unit_attack_start_times[unit] = now
                    unit_attack_end_times[unit]   = now + ATTACK_ANIM_WINDOW
                    unit_attack_is_heavy[unit]    = true
                    end_t = unit_attack_end_times[unit]
                end
                if heavy_only and not unit_attack_is_heavy[unit] then
                    goto continue_guard
                end
                local ok_t, t_tbl, t_n = pcall(Unit.animation_get_time, unit, _anim_time_scratch)
                if ok_t and t_n and t_n > 0 then
                    local t = t_tbl[1]
                    if t >= GUARD_START_T and t <= GUARD_END_T then
                        return true
                    end
                end
                -- time unreadable or outside guard window
            end
        end

        -- Fallback: wall-clock elapsed from the attack event timestamp.
        -- Only used for breeds with no state-sig table.  When sigs exist, the attack
        -- event fires partway into the charge state (measured ~218 ms in for groaners),
        -- so start_times lags state entry by that offset.  Layer A (animation_get_time)
        -- fires at state_entry+GUARD_START_T; Layer B would fire ~218 ms later, producing
        -- a spurious second guard window after the hit.  Skip it when Layer A is available.
        if end_t and not sigs then
            if not heavy_only or unit_attack_is_heavy[unit] then
                local elapsed = now - (unit_attack_start_times[unit] or now)
                if elapsed >= GUARD_START_T and elapsed < GUARD_END_T then
                    return true
                end
            end
        end

        ::continue_guard::
    end

    return false
end

local _get = function(func, self, action_name)
    if self.type ~= "Ingame" then
        return func(self, action_name)
    end

    -- Standalone auto-guard (always-on, independent of keybind).
    -- Injects action_two_hold (the raw InputService input that the action_input_parser
    -- maps to the "block" action input via the weapon template's action_inputs table).
    -- Only applies when a melee weapon is equipped; ranged weapons use action_two_hold
    -- for ADS and must not have it forced true.
    if cached_settings.enable_auto_guard and auto_guard_blocking and is_melee_weapon_equipped() then
        if action_name == "action_two_hold" then
            return true
        end
    end

    if not cached_settings.enable_triggerbot then
        return func(self, action_name)
    end

    local keybind = cached_settings.triggerbot_keybind
    local keybind_active = not next(keybind) or triggerbot_pressed

    -- Melee auto-fight: keybind held + melee weapon equipped
    if keybind_active and is_melee_weapon_equipped() then
        if auto_guard_blocking then
            -- Power attack incoming: inject action_two_hold (the raw input the
            -- action_input_parser maps to the "block" weapon action).
            if action_name == "action_two_hold" then return true end
        else
            -- No threat: pulse action_one_hold briefly to simulate a quick tap (light attack),
            -- but only when an enemy is actually within weapon reach.
            -- Returning false during off-phase suppresses hold so it never charges to heavy.
            if action_name == "action_one_hold" then
                if not melee_enemy_in_range then
                    return false
                end
                local now = Managers.time:time("main")
                local elapsed = now - melee_press_last_t
                local inject
                if elapsed >= MELEE_PRESS_CYCLE then
                    melee_press_last_t = now
                    inject = true
                else
                    inject = elapsed < MELEE_PRESS_DURATION
                end
                return inject
            end
        end
        return func(self, action_name)
    end

    -- Ranged triggerbot path: only intercept attack inputs
    if action_name ~= "action_one_hold" and action_name ~= "action_one_pressed" then
        return func(self, action_name)
    end

    if not keybind_active then
        return func(self, action_name)
    end

    if cached_settings.require_main_weapon and not is_main_weapon_equipped() then
        return func(self, action_name)
    end

    local can_fire = cached_settings.triggerbot_use_raycast and is_reticle_on_enemy() or not cached_settings.triggerbot_use_raycast and has_target
    if not can_fire then
        return func(self, action_name)
    end

    -- Surgical crit-wait: suppress fire if waiting for more stacks will crit
    if cached_settings.wait_for_crits then
        local player_unit = Managers.player:local_player(1)
        player_unit = player_unit and player_unit.player_unit
        if player_unit then
            local crit_action = predict_crit_wait(player_unit)
            if crit_action == "wait" then
                return false
            end
        end
    end

    local weapon_template, fire_mode = get_current_weapon_info()
    if action_name == "action_one_hold" and (fire_mode == "charge" or fire_mode == "full_auto") then
        return true
    end

    if action_name == "action_one_pressed" and fire_mode == "semi_auto" then
        -- For semi-auto weapons, fire once per latency cycle to avoid sending too many fire events
        local fire_interval, current_time = get_fire_interval()
        if current_time - last_semi_auto_fire_time >= fire_interval then
            last_semi_auto_fire_time = current_time
            return true
        end
        return false
    end

    return func(self, action_name)
end

local function _on_attack_anim_event(unit, event_name, now)
    -- Reset per-attack; combo attacks each get a fresh window.
    -- Duplicate fires (host + listen-server same frame) use the same `now`, so safe.
    unit_attack_start_times[unit] = now
    unit_attack_end_times[unit] = now + ATTACK_ANIM_WINDOW
    unit_attack_is_heavy[unit]  = event_name:sub(1, 12) == "attack_move_" or event_name:sub(1, 11) == "attack_run_"

    local breed = _unit_breed_name[unit]
    if not breed then return end

    -- Snapshot the charge-state index; add to the sig table if unseen.
    local ok_s, s_tbl, s_n = pcall(Unit.animation_get_state, unit, _anim_state_scratch)
    if ok_s and s_n and s_n > 0 and s_tbl[1] then
        local sigs = _breed_attack_state_sigs[breed]
        if not sigs then sigs = {} ; _breed_attack_state_sigs[breed] = sigs end
        if not sigs[s_tbl[1]] then
            sigs[s_tbl[1]] = true
            mod:info("[gambits][guard] new state sig: breed=%s event=%s heavy=%s state[1]=%s",
                breed, event_name, tostring(unit_attack_is_heavy[unit]), tostring(s_tbl[1]))
        end
    end
end

-- Attack event names to probe at unit spawn. index_by_animation_event returns the
-- same numeric index that rpc_minion_anim_event carries, so pre-populating the cache
-- here makes the client path work without waiting for the server to fire any event.
local KNOWN_ATTACK_EVENTS = {
    "attack_01", "attack_02", "attack_03", "attack_04", "attack_05",
    "attack_combo_standing_06",
    "attack_move_01", "attack_move_02", "attack_move_03", "attack_move_04",
    "attack_run_01",  "attack_run_02",  "attack_run_03",
}

-- Populate unit->breed map and attack-index cache on spawn (runs on both server and client).
mod:hook_safe("MinionAnimationExtension", "init", function(self, extension_init_context, unit, extension_init_data, ...)
    local breed = extension_init_data and extension_init_data.breed
    if not breed or not breed.name then return end
    _unit_breed_name[unit] = breed.name
    local cache = _breed_attack_idx_cache[breed.name]
    if not cache then
        cache = {}
        _breed_attack_idx_cache[breed.name] = cache
    end
    for _, ev in ipairs(KNOWN_ATTACK_EVENTS) do
        local ok_h, has = pcall(Unit.has_animation_event, unit, ev)
        if ok_h and has then
            local ok_i, idx = pcall(Unit.index_by_animation_event, unit, ev)
            if ok_i and idx and not cache[idx] then
                cache[idx] = ev
            end
        end
    end
end)

-- SERVER / HOST path: event name is available directly from the extension method.
mod:hook_safe("MinionAnimationExtension", "anim_event", function(self, event_name, ...)
    if not event_name or event_name:sub(1, 7) ~= "attack_" then return end
    local unit = self._unit
    if not unit then return end
    _on_attack_anim_event(unit, event_name, (Managers.time and Managers.time:time("main")) or 0)
end)

-- Build a breed-level {event_index -> event_name} cache by intercepting Unit.animation_event.
-- On a listen server the server calls Unit.animation_event(unit, name) before sending the RPC,
-- so by the time rpc_minion_anim_event fires on the local client the cache is already populated.
local _orig_unit_anim_event = Unit.animation_event
Unit.animation_event = function(unit, event_name)
    local idx = _orig_unit_anim_event(unit, event_name)
    if event_name and event_name:sub(1, 7) == "attack_" and unit then
        local breed_name = _unit_breed_name[unit]
        if breed_name then
            local cache = _breed_attack_idx_cache[breed_name]
            if not cache then
                cache = {}
                _breed_attack_idx_cache[breed_name] = cache
            end
            if not cache[idx] then
                cache[idx] = event_name
            end
        end
    end
    return idx
end

-- CLIENT path: event arrives as an index; resolve via the breed cache.
mod:hook_safe("AnimationSystem", "rpc_minion_anim_event", function(self, channel_id, unit_id, event_index)
    local unit_spawner = Managers.state and Managers.state.unit_spawner
    if not unit_spawner then return end
    local unit = unit_spawner:unit(unit_id)
    if not unit then return end

    local breed_name = _unit_breed_name[unit]
    local cache = breed_name and _breed_attack_idx_cache[breed_name]
    local event_name = cache and cache[event_index]

    if not event_name or event_name:sub(1, 7) ~= "attack_" then return end
    _on_attack_anim_event(unit, event_name, (Managers.time and Managers.time:time("main")) or 0)
end)

mod:hook("InputService", "_get", _get)
mod:hook("InputService", "_get_simulate", _get)

mod:hook_safe("PlayerUnitFirstPersonExtension", "fixed_update", function(self, unit, dt, t, frame)
    local player = Managers.player:local_player(1)
    if not player or not player:unit_is_alive() then
        auto_guard_blocking = false
        melee_enemy_in_range = false
        return
    end

    -- Auto guard: run scan when standalone guard is on, or when melee auto-fight is active
    local keybind = cached_settings.triggerbot_keybind
    local keybind_active = not next(keybind) or triggerbot_pressed

    local melee_equipped = is_melee_weapon_equipped()
    local melee_mode_active = cached_settings.enable_triggerbot and keybind_active and melee_equipped

    if cached_settings.enable_auto_guard or melee_mode_active then
        auto_guard_blocking = check_power_attack_incoming(unit)
    else
        auto_guard_blocking = false
    end

    if melee_mode_active then
        melee_enemy_in_range = check_enemy_in_melee_range(unit)
    else
        melee_enemy_in_range = false
    end

    local use_mouse2 = cached_settings.use_mouse2_fallback
    local should_aim = (use_mouse2 and Mouse.button(Mouse.button_index("right")) > 0.5) or (not use_mouse2 and aim_button_pressed)

    if should_aim and (not cached_settings.require_main_weapon or is_main_weapon_equipped()) then
        auto_aim_priority_targets(unit)
    else
        last_aim_unit = nil
        last_aim_zone = nil
        last_aim_zone_blocked_frames = 0
        has_target = false
    end
end)
