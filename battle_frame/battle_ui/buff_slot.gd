extends Control

@export var desc_panel:PanelContainer
@export var desc_label: Label
@export var remaining: Label
@export var icon: TextureRect

var current_buff: BuffData

func init_buff_slot(buff: BuffData) -> void:
	current_buff = buff
	desc_panel.hide()
	# 1. 静态数据初始化
	icon.texture = buff.buff_icon
	desc_label.text = buff.set_text()
	# 2. 初始的持续时间显示
	_update_duration_display(buff.duration)
	# 3. 动态数据绑定：连接信号（加上防重连判定，防止多次初始化引发错误）
	if not current_buff.duration_changed.is_connected(_update_duration_display):
		current_buff.duration_changed.connect(_update_duration_display)

# ==========================================
# 信号回调函数
# ==========================================
func _update_duration_display(new_duration: int) -> void:
	# 【新增核心逻辑】：当持续时间归零，立刻自我销毁
	if new_duration == 0:
		queue_free()
		return
		
	if new_duration == -1:
		# 如果是永久 buff，显示无限符号
		remaining.text = "∞" 
	else:
		remaining.text = str(new_duration)


func _on_icon_mouse_entered() -> void:
	desc_panel.show()


func _on_icon_mouse_exited() -> void:
	desc_panel.hide()
