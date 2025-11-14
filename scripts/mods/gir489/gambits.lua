local mod = get_mod("gir489")
local aim_button_pressed = false

local HALF_PI = math.pi / 2

-- Get all active enemy threats
local function get_all_enemies()
    local extension_manager = Managers.state and Managers.state.extension
    if not extension_manager then
        return {}
    end
    
    local Breed = require("scripts/utilities/breed")
    local enemies = {}
    local n = 0
    
    for unit, _ in pairs(extension_manager:units()) do
        if Unit.alive(unit) then
            local health_ext = ScriptUnit.has_extension(unit, "health_system") and 
                              ScriptUnit.extension(unit, "health_system")
            
            if health_ext and health_ext:is_alive() then
                local unit_data_ext = ScriptUnit.has_extension(unit, "unit_data_system") and
                                     ScriptUnit.extension(unit, "unit_data_system")
                
                if unit_data_ext then
                    local breed = unit_data_ext:breed()
                    
                    if breed and not Breed.is_player(breed) and not breed.name:find("hazard") then
                        n = n + 1
                        enemies[n] = {
                            unit = unit,
                            breed = breed.name,
                            position = POSITION_LOOKUP[unit]
                        }
                    end
                end
            end
        end
    end
    
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
    local priority_specials = get_priority_specials()
    
    -- Only calculate camera rotation if FoV check is enabled
    local camera_forward, fov_angle
    if fov_check_enabled then
        local camera_rot = Managers.state.camera:camera_rotation(player.viewport_name)
        camera_forward = Quaternion.forward(camera_rot)
        fov_angle = mod:get("fov_angle")
    end
    
    -- Find and aim at priority targets
    local enemies = get_all_enemies()
    for i = 1, #enemies do
        local enemy = enemies[i]
        if priority_specials[enemy.breed] then
            -- Only check FoV if enabled
            if not fov_check_enabled or is_in_fov(enemy.unit, camera_pos, camera_forward, fov_angle) then
                if can_see_head(enemy.unit, camera_pos) then
                    look_at_enemy_head(enemy.unit, player, camera_pos, recoil_pitch, recoil_yaw)
                    return
                end
            end
        end
    end
end

mod.toggle_aim = function()
    aim_button_pressed = not aim_button_pressed -- true when held, false when released
end

-- Hook into update
mod:hook_safe("PlayerUnitFirstPersonExtension", "fixed_update", function(self, unit, dt, t, frame)
    local player = Managers.player:local_player(1)
    if player and player:unit_is_alive() then
        local use_mouse2 = mod:get("use_mouse2_fallback")

        if (use_mouse2 and Mouse.button(Mouse.button_index("right")) > 0.5) or (not use_mouse2 and aim_button_pressed) then
            auto_aim_priority_targets(unit)
        end
    end
end)