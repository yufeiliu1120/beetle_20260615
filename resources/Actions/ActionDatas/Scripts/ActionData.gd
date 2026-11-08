class_name ActionData
extends Resource

@export_group("基础信息")
@export var action_name: String = "新动作"
@export var action_icon: Texture2D 
@export_multiline var description: String = ""
@export var tags: Array[String] = []

@export_group("消耗与冷却")
@export var ap_cost: int = 1
@export var base_cooldown: int = 0

@export_group("表现配置")
@export var ship_anim_name: String = ""
@export var tile_anim_name: String = ""

@export_group("效果挂载 (核心)")
# 动作的瞬间执行逻辑载体 (比如立即造成伤害、立即套盾)
@export var action_effects: Array[ActionEffect] = []

@export_group("状态附加 (Buffs)")

# ==========================================
# 运行时变量 (不导出到检查器)
# ==========================================
var source_tile = null
var target_action: ActionData = null

# ==========================================
# 效果分发逻辑
# ==========================================
func on_action_start(caster: CombatEntity) -> void:
	for effect in action_effects:
		if effect != null: 
			if effect.is_on_start:
				effect.Action = self
				effect.target_action = target_action
				effect.ship_anim_name = ship_anim_name
				effect.tile_anim_name = tile_anim_name
				effect.excute(caster)

func excute(caster: CombatEntity) -> void:
	for effect in action_effects:
		# 增加空判定，防止策划在检查器里手滑留空导致游戏崩溃
		if effect != null: 
			if not effect.is_on_start: 
				effect.Action = self
				effect.ship_anim_name = ship_anim_name
				effect.tile_anim_name = tile_anim_name
				effect.target_action = target_action
				effect.excute(caster)
	
# 自动提取 action_effects 中的所有 count 并填入描述文字
func set_text() -> String:
	var raw_text = description
	var dic: Dictionary = {}
	# 将AP消耗和基础CD添加到文本开头
	raw_text = "AP:{AP}  CD:{CD}  ".format({"AP":ap_cost,"CD":base_cooldown}) + raw_text
	
	# 遍历整个 action_effects 数组，把所有下标对应的数值都存起来
	for i in range(action_effects.size()):
		if action_effects[i] != null and action_effects[i].has_method("get_count_text"):
			dic[str(i)] = action_effects[i].get_count_text()
		else:
			dic[str(i)] = 0 # 容错兜底：防止某个 effect 为空导致报错
		
	# 传入整个字典！如果文本是 "造成{0}点伤害"，.format() 会只用 "0"，自动无视多余的 "1"、"2"
	return raw_text.format(dic)

# ==========================================
# 辅助函数
# ==========================================
func get_tags() -> Array[String]:
	return tags

func reset_target_action() -> void:
	target_action = null
	
# ==========================================
# 安全深度克隆（解决资源共享与跨实体污染问题）
# ==========================================
func get_unique_copy() -> ActionData:
	# 1. 复制最外层的壳子
	var clone = self.duplicate(false)
	# 2. 强制独立化标签数组
	clone.tags = self.tags.duplicate()
	
	# 3. 核心：手动深度克隆每一个效果组件，彻底斩断与原文件的联系！
	var new_effects: Array[ActionEffect] = []
	for effect in self.action_effects:
		if effect != null:
			# 对内部效果执行 true 深拷贝
			new_effects.append(effect.duplicate(true))
		else:
			new_effects.append(null)
			
	clone.action_effects = new_effects
	return clone
