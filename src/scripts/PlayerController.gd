extends CharacterBody3D

@export var speed: float = 400.0
@export var jump_velocity: float = -800.0

func _physics_process(delta):
	velocity.x = lerp(velocity.x, Input.get_axis("left", "right") * speed, delta)
	
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		
	move_and_slide()
