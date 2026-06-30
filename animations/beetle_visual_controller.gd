extends Node2D
class_name visual_controller
#储存所有部件的视觉组件
@export var body_nodes:Array[Node2D]
@export var body_shadows:Array[Node2D]
@export var emerge_duration: float = 1.5
@export var particle_nodes:Array[GPUParticles2D]
@export var animation_player:AnimationPlayer
@export var hit_particle:GPUParticles2D

signal action_impact
#受击动画使用的变量
var hit_tween: Tween
var base_position: Vector2 = Vector2.ZERO

signal entrance_finished

func reset_to_sand() -> void:
	for part in body_nodes:
		if part is AnimatedSprite2D:
			part.animation = "Float"
		if part.material is ShaderMaterial:
			part.material.set_shader_parameter("progress", -0.1)
	for shadow in body_shadows:
		shadow.modulate = Color(0,0,0,0)
	for particle in particle_nodes:
		particle.emitting = false
	get_parent().hexgridmanager.modulate = Color(1,1,1,0)
		
#播放所有甲虫出现时的视觉效果
func play_starting_animation():
	reset_to_sand()
	var camera = get_tree().get_first_node_in_group("Camera")
	if not camera:
		push_error("未找到相机节点")
	camera.add_trauma(1.0)
	for particle in particle_nodes:
		particle.emitting = true
	await get_tree().create_timer(1).timeout
	play_emerge_animation()
	await get_tree().create_timer(1).timeout
	show_tiles()
	
func play_emerge_animation() -> void:
	# 1. 创建一个 Tween，并设置为【并行模式】(set_parallel)
	# 这会让接下来的所有 tween_property 同时执行，而不是排队执行
	var tween = create_tween().set_parallel(true)
	# 2. 遍历所有子节点，筛选出挂载了我们 Shader 的 Sprite2D
	for child in body_nodes:
		if child.material is ShaderMaterial:
			# 同时让所有部件的 progress 从当前值渐变到 1.1
			tween.tween_property(
				child.material, 
				"shader_parameter/progress", 
				1.1, 
				emerge_duration
			)
	# 3. 动画结束后的后续处理
	tween.tween_callback(show_shadow).set_delay(1.4)
	# 因为开启了并行模式，需要用 .chain() 告诉 Tween：等上面的所有并行完结后，再执行这行回调
	tween.chain().tween_callback(self._on_emerge_completed)

func show_shadow():
	var tween = create_tween().set_parallel(true)
	if get_parent().is_player:
		for shadow in body_shadows:
			tween.tween_property(shadow,"position",Vector2(-5,-1),0.1)
			tween.tween_property(shadow,"modulate",Color(0,0,0,0.5),0.1)
	else:
		for shadow in body_shadows:
			tween.tween_property(shadow,"position",Vector2(5,-1),0.1)
			tween.tween_property(shadow,"modulate",Color(0,0,0,0.5),0.1)
		
func _on_emerge_completed() -> void:
	for particle in particle_nodes:
		particle.emitting = false
	print("甲虫出土动画完成")
	await get_tree().create_timer(randf_range(0,0.8)).timeout
	animation_player.play("Idle")
	get_tree().create_timer(1).timeout
	entrance_finished.emit()

#背上地块逐渐出现的动画
func show_tiles():
	get_parent().hexgridmanager.modulate = Color(1,1,1,0)
	var tween = create_tween()
	tween.parallel().tween_property(get_parent().hexgridmanager,"modulate",Color(1,1,1,1),0.5)


#受到伤害时触发的动画效果
func take_hit() -> void:
	print("💥 甲虫受到了伤害，播放震动与闪白反馈！")
	
	# ==============================
	# 1. 物理震动反馈 (保持你现有的不变)
	# ==============================
	if hit_tween and hit_tween.is_valid():
		hit_tween.kill()
		position = base_position 
		
	hit_tween = create_tween()
	var shake_strength: float = 18.0
	var shake_duration: float = 0.04
	var shake_count: int = 5
	
	for i in range(shake_count):
		var random_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * shake_strength
		hit_tween.tween_property(self, "position", base_position + random_offset, shake_duration).set_trans(Tween.TRANS_SINE)
		shake_strength *= 0.6
		
	hit_tween.tween_property(self, "position", base_position, shake_duration)

	# ==============================
	# 2. 视觉闪白反馈 (全新加入)
	# ==============================
	var flash_tween = create_tween().set_parallel(true) # 开启并行，让所有部件一起闪
	
	for child in body_nodes:
		if child.material is ShaderMaterial:
			# 瞬间将闪白拉满 (1.0)
			child.material.set_shader_parameter("flash_modifier", 1.0)
			
			# 用 Tween 在 0.15 秒内平滑褪回正常颜色 (0.0)
			flash_tween.tween_property(
				child.material, 
				"shader_parameter/flash_modifier", 
				0.0, 
				0.5
			)
			
	#---------------------------
	#3.触发粒子特效
	#---------------------------
	if not hit_particle:
		push_warning("未找到受击粒子特效节点")
		pass
	else:
		hit_particle.restart()
		hit_particle.emitting = true
		
		
	#---------------------------
	#4.屏幕抖动效果
	#---------------------------
	var camera = get_tree().get_first_node_in_group("Camera") as custom_camera
	if not camera:
		push_warning("未找到相机节点")
		pass
	else:
		camera.add_trauma(0.3)
	
func trigger_impact() -> void:
	print("⚡ 动画轨道触发了打击点！")
	action_impact.emit()
