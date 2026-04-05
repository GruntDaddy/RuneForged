extends Node

const SAVE_PATH := "user://savegame.json"


func save_game() -> void:
	var json := JSON.stringify(GameState.to_dict(), "\t")
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
	GameState.from_dict(data)
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("savegame.json"):
		dir.remove("savegame.json")
