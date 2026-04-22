extends Node3D
## Keeps Terrain3D isle biome `sea_level_y` in sync with the `Water` node's `water_level`.

@onready var _terrain: Terrain3D = $Terrain3D
@onready var _water: Node3D = $Water


func _ready() -> void:
	_apply_sea_level()


func _apply_sea_level() -> void:
	if _terrain == null:
		return
	var y: float = 0.0
	if _water != null and _water.get("water_level") != null:
		y = float(_water.water_level)
	_terrain.material.set_shader_param(&"sea_level_y", y)
