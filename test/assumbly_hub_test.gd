extends Node2D

func _ready() -> void:
	PlayerBlueprintManager.current_chassis = preload("res://resources/beetle_base/test_beetle_enemy.tres")
	var player_ship = PlayerBlueprintManager.build_ship()
	player_ship.global_position = Vector2(600,300)
	add_child.call_deferred(player_ship)
	player_ship.is_player = true
func _on_button_pressed() -> void:
	$CanvasLayer/Control.start_assembly()


func _on_button_2_pressed() -> void:
	get_tree().change_scene_to_file("res://test/test.tscn")
