extends Control

# --- 3D preview ---
@onready var preview_root: Node3D = $PodiumAnchor/SubViewportContainer/SubViewport/PreviewRoot
@onready var player: CharacterBody3D = preview_root.get_node("Player")

# --- Left Customize panel ---
@onready var head_left_button: Button = $CustomizePanel/HeadsRow/HeadButtons/HeadLeftButton
@onready var head_right_button: Button = $CustomizePanel/HeadsRow/HeadButtons/HeadRightButton

@onready var shirt_left_button: Button = $CustomizePanel/OutfitRow/ShirtButtons/ShirtLeftButton
@onready var shirt_right_button: Button = $CustomizePanel/OutfitRow/ShirtButtons/ShirtRightButton

@onready var pants_left_button: Button = $CustomizePanel/OutfitRow/PantsButtons/PantsLeftButton
@onready var pants_right_button: Button = $CustomizePanel/OutfitRow/PantsButtons/PantsRightButton

# --- Right Details panel ---
@onready var name_input: LineEdit = $DetailsPanel/NameInput

@onready var origin_button: OptionButton = $DetailsPanel/OriginsRow/OriginButton
@onready var trait_button: OptionButton = $DetailsPanel/TraitsRow/TraitButton
@onready var birthsign_button: OptionButton = $DetailsPanel/BirthsignRow/BirthsignButton

# --- Bottom controls ---
@onready var confirm_button: Button = $ConfirmButton
@onready var back_button: Button = $BackButton
@onready var rotate_left_button: Button = $PodiumPanel/RotateLeftButton
@onready var rotate_right_button: Button = $PodiumPanel/RotateRightButton

# --- Data ---

var _origins := [
	"Peasant",
	"Outlaw Hunter",
	"Seafarer",
	"Stonewright",
	"Woodsman",
	"King's Smith",
	"Builder",
	"Bard",
]

var _traits := [
	"Night Owl",
	"Early Riser",
	"Thick-Blooded",
	"Glass Hands",
	"Careful Striker",
	"Forager's Instinct",
	"Fleet-Footed",
	"Iron Stomach",
	"Hermit",
	"Pack Mule",
]

var _birthsigns := [
	"Frostforge",
	"Blood-Anvil",
	"Chain-Fenrir",
	"Jotunfang",
	"Yggdrasil Root",
	"Jarnvidr Thorn",
	"Niflheim Mist",
	"Freyja's Bloodbloom",
	"Naglfar Tide",
	"Odin's Crowngold",
	"Ragnarok Shadow",
	"Musphel Flame",
]

var head_index: int = 0
var shirt_index: int = 0
var pants_index: int = 0

var origin_id: int = 0
var trait_id_1: int = 0
var trait_id_2: int = 1
var birthsign_id: int = 0


func _ready() -> void:
	_load_from_gamestate()
	_setup_detail_option_buttons()
	_connect_signals()
	_sync_detail_option_buttons()
	_refresh_all()


func _load_from_gamestate() -> void:
	name_input.text = GameState.player_name

	head_index = GameState.head_index
	shirt_index = GameState.shirt_index
	pants_index = GameState.pants_index

	origin_id = clamp(GameState.origin_id, 0, _origins.size() - 1)
	trait_id_1 = clampi(GameState.trait_id_1, 0, _traits.size() - 1)
	trait_id_2 = (trait_id_1 + 1) % _traits.size()

	birthsign_id = clamp(GameState.birthsign_id, 0, _birthsigns.size() - 1)


func _setup_detail_option_buttons() -> void:
	_fill_option_button(origin_button, _origins)
	_fill_option_button(birthsign_button, _birthsigns)

	trait_button.clear()
	var n: int = _traits.size()
	for i in n:
		trait_button.add_item("%s / %s" % [_traits[i], _traits[(i + 1) % n]])


func _fill_option_button(ob: OptionButton, labels: Array) -> void:
	ob.clear()
	for s in labels:
		ob.add_item(str(s))


func _sync_detail_option_buttons() -> void:
	_select_without_signal(origin_button, origin_id)
	_select_without_signal(trait_button, trait_id_1)
	_select_without_signal(birthsign_button, birthsign_id)


func _select_without_signal(ob: OptionButton, index: int) -> void:
	ob.block_signals(true)
	ob.select(clampi(index, 0, max(0, ob.item_count - 1)))
	ob.block_signals(false)


func _connect_signals() -> void:
	head_left_button.pressed.connect(_on_head_left)
	head_right_button.pressed.connect(_on_head_right)

	shirt_left_button.pressed.connect(_on_shirt_left)
	shirt_right_button.pressed.connect(_on_shirt_right)

	pants_left_button.pressed.connect(_on_pants_left)
	pants_right_button.pressed.connect(_on_pants_right)

	origin_button.item_selected.connect(_on_origin_selected)
	trait_button.item_selected.connect(_on_trait_selected)
	birthsign_button.item_selected.connect(_on_birthsign_selected)

	rotate_left_button.pressed.connect(_on_rotate_left)
	rotate_right_button.pressed.connect(_on_rotate_right)

	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _refresh_all() -> void:
	_apply_visuals()


# --- UI callbacks ---

func _on_origin_selected(index: int) -> void:
	origin_id = index


func _on_trait_selected(index: int) -> void:
	trait_id_1 = index
	trait_id_2 = (trait_id_1 + 1) % _traits.size()


func _on_birthsign_selected(index: int) -> void:
	birthsign_id = index


func _on_head_left() -> void:
	head_index = max(0, head_index - 1)
	_apply_visuals()


func _on_head_right() -> void:
	head_index += 1
	_apply_visuals()


func _on_shirt_left() -> void:
	shirt_index = max(0, shirt_index - 1)
	_apply_visuals()


func _on_shirt_right() -> void:
	shirt_index += 1
	_apply_visuals()


func _on_pants_left() -> void:
	pants_index = max(0, pants_index - 1)
	_apply_visuals()


func _on_pants_right() -> void:
	pants_index += 1
	_apply_visuals()


func _on_rotate_left() -> void:
	player.rotate_y(deg_to_rad(-30))


func _on_rotate_right() -> void:
	player.rotate_y(deg_to_rad(30))


func _on_back_pressed() -> void:
	SceneManager.fade_to_scene("res://ui/menus/main_menu.tscn")


func _on_confirm_pressed() -> void:
	GameState.player_name = name_input.text.strip_edges()

	GameState.head_index = head_index
	GameState.shirt_index = shirt_index
	GameState.pants_index = pants_index

	GameState.origin_id = origin_id
	GameState.trait_id_1 = trait_id_1
	GameState.trait_id_2 = trait_id_2
	GameState.birthsign_id = birthsign_id

	GameState.region = "tutorial_isle"

	SaveManager.save_game()
	SceneManager.fade_to_scene("res://world/regions/tutorial_isle/tutorial_isle.tscn")


# --- Helpers ---

func _apply_visuals() -> void:
	var bc: Node = player.get_node_or_null("BaseCharacter")
	if bc == null or not bc.has_method("apply_customization"):
		return
	bc.apply_customization(head_index, shirt_index, pants_index)
