local mod = get_mod("darktide-lua-aimbot")
local HitZone = require("scripts/utilities/attack/hit_zone")

-- Constants
local HALF_PI = math.pi / 2
local DAEMONHOST_PASSIVE_STAGE = 1

-- State variables
local aim_button_pressed = false
local triggerbot_pressed = false
local has_target = false

-- Cached math functions
local math_rad = math.rad
local math_cos = math.cos
local math_atan2 = math.atan2
local math_asin = math.asin
local Vector3_normalize = Vector3.normalize
local Vector3_dot = Vector3.dot
local Vector3_length = Vector3.length

-- Get priority level for a breed (with caching)
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
    
    -- Special daemonhost check
    if breed_name == "chaos_daemonhost" and priority > 0 and unit then
        local game_object_id = Managers.state.unit_spawner:game_object_id(unit)
        if game_object_id then
            local game_session = Managers.state.game_session:game_session()
            local stage = GameSession.game_object_field(game_session, game_object_id, "stage")
            if stage == DAEMONHOST_PASSIVE_STAGE then
                return 0
            end
        end
    end
    
    return priority
end

-- Get all active enemy threats with priorities
local function get_all_enemies()
    local extension_manager = Managers.state and Managers.state.extension
    if not extension_manager then
        return {}
    end
    
    local enemies = {}
    local n = 0
    
    -- Try to get entities (check husk first, then regular)
    local entities = extension_manager:get_entities("MinionHuskLocomotionExtension")
    if not next(entities) then
        entities = extension_manager:get_entities("MinionLocomotionExtension")
        if not next(entities) then
            return {}
        end
    end
    
    -- Cache extension checks
    local ScriptUnit_has_extension = ScriptUnit.has_extension
    local ScriptUnit_extension = ScriptUnit.extension
    
    for unit, _ in pairs(entities) do
        local health_ext = ScriptUnit_has_extension(unit, "health_system") and 
                          ScriptUnit_extension(unit, "health_system")
        
        if health_ext and health_ext:is_alive() then
            local unit_data_ext = ScriptUnit_has_extension(unit, "unit_data_system") and
                                 ScriptUnit_extension(unit, "unit_data_system")
            
            if unit_data_ext then
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
    
    -- Sort by priority (highest first) - using optimized comparison
    if n > 1 then
        table.sort(enemies, function(a, b) return a.priority > b.priority end)
    end
    
    return enemies
end

-- Check if enemy is within player's field of view
local function is_in_fov(enemy_unit, camera_pos, camera_forward, min_dot)
    local head_node = Unit.node(enemy_unit, "j_head")
    if not head_node then
        return false
    end
    
    local head_pos = Unit.world_position(enemy_unit, head_node)
    local to_enemy = Vector3_normalize(head_pos - camera_pos)
    
    return Vector3_dot(camera_forward, to_enemy) >= min_dot
end

local Breed = require("scripts/utilities/breed")
local Health = require("scripts/utilities/health")
local HitScan = require("scripts/utilities/attack/hit_scan")

-- Helper to raycast and process hits for enemy detection
local function raycast_for_hits(shooting_pos, direction, max_distance, player)
    local physics_world = World.physics_world(Application.main_world())
    return HitScan.raycast(physics_world, shooting_pos, direction, max_distance, nil, "filter_player_character_shooting_raycast_dynamics", 0, true, player, false)
end

-- Check if a specific unit is in hit results
local function find_unit_in_hits(hits, target_unit, require_head)
    if not hits then
        return nil
    end

    for i = 1, #hits do
        local hit = hits[i]
        local actor = hit.actor or hit[4]
        if actor then
            local unit = Actor.unit(actor)
            if unit == target_unit then
                local zone_name = HitZone.get_name(unit, actor)

                -- Shield blocks targeting
                if zone_name == HitZone.hit_zone_names.shield then
                    return "blocked"
                end

                -- Return if we find a head (or any hit if not requiring head)
                if not require_head or zone_name == HitZone.hit_zone_names.head then
                    return "visible"
                end
            end
        end
    end

    return nil
end

-- Check if player can see enemy's head
local function can_see_head(enemy_unit, player)
    local head_node = Unit.node(enemy_unit, "j_head")
    if not head_node then
        return false
    end

    local unit_data_ext = ScriptUnit.extension(player.player_unit, "unit_data_system")
    local first_person_component = unit_data_ext:read_component("first_person")
    local shooting_pos = first_person_component.position

    local head_pos = Unit.world_position(enemy_unit, head_node)
    local dir = head_pos - shooting_pos
    local dist = Vector3_length(dir)
    dir = Vector3_normalize(dir)

    local hits = raycast_for_hits(shooting_pos, dir, dist, player)
    local result = find_unit_in_hits(hits, enemy_unit, true)

    return result == "visible" and "visible" or false
end

-- Helper to get fire configuration from weapon template
local function get_weapon_fire_config(weapon_template)
    if not weapon_template or not weapon_template.actions then
        return nil
    end

    -- Try current action first
    local unit_data_ext = ScriptUnit.extension(Managers.player:local_player(1).player_unit, "unit_data_system")
    local weapon_action_component = unit_data_ext:read_component("weapon_action")
    local fire_config = nil

    if weapon_action_component then
        local Action = require("scripts/utilities/action/action")
        local action_settings = Action.current_action_settings_from_component(weapon_action_component, weapon_template.actions)

        if action_settings then
            fire_config = action_settings.fire_configuration or
                        (action_settings.fire_configurations and action_settings.fire_configurations[1])
        end
    end

    -- Fallback to specific actions
    if not fire_config then
        fire_config = weapon_template.actions.action_shoot_hip or
                    weapon_template.actions.action_shoot_hip_charged or
                    weapon_template.actions.action_shoot_hip_start or
                    weapon_template.actions.action_shoot_zoomed or
                    weapon_template.actions.action_zoom_shoot_charged or
                    weapon_template.actions.action_shoot_zoomed_start

        if fire_config then
            fire_config = fire_config.fire_configuration or
                        (fire_config.fire_configurations and fire_config.fire_configurations[1])
        end
    end

    return fire_config
end

-- Check if crosshair is directly on an enemy (raycast from camera)
local function is_crosshair_on_enemy()
    local player = Managers.player:local_player(1)
    if not player or not player.player_unit then
        return false
    end

    local unit_data_ext = ScriptUnit.extension(player.player_unit, "unit_data_system")
    local camera_pos = Managers.state.camera:camera_position(player.viewport_name)
    local camera_rot = Managers.state.camera:camera_rotation(player.viewport_name)

    -- Apply recoil/sway to rotation
    local weapon_extension = ScriptUnit.extension(player.player_unit, "weapon_system")
    local recoil_template = weapon_extension:recoil_template()
    local sway_template = weapon_extension:sway_template()
    local movement_state_component = unit_data_ext:read_component("movement_state")
    local recoil_component = unit_data_ext:read_component("recoil")
    local sway_component = unit_data_ext:read_component("sway")

    local Recoil = require("scripts/utilities/recoil")
    local Sway = require("scripts/utilities/sway")

    local ray_rotation = Recoil.apply_weapon_recoil_rotation(recoil_template, recoil_component, movement_state_component, camera_rot)
    ray_rotation = Sway.apply_sway_rotation(sway_template, sway_component, movement_state_component, ray_rotation)

    local direction = Quaternion.forward(ray_rotation)
    local max_distance = 150

    -- Get weapon range
    local unit_data_extension = ScriptUnit.has_extension(player.player_unit, "unit_data_system") and ScriptUnit.extension(player.player_unit, "unit_data_system")
    if unit_data_extension then
        local weapon_action_component = unit_data_extension:read_component("weapon_action")
        if weapon_action_component then
            local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")
            local weapon_template = WeaponTemplate.current_weapon_template(weapon_action_component)

            if weapon_template and weapon_template.hit_scan_template and weapon_template.hit_scan_template.range then
                max_distance = weapon_template.hit_scan_template.range
            end
        end
    end

    local hits = raycast_for_hits(camera_pos, direction, max_distance, player)

    if not hits or #hits == 0 then
        return false
    end

    -- Get triggerbot settings
    local weakspot_only = mod:get("triggerbot_weakspot_only")
    local respect_priority = mod:get("triggerbot_respect_priority")

    -- Check each hit for a valid enemy
    for i = 1, #hits do
        local hit = hits[i]
        local actor = hit.actor or hit[4]
        if actor then
            local hit_unit = Actor.unit(actor)

            if hit_unit and hit_unit ~= player.player_unit and ScriptUnit.has_extension(hit_unit, "health_system") then
                local health_ext = ScriptUnit.extension(hit_unit, "health_system")

                if health_ext and health_ext:is_alive() then
                    local breed = Breed.unit_breed_or_nil(hit_unit)

                    if breed and not Breed.is_player(breed) and not (breed.name and breed.name:find("hazard")) then
                        local zone_name = HitZone.get_name(hit_unit, actor)

                        -- Skip afro hits (hair)
                        if zone_name == HitZone.hit_zone_names.afro then
                            goto continue_hit_loop
                        end

                        -- Check weakspot requirement
                        if weakspot_only then
                            if zone_name ~= HitZone.hit_zone_names.head and zone_name ~= HitZone.hit_zone_names.weakspot then
                                goto continue_hit_loop
                            end
                        end

                        -- Check priority requirement
                        if respect_priority then
                            local priority = get_breed_priority(breed.name, hit_unit)
                            if priority == 0 then
                                goto continue_hit_loop
                            end
                        end

                        return true
                    end
                end
            end
        end

        ::continue_hit_loop::
    end

    return false
end

-- Look at an enemy's head with recoil compensation
local function look_at_enemy_head(enemy_unit, player, camera_pos, recoil_pitch, recoil_yaw)
    local head_node = Unit.node(enemy_unit, "j_head")
    if not head_node then
        return false
    end

    local head_pos = Unit.world_position(enemy_unit, head_node)
    local dir = Vector3_normalize(head_pos - camera_pos)

    local target_yaw = math_atan2(dir.y, dir.x) - HALF_PI
    local target_pitch = math_asin(dir.z)

    player:set_orientation(target_yaw - recoil_yaw, target_pitch - recoil_pitch, 0)

    return true
end

-- Auto-aim at priority targets
local function auto_aim_priority_targets(player_unit)
    local player = Managers.player:local_player(1)
    if not player or not player.player_unit then
        return
    end

    local camera_pos = Managers.state.camera:camera_position(player.viewport_name)
    local unit_data_ext = ScriptUnit.extension(player_unit, "unit_data_system")
    local recoil_component = unit_data_ext:read_component("recoil")

    -- Pre-calculate FoV values if enabled
    local camera_forward, min_dot
    local fov_check_enabled = mod:get("enable_fov_check")
    if fov_check_enabled then
        local camera_rot = Managers.state.camera:camera_rotation(player.viewport_name)
        camera_forward = Quaternion.forward(camera_rot)
        local fov_angle = mod:get("fov_angle")
        min_dot = math_cos(math_rad(fov_angle * 0.5))
    end

    -- Find and aim at priority targets
    local enemies = get_all_enemies()

    -- Iterate through sorted priority list and find first visible target
    for i = 1, #enemies do
        local enemy = enemies[i]

        if not fov_check_enabled or is_in_fov(enemy.unit, camera_pos, camera_forward, min_dot) then
            local visibility = can_see_head(enemy.unit, player)

            if visibility == "visible" then
                has_target = true
                look_at_enemy_head(enemy.unit, player, camera_pos, recoil_component.pitch_offset, recoil_component.yaw_offset)
                return
            end
        end
    end

    has_target = false
end

mod.toggle_aim = function(is_pressed)
    aim_button_pressed = is_pressed
end

mod.toggle_triggerbot = function(is_pressed)
    triggerbot_pressed = is_pressed
end

-- Detect weapon firing mode from template
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

-- Get current weapon template and fire mode
local function get_current_weapon_info()
    local player = Managers.player:local_player_safe(1)
    if not player or not player.player_unit then
        return nil, "full_auto", false
    end
    
    local unit_data_ext = ScriptUnit.extension(player.player_unit, "unit_data_system")
    if not unit_data_ext then
        return nil, "full_auto", false
    end
    
    local weapon_action_component = unit_data_ext:read_component("weapon_action")
    if not weapon_action_component then
        return nil, "full_auto", false
    end
    
    local alternate_fire_component = unit_data_ext:read_component("alternate_fire")
    local is_ads = alternate_fire_component and alternate_fire_component.is_active or false
    
    local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")
    local weapon_template = WeaponTemplate.current_weapon_template(weapon_action_component)
    
    if not weapon_template then
        return nil, "full_auto", is_ads
    end
    
    local fire_mode = get_weapon_fire_mode(weapon_template, is_ads)
    return weapon_template, fire_mode, is_ads
end

-- Triggerbot logic hook
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

    local can_fire = mod:get("triggerbot_use_raycast") and is_crosshair_on_enemy() or has_target

    if can_fire then
        local weapon_template, fire_mode, is_ads = get_current_weapon_info()

        if (fire_mode == "charge" or fire_mode == "full_auto") and action_name == "action_one_hold" then
            return true
        elseif fire_mode == "semi_auto" and action_name == "action_one_pressed" then
            return true
        end
    end

    return self(input_service, action_name)
end

-- Hook into weapon system for triggerbot
mod:hook("InputService", "_get", _get)
mod:hook("InputService", "_get_simulate", _get)

-- Hook into update for auto-aim
mod:hook_safe("PlayerUnitFirstPersonExtension", "fixed_update", function(self, unit, dt, t, frame)
    local player = Managers.player:local_player(1)
    if not player or not player:unit_is_alive() then
        return
    end
    
    local use_mouse2 = mod:get("use_mouse2_fallback")
    local should_aim = (use_mouse2 and Mouse.button(Mouse.button_index("right")) > 0.5) or 
                      (not use_mouse2 and aim_button_pressed)
    
    if should_aim then
        auto_aim_priority_targets(unit)
    else
        has_target = false
    end
end)