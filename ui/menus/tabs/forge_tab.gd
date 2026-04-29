extends RefCounted
class_name ForgeTab

const SUBTAB_CRAFTING := 0
const SUBTAB_BUILDING := 1

const _COL_INK := Color(0.82, 0.9, 0.95, 1.0)
const _COL_INK_MUTED := Color(0.55, 0.64, 0.72, 1.0)
const _COL_TITLE := Color(0.98, 0.86, 0.48, 1.0)

var _menu: Node
var _forge_tabs: TabContainer
var _page_crafting_list: ItemList
var _page_crafting_detail: RichTextLabel
var _page_crafting_craft: Button
var _page_crafting_filter: OptionButton
var _craft_selected: RecipeData = null
var _station_filter_idx: int = -1
var _build_rotate_step: float = 30.0
var _build_selected_item_id: String = "campfire_kit"
var _build_selected_label: Label


func setup(menu: Node) -> void:
	_menu = menu


func build_into(page: Control) -> void:
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


func refresh_on_open() -> void:
	_refresh_crafting_list()
	_refresh_crafting_detail()


func on_inventory_changed() -> void:
	_refresh_crafting_detail()


func open_crafting_basic() -> void:
	_set_subtab(SUBTAB_CRAFTING)
	set_station_filter(RecipeData.CraftStation.NONE)
	_refresh_crafting_detail()


func open_building() -> void:
	_set_subtab(SUBTAB_BUILDING)
	_select_build_item(_build_selected_item_id)


func set_subtab(tab_idx: int) -> void:
	_set_subtab(tab_idx)


func set_station_filter(station_id: int) -> void:
	if _page_crafting_filter == null:
		return
	for i in _page_crafting_filter.item_count:
		if int(_page_crafting_filter.get_item_id(i)) == station_id:
			_page_crafting_filter.select(i)
			_on_craft_filter_selected(i)
			return
	if _page_crafting_filter.item_count > 0:
		_page_crafting_filter.select(0)
		_on_craft_filter_selected(0)


func _set_subtab(tab_idx: int) -> void:
	if _forge_tabs == null:
		return
	_forge_tabs.current_tab = clampi(tab_idx, 0, _forge_tabs.get_tab_count() - 1)


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
	body.bbcode_enabled = true
	body.fit_content = true
	body.add_theme_color_override("default_color", _COL_INK)
	body.text = (
		"Place selected utility props in front of the player.\n\n"
		+ "Controls:\n"
		+ "- Rotate Left / Right to set yaw\n"
		+ "- Select an item, then Place Selected\n"
		+ "- Preview turns green when valid, red when blocked"
	)
	vb.add_child(body)
	_build_selected_label = Label.new()
	_apply_body_label(_build_selected_label, 13)
	_build_selected_label.add_theme_color_override("font_color", _COL_INK)
	vb.add_child(_build_selected_label)

	var rot_row := HBoxContainer.new()
	rot_row.add_theme_constant_override("separation", 8)
	vb.add_child(rot_row)
	var rot_l := Button.new()
	rot_l.text = "Rotate Left"
	rot_l.pressed.connect(func() -> void: _adjust_build_rotation(-_build_rotate_step))
	_style_generic_journal_button(rot_l)
	rot_row.add_child(rot_l)
	var rot_r := Button.new()
	rot_r.text = "Rotate Right"
	rot_r.pressed.connect(func() -> void: _adjust_build_rotation(_build_rotate_step))
	_style_generic_journal_button(rot_r)
	rot_row.add_child(rot_r)

	var place_row := HBoxContainer.new()
	place_row.add_theme_constant_override("separation", 8)
	vb.add_child(place_row)
	var pick_camp := Button.new()
	pick_camp.text = "Select Campfire Kit"
	pick_camp.pressed.connect(func() -> void: _select_build_item("campfire_kit"))
	_style_generic_journal_button(pick_camp)
	place_row.add_child(pick_camp)
	var pick_torch := Button.new()
	pick_torch.text = "Select Torch"
	pick_torch.pressed.connect(func() -> void: _select_build_item("tool_torch"))
	_style_generic_journal_button(pick_torch)
	place_row.add_child(pick_torch)
	var place_sel := Button.new()
	place_sel.text = "Place Selected"
	place_sel.pressed.connect(_place_selected_build_item)
	_style_generic_journal_button(place_sel)
	place_row.add_child(place_sel)
	_select_build_item(_build_selected_item_id)


func _select_build_item(item_id: String) -> void:
	_build_selected_item_id = item_id
	if _build_selected_label != null:
		_build_selected_label.text = "Selected: %s" % _pretty_item_name(item_id)
	if _menu != null and _menu.has_method("_select_build_item_from_forge"):
		_menu.call("_select_build_item_from_forge", item_id)


func _place_selected_build_item() -> void:
	_place_build_item(_build_selected_item_id)


func _build_page_unused_keep() -> void:
	# Keeps patch context stable for generated UI sections.
	pass


func _on_craft_filter_selected(idx: int) -> void:
	var id := int(_page_crafting_filter.get_item_id(idx))
	_station_filter_idx = id
	_refresh_crafting_list()


func _refresh_crafting_list() -> void:
	if _page_crafting_list == null:
		return
	_page_crafting_list.clear()
	var all_r: Array[RecipeData] = RecipeCatalog.get_all_recipes()
	for r in all_r:
		if not _recipe_passes_filter(r):
			continue
		var label := r.display_name if r.display_name != "" else r.id
		_page_crafting_list.add_item(label)
		var li := _page_crafting_list.item_count - 1
		_page_crafting_list.set_item_metadata(li, r.id)
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
			lines.append("%s%s x%d (%d / %d)\n" % [mark, _pretty_item_name(ing.item_id), ing.count, have, ing.count])
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
	lines.append("\n[b]Output:[/b] %s x%d\n" % [_pretty_item_name(r.output_item_id), r.output_count])
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
		_refresh_inventory_ui()
	else:
		_toast("Cannot craft that right now.")


func _apply_inner_card_style(card: PanelContainer) -> void:
	if _menu != null and _menu.has_method("_apply_inner_card_style"):
		_menu.call("_apply_inner_card_style", card)


func _apply_section_title(lbl: Label) -> void:
	if _menu != null and _menu.has_method("_apply_section_title"):
		_menu.call("_apply_section_title", lbl)


func _apply_body_label(lbl: Label, size: int) -> void:
	if _menu != null and _menu.has_method("_apply_body_label"):
		_menu.call("_apply_body_label", lbl, size)


func _style_generic_journal_button(ctrl: Control) -> void:
	if _menu != null and _menu.has_method("_style_generic_journal_button"):
		_menu.call("_style_generic_journal_button", ctrl)


func _style_item_list_transparent(list: ItemList) -> void:
	if _menu != null and _menu.has_method("_style_item_list_transparent"):
		_menu.call("_style_item_list_transparent", list)


func _pretty_item_name(item_id: String) -> String:
	if _menu != null and _menu.has_method("_pretty_item_name"):
		return str(_menu.call("_pretty_item_name", item_id))
	return item_id


func _toast(msg: String) -> void:
	if _menu != null and _menu.has_method("_toast"):
		_menu.call("_toast", msg)


func _refresh_inventory_ui() -> void:
	if _menu != null:
		if _menu.has_method("_refresh_inv_grid"):
			_menu.call("_refresh_inv_grid")
		if _menu.has_method("_refresh_equip_slots"):
			_menu.call("_refresh_equip_slots")


func _adjust_build_rotation(delta_deg: float) -> void:
	if _menu == null or not _menu.has_method("_adjust_build_rotation"):
		return
	_menu.call("_adjust_build_rotation", delta_deg)


func _place_build_item(item_id: String) -> void:
	if _menu == null or not _menu.has_method("_place_build_item_from_forge"):
		return
	var ok := bool(_menu.call("_place_build_item_from_forge", item_id))
	if ok:
		_toast("Placed: %s" % _pretty_item_name(item_id))
	else:
		_toast("Cannot place %s right now." % _pretty_item_name(item_id))
