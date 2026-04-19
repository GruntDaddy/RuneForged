class_name BoujieWaveHeight
extends RefCounted
## CPU mirror of `addons/boujie_water_shader/shader/water.gdshader` vertex wave stack (`P_DEG` + average + optional fade).
## Keep in sync with the shader's `P_DEG` / `VERTEX_WAVE` block.

static func p_deg(
	x: float,
	z: float,
	t: float,
	steepness: float,
	amplitude: float,
	direction_degrees: float,
	frequency: float,
	speed: float,
	phase_degrees: float
) -> Vector3:
	var dir_x: float = sin(deg_to_rad(direction_degrees))
	var dir_z: float = cos(deg_to_rad(direction_degrees))
	var p: float = deg_to_rad(phase_degrees)
	var phase: float = TAU * (frequency * dir_x * x + frequency * dir_z * z) + speed * (t + p)
	var c: float = cos(phase)
	var s: float = sin(phase)
	var qx: float = (steepness * amplitude) * dir_x * c
	var qy: float = steepness * s
	var qz: float = (steepness * amplitude) * dir_z * c
	return Vector3(qx, qy, qz)


## Returns averaged vertex-wave Y offset (before adding base sea level), matching shader averaging and fade.
static func sample_vertex_wave_average_y(
	mat: ShaderMaterial,
	world_x: float,
	world_z: float,
	time_sec: float,
	camera_world_pos: Vector3,
	base_sea_y: float
) -> float:
	if mat == null:
		return 0.0
	var freeze: Variant = mat.get_shader_parameter(&"freeze_time")
	if freeze == true:
		time_sec = 0.0

	var count_v: Variant = mat.get_shader_parameter(&"WaveCount")
	var count: int = int(count_v) if count_v != null else 0
	if count <= 0:
		return 0.0

	var steep: PackedFloat32Array = mat.get_shader_parameter(&"WaveSteepnesses")
	var amp: PackedFloat32Array = mat.get_shader_parameter(&"WaveAmplitudes")
	var dirs: PackedFloat32Array = mat.get_shader_parameter(&"WaveDirectionsDegrees")
	var freqs: PackedFloat32Array = mat.get_shader_parameter(&"WaveFrequencies")
	var speeds: PackedFloat32Array = mat.get_shader_parameter(&"WaveSpeeds")
	var phases: PackedFloat32Array = mat.get_shader_parameter(&"WavePhases")

	var acc_y: float = 0.0
	for i in range(mini(count, 8)):
		var st: float = steep[i] if i < steep.size() else 0.0
		var am: float = amp[i] if i < amp.size() else 0.0
		var d: float = dirs[i] if i < dirs.size() else 0.0
		var fq: float = freqs[i] if i < freqs.size() else 0.0
		var sp: float = speeds[i] if i < speeds.size() else 0.0
		var ph: float = phases[i] if i < phases.size() else 0.0
		var disp: Vector3 = p_deg(world_x, world_z, time_sec, st, am, d, fq, sp, ph)
		# Flat ocean mesh: NORMAL is up; addon rotates displacement by mesh normal (ocean plane → unchanged).
		acc_y += disp.y
	acc_y /= float(count)

	var vfade: float = 1.0
	var fmax_v: Variant = mat.get_shader_parameter(&"vertex_wave_fade_max")
	var fmin_v: Variant = mat.get_shader_parameter(&"vertex_wave_fade_min")
	if fmax_v is float and fmin_v is float:
		var fmax: float = fmax_v
		var fmin: float = fmin_v
		var sample := Vector3(world_x, base_sea_y, world_z)
		var dist: float = sample.distance_to(camera_world_pos)
		# Match shader intent: full wave strength near camera, fall off with distance.
		var lo: float = minf(fmin, fmax)
		var hi: float = maxf(fmin, fmax)
		vfade = clampf(1.0 - smoothstep(lo, hi, dist), 0.0, 1.0)

	return acc_y * vfade
