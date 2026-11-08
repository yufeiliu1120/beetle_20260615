extends PanelContainer
@export var container:HFlowContainer
@export var right_panel:beetle_info_panel
var slot_path:String = "res://General_UI_parts/beetles_menu/beetle_slot.tscn"
const PLAYER_BEETLE_DIR = "res://resources/beetle_resources/player_beetle/"
var is_showed:bool

signal slot_clicked(slot:beetle_slot)

func setup():
	for slot in container.get_children():
		if slot is beetle_slot:
			container.remove_child(slot)
			slot.queue_free()
	var player_beetles = load_all_player_beetles()
	for data in player_beetles:
		if data is BeetleChassisData:
			var slot:beetle_slot = load(slot_path).instantiate()
			container.add_child(slot)
			slot.set_slot_with_chassis(data)
			slot.slot_clicked.connect(_on_slot_clicked)
			slot.slot_mouse_entered.connect(_on_slot_mouse_entered)
			slot.slot_mouse_exited.connect(_on_slot_mouse_exited)
			
func _on_slot_mouse_entered(slot:beetle_slot):
	right_panel.setup(slot)
	var tween = create_tween()
	tween.tween_property(right_panel,"position:x",0,0.2)
	
func _on_slot_mouse_exited(slot:beetle_slot):
	var tween = create_tween()
	tween.tween_property(right_panel,"position:x",800,0.2)
			
func _on_slot_clicked(slot):
	slot_clicked.emit(slot)


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
	
