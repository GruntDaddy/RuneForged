extends Node3D

@export var rotation_speed: float = 15.0
@export var float_height: float = 0.08
@export var float_speed: float = 2.0

@onready var player: CharacterBody3D = get_node_or_null("Player")
@onready var preview_cam: Camera3D = get_node_or_null("Camera3D")

var _base_y: float


func _ready() -> void:
	_base_y = position.y

	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)
	else:
		push_warning("PreviewRoot: Player node not found or missing set_input_enabled().")

	_setup_preview_camera()
	_setup_preview_lighting()


func _setup_preview_camera() -> void:
	var player_cam := player.get_node_or_null("CameraRig/SpringArm3D/Camera3D") if player else null
	if player_cam is Camera3D:
		(player_cam as Camera3D).current = false
	if preview_cam:
		preview_cam.current = true
		preview_cam.position = Vector3(0.0, 1.35, 3.15)
		preview_cam.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)


func _setup_preview_lighting() -> void:
	# SubViewport has its own World3D: no lights were present, so PBR meshes rendered black.
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.82, 0.92)
	env.ambient_light_energy = 0.45
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-58.0, 32.0, 0.0)
	key.light_energy = 1.15
	key.shadow_enabled = true
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, -140.0, 0.0)
	fill.light_energy = 0.35
	add_child(fill)


func _process(delta: float) -> void:
	rotate_y(deg_to_rad(rotation_speed * delta))

	var t := Time.get_ticks_msec() * 0.001
	position.y = _base_y + sin(t * float_speed) * float_height
