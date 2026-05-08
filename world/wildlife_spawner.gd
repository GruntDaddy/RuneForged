extends Node3D
class_name WildlifeSpawner

## Spawns [WildAnimal] instances (land or aquatic) and caps population like [EnemySpawner].
## Sets [member WildAnimal.respawn_seconds] to 0 by default so scene-built respawn does not stack with this spawner.

@export var animal_scene: PackedScene
@export_range(1, 64, 1) var max_alive: int = 2
@export_range(0.0, 600.0, 0.1) var respawn_seconds: float = 25.0
@export_range(0.0, 120.0, 0.1) var spawn_radius: float = 4.0
@export_range(1, 64, 1) var initial_spawn_count: int = 1
@export var disable_animal_scene_respawn: bool = true
@export var apply_facing_yaw_offset: bool = false
@export_range(-3.14159, 3.14159, 0.001) var facing_yaw_offset: float = 0.0

var _alive: Array[WeakRef] = []
var _respawn_wait_sec: float = 0.0


func _ready() -> void:
	call_deferred("_seed_initial_spawn")


func _process(delta: float) -> void:
	_reap_dead_refs()
	if _alive.size() >= max_alive:
		return
	if _respawn_wait_sec > 0.0:
		_respawn_wait_sec = maxf(0.0, _respawn_wait_sec - delta)
		return
	_spawn_one()
	_respawn_wait_sec = respawn_seconds


func _seed_initial_spawn() -> void:
	var count := mini(initial_spawn_count, max_alive)
	for _i in range(count):
		_spawn_one()


func _spawn_one() -> void:
	if animal_scene == null:
		return
	var inst := animal_scene.instantiate()
	if inst == null or not (inst is Node3D):
		return
	var animal := inst as Node3D
	if animal.has_method("set"):
		if disable_animal_scene_respawn:
			animal.set("respawn_seconds", 0.0)
		if apply_facing_yaw_offset:
			animal.set("facing_yaw_offset", facing_yaw_offset)
	var parent_node := get_parent()
	if parent_node == null:
		return
	parent_node.add_child.call_deferred(animal)
	call_deferred("_finalize_spawn", animal)


func _finalize_spawn(animal: Node3D) -> void:
	if animal == null or not is_instance_valid(animal):
		return
	var pos := _pick_spawn_position()
	# Preserve rotation/scale authored on this spawner (matches former direct instance transforms).
	animal.global_transform = Transform3D(global_transform.basis, pos)
	if animal.has_method("sync_spawn_anchor"):
		animal.call("sync_spawn_anchor")
	_alive.append(weakref(animal))


func _pick_spawn_position() -> Vector3:
	if spawn_radius <= 0.01:
		return global_position
	var ang := randf() * TAU
	var r := randf() * spawn_radius
	return global_position + Vector3(cos(ang) * r, 0.0, sin(ang) * r)


func _reap_dead_refs() -> void:
	var next_refs: Array[WeakRef] = []
	for wr in _alive:
		if wr == null:
			continue
		var n: Object = wr.get_ref()
		if n != null and is_instance_valid(n):
			next_refs.append(wr)
	_alive = next_refs
