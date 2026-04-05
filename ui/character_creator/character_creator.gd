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

@onready var origin_button: Button = $DetailsPanel/OriginsRow/OriginButton
@onready var trait_button: Button = $DetailsPanel/TraitsRow/TraitButton
@onready var birthsign_button: Button = $DetailsPanel/BirthsignRow/BirthsignButton

# --- Bottom controls ---
@onready var confirm_button: Button = $ConfirmButton
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
	_connect_signals()
	_refresh_all()


func _load_from_gamestate() -> void:
	name_input.text = GameState.player_name

	head_index = GameState.head_index
	shirt_index = GameState.shirt_index
	pants_index = GameState.pants_index

	origin_id = clamp(GameState.origin_id, 0, _origins.size() - 1)
	trait_id_1 = clamp(GameState.trait_id_1 if GameState.trait_id_1 >= 0 else 0, 0, _traits.size() - 1)
	trait_id_2 = clamp(GameState.trait_id_2 if GameState.trait_id_2 >= 0 else 1, 0, _traits.size() - 1)
	if trait_id_2 == trait_id_1:
		trait_id_2 = (trait_id_1 + 1) % _traits.size()

	birthsign_id = clamp(GameState.birthsign_id, 0, _birthsigns.size() - 1)


func _connect_signals() -> void:
	head_left_button.pressed.connect(_on_head_left)
	head_right_button.pressed.connect(_on_head_right)

	shirt_left_button.pressed.connect(_on_shirt_left)
	shirt_right_button.pressed.connect(_on_shirt_right)

	pants_left_button.pressed.connect(_on_pants_left)
	pants_right_button.pressed.connect(_on_pants_right)

	origin_button.pressed.connect(_on_origin_cycle)
	trait_button.pressed.connect(_on_trait_cycle)
	birthsign_button.pressed.connect(_on_birthsign_cycle)

	rotate_left_button.pressed.connect(_on_rotate_left)
	rotate_right_button.pressed.connect(_on_rotate_right)

	confirm_button.pressed.connect(_on_confirm_pressed)


func _refresh_all() -> void:
	_update_detail_buttons()
	_apply_visuals()


# --- UI callbacks ---

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


func _on_origin_cycle() -> void:
	origin_id = (origin_id + 1) % _origins.size()
	_update_detail_buttons()


func _on_trait_cycle() -> void:
	trait_id_1 = (trait_id_1 + 1) % _traits.size()
	trait_id_2 = (trait_id_1 + 1) % _traits.size()
	_update_detail_buttons()


func _on_birthsign_cycle() -> void:
	birthsign_id = (birthsign_id + 1) % _birthsigns.size()
	_update_detail_buttons()


func _on_rotate_left() -> void:
	player.rotate_y(deg_to_rad(-30))


func _on_rotate_right() -> void:
	player.rotate_y(deg_to_rad(30))


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

func _update_detail_buttons() -> void:
	origin_button.text = _origins[origin_id]
	trait_button.text = "%s / %s" % [_traits[trait_id_1], _traits[trait_id_2]]
	birthsign_button.text = _birthsigns[birthsign_id]


func _apply_visuals() -> void:
	var bc: Node = player.get_node_or_null("BaseCharacter")
	if bc == null or not bc.has_method("apply_customization"):
		return
	bc.apply_customization(head_index, shirt_index, pants_index)
