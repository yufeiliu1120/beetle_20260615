extends PanelContainer
class_name MapNodeMenu

@export var text_label: RichTextLabel
@export var start_button: Button

# 保存对所属 MapNode 的引用，以便回调
var _target_node: MapNode

# 初始化接口
func setup(node: MapNode, text_content: String) -> void:
	_target_node = node
	text_label.text = text_content
	
	# 连接按钮信号
	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	if is_instance_valid(_target_node):
		_target_node._on_menu_start_pressed()
