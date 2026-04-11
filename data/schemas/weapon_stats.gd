extends Resource
class_name WeaponStats

## Combat numbers only; no scenes. Systems interpret these fields.

enum WeaponFamily {
	SWORD_1H,
	SWORD_2H,
	AXE,
	MACE,
	DAGGER,
	SPEAR,
	BOW,
	STAFF,
}

@export var weapon_family: WeaponFamily = WeaponFamily.SWORD_1H
@export var base_damage: float = 1.0
## Seconds between attack starts when using this weapon (gameplay may override).
@export var attack_interval_sec: float = 1.0
@export var crit_chance: float = 0.05
@export var crit_multiplier: float = 1.5
