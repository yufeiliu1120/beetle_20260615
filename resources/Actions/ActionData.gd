class_name ActionData
extends Resource

var source_tile = null
@export var tags:Array[String] = []
@export var action_name: String = "新动作"
@export var action_icon: Texture2D 
@export_multiline var description: String = ""
@export var ap_cost: int = 1
@export var base_cooldown: int = 0
@export var ship_anim_name: String = ""
@export var tile_anim_name: String = ""
#用于储存敌方对应动作的标签，被resolver添加内容
var target_action_tags:Array[String]
func excute(caster:CombatEntity):
	pass
	
func get_tags_from_action_data(action_data:ActionData):
	return action_data.tags

func refresh_target_action_tags():
	target_action_tags = []
