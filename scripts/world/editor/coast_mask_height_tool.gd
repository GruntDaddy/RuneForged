@tool
extends Terrain3D
## Editor-only: builds a flat **land vs sea** height image from a PNG mask and imports it into Terrain3D.
## Use for an **accurate coastline**; sculpt height detail afterward.
##
## Setup: attach this script to your **Terrain3D** node (e.g. in `main_island.tscn`), assign `mask_image_path`,
## tune threshold / heights, enable **Run import** once, then remove the script or disable it when done.

@export_file("*.png") var mask_image_path: String = "res://assets/world/coast_mask.png"
## If true, sea is brighter than land in your mask (uncommon).
@export var invert_mask: bool = false
## Pixels with luminance **>=** this count as land (0 = black, 1 = white). Ignored if `use_blue_water_heuristic` is on.
@export_range(0.0, 1.0, 0.001) var land_luminance_threshold: float = 0.42
## Prefer water where blue dominates (ocean on your painted map). Disable for a strict grayscale mask.
@export var use_blue_water_heuristic: bool = true
## Stored in the RF height image; final world height also uses `import_scale` and Terrain3D material range.
@export_range(0.0, 1.0, 0.001) var land_height_rf: float = 0.62
@export_range(0.0, 1.0, 0.001) var sea_height_rf: float = 0.38
## Heightmap resolution (width × height). Often 1024 or 2048 per Terrain3D region; match your region plans.
@export var heightmap_size: Vector2i = Vector2i(1024, 1024)
## World-space import origin (XZ). Default (0,0,0); adjust if your regions are offset.
@export var import_position: Vector3 = Vector3.ZERO
@export var height_offset: float = 0.0
@export var import_scale: float = 150.0
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

	var tex: Texture2D = load(mask_image_path) as Texture2D
	if tex == null:
		push_error("CoastMaskHeightTool: could not load: %s" % mask_image_path)
		return

	var src: Image = tex.get_image()
	if src == null:
		push_error("CoastMaskHeightTool: texture has no image data.")
		return

	var w: int = maxi(8, heightmap_size.x)
	var h: int = maxi(8, heightmap_size.y)
	if src.get_width() != w or src.get_height() != h:
		src = src.duplicate()
		src.resize(w, h, Image.Interpolation.INTERPOLATE_CUBIC)

	var out := Image.create(w, h, false, Image.FORMAT_RF)
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			var is_land := _is_land_pixel(c)
			var hf := land_height_rf if is_land else sea_height_rf
			out.set_pixel(x, y, Color(hf, 0.0, 0.0, 1.0))

	if clear_regions_before_import:
		_clear_regions()

	data.import_images([out, null, null], import_position, height_offset, import_scale)
	data.calc_height_range(true)
	print("CoastMaskHeightTool: import finished (%d × %d)." % [w, h])


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
