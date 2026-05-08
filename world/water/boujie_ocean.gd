@tool
extends Node3D
## Wraps addon `deep_ocean.tscn`: registers `water_surface` group API for the player,
## keeps sea level at fixed Y (CameraFollower uses X+Z only), and configures Boujie waves
## for less tiling (phases, extra layers) and softer shore reads.

const _BoujieWaveHeight = preload("res://world/water/boujie_wave_height.gd")

const _HEIGHT4 := "res://assets/water/boujie/height_waves/height4.tres"
const _HEIGHT2 := "res://assets/water/boujie/height_waves/height2.tres"
const _FOAM1 := "res://assets/water/boujie/foam_waves/foam1.tres"
const _FOAM2 := "res://assets/water/boujie/foam_waves/foam2.tres"
const _FOAM3 := "res://assets/water/boujie/foam_waves/foam3.tres"
const _FOAM4 := "res://assets/water/boujie/foam_waves/foam4.tres"
const _UVW1 := "res://assets/water/boujie/uv_waves/uvwave1.tres"
const _UVW2 := "res://assets/water/boujie/uv_waves/uvwave2.tres"

@export var water_level: float = 1.0:
	set(value):
		water_level = value
		_apply_water_level()

## Large horizontal extent so `_get_active_water_level` finds this ocean while the mesh follows the camera.
@export var plane_size: Vector2 = Vector2(50000, 50000)
## Added to sampled Gerstner height. Negative pulls gameplay (player, fish buoyancy) slightly below the CPU-averaged vertex stack so bodies track troughs/refraction better than raw `sample_vertex_wave_average_y`.
@export var gameplay_height_adjustment: float = -0.26
## Seconds subtracted from the CPU wave clock so sampled Gerstner phase trails rendered crests slightly (shader uses built-in TIME + render clock; physics queries often run earlier in the frame).
@export var gameplay_wave_sample_time_offset_sec: float = -0.072

var _material_instance: ShaderMaterial


func get_water_surface_height_at(world_position: Vector3) -> float:
	if _material_instance == null:
		_ensure_unique_material()
	if _material_instance == null:
		return water_level + gameplay_height_adjustment
	var cam := get_viewport().get_camera_3d()
	var cam_pos: Vector3 = cam.global_position if cam else world_position
	var t: float = Time.get_ticks_msec() * 0.001 + gameplay_wave_sample_time_offset_sec
	var dy: float = _BoujieWaveHeight.sample_vertex_wave_average_y(
		_material_instance,
		world_position.x,
		world_position.z,
		t,
		cam_pos,
		water_level
	)
	return water_level + dy + gameplay_height_adjustment


func _enter_tree() -> void:
	var follower := get_node_or_null("DeepOcean/CameraFollower3D")
	if follower != null:
		# Explicit X+Z only — sea Y must not track the camera (matches addon default 5).
		follower.follow_axes = 1 | 4


func _ready() -> void:
	add_to_group(&"water_surface")
	_apply_water_level()
	_ensure_unique_material()
	_configure_north_swell_waves()


func _apply_water_level() -> void:
	if not is_inside_tree():
		return
	var ocean := get_node_or_null("DeepOcean") as Node3D
	if ocean == null:
		return
	var p := ocean.global_position
	ocean.global_position = Vector3(p.x, water_level, p.z)


func _ensure_unique_material() -> ShaderMaterial:
	if _material_instance != null:
		return _material_instance
	var designer := get_node_or_null("DeepOcean/WaterMaterialDesigner") as WaterMaterialDesigner
	var ocean_node := get_node_or_null("DeepOcean")
	if designer == null or designer.material == null:
		return null
	_material_instance = designer.material.duplicate() as ShaderMaterial
	designer.material = _material_instance
	if ocean_node is Ocean:
		(ocean_node as Ocean).material = _material_instance
	return _material_instance


func _configure_north_swell_waves() -> void:
	var designer := get_node_or_null("DeepOcean/WaterMaterialDesigner") as WaterMaterialDesigner
	if designer == null:
		return
	if _material_instance == null:
		_ensure_unique_material()
	if designer.material == null:
		return

	# --- Height waves (7): dominant +Z swell + cross chop + varied phases (breaks grid sync) ---
	var h4 := load(_HEIGHT4).duplicate() as GerstnerWave
	h4.direction_degrees = 42.0
	h4.phase_degrees = 83.0

	var h2 := load(_HEIGHT2).duplicate() as GerstnerWave
	h2.direction_degrees = 288.0
	h2.phase_degrees = 241.0

	var height_waves: Array[GerstnerWave] = [
		_make_wave(10.0, 2.0, 0.0, 0.02, 1.0, 0.0),
		_make_wave(0.05, 0.004, 95.0, 2.0, 1.0, 127.0),
		h4,
		h2,
		_make_wave(1.2, 0.35, 158.0, 0.035, 1.2, 19.0),
		_make_wave(0.4, 0.25, 72.0, 0.055, 1.4, 305.0),
		_make_wave(0.55, 0.2, 220.0, 0.045, 0.9, 167.0),
	]

	# --- Foam waves (6): duplicate presets + staggered phases (less repeating foam pattern) ---
	var f1 := load(_FOAM1).duplicate() as GerstnerWave
	f1.phase_degrees = 31.0
	var f2 := load(_FOAM2).duplicate() as GerstnerWave
	f2.phase_degrees = 187.0
	var f3 := load(_FOAM3).duplicate() as GerstnerWave
	f3.phase_degrees = 263.0
	var f4 := load(_FOAM4).duplicate() as GerstnerWave
	f4.phase_degrees = 97.0
	var f5 := load(_FOAM1).duplicate() as GerstnerWave
	f5.direction_degrees = 142.0
	f5.phase_degrees = 339.0
	var f6 := load(_FOAM2).duplicate() as GerstnerWave
	f6.direction_degrees = 48.0
	f6.phase_degrees = 71.0

	var foam_waves: Array[GerstnerWave] = [f1, f2, f3, f4, f5, f6]

	# --- UV waves (3): break triplanar / foam texture tiling ---
	var uv1 := load(_UVW1).duplicate() as GerstnerWave
	uv1.phase_degrees = 41.0
	var uv2 := load(_UVW2).duplicate() as GerstnerWave
	uv2.phase_degrees = 263.0
	var uv3 := GerstnerWave.new()
	uv3.steepness = 0.06
	uv3.amplitude = 0.4
	uv3.direction_degrees = 180.0
	uv3.frequency = 0.35
	uv3.speed = 0.5
	uv3.phase_degrees = 119.0

	var uv_waves: Array[GerstnerWave] = [uv1, uv2, uv3]

	designer.height_waves = height_waves
	designer.foam_waves = foam_waves
	designer.uv_waves = uv_waves
	designer.update()

	_apply_material_surface_tweaks(_material_instance)


func _make_wave(
	steepness: float,
	amplitude: float,
	direction_degrees: float,
	frequency: float,
	speed: float,
	phase_degrees: float
) -> GerstnerWave:
	var w := GerstnerWave.new()
	w.steepness = steepness
	w.amplitude = amplitude
	w.direction_degrees = direction_degrees
	w.frequency = frequency
	w.speed = speed
	w.phase_degrees = phase_degrees
	return w


func _apply_material_surface_tweaks(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	# CPU sampling (`boujie_wave_height.gd`) uses global +Y Gerstner displacement only. With this ON,
	# Boujie rotates displacement by mesh normals (LOD ring seams / curvature), so rendered surface Y can
	# sit below our gameplay height at the same XZ — entities look stranded above troughs. Flat ocean +
	# global-up matches the CPU mirror.
	mat.set_shader_parameter(&"vertex_displace_from_mesh_normal", false)
	# Larger triplanar scale = less obvious texture repeat on foam/albedo.
	mat.set_shader_parameter(&"uv_tri_scale", Vector3(52.0, 52.0, 52.0))
	mat.set_shader_parameter(&"uv_blend_sharpness", 1.65)
	mat.set_shader_parameter(&"uv_tri_offset", Vector3(0.37, 0.21, -0.13))
	# Slightly wider depth blend at shore (meters): softer contact on E/W coasts.
	mat.set_shader_parameter(&"shore_start_blend", 1.8)
	mat.set_shader_parameter(&"shore_end_blend", 7.5)
