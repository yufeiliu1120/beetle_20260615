extends TextureRect
class_name beetle_slot

var hp:int
var ap:int
var supply:int
var action_pool:Array[ActionData]
@export var silhouette_rect: TextureRect
@export var name_label:Label
var mouse_in:bool
var current_chassis:BeetleChassisData
var selected

signal slot_clicked(slot:beetle_slot)
signal slot_mouse_entered(slot:beetle_slot)
signal slot_mouse_exited(slot:beetle_slot)

# 定义卡面上甲虫图案的分辨率
const ICON_SIZE = Vector2(256, 256) 

# ==========================================
# 初始化：修正缩放轴心点
# ==========================================
func _ready() -> void:
	# 将缩放原点（轴心点）动态设置到该界面的正中心
	pivot_offset = size / 2.0
	
# 因为需要等待渲染帧，所以这个函数变成了异步执行
func set_slot_with_chassis(chassis: BeetleChassisData) -> void:
	name_label.text = chassis.ship_name
	# ==========================================
	# 1. 搭建临时摄影棚
	# ==========================================
	var viewport = SubViewport.new()
	viewport.transparent_bg = true 
	viewport.size = ICON_SIZE
	# 保持连续渲染，给着色器充足的反应时间
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS 
	add_child(viewport)
	
	var ship = BlueprintManager.build_ship(chassis)
	viewport.add_child(ship)
	current_chassis = chassis
	# 【核心修复 1】：强行覆盖过滤模式，防止边缘像素在视口中发生颜色混合
	ship.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# ==========================================
	# 2. 提取属性与排版
	# ==========================================
	ship.combatentity.init_action_pool(ship.hexgridmanager)
	action_pool = ship.combatentity.action_pool
	hp = ship.combatentity.calculate_base_hp()
	ap = ship.combatentity.calculate_base_ap()
	supply = ship.combatentity.calculate_base_max_supply()
	
	# 调整位置居中
	ship.position = Vector2(ICON_SIZE.x / 2.0, ICON_SIZE.y / 2.0)
	ship.scale = Vector2(0.65,0.5)
	# ==========================================
	# 3. 注入颜色并放宽 Shader 容差
	# ==========================================
	if ship.get("visual_controller") and "body_nodes" in ship.visual_controller:
		var theme_c = chassis.ship_color.get("theme_color", Color.WHITE)
		var deco_c = chassis.ship_color.get("decorative_color", Color.BLACK)
		
		for part in ship.visual_controller.body_nodes:
			if part.has_method("set_part_color"):
				part.set_part_color(true, theme_c)
				part.set_part_color(false, deco_c)
				
				# 【核心修复 2】：临时将容差放大，无视视口带来的任何通道偏移
				if part.material is ShaderMaterial:
					part.material.set_shader_parameter("tolerance", 0.4)
	
	if ship.has_method("play_idle"):
		ship.play_idle()
		
	# ==========================================
	# 4. 延时拍照与清理
	# ==========================================
	# 【核心修复 3】：等待 0.15 秒，确保现代 GPU 在后台完成了所有部位的着色器编译和渲染
	await get_tree().create_timer(0.15).timeout
	
	# 提取最终画面快照
	var img = viewport.get_texture().get_image()
	
	# 将快照印在卡面上
	if silhouette_rect:
		silhouette_rect.texture = ImageTexture.create_from_image(img)
	else:
		push_warning("⚠️ 卡牌 [%s] 未指定 silhouette_rect 子节点，图像无法显示！" % chassis.ship_name)
	
	# 销毁摄影棚
	viewport.queue_free()
	print("📸 甲虫彩色卡片 [%s] 生成完毕！" % chassis.ship_name)


func _on_mouse_entered() -> void:
	if selected:
		return
	var tween = create_tween()
	tween.parallel().tween_property(self,"scale",Vector2(1.1,1.1),0.1)
	tween.parallel().tween_property(self,"modulate:a",3,0.1)
	slot_mouse_entered.emit(self)
	mouse_in = true
	
func _on_mouse_exited() -> void:
	if selected:
		return
	var tween = create_tween()
	tween.parallel().tween_property(self,"modulate:a",1,0.1)
	tween.parallel().tween_property(self,"scale",Vector2(1,1),0.1)
	slot_mouse_exited.emit(self)
	mouse_in = false
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			if mouse_in:
				slot_clicked.emit(self)
