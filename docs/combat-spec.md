# RuneForged Combat Spec

High-level design rules and **where combat lives in code**. Exact numbers are tuned in scenes and `@export` fields; when balance changes, update this doc only when behavior or player-facing rules change (not every stat tweak).

## Core expectations
- Combat should be responsive and readable.
- Enemy behavior should be state-driven where practical.
- Damage, armor, status effects, and rune effects should be separated from UI and presentation.

## Authoritative code touchpoints
- **Player controller (combat + ranged + harvest overlap):** [`entities/characters/player/player.gd`](../entities/characters/player/player.gd) — creature melee sweeps, arrow firing, reticle/aim exports, unarmed damage vs tool damage.
- **Rig / animation + melee combo stepping:** [`entities/characters/base_character/base_character.gd`](../entities/characters/base_character/base_character.gd) — one-handed melee combo sequence, combo timeout, bow meshes, `try_play_melee_attack_1h()`.
- **Damage and mitigation math:** [`systems/combat/combat_formula_service.gd`](../systems/combat/combat_formula_service.gd) (and call sites in the player / creatures). Keep formula changes centralized here when possible.
- **Rune combat effects:** [`systems/magic/rune_effect_service.gd`](../systems/magic/rune_effect_service.gd) — do not fold rune logic into UI nodes.

## Player melee (one-handed)
- Melee against creatures uses a **forward cone / reach** check on the player (see `melee_reach_distance`, `melee_hit_radius`, `melee_forward_dot_min` on the player). Hits align with **animation impact timing** when `melee_creature_impact_delays_sec` is set; otherwise damage applies on the confirmed swing path.
- **Combo chains** are owned by `BaseCharacter`: a repeating sequence of 1H attack clips, advanced with `try_play_melee_attack_1h()`, reset after `melee_combo_reset_seconds` of inactivity.

## Ranged (bow)
- Arrows are **stackable item ids** (`ammo_arrow_*` per [item-schema.md](item-schema.md)). The player resolves **which stack to consume** with a **cheapest-first** order (wood → common → bronze → iron) so higher-tier ammo is preserved when possible—documented in code as `_ARROW_AMMO_IDS_CONSUME_ORDER` in the player script.
- Firing spawns a **projectile scene** (e.g. `arrow_projectile`); aim distance, speed, gravity, and collision mask are player `@export` fields. Quiver/back equipment is handled with the broader equipment/inventory systems—not duplicated in UI.

## Unarmed
- When no weapon clip applies, unarmed creature hits use **`unarmed_melee_damage`** vs **`tool_melee_damage`** for tools—tuning lives on the player; avoid duplicating those constants downstream.

## Creatures and wildlife
- Wild animals use dedicated scenes/scripts under [`entities/`](../entities/) with **state-driven** loops (idle, flee, hit reactions, leash/spawn constraints where authored). Treat creature combat as **environment content**: leash radius, fall recovery, and health bar UX should remain data-driven or exported where reasonable.
- Drops and loot use the same **item id + count** rules as other pickups ([item-schema.md](item-schema.md) pickup contract).

## Constraints
- Preserve signal names and public APIs unless intentionally changing a contract.
- New combat features should avoid rewriting unrelated systems.
- Call out dependency impact before changing shared formulas.