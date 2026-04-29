# RuneForged Item Schema

## Authoritative data (`res://data/items/`)

- Stackable materials, tools, weapons, and armor are defined as **`.tres` resources** built from scripts in [`data/schemas/`](../data/schemas/).
- The stable key for saves, inventory slots, and cross-system references is **`ItemData.id`** (snake_case), e.g. `logs`, `logs_oak`, `stone`, `ore_tin`, `hatchet_basic`, `sword_1h_wooden`.
- **Bow ammunition (stackable materials):** world pickups and inventory use ids `ammo_arrow_wood`, `ammo_arrow_common`, `ammo_arrow_bronze`, `ammo_arrow_iron` (see `res://data/items/materials/ammo_arrow_*.tres`). Tutorial props use these ids directly on `item_pickup_interactable.gd` (bundles use `quantity` 20; single arrows use 1).
- At runtime, [`ItemCatalog`](../autoload/item_catalog.gd) (autoload) indexes every `ItemData` under `res://data/items/` for lookup by id. **Do not serialize full `ItemData` blobs in save files**—only id + count (and optional container payloads such as tackle data on `tool_tacklebox`).

## Stacking (`ItemData.max_stack`)

- [`InventoryService`](../autoload/inventory_service.gd) uses **`max_stack` per item** when merging and when clamping loads (not a single global cap).
- **Convention:** gear-like items (weapons, tools you wield, armour) use **`max_stack = 1`**. Raw resources (ores, logs, bars, etc.) and small stackables (e.g. bait) may use higher values.

## Recipes (`res://data/recipes/`)

- Authoring resources use [`RecipeData`](../data/schemas/recipe_data.gd). Runtime lookup: [`RecipeCatalog`](../autoload/recipe_catalog.gd).
- **`required_tool_ids`**: items that must be in inventory but are **not** consumed (e.g. hammer at anvil).

## Fishing tackle tags

- Items stored in the tacklebox sub-inventory use tags: **`fishing_hook`**, **`fishing_bobber`**, **`fishing_bait`** (see `InventoryService.tackle_category_for_item`).

## High-level item categories
- Materials
- Consumables
- Weapons
- Armor
- Relics
- Runes

## Rules
- Materials and consumables may be stackable.
- Unique gear, relics, and rolled items are not stackable unless explicitly designed otherwise.
- Tooltip and comparison systems should consume item data without mutating it.
- Equipment and inventory systems should share stable item identifiers and field names.