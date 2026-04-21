extends CanvasLayer

const _BaseCharacter = preload("res://entities/characters/base_character/base_character.gd")

@onready var _health_bar: ProgressBar = $Root/TopLeft/Margin/VBox/HealthRow/ProgressBar
@onready var _stamina_bar: ProgressBar = $Root/TopLeft/Margin/VBox/StaminaRow/ProgressBar
@onready var _health_val: Label = $Root/TopLeft/Margin/VBox/HealthRow/ValueLabel
@onready var _stamina_val: Label = $Root/TopLeft/Margin/VBox/StaminaRow/ValueLabel

var _hotbar_panels: Array[Panel] = []
var _hotbar_labels: Array[Label] = []

const _HOT_TOOLS: Array[int] = [
	int(_BaseCharacter.ToolKind.AXE),
	int(_BaseCharacter.ToolKind.PICKAXE),
	int(_BaseCharacter.ToolKind.FISHING_ROD),
	int(_BaseCharacter.ToolKind.NONE),
]


func _ready() -> void:
	layer = 5
	$Root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for path in ["Slot0", "Slot1", "Slot2", "Slot3"]:
		var p: Panel = $Root/Hotbar/Margin/HBox.get_node(path) as Panel
		_hotbar_panels.append(p)
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
		var active: bool = tool_i == _HOT_TOOLS[i]
		_apply_hotbar_style(_hotbar_panels[i], active)
		_hotbar_labels[i].text = _hot_tool_caption(_HOT_TOOLS[i])


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


func _hot_tool_caption(kind: int) -> String:
	match kind:
		int(_BaseCharacter.ToolKind.AXE):
			return "Axe"
		int(_BaseCharacter.ToolKind.PICKAXE):
			return "Pick"
		int(_BaseCharacter.ToolKind.FISHING_ROD):
			return "Fish"
		_:
			return "Hands"
