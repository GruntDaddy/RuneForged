extends StaticBody3D
## Gameplay harvestable (trees, rocks). Use **collision layer 2** so the player melee ray (mask 2) hits props.
## For Terrain3D workflow: parent instances under a [Terrain3DObjects] node so transforms follow sculpted height in the editor.

enum HarvestInteraction { CHOP, MINE }

@export var harvest_interaction: HarvestInteraction = HarvestInteraction.CHOP

@export var max_hits: int = 3
@export var drop_count_min: int = 1
@export var drop_count_max: int = 2
@export var drop_scene: PackedScene
@export var particle_color: Color = Color(0.55, 0.38, 0.22)
@export var particle_height: float = 1.0

@onready var visual: Node3D = $Visual

var _hits_left: int = 0
var _shake_tween: Tween
var _hit_particles: GPUParticles3D


func _ready() -> void:
	add_to_group("harvestable")
	collision_layer = 2
	_hits_left = max(1, max_hits)
	drop_count_min = maxi(1, drop_count_min)
	drop_count_max = maxi(drop_count_min, drop_count_max)
	_setup_hit_particles()


func _setup_hit_particles() -> void:
	_hit_particles = GPUParticles3D.new()
	_hit_particles.name = "HitParticles"
	_hit_particles.emitting = false
	_hit_particles.one_shot = true
	_hit_particles.explosiveness = 0.88
	_hit_particles.amount = 28
	_hit_particles.position = Vector3(0.0, particle_height, 0.0)
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 62.0
	mat.initial_velocity_min = 1.2
	mat.initial_velocity_max = 3.8
	mat.gravity = Vector3(0.0, -10.0, 0.0)
	mat.scale_min = 0.04
	mat.scale_max = 0.11
	mat.color = particle_color
	_hit_particles.process_material = mat
	var sm := SphereMesh.new()
	sm.radius = 0.055
	sm.height = 0.11
	_hit_particles.draw_pass_1 = sm
	add_child(_hit_particles)


## Returns a token understood by BaseCharacter.try_play_action_for_harvest (e.g. chop / mine).
func get_harvest_action() -> String:
	match harvest_interaction:
		HarvestInteraction.MINE:
			return "mine"
		_:
			return "chop"


func harvest_hit() -> void:
	if _hits_left <= 0:
		return
	_hits_left -= 1
	_play_hit_feedback()
	if _hits_left <= 0:
		_spawn_drops()
		queue_free()


func _play_hit_feedback() -> void:
	if visual != null:
		if _shake_tween != null:
			_shake_tween.kill()
		_shake_tween = create_tween()
		var orig := visual.position
		var shake := Vector3(
			randf_range(-0.09, 0.09),
			randf_range(-0.06, 0.06),
			randf_range(-0.09, 0.09)
		)
		_shake_tween.tween_property(visual, "position", orig + shake, 0.05)
		_shake_tween.tween_property(visual, "position", orig, 0.09)
	if _hit_particles != null:
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
