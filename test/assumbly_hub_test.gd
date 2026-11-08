extends Node2D
class_name assumbly_hub_scene
@export var Assumbly_manager:assumbly_hub
var _action_slot = "res://action_slot/action_slot.tscn"
var player_ship:Warship
var timer:Timer
var _hovered_tile: TileBase = null
var assumbly_started:bool

@export var player_ship_resource:String = "res://resources/beetle_resources/test_beetle_player.tres"


func _ready() -> void:
	init_player_ship()
	init_UI()
	await get_tree().create_timer(0.5).timeout
	Assumbly_manager.start_assumbly()	
	assumbly_started = true

func init_player_ship():
	player_ship = BlueprintManager.build_ship(PlayerData.player_chassis)
	player_ship.scale = Vector2(2.5,2.5)
	player_ship.global_position = Vector2(960,550)
	add_child.call_deferred(player_ship)
	player_ship.combatentity.get_data_from_Player_Data()
	player_ship.is_player = true
	player_ship.animation_player.play("Idle")
	await get_tree().process_frame
	player_ship.visual_controller.show_shadow()
	
	
func init_UI():
	var ap_bar = Assumbly_manager.ap_bar
	var _hp_bar = Assumbly_manager._hp_bar
	var _supply_bar = Assumbly_manager._supply_bar
	ap_bar.set_ap(player_ship.combatentity)
	_hp_bar.set_hp_bar(player_ship.combatentity)
	_supply_bar.set_bar()
	player_ship.combatentity.ap_changed.connect(ap_bar.set_ap.bind(player_ship.combatentity))
	player_ship.combatentity.hp_changed.connect(_hp_bar.set_hp_bar.bind(player_ship.combatentity))
	PlayerData.supply_changed.connect(_supply_bar.set_bar)
	Assumbly_manager.tile_changed.connect(_on_tile_changed)

func _on_tile_changed():
	player_ship.combatentity.init_action_pool(player_ship.hexgridmanager)
	Assumbly_manager.action_slot_container.refresh_with_action_pool(player_ship.combatentity.action_pool)
			

func _on_page_button_pressed() -> void:
	Assumbly_manager.next_page()


func _on_prev_button_pressed() -> void:
	Assumbly_manager.prev_page()
	
func _unhandled_input(event: InputEvent) -> void:
	if not assumbly_started:
		return
	# ==========================================
	# 交互 1：鼠标移动，处理悬停发亮 (性能极低消耗：只在鼠标移动时计算)
	# ==========================================
	if event is InputEventMouseMotion:
		var mouse_pos = get_global_mouse_position()
		var target_mount = player_ship.hexgridmanager.get_mount_under_mouse(mouse_pos)
		
		# 安全获取当前鼠标下的地块
		var target_tile: TileBase = null
		if target_mount != null:
			target_tile = target_mount.get_tile()
			
		# 【防抖核心】：只有当鼠标跨越到不同的地块（或空白处）时，才触发动画
		if target_tile != _hovered_tile:
			# 1. 恢复旧地块
			if is_instance_valid(_hovered_tile) and not _hovered_tile.is_disabled:
				_hovered_tile.smooth_restore()
				
			# 2. 点亮新地块
			if is_instance_valid(target_tile) and not target_tile.is_disabled:
				target_tile.smooth_brighten()
				
			# 3. 更新缓存记录
			_hovered_tile = target_tile

	# ==========================================
	# 交互 2：鼠标中键按下，移除地块
	# ==========================================
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
		var mouse_pos = get_global_mouse_position()
		var target_mount = player_ship.hexgridmanager.get_mount_under_mouse(mouse_pos)
		
		if target_mount != null and target_mount.get_tile() != null:
			print("🖱️ 鼠标中键命中，执行地块移除！")
			
			var tile_to_remove = target_mount.get_tile()
			
			# 【关键防错】：如果被删除的正好是当前发亮的地块，必须清空悬停指针
			# 否则鼠标移开时，系统会尝试对一个已被 queue_free 的节点执行 restore，导致报错
			if tile_to_remove == _hovered_tile:
				_hovered_tile = null
				
			player_ship.hexgridmanager.remove_tile_at(target_mount.hex_coords, false)
			
			
