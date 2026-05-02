extends RefCounted
class_name RuneEffectService

## Elemental runes map to `use_effect_id` on each ItemData (see `data/items/runes/`).

const _AirPushVfx: PackedScene = preload("res://entities/effects/air_push_gust.tscn")

const AIR_PUSH_RANGE: float = 9.0
const AIR_PUSH_ORIGIN_Y: float = 1.15
const AIR_PUSH_FORWARD_DOT_MIN: float = 0.25
const AIR_PUSH_DURATION_SEC: float = 0.48
const AIR_PUSH_SPEED: float = 5.8


static func resolve_effect_id(item_id: String, item: ItemData) -> String:
	if item != null and not item.use_effect_id.is_empty():
		return item.use_effect_id
	return item_id


static func default_cooldown_ms(effect_id: String) -> int:
	match effect_id:
		"spell_air_push":
			return 4500
		_:
			return 0


static func has_air_push_target(caster: Node) -> bool:
	if caster == null or not (caster is Node3D):
		return false
	return _find_creature_in_front(caster as Node3D) != null


static func cast(effect_id: String, caster: Node) -> Dictionary:
	match effect_id:
		"spell_air_push":
			return _cast_spell_air_push(caster)
		"rune_earth", "rune_water", "rune_fire":
			return {
				"success": false,
				"message": "That element has no spell bound yet.",
			}
		_:
			return {"success": false, "message": "That rune has no spell bound yet."}


static func _cast_spell_air_push(caster: Node) -> Dictionary:
	if caster == null or not (caster is Node3D):
		return {"success": false, "message": "Invalid caster."}
	var c3 := caster as Node3D
	var target: Object = _find_creature_in_front(c3)
	if target == null:
		return {"success": false, "message": "No creature in front of you."}
	if target.has_method("apply_wind_push"):
		target.call(
			"apply_wind_push",
			c3,
			AIR_PUSH_DURATION_SEC,
			AIR_PUSH_SPEED
		)
	else:
		return {"success": false, "message": "That foe cannot be pushed."}
	_spawn_air_push_vfx(c3, target)
	return {"success": true, "message": "A gust of wind shoves your foe back."}


static func _find_creature_in_front(caster: Node3D) -> Object:
	var forward := Vector3(0.0, 0.0, -1.0)
	if caster.has_method("get_magic_cast_forward_xz"):
		forward = caster.call("get_magic_cast_forward_xz")
	else:
		var b := caster.global_transform.basis
		forward = -b.z
		forward.y = 0.0
		if forward.length_squared() > 1e-6:
			forward = forward.normalized()
	var origin := caster.global_position + Vector3(0.0, AIR_PUSH_ORIGIN_Y, 0.0)
	var best: Object = null
	var best_d2: float = INF
	for n in caster.get_tree().get_nodes_in_group("creature"):
		if not (n is Node3D):
			continue
		var t := n as Node3D
		var to_t := t.global_position - origin
		to_t.y = 0.0
		if to_t.length_squared() < 1e-6:
			continue
		if forward.dot(to_t.normalized()) < AIR_PUSH_FORWARD_DOT_MIN:
			continue
		var d2 := to_t.length_squared()
		if d2 > AIR_PUSH_RANGE * AIR_PUSH_RANGE:
			continue
		if d2 < best_d2:
			best_d2 = d2
			best = n
	return best


static func _spawn_air_push_vfx(caster: Node3D, target: Object) -> void:
	if not (target is Node3D):
		return
	var tgt := target as Node3D
	var parent: Node = caster.get_tree().current_scene
	if parent == null:
		parent = caster.get_parent()
	if parent == null:
		return
	var inst: Variant = _AirPushVfx.instantiate()
	if not (inst is Node3D):
		return
	parent.add_child(inst as Node)
	var mid: Vector3 = (caster.global_position + tgt.global_position) * 0.5 + Vector3(0.0, 0.9, 0.0)
	(inst as Node3D).global_position = mid
	var blow := (tgt.global_position - caster.global_position)
	blow.y = 0.0
	if blow.length_squared() > 1e-6:
		var look := mid + blow.normalized()
		(inst as Node3D).look_at(look, Vector3.UP)
