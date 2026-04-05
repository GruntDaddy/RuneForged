extends Area3D

const _InventoryService = preload("res://autoload/inventory_service.gd")

@export var resource_type: String = ""


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	print("Gathering ", resource_type)
	var inv := get_node_or_null("/root/InventoryService")
	if inv is _InventoryService:
		(inv as _InventoryService).add_item(resource_type, 1)
	queue_free()
