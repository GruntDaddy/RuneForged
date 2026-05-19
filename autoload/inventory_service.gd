extends Node

## Slot-based inventory for UI drag/drop. Slot dict: `id`, `count`, optional `tackle` for `tool_tacklebox`.

signal inventory_changed

const BASE_SLOT_COUNT := 28
## Largest backpack expansion; inventory array is always this wide for save stability.
const MAX_BACKPACK_EXTRA_SLOTS := 28
const SLOT_COUNT := BASE_SLOT_COUNT + MAX_BACKPACK_EXTRA_SLOTS
## When a `backpack_*` item has `ItemData.backpack_extra_slots` == 0, use this many extra slots.
const LEGACY_BACKPACK_EXTRA_SLOTS := 14
## Fallback when an item id is missing from ItemCatalog.
const MAX_STACK := 99

const TACKLEBOX_ID := "tool_tacklebox"
const TACKLE_HOOKS := 5
const TACKLE_BOBBERS := 5
const TACKLE_BAIT := 20

const TAG_FISHING_HOOK := "fishing_hook"
const TAG_FISHING_BOBBER := "fishing_bobber"
const TAG_FISHING_BAIT := "fishing_bait"
const BAIT_ITEM_ID := "tool_fishing_bait"
const WORM_ITEM_ID := "tool_fishing_worm"


## Hooks, bobbers, and bait belong in the tackle box — not on the equipment sheet.
func item_is_tackle_contents_only(item_id: String) -> bool:
	var nid := _normalize_item_id(item_id)
	var it: ItemData = ItemCatalog.get_item(nid)
	if it == null:
		return false
	for t in it.tags:
		var ts := str(t)
		if ts == TAG_FISHING_HOOK or ts == TAG_FISHING_BOBBER or ts == TAG_FISHING_BAIT:
			return true
	return false

const PICKUP_SCENES := {
	# Legacy aliases retained as a compatibility fallback.
	"oak_logs": preload("res://entities/resource/resource_pickup_logs_oak.tscn"),
	"tin_ore": preload("res://entities/resource/resource_pickup_stone.tscn"),
}

## Each entry: null or Dictionary with "id", "count", optional "tackle"
var slots: Array = []


func _ready() -> void:
	slots.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		slots[i] = null


func has_backpack_equipped() -> bool:
	var back_slot: Variant = GameState.equipment.get("back", null)
	if back_slot == null:
		return false
	var item_id := _normalize_item_id(str(back_slot.get("id", "")))
	if item_id.begins_with("backpack_"):
		return true
	var it: ItemData = ItemCatalog.get_item(item_id)
	if it == null:
		return false
	for tag in it.tags:
		if str(tag) == "backpack":
			return true
	return false


func get_equipped_backpack_extra_slots() -> int:
	if not has_backpack_equipped():
		return 0
	var back_slot: Variant = GameState.equipment.get("back", null)
	if back_slot == null:
		return 0
	var item_id := _normalize_item_id(str(back_slot.get("id", "")))
	var it: ItemData = ItemCatalog.get_item(item_id)
	if it != null and it.backpack_extra_slots > 0:
		return clampi(it.backpack_extra_slots, 1, MAX_BACKPACK_EXTRA_SLOTS)
	if item_id.begins_with("backpack_"):
		return LEGACY_BACKPACK_EXTRA_SLOTS
	return 0


func get_unlocked_slot_count() -> int:
	return BASE_SLOT_COUNT + get_equipped_backpack_extra_slots()


func is_slot_unlocked(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= SLOT_COUNT:
		return false
	return slot_idx < get_unlocked_slot_count()


func _stack_cap_for(item_id: String) -> int:
	var nid := _normalize_item_id(item_id)
	var it: ItemData = ItemCatalog.get_item(nid)
	if it == null:
		return MAX_STACK
	var cap := clampi(it.max_stack, 1, 9999)
	# Bait / hooks / bobbers use authored stack sizes (worm stacks; hooks stay 1).
	if item_is_tackle_contents_only(nid):
		return cap
	# Other equipment-like categories should not stack even if data says otherwise.
	if it.category in [
		ItemData.Category.TOOL,
		ItemData.Category.WEAPON,
		ItemData.Category.ARMOR,
		ItemData.Category.CLOTHING,
		ItemData.Category.JEWERLY,
		ItemData.Category.RELIC,
		ItemData.Category.RUNE,
	]:
		return 1
	return cap


func empty_tackle() -> Dictionary:
	var hooks: Array = []
	var bobbers: Array = []
	var bait: Array = []
	hooks.resize(TACKLE_HOOKS)
	bobbers.resize(TACKLE_BOBBERS)
	bait.resize(TACKLE_BAIT)
	for i in TACKLE_HOOKS:
		hooks[i] = null
	for i in TACKLE_BOBBERS:
		bobbers[i] = null
	for i in TACKLE_BAIT:
		bait[i] = null
	return {"hooks": hooks, "bobbers": bobbers, "bait": bait}


func _normalize_tackle(t: Variant) -> Dictionary:
	var out := empty_tackle()
	if typeof(t) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = t
	_copy_tackle_array(d.get("hooks", null), out["hooks"] as Array, TACKLE_HOOKS)
	_copy_tackle_array(d.get("bobbers", null), out["bobbers"] as Array, TACKLE_BOBBERS)
	_copy_tackle_array(d.get("bait", null), out["bait"] as Array, TACKLE_BAIT)
	return out


## Fills only empty tackle cells from `preset` (starter pickup / restock). Existing cells unchanged.
func _fill_empty_tackle_from_preset(existing_tackle: Variant, preset: Variant) -> Dictionary:
	var ex := _normalize_tackle(existing_tackle)
	if typeof(preset) != TYPE_DICTIONARY:
		return ex
	var pr := _normalize_tackle(preset)
	for cat_key in ["hooks", "bobbers", "bait"]:
		var ea: Array = ex[cat_key] as Array
		var pa: Array = pr[cat_key] as Array
		for i in ea.size():
			if ea[i] != null:
				continue
			if i >= pa.size():
				continue
			var pv: Variant = pa[i]
			if pv == null or typeof(pv) != TYPE_DICTIONARY:
				continue
			var cid := str(pv.get("id", ""))
			var cnt := int(pv.get("count", 0))
			if cid.is_empty() or cnt < 1:
				continue
			var cap := _stack_cap_for(cid)
			ea[i] = {"id": cid, "count": mini(cnt, cap)}
	return ex


func _copy_tackle_array(src: Variant, dst: Array, n: int) -> void:
	if typeof(src) != TYPE_ARRAY:
		return
	var a: Array = src
	for i in n:
		if i >= a.size():
			dst[i] = null
			continue
		var cell: Variant = a[i]
		if cell == null or typeof(cell) != TYPE_DICTIONARY:
			dst[i] = null
			continue
		var cid := str(cell.get("id", ""))
		var cc := int(cell.get("count", 0))
		if cid.is_empty() or cc < 1:
			dst[i] = null
		else:
			var cap := _stack_cap_for(cid)
			dst[i] = {"id": cid, "count": mini(cc, cap)}


func tackle_category_for_item(item_id: String) -> String:
	var nid := _normalize_item_id(item_id)
	var it: ItemData = ItemCatalog.get_item(nid)
	if it == null:
		return ""
	for t in it.tags:
		var ts := str(t)
		if ts == TAG_FISHING_HOOK:
			return "hooks"
		if ts == TAG_FISHING_BOBBER:
			return "bobbers"
		if ts == TAG_FISHING_BAIT:
			return "bait"
	return ""


func _tackle_array_for_category(tackle: Dictionary, category: String) -> Array:
	match category:
		"hooks":
			return tackle["hooks"] as Array
		"bobbers":
			return tackle["bobbers"] as Array
		"bait":
			return tackle["bait"] as Array
		_:
			return []


func _count_tackleboxes_in_grid() -> int:
	var n := 0
	for i in SLOT_COUNT:
		var s: Variant = slots[i]
		if s != null and str(s.get("id", "")) == TACKLEBOX_ID:
			n += int(s.get("count", 0))
	return n


func get_tackle_for_slot(slot_idx: int) -> Dictionary:
	if slot_idx < 0 or slot_idx >= SLOT_COUNT:
		return empty_tackle()
	var s: Variant = slots[slot_idx]
	if s == null or str(s.get("id", "")) != TACKLEBOX_ID:
		return empty_tackle()
	return _normalize_tackle(s.get("tackle", null))


## Moves items from a main inventory slot into the first empty (or merge) cell in the matching tackle category.
func deposit_to_tackle_first_empty(tackle_slot_idx: int, from_main_slot_idx: int) -> bool:
	if tackle_slot_idx < 0 or tackle_slot_idx >= SLOT_COUNT:
		return false
	if from_main_slot_idx < 0 or from_main_slot_idx >= SLOT_COUNT:
		return false
	var tb: Variant = slots[tackle_slot_idx]
	var src: Variant = slots[from_main_slot_idx]
	if tb == null or str(tb.get("id", "")) != TACKLEBOX_ID:
		return false
	if src == null:
		return false
	var item_id := _normalize_item_id(str(src["id"]))
	if item_id == TACKLEBOX_ID:
		return false
	var cat := tackle_category_for_item(item_id)
	if cat.is_empty():
		return false
	var tackle: Dictionary = _normalize_tackle(tb.get("tackle", null))
	var arr: Array = _tackle_array_for_category(tackle, cat)
	if arr.is_empty():
		return false
	var cap := _stack_cap_for(item_id)
	var count: int = int(src["count"])
	if count < 1:
		return false
	var start_count: int = count
	for i in arr.size():
		if count <= 0:
			break
		var cell: Variant = arr[i]
		if cell == null:
			continue
		if str(cell.get("id", "")) != item_id:
			continue
		var room: int = cap - int(cell.get("count", 0))
		if room <= 0:
			continue
		var add: int = mini(room, count)
		cell["count"] = int(cell.get("count", 0)) + add
		arr[i] = cell
		count -= add
	if count > 0:
		for i in arr.size():
			if count <= 0:
				break
			if arr[i] != null:
				continue
			var put: int = mini(count, cap)
			arr[i] = {"id": item_id, "count": put}
			count -= put
	if count >= start_count:
		return false
	tb["tackle"] = tackle
	slots[tackle_slot_idx] = tb
	if count <= 0:
		slots[from_main_slot_idx] = null
	else:
		src["count"] = count
		slots[from_main_slot_idx] = src
	inventory_changed.emit()
	return true


func get_item_display_name(item_id: String) -> String:
	var norm_id := _normalize_item_id(item_id)
	var it: ItemData = ItemCatalog.get_item(norm_id)
	if it != null and not it.display_name.is_empty():
		return it.display_name
	match item_id:
		"logs", "wood":
			return "Logs"
		"oak_logs", "logs_oak":
			return "Oak logs"
		"torch", "tool_torch":
			return "Torch"
		"hammer", "tool_hammer":
			return "Hammer"
		"chisel", "tool_chisel":
			return "Chisel"
		"stone":
			return "Stone"
		"tin_ore", "ore_tin":
			return "Tin ore"
		"ore_copper":
			return "Copper ore"
		"ore_iron":
			return "Iron ore"
		"ore_silver":
			return "Silver ore"
		"ore_gold":
			return "Gold ore"
		"ingot_copper":
			return "Copper ingot"
		"ingot_tin":
			return "Tin ingot"
		"ingot_iron":
			return "Iron ingot"
		"ingot_silver":
			return "Silver ingot"
		"ingot_gold":
			return "Gold ingot"
		"ingot_bronze":
			return "Bronze ingot"
		"meat_raw":
			return "Raw meat"
		"hide_raw":
			return "Raw hide"
		"feather":
			return "Feather"
		"bone":
			return "Bone"
		_:
			if item_id.is_empty():
				return ""
			return item_id.replace("_", " ").capitalize()


func get_pickup_scene_for_item(item_id: String) -> PackedScene:
	var it: ItemData = ItemCatalog.get_item(item_id)
	if it != null and not it.pickup_scene_path.is_empty():
		var res: Resource = load(it.pickup_scene_path)
		if res is PackedScene:
			return res as PackedScene
	return PICKUP_SCENES.get(item_id, null) as PackedScene


## Optional `tackle_preset`: when `item_name` is `tool_tacklebox`, used for the new slot's tackle grids (normalized on write).
## If the player already has a tacklebox, preset is merged into empty cells only (no duplicate box).
func add_item(item_name: String, quantity: int = 1, tackle_preset: Variant = null) -> int:
	if quantity < 1:
		return 0
	if item_name == TACKLEBOX_ID and _count_tackleboxes_in_grid() > 0:
		if tackle_preset != null and typeof(tackle_preset) == TYPE_DICTIONARY:
			var unlocked_early := get_unlocked_slot_count()
			for bi in unlocked_early:
				var bs: Variant = slots[bi]
				if bs == null or str(bs.get("id", "")) != TACKLEBOX_ID:
					continue
				var tb: Dictionary = bs as Dictionary
				tb["tackle"] = _fill_empty_tackle_from_preset(tb.get("tackle", null), tackle_preset)
				slots[bi] = tb
				inventory_changed.emit()
				return maxi(0, quantity - 1)
		return quantity
	var left: int = quantity
	var cap: int = _stack_cap_for(item_name)
	# Stack into existing piles first
	var unlocked_count := get_unlocked_slot_count()
	for i in unlocked_count:
		if left <= 0:
			break
		var s: Variant = slots[i]
		if s == null:
			continue
		if str(s.get("id", "")) != item_name:
			continue
		var c: int = int(s.get("count", 0))
		var room: int = cap - c
		if room <= 0:
			continue
		var add: int = mini(left, room)
		var new_count: int = c + add
		var merged: Dictionary = {"id": item_name, "count": new_count}
		_copy_slot_extras(s, merged)
		if item_name == TACKLEBOX_ID:
			var base_tackle: Variant = merged.get("tackle", null)
			if tackle_preset != null and typeof(tackle_preset) == TYPE_DICTIONARY:
				merged["tackle"] = _fill_empty_tackle_from_preset(base_tackle, tackle_preset)
			else:
				merged["tackle"] = _normalize_tackle(base_tackle)
		slots[i] = merged
		left -= add
	if left > 0:
		for i in unlocked_count:
			if left <= 0:
				break
			if slots[i] != null:
				continue
			var add: int = mini(left, cap)
			var slot_dict: Dictionary = {"id": item_name, "count": add}
			if item_name == TACKLEBOX_ID:
				if tackle_preset != null and typeof(tackle_preset) == TYPE_DICTIONARY:
					slot_dict["tackle"] = _normalize_tackle(tackle_preset)
				else:
					slot_dict["tackle"] = empty_tackle()
			slots[i] = slot_dict
			left -= add
	inventory_changed.emit()
	return left


func _copy_slot_extras(from: Variant, to: Dictionary) -> void:
	if typeof(from) != TYPE_DICTIONARY:
		return
	var fd: Dictionary = from
	if str(fd.get("id", "")) == TACKLEBOX_ID:
		to["tackle"] = _normalize_tackle(fd.get("tackle", null))
	elif fd.has("tackle"):
		to["tackle"] = _normalize_tackle(fd["tackle"])


func remove_item(item_name: String, quantity: int = 1) -> void:
	var left: int = quantity
	var unlocked_count := get_unlocked_slot_count()
	for i in unlocked_count:
		if left <= 0:
			break
		var s: Variant = slots[i]
		if s == null or str(s.get("id", "")) != item_name:
			continue
		var c: int = int(s.get("count", 0))
		var take: int = mini(left, c)
		var nc: int = c - take
		left -= take
		if nc <= 0:
			slots[i] = null
		else:
			var nd: Dictionary = {"id": item_name, "count": nc}
			_copy_slot_extras(s, nd)
			slots[i] = nd
	inventory_changed.emit()


func get_items_copy() -> Dictionary:
	var out := {}
	var unlocked_count := get_unlocked_slot_count()
	for i in unlocked_count:
		var s: Variant = slots[i]
		if s == null:
			continue
		var id: String = str(s.get("id", ""))
		var c: int = int(s.get("count", 0))
		if id in out:
			out[id] = int(out[id]) + c
		else:
			out[id] = c
	return out


func has_item(item_name: String) -> bool:
	return get_item_count(item_name) > 0


func get_item_count(item_name: String) -> int:
	var n := 0
	var unlocked_count := get_unlocked_slot_count()
	for i in unlocked_count:
		var s: Variant = slots[i]
		if s != null and str(s.get("id", "")) == item_name:
			n += int(s.get("count", 0))
	return n


func count_fishing_bait_total() -> int:
	var n: int = get_item_count(BAIT_ITEM_ID) + get_item_count(WORM_ITEM_ID)
	var unlocked_count := get_unlocked_slot_count()
	for i in unlocked_count:
		var s: Variant = slots[i]
		if s == null or str(s.get("id", "")) != TACKLEBOX_ID:
			continue
		var tackle: Dictionary = _normalize_tackle(s.get("tackle", null))
		var bait_arr: Array = tackle["bait"] as Array
		for cell in bait_arr:
			if cell == null or typeof(cell) != TYPE_DICTIONARY:
				continue
			var cid := str(cell.get("id", ""))
			if tackle_category_for_item(cid) != "bait":
				continue
			n += int(cell.get("count", 0))
	return n


## Consumes one bait from tacklebox bait cells first, then main inventory stacks.
## Returns the consumed item id, or "" if none available.
func consume_one_fishing_bait() -> String:
	if count_fishing_bait_total() < 1:
		return ""
	var unlocked_count := get_unlocked_slot_count()
	for i in unlocked_count:
		var s: Variant = slots[i]
		if s == null or str(s.get("id", "")) != TACKLEBOX_ID:
			continue
		var tb: Dictionary = s as Dictionary
		var tackle: Dictionary = _normalize_tackle(tb.get("tackle", null))
		var bait_arr: Array = tackle["bait"] as Array
		for j in bait_arr.size():
			var cell: Variant = bait_arr[j]
			if cell == null or typeof(cell) != TYPE_DICTIONARY:
				continue
			var cid := str(cell.get("id", ""))
			if tackle_category_for_item(cid) != "bait":
				continue
			var cc: int = int(cell.get("count", 0))
			if cc < 1:
				continue
			cc -= 1
			if cc <= 0:
				bait_arr[j] = null
			else:
				bait_arr[j] = {"id": cid, "count": cc}
			tb["tackle"] = tackle
			slots[i] = tb
			inventory_changed.emit()
			return cid
	if get_item_count(WORM_ITEM_ID) >= 1:
		remove_item(WORM_ITEM_ID, 1)
		return WORM_ITEM_ID
	if get_item_count(BAIT_ITEM_ID) >= 1:
		remove_item(BAIT_ITEM_ID, 1)
		return BAIT_ITEM_ID
	return ""


func get_slot_data(index: int) -> Variant:
	if index < 0 or index >= SLOT_COUNT:
		return null
	return slots[index]


func remove_amount_from_slot(slot_idx: int, amount: int) -> bool:
	if amount < 1 or slot_idx < 0 or slot_idx >= SLOT_COUNT:
		return false
	var s: Variant = slots[slot_idx]
	if s == null:
		return false
	var c: int = int(s.get("count", 0))
	if c < amount:
		return false
	if c == amount:
		slots[slot_idx] = null
	else:
		s["count"] = c - amount
		slots[slot_idx] = s
	inventory_changed.emit()
	return true


func set_slot_data(slot_idx: int, data: Variant) -> void:
	if slot_idx < 0 or slot_idx >= SLOT_COUNT:
		return
	if not is_slot_unlocked(slot_idx):
		return
	if data == null:
		slots[slot_idx] = null
	else:
		slots[slot_idx] = _duplicate_slot(data)
	inventory_changed.emit()


func move_or_merge(from_idx: int, to_idx: int) -> void:
	if from_idx == to_idx:
		return
	if from_idx < 0 or from_idx >= SLOT_COUNT:
		return
	if to_idx < 0 or to_idx >= SLOT_COUNT:
		return
	if not is_slot_unlocked(to_idx):
		return
	var a: Variant = slots[from_idx]
	if a == null:
		return
	var from_unlocked := is_slot_unlocked(from_idx)
	var b: Variant = slots[to_idx]
	if not from_unlocked and b != null:
		var aid0: String = str(a.get("id", ""))
		var bid0: String = str(b.get("id", ""))
		if aid0 != bid0:
			return
	if b == null:
		slots[to_idx] = _duplicate_slot(a)
		slots[from_idx] = null
		inventory_changed.emit()
		return
	var aid: String = str(a.get("id", ""))
	var bid: String = str(b.get("id", ""))
	if aid == bid:
		var cap: int = _stack_cap_for(aid)
		var room: int = cap - int(b.get("count", 0))
		if room <= 0:
			return
		var move_amt: int = mini(int(a.get("count", 0)), room)
		b["count"] = int(b.get("count", 0)) + move_amt
		a["count"] = int(a.get("count", 0)) - move_amt
		if aid == TACKLEBOX_ID:
			_merge_tackle_payload(b, a)
		if int(a.get("count", 0)) <= 0:
			slots[from_idx] = null
		else:
			slots[from_idx] = a
		slots[to_idx] = b
		inventory_changed.emit()
		return
	var tmp: Variant = slots[to_idx]
	slots[to_idx] = slots[from_idx]
	slots[from_idx] = tmp
	_normalize_tacklebox_slot_at(to_idx)
	_normalize_tacklebox_slot_at(from_idx)
	inventory_changed.emit()


func _normalize_tacklebox_slot_at(slot_idx: int) -> void:
	var s: Variant = slots[slot_idx]
	if s == null or typeof(s) != TYPE_DICTIONARY:
		return
	var d: Dictionary = s
	if str(d.get("id", "")) != TACKLEBOX_ID:
		return
	d["tackle"] = _normalize_tackle(d.get("tackle", null))
	slots[slot_idx] = d


func _merge_tackle_payload(into: Dictionary, from: Dictionary) -> void:
	if not into.has("tackle"):
		into["tackle"] = _normalize_tackle(from.get("tackle", null))
	else:
		into["tackle"] = _normalize_tackle(into["tackle"])


func _duplicate_slot(s: Variant) -> Dictionary:
	var d: Dictionary = (s as Dictionary).duplicate(true)
	if str(d.get("id", "")) == TACKLEBOX_ID:
		d["tackle"] = _normalize_tackle(d.get("tackle", null))
	elif d.has("tackle"):
		d["tackle"] = _normalize_tackle(d["tackle"])
	return d


func drop_slot_to_world(slot_idx: int, drop_global_position: Vector3, world_parent: Node) -> void:
	if slot_idx < 0 or slot_idx >= SLOT_COUNT:
		return
	var s: Variant = slots[slot_idx]
	if s == null:
		return
	var id: String = str(s.get("id", ""))
	var count: int = int(s.get("count", 0))
	slots[slot_idx] = null
	inventory_changed.emit()
	var scene: PackedScene = get_pickup_scene_for_item(id)
	if scene == null:
		push_warning("inventory_service: no pickup scene for '%s'" % id)
		return
	var node := scene.instantiate()
	if node == null:
		return
	world_parent.add_child(node)
	if node is Node3D:
		(node as Node3D).global_position = drop_global_position
		_persist_placeable_fire_if_needed(id, node as Node3D)
	if node.has_method("set_resource_type"):
		node.set_resource_type(id)
	elif "resource_type" in node:
		node.resource_type = id
	if node.has_method("set_quantity"):
		node.set_quantity(count)
	elif "quantity" in node:
		node.quantity = count


func compute_drop_position(player: Node3D, camera: Camera3D, mouse_global_pos: Vector2) -> Vector3:
	var drop_pos := player.global_position + player.global_basis.z * 0.8 + Vector3.UP * 0.25
	if camera == null:
		return drop_pos
	var origin := camera.project_ray_origin(mouse_global_pos)
	var normal := camera.project_ray_normal(mouse_global_pos)
	var target := origin + normal * 6.0
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.size() > 0:
		return (hit["position"] as Vector3) + Vector3.UP * 0.3
	return drop_pos


func _persist_placeable_fire_if_needed(item_id: String, node: Node3D) -> void:
	if item_id != "tool_torch" and item_id != "campfire_kit":
		return
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null or not ("placed_fire_nodes" in gs):
		return
	var fire_scene_path := ""
	match item_id:
		"tool_torch":
			fire_scene_path = "res://world/torch_light.tscn"
		"campfire_kit":
			fire_scene_path = "res://entities/building_parts/campfire.tscn"
	var state_id := "placed_fire_%s" % str(int(Time.get_unix_time_from_system() * 1000.0))
	if "fire_state_id" in node:
		node.fire_state_id = state_id
	if item_id == "campfire_kit":
		var qs: Node = get_node_or_null("/root/QuestService")
		if qs != null and qs.has_method("notify_campfire_placed"):
			qs.call("notify_campfire_placed", state_id)
	var entry := {
		"region": String(gs.region),
		"scene_path": fire_scene_path,
		"state_id": state_id,
		"position": [node.global_position.x, node.global_position.y, node.global_position.z],
		"rotation_y": node.rotation.y,
	}
	gs.placed_fire_nodes.append(entry)


func get_save_dict() -> Dictionary:
	var arr: Array = []
	for i in SLOT_COUNT:
		var s: Variant = slots[i]
		if s == null:
			arr.append(null)
		else:
			var e: Dictionary = {"id": str(s.get("id", "")), "count": int(s.get("count", 0))}
			if str(s.get("id", "")) == TACKLEBOX_ID:
				e["tackle"] = _tackle_to_save_dict(s.get("tackle", null))
			arr.append(e)
	return {"slots": arr}


func _tackle_to_save_dict(t: Variant) -> Dictionary:
	var norm: Dictionary = _normalize_tackle(t)
	return {
		"hooks": norm["hooks"].duplicate(),
		"bobbers": norm["bobbers"].duplicate(),
		"bait": norm["bait"].duplicate(),
	}


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
		var id := _normalize_item_id(str(entry.get("id", "")))
		var c := int(entry.get("count", 0))
		if id.is_empty() or c < 1:
			slots[i] = null
			continue
		var cap: int = _stack_cap_for(id)
		var slot_d: Dictionary = {"id": id, "count": mini(c, cap)}
		if id == TACKLEBOX_ID:
			slot_d["tackle"] = _normalize_tackle(entry.get("tackle", null))
		slots[i] = slot_d
	inventory_changed.emit()


func _normalize_item_id(id: String) -> String:
	return GameState.normalize_item_id(id)


func clear_all_slots() -> void:
	for i in SLOT_COUNT:
		slots[i] = null
	inventory_changed.emit()
