class_name HexGridManager
extends Node2D

var grid_map: Dictionary = {}
@export var hex_click_radius: float = 11.0
# ==========================================
# 动作到地块的映射字典
# Key: Resource (动作副本) -> Value: TileBase (该动作所属的地块)
# ==========================================
var action_to_tile_map: Dictionary = {}
var buff_dependency_graph: Dictionary = {}
var _applied_entity_buffs: Dictionary = {}

signal calculate_start
signal tile_removed(tile:TileBase)

func excute_action_from_tile(action: ActionData, caster: CombatEntity) -> void:
	var tile = action_to_tile_map.get(action)
	if not tile:
		push_error("⚠️ 动作没有找到对应的地块映射！")
		return
		
	var exec_state = {"is_done": false} 
	
	var apply_damage = func():
		if not exec_state.is_done:
			action.excute(caster)
			exec_state.is_done = true
			
	if tile.has_signal("action_impact"):
		tile.action_impact.connect(apply_damage, CONNECT_ONE_SHOT)
		
	if tile.has_method("play_action_animation"):
		await tile.play_action_animation(action.tile_anim_name)
	else:
		await get_tree().create_timer(0.5).timeout
		
	if tile.has_signal("action_impact") and tile.action_impact.is_connected(apply_damage):
		tile.action_impact.disconnect(apply_damage)
		
	apply_damage.call()
	
func register_mount(mount: HexMount) -> void:
	grid_map[mount.hex_coords] = mount
	
func unregister_mount(coords: Vector2i) -> void:
	if grid_map.has(coords):
		grid_map.erase(coords)

func get_mount_at(coords: Vector2i) -> HexMount:
	return grid_map.get(coords, null)

func calculate_tile() -> void:
	print("开始构建地块依赖图并进行结算...")
	var all_tiles = get_all_active_tiles()
		
	# ==========================================
	# 阶段 1：状态重置与图纸初始化
	# ==========================================
	buff_dependency_graph.clear()
	
	for tile in all_tiles:
		if tile.has_method("reset_stats"):
			tile.reset_stats() 
		buff_dependency_graph[tile] = {
			"adjacent": [] as Array[TileBase],
			"global": [] as Array[TileBase]
		}
		
	# ==========================================
	# 阶段 2：扫描全局，构建依赖关系
	# ==========================================
	for buffer_tile in all_tiles:
		for target_tile in all_tiles:
			if buffer_tile != target_tile:
				buff_dependency_graph[target_tile]["global"].append(buffer_tile)		
				
		# 【核心重构】：大地块的“多核邻居扫描”
		var neighbors: Array[TileBase] = []
		# 从地块身上直接获取它覆盖的所有坐标
		var occupied_coords = buffer_tile.get_occupied_coords()
		
		for coord in occupied_coords:
			var m = get_mount_at(coord)
			if m != null:
				for neighbor_tile in m.get_neighbor_tiles():
					# 确保拿到的邻居不是自己，且没有被重复加入
					if neighbor_tile != buffer_tile and not neighbors.has(neighbor_tile):
						neighbors.append(neighbor_tile)
						
		for target_tile in neighbors:
			if buff_dependency_graph.has(target_tile):
				buff_dependency_graph[target_tile]["adjacent"].append(buffer_tile)
			else:
				print("👻 过滤掉了一个无效或已报废的相邻地块: ", target_tile)
				pass
				
	# ==========================================
	# 阶段 3：按照关系图，依次执行 Buff 逻辑
	# ==========================================
	for target_tile in all_tiles:
		var providers = buff_dependency_graph[target_tile]
		
		for global_provider in providers["global"]:
			global_provider.global_buff(target_tile)
			
		for adjacent_provider in providers["adjacent"]:
			adjacent_provider.Adjacent_buff(target_tile)
	
	# ==========================================
	# 阶段 4：收集最终动作，生成【动作 -> 地块】字典 (优化重构)
	# ==========================================
	action_to_tile_map.clear()
	
	for tile in all_tiles:
		# 经过我们刚才的修复，能进到这里的都是 is_disabled = false 的有效地块
		if is_instance_valid(tile):
			if "current_action" in tile and tile.current_action != null:
				var active_action = tile.current_action
				# 直接建立 [动作资源 -> 地块实体] 的精准映射
				action_to_tile_map[active_action] = tile

	print("全盘状态结算完毕！已成功构建动作池，可用动作数量：", action_to_tile_map.size())
	calculate_start.emit()

# 计算一个地块的相邻效果
func calculate_tile_adjacent_buff(tile:TileBase):
	if not tile.has_adjacent_buff:
		return
		
	# 【同步修复】：独立的单体邻居计算也要获取大地块完整边缘
	var neighbors: Array[TileBase] = []
	for coord in tile.get_occupied_coords():
		var m = get_mount_at(coord)
		if m != null:
			for ad_tile in m.get_neighbor_tiles():
				if ad_tile != tile and not neighbors.has(ad_tile):
					neighbors.append(ad_tile)
					
	for ad_tile in neighbors:
		tile.Adjacent_buff(ad_tile)

# 计算一个地块的全局加成	
func calculate_tile_global_buff(tile:TileBase):
	if not tile.has_global_buff:
		return
	for gl_tile in get_all_active_tiles():
		tile.global_buff(gl_tile)

# ==========================================
# 获取网格中所有已挂载的 TileBase 实体
# ==========================================
func get_all_active_tiles() -> Array[TileBase]:
	var active_tiles: Array[TileBase] = []
	
	# 遍历所有的挂点
	for mount in get_tree().get_nodes_in_group("HexMount"):
		if mount.get_parent() == self:
			var tile = mount.get_tile()
			
			# 【核心修复】：追加 not active_tiles.has(tile) 的去重机制！
			# 防止一个占据 3 格的大地块被塞进数组 3 次
			if tile != null and not tile.is_disabled and not active_tiles.has(tile):
				active_tiles.append(tile)
				
	return active_tiles
	
	
# ==========================================
# 移除指定坐标上的地块
# @param coords: 目标 Hex 坐标
# @param return_to_pool: false=彻底销毁(卖出/摧毁), true=仅从网格移除(退回手牌)
# @return: 如果是退回手牌，返回该地块实例；否则返回 null
# ==========================================
# ==========================================
# 移除指定坐标上的地块
# ==========================================
func remove_tile_at(coords: Vector2i, return_to_pool: bool = false) -> TileBase:
	var mount = get_mount_at(coords)
	if mount == null:
		return null
		
	var tile = mount.get_tile()
	if tile == null:
		return null
		
	print("🗑️ 正在移除地块: ", tile.tile_name)
	
	# 【核心修复】：无论怎么移除，先强行切断它的有效性！
	# 这样立刻执行的 calculate_tile 就会在 get_all_active_tiles 时无视它
	tile.is_disabled = true 
	
	if return_to_pool:
		var parent = tile.get_parent()
		if parent:
			parent.remove_child(tile)
	else:
		tile.queue_free()
		# 不用写 tile = null，局部变量随着函数结束就释放了
	call_deferred("calculate_tile")
	tile_removed.emit(tile)
	return tile

# ==========================================
# 核心查找逻辑：遍历挂点计算最近距离
# ==========================================
func get_mount_under_mouse(mouse_pos: Vector2) -> HexMount:
	var closest_mount: HexMount = null
	var min_dist: float = INF
	
	# 从组中获取所有的 HexMount 节点
	for mount in get_tree().get_nodes_in_group("HexMount"):
		# 计算挂点中心到鼠标当前位置的距离
		var dist = mount.global_position.distance_to(mouse_pos)
		
		# 必须落在六边形的有效点击半径内，且寻找距离最近的那个
		if dist < hex_click_radius and dist < min_dist:
			min_dist = dist
			closest_mount = mount
			
	return closest_mount
