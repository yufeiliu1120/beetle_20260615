extends Control
@export_enum("pirate","elf","shark") var card_theme:String
@export_enum("normal","rare","special") var card_rarity:String
@export_group("UI_parts")
@export var Titel:Label
@export var Text_label:RichTextLabel
@export var tag_box:HBoxContainer
@export var Action_desc:RichTextLabel
@export var tag_container:PackedScene
@export var Action_Title:Label
@export var Action_panel:PanelContainer
@export var card_back:TextureRect
@export var text_panel:TextureRect
# 用于记录当前卡牌折叠状态，以及是否包含动作面板
var _current_tween: Tween
var _is_folded: bool = false
var _has_action: bool = false

var card:TileCard
signal menu_click

func _ready() -> void:
	card = get_parent()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if not card._is_in_assembly_hub():
		mouse_filter = Control.MOUSE_FILTER_PASS
	
var theme_sprits:Dictionary = {"pirate": {"normal":"res://assets/cards/card_base/pirate_normal_label.png",
											"rare":"res://assets/cards/card_base/pirate_rare_label.png",
											"special":"res://assets/cards/card_base/pirate_special_label.png",
											"Action": "res://assets/cards/card_base/pirate_panel.png"},
								"elf": {},
								"shark":{}}
								
func add_tag(tag:String) -> void:
	var tag_container = tag_container.instantiate()
	tag_box.add_child(tag_container)
	tag_container.text_label.text = tag

func clear_tags():
	for tag in tag_box.get_children():
		tag.queue_free()

func set_card_menu(tile:TileBase):
	#确定卡牌的品质和主题
	if tile.theme:
		if tile.theme in theme_sprits.keys():
			card_back.texture = load(theme_sprits[tile.theme][tile.rarity])
	
	
	Titel.text = tile.tile_name
	Text_label.text = tile.description
	#
	#如果地块提供动作，便为动作栏填充信息
	if tile.base_action:
		_has_action = true # 【新增】
		clear_tags()
		Action_desc.text = tile.base_action.set_text()
		Action_Title.text = tile.base_action.action_name
		for tag in tile.base_action.tags:
			add_tag(tag)
	else:
		_has_action = false # 【新增】
		Action_panel.hide()
		
	if get_tree().get_first_node_in_group("card_menu_position"):
		global_position = get_tree().get_first_node_in_group("card_menu_position").global_position
	
func _on_mouse_entered() -> void:
	var tween = create_tween()
	tween.tween_property(self,"self_modulate",Color(3.0,3.0,3.0,1),0.25)


func _on_mouse_exited() -> void:
	var tween = create_tween()
	tween.tween_property(self,"self_modulate",Color(1.0,1.0,1.0,1),0.25)
	
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if card._is_in_assembly_hub():
			return 
			
		var new_tile = card.instantiate_tile()
		if new_tile:
			# 【隔离逻辑 2】：只有在组装场景中，生成的地块才需要打上“拖拽中”的专属标签
			if card._is_in_assembly_hub():
				new_tile.add_to_group("DraggingTile") 
		
		if card._is_in_explore_scene():
			if card.is_menu_open:
				# 如果点的是自己且已经展开，则收回
				card.force_close_menu()
			else:
				# 1. 广播：让组内所有其他卡牌强行收回面板！
				get_tree().call_group("explore_cards", "force_close_menu")
				
				# 2. 独享：初始化自己的信息并展开
				card.is_menu_open = true
				card.set_card_menu()
				card.play_explore_unfold_anim()
			# 【核心修改】：信号在所有场景都会毫无保留地发出！
			# 组装场景用它来开启拖拽，奖励场景用它来把卡牌加入背包
		card.card_clicked.emit(new_tile, card.my_card_path)
			
			
		# 拦截鼠标事件，防止穿透到底层 UI
		accept_event()

# ==========================================
# 动画效果：向标题栏折叠
# ==========================================
func fold_to_title(duration: float = 0.3, use_anim: bool = true) -> void:
	z_index = 0
	if _is_folded: return
	_is_folded = true
	
	# 如果上一个动画还没播完，立刻掐断它，防止回调冲突
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	text_panel.pivot_offset = Vector2(text_panel.size.x / 2.0, 0)
	Action_panel.pivot_offset = Vector2(0, Action_panel.size.y / 2.0)
	
	# 如果不需要播放动画，瞬间设置为目标状态并退出
	if not use_anim:
		text_panel.scale.y = 0.0
		text_panel.modulate.a = 0.0
		text_panel.hide()
		
		if _has_action:
			Action_panel.scale.x = 0.0
			Action_panel.modulate.a = 0.0
			Action_panel.hide()
		return
	
	_current_tween = create_tween().set_parallel(true)
	_current_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	_current_tween.tween_property(text_panel, "scale:y", 0.0, duration)
	_current_tween.tween_property(text_panel, "modulate:a", 0.0, duration)
	
	if _has_action:
		_current_tween.tween_property(Action_panel, "scale:x", 0.0, duration)
		_current_tween.tween_property(Action_panel, "modulate:a", 0.0, duration)
		
	# 只有当这个动画没被中断，正常播完时，才会执行隐藏
	_current_tween.chain().tween_callback(func():
		text_panel.hide()
		Action_panel.hide()
	)

# ==========================================
# 动画效果：从标题栏展开复原
# ==========================================
func unfold_from_title(duration: float = 0.3, use_anim: bool = true) -> void:
	z_index = 999
	if not _is_folded: return
	_is_folded = false
	
	# 立刻掐断正在进行中的折叠动画，阻止其触发 hide()
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	text_panel.show()
	if _has_action:
		Action_panel.show()
		
	# 如果不需要播放动画，瞬间设置为目标状态并退出
	if not use_anim:
		text_panel.scale.y = 1.0
		text_panel.modulate.a = 1.0
		
		if _has_action:
			Action_panel.scale.x = 1.0
			Action_panel.modulate.a = 1.0
		return
		
	_current_tween = create_tween().set_parallel(true)
	_current_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	_current_tween.tween_property(text_panel, "scale:y", 1.0, duration)
	_current_tween.tween_property(text_panel, "modulate:a", 1.0, duration)
	
	if _has_action:
		_current_tween.tween_property(Action_panel, "scale:x", 1.0, duration)
		_current_tween.tween_property(Action_panel, "modulate:a", 1.0, duration)
