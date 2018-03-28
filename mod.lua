Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInitMindBlown", function(loc)

  loc:add_localized_strings({
    menu_sniper_graze_damage = "Mind Blown",
    menu_sniper_graze_damage_desc = "BASIC: ##4 points##\nScoring a headshot with a Sniper Rifle deals up to ##50%## of the damage in a ##3m## radius around the bullet impact.\n\nACE: ##8 points##\nThe effect radius is increased by ##65%##.\nScoring a killing headshot deals up to ##100%## of the damage in the effect radius."
  })

end)

if RequiredScript == "lib/managers/player/snipergrazedamage" then

  local brush = Draw:brush(Color(0.2, 1, 0, 0), 1)
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
      --brush:sphere(hit.position, radius)
      local hit_units = World:find_units_quick("sphere", hit.position, radius, enemy_mask)
      for _, unit in ipairs(hit_units) do
        if not hit_enemies[unit:key()] then
          local hit_pos = Vector3()
          mvector3.set(hit_pos, unit:movement():m_head_pos())
          local percentage = 1 - math.min(1, math.max(0, (mvector3.distance(hit.position, hit_pos) - 100) / radius))
          if World:raycast("ray", hit.position, hit_pos, "slot_mask", geometry_mask) then
            percentage = percentage - 0.5
          end
          if percentage > 0 then
            unit:character_damage():damage_simple({
              variant = "graze",
              damage = percentage * hit.damage,
              attacker_unit = player_unit,
              pos = hit_pos,
              attack_dir = hit.position - hit_pos
            })
          end
        end
      end
    end
    
  end

end

if RequiredScript == "lib/tweak_data/upgradestweakdata" then

  local _weapon_definitions_original = UpgradesTweakData._weapon_definitions
  function UpgradesTweakData:_weapon_definitions(...)
    _weapon_definitions_original(self, ...)
    
    self.values.snp.graze_damage = {
      {
        radius = 300,
        damage_factor = 0.5,
        damage_factor_headshot = 0.5
      },
      {
        radius = 500,
        damage_factor = 0.5,
        damage_factor_headshot = 1
      }
    }
  end

end