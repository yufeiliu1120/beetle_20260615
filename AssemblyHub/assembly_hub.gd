extends Control
class_name assumbly_hub
@export_group("核心节点关联")
@export var finish_button: Button
@export var assumbly_slot_manager:AssemblySlotManager
@export var ap_bar:ap_container
@export var _hp_bar:hp_bar
@export var _supply_bar:supply_bar
@export var action_slot_container:assumbly_action_slot_container
@export var name_label:Label
# ==========================================
# 信号定义
# ==========================================
# 当地块成功在战舰网格上吸附落地时发出，留给“新组件”去扣除背包和刷新槽位！
signal tile_placed_on_ship(card_path: String) 
# 当玩家点击完成拼装并保存图纸后发出
signal assumbly_finished
signal started
signal tile_changed

var grid_manager: HexGridManager 

func _ready() -> void:
	if finish_button:
		finish_button.pressed.connect(_on_finish_button_pressed)
	assumbly_finished.connect(_on_assumbly_finished)
	hide()

func _on_hex_grid_manager_calculate():
	tile_changed.emit()

# ==========================================
# 启动与初始化
# ==========================================
func start_assumbly() -> void:
	print("🔧 AssemblyHub: 交互中枢启动...")
	# 获取最新的网格管理器
	var ship = get_tree().get_first_node_in_group("Ships")
	if ship and "hexgridmanager" in ship:
		grid_manager = ship.hexgridmanager
		print("✅ 找到玩家战舰网格管理器")
	else:
		push_error("❌ 玩家战舰网格管理器未发现，或战舰未在 Ships 分组中")
	assumbly_slot_manager.sync_inventory_data()
	assumbly_slot_manager. refresh_page_display()
	grid_manager.calculate_start.connect(_on_hex_grid_manager_calculate)
	grid_manager.tile_removed.connect(_on_tile_removed)
	_on_hex_grid_manager_calculate()
	name_label.text = ship.ship_name
	show() 
	print("✅ 中枢就绪，等待新组件介入与玩家操作。")

# ==========================================
# 【新增接口】：提供给新组件注册槽位信号
# 新组件生成或管理 Slot 后，只需调用 hub.register_slot(slot) 即可接入系统
# ==========================================
func register_slot(slot: Node) -> void:
	if slot.has_signal("request_drag"):
		# 防重复连接保护
		if not slot.request_drag.is_connected(_on_slot_request_drag):
			slot.request_drag.connect(_on_slot_request_drag)
	else:
		push_error("❌ 尝试注册槽位失败：目标节点没有 request_drag 信号 -> " + slot.name)

func unregister_slot(slot: Node) -> void:
	if slot.has_signal("request_drag") and slot.request_drag.is_connected(_on_slot_request_drag):
		slot.request_drag.disconnect(_on_slot_request_drag)

# ==========================================
# 拖拽与实体生成 (纯粹的物理交互)
# ==========================================
func _on_slot_request_drag(new_tile: Node2D, card_path: String) -> void:
	new_tile.data_id = card_path
	new_tile.scale = Vector2(1.25,1.25)
	new_tile.z_index = 99
	new_tile.global_position = get_global_mouse_position()
	get_tree().current_scene.add_child(new_tile)
	if new_tile.has_signal("tile_placed"):
		new_tile.connect("tile_placed", _on_tile_successfully_placed.bind(new_tile,card_path))
	else:
		push_error("❌ 错误：生成的实体上没有发现 tile_placed 信号！")
	
	if new_tile.has_node("StateMachine"):
		new_tile.get_node("StateMachine").change_state("Dragging")


# ==========================================
# 核心响应：当地块吸附落地成功时
# ==========================================
func _on_tile_successfully_placed(new_tile,card_path: String) -> void:
	print("开始计算地块基础属性加成")
	var bonus_hp: int = 0
	var bonus_ap: int = 0
	var bonus_supply: int = 0
	# 1. 遍历当前网格上所有的有效拼装地块
	if new_tile.has_method("entity_buff"):
		var buffs = new_tile.entity_buff()
			# 安全提取各个属性的加成值，如果没有则默认为 0
		bonus_hp += buffs.get("max_hp", 0)
		bonus_ap += buffs.get("max_ap", 0)
		bonus_supply += buffs.get("max_supply", 0)
	var ship = get_tree().get_first_node_in_group("Ships")
	if ship and "combatentity" in ship and ship.combatentity != null:
		var entity = ship.combatentity
		entity.max_hp += bonus_hp
		entity.max_ap += bonus_ap
		PlayerData.max_supply += bonus_supply
			
	print("📦 [物理交互] 检测到地块实体成功落地！广播放置信号...")
	tile_placed_on_ship.emit(card_path)
	
#删除地块时触发基础属性的变化
func _on_tile_removed(tile:TileBase):
	print("开始计算移除地块时的属性恢复")
	var bonus_hp: int = 0
	var bonus_ap: int = 0
	var bonus_supply: int = 0
	
	if tile.has_method("entity_buff"):
		var buffs = tile.entity_buff()
			# 安全提取各个属性的加成值，如果没有则默认为 0
		bonus_hp += buffs.get("max_hp", 0)
		bonus_ap += buffs.get("max_ap", 0)
		bonus_supply += buffs.get("max_supply", 0)
	var ship = get_tree().get_first_node_in_group("Ships")
	if ship and "combatentity" in ship and ship.combatentity != null:
		var entity = ship.combatentity
		entity.max_hp -= bonus_hp
		entity.max_ap -= bonus_ap
		PlayerData.max_supply -= bonus_supply
		

# ==========================================
# 完成拼装与图纸上传 (纯粹的蓝图业务)
# ==========================================
func _on_finish_button_pressed() -> void:
	print("💾 玩家点击了完成拼装，开始上传图纸...")
	PlayerData.player_chassis.blueprint_data.clear()
	if grid_manager:
		for coords in grid_manager.grid_map:
			var mount = grid_manager.grid_map[coords]
			var tile = mount.get_tile() 
			
			# 【终极判定】：只在真正的“主锚点”上保存！
			# 无论这个地块占了多少格，在场景树中它永远只是“主挂点”的子节点。
			if tile != null and tile.get_parent() == mount:
				var actual_tile_path = tile.scene_file_path
				if actual_tile_path != "":
					PlayerData.player_chassis.blueprint_data[coords] = actual_tile_path
				else:
					push_error("❌ 严重错误：坐标 %s 上的地块无法获取场景路径！" % str(coords))
		PlayerData.player_chassis.save_to_disk()
		print("玩家图纸上传完成：{dic}".format({"dic":PlayerData.player_chassis.blueprint_data}))
	#让玩家状态变量保存当前状态
	PlayerData.init_run_data(get_tree().get_first_node_in_group("PlayerShip"))
	assumbly_finished.emit()


func _on_assumbly_finished():
	ExploreData.clear_map_data()
	SceneManager.load_scene("res://Explore_Scene/Test_Explore_Scene.tscn")
