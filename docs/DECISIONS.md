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
| D-028 | Cases declare stage transitions and fail-forward rules; tests verify reachability. | Accepted (fail-forward part superseded by D-052) | Prevents soft-locks and missable critical clues. |
| D-029 | Save schema 4 adds faction standing, NPC knowledge and pending gossip (migration 3→4). | Accepted | |
| D-030 | The first profession is **repair** (not gardening): a timing minigame whose green zone grows with skill level (5 levels by XP). | Accepted | Fits Jonah's workshop, the "fix what's broken" theme and the town's broken objects; reuses world props. |
| D-031 | Economy rules are data (`data/economy/`) and checked by `Economy.validate()`: nothing can be bought and resold for profit, and no recipe outputs more value than its inputs at shop prices. | Accepted | Exploit tests from the M5 exit gate. |
| D-032 | Rent (£15 weekly) becomes debt when unpaid, collected later; there is no eviction or penalty. | Accepted | A money sink that never soft-locks or punishes a story-focused player. |
| D-033 | The business is a repair cart: price tier, stock and upgrades set daily customers, resolved deterministically at dawn; fair prices raise reputation. | Accepted | Small, testable business prototype linked to Jonah's relationship. |
| D-034 | Odd jobs: up to 3 a day, chosen deterministically from the day number; each pays money, XP and +1 with the client; some change the world (the fountain). | Accepted | Ties non-combat work to NPC needs (exit gate). |
| D-035 | Save schema 5 adds `life` (skill, jobs, stall, rent debt, home upgrades), migration 4→5. | Accepted | |
| D-036 | Regions are data: `data/regions/<id>.json` (layout + nodes + templates) built into `.tscn` by `tools/regions/build_regions.py`; generated scenes are committed. | Accepted | Scenes stay hand-editable in Godot, but the spec is the source of truth; the older five scenes rebuild byte-for-byte. The tool needs the private art (sprite sizes); the game does not. |
| D-037 | Definitions merge by file prefix (`items.json` + `items_*.json`); locations register by file name in `scenes/locations`. | Accepted | A new region adds its own files and never edits shared code. Duplicate ids are errors. |
| D-038 | Echo enemy variants are data (`data/enemies/`); bosses stay bespoke scenes. | Accepted | Regular enemies are tuning; bosses are design work. |
| D-039 | Content is validated by a Python tool in CI before Godot runs; dialogue and case graphs are generated as Mermaid and checked for freshness. | Accepted | Fast feedback for writers; reviewable on GitHub without the game. |
| D-040 | Per-location budgets (nodes, props, tiles, NPCs, enemies, instancing time) are data and enforced by tests. | Accepted | Keeps regions cheap as content scales. |
| D-041 | Translation round-trips through CSV (`tools/loc.py`); imports refuse placeholder mismatches. | Accepted | Translators work in spreadsheets; format bugs are caught at import. |
| D-042 | The campaign spine is data (`data/story/campaign.json`): acts start in order once their condition holds; the current act is derived from `act.<id>` flags, so no save migration is needed. Unwritten acts are `planned` and never start. | Accepted | Each stage ships playable; old saves start the new act on load. |
| D-043 | Acts are built and merged one at a time (M7a–M7f, `docs/production/campaign-plan.md`). | Accepted | Keeps every merge playable end to end. |
| D-044 | `quest_stage` as a condition is true only while the case is open. | Accepted | Closed cases keep their last stage; matching it re-ran Jonah's radio reward on every conversation (money and relationship exploit). |
| D-045 | A dialogue entry that ends the conversation without changing anything is a validation error. | Accepted | It hid Jonah's and Mara's hubs (shop, jobs, new cases) while a delivery was pending. |
| D-046 | The lighthouse keeper is renamed Hester Ashby. | Accepted | "Wren" is Director Elias Wren in the story bible. |
| D-047 | One companion at a time (`Party`, `data/characters/companions.json`); a companion leaves their schedule and follows as an Npc with a `Follower` brain; one ability each (Jonah: patch up; Mara: pin). Save schema 6 adds `party`. | Accepted | Smallest party model that supports the bible's companions and per-act camp talk. |
| D-048 | Bosses are any node with `engage()` and a `health`; the region generator takes a boss `scene`. | Accepted | Second boss without copying the arena code. |
| D-049 | Act II fail-forward can open the depot without the boss fight after four days. | Superseded by D-052 | Story bible §11: nothing critical is gated behind combat skill. |
| D-050 | Conditional effects (`first_match`) and `quest_outcome` conditions; `give_item`/`take_item` accept a bare id. | Accepted | Lets the campaign choose the Act III confessor from earlier endings in data. |
| D-051 | Hazards slow the player through `Player.wading`; flood water is a drawn overlay, not tiles. | Accepted | The water level must move every few seconds. |
| D-052 | **No fail-forward.** Nothing advances because time passed, no free hints, bosses cannot be skipped; mistakes are consequences. New content follows this from M7d; existing content is reworked in M7e. | Accepted | Owner's direction: the game must not play itself or feel casual. Supersedes D-028's fail-forward part, D-049 and the fail-forward wording of story bible §11. |
| D-053 | Testimony can be judged authentic / edited / unreliable; evidence carries a hidden `truth`; verdicts are saved in the journal (no schema bump: absent means unjudged). | Accepted | Act IV's investigation is the player's judgement, and getting it wrong sticks. |
| D-055 | Difficulty (story / normal / hard) is chosen at new game: enemy health ×0.7/1/1.3, +1 damage per hit on hard, +3 health on story. Fainting drops a satchel (half the money, all on hard, and carried Resonance) where you fell; recoverable once. Save schema 7. | Accepted | Real stakes without punishing reloads. |
| D-056 | Quests: per-stage objectives (conditions, progress counters, optional rewards paid once), deadlines that fail side quests with consequences, one pinned case on the HUD, no waypoints. Main cases never have deadlines. The validator rejects fail-forward and stages no player action reaches. | Accepted | Replaces fail-forward (D-052) with player-driven progress and real failure. |
| D-057 | The final fight is shaped, not skipped, by allies and evidence: each ally removes or softens one mechanic, true nights lower Wren's health (floor 40%). | Accepted | Bible: "not simply a boss fight" + D-052 (no skips). |
| D-058 | Endings and epilogues are data (`data/story/epilogues.json`): the ending card, then the first matching card per group; the Living Accord needs trust, truth, allies and true nights (`count_at_least`). After the epilogue the game continues in the new world state. | Accepted | Bible §9–10; consequences stay visible. |
| D-059 | Boss health is data (`data/enemies/bosses.json`, before difficulty); tests assert every boss pattern leaves a safe place. | Accepted | Balance changes from playtests without code; challenge stays fair. |
| D-060 | Companion personal quests upgrade the companion's ability (`companions.json` `upgrade`); both can be failed by deadline. | Accepted | Relationships pay off mechanically; consequences per D-052. |
| D-061 | Debug builds (`OS.is_debug_build()`) get a main-menu "start at act N / endgame" that replays a plausible cumulative history from `data/debug/act_starts.json`; exports never show it. Tested: every target lands in its act. | Accepted | Testers reach late bosses and endings without replaying hours. |
| D-062 | Expeditions (M8a) are runtime-built rooms (`expedition_room`, the one location without a region spec) from `data/expeditions/`. Modifiers change play (water, rewritten floors, darkness, extra Wailers, crowding, +1 damage taken), not just numbers; the rematch boss shares the run's modifiers unless it already owns that mechanic. The board is deterministic per day and runs done (no reroll by reload). Fainting ends a run with no shards; the satchel lies at the rift. Shards are unsellable, so shard recipes can't break the economy. Save schema 8. | Accepted | Roadmap M8 exit gate: distinct decisions and encounters, not inflated health. |
| D-063 | World incidents (M8b) are ordinary journal cases (`clear` → `report`, 3-day deadline on `clear`) started by `Incidents` at dawn after the ending, one at a time with a 2-day cooldown, in data order; echoes are spawned at runtime in the incident's location. State lives in journal and flags (no schema bump). Which incidents exist depends on the ending (`requires`). | Accepted | Post-ending world states that react to the player's ending, with consequences instead of chores; reuses the quest system (D-056). |
| D-064 | Quest guidance is a player setting (detailed: goal + where/when + on-screen marker; standard: goal only; minimal: nothing on screen, the world and journal carry it). Default detailed. Where/when lives in `data/story/guides.json` per stage/objective (validator: every stage has one); routes use the generated door graph `data/world/doors.json`. A "wait" key (T) skips to evening/night/morning when no echoes are near. | Accepted | Playtest: a new player didn't know to wait for dark. Clarity without making the game play itself (D-052): guidance shows where, not the answer. |
| D-065 | Direction 2.0 (docs/production/roadmap-2.0.ru.md): keep the codebase and campaign; grow density first (interiors, activities), then the city's districts and a world map, then RPG progression, weapons, countryside with a farm, and the story as three sagas. One dense region before the next. | Accepted | Owner's goal of a large RPG + external audit; avoids a rewrite and empty scale. |
| D-066 | Progression (R3a): XP from play (echoes 4, bosses 60, cases 50/25, objectives 8, evidence 3, sport, training), levels to 50 (60+30·L per level), one point per level for six characteristics, a talent point every third level. Characteristics feed the existing stat pipeline (`Inventory.stat`) so every system benefits without special cases; dialogue and the world can check them (`stat_at_least`). Save schema 9; old saves get a level per closed case (max 10). | Accepted | Owner's goal of real RPG growth; reuse instead of parallel systems. |
| D-054 | One `Reviser` boss class with per-site exports (pattern, summons, look); the region generator writes per-instance exports (`set`). | Accepted | Three distinct bosses without three scripts. |

## Open questions

- What minimum PC specification should be targeted?
- Is controller support required for the first demo or only full release?
- Which languages beyond English and Russian are commercially justified?

## D-067 Weapons and talents (R3b/R4a)

Weapons now have a style (fists, blade, heavy, thrust, staff, sling) and a rarity. The equipped weapon is drawn in the hand while attacking (WeaponSwing, arsenal icons at 16 px). Staffs and slings fire a Bolt: a small projectile with its own Hitbox. Sources are Jonah's shop (hatchet, sling), Veil-shard recipes (signal wand, lantern blade, coral trident) and expeditions: each finished run brings back the next relic weapon the player lacks.

Talents live in data/progression/talents.json: four paths of three ordered steps, paid with talent points. A step either adds stat mods (through Progression.mod, so the usual Inventory.stat pipeline applies), adds characteristics, or names a special effect the code checks with Progression.has_special. Talents are saved inside the progression block; no schema change was needed.

## D-068 Brookside Farm (R5)

The farm is bought through a side case (case_brook_farm): a notice at the market bus stop or Martha's gossip, Hugh Penny's trial (mend the well, come back at dusk), Margaret's echo, her tin of letters, and a choice that sets the price (£120 or £90). Every step is said in the world as well as in the journal: Hugh names the hour, the well tells you to come back at sunset, Margaret names the tree.

Districts can carry `open_if`: once you have heard of a place, the bus goes there before your first visit, and further districts have their own fare and ride time.

Farming is deliberately forgiving: a crop grows one step per watered (or rainy) day and never withers; produce goes in the crate and is paid next morning; hens lay every night. Plots are Interactables generated from a `field` template over a derived soil picture (tools/art/make_field.py, private submodule); animals are decorative `critter` nodes. State lives in the Farm autoload and is saved under "farm" (no schema bump: missing means empty).

## D-069 Millwood and the drowned village (R5b)

East of the farm: Millwood (forest, lake, pier, Ada's caravan, a campsite with a rest by the fire) and, under the lake, Mill Ford, a Veil location reached by a stair of light from the end of the pier in the evening or at night. It is our first "underwater" place: a whole village on the lake bottom, tinted deep blue. The case (case_drowned_ford) ties the countryside to the main story: the village was flooded in 1962 and then struck out of the town's books by the Census. Hints live in the world: Ada names the pier and the hour, and the memorial stone carries her note for anyone who meets the stone first.

Foraging is a new node kind (`forage`, ForageSpot): gather once a day, back next morning, state in the flag forage.<id>.

## D-070 The Chronicle (R6a)

The journal has a third tab, the Chronicle: the story so far written as a book, in the second person and the present tense (which keeps Russian free of gendered past forms). Chapters (data/story/chronicle.json) follow the acts, with "tales from the margins" for the big side stories; each page has its own condition, usually a case outcome, so the book retells the choices this player made and never the others. A chapter that is not finished ends with "the chapter is still being written". New pages raise a quiet toast once any conversation is over. The validator checks every chapter's keys and conditions, and now also checks quest_outcome references everywhere.

## D-071 Townspeople (R1c)

Streets are no longer empty: a Crowd node per location (data/world/crowds.json) keeps the right number of passers-by out for the time of day (fewer in the rain, almost none at night). They are put together at random from Character Generator layers, walk authored routes along pavements, stop now and then, fade in and out at the route ends, and have no collision. Spoken to, they answer with one line in a bubble, from data/world/chatter.json; lines can depend on the place and on the story (rumours of the Ward after act II, new neighbours after the ending), so the town visibly reacts to what the player did. No dialogue window: talking to a stranger should cost a second.

## D-072 NPC activities (R1d)

A schedule entry can carry an activity: look (glance around now and then), read, phone, work (a few busy steps to and fro around the anchor). Reading and the phone use the Character Generator's own rows; layered characters get the pack's Books sheet as an extra layer while reading, premade sheets have the book and phone drawn in. Talking interrupts the activity and it resumes when the conversation ends. The validator checks activity names.

## D-073 Other towns (R12a)

Travel between towns is its own layer above the city bus: data/world/world_map.json lists towns (their scenes, where you arrive, a spot on a hand-drawn coast map) and routes with a mode, a fare and a time. Every scene belongs to Greyford unless a town claims it. The first route is a coach from the market to Cavenmouth, a seaside town with an inn, a post office, a beach and its own crowd. Car and plane will be other modes of the same table. The first Cavenmouth story ties back to Greyford on purpose (letters to erased addresses, delivered by hand to Edda, Theo and Jonah), so a second town deepens the first rather than replacing it.

## D-074 Fishing (R7a)

Fishing spots are screen nodes ("fish:sea|harbour|lake") marked by a bucket. A rod from either bait shop opens the minigame: cast, wait, strike inside a short window, then keep the fish inside a band that rises while E is held and sinks when it is let go. Which fish can bite depends on the water, the part of the day, the weather and sometimes the story (data/fishing/fish.json): the herring of '62 only on rainy nights in the harbour, the bell carp only after Mill Ford's bell is known. Each cast costs ten minutes. The kinds caught are counted (flags fish.caught.<id>). Fixed on the way: screen nodes ignored their "prompt" in the region data, so bus stops and shops all said "Use"; the validator now checks every prompt key in the scenes.

## D-075 Your own car (R12b)

Jonah sells his late father's estate car (£120, once you are on friendly terms). It is parked in Greyford's old quarter, the market, the farm and Cavenmouth; getting in offers "around town" (the city map, free and ten minutes a ride) or "the coast road" (the coast map with car routes: cheaper and quicker than the coach). Car routes are ordinary rows of the route table with mode "car" and an "if" on owning it; a plane will be the same. No driving minigame: the car is about freedom of movement, not a new control scheme.

## D-076 The island ferry (R12c)

Travel modes are now a string on each route ("coach", "car", "ferry"); a town may name a different arrival point per mode (arrive_ferry: the harbour pier). The ferry to St Carrow starts broken: Agatha hands the player the repair as a job, and the board at the pier becomes a ticket office once it is done. St Carrow is small on purpose (a lighthouse, a chapel, a cottage, a pier for lobster) and carries one quiet story: since November 1962 Greyford's lighthouse counts to seven, and from the island's gallery the player can send the missing eighth flash.

## D-077 By air (R12d)

The art packs have no aeroplanes, only a helicopter and a landing pad, so "the plane" is an air taxi: a new Greyford district (the airfield, always on the bus map) and an "air" route to Ashbridge, the county town an hour away. Ashbridge is the first place built for scale rather than intimacy (three-storey townhouses, a square with a fountain, the regional Census Bureau still open), and its story points back home: Agnes Venn's census card is under glass in the museum as a "specimen", and it can go to Mara, by argument (Intellect 3) or by a donation.

## D-078 Mill Hill and the abbey (R5c)

The countryside ends in a village rather than a dungeon: Mill Hill lies east of Millwood on foot, small enough to learn in one visit (a green with a well, a pub with a bed, a shop, a chapel, a dead windmill, the vicarage). Its one story sits a lane further east: in the ruins of St Brigid's Abbey (dissolved 1539) the sisters' echoes still keep their last vigil. Clearing them lets Abbess Cecily hand over the rosary of the house, and the player chooses, as at the Drowned Ford, between giving it back (the chapel, resonance) and carrying it (a trinket, +1 heart).

## D-079 One narrator, who says "вы"

Russian text drifted: the main acts and memories addressed the player as "вы", the later content (the farm, the travels, the Chronicle) as "ты". The narrator now says "вы" everywhere: it is the older and larger body of text, it matches the MEM_ memories, and it is gender-neutral by grammar ("вы пришли"), which removes a whole class of workarounds. Characters keep their own register: Hugh, Ada and Jonah may say "ты" to the player, and the player may say "ты" to friends in choices. text_lint now fails CI on "ты", "твой" or a 2nd-person-singular verb in narration (any string that is not a character's line, a player choice or passer-by chatter, outside «» and „“). The same pass rewrote the flattest one-line descriptions of the main acts.

## D-080 The bond (R8a)

Relationship is what the town thinks of you; the bond is what one companion has learned walking beside you. It grows by itself (a point per half hour on the road together, big clock jumps capped at 30 minutes, and a point per echo beaten side by side), has three tiers (10 / 25 / 45 points), and each tier opens one conversation on the road, offered from the companion's camp dialogue. The third tier also sharpens their ability (companions.json "upgrades"). Jonah's and Mara's third talks can become a romance, always optional, always offered with an equally warm friendship answer and written for a player of any gender; Hester, the third companion (a lamp that slows every echo nearby), ends in an apprenticeship instead. Romance and Hester's apprenticeship each add an epilogue card. The character screen lists every companion met with their bond.

## D-081 Dungeons are regions (R9a)

A big dungeon is built from ordinary regions, not a new system: rooms are region files with side openings, gates are props and doors with show_if, locks are dialogue entries that check flags and items, secrets are doors that only appear once a flag is set. The Salt Tunnels under the harbour are the pattern: a hub with two branches that each hold one of the gate's two locks (the order is the player's), two secrets (a false wall that needs Perception 3, and a hidden shelf found by reading a clue in the other branch), a boss behind the gate, and a ladder shortcut back to the surface once he falls. New palette salt_tunnels (stone floor and walls from Room Builder) and texture aliases @hal and @jail for the Halloween and Jail packs.

## D-082 Places and people have their own music (R10a)

Eight new pieces, composed and rendered by tools/music/compose.py like the rest, each built on the echo leitmotif (A-D-E-F, or its major shape 5-1-2-3) so the town still sounds like one place: farm (a 3/4 accordion waltz), harbour (a 6/8 shanty), village (flute and guitar), abbey (the echo as plainchant over an organ pedal), tunnels (drone, drips, a far-off music box) and three companion themes: Jonah (swung electric piano), Mara (a music-box waltz) and Hester (a bell that counts seven, then, in the second half, eight). New synth voices: accordion, organ, flute, choir. A region picks its piece with options.music; the countryside and harbour give way to the night theme after dark. A dialogue may name a piece ("music"), which plays while it runs: the companions' camp talks use their themes. Combat and bosses still take over. validate_content checks that every named piece exists.

## D-083 Echo behaviours are data traits (R4b)

Eight kinds of echo, still one script. A variant in data/enemies/enemies*.json may carry behaviour traits that combine freely: guard (light hits from the front glance off; flank or hit hard), split (comes apart into smaller echoes that drop nothing), blink (ends its wind-up by stepping out of the air behind the player), summon (calls up to N more echoes while it lives), mend (heals the echoes around it) and resist_stun (the Lantern Flash does not stop it). The five new kinds (Warden, Doubled, Flicker, Caller, Sitter) are placed in the Salt Tunnels, the abbey, the Drowned Ford and the expedition pools. Each teaches itself: the first time one notices the player, a toast names it and says how to fight it. A Hurtbox may carry a damage modifier; a hit it reduces to zero still lands and shows "guarded". A splitting echo stays in the enemy group until its pieces are added, so an encounter cannot clear in between.

## D-084 Rowan Terrace, and the tram that wasn't (R2e)

The residential district is one street of Victorian terraces, numbered 10 to 17 with no 13. Its case is told by the street itself: the gap between 12 and 14 is fenced and empty by day, and after dark, while the case is open, a whole house stands in it (a building with show_if on period). Inside is the Abbotts' kitchen on 12 December 1962, struck from the rates register for arrears. Chalking 13 on the door restores the house for good, and Peggy Abbott (now in her seventies, a girl's ribbon still in her hair) sits on its step by day; or the photograph goes to Ivy's window. The bus reaches the terrace from the start. The city map was full, so a district may now be drawn smaller (city_map.json map_size, honoured by render_maps.py and the map screen's markers).

The roadmap's tram is dropped: the bus already crosses the city, and a second line that does the same job would be a menu, not a place. Fast travel stays the bus, the car and, outside the town, the coach, ferry and air taxi.
