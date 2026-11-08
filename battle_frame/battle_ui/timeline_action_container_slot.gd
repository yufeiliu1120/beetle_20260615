extends HBoxContainer
class_name timeline_slot
const HIT_EFFECT_SCENE = preload("res://battle_frame/battle_ui/particle_effect.tscn")
var action_slot_conntainer = preload("res://battle_frame/battle_ui/action_slot_container.tscn")
@export var enemy_drop_zone: ActionDropZone
@export var player_drop_zone: ActionDropZone

@export var enemy_base: MarginContainer
@export var player_base: MarginContainer
# ==========================================
# 状态标记 (替代原本的 set_meta)
# ==========================================
var was_paired: bool = false
var p_was_present: bool = false

# 当 VBoxContainer 询问这个组件需要多大空间时，拦截并返回我们覆盖的值
	
	
func collapse_to_icon():
	# 第一部分：广度优先搜索，触发展开 (保持不变)
	var nodes_to_check: Array[Node] = [self]
	while nodes_to_check.size() > 0:
		var current_node = nodes_to_check.pop_front()
		if current_node is action_slot:
			current_node.collapse(false, true)
		nodes_to_check.append_array(current_node.get_children())
		
	# 第二部分：【核心修复】智能容器间距 (Separation)
	# 抛弃 get_child(0) 和 get_child_count，用是否抓取到了真实动作来判定
	var e_btn = _get_action_slot_from_base(enemy_base)
	var p_btn = _get_action_slot_from_base(player_base)
	
	var is_paired = (e_btn != null and p_btn != null)
	
	var current_separation = get_theme_constant("separation")
	var target_separation = 0 if is_paired else 0
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(value: int): add_theme_constant_override("separation", value),
		current_separation, 
		target_separation, 
		0.20 
	)

#获取该两个其中的动作并生成一个二元数组
# 获取该两个其中的动作并生成一个三元数组：[敌方ActionData, 玩家ActionData, self]
func get_actions() -> Array:
	var actions: Array = []
	
	# 【核心修改】：精准提取左右两边的动作图标
	var e_btn = _get_action_slot_from_base(enemy_base)
	var p_btn = _get_action_slot_from_base(player_base)
	
	actions.append(e_btn.current_action if e_btn else null)
	actions.append(p_btn.current_action if p_btn else null)
	
	# 将自身 (self) 作为第三个元素加入数组
	actions.append(self)
		
	return actions

# ==========================================
# 动作执行动画：单侧独立突刺与碰撞（纯视觉位移防排版抖动）
# 无参数版本：直接通过检测自身的子节点状态来决定演出逻辑
# ==========================================
func play_excute_animation() -> void:
	var e_btn = _get_action_slot_from_base(enemy_base)
	var p_btn = _get_action_slot_from_base(player_base)
	
	# 1. 垃圾清理：只在有真实动作的那一侧删除 DropZone
	if e_btn and enemy_base:
		for child in enemy_base.get_children():
			if child is ActionDropZone:
				child.queue_free()
				
	if p_btn and player_base:
		for child in player_base.get_children():
			if child is ActionDropZone:
				child.queue_free()
				
	# 2. 【核心修改】：智能选择动画目标
	# 优先使用真实的动作图标，如果没有，就让没被删掉的 DropZone 来替补演出
	var e_target: Control = e_btn if e_btn else _get_drop_zone_from_base(enemy_base)
	var p_target: Control = p_btn if p_btn else _get_drop_zone_from_base(player_base)
	
	# ==========================================
	# 敌方动作演出 (位于左侧，向右攻击)
	# ==========================================
	if e_target:
		# 材质克隆与初始化
		if e_target.material:
			e_target.material = e_target.material.duplicate()
			e_target.material.set("shader_parameter/flash_amount", 0.0)
			e_target.material.set("shader_parameter/dissolve_amount", 0.0)
			
		var e_seq = create_tween()
		
		# 蓄力：向左稍微后撤
		e_seq.tween_property(e_target, "position:x", -20.0, 0.5)\
			.as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			
		# 猛击：向右极速冲刺 
		e_seq.tween_property(e_target, "position:x", 35.0, 0.3)\
			.as_relative().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			
		# 撞击瞬间：Shader 瞬间闪白
		if e_target.material:
			e_seq.chain().tween_property(e_target.material, "shader_parameter/flash_amount", 1.0, 0.05)
		
		# 弹开与消散：物理后退的同时，Shader 控制噪点消散
		e_seq.chain().tween_property(e_target, "position:x", -20.0, 0.45)\
			.as_relative().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if e_target.material:
			e_seq.parallel().tween_property(e_target.material, "shader_parameter/dissolve_amount", 1.0, 0.45)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			
	# ==========================================
	# 玩家动作演出 (位于右侧，向左攻击)
	# ==========================================
	if p_target:
		# 材质克隆与初始化
		if p_target.material:
			p_target.material = p_target.material.duplicate()
			p_target.material.set("shader_parameter/flash_amount", 0.0)
			p_target.material.set("shader_parameter/dissolve_amount", 0.0)
			
		var p_seq = create_tween()
		
		# 蓄力：向右稍微后撤
		p_seq.tween_property(p_target, "position:x", 20.0, 0.5)\
			.as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			
		# 猛击：向左极速冲刺
		p_seq.tween_property(p_target, "position:x", -35.0, 0.3)\
			.as_relative().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			
		# 撞击瞬间：Shader 瞬间闪白
		if p_target.material:
			p_seq.chain().tween_property(p_target.material, "shader_parameter/flash_amount", 1.0, 0.05)
		
		# 弹开与消散：物理后退的同时，Shader 控制噪点消散
		p_seq.chain().tween_property(p_target, "position:x", 20.0, 0.45)\
			.as_relative().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if p_target.material:
			p_seq.parallel().tween_property(p_target.material, "shader_parameter/dissolve_amount", 1.0, 0.45)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				
	# ==========================================
	# 3. 整体清理与平滑上移排版
	# ==========================================
	var timer_tween = create_tween()
	timer_tween.tween_interval(1.3)
	
	timer_tween.tween_callback(func():
		self.clip_contents = true
		self.custom_minimum_size.y = self.size.y
		for child in get_children():
			child.visible = false
	)
	
	timer_tween.tween_property(self, "custom_minimum_size:y", 0.0, 2.0)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	timer_tween.tween_callback(self.hide)
	
func _get_action_slot_from_base(base: MarginContainer) -> action_slot:
	if base == null: 
		return null
	for child in base.get_children():
		if child is action_slot:
			return child
	return null
	
func _get_drop_zone_from_base(base: MarginContainer) -> ActionDropZone:
	if base == null: 
		return null
	for child in base.get_children():
		if child is ActionDropZone:
			return child
	return null
