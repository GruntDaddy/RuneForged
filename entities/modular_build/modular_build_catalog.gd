extends RefCounted
class_name ModularBuildCatalog

## Authoritative list of medieval_village kit pieces exposed in the modular builder.
## Categories drive the UI tabs; ids are stable save keys.

## World grid in meters. Most kit pieces are ~`NATIVE_MODULE_METERS` wide; use `piece_scale_vector()` at runtime. Optional per-row `native_xz_span` fixes narrow corner trims.
const CELL_SIZE: float = 3.0
## Kit pieces are roughly laid out on a 2m module; with a 3m cell we scale meshes ~1.5× to fill the footprint.
const NATIVE_MODULE_METERS: float = 2.0
## Default kit floor slabs are ~2 cm thick with pivot near the middle; vertical placement uses this so they are not buried.
const FLOOR_NATIVE_MESH_Y_MIN: float = -0.01
## After aligning mesh bottom to the deck, nudge slightly down to reduce terrain z-fighting (must stay << slab thickness).
const FLOOR_SURFACE_BIAS: float = 0.02
## Raises full floor slabs above raw terrain (meters); foundation brick skirts align under the slab.
const FLOOR_DECK_LIFT: float = 0.25
## Short foundation stem under floor slabs (meters); built as shared-material box meshes in `ModularBuildPiece`.
## Deeper stem reads better on sloped terrain (less floating above sand).
const FOUNDATION_BOX_DEPTH: float = 0.95
const FOUNDATION_BOX_THICK: float = 0.15
const FOUNDATION_SKIRT_ALBEDO := Color(0.48, 0.44, 0.4, 1.0)
const STORY_HEIGHT: float = 3.25
const MAX_PLACE_DISTANCE: float = 16.0
const OWNER_PLAYER: String = "player"

const _KIT: String = "res://assets/medieval_village kit/"

static func all_piece_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rows: Array = [
		# Floors — `foundation_skirt` adds a simple rim mesh under the slab (see `ModularBuildPiece`).
		{"id": "floor_wood_light", "name": "Wood Floor (Light)", "category": "floors", "path": _KIT + "Floor_WoodLight.gltf", "foundation_skirt": true},
		{"id": "floor_wood_dark", "name": "Wood Floor (Dark)", "category": "floors", "path": _KIT + "Floor_WoodDark.gltf", "foundation_skirt": true},
		{"id": "floor_wood_dark_half1", "name": "Wood Floor Half", "category": "floors", "path": _KIT + "Floor_WoodDark_Half1.gltf"},
		{"id": "floor_uneven_brick", "name": "Brick Floor (Uneven)", "category": "floors", "path": _KIT + "Floor_UnevenBrick.gltf", "foundation_skirt": true},
		{"id": "floor_red_brick", "name": "Brick Floor (Red)", "category": "floors", "path": _KIT + "Floor_RedBrick.gltf", "foundation_skirt": true},
		# Walls — plaster
		{"id": "wall_plaster_straight", "name": "Plaster Wall", "category": "walls", "path": _KIT + "Wall_Plaster_Straight.gltf"},
		{"id": "wall_plaster_straight_base", "name": "Plaster Wall (Base)", "category": "walls", "path": _KIT + "Wall_Plaster_Straight_Base.gltf"},
		{"id": "wall_plaster_straight_l", "name": "Plaster Wall (L)", "category": "walls", "path": _KIT + "Wall_Plaster_Straight_L.gltf"},
		{"id": "wall_plaster_straight_r", "name": "Plaster Wall (R)", "category": "walls", "path": _KIT + "Wall_Plaster_Straight_R.gltf"},
		{"id": "wall_plaster_woodgrid", "name": "Plaster Wood Grid", "category": "walls", "path": _KIT + "Wall_Plaster_WoodGrid.gltf"},
		# Walls — brick
		{"id": "wall_brick_straight", "name": "Brick Wall", "category": "walls", "path": _KIT + "Wall_UnevenBrick_Straight.gltf"},
		# Doors (meshed as wall modules)
		{"id": "door_plaster_flat", "name": "Door Wall (Plaster)", "category": "doors", "path": _KIT + "Wall_Plaster_Door_Flat.gltf"},
		{"id": "door_plaster_round", "name": "Door Wall (Plaster Round)", "category": "doors", "path": _KIT + "Wall_Plaster_Door_Round.gltf"},
		{"id": "door_brick_flat", "name": "Door Wall (Brick)", "category": "doors", "path": _KIT + "Wall_UnevenBrick_Door_Flat.gltf"},
		{"id": "door_brick_round", "name": "Door Wall (Brick Round)", "category": "doors", "path": _KIT + "Wall_UnevenBrick_Door_Round.gltf"},
		# Windows
		{"id": "win_plaster_wide_flat", "name": "Window (Plaster Wide)", "category": "windows", "path": _KIT + "Wall_Plaster_Window_Wide_Flat.gltf"},
		{"id": "win_plaster_thin_round", "name": "Window (Plaster Thin Round)", "category": "windows", "path": _KIT + "Wall_Plaster_Window_Thin_Round.gltf"},
		{"id": "win_brick_wide_flat", "name": "Window (Brick Wide)", "category": "windows", "path": _KIT + "Wall_UnevenBrick_Window_Wide_Flat.gltf"},
		{"id": "win_brick_thin_round", "name": "Window (Brick Thin Round)", "category": "windows", "path": _KIT + "Wall_UnevenBrick_Window_Thin_Round.gltf"},
		# Corners / transitions
		{"id": "corner_ext_brick", "name": "Ext. Corner (Brick)", "category": "corners", "path": _KIT + "Corner_Exterior_Brick.gltf", "native_xz_span": 0.58},
		{"id": "corner_ext_wood", "name": "Ext. Corner (Wood)", "category": "corners", "path": _KIT + "Corner_Exterior_Wood.gltf", "native_xz_span": 0.24},
		{"id": "corner_int_small", "name": "Int. Corner (Small)", "category": "corners", "path": _KIT + "Corner_Interior_Small.gltf", "native_xz_span": 0.24},
		{"id": "corner_int_big", "name": "Int. Corner (Big)", "category": "corners", "path": _KIT + "Corner_Interior_Big.gltf", "native_xz_span": 0.37},
		# Stairs
		{"id": "stair_interior_simple", "name": "Interior Stair", "category": "stairs", "path": _KIT + "Stair_Interior_Simple.gltf", "native_xz_span": 4.6},
		{"id": "stair_interior_rails", "name": "Interior Stair (Rails)", "category": "stairs", "path": _KIT + "Stair_Interior_Rails.gltf", "native_xz_span": 8.35},
		{"id": "stairs_ext_straight", "name": "Exterior Stairs", "category": "stairs", "path": _KIT + "Stairs_Exterior_Straight.gltf"},
		# Roofs
		{"id": "roof_tiles_4x4", "name": "Roof Tiles 4×4", "category": "roofs", "path": _KIT + "Roof_RoundTiles_4x4.gltf"},
		{"id": "roof_tiles_4x6", "name": "Roof Tiles 4×6", "category": "roofs", "path": _KIT + "Roof_RoundTiles_4x6.gltf"},
		{"id": "roof_wooden_2x1", "name": "Roof Wooden 2×1", "category": "roofs", "path": _KIT + "Roof_Wooden_2x1.gltf"},
		{"id": "roof_wooden_corner", "name": "Roof Wooden Corner", "category": "roofs", "path": _KIT + "Roof_Wooden_2x1_Corner.gltf"},
		{"id": "roof_front_brick4", "name": "Roof Front (Brick)", "category": "roofs", "path": _KIT + "Roof_Front_Brick4.gltf"},
		# Decor / props
		{"id": "prop_crate", "name": "Crate", "category": "decor", "path": _KIT + "Prop_Crate.gltf"},
		{"id": "prop_fence_single", "name": "Fence Post", "category": "decor", "path": _KIT + "Prop_WoodenFence_Single.gltf"},
		{"id": "prop_chimney", "name": "Chimney", "category": "decor", "path": _KIT + "Prop_Chimney.gltf"},
		{"id": "prop_support", "name": "Support Beam", "category": "decor", "path": _KIT + "Prop_Support.gltf"},
	]
	for r in rows:
		out.append(r as Dictionary)
	return out


static func categories_in_order() -> PackedStringArray:
	return PackedStringArray([
		"floors", "walls", "doors", "windows", "corners", "stairs", "roofs", "decor",
	])


static func category_display_name(cat: String) -> String:
	match cat:
		"floors":
			return "Floors"
		"walls":
			return "Walls"
		"doors":
			return "Doors"
		"windows":
			return "Windows"
		"corners":
			return "Corners"
		"stairs":
			return "Stairs"
		"roofs":
			return "Roofs"
		"decor":
			return "Decor"
		_:
			return cat.capitalize()


static func find_def(piece_id: String) -> Dictionary:
	var pid := piece_id.strip_edges()
	for d in all_piece_rows():
		if String(d.get("id", "")) == pid:
			return d
	return {}


static func gltf_path_for(piece_id: String) -> String:
	var d := find_def(piece_id)
	return String(d.get("path", ""))


static func display_name_for(piece_id: String) -> String:
	var d := find_def(piece_id)
	var n := String(d.get("name", ""))
	if n.is_empty():
		return piece_id
	return n


static func piece_scale_factor() -> float:
	return CELL_SIZE / maxf(0.001, NATIVE_MODULE_METERS)


## Horizontal span of the mesh in meters (max AABB size on X/Z). Defaults to `NATIVE_MODULE_METERS` (2 m walls/floors). Smaller trims (corners) need a smaller value so XZ scale reaches `CELL_SIZE`.
static func native_xz_span_for(piece_id: String) -> float:
	var d := find_def(piece_id)
	var span := float(d.get("native_xz_span", NATIVE_MODULE_METERS))
	return maxf(0.05, span)


## Non-uniform scale: stretch narrow kit pieces on X/Z to one cell wide, keep Y on the standard module scale so heights still match walls.
static func piece_scale_vector(piece_id: String) -> Vector3:
	var sy := piece_scale_factor()
	var span := native_xz_span_for(piece_id)
	var sxz := CELL_SIZE / span
	return Vector3(sxz, sy, sxz)


static func is_floor_piece(piece_id: String) -> bool:
	return String(find_def(piece_id).get("category", "")) == "floors"


static func foundation_skirt_enabled(piece_id: String) -> bool:
	return bool(find_def(piece_id).get("foundation_skirt", false))


## World Y for the piece root so the bottom of the default floor slab sits on `deck_y` (terrain or upper-story deck), with a tiny bias into the surface.
static func floor_snap_y_for_deck(deck_y: float, piece_id: String) -> float:
	var sy := piece_scale_vector(piece_id).y
	return deck_y - FLOOR_SURFACE_BIAS - FLOOR_NATIVE_MESH_Y_MIN * sy


static func grid_indices_from_world_xz(world_xz: Vector2) -> Vector2i:
	var ix := floori(world_xz.x / CELL_SIZE)
	var iz := floori(world_xz.y / CELL_SIZE)
	return Vector2i(ix, iz)


static func cell_center_xz(ix: int, iz: int) -> Vector2:
	return Vector2((float(ix) + 0.5) * CELL_SIZE, (float(iz) + 0.5) * CELL_SIZE)
