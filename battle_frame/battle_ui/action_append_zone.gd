class_name ActionAppendZone
extends Control

# 当玩家在此处放下动作时触发。
# 因为它永远在最后一行追加，所以不需要传递 target_index，只需传递谁被扔了过来，以及原本在哪。
signal append_action_dropped(action: ActionData, source_index: int)

var _is_hovered: bool = false

func _ready() -> void:
	call_deferred("_update_pivot")
	# 默认关闭 process，仅在鼠标悬停时开启，节省性能
	set_process(false)

func _update_pivot() -> void:
	# 保证缩放动画以中心为锚点
	pivot_offset = size / 2.0

# ==========================================
# 实时离开检测 (规避 Godot 拖放系统的盲区)
# ==========================================
func _process(_delta: float) -> void:
	if _is_hovered and not get_global_rect().has_point(get_global_mouse_position()):
		_reset_visuals()

# ==========================================
# 拖拽悬停与接收判定
# ==========================================
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "action_slot":
		if not _is_hovered:
			_is_hovered = true
			set_process(true)
			
			# 磁力悬停效果：提亮 + 微微放大
			var tw = create_tween()
			tw.tween_property(self, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.15)
			tw.parallel().tween_property(self, "scale", Vector2(1.02, 1.02), 0.15)
		return true
	return false

# ==========================================
# 正式掉落接收
# ==========================================
func _drop_data(at_position: Vector2, data: Variant) -> void:
	var dropped_action = data["action"] as ActionData
	var source_idx = data["source_index"] as int
	
	print("🎯 动作被扔进了追加区！")
	append_action_dropped.emit(dropped_action, source_idx)
	
	_reset_visuals()

# ==========================================
# 兜底清理：监听全局拖拽结束
# ==========================================
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_reset_visuals()

func _reset_visuals() -> void:
	if _is_hovered or modulate != Color.WHITE:
		_is_hovered = false
		set_process(false)
		
		# 恢复原状
		var tw = create_tween()
		tw.tween_property(self, "modulate", Color.WHITE, 0.2)
		tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.2)
