# Campaign plan — staged content

Spoilers. How the story bible's prologue and five acts (`docs/narrative/story-and-lore-bible.md` §8–9) become playable content, in the order it will be built. Each stage is one pull request that leaves the game playable from a new game to the end of the newest act, with saves from earlier stages still loading.

The spine is data: `data/story/campaign.json` lists the acts, the condition that starts each one and the main case it opens. An act with `"planned": true` never starts, so the game always stops at a clean "to be continued" point instead of a broken one.

## Status

| Stage | Content | State |
|---|---|---|
| M7a | Campaign spine, act cards; **Act I** complete | done |
| M7b | **Act II** — the Echo Ward, companions, the Conductor, Rosalind found | done |
| M7c | **Act III** — the Keepers' pact, North Quay, the Archivist of Floods, the ally who knew | done |
| M7d | **Act IV** — the Index: three memory-sites, testimony verdicts, three Revisions, Dr Vale's choice | done |
| M7e | **Quest system and challenge rework** — no fail-forward, objectives, failable quests, mandatory bosses, difficulty (see roadmap) | done |
| M7f | **Act V** — the anchor; Director Wren; three endings and epilogues | done |
| M7g | Campaign pass: balance, full playthrough per difficulty, companion personal quests | next |

## What already exists (M1–M6)

- **Prologue** — the door on the plaza (`case_door`), Jonah's radio, *Greyford Keeps Quiet* (the three-line mark), Lantern Row echo.
- **Character stories that sit in Act I–II** — Rosalind and the Census Taker (`case_rosalind`), Mara's *Eleventh House*, Jonah's *Bell at Harbour Stop*, Nadiya's *Letters to No One*, Hester's *Light That Counts* (Lighthouse Point).
- **Systems** — evidence and hypotheses, fail-forward, factions, NPC knowledge and gossip, relationships with milestones, work and economy, combat with one boss.

## Act I — The City Has Two Maps (M7a, built)

Starts when the door case closes (either outcome). Main case `case_two_maps`:

1. **Incidents** — three places at once; any two of them give the pattern:
   - *The Missing Storeroom* (`case_storeroom`, Jonah): the stock-room door opens onto brick; after dark a door appears in the side wall. An echo storeroom (Hollow, two Clingers). Crates stencilled ROOK & DAUGHTER with the three-line mark; the 1989 ledger "counted by R. Rook, aged 12".
   - *The House That Grew* (`case_larger_house`, new NPC Theo Marsh): a ground-floor flat that gains a room every week. Pace the corridor (forty strides in a twelve-stride house); the newest door; a child's room (Wailer, Clinger); the mark on the headboard. Theo remembers a daughter, Ellie — or is told it was old plans.
   - *The ghost tram stop* — the existing Rosalind case; the Census ledger page carries the mark.
2. **Hypothesis** *The incidents are marked* (2 of 3) → Mara: it's a 1962 surveyor's sign for sites "to be reclassified".
3. **The map** — under the blotter in the newest room: Greyford in ink, and in pencil the streets that aren't there (Lantern Row, Ferry Lane, **the Ward**).
4. **The hand** — hypothesis *Mrs Halloway drew the second map* (the map + her note or her rent book).
5. **Act turn** (bible: "annotations in a handwriting matching a living NPC") — she has never drawn a map; some mornings her pencils are blunt. Keep her secret (Keepers +1), take it to Mara (Open Hand +1; Mara learns), or ask who visits — *Ivo, for tea on Sundays, who tidies her desk* (sets up Act III).

Since M7e: no step moves on by itself. Routes: two of three incidents give the pattern (the storeroom and the growing room can each be *failed* by waiting too long — the council bricks up the wall after 4 days, the newest door closes after 5); the handwriting from the note in your room or by asking Mara. The main case itself has no deadline.

## Act II — The People We Misplaced (M7b, built)

As built: the Ward is reached from the harbour stop after dark — with Ivo (Keepers), with Nadiya (Open Hand; also the route if you asked Ivo about his Sundays), or alone by reading the harbour timetable after dark. The Alderman's register (214 names) and three claims — **Bea Halloway** (wants a Thursday in Edda's kitchen; Edda leaves the back door on the latch), **Abel Crane** of the *Margaret Ellery* (wants to be left alone; can send thanks to Hester), **Ellie Marsh** (No. 11 is hers; Theo lives in it). **Dr Sera Vale** introduces Meridian. Pike asks you to report "the anomaly" (Civic +2, Unwritten −2). The depot hall and **the Conductor** on Platform Eleven: three tram lanes, at least one always safe; passengers board in phase 2; he stops to check his machine after every tram. **Rosalind** remembers Jonah as the one who vanished; reunite them (bring Jonah as your companion) or let her choose. Companions: **Jonah** (patches you up at 1 health) and **Mara** (slows the nearest echo), recruited from their usual conversation once the Ward is open; talking to them while they follow gives camp lines and lets you send them home.

Original plan (before M7e, mentions of fail-forward no longer apply):

**Region:** the **Echo Ward** — the neighbourhood removed in the Quiet Census, stable enough to live in. A hub with residents (Unwritten), not a corridor of enemies. Built from region templates with an echo palette; day/night inverted (the Ward is busiest at night).

**Entry:** Ivo keeps his promise when the tides line up — or, if the player asked about his Sunday visits, Nadiya finds another way in (the Open Hand route). Either way the Ward opens; who leads you there changes who trusts you.

**Main case — `case_misplaced`:**
1. Enter the Ward; meet its *alderman*, who remembers Greyford as the echo.
2. Three residents with conflicting claims (one wants to return, one wants to be left alone — ties to *Letters to No One*, one claims a house that a living family now owns).
3. Faction approaches: Civic Renewal (Pike's superior), the Open Hand (Nadiya), the Keepers (Ivo), the Meridian Group (first appearance: Dr Sera Vale, measuring things).
4. **Dungeon:** the Ward's sealed tram depot (handcrafted, 3 rooms + boss *the Conductor*, who collects tickets for a line that no longer runs — a mechanic of "stops" where the arena changes).
5. **Act turn:** Rosalind is in the Ward. She remembers a different childhood and insists Jonah is the one who disappeared. Outcome depends on *Bell at Harbour Stop* and *Missing Storeroom*.

**Companions begin:** Jonah and Mara can accompany the player in the Ward (follower + one combat/utility ability each, a camp conversation per act). Companion approval is the existing relationship value; milestones gate personal quests.

## Act III — A Kindness Built on a Lie (M7c, built; since M7e Ivo hands you the archive key and the Archivist cannot be skipped)

As built: starts when Act II closes; the campaign picks the **ally who knew** at that moment with `first_match` — Mara if *The Eleventh House* was sealed, else Mrs Halloway if her map was kept secret, else Ivo. Stairs appear in the municipal archive down to **the Keepers' rooms** (the Seal Engine; the pact: every echo half-shut forever). **North Quay** opens at the east end of the promenade: Nadiya explains the Open Hand's plan, Dr Vale wants Meridian's resonator back. The **flooded underpass** holds the 1962 records the flood supposedly destroyed (hypothesis *The flood was the cover story*), then **the Archivist of Floods**: the arena floods in cycles, stacks of files are dry islands, water slows you and deep water hurts; he can only be hit on the surface. The confession (stays if they are your friend, walks out otherwise), then the resonator at the Seal Engine: Keepers (seal holds), Open Hand (the Ward will open), Meridian (£60), or break it. Faction swings of ±3.

Original plan (before M7e, mentions of fail-forward no longer apply):

**Region:** **North Quay** (industrial waterfront; Meridian's research annex) and the Keepers' rooms beneath the old Custodians' hall.

- The Keepers' pact: Greyford's stability depends on a partial seal; restoring every echo at once would displace living residents.
- **Act turn:** a trusted ally admits they knew. Candidate by relationship order: Ivo (default), else Mara (if *Eleventh House* was sealed together), else Mrs Halloway (if her map was kept secret). Earlier relationships decide who stays to explain and who walks away (relationship ≥ friend stays).
- **Dungeon:** the flooded underpass (bible §4), boss *the Archivist of Floods* — water level as the arena mechanic.
- Faction conflict: the Open Hand plans a forced restoration; the player can warn, join or stop it. First real faction lock-in (standings shift by ±3).

## Act IV — The Index (M7d, built — the first act without fail-forward)

As built: starts when Act III closes. Dr Vale (Ward promenade) explains that Meridian switched on three of the Index's nodes; three doors open at the bottom of the Ward's street. Each memory-site is the night of 11 November 1962 — **St Agnes hospital**, **the Okafor kitchen on Lantern Row**, **Lantern Row station** — guarded by a **Revision** (the Matron, the Lodger, the Stationmaster): one boss class that rewrites the floor in its own pattern (rows / columns / checkerboard; one row, column or colour is always safe; the Lantern Flash breaks the channel). After the fight the three testimonies can be read and **judged — authentic, edited or unreliable** (re-read to change your mind). Reconstructing the night with at least two correct verdicts gives the *true night*; otherwise it stays *distorted* for good. The Alderman's register rewrites itself into PLEASE DON'T FORGET ME (act turn). Dr Vale: show her the true nights (needs two true sites) and she shuts the nodes down herself, tell her to finish carefully, or hand her work to the Keepers. Nothing in this act moves on by itself.

Original plan (before M7e, mentions of fail-forward no longer apply):

**Regions:** three short memory-sites reached from the Ward, each a version of the same 1962 night: the hospital archive, the family home, the abandoned station. Each presents testimony that conflicts; the player marks traces as authentic, edited or unreliable (new journal verdict on evidence — a small extension of hypotheses).

- Meridian activates the nodes; Dr Vale's arc (making the Veil safe vs. treating people as variables) reaches its choice.
- **Bosses:** one per site, each a "revision" of a person — mechanics built on the site's edit (the boss rewrites the arena).
- **Act turn:** the Lattice learned to preserve the memories of people who begged not to be forgotten, and could not tell remembrance from imprisonment.

## Act V — What We Choose to Remember (M7f, built)

As built: starts when Act IV closes. **Gather**: ask Jonah, Mara, Ivo, Nadiya, Dr Vale and the Alderman to stand with you — each says yes only if you've earned it (friendship, Rosalind, Keepers / Open Hand / Unwritten standing, Vale turned); allies wait at the anchor. A stair opens beside the Seal Engine. **Director Elias Wren** (Civic Renewal) means to collapse the cracked anchor and every echo with it. The fight cycles the campaign's mechanics — stamps, tram lanes, floor rewrites, summoned echoes; allies remove tricks (Mara: rewrites, Nadiya: lanes, the Alderman: summons, Vale: slower telegraphs, Jonah: heals at each phase, Ivo: −25% health) and each true night costs him 10% — never below 40%, never skippable. **The choice** at the anchor's heart: **Open Record**, **The New Custodians**, or **The Living Accord** (needs Unwritten ≥ 4, two true nights, three allies and three truths told to the living — otherwise the anchor shows you why it won't hold). **Epilogue** cards: the ending, then one card each for Wren, Jonah, Edda, Theo, Hester, Mara, Ivo, Vale and the Ward, plus a hidden card if some echoes chose to stay. Afterwards the world goes on (flag `game.completed`) for M8.

Original plan:

**Region:** the anchor beneath Greyford.

- Who participates in the decision: companions and factions the player has kept faith with attend; the others act on their own (consequences, not punishment).
- **Final encounter:** Director Elias Wren — not simply a boss: a fight whose phases can be shortened or skipped by evidence and allies present.
- **Endings** (bible §9), evaluated from data (`data/story/endings.json`, same condition language as everything else):
  - *Open Record* — release the Index; communities decide.
  - *The New Custodians* — rebuild the seal with oversight; some echoes stay closed.
  - *The Living Accord* — shared control; needs many optional threads (Unwritten ≥ 4, at least three character stories resolved with truth, key evidence from all four acts).
  - Hidden variation: the player knows some echoes chose to stay (*Letters to No One* respected, Hester's lamp kept, Theo's door left open).
- **Epilogues:** one card per character and faction, from their memories and standing; the world state persists into M8 (endgame).

## Rules for every stage

- Story bible §11 fairness, as revised in M7e: several *player-driven* clue paths per major reveal; nothing advances by waiting; no free hints; bosses are mandatory; a missed or failed step is a consequence carried forward, not a soft-lock.
- New content goes in its own files (`*_act2.json`, …) and region specs; GDScript changes only for genuinely new mechanics (followers, evidence verdicts, endings), each with tests.
- Every act adds a smoke-test section that plays it from the previous act's end.
- Saves from the previous stage must load and continue (the campaign derives the current act from flags, so a save made before an act existed simply starts it on load).
