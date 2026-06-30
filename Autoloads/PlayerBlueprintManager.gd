extends Node

# ==========================================
# 核心数据存储
# ==========================================
# 1. 【全新升级】：玩家当前使用的底盘图纸资源
var current_chassis: ShipChassisData = null

# 2. 当前局内的拼装地块图纸
# Key: Vector2i (挂点的网格坐标 hex_coords)
# Value: String (卡牌/地块的场景路径 data_id)
var current_blueprint: Dictionary = {}

# ==========================================
# 图纸操作接口
# ==========================================

# 清空上一局或旧的地块蓝图数据
func clear_blueprint() -> void:
	current_blueprint.clear()
	print("🗑️ PlayerBlueprintManager: 战舰地块蓝图已清空")

# 保存单个地块坐标与路径
func save_tile(coord: Vector2i, data_id: String) -> void:
	current_blueprint[coord] = data_id

# 打印当前蓝图（Debug 专用）
func print_blueprint() -> void:
	print("📜 [工厂日志] 当前保存的战舰地块蓝图：")
	if current_blueprint.is_empty():
		print("  (空白地块图纸)")
	else:
		for coord in current_blueprint:
			print("  📍 挂点坐标 %s -> 📦 地块路径: %s" % [str(coord), current_blueprint[coord]])

# ==========================================
# 核心工厂：自动物理造船
# 凭空实例化底盘，组装部件，并挂载地块
# ==========================================
func build_ship() -> Warship:
	if current_chassis == null or current_chassis.base_ship_scene == null:
		push_error("❌ 组装失败：未向工厂提供战舰底盘图纸 (current_chassis)！")
		return null
		
	# 1. 实例化一个纯净的、光秃秃的战舰底盘框架
	var ship_instance = current_chassis.base_ship_scene.instantiate() as Warship
	print("🏗️ PlayerBlueprintManager: 开始按图纸组装战舰...")
	
	# 2. 【核心新增】：组装甲虫身体部件，并释放挂点到网格中！
	# 这一步必须在寻找挂点之前执行，否则网格管理器里是空的
	if ship_instance.visual_controller and ship_instance.visual_controller.has_method("build_from_chassis"):
		ship_instance.visual_controller.build_from_chassis(current_chassis)
	else:
		push_warning("⚠️ 战舰缺少 visual_controller 或不支持动态图纸，跳过部件组装。")
	
	# 3. 定位网格管理器
	var grid_manager = ship_instance.find_child("HexGridManager", true, false)
	if grid_manager == null:
		push_error("❌ 组装失败：在提供的底盘上找不到 HexGridManager 节点！")
		return ship_instance

	# 【生命周期硬核解耦点】：
	# 因为部件刚刚把挂点交给了 grid_manager，现在正好能扫描到它们
	# 我们在内存中直接通过扫描子节点，建立一个临时的“挂点查找字典”。
	var temp_mount_map: Dictionary = {}
	for child in grid_manager.get_children():
		if child is HexMount:
			temp_mount_map[child.hex_coords] = child

	# 4. 严格按照图纸进行物理元件（地块）挂载
	for coord in current_blueprint:
		var data_id = current_blueprint[coord]
		var tile_scene = load(data_id) as PackedScene
		
		if tile_scene != null:
			var tile_instance = tile_scene.instantiate() as TileBase
			if temp_mount_map.has(coord):
				var target_mount = temp_mount_map[coord]
				target_mount.add_child(tile_instance)
				print("  -> 成功挂载地块到坐标: ", coord)
			else:
				push_warning("  -> 图纸坐标 %s 在当前底盘上没有对应的挂点，地块挂载失败！" % str(coord))
				tile_instance.queue_free()
		else:
			push_warning("  -> 无法加载地块资源: ", data_id)

	print("✅ 战舰物理组装完毕！")
	return ship_instance
