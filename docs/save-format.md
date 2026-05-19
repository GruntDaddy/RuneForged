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
- **`fishing_level`**: int fishing skill level (mirrors `skill_levels["fishing"]` via `GameState.SKILL_ID_TO_FIELD`). Missing key defaults to `1` on load.
- **`fishing_xp`**: int partial progress toward the next fishing level (consumed when leveling through `GameState.add_fishing_xp`). Missing key defaults to `0`.
- **`time_of_day`**: float in `[0, 1)`, used by `DayNightController` to resume cycle position.
- **`moon_phase`**: float in `[0, 1)`, moon phase offset used by sky shader/controller.
- **`world_fire_states`**: dictionary keyed by node path or explicit `fire_state_id` (string), values are dictionaries with fire runtime state:
  - **`lit`**: bool.
  - **`fuel_seconds`**: float remaining burn time. Each consumed log adds the item's `burn_seconds` (item data); legacy saves still use the campfire's flat `seconds_per_log` fallback.
  - **`logs_burned_counter`**: int for charcoal mint pacing (campfires).
  - **`log_slots`**: optional array (length 4) of `null` or `{ "id": String }` per campfire log slot — one log per slot, any item with `burn_seconds > 0` (e.g. `logs`, `logs_oak`). Missing key loads as empty slots.
  - **`cook_active`**: optional dictionary describing the single in-progress auto-cook entry: `{ "id": String, "cooked_id": String, "burned_id": String, "difficulty": float }`. Empty/missing means nothing is cooking.
  - **`cook_progress_sec`**: optional float (0–`COOK_TIME_SEC`) for the active cook entry. Defaults to `0.0`.
  - **`cook_auto_enabled`**: optional bool — whether the campfire is configured to auto-pull cookables from inventory. Defaults to `false`.
  - **`ash_waiting_pickup`**: optional bool — campfire has cooled with charcoal left in the ash pile until collected via `[F]` (`interact_secondary`). Defaults to `false`.
  - **`pending_charcoal_count`**: optional int — charcoal units staged for pickup while `ash_waiting_pickup` is true. Defaults to `0`.

Legacy `cook_slots` (array of 2) and array-form `cook_progress_sec` written by pre-rework campfires are silently ignored on load. Legacy `log_slots` entries with `count > 1` are migrated by retaining one log per slot and spilling the surplus back into the player's inventory on first load.
- **`placed_fire_nodes`**: array of dictionaries for player-placed fire props:
  - `region`: string region id.
  - `scene_path`: packed scene path.
  - `state_id`: unique fire state id.
  - `position`: `[x, y, z]` world-space float array.
  - `rotation_y`: float radians.
- **`placed_modular_build_pieces`**: array of dictionaries for player-placed modular kit pieces (2 m grid, see `ModularBuildCatalog` / `ModularBuildWorld`):
  - `region`: string region id.
  - `placement_id`: unique string id for dedupe and salvage.
  - `piece_id`: catalog id (maps to a `res://assets/medieval_village kit/*.gltf` entry).
  - `ix`, `iy`, `iz`: int grid indices (`iy` 0 = ground, 1 = one upper story offset).
  - `rotation_y`: float radians (90° steps).
  - `owner`: string owner key (`player` for solo).
  - `position`: `[x, y, z]` world-space float array (authoritative pose on load).
  - **Note:** `region` should match `GameState.region` when set (canonical id `jorvik`). Legacy saves may still store `tutorial_isle` or `overworld`; `GameState.from_dict()` normalizes those to `jorvik` and rewrites `region` on placed fire/build entries. If `region` is empty on load (e.g. Run Current Scene), `GameState.region_effective_for_scene_path()` maps known overworld scene paths (`jorvik.tscn`, legacy `tutorial_isle.tscn`) so pieces still spawn and validate.
- **`warmth_until_unix_ms`**: int UTC epoch milliseconds when temporary campfire warmth buff expires.
- **`campfire_night_run_bonus`** / **`campfire_night_penalty`**: float night movement tuning applied by player controller.

Legacy saves missing these keys default safely in `GameState.from_dict()`.

## Quest progress (`game_state.quest_progress`)

- **`active_quest_id`**: string quest id (e.g. `woodsman_trial`) or empty when none active.
- **`stage_index`**: int zero-based stage within the active quest.
- **`counters`**: dictionary (`counter_id -> int`), e.g. `rabbits_killed`.
- **`flags`**: dictionary for hybrid gating and quest-specific state:
  - **`woodsman_met`**: bool — player has spoken to the Woodsman at least once.
  - **`awaiting_woodsman_talk`**: string checkpoint id (`after_chop`, `after_campfire`, `after_hunt`, `after_cook`) when the player must return to the NPC.
  - **`quest_campfire_state_id`**: string `fire_state_id` of the player-placed campfire used for the cooking lesson.
  - **`campfire_placed`**: bool — stage-3 placement objective met.
  - **`cooked_on_quest_fire`**: bool — cooking lesson objective met.
  - **`blacksmith_met`**: bool — player has started the blacksmith quest at least once.
  - **`awaiting_blacksmith_talk`**: string checkpoint id (`after_mine`, `after_smelt`, `after_hatchet`) when the player must return to the Blacksmith.
  - **`blacksmith_tongs_granted`**: bool — tongs granted after the mining lesson talk.
  - **`blacksmith_hammer_granted`**: bool — hammer granted after the smelting lesson talk.
  - **`crafted_ingot_bronze`**: bool — player smelted bronze during the blacksmith quest (stage 1).
  - **`crafted_hatchet_bronze`**: bool — player forged a bronze hatchet during the blacksmith quest (stage 2).
- **`completed_quest_ids`**: array of completed quest id strings.

Missing `quest_progress` defaults to an empty dictionary. `QuestService` owns runtime updates and syncs through `GameState`.

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
