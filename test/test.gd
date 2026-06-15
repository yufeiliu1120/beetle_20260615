extends Node2D


func _on_button_pressed() -> void:
	PlayerBlueprintManager.player_base_ship = load("res://animations/test_beetle_3.tscn")
	var player_ship = PlayerBlueprintManager.build_ship()
	player_ship.global_position = Vector2(600,300)
	get_tree().root.add_child(player_ship)
	$warship2.global_position = Vector2(400,300)
	$CombatManager.start_battle()
