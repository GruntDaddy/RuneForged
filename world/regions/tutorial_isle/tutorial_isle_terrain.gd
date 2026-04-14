@tool
extends Terrain3D

## Heightmap import / ocean ring for tutorial isle. Add Terrain3D texture assets in the editor or via assets on this node.

const HEIGHT_MAP := "res://world/regions/tutorial_isle/data/tutorial_isle_height.png"
const EXPORT_COMBINED := "res://world/regions/tutorial_isle/data/tutorial_isle_height_ocean_ring.png"

## Vertical scale for normalized 0–1 height samples (Terrain3D import_images).
@export var height_scale: float = 42.0

## Legacy: import only the 512×512 center heightmap at the origin (single-region-sized image).
@export var import_legacy_center_only_on_enter_tree: bool = false

## Stitched image size: 3× the island tile (512) = 1536 — one ring of ocean shelf around the original island height.
@export var island_tile_px: int = 512
@export var combined_grid_tiles: int = 3

## Ocean shelf: extra depth (normalized 0–1) added with distance from island; scaled by height_scale for world units.
@export var ocean_shelf_depth: float = 0.12
@export var ocean_shelf_falloff_px: float = 180.0
@export var ocean_floor_noise_amp: float = 0.018

## Toggle ON in the inspector to rebuild all regions from the combined heightmap and save to data_directory.
@export var rebuild_ocean_ring_heightmap: bool = false:
	get:
		return false
	set(value):
		if value:
			call_deferred("_rebuild_ocean_ring_heightmap")


func _enter_tree() -> void:
	if import_legacy_center_only_on_enter_tree:
		call_deferred("_import_heightmap_legacy")


func _import_heightmap_legacy() -> void:
	if not ResourceLoader.exists(HEIGHT_MAP):
		push_warning("Tutorial isle: missing heightmap at " + HEIGHT_MAP)
		return
	for region: Terrain3DRegion in data.get_regions_active():
		data.remove_region(region, false)
	data.update_maps(Terrain3DRegion.TYPE_MAX, true, false)

	var img: Image = Terrain3DUtil.load_image(
		HEIGHT_MAP,
		ResourceLoader.CACHE_MODE_IGNORE,
		Vector2(0.0, 1.0),
		Vector2i(island_tile_px, island_tile_px),
	)
	if img == null or img.is_empty():
		push_error("Tutorial isle: could not decode heightmap")
		return
	var layers: Array[Image] = []
	layers.resize(Terrain3DRegion.TYPE_MAX)
	layers[Terrain3DRegion.TYPE_HEIGHT] = img
	data.import_images(layers, Vector3.ZERO, 0.0, height_scale)
	data.calc_height_range(true)
	_save_data_if_possible()


func _rebuild_ocean_ring_heightmap() -> void:
	if not ResourceLoader.exists(HEIGHT_MAP):
		push_error("Tutorial isle: missing heightmap at " + HEIGHT_MAP)
		return

	var island: Image = Terrain3DUtil.load_image(
		HEIGHT_MAP,
		ResourceLoader.CACHE_MODE_IGNORE,
		Vector2(0.0, 1.0),
		Vector2i(island_tile_px, island_tile_px),
	)
	if island == null or island.is_empty():
		push_error("Tutorial isle: could not decode heightmap")
		return

	var combined: Image = _build_combined_height_image(island)
	var err := combined.save_png(EXPORT_COMBINED)
	if err != OK:
		push_warning("Tutorial isle: could not save combined PNG: ", error_string(err))

	for region: Terrain3DRegion in data.get_regions_active():
		data.remove_region(region, false)
	data.update_maps(Terrain3DRegion.TYPE_MAX, true, false)

	var layers: Array[Image] = []
	layers.resize(Terrain3DRegion.TYPE_MAX)
	layers[Terrain3DRegion.TYPE_HEIGHT] = combined
	data.import_images(layers, Vector3.ZERO, 0.0, height_scale)
	data.calc_height_range(true)
	_save_data_if_possible()
	print("Tutorial isle: ocean ring heightmap import finished (", combined.get_width(), "×", combined.get_height(), ").")


func _build_combined_height_image(island: Image) -> Image:
	var tile: int = island_tile_px
	var n: int = combined_grid_tiles
	var total: int = tile * n
	var out := Image.create(total, total, false, island.get_format())

	var mm := Terrain3DUtil.get_min_max(island)
	var island_min: float = mm.x
	var ocean_baseline: float = island_min - ocean_shelf_depth * 0.35

	var noise := FastNoiseLite.new()
	noise.seed = 982451653
	noise.frequency = 0.02
	noise.fractal_octaves = 3

	var half: int = int(floor(float(n) * 0.5))
	var ox := half * tile
	var oy := half * tile

	for py in total:
		for px in total:
			var h: float
			if px >= ox and px < ox + tile and py >= oy and py < oy + tile:
				var ix: int = px - ox
				var iy: int = py - oy
				h = island.get_pixel(ix, iy).r
			else:
				var dist: float = _distance_to_rect(float(px), float(py), float(ox), float(oy), float(ox + tile - 1), float(oy + tile - 1))
				var edge_h: float = _sample_nearest_island_edge(island, ox, oy, tile, px, py)
				var t: float = 1.0 - exp(-dist / maxf(ocean_shelf_falloff_px, 1.0))
				h = lerpf(edge_h, ocean_baseline - ocean_shelf_depth * t, smoothstep(0.0, 1.0, t))
				var nx: float = noise.get_noise_2d(float(px), float(py)) * ocean_floor_noise_amp
				h += nx
				h = clampf(h, 0.0, 1.0)

			out.set_pixel(px, py, Color(h, h, h, 1.0))

	var gen_err := out.generate_mipmaps()
	if gen_err != OK:
		push_warning("Tutorial isle: combined height mipmaps: ", error_string(gen_err))
	return out


func _distance_to_rect(px: float, py: float, min_x: float, min_y: float, max_x: float, max_y: float) -> float:
	var dx: float = 0.0
	if px < min_x:
		dx = min_x - px
	elif px > max_x:
		dx = px - max_x
	var dy: float = 0.0
	if py < min_y:
		dy = min_y - py
	elif py > max_y:
		dy = py - max_y
	return sqrt(dx * dx + dy * dy)


func _sample_nearest_island_edge(island: Image, ox: int, oy: int, tile: int, px: int, py: int) -> float:
	var cx: int = clampi(px, ox, ox + tile - 1)
	var cy: int = clampi(py, oy, oy + tile - 1)
	var ix: int = cx - ox
	var iy: int = cy - oy
	return island.get_pixel(ix, iy).r


func _save_data_if_possible() -> void:
	var dir: String = data_directory
	if dir.is_empty():
		push_warning("Tutorial isle: Terrain3D data_directory is empty; not saving.")
		return
	data.save_directory(dir)
