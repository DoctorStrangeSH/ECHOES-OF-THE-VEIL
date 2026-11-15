# Production Roadmap

This roadmap is milestone-based, not a promise of fixed calendar dates. Estimates should be revised after the first playable slice and asset audit. A solo developer using AI assistance should expect a substantial multi-year project if the intended scope remains large.

## M0 — Pre-production foundation (done)
**Deliverables**
- repository structure and project vision;
- narrative / lore bible and story pillars;
- gameplay system outline;
- Godot architecture and conventions;
- asset intake and license process;
- quality plan, roadmap, release strategy.

**Exit gate:** scope is coherent, the first slice is small enough to build, and source assets are audited.

## M1 — Technical proof (implemented)
**Build**
- pinned Godot 4.x project;
- boot flow and main menu;
- player movement in eight directions;
- camera, collision, input settings;
- interaction contract and one test object;
- scene transition and spawn IDs;
- versioned save/load with backup.

**Exit gate:** clean launch, repeatable movement and interactions, save/load round-trip tests, no critical parser/runtime errors.

## M2 — Greyford vertical slice (implemented)
**Build**
- one polished city block, one interior, one short outdoor route;
- player character with a feasible customization subset;
- 5–8 named NPCs with schedules and distinct voices;
- dialogue, journal, one investigation chain;
- one local quest with a meaningful choice;
- first Veil breach and a short combat encounter.

**Exit gate:** 30–60 minute coherent experience; external testers understand the hook and can complete it without developer guidance.

## M3 — Core RPG loop (implemented)
**Build**
- health, damage, hit reactions, dodge / weapon feel;
- one weapon discipline and one utility ability;
- inventory, equipment, item definitions;
- one enemy family and one memorable miniboss;
- rewards and progression.

**Exit gate:** combat is enjoyable with placeholder art and remains readable with final effects.

## M4 — Narrative and NPC foundation (implemented)
**Build**
- evidence provenance and hypothesis journal;
- quest state graph (fail-forward was used here and is removed in M7e);
- NPC knowledge, relationship milestones, semantic memory events;
- faction access and local world-state changes;
- 2–3 character stories.

**Exit gate:** choices produce visible, tested consequences; no critical clue is accidentally missable.

## M5 — Life, work, and ownership (implemented)
**Build**
- day clock and weather;
- one profession loop (gardening or repair);
- one home/safehouse upgrade;
- small shop/business prototype;
- economy sources/sinks and exploit tests.

**Exit gate:** non-combat activities are rewarding and connect to NPC/world needs.

## M6 — Content production pipeline (implemented)
**Build**
- reusable region templates;
- dialogue/quest authoring workflow;
- enemy and item data pipeline;
- localization workflow;
- asset validation tools and scene performance budgets.

**Exit gate:** a second region can be produced faster and with fewer bespoke code changes than the first.

## M7 — Campaign production (in progress: Acts I–IV implemented — see campaign-plan.md)

Stages: M7a Act I · M7b Act II · M7c Act III · M7d Act IV (done) → **M7e quest system and challenge rework** (next) → M7f Act V and endings → M7g campaign pass.

### M7e — Quest system and challenge rework (next, before Act V)

Owner's direction (2026-11-15): the game must not play itself. No story progress or clue may arrive because time passed; no free hints; bosses cannot be skipped; mistakes have consequences. This replaces the fail-forward approach used in M2–M7c.

**Build**
- **Remove fail-forward** from every case (prologue to Act III) and the Act II/III boss skips. Each removed safety net is replaced by an alternative *player-driven* route — another witness to persuade, a document to find, a door to force, a favour to buy — or, where no route fits, by accepting that the step can be failed (see below).
- **Objectives.** Every quest stage lists explicit objectives built from conditions (talk to, find, defeat, bring, judge, reach a standing), with progress counters ("residents heard 2/3"). Optional objectives with their own rewards. Hidden objectives revealed by exploring, never by waiting.
- **Quest offers.** Side quests are offered by people and can be declined; some need standing, skills, items or money to accept.
- **Failure as an outcome.** Quests can fail: deadlines in days, a rival faction getting there first, a wrong verdict, a broken promise, a companion who walks away. Failure is recorded, has consequences in later acts and endings, and is never undone by reloading the world state silently.
- **Rewards that depend on how well you did** — optional objectives, correct verdicts, people helped — not just on finishing.
- **Tracking without hand-holding.** Pin one quest; the HUD shows its current objective text. No waypoint arrows or markers; the journal describes places the way people would.
- **Challenge.** Difficulty chosen at new game (Story / Normal / Hard; Normal and Hard have no assists). Bosses are mandatory. Fainting costs something (money and carried Resonance dropped where you fell, recoverable once). Enemy and boss tuning pass.
- **Tooling.** The validator rejects `fail_forward` and time-based progress; checks that every main-quest stage has at least one player action that completes it and that every failable quest has a failure outcome in data; tests that waiting 30 days at any stage changes nothing.

**Exit gate:** a full playthrough of Acts I–IV where (1) waiting never advances anything, (2) every boss must be beaten, (3) at least a quarter of side quests can be failed with lasting consequences, (4) every main-quest step is completable by player action, and (5) saves from M7d load into the new quest model.
**Build**
- remaining acts and regions in a staged content plan;
- companion arcs and faction conflicts;
- handcrafted dungeons and boss encounters;
- multiple endings driven by evidence, relationships, and decisions.

**Exit gate:** full campaign is playable from new game to ending with save compatibility and no progression blockers (a failed or wrong choice is a consequence, not a blocker).

## M8 — Endgame
**Build**
- repeatable expeditions with meaningful modifiers;
- world incidents and boss rematches with distinct mechanics;
- post-ending world states;
- long-term crafting / collection goals;
- optional New Game Plus only if it adds meaningful variation.

**Exit gate:** endgame offers distinct decisions and encounters, not merely inflated enemy health or repetitive chores.

## M9 — Release readiness
**Build**
- accessibility and control polish;
- performance and memory budgets;
- localization review;
- credits and license compliance;
- Steam demo, trailer, screenshots, store copy;
- crash reporting / support process and release candidate testing.

**Exit gate:** stable release candidate, verified builds, no critical save corruption or progression blockers, store assets and legal notices reviewed.

## Scope control

For each milestone maintain:
- must-have;
- should-have;
- explicitly deferred;
- risks / dependencies;
- acceptance tests;
- playable build reference.

If a feature does not strengthen the core promise or vertical slice, defer it. Do not add multiplayer, large procedural worlds, or dozens of classes before the first slice proves the core loop.
