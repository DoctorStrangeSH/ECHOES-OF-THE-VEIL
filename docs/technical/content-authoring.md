# Content authoring guide

How to add places, people, stories and items to Echoes of the Veil without touching game code. Everything below is data in `data/` plus generated scenes; the tools check it before Godot ever runs.

## The loop

1. Edit JSON in `data/` (and `data/regions/` for places).
2. `python3 tools/regions/build_regions.py <region> --preview` — rebuilds the scene and draws `build/region_previews/<region>.png`.
3. `python3 tools/validate_content.py` — catches broken references, missing translations, unreachable dialogue.
4. `python3 tools/content_graphs.py` — refreshes the Mermaid diagrams in `docs/generated/` (reviewers read them on GitHub).
5. Run the game or the tests (see README).

CI runs steps 3–4 (in check mode), the asset license guard and the Godot tests on every pull request.

## How files are found

- **Locations** register themselves: every `scenes/locations/<id>.tscn` is a location with id `<id>`. Nothing to list anywhere.
- **Definitions** merge by file-name prefix (`DataFiles.defs`): `items.json` + every `items_*.json`. Put a region's content in its own files — `items_harbour.json`, `npcs_harbour.json`, `jobs_harbour.json`, `facts_harbour.json` — and nothing else changes. A duplicate id is an error.
  Prefixes: `data/items/items`, `data/characters/npcs`, `data/world/facts`, `data/world/factions`, `data/economy/jobs`, `data/economy/shops`, `data/economy/recipes`, `data/economy/home_upgrades`, `data/enemies/enemies`, `data/progression/attunements`.
- **Dialogue** (`data/dialogue/*.json`), **journal** (`data/journal/*.json`) and **strings** (`data/localization/*.json`) load every file in their folder.

## A region

`data/regions/<id>.json`:

```json
{
 "id": "lighthouse_point", "name_key": "LOC_LIGHTHOUSE_POINT", "palette": "lighthouse_point",
 "options": {"outdoors": true},
 "layout": {"generator": "bands", "width": 36, "bands": [["w", 4], ["o", 1], ["d", 13], ["g", 4]],
            "carve": [["s", 7, 15, 29, 2]]},
 "nodes": [ ... ]
}
```

- **layout**: rows of palette characters, or a generator — `bands` (horizontal stripes, then rectangles carved in) or `room` (`width`, `height`, `door_x`: walls, wall face, floor, doorway). Palettes live in `data/tiles/palettes.json`.
- **options**: scene settings — `outdoors`, `combat_enabled`, `fixed_tint` (`{"color": [r, g, b, a]}`), `enter_dialogue_id`, `enter_condition`, `camera_margin_tiles`.
- **nodes**: plain nodes or templates. Texture paths can use aliases from `data/regions/_aliases.json` (`@city/Bench_2.png`, `@beach/...`, `@bedroom/...`).

Plain node kinds: `prop`, `spawn`, `door`, `inspect`, `rest`, `anchor`, `npc`, `enemy` (`variant`), `boss`, `arena`, `encounter`, `pickup`, `spot` (repair), `screen` (shop/jobs/workbench/business), `junk`. Any node can take `show_if` (a StoryRules condition).

Templates (`tools/regions/templates.py`):

| Template | Makes |
|---|---|
| `building` | building single with collision sized from the art, optional `door` (and return spawn) or `inspect` at its front |
| `fixture` | a prop plus something to do at it (`use`: spot, screen, junk, inspect) |
| `sign` | a readable sign or poster (prop + "Read") |
| `row` | the same prop at several points (`at`: `[[x, y], ...]` or `{"xs": [...], "y": n}`) |
| `scatter` | decoration with no collision (shells, litter, birds) |
| `anchors` | NPC schedule anchors: `{"points": {"id": [x, y]}}` |

Add a template only when a pattern repeats across regions; anything specific to one place stays in its JSON.

The generator needs the private art submodule (it reads sprite sizes); the game does not. `--check` reports scenes that are out of date with their specs; `--format` rewrites specs one node per line for clean diffs.

**Linking regions**: a `door` node in each region pointing at a `spawn` in the other (`scene`, `spawn`). The validator fails on a door to a missing spawn.

## People

`data/characters/npcs_<region>.json` — name key, LimeZu premade or custom sheet, dialogue id, factions, schedule (`period`, optional `if`, `scene`, `anchor`, `facing`). The first matching schedule entry wins; no match means the NPC is elsewhere. Anchors are `anchor` nodes in the region.

## Dialogue

`data/dialogue/<file>.json`: `{ "<dialogue id>": {"entries": [{"if": cond, "node": id}], "start": id, "nodes": {...}} }`. A node has `speaker` (string key or `"player"`), `text`, then `next` or `choices` (`text`, optional `if`, `effects`, `next`; `next: null` ends). Entries are checked in order; the first true one is where the conversation starts.

Conditions and effects are listed at the top of `systems/story/story_rules.gd` (flags, evidence, case stages, time of day, weather, relationships, memories, items, money, factions, NPC knowledge, repair level / give and take items, money, Resonance, faction standing, tell and publish facts, open a shop or the jobs board, travel, save).

A `remember` effect needs a `MEM_<EVENT>` string — it is what the People tab shows.

## Cases (quests)

`data/journal/<file>.json` holds `cases`, `evidence` and `hypotheses`. A case declares `stages`, `first_stage`, `transitions` (allowed moves), `outcomes`, `"main": true` for the story spine, and optionally:
- `objectives`: per stage, `[{"id", "text", "done_if": cond | "progress": [conds], "need": n, "optional": bool, "reward": [effects]}]` — shown in the journal and on the HUD; rewards only on optional ones, paid once.
- `deadlines`: `[{"stage", "days", "outcome", "note", "effects"}]` — the case **fails** with that outcome if still at that stage after `days`. Side quests only.

**Never** `fail_forward` (D-052): nothing may advance because time passed, and the validator fails any stage that no player action reaches. Give important steps two or more player-driven routes instead. Evidence can `advance` a case when found; testimony can carry `"testimony": true, "truth": "authentic|edited|unreliable"`. Check the graph in `docs/generated/cases.md`.

## Items, jobs, shops, enemies

- Items: `category` (weapon, trinket, consumable, material, key), `value`, `stack`, `use`. Shops must not sell below buy-back value; recipes must not create value (the validator and `Economy.validate()` enforce both).
- Jobs: `client`, `spot` (a `spot` node in some region), `difficulty`, `scrap`, `pay`, `xp`, optional `requires`, `once`, `effects`.
- Enemies: `data/enemies/enemies*.json` — health, speeds, wind-up, range, scale, tint, Resonance, optional `ranged`, `sheet`, `damage`, `drop_chance`. Set `variant` on an `enemy` node. Bosses are still bespoke scenes.

## Strings and translation

Every player-facing key lives in `data/localization/*.json` with `en` and `ru`. Russian lines addressed to the player stay gender-neutral (the player picks pronouns).

```
python3 tools/loc.py status                 # coverage and placeholder checks
python3 tools/loc.py export ru ru.csv       # send to a translator (add --missing for only new strings)
python3 tools/loc.py import ru.csv          # write it back; rows with wrong %s/%d are refused
python3 tools/loc.py format                 # one string per line
```

## Budgets

`data/world/budgets.json` caps nodes, props, interactables, NPCs, enemies, painted tiles and instancing time per location; `test_location_budgets` prints every location's numbers. Raise a budget for one location deliberately, not the default.

## Assets

`python3 tools/validate_assets.py` fails if any image, audio or archive file is tracked in the public repo (LimeZu's license forbids redistribution). With the art submodule present it also checks that every referenced texture exists, placeholders match real sprite sizes and palette tiles are inside their tilesets.
