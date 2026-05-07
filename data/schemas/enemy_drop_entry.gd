extends Resource
class_name EnemyDropEntry

@export var item_id: String = ""
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
@export_range(1, 99, 1) var min_count: int = 1
@export_range(1, 99, 1) var max_count: int = 1
