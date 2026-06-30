class_name CombatEntity
extends Node2D

# ==========================================
# 基础属性
# ==========================================
@export var warship = get_parent() as Warship

@export var entity_name: String = "甲虫战舰"
@export var max_hp: int = 100
var current_hp: int

@export var max_ap: int = 3
var current_ap: int

# 裸机基础属性
@export var base_max_hp: int = 50
@export var base_max_ap: int = 2
@export var active_shields: Array = []
# ==========================================
# 动作相关
# ==========================================
var action_pool: Array[ActionData] = []
var cooldown_tracker: Dictionary = {}
var current_action_queue: Array[ActionData] = []
@export var inherent_actions: Array[ActionData] = []
var _runtime_inherent_actions: Array[ActionData] = []
# 信号
signal stats_changed
signal died
signal action_animation_finished
func init_aciont_pool(grid_manager: HexGridManager) -> void:
	print("初始化动作池")
	#清空原本的动作池
	action_pool = []
	if not grid_manager:
		push_error("初始化动作池失败，未提供地块管理器节点")
		return
	for action in grid_manager.action_to_tile_map.keys():
		action_pool.append(action)
	print("取得地块提供的动作：{action_pool}".format({"action_pool":action_pool}))
	for action in inherent_actions:
		var cloned_action = action.duplicate()
		action_pool.append(cloned_action)
	print("取得战舰自带动作：{action_pool}".format({"action_pool":action_pool}))

func _ready() -> void:
	current_hp = max_hp
	current_ap = max_ap
	
	_initialize_cooldowns()

func _initialize_cooldowns() -> void:
	for action in action_pool:
		cooldown_tracker[action] = 0

# ==========================================
# 回合逻辑与动作校验
# ==========================================
func on_turn_start() -> void:
	# ==========================================
	# 回合刚开始时，统一进行地块全量刷新
	# ==========================================
	if get_parent().visual_controller and get_parent().visual_controller.has_node("HexGridManager"):
		var grid_manager = get_parent().visual_controller.get_node("HexGridManager")
		if grid_manager and grid_manager.has_method("calculate_tile"):
			# 1. 刷新底层的 Buff 和动作字典
			grid_manager.calculate_tile()
			# 2. 【安全优化】：直接使用刚刚找到的 grid_manager 刷新表层动作池
			init_aciont_pool(grid_manager)
	# 以下为你原本的 AP 恢复和队列清理逻辑（保持不变）
	current_ap = max_ap
	for action in cooldown_tracker.keys():
		if cooldown_tracker[action] > 0:
			cooldown_tracker[action] -= 1
	current_action_queue.clear()
	stats_changed.emit()

func is_action_available(action: ActionData) -> bool:
	var not_in_cooldown = cooldown_tracker.get(action, 0) == 0
	var has_enough_ap = current_ap >= action.ap_cost
	var not_already_queued = not current_action_queue.has(action) 
	return not_in_cooldown and has_enough_ap and not_already_queued

func use_action(action: ActionData) -> void:
	if is_action_available(action):
		current_ap -= action.ap_cost
		current_action_queue.append(action)
		stats_changed.emit()

func cancel_action(index: int) -> void:
	if index < current_action_queue.size():
		var action = current_action_queue[index]
		current_ap += action.ap_cost
		current_action_queue.remove_at(index)
		stats_changed.emit()

func start_cooldown(action: ActionData) -> void:
	if action.base_cooldown > 0:
		cooldown_tracker[action] = action.base_cooldown + 1
	else:
		cooldown_tracker[action] = 0

# ==========================================
# 战斗反馈与表现接口
# ==========================================
func take_damage(amount: int) -> void:
	print("⚠️ 战舰即将受到 %d 点伤害..." % amount)
	
	while active_shields.size() > 0:
		var shield = active_shields.pop_back()
		
		# 分支 A：这是一个地块实体
		if is_instance_valid(shield) and shield is TileBase:
			if not shield.is_disabled:
				print("🛡️ 装甲地块 [%s] 挺身而出！完美抵挡伤害！" % shield.tile_name)
				
				# 【核心新增】：判断是否需要碎裂
				if shield.get("breaks_on_block") == true:
					shield.deactivate_tile(false) # 一次性装甲，直接报废
				else:
					print("✨ 该装甲结构完好，未发生碎裂！（本回合护盾已消耗）")
					# 这里不调用 deactivate_tile，地块依然存活，只是被移出了本回合的挡刀队列
					
				return # 无论碎不碎，这发伤害都被成功抵挡了，安全退出
				
		# 分支 B：非地块的虚拟护盾
		else:
			print("✨ 虚拟护盾生效！完美抵挡伤害！类型: ", shield)
			return
			
	get_parent().visual_controller.take_hit()
	current_hp = clampi(current_hp - amount, 0, max_hp)
	stats_changed.emit()
	if current_hp <= 0:
		died.emit()
		print(entity_name, " 被击沉了！")
