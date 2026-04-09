# RuneForged Combat Spec

## Core expectations
- Combat should be responsive and readable.
- Enemy behavior should be state-driven where practical.
- Damage, armor, status effects, and rune effects should be separated from UI and presentation.

## Constraints
- Preserve signal names and public APIs unless intentionally changing a contract.
- New combat features should avoid rewriting unrelated systems.
- Call out dependency impact before changing shared formulas.