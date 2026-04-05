extends Node

@export var max_health: int = 100
var current_health: int = max_health

func take_damage(amount):
	current_health -= amount
	if current_health <= 0:
		queue_free()

# Optional regeneration while falling
func _process(delta):
	if current_health < max_health and not is_on_floor():
		current_health += delta * 2.5 
