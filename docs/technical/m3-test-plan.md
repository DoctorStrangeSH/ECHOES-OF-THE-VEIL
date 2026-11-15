# M3 Test Plan — Core RPG Loop

Automated: `godot --headless --path . res://tests/test_runner.tscn` (adds inventory, equipment, stacking, attunements and stat stacking, shop rules, item→evidence→case advance, Health i-frames/heal, enemy variants, v2→v3 save migration).

## Combat feel (Veil locations only)
1. **Combo**: J / left mouse ×3 — third hit is slower, knocks back further, hit-stop and shake are stronger. Pausing > 0.5 s resets the combo.
2. **Dodge**: Space / K / right mouse / B — short dash with afterimages and i-frames; you can dash through a lunge and through a stamp. Cooldown ring bottom-left.
3. **Lantern Flash**: Q / Y — expanding ring stuns every echo in range (they glow yellow); the Census Taker is only interrupted briefly and not mid-charge.
4. **Quick heal**: R / LB eats a sandwich first, then tea. "Nothing to heal with" toast when empty.
5. Enemies: Hollow (glow → lunge), Clinger (small, fast, 1 HP), Wailer (keeps distance, glows, throws a shard that breaks on walls). Health bars appear on hit. Motes drift to you; Resonance counter top-right.
6. Fainting still returns you to your room; defeated enemies stay defeated; the boss fight resets.

## Census Taker
7. Entering the right half of the platform wakes him; the turnstile gate closes behind you.
8. Phase 1: three red squares fill up, then stamp. Phase 2: four stamps, summons two Clingers. Phase 3: a red line aims at you, then he charges along it. Every attack can be avoided by moving or dodging.
9. On defeat: gate opens, ten motes and the Census page drop; picking up the page adds evidence and advances Jonah's case.

## Items, money, progression
10. I opens the inventory (game paused): filters, details, equip/unequip, use. Pause menu also has Inventory and Journal.
11. Attunements tab: buying respects cost and prerequisites; max health updates immediately in the Veil.
12. Brass compass in your room; signal rod and tea on the platform (one-time pickups survive save/load).
13. Jonah sells tea for £4; the radio quest pays £10; Mrs Halloway gives two sandwiches.

## Story
14. After the door case closes, Jonah asks about his sister and gives you his wrench. The ghost tram stop appears at the harbour in the evening, at night or in rain.
15. Return with the page: **show him** (relationship +3, his sister's tram token) or **spare him** (keep the page; you can later give it to Mara for the paper lantern charm).
