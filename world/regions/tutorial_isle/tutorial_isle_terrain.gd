@tool
extends Terrain3D

const HEIGHT_MAP := "res://world/regions/tutorial_isle/data/tutorial_isle_height.png"

## Vertical scale for normalized 0–1 height samples (Terrain3D import_images).
@export var height_scale: float = 42.0

## When true, generates simple grass / sand / rock slots and enables Terrain3D autoshader (slope + height blend).
@export var setup_default_texture_layers: bool = true


func _enter_tree() -> void:
	# Editor viewport does not run non-@tool scripts; without @tool the terrain stays flat until Play.
	call_deferred("_import_heightmap_from_png")


func _import_heightmap_from_png() -> void:
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
		Vector2i(512, 512),
	)
	if img == null or img.is_empty():
		push_error("Tutorial isle: could not decode heightmap")
		return
	var layers: Array[Image] = []
	layers.resize(Terrain3DRegion.TYPE_MAX)
	layers[Terrain3DRegion.TYPE_HEIGHT] = img
	data.import_images(layers, Vector3.ZERO, 0.0, height_scale)
	data.calc_height_range(true)
	if setup_default_texture_layers and assets.get_texture_count() == 0:
		_setup_default_texture_layers()
	elif assets.get_texture_count() > 0:
		material.show_checkered = false


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
	# Flat / high areas: grass; lower coastal areas & steep slopes: more sand/rock via autoshader.
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
			# Alpha = height channel for Terrain3D albedo (mid grey = neutral blend).
			c.a = 0.48 + noise.get_noise_2d(float(x) + 30.0, float(y) + 40.0) * 0.06
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _make_flat_normal_roughness(_size: Vector2i) -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	# OpenGL-style normals, roughness in alpha.
	var c := Color(0.5, 0.5, 1.0, 0.55)
	img.fill(c)
	return ImageTexture.create_from_image(img)
