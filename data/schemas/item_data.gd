extends Resource
class_name ItemData

## Authoring definition for an item. Runtime stacks reference `id` only (see InventoryService save format).

enum Category {
	MATERIAL,
	CONSUMABLE,
	TOOL,
	WEAPON,
	ARMOR,
	CLOTHING,
	JEWERLY,
	RELIC,
	RUNE,
	QUEST,
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.MATERIAL
@export_range(1, 999, 1) var max_stack: int = 99
@export var tags: PackedStringArray = PackedStringArray()
@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture2D = null
## Optional explicit pickup scene path for world drops/placements.
@export_file("*.tscn") var pickup_scene_path: String = ""
## Optional data-driven "use/cast" effect id (mainly runes).
@export var use_effect_id: String = ""
## Optional cooldown for use/cast effects. 0 means script default.
@export_range(0, 3600000, 1) var use_cooldown_ms: int = 0


func create_runtime_copy() -> ItemData:
	return duplicate(true) as ItemData
