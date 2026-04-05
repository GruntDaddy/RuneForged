extends Node3D

@export var rotation_speed: float = 15.0
@export var float_height: float = 0.08
@export var float_speed: float = 2.0

@onready var player: CharacterBody3D = get_node_or_null("Player")

var _base_y: float


func _ready() -> void:
	_base_y = position.y

	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)
	else:
		push_warning("PreviewRoot: Player node not found or missing set_input_enabled().")


func _process(delta: float) -> void:
	rotate_y(deg_to_rad(rotation_speed * delta))

	var t := Time.get_ticks_msec() * 0.001
	position.y = _base_y + sin(t * float_speed) * float_height
