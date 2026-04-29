extends CharacterBody3D

const _GameState = preload("res://autoload/game_state.gd")
const _BaseCharacter = preload("res://entities/characters/base_character/base_character.gd")
const _WaterSurfaceQueries = preload("res://world/water/water_surface_queries.gd")
const _WeaponData = preload("res://data/schemas/weapon_data.gd")
const _WeaponStats = preload("res://data/schemas/weapon_stats.gd")
const _AnimalChickenScene = preload("res://entities/characters/animals/chicken.tscn")
const _AnimalRabbitScene = preload("res://entities/characters/animals/rabbit.tscn")
const _AnimalRoosterScene = preload("res://entities/characters/animals/rooster.tscn")
const _AnimalChickScene = preload("res://entities/characters/animals/chick.tscn")

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
@export var chop_animation_duration_sec: float = 1.3
@export var chop_impact_delays_sec: PackedFloat32Array = PackedFloat32Array([0.5])
@export var mine_animation_duration_sec: float = 1.7
@export var mine_impact_delays_sec: PackedFloat32Array = PackedFloat32Array([0.3])
@export var harvest_interact_start_distance: float = 1.95
@export var harvest_interact_start_distance_chop: float = 2.05
@export var harvest_interact_start_distance_mine: float = 1.65
@export var harvest_interact_face_dot_min: float = 0.62
@export var harvest_interact_face_dot_min_chop: float = 0.55
@export var harvest_interact_face_dot_min_mine: float = 0.72
@export var creature_attack_damage: float = 8.0
@export var unarmed_melee_damage: float = 1.0
@export var tool_melee_damage: float = 2.0
@export var creature_attack_cooldown_sec: float = 0.7
## Seconds from melee swing start until each creature hit registers. Empty = immediate on swing start after animation confirms.
@export var melee_creature_impact_delays_sec: PackedFloat32Array = PackedFloat32Array([0.42])
@export var melee_reach_distance: float = 2.15
@export var melee_hit_radius: float = 0.65
@export var melee_forward_dot_min: float = 0.1
@export var shield_block_damage_multiplier: float = 0.15
@export var shield_block_move_multiplier: float = 0.55
@export var shield_block_turn_multiplier: float = 0.6

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
var _pending_chop_hit: bool = false
var _pending_chop_ref: WeakRef
var _pending_mine_ref: WeakRef
var _harvest_timer_generation: int = 0
var _creature_impact_generation: int = 0
var _pending_creature_ref: WeakRef

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

func apply_damage(amount: float) -> void:
	var amt: float = absf(amount)
	if base_character != null and base_character.has_method("is_blocking") and base_character.is_blocking():
		amt *= shield_block_damage_multiplier
	health = maxf(health - amt, 0.0)


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
	if spring_arm != null:
		spring_arm.spring_length = clampf(spring_arm.spring_length, zoom_min_distance, zoom_max_distance)
		_zoom_target_distance = spring_arm.spring_length
	_update_reticle_position()
	_update_reticle_icon()
	_resolve_day_night_controller()
	_apply_from_gamestate()
	_setup_tutorial_animals_if_needed()
	if _input_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if interaction_prompt:
		interaction_prompt.visible = false
	var inv: Node = get_node_or_null("/root/InventoryService")
	if inv != null and inv.has_signal("inventory_changed"):
		inv.inventory_changed.connect(_on_inventory_changed)
	_refresh_tacklebox_back_visual()
	_sync_equipped_hand_visuals()


func _setup_tutorial_animals_if_needed() -> void:
	var scene := get_tree().current_scene
	if scene == null or not _scene_is_tutorial_isle(scene):
		return
	if scene.get_node_or_null("AnimalsGameplay") != null:
		return
	var wildlife := scene.get_node_or_null("Wildlife") as Node3D
	if wildlife != null and wildlife.get_child_count() > 0:
		return
	var src_root := scene.get_node_or_null("Animals") as Node3D
	if src_root == null:
		return
	var spawned := Node3D.new()
	spawned.name = "AnimalsGameplay"
	spawned.transform = src_root.transform
	scene.add_child(spawned)
	var scene_by_name := {
		"Chicken": _AnimalChickenScene,
		"Rabbit": _AnimalRabbitScene,
		"Rooster": _AnimalRoosterScene,
		"Chick": _AnimalChickScene,
	}
	var spawned_count := 0
	for k in scene_by_name.keys():
		var src := src_root.get_node_or_null(String(k)) as Node3D
		if src == null:
			continue
		var animal_scene: PackedScene = scene_by_name[k]
		if animal_scene == null:
			continue
		var inst := animal_scene.instantiate()
		spawned.add_child(inst)
		if inst is Node3D:
			(inst as Node3D).transform = src.transform
		spawned_count += 1
	if spawned_count > 0:
		src_root.visible = false
	else:
		spawned.queue_free()


func _scene_is_tutorial_isle(scene: Node) -> bool:
	if String(scene.name) == "TutorialIsle":
		return true
	var p := String(scene.scene_file_path)
	return p.ends_with("tutorial_isle/tutorial_isle.tscn") or p.ends_with("tutorial_isle.tscn")


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
	if _harvest_auto_active and raw_move.length_squared() > 0.0001:
		_stop_harvest_auto()
	if _harvest_interact_pending and raw_move.length_squared() > 0.0001:
		_clear_harvest_interact_approach()
	var input_vec := raw_move
	var approach_input := _harvest_interact_move_input()
	if approach_input.length_squared() > 0.0001:
		input_vec = approach_input
	if anim_busy:
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
	var speed_factor: float = _night_speed_factor()
	var speed := move_speed * speed_factor * (run_multiplier if running else 1.0)
	if actively_blocking:
		speed *= shield_block_move_multiplier

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

	_update_interaction_ray()
	if spring_arm != null:
		spring_arm.spring_length = lerpf(spring_arm.spring_length, _zoom_target_distance, clampf(zoom_lerp_speed * delta, 0.0, 1.0))
	_update_reticle_position()
	_update_reticle_icon()
	_update_interaction_prompt()
	_sync_equipped_hand_visuals()

	if not anim_busy:
		if Input.is_action_just_pressed("tool_axe"):
			_use_hotbar_slot(0)
		if Input.is_action_just_pressed("tool_pickaxe"):
			_use_hotbar_slot(1)
		if Input.is_action_just_pressed("tool_hands"):
			_use_hotbar_slot(2)
		if Input.is_action_just_pressed("tool_fishing"):
			_use_hotbar_slot(3)

	_attack_input_tick()

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var moving := horizontal_speed > 0.15
	if base_character.has_method("set_locomotion_state"):
		base_character.set_locomotion_state(moving, running, is_on_floor())


func _attack_input_tick() -> void:
	if _gameplay_input_blocked():
		if _equipped_weapon_is_bow() and base_character != null and base_character.has_method("try_cancel_bow_draw"):
			base_character.try_cancel_bow_draw()
		return
	if _pending_chop_hit:
		return
	var now_ms: int = Time.get_ticks_msec()

	if _equipped_weapon_is_bow():
		var aiming_bow: bool = Input.is_action_pressed("block")
		if not aiming_bow:
			if base_character != null and base_character.has_method("try_cancel_bow_draw"):
				base_character.try_cancel_bow_draw()
			return
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
	if now_ms < _next_harvest_allowed_ms:
		return

	if Input.is_action_just_pressed("attack"):
		if _try_creature_melee_hit():
			_next_harvest_allowed_ms = now_ms + int(_creature_attack_interval_sec() * 1000.0)
			return
		if _try_play_attack_air_whiff():
			_next_harvest_allowed_ms = now_ms + int(_creature_attack_interval_sec() * 1000.0)


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
		main_id = _normalize_item_id(str(m.get("id", "")))
		m["id"] = main_id
		GameState.equipment["main_hand"] = m
	var o: Variant = GameState.equipment.get("off_hand", null)
	if o != null:
		off_id = _normalize_item_id(str(o.get("id", "")))
		o["id"] = off_id
		GameState.equipment["off_hand"] = o
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
		back_id = _normalize_item_id(str(b.get("id", "")))
		b["id"] = back_id
		GameState.equipment["back"] = b
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


func _normalize_item_id(id: String) -> String:
	match id:
		"wood":
			return "logs"
		"oak_logs":
			return "logs_oak"
		"torch":
			return "tool_torch"
		"hammer":
			return "tool_hammer"
		"chisel":
			return "tool_chisel"
		_:
			return id


func _off_hand_has_shield_equipped() -> bool:
	var o: Variant = GameState.equipment.get("off_hand", null)
	if o == null:
		return false
	var id := _normalize_item_id(str(o.get("id", "")))
	return id.begins_with("shield_")


func _equipped_main_hand_id_str() -> String:
	var m: Variant = GameState.equipment.get("main_hand", null)
	if m == null:
		return ""
	return _normalize_item_id(str(m.get("id", "")))


func _main_hand_weapon_family() -> _WeaponStats.WeaponFamily:
	var id := _equipped_main_hand_id_str()
	if id.is_empty():
		return _WeaponStats.WeaponFamily.SWORD_1H
	var it: ItemData = ItemCatalog.get_item(id)
	if it == null:
		return _WeaponStats.WeaponFamily.SWORD_1H
	if it is _WeaponData:
		var wd: WeaponData = it as WeaponData
		if wd.weapon_stats != null:
			return wd.weapon_stats.weapon_family
	for tag in it.tags:
		if str(tag) == "bow":
			return _WeaponStats.WeaponFamily.BOW
	return _WeaponStats.WeaponFamily.SWORD_1H


func _equipped_weapon_is_bow() -> bool:
	return _main_hand_weapon_family() == _WeaponStats.WeaponFamily.BOW


func _creature_damage_amount() -> float:
	var id := _equipped_main_hand_id_str()
	if id.is_empty():
		return unarmed_melee_damage
	if id in ["hatchet_basic", "hatchet_bronze", "pickaxe_basic", "pickaxe_bronze"]:
		return tool_melee_damage
	var it: ItemData = ItemCatalog.get_item(id)
	if it is _WeaponData:
		var wd: WeaponData = it as WeaponData
		if wd.weapon_stats != null:
			return wd.weapon_stats.base_damage
	return creature_attack_damage


func _creature_attack_interval_sec() -> float:
	var id := _equipped_main_hand_id_str()
	var it: ItemData = ItemCatalog.get_item(id)
	if it is _WeaponData:
		var wd: WeaponData = it as WeaponData
		if wd.weapon_stats != null:
			return wd.weapon_stats.attack_interval_sec
	return creature_attack_cooldown_sec


func _try_creature_melee_hit() -> bool:
	var collider: Object = _find_creature_melee_target()
	if not _is_creature_candidate(collider):
		return false
	var family := _main_hand_weapon_family()
	var played := false
	match family:
		_WeaponStats.WeaponFamily.STAFF:
			if base_character.has_method("try_play_action_for_harvest"):
				played = base_character.try_play_action_for_harvest("interact")
		_WeaponStats.WeaponFamily.BOW:
			return false
		_:
			if base_character.has_method("try_play_melee_attack_1h"):
				played = base_character.try_play_melee_attack_1h()
	if not played:
		return false

	_creature_impact_generation += 1
	var seq: int = _creature_impact_generation
	_pending_creature_ref = weakref(collider)

	if melee_creature_impact_delays_sec.is_empty():
		_apply_creature_melee_damage_at_impact(seq)
		return true

	for i in range(melee_creature_impact_delays_sec.size()):
		var d: float = melee_creature_impact_delays_sec[i]
		var tw := get_tree().create_timer(maxf(0.0, d))
		tw.timeout.connect(_on_creature_melee_impact_timeout.bind(seq))
	return true


func _apply_creature_melee_damage_at_impact(seq: int) -> void:
	if seq != _creature_impact_generation:
		return
	var c: Object = _pending_creature_ref.get_ref() if _pending_creature_ref != null else null
	if c == null or not is_instance_valid(c) or not _creature_target_still_valid_for_hit(c) or not _is_creature_candidate(c):
		c = _find_creature_melee_target()
		if c == null or not _is_creature_candidate(c):
			return
	var dmg := _creature_damage_amount()
	c.call("receive_hit", dmg, self)


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
	var family := _main_hand_weapon_family()
	match family:
		_WeaponStats.WeaponFamily.BOW:
			return false
		_WeaponStats.WeaponFamily.STAFF:
			if base_character.has_method("try_play_action_for_harvest"):
				return base_character.try_play_action_for_harvest("interact")
			return false
		_:
			if base_character.has_method("try_play_melee_attack_1h"):
				return base_character.try_play_melee_attack_1h()
			return false


func _equipped_back_has_quiver() -> bool:
	var b: Variant = GameState.equipment.get("back", null)
	if b == null:
		return false
	var id := _normalize_item_id(str(b.get("id", "")))
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
	if item_id == "tool_torch":
		equip_slot = "off_hand"
	if item_id.begins_with("quiver_") or item_id.begins_with("backpack_"):
		equip_slot = "back"
	GameState.equipment[equip_slot] = {"id": item_id, "count": 1}
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
	var collider: Object = _get_interaction_collider()
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
		_stop_harvest_auto()
		return
	if c.has_method("can_harvest") and not c.can_harvest():
		_stop_harvest_auto()
		return
	var move_check := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if move_check.length_squared() > 0.0001:
		_stop_harvest_auto()
		return
	if not _harvest_auto_target_still_valid(c):
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
	if not _harvest_auto_target_still_valid(c):
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
		return state.mining_level >= req
	if not _has_tool_in_inventory_or_equipped(["hatchet_basic", "hatchet_bronze"]):
		return false
	var req_wc := 0
	if collider.has_method("get_required_woodcutting_level"):
		req_wc = int(collider.get_required_woodcutting_level())
	if req_wc <= 0:
		return true
	return state.woodcutting_level >= req_wc


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
	var collider: Object = _get_interaction_collider()
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
	var collider: Object = _get_interaction_collider()
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
	var collider: Object = _get_interaction_collider()
	if collider == null:
		return
	var harvest_target: Object = _resolve_harvest_target(collider)
	if harvest_target != null:
		if not _harvest_interact_ready(harvest_target):
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
	if "item_id" in node:
		var explicit := str(node.get("item_id"))
		if not explicit.is_empty():
			var count: int = 1
			if "quantity" in node:
				count = maxi(1, int(node.get("quantity")))
			return {"item_id": explicit, "count": count}
	var raw_name := String(node.name).to_lower()
	var by_name := {
		"1h_sword_wooden": "sword_1h_wooden",
		"1h_katana_bronze": "sword_1h_bronze",
		"katana_1h_bronze": "sword_1h_bronze",
		"bow_short_common": "bow_short_common",
		"bow_long_common": "bow_long_common",
		"quiver_common": "quiver_common",
		"quiver_bronze": "quiver_bronze",
		"quiver_iron": "quiver_iron",
		"arrow_common": "ammo_arrow_common",
		"arrow_bronze": "ammo_arrow_bronze",
		"arrow_iron": "ammo_arrow_iron",
		"copper_bar": "ingot_copper",
		"iron_bar": "ingot_iron",
		"silver_bar": "ingot_silver",
		"gold_bar": "ingot_gold",
		"tin_bar": "ingot_tin",
		"copper_nuggets": "ore_copper",
		"iron_nuggets": "ore_iron",
		"silver_nuggets": "ore_silver",
		"gold_nuggets": "ore_gold",
		"tin_nuggets": "ore_tin",
	}
	if by_name.has(raw_name):
		return {"item_id": str(by_name[raw_name]), "count": 1}
	if raw_name.find("bronze") >= 0 and (raw_name.find("katana") >= 0 or raw_name.find("sword") >= 0):
		return {"item_id": "sword_1h_bronze", "count": 1}
	if raw_name.find("bow") >= 0:
		return {"item_id": "bow_short_common", "count": 1}
	if raw_name.find("quiver_iron") >= 0:
		return {"item_id": "quiver_iron", "count": 1}
	if raw_name.find("quiver_bronze") >= 0:
		return {"item_id": "quiver_bronze", "count": 1}
	if raw_name.find("quiver") >= 0:
		return {"item_id": "quiver_common", "count": 1}
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
