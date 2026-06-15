extends Node2D

func _ready() -> void:
	PlayerBlueprintManager.player_base_ship = load("res://warship_parts/warship_base.tscn")

func _on_button_pressed() -> void:
	$CanvasLayer/Control.start_assembly()


func _on_button_2_pressed() -> void:
	get_tree().change_scene_to_file("res://test/test.tscn")
