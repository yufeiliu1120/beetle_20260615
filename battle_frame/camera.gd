extends Camera2D
class_name custom_camera

var shake_duration: float = 0.0  # 设定的总震动时间
var shake_time_left: float = 0.0 # 剩余震动时间
var shake_amplitude: float = 0.0 # 最大震动幅度（像素）

func _process(delta: float) -> void:
	if shake_time_left > 0:
		shake_time_left -= delta
		
		# 【平滑衰减】：让震动随着时间推移慢慢变小，看起来更自然
		# 如果你想让震动从头到尾一样猛烈，可以直接去掉 damping，强制使用 shake_amplitude
		var damping: float = shake_time_left / shake_duration
		var current_amplitude: float = shake_amplitude * damping
		
		# 在 X 和 Y 轴上随机产生偏移
		offset = Vector2(
			randf_range(-current_amplitude, current_amplitude),
			randf_range(-current_amplitude, current_amplitude)
		)
	elif offset != Vector2.ZERO:
		# 震动时间结束，将相机视野精准归零
		offset = Vector2.ZERO

# ==========================================
# 极简震动接口
# @param amplitude: 震动幅度（最大偏移像素，例如 15.0）
# @param duration: 震动持续时间（秒，例如 0.5）
# ==========================================
func apply_shake(amplitude: float, duration: float) -> void:
	shake_amplitude = amplitude
	shake_duration = duration
	shake_time_left = duration

# ==========================================
# 兼容旧代码的过渡接口
# ==========================================
func add_trauma(amount: float) -> void:
	# 以前的代码可能还在调用 add_trauma，在这里做一个简单的映射拦截
	# 假设 1.0 的 trauma 等于 20 像素的震幅，持续 0.5 秒
	apply_shake(amount * 20.0, 0.5)
