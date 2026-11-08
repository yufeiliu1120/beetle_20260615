extends BuffLogic
class_name BaseDamageBuffLogic

func apply_turn_start(caster: CombatEntity) -> void:
	for action in caster.action_pool:
		if "Attack" in action.tags:
			for effect in action.action_effects:
				if effect != null and effect.effect_name == "Attack":
					# 【修复】：使用 influence！保证回合结束自动清除，不会越叠越高
					effect.count_influence += get_final_count()
