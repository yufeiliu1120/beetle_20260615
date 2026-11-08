class_name BuffLogic
extends Resource

@export var logic_name: String = "基础状态逻辑"
@export var count:int
@export var count_bonus = 0
# ==========================================
# 状态触发接口
# 子类重写这些方法来实现具体的扣血、加血、改属性等效果
# ==========================================
func get_final_count():
	return count + count_bonus
func get_count_text():
	return str(get_final_count())
# 回合开始时触发
func apply_turn_start(caster: CombatEntity) -> void:
	pass

# 回合结束时触发
func apply_turn_end(caster: CombatEntity) -> void:
	pass
	
# (可选预留) 状态刚被赋予时触发（比如瞬间增加 10 点最大生命值）
func apply_on_attach(caster: CombatEntity) -> void:
	pass

# (可选预留) 状态持续时间结束被移除时触发（比如扣除那 10 点最大生命值）
func apply_on_detach(caster: CombatEntity) -> void:
	pass
