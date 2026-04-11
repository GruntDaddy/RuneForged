extends Resource
class_name RecipeData

enum CraftStation {
	NONE,
	CAMPFIRE,
	STOVE,
	WORKBENCH,
	ANVIL,
	FURNACE,
}

@export var id: String = ""
@export var display_name: String = ""
@export var inputs: Array[RecipeIngredient] = []
@export var output_item_id: String = ""
@export_range(1, 999, 1) var output_count: int = 1
@export var skill_id: String = ""
@export var required_skill_level: int = 0
@export var station: CraftStation = CraftStation.NONE
