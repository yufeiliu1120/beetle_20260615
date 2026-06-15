extends ActionData
class_name BaseAttackAction
#基础动作脚本

# --- 战斗数值配置 ---
@export var damage: int = 10 # 测试用的伤害值

# ==========================================
# 动作执行逻辑
# 接收 caster (施法者实体)，借用它的节点树层级来寻找敌人
# ==========================================
func excute(caster: CombatEntity) -> void:
	if damage <= 0 or caster == null:
		return

	# 1v1 极简全局索敌：去场景里找所有的战舰
	var all_ships = caster.get_tree().get_nodes_in_group("Ships")
	var target_entity: CombatEntity = null

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
		if not target_action_tags.is_empty():
			if "Dodge" in target_action_tags:
				print("❌ 攻击落空！对方使用了闪避动作！")
				return

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
