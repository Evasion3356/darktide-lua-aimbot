local mod = get_mod("darktide-lua-aimbot")
local Action = require("scripts/utilities/action/action")
local HitZone = require("scripts/utilities/attack/hit_zone")

-- Constants
local HALF_PI = math.pi / 2
local DAEMONHOST_PASSIVE_STAGE = 1

-- State variables
local aim_button_pressed = false
local triggerbot_pressed = false
local has_target = false
local locked_target_unit = nil  -- Locked target to prevent oscillation

-- Cache frequently accessed values
local math_rad = math.rad
local math_cos = math.cos
local math_atan2 = math.atan2
local math_asin = math.asin
local Vector3_normalize = Vector3.normalize
local Vector3_dot = Vector3.dot
local Vector3_length = Vector3.length

local log_debug = true
local log_phv = true  -- Enable process_hits_visibility debug logs for debugging

function log_to_console(message)
    local dmf = get_mod("DMF")
    if log_debug and dmf:get("show_developer_console") then
        -- Filter out PHV logs if disabled
        if log_phv or not message:find("%[PHV%]") then
            print(message)
        end
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

local AttackSettings = require("scripts/settings/damage/attack_settings")
local Breed = require("scripts/utilities/breed")
local DamageProfile = require("scripts/utilities/attack/damage_profile")
local Dodge = require("scripts/extension_systems/character_state_machine/character_states/utilities/dodge")
local DodgeSettings = require("scripts/settings/dodge/dodge_settings")
local RangedAction = require("scripts/utilities/action/ranged_action")
local HitMass = require("scripts/utilities/attack/hit_mass")
local Weakspot = require("scripts/utilities/attack/weakspot")
local HazardProp = require("scripts/utilities/level_props/hazard_prop")
local Health = require("scripts/utilities/health")
local ObjectPenetration = require("scripts/utilities/attack/object_penetration")

local attack_types = AttackSettings.attack_types
local dodge_types = DodgeSettings.dodge_types

-- Helper: process hits similar to HitScan.process_hits but without side effects
local HitScan = require("scripts/utilities/attack/hit_scan")
local Sprint = require("scripts/extension_systems/character_state_machine/character_states/utilities/sprint")

-- Helper: process hits similar to HitScan.process_hits but without side effects
-- Returns: "visible" if target is directly visible, "penetrable" if target is behind wall but reachable, false otherwise
local function process_hits_visibility(is_server, world, physics_world, attacker_unit, hits, position, direction, max_distance, optional_is_local_unit, optional_player, hit_scan_template, target_unit)
    if not hits then
        return false
    end

    log_to_console("[PHV] process_hits_visibility called, hits_count=" .. tostring(#hits) .. " target=" .. tostring(target_unit))

    local HIT_UNITS = {}
    HIT_UNITS[attacker_unit] = true

    local damage_config = hit_scan_template and hit_scan_template.damage
    local impact_config = damage_config and damage_config.impact
    local penetration_config = damage_config and damage_config.penetration
    local damage_profile = damage_config and impact_config and impact_config.damage_profile

    -- If no penetration config exists, create a default one for visibility checks
    -- This allows the aimbot to see through thin walls even if the weapon doesn't penetrate
    if not penetration_config then
        log_to_console("[PHV] No penetration_config found, using default")
        penetration_config = {
            depth = 0.5,  -- 0.5 meters default penetration for visibility
            destroy_on_exit = false
        }
    end

    -- follow engine style for optional attacker breed
    local optional_attacker_data_extension = ScriptUnit.has_extension(attacker_unit, "unit_data_system") and ScriptUnit.extension(attacker_unit, "unit_data_system")
    local optional_attacker_breed = optional_attacker_data_extension and optional_attacker_data_extension:breed()
    local is_attacker_player = Breed.is_player(optional_attacker_breed)

    local damage_profile_lerp_values = nil
    local hit_mass_budget_attack, hit_mass_budget_impact = nil, nil

    if damage_profile then
        damage_profile_lerp_values = DamageProfile.lerp_values(damage_profile, attacker_unit)
        hit_mass_budget_attack, hit_mass_budget_impact = DamageProfile.max_hit_mass(damage_profile, 1, 0, damage_profile_lerp_values, false, attacker_unit, attack_types.ranged)
    end

    local exit_distance = 0
    local penetrated = false
    local try_penetration = penetration_config ~= nil  -- Now always true with default config
    local target_found_directly = false  -- Track if target is directly visible (no penetration needed)

    -- iterate in distance order - use while loop so we can process newly added hits
    local index = 1
    while index <= #hits do
        local hit = hits[index]
        local hit_position = hit.position or hit[1]
        local hit_distance = hit.distance or hit[2] or 0
        local hit_actor = hit.actor or hit[4]

        log_to_console("[PHV] Hit[" .. index .. "] dist=" .. tostring(hit_distance) .. " actor_present=" .. tostring(hit_actor ~= nil) .. " pos=" .. tostring(hit_position))

        -- Skip hits inside penetrated object
        if hit_distance < exit_distance then
            log_to_console("[PHV] Hit[" .. index .. "] behind exit_distance=" .. tostring(exit_distance) .. ", skipping")
            goto continue
        end

        if hit_actor then
            local hit_unit = Actor.unit(hit_actor)

            log_to_console("[PHV] Hit[" .. index .. "] actor unit=" .. tostring(hit_unit))

            if HIT_UNITS[hit_unit] then
                log_to_console("[PHV] Hit[" .. index .. "] unit already in HIT_UNITS, skipping")
                goto continue
            end

            local hit_zone_name = HitZone.get_name(hit_unit, hit_actor)
            local hit_afro = hit_zone_name == HitZone.hit_zone_names.afro
            local target_breed_or_nil = Breed.unit_breed_or_nil(hit_unit)
            local is_damagable = Health.is_damagable(hit_unit)
            local target_is_hazard_prop, hazard_prop_is_active = HazardProp.status(hit_unit)

            log_to_console("[PHV] Hit[" .. index .. "] zone=" .. tostring(hit_zone_name) .. " breed=" .. tostring(target_breed_or_nil and target_breed_or_nil.name) .. " damagable=" .. tostring(is_damagable) .. " hazard_prop=" .. tostring(target_is_hazard_prop))

            -- Check if this is actually a static/environment hit (has actor but not damagable and no breed)
            -- This happens when walls/environment have actors attached
            if not is_damagable and not target_breed_or_nil and not target_is_hazard_prop then
                log_to_console("[PHV] Hit[" .. index .. "] actor is static environment (not damagable, no breed)")
                -- Treat as environment hit - jump to penetration logic below
                goto handle_environment_hit
            end

            -- Ragdoll handling: treat as occlusion
            if Health.is_ragdolled(hit_unit) then
                log_to_console("[PHV] Hit[" .. index .. "] unit is ragdolled")
                if hit_afro then
                    log_to_console("[PHV] Hit[" .. index .. "] afro hit on ragdoll - continue")
                    goto continue
                end

                log_to_console("[PHV] Hit[" .. index .. "] ragdoll treated as occlusion -> return false")
                return false
            elseif is_damagable then
                -- faded player check
                if is_attacker_player and HitScan and HitScan.inside_faded_player and HitScan.inside_faded_player(target_breed_or_nil, hit_distance) then
                    log_to_console("[PHV] Hit[" .. index .. "] inside faded player - continue")
                    goto continue
                end

                if not target_is_hazard_prop then
                    -- dodge handling: treat dodging as occlusion
                    local is_undodgeable = damage_profile and damage_profile.undodgeable

                    if not is_undodgeable and is_server then
                        local is_dodging, dodge_type = Dodge.is_dodging(hit_unit, attack_types.ranged)
                        local is_sprint_dodging = Sprint and Sprint.is_sprint_dodging and Sprint.is_sprint_dodging(hit_unit, attacker_unit, damage_profile and damage_profile.run_away_dodge)

                        log_to_console("[PHV] Hit[" .. index .. "] dodging=" .. tostring(is_dodging) .. " sprint_dodging=" .. tostring(is_sprint_dodging))

                        if is_dodging or is_sprint_dodging then
                            HIT_UNITS[hit_unit] = true
                            log_to_console("[PHV] Hit[" .. index .. "] dodging treated as occlusion -> return false")
                            return false
                        end
                    end

                    if hit_afro then
                        log_to_console("[PHV] Hit[" .. index .. "] afro hit - skipping")
                        goto continue
                    end
                end

                local hit_weakspot = Weakspot.hit_weakspot(target_breed_or_nil, hit_zone_name, attacker_unit)

                -- Check if this is the target unit FIRST before hit mass checks
                if hit_unit == target_unit then
                    log_to_console("[PHV] Hit[" .. index .. "] hit is target unit")
                    if hit_zone_name == HitZone.hit_zone_names.shield then
                        log_to_console("[PHV] Hit[" .. index .. "] hit shield -> return false")
                        return false
                    end
                    if hit_zone_name == HitZone.hit_zone_names.head then
                        log_to_console("[PHV] Hit[" .. index .. "] head hit on target -> return visible")
                        target_found_directly = true  -- Mark as directly visible
                        return "visible"
                    end

                    -- hit other zone on same unit: skip this and continue looking
                    -- The target might be behind a penetrable wall and appear again in secondary raycast
                    log_to_console("[PHV] Hit[" .. index .. "] hit non-head zone on target, but continuing to check for penetration")
                    HIT_UNITS[hit_unit] = true
                    goto continue
                end

                -- Only do hit mass checks for non-target units
                if damage_profile then
                    log_to_console("[PHV] Hit[" .. index .. "] consuming hit mass budgets")
                    hit_mass_budget_attack, hit_mass_budget_impact = HitMass.consume_hit_mass(attacker_unit, hit_unit, hit_mass_budget_attack, hit_mass_budget_impact, hit_weakspot, false, attack_types.ranged)
                    local stop = HitMass.stopped_attack(hit_unit, hit_zone_name, hit_mass_budget_attack, hit_mass_budget_impact, impact_config)

                    log_to_console("[PHV] Hit[" .. index .. "] stopped_attack=" .. tostring(stop))

                    if stop then
                        log_to_console("[PHV] Hit[" .. index .. "] stopped the ray (non-target) -> return false")
                        return false
                    end
                end

                -- not target unit: if it didn't stop the ray, mark as hit and continue (penetrable)
                log_to_console("[PHV] Hit[" .. index .. "] hit other (damagable) unit before target - marking and continuing")
                HIT_UNITS[hit_unit] = true
                goto continue
            else
                -- non-damagable actor that's NOT a static environment -> occlusion
                log_to_console("[PHV] Hit[" .. index .. "] non-damagable non-static actor occludes -> return false")
                return false
            end
        end
        
        -- Label for environment/static hit handling (can jump here from above)
        ::handle_environment_hit::
        do
            -- environment/static hit - THIS IS WHERE PENETRATION HAPPENS
            log_to_console("[PHV] Hit[" .. index .. "] environment/static hit at dist=" .. tostring(hit_distance))
            log_to_console("[PHV] Hit[" .. index .. "] try_penetration=" .. tostring(try_penetration) .. " penetrated=" .. tostring(penetrated))
            log_to_console("[PHV] Hit[" .. index .. "] hit_scan_template=" .. tostring(hit_scan_template))
            log_to_console("[PHV] Hit[" .. index .. "] damage_config=" .. tostring(damage_config))
            log_to_console("[PHV] Hit[" .. index .. "] impact_config=" .. tostring(impact_config))
            log_to_console("[PHV] Hit[" .. index .. "] penetration_config=" .. tostring(penetration_config))
            
            if penetration_config then
                log_to_console("[PHV] Hit[" .. index .. "] penetration_config.depth=" .. tostring(penetration_config.depth))
                log_to_console("[PHV] Hit[" .. index .. "] penetration_config.destroy_on_exit=" .. tostring(penetration_config.destroy_on_exit))
            end
            
            -- Try penetration if enabled and not already penetrated
            if try_penetration and not penetrated then
                log_to_console("[PHV] Hit[" .. index .. "] attempting penetration depth=" .. tostring(penetration_config.depth))
                local exit_pos, exit_normal, exit_unit = ObjectPenetration.test_for_penetration(physics_world, hit_position, direction, penetration_config.depth)

                if exit_pos then
                    -- Successfully penetrated!
                    local object_thickness = Vector3.distance(hit_position, exit_pos)
                    exit_distance = hit_distance + object_thickness
                    penetrated = true
                    try_penetration = false  -- Only penetrate once
                    
                    log_to_console("[PHV] Hit[" .. index .. "] penetrated object thickness=" .. tostring(object_thickness) .. " new exit_distance=" .. tostring(exit_distance))
                    
                    -- CRITICAL: After penetrating, we need to raycast AGAIN from the exit point
                    -- to find targets beyond the wall
                    local remaining_distance = max_distance - exit_distance
                    if remaining_distance > 0.1 then
                        log_to_console("[PHV] Hit[" .. index .. "] doing secondary raycast from exit point, remaining_dist=" .. tostring(remaining_distance))
                        
                        -- Raycast from exit point to find enemies beyond
                        local HitScan = require("scripts/utilities/attack/hit_scan")
                        local secondary_hits_dynamics = HitScan.raycast(physics_world, exit_pos, direction, remaining_distance, nil, "filter_player_character_shooting_raycast_dynamics", 0, optional_is_local_unit, optional_player, false)
                        
                        if secondary_hits_dynamics and #secondary_hits_dynamics > 0 then
                            log_to_console("[PHV] Hit[" .. index .. "] secondary raycast found " .. #secondary_hits_dynamics .. " hits")
                            
                            -- Insert secondary hits into main hits array AFTER current position
                            -- Insert in reverse order so they maintain correct order after insertion
                            for i = #secondary_hits_dynamics, 1, -1 do
                                local sec_hit = secondary_hits_dynamics[i]
                                -- Adjust distance to be relative to original start position
                                local original_dist = sec_hit.distance or sec_hit[2] or 0
                                local adjusted_dist = exit_distance + original_dist
                                
                                -- Create a new hit table with adjusted distance
                                local adjusted_hit = {}
                                for k, v in pairs(sec_hit) do
                                    adjusted_hit[k] = v
                                end
                                adjusted_hit.distance = adjusted_dist
                                adjusted_hit[2] = adjusted_dist
                                
                                table.insert(hits, index + 1, adjusted_hit)
                                log_to_console("[PHV] Hit[" .. index .. "] added secondary hit at adjusted dist=" .. tostring(adjusted_dist))
                            end
                            
                            -- Update the total number of hits to process
                            log_to_console("[PHV] Hit[" .. index .. "] total hits after insertion: " .. #hits)
                        end
                    end
                    
                    -- Check if we should destroy on exit
                    if penetration_config.destroy_on_exit then
                        log_to_console("[PHV] Hit[" .. index .. "] destroy_on_exit -> return false")
                        return false
                    end
                    
                    -- Continue to process hits beyond the exit point (including newly added secondary hits)
                    goto continue
                else
                    log_to_console("[PHV] Hit[" .. index .. "] penetration failed, occluded")
                end
            end

            -- If we couldn't penetrate, this is an occlusion
            log_to_console("[PHV] Hit[" .. index .. "] environment occludes -> return false")
            return false
        end

        ::continue::
        index = index + 1
    end

    -- If we got here without returning, check if we found the target through penetration
    if HIT_UNITS[target_unit] and not target_found_directly then
        log_to_console("[PHV] process_hits_visibility finished target found through penetration -> return penetrable")
        return "penetrable"
    end

    log_to_console("[PHV] process_hits_visibility finished no valid head hit found -> return false")
    return false
end

-- Check if player can see enemy's head
local function can_see_head(enemy_unit, player)
    local head_node = Unit.node(enemy_unit, "j_head")
    if not head_node then
        return false
    end

    -- Use first person component position for raycasting (where weapon actually fires from)
    local unit_data_ext = ScriptUnit.extension(player.player_unit, "unit_data_system")
    local first_person_component = unit_data_ext:read_component("first_person")
    local shooting_pos = first_person_component.position

    local head_pos = Unit.world_position(enemy_unit, head_node)
    local dir = head_pos - shooting_pos
    local dist = Vector3_length(dir)
    dir = Vector3_normalize(dir)

    local physics_world = World.physics_world(Application.main_world())
    local max_distance = dist

    -- Determine hit_scan_template from weapon
    local hit_scan_template = nil
    do
        local unit_data_extension = ScriptUnit.has_extension(player.player_unit, "unit_data_system") and ScriptUnit.extension(player.player_unit, "unit_data_system")
        if unit_data_extension then
            local weapon_action_component = unit_data_extension:read_component("weapon_action")
            if weapon_action_component then
                local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")
                local weapon_template = WeaponTemplate.current_weapon_template(weapon_action_component)

                if weapon_template then
                    -- Get current action settings (like FlamerGasEffects does)
                    local Action = require("scripts/utilities/action/action")
                    local action_settings = Action.current_action_settings_from_component(weapon_action_component, weapon_template.actions)

                    -- Try to get fire_configuration
                    local fire_config = nil
                    if action_settings then
                        fire_config = action_settings.fire_configuration or
                                    (action_settings.fire_configurations and action_settings.fire_configurations[1])
                    end

                    -- Fallback to checking specific actions if no current action
                    if not fire_config and weapon_template.actions then
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

                    if fire_config and fire_config.hit_scan_template then
                        hit_scan_template = fire_config.hit_scan_template
                    elseif weapon_template.hit_scan_template then
                        hit_scan_template = weapon_template.hit_scan_template
                    end

                    if hit_scan_template and hit_scan_template.range then
                        max_distance = math.max(max_distance, hit_scan_template.range)
                    end
                end
            end
        end
    end

    local HitScan = require("scripts/utilities/attack/hit_scan")

    -- Do TWO raycasts and merge results:
    -- 1. Dynamics (enemies, players)
    local hits_dynamics = HitScan.raycast(physics_world, shooting_pos, dir, max_distance, nil, "filter_player_character_shooting_raycast_dynamics", 0, true, player, false)

    log_to_console("[HEAD] Raycast from " .. tostring(shooting_pos) .. " to head, direction=" .. tostring(dir) .. ", max_dist=" .. tostring(max_distance))
    log_to_console("[HEAD] Total hits from dynamics raycast: " .. tostring(hits_dynamics and #hits_dynamics or 0))

    -- Check all hits for the target and look for a head hit
    local target_found = false
    local target_zone_name = nil
    local head_distance = math.huge

    if hits_dynamics then
        for i = 1, #hits_dynamics do
            local hit = hits_dynamics[i]
            local actor = hit.actor or hit[4]
            local hit_dist = hit.distance or hit[2] or 0
            if actor then
                local unit = Actor.unit(actor)
                if unit == enemy_unit then
                    -- Found a hit on the target
                    local zone_name = HitZone.get_name(unit, actor)
                    log_to_console("[HEAD] Hit[" .. i .. "] distance=" .. tostring(hit_dist) .. " on target, zone=" .. tostring(zone_name))

                    target_found = true

                    -- Shield blocks targeting completely
                    if zone_name == HitZone.hit_zone_names.shield then
                        log_to_console("[HEAD] Target has shield -> NOT VISIBLE")
                        return false
                    end

                    -- If it's a head hit, record the distance
                    if zone_name == HitZone.hit_zone_names.head then
                        head_distance = hit_dist
                        log_to_console("[HEAD] Head hit found at distance " .. tostring(head_distance))
                    end

                    -- Record the first non-head zone we hit (for logging)
                    if not target_zone_name then
                        target_zone_name = zone_name
                    end
                    -- Continue iterating to find a head hit
                end
            end
        end
    end

    if not target_found then
        log_to_console("[HEAD] Target not found in raycast at all")
        return false
    end

    if head_distance == math.huge then
        log_to_console("[HEAD] No head hit found (first hit was " .. tostring(target_zone_name) .. "), target not visible")
        return false
    end

    -- 2. Statics (walls, floors, environment) - check if wall is blocking the head
    local hits_statics = PhysicsWorld.raycast(physics_world, shooting_pos, dir, max_distance, "all", "types", "statics", "max_hits", 256, "collision_filter", "filter_player_character_shooting_raycast_statics")

    -- Check if the first wall is closer than the head
    local first_wall_distance = math.huge
    local first_wall_position = nil
    if hits_statics and #hits_statics > 0 then
        first_wall_distance = hits_statics[1].distance or hits_statics[1][2] or math.huge
        first_wall_position = hits_statics[1].position or hits_statics[1][1]
        log_to_console("[HEAD] First wall at distance " .. tostring(first_wall_distance) .. ", head at distance " .. tostring(head_distance))
    end

    -- If head is closer than any wall, it's visible
    if head_distance < first_wall_distance then
        log_to_console("[HEAD] Head is closer than wall -> VISIBLE")
        return "visible"
    end

    -- Head is blocked by wall, try penetration
    log_to_console("[HEAD] Wall is blocking head, attempting penetration...")
    local ObjectPenetration = require("scripts/utilities/attack/object_penetration")

    -- Get penetration depth from weapon template
    local penetration_depth = 0.75  -- default fallback
    if hit_scan_template and hit_scan_template.damage and hit_scan_template.damage.penetration then
        penetration_depth = hit_scan_template.damage.penetration.depth or 0.75
    end

    -- Try to penetrate through the wall
    local exit_pos, exit_normal, exit_unit = ObjectPenetration.test_for_penetration(physics_world, first_wall_position, dir, penetration_depth)

    if not exit_pos then
        log_to_console("[HEAD] Penetration failed -> NOT VISIBLE")
        return false
    end

    -- Penetration succeeded, check if head is beyond the wall
    local object_thickness = Vector3_length(exit_pos - first_wall_position)
    local exit_distance = first_wall_distance + object_thickness

    log_to_console("[HEAD] Penetrated wall, thickness=" .. tostring(object_thickness) .. ", exit_distance=" .. tostring(exit_distance) .. ", head_distance=" .. tostring(head_distance))

    if head_distance > exit_distance then
        -- Head is beyond the penetrated wall
        log_to_console("[HEAD] Head is beyond wall exit -> PENETRABLE")
        return "penetrable"
    else
        log_to_console("[HEAD] Head is still in wall thickness -> NOT VISIBLE")
        return false
    end
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

    -- Apply recoil/sway to rotation (like the game does)
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

    local HitScan = require("scripts/utilities/attack/hit_scan")
    local physics_world = World.physics_world(Application.main_world())

    local max_distance = 150
    local hit_scan_template = nil
    do
        local unit_data_extension = ScriptUnit.has_extension(player.player_unit, "unit_data_system") and ScriptUnit.extension(player.player_unit, "unit_data_system")
        if unit_data_extension then
            local weapon_action_component = unit_data_extension:read_component("weapon_action")
            if weapon_action_component then
                local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")
                local weapon_template = WeaponTemplate.current_weapon_template(weapon_action_component)

                if weapon_template then
                    -- Get current action settings
                    local Action = require("scripts/utilities/action/action")
                    local action_settings = Action.current_action_settings_from_component(weapon_action_component, weapon_template.actions)
                    
                    -- Try to get fire_configuration
                    local fire_config = nil
                    if action_settings then
                        fire_config = action_settings.fire_configuration or 
                                    (action_settings.fire_configurations and action_settings.fire_configurations[1])
                    end
                    
                    -- Fallback to checking specific actions if no current action
                    if not fire_config and weapon_template.actions then
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

                    if fire_config and fire_config.hit_scan_template then
                        hit_scan_template = fire_config.hit_scan_template
                    elseif weapon_template.hit_scan_template then
                        hit_scan_template = weapon_template.hit_scan_template
                    end

                    if hit_scan_template and hit_scan_template.range then
                        max_distance = hit_scan_template.range
                    end
                end
            end
        end
    end

    -- Do TWO raycasts and merge results:
    -- 1. Dynamics (enemies, players)
    local hits_dynamics = HitScan.raycast(physics_world, camera_pos, direction, max_distance, nil, "filter_player_character_shooting_raycast_dynamics", 0, true, player, false)
    -- 2. Statics (walls, floors, environment)
    local hits_statics = PhysicsWorld.raycast(physics_world, camera_pos, direction, max_distance, "all", "types", "statics", "max_hits", 256, "collision_filter", "filter_player_character_shooting_raycast_statics")
    
    -- Merge both hit arrays
    local hits = {}
    if hits_dynamics then
        for i = 1, #hits_dynamics do
            hits[#hits + 1] = hits_dynamics[i]
        end
    end
    if hits_statics then
        for i = 1, #hits_statics do
            hits[#hits + 1] = hits_statics[i]
        end
    end

    if not hits or #hits == 0 then
        return false
    end

    -- Sort by distance
    table.sort(hits, function(a, b)
        local da = a.distance or a[2] or math.huge
        local db = b.distance or b[2] or math.huge
        return da < db
    end)

    -- iterate and check each actor hit using process logic by setting target_unit to that unit when appropriate
    local Breed = require("scripts/utilities/breed")

    for i = 1, #hits do
        local hit = hits[i]
        local actor = hit.actor or hit[4]
        if actor then
            local hit_unit = Actor.unit(actor)

            if hit_unit and hit_unit ~= player.player_unit then
                if ScriptUnit.has_extension(hit_unit, "health_system") then
                    local health_ext = ScriptUnit.extension(hit_unit, "health_system")

                    if health_ext and health_ext:is_alive() then
                        local breed = Breed.unit_breed_or_nil(hit_unit)

                        if breed and not Breed.is_player(breed) and not (breed.name and breed.name:find("hazard")) then
                            -- Use process_hits_visibility but restrict to this hit_unit as target
                            local visibility = process_hits_visibility(false, World, physics_world, player.player_unit, hits, camera_pos, direction, max_distance, true, player, hit_scan_template, hit_unit)
                            if visibility then  -- true for "visible" or "penetrable"
                                return true
                            end
                        end
                    end
                end
            end
        end
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

    -- Filter out enemies with priority 0 and sort by priority (highest first: 9 -> 1)
    local valid_enemies = {}
    for i = 1, #enemies do
        if enemies[i].priority > 0 then
            table.insert(valid_enemies, enemies[i])
        end
    end

    -- Sort by priority descending (9 -> 1)
    table.sort(valid_enemies, function(a, b)
        return a.priority > b.priority
    end)

    -- Iterate through sorted priority list and find first visible or penetrable target
    local target_to_aim = nil
    for i = 1, #valid_enemies do
        local enemy = valid_enemies[i]

        if not fov_check_enabled or is_in_fov(enemy.unit, camera_pos, camera_forward, min_dot) then
            local visibility = can_see_head(enemy.unit, player)
            log_to_console("[AIM] Checking priority " .. enemy.priority .. " enemy, visibility=" .. tostring(visibility))

            -- First target that's either visible or penetrable - use it
            if visibility == "visible" or visibility == "penetrable" then
                target_to_aim = enemy.unit
                log_to_console("[AIM] Selected target with priority " .. enemy.priority .. " visibility=" .. tostring(visibility))
                break
            end
        end
    end

    if target_to_aim then
        locked_target_unit = target_to_aim
        look_at_enemy_head(target_to_aim, player, camera_pos, recoil_pitch, recoil_yaw)
        has_target = true
        return
    end

    -- No targets found
    log_to_console("[AIM] No targets found.")
    locked_target_unit = nil
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
    
    if should_aim then
        auto_aim_priority_targets(unit)
    end
end)