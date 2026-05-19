extends CharacterBody3D

const _PickupScript: Script = preload("res://world/item_pickup_interactable.gd")
const _Terrain3DPrimaryResolver = preload("res://world/terrain3d_primary_resolver.gd")

const WORK_SPOT_GROUP := "woodsman_work_spot"
const WORK_FACE_GROUP := "woodsman_work_face"
const WORK_ANIM := "Work_C"
const WORK_ANIM_DURATION_SEC := 3.666

enum _AmbientState { IDLE, WALK, WORK }

@export var interact_radius: float = 2.4
@export var interact_height: float = 1.6
@export var roam_radius: float = 5.0
## Random idle walks stay outside this radius around the lumbermill workbench (only work approach enters).
@export var work_zone_keepout_radius: float = 8.0
@export var roam_speed: float = 1.05
@export var walk_arrival_dist: float = 0.4
@export var work_arrival_dist: float = 1.35
@export var walk_stuck_move_eps: float = 0.045
@export var walk_stuck_time_sec: float = 0.65
@export var walk_avoid_time_sec: float = 1.4
@export var walk_give_up_time_sec: float = 2.75
@export var idle_time_min: float = 2.5
@export var idle_time_max: float = 6.0
@export var work_duration_sec: float = WORK_ANIM_DURATION_SEC
@export_range(0.0, 1.0, 0.05) var work_chance_after_idle: float = 0.55
@export var face_turn_speed: float = 5.0
## Extra yaw after facing the workbench (degrees). Tune in editor if the rig faces sideways/backward.
@export var work_face_yaw_offset_deg: float = 0.0
## Optional fixed spot in the level (e.g. Marker3D by the lumbermill workbench). Falls back to group `woodsman_work_spot`.
@export var work_spot_path: NodePath = NodePath("")
## What to face while working (e.g. the lumbermill workbench). Falls back to group `woodsman_work_face`.
@export var work_face_path: NodePath = NodePath("")

@onready var _interact_area: Area3D = $InteractArea
@onready var _anim: AnimationPlayer = $AnimationPlayer

var _roam_home_xz: Vector2 = Vector2.ZERO
var _work_zone_center_xz: Vector2 = Vector2.ZERO
var _ambient: _AmbientState = _AmbientState.IDLE
var _walk_target: Vector3 = Vector3.ZERO
var _walk_arrival_state: _AmbientState = _AmbientState.IDLE
var _state_timer: float = 0.0
var _current_anim: String = ""
var _work_spot: Node3D
var _work_face: Node3D
var _walk_no_progress_timer: float = 0.0
var _walk_avoid_timer: float = 0.0
var _walk_avoid_sign: float = 1.0


func _ready() -> void:
	_work_face = _resolve_work_face()
	add_to_group("quest_npc_woodsman")
	_work_spot = _resolve_work_spot()
	_roam_home_xz = Vector2(global_position.x, global_position.z)
	_work_zone_center_xz = _resolve_work_zone_center_xz()
	if _interact_area != null:
		var shape := _interact_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape != null and shape.shape is CapsuleShape3D:
			var cap := shape.shape as CapsuleShape3D
			cap.radius = interact_radius * 0.45
			cap.height = interact_height
	_pick_idle()
	_state_timer = _random_idle_wait()


func _process(delta: float) -> void:
	if QuestDialogue.is_busy():
		velocity = Vector3.ZERO
		_play_anim(["Idle_A", "Idle"])
		return
	match _ambient:
		_AmbientState.IDLE:
			_tick_idle(delta)
		_AmbientState.WALK:
			_tick_walk(delta)
		_AmbientState.WORK:
			_tick_work(delta)


func get_interaction_prompt(_player: Node) -> String:
	if QuestService.is_quest_completed(QuestService.WOODSMAN_TRIAL_ID):
		return "E: Talk to Woodsman"
	if not QuestService.is_quest_active(QuestService.WOODSMAN_TRIAL_ID):
		return "E: Talk to Woodsman"
	var checkpoint := QuestService.get_awaiting_checkpoint()
	if not checkpoint.is_empty():
		return "E: Talk to Woodsman"
	if QuestService.stage_index == 3 and QuestService.get_counter("rabbits_killed") >= 3:
		if InventoryService.get_item_count("meat_raw") >= 3:
			return "E: Talk to Woodsman"
	return "E: Talk to Woodsman"


func interact(player: Node) -> bool:
	if player == null:
		return false
	if QuestDialogue.is_busy():
		return false
	_ambient = _AmbientState.IDLE
	_state_timer = _random_idle_wait()
	velocity = Vector3.ZERO
	_face_player(player)
	if QuestService.is_quest_completed(QuestService.WOODSMAN_TRIAL_ID):
		var lines := PackedStringArray(["You're doing fine out here. Keep your fire fed."])
		if not QuestService.is_quest_completed(QuestService.BLACKSMITH_TRIAL_ID):
			lines.append("The blacksmith lives down the road if you're ready to learn metalwork.")
		_show_lines(player, lines, [])
		return true
	var checkpoint := QuestService.get_awaiting_checkpoint()
	if not QuestService.is_quest_active(QuestService.WOODSMAN_TRIAL_ID):
		_start_quest(player)
		return true
	match checkpoint:
		QuestService.CHECKPOINT_AFTER_CHOP:
			_handle_after_chop(player)
		QuestService.CHECKPOINT_AFTER_CAMPFIRE:
			_handle_after_campfire(player)
		QuestService.CHECKPOINT_AFTER_HUNT:
			_handle_after_hunt(player)
		QuestService.CHECKPOINT_AFTER_COOK:
			_handle_finale(player)
		_:
			_show_idle_lines(player)
	return true


func _tick_idle(delta: float) -> void:
	velocity = Vector3.ZERO
	_play_anim(["Idle_A", "Idle"])
	_state_timer -= delta
	if _state_timer > 0.0:
		return
	if randf() < work_chance_after_idle and _resolve_work_spot() != null:
		_begin_work_approach()
	elif _is_in_work_keepout(global_position):
		_begin_walk_away_from_work_zone()
	elif randf() < 0.4:
		_begin_walk()
	else:
		_state_timer = _random_idle_wait()


func _tick_walk(delta: float) -> void:
	var pos := global_position
	var to := _walk_target - pos
	to.y = 0.0
	var dist := to.length()
	var arrival := _walk_arrival_distance()
	if dist < arrival:
		_finish_walk_arrival()
		return
	var prev_dist := dist
	var prev_pos := global_position
	velocity = _compute_walk_velocity(to, dist)
	move_and_slide()
	global_position = _snap_to_terrain(global_position)
	to = _walk_target - global_position
	to.y = 0.0
	dist = to.length()
	if dist < arrival:
		_finish_walk_arrival()
		return
	if _update_walk_obstacle_response(delta, prev_pos, prev_dist, dist, arrival):
		return
	_face_direction(velocity, delta)
	_play_anim(["Walking_A", "Walking_B", "Walk"])


func _compute_walk_velocity(to_target: Vector3, dist: float) -> Vector3:
	if dist < 0.01:
		return Vector3.ZERO
	var forward := to_target / dist
	if _walk_avoid_timer > 0.0:
		var side := Vector3(-forward.z, 0.0, forward.x) * _walk_avoid_sign
		return (forward + side * 0.9).normalized() * roam_speed
	if get_slide_collision_count() > 0:
		var slide := _slide_along_blocking_surface(forward)
		if slide.length_squared() > 0.01:
			return slide * roam_speed
	return forward * roam_speed


func _slide_along_blocking_surface(forward: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_len_sq := 0.0
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision == null:
			continue
		var normal := collision.get_normal()
		normal.y = 0.0
		if normal.length_squared() < 0.01:
			continue
		normal = normal.normalized()
		var tangent := forward - normal * forward.dot(normal)
		if tangent.length_squared() > best_len_sq:
			best = tangent
			best_len_sq = tangent.length_squared()
	return best.normalized() if best_len_sq > 0.01 else Vector3.ZERO


func _update_walk_obstacle_response(
	delta: float,
	prev_pos: Vector3,
	prev_dist: float,
	dist: float,
	arrival: float
) -> bool:
	var moved_pos := prev_pos.distance_to(global_position)
	var progressed := prev_dist - dist
	var colliding := get_slide_collision_count() > 0
	var making_progress := (
		moved_pos >= walk_stuck_move_eps
		and progressed >= walk_stuck_move_eps * 0.5
		and not colliding
	)
	if making_progress:
		_walk_no_progress_timer = maxf(0.0, _walk_no_progress_timer - delta * 2.0)
		if _walk_avoid_timer > 0.0:
			_walk_avoid_timer -= delta
		return false
	_walk_no_progress_timer += delta
	if _walk_no_progress_timer >= walk_stuck_time_sec and _walk_avoid_timer <= 0.0:
		_walk_avoid_sign = 1.0 if randf() > 0.5 else -1.0
		_walk_avoid_timer = walk_avoid_time_sec
		_walk_no_progress_timer = 0.0
		return false
	if _walk_avoid_timer > 0.0:
		_walk_avoid_timer -= delta
	if _walk_no_progress_timer < walk_give_up_time_sec:
		return false
	_abandon_walk(dist, arrival)
	return true


func _abandon_walk(dist: float, arrival: float) -> void:
	_walk_no_progress_timer = 0.0
	_walk_avoid_timer = 0.0
	if _walk_arrival_state == _AmbientState.WORK:
		_finish_walk_arrival()
		return
	if dist <= arrival * 1.75:
		_finish_walk_arrival()
		return
	_ambient = _AmbientState.IDLE
	_state_timer = _random_idle_wait()
	velocity = Vector3.ZERO
	_play_anim(["Idle_A", "Idle"])


func _walk_arrival_distance() -> float:
	if _walk_arrival_state == _AmbientState.WORK:
		return work_arrival_dist
	return walk_arrival_dist


func _finish_walk_arrival() -> void:
	velocity = Vector3.ZERO
	_walk_no_progress_timer = 0.0
	_walk_avoid_timer = 0.0
	match _walk_arrival_state:
		_AmbientState.WORK:
			_begin_work()
		_:
			_ambient = _AmbientState.IDLE
			_state_timer = _random_idle_wait()
			_play_anim(["Idle_A", "Idle"])


func _tick_work(delta: float) -> void:
	velocity = Vector3.ZERO
	_apply_work_facing()
	_state_timer -= delta
	if _state_timer > 0.0:
		return
	if _is_in_work_keepout(global_position):
		_begin_walk_away_from_work_zone()
	else:
		_ambient = _AmbientState.IDLE
		_state_timer = _random_idle_wait()
		_play_anim(["Idle_A", "Idle"])


func _begin_walk_away_from_work_zone() -> void:
	if not _is_in_work_keepout(global_position):
		return
	_walk_arrival_state = _AmbientState.IDLE
	_ambient = _AmbientState.WALK
	_reset_walk_obstacle_state()
	var pos_xz := Vector2(global_position.x, global_position.z)
	var dir := _roam_home_xz - pos_xz
	if dir.length_squared() < 0.25:
		dir = pos_xz - _work_zone_center_xz
	if dir.length_squared() < 0.01:
		dir = Vector2(1.0, 0.0)
	dir = dir.normalized()
	var dist_inside := _work_zone_center_xz.distance_to(pos_xz)
	var step := maxf(work_zone_keepout_radius - dist_inside + 1.5, 2.5)
	var dest := pos_xz + dir * step
	if dest.distance_to(_work_zone_center_xz) < work_zone_keepout_radius:
		dest = _work_zone_center_xz + dir * (work_zone_keepout_radius + 1.5)
	_walk_target = _snap_to_terrain(Vector3(dest.x, global_position.y, dest.y))


func _begin_walk() -> void:
	_walk_arrival_state = _AmbientState.IDLE
	_ambient = _AmbientState.WALK
	_reset_walk_obstacle_state()
	for _attempt in 16:
		var ang := randf() * TAU
		var r := randf_range(roam_radius * 0.35, roam_radius)
		var offset := Vector2(cos(ang), sin(ang)) * r
		var dest := _roam_home_xz + offset
		if dest.distance_to(_roam_home_xz) > roam_radius:
			continue
		if _is_in_work_keepout(Vector3(dest.x, global_position.y, dest.y)):
			continue
		_walk_target = _snap_to_terrain(Vector3(dest.x, global_position.y, dest.y))
		return
	_ambient = _AmbientState.IDLE
	_state_timer = _random_idle_wait()


func _begin_work_approach() -> void:
	var spot := _resolve_work_spot()
	if spot == null:
		return
	var stand := _work_stand_position(spot, true)
	var to_stand := stand - global_position
	to_stand.y = 0.0
	if to_stand.length() <= work_arrival_dist:
		_begin_work()
		return
	_walk_arrival_state = _AmbientState.WORK
	_ambient = _AmbientState.WALK
	_reset_walk_obstacle_state()
	_walk_target = _work_walk_target(spot)


func _reset_walk_obstacle_state() -> void:
	_walk_no_progress_timer = 0.0
	_walk_avoid_timer = 0.0


func _begin_work() -> void:
	var spot := _resolve_work_spot()
	_ambient = _AmbientState.WORK
	_state_timer = _work_anim_duration()
	var stand := _work_stand_position(spot)
	global_position = stand
	_apply_work_facing()
	velocity = Vector3.ZERO
	_play_anim([WORK_ANIM], false)


func _work_walk_target(spot: Node3D) -> Vector3:
	return _snap_to_terrain(_work_stand_position(spot, false))


func _work_stand_position(spot: Node3D, prefer_current_if_close: bool = true) -> Vector3:
	if spot == null:
		return _snap_to_terrain(global_position)
	var spot_pos := spot.global_position
	if prefer_current_if_close:
		var to_spot := spot_pos - global_position
		to_spot.y = 0.0
		if to_spot.length() <= work_arrival_dist + 0.25:
			return _snap_to_terrain(global_position)
	var face := _resolve_work_face()
	if face != null:
		var outward := spot_pos - face.global_position
		outward.y = 0.0
		if outward.length_squared() > 0.04:
			return _snap_to_terrain(face.global_position + outward.normalized() * outward.length())
	return _snap_to_terrain(spot_pos)


func _work_anim_duration() -> float:
	if _anim != null:
		var resolved := _resolve_anim_name(WORK_ANIM)
		if not resolved.is_empty():
			var anim_res: Animation = _anim.get_animation(resolved)
			if anim_res != null and anim_res.length > 0.001:
				return anim_res.length
	if work_duration_sec > 0.0:
		return work_duration_sec
	return WORK_ANIM_DURATION_SEC


func _pick_idle() -> void:
	_ambient = _AmbientState.IDLE
	_play_anim(["Idle_A", "Idle"])


func _random_idle_wait() -> float:
	return randf_range(idle_time_min, idle_time_max)


func _resolve_work_zone_center_xz() -> Vector2:
	var spot := _resolve_work_spot()
	var face := _resolve_work_face()
	if spot != null and face != null:
		var s := spot.global_position
		var f := face.global_position
		return Vector2((s.x + f.x) * 0.5, (s.z + f.z) * 0.5)
	if spot != null:
		return Vector2(spot.global_position.x, spot.global_position.z)
	if face != null:
		return Vector2(face.global_position.x, face.global_position.z)
	return _roam_home_xz


func _is_in_work_keepout(world_pos: Vector3) -> bool:
	if work_zone_keepout_radius <= 0.0:
		return false
	var xz := Vector2(world_pos.x, world_pos.z)
	return xz.distance_to(_work_zone_center_xz) < work_zone_keepout_radius


func _resolve_work_face() -> Node3D:
	if work_face_path != NodePath(""):
		var linked := get_node_or_null(work_face_path) as Node3D
		if linked != null:
			return linked
	if _work_face != null and is_instance_valid(_work_face):
		return _work_face
	var tree := get_tree()
	if tree == null:
		return null
	for node in tree.get_nodes_in_group(WORK_FACE_GROUP):
		if node is Node3D:
			_work_face = node as Node3D
			return _work_face
	return null


func _apply_work_facing() -> void:
	var spot := _resolve_work_spot()
	if spot != null:
		rotation.y = spot.global_rotation.y + deg_to_rad(work_face_yaw_offset_deg)
		return
	var look_pos := _resolve_work_face_look_position()
	var flat := look_pos - global_position
	flat.y = 0.0
	if flat.length_squared() < 1e-6:
		return
	rotation.y = atan2(flat.x, flat.z) + deg_to_rad(work_face_yaw_offset_deg)


func _resolve_work_face_look_position() -> Vector3:
	var face := _resolve_work_face()
	if face == null:
		return global_position
	var bench := face.global_position
	bench.y = global_position.y
	var spot := _resolve_work_spot()
	if spot == null:
		return bench
	var spot_pos := spot.global_position
	spot_pos.y = global_position.y
	return (bench + spot_pos) * 0.5


func _resolve_work_spot() -> Node3D:
	if work_spot_path != NodePath(""):
		var linked := get_node_or_null(work_spot_path) as Node3D
		if linked != null:
			return linked
	if _work_spot != null and is_instance_valid(_work_spot):
		return _work_spot
	var tree := get_tree()
	if tree == null:
		return null
	for node in tree.get_nodes_in_group(WORK_SPOT_GROUP):
		if node is Node3D:
			_work_spot = node as Node3D
			return _work_spot
	return null


func _snap_to_terrain(world_pos: Vector3) -> Vector3:
	var y := world_pos.y
	var hf := _Terrain3DPrimaryResolver.height_at_world(get_tree(), Vector3(world_pos.x, 0.0, world_pos.z))
	if not is_nan(hf):
		y = hf
	return Vector3(world_pos.x, y, world_pos.z)


func _face_player(player: Node) -> void:
	if player is Node3D:
		_face_direction((player as Node3D).global_position - global_position, 1.0)


func _face_direction(flat_dir: Vector3, delta: float) -> void:
	var d := flat_dir
	d.y = 0.0
	if d.length_squared() < 1e-6:
		return
	d = d.normalized()
	var target_yaw := atan2(d.x, d.z)
	var w := clampf(face_turn_speed * delta, 0.0, 1.0)
	rotation.y = lerp_angle(rotation.y, target_yaw, w)


func _play_anim(candidates: Array, loop: bool = true) -> void:
	if _anim == null:
		return
	for short in candidates:
		var resolved := _resolve_anim_name(str(short))
		if resolved.is_empty():
			continue
		if _current_anim == resolved and _anim.is_playing():
			return
		_current_anim = resolved
		_anim.play(resolved, 0.15)
		var anim_res: Animation = _anim.get_animation(resolved)
		if anim_res != null:
			anim_res.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
		return


func _resolve_anim_name(short: String) -> String:
	if _anim == null:
		return ""
	if _anim.has_animation(short):
		return short
	var prefixed := "Player/%s" % short
	if _anim.has_animation(prefixed):
		return prefixed
	return ""


func _start_quest(player: Node) -> void:
	QuestService.start_quest(QuestService.WOODSMAN_TRIAL_ID, 0)
	var stage := QuestService.get_current_stage()
	var lines := stage.dialogue_lines if stage != null else PackedStringArray()
	var hints := stage.toast_hints if stage != null else PackedStringArray()
	_grant_items(player, [{"id": "hatchet_basic", "count": 1}])
	_show_lines(player, lines, hints)


func _handle_after_chop(player: Node) -> void:
	QuestService.clear_awaiting_checkpoint()
	QuestService.set_flag("woodsman_stone_granted", true)
	_grant_items(player, [{"id": "stone", "count": 5}, {"id": "tinderbox", "count": 1}])
	var stage := QuestService.get_quest(QuestService.WOODSMAN_TRIAL_ID)
	var lines := PackedStringArray()
	var hints := PackedStringArray()
	if stage != null and stage.stages.size() > 1:
		lines = stage.stages[1].dialogue_lines
		hints = stage.stages[1].toast_hints
	_show_lines(player, lines, hints)
	QuestService.reevaluate_active_quest()


func _handle_after_campfire(player: Node) -> void:
	QuestService.clear_awaiting_checkpoint()
	_grant_items(
		player,
		[
			{"id": "bow_short_common", "count": 1},
			{"id": "quiver_common", "count": 1},
			{"id": "ammo_arrow_wood", "count": 20},
		]
	)
	QuestService.advance_stage()
	var stage := QuestService.get_current_stage()
	_show_lines(
		player,
		stage.dialogue_lines if stage != null else PackedStringArray(),
		stage.toast_hints if stage != null else PackedStringArray()
	)


func _handle_after_hunt(player: Node) -> void:
	if InventoryService.get_item_count("meat_raw") < 3:
		_notify(player, "Bring at least three pieces of raw meat from the rabbits.")
		return
	if QuestService.get_counter("rabbits_killed") < 3:
		_notify(player, "Hunt three rabbits first.")
		return
	QuestService.clear_awaiting_checkpoint()
	QuestService.advance_stage()
	var stage := QuestService.get_current_stage()
	_show_lines(
		player,
		stage.dialogue_lines if stage != null else PackedStringArray(),
		stage.toast_hints if stage != null else PackedStringArray()
	)


func _handle_finale(player: Node) -> void:
	QuestService.clear_awaiting_checkpoint()
	_grant_items(
		player,
		[
			{"id": "ammo_arrow_wood", "count": 10},
			{"id": "health_potion_small", "count": 2},
		]
	)
	var lines := PackedStringArray(
		[
			"You've got fire, meat, and a steady hand. That's more than most who wash ashore.",
			"Take these—may they keep you alive when the night turns cruel.",
			"Follow the road to the blacksmith's house—he'll teach you ore and the forge.",
		]
	)
	_show_lines(player, lines, PackedStringArray())
	QuestService.complete_quest(QuestService.WOODSMAN_TRIAL_ID)


func _show_idle_lines(player: Node) -> void:
	var stage := QuestService.get_current_stage()
	if stage == null:
		_notify(player, "Come back when you've done what I asked.")
		return
	_notify(player, "Follow your journal tasks, then return when you're done.")


func _show_lines(player: Node, lines: PackedStringArray, toast_hints: PackedStringArray) -> void:
	QuestDialogue.show_lines(
		"Woodsman",
		lines,
		func() -> void:
			_play_toast_hints(player, toast_hints)
	)


func _play_toast_hints(player: Node, hints: PackedStringArray) -> void:
	if hints.is_empty():
		return
	var toast: Node = player.get_node_or_null("GameplayToast") if player != null else null
	if toast != null and toast.has_method("show_message"):
		for i in hints.size():
			var delay := float(i) * 4.5
			var msg := str(hints[i])
			if delay <= 0.0:
				toast.call("show_message", msg)
			else:
				get_tree().create_timer(delay).timeout.connect(
					func() -> void:
						if is_instance_valid(toast):
							toast.call("show_message", msg)
				)


func _grant_items(player: Node, grants: Array) -> void:
	for entry in grants:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_id := GameState.normalize_item_id(str(entry.get("id", "")))
		var count := maxi(1, int(entry.get("count", 1)))
		if item_id.is_empty():
			continue
		var left := InventoryService.add_item(item_id, count)
		if left <= 0:
			continue
		var dropped := count - left
		if dropped > 0:
			_notify(player, "Inventory full — dropped %s nearby." % InventoryService.get_item_display_name(item_id))
		_spawn_pickup_at_feet(item_id, left)


func _spawn_pickup_at_feet(item_id: String, quantity: int) -> void:
	if quantity < 1:
		return
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	var inst: Node = null
	var scene: PackedScene = InventoryService.get_pickup_scene_for_item(item_id)
	if scene != null:
		inst = scene.instantiate()
	if inst == null:
		inst = _make_generic_pickup(item_id, quantity)
	if inst == null:
		return
	if "item_id" in inst:
		inst.set("item_id", item_id)
	if "quantity" in inst:
		inst.set("quantity", quantity)
	parent.add_child(inst)
	if inst is Node3D:
		(inst as Node3D).global_position = global_position + Vector3(0.0, 0.15, 1.2)


func _make_generic_pickup(item_id: String, quantity: int) -> Node3D:
	var root := Node3D.new()
	root.set_script(_PickupScript)
	root.set("item_id", item_id)
	root.set("quantity", quantity)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	shape.shape = sphere
	body.add_child(shape)
	root.add_child(body)
	return root


func _notify(player: Node, msg: String) -> void:
	if player != null and player.has_method("show_gameplay_message"):
		player.show_gameplay_message(msg)
