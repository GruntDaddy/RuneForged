extends RefCounted
class_name CombatFormulaService

const _WeaponData = preload("res://data/schemas/weapon_data.gd")
const _WeaponStats = preload("res://data/schemas/weapon_stats.gd")

const _TOOL_MELEE_IDS: PackedStringArray = [
	"hatchet_basic",
	"hatchet_bronze",
	"pickaxe_basic",
	"pickaxe_bronze",
]


static func equipped_weapon_family(item_id: String) -> _WeaponStats.WeaponFamily:
	if item_id.is_empty():
		return _WeaponStats.WeaponFamily.SWORD_1H
	var it: ItemData = ItemCatalog.get_item(item_id)
	if it == null:
		return _WeaponStats.WeaponFamily.SWORD_1H
	if it is _WeaponData:
		var wd: WeaponData = it as _WeaponData
		if wd.weapon_stats != null:
			return wd.weapon_stats.weapon_family
	for tag in it.tags:
		if str(tag) == "bow":
			return _WeaponStats.WeaponFamily.BOW
	return _WeaponStats.WeaponFamily.SWORD_1H


static func creature_damage_amount(
	item_id: String,
	unarmed_melee_damage: float,
	tool_melee_damage: float,
	creature_attack_damage: float
) -> float:
	if item_id.is_empty():
		return unarmed_melee_damage
	if _TOOL_MELEE_IDS.has(item_id):
		return tool_melee_damage
	var it: ItemData = ItemCatalog.get_item(item_id)
	if it is _WeaponData:
		var wd: WeaponData = it as _WeaponData
		if wd.weapon_stats != null:
			return wd.weapon_stats.base_damage
	return creature_attack_damage


static func creature_attack_interval_sec(item_id: String, fallback_sec: float) -> float:
	if item_id.is_empty():
		return fallback_sec
	var it: ItemData = ItemCatalog.get_item(item_id)
	if it is _WeaponData:
		var wd: WeaponData = it as _WeaponData
		if wd.weapon_stats != null:
			return wd.weapon_stats.attack_interval_sec
	return fallback_sec
