extends Area3D

@export var resource_type: String = ""

func _on_body_entered(body):
	if body.is_in_group("player"):
		# Trigger collection animation or effect
		print("Gathering", resource_type)
		
		# Add to inventory [2]
		InventoryService.add_item(resource_type, 1) 
		
		# Disable gathering after collection
		self.queue_free()
