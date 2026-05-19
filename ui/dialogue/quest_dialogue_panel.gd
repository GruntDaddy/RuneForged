extends CanvasLayer

@onready var _backdrop: ColorRect = $Backdrop
@onready var _panel: PanelContainer = $Panel
@onready var _speaker_label: Label = $Panel/Margin/VBox/SpeakerLabel
@onready var _body_label: RichTextLabel = $Panel/Margin/VBox/BodyLabel
@onready var _continue_btn: Button = $Panel/Margin/VBox/ContinueButton

var _lines: PackedStringArray = PackedStringArray()
var _line_index: int = 0
var _on_finished: Callable = Callable()
var _player: Node = null


func _ready() -> void:
	layer = 90
	visible = false
	_continue_btn.pressed.connect(_on_continue_pressed)


func show_dialogue(speaker_name: String, lines: PackedStringArray, on_finished: Callable) -> void:
	_lines = lines
	_line_index = 0
	_on_finished = on_finished
	_speaker_label.text = speaker_name
	_set_player_input_blocked(true)
	_show_current_line()
	visible = true


func _show_current_line() -> void:
	if _line_index >= _lines.size():
		_close()
		return
	_body_label.text = _lines[_line_index]
	_continue_btn.text = "Continue" if _line_index < _lines.size() - 1 else "Done"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_on_continue_pressed()
		get_viewport().set_input_as_handled()


func _on_continue_pressed() -> void:
	_line_index += 1
	_show_current_line()


func _close() -> void:
	visible = false
	_set_player_input_blocked(false)
	if _on_finished.is_valid():
		_on_finished.call()


func _set_player_input_blocked(blocked: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player")
	if player != null and player.has_method("set_input_enabled"):
		player.call("set_input_enabled", not blocked)
	if blocked:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif player != null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
