class_name ActionUIManager
extends Control

@export var timeline_row_scene: PackedScene 
@export var combat_manager: CombatManager
# --- 预加载组件 ---
@export var action_button_scene: PackedScene 
@export var game_over_pack:PackedScene

# 【新增】：用来拖入你新做好的 ActionAppendZone 场景
@export var append_zone_scene: PackedScene 

# --- UI 节点引用 ---
@export var player_status_bar: status_bar
@export var enemy_status_bar: status_bar
@export var pool_container: Container           
@export var submit_button: Button                
@export var pool_container_panel: PanelContainer
@export var timeline_container_panel: PanelContainer
@export var compact_width: float = 205.0 
@export var width_anim_duration: float = 0.3 
@export var ui_blocker: Control
# --- 数据引用 ---
var player_entity: CombatEntity
var enemy_entity: CombatEntity
var _last_dropped_index: int = -1
#const DEFAULT_SEPARATION: int = 4
var _is_dirty: bool = false
var is_resolving_turn: bool = false

signal turn_submitted

func _tween_column_separation(column: Control, target_val: int) -> void:
	var tw = create_tween()
	tw.tween_property(column, "theme_override_constants/separation", target_val, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
func _ready() -> void:
	submit_button.pressed.connect(_on_submit_pressed)
	hide() 
	pool_container_panel.modulate.a = 0.0

# ==========================================
# 核心接口：绑定双方实体并显示 UI
# ==========================================
func bind_entities(p_entity: CombatEntity, e_entity: CombatEntity) -> void:
	player_entity = p_entity
	enemy_entity = e_entity
	
	if player_entity and not player_entity.stats_changed.is_connected(queue_refresh):
		player_entity.stats_changed.connect(queue_refresh)
	if enemy_entity and not enemy_entity.stats_changed.is_connected(queue_refresh):
		enemy_entity.stats_changed.connect(queue_refresh)
	player_status_bar.init_status_bar(player_entity)
	enemy_status_bar.init_status_bar(enemy_entity)
	combat_manager.action_resolver.action_pair_executing.connect(_on_action_pair_executing)
	show() 
	queue_refresh()

# ==========================================
# 防抖与局部状态刷新 (仅限动作池和血条)
# ==========================================
func queue_refresh() -> void:
	if _is_dirty: return
	_is_dirty = true
	call_deferred("_refresh_pool_and_status")

func _refresh_pool_and_status() -> void:
	_is_dirty = false 
	if not is_node_ready() or player_entity == null or enemy_entity == null: 
		return

	# 现在的全局刷新只负责更新底部的牌库状态（比如 AP 不够时变灰）
	var turn_pairs = combat_manager.action_resolver.turn_action_pairs
	_refresh_action_pool(turn_pairs)
	

# ===========================================
# 阶段触发：回合初初始化时间轴
# ===========================================
func _on_enemy_thinking():
	_init_turn_timeline()
	
func _init_turn_timeline() -> void:
	# 【防误触 1】：在初始化动画开始前，开启遮罩防止玩家立刻点击交互
	if ui_blocker:
		ui_blocker.show()
	var timeline = timeline_container_panel.timeline
	var turn_pairs = combat_manager.action_resolver.turn_action_pairs
	
	# 1. 暴力清理上一回合的所有残留（包括 AppendZone）
	for child in timeline.get_children():
		timeline.remove_child(child)
		child.queue_free()
		
	# 2. 瞬间铺设敌人动作行 (注意：传入 false，不需要单行的撑开动画，因为外面有整体卷帘)
	for i in range(turn_pairs.size()):
		var column = _create_timeline_row(timeline, false)
		_update_timeline_row(column, i, turn_pairs[i][0], turn_pairs[i][1], true, true)
		
	# 3. 在末尾挂载追加区
	_ensure_append_zone()
	
	# 如果时间轴有动作，播放卷帘动画并等待其完成
	if timeline.get_child_count() > 0:
		# 传入 0.15 作为单个 slot 展开时长
		timeline_container_panel.play_vbox_roll_down_anim(0.5)
		
		# 【核心修复】：提取 timeline_panel 缓存的 roll_tween，死等动画链彻底播放完毕
		if timeline.has_meta("roll_tween"):
			var roll_tween = timeline.get_meta("roll_tween") as Tween
			if roll_tween and roll_tween.is_valid():
				await roll_tween.finished
				
		# 动画播完后再等一帧缓冲，保证节点布局完全稳定
		await get_tree().process_frame
	# 【防误触 2】：动画安全播放完毕，关闭遮罩，将控制权还给玩家
	if ui_blocker:
		ui_blocker.hide()
		
	
# ==========================================
# 玩家交互：时间轴局部动态增删 
# ==========================================
func _update_timeline_interactively() -> void:
	var turn_pairs = combat_manager.action_resolver.turn_action_pairs
	var timeline = timeline_container_panel.timeline
	var max_len = turn_pairs.size()
	
	var current_rows = _get_actual_timeline_rows()
	
	# 【核心修复 1】：记录本次交互前，时间轴原本有多少行
	var old_row_count = current_rows.size()
			
	if current_rows.size() < max_len:
		for i in range(current_rows.size(), max_len):
			var new_row = _create_timeline_row(timeline, true)
			current_rows.append(new_row)
			
	_ensure_append_zone()
	
	for i in range(max_len):
		# 判断当前遍历的这一行，是不是刚刚追加出来的新行
		var is_new = (i >= old_row_count) 
		
		# 将动态计算的 is_new 传进去
		_update_timeline_row(current_rows[i], i, turn_pairs[i][0], turn_pairs[i][1], is_new, false)
		
	if current_rows.size() > max_len:
		for i in range(max_len, current_rows.size()):
			var excess_row = current_rows[i]
			_remove_timeline_row_with_anim(excess_row)

func _ensure_append_zone() -> void:
	var timeline = timeline_container_panel.timeline
	var append_zone = timeline.get_node_or_null("ActionAppendZone")
	if not append_zone:
		if append_zone_scene:
			append_zone = append_zone_scene.instantiate()
			append_zone.name = "ActionAppendZone"
			timeline.add_child(append_zone)
			append_zone.append_action_dropped.connect(_on_append_action_dropped)
	timeline.move_child(append_zone, -1)

# ==========================================
# 移除行：反向装填掩体，实现平滑收缩
# ==========================================
func _remove_timeline_row_with_anim(row: timeline_slot) -> void:
	var parent = row.get_parent()
	var idx = row.get_index()
	var TARGET_HEIGHT = 80.0
	
	# 如果它本来就在掩体里（比如还没展开完就被取消了），直接收缩掩体
	var wrapper = parent if parent.name == "AnimWrapper" else Control.new()
	
	if wrapper != parent:
		wrapper.name = "AnimWrapper"
		wrapper.clip_contents = true
		wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrapper.custom_minimum_size.y = TARGET_HEIGHT
		
		parent.remove_child(row)
		parent.add_child(wrapper)
		parent.move_child(wrapper, idx)
		
		wrapper.add_child(row)
		row.set_anchor(SIDE_LEFT, 0.0)
		row.set_anchor(SIDE_RIGHT, 1.0)
		row.offset_left = 0
		row.offset_right = 0
		
	var tw = create_tween().set_parallel(true)
	tw.tween_property(wrapper, "custom_minimum_size:y", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(row, "modulate:a", 0.0, 0.2)
	
	tw.chain().tween_callback(wrapper.queue_free)

# ==========================================
# 更新单行的数据与视觉状态
# ==========================================
func _update_timeline_row(column: timeline_slot, index: int, e_action: ActionData, p_action: ActionData, is_new_row: bool, is_turn_start: bool) -> void:
	var e_base = column.enemy_base
	var p_base = column.player_base
	
	var p_drop_zone = p_base.get_node_or_null("ActionDropZone") 
	if p_drop_zone is ActionDropZone:
		p_drop_zone.timeline_index = index
		if not p_drop_zone.action_dropped.is_connected(_on_action_dropped_on_timeline):
			p_drop_zone.action_dropped.connect(_on_action_dropped_on_timeline)
	
	var e_has_action = (e_action != null)
	var p_has_action = (p_action != null)
	
	var e_btn = _update_slot_button(e_base, e_action, index, false)
	var p_btn = _update_slot_button(p_base, p_action, index, true)

	var is_paired_now = (e_has_action and p_has_action)
	var was_paired = column.was_paired
	
	# ==========================================
	# 定制三种情况的排版间距
	# ==========================================
	var target_sep: int = 0
	if is_paired_now:
		target_sep = 0   # 双方都有动作，卡牌贴合
	elif not e_has_action and p_has_action:
		target_sep = 148 # 只有玩家有动作（末尾追加的行），向左偏移对齐
	elif e_has_action and not p_has_action:
		target_sep = 4   # 只有敌人有动作（回合初刚生成），保持默认间距
	else:
		target_sep = 4   # 兜底情况
	if is_new_row or is_turn_start:
		column.add_theme_constant_override("separation", target_sep)
		if is_paired_now:
			if e_btn: e_btn.collapse(true)
			if p_btn: p_btn.collapse(true)
		else:
			if e_btn: e_btn.expand(true)
			if p_btn: p_btn.collapse(true) 
	else:
		if is_paired_now and not was_paired:
			_tween_column_separation(column, target_sep)
			if e_btn: e_btn.collapse(false)
			if p_btn: p_btn.collapse(false)
		elif not is_paired_now and was_paired:
			_tween_column_separation(column, target_sep)
			if e_btn: e_btn.expand(false)
			if p_btn: p_btn.collapse(false)
			
	column.was_paired = is_paired_now
	column.p_was_present = p_has_action
	
	if index == _last_dropped_index and p_btn != null:
		p_btn.call_deferred("play_snap_animation")
		_last_dropped_index = -1
# ==========================================
# 按钮生成助手
# ==========================================
func _update_slot_button(base_container: MarginContainer, action: ActionData, index: int, is_player: bool) -> action_slot:
	var btn: action_slot = null
	for child in base_container.get_children():
		if child is action_slot:
			btn = child
			break
			
	if action == null:
		if btn:
			base_container.remove_child(btn)
			btn.queue_free()
		return null
		
	if btn == null:
		btn = action_button_scene.instantiate() as action_slot
		base_container.add_child(btn)
		if is_player and not btn.queue_action_clicked.is_connected(_on_timeline_action_cancelled):
			btn.queue_action_clicked.connect(_on_timeline_action_cancelled)
			
	btn.mode = "battle"
	btn.is_enemy_slot = not is_player 
	
	if is_player:
		btn.set_action_slot(action, 999, 0, true, index)
		btn.collapse(false, false)
	else:
		btn.set_action_slot(action, 999, 0, true)
		
	return btn
	
# ==========================================
# 助手：穿透动画掩体，安全获取所有真实时间轴行
# ==========================================
func _get_actual_timeline_rows() -> Array:
	var rows = []
	var timeline = timeline_container_panel.timeline
	for child in timeline.get_children():
		if child is timeline_slot:
			rows.append(child)
		# 如果它正在播放动画，它会被包裹在 AnimWrapper 中，我们要把它挖出来
		elif child.name == "AnimWrapper" and child.get_child_count() > 0:
			var slot = child.get_child(0)
			if slot is timeline_slot:
				rows.append(slot)
	return rows
	
# ==========================================
# 生成新行：使用“掩体剥离法”实现完美的推挤动画
# ==========================================
func _create_timeline_row(parent_container: Node, use_anim: bool) -> timeline_slot:
	var column = timeline_row_scene.instantiate() as timeline_slot
	var TARGET_HEIGHT = 80.0 # 如果你的行高不是 80，请修改这个数值！
	
	if use_anim:
		# 1. 制造一个“掩体”来欺骗 VBoxContainer 的高度计算
		var wrapper = Control.new()
		wrapper.name = "AnimWrapper"
		wrapper.clip_contents = true # 裁切溢出
		wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrapper.custom_minimum_size.y = 0.0 # 初始高度强制为 0
		
		parent_container.add_child(wrapper)
		wrapper.add_child(column)
		
		# 2. 强行设定内容宽度对齐，并保持其 80 像素的物理高度不变，只让外壳缩小
		column.set_anchor(SIDE_LEFT, 0.0)
		column.set_anchor(SIDE_RIGHT, 1.0)
		column.offset_left = 0
		column.offset_right = 0
		column.size.y = TARGET_HEIGHT 
		column.modulate.a = 0.0
		
		# 3. 动画：撑开掩体，自然挤压下方的 AppendZone
		var tw = create_tween().set_parallel(true)
		tw.tween_property(wrapper, "custom_minimum_size:y", TARGET_HEIGHT, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(column, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# 4. 动画结束后，剥除掩体，无缝还给 VBoxContainer，不留任何痕迹
		tw.chain().tween_callback(func():
			if is_instance_valid(wrapper) and is_instance_valid(column):
				var idx = wrapper.get_index()
				wrapper.remove_child(column)
				parent_container.add_child(column)
				parent_container.move_child(column, idx) # 保持原位
				wrapper.queue_free()
		)
	else:
		parent_container.add_child(column)
		
	column.was_paired = false
	column.p_was_present = false 
	return column

# ==========================================
# 待选池 (Action Pool)
# ==========================================
func _refresh_action_pool(turn_pairs: Array) -> void:
	var current_pool = pool_container.get_children()
	var pool_actions = player_entity.action_pool
	
	if current_pool.size() > pool_actions.size():
		for i in range(pool_actions.size(), current_pool.size()):
			var excess_btn = current_pool[i]
			pool_container.remove_child(excess_btn)
			excess_btn.queue_free()
			
	for i in range(pool_actions.size()):
		var action = pool_actions[i]
		var btn: action_slot
		
		if i < pool_container.get_child_count():
			btn = pool_container.get_child(i) as action_slot
		else:
			btn = action_button_scene.instantiate() as action_slot
			pool_container.add_child(btn)
			btn.collapse(true)
			btn.mode = "battle"
			btn.expand()
			btn.pool_action_clicked.connect(_on_pool_action_selected)
			
		var cd = player_entity.cooldown_tracker.get(action, 0)
		btn.set_action_slot(action, player_entity.current_ap, cd, false)
		
		var is_used_in_timeline = false
		for pair in turn_pairs:
			if pair[1] == action:
				is_used_in_timeline = true
				break
				
		# ==========================================
		# 【核心修改】：综合判定动作是否可用
		# ==========================================
		var is_on_cd = (cd > 0)
		var not_enough_ap = (player_entity.current_ap < action.ap_cost)
		
		# 只要满足 (被占用 / 冷却中 / AP不够) 任意一点，强行禁用！
		btn.is_disabled = is_used_in_timeline or is_on_cd or not_enough_ap
				

func animate_panel_fold(panel: PanelContainer, direction: String, fold: bool, duration: float = 0.25) -> void:
	if not is_instance_valid(panel):
		push_error("❌ animate_panel_fold: 目标 PanelContainer 实例无效！")
		return
		
	panel.clip_contents = true
	if panel.has_meta("active_tween"):
		var old_tween = panel.get_meta("active_tween") as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
			
	var full_size = panel.get_combined_minimum_size()
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	panel.set_meta("active_tween", tween)
	
	if not fold:
		panel.visible = true
	
	match direction.to_lower():
		"up", "down":
			if fold:
				tween.tween_property(panel, "custom_maximum_size:y", 0.0, duration)
				tween.tween_property(panel, "size:y", 0.0, duration)
				tween.tween_property(panel, "modulate:a", 0.0, duration)
				tween.chain().tween_callback(func(): panel.visible = false)
			else:
				if panel.custom_maximum_size.y < 0:
					panel.custom_maximum_size.y = 0.0
				tween.tween_property(panel, "custom_maximum_size:y", 655, duration)
				tween.tween_property(panel, "size:y", 655, duration)
				tween.tween_property(panel, "modulate:a", 1.0, duration)
				tween.chain().tween_callback(func(): panel.custom_maximum_size.y = -1.0)
		"left", "right":
			if fold:
				tween.tween_property(panel, "custom_maximum_size:x", 0.0, duration)
				tween.tween_property(panel, "size:x", 0.0, duration)
				tween.tween_property(panel, "modulate:a", 0.0, duration)
				tween.chain().tween_callback(func(): panel.visible = false)
			else:
				if panel.custom_maximum_size.x < 0:
					panel.custom_maximum_size.x = 0.0
				tween.tween_property(panel, "custom_maximum_size:x", full_size.x, duration)
				tween.tween_property(panel, "size:x", full_size.x, duration)
				tween.tween_property(panel, "modulate:a", 1.0, duration)
				tween.chain().tween_callback(func(): panel.custom_maximum_size.x = -1.0)
		_:
			push_error("❌ 未知的折叠方向: %s" % direction)
			return

# ==========================================
# 交互信号接收
# ==========================================
func _on_pool_action_selected(action: ActionData) -> void:
	var pairs = combat_manager.action_resolver.turn_action_pairs
	for i in range(pairs.size()):
		if pairs[i][1] == null:
			combat_manager.action_resolver.place_player_action(i, action, player_entity)
			return
	combat_manager.action_resolver.place_player_action(pairs.size(), action, player_entity)

func _on_timeline_action_cancelled(index: int) -> void:
	combat_manager.action_resolver.remove_player_action(index, player_entity)
	# 【核心修改】：明确要求进行时间轴的局部交互更新
	_update_timeline_interactively()


func _on_submit_pressed() -> void:
	
	# 【核心修改 1】：通过 bool 值进行第一段防抖，如果已经在结算中，直接丢弃该次点击
	if is_resolving_turn:
		return
		
	# 【核心修改 2】：开启透明遮罩，通过 MOUSE_FILTER_STOP 拦截此后的一切鼠标点击
	if ui_blocker:
		ui_blocker.show()
		
	turn_submitted.emit() 
	is_resolving_turn = true
	
	animate_panel_fold(pool_container_panel, "up", true)
	timeline_container_panel.collapse_all_slot_to_icon()
	timeline_container_panel.update_all_actions_map()
	
	# ==========================================
	# 【核心新增】：平滑隐藏并移除追加区 (ActionAppendZone)
	# ==========================================
	var timeline = timeline_container_panel.timeline
	var append_zone = timeline.get_node_or_null("ActionAppendZone")
	if append_zone:
		# 确保开启裁切，防止高度缩小时内部内容溢出
		append_zone.clip_contents = true 
		
		var zone_tw = create_tween().set_parallel(true)
		zone_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# 0.2秒内同时完成透明度褪去和高度压缩
		zone_tw.tween_property(append_zone, "modulate:a", 0.0, 0.2)
		zone_tw.tween_property(append_zone, "custom_minimum_size:y", 0.0, 0.2)
		zone_tw.tween_property(append_zone, "size:y", 0.0, 0.2)
		
		# 动画结束后彻底销毁该节点，保证结算环境干净
		zone_tw.chain().tween_callback(append_zone.queue_free)

	# ==========================================
	# 原有：整个父级容器的宽度收缩动画
	# ==========================================
	clip_contents = false
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(timeline_container_panel, "custom_maximum_size:x", compact_width, width_anim_duration)
	tween.tween_property(timeline_container_panel, "size:x", compact_width, width_anim_duration)
	
	await get_tree().create_timer(1).timeout
	
func _on_action_pair_executing(action_pair:Array) -> void:
	var target_slot = timeline_container_panel.find_slot_by_action_pair(action_pair)
	if target_slot:
		print("UI 成功找到了当前正在执行的时间轴行")
		target_slot.play_excute_animation()

# ===========================================
# 配合CombatManager阶段触发的函数
# ===========================================
func _on_turn_start():
	# 【核心修复 1】：锁定玩家操作！刚进入回合时，动画还没播完，绝对不能解锁
	is_resolving_turn = true
	if ui_blocker:
		ui_blocker.show()
		
	queue_refresh() 
	
	# 等待上游数据或时间轴初期的初始化动画
	await get_tree().create_timer(0.5).timeout
	
	animate_panel_fold(pool_container_panel, "up", false)
	
	var tween = create_tween()
	timeline_container_panel.custom_maximum_size.x = 622
	tween.tween_property(timeline_container_panel, "size:x", 622, width_anim_duration)
	
	# 【核心修复 2】：阻塞执行，死等这个横向展开动画彻底播完
	await tween.finished
	
	# 【核心修复 3】：所有的面板、节点、排版全部就绪后，真正交还控制权
	is_resolving_turn = false
	if ui_blocker:
		ui_blocker.hide()
	
	
func _on_player_phase():
	pass
	
func _on_submit():
	is_resolving_turn = true
	animate_panel_fold(pool_container_panel, "up", true)
	timeline_container_panel.collapse_all_slot_to_icon()
	timeline_container_panel.update_all_actions_map()
	clip_contents = false
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(timeline_container_panel, "custom_maximum_size:x", compact_width, width_anim_duration)
	tween.tween_property(timeline_container_panel, "size:x", compact_width, width_anim_duration)
	await get_tree().create_timer(1).timeout

# ==========================================
# 拖拽系统的核心中枢
# ==========================================
func _on_action_dropped_on_timeline(action: ActionData, target_index: int, source_index: int) -> void:
	var resolver = combat_manager.action_resolver
	
	var success = false
	if source_index == -1:
		success = resolver.place_player_action(target_index, action, player_entity)
	else:
		success = resolver.swap_player_action(source_index, target_index)
		
	# 【核心修改】：只有当底层数据层同意了这次操作，UI才进行视觉刷新
	if success:
		_last_dropped_index = target_index 
		_update_timeline_interactively()
	else:
		# UI层拒绝执行任何动画 (为以后做屏幕飘字 "补给不足！" 留出位置)
		print("UI：拦截操作，补给不足！")

func _on_append_action_dropped(action: ActionData, source_index: int) -> void:
	var resolver = combat_manager.action_resolver
	var target_index = resolver.turn_action_pairs.size() 
	
	var success = false
	if source_index == -1:
		success = resolver.place_player_action(target_index, action, player_entity)
	else:
		success = resolver.swap_player_action(source_index, target_index)
		
	# 【核心修改】：同上，底层同意后才刷新 UI 并播放平滑下推动画
	if success:
		_last_dropped_index = target_index 
		_update_timeline_interactively()
	else:
		print("UI：拦截操作，补给不足！")


#处理玩家死亡时的UI层逻辑
func handle_player_defeated():
	var scene = game_over_pack.instantiate()
	add_child(scene)
	scene.show_up()
