extends AnimatedSprite2D
class_name beetle_part_base
var shadow
@export var tamed_scene:PackedScene  #用来表示驯服后的场景，会在捕获野生甲虫后自动更换为这个场景
@export var target_socket_name: String = ""
@export var base_ap:int = 0 #用来表示部件会给予战舰的AP值
@export var base_hp:int = 0 #部件会给予战舰的HP值
@export var base_supply:int = 0 #部件会给予战舰的补给值
@export var actions:Array[ActionData] #该部件会给予的动作
func _ready() -> void:
	# 更安全的节点获取方式，避免由于拼写错误导致引擎底层崩溃
	shadow = get_node_or_null("shadow")
	
	if not shadow:
		push_warning("⚠️ 部件 [%s] 未找到阴影子节点(shadow)！" % name)


func transfer_mounts(grid_manager: HexGridManager) -> void:
	print("正在尝试将部件地块挂点转移到舰船主场景")
	if not grid_manager:
		push_error("未找到地块管理器节点")
		return
	
	# 假设你在部件场景里建了一个叫 "Mounts" 的 Node2D 用来专门存放挂点
	var mounts_container = get_node_or_null("Mounts")
	if not mounts_container:
		return # 如果这个部件不带挂点，直接跳过
		
	# 获取所有挂点子节点
	var mounts = mounts_container.get_children()
	
	for mount in mounts:
		# 1. 记录转移前的绝对物理坐标（防止移交后发生位置偏移）
		if not mount is HexMount:
			push_error("该节点不是地块挂点")
		var global_pos = mount.global_position
		
		# 2. 剥夺抚养权，移交总管
		mounts_container.remove_child(mount)
		grid_manager.add_child(mount)
		
		# 3. 恢复绝对坐标
		mount.global_position = global_pos
		
		# 4. 手动补发注册逻辑（因为原本挂点的 _ready() 触发时父节点还不是网格管理器）
		if grid_manager.has_method("register_mount"):
			grid_manager.register_mount(mount)
			
		if not mount.tile_placed.is_connected(grid_manager.calculate_tile):
			mount.tile_placed.connect(grid_manager.calculate_tile)
			
			
# ==========================================
# 动态变色接口
# 参数 is_theme: true 代表修改主体颜色，false 代表修改装饰颜色
# ==========================================
func set_part_color(is_theme: bool, new_color: Color) -> void:
	if material and material is ShaderMaterial:
		# 修改着色器内的 uniform 变量
		if is_theme:
			material.set_shader_parameter("theme_color", new_color)
		else:
			material.set_shader_parameter("decorative_color", new_color)
	else:
		push_warning("⚠️ 部件 [%s] 未挂载 ShaderMaterial 变色材质，颜色修改失败！" % name)
