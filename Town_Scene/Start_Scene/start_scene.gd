
extends Node2D

var current_beetle:BeetleChassisData
var current_cards:Array[TileCard]
@export var ui_layer:start_scene_ui
@export var start_button_area:Area2D
@export var button_sprite:AnimatedSprite2D
@export var center_marker:Marker2D
var start_button_mouse_in:bool
var allow_to_start:bool = true

func _ready():
	start_button_area.mouse_entered.connect(_on_start_button_area_mouse_entered)
	start_button_area.mouse_exited.connect(_on_start_button_area_mouse_exited)
	ui_layer.current_beetle_changed.connect(_on_current_beetle_changed)
	
func _on_current_beetle_changed(beetle:BeetleChassisData):
	current_beetle = beetle
	
func _on_start_button_area_mouse_entered():
	if not allow_to_start:
		return
	start_button_mouse_in = true
	button_sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
func _on_start_button_area_mouse_exited():
	start_button_mouse_in = false
	button_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# 确保是左键且刚刚按下 (is_pressed())，防止拖拽释放时误触
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			if start_button_mouse_in and allow_to_start:
				
				# 4. 动画播完，正式启动后端逻辑与场景跳转
				start_new_game()


# ==========================================
# 视觉表现：独立的转场动画协程 (同步加速版)
# ==========================================
func play_transition_animation(anim_duration: float = 0.8) -> void:
	var tween = create_tween().set_parallel(true)
	
	# 【核心修改】：统一使用 TRANS_CUBIC 和 EASE_IN
	# EASE_IN 会让动画从缓和开始，然后一直加速冲刺直到结束，极大地增强转场的爆发力
	var trans_type = Tween.TRANS_CUBIC
	var ease_type = Tween.EASE_IN
	
	# 1. 摄像机移动与放大逻辑
	var camera = get_tree().get_first_node_in_group("Camera") as Camera2D
	if camera and center_marker:
		# 移动
		tween.tween_property(camera, "global_position", center_marker.global_position, anim_duration)\
			.set_trans(trans_type).set_ease(ease_type)
			
		# 放大
		var target_zoom = camera.zoom * 10 
		tween.tween_property(camera, "zoom", target_zoom, anim_duration)\
			.set_trans(trans_type).set_ease(ease_type)

	# 2. 生成全屏渐白遮罩层
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100 
	get_tree().current_scene.add_child(canvas_layer)
	
	var fade_rect = ColorRect.new()
	fade_rect.color = Color(1.0, 1.0, 1.0, 0.0) 
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT) 
	canvas_layer.add_child(fade_rect)
	
	# 3. 播放渐变动画：使用与摄像机完全一致的曲线，确保白屏和放大达到巅峰的时刻分毫不差
	tween.tween_property(fade_rect, "color:a", 1.0, anim_duration)\
		.set_trans(trans_type).set_ease(ease_type)
		
	# 4. 阻塞当前协程，直到视觉动画结束
	await tween.finished
	await get_tree().create_timer(0.3).timeout
# 游戏初始化入口
# ==========================================
func start_new_game() -> void:
	var base_blueprint = current_beetle
	var initial_cards = current_cards
	if base_blueprint == null:
		push_error("❌ 初始化失败：未提供初始蓝图！")
		return
	print("🚀 正在初始化全新游戏存档...")
	
	await play_transition_animation()
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
	# 步骤 2：注入初始手牌/地块卡库 (转为路径存储)
	# ---------------------------------------------------------
	PlayerData.card_backpack.clear()
	
	for card in initial_cards:
		if card == null:
			continue
			
		# 情况 A：如果数组里存的是尚未实例化的场景资源 (PackedScene)
		if card is PackedScene:
			PlayerData.card_backpack.append(card.resource_path)
			
		# 情况 B：如果数组里存的是已经实例化的节点 (TileCard 实例)
		elif card is Node and card.scene_file_path != "":
			PlayerData.card_backpack.append(card.scene_file_path)
			
		# 情况 C：如果你在卡牌脚本中自定义并赋值了 my_card_path
		elif "my_card_path" in card and card.my_card_path != "":
			PlayerData.card_backpack.append(card.my_card_path)
			
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
	#重设玩家的卡牌奖励数量和幸运值
	PlayerData.current_tile_reward_count = 3
	PlayerData.luck = 0
	# 3. 数据提取完毕，彻底销毁虚拟战舰，释放内存
	beetle.queue_free()
	print("📊 基础属性已写入单例 -> HP: %d | AP: %d | Supply: %d" % [PlayerData.base_hp, PlayerData.base_ap, PlayerData.base_supply])
	
	# 4. 彻底计算完毕，携带纯白遮罩直接跨入新场景！
	SceneManager.load_scene("res://test/AssumblyHubTest.tscn")
