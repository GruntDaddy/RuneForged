extends Resource
class_name QuestObjectiveData

enum ObjectiveType {
	INVENTORY_COUNT,
	HAS_ITEM,
	PLACED_FIRE,
	KILL_COUNT,
	COOK_ON_FIRE,
}

@export var objective_type: ObjectiveType = ObjectiveType.INVENTORY_COUNT
@export var target_id: String = ""
@export_range(1, 999, 1) var target_count: int = 1
@export var description: String = ""
