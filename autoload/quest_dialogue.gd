extends Node

const _PANEL_SCENE: PackedScene = preload("res://ui/dialogue/quest_dialogue_panel.tscn")

var _panel: CanvasLayer
var _busy: bool = false


func show_lines(speaker_name: String, lines: PackedStringArray, on_finished: Callable = Callable()) -> void:
	if lines.is_empty():
		if on_finished.is_valid():
			on_finished.call()
		return
	_ensure_panel()
	_busy = true
	_panel.call(
		"show_dialogue",
		speaker_name,
		lines,
		func() -> void:
			_busy = false
			if on_finished.is_valid():
				on_finished.call()
	)


func is_busy() -> bool:
	return _busy


func _ensure_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		return
	_panel = _PANEL_SCENE.instantiate() as CanvasLayer
	get_tree().root.add_child(_panel)
