extends Node2D
class_name Warship
@export var hexgridmanager:HexGridManager
@export var combatentity:CombatEntity
@export var is_player:bool
@export var visual_controller: Node2D
@export var animation_player:AnimationPlayer
signal _excute_action
func start_battle() -> void:
	# 显式地将管理器传给实体，避免在实体里用 get_parent() 这种容易因为改层级而报错的代码
	combatentity.init_aciont_pool(hexgridmanager)
	if is_player:
		scale.x = 1
		scale.y = 1
	else:
		scale.x = -1
		scale.y = 1
# 必须加上 async/await，确保战斗结算器能“等”动画播完
func excute_action(action: ActionData) -> void:
	print("触发动作：", action.action_name)
	
	if action in hexgridmanager.action_to_tile_map:
		# 分支 A：地块动作
		await hexgridmanager.excute_action_from_tile(action, combatentity)
	else:
		# ==========================================
		# 分支 B：自带动作 (闭包引用传递修复版)
		# ==========================================
		var anim_played = false
		
		# 【核心修复】：使用字典作为状态容器，强行逼迫 Godot 进行引用传递！
		var exec_state = {"is_done": false} 
		
		# 定义闭包逻辑
		var apply_damage = func():
			if not exec_state.is_done:
				print("⚔️ 触发伤害/动作结算！")
				action.excute(combatentity)
				exec_state.is_done = true # 标记为已执行
				
		if action.ship_anim_name != "" and visual_controller and "animation_player" in visual_controller:
			var anim_player = visual_controller.animation_player as AnimationPlayer
			
			if anim_player.has_animation(action.ship_anim_name):
				print("🎬 战舰触发自带动作动画: ", action.ship_anim_name)
				
				# 绑定打击信号 (CONNECT_ONE_SHOT 保证信号最多只触发一次)
				if visual_controller.has_signal("action_impact"):
					visual_controller.action_impact.connect(apply_damage, CONNECT_ONE_SHOT)
					
				anim_player.play(action.ship_anim_name)
				anim_played = true
				
				# 等待动画播完
				await anim_player.animation_finished
				
				# 清理冗余连接（防止因为没打关键帧导致信号没被消耗掉）
				if visual_controller.action_impact.is_connected(apply_damage):
					visual_controller.action_impact.disconnect(apply_damage)
			else:
				push_warning("⚠️ 未找到动画: " + action.ship_anim_name)
				
		if not anim_played:
			await get_tree().create_timer(0.5).timeout
			
		# 兜底判定：无论前面发生了什么，最后都 call 一次。
		# 如果关键帧已经触发过了，字典里的 is_done 就是 true，这里就不会再扣血了。
		apply_damage.call()
		play_idle()
# 【新增】：向外暴露的登场动画接口
func play_entrance() -> void:
	if visual_controller and visual_controller.has_method("play_starting_animation"):
		# 呼叫美术控制器播放动画，并等待它发出的结束信号
		await visual_controller.play_starting_animation()
	else:
		# 如果没有美术节点，假装等半秒钟，防止报错卡死
		await get_tree().create_timer(0.5).timeout
		
# 战舰基础状态表现		
func play_idle() -> void:
	if visual_controller and "animation_player" in visual_controller:
		var anim_player = visual_controller.animation_player as AnimationPlayer
		
		# 假设你的待机动画叫做 "Idle"，请根据实际情况修改字符串
		if anim_player.has_animation("Idle"):
			anim_player.play("Idle")
