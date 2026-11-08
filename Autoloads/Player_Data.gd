extends Node

# ==========================================
# 跨场景数据桥梁 (用于传递给下一个场景)
# ==========================================
var upcoming_enemy_chassis: BeetleChassisData = null
var upcoming_enemy_scene: PackedScene = null

# 可选：加一个清理函数，战斗结束后清空，防止数据残留
func clear_upcoming_encounter() -> void:
	upcoming_enemy_chassis = null
	upcoming_enemy_scene = null
# 玩家拥有的地块卡牌路径数组
var card_backpack: Array[String] = ["res://tiles/cannon/cannon_card.tscn","res://tiles/cannon/cannon_card.tscn","res://tiles/test_large_tile/large_tile_card.tscn","res://tiles/cannon/cannon_card.tscn","res://tiles/cannon/cannon_card.tscn","res://tiles/test_large_tile/large_tile_card.tscn"]
var player_chassis: BeetleChassisData = preload("res://resources/beetle_resources/player_beetle/test_beetle_player.tres")
# ==========================================
# 跨场景状态储存
# ==========================================

var base_hp:int
var base_ap:int
var base_supply:int

var current_hp: int = 0:
	set(value):
		current_hp = value
		hp_changed.emit()

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

var current_supply:int = 0:
	set(value):
		supply_changed.emit()
		current_supply = value
		
var max_supply: int = 0:
	set(new_max_supply):
		# 计算变化差值
		var diff = new_max_supply - max_supply
		
		# 1. 先更新 max_hp 本身
		max_supply = new_max_supply
		
		# 2. 根据差值处理 current_hp
		if diff < 0:
			# 如果 max_hp 变小，检查当前血量是否超标
			if current_supply > max_supply:
				current_supply = max_supply
		supply_changed.emit()
		
var max_ap: int = 0

#和奖励有关的属性
var current_tile_reward_count = 3  #每次地块奖励会出现的选择数量
var luck = 0 #幸运值
var current_advanture_theme = "pirate"#当前冒险选择的阵营

#全局buff
var global_buffs: Array[BuffData] = []

# 【新增】：用于在探索场景 UI 中展示给玩家看的当前卡组/动作池
var action_pool: Array[ActionData] = [] 

signal supply_changed
signal hp_changed
signal ap_changed
# ==========================================
# 探索开局：数据提取与初始化
# ==========================================
func init_run_data(ship_instance: Warship) -> void:
	if not ship_instance or not ship_instance.combatentity:
		push_error("❌ PlayerData 初始化失败：无效的战舰实例")
		return
		
	var entity = ship_instance.combatentity
	
	# 1. 强制提取血量上限
	# 让 combatentity 扫描刚刚拼装好的部件，计算出真实的 max_hp
	max_hp = entity.max_hp
	current_hp = max_hp # 每次从组装车间出发，必定是满血！
	max_ap = entity.max_ap
	#获取补给值
	current_supply = max_supply
	
	# 2. 强制提取动作池
	var grid_manager = ship_instance.find_child("HexGridManager", true, false)
	if grid_manager:
		# 如果你的地块需要 calculate_tile 来激活功能，这里需要预先调用一次
		if grid_manager.has_method("calculate_tile"):
			grid_manager.calculate_tile()
			
		# 让 combatentity 生成完整的 action_pool
		entity.init_action_pool(grid_manager)
		
	# 3. 将提取到的动作池保存到单例中
	action_pool.clear()
	for action in entity.action_pool:
		action_pool.append(action)
		
	print("🚀 探索旅程初始化完毕！最大血量: %d, 携带动作数量: %d" % [max_hp, action_pool.size()])

# ==========================================
# 数据交互接口 (保留你原有的逻辑)
# ==========================================
func save_battle_result(entity: CombatEntity) -> void:
	current_hp = entity.current_hp
	
func reset_run_data() -> void:
	current_hp = 0
	max_hp = 0
	global_buffs.clear()
	action_pool.clear()

# 提供一个辅助方法：消耗地块
func consume_card(card_path: String) -> void:
	var index = card_backpack.find(card_path)
	if index != -1:
		card_backpack.remove_at(index)
