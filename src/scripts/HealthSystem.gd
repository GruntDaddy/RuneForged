extends Node

@export var max_health: int = 100
var current_health: int = max_health

var _regen_accumulator: float = 0.0


func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		queue_free()


# Optional regeneration while airborne. Resolves CharacterBody3D whether this script is on the body
# or on a child Node (original pattern assumed is_on_floor() on self == body).
func _process(delta: float) -> void:
	if current_health >= max_health:
		return
	var body: CharacterBody3D = _resolve_character_body()
	if body == null:
		_regen_accumulator = 0.0
		return
	if body.is_on_floor():
		_regen_accumulator = 0.0
		return
	_regen_accumulator += delta * 2.5
	while _regen_accumulator >= 1.0 and current_health < max_health:
		current_health += 1
		_regen_accumulator -= 1.0


func _resolve_character_body() -> CharacterBody3D:
	var here := self as Node
	if here is CharacterBody3D:
		return here as CharacterBody3D
	var p := get_parent()
	if p is CharacterBody3D:
		return p as CharacterBody3D
	return null
