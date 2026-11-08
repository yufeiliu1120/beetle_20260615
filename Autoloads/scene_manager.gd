extends Node

# ==========================================
# 极简的数据桥梁
# ==========================================
# 指向你的加载界面的实际路径，请确保路径正确
const LOADING_SCREEN_PATH: String = "res://General_UI_parts/loading_scene/loading_scene.tscn"


# 临时储存目标场景 (支持 String 或 PackedScene)
var next_scene_target: Variant = null 

func load_scene(target: Variant) -> void:
	if not (target is String or target is PackedScene):
		push_error("❌ SceneManager: 传入了无效的场景类型！")
		return
		
	# 1. 存入目标
	next_scene_target = target
	
	# 2. 彻底销毁当前场景，切入加载跳板场景
	get_tree().change_scene_to_file(LOADING_SCREEN_PATH)
