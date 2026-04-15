extends Node3D

## Outdoor world root: instances region scenes (e.g. main island) and hosts the world map overlay.

var _world_map_layer: CanvasLayer


func _ready() -> void:
	_world_map_layer = get_node_or_null("WorldMapLayer") as CanvasLayer
	if _world_map_layer:
		_world_map_layer.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _world_map_layer == null:
		return
	if event.is_action_pressed(&"toggle_world_map"):
		_toggle_world_map()
		get_viewport().set_input_as_handled()


func _toggle_world_map() -> void:
	if _world_map_layer == null:
		return
	_world_map_layer.visible = not _world_map_layer.visible
	if _world_map_layer.visible:
		var overlay: Control = _world_map_layer.get_node_or_null("WorldMapOverlay") as Control
		if overlay and overlay.has_method("grab_focus_for_map"):
			overlay.grab_focus_for_map()
