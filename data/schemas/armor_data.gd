extends ItemData
class_name ArmorData

@export var armor_stats: ArmorStats


func create_runtime_copy() -> ArmorData:
	return duplicate(true) as ArmorData
