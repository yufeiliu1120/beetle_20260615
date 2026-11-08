extends Marker2D

@onready var label: Label = $Text

@export var base_damage: float = 3.0
@export var scale_per_step: float = 0.15
@export var max_scale_limit: float = 2.5

func setup(amount: int) -> void:
	label.text = str(amount)
	
	# 1. 计算倍率
	var bonus_steps: float = max(0.0, float(amount) - base_damage) / base_damage
	var size_multiplier: float = min(1.0 + (bonus_steps * scale_per_step), max_scale_limit)
	
	# ==========================================
	# 检测父级翻转，利用“负负得正”抵消镜像！
	# ==========================================
	# global_transform.x.x 代表当前节点 X 轴在全局屏幕上的朝向。
	# 如果小于 0，说明祖先节点有 scale.x = -1 的情况（被翻转了），此时 flip_x 设为 -1.0
	var flip_x: float = -1.0 if get_parent().scale.x < 0 else 1.0
	
	# 将 flip_x 融入 target_scale 的 X 轴中
	# 当在敌舰身上时，这里会变成 Vector2(-size_multiplier, size_multiplier)
	# 负号乘以敌舰的 -1 缩放，屏幕上看到的正好是正向的文字！
	var target_scale = Vector2(size_multiplier * flip_x, size_multiplier)
	
		
	scale = target_scale * 0.4
		
	# ==========================================
	# 抛物线飞出屏幕动画 (根据受击者朝向向后飞)
	# ==========================================
	var duration: float = 1.5 
	var start_pos: Vector2 = position
	
	# 【核心修改】：去掉了 * flip_x
	# 永远向局部坐标的正前方 (+X) 运动，配合父节点的镜像，自动实现：
	# 玩家受伤数字往右飞，敌舰受伤数字往左飞
	var move_x: float = randf_range(150.0, 250.0) 
	
	var jump_height: float = randf_range(50.0, 80.0)
	var drop_y: float = start_pos.y + 800.0

	# 1. X轴：使用线性 (TRANS_LINEAR)，模拟物理中不受阻力影响的水平匀速动量
	var tween_x = create_tween()
	tween_x.tween_property(self, "position:x", start_pos.x + move_x, duration)\
		.set_trans(Tween.TRANS_LINEAR)

	# 2. Y轴：完美的重力抛物线 (先减速上升，再加速下坠)
	var tween_y = create_tween()
	# 上升阶段
	tween_y.tween_property(self, "position:y", start_pos.y - jump_height, duration * 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 下坠阶段
	tween_y.tween_property(self, "position:y", drop_y, duration * 0.85)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 3. 视觉补充：缩放与淡出
	# 注意：这里的 target_scale 依然保留了 flip_x，
	# 这样只是为了防止文字本身变成镜像反字，不影响飞行轨迹！
	var tween_vis = create_tween()
	tween_vis.tween_property(self, "scale", target_scale, duration * 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	# 在掉出屏幕的后半段逐渐变为透明，并在最后彻底释放节点内存
	tween_vis.tween_interval(duration * 0.5)
	tween_vis.tween_property(label, "modulate:a", 0.0, duration * 0.5)
	tween_vis.tween_callback(queue_free)
