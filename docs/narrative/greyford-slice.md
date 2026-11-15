# Greyford Vertical Slice (M2) — Content Map

Spoilers. This is the playable prologue slice: one city block, the player's room, and the first Veil echo.

## Cast and schedules

| NPC | Role | Morning | Afternoon | Evening | Night |
|---|---|---|---|---|---|
| Mara Venn | municipal archivist | plaza (east) | plaza (east) | harbour rail | — |
| Jonah Rook | repair technician | harbour rail | his shop | his shop | — |
| Edda Halloway | landlady | by the mailbox | park bench (west) | — | — |
| Ivo Calder | residents' association (Keeper) | — | plaza (west) | park bench (east) | — |
| Nadiya Sol | courier (Open Hand) | — | — | plaza (west) | by the door |
| Dana Pike | Civic Renewal warden | plaza (south) | plaza (south) | — | — |
| Woman in green | Unwritten, Lantern Row no. 11 | echo kitchen, once the Hollows are gone | | | |

Source of truth: `data/characters/npcs.json`. Story changes during a conversation are applied when it ends.

## Case 1 — The Door That Shouldn't Be There (main case)

1. **Observe** the doorway on the plaza → `e_door_observed` (Observed, you). The case opens automatically after the intro.
2. **Gather** at least two of:
   - Mara: "What was here before the plaza?" → `e_mara_lantern_row` (Reported, Mara)
   - Mrs Halloway, when the radio is delivered → `e_halloway_lantern_row` (Reported, Halloway) and `e_radio_announcement` (Observed, radio)
   - Jonah, after the radio quest → `e_city_map` (Recorded, 1962 survey plan)
3. **Form the hypothesis** in the journal: *The door is a piece of Lantern Row* (inferred with 3 sources, corroborated with 4).
4. **Decide** (meaningful choice):
   - **Report it to Warden Pike** (possible as soon as you have seen the door). Civic Renewal fences off the plaza; the door is gone for good. Mara −2 and remembers; Nadiya −2; Ivo +1; Pike +2. Case closes: *reported*.
   - **Confide in Mara** (optional, before opening). Mara +2, remembers `trusted_with_door`; she reacts warmly afterwards and reveals her grandmother lived at no. 11.
   - **Open the door** (requires the hypothesis). Enter the echo of Lantern Row.
5. **Inside the echo**: three Hollows (telegraphed lunge, 3 hits each). Fainting is fail-forward: you wake in your room an hour later. Once they are gone, the woman in green appears in the kitchen. She knows your name; the door vanishes. Case closes: *opened*; **Lantern Row** case opens (to be continued).

Reactions after the outcome: Mara (warm if told first, hurt if not), Ivo (disapproves of opening), Nadiya (approves of opening).

## Case 2 — Rook's Radio (local quest)

Jonah (afternoon/evening at his shop) asks you to deliver Mrs Halloway's radio. Repair technicians notice the dial is soldered to a frequency no station uses. Delivering it plays a tram announcement for "Lantern Row" — two clues for Case 1. Returning to Jonah gives the 1962 survey plan.

## Case 3 — Greyford Keeps Quiet (side thread)

Clues: the three-line symbol under the yellow condo's doorbell (Observed), the landlady's note (Recorded), the note on Rook's door (Recorded), Ivo's warning (Reported). Forming the hypothesis unlocks asking Ivo about the marks — a Keeper teaser.

## Backgrounds

- **Returning local**: Mrs Halloway recognises you but cannot remember which street you lived on (foreshadows Lantern Row).
- **Former archivist**: framed as Mara's colleague (dialogue tag; expand in M4).
- **Repair technician**: extra radio branch with Jonah.
- **Courier**: +12% sprint speed.

## Fairness check (story bible §11)

The Lantern Row reveal has environmental (door, symbol), dialogue (Mara, Halloway, Ivo) and systemic/document (radio broadcast, survey plan) clue paths. No single line is missable: every clue stays available until the case closes, and NPCs repeat their hubs.

## Case 4 — The Girl Who Wasn't Counted (M3)

Unlocked after Case 1 closes (either outcome). Jonah asks you to look for his sister Rosalind, erased from every record in 1989, and gives you his wrench.

1. The **ghost tram stop** appears at the harbour promenade in the evening, at night or in rain → `e_tram_stop` (Observed).
2. Board it → **Lantern Row stop** (echo): Hollows, Clingers and a Wailer; signal lamp rod and tea on the platform.
3. Miniboss **the Census Taker** (three phases, all telegraphed). He drops the **Census ledger page** → `e_census_page` (Recorded): "ROOK, Rosalind — reclassified: NOT RESIDENT", stamped with the three-line mark (links to *Greyford Keeps Quiet*).
4. Choice with Jonah:
   - **Show him the page** — he finally knows she was real and that someone erased her on purpose. Jonah +3, remembers `told_truth_about_rosalind`; he gives you Rosalind's tram token (+1 max health).
   - **Say you found nothing** — Jonah +1, remembers `spared_about_rosalind`; you keep the page and can give it to Mara for the real archive (Mara +2, paper lantern charm).

## Economy (first pass)
Sources: £20 at start, £10 radio reward, Resonance from echoes. Sinks: Jonah's tea (£4), Attunements (Resonance). More sinks arrive with M5 (rent, repairs, business).

## M4 — Society and character stories

**Factions** (standing −10..10, shown in Journal → People): Civic Renewal, Keepers, Open Hand, Unwritten. Moved by choices, never by a single morality meter.

**Knowledge and gossip**: facts (`data/world/facts.json`) spread to their audience one time-of-day period later. Reactions read *who knows*, not global flags — reporting the door reaches Pike at once and everyone else by the next period; opening it reaches the Keepers and the Open Hand.

**Milestones**: friend (3), confidant (6), distrust (−3) per NPC, as flags other content can read.

### The Eleventh House (Mara, friend + door case closed)
Night break-in to the sealed Municipal Archive. Drawer L: Agnes Venn, Mara's grandmother, was a Census enumerator who signed Lantern Row's reclassification — the same hand as Rosalind's page (story bible: Mara conceals a document implicating her family). Outcomes: **publish** (Open Hand +2, Civic −2, flyer on the plaza, Ivo disapproves), **seal together** (Keepers +2, shared secret), **lie** (keep the file; if it later reaches Civic Renewal, gossip tells Mara and she confronts you).

### The Bell at Harbour Stop (Jonah, after the truth about Rosalind)
Collect clapper (platform echo), copper flex (Mrs Halloway), relay (Pike with Civic ≥ 1; fail-forward after 3 days). Ring it at night: Rosalind appears in the water, twelve and seventy at once (bible: each sighting contradicts the last). Answer "he's waiting" or "go home".

### Letters to No One (Nadiya, after the door case)
Three letters: Mrs Halloway learns she had a sister, Bea, who is happy where she is; the platform's emergency box brings back a reply — "We are not lost. Please stop trying to bring us back."; Ivo reveals he writes to the erased every winter. Nadiya must face that some echoes do not want to return (her bible arc). Respect their choice (Unwritten +2) or keep going (Open Hand +2, Unwritten −1).

## M5 — Work and ownership

- **Jonah** sells scrap, tea and repair kits and buys items back at half value ("Let's trade"). "Got any work?" points to the **odd-jobs board** (cork board on the yellow building) and the **scrap heap** by the bins (once a day); once, he gives 4 scrap to start.
- **Jobs** (up to 3 a day): Halloway's radiator (your room), the plaza fountain (Mara; once — the fountain stays fixed), the condo street lamp (Ivo), Pike's radio, Nadiya's mailbox, and the park bench clock (Ivo, repair level 2, pays Resonance, +Keepers).
- **Repair skill** levels 1–5 widen the minigame's green zone. Repair kits (2 scrap at the workbench) widen it once more and are used automatically.
- **Mrs Halloway** ("About my room...") sells room improvements: workbench (£40), a proper mattress (+1 max health, £30), a lantern shelf (Flash recharges 15% faster, £25). Rent is £15 a week; unpaid rent waits as debt.
- **Repair cart:** at repair level 3 and Jonah's friendship, Jonah offers the old food cart. Stock it with kits, choose fair / normal / premium prices; sales happen overnight. Fair prices build reputation; upgrades (sign, toolbox, Jonah on Saturdays — needs his full trust) add customers.
