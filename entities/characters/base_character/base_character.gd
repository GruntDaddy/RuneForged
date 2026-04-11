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
}

@onready var skeleton: Skeleton3D = $Rig_Medium/Skeleton3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

@onready var hand_r_slot: BoneAttachment3D = $Rig_Medium/Skeleton3D/HandAttach_R
@onready var hand_l_slot: BoneAttachment3D = $Rig_Medium/Skeleton3D/HandAttach_L
@onready var head_slot: BoneAttachment3D = $Rig_Medium/Skeleton3D/Head_Slot
@onready var chest_slot: BoneAttachment3D = $Rig_Medium/Skeleton3D/Chest_Slot
@onready var legs_slot: BoneAttachment3D = $Rig_Medium/Skeleton3D/Legs_Slot
@onready var back_slot: BoneAttachment3D = $Rig_Medium/Skeleton3D/Back_Slot

@onready var equipped_tool_root: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight
@onready var axe_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight/Hatchet_Basic
@onready var pickaxe_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight/Pickaxe_Basic
@onready var fishing_pole_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_R/EquippedToolRight/Fishing_Pole
@onready var tacklebox_hand_mesh: Node3D = $Rig_Medium/Skeleton3D/HandAttach_L/EquippedToolLeft/Tool_Tacklebox
@onready var tacklebox_back_mesh: Node3D = $Rig_Medium/Skeleton3D/Back_Slot/Tool_Tacklebox_Back

## Order matches cycling in the character creator; one head visible at a time.
var _head_paths: Array[String] = [
	"Rig_Medium/Head_M-W_01_R",
	"Rig_Medium/Ranger_Head",
	"Rig_Medium/Mage_Head_F_Red",
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

var _action_state: ActionState = ActionState.LOCOMOTION
## Player-selected tool (keys 1–4). Swings temporarily show axe/pickaxe to match the clip, then this is restored.
var _player_chosen_tool: ToolKind = ToolKind.AXE
## When using FISHING_ROD, show tacklebox on back only if true (e.g. player owns `tool_tacklebox`).
var _show_tacklebox_on_back: bool = true


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

	_apply_tool_kind(_player_chosen_tool)


func _anim_path(clip: String) -> StringName:
	return StringName("%s/%s" % [_ANIM_LIB, clip])


func set_locomotion_state(moving: bool, running: bool, on_floor: bool) -> void:
	if anim_player == null:
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
	if _action_state != ActionState.TOOL_ACTION:
		return
	var s := String(anim_name)
	if not s.begins_with(_ANIM_LIB + "/"):
		return
	_action_state = ActionState.LOCOMOTION
	_apply_tool_kind(_player_chosen_tool)


func _apply_tool_kind(kind: ToolKind) -> void:
	if axe_mesh != null:
		axe_mesh.visible = kind == ToolKind.AXE
	if pickaxe_mesh != null:
		pickaxe_mesh.visible = kind == ToolKind.PICKAXE
	if fishing_pole_mesh != null:
		fishing_pole_mesh.visible = kind == ToolKind.FISHING_ROD
	if equipped_tool_root != null:
		equipped_tool_root.visible = kind != ToolKind.NONE
	if tacklebox_hand_mesh != null:
		tacklebox_hand_mesh.visible = false
	if tacklebox_back_mesh != null:
		tacklebox_back_mesh.visible = kind == ToolKind.FISHING_ROD and _show_tacklebox_on_back


## When the active tool is the fishing rod, controls whether the back tacklebox mesh is shown (e.g. inventory has `tool_tacklebox`).
func set_tacklebox_back_display_enabled(enabled: bool) -> void:
	_show_tacklebox_on_back = enabled
	if _action_state == ActionState.LOCOMOTION:
		_apply_tool_kind(_player_chosen_tool)


## Player tool selection (keys 1–4): updates which KayKit mesh is shown when idle.
func set_active_tool(kind: ToolKind) -> void:
	_player_chosen_tool = kind
	if _action_state == ActionState.LOCOMOTION:
		_apply_tool_kind(kind)


func is_tool_action_active() -> bool:
	return _action_state == ActionState.TOOL_ACTION


## Stops the current tool clip (e.g. target destroyed mid-swing) and returns to idle + chosen tool mesh.
func cancel_tool_action() -> void:
	_action_state = ActionState.LOCOMOTION
	if anim_player != null:
		anim_player.stop()
		if anim_player.has_animation(_anim_path(_ANIM_IDLE)):
			anim_player.play(_anim_path(_ANIM_IDLE), 0.12)
	_apply_tool_kind(_player_chosen_tool)


## Plays a one-shot survival/tool clip. Returns false if a tool action is already playing.
func try_play_action_for_harvest(harvest_action: String) -> bool:
	if anim_player == null:
		return false
	if _action_state == ActionState.TOOL_ACTION:
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

	var shirt_col: Color = SHIRT_TINTS[posmod(shirt_idx, SHIRT_TINTS.size())]
	var pants_col: Color = PANTS_TINTS[posmod(pants_idx, PANTS_TINTS.size())]

	for p in [
		"Rig_Medium/Base_Body",
		"Rig_Medium/Base_ArmLeft",
		"Rig_Medium/Base_ArmRight",
	]:
		_tint_mesh_surfaces(get_node_or_null(p) as MeshInstance3D, shirt_col)
	for p in ["Rig_Medium/Base_LegLeft", "Rig_Medium/Base_LegRight"]:
		_tint_mesh_surfaces(get_node_or_null(p) as MeshInstance3D, pants_col)


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
