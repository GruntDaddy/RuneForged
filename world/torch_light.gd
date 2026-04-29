extends Node3D

@export var fire_state_id: String = ""
@export var start_lit: bool = false
@export var seconds_per_log: float = 120.0
@export var initial_logs_on_ignite: int = 1
@export var auto_extinguish_when_empty: bool = true
@export var ignite_log_cost: int = 1
@export var fuel_add_log_cost: int = 1
@export var charcoal_per_logs_burned: int = 2
@export var flicker_base_energy: float = 1.35
@export var flicker_energy_amount: float = 0.26
@export var flicker_speed: float = 5.8
@export var flicker_range_base: float = 7.0
@export var flicker_range_amount: float = 0.65

@onready var _light: OmniLight3D = $OmniLight3D
@onready var _flame: GPUParticles3D = $FlameParticles

var _is_lit: bool = false
var _fuel_seconds: float = 0.0
var _flicker_t: float = 0.0
var _logs_burned_counter: int = 0


func _ready() -> void:
	_load_state()
	_apply_visuals()


func _process(delta: float) -> void:
	if _is_lit:
		_fuel_seconds = maxf(0.0, _fuel_seconds - delta)
		if auto_extinguish_when_empty and _fuel_seconds <= 0.0:
			extinguish()
			return
		_flicker_t += delta * flicker_speed
		var wave: float = sin(_flicker_t) * 0.5 + sin(_flicker_t * 0.63 + 1.1) * 0.35
		_light.light_energy = maxf(0.05, flicker_base_energy + wave * flicker_energy_amount)
		_light.omni_range = maxf(1.0, flicker_range_base + wave * flicker_range_amount)


func get_interaction_prompt(_player: Node) -> String:
	if _is_lit:
		return "E: Add fuel to torch (+%d log)" % fuel_add_log_cost
	return "E: Ignite torch (%d log)" % ignite_log_cost


func interact(player: Node) -> bool:
	if _is_lit:
		if not _consume_logs(player, fuel_add_log_cost):
			_notify_player(player, "Need %d log to fuel this torch." % fuel_add_log_cost)
			return false
		_add_fuel_logs(fuel_add_log_cost)
		_notify_player(player, "Torch fueled (+%ds)." % int(seconds_per_log * float(fuel_add_log_cost)))
		return true
	if not _consume_logs(player, ignite_log_cost):
		_notify_player(player, "Need %d logs to light this torch." % ignite_log_cost)
		return false
	light_torch(initial_logs_on_ignite)
	_notify_player(player, "Torch lit.")
	return true


func light_torch(logs_to_add: int = 0) -> void:
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


func _consume_logs(_player: Node, amount: int) -> bool:
	var inv: Node = get_node_or_null("/root/InventoryService")
	if inv == null or not inv.has_method("get_item_count") or not inv.has_method("remove_item"):
		return false
	if int(inv.get_item_count("logs")) < amount:
		return false
	inv.remove_item("logs", amount)
	return true


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


func _apply_visuals() -> void:
	_light.visible = _is_lit
	_flame.emitting = _is_lit
	if _is_lit:
		_light.light_energy = maxf(0.8, flicker_base_energy)
		_light.omni_range = maxf(3.0, flicker_range_base)


func _state_key() -> String:
	if not fire_state_id.is_empty():
		return fire_state_id
	return str(get_path())


func _load_state() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		_is_lit = start_lit
		_fuel_seconds = seconds_per_log if start_lit else 0.0
		return
	var key: String = _state_key()
	if "world_fire_states" in gs and gs.world_fire_states.has(key):
		var d: Variant = gs.world_fire_states.get(key, {})
		if typeof(d) == TYPE_DICTIONARY:
			_is_lit = bool(d.get("lit", start_lit))
			_fuel_seconds = maxf(0.0, float(d.get("fuel_seconds", seconds_per_log if _is_lit else 0.0)))
			_logs_burned_counter = maxi(0, int(d.get("logs_burned_counter", 0)))
			return
	_is_lit = start_lit
	_fuel_seconds = seconds_per_log if start_lit else 0.0
	_logs_burned_counter = 0


func _save_state() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or not ("world_fire_states" in gs):
		return
	gs.world_fire_states[_state_key()] = {
		"lit": _is_lit,
		"fuel_seconds": _fuel_seconds,
		"logs_burned_counter": _logs_burned_counter,
	}
