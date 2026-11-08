extends ActionEffect
class_name ComboAction

@export_group("连携设置")
@export var trigger_tag: String = ""  # 要呼叫的标签
@export var put_sub_actions_on_cooldown: bool = true
#动画标记变量，被动作资源赋值

# 改为一个全局汇总信号，不再听单个火炮的信号了
signal all_sub_actions_completed

func excute(caster: CombatEntity) -> void:
	print("全舰搜索标签: ", trigger_tag)
	var actions_to_trigger: Array[ActionData] = []
	var animation_player
	if ship_anim_name:
		animation_player = caster.warship.visual_controller.animation_player
	elif tile_anim_name:
		var tile = caster.warship.hexgridmanager.action_to_tile_map[Action]
		animation_player = tile.tile_anim_player
	else:
		push_error("动作动画名无效，无法找到动画播放器")
		return
	# 1. 遍历动作池找小弟
	for action in caster.action_pool:
		if action == Action:
			continue
		if trigger_tag in action.tags: # 注意这里要是你实际的变量名
			actions_to_trigger.append(action)
			
	if actions_to_trigger.is_empty():
		print("未找到任何携带 [%s] 标签的地块动作。" % trigger_tag)
		await caster.get_tree().create_timer(0.5).timeout
		animation_player.play()
		return
		
	# 2. 提前过滤出真正在网格里的有效动作（非常重要，确保计数器准确）
	var valid_actions: Array[ActionData] = []
	for action in actions_to_trigger:
		if action in caster.warship.hexgridmanager.action_to_tile_map:
			valid_actions.append(action)
			
	if valid_actions.is_empty():
		animation_player.play()
		return
	print(valid_actions)
	# ==========================================
	# 3. 核心机制：闭包异步计数器
	# ==========================================
	# 使用数组 [ ] 包装整数，强行让 GDScript 进行引用传递
	var pending_count = [valid_actions.size()] 
	
	# 声明一个负责单发火炮的闭包函数
	var fire_single_cannon = func(action: ActionData):
		action.target_action_tags = Action.target_action_tags
		# 在后台独自等待这门火炮打完
		await caster.warship.hexgridmanager.excute_action_from_tile(action, caster)
		
		# 打完后计数器减一
		pending_count[0] -= 1
		# 如果我是最后一门打完的炮，呼叫主程序！
		if pending_count[0] <= 0:
			all_sub_actions_completed.emit()

	# ==========================================
	# 4. 开始带延迟的扫射
	# ==========================================
	for action in valid_actions:
		# call() 是非阻塞的，火炮会在后台自己算自己的
		fire_single_cannon.call(action) 
		# 主程序只负责制造 0.2 秒的视觉间隔
		await caster.get_tree().create_timer(0.2).timeout
		
	# 5. 最终检查：如果扫射间隔全等完了，但还有火炮没打完，就挂起等待
	if pending_count[0] > 0:
		await all_sub_actions_completed
		
	# 6. 所有子弹绝对飞行完毕，安全唤醒甲虫动画！
	animation_player.play()
