extends Node

## Loads all `ItemData` `.tres` under `res://data/items/` (recursive). Inventory saves still use string ids only.

var _items: Dictionary = {}  ## id -> ItemData
var _rpg_icon_cache: Dictionary = {}  ## icon filename -> Texture2D
var _warned_missing_icon_for_item: Dictionary = {}  ## item_id -> true

const _RPG_ICON_BY_ITEM_ID := {
	"tool_torch": "I_Torch01.png",
	"tool_torch_burnt": "I_Torch02.png",
	"logs": "I_Rock05.png",
	"logs_oak": "I_Rock04.png",
	"stone": "I_Rock01.png",
	"ore_tin": "I_Rock02.png",
	"ore_copper": "I_Rock03.png",
	"ore_iron": "I_Rock04.png",
	"ore_silver": "I_Rock05.png",
	"ore_gold": "I_Rock06.png",
	"ingot_copper": "I_BronzeBar.png",
	"ingot_tin": "I_BronzeBar.png",
	"ingot_iron": "I_IronBall.png",
	"ingot_silver": "I_SilverBar.png",
	"ingot_gold": "I_GoldBar.png",
	"ingot_bronze": "I_BronzeBar.png",
	"charcoal": "I_Rock01.png",
	"dagger_bronze": "S_Dagger02.png",
	"sword_1h_wooden": "S_Dagger04.png",
	"sword_1h_bronze": "S_Dagger03.png",
	"bow_short_common": "S_Bow04.png",
	"bow_long_common": "S_Bow04.png",
	"ammo_arrow_wood": "S_Bow04.png",
	"ammo_arrow_common": "S_Bow04.png",
	"ammo_arrow_bronze": "S_Bow04.png",
	"ammo_arrow_iron": "S_Bow04.png",
	"hatchet_basic": "S_Axe01.png",
	"hatchet_bronze": "S_Axe02.png",
	"pickaxe_basic": "S_Axe03.png",
	"pickaxe_bronze": "S_Axe04.png",
	"fishing_pole": "S_Bow01.png",
	"tool_hammer": "S_Axe05.png",
	"tool_chisel": "S_Axe06.png",
	"tool_tacklebox": "I_Mirror.png",
	"backpack_large": "I_Mirror.png",
	"backpack_small": "I_Mirror.png",
	"rune_air": "I_Gem03.png",
	"rune_earth": "I_Gem03.png",
	"rune_water": "I_Gem03.png",
	"rune_fire": "I_Ruby.png",
}


func _ready() -> void:
	_index_items_under("res://data/items")
	_run_pickup_scene_audit()


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
					_validate_item_resource(it, p)
		entry_name = d.get_next()


func get_item(id: String) -> ItemData:
	var v: Variant = _items.get(id, null)
	return v as ItemData


func get_item_icon(id: String) -> Texture2D:
	var it: ItemData = get_item(id)
	if it != null and it.icon != null:
		return it.icon
	var icon_file := str(_RPG_ICON_BY_ITEM_ID.get(id, ""))
	if icon_file.is_empty() and id == "oak_logs":
		icon_file = str(_RPG_ICON_BY_ITEM_ID.get("logs_oak", ""))
	if icon_file.is_empty():
		_warn_missing_icon_once(id, "<no mapping in _RPG_ICON_BY_ITEM_ID>")
		return null
	var tex := _load_rpg_icon(icon_file)
	if tex == null:
		_warn_missing_icon_once(id, icon_file)
	return tex


func _load_rpg_icon(icon_file_name: String) -> Texture2D:
	if _rpg_icon_cache.has(icon_file_name):
		return _rpg_icon_cache[icon_file_name] as Texture2D
	var tex_path := "res://data/rpg_icons/%s" % icon_file_name
	if not ResourceLoader.exists(tex_path):
		var import_path := tex_path + ".import"
		if ResourceLoader.exists(import_path):
			var cfg := ConfigFile.new()
			if cfg.load(import_path) == OK:
				var remap_path := str(cfg.get_value("remap", "path", ""))
				if not remap_path.is_empty() and ResourceLoader.exists(remap_path):
					tex_path = remap_path
		if not ResourceLoader.exists(tex_path):
			_rpg_icon_cache[icon_file_name] = null
			return null
	var tex := load(tex_path) as Texture2D
	_rpg_icon_cache[icon_file_name] = tex
	return tex


func _warn_missing_icon_once(item_id: String, expected_icon: String) -> void:
	if item_id.is_empty():
		return
	if _warned_missing_icon_for_item.has(item_id):
		return
	_warned_missing_icon_for_item[item_id] = true
	push_warning(
		"ItemCatalog: missing icon for item '%s' (expected '%s' under res://data/rpg_icons/)." % [
			item_id,
			expected_icon,
		]
	)


func has_id(id: String) -> bool:
	return _items.has(id)


func get_all_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for k in _items.keys():
		out.append(str(k))
	return out


func _validate_item_resource(it: ItemData, source_path: String) -> void:
	if it == null:
		return
	if it.display_name.strip_edges().is_empty():
		push_warning("ItemCatalog: item '%s' has empty display_name (%s)" % [it.id, source_path])
	if it.category in [
		ItemData.Category.TOOL,
		ItemData.Category.WEAPON,
		ItemData.Category.ARMOR,
		ItemData.Category.CLOTHING,
		ItemData.Category.JEWERLY,
		ItemData.Category.RELIC,
		ItemData.Category.RUNE,
	]:
		if it.max_stack != 1:
			push_warning(
				"ItemCatalog: equipment-like item '%s' should use max_stack=1 (found %d) (%s)" % [
					it.id,
					it.max_stack,
					source_path,
				]
			)
	if not it.pickup_scene_path.is_empty() and not ResourceLoader.exists(it.pickup_scene_path):
		push_warning(
			"ItemCatalog: item '%s' pickup_scene_path does not exist: %s (%s)" % [
				it.id,
				it.pickup_scene_path,
				source_path,
			]
		)


func _run_pickup_scene_audit() -> void:
	for item_id in _items.keys():
		var id := str(item_id)
		var it: ItemData = _items.get(id, null) as ItemData
		if it == null:
			continue
		if not _should_expect_pickup_scene(it):
			continue
		if not it.pickup_scene_path.is_empty():
			continue
		push_warning(
			"ItemCatalog: item '%s' is likely world-droppable but has no pickup_scene_path. Add one in its .tres, or keep legacy fallback mapping intentionally." % id
		)


func _should_expect_pickup_scene(it: ItemData) -> bool:
	if it == null:
		return false
	# World resources/material-like loot and explicit placeables should carry drop scenes in data.
	if it.category == ItemData.Category.MATERIAL:
		return true
	for tag in it.tags:
		var t := str(tag)
		if t in ["resource", "ore", "ingot", "wood", "stone", "meat", "hide", "feather", "bone", "torch", "campfire"]:
			return true
	return false
