extends Node3D

const _GameState = preload("res://autoload/game_state.gd")

const _AnimalChickenScene = preload("res://entities/characters/animals/chicken.tscn")
const _AnimalRabbitScene = preload("res://entities/characters/animals/rabbit.tscn")
const _AnimalRoosterScene = preload("res://entities/characters/animals/rooster.tscn")
const _AnimalChickScene = preload("res://entities/characters/animals/chick.tscn")


func _ready() -> void:
	_setup_tutorial_animals_if_needed()
	call_deferred("_maybe_shore_wake_after_intro")


func _maybe_shore_wake_after_intro() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null or not (gs is _GameState):
		return
	var state := gs as _GameState
	if not state.pending_shore_wake:
		return
	state.pending_shore_wake = false
	var player := get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return
	if player.has_method("set_input_enabled"):
		player.set_input_enabled(false)
	var toast: Node = player.get_node_or_null("GameplayToast")
	if toast != null and toast.has_method("show_message"):
		toast.call("show_message", "You wake on a strange shore.")
	await get_tree().create_timer(3.5).timeout
	if player != null and is_instance_valid(player) and player.has_method("set_input_enabled"):
		player.set_input_enabled(true)


func _setup_tutorial_animals_if_needed() -> void:
	var gameplay_root := get_node_or_null("AnimalsGameplay") as Node3D
	if gameplay_root != null and gameplay_root.get_child_count() > 0:
		return
	var source_root := _resolve_source_animals_root()
	if source_root == null:
		return
	if source_root.get_name() == &"Wildlife":
		return
	gameplay_root = Node3D.new()
	gameplay_root.name = "AnimalsGameplay"
	gameplay_root.transform = source_root.transform
	add_child(gameplay_root)
	var scene_by_name := {
		"Chicken": _AnimalChickenScene,
		"Rabbit": _AnimalRabbitScene,
		"Rooster": _AnimalRoosterScene,
		"Chick": _AnimalChickScene,
	}
	var spawned_count := 0
	for key in scene_by_name.keys():
		var source_spawn := source_root.get_node_or_null(String(key)) as Node3D
		if source_spawn == null:
			continue
		var animal_scene: PackedScene = scene_by_name[key]
		if animal_scene == null:
			continue
		var inst := animal_scene.instantiate()
		gameplay_root.add_child(inst)
		if inst is Node3D:
			(inst as Node3D).transform = source_spawn.transform
		spawned_count += 1
	if spawned_count > 0:
		source_root.visible = false
	else:
		gameplay_root.queue_free()


func _resolve_source_animals_root() -> Node3D:
	var wildlife := get_node_or_null("Wildlife") as Node3D
	if wildlife != null and wildlife.get_child_count() > 0:
		return wildlife
	return get_node_or_null("Animals") as Node3D
