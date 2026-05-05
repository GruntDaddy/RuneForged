extends Node
## Per-region coordinator: visibility fade + cull distance + simulation LOD tiers for `wildlife_lod` vs anchor (usually Player).
##
## Units are Godot world units (1 ≈ 1 m). See exports on this node for distance bands.

@export var lod_anchor_path: NodePath = NodePath("../Player")
## Within this radius → full movement + full AI tick rate (when [member WildAnimal.use_simulation_lod]).
@export var full_sim_radius: float = 52.0
## Outer edge of low-cost band: between full and this → slower AI/movement; beyond → frozen idle.
@export var low_sim_radius: float = 105.0
## Past this distance → hidden, collision off, physics disabled (0 = use multiplier × low_sim_radius).
@export var hide_beyond_radius: float = 150.0
## When hide_beyond_radius is 0: hide distance = low_sim_radius × this (legacy auto, very far).
@export var hide_distance_multiplier: float = 3.0
## Over this span before hide, mesh fades via [member GeometryInstance3D.transparency] (0 = no fade).
@export var fade_band_meters: float = 25.0
## How often simulation tier (full/low/frozen) is reassigned; visibility + fade run every frame.
@export var tier_update_interval_sec: float = 0.12

var _anchor: Node3D
var _tier_tick_accum: float = 0.0


func _ready() -> void:
	_resolve_anchor()


func _process(_delta: float) -> void:
	if not is_instance_valid(_anchor):
		_resolve_anchor()
	if _anchor == null:
		return

	_tier_tick_accum += _delta
	var apply_tiers := _tier_tick_accum >= maxf(0.016, tier_update_interval_sec)
	if apply_tiers:
		_tier_tick_accum = 0.0

	var ax := _anchor.global_position
	var full_r2 := maxf(0.01, full_sim_radius * full_sim_radius)
	var low_r2 := maxf(full_r2 + 0.01, low_sim_radius * low_sim_radius)

	var hide_dist := hide_beyond_radius
	if hide_dist <= 0.0 and hide_distance_multiplier > 0.0:
		hide_dist = low_sim_radius * hide_distance_multiplier

	var hide_r2 := -1.0
	var fade_start_r2 := -1.0
	if hide_dist > 0.0:
		hide_r2 = hide_dist * hide_dist
		if fade_band_meters > 0.0:
			var fade_start_dist := maxf(0.01, hide_dist - fade_band_meters)
			fade_start_r2 = fade_start_dist * fade_start_dist

	for n in get_tree().get_nodes_in_group(&"wildlife_lod"):
		if not is_instance_valid(n):
			continue
		if not (n is WildAnimal):
			continue
		var wa := n as WildAnimal
		var d2 := ax.distance_squared_to((wa as Node3D).global_position)
		wa.apply_lod_frame(d2, full_r2, low_r2, hide_r2, fade_start_r2, apply_tiers)
