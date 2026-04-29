extends Node3D

var _velocity: Vector3 = Vector3.ZERO
var _shooter: Node = null
var _damage: float = 1.0
var _collision_mask: int = 7
var _lifetime: float = 10.0
var _gravity_scale: float = 1.0
var _age: float = 0.0
var _spent: bool = false
var _exclude: Array = []


func fire(
	p_shooter: Node,
	p_damage: float,
	origin: Vector3,
	direction: Vector3,
	speed: float,
	collision_mask: int,
	gravity_scale: float,
	lifetime: float,
	exclude_rids: Array
) -> void:
	_shooter = p_shooter
	_damage = p_damage
	_collision_mask = collision_mask
	_gravity_scale = gravity_scale
	_lifetime = lifetime
	_exclude.clear()
	for r in exclude_rids:
		_exclude.append(r)
	global_position = origin
	var dir := direction
	if dir.length_squared() < 1e-6:
		dir = Vector3(0, 0, -1)
	else:
		dir = dir.normalized()
	_velocity = dir * speed
	_align_to_velocity(_velocity.normalized())


func _align_to_velocity(dir: Vector3) -> void:
	var target := global_position + dir
	if global_position.distance_squared_to(target) < 1e-8:
		target = global_position + Vector3(0, 0, -1)
	look_at(target, Vector3.UP)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_age += delta
	if _age > _lifetime:
		queue_free()
		return
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_velocity.y -= g * _gravity_scale * delta
	var from := global_position
	var motion := _velocity * delta
	var to := from + motion
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = _collision_mask
	q.exclude = _exclude
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		var vn := _velocity.normalized()
		if vn.length_squared() > 1e-6:
			_align_to_velocity(vn)
		return
	_spent = true
	global_position = hit.position
	var collider: Object = hit.get("collider", null)
	_apply_hit(collider)
	queue_free()


func _apply_hit(collider: Object) -> void:
	if collider == null:
		return
	if _shooter != null and collider == _shooter:
		return
	if collider.has_method("receive_hit"):
		collider.call("receive_hit", _damage, _shooter)
