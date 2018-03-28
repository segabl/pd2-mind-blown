Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInitMindBlown", function(loc)

  loc:add_localized_strings({
    menu_sniper_graze_damage = "Mind Blown",
    menu_sniper_graze_damage_desc = "BASIC: ##4 points##\nScoring a headshot with a Sniper Rifle deals ##40%## of the damage to the closest enemy in a ##5m## radius.\n\nThe effect propagates from every additional enemy hit, with subsequent damage being capped by the damage dealt to that enemy.\n\nACE: ##8 points##\nScoring a killing headshot deals ##100%## of the damage to the closest enemy in the effect radius."
  })

end)

if RequiredScript == "lib/managers/player/snipergrazedamage" then

  local TRAIL_EFFECT = Idstring("effects/particles/weapons/sniper_trail")
  local idstr_trail = Idstring("trail")
  local idstr_simulator_length = Idstring("simulator_length")
  local idstr_size = Idstring("size")
  local trail_length = World:effect_manager():get_initial_simulator_var_vector2(TRAIL_EFFECT, idstr_trail, idstr_simulator_length, idstr_size)

  local brush = Draw:brush(Color(0.1, 1, 0, 0), 2)
  function SniperGrazeDamage:on_weapon_fired(weapon_unit, result)
    if not alive(weapon_unit) or not weapon_unit:base():is_category("snp") or weapon_unit ~= managers.player:equipped_weapon_unit() or not result.hit_enemy then
      return
    end
    
    local player_unit = managers.player:player_unit()
    if not player_unit then
      return
    end

    local upgrade_value = managers.player:upgrade_value("snp", "graze_damage")
    local sentry_mask = managers.slot:get_mask("sentry_gun")
    local ally_mask = managers.slot:get_mask("all_criminals")
    local enemy_mask = managers.slot:get_mask("enemies")
    local geometry_mask = managers.slot:get_mask("world_geometry")
    local hit_enemies = {}

    for _, hit in ipairs(result.rays) do
      local is_turret = hit.unit:in_slot(sentry_mask)
      local is_ally = hit.unit:in_slot(ally_mask)

      local result = hit.damage_result
      local attack_data = result and result.attack_data
      if attack_data and attack_data.headshot and not is_turret and not is_ally then
        local multiplier = (result.type == "death" or result.type == "healed") and upgrade_value.damage_factor_headshot or upgrade_value.damage_factor
        hit_enemies[hit.unit:key()] = {
          unit = hit.unit,
          position = hit.position,
          damage = attack_data.damage * multiplier
        }
      end
    end
    
    local radius = upgrade_value.radius
    for _, hit in pairs(hit_enemies) do
      self:find_closest_hit(hit, hit_enemies, radius, enemy_mask, geometry_mask, player_unit)
    end
    
  end

  function SniperGrazeDamage:find_closest_hit(hit, hit_enemies, radius, enemy_mask, geometry_mask, player_unit)
    local hit_units = World:find_units_quick("sphere", hit.position, radius, enemy_mask)
    local closest
    local closest_d_sq
    for _, unit in ipairs(hit_units) do
      if not hit_enemies[unit:key()] then
        local d_s = mvector3.distance_sq(hit.position, unit:movement():m_head_pos())
        if not closest_d_sq or d_s < closest_d_sq then
          if not World:raycast("ray", hit.position, unit:movement():m_head_pos(), "slot_mask", geometry_mask) then
            closest = unit
            closest_d_sq = d_s
          end
        end
      end
    end
    if closest then
      local hit_pos = Vector3()
      mvector3.set(hit_pos, closest:movement():m_head_pos())

      --brush:cylinder(hit.position, hit_pos, 5)
      local trail = World:effect_manager():spawn({
        effect = Idstring("effects/particles/weapons/sniper_trail"),
        position = hit.position,
        normal = hit_pos - hit.position
      })
      mvector3.set_y(trail_length, math.sqrt(closest_d_sq))
      World:effect_manager():set_simulator_var_vector2(trail, idstr_trail, idstr_simulator_length, idstr_size, trail_length)

      hit_enemies[closest:key()] = data

      DelayedCalls:Add("grazehit" .. tostring(closest), 0.1, function ()
        if not alive(closest) or not alive(player_unit) then
          return
        end
        
        local result = closest:character_damage():damage_simple({
          variant = "graze",
          damage = hit.damage,
          attacker_unit = player_unit,
          pos = hit_pos,
          attack_dir = hit_pos - hit.position
        })

        data = {
          unit = closest,
          position = hit_pos,
          damage = result and result.damage or hit.damage
        }
      
        self:find_closest_hit(data, hit_enemies, radius, enemy_mask, geometry_mask, player_unit)
      end)

    end
  
  end

end

if RequiredScript == "lib/tweak_data/upgradestweakdata" then

  local _weapon_definitions_original = UpgradesTweakData._weapon_definitions
  function UpgradesTweakData:_weapon_definitions(...)
    _weapon_definitions_original(self, ...)
    
    self.values.snp.graze_damage = {
      {
        radius = 500,
        damage_factor = 0.4,
        damage_factor_headshot = 0.4
      },
      {
        radius = 500,
        damage_factor = 0.4,
        damage_factor_headshot = 1
      }
    }
  end

end