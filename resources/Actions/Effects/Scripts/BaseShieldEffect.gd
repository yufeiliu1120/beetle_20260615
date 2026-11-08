extends ActionEffect
class_name BaseShieldAction
func excute(caster):
	var count = get_final_count()
	caster.add_shield(count)
	#影响值触发后就清零，方便每回合计算buff
