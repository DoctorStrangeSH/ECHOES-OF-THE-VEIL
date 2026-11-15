# Campaign plan — staged content

Spoilers. How the story bible's prologue and five acts (`docs/narrative/story-and-lore-bible.md` §8–9) become playable content, in the order it will be built. Each stage is one pull request that leaves the game playable from a new game to the end of the newest act, with saves from earlier stages still loading.

The spine is data: `data/story/campaign.json` lists the acts, the condition that starts each one and the main case it opens. An act with `"planned": true` never starts, so the game always stops at a clean "to be continued" point instead of a broken one.

## Status

| Stage | Content | State |
|---|---|---|
| M7a | Campaign spine, act cards; **Act I** complete | this PR |
| M7b | **Act II** — the Echo Ward (first stable Veil site), Rosalind found | next |
| M7c | **Act III** — the Keepers' pact; the ally who knew | |
| M7d | **Act IV** — the Index: three memory-sites, Meridian | |
| M7e | **Act V** — the anchor; endings and epilogues | |
| M7f | Campaign pass: balance, fail-forward audit, full playthrough tests | |

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

Fail-forward: Mara's hint (incidents), Theo brings the map (3 days), Mara recognises the sevens (2 days), Jonah photographs the crate (3 days), Theo's note about the headboard (3 days). Nothing requires combat, the archive key or a side story.

## Act II — The People We Misplaced (M7b)

**Region:** the **Echo Ward** — the neighbourhood removed in the Quiet Census, stable enough to live in. A hub with residents (Unwritten), not a corridor of enemies. Built from region templates with an echo palette; day/night inverted (the Ward is busiest at night).

**Entry:** Ivo keeps his promise when the tides line up — or, if the player asked about his Sunday visits, Nadiya finds another way in (the Open Hand route). Either way the Ward opens; who leads you there changes who trusts you.

**Main case — `case_misplaced`:**
1. Enter the Ward; meet its *alderman*, who remembers Greyford as the echo.
2. Three residents with conflicting claims (one wants to return, one wants to be left alone — ties to *Letters to No One*, one claims a house that a living family now owns).
3. Faction approaches: Civic Renewal (Pike's superior), the Open Hand (Nadiya), the Keepers (Ivo), the Meridian Group (first appearance: Dr Sera Vale, measuring things).
4. **Dungeon:** the Ward's sealed tram depot (handcrafted, 3 rooms + boss *the Conductor*, who collects tickets for a line that no longer runs — a mechanic of "stops" where the arena changes).
5. **Act turn:** Rosalind is in the Ward. She remembers a different childhood and insists Jonah is the one who disappeared. Outcome depends on *Bell at Harbour Stop* and *Missing Storeroom*.

**Companions begin:** Jonah and Mara can accompany the player in the Ward (follower + one combat/utility ability each, a camp conversation per act). Companion approval is the existing relationship value; milestones gate personal quests.

## Act III — A Kindness Built on a Lie (M7c)

**Region:** **North Quay** (industrial waterfront; Meridian's research annex) and the Keepers' rooms beneath the old Custodians' hall.

- The Keepers' pact: Greyford's stability depends on a partial seal; restoring every echo at once would displace living residents.
- **Act turn:** a trusted ally admits they knew. Candidate by relationship order: Ivo (default), else Mara (if *Eleventh House* was sealed together), else Mrs Halloway (if her map was kept secret). Earlier relationships decide who stays to explain and who walks away (relationship ≥ friend stays).
- **Dungeon:** the flooded underpass (bible §4), boss *the Archivist of Floods* — water level as the arena mechanic.
- Faction conflict: the Open Hand plans a forced restoration; the player can warn, join or stop it. First real faction lock-in (standings shift by ±3).

## Act IV — The Index (M7d)

**Regions:** three short memory-sites reached from the Ward, each a version of the same 1962 night: the hospital archive, the family home, the abandoned station. Each presents testimony that conflicts; the player marks traces as authentic, edited or unreliable (new journal verdict on evidence — a small extension of hypotheses).

- Meridian activates the nodes; Dr Vale's arc (making the Veil safe vs. treating people as variables) reaches its choice.
- **Bosses:** one per site, each a "revision" of a person — mechanics built on the site's edit (the boss rewrites the arena).
- **Act turn:** the Lattice learned to preserve the memories of people who begged not to be forgotten, and could not tell remembrance from imprisonment.

## Act V — What We Choose to Remember (M7e)

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

- Story bible §11 fairness: three clue paths per major reveal; no permanently missable critical information; fail-forward on every stage of a main case.
- New content goes in its own files (`*_act2.json`, …) and region specs; GDScript changes only for genuinely new mechanics (followers, evidence verdicts, endings), each with tests.
- Every act adds a smoke-test section that plays it from the previous act's end.
- Saves from the previous stage must load and continue (the campaign derives the current act from flags, so a save made before an act existed simply starts it on load).
