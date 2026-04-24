extends CanvasLayer
class_name GameMenu

## Spine tab indices (7 tabs + Codex uses World / People / Items filters inside).
const TAB_VITALS := 0
const TAB_SKILLS := 1
const TAB_INVENTORY := 2
const TAB_MAGIC := 3
const TAB_FORGE := 4
const TAB_QUESTS := 5
const TAB_CODEX := 6

const _SLOT_COLS := 4
const _INV_SLOT_SIZE := Vector2(70, 82)
const _EQUIP_SLOT_SIZE := Vector2(62, 74)

const _TAB_NAMES: PackedStringArray = [
	"Vitals",
	"Skills",
	"Inventory",
	"Magic",
	"Forge",
	"Quests",
	"Codex",
]

const _CODEX_WORLD: Array[Dictionary] = [
	{
		"id": "regions_intro",
		"title": "The Shattered North",
		"body": "Runesinger sagas tell of kingdoms drowned in ash-sea and forests that remember every axe-stroke. Your road is inked one camp at a time.\n\n[i]Explore to uncover more verses.[/i]",
	},
	{
		"id": "map_stub",
		"title": "Traveler’s chart",
		"body": "No master cartographer walks with you yet. Markers and fog-of-war will appear here as waypoints are earned.\n\n[b]Tip:[/b] high ground reveals paths at dawn.",
	},
]
const _CODEX_PEOPLE: Array[Dictionary] = [
	{
		"id": "you",
		"title": "Your hero",
		"body": "Name and deeds are written as you play. Factions and bonds will appear when dialogue systems hook this codex.",
	},
]
const _CODEX_ITEMS: Array[Dictionary] = [
	{
		"id": "codex_items_hint",
		"title": "Relics & materials",
		"body": "Items you examine or loot will log short lore here (schemas already live under ItemCatalog).\n\n[i]Select an entry after discovery is wired.[/i]",
	},
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

## UI Borders pack (new default visual language for the menu shell and widgets).
const _UIB := "res://assets/ui/UI Borders/PNG/Default/"
const _PANEL_MAIN := _UIB + "Border/panel-border-016.png"
const _PANEL_MAIN_FALLBACK := _UIB + "Border/panel-border-012.png"
const _PANEL_CARD := _UIB + "Transparent border/panel-transparent-border-020.png"
const _TAB_IDLE := _UIB + "Border/panel-border-009.png"
const _TAB_ACTIVE := _UIB + "Border/panel-border-004.png"
const _BTN_GENERIC_NORMAL := _UIB + "Border/panel-border-007.png"
const _BTN_GENERIC_PRESSED := _UIB + "Border/panel-border-003.png"
const _SLOT_INV_EMPTY := _UIB + "Border/panel-border-010.png"
const _SLOT_EQUIP := _UIB + "Border/panel-border-011.png"
const _MARGIN_PANEL := 24
const _MARGIN_TAB := 16
const _SB_SLOT := 16

## Frost ledger — pale ink on cool stone
const _COL_INK := Color(0.82, 0.9, 0.95, 1.0)
const _COL_INK_MUTED := Color(0.55, 0.64, 0.72, 1.0)
const _COL_TITLE := Color(0.98, 0.86, 0.48, 1.0)

var _ui_tex: Dictionary = {}  ## String -> Texture2D

@onready var _backdrop: ColorRect = $Backdrop
@onready var _book: PanelContainer = $ScreenFill/Center/BookPanel
@onready var _tab_column: VBoxContainer = $ScreenFill/Center/BookPanel/InnerMargin/MainVBox/Body/TabColumn
@onready var _page_host: Control = $ScreenFill/Center/BookPanel/InnerMargin/MainVBox/Body/PageHost
@onready var _drag_preview: Panel = $DragPreview
@onready var _drag_icon: TextureRect = $DragPreview/Margin/VBox/IconTexture
@onready var _drag_fallback: Label = $DragPreview/Margin/VBox/IconFallback
@onready var _drag_name: Label = $DragPreview/Margin/VBox/NameLabel
@onready var _drag_count: Label = $DragPreview/Margin/VBox/CountLabel

var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _current_tab: int = 0
var _page_flipping: bool = false
var _page_flip_tween: Tween
var _pending_tab: int = -1

## Half of the journal "page" flip: out (spine) + in. Total ~0.3s — between a soft fade and a long curl.
const _FLIP_OUT_SEC := 0.14
const _FLIP_IN_SEC := 0.17

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

var _vital_health_bar: ProgressBar
var _vital_stamina_bar: ProgressBar
var _vital_health_lbl: Label
var _vital_stamina_lbl: Label
var _vital_effects_body: RichTextLabel

var _codex_filter: OptionButton
var _codex_list: ItemList
var _codex_detail: RichTextLabel


func _ready() -> void:
	layer = 25
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style_book_panel()
	_build_tabs()
	_build_pages()
	call_deferred("_ensure_all_page_pivots")
	_drag_preview.visible = false
	_drag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_backdrop.gui_input.connect(_on_backdrop_gui_input)
	InventoryService.inventory_changed.connect(_on_inventory_changed)
	_style_drag_preview()
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
	_set_tab_instant(clampi(tab_idx, 0, _TAB_NAMES.size() - 1))
	_play_open_anim()
	_refresh_inv_grid()
	_refresh_equip_slots()
	_refresh_skills_page()
	_refresh_vitals_page()
	_refresh_crafting_list()
	_refresh_crafting_detail()
	if _current_tab == TAB_CODEX:
		_refresh_codex_list()


func close_menu() -> void:
	_close_tackle_window()
	_cancel_drag()
	_kill_page_flip_tween()
	_set_tab_instant(_get_selected_tab_index())
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


func _get_ui_tex(path: String) -> Texture2D:
	if not _ui_tex.has(path) and ResourceLoader.exists(path):
		_ui_tex[path] = load(path) as Texture2D
	if _ui_tex.has(path):
		return _ui_tex[path]
	return null


func _make_stylebox_texture(path: String, m: int) -> StyleBoxTexture:
	var t: Texture2D = _get_ui_tex(path)
	var sb := StyleBoxTexture.new()
	if t != null:
		sb.texture = t
		sb.texture_margin_left = m
		sb.texture_margin_top = m
		sb.texture_margin_right = m
		sb.texture_margin_bottom = m
	return sb


func _stylebook_flat_for_book() -> void:
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0.04, 0.07, 0.1, 0.96)
	flat.border_color = Color(0.45, 0.62, 0.78, 1.0)
	flat.set_border_width_all(3)
	flat.set_corner_radius_all(6)
	flat.set_content_margin_all(20)
	_book.add_theme_stylebox_override("panel", flat)


func _style_book_panel() -> void:
	var path := _PANEL_MAIN
	if not ResourceLoader.exists(path) and ResourceLoader.exists(_PANEL_MAIN_FALLBACK):
		path = _PANEL_MAIN_FALLBACK
	if not ResourceLoader.exists(path):
		_stylebook_flat_for_book()
		return
	var sb := _make_stylebox_texture(path, _MARGIN_PANEL)
	if sb.texture == null:
		_stylebook_flat_for_book()
		return
	_book.add_theme_stylebox_override("panel", sb)


func _style_drag_preview() -> void:
	if ResourceLoader.exists(_SLOT_INV_EMPTY):
		var sb := _make_stylebox_texture(_SLOT_INV_EMPTY, 12)
		if sb.texture != null:
			_drag_preview.add_theme_stylebox_override("panel", sb)
			_drag_name.add_theme_color_override("font_color", _COL_INK)
			_drag_count.add_theme_color_override("font_color", _COL_INK)
			return
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0.06, 0.09, 0.12, 0.92)
	flat.border_color = Color(0.5, 0.68, 0.82, 1.0)
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(5)
	flat.set_content_margin_all(6)
	_drag_preview.add_theme_stylebox_override("panel", flat)
	_drag_name.add_theme_color_override("font_color", _COL_INK)
	_drag_count.add_theme_color_override("font_color", _COL_INK)


func _apply_inner_card_style(p: PanelContainer) -> void:
	if ResourceLoader.exists(_PANEL_CARD):
		var sb_tex := _make_stylebox_texture(_PANEL_CARD, 20)
		if sb_tex.texture != null:
			p.add_theme_stylebox_override("panel", sb_tex)
			return
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0.03, 0.06, 0.09, 0.42)
	flat.border_color = Color(0.42, 0.62, 0.78, 0.45)
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(8)
	flat.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", flat)


func _style_scroll_transparent(sc: ScrollContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_content_margin_all(4)
	sc.add_theme_stylebox_override("panel", sb)


func _style_item_list_transparent(list: ItemList) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	list.add_theme_stylebox_override("panel", sb)


func _apply_section_title(l: Label) -> void:
	l.add_theme_color_override("font_color", _COL_TITLE)
	l.add_theme_font_size_override("font_size", 19)


func _apply_body_label(l: Label, font_size: int = 12) -> void:
	l.add_theme_color_override("font_color", _COL_INK)
	l.add_theme_font_size_override("font_size", font_size)


func _style_tab_button(b: Button) -> void:
	var path_idle := _TAB_IDLE
	var path_active := _TAB_ACTIVE
	if not ResourceLoader.exists(path_idle) or not ResourceLoader.exists(path_active):
		_style_tab_button_flat(b)
		return
	var sb_idle := _make_stylebox_texture(path_idle, _MARGIN_TAB)
	var sb_active := _make_stylebox_texture(path_active, _MARGIN_TAB)
	if sb_idle.texture == null or sb_active.texture == null:
		_style_tab_button_flat(b)
		return
	if b.button_pressed:
		b.add_theme_stylebox_override("normal", sb_active)
		b.add_theme_stylebox_override("hover", sb_active)
		b.add_theme_stylebox_override("pressed", sb_active)
	else:
		b.add_theme_stylebox_override("normal", sb_idle)
		b.add_theme_stylebox_override("hover", sb_idle)
		b.add_theme_stylebox_override("pressed", sb_idle)
	if b.button_pressed:
		b.add_theme_color_override("font_color", _COL_TITLE)
		b.add_theme_color_override("font_focus_color", _COL_TITLE)
	else:
		b.add_theme_color_override("font_color", _COL_INK)
		b.add_theme_color_override("font_focus_color", _COL_INK)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_constant_override("content_margin_left", 14)
	b.add_theme_constant_override("content_margin_right", 10)
	b.add_theme_constant_override("content_margin_top", 6)
	b.add_theme_constant_override("content_margin_bottom", 6)


func _style_tab_button_flat(b: Button) -> void:
	var sb_on := StyleBoxFlat.new()
	sb_on.bg_color = Color(0.12, 0.18, 0.24, 0.88)
	sb_on.border_color = Color(0.55, 0.75, 0.92, 0.85)
	sb_on.set_border_width_all(2)
	sb_on.set_corner_radius_all(5)
	sb_on.set_content_margin_all(8)
	var sb_off := StyleBoxFlat.new()
	sb_off.bg_color = Color(0.06, 0.09, 0.12, 0.65)
	sb_off.border_color = Color(0.35, 0.48, 0.58, 0.55)
	sb_off.set_border_width_all(2)
	sb_off.set_corner_radius_all(5)
	sb_off.set_content_margin_all(8)
	if b.button_pressed:
		b.add_theme_stylebox_override("normal", sb_on)
		b.add_theme_stylebox_override("hover", sb_on)
		b.add_theme_stylebox_override("pressed", sb_on)
		b.add_theme_color_override("font_color", _COL_TITLE)
		b.add_theme_color_override("font_focus_color", _COL_TITLE)
	else:
		b.add_theme_stylebox_override("normal", sb_off)
		b.add_theme_stylebox_override("hover", sb_on)
		b.add_theme_stylebox_override("pressed", sb_off)
		b.add_theme_color_override("font_color", _COL_INK)
		b.add_theme_color_override("font_focus_color", _COL_INK)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_constant_override("content_margin_left", 14)
	b.add_theme_constant_override("content_margin_right", 10)
	b.add_theme_constant_override("content_margin_top", 6)
	b.add_theme_constant_override("content_margin_bottom", 6)


func _refresh_tab_styles() -> void:
	for b in _tab_buttons:
		_style_tab_button(b)


func _style_generic_journal_button(b: BaseButton) -> void:
	if not ResourceLoader.exists(_BTN_GENERIC_NORMAL):
		return
	var sb_n := _make_stylebox_texture(_BTN_GENERIC_NORMAL, 14)
	if sb_n.texture == null:
		return
	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_n)
	if ResourceLoader.exists(_BTN_GENERIC_PRESSED):
		var sb_p := _make_stylebox_texture(_BTN_GENERIC_PRESSED, 20)
		if sb_p.texture != null:
			b.add_theme_stylebox_override("pressed", sb_p)
		else:
			b.add_theme_stylebox_override("pressed", sb_n)
	else:
		b.add_theme_stylebox_override("pressed", sb_n)
	b.add_theme_color_override("font_color", _COL_INK)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_constant_override("content_margin_left", 10)
	b.add_theme_constant_override("content_margin_right", 10)
	b.add_theme_constant_override("content_margin_top", 4)
	b.add_theme_constant_override("content_margin_bottom", 4)
	if b is Button and not (b is OptionButton):
		(b as Button).custom_minimum_size = Vector2(0, 32)


func _build_tabs() -> void:
	for c in _tab_column.get_children():
		c.queue_free()
	_tab_buttons.clear()
	for i in _TAB_NAMES.size():
		var b := Button.new()
		b.name = "TabBtn_%d" % i
		b.text = _TAB_NAMES[i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, 36)
		b.pressed.connect(_on_tab_pressed.bind(i))
		_tab_column.add_child(b)
		_tab_buttons.append(b)
	var tab_spacer := Control.new()
	tab_spacer.name = "TabColumnSpacer"
	tab_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_column.add_child(tab_spacer)
	_refresh_tab_styles()


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
			TAB_VITALS:
				_build_vitals_page(page)
			TAB_SKILLS:
				_build_skills_page(page)
			TAB_INVENTORY:
				_build_inventory_page(page)
			TAB_MAGIC:
				_build_magic_page(page)
			TAB_FORGE:
				_build_forge_page(page)
			TAB_QUESTS:
				_build_quests_page(page)
			TAB_CODEX:
				_build_codex_page(page)
		_connect_page_resize(page)
	_set_tab_instant(0)


func _build_vitals_page(page: Control) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	page.add_child(margin)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_inner_card_style(card)
	margin.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)
	var t := Label.new()
	t.text = "Vitals & effects"
	_apply_section_title(t)
	t.add_theme_font_size_override("font_size", 21)
	vb.add_child(t)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 10)
	vb.add_child(hp_row)
	var hp_l := Label.new()
	hp_l.text = "Health"
	hp_l.custom_minimum_size = Vector2(72, 0)
	_apply_body_label(hp_l, 14)
	hp_row.add_child(hp_l)
	_vital_health_bar = ProgressBar.new()
	_vital_health_bar.custom_minimum_size = Vector2(180, 22)
	_vital_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vital_health_bar.max_value = 100.0
	_vital_health_bar.value = 100.0
	_vital_health_bar.show_percentage = false
	_style_vitals_bar(_vital_health_bar, Color(0.72, 0.22, 0.18, 1.0))
	hp_row.add_child(_vital_health_bar)
	_vital_health_lbl = Label.new()
	_vital_health_lbl.custom_minimum_size = Vector2(88, 0)
	_vital_health_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_body_label(_vital_health_lbl, 13)
	hp_row.add_child(_vital_health_lbl)
	var st_row := HBoxContainer.new()
	st_row.add_theme_constant_override("separation", 10)
	vb.add_child(st_row)
	var st_l := Label.new()
	st_l.text = "Stamina"
	st_l.custom_minimum_size = Vector2(72, 0)
	_apply_body_label(st_l, 14)
	st_row.add_child(st_l)
	_vital_stamina_bar = ProgressBar.new()
	_vital_stamina_bar.custom_minimum_size = Vector2(180, 22)
	_vital_stamina_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vital_stamina_bar.max_value = 100.0
	_vital_stamina_bar.value = 100.0
	_vital_stamina_bar.show_percentage = false
	_style_vitals_bar(_vital_stamina_bar, Color(0.32, 0.72, 0.88, 1.0))
	st_row.add_child(_vital_stamina_bar)
	_vital_stamina_lbl = Label.new()
	_vital_stamina_lbl.custom_minimum_size = Vector2(88, 0)
	_vital_stamina_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_body_label(_vital_stamina_lbl, 13)
	st_row.add_child(_vital_stamina_lbl)
	var fx := Label.new()
	fx.text = "Active effects"
	_apply_section_title(fx)
	fx.add_theme_font_size_override("font_size", 17)
	vb.add_child(fx)
	_vital_effects_body = RichTextLabel.new()
	_vital_effects_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vital_effects_body.bbcode_enabled = true
	_vital_effects_body.fit_content = false
	_vital_effects_body.scroll_active = true
	_vital_effects_body.custom_minimum_size = Vector2(0, 120)
	_vital_effects_body.add_theme_color_override("default_color", _COL_INK_MUTED)
	_vital_effects_body.text = "[i]No ailments or blessings tracked yet.[/i]"
	vb.add_child(_vital_effects_body)


func _style_vitals_bar(bar: ProgressBar, fill_col: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.08, 0.1, 0.92)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(4)
	fill.bg_color = fill_col
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)


func _build_inventory_page(page: Control) -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	page.add_child(root)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(238, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	root.add_child(left)
	var left_card := PanelContainer.new()
	left_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_inner_card_style(left_card)
	left.add_child(left_card)
	var left_inner := VBoxContainer.new()
	left_inner.add_theme_constant_override("separation", 8)
	left_card.add_child(left_inner)
	var lt := Label.new()
	lt.text = "Equipment"
	_apply_section_title(lt)
	left_inner.add_child(lt)
	var eg := GridContainer.new()
	eg.columns = 2
	eg.add_theme_constant_override("h_separation", 8)
	eg.add_theme_constant_override("v_separation", 8)
	left_inner.add_child(eg)
	_equip_panels.clear()
	for slot_id in _EQUIP_ORDER:
		var cell := VBoxContainer.new()
		var cap := Label.new()
		cap.text = _equip_label(slot_id)
		_apply_body_label(cap, 11)
		cap.add_theme_color_override("font_color", _COL_INK_MUTED)
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
	right.custom_minimum_size = Vector2(0, 0)
	root.add_child(right)
	var right_card := PanelContainer.new()
	right_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_inner_card_style(right_card)
	right.add_child(right_card)
	var right_inner := VBoxContainer.new()
	right_inner.add_theme_constant_override("separation", 6)
	right_card.add_child(right_inner)
	var rt := Label.new()
	rt.text = "Inventory"
	_apply_section_title(rt)
	right_inner.add_child(rt)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(120, 160)
	sc.clip_contents = true
	_style_scroll_transparent(sc)
	right_inner.add_child(sc)
	_inv_grid = GridContainer.new()
	_inv_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_grid.columns = _SLOT_COLS
	_inv_grid.add_theme_constant_override("h_separation", 6)
	_inv_grid.add_theme_constant_override("v_separation", 6)
	sc.add_child(_inv_grid)
	_build_inv_slots()
	var help := Label.new()
	help.text = "Drag between slots and equipment. Drop outside to place. Right-click a tackle box to manage lures."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_body_label(help, 11)
	help.add_theme_color_override("font_color", _COL_INK_MUTED)
	right_inner.add_child(help)


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
	_apply_body_label(name_l, 10)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_l.name = "NameLabel"
	var count_l := Label.new()
	count_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_body_label(count_l, 12)
	count_l.add_theme_color_override("font_color", _COL_TITLE)
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
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	page.add_child(margin)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_inner_card_style(card)
	margin.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	var t := Label.new()
	t.name = "SkillsTitle"
	t.text = "Skills"
	_apply_section_title(t)
	t.add_theme_font_size_override("font_size", 21)
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
		a.add_theme_font_size_override("font_size", 15)
		a.add_theme_color_override("font_color", _COL_TITLE)
	else:
		_apply_body_label(a, 14)
	grid.add_child(a)
	if not is_header:
		_apply_body_label(val, 14)
	else:
		val.add_theme_font_size_override("font_size", 15)
		val.add_theme_color_override("font_color", _COL_TITLE)
	val.name = "Val_%s" % title.replace(" ", "_")
	grid.add_child(val)


func _build_placeholder_page(page: Control, title: String) -> void:
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_inner_card_style(card)
	page.add_child(card)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	card.add_child(m)
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.text = "%s — coming soon." % title
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_body_label(l, 18)
	l.add_theme_color_override("font_color", _COL_INK_MUTED)
	m.add_child(l)


func _build_crafting_page(page: Control) -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	page.add_child(root)
	var left_card := PanelContainer.new()
	left_card.custom_minimum_size = Vector2(288, 0)
	left_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_inner_card_style(left_card)
	root.add_child(left_card)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left_card.add_child(left)
	var fl := Label.new()
	fl.text = "Station filter"
	_apply_body_label(fl, 13)
	fl.add_theme_color_override("font_color", _COL_INK_MUTED)
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
	_style_generic_journal_button(_page_crafting_filter)
	_page_crafting_list = ItemList.new()
	_page_crafting_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_crafting_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_crafting_list.custom_minimum_size = Vector2(120, 200)
	_page_crafting_list.add_theme_color_override("font_color", _COL_INK)
	_page_crafting_list.add_theme_color_override("font_hovered_color", _COL_TITLE)
	_page_crafting_list.item_selected.connect(_on_craft_recipe_selected)
	_style_item_list_transparent(_page_crafting_list)
	left.add_child(_page_crafting_list)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_inner_card_style(right)
	root.add_child(right)
	var right_inner := VBoxContainer.new()
	right_inner.add_theme_constant_override("separation", 8)
	right.add_child(right_inner)
	_page_crafting_detail = RichTextLabel.new()
	_page_crafting_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_crafting_detail.bbcode_enabled = true
	_page_crafting_detail.fit_content = false
	_page_crafting_detail.scroll_active = true
	_page_crafting_detail.add_theme_color_override("default_color", _COL_INK)
	right_inner.add_child(_page_crafting_detail)
	_page_crafting_craft = Button.new()
	_page_crafting_craft.text = "Craft"
	_page_crafting_craft.pressed.connect(_on_craft_pressed)
	_style_generic_journal_button(_page_crafting_craft)
	right_inner.add_child(_page_crafting_craft)


func _build_building_page(page: Control) -> void:
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_inner_card_style(card)
	page.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	var t := Label.new()
	t.text = "Building"
	_apply_section_title(t)
	t.add_theme_font_size_override("font_size", 21)
	vb.add_child(t)
	var body := RichTextLabel.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.bbcode_enabled = true
	body.add_theme_color_override("default_color", _COL_INK)
	body.text = (
		"Place structures and furniture from a build palette (planned).\n\n"
		+ "For now, use placeable items such as [b]campfire kits[/b] and [b]torches[/b] from inventory."
	)
	vb.add_child(body)


func _build_magic_page(page: Control) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	page.add_child(margin)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_inner_card_style(card)
	margin.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	var t := Label.new()
	t.text = "Magic & spells"
	_apply_section_title(t)
	t.add_theme_font_size_override("font_size", 21)
	vb.add_child(t)
	var body := RichTextLabel.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.bbcode_enabled = true
	body.add_theme_color_override("default_color", _COL_INK)
	body.text = (
		"Known spells, costs, and attunements will live here.\n\n"
		+ "[i]Binding runes to the hotbar is planned alongside the combat magic loop.[/i]\n\n"
		+ "Until then, keep your [b]relics[/b] close and read item tooltips for arcane bonuses."
	)
	vb.add_child(body)


func _build_forge_page(page: Control) -> void:
	var tabs := TabContainer.new()
	tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	tabs.tab_alignment = TabBar.ALIGNMENT_CENTER
	page.add_child(tabs)
	var craft_host := Control.new()
	craft_host.name = "Crafting"
	craft_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	tabs.add_child(craft_host)
	_build_crafting_page(craft_host)
	var build_host := Control.new()
	build_host.name = "Building"
	build_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	tabs.add_child(build_host)
	_build_building_page(build_host)


func _build_quests_page(page: Control) -> void:
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_inner_card_style(card)
	page.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	var t := Label.new()
	t.text = "Quests"
	_apply_section_title(t)
	t.add_theme_font_size_override("font_size", 21)
	vb.add_child(t)
	var body := RichTextLabel.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.bbcode_enabled = true
	body.add_theme_color_override("default_color", _COL_INK)
	body.text = (
		"No sworn oaths logged yet.\n\n"
		+ "When the quest journal is wired, [b]active[/b] and [b]completed[/b] tasks will appear here with rewards and map hints."
	)
	vb.add_child(body)


func _build_codex_page(page: Control) -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	page.add_child(root)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)
	var title := Label.new()
	title.text = "Codex"
	_apply_section_title(title)
	title.add_theme_font_size_override("font_size", 21)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_codex_filter = OptionButton.new()
	_codex_filter.focus_mode = Control.FOCUS_NONE
	_codex_filter.add_item("World", 0)
	_codex_filter.add_item("People", 1)
	_codex_filter.add_item("Items", 2)
	_codex_filter.select(0)
	_codex_filter.item_selected.connect(_on_codex_filter_changed)
	_style_generic_journal_button(_codex_filter)
	head.add_child(_codex_filter)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	var left_card := PanelContainer.new()
	left_card.custom_minimum_size = Vector2(260, 0)
	left_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_inner_card_style(left_card)
	body.add_child(left_card)
	var left_v := VBoxContainer.new()
	left_v.add_theme_constant_override("separation", 6)
	left_card.add_child(left_v)
	var fl := Label.new()
	fl.text = "Entries"
	_apply_body_label(fl, 12)
	fl.add_theme_color_override("font_color", _COL_INK_MUTED)
	left_v.add_child(fl)
	_codex_list = ItemList.new()
	_codex_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_codex_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_list.add_theme_color_override("font_color", _COL_INK)
	_codex_list.add_theme_color_override("font_hovered_color", _COL_TITLE)
	_codex_list.item_selected.connect(_on_codex_entry_selected)
	_style_item_list_transparent(_codex_list)
	left_v.add_child(_codex_list)
	var right_card := PanelContainer.new()
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_inner_card_style(right_card)
	body.add_child(right_card)
	_codex_detail = RichTextLabel.new()
	_codex_detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_codex_detail.bbcode_enabled = true
	_codex_detail.fit_content = false
	_codex_detail.scroll_active = true
	_codex_detail.add_theme_color_override("default_color", _COL_INK)
	right_card.add_child(_codex_detail)
	_refresh_codex_list()


func _codex_entries_for_filter(idx: int) -> Array[Dictionary]:
	match idx:
		0:
			return _CODEX_WORLD
		1:
			return _CODEX_PEOPLE
		2:
			return _CODEX_ITEMS
		_:
			return _CODEX_WORLD


func _refresh_codex_list() -> void:
	if _codex_list == null or _codex_detail == null:
		return
	_codex_list.clear()
	var f := _codex_filter.get_selected_id() if _codex_filter else 0
	var entries: Array[Dictionary] = _codex_entries_for_filter(int(f))
	for e in entries:
		var t: String = str(e.get("title", "???"))
		_codex_list.add_item(t)
		var li := _codex_list.item_count - 1
		_codex_list.set_item_metadata(li, e.get("id", ""))
	if _codex_list.item_count > 0:
		_codex_list.select(0)
		_on_codex_entry_selected(0)
	else:
		_codex_detail.text = "[i]Nothing written here yet.[/i]"


func _on_codex_filter_changed(_i: int) -> void:
	_refresh_codex_list()


func _on_codex_entry_selected(idx: int) -> void:
	if _codex_detail == null or _codex_list == null:
		return
	if idx < 0 or idx >= _codex_list.item_count:
		return
	var f := _codex_filter.get_selected_id() if _codex_filter else 0
	var entries: Array[Dictionary] = _codex_entries_for_filter(int(f))
	var pick_id: Variant = _codex_list.get_item_metadata(idx)
	for e in entries:
		if str(e.get("id", "")) == str(pick_id):
			var tit: String = str(e.get("title", ""))
			var bod: String = str(e.get("body", ""))
			_codex_detail.text = "[b]%s[/b]\n\n%s" % [tit, bod]
			return
	_codex_detail.text = "[i]Entry missing.[/i]"


func _refresh_vitals_page() -> void:
	if _vital_health_bar == null:
		return
	var p: Node = get_parent()
	if p == null or not p.has_method("get_hud_snapshot"):
		return
	var s: Dictionary = p.get_hud_snapshot()
	var mh: float = float(s.get("max_health", 1.0))
	var h: float = float(s.get("health", 0.0))
	var ms: float = float(s.get("max_stamina", 1.0))
	var st: float = float(s.get("stamina", 0.0))
	_vital_health_bar.max_value = mh
	_vital_health_bar.value = h
	_vital_stamina_bar.max_value = ms
	_vital_stamina_bar.value = st
	if _vital_health_lbl:
		_vital_health_lbl.text = "%d / %d" % [int(round(h)), int(round(mh))]
	if _vital_stamina_lbl:
		_vital_stamina_lbl.text = "%d / %d" % [int(round(st)), int(round(ms))]


func _set_tab_instant(idx: int) -> void:
	_kill_page_flip_tween()
	_page_flipping = false
	_pending_tab = -1
	if _tab_buttons.is_empty():
		return
	idx = clampi(idx, 0, _tab_buttons.size() - 1)
	_current_tab = idx
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == idx)
	for i in _pages.size():
		var p: Control = _pages[i]
		p.visible = (i == idx)
		p.scale = Vector2.ONE
		p.modulate = Color.WHITE
		_ensure_page_pivot(p)
	_refresh_tab_styles()


func _get_selected_tab_index() -> int:
	for i in _tab_buttons.size():
		if _tab_buttons[i].button_pressed:
			return i
	return _current_tab


func _ensure_page_pivot(p: Control) -> void:
	p.pivot_offset = Vector2(0.0, p.size.y * 0.5)


func _connect_page_resize(page: Control) -> void:
	page.resized.connect(_on_book_page_resized.bind(page))


func _on_book_page_resized(page: Control) -> void:
	_ensure_page_pivot(page)


func _ensure_all_page_pivots() -> void:
	for p in _pages:
		_ensure_page_pivot(p)


func _kill_page_flip_tween() -> void:
	if _page_flip_tween != null and is_instance_valid(_page_flip_tween):
		_page_flip_tween.kill()
	_page_flip_tween = null


func _on_tab_pressed(idx: int) -> void:
	idx = clampi(idx, 0, _tab_buttons.size() - 1)
	if _page_flipping:
		_pending_tab = idx
		for i in _tab_buttons.size():
			_tab_buttons[i].set_pressed_no_signal(i == idx)
		_refresh_tab_styles()
		return
	if idx == _current_tab:
		return
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == idx)
	_refresh_tab_styles()
	_begin_page_flip_to(idx)


func _swap_book_page(old_idx: int, new_idx: int) -> void:
	var out_p: Control = _pages[old_idx]
	var in_p: Control = _pages[new_idx]
	out_p.visible = false
	out_p.scale = Vector2.ONE
	out_p.modulate = Color.WHITE
	_current_tab = new_idx
	_ensure_page_pivot(in_p)
	in_p.visible = true
	in_p.scale = Vector2(0.0, 1.0)
	in_p.modulate = Color(0.82, 0.9, 0.96, 0.78)


func _on_page_flip_chain_finished() -> void:
	_page_flipping = false
	_page_flip_tween = null
	if _current_tab < _pages.size():
		var p: Control = _pages[_current_tab]
		p.scale = Vector2.ONE
		p.modulate = Color.WHITE
	if _current_tab == TAB_VITALS:
		_refresh_vitals_page()
	if _current_tab == TAB_CODEX:
		_refresh_codex_list()
	_refresh_tab_styles()
	var next: int = _pending_tab
	_pending_tab = -1
	if next >= 0 and next != _current_tab:
		for i in _tab_buttons.size():
			_tab_buttons[i].set_pressed_no_signal(i == next)
		_refresh_tab_styles()
		_begin_page_flip_to(next)


func _begin_page_flip_to(new_idx: int) -> void:
	new_idx = clampi(new_idx, 0, _pages.size() - 1)
	var old_idx: int = _current_tab
	if old_idx == new_idx:
		_page_flipping = false
		return
	_page_flipping = true
	_kill_page_flip_tween()
	var out_page: Control = _pages[old_idx]
	var in_page: Control = _pages[new_idx]
	_ensure_page_pivot(out_page)
	_ensure_page_pivot(in_page)
	for i in _pages.size():
		_pages[i].visible = (i == old_idx)
		if i == old_idx:
			_pages[i].scale = Vector2.ONE
			_pages[i].modulate = Color.WHITE
	out_page.visible = true
	# in_page stays hidden until _swap_book_page; others already not visible
	var tw: Tween = create_tween()
	_page_flip_tween = tw
	tw.tween_property(out_page, "scale", Vector2(0.0, 1.0), _FLIP_OUT_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN
	)
	tw.parallel().tween_property(
		out_page, "modulate", Color(0.55, 0.62, 0.7, 0.72), _FLIP_OUT_SEC
	)
	tw.tween_callback(_swap_book_page.bind(old_idx, new_idx))
	tw.tween_property(in_page, "scale", Vector2(1.0, 1.0), _FLIP_IN_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	tw.parallel().tween_property(in_page, "modulate", Color(1, 1, 1, 1), _FLIP_IN_SEC)
	tw.finished.connect(_on_page_flip_chain_finished, CONNECT_ONE_SHOT)


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
			_apply_slot_style(slot, true, "")
		else:
			icon_tex.texture = null
			icon_fb.visible = false
			name_l.text = ""
			count_l.text = ""
			_apply_slot_style(slot, false, "")


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
			_apply_slot_style(slot, true, slot_id)
		else:
			icon_tex.texture = null
			icon_fb.visible = false
			name_l.text = ""
			count_l.text = ""
			_apply_slot_style(slot, false, slot_id)


func _refresh_skills_page() -> void:
	var page: Control = _pages[TAB_SKILLS]
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
	if _current_tab != TAB_INVENTORY:
		return -1
	for i in _inv_slots.size():
		if _inv_slots[i].get_global_rect().has_point(global_pos):
			return i
	return -1


func _equip_slot_from_mouse(global_pos: Vector2) -> String:
	if _current_tab != TAB_INVENTORY:
		return ""
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


func _equip_slot_bg_path(slot_id: String) -> String:
	if slot_id.is_empty():
		return _SLOT_INV_EMPTY
	return _SLOT_EQUIP


func _apply_slot_style(slot: Panel, filled: bool, equip_slot_id: String = "") -> void:
	slot.modulate = Color.WHITE
	var tex_path: String = _equip_slot_bg_path(equip_slot_id) if equip_slot_id != "" else _SLOT_INV_EMPTY
	if ResourceLoader.exists(tex_path):
		var sb := _make_stylebox_texture(tex_path, _SB_SLOT)
		if sb.texture != null:
			slot.add_theme_stylebox_override("panel", sb)
			if filled:
				slot.modulate = Color(1.02, 1.04, 1.06, 1.0)
			else:
				slot.modulate = Color(0.88, 0.92, 0.96, 1.0)
			return
	var sb2 := StyleBoxFlat.new()
	if filled:
		sb2.bg_color = Color(0.1, 0.14, 0.18, 0.88)
		sb2.border_color = Color(0.45, 0.68, 0.82, 0.95)
	else:
		sb2.bg_color = Color(0.05, 0.07, 0.09, 0.72)
		sb2.border_color = Color(0.28, 0.4, 0.48, 0.75)
	sb2.set_border_width_all(2)
	sb2.set_corner_radius_all(4)
	sb2.content_margin_left = 4
	sb2.content_margin_top = 4
	sb2.content_margin_right = 4
	sb2.content_margin_bottom = 4
	slot.add_theme_stylebox_override("panel", sb2)


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
