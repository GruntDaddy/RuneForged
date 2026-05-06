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
## When > 0 and this item is equipped in the `back` slot, unlocks this many inventory slots after `InventoryService.BASE_SLOT_COUNT`. 0 = use catalog fallback for `backpack_*` ids.
@export_range(0, 64, 1) var backpack_extra_slots: int = 0

## Fuel value for fire-based stations (campfire, future torch). 0 = not a fuel.
@export_range(0, 3600, 1) var burn_seconds: int = 0
## Cooking burn-failure chance over a campfire (0..1). 0 = never burns.
@export_range(0.0, 1.0, 0.01) var cook_difficulty: float = 0.0
## Item id produced on a successful cook. Empty = item is not cookable.
@export var cooked_id: String = ""
## Item id produced on a failed cook (burn). Empty = burned roll is treated as success.
@export var burned_id: String = ""


func create_runtime_copy() -> ItemData:
	return duplicate(true) as ItemData
