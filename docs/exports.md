# RuneForged exports (build presets)

Godot stores export presets in **`export_presets.cfg`** at the project root. This file is **not** in the repository by default (local/editor-specific paths, store keys, etc.). Use this page to name what “the stable build” means for each milestone.

## Team convention

Fill in the table when you cut a stable tag (copy row into `docs/release-vX.Y.Z.md` or link here).

| Stable tag | Preset name(s) in editor | Platform(s) | Notes |
|------------|---------------------------|---------------|-------|
| v1.1.0 | *(fill in)* | *(Windows / Linux / …)* | Match [`project.godot`](../project.godot) `config/features` (Godot **4.6**). |

## Optional reproducibility

1. **Sanitized preset template:** maintain `export_presets.example.cfg` with placeholder paths only, or commit **`export_presets.cfg`** after stripping signing keys and machine-specific absolute paths—review before commit.
2. **CI:** releases can stay manual; [`.github/workflows/godot-smoke.yml`](../.github/workflows/godot-smoke.yml) validates project load only—it does not replace export QA.

## Secrets

Never commit Android keystores, Steam SDK secrets, or API keys. Keep those in local-only overrides or CI secrets.
