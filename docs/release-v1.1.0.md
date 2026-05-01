# Stable release v1.1.0 — audit record

This document implements the main-branch stable audit for **RuneForged v1.1.0**, relative to baseline tag **`v1.0.0`** (`fb091dd4131520f75fc99c77ffb831461cc66213`).

## 1. Release bar (scope, stop-ship, known debt)

### Ship scope (this stable)

- **Primary platform:** Desktop (Godot 4.6, Forward Plus per [`project.godot`](../project.godot)).
- **Content focus:** Tutorial isle and integrated systems exercised since v1.0.0 (inventory, equipment, backpack slots, crafting/build menus, harvesting, combat vs wildlife, ranged ammo/quiver, campfires/torches, day/night and fires where persisted).
- **Mobile / virtual joystick:** Included in project addons; treat as **best-effort** for this milestone unless a dedicated mobile preset is added to export presets and smoke-tested.

### Stop-ship rules

Ship-blocking if observed on a **clean** checkout of the tagged commit:

1. Crash or hang before playable state from boot scene (`res://ui/boot_splash/splash_boot.tscn`).
2. New save → play → **save** → quit → **load** fails or corrupts inventory/equipment/hotbar.
3. Equipment or inventory rules violate documented contracts (e.g. backpack-gated slots 28–41 per [save-format.md](save-format.md)).
4. Hard progression blockers in the intended tutorial path with no workaround.

### Known debt (acceptable for v1.1.0; re-triage next milestone)

- **`docs/combat-spec.md`** has **no file changes** since v1.0.0 while combat code changed substantially — **spec drift**; follow-up: align doc with melee combos, ranged ammo, and creature combat or mark sections as non-normative.
- **Export presets** are not tracked in this repository; reproducible builds depend on local **`export_presets.cfg`** — document preset name(s) used for any published zip.
- **Godot CLI** was not available on the audit machine PATH; automated headless smoke was **not** run here — perform manual smoke (section 4) in the Godot editor before publishing builds.

---

## 2. Mechanical baseline (v1.0.0 → main)

### Baseline tag

- **Previous stable:** `v1.0.0` at `fb091dd41` — *chore: update project structure and remove debug logs*.

### High-risk paths (commits touching persistence and catalogs)

Since `v1.0.0`, diff concentration (not exhaustive):

| Area | Notes |
|------|--------|
| [`autoload/inventory_service.gd`](../autoload/inventory_service.gd) | Large expansion (backpack, tackle, stacking). |
| [`autoload/game_state.gd`](../autoload/game_state.gd) | Skills, fires, placed fires, warmth, legacy ID normalization. |
| [`autoload/item_catalog.gd`](../autoload/item_catalog.gd) / [`recipe_catalog.gd`](../autoload/recipe_catalog.gd) / [`crafting_service.gd`](../autoload/crafting_service.gd) | New autoload surface area for items and crafting. |
| [`autoload/save_manager.gd`](../autoload/save_manager.gd) | **No diff** vs v1.0.0 — behavior changes flow through `GameState` / payload shape; still validate save/load manually. |
| [`docs/save-format.md`](save-format.md) | Updated (+45 lines vs v1.0.0 baseline). |
| [`docs/item-schema.md`](item-schema.md) | Updated (+38 lines vs v1.0.0 baseline). |
| [`project.godot`](../project.godot) | Features `4.6`, autoload list growth — verify editor version matches team. |

To reproduce the audit window locally:

```text
git log v1.0.0..main --oneline
git diff v1.0.0..main --stat -- autoload/ docs/save-format.md docs/item-schema.md
```

---

## 3. Contract audit (docs vs implementation)

### Save format ([save-format.md](save-format.md))

- **Inventory v2:** 42 slots, tackle payload on `tool_tacklebox`, backpack slot rules — documented; **verify** in-game with tacklebox and backpack equip/unequip + reload.
- **Game state keys:** Skills, time/moon, fires, warmth, campfire tuning — documented with legacy defaults in `GameState.from_dict()` — **verify** torch/campfire flows and reload.
- **Equipment / hotbar:** Normalization via `GameState.normalize_item_id` — **verify** old saves if samples exist.

### Item schema ([item-schema.md](item-schema.md))

- Canonical IDs, ammo arrows, `ItemCatalog` indexing, tackle tags — consistent with autoload additions — **verify** pickups and crafting use catalog ids (no stale renamed props).

### Combat spec ([combat-spec.md](combat-spec.md))

- **Unchanged file vs v1.0.0** while code gained melee combos, ranged arrows, animal combat — **contract gap**: gameplay acceptance only; doc refresh recommended post-release.

---

## 4. Godot smoke checklist (manual)

Perform on the **exact tagged commit** before distributing builds:

1. Fresh clone or `git clean -fdx` (only if safe) / confirm no uncommitted deps.
2. Open project in **Godot 4.6** (match `config/features`).
3. **Project → Scan** (or equivalent) and resolve broken resource/script references.
4. Run main scene: boot → main menu → **new game** (or load test save).
5. **Save loop:** change inventory/equipment → save → quit → relaunch → load → confirm state.
6. **Backpack:** equip/unequip back slot; confirm slots 28–41 lock/unlock per spec.
7. **Exports:** run **Export** using your **release** preset(s); confirm binary starts and matches editor smoke.

*CLI alternative when `godot` is on PATH:* from repo root, `godot --path . --headless --quit-after 2` (adjust flags per installed Godot version) as a quick sanity check — does not replace editor smoke.

---

## 5. Versioning and release notes

### Product version

- **`application/config/version`** in [`project.godot`](../project.godot): **1.1.0**.

### Git tag

- Create annotated tag **`v1.1.0`** on the release commit after this audit lands:

```text
git tag -a v1.1.0 -m "RuneForged v1.1.0 stable"
```

### Release notes (short)

**RuneForged v1.1.0** builds on **v1.0.0** with major gameplay and systems work: expanded inventory (including backpack and tackle), crafting/build flows, harvesting and skills, ranged ammunition and quiver support, campfire/torch and persistence-related game state, tutorial isle and environment updates, UI/inventory/hotbar improvements, and wildlife/combat iteration. Saves remain backward-compatible per [save-format.md](save-format.md); validate critical paths before publishing.

### Build identification

- **Release commit:** same as tag target — run `git rev-parse v1.1.0^{commit}` (annotated tag **`v1.1.0`**; message records engine + hash).
- **Engine:** Godot **4.6** (see `config/features` in `project.godot`).
