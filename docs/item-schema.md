# RuneForged Item Schema

## Authoritative data (`res://data/items/`)

- Stackable materials, tools, weapons, and armor are defined as **`.tres` resources** built from scripts in [`data/schemas/`](../data/schemas/).
- The stable key for saves, inventory slots, and cross-system references is **`ItemData.id`** (snake_case), e.g. `logs`, `logs_oak`, `stone`, `ore_tin`, `hatchet_basic`, `sword_1h_wooden`.
- At runtime, [`ItemCatalog`](../autoload/item_catalog.gd) (autoload) indexes every `ItemData` under `res://data/items/` for lookup by id. **Do not serialize full `ItemData` blobs in save files**—only id + count (and future instance payloads for rolled gear).

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