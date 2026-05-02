extends Node

const FADE_SECONDS := 0.45

var _layer: CanvasLayer
var _fade: ColorRect


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.offset_left = 0.0
	_fade.offset_top = 0.0
	_fade.offset_right = 0.0
	_fade.offset_bottom = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate = Color(1, 1, 1, 0)
	_layer.add_child(_fade)


func fade_to_scene(path: String) -> void:
	await _fade_out()
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneManager: failed to load %s (error %s)" % [path, err])
	else:
		GameAudio.apply_music_for_scene_path(path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_in()


func _fade_out() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_fade, "modulate:a", 1.0, FADE_SECONDS)
	await tw.finished


func _fade_in() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_fade, "modulate:a", 0.0, FADE_SECONDS)
	await tw.finished
