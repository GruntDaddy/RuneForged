extends Node

const SAVE_PATH := "user://savegame.json"
## v1: flat GameState only. v2: game_state + inventory.
const SAVE_FORMAT_VERSION := 2


func save_game() -> void:
	var payload := {
		"version": SAVE_FORMAT_VERSION,
		"game_state": GameState.to_dict(),
		"inventory": InventoryService.get_save_dict(),
	}
	var json := JSON.stringify(payload, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not write %s" % SAVE_PATH)
		return
	file.store_string(json)


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("SaveManager: invalid JSON in save file.")
		return false
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var ver: int = int(data.get("version", 1))
	if ver >= 2 and data.has("game_state"):
		GameState.from_dict(data["game_state"])
		if data.has("inventory"):
			InventoryService.apply_save_dict(data["inventory"])
		else:
			InventoryService.clear_all_slots()
	else:
		GameState.from_dict(data)
		InventoryService.clear_all_slots()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("savegame.json"):
		dir.remove("savegame.json")
