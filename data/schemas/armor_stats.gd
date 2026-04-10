extends Resource
class_name ArmorStats

enum ArmorSlot {
	HEAD,
	CHEST,
	LEGS,
	HANDS,
	FEET,
	SHIELD,
}

@export var slot: ArmorSlot = ArmorSlot.CHEST
@export var armor_value: float = 0.0
@export var resist_physical: float = 0.0
@export var resist_magic: float = 0.0
