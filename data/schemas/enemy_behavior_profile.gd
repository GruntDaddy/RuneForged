extends Resource
class_name EnemyBehaviorProfile

@export_range(0.1, 200.0, 0.1) var aggro_range: float = 12.0
@export_range(0.1, 200.0, 0.1) var leash_range: float = 24.0
@export_range(0.1, 20.0, 0.1) var attack_range: float = 1.8
@export_range(0.1, 20.0, 0.1) var preferred_range: float = 1.2
@export_range(0.1, 10.0, 0.05) var attack_cooldown: float = 1.4
@export_range(0.1, 50.0, 0.1) var patrol_radius: float = 6.0
@export_range(0.1, 20.0, 0.1) var return_stop_distance: float = 1.4
@export var uses_ranged_attacks: bool = false
