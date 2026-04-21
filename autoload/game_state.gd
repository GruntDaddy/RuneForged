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
const REGION_OVERWORLD := "overworld"
## Legacy save value remapped to `REGION_TUTORIAL_ISLE` in `from_dict`.
const REGION_TUTORIAL_ISLE := "tutorial_isle"
const REGION_CHARACTER_CREATOR := "character_creator"

const OVERWORLD_SCENE_PATH := "res://world/regions/tutorial_isle/tutorial_isle.tscn"
const SCENE_BOOT_SPLASH := "res://ui/boot_splash/splash_boot.tscn"
const SCENE_MAIN_MENU := "res://ui/menus/main_menu.tscn"
const SCENE_CHARACTER_CREATOR := "res://ui/character_creator/character_creator.tscn"
const SCENE_OPTIONS_MENU := "res://ui/menus/options_menu.tscn"
var region: String = ""
## Survival skills (harvest gates). Tune when XP/progression exists.
var woodcutting_level: int = 10
var mining_level: int = 10
## Day/night persistence used by world sky controller.
var time_of_day: float = 0.32
var moon_phase: float = 0.18
## Campfire/torch runtime persistence keyed by scene path.
var world_fire_states: Dictionary = {}
## Runtime placed fire props persisted per region.
var placed_fire_nodes: Array = []
## Temporary campfire warmth effect expiry in UTC milliseconds.
var warmth_until_unix_ms: int = 0
## Run-speed tuning while in nighttime conditions.
var campfire_night_run_bonus: float = 0.2
var campfire_night_penalty: float = 0.15


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
	time_of_day = 0.32
	moon_phase = 0.18
	world_fire_states = {}
	placed_fire_nodes = []
	warmth_until_unix_ms = 0
	campfire_night_run_bonus = 0.2
	campfire_night_penalty = 0.15


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
		"time_of_day": time_of_day,
		"moon_phase": moon_phase,
		"world_fire_states": world_fire_states.duplicate(true),
		"placed_fire_nodes": placed_fire_nodes.duplicate(true),
		"warmth_until_unix_ms": warmth_until_unix_ms,
		"campfire_night_run_bonus": campfire_night_run_bonus,
		"campfire_night_penalty": campfire_night_penalty,
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
	region = str(d.get("region", ""))
	if region == REGION_OVERWORLD:
		region = REGION_TUTORIAL_ISLE
	woodcutting_level = int(d.get("woodcutting_level", 10))
	mining_level = int(d.get("mining_level", 10))
	time_of_day = clampf(float(d.get("time_of_day", 0.32)), 0.0, 0.999999)
	moon_phase = clampf(float(d.get("moon_phase", 0.18)), 0.0, 0.999999)
	if typeof(d.get("world_fire_states", null)) == TYPE_DICTIONARY:
		world_fire_states = (d.get("world_fire_states", {}) as Dictionary).duplicate(true)
	else:
		world_fire_states = {}
	if typeof(d.get("placed_fire_nodes", null)) == TYPE_ARRAY:
		placed_fire_nodes = (d.get("placed_fire_nodes", []) as Array).duplicate(true)
	else:
		placed_fire_nodes = []
	warmth_until_unix_ms = int(d.get("warmth_until_unix_ms", 0))
	campfire_night_run_bonus = float(d.get("campfire_night_run_bonus", 0.2))
	campfire_night_penalty = float(d.get("campfire_night_penalty", 0.15))


func scene_path_for_saved_region(saved_region: String) -> String:
	match saved_region:
		REGION_OVERWORLD, REGION_TUTORIAL_ISLE:
			return OVERWORLD_SCENE_PATH
		REGION_CHARACTER_CREATOR:
			return SCENE_CHARACTER_CREATOR
		_:
			return SCENE_MAIN_MENU
