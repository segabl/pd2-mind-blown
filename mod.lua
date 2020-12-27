Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInitMindBlown", function(loc)

	loc:add_localized_strings({
		menu_sniper_graze_damage = "Mind Blown",
		menu_sniper_graze_damage_desc = "BASIC: ##4 points##\nScoring a headshot with a Sniper Rifle deals ##50%## of the damage to the closest enemy in a ##4m## radius, chaining up to ##4## times.\n\nACE: ##8 points##\nAny killing headshot with a Sniper Rifle now deals ##100%## of the damage to the closest enemy and the effect can now chain up to ##8## times."
	})

end)

if RequiredScript == "lib/managers/player/snipergrazedamage" then

	local TRAIL_EFFECT = Idstring("effects/particles/weapons/sniper_trail")
	local idstr_trail = Idstring("trail")
	local idstr_simulator_length = Idstring("simulator_length")
	local idstr_size = Idstring("size")
	local trail_length

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
		local ignored_enemies = {}

		for _, hit in ipairs(result.rays) do
			local is_turret = hit.unit:in_slot(sentry_mask)
			local is_ally = hit.unit:in_slot(ally_mask)

			local result = hit.damage_result
			local attack_data = result and result.attack_data
			if attack_data and attack_data.headshot and not is_turret and not is_ally then
				local multiplier = (result.type == "death" or result.type == "healed") and upgrade_value.damage_factor_kill or upgrade_value.damage_factor
				local key = hit.unit:key()
				hit_enemies[key] = {
					position = hit.position,
					damage = attack_data.damage * multiplier
				}
				ignored_enemies[key] = true
			end
		end
		
		local radius = upgrade_value.radius
		for _, hit in pairs(hit_enemies) do
			self:find_closest_hit(hit, ignored_enemies, upgrade_value, enemy_mask, geometry_mask, player_unit, upgrade_value.times)
		end
		
	end

	function SniperGrazeDamage:find_closest_hit(hit, ignored_enemies, upgrade_value, enemy_mask, geometry_mask, player_unit, times)
		if times <= 0 then
			return
		end
		DelayedCalls:Add("grazehit" .. tostring(hit), 0.05, function ()
			local hit_units = World:find_units_quick("sphere", hit.position, upgrade_value.radius, enemy_mask)
			local closest
			local closest_d_sq = math.huge
			for _, unit in ipairs(hit_units) do
				if not ignored_enemies[unit:key()] then
					local d_s = mvector3.distance_sq(hit.position, unit:movement():m_head_pos())
					if d_s < closest_d_sq and not World:raycast("ray", hit.position, unit:movement():m_head_pos(), "slot_mask", geometry_mask) then
						closest = unit
						closest_d_sq = d_s
					end
				end
			end

			if not closest then
				return
			end

			ignored_enemies[closest:key()] = true

			local hit_pos = Vector3()
			mvector3.set(hit_pos, closest:movement():m_head_pos())

			if not trail_length then
				trail_length = World:effect_manager():get_initial_simulator_var_vector2(TRAIL_EFFECT, idstr_trail, idstr_simulator_length, idstr_size)
			end
			local trail = World:effect_manager():spawn({
				effect = Idstring("effects/particles/weapons/sniper_trail"),
				position = hit.position,
				normal = hit_pos - hit.position
			})
			mvector3.set_y(trail_length, math.sqrt(closest_d_sq))
			World:effect_manager():set_simulator_var_vector2(trail, idstr_trail, idstr_simulator_length, idstr_size, trail_length)

			local result = closest:character_damage():damage_simple({
				variant = "graze",
				damage = hit.damage,
				attacker_unit = player_unit,
				pos = hit_pos,
				attack_dir = hit_pos - hit.position
			})

			hit = {
				position = hit_pos,
				damage = hit.damage
			}
		
			self:find_closest_hit(hit, ignored_enemies, upgrade_value, enemy_mask, geometry_mask, player_unit, times - 1)
		end)
	end

end

if RequiredScript == "lib/tweak_data/upgradestweakdata" then

	Hooks:PostHook(UpgradesTweakData, "_weapon_definitions", "_weapon_definitions_mb", function (self)
		self.values.snp.graze_damage = {
			{
				radius = 400,
				times = 4,
				damage_factor = 0.5,
				damage_factor_kill = 0.5
			},
			{
				radius = 400,
				times = 8,
				damage_factor = 0.5,
				damage_factor_kill = 1
			}
		}
	end)

end