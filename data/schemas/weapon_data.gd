extends ItemData
class_name WeaponData

@export var weapon_stats: WeaponStats


func create_runtime_copy() -> WeaponData:
	return duplicate(true) as WeaponData
