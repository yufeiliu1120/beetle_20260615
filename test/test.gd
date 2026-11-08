extends Node2D

var player_position_mark: Marker2D
var enemy_position_mark: Marker2D

var current_player_ship:Warship
var current_enemy:Warship
# ==========================================
# 敌人配置 (在编辑器中二选一填入)
# ==========================================
@export_group("Enemy Configuration")
@export var enemy_chassis: BeetleChassisData # 拼接型甲虫敌人
@export var enemy_scene: PackedScene         # 非甲虫的一体化场景敌人 (如 Boss、野兽)



# 外部接口，用来开始战斗
func init_combat_scene():
	init_player_ship()
	init_enemy()
	$CombatManager.start_battle()

func init_player_ship():
	if current_player_ship:
		get_tree().root.remove_child(current_player_ship)
		current_player_ship.queue_free()
	player_position_mark = get_tree().get_first_node_in_group("player_position")
	# 从单例中获取玩家图纸进行组装
	var player_ship = BlueprintManager.build_ship(PlayerData.player_chassis)
	player_ship.global_position = player_position_mark.position
	get_tree().root.add_child(player_ship)
	player_ship.is_player = true
	current_player_ship = player_ship
	
func init_enemy():
	if current_enemy:
		get_tree().root.remove_child(current_enemy)
		current_enemy.queue_free()
		
	enemy_position_mark = get_tree().get_first_node_in_group("enemy_position")
	var enemy_ship = null
	
	# ==========================================
	# 智能读取：优先使用单例传递过来的数据，没有则使用本地导出的测试数据
	# ==========================================
	var final_chassis = PlayerData.upcoming_enemy_chassis if PlayerData.upcoming_enemy_chassis else null
	var final_scene = PlayerData.upcoming_enemy_scene if PlayerData.upcoming_enemy_scene else null

	if final_chassis != null:
		print("🕷️ 检测到甲虫图纸，通过蓝图工厂生成敌人...")
		# 【核心修复 1】：深拷贝图纸资源，确保新敌人的所有部件和材质彻底独立！
		var clean_chassis = final_chassis.duplicate(true)
		enemy_ship = BlueprintManager.build_ship(clean_chassis)
	elif final_scene != null:
		print("👾 检测到预设场景，直接实例化独立敌人...")
		enemy_ship = final_scene.instantiate()
	else:
		push_error("❌ 未配置任何敌人数据，无法初始化敌方实体！")
		return
		
	enemy_ship.global_position = enemy_position_mark.position
	get_tree().root.add_child(enemy_ship)
	
	if "is_player" in enemy_ship:
		enemy_ship.is_player = false
	current_enemy = enemy_ship

	# 【核心修复 2】：强制重置敌人的视觉状态（清理死亡 Shader 参数）
	if "visual_controller" in enemy_ship and enemy_ship.visual_controller:
		_reset_enemy_visual_state(enemy_ship.visual_controller)
		
	# 消耗掉桥梁里的数据，保持环境整洁
	PlayerData.clear_upcoming_encounter()


# ==========================================
# 辅助函数：彻底重置敌人的视觉 Shader 与坐标状态
# ==========================================
func _reset_enemy_visual_state(vc: visual_controller) -> void:
	# 1. 确保物理坐标和残余 Tween 彻底终止
	vc.position = Vector2.ZERO
	if vc.death_tween and vc.death_tween.is_valid():
		vc.death_tween.kill()
		
	# 2. 遍历部件，强制将死亡 Shader 参数清零！
	if not vc.body_nodes.is_empty():
		for socket in vc.body_nodes:
			var part = vc._get_part_in_socket(socket)
			if part and part.material is ShaderMaterial:
				part.material.set_shader_parameter("death_progress", 0.0)
				part.material.set_shader_parameter("flash_modifier", 0.0)
	else:
		if vc.material is ShaderMaterial:
			vc.material.set_shader_parameter("death_progress", 0.0)
			vc.material.set_shader_parameter("flash_modifier", 0.0)
			
	# 3. 准备好登场状态（例如重置到沙子中）
	if vc.has_method("reset_to_sand"):
		vc.reset_to_sand()

	
