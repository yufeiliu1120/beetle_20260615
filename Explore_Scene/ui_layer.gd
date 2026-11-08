extends CanvasLayer
class_name explore_ui

@export var _hp_bar: hp_bar
@export var pool: VBoxContainer
@export var pool_panel: PanelContainer
@export var pool_top: TextureRect
@export var tile_pack_top:TextureRect
@export var tile_pack_container:ScrollContainer
@export var tile_pack_panel:PanelContainer
@export var _supply_bar:supply_bar
@export var tile_card_position:Control
@export var pack_container:VBoxContainer

# 记录当前面板的展开状态
var _is_pack_expanded:bool = false
var _is_panel_expanded: bool = false
var _action_slot = preload("res://General_UI_parts/action_slot/action_slot.tscn")

#外部用接口，设置UI内容
func set_UI_layer():
	_hp_bar.set_hp_bar()
	_supply_bar.set_bar()
	PlayerData.hp_changed.connect(_hp_bar.set_hp_bar)
	PlayerData.supply_changed.connect(_supply_bar.set_bar)
	set_pool()

func set_pool():
	pool.get_children().clear()
	for action in PlayerData.action_pool:
		var slot = _action_slot.instantiate() as action_slot
		pool.add_child(slot)
		slot.set_action_slot(action)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_pack():
	#清理旧背包
	for slot in pack_container.get_children():
		if slot is ui_tile_card_slot:
			pack_container.remove_child(slot)
			slot.queue_free()
	
	var slot_path = "res://Explore_Scene/ui_tile_card_slot.tscn"
	for card_path in PlayerData.card_backpack:
		#实例化卡牌
		var slot:ui_tile_card_slot = load(slot_path).instantiate()
		pack_container.add_child(slot)
		slot.set_up_slot_with_card(card_path)
	pass

func _ready() -> void:
	pool_panel.modulate.a = 0
	tile_pack_panel.modulate.a = 0
	pool_panel.hide()
	tile_pack_panel.hide()
	
	# 核心修改 1：确保 TextureRect 能接收鼠标输入
	# （TextureRect 的默认 mouse_filter 往往是 IGNORE，这里用代码强行开启防患于未然）
	pool_top.mouse_filter = Control.MOUSE_FILTER_PASS
	tile_pack_top.mouse_filter = Control.MOUSE_FILTER_PASS
	# 核心修改 2：绑定 UI 专属的输入信号，代替原本的悬浮信号
	pool_top.gui_input.connect(_on_pool_top_gui_input)
	pool_top.mouse_entered.connect(_on_top_mouse_entered)
	pool_top.mouse_exited.connect(_on_top_mouse_exited)
	tile_pack_top.gui_input.connect(_on_tile_pack_top_gui_input)
	tile_pack_top.mouse_entered.connect(_on_tile_pack_top_mouse_entered)
	tile_pack_top.mouse_exited.connect(_on_tile_pack_top_mouse_exited)
	
# =====================================================
# 处理动作池的收放动画的函数[cite: 15]
# =====================================================
# =====================================================
# 鼠标点击切换逻辑
# =====================================================
func _on_pool_top_gui_input(event: InputEvent) -> void:
	# 检测鼠标左键的“按下”瞬间
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 状态翻转：关变开，开变关
		_is_panel_expanded = not _is_panel_expanded
		var tween = create_tween()
		tween.tween_property(pool_top,"modulate",Color(0.5,0.5,0.5,1),0.1)
		tween.chain().tween_property(pool_top,"modulate",Color(1,1,1,1),0.1)
		# 触发动画（注意 animate_panel_fold 的第三个参数 fold：true为折叠，false为展开）
		animate_panel_fold(pool_panel, "up", not _is_panel_expanded)

func _on_tile_pack_top_gui_input(event:InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_is_pack_expanded = not _is_pack_expanded
		var tween = create_tween()
		tween.tween_property(tile_pack_top,"modulate",Color(0.5,0.5,0.5,1),0.1)
		tween.chain().tween_property(tile_pack_top,"modulate",Color(1,1,1,1),0.1)
		
		# 【核心修复】：只有在面板即将展开时，才去刷新卡牌实例
		if _is_pack_expanded:
			set_pack()
			
		tile_pack_container.clip_contents = true
		await animate_panel_fold(tile_pack_panel, "up", not _is_pack_expanded)
# =====================================================
# 处理动作池的收放动画的函数 (完全保持你原来的代码不变)
# =====================================================
func animate_panel_fold(panel: PanelContainer, direction: String, fold: bool, duration: float = 0.25) -> void:
	if not is_instance_valid(panel):
		push_error("❌ animate_panel_fold: 目标 PanelContainer 实例无效！")
		return
		
	# 确保开启裁切，防止缩小过程中内容溢出
	panel.clip_contents = true
	
	if panel.has_meta("active_tween"):
		var old_tween = panel.get_meta("active_tween") as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
			
	var full_size = panel.get_combined_minimum_size()
	
	# 设置全并行模式，所有 tween_property 会同时播放
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	panel.set_meta("active_tween", tween)
	
	if not fold:
		panel.visible = true
		
	match direction.to_lower():
		"up", "down":
			if fold:
				tween.tween_property(panel, "custom_maximum_size:y", 0.0, duration)
				tween.tween_property(panel, "size:y", 0.0, duration)
				tween.tween_property(panel, "modulate:a", 0.0, duration)
				tween.chain().tween_callback(func(): panel.visible = false)
			else:
				if panel.custom_maximum_size.y < 0:
					panel.custom_maximum_size.y = 0.0
					
				tween.tween_property(panel, "custom_maximum_size:y", 732, duration)
				tween.tween_property(panel, "size:y", 732, duration)
				tween.tween_property(panel, "modulate:a", 1.0, duration)
				
				tween.chain().tween_callback(func(): panel.custom_maximum_size.y = -1.0)
				
		"left", "right":
			if fold:
				tween.tween_property(panel, "custom_maximum_size:x", 0.0, duration)
				tween.tween_property(panel, "size:x", 0.0, duration)
				tween.tween_property(panel, "modulate:a", 0.0, duration)
				tween.chain().tween_callback(func(): panel.visible = false)
			else:
				if panel.custom_maximum_size.x < 0:
					panel.custom_maximum_size.x = 0.0
					
				tween.tween_property(panel, "custom_maximum_size:x", full_size.x, duration)
				tween.tween_property(panel, "size:x", full_size.x, duration)
				tween.tween_property(panel, "modulate:a", 1.0, duration)
				
				tween.chain().tween_callback(func(): panel.custom_maximum_size.x = -1.0)
				
		_:
			push_error("❌ 未知的折叠方向: %s" % direction)
			return


func _on_top_mouse_entered():
	pool_top.modulate = Color(1.5,1.5,1.5,1)
	
func _on_top_mouse_exited():
	pool_top.modulate = Color(1,1,1,1)
	
func _on_tile_pack_top_mouse_entered():
	tile_pack_top.modulate = Color(1.5,1.5,1.5,1)
	
func _on_tile_pack_top_mouse_exited():
	tile_pack_top.modulate = Color(1,1,1,1)
