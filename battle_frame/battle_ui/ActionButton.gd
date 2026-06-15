class_name ActionButton
extends Button

# 绑定的动作数据
var action_data: ActionData
var is_in_queue: bool = false # 标记这个按钮是在“待选池”里，还是在“已选队列”里
var queue_index: int = -1     # 如果在已选队列里，它排第几？

# 自定义信号，向上传递给动作管理器
signal pool_action_clicked(action: ActionData)
signal queue_action_clicked(index: int)

func _ready() -> void:
	# 自动绑定自身的点击事件
	pressed.connect(_on_button_pressed)

# 初始化方法
func setup(data: ActionData, current_ap: int, cooldown_turns: int, in_queue: bool, q_index: int = -1) -> void:
	action_data = data
	is_in_queue = in_queue
	queue_index = q_index
	
	# --- 表现层更新 ---
	var btn_text = data.action_name
	
	if not is_in_queue:
		# 在下方的待选池中
		btn_text += " (AP: %d)" % data.ap_cost
		if cooldown_turns > 0:
			btn_text += " [冷却中: %d]" % cooldown_turns
			disabled = true 
		elif current_ap < data.ap_cost:
			disabled = true 
		else:
			disabled = false 
	else:
		# 在上方的已选队列中
		btn_text = btn_text
		disabled = false # 队列中的动作永远可以点击撤销
		
	text = btn_text

# 处理自身被点击
func _on_button_pressed() -> void:
	if is_in_queue:
		queue_action_clicked.emit(queue_index)
	else:
		pool_action_clicked.emit(action_data)
