extends Node3D
## Drives sun/moon sky shader, DirectionalLight3D, and ambient for a full day-night cycle.
## Expects a sibling DirectionalLight3D and WorldEnvironment (paths configurable).

@export var day_length_seconds: float = 90.0
@export_range(0.0, 1.0) var start_time_of_day: float = 0.32

@export_group("Light")
@export var sun_energy_max: float = 0.85
@export var moon_light_energy: float = 0.22
@export var sun_color_day: Color = Color(1.0, 0.97, 0.88)
@export var sun_color_sunset: Color = Color(1.0, 0.62, 0.38)
@export var moon_light_color: Color = Color(0.52, 0.62, 0.92)

@export_group("Ambient")
@export var ambient_energy_day: float = 0.5
@export var ambient_energy_night: float = 0.22
@export var ambient_color_day: Color = Color(0.45, 0.52, 0.58)
@export var ambient_color_night: Color = Color(0.16, 0.18, 0.28)

@export_group("Nodes")
@export var directional_light_path: NodePath = ^"../DirectionalLight3D"
@export var world_environment_path: NodePath = ^"../WorldEnvironment"

var _time_of_day: float = 0.32
var _sky_material: ShaderMaterial


func _ready() -> void:
	_time_of_day = start_time_of_day
	var we: WorldEnvironment = get_node_or_null(world_environment_path) as WorldEnvironment
	if we != null and we.environment != null:
		var sky: Sky = we.environment.sky
		if sky != null and sky.sky_material is ShaderMaterial:
			_sky_material = sky.sky_material
	# region agent log
	_dbg_sky("H3", "day_night_ready", { "sky_mat_ok": _sky_material != null })
	# endregion
	_apply_time()


func _dbg_sky(hypothesis_id: String, message: String, data: Dictionary) -> void:
	var path := ProjectSettings.globalize_path("res://debug-77cfd5.log")
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
		"location": "day_night_controller.gd",
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec(),
		"runId": "pre-fix"
	}
	f.store_line(JSON.stringify(payload))
	f.close()


func _process(delta: float) -> void:
	if day_length_seconds <= 0.001:
		return
	_time_of_day = fmod(_time_of_day + delta / day_length_seconds, 1.0)
	_apply_time()


func set_time_of_day(t: float) -> void:
	_time_of_day = fmod(clampf(t, 0.0, 0.999999), 1.0)
	_apply_time()


func get_time_of_day() -> float:
	return _time_of_day


func _sun_direction() -> Vector3:
	# 0.25 ≈ sunrise, 0.5 ≈ noon, 0.75 ≈ sunset; slight Z sway for depth
	var angle: float = (_time_of_day - 0.25) * TAU
	return Vector3(-cos(angle), sin(angle), -sin(angle) * 0.28).normalized()


func _apply_time() -> void:
	var sun_dir: Vector3 = _sun_direction()
	var height: float = sun_dir.y
	var day_f: float = smoothstep(-0.12, 0.22, height)
	var sunset_f: float = smoothstep(0.02, 0.22, height) * (1.0 - smoothstep(0.12, 0.42, height))
	sunset_f = clampf(sunset_f * 1.35, 0.0, 1.0)

	var dl: DirectionalLight3D = get_node_or_null(directional_light_path) as DirectionalLight3D
	if dl != null:
		# Day: light from sun direction. Night: slerp toward moon (-sun_dir) so moonlit side gets cool fill.
		var anchor: Vector3 = dl.global_position
		# Full moon direction when day_f low; fade out by mid-morning so sunlight stays coherent.
		var moon_influence: float = 1.0 - smoothstep(0.08, 0.42, day_f)
		var lit_dir: Vector3 = sun_dir.slerp(-sun_dir, moon_influence)
		if lit_dir.length_squared() < 1e-10:
			lit_dir = sun_dir
		else:
			lit_dir = lit_dir.normalized()
		dl.look_at(anchor - lit_dir, Vector3.UP)

		var e: float = lerpf(moon_light_energy, sun_energy_max, day_f)
		dl.light_energy = e
		var c: Color = moon_light_color.lerp(sun_color_day, day_f)
		c = c.lerp(sun_color_sunset, sunset_f * (1.0 - day_f * 0.35) * clampf(day_f * 1.5, 0.0, 1.0))
		dl.light_color = c

	if _sky_material != null:
		_sky_material.set_shader_parameter(&"sun_direction", sun_dir)
		_sky_material.set_shader_parameter(&"day_factor", day_f)
		_sky_material.set_shader_parameter(&"sunset_factor", sunset_f)

	var we: WorldEnvironment = get_node_or_null(world_environment_path) as WorldEnvironment
	if we != null and we.environment != null:
		var env: Environment = we.environment
		env.ambient_light_energy = lerpf(ambient_energy_night, ambient_energy_day, day_f)
		env.ambient_light_color = ambient_color_night.lerp(ambient_color_day, day_f)
