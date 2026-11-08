extends Control
class_name action_slot
#这个部件要给组装和战斗两个场景使用，需要一个常驻展开状态，以及一个鼠标悬上时展开的状态，分别给战斗和组装场景使用

# --- 模拟按钮逻辑所需的新增变量与信号 ---
signal pool_action_clicked(action: ActionData)
signal queue_action_clicked(index: int)

var is_in_queue: bool = false
var queue_index: int = -1
var is_disabled: bool = false:
	set(value):
		is_disabled = value
		if is_disabled:
			modulate = Color(0.4, 0.4, 0.4, 1.0) # 禁用时变灰
		else:
			modulate = Color(1.0, 1.0, 1.0, 1.0) # 启用时恢复正常
#用来标记模式的变量，不同模式会影响mouse_enter时触发的函数
@export_enum("assumbly","battle") var mode
#部件变量
@export var Icon_rect:TextureRect
@export var Name_Panel:PanelContainer
@export var Text_Panel:PanelContainer
@export var Name_Label:Label
@export var Text_Label:RichTextLabel
@export var tag_container:HBoxContainer
@export var hbox_container: HBoxContainer
@export var Icon_Panel: Control          # 图标容器节点，用于获取折叠后的宽度
@export var anim_duration: float = 0.20  # 每段动画的时长
var is_enemy_slot: bool = false
#标签组件场景
var tag_panel:String = "res://General_UI_parts/action_slot/tag_panel.tscn"
# === 需要在顶部声明补充的导出变量 ===
signal _mouse_entered(slot:action_slot)
signal _mouse_exited(slot:action_slot)

# 内部缓存变量
var _tween: Tween
var _target_hbox_width: float = 600
var _target_tag_height: float = 45
var _collapsed_width: float = 210
var icon_width: float = 64
#当前显示的动作在设置时被赋值
var current_action:ActionData

func set_empty_placeholder() -> void:
	# 清除引用的数据
	current_action = null 
	
	# 清空图标和文本，甚至可以换上一张半透明的“虚线框”图片作为底图
	if Icon_rect:
		Icon_rect.texture = null
		
	if Name_Label:
		Name_Label.text = ""
		
	if Text_Label:
		Name_Label.text = ""
	for tag in tag_container.get_children():
		if tag is tag_panel:
			tag_container.remove_child(tag)
			tag.queue_free()
	
func _ready():
	# 开启裁切：这是折叠动画成功的关键，防止容器缩小时子组件文本或元素溢出
	hbox_container.clip_contents = true
	tag_container.clip_contents = true
	
	# 【新增】：确保当前节点能拦截并响应鼠标事件
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 确保初始颜色正常
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	
# 从一个动作资源获取文本和标签并添加到对应组件上的函数
func set_action_slot(Action: ActionData, current_ap: int = 0, cooldown_turns: int = 0, in_queue: bool = false, q_index: int = -1) -> void:
	# 设置图标
	if not Action.action_icon:
		push_error("未设置动作图标")
	else:
		Icon_rect.texture = Action.action_icon
		
	# 缓存基础动作名称
	var display_name = Action.action_name
	Text_Label.text = Action.set_text()
	
	# 清除旧标签
	var tag_container_children = tag_container.get_children()
	for i in range(1, tag_container_children.size()):
		var child = tag_container_children[i]
		tag_container.remove_child(child) # 1. 立即脱离 UI 容器排版树
		child.queue_free()  # 2. 安全标记为在帧末销毁
		
	# 设置新标签
	for tag in Action.tags:
		var _tag_panel = load(tag_panel).instantiate()
		_tag_panel.label.text = tag
		tag_container.add_child(_tag_panel)
		
	current_action = Action

	# ==========================================
	# 战斗模式下执行的状态与文本校验逻辑
	# ==========================================
	if mode == "battle":
		is_in_queue = in_queue
		queue_index = q_index
		
		if not is_in_queue:
			# 1. 在下方的待选池中：追加 AP 消耗显示
			if cooldown_turns > 0:
				display_name += "(%d)" % cooldown_turns
				self.is_disabled = true # 触发 setter 自动变灰
			elif current_ap < Action.ap_cost:
				self.is_disabled = true # 触发 setter 自动变灰
			else:
				self.is_disabled = false # 触发 setter 恢复正常
		else:
			# 2. 在上方的已选队列中：动作永远可以点击撤销
			self.is_disabled = false # 触发 setter 恢复正常
			
	# 最后再统一赋值给 Label
	Name_Label.text = display_name

# 展开：1. 横向展开 HBoxContainer -> 2. 纵向展开 Tag_Container
func expand(instant: bool = false):
	show_panels()
	if _tween and _tween.is_valid():
		_tween.kill()
	
	# 由于 set_action_slot 可能会动态修改文本和标签，展开前重新刷新目标尺寸
	tag_container.visible = true
	
	if instant:
		hbox_container.custom_maximum_size.x = _target_hbox_width
		tag_container.custom_maximum_size.y = _target_tag_height
		tag_container.modulate.a = 1.0
		show_panels()
		return
	# set_parallel(false) 确保动画按串行步骤依次执行
	_tween = create_tween().set_parallel(false)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 第一阶段：横向展开上方组件
	_tween.tween_property(self,"custom_maximum_size:x",_target_hbox_width, anim_duration)
	_tween.tween_property(hbox_container, "custom_maximum_size:x", _target_hbox_width, anim_duration)
	
	# 第二阶段：纵向展开下方标签，同时配合透明度渐现会让视觉更顺滑
	_tween.tween_property(tag_container, "custom_maximum_size:y", _target_tag_height, anim_duration)
	_tween.parallel().tween_property(tag_container, "modulate:a", 1.0, anim_duration)

# 折叠：1. 纵向收起 Tag_Container -> 2. 横向收起 HBoxContainer 至指定宽度
func collapse(instant: bool = false, to_icon: bool = false):
	if _tween and _tween.is_valid():
		_tween.kill()
		
	# 根据传入的参数决定目标折叠宽度
	var target_width: float = icon_width if to_icon else _collapsed_width
		
	if instant:
		tag_container.custom_minimum_size.y = 0.0
		tag_container.modulate.a = 0.0
		tag_container.visible = false
		hbox_container.custom_maximum_size.x = target_width
		hide_panels(to_icon)
		return
		
	_tween = create_tween().set_parallel(false)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 横向收缩上方组件，宽度减小到目标宽度
	_tween.tween_property(self,"custom_maximum_size:x",target_width, anim_duration)
	_tween.tween_property(hbox_container, "custom_maximum_size:x", target_width, anim_duration)
	
	# 【核心修改】：使用匿名函数 (Lambda) 在动画结束时执行带参数的 hide_panels
	_tween.tween_callback(func(): hide_panels(to_icon))
	
	# 纵向收缩下方标签组件，并在完成时隐藏节点防止占用布局间距
	_tween.tween_property(tag_container, "custom_maximum_size:y", 0.0, anim_duration)
	_tween.parallel().tween_property(tag_container, "modulate:a", 0.0, anim_duration)
	_tween.tween_callback(func(): tag_container.visible = false)


func show_panels():
	Name_Panel.visible = true
	Text_Panel.visible = true

# 【核心修改】：为隐藏函数添加判定逻辑
func hide_panels(to_icon: bool = false):
	# 无论哪种折叠，说明文本一定会隐藏
	Text_Panel.visible = false
	
	# 只有当彻底折叠为图标模式时，才额外隐藏名字面板
	if to_icon:
		Name_Panel.visible = false
	
	
# 辅助函数：根据实际子元素内容动态计算完全展开所需要的尺寸
func _update_target_sizes():
	# 使用 get_combined_minimum_size() 可以准确获取经过 set_action_slot 填充文字后的所需长度
	_target_hbox_width = max(hbox_container.get_combined_minimum_size().x, hbox_container.size.x)
	_target_tag_height = max(tag_container.get_combined_minimum_size().y, tag_container.size.y)
	if Icon_Panel:
		_collapsed_width = Icon_Panel.size.x
		

func _on_mouse_entered() -> void:
	if not mode:
		push_error("该组件未设置模式，无法触发鼠标信号")
		return
	if not is_disabled:
		modulate = Color(1.2, 1.2, 1.2, 1.0) # 提亮 20%
	if mode == "battle":
		_on_battle_mode_mouse_entered()
		#把自己发送出去，方便其他组件捕获
		_mouse_entered.emit(self)
	else:
		_on_assumbly_mode_mouse_entered()
		#把自己发送出去，方便其他组件捕获
		_mouse_entered.emit(self)

func _on_mouse_exited() -> void:
	if not mode:
		push_error("该组件未设置模式，无法触发鼠标信号")
		return
	if not is_disabled:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	if mode == "battle":
		_on_battle_mode_mouse_exited()
		#把自己发送出去，方便其他组件捕获
		_mouse_exited.emit(self)
	else:
		_on_assumbly_mode_mouse_exited()
		#把自己发送出去，方便其他组件捕获
		_mouse_exited.emit(self)

# 【新增】：处理鼠标点击事件
func _gui_input(event: InputEvent) -> void:
	if is_disabled or is_enemy_slot:
		return # 如果被禁用，则不响应点击
		
	# 检测鼠标左键按下
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# 触发与原本 ActionButton 一样的信号逻辑
		if is_in_queue:
			queue_action_clicked.emit(queue_index)
		else:
			pool_action_clicked.emit(current_action)
			
		# 吸收掉这个事件，防止它继续向父节点传递
		accept_event()

func _get_drag_data(at_position: Vector2) -> Variant:
	if is_disabled or current_action == null or is_enemy_slot:
		return null
		
	var drag_data = {
		"type": "action_slot",
		"action": current_action,
		"source_index": queue_index,
		"is_in_queue": is_in_queue
	}
	
	var preview_container = Control.new()
	var ghost_slot = load(scene_file_path).instantiate() as action_slot
	preview_container.add_child(ghost_slot)
	
	ghost_slot.mode = "battle"
	ghost_slot.set_action_slot(current_action, 999, 0, true)
	ghost_slot.collapse(true, true) 
	
	# 让预览图的中心点对准鼠标当前位置
	ghost_slot.position = -Vector2(64 / 2.0, 64 / 2.0)
	set_drag_preview(preview_container)
	
	# 【新增】：隐藏系统鼠标指针
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	return drag_data
	
func _notification(what: int) -> void:
	# 当拖拽操作结束时（无论是成功放下，还是在屏幕外松手取消）
	if what == NOTIFICATION_DRAG_END:
		# 确保恢复系统鼠标指针
		if Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
# ==========================================
# 拖拽降落时的吸附砸落动画
# ==========================================
func play_snap_animation() -> void:
	# 确保基于中心点缩放
	#pivot_offset = size / 2.0
	
	# 起始状态：放大 1.4 倍，完全透明
	scale = Vector2(1.4, 1.4)
	modulate.a = 0.0
	
	var tw = create_tween()
	# 【核心】：TRANS_BACK 会让缩放值越过 1.0 再缩回来，造成物理碰撞般的“果冻感”
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 极速砸下 (0.25秒)
	tw.tween_property(self, "scale", Vector2.ONE, 0.25)
	tw.parallel().tween_property(self, "modulate:a", 1.0, 0.15)
	
func _on_assumbly_mode_mouse_entered():
	pass
	
func _on_battle_mode_mouse_entered():
	pass

	
func _on_assumbly_mode_mouse_exited():
	pass
	
func _on_battle_mode_mouse_exited():
	pass
