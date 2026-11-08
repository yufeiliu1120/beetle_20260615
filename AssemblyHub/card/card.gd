class_name TileCard
extends Control 

@export var tile_scene: PackedScene 
@onready var card_menu = $Control  
const card_menu_default_position:Vector2 = Vector2(620,-10)
var my_card_path: String = "" 

var _move_tween: Tween 
var is_menu_open: bool = false # 【新增】：记录当前卡牌的菜单状态

signal card_clicked(new_tile: TileBase, card_path: String)

func _ready():
	if _is_in_assembly_hub() or _is_in_explore_scene():
		card_menu.hide()
		
	# 【核心修改 1】：如果是探索场景，将卡牌加入全局分组，方便统一调度
	if _is_in_explore_scene():
		add_to_group("explore_cards")
		
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	await get_tree().process_frame
	
func instantiate_tile() -> TileBase:
	if tile_scene != null:
		return tile_scene.instantiate() as TileBase
	return null

# ==========================================
# 场景检测辅助函数
# ==========================================
func _is_in_assembly_hub() -> bool:
	var root = get_tree().current_scene
	return root is assumbly_hub_scene
	
func _is_in_explore_scene() -> bool:
	var root = get_tree().current_scene
	return root is text_explore_scene

# ==========================================
# 【核心修改 2】：全局输入监听 (处理鼠标右键收回)
# ==========================================
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# 玩家在探索场景下按下右键，如果菜单是开着的，强制关闭
		if _is_in_explore_scene() and is_menu_open:
			force_close_menu()

# ==========================================
# 交互逻辑 (处理鼠标左键点击展开)
# ==========================================
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		
		# 【隔离逻辑 1】：组装场景防抖
		if _is_in_assembly_hub() and get_tree().get_nodes_in_group("DraggingTile").size() > 0:
			return 
			
		# ==========================================
		# 【核心修改 3】：探索场景的互斥展开逻辑
		# ==========================================
		if _is_in_explore_scene():
			if is_menu_open:
				# 如果点的是自己且已经展开，则收回
				force_close_menu()
			else:
				# 1. 广播：让组内所有其他卡牌强行收回面板！
				get_tree().call_group("explore_cards", "force_close_menu")
				
				# 2. 独享：初始化自己的信息并展开
				is_menu_open = true
				set_card_menu()
				play_explore_unfold_anim()
			
		var new_tile = instantiate_tile()
		if new_tile:
			if _is_in_assembly_hub():
				new_tile.add_to_group("DraggingTile") 
			
			card_clicked.emit(new_tile, my_card_path)
			
		# 拦截鼠标事件，防止穿透到底层 UI
		accept_event()

func set_card_menu():
	var tile_instantiate = tile_scene.instantiate()
	card_menu.set_card_menu(tile_instantiate)
		
# ==========================================
# 【核心修改 4】：鼠标悬浮与移出表现 (剥离动画逻辑，仅保留发光)
# ==========================================
func _on_mouse_entered() -> void:
	var tween = create_tween()
	tween.tween_property(self,"self_modulate",Color(3.0,3.0,3.0,1),0.25)
	
	if _is_in_assembly_hub():
		set_card_menu()
		card_menu.show()

func _on_mouse_exited() -> void:
	var tween = create_tween()
	tween.tween_property(self,"self_modulate",Color(1.0,1.0,1.0,1),0.25)
	
	if _is_in_assembly_hub():
		card_menu.hide()

# ==========================================
# 【核心修改 5】：强制关闭接口 (供全局 Group 调用)
# ==========================================
func force_close_menu() -> void:
	if is_menu_open:
		is_menu_open = false
		play_explore_fold_anim()

# ==========================================
# 探索场景专属动画封装接口 (全局飞入飞出版)
# ==========================================
func play_explore_unfold_anim(play_animation:bool = true) -> void:
	card_menu.show() 
	if card_menu.has_method("unfold_from_title"):
		card_menu.unfold_from_title(0.3,play_animation)

	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
		
	# 【核心修改 1：动态提权】在赋予 top_level 前，先记录它当前的真实屏幕位置
	var current_global_pos = card_menu.global_position
	card_menu.top_level = true
	# 脱离父节点后，手动补偿原本继承自父节点的 0.5 缩放
	card_menu.scale = Vector2(0.5, 0.5)
	# 瞬间赋回全局坐标，确保它在这一帧绝对不会发生位置跳变
	card_menu.global_position = current_global_pos
		
	_move_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target_marker = get_tree().get_first_node_in_group("tile_card_position")
	if target_marker:
		_move_tween.tween_property(card_menu, "global_position", target_marker.global_position, 0.3)
	else:
		# 兜底情况，基于卡牌当前位置往上飞
		var fallback_pos = self.global_position + Vector2(0, -234.0)
		_move_tween.tween_property(card_menu, "global_position", fallback_pos, 0.3)

func play_explore_fold_anim(play_animation:bool = true) -> void:
	if card_menu.has_method("fold_to_title"):
		card_menu.fold_to_title(0.3,play_animation)
	
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
		
	# 【核心修复】：如果不播放动画（例如初始化时），直接瞬间解除 top_level 并归位
	if not play_animation:
		card_menu.top_level = false
		card_menu.scale = Vector2(1.0, 1.0)
		card_menu.position = card_menu_default_position
		return
		
	# 下方的动画逻辑保持不变（仅在 play_animation 为 true 时执行）
	_move_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target_pos = self.global_position + (card_menu_default_position * 0.5)
	_move_tween.tween_property(card_menu, "global_position", target_pos, 0.3)
	
	_move_tween.tween_callback(func():
		card_menu.top_level = false
		card_menu.scale = Vector2(1.0, 1.0)
		card_menu.position = card_menu_default_position
	)

# ==========================================
# 尺寸计算
# ==========================================
func get_slot_size_key() -> String:
	var offsets: Array[Vector2i] = [Vector2i.ZERO]
	
	if tile_scene != null:
		var temp_tile = tile_scene.instantiate()
		if "shape_offsets" in temp_tile:
			offsets = temp_tile.shape_offsets
		temp_tile.queue_free()
		
	var min_y: int = offsets[0].y
	var max_y: int = offsets[0].y
	
	var first_visual_x: int = 2 * offsets[0].x + offsets[0].y
	var min_visual_x: int = first_visual_x
	var max_visual_x: int = first_visual_x
	
	for offset in offsets:
		if offset.y < min_y: min_y = offset.y
		if offset.y > max_y: max_y = offset.y
		
		var visual_x: int = 2 * offset.x + offset.y
		if visual_x < min_visual_x: min_visual_x = visual_x
		if visual_x > max_visual_x: max_visual_x = visual_x
		
	var span_y: int = max_y - min_y
	var span_visual_x: int = max_visual_x - min_visual_x
	
	var size_y: int = 1
	if span_y == 0:
		size_y = 1
	elif span_y <= 2:
		size_y = 2
	else:
		size_y = 3
		
	var size_x: int = 1
	if span_visual_x <= 2:
		size_x = 1
	elif span_visual_x <= 4:
		size_x = 2
	else:
		size_x = 3
	
	return "%d*%d" % [size_y, size_x]
