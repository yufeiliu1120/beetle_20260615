extends CanvasLayer

var cursor_normal = preload("res://assets/General/mouse.png")
var cursor_clicked = preload("res://assets/General/mouse_clicked.png") 
var hotspot = Vector2(0, 0) 

# 【新增】：预存 GPU 粒子的材质，避免每次点击重复创建浪费性能
var click_particle_material: ParticleProcessMaterial

func _ready() -> void:
	layer = 128
	Input.set_custom_mouse_cursor(cursor_normal, Input.CURSOR_ARROW, hotspot)
	
	# ==========================================
	# 初始化 GPU 粒子材质与渐变效果
	# ==========================================
	click_particle_material = ParticleProcessMaterial.new()
	# 告诉材质这是 2D 粒子
	click_particle_material.particle_flag_disable_z = true 
	
	# 物理参数转移到 Material 中
	click_particle_material.spread = 180.0
	click_particle_material.gravity = Vector3(0, 0, 0) # GPU 粒子的重力使用 Vector3
	click_particle_material.initial_velocity_min = 40.0
	click_particle_material.initial_velocity_max = 80.0
	click_particle_material.damping_min = 100.0
	click_particle_material.damping_max = 100.0
	click_particle_material.scale_min = 3.0
	click_particle_material.scale_max = 6.0
	
	# 【核心】：颜色渐变（从不透明到完全透明）
	var gradient = Gradient.new()
	# 设置起始点 (索引0) 的颜色为淡黄色，Alpha 1.0 (不透明)
	gradient.set_color(0, Color(1.0, 0.9, 0.6, 1.0))
	# 设置结束点 (索引1) 的颜色为淡黄色，Alpha 0.0 (完全透明)
	gradient.set_color(1, Color(1.0, 0.9, 0.6, 0.0))
	
	# 将渐变转化为纹理并交给材质
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	click_particle_material.color_ramp = gradient_texture

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			Input.set_custom_mouse_cursor(cursor_clicked, Input.CURSOR_ARROW, hotspot)
			_spawn_click_sparkle(event.position)
		else:
			Input.set_custom_mouse_cursor(cursor_normal, Input.CURSOR_ARROW, hotspot)

# ==========================================
# GPU 粒子生成逻辑
# ==========================================
func _spawn_click_sparkle(pos: Vector2) -> void:
	# 改用性能更高的 GPUParticles2D
	var particles = GPUParticles2D.new()
	
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.35
	particles.amount = 6
	
	# 【核心】：直接套用我们在 _ready 里捏好的高性能缓存材质
	particles.process_material = click_particle_material
	
	add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	
	# 销毁节点
	var timer = get_tree().create_timer(0.4)
	timer.timeout.connect(particles.queue_free)
