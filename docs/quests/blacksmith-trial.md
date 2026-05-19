# Blacksmith's Trial (tutorial quest)

Quest id: `blacksmith_trial`  
NPC: Blacksmith in Jorvik (`world/regions/jorvik/npcs/blacksmith.tscn`)

**Prerequisite:** Complete `woodsman_trial`. The Woodsman finale and post-quest dialogue direct the player to the blacksmith down the road.

## Stages

| # | Id | Auto-complete | Blacksmith talk |
|---|-----|---------------|-----------------|
| 0 | mine | ≥1 `ore_copper` and ≥2 `ore_tin` | Start: `pickaxe_basic` ×1 + intro |
| 1 | smelt | Craft `ingot_bronze` (after tongs granted) | After mine: `tool_tongs` ×1 + smelter hints |
| 2 | forge_hatchet | Craft `hatchet_bronze` (after hammer granted) | After smelt: `tool_hammer` ×1 + anvil hints |
| 3 | finale | — | After hatchet: **3× `ingot_bronze`** + guidance to level smithing and craft `pickaxe_bronze` |

## Stations

Use world stations beside the blacksmith house (`jorvik_props.tscn`):

- **Smelter** — bronze ingot (2 tin ore + 1 copper ore)
- **Anvil** — bronze hatchet (2 bronze ingots, hammer in inventory)

Tin and copper rocks are in `jorvik_harvestables.tscn` near the forge (~137–168, ~151–217).

## Save key

`game_state.quest_progress` — see [save-format.md](../save-format.md).

## Manual QA

1. Fresh save → Blacksmith refuses until Woodsman trial is complete.
2. Complete Woodsman → finale mentions blacksmith down the road.
3. Talk to Blacksmith → receive pickaxe; mine 1 copper + 2 tin → journal checkpoint → talk → tongs.
4. Smelt bronze at Smelter → talk → hammer.
5. Forge bronze hatchet at Anvil → talk → 3 bronze ingots + pickaxe guidance; quest complete.
6. Optional: craft `pickaxe_bronze` at Anvil with hammer and 2 ingots.
7. Save/load at each checkpoint; Woodsman remains completed.
8. After completion, Blacksmith finale and idle talk mention the **healer** farther down the road (next tutorial NPC, not yet implemented).
