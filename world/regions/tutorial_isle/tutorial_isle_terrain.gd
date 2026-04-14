@tool
extends Terrain3D

## Terrain3D texture indices (see terrain assets on this node): 0 Grass, 1 Sand, 2 Rock, 3 dirt,
## 4 DirtPath, 5 CobblePath — paint 4/5 with the texture tool where you want paths (autoshader handles biome blend).

const HEIGHT_MAP := "res://world/regions/tutorial_isle/data/tutorial_isle_height.png"
const EXPORT_COMBINED := "res://world/regions/tutorial_isle/data/tutorial_isle_height_ocean_ring.png"

## Shared Terrain3D layers (indices 0–5). Albedo + OpenGL normal (nor_gl); roughness tuned per slot.
const _TEX_GRASS_ALBEDO := "res://shared/terrain_textures/forrest_ground/forrest_ground_01_diff_1k.jpg"
const _TEX_GRASS_NORMAL := "res://shared/terrain_textures/forrest_ground/forrest_ground_01_nor_gl_1k.exr"
const _TEX_SAND_ALBEDO := "res://shared/terrain_textures/beach_sand/aerial_beach_01_diff_1k.jpg"
const _TEX_SAND_NORMAL := "res://shared/terrain_textures/beach_sand/aerial_beach_01_nor_gl_1k.exr"
const _TEX_ROCK_ALBEDO := "res://shared/terrain_textures/grey_rocks/gray_rocks_diff_1k.jpg"
const _TEX_ROCK_NORMAL := "res://shared/terrain_textures/grey_rocks/gray_rocks_nor_gl_1k.exr"
const _TEX_DIRT_ALBEDO := "res://shared/terrain_textures/dirt_floor/dirt_floor_diff_1k.jpg"
const _TEX_DIRT_NORMAL := "res://shared/terrain_textures/dirt_floor/dirt_floor_nor_gl_1k.exr"
const _TEX_PATH_ALBEDO := "res://shared/terrain_textures/grass_path/grass_path_2_diff_1k.jpg"
const _TEX_PATH_NORMAL := "res://shared/terrain_textures/grass_path/grass_path_2_nor_gl_1k.exr"
const _TEX_COBBLE_ALBEDO := "res://shared/terrain_textures/river_pebbles/ganges_river_pebbles_diff_1k.jpg"
const _TEX_COBBLE_NORMAL := "res://shared/terrain_textures/river_pebbles/ganges_river_pebbles_nor_gl_1k.exr"

## Vertical scale for normalized 0–1 height samples (Terrain3D import_images).
@export var height_scale: float = 42.0

## When true, assigns Terrain3D texture slots 0–5 from `res://shared/terrain_textures/` at runtime (see constants above).
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


func _ready() -> void:
	call_deferred("_deferred_terrain_polish")


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
		_apply_shared_terrain_textures()
	elif assets.get_texture_count() > 0:
		material.show_checkered = false


func _deferred_terrain_polish() -> void:
	if setup_default_texture_layers:
		_apply_shared_terrain_textures()
	_apply_autoshader_polish()


func _load_tex2d(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_error("Tutorial isle: missing texture: ", path)
		return null
	var res: Resource = load(path)
	if res is Texture2D:
		return res as Texture2D
	push_error("Tutorial isle: not a Texture2D: ", path)
	return null


func _build_texture_asset(
	p_name: String,
	p_id: int,
	albedo_path: String,
	normal_path: String,
	uv_scale: float,
	roughness: float,
) -> Terrain3DTextureAsset:
	var alb := _load_tex2d(albedo_path)
	var nrm := _load_tex2d(normal_path)
	if alb == null or nrm == null:
		return null
	var ta := Terrain3DTextureAsset.new()
	ta.name = p_name
	ta.id = p_id
	ta.albedo_texture = alb
	ta.normal_texture = nrm
	ta.uv_scale = uv_scale
	ta.roughness = roughness
	return ta


func _apply_shared_terrain_textures() -> void:
	if assets == null or material == null:
		return
	var grass := _build_texture_asset("Grass", 0, _TEX_GRASS_ALBEDO, _TEX_GRASS_NORMAL, 0.14, 0.08)
	var sand := _build_texture_asset("Sand", 1, _TEX_SAND_ALBEDO, _TEX_SAND_NORMAL, 0.18, 0.12)
	var rock := _build_texture_asset("Rock", 2, _TEX_ROCK_ALBEDO, _TEX_ROCK_NORMAL, 0.12, 0.22)
	var dirt := _build_texture_asset("dirt", 3, _TEX_DIRT_ALBEDO, _TEX_DIRT_NORMAL, 0.16, 0.85)
	var dirt_path := _build_texture_asset("DirtPath", 4, _TEX_PATH_ALBEDO, _TEX_PATH_NORMAL, 0.2, 0.14)
	var cobble := _build_texture_asset("CobblePath", 5, _TEX_COBBLE_ALBEDO, _TEX_COBBLE_NORMAL, 0.14, 0.2)
	for ta in [grass, sand, rock, dirt, dirt_path, cobble]:
		if ta == null:
			push_error("Tutorial isle: failed to build one or more Terrain3D texture assets.")
			return
	assets.set_texture(0, grass)
	assets.set_texture(1, sand)
	assets.set_texture(2, rock)
	assets.set_texture(3, dirt)
	assets.set_texture(4, dirt_path)
	assets.set_texture(5, cobble)
	assets.update_texture_list()
	material.show_checkered = false


func _apply_autoshader_polish() -> void:
	if material == null:
		return
	material.auto_shader = true
	material.set_shader_param(&"auto_base_texture", 0)
	material.set_shader_param(&"auto_overlay_texture", 1)
	material.set_shader_param(&"auto_slope", 2.35)
	material.set_shader_param(&"auto_height_reduction", 0.34)
	material.set_shader_param(&"blend_sharpness", 0.58)
	material.set_shader_param(&"macro_variation_slope", 0.28)
	material.set_shader_param(&"macro_variation1", Color(0.97, 0.99, 0.95))
	material.set_shader_param(&"macro_variation2", Color(0.94, 0.96, 1.0))


func _save_data_if_possible() -> void:
	var dir: String = data_directory
	if dir.is_empty():
		push_warning("Tutorial isle: Terrain3D data_directory is empty; not saving.")
		return
	data.save_directory(dir)
