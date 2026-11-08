extends VBoxContainer
class_name assumbly_action_slot_container
var _action_slot = "res://General_UI_parts/action_slot/action_slot.tscn"

func add_new_slot(action:ActionData):
	var slot:action_slot = load(_action_slot).instantiate()
	slot.set_action_slot(action)
	add_child(slot)
	slot.collapse(true)
	slot.expand()
	slot.mode = "assumbly"
	slot._mouse_entered.connect(_on_slot_mouse_entered)
	slot._mouse_exited.connect(_on_slot_mouse_exited)
	
func delete_slot(slot:action_slot):
	remove_child(slot)
	slot.queue_free()

func reset_slot(slot:action_slot):
	slot.set_action_slot(slot.current_action)
	
func refresh_with_action_pool(action_pool: Array[ActionData]):
	# 1. 创建动作池的一个浅拷贝，用来记录需要新增的动作（避免直接修改传入的数组）
	var actions_to_add: Array[ActionData] = action_pool.duplicate()
	
	# 2. 获取当前容器中现有的子组件（倒序遍历，因为如果中间触发删除也不会发生索引偏移错位）
	var children = get_children()
	for i in range(children.size() - 1, -1, -1):
		var slot = children[i] as action_slot
		if not slot:
			continue
			
		var action = slot.current_action
		if action in actions_to_add:
			# 【存在于两边的动作】：重设文本与标签
			reset_slot(slot)
			# 从待新增列表里去掉，这样遍历结束剩下的就是纯新增的数据
			actions_to_add.erase(action)
		else:
			# 【当前有但动作池没有的动作】：从视图中删除
			delete_slot(slot)
	
	# 3. 【动作池有但当前没有的动作】：将剩余的 action_pool 项添加到视图中
	for new_action in actions_to_add:
		add_new_slot(new_action)
		
func _on_slot_mouse_entered(slot:action_slot):
	#获取slot中的动作，并和战舰动作池进行比较
	var action = slot.current_action
	if get_tree().get_first_node_in_group("Assumbly_Scene"):
		var warship:Warship = get_tree().get_first_node_in_group("Assumbly_Scene").player_ship
		if not warship:
			push_error("尝试获取玩家战舰失败")
			return
		if action in warship.combatentity.action_pool:
			if action in warship.hexgridmanager.action_to_tile_map.keys():
				if warship.hexgridmanager.action_to_tile_map[action].smooth_brighten():
					warship.hexgridmanager.action_to_tile_map[action].smooth_brighten()
	
func _on_slot_mouse_exited(slot:action_slot):
	#获取slot中的动作，并和战舰动作池进行比较
	var action = slot.current_action
	if get_tree().get_first_node_in_group("Assumbly_Scene"):
		var warship:Warship = get_tree().get_first_node_in_group("Assumbly_Scene").player_ship
		if not warship:
			push_error("尝试获取玩家战舰失败")
			return
		if action in warship.combatentity.action_pool:
			if action in warship.hexgridmanager.action_to_tile_map.keys():
				warship.hexgridmanager.action_to_tile_map[action].smooth_restore()
