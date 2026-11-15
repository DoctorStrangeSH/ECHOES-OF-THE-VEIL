# M2 Test Plan — Greyford Vertical Slice

Automated: `godot --headless --path . res://tests/test_runner.tscn` now also checks every dialogue (nodes, text keys), every story reference (evidence, cases, hypotheses, scenes, NPC dialogues), journal hypothesis/corroboration rules, the world clock, NPC anchors, v1→v2 save migration and the creator's layer parsing.

## Character creator
1. New game → creator. Change skin, eyes, outfit (style and colour), hair, accessory; the preview walks in four directions. Randomise works.
2. Each background shows its description. Empty name → default name. Begin → arrive at the bus stop with the intro.

## Time, weather, schedules
3. Clock top-right advances ~1 game minute per second, not during dialogue/menus.
4. At 12:00, 18:00 and 22:00 NPCs fade out and reappear at their next spot (see docs/narrative/greyford-slice.md). Nobody vanishes mid-conversation.
5. Bed → "Wait until evening" / "Sleep until morning" skips time and saves. On a rainy day rain falls outdoors only and the scene is darker.

## Dialogue and journal
6. Choices appear after the line finishes; mouse, arrows + E, or number keys select. Esc does not open the pause menu during dialogue.
7. Tab opens the journal (game paused): cases, objectives, evidence with kind and source, hypotheses. Forming one updates the case.
8. Two clues shared by the same person count as one source.

## Main case paths (play each on a fresh save)
9. **Report path**: see the door → tell Pike → barriers appear, door inaccessible, case closed. Mara/Nadiya react coldly; Ivo thanks you.
10. **Open path**: collect clues, form the hypothesis, (optionally tell Mara), open the door → echo. Fight three Hollows; get hit until you faint once → wake in your room an hour later, Hollows you beat stay beaten. Clear them → the woman appears → talk → walk back → the door is gone; Lantern Row case opens.
11. Rook's radio: accept, deliver (morning mailbox / afternoon bench), return to Jonah → map.

## Saves
12. Save/load at each stage above restores flags, journal, clock, relationships and NPC positions.
13. A save from M1 (schema 1) loads with default profile.

## Combat feel (echo only)
14. J / left mouse / X strikes in the facing direction; enemies glow before lunging and can be sidestepped; hits knock back both sides; i-frames blink. Attack does nothing in the town.
