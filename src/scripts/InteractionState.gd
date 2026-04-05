extends Area3D

func _on_body_entered(body):
	if body.is_in_group("player"):
		# Show interaction prompt in UI
		print("Interact with", name)

func _on_body_exited(body):
	# Hide interaction prompt
	print("Interaction ended")
