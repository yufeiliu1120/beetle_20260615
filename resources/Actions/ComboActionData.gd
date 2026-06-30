extends ActionData
class_name ComboActionData 

@export_group("连携设置")
@export var trigger_tag: String = ""  # 要呼叫的标签
@export var put_sub_actions_on_cooldown: bool = true # 被呼叫的小弟是否要进入冷却

func excute(caster: CombatEntity) -> void:
	print("📢 [指令] 齐射协议启动！全舰搜索标签: ", trigger_tag)
	var actions_to_trigger: Array[ActionData] = []
	# 1. 遍历动作池找小弟（注意：action_pool 是在回合初由 HexGridManager 填充好的）
	for action in caster.action_pool:
		if action == self:
			continue # 安全锁：防止齐射呼叫齐射，导致无限死循环
			
		if trigger_tag in action.tags:
			actions_to_trigger.append(action)
			
	if actions_to_trigger.is_empty():
		print("未找到任何携带 [%s] 标签的地块动作。" % trigger_tag)
		return
		
	# 2. 开始执行动作
	for action in actions_to_trigger:
		if action in caster.warship.hexgridmanager.action_to_tile_map:
			caster.warship.hexgridmanager.excute_action_from_tile(action,caster)
