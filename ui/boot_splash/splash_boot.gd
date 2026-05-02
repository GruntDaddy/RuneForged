extends Control

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var start_button: Button = $StartScreen_Bg/ButtonPanel/StartButton


func _ready() -> void:
	var ga: Node = get_tree().root.get_node_or_null("GameAudio")
	if ga != null and not String(scene_file_path).is_empty() and ga.has_method("apply_music_for_scene_path"):
		ga.call("apply_music_for_scene_path", scene_file_path)
	# Start the boot animation when the scene loads.
	anim_player.play("splash_boot")

	# Handle chaining between splash_boot, start_screen, and fade_out.
	anim_player.animation_finished.connect(_on_animation_finished)

	# Hook up the Start button.
	start_button.pressed.connect(_on_start_button_pressed)


func _on_animation_finished(anim_name: StringName) -> void:
	match String(anim_name):
		"splash_boot":
			# When the logo boot finishes, show the start screen.
			anim_player.play("start_screen")
		"start_screen":
			# Sit on the start screen until the player hits Start.
			pass
		"fade_out":
			# After the fade_out completes, transition to the main menu.
			SceneManager.fade_to_scene(GameState.SCENE_MAIN_MENU)


func _on_start_button_pressed() -> void:
	var ga: Node = get_tree().root.get_node_or_null("GameAudio")
	if ga != null and ga.has_method("play_ui_confirm"):
		ga.call("play_ui_confirm")
	# Player clicked Start: run your fade_out animation.
	anim_player.play("fade_out")
