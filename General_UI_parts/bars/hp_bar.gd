extends HBoxContainer
class_name hp_bar

@export var bar: TextureProgressBar
@export var label: RichTextLabel
@export var shield:TextureRect
@export var shield_count_label:Label
# 【新增】：用于追踪当前的血条动画，防止多次触发导致来回抽搐
var _hp_tween: Tween

func set_shield(entity: CombatEntity = null):
	shield.modulate.a = 0
	if entity:
		if not entity.active_shields.is_empty():
			shield.modulate.a = 1
			shield_count_label.text = str(entity.active_shields.size())
	
	
func set_hp_bar(entity: CombatEntity = null) -> void:
	var target_current_hp: int = 0
	var target_max_hp: int = 0
	
	shield.modulate.a = 0
	if entity:
		if entity.active_shields.is_empty():
			shield.modulate.a = 0
		else:
			shield.modulate.a = 1
			shield_count_label.text = str(entity.active_shields.size())
	
	if entity != null:
		target_current_hp = entity.current_hp
		target_max_hp = entity.max_hp
	else:
		target_current_hp = PlayerData.current_hp
		target_max_hp = PlayerData.max_hp

	# 1. 上限直接瞬间赋值，确保比例正确
	bar.max_value = target_max_hp
	
	# 2. 文本瞬间更新为最终结果
	label.text = tr("HP: {hp}/{max}").format({"hp": target_current_hp, "max": target_max_hp})
	
	# ==========================================
	# 3. 核心动画逻辑：平滑过渡进度条
	# ==========================================
	# 如果当前有正在播放的动画，立刻停止它
	if _hp_tween and _hp_tween.is_valid():
		_hp_tween.kill()
		
	# 创建新的动画队列
	var tween = create_tween()
	

	var is_decreasing = target_current_hp < bar.value
	
	tween.tween_property(bar, "value", float(target_current_hp), 1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	# 只有在减少时，才将闪烁指令追加到当前的 Tween 序列中
	if is_decreasing:
		spark()
		
func spark():
	var tween = create_tween()
	tween.parallel().tween_property(bar, "modulate", Color(5, 5, 5, 1), 0.2)
	tween.chain().tween_property(bar, "modulate", Color(1, 1, 1, 1), 0.5)
