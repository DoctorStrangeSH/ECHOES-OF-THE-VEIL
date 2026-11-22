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

## D-085 The Rope Works (R2f)

The industrial district is the Greyford Rope & Twine Co.: three ropewalk sheds in a row (one long hall inside), a boiler house, the works office and the gutted Number 2 Mill across the road. It is the first place in town that pays by the hour: Doyle the foreman gives a four-hour day shift for £16 (a dialogue that advances the clock), repeatable, so money can come from steady work as well as cases. Its case, The Night Shift, is about a roper killed in 1961 by a rope of rotten hemp bought from the owner's brother-in-law and then struck from the record so his widow would get nothing. His echo still clocks in every night; the player finishes his rope at the wheel (a repair job, reusing the minigame), finds the buried accident report, and chooses to pin it on the noticeboard (a brass plate appears in the yard) or to clock him out quietly. Every region now must have a LOC_<ID> name (validate_content checks it), because the quest guide names places by it; eleven older places got theirs.

## D-086 Cooking and meals (R7b)

The farm, the rod and the forest finally feed something. Eight recipes (data/cooking/recipes.json) turn crops, eggs, fish, crab, mushrooms and berries into dishes at a stove (the rented room, the farmhouse) or a campfire (Millwood). A need is an exact item or "any" of a list (any fish, any vegetable), so the player cooks with what they have. Cooking takes twenty minutes. A dish heals and may leave a meal: one bonus for a few game hours (+1 heart, +1 damage, faster steps, quicker dodge, a wider or quicker Lantern Flash). One meal at a time, the latest replaces the last, it is saved, and it wears off on the clock; the character screen shows what is active and until when. Bonuses are small on purpose: cooking should feel like care, not a requirement.

## D-087 Pontoon in the pubs (R7c)

The card game is pontoon, the British pub cousin of twenty-one, because people in Greyford would actually play it and the rules fit on one line: get closer to 21 than the banker without going over; twist or stick; the banker draws to 17; ties go to the banker; a pontoon (ace and ten-card) or a five-card trick pays double. Stakes are £1, £2 or £5, so it is a pastime, not an income (the house edge is real, as in a real pub). One RPG touch: with Perception 4 you read the banker's face and know whether the hidden card is high or low, which turns a stat into a better decision rather than a better number. Tables at the Old Millstone (Bess deals) and the Gull & Anchor. The rules live in systems/minigames/pontoon.gd and are unit-tested; the table is drawn in code, so it needs no art.

## D-088 The main theme, orchestrated (R10b)

The title theme keeps its two tunes and its key and becomes a 93-second arc that loops: a bell alone counts the echo over a held D while the choir hums; the piano states theme A over harp-like arpeggios; strings take theme B with the flute answering, choir and timpani entering; the echo returns full (strings, choir, organ, timpani on every bar); and the piano closes alone, quiet enough to lead back into the opening bell. Same tools/music pipeline, new voices from R10a.

## D-089 The first minute (R11a)

A pass over the opening as a new player sees it, by screenshots. The intro grows from three lines to five or six: arrival, one line chosen by the background (why you came), the address, and the door: "in the middle of the square, behind the fountain, stands a door, just a door, with no house around it". Because the door is off the top of the screen at the bus stop, the intro now glances at it: a new story effect camera_look [x, y] glides the camera to frame a point above the dialogue panel, clamped to the map, and camera_back returns it (the player keeps a look offset that the camera shake adds to, instead of resetting to zero). Toasts drop below the controls card while it is up; the Chronicle's opening page no longer toasts in the first second. The menu tagline wraps and reads better in Russian. Two background names were gendered in Russian ("Вернувшийся", "Бывший архивист"); they are now "Снова дома" and "Архивист в прошлом". The debug start button exists only in debug builds, as before.

## D-090 The first hour (R11b)

A second screenshot pass, from the door to the first morning. The player could ask Mrs Halloway about "Lantern Row" before hearing the name; the question is now about the door ("what stood there before?"). First meetings with Halloway, Mara, Ivo and Nadiya ended the conversation instead of opening their topics; they now go to the hub. The door case has step-by-step objectives in both stages: look at the door, ask people (any two of four sources), put it together in the journal; then get past the hollows and find whoever called your name. Each step has its own guide line. A conclusion that is ready to draw shows as a highlighted button right under the case's steps, focused when the journal opens, instead of at the bottom under the evidence. "Stop showing" became "Hide this case's hints from the screen". The Lantern Row echo, a bare corridor, is now a furnished 1970s hallway (coat stand, radiogram, clock, stove, a toy shelf, chairs at the half-drawn table), with two things to look at; the woman no longer stands hidden behind her table. The entry line names dash as well as strike. The first night has its own dream, which depends on whether you opened the door; later nights keep the short line.

## D-091 A tour bot, and terrain the way LimeZu draws it (R11c)

tools/tour_bot.tscn plays through the game as a very thorough tester: at the start of the game and at chosen act starts it travels to every location, photographs the whole map and the player's view, uses every inspectable, person, bed and pickup (answering conversations branch by branch), checks every door's target and logs every engine error and warning; it also measures how much walkable floor has nothing near it. tools/tour_report.py turns a run into a ranked table and contact sheets. Its first run found a boss bar that stayed on screen after leaving the arena (now cleared on every location change) and a conversation it could not leave by cycling choices.

Grass was one tile everywhere. LimeZu ships its terrains for Godot as 26 blocks in the 47-tile "3x3 minimal" layout (Autotiles_16x16/Godot_Autotiles_16x16.png); tools/regions/blob_map.py reads each tile's neighbour mask from the sheet itself into data/tiles/blob47.json, and TilePainter gains blob brushes: the edge or corner tile on an overlay layer, the neighbouring ground underneath, and light patches scattered over plain grass. Outdoor grass now has the outlined, tufted edges of the pack's own scenes; country dirt paths blend into grass the same way.

Interiors: LimeZu's sample rooms (6_Home_Designs) never leave a wall bare and put plants in free corners. Rooms can ask for a dressing pass ("dress": {"theme": ...}) that hangs pictures, shelves, boards, bunting and lamps along every free stretch of the back wall, by theme (home, cafe, tavern, shop, office, bare), and puts plants in free corners. This is a first step; the larger change, rebuilding rooms smaller and denser after those samples, follows.

## D-092 Feedback pass, stage 1: reading and small things (R13a)

From a 26-point review. The character creator shows a still figure facing you. Identity rows share one label width, so every field lines up; text fields are styled like buttons; pronoun choices are capitalised. In dialogue the narrator has no name plate and speaks in warm italics, while a person has a name plate, a head-and-shoulders portrait cut from their own sprite, and white text. Text speed is a setting (slow, normal, fast, at once); a line that ends in a choice prints three times faster. A left click anywhere but on a choice moves a conversation on. Settings gain a display mode (window, full screen, borderless) and window sizes, all whole multiples of the 480x270 base so pixels stay square. A bobbing pointer marks the thing E would use, the interaction sensor reaches a little further, and inspect zones are at least 20x16. The journal groups cases as Story, Town stories, Errands and Incidents (a "category" on every case), finished ones last. The HUD hides while the game is paused, so menus no longer have the objective showing through them. Streets with traffic (region option "traffic") have cars and the odd bus driving through, which wait for anyone standing in the road.

The rest of the review is planned in stages: one tabbed window built from the Modern UI pack with full mouse control; light, shadows, see-through buildings and exact colliders; one seamless world where roofs lift as you walk in and St Carrow is an island reached by ferry; combat; and a rewrite of the dialogue, story and quests.

## D-093 One window, the artist's look, and the mouse (R13b)

The interface now uses LimeZu's Modern UI pack (Style 1): paper panels in wooden frames, beige buttons that sink when pressed, dark-brown ink, a thin brown scroll rail, and the pack's own arrow and hand as mouse cursors (scaled with the window). Nine-patch margins stop just short of each piece's flat middle so only plain paper stretches. Text drawn over the world (clock, objective, toasts, the button bar) is light with a dark outline. The main menu and the character creator sit on the harbour, drifting slowly behind them.

Journal, Things, Character, Map and Game (save, load, settings, quit) are tabs of one window, the same size whichever is open (GameMenu). Tab, I, C, M and Esc open it on their tab and switch tabs while it is open; the same key again, Esc or the ✕ closes it. A row of small buttons in the corner of the screen opens the same tabs (and the wait menu) with the mouse, each labelled with its key. The Things tab shows the hero as they look now, with name, level and what they carry; "Attunements" is "Созвучия" in Russian, so it no longer reads like "Settings".

Mouse: a click on the ground walks there (hold to keep walking towards the pointer), a click on anything usable walks up to it and uses it, the pointer turns into a hand over such things, and a click in a conversation finishes the line or moves on. In the Veil a click on open ground strikes towards the pointer and the right button dashes that way. Every window is clickable.

## D-094 The mouse is for windows and for aiming (R13c)

Playtest correction to D-093: walking stays on WASD and using things on the interact key; click-to-walk and click-to-use are gone, and so is the hand over things in the world. The mouse is for windows, for conversations (a click finishes the line or moves on) and for aiming: in the Veil a left click strikes towards the pointer. The dash moved off the right button, which is kept free; it is Space (or K).

The Things tab became a bag of squares with pictures: click one to read about it, double-click to use or wear it, drag it onto another square to rearrange the bag (the arrangement is saved, Inventory.order), onto the hero's weapon or amulet slot to wear it, or out of those slots to take it off. Every item has an icon now: 68 more come from the Clockwork Raven sheet, addressed as "sheet.png#col,row" (Inventory.icon_of).

## D-095 Light, shadow, and seeing behind things (R13d)

Outdoors, every tall standing thing (trees, lamps, benches, kiosks, building fronts: the build tool marks them casts_shadow) throws a sun shadow: a squashed, skewed black copy of its sprite, swinging from west in the morning to east in the evening and fading out at dusk (Lighting). Street lamps, light towers, lanterns, candles, campfires, the lighthouse, and indoor lamps and fireplaces carry a warm light (the build tool reads it from the texture) that comes on at dusk outdoors and is always gently on indoors at night. People have a soft contact shadow under their feet.

Anything taller than 28 px fades to 42% while the player stands behind it, so nobody is lost behind a building, a tree or a wardrobe; collision stays at the base, so walking behind the upper part of things is allowed. Low things (flower beds, tombs, crates, signs) now block exactly as wide as their solid pixels at the ground (tools/regions/footprint.py: solid means alpha above 200, so baked shadows don't count); furniture already did, and trees keep their trunk box.

## D-096 One open world (R14a)

The outdoor places of the real world are no longer separate scenes joined by edge exits: they sit on one map (data/world/open_world.json, 760x172 tiles), lined up so their main roads meet in one long avenue from Cavenmouth in the west through Rowan Terrace, the Ropeworks, the harbour, the old quarter, Market Street and Ashbridge to the airfield, and on to the farm, Millwood, Mill Hill and the abbey. North Quay sits above Market Street, the park below the old quarter, the Point on the coast beyond Rowan Terrace; St Carrow is an island in the bay, reached only by ferry.

tools/world/build_world.py builds the land between and around them by carrying each place's own edges outwards (the avenue's road and the pavements beside it run on between towns, lanes and quays a few steps, the sea north of the coast), puts grass everywhere else and dresses it the way LimeZu dresses open ground: trees in clumps whose density follows a coarse random field (woods and meadows), bushes, flowers, and street lamps along the open road. It is cut into 64x44-tile chunks with one cell of context around each, so terrain edges join across chunk borders (TilePainter.context_margin).

At run time OpenWorld holds the player, the camera, the light and the outer edge, and streams places and countryside chunks (Locations in chunk mode) in as the player comes near and out when they are far behind. The place the player stands in is the current location for everything else (quests, music, schedules, the place name, combat); on the open road the last place stays current. Doors that led from one outdoor place to another are switched off: you walk. The quest pointer in the open world points at the street a target is on until you get there. Saves keep the position inside the current place. Interiors and the Veil stay scenes of their own behind doors (roofs that lift as you walk in come with the next step), and the bus, the car and the ferry still take you across the map in a moment.

## D-097 Driving your own car (R14b)

Once you own a car, getting into it in the open world now offers "Drive" as well as the old map rides. Behind the wheel you see the car (LimeZu's four-way car sprites) instead of yourself and move about three times faster than walking; the interact key gets you out wherever you stop, and the car stays parked there (flags car.away and car.spot, in world coordinates) until you get back in. While it is away, the car outside your usual spots is hidden. Leaving the world by bus, ferry or a door while driving parks the car where you are; a save made behind the wheel keeps the car right there.

Roofs that lift as you walk into a building are not in yet: they need each interior built to fit inside its building's footprint, which comes with the interior redesign after LimeZu's sample rooms. Until then doors still lead into rooms with a short fade.

## D-098 Rooms open inside their house (R14c)

An interior marked `"in_place": true` in its region options opens where its house stands in the open world instead of behind a fade: the house's sprites (everything tall that covers a point just above the street door) fade away, the town around is dimmed, and the room is laid over the house's footprint, centred on it with its floor ending at the house front. Its walls, furniture and people sit on their own physics layer (6), and the player only collides with and can only use things in that layer while inside, so the street beneath does not interfere. Walking out through the gap in the bottom wall or using the room's door lifts the roof back without moving you; saves inside keep the room and the position in it, and loading one opens the room in place again. Veil places (fights, fixed tint) and streets never open this way.

Only rooms redrawn to fit their house use it. The rented room is the first: 6×7 floor tiles inside the 96-pixel townhouse, laid out densely after LimeZu's sample rooms (bed, nightstand, window, stove, desk and chair, rug, wardrobe, armchair that gives way to the workbench). Other interiors keep the old transition until they are redrawn to their houses' sizes.

## D-099 Interior sprites without baked shadows; settings in the game window (R14d)

LimeZu's default interior singles carry an opaque grey floor shadow drawn for one particular floor colour; on our floors it showed as a dark slab under beds, wardrobes and armchairs (review item 7). All interior aliases now point at the pack's `Theme_Sorter_Shadowless_Singles`. Numbering drifts between the two sets near the end of the bedroom sheet, so references were matched by pixels and renumbered where needed, and the dressing pass in build_regions.py maps its wall hangings and plants the same way (`shadowless()`). The one sprite with no shadowless twin (basement 241) keeps its full original path.

Settings opened from the Game tab were drawn on the same layer as that tab and under it, so they could not be seen (review item 21). The settings screen now sits above the tabbed window, uses the same window frame, lays its rows out in two columns so everything including Back fits at the base resolution, and the Game tab's buttons hide while it is open. Esc closes settings first, then the window.

## D-100 Shops and the archive open in place (R14e)

The archive, Rook's shop, the bakery, the café and the gym are redrawn to their houses' footprints (8 tiles wide, 11–12 deep, doorway under the street door) in the dense LimeZu manner and marked `in_place`. Every look-at, anchor and door of the old rooms is kept, moved to the new layout. Theo's flat stays a separate scene: its endless corridor is the point.

A house can be several pictures stacked (the market's ground floor, middle floor and roof), so the house now grows from the picture above the door to every tall picture stacked on it that is about as wide; all of them fade, and the room stands on the ground-floor picture. Travelling from a room to a different street closes the room first instead of walking out onto its own street.

## D-101 Combat depth: heavy blow, the Echo, poise, streaks, tells (R15a)

Review item 14 asked for combat that holds attention. The fights already had a combo, dodge, the Lantern Flash and echo traits; what they lacked was a reason to read the enemy and a reward for doing it well. Five additions, all on the existing hitbox/hurtbox model:

- **Tells.** An echo's wind-up now draws its lunge on the ground (a red band the length of the blow, brightening as it comes) and pops a "!" above it; ranged echoes draw a thin line towards you.
- **The Echo (perfect dodge).** A dodge within the last 0.18 s of a wind-up, or during a lunge that has not landed, or with a shard about to hit, slows time to 0.3 for 0.45 s of real time, grants half a second of safety and arms a counter: the next blow within 1.5 s does double and knocks hard. `CombatFx.slowmo` coexists with hit-stop.
- **Heavy blow.** Holding the attack past 0.3 s charges (the hero glows and pulses when full at 0.8 s); releasing a full charge strikes everything within 26 px for the weapon's best combo hit + 1 + finisher bonus, with heavy knockback. A tap still attacks at once, so nothing gets slower.
- **Poise.** Echoes have poise (data `poise`, default max health + 1). Hits wear it down, hard hits (knockback ≥ 200: finishers, counters, heavy blows) by two more; at zero the echo is knocked off balance for 1.3 s (0.65 s if it resists stuns), and every hit on it does one more. Poise refills after 2 s without being hit.
- **Streak.** Hits landed without being hurt count up (shown every five); each full five means one more Resonance from every echo killed, up to three. Getting hurt breaks it.

The first echo met teaches all of it in one toast; the controls card says "hold: heavy".

## D-102 Bosses: balance, readable lunges, the Echo against everything (R15b)

R15a's moves now reach the five bosses and their hazards.

- **Balance.** `BossPoise` attaches to every boss: hits fill a gold bar under the boss's health (hard hits by two more), and a full bar throws the boss off balance for 2.2 s, whatever it was doing (`break_open` on each boss: a stamp charge, a cast or a channel is broken), with every hit doing one more meanwhile. The bar holds about 28 % of the boss's health (at least 4) and settles back when the boss is left alone for 3 s. The Lantern Flash keeps its short, state-limited stun; balance is the way to a long opening.
- **The Echo against everything.** Anything about to hurt the player joins the group `threat` and answers `is_threatening(at)`: echoes, shards, stamp markers in their last 0.22 s, a lane sweep reaching you, the Census-Taker's charge, the Reviser's lunge, the Director and Conductor close enough to strike. A dodge then is perfect, as against echoes.
- **The Reviser's lunge** was the one boss attack without a tell; it is now drawn on the ground for its last 0.45 s of stalking.

## D-103 The prose pass, part 1: the arrival (R16a)

Review items 12 and 25 ask for the whole text to read like a good book. The existing lines were sound but terse: introductions were bare self-presentations, important lines had no gesture beside them, and scenes jumped straight to their point. The pass rewrites the game in parts, in both languages as two originals, following the rules added to the style guide (one detail at a character's first appearance, an action beside every important line, a breath of description before a turn). Part 1 covers the arrival: the prologue (two new beats: the fog at the harbour, the lino under the door), Mrs Halloway, Jonah, Mara, Ivo, Nadiya, Pike, the door on the square, the first echo and waking up afterwards — 64 strings. Keys and dialogue logic are unchanged apart from the two new prologue nodes, so saves and cases are unaffected.

Found on the way: in the open world a cutscene's `camera_look` point was read as a world position, so the prologue's glance at the door showed empty space. Points are written in the place's own coordinates, so the effect now adds the current place's origin.

## D-104 The prose pass, part 2: Act I (R16b)

Act I — Theo's growing flat and the nursery, Jonah's storeroom and the ledger, Mrs Halloway's pencil map, Ivo on the Ward, Mara on the surveyors' mark, the rain tram and its platform — rewritten by the same rules (38 strings). The tram stop and route map now say «Фонарный ряд», as the style guide requires, instead of the transliteration that had survived there. `tools/narrative_apply.py` applies a part (a table of key → (ru, en)) to whichever localization file holds each key.

## D-105 The prose pass, part 3: Act II (R16c)

Act II — the way into the Ward with Ivo, Nadiya or alone, the Ward itself, the alderman, Bea, Abel, Ellie, Dr Vale, the depot, the Conductor's platform, Rosalind and her reunion with Jonah, the companions' camp talk, and the Ward threads in Greyford (Pike, Mrs Halloway and Thursdays) — rewritten by the same rules (61 strings).
