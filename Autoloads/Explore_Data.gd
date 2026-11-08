extends Node

# ==========================================
# 探索地图持久化数据
# ==========================================

# 保存地图节点结构。格式为 { Vector2(坐标) : MapNodeData(节点数据资源) }
var map_data: Dictionary = {}
var explore_scene:String = "res://Explore_Scene/Test_Explore_Scene.tscn"
# 保存玩家当前的绝对坐标
var player_position: Vector2 = Vector2.INF

# ==========================================
# 数据管理接口
# ==========================================

# 检查当前是否有存档的地图
func has_saved_map() -> bool:
	return not map_data.is_empty()

# 当玩家彻底游戏失败或开启新一轮游戏时调用，清空旧数据
func clear_map_data() -> void:
	map_data.clear()
	player_position = Vector2.INF
	

	
	# 未来如果增加了诸如“当前探索层数”、“已收集事件道具”等变量，也可以在这里一并重置
