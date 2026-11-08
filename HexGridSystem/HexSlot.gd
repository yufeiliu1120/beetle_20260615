class_name HexMount
extends Node2D

@export var hex_coords: Vector2i = Vector2i.ZERO
signal tile_placed()

# 存储相邻的“挂点”节点（无论上面有没有地块）
var neighbor_mounts: Array[HexMount] = []
var label: Label

const HEX_DIRECTIONS = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]

# ==========================================
# 【核心新增】：占用指针
# 无论地块是不是当前挂点的子节点，只要物理上盖在这个挂点上，指针就会指向该地块。
# ==========================================
var occupied_by: TileBase = null

func _ready() -> void:
	var parent = get_parent()
	if parent is HexGridManager:
		parent.register_mount(self)
		if not tile_placed.is_connected(parent.calculate_tile):
			tile_placed.connect(parent.calculate_tile)
	call_deferred("find_neighbor_mounts")
	add_to_group("HexMount")
	
	# 【修改】：延迟一帧处理初始子节点。
	# 因为大地块需要跨挂点注册占用，必须等网格管理器把所有挂点都登记完毕再执行。
	call_deferred("_check_initial_child")
		
func _check_initial_child() -> void:
	for child in get_children():
		if child is TileBase:
			attach_tile(child)
			break

func find_neighbor_mounts() -> void:
	neighbor_mounts.clear()
	var parent = get_parent()
	if not parent is HexGridManager: return

	for dir in HEX_DIRECTIONS:
		var target_coords = hex_coords + dir
		var neighbor = parent.get_mount_at(target_coords)
		
		if neighbor != null:
			neighbor_mounts.append(neighbor)
			if self not in neighbor.neighbor_mounts:
				neighbor.neighbor_mounts.append(self)

func _exit_tree() -> void:
	var parent = get_parent()
	if parent is HexGridManager:
		parent.unregister_mount(hex_coords)
	for neighbor in neighbor_mounts:
		if is_instance_valid(neighbor):
			neighbor.neighbor_mounts.erase(self)

# ==========================================
# 新增与重构：地块实体交互逻辑
# ==========================================

# 1. 【重构】：不再查子节点，而是直接返回占用指针
func get_tile() -> TileBase:
	if is_instance_valid(occupied_by):
		return occupied_by
	return null

# 2. 获取所有“被其他地块占用”的相邻挂点（排除被我自己这个大地块占用的部分）
func get_occupied_neighbor_mounts() -> Array[HexMount]:
	var valid_mounts: Array[HexMount] = []
	for mount in neighbor_mounts:
		var tile = mount.get_tile()
		if tile != null and tile != self.occupied_by:
			valid_mounts.append(mount)
	return valid_mounts

# 3. 【重构】：直接获取相邻的“地块实体”列表（自动去重，自动排除自身）
func get_neighbor_tiles() -> Array[TileBase]:
	var tiles: Array[TileBase] = []
	for mount in neighbor_mounts:
		var tile = mount.get_tile()
		
		# 规则 A: 挂点上有地块
		# 规则 B: 这个地块不能是我自己（防止大地块把自己的另一截当成邻居）
		# 规则 C: 这个地块还没有被加入过数组（防止一个大地块占据了两个相邻挂点被计算两次）
		if tile != null and tile != self.occupied_by and not tiles.has(tile):
			tiles.append(tile)
	return tiles
	
# 4. 【重构】：将一个外部的地块实体挂载，并向所有覆盖的挂点广播占用权
func attach_tile(tile: TileBase) -> bool:
	if tile == null:
		push_warning("尝试挂载的地块为空！")
		return false
		
	# 注意：这里的合法性判定（能不能放得下）将由 Dragging 状态机提前确认，
	# 只要调了 attach_tile，就默认是强行装载。
	
	var current_parent = tile.get_parent()
	if current_parent != self:
		if current_parent == null:
			add_child(tile)
		else:
			tile.reparent(self)
			
	tile.position = Vector2.ZERO
	# 【核心广播】：通知网格管理器，把我盖住的所有格子全部打上我的标签
	var grid_manager = get_parent()
	if grid_manager is HexGridManager:
		var coords_list = tile.get_occupied_coords()
		for coord in coords_list:
			var m = grid_manager.get_mount_at(coord)
			if m != null:
				m.occupied_by = tile
				
	# 监听该地块的销毁/移除事件，以便在它碎裂或被卖掉时，自动清理那些挂点的占用状态
	if not tile.tree_exiting.is_connected(_on_tile_removing.bind(tile)):
		tile.tree_exiting.connect(_on_tile_removing.bind(tile))
		
	tile_placed.emit()
	return true

# 5. 【新增】：自动清理占用逻辑
func _on_tile_removing(tile: TileBase) -> void:
	var grid_manager = get_parent()
	if grid_manager is HexGridManager:
		# 用地块身上残存的坐标信息，顺藤摸瓜把相关的挂点全部清空
		var coords_list = tile.get_occupied_coords()
		for coord in coords_list:
			var m = grid_manager.get_mount_at(coord)
			# 确保只有当前占用者是这个地块时才清空（防止被新地块顶替后误删）
			if m != null and m.occupied_by == tile:
				m.occupied_by = null

# 检测地块是否在最左侧
func is_frontline() -> bool:
	var parent = get_parent()
	if parent is HexGridManager:
		var left_coords = hex_coords + Vector2i(-1, 0)
		return parent.get_mount_at(left_coords) == null
		
	return false
