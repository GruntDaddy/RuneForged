extends Node3D
## Runtime bobber + line (solid strand), fish-like surface bob (same defaults as [`WildAnimal`] aquatic), optional cast arc.

const _WaterSurfaceQueries = preload("res://world/water/water_surface_queries.gd")
const _TOOLS_TEX := preload("res://assets/kaykit/items/tools_bits_texture.png")
const _FLOATER_SCENE := preload("res://assets/kaykit/items/fishing_floater.gltf")

@export_group("Cast")
## Share of [`Fishing_Cast`] clip spent on reel-back: bobber stays near the rod tip and follows it (no flight to water).
@export_range(0.05, 0.92, 0.01) var cast_windup_portion: float = 0.52
## During wind-up, bobber sits this far back along the flat cast axis so the line stays readable (toward the angler vs out at sea).
@export var windup_tip_slack_m: float = 0.078
@export var cast_arc_peak_m: float = 0.95
## Lower = bobber reaches the water sooner during the forward cast (relative to release phase duration).
@export_range(0.35, 1.0, 0.01) var cast_release_duration_scale: float = 0.68
## Pull the line attach point toward the bobber (along the cast). Non-zero can leave a gap at the rod tip.
@export var line_tip_inset_m: float = 0.0

@export_group("Line")
@export var line_radius: float = 0.0045
## Solid line color (no texture — avoids dark tint from tools atlas).
@export var line_albedo_color: Color = Color(1.0, 1.0, 1.0, 1.0)

@export_group("Bobber mesh")
@export var use_kaykit_floater: bool = true
@export var floater_mesh_scale: float = 0.75

@export_group("Aquatic bob (wild fish defaults)")
## Raw water sample + offset sets target height (floater sits slightly above plane vs fish body center).
@export var aquatic_surface_vertical_offset: float = 0.034
@export var aquatic_surface_vertical_smoothing: float = 12.0
@export var aquatic_surface_rise_smoothing: float = 2.0
@export var aquatic_max_above_surface_y: float = 0.0
@export var aquatic_min_depth_below_surface_m: float = 0.045
@export var swim_bob_amplitude: float = 0.018
@export var swim_bob_speed: float = 1.6
@export var aquatic_swim_bob_up_fraction: float = 0.0

@export_group("Bite")
@export var bite_dip_depth: float = 0.14
@export var bite_dip_duration_sec: float = 0.42

var _line: MeshInstance3D
var _bobber_root: Node3D
var _bobber_mesh_inst: Node3D

var _active: bool = false
var _casting: bool = false
var _spot_xz: Vector2 = Vector2.ZERO

var _aquatic_smoothed_base_y: float = NAN
var _swim_phase: float = 0.0
var _dip_offset: float = 0.0

var _cast_tween: Tween
var _bite_tween: Tween


func _ready() -> void:
	_ensure_nodes()
	visible = false


func is_line_active() -> bool:
	return _active


func clear_line() -> void:
	_active = false
	_casting = false
	visible = false
	_aquatic_smoothed_base_y = NAN
	_dip_offset = 0.0
	if _cast_tween != null and is_instance_valid(_cast_tween):
		_cast_tween.kill()
		_cast_tween = null
	if _bite_tween != null and is_instance_valid(_bite_tween):
		_bite_tween.kill()
		_bite_tween = null


func cast_out_async(tree: SceneTree, spot_world: Vector3, duration: float, get_rod_tip: Callable) -> void:
	_ensure_nodes()
	if _cast_tween != null and is_instance_valid(_cast_tween):
		_cast_tween.kill()
	if _bite_tween != null and is_instance_valid(_bite_tween):
		_bite_tween.kill()
	_aquatic_smoothed_base_y = NAN
	_dip_offset = 0.0
	_active = true
	_casting = true
	visible = true
	_spot_xz = Vector2(spot_world.x, spot_world.z)

	var land_wh: float = _WaterSurfaceQueries.get_active_water_height_at(tree, spot_world)
	if land_wh <= -1.0e6:
		land_wh = spot_world.y
	var dest := Vector3(spot_world.x, land_wh + aquatic_surface_vertical_offset, spot_world.z)

	var portion := clampf(cast_windup_portion, 0.05, 0.92)
	var wind_dur: float = maxf(0.04, duration * portion)
	var release_dur: float = maxf(
		0.05,
		(duration - wind_dur) * clampf(cast_release_duration_scale, 0.35, 1.0)
	)

	_cast_tween = create_tween()
	_cast_tween.set_parallel(false)
	_cast_tween.tween_method(
		func(_wu: float) -> void:
			var tip: Vector3 = get_rod_tip.call() as Vector3
			var bob := _windup_bobber_position(tip, dest)
			_bobber_root.global_position = bob
			_layout_line_segment(tip, bob),
		0.0,
		1.0,
		wind_dur
	)
	_cast_tween.tween_method(
		func(tt: float) -> void:
			var tip: Vector3 = get_rod_tip.call() as Vector3
			var flat := tip.lerp(dest, tt)
			flat.y += sin(PI * tt) * cast_arc_peak_m
			_bobber_root.global_position = flat
			_layout_line_segment(tip, flat),
		0.0,
		1.0,
		release_dur
	)
	await _cast_tween.finished
	_cast_tween = null
	_casting = false

	_aquatic_smoothed_base_y = NAN
	_swim_phase = randf() * TAU
	_dip_offset = 0.0
	_bobber_root.global_position = Vector3(_spot_xz.x, dest.y, _spot_xz.y)


## Called from [`Player._physics_process`] so bobber Y matches fish-style waves and the line tracks the moving rod tip.
func tick(delta: float, rod_tip_global: Vector3) -> void:
	if not _active or _bobber_root == null or _casting:
		return
	_apply_aquatic_bob(delta)
	_layout_line_segment(rod_tip_global, _bobber_root.global_position)


func play_bite_dip_async() -> void:
	if not _active:
		return
	if _bite_tween != null and is_instance_valid(_bite_tween):
		_bite_tween.kill()
	var half := bite_dip_duration_sec * 0.48
	var up := bite_dip_duration_sec - half
	_bite_tween = create_tween()
	_bite_tween.tween_property(self, "_dip_offset", -bite_dip_depth, half).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	_bite_tween.tween_property(self, "_dip_offset", 0.0, up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _bite_tween.finished
	_bite_tween = null


func _windup_bobber_position(tip: Vector3, dest: Vector3) -> Vector3:
	var flat := Vector3(dest.x - tip.x, 0.0, dest.z - tip.z)
	if flat.length_squared() < 1e-8:
		flat = Vector3(0.001, 0.0, 0.001)
	flat = flat.normalized()
	var slack := maxf(0.0, windup_tip_slack_m)
	return tip - flat * slack


func _apply_aquatic_bob(delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var sample_pos := Vector3(_spot_xz.x, 0.0, _spot_xz.y)
	var raw_h: float = _WaterSurfaceQueries.get_active_water_height_at(tree, sample_pos)
	if raw_h <= -1.0e6:
		raw_h = _bobber_root.global_position.y
	var raw_surface := raw_h + aquatic_surface_vertical_offset
	if is_nan(_aquatic_smoothed_base_y):
		_aquatic_smoothed_base_y = raw_surface
	else:
		var rising := raw_surface > _aquatic_smoothed_base_y + 0.002
		var smooth_rate := aquatic_surface_rise_smoothing if rising else aquatic_surface_vertical_smoothing
		var st := clampf(smooth_rate * delta, 0.0, 1.0)
		_aquatic_smoothed_base_y = lerpf(_aquatic_smoothed_base_y, raw_surface, st)
	_swim_phase += delta * swim_bob_speed
	var sp := sin(_swim_phase)
	var bob := swim_bob_amplitude * (sp if sp < 0.0 else sp * aquatic_swim_bob_up_fraction)
	var y := _aquatic_smoothed_base_y + bob + _dip_offset
	var cap_smoothed := _aquatic_smoothed_base_y + aquatic_max_above_surface_y
	y = minf(y, cap_smoothed)
	var cap_below_sample := raw_h - aquatic_min_depth_below_surface_m
	y = minf(y, cap_below_sample)
	_bobber_root.global_position = Vector3(_spot_xz.x, y, _spot_xz.y)


func _ensure_nodes() -> void:
	if _line != null:
		return
	_line = MeshInstance3D.new()
	_line.name = "Line"
	var cyl := CylinderMesh.new()
	cyl.top_radius = line_radius
	cyl.bottom_radius = line_radius
	cyl.height = 1.0
	_line.mesh = cyl
	var lm := _make_line_material()
	_line.material_override = lm
	add_child(_line)

	_bobber_root = Node3D.new()
	_bobber_root.name = "BobberRoot"
	add_child(_bobber_root)

	if use_kaykit_floater:
		var inst := _FLOATER_SCENE.instantiate() as Node
		_bobber_mesh_inst = inst as Node3D
		if _bobber_mesh_inst != null:
			_bobber_mesh_inst.scale = Vector3.ONE * floater_mesh_scale
			var fm := _make_tools_material()
			_apply_material_recursive(_bobber_mesh_inst, fm)
			_bobber_root.add_child(_bobber_mesh_inst)
	else:
		var bs := SphereMesh.new()
		var r := 0.085
		bs.radius = r
		bs.height = r * 2.0
		var mi := MeshInstance3D.new()
		mi.mesh = bs
		mi.material_override = _make_tools_material()
		_bobber_root.add_child(mi)


func _make_line_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = line_albedo_color
	m.metallic = 0.0
	m.roughness = 0.28
	return m


func _make_tools_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _TOOLS_TEX
	m.roughness = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


func _apply_material_recursive(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_apply_material_recursive(c, mat)


func _layout_line_segment(rod_tip_global: Vector3, bobber_global: Vector3) -> void:
	if _line == null:
		return
	var diff_raw := bobber_global - rod_tip_global
	var len_raw := diff_raw.length()
	if len_raw < 0.002:
		len_raw = 0.002
	var dir := diff_raw / len_raw
	var inset := minf(maxf(line_tip_inset_m, 0.0), len_raw * 0.42)
	var tip_on_line := rod_tip_global + dir * inset
	var diff := bobber_global - tip_on_line
	var length := diff.length()
	if length < 0.002:
		length = 0.002
	var y_axis := diff / length
	var aux := Vector3.UP
	if absf(y_axis.dot(aux)) > 0.92:
		aux = Vector3.RIGHT
	var x_axis := aux.cross(y_axis)
	if x_axis.length_squared() < 1e-8:
		x_axis = Vector3.FORWARD.cross(y_axis)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	var line_basis := Basis(x_axis, y_axis, z_axis)
	var cyl := _line.mesh as CylinderMesh
	if cyl != null:
		cyl.height = length
	_line.global_transform = Transform3D(line_basis, tip_on_line + diff * 0.5)
