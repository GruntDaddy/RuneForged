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

- **`inventory.slots`**: array length matches `InventoryService.SLOT_COUNT` (currently 42 = 28 base + 14 backpack). Each entry is `null` or a dictionary:
  - **`id`**: string, item id.
  - **`count`**: int, clamped on load by `ItemData.max_stack` from ItemCatalog.
  - **`tackle`** (optional, only when `id` is `tool_tacklebox`): dictionary with **`hooks`**, **`bobbers`**, **`bait`** — each is an array of `null` or `{ "id": String, "count": int }`. Missing `tackle` on load defaults to empty grids.
- Runtime lock rule: slots `0-27` are always available; slots `28-41` are only usable while a backpack is equipped in the `back` equipment slot.

## Game State Additions (`SaveManager` v2 payload.game_state)

- **`survival_level`**: int survival skill level used by crafting requirements such as torch crafting/repair.
- **`smithing_level`**: int smithing skill level used by smithing recipes (`skill_id = "smithing"`).
- **`crafting_level`**: int crafting skill level used by utility/building recipes (`skill_id = "crafting"`).
- **`skill_levels`**: dictionary (`skill_id -> int`) canonical skill registry. Legacy flat fields above remain supported and are synchronized for backward compatibility.
- **`time_of_day`**: float in `[0, 1)`, used by `DayNightController` to resume cycle position.
- **`moon_phase`**: float in `[0, 1)`, moon phase offset used by sky shader/controller.
- **`world_fire_states`**: dictionary keyed by node path or explicit `fire_state_id` (string), values are dictionaries with fire runtime state:
  - **`lit`**: bool.
  - **`fuel_seconds`**: float remaining burn time.
  - **`logs_burned_counter`**: int for charcoal mint pacing (campfires).
  - **`log_slots`**: optional array (length 4) of `null` or `{ "id": "logs", "count": int }` per campfire log slot. Missing key loads as empty slots.
  - **`cook_slots`**: optional array (length 2) of `null` or stack dicts (campfire cooking; `meat_raw`). Missing key loads empty.
  - **`cook_progress_sec`**: optional array (length 2) of floats 0–`COOK_TIME_SEC` per cooking slot. Missing key defaults to zeros.
- **`placed_fire_nodes`**: array of dictionaries for player-placed fire props:
  - `region`: string region id.
  - `scene_path`: packed scene path.
  - `state_id`: unique fire state id.
  - `position`: `[x, y, z]` world-space float array.
  - `rotation_y`: float radians.
- **`warmth_until_unix_ms`**: int UTC epoch milliseconds when temporary campfire warmth buff expires.
- **`campfire_night_run_bonus`** / **`campfire_night_penalty`**: float night movement tuning applied by player controller.

Legacy saves missing these keys default safely in `GameState.from_dict()`.

## Equipment persistence contract

- `game_state.equipment` remains a dictionary of slots to `{ "id": String, "count": int }` plus optional fields when needed:
  - **`torch_lit`** (optional, `off_hand` only when `id` is `tool_torch`): bool — whether the equipped torch flame is active (lit from a fire). Defaults to false when missing or when swapping to a different torch.
- Slot writes should go through `GameState.set_equipment_slot(slot, item_id, count)` and clears through `GameState.clear_equipment_slot(slot)` so IDs are normalized consistently.
- Legacy aliases are normalized during load in `GameState.from_dict()` via `GameState.normalize_item_id(...)`.
  - Current aliases include: `wood -> logs`, `oak_logs -> logs_oak`, `torch -> tool_torch`, `hammer -> tool_hammer`, `chisel -> tool_chisel`.
- Backward compatibility note: legacy IDs are accepted in older saves, then rewritten in-memory to canonical IDs after load.

## Hotbar persistence

- `game_state.hotbar_item_ids` remains an array of four item ids.
- `game_state.hotbar_spell_ids` (optional on legacy saves): parallel array of four spell effect ids (for example `spell_air_push`). When a slot has a non-empty spell id, that slot casts the spell instead of using `hotbar_item_ids` for that index. Missing key defaults to four empty strings on load.
- Hotbar slots may include rune ids (for example `rune_air`, `rune_earth`) in addition to tools/gear ids when no spell is bound. Legacy `rune_spark` is normalized to `rune_air` at load.
