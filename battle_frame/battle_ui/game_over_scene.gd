extends Control
class_name game_over_scene
var town:String = "res://Town_Scene/town.tscn"
@onready var panel = $TextureRect
@onready var content_container:VBoxContainer = $TextureRect/MarginContainer/VBoxContainer



func show_up():
	var tween = create_tween()
	tween.tween_property(panel,"self_modulate:a",1,1)
	tween.chain().tween_property(content_container,"modulate:a",1,0.5)


func _on_button_pressed() -> void:
	SceneManager.load_scene(town)
