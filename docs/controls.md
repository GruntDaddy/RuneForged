# RuneForged Controls

Keyboard bindings live in **Project → Project Settings → Input**. Xbox and PlayStation controllers use the same SDL button layout; gamepad events are registered at boot by `systems/input/gamepad_bindings.gd` (called from `GameState._ready`).

## Movement & camera

| Action | Keyboard | Gamepad |
|--------|----------|---------|
| Move | W A S D | Left stick |
| Run | Shift | L3 (left stick click) |
| Jump | Space | A / Cross |
| Sneak / roll | Ctrl | B / Circle |
| Swim down | Ctrl | LT (light hold; full pull blocks) |
| Look | Mouse | Right stick |
| Zoom | Mouse wheel | Light LT / RT pull (partial, not full attack/block) |

## Combat & tools

| Action | Keyboard | Gamepad |
|--------|----------|---------|
| Attack | LMB | RT |
| Block | RMB | LT |
| Interact | E | X / Square |
| Interact alt | F | Y / Triangle |
| Interact extra | R | RB |
| Interact extra | G | LB |
| Hotbar 1–4 | 1–4 | D-pad Up / Left / Down / Right |

## Menus

| Action | Keyboard | Gamepad |
|--------|----------|---------|
| Pause / close menu | Esc | Menu (Start) |
| Character / Vitals | Tab | R3 |
| Inventory | I | View / Share (Back) |
| Craft (Forge) | C | Paddle 1 (Misc1), or **Menu + D-Left** |
| Build (modular) | B | Paddle 2 (Misc2), or **Menu + D-Right** |

## Placement modes

| Action | Keyboard | Gamepad |
|--------|----------|---------|
| Place | E | X |
| Cancel build ghost | RMB | B |
| Rotate piece | Mouse wheel | LB / RB |
| Modular floor ↓ / ↑ | [ / ] | D-pad Down / Up |
| Modular demolish | X | X |
| Dialogue continue | Click / Enter | A |

UI navigation uses the left stick and **A** to confirm / **B** to back (`ui_accept` / `ui_cancel`).
