extends Control
class_name beetles_menu
var slot_path:String = "res://General_UI_parts/beetles_menu/beetle_slot.tscn"
@export var slot_container:HFlowContainer
@export var right_panel:Control
@export var cancel_button:Button
@export var breede_button:Button
@export var beetle_confirm_box:VBoxContainer
@export var name_confirm_box:VBoxContainer
var selected_slots:Array = []

# 定义玩家甲虫数据所在的固定文件夹路径
const PLAYER_BEETLE_DIR = "res://resources/beetle_resources/player_beetle/"
signal canceled
signal slot_clicked(slot:beetle_slot)
signal breede
signal sell_it
signal name_it
signal name_confirm(text:String)
signal return_to_town


func _ready() -> void:
	call_deferred("set_up_menu")
	await get_tree().create_timer(0.5).timeout
	init_panel()
	beetle_confirm_box.hide()
	name_confirm_box.hide()


#甲虫诞生时的选项按钮，和选择命名后的的界面
#======================================================================================================
func show_beetle_confirm_box():
	beetle_confirm_box.modulate.a = 0
	beetle_confirm_box.show()
	var tween = create_tween()
	tween.tween_property(beetle_confirm_box,"modulate:a",1,0.5)
	
func show_name_confirm_box():
	name_confirm_box.modulate.a = 0
	name_confirm_box.show()
	var tween = create_tween()
	tween.tween_property(name_confirm_box,"modulate:a",1,0.5)
	
func hide_beetle_confirm_box():
	var tween = create_tween()
	tween.tween_property(beetle_confirm_box,"modulate:a",0,0.5)
	tween.tween_callback(beetle_confirm_box.hide)
	
func hide_name_confirm_box():
	var tween = create_tween()
	tween.tween_property(name_confirm_box,"modulate:a",0,0.5)
	tween.tween_callback(name_confirm_box.hide)
	
#======================================================================================================


func init_panel():
	var tween = create_tween()
	tween.tween_property($PanelContainer,"position:y",15,0.5)
	tween.chain().tween_property($PanelContainer,"position:y",1.0,0.1)
	$Timer.start()

func fold_panel():
	var tween = create_tween()
	tween.tween_property($PanelContainer,"position:y",-460,0.3)
	$Timer.stop()
	
func set_up_menu():
	var beetle_array = load_all_player_beetles()
	for slot in slot_container.get_children():
		slot_container.remove_child(slot)
		slot.queue_free()
	for chassis in beetle_array:
		var slot = load(slot_path).instantiate()
		slot_container.add_child(slot)
		slot.slot_mouse_entered.connect(_on_slot_mouse_entered)
		slot.slot_mouse_exited.connect(_on_slot_mouse_exited)
		slot.slot_clicked.connect(_on_slot_clicked)
		if slot.has_method("set_slot_with_chassis"):
			slot.set_slot_with_chassis(chassis)
		else:
			push_error("甲虫卡牌设置失败")

# ==========================================
# 提取指定文件夹下的所有甲虫资源并按时间降序(最新在前)返回
# ==========================================
func load_all_player_beetles() -> Array[BeetleChassisData]:
	var temp_sort_array: Array = [] 
	var dir = DirAccess.open(PLAYER_BEETLE_DIR)
	
	if dir:
		var files = dir.get_files()
		
		for file_name in files:
			var clean_name = file_name.replace(".remap", "")
			
			if clean_name.ends_with(".tres") or clean_name.ends_with(".res"):
				var file_path = PLAYER_BEETLE_DIR + "/" + clean_name
				var resource = load(file_path)
				
				if resource is BeetleChassisData:
					# 获取操作系统的文件修改时间戳
					var file_time = FileAccess.get_modified_time(file_path)
					
					# 将资源和时间戳打包存入临时数组
					temp_sort_array.append({
						"data": resource,
						"time": file_time
					})
					
		# 使用 sort_custom 进行降序排列（a["time"] > b["time"] 意味着时间越晚、越新的排在前面）
		temp_sort_array.sort_custom(func(a, b): return a["time"] > b["time"])
		
		# 提取排序后的纯净数据
		var sorted_beetle_array: Array[BeetleChassisData] = []
		for item in temp_sort_array:
			sorted_beetle_array.append(item["data"])
			
		return sorted_beetle_array
		
	else:
		push_error("⚠️ 无法访问指定的甲虫文件夹路径: " + PLAYER_BEETLE_DIR)
		return []


func animate_right_panel(slot = null,open:bool = true):
	var tween = create_tween()
	if open:
		tween.parallel().tween_property(right_panel,"position:x",-30,0.2)
		tween.chain().tween_property(right_panel,"position:x",0,0.1)
		if slot:
			right_panel.setup(slot)
	else:
		tween.parallel().tween_property(right_panel,"position:x",800,0.2)
		
func _on_slot_mouse_entered(slot:beetle_slot):
	animate_right_panel(slot)
	
func _on_slot_mouse_exited(slot:beetle_slot):
	animate_right_panel(slot,false)
	
func _on_slot_clicked(slot:beetle_slot):
	slot_clicked.emit(slot)
	
func _on_button_pressed() -> void:
	canceled.emit()

func _on_button_2_pressed() -> void:
	breede.emit()


func _on_sell_button_pressed() -> void:
	sell_it.emit()


func _on_confirm_button_pressed() -> void:
	name_it.emit()


func _on_name_confirm_button_pressed() -> void:
	name_confirm.emit($Name/LineEdit.text)
	$Name/LineEdit.text = ""
	for slot in selected_slots:
		var tween = create_tween()
		tween.parallel().tween_property(slot,"modulate:a",1,0.1)
		slot.selected = false


func _on_timer_timeout() -> void:
	if slot_container.get_children().is_empty():
		return
	var should_close:bool = true
	for slot in slot_container.get_children():
		if slot is beetle_slot:
			if slot.mouse_in:
				should_close = false
	if should_close == true:
		animate_right_panel(null,false)


func _on_return_button_pressed() -> void:
	return_to_town.emit()
