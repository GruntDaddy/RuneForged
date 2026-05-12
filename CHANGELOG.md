# Changelog

All notable changes for packaged milestones are summarized here. Internal refactors may be omitted; see `git log` for full history.

## [Unreleased]

- Modular building: press **[B]** for the categorized medieval village kit builder (2 m grid, ground + upper floor; pick a piece from the list first, then mouse-look to aim; place with **E**, demolish own pieces; **[** / **]** floor, **X** demolish toggle, wheel rotates). New `game_state.placed_modular_build_pieces` save array; overworld `GameState.region` may be inferred from the active scene when empty so placement validates. **[B]** no longer opens the forge “Building” tab directly (use **Forge** from the **[C]** craft menu for campfire/torch placement UI).
- Tutorial isle: gear/materials/props pickups use `world/pickups/*_pickup.tscn` wrappers; added `wood_planks` material and aligned `pickup_scene_path` on affected items (torch pickup scene is now the gltf wrapper, not `torch_light.tscn`).

## [1.1.0] — stable audit tag

**Baseline:** `v1.0.0`. Full audit notes: [docs/release-v1.1.0.md](docs/release-v1.1.0.md).

### Highlights

- Inventory expansion: backpack-gated slots, tacklebox payloads, stacking and catalog-driven ids ([save-format.md](docs/save-format.md), [item-schema.md](docs/item-schema.md)).
- Crafting and building menus; skill checks for crafting; item/recipe catalogs as autoloads.
- Game state: skill registry, day/night + moon, campfire/torch and placed-fire persistence, warmth buffs, legacy item id normalization.
- Tutorial isle and environment updates; sky/day-night tuning.
- Combat iteration: melee combos (1H sequence), ranged bow with tiered `ammo_arrow_*` consumption order, wildlife behaviors and loot.
- UI: inventory layout, hotbar, equipment and tooltip flows.

### Documentation

- [docs/combat-spec.md](docs/combat-spec.md) expanded to match implemented combat systems.
- Reusable [release playtest checklist](docs/release-playtest-checklist.md) and [exports](docs/exports.md) guidance.

### Compatibility

- Saves: additive keys preferred; legacy fields and aliases documented in [save-format.md](docs/save-format.md). Validate critical paths before publishing builds.

[1.1.0]: https://github.com/GruntDaddy/RuneForged/compare/v1.0.0...v1.1.0
