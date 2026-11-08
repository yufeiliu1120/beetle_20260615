extends VBoxContainer
class_name town_confirm_box
@export var text_label: RichTextLabel
@export var confirm_button:Button
var current_building:town_building_base

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm)
	modulate.a = 0
	hide()
	
func show_box():
	show()
	var tween = create_tween()
	tween.parallel().tween_property(self,"modulate:a",1,0.5)
	
func hide_box():
	var tween = create_tween()
	tween.parallel().tween_property(self,"modulate:a",0,0.5)
	tween.tween_callback(hide)

func _on_confirm():
	if not current_building:
		return
	if not current_building.to_scene:
		return
	current_building.pressed()
	
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if visible:
				hide_box()
				current_building = null
