extends CharacterBody3D

const _GameState = preload("res://autoload/game_state.gd")
const _BaseCharacter = preload("res://entities/characters/base_character/base_character.gd")

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
@onready var camera_3d: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var interaction_ray: RayCast3D = $RayCast3D
@onready var inventory_hud: CanvasLayer = $PlayerInventoryHud

@export var interaction_range: float = 4.0

var _input_enabled: bool = true
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	add_to_group("player")
	_apply_from_gamestate()
	if _input_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	if event.is_action_pressed("inventory") and inventory_hud:
		inventory_hud.toggle_inventory()
		get_viewport().set_input_as_handled()
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
	var cam_basis := camera_3d.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	var right := cam_basis.x
	right.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	if right.length_squared() > 0.0001:
		right = right.normalized()
	var dir := right * input_vec.x + forward * (-input_vec.y)

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

	interaction_ray.global_transform = camera_3d.global_transform
	interaction_ray.target_position = Vector3(0.0, 0.0, -interaction_range)
	interaction_ray.force_raycast_update()

	if Input.is_action_just_pressed("tool_axe"):
		_set_player_tool(_BaseCharacter.ToolKind.AXE)
	if Input.is_action_just_pressed("tool_pickaxe"):
		_set_player_tool(_BaseCharacter.ToolKind.PICKAXE)
	if Input.is_action_just_pressed("tool_hands"):
		_set_player_tool(_BaseCharacter.ToolKind.NONE)

	if Input.is_action_just_pressed("attack"):
		_try_harvest_hit()

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


func _set_player_tool(kind: _BaseCharacter.ToolKind) -> void:
	if base_character.has_method("set_active_tool"):
		base_character.set_active_tool(kind)


func _try_harvest_hit() -> void:
	if not interaction_ray.is_colliding():
		return
	var collider: Object = interaction_ray.get_collider()
	if collider == null:
		return
	var action := "chop"
	if collider.has_method("get_harvest_action"):
		action = collider.get_harvest_action()
	if base_character.has_method("try_play_action_for_harvest"):
		base_character.try_play_action_for_harvest(action)
	if collider.has_method("harvest_hit"):
		collider.harvest_hit()
