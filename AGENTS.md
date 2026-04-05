# AGENTS.md

## Project Overview

RuneForged is a 3D action-RPG built with **Godot Engine 4.6** (Forward Plus renderer, Jolt Physics). It is a single Godot project with no backend services, databases, or package managers. All addon dependencies (Terrain3D, Inventory System) ship pre-compiled native binaries in the repo.

## Cursor Cloud specific instructions

### Engine requirement

Godot 4.6 must be installed at `/usr/local/bin/godot`. The update script handles downloading and installing it automatically from GitHub releases.

### Running the game

```bash
export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/runtime-ubuntu
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json
cd /workspace
godot
```

The cloud VM has no GPU — rendering uses Mesa llvmpipe (software Vulkan). This works but is slow; expect lower frame rates. Audio will fall back to a dummy driver (no audio hardware), which is harmless.

### Running the editor

```bash
DISPLAY=:1 XDG_RUNTIME_DIR=/tmp/runtime-ubuntu VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json godot --editor
```

### Headless validation (CI-style)

- **Import project:** `godot --headless --import` — reimports all assets; useful after asset changes.
- **Check a single script:** `godot --headless --check-only --script <path>` — parses one GDScript file. Note: scripts referencing autoload singletons (`GameState`, `SceneManager`, `SaveManager`) will fail in isolation; this is expected.
- **Quick open/close:** `godot --headless --quit` — verifies the project loads without errors.

### GDScript linting

There is no standalone GDScript linter outside the Godot editor. Use `godot --headless --check-only --script <file>` for individual files. Scripts that depend on autoload singletons or GDExtension types will report errors when checked in isolation — this is a Godot limitation, not a code bug.

### Automated tests

The `addons/inventory-system-demos/tests/` directory contains test suites for the inventory system addon. These tests require the full Godot scene tree and GDExtension native types, so they must be run inside the engine, not headlessly via `--check-only`.

### Key gotchas

- The project uses `window/size/mode=4` (fullscreen). When running in the cloud VM via `DISPLAY=:1`, the game renders at the Xvfb resolution.
- `mesa-vulkan-drivers` and `mesa-utils` must be installed for the software Vulkan renderer (lvp) to work.
- The `VK_ICD_FILENAMES` env var must point to `/usr/share/vulkan/icd.d/lvp_icd.json` to select the lavapipe software Vulkan driver.
