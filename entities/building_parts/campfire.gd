extends Node3D

const LOG_SLOT_COUNT := 4
const COOK_SLOT_COUNT := 2
const COOK_TIME_SEC := 24.0

const _PANEL_SCENE := preload("res://ui/hud/campfire_inventory_panel.tscn")

@export var fire_state_id: String = ""
@export var start_lit: bool = true
@export var seconds_per_log: float = 120.0
@export var initial_logs_on_ignite: int = 2
@export var auto_extinguish_when_empty: bool = true
@export var ignite_log_cost: int = 1
@export var fuel_add_log_cost: int = 1
@export var charcoal_per_logs_burned: int = 2
@export var rest_warmth_minutes: float = 10.0
@export var warmth_night_run_bonus: float = 0.2
@export var warmth_night_penalty: float = 0.15
## Deprecated: torch recipes moved to workbench; left empty for saves/scenes that still set it.
@export var campfire_recipe_ids: PackedStringArray = PackedStringArray()

@onready var _light: OmniLight3D = $OmniLight3D
@onready var _fire_mesh: MeshInstance3D = $FireMesh
@onready var _smoke: GPUParticles3D = $SmokeParticles
@onready var _audio: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var _logs_visual: Node3D = $Campfire_Logs

var _is_lit: bool = false
var _fuel_seconds: float = 0.0
var _flicker_t: float = 0.0
var _logs_burned_counter: int = 0

var _log_slots: Array = [] ## Array of null or { "id": String, "count": int } — only "logs"
var _cook_slots: Array = []
var _cook_progress_sec: Array = []


func _ready() -> void:
	_init_slot_arrays()
	_load_state()
	_apply_visuals()


func _init_slot_arrays() -> void:
	_log_slots.clear()
	for _i in LOG_SLOT_COUNT:
		_log_slots.append(null)
	_cook_slots.clear()
	for _i in COOK_SLOT_COUNT:
		_cook_slots.append(null)
	_cook_progress_sec.clear()
	for _i in COOK_SLOT_COUNT:
		_cook_progress_sec.append(0.0)


func _process(delta: float) -> void:
	if not _is_lit:
		return
	_fuel_seconds = maxf(0.0, _fuel_seconds - delta)
	if auto_extinguish_when_empty and _fuel_seconds <= 0.0:
		extinguish()
		return
	_flicker_t += delta * 4.4
	var wave: float = sin(_flicker_t) * 0.58 + sin(_flicker_t * 0.41 + 0.75) * 0.33
	_light.light_energy = maxf(0.1, 2.15 + wave * 0.45)
	_light.omni_range = maxf(1.0, 10.5 + wave * 1.15)
	_tick_cooking(delta)


func _tick_cooking(delta: float) -> void:
	for i in COOK_SLOT_COUNT:
		var slot: Variant = _cook_slots[i]
		if slot == null:
			_cook_progress_sec[i] = 0.0
			continue
		var sid := str(slot.get("id", ""))
		var cnt := int(slot.get("count", 0))
		if sid != "meat_raw" or cnt <= 0:
			_cook_progress_sec[i] = 0.0
			continue
		_cook_progress_sec[i] = float(_cook_progress_sec[i]) + delta
		if float(_cook_progress_sec[i]) >= COOK_TIME_SEC:
			_cook_progress_sec[i] = 0.0
			cnt -= 1
			if cnt <= 0:
				_cook_slots[i] = null
			else:
				_cook_slots[i] = {"id": "meat_raw", "count": cnt}
			var left: int = InventoryService.add_item("meat_cooked", 1)
			if left > 0:
				_notify_nearby("Inventory full — cooked meat fell into the ash.")
			else:
				_notify_nearby("Meat cooked.")
			_save_state()


func get_interaction_prompt(_player: Node) -> String:
	return "E: Campfire"


func interact(player: Node) -> bool:
	if player == null:
		return false
	if _is_lit and _try_light_equipped_torch(player):
		return true
	_open_panel(player)
	return true


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


func _open_panel(player: Node) -> void:
	var panel: CanvasLayer = _ensure_panel(player)
	if panel != null and panel.has_method("open"):
		panel.call("open", self, player)


func _ensure_panel(player: Node) -> CanvasLayer:
	if player == null:
		return null
	var existing: Node = player.get_node_or_null("CampfireInventoryPanel")
	if existing != null:
		return existing as CanvasLayer
	var p: CanvasLayer = _PANEL_SCENE.instantiate()
	p.name = "CampfireInventoryPanel"
	player.add_child(p)
	return p


func build_slot_refresh_payload() -> Dictionary:
	var can_light := (not _is_lit) and _player_has_tinderbox() and _total_logs_in_slots() >= ignite_log_cost
	return {"is_lit": _is_lit, "can_light": can_light}


func get_panel_hint_text() -> String:
	if not _is_lit:
		if not _player_has_tinderbox():
			return "Need a tinderbox in inventory to ignite. Stock logs in the slots below."
		if _total_logs_in_slots() < ignite_log_cost:
			return "Need at least %d log(s) in the fire to ignite." % ignite_log_cost
		return "Ready to light when you press Light fire."
	return "Fire burns fuel from log slots. Rest saves like before."


func get_log_slot_dict(idx: int) -> Dictionary:
	if idx < 0 or idx >= LOG_SLOT_COUNT:
		return {}
	var s: Variant = _log_slots[idx]
	if s == null:
		return {}
	return s


func get_cook_slot_dict(idx: int) -> Dictionary:
	if idx < 0 or idx >= COOK_SLOT_COUNT:
		return {}
	var s: Variant = _cook_slots[idx]
	if s == null:
		return {}
	var d: Dictionary = (s as Dictionary).duplicate(true)
	if idx < _cook_progress_sec.size():
		d["progress"] = float(_cook_progress_sec[idx]) / COOK_TIME_SEC
	return d


func panel_cycle_log_slot(idx: int, player: Node) -> void:
	if idx < 0 or idx >= LOG_SLOT_COUNT:
		return
	var s: Variant = _log_slots[idx]
	if s != null:
		var cnt := int(s.get("count", 0))
		if cnt > 0:
			var take: int = mini(cnt, 1)
			var left: int = InventoryService.add_item("logs", take)
			var added: int = take - left
			if added <= 0:
				_notify_player(player, "Inventory full.")
				return
			cnt -= added
			if cnt <= 0:
				_log_slots[idx] = null
			else:
				_log_slots[idx] = {"id": "logs", "count": cnt}
			_save_state()
			_apply_log_visuals()
			return
	# Empty slot: deposit one log from player
	if int(InventoryService.get_item_count("logs")) < 1:
		_notify_player(player, "No logs in inventory.")
		return
	InventoryService.remove_item("logs", 1)
	_add_logs_to_slot_amount(idx, 1)
	_save_state()
	_apply_log_visuals()


func panel_cycle_cook_slot(idx: int, player: Node) -> void:
	if idx < 0 or idx >= COOK_SLOT_COUNT:
		return
	var s: Variant = _cook_slots[idx]
	if s != null:
		var iid := str(s.get("id", ""))
		var cnt := int(s.get("count", 0))
		if iid == "meat_raw" and cnt > 0:
			var left: int = InventoryService.add_item("meat_raw", 1)
			if left > 0:
				_notify_player(player, "Inventory full.")
				return
			cnt -= 1
			_cook_progress_sec[idx] = 0.0
			if cnt <= 0:
				_cook_slots[idx] = null
			else:
				_cook_slots[idx] = {"id": "meat_raw", "count": cnt}
			_save_state()
			return
	# deposit raw meat
	if int(InventoryService.get_item_count("meat_raw")) < 1:
		_notify_player(player, "No raw meat in inventory.")
		return
	InventoryService.remove_item("meat_raw", 1)
	var it_meat: ItemData = ItemCatalog.get_item("meat_raw")
	var mx: int = it_meat.max_stack if it_meat != null else 99
	if _cook_slots[idx] == null:
		_cook_slots[idx] = {"id": "meat_raw", "count": 1}
	else:
		var oc := int(_cook_slots[idx].get("count", 0))
		if oc >= mx:
			InventoryService.add_item("meat_raw", 1)
			_notify_player(player, "Cooking slot full.")
			return
		_cook_slots[idx] = {"id": "meat_raw", "count": oc + 1}
	_cook_progress_sec[idx] = 0.0
	_save_state()


func panel_deposit_one_log(player: Node) -> void:
	if int(InventoryService.get_item_count("logs")) < 1:
		_notify_player(player, "No logs to deposit.")
		return
	for i in LOG_SLOT_COUNT:
		if _log_slots[i] == null:
			InventoryService.remove_item("logs", 1)
			_log_slots[i] = {"id": "logs", "count": 1}
			_save_state()
			_apply_log_visuals()
			return
		var sid := str(_log_slots[i].get("id", ""))
		var cnt := int(_log_slots[i].get("count", 0))
		if sid == "logs":
			var it: ItemData = ItemCatalog.get_item("logs")
			var mx: int = it.max_stack if it != null else 99
			if cnt < mx:
				InventoryService.remove_item("logs", 1)
				_log_slots[i] = {"id": "logs", "count": cnt + 1}
				_save_state()
				_apply_log_visuals()
				return
	_notify_player(player, "Log slots are full.")


func panel_take_one_log(player: Node) -> void:
	for i in range(LOG_SLOT_COUNT - 1, -1, -1):
		var s: Variant = _log_slots[i]
		if s == null:
			continue
		var cnt := int(s.get("count", 0))
		if cnt <= 0:
			continue
		var left: int = InventoryService.add_item("logs", 1)
		if left > 0:
			_notify_player(player, "Inventory full.")
			return
		cnt -= 1
		if cnt <= 0:
			_log_slots[i] = null
		else:
			_log_slots[i] = {"id": "logs", "count": cnt}
		_save_state()
		_apply_log_visuals()
		return
	_notify_player(player, "No logs in the fire.")


func panel_try_light(player: Node) -> void:
	if _is_lit:
		return
	if not _player_has_tinderbox():
		_notify_player(player, "You need a tinderbox to light the fire.")
		return
	if not _consume_logs_from_slots(ignite_log_cost):
		_notify_player(player, "Need %d log(s) in the fire to light it." % ignite_log_cost)
		return
	light_fire(initial_logs_on_ignite)
	_apply_log_visuals()
	_notify_player(player, "Campfire lit.")


func panel_rest_save(player: Node) -> void:
	if not _is_lit:
		_notify_player(player, "Light the fire first.")
		return
	_apply_rest_and_save(player)


func _player_has_tinderbox() -> bool:
	return int(InventoryService.get_item_count("tinderbox")) > 0


func _total_logs_in_slots() -> int:
	var t := 0
	for i in LOG_SLOT_COUNT:
		var s: Variant = _log_slots[i]
		if s == null:
			continue
		if str(s.get("id", "")) == "logs":
			t += int(s.get("count", 0))
	return t


func _consume_logs_from_slots(amount: int) -> bool:
	var need := amount
	if need <= 0:
		return true
	for i in LOG_SLOT_COUNT:
		var s: Variant = _log_slots[i]
		if s == null:
			continue
		if str(s.get("id", "")) != "logs":
			continue
		var cnt := int(s.get("count", 0))
		if cnt <= 0:
			continue
		var take := mini(cnt, need)
		cnt -= take
		need -= take
		if cnt <= 0:
			_log_slots[i] = null
		else:
			_log_slots[i] = {"id": "logs", "count": cnt}
		if need <= 0:
			return true
	return false


func _add_logs_to_slot_amount(slot_idx: int, amount: int) -> void:
	if amount <= 0 or slot_idx < 0 or slot_idx >= LOG_SLOT_COUNT:
		return
	var s: Variant = _log_slots[slot_idx]
	if s == null:
		_log_slots[slot_idx] = {"id": "logs", "count": amount}
		return
	var cnt := int(s.get("count", 0))
	_log_slots[slot_idx] = {"id": "logs", "count": cnt + amount}


func light_fire(logs_to_add: int = 0) -> void:
	_is_lit = true
	if logs_to_add > 0:
		_add_fuel_logs(logs_to_add)
	elif _fuel_seconds <= 0.0:
		_fuel_seconds = seconds_per_log
	_save_state()
	_apply_visuals()


func extinguish() -> void:
	_is_lit = false
	_save_state()
	_apply_visuals()


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


func _add_fuel_logs(log_count: int) -> void:
	if log_count <= 0:
		return
	_fuel_seconds += seconds_per_log * float(log_count)
	_logs_burned_counter += log_count
	_mint_charcoal_from_logs()


func _mint_charcoal_from_logs() -> void:
	if charcoal_per_logs_burned <= 0:
		return
	var grants := int(floor(float(_logs_burned_counter) / float(charcoal_per_logs_burned)))
	if grants <= 0:
		return
	_logs_burned_counter -= grants * charcoal_per_logs_burned
	InventoryService.add_item("charcoal", grants)


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
	if _smoke != null:
		_smoke.emitting = _is_lit
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
		_logs_visual.visible = _total_logs_in_slots() > 0


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


func _slot_dict_from_load(raw: Variant, template_size: int) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		for _i in template_size:
			out.append(null)
		return out
	var ra: Array = raw
	for i in template_size:
		if i < ra.size():
			var e: Variant = ra[i]
			if e == null or typeof(e) != TYPE_DICTIONARY:
				out.append(null)
			else:
				out.append((e as Dictionary).duplicate(true))
		else:
			out.append(null)
	return out


func _load_state() -> void:
	_init_slot_arrays()
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		_is_lit = start_lit
		_fuel_seconds = seconds_per_log if start_lit else 0.0
		_logs_burned_counter = 0
		return
	var key: String = _state_key()
	if "world_fire_states" in gs and gs.world_fire_states.has(key):
		var d: Variant = gs.world_fire_states.get(key, {})
		if typeof(d) == TYPE_DICTIONARY:
			_is_lit = bool(d.get("lit", start_lit))
			_fuel_seconds = maxf(0.0, float(d.get("fuel_seconds", seconds_per_log if _is_lit else 0.0)))
			_logs_burned_counter = maxi(0, int(d.get("logs_burned_counter", 0)))
			_log_slots = _slot_dict_from_load(d.get("log_slots", []), LOG_SLOT_COUNT)
			_cook_slots = _slot_dict_from_load(d.get("cook_slots", []), COOK_SLOT_COUNT)
			var cp: Variant = d.get("cook_progress_sec", [])
			if typeof(cp) == TYPE_ARRAY:
				var cpa: Array = cp
				for i in mini(COOK_SLOT_COUNT, cpa.size()):
					_cook_progress_sec[i] = float(cpa[i])
			return
	_is_lit = start_lit
	_fuel_seconds = seconds_per_log if start_lit else 0.0
	_logs_burned_counter = 0


func _save_state() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or not ("world_fire_states" in gs):
		return
	var cp: Array = []
	for i in COOK_SLOT_COUNT:
		cp.append(float(_cook_progress_sec[i]))
	gs.world_fire_states[_state_key()] = {
		"lit": _is_lit,
		"fuel_seconds": _fuel_seconds,
		"logs_burned_counter": _logs_burned_counter,
		"log_slots": _slot_dict_to_save(_log_slots),
		"cook_slots": _slot_dict_to_save(_cook_slots),
		"cook_progress_sec": cp,
	}
