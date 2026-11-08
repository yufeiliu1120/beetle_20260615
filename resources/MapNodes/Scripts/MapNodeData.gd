extends Resource
class_name MapNodeData

# ==========================================
# 节点类型枚举 (从原先的 MapNode 中提出来，放在数据层)
# ==========================================
enum NodeType {
	MONSTER_BATTLE,       # 怪物战斗
	PIRATE_BATTLE, # 敌舰战斗
	EVENT,        # 随机事件
	TOWN,         # 城镇/商店
	BOSS          # Boss
}

@export_group("基础表现")
@export var node_type: NodeType = NodeType.MONSTER_BATTLE
@export var icon: Texture2D
@export_multiline var description: String = "" # 使用 multiline 让检查器里的文本框更大，方便写事件长描述

@export_group("场景跳转核心")
@export var target_scene: PackedScene

@export_group("战斗遭遇配置 (可选)")
@export var enemy_chassis: BeetleChassisData # 针对甲虫类敌人
@export var enemy_scene: PackedScene         # 针对非甲虫的一体化 Boss/野怪
