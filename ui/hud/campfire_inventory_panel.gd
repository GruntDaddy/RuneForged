extends CanvasLayer
## Simple campfire UI: log slots, cooking slots, light, rest.

const _LOG_SLOTS := 4
const _COOK_SLOTS := 2

var _campfire: Node3D = null
var _player: Node = null

@onready var _backdrop: ColorRect = $Backdrop
@onready var _panel: PanelContainer = $CenterContainer/PanelContainer
@onready var _log_grid: GridContainer = $CenterContainer/PanelContainer/Margin/VBox/LogRow
@onready var _cook_grid: GridContainer = $CenterContainer/PanelContainer/Margin/VBox/CookRow
@onready var _hint: Label = $CenterContainer/PanelContainer/Margin/VBox/HintLabel
@onready var _btn_light: Button = $CenterContainer/PanelContainer/Margin/VBox/ButtonRow/LightButton
@onready var _btn_rest: Button = $CenterContainer/PanelContainer/Margin/VBox/ButtonRow/RestButton
@onready var _btn_close: Button = $CenterContainer/PanelContainer/Margin/VBox/ButtonRow/CloseButton
@onready var _btn_deposit_log: Button = $CenterContainer/PanelContainer/Margin/VBox/DepositRow/DepositLogButton
@onready var _btn_take_logs: Button = $CenterContainer/PanelContainer/Margin/VBox/DepositRow/TakeLogButton


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _backdrop != null:
		_backdrop.gui_input.connect(_on_backdrop_gui_input)
	if _btn_close != null:
		_btn_close.pressed.connect(close)
	if _btn_light != null:
		_btn_light.pressed.connect(_on_light_pressed)
	if _btn_rest != null:
		_btn_rest.pressed.connect(_on_rest_pressed)
	if _btn_deposit_log != null:
		_btn_deposit_log.pressed.connect(_on_deposit_log)
	if _btn_take_logs != null:
		_btn_take_logs.pressed.connect(_on_take_logs)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open(campfire: Node3D, player: Node) -> void:
	_campfire = campfire
	_player = player
	visible = true
	_refresh_all()


func close() -> void:
	visible = false
	_campfire = null
	_player = null


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _refresh_all() -> void:
	if _campfire == null:
		return
	if _campfire.has_method("build_slot_refresh_payload"):
		var d: Dictionary = _campfire.call("build_slot_refresh_payload")
		_update_buttons_state(bool(d.get("is_lit", false)), bool(d.get("can_light", false)))
	if _hint != null:
		_hint.text = str(_campfire.call("get_panel_hint_text")) if _campfire.has_method("get_panel_hint_text") else ""
	_refresh_slot_buttons()


func _update_buttons_state(is_lit: bool, can_light: bool) -> void:
	if _btn_light != null:
		_btn_light.visible = not is_lit
		_btn_light.disabled = not can_light
	if _btn_rest != null:
		_btn_rest.visible = is_lit


func _refresh_slot_buttons() -> void:
	_clear_grid_children(_log_grid)
	_clear_grid_children(_cook_grid)
	if _campfire == null:
		return
	for i in _LOG_SLOTS:
		var data: Dictionary = {}
		if _campfire.has_method("get_log_slot_dict"):
			data = _campfire.call("get_log_slot_dict", i)
		_log_grid.add_child(_make_slot_button(i, data, true))
	for i in _COOK_SLOTS:
		var data: Dictionary = {}
		if _campfire.has_method("get_cook_slot_dict"):
			data = _campfire.call("get_cook_slot_dict", i)
		_cook_grid.add_child(_make_slot_button(i, data, false))


func _clear_grid_children(grid: GridContainer) -> void:
	if grid == null:
		return
	for c in grid.get_children():
		c.queue_free()


func _make_slot_button(idx: int, slot: Dictionary, is_log: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(52, 52)
	var iid := str(slot.get("id", ""))
	var cnt := int(slot.get("count", 0))
	if iid.is_empty() or cnt <= 0:
		b.text = "—"
	else:
		var short := iid
		if iid == "logs":
			short = "log"
		elif iid == "meat_raw":
			short = "raw"
		elif iid == "meat_cooked":
			short = "ck"
		b.text = "%s\n×%d" % [short, cnt]
	b.pressed.connect(func() -> void: _on_slot_clicked(idx, is_log))
	return b


func _on_slot_clicked(idx: int, is_log: bool) -> void:
	if _campfire == null or _player == null:
		return
	if is_log:
		if _campfire.has_method("panel_cycle_log_slot"):
			_campfire.call("panel_cycle_log_slot", idx, _player)
	else:
		if _campfire.has_method("panel_cycle_cook_slot"):
			_campfire.call("panel_cycle_cook_slot", idx, _player)
	_refresh_all()


func _on_light_pressed() -> void:
	if _campfire != null and _campfire.has_method("panel_try_light") and _player != null:
		_campfire.call("panel_try_light", _player)
	_refresh_all()


func _on_rest_pressed() -> void:
	if _campfire != null and _campfire.has_method("panel_rest_save") and _player != null:
		_campfire.call("panel_rest_save", _player)
	_refresh_all()


func _on_deposit_log() -> void:
	if _campfire != null and _campfire.has_method("panel_deposit_one_log") and _player != null:
		_campfire.call("panel_deposit_one_log", _player)
	_refresh_all()


func _on_take_logs() -> void:
	if _campfire != null and _campfire.has_method("panel_take_one_log") and _player != null:
		_campfire.call("panel_take_one_log", _player)
	_refresh_all()


func is_open_for(campfire: Node) -> bool:
	return visible and _campfire == campfire
