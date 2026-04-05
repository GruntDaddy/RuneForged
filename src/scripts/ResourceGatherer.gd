extends Area3D

const _InventoryService = preload("res://autoload/inventory_service.gd")

@export var resource_type: String = ""


func _enter_tree() -> void:
	# Runs every time this node enters the tree (including after reparent / re-add). Idempotent:
	# if you already connected body_entered → _on_body_entered in the editor, this does nothing.
	var on_gather := Callable(self, "_on_body_entered")
	if not body_entered.is_connected(on_gather):
		body_entered.connect(on_gather)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	print("Gathering ", resource_type)
	var inv := get_node_or_null("/root/InventoryService")
	if inv is _InventoryService:
		(inv as _InventoryService).add_item(resource_type, 1)
	queue_free()
