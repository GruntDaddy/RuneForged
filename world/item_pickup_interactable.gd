extends Node3D

@export var item_id: String = ""
@export_range(1, 999, 1) var quantity: int = 1
@export var prompt_verb: String = "Pick up"
var _consumed: bool = false


func get_interaction_prompt(_player: Node) -> String:
	var item_name: String = _item_display_name()
	if item_name.is_empty():
		return ""
	return "E: %s %s" % [prompt_verb, item_name]


func interact(player: Node) -> bool:
	if _consumed:
		return false
	if item_id.is_empty():
		return false
	var inv: Node = get_node_or_null("/root/InventoryService")
	if inv == null or not inv.has_method("add_item"):
		_notify_player(player, "Cannot pick that up right now.")
		return false
	var left: int = int(inv.add_item(item_id, quantity))
	var added: int = quantity - left
	if added <= 0:
		_notify_player(player, "Inventory full.")
		return false
	var label: String = _item_display_name()
	if left > 0:
		quantity = left
		_notify_player(player, "Picked up %d %s. Inventory is full." % [added, label])
		return true
	_consumed = true
	_notify_player(player, "Picked up %s." % label)
	queue_free()
	return true


func _item_display_name() -> String:
	var inv: Node = get_node_or_null("/root/InventoryService")
	if inv != null and inv.has_method("get_item_display_name"):
		var from_inv := str(inv.get_item_display_name(item_id))
		if not from_inv.is_empty():
			return from_inv
	var it: ItemData = ItemCatalog.get_item(item_id)
	if it != null and not it.display_name.is_empty():
		return it.display_name
	return item_id.replace("_", " ").capitalize()


func _notify_player(player: Node, msg: String) -> void:
	if player != null and player.has_method("show_gameplay_message"):
		player.show_gameplay_message(msg)
