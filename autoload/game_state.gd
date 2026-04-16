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
## Region id persisted in saves; routed in `main_menu.gd` `_scene_for_region`.
const REGION_OVERWORLD := "overworld"
const OVERWORLD_SCENE_PATH := "res://world/regions/tutorial_isle/tutorial_isle.tscn"
var region: String = ""
## Survival skills (harvest gates). Tune when XP/progression exists.
var woodcutting_level: int = 10
var mining_level: int = 10


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
		region = "tutorial_isle"
	woodcutting_level = int(d.get("woodcutting_level", 10))
	mining_level = int(d.get("mining_level", 10))
