extends RefCounted
class_name ConsumableEffectService

const HEAL_SMALL_AMOUNT := 35.0


static func use(item_id: String, item: ItemData, user: Node) -> Dictionary:
	var effect_id := ""
	if item != null and not item.use_effect_id.is_empty():
		effect_id = item.use_effect_id
	match effect_id:
		"heal_small":
			return _heal_small(user)
		_:
			return {"success": false, "message": "Nothing happens."}


static func _heal_small(user: Node) -> Dictionary:
	if user == null or not user.has_method("heal"):
		return {"success": false, "message": "Can't use that now."}
	user.call("heal", HEAL_SMALL_AMOUNT)
	return {"success": true, "message": "You drink the potion and feel steadier."}
