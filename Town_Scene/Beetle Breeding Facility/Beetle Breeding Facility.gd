extends Node2D
class_name beetle_breeding_facility

@export var parent_mark1:Marker2D
@export var parent_mark2:Marker2D
@export var child_mark:Marker2D
@export var menu:beetles_menu
@export var animation_player:AnimationPlayer
const PLAYER_BEETLE_DIR = "res://resources/beetle_resources/player_beetle/"
var parent_1:BeetleChassisData
var parent_2:BeetleChassisData
var current_child_data:BeetleChassisData
var ship1:Warship
var ship2:Warship
var ship_child:Warship
var selected_slots:Array[beetle_slot]

func _ready() -> void:
	menu.slot_clicked.connect(_on_slot_clicked)
	menu.canceled.connect(_on_breeding_canceled)
	menu.breede.connect(_on_breede_confirmed)
	menu.name_it.connect(_on_name_it)
	menu.sell_it.connect(_on_sell_it)
	menu.name_confirm.connect(_on_name_confirm)
	menu.return_to_town.connect(_on_return_to_town)
	
func _on_slot_clicked(slot:beetle_slot):
	if not parent_1:
		if slot.current_chassis:
			parent_1 = slot.current_chassis
			ship1 = BlueprintManager.build_ship(parent_1)
			ship1.scale *= 1.5
			add_child(ship1)
			ship1.global_position = parent_mark1.global_position
			ship1.visual_controller.play_starting_animation()
			var tween = create_tween()
			menu.animate_right_panel(slot,false)
			tween.parallel().tween_property(slot,"modulate:a",0.4,0.1)
			tween.parallel().tween_property(slot,"scale",Vector2(1,1),0.1)
			slot.mouse_in = false
			selected_slots.append(slot)
			slot.selected = true
			
	elif not parent_2:
		if slot.current_chassis:
			parent_2 = slot.current_chassis
			ship2 = BlueprintManager.build_ship(parent_2)
			ship2.scale *= 1.5
			add_child(ship2)
			ship2.global_position = parent_mark2.global_position
			ship2.visual_controller.play_starting_animation()
			var tween = create_tween()
			menu.animate_right_panel(slot,false)
			tween.parallel().tween_property(slot,"modulate:a",0.4,0.1)
			tween.parallel().tween_property(slot,"scale",Vector2(1,1),0.1)
			slot.mouse_in = false
			selected_slots.append(slot)
			slot.selected = true
	else:
		print("父母位置已满")
		return
	
func _on_breeding_canceled():
	parent_1 = null
	parent_2 = null
	parents_reset()
	for slot in selected_slots:
		var tween = create_tween()
		tween.parallel().tween_property(slot,"modulate:a",1,0.1)
		slot.selected = false
func _on_breede_confirmed():
	if not parent_1 or not parent_2:
		print('未选择父母甲虫')
		return
	animation_player.play("breed")
	await animation_player.animation_finished
	current_child_data = breed_beetles(parent_1,parent_2)
	ship_child = BlueprintManager.build_ship(current_child_data)
	ship_child.scale *= 1.5
	add_child(ship_child)
	ship_child.global_position = child_mark.global_position
	ship_child.visual_controller.play_starting_animation()
	var slot:beetle_slot = load("res://General_UI_parts/beetles_menu/beetle_slot.tscn").instantiate()
	add_child(slot)
	slot.global_position = Vector2(10000,0)
	slot.set_slot_with_chassis(current_child_data)
	await get_tree().create_timer(2).timeout
	menu.animate_right_panel(slot)
	remove_child(slot)
	slot.queue_free()
	menu.show_beetle_confirm_box()
	
	
func parents_reset():
	if ship1:
		remove_child(ship1)
		ship1.queue_free()
	if ship2:
		remove_child(ship2)
		ship2.queue_free()

func darken_scene():
	var tween = create_tween()
	tween.tween_property($CanvasModulate,"color",Color(0,0,0,1),0.7)

func light_scene():
	var tween = create_tween()
	tween.tween_property($CanvasModulate,"color",Color(1,1,1,1),0.7)
	
func child_reset():
	current_child_data = null
	remove_child(ship_child)
	ship_child.queue_free()

func _on_name_it():
	menu.hide_beetle_confirm_box()
	await get_tree().create_timer(0.5).timeout
	menu.show_name_confirm_box()
	
func _on_sell_it():
	parent_1 = null
	parent_2 = null
	menu.hide_beetle_confirm_box()
	menu.animate_right_panel(null,false)
	darken_scene()
	await get_tree().create_timer(1.5).timeout
	child_reset()
	light_scene()
	await get_tree().create_timer(1).timeout
	menu.set_up_menu()
	menu.init_panel()
	
func _on_name_confirm(text: String) -> void:
	#保存甲虫到文件
	parent_1 = null
	parent_2 = null
	save_player_beetle_to_disk(text)
	menu.hide_name_confirm_box()
	menu.animate_right_panel(null,false)
	darken_scene()
	await get_tree().create_timer(1.5).timeout
	child_reset()
	light_scene()
	await get_tree().create_timer(1).timeout
	menu.set_up_menu()
	menu.init_panel()
	
func _on_return_to_town():
	SceneManager.load_scene("res://Town_Scene/town.tscn")
	
func save_player_beetle_to_disk(ship_name:String):
	if not current_child_data:
		push_error("尝试确认甲虫，但甲虫未能成功加载")
		return
		
	# 1. 清理首尾空格，设置兜底名称
	var clean_name = ship_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "未命名甲虫"
		
	print("将甲虫 {name} 存入文件".format({"name": clean_name}))
	current_child_data.ship_name = clean_name
	
	# 2. 净化文件名，提取基础路径
	var safe_file_name = clean_name.validate_filename()
	var base_path = PLAYER_BEETLE_DIR + "/" + safe_file_name
	var full_path = base_path + ".tres"
	
	# 3. 【核心新增】：冲突检测与自动重命名
	var counter = 1
	while FileAccess.file_exists(full_path):
		# 如果文件已存在，则在原名后追加 _1, _2 等后缀并重新检测
		full_path = base_path + "_" + str(counter) + ".tres"
		counter += 1
		
	# 4. 执行保存 (此时的 full_path 绝对是一个未被占用的安全路径)
	current_child_data.save_to_disk(full_path)
# ==========================================
# 核心功能：甲虫配种 (基因重组)
# 接收两个父母蓝图，返回一个全新的子代蓝图
# ==========================================
func breed_beetles(parent_a: BeetleChassisData, parent_b: BeetleChassisData) -> BeetleChassisData:
	print("🧬 开始进行甲虫配种序列...")
	
	# 1. 诞生新的子代躯壳
	var child = BeetleChassisData.new()
	
	# 2. 基础底盘继承与数据重置
	# 因为同种类的基础底盘完全相同，直接继承其一即可
	child.base_ship_scene = parent_a.base_ship_scene
	child.ship_name = "" # 暂时留空，等待玩家赐名
	child.blueprint_data = {} # 纯净初生，没有任何地块污染
	
	# 3. 颜色遗传 (50% 概率继承父亲，50% 概率继承母亲)
	if randf() > 0.5:
		child.ship_color = parent_a.ship_color.duplicate()
		print("🎨 子代继承了 父本A 的颜色基因")
	else:
		child.ship_color = parent_b.ship_color.duplicate()
		print("🎨 子代继承了 母本B 的颜色基因")
		
	# 4. 基因池提取 (解析并分离 front, mid, back 模块)
	var gene_pool = {
		"front": [],
		"mid": [],
		"back": []
	}
	
	# 定义一个匿名函数来安全提取父母的部件
	var extract_genes = func(parent_data: BeetleChassisData):
		for packed_scene in parent_data.part_scenes:
			# 必须临时实例化才能读取到脚本里的 target_socket_name
			var temp_part = packed_scene.instantiate() as beetle_part_base
			if temp_part:
				var socket = temp_part.target_socket_name
				if gene_pool.has(socket):
					gene_pool[socket].append(packed_scene)
				else:
					push_warning("⚠️ 未知的部件插槽: " + socket)
			temp_part.queue_free() # 提取完插槽信息后，必须立刻销毁，防止内存泄漏
			
	# 将父母双方的部件分别倒入基因池
	extract_genes.call(parent_a)
	extract_genes.call(parent_b)
	
	# 5. 基因重组 (为子代抽取对应的部位)
	for socket in gene_pool.keys():
		var available_parts = gene_pool[socket]
		if available_parts.size() > 0:
			# 随机挑选该部位的一个部件（如果父母双方该部位是同一个，pick_random 也会完美处理）
			var selected_part = available_parts.pick_random()
			child.part_scenes.append(selected_part)
		else:
			push_error("❌ 严重基因缺陷：父母双方都没有提供 [%s] 槽位的部件！" % socket)
			
	print("✨ 配种完成！新生甲虫已诞生，共有 %d 个躯干部件。" % child.part_scenes.size())
	return child
