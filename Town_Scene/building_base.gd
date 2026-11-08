extends Node2D
class_name town_building_base

@export var area: Area2D
@export var to_scene: PackedScene
@export_multiline var desc_text: String

var mouse_is_in: bool = false
var _is_transitioning: bool = false # 【新增】防抖标记，防止动画期间重复触发跳转

func _ready() -> void:
	if area:
		if not area.mouse_entered.is_connected(_on_area_mouse_entered):
			area.mouse_entered.connect(_on_area_mouse_entered)
		if not area.mouse_exited.is_connected(_on_area_mouse_exited):
			area.mouse_exited.connect(_on_area_mouse_exited)

func _on_area_mouse_entered():
	if _is_transitioning: return
	material.set_shader_parameter("outline_width", 1)
	mouse_is_in = true

func _on_area_mouse_exited():
	material.set_shader_parameter("outline_width", 0)
	mouse_is_in = false
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			if mouse_is_in and not _is_transitioning:
				var confirm_box: town_confirm_box = get_tree().get_first_node_in_group("town_ui_confirm_box")
				confirm_box.text_label.text = desc_text
				confirm_box.current_building = self
				confirm_box.show_box()
				
# ==========================================
# 交互执行：转场动画与场景跳转
# ==========================================
func pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	
	# 1. 拦截输入，重置高光
	if area:
		area.input_pickable = false
	material.set_shader_parameter("outline_width", 0)
	
	# 2. 挂起主逻辑，等待独立的转场动画播完
	await play_transition_animation(0.8)
	
	# 3. 动画播完，安全跳转场景
	SceneManager.load_scene(to_scene)

func play_transition_animation(anim_duration: float = 0.8) -> void:
	var tween = create_tween().set_parallel(true)
	
	# 1. 摄像机移动与放大逻辑
	var camera = get_tree().get_first_node_in_group("Camera") as Camera2D
	if camera:
		# 平滑移动至当前建筑的中心坐标
		tween.tween_property(camera, "global_position", global_position, anim_duration)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			
		# 摄像机放大
		var target_zoom = camera.zoom * 2.5 
		tween.tween_property(camera, "zoom", target_zoom, anim_duration)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# 2. 生成全屏渐黑遮罩层
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100 # 确保渲染层级最高，盖住所有 UI
	get_tree().current_scene.add_child(canvas_layer)
	
	var fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0) # 初始完全透明
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT) # 铺满全屏
	canvas_layer.add_child(fade_rect)
	
	# 3. 播放渐黑动画
	tween.tween_property(fade_rect, "color:a", 1.0, anim_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 4. 阻塞当前协程，直到视觉动画结束
	await tween.finished
	await get_tree().create_timer(0.3).timeout
