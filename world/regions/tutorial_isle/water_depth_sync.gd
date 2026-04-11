extends MeshInstance3D
## Supplies view matrices to tutorial_water.gdshader — D3D12/Forward+ fragment stage lacks VIEW_MATRIX.

const _LOG_REL := "res://debug-77cfd5.log"


func _ready() -> void:
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
	# region agent log
	if Engine.get_frames_drawn() == 1:
		_dbg("H5", "all_cam_mats_set_frame1", {
			"cam_path": str(cam.get_path()),
			"inv_proj_ok": true
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
