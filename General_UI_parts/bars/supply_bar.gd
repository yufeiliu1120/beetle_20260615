extends HBoxContainer
class_name supply_bar
@export var bar:TextureProgressBar
@export var label:Label
var tween: Tween

func set_bar() -> void:
	await get_tree().process_frame
	var target_current_supply: int = PlayerData.current_supply
	var target_max_supply: int = PlayerData.max_supply

	# 1. 上限直接瞬间赋值，确保比例正确
	bar.max_value = target_max_supply
	
	# 2. 文本瞬间更新为最终结果
	label.text = tr("Supply: {current}/{max}").format({"current": target_current_supply, "max": target_max_supply})
	
	# ==========================================
	# 3. 核心动画逻辑：平滑过渡进度条
	# ==========================================
	if tween and tween.is_valid():
		tween.kill()
		
	tween = create_tween()
	
	# 【核心判断】：如果目标值小于进度条当前停留的数值，说明正在扣除补给
	var is_decreasing = target_current_supply < bar.value
	
	tween.tween_property(bar, "value", float(target_current_supply), 1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	# 只有在减少时，才将闪烁指令追加到当前的 Tween 序列中
	if is_decreasing:
		spark()
		
func spark():
	var tween = create_tween()
	tween.parallel().tween_property(bar, "modulate", Color(5, 5, 5, 1), 0.2)
	tween.chain().tween_property(bar, "modulate", Color(1, 1, 1, 1), 0.5)
