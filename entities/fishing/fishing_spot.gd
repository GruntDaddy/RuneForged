class_name FishingSpot
extends StaticBody3D
## Authored interactable: player faces spot with fishing rod + bait to run the fishing loop.

## Compared to player fishing skill for catch chance (see `player.gd`).
@export var fish_difficulty: int = 1
@export_range(0.0, 1.0, 0.01) var base_catch_chance: float = 0.42
@export var bonus_chance_per_skill_over_diff: float = 0.028
@export var bite_wait_min_sec: float = 2.2
@export var bite_wait_max_sec: float = 5.5
@export var reward_item_id: String = "fish_raw"
@export var xp_reward: int = 18

@export_group("Spot presentation")
@export var fish_jump_interval_min_sec: float = 4.2
@export var fish_jump_interval_max_sec: float = 11.5
@export_range(0.0, 2.0, 0.05) var fish_arc_peak_min: float = 0.52
@export_range(0.0, 2.0, 0.05) var fish_arc_peak_max: float = 1.08
@export_range(0.2, 2.5, 0.05) var fish_jump_distance_min: float = 0.42
@export_range(0.2, 2.5, 0.05) var fish_jump_distance_max: float = 0.95
@export_range(-1.0, 0.5, 0.01) var water_surface_y: float = 0.1
@export_range(0.0, 1.0, 0.01) var twin_jump_chance: float = 0.14


func get_interaction_prompt(_player: Node) -> String:
	return "E: Fish"


func interact(player: Node) -> void:
	if player != null and player.has_method("try_begin_fishing_at_spot"):
		player.call("try_begin_fishing_at_spot", self)


@onready var _bubble_particles: GPUParticles3D = $FxLayer/BubbleParticles
@onready var _jump_fish: MeshInstance3D = $FxLayer/JumpFishVisual

var _jump_timer: Timer


func _ready() -> void:
	if _bubble_particles != null:
		_bubble_particles.emitting = true
	if _jump_fish != null:
		_jump_fish.visible = false

	_jump_timer = Timer.new()
	_jump_timer.one_shot = true
	add_child(_jump_timer)
	_jump_timer.timeout.connect(_on_jump_timer_timeout)
	_schedule_next_jump()


func _schedule_next_jump() -> void:
	if _jump_timer == null:
		return
	var lo: float = minf(fish_jump_interval_min_sec, fish_jump_interval_max_sec)
	var hi: float = maxf(fish_jump_interval_min_sec, fish_jump_interval_max_sec)
	_jump_timer.wait_time = randf_range(lo, hi)
	_jump_timer.start()


func _on_jump_timer_timeout() -> void:
	if randf() < twin_jump_chance:
		await _play_one_fish_jump()
		await get_tree().create_timer(randf_range(0.16, 0.38)).timeout
		await _play_one_fish_jump()
	else:
		await _play_one_fish_jump()
	_schedule_next_jump()


func _play_one_fish_jump() -> void:
	if _jump_fish == null:
		return
	var dist_lo: float = minf(fish_jump_distance_min, fish_jump_distance_max)
	var dist_hi: float = maxf(fish_jump_distance_min, fish_jump_distance_max)
	var jump_len: float = randf_range(dist_lo, dist_hi)
	var ang: float = randf() * TAU
	var dir := Vector3(cos(ang), 0.0, sin(ang))
	var half := jump_len * 0.5
	var start := Vector3(-dir.x * half, water_surface_y, -dir.z * half)
	var end := Vector3(dir.x * half, water_surface_y, dir.z * half)
	var peak_lo: float = minf(fish_arc_peak_min, fish_arc_peak_max)
	var peak_hi: float = maxf(fish_arc_peak_min, fish_arc_peak_max)
	var peak: float = randf_range(peak_lo, peak_hi)
	var dur: float = randf_range(0.52, 0.92)

	_jump_fish.visible = true
	_jump_fish.scale = Vector3.ONE * randf_range(0.85, 1.15)

	var tween := create_tween()
	tween.set_parallel(false)
	tween.tween_method(_apply_fish_jump_frame.bind(start, end, peak), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished
	_jump_fish.visible = false


func _apply_fish_jump_frame(t: float, start: Vector3, end: Vector3, peak: float) -> void:
	if _jump_fish == null:
		return
	var pos := start.lerp(end, t)
	pos.y = water_surface_y + peak * sin(PI * t)
	_jump_fish.position = pos
	var flat := Vector3(end.x - start.x, 0.0, end.z - start.z)
	if flat.length_squared() > 1e-6:
		var yaw := atan2(flat.x, flat.z)
		_jump_fish.rotation = Vector3(
			deg_to_rad(-22.0) * sin(PI * t),
			yaw,
			deg_to_rad(8.0) * sin(TAU * t)
		)
