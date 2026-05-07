extends Node3D

## Campfire interactable. Prompt-driven, single equipped tinderbox to ignite,
## per-log burn time read from item data, single-slot auto-cook with random
## burn rolls. Old drag-and-drop panel is removed; status surfaces via a
## floating Label3D above the fire and brief player notifications.

const LOG_SLOT_COUNT := 4
const COOK_TIME_SEC := 24.0
const _LOW_FUEL_WARNING_SEC := 30.0
const _COOKABLE_PRIORITY := ["meat_raw", "fish_raw"]

@export var fire_state_id: String = ""
@export var start_lit: bool = false
@export var auto_extinguish_when_empty: bool = true
@export var charcoal_per_logs_burned: int = 2
@export var rest_warmth_minutes: float = 10.0
@export var warmth_night_run_bonus: float = 0.2
@export var warmth_night_penalty: float = 0.15
## Fallback burn duration when an item resource is missing `burn_seconds`.
@export var fallback_log_burn_seconds: int = 120
## Deprecated. Retained for save/scene compatibility; per-log burn time now lives in item data.
@export var seconds_per_log: float = 120.0
@export var initial_logs_on_ignite: int = 1
@export var ignite_log_cost: int = 0
@export var fuel_add_log_cost: int = 0
@export var rest_safe_min_distance: float = 1.35
@export var rest_safe_max_distance: float = 4.5
@export var rest_snap_distance: float = 3.7
## Hide floating status text when the player is farther than this distance (meters).
@export var status_label_max_distance_m: float = 10.0
## While fuel is in the last N seconds, fire/light/smoke scale down before hiding.
@export var fire_fade_out_seconds: float = 2.25
## Deprecated: torch recipes moved to workbench; left empty for saves/scenes that still set it.
@export var campfire_recipe_ids: PackedStringArray = PackedStringArray()

@onready var _light: OmniLight3D = $OmniLight3D
@onready var _fire_mesh: MeshInstance3D = $FireMesh
@onready var _smoke: GPUParticles3D = $SmokeParticles
@onready var _audio: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var _logs_visual: Node3D = $Campfire_Logs
@onready var _status_label: Label3D = get_node_or_null("StatusLabel")

var _is_lit: bool = false
var _fuel_seconds: float = 0.0
var _flicker_t: float = 0.0
var _logs_burned_counter: int = 0

## 4 fixed slots; each slot is null OR { "id": String } (one log per slot).
var _log_slots: Array = []

## Single in-progress cook entry.
## Empty when nothing is cooking. Otherwise:
##   { "id": String, "cooked_id": String, "burned_id": String, "difficulty": float }
var _cook_active: Dictionary = {}
var _cook_progress_sec: float = 0.0
var _cook_auto_enabled: bool = false
var _ignition_in_progress: bool = false

var _legacy_log_spill: Dictionary = {}
var _low_fuel_warned: bool = false

## After fuel runs out: logs stay black until player collects charcoal via [F] (`interact_secondary`).
var _ash_waiting_pickup: bool = false
var _pending_charcoal_count: int = 0
var _log_material_backup: Dictionary = {}


func _ready() -> void:
	add_to_group("campfire_status")
	_configure_status_label_visuals()
	_init_slot_arrays()
	_load_state()
	_apply_visuals()
	_update_status_label()
	if not _legacy_log_spill.is_empty():
		call_deferred("_apply_legacy_log_spill")


func _init_slot_arrays() -> void:
	_log_slots.clear()
	for _i in LOG_SLOT_COUNT:
		_log_slots.append(null)
	_cook_active = {}
	_cook_progress_sec = 0.0


func _process(delta: float) -> void:
	if _is_lit:
		_fuel_seconds = maxf(0.0, _fuel_seconds - delta)
		var fade_mult := 1.0
		if fire_fade_out_seconds > 0.0 and _fuel_seconds <= fire_fade_out_seconds:
			fade_mult = clampf(_fuel_seconds / fire_fade_out_seconds, 0.0, 1.0)
		if _fuel_seconds <= 0.0:
			if auto_extinguish_when_empty:
				extinguish()
				_update_status_label()
				return
		_tick_visuals(delta, fade_mult)
		_tick_cooking(delta)
		_tick_low_fuel_warning()
	_update_status_label()


func _tick_visuals(delta: float, fade_mult: float = 1.0) -> void:
	_flicker_t += delta * 4.4
	var wave: float = sin(_flicker_t) * 0.58 + sin(_flicker_t * 0.41 + 0.75) * 0.33
	var energy_base := maxf(0.1, 2.15 + wave * 0.45) * fade_mult
	_light.light_energy = energy_base
	_light.omni_range = maxf(1.0, 10.5 + wave * 1.15) * lerpf(0.35, 1.0, fade_mult)
	var fuel_norm: float = clampf(_fuel_seconds / 240.0, 0.35, 1.0) * fade_mult
	if _fire_mesh != null:
		var s: float = lerpf(0.72, 1.04, fuel_norm) * (1.0 + wave * 0.035) * lerpf(0.15, 1.0, fade_mult)
		_fire_mesh.scale = Vector3(s, s, s)
	if _smoke != null:
		_smoke.amount_ratio = clampf(lerpf(0.35, 1.0, fuel_norm), 0.05, 1.0)


func _tick_low_fuel_warning() -> void:
	if _fuel_seconds <= _LOW_FUEL_WARNING_SEC and _fuel_seconds > 0.0001:
		if not _low_fuel_warned:
			_low_fuel_warned = true
			_notify_nearby("The fire is dying. Add logs.")
	else:
		_low_fuel_warned = false


func _tick_cooking(delta: float) -> void:
	if not _cook_auto_enabled:
		return
	if _cook_active.is_empty():
		var picked := _pick_next_cookable_from_inventory()
		if picked.is_empty():
			_cook_auto_enabled = false
			_save_state()
			return
		_cook_active = picked
		_cook_progress_sec = 0.0
		_save_state()
		return
	_cook_progress_sec += delta
	if _cook_progress_sec >= COOK_TIME_SEC:
		_finish_cook()


func _finish_cook() -> void:
	var raw_id := str(_cook_active.get("id", ""))
	var cooked_id := str(_cook_active.get("cooked_id", ""))
	var burned_id := str(_cook_active.get("burned_id", ""))
	var difficulty := float(_cook_active.get("difficulty", 0.0))
	_cook_active = {}
	_cook_progress_sec = 0.0
	var burned: bool = randf() < clampf(difficulty, 0.0, 1.0) and not burned_id.is_empty()
	var produced_id := burned_id if burned else cooked_id
	if produced_id.is_empty():
		_save_state()
		return
	var left: int = InventoryService.add_item(produced_id, 1)
	var produced_name: String = InventoryService.get_item_display_name(produced_id)
	if left > 0:
		_notify_nearby("Inventory full — %s fell into the ash." % produced_name.to_lower())
	elif burned:
		var raw_name: String = InventoryService.get_item_display_name(raw_id)
		_notify_nearby("You burned the %s." % raw_name.to_lower())
	else:
		_notify_nearby("%s cooked." % produced_name)
	_save_state()


# ----- Interaction API ----------------------------------------------------

func get_interaction_prompts(player: Node) -> Array:
	var prompts: Array = []
	if _ash_waiting_pickup:
		prompts.append({"action": "interact_secondary", "label": "Collect charcoal"})
		return prompts
	var has_unlit_torch: bool = _is_lit and _player_has_unlit_torch_equipped()
	if has_unlit_torch:
		prompts.append({"action": "interact", "label": "Light Torch"})
	elif _can_add_log_now():
		prompts.append({"action": "interact", "label": "Add Logs"})
	if not _is_lit and _player_has_tinderbox_in_inventory():
		if _total_logs_in_slots() > 0:
			prompts.append({"action": "interact_secondary", "label": "Light Fire"})
		else:
			prompts.append({"action": "interact_secondary", "label": "Add logs before lighting"})
	if _is_lit and _has_any_cookable_in_inventory(player):
		if _cook_auto_enabled:
			prompts.append({"action": "interact_tertiary", "label": "Stop Cooking"})
		else:
			prompts.append({"action": "interact_tertiary", "label": "Cook Meat/Fish"})
	if _is_lit:
		var rest_label := "Rest"
		if player != null and player.has_method("is_campfire_resting") and bool(player.is_campfire_resting()):
			rest_label = "Stand Up"
		prompts.append({"action": "interact_quaternary", "label": rest_label})
	return prompts


func get_interaction_prompt(player: Node) -> String:
	# Fallback for any code path that hasn't adopted multi-prompts.
	var prompts := get_interaction_prompts(player)
	if prompts.is_empty():
		return ""
	var first: Dictionary = prompts[0]
	return "E: %s" % str(first.get("label", "Campfire"))


func interact(player: Node) -> bool:
	if player == null:
		return false
	if _ash_waiting_pickup:
		_notify_player(player, "Press [F] to collect charcoal from the ash.")
		return true
	if _is_lit and _try_light_equipped_torch(player):
		return true
	_action_add_log(player)
	return true


func interact_with_action(player: Node, action_id: String) -> bool:
	if player == null:
		return false
	match action_id:
		"interact_secondary":
			if _ash_waiting_pickup:
				_collect_charcoal(player)
			else:
				_action_light_fire(player)
		"interact_tertiary":
			_action_toggle_cook(player)
		"interact_quaternary":
			_action_rest(player)
		_:
			return false
	return true


# ----- Actions ------------------------------------------------------------

func _action_add_log(player: Node) -> void:
	var slot_idx := _find_empty_log_slot()
	if slot_idx < 0:
		_notify_player(player, "Log slots are full.")
		return
	var item_id := _find_best_log_in_inventory()
	if item_id.is_empty():
		_notify_player(player, "No logs in inventory.")
		return
	InventoryService.remove_item(item_id, 1)
	_log_slots[slot_idx] = {"id": item_id}
	if _is_lit:
		_fuel_seconds += float(_get_burn_seconds_for(item_id))
	_save_state()
	_apply_log_visuals()
	var dname: String = InventoryService.get_item_display_name(item_id)
	_notify_player(player, "Added %s to the fire." % dname.to_lower())


func _action_light_fire(player: Node) -> void:
	if _ash_waiting_pickup:
		_notify_player(player, "Collect charcoal from the ash first.")
		return
	if _is_lit:
		return
	if _ignition_in_progress:
		return
	if not _player_has_tinderbox_in_inventory():
		_notify_player(player, "You need a tinderbox in your inventory to light the fire.")
		return
	if _total_logs_in_slots() <= 0:
		_notify_player(player, "Add logs before lighting.")
		return
	_face_player_toward_fire(player as Node3D)
	_ignition_in_progress = true
	var restore_off_hand: Variant = _capture_off_hand_state()
	_set_temp_tinderbox_off_hand(player)
	# Ensure off-hand visuals are updated before the ignite clip starts.
	await get_tree().process_frame
	var ignite_anim_sec := _play_ignite_animation(player)
	if ignite_anim_sec <= 0.0:
		ignite_anim_sec = 0.65
	await get_tree().create_timer(ignite_anim_sec).timeout
	if player != null and player.has_method("finish_campfire_ignite_animation"):
		player.finish_campfire_ignite_animation()
	_is_lit = true
	if _fuel_seconds <= 0.0:
		_pool_all_logs_into_fuel()
	_low_fuel_warned = false
	_restore_off_hand_state(player, restore_off_hand)
	_ignition_in_progress = false
	_save_state()
	_apply_visuals()
	_notify_player(player, "Campfire lit.")


func _action_toggle_cook(player: Node) -> void:
	if not _is_lit:
		_notify_player(player, "Light the fire first.")
		return
	if not _cook_auto_enabled and _cook_active.is_empty() and not _has_any_cookable_in_inventory(player):
		_notify_player(player, "No raw meat or fish in inventory.")
		return
	_cook_auto_enabled = not _cook_auto_enabled
	if not _cook_auto_enabled and not _cook_active.is_empty():
		var raw_id := str(_cook_active.get("id", ""))
		if not raw_id.is_empty():
			var left: int = InventoryService.add_item(raw_id, 1)
			if left > 0:
				_notify_player(player, "Inventory full — %s fell into the ash." % raw_id)
		_cook_active = {}
		_cook_progress_sec = 0.0
	_save_state()
	if _cook_auto_enabled:
		_notify_player(player, "Cooking started.")
	else:
		_notify_player(player, "Cooking stopped.")


func _action_rest(player: Node) -> void:
	if not _is_lit:
		_notify_player(player, "Light the fire first.")
		return
	if player != null and player.has_method("is_campfire_resting") and bool(player.is_campfire_resting()):
		if player.has_method("stop_campfire_rest"):
			player.stop_campfire_rest()
		return
	if player != null and player.has_method("start_campfire_rest"):
		_place_and_face_player_for_rest(player)
		if not bool(player.call("start_campfire_rest", self)):
			_notify_player(player, "Cannot rest right now.")
			return
	_apply_rest_and_save(player)
	_notify_player(player, "Resting by the fire. Press [G] to stand.")


func on_player_rest_stopped(player: Node, _standup_duration: float = -1.0) -> void:
	if player == null:
		return
	_notify_player(player, "You stand up.")


func _place_and_face_player_for_rest(player: Node) -> void:
	var p3: Node3D = player as Node3D
	if p3 == null:
		return
	var fire_flat := Vector3(global_position.x, 0.0, global_position.z)
	var player_flat := Vector3(p3.global_position.x, 0.0, p3.global_position.z)
	var away: Vector3 = player_flat - fire_flat
	var dist: float = away.length()
	if dist < 0.001:
		away = -global_basis.z
		away.y = 0.0
		if away.length_squared() < 0.001:
			away = Vector3(0.0, 0.0, 1.0)
	var dir := away.normalized()
	# Always place on a safe radius before sit so root-motion clips cannot start inside the fire.
	var snap_dist := clampf(rest_snap_distance, rest_safe_min_distance, rest_safe_max_distance)
	var target: Vector3 = global_position + dir * snap_dist
	target.y = p3.global_position.y
	p3.global_position = target
	_face_player_toward_fire(p3)


func _face_player_toward_fire(player_body: Node3D) -> void:
	var to_fire := global_position - player_body.global_position
	to_fire.y = 0.0
	if to_fire.length_squared() < 0.0001:
		return
	var yaw := atan2(to_fire.x, to_fire.z)
	var base := player_body.get_node_or_null("BaseCharacter") as Node3D
	if base != null:
		base.rotation.y = yaw
	else:
		player_body.rotation.y = yaw


# ----- Helpers ------------------------------------------------------------

func _try_light_equipped_torch(player: Node) -> bool:
	var off: Variant = GameState.get_equipment_slot("off_hand")
	if typeof(off) != TYPE_DICTIONARY:
		return false
	var oid := GameState.normalize_item_id(str(off.get("id", "")))
	if oid != "tool_torch":
		return false
	if bool(off.get("torch_lit", false)):
		_notify_player(player, "Torch is already lit.")
		return true
	GameState.set_torch_lit_on_off_hand(true)
	if player.has_method("notify_torch_lit_changed"):
		player.notify_torch_lit_changed()
	_notify_player(player, "You light your torch from the fire.")
	return true


func _player_has_unlit_torch_equipped() -> bool:
	var off: Variant = GameState.get_equipment_slot("off_hand")
	if typeof(off) != TYPE_DICTIONARY:
		return false
	var oid := GameState.normalize_item_id(str(off.get("id", "")))
	if oid != "tool_torch":
		return false
	return not bool(off.get("torch_lit", false))


func _player_has_tinderbox_in_inventory() -> bool:
	return int(InventoryService.get_item_count("tinderbox")) > 0


func _capture_off_hand_state() -> Variant:
	var off: Variant = GameState.get_equipment_slot("off_hand")
	if typeof(off) == TYPE_DICTIONARY:
		return (off as Dictionary).duplicate(true)
	return null


func _set_temp_tinderbox_off_hand(player: Node) -> void:
	GameState.set_equipment_slot("off_hand", "tinderbox", 1)
	_sync_player_equipment_visuals(player)


func _restore_off_hand_state(player: Node, state: Variant) -> void:
	if typeof(state) == TYPE_DICTIONARY:
		GameState.equipment["off_hand"] = (state as Dictionary).duplicate(true)
	else:
		GameState.clear_equipment_slot("off_hand")
	_sync_player_equipment_visuals(player)
	if player != null and player.has_method("notify_torch_lit_changed"):
		player.notify_torch_lit_changed()


func _sync_player_equipment_visuals(player: Node) -> void:
	if player == null:
		return
	if player.has_method("_sync_equipped_hand_visuals"):
		player.call("_sync_equipped_hand_visuals")


func _play_ignite_animation(player: Node) -> float:
	if player == null:
		return -1.0
	if player.has_method("play_campfire_ignite_animation"):
		return float(player.call("play_campfire_ignite_animation"))
	return -1.0


func _can_add_log_now() -> bool:
	if _ash_waiting_pickup:
		return false
	if _find_empty_log_slot() < 0:
		return false
	return not _find_best_log_in_inventory().is_empty()


func _find_empty_log_slot() -> int:
	for i in LOG_SLOT_COUNT:
		if _log_slots[i] == null:
			return i
	return -1


func _find_best_log_in_inventory() -> String:
	var best_id: String = ""
	var best_burn: int = -1
	for raw_id in ItemCatalog.get_all_ids():
		var id := str(raw_id)
		var item: ItemData = ItemCatalog.get_item(id)
		if item == null or item.burn_seconds <= 0:
			continue
		if int(InventoryService.get_item_count(id)) <= 0:
			continue
		var burn: int = int(item.burn_seconds)
		if best_id.is_empty() or burn < best_burn:
			best_id = id
			best_burn = burn
	return best_id


func _has_any_cookable_in_inventory(_player: Node) -> bool:
	for id in _COOKABLE_PRIORITY:
		if int(InventoryService.get_item_count(id)) > 0:
			return true
	for raw_id in ItemCatalog.get_all_ids():
		var item: ItemData = ItemCatalog.get_item(str(raw_id))
		if item == null or item.cook_difficulty <= 0.0 or item.cooked_id.is_empty():
			continue
		if int(InventoryService.get_item_count(str(raw_id))) > 0:
			return true
	return false


func _pick_next_cookable_from_inventory() -> Dictionary:
	for id in _COOKABLE_PRIORITY:
		var picked := _pull_cookable_into_active(id)
		if not picked.is_empty():
			return picked
	for raw_id in ItemCatalog.get_all_ids():
		var picked := _pull_cookable_into_active(str(raw_id))
		if not picked.is_empty():
			return picked
	return {}


func _pull_cookable_into_active(item_id: String) -> Dictionary:
	if item_id.is_empty():
		return {}
	var item: ItemData = ItemCatalog.get_item(item_id)
	if item == null or item.cook_difficulty <= 0.0 or item.cooked_id.is_empty():
		return {}
	if int(InventoryService.get_item_count(item_id)) <= 0:
		return {}
	InventoryService.remove_item(item_id, 1)
	return {
		"id": item_id,
		"cooked_id": item.cooked_id,
		"burned_id": item.burned_id,
		"difficulty": float(item.cook_difficulty),
	}


## Pull burn time from every slotted log into the fuel pool without removing visuals yet.
func _pool_all_logs_into_fuel() -> void:
	var total := 0.0
	for i in LOG_SLOT_COUNT:
		var s: Variant = _log_slots[i]
		if s == null:
			continue
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var item_id := str((s as Dictionary).get("id", ""))
		if item_id.is_empty():
			continue
		total += float(_get_burn_seconds_for(item_id))
	_fuel_seconds += total


func _get_burn_seconds_for(item_id: String) -> int:
	var item: ItemData = ItemCatalog.get_item(item_id)
	if item != null and item.burn_seconds > 0:
		return int(item.burn_seconds)
	return maxi(1, fallback_log_burn_seconds)


func _total_logs_in_slots() -> int:
	var t := 0
	for i in LOG_SLOT_COUNT:
		if _log_slots[i] != null:
			t += 1
	return t


# ----- Lifecycle / visuals ------------------------------------------------

func light_fire(_logs_to_add: int = 0) -> void:
	if _ash_waiting_pickup:
		return
	if _is_lit:
		return
	_is_lit = true
	if _fuel_seconds <= 0.0:
		if _total_logs_in_slots() > 0:
			_pool_all_logs_into_fuel()
		else:
			_fuel_seconds = float(seconds_per_log)
	_low_fuel_warned = false
	_save_state()
	_apply_visuals()


func extinguish() -> void:
	var n_logs := _total_logs_in_slots()
	var had_logs := n_logs > 0
	if had_logs:
		_logs_burned_counter += n_logs
		_compute_pending_charcoal_from_counter()
	for i in LOG_SLOT_COUNT:
		_log_slots[i] = null
	_is_lit = false
	_fuel_seconds = 0.0
	_low_fuel_warned = false
	if had_logs:
		_ash_waiting_pickup = true
		_apply_burned_logs_visual(true)
	else:
		_ash_waiting_pickup = false
		_pending_charcoal_count = 0
	_save_state()
	_apply_visuals()


func _compute_pending_charcoal_from_counter() -> void:
	_pending_charcoal_count = 0
	if charcoal_per_logs_burned <= 0:
		return
	var grants := int(floor(float(_logs_burned_counter) / float(charcoal_per_logs_burned)))
	if grants <= 0:
		return
	_logs_burned_counter -= grants * charcoal_per_logs_burned
	_pending_charcoal_count = grants


func _collect_charcoal(player: Node) -> void:
	if not _ash_waiting_pickup:
		return
	var n := maxi(0, _pending_charcoal_count)
	if n > 0:
		var left: int = InventoryService.add_item("charcoal", n)
		if left > 0:
			_pending_charcoal_count = left
			_notify_player(player, "Inventory full — couldn't carry all charcoal.")
			return
	_pending_charcoal_count = 0
	_ash_waiting_pickup = false
	_apply_burned_logs_visual(false)
	_save_state()
	_apply_visuals()
	if player != null:
		var msg := "Ash cleared." if n <= 0 else "Collected charcoal."
		_notify_player(player, msg)


func _apply_rest_and_save(player: Node) -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and "warmth_until_unix_ms" in gs:
		var add_ms: int = int(rest_warmth_minutes * 60.0 * 1000.0)
		gs.warmth_until_unix_ms = Time.get_unix_time_from_system() * 1000 + add_ms
	if gs != null:
		if "campfire_night_run_bonus" in gs:
			gs.campfire_night_run_bonus = warmth_night_run_bonus
		if "campfire_night_penalty" in gs:
			gs.campfire_night_penalty = warmth_night_penalty
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("save_game"):
		sm.save_game()
	_notify_player(player, "You rest by the fire. Game saved.")


func _notify_player(player: Node, msg: String) -> void:
	if player != null and player.has_method("show_gameplay_message"):
		player.show_gameplay_message(msg)


func _notify_nearby(msg: String) -> void:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("show_gameplay_message"):
		p.show_gameplay_message(msg)


func _apply_visuals() -> void:
	_light.visible = _is_lit
	if _fire_mesh != null:
		_fire_mesh.visible = _is_lit
		if not _is_lit:
			_fire_mesh.scale = Vector3.ONE
	if _smoke != null:
		_smoke.emitting = _is_lit
		if not _is_lit:
			_smoke.amount_ratio = 1.0
	if _is_lit:
		_light.light_energy = 2.35
		_light.omni_range = 11.0
		if _audio != null and not _audio.playing:
			_audio.play()
	else:
		if _audio != null:
			_audio.stop()
	_apply_log_visuals()


func _apply_log_visuals() -> void:
	if _logs_visual != null:
		_logs_visual.visible = _total_logs_in_slots() > 0 or _ash_waiting_pickup


func _apply_burned_logs_visual(active: bool) -> void:
	if _logs_visual == null:
		return
	if active:
		if not _log_material_backup.is_empty():
			return
		for mi in _logs_visual.find_children("*", "MeshInstance3D", true, false):
			var mesh_i := mi as MeshInstance3D
			if mesh_i == null:
				continue
			if _log_material_backup.has(mesh_i):
				continue
			_log_material_backup[mesh_i] = mesh_i.material_override
			var ash := StandardMaterial3D.new()
			ash.albedo_color = Color(0.07, 0.065, 0.06, 1.0)
			ash.roughness = 0.94
			mesh_i.material_override = ash
	else:
		for k in _log_material_backup.keys():
			var mesh_i := k as MeshInstance3D
			if mesh_i != null and is_instance_valid(mesh_i):
				mesh_i.material_override = _log_material_backup[k]
		_log_material_backup.clear()


func _update_status_label() -> void:
	if _status_label == null:
		return
	var should_show: bool = (_is_lit or not _cook_active.is_empty() or _ash_waiting_pickup) and _is_player_within_status_range() and _is_primary_campfire_for_player()
	_status_label.visible = should_show
	if not should_show:
		return
	var lines: Array[String] = []
	if _ash_waiting_pickup:
		if _pending_charcoal_count > 0:
			lines.append("Charcoal in ash — [F] to collect")
		else:
			lines.append("Ash pile — [F] to clear")
	if _is_lit:
		lines.append("Fire: %s" % _format_seconds(_total_fire_seconds_remaining()))
	if not _cook_active.is_empty():
		var raw_id: String = str(_cook_active.get("id", ""))
		var raw_name: String = InventoryService.get_item_display_name(raw_id)
		lines.append("Cooking %s: %ds / %ds" % [raw_name.to_lower(), int(_cook_progress_sec), int(COOK_TIME_SEC)])
	_status_label.text = "\n".join(lines)


func _is_player_within_status_range() -> bool:
	var max_dist := maxf(0.1, status_label_max_distance_m)
	var p := get_tree().get_first_node_in_group("player")
	if not (p is Node3D):
		return true
	return global_position.distance_to((p as Node3D).global_position) <= max_dist


func _is_primary_campfire_for_player() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	if not (p is Node3D):
		return true
	var p3 := p as Node3D
	var my_dist_sq := global_position.distance_squared_to(p3.global_position)
	for n in get_tree().get_nodes_in_group("campfire_status"):
		if n == self or not (n is Node3D):
			continue
		if not is_instance_valid(n):
			continue
		var other := n as Node3D
		if global_position.is_equal_approx(other.global_position):
			continue
		var d2 := other.global_position.distance_squared_to(p3.global_position)
		if d2 + 0.0001 < my_dist_sq:
			return false
	return true


func _configure_status_label_visuals() -> void:
	if _status_label == null:
		return
	_status_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_status_label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	_status_label.no_depth_test = true
	_status_label.render_priority = 127
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.fixed_size = true


func _format_seconds(seconds: int) -> String:
	if seconds >= 60:
		@warning_ignore("integer_division")
		var m: int = seconds / 60
		var s: int = seconds % 60
		return "%dm %02ds" % [m, s]
	return "%ds" % maxi(0, seconds)


func _total_fire_seconds_remaining() -> int:
	return maxi(0, int(ceil(_fuel_seconds)))


# ----- Save / load --------------------------------------------------------

func _state_key() -> String:
	if not fire_state_id.is_empty():
		return fire_state_id
	return str(get_path())


func _slot_dict_to_save(arr: Array) -> Array:
	var out: Array = []
	for v in arr:
		if v == null:
			out.append(null)
		else:
			out.append((v as Dictionary).duplicate(true))
	return out


func _log_slots_from_load(raw: Variant) -> Array:
	var out: Array = []
	for _i in LOG_SLOT_COUNT:
		out.append(null)
	if typeof(raw) != TYPE_ARRAY:
		return out
	var ra: Array = raw
	var write_idx := 0
	for i in ra.size():
		if write_idx >= LOG_SLOT_COUNT:
			break
		var e: Variant = ra[i]
		if e == null or typeof(e) != TYPE_DICTIONARY:
			continue
		var item_id := str((e as Dictionary).get("id", ""))
		if item_id.is_empty():
			continue
		out[write_idx] = {"id": item_id}
		write_idx += 1
		# Legacy save stored count > 1 per slot; spill the surplus back to the player.
		var count := int((e as Dictionary).get("count", 1))
		if count > 1:
			_legacy_log_spill[item_id] = int(_legacy_log_spill.get(item_id, 0)) + (count - 1)
	return out


func _apply_legacy_log_spill() -> void:
	for id in _legacy_log_spill.keys():
		var n := int(_legacy_log_spill[id])
		if n > 0:
			InventoryService.add_item(str(id), n)
	_legacy_log_spill.clear()


func _load_state() -> void:
	_init_slot_arrays()
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		_is_lit = start_lit
		_fuel_seconds = float(seconds_per_log) if start_lit else 0.0
		_logs_burned_counter = 0
		_ash_waiting_pickup = false
		_pending_charcoal_count = 0
		return
	var key: String = _state_key()
	if "world_fire_states" in gs and gs.world_fire_states.has(key):
		var d: Variant = gs.world_fire_states.get(key, {})
		if typeof(d) == TYPE_DICTIONARY:
			_is_lit = bool(d.get("lit", start_lit))
			_fuel_seconds = maxf(0.0, float(d.get("fuel_seconds", float(seconds_per_log) if _is_lit else 0.0)))
			_logs_burned_counter = maxi(0, int(d.get("logs_burned_counter", 0)))
			_log_slots = _log_slots_from_load(d.get("log_slots", []))
			var ca: Variant = d.get("cook_active", {})
			if typeof(ca) == TYPE_DICTIONARY and not (ca as Dictionary).is_empty():
				_cook_active = (ca as Dictionary).duplicate(true)
				var cp: Variant = d.get("cook_progress_sec", 0.0)
				if typeof(cp) == TYPE_FLOAT or typeof(cp) == TYPE_INT:
					_cook_progress_sec = float(cp)
				else:
					_cook_progress_sec = 0.0
			else:
				_cook_active = {}
				_cook_progress_sec = 0.0
			_cook_auto_enabled = bool(d.get("cook_auto_enabled", false))
			_ash_waiting_pickup = bool(d.get("ash_waiting_pickup", false))
			_pending_charcoal_count = maxi(0, int(d.get("pending_charcoal_count", 0)))
			if _ash_waiting_pickup:
				call_deferred("_apply_burned_logs_visual", true)
			return
	_is_lit = start_lit
	_fuel_seconds = float(seconds_per_log) if start_lit else 0.0
	_logs_burned_counter = 0
	_ash_waiting_pickup = false
	_pending_charcoal_count = 0


func _save_state() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or not ("world_fire_states" in gs):
		return
	gs.world_fire_states[_state_key()] = {
		"lit": _is_lit,
		"fuel_seconds": _fuel_seconds,
		"logs_burned_counter": _logs_burned_counter,
		"log_slots": _slot_dict_to_save(_log_slots),
		"cook_active": _cook_active.duplicate(true),
		"cook_progress_sec": _cook_progress_sec,
		"cook_auto_enabled": _cook_auto_enabled,
		"ash_waiting_pickup": _ash_waiting_pickup,
		"pending_charcoal_count": _pending_charcoal_count,
	}
