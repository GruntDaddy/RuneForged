# RuneForged Agent Guide

## What this project is
RuneForged is a Godot 4 action RPG with itemization, runes, combat systems, UI-driven inventory and equipment flows, and persistent save data.

## How to work in this repo
1. Read the relevant files before editing.
2. Read docs specifications when changing systems tied to combat, items, or save data.
3. Make the smallest change that satisfies the request.
4. Preserve existing APIs and scene wiring unless explicitly told otherwise.
5. After editing, explain assumptions, risks, and test steps.

## Source-of-truth docs
- docs/game-pillars.md
- docs/combat-spec.md
- docs/item-schema.md
- docs/save-format.md

## Stable releases and versioning
- **Tagged releases:** git tags `v*.*.*` (annotated) mark stable checkpoints on `main`.
- **Per-release audit notes:** `docs/release-vX.Y.Z.md` (example: [docs/release-v1.1.0.md](docs/release-v1.1.0.md)).
- **Human QA checklist (reuse each milestone):** [docs/release-playtest-checklist.md](docs/release-playtest-checklist.md).
- **Exports / build presets:** [docs/exports.md](docs/exports.md).
- **Player-facing history:** [CHANGELOG.md](CHANGELOG.md).
- **Automated sanity:** `.github/workflows/godot-smoke.yml` runs a short headless Godot pass on push/PR (not a substitute for editor QA).

## High-priority constraints
- Godot 4.x only
- Preserve save compatibility
- Keep gameplay logic out of UI when possible
- Do not create new global systems casually
- Ask before large refactors