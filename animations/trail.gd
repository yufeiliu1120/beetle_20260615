extends Line2D

@export var max_length: int = 50                # 尾迹最大允许的拐点数量
@export var min_spawn_distance: float = 10.0    # 移动多少像素产生一个新拐点（越小越平滑，但性能消耗略高）
@export var shrink_speed: float = 600.0         # 尾迹消失的速度（像素/秒，建议大于战舰正常移速）

func _ready() -> void:
	# 【核心黑魔法】：脱离父节点的相对坐标系，固定在世界原点
	# 这样我们绘制的点才能留在世界中，而不会跟着父节点一起移动
	top_level = true
	global_position = Vector2.ZERO
	global_rotation = 0.0
	clear_points()

func _process(delta: float) -> void:
	var target = get_parent()
	if target == null: return
	var target_pos = target.global_position
	# 1. 确保至少有两个点（Line2D必须有头有尾才能画出线段）
	if get_point_count() < 2:
		clear_points()
		add_point(target_pos)
		add_point(target_pos)
		
	# 2. 始终让“线头”（数组里的最后一个点）死死黏住战舰
	set_point_position(get_point_count() - 1, target_pos)
	
	# 3. 移动判定：如果线头被拉得够长，就把当前位置固定下来，并生出一个新线头
	var second_last = get_point_position(get_point_count() - 2)
	if target_pos.distance_to(second_last) > min_spawn_distance:
		add_point(target_pos)
		
	# 4. 长度限制兜底：防止点数过多
	while get_point_count() > max_length:
		remove_point(0)

	# 5. 【平滑消失逻辑】：尾巴（索引0）像燃烧的导火索一样，不断向下一个点追赶
	var distance_to_move = shrink_speed * delta
	while distance_to_move > 0.0 and get_point_count() > 1:
		var tail_pos = get_point_position(0)
		var next_pos = get_point_position(1)
		var dist = tail_pos.distance_to(next_pos)
		
		if dist <= distance_to_move:
			# 如果这一帧的缩减距离足以吃掉整段线，就删掉旧尾巴，继续吃下一段
			remove_point(0)
			distance_to_move -= dist
		else:
			# 如果吃不完，就把尾巴往前平滑地挪一点，然后结束
			set_point_position(0, tail_pos.move_toward(next_pos, distance_to_move))
			break
			
	# 兜底：如果完全静止被吃得只剩一个点了，补一个重合点，让长度归零实现完全隐形
	if get_point_count() == 1:
		add_point(get_point_position(0))
