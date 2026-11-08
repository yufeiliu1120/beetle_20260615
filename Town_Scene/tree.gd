extends town_building_base
class_name game_start_building


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			if mouse_is_in:
				if get_parent().has_method("start_new_game"):
					get_parent().start_new_game()
	
