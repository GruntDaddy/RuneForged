extends Control

@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.mouse_entered.connect(_on_back_hover)


func _on_back_hover() -> void:
	var ga: Node = get_tree().root.get_node_or_null("GameAudio")
	if ga != null and ga.has_method("play_ui_hover"):
		ga.call("play_ui_hover")


func _on_back_pressed() -> void:
	var ga: Node = get_tree().root.get_node_or_null("GameAudio")
	if ga != null and ga.has_method("play_ui_confirm"):
		ga.call("play_ui_confirm")
	SceneManager.fade_to_scene(GameState.SCENE_MAIN_MENU)
