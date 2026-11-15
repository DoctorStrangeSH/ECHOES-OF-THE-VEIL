# M7b test plan — Act II, companions, the Conductor

## Automated
- `test_party_companion_lifecycle` — recruit and dismiss by story effect, companion leaves their schedule, party survives save/load, unknown ids refused.
- `test_jonah_patches_you_up` — heals 2 at 1 health, then cooldown; followers never block the player.
- `test_slow_and_conductor_lanes` — Mara's pin slows; the Conductor always calls the player's lane and always leaves one lane free; phases by health.
- `test_save_migration_from_v5` — schema 6 adds `party`.
- `test_act_two_never_blocks` — timetable, Alderman, depot and Jonah fail-forwards; Rosalind's schedule follows the case.
- Smoke "act II": Nadiya's way in at night, the Ward's enter scene, all three residents and Dr Vale, the Alderman, Jonah as companion (follows into the depot), depot hall, the Conductor, Rosalind reunited, the hypothesis, camp dialogue "go home".

## Manual
1. After Act I: Ivo → "What is the Ward?" → harbour stop after dark ("The stop that isn't on the map"). If you asked about his Sundays in Act I he refuses — ask Nadiya. Or wait two days.
2. The Ward is lit and blue; residents never move. Hear Bea, Abel, Ellie (choices depend on Theo's and Hester's endings), meet Dr Vale.
3. Tell the Alderman you've heard them; the tram shelter becomes the depot entrance.
4. Ask Jonah or Mara "Come with me for a while?" — they follow through doors, are not solid, and talking to them gives camp lines, Jonah's shop, "Go home for now".
5. Jonah heals you once when you drop to 1 health (45 s cooldown); Mara slows the nearest echo every 10 s (blue tint).
6. The Conductor: lanes light yellow, then a ghost tram runs; one lane is always free; passengers board in phase 2; Lantern Flash interrupts him except while a tram is running. The gate closes behind you.
7. Rosalind on the platform: with Jonah → reunion; without → "I'll bring him" (then bring him), or let her choose.
8. Back in Greyford: Mrs Halloway and Bea's Thursdays; Pike and "the anomaly".
9. Old saves (schema 5) load with no companion.
10. Russian: player lines are gender-neutral.
