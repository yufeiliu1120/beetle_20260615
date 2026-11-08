extends TextureRect
class_name status_bar
@export var hp_bar:hp_bar
@export var ap_container:ap_container
@export var title:RichTextLabel
@export var buff_container:buff_container
@export var supply_bar:supply_bar
var current_entity:CombatEntity
func _ready() -> void:
	modulate.a = 0

#根据一个战斗节点来初始化ui组件
func init_status_bar(entity:CombatEntity):
	current_entity = entity
	current_entity.hp_changed.connect(set_bars.bind(current_entity))
	if supply_bar:
		supply_bar.set_bar()
		PlayerData.supply_changed.connect(set_bars.bind(current_entity))
	current_entity.shields_changed.connect(hp_bar.set_shield.bind(current_entity))
	if current_entity and not current_entity.buff_added.is_connected(buff_container.add_slot_with_buff):
		current_entity.buff_added.connect(buff_container.add_slot_with_buff)
	#检测是否为玩家战舰，如果是敌人战舰，不显示AP组件
	if not entity.warship.is_player:
		ap_container.hide()
	
	hp_bar.set_hp_bar(entity)
	entity.ap_changed.connect(ap_container.set_ap.bind(entity))
	ap_container.set_ap(entity)
	title.text = entity.warship.ship_name
	var tween = create_tween()
	tween.parallel().tween_property(self,"modulate",Color(1.0,1.0,1.0),0.3)
	await get_tree().create_timer(0.5).timeout
	buff_container.init_buff_container(current_entity)
	
#设定数值，在物理帧中被调用
func set_bars(entity:CombatEntity):
	hp_bar.set_hp_bar(entity)
	if supply_bar:
		supply_bar.set_bar()
