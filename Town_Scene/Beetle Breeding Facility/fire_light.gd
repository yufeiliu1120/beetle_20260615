extends PointLight2D

@export_group("Fire Flicker Settings")
@export var flicker_speed: float = 5.0      # 闪烁的速度
@export var min_energy: float = 0.6         # 火光最暗时的亮度
@export var max_energy: float = 1.2         # 火光最亮时的亮度
@export var min_scale: float = 0.85         # 火光最暗时的纹理缩放比例
@export var max_scale: float = 1.15         # 火光最亮时的纹理缩放比例

var _noise: FastNoiseLite
var _time_passed: float = 0.0

func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX 
	_noise.seed = randi()

func _process(delta: float) -> void:
	_time_passed += delta * flicker_speed
	
	var noise_value = _noise.get_noise_1d(_time_passed)
	var normalized_noise = (noise_value + 1.0) / 2.0
	
	# 1. 亮度同步：在设定的最低亮度和最高亮度之间插值
	self.energy = lerpf(min_energy, max_energy, normalized_noise)
	
	# 2. 尺寸同步：使用完全相同的噪声比例，在最小和最大范围间插值
	self.texture_scale = lerpf(min_scale, max_scale, normalized_noise)
