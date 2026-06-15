extends TileBase

func Adjacent_buff(tile):
	var tile_action = tile.current_action
	if not tile_action:
		return
	var tile_tags = tile.current_action.tags
	if "Attack" in tile_tags:
		tile_action.damage += 100
