extends Resource
class_name ResourceNodeData

## Profile for harvest / fish nodes. No scene paths — scenes reference this resource by export.

enum InteractionKind {
	CHOP,
	MINE,
	SMELT,
	CREATE,
	CRAFT,
	FISH,
	COOK,
}

@export var profile_id: String = ""
@export var skill_id: String = ""
@export var required_level: int = 0
@export var primary_item_id: String = ""
@export var respawn_seconds: float = 30.0
@export_range(0.0, 1.0, 0.01) var base_success_chance: float = 0.5
@export var interaction: InteractionKind = InteractionKind.CHOP
@export_range(1, 999, 1) var max_yield: int = 6
