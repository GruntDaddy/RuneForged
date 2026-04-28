extends CharacterBody3D
class_name WildAnimal

const _AnimalDropEntry = preload("res://entities/characters/animals/animal_drop_entry.gd")

@export var max_health: float = 20.0
@export var species_id: String = ""
@export var move_speed: float = 1.1
@export var turn_speed: float = 5.5
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

## FBX meshes usually face +Z; Godot uses -Z as forward. Default PI fixes “walks backward” unless your model matches Godot.
@export var facing_yaw_offset: float = PI

@export var idle_animation: StringName = &"Idle"
@export var walk_animation: StringName = &"Walk"
@export var death_animation: StringName = &"Death"

## Negative values move the mesh down so feet align with the ground when the FBX pivot sits high.
@export var visual_mesh_vertical_offset: float = 0.0

@export var drops: Array[_AnimalDropEntry] = []

var animation_player: AnimationPlayer

var _idle_clip: String = ""
var _walk_clip: String = ""
var _death_clip: String = ""

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _spawn_position: Vector3 = Vector3.ZERO
var _health: float = 0.0
var _dead: bool = false
var _is_walking: bool = false
var _phase_timeout: float = 0.0
var _walk_target: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("creature")
	animation_player = _resolve_animation_player()
	if animation_player:
		_idle_clip = _resolve_clip_name(idle_animation)
		_walk_clip = _resolve_clip_name(walk_animation)
		_death_clip = _resolve_clip_name(death_animation)
	_apply_visual_vertical_offset()
	_spawn_position = global_position
	_health = maxf(1.0, max_health)
	if drops.is_empty():
		drops = _default_drops_for_species(species_id)
	_set_idle_phase()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_phase_timeout -= delta
	if _phase_timeout <= 0.0:
		if _is_walking:
			_set_idle_phase()
		else:
			_set_walk_phase()
	var planar_velocity := Vector3.ZERO
	if _is_walking:
		var to_target := _walk_target - global_position
		to_target.y = 0.0
		var len_sq := to_target.length_squared()
		if len_sq > 1e-8:
			var dir := to_target.normalized()
			var target_yaw := atan2(dir.x, dir.z) + facing_yaw_offset
			rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))
			if len_sq > 0.04:
				planar_velocity = dir * move_speed
	velocity.x = planar_velocity.x
	velocity.z = planar_velocity.z
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_update_anim()


func can_receive_hit() -> bool:
	return not _dead


func get_interaction_prompt(_player: Node) -> String:
	if _dead:
		return ""
	return "LMB: Attack"


func receive_hit(damage: float, _source: Node = null) -> bool:
	if _dead:
		return false
	var dealt := maxf(0.0, damage)
	if dealt <= 0.0:
		return false
	_health -= dealt
	if _health <= 0.0:
		_die()
	return true


func _die() -> void:
	if _dead:
		return
	_dead = true
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
			(node as Node3D).global_position = global_position + o
		if node.has_method("set_resource_type"):
			node.set_resource_type(entry.item_id)
		elif "resource_type" in node:
			node.resource_type = entry.item_id
		if node.has_method("set_quantity"):
			node.set_quantity(drop_count)
		elif "quantity" in node:
			node.quantity = drop_count


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
	if is_zero_approx(visual_mesh_vertical_offset):
		return
	var vr := get_node_or_null("VisualRoot")
	if vr:
		vr.position.y += visual_mesh_vertical_offset


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
	return []


func _make_drop(item_id: String, chance: float, min_count: int, max_count: int) -> _AnimalDropEntry:
	var d := _AnimalDropEntry.new()
	d.item_id = item_id
	d.chance = chance
	d.min_count = min_count
	d.max_count = max_count
	return d
