extends ActionEffect
class_name BaseAttackAction
#基础动作脚本

# --- 战斗数值配置 ---

func excute(caster: CombatEntity) -> void:
	var count = get_final_count()
	if count <= 0:
		return
	if caster == null:
		return

	# 1v1 极简全局索敌：去场景里找所有的战舰
	var all_ships = caster.get_tree().get_nodes_in_group("Ships")
	var target_entity: CombatEntity = null
	#计算伤害
	var damage = count
	# 遍历战舰，只要战舰里的大脑（CombatEntity）不是我自己，那它就是敌人
	for ship in all_ships:
		var entity = ship.find_child("CombatEntity", true, false)
		if entity != null and entity != caster:
			target_entity = entity
			break

	# ==========================================
	# 检测对方动作的标签
	# ==========================================
	if target_entity:
		if target_action:
			if has_target_tag("Dodge"):
				print("❌ 攻击落空！对方使用了闪避动作！")
				return
			if has_target_tag("Defend"):
				for effect in target_action.action_effects:
					if effect is BaseDefendEffect:
						damage -= effect.get_final_count()
						print("攻击对应防御动作，减免{count}点伤害".format({"count": effect.get_final_count()}))
	# ==========================================
	# 结算伤害并通知 UI
	# ==========================================
	if target_entity:
		target_entity.take_damage(damage)
		
		# 兜底：防止血量掉到 0 以下
		target_entity.current_hp = max(0, target_entity.current_hp)
		
		print("⚔️ 命中目标！造成了 %d 点伤害，敌方剩余 HP: %d" % [damage, target_entity.current_hp])
		
		# 【核心】：一定要发射这个信号！否则底层的血扣了，顶层的 UI 血条/文本不会刷新
		target_entity.stats_changed.emit()
	else:
		push_warning("⚠️ 动作释放失败：未在场景中找到敌方战舰！")
