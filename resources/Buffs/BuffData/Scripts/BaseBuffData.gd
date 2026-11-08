class_name BuffData
extends Resource

enum StackMode {
	ADD_NEW,          # 独立叠加：每次获得都会生成一个全新的图标和层数
	EXTEND_DURATION   # 延时模式：不增加新层数，而是将时间补充给已存在的同名 Buff
}

@export_group("基础信息 (Visuals)")
@export var buff_name: String = "新状态"
@export var buff_icon: Texture2D
@export_multiline var description: String = ""
@export var is_debuff: bool = false # 用于区分增益/减益

@export_group("持续时间 (Duration)")
# 【新增】：在检查器中选择这个状态的叠加逻辑
@export var stack_mode: StackMode = StackMode.ADD_NEW

@export_group("持续时间 (Duration)")
# 持续回合数，-1 表示永久生效 (需要特殊事件清除)
@export var duration: int = 1:
	set(value):
		# 如果数值没有真正发生变化，则不触发信号（节省性能）
		if duration != value:
			duration = value
			duration_changed.emit(duration)
	
@export_group("逻辑挂载 (Logics)")
# 【核心重构】：这里挂载所有具体的执行逻辑
@export var buff_logics: Array[BuffLogic] = []

signal duration_changed(new_duration: int)

func set_text() -> String:
	var raw_text = description
	var dic: Dictionary = {}
	
	# 遍历整个数组，把所有下标对应的数值都存起来
	for i in range(buff_logics.size()):
		if buff_logics[i] != null and buff_logics[i].has_method("get_count_text"):
			dic[str(i)] = buff_logics[i].get_count_text()
		else:
			dic[str(i)] = 0 # 容错兜底：防止某个 effect 为空导致报错
	# 传入整个字典！如果文本是 "造成{0}点伤害"，.format() 会只用 "0"，自动无视多余的 "1"、"2"
	return raw_text.format(dic)
	
# ==========================================
# 运行时触发分发器
# 外部(CombatEntity)在对应的时机调用这些函数，
# Data 再将指令下发给挂载的所有 Logic
# ==========================================

#用于充值buff的数值，赋予buff时触发
func reset_count():
	for logic in buff_logics:
		logic.count_bonus = 0


func trigger_turn_start(caster: CombatEntity) -> void:
	for logic in buff_logics:
		if logic != null:
			logic.apply_turn_start(caster)

func trigger_turn_end(caster: CombatEntity) -> void:
	for logic in buff_logics:
		if logic != null:
			logic.apply_turn_end(caster)
			
func trigger_on_attach(caster: CombatEntity) -> void:
	for logic in buff_logics:
		if logic != null:
			logic.apply_on_attach(caster)
			
func trigger_on_detach(caster: CombatEntity) -> void:
	for logic in buff_logics:
		if logic != null:
			logic.apply_on_detach(caster)
