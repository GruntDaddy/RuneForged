extends CanvasLayer
class_name ModularBuildUi

## Categorized piece picker + floor / demolish toggles for modular building.

signal piece_selected(piece_id: String)
signal demolish_mode_changed(active: bool)
signal floor_level_changed(floor_iy: int)

var _dock: Control
var _demolish_btn: Button
var _floor_g_btn: Button
var _floor_u_btn: Button
var _tab_container: TabContainer
var _floor_iy: int = 0


func _ready() -> void:
	layer = 50
	visible = false
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_dock = Control.new()
	_dock.name = "Dock"
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	_dock.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_dock.anchor_right = 0.0
	_dock.offset_right = 320.0
	root.add_child(_dock)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_dock.add_child(margin)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "Build [B]"
	title.add_theme_font_size_override("font_size", 18)
	vb.add_child(title)
	var row_floor := HBoxContainer.new()
	row_floor.add_theme_constant_override("separation", 6)
	vb.add_child(row_floor)
	var fl := Label.new()
	fl.text = "Floor:"
	row_floor.add_child(fl)
	_floor_g_btn = Button.new()
	_floor_g_btn.text = "Ground"
	_floor_g_btn.disabled = true
	_floor_g_btn.pressed.connect(func() -> void: _select_floor(0))
	row_floor.add_child(_floor_g_btn)
	_floor_u_btn = Button.new()
	_floor_u_btn.text = "Upper"
	_floor_u_btn.pressed.connect(func() -> void: _select_floor(1))
	row_floor.add_child(_floor_u_btn)
	_demolish_btn = Button.new()
	_demolish_btn.text = "Demolish mode"
	_demolish_btn.toggle_mode = true
	_demolish_btn.toggled.connect(_on_demolish_toggled)
	vb.add_child(_demolish_btn)
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.custom_minimum_size = Vector2(0, 360)
	vb.add_child(_tab_container)
	_build_category_tabs()
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = (
		"Choose a piece below, then you can look with the mouse while placing.\n"
		+ "After picking: E place / demolish · Wheel rotate · [ / ] floor · X demolish · B close."
	)
	hint.add_theme_font_size_override("font_size", 12)
	vb.add_child(hint)


func set_panel_visible(on: bool) -> void:
	visible = on


func set_dock_visible(on: bool) -> void:
	if _dock != null:
		_dock.visible = on


func is_dock_visible() -> bool:
	return _dock != null and _dock.visible


func reset_for_session() -> void:
	set_dock_visible(true)
	set_demolish_pressed(false)
	_select_floor(0)


func set_demolish_pressed(on: bool) -> void:
	_demolish_btn.set_pressed_no_signal(on)


func set_floor_iy(iy: int) -> void:
	_select_floor(iy)


func set_piece_picker_focus_first_tab() -> void:
	if _tab_container != null and _tab_container.get_tab_count() > 0:
		_tab_container.current_tab = 0


func is_pointer_over_ui() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var h: Control = vp.gui_get_hovered_control()
	if h == null:
		return false
	var cur: Node = h
	while cur != null:
		if cur == _dock:
			return true
		cur = cur.get_parent()
	return false


func get_selected_floor_iy() -> int:
	return _floor_iy


func is_demolish_mode() -> bool:
	return _demolish_btn.button_pressed


func _select_floor(iy: int) -> void:
	_floor_iy = clampi(iy, 0, 1)
	_floor_g_btn.disabled = _floor_iy == 0
	_floor_u_btn.disabled = _floor_iy == 1
	floor_level_changed.emit(_floor_iy)


func _on_demolish_toggled(pressed: bool) -> void:
	demolish_mode_changed.emit(pressed)


func _build_category_tabs() -> void:
	for c in _tab_container.get_children():
		c.queue_free()
	var cats := ModularBuildCatalog.categories_in_order()
	var all := ModularBuildCatalog.all_piece_rows()
	for cat in cats:
		var scroll := ScrollContainer.new()
		scroll.name = ModularBuildCatalog.category_display_name(cat)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := VBoxContainer.new()
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_theme_constant_override("separation", 4)
		scroll.add_child(inner)
		_tab_container.add_child(scroll)
		for row in all:
			if String(row.get("category", "")) != String(cat):
				continue
			var bid := String(row.get("id", ""))
			if bid.is_empty():
				continue
			var b := Button.new()
			b.text = String(row.get("name", bid))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.pressed.connect(func() -> void: piece_selected.emit(bid))
			inner.add_child(b)
