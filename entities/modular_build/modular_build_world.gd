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
			var deck_y := terrain_deck_y_for_skirt_and_preview(tree, gs, region, iix, iiy, iiz, piece_id)
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
		if not _region_entry_matches(region, d):
			continue
		if int(d.get("ix", -9999)) == ix and int(d.get("iy", -9999)) == iy and int(d.get("iz", -9999)) == iz:
			return true
	return false


static func _region_entry_matches(active_region: String, d: Dictionary) -> bool:
	if active_region.is_empty():
		return true
	return String(d.get("region", "")) == active_region


## True if a ground-floor slab (any floor catalog piece) is saved in this cell.
static func cell_has_ground_floor(gs: Node, region: String, ix: int, iz: int) -> bool:
	if gs == null or not ("placed_modular_build_pieces" in gs):
		return false
	for e in gs.placed_modular_build_pieces:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = e
		if not _region_entry_matches(region, d):
			continue
		if int(d.get("iy", -99)) != 0:
			continue
		var pid := String(d.get("piece_id", ""))
		if not ModularBuildCatalog.is_floor_piece(pid):
			continue
		if int(d.get("ix", -9999)) == ix and int(d.get("iz", -9999)) == iz:
			return true
	return false


## True if any floor catalog piece is saved in this cell at the given story `iy`.
static func cell_has_floor_at(gs: Node, region: String, ix: int, iy: int, iz: int) -> bool:
	if gs == null or not ("placed_modular_build_pieces" in gs):
		return false
	for e in gs.placed_modular_build_pieces:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = e
		if not _region_entry_matches(region, d):
			continue
		if int(d.get("ix", -9999)) != ix or int(d.get("iy", -99)) != iy or int(d.get("iz", -9999)) != iz:
			continue
		var pid := String(d.get("piece_id", ""))
		if ModularBuildCatalog.is_floor_piece(pid):
			return true
	return false


## Walls/doors/windows: shift root XZ from cell center toward each orthogonally adjacent floor (same `iy`) so
## modules hug the shared edge instead of floating in the middle of the cell. Opposite neighbors cancel out.
static func wall_like_adjacent_floor_edge_snap_xz(
	gs: Node,
	region: String,
	ix: int,
	iy: int,
	iz: int,
	piece_id: String
) -> Vector2:
	if gs == null or region.is_empty():
		return Vector2.ZERO
	if not ModularBuildCatalog.nudges_off_floor_cell(piece_id):
		return Vector2.ZERO
	var half := ModularBuildCatalog.CELL_SIZE * 0.5
	var acc := Vector2.ZERO
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	for d in dirs:
		var nx := ix + d.x
		var nz := iz + d.y
		if cell_has_floor_at(gs, region, nx, iy, nz):
			acc.x += float(d.x) * half
			acc.y += float(d.y) * half
	return acc


static func horizontal_modular_placement_xz(
	gs: Node,
	region: String,
	ix: int,
	iy: int,
	iz: int,
	piece_id: String,
	yaw_steps: int
) -> Vector2:
	var xz := ModularBuildCatalog.cell_center_xz(ix, iz)
	xz += ModularBuildCatalog.vertex_anchor_world_offset_xz(piece_id, yaw_steps)
	xz += wall_like_adjacent_floor_edge_snap_xz(gs, region, ix, iy, iz, piece_id)
	return xz


## Walls/doors/windows: if the reticle resolves to an occupied cell (e.g. floor), pick a free orthogonal neighbor
## whose cell center is closest to `aim_world_xz` so one floor tile can be ringed by four walls flush on each side.
static func nudge_cell_to_empty_for_wall_like(
	gs: Node,
	region: String,
	piece_id: String,
	ix: int,
	iz: int,
	iy: int,
	aim_world_xz: Vector2,
	_player_world_xz: Vector2
) -> Vector2i:
	if not ModularBuildCatalog.nudges_off_floor_cell(piece_id):
		return Vector2i(ix, iz)
	if not cell_occupied(gs, region, ix, iy, iz):
		return Vector2i(ix, iz)
	var cardinals: Array[Vector2i] = [
		Vector2i(ix + 1, iz),
		Vector2i(ix - 1, iz),
		Vector2i(ix, iz + 1),
		Vector2i(ix, iz - 1),
	]
	var best: Vector2i = Vector2i(ix, iz)
	var best_d := INF
	for c in cardinals:
		if cell_occupied(gs, region, c.x, iy, c.y):
			continue
		var d := ModularBuildCatalog.cell_center_xz(c.x, c.y).distance_to(aim_world_xz)
		if d < best_d:
			best_d = d
			best = c
	if best_d < INF:
		return best
	return Vector2i(ix, iz)


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
	if iy == 0:
		return _terrain_mean_3x3(tree, ix, iz)
	var xz := ModularBuildCatalog.cell_center_xz(ix, iz)
	var y0 := _terrain_height_at(tree, xz)
	return y0 + ModularBuildCatalog.STORY_HEIGHT * float(iy)


## Ground-level skirt / preview: for wall-like pieces next to a floor, sample terrain like the slab cells so the rim
## matches; upper stories unchanged.
static func terrain_deck_y_for_skirt_and_preview(
	tree: SceneTree,
	gs: Node,
	region: String,
	ix: int,
	iy: int,
	iz: int,
	piece_id: String
) -> float:
	if iy != 0:
		return terrain_deck_y_at_cell(tree, ix, iy, iz)
	if gs == null or region.is_empty():
		return terrain_deck_y_at_cell(tree, ix, iy, iz)
	if not ModularBuildCatalog.align_to_floor_deck(piece_id):
		return terrain_deck_y_at_cell(tree, ix, iy, iz)
	var sum_t := 0.0
	var n_t := 0
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	for d in dirs:
		var nx := ix + d.x
		var nz := iz + d.y
		if not cell_has_floor_at(gs, region, nx, 0, nz):
			continue
		sum_t += _terrain_mean_3x3(tree, nx, nz)
		n_t += 1
	if n_t > 0:
		return sum_t / float(n_t)
	return terrain_deck_y_at_cell(tree, ix, iy, iz)


## World deck-plane Y (top of raised ground slab) implied by a saved floor root transform and that floor's mesh scale.
static func _deck_world_y_from_saved_floor_root(y_root: float, floor_piece_id: String) -> float:
	var sy := ModularBuildCatalog.piece_scale_vector(floor_piece_id).y
	return (
		y_root
		+ ModularBuildCatalog.FLOOR_SURFACE_BIAS
		+ ModularBuildCatalog.FLOOR_NATIVE_MESH_Y_MIN * sy
	)


## Average deck height from orthogonally adjacent ground-floor slabs (same region), or NAN if none.
static func _average_adjacent_floor_deck_plane_world_y(gs: Node, region: String, ix: int, iz: int) -> float:
	if gs == null or region.is_empty():
		return NAN
	var sum_d := 0.0
	var n_d := 0
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	for d in dirs:
		var nx := ix + d.x
		var nz := iz + d.y
		if not cell_has_floor_at(gs, region, nx, 0, nz):
			continue
		for e in gs.placed_modular_build_pieces:
			if typeof(e) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = e
			if not _region_entry_matches(region, row):
				continue
			if int(row.get("ix", -9999)) != nx or int(row.get("iz", -9999)) != nz:
				continue
			if int(row.get("iy", -99)) != 0:
				continue
			var fpid := String(row.get("piece_id", ""))
			if not ModularBuildCatalog.is_floor_piece(fpid):
				continue
			var pos_v: Variant = row.get("position", [])
			if typeof(pos_v) != TYPE_ARRAY:
				break
			var pa: Array = pos_v
			if pa.size() < 2:
				break
			var y_root := float(pa[1])
			sum_d += _deck_world_y_from_saved_floor_root(y_root, fpid)
			n_d += 1
			break
	if n_d == 0:
		return NAN
	return sum_d / float(n_d)


## Mean terrain height over a 3×3 cell neighborhood so adjacent ground-floor decks stay level with each other.
static func _terrain_mean_3x3(tree: SceneTree, ix: int, iz: int) -> float:
	var sum := 0.0
	var cnt := 0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var xz2 := ModularBuildCatalog.cell_center_xz(ix + dx, iz + dz)
			sum += _terrain_height_at(tree, xz2)
			cnt += 1
	return sum / float(cnt)


## Average `position.y` of orthogonally adjacent placed ground-floor pieces (floors only) for raft alignment.
static func _neighbor_floor_root_y_avg(gs: Node, region: String, ix: int, iz: int) -> float:
	if gs == null or not ("placed_modular_build_pieces" in gs):
		return NAN
	var sum := 0.0
	var n := 0
	for e in gs.placed_modular_build_pieces:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = e
		if not _region_entry_matches(region, d):
			continue
		if int(d.get("iy", -99)) != 0:
			continue
		var pid := String(d.get("piece_id", ""))
		if not ModularBuildCatalog.is_floor_piece(pid):
			continue
		var ox := int(d.get("ix", -99999))
		var oz := int(d.get("iz", -99999))
		if absi(ox - ix) + absi(oz - iz) != 1:
			continue
		var pa: Variant = d.get("position", [])
		if typeof(pa) == TYPE_ARRAY:
			var ar: Array = pa
			if ar.size() >= 2:
				sum += float(ar[1])
				n += 1
	if n == 0:
		return NAN
	return sum / float(n)


## Single source for ghost + place: world pose, skirt deck reference, validity, and `block_reason` when invalid.
static func evaluate_cell(
	tree: SceneTree,
	ix: int,
	iy: int,
	iz: int,
	piece_id: String,
	player_horizontal_xz: Vector2,
	gs: Node,
	region: String,
	yaw_steps: int = 0
) -> Dictionary:
	var world_pos := world_position_for_cell(tree, ix, iy, iz, piece_id, gs, region, yaw_steps)
	var deck_y := terrain_deck_y_for_skirt_and_preview(tree, gs, region, ix, iy, iz, piece_id)
	var block_reason := ""
	if region.is_empty():
		block_reason = "no_region"
	elif cell_occupied(gs, region, ix, iy, iz):
		block_reason = "occupied"
	else:
		var hb := horizontal_modular_placement_xz(gs, region, ix, iy, iz, piece_id, yaw_steps)
		var dist_pt := Vector3(hb.x, 0.0, hb.y)
		var dist_h: float = dist_pt.distance_to(
			Vector3(player_horizontal_xz.x, 0.0, player_horizontal_xz.y)
		)
		if dist_h > ModularBuildCatalog.MAX_PLACE_DISTANCE:
			block_reason = "too_far"
	return {
		"world_pos": world_pos,
		"deck_y": deck_y,
		"valid": block_reason.is_empty(),
		"block_reason": block_reason,
	}


static func block_reason_message(reason: String) -> String:
	match reason:
		"no_region":
			return "Cannot build in this area yet."
		"occupied":
			return "That cell is already full."
		"too_far":
			return "Too far to place."
		"no_terrain":
			return "Terrain unavailable here."
		_:
			return "Cannot place here."


static func world_position_for_cell(
	tree: SceneTree,
	ix: int,
	iy: int,
	iz: int,
	piece_id: String = "",
	gs: Node = null,
	region: String = "",
	yaw_steps: int = 0
) -> Vector3:
	var xz_pos := horizontal_modular_placement_xz(gs, region, ix, iy, iz, piece_id, yaw_steps)
	if ModularBuildCatalog.is_floor_piece(piece_id) and iy == 0:
		if gs != null and not region.is_empty():
			var nby := _neighbor_floor_root_y_avg(gs, region, ix, iz)
			if not is_nan(nby):
				return Vector3(xz_pos.x, nby, xz_pos.y)
		var terr_s := _terrain_mean_3x3(tree, ix, iz)
		var deck := terr_s + ModularBuildCatalog.FLOOR_DECK_LIFT
		var yf := ModularBuildCatalog.floor_snap_y_for_deck(deck, piece_id)
		return Vector3(xz_pos.x, yf, xz_pos.y)
	# Ground-level non-floors: smoothed terrain (3×3) so slopes match the floor grid; optional deck alignment for walls.
	if iy == 0 and not ModularBuildCatalog.is_floor_piece(piece_id):
		var y_ground: float
		if ModularBuildCatalog.align_to_floor_deck(piece_id):
			var deck0: float
			var adj_deck := _average_adjacent_floor_deck_plane_world_y(gs, region, ix, iz)
			if not is_nan(adj_deck):
				deck0 = adj_deck
			else:
				var terr_m := _terrain_mean_3x3(tree, ix, iz)
				deck0 = terr_m + ModularBuildCatalog.FLOOR_DECK_LIFT
			y_ground = ModularBuildCatalog.floor_snap_y_for_deck(
				deck0, ModularBuildCatalog.DECK_ALIGN_REFERENCE_FLOOR_ID
			)
		else:
			y_ground = _terrain_mean_3x3(tree, ix, iz)
		y_ground += ModularBuildCatalog.ground_offset_y_for(piece_id)
		return Vector3(xz_pos.x, y_ground, xz_pos.y)
	var xz_center := ModularBuildCatalog.cell_center_xz(ix, iz)
	var y0 := _terrain_height_at(tree, xz_center)
	var deck2 := y0 + ModularBuildCatalog.STORY_HEIGHT * float(iy)
	var y2: float
	if ModularBuildCatalog.is_floor_piece(piece_id):
		y2 = ModularBuildCatalog.floor_snap_y_for_deck(deck2 + ModularBuildCatalog.FLOOR_DECK_LIFT, piece_id)
	else:
		y2 = deck2
	return Vector3(xz_pos.x, y2, xz_pos.y)


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
