extends Object
class_name Terrain3DPrimaryResolver

## Resolves the gameplay Terrain3D (main ground), skipping overlay datasets such as `Terrain3DPaths`.
## Prefer nodes in group `terrain3d` (registered by region scenes such as tutorial_isle_terrain_sync).


static func find_primary(tree: SceneTree, terrain_override: Terrain3D = null) -> Terrain3D:
	if terrain_override != null and is_instance_valid(terrain_override) and terrain_override.is_inside_tree():
		return terrain_override
	if tree == null:
		return null
	var grouped := tree.get_first_node_in_group(&"terrain3d")
	if grouped is Terrain3D:
		return grouped as Terrain3D
	var root := tree.root
	if root == null:
		return null
	return _dfs_primary(root)


static func height_at_world(tree: SceneTree, world_position: Vector3, terrain_override: Terrain3D = null) -> float:
	var t := find_primary(tree, terrain_override)
	if t == null or t.data == null:
		return NAN
	var h: float = t.data.get_height(world_position)
	return h


static func _is_paths_overlay(t: Terrain3D) -> bool:
	if String(t.name) == "Terrain3DPaths":
		return true
	var dd: Variant = t.get("data_directory")
	return dd is String and String(dd).ends_with("terrain3d_tutorial_paths")


static func _dfs_primary(n: Node) -> Terrain3D:
	if n is Terrain3D:
		var terr := n as Terrain3D
		if not _is_paths_overlay(terr):
			return terr
	for c in n.get_children():
		var hit := _dfs_primary(c)
		if hit != null:
			return hit
	return null
