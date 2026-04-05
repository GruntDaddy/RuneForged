extends CharacterBody3D

@export var move_speed: float = 5.0
@export var run_multiplier: float = 1.45
@export var turn_speed: float = 10.0
@export var jump_velocity: float = 6.0

@onready var base_character: Node3D = $BaseCharacter
@onready var camera_rig: Node3D = $CameraRig

var _input_enabled: bool = true
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled


func _ready() -> void:
	_apply_from_gamestate()


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
	var dir := Vector3(input_vec.x, 0.0, input_vec.y)

	var speed := move_speed * (run_multiplier if Input.is_action_pressed("run") else 1.0)

	if dir.length() > 0.0:
		dir = dir.normalized()
		var target_rot := atan2(dir.x, dir.z)
		base_character.rotation.y = lerp_angle(base_character.rotation.y, target_rot, turn_speed * delta)

		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()


func _apply_from_gamestate() -> void:
	if GameState.player_name != "":
		name = GameState.player_name
	if base_character.has_method("apply_customization"):
		base_character.apply_customization(
			GameState.head_index,
			GameState.shirt_index,
			GameState.pants_index,
			GameState.gender
		)
