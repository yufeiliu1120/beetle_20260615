class_name TileBase
extends Node2D

signal action_animation_finished #用来控制动作动画的完成的信号
signal tile_placed #放置地块时触发的信号
signal action_impact

# 可以在这里定义地块的通用属性（如类型、生命值、重量等）
@export var tile_name: String = "默认地块"
@export var base_action: ActionData
@export var data_id: String
@export_multiline var description: String = ""
@export var tile_anim_player: AnimationPlayer
@export_enum("pirate","elf","shark") var theme: String
@export_enum("normal","rare","special") var rarity: String

# ==========================================
# 【新增】：大地块形状与占用定义
# 存储地块占用的相对六边形坐标。默认只包含原点 Vector2i(0, 0)。
# ==========================================
@export var shape_offsets: Array[Vector2i] = [Vector2i.ZERO]

# 地块会为战舰本体提供的属性
@export var entity_buffs: Dictionary = {
	"max_hp": 0,
	"max_ap": 0,
	"max_supply":0
}

@export var require_frontline: bool = false
@export var provides_shield: bool = false
@export var breaks_on_block: bool = true

var current_action: Resource
var is_disabled: bool = false

# 声明一个全局变量来追踪当前正在运行的颜色 Tween
var _color_tween: Tween

# 反向获取它所在的挂点（这是它的核心锚点挂点）
func get_mount() -> HexMount:
	var parent = get_parent()
	if parent is HexMount:
		return parent
	return null
	
# ==========================================
# 【新增】：获取该大地块在网格上实际盖住的所有绝对坐标
# ==========================================
func get_occupied_coords() -> Array[Vector2i]:
	var occupied_coords: Array[Vector2i] = []
	var anchor_mount = get_mount()
	if anchor_mount != null:
		var base_coord = anchor_mount.hex_coords
		for offset in shape_offsets:
			occupied_coords.append(base_coord + offset)
	return occupied_coords

# 被子节点重写的函数，重置加成使用的函数
func reset_stats():
	if is_disabled:
		current_action = null # 失效时，不提供任何动作副本
		return
		
	if base_action != null:
		current_action = base_action.duplicate(true)
		for effect in current_action.action_effects:
			effect.count_bonus = 0
	else:
		current_action = null
			
# 用于找到战舰根节点的函数
func get_warship_root() -> Warship:
	var current_node = self
	while current_node != null:
		if current_node.is_in_group("Ships"):
			return current_node as Warship
		current_node = current_node.get_parent()
	return null
	
# 用于找到战舰的动画播放器的函数
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
	
# 打击帧触发，允许在某一帧触发动作效果
func trigger_impact() -> void:
	print("⚡ 地块专属动画触发了打击点！")
	action_impact.emit()

# 用来处理相邻加成，参数为被影响的地块
func Adjacent_buff(tile):
	pass
	
# 用来处理全局加成，参数为被影响的地块
func global_buff(tile):
	pass
	
# 直接影响战舰本体的函数
func entity_buff() -> Dictionary:
	return entity_buffs

# ==========================================
# 动画播放接口
# ==========================================
func play_action_animation(anim_name: String) -> void:
	if anim_name == "":
		await get_tree().create_timer(0.2).timeout
		return
		
	if tile_anim_player and tile_anim_player.has_animation(anim_name):
		print("🎬 地块开始播放动画: ", anim_name)
		tile_anim_player.play(anim_name)
		await tile_anim_player.animation_finished
	else:
		push_warning("⚠️ 地块未绑定 AnimationPlayer，或未找到动画: " + anim_name)
		await get_tree().create_timer(0.5).timeout
		
func deactivate_tile(should_calculate: bool = true) -> void:
	if is_disabled: return
	
	is_disabled = true
	print("❌ 地块 [%s] 失效！" % tile_name)
	
	if not should_calculate:
		return 
		
	var grid_manager = get_parent()
	while grid_manager != null and not grid_manager is HexGridManager:
		grid_manager = grid_manager.get_parent()
		
	if grid_manager:
		grid_manager.calculate_tile()
		
func apply_shake(amplitude: float, duration: float) -> void:
	var camera = get_tree().get_first_node_in_group("Camera") as custom_camera
	if not camera:
		push_warning("地块晃动摄像头，但未找到摄像头节点")
		return
	camera.apply_shake(amplitude,duration)
	
# ==========================================
# 提亮与复原动画
# ==========================================
func smooth_brighten(duration: float = 0.2) -> void:
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	_color_tween = create_tween()
	var bright_color = Color(2.0, 2.0, 2.0, 1.0)
	_color_tween.tween_property(self, "modulate", bright_color, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func smooth_restore(duration: float = 0.2) -> void:
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	_color_tween = create_tween()
	var normal_color = Color(1.0, 1.0, 1.0, 1.0)
	_color_tween.tween_property(self, "modulate", normal_color, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
