extends StaticBody3D

const _GameState = preload("res://autoload/game_state.gd")
const _InventoryService = preload("res://autoload/inventory_service.gd")

## Gameplay harvestable (trees, rocks). **Collision layer 2** is applied in `_ready` so the player ray (mask 2) hits props.
##
## ## Reusing / placing on a map (editor)
## - **Scenes:** `res://entities/harvestable/harvestable_tree_1.tscn` (chop) and `res://entities/harvestable/harvestable_rock.tscn` (mine). Open your level scene, drag the scene from the FileSystem dock, or **Instance Child Scene** and pick the same path.
## - **Move / duplicate:** Select the instance, move/rotate in the viewport. **Ctrl+D** duplicates. Adjust **Transform** in the inspector for fine placement.
## - **Exports:** Per-instance you can change `max_hits`, drops, particle color, `harvest_interaction` (Chop vs Mine) on rocks if you duplicate the rock scene or override in the inspector.
##
## ## Terrain3D (Jorvik / overworld)
## - The island uses a **TerrainObjects** node (`terrain_3d_objects.gd` — Terrain3D addon) as a parent for world props.
## - **Best for sculpted ground:** Make each tree/rock a **direct child** of that **TerrainObjects** node so Terrain3D can keep each object’s height in sync when you sculpt (addon tracks direct children).
## - **Grouping:** You can add an empty `Node3D` (e.g. “ForestPatch”) under **TerrainObjects**, parent instances under it for organization; height sync then applies per group node unless you use direct children — for strict per-prop follow, prefer **direct** children of **TerrainObjects** or re-run placement after big terrain edits.
## - **No Terrain3D:** Parent under any `Node3D`; set **Y** by eye or use Terrain3D’s project tools from the addon docs.
##
## ## Terrain3D “Meshes” / foliage painter (Asset Dock → Meshes)
## - That tool instances **MultiMeshes** for rendering. Official limitation: **no physics collision** on painted instances (see Terrain3D docs: *Foliage Instancing* → *Limitations* → *No Collision*).
## - So you **cannot** paint these `harvestable_*.tscn` scenes there and still get **chop/mine** + triggers — the painter does not spawn full `StaticBody3D` gameplay nodes.
## - Use the painter for **decorative-only** trees/rocks (visual mesh/scene), and place **separate** harvestable scenes under `res://entities/harvestable/` for anything the player must harvest; or use an editor tool like **AssetPlacer / Scatter** (third-party) for bulk placement of real scenes.

enum HarvestInteraction { CHOP, MINE }

## Return values for [`harvest_hit`].
const HARVEST_INVALID := 0
const HARVEST_WHIFF := 1
const HARVEST_SUCCESS := 2
const HARVEST_INVENTORY_FULL := 3

@export var harvest_interaction: HarvestInteraction = HarvestInteraction.CHOP

@export var max_hits: int = 6
@export var drop_count_min: int = 1
@export var drop_count_max: int = 2
@export var drop_scene: PackedScene
@export var particle_color: Color = Color(0.39, 0.257, 0.133, 1.0)
@export var particle_height: float = 1.0
@export var shake_amount: float = 0.18
@export var tree_scale_multiplier: float = 1.2
@export var fall_duration: float = 0.45
## Seconds before a fresh instance respawns at this transform. 0 = no respawn.
@export var respawn_seconds: float = 0.0
## Optional PackedScene for respawn (inspector override).
@export var respawn_scene: PackedScene
## Preferred: `res://` path to this harvestable's `.tscn` (set on each base scene). Used when `scene_file_path` is empty or points at a `.gltf`/`.glb` (so we always respawn the full StaticBody, not the mesh-only import).
@export_file("*.tscn") var respawn_scene_path: String = ""
## Gate for chop (trees). 0 = no requirement. Compared to GameState.woodcutting_level.
@export var required_woodcutting_level: int = 0
## Gate for mine (rocks). 0 = no requirement. Compared to GameState.mining_level.
@export var required_mining_level: int = 0
## Extra line for UI prompts, e.g. "Needs Level 10 Woodcutting".
@export var prompt_detail: String = ""
## If true: each impact rolls for success; success grants one item and reduces yield; failure has no yield. If false: legacy (every impact reduces yield; burst drops at depletion).
@export var rs_style_gathering: bool = true
## Must match InventoryService item ids (e.g. logs, stone, logs_oak, tin_ore).
@export var resource_item_id: String = "logs"
## If set, used for harvest UI messages; otherwise InventoryService.get_item_display_name.
@export var resource_display_name: String = ""
@export_range(0.0, 1.0) var base_success_chance: float = 0.5
@export var bonus_per_skill_level: float = 0.015
@export_range(0.0, 1.0) var min_success_chance: float = 0.05
@export_range(0.0, 1.0) var max_success_chance: float = 0.95

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


func get_required_woodcutting_level() -> int:
	return required_woodcutting_level


func get_required_mining_level() -> int:
	return required_mining_level


func get_prompt_detail() -> String:
	return prompt_detail


func can_harvest() -> bool:
	return _hits_left > 0 and not _is_falling


func get_resource_display_name() -> String:
	if not resource_display_name.is_empty():
		return resource_display_name
	var inv: Node = get_node_or_null("/root/InventoryService")
	if inv != null and inv.has_method("get_item_display_name"):
		return inv.get_item_display_name(resource_item_id)
	return resource_item_id.replace("_", " ").capitalize()


func _notify_player_message(msg: String) -> void:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("show_gameplay_message"):
		p.show_gameplay_message(msg)


func _get_respawn_packed_scene() -> PackedScene:
	if respawn_scene != null:
		return respawn_scene
	if not respawn_scene_path.is_empty():
		var from_path: Resource = load(respawn_scene_path)
		if from_path is PackedScene:
			return from_path as PackedScene
	var p := scene_file_path
	if not p.is_empty() and p.ends_with(".tscn"):
		var from_self: Resource = load(p)
		if from_self is PackedScene:
			return from_self as PackedScene
	return null


## Swing result: [`HARVEST_INVALID`] depleted/blocked, [`HARVEST_WHIFF`] failed roll, [`HARVEST_SUCCESS`] got resource, [`HARVEST_INVENTORY_FULL`] success roll but no space.
func harvest_hit() -> int:
	if _hits_left <= 0 or _is_falling:
		return HARVEST_INVALID
	if not rs_style_gathering:
		_hits_left -= 1
		_play_hit_feedback()
		if _hits_left <= 0:
			_finish_harvest()
		return HARVEST_SUCCESS
	# RS-style: roll once per call; failure = feedback only, no yield.
	if randf() > _compute_success_chance():
		_play_hit_feedback()
		return HARVEST_WHIFF
	if not _grant_one_resource_to_inventory():
		_play_hit_feedback()
		_notify_player_message("Not enough inventory space.")
		return HARVEST_INVENTORY_FULL
	_notify_player_message("You receive %s." % get_resource_display_name())
	_hits_left -= 1
	_play_hit_feedback()
	if _hits_left <= 0:
		_finish_harvest()
	return HARVEST_SUCCESS


func _compute_success_chance() -> float:
	var skill: int = 1
	var req: int = 0
	var gs: Node = get_node_or_null("/root/GameState")
	if harvest_interaction == HarvestInteraction.MINE:
		req = required_mining_level
		if gs is _GameState:
			skill = (gs as _GameState).mining_level
	else:
		req = required_woodcutting_level
		if gs is _GameState:
			skill = (gs as _GameState).woodcutting_level
	var bonus: float = bonus_per_skill_level * maxf(0.0, float(skill - maxi(req, 1)))
	return clampf(base_success_chance + bonus, min_success_chance, max_success_chance)


func _grant_one_resource_to_inventory() -> bool:
	var inv: Node = get_node_or_null("/root/InventoryService")
	if inv == null or not (inv is _InventoryService):
		push_warning("harvestable_resource: InventoryService missing; could not add %s" % resource_item_id)
		return false
	var left: int = (inv as _InventoryService).add_item(resource_item_id, 1)
	if left > 0:
		return false
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
		tw.tween_callback(Callable(self, "_depletion_drops_and_remove"))
		return
	_depletion_drops_and_remove()


func _depletion_drops_and_remove() -> void:
	if not rs_style_gathering:
		_spawn_drops()
	_remove_after_harvest()


func _remove_after_harvest() -> void:
	_schedule_respawn()
	queue_free()


func _schedule_respawn() -> void:
	if respawn_seconds <= 0.0:
		return
	var scene: PackedScene = _get_respawn_packed_scene()
	if scene == null:
		return
	var parent_node := get_parent()
	if parent_node == null:
		return
	var xf: Transform3D = global_transform
	var delay: float = respawn_seconds
	get_tree().create_timer(delay).timeout.connect(
		func() -> void:
			if not is_instance_valid(parent_node):
				return
			var inst: Node = scene.instantiate()
			parent_node.add_child(inst)
			if inst is Node3D:
				(inst as Node3D).global_transform = xf
	)


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
