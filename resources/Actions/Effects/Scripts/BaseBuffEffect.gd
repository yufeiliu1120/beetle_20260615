extends ActionEffect
class_name BaseBuffActionEffect

@export_group("状态配置")
# 在检查器中塞入我们要赋予的 BuffData
@export var buff_data: BuffData

# ==========================================
# 核心派发逻辑
# ==========================================
func excute(caster: CombatEntity) -> void:
	if buff_data != null:
		# 直接把原始数据扔过去，复制的工作交给 CombatEntity
		caster.add_buff(buff_data)
