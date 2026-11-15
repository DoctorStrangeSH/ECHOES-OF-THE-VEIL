# ECHOES OF THE VEIL

A single-player, top-down pixel-art narrative RPG built with Godot 4.x.

> **Project status:** M7 — Act II: the Echo Ward, a neighbourhood erased in 1962 and still lit; Jonah and Mara as companions; the Conductor; Rosalind. Before that, Act I: three incidents (a vanished storeroom, a flat that grows a room every week, the ghost tram stop), a map of streets that aren't there, and whose handwriting is on it. Earlier: M6 — content pipeline and a second region, Lighthouse Point (a keeper, a lighthouse that counts, a new case). Earlier: M5 — life and work: repair profession with a minigame, odd jobs for neighbours, scrap salvaging, crafting, Jonah's shop, room upgrades, rent, and a repair-cart business. Earlier: M4 — society: factions, NPC knowledge and gossip, relationship milestones, quest graphs with fail-forward, three character stories (Mara, Jonah, Nadiya) and the Municipal Archive. Earlier: M3 — core RPG loop on top of the Greyford slice: weapon combos, dodge, Lantern Flash, the Hollow enemy family, the Census Taker miniboss, inventory/equipment, Resonance and Attunements, generated sound effects. M2: Character creator, six scheduled NPCs, branching dialogue, an investigation journal with evidence provenance and hypotheses, a day clock with weather, a main case with a meaningful choice, a local quest, and the first Veil echo with a short combat encounter. English and Russian.

## High concept

A contemporary coastal city is built over the sealed infrastructure of a vanished civilization. When impossible places begin appearing inside ordinary buildings, the player discovers that the phenomenon is not an invasion from another world: it is the return of places, people, and choices that the city deliberately erased.

The player can investigate the mystery while building an independent life through exploration, relationships, professions, crafting, trade, and ownership. Personal ambition and the central mystery continually affect one another.

## Pillars

1. **A mystery worth solving:** layered revelations, fair clues, conflicting testimony, and consequences that reframe earlier events.
2. **A world worth inhabiting:** memorable NPCs with schedules, goals, relationships, and persistent memories.
3. **Freedom with consequences:** combat, investigation, crafting, trade, community work, and relationships all offer meaningful progress.
4. **Discovery over grind:** handcrafted story spaces combined with systemic expeditions and replayable endgame challenges.
5. **A coherent identity:** modern everyday life collides with ancient, uncanny fantasy; all visual additions must respect the purchased asset packs' licenses and style.

## Getting started

1. Install **Godot 4.7** (standard build, not .NET).
2. Clone with the private art submodule — the LimeZu sprites come along automatically, nothing to install:
   ```
   git clone --recurse-submodules https://github.com/DoctorStrangeSH/ECHOES-OF-THE-VEIL
   ```
   The art lives in a private repository (the packs may be used in the game but not redistributed publicly). Without access, the game runs with placeholders. To rebuild the art from the purchased ZIPs, see `docs/art/asset-pipeline.md`.
3. Open `project.godot` in Godot. The first import of ~34k textures takes a few minutes.
4. Press F5. Without the art packs the game still runs with coloured placeholders.

### Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD / arrows | Left stick / D-pad |
| Sprint | Shift | RB |
| Interact / next line | E, Enter | A |
| Dialogue choice | 1–4, arrows + E, mouse | D-pad + A |
| Journal | Tab | Back |
| Strike (Veil only) | J, left mouse | X |
| Dodge (Veil only) | Space, K, right mouse | B |
| Lantern Flash (Veil only) | Q | Y |
| Eat / drink | R | LB |
| Inventory | I | pause menu |
| Pause menu | Esc | Start |
| Quick save / load | F5 / F9 | — |

### Tests

```
godot --headless --path . --import
godot --headless --path . res://tools/check_scripts.tscn   # every script compiles
godot --headless --path . res://tests/test_runner.tscn     # unit tests
godot --headless --path . res://tests/smoke_test.tscn      # plays through the slice
```
Content checks (Python only, also in CI):
```
python3 tools/validate_content.py        # references, translations, dialogue reachability
python3 tools/validate_assets.py         # license guard (+ texture checks with the art)
python3 tools/loc.py status              # translation coverage
python3 tools/content_graphs.py          # regenerate docs/generated diagrams
python3 tools/regions/build_regions.py   # rebuild location scenes from data/regions (needs the art)
```
Exit code 0 means success; the smoke test must also print `SMOKE TEST FINISHED` with no `SCRIPT ERROR`. GitHub Actions runs all three on every pull request (`.github/workflows/tests.yml`). Manual checks: [M1](docs/technical/m1-test-plan.md), [M2](docs/technical/m2-test-plan.md), [M3](docs/technical/m3-test-plan.md), [M4](docs/technical/m4-test-plan.md), [M5](docs/technical/m5-test-plan.md), [M6](docs/technical/m6-test-plan.md), [M7 Act I](docs/technical/m7-act1-test-plan.md), [M7 Act II](docs/technical/m7-act2-test-plan.md). Making content: [authoring guide](docs/technical/content-authoring.md); diagrams: [dialogue](docs/generated/dialogue.md), [cases](docs/generated/cases.md). Story content map: [Greyford slice](docs/narrative/greyford-slice.md).

## Audio

Sound effects are synthesised by `tools/generate_sfx.py` (our own, committed in `assets/audio/sfx/`). Re-run the script after tweaking sounds.

## Technology

- Engine: Godot 4.7.
- Target: Windows PC / Steam first.
- Mode: offline single-player.
- Presentation: top-down 2D pixel art.

## Documentation

- [Game vision](docs/vision/game-vision.md)
- [Story and lore bible](docs/narrative/story-and-lore-bible.md)
- [World and quest design](docs/narrative/world-and-quest-design.md)
- [Gameplay systems design](docs/design/gameplay-systems.md)
- [Technical architecture](docs/technical/architecture.md)
- [Asset pipeline and licensing](docs/art/asset-pipeline.md)
- [Production roadmap](docs/production/roadmap.md)
- [Quality strategy](docs/production/quality-and-testing.md)
- [Release and audience strategy](docs/production/release-strategy.md)
- [Decision log](docs/DECISIONS.md)
- [M1 test plan](docs/technical/m1-test-plan.md)

## Production rule

Build and validate a small, compelling vertical slice before scaling content. A feature is not considered complete because it is documented or stubbed: it must be implemented, tested in-game, and reviewed against explicit acceptance criteria.

## Current milestone

**M7 — Campaign production** (in progress): the campaign spine, **Act I — The City Has Two Maps** and **Act II — The People We Misplaced** (the Echo Ward, companions, the Conductor) are playable; Acts II–V follow the [campaign plan](docs/production/campaign-plan.md). Done before: M6 content pipeline (regions as data, validators, Lighthouse Point).

## License and third-party assets

The game's original code and original content license will be decided before public release. Third-party assets (including LimeZu packs) remain subject to their individual licenses and attribution requirements. Do not redistribute purchased source asset packs in this repository unless their license explicitly permits it.
