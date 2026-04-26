extends Node

## Loads all `ItemData` `.tres` under `res://data/items/` (recursive). Inventory saves still use string ids only.

var _items: Dictionary = {}  ## id -> ItemData
var _rpg_icon_cache: Dictionary = {}  ## import filename -> Texture2D

const _RPG_ICON_BY_ITEM_ID := {
	"tool_torch": "I_Torch01.png.import",
	"tool_torch_burnt": "I_Torch02.png.import",
	"logs": "I_Rock05.png.import",
	"logs_oak": "I_Rock04.png.import",
	"stone": "I_Rock01.png.import",
	"ore_tin": "I_Rock02.png.import",
	"ore_copper": "I_Rock03.png.import",
	"ingot_bronze": "I_SilverBar.png.import",
	"dagger_bronze": "S_Dagger02.png.import",
	"sword_1h_wooden": "S_Dagger04.png.import",
	"sword_1h_bronze": "S_Dagger03.png.import",
	"hatchet_basic": "S_Axe01.png.import",
	"hatchet_bronze": "S_Axe02.png.import",
	"pickaxe_basic": "S_Axe03.png.import",
	"pickaxe_bronze": "S_Axe04.png.import",
	"fishing_pole": "S_Bow01.png.import",
	"tool_hammer": "S_Axe05.png.import",
	"tool_chisel": "S_Axe06.png.import",
	"tool_tacklebox": "I_Mirror.png.import",
}


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


func get_item_icon(id: String) -> Texture2D:
	var it: ItemData = get_item(id)
	if it != null and it.icon != null:
		return it.icon
	var icon_import := str(_RPG_ICON_BY_ITEM_ID.get(id, ""))
	if icon_import.is_empty() and id == "oak_logs":
		icon_import = str(_RPG_ICON_BY_ITEM_ID.get("logs_oak", ""))
	if icon_import.is_empty():
		return null
	return _load_rpg_icon_from_import(icon_import)


func _load_rpg_icon_from_import(import_file_name: String) -> Texture2D:
	if _rpg_icon_cache.has(import_file_name):
		return _rpg_icon_cache[import_file_name] as Texture2D
	var import_path := "res://data/rpg_icons/%s" % import_file_name
	if not ResourceLoader.exists(import_path):
		_rpg_icon_cache[import_file_name] = null
		return null
	var cfg := ConfigFile.new()
	if cfg.load(import_path) != OK:
		_rpg_icon_cache[import_file_name] = null
		return null
	var tex_path := str(cfg.get_value("remap", "path", ""))
	if tex_path.is_empty() or not ResourceLoader.exists(tex_path):
		_rpg_icon_cache[import_file_name] = null
		return null
	var tex := load(tex_path) as Texture2D
	_rpg_icon_cache[import_file_name] = tex
	return tex


func has_id(id: String) -> bool:
	return _items.has(id)


func get_all_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for k in _items.keys():
		out.append(str(k))
	return out
