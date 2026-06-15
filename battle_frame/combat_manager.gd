class_name CombatManager
extends Node

# 战斗的五个核心状态
enum CombatState {
	TURN_START,      # 回合开始
	ENEMY_THINKING,  # 敌人思考
	PLAYER_PHASE,    # 玩家回合
	RESOLUTION,      # 回合结算
	TURN_END         # 回合结束
}

var current_state: CombatState = CombatState.TURN_START

# ==========================================
# 核心部件引用：现在只管理最高层级的 Warship 外观！
# ==========================================
var player_warship: Warship
var enemy_warship: Warship

@export var ui_manager: ActionUIManager
@export var action_resolver: ActionResolver

signal battle_ended

func _ready() -> void:
	# 不在 _ready 自动启动，等待测试场景或外部总控脚本手动呼叫 start_battle()
	pass

# ==========================================
# 手动启动战斗的入口
# ==========================================
func start_battle() -> void:
	print("🚀 CombatManager: 正在接管战局，启动战斗流程...")
	
	# 1. 在场景中定位双方战舰 (Warship)
	_initialize_battle_entities()
	
	if player_warship == null or enemy_warship == null:
		push_error("错误：CombatManager 无法在场景中找齐玩家和敌人的 Warship 节点！")
		return

	# 2. 呼叫战舰的外观接口：让战舰内部自己去算 Buff、整合动作池
	player_warship.start_battle()
	enemy_warship.start_battle()
	
	print("🎥 正在播放双方战舰登场动画...")
	# 使用隐式协程并发，让两艘船同时播放登场动画
	player_warship.play_entrance()
	enemy_warship.play_entrance()
	
	# 等待玩家战舰的美术节点发出完成信号（因为两边大概率是同时完成的）
	await player_warship.visual_controller.entrance_finished
	
	print("⚔️ 登场完毕，正式开始绑定 UI 与第一回合！")
	# 3. 绑定 UI：注意！UI 依然只看纯数据，所以我们把战舰里的 combatentity 挑出来喂给 UI
	ui_manager.bind_entities(player_warship.combatentity, enemy_warship.combatentity)
	
	if not ui_manager.turn_submitted.is_connected(_on_player_turn_submitted):
		ui_manager.turn_submitted.connect(_on_player_turn_submitted)
	
	print("⚔️ 战斗系统就绪，正式开始第一回合！")
	change_state(CombatState.TURN_START)

# ==========================================
# 动态获取战舰的逻辑
# ==========================================
func _initialize_battle_entities() -> void:
	# 假设你的战舰根节点 (挂载着 warship.gd 的节点) 在 "Ships" 分组中
	var all_ships = get_tree().get_nodes_in_group("Ships")

	for ship in all_ships:
		if ship is Warship:
			# 检查战舰上的 is_player 标识
			if ship.get("is_player") == true:
				player_warship = ship 
				print("✅ 已定位玩家战舰: ", ship.name)
			else:
				enemy_warship = ship
				print("✅ 已定位敌方战舰: ", ship.name)

# ==========================================
# 状态机核心控制逻辑
# ==========================================
func change_state(new_state: CombatState) -> void:
	current_state = new_state
	match current_state:
		CombatState.TURN_START: _state_turn_start()
		CombatState.ENEMY_THINKING: _state_enemy_thinking()
		CombatState.PLAYER_PHASE: _state_player_phase()
		CombatState.RESOLUTION: _state_resolution()
		CombatState.TURN_END: _state_turn_end()

func _state_turn_start() -> void:
	print("\n========== 第 新 回 合 ==========")
	# 回合开始，恢复 AP 和削减 CD
	player_warship.combatentity.on_turn_start()
	enemy_warship.combatentity.on_turn_start()
	change_state(CombatState.ENEMY_THINKING)

func _state_enemy_thinking() -> void:
	print("🤖 敌方 AI 正在思考...")
	# AI 直接操作底层的 combatentity
	var e_entity = enemy_warship.combatentity
	var available_actions = []
	
	for action in e_entity.action_pool:
		if e_entity.is_action_available(action):
			available_actions.append(action)
			
	while available_actions.size() > 0 and e_entity.current_ap > 0:
		var random_action = available_actions.pick_random()
		if e_entity.current_ap >= random_action.ap_cost:
			e_entity.use_action(random_action)
		else:
			break
		available_actions.clear()
		for action in e_entity.action_pool:
			if e_entity.is_action_available(action):
				available_actions.append(action)
				
	change_state(CombatState.PLAYER_PHASE)

func _state_player_phase() -> void:
	print("🎮 等待玩家操作...")
	# 放开 UI 的点击屏蔽
	ui_manager.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_player_turn_submitted(final_queue: Array[ActionData]) -> void:
	if current_state == CombatState.PLAYER_PHASE:
		# 屏蔽 UI 点击，防止结算时乱点
		ui_manager.mouse_filter = Control.MOUSE_FILTER_STOP
		change_state(CombatState.RESOLUTION)

func _state_resolution() -> void:
	# 【核心解耦点】：把两艘完整的战舰扔给结算器，CombatManager 坐等结算完毕
	await action_resolver.resolve_turn(player_warship, enemy_warship)
	change_state(CombatState.TURN_END)

func _state_turn_end() -> void:
	var p_hp = player_warship.combatentity.current_hp
	var e_hp = enemy_warship.combatentity.current_hp
	
	if p_hp <= 0 or e_hp <= 0:
		_handle_battle_end()
	else:
		# 活着的话，等 1 秒进入下一回合，给玩家一点喘息时间
		await get_tree().create_timer(1.0).timeout
		change_state(CombatState.TURN_START)

func _handle_battle_end() -> void:
	var p_hp = player_warship.combatentity.current_hp
	var e_hp = enemy_warship.combatentity.current_hp
	
	if p_hp <= 0 and e_hp <= 0:
		print("💀 同归于尽！")
	elif p_hp <= 0:
		print("💀 玩家战败！")
	else:
		print("🏆 玩家胜利！")
		
	battle_ended.emit()
