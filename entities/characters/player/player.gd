extends CharacterBody3D

const _GameState = preload("res://autoload/game_state.gd")
const _BaseCharacter = preload("res://entities/characters/base_character/base_character.gd")
const _WaterSurfaceQueries = preload("res://world/water/water_surface_queries.gd")
const _WeaponStats = preload("res://data/schemas/weapon_stats.gd")
const _CombatFormulaService = preload("res://systems/combat/combat_formula_service.gd")
const _RuneEffectService = preload("res://systems/magic/rune_effect_service.gd")
const _SpellCatalog = preload("res://systems/magic/spell_catalog.gd")

const _ArrowProjectileScene = preload("res://entities/projectiles/arrow_projectile.tscn")
## Consume cheaper ammo first so higher-tier arrows stay in the bag.
const _ARROW_AMMO_IDS_CONSUME_ORDER: Array[String] = [
	"ammo_arrow_wood", "ammo_arrow_common", "ammo_arrow_bronze", "ammo_arrow_iron",
]

const _H_INVALID := 0
const _H_WHIFF := 1
const _H_SUCCESS := 2
const _H_INV_FULL := 3

const _UNDERWATER_FOG_DEPTH_MAX := 22.0
const _DefaultHitVfxScene: PackedScene = preload("res://entities/effects/hit_spark_burst.tscn")

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
@export var interaction_fallback_radius: float = 0.6
@export var crosshair_screen_offset_px: Vector2 = Vector2.ZERO
@export var camera_shoulder_h_offset: float = 1.02
@export var zoom_min_distance: float = 5.2
@export var zoom_max_distance: float = 13.0
@export var zoom_step: float = 0.7
@export var zoom_lerp_speed: float = 10.0
@export var reticle_icon_default: Texture2D = preload("res://assets/ui/UI assets/Mobile Controls/Sprites/Icons/Default/icon_crosshair.png")
@export var reticle_icon_interact: Texture2D = preload("res://assets/ui/UI assets/Cursor Pack/PNG/Outline/Default/door_enter.png")
@export var reticle_icon_attack: Texture2D = preload("res://assets/ui/UI assets/UI Pack - Sci-fi/PNG/Blue/Default/crosshair_color_a.png")
@export var reticle_icon_mine: Texture2D = preload("res://assets/ui/UI assets/UI Pack - Sci-fi/PNG/Yellow/Default/crosshair_color_b.png")
@export var reticle_icon_door_locked: Texture2D = preload("res://assets/ui/UI assets/Cursor Pack/PNG/Outline/Default/lock.png")
@export var reticle_icon_door_unlocked: Texture2D = preload("res://assets/ui/UI assets/Cursor Pack/PNG/Outline/Default/lock_unlocked.png")
@export var reticle_icon_watering: Texture2D = preload("res://assets/ui/UI assets/Cursor Pack/PNG/Outline/Default/tool_watering_can.png")
@export_group("Ranged")
@export var arrow_aim_max_distance: float = 140.0
@export var arrow_projectile_speed: float = 42.0
@export var arrow_projectile_gravity_scale: float = 0.85
@export var arrow_projectile_lifetime: float = 10.0
@export var arrow_physics_collision_mask: int = 7
## Harvest/interaction ray uses character facing (not camera look). Slight downward bias helps short ground nodes.
@export var harvest_ray_downward_blend: float = 0.22
@export var harvest_click_cooldown_sec: float = 1.5
## Movement above this (Input.get_vector) immediately cancels harvest + tool clip.
@export var harvest_move_cancel_deadzone: float = 0.08
@export var chop_animation_duration_sec: float = 4.3333
## Chop clip has 3 impact beats.
@export var chop_impact_delays_sec: PackedFloat32Array = PackedFloat32Array([0.8, 2.2, 3.5])
@export var mine_animation_duration_sec: float = 3.7333
## Pickaxe clip has 2 impact beats.
@export var mine_impact_delays_sec: PackedFloat32Array = PackedFloat32Array([0.3, 2.15])
@export var harvest_interact_start_distance: float = 1.95
@export var harvest_interact_start_distance_chop: float = 2.05
## Mine uses a larger radius because many rocks have a center pivot deeper than the reachable collision face.
@export var harvest_interact_start_distance_mine: float = 2.6
@export var harvest_interact_face_dot_min: float = 0.62
@export var harvest_interact_face_dot_min_chop: float = 0.55
@export var harvest_interact_face_dot_min_mine: float = 0.55
@export var creature_attack_damage: float = 8.0
@export var unarmed_melee_damage: float = 1.0
@export var tool_melee_damage: float = 2.0
@export var creature_attack_cooldown_sec: float = 0.7
## When enabled, scales weapon/fallback attack interval differently for cone-target swings vs air swings.
@export var creature_attack_use_split_melee_cooldown: bool = false
## Applied to resolved interval when a creature was in melee cone (includes staff interact on target).
@export var creature_attack_melee_targeted_interval_mult: float = 1.0
## Applied to resolved interval for air / no-melee-target swings.
@export var creature_attack_melee_whiff_interval_mult: float = 1.0
## Optional floor/cap in seconds for melee GCD (0 = no limit on that bound).
@export var creature_attack_melee_interval_min_sec: float = 0.0
@export var creature_attack_melee_interval_max_sec: float = 0.0

@export_group("Melee hit feedback")
@export var melee_hitstop_enabled: bool = true
## Real-time duration of slow-motion (wall clock). Restore uses `Time.get_ticks_msec()`.
@export var melee_hitstop_duration_sec: float = 0.055
## `Engine.time_scale` while hitstop is active (lower = snappier freeze).
@export var melee_hitstop_time_scale: float = 0.14
@export var melee_hit_camera_shake_enabled: bool = true
@export var melee_hit_camera_shake_duration_sec: float = 0.12
## Max camera offset in meters (decays over shake duration).
@export var melee_hit_camera_shake_amplitude: float = 0.032
@export var hit_feedback_default_impact_sound: AudioStream
## Null uses built-in `entities/effects/hit_spark_burst.tscn` when `hit_feedback_enable_impact_vfx` is on.
@export var hit_feedback_default_impact_vfx_scene: PackedScene
@export var hit_feedback_enable_impact_vfx: bool = true
## Seconds from melee swing start until each creature hit registers. Empty = immediate on swing start after animation confirms.
## Used when no entry exists in `melee_creature_impact_delays_by_clip` for the active clip (and for staff interact swings).
@export var melee_creature_impact_delays_sec: PackedFloat32Array = PackedFloat32Array([0.42])
## Keys = AnimationPlayer clip names for melee (same as BaseCharacter.get_active_melee_clip_name()). Values = PackedFloat32Array or Array of delay seconds per hit window.
@export var melee_creature_impact_delays_by_clip: Dictionary = {
	"Melee_1H_Attack_Slice_Diagonal": PackedFloat32Array([0.42]),
	"Melee_Attack_1H_Diagonal": PackedFloat32Array([0.42]),
	"Melee_Attack_Diagonal": PackedFloat32Array([0.42]),
	"Melee_1H_Attack_Stab": PackedFloat32Array([0.42]),
	"Melee_Attack_1H_Stab": PackedFloat32Array([0.42]),
	"Melee_Attack_Stab": PackedFloat32Array([0.42]),
	"Melee_Attack_1H": PackedFloat32Array([0.42]),
	"Melee_1H_Attack_Jump_Chop": PackedFloat32Array([0.42]),
	"Melee_Attack_1H_Jump_Chop": PackedFloat32Array([0.42]),
	"Melee_Attack_Jump_Chop": PackedFloat32Array([0.42]),
	"Chop": PackedFloat32Array([0.42]),
	"Melee_Unarmed_Attack_Punch_A": PackedFloat32Array([0.42]),
	"Melee_Unarmed_Attack_Kick": PackedFloat32Array([0.42]),
}
@export var melee_reach_distance: float = 2.15
@export var melee_hit_radius: float = 0.65
@export var melee_forward_dot_min: float = 0.1
## Attack presses during an active melee swing are remembered this long for the next swing after recovery.
@export var melee_input_buffer_sec: float = 0.16
## Horizontal move speed while in a melee swing (tool chop / bow still root). 1.0 = full speed.
@export var melee_swing_move_speed_multiplier: float = 0.38
## Rotate rig toward attack direction when a swing starts (applied after movement this frame).
@export var melee_face_on_attack: bool = true
## `lerp_angle` blend toward target/camera (1.0 = fully align this frame).
@export var melee_face_lerp_weight: float = 1.0
@export var shield_block_damage_multiplier: float = 0.15
@export var shield_block_move_multiplier: float = 0.55
@export var shield_block_turn_multiplier: float = 0.6
@export var build_place_distance: float = 4.0
@export var build_rotate_step_deg: float = 15.0

@export_group("Water")
@export var water_buoyancy_strength: float = 14.0
@export var water_gravity_scale: float = 0.22
@export var water_vertical_drag: float = 4.5
@export var water_horizontal_drag: float = 0.88
@export var water_jump_multiplier: float = 0.55
@export var water_max_effect_depth: float = 18.0
## If set, receives underwater fog via `set_underwater_fog_override`. Otherwise uses group `day_night_cycle`.
@export var day_night_controller_path: NodePath = NodePath("")
@export var water_dive_accel: float = 12.0
@export var water_buoyancy_dive_scale: float = 0.28
@export var water_dive_max_down_speed: float = 7.5

@export_group("Vitality")
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var stamina_drain_run: float = 22.0
@export var stamina_regen: float = 16.0
@export var stamina_regen_air: float = 8.0

var health: float = 100.0
var stamina: float = 100.0

@onready var base_character: Node3D = $BaseCharacter
@onready var camera_rig: Node3D = $CameraRig
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var camera_3d: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var interaction_ray: RayCast3D = $RayCast3D
@onready var game_menu: GameMenu = $GameMenu
@onready var player_hud: CanvasLayer = $PlayerHud
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var reticle: TextureRect = $Reticle
@onready var gameplay_toast: CanvasLayer = $GameplayToast

var _input_enabled: bool = true
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _next_harvest_allowed_ms: int = 0
var _melee_attack_buffer_deadline_ms: int = 0
var _prev_melee_combat_active: bool = false
var _pending_melee_face_yaw_valid: bool = false
var _pending_melee_face_yaw: float = 0.0
var _pending_chop_hit: bool = false
var _pending_chop_ref: WeakRef
var _pending_mine_ref: WeakRef
var _harvest_timer_generation: int = 0
var _creature_impact_generation: int = 0
var _pending_creature_ref: WeakRef

var _melee_hitstop_active: bool = false
var _melee_hitstop_prev_time_scale: float = 1.0
var _melee_hitstop_end_ticks_ms: int = 0
var _melee_cam_shake_time_left_sec: float = 0.0
var _melee_cam_shake_rest_pos: Vector3 = Vector3.ZERO
var _melee_cam_shake_dur_effective: float = 0.12
var _melee_cam_shake_amp_effective: float = 0.032
var _hit_feedback_audio: AudioStreamPlayer3D

var _harvest_auto_active: bool = false
var _harvest_auto_target: WeakRef
var _harvest_auto_gen: int = 0
var _harvest_interact_pending: bool = false
var _harvest_interact_target: WeakRef
var _zoom_target_distance: float = 0.0

var _day_night: Node = null
var _last_equipped_main_hand_id: String = ""
var _last_equipped_off_hand_id: String = ""
var _last_equipped_head_id: String = ""
var _last_equipped_chest_id: String = ""
var _last_equipped_legs_id: String = ""
var _last_equipped_back_id: String = ""
var _cached_interaction_collider: Object = null
var _cached_interaction_frame: int = -1
var _rune_cooldown_until_ms: Dictionary = {}
var _build_preview_item_id: String = ""
var _build_preview_rotation_y: float = 0.0
var _build_preview_node: Node3D = null
var _build_preview_valid: bool = false
var _build_mode_active: bool = false

func apply_damage(amount: float) -> void:
	var amt: float = absf(amount)
	if base_character != null and base_character.has_method("is_blocking") and base_character.is_blocking():
		amt *= shield_block_damage_multiplier
	health = maxf(health - amt, 0.0)
	# Taking a hit should break harvest automation immediately.
	_stop_harvest_auto()
	_clear_harvest_interact_approach()


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	add_to_group("player")
	health = max_health
	stamina = max_stamina
	if interaction_ray != null:
		interaction_ray.top_level = true
		interaction_ray.collide_with_areas = true
		interaction_ray.collide_with_bodies = true
	if camera_3d != null:
		camera_3d.h_offset = camera_shoulder_h_offset
		_melee_cam_shake_rest_pos = camera_3d.position
	if spring_arm != null:
		spring_arm.spring_length = clampf(spring_arm.spring_length, zoom_min_distance, zoom_max_distance)
		_zoom_target_distance = spring_arm.spring_length
	_refresh_interaction_collider_cache(true)
	_update_reticle_position()
	_update_reticle_icon()
	_resolve_day_night_controller()
	_apply_from_gamestate()
	if _input_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if interaction_prompt:
		interaction_prompt.visible = false
	var inv: Node = get_node_or_null("/root/InventoryService")
	if inv != null and inv.has_signal("inventory_changed"):
		inv.inventory_changed.connect(_on_inventory_changed)
	_refresh_tacklebox_back_visual()
	_sync_equipped_hand_visuals()


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
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right") or event.is_action_pressed("move_forward") or event.is_action_pressed("move_back"):
		_cancel_harvest_on_movement_press()
	if event.is_action_pressed("character_menu") and game_menu:
		game_menu.toggle(GameMenu.TAB_VITALS)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory") and game_menu:
		game_menu.toggle(GameMenu.TAB_INVENTORY)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("craft_menu") and game_menu:
		if game_menu.has_method("open_forge_crafting_basic"):
			game_menu.open_forge_crafting_basic()
		else:
			game_menu.toggle(GameMenu.TAB_FORGE)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("build_menu") and game_menu:
		if game_menu.has_method("open_forge_building"):
			game_menu.open_forge_building()
		else:
			game_menu.toggle(GameMenu.TAB_FORGE)
		get_viewport().set_input_as_handled()
		return
	if _gameplay_input_blocked():
		if event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				get_viewport().set_input_as_handled()
				return
		return
	if _build_mode_active:
		if event.is_action_pressed("interact"):
			if try_place_build_item(_build_preview_item_id, _build_preview_rotation_y):
				show_gameplay_message("Placed: %s" % InventoryService.get_item_display_name(_build_preview_item_id))
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				cancel_build_placement()
				get_viewport().set_input_as_handled()
				return
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_build_preview_rotation_y = wrapf(_build_preview_rotation_y - deg_to_rad(build_rotate_step_deg), -PI, PI)
				if game_menu != null and game_menu.has_method("_set_build_rotation_from_player"):
					game_menu.call("_set_build_rotation_from_player", _build_preview_rotation_y)
				get_viewport().set_input_as_handled()
				return
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_build_preview_rotation_y = wrapf(_build_preview_rotation_y + deg_to_rad(build_rotate_step_deg), -PI, PI)
				if game_menu != null and game_menu.has_method("_set_build_rotation_from_player"):
					game_menu.call("_set_build_rotation_from_player", _build_preview_rotation_y)
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("interact"):
		_try_interact()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_target_distance = clampf(_zoom_target_distance - zoom_step, zoom_min_distance, zoom_max_distance)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_target_distance = clampf(_zoom_target_distance + zoom_step, zoom_min_distance, zoom_max_distance)
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

	if _melee_hitstop_active and Time.get_ticks_msec() >= _melee_hitstop_end_ticks_ms:
		Engine.time_scale = _melee_hitstop_prev_time_scale
		_melee_hitstop_active = false

	var melee_combat_active: bool = (
		base_character != null
		and base_character.has_method("is_melee_combat_active")
		and bool(base_character.is_melee_combat_active())
	)
	if _prev_melee_combat_active and not melee_combat_active:
		var consumed: bool = _try_consume_melee_attack_buffer()
		if consumed:
			melee_combat_active = true

	var anim_busy: bool = base_character.has_method("is_movement_locked") and base_character.is_movement_locked()
	var wants_block: bool = Input.is_action_pressed("block") and _off_hand_has_shield_equipped()
	if base_character.has_method("set_blocking"):
		base_character.set_blocking(wants_block)
	var actively_blocking: bool = base_character != null and base_character.has_method("is_blocking") and base_character.is_blocking()

	var wl: float = _WaterSurfaceQueries.get_active_water_height_at(get_tree(), global_position)
	var in_water: bool = (
			wl > -1e6
			and global_position.y < wl - 0.02
			and global_position.y > wl - water_max_effect_depth
	)
	var depth_below_surface: float = wl - global_position.y

	if in_water:
		# Seabed used to count as floor: velocity.y was zeroed and buoyancy never ran, so the
		# player sank while walking but floated after jump (briefly not on_floor).
		var diving: bool = not anim_busy and Input.is_action_pressed("swim_down")
		var gmul: float = gravity_multiplier * water_gravity_scale
		velocity.y -= (_gravity * gmul) * delta
		if depth_below_surface > 0.0:
			var sub: float = clampf(depth_below_surface / 2.8, 0.0, 1.2)
			var buoy_mul: float = water_buoyancy_dive_scale if diving else 1.0
			velocity.y += water_buoyancy_strength * sub * buoy_mul * delta
			velocity.y -= water_vertical_drag * velocity.y * delta
		if diving:
			velocity.y -= water_dive_accel * delta
			velocity.y = maxf(velocity.y, -water_dive_max_down_speed)
		if not anim_busy and Input.is_action_just_pressed("jump"):
			velocity.y = maxf(velocity.y, jump_velocity * water_jump_multiplier)
	elif is_on_floor():
		if not anim_busy and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
		else:
			velocity.y = 0.0
	else:
		velocity.y -= (_gravity * gravity_multiplier) * delta

	var raw_move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_cancel_harvest_on_movement_input(raw_move)
	var input_vec := raw_move
	var approach_input := _harvest_interact_move_input()
	if approach_input.length_squared() > 0.0001:
		input_vec = approach_input
	# Root during tool actions, bow, etc.; allow reduced strafe during one-handed / unarmed melee.
	if anim_busy and not melee_combat_active:
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

	var want_run := Input.is_action_pressed("run")
	var running := want_run and stamina > 0.05 and not actively_blocking
	if melee_combat_active:
		running = false
	var speed_factor: float = _night_speed_factor()
	var speed := move_speed * speed_factor * (run_multiplier if running else 1.0)
	if actively_blocking:
		speed *= shield_block_move_multiplier
	if anim_busy and melee_combat_active:
		speed *= clampf(melee_swing_move_speed_multiplier, 0.0, 1.0)

	if dir.length_squared() > 0.0001:
		dir = dir.normalized()
		var target_rot := atan2(dir.x, dir.z)
		var turn_mult := shield_block_turn_multiplier if actively_blocking else 1.0
		base_character.rotation.y = lerp_angle(base_character.rotation.y, target_rot, turn_speed * turn_mult * delta)

		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	# Walk-to-harvest stops horizontal input once in range, but rotation was only driven by move dir — so
	# side approaches never satisfy facing dot. Nudge body toward the node while E-approach is pending.
	if _harvest_interact_pending and not anim_busy and not actively_blocking:
		var ht: Object = _harvest_interact_target.get_ref() if _harvest_interact_target != null else null
		if ht is Node3D and is_instance_valid(ht):
			if _harvest_interact_within_start_distance(ht) and not _harvest_interact_ready(ht):
				_harvest_face_toward_node3d(ht as Node3D, delta)

	if in_water:
		velocity.x *= water_horizontal_drag
		velocity.z *= water_horizontal_drag

	move_and_slide()
	_try_start_pending_harvest_interact()

	if not in_water and is_on_floor():
		if running and dir.length_squared() > 0.0001:
			stamina = maxf(stamina - stamina_drain_run * delta, 0.0)
		else:
			stamina = minf(stamina + stamina_regen * delta, max_stamina)
	elif not in_water:
		stamina = minf(stamina + stamina_regen_air * delta, max_stamina)

	var wl_cam: float = _WaterSurfaceQueries.get_active_water_height_at(get_tree(), camera_3d.global_position)
	_update_underwater_fog(wl_cam)

	_refresh_interaction_collider_cache()
	if spring_arm != null:
		spring_arm.spring_length = lerpf(spring_arm.spring_length, _zoom_target_distance, clampf(zoom_lerp_speed * delta, 0.0, 1.0))
	_update_reticle_position()
	_update_reticle_icon()
	_update_interaction_prompt()
	_sync_equipped_hand_visuals()
	_update_build_preview()

	if not anim_busy:
		if Input.is_action_just_pressed("tool_axe"):
			_use_hotbar_slot(0)
		if Input.is_action_just_pressed("tool_pickaxe"):
			_use_hotbar_slot(1)
		if Input.is_action_just_pressed("tool_hands"):
			_use_hotbar_slot(2)
		if Input.is_action_just_pressed("tool_fishing"):
			_use_hotbar_slot(3)

	# Bow phases mark movement locked (`anim_busy`), but aim/fire/cancel must still run every frame.
	_attack_input_tick()

	_apply_pending_melee_facing(delta)

	_update_melee_hit_camera_shake(delta)

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var moving := horizontal_speed > 0.15
	if base_character.has_method("set_locomotion_state"):
		base_character.set_locomotion_state(moving, running, is_on_floor())

	_prev_melee_combat_active = (
		base_character != null
		and base_character.has_method("is_melee_combat_active")
		and bool(base_character.is_melee_combat_active())
	)


func _try_consume_melee_attack_buffer() -> bool:
	var now_ms: int = Time.get_ticks_msec()
	if _melee_attack_buffer_deadline_ms <= 0 or now_ms > _melee_attack_buffer_deadline_ms:
		return false
	if _gameplay_input_blocked() or _pending_chop_hit:
		return false
	if _equipped_weapon_is_bow():
		return false
	if now_ms < _next_harvest_allowed_ms:
		return false
	if _try_creature_melee_hit():
		_next_harvest_allowed_ms = now_ms + int(_resolve_melee_attack_gcd_sec(true) * 1000.0)
		_melee_attack_buffer_deadline_ms = 0
		return true
	if _try_play_attack_air_whiff():
		_next_harvest_allowed_ms = now_ms + int(_resolve_melee_attack_gcd_sec(false) * 1000.0)
		_melee_attack_buffer_deadline_ms = 0
		return true
	_melee_attack_buffer_deadline_ms = 0
	return false


func _attack_input_tick() -> void:
	if _gameplay_input_blocked():
		if _equipped_weapon_is_bow() and base_character != null and base_character.has_method("try_cancel_bow_draw"):
			base_character.try_cancel_bow_draw()
		return
	if _pending_chop_hit:
		return
	var now_ms: int = Time.get_ticks_msec()

	if not _equipped_weapon_is_bow() and Input.is_action_just_pressed("attack"):
		if base_character != null and base_character.has_method("is_melee_combat_active"):
			if base_character.is_melee_combat_active():
				_melee_attack_buffer_deadline_ms = now_ms + int(maxf(0.05, melee_input_buffer_sec) * 1000.0)

	if _equipped_weapon_is_bow():
		if Input.is_action_just_released("attack"):
			if _try_bow_release_fire():
				_next_harvest_allowed_ms = now_ms + int(_creature_attack_interval_sec() * 1000.0)
			return
		if Input.is_action_pressed("attack"):
			if not _equipped_back_has_quiver():
				if Input.is_action_just_pressed("attack"):
					show_gameplay_message("Equip a quiver on your back to fire arrows.")
				return
			if _total_arrow_ammo_count() < 1:
				if Input.is_action_just_pressed("attack"):
					show_gameplay_message("You have no arrows.")
				return
			var drawing: bool = false
			if base_character != null and base_character.has_method("is_bow_drawn_or_drawing"):
				drawing = bool(base_character.is_bow_drawn_or_drawing())
			if not drawing and base_character != null and base_character.has_method("try_begin_bow_draw"):
				base_character.try_begin_bow_draw()
			return
		if base_character != null and base_character.has_method("try_cancel_bow_draw"):
			base_character.try_cancel_bow_draw()
		return
	if now_ms < _next_harvest_allowed_ms:
		return

	if Input.is_action_just_pressed("attack"):
		if _try_creature_melee_hit():
			_next_harvest_allowed_ms = now_ms + int(_resolve_melee_attack_gcd_sec(true) * 1000.0)
			return
		if _try_play_attack_air_whiff():
			_next_harvest_allowed_ms = now_ms + int(_resolve_melee_attack_gcd_sec(false) * 1000.0)


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


func _sync_equipped_hand_visuals() -> void:
	if base_character == null:
		return
	var main_id := ""
	var off_id := ""
	var head_id := ""
	var chest_id := ""
	var legs_id := ""
	var back_id := ""
	var m: Variant = GameState.equipment.get("main_hand", null)
	if m != null:
		main_id = GameState.normalize_item_id(str(m.get("id", "")))
	var o: Variant = GameState.equipment.get("off_hand", null)
	if o != null:
		off_id = GameState.normalize_item_id(str(o.get("id", "")))
	var h: Variant = GameState.equipment.get("head", null)
	if h != null:
		head_id = str(h.get("id", ""))
	var c: Variant = GameState.equipment.get("chest", null)
	if c != null:
		chest_id = str(c.get("id", ""))
	var l: Variant = GameState.equipment.get("legs", null)
	if l != null:
		legs_id = str(l.get("id", ""))
	var b: Variant = GameState.equipment.get("back", null)
	if b != null:
		back_id = GameState.normalize_item_id(str(b.get("id", "")))
	if (
		main_id == _last_equipped_main_hand_id
		and off_id == _last_equipped_off_hand_id
		and head_id == _last_equipped_head_id
		and chest_id == _last_equipped_chest_id
		and legs_id == _last_equipped_legs_id
		and back_id == _last_equipped_back_id
	):
		return
	_last_equipped_main_hand_id = main_id
	_last_equipped_off_hand_id = off_id
	_last_equipped_head_id = head_id
	_last_equipped_chest_id = chest_id
	_last_equipped_legs_id = legs_id
	_last_equipped_back_id = back_id
	if base_character.has_method("set_equipped_hand_items"):
		base_character.set_equipped_hand_items(main_id, off_id)
	if base_character.has_method("set_equipped_armor_items"):
		base_character.set_equipped_armor_items(head_id, chest_id, legs_id, back_id)
	if base_character.has_method("set_active_tool"):
		var desired_tool := _tool_kind_for_equipped_main(main_id)
		var harvest_target: Object = null
		if _harvest_interact_pending:
			harvest_target = _harvest_interact_target.get_ref() if _harvest_interact_target != null else null
		elif _harvest_auto_active:
			harvest_target = _harvest_auto_target.get_ref() if _harvest_auto_target != null else null
		if harvest_target != null and is_instance_valid(harvest_target) and harvest_target.has_method("get_harvest_action"):
			var harvest_action := String(harvest_target.call("get_harvest_action"))
			if harvest_action == "mine":
				desired_tool = _BaseCharacter.ToolKind.PICKAXE
			elif harvest_action == "chop":
				desired_tool = _BaseCharacter.ToolKind.AXE
		base_character.set_active_tool(desired_tool)


func _off_hand_has_shield_equipped() -> bool:
	var o: Variant = GameState.equipment.get("off_hand", null)
	if o == null:
		return false
	var id := GameState.normalize_item_id(str(o.get("id", "")))
	return id.begins_with("shield_")


func _equipped_main_hand_id_str() -> String:
	var m: Variant = GameState.equipment.get("main_hand", null)
	if m == null:
		return ""
	return GameState.normalize_item_id(str(m.get("id", "")))


func _equipped_off_hand_id_str() -> String:
	var o: Variant = GameState.equipment.get("off_hand", null)
	if o == null:
		return ""
	return GameState.normalize_item_id(str(o.get("id", "")))


## Bows use off_hand (left). Anything non-bow in main_hand wins for melee/harvest; legacy bow-in-main still works.
func _equipped_attack_weapon_family() -> _WeaponStats.WeaponFamily:
	var main_id := _equipped_main_hand_id_str()
	var off_id := _equipped_off_hand_id_str()
	var main_f := _CombatFormulaService.equipped_weapon_family(main_id)
	var off_f := _CombatFormulaService.equipped_weapon_family(off_id)
	if not main_id.is_empty() and main_f != _WeaponStats.WeaponFamily.BOW:
		return main_f
	if off_f == _WeaponStats.WeaponFamily.BOW:
		return _WeaponStats.WeaponFamily.BOW
	if not main_id.is_empty():
		return main_f
	return _CombatFormulaService.equipped_weapon_family("")


func _equipped_weapon_item_id_for_combat() -> String:
	var main_id := _equipped_main_hand_id_str()
	var off_id := _equipped_off_hand_id_str()
	var main_f := _CombatFormulaService.equipped_weapon_family(main_id)
	var off_f := _CombatFormulaService.equipped_weapon_family(off_id)
	if not main_id.is_empty() and main_f != _WeaponStats.WeaponFamily.BOW:
		return main_id
	if off_f == _WeaponStats.WeaponFamily.BOW:
		return off_id
	if not main_id.is_empty():
		return main_id
	return ""


func _equipped_weapon_is_bow() -> bool:
	return _equipped_attack_weapon_family() == _WeaponStats.WeaponFamily.BOW


func _creature_damage_amount() -> float:
	var id := _equipped_weapon_item_id_for_combat()
	return _CombatFormulaService.creature_damage_amount(
		id,
		unarmed_melee_damage,
		tool_melee_damage,
		creature_attack_damage
	)


func _creature_attack_interval_sec() -> float:
	var id := _equipped_weapon_item_id_for_combat()
	return _CombatFormulaService.creature_attack_interval_sec(id, creature_attack_cooldown_sec)


func _resolve_melee_attack_gcd_sec(is_targeted_swing: bool) -> float:
	var sec := _creature_attack_interval_sec()
	if creature_attack_use_split_melee_cooldown:
		sec *= (
			creature_attack_melee_targeted_interval_mult
			if is_targeted_swing
			else creature_attack_melee_whiff_interval_mult
		)
	if creature_attack_melee_interval_min_sec > 0.0:
		sec = maxf(sec, creature_attack_melee_interval_min_sec)
	if creature_attack_melee_interval_max_sec > 0.0:
		sec = minf(sec, creature_attack_melee_interval_max_sec)
	return maxf(0.05, sec)


func _try_creature_melee_hit() -> bool:
	var collider: Object = _find_creature_melee_target()
	if not _is_creature_candidate(collider):
		return false
	var family := _equipped_attack_weapon_family()
	var played := false
	var use_melee_clip_delays: bool = false
	match family:
		_WeaponStats.WeaponFamily.STAFF:
			if base_character.has_method("try_play_action_for_harvest"):
				played = base_character.try_play_action_for_harvest("interact")
		_WeaponStats.WeaponFamily.BOW:
			return false
		_:
			if base_character.has_method("try_play_melee_attack_1h"):
				played = base_character.try_play_melee_attack_1h()
				use_melee_clip_delays = true
	if not played:
		return false

	if collider is Node3D:
		_queue_melee_face_toward_world_xz((collider as Node3D).global_position)

	_creature_impact_generation += 1
	var seq: int = _creature_impact_generation
	_pending_creature_ref = weakref(collider)

	var delays: PackedFloat32Array = _resolve_creature_melee_impact_delays_sec(use_melee_clip_delays)
	if delays.is_empty():
		_apply_creature_melee_damage_at_impact(seq)
		return true

	for i in range(delays.size()):
		var d: float = delays[i]
		var tw := get_tree().create_timer(maxf(0.0, d))
		tw.timeout.connect(_on_creature_melee_impact_timeout.bind(seq))
	return true


func _resolve_creature_melee_impact_delays_sec(use_melee_clip_lookup: bool) -> PackedFloat32Array:
	if not use_melee_clip_lookup:
		return melee_creature_impact_delays_sec
	var clip := ""
	if base_character != null and base_character.has_method("get_active_melee_clip_name"):
		clip = str(base_character.get_active_melee_clip_name())
	if clip.is_empty():
		return melee_creature_impact_delays_sec
	if melee_creature_impact_delays_by_clip.has(clip):
		var packed := _coerce_impact_delays_array(melee_creature_impact_delays_by_clip[clip])
		if not packed.is_empty():
			return packed
	return melee_creature_impact_delays_sec


func _coerce_impact_delays_array(v: Variant) -> PackedFloat32Array:
	if v == null:
		return PackedFloat32Array()
	if v is PackedFloat32Array:
		return v
	if v is Array:
		var out := PackedFloat32Array()
		for x in v:
			out.append(float(x))
		return out
	return PackedFloat32Array()


func _queue_melee_face_toward_world_xz(world_pos: Vector3) -> void:
	if not melee_face_on_attack or base_character == null:
		return
	var to_t := world_pos - base_character.global_position
	to_t.y = 0.0
	if to_t.length_squared() < 0.0001:
		return
	_pending_melee_face_yaw = atan2(to_t.x, to_t.z)
	_pending_melee_face_yaw_valid = true


func _queue_melee_face_camera_forward_xz() -> void:
	if not melee_face_on_attack or base_character == null or camera_3d == null:
		return
	var cam_basis := camera_3d.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return
	forward = forward.normalized()
	_pending_melee_face_yaw = atan2(forward.x, forward.z)
	_pending_melee_face_yaw_valid = true


func _apply_pending_melee_facing(_delta: float) -> void:
	if not _pending_melee_face_yaw_valid or base_character == null:
		return
	var w := clampf(melee_face_lerp_weight, 0.0, 1.0)
	base_character.rotation.y = lerp_angle(base_character.rotation.y, _pending_melee_face_yaw, w)
	_pending_melee_face_yaw_valid = false


func _apply_creature_melee_damage_at_impact(seq: int) -> void:
	if seq != _creature_impact_generation:
		return
	var c: Object = _pending_creature_ref.get_ref() if _pending_creature_ref != null else null
	if c == null or not is_instance_valid(c) or not _creature_target_still_valid_for_hit(c) or not _is_creature_candidate(c):
		return
	var dmg := _creature_damage_amount()
	var landed: Variant = c.call("receive_hit", dmg, self)
	if bool(landed):
		var hit_pos := global_position
		if c is Node3D:
			hit_pos = (c as Node3D).global_position
		_trigger_hit_feedback(_equipped_main_hand_id_str(), hit_pos)


func get_magic_cast_forward_xz() -> Vector3:
	if camera_3d != null:
		var cf := -camera_3d.global_transform.basis.z
		cf.y = 0.0
		if cf.length_squared() > 1e-6:
			return cf.normalized()
	var b := global_transform.basis
	var f := -b.z
	f.y = 0.0
	if f.length_squared() > 1e-6:
		return f.normalized()
	return Vector3(0.0, 0.0, -1.0)


func notify_weapon_hit_landed(world_position: Vector3) -> void:
	if not is_instance_valid(self):
		return
	_trigger_hit_feedback(_equipped_main_hand_id_str(), world_position)


func _get_resolved_hit_feedback(weapon_item_id: String) -> Dictionary:
	var hitstop_dur := melee_hitstop_duration_sec
	var hitstop_ts := melee_hitstop_time_scale
	var shake_dur := melee_hit_camera_shake_duration_sec
	var shake_amp := melee_hit_camera_shake_amplitude
	var snd: AudioStream = hit_feedback_default_impact_sound
	var vfx: PackedScene = hit_feedback_default_impact_vfx_scene
	if vfx == null:
		vfx = _DefaultHitVfxScene
	if not weapon_item_id.is_empty():
		var it: ItemData = ItemCatalog.get_item(weapon_item_id)
		if it is WeaponData:
			var wd: WeaponData = it as WeaponData
			if wd.weapon_stats != null:
				var ws: WeaponStats = wd.weapon_stats
				if ws.hit_feedback_hitstop_duration_sec >= 0.0:
					hitstop_dur = ws.hit_feedback_hitstop_duration_sec
				if ws.hit_feedback_hitstop_time_scale >= 0.0:
					hitstop_ts = ws.hit_feedback_hitstop_time_scale
				if ws.hit_feedback_camera_shake_duration_sec >= 0.0:
					shake_dur = ws.hit_feedback_camera_shake_duration_sec
				if ws.hit_feedback_camera_shake_amplitude >= 0.0:
					shake_amp = ws.hit_feedback_camera_shake_amplitude
				if ws.hit_feedback_impact_sound != null:
					snd = ws.hit_feedback_impact_sound
				if ws.hit_feedback_impact_vfx_scene != null:
					vfx = ws.hit_feedback_impact_vfx_scene
	return {
		"hitstop_dur": hitstop_dur,
		"hitstop_ts": hitstop_ts,
		"shake_dur": shake_dur,
		"shake_amp": shake_amp,
		"sound": snd,
		"vfx": vfx,
	}


func _trigger_hit_feedback(weapon_item_id: String, impact_world_position: Vector3) -> void:
	var cfg := _get_resolved_hit_feedback(weapon_item_id)
	if melee_hitstop_enabled:
		_begin_melee_hitstop(cfg["hitstop_dur"], cfg["hitstop_ts"])
	if melee_hit_camera_shake_enabled:
		_begin_melee_camera_shake(cfg["shake_amp"], cfg["shake_dur"])
	_play_hit_impact_sound(cfg["sound"], impact_world_position)
	if hit_feedback_enable_impact_vfx:
		_spawn_hit_impact_vfx(cfg["vfx"], impact_world_position)


func _ensure_hit_feedback_audio() -> AudioStreamPlayer3D:
	if _hit_feedback_audio != null and is_instance_valid(_hit_feedback_audio):
		return _hit_feedback_audio
	_hit_feedback_audio = AudioStreamPlayer3D.new()
	_hit_feedback_audio.max_distance = 28.0
	add_child(_hit_feedback_audio)
	return _hit_feedback_audio


func _play_hit_impact_sound(stream: AudioStream, world_position: Vector3) -> void:
	if stream == null:
		return
	var p := _ensure_hit_feedback_audio()
	p.global_position = world_position
	p.stream = stream
	p.play()


func _spawn_hit_impact_vfx(scene: PackedScene, world_position: Vector3) -> void:
	if scene == null:
		return
	var inst := scene.instantiate()
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		parent = self
	parent.add_child(inst)
	if inst is Node3D:
		(inst as Node3D).global_position = world_position + Vector3(0, 0.45, 0)


func _begin_melee_hitstop(duration_sec: float = -1.0, time_scale_value: float = -1.0) -> void:
	if not melee_hitstop_enabled:
		return
	if duration_sec < 0.0:
		duration_sec = melee_hitstop_duration_sec
	if time_scale_value < 0.0:
		time_scale_value = melee_hitstop_time_scale
	if not _melee_hitstop_active:
		_melee_hitstop_prev_time_scale = Engine.time_scale
		_melee_hitstop_active = true
	Engine.time_scale = clampf(time_scale_value, 0.02, 1.0)
	var extend_to := Time.get_ticks_msec() + int(maxf(1.0, duration_sec * 1000.0))
	if extend_to > _melee_hitstop_end_ticks_ms:
		_melee_hitstop_end_ticks_ms = extend_to


func _begin_melee_camera_shake(shake_amp: float = -1.0, duration_sec: float = -1.0) -> void:
	if not melee_hit_camera_shake_enabled or camera_3d == null:
		return
	if shake_amp < 0.0:
		shake_amp = melee_hit_camera_shake_amplitude
	if duration_sec < 0.0:
		duration_sec = melee_hit_camera_shake_duration_sec
	duration_sec = maxf(0.02, duration_sec)
	_melee_cam_shake_amp_effective = shake_amp
	_melee_cam_shake_dur_effective = duration_sec
	_melee_cam_shake_time_left_sec = maxf(_melee_cam_shake_time_left_sec, duration_sec)


func _update_melee_hit_camera_shake(delta: float) -> void:
	if camera_3d == null:
		return
	if _melee_cam_shake_time_left_sec <= 0.0:
		camera_3d.position = _melee_cam_shake_rest_pos
		return
	var dt := delta / maxf(Engine.time_scale, 0.001)
	_melee_cam_shake_time_left_sec -= dt
	var dur := maxf(0.0001, _melee_cam_shake_dur_effective)
	var t := clampf(_melee_cam_shake_time_left_sec / dur, 0.0, 1.0)
	var amp := _melee_cam_shake_amp_effective * t
	var shake := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if shake.length_squared() > 1e-8:
		shake = shake.normalized()
	camera_3d.position = _melee_cam_shake_rest_pos + shake * amp
	if _melee_cam_shake_time_left_sec <= 0.0:
		camera_3d.position = _melee_cam_shake_rest_pos


func _creature_target_still_valid_for_hit(c: Object) -> bool:
	if c == null or not is_instance_valid(c):
		return false
	if c is Node3D:
		var n := c as Node3D
		if global_position.distance_to(n.global_position) > melee_reach_distance + 0.9:
			return false
	return true


func _invalidate_pending_creature_impacts() -> void:
	_creature_impact_generation += 1
	_pending_creature_ref = null


func _on_creature_melee_impact_timeout(seq: int) -> void:
	_apply_creature_melee_damage_at_impact(seq)


func _find_creature_melee_target() -> Object:
	var best: Object = null
	var best_d2: float = INF
	var origin := global_position + Vector3(0.0, interaction_height, 0.0)
	for n in get_tree().get_nodes_in_group("creature"):
		if not (n is Node3D):
			continue
		var c := n as Object
		if not _is_creature_candidate(c):
			continue
		var t := n as Node3D
		var to_t := t.global_position - origin
		to_t.y = 0.0
		if to_t.length_squared() < 0.0001:
			continue
		var fwd := base_character.global_transform.basis.z
		fwd.y = 0.0
		if fwd.length_squared() < 0.0001:
			fwd = Vector3(0.0, 0.0, 1.0)
		else:
			fwd = fwd.normalized()
		if fwd.dot(to_t.normalized()) < melee_forward_dot_min:
			continue
		var d2 := to_t.length_squared()
		if d2 > pow(melee_reach_distance + melee_hit_radius, 2.0):
			continue
		if d2 < best_d2:
			best_d2 = d2
			best = c
	return best


## Visual-only swing when reticle has no valid harvest/creature target (no damage, no harvest timers).
func _try_play_attack_air_whiff() -> bool:
	if base_character == null:
		return false
	if base_character.has_method("is_animation_locked") and base_character.is_animation_locked():
		return false
	var family := _equipped_attack_weapon_family()
	var played: bool = false
	match family:
		_WeaponStats.WeaponFamily.BOW:
			return false
		_WeaponStats.WeaponFamily.STAFF:
			if base_character.has_method("try_play_action_for_harvest"):
				played = base_character.try_play_action_for_harvest("interact")
		_:
			if base_character.has_method("try_play_melee_attack_1h"):
				played = base_character.try_play_melee_attack_1h()
	if played:
		_queue_melee_face_camera_forward_xz()
	return played


func _equipped_back_has_quiver() -> bool:
	var b: Variant = GameState.equipment.get("back", null)
	if b == null:
		return false
	var id := GameState.normalize_item_id(str(b.get("id", "")))
	if id.begins_with("quiver_"):
		return true
	var it: ItemData = ItemCatalog.get_item(id)
	if it == null:
		return false
	for tag in it.tags:
		if str(tag) == "quiver":
			return true
	return false


func _gather_collision_rids_recursive(n: Node, out: Array) -> void:
	if n is CollisionObject3D:
		out.append((n as CollisionObject3D).get_rid())
	for c in n.get_children():
		_gather_collision_rids_recursive(c, out)


func _projectile_exclude_rids() -> Array:
	var rids: Array = []
	_gather_collision_rids_recursive(self, rids)
	return rids


func _get_reticle_world_aim(max_dist: float) -> Dictionary:
	var vp := get_viewport()
	if vp == null or camera_3d == null:
		var fwd := -global_transform.basis.z
		var ap := global_position + fwd * minf(4.0, max_dist)
		return {"origin": global_position, "direction": fwd, "aim_point": ap}
	var center := _get_crosshair_screen_point()
	var cam_orig := camera_3d.project_ray_origin(center)
	var cast_dir := camera_3d.project_ray_normal(center).normalized()
	var cam_fwd := (-camera_3d.global_transform.basis.z).normalized()
	if cast_dir.dot(cam_fwd) < 0.0:
		cast_dir = -cast_dir
	var to := cam_orig + cast_dir * max_dist
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam_orig, to)
	q.collision_mask = arrow_physics_collision_mask
	q.exclude = _projectile_exclude_rids()
	var hit := space.intersect_ray(q)
	var aim_point: Vector3 = to
	if not hit.is_empty():
		aim_point = hit.position
	return {"origin": cam_orig, "direction": cast_dir, "aim_point": aim_point}


func _spawn_arrow_projectile() -> void:
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		parent = self
	var proj_variant: Variant = _ArrowProjectileScene.instantiate()
	if not (proj_variant is Node):
		return
	var proj: Node = proj_variant as Node
	parent.add_child(proj)
	var aim := _get_reticle_world_aim(arrow_aim_max_distance)
	var spawn_pos: Vector3 = base_character.get_arrow_spawn_global_position()
	var dir: Vector3 = aim.aim_point - spawn_pos
	var excl := _projectile_exclude_rids()
	if proj.has_method("fire"):
		proj.call(
			"fire",
			self,
			_creature_damage_amount(),
			spawn_pos,
			dir,
			arrow_projectile_speed,
			arrow_physics_collision_mask,
			arrow_projectile_gravity_scale,
			arrow_projectile_lifetime,
			excl
		)


func _total_arrow_ammo_count() -> int:
	var n := 0
	for id in _ARROW_AMMO_IDS_CONSUME_ORDER:
		n += InventoryService.get_item_count(id)
	return n


func _take_one_arrow_for_fire() -> bool:
	for id in _ARROW_AMMO_IDS_CONSUME_ORDER:
		if InventoryService.get_item_count(id) >= 1:
			InventoryService.remove_item(id, 1)
			return true
	return false


func _try_bow_release_fire() -> bool:
	if base_character == null or not base_character.has_method("try_play_bow_release"):
		return false
	if not _equipped_back_has_quiver():
		show_gameplay_message("Equip a quiver on your back to fire arrows.")
		if base_character.has_method("try_cancel_bow_draw"):
			base_character.try_cancel_bow_draw()
		return false
	if _total_arrow_ammo_count() < 1:
		show_gameplay_message("You have no arrows.")
		if base_character.has_method("try_cancel_bow_draw"):
			base_character.try_cancel_bow_draw()
		return false
	if not base_character.try_play_bow_release():
		return false
	if not _take_one_arrow_for_fire():
		return false
	_spawn_arrow_projectile()
	return true


func _tool_kind_for_equipped_main(item_id: String) -> _BaseCharacter.ToolKind:
	match item_id:
		"hatchet_basic", "hatchet_bronze":
			return _BaseCharacter.ToolKind.AXE
		"pickaxe_basic", "pickaxe_bronze":
			return _BaseCharacter.ToolKind.PICKAXE
		"fishing_pole":
			return _BaseCharacter.ToolKind.FISHING_ROD
		_:
			return _BaseCharacter.ToolKind.NONE


func _use_hotbar_slot(slot_idx: int) -> void:
	GameState.ensure_hotbar_arrays()
	if GameState.hotbar_spell_ids.size() > slot_idx:
		var spell_id := str(GameState.hotbar_spell_ids[slot_idx])
		if not spell_id.is_empty():
			_try_cast_bound_spell(spell_id)
			return
	if GameState.hotbar_item_ids.size() > slot_idx:
		var item_id := str(GameState.hotbar_item_ids[slot_idx])
		if not item_id.is_empty():
			_use_hotbar_item(item_id)
			return
	_set_player_tool(_default_tool_for_slot(slot_idx))


func _use_hotbar_item(item_id: String) -> void:
	if not InventoryService.has_item(item_id):
		show_gameplay_message("Missing: %s" % InventoryService.get_item_display_name(item_id))
		return
	var it: ItemData = ItemCatalog.get_item(item_id)
	if it != null and it.category == ItemData.Category.RUNE:
		_try_cast_rune_item(item_id)
		return
	_quick_equip_hotbar_item(item_id)
	var tool_kind: _BaseCharacter.ToolKind = _tool_kind_for_item(item_id)
	if tool_kind != _BaseCharacter.ToolKind.NONE:
		_set_player_tool(tool_kind)
		return
	if base_character != null and base_character.has_method("set_active_tool"):
		base_character.set_active_tool(_BaseCharacter.ToolKind.NONE)


func _quick_equip_hotbar_item(item_id: String) -> void:
	var it: ItemData = ItemCatalog.get_item(item_id)
	if it == null:
		return
	var equip_slot := ""
	match it.category:
		ItemData.Category.TOOL, ItemData.Category.WEAPON:
			equip_slot = "main_hand"
		ItemData.Category.RELIC:
			equip_slot = "off_hand"
		_:
			return
	# Shields and similar defensive items should be off-hand when quick-selected.
	for tag in it.tags:
		var t := str(tag)
		if t == "shield":
			equip_slot = "off_hand"
			break
	if _CombatFormulaService.equipped_weapon_family(item_id) == _WeaponStats.WeaponFamily.BOW:
		equip_slot = "off_hand"
	if item_id == "tool_torch":
		equip_slot = "off_hand"
	if item_id.begins_with("quiver_") or item_id.begins_with("backpack_"):
		equip_slot = "back"
	GameState.set_equipment_slot(equip_slot, item_id, 1)
	_sync_equipped_hand_visuals()


func _tool_kind_for_item(item_id: String) -> _BaseCharacter.ToolKind:
	var it: ItemData = ItemCatalog.get_item(item_id)
	if it == null:
		return _BaseCharacter.ToolKind.NONE
	for tag in it.tags:
		var t := str(tag)
		if t == "hatchet" or t == "axe":
			return _BaseCharacter.ToolKind.AXE
		if t == "pickaxe":
			return _BaseCharacter.ToolKind.PICKAXE
		if t == "fishing_rod" or t == "fishing":
			return _BaseCharacter.ToolKind.FISHING_ROD
	return _BaseCharacter.ToolKind.NONE


func _try_cast_rune_item(item_id: String) -> bool:
	var item: ItemData = ItemCatalog.get_item(item_id)
	if item == null:
		show_gameplay_message("That rune has no effect yet.")
		return false
	var effect_id := _RuneEffectService.resolve_effect_id(item_id, item)
	var cooldown_ms: int = item.use_cooldown_ms
	if cooldown_ms <= 0:
		cooldown_ms = _RuneEffectService.default_cooldown_ms(effect_id)
	var now_ms: int = Time.get_ticks_msec()
	var cooldown_key := effect_id if not effect_id.is_empty() else item_id
	var next_ready: int = int(_rune_cooldown_until_ms.get(cooldown_key, 0))
	if now_ms < next_ready:
		var sec_left := ceili(float(next_ready - now_ms) / 1000.0)
		show_gameplay_message("%s is on cooldown (%ds)." % [InventoryService.get_item_display_name(item_id), sec_left])
		return false
	if effect_id == "spell_air_push":
		if not _RuneEffectService.has_air_push_target(self):
			show_gameplay_message("No creature in front of you.")
			return false
		if base_character != null and base_character.has_method("try_play_rune_air_push"):
			if not base_character.try_play_rune_air_push():
				show_gameplay_message("You can't cast that right now.")
				return false
	var result: Dictionary = _RuneEffectService.cast(effect_id, self)
	if not bool(result.get("success", false)):
		show_gameplay_message(str(result.get("message", "That rune has no effect yet.")))
		return false
	if cooldown_ms > 0:
		_rune_cooldown_until_ms[cooldown_key] = now_ms + cooldown_ms
	show_gameplay_message(str(result.get("message", "Rune effect triggered.")))
	return true


func _try_cast_bound_spell(spell_id: String) -> bool:
	if spell_id.is_empty():
		return false
	var effect_id := spell_id
	var cooldown_ms: int = _RuneEffectService.default_cooldown_ms(effect_id)
	var now_ms: int = Time.get_ticks_msec()
	var cooldown_key := effect_id
	var next_ready: int = int(_rune_cooldown_until_ms.get(cooldown_key, 0))
	if now_ms < next_ready:
		var sec_left := ceili(float(next_ready - now_ms) / 1000.0)
		show_gameplay_message(
			"%s is on cooldown (%ds)." % [_SpellCatalog.get_display_name(spell_id), sec_left]
		)
		return false
	if effect_id == "spell_air_push":
		if not _RuneEffectService.has_air_push_target(self):
			show_gameplay_message("No creature in front of you.")
			return false
		if base_character != null and base_character.has_method("try_play_rune_air_push"):
			if not base_character.try_play_rune_air_push():
				show_gameplay_message("You can't cast that right now.")
				return false
	var result: Dictionary = _RuneEffectService.cast(effect_id, self)
	if not bool(result.get("success", false)):
		show_gameplay_message(str(result.get("message", "That spell failed.")))
		return false
	if cooldown_ms > 0:
		_rune_cooldown_until_ms[cooldown_key] = now_ms + cooldown_ms
	show_gameplay_message(str(result.get("message", "Spell cast.")))
	return true


func _default_tool_for_slot(_slot_idx: int) -> _BaseCharacter.ToolKind:
	return _BaseCharacter.ToolKind.NONE


func get_hud_snapshot() -> Dictionary:
	var tk: int = int(_BaseCharacter.ToolKind.NONE)
	if base_character != null and base_character.has_method("get_active_tool_kind"):
		tk = int(base_character.get_active_tool_kind())
	return {
		"health": health,
		"max_health": max_health,
		"stamina": stamina,
		"max_stamina": max_stamina,
		"tool_kind": tk,
	}


func get_equipment_sheet_snapshot() -> Dictionary:
	var tool_str := "—"
	if base_character != null and base_character.has_method("get_active_tool_kind"):
		tool_str = _tool_display_name(base_character.get_active_tool_kind())
	var gs: Node = get_node_or_null("/root/GameState")
	var head_s := "—"
	var chest_s := "—"
	var legs_s := "—"
	if gs != null:
		head_s = "Look %d" % (int(gs.head_index) + 1)
		chest_s = "Shirt %d" % (int(gs.shirt_index) + 1)
		legs_s = "Pants %d" % (int(gs.pants_index) + 1)
	return {
		"active_tool": tool_str,
		"head": head_s,
		"chest": chest_s,
		"legs": legs_s,
	}


func _tool_display_name(kind: _BaseCharacter.ToolKind) -> String:
	match kind:
		_BaseCharacter.ToolKind.AXE:
			return "Hatchet"
		_BaseCharacter.ToolKind.PICKAXE:
			return "Pickaxe"
		_BaseCharacter.ToolKind.FISHING_ROD:
			return "Fishing rod"
		_:
			return "Unarmed"


func show_gameplay_message(msg: String) -> void:
	if gameplay_toast != null and gameplay_toast.has_method("show_message"):
		gameplay_toast.show_message(msg)


func open_crafting_station(station_id: int) -> bool:
	if game_menu == null:
		show_gameplay_message("Cannot open forge right now.")
		return false
	if game_menu.has_method("open_forge_crafting_basic"):
		game_menu.call("open_forge_crafting_basic")
	elif game_menu.has_method("toggle"):
		game_menu.call("toggle", GameMenu.TAB_FORGE)
	if game_menu.has_method("_set_craft_station_filter"):
		game_menu.call("_set_craft_station_filter", station_id)
	return true


func try_place_build_item(item_id: String, rotation_y: float = 0.0) -> bool:
	var norm_id := GameState.normalize_item_id(item_id)
	if norm_id.is_empty():
		return false
	if not InventoryService.has_item(norm_id):
		show_gameplay_message("Missing: %s" % InventoryService.get_item_display_name(norm_id))
		return false
	var p := _compute_build_placement(norm_id, rotation_y)
	if not bool(p.get("valid", false)):
		show_gameplay_message(str(p.get("reason", "Cannot place here.")))
		return false
	var scene: PackedScene = InventoryService.get_pickup_scene_for_item(norm_id)
	if scene == null:
		show_gameplay_message("Cannot place this item.")
		return false
	var inst := scene.instantiate()
	if not (inst is Node3D):
		show_gameplay_message("Invalid placeable scene.")
		return false
	var place_node := inst as Node3D
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return false
	parent.add_child(place_node)
	place_node.global_position = p["position"] as Vector3
	var normal := p.get("normal", Vector3.UP) as Vector3
	if norm_id == "campfire_kit":
		place_node.global_basis = _basis_from_up_and_yaw(normal, rotation_y)
	else:
		place_node.rotation.y = rotation_y
	if norm_id == "tool_torch" or norm_id == "campfire_kit":
		InventoryService._persist_placeable_fire_if_needed(norm_id, place_node)
	InventoryService.remove_item(norm_id, 1)
	return true


func set_build_preview_item(item_id: String) -> void:
	var norm := GameState.normalize_item_id(item_id)
	if norm == _build_preview_item_id:
		return
	_build_preview_item_id = norm
	_rebuild_build_preview_node()
	_build_mode_active = not _build_preview_item_id.is_empty()


func set_build_preview_rotation(rotation_y: float) -> void:
	_build_preview_rotation_y = rotation_y
	if _build_preview_node != null:
		_build_preview_node.rotation.y = _build_preview_rotation_y


func clear_build_preview() -> void:
	_build_preview_item_id = ""
	if _build_preview_node != null and is_instance_valid(_build_preview_node):
		_build_preview_node.queue_free()
	_build_preview_node = null
	_build_preview_valid = false
	_build_mode_active = false


func begin_build_placement(item_id: String, rotation_y: float = 0.0) -> void:
	_build_mode_active = true
	set_build_preview_rotation(rotation_y)
	set_build_preview_item(item_id)


func cancel_build_placement() -> void:
	clear_build_preview()
	show_gameplay_message("Build placement canceled.")


func _rebuild_build_preview_node() -> void:
	if _build_preview_node != null and is_instance_valid(_build_preview_node):
		_build_preview_node.queue_free()
	_build_preview_node = null
	_build_preview_valid = false
	if _build_preview_item_id.is_empty():
		return
	var scene: PackedScene = InventoryService.get_pickup_scene_for_item(_build_preview_item_id)
	if scene == null:
		return
	var inst := scene.instantiate()
	if not (inst is Node3D):
		return
	_build_preview_node = inst as Node3D
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		_build_preview_node = null
		return
	parent.add_child(_build_preview_node)
	_set_collision_disabled_recursive(_build_preview_node)
	_apply_build_preview_visual(false)
	_build_preview_node.rotation.y = _build_preview_rotation_y


func _set_collision_disabled_recursive(n: Node) -> void:
	if n is CollisionObject3D:
		var co := n as CollisionObject3D
		co.collision_layer = 0
		co.collision_mask = 0
	if n is CollisionShape3D:
		(n as CollisionShape3D).disabled = true
	for c in n.get_children():
		_set_collision_disabled_recursive(c)


func _apply_build_preview_visual(valid: bool) -> void:
	if _build_preview_node == null:
		return
	var tint := Color(0.2, 0.9, 0.35, 0.45) if valid else Color(0.95, 0.22, 0.22, 0.45)
	var meshes: Array[Node] = _build_preview_node.find_children("*", "MeshInstance3D", true, false)
	for n in meshes:
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var surf_count := mi.mesh.get_surface_count() if mi.mesh != null else 0
		for s in range(surf_count):
			var mat: Material = mi.get_active_material(s)
			if mat == null and mi.mesh != null:
				mat = mi.mesh.surface_get_material(s)
			if mat == null or not (mat is BaseMaterial3D):
				continue
			var dup := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dup.albedo_color = tint
			dup.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			dup.no_depth_test = true
			mi.set_surface_override_material(s, dup)


func _update_build_preview() -> void:
	if _build_preview_item_id.is_empty():
		if _build_preview_node != null:
			clear_build_preview()
		return
	if _build_preview_node == null or not is_instance_valid(_build_preview_node):
		_rebuild_build_preview_node()
	if _build_preview_node == null:
		return
	var p := _compute_build_placement(_build_preview_item_id, _build_preview_rotation_y)
	var pos := p.get("position", global_position) as Vector3
	var normal := p.get("normal", Vector3.UP) as Vector3
	_build_preview_node.global_position = pos
	if _build_preview_item_id == "campfire_kit":
		_build_preview_node.global_basis = _basis_from_up_and_yaw(normal, _build_preview_rotation_y)
	else:
		_build_preview_node.rotation.y = _build_preview_rotation_y
	var valid := bool(p.get("valid", false))
	if valid != _build_preview_valid:
		_build_preview_valid = valid
		_apply_build_preview_visual(valid)
	_update_build_mode_prompt()


func _compute_build_placement(item_id: String, rotation_y: float) -> Dictionary:
	var aim := _get_reticle_world_aim(build_place_distance)
	var origin := global_position + Vector3.UP * 0.25
	var target: Vector3 = aim.aim_point
	if origin.distance_to(target) > build_place_distance:
		target = origin + (target - origin).normalized() * build_place_distance
	var from := target + Vector3.UP * 2.5
	var to := target + Vector3.DOWN * 5.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.exclude = _projectile_exclude_rids()
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {"valid": false, "position": target, "normal": Vector3.UP, "reason": "Need solid ground to place this."}
	var place_pos := hit["position"] as Vector3
	var nrm := (hit.get("normal", Vector3.UP) as Vector3).normalized()
	var check := SphereShape3D.new()
	var radius := 0.35
	if item_id == "campfire_kit":
		radius = 0.75
	check.radius = radius
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = check
	sq.transform = Transform3D(Basis.IDENTITY, place_pos + Vector3.UP * 0.35)
	sq.collide_with_areas = false
	sq.collide_with_bodies = true
	sq.exclude = _projectile_exclude_rids()
	var blockers := get_world_3d().direct_space_state.intersect_shape(sq, 8)
	if blockers.size() > 0:
		return {"valid": false, "position": place_pos, "normal": nrm, "reason": "Not enough space to place here."}
	return {"valid": true, "position": place_pos, "normal": nrm, "rotation_y": rotation_y}


func _basis_from_up_and_yaw(up: Vector3, yaw: float) -> Basis:
	var n := up.normalized()
	if n.length_squared() < 0.0001:
		n = Vector3.UP
	var yaw_fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var tangent := yaw_fwd.slide(n)
	if tangent.length_squared() < 0.0001:
		tangent = Vector3.FORWARD.slide(n)
	if tangent.length_squared() < 0.0001:
		tangent = Vector3.RIGHT
	tangent = tangent.normalized()
	var binormal := n.cross(tangent).normalized()
	var fwd := binormal.cross(n).normalized()
	return Basis(binormal, n, fwd)


func _update_build_mode_prompt() -> void:
	if interaction_prompt == null:
		return
	if not _build_mode_active:
		return
	var status := "PLACEMENT VALID" if _build_preview_valid else "PLACEMENT BLOCKED"
	var label := InventoryService.get_item_display_name(_build_preview_item_id)
	interaction_prompt.text = "[%s]  %s\nE: Set  RMB: Cancel  Wheel: Turn" % [status, label]
	interaction_prompt.add_theme_color_override(
		"font_color",
		Color(0.78, 0.91, 0.78, 1.0) if _build_preview_valid else Color(0.9, 0.47, 0.47, 1.0)
	)
	interaction_prompt.add_theme_color_override("font_shadow_color", Color(0.03, 0.03, 0.03, 0.95))
	interaction_prompt.visible = true


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
	var vp := get_viewport()
	if vp == null or camera_3d == null:
		return
	var center := _get_crosshair_screen_point()
	var interaction_anchor := global_position + Vector3(0.0, interaction_height, 0.0)
	var camera_origin := camera_3d.project_ray_origin(center)
	var cast_dir := camera_3d.project_ray_normal(center).normalized()
	var cam_forward := (-camera_3d.global_transform.basis.z).normalized()
	# Some camera setups can return an inverted screen-ray vector; ensure it always points where camera faces.
	if cast_dir.dot(cam_forward) < 0.0:
		cast_dir = -cast_dir
	# Keep the ray on the reticle line while projecting near the player's interaction height.
	var along := maxf(0.0, (interaction_anchor - camera_origin).dot(cast_dir))
	var interaction_origin := camera_origin + cast_dir * along
	interaction_ray.global_basis = Basis.IDENTITY
	interaction_ray.global_position = interaction_origin
	interaction_ray.target_position = cast_dir * interaction_range
	interaction_ray.force_raycast_update()


func _is_interaction_candidate(collider: Object) -> bool:
	if collider == null:
		return false
	if collider.has_method("harvest_hit"):
		return true
	if _is_creature_candidate(collider):
		return true
	if not _resolve_world_item_id_from_collider(collider).is_empty():
		return true
	return _resolve_interactable_target(collider) != null


func _is_creature_candidate(collider: Object) -> bool:
	if collider == null:
		return false
	if not collider.has_method("receive_hit"):
		return false
	if collider.has_method("can_receive_hit"):
		return bool(collider.call("can_receive_hit"))
	return true


func _fallback_interaction_collider() -> Object:
	if camera_3d == null:
		return null
	var shape := SphereShape3D.new()
	shape.radius = maxf(0.05, interaction_fallback_radius)
	var vp := get_viewport()
	if vp == null:
		return null
	var center := _get_crosshair_screen_point()
	var interaction_anchor := global_position + Vector3(0.0, interaction_height, 0.0)
	var camera_origin := camera_3d.project_ray_origin(center)
	var dir := camera_3d.project_ray_normal(center).normalized()
	var cam_forward := (-camera_3d.global_transform.basis.z).normalized()
	if dir.dot(cam_forward) < 0.0:
		dir = -dir
	var along := maxf(0.0, (interaction_anchor - camera_origin).dot(dir))
	var from := camera_origin + dir * along
	var xform := Transform3D(Basis.IDENTITY, from + dir * minf(interaction_range * 0.6, 2.2))
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = xform
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(q, 12)
	if hits.is_empty():
		return null
	var best: Object = null
	var best_d2 := INF
	for h in hits:
		var c: Object = h.get("collider", null)
		if not _is_interaction_candidate(c):
			continue
		var p: Vector3 = h.get("point", from + dir * interaction_range)
		var d2 := from.distance_squared_to(p)
		if d2 < best_d2:
			best_d2 = d2
			best = c
	return best


func _get_interaction_collider() -> Object:
	_update_interaction_ray()
	if interaction_ray != null and interaction_ray.is_colliding():
		var ray_c: Object = interaction_ray.get_collider()
		if _is_interaction_candidate(ray_c):
			return ray_c
	return _fallback_interaction_collider()


func _refresh_interaction_collider_cache(force_refresh: bool = false) -> void:
	var frame_now: int = Engine.get_physics_frames()
	if not force_refresh and _cached_interaction_frame == frame_now:
		return
	_cached_interaction_collider = _get_interaction_collider()
	_cached_interaction_frame = frame_now


func _get_interaction_collider_cached(force_refresh: bool = false) -> Object:
	_refresh_interaction_collider_cache(force_refresh)
	return _cached_interaction_collider


func _resolve_harvest_target(collider: Object) -> Object:
	if collider == null:
		return null
	var cur: Node = collider as Node
	var hops: int = 0
	while cur != null and hops < 6:
		if cur.has_method("harvest_hit"):
			return cur
		cur = cur.get_parent()
		hops += 1
	return null


func _get_crosshair_screen_point() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2.ZERO
	var rect := vp.get_visible_rect()
	return rect.size * 0.5 + crosshair_screen_offset_px


func _update_reticle_position() -> void:
	if reticle == null:
		return
	var p := _get_crosshair_screen_point()
	reticle.position = p - reticle.size * 0.5


func _is_door_like_target(target: Object) -> bool:
	if target == null:
		return false
	if target.has_method("is_locked"):
		return true
	var n := target as Node
	if n == null:
		return false
	if n.has_meta("door_locked") or n.has_meta("is_door"):
		return true
	var lower_name := n.name.to_lower()
	return lower_name.find("door") >= 0


## Returns -1 when lock state is unknown, 0 unlocked, 1 locked.
func _door_lock_state(target: Object) -> int:
	if target == null:
		return -1
	if target.has_method("is_locked"):
		return 1 if bool(target.call("is_locked")) else 0
	var n := target as Node
	if n == null:
		return -1
	if n.has_meta("door_locked"):
		return 1 if bool(n.get_meta("door_locked")) else 0
	return -1


func _update_reticle_icon() -> void:
	if reticle == null:
		return
	var icon: Texture2D = reticle_icon_default
	var collider: Object = _get_interaction_collider_cached()
	if collider != null:
		var interactable: Object = _resolve_interactable_target(collider)
		if collider.has_method("harvest_hit"):
			var action := "chop"
			if collider.has_method("get_harvest_action"):
				action = String(collider.get_harvest_action())
			icon = reticle_icon_mine if action == "mine" else reticle_icon_attack
		elif _is_creature_candidate(collider):
			icon = reticle_icon_attack
		elif interactable != null:
			if _is_door_like_target(interactable):
				var lock_state := _door_lock_state(interactable)
				if lock_state == 1:
					icon = reticle_icon_door_locked
				elif lock_state == 0:
					icon = reticle_icon_door_unlocked
				else:
					icon = reticle_icon_interact
			elif interactable.has_method("get_interaction_prompt"):
				var prompt := String(interactable.call("get_interaction_prompt", self)).to_lower()
				if prompt.find("water") >= 0 and reticle_icon_watering != null:
					icon = reticle_icon_watering
				else:
					icon = reticle_icon_interact
			else:
				icon = reticle_icon_interact
	if icon == null:
		icon = reticle_icon_default
	reticle.texture = icon


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


func _clear_harvest_interact_approach() -> void:
	_harvest_interact_pending = false
	_harvest_interact_target = null


func _start_harvest_interact_approach(collider: Object) -> void:
	_harvest_interact_pending = true
	_harvest_interact_target = weakref(collider)


func _harvest_interact_move_input() -> Vector2:
	if not _harvest_interact_pending:
		return Vector2.ZERO
	var c: Object = _harvest_interact_target.get_ref() if _harvest_interact_target != null else null
	if c == null or not is_instance_valid(c):
		_clear_harvest_interact_approach()
		return Vector2.ZERO
	if not (c is Node3D):
		_clear_harvest_interact_approach()
		return Vector2.ZERO
	var t := c as Node3D
	var to_t := t.global_position - global_position
	to_t.y = 0.0
	var dist := to_t.length()
	var start_dist := _harvest_interact_distance_for(c)
	if dist <= start_dist:
		return Vector2.ZERO
	var world_dir := to_t.normalized()
	if camera_3d == null:
		return Vector2(world_dir.x, -world_dir.z)
	var cam_basis := camera_3d.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	var right := cam_basis.x
	right.y = 0.0
	if forward.length_squared() < 0.0001 or right.length_squared() < 0.0001:
		return Vector2.ZERO
	forward = forward.normalized()
	right = right.normalized()
	var x := world_dir.dot(right)
	var y := -world_dir.dot(forward)
	return Vector2(x, y).limit_length(1.0)


func _harvest_interact_within_start_distance(t: Node3D) -> bool:
	var c: Object = t
	var start_dist := _harvest_interact_distance_for(c)
	var to_t := t.global_position - global_position
	to_t.y = 0.0
	# Small slack so float error / collider vs pivot offset does not strand the player at the threshold.
	return to_t.length() <= start_dist + 0.18


func _harvest_face_toward_node3d(t: Node3D, delta: float) -> void:
	if base_character == null:
		return
	var blocking: bool = base_character.has_method("is_blocking") and base_character.is_blocking()
	var to_t := t.global_position - global_position
	to_t.y = 0.0
	if to_t.length_squared() < 0.0001:
		return
	to_t = to_t.normalized()
	var target_rot := atan2(to_t.x, to_t.z)
	var mult := shield_block_turn_multiplier if blocking else 1.0
	base_character.rotation.y = lerp_angle(base_character.rotation.y, target_rot, turn_speed * mult * delta)


func _harvest_interact_ready(collider: Object) -> bool:
	if collider == null or not is_instance_valid(collider):
		return false
	if not (collider is Node3D):
		return false
	var t := collider as Node3D
	var to_t := t.global_position - global_position
	to_t.y = 0.0
	var start_dist := _harvest_interact_distance_for(collider)
	if to_t.length() > start_dist:
		return false
	var fwd := base_character.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001 or to_t.length_squared() < 0.0001:
		return false
	fwd = fwd.normalized()
	to_t = to_t.normalized()
	return fwd.dot(to_t) >= _harvest_interact_face_dot_for(collider)


func _harvest_interact_distance_for(collider: Object) -> float:
	if collider != null and collider.has_method("get_harvest_action"):
		var action := String(collider.call("get_harvest_action"))
		if action == "mine":
			return harvest_interact_start_distance_mine
		if action == "chop":
			return harvest_interact_start_distance_chop
	return harvest_interact_start_distance


func _harvest_interact_face_dot_for(collider: Object) -> float:
	if collider != null and collider.has_method("get_harvest_action"):
		var action := String(collider.call("get_harvest_action"))
		if action == "mine":
			return harvest_interact_face_dot_min_mine
		if action == "chop":
			return harvest_interact_face_dot_min_chop
	return harvest_interact_face_dot_min


func _try_start_pending_harvest_interact() -> void:
	if not _harvest_interact_pending:
		return
	var c: Object = _harvest_interact_target.get_ref() if _harvest_interact_target != null else null
	if c == null or not is_instance_valid(c):
		_clear_harvest_interact_approach()
		return
	if c.has_method("can_harvest") and not c.can_harvest():
		_clear_harvest_interact_approach()
		return
	if not _harvest_interact_ready(c):
		return
	if base_character != null and base_character.has_method("is_movement_locked") and base_character.is_movement_locked():
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _next_harvest_allowed_ms:
		return
	var res: Array = _begin_harvest_on_collider(c)
	if bool(res[0]):
		var dur_sec: float = float(res[1])
		_next_harvest_allowed_ms = now_ms + int(dur_sec * 1000.0)
		_harvest_schedule_auto_chain(c, dur_sec)
		_clear_harvest_interact_approach()
		return
	if not _harvest_skill_met(c):
		show_gameplay_message("You need the right tool and level to harvest this.")
	_clear_harvest_interact_approach()


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
		_abort_harvest_tool_animation()
		return
	if c.has_method("can_harvest") and not c.can_harvest():
		_abort_harvest_tool_animation()
		return
	var move_check := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _movement_cancels_harvest(move_check):
		_abort_harvest_tool_animation()
		return
	if not _harvest_auto_target_still_valid(c):
		_abort_harvest_tool_animation()
		return
	if not _harvest_skill_met(c):
		_abort_harvest_tool_animation()
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
			_abort_harvest_tool_animation()
			return
	if gen != _harvest_auto_gen or not _harvest_auto_active:
		return
	c = _harvest_auto_target.get_ref() if _harvest_auto_target != null else null
	if c == null or not is_instance_valid(c):
		_abort_harvest_tool_animation()
		return
	if c.has_method("can_harvest") and not c.can_harvest():
		_abort_harvest_tool_animation()
		return
	if not _harvest_auto_target_still_valid(c):
		_abort_harvest_tool_animation()
		return
	if not _harvest_skill_met(c):
		_abort_harvest_tool_animation()
		return
	var res: Array = _begin_harvest_on_collider(c)
	if not bool(res[0]):
		_abort_harvest_tool_animation()
		return
	_schedule_harvest_auto_followup(float(res[1]), gen)


func _harvest_auto_target_still_valid(c: Object) -> bool:
	if c == null or not is_instance_valid(c):
		return false
	if not (c is Node3D):
		return false
	var t := c as Node3D
	var max_dist := maxf(interaction_range + 1.0, _harvest_interact_distance_for(c) + 2.0)
	if global_position.distance_to(t.global_position) > max_dist:
		return false
	if c.has_method("can_harvest") and not c.can_harvest():
		return false
	return true


func _movement_cancels_harvest(move_vec: Vector2) -> bool:
	var dz := clampf(harvest_move_cancel_deadzone, 0.0, 0.95)
	return move_vec.length() > dz


func _is_mid_harvest_tool_or_chain() -> bool:
	if _harvest_auto_active or _pending_chop_hit:
		return true
	return _is_harvest_tool_action_active()


func _is_harvest_tool_action_active() -> bool:
	return base_character != null and base_character.has_method("is_tool_action_active") and base_character.is_tool_action_active()


func _cancel_harvest_on_movement_input(move_vec: Vector2) -> void:
	if not _movement_cancels_harvest(move_vec):
		return
	_clear_harvest_interact_approach()
	if _is_mid_harvest_tool_or_chain():
		_abort_harvest_tool_animation()


func _cancel_harvest_on_movement_press() -> void:
	_clear_harvest_interact_approach()
	if _is_mid_harvest_tool_or_chain():
		_abort_harvest_tool_animation()


func _harvest_target_exhausted_after_hit(c: Object) -> bool:
	if c == null or not is_instance_valid(c):
		return true
	if c.has_method("can_harvest"):
		return not bool(c.call("can_harvest"))
	return false


func _begin_harvest_on_collider(collider: Object) -> Array:
	if _equipped_weapon_is_bow():
		return [false, harvest_click_cooldown_sec]
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
		if not _has_tool_in_inventory_or_equipped(["pickaxe_basic", "pickaxe_bronze"]):
			return false
		var req := 0
		if collider.has_method("get_required_mining_level"):
			req = int(collider.get_required_mining_level())
		if req <= 0:
			return true
		return state.get_skill_level("mining", state.mining_level) >= req
	if not _has_tool_in_inventory_or_equipped(["hatchet_basic", "hatchet_bronze"]):
		return false
	var req_wc := 0
	if collider.has_method("get_required_woodcutting_level"):
		req_wc = int(collider.get_required_woodcutting_level())
	if req_wc <= 0:
		return true
	return state.get_skill_level("woodcutting", state.woodcutting_level) >= req_wc


func _inventory_has_any(item_ids: Array[String]) -> bool:
	for item_id in item_ids:
		if InventoryService.has_item(item_id):
			return true
	return false


func _has_tool_in_inventory_or_equipped(item_ids: Array[String]) -> bool:
	if _inventory_has_any(item_ids):
		return true
	var eq_main: String = _equipped_main_hand_id_str()
	return item_ids.has(eq_main)


func _bump_harvest_timer_generation() -> int:
	_harvest_timer_generation += 1
	return _harvest_timer_generation


func _abort_harvest_tool_animation() -> void:
	_clear_harvest_interact_approach()
	_harvest_timer_generation += 1
	_pending_chop_hit = false
	_stop_harvest_auto()
	if base_character.has_method("cancel_tool_action"):
		base_character.cancel_tool_action()


func _try_harvest_hit_with_cooldown() -> Array:
	if _gameplay_input_blocked():
		return [false, harvest_click_cooldown_sec]
	if _equipped_weapon_is_bow():
		return [false, harvest_click_cooldown_sec]
	var collider: Object = _get_interaction_collider_cached(true)
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
	_invalidate_pending_creature_impacts()
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
	if _build_mode_active:
		_update_build_mode_prompt()
		return
	var collider: Object = _get_interaction_collider_cached()
	if collider == null:
		interaction_prompt.visible = false
		return
	var world_item := _resolve_world_item_target(collider)
	if not world_item.is_empty():
		var wi_id := str(world_item.get("item_id", ""))
		var wi_count: int = maxi(1, int(world_item.get("count", 1)))
		if not wi_id.is_empty():
			var label := InventoryService.get_item_display_name(wi_id)
			if wi_count > 1:
				interaction_prompt.text = "E: Pick up %d × %s" % [wi_count, label]
			else:
				interaction_prompt.text = "E: Pick up %s" % label
			interaction_prompt.visible = true
			return
	var interactable: Object = _resolve_interactable_target(collider)
	if interactable != null and interactable.has_method("get_interaction_prompt"):
		interaction_prompt.text = String(interactable.get_interaction_prompt(self))
		interaction_prompt.visible = not interaction_prompt.text.is_empty()
		return
	if _is_creature_candidate(collider):
		interaction_prompt.text = "LMB: Attack"
		interaction_prompt.visible = true
		return
	if not collider.has_method("harvest_hit"):
		interaction_prompt.visible = false
		return
	var txt := "E: Chop"
	if collider.has_method("get_harvest_action"):
		var act := String(collider.get_harvest_action())
		if act == "mine":
			txt = "E: Mine"
		else:
			txt = "E: Chop"
	if collider.has_method("get_prompt_detail"):
		var detail := String(collider.get_prompt_detail())
		if detail != "":
			txt += "\n" + detail
	if not _harvest_skill_met(collider):
		txt += "\n(Requires tool in inventory / level)"
	interaction_prompt.text = txt
	interaction_prompt.visible = true


func _resolve_interactable_target(collider: Object) -> Object:
	if collider == null:
		return null
	var cur: Node = collider as Node
	var hops: int = 0
	while cur != null and hops < 6:
		if cur.has_method("interact") or cur.has_method("get_interaction_prompt"):
			return cur
		cur = cur.get_parent()
		hops += 1
	return null


func _gameplay_input_blocked() -> bool:
	return game_menu != null and game_menu.visible


func _try_interact() -> void:
	if _gameplay_input_blocked():
		return
	var collider: Object = _get_interaction_collider_cached(true)
	if collider == null:
		return
	var harvest_target: Object = _resolve_harvest_target(collider)
	if harvest_target != null:
		if not _harvest_interact_ready(harvest_target):
			# If target is nearby, allow one-tap interact to auto-step into harvest range.
			if harvest_target is Node3D:
				var t3d := harvest_target as Node3D
				var max_approach_dist := interaction_range + 2.0
				if global_position.distance_to(t3d.global_position) > max_approach_dist:
					show_gameplay_message("Move closer and face the node to harvest.")
					return
			_start_harvest_interact_approach(harvest_target)
			return
		var now_ms: int = Time.get_ticks_msec()
		if now_ms < _next_harvest_allowed_ms:
			return
		var res: Array = _begin_harvest_on_collider(harvest_target)
		if bool(res[0]):
			var dur_sec: float = float(res[1])
			_next_harvest_allowed_ms = now_ms + int(dur_sec * 1000.0)
			_harvest_schedule_auto_chain(harvest_target, dur_sec)
			return
		if not _harvest_skill_met(harvest_target):
			show_gameplay_message("You need the right tool and level to harvest this.")
		return
	if _try_pickup_item_from_world(collider):
		return
	var interactable: Object = _resolve_interactable_target(collider)
	if interactable == null or not interactable.has_method("interact"):
		return
	interactable.interact(self)


func _try_pickup_item_from_world(collider: Object) -> bool:
	var world_item := _resolve_world_item_target(collider)
	if world_item.is_empty():
		return false
	var item_id := str(world_item["item_id"])
	var count: int = maxi(1, int(world_item.get("count", 1)))
	var item_node := world_item["node"] as Node
	if item_node == null:
		return false
	if not ItemCatalog.has_method("get_item"):
		return false
	var item: ItemData = ItemCatalog.get_item(item_id)
	if item == null:
		return false
	var left: int = InventoryService.add_item(item_id, count)
	if left > 0:
		show_gameplay_message("Inventory full.")
		return false
	var dname := InventoryService.get_item_display_name(item_id)
	if count > 1:
		show_gameplay_message("Picked up %d × %s." % [count, dname])
	else:
		show_gameplay_message("Picked up %s." % dname)
	item_node.queue_free()
	return true


func _resolve_world_item_id_from_collider(collider: Object) -> String:
	var world_item := _resolve_world_item_target(collider)
	if world_item.is_empty():
		return ""
	return str(world_item.get("item_id", ""))


func _resolve_world_item_target(collider: Object) -> Dictionary:
	var cur: Node = collider as Node
	var hops: int = 0
	while cur != null and hops < 8:
		var pick := _parse_world_pickup_from_node(cur)
		var iid := str(pick.get("item_id", ""))
		if not iid.is_empty():
			return {
				"item_id": iid,
				"count": maxi(1, int(pick.get("count", 1))),
				"node": cur,
			}
		cur = cur.get_parent()
		hops += 1
	return {}


func _parse_world_pickup_from_node(node: Node) -> Dictionary:
	if node == null:
		return {}
	if node.has_meta("item_id"):
		var meta_item := str(node.get_meta("item_id", ""))
		if not meta_item.is_empty():
			var meta_count: int = maxi(1, int(node.get_meta("quantity", 1)))
			return {"item_id": GameState.normalize_item_id(meta_item), "count": meta_count}
	if "item_id" in node:
		var explicit := str(node.get("item_id"))
		if not explicit.is_empty():
			var count: int = 1
			if "quantity" in node:
				count = maxi(1, int(node.get("quantity")))
			return {"item_id": GameState.normalize_item_id(explicit), "count": count}
	if "resource_type" in node:
		var resource_id := str(node.get("resource_type"))
		if not resource_id.is_empty():
			var qty: int = 1
			if "quantity" in node:
				qty = maxi(1, int(node.get("quantity")))
			return {"item_id": GameState.normalize_item_id(resource_id), "count": qty}
	return {}


func _extract_world_item_id(node: Node) -> String:
	var p := _parse_world_pickup_from_node(node)
	return str(p.get("item_id", ""))


func _night_speed_factor() -> float:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return 1.0
	var tod: float = float(gs.time_of_day) if "time_of_day" in gs else 0.5
	var is_night: bool = tod < 0.23 or tod > 0.78
	if not is_night:
		return 1.0
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	var warm_until: int = int(gs.warmth_until_unix_ms) if "warmth_until_unix_ms" in gs else 0
	if now_ms < warm_until:
		var warm_bonus: float = float(gs.campfire_night_run_bonus) if "campfire_night_run_bonus" in gs else 0.2
		return clampf(1.0 + warm_bonus, 1.0, 1.6)
	var night_penalty: float = float(gs.campfire_night_penalty) if "campfire_night_penalty" in gs else 0.15
	return clampf(1.0 - night_penalty, 0.55, 1.0)


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
	if _harvest_target_exhausted_after_hit(c):
		_abort_harvest_tool_animation()
		return
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
	if _harvest_target_exhausted_after_hit(c):
		_abort_harvest_tool_animation()
		return


func _resolve_day_night_controller() -> void:
	if day_night_controller_path != NodePath(""):
		var n: Node = get_node_or_null(day_night_controller_path)
		if n != null and n.has_method(&"set_underwater_fog_override"):
			_day_night = n
			return
	var scene := get_tree().current_scene
	if scene != null:
		var by_path: Node = scene.get_node_or_null(NodePath("DayNightCycle"))
		if by_path != null and by_path.has_method(&"set_underwater_fog_override"):
			_day_night = by_path
			return
	var g: Node = get_tree().get_first_node_in_group("day_night_cycle")
	if g != null and g.has_method(&"set_underwater_fog_override"):
		_day_night = g


func _update_underwater_fog(water_level_y: float) -> void:
	if _day_night == null:
		_resolve_day_night_controller()
	if _day_night == null:
		return
	var cam_y: float = camera_3d.global_position.y
	var cam_submerged: bool = water_level_y > -1e6 and cam_y < water_level_y - 0.02
	if cam_submerged:
		var d: float = clampf(water_level_y - cam_y, 0.0, _UNDERWATER_FOG_DEPTH_MAX)
		var t: float = clampf(d / _UNDERWATER_FOG_DEPTH_MAX, 0.0, 1.0)
		_day_night.call("set_underwater_fog_override", true, t)
	else:
		_day_night.call("set_underwater_fog_override", false, 0.0)
