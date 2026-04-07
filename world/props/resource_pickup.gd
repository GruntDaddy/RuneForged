extends Area3D

const _InventoryService = preload("res://autoload/inventory_service.gd")

@export var resource_type: String = "wood"


func _ready() -> void:
	var on_gather := Callable(self, "_on_body_entered")
	if not body_entered.is_connected(on_gather):
		body_entered.connect(on_gather)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var inv := get_node_or_null("/root/InventoryService")
	if inv == null:
		push_error(
			"resource_pickup: /root/InventoryService missing — lost pickup: %s (%s)"
			% [resource_type, get_path()]
		)
	elif not (inv is _InventoryService):
		var scr: Variant = inv.get_script()
		var detail: String
		if scr is Resource:
			detail = (scr as Resource).resource_path
		elif scr != null:
			detail = str(scr)
		else:
			detail = inv.get_class()
		push_error(
			"resource_pickup: InventoryService type mismatch (got %s). Lost: %s (%s)"
			% [detail, resource_type, get_path()]
		)
	else:
		(inv as _InventoryService).add_item(resource_type, 1)
	queue_free()
