extends GPUParticles2D
func _ready() -> void:
	one_shot = true
	emitting = true
	# 监听粒子发射完毕后自动释放节点
	await finished
	queue_free()
