extends Node
## Per-region coordinator: simulation LOD tiers for `wildlife_lod` vs anchor (usually Player). Animals are never hidden or disabled by distance.
##
## Units are Godot world units (1 ≈ 1 m). See exports on this node for distance bands.

@export var lod_anchor_path: NodePath = NodePath("../Player")
## Within this radius → full movement + full AI tick rate (when [member WildAnimal.use_simulation_lod]).
@export var full_sim_radius: float = 52.0
## Outer edge of low-cost band: between full and this → slower AI/movement; beyond → frozen idle.
@export var low_sim_radius: float = 105.0
## How often simulation tier (full/low/frozen) is reassigned; distance check runs every frame.
@export var tier_update_interval_sec: float = 0.12

var _anchor: Node3D
var _tier_tick_accum: float = 0.0


func _resolve_anchor() -> void:
	if lod_anchor_path.is_empty():
		_anchor = null
		return
	var node := get_node_or_null(lod_anchor_path)
	if node is Node3D:
		_anchor = node as Node3D
	else:
		_anchor = null


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

	for n in get_tree().get_nodes_in_group(&"wildlife_lod"):
		if not is_instance_valid(n):
			continue
		if not (n is WildAnimal):
			continue
		var wa := n as WildAnimal
		var d2 := ax.distance_squared_to((wa as Node3D).global_position)
		wa.apply_lod_frame(d2, full_r2, low_r2, apply_tiers)
