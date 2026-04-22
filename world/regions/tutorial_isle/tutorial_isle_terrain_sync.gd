extends Node3D
## Keeps Terrain3D isle biome `sea_level_y` in sync with the `Water` node, and pushes tree XZ
## positions for procedural dirt rings under trunks (shader reads `tree_dirt_patches`).

const _MAX_TREE_PATCHES := 48

@onready var _terrain: Terrain3D = $Terrain3D
@onready var _water: Node3D = $Water

@export var trees_scan_root: NodePath = ^"Harvestables/Trees"
## World-space radius (meters) of extra dirt around each collected tree node.
@export var tree_dirt_radius: float = 2.85
## How strongly grass weight is moved to dirt under trees (0 = off).
@export var tree_dirt_strength: float = 0.78


func _ready() -> void:
	_apply_sea_level()
	_push_tree_dirt_patches()


func _apply_sea_level() -> void:
	if _terrain == null:
		return
	var y: float = 0.0
	if _water != null and _water.get("water_level") != null:
		y = float(_water.water_level)
	_terrain.material.set_shader_param(&"sea_level_y", y)


func _push_tree_dirt_patches() -> void:
	if _terrain == null:
		return
	var root := get_node_or_null(trees_scan_root)
	if root == null:
		_terrain.material.set_shader_param(&"tree_dirt_patch_count", 0)
		return
	var patches := PackedVector4Array()
	_collect_tree_patches(root, patches)
	var n_src: int = mini(patches.size(), _MAX_TREE_PATCHES)
	var padded := PackedVector4Array()
	padded.resize(_MAX_TREE_PATCHES)
	for i: int in range(_MAX_TREE_PATCHES):
		padded[i] = patches[i] if i < n_src else Vector4.ZERO
	_terrain.material.set_shader_param(&"tree_dirt_patches", padded)
	_terrain.material.set_shader_param(&"tree_dirt_patch_count", n_src)


func _collect_tree_patches(n: Node, out: PackedVector4Array) -> void:
	if out.size() >= _MAX_TREE_PATCHES:
		return
	for c in n.get_children():
		_collect_tree_patches(c, out)
	if n is Node3D and n.name.begins_with("Harvestable"):
		var o := n as Node3D
		var p := o.global_position
		out.append(Vector4(p.x, p.z, tree_dirt_radius, tree_dirt_strength))
