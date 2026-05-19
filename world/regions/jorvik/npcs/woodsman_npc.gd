extends Node3D

const _PickupScript: Script = preload("res://world/item_pickup_interactable.gd")
const _Terrain3DPrimaryResolver = preload("res://world/terrain3d_primary_resolver.gd")

enum _AmbientState { IDLE, WALK, CHOP }

@export var interact_radius: float = 2.4
@export var interact_height: float = 1.6
@export var roam_radius: float = 6.0
@export var roam_speed: float = 1.05
@export var idle_time_min: float = 2.5
@export var idle_time_max: float = 6.0
@export var chop_duration_sec: float = 3.8
@export_range(0.0, 1.0, 0.05) var chop_chance_after_walk: float = 0.4
@export var face_turn_speed: float = 5.0

@onready var _interact_area: Area3D = $InteractArea
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _chop_spot: Node3D = get_node_or_null("ChopSpot") as Node3D

var _home_xz: Vector2 = Vector2.ZERO
var _ambient: _AmbientState = _AmbientState.IDLE
var _walk_target: Vector3 = Vector3.ZERO
var _state_timer: float = 0.0
var _current_anim: String = ""


func _ready() -> void:
	add_to_group("quest_npc_woodsman")
	_home_xz = Vector2(global_position.x, global_position.z)
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
		_play_anim(["Idle_A", "Idle"])
		return
	match _ambient:
		_AmbientState.IDLE:
			_tick_idle(delta)
		_AmbientState.WALK:
			_tick_walk(delta)
		_AmbientState.CHOP:
			_tick_chop(delta)


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
	_face_player(player)
	if QuestService.is_quest_completed(QuestService.WOODSMAN_TRIAL_ID):
		_show_lines(player, PackedStringArray(["You're doing fine out here. Keep your fire fed."]), [])
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
	_play_anim(["Idle_A", "Idle"])
	_state_timer -= delta
	if _state_timer > 0.0:
		return
	if randf() < chop_chance_after_walk and _chop_spot != null:
		_begin_chop()
	else:
		_begin_walk()


func _tick_walk(delta: float) -> void:
	var pos := global_position
	var to := _walk_target - pos
	to.y = 0.0
	var dist := to.length()
	if dist < 0.35:
		_ambient = _AmbientState.IDLE
		_state_timer = _random_idle_wait()
		_play_anim(["Idle_A", "Idle"])
		return
	var step := roam_speed * delta
	var move := to.normalized() * minf(step, dist)
	global_position = pos + move
	_face_direction(move, delta)
	_play_anim(["Walking_A", "Walking_B", "Walk"])


func _tick_chop(delta: float) -> void:
	_state_timer -= delta
	if _state_timer > 0.0:
		return
	_ambient = _AmbientState.IDLE
	_state_timer = _random_idle_wait()
	_play_anim(["Idle_A", "Idle"])


func _begin_walk() -> void:
	_ambient = _AmbientState.WALK
	for _attempt in 8:
		var ang := randf() * TAU
		var r := randf_range(roam_radius * 0.35, roam_radius)
		var offset := Vector2(cos(ang), sin(ang)) * r
		var dest := _home_xz + offset
		if dest.distance_to(_home_xz) <= roam_radius:
			var y := global_position.y
			var hf := _Terrain3DPrimaryResolver.height_at_world(get_tree(), Vector3(dest.x, 0.0, dest.y))
			if not is_nan(hf):
				y = hf
			_walk_target = Vector3(dest.x, y, dest.y)
			return
	_walk_target = global_position


func _begin_chop() -> void:
	_ambient = _AmbientState.CHOP
	_state_timer = chop_duration_sec
	if _chop_spot != null:
		_face_direction(_chop_spot.global_position - global_position, 1.0)
	_play_anim(["Melee_1H_Attack_Chop"], false)


func _pick_idle() -> void:
	_ambient = _AmbientState.IDLE
	_play_anim(["Idle_A", "Idle"])


func _random_idle_wait() -> float:
	return randf_range(idle_time_min, idle_time_max)


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
