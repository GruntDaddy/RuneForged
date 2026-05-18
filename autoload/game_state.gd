extends Node

## Persistent run data. SaveManager serializes these fields to user://savegame.json

var player_name: String = ""
var gender: String = "Male"
var head_index: int = 0
var shirt_index: int = 0
var pants_index: int = 0
var origin_id: int = 0
var trait_id_1: int = 0
var trait_id_2: int = 1
var birthsign_id: int = 0
## Region ids persisted in saves; load routing uses `scene_path_for_saved_region`.
const REGION_JORVIK := "jorvik"
const REGION_OVERWORLD := "overworld"
const LEGACY_REGION_TUTORIAL_ISLE := "tutorial_isle"
const REGION_CHARACTER_CREATOR := "character_creator"

const JORVIK_SCENE_PATH := "res://world/regions/jorvik/jorvik.tscn"
const OVERWORLD_SCENE_PATH := JORVIK_SCENE_PATH
const LEGACY_JORVIK_SCENE_SUFFIX := "/tutorial_isle.tscn"
const SCENE_BOOT_SPLASH := "res://ui/boot_splash/splash_boot.tscn"
const SCENE_MAIN_MENU := "res://ui/menus/main_menu.tscn"
const SCENE_CHARACTER_CREATOR := "res://ui/character_creator/character_creator.tscn"
const SCENE_OPTIONS_MENU := "res://ui/menus/options_menu.tscn"
const LEGACY_ITEM_ID_ALIASES := {
	"wood": "logs",
	"oak_logs": "logs_oak",
	"tin_ore": "ore_tin",
	"torch": "tool_torch",
	"hammer": "tool_hammer",
	"chisel": "tool_chisel",
	"rune_spark": "rune_air",
}
const SKILL_ID_TO_FIELD := {
	"woodcutting": "woodcutting_level",
	"mining": "mining_level",
	"survival": "survival_level",
	"smithing": "smithing_level",
	"crafting": "crafting_level",
	"fishing": "fishing_level",
}
var region: String = ""
## Survival skills (harvest gates). Tune when XP/progression exists.
var woodcutting_level: int = 10
var mining_level: int = 10
var survival_level: int = 10
var smithing_level: int = 10
var crafting_level: int = 10
var fishing_level: int = 1
## XP toward next fishing level; levels up via `add_fishing_xp`.
var fishing_xp: int = 0
## Canonical skill registry persisted as skill_id -> level.
var skill_levels: Dictionary = {}
## Day/night persistence used by world sky controller.
var time_of_day: float = 0.32
var moon_phase: float = 0.18
## Campfire/torch runtime persistence keyed by scene path.
var world_fire_states: Dictionary = {}
## Runtime placed fire props persisted per region.
var placed_fire_nodes: Array = []
## Player-placed modular building pieces (medieval village kit); see docs/save-format.md.
var placed_modular_build_pieces: Array = []
## Temporary campfire warmth effect expiry in UTC milliseconds.
var warmth_until_unix_ms: int = 0
## Run-speed tuning while in nighttime conditions.
var campfire_night_run_bonus: float = 0.2
var campfire_night_penalty: float = 0.15
## Equipped items: slot id -> { "id": String, "count": int }. Slots: head, neck, ring_1, ring_2, cape, chest, hands, legs, feet, main_hand, off_hand, back
var equipment: Dictionary = {}
## Hotbar quick-use item ids for keys [1]-[4].
var hotbar_item_ids: Array[String] = ["", "", "", ""]
## If set, hotbar key casts this spell id instead of using `hotbar_item_ids` for that slot (parallel index).
var hotbar_spell_ids: Array[String] = ["", "", "", ""]


func _ready() -> void:
	_sync_skill_registry_from_legacy_fields()


func reset() -> void:
	player_name = ""
	gender = "Male"
	head_index = 0
	shirt_index = 0
	pants_index = 0
	origin_id = 0
	trait_id_1 = 0
	trait_id_2 = 1
	birthsign_id = 0
	region = ""
	woodcutting_level = 10
	mining_level = 10
	survival_level = 10
	smithing_level = 10
	crafting_level = 10
	fishing_level = 1
	fishing_xp = 0
	_sync_skill_registry_from_legacy_fields()
	time_of_day = 0.32
	moon_phase = 0.18
	world_fire_states = {}
	placed_fire_nodes = []
	placed_modular_build_pieces = []
	warmth_until_unix_ms = 0
	campfire_night_run_bonus = 0.2
	campfire_night_penalty = 0.15
	equipment = {}
	hotbar_item_ids = ["", "", "", ""]
	hotbar_spell_ids = ["", "", "", ""]


func to_dict() -> Dictionary:
	return {
		"player_name": player_name,
		"gender": gender,
		"head_index": head_index,
		"shirt_index": shirt_index,
		"pants_index": pants_index,
		"origin_id": origin_id,
		"trait_id_1": trait_id_1,
		"trait_id_2": trait_id_2,
		"birthsign_id": birthsign_id,
		"region": region,
		"woodcutting_level": woodcutting_level,
		"mining_level": mining_level,
		"survival_level": survival_level,
		"smithing_level": smithing_level,
		"crafting_level": crafting_level,
		"fishing_level": fishing_level,
		"fishing_xp": fishing_xp,
		"skill_levels": skill_levels.duplicate(true),
		"time_of_day": time_of_day,
		"moon_phase": moon_phase,
		"world_fire_states": world_fire_states.duplicate(true),
		"placed_fire_nodes": placed_fire_nodes.duplicate(true),
		"placed_modular_build_pieces": placed_modular_build_pieces.duplicate(true),
		"warmth_until_unix_ms": warmth_until_unix_ms,
		"campfire_night_run_bonus": campfire_night_run_bonus,
		"campfire_night_penalty": campfire_night_penalty,
		"equipment": equipment.duplicate(true),
		"hotbar_item_ids": hotbar_item_ids.duplicate(),
		"hotbar_spell_ids": hotbar_spell_ids.duplicate(),
	}


func from_dict(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	player_name = str(d.get("player_name", ""))
	gender = str(d.get("gender", "Male"))
	head_index = int(d.get("head_index", 0))
	shirt_index = int(d.get("shirt_index", 0))
	pants_index = int(d.get("pants_index", 0))
	origin_id = int(d.get("origin_id", 0))
	trait_id_1 = int(d.get("trait_id_1", 0))
	trait_id_2 = int(d.get("trait_id_2", 1))
	birthsign_id = int(d.get("birthsign_id", 0))
	region = normalize_region_id(str(d.get("region", "")))
	woodcutting_level = int(d.get("woodcutting_level", 10))
	mining_level = int(d.get("mining_level", 10))
	survival_level = int(d.get("survival_level", 10))
	smithing_level = int(d.get("smithing_level", 10))
	crafting_level = int(d.get("crafting_level", 10))
	fishing_level = int(d.get("fishing_level", 1))
	fishing_xp = maxi(0, int(d.get("fishing_xp", 0)))
	_sync_skill_registry_from_legacy_fields()
	if typeof(d.get("skill_levels", null)) == TYPE_DICTIONARY:
		_apply_skill_registry_dict(d.get("skill_levels", {}))
	time_of_day = clampf(float(d.get("time_of_day", 0.32)), 0.0, 0.999999)
	moon_phase = clampf(float(d.get("moon_phase", 0.18)), 0.0, 0.999999)
	if typeof(d.get("world_fire_states", null)) == TYPE_DICTIONARY:
		world_fire_states = (d.get("world_fire_states", {}) as Dictionary).duplicate(true)
	else:
		world_fire_states = {}
	if typeof(d.get("placed_fire_nodes", null)) == TYPE_ARRAY:
		placed_fire_nodes = _migrate_placed_region_ids(d.get("placed_fire_nodes", []) as Array)
	else:
		placed_fire_nodes = []
	if typeof(d.get("placed_modular_build_pieces", null)) == TYPE_ARRAY:
		placed_modular_build_pieces = _migrate_placed_region_ids(d.get("placed_modular_build_pieces", []) as Array)
	else:
		placed_modular_build_pieces = []
	warmth_until_unix_ms = int(d.get("warmth_until_unix_ms", 0))
	campfire_night_run_bonus = float(d.get("campfire_night_run_bonus", 0.2))
	campfire_night_penalty = float(d.get("campfire_night_penalty", 0.15))
	if typeof(d.get("equipment", null)) == TYPE_DICTIONARY:
		equipment = (d.get("equipment", {}) as Dictionary).duplicate(true)
	else:
		equipment = {}
	_normalize_equipment_map()
	hotbar_item_ids = ["", "", "", ""]
	var hb: Variant = d.get("hotbar_item_ids", null)
	if typeof(hb) == TYPE_ARRAY:
		var arr: Array = hb
		for i in mini(4, arr.size()):
			hotbar_item_ids[i] = str(arr[i])
	hotbar_spell_ids = ["", "", "", ""]
	var hs: Variant = d.get("hotbar_spell_ids", null)
	if typeof(hs) == TYPE_ARRAY:
		var sa: Array = hs
		for i in mini(4, sa.size()):
			hotbar_spell_ids[i] = str(sa[i])


func ensure_hotbar_arrays() -> void:
	while hotbar_item_ids.size() < 4:
		hotbar_item_ids.append("")
	while hotbar_spell_ids.size() < 4:
		hotbar_spell_ids.append("")


func clear_hotbar_slot(idx: int) -> void:
	ensure_hotbar_arrays()
	if idx < 0 or idx >= 4:
		return
	hotbar_item_ids[idx] = ""
	hotbar_spell_ids[idx] = ""


func normalize_item_id(id: String) -> String:
	return str(LEGACY_ITEM_ID_ALIASES.get(id, id))


func get_skill_level(skill_id: String, fallback: int = 1) -> int:
	var sid := str(skill_id).strip_edges().to_lower()
	if sid.is_empty():
		return fallback
	if skill_levels.has(sid):
		return int(skill_levels[sid])
	if SKILL_ID_TO_FIELD.has(sid):
		return int(get(str(SKILL_ID_TO_FIELD[sid])))
	return fallback


func set_skill_level(skill_id: String, level: int) -> void:
	var sid := str(skill_id).strip_edges().to_lower()
	if sid.is_empty():
		return
	var clamped := maxi(1, level)
	skill_levels[sid] = clamped
	if SKILL_ID_TO_FIELD.has(sid):
		set(str(SKILL_ID_TO_FIELD[sid]), clamped)


func add_fishing_xp(amount: int) -> void:
	if amount < 1:
		return
	fishing_xp = maxi(0, fishing_xp) + amount
	while fishing_xp >= _fishing_xp_for_next_level():
		fishing_xp -= _fishing_xp_for_next_level()
		var lv := get_skill_level("fishing", 1)
		set_skill_level("fishing", lv + 1)


func _fishing_xp_for_next_level() -> int:
	var lv := get_skill_level("fishing", 1)
	return 28 + lv * 10


func get_skill_levels_copy() -> Dictionary:
	return skill_levels.duplicate(true)


func get_equipment_slot(slot: String) -> Variant:
	return equipment.get(slot, null)


func set_equipment_slot(slot: String, item_id: String, count: int = 1) -> void:
	if slot.is_empty():
		return
	var norm_id := normalize_item_id(item_id)
	if norm_id.is_empty():
		equipment.erase(slot)
		return
	var entry: Dictionary = {"id": norm_id, "count": maxi(1, count)}
	if norm_id == "tool_torch":
		entry["torch_lit"] = false
	equipment[slot] = entry


func set_torch_lit_on_off_hand(lit: bool) -> void:
	var v: Variant = get_equipment_slot("off_hand")
	if typeof(v) != TYPE_DICTIONARY:
		return
	var d: Dictionary = v
	if normalize_item_id(str(d.get("id", ""))) != "tool_torch":
		return
	d["torch_lit"] = lit
	equipment["off_hand"] = d


func is_off_hand_torch_lit() -> bool:
	var v: Variant = get_equipment_slot("off_hand")
	if typeof(v) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = v
	if normalize_item_id(str(d.get("id", ""))) != "tool_torch":
		return false
	return bool(d.get("torch_lit", false))


func clear_equipment_slot(slot: String) -> void:
	equipment.erase(slot)


func _normalize_equipment_map() -> void:
	for slot in equipment.keys():
		var key := str(slot)
		var val: Variant = equipment.get(slot, null)
		if typeof(val) != TYPE_DICTIONARY:
			equipment.erase(slot)
			continue
		var d: Dictionary = val
		var norm_id := normalize_item_id(str(d.get("id", "")))
		if norm_id.is_empty():
			equipment.erase(slot)
			continue
		var rebuilt: Dictionary = {"id": norm_id, "count": maxi(1, int(d.get("count", 1)))}
		if norm_id == "tool_torch" and d.has("torch_lit"):
			rebuilt["torch_lit"] = bool(d.get("torch_lit", false))
		equipment[key] = rebuilt


func _sync_skill_registry_from_legacy_fields() -> void:
	for sid in SKILL_ID_TO_FIELD.keys():
		var field_name := str(SKILL_ID_TO_FIELD[sid])
		skill_levels[str(sid)] = maxi(1, int(get(field_name)))


func _apply_skill_registry_dict(v: Variant) -> void:
	if typeof(v) != TYPE_DICTIONARY:
		return
	var d: Dictionary = v
	for sid in d.keys():
		var key := str(sid).strip_edges().to_lower()
		if key.is_empty():
			continue
		var lvl := maxi(1, int(d[sid]))
		skill_levels[key] = lvl
		if SKILL_ID_TO_FIELD.has(key):
			set(str(SKILL_ID_TO_FIELD[key]), lvl)


func normalize_region_id(region_id: String) -> String:
	var rid := str(region_id).strip_edges()
	match rid:
		REGION_OVERWORLD, LEGACY_REGION_TUTORIAL_ISLE:
			return REGION_JORVIK
		_:
			return rid


func scene_path_for_saved_region(saved_region: String) -> String:
	match normalize_region_id(saved_region):
		REGION_JORVIK:
			return JORVIK_SCENE_PATH
		REGION_CHARACTER_CREATOR:
			return SCENE_CHARACTER_CREATOR
		_:
			return SCENE_MAIN_MENU


## When `region` is empty (e.g. Run Current Scene), infer a stable id from the active main scene for saves / modular build.
func region_effective_for_scene_path(scene_path: String) -> String:
	var persisted := normalize_region_id(str(region).strip_edges())
	if not persisted.is_empty():
		return persisted
	var p := str(scene_path).strip_edges()
	if p == JORVIK_SCENE_PATH or p.ends_with("/jorvik.tscn") or p.ends_with(LEGACY_JORVIK_SCENE_SUFFIX):
		return REGION_JORVIK
	return ""


func _migrate_placed_region_ids(entries: Array) -> Array:
	var out: Array = entries.duplicate(true)
	for i in out.size():
		var entry: Variant = out[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = (entry as Dictionary).duplicate(true)
		if d.has("region"):
			d["region"] = normalize_region_id(str(d.get("region", "")))
		out[i] = d
	return out
