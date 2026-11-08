extends Sprite2D 
class_name PlayerMapIcon

# ==========================================
# 移动与表现参数
# ==========================================
@export var move_speed: float = 100.0         
@export var turn_duration: float = 2.5   
@export var move_shake_amplitude: float = 4.0 

@export var anim_player: AnimationPlayer # 引入你的动画播放器

# 移动状态信号
signal movement_started(target_node: Node2D, cost: int)
signal movement_finished(target_node: Node2D)

var _move_tween: Tween
var _initial_rotation: float = 0.0 # 记录初始朝向

func _ready() -> void:
	# 记录它在场景中的初始角度，确保每次回正都是完美的
	_initial_rotation = rotation
	
	if anim_player and anim_player.has_animation("Idle"):
		anim_player.play("Idle")

# ==========================================
# 核心移动逻辑 (包含动画暂停与回正震动)
# ==========================================
func move_to_node(target_node: Node2D) -> void:
	if not is_instance_valid(target_node):
		push_error("❌ 移动失败：目标节点无效！")
		return
		
	var distance: float = global_position.distance_to(target_node.global_position)
	var move_duration: float = distance / move_speed
	var supply_cost: int = ceili(distance / 50.0) 
	
	var direction = global_position.direction_to(target_node.global_position)
	var target_angle = direction.angle() - PI / 2.0 
	
	print("🚶 准备移动 -> 距离: %.1f | 耗时: %.2f | 消耗: %d" % [distance, move_duration, supply_cost])
	
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
		
	_move_tween = create_tween()
	
	# 步骤 A：暂停呼吸动画，触发扣除补给与第一次屏幕震动
	_move_tween.tween_callback(func():
		if anim_player:
			anim_player.pause() # 暂停呼吸动画，让身体保持僵直移动状态
			
		movement_started.emit(target_node, supply_cost)
		
		var camera = get_tree().get_first_node_in_group("Camera")
		if camera and camera.has_method("apply_shake"):
			# 第一次震动：转身 + 滑行
			var total_action_time = turn_duration + move_duration
			camera.apply_shake(move_shake_amplitude, total_action_time)
	)
	
	# 步骤 B：转身对准目标
	_move_tween.tween_property(self, "rotation", target_angle, turn_duration)\
		.set_trans(Tween.TRANS_SINE)
		
	# 步骤 C：朝目标节点滑行
	_move_tween.tween_property(self, "global_position", target_node.global_position, move_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
		
	# 步骤 D：抵达后，触发第二次屏幕震动以配合“回正转身”
	_move_tween.tween_callback(func():
		var camera = get_tree().get_first_node_in_group("Camera")
		if camera and camera.has_method("apply_shake"):
			# 这里的震动时长仅覆盖最后的回正时间
			camera.apply_shake(move_shake_amplitude, turn_duration)
	)
	
	# 步骤 E：转回初始待机朝向
	_move_tween.tween_property(self, "rotation", _initial_rotation, turn_duration)\
		.set_trans(Tween.TRANS_SINE)
		
	# 步骤 F：所有动作彻底完成，恢复动画并发送信号
	_move_tween.tween_callback(func():
		if anim_player:
			anim_player.play("Idle") # 重新开始呼吸动画
			
		print("✅ 成功抵达目标并回正待机！")
		movement_finished.emit(target_node)
	)
# 图标的画布大小，可以根据你战舰的实际像素尺寸调整
const ICON_SIZE = Vector2i(360, 360) 



func _generate_snapshot() -> void:
	# 1. 搭建一个虚拟的“后台摄影棚” (SubViewport)
	var viewport = SubViewport.new()
	viewport.transparent_bg = true # 背景必须透明
	viewport.size = ICON_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE # 极度节省性能：只渲染一次就停止
	add_child(viewport)
	
	# 2. 从蓝图工厂凭空召唤一艘玩家的战舰
	var player_ship = BlueprintManager.build_ship(PlayerData.player_chassis)
	viewport.add_child(player_ship)
	
	# 3. 将战舰移动到摄影棚的中心
	player_ship.position = Vector2(ICON_SIZE.x / 2.0, ICON_SIZE.y / 2.0)
	
	# 如果战舰有待机动画，确保它处于默认的初始状态
	if player_ship.has_method("play_idle"):
		player_ship.play_idle()
		
	# 4. 【核心等待】：必须等待至少两帧，让 Godot 走完新节点的初始化和渲染管线
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 5. 咔嚓！提取摄影棚画面的快照，赋值给自身的纹理
	# Godot 中 Viewport 的纹理是从底层抓取的 Image，完全等价于一张普通的 PNG 图片
	var img = viewport.get_texture().get_image()
	self.texture = ImageTexture.create_from_image(img)
	
	# 6. 过河拆桥：快照已经拿到，彻底销毁摄影棚和临时的实体战舰释放内存
	viewport.queue_free()
	
	print("📸 玩家战舰地图图标快照生成完毕！")
