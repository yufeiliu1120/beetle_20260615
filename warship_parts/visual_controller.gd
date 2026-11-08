extends Node2D
class_name visual_controller
#储存所有部件的视觉组件
@export var body_nodes:Array[Node2D]
@export var emerge_duration: float = 1.5
@export var particle_nodes:Array[GPUParticles2D]
@export var animation_player:AnimationPlayer
@export var hit_particle:GPUParticles2D
@export var DamageTextNode:Marker2D
@export var use_sand_emerge: bool = true
var damage_text_scene:PackedScene = preload("res://warship_parts/damage_text_node.tscn")
signal action_impact
#受击动画使用的变量
var hit_tween: Tween
var base_position: Vector2 = Vector2.ZERO
var death_tween: Tween # [新增] 用于持续的死亡动画循环

signal entrance_finished

func reset_to_sand(play_anim: bool = false) -> void:
	if play_anim:
		# ==========================================
		# 动画分支：播放甲虫钻回沙子的反向登场动画
		# ==========================================
		var fade_tween = create_tween().set_parallel(true)
		var parent = get_parent()
		
		# 1. 优先隐藏背上的地块网格
		if parent and "hexgridmanager" in parent and parent.hexgridmanager:
			fade_tween.tween_property(parent.hexgridmanager, "modulate", Color(1, 1, 1, 0), 0.5)
			
		# 2. 隐藏下方阴影
		for socket in body_nodes:
			var part = _get_part_in_socket(socket)
			if part and part.shadow:
				fade_tween.tween_property(part.shadow, "modulate", Color(0, 0, 0, 0), 0.5)
				
		# 等待网格和阴影消失
		await fade_tween.finished
		
		# 3. 喷射沙尘粒子，模拟下潜动作
		for particle in particle_nodes:
			particle.emitting = true
			
		var dive_tween = create_tween().set_parallel(true)
		
		# 4. 控制 Shader 参数，让甲虫从 1.1 溶解至 -0.1
		for socket in body_nodes:
			var part = _get_part_in_socket(socket)
			if part and part.material is ShaderMaterial:
				dive_tween.tween_property(
					part.material, 
					"shader_parameter/progress", 
					-0.1, 
					emerge_duration
				)
				
		# 等待身体完全沉入沙子
		await dive_tween.finished
		
		# 5. 扫尾工作：关闭粒子，重置静态帧
		for particle in particle_nodes:
			particle.emitting = false
			
		for socket in body_nodes:
			var part = _get_part_in_socket(socket)
			if part and part.sprite_frames:
				if part.sprite_frames.has_animation("Float"):
					part.animation = "Float"
				elif part.sprite_frames.has_animation("default"):
					part.animation = "default"

	else:
		# ==========================================
		# 默认分支：瞬间重置（保留原版逻辑）
		# ==========================================
		# 1. 安全重置所有插槽内的部件
		for socket in body_nodes:
			var part = _get_part_in_socket(socket)
			if part:
				if part.sprite_frames:
					if part.sprite_frames.has_animation("Float"):
						part.animation = "Float"
					elif part.sprite_frames.has_animation("default"):
						part.animation = "default"
				
				# 材质和阴影部分保持不变
				if part.material is ShaderMaterial:
					part.material.set_shader_parameter("progress", -0.1)
					
				if part.shadow:
					part.shadow.modulate = Color(0, 0, 0, 0)
					
		# 2. 重置沙尘粒子
		for particle in particle_nodes:
			if particle:
				particle.emitting = false
			
		# 3. 安全隐藏网格
		var parent = get_parent()
		if parent and "hexgridmanager" in parent and parent.hexgridmanager:
			parent.hexgridmanager.modulate = Color(1, 1, 1, 0)
		
#播放所有甲虫出现时的视觉效果
# ==========================================
# 登场动画流程
# ==========================================
func play_starting_animation():
	if use_sand_emerge:
		# 分支 A：甲虫专用的钻地登场
		reset_to_sand()
		var camera = get_tree().get_first_node_in_group("Camera")
		if camera and camera.has_method("add_trauma"):
			camera.apply_shake(10, 3)
			
		for particle in particle_nodes:
			particle.emitting = true
			
		await get_tree().create_timer(1).timeout
		play_emerge_animation()
		await get_tree().create_timer(1).timeout
		show_tiles()
	else:
		# 分支 B：非甲虫敌人 (Boss/野怪) 的通用登场
		print("👾 非甲虫实体，播放通用登场...")
		if animation_player:
			if animation_player.has_animation("Entrance"):
				animation_player.play("Entrance")
				await animation_player.animation_finished
			elif animation_player.has_animation("Idle"):
				animation_player.play("Idle")
		# 稍微停顿一下以配合整体战斗节奏
		await get_tree().create_timer(0.5).timeout
		entrance_finished.emit()
	
func play_emerge_animation() -> void:
	# 1. 创建一个 Tween，并设置为【并行模式】(set_parallel)
	# 这会让接下来的所有 tween_property 同时执行，而不是排队执行
	var tween = create_tween().set_parallel(true)
	# 2. 遍历所有子节点，筛选出挂载了我们 Shader 的 Sprite2D
	for socket in body_nodes:
		var part = _get_part_in_socket(socket)
		if part:
			if part.material is ShaderMaterial:
			# 同时让所有部件的 progress 从当前值渐变到 1.1
				tween.tween_property(
					part.material, 
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
		for body_parts in body_nodes:
			var part = _get_part_in_socket(body_parts)
			if part:
				tween.tween_property(body_parts.get_child(0).shadow,"position",Vector2(-5,-1),0.1)
				tween.tween_property(body_parts.get_child(0).shadow,"modulate",Color(0,0,0,0.5),0.1)
	else:
		for body_parts in body_nodes:
			var part = _get_part_in_socket(body_parts)
			if part:
				tween.tween_property(body_parts.get_child(0).shadow,"position",Vector2(5,-1),0.1)
				tween.tween_property(body_parts.get_child(0).shadow,"modulate",Color(0,0,0,0.5),0.1)
		
				
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



#护盾抵挡伤害的效果
func shield_take_hit():
	print("甲虫护盾受到了伤害，播放震动与闪白反馈！")
	# ==============================
	# 1. 物理震动反馈 (保持你现有的不变)
	# ==============================
	if hit_tween and hit_tween.is_valid():
		hit_tween.kill()
		position = base_position 
		
	hit_tween = create_tween()
	var shake_strength: float = 18.0
	var shake_duration: float = 0.1
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
	
	if not body_nodes.is_empty():
		for child in body_nodes:
			var part = _get_part_in_socket(child)
			if not part:
				return
			if part.material is ShaderMaterial:
				# 瞬间将闪白拉满 (1.0)
				part.material.set_shader_parameter("flash_modifier", 1.0)
			
				# 用 Tween 在 0.15 秒内平滑褪回正常颜色 (0.0)
				flash_tween.tween_property(
					part.material, 
					"shader_parameter/flash_modifier", 
					0.0, 
					0.8
				)
	else:

		if material is ShaderMaterial:
			# 瞬间将闪白拉满 (1.0)
			material.set_shader_parameter("flash_modifier", 1.0)
			
				# 用 Tween 在 0.15 秒内平滑褪回正常颜色 (0.0)
			flash_tween.tween_property(
				material, 
				"shader_parameter/flash_modifier", 
				0.0, 
				0.8
			)
			
#受到伤害时触发的动画效果
func take_hit(amount) -> void:
	print("💥 甲虫受到了伤害，播放震动与闪白反馈！")
	
	# ==============================
	# 1. 物理震动反馈 (保持你现有的不变)
	# ==============================
	if hit_tween and hit_tween.is_valid():
		hit_tween.kill()
		position = base_position 
		
	hit_tween = create_tween()
	var shake_strength: float = 18.0
	var shake_duration: float = 0.1
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
	
	if not body_nodes.is_empty():
		for child in body_nodes:
			var part = _get_part_in_socket(child)
			if not part:
				return
			if part.material is ShaderMaterial:
				# 瞬间将闪白拉满 (1.0)
				part.material.set_shader_parameter("flash_modifier", 1.0)
			
				# 用 Tween 在 0.15 秒内平滑褪回正常颜色 (0.0)
				flash_tween.tween_property(
					part.material, 
					"shader_parameter/flash_modifier", 
					0.0, 
					0.8
				)
	else:

		if material is ShaderMaterial:
			# 瞬间将闪白拉满 (1.0)
			material.set_shader_parameter("flash_modifier", 1.0)
			
				# 用 Tween 在 0.15 秒内平滑褪回正常颜色 (0.0)
			flash_tween.tween_property(
				material, 
				"shader_parameter/flash_modifier", 
				0.0, 
				0.8
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
		camera.apply_shake(10, 0.8)
		
	var text_instance = damage_text_scene.instantiate()
# 把数字添加为 VisualController 的子节点，它会跟随战舰的相对坐标移动！
	if not get_parent().is_player:
		text_instance.scale.x *= -1
	get_parent().add_child(text_instance)
# 让飘字产生在偏上方一点的位置（假设战舰中心是 0,0）
	text_instance.position = Vector2(0, -60)

# 调用刚才写的 setup 函数
	if text_instance.has_method("setup"):
		text_instance.setup(amount)
	
func trigger_impact() -> void:
	print("⚡ 动画轨道触发了打击点！")
	action_impact.emit()
	
#新函数，访问挂点下的animatedsprite并播放对应动画
func play_animation_from_body_part(body_part:NodePath,animation:String):
	var part:AnimatedSprite2D = _get_part_in_socket(get_node(body_part))
	if not part or not part is AnimatedSprite2D:
		push_warning("该挂点下没有子节点或子节点不是AnimatedSprite2D")
		return
	if part.sprite_frames.has_animation(animation):
		part.play(animation)
	if part.shadow.sprite_frames.has_animation(animation):
		part.shadow.play(animation)
	
# ==========================================
# 核心安全机制：获取插槽内的有效部件
# ==========================================
func _get_part_in_socket(socket: Node2D) -> beetle_part_base:
	if socket and socket.get_child_count() > 0:
		var part = socket.get_child(0)
		if part is beetle_part_base:
			return part
	return null
	
	
# ==========================================
# 【新增】：在完成甲虫部件组装后调用此函数
# ==========================================
func extract_all_part_mounts() -> void:
	var parent = get_parent()
	if not parent or not "hexgridmanager" in parent or not parent.hexgridmanager:
		push_warning("⚠️ 未找到 HexGridManager，挂点提取失败！")
		return
		
	var grid_manager = parent.hexgridmanager
	
	# 1. 遍历所有插槽，让部件乖乖交出挂点
	for socket in body_nodes:
		var part = _get_part_in_socket(socket)
		if part and part.has_method("transfer_mounts"):
			part.transfer_mounts(grid_manager)
			
	# ==========================================
	# 2. 【完美修复】：不依赖场景树，直接在内存中遍历网格管理器的子节点
	# ==========================================
	for mount in grid_manager.get_children():
		# 只要这个子节点拥有寻找邻居的函数（说明它是挂点），就让它执行
		if mount.has_method("find_neighbor_mounts"):
			mount.find_neighbor_mounts()
			
	print("🧩 所有部件自带挂点已成功整合至 HexGridManager！网络拓扑重构完毕。")
	
# ==========================================
# 【全新升级】：根据 Resource 图纸动态组装战舰
# ==========================================
# ==========================================
# 基于“组件自识别”的动态图纸组装
# ==========================================
func build_from_chassis(chassis_data: BeetleChassisData) -> void:
	if not chassis_data:
		push_error("❌ 图纸为空，无法组装底盘！")
		return
		
	print("🛠️ VisualController: 开始执行动态寻址组装...")
	
	# 1. 清空旧部件
	_clear_all_sockets()
	
	# 2. 遍历图纸中的所有部件场景
	for part_scene in chassis_data.part_scenes:
		if part_scene == null: continue
			
		# 先实例化出来，但不急着加进场景树
		var part_instance = part_scene.instantiate()
		
		# 检查这个部件是不是合法的子类，并且带有目标插槽名字
		if part_instance is beetle_part_base and part_instance.target_socket_name != "":
			var target_name = part_instance.target_socket_name
			var found_socket: Node2D = null
			
			# 在我们的插槽数组中，寻找名字匹配的那个节点
			for socket in body_nodes:
				if socket and socket.name == target_name:
					found_socket = socket
					break
					
			# 如果找到了匹配的插槽，成功对接！
			if found_socket:
				found_socket.add_child(part_instance)
				part_instance.position = Vector2.ZERO
				part_instance.material.set_shader_parameter("theme_color",chassis_data.ship_color["theme_color"])
				part_instance.material.set_shader_parameter("decorative_color",chassis_data.ship_color["decorative_color"])
				# ==========================================
				# 🛡️ 【核心修复】：将材质资源独立化（剥离共享）
				# ==========================================
				if part_instance.material != null:
					# duplicate() 会在内存中复制一份全新的材质专供这个部件使用
					part_instance.material = part_instance.material.duplicate()
				# ==========================================
					
				print("🧩 部件 [%s] 成功寻址并挂载至插槽 -> [%s]" % [part_instance.name, target_name])
			else:
				push_warning("⚠️ 部件 [%s] 想要挂载到 [%s]，但控制器中没有这个名字的插槽！" % [part_instance.name, target_name])
				part_instance.queue_free() # 销毁流浪的部件
		else:
			push_warning("⚠️ 发现无效部件，或者部件没有配置 target_socket_name！")
			part_instance.queue_free()
	#设定战舰名字
	if not get_parent().ship_name:
		get_parent().ship_name = chassis_data.ship_name
	#设定颜色
	
	# 3. 组装完毕，提取所有地块挂点！
	extract_all_part_mounts()

func die_animation():
	pass

# ==========================================
# 内部工具函数升级（支持 PackedScene）
# ==========================================
func _clear_all_sockets() -> void:
	for socket in body_nodes:
		if socket:
			for child in socket.get_children():
				child.queue_free()

func _instance_part_into_socket(part_scene: PackedScene, target_socket: Node2D) -> void:
	if part_scene == null or target_socket == null: 
		return
	
	var part_instance = part_scene.instantiate()
	target_socket.add_child(part_instance)
	
	if part_instance is Node2D:
		part_instance.position = Vector2.ZERO


#用于改变甲虫颜色的函数，参数1用于标记是否为主体颜色，true为改变主体颜色，false为装饰颜色
func set_body_color(is_theme: bool, new_color: Color) -> void:
	for body_part in body_nodes:
		var child = _get_part_in_socket(body_part)
		if child:
			child.set_part_color(is_theme,new_color)


# ==========================================
# 死亡动画：震动 -> 闪白 -> 噪声消散
# ==========================================
# ==========================================
# 死亡动画：震动、闪白与噪声消散（同步进行）
# ==========================================
func play_death_animation(duration: float = 1.5) -> void:
	print("💀 开始播放死亡动画：震动与消散同步进行...")
	# ------------------------------------------
	# 1. 物理层：启动无限循环震动
	# ------------------------------------------
	if hit_tween and hit_tween.is_valid():
		hit_tween.kill()
	position = base_position 
	
	death_tween = create_tween().set_loops()
	var shake_strength: float = 5.0  
	var shake_duration: float = 0.04  
	death_tween.tween_method(_apply_random_shake, shake_strength, shake_strength, shake_duration)

	# ------------------------------------------
	# 2. 视觉层：立即启动闪白与消散
	# ------------------------------------------
	var dissolve_tw = create_tween().set_parallel(true)
	# 闪白持续时间：取 0.3 秒和总时长的 20% 中的较小值，防止总时间太短时闪白没播完
	var flash_duration = min(0.3, duration * 0.2) 
	
	if not body_nodes.is_empty():
		for socket in body_nodes:
			var part = _get_part_in_socket(socket)
			if part and part.material is ShaderMaterial:
				# 瞬间纯白
				part.material.set_shader_parameter("flash_modifier", 1.0)
				# 快速褪去闪白
				dissolve_tw.tween_property(part.material, "shader_parameter/flash_modifier", 0.0, flash_duration)
				# 【核心修改】：使用传入的 duration 作为消散的耗时
				dissolve_tw.tween_property(
					part.material, 
					"shader_parameter/death_progress", 
					1.1, 
					duration 
				).set_trans(Tween.TRANS_SINE)
	else:
		if material is ShaderMaterial:
			material.set_shader_parameter("flash_modifier", 1.0)
			dissolve_tw.tween_property(material, "shader_parameter/flash_modifier", 0.0, flash_duration)
			dissolve_tw.tween_property(material, "shader_parameter/death_progress", 1.1, duration).set_trans(Tween.TRANS_SINE)
			
	# ------------------------------------------
	# 3. 同步点：等待消散动画（耗时 duration）彻底结束
	# ------------------------------------------
	await dissolve_tw.finished
	
	# ------------------------------------------
	# 4. 完美谢幕：掐断震动，销毁节点
	# ------------------------------------------
	if death_tween and death_tween.is_valid():
		death_tween.kill()
	position = base_position
	
	print("💥 死亡演出完毕，彻底消散！")
	get_parent().queue_free()

# 配合无限循环使用的随机震动执行器
func _apply_random_shake(strength: float) -> void:
	var random_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * strength
	position = base_position + random_offset
