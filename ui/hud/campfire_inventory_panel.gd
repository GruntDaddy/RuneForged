extends CanvasLayer
## Simple campfire UI: log slots, cooking slots, light, rest.

const _LOG_SLOTS := 4
const _COOK_SLOTS := 2

var _campfire: Node3D = null
var _player: Node = null
var _opened_game_menu_for_panel: bool = false
var _drag_item_id: String = ""
var _log_slot_buttons: Array[Button] = []
var _cook_slot_buttons: Array[Button] = []

@onready var _backdrop: ColorRect = $Backdrop
@onready var _panel: PanelContainer = $CenterContainer/PanelContainer
@onready var _log_grid: GridContainer = $CenterContainer/PanelContainer/Margin/VBox/LogRow
@onready var _cook_grid: GridContainer = $CenterContainer/PanelContainer/Margin/VBox/CookRow
@onready var _bag_logs_btn: Button = $CenterContainer/PanelContainer/Margin/VBox/BagRow/BagLogsButton
@onready var _bag_raw_btn: Button = $CenterContainer/PanelContainer/Margin/VBox/BagRow/BagRawButton
@onready var _hint: Label = $CenterContainer/PanelContainer/Margin/VBox/HintLabel
@onready var _btn_light: Button = $CenterContainer/PanelContainer/Margin/VBox/ButtonRow/LightButton
@onready var _btn_rest: Button = $CenterContainer/PanelContainer/Margin/VBox/ButtonRow/RestButton
@onready var _btn_close: Button = $CenterContainer/PanelContainer/Margin/VBox/ButtonRow/CloseButton
@onready var _btn_deposit_log: Button = $CenterContainer/PanelContainer/Margin/VBox/DepositRow/DepositLogButton
@onready var _btn_take_logs: Button = $CenterContainer/PanelContainer/Margin/VBox/DepositRow/TakeLogButton
@onready var _drag_preview: Panel = $DragPreview
@onready var _drag_item_label: Label = $DragPreview/Margin/DragItemLabel


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
	if _bag_logs_btn != null:
		_bag_logs_btn.pressed.connect(func() -> void: _begin_drag_from_bag("logs"))
	if _bag_raw_btn != null:
		_bag_raw_btn.pressed.connect(func() -> void: _begin_drag_from_bag("meat_raw"))
	if _drag_preview != null:
		_drag_preview.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion and _is_dragging():
		_drag_preview.global_position = event.global_position + Vector2(16, 16)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _is_dragging():
		_drop_dragged_item(event.global_position)
		_cancel_drag()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open(campfire: Node3D, player: Node) -> void:
	_campfire = campfire
	_player = player
	_open_player_inventory_menu()
	visible = true
	_refresh_all()


func close() -> void:
	_cancel_drag()
	_close_player_inventory_menu_if_opened()
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
	_log_slot_buttons.clear()
	_cook_slot_buttons.clear()
	if _campfire == null:
		return
	for i in _LOG_SLOTS:
		var data: Dictionary = {}
		if _campfire.has_method("get_log_slot_dict"):
			data = _campfire.call("get_log_slot_dict", i)
		var b := _make_slot_button(i, data, true)
		_log_grid.add_child(b)
		_log_slot_buttons.append(b)
	for i in _COOK_SLOTS:
		var data: Dictionary = {}
		if _campfire.has_method("get_cook_slot_dict"):
			data = _campfire.call("get_cook_slot_dict", i)
		var b := _make_slot_button(i, data, false)
		_cook_grid.add_child(b)
		_cook_slot_buttons.append(b)
	_refresh_bag_buttons()


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


func _refresh_bag_buttons() -> void:
	if _bag_logs_btn != null:
		var lc: int = int(InventoryService.get_item_count("logs"))
		_bag_logs_btn.text = "Bag logs ×%d (drag)" % lc
		_bag_logs_btn.disabled = lc <= 0
	if _bag_raw_btn != null:
		var mc: int = int(InventoryService.get_item_count("meat_raw"))
		_bag_raw_btn.text = "Bag raw meat ×%d (drag)" % mc
		_bag_raw_btn.disabled = mc <= 0


func _begin_drag_from_bag(item_id: String) -> void:
	if int(InventoryService.get_item_count(item_id)) <= 0:
		return
	_drag_item_id = item_id
	if _drag_item_label != null:
		_drag_item_label.text = "Drag: %s" % item_id
	if _drag_preview != null:
		_drag_preview.visible = true
		_drag_preview.global_position = get_viewport().get_mouse_position() + Vector2(16, 16)


func _is_dragging() -> bool:
	return not _drag_item_id.is_empty()


func _cancel_drag() -> void:
	_drag_item_id = ""
	if _drag_preview != null:
		_drag_preview.visible = false


func _drop_dragged_item(global_pos: Vector2) -> void:
	if _campfire == null or _player == null:
		return
	var idx := _slot_index_at_global(_log_slot_buttons, global_pos)
	if idx >= 0 and _campfire.has_method("panel_drop_item_to_log_slot"):
		_campfire.call("panel_drop_item_to_log_slot", idx, _drag_item_id, _player)
		_refresh_all()
		return
	idx = _slot_index_at_global(_cook_slot_buttons, global_pos)
	if idx >= 0 and _campfire.has_method("panel_drop_item_to_cook_slot"):
		_campfire.call("panel_drop_item_to_cook_slot", idx, _drag_item_id, _player)
		_refresh_all()


func _slot_index_at_global(btns: Array[Button], global_pos: Vector2) -> int:
	for i in btns.size():
		if btns[i].get_global_rect().has_point(global_pos):
			return i
	return -1


func _open_player_inventory_menu() -> void:
	_opened_game_menu_for_panel = false
	if _player == null:
		return
	var gm := _player.get_node_or_null("GameMenu")
	if gm == null:
		return
	if bool(gm.visible):
		return
	if gm.has_method("open_menu"):
		gm.call("open_menu", 2) # TAB_INVENTORY
		_opened_game_menu_for_panel = true


func _close_player_inventory_menu_if_opened() -> void:
	if not _opened_game_menu_for_panel or _player == null:
		return
	var gm := _player.get_node_or_null("GameMenu")
	if gm != null and gm.has_method("close_menu"):
		gm.call("close_menu")
	_opened_game_menu_for_panel = false
