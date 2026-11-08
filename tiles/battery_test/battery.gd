extends TileBase



func Adjacent_buff(tile:TileBase):
	if tile.current_action:
		if "Cannon" in tile.current_action.tags:
			for effect in tile.current_action.action_effects:
				if effect.effect_name == "Attack":
					effect.count_bonus += 2
