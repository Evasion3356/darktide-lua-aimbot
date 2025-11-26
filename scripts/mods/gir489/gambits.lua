local mod = get_mod("darktide-lua-aimbot")
local HitZone = require("scripts/utilities/attack/hit_zone")
local Breed = require("scripts/utilities/breed")
local HitScan = require("scripts/utilities/attack/hit_scan")
local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")
local Recoil = require("scripts/utilities/recoil")
local Sway = require("scripts/utilities/sway")

local HALF_PI = math.pi / 2

local aim_button_pressed = false
local triggerbot_pressed = false
local has_target = false
local last_semi_auto_fire_time = 0

local math_rad = math.rad
local math_cos = math.cos
local math_atan2 = math.atan2
local math_asin = math.asin
local math_huge = math.huge
local Vector3_normalize = Vector3.normalize
local Vector3_dot = Vector3.dot
local Vector3_length = Vector3.length
local ScriptUnit_has_extension = ScriptUnit.has_extension
local ScriptUnit_extension = ScriptUnit.extension

local function get_daemonhost_priority(unit, priority)
    local game_object_id = Managers.state.unit_spawner:game_object_id(unit)
    if game_object_id then
       local game_session = Managers.state.game_session:game_session()
       local stage = GameSession.game_object_field(game_session, game_object_id, "stage")
       if stage == 6 then --DAEMONHOST_AGGROED_STAGE
           return priority
       end
    end
    return 0
end

local function get_breed_priority(breed_name, unit)
    local priority_map = {
        -- Hound
        chaos_hound = "target_hounds", --Pox Hound
        chaos_hound_mutator = "target_hounds", --Pox Hound
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
        -- Trappers
        renegade_netgunner = "target_netgunners", --Trapper
        -- Flamers
        cultist_flamer = "target_flamers", --Dreg Tox Flamer
        renegade_flamer = "target_flamers", --Scab Flamer
        renegade_flamer_mutator = "target_flamers", --Scab Flamer
        -- Sniper
        renegade_sniper = "target_snipers", --Sniper
        -- Bombers
        chaos_poxwalker_bomber = "target_bombers", --Poxburster
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
        -- Ogryns (Melee)
        chaos_ogryn_bulwark = "target_ogryns_melee", --Bulwark
        chaos_ogryn_executor = "target_ogryns_melee", --Crusher
        -- Ogryn
        chaos_ogryn_gunner = "target_ogryns" --Reaper
    }

    local setting_key = priority_map[breed_name]
    local priority = setting_key and mod:get(setting_key) or 0
    local is_daemonhost = breed_name == "chaos_daemonhost" or breed_name == "chaos_mutator_daemonhost"

    if is_daemonhost and priority > 0 then
        return get_daemonhost_priority(unit, priority)
    end

    return priority
end

local function get_all_enemies()
    local extension_manager = Managers.state and Managers.state.extension
    if not extension_manager then
        return {}
    end

    local entities = extension_manager:get_entities("MinionHuskLocomotionExtension")
    if not next(entities) then
        entities = extension_manager:get_entities("MinionLocomotionExtension")
        if not next(entities) then
            return {}
        end
    end

    local enemies = {}
    local n = 0

    for unit, _ in pairs(entities) do
        if ScriptUnit_has_extension(unit, "health_system") then
            local health_ext = ScriptUnit_extension(unit, "health_system")
            if health_ext:is_alive() and ScriptUnit_has_extension(unit, "unit_data_system") then
                local unit_data_ext = ScriptUnit_extension(unit, "unit_data_system")
                local breed = unit_data_ext:breed()
                if breed and breed.breed_type ~= "player" and not breed.name:find("hazard") then
                    local priority = get_breed_priority(breed.name, unit)
                    if priority > 0 then
                        n = n + 1
                        enemies[n] = {
                            unit = unit,
                            position = POSITION_LOOKUP[unit],
                            priority = priority
                        }
                    end
                end
            end
        end
    end

    if n > 1 then
        table.sort(enemies, function(a, b) return a.priority > b.priority end)
    end

    return enemies
end

local function is_in_fov(enemy_unit, camera_pos, camera_forward, min_dot)
    local head_node = Unit.node(enemy_unit, "j_head")
    if not head_node then
        return false
    end
    local head_pos = Unit.world_position(enemy_unit, head_node)
    return Vector3_dot(camera_forward, Vector3_normalize(head_pos - camera_pos)) >= min_dot
end

local function can_see_head(enemy_unit, player)
    local head_node = Unit.node(enemy_unit, "j_head")
    if not head_node then
        return false
    end

    local unit_data_ext = ScriptUnit_extension(player.player_unit, "unit_data_system")
    local shooting_pos = unit_data_ext:read_component("first_person").position

    local head_pos = Unit.world_position(enemy_unit, head_node)
    local dir = head_pos - shooting_pos
    local dist = Vector3_length(dir)
    dir = Vector3_normalize(dir)

    local physics_world = World.physics_world(Application.main_world())
    local hits_dynamics = HitScan.raycast(physics_world, shooting_pos, dir, dist, nil, "filter_player_character_shooting_raycast_dynamics", 0, true, player, false)

    local target_head_hit = nil
    if hits_dynamics then
        for i = 1, #hits_dynamics do
            local hit = hits_dynamics[i]
            local actor = hit.actor or hit[4]
            if actor then
                local unit = Actor.unit(actor)
                if unit == enemy_unit then
                    local zone_name = HitZone.get_name(unit, actor)
                    if zone_name == HitZone.hit_zone_names.shield then
                        return false
                    end
                    if zone_name == HitZone.hit_zone_names.head then
                        target_head_hit = hit.distance or hit[2] or 0
                    end
                end
            end
        end
    end

    if not target_head_hit then
        return false
    end

    local hits_statics = PhysicsWorld.raycast(physics_world, shooting_pos, dir, dist, "all", "types", "statics", "max_hits", 256, "collision_filter", "filter_player_character_shooting_raycast_statics")

    if hits_statics and #hits_statics > 0 then
        local wall_distance = hits_statics[1].distance or hits_statics[1][2] or math_huge
        if wall_distance < target_head_hit then
            return false
        end
    end

    return true
end

local function look_at_enemy_head(enemy_unit, player, shooting_pos, player_unit)
    local head_node = Unit.node(enemy_unit, "j_head")
    if not head_node then
        return
    end
    local head_pos = Unit.world_position(enemy_unit, head_node)
    local dir = Vector3_normalize(head_pos - shooting_pos)

    -- Get base orientation without recoil
    local base_pitch = math_asin(dir.z)
    local base_yaw = math_atan2(dir.y, dir.x) - HALF_PI

    -- Apply recoil and sway like the weapon does
    local unit_data_ext = ScriptUnit_extension(player_unit, "unit_data_system")
    local recoil_component = unit_data_ext:read_component("recoil")
    local sway_component = unit_data_ext:read_component("sway")

    player:set_orientation(base_yaw - recoil_component.yaw_offset - sway_component.offset_x, base_pitch - recoil_component.pitch_offset - sway_component.offset_y, 0)
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
            local is_connected = game_session_manager:connected_to_client(peer_id)
            if is_connected and not player:unit_is_alive() then
                print("dead")
                return true
            end
            -- Check if hogtied
            if player.player_unit then
                local unit_data_extension = ScriptUnit.extension(player.player_unit, "unit_data_system")
                local character_state_component = unit_data_extension:read_component("character_state")
                if character_state_component.state_name == "hogtied" then
                    print("hogtied")
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
        return
    end

    -- Check if disable is enabled when teammates are dead
    local disable_when_teammates_dead = mod:get("disable_aimbot_when_teammates_are_dead")
    local teammates_are_dead = are_teammates_dead()

    if disable_when_teammates_dead and teammates_are_dead then
        has_target = false
        return
    end

    local unit_data_ext = ScriptUnit_extension(player_unit, "unit_data_system")
    local first_person_component = unit_data_ext:read_component("first_person")
    local shooting_pos = first_person_component.position

    local camera_forward, min_dot
    local fov_check_enabled = mod:get("enable_fov_check")
    if fov_check_enabled then
        local first_person_rot = first_person_component.rotation
        camera_forward = Quaternion.forward(first_person_rot)
        min_dot = math_cos(math_rad(mod:get("fov_angle") * 0.5))
    end

    local enemies = get_all_enemies()
    for i = 1, #enemies do
        local enemy = enemies[i]
        if not fov_check_enabled or is_in_fov(enemy.unit, shooting_pos, camera_forward, min_dot) then
            if can_see_head(enemy.unit, player) then
                has_target = true
                look_at_enemy_head(enemy.unit, player, shooting_pos, player_unit)
                return
            end
        end
    end

    has_target = false
end

local function get_weapon_fire_mode(weapon_template, is_ads)
    if not weapon_template or not weapon_template.actions then
        return "full_auto"
    end

    local shoot_action = is_ads and
        (weapon_template.actions.action_shoot_zoomed or weapon_template.actions.action_zoom_shoot_charged or weapon_template.actions.action_shoot_zoomed_start) or
        (weapon_template.actions.action_shoot_hip or weapon_template.actions.action_shoot_hip_charged or weapon_template.actions.action_shoot_hip_start)

    if not shoot_action then
        return "full_auto"
    end

    if shoot_action.kind == "charge_ammo" then
        return "charge"
    end

    local input_check = is_ads and
        (weapon_template.action_inputs and weapon_template.action_inputs.zoom_shoot) or
        (weapon_template.action_inputs and weapon_template.action_inputs.shoot_pressed)

    if input_check then
        for _, input_seq in ipairs(input_check.input_sequence or {}) do
            if input_seq.input and (input_seq.input == "action_one_pressed" or input_seq.input:find("_pressed")) then
                return "semi_auto"
            end
        end
    end

    if shoot_action.stop_input == "shoot_release" and shoot_action.total_time == math.huge then
        return "full_auto"
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

    -- Apply recoil and sway like action_shoot.lua does
    local recoil_component = unit_data_ext:read_component("recoil")
    local sway_component = unit_data_ext:read_component("sway")
    local movement_state_component = unit_data_ext:read_component("movement_state")

    if action_component and recoil_component and sway_component and movement_state_component then
        local weapon_template = WeaponTemplate.current_weapon_template(action_component)
        if weapon_template then
            local weapon_extension = ScriptUnit_extension(player.player_unit, "weapon_system")
            if weapon_extension then
                local recoil_template = weapon_extension:recoil_template()
                local sway_template = weapon_extension:sway_template()

                if recoil_template then
                    ray_rotation = Recoil.apply_weapon_recoil_rotation(recoil_template, recoil_component, movement_state_component, ray_rotation)
                end

                if sway_template then
                    ray_rotation = Sway.apply_sway_rotation(sway_template, sway_component, movement_state_component, ray_rotation)
                end
            end
        end
    end

    local direction = Quaternion.forward(ray_rotation)
    local max_distance = 150

    if action_component then
        local weapon_template = WeaponTemplate.current_weapon_template(action_component)
        if weapon_template and weapon_template.hit_scan_template and weapon_template.hit_scan_template.range then
            max_distance = weapon_template.hit_scan_template.range
        end
    end

    local physics_world = World.physics_world(Application.main_world())
    local hits = HitScan.raycast(physics_world, shooting_pos, direction, max_distance, nil, "filter_player_character_shooting_raycast_dynamics", 0, true, player, false)

    if not hits or #hits == 0 then
        return false
    end

    local weakspot_only = mod:get("triggerbot_weakspot_only")
    local respect_priority = mod:get("triggerbot_respect_priority")

    for i = 1, #hits do
        local hit = hits[i]
        if hit then
            local actor = hit.actor or hit[4]
            if actor then
                local hit_unit = Actor.unit(actor)
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
                                local is_daemonhost = breed_name == "chaos_daemonhost" or breed_name == "chaos_mutator_daemonhost"
                                if is_daemonhost and get_daemonhost_priority(hit_unit, 1) == 0 then
                                    goto continue_hit_loop
                                end
                            end

                            local hit_distance = hit.distance or hit[2] or 0
                            local hits_statics = PhysicsWorld.raycast(physics_world, shooting_pos, direction, max_distance, "all", "types", "statics", "max_hits", 256, "collision_filter", "filter_player_character_shooting_raycast_statics")
                            if hits_statics and #hits_statics > 0 then
                                local wall_distance = hits_statics[1].distance or hits_statics[1][2] or math_huge
                                if wall_distance < hit_distance then
                                    goto continue_hit_loop
                                end
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

local _get = function(self, input_service, action_name)
    local is_fire_input = (action_name == "action_one_hold" or action_name == "action_one_pressed") and input_service.type == "Ingame"

    if not is_fire_input or not mod:get("enable_triggerbot") then
        return self(input_service, action_name)
    end

    local keybind = mod:get("triggerbot_keybind")
    local has_keybind = next(keybind) ~= nil
    if has_keybind and not triggerbot_pressed then
        return self(input_service, action_name)
    end

    if mod:get("require_main_weapon") and not is_main_weapon_equipped() then
        return self(input_service, action_name)
    end

    local can_fire = mod:get("triggerbot_use_raycast") and is_reticle_on_enemy() or has_target

    if can_fire then
        local weapon_template, fire_mode = get_current_weapon_info()

        if (fire_mode == "charge" or fire_mode == "full_auto") and action_name == "action_one_hold" then
            return true
        elseif fire_mode == "semi_auto" and action_name == "action_one_pressed" then
            -- For semi-auto weapons, fire once per latency cycle to avoid sending too many fire events
            local fire_interval, current_time = get_fire_interval()

            if current_time - last_semi_auto_fire_time >= fire_interval then
                last_semi_auto_fire_time = current_time
                return true
            end
            return false
        end
    end

    return self(input_service, action_name)
end

mod:hook("InputService", "_get", _get)
mod:hook("InputService", "_get_simulate", _get)

mod:hook_safe("PlayerUnitFirstPersonExtension", "fixed_update", function(self, unit, dt, t, frame)
    local player = Managers.player:local_player(1)
    if not player or not player:unit_is_alive() then
        return
    end

    local use_mouse2 = mod:get("use_mouse2_fallback")
    local should_aim = (use_mouse2 and Mouse.button(Mouse.button_index("right")) > 0.5) or (not use_mouse2 and aim_button_pressed)

    if should_aim and (not mod:get("require_main_weapon") or is_main_weapon_equipped()) then
        auto_aim_priority_targets(unit)
    else
        has_target = false
    end
end)
