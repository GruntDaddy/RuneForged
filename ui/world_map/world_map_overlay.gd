extends Control

const _WORLD_MAP_REGISTRY_SCRIPT = preload("res://scripts/world/world_map_registry.gd")

## Full-screen world map: hover shows region name from WorldMapRegistry.

var _registry: RefCounted

@onready var _map_texture: TextureRect = %MapTexture
@onready var _region_label: Label = %RegionLabel
@onready var _blurb_label: Label = %BlurbLabel
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	_registry = _WORLD_MAP_REGISTRY_SCRIPT.new() as RefCounted
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_close_button.pressed.connect(_on_close_pressed)
	if _map_texture:
		_map_texture.gui_input.connect(_on_map_texture_gui_input)
		_map_texture.mouse_entered.connect(_on_map_mouse_entered)
		_map_texture.mouse_exited.connect(_on_map_mouse_exited)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_close_map()
		get_viewport().set_input_as_handled()


func grab_focus_for_map() -> void:
	grab_focus()
	if _map_texture:
		_map_texture.grab_focus()


func _close_map() -> void:
	var layer: CanvasLayer = get_parent() as CanvasLayer
	if layer:
		layer.visible = false
	else:
		visible = false


func _on_close_pressed() -> void:
	_close_map()


func _on_map_mouse_entered() -> void:
	pass


func _on_map_mouse_exited() -> void:
	if _region_label:
		_region_label.text = ""
	if _blurb_label:
		_blurb_label.text = ""


func _on_map_texture_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var uv := _uv_in_texture_rect(_map_texture, _map_texture.get_local_mouse_position())
		var reg: Dictionary = _registry.call("get_region_at_normalized", uv) as Dictionary
		if reg.is_empty():
			if _region_label:
				_region_label.text = ""
			if _blurb_label:
				_blurb_label.text = ""
			return
		if _region_label:
			_region_label.text = str(reg.get("display_name", reg.get("id", "?")))
		if _blurb_label:
			_blurb_label.text = str(reg.get("blurb", ""))


static func _uv_in_texture_rect(texture_rect: TextureRect, local: Vector2) -> Vector2:
	var sz: Vector2 = texture_rect.size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return Vector2(0.5, 0.5)
	return Vector2(clampf(local.x / sz.x, 0.0, 1.0), clampf(local.y / sz.y, 0.0, 1.0))
