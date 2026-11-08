extends Marker2D

@onready var label: Label = $Label

# ==========================================
# 文本与颜色配置
# ==========================================
var SHIELD_TEXT_FORMAT: String = "获得护盾 +%d"
var COLOR_DEBUFF = Color.html("#ff6b6b") # 浅红
var COLOR_BUFF = Color.html("#51cf66")   # 浅绿
var COLOR_SHIELD = Color.html("#339af0") # 浅蓝

# ==========================================
# 外部调用接口 1：赋予 Buff
# ==========================================
func setup(string: String, is_debuff: bool) -> void:
	label.text = string
	
	# 【核心修改】：移除 modulate，通过 theme_override 仅修改文字边框颜色
	label.add_theme_color_override("font_outline_color", COLOR_DEBUFF if is_debuff else COLOR_BUFF)
	# 保险设置：确保描边有足够的厚度，如果你已经在编辑器里设置了描边粗细，这行可以删掉
	label.add_theme_constant_override("outline_size", 4)
	
	_start_floating()

# ==========================================
# 外部调用接口 2：添加护盾
# ==========================================
func setup_for_shield(count: int) -> void:
	label.text = tr(SHIELD_TEXT_FORMAT) % count
	
	# 【核心修改】：修改护盾文字的边框颜色
	label.add_theme_color_override("font_outline_color", COLOR_SHIELD)
	label.add_theme_constant_override("outline_size", 4)
	
	_start_floating()

# ==========================================
# 核心公共逻辑：自适应居中与飘字动画
# ==========================================
func _start_floating() -> void:
	# 尺寸自适应与绝对居中
	label.reset_size()
	label.position = -label.size / 2.0
	
	# 镜像翻转抵消
	var flip_x: float = -1.0 if get_parent().scale.x < 0 else 1.0
	var target_scale = Vector2(1.0 * flip_x, 1.0)
	scale = target_scale * 0.4
	
	# 动画配置
	var duration: float = 0.8
	var start_pos: Vector2 = position
	var move_up: float = 120.0 

	var tween_pos = create_tween()
	tween_pos.tween_property(self, "position:y", start_pos.y - move_up, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var tween_vis = create_tween()
	tween_vis.tween_property(self, "scale", target_scale, duration * 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	await get_tree().create_timer(0.5).timeout
	
	var tween_fade = create_tween()
	tween_fade.tween_interval(duration * 0.4) 
	tween_fade.tween_property(self, "modulate:a", 0.0, duration * 0.4)
	
	tween_fade.tween_callback(queue_free)
