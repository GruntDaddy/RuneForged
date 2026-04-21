extends Control

@onready var anim_player: AnimationPlayer = $AnimationPlayer

@onready var load_game_button: Button = $ButtonContainer/ButtonPanel/ButtonRow_1/LoadGameButton
@onready var new_game_button: Button = $ButtonContainer/ButtonPanel/ButtonRow_2/NewGameButton
@onready var options_button: Button = $ButtonContainer/ButtonPanel/ButtonRow_3/OptionsButton
@onready var quit_button: Button = $ButtonRow_4/QuitButton

var _pending_scene: String = ""


func _ready() -> void:
	anim_player.play("fade_in")
	anim_player.animation_finished.connect(_on_animation_finished)

	load_game_button.pressed.connect(_on_load_pressed)
	new_game_button.pressed.connect(_on_new_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_animation_finished(anim_name: StringName) -> void:
	if String(anim_name) == "fade_out":
		if _pending_scene != "":
			SceneManager.fade_to_scene(_pending_scene)
			_pending_scene = ""


func _on_new_pressed() -> void:
	GameState.reset()
	InventoryService.clear_all_slots()
	_pending_scene = GameState.SCENE_CHARACTER_CREATOR
	anim_player.play("fade_out")


func _on_load_pressed() -> void:
	var ok := SaveManager.load_game()
	if ok:
		_pending_scene = GameState.scene_path_for_saved_region(GameState.region)
	else:
		# No save yet – fall back to fresh character creation
		GameState.reset()
		InventoryService.clear_all_slots()
		_pending_scene = GameState.SCENE_CHARACTER_CREATOR

	anim_player.play("fade_out")


func _on_options_pressed() -> void:
	_pending_scene = GameState.SCENE_OPTIONS_MENU
	anim_player.play("fade_out")


func _on_quit_pressed() -> void:
	_pending_scene = ""
	anim_player.play("fade_out")
	await anim_player.animation_finished
	get_tree().quit()
