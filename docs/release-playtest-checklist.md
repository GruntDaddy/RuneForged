# Release playtest checklist (repeat each stable)

Use this list on the **exact tagged commit** you intend to ship. Check items only after they pass. Prioritize **save compatibility**, **inventory/equipment**, and **boot stability** over polish.

**Docs:** [save-format.md](save-format.md) · [item-schema.md](item-schema.md) · [combat-spec.md](combat-spec.md)

---

## A. Project and boot

- [ ] Clean checkout (or confirm no required uncommitted files).
- [ ] Godot version matches [`project.godot`](../project.godot) `config/features` (currently **4.6**).
- [ ] Project scan / fix broken resource or script references.
- [ ] Boot: `res://ui/boot_splash/splash_boot.tscn` → main menu → start or load without crash.

## B. Save / load loop

- [ ] New game → play briefly → **save** → quit → relaunch → **load** → state matches (inventory + equipment + hotbar).
- [ ] If a **legacy save** exists for regression: load → save again → reload.

## C. Inventory and equipment

- [ ] Move/stack items; verify counts respect `ItemData.max_stack` behavior.
- [ ] Equip **backpack** (if applicable): slots **28–41** usable only with back slot filled; unequip backpack and confirm extra slots lock / items handled per design.
- [ ] **Tacklebox** (if applicable): open tackle grids, save, reload, data intact per [save-format.md](save-format.md).

## D. Combat (spot-check)

- [ ] **Melee** vs a creature: combo advances, hits register, no soft-lock in attack state.
- [ ] **Ranged:** fire bow with mixed `ammo_arrow_*` stacks—confirm **cheapest ammo consumes first** (see [combat-spec.md](combat-spec.md)).
- [ ] **Unarmed** hit registers when intended.

## E. Regression focus (since last tag)

- [ ] Skim `git diff <last-tag>..HEAD --stat` and add **3–5** checks for areas that changed most (autoload, UI, world).

## F. Export smoke (if shipping binaries)

- [ ] Export with your **release** preset(s); document names in [exports.md](exports.md).
- [ ] Run exported build: reaches gameplay and save/load once.

---

## Sign-off

| Role | Name | Date |
|------|------|------|
| Tester | | |
