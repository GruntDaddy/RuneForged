class_name BaseCharacter
extends Node3D

const _CombatFormulaService = preload("res://systems/combat/combat_formula_service.gd")
const _WeaponStats = preload("res://data/schemas/weapon_stats.gd")

## Locomotion + one-shot tool / survival clips share the same AnimationPlayer library **Base**.
## Action state machine: locomotion updates are skipped while a tool/survival clip is playing.

enum ToolKind {
	NONE,
	AXE,
	PICKAXE,
	FISHING_ROD,
}

enum ActionState {
	LOCOMOTION,
	TOOL_ACTION,
	COMBAT_ACTION,
	RUNE_CAST_ACTION,
}

@onready var skeleton: Skeleton3D = $Rig_Medium/Skeleton3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

@onready var hand_r_slot: BoneAttachment3D = $Rig_Medium/Skeleton3D/HandAttach_R
@onready var hand_l_slot: BoneAttachment3D = $Rig_Medium/Skeleton3D/HandAttach_L

@onready var equipped_tool_root: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight
@onready var axe_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight/Hatchet_Basic
@onready var axe_bronze_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight/Hatchet_Bronze
@onready var pickaxe_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight/Pickaxe_Basic
@onready var pickaxe_bronze_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight/Pickaxe_Bronze
@onready var fishing_pole_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight/Fishing_Pole
@onready var hammer_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight/Hammer_Common
@onready var equipped_weapon_root: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight
@onready var equipped_weapon_left_root: Node3D = get_node_or_null(
	"Rig_Medium/Skeleton3D/HandAttach_L/EquippedWeaponLeft"
) as Node3D
@onready var dagger_bronze_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight/Dagger_Bronze
@onready var sword_wooden_mesh: Node3D = get_node_or_null(
	"Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight/1h_Sword_Wooden"
) as Node3D
@onready var sword_short_mesh_variants: Array[Node3D] = [
	get_node_or_null("Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight/1h_ShortSword_Bronze") as Node3D,
	get_node_or_null("Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight/1h_ShortSword_Iron") as Node3D,
	get_node_or_null("Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight/1h_ShortSword_Steel") as Node3D,
	get_node_or_null("Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight/1h_ShortSword_Mithril") as Node3D,
	get_node_or_null("Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight/1h_ShortSword_Adamant") as Node3D,
	get_node_or_null("Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight/1h_ShortSword_Rune") as Node3D,
	get_node_or_null("Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight/1h_ShortSword_Dragon") as Node3D,
]
@onready var bow_short_left_mesh: Node3D = (
	get_node_or_null("Rig_Medium/Skeleton3D/HandAttach_L/EquippedWeaponLeft/Bow_Hunting_Bow")
	as Node3D
	if get_node_or_null("Rig_Medium/Skeleton3D/HandAttach_L/EquippedWeaponLeft/Bow_Hunting_Bow") != null
	else get_node_or_null("Rig_Medium/Skeleton3D/HandAttach_L/EquippedWeaponLeft/Bow_Short_Common") as Node3D
)
@onready var bow_long_left_mesh: Node3D = (
	get_node_or_null("Rig_Medium/Skeleton3D/HandAttach_L/EquippedWeaponLeft/Bow_Common")
	as Node3D
	if get_node_or_null("Rig_Medium/Skeleton3D/HandAttach_L/EquippedWeaponLeft/Bow_Common") != null
	else get_node_or_null("Rig_Medium/Skeleton3D/HandAttach_L/EquippedWeaponLeft/Bow_Long_Common") as Node3D
)
@onready var arrow_spawn: Marker3D = get_node_or_null(
	"Rig_Medium/Skeleton3D/HandAttach_L/EquippedWeaponLeft/ArrowSpawn"
) as Marker3D
@onready var tacklebox_hand_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_L/EquippedToolLeft/Tacklebox
@onready var torch_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_L/EquippedToolLeft/Torch
@onready var chisel_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_L/EquippedToolLeft/Chisel
@onready var shield_bronze_mesh: Node3D = get_node_or_null(
	"Rig_Medium/Skeleton3D/HandAttach_L/EquippedShield/Shield_Kite_Bronze"
) as Node3D
@onready var shield_iron_mesh: Node3D = get_node_or_null(
	"Rig_Medium/Skeleton3D/HandAttach_L/EquippedShield/Shield_Kite_Iron"
) as Node3D
@onready var shield_square_bronze_mesh: Node3D = get_node_or_null(
	"Rig_Medium/Skeleton3D/HandAttach_L/EquippedShield/Shield_Square_Bronze"
) as Node3D
@onready var shield_square_iron_mesh: Node3D = get_node_or_null(
	"Rig_Medium/Skeleton3D/HandAttach_L/EquippedShield/Shield_Square_Iron"
) as Node3D
@onready var shield_wooden_mesh: Node3D = get_node_or_null(
	"Rig_Medium/Skeleton3D/HandAttach_L/EquippedShield/Shield_Wooden"
) as Node3D
@onready var clothing_root: Node3D = get_node_or_null("Rig_Medium/Skeleton3D/Clothing") as Node3D
@onready var cape_blue_mesh: Node3D = get_node_or_null("Rig_Medium/Skeleton3D/Capes/Cape_Blue") as Node3D
@onready var backpack_large_mesh: Node3D = get_node_or_null("Rig_Medium/Skeleton3D/Backpacks/Backpack_Large") as Node3D
@onready var quiver_common_mesh: Node3D = get_node_or_null("Rig_Medium/Skeleton3D/Quivers/Quiver_Common") as Node3D
@onready var quiver_bronze_mesh: Node3D = get_node_or_null("Rig_Medium/Skeleton3D/Quivers/Quiver_Bronze") as Node3D
@onready var quiver_iron_mesh: Node3D = get_node_or_null("Rig_Medium/Skeleton3D/Quivers/Quiver_Iron") as Node3D
@onready var outfit_green: Node3D = get_node_or_null("Rig_Medium/Skeleton3D/Clothing/Outfit_2_Green") as Node3D
@onready var outfit_yellow: Node3D = get_node_or_null("Rig_Medium/Skeleton3D/Clothing/Outfit_1_Yellow") as Node3D
@onready var shirt_green_mesh: Node3D = get_node_or_null(
	"Rig_Medium/Skeleton3D/Clothing/Outfit_2_Green/Shirt_Green"
) as Node3D
@onready var pants_green_mesh: Node3D = get_node_or_null(
	"Rig_Medium/Skeleton3D/Clothing/Outfit_2_Green/Pants_Green"
) as Node3D
@onready var shirt_yellow_mesh: Node3D = get_node_or_null(
	"Rig_Medium/Skeleton3D/Clothing/Outfit_1_Yellow/Shirt_Yellow"
) as Node3D
@onready var pants_yellow_mesh: Node3D = get_node_or_null(
	"Rig_Medium/Skeleton3D/Clothing/Outfit_1_Yellow/Pants_Yellow"
) as Node3D
@onready var helmets_root: Node3D = $Rig_Medium/Skeleton3D/Helmets
@onready var armor_root: Node3D = $Rig_Medium/Skeleton3D/Armor
@onready var base_body_mesh: MeshInstance3D = get_node_or_null("Rig_Medium/Base_Body") as MeshInstance3D
@onready var base_arm_left_mesh: MeshInstance3D = get_node_or_null("Rig_Medium/Base_ArmLeft") as MeshInstance3D
@onready var base_arm_right_mesh: MeshInstance3D = get_node_or_null("Rig_Medium/Base_ArmRight") as MeshInstance3D
@onready var base_leg_left_mesh: MeshInstance3D = get_node_or_null("Rig_Medium/Base_LegLeft") as MeshInstance3D
@onready var base_leg_right_mesh: MeshInstance3D = get_node_or_null("Rig_Medium/Base_LegRight") as MeshInstance3D

## Order matches cycling in the character creator; one head visible at a time.
var _head_paths: Array[String] = [
	"Rig_Medium/Skeleton3D/Head_M-W_01_R",
	"Rig_Medium/Skeleton3D/Head_M-W_02_R",
	"Rig_Medium/Skeleton3D/Head_F-W_01_R",
	"Rig_Medium/Skeleton3D/Head_F-W_02_R",
]

## Placeholder outfit tints until separate KayKit shirt/pants meshes are hooked up.
const SHIRT_TINTS: Array[Color] = [
	Color.WHITE,
	Color(0.82, 0.88, 1.0),
	Color(1.0, 0.9, 0.82),
	Color(0.85, 1.0, 0.88),
	Color(1.0, 0.82, 0.86),
]
const PANTS_TINTS: Array[Color] = [
	Color.WHITE,
	Color(0.55, 0.52, 0.62),
	Color(0.42, 0.48, 0.58),
	Color(0.58, 0.5, 0.42),
	Color(0.48, 0.55, 0.5),
]

const _ANIM_LIB := "Base"
const _ANIM_WALK := "Walking_B"
const _ANIM_RUN := "Running_A"
const _ANIM_IDLE := "Idle_A"
const _ANIM_AIR := "Jump_Idle"
const _ANIM_CHOP := "Chop 2"
const _ANIM_PICKAXE := "Pickaxe"
const _ANIM_INTERACT := "Interact"
const _ANIM_PICKUP := "PickUp"
const _ANIM_USE_ITEM := "Use_Item"
## Combat clips are authored under `Base/` in AnimationLibrary (may alias survival poses until sword/block/bow slices ship).
const _ANIM_MELEE_1H := "Melee_Attack_1H"
const _ANIM_MELEE_ALT_CHOP := "Chop"
const _ANIM_BLOCK_LOOP := "Shield_Block_Loop"
const _ANIM_BOW_DRAW := "Bow_Draw"
const _ANIM_BOW_RELEASE := "Bow_Release"
const _ANIM_UNARMED_PUNCH := "Melee_Unarmed_Attack_Punch_A"
const _ANIM_UNARMED_KICK := "Melee_Unarmed_Attack_Kick"
const _REQUIRED_RIG_PATHS: Array[String] = [
	"Rig_Medium",
	"Rig_Medium/Skeleton3D",
	"Rig_Medium/Skeleton3D/HandAttach_R",
	"Rig_Medium/Skeleton3D/HandAttach_L",
	"Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight",
	"Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight",
	"Rig_Medium/Skeleton3D/HandAttach_L/EquippedToolLeft",
	"Rig_Medium/Skeleton3D/HandAttach_L/EquippedWeaponLeft",
	"Rig_Medium/Skeleton3D/Helmets",
	"Rig_Medium/Skeleton3D/Armor",
	"AnimationPlayer",
]

@export var melee_combo_reset_seconds: float = 1.25

var _action_state: ActionState = ActionState.LOCOMOTION
## Player-selected tool (keys 1–4). Swings temporarily show axe/pickaxe to match the clip, then this is restored.
var _player_chosen_tool: ToolKind = ToolKind.NONE
var _equipped_main_hand_item_id: String = ""
var _equipped_off_hand_item_id: String = ""
var _equipped_head_item_id: String = ""
var _equipped_chest_item_id: String = ""
var _equipped_legs_item_id: String = ""
var _equipped_back_item_id: String = ""

var _block_hold_active: bool = false
## 0 idle, 1 draw playing, 2 fully drawn (held pose), 3 release playing.
var _bow_phase: int = 0
var _next_unarmed_kick: bool = false
var _melee_combo_step: int = 0
var _active_melee_clip: String = ""
var _active_rune_cast_clip: String = ""
var _last_melee_attack_ms: int = -1


func _ready() -> void:
	_validate_runtime_contract()
	if skeleton == null:
		push_warning("BaseCharacter: Skeleton3D not found at Rig_Medium/Skeleton3D.")

	if hand_r_slot == null:
		push_warning("BaseCharacter: HandAttach_R not found.")
	if hand_l_slot == null:
		push_warning("BaseCharacter: HandAttach_L not found.")

	if anim_player:
		if not anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.connect(_on_animation_finished)

	if anim_player and anim_player.has_animation(_anim_path(_ANIM_IDLE)):
		anim_player.play(_anim_path(_ANIM_IDLE))

	_disable_equipped_tool_colliders()
	_rebind_equipment_mesh_skeleton_paths()
	_apply_armor_visibility()
	_apply_tool_kind(_player_chosen_tool)


func _validate_runtime_contract() -> void:
	var missing_nodes: Array[String] = []
	for p in _REQUIRED_RIG_PATHS:
		if get_node_or_null(p) == null:
			missing_nodes.append(p)
	if not missing_nodes.is_empty():
		push_error(
			"BaseCharacter: required scene nodes missing: %s"
			% ", ".join(missing_nodes)
		)
	if anim_player == null:
		push_error("BaseCharacter: AnimationPlayer missing; locomotion/combat clips will fail.")
		return
	var required_clips: Array[String] = [
		_ANIM_IDLE,
		_ANIM_WALK,
		_ANIM_RUN,
		_ANIM_AIR,
		_ANIM_CHOP,
		_ANIM_PICKAXE,
		_ANIM_INTERACT,
		_ANIM_PICKUP,
		_ANIM_USE_ITEM,
		_ANIM_MELEE_1H,
		_ANIM_BLOCK_LOOP,
		_ANIM_BOW_DRAW,
		_ANIM_BOW_RELEASE,
		_ANIM_UNARMED_PUNCH,
		_ANIM_UNARMED_KICK,
	]
	var missing_clips: Array[String] = []
	for clip in required_clips:
		if not anim_player.has_animation(_anim_path(clip)):
			missing_clips.append("%s/%s" % [_ANIM_LIB, clip])
	if not missing_clips.is_empty():
		push_error(
			"BaseCharacter: required animations missing: %s"
			% ", ".join(missing_clips)
		)


func _anim_path(clip: String) -> StringName:
	return StringName("%s/%s" % [_ANIM_LIB, clip])


func _disable_equipped_tool_colliders() -> void:
	if hand_r_slot == null:
		return
	var bodies: Array[Node] = hand_r_slot.find_children("*", "StaticBody3D", true, false)
	for n in bodies:
		var sb := n as StaticBody3D
		if sb == null:
			continue
		# Equipped hand tools are visual props; their physics bodies can push/carry the player capsule.
		sb.collision_layer = 0
		sb.collision_mask = 0


func _rebind_equipment_mesh_skeleton_paths() -> void:
	if skeleton == null:
		return
	_rebind_meshes_under(helmets_root)
	_rebind_meshes_under(armor_root)


func _rebind_meshes_under(root: Node) -> void:
	if root == null:
		return
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	for n in meshes:
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		# Armor/helmet scenes are instanced under different parents; compute skeleton path dynamically.
		mi.skeleton = mi.get_path_to(skeleton)


func set_locomotion_state(moving: bool, running: bool, on_floor: bool) -> void:
	if anim_player == null:
		return
	if _block_hold_active:
		_play_if_needed(_ANIM_BLOCK_LOOP, 0.12)
		return
	if _bow_phase > 0 and _bow_phase != 3:
		return
	if _action_state == ActionState.RUNE_CAST_ACTION:
		return
	if _action_state != ActionState.LOCOMOTION:
		return
	if not on_floor:
		_play_if_needed(_ANIM_AIR, 0.12)
		return
	if moving:
		if running and anim_player.has_animation(_anim_path(_ANIM_RUN)):
			_play_if_needed(_ANIM_RUN, 0.12)
		else:
			_play_if_needed(_ANIM_WALK, 0.12)
		anim_player.speed_scale = 1.0
	else:
		_play_if_needed(_ANIM_IDLE, 0.12)
		anim_player.speed_scale = 1.0


func _play_if_needed(clip: String, blend: float) -> void:
	var path := _anim_path(clip)
	if not anim_player.has_animation(path):
		return
	if String(anim_player.current_animation) == String(path) and anim_player.is_playing():
		return
	anim_player.play(path, blend)


## AnimationPlayer may emit `animation_finished` as `Library/Clip` or as `Clip` only — normalize for comparisons.
func _finished_animation_clip_name(anim_name: StringName) -> String:
	var s := String(anim_name)
	var prefix := _ANIM_LIB + "/"
	if s.begins_with(prefix):
		return s.substr(prefix.length())
	return s


func _process(_delta: float) -> void:
	# Fallback when `animation_finished` is missing/mismatched or clip names differ by library prefix.
	if anim_player == null or _bow_phase == 0:
		return
	var cur_full := String(anim_player.current_animation)
	if cur_full.is_empty():
		return
	var cur_base := _finished_animation_clip_name(StringName(cur_full))
	var length := anim_player.current_animation_length
	var pos := anim_player.current_animation_position
	var playing := anim_player.is_playing()

	if _bow_phase == 1 and cur_base == _ANIM_BOW_DRAW and length > 0.0:
		var near_end: bool = pos >= length - minf(0.08, maxf(0.02, length * 0.02))
		var ratio: float = pos / length if length > 0.0 else 0.0
		if near_end or ratio >= 0.995 or (not playing and pos >= length * 0.95):
			_bow_phase = 2
		return

	if _bow_phase == 3 and cur_base == _ANIM_BOW_RELEASE:
		var release_thresh := length - minf(0.08, maxf(0.02, length * 0.02)) if length > 0.0 else 0.0
		var release_ratio: float = pos / length if length > 0.0 else 0.0
		if not playing:
			_bow_release_finished_cleanup()
		elif length > 0.0 and (pos >= release_thresh or release_ratio >= 0.995):
			_bow_release_finished_cleanup()


func _bow_release_finished_cleanup() -> void:
	if _bow_phase != 3:
		return
	_bow_phase = 0
	_action_state = ActionState.LOCOMOTION
	_apply_tool_kind(_player_chosen_tool)


func _on_animation_finished(anim_name: StringName) -> void:
	var clip_name := _finished_animation_clip_name(anim_name)

	if _bow_phase == 1 and clip_name == _ANIM_BOW_DRAW:
		_bow_phase = 2
		return

	if _action_state == ActionState.COMBAT_ACTION and _bow_phase == 3 and clip_name == _ANIM_BOW_RELEASE:
		_bow_release_finished_cleanup()
		return

	if _action_state == ActionState.RUNE_CAST_ACTION and clip_name == _active_rune_cast_clip:
		_active_rune_cast_clip = ""
		_action_state = ActionState.LOCOMOTION
		_apply_tool_kind(_player_chosen_tool)
		return

	if _action_state == ActionState.COMBAT_ACTION and clip_name == _active_melee_clip:
		_active_melee_clip = ""
		_action_state = ActionState.LOCOMOTION
		_apply_tool_kind(_player_chosen_tool)
		return
	if _action_state == ActionState.COMBAT_ACTION and (clip_name == _ANIM_UNARMED_PUNCH or clip_name == _ANIM_UNARMED_KICK):
		_action_state = ActionState.LOCOMOTION
		_apply_tool_kind(_player_chosen_tool)
		return

	if _action_state != ActionState.TOOL_ACTION:
		return
	_action_state = ActionState.LOCOMOTION
	_apply_tool_kind(_player_chosen_tool)


func _apply_tool_kind(kind: ToolKind) -> void:
	_set_right_hand_meshes_visible(false)
	_set_weapon_meshes_visible(false)
	var show_tool_root := false
	if kind == ToolKind.AXE:
		show_tool_root = true
		_pick_right_hand_tool(["hatchet_bronze", "hatchet_basic"], axe_bronze_mesh, axe_mesh)
	elif kind == ToolKind.PICKAXE:
		show_tool_root = true
		_pick_right_hand_tool(["pickaxe_bronze", "pickaxe_basic"], pickaxe_bronze_mesh, pickaxe_mesh)
	elif kind == ToolKind.FISHING_ROD:
		show_tool_root = true
		if fishing_pole_mesh != null:
			fishing_pole_mesh.visible = true
	else:
		if _equipped_main_hand_item_id == "tool_hammer":
			show_tool_root = true
			if hammer_mesh != null:
				hammer_mesh.visible = true
		else:
			_show_equipped_weapon_mesh()
	if hammer_mesh != null:
		hammer_mesh.visible = show_tool_root and _equipped_main_hand_item_id == "tool_hammer"
	if equipped_tool_root != null:
		equipped_tool_root.visible = show_tool_root
	_apply_off_hand_visibility()


## When the active tool is the fishing rod, controls whether the back tacklebox mesh is shown (e.g. inventory has `tool_tacklebox`).
func set_tacklebox_back_display_enabled(enabled: bool) -> void:
	# Back-slot tacklebox visuals are disabled by design (off-hand only).
	if enabled:
		return


func set_equipped_hand_items(main_hand_item_id: String, off_hand_item_id: String) -> void:
	_equipped_main_hand_item_id = main_hand_item_id
	_equipped_off_hand_item_id = off_hand_item_id
	if not _off_hand_has_shield():
		_block_hold_active = false
	if _action_state == ActionState.LOCOMOTION:
		_apply_tool_kind(_player_chosen_tool)


func set_equipped_armor_items(head_item_id: String, chest_item_id: String, legs_item_id: String, back_item_id: String = "") -> void:
	_equipped_head_item_id = head_item_id
	_equipped_chest_item_id = chest_item_id
	_equipped_legs_item_id = legs_item_id
	_equipped_back_item_id = back_item_id
	_apply_armor_visibility()


## Player tool selection (keys 1–4): updates which KayKit mesh is shown when idle.
func set_active_tool(kind: ToolKind) -> void:
	_player_chosen_tool = kind
	if _action_state == ActionState.LOCOMOTION:
		_apply_tool_kind(kind)


func get_active_tool_kind() -> ToolKind:
	return _player_chosen_tool


func is_tool_action_active() -> bool:
	return _action_state == ActionState.TOOL_ACTION


func is_animation_locked() -> bool:
	if (
		_action_state == ActionState.TOOL_ACTION
		or _action_state == ActionState.COMBAT_ACTION
		or _action_state == ActionState.RUNE_CAST_ACTION
	):
		return true
	if _block_hold_active:
		return true
	if _bow_phase > 0:
		return true
	return false


## Movement can continue while shield blocking; this excludes block-hold from hard lock checks.
func is_movement_locked() -> bool:
	if (
		_action_state == ActionState.TOOL_ACTION
		or _action_state == ActionState.COMBAT_ACTION
		or _action_state == ActionState.RUNE_CAST_ACTION
	):
		return true
	if _bow_phase > 0:
		return true
	return false


func is_blocking() -> bool:
	return _block_hold_active


func is_bow_drawn_or_drawing() -> bool:
	return _bow_phase > 0


## True during one-handed melee / unarmed swing (not bow draw or release).
func is_melee_combat_active() -> bool:
	return _action_state == ActionState.COMBAT_ACTION and _bow_phase == 0


## Clip basename (library-relative) for the current melee swing; empty if not in a melee attack.
func get_active_melee_clip_name() -> String:
	return _active_melee_clip


## Stops the current tool clip (e.g. target destroyed mid-swing) and returns to idle + chosen tool mesh.
func cancel_tool_action() -> void:
	_block_hold_active = false
	_bow_phase = 0
	_active_rune_cast_clip = ""
	_action_state = ActionState.LOCOMOTION
	if anim_player != null:
		anim_player.stop()
		if anim_player.has_animation(_anim_path(_ANIM_IDLE)):
			anim_player.play(_anim_path(_ANIM_IDLE), 0.12)
	_apply_tool_kind(_player_chosen_tool)


## Shield hold (requires shield in off-hand). Blocks locomotion blends while active.
func set_blocking(wanted: bool) -> void:
	if wanted and not _off_hand_has_shield():
		_block_hold_active = false
		if _action_state == ActionState.LOCOMOTION:
			_apply_tool_kind(_player_chosen_tool)
		return
	if wanted and (
		_action_state == ActionState.TOOL_ACTION
		or _action_state == ActionState.COMBAT_ACTION
		or _action_state == ActionState.RUNE_CAST_ACTION
	):
		return
	if wanted and _bow_phase > 0:
		return
	_block_hold_active = wanted
	if not wanted:
		if _action_state == ActionState.LOCOMOTION:
			_apply_tool_kind(_player_chosen_tool)
		return
	if anim_player != null and anim_player.has_animation(_anim_path(_ANIM_BLOCK_LOOP)):
		anim_player.speed_scale = 1.0
		anim_player.play(_anim_path(_ANIM_BLOCK_LOOP), 0.12)


func try_play_melee_attack_1h() -> bool:
	if anim_player == null:
		return false
	if is_animation_locked():
		return false
	_reset_combo_if_timed_out()
	var attack_clip := _ANIM_MELEE_1H
	if _equipped_main_hand_item_id.is_empty():
		attack_clip = _ANIM_UNARMED_KICK if _next_unarmed_kick else _ANIM_UNARMED_PUNCH
		_next_unarmed_kick = not _next_unarmed_kick
	else:
		attack_clip = _resolve_weapon_combo_clip()
	var path := _anim_path(attack_clip)
	if not anim_player.has_animation(path):
		if attack_clip != _ANIM_MELEE_1H:
			attack_clip = _ANIM_MELEE_1H
			path = _anim_path(_ANIM_MELEE_1H)
	if not anim_player.has_animation(path):
		if attack_clip != _ANIM_MELEE_ALT_CHOP:
			attack_clip = _ANIM_MELEE_ALT_CHOP
			path = _anim_path(_ANIM_MELEE_ALT_CHOP)
	if not anim_player.has_animation(path):
		return false
	_action_state = ActionState.COMBAT_ACTION
	_active_melee_clip = attack_clip
	_apply_weapon_visual_for_attack()
	anim_player.speed_scale = 1.0
	anim_player.play(path, 0.12)
	_last_melee_attack_ms = Time.get_ticks_msec()
	return true


func try_play_rune_air_push() -> bool:
	if anim_player == null:
		return false
	if is_animation_locked():
		return false
	var clip := _first_available_clip_named(
		["Magic_Air_Push", "Spell_Cast_Air", _ANIM_INTERACT]
	)
	if clip.is_empty():
		return false
	var path := _anim_path(clip)
	if not anim_player.has_animation(path):
		return false
	_action_state = ActionState.RUNE_CAST_ACTION
	_active_rune_cast_clip = clip
	_apply_weapon_visual_for_attack()
	anim_player.speed_scale = 1.0
	anim_player.play(path, 0.12)
	return true


func _first_available_clip_named(candidates: Array) -> String:
	for c in candidates:
		var clip := str(c)
		if clip.is_empty():
			continue
		if anim_player != null and anim_player.has_animation(_anim_path(clip)):
			return clip
	return ""


func _resolve_weapon_combo_clip() -> String:
	# Requested sequence: diagonal slice -> stab -> current 1H attack -> jump chop.
	var seq: Array[Array] = [
		["Melee_1H_Attack_Slice_Diagonal", "Melee_Attack_1H_Diagonal", "Melee_Attack_Diagonal", _ANIM_MELEE_1H],
		["Melee_1H_Attack_Stab", "Melee_Attack_1H_Stab", "Melee_Attack_Stab", _ANIM_MELEE_1H],
		[_ANIM_MELEE_1H],
		["Melee_1H_Attack_Jump_Chop", "Melee_Attack_1H_Jump_Chop", "Melee_Attack_Jump_Chop", _ANIM_MELEE_ALT_CHOP],
	]
	var idx := posmod(_melee_combo_step, seq.size())
	_melee_combo_step += 1
	return _first_available_clip(seq[idx])


func _first_available_clip(candidates: Array) -> String:
	for c in candidates:
		var clip := str(c)
		if clip.is_empty():
			continue
		if anim_player != null and anim_player.has_animation(_anim_path(clip)):
			return clip
	return _ANIM_MELEE_1H


func _reset_combo_if_timed_out() -> void:
	if _last_melee_attack_ms < 0:
		_melee_combo_step = 0
		return
	var timeout_ms := int(maxf(0.1, melee_combo_reset_seconds) * 1000.0)
	var elapsed := Time.get_ticks_msec() - _last_melee_attack_ms
	if elapsed > timeout_ms:
		_melee_combo_step = 0


func get_arrow_spawn_global_position() -> Vector3:
	if arrow_spawn != null:
		return arrow_spawn.global_position
	if hand_l_slot != null:
		return hand_l_slot.global_position
	return global_position


func try_begin_bow_draw() -> bool:
	if anim_player == null:
		return false
	if _bow_phase != 0:
		return false
	if _action_state != ActionState.LOCOMOTION:
		return false
	if _block_hold_active:
		return false
	var path := _anim_path(_ANIM_BOW_DRAW)
	if not anim_player.has_animation(path):
		return false
	_action_state = ActionState.COMBAT_ACTION
	_bow_phase = 1
	_apply_weapon_visual_for_attack()
	anim_player.speed_scale = 1.0
	anim_player.play(path, 0.12)
	return true


func try_cancel_bow_draw() -> void:
	if _bow_phase == 0:
		return
	_bow_phase = 0
	_action_state = ActionState.LOCOMOTION
	if anim_player != null:
		anim_player.stop()
		if anim_player.has_animation(_anim_path(_ANIM_IDLE)):
			anim_player.play(_anim_path(_ANIM_IDLE), 0.12)
	_apply_tool_kind(_player_chosen_tool)


func try_play_bow_release() -> bool:
	if anim_player == null:
		return false
	if _bow_phase != 2:
		return false
	var path := _anim_path(_ANIM_BOW_RELEASE)
	if not anim_player.has_animation(path):
		return false
	_bow_phase = 3
	_action_state = ActionState.COMBAT_ACTION
	_apply_weapon_visual_for_attack()
	anim_player.speed_scale = 1.0
	anim_player.play(path, 0.12)
	return true


func _off_hand_has_shield() -> bool:
	var off_id := _normalize_item_id(_equipped_off_hand_item_id)
	return off_id.begins_with("shield_")


## Bows are parented to the left hand (off_hand); main_hand non-bow hides the bow mesh when both are equipped.
func _weapon_mesh_item_id() -> String:
	var main_id := _normalize_item_id(_equipped_main_hand_item_id)
	var off_id := _normalize_item_id(_equipped_off_hand_item_id)
	var main_f := _CombatFormulaService.equipped_weapon_family(main_id)
	var off_f := _CombatFormulaService.equipped_weapon_family(off_id)
	if not main_id.is_empty() and main_f != _WeaponStats.WeaponFamily.BOW:
		return main_id
	if off_f == _WeaponStats.WeaponFamily.BOW:
		return off_id
	if not main_id.is_empty():
		return main_id
	return ""


func _apply_weapon_visual_for_attack() -> void:
	var tool_kind := _tool_kind_for_main_hand_item_id()
	if tool_kind != ToolKind.NONE:
		_apply_tool_kind(tool_kind)
		return
	_set_right_hand_meshes_visible(false)
	if equipped_tool_root != null:
		equipped_tool_root.visible = false
	_set_weapon_meshes_visible(false)
	_show_equipped_weapon_mesh()


func _tool_kind_for_main_hand_item_id() -> ToolKind:
	match _equipped_main_hand_item_id:
		"hatchet_basic", "hatchet_bronze":
			return ToolKind.AXE
		"pickaxe_basic", "pickaxe_bronze":
			return ToolKind.PICKAXE
		"fishing_pole":
			return ToolKind.FISHING_ROD
		_:
			return ToolKind.NONE


## Plays a one-shot survival/tool clip. Returns false if a tool action is already playing.
func try_play_action_for_harvest(harvest_action: String) -> bool:
	if anim_player == null:
		return false
	if is_animation_locked():
		return false
	var clip: String = _ANIM_CHOP
	var swing_tool := ToolKind.AXE
	match harvest_action:
		"mine", "pickaxe", "rock":
			clip = _ANIM_PICKAXE
			swing_tool = ToolKind.PICKAXE
		"chop", "tree", "axe", "wood":
			clip = _ANIM_CHOP
			swing_tool = ToolKind.AXE
		"interact":
			clip = _ANIM_INTERACT
			swing_tool = _player_chosen_tool
		"pickup":
			clip = _ANIM_PICKUP
			swing_tool = _player_chosen_tool
		"use_item":
			clip = _ANIM_USE_ITEM
			swing_tool = _player_chosen_tool
		_:
			clip = _ANIM_CHOP
			swing_tool = ToolKind.AXE
	_apply_tool_kind(swing_tool)
	var path := _anim_path(clip)
	if not anim_player.has_animation(path):
		_action_state = ActionState.LOCOMOTION
		return false
	_action_state = ActionState.TOOL_ACTION
	anim_player.speed_scale = 1.0
	anim_player.play(path, 0.12)
	return true


func get_hand_slot(is_right: bool = true) -> BoneAttachment3D:
	return hand_r_slot if is_right else hand_l_slot


func get_head_slot() -> BoneAttachment3D:
	return null


func get_chest_slot() -> BoneAttachment3D:
	return null


func get_legs_slot() -> BoneAttachment3D:
	return null


func get_back_slot() -> BoneAttachment3D:
	return null


func apply_customization(head_idx: int, shirt_idx: int, pants_idx: int) -> void:
	var n_heads: int = _head_paths.size()
	if n_heads == 0:
		return
	var pick: int = posmod(head_idx, n_heads)
	for i in n_heads:
		var h: Node = get_node_or_null(_head_paths[i])
		if h:
			h.visible = i == pick

	# Outfit variants replaced base-body tint placeholders in the current scene layout.
	_apply_outfit_selection(shirt_idx, pants_idx)


func _apply_outfit_selection(shirt_idx: int, pants_idx: int) -> void:
	if outfit_green == null and outfit_yellow == null:
		return
	var pick := posmod(shirt_idx + pants_idx, 2)
	if outfit_yellow != null:
		outfit_yellow.visible = pick == 0
	if outfit_green != null:
		outfit_green.visible = pick != 0


## Godot 4: MeshInstance3D has no modulate (CanvasItem-only). Tint via material albedo.
## Body meshes use a single `material_override`; tint that directly so it isn't masked by override.
## Limbs often use per-surface mesh materials only.
func _tint_mesh_surfaces(mi: MeshInstance3D, tint: Color) -> void:
	if mi == null or mi.mesh == null:
		return
	var mo := mi.material_override
	if mo is BaseMaterial3D:
		var dup_m := mo.duplicate() as BaseMaterial3D
		var mixed_m: Color = dup_m.albedo_color * tint
		dup_m.albedo_color = mixed_m.lerp(tint, 0.22)
		mi.material_override = dup_m
		return
	for surf_idx in range(mi.mesh.get_surface_count()):
		var base_mat: Material = mi.get_active_material(surf_idx)
		if base_mat == null:
			base_mat = mi.mesh.surface_get_material(surf_idx)
		if base_mat == null:
			continue
		if not (base_mat is BaseMaterial3D):
			continue
		var dup: Material = base_mat.duplicate()
		var bm := dup as BaseMaterial3D
		var mixed: Color = bm.albedo_color * tint
		bm.albedo_color = mixed.lerp(tint, 0.22)
		mi.set_surface_override_material(surf_idx, dup)


func _pick_right_hand_tool(ids: Array[String], primary: Node3D, fallback: Node3D) -> void:
	var selected: bool = false
	var inv: Node = get_node_or_null("/root/InventoryService")
	var has_item_fn: bool = inv != null and inv.has_method("has_item")
	for id in ids:
		if _equipped_main_hand_item_id == id:
			selected = true
			if id.find("bronze") >= 0:
				if primary != null:
					primary.visible = true
			else:
				if fallback != null:
					fallback.visible = true
			break
	if not selected and has_item_fn:
		for id in ids:
			if bool(inv.call("has_item", id)):
				selected = true
				if id.find("bronze") >= 0:
					if primary != null:
						primary.visible = true
				else:
					if fallback != null:
						fallback.visible = true
				break
	if not selected and fallback != null:
		# Allow harvest/tool actions to still show a default mesh even when the tool is not equipped.
		fallback.visible = true


func _set_right_hand_meshes_visible(enabled: bool) -> void:
	for n in [axe_mesh, axe_bronze_mesh, pickaxe_mesh, pickaxe_bronze_mesh, fishing_pole_mesh, hammer_mesh]:
		if n != null:
			n.visible = enabled


func _set_weapon_meshes_visible(enabled: bool) -> void:
	if equipped_weapon_root != null:
		equipped_weapon_root.visible = enabled
	if equipped_weapon_left_root != null:
		equipped_weapon_left_root.visible = enabled
	for n in [dagger_bronze_mesh, sword_wooden_mesh]:
		if n != null:
			n.visible = enabled
	for n in sword_short_mesh_variants:
		if n != null:
			n.visible = enabled
	if bow_short_left_mesh != null:
		bow_short_left_mesh.visible = enabled
	if bow_long_left_mesh != null:
		bow_long_left_mesh.visible = enabled


func _apply_off_hand_visibility() -> void:
	var off_id := _normalize_item_id(_equipped_off_hand_item_id)
	if torch_mesh != null:
		torch_mesh.visible = off_id == "tool_torch"
	if chisel_mesh != null:
		chisel_mesh.visible = off_id == "tool_chisel"
	if tacklebox_hand_mesh != null:
		tacklebox_hand_mesh.visible = off_id == "tool_tacklebox"
	if shield_bronze_mesh != null:
		shield_bronze_mesh.visible = off_id == "shield_bronze"
	if shield_iron_mesh != null:
		shield_iron_mesh.visible = off_id == "shield_iron"
	if shield_square_bronze_mesh != null:
		shield_square_bronze_mesh.visible = off_id == "shield_square_bronze"
	if shield_square_iron_mesh != null:
		shield_square_iron_mesh.visible = off_id == "shield_square_iron"
	if shield_wooden_mesh != null:
		shield_wooden_mesh.visible = off_id == "shield_wooden"


func _normalize_item_id(id: String) -> String:
	return GameState.normalize_item_id(id)


func _apply_armor_visibility() -> void:
	if helmets_root != null:
		_set_node3d_tree_visible(helmets_root, false, false)
	var head_tier := _armor_tier_from_item_id(_equipped_head_item_id, "armor_head_")
	if not head_tier.is_empty() and helmets_root != null:
		var head_node := helmets_root.get_node_or_null("FullHelm_%s" % _tier_to_node_suffix(head_tier)) as Node3D
		if head_node != null:
			head_node.visible = true
			_set_node3d_tree_visible(head_node, true, true)
	if armor_root != null:
		_set_node3d_tree_visible(armor_root, false, false)
	var chest_tier := _armor_tier_from_item_id(_equipped_chest_item_id, "armor_chest_")
	var legs_tier := _armor_tier_from_item_id(_equipped_legs_item_id, "armor_legs_")
	_set_base_outfit_visibility(chest_tier.is_empty(), legs_tier.is_empty())
	if armor_root != null and not chest_tier.is_empty():
		var chest_suffix := _tier_to_node_suffix(chest_tier)
		var body := armor_root.get_node_or_null("%s/Platebody_%s" % [chest_suffix, chest_suffix]) as Node3D
		if body != null:
			_set_ancestor_visible_until(body, armor_root)
			_set_node3d_tree_visible(body, true, true)
	if armor_root != null and not legs_tier.is_empty():
		var legs_suffix := _tier_to_node_suffix(legs_tier)
		var legs := armor_root.get_node_or_null("%s/Platelegs_%s" % [legs_suffix, legs_suffix]) as Node3D
		if legs != null:
			_set_ancestor_visible_until(legs, armor_root)
			_set_node3d_tree_visible(legs, true, true)
	_apply_back_slot_visibility()


func _apply_back_slot_visibility() -> void:
	var back_id := _normalize_item_id(_equipped_back_item_id)
	for q in [quiver_common_mesh, quiver_bronze_mesh, quiver_iron_mesh]:
		if q != null:
			q.visible = false
	if cape_blue_mesh != null:
		cape_blue_mesh.visible = back_id.begins_with("cape_")
	if backpack_large_mesh != null:
		backpack_large_mesh.visible = back_id.begins_with("backpack_") or back_id.find("backpack") >= 0
	match back_id:
		"quiver_common":
			if quiver_common_mesh != null:
				quiver_common_mesh.visible = true
		"quiver_bronze":
			if quiver_bronze_mesh != null:
				quiver_bronze_mesh.visible = true
		"quiver_iron":
			if quiver_iron_mesh != null:
				quiver_iron_mesh.visible = true
		_:
			if back_id.begins_with("quiver_") and quiver_common_mesh != null:
				quiver_common_mesh.visible = true


func _set_base_outfit_visibility(show_chest: bool, show_legs: bool) -> void:
	if clothing_root != null:
		clothing_root.visible = show_chest or show_legs
	if shirt_green_mesh != null:
		shirt_green_mesh.visible = show_chest
	if shirt_yellow_mesh != null:
		shirt_yellow_mesh.visible = show_chest
	if pants_green_mesh != null:
		pants_green_mesh.visible = show_legs
	if pants_yellow_mesh != null:
		pants_yellow_mesh.visible = show_legs
	if base_body_mesh != null:
		base_body_mesh.visible = show_chest
	if base_arm_left_mesh != null:
		base_arm_left_mesh.visible = show_chest
	if base_arm_right_mesh != null:
		base_arm_right_mesh.visible = show_chest
	if base_leg_left_mesh != null:
		base_leg_left_mesh.visible = show_legs
	if base_leg_right_mesh != null:
		base_leg_right_mesh.visible = show_legs


func _show_equipped_weapon_mesh() -> void:
	if equipped_weapon_root == null and equipped_weapon_left_root == null:
		return
	if equipped_weapon_root != null:
		equipped_weapon_root.visible = true
	if equipped_weapon_left_root != null:
		equipped_weapon_left_root.visible = false
	match _weapon_mesh_item_id():
		"dagger_bronze":
			if dagger_bronze_mesh != null:
				dagger_bronze_mesh.visible = true
		"sword_1h_wooden":
			if sword_wooden_mesh != null:
				sword_wooden_mesh.visible = true
		"sword_1h_bronze":
			_show_short_sword_variant(0)
		"sword_1h_iron":
			_show_short_sword_variant(1)
		"sword_1h_steel":
			_show_short_sword_variant(2)
		"sword_1h_mithril":
			_show_short_sword_variant(3)
		"sword_1h_adamant":
			_show_short_sword_variant(4)
		"sword_1h_rune":
			_show_short_sword_variant(5)
		"sword_1h_dragon":
			_show_short_sword_variant(6)
		"bow_short_common":
			if equipped_weapon_root != null:
				equipped_weapon_root.visible = false
			if equipped_weapon_left_root != null:
				equipped_weapon_left_root.visible = true
			if bow_short_left_mesh != null:
				bow_short_left_mesh.visible = true
		"bow_long_common":
			if equipped_weapon_root != null:
				equipped_weapon_root.visible = false
			if equipped_weapon_left_root != null:
				equipped_weapon_left_root.visible = true
			if bow_long_left_mesh != null:
				bow_long_left_mesh.visible = true
		_:
			if equipped_weapon_root != null:
				equipped_weapon_root.visible = false


func _show_short_sword_variant(idx: int) -> void:
	if idx < 0 or idx >= sword_short_mesh_variants.size():
		return
	var n: Node3D = sword_short_mesh_variants[idx]
	if n != null:
		n.visible = true


func _armor_tier_from_item_id(item_id: String, prefix: String) -> String:
	if item_id.begins_with(prefix):
		return item_id.trim_prefix(prefix)
	return ""


func _tier_to_node_suffix(tier: String) -> String:
	if tier.is_empty():
		return ""
	return tier.substr(0, 1).to_upper() + tier.substr(1)


func _set_node3d_tree_visible(root: Node, enabled: bool, include_root: bool = true) -> void:
	if root == null:
		return
	if include_root and root is Node3D:
		(root as Node3D).visible = enabled
	for c in root.get_children():
		if c is Node3D:
			(c as Node3D).visible = enabled
		_set_node3d_tree_visible(c, enabled, false)


func _set_ancestor_visible_until(start: Node, stop_parent: Node) -> void:
	var n := start
	while n != null and n != stop_parent:
		if n is Node3D:
			(n as Node3D).visible = true
		n = n.get_parent()
	if stop_parent is Node3D:
		(stop_parent as Node3D).visible = true
