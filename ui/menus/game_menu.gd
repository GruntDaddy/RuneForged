extends CanvasLayer
class_name GameMenu
const ForgeTabScript = preload("res://ui/menus/tabs/forge_tab.gd")
const _SpellCatalog = preload("res://systems/magic/spell_catalog.gd")
const _CombatFormulaService = preload("res://systems/combat/combat_formula_service.gd")
const _WeaponStats = preload("res://data/schemas/weapon_stats.gd")

## Spine tab indices (7 tabs + Codex uses World / People / Items filters inside).
const TAB_VITALS := 0
const TAB_SKILLS := 1
const TAB_INVENTORY := 2
const TAB_MAGIC := 3
const TAB_FORGE := 4
const TAB_QUESTS := 5
const TAB_CODEX := 6

const _SLOT_COLS := 4
const _INV_SLOT_SIZE := Vector2(64, 74)
const _EQUIP_SLOT_SIZE := _INV_SLOT_SIZE
const _BASE_INV_SLOTS := 28

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
	"cape",
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

## High-contrast dark menu palette.
const _COL_INK := Color(0.97, 0.98, 1.0, 1.0)
const _COL_INK_MUTED := Color(0.95, 0.97, 1.0, 1.0)
const _COL_TITLE := Color(1.0, 1.0, 1.0, 1.0)

var _ui_tex: Dictionary = {}  ## String -> Texture2D
var _default_slot_icon: Texture2D = null

@onready var _backdrop: ColorRect = $Backdrop
@onready var _book: PanelContainer = $ScreenFill/Center/BookPanel
@onready var _header_title: Label = $ScreenFill/Center/BookPanel/InnerMargin/MainVBox/Header/Title
@onready var _header_hint: Label = $ScreenFill/Center/BookPanel/InnerMargin/MainVBox/Header/Hint
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

var _inv_base_grid: GridContainer
var _inv_backpack_grid: GridContainer
var _inv_backpack_section: PanelContainer
var _inv_backpack_locked_hint: Label
var _inv_slots: Array[Dictionary] = []  ## { "idx": int, "panel": Panel, "is_backpack": bool }
var _menu_hotbar_panels: Array[Panel] = []
var _menu_hotbar_labels: Array[Label] = []
var _equip_panels: Dictionary = {}  ## slot_id -> Panel

var _page_crafting_list: ItemList
var _page_crafting_detail: RichTextLabel
var _page_crafting_craft: Button
var _page_crafting_filter: OptionButton
var _craft_recipes: Array[RecipeData] = []
var _craft_selected: RecipeData = null
var _station_filter_idx: int = -1
var _forge_tabs: TabContainer
var _forge_tab = ForgeTabScript.new()

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
var _build_preview_rotation_y: float = 0.0
var _magic_spell_picker: OptionButton
var _magic_slot_picker: OptionButton
var _selected_build_item_id: String = "campfire_kit"
var _quests_body: RichTextLabel


func _ready() -> void:
	layer = 25
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_forge_tab.setup(self)
	if QuestService.has_signal("quest_updated"):
		QuestService.quest_updated.connect(_refresh_quests_page)
	_style_book_panel()
	_apply_header_style()
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


func _apply_header_style() -> void:
	if _backdrop != null:
		_backdrop.color = Color(0.0, 0.0, 0.0, 0.84)
	if _header_title != null:
		_header_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		_header_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.62))
	if _header_hint != null:
		_header_hint.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 0.96))


func _on_inventory_changed() -> void:
	if visible:
		_refresh_inv_grid()
		_refresh_equip_slots()
		_refresh_menu_hotbar()
		_refresh_tackle_panel()
		_refresh_skills_page()
		_refresh_magic_spell_picker()
		_forge_tab.on_inventory_changed()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var book_rect := _book.get_global_rect()
		if not book_rect.has_point(event.global_position):
			close_menu()


func toggle(default_tab: int = 0) -> void:
	if visible:
		close_menu()
	else:
		open_menu(clampi(default_tab, 0, _TAB_NAMES.size() - 1))


func open_menu(tab_idx: int = 0) -> void:
	var ga_open: Node = get_tree().root.get_node_or_null("GameAudio")
	if ga_open != null and ga_open.has_method("play_book_open"):
		ga_open.call("play_book_open")
	_was_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_set_tab_instant(clampi(tab_idx, 0, _TAB_NAMES.size() - 1))
	_play_open_anim()
	_refresh_inv_grid()
	_refresh_equip_slots()
	_refresh_menu_hotbar()
	_refresh_skills_page()
	_refresh_magic_spell_picker()
	_refresh_vitals_page()
	_forge_tab.refresh_on_open()
	if _current_tab == TAB_CODEX:
		_refresh_codex_list()


func open_forge_crafting_basic() -> void:
	open_menu(TAB_FORGE)
	_forge_tab.open_crafting_basic()


func open_forge_building() -> void:
	open_menu(TAB_FORGE)
	_forge_tab.open_building()
	_sync_build_preview()


func _set_forge_subtab(tab_idx: int) -> void:
	_forge_tab.set_subtab(tab_idx)


func _set_craft_station_filter(station_id: int) -> void:
	_forge_tab.set_station_filter(station_id)


func close_menu() -> void:
	var ga_close: Node = get_tree().root.get_node_or_null("GameAudio")
	if ga_close != null and ga_close.has_method("play_book_close"):
		ga_close.call("play_book_close")
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


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var hb_idx := _menu_hotbar_slot_from_mouse(event.global_position)
		if hb_idx >= 0:
			GameState.clear_hotbar_slot(hb_idx)
			_refresh_menu_hotbar()
			get_viewport().set_input_as_handled()
			return
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
				elif s != null and str(s.get("id", "")) != InventoryService.TACKLEBOX_ID:
					_toast("Can't store that in the tackle box.")
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseMotion and not _drag.is_empty():
		_drag_preview.global_position = event.global_position + Vector2(16, 16)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hb_left_idx := _menu_hotbar_slot_from_mouse(event.global_position)
			if hb_left_idx >= 0:
				if _begin_drag_hotbar(hb_left_idx):
					get_viewport().set_input_as_handled()
					return
			if event.double_click:
				var dbl_inv_idx := _inv_slot_from_mouse(event.global_position)
				if dbl_inv_idx >= 0 and _try_quick_equip_inventory_slot(dbl_inv_idx):
					get_viewport().set_input_as_handled()
					return
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
	flat.bg_color = Color(0.02, 0.03, 0.05, 0.97)
	flat.border_color = Color(0.38, 0.48, 0.62, 1.0)
	flat.set_border_width_all(4)
	flat.set_corner_radius_all(6)
	flat.set_content_margin_all(20)
	_book.add_theme_stylebox_override("panel", flat)


func _style_book_panel() -> void:
	_stylebook_flat_for_book()


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
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0.09, 0.09, 0.1, 0.94)
	flat.border_color = Color(0.34, 0.38, 0.46, 0.92)
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
	_style_tab_button_flat(b)


func _style_tab_button_flat(b: Button) -> void:
	var sb_on := StyleBoxFlat.new()
	sb_on.bg_color = Color(0.08, 0.1, 0.13, 0.98)
	sb_on.border_color = Color(0.9, 0.94, 1.0, 0.95)
	sb_on.set_border_width_all(2)
	sb_on.set_corner_radius_all(5)
	sb_on.set_content_margin_all(8)
	var sb_off := StyleBoxFlat.new()
	sb_off.bg_color = Color(0.03, 0.04, 0.06, 0.95)
	sb_off.border_color = Color(0.5, 0.56, 0.66, 0.85)
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
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.06, 0.08, 0.11, 0.95)
	sb_n.border_color = Color(0.58, 0.66, 0.78, 0.95)
	sb_n.set_border_width_all(2)
	sb_n.set_corner_radius_all(4)
	sb_n.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_n)
	var sb_p := sb_n.duplicate() as StyleBoxFlat
	sb_p.bg_color = Color(0.1, 0.13, 0.17, 1.0)
	sb_p.border_color = Color(0.96, 0.98, 1.0, 1.0)
	b.add_theme_stylebox_override("pressed", sb_p)
	b.add_theme_color_override("font_color", _COL_INK)
	b.add_theme_color_override("font_hover_color", _COL_INK)
	b.add_theme_color_override("font_pressed_color", _COL_INK)
	b.add_theme_color_override("font_focus_color", _COL_INK)
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
				_forge_tab.build_into(page)
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
	var eg := VBoxContainer.new()
	eg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	eg.add_theme_constant_override("separation", 8)
	left_inner.add_child(eg)
	_equip_panels.clear()
	var equip_rows: Array[Array] = [
		["", "head", ""],
		["ring_1", "neck", "ring_2"],
		["cape", "chest", "back"],
		["main_hand", "legs", "off_hand"],
	]
	for row in equip_rows:
		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 8)
		eg.add_child(row_box)
		for slot_id in row:
			var cell := VBoxContainer.new()
			cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			row_box.add_child(cell)
			if slot_id == "":
				var spacer := Control.new()
				spacer.custom_minimum_size = _EQUIP_SLOT_SIZE
				cell.add_child(spacer)
				continue
			var cap := Label.new()
			cap.text = _equip_label(slot_id)
			_apply_body_label(cap, 11)
			cap.add_theme_color_override("font_color", _COL_INK)
			cell.add_child(cap)
			var p := _make_slot_panel(_EQUIP_SLOT_SIZE)
			p.mouse_filter = Control.MOUSE_FILTER_STOP
			p.name = "Equip_%s" % slot_id
			cell.add_child(p)
			_equip_panels[slot_id] = p
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
	var inv_v := HBoxContainer.new()
	inv_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_v.add_theme_constant_override("separation", 10)
	right_inner.add_child(inv_v)
	_inv_base_grid = GridContainer.new()
	_inv_base_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_base_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_inv_base_grid.columns = _SLOT_COLS
	_inv_base_grid.add_theme_constant_override("h_separation", 6)
	_inv_base_grid.add_theme_constant_override("v_separation", 6)
	inv_v.add_child(_inv_base_grid)
	_inv_backpack_section = PanelContainer.new()
	_inv_backpack_section.custom_minimum_size = Vector2(270, 0)
	_inv_backpack_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_backpack_section.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_inner_card_style(_inv_backpack_section)
	inv_v.add_child(_inv_backpack_section)
	var backpack_inner := VBoxContainer.new()
	backpack_inner.add_theme_constant_override("separation", 6)
	_inv_backpack_section.add_child(backpack_inner)
	var backpack_title := Label.new()
	backpack_title.text = "Backpack"
	_apply_section_title(backpack_title)
	backpack_title.add_theme_font_size_override("font_size", 16)
	backpack_inner.add_child(backpack_title)
	_inv_backpack_locked_hint = Label.new()
	_inv_backpack_locked_hint.text = "Equip a backpack in the Back slot to unlock extra rows (14 with a small pack, 28 with a large one)."
	_inv_backpack_locked_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_body_label(_inv_backpack_locked_hint, 11)
	_inv_backpack_locked_hint.add_theme_color_override("font_color", _COL_INK_MUTED)
	backpack_inner.add_child(_inv_backpack_locked_hint)
	_inv_backpack_grid = GridContainer.new()
	_inv_backpack_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_backpack_grid.columns = _SLOT_COLS
	_inv_backpack_grid.add_theme_constant_override("h_separation", 6)
	_inv_backpack_grid.add_theme_constant_override("v_separation", 6)
	backpack_inner.add_child(_inv_backpack_grid)
	_build_inv_slots()
	_build_menu_hotbar(right_inner)
	var help := Label.new()
	help.text = "Drag between slots and equipment. Drag to hotbar below. Right-click tackle box. Right-click hotbar to clear."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_body_label(help, 11)
	help.add_theme_color_override("font_color", _COL_INK_MUTED)
	right_inner.add_child(help)


func _ensure_starter_items_if_empty() -> void:
	return


func _equip_label(slot_id: String) -> String:
	match slot_id:
		"head":
			return "Head"
		"neck":
			return "Amulet"
		"cape":
			return "Cape"
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
			return "Right Hand"
		"off_hand":
			return "Left Hand"
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
	for c in _inv_base_grid.get_children():
		c.queue_free()
	for c in _inv_backpack_grid.get_children():
		c.queue_free()
	_inv_slots.clear()
	for i in InventoryService.SLOT_COUNT:
		var slot := _make_slot_panel(_INV_SLOT_SIZE)
		slot.name = "InvSlot_%d" % i
		if i < _BASE_INV_SLOTS:
			_inv_base_grid.add_child(slot)
			_inv_slots.append({"idx": i, "panel": slot, "is_backpack": false})
		else:
			_inv_backpack_grid.add_child(slot)
			_inv_slots.append({"idx": i, "panel": slot, "is_backpack": true})


func _build_menu_hotbar(parent: VBoxContainer) -> void:
	_menu_hotbar_panels.clear()
	_menu_hotbar_labels.clear()
	var hotbar_box := VBoxContainer.new()
	hotbar_box.add_theme_constant_override("separation", 4)
	parent.add_child(hotbar_box)
	var title := Label.new()
	title.text = "Hotbar"
	_apply_body_label(title, 12)
	title.add_theme_color_override("font_color", _COL_INK_MUTED)
	hotbar_box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	hotbar_box.add_child(row)
	for i in 4:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(112, 48)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(slot)
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 1)
		slot.add_child(vb)
		var key := Label.new()
		key.text = "[%d]" % (i + 1)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_apply_body_label(key, 10)
		vb.add_child(key)
		var name_label := Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		_apply_body_label(name_label, 11)
		name_label.name = "HotbarName_%d" % i
		vb.add_child(name_label)
		_menu_hotbar_panels.append(slot)
		_menu_hotbar_labels.append(name_label)
	_refresh_menu_hotbar()


func _menu_hotbar_slot_from_mouse(global_pos: Vector2) -> int:
	if _current_tab != TAB_INVENTORY:
		return -1
	for i in _menu_hotbar_panels.size():
		if _menu_hotbar_panels[i].get_global_rect().has_point(global_pos):
			return i
	return -1


func _refresh_menu_hotbar() -> void:
	GameState.ensure_hotbar_arrays()
	for i in _menu_hotbar_panels.size():
		var spell_id := ""
		var item_id := ""
		if GameState.hotbar_spell_ids.size() > i:
			spell_id = str(GameState.hotbar_spell_ids[i])
		if GameState.hotbar_item_ids.size() > i:
			item_id = str(GameState.hotbar_item_ids[i])
		var filled := not spell_id.is_empty() or not item_id.is_empty()
		if i < _menu_hotbar_labels.size():
			var cap := "(empty)"
			if not spell_id.is_empty():
				cap = _SpellCatalog.get_display_name(spell_id)
			elif not item_id.is_empty():
				cap = _pretty_item_name(item_id)
			_menu_hotbar_labels[i].text = cap
		_apply_menu_hotbar_style(_menu_hotbar_panels[i], false, filled)


func _apply_menu_hotbar_style(panel: Panel, selected: bool, filled: bool) -> void:
	var sb := StyleBoxFlat.new()
	if selected:
		sb.bg_color = Color(0.14, 0.17, 0.22, 0.98)
		sb.border_color = Color(0.98, 0.93, 0.72, 1.0)
	elif filled:
		sb.bg_color = Color(0.08, 0.12, 0.17, 0.95)
		sb.border_color = Color(0.56, 0.73, 0.9, 1.0)
	else:
		sb.bg_color = Color(0.05, 0.08, 0.12, 0.85)
		sb.border_color = Color(0.38, 0.46, 0.58, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", sb)


func _refresh_backpack_visibility() -> void:
	if _inv_backpack_section == null:
		return
	var backpack_unlocked := InventoryService.has_backpack_equipped()
	_inv_backpack_section.visible = backpack_unlocked
	if _inv_backpack_grid != null:
		_inv_backpack_grid.visible = backpack_unlocked
	if _inv_backpack_locked_hint != null:
		_inv_backpack_locked_hint.visible = not backpack_unlocked


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
		"Press [b]B[/b] in the world for the modular home builder (walls, floors, roofs, stairs, and props from the medieval village kit).\n\n"
		+ "For placeable items such as [b]campfire kits[/b] and [b]torches[/b], open [b]C[/b] → Forge → Building tab."
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
	t.text = "Spell book"
	_apply_section_title(t)
	t.add_theme_font_size_override("font_size", 21)
	vb.add_child(t)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.add_theme_color_override("default_color", _COL_INK)
	body.text = (
		"Bind spells to hotbar slots [1]-[4]. Each slot can hold either a spell or a normal item (tools, gear).\n\n"
		+ "Spell book — [b]Push[/b] (Air · level 1): a gust of wind that shoves a creature back. No damage.\n"
		+ "Future spells may require multiple rune types in inventory; binding the spell keeps one hotbar slot."
	)
	vb.add_child(body)
	var picker_row := HBoxContainer.new()
	picker_row.add_theme_constant_override("separation", 8)
	vb.add_child(picker_row)
	_magic_spell_picker = OptionButton.new()
	_style_generic_journal_button(_magic_spell_picker)
	picker_row.add_child(_magic_spell_picker)
	_magic_slot_picker = OptionButton.new()
	for i in 4:
		_magic_slot_picker.add_item("Hotbar %d" % (i + 1), i)
	_magic_slot_picker.select(0)
	_style_generic_journal_button(_magic_slot_picker)
	picker_row.add_child(_magic_slot_picker)
	var bind_btn := Button.new()
	bind_btn.text = "Bind spell"
	bind_btn.pressed.connect(_on_magic_bind_pressed)
	_style_generic_journal_button(bind_btn)
	picker_row.add_child(bind_btn)
	var grant_btn := Button.new()
	grant_btn.text = "Grant Spark Rune"
	grant_btn.pressed.connect(_on_magic_grant_pressed)
	_style_generic_journal_button(grant_btn)
	picker_row.add_child(grant_btn)
	var foot := Label.new()
	foot.text = "Use hotbar keys [1]-[4] to cast bound spells or use items."
	_apply_body_label(foot, 12)
	foot.add_theme_color_override("font_color", _COL_INK_MUTED)
	vb.add_child(foot)
	_refresh_magic_spell_picker()


func _build_forge_page(page: Control) -> void:
	var tabs := TabContainer.new()
	tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	tabs.tab_alignment = TabBar.ALIGNMENT_CENTER
	_forge_tabs = tabs
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
	_quests_body = RichTextLabel.new()
	_quests_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quests_body.bbcode_enabled = true
	_quests_body.scroll_active = true
	_quests_body.add_theme_color_override("default_color", _COL_INK)
	vb.add_child(_quests_body)
	_refresh_quests_page()


func _refresh_quests_page() -> void:
	if _quests_body == null:
		return
	var parts: PackedStringArray = PackedStringArray()
	if QuestService.is_quest_completed(QuestService.WOODSMAN_TRIAL_ID):
		parts.append("[b]Completed[/b]")
		parts.append("The Woodsman's Trial")
	if QuestService.is_quest_active(QuestService.WOODSMAN_TRIAL_ID):
		parts.append("[b]Active[/b]")
		for line in QuestService.get_journal_lines():
			parts.append(line)
	elif parts.is_empty():
		parts.append("No sworn oaths logged yet.")
		parts.append("Seek out folk who need a hand—the journal will record your tasks here.")
	_quests_body.text = "\n\n".join(parts)


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
	if new_idx == TAB_QUESTS:
		_refresh_quests_page()
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
	var ga_flip: Node = get_tree().root.get_node_or_null("GameAudio")
	if ga_flip != null and ga_flip.has_method("play_book_page_flip"):
		ga_flip.call("play_book_page_flip")
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
	_refresh_backpack_visibility()
	var unlocked_n := InventoryService.get_unlocked_slot_count()
	for entry in _inv_slots:
		var idx := int(entry.get("idx", -1))
		var slot: Panel = entry.get("panel", null) as Panel
		if slot == null or idx < 0:
			continue
		var icon_tex: TextureRect = slot.find_child("IconTexture", true, false)
		var icon_fb: Label = slot.find_child("IconFallback", true, false)
		var name_l: Label = slot.find_child("NameLabel", true, false)
		var count_l: Label = slot.find_child("CountLabel", true, false)
		var s: Variant = InventoryService.get_slot_data(idx)
		if s != null:
			var item_id: String = str(s.get("id", ""))
			_apply_icon_to_texture_rect(icon_tex, icon_fb, item_id)
			name_l.text = _pretty_item_name(item_id)
			var count := int(s.get("count", 0))
			count_l.text = str(count) if count > 1 else ""
			_apply_slot_style(slot, true, "")
		else:
			icon_tex.texture = null
			icon_fb.visible = false
			name_l.text = ""
			count_l.text = ""
			_apply_slot_style(slot, false, "")
		slot.modulate = Color.WHITE if idx < unlocked_n else Color(0.5, 0.52, 0.56, 0.82)


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
			var count := int(s.get("count", 1))
			count_l.text = str(count) if count > 1 else ""
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
	if not String(r.skill_id).is_empty() and int(r.required_skill_level) > 0:
		var skill_key := "%s_level" % String(r.skill_id)
		var have_level := 0
		if skill_key in GameState:
			have_level = int(GameState.get(skill_key))
		var meets_skill := have_level >= int(r.required_skill_level)
		var skill_mark := "[+] " if meets_skill else "[-] "
		lines.append(
			"%sSkill: %s Lv %d (%d / %d)\n"
			% [
				skill_mark,
				String(r.skill_id).capitalize(),
				int(r.required_skill_level),
				have_level,
				int(r.required_skill_level),
			]
		)
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
	for entry in _inv_slots:
		var idx := int(entry.get("idx", -1))
		var slot: Panel = entry.get("panel", null) as Panel
		if slot == null or idx < 0:
			continue
		if not slot.is_visible_in_tree():
			continue
		if slot.get_global_rect().has_point(global_pos):
			return idx
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
	var to_hb := _menu_hotbar_slot_from_mouse(global_pos)
	if _drag["k"] == "inv":
		var from_i: int = int(_drag["i"])
		if to_inv >= 0:
			InventoryService.move_or_merge(from_i, to_inv)
		elif to_eq != "":
			_try_drop_inv_on_equip(from_i, to_eq)
		else:
			if not _try_drop_inv_on_hotbar(from_i, global_pos):
				_drop_dragged_to_world(global_pos)
	elif _drag["k"] == "hb" or _drag["k"] == "hbs":
		var from_hb: int = int(_drag["i"])
		if to_hb >= 0 and to_hb != from_hb:
			GameState.ensure_hotbar_arrays()
			var a := str(GameState.hotbar_item_ids[from_hb])
			var b := str(GameState.hotbar_item_ids[to_hb])
			var sa := str(GameState.hotbar_spell_ids[from_hb])
			var sb := str(GameState.hotbar_spell_ids[to_hb])
			GameState.hotbar_item_ids[from_hb] = b
			GameState.hotbar_item_ids[to_hb] = a
			GameState.hotbar_spell_ids[from_hb] = sb
			GameState.hotbar_spell_ids[to_hb] = sa
		_refresh_menu_hotbar()
	elif _drag["k"] == "eq":
		var from_s: String = str(_drag["s"])
		if to_inv >= 0:
			_try_drop_equip_on_inv(from_s, to_inv)
		elif to_eq != "" and to_eq != from_s:
			_try_swap_equip_slots(from_s, to_eq)
		else:
			_drop_equipped_to_world(global_pos, from_s)
	_cancel_drag()


func _begin_drag_hotbar(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= 4:
		return false
	GameState.ensure_hotbar_arrays()
	var item_id := str(GameState.hotbar_item_ids[slot_idx])
	var spell_id := str(GameState.hotbar_spell_ids[slot_idx])
	if not item_id.is_empty():
		_drag = {"k": "hb", "i": slot_idx}
		_show_drag_preview(item_id, 1)
		return true
	if not spell_id.is_empty():
		_drag = {"k": "hbs", "i": slot_idx}
		_show_drag_preview_spell(spell_id)
		return true
	return false


func _show_drag_preview_spell(spell_id: String) -> void:
	_apply_icon_to_texture_rect(_drag_icon, _drag_fallback, "")
	_drag_name.text = _SpellCatalog.get_display_name(spell_id)
	_drag_fallback.text = "◇"
	_drag_count.text = "1"
	_drag_preview.visible = true
	var mp := get_viewport().get_mouse_position()
	_drag_preview.global_position = mp + Vector2(16, 16)


func _try_drop_inv_on_hotbar(from_i: int, global_pos: Vector2) -> bool:
	var menu_slot_idx := _menu_hotbar_slot_from_mouse(global_pos)
	if menu_slot_idx >= 0:
		var s: Variant = InventoryService.get_slot_data(from_i)
		if s == null:
			return false
		var item_id := str(s.get("id", ""))
		if item_id.is_empty():
			return false
		GameState.ensure_hotbar_arrays()
		GameState.hotbar_item_ids[menu_slot_idx] = item_id
		GameState.hotbar_spell_ids[menu_slot_idx] = ""
		_refresh_menu_hotbar()
		return true
	var p := get_parent()
	if p == null:
		return false
	var hud := p.get_node_or_null("PlayerHud")
	if hud == null or not hud.has_method("hotbar_slot_from_global"):
		return false
	var slot_idx: int = int(hud.call("hotbar_slot_from_global", global_pos))
	if slot_idx < 0:
		return false
	if not hud.has_method("assign_hotbar_from_inventory"):
		return false
	return bool(hud.call("assign_hotbar_from_inventory", slot_idx, from_i))


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
	var drop_pos: Vector3 = InventoryService.compute_drop_position(player, cam, global_pos)
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
	var drop_pos: Vector3 = InventoryService.compute_drop_position(player, cam, global_pos)
	var id := str(s.get("id", ""))
	var count := int(s.get("count", 1))
	GameState.clear_equipment_slot(equip_slot)
	var scene: PackedScene = InventoryService.get_pickup_scene_for_item(id)
	if scene == null:
		_toast("Cannot drop that item.")
		GameState.set_equipment_slot(equip_slot, id, count)
		_refresh_equip_slots()
		return
	var node := scene.instantiate()
	if node == null:
		GameState.set_equipment_slot(equip_slot, id, count)
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
		# Always unequip the current item first, then equip the new one.
		# This keeps slot behavior consistent for armor/clothing replacements.
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
		GameState.set_equipment_slot(a, str(eb.get("id", "")), int(eb.get("count", 1)))
		GameState.clear_equipment_slot(b)
	elif eb == null:
		GameState.set_equipment_slot(b, str(ea.get("id", "")), int(ea.get("count", 1)))
		GameState.clear_equipment_slot(a)
	else:
		GameState.set_equipment_slot(a, str(eb.get("id", "")), int(eb.get("count", 1)))
		GameState.set_equipment_slot(b, str(ea.get("id", "")), int(ea.get("count", 1)))
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
	GameState.set_equipment_slot(equip_slot, new_id, 1)
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
	# Place replaced item back into source slot so swapping works even when inventory is full.
	InventoryService.set_slot_data(
		inv_idx, {"id": str(old.get("id", "")), "count": int(old.get("count", 1))}
	)
	GameState.set_equipment_slot(equip_slot, new_id, 1)
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
	GameState.clear_equipment_slot(equip_slot)
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
	GameState.set_equipment_slot(equip_slot, str(inv_d.get("id", "")), int(inv_d.get("count", 1)))
	return true


func _is_bow_weapon_item(it: ItemData) -> bool:
	if it == null:
		return false
	var item_id := GameState.normalize_item_id(str(it.id))
	return (
		_CombatFormulaService.equipped_weapon_family(item_id)
		== _WeaponStats.WeaponFamily.BOW
	)


func _equip_accepts(equip_slot: String, it: ItemData) -> bool:
	if it == null:
		return false
	var item_id := str(it.id).to_lower()
	if InventoryService.item_is_tackle_contents_only(item_id):
		return false
	match equip_slot:
		"main_hand":
			if _is_bow_weapon_item(it):
				return false
			return it.category in [ItemData.Category.TOOL, ItemData.Category.WEAPON]
		"off_hand":
			if _is_shield_item(it):
				return true
			if _is_back_relic_item_id(item_id):
				return false
			return it.category in [
				ItemData.Category.TOOL,
				ItemData.Category.WEAPON,
				ItemData.Category.RELIC,
			]
		"head", "chest", "legs", "feet", "hands", "back":
			if equip_slot == "back" and _is_back_relic_item_id(item_id):
				return true
			return it.category in [ItemData.Category.ARMOR, ItemData.Category.CLOTHING]
		"cape":
			if item_id.begins_with("cape_"):
				return true
			return it.category in [ItemData.Category.CLOTHING, ItemData.Category.ARMOR]
		"neck", "ring_1", "ring_2":
			return it.category == ItemData.Category.JEWERLY
		_:
			return false


func _try_quick_equip_inventory_slot(inv_idx: int) -> bool:
	var inv_s: Variant = InventoryService.get_slot_data(inv_idx)
	if inv_s == null:
		return false
	var item_id := str(inv_s.get("id", ""))
	if item_id.is_empty():
		return false
	var it := ItemCatalog.get_item(item_id)
	if it == null:
		_toast("Cannot equip that item.")
		return false
	var target_slot := _preferred_equip_slot_for_item(it, item_id)
	if target_slot.is_empty():
		_toast("That item has no equipment slot.")
		return false
	_try_drop_inv_on_equip(inv_idx, target_slot)
	if item_id == "campfire_kit" or item_id == "tool_torch":
		_start_player_placeable_build(item_id)
	return true


func _start_player_placeable_build(item_id: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("begin_build_placement"):
		return
	if visible:
		close_menu()
	player.call("begin_build_placement", item_id, 0.0)


func _preferred_equip_slot_for_item(it: ItemData, item_id: String) -> String:
	var id := item_id.to_lower()
	if InventoryService.item_is_tackle_contents_only(id):
		return ""
	if _is_shield_item(it):
		return "off_hand"
	if it is ArmorData:
		var ad := it as ArmorData
		if ad.armor_stats != null:
			match ad.armor_stats.slot:
				ArmorStats.ArmorSlot.HEAD:
					return "head"
				ArmorStats.ArmorSlot.CHEST:
					return "chest"
				ArmorStats.ArmorSlot.LEGS:
					return "legs"
				ArmorStats.ArmorSlot.HANDS:
					return "hands"
				ArmorStats.ArmorSlot.FEET:
					return "feet"
				ArmorStats.ArmorSlot.SHIELD:
					return "off_hand"
	match it.category:
		ItemData.Category.WEAPON:
			if _is_bow_weapon_item(it):
				return "off_hand"
			return "main_hand"
		ItemData.Category.TOOL:
			if id == "tool_torch" or id == "tool_chisel" or id == "tool_tacklebox":
				return "off_hand"
			return "main_hand"
		ItemData.Category.ARMOR, ItemData.Category.CLOTHING:
			if id.begins_with("cape_"):
				return "cape"
			if id.begins_with("backpack_") or id.find("backpack") >= 0:
				return "back"
			if id.begins_with("armor_head_"):
				return "head"
			if id.begins_with("armor_chest_"):
				return "chest"
			if id.begins_with("armor_legs_"):
				return "legs"
			if id.begins_with("armor_hands_"):
				return "hands"
			if id.begins_with("armor_feet_"):
				return "feet"
			if id.begins_with("quiver_") or id.begins_with("backpack_"):
				return "back"
		ItemData.Category.JEWERLY:
			if id.find("amulet") >= 0 or id.begins_with("neck_") or id.begins_with("jewelry_neck_"):
				return "neck"
			if id.find("ring") >= 0:
				if GameState.equipment.get("ring_1", null) == null:
					return "ring_1"
				if GameState.equipment.get("ring_2", null) == null:
					return "ring_2"
				return "ring_1"
			if GameState.equipment.get("ring_1", null) == null:
				return "ring_1"
			if GameState.equipment.get("ring_2", null) == null:
				return "ring_2"
			return "ring_1"
		ItemData.Category.RELIC:
			if _is_back_relic_item_id(id):
				return "back"
			return "off_hand"
		_:
			return ""
	return ""


func _is_back_relic_item_id(item_id: String) -> bool:
	return item_id.begins_with("quiver_") or item_id.begins_with("backpack_")


func _is_shield_item(it: ItemData) -> bool:
	if it == null:
		return false
	if str(it.id).begins_with("shield_"):
		return true
	if it is ArmorData:
		var ad := it as ArmorData
		if ad.armor_stats != null and ad.armor_stats.slot == ArmorStats.ArmorSlot.SHIELD:
			return true
	return false


func _toast(msg: String) -> void:
	var p: Node = get_parent()
	if p != null and p.has_method("show_gameplay_message"):
		p.call("show_gameplay_message", msg)


func _refresh_magic_spell_picker() -> void:
	if _magic_spell_picker == null:
		return
	var prev_id := ""
	if _magic_spell_picker.item_count > 0 and _magic_spell_picker.selected >= 0:
		prev_id = str(_magic_spell_picker.get_item_metadata(_magic_spell_picker.selected))
	_magic_spell_picker.clear()
	for spell_id in _SpellCatalog.get_known_spell_ids():
		var sid := str(spell_id)
		if sid.is_empty():
			continue
		_magic_spell_picker.add_item(_SpellCatalog.get_display_name(sid))
		var idx := _magic_spell_picker.item_count - 1
		_magic_spell_picker.set_item_metadata(idx, sid)
	_magic_spell_picker.add_separator()
	_magic_spell_picker.add_item("(none)")
	var none_idx := _magic_spell_picker.item_count - 1
	_magic_spell_picker.set_item_metadata(none_idx, "")
	var selected_idx := none_idx
	if not prev_id.is_empty():
		for i in _magic_spell_picker.item_count:
			if str(_magic_spell_picker.get_item_metadata(i)) == prev_id:
				selected_idx = i
				break
	_magic_spell_picker.select(selected_idx)


func _on_magic_bind_pressed() -> void:
	if _magic_spell_picker == null or _magic_slot_picker == null:
		return
	if _magic_slot_picker.item_count < 1:
		return
	var slot_idx := int(_magic_slot_picker.get_item_id(_magic_slot_picker.selected))
	if slot_idx < 0 or slot_idx >= 4:
		return
	var spell_id := str(_magic_spell_picker.get_item_metadata(_magic_spell_picker.selected))
	GameState.ensure_hotbar_arrays()
	GameState.hotbar_spell_ids[slot_idx] = spell_id
	if not spell_id.is_empty():
		GameState.hotbar_item_ids[slot_idx] = ""
	if spell_id.is_empty():
		_toast("Cleared spell from hotbar slot %d." % (slot_idx + 1))
	else:
		_toast(
			"Bound %s to hotbar %d."
			% [_SpellCatalog.get_display_name(spell_id), slot_idx + 1]
		)


func _on_magic_grant_pressed() -> void:
	var left := InventoryService.add_item("rune_air", 1)
	if left > 0:
		_toast("Inventory full.")
		return
	_refresh_magic_spell_picker()
	_toast("Spark Rune added.")


func _adjust_build_rotation(delta_deg: float) -> void:
	_build_preview_rotation_y = wrapf(
		_build_preview_rotation_y + deg_to_rad(delta_deg),
		-PI,
		PI
	)
	_toast("Build rotation: %d deg" % int(round(rad_to_deg(_build_preview_rotation_y))))
	_sync_build_preview()


func _set_build_rotation_from_player(rotation_y: float) -> void:
	_build_preview_rotation_y = rotation_y


func _place_build_item_from_forge(item_id: String) -> bool:
	_selected_build_item_id = GameState.normalize_item_id(item_id)
	_sync_build_preview()
	var p: Node = get_parent()
	if p == null or not p.has_method("try_place_build_item"):
		return false
	var ok := bool(p.call("try_place_build_item", _selected_build_item_id, _build_preview_rotation_y))
	if ok:
		_sync_build_preview()
	return ok


func _select_build_item_from_forge(item_id: String) -> void:
	_selected_build_item_id = GameState.normalize_item_id(item_id)
	_sync_build_preview()


func _begin_build_placement_from_forge(item_id: String) -> void:
	_selected_build_item_id = GameState.normalize_item_id(item_id)
	var p: Node = get_parent()
	if p != null and p.has_method("begin_build_placement"):
		p.call("begin_build_placement", _selected_build_item_id, _build_preview_rotation_y)
	close_menu()


func _sync_build_preview() -> void:
	var p: Node = get_parent()
	if p == null:
		return
	if p.has_method("set_build_preview_rotation"):
		p.call("set_build_preview_rotation", _build_preview_rotation_y)
	if p.has_method("set_build_preview_item"):
		p.call("set_build_preview_item", _selected_build_item_id)


func _clear_build_preview() -> void:
	var p: Node = get_parent()
	if p != null and p.has_method("clear_build_preview"):
		p.call("clear_build_preview")


func _apply_icon_to_texture_rect(tex_rect: TextureRect, fallback: Label, item_id: String) -> void:
	var tex: Texture2D = ItemCatalog.get_item_icon(item_id)
	if tex == null:
		tex = _get_default_slot_icon()
	if tex != null:
		tex_rect.texture = tex
		tex_rect.visible = true
		fallback.visible = false
	else:
		tex_rect.texture = null
		tex_rect.visible = false
		fallback.visible = true
		fallback.text = _item_icon_abbrev(item_id)


func _get_default_slot_icon() -> Texture2D:
	if _default_slot_icon != null:
		return _default_slot_icon
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.12, 0.16, 0.22, 1.0))
	for y in range(32):
		for x in range(32):
			if x <= 1 or x >= 30 or y <= 1 or y >= 30:
				img.set_pixel(x, y, Color(0.66, 0.76, 0.9, 1.0))
	for i in range(6, 27):
		img.set_pixel(i, i, Color(0.84, 0.9, 0.98, 0.68))
		img.set_pixel(31 - i, i, Color(0.84, 0.9, 0.98, 0.68))
	_default_slot_icon = ImageTexture.create_from_image(img)
	return _default_slot_icon


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
		"oak_logs", "logs_oak":
			return "OK"
		"stone":
			return "ST"
		"tin_ore", "ore_tin":
			return "Sn"
		"ore_copper":
			return "Cu"
		_:
			return "??"


func _equip_slot_bg_path(slot_id: String) -> String:
	if slot_id.is_empty():
		return _SLOT_INV_EMPTY
	return _SLOT_EQUIP


func _apply_slot_style(slot: Panel, filled: bool, equip_slot_id: String = "") -> void:
	slot.modulate = Color.WHITE
	var sb2 := StyleBoxFlat.new()
	var equip_slot := not equip_slot_id.is_empty()
	if filled and equip_slot:
		sb2.bg_color = Color(0.07, 0.11, 0.15, 0.9)
		sb2.border_color = Color(0.95, 0.82, 0.52, 1.0)
	elif filled:
		sb2.bg_color = Color(0.07, 0.11, 0.15, 0.9)
		sb2.border_color = Color(0.36, 0.78, 1.0, 1.0)
	elif equip_slot:
		sb2.bg_color = Color(0.04, 0.06, 0.1, 0.75)
		sb2.border_color = Color(0.55, 0.62, 0.72, 0.88)
	else:
		sb2.bg_color = Color(0.04, 0.06, 0.1, 0.75)
		sb2.border_color = Color(0.44, 0.54, 0.66, 0.86)
	sb2.set_border_width_all(3)
	sb2.set_corner_radius_all(4)
	sb2.content_margin_left = 4
	sb2.content_margin_top = 4
	sb2.content_margin_right = 4
	sb2.content_margin_bottom = 4
	slot.add_theme_stylebox_override("panel", sb2)


func _ensure_tackle_window() -> void:
	if _tackle_window != null:
		if (
			_tackle_hook_labels.size() == InventoryService.TACKLE_HOOKS
			and _tackle_bobber_labels.size() == InventoryService.TACKLE_BOBBERS
			and _tackle_bait_labels.size() == InventoryService.TACKLE_BAIT
		):
			return
		_tackle_window.queue_free()
		_tackle_window = null
		_tackle_hook_labels.clear()
		_tackle_bobber_labels.clear()
		_tackle_bait_labels.clear()
	_tackle_window = Window.new()
	_tackle_window.title = "Tackle box"
	_tackle_window.size = Vector2i(400, 620)
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
	help.text = "Drag supplies into these slots, right-click from inventory, or pick up spares on the beach."
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
	var margin := 14
	var sz: Vector2i = _tackle_window.size
	var br := _book.get_global_rect()
	_tackle_window.popup(
		Rect2i(
			int(br.position.x + br.size.x - float(sz.x) - margin),
			int(br.position.y + margin),
			sz.x,
			sz.y
		)
	)


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
