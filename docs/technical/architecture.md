# Technical Architecture — Godot 4.x

## Status and constraints

The repository began empty. This document describes the intended architecture; it does not claim that a Godot project or playable systems have been committed. Pin the exact Godot 4 minor version after checking the developer environment and CI runner. Do not upgrade engine versions casually mid-milestone.

## Architectural principles

- Prefer small, testable scenes and scripts with one responsibility.
- Use typed GDScript and explicit resource schemas.
- Use stable string IDs for persistent content references.
- Keep content data separate from runtime state.
- Use signals / event messages for loose coupling; avoid a global singleton becoming a service locator for everything.
- Avoid premature microservices or complex plugin frameworks.
- Every autoload must have a documented owner, public API, and test strategy.

## Proposed project layout

```
res://
  project.godot
  assets/
    characters/ environments/ interiors/ props/ enemies/
    effects/ ui/ audio/ fonts/
  scenes/
    bootstrap/ player/ world/ locations/ interiors/
    npcs/ interactables/ combat/ ui/
  scripts/
    core/ player/ world/ interaction/ combat/
    inventory/ dialogue/ utilities/
  data/
    characters/ items/ abilities/ enemies/ quests/
    dialogue/ regions/ schedules/
  resources/
    definitions/ configs/
  systems/
    save/ scene_flow/ time/ content/ localization/
  tests/
  docs/
```

## Scene composition

- `GameRoot.tscn`: application root and scene-flow boundary.
- `MainMenu.tscn`: new game, continue, settings, credits, exit.
- `CharacterCreator.tscn`: preview and validated appearance selection.
- `WorldRoot.tscn`: active region container, player spawn, region services.
- `Player.tscn`: CharacterBody2D, collision, visual rig, interaction sensor, health/state components.
- `Interactable`: reusable contract for objects/NPCs with stable IDs and interaction methods.
- UI scenes are presentation only; they call system APIs and do not own game state.

## Autoload candidates

Keep the initial set small:
- `SceneFlow`: safe scene changes and spawn routing.
- `SaveService`: versioned save serialization and backups.
- `ContentRegistry`: validated lookup of content definitions.
- `EventHub`: a limited set of cross-system events.

Add `WorldClock`, `AudioService`, or `SettingsService` only when a real consumer exists. Do not create an autoload for every feature.

## Data model

Use custom Resource classes for authorable definitions where useful:
- ItemDefinition
- CharacterDefinition / AppearanceDefinition
- EnemyDefinition
- AbilityDefinition
- QuestDefinition
- DialogueGraph / DialogueNode
- RegionDefinition / ScheduleDefinition

Runtime state must be separate from immutable definitions. Persistent state should reference IDs and primitive values, not serialized live Nodes.

## Save format and migration

Save envelope:
- schema_version;
- game_version;
- timestamp;
- player state;
- world and quest flags;
- NPC relationship / knowledge state;
- inventory and equipment;
- region changes and property state.

Write to a temporary file, flush/close, then replace the primary save; retain a previous backup. Validate payloads on load. Provide migration functions per schema version and a safe recovery message for corrupt saves. Never silently overwrite an unreadable save.

## Scene transitions

Use explicit transition requests with destination scene ID and spawn ID. The player is recreated or transferred through a documented boundary; no scene should assume a hard-coded node path into another scene. Persist only necessary state before leaving.

## Content IDs and localization

IDs are stable snake_case identifiers, never display strings. All player-facing text uses localization keys. English and Russian are initial target languages; layout must tolerate text expansion. No text baked into sprites unless unavoidable.

## Performance strategy

- Load only active region scenes and required neighbors.
- Use coarse simulation for off-screen NPCs.
- Pool only after profiling proves allocation churn is material.
- Avoid per-frame work in UI and large numbers of always-processing nodes.
- Profile on the minimum target PC before scaling NPC count.
- Use tilemaps / TileMapLayer conventions supported by the pinned Godot version.

## Code conventions

- Typed GDScript; explicit return types for public APIs.
- PascalCase for classes/scenes, snake_case for functions and variables, CONSTANT_CASE for constants.
- No magic node paths repeated across scripts; use exported NodePaths or component references.
- No silent catch-all error handling.
- Debug logging behind a development setting.
- Keep scripts focused; split when a component has independent lifecycle or tests.

## Definition of done for a technical feature

A feature is done only when it:
1. runs in the pinned engine version;
2. has no parser/runtime errors in its test path;
3. handles invalid/missing data safely;
4. has automated tests where feasible and a documented manual test;
5. survives save/load if persistent;
6. has no known critical regression;
7. is documented for the next contributor.
