extends Node3D
## Optional: snap this node's Y to the active water surface each physics frame (visual bobbers / props).
## For RigidBody3D boats, prefer buoyancy forces instead of overwriting transform.

const _WaterSurfaceQueries = preload("res://world/water/water_surface_queries.gd")

@export var vertical_offset: float = 0.0
@export var enabled: bool = true


func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	var y: float = _WaterSurfaceQueries.get_active_water_height_at(get_tree(), global_position)
	if y > -1e6:
		global_position.y = y + vertical_offset
