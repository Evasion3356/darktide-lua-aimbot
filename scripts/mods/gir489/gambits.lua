local mod = get_mod("darktide-lua-aimbot")

local Breed = require("scripts/utilities/breed")
local HitZone = require("scripts/utilities/attack/hit_zone")
local Recoil = require("scripts/utilities/recoil")
local Sway = require("scripts/utilities/sway")
local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")

-- Constants
local HALF_PI = math.pi / 2
local DAEMONHOST_PASSIVE_STAGE = 1

-- State variables
local aim_button_pressed = false
local triggerbot_pressed = false
local has_target = false

-- Cache frequently accessed values
local math_rad = math.rad
local math_cos = math.cos
local math_atan2 = math.atan2
local math_asin = math.asin
local Vector3_normalize = Vector3.normalize
local Vector3_dot = Vector3.dot
local Vector3_length = Vector3.length

function log_to_console(message)
    local dmf = get_mod("DMF")
    if mod:get("enable_logging") and dmf:get("show_developer_console") then
        print(message)
    end
end

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

local function can_visibly_see_target(enemy_unit, camera_pos)
    local head_node = Unit.node(enemy_unit, "j_head")
    if not head_node then return false end

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

local function is_crosshair_on_enemy()
    local player = Managers.player:local_player(1)
    if not player or not player.player_unit then
        return false
    end

    local camera_pos = Managers.state.camera:camera_position(player.viewport_name)
    local camera_rot = Managers.state.camera:camera_rotation(player.viewport_name)

    -- Apply recoil/sway
    local unit_data_ext = ScriptUnit.extension(player.player_unit, "unit_data_system")
    local weapon_extension = ScriptUnit.extension(player.player_unit, "weapon_system")
    local recoil_template = weapon_extension:recoil_template()
    local sway_template = weapon_extension:sway_template()
    local movement_state_component = unit_data_ext:read_component("movement_state")
    local recoil_component = unit_data_ext:read_component("recoil")
    local sway_component = unit_data_ext:read_component("sway")

    local ray_rotation = Recoil.apply_weapon_recoil_rotation(recoil_template, recoil_component, movement_state_component, camera_rot)
    ray_rotation = Sway.apply_sway_rotation(sway_template, sway_component, movement_state_component, ray_rotation)

    local direction = Quaternion.forward(ray_rotation)

    local physics_world = World.physics_world(Application.main_world())
    local max_distance = 300 -- or weapon range

    -- Collect statics (walls/environment)
    local hits = PhysicsWorld.raycast(
        physics_world,
        camera_pos,
        direction,
        max_distance,
        "all",
        "types", "both",
        "max_hits", 64,
        "collision_filter", "filter_player_character_shooting_raycast"
    )

    if not hits or #hits == 0 then
		log_to_console("[Triggerbot] No hits.")
        return false
    end

    -- Iterate hits in order
    for i = 1, #hits do
        local hit = hits[i]
        local actor = hit.actor or hit[4]
        if actor then
            local hit_unit = Actor.unit(actor)

			log_to_console("[Triggerbot] Unit["..tostring(i).."] :" .. tostring(hit_unit))
            -- Skip self
            if hit_unit and hit_unit ~= player.player_unit then
                -- Check if enemy is alive
                if ScriptUnit.has_extension(hit_unit, "health_system") then
                    local health_ext = ScriptUnit.extension(hit_unit, "health_system")
                    if health_ext and health_ext:is_alive() then
						log_to_console("[Triggerbot] Unit["..tostring(i).."] :" .. tostring(hit_unit) .. " is alive")
                        local breed = Breed.unit_breed_or_nil(hit_unit)
                        if breed and not Breed.is_player(breed) and not (breed.name and breed.name:find("hazard")) then
                            if (mod:get("triggerbot_respect_priority")) then
                                local priority = get_breed_priority(breed.name, hit_unit)
                                log_to_console("[Triggerbot] triggerbot_respect_priority on, checking priority: "..tostring(priority))
                                if priority == 0 then
                                    return false
                                end
                            end
							log_to_console("[Triggerbot] Unit["..tostring(i).."] :" .. tostring(hit_unit) .. " is not a hazard or a player.")
                            -- Resolve hit zone
                            local zone = HitZone.get_name(hit_unit, actor)
                            if zone == HitZone.hit_zone_names.head then
								log_to_console("[Triggerbot] Unit["..tostring(i).."] :" .. tostring(hit_unit) .. " hit head.")
								return can_visibly_see_target(hit_unit, camera_pos) --Check for walls
                            elseif not mod:get("triggerbot_weakspot_only") then
                                log_to_console("[Triggerbot] Unit["..tostring(i).."] :" .. tostring(hit_unit) .. " hit non-head weakspot only enabled.")
                                if zone and zone ~= HitZone.hit_zone_names.afro then
                                    log_to_console("[Triggerbot] Unit["..tostring(i).."] :" .. tostring(hit_unit) .. " hit something: "..tostring(zone))
                                    return can_visibly_see_target(hit_unit, camera_pos) --Check for walls
                                end
                            end
                        end
                    end
                end
            end
        end
    end
	
	log_to_console("[Triggerbot] Nothing hit.")

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
	log_to_console("[Aimbot] Begin finding enemy")
    for i = 1, #enemies do
        local enemy = enemies[i]
        
        if not fov_check_enabled or is_in_fov(enemy.unit, camera_pos, camera_forward, min_dot) then
            if can_visibly_see_target(enemy.unit, camera_pos) then
                look_at_enemy_head(enemy.unit, player, camera_pos, recoil_pitch, recoil_yaw)
                has_target = true
				log_to_console("[Aimbot] Found target.")
                return
            end
        end
    end
    
	log_to_console("[Aimbot] No target.")
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
    
    local weapon_template = WeaponTemplate.current_weapon_template(weapon_action_component)
    
    if not weapon_template then
        return nil, "full_auto", is_ads
    end
    
    local fire_mode = get_weapon_fire_mode(weapon_template, is_ads)
    return weapon_template, fire_mode, is_ads
end

-- Triggerbot logic hook (optimized with early returns)
local _get = function(self, input_service, action_name)
    local is_fire_input = (action_name == "action_one_hold" or action_name == "action_one_pressed") and input_service.type == "Ingame"
    
    if not is_fire_input then
        return self(input_service, action_name)
    end
    
    local triggerbot_enabled = mod:get("enable_triggerbot")
    
    if not triggerbot_enabled then
        return self(input_service, action_name)
    end
    
    local keybind = mod:get("triggerbot_keybind")
    local has_keybind = next(keybind) ~= nil
    local should_fire = (triggerbot_pressed or not has_keybind)
    
    log_to_console("[Triggerbot] Action: " .. action_name .. 
             " | Enabled: " .. tostring(triggerbot_enabled) ..
             " | Has keybind: " .. tostring(has_keybind) ..
             " | Pressed: " .. tostring(triggerbot_pressed) ..
             " | Should fire: " .. tostring(should_fire))
    
    if triggerbot_enabled and should_fire then
        local use_raycast = mod:get("triggerbot_use_raycast")
        log_to_console("[Triggerbot] Use raycast mode: " .. tostring(use_raycast))
        
        local can_fire = false
        
        if use_raycast then
            -- Raycast mode: fire if crosshair is directly on enemy
            can_fire = is_crosshair_on_enemy()
        else
            -- Legacy mode: fire if aimbot has locked onto target
            can_fire = has_target
            log_to_console("[Triggerbot] Legacy mode - has_target: " .. tostring(has_target))
        end
        
        log_to_console("[Triggerbot] Can fire: " .. tostring(can_fire))
        
        if can_fire then
            local weapon_template, fire_mode, is_ads = get_current_weapon_info()
            log_to_console("[Triggerbot] Fire mode: " .. tostring(fire_mode) .. " | Action: " .. action_name)
            
            if (fire_mode == "charge" or fire_mode == "full_auto") and action_name == "action_one_hold" then
                log_to_console("[Triggerbot] FIRING (hold)")
                return true
            elseif fire_mode == "semi_auto" and action_name == "action_one_pressed" then
                log_to_console("[Triggerbot] FIRING (pressed)")
                return true
            end
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
    
    has_target = false
    if should_aim then
        auto_aim_priority_targets(unit)
    end
end)