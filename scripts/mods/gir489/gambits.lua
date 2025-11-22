local mod = get_mod("darktide-lua-aimbot")
local Action = require("scripts/utilities/action/action")

-- Constants
local HALF_PI = math.pi / 2
local DAEMONHOST_PASSIVE_STAGE = 1

-- State variables
local aim_button_pressed = false
local auto_fire_pressed = false
local has_target = false

-- Cache frequently accessed values
local math_rad = math.rad
local math_cos = math.cos
local math_atan2 = math.atan2
local math_asin = math.asin
local Vector3_normalize = Vector3.normalize
local Vector3_dot = Vector3.dot
local Vector3_length = Vector3.length

-- Breed priority mapping (cached to avoid repeated function calls)
local breed_priority_cache = {}

-- Get priority level for a breed (with caching)
local function get_breed_priority(breed_name, unit)
    local cached = breed_priority_cache[breed_name]
    if cached ~= nil and breed_name ~= "chaos_daemonhost" then
        return cached
    end
    
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
    else
        -- Cache non-daemonhost priorities
        breed_priority_cache[breed_name] = priority
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

-- Check if player can see enemy's head
local function can_see_head(enemy_unit, camera_pos)
    local head_node = Unit.node(enemy_unit, "j_head")
    if not head_node then
        return false
    end
    
    local head_pos = Unit.world_position(enemy_unit, head_node)
    local dir = head_pos - camera_pos
    local dist = Vector3_length(dir)
    Vector3_normalize(dir)
    
    local hit, _, _, _, actor = PhysicsWorld.raycast(
        World.physics_world(Application.main_world()),
        camera_pos,
        dir,
        dist,
        "closest",
        "collision_filter",
        "filter_ray_aim_assist_line_of_sight"
    )
    
    return not hit or Actor.unit(actor) == enemy_unit
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
    
    -- Get recoil offset
    local unit_data_ext = ScriptUnit.extension(player_unit, "unit_data_system")
    local recoil_component = unit_data_ext:read_component("recoil")
    local recoil_pitch = recoil_component.pitch_offset
    local recoil_yaw = recoil_component.yaw_offset
    
    -- Get settings
    local fov_check_enabled = mod:get("enable_fov_check")
    
    -- Pre-calculate FoV values if needed
    local camera_forward, min_dot
    if fov_check_enabled then
        local camera_rot = Managers.state.camera:camera_rotation(player.viewport_name)
        camera_forward = Quaternion.forward(camera_rot)
        local fov_angle = mod:get("fov_angle")
        min_dot = math_cos(math_rad(fov_angle * 0.5))
    end
    
    -- Find and aim at priority targets
    local enemies = get_all_enemies()
    for i = 1, #enemies do
        local enemy = enemies[i]
        
        if not fov_check_enabled or is_in_fov(enemy.unit, camera_pos, camera_forward, min_dot) then
            if can_see_head(enemy.unit, camera_pos) then
                look_at_enemy_head(enemy.unit, player, camera_pos, recoil_pitch, recoil_yaw)
                has_target = true
                return
            end
        end
    end
    
    has_target = false
end

mod.toggle_aim = function(is_pressed)
    aim_button_pressed = is_pressed
end

mod.toggle_auto_fire = function(is_pressed)
    auto_fire_pressed = is_pressed
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

-- Auto-fire logic hook (optimized with early returns)
local _get = function(self, input_service, action_name)
    local is_fire_input = (action_name == "action_one_hold" or action_name == "action_one_pressed") and input_service.type == "Ingame"
    
    if not is_fire_input then
        return self(input_service, action_name)
    end
    
    local auto_fire_enabled = mod:get("enable_auto_fire")
    local should_fire = (auto_fire_pressed or next(mod:get("auto_fire_keybind")) == nil) and has_target
    
    if auto_fire_enabled and should_fire then
        local weapon_template, fire_mode, is_ads = get_current_weapon_info()
        
        if (fire_mode == "charge" or fire_mode == "full_auto") and action_name == "action_one_hold" then
            return true
        elseif fire_mode == "semi_auto" and action_name == "action_one_pressed" then
            return true
        end
    end
    
    return self(input_service, action_name)
end

-- Hook into weapon system for auto-fire
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
    end
end)