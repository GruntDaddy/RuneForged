@tool
extends Terrain3D

const HEIGHT_MAP := "res://world/regions/tutorial_isle/data/tutorial_isle_height.png"
const EXPORT_COMBINED := "res://world/regions/tutorial_isle/data/tutorial_isle_height_ocean_ring.png"

## Vertical scale for normalized 0–1 height samples (Terrain3D import_images).
@export var height_scale: float = 42.0

## When true, generates simple grass / sand / rock slots and enables Terrain3D autoshader (slope + height blend).
@export var setup_default_texture_layers: bool = true

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
	_finish_texture_setup()
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
	_finish_texture_setup()
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


func _finish_texture_setup() -> void:
	if setup_default_texture_layers and assets.get_texture_count() == 0:
		_setup_default_texture_layers()
	elif assets.get_texture_count() > 0:
		material.show_checkered = false


func _save_data_if_possible() -> void:
	var dir: String = data_directory
	if dir.is_empty():
		push_warning("Tutorial isle: Terrain3D data_directory is empty; not saving.")
		return
	data.save_directory(dir)


func _setup_default_texture_layers() -> void:
	if assets == null or material == null:
		return
	var albedo_size := Vector2i(128, 128)
	var grass_albedo := _make_noise_albedo(Color(0.22, 0.48, 0.18), Color(0.32, 0.58, 0.22), 1)
	var sand_albedo := _make_noise_albedo(Color(0.72, 0.62, 0.42), Color(0.82, 0.72, 0.52), 2)
	var rock_albedo := _make_noise_albedo(Color(0.28, 0.27, 0.26), Color(0.4, 0.38, 0.36), 3)
	var flat_normal := _make_flat_normal_roughness(albedo_size)

	var grass := Terrain3DTextureAsset.new()
	grass.name = "Grass"
	grass.id = 0
	grass.albedo_texture = grass_albedo
	grass.normal_texture = flat_normal
	grass.uv_scale = 0.14
	grass.roughness = 0.08

	var sand := Terrain3DTextureAsset.new()
	sand.name = "Sand"
	sand.id = 1
	sand.albedo_texture = sand_albedo
	sand.normal_texture = flat_normal
	sand.uv_scale = 0.18
	sand.roughness = 0.12

	var rock := Terrain3DTextureAsset.new()
	rock.name = "Rock"
	rock.id = 2
	rock.albedo_texture = rock_albedo
	rock.normal_texture = flat_normal
	rock.uv_scale = 0.12
	rock.roughness = 0.22

	assets.set_texture(0, grass)
	assets.set_texture(1, sand)
	assets.set_texture(2, rock)
	assets.update_texture_list()

	material.show_checkered = false
	material.auto_shader = true
	material.set_shader_param(&"auto_base_texture", 0)
	material.set_shader_param(&"auto_overlay_texture", 1)
	material.set_shader_param(&"auto_slope", 2.4)
	material.set_shader_param(&"auto_height_reduction", 0.42)


func _make_noise_albedo(c0: Color, c1: Color, noise_seed: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = 0.09
	noise.fractal_octaves = 4
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var n: float = noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var c: Color = c0.lerp(c1, n)
			c.a = 0.48 + noise.get_noise_2d(float(x) + 30.0, float(y) + 40.0) * 0.06
			img.set_pixel(x, y, c)
	return _image_texture_with_mipmaps(img)


func _make_flat_normal_roughness(_size: Vector2i) -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var c := Color(0.5, 0.5, 1.0, 0.55)
	img.fill(c)
	return _image_texture_with_mipmaps(img)


func _image_texture_with_mipmaps(img: Image) -> ImageTexture:
	var err := img.generate_mipmaps()
	if err != OK:
		push_warning("Tutorial isle: generate_mipmaps failed: ", error_string(err))
	var tex := ImageTexture.new()
	tex.set_image(img)
	return tex
