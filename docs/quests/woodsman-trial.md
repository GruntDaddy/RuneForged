# Woodsman's Trial (tutorial quest)

Quest id: `woodsman_trial`  
NPC: Woodsman in Jorvik (`world/regions/jorvik/npcs/woodsman.tscn`)

## Stages

| # | Id | Auto-complete | Woodsman talk |
|---|-----|---------------|---------------|
| 0 | hatchet | ≥1 `logs` | Start: hatchet + intro |
| 1 | materials | 5 `logs` + 5 `stone` or `campfire_kit` | After chop: 5 `stone` + forge hint |
| 2 | campfire | Place `campfire_kit` (player `placed_fire_nodes`) | After place: bow + quiver + 20 wood arrows |
| 3 | hunt | 3 rabbit kills + ≥3 `meat_raw` on return | After hunt: cooking lesson |
| 4 | cook | `meat_cooked` on quest campfire `fire_state_id` | After cook: 10 arrows + 2 `health_potion_small` |

## Save key

`game_state.quest_progress` — see [save-format.md](../save-format.md).

## Manual QA

1. Fresh save → no journal until first Woodsman talk.
2. Chop one tree → journal stage 2 → talk → receive 5 stone.
3. Craft campfire kit, place it → static Props campfire does not count.
4. Talk → bow bundle; kill 3 rabbits; return with 3+ meat.
5. Cook on **your** placed fire → finale rewards; potion heals on hotbar use.
6. Save/load at each checkpoint.
