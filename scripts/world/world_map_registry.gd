class_name WorldMapRegistry
extends RefCounted

## Loads [`data/world/world_regions.json`](data/world/world_regions.json) (normalized UV hit rects).
## Regions are tested in array order; put broad areas like `OCEAN` last.

const REGIONS_JSON_PATH := "res://data/world/world_regions.json"

var _regions: Array = []
var _loaded: bool = false


func load_regions() -> Array:
	if _loaded:
		return _regions
	_loaded = true
	if not FileAccess.file_exists(REGIONS_JSON_PATH):
		push_error("WorldMapRegistry: missing %s" % REGIONS_JSON_PATH)
		return _regions
	var text := FileAccess.get_file_as_string(REGIONS_JSON_PATH)
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("WorldMapRegistry: invalid JSON in %s" % REGIONS_JSON_PATH)
		return _regions
	var d: Dictionary = data
	_regions = d.get("regions", [])
	return _regions


func get_all() -> Array:
	return load_regions()


func get_region_at_normalized(uv: Vector2) -> Dictionary:
	var regions: Array = load_regions()
	for r in regions:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var rect_arr: Array = r.get("map_uv_rect", [])
		if rect_arr.size() < 4:
			continue
		var rect := Rect2(
			float(rect_arr[0]),
			float(rect_arr[1]),
			float(rect_arr[2]),
			float(rect_arr[3])
		)
		if rect.has_point(uv):
			return r
	return {}


func reload_for_editor() -> void:
	_loaded = false
	_regions.clear()
	load_regions()
