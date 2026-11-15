# M8a test plan: debug act starts and expeditions

Automated (CI):
- `test_debug_act_starts_reach_every_act`: every debug target lands in its act; endgame unlocks expeditions.
- `test_expedition_board_and_rewards`: board deterministic per day, tiers have 1–3 modifiers, harder runs pay more, board changes after a run, every Index page is reachable.
- `test_expedition_modifiers_and_save`: fragile adds 1 damage, arena is the last room, run and pages survive save/load, fainting ends a run, v7 saves migrate.
- `test_shard_trinkets_need_shards_and_the_index`: shards unsellable, the bound Index needs the full Index.
- Validator: every expedition room is walkable from start to exit (and boss spot), palettes/enemies/rematch scenes exist, every page's requirement can be cleared.
- Smoke: after the ending, the rift appears; a 5-modifier run at the station with the revised Matron in rising water is cleared room by room, pays shards and pages; a shard trinket is crafted; fainting in a run ends it at the rift with the satchel.

Manual (owner playtest, `docs/production/playtest-guide.ru.md`): feel of each modifier, rematch combinations, shard pacing.
