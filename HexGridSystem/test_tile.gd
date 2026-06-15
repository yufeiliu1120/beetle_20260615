extends TileBase
#用来测试地块加成效果的地块

func Adjacent_buff(tile):
	pass
	
func global_buff(tile):
	pass
	
func reset_stats():
	super()

func play_action_animation():
	var tween = get_tree().create_tween()
	tween.parallel().tween_property(self,"position",Vector2(50.0,0.0),0.2)
	tween.chain().tween_property(self,"position",Vector2(0.0,0.0),0.2)
	tween.tween_callback(action_animation_finished.emit)
	
	
