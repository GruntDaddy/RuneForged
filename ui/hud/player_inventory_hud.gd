extends CanvasLayer

const SLOT_COLS := 4
const SLOT_SIZE := Vector2(80, 96)

@onready var _panel: PanelContainer = $Root/Margin/Panel
@onready var _grid: GridContainer = $Root/Margin/Panel/VBox/Scroll/Grid
@onready var _drag_preview: Panel = $Root/DragPreview
@onready var _drag_icon: TextureRect = $Root/DragPreview/Margin/VBox/IconTexture
@onready var _drag_fallback: Label = $Root/DragPreview/Margin/VBox/IconFallback
@onready var _drag_name: Label = $Root/DragPreview/Margin/VBox/NameLabel
@onready var _drag_count: Label = $Root/DragPreview/Margin/VBox/CountLabel

var _slots: Array[Panel] = []
var _was_mouse_captured: bool = false
var _drag_from_idx: int = -1

var _tackle_window: Window = null
var _tackle_inventory_slot: int = -1
var _tackle_hook_labels: Array[Label] = []
var _tackle_bobber_labels: Array[Label] = []
var _tackle_bait_labels: Array[Label] = []


func _style_main_panel() -> void:
	var path := "res://assets/Fantasy RPG UI/Individual files/2x/Background boxes/BGbox_06A.png"
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
	var m := 44
	sb.texture_margin_left = m
	sb.texture_margin_top = m
	sb.texture_margin_right = m
	sb.texture_margin_bottom = m
	_panel.add_theme_stylebox_override("panel", sb)


func _ready() -> void:
	layer = 20
	visible = false
	InventoryService.inventory_changed.connect(_on_inventory_service_changed)
	_style_main_panel()
	_build_slots()
	_refresh_grid()
	_drag_preview.visible = false
	_drag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL


func _on_inventory_service_changed() -> void:
	_refresh_grid()
	_refresh_tackle_panel()


func toggle_inventory() -> void:
	visible = not visible
	if visible:
		_was_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_grid()
	else:
		_close_tackle_window()
		if _was_mouse_captured:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_cancel_drag()


func _build_slots() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_slots.clear()
	_grid.columns = SLOT_COLS
	for i in InventoryService.SLOT_COUNT:
		var slot := Panel.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.name = "Slot_%d" % i
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 4)
		slot.add_child(vb)
		var icon_area := Control.new()
		icon_area.custom_minimum_size = Vector2(72, 56)
		icon_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(icon_area)
		var icon_tex := TextureRect.new()
		icon_tex.name = "IconTexture"
		icon_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_tex.offset_left = 2.0
		icon_tex.offset_top = 2.0
		icon_tex.offset_right = -2.0
		icon_tex.offset_bottom = -2.0
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_area.add_child(icon_tex)
		var icon_fb := Label.new()
		icon_fb.name = "IconFallback"
		icon_fb.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_fb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_fb.add_theme_font_size_override("font_size", 20)
		icon_fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_fb.visible = false
		icon_area.add_child(icon_fb)
		var name_l := Label.new()
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_l.clip_text = true
		name_l.add_theme_font_size_override("font_size", 11)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_l.name = "NameLabel"
		var count_l := Label.new()
		count_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_l.add_theme_font_size_override("font_size", 13)
		count_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_l.name = "CountLabel"
		vb.add_child(name_l)
		vb.add_child(count_l)
		_grid.add_child(slot)
		_slots.append(slot)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var ridx := _slot_from_mouse(event.global_position)
		if ridx >= 0:
			var s: Variant = InventoryService.get_slot_data(ridx)
			if s != null and str(s.get("id", "")) == InventoryService.TACKLEBOX_ID:
				_open_tackle_window(ridx)
				get_viewport().set_input_as_handled()
				return
			if _tackle_window != null and _tackle_window.visible and _tackle_inventory_slot >= 0:
				if InventoryService.deposit_to_tackle_first_empty(_tackle_inventory_slot, ridx):
					_refresh_tackle_panel()
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseMotion and _drag_from_idx >= 0:
		_drag_preview.global_position = event.global_position + Vector2(16, 16)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var idx := _slot_from_mouse(event.global_position)
			if idx >= 0:
				_try_begin_drag(idx)
		else:
			if _drag_from_idx >= 0:
				var to_idx := _slot_from_mouse(event.global_position)
				if to_idx >= 0:
					InventoryService.move_or_merge(_drag_from_idx, to_idx)
				else:
					if not _try_drop_on_hotbar(event.global_position):
						_drop_dragged_item_to_world(event.global_position)
				_cancel_drag()


func _slot_from_mouse(global_pos: Vector2) -> int:
	for i in _slots.size():
		var rect := _slots[i].get_global_rect()
		if rect.has_point(global_pos):
			return i
	return -1


func _try_begin_drag(idx: int) -> void:
	var s: Variant = InventoryService.get_slot_data(idx)
	if s == null:
		return
	_drag_from_idx = idx
	var item_id: String = s["id"]
	var count: int = int(s["count"])
	_apply_icon_to_texture_rect(_drag_icon, _drag_fallback, item_id)
	_drag_name.text = _pretty_item_name(item_id)
	_drag_count.text = str(count)
	_drag_preview.visible = true
	var mp := get_viewport().get_mouse_position()
	_drag_preview.global_position = mp + Vector2(16, 16)


func _cancel_drag() -> void:
	_drag_from_idx = -1
	_drag_preview.visible = false


func _drop_dragged_item_to_world(mouse_pos: Vector2) -> void:
	var player := get_parent() as Node3D
	if player == null:
		return
	var cam: Camera3D = player.get_node_or_null("CameraRig/SpringArm3D/Camera3D")
	if cam == null:
		return
	var origin := cam.project_ray_origin(mouse_pos)
	var normal := cam.project_ray_normal(mouse_pos)
	var target := origin + normal * 6.0
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(query)
	var drop_pos := player.global_position + player.global_basis.z * 0.8 + Vector3.UP * 0.25
	if hit.size() > 0:
		drop_pos = (hit["position"] as Vector3) + Vector3.UP * 0.3
	InventoryService.drop_slot_to_world(_drag_from_idx, drop_pos, player.get_parent())


func _try_drop_on_hotbar(global_pos: Vector2) -> bool:
	var player := get_parent()
	if player == null:
		return false
	var hud := player.get_node_or_null("PlayerHud")
	if hud == null or not hud.has_method("hotbar_slot_from_global"):
		return false
	var slot_idx: int = int(hud.call("hotbar_slot_from_global", global_pos))
	if slot_idx < 0:
		return false
	if not hud.has_method("assign_hotbar_from_inventory"):
		return false
	return bool(hud.call("assign_hotbar_from_inventory", slot_idx, _drag_from_idx))


func _refresh_grid() -> void:
	for i in _slots.size():
		var slot := _slots[i]
		var icon_tex: TextureRect = slot.find_child("IconTexture", true, false)
		var icon_fb: Label = slot.find_child("IconFallback", true, false)
		var name_l: Label = slot.find_child("NameLabel", true, false)
		var count_l: Label = slot.find_child("CountLabel", true, false)
		var s: Variant = InventoryService.get_slot_data(i)
		if s != null:
			var item_id: String = s["id"]
			_apply_icon_to_texture_rect(icon_tex, icon_fb, item_id)
			name_l.text = _pretty_item_name(item_id)
			count_l.text = str(int(s["count"]))
			_apply_slot_style(slot, true)
		else:
			icon_tex.texture = null
			icon_fb.visible = false
			name_l.text = ""
			count_l.text = ""
			_apply_slot_style(slot, false)


func _apply_icon_to_texture_rect(tex_rect: TextureRect, fallback: Label, item_id: String) -> void:
	var tex: Texture2D = ItemCatalog.get_item_icon(item_id)
	if tex != null:
		tex_rect.texture = tex
		tex_rect.visible = true
		fallback.visible = false
	else:
		tex_rect.texture = null
		tex_rect.visible = false
		fallback.visible = true
		fallback.text = _item_icon(item_id)


func _pretty_item_name(item_id: String) -> String:
	var inv := get_node_or_null("/root/InventoryService")
	if inv != null and inv.has_method("get_item_display_name"):
		var n: String = inv.get_item_display_name(item_id)
		if not n.is_empty():
			return n
	var s := item_id.replace("_", " ")
	if s.is_empty():
		return ""
	return s.capitalize()


func _item_icon(item_id: String) -> String:
	match item_id:
		"logs", "wood":
			return "LG"
		"oak_logs":
			return "OK"
		"stone":
			return "ST"
		"tin_ore", "ore_tin":
			return "Sn"
		"ore_copper":
			return "Cu"
		_:
			return "•"


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


func _ensure_tackle_window() -> void:
	if _tackle_window != null:
		return
	_tackle_window = Window.new()
	_tackle_window.title = "Tackle box"
	_tackle_window.size = Vector2i(340, 460)
	_tackle_window.unresizable = true
	_tackle_window.close_requested.connect(_close_tackle_window)
	add_child(_tackle_window)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_tackle_window.add_child(margin)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(vb)
	var help := Label.new()
	help.text = "Right-click a hook, bobber, or bait in inventory to store it here."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(help)
	_append_tackle_row(vb, "Hooks", InventoryService.TACKLE_HOOKS, _tackle_hook_labels)
	_append_tackle_row(vb, "Bobbers", InventoryService.TACKLE_BOBBERS, _tackle_bobber_labels)
	_append_tackle_row(vb, "Bait", InventoryService.TACKLE_BAIT, _tackle_bait_labels)
	_tackle_window.hide()


func _append_tackle_row(parent: VBoxContainer, title: String, count: int, out_labels: Array[Label]) -> void:
	var tl := Label.new()
	tl.text = title
	parent.add_child(tl)
	var grid := GridContainer.new()
	grid.columns = mini(count, 5)
	parent.add_child(grid)
	out_labels.clear()
	for i in count:
		var cell := Label.new()
		cell.custom_minimum_size = Vector2(56, 22)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.text = "—"
		grid.add_child(cell)
		out_labels.append(cell)


func _open_tackle_window(inv_slot: int) -> void:
	var s: Variant = InventoryService.get_slot_data(inv_slot)
	if s == null or str(s.get("id", "")) != InventoryService.TACKLEBOX_ID:
		return
	_ensure_tackle_window()
	_tackle_inventory_slot = inv_slot
	_refresh_tackle_panel()
	_tackle_window.popup_centered()


func _close_tackle_window() -> void:
	if _tackle_window != null:
		_tackle_window.hide()
	_tackle_inventory_slot = -1


func _refresh_tackle_panel() -> void:
	if _tackle_window == null or not _tackle_window.visible:
		return
	if _tackle_inventory_slot < 0:
		return
	var t: Dictionary = InventoryService.get_tackle_for_slot(_tackle_inventory_slot)
	_fill_tackle_labels(_tackle_hook_labels, t.get("hooks", []))
	_fill_tackle_labels(_tackle_bobber_labels, t.get("bobbers", []))
	_fill_tackle_labels(_tackle_bait_labels, t.get("bait", []))


func _fill_tackle_labels(labels: Array[Label], arr: Variant) -> void:
	if typeof(arr) != TYPE_ARRAY:
		return
	var a: Array = arr
	for i in labels.size():
		var lab: Label = labels[i]
		if i >= a.size() or a[i] == null:
			lab.text = "—"
			continue
		var c: Variant = a[i]
		if typeof(c) != TYPE_DICTIONARY:
			lab.text = "—"
			continue
		var id := str(c.get("id", ""))
		var n := int(c.get("count", 0))
		if id.is_empty():
			lab.text = "—"
		else:
			var short := id
			if short.length() > 8:
				short = short.substr(0, 7) + "…"
			lab.text = "%s x%d" % [short, n]
