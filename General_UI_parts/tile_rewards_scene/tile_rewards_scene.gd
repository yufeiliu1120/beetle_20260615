extends Control
class_name tile_rewards_scene

@export var card_positions:Array[Control]
@export var card_attachment_point:Control



# ==========================================
# 对外公开接口：清空面板，生成并展示新奖励
# ==========================================
func show_rewards(amount: int, theme: String, luck: int = 0) -> void:
	
	# 1. 彻底清空挂载点下残留的上一批卡牌
	for child in card_attachment_point.get_children():
		card_attachment_point.remove_child(child) # 立即从排版和逻辑树中剥离，防止冲突
		child.queue_free()                        # 标记为当前帧结束时彻底释放内存
		
	# 2. 呼叫底层的生成函数获取实例数组
	var new_cards = generate_reward_cards(amount, theme, luck)
	# 如果因为某种原因没生成出卡牌，直接中断，不播放动画
	if new_cards.is_empty():
		return
	await get_tree().process_frame
	# 3. 将数组交给 UI 表现层播放顺滑的展开动画
	_present_rewards_with_anim(new_cards)

# ==========================================
# UI 表现：发牌展开动画
# ==========================================
func _present_rewards_with_anim(cards: Array[TileCard]) -> void:
	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	for i in range(cards.size()):
		if i >= card_positions.size():
			break
			
		var card = cards[i]
		
		# 1. 先将卡牌加入场景树！
		# 这一步会立刻触发卡牌内部的 _ready()，完成所有 @onready UI节点的获取
		card_attachment_point.add_child(card)
		
		# ==========================================
		# 【核心修复】：在卡牌的 UI 节点准备就绪后，执行初始化
		# ==========================================
		set_up_card(card)
		
		# 2. 设置层级与初始位置
		card.z_index = 10 - i 
		
		var target_pos = card_positions[i].global_position
		var start_pos: Vector2
		if i < 3:
			start_pos = card_positions[0].global_position 
		else:
			start_pos = card_positions[3].global_position 
			
		card.global_position = start_pos
		card.modulate.a = 0.0
		
		# 3. 播放动画
		var order_in_col = i % 3
		var delay = order_in_col * 0.15 
		
		tw.tween_property(card, "global_position", target_pos, 0.4).set_delay(delay)
		tw.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(delay)



# ==========================================
# 核心：生成并抽取奖励卡牌实例
# ==========================================
func generate_reward_cards(amount: int, theme: String, luck: int = 0) -> Array[TileCard]:
	var result_cards: Array[TileCard] = []
	var drawn_paths: Array[String] = []
	
	# 1. 强制限制抽取数量在 1 到 6 之间
	amount = clampi(amount, 1, 6)
	
	# 2. 统计该阵营下，总共有多少张*不重复*的卡牌
	var total_unique_cards: int = 0
	if RewardPool.all_tiles.has(theme):
		var theme_pool = RewardPool.all_tiles[theme]
		for rarity in theme_pool.keys():
			total_unique_cards += theme_pool[rarity].size()
	else:
		push_error("❌ 奖励场景报错：不存在的阵营 - ", theme)
		return result_cards

	# 3. 开始循环抽取
	for i in range(amount):
		var selected_path: String = ""
		var attempts: int = 0
		var max_attempts: int = 30 # 安全锁，防止极端概率下死循环
		
		while attempts < max_attempts:
			selected_path = RewardPool.draw_tile_card(theme, luck)
			
			# 如果发生异常没抽到，直接跳出
			if selected_path == "":
				break
				
			# 【核心去重逻辑】：
			# 条件 A：这张卡之前没被抽到过
			# 条件 B：我们已经把该阵营所有不同的卡都抽了一遍了（卡池种类 < 抽取数量），此时只能允许重复
			if not drawn_paths.has(selected_path) or drawn_paths.size() >= total_unique_cards:
				break # 这是一个合法的抽取，跳出 while 循环
				
			attempts += 1
			
		# 记录这条路径，用于后续的去重比对
		if selected_path != "":
			drawn_paths.append(selected_path)
			
			# 4. 实例化这步抽到的卡牌
			var card_scene = load(selected_path) as PackedScene
			if card_scene:
				var card_instance = card_scene.instantiate() as TileCard
				# 给这张卡赋予它的专属路径，以便之后被点击时能传递给单例背包
				card_instance.my_card_path = selected_path 
				result_cards.append(card_instance)
				
	return result_cards
	
func set_up_card(card: TileCard):
	card.set_card_menu()
	card.card_menu.show()
	
	# 【核心修改】：使用 bind(card) 将这唯一的卡牌实例强行绑定进回调参数中
	if not card.card_clicked.is_connected(_on_tile_card_clicked):
		card.card_clicked.connect(_on_tile_card_clicked.bind(card))

# ==========================================
# 接收器：玩家点击奖励后的函数
# ==========================================
# 【核心修改】：在参数列表的最后，增加一个 clicked_card 来接收 bind 传过来的实例
func _on_tile_card_clicked(new_tile: TileBase, my_card_path: String, clicked_card: TileCard):
	# 1. 核心逻辑与清理
	if new_tile:
		new_tile.queue_free() # 销毁因为复用组件而意外生成的拖拽用临时地块
		
	PlayerData.card_backpack.append(my_card_path) #[cite: 1]
	print(PlayerData.card_backpack)
	print("点击了卡牌，路径为: ", my_card_path)
	
	# 2. 封锁全局点击事件 (极其重要！)
	# 防止玩家在动画播放的 0.5 秒内，利用手速同时点走两张甚至三张卡牌
	for card in card_attachment_point.get_children():
		if card is Control:
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
	# 3. 被选中卡牌的华丽谢幕：高光放大 -> 迅速缩回消失
	var clicked_tw = create_tween()
	# 第一阶段：用 0.15 秒时间猛然放大 1.15 倍，同时颜色提亮并过曝
	clicked_tw.tween_property(clicked_card, "scale", Vector2(0.65, 0.65), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	clicked_tw.parallel().tween_property(clicked_card, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.15)
	
	# 第二阶段：用 0.3 秒缩成一个点并完全透明，采用 BACK 曲线产生轻微的回弹吸入感
	clicked_tw.tween_property(clicked_card, "scale", Vector2(0.1, 0.1), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	clicked_tw.parallel().tween_property(clicked_card, "modulate:a", 0.0, 0.5)
	
# 动画终结：彻底销毁自身
	clicked_tw.tween_callback(clicked_card.queue_free)
	await get_tree().create_timer(0.3).timeout
	
	# ==========================================
	# 4. 落选卡牌的退场：越下方飞得越快
	# ==========================================
	var max_y: float = 0.0
	for c in card_attachment_point.get_children():
		if c != clicked_card and c.global_position.y > max_y:
			max_y = c.global_position.y
			
	# 【新增】：用一个变量来记录所有落选卡牌中，最长的飞行时间
	var max_fly_duration: float = 0.0 
			
	for card in card_attachment_point.get_children():
		if card != clicked_card:
			var other_tw = create_tween().set_parallel(true)
			var target_y = card.global_position.y - 800 
			
			var fly_duration: float = 0.55
			if max_y > 0:
				fly_duration = 0.55 - (card.global_position.y / max_y) * 0.3
				
			# 记录最大耗时，为最终销毁场景做准备
			if fly_duration > max_fly_duration:
				max_fly_duration = fly_duration
			
			other_tw.tween_property(card, "global_position:y", target_y, fly_duration)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				
			var fade_delay = fly_duration * 0.25
			var fade_duration = fly_duration * 0.75
			other_tw.tween_property(card, "modulate:a", 0.0, fade_duration).set_delay(fade_delay)
			
			other_tw.chain().tween_callback(card.queue_free)
	RewardPool.rewards_chosen.emit()
	# ==========================================
	# 5. 终幕：等待动画全部结束，彻底销毁奖励场景自身
	# ==========================================
	# 加上 0.1 秒的视觉缓冲时间，确保所有卡牌都已被完全清理
	await get_tree().create_timer(max_fly_duration + 0.1).timeout
	
	# 销毁整个奖励界面场景
	self.queue_free()
	print("🗑️ 奖励界面动画播放完毕，已自我销毁并释放内存。")
