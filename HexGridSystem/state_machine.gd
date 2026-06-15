class_name StateMachine
extends Node

@export var initial_state: State
var current_state: State
var states: Dictionary = {}
func _ready():
	var used_names = {}
	for child in get_children():
		if child is State:
			if child.state_name in used_names:
				push_error("重复的状态名：%s" % child.state_name)
				continue
		if child.state_name.is_empty():
			push_error("状态节点必须设置 state_name 属性")
			continue
		used_names[child.state_name] = true
		states[child.state_name] = child
		child.fsm = self
		child.actor = get_parent()
	for state in states.values():
		state.state_finished.connect(_on_state_finished)
	# 确保初始状态存在
	if not initial_state or not states.has(initial_state.state_name):
		push_error("初始状态配置错误")
		return
	initial_state_priority()
	change_state(initial_state.state_name)
	
func initial_state_priority():
	for i in states.keys():
		STATE_PRIORITY[i] = 1
	
func _on_state_finished(next_state_name: String):
	try_transition(next_state_name)
	
func change_state(new_state_name:String):
		
	if current_state:
		current_state.exit()
	current_state = states[new_state_name]
	current_state.enter()


func _physics_process(delta):
	if current_state:
		current_state.do(delta)

# 基础状态类
@export var STATE_PRIORITY = {
}

func try_transition(new_state_name: String):
	
	if not states.has(new_state_name):  # 添加额外校验
		push_error("尝试切换到不存在的状态：", new_state_name)
		return
	if not STATE_PRIORITY.has(new_state_name):
		push_error("尝试切换到未定义优先级的狀態: %s" % new_state_name)
		return
	
	var current_priority = STATE_PRIORITY.get(current_state.state_name, 0)
	var new_priority = STATE_PRIORITY[new_state_name]
	
	if new_priority > current_priority or (
		new_priority == current_priority and new_state_name != current_state.state_name
	):
		change_state(new_state_name)
		
class State extends Node:
	signal state_finished(next_state)
	@onready var fsm = $"."
	@onready var actor = get_parent().get_parent()
	func enter(): pass
	func exit(): pass
	func do(_delta): pass
	func should_stop_navigation() -> bool:
		return false
