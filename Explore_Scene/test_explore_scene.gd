extends Node2D
class_name text_explore_scene

@export_group("部件")
@export var UI_layer: CanvasLayer
@export var MapNodesContainer: Node2D
@export var player_node:PlayerMapIcon
@export var Center_Marker: Marker2D

var selected_node:MapNode
var map_node_path: String = "res://Explore_Scene/MapNode.tscn"
var path_line: Line2D = preload("res://Explore_Scene/line.tscn").instantiate()
# ==========================================
# 同心椭圆散布设置
# ==========================================
@export_group("地图散布设置")
@export var ring_count: int = 3             # 椭圆的层数 (例如: 1, 2, 3)
@export var ring_spacing_x: float = 300.0   # 横向（X轴）的层级间距
@export var ring_spacing_y: float = 180.0   # 纵向（Y轴）的层级间距
@export var min_node_distance: float = 120.0 
@export var max_spawn_attempts: int = 50    
@export var show_debug_rings: bool = true   # 开启/关闭测试辅助线
@export var nodes_pool: Array[MapNodeData] 
# 在你的 @export_group("地图散布设置") 下方增加：
@export var total_node_count: int = 8     # 目标生成的节点总数（包含中心的城镇）

@export_group("探索消耗设置")
@export var pixels_per_supply: float = 50.0 # 每移动多少像素消耗 1 点补给

var map_nodes: Array = []
var debug_drawer: Node2D

signal player_stranded(remaining_supply: int)


func _ready() -> void:
	UI_layer.call_deferred("set_UI_layer")
	queue_redraw()
	check_if_stranded()
	# ==========================================
	# 动态创建路径预览线
	# ==========================================
	path_line.width = 6.0
	path_line.top_level = true # 开启此选项，直接使用全局坐标画线，无视父节点偏移
	path_line.z_index = 2 # 确保它在辅助线(100)之下，但在背景之上
	add_child(path_line)
	
	# 初始化时隐藏或者没有点
	path_line.clear_points()
	generate_map()
	player_node._generate_snapshot()
	
# ==========================================
# 辅助线绘制逻辑 (修改为由 debug_drawer 执行)
# ==========================================
func _on_debug_draw() -> void:
	if not show_debug_rings or Center_Marker == null:
		return
		
	for ring in range(1, ring_count + 1):
		var points: PackedVector2Array = []
		var rx = ring * ring_spacing_x
		var ry = ring * ring_spacing_y
		var segments = 64 
		
		for i in range(segments + 1):
			var angle = (float(i) / segments) * TAU
			var pt = Center_Marker.position + Vector2(cos(angle) * rx, sin(angle) * ry)
			points.append(pt)
			
		# 【核心修改】：通过 debug_drawer 调用 draw_polyline
		debug_drawer.draw_polyline(points, Color(1, 1, 1, 0.4), 2.0, true)


# ==========================================
# 地图生成与恢复逻辑
# ==========================================
func generate_map() -> void:
	var is_new_map = not ExploreData.has_saved_map()
	
	# 1. 如果没有存档，生成新地图并存入单例
	if is_new_map:
		ExploreData.map_data = create_map_Dictionary()
		# 初始状态下，记录玩家的起始位置为中心点
		ExploreData.player_position = Center_Marker.global_position
		print("🗺️ 生成全新探索地图并存入存档！")
	else:
		print("♻️ 发现地图存档，正在恢复地图状态...")

	# 2. 从单例中提取字典并开始铺设节点
	var dic = ExploreData.map_data
	for node_pos in dic.keys():
		add_map_node(dic[node_pos], node_pos)
		
		# 只有新生成的地图才播放逐个弹出的延迟动画，恢复存档时瞬间铺满
		if is_new_map:
			await get_tree().create_timer(0.1).timeout 

	# 3. 同步玩家的位置
	if ExploreData.player_position != Vector2.INF:
		player_node.global_position = ExploreData.player_position
		# 确保玩家节点的内部状态也更新到新位置[cite: 8]
		player_node._generate_snapshot()
		
func get_random_node_data() -> MapNodeData:
	var randi = randi_range(0, nodes_pool.size() - 1)
	return nodes_pool[randi]

# ==========================================
# 核心算法：按指定数量抽取，并离散分布
# ==========================================
func create_map_Dictionary() -> Dictionary:
	var result = {}
	
	# 1. 寻找城镇节点并放置在中心
	var town_data: MapNodeData = null
	for data in nodes_pool:
		if data.node_type == MapNodeData.NodeType.TOWN:
			town_data = data
			result[Center_Marker.global_position] = data
			break
			
	# 2. 建立一个“抽卡池”（复制原数组，防止破坏原始数据）
	var draw_pool = nodes_pool.duplicate()
	if town_data != null:
		draw_pool.erase(town_data) # 把已经放好的城镇从卡池里剔除
		
	draw_pool.shuffle() # 将卡池彻底打乱
	
	# 3. 抽取所需数量的节点
	var selected_data_array: Array[MapNodeData] = []
	var needed_count = total_node_count - result.size() # 扣除已经放置的城镇
	
	for i in range(needed_count):
		# 如果抽卡池空了，但还没达到目标数量，就重新拿一副新牌洗乱（允许开始重复）
		if draw_pool.is_empty():
			draw_pool = nodes_pool.duplicate()
			if town_data != null:
				draw_pool.erase(town_data)
			draw_pool.shuffle()
			
			# 兜底防死循环：如果池子里除了城镇什么都没有，直接中断抽取
			if draw_pool.is_empty():
				push_warning("⚠️ 节点池中没有足够的非城镇节点可供生成！")
				break
				
		# pop_back() 会取出并移除数组的最后一个元素，确保本次卡池内绝对不重复
		selected_data_array.append(draw_pool.pop_back())

	# 4. 将抽取出的节点放入地图（保留你原本的椭圆生成逻辑）
	for data in selected_data_array:
		var valid_position = false
		var spawn_pos = Vector2.ZERO
		
		for attempt in range(max_spawn_attempts):
			var current_ring = randi_range(1, ring_count)
			var current_rx = current_ring * ring_spacing_x
			var current_ry = current_ring * ring_spacing_y
			
			var random_angle = randf() * TAU 
			
			spawn_pos = Center_Marker.global_position + Vector2(cos(random_angle) * current_rx, sin(random_angle) * current_ry)
			
			var is_too_close = false
			for existing_pos in result.keys():
				if spawn_pos.distance_to(existing_pos) < min_node_distance:
					is_too_close = true
					break 
					
			if not is_too_close:
				valid_position = true
				break 
				
		if valid_position:
			result[spawn_pos] = data
		else:
			push_warning("⚠️ 节点生成失败：位置太拥挤，已被舍弃。")
	ExploreData.map_data = result
	return result

func add_map_node(Data: MapNodeData, node_position: Vector2):
	var map_node: MapNode = load(map_node_path).instantiate()
	map_node.setup(Data)
	MapNodesContainer.add_child(map_node)
	map_node.global_position = node_position
	map_node.node_selected.connect(_on_map_node_selected)
	map_node.start_voyage.connect(player_sail_to)
# ==========================================
# 节点点击：仅进入“预览状态”
# ==========================================
func _on_map_node_selected(node: MapNode) -> void:
	if node.node_data == null: return
	#隐藏现在开启的节点信息
	if selected_node:
		selected_node.hide_panel()
	# 1. 计算距离与理论补给消耗
	var distance: float = player_node.global_position.distance_to(node.global_position)
	var supply_cost: int = ceili(distance / pixels_per_supply)
	# 2. 画出预览线 (起点: 玩家位置, 终点: 目标节点)
	path_line.clear_points()
	path_line.add_point(player_node.global_position)
	path_line.add_point(node.global_position)
	
	# 3. 呼叫目标节点，弹出事件信息与消耗提示
	if node.has_method("show_information"):
		node.show_information(supply_cost)
		selected_node = node
# ==========================================
# 绝境检测逻辑
# ==========================================
func check_if_stranded() -> void:
	var can_reach_any_node: bool = false
	
	# 遍历地图容器下的所有节点
	for child in MapNodesContainer.get_children():
		if child is MapNode and not child.is_locked:
			var distance: float = player_node.global_position.distance_to(child.global_position)
			var cost: int = ceili(distance / pixels_per_supply)
			
			# 只要发现一个能到的，就立刻判定安全，中断循环
			if PlayerData.current_supply >= cost:
				can_reach_any_node = true
				break
				
	# 如果循环结束依然为 false，说明所有节点的消耗都大于当前补给
	if not can_reach_any_node:
		print("🚨 警告：补给不足以抵达任何节点！触发受困事件！")
		player_stranded.emit(PlayerData.current_supply)
		
# ==========================================
# 执行移动与场景跳转
# ==========================================
func player_sail_to(node: MapNode) -> void:
	if node == null or node.node_data == null: 
		return
	
	var distance: float = player_node.global_position.distance_to(node.global_position)
	var supply_cost: int = ceili(distance / pixels_per_supply)
	
	if PlayerData.current_supply < supply_cost:
		print("⚠️ 出发失败：补给不足！需要: %d，当前: %d" % [supply_cost, PlayerData.current_supply])
		return
		
	PlayerData.current_supply -= supply_cost
	print("⛽ 舰队启航！消耗补给: %d | 剩余补给: %d" % [supply_cost, PlayerData.current_supply])
	
	if path_line:
		path_line.clear_points()
	node.hide_panel()
	player_node.move_to_node(node)
	await player_node.movement_finished
	
	# ==========================================
	# 【核心新增】：在跳转场景前，将玩家到达的新坐标存入单例！
	# ==========================================
	ExploreData.player_position = player_node.global_position
	if ExploreData.map_data.has(node.global_position):
		ExploreData.map_data.erase(node.global_position)
		print("✅ 节点已攻克，从地图存档中永久移除！")
	PlayerData.upcoming_enemy_chassis = node.node_data.enemy_chassis
	PlayerData.upcoming_enemy_scene = node.node_data.enemy_scene
	
	if node.node_data.target_scene != null:
		SceneManager.load_scene(node.node_data.target_scene)
	else:
		push_error("❌ 该节点资源未配置 target_scene！无法进行跳转。")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if selected_node:
				selected_node.hide_panel()
