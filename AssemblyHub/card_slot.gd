extends Control

@onready var card_position = $HBoxContainer/Control # 左侧用来挂载卡牌的节点
@onready var number_label = $HBoxContainer/Label    # 右侧用来显示数量的文本

var current_card_path: String = ""
var current_count: int = 0

# 信号：通知中枢有人要求拖拽地块了
signal request_drag(new_tile: TileBase, card_path: String)

# 中枢用来初始化这个槽位的方法
func setup(card_path: String, count: int) -> void:
	current_card_path = card_path
	
	# 如果还没有卡牌，就实例化一张挂上去
	if card_position.get_child_count() == 0:
		var card_instance = load(card_path).instantiate() as TileCard
		
		# 【关键】允许鼠标事件进入卡牌，让卡牌自己处理点击
		card_instance.mouse_filter = Control.MOUSE_FILTER_PASS 
		card_instance.my_card_path = current_card_path
		
		# 监听这张卡牌被点击的信号
		card_instance.card_clicked.connect(_on_card_clicked)
		
		card_position.add_child(card_instance)
		
	# 更新数量显示
	update_count(count)

func update_count(count: int) -> void:
	current_count = count
	number_label.text = "* " + str(current_count)

# 当接收到内部卡牌的点击信号时触发
func _on_card_clicked(new_tile: TileBase, card_path: String) -> void:
	# 检查余额是否充足
	if current_count > 0:
		request_drag.emit(new_tile, card_path)
