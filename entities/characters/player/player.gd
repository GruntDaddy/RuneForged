extends CharacterBody3D

const _GameState = preload("res://autoload/game_state.gd")

@export var move_speed: float = 5.0
@export var run_multiplier: float = 1.45
@export var turn_speed: float = 12.0
@export var jump_velocity: float = 6.0
@export var mouse_sensitivity: float = 0.003
@export var min_pitch_rad: float = -1.2
@export var max_pitch_rad: float = 0.65

@onready var base_character: Node3D = $BaseCharacter
@onready var camera_rig: Node3D = $CameraRig
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D

var _input_enabled: bool = true
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	_apply_from_gamestate()
	if _input_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rig.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotation.x = clamp(
			spring_arm.rotation.x - event.relative.y * mouse_sensitivity,
			min_pitch_rad,
			max_pitch_rad
		)


func _physics_process(delta: float) -> void:
	if not _input_enabled:
		return

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
		else:
			velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := camera_rig.global_transform.basis
	var dir := cam_basis * Vector3(input_vec.x, 0.0, input_vec.y)
	dir.y = 0.0

	var running := Input.is_action_pressed("run")
	var speed := move_speed * (run_multiplier if running else 1.0)

	if dir.length_squared() > 0.0001:
		dir = dir.normalized()
		var target_rot := atan2(dir.x, dir.z)
		base_character.rotation.y = lerp_angle(base_character.rotation.y, target_rot, turn_speed * delta)

		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var moving := horizontal_speed > 0.15
	if base_character.has_method("set_locomotion_state"):
		base_character.set_locomotion_state(moving, running, is_on_floor())


func _apply_from_gamestate() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null or not (gs is _GameState):
		return
	var state := gs as _GameState
	if state.player_name != "":
		name = state.player_name
	if base_character.has_method("apply_customization"):
		base_character.apply_customization(state.head_index, state.shirt_index, state.pants_index)
