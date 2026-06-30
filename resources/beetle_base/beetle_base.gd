extends Resource
class_name ShipChassisData

#这个资源类用来储存一个甲虫基础的信息
@export_group("战舰基础核心")
@export var base_ship_scene: PackedScene 

@export_group("模块化部件列表")
# 【全新升级】：不再写死具体部位，直接给一个数组。
# 你可以在检查器里塞入任意数量的部件场景！
@export var part_scenes: Array[PackedScene] = []
