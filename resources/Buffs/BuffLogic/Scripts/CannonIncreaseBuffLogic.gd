extends BuffLogic
class_name CannonBuffLogic

func apply_turn_start(caster: CombatEntity) -> void:
	for action in caster.action_pool:
		if "Cannon" in action.tags:
			for effect in action.action_effects:
				if effect.effect_name == "Attack":
					effect.count_bonus += get_final_count()
