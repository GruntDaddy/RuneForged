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
var _was_on_floor_last_frame: bool = true
var _air_time: float = 0.0


#region agent log
func _agent_log(run_id: String, hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	var payload := {
		"sessionId": "c5ea88",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000
	}
	var path := "c:/Users/price/Desktop/Game Creation/3D Projects/rune_forged/debug-c5ea88.log"
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		path = ProjectSettings.globalize_path("res://debug-c5ea88.log")
		f = FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.close()
	var req := HTTPRequest.new()
	add_child(req)
	req.request(
		"http://127.0.0.1:7780/ingest/aa3393c7-0b4c-4042-9eeb-84c344b7ef69",
		["Content-Type: application/json", "X-Debug-Session-Id: c5ea88"],
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
#endregion


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
	#region agent log
	_agent_log(
		"initial",
		"H1",
		"player.gd:_ready",
		"Player ready; HUD + movement config",
		{
			"hasInventoryHud": inventory_hud != null,
			"gravity": _gravity,
			"jumpVelocity": jump_velocity,
			"moveSpeed": move_speed,
			"runMultiplier": run_multiplier
		}
	)
	#endregion


func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	if event.is_action_pressed("inventory") and inventory_hud:
		#region agent log
		_agent_log(
			"initial",
			"H1",
			"player.gd:_unhandled_input",
			"Inventory action received by player",
			{"mouseMode": Input.mouse_mode}
		)
		#endregion
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
			#region agent log
			_agent_log(
				"initial",
				"H5",
				"player.gd:_physics_process",
				"Jump pressed",
				{"velocityY": velocity.y, "gravity": _gravity}
			)
			#endregion
		else:
			velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
		_air_time += delta

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
	if not is_on_floor() and _was_on_floor_last_frame:
		_air_time = 0.0
	if is_on_floor() and not _was_on_floor_last_frame:
		#region agent log
		_agent_log(
			"initial",
			"H5",
			"player.gd:_physics_process",
			"Landed after jump/fall",
			{"airTime": _air_time, "horizontalSpeed": Vector2(velocity.x, velocity.z).length()}
		)
		#endregion
	_air_time = _air_time if not is_on_floor() else 0.0
	_was_on_floor_last_frame = is_on_floor()

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
		#region agent log
		_agent_log(
			"initial",
			"H3",
			"player.gd:_physics_process",
			"Attack input pressed",
			{
				"rayColliding": interaction_ray.is_colliding(),
				"rayOrigin": interaction_ray.global_position,
				"rayTarget": interaction_ray.to_global(interaction_ray.target_position)
			}
		)
		#endregion
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
		#region agent log
		_agent_log("initial", "H3", "player.gd:_try_harvest_hit", "Ray did not hit harvest target")
		#endregion
		return
	var collider: Object = interaction_ray.get_collider()
	if collider == null:
		#region agent log
		_agent_log("initial", "H3", "player.gd:_try_harvest_hit", "Ray collider is null")
		#endregion
		return
	#region agent log
	_agent_log(
		"initial",
		"H3",
		"player.gd:_try_harvest_hit",
		"Ray hit collider",
		{"colliderClass": collider.get_class(), "colliderPath": str((collider as Node).get_path()) if collider is Node else "not-node"}
	)
	#endregion
	var action := "chop"
	if collider.has_method("get_harvest_action"):
		action = collider.get_harvest_action()
	if base_character.has_method("try_play_action_for_harvest"):
		base_character.try_play_action_for_harvest(action)
	if collider.has_method("harvest_hit"):
		collider.harvest_hit()
