# RuneForged Item Schema

## Authoritative data (`res://data/items/`)

- Stackable materials, tools, weapons, and armor are defined as **`.tres` resources** built from scripts in [`data/schemas/`](../data/schemas/).
- The stable key for saves, inventory slots, and cross-system references is **`ItemData.id`** (snake_case), e.g. `logs`, `logs_oak`, `stone`, `ore_tin`, `hatchet_basic`, `sword_1h_wooden`.
- Tin ore canonical id is `ore_tin`; legacy `tin_ore` is normalized at runtime for backward compatibility.
- **Bow ammunition (stackable materials):** world pickups and inventory use ids `ammo_arrow_wood`, `ammo_arrow_common`, `ammo_arrow_bronze`, `ammo_arrow_iron` (see `res://data/items/materials/ammo_arrow_*.tres`). Tutorial props use these ids directly on `item_pickup_interactable.gd` (bundles use `quantity` 20; single arrows use 1).
- At runtime, [`ItemCatalog`](../autoload/item_catalog.gd) (autoload) indexes every `ItemData` under `res://data/items/` for lookup by id. **Do not serialize full `ItemData` blobs in save files**—only id + count (and optional container payloads such as tackle data on `tool_tacklebox`).
- Optional authoring fields on `ItemData`:
  - `pickup_scene_path`: explicit world scene for drop/place behavior (preferred over hardcoded lookup when present).
  - `use_effect_id` and `use_cooldown_ms`: data-driven item-use effect hooks (currently used by runes).
  - `burn_seconds` (int, default `0`): fuel value when consumed by fire-based stations (campfire). `0` means the item is not a fuel. Canonical fuels: `logs` = `120`, `logs_oak` = `240`.
  - `cook_difficulty` (float `0..1`, default `0.0`): chance of producing the burned variant instead of the cooked variant when auto-cooked over a campfire. `0.0` means the item is not cookable. Canonical cookables: `meat_raw` = `0.05`, `fish_raw` = `0.15`.
  - `cooked_id` (string, default empty): item id produced on a successful cook. Required for cookable items.
  - `burned_id` (string, default empty): item id produced on a failed cook (burn). If empty, a burn roll is treated as a successful cook.

## Cookable items (campfire conversion)

| Raw id      | Cooked id     | Burned id     | `cook_difficulty` |
|-------------|---------------|---------------|-------------------|
| `meat_raw`  | `meat_cooked` | `meat_burned` | `0.05`            |
| `fish_raw`  | `fish_cooked` | `fish_burned` | `0.15`            |

`meat_burned` and `fish_burned` are consumable food items; balance/effect tuning is intentionally deferred. Fish raw/cooked/burned items currently have no world drop source; fishing integration is tracked separately.

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

## Pickup authoring contract

- World pickups should provide explicit item identity fields, not rely on node names:
  - `item_id` (preferred for `item_pickup_interactable.gd`)
  - `quantity` (optional; defaults to 1)
  - `resource_type` is supported for generic resource pickup scenes.
- Item IDs should use canonical catalog IDs from `ItemCatalog` / `ItemData.id`; legacy aliases are normalized at runtime by `GameState.normalize_item_id(...)`.
- Avoid name-based heuristics when placing pickup nodes in scenes; rename-safe behavior depends on explicit fields above.
