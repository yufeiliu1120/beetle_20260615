extends VBoxContainer
class_name buff_container
@export var max_slots_per_row: int = 16
var slot_path:String = "res://battle_frame/battle_ui/buff_slot.tscn"
# 【防抖锁】：极其重要！防止代码自动移动节点时再次触发信号引发死循环
var _is_reflowing: bool = false

func _ready() -> void:
	# 遍历自身的行（HBoxContainer），监听它们的子节点变化
	for row in get_children():
		if row is HBoxContainer:
			row.child_order_changed.connect(_on_row_changed)


func add_slot_with_buff(buff:BuffData):
	var slot = load(slot_path).instantiate()
	add_slot_bottom_up(slot)
	slot.init_buff_slot(buff)

func init_buff_container(entity:CombatEntity):
	for buff in entity.active_buffs:
		var slot = load(slot_path).instantiate()
		add_slot_bottom_up(slot)
		slot.init_buff_slot(buff)

	
# ==========================================
# 信号响应与防抖
# ==========================================
func _on_row_changed() -> void:
	# 如果当前正在执行重排，直接拦截，无视新发出的信号
	if _is_reflowing:
		return
		
	_is_reflowing = true
	# 必须使用 call_deferred！
	# 等待 queue_free() 把节点真正清理掉，或者等这一帧排版引擎稳定后，再执行重排
	call_deferred("reflow_slots")

# ==========================================
# 核心重排逻辑 (瀑布流重排)
# ==========================================
func reflow_slots() -> void:
	var rows = get_children()
	
	# 从最底下的行开始，倒序往上遍历
	for i in range(rows.size() - 1, 0, -1):
		var current_row = rows[i] as HBoxContainer
		var row_above = rows[i - 1] as HBoxContainer
		
		if not current_row or not row_above:
			continue
			
		# 当下排没满，且上排有节点时，持续从上排“偷”最左侧的节点
		while current_row.get_child_count() < max_slots_per_row and row_above.get_child_count() > 0:
			var slot_to_move = row_above.get_child(0)
			
			# reparent 会将节点抽出，并自动加到 current_row 的末尾
			# 注意：这一步会触发两行的 child_order_changed，但被我们上面的 _is_reflowing 锁完美挡住了
			slot_to_move.reparent(current_row)
			
	# 本次大扫除彻底结束，解开防抖锁，迎接下一次玩家操作
	_is_reflowing = false

# ==========================================
# 外部添加接口
# ==========================================
func add_slot_bottom_up(new_slot: Control) -> bool:
	var rows = get_children()
	
	for i in range(rows.size() - 1, -1, -1):
		var target_row = rows[i] as HBoxContainer
		
		if not target_row:
			continue
			
		if target_row.get_child_count() < max_slots_per_row:
			# 这里 add_child 后，引擎会自动触发 _on_row_changed 并执行自动重排，不需要手动干预
			target_row.add_child(new_slot)
			return true 
	push_warning("槽位已满！无法添加更多Buff。")
	return false
