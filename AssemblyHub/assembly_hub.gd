extends Control

@export var slot_container: VBoxContainer # 指向你用来垂直排列所有Slot的容器
var grid_manager: HexGridManager 
@export var finish_button: Button

const CardSlotScene = preload("res://AssemblyHub/card_slot.tscn") # 替换为你的Slot场景路径
signal assembly_finished

var card_counts: Dictionary = {} 
var active_slots: Dictionary = {} 

func _ready() -> void:
	if finish_button:
		finish_button.pressed.connect(_on_finish_button_pressed)
	hide()

# ==========================================
# 启动拼装系统
# ==========================================
func start_assembly() -> void:
	print("🔧 AssemblyHub: 正在初始化拼装界面...")
	
	# 获取最新的网格管理器
	var ship = get_tree().get_first_node_in_group("Ships")
	if ship and "hexgridmanager" in ship:
		grid_manager = ship.hexgridmanager
		print("✅ 找到玩家战舰网格管理器")
	else:
		push_error("❌ 玩家战舰网格管理器未发现，或战舰未在 PlayerShip 分组中")
		
	show() 
	refresh_assembly_ui()
	print("✅ 拼装界面就绪，等待玩家操作。")

# ==========================================
# 【极致安全】：全量刷新 UI 表现层
# ==========================================
func refresh_assembly_ui() -> void:
	# 1. 强力清空旧 UI 节点
	for child in slot_container.get_children():
		slot_container.remove_child(child)
		child.queue_free()
		
	card_counts.clear()
	active_slots.clear()
	
	# 2. 重新扫描并统计当前的背包单例数据（单一数据源）
	for path in PlayerInventory.card_backpack:
		card_counts[path] = card_counts.get(path, 0) + 1
		
	# 3. 根据最新数据重建整个卡牌列表
	for path in card_counts:
		var slot = CardSlotScene.instantiate()
		slot_container.add_child(slot)
		slot.setup(path, card_counts[path])
		slot.request_drag.connect(_on_slot_request_drag)
		active_slots[path] = slot

# ==========================================
# 拖拽与生成
# ==========================================
func _on_slot_request_drag(new_tile: Node2D, card_path: String) -> void:
	# 1. 记录路径数据
	new_tile.data_id = card_path
	
	# 2. 生成临时模型放入世界，跟随鼠标
	get_tree().current_scene.add_child(new_tile)
	new_tile.global_position = get_global_mouse_position()
	
	# 3. 【核心修改】：不再监听状态机内部信号，直接监听地块根节点抛出的物理放置信号
	if new_tile.has_signal("tile_placed"):
		new_tile.connect("tile_placed", _on_tile_successfully_placed.bind(card_path))
	else:
		push_error("❌ 错误：生成的实体上没有发现 tile_placed 信号！")
	
	# 4. 驱动状态机去干活（拖拽）
	if new_tile.has_node("StateMachine"):
		new_tile.get_node("StateMachine").change_state("Dragging")

# ==========================================
# 核心响应：当任何地块真正“落地吸附”成功时
# ==========================================
func _on_tile_successfully_placed(card_path: String) -> void:
	print("📦 检测到地块实体成功落地！触发全量数据刷新流程。")
	
	# 1. 从单一数据源背包中扣除该卡牌
	if PlayerInventory.card_backpack.has(card_path):
		PlayerInventory.card_backpack.erase(card_path)
		print("  -> 已从 PlayerInventory 中移除: ", card_path)
	else:
		push_warning("  -> 警告：尝试扣除背包，但未找到对应的路径数据")
		
	# 2. 【数据驱动核心】：直接基于被扣除后的背包数据，把整个 UI 全毁重建！
	refresh_assembly_ui()

# ==========================================
# 完成拼装：临时纯流转逻辑
# ==========================================
func _on_finish_button_pressed() -> void:
	print("💾 玩家点击了完成拼装，开始上传图纸...")
	
	# 1. 呼叫工厂清空旧图纸
	PlayerBlueprintManager.clear_blueprint()
	
	# 2. 遍历你当前网格管理器里所有的物理挂点
	if grid_manager:
		for coords in grid_manager.grid_map:
			var mount = grid_manager.grid_map[coords]
			
			var tile = mount.get_tile() 
			if tile != null:
				# 【神仙代码】：直接读取 Godot 底层自带的场景来源路径！
				var actual_tile_path = tile.scene_file_path
				
				if actual_tile_path != "":
					# 抄写到全局单例的图纸上，存入的是纯粹的地块路径！
					PlayerBlueprintManager.save_tile(coords, actual_tile_path)
				else:
					push_error("❌ 严重错误：坐标 %s 上的地块无法获取场景路径，它可能不是通过 PackedScene 实例化的！" % str(coords))
				
	# 3. 打印蓝图进行验证
	PlayerBlueprintManager.print_blueprint()
	
	# 4. 发射信号通知场景控制器，准备切换到战斗场景
	assembly_finished.emit()
