class_name CombatEntity
extends Node2D

# ==========================================
# 基础属性
# ==========================================
@export var warship = get_parent() as Warship

@export var entity_name: String = "测试用甲虫战舰"
# 当前生命值，自带一个 setter 以确保它永远不会超过 max_hp 或低于 0
var current_hp: int = 0:
	set(value):
		# 使用 clampi 限制 current_hp 的范围在 0 到 max_hp 之间
		current_hp = clampi(value, 0, max_hp)
		hp_changed.emit()
# 最大生命值，包含你需要的核心联动逻辑
var max_hp: int = 0:
	set(new_max_hp):
		# 计算变化差值
		var diff = new_max_hp - max_hp 
		
		# 1. 先更新 max_hp 本身
		max_hp = new_max_hp 
		
		# 2. 根据差值处理 current_hp
		if diff > 0:
			# 如果 max_hp 变大，current_hp 增加相同的数值
			current_hp += diff
		else:
			# 如果 max_hp 变小，检查当前血量是否超标
			if current_hp > max_hp:
				current_hp = max_hp
		hp_changed.emit()
		
signal ap_changed
signal hp_changed
signal supply_changed
signal shields_changed

var current_ap: int = 0:
	set(value):
		# 使用 clampi 限制 current_hp 的范围在 0 到 max_hp 之间
		current_ap = clampi(value, 0, max_hp)
		ap_changed.emit()
# 最大生命值，包含你需要的核心联动逻辑
var max_ap: int = 0:
	set(new_max_ap):
		# 计算变化差值
		var diff = new_max_ap - max_ap 
		
		# 1. 先更新 max_hp 本身
		max_ap = new_max_ap
		
		# 2. 根据差值处理 current_hp
		if diff > 0:
			# 如果 max_hp 变大，current_hp 增加相同的数值
			current_ap += diff
		else:
			# 如果 max_hp 变小，检查当前血量是否超标
			if current_ap > max_ap:
				current_ap = max_ap
		ap_changed.emit()
		
# 裸机基础属性
@export var base_max_hp: int = 0
@export var base_max_ap: int = 0
@export var base_max_supply:int = 0
@export var init_shield_count:int = 0 #初始携带的护盾量

var active_shields: Array = []

# ==========================================
# 动作相关
# ==========================================
var action_pool: Array[ActionData] = []
var cooldown_tracker: Dictionary = {}
@export var inherent_actions: Array[ActionData] = []
var _instanced_inherent_actions: Array[ActionData] = []
var _runtime_inherent_actions: Array[ActionData] = []

#用于处理回合开始和回合结束的数组，其中保存BuffData
var active_buffs: Array[BuffData] = []
#战斗开始时自带的buff
var inherent_buffs:Array[BuffData] = []

var buff_text_scene: PackedScene = preload("res://warship_parts/Buff_Shield_text_Node.tscn")# 将你做好的飘字场景拖到这里
# 信号
signal stats_changed
signal died
signal action_animation_finished
signal buff_added(buff: BuffData)


#直接从单例中获取数值
func get_data_from_Player_Data():
	max_hp = PlayerData.max_hp
	max_ap = PlayerData.max_ap
	current_hp = PlayerData.current_hp

#用于计算基础数值的函数
func calculate_base_max_supply():
	var max_supply = base_max_supply
	# 增加安全判定：必须有 visual_controller 且里面真的有 body_nodes 数组
	if warship.visual_controller and "body_nodes" in warship.visual_controller:
		var _visual_controller = warship.visual_controller
		for part in _visual_controller.body_nodes:
			var part_data = _visual_controller._get_part_in_socket(part)
			if part_data:
				max_supply += part_data.base_supply
		return max_supply
		
		
func calculate_base_ap():
	max_ap = base_max_ap
	if warship.visual_controller and "body_nodes" in warship.visual_controller:
		var _visual_controller = warship.visual_controller
		for part in _visual_controller.body_nodes:
			var part_data = _visual_controller._get_part_in_socket(part)
			if part_data:
				max_ap += part_data.base_ap
	return max_ap
	
	
func calculate_base_hp():
	max_hp = base_max_hp
	if warship.visual_controller and "body_nodes" in warship.visual_controller:
		var _visual_controller = warship.visual_controller
		for part in _visual_controller.body_nodes:
			var part_data = _visual_controller._get_part_in_socket(part)
			if part_data:
				max_hp += part_data.base_hp
	return max_hp
	
func add_shield(count: int) -> void:
	if count <= 0: return
	
	# 添加护盾层数
	for i in range(count):
		active_shields.append(null)
		
	print("🛡️ 战舰获得了 %d 层护盾" % count)
	
	# 【全新视觉环节】：生成护盾飘字
	if buff_text_scene:
		var text_inst = buff_text_scene.instantiate()
		add_child(text_inst)
		
		# 同样增加一点随机偏移，防止和 Buff 的飘字完全重叠
		text_inst.position = Vector2(randf_range(-15, 15), -40 + randf_range(-10, 10))
		
		# 调用专属的护盾设置接口
		text_inst.setup_for_shield(count)
	shields_changed.emit()
		
#用于计算护盾值的函数，包括地块提供，在战斗开始时触发一次
func calculate_shields():
	active_shields.clear()
	for i in range(init_shield_count):
		active_shields.append(null)
	
	# 【核心修改】：只有战舰真的有地块管理器时，才去遍历地块护盾
	if warship.hexgridmanager:
		for tile in warship.hexgridmanager.get_all_active_tiles():
			if tile.get("provides_shield") == true:
				active_shields.append(tile)

func init_action_pool(grid_manager: HexGridManager, tile_cd_bridge: Dictionary = {}) -> void:
	var old_cooldowns = cooldown_tracker.duplicate()
	cooldown_tracker.clear()
	action_pool.clear()

	# 1. 取得地块提供的动作 (增加安全判定)
	if grid_manager:
		for action in grid_manager.action_to_tile_map.keys():
			action_pool.append(action)
			var tile = grid_manager.action_to_tile_map[action]
			if tile_cd_bridge.has(tile):
				cooldown_tracker[action] = tile_cd_bridge[tile]
			elif old_cooldowns.has(action):
				cooldown_tracker[action] = old_cooldowns[action]
			else:
				cooldown_tracker[action] = 0 
	else:
		print("ℹ️ 该实体没有地块网络，跳过地块动作扫描。")

	# 2. 战舰自带动作初始化 (即使没有部件，也能装载自身配置的固有动作)
	if _instanced_inherent_actions.is_empty():
		for action in inherent_actions:
			# 【核心修改】：使用全新的安全克隆
			_instanced_inherent_actions.append(action.get_unique_copy())
			
		# 只有拥有 body_nodes 才去遍历部件动作
		if warship.visual_controller and "body_nodes" in warship.visual_controller:
			var _visual_controller = warship.visual_controller
			for part in _visual_controller.body_nodes:
				var _part = _visual_controller._get_part_in_socket(part)
				if _part:
					for action in _part.actions:
						# 【核心修改】：使用全新的安全克隆
						_instanced_inherent_actions.append(action.get_unique_copy())
	
	# 3. 取得永久唯一的自带动作
	for action in _instanced_inherent_actions:
		action_pool.append(action)
		if old_cooldowns.has(action):
			cooldown_tracker[action] = old_cooldowns[action]
		else:
			cooldown_tracker[action] = 0

func start_battle() -> void:
	init_action_pool(warship.hexgridmanager) # 生成动作池
	_initialize_cooldowns() # 计算冷却时间
	calculate_shields() # 计算护盾值
	

	
	if warship.is_player:
		get_data_from_Player_Data()
		print("📦 正在从 PlayerData 读取玩家全局状态...")
		# 1. 强制覆盖当前血量，无视 setter 刚才造成的增量
		# 2. 注入全局 Buff
		# 【关键安全细节】：从单例中取 Buff 时，依然需要深拷贝 duplicate(true)！
		# 否则战斗中扣减 buff.duration 时，会直接修改掉单例里的寿命，导致下场战斗失效
		for buff in PlayerData.global_buffs:
			if buff != null:
				inherent_buffs.append(buff.duplicate(true))
	else:
		# 非玩家单位满血出战
		calculate_base_hp()
		calculate_base_ap()
		current_hp = max_hp
		
	current_ap = max_ap # AP 每次战斗回满
	
	# 统一初始化 Buff：
	# 此时 inherent_buffs 里已经包含了 [自身部件自带的Buff + PlayerData下发的全局Buff]
	init_buffs()
	
func _initialize_cooldowns() -> void:
	for action in action_pool:
		cooldown_tracker[action] = 0

# ==========================================
# 回合开始与动作池重建 (CD 安全重构版)
# ==========================================
func on_turn_start() -> void:
	# 【步骤 1：构建安全桥梁】在刷新地块前，先通过 action_to_tile_map 
	# 建立一个 "地块节点 -> 当前剩余CD" 的临时字典！
	var tile_cd_bridge: Dictionary = {}
	var grid_manager = null
	
	if warship.visual_controller and warship.visual_controller.has_node("HexGridManager"):
		grid_manager = warship.visual_controller.get_node("HexGridManager")
		if grid_manager:
			for old_action in cooldown_tracker.keys():
				if grid_manager.action_to_tile_map.has(old_action):
					var tile = grid_manager.action_to_tile_map[old_action]
					tile_cd_bridge[tile] = cooldown_tracker[old_action]
					
			# 触发底层地块与 Buff 全量重新算一次
			if grid_manager.has_method("calculate_tile"):
				grid_manager.calculate_tile()

	# 【步骤 2：传入桥梁重建动作池】
	init_action_pool(grid_manager, tile_cd_bridge)

	# 【步骤 3：恢复 AP 与扣减 CD】
	current_ap = max_ap
	for action in cooldown_tracker.keys():
		if cooldown_tracker[action] > 0:
			cooldown_tracker[action] -= 1
			
	calculate_turn_start_buff()
	stats_changed.emit()
	
#回合结束时的效果
func _on_turn_end() -> void:
	# 1. 将所有影响值清零，方便下回合重新赋予buff
	for action in action_pool:
		for effect in action.action_effects:
			effect.count_influence = 0
			
	# 2. 执行所有在回合结束时触发的 Buff 伤害/治疗
	calculate_turn_end_buff()
	
	# 3. 【新增】：当本回合所有的效果都结算完毕后，统一扣除 Buff 的寿命！
	process_buff_decay()
	
	stats_changed.emit() # 回合结束，刷新状态栏 UI

#================================================================
#Buff处理逻辑
#================================================================

#初始化buff数组，将战斗开始赋予的buff加上
func init_buffs():
	active_buffs.clear()
	if not inherent_buffs.is_empty():
		for buff in inherent_buffs:
			add_buff(buff)
# ==========================================
# 寿命衰减与销毁逻辑
# ==========================================
func process_buff_decay() -> void:
	# 【核心安全机制】：倒序遍历数组
	# 因为我们在发现 buff 寿命耗尽时需要从数组中 remove_at(i)，
	# 如果正序遍历，删掉元素后后续元素的索引会发生错位。
	for i in range(active_buffs.size() - 1, -1, -1):
		var buff = active_buffs[i]
		
		# 如果 duration 是 -1，代表这是永久被动或受光环控制的 Buff，不扣减寿命
		if buff.duration == -1:
			continue
			
		# 寿命减 1
		buff.duration -= 1
		
		# 判断是否应该销毁
		if buff.duration <= 0:
			print("🗑️ 状态 [%s] 持续时间结束，正在销毁..." % buff.buff_name)
			
			# 1. 触发消散时的兜底效果 (例如移除增加的最大生命值)
			if buff.has_method("trigger_on_detach"):
				buff.trigger_on_detach(self)
				
			# 2. 安全地从数组中将其移除
			active_buffs.remove_at(i)


func add_buff(raw_buff: BuffData) -> void:
	if raw_buff == null:
		return
		
	# ==========================================
	# 【核心修改】：同名 Buff 检测与叠加判定
	# ==========================================
	for existing_buff in active_buffs:
		# 依靠 buff_name 字符串进行跨实例的绝对识别
		if existing_buff.buff_name == raw_buff.buff_name:
			# 如果该状态被配置为“延长寿命”模式
			if raw_buff.stack_mode == BuffData.StackMode.EXTEND_DURATION:
				# 排除永久状态 (-1) 的干扰
				if existing_buff.duration != -1 and raw_buff.duration != -1:
					existing_buff.duration += raw_buff.duration
					print("⏳ 触发延时机制！状态 [%s] 持续时间延长，当前剩余: %d 回合" % [existing_buff.buff_name, existing_buff.duration])
					
					# 飘一个 "+ 时间" 的文字，给玩家正反馈
					if buff_text_scene:
						var text_inst = buff_text_scene.instantiate()
						warship.add_child(text_inst)
						text_inst.position = Vector2(randf_range(-15, 15), -40 + randf_range(-10, 10))
						# 仅显示名字和加号，表示时间被延长
						text_inst.setup(existing_buff.buff_name + " +", existing_buff.is_debuff)
						
					stats_changed.emit()
				# 因为已经成功处理了延时，直接阻断后续逻辑，不生成新 Buff
				return 
				
	# ==========================================
	# 原有逻辑：生成全新 Buff 实例
	# (走到这里说明：要么是第一次获得，要么是允许 ADD_NEW 并存)
	# ==========================================
	var new_buff = raw_buff.duplicate(true)
	active_buffs.append(new_buff)
	new_buff.reset_count()
	print("✨ 战舰获得了新独立状态: ", new_buff.buff_name)
	
	if new_buff.has_method("trigger_on_attach"):
		new_buff.trigger_on_attach(self)
		
	if buff_text_scene:
		var text_inst = buff_text_scene.instantiate()
		warship.add_child(text_inst)
		text_inst.position = Vector2(randf_range(-15, 15), -40 + randf_range(-10, 10))
		text_inst.setup(new_buff.set_text(), new_buff.is_debuff)
		
	buff_added.emit(new_buff)
	stats_changed.emit()

# ==========================================
# 回合引擎重构：回合开始
# ==========================================
func calculate_turn_start_buff() -> void:
	print("开始计算回合开始buff，当前拥有状态数: ", active_buffs.size())
	for buff in active_buffs:
		if buff.has_method("trigger_turn_start"):
			buff.trigger_turn_start(self)

# ==========================================
# 回合引擎重构：回合结束
# ==========================================
func calculate_turn_end_buff() -> void:
	print("开始计算回合结束buff")
	for buff in active_buffs:
		if buff.has_method("trigger_turn_end"):
			buff.trigger_turn_end(self)

#=================================================================
				

func is_action_available(action: ActionData) -> bool:
	var not_in_cooldown = cooldown_tracker.get(action, 0) == 0
	var has_enough_ap = current_ap >= action.ap_cost
	return not_in_cooldown and has_enough_ap


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
		shields_changed.emit()
		if get_parent().visual_controller and get_parent().visual_controller.has_method("shield_take_hit"):
			get_parent().visual_controller.shield_take_hit()
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
			
	# 【核心修改】：受击特效安全调用
	if get_parent().visual_controller and get_parent().visual_controller.has_method("take_hit"):
		get_parent().visual_controller.take_hit(amount)
		
	current_hp = clampi(current_hp - amount, 0, max_hp)
	stats_changed.emit()
	if current_hp <= 0:
		died.emit()
		print(entity_name, " 被击沉了！")
		
		
# ==========================================
# 安全深度克隆（解决资源共享与跨实体污染问题）
# ==========================================
func get_unique_copy() -> ActionData:
	# 1. 复制最外层的壳子
	var clone = self.duplicate(false)
	# 2. 强制独立化标签数组
	clone.tags = self.tags.duplicate()
	
	# 3. 核心：手动深度克隆每一个效果组件，彻底斩断与原文件的联系！
	var new_effects: Array[ActionEffect] = []
	for effect in self.action_effects:
		if effect != null:
			# 对内部效果执行 true 深拷贝
			new_effects.append(effect.duplicate(true))
		else:
			new_effects.append(null)
			
	clone.action_effects = new_effects
	return clone
