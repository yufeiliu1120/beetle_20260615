extends Camera2D
class_name custom_camera
@export var decay: float = 0.25 # 创伤衰减速度（值越大，停得越快）
@export var max_offset: Vector2 = Vector2(20, 20)  # 最大水平/垂直晃动像素
@export var max_roll: float = 0.05  # 最大旋转弧度
@export var noise_speed: float = 50.0

var trauma: float = 0.0  # 当前创伤值，范围 0.0 到 1.0
var trauma_power: int = 2  # 创伤曲线（二次方能让微小的震动更快平息）
var noise: FastNoiseLite = FastNoiseLite.new()
var noise_y: float = 0.0

func _ready() -> void:
	# 初始化噪波生成器
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.5 # 控制抖动的频率，可根据游戏节奏微调

func _process(delta: float) -> void:
	if trauma > 0.0:
		# 每帧持续衰减创伤值
		trauma = max(trauma - decay * delta, 0.0)
		# 将 delta 传给抖动函数以实现帧率独立
		_apply_shake(delta)
	elif offset != Vector2.ZERO or rotation != 0.0:
		# 创伤归零时，重置相机位置
		offset = Vector2.ZERO
		rotation = 0.0

func _apply_shake(delta: float) -> void:
	var amount: float = pow(trauma, trauma_power)
	
	# 根据时间推移在噪波图上移动
	noise_y += delta * noise_speed
	
	# 分别在 X=0, X=100, X=200 的噪波空间进行采样，避免各轴的抖动同步
	offset.x = max_offset.x * amount * noise.get_noise_2d(0.0, noise_y)
	offset.y = max_offset.y * amount * noise.get_noise_2d(100.0, noise_y)
	rotation = max_roll * amount * noise.get_noise_2d(200.0, noise_y)

# 外部调用的接口
func add_trauma(amount: float) -> void:
	# 叠加创伤值，封顶为 1.0
	trauma = min(trauma + amount, 1.0)
