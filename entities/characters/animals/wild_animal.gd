extends CharacterBody3D
class_name WildAnimal

const _AnimalDropEntry = preload("res://entities/characters/animals/animal_drop_entry.gd")

const LOD_FULL := 0
const LOD_LOW := 1
const LOD_FROZEN := 2

@export var max_health: float = 20.0
@export var species_id: String = ""
@export var move_speed: float = 1.1
@export var turn_speed: float = 10.0
@export var roam_radius: float = 3.0
@export var idle_time_min: float = 1.2
@export var idle_time_max: float = 3.5
@export var walk_time_min: float = 1.5
@export var walk_time_max: float = 3.8
@export var attack_damage: float = 8.0
## Used when no death clip is resolved (fallback).
@export var death_remove_delay_sec: float = 0.5
## Extra time after the death animation finishes before the body is freed.
@export var death_cleanup_after_anim_sec: float = 0.5
@export var respawn_seconds: float = 0.0
@export var show_health_bar: bool = true
@export var health_bar_height: float = 1.15
@export var health_bar_width: float = 0.75
@export var health_bar_thickness: float = 0.07
@export var health_bar_visible_seconds_after_hit: float = 3.0

## Extra yaw (radians) after aligning facing to velocity. Uses atan2(-x,-z) so local −Z matches movement.
@export var facing_yaw_offset: float = 0.0

@export var idle_animation: StringName = &"Idle"
@export var walk_animation: StringName = &"Walk"
@export var hit_animation: StringName = &"Hit"
@export var death_animation: StringName = &"Death"
@export var flee_on_hit: bool = true
@export var flee_duration_sec: float = 2.0
@export var flee_speed_multiplier: float = 1.85
## Extra planar velocity impulse when hit (0 disables). Decays each physics frame.
@export var hit_receive_knockback_impulse: float = 0.85
@export var hit_knockback_decay_per_sec: float = 16.0
## Safety leash: keep wildlife near its spawn and recover from terrain falls.
@export var max_spawn_wander_multiplier: float = 3.0
@export var fall_reset_depth: float = 15.0

## Negative values move the mesh down so feet align with the ground when the FBX pivot sits high.
@export var visual_mesh_vertical_offset: float = 0.0
## Yaw offset (degrees) for imported meshes whose authored forward axis is not Godot's -Z.
@export var visual_mesh_yaw_offset_deg: float = 0.0

## Register with region `WildlifeLod`; tiers throttle AI + billboard work when far from anchor.
@export var use_simulation_lod: bool = true
## Fish / pond wildlife: planar roam only; Y locked to spawn with gentle bob (no gravity).
@export var aquatic: bool = false
@export var swim_bob_amplitude: float = 0.06
@export var swim_bob_speed: float = 1.8
## When LOD is frozen, land animals raycast down and set Y to hit + this (body origin above ground).
@export var terrain_snap_y_offset: float = 0.1
## Wider floor snap when LOD is low so move_and_slide keeps contact before is_on_floor flaps at range.
@export var lod_low_floor_snap_length: float = 0.5

@export var drops: Array[_AnimalDropEntry] = []

var animation_player: AnimationPlayer

var _idle_clip: String = ""
var _walk_clip: String = ""
var _hit_clip: String = ""
var _death_clip: String = ""

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _spawn_position: Vector3 = Vector3.ZERO
var _health: float = 0.0
var _dead: bool = false
var _is_walking: bool = false
var _phase_timeout: float = 0.0
var _walk_target: Vector3 = Vector3.ZERO
var _flee_timeout: float = 0.0
var _health_bar_root: Node3D
var _health_bar_bg: MeshInstance3D
var _health_bar_fill: MeshInstance3D
var _health_bar_visible_until_ms: int = 0
var _hit_knockback_planar: Vector3 = Vector3.ZERO
var _wind_push_time_left: float = 0.0
var _wind_push_dir: Vector3 = Vector3.ZERO
var _wind_push_speed: float = 0.0

var _lod_tier: int = LOD_FULL
var _swim_phase: float = 0.0
var _hb_billboard_tick: int = 0
var _saved_floor_snap_length: float = 0.18
var _far_culled: bool = false
var _saved_collision_layer: int = 0
var _saved_collision_mask: int = 0
var _geometry_fade_instances: Array[GeometryInstance3D] = []
var _geometry_fade_cache_dirty: bool = true


func _ready() -> void:
	add_to_group("creature")
	add_to_group("wildlife_lod")
	# Match Player CharacterBody: tutorial terrain + static meshes use physics layers 1–2.
	if not aquatic:
		collision_mask |= 3
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask
	_saved_floor_snap_length = floor_snap_length
	animation_player = _resolve_animation_player()
	if animation_player:
		_idle_clip = _resolve_clip_name(idle_animation)
		_walk_clip = _resolve_clip_name(walk_animation)
		_hit_clip = _resolve_clip_name(hit_animation)
		_death_clip = _resolve_clip_name(death_animation)
	_apply_visual_vertical_offset()
	_spawn_position = global_position
	_health = maxf(1.0, max_health)
	_setup_health_bar()
	_update_health_bar_visual()
	if drops.is_empty():
		drops = _default_drops_for_species(species_id)
	_set_idle_phase()


## Called every frame from the region `WildlifeLod` controller. Handles far cull + distance fade; simulation tier updates only when `apply_tiers` is true.
func apply_lod_frame(
	dist_sq: float,
	full_radius_squared: float,
	low_radius_squared: float,
	hide_radius_squared: float,
	fade_start_squared: float,
	apply_tiers: bool,
) -> void:
	if _dead:
		return

	if hide_radius_squared > 0.0 and dist_sq > hide_radius_squared:
		_set_far_culled(true)
		_reset_geometry_instance_transparency()
		return

	_set_far_culled(false)

	if fade_start_squared > 0.0 and hide_radius_squared > 0.0 and dist_sq >= fade_start_squared:
		var d := sqrt(dist_sq)
		var d0 := sqrt(fade_start_squared)
		var d1 := sqrt(hide_radius_squared)
		var span := maxf(1e-4, d1 - d0)
		var tr := clampf((d - d0) / span, 0.0, 1.0)
		_set_geometry_instance_transparency(tr)
	else:
		_reset_geometry_instance_transparency()

	if not apply_tiers:
		return

	if not use_simulation_lod:
		_set_lod_tier(LOD_FULL)
		return
	var full_r2 := maxf(0.01, full_radius_squared)
	var low_r2 := maxf(full_r2 + 0.01, low_radius_squared)
	if dist_sq <= full_r2:
		_set_lod_tier(LOD_FULL)
	elif dist_sq <= low_r2:
		_set_lod_tier(LOD_LOW)
	else:
		_set_lod_tier(LOD_FROZEN)


func _rebuild_geometry_fade_cache() -> void:
	_geometry_fade_instances.clear()
	_collect_geometry_instances_for_fade(self)
	_geometry_fade_cache_dirty = false


func _collect_geometry_instances_for_fade(n: Node) -> void:
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		if is_instance_valid(gi):
			_geometry_fade_instances.append(gi)
	for c in n.get_children():
		_collect_geometry_instances_for_fade(c)


func _set_geometry_instance_transparency(instance_transparency: float) -> void:
	if _geometry_fade_cache_dirty:
		_rebuild_geometry_fade_cache()
	var t := clampf(instance_transparency, 0.0, 1.0)
	for gi in _geometry_fade_instances:
		if is_instance_valid(gi):
			gi.transparency = t


func _reset_geometry_instance_transparency() -> void:
	_set_geometry_instance_transparency(0.0)


func _set_far_culled(active: bool) -> void:
	if _far_culled == active:
		return
	_far_culled = active
	if active:
		velocity = Vector3.ZERO
		_hit_knockback_planar = Vector3.ZERO
		_wind_push_time_left = 0.0
		collision_layer = 0
		collision_mask = 0
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
	else:
		process_mode = Node.PROCESS_MODE_INHERIT
		visible = true
		collision_layer = _saved_collision_layer
		collision_mask = _saved_collision_mask
		floor_snap_length = _saved_floor_snap_length


func _set_lod_tier(tier: int) -> void:
	if _lod_tier == tier:
		return
	_lod_tier = tier


func _ai_time_scale() -> float:
	if not use_simulation_lod:
		return 1.0
	match _lod_tier:
		LOD_FULL:
			return 1.0
		LOD_LOW:
			return 0.42
		_:
			return 0.0


func _move_speed_scale() -> float:
	if not use_simulation_lod:
		return 1.0
	match _lod_tier:
		LOD_FULL:
			return 1.0
		LOD_LOW:
			return 0.58
		_:
			return 0.0


func _aquatic_zero_vertical_velocity() -> void:
	if aquatic:
		velocity.y = 0.0


func _aquatic_apply_bob_after_move(delta: float) -> void:
	if not aquatic:
		return
	_swim_phase += delta * swim_bob_speed
	var bob := sin(_swim_phase) * swim_bob_amplitude
	global_position.y = _spawn_position.y + bob


func _query_ground_y_below() -> float:
	var w := get_world_3d()
	if w == null:
		return NAN
	var from := global_position + Vector3.UP * 5.0
	var to := global_position + Vector3.DOWN * 50.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_bodies = true
	q.collide_with_areas = false
	var mask := collision_mask
	if mask == 0:
		mask = 1
	q.collision_mask = mask
	q.exclude = [get_rid()]
	var r := w.direct_space_state.intersect_ray(q)
	if r.is_empty():
		return NAN
	return (r["position"] as Vector3).y


## Far frozen sim: do not integrate gravity (avoids tunneling + fall_reset thrash when is_on_floor is unreliable).
func _snap_frozen_land_to_ground() -> void:
	var gy := _query_ground_y_below()
	if is_nan(gy):
		global_position.y = _spawn_position.y
	else:
		global_position.y = gy + terrain_snap_y_offset
	velocity.y = 0.0


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _wind_push_time_left > 0.0:
		_wind_push_time_left -= delta
		var pv := _wind_push_dir * _wind_push_speed
		velocity.x = pv.x
		velocity.z = pv.z
		_aquatic_zero_vertical_velocity()
		if not aquatic:
			if not is_on_floor():
				velocity.y -= _gravity * delta
			else:
				velocity.y = 0.0
		move_and_slide()
		_aquatic_apply_bob_after_move(delta)
		_update_anim()
		_maybe_update_health_bar_billboard()
		_update_health_bar_visibility()
		return

	if use_simulation_lod and _lod_tier == LOD_FROZEN:
		_hit_knockback_planar *= exp(-hit_knockback_decay_per_sec * delta)
		velocity.x = _hit_knockback_planar.x
		velocity.z = _hit_knockback_planar.z
		if aquatic:
			_aquatic_zero_vertical_velocity()
			velocity.x = 0.0
			velocity.z = 0.0
			_hit_knockback_planar = Vector3.ZERO
			move_and_slide()
			_aquatic_apply_bob_after_move(delta)
		else:
			velocity.y = 0.0
			floor_snap_length = 0.0
			move_and_slide()
			_snap_frozen_land_to_ground()
		_play_clip(_idle_clip)
		_maybe_update_health_bar_billboard()
		_update_health_bar_visibility()
		return

	_enforce_spawn_leash()
	if use_simulation_lod and _lod_tier == LOD_LOW:
		floor_snap_length = lod_low_floor_snap_length
	else:
		floor_snap_length = _saved_floor_snap_length
	var ai_dt := delta * _ai_time_scale()
	_phase_timeout -= ai_dt
	_flee_timeout = maxf(0.0, _flee_timeout - delta)
	if _phase_timeout <= 0.0:
		if _is_walking:
			_set_idle_phase()
		else:
			_set_walk_phase()
	var planar_velocity := Vector3.ZERO
	var spd_scale := _move_speed_scale()
	if _is_walking and spd_scale > 1e-6:
		var to_target := _walk_target - global_position
		to_target.y = 0.0
		var len_sq := to_target.length_squared()
		if len_sq > 1e-8:
			var dir := to_target.normalized()
			var target_yaw := atan2(-dir.x, -dir.z) + facing_yaw_offset
			rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))
			if len_sq > 0.04:
				var forward := -global_transform.basis.z
				forward.y = 0.0
				var speed := move_speed * spd_scale * (flee_speed_multiplier if _flee_timeout > 0.0 else 1.0)
				if forward.length_squared() > 1e-8:
					planar_velocity = forward.normalized() * speed
				else:
					planar_velocity = dir * speed
	_hit_knockback_planar *= exp(-hit_knockback_decay_per_sec * delta)
	velocity.x = planar_velocity.x + _hit_knockback_planar.x
	velocity.z = planar_velocity.z + _hit_knockback_planar.z
	_aquatic_zero_vertical_velocity()
	if not aquatic:
		if not is_on_floor():
			velocity.y -= _gravity * delta
		else:
			velocity.y = 0.0
	move_and_slide()
	_aquatic_apply_bob_after_move(delta)
	_update_anim()
	_maybe_update_health_bar_billboard()
	_update_health_bar_visibility()


func _enforce_spawn_leash() -> void:
	if not aquatic:
		if global_position.y < _spawn_position.y - fall_reset_depth:
			_reset_to_spawn()
			return
	var max_dist := maxf(roam_radius, 1.0) * maxf(max_spawn_wander_multiplier, 1.5)
	if aquatic:
		var dx := global_position.x - _spawn_position.x
		var dz := global_position.z - _spawn_position.z
		if (dx * dx + dz * dz) <= max_dist * max_dist:
			return
	else:
		if global_position.distance_to(_spawn_position) <= max_dist:
			return
	# Too far away: force a return leg instead of letting wildlife drift out of play space.
	_flee_timeout = 0.0
	_is_walking = true
	_phase_timeout = randf_range(maxf(0.1, walk_time_min), maxf(walk_time_min, walk_time_max))
	_walk_target = _spawn_position + Vector3(randf_range(-roam_radius, roam_radius), 0.0, randf_range(-roam_radius, roam_radius))


func _reset_to_spawn() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO
	_flee_timeout = 0.0
	_set_idle_phase()


func apply_wind_push(source: Node3D, duration_sec: float, speed: float) -> void:
	if _dead:
		return
	if source == null or not is_instance_valid(source):
		return
	var away := global_position - source.global_position
	away.y = 0.0
	if away.length_squared() < 1e-6:
		away = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	_wind_push_dir = away.normalized()
	_wind_push_speed = maxf(0.1, speed)
	_wind_push_time_left = maxf(_wind_push_time_left, maxf(0.05, duration_sec))
	_hit_knockback_planar = Vector3.ZERO


func can_receive_hit() -> bool:
	return not _dead


func get_current_health() -> float:
	return _health


func get_max_health() -> float:
	return maxf(1.0, max_health)


func get_health_ratio() -> float:
	return clampf(_health / maxf(1.0, max_health), 0.0, 1.0)


func get_interaction_prompt(_player: Node) -> String:
	if _dead:
		return ""
	return "LMB: Attack"


func receive_hit(damage: float, source: Node = null) -> bool:
	if _dead:
		return false
	var dealt := maxf(0.0, damage)
	if dealt <= 0.0:
		return false
	_health -= dealt
	_show_health_bar_temporarily()
	_update_health_bar_visual()
	if hit_receive_knockback_impulse > 0.0 and source is Node3D:
		var away := global_position - (source as Node3D).global_position
		away.y = 0.0
		if away.length_squared() > 1e-6:
			_hit_knockback_planar += away.normalized() * hit_receive_knockback_impulse
	if _health <= 0.0:
		_die()
	else:
		_on_hit_react(source)
	return true


func _on_hit_react(source: Node) -> void:
	_play_clip(_hit_clip if not _hit_clip.is_empty() else _idle_clip)
	if not flee_on_hit:
		return
	_is_walking = true
	_phase_timeout = maxf(flee_duration_sec, 0.6)
	_flee_timeout = _phase_timeout
	var away := Vector3.ZERO
	if source is Node3D:
		away = global_position - (source as Node3D).global_position
		away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	away = away.normalized()
	_walk_target = global_position + away * maxf(2.0, roam_radius)


func _die() -> void:
	if _dead:
		return
	_dead = true
	if _health_bar_root != null:
		_health_bar_root.visible = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	_play_clip(_death_clip)
	_spawn_drops()
	_schedule_respawn()
	var remove_after := maxf(0.0, death_remove_delay_sec)
	if animation_player != null and not _death_clip.is_empty() and animation_player.has_animation(_death_clip):
		var anim: Animation = animation_player.get_animation(_death_clip)
		if anim != null:
			remove_after = maxf(remove_after, anim.length + death_cleanup_after_anim_sec)
	get_tree().create_timer(remove_after).timeout.connect(func() -> void:
		queue_free()
	)


func _spawn_drops() -> void:
	var inv: Node = get_node_or_null("/root/InventoryService")
	if inv == null or not inv.has_method("get_pickup_scene_for_item"):
		return
	var parent_node := get_parent()
	if parent_node == null:
		return
	for entry in drops:
		if entry == null:
			continue
		if entry.item_id.is_empty():
			continue
		if randf() > clampf(entry.chance, 0.0, 1.0):
			continue
		var scene: PackedScene = inv.get_pickup_scene_for_item(entry.item_id)
		if scene == null:
			continue
		var drop_count := randi_range(mini(entry.min_count, entry.max_count), maxi(entry.min_count, entry.max_count))
		var node := scene.instantiate()
		if node == null:
			continue
		parent_node.add_child(node)
		if node is Node3D:
			var o := Vector3(randf_range(-0.45, 0.45), 0.2, randf_range(-0.45, 0.45))
			var drop_node := node as Node3D
			drop_node.global_position = global_position + o
			if node.has_method("launch_from_harvest"):
				node.launch_from_harvest(global_position, get_rid())
			else:
				_snap_drop_to_ground(drop_node)
		if node.has_method("set_resource_type"):
			node.set_resource_type(entry.item_id)
		elif "resource_type" in node:
			node.resource_type = entry.item_id
		if node.has_method("set_quantity"):
			node.set_quantity(drop_count)
		elif "quantity" in node:
			node.quantity = drop_count


func _snap_drop_to_ground(drop_node: Node3D) -> void:
	var from := drop_node.global_position + Vector3.UP * 1.5
	var to := from + Vector3.DOWN * 10.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.size() > 0:
		drop_node.global_position.y = (hit["position"] as Vector3).y + 0.06


func _schedule_respawn() -> void:
	if respawn_seconds <= 0.0:
		return
	var parent_node := get_parent()
	if parent_node == null:
		return
	var p := scene_file_path
	if p.is_empty():
		return
	var scene: Resource = load(p)
	if not (scene is PackedScene):
		return
	var delay := respawn_seconds
	var spawn_xf := global_transform
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not is_instance_valid(parent_node):
			return
		var inst := (scene as PackedScene).instantiate()
		parent_node.add_child(inst)
		if inst is Node3D:
			(inst as Node3D).global_transform = spawn_xf
	)


func _set_idle_phase() -> void:
	_is_walking = false
	_phase_timeout = randf_range(maxf(0.1, idle_time_min), maxf(idle_time_min, idle_time_max))
	_walk_target = global_position


func _set_walk_phase() -> void:
	_is_walking = true
	_phase_timeout = randf_range(maxf(0.1, walk_time_min), maxf(walk_time_min, walk_time_max))
	_walk_target = _spawn_position + Vector3(randf_range(-roam_radius, roam_radius), 0.0, randf_range(-roam_radius, roam_radius))


func _update_anim() -> void:
	if _dead:
		return
	if _is_walking and velocity.length_squared() > 0.05:
		_play_clip(_walk_clip)
	else:
		_play_clip(_idle_clip)


func _play_clip(clip: String) -> void:
	if animation_player == null or clip.is_empty():
		return
	if not animation_player.has_animation(clip):
		return
	if animation_player.current_animation == clip and animation_player.is_playing():
		return
	animation_player.play(clip, 0.15)


func _resolve_animation_player() -> AnimationPlayer:
	var vr: Node = get_node_or_null("VisualRoot")
	if vr:
		var found := _find_animation_player_deep(vr)
		if found:
			return found
	var direct := get_node_or_null("VisualRoot/AnimationPlayer")
	return direct as AnimationPlayer


func _find_animation_player_deep(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for child in n.get_children():
		var nested := _find_animation_player_deep(child)
		if nested:
			return nested
	return null


func _resolve_clip_name(preferred: StringName) -> String:
	if animation_player == null:
		return ""
	var pref := String(preferred)
	if pref.is_empty():
		return ""
	if animation_player.has_animation(pref):
		return pref
	for clip in animation_player.get_animation_list():
		if clip == pref or clip.ends_with("/" + pref):
			return clip
		if String(clip).get_file() == pref:
			return clip
	return ""


func _apply_visual_vertical_offset() -> void:
	var vr := get_node_or_null("VisualRoot")
	if vr == null:
		return
	if not is_zero_approx(visual_mesh_vertical_offset):
		vr.position.y += visual_mesh_vertical_offset
	if not is_zero_approx(visual_mesh_yaw_offset_deg):
		vr.rotation.y += deg_to_rad(visual_mesh_yaw_offset_deg)


func _default_drops_for_species(species: String) -> Array[_AnimalDropEntry]:
	match species:
		"chicken":
			return [
				_make_drop("feather", 0.95, 1, 3),
				_make_drop("meat_raw", 0.65, 1, 2),
				_make_drop("bone", 0.20, 1, 1),
			]
		"rooster":
			return [
				_make_drop("feather", 0.98, 2, 4),
				_make_drop("meat_raw", 0.75, 1, 2),
				_make_drop("bone", 0.25, 1, 1),
			]
		"chick":
			return [
				_make_drop("feather", 0.35, 1, 1),
				_make_drop("meat_raw", 0.40, 1, 1),
				_make_drop("bone", 0.05, 1, 1),
			]
		"rabbit":
			return [
				_make_drop("meat_raw", 0.85, 1, 2),
				_make_drop("hide_raw", 0.75, 1, 1),
				_make_drop("bone", 0.30, 1, 1),
			]
		"horse", "cow", "bull":
			return [
				_make_drop("meat_raw", 0.82, 2, 4),
				_make_drop("hide_raw", 0.6, 1, 2),
				_make_drop("bone", 0.4, 1, 2),
			]
		"pig":
			return [
				_make_drop("meat_raw", 0.9, 2, 3),
				_make_drop("bone", 0.25, 1, 1),
			]
		"goose", "turkey":
			return [
				_make_drop("feather", 0.75, 1, 3),
				_make_drop("meat_raw", 0.7, 1, 2),
				_make_drop("bone", 0.2, 1, 1),
			]
		"ram", "sheep":
			return [
				_make_drop("meat_raw", 0.75, 1, 2),
				_make_drop("hide_raw", 0.8, 1, 2),
				_make_drop("bone", 0.25, 1, 1),
			]
		"walleye", "trout", "sturgeon", "roach", "pike", "perch", "largemouth", "drum", "catfish", "carp", "bluegill":
			return [
				_make_drop("meat_raw", 0.88, 1, 2),
				_make_drop("bone", 0.1, 0, 1),
			]
	return []


func _make_drop(item_id: String, chance: float, min_count: int, max_count: int) -> _AnimalDropEntry:
	var d := _AnimalDropEntry.new()
	d.item_id = item_id
	d.chance = chance
	d.min_count = min_count
	d.max_count = max_count
	return d


func _setup_health_bar() -> void:
	if not show_health_bar:
		return
	_health_bar_root = Node3D.new()
	_health_bar_root.name = "HealthBarRoot"
	_health_bar_root.position = Vector3(0.0, health_bar_height, 0.0)
	add_child(_health_bar_root)

	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(maxf(0.1, health_bar_width), maxf(0.02, health_bar_thickness))
	_health_bar_bg = MeshInstance3D.new()
	_health_bar_bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.08, 0.08, 0.08, 1.0)
	bg_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bg_mat.no_depth_test = false
	_health_bar_bg.material_override = bg_mat
	_health_bar_root.add_child(_health_bar_bg)

	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(maxf(0.1, health_bar_width), maxf(0.02, health_bar_thickness) * 0.8)
	_health_bar_fill = MeshInstance3D.new()
	_health_bar_fill.mesh = fill_mesh
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.95, 0.12, 0.12, 1.0)
	fill_mat.emission_enabled = true
	fill_mat.emission = Color(0.95, 0.12, 0.12, 1.0)
	fill_mat.emission_energy_multiplier = 0.7
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_mat.no_depth_test = false
	_health_bar_fill.material_override = fill_mat
	# Keep fill slightly in front of the black frame so it cannot be depth-occluded.
	_health_bar_fill.position = Vector3(0.0, 0.0, 0.01)
	_health_bar_root.add_child(_health_bar_fill)
	_health_bar_root.visible = false
	_geometry_fade_cache_dirty = true


func _maybe_update_health_bar_billboard() -> void:
	if _health_bar_root == null or _dead:
		return
	var must_always := (not use_simulation_lod) or (_lod_tier == LOD_FULL)
	var recent_hit := Time.get_ticks_msec() <= _health_bar_visible_until_ms
	if must_always or recent_hit:
		_update_health_bar_billboard()
		return
	_hb_billboard_tick += 1
	if _hb_billboard_tick % 10 == 0:
		_update_health_bar_billboard()


func _update_health_bar_billboard() -> void:
	if _health_bar_root == null or _dead:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_health_bar_root.look_at(cam.global_position, Vector3.UP, true)


func _update_health_bar_visual() -> void:
	if _health_bar_fill == null:
		return
	var ratio := clampf(_health / maxf(1.0, max_health), 0.0, 1.0)
	_health_bar_fill.visible = ratio > 0.0
	_health_bar_fill.scale.x = maxf(0.001, ratio)
	_health_bar_fill.position.x = -(1.0 - ratio) * health_bar_width * 0.5


func _show_health_bar_temporarily() -> void:
	if _health_bar_root == null or _dead:
		return
	_health_bar_visible_until_ms = Time.get_ticks_msec() + int(maxf(0.1, health_bar_visible_seconds_after_hit) * 1000.0)
	_health_bar_root.visible = true


func _update_health_bar_visibility() -> void:
	if _health_bar_root == null:
		return
	if _dead:
		_health_bar_root.visible = false
		return
	if _health <= 0.0:
		_health_bar_root.visible = false
		return
	_health_bar_root.visible = Time.get_ticks_msec() <= _health_bar_visible_until_ms
