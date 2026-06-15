class_name TileBase
extends Node2D
signal action_animation_finished #用来控制动作动画的完成的信号
signal tile_placed #放置地块时触发的信号
signal action_impact
# 可以在这里定义地块的通用属性（如类型、生命值、重量等）
@export var tile_name: String = "默认地块"
@export var base_action:ActionData
@export var data_id:String
@export var tile_anim_player:AnimationPlayer

#地块会为战舰本体提供的属性
@export var entity_buffs: Dictionary = {
	"max_hp": 0,
	"max_ap": 0
}

@export var require_frontline: bool = false
@export var provides_shield: bool = false
@export var breaks_on_block: bool = true
var current_action: Resource
var is_disabled: bool = false
# 反向获取它所在的挂点（方便在地块逻辑中查询坐标）
func get_mount() -> HexMount:
	var parent = get_parent()
	if parent is HexMount:
		return parent
	return null
	
	
#被子节点重写的函数，
#重置加成使用的函数
func reset_stats():
	if is_disabled:
		current_action = null # 失效时，不提供任何动作副本
		return
		
	if base_action != null:
		current_action = base_action.duplicate(true)
	else:
		current_action = null
			
#用于找到战舰根节点的函数
func get_warship_root() -> Warship:
	var current_node = self
	
	# 不断向上找，直到撞到场景树的顶部 (null)
	while current_node != null:
		# 检查当前节点是否在 "Ships" 分组中
		if current_node.is_in_group("Ships"):
			return current_node as Warship
		# 没找到，就获取父节点继续往上查
		current_node = current_node.get_parent()
		
	return null
	
#用于找到战舰的动画播放器的函数
func get_animation_player() -> AnimationPlayer:
	var warship = get_warship_root()
	if not warship:
		push_warning("未找到战舰根节点，动画不会播放")
		return null
	if warship.visual_controller and "animation_player" in warship.visual_controller:
		return warship.visual_controller.animation_player
	else:
		push_warning("未找到战舰的动画播放器，动画不会播放")
		return null
	
#打击帧触发，允许在某一帧触发动作效果
func trigger_impact() -> void:
	print("⚡ 地块专属动画触发了打击点！")
	action_impact.emit()

#用来处理相邻加成，参数为被影响的地块
func Adjacent_buff(tile):
	pass
	
#用力处理全局加成，参数为被影响的地块
func global_buff(tile):
	pass
	
#直接影响战舰本体的函数
func entity_buff() -> Dictionary:
	return entity_buffs
# ==========================================
# 动画播放接口（这个函数由基类彻底包揽，具体的火炮、激光塔脚本里千万不要重写它！）
# ==========================================
func play_action_animation(anim_name: String) -> void:
	if anim_name == "":
		# 如果这个动作没配动画名，直接跳过，防止卡死
		await get_tree().create_timer(0.2).timeout
		return
		
	if tile_anim_player and tile_anim_player.has_animation(anim_name):
		print("🎬 地块开始播放动画: ", anim_name)
		tile_anim_player.play(anim_name)
		
		# 【核心】：基类在这里统一 await！你以后配置任何新地块，都再也不怕忘了写这句了！
		await tile_anim_player.animation_finished
	else:
		push_warning("⚠️ 地块未绑定 AnimationPlayer，或未找到动画: " + anim_name)
		await get_tree().create_timer(0.5).timeout
		
func deactivate_tile(should_calculate: bool = true) -> void:
	if is_disabled: return
	
	is_disabled = true
	print("❌ 地块 [%s] 失效！" % tile_name)
	
	# 如果不要求立刻重算，就此打住，仅仅改变状态和视觉表现
	if not should_calculate:
		return 
		
	# 原本的呼叫逻辑
	var grid_manager = get_parent()
	while grid_manager != null and not grid_manager is HexGridManager:
		grid_manager = grid_manager.get_parent()
		
	if grid_manager:
		grid_manager.calculate_tile()
		
func shake_camera(x:float):
	var camera = get_tree().get_first_node_in_group("Camera") as custom_camera
	if not camera:
		push_warning("地块晃动摄像头，但未找到摄像头节点")
		return
	camera.add_trauma(x)
