extends CanvasLayer
class_name GameMenu

const _SLOT_COLS := 4
const _INV_SLOT_SIZE := Vector2(76, 90)
const _EQUIP_SLOT_SIZE := Vector2(68, 82)

const _TAB_NAMES: PackedStringArray = [
	"Character",
	"Skills",
	"Quests",
	"Magic",
	"Abilities",
	"Crafting",
	"Building",
]

const _EQUIP_ORDER: PackedStringArray = [
	"head",
	"neck",
	"chest",
	"hands",
	"legs",
	"feet",
	"back",
	"ring_1",
	"ring_2",
	"main_hand",
	"off_hand",
]

@onready var _backdrop: ColorRect = $Backdrop
@onready var _book: PanelContainer = $Center/BookPanel
@onready var _tab_column: VBoxContainer = $Center/BookPanel/MainVBox/Body/TabColumn
@onready var _page_host: Control = $Center/BookPanel/MainVBox/Body/PageHost
@onready var _drag_preview: Panel = $DragPreview
@onready var _drag_icon: TextureRect = $DragPreview/Margin/VBox/IconTexture
@onready var _drag_fallback: Label = $DragPreview/Margin/VBox/IconFallback
@onready var _drag_name: Label = $DragPreview/Margin/VBox/NameLabel
@onready var _drag_count: Label = $DragPreview/Margin/VBox/CountLabel

var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _current_tab: int = 0

var _inv_grid: GridContainer
var _inv_slots: Array[Panel] = []
var _equip_panels: Dictionary = {}  ## slot_id -> Panel

var _page_crafting_list: ItemList
var _page_crafting_detail: RichTextLabel
var _page_crafting_craft: Button
var _page_crafting_filter: OptionButton
var _craft_recipes: Array[RecipeData] = []
var _craft_selected: RecipeData = null
var _station_filter_idx: int = -1

var _was_mouse_captured: bool = false
var _drag: Dictionary = {}

var _tackle_window: Window = null
var _tackle_inventory_slot: int = -1
var _tackle_hook_labels: Array[Label] = []
var _tackle_bobber_labels: Array[Label] = []
var _tackle_bait_labels: Array[Label] = []


func _ready() -> void:
	layer = 25
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style_book_panel()
	_build_tabs()
	_build_pages()
	_drag_preview.visible = false
	_drag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_backdrop.gui_input.connect(_on_backdrop_gui_input)
	InventoryService.inventory_changed.connect(_on_inventory_changed)
	_on_inventory_changed()


func _on_inventory_changed() -> void:
	if visible:
		_refresh_inv_grid()
		_refresh_equip_slots()
		_refresh_tackle_panel()
		_refresh_skills_page()
		_refresh_crafting_detail()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close_menu()


func toggle(default_tab: int = 0) -> void:
	if visible:
		close_menu()
	else:
		open_menu(clampi(default_tab, 0, _TAB_NAMES.size() - 1))


func open_menu(tab_idx: int = 0) -> void:
	_was_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_set_tab(clampi(tab_idx, 0, _TAB_NAMES.size() - 1))
	_play_open_anim()
	_refresh_inv_grid()
	_refresh_equip_slots()
	_refresh_skills_page()
	_refresh_crafting_list()
	_refresh_crafting_detail()


func close_menu() -> void:
	_close_tackle_window()
	_cancel_drag()
	var tw := create_tween()
	tw.tween_property(_book, "scale", Vector2(0.92, 0.92), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_book, "modulate:a", 0.0, 0.1)
	await tw.finished
	visible = false
	_book.scale = Vector2.ONE
	_book.modulate.a = 1.0
	if _was_mouse_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _play_open_anim() -> void:
	_book.scale = Vector2(0.92, 0.92)
	_book.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_book, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_book, "modulate:a", 1.0, 0.14)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var inv_idx := _inv_slot_from_mouse(event.global_position)
		if inv_idx >= 0:
			var s: Variant = InventoryService.get_slot_data(inv_idx)
			if s != null and str(s.get("id", "")) == InventoryService.TACKLEBOX_ID:
				_open_tackle_window(inv_idx)
				get_viewport().set_input_as_handled()
				return
			if _tackle_window != null and _tackle_window.visible and _tackle_inventory_slot >= 0:
				if InventoryService.deposit_to_tackle_first_empty(_tackle_inventory_slot, inv_idx):
					_refresh_tackle_panel()
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseMotion and not _drag.is_empty():
		_drag_preview.global_position = event.global_position + Vector2(16, 16)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_begin_drag_at(event.global_position)
		else:
			_finish_drag_at(event.global_position)


func _style_book_panel() -> void:
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
		_book.add_theme_stylebox_override("panel", flat)
		return
	var tex: Texture2D = load(path)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 14
	sb.texture_margin_top = 14
	sb.texture_margin_right = 14
	sb.texture_margin_bottom = 14
	_book.add_theme_stylebox_override("panel", sb)


func _build_tabs() -> void:
	for c in _tab_column.get_children():
		c.queue_free()
	_tab_buttons.clear()
	for i in _TAB_NAMES.size():
		var b := Button.new()
		b.text = _TAB_NAMES[i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_tab_pressed.bind(i))
		_tab_column.add_child(b)
		_tab_buttons.append(b)


func _build_pages() -> void:
	for c in _page_host.get_children():
		c.queue_free()
	_pages.clear()
	for i in _TAB_NAMES.size():
		var page := Control.new()
		page.name = "Page_%d" % i
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		page.mouse_filter = Control.MOUSE_FILTER_PASS
		_page_host.add_child(page)
		_pages.append(page)
		match i:
			0:
				_build_character_page(page)
			1:
				_build_skills_page(page)
			2, 3, 4:
				_build_placeholder_page(page, _TAB_NAMES[i])
			5:
				_build_crafting_page(page)
			6:
				_build_building_page(page)
	_set_tab(0)


func _build_character_page(page: Control) -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	page.add_child(root)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(260, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(left)
	var lt := Label.new()
	lt.text = "Equipment"
	lt.add_theme_font_size_override("font_size", 18)
	left.add_child(lt)
	var eg := GridContainer.new()
	eg.columns = 2
	eg.add_theme_constant_override("h_separation", 8)
	eg.add_theme_constant_override("v_separation", 8)
	left.add_child(eg)
	_equip_panels.clear()
	for slot_id in _EQUIP_ORDER:
		var cell := VBoxContainer.new()
		var cap := Label.new()
		cap.text = _equip_label(slot_id)
		cap.add_theme_font_size_override("font_size", 11)
		cell.add_child(cap)
		var p := _make_slot_panel(_EQUIP_SLOT_SIZE)
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.name = "Equip_%s" % slot_id
		cell.add_child(p)
		_equip_panels[slot_id] = p
		eg.add_child(cell)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	var rt := Label.new()
	rt.text = "Inventory"
	rt.add_theme_font_size_override("font_size", 18)
	right.add_child(rt)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(320, 400)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sc)
	_inv_grid = GridContainer.new()
	_inv_grid.columns = _SLOT_COLS
	_inv_grid.add_theme_constant_override("h_separation", 6)
	_inv_grid.add_theme_constant_override("v_separation", 6)
	sc.add_child(_inv_grid)
	_build_inv_slots()
	var help := Label.new()
	help.text = "Drag items between slots and equipment. Drop outside to place in the world. Right-click tackle box."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 11)
	right.add_child(help)


func _equip_label(slot_id: String) -> String:
	match slot_id:
		"head":
			return "Head"
		"neck":
			return "Neck"
		"chest":
			return "Chest"
		"hands":
			return "Hands"
		"legs":
			return "Legs"
		"feet":
			return "Feet"
		"back":
			return "Back"
		"ring_1":
			return "Ring"
		"ring_2":
			return "Ring"
		"main_hand":
			return "Main hand"
		"off_hand":
			return "Off hand"
		_:
			return slot_id


func _make_slot_panel(sz: Vector2) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = sz
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	slot.add_child(vb)
	var icon_area := Control.new()
	icon_area.custom_minimum_size = Vector2(sz.x - 8, 48)
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
	icon_fb.add_theme_font_size_override("font_size", 16)
	icon_fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_fb.visible = false
	icon_area.add_child(icon_fb)
	var name_l := Label.new()
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.clip_text = true
	name_l.add_theme_font_size_override("font_size", 10)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_l.name = "NameLabel"
	var count_l := Label.new()
	count_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_l.add_theme_font_size_override("font_size", 12)
	count_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_l.name = "CountLabel"
	vb.add_child(name_l)
	vb.add_child(count_l)
	return slot


func _build_inv_slots() -> void:
	for c in _inv_grid.get_children():
		c.queue_free()
	_inv_slots.clear()
	for i in InventoryService.SLOT_COUNT:
		var slot := _make_slot_panel(_INV_SLOT_SIZE)
		slot.name = "InvSlot_%d" % i
		_inv_grid.add_child(slot)
		_inv_slots.append(slot)


func _build_skills_page(page: Control) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	page.add_child(margin)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(vb)
	var t := Label.new()
	t.name = "SkillsTitle"
	t.text = "Skills & vitals"
	t.add_theme_font_size_override("font_size", 20)
	vb.add_child(t)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.name = "SkillsGrid"
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	_append_skill_row(grid, "Name", Label.new(), true)
	_append_skill_row(grid, "Woodcutting", Label.new(), false)
	_append_skill_row(grid, "Mining", Label.new(), false)
	_append_skill_row(grid, "Active tool", Label.new(), false)
	_append_skill_row(grid, "Appearance head", Label.new(), false)
	_append_skill_row(grid, "Appearance chest", Label.new(), false)
	_append_skill_row(grid, "Appearance legs", Label.new(), false)


func _append_skill_row(grid: GridContainer, title: String, val: Label, is_header: bool) -> void:
	var a := Label.new()
	a.text = title
	if is_header:
		a.add_theme_font_size_override("font_size", 14)
	grid.add_child(a)
	val.add_theme_font_size_override("font_size", 14)
	val.name = "Val_%s" % title.replace(" ", "_")
	grid.add_child(val)


func _build_placeholder_page(page: Control, title: String) -> void:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.text = "%s — coming soon." % title
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 18)
	page.add_child(l)


func _build_crafting_page(page: Control) -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	page.add_child(root)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	root.add_child(left)
	var fl := Label.new()
	fl.text = "Station filter"
	left.add_child(fl)
	_page_crafting_filter = OptionButton.new()
	_page_crafting_filter.add_item("All stations", -1)
	_page_crafting_filter.add_item("Hand (none)", RecipeData.CraftStation.NONE)
	_page_crafting_filter.add_item("Campfire", RecipeData.CraftStation.CAMPFIRE)
	_page_crafting_filter.add_item("Stove", RecipeData.CraftStation.STOVE)
	_page_crafting_filter.add_item("Workbench", RecipeData.CraftStation.WORKBENCH)
	_page_crafting_filter.add_item("Anvil", RecipeData.CraftStation.ANVIL)
	_page_crafting_filter.add_item("Furnace", RecipeData.CraftStation.FURNACE)
	_page_crafting_filter.select(0)
	_page_crafting_filter.item_selected.connect(_on_craft_filter_selected)
	left.add_child(_page_crafting_filter)
	_page_crafting_list = ItemList.new()
	_page_crafting_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_crafting_list.custom_minimum_size = Vector2(260, 360)
	_page_crafting_list.item_selected.connect(_on_craft_recipe_selected)
	left.add_child(_page_crafting_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	_page_crafting_detail = RichTextLabel.new()
	_page_crafting_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_crafting_detail.bbcode_enabled = true
	_page_crafting_detail.fit_content = false
	_page_crafting_detail.scroll_active = true
	right.add_child(_page_crafting_detail)
	_page_crafting_craft = Button.new()
	_page_crafting_craft.text = "Craft"
	_page_crafting_craft.pressed.connect(_on_craft_pressed)
	right.add_child(_page_crafting_craft)


func _build_building_page(page: Control) -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 10)
	page.add_child(vb)
	var t := Label.new()
	t.text = "Building"
	t.add_theme_font_size_override("font_size", 20)
	vb.add_child(t)
	var body := RichTextLabel.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.bbcode_enabled = true
	body.text = (
		"Place structures and furniture from a build palette (planned).\n\n"
		+ "For now, use placeable items such as [b]campfire kits[/b] and [b]torches[/b] from inventory."
	)
	vb.add_child(body)


func _set_tab(idx: int) -> void:
	_current_tab = idx
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == idx)
	for i in _pages.size():
		_pages[i].visible = (i == idx)


func _on_tab_pressed(idx: int) -> void:
	_set_tab(idx)


func _refresh_inv_grid() -> void:
	if _inv_slots.is_empty():
		return
	for i in _inv_slots.size():
		var slot: Panel = _inv_slots[i]
		var icon_tex: TextureRect = slot.find_child("IconTexture", true, false)
		var icon_fb: Label = slot.find_child("IconFallback", true, false)
		var name_l: Label = slot.find_child("NameLabel", true, false)
		var count_l: Label = slot.find_child("CountLabel", true, false)
		var s: Variant = InventoryService.get_slot_data(i)
		if s != null:
			var item_id: String = str(s.get("id", ""))
			_apply_icon_to_texture_rect(icon_tex, icon_fb, item_id)
			name_l.text = _pretty_item_name(item_id)
			count_l.text = str(int(s.get("count", 0)))
			_apply_slot_style(slot, true)
		else:
			icon_tex.texture = null
			icon_fb.visible = false
			name_l.text = ""
			count_l.text = ""
			_apply_slot_style(slot, false)


func _refresh_equip_slots() -> void:
	for slot_id in _equip_panels.keys():
		var slot: Panel = _equip_panels[slot_id]
		var icon_tex: TextureRect = slot.find_child("IconTexture", true, false)
		var icon_fb: Label = slot.find_child("IconFallback", true, false)
		var name_l: Label = slot.find_child("NameLabel", true, false)
		var count_l: Label = slot.find_child("CountLabel", true, false)
		var s: Variant = GameState.equipment.get(slot_id, null)
		if s != null:
			var item_id: String = str(s.get("id", ""))
			_apply_icon_to_texture_rect(icon_tex, icon_fb, item_id)
			name_l.text = _pretty_item_name(item_id)
			count_l.text = str(int(s.get("count", 1)))
			_apply_slot_style(slot, true)
		else:
			icon_tex.texture = null
			icon_fb.visible = false
			name_l.text = ""
			count_l.text = ""
			_apply_slot_style(slot, false)


func _refresh_skills_page() -> void:
	var page: Control = _pages[1]
	var grid: GridContainer = page.find_child("SkillsGrid", true, false) as GridContainer
	if grid == null:
		return
	var p: Node = get_parent()
	var name_v: Label = grid.find_child("Val_Name", true, false) as Label
	var wood_v: Label = grid.find_child("Val_Woodcutting", true, false) as Label
	var mine_v: Label = grid.find_child("Val_Mining", true, false) as Label
	var tool_v: Label = grid.find_child("Val_Active_tool", true, false) as Label
	var head_v: Label = grid.find_child("Val_Appearance_head", true, false) as Label
	var chest_v: Label = grid.find_child("Val_Appearance_chest", true, false) as Label
	var legs_v: Label = grid.find_child("Val_Appearance_legs", true, false) as Label
	if name_v:
		name_v.text = GameState.player_name if GameState.player_name != "" else "—"
	if wood_v:
		wood_v.text = str(GameState.woodcutting_level)
	if mine_v:
		mine_v.text = str(GameState.mining_level)
	if p != null and p.has_method("get_equipment_sheet_snapshot"):
		var e: Dictionary = p.get_equipment_sheet_snapshot()
		if tool_v:
			tool_v.text = str(e.get("active_tool", "—"))
		if head_v:
			head_v.text = str(e.get("head", "—"))
		if chest_v:
			chest_v.text = str(e.get("chest", "—"))
		if legs_v:
			legs_v.text = str(e.get("legs", "—"))
	else:
		if tool_v:
			tool_v.text = "—"
		if head_v:
			head_v.text = "—"
		if chest_v:
			chest_v.text = "—"
		if legs_v:
			legs_v.text = "—"


func _on_craft_filter_selected(idx: int) -> void:
	var id := int(_page_crafting_filter.get_item_id(idx))
	_station_filter_idx = id
	_refresh_crafting_list()


func _refresh_crafting_list() -> void:
	if _page_crafting_list == null:
		return
	_page_crafting_list.clear()
	_craft_recipes.clear()
	var all_r: Array[RecipeData] = RecipeCatalog.get_all_recipes()
	for r in all_r:
		if not _recipe_passes_filter(r):
			continue
		var label := r.display_name if r.display_name != "" else r.id
		_page_crafting_list.add_item(label)
		var li := _page_crafting_list.item_count - 1
		_page_crafting_list.set_item_metadata(li, r.id)
		_craft_recipes.append(r)
	if _page_crafting_list.item_count > 0:
		_page_crafting_list.select(0)
		_on_craft_recipe_selected(0)
	else:
		_craft_selected = null
		_refresh_crafting_detail()


func _recipe_passes_filter(r: RecipeData) -> bool:
	if _station_filter_idx < 0:
		return true
	return int(r.station) == _station_filter_idx


func _on_craft_recipe_selected(idx: int) -> void:
	if idx < 0 or idx >= _page_crafting_list.item_count:
		_craft_selected = null
		_refresh_crafting_detail()
		return
	var rid: Variant = _page_crafting_list.get_item_metadata(idx)
	_craft_selected = RecipeCatalog.get_recipe(str(rid))
	_refresh_crafting_detail()


func _refresh_crafting_detail() -> void:
	if _page_crafting_detail == null:
		return
	var r := _craft_selected
	if r == null:
		_page_crafting_detail.text = "Select a recipe."
		if _page_crafting_craft:
			_page_crafting_craft.disabled = true
		return
	var lines: PackedStringArray = []
	lines.append("[b]%s[/b]\n" % (r.display_name if r.display_name != "" else r.id))
	lines.append("Station: [i]%s[/i]\n" % _station_name(r.station))
	if r.inputs.size() > 0:
		lines.append("\n[b]Requires:[/b]\n")
		for ing in r.inputs:
			if ing == null:
				continue
			var have := InventoryService.get_item_count(ing.item_id)
			var ok := have >= ing.count
			var mark := "[+] " if ok else "[-] "
			lines.append(
				"%s%s x%d (%d / %d)\n"
				% [mark, _pretty_item_name(ing.item_id), ing.count, have, ing.count]
			)
	else:
		lines.append("\n(No ingredients defined.)\n")
	if r.required_tool_ids.size() > 0:
		lines.append("\n[b]Tools in bag (not consumed):[/b]\n")
		for tid in r.required_tool_ids:
			if str(tid).is_empty():
				continue
			var has_t := InventoryService.has_item(str(tid))
			var mark2 := "[+] " if has_t else "[-] "
			lines.append("%s%s\n" % [mark2, _pretty_item_name(str(tid))])
	lines.append(
		"\n[b]Output:[/b] %s x%d\n"
		% [_pretty_item_name(r.output_item_id), r.output_count]
	)
	_page_crafting_detail.text = "".join(lines)
	if _page_crafting_craft:
		var st := r.station
		_page_crafting_craft.disabled = not CraftingService.can_craft(r, st)


func _station_name(st: RecipeData.CraftStation) -> String:
	match st:
		RecipeData.CraftStation.NONE:
			return "Hand"
		RecipeData.CraftStation.CAMPFIRE:
			return "Campfire"
		RecipeData.CraftStation.STOVE:
			return "Stove"
		RecipeData.CraftStation.WORKBENCH:
			return "Workbench"
		RecipeData.CraftStation.ANVIL:
			return "Anvil"
		RecipeData.CraftStation.FURNACE:
			return "Furnace"
		_:
			return str(st)


func _on_craft_pressed() -> void:
	var r := _craft_selected
	if r == null:
		return
	if CraftingService.craft(r, r.station):
		_toast("Crafted: %s" % _pretty_item_name(r.output_item_id))
		_refresh_crafting_detail()
		_refresh_inv_grid()
	else:
		_toast("Cannot craft that right now.")


func _inv_slot_from_mouse(global_pos: Vector2) -> int:
	for i in _inv_slots.size():
		if _inv_slots[i].get_global_rect().has_point(global_pos):
			return i
	return -1


func _equip_slot_from_mouse(global_pos: Vector2) -> String:
	for slot_id in _equip_panels.keys():
		var p: Panel = _equip_panels[slot_id]
		if p.get_global_rect().has_point(global_pos):
			return slot_id
	return ""


func _try_begin_drag_at(global_pos: Vector2) -> void:
	var ii := _inv_slot_from_mouse(global_pos)
	if ii >= 0:
		var s: Variant = InventoryService.get_slot_data(ii)
		if s == null:
			return
		_begin_drag_inv(ii)
		return
	var es := _equip_slot_from_mouse(global_pos)
	if es != "":
		var s2: Variant = GameState.equipment.get(es, null)
		if s2 == null:
			return
		_begin_drag_equip(es)


func _begin_drag_inv(idx: int) -> void:
	var s: Variant = InventoryService.get_slot_data(idx)
	if s == null:
		return
	_drag = {"k": "inv", "i": idx}
	_show_drag_preview(str(s.get("id", "")), int(s.get("count", 0)))


func _begin_drag_equip(slot_id: String) -> void:
	var s: Variant = GameState.equipment.get(slot_id, null)
	if s == null:
		return
	_drag = {"k": "eq", "s": slot_id}
	_show_drag_preview(str(s.get("id", "")), int(s.get("count", 1)))


func _show_drag_preview(item_id: String, count: int) -> void:
	_apply_icon_to_texture_rect(_drag_icon, _drag_fallback, item_id)
	_drag_name.text = _pretty_item_name(item_id)
	_drag_count.text = str(count)
	_drag_preview.visible = true
	var mp := get_viewport().get_mouse_position()
	_drag_preview.global_position = mp + Vector2(16, 16)


func _finish_drag_at(global_pos: Vector2) -> void:
	if _drag.is_empty():
		return
	var to_inv := _inv_slot_from_mouse(global_pos)
	var to_eq := _equip_slot_from_mouse(global_pos)
	if _drag["k"] == "inv":
		var from_i: int = int(_drag["i"])
		if to_inv >= 0:
			InventoryService.move_or_merge(from_i, to_inv)
		elif to_eq != "":
			_try_drop_inv_on_equip(from_i, to_eq)
		else:
			_drop_dragged_to_world(global_pos)
	elif _drag["k"] == "eq":
		var from_s: String = str(_drag["s"])
		if to_inv >= 0:
			_try_drop_equip_on_inv(from_s, to_inv)
		elif to_eq != "" and to_eq != from_s:
			_try_swap_equip_slots(from_s, to_eq)
		else:
			_drop_equipped_to_world(global_pos, from_s)
	_cancel_drag()


func _cancel_drag() -> void:
	_drag = {}
	_drag_preview.visible = false


func _drop_dragged_to_world(global_pos: Vector2) -> void:
	if _drag.get("k", "") != "inv":
		return
	var idx: int = int(_drag["i"])
	var player := get_parent() as Node3D
	if player == null:
		return
	var cam: Camera3D = player.get_node_or_null("CameraRig/SpringArm3D/Camera3D")
	if cam == null:
		return
	var origin := cam.project_ray_origin(global_pos)
	var normal := cam.project_ray_normal(global_pos)
	var target := origin + normal * 6.0
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(query)
	var drop_pos := player.global_position + player.global_basis.z * 0.8 + Vector3.UP * 0.25
	if hit.size() > 0:
		drop_pos = (hit["position"] as Vector3) + Vector3.UP * 0.3
	InventoryService.drop_slot_to_world(idx, drop_pos, player.get_parent())


func _drop_equipped_to_world(global_pos: Vector2, equip_slot: String) -> void:
	var s: Variant = GameState.equipment.get(equip_slot, null)
	if s == null:
		return
	var player := get_parent() as Node3D
	if player == null:
		return
	var cam: Camera3D = player.get_node_or_null("CameraRig/SpringArm3D/Camera3D")
	if cam == null:
		return
	var origin := cam.project_ray_origin(global_pos)
	var normal := cam.project_ray_normal(global_pos)
	var target := origin + normal * 6.0
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(query)
	var drop_pos := player.global_position + player.global_basis.z * 0.8 + Vector3.UP * 0.25
	if hit.size() > 0:
		drop_pos = (hit["position"] as Vector3) + Vector3.UP * 0.3
	var id := str(s.get("id", ""))
	var count := int(s.get("count", 1))
	GameState.equipment.erase(equip_slot)
	var scene: PackedScene = InventoryService.PICKUP_SCENES.get(id, null)
	if scene == null:
		_toast("Cannot drop that item.")
		GameState.equipment[equip_slot] = s
		_refresh_equip_slots()
		return
	var node := scene.instantiate()
	if node == null:
		GameState.equipment[equip_slot] = s
		return
	var wp := player.get_parent()
	if wp != null:
		wp.add_child(node)
	if node is Node3D:
		(node as Node3D).global_position = drop_pos
	if node.has_method("set_resource_type"):
		node.set_resource_type(id)
	elif "resource_type" in node:
		node.resource_type = id
	if node.has_method("set_quantity"):
		node.set_quantity(count)
	elif "quantity" in node:
		node.quantity = count
	_refresh_equip_slots()


func _try_drop_inv_on_equip(from_i: int, equip_slot: String) -> void:
	var inv_s: Variant = InventoryService.get_slot_data(from_i)
	if inv_s == null:
		return
	var it := ItemCatalog.get_item(str(inv_s.get("id", "")))
	if it == null:
		return
	if not _equip_accepts(equip_slot, it):
		_toast("Cannot equip that here.")
		return
	var old: Variant = GameState.equipment.get(equip_slot, null)
	if old == null:
		if not _equip_one_from_inv(from_i, equip_slot):
			return
	else:
		if int(inv_s.get("count", 0)) == 1:
			if not _swap_inv_equip(from_i, equip_slot):
				return
		else:
			if not _equip_replace_from_inv(from_i, equip_slot):
				return
	_refresh_inv_grid()
	_refresh_equip_slots()


func _try_drop_equip_on_inv(equip_slot: String, inv_idx: int) -> void:
	var eq: Variant = GameState.equipment.get(equip_slot, null)
	if eq == null:
		return
	var inv_s: Variant = InventoryService.get_slot_data(inv_idx)
	if inv_s == null:
		if not _unequip_to_inv(equip_slot, inv_idx):
			return
	else:
		if int(inv_s.get("count", 0)) != 1:
			_toast("Target slot must hold a single item to swap.")
			return
		var it := ItemCatalog.get_item(str(inv_s.get("id", "")))
		if it == null or not _equip_accepts(equip_slot, it):
			_toast("Cannot swap with that item.")
			return
		if not _swap_inv_equip(inv_idx, equip_slot):
			return
	_refresh_inv_grid()
	_refresh_equip_slots()


func _try_swap_equip_slots(a: String, b: String) -> void:
	var ea: Variant = GameState.equipment.get(a, null)
	var eb: Variant = GameState.equipment.get(b, null)
	if ea == null and eb == null:
		return
	if ea != null:
		var ita := ItemCatalog.get_item(str(ea.get("id", "")))
		if ita == null or not _equip_accepts(b, ita):
			_toast("Cannot move that to the other slot.")
			return
	if eb != null:
		var itb := ItemCatalog.get_item(str(eb.get("id", "")))
		if itb == null or not _equip_accepts(a, itb):
			_toast("Cannot move that to the other slot.")
			return
	if ea == null:
		GameState.equipment[a] = eb
		GameState.equipment.erase(b)
	elif eb == null:
		GameState.equipment[b] = ea
		GameState.equipment.erase(a)
	else:
		GameState.equipment[a] = eb
		GameState.equipment[b] = ea
	_refresh_equip_slots()


func _equip_one_from_inv(inv_idx: int, equip_slot: String) -> bool:
	var inv_s: Variant = InventoryService.get_slot_data(inv_idx)
	if inv_s == null:
		return false
	var new_id := str(inv_s.get("id", ""))
	var it := ItemCatalog.get_item(new_id)
	if it == null or not _equip_accepts(equip_slot, it):
		_toast("Cannot equip that here.")
		return false
	if not InventoryService.remove_amount_from_slot(inv_idx, 1):
		return false
	GameState.equipment[equip_slot] = {"id": new_id, "count": 1}
	return true


func _equip_replace_from_inv(inv_idx: int, equip_slot: String) -> bool:
	var inv_s: Variant = InventoryService.get_slot_data(inv_idx)
	if inv_s == null:
		return false
	var new_id := str(inv_s.get("id", ""))
	var it := ItemCatalog.get_item(new_id)
	if it == null or not _equip_accepts(equip_slot, it):
		_toast("Cannot equip that here.")
		return false
	var old: Variant = GameState.equipment.get(equip_slot, null)
	if old == null:
		return _equip_one_from_inv(inv_idx, equip_slot)
	if not InventoryService.remove_amount_from_slot(inv_idx, 1):
		return false
	var left := InventoryService.add_item(str(old.get("id", "")), int(old.get("count", 1)))
	if left > 0:
		InventoryService.add_item(new_id, 1)
		GameState.equipment[equip_slot] = old
		_toast("Inventory full.")
		return false
	GameState.equipment[equip_slot] = {"id": new_id, "count": 1}
	return true


func _unequip_to_inv(equip_slot: String, inv_idx: int) -> bool:
	var eq: Variant = GameState.equipment.get(equip_slot, null)
	if eq == null:
		return false
	var inv_s: Variant = InventoryService.get_slot_data(inv_idx)
	if inv_s != null:
		return false
	InventoryService.set_slot_data(
		inv_idx, {"id": str(eq.get("id", "")), "count": int(eq.get("count", 1))}
	)
	GameState.equipment.erase(equip_slot)
	return true


func _swap_inv_equip(inv_idx: int, equip_slot: String) -> bool:
	var inv_s: Variant = InventoryService.get_slot_data(inv_idx)
	var eq: Variant = GameState.equipment.get(equip_slot, null)
	if inv_s == null or eq == null:
		return false
	if int(inv_s.get("count", 0)) != 1:
		_toast("Split the stack first.")
		return false
	var it_i := ItemCatalog.get_item(str(inv_s.get("id", "")))
	if it_i == null or not _equip_accepts(equip_slot, it_i):
		_toast("Cannot equip that here.")
		return false
	var eq_d := {"id": str(eq.get("id", "")), "count": int(eq.get("count", 1))}
	var inv_d := {"id": str(inv_s.get("id", "")), "count": 1}
	InventoryService.set_slot_data(inv_idx, eq_d)
	GameState.equipment[equip_slot] = inv_d
	return true


func _equip_accepts(equip_slot: String, it: ItemData) -> bool:
	if it == null:
		return false
	match equip_slot:
		"main_hand":
			return it.category in [ItemData.Category.TOOL, ItemData.Category.WEAPON]
		"off_hand":
			return it.category in [
				ItemData.Category.TOOL,
				ItemData.Category.WEAPON,
				ItemData.Category.RELIC,
			]
		"head", "chest", "legs", "feet", "hands", "back":
			return it.category in [ItemData.Category.ARMOR, ItemData.Category.CLOTHING]
		"neck", "ring_1", "ring_2":
			return it.category == ItemData.Category.JEWERLY
		_:
			return false


func _toast(msg: String) -> void:
	var p: Node = get_parent()
	if p != null and p.has_method("show_gameplay_message"):
		p.call("show_gameplay_message", msg)


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
		fallback.text = _item_icon_abbrev(item_id)


func _pretty_item_name(item_id: String) -> String:
	var n: String = InventoryService.get_item_display_name(item_id)
	if not n.is_empty():
		return n
	var s := item_id.replace("_", " ")
	if s.is_empty():
		return ""
	return s.capitalize()


func _item_icon_abbrev(item_id: String) -> String:
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
