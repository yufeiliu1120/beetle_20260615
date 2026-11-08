extends Node2D
class_name town_scene

@export var current_beetle_resource:BeetleChassisData
@export var current_tiles:Array[String]

func start_new_game() -> void:
	var base_blueprint = current_beetle_resource
	var initial_cards = current_tiles
	if base_blueprint == null:
		push_error("❌ 初始化失败：未提供初始蓝图！")
		return
		
	print("🚀 正在初始化全新游戏存档...")
	
	# ---------------------------------------------------------
	# 步骤 1：生成纯净底盘 (避免污染原始 .tres 文件)
	# ---------------------------------------------------------
	# 使用 duplicate(true) 进行深拷贝，确保我们修改的是运行时独占的新蓝图
	var run_chassis = base_blueprint.duplicate(true)
	
	# 强制清空蓝图中的所有拼接地块数据
	if "blueprint_data" in run_chassis:
		run_chassis.blueprint_data.clear()
		print("✨ 底盘地块数据已成功清空。")
	
	# 将这个干净的蓝图存入玩家全局单例
	PlayerData.player_chassis = run_chassis
	
	# ---------------------------------------------------------
	# 步骤 2：注入初始手牌/地块卡库
	# ---------------------------------------------------------
	# 同样使用 duplicate 确保外部传入的数组修改不会影响原卡组池
	PlayerData.card_backpack = initial_cards.duplicate()
	print("🃏 初始地块卡牌已发放，共 %d 张。" % PlayerData.card_backpack.size())
	# ---------------------------------------------------------
	# 步骤 3：计算裸机基础属性 (留出对接接口)
	# ---------------------------------------------------------
	_calculate_and_save_base_stats(run_chassis)
	
# ==========================================
# 步骤 3 专属函数：裸机属性计算
# ==========================================
func _calculate_and_save_base_stats(clean_chassis: BeetleChassisData) -> void:
	print("⚙️ 正在通过生成虚拟战舰计算基础属性...")
	
	# 1. 在后台凭空生成一个干净的战舰实体（由于 clean_chassis 已被清空，所以这是一个只有原生躯干的裸机）
	var beetle = BlueprintManager.build_ship(clean_chassis)
	
	# 确保战舰和对应的战斗实体存在
	if not is_instance_valid(beetle) or not "combatentity" in beetle:
		push_error("❌ 计算失败：生成的战舰无效或缺少 combatentity 节点！")
		if is_instance_valid(beetle):
			beetle.queue_free()
		return
		
	# 2. 直接调用战舰自身的计算逻辑获取原始最高属性
	PlayerData.base_ap = beetle.combatentity.calculate_base_ap()
	PlayerData.base_hp = beetle.combatentity.calculate_base_hp()
	PlayerData.base_supply = beetle.combatentity.calculate_base_max_supply()
	
	# 同步填满当前的可用状态 (满血、满 AP、满补给开局)
	PlayerData.max_hp = PlayerData.base_hp
	PlayerData.max_ap = PlayerData.base_ap
	PlayerData.max_supply = PlayerData.base_supply
	
	PlayerData.current_hp = PlayerData.max_hp
	PlayerData.current_supply = PlayerData.max_supply
	
	# 3. 数据提取完毕，彻底销毁虚拟战舰，释放内存
	beetle.queue_free()
	print("📊 基础属性已写入单例 -> HP: %d | AP: %d | Supply: %d" % [PlayerData.base_hp, PlayerData.base_ap, PlayerData.base_supply])
	SceneManager.load_scene("res://test/AssumblyHubTest.tscn")
