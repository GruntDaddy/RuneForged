extends Area3D

const _InventoryService = preload("res://autoload/inventory_service.gd")

@export var resource_type: String = "wood"


#region agent log
func _agent_log(run_id: String, hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	var payload := {
		"sessionId": "c5ea88",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000
	}
	var path := "c:/Users/price/Desktop/Game Creation/3D Projects/rune_forged/debug-c5ea88.log"
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		path = ProjectSettings.globalize_path("res://debug-c5ea88.log")
		f = FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.close()
	var req := HTTPRequest.new()
	add_child(req)
	req.request(
		"http://127.0.0.1:7780/ingest/aa3393c7-0b4c-4042-9eeb-84c344b7ef69",
		["Content-Type: application/json", "X-Debug-Session-Id: c5ea88"],
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
#endregion


func _ready() -> void:
	var on_gather := Callable(self, "_on_body_entered")
	if not body_entered.is_connected(on_gather):
		body_entered.connect(on_gather)


func _on_body_entered(body: Node3D) -> void:
	#region agent log
	_agent_log(
		"initial",
		"H2",
		"resource_pickup.gd:_on_body_entered",
		"Pickup overlapped body",
		{
			"resourceType": resource_type,
			"bodyName": body.name,
			"isPlayerGroup": body.is_in_group("player"),
			"pickupLayer": collision_layer,
			"pickupMask": collision_mask
		}
	)
	#endregion
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
		#region agent log
		_agent_log(
			"initial",
			"H2",
			"resource_pickup.gd:_on_body_entered",
			"Pickup added to inventory",
			{"resourceType": resource_type}
		)
		#endregion
	queue_free()
