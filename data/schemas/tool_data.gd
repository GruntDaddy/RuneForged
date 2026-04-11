extends ItemData
class_name ToolData

@export var tool_stats: ToolStats


func create_runtime_copy() -> ToolData:
	return duplicate(true) as ToolData
