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


## Builds or rebuilds uneven-brick perimeter walls under the raised floor slab (tops just below deck). Pass `floor_iy < 0` to only remove the skirt (e.g. invalid ghost cell).
func apply_foundation_skirt(_terrain_deck_y: float, floor_iy: int = 0) -> void:
	_clear_foundation_skirt()
	if floor_iy < 0:
		return
	# Preview ghost: skip 4× full wall meshes (huge material/descriptor churn when this runs every frame).
	if _preview_mode:
		return
	if floor_iy != 0:
		return
	if not ModularBuildCatalog.foundation_skirt_enabled(piece_id):
		return
	var skirt_path := ModularBuildCatalog.gltf_path_for(ModularBuildCatalog.foundation_skirt_wall_piece_id())
	if skirt_path.is_empty():
		return
	var res: Resource = load(skirt_path)
	if res == null or not (res is PackedScene):
		return
	var wall_scene: PackedScene = res as PackedScene

	var skirt_root := Node3D.new()
	skirt_root.name = _FOUNDATION_SKIRT_NAME
	add_child(skirt_root)

	var half := ModularBuildCatalog.CELL_SIZE * 0.5
	var bx := global_transform.basis.x.normalized()
	var bz := global_transform.basis.z.normalized()

	var specs: Array[Dictionary] = [
		{"pos": global_position - bz * half, "xax": bx},
		{"pos": global_position + bz * half, "xax": bx},
		{"pos": global_position - bx * half, "xax": bz},
		{"pos": global_position + bx * half, "xax": bz},
	]
	var skirt_y := ModularBuildCatalog.foundation_skirt_wall_root_y(global_position.y, scale.y)
	for spec in specs:
		var wpos: Vector3 = spec["pos"]
		wpos.y = skirt_y
		var xax: Vector3 = spec["xax"]
		var seg := Node3D.new()
		skirt_root.add_child(seg)
		seg.global_transform = Transform3D(_ortho_basis_x_up(xax), wpos)
		var inst: Node = wall_scene.instantiate()
		seg.add_child(inst)

	if not _preview_mode:
		var body := get_node_or_null("CollisionRoot") as StaticBody3D
		if body != null:
			for seg2 in skirt_root.get_children():
				_collect_mesh_collision(seg2, body)


func _clear_foundation_skirt() -> void:
	var n := get_node_or_null(_FOUNDATION_SKIRT_NAME)
	if n != null:
		n.queue_free()


func _ortho_basis_x_up(x_axis: Vector3) -> Basis:
	var x := x_axis.normalized()
	var up := Vector3.UP
	if absf(x.dot(up)) > 0.98:
		up = Vector3.FORWARD
	var z := x.cross(up)
	if z.length_squared() < 1e-8:
		z = x.cross(Vector3.RIGHT)
	z = z.normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z).orthonormalized()


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
