extends RefCounted
class_name ModularBuildWorld

const _ROOT_NAME := "ModularBuildRoot"
const _PieceScene: PackedScene = preload("res://entities/modular_build/modular_build_piece.tscn")
const _Terrain3DPrimaryResolver = preload("res://world/terrain3d_primary_resolver.gd")


static func ensure_root(parent: Node) -> Node3D:
	var existing := parent.get_node_or_null(_ROOT_NAME) as Node3D
	if existing != null:
		return existing
	var n := Node3D.new()
	n.name = _ROOT_NAME
	parent.add_child(n)
	return n


static func scene_has_placement_id(scene: Node, placement_id: String) -> bool:
	var root := scene.get_node_or_null(_ROOT_NAME) as Node3D
	if root == null:
		return false
	for c in root.get_children():
		if c is Node3D and "placement_id" in c and String((c as Node3D).get("placement_id")) == placement_id:
			return true
	return false


static func spawn_saved_for_current_scene(tree: SceneTree) -> void:
	if tree == null:
		return
	var scene := tree.current_scene
	if scene == null:
		return
	var gs: Node = tree.root.get_node_or_null("/root/GameState")
	if gs == null or not ("placed_modular_build_pieces" in gs):
		return
	var scene_path := String(scene.scene_file_path)
	var region: String = ""
	if gs.has_method("region_effective_for_scene_path"):
		region = String(gs.call("region_effective_for_scene_path", scene_path))
	else:
		region = String(gs.get("region")) if "region" in gs else ""
	if region.is_empty():
		return
	var arr: Array = gs.placed_modular_build_pieces
	var root := ensure_root(scene)
	for e in arr:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = e
		if String(d.get("region", "")) != region:
			continue
		var pid: String = String(d.get("placement_id", ""))
		if pid.is_empty():
			continue
		if scene_has_placement_id(scene, pid):
			continue
		var piece_id: String = String(d.get("piece_id", ""))
		if piece_id.is_empty():
			continue
		var inst := _PieceScene.instantiate()
		if not (inst is Node3D):
			continue
		var node3d := inst as Node3D
		root.add_child(node3d)
		if node3d.has_method("configure"):
			node3d.call(
				"configure",
				piece_id,
				pid,
				String(d.get("owner", ModularBuildCatalog.OWNER_PLAYER)),
				false
			)
		var pos_v: Variant = d.get("position", [])
		if typeof(pos_v) == TYPE_ARRAY:
			var pa: Array = pos_v
			if pa.size() >= 3:
				node3d.global_position = Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
		node3d.rotation.y = float(d.get("rotation_y", 0.0))
		if node3d.has_method("apply_foundation_skirt"):
			var iix := int(d.get("ix", 0))
			var iiy := int(d.get("iy", 0))
			var iiz := int(d.get("iz", 0))
			var deck_y := terrain_deck_y_at_cell(tree, iix, iiy, iiz)
			node3d.call("apply_foundation_skirt", deck_y, iiy)


static func placement_dict(
	region: String,
	placement_id: String,
	piece_id: String,
	ix: int,
	iy: int,
	iz: int,
	rotation_y: float,
	owner: String,
	world_pos: Vector3
) -> Dictionary:
	return {
		"region": region,
		"placement_id": placement_id,
		"piece_id": piece_id,
		"ix": ix,
		"iy": iy,
		"iz": iz,
		"rotation_y": rotation_y,
		"owner": owner,
		"position": [world_pos.x, world_pos.y, world_pos.z],
	}


static func cell_occupied(gs: Node, region: String, ix: int, iy: int, iz: int) -> bool:
	if gs == null or not ("placed_modular_build_pieces" in gs):
		return false
	for e in gs.placed_modular_build_pieces:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = e
		if String(d.get("region", "")) != region:
			continue
		if int(d.get("ix", -9999)) == ix and int(d.get("iy", -9999)) == iy and int(d.get("iz", -9999)) == iz:
			return true
	return false


static func remove_from_game_state(gs: Node, placement_id: String) -> bool:
	if gs == null or not ("placed_modular_build_pieces" in gs):
		return false
	var arr: Array = gs.placed_modular_build_pieces
	var out: Array = []
	var removed := false
	for e in arr:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = e
		if String(d.get("placement_id", "")) == placement_id:
			removed = true
			continue
		out.append(d)
	if removed:
		gs.placed_modular_build_pieces = out
	return removed


static func terrain_deck_y_at_cell(tree: SceneTree, ix: int, iy: int, iz: int) -> float:
	var xz := ModularBuildCatalog.cell_center_xz(ix, iz)
	var y0 := _terrain_height_at(tree, xz)
	return y0 + ModularBuildCatalog.STORY_HEIGHT * float(iy)


static func world_position_for_cell(tree: SceneTree, ix: int, iy: int, iz: int, piece_id: String = "") -> Vector3:
	var xz := ModularBuildCatalog.cell_center_xz(ix, iz)
	var y0 := _terrain_height_at(tree, xz)
	var deck := y0 + ModularBuildCatalog.STORY_HEIGHT * float(iy)
	var y: float
	if ModularBuildCatalog.is_floor_piece(piece_id):
		y = ModularBuildCatalog.floor_snap_y_for_deck(deck + ModularBuildCatalog.FLOOR_DECK_LIFT, piece_id)
	else:
		y = deck
	return Vector3(xz.x, y, xz.y)


static func _terrain_height_at(tree: SceneTree, xz: Vector2) -> float:
	var probe := Vector3(xz.x, 512.0, xz.y)
	var hf: float = _Terrain3DPrimaryResolver.height_at_world(tree, probe)
	if not is_nan(hf):
		return hf
	# Ray down from high above (static geometry, terrain).
	var space := tree.root.get_world_3d().direct_space_state if tree.root.get_world_3d() != null else null
	if space == null:
		return 0.0
	var from := Vector3(xz.x, 400.0, xz.y)
	var to := Vector3(xz.x, -200.0, xz.y)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return 0.0
	return float(hit.position.y)


static func ray_pick_piece(tree: SceneTree, origin: Vector3, dir: Vector3, max_dist: float) -> Node3D:
	var space := tree.root.get_world_3d().direct_space_state if tree.root.get_world_3d() != null else null
	if space == null:
		return null
	var to := origin + dir.normalized() * max_dist
	var q := PhysicsRayQueryParameters3D.create(origin, to)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return null
	var collider: Object = hit.get("collider")
	if collider == null:
		return null
	var n: Node = collider as Node
	if n == null:
		return null
	var cur: Node = n
	var hops := 0
	while cur != null and hops < 12:
		if cur is Node3D and cur.is_in_group("modular_build_piece"):
			return cur as Node3D
		cur = cur.get_parent()
		hops += 1
	return null
