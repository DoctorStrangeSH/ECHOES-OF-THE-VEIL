# Project Decision Log

Decisions are recorded with date, status, and rationale. Revisit only when evidence or constraints materially change.

| ID | Decision | Status | Rationale |
|---|---|---|---|
| D-001 | Build a standalone ECHOES OF THE VEIL project; do not mix with other game repositories. | Accepted | Independent identity and clean production history. |
| D-002 | Godot 4.x, top-down 2D pixel art. | Accepted | Matches the intended asset workflow and scope. Exact minor version remains to be pinned. |
| D-003 | Single-player, offline-first, Windows / Steam as first target. | Accepted | Keeps production focused and avoids MMO/network complexity. |
| D-004 | Modern everyday setting collides with ancient supernatural mystery. | Accepted | Makes use of modern LimeZu environment packs while creating a distinctive narrative hook. |
| D-005 | Customizable player character. | Accepted, feasibility-gated | Scope of customization depends on the actual purchased sprite layers and animation coverage. |
| D-006 | Purchased LimeZu packs are third-party assets with pack-specific license terms. | Accepted | Audit each archive and license before import or distribution. |
| D-007 | Build a polished Greyford vertical slice before expanding to multiple regions. | Accepted | Validates the core hook and production pipeline early. |
| D-008 | Main story centers on the Lattice, the Quiet Census, and the ethics of restoring erased memories/communities. | Proposed canon v0.1 | Provides a mystery with human stakes and multiple defensible resolutions. |
| D-009 | No runtime generative-AI dependency for NPC dialogue or core progression. | Accepted for launch | Protects offline play, authorial consistency, cost, and reliability. |
| D-010 | Premium single-player business model; no mandatory online monetization. | Proposed | Best fit for a complete narrative RPG; price to be validated later. |
| D-011 | Pin Godot **4.7**. | Accepted (2026-11-14) | Version installed on the development machine. |
| D-012 | 16x16 is the canonical tile scale; 480x270 base resolution, `canvas_items` stretch with integer scaling, nearest filtering. | Accepted | All five LimeZu packs ship 16x16; 480x270 scales cleanly to 1080p/1440p/4K; canvas_items keeps UI text crisp. |
| D-013 | LimeZu packs are imported locally by `tools/import_limezu.py` into git-ignored folders; the public repo never contains pack files. | Accepted | Pack licenses allow use in the game but forbid redistribution. The game runs with placeholders when packs are absent. |
| D-014 | Character look = LimeZu Character Generator layers (body, eyes, outfit, hairstyle, accessory) stored as IDs in `CharacterAppearance`. | Accepted | Layer alignment verified on the 16x16 sheets (16x32 frames; idle row 1, walk row 2; right/up/left/down). Enables the character creator in M2. |
| D-015 | Player-facing text lives in `data/localization/*.json` (en, ru) loaded at runtime. | Accepted | Diff-friendly, export-safe, no CSV import step. |
| D-016 | Saves: JSON envelope with schema_version, temp-file write, verified read-back, rotating `.bak`, corrupt files preserved. | Accepted | Meets the save-integrity bar in quality-and-testing.md. |
| D-017 | Story logic is data: conditions/effects (`StoryRules`) shared by dialogue, schedules, journal and conditional objects; content in `data/` JSON. | Accepted | Writers can add branches without code; tests validate every reference. |
| D-018 | Evidence kinds observed / reported / recorded; hypotheses are inferred, then corroborated by *independent sources* (one source per person/document). | Accepted | Implements the story bible's fairness rules and the journal labels from world-and-quest-design.md. |
| D-019 | Time advances only while the player can act (1 game minute per real second); NPCs follow four period blocks; story changes apply after a conversation ends. | Accepted | Prevents missed story moments; cheap coarse simulation. |
| D-020 | Combat is enabled per location (`combat_enabled`); the town is non-violent. Fainting is fail-forward (wake at home, defeated enemies stay defeated). | Accepted | Keeps the town a social space; no punishing reloads. |
| D-021 | Save schema 2 adds profile, relationships, NPC memory, journal and clock, with an automatic migration from schema 1. | Accepted | Exercises the migration path early. |

## Open questions

- What minimum PC specification should be targeted?
- Is controller support required for the first demo or only full release?
- Which languages beyond English and Russian are commercially justified?
