extends CanvasLayer

const _BaseCharacter = preload("res://entities/characters/base_character/base_character.gd")

@onready var _health_bar: ProgressBar = $Root/TopLeft/Margin/VBox/HealthRow/ProgressBar
@onready var _stamina_bar: ProgressBar = $Root/TopLeft/Margin/VBox/StaminaRow/ProgressBar
@onready var _health_val: Label = $Root/TopLeft/Margin/VBox/HealthRow/ValueLabel
@onready var _stamina_val: Label = $Root/TopLeft/Margin/VBox/StaminaRow/ValueLabel
@onready var _hud_root: Control = $Root

var _hotbar_panels: Array[Panel] = []
var _hotbar_labels: Array[Label] = []
var _hotbar_keys: Array[Label] = []


func _ready() -> void:
	layer = 5
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for path in ["Slot0", "Slot1", "Slot2", "Slot3"]:
		var p: Panel = $Root/Hotbar/Margin/HBox.get_node(path) as Panel
		_hotbar_panels.append(p)
		_hotbar_keys.append(p.get_node("VBox/Key") as Label)
		_hotbar_labels.append(p.get_node("VBox/Name") as Label)
	_style_bars()


func _style_bars() -> void:
	for bar in [_health_bar, _stamina_bar]:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.08, 0.07, 0.06, 0.92)
		bg.set_corner_radius_all(4)
		var fill := StyleBoxFlat.new()
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", bg)
		if bar == _health_bar:
			fill.bg_color = Color(0.72, 0.22, 0.18, 1.0)
		else:
			fill.bg_color = Color(0.28, 0.55, 0.82, 1.0)
		bar.add_theme_stylebox_override("fill", fill)


func _physics_process(_delta: float) -> void:
	var p: Node = get_parent()
	if p == null or not p.has_method("get_hud_snapshot"):
		return
	var s: Dictionary = p.get_hud_snapshot()
	var mh: float = float(s.get("max_health", 1.0))
	var h: float = float(s.get("health", 0.0))
	var ms: float = float(s.get("max_stamina", 1.0))
	var st: float = float(s.get("stamina", 0.0))
	_health_bar.max_value = mh
	_health_bar.value = h
	_stamina_bar.max_value = ms
	_stamina_bar.value = st
	_health_val.text = "%d / %d" % [int(round(h)), int(round(mh))]
	_stamina_val.text = "%d / %d" % [int(round(st)), int(round(ms))]
	var tool_i: int = int(s.get("tool_kind", 0))
	for i in _hotbar_panels.size():
		_hotbar_keys[i].text = "[%d]" % (i + 1)
		var item_id := _hotbar_item_id(i)
		var kind: int = _tool_kind_for_item(item_id)
		if item_id.is_empty():
			kind = _default_tool_kind_for_slot(i)
		var active: bool = tool_i == kind
		_apply_hotbar_style(_hotbar_panels[i], active)
		_hotbar_labels[i].text = _hot_item_caption(i, item_id)


func _apply_hotbar_style(panel: Panel, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	if active:
		sb.bg_color = Color(0.18, 0.22, 0.16, 0.95)
		sb.border_color = Color(0.85, 0.72, 0.38, 1.0)
	else:
		sb.bg_color = Color(0.1, 0.09, 0.08, 0.88)
		sb.border_color = Color(0.38, 0.35, 0.3, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_top = 6
	sb.content_margin_right = 8
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)


func hotbar_slot_from_global(global_pos: Vector2) -> int:
	for i in _hotbar_panels.size():
		if _hotbar_panels[i].get_global_rect().has_point(global_pos):
			return i
	return -1


func assign_hotbar_from_inventory(slot_idx: int, inv_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= 4:
		return false
	var s: Variant = InventoryService.get_slot_data(inv_idx)
	if s == null:
		return false
	var item_id := str(s.get("id", ""))
	if item_id.is_empty():
		return false
	_set_hotbar_item(slot_idx, item_id)
	return true


func _set_hotbar_item(slot_idx: int, item_id: String) -> void:
	while GameState.hotbar_item_ids.size() < 4:
		GameState.hotbar_item_ids.append("")
	GameState.hotbar_item_ids[slot_idx] = item_id


func _hotbar_item_id(slot_idx: int) -> String:
	if slot_idx < 0:
		return ""
	if GameState.hotbar_item_ids.size() <= slot_idx:
		return ""
	return str(GameState.hotbar_item_ids[slot_idx])


func _hot_item_caption(_slot_idx: int, item_id: String) -> String:
	if item_id.is_empty():
		return ""
	var n := InventoryService.get_item_display_name(item_id)
	if n.is_empty():
		n = item_id.replace("_", " ").capitalize()
	return n


func _tool_kind_for_item(item_id: String) -> int:
	if item_id.is_empty():
		return int(_BaseCharacter.ToolKind.NONE)
	var it: ItemData = ItemCatalog.get_item(item_id)
	if it == null:
		return int(_BaseCharacter.ToolKind.NONE)
	for tag in it.tags:
		var t := str(tag)
		if t == "hatchet" or t == "axe":
			return int(_BaseCharacter.ToolKind.AXE)
		if t == "pickaxe":
			return int(_BaseCharacter.ToolKind.PICKAXE)
		if t == "fishing_rod" or t == "fishing":
			return int(_BaseCharacter.ToolKind.FISHING_ROD)
	return int(_BaseCharacter.ToolKind.NONE)


func _default_tool_kind_for_slot(_slot_idx: int) -> int:
	return int(_BaseCharacter.ToolKind.NONE)
