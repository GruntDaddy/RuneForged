extends Node3D
class_name EnemySpawner

const _EnemyVariantData = preload("res://data/schemas/enemy_variant_data.gd")
const _EnemyBaseScene = preload("res://entities/characters/enemies/enemy_base.tscn")

@export var variant_data: _EnemyVariantData
@export_range(1, 64, 1) var max_alive: int = 3
@export_range(0.0, 600.0, 0.1) var respawn_seconds: float = 20.0
@export_range(0.0, 120.0, 0.1) var spawn_radius: float = 7.0
@export_range(1, 64, 1) var initial_spawn_count: int = 2
@export var enemy_scene_override: PackedScene

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
	var scene: PackedScene = enemy_scene_override if enemy_scene_override != null else _EnemyBaseScene
	if scene == null:
		return
	var inst := scene.instantiate()
	if inst == null or not (inst is Node3D):
		return
	var enemy := inst as Node3D
	if enemy.has_method("set"):
		enemy.set("variant_data", variant_data)
	var parent_node := get_parent()
	if parent_node == null:
		return
	parent_node.add_child.call_deferred(enemy)
	call_deferred("_finalize_spawn", enemy)


func _finalize_spawn(enemy: Node3D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	enemy.global_position = _pick_spawn_position()
	_alive.append(weakref(enemy))


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
