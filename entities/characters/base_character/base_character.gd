class_name BaseCharacter
extends Node3D

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
}

@onready var skeleton: Skeleton3D = $Rig_Medium/Skeleton3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

@onready var hand_r_slot: BoneAttachment3D = $Rig_Medium/Skeleton3D/HandAttach_R
@onready var hand_l_slot: BoneAttachment3D = $Rig_Medium/Skeleton3D/HandAttach_L
@onready var head_slot: BoneAttachment3D = get_node_or_null("Rig_Medium/Skeleton3D/Head_Slot") as BoneAttachment3D
@onready var chest_slot: BoneAttachment3D = get_node_or_null("Rig_Medium/Skeleton3D/Chest_Slot") as BoneAttachment3D
@onready var legs_slot: BoneAttachment3D = get_node_or_null("Rig_Medium/Skeleton3D/Legs_Slot") as BoneAttachment3D
@onready var back_slot: BoneAttachment3D = get_node_or_null("Rig_Medium/Skeleton3D/Back_Slot") as BoneAttachment3D

@onready var equipped_tool_root: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight
@onready var axe_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight/Hatchet_Basic
@onready var axe_bronze_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight/Hatchet_Bronze
@onready var pickaxe_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight/Pickaxe_Basic
@onready var pickaxe_bronze_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight/Pickaxe_Bronze
@onready var fishing_pole_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight/Fishing_Pole
@onready var hammer_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight/Hammer_Common
@onready var equipped_weapon_root: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight
@onready var dagger_bronze_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight/Dagger_Bronze
@onready var sword_wooden_mesh: Node3D = get_node_or_null(
	"Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight/1h_Sword_Wooden"
) as Node3D
@onready var sword_bronze_mesh: Node3D = get_node_or_null(
	"Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight/1h_Katana_Bronze"
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
@onready var bow_short_mesh: Node3D = get_node_or_null(
	"Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight/Bow_Short_Common"
) as Node3D
@onready var bow_long_mesh: Node3D = get_node_or_null(
	"Rig_Medium/Skeleton3D/HandAttach_R/EquippedWeaponRight/Bow_Long_Common"
) as Node3D
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
const _ANIM_CHOP := "Chop"
const _ANIM_PICKAXE := "Pickaxe"
const _ANIM_INTERACT := "Interact"
const _ANIM_PICKUP := "PickUp"
const _ANIM_USE_ITEM := "Use_Item"
## Combat clips are authored under `Base/` in AnimationLibrary (may alias survival poses until sword/block/bow slices ship).
const _ANIM_MELEE_1H := "Melee_Attack_1H"
const _ANIM_BLOCK_LOOP := "Shield_Block_Loop"
const _ANIM_BOW_DRAW := "Bow_Draw"
const _ANIM_BOW_RELEASE := "Bow_Release"
const _ANIM_UNARMED_PUNCH := "Melee_Unarmed_Attack_Punch_A"
const _ANIM_UNARMED_KICK := "Melee_Unarmed_Attack_Kick"

var _action_state: ActionState = ActionState.LOCOMOTION
## Player-selected tool (keys 1–4). Swings temporarily show axe/pickaxe to match the clip, then this is restored.
var _player_chosen_tool: ToolKind = ToolKind.NONE
var _equipped_main_hand_item_id: String = ""
var _equipped_off_hand_item_id: String = ""
var _equipped_head_item_id: String = ""
var _equipped_chest_item_id: String = ""
var _equipped_legs_item_id: String = ""

var _block_hold_active: bool = false
## 0 idle, 1 draw playing, 2 fully drawn (held pose), 3 release playing.
var _bow_phase: int = 0
var _next_unarmed_kick: bool = false


func _ready() -> void:
	if skeleton == null:
		push_warning("BaseCharacter: Skeleton3D not found at Rig_Medium/Skeleton3D.")

	if hand_r_slot == null:
		push_warning("BaseCharacter: HandAttach_R not found.")
	if hand_l_slot == null:
		push_warning("BaseCharacter: HandAttach_L not found.")
	if head_slot == null:
		push_warning("BaseCharacter: Head_Slot not found.")
	if chest_slot == null:
		push_warning("BaseCharacter: Chest_Slot not found.")
	if legs_slot == null:
		push_warning("BaseCharacter: Legs_Slot not found.")
	if back_slot == null:
		push_warning("BaseCharacter: Back_Slot not found.")

	if anim_player:
		if not anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.connect(_on_animation_finished)

	if anim_player and anim_player.has_animation(_anim_path(_ANIM_IDLE)):
		anim_player.play(_anim_path(_ANIM_IDLE))

	_disable_equipped_tool_colliders()
	_rebind_equipment_mesh_skeleton_paths()
	_apply_armor_visibility()
	_apply_tool_kind(_player_chosen_tool)


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


func _on_animation_finished(anim_name: StringName) -> void:
	var s := String(anim_name)
	if not s.begins_with(_ANIM_LIB + "/"):
		return
	var clip_name := s.substr(_ANIM_LIB.length() + 1, s.length())

	if _bow_phase == 1 and clip_name == _ANIM_BOW_DRAW:
		_bow_phase = 2
		return

	if _action_state == ActionState.COMBAT_ACTION and _bow_phase == 3 and clip_name == _ANIM_BOW_RELEASE:
		_bow_phase = 0
		_action_state = ActionState.LOCOMOTION
		_apply_tool_kind(_player_chosen_tool)
		return

	if _action_state == ActionState.COMBAT_ACTION and clip_name == _ANIM_MELEE_1H:
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


func set_equipped_armor_items(head_item_id: String, chest_item_id: String, legs_item_id: String) -> void:
	_equipped_head_item_id = head_item_id
	_equipped_chest_item_id = chest_item_id
	_equipped_legs_item_id = legs_item_id
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
	if _action_state == ActionState.TOOL_ACTION or _action_state == ActionState.COMBAT_ACTION:
		return true
	if _block_hold_active:
		return true
	if _bow_phase > 0:
		return true
	return false


## Movement can continue while shield blocking; this excludes block-hold from hard lock checks.
func is_movement_locked() -> bool:
	if _action_state == ActionState.TOOL_ACTION or _action_state == ActionState.COMBAT_ACTION:
		return true
	if _bow_phase > 0:
		return true
	return false


func is_blocking() -> bool:
	return _block_hold_active


func is_bow_drawn_or_drawing() -> bool:
	return _bow_phase > 0


## Stops the current tool clip (e.g. target destroyed mid-swing) and returns to idle + chosen tool mesh.
func cancel_tool_action() -> void:
	_block_hold_active = false
	_bow_phase = 0
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
	if wanted and (_action_state == ActionState.TOOL_ACTION or _action_state == ActionState.COMBAT_ACTION):
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
	var attack_clip := _ANIM_MELEE_1H
	if _equipped_main_hand_item_id.is_empty():
		attack_clip = _ANIM_UNARMED_KICK if _next_unarmed_kick else _ANIM_UNARMED_PUNCH
		_next_unarmed_kick = not _next_unarmed_kick
	var path := _anim_path(attack_clip)
	if not anim_player.has_animation(path):
		if attack_clip != _ANIM_MELEE_1H:
			path = _anim_path(_ANIM_MELEE_1H)
	if not anim_player.has_animation(path):
		return false
	_action_state = ActionState.COMBAT_ACTION
	_apply_weapon_visual_for_attack()
	anim_player.speed_scale = 1.0
	anim_player.play(path, 0.12)
	return true


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
	return head_slot


func get_chest_slot() -> BoneAttachment3D:
	return chest_slot


func get_legs_slot() -> BoneAttachment3D:
	return legs_slot


func get_back_slot() -> BoneAttachment3D:
	return back_slot


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
	for id in ids:
		if _equipped_main_hand_item_id == id:
			if id.find("bronze") >= 0:
				if primary != null:
					primary.visible = true
			else:
				if fallback != null:
					fallback.visible = true
			return


func _set_right_hand_meshes_visible(enabled: bool) -> void:
	for n in [axe_mesh, axe_bronze_mesh, pickaxe_mesh, pickaxe_bronze_mesh, fishing_pole_mesh, hammer_mesh]:
		if n != null:
			n.visible = enabled


func _set_weapon_meshes_visible(enabled: bool) -> void:
	if equipped_weapon_root != null:
		equipped_weapon_root.visible = enabled
	for n in [dagger_bronze_mesh, sword_wooden_mesh, sword_bronze_mesh]:
		if n != null:
			n.visible = enabled
	for n in sword_short_mesh_variants:
		if n != null:
			n.visible = enabled
	if bow_short_mesh != null:
		bow_short_mesh.visible = enabled
	if bow_long_mesh != null:
		bow_long_mesh.visible = enabled


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
	match id:
		"torch":
			return "tool_torch"
		"hammer":
			return "tool_hammer"
		"chisel":
			return "tool_chisel"
		"oak_logs":
			return "logs_oak"
		_:
			return id


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
	if equipped_weapon_root == null:
		return
	equipped_weapon_root.visible = true
	match _equipped_main_hand_item_id:
		"dagger_bronze":
			if dagger_bronze_mesh != null:
				dagger_bronze_mesh.visible = true
		"sword_1h_wooden":
			if sword_wooden_mesh != null:
				sword_wooden_mesh.visible = true
		"sword_1h_bronze":
			if sword_bronze_mesh != null:
				sword_bronze_mesh.visible = true
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
			if bow_short_mesh != null:
				bow_short_mesh.visible = true
		"bow_long_common":
			if bow_long_mesh != null:
				bow_long_mesh.visible = true
		_:
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
