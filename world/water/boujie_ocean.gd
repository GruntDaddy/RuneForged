@tool
extends Node3D
## Wraps addon `deep_ocean.tscn`: registers `water_surface` group API for the player,
## keeps sea level at fixed Y (CameraFollower uses X+Z only), and applies swells toward +Z (north).

const _HEIGHT4 := "res://addons/boujie_water_shader/example/boujie_water_shader/height_waves/height4.tres"
const _HEIGHT2 := "res://addons/boujie_water_shader/example/boujie_water_shader/height_waves/height2.tres"

@export var water_level: float = 1.0:
	set(value):
		water_level = value
		_apply_water_level()

## Large horizontal extent so `_get_active_water_level` finds this ocean while the mesh follows the camera.
@export var plane_size: Vector2 = Vector2(50000, 50000)

func _enter_tree() -> void:
	var follower := get_node_or_null("DeepOcean/CameraFollower3D")
	if follower != null:
		# Explicit X+Z only — sea Y must not track the camera (matches addon default 5).
		follower.follow_axes = 1 | 4


func _ready() -> void:
	add_to_group(&"water_surface")
	_apply_water_level()
	_configure_north_swell_waves()


func _apply_water_level() -> void:
	if not is_inside_tree():
		return
	var ocean := get_node_or_null("DeepOcean") as Node3D
	if ocean == null:
		return
	var p := ocean.global_position
	ocean.global_position = Vector3(p.x, water_level, p.z)


func _configure_north_swell_waves() -> void:
	var designer := get_node_or_null("DeepOcean/WaterMaterialDesigner") as WaterMaterialDesigner
	if designer == null or designer.material == null:
		return
	# Primary swell toward +Z (north); cross swells for chop (1 m units).
	var w1 := GerstnerWave.new()
	w1.steepness = 10.0
	w1.amplitude = 2.0
	w1.direction_degrees = 0.0
	w1.frequency = 0.02
	w1.speed = 1.0
	w1.phase_degrees = 0.0

	var w2 := GerstnerWave.new()
	w2.steepness = 0.05
	w2.amplitude = 0.004
	w2.direction_degrees = 95.0
	w2.frequency = 2.0
	w2.speed = 1.0
	w2.phase_degrees = 0.0

	var h4 := load(_HEIGHT4).duplicate() as GerstnerWave
	h4.direction_degrees = 42.0

	var h2 := load(_HEIGHT2).duplicate() as GerstnerWave
	h2.direction_degrees = 288.0

	designer.height_waves = [w1, w2, h4, h2]
	designer.update()
