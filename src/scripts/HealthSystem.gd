extends Node

@export var max_health: int = 100
var current_health: int = max_health

var _regen_accumulator: float = 0.0


func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		queue_free()


# Optional regeneration while airborn (parent must be CharacterBody3D).
func _process(delta: float) -> void:
	if current_health >= max_health:
		return
	var parent := get_parent()
	if parent is not CharacterBody3D:
		_regen_accumulator = 0.0
		return
	if (parent as CharacterBody3D).is_on_floor():
		_regen_accumulator = 0.0
		return
	_regen_accumulator += delta * 2.5
	while _regen_accumulator >= 1.0 and current_health < max_health:
		current_health += 1
		_regen_accumulator -= 1.0
