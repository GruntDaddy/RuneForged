extends CanvasLayer

const _BaseCharacter = preload("res://entities/characters/base_character/base_character.gd")

@onready var _panel: PanelContainer = $Root/Center/Margin/Panel
@onready var _name_val: Label = $Root/Center/Margin/Panel/VBox/NameRow/Value
@onready var _wood_val: Label = $Root/Center/Margin/Panel/VBox/SkillsGrid/WoodVal
@onready var _mine_val: Label = $Root/Center/Margin/Panel/VBox/SkillsGrid/MineVal
@onready var _tool_val: Label = $Root/Center/Margin/Panel/VBox/EquipGrid/ToolVal
@onready var _head_val: Label = $Root/Center/Margin/Panel/VBox/EquipGrid/HeadVal
@onready var _chest_val: Label = $Root/Center/Margin/Panel/VBox/EquipGrid/ChestVal
@onready var _legs_val: Label = $Root/Center/Margin/Panel/VBox/EquipGrid/LegsVal
@onready var _help: Label = $Root/Center/Margin/Panel/VBox/Help

var _was_mouse_captured: bool = false


func _ready() -> void:
	layer = 18
	visible = false
	_style_panel()
	var inv: Node = get_node_or_null("/root/InventoryService")
	if inv != null and inv.has_signal("inventory_changed"):
		inv.inventory_changed.connect(_on_inv_changed)


func _on_inv_changed() -> void:
	if visible:
		_refresh()


func toggle_sheet() -> void:
	visible = not visible
	if visible:
		_was_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh()
	else:
		if _was_mouse_captured:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _style_panel() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.055, 0.96)
	sb.border_color = Color(0.62, 0.52, 0.32, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 18
	sb.content_margin_top = 16
	sb.content_margin_right = 18
	sb.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", sb)


func _refresh() -> void:
	var p: Node = get_parent()
	_name_val.text = GameState.player_name if GameState.player_name != "" else "—"
	_wood_val.text = str(GameState.woodcutting_level)
	_mine_val.text = str(GameState.mining_level)

	if p != null and p.has_method("get_equipment_sheet_snapshot"):
		var e: Dictionary = p.get_equipment_sheet_snapshot()
		_tool_val.text = str(e.get("active_tool", "—"))
		_head_val.text = str(e.get("head", "—"))
		_chest_val.text = str(e.get("chest", "—"))
		_legs_val.text = str(e.get("legs", "—"))
	else:
		_tool_val.text = "—"
		_head_val.text = "—"
		_chest_val.text = "—"
		_legs_val.text = "—"

	_help.text = "Equipment slots are placeholders until armor items are saved on the character."
