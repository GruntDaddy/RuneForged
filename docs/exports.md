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

## Editor: Terrain3D vendor noise

The Terrain3D addon ships **demo** and **examples** trees that are not part of RuneForged gameplay. To keep the FileSystem dock focused on your content, the repo uses an **empty `.gdignore` file** in:

- `addons/terrain_3d/demo/`
- `addons/terrain_3d/examples/`

Godot hides those folders from the editor dock. To open a stock demo scene, delete or rename the `.gdignore` in that folder and reload the project. The `examples/terrain.tscn` flow may require the **Terrainy** editor plugin; that plugin is not enabled in `project.godot` by default.

When you create a local **`export_presets.cfg`**, add **export exclude filters** for the same paths so builds do not pack vendor demos (exact glob syntax depends on the Godot version; use the Export dialog’s “Filters to export non-resource files” / exclude list and mirror that in committed templates if you add `export_presets.example.cfg`).
