extends Resource
class_name BeetleChassisData

#这个资源类用来储存一个甲虫基础的信息
@export var ship_color:Dictionary = {"theme_color":Color(1,1,1,1),"decorative_color":Color(0,0,0,1)}
@export var ship_name:String = "Test Beetle" 

@export_group("战舰基础核心")
@export var base_ship_scene: PackedScene 

@export_group("模块化部件列表")
# 不再写死具体部位，直接给一个数组。可以在检查器里塞入任意数量的部件场景！
@export var part_scenes: Array[PackedScene] = []

@export_group("地块蓝图数据")
# 【全新升级】：直接保存在资源内部的地块配置蓝图
# Key: Vector2i (挂点的网格坐标 hex_coords)
# Value: String (卡牌/地块的场景路径 data_id)
@export var blueprint_data: Dictionary = {}


# ==========================================
# 资源持久化接口
# ==========================================
func save_to_disk(custom_path: String = "") -> void:
	var target_path: String = custom_path
	
	# 1. 如果没有传入自定义路径，则使用资源自带路径
	if target_path.is_empty():
		target_path = resource_path
		
	# 2. 依然为空，说明是全新创建且未指定路径
	if target_path.is_empty():
		push_error("❌ 保存失败：未提供路径，且该资源为内存实例！")
		return
		
	# ==========================================
	# 【核心修复】：解决错误码 15 (ERR_FILE_UNRECOGNIZED)
	# 强制检查路径后缀。如果没有合法的资源后缀，自动补全 .tres
	# ==========================================
	var lower_path = target_path.to_lower()
	if not lower_path.ends_with(".tres") and not lower_path.ends_with(".res"):
		target_path += ".tres"
		
	# 3. 自动创建不存在的文件夹
	var dir_path = target_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var make_dir_err = DirAccess.make_dir_recursive_absolute(dir_path)
		if make_dir_err != OK:
			push_error("❌ 保存失败：无法创建目标文件夹层级 -> ", dir_path)
			return

	# 4. 调用 Godot 原生 API 进行保存
	var err = ResourceSaver.save(self, target_path)
	
	if err == OK:
		# 路径接管：将内存数据与硬盘文件绑定
		if resource_path != target_path:
			take_over_path(target_path)
			
		print("💾 战舰图纸已成功生成并保存至本地: ", target_path)
	else:
		push_error("❌ 保存图纸失败，错误码: ", err)
