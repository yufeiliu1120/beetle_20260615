extends Node2D

@onready var card_position = $Marker2D # 用来挂载卡牌（部件图标）的父节点
@onready var number_label = $Label    # 用来显示部件剩余数量的文本
@export var occupy_size: int = 1
# 【新增】：记录当前停泊的车位索引（顶部为0，越往下越大）
var current_marker_index: int = 0
var current_card_path: String = ""
var current_count: int = 0
var is_disabled: bool = false         # 数量归零时标记为禁用状态

# 信号：通知中枢有人要求拖拽地块了
signal request_drag(new_tile: TileBase, card_path: String)

# ==========================================
# 中枢用它来注入或刷新槽位数据
# ==========================================
func setup(card_path: String, count: int) -> void:
	current_card_path = card_path
	
	# 如果还没有卡牌实例，就实例化一张挂上去
	if card_position.get_child_count() == 0:
		var card_instance = load(card_path).instantiate() as TileCard
		
		# 【关键】允许鼠标事件进入卡牌，让卡牌自己处理点击
		card_instance.mouse_filter = Control.MOUSE_FILTER_PASS 
		card_instance.my_card_path = current_card_path
		
		# 监听这张卡牌被点击的信号
		card_instance.card_clicked.connect(_on_card_clicked)
		card_position.add_child(card_instance)
	else:
		# 如果已经有卡牌了，检查是否换了种类（针对动态刷新的容错）
		var existing_card = card_position.get_child(0) as TileCard
		if existing_card.my_card_path != card_path:
			clear_slot()
			setup(card_path, count)
			return
		
	# 更新数量与视觉状态
	update_count(count)

# ==========================================
# 更新数量与可用状态表现
# ==========================================
func update_count(count: int) -> void:
	current_count = count
	if number_label:
		number_label.text = str(current_count)
		number_label.show()
	
	# 【修改】：耗尽时不再设为灰色半透明，仅禁用交互，等待中枢来将自己销毁
	if current_count <= 0:
		is_disabled = true
	else:
		is_disabled = false
		modulate = Color(1.0, 1.0, 1.0, 1.0)

# ==========================================
# 【新增】：当这个槽位没有分配到卡牌时，清空自毁逻辑
# ==========================================
func clear_slot() -> void:
	current_card_path = ""
	current_count = 0
	is_disabled = true
	
	# 销毁内部挂载的卡牌图标
	for child in card_position.get_children():
		card_position.remove_child(child)
		child.queue_free()
		
	# 隐藏数量标签，恢复默认透明度
	if number_label:
		number_label.text = ""
		number_label.hide()
	modulate = Color(1.0, 1.0, 1.0, 1.0)

# ==========================================
# 核心点击处理
# ==========================================
func _on_card_clicked(new_tile: TileBase, card_path: String) -> void:
	# 只有在没有被禁用且余额大于0时，才允许向工厂发车（拖拽）
	if not is_disabled and current_count > 0:
		request_drag.emit(new_tile, card_path)
	else:
		# 如果用光了，把刚生成的临时地块立刻销毁，防止留存在空空中
		if new_tile and is_instance_valid(new_tile):
			new_tile.queue_free()
		print("⚠️ 该部件库存已耗尽，无法继续生成！")
