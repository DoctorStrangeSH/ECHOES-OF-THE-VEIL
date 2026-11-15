# M6 test plan — content production pipeline

## Exit gate: "a second region can be produced faster and with fewer bespoke code changes than the first"

Lighthouse Point was built with the M6 pipeline only:

| | Greyford block (M1–M5) | Lighthouse Point (M6) |
|---|---|---|
| GDScript changed for the region | location registry, loaders, enemy table, scene generator outside the repo | **none** |
| Scene | hand-written Python spec | 40-line JSON spec using templates (`building`, `fixture`, `sign`, `scatter`, `anchors`) |
| Content | edits to shared files | own files: `npcs_lighthouse`, `items_lighthouse`, `jobs_lighthouse`, `facts_lighthouse`, `dialogue/lighthouse`, `journal/lighthouse`, `m6_lighthouse` strings (≈450 lines in total) |
| Links into the old region | — | 3 nodes in `greyford_block.json`, 1 branch in the archive shelves, 1 line for Jonah |
| Checked by | tests written per feature | validator, graphs, budgets and the existing test suite, unchanged |

## Automated

- `python3 tools/validate_content.py` — 0 errors, 0 warnings (also in CI).
- `python3 tools/validate_assets.py` — license guard (CI); texture/placeholder/palette checks with the art present.
- `python3 tools/loc.py status` — en/ru complete, placeholders consistent.
- `python3 tools/content_graphs.py --check` — diagrams in `docs/generated/` up to date.
- `python3 tools/regions/build_regions.py --check` (needs art) — every scene matches its JSON spec; the five older scenes rebuild byte-for-byte from JSON.
- `tests/test_runner.tscn` — location budgets, self-registering locations, prefix merging (no false matches such as `factions.json` for `facts`), enemy variants from data.
- `tests/smoke_test.tscn` — travels to Lighthouse Point, meets Wren, counts the light at night, finds the register, resolves the case, returns to Greyford.

## Manual

1. From the harbour promenade, walk to the far west end: "Down to Lighthouse Point". The way back is at the east end of the beach path.
2. Meet Wren by the lighthouse (day), on the bench (evening) or on the sea wall (night).
3. Ask what the light counts; at night, inspect the end of the sea wall. Before dark it tells you to come back.
4. Read the harbour registers on the archive shelves — or wait two days for the fail-forward help.
5. Answer Wren both ways on two saves: "real" keeps her on the sea wall at night and lets Jonah mention the ship a period later; "fault" pays £10, and she no longer keeps watch.
6. Salvage the junk on the beach, pick up two pieces of sea glass, sell them to Jonah (£1 each).
7. The sea-wall lamp job appears on the board after meeting Wren.
8. Russian: every new line translated, no gendered forms for the player.
