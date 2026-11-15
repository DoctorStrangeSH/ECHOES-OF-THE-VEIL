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
