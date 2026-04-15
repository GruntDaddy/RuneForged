# Terrain3D blockout (main island)

Use this workflow for the first playable pass on [`world/regions/main_island/main_island.tscn`](../../world/regions/main_island/main_island.tscn). **Terrain3D** is the source of truth for outdoor ground; do not stack [`addons/ninetailsrabbit.terrainy`](../../addons/ninetailsrabbit.terrainy) mesh terrain on the same walkable surface.

## 1. Scale

- Default Terrain3D region size is **1024 m** per side (see Terrain3D docs). Start with **one region** at the origin, then add more only if the island needs more area.
- Keep `data_directory` at `res://data/terrain3d` (or a dedicated subfolder if you split biomes later).

## 2. Coast silhouette

- Export a **coastal mask** or reference from your concept art (silhouette of the main island).
- **Automated outline (editor):** attach [`scripts/world/editor/coast_mask_height_tool.gd`](../../scripts/world/editor/coast_mask_height_tool.gd) to your **Terrain3D** node (temporarily). Set `mask_image_path` to a PNG — preferably a **black & white** land mask (white = land). For a **full-color** map, enable `use_blue_water_heuristic` only if needed; it often mis-labels forests/deserts as water. Toggle **Run import** once. The tool uses the same **2048×2048 / 1024 m region** convention as the Terrain3D demo, aligns import origin to **(-region, 0, -region)**, lowers default **import_scale** (gentle coast), and sets **world background to NONE** to avoid a huge flat “infinite ground” slab. Check the Godot **Output** panel for land/sea %; if it is ~0% or ~100%, fix the mask or `invert_mask`. Remove the script when finished.
- Manual path: add a region, use **Sculpt** / **Raise** for land and low areas for sea, using the mask as an overlay on a second monitor.

## 3. Macro height

- Block **north highlands**, **central basin / crater**, **south plateaus**, and **east bay** as broad shapes before small noise or textures.
- Optional: paint a **heightmap** in Krita/GIMP/Gaea and **import** via Terrain3D’s heightmap importer (see `addons/terrain_3d` documentation for supported formats and scale).

## 4. Textures and props (later)

- After the silhouette reads clearly, assign Terrain3D materials and place gameplay props under **TerrainObjects** (see [`harvestable_resource.gd`](../../world/world_building_parts/props/harvestable_resource.gd)) or plain `Node3D` parents as needed.

## 5. World map alignment

- Update [`data/world/world_regions.json`](../../data/world/world_regions.json) **`map_uv_rect`** values (normalized 0–1) so hover regions on the 2D world map match your final art. Replace [`assets/world/rune_forged_world_map.png`](../../assets/world/rune_forged_world_map.png) with the full-resolution map; keep aspect ratio consistent with the UV rects you author.
