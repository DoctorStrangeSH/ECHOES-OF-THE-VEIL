# M7a test plan — campaign spine and Act I

## Automated
- `test_campaign_acts_start_in_order`, `test_campaign_data_is_consistent` — prologue at a new game; act I only after the door case; act II after act I; planned acts never start; titles translated.
- `test_act_one_incidents_lead_to_the_map`, `test_act_one_fail_forward_never_blocks` — two marked incidents form the pattern; map → hand → turn; Theo, Mara and Jonah's fail-forwards each move the case.
- `test_closed_cases_do_not_replay_their_last_stage` — regression for the repeating radio reward.
- Smoke test "act I": Jonah's storeroom (echo fight, crate, ledger), Theo's corridor and newest room (echo fight, bed, desk), both hypotheses, Halloway's answer, act II card, Ivo's promise.
- `validate_content.py` now fails on dialogue entries that hide a hub, and checks fail-forward notes and stages.

## Manual
1. Load a save made after the door case (M6 or earlier): the Act I card appears and *The City Has Two Maps* is in the journal. The journal title shows the current act.
2. New game → close the door case either way → Act I card (Esc or E skips it).
3. Jonah → "Anything strange happen to you lately?" — during the day the side wall is warm brick; after 18:00 there is a door.
4. Theo on the park bench (morning) → his flat (afternoon door). Walk to the far end of the corridor; a door appears.
5. Form *The incidents are marked* with any two of: storeroom stencil, the headboard, the Census page.
6. Mara (while the case is at "map") explains the mark. The desk in the newest room has the map.
7. Form *Mrs Halloway drew the second map* (her note in your room or, after two days, Mara's comparison).
8. Each of Mrs Halloway's three answers: check relationships, factions, memories in Journal → People.
9. Act II card; Ivo → "What is the Ward?".
10. Wait out each stage instead: every stage moves on by itself (see campaign plan).
11. Russian: no gendered forms for the player in new lines.
