extends Node

# ==========================================
# 核心工厂：自动物理造船
# 根据传入的 Resource 图纸，凭空实例化底盘，组装部件，并挂载地块
# ==========================================
func build_ship(chassis_data: BeetleChassisData) -> Warship:
	if chassis_data == null or chassis_data.base_ship_scene == null:
		push_error("❌ 组装失败：未向工厂提供战舰底盘图纸！")
		return null
		
	# 1. 实例化一个纯净的、光秃秃的战舰底盘框架
	var ship_instance = chassis_data.base_ship_scene.instantiate() as Warship
	print("🏗️ Factory: 开始按图纸 [%s] 组装战舰..." % chassis_data.ship_name)
	
	# 2. 组装甲虫身体部件，并释放挂点到网格中！
	if ship_instance.visual_controller and ship_instance.visual_controller.has_method("build_from_chassis"):
		ship_instance.visual_controller.build_from_chassis(chassis_data)
	else:
		push_warning("⚠️ 战舰缺少 visual_controller 或不支持动态图纸，跳过部件组装。")
	
	# 3. 定位网格管理器
	var grid_manager = ship_instance.find_child("HexGridManager", true, false)
	if grid_manager == null:
		push_error("❌ 组装失败：在提供的底盘上找不到 HexGridManager 节点！")
		return ship_instance

	# 在内存中直接通过扫描子节点，建立一个临时的“挂点查找字典”
	var temp_mount_map: Dictionary = {}
	for child in grid_manager.get_children():
		if child is HexMount:
			temp_mount_map[child.hex_coords] = child

	# 4. 【核心修改】：严格按照 Resource 里的 blueprint_data 进行地块挂载
	for coord in chassis_data.blueprint_data:
		var data_id = chassis_data.blueprint_data[coord]
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
	ship_instance.ship_name = chassis_data.ship_name
	print("✅ 战舰物理组装完毕！")
	return ship_instance
