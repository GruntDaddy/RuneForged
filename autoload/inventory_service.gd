extends Node

## Global item counts for gatherers / UI. Not the addon CharacterInventorySystem.

signal inventory_changed

var items: Dictionary = {}  # item_id -> count


func add_item(item_name: String, quantity: int = 1) -> void:
	if item_name in items:
		items[item_name] = items[item_name] + quantity
	else:
		items[item_name] = quantity
	inventory_changed.emit()


func remove_item(item_name: String, quantity: int = 1) -> void:
	if item_name in items and items[item_name] > 0:
		items[item_name] = items[item_name] - quantity
		if items[item_name] <= 0:
			items.erase(item_name)
		inventory_changed.emit()


func get_items_copy() -> Dictionary:
	return items.duplicate()


func has_item(item_name: String) -> bool:
	return item_name in items


func get_item_count(item_name: String) -> int:
	return items.get(item_name, 0)
