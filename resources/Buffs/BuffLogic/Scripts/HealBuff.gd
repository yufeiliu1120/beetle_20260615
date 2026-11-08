extends BuffLogic
class_name HealBuffLogic

func apply_turn_start(caster: CombatEntity) -> void:
	caster.current_hp += get_final_count()
