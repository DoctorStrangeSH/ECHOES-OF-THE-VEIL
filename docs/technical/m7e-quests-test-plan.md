# M7e test plan — quests without a safety net

## Automated
- `test_waiting_never_advances_anything` — every stage of every case, 30 days: unchanged, unless it has a deadline, in which case it fails with that outcome.
- `test_failable_side_quests_share` — ≥ 25% of side quests can fail; main cases have no deadlines.
- `test_main_story_survives_failed_incidents` — failing both Act I incidents still leaves the tram-stop route.
- `test_late_radio_fails_the_case`.
- `test_objectives_progress_and_rewards` — 2/3 progress, optional reward once, pin saved.
- `test_difficulty_and_the_satchel`; `test_save_migration_from_v6`.
- Validator: rejects `fail_forward`; every non-first stage must be reached by an effect, evidence or hypothesis; deadline and objective data checked.
- Smoke: HUD objective in Act I; fainting in the depot leaves half the money there; the satchel gives it back.

## Manual
1. New game: choose difficulty (descriptions in the creator).
2. HUD (top right, under the money): the pinned case's current objective; deadlines show days left.
3. Journal: objectives with [x]/[ ], "Optional:", progress counts, "Show on screen"; failed cases marked [-].
4. Let Jonah's radio sit for 3 days → case failed, Mrs Halloway cooler towards you.
5. Ask Jonah about strange things, then wait 4 days → the storeroom is bricked up for good.
6. Faint in an echo → wake in your room; go back: your things are where you fell. Faint again before picking them up → the first satchel is gone.
7. The Conductor and the Archivist can't be avoided by waiting.
8. Act III without the Eleventh House: Ivo gives you the archive key.
9. Hester's register: the archive, or force the lifeboat locker with 3 scrap.
10. Old saves (schema 6) load on Normal.
