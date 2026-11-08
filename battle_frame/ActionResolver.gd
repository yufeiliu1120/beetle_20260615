class_name ActionResolver
extends Node

signal round_finish
signal action_started(warship: Warship, action: ActionData)
signal action_finished(warship: Warship, action: ActionData)
signal _round_sync_finished
signal action_pair_executing(action_pair: Array)

var _running_animations: int = 0

# 【新增】：追加新行的补给消耗常量，方便后续平衡与修改
const ROW_APPEND_COST: int = 1

# ==========================================
# 核心数据：时间轴的“真理之源”
# 格式为: [ [敌方Action, 玩家Action], [敌方Action, 玩家Action], ... ]
# ==========================================
var turn_action_pairs: Array = []

# ==========================================
# 阶段 1：规划期接口 (供 CombatManager 和 UI 调用)
# ==========================================

# 回合开始时，根据敌人的意图初始化时间轴
func init_turn(enemy_actions: Array) -> void:
	turn_action_pairs.clear()
	for e_a in enemy_actions:
		# 左侧为敌人动作，右侧预留为 null 等待玩家拖入
		turn_action_pairs.append([e_a, null])

# 放置动作：支持动态生成 [null, action] 扩容数组，并查验补给
func place_player_action(index: int, action: ActionData, p_entity: CombatEntity) -> bool:
	if not p_entity or not action: return false
	
	# 1. 检查 AP 是否足够
	var old_action_cost = 0
	if index < turn_action_pairs.size() and turn_action_pairs[index][1] != null:
		old_action_cost = turn_action_pairs[index][1].ap_cost
		
	if p_entity.current_ap + old_action_cost < action.ap_cost:
		print("❌ AP 不足，无法放置！")
		return false

	# 2. 检查并扣除补给 (如果本次放置需要追加新行)
	var needed_rows = index - turn_action_pairs.size() + 1
	if needed_rows > 0:
		var total_cost = needed_rows * ROW_APPEND_COST
		if PlayerData.current_supply < total_cost:
			print("❌ 补给不足，无法追加新动作行！当前补给：", PlayerData.current_supply)
			return false
			
		# 扣除对应补给[cite: 2]
		PlayerData.current_supply -= total_cost
		print("📦 消耗补给追加新行，剩余补给：", PlayerData.current_supply)
		
		# 补给足够，执行数组扩容
		while index >= turn_action_pairs.size():
			turn_action_pairs.append([null, null])
		
	# 3. 结算 AP：退还旧的，扣除新的
	p_entity.current_ap += old_action_cost
	p_entity.current_ap -= action.ap_cost
	
	# 4. 正式放置
	turn_action_pairs[index][1] = action
	p_entity.stats_changed.emit()
	return true

# 移除动作并退还 AP 与 补给
func remove_player_action(index: int, p_entity: CombatEntity) -> void:
	if index >= turn_action_pairs.size(): return
	
	var existing_action = turn_action_pairs[index][1]
	if existing_action:
		p_entity.current_ap += existing_action.ap_cost
		turn_action_pairs[index][1] = null
		p_entity.stats_changed.emit()
		
	# 检查并回收因为移除操作闲置出的空行
	_cleanup_trailing_empty_pairs()

# 交换时间轴内的两个玩家动作，如果拉到底部同样需要检查补给
func swap_player_action(from_index: int, to_index: int) -> bool:
	if from_index == to_index or from_index >= turn_action_pairs.size(): 
		return false
	
	# 检查并扣除补给 (如果目标位置需要扩容)
	var needed_rows = to_index - turn_action_pairs.size() + 1
	if needed_rows > 0:
		var total_cost = needed_rows * ROW_APPEND_COST
		if PlayerData.current_supply < total_cost:
			print("❌ 补给不足，无法交换到新动作行！")
			return false
			
		PlayerData.current_supply -= total_cost
		
		while to_index >= turn_action_pairs.size():
			turn_action_pairs.append([null, null])
		
	var temp = turn_action_pairs[to_index][1]
	turn_action_pairs[to_index][1] = turn_action_pairs[from_index][1]
	turn_action_pairs[from_index][1] = temp
	
	# 如果因为拖拽交换导致上面的源位置变成了空行（比如把最后的动作往下拖），触发回收
	_cleanup_trailing_empty_pairs()
	return true

# 内部清理：时间轴末尾全是 [null, null] 时销毁该数据，并自动退还补给
func _cleanup_trailing_empty_pairs() -> void:
	# 从后往前逆向遍历
	for i in range(turn_action_pairs.size() - 1, -1, -1):
		if turn_action_pairs[i][0] == null and turn_action_pairs[i][1] == null:
			turn_action_pairs.remove_at(i)
			# 只要销毁一行，就触发退款[cite: 2]
			PlayerData.current_supply += ROW_APPEND_COST
			print("♻️ 回收末尾空行，返还补给。当前补给：", PlayerData.current_supply)
		else:
			break

# ==========================================
# 阶段 2：执行期结算
# ==========================================
func resolve_turn(p_warship: Warship, e_warship: Warship) -> void:
	print("\n=========== 💥 同步结算阶段开始 💥 ===========")
	
	var p_entity = p_warship.combatentity
	var e_entity = e_warship.combatentity
	
	var max_actions = turn_action_pairs.size()
	print("获取动作对：", turn_action_pairs)
	
	# 【新增】：设定单个动作轮次的保底最短时间（秒）
	var min_round_duration: float = 2 
	
	for i in range(max_actions):
		print("\n--- ⚔️ 动作轮次 %d ---" % (i + 1))
		
		var e_action: ActionData = turn_action_pairs[i][0]
		var p_action: ActionData = turn_action_pairs[i][1]
		
		if p_entity.current_hp <= 0 or e_entity.current_hp <= 0:
			break
			
		# 将双方动作传入对方的动作中
		if p_action != null:
			p_action.reset_target_action() 
			if e_action != null:
				p_action.target_action = e_action 
				
		if e_action != null:
			e_action.reset_target_action()
			if p_action != null:
				e_action.target_action = p_action

		# 先制启动
		if p_action != null and p_entity.current_hp > 0:
			p_action.on_action_start(p_entity)
		if e_action != null and e_entity.current_hp > 0:
			e_action.on_action_start(e_entity)
		
		# 动画与结算交接
		action_pair_executing.emit([e_action, p_action])
		
		# 【核心修改 1】：在此处开启一轮独立的保底计时器
		var round_timer = get_tree().create_timer(min_round_duration)
		
		_running_animations = 0
		if p_action != null and p_entity.current_hp > 0:
			_running_animations += 1
			_trigger_action_async(p_warship, p_action)
		if e_action != null and e_entity.current_hp > 0:
			_running_animations += 1
			_trigger_action_async(e_warship, e_action)
			
		# 1. 优先等待所有正在执行的逻辑与动画完毕
		if _running_animations > 0:
			await self._round_sync_finished
			
		# 【核心修改 2】：如果动画瞬间播完（或遇到空回合），但保底时间还没耗尽，强行等待剩余时间
		if round_timer.time_left > 0:
			await round_timer.timeout
			
		if p_entity.current_hp <= 0 or e_entity.current_hp <= 0:
			print("💀 有战舰已被摧毁，战斗结束！")
			break

	# 回合结束，清理时间轴为下回合做准备
	turn_action_pairs.clear()
	print("🏁 回合同步结算彻底完毕！")
	round_finish.emit()

func _trigger_action_async(warship: Warship, action: ActionData) -> void:
	action_started.emit(warship, action)
	await warship.excute_action(action)
	action_finished.emit(warship, action)
	
	_running_animations -= 1
	if _running_animations <= 0:
		_round_sync_finished.emit()
