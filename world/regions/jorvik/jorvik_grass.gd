@tool
extends "res://addons/simplegrasstextured/grass.gd"

## Tutorial isle grass: KayKit mesh + texture, SimpleGrassTextured wind shader.
## Paint in editor with SimpleGrassTextured tools (airbrush/pencil) after selecting this node.

const _KAYKIT_GLTF := "res://assets/kaykit/forest_and_nature_pack/Color3/Grass_1_D_Singlesided_Color3.gltf"
static var _mesh_cache: Mesh


func _init() -> void:
	super()
	if mesh == null:
		mesh = _get_kaykit_mesh()


static func _get_kaykit_mesh() -> Mesh:
	if _mesh_cache != null:
		return _mesh_cache
	var ps: PackedScene = load(_KAYKIT_GLTF) as PackedScene
	if ps == null:
		push_warning("TutorialIsleGrass: could not load KayKit GLTF, using addon default mesh in editor.")
		return null
	var root := ps.instantiate()
	var stack: Array[Node] = [root]
	var found: Mesh
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				found = mi.mesh
				break
		for c in n.get_children():
			stack.append(c)
	root.queue_free()
	_mesh_cache = found
	if found == null:
		push_warning("TutorialIsleGrass: no MeshInstance3D in KayKit GLTF.")
	return found
