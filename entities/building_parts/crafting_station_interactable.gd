extends Node3D

@export var station: RecipeData.CraftStation = RecipeData.CraftStation.NONE
@export var station_label: String = ""


func get_interaction_prompt(_player: Node) -> String:
	var label := station_label
	if label.is_empty():
		label = _station_name(station)
	return "E: Use %s" % label


func interact(player: Node) -> bool:
	if player == null:
		return false
	var menu: Node = player.get_node_or_null("GameMenu")
	if menu == null:
		_notify_player(player, "Cannot open forge right now.")
		return false
	if menu.has_method("open_forge_crafting_basic"):
		menu.call("open_forge_crafting_basic")
	elif menu.has_method("toggle"):
		menu.call("toggle", 4)
	if menu.has_method("_set_craft_station_filter"):
		menu.call("_set_craft_station_filter", int(station))
	return true


func _station_name(st: RecipeData.CraftStation) -> String:
	match st:
		RecipeData.CraftStation.ANVIL:
			return "Anvil"
		RecipeData.CraftStation.FURNACE:
			return "Furnace"
		RecipeData.CraftStation.CAMPFIRE:
			return "Campfire"
		RecipeData.CraftStation.STOVE:
			return "Stove"
		RecipeData.CraftStation.WORKBENCH:
			return "Workbench"
		_:
			return "Forge"


func _notify_player(player: Node, msg: String) -> void:
	if player.has_method("show_gameplay_message"):
		player.show_gameplay_message(msg)
