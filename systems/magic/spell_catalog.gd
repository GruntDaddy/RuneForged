extends RefCounted
class_name SpellCatalog

## Authoritative list of castable spell ids for UI + hotbar binding. Extend as spells ship.


static func get_known_spell_ids() -> PackedStringArray:
	return PackedStringArray(["spell_air_push"])


static func get_display_name(spell_id: String) -> String:
	match spell_id:
		"spell_air_push":
			return "Push"
		_:
			var s := spell_id.strip_edges()
			if s.is_empty():
				return ""
			return s.replace("_", " ").capitalize()


static func get_description(spell_id: String) -> String:
	match spell_id:
		"spell_air_push":
			return "Air · Level 1 — Gust of wind; shoves a creature backward. No damage."
		_:
			return ""
