extends Node3D
class_name ModularBuildPiece

const GROUP_NAME := "modular_build_piece"

@export var placement_id: String = ""
@export var owner_key: String = ModularBuildCatalog.OWNER_PLAYER
@export var piece_id: String = ""

var _preview_mode: bool = false


func configure(p_pid: String, p_placement_id: String, p_owner: String, preview: bool = false) -> void:
	piece_id = p_pid
	placement_id = p_placement_id
	owner_key = p_owner
	_preview_mode = preview
	if not preview:
		add_to_group(GROUP_NAME)
		name = "ModularPiece_%s" % p_placement_id
	else:
		name = "ModularPiecePreview"
	_rebuild_visual()


func refresh_preview_tint(valid: bool) -> void:
	if not _preview_mode:
		return
	_apply_preview_tint(valid)


func _rebuild_visual() -> void:
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
