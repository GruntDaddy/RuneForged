extends Node3D
## World pickup for `tool_tacklebox` with starter hooks, bobber, and bait (consumed from tackle via fishing).

var _consumed: bool = false


func get_interaction_prompt(_player: Node) -> String:
	return "E: Pick up tackle box"


func interact(player: Node) -> bool:
	if _consumed:
		return false
	var inv: Node = get_node_or_null("/root/InventoryService")
	if inv == null or not inv.has_method("add_item"):
		_notify_player(player, "Cannot pick that up right now.")
		return false
	var tackle: Dictionary = InventoryService.empty_tackle()
	var bait_arr: Array = tackle["bait"] as Array
	var hooks_arr: Array = tackle["hooks"] as Array
	var bobbers_arr: Array = tackle["bobbers"] as Array
	bait_arr[0] = {"id": "tool_fishing_bait", "count": 24}
	hooks_arr[0] = {"id": "tool_fishing_hook", "count": 1}
	bobbers_arr[0] = {"id": "tool_fishing_bobber", "count": 1}
	var left: int = int(inv.add_item("tool_tacklebox", 1, tackle))
	if left > 0:
		_notify_player(player, "Inventory full.")
		return false
	_consumed = true
	_notify_player(player, "Picked up tackle box.")
	queue_free()
	return true


func _notify_player(player: Node, msg: String) -> void:
	if player != null and player.has_method("show_gameplay_message"):
		player.show_gameplay_message(msg)
