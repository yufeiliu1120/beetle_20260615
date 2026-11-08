extends Control
class_name ui_tile_card_slot
@export var card_position:Control

func set_up_slot_with_card(card_path: String) -> void:
	# 1. 安全起见，先清理卡槽中可能残留的旧卡牌
	for child in card_position.get_children():
		child.queue_free()
		
	# 2. 根据路径加载并实例化卡牌场景
	var card_scene = load(card_path) as PackedScene
	if not card_scene:
		push_error("❌ 无法加载卡牌场景，路径错误: " + card_path)
		return
		
	var card:TileCard = card_scene.instantiate()
	card.my_card_path = card_path
	# 3. 将其挂载到指定的 position 节点上
	card_position.add_child(card)
	
	# 4. 强制重置坐标为 (0,0)
	card.position = Vector2.ZERO
	
	# 5. 尺寸判定与等比缩放保护
	if card is TileCard:
		# 【保险设置】：允许 Control 缩放，并保证纹理始终保持原始比例
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		
		# 检测 Y 轴是否超标
		if card.size.y > 252.0:
			# 计算等比缩放的比例系数
			var scale_ratio = 252.0 / card.size.y
			
			# 将 X 轴和 Y 轴按比例缩小，强制 Y 轴等于 192.0
			var new_size = Vector2(card.size.x * scale_ratio, 252.0)
			
			card.size = new_size
			# 如果你的 card_position 是 Container 的子类，最好同步修改最小尺寸防止被父级撑大
			card.custom_minimum_size = new_size
	card.set_card_menu()
	card.card_menu.show()
	card.play_explore_fold_anim(false)
