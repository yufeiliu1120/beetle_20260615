extends Control
class_name start_scene_ui
@export var beetle_panel:PanelContainer
@export var preview_beetle_slot:beetle_slot
@export var right_panel:beetle_info_panel
@export var current_scene:Node2D
var beetle_panel_init_position
var current_showed_panel:PanelContainer
signal current_beetle_changed(chassis:BeetleChassisData)
signal current_tile_changed

func _ready() -> void:
	preview_beetle_slot.mouse_entered.connect(_on_preview_slot_mouse_entered)
	preview_beetle_slot.mouse_exited.connect(_on_preview_slot_mouse_exited)
	beetle_panel_init_position = beetle_panel.position
	beetle_panel.call_deferred("setup")
	beetle_panel.slot_clicked.connect(_on_beetle_panel_slot_clicked)
	
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if current_showed_panel:
				hide_panel(beetle_panel,beetle_panel_init_position)

func show_panel(panel:PanelContainer,pos:int):
	if current_scene:
		current_scene.allow_to_start = false
	var tween = create_tween()
	tween.parallel().tween_property(panel,"position:y",pos,0.8)
	current_showed_panel = panel
	panel.is_showed = true

func hide_panel(panel:PanelContainer,init_position:Vector2):
	if current_scene:
		current_scene.allow_to_start = true
	var tween = create_tween()
	tween.parallel().tween_property(panel,"position:y",init_position.y,0.8)
	current_showed_panel = null
	panel.is_showed = false

func _on_preview_slot_mouse_entered():
	right_panel.setup(preview_beetle_slot)
	var tween = create_tween()
	tween.tween_property(right_panel,"position:x",0,0.2)
	
func _on_preview_slot_mouse_exited():
	var tween = create_tween()
	tween.tween_property(right_panel,"position:x",800,0.2)

func _on_beetle_panel_slot_clicked(slot:beetle_slot):
	var tween = create_tween()
	tween.tween_property(preview_beetle_slot,"scale",Vector2(1.05,1.05),0.1)
	tween.chain().tween_property(preview_beetle_slot,"scale",Vector2(1,1),0.4)
	preview_beetle_slot.set_slot_with_chassis(slot.current_chassis)
	current_beetle_changed.emit(slot.current_chassis)
	
func _on_change_beetle_pressed() -> void:
	if not beetle_panel.is_showed:
		show_panel(beetle_panel,95)
	else:
		hide_panel(beetle_panel,beetle_panel_init_position)
		
func _on_return_to_town_pressed() -> void:
	SceneManager.load_scene("res://Town_Scene/town.tscn")
