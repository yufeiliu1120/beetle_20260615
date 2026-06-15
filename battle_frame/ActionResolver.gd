
class_name ActionResolver
extends Node
signal round_finish
# ==========================================
# 动作结算核心逻辑
# 接收双方的战舰总成 (Warship)，按顺序交替调度
# ==========================================
# 用于同步等待双方动作同时完成的内部信号
signal _round_sync_finished

# 记录当前轮次还在播放动画的动作数量
var _running_animations: int = 0

func resolve_turn(p_warship: Warship, e_warship: Warship) -> void:
	print("\n=========== 💥 同步结算阶段开始 💥 ===========")
	
	var p_entity = p_warship.combatentity
	var e_entity = e_warship.combatentity
	
	var p_queue = p_entity.current_action_queue
	var e_queue = e_entity.current_action_queue
	
	var max_actions = max(p_queue.size(), e_queue.size())
	
	for i in range(max_actions):
		print("\n--- ⚔️ 动作轮次 %d ---" % (i + 1))
		
		var p_action: ActionData = p_queue[i] if i < p_queue.size() else null
		var e_action: ActionData = e_queue[i] if i < e_queue.size() else null
		
		# 如果双方有任何一方已经死亡，停止执行后续队列
		if p_entity.current_hp <= 0 or e_entity.current_hp <= 0:
			break
			
		# ==========================================
		# 【新增逻辑】：互相注入对应动作的标签 (Tag Injection)
		# ==========================================
		if p_action != null:
			p_action.refresh_target_action_tags() # 先清空旧数据
			if e_action != null:
				# 复制敌人的标签过来
				p_action.target_action_tags = e_action.tags.duplicate()
				
		if e_action != null:
			e_action.refresh_target_action_tags() # 先清空旧数据
			if p_action != null:
				# 复制玩家的标签过来
				e_action.target_action_tags = p_action.tags.duplicate()
				
		print("  -> 玩家动作标签: %s | 面对敌方动作标签: %s" % [
			p_action.tags if p_action else "无", 
			p_action.target_action_tags if p_action else "无"
		])
		print("  -> 敌方动作标签: %s | 面对玩家动作标签: %s" % [
			e_action.tags if e_action else "无", 
			e_action.target_action_tags if e_action else "无"
		])
		# ==========================================

		_running_animations = 0
		
		# 触发玩家动作
		if p_action != null and p_entity.current_hp > 0:
			p_entity.start_cooldown(p_action)
			_running_animations += 1
			_trigger_action_async(p_warship, p_action)
			
		# 触发敌人动作
		if e_action != null and e_entity.current_hp > 0:
			e_entity.start_cooldown(e_action)
			_running_animations += 1
			_trigger_action_async(e_warship, e_action)
			
		# 同步等待双方动画播完
		if _running_animations > 0:
			await self._round_sync_finished
			
		if p_entity.current_hp <= 0 or e_entity.current_hp <= 0:
			print("💀 有战舰已被摧毁，战斗结束！")
			break

	p_entity.current_action_queue.clear()
	e_entity.current_action_queue.clear()
	print("🏁 回合同步结算彻底完毕！")
	
func _trigger_action_async(warship: Warship, action: ActionData) -> void:
	await warship.excute_action(action)
	_running_animations -= 1
	if _running_animations <= 0:
		_round_sync_finished.emit()
