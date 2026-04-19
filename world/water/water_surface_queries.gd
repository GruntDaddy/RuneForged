class_name WaterSurfaceQueries
extends RefCounted
## Resolves `water_surface` group the same way gameplay expects (smallest bounding `plane_size`),
## then returns either Boujie-sampled height or flat `water_level`.

const _NONE := -1e7


static func get_active_water_height_at(tree: SceneTree, world_position: Vector3) -> float:
	if tree == null:
		return _NONE
	var best: Node3D = null
	var best_area: float = INF
	for node in tree.get_nodes_in_group(&"water_surface"):
		if not node is Node3D:
			continue
		var w := node as Node3D
		var ps: Variant = w.get(&"plane_size")
		if typeof(ps) != TYPE_VECTOR2:
			continue
		var half: Vector2 = ps * 0.5
		var dx: float = absf(world_position.x - w.global_position.x)
		var dz: float = absf(world_position.z - w.global_position.z)
		if dx > half.x or dz > half.y:
			continue
		var area: float = ps.x * ps.y
		if area < best_area:
			best_area = area
			best = w
	if best == null:
		return _NONE
	if best.has_method(&"get_water_surface_height_at"):
		return best.call(&"get_water_surface_height_at", world_position)
	var wl: Variant = best.get(&"water_level")
	if typeof(wl) == TYPE_FLOAT:
		return wl as float
	return best.global_position.y
