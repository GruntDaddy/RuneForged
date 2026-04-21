extends Control

@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	SceneManager.fade_to_scene(GameState.SCENE_MAIN_MENU)
