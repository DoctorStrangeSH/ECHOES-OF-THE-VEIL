# World & Quest Design

## World structure

Use connected, authored regions rather than one enormous seamless map. Each region is a compact place with a distinct social identity, traversal rhythm, visual language, resources, and story question. Transitions may be streets, transit, loading gates, or Veil passages.

### Launch-scope regions (provisional)

1. **Greyford — Old Quarter:** starter district; market arcade, rented rooms, municipal archive, tram stop, clinic, repair shop, café, waterfront access.
2. **Greenbank — Outskirts:** farms, allotments, woodland, reservoir, small settlements, gathering and fishing.
3. **North Quay — Industrial waterfront:** warehouses, logistics yards, research annex, shipyard, faction pressure.
4. **The Underworks:** connected tunnels, sealed service spaces, first major Veil expedition.
5. **The Echo Ward:** handcrafted echo of the erased neighborhood; major narrative dungeon / hub.
6. **Asteri Sites:** late-game locations unlocked by story and endgame progression.

Do not commit to all six as launch content until the first region proves the production pipeline. Each additional region must justify its cost with a new mechanic, story arc, enemy ecology, or profession loop.

## Region template

Every region design must specify:
- one-sentence identity and emotional tone;
- landmark silhouette and navigation landmarks;
- resident groups and daily rhythm;
- 3–5 reusable activity loops;
- main quest beats and side stories;
- shops, services, resources, and sinks;
- combat spaces and safe spaces;
- secrets and environmental storytelling;
- day/night and weather variants;
- accessibility and navigation considerations;
- performance budget and scene streaming boundaries.

## Quest taxonomy

- **Main case:** advances the central mystery and requires evidence synthesis.
- **Character story:** reveals a companion/NPC contradiction and changes the relationship.
- **Neighborhood story:** resolves a local need with visible community outcomes.
- **Profession contract:** uses a trade skill and contributes to reputation/economy.
- **Expedition:** authored destination with variable encounters and discoveries.
- **World incident:** timed or state-driven event with multiple response methods.
- **Collection / research:** optional lore trail with a meaningful final synthesis.

## Quest quality bar

A quest is not accepted merely because it has dialogue and a reward. It must have:
1. a clear player-facing motivation;
2. at least one interesting decision or discovery;
3. a distinct location, character, or mechanic;
4. a fail-forward outcome where appropriate;
5. consequences or a satisfying resolution;
6. journal and localization coverage;
7. state-combination tests.

Avoid filler fetch quests. If an item must be collected, the act should reveal character, world, risk, or a useful systemic choice.

## Investigation design

The player collects evidence and forms hypotheses. The journal labels entries:
- **Observed:** directly witnessed.
- **Reported:** told by a source, with provenance.
- **Recorded:** found in a document or device, with authenticity caveats.
- **Inferred:** player hypothesis.
- **Corroborated:** supported by independent sources.

Two NPCs repeating the same rumor are not independent corroboration if they share a source. Evidence records should preserve provenance and contradictions.

## NPC schedule model

Use authored schedule blocks and event overrides, not expensive frame-by-frame simulation for every resident. NPCs outside the active region can advance through coarse simulation. Story-critical NPCs use explicit quest states and protected scene scheduling.

## World-state changes

Track meaningful state at the smallest useful scope:
- global campaign flags;
- faction standing / access;
- region conditions;
- NPC relationship and knowledge flags;
- business / property state;
- quest and evidence states.

Avoid a single opaque morality score. Every tracked variable must have a documented reader/writer and a reason to exist.
