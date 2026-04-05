extends Node

var items = {} # {item_name: count}

func add_item(item_name, quantity=1):
	if item_name in items:
		items[item_name] += quantity
	else:
		items[item_name] = quantity

func remove_item(item_name, quantity=1):
	if item_name in items and items[item_name] > 0:
		items[item_name] -= quantity
		if items[item_name] <= 0:
			items.erase(item_name)

func has_item(item_name) -> bool:
	return item_name in items

func get_item_count(item_name):
	return items.get(item_name, 0)
