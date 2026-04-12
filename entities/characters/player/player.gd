extends CharacterBody3D

const _GameState = preload("res://autoload/game_state.gd")
const _BaseCharacter = preload("res://entities/characters/base_character/base_character.gd")

const _H_INVALID := 0
const _H_WHIFF := 1
const _H_SUCCESS := 2
const _H_INV_FULL := 3

@export var move_speed: float = 3.15
@export var run_multiplier: float = 2.6
@export var turn_speed: float = 12.0
@export var jump_velocity: float = 5.5
@export var mouse_sensitivity: float = 0.003
@export var min_pitch_rad: float = -1.2
@export var max_pitch_rad: float = 0.65
@export var gravity_multiplier: float = 1.35
@export var interaction_range: float = 3.45
@export var interaction_height: float = 1.35
## Harvest/interaction ray uses character facing (not camera look). Slight downward bias helps short ground nodes.
@export var harvest_ray_downward_blend: float = 0.22
@export var harvest_click_cooldown_sec: float = 1.5
@export var chop_animation_duration_sec: float = 1.3
@export var chop_impact_delays_sec: PackedFloat32Array = PackedFloat32Array([0.5])
@export var mine_animation_duration_sec: float = 1.7
@export var mine_impact_delays_sec: PackedFloat32Array = PackedFloat32Array([0.3])

@export_group("Water")
@export var water_buoyancy_strength: float = 16.0
@export var water_gravity_scale: float = 0.22
@export var water_vertical_drag: float = 4.5
@export var water_horizontal_drag: float = 0.88
@export var water_jump_multiplier: float = 0.55
@export var water_max_effect_depth: float = 18.0
@export var underwater_fog_density_max: float = 0.085
@export var underwater_fog_density_min: float = 0.028

@onready var base_character: Node3D = $BaseCharacter
@onready var camera_rig: Node3D = $CameraRig
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var camera_3d: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var interaction_ray: RayCast3D = $RayCast3D
@onready var inventory_hud: CanvasLayer = $PlayerInventoryHud
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var gameplay_toast: CanvasLayer = $GameplayToast

var _input_enabled: bool = true
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _next_harvest_allowed_ms: int = 0
var _pending_chop_hit: bool = false
var _pending_chop_ref: WeakRef
var _pending_mine_ref: WeakRef
var _harvest_timer_generation: int = 0

var _harvest_auto_active: bool = false
var _harvest_auto_target: WeakRef
var _harvest_auto_gen: int = 0

var _world_environment: WorldEnvironment = null


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	add_to_group("player")
	_world_environment = _find_world_environment()
	_apply_from_gamestate()
	if _input_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if interaction_prompt:
		interaction_prompt.visible = false
	var inv: Node = get_node_or_null("/root/InventoryService")
	if inv != null and inv.has_signal("inventory_changed"):
		inv.inventory_changed.connect(_on_inventory_changed)
	_refresh_tacklebox_back_visual()


func _on_inventory_changed() -> void:
	_refresh_tacklebox_back_visual()


func _refresh_tacklebox_back_visual() -> void:
	if base_character == null or not base_character.has_method("set_tacklebox_back_display_enabled"):
		return
	var inv: Node = get_node_or_null("/root/InventoryService")
	var has_tb := false
	if inv != null and inv.has_method("has_item"):
		has_tb = inv.has_item("tool_tacklebox")
	base_character.set_tacklebox_back_display_enabled(has_tb)


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

	var tool_busy: bool = base_character.has_method("is_tool_action_active") and base_character.is_tool_action_active()

	var wl: float = _get_active_water_level()
	var in_water: bool = wl > -1e6 and global_position.y < wl + 0.45 and global_position.y > wl - water_max_effect_depth
	var depth_below_surface: float = wl - global_position.y

	if is_on_floor():
		if not tool_busy and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity if not in_water else jump_velocity * water_jump_multiplier
		else:
			velocity.y = 0.0
	else:
		var gmul: float = gravity_multiplier
		if in_water:
			gmul *= water_gravity_scale
		velocity.y -= (_gravity * gmul) * delta
		if in_water and depth_below_surface > 0.0:
			var sub: float = clampf(depth_below_surface / 2.8, 0.0, 1.2)
			velocity.y += water_buoyancy_strength * sub * delta
			velocity.y -= water_vertical_drag * velocity.y * delta

	var raw_move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _harvest_auto_active and raw_move.length_squared() > 0.0001:
		_stop_harvest_auto()
	var input_vec := raw_move
	if tool_busy:
		input_vec = Vector2.ZERO
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

	if in_water:
		velocity.x *= water_horizontal_drag
		velocity.z *= water_horizontal_drag
		if not tool_busy and Input.is_action_just_pressed("jump"):
			velocity.y = maxf(velocity.y, jump_velocity * water_jump_multiplier)

	move_and_slide()

	_update_underwater_fog(wl)

	_update_interaction_ray()
	_update_interaction_prompt()

	if not tool_busy:
		if Input.is_action_just_pressed("tool_axe"):
			_set_player_tool(_BaseCharacter.ToolKind.AXE)
		if Input.is_action_just_pressed("tool_pickaxe"):
			_set_player_tool(_BaseCharacter.ToolKind.PICKAXE)
		if Input.is_action_just_pressed("tool_fishing"):
			_set_player_tool(_BaseCharacter.ToolKind.FISHING_ROD)
		if Input.is_action_just_pressed("tool_hands"):
			_set_player_tool(_BaseCharacter.ToolKind.NONE)

	if Input.is_action_just_pressed("attack"):
		if _pending_chop_hit:
			return
		var now_ms: int = Time.get_ticks_msec()
		if now_ms >= _next_harvest_allowed_ms:
			var harvest_res: Array = _try_harvest_hit_with_cooldown()
			if harvest_res[0]:
				_next_harvest_allowed_ms = now_ms + int(harvest_res[1] * 1000.0)

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


func show_gameplay_message(msg: String) -> void:
	if gameplay_toast != null and gameplay_toast.has_method("show_message"):
		gameplay_toast.show_message(msg)


func _get_harvest_facing_direction() -> Vector3:
	# Character mesh (KayKit rig) faces +local Z; -Z is “camera forward” in Godot, so use +basis.z for body aim.
	var fwd := base_character.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = Vector3(0.0, 0.0, 1.0)
	else:
		fwd = fwd.normalized()
	var blend: float = clampf(harvest_ray_downward_blend, 0.0, 0.95)
	return ((1.0 - blend) * fwd + blend * Vector3.DOWN).normalized()


func _update_interaction_ray() -> void:
	var interaction_origin := global_position + Vector3(0.0, interaction_height, 0.0)
	var cast_dir := _get_harvest_facing_direction()
	interaction_ray.global_position = interaction_origin
	interaction_ray.target_position = cast_dir * interaction_range
	interaction_ray.force_raycast_update()


## True if the ray hits this collider, or it is still in range and roughly in front of the character (camera-independent).
func _harvest_target_still_valid(c: Object) -> bool:
	if c == null or not is_instance_valid(c):
		return false
	_update_interaction_ray()
	if interaction_ray.is_colliding() and interaction_ray.get_collider() == c:
		return true
	if not (c is Node3D):
		return false
	var t := c as Node3D
	if global_position.distance_to(t.global_position) > interaction_range + 1.0:
		return false
	var to_t: Vector3 = t.global_position - global_position
	to_t.y = 0.0
	var fwd := base_character.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001 or to_t.length_squared() < 0.0001:
		return false
	fwd = fwd.normalized()
	to_t = to_t.normalized()
	return fwd.dot(to_t) >= 0.35


func _stop_harvest_auto() -> void:
	if not _harvest_auto_active:
		return
	_harvest_auto_active = false
	_harvest_auto_target = null
	_harvest_auto_gen += 1


func _harvest_schedule_auto_chain(collider: Object, duration_sec: float) -> void:
	if collider == null or not collider.has_method("can_harvest"):
		return
	_harvest_auto_gen += 1
	var gen: int = _harvest_auto_gen
	_harvest_auto_active = true
	_harvest_auto_target = weakref(collider)
	_schedule_harvest_auto_followup(duration_sec, gen)


func _schedule_harvest_auto_followup(duration_sec: float, gen: int) -> void:
	var tw := get_tree().create_timer(maxf(0.05, duration_sec))
	tw.timeout.connect(_on_harvest_auto_timer.bind(gen))


func _on_harvest_auto_timer(gen: int) -> void:
	# Must be async: next swing waits until BaseCharacter leaves TOOL_ACTION or try_play_action_for_harvest stays false.
	_harvest_auto_continue_async(gen)


func _harvest_auto_continue_async(gen: int) -> void:
	if gen != _harvest_auto_gen:
		return
	if not _harvest_auto_active:
		return
	var c: Object = _harvest_auto_target.get_ref() if _harvest_auto_target != null else null
	if c == null or not is_instance_valid(c):
		_stop_harvest_auto()
		return
	if c.has_method("can_harvest") and not c.can_harvest():
		_stop_harvest_auto()
		return
	var move_check := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if move_check.length_squared() > 0.0001:
		_stop_harvest_auto()
		return
	if not _harvest_target_still_valid(c):
		_stop_harvest_auto()
		return
	if not _harvest_skill_met(c):
		_stop_harvest_auto()
		return
	# Timer uses exported clip length; animation may end slightly later. try_play_action_for_harvest rejects while TOOL_ACTION.
	var safety := 0
	while base_character.has_method("is_tool_action_active") and base_character.is_tool_action_active():
		if gen != _harvest_auto_gen or not _harvest_auto_active:
			return
		await get_tree().process_frame
		safety += 1
		if safety > 360:
			push_warning("player: harvest auto waited too long for tool idle; stopping chain.")
			_stop_harvest_auto()
			return
	if gen != _harvest_auto_gen or not _harvest_auto_active:
		return
	c = _harvest_auto_target.get_ref() if _harvest_auto_target != null else null
	if c == null or not is_instance_valid(c):
		_stop_harvest_auto()
		return
	if c.has_method("can_harvest") and not c.can_harvest():
		_stop_harvest_auto()
		return
	if not _harvest_target_still_valid(c):
		_stop_harvest_auto()
		return
	if not _harvest_skill_met(c):
		_stop_harvest_auto()
		return
	var res: Array = _begin_harvest_on_collider(c)
	if not bool(res[0]):
		_stop_harvest_auto()
		return
	_schedule_harvest_auto_followup(float(res[1]), gen)


func _begin_harvest_on_collider(collider: Object) -> Array:
	if collider == null or not collider.has_method("harvest_hit"):
		return [false, harvest_click_cooldown_sec]
	if not _harvest_skill_met(collider):
		return [false, harvest_click_cooldown_sec]
	var action := "chop"
	if collider.has_method("get_harvest_action"):
		action = collider.get_harvest_action()
	if base_character.has_method("try_play_action_for_harvest"):
		if not base_character.try_play_action_for_harvest(action):
			return [false, harvest_click_cooldown_sec]
	return _start_harvest_swing_on_collider(collider, action)


func _harvest_skill_met(collider: Object) -> bool:
	if collider == null:
		return false
	var gs := get_node_or_null("/root/GameState")
	if gs == null or not (gs is _GameState):
		return true
	var state := gs as _GameState
	var action := "chop"
	if collider.has_method("get_harvest_action"):
		action = String(collider.get_harvest_action())
	if action == "mine":
		var req := 0
		if collider.has_method("get_required_mining_level"):
			req = int(collider.get_required_mining_level())
		if req <= 0:
			return true
		return state.mining_level >= req
	var req_wc := 0
	if collider.has_method("get_required_woodcutting_level"):
		req_wc = int(collider.get_required_woodcutting_level())
	if req_wc <= 0:
		return true
	return state.woodcutting_level >= req_wc


func _bump_harvest_timer_generation() -> int:
	_harvest_timer_generation += 1
	return _harvest_timer_generation


func _abort_harvest_tool_animation() -> void:
	_harvest_timer_generation += 1
	_pending_chop_hit = false
	_stop_harvest_auto()
	if base_character.has_method("cancel_tool_action"):
		base_character.cancel_tool_action()


func _try_harvest_hit_with_cooldown() -> Array:
	_update_interaction_ray()
	if not interaction_ray.is_colliding():
		return [false, harvest_click_cooldown_sec]
	var collider: Object = interaction_ray.get_collider()
	if collider == null:
		return [false, harvest_click_cooldown_sec]
	if not collider.has_method("harvest_hit"):
		return [false, harvest_click_cooldown_sec]
	if not _harvest_skill_met(collider):
		return [false, harvest_click_cooldown_sec]
	var action := "chop"
	if collider.has_method("get_harvest_action"):
		action = collider.get_harvest_action()
	if base_character.has_method("try_play_action_for_harvest"):
		if not base_character.try_play_action_for_harvest(action):
			return [false, harvest_click_cooldown_sec]
	var res: Array = _start_harvest_swing_on_collider(collider, action)
	if bool(res[0]):
		_harvest_schedule_auto_chain(collider, float(res[1]))
	return res


func _start_harvest_swing_on_collider(collider: Object, action: String) -> Array:
	if action == "chop":
		_pending_chop_hit = true
		_pending_chop_ref = weakref(collider)
		if chop_impact_delays_sec.is_empty():
			var c0: Object = _pending_chop_ref.get_ref() if _pending_chop_ref != null else null
			var outcome0 := _harvest_swing_outcome(c0)
			if outcome0 == _H_INVALID:
				_abort_harvest_tool_animation()
				return [false, chop_animation_duration_sec]
			if outcome0 == _H_INV_FULL:
				_stop_harvest_auto()
			_pending_chop_hit = false
			return [true, chop_animation_duration_sec]
		var chop_seq := _bump_harvest_timer_generation()
		for i in range(chop_impact_delays_sec.size()):
			var d: float = chop_impact_delays_sec[i]
			var tw := get_tree().create_timer(d)
			tw.timeout.connect(_on_chop_impact_timeout.bind(i + 1, chop_seq))
		return [true, chop_animation_duration_sec]
	if action == "mine":
		_pending_mine_ref = weakref(collider)
		var mine_seq := _bump_harvest_timer_generation()
		for i in range(mine_impact_delays_sec.size()):
			var d: float = mine_impact_delays_sec[i]
			var tw := get_tree().create_timer(d)
			tw.timeout.connect(_on_mine_impact_timeout.bind(i + 1, mine_seq))
		return [true, mine_animation_duration_sec]
	var outcome: int = _harvest_swing_outcome(collider)
	return [outcome != _H_INVALID, harvest_click_cooldown_sec]


func _harvest_swing_outcome(c: Object) -> int:
	if c == null or not c.has_method("harvest_hit"):
		return _H_INVALID
	var v: Variant = c.harvest_hit()
	if typeof(v) == TYPE_INT:
		return int(v)
	return _H_SUCCESS if v else _H_INVALID


func _update_interaction_prompt() -> void:
	if interaction_prompt == null:
		return
	if not interaction_ray.is_colliding():
		interaction_prompt.visible = false
		return
	var collider: Object = interaction_ray.get_collider()
	if collider == null or not collider.has_method("harvest_hit"):
		interaction_prompt.visible = false
		return
	var txt := "LMB: Chop"
	if collider.has_method("get_harvest_action"):
		var act := String(collider.get_harvest_action())
		if act == "mine":
			txt = "LMB: Mine"
	if collider.has_method("get_prompt_detail"):
		var detail := String(collider.get_prompt_detail())
		if detail != "":
			txt += "\n" + detail
	if not _harvest_skill_met(collider):
		txt += "\n(Requirements not met)"
	interaction_prompt.text = txt
	interaction_prompt.visible = true


func _on_chop_impact_timeout(impact_idx: int, seq: int) -> void:
	if seq != _harvest_timer_generation:
		return
	var c: Object = _pending_chop_ref.get_ref() if _pending_chop_ref != null else null
	if c == null:
		_abort_harvest_tool_animation()
		return
	var outcome := _harvest_swing_outcome(c)
	if outcome == _H_INVALID:
		_abort_harvest_tool_animation()
		return
	if outcome == _H_INV_FULL:
		_stop_harvest_auto()
	if impact_idx >= chop_impact_delays_sec.size():
		_pending_chop_hit = false


func _on_mine_impact_timeout(_impact_idx: int, seq: int) -> void:
	if seq != _harvest_timer_generation:
		return
	var c: Object = _pending_mine_ref.get_ref() if _pending_mine_ref != null else null
	if c == null:
		_abort_harvest_tool_animation()
		return
	var outcome := _harvest_swing_outcome(c)
	if outcome == _H_INVALID:
		_abort_harvest_tool_animation()
		return
	if outcome == _H_INV_FULL:
		_stop_harvest_auto()


func _find_world_environment() -> WorldEnvironment:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for c in scene.get_children():
		if c is WorldEnvironment:
			return c as WorldEnvironment
	return null


func _get_active_water_level() -> float:
	var best: Node3D = null
	var best_area: float = INF
	for node in get_tree().get_nodes_in_group(&"water_surface"):
		if not node is Node3D:
			continue
		var w := node as Node3D
		var ps: Variant = w.get("plane_size")
		if typeof(ps) != TYPE_VECTOR2:
			continue
		var half: Vector2 = ps * 0.5
		var dx: float = absf(global_position.x - w.global_position.x)
		var dz: float = absf(global_position.z - w.global_position.z)
		if dx > half.x or dz > half.y:
			continue
		var area: float = ps.x * ps.y
		if area < best_area:
			best_area = area
			best = w
	if best == null:
		return -1e7
	var wl: Variant = best.get("water_level")
	if typeof(wl) == TYPE_FLOAT:
		return wl as float
	return best.global_position.y


func _update_underwater_fog(water_level_y: float) -> void:
	if _world_environment == null:
		_world_environment = _find_world_environment()
	if _world_environment == null:
		return
	var env: Environment = _world_environment.environment
	if env == null:
		return
	var cam_y: float = camera_3d.global_position.y
	var cam_submerged: bool = water_level_y > -1e6 and cam_y < water_level_y - 0.02
	env.fog_enabled = cam_submerged
	if cam_submerged:
		var d: float = clampf(water_level_y - cam_y, 0.0, 22.0)
		var t: float = d / 14.0
		env.fog_density = lerpf(underwater_fog_density_min, underwater_fog_density_max, t)
