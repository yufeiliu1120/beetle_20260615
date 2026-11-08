extends StateMachine.State
var state_name = "Dragging"

@export var snap_distance: float = 10    # 靠近到多少距离时触发吸附
@export var unsnap_distance: float = 15   # 离开多少距离时脱离吸附（必须 > snap_distance）
@export var follow_speed: float = 20.0     # 平滑跟随鼠标的插值速度

var mouse_world_pos: Vector2 = Vector2.ZERO # 鼠标在3D世界中的投影坐标（需要由你的玩家控制器每帧赋值）
var current_snap_mount: HexMount = null    # 当前吸附的目标挂点
func enter():
	print("地块进入拖拽状态")
	
func do(delta):
	# ==========================================
	# 检测鼠标右键点击，随时取消拖拽
	# ==========================================
	if Input.is_action_just_pressed("mouse_right"):
		print("❌ 玩家点击右键：取消拖拽，销毁临时地块实体。背包数据未发生任何改变。")
		actor.queue_free() # 优雅销毁地块及状态机本身
		return # 直接切断后续的所有跟鼠、吸附计算，安全退场
	
	mouse_world_pos = actor.get_global_mouse_position()
	if current_snap_mount != null:
		# 状态 A：已吸附。平滑移动到挂点中心
		actor.global_position = actor.global_position.lerp(current_snap_mount.global_position, follow_speed * delta)
		# 判定脱离：测量【鼠标位置】与【挂点位置】的距离
		var dist_to_mouse = current_snap_mount.global_position.distance_to(mouse_world_pos)
		if dist_to_mouse > unsnap_distance:
			current_snap_mount = null # 距离过远，断开软吸附
		#在吸附状态下点击鼠标左键
		if Input.is_action_just_pressed("mouse_left"):
			#触发放置地块逻辑
			if current_snap_mount:
				current_snap_mount.attach_tile(actor)
			
			# 【撕下标签】：安全落地，移除组标签，解锁卡牌界面的点击！
				actor.remove_from_group("DraggingTile") 
			
				actor.tile_placed.emit()
				emit_signal("state_finished","Placed")
	else:
		# 状态 B：未吸附。平滑跟随鼠标位置
		actor.global_position = actor.global_position.lerp(mouse_world_pos, follow_speed * delta)
		
		# 判定吸附：寻找距离【当前模型位置】最近的空挂点
		var nearest_mount = _find_nearest_empty_mount()
		if nearest_mount != null:
			var dist_to_mount = actor.global_position.distance_to(nearest_mount.global_position)
			if dist_to_mount <= snap_distance:
				current_snap_mount = nearest_mount # 距离足够近，触发软吸附
	
	
func _find_nearest_empty_mount() -> HexMount:
	var nearest_mount: HexMount = null
	var min_dist = INF
	
	# 获取所有的挂点，并顺藤摸瓜拿到网格管理器
	var all_mounts = get_tree().get_nodes_in_group("HexMount")
	var grid_manager = null
	if all_mounts.size() > 0:
		grid_manager = all_mounts[0].get_parent() 
		
	if not grid_manager: return null

	for mount in all_mounts:
		# ==========================================
		# 【全新升级 1】：全域碰撞与越界预检
		# ==========================================
		var can_fit: bool = true
		var base_coord = mount.hex_coords
		
		# 尝试获取大地块的形状，如果没有则默认为单格 [Vector2i(0, 0)]
		var offsets: Array = [Vector2i.ZERO]
		if "shape_offsets" in actor:
			offsets = actor.shape_offsets
			
		for offset in offsets:
			var target_coord = base_coord + offset
			var target_mount = grid_manager.get_mount_at(target_coord)
			
			# 一票否决：如果目标坐标根本没有挂点（越界），或者挂点上已经有地块了，直接判定塞不下！
			if target_mount == null or target_mount.get_tile() != null:
				can_fit = false
				break # 跳出内层循环
				
		if not can_fit:
			continue # 形状冲突，直接跳过这个主挂点，不产生吸附引力
			
		# ==========================================
		# 【规则判定 2】：前排战术限制
		# ==========================================
		if actor.get("require_frontline") == true:
			# 这里采用宽容判定：只要玩家捏着的“主锚点”在前排，就算合法
			if not mount.is_frontline():
				continue
				
		# ==========================================
		# 距离计算：寻找最近的合法落点
		# ==========================================
		var dist = actor.global_position.distance_to(mount.global_position)
		if dist < snap_distance and dist < min_dist:
			min_dist = dist
			nearest_mount = mount
			
	return nearest_mount
