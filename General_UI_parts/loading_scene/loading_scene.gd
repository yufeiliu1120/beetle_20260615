extends CanvasLayer # 或者 Control，取决于你的根节点类型

@onready var progress_bar: TextureProgressBar = $TextureProgressBar

var _target_path: String = ""
var _is_loading_string: bool = false



func _ready() -> void:
	# 1. 从单例中获取目标
	var target = SceneManager.next_scene_target
	
	if target is String:
		# 分支 A：需要多线程硬盘加载
		_target_path = target
		ResourceLoader.load_threaded_request(_target_path)
		_is_loading_string = true # 开启 _process 监听
		
	elif target is PackedScene:
		# 分支 B：已经在内存中了
		progress_bar.value = 100.0
		_is_loading_string = false # 不需要监听 _process
		
		# 使用 call_deferred 确保加载界面的 UI 至少在屏幕上渲染了一帧，
		# 否则画面可能会卡在上一帧直接硬切
		call_deferred("_switch_to_packed", target)
	else:
		push_error("❌ 加载界面未获取到有效的目标场景！")

# 处理 PackedScene 的瞬间切换
func _switch_to_packed(scene: PackedScene) -> void:
	get_tree().change_scene_to_packed(scene)
	# 切换后，当前这个 loading_screen 场景会自动被 Godot 引擎销毁

# ==========================================
# 帧循环：仅在需要读取硬盘时生效
# ==========================================
func _process(_delta: float) -> void:
	if not _is_loading_string:
		return
		
	var progress_array: Array = []
	var status = ResourceLoader.load_threaded_get_status(_target_path, progress_array)
	
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# 更新进度条 (progress_array[0] 是 0.0 到 1.0 的浮点数)
			progress_bar.value = progress_array[0] * 100.0
			
		ResourceLoader.THREAD_LOAD_LOADED:
			# 加载完成！关闭 _process 节省性能
			set_process(false) 
			progress_bar.value = 100.0
			
			# 提取新场景并切换
			var new_scene = ResourceLoader.load_threaded_get(_target_path)
			get_tree().change_scene_to_packed(new_scene)
			
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			set_process(false)
			push_error("❌ 场景多线程加载失败，路径: ", _target_path)
