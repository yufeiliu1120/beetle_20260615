extends Node2D
class_name MapNode

var node_data: MapNodeData

@export var is_locked: bool = false 
@export var menu_scene: PackedScene # 【新增】：请在检查器中拖入你拆分好的 MapNodeMenu 场景

@onready var visuals: Node2D = $Visuals
@onready var click_area: Area2D = $ClickArea
@onready var ui_marker: Marker2D = $Marker2D # 【新增】：获取你放置在场景中的标记点
@export var icon_sprite: Sprite2D

signal node_selected(node: MapNode)
signal start_voyage(node: MapNode)

var _hover_tween: Tween
var _active_menu: MapNodeMenu
var _menu_canvas: CanvasLayer # 用于装载信息框的顶层画板

func _ready() -> void:
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	click_area.input_event.connect(_on_input_event)
	visuals.scale = Vector2.ZERO
	
# ==========================================
# 视觉初始化
# ==========================================
func setup(Data: MapNodeData) -> void:
	if Data.icon != null:
		icon_sprite.texture = Data.icon
	var result = Data.duplicate()
	Data.target_scene = Data.target_scene.duplicate()
	node_data = result
	$AnimationPlayer.play("start")

# ==========================================
# 交互动画
# ==========================================
func _on_mouse_entered() -> void:
	if is_locked: return
	if _hover_tween and _hover_tween.is_valid(): _hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(visuals, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	if is_locked: return
	if _hover_tween and _hover_tween.is_valid(): _hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(visuals, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_locked: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_tween = create_tween()
		click_tween.tween_property(visuals, "scale", Vector2(0.9, 0.9), 0.1)
		click_tween.tween_property(visuals, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BOUNCE)
		
		node_selected.emit(self)
		
# ==========================================
# 信息框生成与挂载逻辑
# ==========================================
func show_information(supply_cost: int) -> void:
	# 确保不出现重复的面板
	hide_panel()
	
	# 1. 动态生成专属的 CanvasLayer 并赋予极高的层级，确保突破一切遮挡
	_menu_canvas = CanvasLayer.new()
	_menu_canvas.layer = 100 
	add_child(_menu_canvas)
	
	# 2. 实例化分离出去的信息框场景
	_active_menu = menu_scene.instantiate() as MapNodeMenu
	_menu_canvas.add_child(_active_menu)
	
	# 3. 准备数据并初始化信息框
	var color_hex: String = "#51cf66" if PlayerData.current_supply >= supply_cost else "#ff6b6b"
	var text_content = node_data.description + "\n[color=%s]Supply: %d[/color]" % [color_hex, supply_cost]
	_active_menu.setup(self, text_content)

	# 4. 强制执行一次坐标同步
	_update_menu_position()

func hide_panel() -> void:
	# 连同 CanvasLayer 一起彻底销毁，释放内存
	if is_instance_valid(_active_menu):
		_active_menu.queue_free()
	if is_instance_valid(_menu_canvas):
		_menu_canvas.queue_free()
		
func _on_menu_start_pressed():
	start_voyage.emit(self)
	hide_panel() # 点击后自动收起信息框

# ==========================================
# 坐标实时投影：让 UI 紧紧咬住 2D 世界的坐标
# ==========================================
func _process(_delta: float) -> void:
	if is_instance_valid(_active_menu) and is_instance_valid(ui_marker):
		_update_menu_position()
		
func _update_menu_position() -> void:
	# 核心黑魔法：把 Marker2D 所处的地图世界坐标，无视摄像机缩放平移，转换为纯粹的屏幕 UI 坐标
	var screen_pos = ui_marker.get_global_transform_with_canvas().origin
	_active_menu.global_position = screen_pos
