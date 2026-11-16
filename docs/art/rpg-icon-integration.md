# RPG Icon Pack Integration — Private Asset Workflow

## Received and inspected

| Archive | PNG files | Selected sprites | Original size | Attribution |
|---|---:|---:|---|---|
| `16x16 Weapons Icons.zip` (LimeZu) | 55 | 53 icons | 16×16 | LimeZu |
| `24x24 Swords.zip` (LimeZu) | 31 | 30 icons | 24×24 | LimeZu |
| `24x24 Shields.zip` (LimeZu) | 31 | 30 icons | 24×24 | LimeZu |
| `RPG_ARSENAL_V1.1.zip` (LimeZu) | 298 | 148 no-background icons | 32×32 | LimeZu |
| `Free - Raven Fantasy Icons.zip` (Clockwork Raven) | 6,580 | 2,192 unique 16×16 icons, **optional** | 16/32/64 | Credit appreciated |

Counts are archive-image counts, not unique item designs. The importer defaults to **261 curated icons** (53 + 30 + 30 + 148) and excludes the 2,192 Raven icons unless explicitly requested.

## License guardrails

The three LimeZu weapons/swords/shields product pages permit commercial project use and modification but **prohibit redistributing or reselling the art**. RPG Arsenal includes a request to credit LimeZu (`https://limezu.itch.io/`). Its archive has a license/requests text file; preserve the original. Clockwork Raven's page permits use and adaptation in games, including commercial games, but prohibits redistribution/sale of the icons as a separate asset product. See official sources:

- https://limezu.itch.io/weaponsprites
- https://limezu.itch.io/24x24swords
- https://limezu.itch.io/24x24shields
- https://limezu.itch.io/rpg-arsenal
- https://clockworkraven.itch.io/raven-fantasy-icons

**Do not upload original ZIPs or processed stand-alone icon libraries to this public repository.** Adapted icons still contain third-party artwork. The game may use these icons under the authors' project-use terms; keep game builds and attribution compliant. Art assets, whether public or private, must not be redistributed as an independent asset pack. The importer is safe to publish because it contains no copyrighted artwork.

## Import

1. Put your five original ZIP files in an **untracked private folder** outside the project, e.g. `../eotv-source-icons/`.
2. Install Pillow for Python: `python -m pip install Pillow`
3. From the repository root run:

```bash
python tools/import_rpg_icons.py --archives ../eotv-source-icons
```

4. Optional full Raven integration (much larger and with numeric filenames that need curation):

```bash
python tools/import_rpg_icons.py --archives ../eotv-source-icons --include-raven
```

Outputs go to `assets/third_party_icons/` (gitignored). Keep this directory local or distribute only as part of a permitted game build, never as a stand-alone download.

## Visual consistency specification

- UI inventory icon slots: **32×32 transparent canvas**; original pixel samples untouched, centered (16→32, 24→32).
- Nearest-neighbor pixel filtering in Godot; avoid bilinear scaling and rotation of sprites.
- Mild saturation adjustment (default 0.88) to reduce mismatch in the UI without repainting authors' original icon design.
- Preserve transparency and silhouettes. A 16×16 symbol will appear physically smaller within the 32×32 slot; if equal **apparent** size is required, set explicit per-family UI display scale or author a dedicated replacement. Do not casually upscale icon textures or blur them.
- For UI readability, standardize borders, tooltip spacing, rarity treatment, and hover states in the **UI frame**, not by painting a rarity border into each icon.
- Do not imply that icon sprites are animated, equipable 8-direction weapon sheets, or visible armor layers. These packs primarily supply item/interface art.

## Follow-up integration into item data

The importer writes a deterministic `manifest.json` mapping icon IDs to generated paths. Next implementation PR should add a Godot `IconRegistry` or a validated item `icon_id` property with fallback placeholder; map an initial 12 hand-curated item definitions and verify in inventory, shop, pickup and tooltip UI.

**Acceptance tests:** icons render at native pixel resolution in Godot; no stale/absent references; Russian/English tooltips show; fallback works without private art; credits page includes both authors; no licensed artwork gets committed to the public repository.

## Important limitation

This is a **consistent UI presentation pass and reproducible import pipeline**, not a repaint of every item into one bespoke art style. The source packs still have different illustration conventions. A full visual unification requires manual art direction and per-icon redraw decisions after a side-by-side visual review.
