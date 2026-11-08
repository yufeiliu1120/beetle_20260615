extends Control
class_name beetle_info_panel
@export var hp_label:Label
@export var ap_label:Label
@export var supply_label:Label
@export var action_slot_container:assumbly_action_slot_container
@export var name_label:Label

func setup(slot:beetle_slot):
	hp_label.text = tr("HP") + ":" + " " + str(slot.hp)
	ap_label.text = tr("AP") + ":" + " " + str(slot.ap)
	supply_label.text = tr("SUPPLY") + ":" + " " + str(slot.supply)
	name_label.text = slot.name_label.text
	action_slot_container.refresh_with_action_pool(slot.action_pool)
