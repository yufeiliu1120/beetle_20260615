extends Node
#用来管理项目中所有的信号，这个项目不在脚本中大量使用信号，所有信号（除了封装的现成脚本，例如状态机）在这里管理。

#地块放下时触发这个信号，用来提示网格系统计算网格加成
signal tile_placed(Tile:TileBase)
