extends RefCounted
class_name RuneEffectService


static func resolve_effect_id(item_id: String, item: ItemData) -> String:
	if item != null and not item.use_effect_id.is_empty():
		return item.use_effect_id
	return item_id


static func default_cooldown_ms(effect_id: String) -> int:
	match effect_id:
		"rune_spark", "stamina_restore_small":
			return 12000
		_:
			return 0


static func cast(effect_id: String, caster: Node) -> Dictionary:
	match effect_id:
		"rune_spark", "stamina_restore_small":
			return _cast_stamina_restore_small(caster)
		_:
			return {"success": false, "message": "That rune has no effect yet."}


static func _cast_stamina_restore_small(caster: Node) -> Dictionary:
	if caster == null:
		return {"success": false, "message": "No caster."}
	var before_stamina: float = float(caster.get("stamina"))
	var max_stamina: float = float(caster.get("max_stamina"))
	var next_stamina: float = minf(max_stamina, before_stamina + 28.0)
	caster.set("stamina", next_stamina)
	if next_stamina <= before_stamina + 0.01:
		return {"success": false, "message": "Stamina already full."}
	return {"success": true, "message": "Spark Rune surges. Stamina restored."}
