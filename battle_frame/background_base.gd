extends Node2D
@export var combat_manager:Node2D


func _ready() -> void:
	combat_manager.call_deferred("init_combat_scene")
