class_name HexMount
extends Node2D

@export var hex_coords: Vector2i = Vector2i.ZERO
signal tile_placed()
# 存储相邻的“挂点”节点（无论上面有没有地块）
var neighbor_mounts: Array[HexMount] = []
var label:Label
const HEX_DIRECTIONS = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]

func _ready() -> void:
	var parent = get_parent()
	if parent is HexGridManager:
		parent.register_mount(self)
		tile_placed.connect(parent.calculate_tile)
	call_deferred("find_neighbor_mounts")
	add_to_group("HexMount")
	if get_child(0) and get_child(0) is TileBase:
		attach_tile(get_child(0))
		tile_placed.emit()
		
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
# 新增功能：地块实体交互逻辑
# ==========================================

# 1. 获取当前挂点上的地块实体
func get_tile() -> TileBase:
	for child in get_children():
		if child is TileBase:
			return child
	return null # 如果挂点是空的，返回 null

# 2. 获取所有“拥有地块”的相邻挂点
func get_occupied_neighbor_mounts() -> Array[HexMount]:
	var valid_mounts: Array[HexMount] = []
	for mount in neighbor_mounts:
		if mount.get_tile() != null:
			valid_mounts.append(mount)
	return valid_mounts

# 3. 直接获取相邻的“地块实体”列表（通常这是实际拼装逻辑最需要的）
func get_neighbor_tiles() -> Array[TileBase]:
	find_neighbor_mounts()
	var tiles: Array[TileBase] = []
	for mount in neighbor_mounts:
		var tile = mount.get_tile()
		if tile != null:
			tiles.append(tile)
	return tiles
	
# 将一个外部的地块实体挂载到当前挂点上
func attach_tile(tile: TileBase) -> bool:
	if tile == null:
		push_warning("尝试挂载的地块为空！")
		return false
	# 安全检查：如果当前挂点已经有地块了，则拒绝挂载（你可以根据需求修改为替换逻辑）
	if get_tile() != null:
		push_warning("坐标 ", hex_coords, " 的挂点已被占用，无法挂载新地块！")
		return false
	var current_parent = tile.get_parent()
	if current_parent == self:
		# 情况 1：已经在自己下面了，什么都不用做
		pass
	elif current_parent == null:
		# 情况 2：这是单例造船厂刚刚 instantiate() 出来的孤儿节点，直接收养
		add_child(tile)
	else:
		# 情况 3：这是从拼装界面世界场景里拖过来的，安全剥离并转移抚养权
		tile.reparent(self)
	# 确保地块的局部坐标和旋转归零，完美对齐到挂点中心
	# 注：如果你使用的是 2D 项目，请将 Vector3 改为 Vector2
	tile.position = Vector2.ZERO
	tile_placed.emit()
	# 可以在这里触发一些“拼装成功”的逻辑，比如播放音效或更新相邻地块状态
	# _on_tile_attached() 
	
	return true

#检测地块是否在最左侧
func is_frontline() -> bool:
	var parent = get_parent()
	if parent is HexGridManager:
		# 检查正左方 Vector2i(-1, 0) 是否有挂点
		var left_coords = hex_coords + Vector2i(-1, 0)
		
		# 如果左边没有挂点，说明我就是最左侧的前排！
		return parent.get_mount_at(left_coords) == null
		
	return false
