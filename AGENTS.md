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

## High-priority constraints
- Godot 4.x only
- Preserve save compatibility
- Keep gameplay logic out of UI when possible
- Do not create new global systems casually
- Ask before large refactors