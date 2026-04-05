extends Node3D

@onready var skeleton: Skeleton3D = $Rig_Medium/Skeleton3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

@onready var hand_r_slot: BoneAttachment3D = $Rig_Medium/Skeleton3D/HandAttach_R
@onready var hand_l_slot: BoneAttachment3D = $Rig_Medium/Skeleton3D/HandAttach_L
@onready var head_slot:    BoneAttachment3D = $Rig_Medium/Skeleton3D/Head_Slot
@onready var chest_slot:   BoneAttachment3D = $Rig_Medium/Skeleton3D/Chest_Slot
@onready var legs_slot:    BoneAttachment3D = $Rig_Medium/Skeleton3D/Legs_Slot
@onready var back_slot:    BoneAttachment3D = $Rig_Medium/Skeleton3D/Back_Slot

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

## Animation library name in base_character.tscn is "Base".
const _ANIM_LIB := "Base"
const _ANIM_WALK := "Walking_B"
const _ANIM_IDLE := "T-Pose"
const _ANIM_AIR := "Jump_Idle"


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

	if anim_player and anim_player.has_animation(_anim_path(_ANIM_IDLE)):
		anim_player.play(_anim_path(_ANIM_IDLE))


func _anim_path(clip: String) -> StringName:
	return StringName("%s/%s" % [_ANIM_LIB, clip])


func set_locomotion_state(moving: bool, running: bool, on_floor: bool) -> void:
	if anim_player == null:
		return
	if not on_floor:
		_play_if_needed(_ANIM_AIR, 0.12)
		return
	if moving:
		_play_if_needed(_ANIM_WALK, 0.12)
		anim_player.speed_scale = 1.28 if running else 1.0
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
## Prefer get_active_material (includes overrides from instanced mesh scenes). Stronger tint for textured albedo.
func _tint_mesh_surfaces(mi: MeshInstance3D, tint: Color) -> void:
	if mi == null or mi.mesh == null:
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
		# Multiply + slight lerp toward tint so colors read on busy texture sheets.
		var mixed: Color = bm.albedo_color * tint
		bm.albedo_color = mixed.lerp(tint, 0.22)
		mi.set_surface_override_material(surf_idx, dup)
