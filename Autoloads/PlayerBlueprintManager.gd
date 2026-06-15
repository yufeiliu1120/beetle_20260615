extends Node

# ==========================================
# 核心数据存储
# ==========================================
# 1. 战舰白板底盘预制体（在游戏启动或选择战舰时由外部赋值）
var player_base_ship: PackedScene = null

# 2. 当前局内的拼装图纸
# Key: Vector2i (挂点的网格坐标 hex_coords)
# Value: String (卡牌/地块的场景路径 data_id)
var current_blueprint: Dictionary = {}

# ==========================================
# 图纸操作接口
# ==========================================

# 清空上一局或旧的蓝图数据
func clear_blueprint() -> void:
	current_blueprint.clear()
	print("🗑️ PlayerBlueprintManager: 战舰蓝图已清空")

# 保存单个地块坐标与路径
func save_tile(coord: Vector2i, data_id: String) -> void:
	current_blueprint[coord] = data_id

# 打印当前蓝图（Debug 专用）
func print_blueprint() -> void:
	print("📜 [工厂日志] 当前保存的战舰蓝图：")
	if current_blueprint.is_empty():
		print("  (空白图纸)")
	else:
		for coord in current_blueprint:
			print("  📍 挂点坐标 %s -> 📦 地块路径: %s" % [str(coord), current_blueprint[coord]])

# ==========================================
# 核心工厂：自动物理造船
# 凭空实例化底盘，并根据图纸将地块节点挂载到对应的挂点下
# ==========================================
func build_ship() -> Node2D:
	if player_base_ship == null:
		push_error("❌ 组装失败：未向工厂提供战舰基础底盘 (player_base_ship)！")
		return null
		
	# 1. 实例化一个纯净的、光秃秃的战舰底盘
	var ship_instance = player_base_ship.instantiate()
	print("🏗️ PlayerBlueprintManager: 开始按图纸组装战舰...")
	
	# 2. 定位网格管理器
	var grid_manager = ship_instance.find_child("HexGridManager", true, false)
	if grid_manager == null:
		push_error("❌ 组装失败：在提供的底盘上找不到 HexGridManager 节点！")
		return ship_instance

	# 【生命周期硬核解耦点】：
	# 因为此时整个 ship_instance 还没被 add_child() 到游戏世界里，
	# 挂点和网格管理器的 _ready() 绝对没有跑，所以 grid_manager.grid_map 必然是空的。
	# 我们在内存中直接通过扫描子节点，建立一个临时的“挂点查找字典”。
	var temp_mount_map: Dictionary = {}
	for child in grid_manager.get_children():
		if child is HexMount:
			temp_mount_map[child.hex_coords] = child

	# 3. 严格按照图纸进行物理元件挂载
	for coord in current_blueprint:
		var data_id = current_blueprint[coord]
		var tile_scene = load(data_id) as PackedScene
		
		if tile_scene != null:
			var tile_instance = tile_scene.instantiate()
			# 注入路径数据
			if "data_id" in tile_instance:
				tile_instance.data_id = data_id
				
			# 检查这艘船有没有图纸要求的坑位
			if temp_mount_map.has(coord):
				var mount = temp_mount_map[coord] as HexMount
				
				# 【无敌的场景树架构】：直接呼叫 attach_tile 将其变成挂点的子节点
				# 此时不进行任何数值计算，纯做物理上的拼装
				mount.attach_tile(tile_instance)
			else:
				push_warning("⚠️ 蓝图警告：图纸要求在坐标 %s 放零件，但该船底盘没有这个挂点！" % str(coord))
		else:
			push_error("❌ 工厂错误：无法加载地块资源路径 -> " + data_id)
	ship_instance.is_player = true
	print("✅ PlayerBlueprintManager: 战舰物理躯壳全量组装完毕，等待注入世界！")
	return ship_instance
