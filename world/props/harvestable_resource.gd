extends StaticBody3D
## Gameplay harvestable (trees, rocks). **Collision layer 2** is applied in `_ready` so the player ray (mask 2) hits props.
##
## ## Reusing / placing on a map (editor)
## - **Scenes:** `res://world/props/harvestable_tree.tscn` (chop) and `harvestable_rock.tscn` (mine). Open your level scene, drag the scene from the FileSystem dock, or **Instance Child Scene** and pick the same path.
## - **Move / duplicate:** Select the instance, move/rotate in the viewport. **Ctrl+D** duplicates. Adjust **Transform** in the inspector for fine placement.
## - **Exports:** Per-instance you can change `max_hits`, drops, particle color, `harvest_interaction` (Chop vs Mine) on rocks if you duplicate the rock scene or override in the inspector.
##
## ## Terrain3D (tutorial_isle)
## - The island uses a **TerrainObjects** node (`terrain_3d_objects.gd` — Terrain3D addon) as a parent for world props.
## - **Best for sculpted ground:** Make each tree/rock a **direct child** of that **TerrainObjects** node so Terrain3D can keep each object’s height in sync when you sculpt (addon tracks direct children).
## - **Grouping:** You can add an empty `Node3D` (e.g. “ForestPatch”) under **TerrainObjects**, parent instances under it for organization; height sync then applies per group node unless you use direct children — for strict per-prop follow, prefer **direct** children of **TerrainObjects** or re-run placement after big terrain edits.
## - **No Terrain3D:** Parent under any `Node3D`; set **Y** by eye or use Terrain3D’s project tools from the addon docs.
##
## ## Terrain3D “Meshes” / foliage painter (Asset Dock → Meshes)
## - That tool instances **MultiMeshes** for rendering. Official limitation: **no physics collision** on painted instances (see Terrain3D docs: *Foliage Instancing* → *Limitations* → *No Collision*).
## - So you **cannot** paint these `harvestable_*.tscn` scenes there and still get **chop/mine** + triggers — the painter does not spawn full `StaticBody3D` gameplay nodes.
## - Use the painter for **decorative-only** trees/rocks (visual mesh/scene), and place **separate** `harvestable_tree.tscn` / `harvestable_rock.tscn` under **TerrainObjects** for anything the player must harvest; or use an editor tool like **AssetPlacer / Scatter** (third-party) for bulk placement of real scenes.

enum HarvestInteraction { CHOP, MINE }

@export var harvest_interaction: HarvestInteraction = HarvestInteraction.CHOP

@export var max_hits: int = 6
@export var drop_count_min: int = 1
@export var drop_count_max: int = 2
@export var drop_scene: PackedScene
@export var particle_color: Color = Color(0.55, 0.38, 0.22)
@export var particle_height: float = 1.0
@export var shake_amount: float = 0.18
@export var tree_scale_multiplier: float = 1.2
@export var fall_duration: float = 0.45

@onready var visual: Node3D = $Visual

var _hits_left: int = 0
var _shake_tween: Tween
var _hit_particles: GPUParticles3D
var _is_falling: bool = false


func _ready() -> void:
	add_to_group("harvestable")
	collision_layer = 2
	_hits_left = max(1, max_hits)
	drop_count_min = maxi(1, drop_count_min)
	drop_count_max = maxi(drop_count_min, drop_count_max)
	if harvest_interaction == HarvestInteraction.CHOP and visual != null:
		visual.scale *= tree_scale_multiplier
	_setup_hit_particles()


func _setup_hit_particles() -> void:
	_hit_particles = GPUParticles3D.new()
	_hit_particles.name = "HitParticles"
	_hit_particles.top_level = true
	_hit_particles.emitting = false
	_hit_particles.one_shot = true
	_hit_particles.lifetime = 0.6
	_hit_particles.explosiveness = 1.0
	_hit_particles.amount = 78
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 95.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 7.4
	mat.gravity = Vector3(0.0, -10.0, 0.0)
	mat.scale_min = 0.12
	mat.scale_max = 0.28
	mat.color = particle_color
	_hit_particles.process_material = mat
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	_hit_particles.draw_pass_1 = sm
	add_child(_hit_particles)


## Returns a token understood by BaseCharacter.try_play_action_for_harvest (e.g. chop / mine).
func get_harvest_action() -> String:
	match harvest_interaction:
		HarvestInteraction.MINE:
			return "mine"
		_:
			return "chop"


func harvest_hit() -> bool:
	if _hits_left <= 0 or _is_falling:
		return false
	_hits_left -= 1
	_play_hit_feedback()
	if _hits_left <= 0:
		_finish_harvest()
	return true


func _finish_harvest() -> void:
	if harvest_interaction == HarvestInteraction.CHOP and visual != null:
		_is_falling = true
		collision_layer = 0
		collision_mask = 0
		var axis := Vector3(1.0, 0.0, randf_range(-0.35, 0.35)).normalized()
		var target_basis := Basis(axis, deg_to_rad(82.0)) * visual.transform.basis
		var tw := create_tween()
		tw.set_ease(Tween.EASE_IN)
		tw.set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(visual, "basis", target_basis, fall_duration)
		tw.tween_callback(Callable(self, "_spawn_drops"))
		tw.tween_callback(Callable(self, "queue_free"))
		return
	_spawn_drops()
	queue_free()


func _play_hit_feedback() -> void:
	if visual != null:
		if _shake_tween != null:
			_shake_tween.kill()
		_shake_tween = create_tween()
		var orig := visual.position
		var shake := Vector3(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount * 0.6, shake_amount * 0.6),
			randf_range(-shake_amount, shake_amount)
		)
		_shake_tween.tween_property(visual, "position", orig + shake, 0.05)
		_shake_tween.tween_property(visual, "position", orig, 0.16)
	if _hit_particles != null:
		_hit_particles.global_position = global_position + Vector3(0.0, particle_height, 0.0)
		_hit_particles.restart()
		_hit_particles.emitting = true


func _spawn_drops() -> void:
	if drop_scene == null:
		return
	var parent := get_parent()
	if parent == null:
		return
	var n: int = randi_range(drop_count_min, drop_count_max)
	for _idx in range(n):
		var drop: Node3D = drop_scene.instantiate() as Node3D
		if drop == null:
			continue
		var o := Vector3(randf_range(-0.65, 0.65), 0.45, randf_range(-0.65, 0.65))
		parent.add_child(drop)
		drop.global_position = global_position + o
		if drop.has_method("launch_from_harvest"):
			# Pass RID, not Node: typed Object args often fail through call_deferred on message queue.
			drop.call_deferred("launch_from_harvest", global_position, get_rid())
