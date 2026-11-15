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

## M4 — Narrative and NPC foundation (implemented, in review)
**Build**
- evidence provenance and hypothesis journal;
- quest state graph and fail-forward handling;
- NPC knowledge, relationship milestones, semantic memory events;
- faction access and local world-state changes;
- 2–3 character stories.

**Exit gate:** choices produce visible, tested consequences; no critical clue is accidentally missable.

## M5 — Life, work, and ownership
**Build**
- day clock and weather;
- one profession loop (gardening or repair);
- one home/safehouse upgrade;
- small shop/business prototype;
- economy sources/sinks and exploit tests.

**Exit gate:** non-combat activities are rewarding and connect to NPC/world needs.

## M6 — Content production pipeline
**Build**
- reusable region templates;
- dialogue/quest authoring workflow;
- enemy and item data pipeline;
- localization workflow;
- asset validation tools and scene performance budgets.

**Exit gate:** a second region can be produced faster and with fewer bespoke code changes than the first.

## M7 — Campaign production
**Build**
- remaining acts and regions in a staged content plan;
- companion arcs and faction conflicts;
- handcrafted dungeons and boss encounters;
- multiple endings driven by evidence, relationships, and decisions.

**Exit gate:** full campaign is playable from new game to ending with save compatibility and no progression blockers.

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
