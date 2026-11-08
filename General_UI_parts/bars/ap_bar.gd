extends HBoxContainer
class_name ap_container

@export var ap_icon_scene: PackedScene 
@export var ap_icon_red_scene: PackedScene # 新增红色 icon
@export var ap_bar: HFlowContainer
@export var label: RichTextLabel

# Key 为 TextureRect 实例，Value 为 bool (true 表示未消耗/亮起，false 表示已消耗/暗淡)
var ap_icons: Dictionary = {}

var _ap_update_token: int = 0

func set_ap(entity: CombatEntity) -> void:
	_ap_update_token += 1
	var my_token = _ap_update_token

	var new_max_ap = entity.max_ap
	var new_current_ap = entity.current_ap
	
	# --------------------------------------------------
	# 阶段 0：清理所有游离的红色 Icon
	# --------------------------------------------------
	# 在每次刷新时，把之前遗留的红色超额 AP 全部删掉，
	# 待会如果仍然超额，会在后续逻辑中重新生成，确保逻辑纯净。
	for child in ap_bar.get_children():
		if child.scene_file_path == ap_icon_red_scene.resource_path:
			ap_bar.remove_child(child)
			child.queue_free()

	if ap_icons.is_empty() and ap_bar.get_child_count() > 0:
		for child in ap_bar.get_children():
			ap_bar.remove_child(child)
			child.queue_free()
			
	var icons_array = ap_icons.keys()
	var current_max = icons_array.size()
	
	# --------------------------------------------------
	# 阶段 1：校验 max_ap（容器数量管理 - 仅限蓝色槽位）
	# --------------------------------------------------
	if new_max_ap > current_max:
		var diff = new_max_ap - current_max
		for i in range(diff):
			var icon_instance = ap_icon_scene.instantiate() as TextureRect
			ap_bar.add_child(icon_instance)
			
			ap_icons[icon_instance] = false
			var anim_player = icon_instance.get_node("AnimationPlayer") as AnimationPlayer
			anim_player.play("out")
			anim_player.seek(anim_player.current_animation_length, true)
			
	elif new_max_ap < current_max:
		var diff = current_max - new_max_ap
		for i in range(diff):
			var icon_to_remove = icons_array.pop_back()
			if is_instance_valid(icon_to_remove):
				ap_icons.erase(icon_to_remove)
				ap_bar.remove_child(icon_to_remove)
				icon_to_remove.queue_free()
				
	icons_array = ap_icons.keys()
	
	# --------------------------------------------------
	# 阶段 2：校验 current_ap（点亮蓝色槽位）
	# --------------------------------------------------
	var current_true_count = 0
	for icon in icons_array:
		if is_instance_valid(icon) and ap_icons.has(icon):
			if ap_icons[icon]:
				current_true_count += 1
			
	# 注意：对于蓝色槽位，最多只能点亮 max_ap 个
	var target_blue_ap = min(new_current_ap, new_max_ap)
			
	if target_blue_ap > current_true_count:
		var diff = target_blue_ap - current_true_count
		var changed_count = 0
		
		# 正向遍历充能蓝色
		for icon in icons_array:
			if changed_count >= diff:
				break
			if not is_instance_valid(icon) or not ap_icons.has(icon):
				continue
				
			if not ap_icons[icon]: 
				ap_icons[icon] = true
				var anim_player = icon.get_node("AnimationPlayer") as AnimationPlayer
				anim_player.play("recover")
				changed_count += 1
				await get_tree().create_timer(0.1).timeout
				
				if my_token != _ap_update_token: return
				
	elif target_blue_ap < current_true_count:
		var diff = current_true_count - target_blue_ap
		var changed_count = 0
		
		# 逆向遍历消耗蓝色
		for i in range(icons_array.size() - 1, -1, -1):
			var icon = icons_array[i]
			if changed_count >= diff:
				break
			if not is_instance_valid(icon) or not ap_icons.has(icon):
				continue
				
			if ap_icons[icon]: 
				ap_icons[icon] = false
				var anim_player = icon.get_node("AnimationPlayer") as AnimationPlayer
				anim_player.play("out")
				changed_count += 1
				await get_tree().create_timer(0.1).timeout
				
				if my_token != _ap_update_token: return
					
	# --------------------------------------------------
	# 阶段 3：超额 AP（红色 Icon 动态追加与消失动画）
	# --------------------------------------------------
	if new_current_ap > new_max_ap:
		var excess_ap = new_current_ap - new_max_ap
		
		for i in range(excess_ap):
			var red_icon = ap_icon_red_scene.instantiate() as TextureRect
			ap_bar.add_child(red_icon)
			
			var anim_player = red_icon.get_node("AnimationPlayer") as AnimationPlayer
			
			# 如果实体正在消耗 AP（本次属于扣减行为，但由于扣减前极度溢出，本次依旧溢出），
			# 需要给被扣掉的那颗红星播放 out 动画，并在播完后将其删除。
			# 判断逻辑：这是超额生成的最后一颗，且 current_ap 比上次的记录少。
			# 【注】：此处需要 entity 在外界配合追踪，但我们可以用一个巧妙的方法：
			# 因为本函数每次调用都会清除所有红色节点并重画，
			# 所以我们可以直接让红色直接播放 recover。
			# "扣除消失" 的感觉，会体现在下一次调用时，红星总数减少了。
			anim_player.play("recover")
			
			await get_tree().create_timer(0.1).timeout
			if my_token != _ap_update_token: return
					
	label.text = tr("AP:{current}/{max}".format({"current":new_current_ap,"max":new_max_ap}))
