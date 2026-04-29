extends Node3D

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
@export var campfire_recipe_ids: PackedStringArray = PackedStringArray(["craft_torch_basic"])

@onready var _light: OmniLight3D = $OmniLight3D
@onready var _flame: GPUParticles3D = $FlameParticles
@onready var _embers: GPUParticles3D = $EmberParticles
@onready var _audio: AudioStreamPlayer3D = $AudioStreamPlayer3D

var _is_lit: bool = false
var _fuel_seconds: float = 0.0
var _flicker_t: float = 0.0
var _logs_burned_counter: int = 0


func _ready() -> void:
	_load_state()
	_apply_visuals()


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


func get_interaction_prompt(_player: Node) -> String:
	if _is_lit:
		return "E: Tend fire (+%d log) / Rest / Save" % fuel_add_log_cost
	return "E: Light campfire (%d log)" % ignite_log_cost


func interact(player: Node) -> bool:
	if not _is_lit:
		if not _consume_logs(ignite_log_cost):
			_notify_player(player, "Need %d log to light the campfire." % ignite_log_cost)
			return false
		light_fire(initial_logs_on_ignite)
		_notify_player(player, "Campfire lit.")
		return true
	if _consume_logs(fuel_add_log_cost):
		_add_fuel_logs(fuel_add_log_cost)
		_notify_player(player, "Campfire fueled (+%ds)." % int(seconds_per_log * float(fuel_add_log_cost)))
	_try_campfire_crafting(player)
	_apply_rest_and_save(player)
	return true


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


func _try_campfire_crafting(player: Node) -> void:
	var recipes: Node = get_node_or_null("/root/RecipeCatalog")
	var crafting: Node = get_node_or_null("/root/CraftingService")
	if recipes == null or crafting == null:
		return
	if not recipes.has_method("get_recipe") or not crafting.has_method("can_craft") or not crafting.has_method("craft"):
		return
	for recipe_id in campfire_recipe_ids:
		var id: String = str(recipe_id)
		if id.is_empty():
			continue
		var recipe: Variant = recipes.get_recipe(id)
		if recipe == null:
			continue
		if not crafting.can_craft(recipe, RecipeData.CraftStation.CAMPFIRE):
			continue
		if crafting.craft(recipe, RecipeData.CraftStation.CAMPFIRE):
			var label: String = str(recipe.display_name) if "display_name" in recipe else id
			_notify_player(player, "Crafted %s at campfire." % label)
			return


func _consume_logs(amount: int) -> bool:
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
	_embers.emitting = _is_lit
	if _is_lit:
		_light.light_energy = 2.35
		_light.omni_range = 11.0
		if not _audio.playing:
			_audio.play()
	else:
		_audio.stop()


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
