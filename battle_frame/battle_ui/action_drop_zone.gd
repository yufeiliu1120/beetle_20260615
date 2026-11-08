class_name ActionDropZone
extends Control

signal action_dropped(action: ActionData, target_index: int, source_index: int)
var timeline_index: int = -1
var _is_hovered: bool = false

# 【新增】：记住初始颜色
var _base_color: Color = Color.WHITE

func _ready() -> void:
	_base_color = modulate # 记录刚出生时的颜色 (对 append_zone 来说就是透明)
	call_deferred("_update_pivot")
	set_process(false)

func _update_pivot() -> void:
	pivot_offset = size / 2.0

func _process(_delta: float) -> void:
	if _is_hovered and not get_global_rect().has_point(get_global_mouse_position()):
		_reset_visuals()

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "action_slot":
		if not _is_hovered:
			_is_hovered = true
			set_process(true) 
			
			var tw = create_tween()
			# 强行将 a 通道设为 1.0，让透明的区域在被悬停时突然发出白光提示玩家！
			var glow_color = Color(1.8, 1.8, 1.8, 1.0)
			tw.tween_property(self, "modulate", glow_color, 0.15)
			tw.parallel().tween_property(self, "scale", Vector2(1.05, 1.05), 0.15)
		return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var dropped_action = data["action"] as ActionData
	var source_idx = data["source_index"] as int
	action_dropped.emit(dropped_action, timeline_index, source_idx)
	_reset_visuals()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_reset_visuals()

func _reset_visuals() -> void:
	if _is_hovered or modulate != _base_color:
		_is_hovered = false
		set_process(false) 
		
		var tw = create_tween()
		# 【修改】：恢复到属于自己的专属初始颜色
		tw.tween_property(self, "modulate", _base_color, 0.2)
		tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
