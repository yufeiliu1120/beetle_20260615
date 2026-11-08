class_name AssemblySlotManager
extends Node2D
var slots:Dictionary = {"1*1":"res://AssemblyHub/card/card_slots/1-1.tscn"
,"1*2":"res://AssemblyHub/card/card_slots/1-2.tscn"
,"1*3":"res://AssemblyHub/card/card_slots/1-3.tscn"
,"2*1":"res://AssemblyHub/card/card_slots/2-1.tscn"
,"2*2":"res://AssemblyHub/card/card_slots/2-2.tscn"
,"2*3":"res://AssemblyHub/card/card_slots/2-3.tscn"
,"3*1":"res://AssemblyHub/card/card_slots/3-1.tscn"
,"3*2":"res://AssemblyHub/card/card_slots/3-2.tscn"
,"3*3":"res://AssemblyHub/card/card_slots/3-3.tscn"}

@export_group("资源与节点绑定")
# 【已移除 slot_scene 的导出，改为全自动单例获取】
@export var spawn_markers: Array[Marker2D] = []          
@export var slot_spawn: Marker2D                         
@export var slot_exit: Marker2D                          
@export var back_ground_animatedsprite: AnimatedSprite2D 
@export var assembly_hub: Control                        

@export_group("物理动画设置")
@export var move_duration: float = 0.5   
@export var stagger_delay: float = 0.12  

var card_counts: Dictionary = {}
var unique_card_paths: Array[String] = [] 
var active_slots: Array[Node] = []        
var current_page: int = 0
var max_pages: int = 1
var is_transitioning: bool = false        

# ==========================================
# 分页、尺寸与场景键名缓存
# ==========================================
var card_sizes: Dictionary = {}      # 缓存每个卡牌在纵向上占据的停车位数 (Y)
var card_slot_keys: Dictionary = {}  # 缓存每个卡牌对应的矿车键名 (例如 "2*1")
var pages: Array[Array] = []

func _ready() -> void:
	if assembly_hub and assembly_hub.has_signal("tile_placed_on_ship"):
		assembly_hub.tile_placed_on_ship.connect(_on_tile_placed_on_ship)
		print("✅ [SlotManager] 成功挂载地块安放监听！")

# ==========================================
# 步骤 1：同步数据并读取键名与尺寸
# ==========================================
func sync_inventory_data() -> void:
	card_counts.clear()
	unique_card_paths.clear()
	card_sizes.clear()
	card_slot_keys.clear()
	
	for card_path in PlayerData.card_backpack:
		card_counts[card_path] = card_counts.get(card_path, 0) + 1
		
	for key in card_counts:
		unique_card_paths.append(key)
		
		# 实例化卡牌以读取它所需的矿车键名
		var temp_card = load(key).instantiate()
		var slot_key: String = "1*1" # 默认兜底
		
		if temp_card.has_method("get_slot_size_key"):
			slot_key = temp_card.get_slot_size_key()
		temp_card.queue_free()
		
		# 缓存获取到的键名
		card_slot_keys[key] = slot_key
		
		# 【核心数学拆解】："纵向*横向" -> 解析出前面的纵向数字作为占用车位数
		var split_strings = slot_key.split("*")
		var vertical_size = 1
		if split_strings.size() >= 1:
			vertical_size = split_strings[0].to_int()
			
		card_sizes[key] = vertical_size
		
	# 数据汇总后，触发智能分页
	_calculate_pages()
	print("📦 [SlotManager] 库存同步完毕。种类数: %d | 总页数: %d" % [unique_card_paths.size(), max_pages])

# ==========================================
# 基于尺寸的智能分页引擎
# ==========================================
func _calculate_pages() -> void:
	pages.clear()
	var current_page_items: Array[String] = []
	var used_markers: int = 0
	var total_markers: int = spawn_markers.size()

	for path in unique_card_paths:
		var size = card_sizes[path]
		
		if used_markers + size > total_markers:
			if current_page_items.size() > 0:
				pages.append(current_page_items)
			current_page_items = [path]
			used_markers = size
		else:
			current_page_items.append(path)
			used_markers += size

	if current_page_items.size() > 0:
		pages.append(current_page_items)
		
	max_pages = max(1, pages.size())

# ==========================================
# 步骤 2：翻页触发
# ==========================================
func next_page() -> void:
	if is_transitioning or current_page >= max_pages - 1: return
	_transition_to_page(current_page + 1)

func prev_page() -> void:
	if is_transitioning or current_page <= 0: return
	_transition_to_page(current_page - 1)

func _transition_to_page(target_page: int) -> void:
	is_transitioning = true 
	
	if active_slots.size() == 0 or slot_exit == null:
		current_page = target_page
		refresh_page_display()
		is_transitioning = false
		return
		
	var total_exit_time: float = 0.0
	var slot_count: int = active_slots.size()
	
	for i in range(slot_count - 1, -1, -1):
		var slot = active_slots[i]
		if not is_instance_valid(slot): continue
			
		var reverse_order: int = (slot_count - 1) - i
		var delay: float = reverse_order * stagger_delay
		total_exit_time = max(total_exit_time, delay + move_duration)
		
		var tween = create_tween().set_parallel(true)
		tween.tween_property(slot, "global_position", slot_exit.global_position, move_duration)\
			.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN) 
		tween.tween_property(slot, "modulate:a", 0.0, 0.2)\
			.set_delay(delay + move_duration * 0.7)
			
	var master_tween = create_tween()
	master_tween.tween_interval(total_exit_time)
	master_tween.tween_callback(func():
		current_page = target_page
		refresh_page_display()
		is_transitioning = false
	)

# ==========================================
# 步骤 3：页面加载（修正为底部对齐）
# ==========================================
func refresh_page_display() -> void:
	for slot in active_slots:
		if is_instance_valid(slot):
			if assembly_hub and assembly_hub.has_method("unregister_slot"):
				assembly_hub.unregister_slot(slot)
			slot.queue_free()
	active_slots.clear()
	
	if spawn_markers.size() == 0 or pages.size() == 0:
		return
		
	var paths_to_spawn = pages[current_page]
	
	if back_ground_animatedsprite:
		back_ground_animatedsprite.play("Open")
		await back_ground_animatedsprite.animation_finished
		
	# 从最底部的车位开始
	var current_bottom_idx: int = spawn_markers.size() - 1
		
	for i in range(paths_to_spawn.size()):
		var card_path = paths_to_spawn[i]
		var count = card_counts[card_path]
		var size = card_sizes[card_path]
		var slot_key = card_slot_keys[card_path]
		
		var slot_instance = _instantiate_and_setup_slot(card_path, count, slot_key)
		slot_instance.occupy_size = size
		
		# 【核心修复】：目标直接设为当前的底部空位！
		var target_marker_index = current_bottom_idx 
		
		slot_instance.current_marker_index = target_marker_index
		var target_marker: Marker2D = spawn_markers[target_marker_index]
		
		active_slots.push_front(slot_instance)
		move_slot_to_marker(slot_instance, target_marker, i * stagger_delay)
		
		# 游标上移 size 个单位，为下一辆车留出空间
		current_bottom_idx -= size
		
	if back_ground_animatedsprite:
		var total_dispatch_time: float = ((paths_to_spawn.size() - 1) * stagger_delay) + 0.5
		var door_tween = create_tween()
		door_tween.tween_interval(total_dispatch_time)
		door_tween.tween_callback(func(): back_ground_animatedsprite.play("Close"))

# ==========================================
# 重力下滑与多格补货
# ==========================================
func _on_tile_placed_on_ship(card_path: String) -> void:
	if PlayerData.card_backpack.has(card_path):
		PlayerData.card_backpack.erase(card_path)
		
	var new_count: int = 0
	if card_counts.has(card_path):
		card_counts[card_path] = max(0, card_counts[card_path] - 1)
		new_count = card_counts[card_path]
		if new_count == 0:
			card_counts.erase(card_path)
			unique_card_paths.erase(card_path) 
			
	for i in range(active_slots.size()):
		var slot = active_slots[i]
		if is_instance_valid(slot) and "current_card_path" in slot and slot.current_card_path == card_path:
			if new_count > 0:
				if slot.has_method("update_count"):
					slot.update_count(new_count)
			else:
				print("🗑️ 矿车 [%s] 部件用光，正在移除..." % card_path)
				
				var freed_size = slot.occupy_size 
				active_slots.remove_at(i)
				
				if assembly_hub and assembly_hub.has_method("unregister_slot"):
					assembly_hub.unregister_slot(slot)
				slot.queue_free()
				
				_calculate_pages()
				
				for upper_i in range(i - 1, -1, -1):
					var upper_slot = active_slots[upper_i]
					upper_slot.current_marker_index += freed_size 
					var new_marker: Marker2D = spawn_markers[upper_slot.current_marker_index]
					
					var tween = create_tween()
					tween.tween_property(upper_slot, "global_position", new_marker.global_position, move_duration)\
						.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				
				if active_slots.size() == 0:
					if current_page >= max_pages and current_page > 0:
						current_page = max_pages - 1
					refresh_page_display()
					break
					
				var top_path = active_slots[0].current_card_path
				var next_item_index = unique_card_paths.find(top_path) + 1
				
				var space_to_fill = freed_size
				var newly_spawned = []
				
				while space_to_fill > 0 and next_item_index < unique_card_paths.size():
					var replacement_path = unique_card_paths[next_item_index]
					var replacement_size = card_sizes[replacement_path]
					
					if replacement_size <= space_to_fill:
						var rep_count = card_counts[replacement_path]
						var rep_key = card_slot_keys[replacement_path]
						
						# 用新键名实例化
						var new_slot = _instantiate_and_setup_slot(replacement_path, rep_count, rep_key)
						new_slot.occupy_size = replacement_size
						
						# ==========================================
						# 【核心修复】：顶部补货时，也瞄准腾出空间的“最底端”
						# ==========================================
						var target_index = space_to_fill - 1 
						new_slot.current_marker_index = target_index
						
						newly_spawned.append(new_slot)
						
						# 扣除消耗的空间
						space_to_fill -= replacement_size
						next_item_index += 1
					else:
						break 
						
				for new_s in newly_spawned:
					active_slots.insert(0, new_s)
					
				if newly_spawned.size() > 0 and back_ground_animatedsprite:
					back_ground_animatedsprite.play("Open")
					for j in range(newly_spawned.size()):
						var s = newly_spawned[j]
						move_slot_to_marker(s, spawn_markers[s.current_marker_index], j * stagger_delay)
						
					var door_tween = create_tween()
					door_tween.tween_interval(move_duration * 0.85)
					door_tween.tween_callback(func(): back_ground_animatedsprite.play("Close"))
					
				if current_page >= max_pages and current_page > 0:
					current_page = max_pages - 1
					
			break
# ==========================================
# 【重构：通过单例动态查询与加载场景】
# ==========================================
func _instantiate_and_setup_slot(card_path: String, count: int, slot_key: String) -> Node2D:
	# 默认安全后备路径
	var default_path: String = "res://AssemblyHub/card/card_slots/1-1.tscn"
	var target_slot_path: String = default_path
	
	# 从单例字典中提取对应尺寸的矿车场景路径
	if slots.has(slot_key):
		target_slot_path = slots[slot_key]
	else:
		push_warning("⚠️ 警告：无法在字典中找到键名 '%s' 的矿车，将使用 1*1 矿车进行兜底。" % slot_key)
		
	var target_scene = load(target_slot_path)
	var slot_instance = target_scene.instantiate()
	
	add_child(slot_instance)
	slot_instance.global_position = slot_spawn.global_position
	slot_instance.modulate.a = 0.0 
	
	if slot_instance.has_method("setup"):
		slot_instance.setup(card_path, count)
	if assembly_hub and assembly_hub.has_method("register_slot"):
		assembly_hub.register_slot(slot_instance)
		
	return slot_instance

func move_slot_to_marker(slot: Node2D, target_marker: Marker2D, delay: float = 0.0) -> void:
	if not slot or not target_marker: return
	var tween = create_tween().set_parallel(true)
	tween.tween_property(slot, "global_position", target_marker.global_position, move_duration)\
		.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, "modulate:a", 1.0, 0.2)\
		.set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
