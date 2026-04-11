# RuneForged Save Format

## Save goals
- Backward compatibility is preferred.
- Additive changes are safer than destructive changes.
- Save migrations should be small, explicit, and testable.

## Expectations when editing save-related code
- Document any new save keys.
- Document changed or removed keys.
- Provide defaults for missing legacy fields.
- Call out migration needs before introducing breaking changes.

## Inventory (`SaveManager` v2+)

- **`inventory.slots`**: array length matches `InventoryService.SLOT_COUNT`. Each entry is `null` or a dictionary:
  - **`id`**: string, item id.
  - **`count`**: int, clamped on load by `ItemData.max_stack` from ItemCatalog.
  - **`tackle`** (optional, only when `id` is `tool_tacklebox`): dictionary with **`hooks`**, **`bobbers`**, **`bait`** — each is an array of `null` or `{ "id": String, "count": int }`. Missing `tackle` on load defaults to empty grids.