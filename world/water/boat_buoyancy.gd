extends RigidBody3D
## Simple buoyancy toward `WaterSurfaceQueries` height (Boujie or flat). Tune for PC; not a full ship sim.

const _WaterSurfaceQueries = preload("res://world/water/water_surface_queries.gd")

@export var buoyancy_strength: float = 35.0
## How strongly vertical velocity is damped when in water.
@export var vertical_drag: float = 3.5
@export var max_buoyancy_depth: float = 8.0
@export var enabled: bool = true


func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	var h: float = _WaterSurfaceQueries.get_active_water_height_at(get_tree(), global_position)
	if h < -1e6:
		return
	var depth: float = h - global_position.y
	if depth <= 0.0:
		return
	var sub: float = clampf(depth / maxf(max_buoyancy_depth, 0.01), 0.0, 1.2)
	apply_central_force(Vector3.UP * buoyancy_strength * sub)
	apply_central_force(-Vector3.UP * vertical_drag * linear_velocity.y * sub)
