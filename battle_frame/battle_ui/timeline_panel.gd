extends PanelContainer
@export var timeline:VBoxContainer
# ==========================================
# VBoxContainer 级联卷帘展开效果
# @param vbox: 目标容器
# @param duration_per_item: 每个子节点展开所需的耗时（推荐 0.1 ~ 0.2 秒）
# ==========================================

# ==========================================
# 维护当前时间轴的全局动作映射表
# 格式为: [ [e_action1, p_action1, slot_node1], [e_action2, p_action2, slot_node2]... ]
# ==========================================
var timeline_action_map: Array = []
# ==========================================
# VBoxContainer 级联卷帘展开效果 (二段式横向展开版)
# ==========================================
func play_vbox_roll_down_anim(duration_per_item: float = 0.15) -> void:
	var vbox = timeline
	if vbox.has_meta("roll_tween"):
		var old_tween = vbox.get_meta("roll_tween") as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
			
	var children = vbox.get_children()
	if children.is_empty():
		return
		
	var target_heights = {}
	
	for child in children:
		if not child is Control:
			continue
		if child.has_method("collapse"):
			child.collapse(true)
		child.clip_contents = true
		var min_size = child.get_combined_minimum_size()
		target_heights[child] = min_size.y
		child.custom_minimum_size.x = min_size.x
		child.custom_maximum_size.y = 0.0
		child.modulate.a = 0.0
		child.visible = true 

	var tween = create_tween()
	vbox.set_meta("roll_tween", tween)
	
	for child in children:
		if not child is Control or not target_heights.has(child):
			continue
			
		var target_h = target_heights[child]
		
		# 动作 1：向下空投（纵向展开）
		tween.tween_property(child, "custom_maximum_size:y", target_h, duration_per_item)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			
		tween.parallel().tween_property(child, "modulate:a", 1.0, duration_per_item)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			
		# 动作 2：触底反弹（收尾并触发横向展开）
		tween.tween_callback(func(): 
			child.custom_maximum_size.y = -1.0
			child.custom_minimum_size.x = 0.0
			child.clip_contents = false
			
			# 【核心修改】：通过遍历队列，动态寻找所有嵌套的 action_slot 并展开
			var nodes_to_check: Array[Node] = [child]
			
			while nodes_to_check.size() > 0:
				var current_node = nodes_to_check.pop_front()
				
				# 命中目标类，触发展开动画
				if current_node is action_slot:
					current_node.expand(false)
					
				# 将该节点的所有子节点加入队列，继续向下扫描
				nodes_to_check.append_array(current_node.get_children())
		)
			
func collapse_all_slot_to_icon():
	for child in timeline.get_children():
		if child.has_method("collapse_to_icon"):
			child.collapse_to_icon()
			
# ==========================================
# 【修改】：将直接返回改为刷新并维护内部属性
# ==========================================
func update_all_actions_map() -> void:
	timeline_action_map.clear()
	for slot in timeline.get_children():
		if slot.has_method("get_actions"):
			var action_tuple = slot.get_actions()
			timeline_action_map.append(action_tuple)
			
	print("UI映射表已更新: ", timeline_action_map)

# 【新增辅助函数】：给外部 UI Manager 提供一个便捷的查找接口
func find_slot_by_action_pair(action_pair: Array) -> timeline_slot:
	if action_pair == null or action_pair.size() != 2:
		push_error("传入动作对格式错误")
		return null
		
	for action in action_pair:
		# 【核心修复】：允许 action 为 null，只有当它有值且不是 ActionData 时才报错
		if action != null and not action is ActionData:
			push_error("传入数组内有非动作类")
			return null
			
	for tuple in timeline_action_map:
		# tuple[0] 是敌方动作，tuple[1] 是玩家动作
		if tuple[0] == action_pair[0] and tuple[1] == action_pair[1]:
			return tuple[2] as timeline_slot
			
	return null
