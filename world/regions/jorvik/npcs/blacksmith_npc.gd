extends CharacterBody3D

const _PickupScript: Script = preload("res://world/item_pickup_interactable.gd")

@export var interact_radius: float = 2.4
@export var interact_height: float = 1.6
@export var face_turn_speed: float = 5.0

@onready var _interact_area: Area3D = $InteractArea
@onready var _anim: AnimationPlayer = $AnimationPlayer

var _current_anim: String = ""


func _ready() -> void:
	add_to_group("quest_npc_blacksmith")
	if _interact_area != null:
		var shape := _interact_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape != null and shape.shape is CapsuleShape3D:
			var cap := shape.shape as CapsuleShape3D
			cap.radius = interact_radius * 0.45
			cap.height = interact_height
	_play_anim(["Idle_A", "Idle"])


func _process(delta: float) -> void:
	if QuestDialogue.is_busy():
		velocity = Vector3.ZERO
		_play_anim(["Idle_A", "Idle"])
		return
	velocity = Vector3.ZERO
	_play_anim(["Idle_A", "Idle"])


func get_interaction_prompt(_player: Node) -> String:
	if not QuestService.is_quest_completed(QuestService.WOODSMAN_TRIAL_ID):
		return "E: Talk to Blacksmith"
	if QuestService.is_quest_completed(QuestService.BLACKSMITH_TRIAL_ID):
		return "E: Talk to Blacksmith"
	if not QuestService.is_quest_active(QuestService.BLACKSMITH_TRIAL_ID):
		return "E: Talk to Blacksmith"
	if not QuestService.get_awaiting_blacksmith_checkpoint().is_empty():
		return "E: Talk to Blacksmith"
	return "E: Talk to Blacksmith"


func interact(player: Node) -> bool:
	if player == null:
		return false
	if QuestDialogue.is_busy():
		return false
	velocity = Vector3.ZERO
	_face_player(player)
	if not QuestService.is_quest_completed(QuestService.WOODSMAN_TRIAL_ID):
		_show_lines(
			player,
			PackedStringArray(
				[
					"You're not ready for my forge yet.",
					"Learn survival from the Woodsman first—then come back.",
				]
			),
			PackedStringArray()
		)
		return true
	if QuestService.is_quest_completed(QuestService.BLACKSMITH_TRIAL_ID):
		_show_lines(
			player,
			PackedStringArray(
				[
					"Keep at the anvil. Every ingot you smelt sharpens your craft.",
					"When you can forge a bronze pickaxe, you'll be a proper smith.",
					"Keep traveling the road until you find the healer—she knows herbs and healing.",
				]
			),
			PackedStringArray()
		)
		return true
	var checkpoint := QuestService.get_awaiting_blacksmith_checkpoint()
	if not QuestService.is_quest_active(QuestService.BLACKSMITH_TRIAL_ID):
		_start_quest(player)
		return true
	match checkpoint:
		QuestService.CHECKPOINT_AFTER_MINE:
			_handle_after_mine(player)
		QuestService.CHECKPOINT_AFTER_SMELT:
			_handle_after_smelt(player)
		QuestService.CHECKPOINT_AFTER_HATCHET:
			_handle_finale(player)
		_:
			_show_idle_lines(player)
	return true


func _start_quest(player: Node) -> void:
	if not QuestService.start_quest(QuestService.BLACKSMITH_TRIAL_ID, 0):
		_show_lines(
			player,
			PackedStringArray(["Finish the Woodsman's lessons before I take you on."]),
			PackedStringArray()
		)
		return
	var stage := QuestService.get_current_stage()
	var lines := stage.dialogue_lines if stage != null else PackedStringArray()
	var hints := stage.toast_hints if stage != null else PackedStringArray()
	_grant_items(player, [{"id": "pickaxe_basic", "count": 1}])
	_show_lines(player, lines, hints)


func _handle_after_mine(player: Node) -> void:
	QuestService.clear_awaiting_blacksmith_checkpoint()
	QuestService.set_flag("blacksmith_tongs_granted", true)
	_grant_items(player, [{"id": "tool_tongs", "count": 1}])
	var quest := QuestService.get_quest(QuestService.BLACKSMITH_TRIAL_ID)
	var lines := PackedStringArray()
	var hints := PackedStringArray()
	if quest != null and quest.stages.size() > 1:
		lines = quest.stages[1].dialogue_lines
		hints = quest.stages[1].toast_hints
	_show_lines(player, lines, hints)


func _handle_after_smelt(player: Node) -> void:
	QuestService.clear_awaiting_blacksmith_checkpoint()
	QuestService.set_flag("blacksmith_hammer_granted", true)
	_grant_items(player, [{"id": "tool_hammer", "count": 1}])
	QuestService.advance_stage()
	var stage := QuestService.get_current_stage()
	_show_lines(
		player,
		stage.dialogue_lines if stage != null else PackedStringArray(),
		stage.toast_hints if stage != null else PackedStringArray()
	)


func _handle_finale(player: Node) -> void:
	QuestService.clear_awaiting_blacksmith_checkpoint()
	_grant_items(player, [{"id": "ingot_bronze", "count": 3}])
	var quest := QuestService.get_quest(QuestService.BLACKSMITH_TRIAL_ID)
	var lines := PackedStringArray()
	var hints := PackedStringArray()
	if quest != null and quest.stages.size() > 3:
		lines = quest.stages[3].dialogue_lines
		hints = quest.stages[3].toast_hints
	_show_lines(player, lines, hints)
	QuestService.complete_quest(QuestService.BLACKSMITH_TRIAL_ID)


func _show_idle_lines(player: Node) -> void:
	var stage := QuestService.get_current_stage()
	if stage == null:
		_notify(player, "Come back when you've done what I asked.")
		return
	_notify(player, "Follow your journal tasks, then return when you're done.")


func _show_lines(player: Node, lines: PackedStringArray, toast_hints: PackedStringArray) -> void:
	QuestDialogue.show_lines(
		"Blacksmith",
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


func _notify(player: Node, msg: String) -> void:
	if player != null and player.has_method("show_gameplay_message"):
		player.show_gameplay_message(msg)
