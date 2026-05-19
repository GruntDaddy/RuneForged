extends Node

## Quest progress, objective checks, and save sync for GameState.quest_progress.

signal quest_updated

const WOODSMAN_TRIAL_ID := &"woodsman_trial"
const CHECKPOINT_AFTER_CHOP := &"after_chop"
const CHECKPOINT_AFTER_CAMPFIRE := &"after_campfire"
const CHECKPOINT_AFTER_HUNT := &"after_hunt"
const CHECKPOINT_AFTER_COOK := &"after_cook"

var _quests: Dictionary = {}

var active_quest_id: String = ""
var stage_index: int = 0
var counters: Dictionary = {}
var flags: Dictionary = {}
var completed_quest_ids: Array[String] = []


func _ready() -> void:
	_index_quests_under("res://data/quests/")
	_ensure_builtin_quests()
	var inv: Node = get_node_or_null("/root/InventoryService")
	if inv != null and inv.has_signal("inventory_changed"):
		inv.inventory_changed.connect(_on_inventory_changed)
	call_deferred("_sync_from_game_state")


func _sync_from_game_state() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or not ("quest_progress" in gs):
		return
	load_progress_dict(gs.quest_progress)


func _on_inventory_changed() -> void:
	reevaluate_active_quest()


func get_quest(quest_id: String) -> QuestData:
	return _quests.get(quest_id, null) as QuestData


func is_quest_active(quest_id: String) -> bool:
	return active_quest_id == quest_id and not is_quest_completed(quest_id)


func is_quest_completed(quest_id: String) -> bool:
	return quest_id in completed_quest_ids


func get_active_quest() -> QuestData:
	if active_quest_id.is_empty():
		return null
	return get_quest(active_quest_id)


func get_current_stage() -> QuestStageData:
	var q := get_active_quest()
	if q == null or stage_index < 0 or stage_index >= q.stages.size():
		return null
	return q.stages[stage_index]


func get_awaiting_checkpoint() -> String:
	return str(flags.get("awaiting_woodsman_talk", ""))


func set_awaiting_checkpoint(checkpoint_id: String) -> void:
	flags["awaiting_woodsman_talk"] = checkpoint_id
	_persist_and_emit()


func clear_awaiting_checkpoint() -> void:
	flags.erase("awaiting_woodsman_talk")
	_persist_and_emit()


func get_flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)


func set_flag(key: String, value: Variant) -> void:
	flags[key] = value
	_persist_and_emit()


func increment_counter(key: String, amount: int = 1) -> void:
	counters[key] = int(counters.get(key, 0)) + amount
	reevaluate_active_quest()


func get_counter(key: String) -> int:
	return int(counters.get(key, 0))


func start_quest(quest_id: String, stage: int = 0) -> bool:
	if is_quest_completed(quest_id):
		return false
	if not _quests.has(quest_id):
		return false
	active_quest_id = quest_id
	stage_index = maxi(0, stage)
	if not flags.has("woodsman_met") and quest_id == WOODSMAN_TRIAL_ID:
		flags["woodsman_met"] = true
	_persist_and_emit()
	return true


func complete_quest(quest_id: String) -> void:
	if quest_id.is_empty():
		return
	if quest_id not in completed_quest_ids:
		completed_quest_ids.append(quest_id)
	if active_quest_id == quest_id:
		active_quest_id = ""
		stage_index = 0
		counters = {}
		flags = {"woodsman_met": true}
	clear_awaiting_checkpoint()
	_persist_and_emit()


func advance_stage() -> void:
	var q := get_active_quest()
	if q == null:
		return
	if stage_index + 1 >= q.stages.size():
		complete_quest(active_quest_id)
		return
	stage_index += 1
	_persist_and_emit()


func notify_campfire_placed(state_id: String) -> void:
	if not is_quest_active(WOODSMAN_TRIAL_ID) or stage_index != 2:
		return
	flags["quest_campfire_state_id"] = state_id
	flags["campfire_placed"] = true
	set_awaiting_checkpoint(CHECKPOINT_AFTER_CAMPFIRE)


func notify_cooked_at_fire(fire_state_id: String, produced_item_id: String) -> void:
	if not is_quest_active(WOODSMAN_TRIAL_ID) or stage_index != 4:
		return
	if produced_item_id != "meat_cooked":
		return
	var quest_fire := str(flags.get("quest_campfire_state_id", ""))
	if quest_fire.is_empty() or fire_state_id != quest_fire:
		return
	flags["cooked_on_quest_fire"] = true
	set_awaiting_checkpoint(CHECKPOINT_AFTER_COOK)


func notify_rabbit_killed() -> void:
	if not is_quest_active(WOODSMAN_TRIAL_ID) or stage_index != 3:
		return
	increment_counter("rabbits_killed", 1)


func notify_item_crafted(output_item_id: String) -> void:
	if output_item_id == "campfire_kit":
		reevaluate_active_quest()


func reevaluate_active_quest() -> void:
	if active_quest_id.is_empty():
		return
	match active_quest_id:
		WOODSMAN_TRIAL_ID:
			_evaluate_woodsman_trial()
		_:
			pass


func _evaluate_woodsman_trial() -> void:
	match stage_index:
		0:
			if InventoryService.get_item_count("logs") >= 1:
				stage_index = 1
				set_awaiting_checkpoint(CHECKPOINT_AFTER_CHOP)
		1:
			if bool(flags.get("woodsman_stone_granted", false)) and _woodsman_stage1_materials_met():
				stage_index = 2
				clear_awaiting_checkpoint()
				_persist_and_emit()
		3:
			_maybe_set_hunt_checkpoint()
		_:
			pass


func _woodsman_stage1_materials_met() -> bool:
	if InventoryService.has_item("campfire_kit"):
		return true
	return InventoryService.get_item_count("logs") >= 5 and InventoryService.get_item_count("stone") >= 5


func _maybe_set_hunt_checkpoint() -> void:
	if get_counter("rabbits_killed") < 3:
		return
	if InventoryService.get_item_count("meat_raw") < 3:
		return
	set_awaiting_checkpoint(CHECKPOINT_AFTER_HUNT)


func is_stage_objective_met() -> bool:
	if active_quest_id != WOODSMAN_TRIAL_ID:
		return false
	match stage_index:
		0:
			return InventoryService.get_item_count("logs") >= 1
		1:
			return _woodsman_stage1_materials_met()
		2:
			return bool(flags.get("campfire_placed", false))
		3:
			return get_counter("rabbits_killed") >= 3 and InventoryService.get_item_count("meat_raw") >= 3
		4:
			return bool(flags.get("cooked_on_quest_fire", false))
		_:
			return false


func get_journal_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var q := get_active_quest()
	if q == null:
		return lines
	lines.append(q.title)
	var stage := get_current_stage()
	if stage != null:
		if not stage.title.is_empty():
			lines.append(stage.title)
		if not stage.journal_text.is_empty():
			lines.append(stage.journal_text)
	for obj in _objectives_for_active_stage():
		if obj == null:
			continue
		var prog := _objective_progress_text(obj)
		if prog.is_empty():
			lines.append(obj.description)
		else:
			lines.append("%s (%s)" % [obj.description, prog])
	if not get_awaiting_checkpoint().is_empty():
		lines.append("Return to the Woodsman.")
	return lines


func _objectives_for_active_stage() -> Array:
	var stage := get_current_stage()
	if stage == null:
		return []
	return stage.objectives


func _objective_progress_text(obj: QuestObjectiveData) -> String:
	if obj == null:
		return ""
	match obj.objective_type:
		QuestObjectiveData.ObjectiveType.INVENTORY_COUNT:
			var have := InventoryService.get_item_count(obj.target_id)
			return "%d/%d" % [have, obj.target_count]
		QuestObjectiveData.ObjectiveType.KILL_COUNT:
			return "%d/%d" % [get_counter("rabbits_killed"), obj.target_count]
		QuestObjectiveData.ObjectiveType.PLACED_FIRE:
			return "1/1" if bool(flags.get("campfire_placed", false)) else "0/1"
		QuestObjectiveData.ObjectiveType.COOK_ON_FIRE:
			return "1/1" if bool(flags.get("cooked_on_quest_fire", false)) else "0/1"
		_:
			return ""


func load_progress_dict(d: Variant) -> void:
	active_quest_id = ""
	stage_index = 0
	counters = {}
	flags = {}
	completed_quest_ids = []
	if typeof(d) != TYPE_DICTIONARY:
		quest_updated.emit()
		return
	var data: Dictionary = d
	active_quest_id = str(data.get("active_quest_id", ""))
	stage_index = int(data.get("stage_index", 0))
	if typeof(data.get("counters", null)) == TYPE_DICTIONARY:
		counters = (data.get("counters") as Dictionary).duplicate(true)
	if typeof(data.get("flags", null)) == TYPE_DICTIONARY:
		flags = (data.get("flags") as Dictionary).duplicate(true)
	var cq: Variant = data.get("completed_quest_ids", [])
	if typeof(cq) == TYPE_ARRAY:
		for id in cq as Array:
			completed_quest_ids.append(str(id))
	quest_updated.emit()


func to_progress_dict() -> Dictionary:
	return {
		"active_quest_id": active_quest_id,
		"stage_index": stage_index,
		"counters": counters.duplicate(true),
		"flags": flags.duplicate(true),
		"completed_quest_ids": completed_quest_ids.duplicate(),
	}


func _persist_and_emit() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and "quest_progress" in gs:
		gs.quest_progress = to_progress_dict()
	quest_updated.emit()


func _index_quests_under(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		push_warning("QuestService: cannot open %s" % dir_path)
		return
	d.list_dir_begin()
	var entry_name: String = d.get_next()
	while entry_name != "":
		if not entry_name.begins_with("."):
			var p: String = dir_path.path_join(entry_name)
			if d.current_is_dir():
				_index_quests_under(p)
			elif entry_name.ends_with(".tres"):
				var res: Resource = ResourceLoader.load(p)
				if res is QuestData:
					var q: QuestData = res as QuestData
					if q.id.is_empty():
						push_warning("QuestService: empty id in %s" % p)
					else:
						_quests[q.id] = q
		entry_name = d.get_next()


func _ensure_builtin_quests() -> void:
	if _quests.has(WOODSMAN_TRIAL_ID):
		return
	_quests[WOODSMAN_TRIAL_ID] = _build_woodsman_trial_quest()


func _build_woodsman_trial_quest() -> QuestData:
	var q := QuestData.new()
	q.id = WOODSMAN_TRIAL_ID
	q.title = "The Woodsman's Trial"
	q.summary = "Learn to survive the shore: chop wood, build fire, hunt, and cook."
	q.stages = [
		_make_woodsman_stage(
			"hatchet",
			"A stranger's tools",
			"Equip the hatchet and chop a tree for logs.",
			[{"type": QuestObjectiveData.ObjectiveType.INVENTORY_COUNT, "id": "logs", "count": 1, "desc": "Collect at least 1 log"}],
			[
				"You look half-drowned. The forest will feed you if you respect it.",
				"Take this hatchet. Chop a tree nearby, then come back when you have wood.",
			],
			["Equip the hatchet, face a tree, and attack to chop."],
		),
		_make_woodsman_stage(
			"materials",
			"Fuel for the night",
			"Gather five logs and craft a campfire kit at the Forge menu.",
			[
				{"type": QuestObjectiveData.ObjectiveType.INVENTORY_COUNT, "id": "logs", "count": 5, "desc": "Collect 5 logs"},
				{"type": QuestObjectiveData.ObjectiveType.INVENTORY_COUNT, "id": "stone", "count": 5, "desc": "Have 5 stone (the Woodsman will help)"},
			],
			[
				"Fire keeps the cold and the dark at bay.",
				"I'll spare you some stone and a tinderbox. Bring five logs and craft a campfire kit at your Forge.",
			],
			["Open the menu with C, use Forge, and craft a Campfire kit.", "Use the tinderbox to light your campfire after you place it."],
		),
		_make_woodsman_stage(
			"campfire",
			"Light the hearth",
			"Place your campfire kit somewhere safe, then return.",
			[{"type": QuestObjectiveData.ObjectiveType.PLACED_FIRE, "id": "campfire_kit", "count": 1, "desc": "Place your campfire"}],
			[
				"Good. Set your kit down somewhere clear—not on the roots.",
				"Come back when your fire is placed.",
			],
			["Put the campfire kit on your hotbar and confirm placement."],
		),
		_make_woodsman_stage(
			"hunt",
			"The quiet hunt",
			"Hunt three rabbits and bring back raw meat.",
			[{"type": QuestObjectiveData.ObjectiveType.KILL_COUNT, "id": "rabbit", "count": 3, "desc": "Kill 3 rabbits"}],
			[
				"You've got fire. Now you need meat.",
				"Take this bow and quiver. Hunt three rabbits, then return with the meat.",
			],
			["Equip the bow, put the quiver on your back slot, and keep arrows in your bag."],
		),
		_make_woodsman_stage(
			"cook",
			"Meat over flame",
			"Cook raw meat on your campfire.",
			[{"type": QuestObjectiveData.ObjectiveType.COOK_ON_FIRE, "id": "meat_cooked", "count": 1, "desc": "Cook meat on your campfire"}],
			[
				"Raw meat will sour your gut. Cook it on the fire you built.",
				"Use Cook Meat/Fish at your lit campfire when you have raw meat.",
			],
			["Light your fire with a tinderbox, enable cooking, and wait for the meat to finish."],
		),
	]
	return q


func _make_woodsman_stage(
	stage_id: String,
	title: String,
	journal_text: String,
	objective_specs: Array,
	dialogue_lines: Array,
	toast_hints: Array,
) -> QuestStageData:
	var stage := QuestStageData.new()
	stage.stage_id = stage_id
	stage.title = title
	stage.journal_text = journal_text
	stage.dialogue_lines = PackedStringArray(dialogue_lines)
	stage.toast_hints = PackedStringArray(toast_hints)
	for spec in objective_specs:
		var obj := QuestObjectiveData.new()
		obj.objective_type = spec.get("type", QuestObjectiveData.ObjectiveType.INVENTORY_COUNT)
		obj.target_id = str(spec.get("id", ""))
		obj.target_count = int(spec.get("count", 1))
		obj.description = str(spec.get("desc", ""))
		stage.objectives.append(obj)
	return stage
