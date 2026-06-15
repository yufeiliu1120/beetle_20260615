class_name ActionUIManager
extends Control

# --- 预加载组件 ---
@export var action_button_scene: PackedScene 

# --- UI 节点引用 ---
@onready var ap_label: Label = $APLabel
@onready var timeline_container: HBoxContainer = $TimelineContainer 
@onready var pool_container: Container = $PoolContainer             
@onready var submit_button: Button = $SubmitButton                  

# --- 数据引用 ---
var player_entity: CombatEntity
var enemy_entity: CombatEntity

# 防抖标记，防止同一帧内暴发信号导致 UI 崩溃
var _is_dirty: bool = false

# --- 信号 ---
signal turn_submitted(final_queue: Array[ActionData])

func _ready() -> void:
	submit_button.pressed.connect(_on_submit_pressed)
	hide() # 初始状态隐藏，等战斗管理器呼叫后再出现

# ==========================================
# 核心接口：绑定双方实体并显示 UI
# ==========================================
func bind_entities(p_entity: CombatEntity, e_entity: CombatEntity) -> void:
	player_entity = p_entity
	enemy_entity = e_entity
	
	# 连接到防抖刷新机制
	if player_entity and not player_entity.stats_changed.is_connected(queue_refresh):
		player_entity.stats_changed.connect(queue_refresh)
	if enemy_entity and not enemy_entity.stats_changed.is_connected(queue_refresh):
		enemy_entity.stats_changed.connect(queue_refresh)
		
	show() # 数据绑定完毕，正式登场
	queue_refresh()

# ==========================================
# 防抖与刷新逻辑
# ==========================================
func queue_refresh() -> void:
	if _is_dirty: return
	_is_dirty = true
	call_deferred("refresh_timeline_ui")

func refresh_timeline_ui() -> void:
	_is_dirty = false 
	
	if not is_node_ready() or player_entity == null or enemy_entity == null: 
		return

	if ap_label:
		ap_label.text = "AP: %d / %d" % [player_entity.current_ap, player_entity.max_ap]

	# 【安全清理】：必须先 remove_child 再 queue_free，防止排版引擎崩溃
	for child in timeline_container.get_children():
		timeline_container.remove_child(child) 
		child.queue_free()
	for child in pool_container.get_children():
		pool_container.remove_child(child) 
		child.queue_free()

	var p_queue = player_entity.current_action_queue
	var e_queue = enemy_entity.current_action_queue
	var max_len = max(p_queue.size(), e_queue.size())
	
	# 1. 渲染上方时间轴
	for i in range(max_len):
		var column = VBoxContainer.new()
		
		# 敌人动作（上方，只读）
		if i < e_queue.size():
			var e_btn = action_button_scene.instantiate() as ActionButton
			column.add_child(e_btn)
			e_btn.setup(e_queue[i], 999, 0, true) 
		else:
			column.add_child(_create_spacer())
			
		# 玩家动作（下方，可撤销）
		if i < p_queue.size():
			var p_btn = action_button_scene.instantiate() as ActionButton
			column.add_child(p_btn)
			# 传入 index 方便撤销
			p_btn.setup(p_queue[i], 999, 0, true, i) 
			p_btn.queue_action_clicked.connect(_on_timeline_action_cancelled)
		else:
			column.add_child(_create_spacer())
			
		timeline_container.add_child(column)
		
	# 2. 渲染下方待选池
	for action in player_entity.action_pool:
		var btn = action_button_scene.instantiate() as ActionButton
		pool_container.add_child(btn)
		
		var cd = player_entity.cooldown_tracker.get(action, 0)
		btn.setup(action, player_entity.current_ap, cd, false)
		
		if player_entity.current_action_queue.has(action):
			btn.disabled = true
			btn.text += " (已选)"
			
		btn.pool_action_clicked.connect(_on_pool_action_selected)

func _create_spacer() -> Control:
	# 1. 直接实例化一个真实的按钮来占位
	var ghost_btn = action_button_scene.instantiate() as Button
	
	# 2. 让它变成“幽灵”
	ghost_btn.modulate.a = 0.0 # 设置 Alpha 透明度为 0（完全隐身）
	ghost_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE # 忽略所有鼠标悬浮和点击
	ghost_btn.disabled = true # 禁用状态
	
	# 3. 随便塞点默认文字撑起高度（虽然看不见）
	ghost_btn.text = "幽灵占位" 
	
	return ghost_btn


# ==========================================
# 交互信号接收
# ==========================================
func _on_pool_action_selected(action: ActionData) -> void:
	player_entity.use_action(action)

func _on_timeline_action_cancelled(index: int) -> void:
	player_entity.cancel_action(index)

func _on_submit_pressed() -> void:
	turn_submitted.emit(player_entity.current_action_queue)
