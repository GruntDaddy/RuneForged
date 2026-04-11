extends Node

## Loads all `ItemData` `.tres` under `res://data/items/` (recursive). Inventory saves still use string ids only.

var _items: Dictionary = {}  ## id -> ItemData


func _ready() -> void:
	_index_items_under("res://data/items")


func _index_items_under(dir_path: String) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		push_warning("ItemCatalog: cannot open %s" % dir_path)
		return
	d.list_dir_begin()
	var entry_name: String = d.get_next()
	while entry_name != "":
		if not entry_name.begins_with("."):
			var p: String = dir_path.path_join(entry_name)
			if d.current_is_dir():
				_index_items_under(p)
			elif entry_name.ends_with(".tres"):
				var res: Resource = ResourceLoader.load(p)
				if res is ItemData:
					var it: ItemData = res as ItemData
					if it.id.is_empty():
						push_warning("ItemCatalog: empty id in %s" % p)
					else:
						if _items.has(it.id):
							push_warning("ItemCatalog: duplicate id '%s' (%s)" % [it.id, p])
						_items[it.id] = it
		entry_name = d.get_next()


func get_item(id: String) -> ItemData:
	var v: Variant = _items.get(id, null)
	return v as ItemData


func has_id(id: String) -> bool:
	return _items.has(id)


func get_all_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for k in _items.keys():
		out.append(str(k))
	return out
