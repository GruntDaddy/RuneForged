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