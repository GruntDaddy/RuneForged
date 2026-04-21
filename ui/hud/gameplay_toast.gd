extends CanvasLayer

## Short non-blocking messages (harvest, inventory full). Bottom-center fade.

@onready var _label: Label = $Margin/Label

var _fade_tween: Tween


func _ready() -> void:
	layer = 35
	if _label:
		_label.visible = false
		_label.modulate.a = 1.0


func show_message(text: String) -> void:
	if _label == null:
		return
	_label.text = text
	_label.visible = true
	_label.modulate.a = 1.0
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_interval(2.8)
	_fade_tween.tween_property(_label, "modulate:a", 0.0, 0.45)
	_fade_tween.tween_callback(func() -> void:
		if _label:
			_label.visible = false
			_label.modulate.a = 1.0
	)
