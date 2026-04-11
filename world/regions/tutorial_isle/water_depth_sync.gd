extends MeshInstance3D
## Supplies view matrices to tutorial_water.gdshader — D3D12/Forward+ fragment stage lacks VIEW_MATRIX.

const _LOG_REL := "res://debug-77cfd5.log"

@export var toward_land: Vector2 = Vector2(0.65, 0.52)
@export var shore_reference_xz: Vector2 = Vector2(130.0, 115.0)


func _ready() -> void:
	# Gerstner displacement moves vertices horizontally; expand AABB so the mesh is not frustum-culled in strips.
	custom_aabb = AABB(Vector3(-400.0, -6.0, -400.0), Vector3(800.0, 12.0, 800.0))
	# region agent log
	_dbg("H3", "water_depth_sync_ready", { "has_override": material_override != null })
	# endregion
	_sync_camera_matrices()


func _process(_delta: float) -> void:
	_sync_camera_matrices()


func _sync_camera_matrices() -> void:
	var mat := material_override as ShaderMaterial
	if mat == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		# region agent log
		_dbg("H4", "no_active_camera_3d", {})
		# endregion
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
	# region agent log
	if Engine.get_frames_drawn() == 1:
		_dbg("H5", "all_cam_mats_set_frame1", {
			"cam_path": str(cam.get_path()),
			"inv_proj_ok": true
		})
	if Engine.get_frames_drawn() == 2:
		_dbg("H6", "water_visibility_cull_guard", {
			"custom_aabb_size": [custom_aabb.size.x, custom_aabb.size.y, custom_aabb.size.z],
			"cam_far": cam.far
		})
		_dbg("H1", "wave_direction_semantics", {
			"toward_land_export": [toward_land.x, toward_land.y],
			"toward_land_normalized": [toward_land.normalized().x, toward_land.normalized().y] if toward_land.length_squared() > 0.0001 else [0.0, 0.0],
			"shader_uses": "negated_normalize_for_gerstner_phase_toward_shore"
		})
		_dbg("H2", "reflection_params_runtime", {
			"roughness": mat.get_shader_parameter(&"roughness"),
			"specular_amount": mat.get_shader_parameter(&"specular_amount"),
			"horizon_sky_mix": mat.get_shader_parameter(&"horizon_sky_mix"),
			"fresnel_intensity": mat.get_shader_parameter(&"fresnel_intensity"),
			"shallow_color_str": str(mat.get_shader_parameter(&"shallow_color"))
		})
	# endregion


func _dbg(hypothesis_id: String, message: String, data: Dictionary) -> void:
	var path := ProjectSettings.globalize_path(_LOG_REL)
	var f: FileAccess
	if FileAccess.file_exists(path):
		f = FileAccess.open(path, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	var payload := {
		"sessionId": "77cfd5",
		"hypothesisId": hypothesis_id,
		"location": "water_depth_sync.gd",
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec(),
		"runId": "pre-fix"
	}
	f.store_line(JSON.stringify(payload))
	f.close()
