# ECHOES OF THE VEIL

A single-player, top-down pixel-art narrative RPG built with Godot 4.x.

> **Project status:** M2 — Greyford vertical slice. Character creator, six scheduled NPCs, branching dialogue, an investigation journal with evidence provenance and hypotheses, a day clock with weather, a main case with a meaningful choice, a local quest, and the first Veil echo with a short combat encounter. English and Russian.

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
2. Put your purchased LimeZu ZIP archives in one folder (outside this repo) and import them:
   ```
   python tools/import_limezu.py --source "C:/path/to/limezu-zips"
   ```
   This extracts the 16x16 art into `assets/limezu/` and generates ready-to-paint TileSets in `resources/tilesets/limezu/`. Both folders are git-ignored: the packs may be used in the game but not redistributed, so every developer imports their own copies. Add `--scales 16 32 48` to also import the larger variants. Pillow (`pip install pillow`) is recommended.
3. Open `project.godot` in Godot. The first import of ~34k textures takes a few minutes.
4. Press F5. Without the art packs the game still runs with coloured placeholders.

### Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD / arrows | Left stick / D-pad |
| Sprint | Shift | RB |
| Interact / next line | E, Enter, Space | A |
| Dialogue choice | 1–4, arrows + E, mouse | D-pad + A |
| Journal | Tab | Back |
| Strike (Veil only) | J, left mouse | X |
| Pause menu | Esc | Start |
| Quick save / load | F5 / F9 | — |

### Tests

```
godot --headless --path . --import
godot --headless --path . res://tests/test_runner.tscn
```
Exit code 0 means all tests passed. Manual checks: [M1](docs/technical/m1-test-plan.md), [M2](docs/technical/m2-test-plan.md). Story content map: [Greyford slice](docs/narrative/greyford-slice.md).

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

**M2 — Greyford vertical slice** (in review). Next: **M3 — Core RPG loop** (combat depth, inventory and equipment, enemy family, miniboss) and external playtests of the slice.

## License and third-party assets

The game's original code and original content license will be decided before public release. Third-party assets (including LimeZu packs) remain subject to their individual licenses and attribution requirements. Do not redistribute purchased source asset packs in this repository unless their license explicitly permits it.
