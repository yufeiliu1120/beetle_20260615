extends Resource
class_name ActionEffect
var target_action: ActionData = null #被动作资源赋值

#动画标记变量，被动作资源赋值
var ship_anim_name
var tile_anim_name

#此效果对应的动作，被动作资源赋值
var Action:ActionData
@export var effect_name:String #每个效果的名字标记
@export var is_on_start:bool = false #标记这个效果是在动画开始时触发还是在动画时触发
@export var base_count:int
var count_bonus:int #来自地块加成的数值，会在地块计算时被赋值
var count_influence:int #数值影响值，用来处理buff，在回合结束时清零，在每回合重新赋值

#用来获取数值字符串的函数，被ActionData调用，用于UI组件使用
func get_count_text() -> String:
	# 1. 初始化基础文本
	var text: String = str(base_count)
	
	# 2. 将所有的额外增益与减益相加，得出一个最终的修饰值
	var total_modifier: int = count_bonus + count_influence
	
	# 3. 根据最终修饰值的正负，追加带有 BBCode 颜色的文本
	if total_modifier > 0:
		# 最终为正增益：连同加号显示为绿色
		text += "[color=green] + " + str(total_modifier) + "[/color]" + " "
	elif total_modifier < 0:
		# 最终为负减益：连同减号显示为红色 (用 abs 取绝对值去掉原本的负号)
		text += "[color=red] - " + str(abs(total_modifier)) + "[/color]" + " "
		
	# 如果 total_modifier 刚好抵消为 0，则直接跳过，只返回基础文本
	return text

func get_final_count() -> int:
	var count = base_count + count_bonus + count_influence
	return count

# 获取对方动作的所有标签
func get_target_tags() -> Array[String]:
	if target_action != null:
		return target_action.get_tags() # 调用对方 ActionData 内部的接口
	return []

# 快捷判定：对方动作是否包含指定的标签
func has_target_tag(tag_name: String) -> bool:
	if target_action != null:
		return target_action.get_tags().has(tag_name)
	return false
	
func excute(caster:CombatEntity):
	pass
	
