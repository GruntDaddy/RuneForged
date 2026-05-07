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
@export_range(0.05, 2.0, 0.01) var ranged_draw_time_sec: float = 0.38
@export_range(0.0, 2.0, 0.01) var ranged_hold_time_sec: float = 0.16
@export_range(0.05, 2.0, 0.01) var ranged_recover_time_sec: float = 0.34
@export_range(0.0, 1.0, 0.01) var hit_react_chance: float = 1.0
@export_range(0.0, 1.0, 0.01) var hit_interrupt_attack_chance: float = 0.18
@export_range(0.05, 1.5, 0.01) var hit_react_duration_sec: float = 0.22
