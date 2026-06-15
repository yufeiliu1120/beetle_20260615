extends Node

# 玩家拥有的地块卡牌路径数组
var card_backpack: Array[String] = ["res://tiles/cannon/cannon_card.tscn"]

# 提供一个辅助方法：消耗地块
func consume_card(card_path: String) -> void:
	var index = card_backpack.find(card_path)
	if index != -1:
		card_backpack.remove_at(index)
