extends Node

## Slot-based inventory for UI drag/drop. Aggregates counts for simple queries.

signal inventory_changed

const SLOT_COUNT := 16
const MAX_STACK := 99

const PICKUP_SCENES := {
	"logs": preload("res://world/props/resource_pickup_logs.tscn"),
	"oak_logs": preload("res://world/props/resource_pickup_logs_oak.tscn"),
	"stone": preload("res://world/props/resource_pickup_stone.tscn"),
	"tin_ore": preload("res://world/props/resource_pickup_stone.tscn"),
}


func get_item_display_name(item_id: String) -> String:
	match item_id:
		"logs", "wood":
			return "Logs"
		"oak_logs":
			return "Oak logs"
		"stone":
			return "Stone"
		"tin_ore":
			return "Tin ore"
		_:
			if item_id.is_empty():
				return ""
			return item_id.replace("_", " ").capitalize()

## Each entry: null or { "id": String, "count": int }
var slots: Array = []


func _ready() -> void:
	slots.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		slots[i] = null


func add_item(item_name: String, quantity: int = 1) -> int:
	var left: int = quantity
	# Stack into existing piles first
	for i in SLOT_COUNT:
		if left <= 0:
			break
		var s: Variant = slots[i]
		if s == null:
			continue
		if s["id"] != item_name:
			continue
		var c: int = int(s["count"])
		var room: int = MAX_STACK - c
		if room <= 0:
			continue
		var add: int = mini(left, room)
		slots[i] = {"id": item_name, "count": c + add}
		left -= add
	if left > 0:
		for i in SLOT_COUNT:
			if left <= 0:
				break
			if slots[i] != null:
				continue
			var add: int = mini(left, MAX_STACK)
			slots[i] = {"id": item_name, "count": add}
			left -= add
	inventory_changed.emit()
	return left


func remove_item(item_name: String, quantity: int = 1) -> void:
	var left: int = quantity
	for i in SLOT_COUNT:
		if left <= 0:
			break
		var s: Variant = slots[i]
		if s == null or s["id"] != item_name:
			continue
		var c: int = int(s["count"])
		var take: int = mini(left, c)
		var nc: int = c - take
		left -= take
		if nc <= 0:
			slots[i] = null
		else:
			slots[i] = {"id": item_name, "count": nc}
	inventory_changed.emit()


func get_items_copy() -> Dictionary:
	var out := {}
	for i in SLOT_COUNT:
		var s: Variant = slots[i]
		if s == null:
			continue
		var id: String = s["id"]
		var c: int = int(s["count"])
		if id in out:
			out[id] = int(out[id]) + c
		else:
			out[id] = c
	return out


func has_item(item_name: String) -> bool:
	return get_item_count(item_name) > 0


func get_item_count(item_name: String) -> int:
	var n := 0
	for i in SLOT_COUNT:
		var s: Variant = slots[i]
		if s != null and s["id"] == item_name:
			n += int(s["count"])
	return n


func get_slot_data(index: int) -> Variant:
	if index < 0 or index >= SLOT_COUNT:
		return null
	return slots[index]


func move_or_merge(from_idx: int, to_idx: int) -> void:
	if from_idx == to_idx:
		return
	if from_idx < 0 or from_idx >= SLOT_COUNT:
		return
	if to_idx < 0 or to_idx >= SLOT_COUNT:
		return
	var a: Variant = slots[from_idx]
	if a == null:
		return
	var b: Variant = slots[to_idx]
	if b == null:
		slots[to_idx] = (a as Dictionary).duplicate()
		slots[from_idx] = null
		inventory_changed.emit()
		return
	if b["id"] == a["id"]:
		var room: int = MAX_STACK - int(b["count"])
		if room <= 0:
			return
		var move_amt: int = mini(int(a["count"]), room)
		b["count"] = int(b["count"]) + move_amt
		a["count"] = int(a["count"]) - move_amt
		if int(a["count"]) <= 0:
			slots[from_idx] = null
		else:
			slots[from_idx] = a
		slots[to_idx] = b
		inventory_changed.emit()
		return
	# Swap different items
	var tmp: Variant = slots[to_idx]
	slots[to_idx] = slots[from_idx]
	slots[from_idx] = tmp
	inventory_changed.emit()


func drop_slot_to_world(slot_idx: int, drop_global_position: Vector3, world_parent: Node) -> void:
	if slot_idx < 0 or slot_idx >= SLOT_COUNT:
		return
	var s: Variant = slots[slot_idx]
	if s == null:
		return
	var id: String = s["id"]
	var count: int = int(s["count"])
	slots[slot_idx] = null
	inventory_changed.emit()
	var scene: PackedScene = PICKUP_SCENES.get(id, null)
	if scene == null:
		push_warning("inventory_service: no pickup scene for '%s'" % id)
		return
	var node := scene.instantiate()
	if node == null:
		return
	world_parent.add_child(node)
	if node is Node3D:
		(node as Node3D).global_position = drop_global_position
	if node.has_method("set_resource_type"):
		node.set_resource_type(id)
	elif "resource_type" in node:
		node.resource_type = id
	if node.has_method("set_quantity"):
		node.set_quantity(count)
	elif "quantity" in node:
		node.quantity = count


func get_save_dict() -> Dictionary:
	var arr: Array = []
	for i in SLOT_COUNT:
		var s: Variant = slots[i]
		if s == null:
			arr.append(null)
		else:
			arr.append({"id": str(s["id"]), "count": int(s["count"])})
	return {"slots": arr}


func apply_save_dict(d: Variant) -> void:
	if typeof(d) != TYPE_DICTIONARY:
		return
	var arr: Variant = d.get("slots", [])
	if typeof(arr) != TYPE_ARRAY:
		clear_all_slots()
		return
	for i in SLOT_COUNT:
		if i >= arr.size():
			slots[i] = null
			continue
		var entry: Variant = arr[i]
		if entry == null or typeof(entry) != TYPE_DICTIONARY:
			slots[i] = null
			continue
		var id := str(entry.get("id", ""))
		if id == "wood":
			id = "logs"
		var c := int(entry.get("count", 0))
		if id.is_empty() or c < 1:
			slots[i] = null
		else:
			slots[i] = {"id": id, "count": mini(c, MAX_STACK)}
	inventory_changed.emit()


func clear_all_slots() -> void:
	for i in SLOT_COUNT:
		slots[i] = null
	inventory_changed.emit()
