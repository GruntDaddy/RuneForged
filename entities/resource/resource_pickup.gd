extends Area3D

const _InventoryService = preload("res://autoload/inventory_service.gd")
const _Terrain3DPrimaryResolver = preload("res://world/terrain3d_primary_resolver.gd")

@export var resource_type: String = "logs"
@export var quantity: int = 1
@export var pop_up_velocity: float = 4.2
@export var pop_side_velocity: float = 2.2
@export var pop_gravity: float = 13.0
@export var ground_probe_height: float = 0.2
@export var ground_probe_depth: float = 4.0
@export var ground_clearance: float = 0.06
@export var auto_snap_visual_to_ground: bool = false
## After landing, nudge the root so mesh bottom matches terrain probe (fixes log vs sphere origin).
@export var align_bottom_to_ground_on_settle: bool = true
## When set, height queries use this terrain (main island). Otherwise uses group `terrain3d`, then the first Terrain3D that is not the paths overlay.
@export var terrain_override: Terrain3D

var _velocity: Vector3 = Vector3.ZERO
var _is_airborne: bool = false
var _exclude_rid: RID
var _terrain_3d_cache: Node


func _ready() -> void:
	add_to_group("pickup")
	if auto_snap_visual_to_ground:
		_snap_visual_to_ground()
	var on_gather := Callable(self, "_on_body_entered")
	if not body_entered.is_connected(on_gather):
		body_entered.connect(on_gather)


func set_quantity(n: int) -> void:
	quantity = maxi(1, n)


func set_resource_type(id: String) -> void:
	resource_type = id


func launch_from_harvest(source_pos: Vector3, source_exclude_rid: Variant = RID()) -> void:
	var planar := (global_position - source_pos)
	planar.y = 0.0
	if planar.length_squared() < 0.0001:
		planar = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	planar = planar.normalized()
	var side := planar * randf_range(pop_side_velocity * 0.65, pop_side_velocity * 1.25)
	_velocity = Vector3(side.x, randf_range(pop_up_velocity * 0.85, pop_up_velocity * 1.2), side.z)
	var xr: RID = RID()
	if source_exclude_rid is RID:
		xr = source_exclude_rid as RID
	_exclude_rid = xr if xr.is_valid() else RID()
	_is_airborne = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _is_airborne:
		return
	_velocity.y -= pop_gravity * delta
	global_position += _velocity * delta
	var ground_target := _probe_ground_y()
	var lowest_world := _get_visual_lowest_world_y()
	var bottom_y: float = lowest_world if lowest_world < INF else global_position.y
	if bottom_y <= ground_target:
		if align_bottom_to_ground_on_settle and lowest_world < INF:
			var dy: float = ground_target - lowest_world
			global_position.y += dy
		_velocity = Vector3.ZERO
		_is_airborne = false
		set_physics_process(false)


func _find_terrain_3d() -> Node:
	if is_instance_valid(_terrain_3d_cache) and _terrain_3d_cache.is_inside_tree():
		return _terrain_3d_cache
	_terrain_3d_cache = null
	var tree := get_tree()
	if tree == null:
		return null
	var t: Terrain3D = _Terrain3DPrimaryResolver.find_primary(tree, terrain_override)
	if t != null:
		_terrain_3d_cache = t
	return _terrain_3d_cache


func _terrain_surface_y_at(world_xz: Vector3) -> float:
	var terr: Node = _find_terrain_3d()
	if terr == null:
		return NAN
	var data: Variant = terr.get("data")
	if data == null or not data.has_method("get_height"):
		return NAN
	var hf: float = data.get_height(world_xz)
	if is_nan(hf):
		return NAN
	return hf + ground_clearance


func _probe_ground_y() -> float:
	var from := global_position + Vector3.UP * ground_probe_height
	var to := from + Vector3.DOWN * ground_probe_depth
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if _exclude_rid.is_valid():
		query.exclude = [_exclude_rid]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.size() > 0:
		return (hit["position"] as Vector3).y + ground_clearance
	var ty := _terrain_surface_y_at(global_position)
	if not is_nan(ty):
		return ty
	return global_position.y


func _get_visual_lowest_world_y() -> float:
	var lowest := INF
	var meshes: Array = find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var aabb: AABB = mi.get_aabb()
		for x in [aabb.position.x, aabb.position.x + aabb.size.x]:
			for y in [aabb.position.y, aabb.position.y + aabb.size.y]:
				for z in [aabb.position.z, aabb.position.z + aabb.size.z]:
					var p_world: Vector3 = mi.global_transform * Vector3(x, y, z)
					lowest = minf(lowest, p_world.y)
	return lowest


func _snap_visual_to_ground() -> void:
	var visual := get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	var meshes: Array = find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	var min_y := INF
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var aabb := mi.mesh.get_aabb()
		for x in [aabb.position.x, aabb.position.x + aabb.size.x]:
			for y in [aabb.position.y, aabb.position.y + aabb.size.y]:
				for z in [aabb.position.z, aabb.position.z + aabb.size.z]:
					var p_world := mi.global_transform * Vector3(x, y, z)
					var p_local := to_local(p_world)
					min_y = minf(min_y, p_local.y)
	if min_y == INF:
		return
	var shift := -min_y
	visual.position.y += shift


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var inv := get_node_or_null("/root/InventoryService")
	if inv == null:
		push_error(
			"resource_pickup: /root/InventoryService missing — lost pickup: %s (%s)"
			% [resource_type, get_path()]
		)
	elif not (inv is _InventoryService):
		var scr: Variant = inv.get_script()
		var detail: String
		if scr is Resource:
			detail = (scr as Resource).resource_path
		elif scr != null:
			detail = str(scr)
		else:
			detail = inv.get_class()
		push_error(
			"resource_pickup: InventoryService type mismatch (got %s). Lost: %s (%s)"
			% [detail, resource_type, get_path()]
		)
	else:
		(inv as _InventoryService).add_item(resource_type, quantity)
	queue_free()
