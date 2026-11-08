extends Node
class_name reward_pool

signal rewards_chosen
# 在检查器中，把你所有制作好的卡牌场景（.tscn）全部塞进这个数组里
@export var all_tiles_cards: Array[PackedScene] = []
@export var tile_rewards_ui:PackedScene

var all_tiles: Dictionary = {
	"pirate": 
		{"normal": [], "rare": [], "special": []},
	"elf": 
		{"normal": [], "rare": [], "special": []},
	"shark":
		{"normal": [], "rare": [], "special": []}
}

func _ready() -> void:
	_categorize_all_cards()

# ==========================================
# 核心逻辑：自动分类整理地块卡牌
# ==========================================
func _categorize_all_cards() -> void:
	print("🗂️ 开始整理地块卡牌奖励池...")
	
	for card_scene in all_tiles_cards:
		if not card_scene:
			continue
			
		# 1. 临时实例化卡牌壳子
		var temp_card = card_scene.instantiate() as TileCard
		if not temp_card:
			if temp_card != null: temp_card.queue_free()
			continue
			
		# 2. 临时实例化地块本体，以读取深层属性[cite: 5]
		var temp_tile = temp_card.instantiate_tile()
		if not temp_tile:
			temp_card.queue_free()
			continue
			
		# 3. 获取分类依据[cite: 6]
		var t_theme = temp_tile.theme
		var t_rarity = temp_tile.rarity
		
		# 4. 安全存入字典 (存入路径字符串，与 PlayerData.card_backpack 保持格式统一)[cite: 2]
		if all_tiles.has(t_theme) and all_tiles[t_theme].has(t_rarity):
			all_tiles[t_theme][t_rarity].append(card_scene.resource_path)
		else:
			push_warning("⚠️ 卡牌分类失败，未知的 theme (%s) 或 rarity (%s): %s" % [t_theme, t_rarity, card_scene.resource_path])
			
		# 5. 内存释放：过河拆桥，销毁临时节点，保证没有任何内存泄漏
		temp_tile.queue_free()
		temp_card.queue_free()
		
	# 打印一下整理结果，方便你调试
	_print_pool_summary()

# ==========================================
# 调试助手：打印池子状态
# ==========================================
func _print_pool_summary() -> void:
	print("✅ 奖励池整理完毕！当前池内卡牌分布：")
	for theme in all_tiles.keys():
		var total_in_theme = 0
		var details = []
		for rarity in all_tiles[theme].keys():
			var count = all_tiles[theme][rarity].size()
			total_in_theme += count
			details.append("%s: %d" % [rarity, count])
		
		print("  [%s] 阵营总计 %d 张 -> %s" % [theme, total_in_theme, ", ".join(details)])


func draw_tile_card(theme: String, luck: int = 0) -> String:
	# 1. 防错校验
	if not all_tiles.has(theme):
		push_error("❌ 抽卡失败：不存在的阵营主题 - " + theme)
		return ""
		
	# 2. 动态计算概率 (权重平移法)
	# 设定：每 1 点幸运，扣除普通 1.5% 的概率，其中 1.0% 给稀有，0.5% 给特殊
	# clamp 限制普通概率最低不小于 0%
	var current_normal_chance = clampf(50.0 - (luck * 1.5), 0.0, 100.0)
	
	# 计算被挤压出来的多余概率
	var shifted_prob = 50.0 - current_normal_chance 
	
	var current_rare_chance = 30.0 + (shifted_prob * (1.0 / 1.5))
	var current_special_chance = 20.0 + (shifted_prob * (0.5 / 1.5))
	
	# 3. 掷骰子 (0.0 到 100.0 之间)
	var roll = randf_range(0.0, 100.0)
	var target_rarity = "normal"
	
	# 按照从高到低的极品顺序进行判定
	if roll <= current_special_chance:
		target_rarity = "special"
	elif roll <= current_special_chance + current_rare_chance:
		target_rarity = "rare"
		
	# 4. 从池中抽取并执行防空保底
	return _pick_card_with_fallback(theme, target_rarity)

# ==========================================
# 安全抽取与降级兜底
# ==========================================
func _pick_card_with_fallback(theme: String, desired_rarity: String) -> String:
	var pool = all_tiles[theme][desired_rarity]
	
	# 如果想要的稀有度池子里有卡，直接爽快返回！
	if pool.size() > 0:
		print("🎲 成功抽出 [%s] 阵营的 [%s] 卡牌！" % [theme, desired_rarity])
		return pool.pick_random()
		
	# 发生缺卡情况！启动降级/平替机制
	push_warning("⚠️ [%s] 的 [%s] 卡池为空，启动保底降级..." % [theme, desired_rarity])
	
	var fallback_order = []
	match desired_rarity:
		"special": fallback_order = ["rare", "normal"]
		"rare":    fallback_order = ["special", "normal"] # 稀有缺货，先尝试给极品，再降级
		"normal":  fallback_order = ["rare", "special"]   # 普通缺货，被迫给好卡
		
	for fallback_rarity in fallback_order:
		if all_tiles[theme][fallback_rarity].size() > 0:
			print("🔄 降级/平替为 [%s] 卡牌。" % fallback_rarity)
			return all_tiles[theme][fallback_rarity].pick_random()
			
	# 如果所有池子都空了（你一个卡都没配置）
	push_error("❌ 彻底失败：[%s] 阵营下没有任何卡牌！" % theme)
	return ""


func spawn_tile_reward_ui() -> void:
	# 1. 确保已在检查器中配置了奖励 UI 的场景预制体[cite: 7]
	if not tile_rewards_ui:
		push_error("❌ RewardPool 错误：未配置 tile_rewards_ui 场景！")
		return
		
	# 2. 获取当前正在运行的主场景
	var current_scene = get_tree().current_scene
	if not current_scene:
		push_error("❌ RewardPool 错误：无法获取当前场景！")
		return
		
	# 3. 寻找 CanvasLayer 以确保 UI 渲染在最上层
	var target_canvas: CanvasLayer = null
	for child in current_scene.get_children():
		if child is CanvasLayer:
			target_canvas = child
			break
			
	# 如果当前场景开发者忘记加 CanvasLayer，这里做个安全兜底，动态建一个
	if not target_canvas:
		push_warning("⚠️ 当前场景未找到 CanvasLayer，自动创建临时 CanvasLayer 作为挂载点。")
		target_canvas = CanvasLayer.new()
		current_scene.add_child(target_canvas)
		
	# 4. 实例化奖励 UI 并挂载
	var reward_ui_instance = tile_rewards_ui.instantiate() as tile_rewards_scene
	target_canvas.add_child(reward_ui_instance)
	
	# 5. 直接从 PlayerData 单例读取当前探索状态
	var amount = PlayerData.current_tile_reward_count
	var theme = PlayerData.current_advanture_theme
	var luck = PlayerData.luck
	
	# 6. 触发 UI 内部的展开与初始化逻辑
	reward_ui_instance.show_rewards(amount, theme, luck)
	print("✨ 奖励界面已呼出！发牌数量：%d | 阵营：%s | 幸运加成：%d" % [amount, theme, luck])
