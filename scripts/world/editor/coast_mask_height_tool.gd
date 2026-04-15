@tool
extends Terrain3D
## Editor-only: builds a flat **land vs sea** height image from a PNG mask and imports it into Terrain3D.
## Use for an **accurate coastline**; sculpt height detail afterward.
##
## Setup: attach this script to your **Terrain3D** node (e.g. in `main_island.tscn`), assign `mask_image_path`,
## tune threshold / heights, enable **Run import** once, then remove the script or disable it when done.

@export_file("*.png") var mask_image_path: String = "res://assets/world/coast_mask.png"
## Must match Terrain3D region size (meters per side). The official demo uses **1024** with a **2048×2048** height image.
@export_range(64, 4096, 1) var region_size_meters: int = 1024
## If true, sea is brighter than land in your mask (uncommon).
@export var invert_mask: bool = false
## Pixels with luminance **>=** this count as land (0 = black, 1 = white). Used when `use_blue_water_heuristic` is off.
@export_range(0.0, 1.0, 0.001) var land_luminance_threshold: float = 0.42
## If on, treats “bluer than green/red” as ocean. **Mis-classifies forests/deserts/lava** — use only for quick tests, or export a **black/white land mask** and leave this **off**.
@export var use_blue_water_heuristic: bool = false
## Normalized height samples (0–1). Keep land/sea **close** so the coast step stays small; `import_scale` turns this into world meters.
@export_range(0.0, 1.0, 0.001) var land_height_rf: float = 0.55
@export_range(0.0, 1.0, 0.001) var sea_height_rf: float = 0.45
## Heightmap pixel size. Leave at **0,0** to use **2 × region_size** per side (matches `addons/terrain_3d/demo` CodeGenerated). Nonzero overrides.
@export var heightmap_size: Vector2i = Vector2i.ZERO
## World-space import origin (XZ). The demo uses **(-region_size, 0, -region_size)** so one region lines up with the height image.
@export var import_position: Vector3 = Vector3(-1024, 0, -1024)
@export var height_offset: float = 0.0
## Multiplies normalized height into meters. **150** makes even a 0.1 RF gap ≈ **15 m cliffs**. Use **10–40** for a gentle coast step while sculpting later.
@export var import_scale: float = 25.0
## Sets `Terrain3DMaterial.world_background` to **NONE** after import so you do not get a giant flat/noise “infinite ground” plane behind the region.
@export var set_world_background_none: bool = true
## Sets `import_position` to **(-region_size_meters, 0, -region_size_meters)** (matches Terrain3D demo import alignment).
@export var auto_align_import_origin: bool = true
## Clears existing Terrain3D regions before import (recommended when re-baking the mask).
@export var clear_regions_before_import: bool = true
@export var run_import: bool = false:
	set = _set_run_import


func _set_run_import(value: bool) -> void:
	if not value:
		return
	if not Engine.is_editor_hint():
		push_warning("CoastMaskHeightTool: import only runs in the editor.")
		call_deferred("set", "run_import", false)
		return
	_run_import()
	call_deferred("set", "run_import", false)


func _run_import() -> void:
	if mask_image_path.is_empty():
		push_error("CoastMaskHeightTool: set `mask_image_path` to a PNG (land vs water).")
		return
	if data == null:
		push_error("CoastMaskHeightTool: Terrain3D `data` is null.")
		return

	# Terrain3D exposes region_size as an enum in the inspector; int assignment satisfies the engine at runtime.
	set("region_size", maxi(64, region_size_meters))

	var tex: Texture2D = load(mask_image_path) as Texture2D
	if tex == null:
		push_error("CoastMaskHeightTool: could not load: %s" % mask_image_path)
		return

	var src: Image = tex.get_image()
	if src == null:
		push_error("CoastMaskHeightTool: texture has no image data.")
		return

	var w: int
	var h: int
	if heightmap_size.x > 0 and heightmap_size.y > 0:
		w = heightmap_size.x
		h = heightmap_size.y
	else:
		# Terrain3D demo uses 2048×2048 for a 1024 m region (2× region size).
		w = region_size_meters * 2
		h = region_size_meters * 2

	src = src.duplicate()
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)

	if src.get_width() != w or src.get_height() != h:
		src.resize(w, h, Image.Interpolation.INTERPOLATE_CUBIC)

	var out := Image.create(w, h, false, Image.FORMAT_RF)
	var land_count: int = 0
	var sea_count: int = 0
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			var is_land := _is_land_pixel(c)
			if is_land:
				land_count += 1
			else:
				sea_count += 1
			var hf := land_height_rf if is_land else sea_height_rf
			out.set_pixel(x, y, Color(hf, 0.0, 0.0, 1.0))

	var total: int = max(1, land_count + sea_count)
	var land_pct: float = 100.0 * float(land_count) / float(total)
	print("CoastMaskHeightTool: land pixels %.1f%% (%d), sea %.1f%% (%d)." % [land_pct, land_count, 100.0 - land_pct, sea_count])
	if land_pct < 0.5 or land_pct > 99.5:
		push_warning("CoastMaskHeightTool: almost all land or all sea — check mask, invert_mask, or use_blue_water_heuristic / threshold.")

	if clear_regions_before_import:
		_clear_regions()

	var pos := import_position
	if auto_align_import_origin:
		pos = Vector3(float(-region_size_meters), 0.0, float(-region_size_meters))

	data.import_images([out, null, null], pos, height_offset, import_scale)
	data.calc_height_range(true)

	if set_world_background_none and material != null:
		material.world_background = Terrain3DMaterial.NONE

	print("CoastMaskHeightTool: import finished (%d × %d), region_size=%d, import_pos=%s, import_scale=%.2f." % [w, h, region_size_meters, pos, import_scale])


func _is_land_pixel(c: Color) -> bool:
	if use_blue_water_heuristic:
		# Ocean is usually more blue than green/red; land is green/brown/tan.
		var is_water := c.b > c.g + 0.08 and c.b > c.r + 0.08
		var is_land := not is_water
		return not is_land if invert_mask else is_land

	var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	var is_land_lum := lum >= land_luminance_threshold
	return not is_land_lum if invert_mask else is_land_lum


func _clear_regions() -> void:
	for region: Terrain3DRegion in data.get_regions_active():
		data.remove_region(region, false)
	data.update_maps(Terrain3DRegion.TYPE_MAX, true, false)
