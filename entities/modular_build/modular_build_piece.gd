extends Node3D
class_name ModularBuildPiece

const GROUP_NAME := "modular_build_piece"
const _FOUNDATION_SKIRT_NAME := "FoundationSkirt"

@export var placement_id: String = ""
@export var owner_key: String = ModularBuildCatalog.OWNER_PLAYER
@export var piece_id: String = ""

var _preview_mode: bool = false
## -2 = needs tint after rebuild; 0/1 = last applied invalid/valid (skip duplicate work each frame).
var _preview_tint_state: int = -2


func configure(p_pid: String, p_placement_id: String, p_owner: String, preview: bool = false) -> void:
	piece_id = p_pid
	placement_id = p_placement_id
	owner_key = p_owner
	_preview_mode = preview
	_preview_tint_state = -2
	if not preview:
		add_to_group(GROUP_NAME)
		name = "ModularPiece_%s" % p_placement_id
	else:
		name = "ModularPiecePreview"
	_rebuild_visual()


func refresh_preview_tint(valid: bool) -> void:
	if not _preview_mode:
		return
	var want := 1 if valid else 0
	if _preview_tint_state == want:
		return
	_preview_tint_state = want
	_clear_preview_surface_overrides()
	_apply_preview_tint(valid)


static var _foundation_shared_mat: StandardMaterial3D


func _foundation_shared_material() -> StandardMaterial3D:
	if _foundation_shared_mat == null:
		_foundation_shared_mat = StandardMaterial3D.new()
		_foundation_shared_mat.albedo_color = ModularBuildCatalog.FOUNDATION_SKIRT_ALBEDO
		_foundation_shared_mat.roughness = 0.92
	return _foundation_shared_mat


func _is_under_foundation_skirt(mi: MeshInstance3D) -> bool:
	var p := mi.get_parent()
	return p != null and String(p.name) == _FOUNDATION_SKIRT_NAME


## Deck footprint in piece-local XZ from merged `Visual` mesh AABBs; falls back to full cell if missing.
func _foundation_deck_xz_extents_local() -> Dictionary:
	var cell := ModularBuildCatalog.CELL_SIZE
	var half := cell * 0.5
	var fallback := {"min_x": -half, "max_x": half, "min_z": -half, "max_z": half}
	var visual := get_node_or_null("Visual") as Node3D
	if visual == null:
		return fallback
	var inv_piece := global_transform.affine_inverse()
	var first := true
	var min_x := 0.0
	var max_x := 0.0
	var min_z := 0.0
	var max_z := 0.0
	for n in visual.find_children("*", "MeshInstance3D", true, false):
		var meshi := n as MeshInstance3D
		if meshi == null or meshi.mesh == null:
			continue
		var laabb: AABB = meshi.get_aabb()
		var to_piece: Transform3D = inv_piece * meshi.global_transform
		var baabb: AABB = to_piece * laabb
		if first:
			min_x = baabb.position.x
			max_x = baabb.end.x
			min_z = baabb.position.z
			max_z = baabb.end.z
			first = false
		else:
			min_x = minf(min_x, baabb.position.x)
			max_x = maxf(max_x, baabb.end.x)
			min_z = minf(min_z, baabb.position.z)
			max_z = maxf(max_z, baabb.end.z)
	if first:
		return fallback
	var span_x := max_x - min_x
	var span_z := max_z - min_z
	if span_x < 0.05 or span_z < 0.05:
		return fallback
	return {"min_x": min_x, "max_x": max_x, "min_z": min_z, "max_z": max_z}


## Box foundation rim under the slab (shared material, works in preview). Pass `floor_iy < 0` to clear only.
func apply_foundation_skirt(_terrain_deck_y: float, floor_iy: int = 0) -> void:
	_clear_foundation_skirt()
	if floor_iy < 0:
		return
	if floor_iy != 0:
		return
	if not ModularBuildCatalog.foundation_skirt_enabled(piece_id):
		return
	var skirt_root := Node3D.new()
	skirt_root.name = _FOUNDATION_SKIRT_NAME
	add_child(skirt_root)

	var depth := ModularBuildCatalog.FOUNDATION_BOX_DEPTH
	var thick := ModularBuildCatalog.FOUNDATION_BOX_THICK
	var b := _foundation_deck_xz_extents_local()
	var ix0 := float(b["min_x"])
	var ix1 := float(b["max_x"])
	var iz0 := float(b["min_z"])
	var iz1 := float(b["max_z"])
	var cx := (ix0 + ix1) * 0.5
	var cz := (iz0 + iz1) * 0.5
	var span_x := ix1 - ix0 + 2.0 * thick
	var span_z := iz1 - iz0 + 2.0 * thick
	var sy := maxf(0.001, absf(scale.y))
	var slab_bottom_local_y := ModularBuildCatalog.FLOOR_NATIVE_MESH_Y_MIN * sy
	var rim_center_y := slab_bottom_local_y - depth * 0.5 - 0.005
	var mat := _foundation_shared_material()
	var faces: Array[Dictionary] = [
		{"size": Vector3(span_x, depth, thick), "pos": Vector3(cx, rim_center_y, iz0 - thick * 0.5)},
		{"size": Vector3(span_x, depth, thick), "pos": Vector3(cx, rim_center_y, iz1 + thick * 0.5)},
		{"size": Vector3(thick, depth, span_z), "pos": Vector3(ix0 - thick * 0.5, rim_center_y, cz)},
		{"size": Vector3(thick, depth, span_z), "pos": Vector3(ix1 + thick * 0.5, rim_center_y, cz)},
	]
	for f in faces:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = f["size"] as Vector3
		mi.mesh = box
		mi.material_override = mat
		mi.position = f["pos"] as Vector3
		skirt_root.add_child(mi)

	if not _preview_mode:
		var body := get_node_or_null("CollisionRoot") as StaticBody3D
		if body != null:
			var inv_body := body.global_transform.affine_inverse()
			for mi2 in skirt_root.get_children():
				if mi2 is MeshInstance3D:
					var mesh: Mesh = (mi2 as MeshInstance3D).mesh
					if mesh == null or not (mesh is BoxMesh):
						continue
					var cs := CollisionShape3D.new()
					var bxsh := BoxShape3D.new()
					bxsh.size = (mesh as BoxMesh).size
					cs.shape = bxsh
					cs.transform = inv_body * (mi2 as Node3D).global_transform
					body.add_child(cs)


func _clear_foundation_skirt() -> void:
	var n := get_node_or_null(_FOUNDATION_SKIRT_NAME)
	if n != null:
		n.queue_free()


func _rebuild_visual() -> void:
	_clear_foundation_skirt()
	scale = ModularBuildCatalog.piece_scale_vector(piece_id)
	for c in get_children():
		c.queue_free()
	var path := ModularBuildCatalog.gltf_path_for(piece_id)
	if path.is_empty():
		push_warning("ModularBuildPiece: unknown piece_id '%s'" % piece_id)
		return
	var res: Resource = load(path)
	if res == null:
		push_warning("ModularBuildPiece: failed to load %s" % path)
		return
	if not (res is PackedScene):
		push_warning("ModularBuildPiece: not a PackedScene: %s" % path)
		return
	var inst: Node = (res as PackedScene).instantiate()
	var holder := Node3D.new()
	holder.name = "Visual"
	add_child(holder)
	holder.add_child(inst)
	if not _preview_mode:
		_add_collision(holder)


func _add_collision(visual_root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "CollisionRoot"
	add_child(body)
	_collect_mesh_collision(visual_root, body)


func _collect_mesh_collision(n: Node, body: StaticBody3D) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mesh: Mesh = mi.mesh
		if mesh != null:
			var tris: Shape3D = mesh.create_trimesh_shape()
			if tris != null:
				var cs := CollisionShape3D.new()
				cs.shape = tris
				cs.transform = global_transform.affine_inverse() * mi.global_transform
				body.add_child(cs)
	for c in n.get_children():
		_collect_mesh_collision(c, body)


func _clear_preview_surface_overrides() -> void:
	var meshes: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	for n in meshes:
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		if _is_under_foundation_skirt(mi):
			continue
		mi.material_override = null
		var surf_count := mi.mesh.get_surface_count() if mi.mesh != null else 0
		for s in range(surf_count):
			mi.set_surface_override_material(s, null)


func _apply_preview_tint(valid: bool) -> void:
	var tint := Color(0.2, 0.9, 0.35, 0.45) if valid else Color(0.95, 0.22, 0.22, 0.45)
	var meshes: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	for n in meshes:
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		if _is_under_foundation_skirt(mi):
			continue
		var surf_count := mi.mesh.get_surface_count() if mi.mesh != null else 0
		for s in range(surf_count):
			var mat: Material = mi.get_active_material(s)
			if mat == null and mi.mesh != null:
				mat = mi.mesh.surface_get_material(s)
			if mat == null or not (mat is BaseMaterial3D):
				continue
			var dup := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dup.albedo_color = tint
			dup.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			dup.no_depth_test = true
			mi.set_surface_override_material(s, dup)
