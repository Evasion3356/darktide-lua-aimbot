local mod = get_mod("darktide-lua-aimbot")
local Action = require("scripts/utilities/action/action")

local aim_button_pressed = false
local HALF_PI = math.pi / 2

-- Auto-fire state variables
mod._auto_fire = false
mod._last_fire_time_passed = 0
mod._release_fire_key = false
mod._weapon_action_component = false
mod._weapon_template = false

-- Get priority level for a breed
local function get_breed_priority(breed_name, unit)
    local breed_mapping = {
        -- Hound
        chaos_hound = mod:get("target_hounds"), --Pox Hound
        -- Boss Enemies
        chaos_beast_of_nurgle = mod:get("target_bosses"), --Beast of Nurgle
        chaos_plague_ogryn = mod:get("target_bosses"), --Plague Ogyrn
        chaos_spawn = mod:get("target_bosses"), --Chaos Spawn
        cultist_captain = mod:get("target_bosses"), --Admontion Champion
        renegade_captain = mod:get("target_bosses"), --Scab Captain
        renegade_twin_captain = mod:get("target_bosses"), --Rodin Karnak
        renegade_twin_captain_two = mod:get("target_bosses"), --Rinda Karnak
        chaos_daemonhost = mod:get("target_bosses"), --Daemonhost (with special check below)
        -- Trappers
        renegade_netgunner = mod:get("target_netgunners"), --Trapper
        -- Flamers
        cultist_flamer = mod:get("target_flamers"), --Dreg Tox Flamer
        renegade_flamer = mod:get("target_flamers"), --Scab Flamer
        -- Sniper
        renegade_sniper = mod:get("target_snipers"), --Sniper
        -- Bombers
        chaos_poxwalker_bomber = mod:get("target_bombers"), --Poxburster
        cultist_grenadier = mod:get("target_bombers"), --Dreg Tox Bomber
        renegade_grenadier = mod:get("target_bombers"), --Scab Bomber
        -- Gunners
        cultist_shocktrooper = mod:get("target_gunners"), --Dreg Shotgunner
        cultist_gunner = mod:get("target_gunners"), --Dreg Gunner
        renegade_gunner = mod:get("target_gunners"), --Scab Gunner
        renegade_plasma_gunner = mod:get("target_gunners"), --Scab Plasmer Gunner
        renegade_shocktrooper = mod:get("target_gunners"), --Scab Shotgunner
        -- Ragers
        cultist_berzerker = mod:get("target_berzerkers"), --Dreg Rager
        renegade_berzerker = mod:get("target_berzerkers"), --Scab Rager
        --Mauler
        renegade_executor = mod:get("target_mauler"), --Scab Mauler
        -- Mutants
        cultist_mutant = mod:get("target_mutants"), --Mutant
        cultist_mutant_mutator = mod:get("target_mutants"), --Mutant
        -- Ogryns
        chaos_ogryn_bulwark = mod:get("target_ogryns_melee"), --Bulwark
        chaos_ogryn_executor = mod:get("target_ogryns_melee"), --Crusher
        chaos_ogryn_gunner = mod:get("target_ogryns") --Reaper
    }
    
    local priority = breed_mapping[breed_name] or 0
    
    -- Special check for daemonhost - only target if NOT in passive stage (STAGES.passive = 1)
    if breed_name == "chaos_daemonhost" and priority > 0 and unit then
        local game_object_id = Managers.state.unit_spawner:game_object_id(unit)
        if game_object_id then
            local game_session = Managers.state.game_session:game_session()
            local stage = GameSession.game_object_field(game_session, game_object_id, "stage")
            if stage == 1 then
                -- Daemonhost is in passive stage, don't target it
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
    
    local Breed = require("scripts/utilities/breed")
    local enemies = {}
    local n = 0
	
    local entities = extension_manager:get_entities("MinionHuskLocomotionExtension")
    if next(entities) == nil then
        entities = extension_manager:get_entities("MinionLocomotionExtension")
		if next(entities) == nil then
			return {}
		end
    end
    
    for unit, _ in pairs(entities) do
       local health_ext = ScriptUnit.has_extension(unit, "health_system") and 
                         ScriptUnit.extension(unit, "health_system")
       
       if health_ext and health_ext:is_alive() then
           local unit_data_ext = ScriptUnit.has_extension(unit, "unit_data_system") and
                                ScriptUnit.extension(unit, "unit_data_system")
           
           if unit_data_ext then
               local breed = unit_data_ext:breed()
               
               if breed and not Breed.is_player(breed) and not breed.name:find("hazard") then
                   local priority = get_breed_priority(breed.name, unit)
                   
                   -- Only add enemies with priority > 0
                   if priority > 0 then
                       n = n + 1
                       enemies[n] = {
                           unit = unit,
                           breed = breed.name,
                           position = POSITION_LOOKUP[unit],
                           priority = priority
                       }
                   end
               end
           end
        end
    end
    
    -- Sort by priority (highest first)
    table.sort(enemies, function(a, b)
        return a.priority > b.priority
    end)
    
    return enemies
end

-- Check if enemy is within player's field of view
local function is_in_fov(enemy_unit, camera_pos, camera_forward, fov_degrees)
    local head_node = Unit.node(enemy_unit, "j_head")
    if not head_node then
        return false
    end
    
    local head_pos = Unit.world_position(enemy_unit, head_node)
    local to_enemy = Vector3.normalize(head_pos - camera_pos)
    
    local dot = Vector3.dot(camera_forward, to_enemy)
    local fov_radians = math.rad(fov_degrees / 2) -- Half angle
    local min_dot = math.cos(fov_radians)
    
    return dot >= min_dot
end

-- Check if player can see enemy's head
local function can_see_head(enemy_unit, camera_pos)
    local head_node = Unit.node(enemy_unit, "j_head")
    if not head_node then
        return false
    end
    
    local head_pos = Unit.world_position(enemy_unit, head_node)
    local dir = head_pos - camera_pos
    local dist = Vector3.length(dir)
    Vector3.normalize(dir)
    
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
    local dir = Vector3.normalize(head_pos - camera_pos)
    
    local target_yaw = math.atan2(dir.y, dir.x) - HALF_PI
    local target_pitch = math.asin(dir.z)
    
    -- Compensate for recoil
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
    
    -- Only calculate camera rotation if FoV check is enabled
    local camera_forward, fov_angle
    if fov_check_enabled then
        local camera_rot = Managers.state.camera:camera_rotation(player.viewport_name)
        camera_forward = Quaternion.forward(camera_rot)
        fov_angle = mod:get("fov_angle")
    end
    
    -- Find and aim at priority targets (already sorted by priority)
    local enemies = get_all_enemies()
    for i = 1, #enemies do
        local enemy = enemies[i]
        -- Only check FoV if enabled
        if not fov_check_enabled or is_in_fov(enemy.unit, camera_pos, camera_forward, fov_angle) then
            if can_see_head(enemy.unit, camera_pos) then
                look_at_enemy_head(enemy.unit, player, camera_pos, recoil_pitch, recoil_yaw)
                return
            end
        end
    end
end

mod.toggle_aim = function(is_pressed)
    aim_button_pressed = is_pressed
end

mod.toggle_auto_fire = function(is_pressed)
    mod._auto_fire = is_pressed
end

-- Track when weapon is equipped
local on_slot_wielded = function(weapon_extension, slot_name)
    mod._weapon_action_component = weapon_extension._weapon_action_component
    mod._weapon_template = weapon_extension._weapons[slot_name].weapon_template
end

-- Auto-fire logic hook
local _get = function(self, input_service, action_name)
    -- Only intercept primary fire action for in-game input when auto-fire is enabled
    if action_name == "action_one_hold" and input_service.type == "Ingame" and mod:get("enable_auto_fire") then
        if mod._auto_fire and not mod._release_fire_key and mod._weapon_action_component and mod._weapon_template then
            local auto_fire = false
            
            -- Get current action and settings
            local current_action_name, action_settings = Action.current_action(mod._weapon_action_component, mod._weapon_template)
            local action_chain_attack = action_settings and action_settings.allowed_chain_actions and action_settings.allowed_chain_actions.start_attack
            
            -- Check if we can chain into next attack
            if action_chain_attack and #action_chain_attack == 0 and action_chain_attack.chain_time and not action_chain_attack.chain_until then
                local player = Managers.player:local_player_safe(1)
                if player and player.player_unit then
                    local weapon_system = ScriptUnit.extension(player.player_unit, "weapon_system")
                    if weapon_system then
                        local action_handler = weapon_system._action_handler
                        local time_scale = 1
                        
                        -- Safely get time scale
                        if action_handler and action_handler._registered_components and 
                           action_handler._registered_components.weapon_action and 
                           action_handler._registered_components.weapon_action.component then
                            time_scale = action_handler._registered_components.weapon_action.component.time_scale or 1
                        end
                        
                        -- Calculate chain time with time scale
                        local chain_time = action_chain_attack.chain_time / time_scale
                        
                        -- Check if enough time has passed to chain
                        if chain_time and chain_time <= mod._last_fire_time_passed then
                            auto_fire = true
                        end
                    end
                end
            else
                -- Can always fire if no chain restrictions
                auto_fire = true
            end
            
            -- Trigger fire and reset timing
            if auto_fire then
                mod._release_fire_key = true
                mod._last_fire_time_passed = 0
                return true
            end
        end
        
        -- Reset release flag
        if mod._release_fire_key then
            mod._release_fire_key = false
        end
        
        -- Increment time tracker
        mod._last_fire_time_passed = mod._last_fire_time_passed + Managers.state.game_session.fixed_time_step
    end
    
    return self(input_service, action_name)
end

-- Hook into weapon system for auto-fire
mod:hook_safe("PlayerUnitWeaponExtension", "on_slot_wielded", on_slot_wielded)
mod:hook("InputService", "_get", _get)
mod:hook("InputService", "_get_simulate", _get)

-- Hook into update for auto-aim
mod:hook_safe("PlayerUnitFirstPersonExtension", "fixed_update", function(self, unit, dt, t, frame)
    local player = Managers.player:local_player(1)
    if player and player:unit_is_alive() then
        local use_mouse2 = mod:get("use_mouse2_fallback")

        if (use_mouse2 and Mouse.button(Mouse.button_index("right")) > 0.5) or (not use_mouse2 and aim_button_pressed) then
            auto_aim_priority_targets(unit)
        end
    end
end)