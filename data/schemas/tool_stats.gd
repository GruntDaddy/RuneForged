extends Resource
class_name ToolStats

enum ToolKind {
	HATCHET,
	PICKAXE,
	CHISEL,
	HAMMER,
	FISHING_ROD,
}

@export var tool_kind: ToolKind = ToolKind.HATCHET
@export_range(1, 99, 1) var tier: int = 1
## Generic modifier for harvest/mining success or speed; systems define meaning.
@export var harvest_power: float = 1.0
