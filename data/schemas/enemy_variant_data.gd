extends Resource
class_name EnemyVariantData

const _EnemyBehaviorProfile = preload("res://data/schemas/enemy_behavior_profile.gd")
const _EnemyDropProfile = preload("res://data/schemas/enemy_drop_profile.gd")

@export var variant_id: String = ""
@export var display_name: String = ""
@export var visual_scene: PackedScene

@export_range(1.0, 10000.0, 0.1) var max_health: float = 30.0
@export_range(0.1, 50.0, 0.1) var move_speed: float = 2.2
@export_range(0.1, 1000.0, 0.1) var attack_damage: float = 6.0
@export_range(0.0, 10000.0, 1.0) var xp_value: float = 8.0

@export var behavior_profile: _EnemyBehaviorProfile
@export var drop_profile: _EnemyDropProfile

@export var projectile_scene: PackedScene
@export_range(0.1, 200.0, 0.1) var projectile_speed: float = 20.0
@export_range(0.1, 30.0, 0.1) var projectile_lifetime: float = 6.0
