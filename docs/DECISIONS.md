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
| D-022 | One weapon discipline (3-hit combo with finisher) + one utility (Lantern Flash stun) + dodge with bounded i-frames; hit-stop/shake for feedback. | Accepted | Matches gameplay-systems.md combat scope; readable before flashy. |
| D-023 | Progression is horizontal: Resonance from echoes buys small Attunements; equipment modifies play style (combo shape, cooldowns), not big stat inflation. | Accepted | Keeps balance tractable and choices meaningful. |
| D-024 | Sound effects are synthesised by a committed script (no third-party samples). | Accepted | License-clean in a public repo; easy to iterate. |
| D-025 | Save schema 3 adds inventory, money, Resonance and Attunements (migration 2→3). | Accepted | |
| D-026 | Factions are standings per group (−10..10) moved by specific choices; no single morality meter. | Accepted | Story bible §6 and world-and-quest-design.md. |
| D-027 | NPC knowledge: facts with audiences spread one time-of-day period after being published; reactions read who knows. | Accepted | Consequences become visible and believable without simulating conversations. |
| D-028 | Cases declare stage transitions and fail-forward rules; tests verify reachability. | Accepted | Prevents soft-locks and missable critical clues. |
| D-029 | Save schema 4 adds faction standing, NPC knowledge and pending gossip (migration 3→4). | Accepted | |
| D-030 | The first profession is **repair** (not gardening): a timing minigame whose green zone grows with skill level (5 levels by XP). | Accepted | Fits Jonah's workshop, the "fix what's broken" theme and the town's broken objects; reuses world props. |
| D-031 | Economy rules are data (`data/economy/`) and checked by `Economy.validate()`: nothing can be bought and resold for profit, and no recipe outputs more value than its inputs at shop prices. | Accepted | Exploit tests from the M5 exit gate. |
| D-032 | Rent (£15 weekly) becomes debt when unpaid, collected later; there is no eviction or penalty. | Accepted | A money sink that never soft-locks or punishes a story-focused player. |
| D-033 | The business is a repair cart: price tier, stock and upgrades set daily customers, resolved deterministically at dawn; fair prices raise reputation. | Accepted | Small, testable business prototype linked to Jonah's relationship. |
| D-034 | Odd jobs: up to 3 a day, chosen deterministically from the day number; each pays money, XP and +1 with the client; some change the world (the fountain). | Accepted | Ties non-combat work to NPC needs (exit gate). |
| D-035 | Save schema 5 adds `life` (skill, jobs, stall, rent debt, home upgrades), migration 4→5. | Accepted | |

## Open questions

- What minimum PC specification should be targeted?
- Is controller support required for the first demo or only full release?
- Which languages beyond English and Russian are commercially justified?
