# Gameplay Systems Design

## Player experience priorities

1. Movement and interaction must feel immediate and predictable.
2. The player should always understand what can be interacted with.
3. Combat is readable and responsive, not animation spectacle without feedback.
4. Non-combat progress is viable and rewarded.
5. Systems reinforce the story and the town rather than compete for attention.

## Character creation

Initial scope:
- display name and pronouns;
- body preset / presentation option;
- skin tone, hair style/color, eyes, outfit layers where supported by source assets;
- one background choice that grants a small practical perk and dialogue tags.

Do not promise unlimited modular customization until sprite layers, animation alignment, palette compatibility, and licensing are audited. Build a data-driven appearance model and test all combinations.

## Movement and interaction

- 8-direction movement with normalized diagonal speed.
- Collision-safe movement and configurable input actions.
- Interact prompt with action name and input hint.
- Context priority: focused story interaction > usable object > ambient inspect.
- Input remapping and keyboard/controller support.
- Scene transitions preserve player state and spawn point.
- Interaction targets expose stable IDs for quest and save references.

## Combat (first playable implementation)

A compact action-combat foundation:
- one basic melee weapon;
- one ranged or magic option after melee feel is validated;
- dodge with bounded invulnerability only if telegraphed clearly;
- hit reaction, health, damage, knockback, and clear enemy telegraphs;
- one enemy archetype and one miniboss.

Combat must be fun with placeholder art before adding many classes. Later progression may include weapon families, active skills, passives, status effects, builds, and boss-specific mechanics.

## Progression

Prefer horizontal choices and meaningful tradeoffs over endless stat inflation:
- character level unlocks capacity and core points;
- weapon / discipline proficiency unlocks moves or utility;
- professions progress independently;
- relationship and faction progression unlocks scenes, access, and support;
- equipment changes play style through readable affixes and set effects.

Avoid designing eight classes before the first two combat styles are proven. Initial prototype: adaptable base character with one weapon discipline and one utility ability.

## Inventory and items

Items are data resources with stable IDs, category, stack rules, icon, description, acquisition sources, use behavior, sell value, and localization keys. Inventory UI must support sorting, filtering, tooltips, comparison, and controller navigation. Save by item ID and quantity, not scene instance.

## Professions and economy

Candidate professions: cooking, gardening, fishing, repair, crafting, alchemy, and trade. Introduce only loops that connect to quests, NPC needs, exploration, or business.

Economy rules:
- every currency source has sinks;
- shop stock and prices have explicit rules;
- avoid infinite profitable buy/sell loops;
- regional supply disruptions should be understandable;
- offline single-player economy must not punish players for taking breaks.

## Home and business

Start with one player room / safehouse and one small shop or workshop upgrade path. Decoration is optional and grid/placement rules must be robust. Business management should be a light strategic layer, not a spreadsheet simulator: stock, staff, opening hours, reputation, and a small number of upgrades.

## NPCs and relationships

NPC profile data:
- stable ID, name, portrait/sprite references;
- schedule and home/work anchors;
- personality tags and authored goals;
- relationship values / milestones;
- knowledge flags and memory events;
- dialogue conditions and localization keys.

Memory events should be semantic (helped with evacuation, broke a promise, shared a secret), not a raw log of every player input. Important NPCs can remember and react; ambient NPCs use cheaper generic schedules.

## Time, weather, and world simulation

Start with a simple day clock and weather state. Time advances through authored actions and play, not real-world waiting. Story events use explicit conditions and should not be permanently missed because the player slept or explored elsewhere.

## Endgame foundations

Build reusable contracts, expedition modifiers, boss phase data, reward pools, and world-state hooks. Handcrafted bosses and narrative encounters remain authored. Procedural variation may change routes, hazards, enemy combinations, and optional objectives, never the core emotional story.
