extends CanvasLayer

## Toggle with the `inventory` input action; shows items from InventoryService.

const _SLOT_COUNT := 16

@onready var _panel: PanelContainer = $Root/Margin/Panel
@onready var _grid: GridContainer = $Root/Margin/Panel/VBox/Scroll/Grid

var _slots: Array[Panel] = []
var _was_mouse_captured: bool = false


#region agent log
func _agent_log(run_id: String, hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	var payload := {
		"sessionId": "c5ea88",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000
	}
	var path := "c:/Users/price/Desktop/Game Creation/3D Projects/rune_forged/debug-c5ea88.log"
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		path = ProjectSettings.globalize_path("res://debug-c5ea88.log")
		f = FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.close()
	var req := HTTPRequest.new()
	add_child(req)
	req.request(
		"http://127.0.0.1:7780/ingest/aa3393c7-0b4c-4042-9eeb-84c344b7ef69",
		["Content-Type: application/json", "X-Debug-Session-Id: c5ea88"],
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
#endregion


func _style_main_panel() -> void:
	var path := "res://assets/ui/UI Borders/PNG/Double/Panel/panel-000.png"
	if not ResourceLoader.exists(path):
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.06, 0.05, 0.04, 0.94)
		flat.border_color = Color(0.65, 0.52, 0.3, 1.0)
		flat.set_border_width_all(3)
		flat.set_corner_radius_all(6)
		flat.content_margin_left = 14
		flat.content_margin_top = 12
		flat.content_margin_right = 14
		flat.content_margin_bottom = 14
		_panel.add_theme_stylebox_override("panel", flat)
		return
	var tex: Texture2D = load(path)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 14
	sb.texture_margin_top = 14
	sb.texture_margin_right = 14
	sb.texture_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", sb)


func _ready() -> void:
	layer = 20
	visible = false
	InventoryService.inventory_changed.connect(_refresh_grid)
	_style_main_panel()
	_build_slots()
	_refresh_grid()
	#region agent log
	_agent_log(
		"initial",
		"H1",
		"player_inventory_hud.gd:_ready",
		"Inventory HUD ready",
		{"slotCount": _slots.size(), "panelVisible": visible}
	)
	#endregion


func toggle_inventory() -> void:
	visible = not visible
	#region agent log
	_agent_log(
		"initial",
		"H1",
		"player_inventory_hud.gd:toggle_inventory",
		"Inventory toggled",
		{"visible": visible, "mouseModeBefore": Input.mouse_mode}
	)
	#endregion
	if visible:
		_was_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_grid()
	else:
		if _was_mouse_captured:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_slots() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_slots.clear()
	for i in _SLOT_COUNT:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(56, 56)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(vb)
		var name_l := Label.new()
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_l.clip_text = true
		name_l.add_theme_font_size_override("font_size", 11)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_l.name = "NameLabel"
		var count_l := Label.new()
		count_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_l.add_theme_font_size_override("font_size", 14)
		count_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_l.name = "CountLabel"
		vb.add_child(name_l)
		vb.add_child(count_l)
		_grid.add_child(slot)
		_slots.append(slot)


func _refresh_grid() -> void:
	var items: Dictionary = InventoryService.get_items_copy()
	#region agent log
	_agent_log(
		"initial",
		"H1",
		"player_inventory_hud.gd:_refresh_grid",
		"Refreshing inventory slots",
		{"itemTypes": items.size(), "items": items}
	)
	#endregion
	var keys: Array = items.keys()
	keys.sort()
	var idx := 0
	for slot in _slots:
		var name_l: Label = slot.find_child("NameLabel", true, false)
		var count_l: Label = slot.find_child("CountLabel", true, false)
		if idx < keys.size():
			var k: String = keys[idx]
			name_l.text = _pretty_item_name(k)
			count_l.text = str(items[k])
			_apply_slot_style(slot, true)
		else:
			name_l.text = ""
			count_l.text = ""
			_apply_slot_style(slot, false)
		idx += 1


func _pretty_item_name(item_id: String) -> String:
	var s := item_id.replace("_", " ")
	if s.is_empty():
		return ""
	return s.capitalize()


func _apply_slot_style(slot: Panel, filled: bool) -> void:
	var sb := StyleBoxFlat.new()
	if filled:
		sb.bg_color = Color(0.12, 0.1, 0.08, 0.92)
		sb.border_color = Color(0.72, 0.58, 0.35, 1.0)
	else:
		sb.bg_color = Color(0.08, 0.07, 0.06, 0.75)
		sb.border_color = Color(0.35, 0.32, 0.28, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 4
	sb.content_margin_top = 4
	sb.content_margin_right = 4
	sb.content_margin_bottom = 4
	slot.add_theme_stylebox_override("panel", sb)
