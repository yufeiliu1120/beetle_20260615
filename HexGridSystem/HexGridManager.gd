class_name HexGridManager
extends Node2D

var grid_map: Dictionary = {}

# ==========================================
# 动作到地块的映射字典 (完全符合你的思路)
# Key: Resource (动作副本) -> Value: TileBase (该动作所属的地块)
# ==========================================
var action_to_tile_map: Dictionary = {}
var buff_dependency_graph: Dictionary = {}
var _applied_entity_buffs: Dictionary = {}

func excute_action_from_tile(action: ActionData, caster: CombatEntity) -> void:
	var tile = action_to_tile_map.get(action)
	if not tile:
		push_error("⚠️ 动作没有找到对应的地块映射！")
		return
		
	# ==========================================
	# 闭包状态容器，强行引用传递防止重复触发
	# ==========================================
	var exec_state = {"is_done": false} 
	
	# 定义闭包逻辑
	var apply_damage = func():
		if not exec_state.is_done:
			print("⚔️ 地块动作触发伤害/结算！对方动作标签: ", action.target_action_tags)
			action.excute(caster)
			exec_state.is_done = true
			
	# 1. 绑定地块的打击信号 (CONNECT_ONE_SHOT 保证信号最多只触发一次)
	if tile.has_signal("action_impact"):
		tile.action_impact.connect(apply_damage, CONNECT_ONE_SHOT)
		
	# 2. 触发地块基类的动画播放流程，把动作配置里的名字传进去
	if tile.has_method("play_action_animation"):
		await tile.play_action_animation(action.tile_anim_name)
	else:
		await get_tree().create_timer(0.5).timeout
		
	# 3. 动画彻底结束后退回原位，清理冗余的信号连接
	if tile.has_signal("action_impact") and tile.action_impact.is_connected(apply_damage):
		tile.action_impact.disconnect(apply_damage)
		
	# 4. 兜底判定：如果地块动画没打关键帧，动画结束时强制结算伤害
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
	# 阶段 0：战舰实体属性全量刷新 (差值追踪，防数值膨胀)
	# ==========================================
	var warship = get_parent().get_parent()
	if warship and "combatentity" in warship and warship.combatentity != null:
		var entity = warship.combatentity
		
		# 1. 【撤销】：先把上一次这套网格加的属性扣除，让实体恢复原本状态
		for prop in _applied_entity_buffs.keys():
			if prop in entity:
				entity.set(prop, entity.get(prop) - _applied_entity_buffs[prop])
				
		_applied_entity_buffs.clear()
		
		# 2. 【收集】：遍历当前场上的所有地块，重新合计属性加成
		for tile in all_tiles:
			if tile.has_method("entity_buff"):
				var buffs = tile.entity_buff()
				for prop in buffs.keys():
					if buffs[prop] != 0:
						if not _applied_entity_buffs.has(prop):
							_applied_entity_buffs[prop] = 0
						_applied_entity_buffs[prop] += buffs[prop]
						
		# 3. 【注入】：将重新算好的总增益注入战舰实体
		for prop in _applied_entity_buffs.keys():
			if prop in entity:
				entity.set(prop, entity.get(prop) + _applied_entity_buffs[prop])
				print("📈 [实体加成] 战舰 %s 属性得到了网格总加成: +%d" % [prop, _applied_entity_buffs[prop]])
				
		entity.active_shields.clear() # 先清空旧护盾
		
		# 遍历场上有效节点，如果是装甲就塞进数组
		for tile in all_tiles:
			if tile.get("provides_shield") == true:
				entity.active_shields.append(tile)
				
		print("🛡️ 护盾池已就绪，当前拥有护盾层数: ", entity.active_shields.size())
	# ==========================================
	# 阶段 1：状态重置与图纸初始化
	# ==========================================
	buff_dependency_graph.clear()
	action_to_tile_map.clear() # 每次重算前清空动作字典
	
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
				
		var neighbors = buffer_tile.get_mount().get_neighbor_tiles()
		for target_tile in neighbors:
			buff_dependency_graph[target_tile]["adjacent"].append(buffer_tile)

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
	# 阶段 4：收集最终动作，生成【动作 -> 地块】字典
	# ==========================================
	for tile in all_tiles:
		if "current_action" in tile and tile.current_action != null:
			# 直接以动作为键，地块为值存入字典
			action_to_tile_map[tile.current_action] = tile
	print("全盘状态结算完毕！已成功构建动作池，可用动作数量：", action_to_tile_map)
	
#计算一个地块的相邻效果
func calculate_tile_adjacent_buff(tile:TileBase):
	if not tile.has_adjacent_buff:
		return
	for ad_tile in tile.get_mount().get_neighbor_tiles():
		tile.Adjacent_buff(ad_tile)

#计算一个地块的全局加成	
func calculate_tile_global_buff(tile:TileBase):
	if not tile.has_global_buff:
		return
	for gl_tile in get_all_active_tiles():
		tile.global_buff(gl_tile)

# 遍历所有挂点，返回当前网格中所有已挂载的 TileBase 实体
func get_all_active_tiles() -> Array[TileBase]:
	var active_tiles: Array[TileBase] = []
	
	# 遍历所有的挂点
	for mount in get_tree().get_nodes_in_group("HexMount"):
		if mount.get_parent() == self:
			var tile = mount.get_tile()
			
			# 【核心源头过滤】：只有地块存在，且没有失效时，才把它当作有效资产！
			if tile != null and not tile.is_disabled:
				active_tiles.append(tile)
				
	return active_tiles
