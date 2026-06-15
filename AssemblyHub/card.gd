class_name TileCard
extends Control 

@export var tile_scene: PackedScene # 在检查器中，把对应的地块场景(如臼炮.tscn)拖进来

var my_card_path: String = "" # 记录自己的数据路径（由Slot赋予）

# 信号：当自己被点击时，把生成好的地块和自己的路径交出去
signal card_clicked(new_tile: TileBase, card_path: String)

func instantiate_tile() -> TileBase:
	if tile_scene != null:
		return tile_scene.instantiate() as TileBase
	return null

# 核心逻辑：卡牌自己处理点击
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		
		# ==========================================
		# 【核心防抖拦截】：检查场景中是否已经有正在拖拽的地块
		# ==========================================
		if get_tree().get_nodes_in_group("DraggingTile").size() > 0:
			# 如果有，直接无视这次点击，不生成新地块！
			return 
			
		var new_tile = instantiate_tile()
		if new_tile:
			# 【贴上标签】：刚造出来，立刻给它打上正在拖拽的专属组标签
			new_tile.add_to_group("DraggingTile") 
			
			# 发出信号
			card_clicked.emit(new_tile, my_card_path)
			
		# 拦截鼠标事件，防止穿透到下层UI
		accept_event()
