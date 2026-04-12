extends MeshInstance3D
## Supplies view matrices to rune_water.gdshader — D3D12/Forward+ fragment stage lacks VIEW_MATRIX.
## Duplicates material_override in _enter_tree (before _ready) so exports cannot mutate the shared .tres.

@export var water_level: float = 1.0:
	set(value):
		water_level = value
		_sync_water_level()

@export var plane_size: Vector2 = Vector2(1100, 1100)
@export var subdivisions: Vector2i = Vector2i(96, 96)
@export var toward_land: Vector2 = Vector2(0.65, 0.52)
@export var shore_reference_xz: Vector2 = Vector2(130.0, 115.0)


func _enter_tree() -> void:
	# Instance-safe: shared .tres defaults must not mutate across WaterSurface instances.
	if material_override != null:
		material_override = material_override.duplicate()


func _ready() -> void:
	_rebuild_mesh()
	_sync_water_level()
	_sync_camera_matrices()


func _process(_delta: float) -> void:
	_sync_camera_matrices()


func _rebuild_mesh() -> void:
	var pm := PlaneMesh.new()
	pm.size = plane_size
	pm.subdivide_width = maxi(1, subdivisions.x)
	pm.subdivide_depth = maxi(1, subdivisions.y)
	mesh = pm
	_update_custom_aabb()


func _update_custom_aabb() -> void:
	var half_w := plane_size.x * 0.5
	var half_d := plane_size.y * 0.5
	var margin := 40.0
	custom_aabb = AABB(
		Vector3(-half_w - margin, -6.0, -half_d - margin),
		Vector3(plane_size.x + margin * 2.0, 12.0, plane_size.y + margin * 2.0)
	)


func _sync_water_level() -> void:
	if not is_inside_tree():
		return
	global_position.y = water_level
	var mat := material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"water_level", water_level)


func _sync_camera_matrices() -> void:
	var mat := material_override as ShaderMaterial
	if mat == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var inv_view: Transform3D = cam.global_transform
	var view: Transform3D = cam.global_transform.affine_inverse()
	var inv_proj: Projection = cam.get_camera_projection().inverse()
	mat.set_shader_parameter(&"inv_view_matrix", inv_view)
	mat.set_shader_parameter(&"view_matrix", view)
	mat.set_shader_parameter(&"inv_projection_matrix", inv_proj)
	if toward_land.length_squared() > 0.0001:
		mat.set_shader_parameter(&"toward_land_xz", toward_land.normalized())
	mat.set_shader_parameter(&"shore_reference_xz", shore_reference_xz)
