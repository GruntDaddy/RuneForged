extends Node3D
## Drives sun/moon sky shader, DirectionalLight3D, and ambient for a full day-night cycle.
## Expects a sibling DirectionalLight3D and WorldEnvironment (paths configurable).

## Full cycle duration in seconds (e.g. 90 for fast testing, 900 for fifteen minutes).
@export var day_length_seconds: float = 900.0
@export_range(0.0, 1.0) var start_time_of_day: float = 0.32

@export_group("Light")
@export var sun_energy_max: float = 0.85
@export var moon_light_energy: float = 0.22
@export var sun_color_day: Color = Color(1.0, 0.97, 0.88)
@export var sun_color_sunset: Color = Color(1.0, 0.62, 0.38)
@export var moon_light_color: Color = Color(0.52, 0.62, 0.92)

@export_group("Ambient")
@export var ambient_energy_day: float = 0.5
@export var ambient_energy_night: float = 0.22
@export var ambient_color_day: Color = Color(0.45, 0.52, 0.58)
@export var ambient_color_night: Color = Color(0.16, 0.18, 0.28)

@export_group("Fog")
@export var fog_enabled: bool = true
## Base fog density (exponential mode); night lerps toward higher density for depth.
@export_range(0.0, 0.2, 0.0001) var fog_density_day: float = 0.038
@export_range(0.0, 0.2, 0.0001) var fog_density_night: float = 0.062
@export var fog_light_color_day: Color = Color(0.55, 0.72, 0.82, 1)
@export var fog_light_color_sunset: Color = Color(0.85, 0.58, 0.42, 1)
@export var fog_light_color_night: Color = Color(0.12, 0.14, 0.22, 1)
@export_range(0.0, 1.0, 0.01) var fog_sky_affect_day: float = 0.42
@export_range(0.0, 1.0, 0.01) var fog_sky_affect_night: float = 0.72

@export_group("Underwater fog")
## Applied when the player reports submerged camera; wins over surface day/night fog for that frame.
@export_range(0.0, 0.2, 0.0001) var underwater_fog_density_min: float = 0.028
@export_range(0.0, 0.2, 0.0001) var underwater_fog_density_max: float = 0.085
@export var underwater_fog_light_color: Color = Color(0.12, 0.38, 0.42, 1)
@export_range(0.0, 1.0, 0.01) var underwater_fog_sky_affect: float = 0.55

@export_group("Sky shader (optional)")
## When true, boosts moon rim strength toward night so the moon reads better against the dark sky.
@export var drive_sky_night_visuals: bool = false
@export_range(0.0, 1.0, 0.01) var sky_moon_rim_night_max: float = 0.15
@export var drive_sky_aurora: bool = true
@export_range(0.0, 1.0, 0.01) var aurora_intensity_day: float = 0.0
@export_range(0.0, 2.0, 0.01) var aurora_intensity_night: float = 0.05
@export_group("Moon phase")
## Extra yaw (degrees) around world up, applied after placing the moon opposite the sun.
## Keep near 0 so the moon rises ~when the sun sets; large values break that pairing.
@export_range(-45.0, 45.0, 0.1) var moon_orbit_offset_deg: float = 0.0
@export_range(1.0, 60.0, 0.1) var moon_phase_days: float = 12.0
@export_range(0.0, 1.0, 0.001) var start_moon_phase: float = 0.18
@export_group("Sky tuning")
@export var apply_stylized_sky_preset: bool = true
@export_range(0.001, 0.06, 0.0001) var moon_disk_size_target: float = 0.0005
@export_range(0.0, 2.5, 0.01) var star_brightness_target: float = 1.08
@export var star_density_uv_target: Vector2 = Vector2(365.0, 192.0)
@export_range(0.02, 0.35, 0.001) var star_point_size_target: float = 0.018
@export var milky_way_enabled_target: bool = true
@export_range(0.0, 2.0, 0.01) var milky_way_intensity_target: float = 0.12
@export_range(0.02, 1.0, 0.01) var milky_way_width_target: float = 0.075
@export var aurora_enabled_target: bool = true
@export_range(0.0, 1.0, 0.01) var aurora_band_height_target: float = 0.23
@export_range(0.01, 0.5, 0.01) var aurora_band_softness_target: float = 0.06
@export_group("Persistence")
@export var persist_time_to_game_state: bool = true
@export var persist_moon_phase_to_game_state: bool = true

@export_group("Nodes")
@export var directional_light_path: NodePath = ^"../DirectionalLight3D"
@export var world_environment_path: NodePath = ^"../WorldEnvironment"

var _time_of_day: float = 0.32
var _sky_material: ShaderMaterial
var _moon_phase: float = 0.18
var _underwater_fog_active: bool = false
var _underwater_fog_depth_t: float = 0.0


func set_underwater_fog_override(active: bool, depth_t: float) -> void:
	_underwater_fog_active = active
	_underwater_fog_depth_t = clampf(depth_t, 0.0, 1.0)


func _ready() -> void:
	_time_of_day = start_time_of_day
	_moon_phase = start_moon_phase
	var we: WorldEnvironment = get_node_or_null(world_environment_path) as WorldEnvironment
	if we != null and we.environment != null:
		var sky: Sky = we.environment.sky
		if sky != null and sky.sky_material is ShaderMaterial:
			_sky_material = sky.sky_material
	_spawn_saved_fire_props()
	_load_persisted_cycle_state()
	_apply_time()


func _process(delta: float) -> void:
	if day_length_seconds <= 0.001:
		return
	_time_of_day = fmod(_time_of_day + delta / day_length_seconds, 1.0)
	var phase_len: float = maxf(1.0, moon_phase_days) * day_length_seconds
	_moon_phase = fmod(_moon_phase + delta / phase_len, 1.0)
	_apply_time()
	_store_cycle_state()


func set_time_of_day(t: float) -> void:
	_time_of_day = fmod(clampf(t, 0.0, 0.999999), 1.0)
	_apply_time()


func get_time_of_day() -> float:
	return _time_of_day


func _sun_direction() -> Vector3:
	# 0.25 ≈ sunrise, 0.5 ≈ noon, 0.75 ≈ sunset; slight Z sway for depth
	var angle: float = (_time_of_day - 0.25) * TAU
	return Vector3(-cos(angle), sin(angle), -sin(angle) * 0.28).normalized()


func _moon_direction(sun_dir: Vector3) -> Vector3:
	# Sky position: opposite the sun so at sunset the moon is on the opposite horizon (full-moon style).
	var opposite: Vector3 = -sun_dir
	if absf(moon_orbit_offset_deg) < 0.001:
		return opposite.normalized()
	var axis := Vector3(0.0, 1.0, 0.0)
	return opposite.rotated(axis, deg_to_rad(moon_orbit_offset_deg)).normalized()


func _load_persisted_cycle_state() -> void:
	if not persist_time_to_game_state and not persist_moon_phase_to_game_state:
		return
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	if persist_time_to_game_state and "time_of_day" in gs:
		_time_of_day = clampf(float(gs.time_of_day), 0.0, 0.999999)
	if persist_moon_phase_to_game_state and "moon_phase" in gs:
		_moon_phase = clampf(float(gs.moon_phase), 0.0, 0.999999)


func _store_cycle_state() -> void:
	if not persist_time_to_game_state and not persist_moon_phase_to_game_state:
		return
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	if persist_time_to_game_state and "time_of_day" in gs:
		gs.time_of_day = _time_of_day
	if persist_moon_phase_to_game_state and "moon_phase" in gs:
		gs.moon_phase = _moon_phase


func _spawn_saved_fire_props() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or not ("placed_fire_nodes" in gs):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var region: String = String(gs.region) if "region" in gs else ""
	if region.is_empty():
		return
	var entries: Array = gs.placed_fire_nodes
	for e in entries:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = e
		if String(d.get("region", "")) != region:
			continue
		var state_id: String = String(d.get("state_id", ""))
		if state_id.is_empty():
			continue
		if _scene_has_fire_id(scene, state_id):
			continue
		var path: String = String(d.get("scene_path", ""))
		if path.is_empty():
			continue
		var packed: Resource = load(path)
		if not (packed is PackedScene):
			continue
		var node: Node = (packed as PackedScene).instantiate()
		if not (node is Node3D):
			continue
		scene.add_child(node)
		var node3d := node as Node3D
		var pos_v: Variant = d.get("position", [])
		if typeof(pos_v) == TYPE_ARRAY:
			var pa: Array = pos_v
			if pa.size() >= 3:
				node3d.global_position = Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
		node3d.rotation.y = float(d.get("rotation_y", 0.0))
		if "fire_state_id" in node3d:
			node3d.fire_state_id = state_id


func _scene_has_fire_id(scene: Node, fire_id: String) -> bool:
	for c in scene.get_children():
		if c is Node3D and "fire_state_id" in c and String(c.fire_state_id) == fire_id:
			return true
	return false


func _apply_time() -> void:
	var sun_dir: Vector3 = _sun_direction()
	var moon_dir: Vector3 = _moon_direction(sun_dir)
	var height: float = sun_dir.y
	var day_f: float = smoothstep(-0.12, 0.22, height)
	var sunset_f: float = smoothstep(0.02, 0.22, height) * (1.0 - smoothstep(0.12, 0.42, height))
	sunset_f = clampf(sunset_f * 1.35, 0.0, 1.0)

	var dl: DirectionalLight3D = get_node_or_null(directional_light_path) as DirectionalLight3D
	if dl != null:
		# Day: light from sun direction. Night: slerp toward moon direction so moonlit side gets cool fill.
		var anchor: Vector3 = dl.global_position
		var moon_influence: float = 1.0 - smoothstep(0.08, 0.42, day_f)
		var lit_dir: Vector3 = sun_dir.slerp(moon_dir, moon_influence)
		if lit_dir.length_squared() < 1e-10:
			lit_dir = sun_dir
		else:
			lit_dir = lit_dir.normalized()
		dl.look_at(anchor - lit_dir, Vector3.UP)

		var e: float = lerpf(moon_light_energy, sun_energy_max, day_f)
		dl.light_energy = e
		var c: Color = moon_light_color.lerp(sun_color_day, day_f)
		c = c.lerp(sun_color_sunset, sunset_f * (1.0 - day_f * 0.35) * clampf(day_f * 1.5, 0.0, 1.0))
		dl.light_color = c

	if _sky_material != null:
		if apply_stylized_sky_preset:
			_sky_material.set_shader_parameter(&"moon_disk_size", moon_disk_size_target)
			_sky_material.set_shader_parameter(&"star_brightness", star_brightness_target)
			_sky_material.set_shader_parameter(&"star_density_uv", star_density_uv_target)
			_sky_material.set_shader_parameter(&"star_point_size", star_point_size_target)
			_sky_material.set_shader_parameter(&"milky_way_enabled", milky_way_enabled_target)
			_sky_material.set_shader_parameter(&"milky_way_intensity", milky_way_intensity_target)
			_sky_material.set_shader_parameter(&"milky_way_width", milky_way_width_target)
			_sky_material.set_shader_parameter(&"aurora_enabled", aurora_enabled_target)
			_sky_material.set_shader_parameter(&"aurora_band_height", aurora_band_height_target)
			_sky_material.set_shader_parameter(&"aurora_band_softness", aurora_band_softness_target)
		_sky_material.set_shader_parameter(&"sun_direction", sun_dir)
		_sky_material.set_shader_parameter(&"moon_direction", moon_dir)
		_sky_material.set_shader_parameter(&"day_factor", day_f)
		_sky_material.set_shader_parameter(&"sunset_factor", sunset_f)
		_sky_material.set_shader_parameter(&"moon_phase", _moon_phase)
		var night_amt: float = 1.0 - day_f
		var rim_target: float = 0.0
		if drive_sky_night_visuals:
			rim_target = sky_moon_rim_night_max
		_sky_material.set_shader_parameter(
			&"moon_rim_strength",
			lerpf(0.0, rim_target, smoothstep(0.12, 0.9, night_amt))
		)
		if drive_sky_aurora:
			_sky_material.set_shader_parameter(
				&"aurora_intensity",
				lerpf(aurora_intensity_day, aurora_intensity_night, smoothstep(0.52, 1.0, night_amt))
			)

	var we: WorldEnvironment = get_node_or_null(world_environment_path) as WorldEnvironment
	if we != null and we.environment != null:
		var env: Environment = we.environment
		env.ambient_light_energy = lerpf(ambient_energy_night, ambient_energy_day, day_f)
		env.ambient_light_color = ambient_color_night.lerp(ambient_color_day, day_f)
		if _underwater_fog_active:
			env.fog_enabled = true
			env.fog_light_color = underwater_fog_light_color
			env.fog_density = lerpf(
				underwater_fog_density_min, underwater_fog_density_max, _underwater_fog_depth_t
			)
			env.fog_sky_affect = underwater_fog_sky_affect
		elif fog_enabled:
			env.fog_enabled = true
			var fog_color: Color = fog_light_color_night.lerp(fog_light_color_day, day_f)
			fog_color = fog_color.lerp(fog_light_color_sunset, sunset_f * clampf(1.0 - day_f * 0.5, 0.0, 1.0))
			env.fog_light_color = fog_color
			env.fog_density = lerpf(fog_density_night, fog_density_day, day_f)
			env.fog_sky_affect = lerpf(fog_sky_affect_night, fog_sky_affect_day, day_f)
		else:
			env.fog_enabled = false
