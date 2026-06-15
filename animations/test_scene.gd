extends Node2D

func _ready() -> void:
	$Node2D.reset_to_sand()

func _on_button_pressed() -> void:
	$Node2D.play_starting_animation()
