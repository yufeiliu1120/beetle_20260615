extends Node2D


func _on_button_pressed() -> void:
	PlayerBlueprintManager.current_chassis = preload("res://resources/beetle_base/test_beetle_enemy.tres")
	var player_ship = PlayerBlueprintManager.build_ship()
	player_ship.global_position = Vector2(600,300)
	get_tree().root.add_child(player_ship)
	player_ship.is_player = true
	player_ship.visual_controller.set_body_color(true,Color(1,1,1,1))
	$warship2.global_position = Vector2(400,300)
	$warship2.visual_controller.build_from_chassis(load("res://resources/beetle_base/test_beetle_enemy.tres"))
	$CombatManager.start_battle()


func _on_button_2_pressed() -> void:
	$warship2.visual_controller.set_body_color(true,Color(1,1,1,1))
