extends Control
@export var name_label:Label
@export var _hp_bar:hp_bar


func _ready() -> void:
	modulate.a = 0



func set_ui():
	var tween = create_tween()
	tween.tween_property(self,"modulate:a",1,0.5)
	_hp_bar.set_hp_bar()
	name_label.text = PlayerData.player_chassis.ship_name
