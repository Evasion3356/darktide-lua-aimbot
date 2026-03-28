local mod = get_mod("darktide-lua-gambits")
local Health = require("scripts/utilities/health")
local HitZone = require("scripts/utilities/attack/hit_zone")
local Breed = require("scripts/utilities/breed")
local HitScan = require("scripts/utilities/attack/hit_scan")
local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")
local Recoil = require("scripts/utilities/recoil")
local Sway = require("scripts/utilities/sway")
local Suppression = require("scripts/utilities/attack/suppression")
local WeaponMovementState = require("scripts/extension_systems/weapon/utilities/weapon_movement_state")

local HALF_PI = math.pi / 2

local aim_button_pressed = false
local triggerbot_pressed = false
local has_target = false
local last_semi_auto_fire_time = 0
local pending_aim_yaw = nil
local pending_aim_pitch = nil

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
local math_huge = math.huge
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
    return a.priority > b.priority
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

    -- Build a [class][breed_name] -> priority lookup table so get_breed_priority
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

local function get_alive_player_unit(player)
    local player_unit = player and player.player_unit
    if not player_unit or not ALIVE[player_unit] then
        return nil
    end

    return player_unit
end

local function should_activate_autoaim()
    local use_mouse2 = cached_settings.use_mouse2_fallback
    return (use_mouse2 and Mouse.button(Mouse.button_index("right")) > 0.5) or (not use_mouse2 and aim_button_pressed)
end

local function is_same_local_player(player, local_player)
    if not player or not local_player then
        return false
    end

    if player == local_player then
        return true
    end

    return player:peer_id() == local_player:peer_id() and player:local_player_id() == local_player:local_player_id()
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

    local n = 0

    for unit, _ in pairs(entities) do
        local health_extension = ScriptUnit_has_extension(unit, "health_system")
        if health_extension and health_extension:is_alive() then
            local unit_data_ext = ScriptUnit_extension(unit, "unit_data_system")
            local breed = unit_data_ext:breed()
            if not breed or breed.breed_type == "player" or (breed.name and breed.name:find("hazard")) then
                goto next_unit
            end

            local priority = get_breed_priority(breed.name, unit)
            if priority > 0 then
                if POXBURSTER_BREEDS[breed.name] and not is_poxburster_safe_to_target(unit) then
                    goto next_unit
                end
                n = n + 1
                local entry = reusable_enemies[n]
                if entry then
                    entry.unit = unit
                    entry.position = POSITION_LOOKUP[unit]
                    entry.priority = priority
                else
                    reusable_enemies[n] = {
                        unit = unit,
                        position = POSITION_LOOKUP[unit],
                        priority = priority
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

local function spread_rotation_from_offset(offset, previous_offset, max_delta, around_vector)
    local diff = math_abs(previous_offset - offset)
    local lerp_ratio = diff == 0 and 1 or math_min(max_delta, 1)
    local lerped_offset = math.lerp(previous_offset, offset, lerp_ratio)
    local rotation = Quaternion(around_vector, math.degrees_to_radians(lerped_offset))

    return rotation
end

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

    local yaw_rot = spread_rotation_from_offset(
        yaw_offset,
        previous_yaw,
        rs.max_yaw_delta or SPREAD_DEFAULT_MAX_YAW_DELTA,
        Vector3.up()
    )
    
    local pitch_rot = spread_rotation_from_offset(
        pitch_offset,
        previous_pitch,
        rs.max_pitch_delta or SPREAD_DEFAULT_MAX_PITCH_DELTA,
        Vector3.right()
    )

    -- final = input * pitch * yaw  =>  offset = pitch * yaw
    return Quaternion.multiply(pitch_rot, yaw_rot)
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
                local hit = hits[i]
                local actor = hit[4]
                if actor then
                    local hit_unit = Actor_unit(actor)
                    local hit_zone_name = HitZone.get_name(hit_unit, actor)

                    if hit_zone_name == HitZone.hit_zone_names.afro then
                        goto continue_ray
                    end

                    if hit_zone_name == HitZone.hit_zone_names.shield or hit_zone_name == HitZone.hit_zone_names.captain_void_shield then
                        blocked = true
                        break
                    end

                    if hit_unit == player.player_unit then
                        goto continue_ray
                    end

                    if Health.is_ragdolled(hit_unit) then
                        goto continue_ray
                    end

                    if hit_unit == enemy_unit then
                        if target_actor then
                            -- Only accept LOS if the ray hit the specific actor we're
                            -- targeting. Any other actor on this unit means the target
                            -- is occluded by the body; fall through to the next zone.
                            if actor == target_actor then
                                return true, zone
                            end
                            blocked = true
                            break
                        end
                        return true, zone
                    end

                    blocked = true
                    break
                end
                ::continue_ray::
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
    if not aim_pos then
        return nil, nil
    end

    local dir = Vector3_normalize(aim_pos - shooting_pos)
    local base_pitch = math_asin(dir.z)
    local base_yaw = math_atan2(dir.y, dir.x) - HALF_PI

    local unit_data_ext = ScriptUnit_extension(player_unit, "unit_data_system")
    if not unit_data_ext then
        return nil, nil
    end

    local recoil_component = unit_data_ext:read_component("recoil")
    local sway_component = unit_data_ext:read_component("sway")
    if not recoil_component or not sway_component then
        return nil, nil
    end

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

    return base_yaw - recoil_component.yaw_offset - sway_component.offset_x, base_pitch - recoil_component.pitch_offset - sway_component.offset_y
end

local function set_pending_aim_orientation(enemy_unit, zone, player, shooting_pos, player_unit)
    local target_yaw, target_pitch = look_at_aim_target(enemy_unit, zone, player, shooting_pos, player_unit)
    if not target_yaw or not target_pitch then
        return false
    end

    pending_aim_yaw = target_yaw
    pending_aim_pitch = target_pitch

    return true
end

local function get_fire_interval()
    -- Get current time from the game using main clock (steadier than gameplay)
    local current_time = Managers.time:time("main") or 0

    -- Try to get the player's peer connection
    local player = Managers.player:local_player(1)
    if not player then
        return 0.1, current_time -- Default 100ms interval if we can't get latency
    end

    -- Get the peer ID for the player
    local peer_id = player:peer_id()
    if not peer_id then
        return 0.1, current_time
    end

    -- Get RTT (round trip time) from Network API - this returns time in seconds
    local rtt = Network.ping(peer_id)
    if not rtt or rtt == 0 then
        return 0.1, current_time
    end

    -- Double the latency as requested (full roundtrip = client -> server -> client)
    -- The Network.ping already returns RTT, so we use it as-is and double it
    local fire_interval = rtt * 2

    return fire_interval, current_time
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
            -- Check if dead
            local peer_id = player:peer_id()
            if game_session_manager:connected_to_client(peer_id) and not player:unit_is_alive() then
                return true
            end
            -- Check if hogtied
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
    pending_aim_yaw = nil
    pending_aim_pitch = nil

    local player = Managers.player:local_player(1)
    if not player or not player.player_unit then
        has_target = false
        return
    end

    -- Check if disable is enabled when teammates are dead
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
            local unit_data_ext2 = ScriptUnit_has_extension(enemy.unit, "unit_data_system")
            local breed = unit_data_ext2 and unit_data_ext2:breed()
            local zones = (breed and BREED_AIM_ZONES[breed.name]) or DEFAULT_AIM_ZONES

            local visible, resolved_zone = can_see_aim_target(enemy.unit, player, shooting_pos, zones)
            if visible then
                if set_pending_aim_orientation(enemy.unit, resolved_zone, player, shooting_pos, player_unit) then
                    has_target = true
                    return
                end
            end
        end
    end

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

            -- Apply predicted spread so triggerbot ray matches actual next shot prediction
            if cached_settings.enable_spread_compensation then
                local spread_offset = predict_spread_offset(player.player_unit)
                if spread_offset then
                    ray_rotation = Quaternion.multiply(ray_rotation, spread_offset)
                end
            end

            -- Get max distance from weapon template
            if weapon_template.hit_scan_template and weapon_template.hit_scan_template.range then
                max_distance = weapon_template.hit_scan_template.range
            end
        end
    end

    local direction = Quaternion_forward(ray_rotation)

    local physics_world = World_physics_world(Application_main_world())
    local hits = HitScan.raycast(physics_world, shooting_pos, direction, max_distance, nil, "filter_player_character_shooting_raycast_dynamics", 0, true, player, false)

    if not hits or #hits == 0 then
        return false
    end

    -- Hoist static raycast out of the loop-direction and position don't change per hit.
    -- Use "closest" instead of "all" since we only need the nearest wall distance.
    local wall_distance = math_huge
    local hit_statics, _, static_dist = PhysicsWorld_raycast(physics_world, shooting_pos, direction, max_distance, "closest", "types", "statics", "collision_filter", "filter_player_character_shooting_raycast_statics")
    if hit_statics then
        wall_distance = static_dist
    end

    local weakspot_only = cached_settings.triggerbot_weakspot_only
    local respect_priority = cached_settings.triggerbot_respect_priority

    for i = 1, #hits do
        local hit = hits[i]
        if hit then
            local actor = hit.actor or hit[4]
            if actor then
                local hit_unit = Actor_unit(actor)
                -- Skip hits on the player itself
                if hit_unit == player.player_unit then
                    goto continue_hit_loop
                end
                if hit_unit and ScriptUnit_has_extension(hit_unit, "health_system") then
                    local health_ext = ScriptUnit_extension(hit_unit, "health_system")
                    if health_ext:is_alive() then
                        local breed = Breed.unit_breed_or_nil(hit_unit)
                        if breed and not Breed.is_player(breed) and not breed.name:find("hazard") then
                            local zone_name = HitZone.get_name(hit_unit, actor)

                            if zone_name == HitZone.hit_zone_names.afro then
                                goto continue_hit_loop
                            end

                            if zone_name == HitZone.hit_zone_names.shield then
                                return false
                            end

                            if weakspot_only and zone_name ~= HitZone.hit_zone_names.head and zone_name ~= HitZone.hit_zone_names.weakspot then
                                goto continue_hit_loop
                            end

                            local breed_name = breed.name
                            if respect_priority and get_breed_priority(breed_name, hit_unit) == 0 then
                                goto continue_hit_loop
                            else
                                if DAEMONHOST_BREEDS[breed_name] and get_daemonhost_priority(hit_unit, 1) == 0 then
                                    goto continue_hit_loop
                                end
                                if POXBURSTER_BREEDS[breed_name] and not is_poxburster_safe_to_target(hit_unit) then
                                    goto continue_hit_loop
                                end
                            end

                            local hit_distance = hit.distance or hit[2] or 0
                            if wall_distance < hit_distance then
                                goto continue_hit_loop
                            end

                            return true
                        end
                    end
                end
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

local _get = function(func, self, action_name)
    if self.type ~= "Ingame" or not cached_settings.enable_triggerbot then
        return func(self, action_name)
    end

    if action_name ~= "action_one_hold" and action_name ~= "action_one_pressed" then
        return func(self, action_name)
    end

    local keybind = cached_settings.triggerbot_keybind
    if next(keybind) and not triggerbot_pressed then
        return func(self, action_name)
    end

    if cached_settings.require_main_weapon and not is_main_weapon_equipped() then
        return func(self, action_name)
    end

    local can_fire = (cached_settings.triggerbot_use_raycast and is_reticle_on_enemy()) or has_target
    if not can_fire then
        return func(self, action_name)
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

mod:hook("InputService", "_get", _get)
mod:hook("InputService", "_get_simulate", _get)

mod:hook("HumanGameplay", "fixed_update", function(func, self, game_dt, game_t, fixed_frame)
    local player = self and self._player
    local local_player = Managers.player:local_player_safe(1)
    local player_unit = get_alive_player_unit(player)

    if not player_unit or not is_same_local_player(player, local_player) then
        has_target = false
        pending_aim_yaw = nil
        pending_aim_pitch = nil
        return func(self, game_dt, game_t, fixed_frame)
    end

    local should_aim = should_activate_autoaim()

    if should_aim and cached_settings.require_main_weapon and not is_main_weapon_equipped() then
        should_aim = false
    end

    if not should_aim then
        has_target = false
        pending_aim_yaw = nil
        pending_aim_pitch = nil
        return func(self, game_dt, game_t, fixed_frame)
    end

    auto_aim_priority_targets(player_unit)

    if pending_aim_yaw == nil or pending_aim_pitch == nil then
        return func(self, game_dt, game_t, fixed_frame)
    end

    local orientation = player:get_orientation()
    local old_yaw = orientation.yaw
    local old_pitch = orientation.pitch
    local old_roll = orientation.roll

    player:set_orientation(pending_aim_yaw, pending_aim_pitch, old_roll)

    local result = func(self, game_dt, game_t, fixed_frame)

    player:set_orientation(old_yaw, old_pitch, old_roll)

    return result
end)
