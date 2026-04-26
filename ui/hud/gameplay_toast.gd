extends CanvasLayer

## Short non-blocking messages (harvest, inventory full). Bottom-center fade.

@onready var _label: Label = $Margin/Label

var _fade_tween: Tween
var _stacked_messages: Array[Dictionary] = []
const _MAX_STACKED_LINES := 4


func _ready() -> void:
	layer = 35
	if _label:
		_label.visible = false
		_label.modulate.a = 1.0
		_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP


func show_message(text: String) -> void:
	if _label == null:
		return
	var msg := text.strip_edges()
	if msg.is_empty():
		return
	if not _stacked_messages.is_empty():
		var last_idx := _stacked_messages.size() - 1
		var last := _stacked_messages[last_idx]
		if str(last.get("text", "")) == msg:
			last["count"] = int(last.get("count", 1)) + 1
			_stacked_messages[last_idx] = last
		else:
			_stacked_messages.append({"text": msg, "count": 1})
	else:
		_stacked_messages.append({"text": msg, "count": 1})
	while _stacked_messages.size() > _MAX_STACKED_LINES:
		_stacked_messages.pop_front()
	var lines: PackedStringArray = []
	for i in range(_stacked_messages.size() - 1, -1, -1):
		var row := _stacked_messages[i]
		var row_text := str(row.get("text", ""))
		var row_count := int(row.get("count", 1))
		if row_count > 1:
			row_text += "  [+%d]" % row_count
		lines.append(row_text)
	_label.text = "\n".join(lines)
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
		_stacked_messages.clear()
	)
