extends Node
## Per-region coordinator: assigns simulation LOD to all nodes in group `wildlife_lod` by distance
## to an anchor (usually the player). Add one instance per overworld region scene.

@export var lod_anchor_path: NodePath = NodePath("../Player")
## Squared distance at or below which wildlife runs full AI/movement.
@export var full_sim_radius: float = 52.0
## Squared distance at or below which wildlife runs reduced-cost simulation (beyond = frozen).
@export var low_sim_radius: float = 105.0
## How often distance checks run (seconds); avoids sqrt work every frame for every animal.
@export var update_interval_sec: float = 0.12

var _anchor: Node3D
var _accum: float = 0.0


func _ready() -> void:
	_resolve_anchor()


func _process(delta: float) -> void:
	_accum += delta
	if _accum < maxf(0.016, update_interval_sec):
		return
	_accum = 0.0
	if not is_instance_valid(_anchor):
		_resolve_anchor()
	if _anchor == null:
		return
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
		wa.apply_lod_distance_squared(d2, full_r2, low_r2)


func _resolve_anchor() -> void:
	var node := get_node_or_null(lod_anchor_path)
	if node is Node3D:
		_anchor = node as Node3D
	else:
		_anchor = null
