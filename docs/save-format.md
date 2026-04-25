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

## Game State Additions (`SaveManager` v2 payload.game_state)

- **`survival_level`**: int survival skill level used by crafting requirements such as torch crafting/repair.
- **`time_of_day`**: float in `[0, 1)`, used by `DayNightController` to resume cycle position.
- **`moon_phase`**: float in `[0, 1)`, moon phase offset used by sky shader/controller.
- **`world_fire_states`**: dictionary keyed by node path (string), values are dictionaries with fire runtime state (e.g. `lit`, `fuel_seconds`).
- **`placed_fire_nodes`**: array of dictionaries for player-placed fire props:
  - `region`: string region id.
  - `scene_path`: packed scene path.
  - `state_id`: unique fire state id.
  - `position`: `[x, y, z]` world-space float array.
  - `rotation_y`: float radians.
- **`warmth_until_unix_ms`**: int UTC epoch milliseconds when temporary campfire warmth buff expires.
- **`campfire_night_run_bonus`** / **`campfire_night_penalty`**: float night movement tuning applied by player controller.

Legacy saves missing these keys default safely in `GameState.from_dict()`.