extends CharacterBody3D
class_name EnemyBase

const _EnemyVariantData = preload("res://data/schemas/enemy_variant_data.gd")
const _EnemyDropProfile = preload("res://data/schemas/enemy_drop_profile.gd")
const _EnemyBehaviorProfile = preload("res://data/schemas/enemy_behavior_profile.gd")
const _EnemyDropEntry = preload("res://data/schemas/enemy_drop_entry.gd")
const _ARROW_PROJECTILE_SCENE = preload("res://entities/projectiles/arrow_projectile.tscn")

enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	RETURN_TO_LEASH,
}

enum RangedAttackStage {
	NONE,
	DRAW,
	RECOVER,
}

@export var variant_data: _EnemyVariantData

@export var max_health: float = 30.0
@export var move_speed: float = 2.2
@export var attack_damage: float = 6.0
@export var aggro_range: float = 12.0
@export var leash_range: float = 24.0
@export var attack_range: float = 1.8
@export var preferred_range: float = 1.2
@export var attack_cooldown: float = 1.4
@export var patrol_radius: float = 6.0
@export var return_stop_distance: float = 1.4
@export var uses_ranged_attacks: bool = false
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 20.0
@export var projectile_lifetime: float = 6.0
@export var ranged_draw_time_sec: float = 0.38
@export var ranged_recover_time_sec: float = 0.34
@export var death_remove_delay_sec: float = 1.2

@export var drop_profile: _EnemyDropProfile
@export var xp_value: float = 8.0

@export var show_health_bar: bool = true
@export var health_bar_height: float = 1.35
@export var health_bar_width: float = 0.95
@export var health_bar_thickness: float = 0.08
@export var health_bar_visible_seconds_after_hit: float = 3.5

@onready var visual_root: Node3D = $VisualRoot
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _animation_player: AnimationPlayer
var _spawn_position: Vector3 = Vector3.ZERO
var _health: float = 0.0
var _state: State = State.IDLE
var _phase_timeout: float = 0.0
var _attack_cooldown_left: float = 0.0
var _dead: bool = false
var _walk_target: Vector3 = Vector3.ZERO
var _target_player: Node3D = null
var _ranged_attack_stage: RangedAttackStage = RangedAttackStage.NONE
var _ranged_stage_left_sec: float = 0.0
var _ranged_attack_target_ref: WeakRef = null

var _health_bar_root: Node3D
var _health_bar_fill: MeshInstance3D
var _health_bar_visible_until_ms: int = 0

func _ready() -> void:
	add_to_group("creature")
	_apply_variant_data()
	_animation_player = _resolve_animation_player()
	_spawn_position = global_position
	_health = maxf(1.0, max_health)
	_setup_health_bar()
	_update_health_bar_visual()
	_set_idle_phase()


func _apply_variant_data() -> void:
	if variant_data == null:
		return
	max_health = variant_data.max_health
	move_speed = variant_data.move_speed
	attack_damage = variant_data.attack_damage
	xp_value = variant_data.xp_value
	projectile_scene = variant_data.projectile_scene
	projectile_speed = variant_data.projectile_speed
	projectile_lifetime = variant_data.projectile_lifetime
	drop_profile = variant_data.drop_profile
	if variant_data.behavior_profile != null:
		var profile: _EnemyBehaviorProfile = variant_data.behavior_profile
		aggro_range = profile.aggro_range
		leash_range = profile.leash_range
		attack_range = profile.attack_range
		preferred_range = profile.preferred_range
		attack_cooldown = profile.attack_cooldown
		patrol_radius = profile.patrol_radius
		return_stop_distance = profile.return_stop_distance
		uses_ranged_attacks = profile.uses_ranged_attacks
	if variant_data.visual_scene != null and visual_root != null:
		for c in visual_root.get_children():
			c.queue_free()
		var visual := variant_data.visual_scene.instantiate()
		visual_root.add_child(visual)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	_update_ranged_attack_tick(delta)
	_target_player = _find_player_target()
	_update_state_machine(delta)
	_update_movement(delta)
	_update_health_bar_visibility()


func _update_state_machine(delta: float) -> void:
	var to_spawn := _spawn_position - global_position
	to_spawn.y = 0.0
	var dist_to_spawn := to_spawn.length()
	if dist_to_spawn > leash_range and _state != State.RETURN_TO_LEASH:
		_state = State.RETURN_TO_LEASH

	match _state:
		State.IDLE:
			_phase_timeout -= delta
			if _can_aggro_target():
				_state = State.CHASE
				return
			if _phase_timeout <= 0.0:
				_state = State.PATROL
				_walk_target = _pick_patrol_target()
				_phase_timeout = randf_range(1.5, 3.6)
		State.PATROL:
			if _can_aggro_target():
				_state = State.CHASE
				return
			if _is_near_point(_walk_target, 0.8) or _phase_timeout <= 0.0:
				_set_idle_phase()
			else:
				_phase_timeout -= delta
		State.CHASE:
			if _target_player == null:
				_state = State.RETURN_TO_LEASH
				return
			var dist := _distance_to_target_player()
			if dist <= attack_range:
				_state = State.ATTACK
		State.ATTACK:
			if _target_player == null:
				_state = State.RETURN_TO_LEASH
				return
			var dist := _distance_to_target_player()
			if dist > attack_range * 1.15:
				_state = State.CHASE
				return
			_try_attack_player()
		State.RETURN_TO_LEASH:
			if dist_to_spawn <= return_stop_distance:
				global_position = Vector3(_spawn_position.x, global_position.y, _spawn_position.z)
				_set_idle_phase()


func _update_movement(delta: float) -> void:
	var desired_planar := Vector3.ZERO
	match _state:
		State.PATROL:
			desired_planar = _move_towards(_walk_target)
		State.CHASE:
			if _target_player != null:
				var chase_to := _target_player.global_position
				if uses_ranged_attacks:
					var dist := _distance_to_target_player()
					if dist <= preferred_range:
						chase_to = global_position - (_target_player.global_position - global_position).normalized() * 2.0
				desired_planar = _move_towards(chase_to)
		State.RETURN_TO_LEASH:
			desired_planar = _move_towards(_spawn_position)

	velocity.x = desired_planar.x
	velocity.z = desired_planar.z
	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_update_animation(desired_planar.length() > 0.05)


func _move_towards(world_point: Vector3) -> Vector3:
	var to_t := world_point - global_position
	to_t.y = 0.0
	if to_t.length_squared() < 1e-6:
		return Vector3.ZERO
	var dir := to_t.normalized()
	# Match player-facing locomotion convention so enemies don't backpedal.
	var target_yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 0.18)
	return dir * move_speed


func _update_animation(moving: bool) -> void:
	if _animation_player == null:
		return
	if _dead:
		_play_best_clip(["Death_A", "Death_B", "Death", "Die", "death", "die"])
		return
	if _state == State.ATTACK:
		_play_best_clip(_attack_animation_candidates())
		return
	if moving:
		_play_best_clip(["Walk", "Run", "Walking_B", "walk"])
	else:
		_play_best_clip(["Idle", "Idle_A", "idle"])


func _play_best_clip(candidates: Array[String]) -> void:
	if _animation_player == null:
		return
	for clip in candidates:
		var resolved := _resolve_clip_name(clip)
		if resolved.is_empty():
			continue
		if _animation_player.current_animation == resolved and _animation_player.is_playing():
			return
		_animation_player.play(resolved, 0.1)
		return


func _attack_animation_candidates() -> Array[String]:
	if uses_ranged_attacks:
		if _ranged_attack_stage == RangedAttackStage.DRAW:
			return [
				"Ranged_Bow_Draw",
				"Ranged_Bow_Draw_Up",
				"Ranged_Bow_Aiming_Idle",
				"Ranged_Bow_Idle",
				"Ranged_Magic_Raise",
				"Ranged_Magic_Spellcasting",
			]
		if _ranged_attack_stage == RangedAttackStage.RECOVER:
			return [
				"Ranged_Bow_Release",
				"Ranged_Bow_Release_Up",
				"Ranged_Bow_Aiming_Idle",
				"Ranged_Bow_Idle",
				"Ranged_Magic_Shoot",
				"Ranged_Magic_Spellcasting",
			]
		# While waiting for cooldown, hold ranged-ready stance only (never melee swings).
		return [
			"Ranged_Bow_Aiming_Idle",
			"Ranged_Bow_Idle",
			"Ranged_Magic_Spellcasting",
			"Ranged_Magic_Raise",
			"Idle",
			"Idle_A",
		]

	return [
		"Attack",
		"Melee_1H_Attack_Chop",
		"Melee_1H_Attack_Slice_Diagonal",
		"Melee_Attack_1H",
		"Attack_01",
		"attack",
	]


func _resolve_animation_player() -> AnimationPlayer:
	if visual_root == null:
		return null
	return _find_animation_player_deep(visual_root)


func _find_animation_player_deep(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var nested := _find_animation_player_deep(c)
		if nested != null:
			return nested
	return null


func _resolve_clip_name(preferred: String) -> String:
	if _animation_player == null:
		return ""
	var candidates: Array[String] = [
		preferred,
		"Enemy/%s" % preferred,
		"Base/%s" % preferred,
	]
	for c in candidates:
		if _animation_player.has_animation(StringName(c)):
			return c
	return ""


func _can_aggro_target() -> bool:
	if _target_player == null:
		return false
	return _distance_to_target_player() <= aggro_range


func _find_player_target() -> Node3D:
	var candidates := get_tree().get_nodes_in_group("player")
	for n in candidates:
		if n is Node3D:
			return n as Node3D
	return null


func _distance_to_target_player() -> float:
	if _target_player == null:
		return INF
	return global_position.distance_to(_target_player.global_position)


func _try_attack_player() -> void:
	if _target_player == null or _attack_cooldown_left > 0.0:
		return
	if uses_ranged_attacks:
		if _ranged_attack_stage == RangedAttackStage.NONE:
			_ranged_attack_stage = RangedAttackStage.DRAW
			_ranged_stage_left_sec = maxf(0.05, ranged_draw_time_sec)
			_ranged_attack_target_ref = weakref(_target_player)
			_play_best_clip(
				[
					"Ranged_Bow_Draw",
					"Ranged_Bow_Draw_Up",
					"Ranged_Bow_Aiming_Idle",
					"Ranged_Bow_Idle",
				]
			)
	else:
		if _target_player.has_method("apply_damage"):
			_target_player.call("apply_damage", attack_damage)
		_attack_cooldown_left = attack_cooldown


func _update_ranged_attack_tick(delta: float) -> void:
	if not uses_ranged_attacks or _ranged_attack_stage == RangedAttackStage.NONE:
		return
	if _dead:
		_ranged_attack_stage = RangedAttackStage.NONE
		_ranged_stage_left_sec = 0.0
		_ranged_attack_target_ref = null
		return
	_ranged_stage_left_sec = maxf(0.0, _ranged_stage_left_sec - delta)
	if _ranged_attack_stage == RangedAttackStage.DRAW and _ranged_stage_left_sec <= 0.0:
		var target: Node3D = _resolve_ranged_attack_target()
		if target != null:
			_fire_projectile_towards(target)
			_play_best_clip(
				[
					"Ranged_Bow_Release",
					"Ranged_Bow_Release_Up",
					"Ranged_Bow_Aiming_Idle",
				]
			)
			_attack_cooldown_left = attack_cooldown
			_ranged_attack_stage = RangedAttackStage.RECOVER
			_ranged_stage_left_sec = maxf(0.05, ranged_recover_time_sec)
		else:
			_ranged_attack_stage = RangedAttackStage.NONE
			_ranged_stage_left_sec = 0.0
			_ranged_attack_target_ref = null
	elif _ranged_attack_stage == RangedAttackStage.RECOVER and _ranged_stage_left_sec <= 0.0:
		_ranged_attack_stage = RangedAttackStage.NONE
		_ranged_attack_target_ref = null


func _resolve_ranged_attack_target() -> Node3D:
	var ref_target: Object = _ranged_attack_target_ref.get_ref() if _ranged_attack_target_ref != null else null
	if ref_target is Node3D and is_instance_valid(ref_target):
		return ref_target as Node3D
	if _target_player != null and is_instance_valid(_target_player):
		return _target_player
	return null


func _fire_projectile_towards(target: Node3D) -> void:
	var scene: PackedScene = projectile_scene if projectile_scene != null else _ARROW_PROJECTILE_SCENE
	if scene == null:
		return
	var inst := scene.instantiate()
	if inst == null:
		return
	var parent_node := get_parent()
	if parent_node == null:
		return
	parent_node.add_child(inst)
	if inst.has_method("fire"):
		var origin := global_position + Vector3(0.0, 1.3, 0.0)
		var direction := (target.global_position + Vector3(0.0, 1.0, 0.0) - origin).normalized()
		inst.call(
			"fire",
			self,
			attack_damage,
			origin,
			direction,
			projectile_speed,
			7,
			0.0,
			projectile_lifetime,
			[get_rid()]
		)


func _set_idle_phase() -> void:
	_state = State.IDLE
	_phase_timeout = randf_range(0.9, 2.4)
	_walk_target = global_position


func _pick_patrol_target() -> Vector3:
	return _spawn_position + Vector3(
		randf_range(-patrol_radius, patrol_radius),
		0.0,
		randf_range(-patrol_radius, patrol_radius)
	)


func _is_near_point(world_point: Vector3, threshold: float) -> bool:
	var d := world_point - global_position
	d.y = 0.0
	return d.length() <= threshold


func can_receive_hit() -> bool:
	return not _dead


func receive_hit(damage: float, _source: Node = null) -> bool:
	if _dead:
		return false
	var dealt := maxf(0.0, damage)
	if dealt <= 0.0:
		return false
	_health = maxf(0.0, _health - dealt)
	_show_health_bar_temporarily()
	_update_health_bar_visual()
	if _health <= 0.0:
		_die()
	else:
		_state = State.CHASE
	return true


func _die() -> void:
	if _dead:
		return
	_dead = true
	_ranged_attack_stage = RangedAttackStage.NONE
	_ranged_stage_left_sec = 0.0
	_ranged_attack_target_ref = null
	collision_layer = 0
	collision_mask = 0
	_spawn_drops()
	_play_best_clip(["Death_A", "Death_B", "Death", "Die", "death", "die"])
	get_tree().create_timer(maxf(1.0, death_remove_delay_sec)).timeout.connect(func() -> void:
		queue_free()
	)


func _spawn_drops() -> void:
	if drop_profile == null:
		return
	var inv: Node = get_node_or_null("/root/InventoryService")
	if inv == null or not inv.has_method("get_pickup_scene_for_item"):
		return
	var parent_node := get_parent()
	if parent_node == null:
		return
	for e in drop_profile.entries:
		var entry := e as _EnemyDropEntry
		if entry == null or entry.item_id.is_empty():
			continue
		if randf() > clampf(entry.chance, 0.0, 1.0):
			continue
		var scene: PackedScene = inv.call("get_pickup_scene_for_item", entry.item_id)
		if scene == null:
			continue
		var n := scene.instantiate()
		if n == null:
			continue
		parent_node.add_child(n)
		if n is Node3D:
			(n as Node3D).global_position = global_position + Vector3(
				randf_range(-0.5, 0.5),
				0.2,
				randf_range(-0.5, 0.5)
			)
		var drop_count := randi_range(mini(entry.min_count, entry.max_count), maxi(entry.min_count, entry.max_count))
		if n.has_method("set_resource_type"):
			n.call("set_resource_type", entry.item_id)
		if n.has_method("set_quantity"):
			n.call("set_quantity", drop_count)


func _setup_health_bar() -> void:
	if not show_health_bar:
		return
	_health_bar_root = Node3D.new()
	_health_bar_root.name = "HealthBarRoot"
	_health_bar_root.position = Vector3(0.0, health_bar_height, 0.0)
	add_child(_health_bar_root)

	var bg := MeshInstance3D.new()
	var bg_quad := QuadMesh.new()
	bg_quad.size = Vector2(maxf(0.1, health_bar_width), maxf(0.02, health_bar_thickness))
	bg.mesh = bg_quad
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.08, 0.08, 0.08, 1.0)
	bg_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bg.material_override = bg_mat
	_health_bar_root.add_child(bg)

	_health_bar_fill = MeshInstance3D.new()
	var fill_quad := QuadMesh.new()
	fill_quad.size = Vector2(maxf(0.1, health_bar_width), maxf(0.02, health_bar_thickness) * 0.8)
	_health_bar_fill.mesh = fill_quad
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.9, 0.1, 0.1, 1.0)
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_health_bar_fill.material_override = fill_mat
	_health_bar_fill.position = Vector3(0.0, 0.0, 0.01)
	_health_bar_root.add_child(_health_bar_fill)
	_health_bar_root.visible = false


func _update_health_bar_visual() -> void:
	if _health_bar_fill == null:
		return
	var ratio := clampf(_health / maxf(1.0, max_health), 0.0, 1.0)
	_health_bar_fill.visible = ratio > 0.0
	_health_bar_fill.scale.x = maxf(0.001, ratio)
	_health_bar_fill.position.x = -(1.0 - ratio) * health_bar_width * 0.5


func _show_health_bar_temporarily() -> void:
	if _health_bar_root == null:
		return
	_health_bar_visible_until_ms = Time.get_ticks_msec() + int(maxf(0.1, health_bar_visible_seconds_after_hit) * 1000.0)
	_health_bar_root.visible = true


func _update_health_bar_visibility() -> void:
	if _health_bar_root == null:
		return
	if _dead or _health <= 0.0:
		_health_bar_root.visible = false
		return
	_health_bar_root.visible = Time.get_ticks_msec() <= _health_bar_visible_until_ms
	if _health_bar_root.visible:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			_health_bar_root.look_at(cam.global_position, Vector3.UP, true)
