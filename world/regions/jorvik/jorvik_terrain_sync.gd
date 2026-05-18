extends Node3D
## Keeps Terrain3D isle biome `sea_level_y` in sync with the `Water` node, and pushes tree XZ
## positions for procedural dirt rings under trunks (shader reads `tree_dirt_patches`).
##
## **Terrain3D:** Main island uses node `Terrain3D`, group `terrain3d`, data `res://data/terrain3d`. If you add a second overlay terrain (e.g. paths), resolve gameplay height via [Terrain3DPrimaryResolver] or group `terrain3d`, not arbitrary `find_children` order.

const _MAX_TREE_PATCHES := 48

@onready var _terrain: Terrain3D = $Terrain3D
@onready var _water: Node3D = $Water

## Harvestables root under the **main region scene** (e.g. tutorial_isle.tscn → Props/Harvestables).
## Resolved via `current_scene`, not this node's parent (terrain sync lives on the environment subtree).
@export var trees_scan_root: NodePath = ^"Props/Harvestables"
## World-space radius (meters) of extra dirt around each collected tree node.
@export var tree_dirt_radius: float = 2.85
## How strongly grass weight is moved to dirt under trees (0 = off).
@export var tree_dirt_strength: float = 0.78


func _ready() -> void:
	if _terrain != null:
		# Lets gameplay code resolve Terrain3D without paths (see WildAnimal ground queries).
		_terrain.add_to_group(&"terrain3d")
	_apply_sea_level()
	_push_tree_dirt_patches()
	if Engine.is_editor_hint() and _terrain != null and _terrain.vertex_spacing > 1.0:
		push_warning(
			"Terrain3D paint samples on a grid stepped by vertex_spacing (%.1f m here) — large spacing looks blocky. " % _terrain.vertex_spacing
			+ "Use ≤0.5 for detail. Paint Texture (B) REPLACE ignores strength (full swap per vertex when brush hits); use Spray (V) for gradual blends."
		)


func _apply_sea_level() -> void:
	if _terrain == null:
		return
	var terrain_mat: Variant = _get_terrain_shader_material()
	if terrain_mat == null:
		return
	var y: float = 0.0
	if _water != null and _water.get("water_level") != null:
		y = float(_water.water_level)
	terrain_mat.set_shader_param(&"sea_level_y", y)


func _push_tree_dirt_patches() -> void:
	if _terrain == null:
		return
	var terrain_mat: Variant = _get_terrain_shader_material()
	if terrain_mat == null:
		return
	var root := _resolve_trees_scan_root()
	if root == null:
		terrain_mat.set_shader_param(&"tree_dirt_patch_count", 0)
		return
	var patches := PackedVector4Array()
	_collect_tree_patches(root, patches)
	var n_src: int = mini(patches.size(), _MAX_TREE_PATCHES)
	var padded := PackedVector4Array()
	padded.resize(_MAX_TREE_PATCHES)
	for i: int in range(_MAX_TREE_PATCHES):
		padded[i] = patches[i] if i < n_src else Vector4.ZERO
	terrain_mat.set_shader_param(&"tree_dirt_patches", padded)
	terrain_mat.set_shader_param(&"tree_dirt_patch_count", n_src)


func _resolve_trees_scan_root() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var primary: NodePath = trees_scan_root
	if primary.is_empty():
		primary = ^"Props/Harvestables"
	var root := scene.get_node_or_null(primary)
	if root != null:
		return root
	var fallbacks: Array[NodePath] = [
		^"Props/Harvestables",
		^"Harvestables",
		^"Props/Harvestables/Trees",
		^"Harvestables/Trees",
	]
	for p in fallbacks:
		if p == primary:
			continue
		root = scene.get_node_or_null(p)
		if root != null:
			return root
	return null


func _get_terrain_shader_material() -> Variant:
	if _terrain == null:
		return null
	if _terrain.material == null:
		push_warning("tutorial_isle_terrain_sync: Terrain3D has no material; skipping shader sync.")
		return null
	if not _terrain.material.has_method("set_shader_param"):
		push_warning("tutorial_isle_terrain_sync: Terrain3D material has no shader param API; skipping shader sync.")
		return null
	return _terrain.material


func _collect_tree_patches(n: Node, out: PackedVector4Array) -> void:
	if out.size() >= _MAX_TREE_PATCHES:
		return
	for c in n.get_children():
		_collect_tree_patches(c, out)
	# Instanced trees are often renamed (e.g. "Trees_PalmTrees#HarvestableTree"); match substring.
	if n is Node3D and String(n.name).contains("Harvestable"):
		var o := n as Node3D
		var p := o.global_position
		out.append(Vector4(p.x, p.z, tree_dirt_radius, tree_dirt_strength))
