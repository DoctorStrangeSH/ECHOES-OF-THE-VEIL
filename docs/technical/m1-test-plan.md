# M1 Test Plan — Technical Proof

Automated: `godot --headless --path . res://tests/test_runner.tscn` (save round trip, corrupt-file fallback, schema validation, GameState round trip, localization completeness, input actions, tile painter, scene registry and door/spawn consistency).

Manual checks below. Run each with and without the LimeZu packs imported (placeholders must keep the game playable).

## Boot and menu
1. Launch → fade into the main menu; title, tagline, LimeZu credit visible. "Continue" is disabled with no save.
2. Toggle language → all menu text switches between English and Russian.

## Movement and camera
3. New game → player appears at the bus stop facing up; location name toast shows.
4. Move in 8 directions; diagonal speed equals straight speed; sprite faces the dominant direction; walk/idle animations play.
5. Hold Shift → sprint. Release all keys → the player stops quickly without sliding.
6. Walk into buildings, lamps, trees, benches, the fountain, the car, the water and the map edges → blocked; no jitter or getting stuck.
7. Walk north of a lamp/tree → the player is drawn behind it; south → in front (y-sorting).
8. Camera follows smoothly and never shows outside the map.

## Interaction and dialogue
9. Stand next to any sign/door/NPC → a prompt `[E] <action>` appears; it disappears when walking away.
10. With two targets in reach, the higher-priority one wins (Mara over the fountain).
11. Talk to Mara → three lines with typewriter text; first press completes a line, second advances; movement is locked until the end; she turns to face the player.
12. Talk again → only the repeat line.
13. Inspect the floating door on the plaza → four lines; inspect again → repeat lines.

## Scene transitions
14. Enter the brown house door → fade → player inside facing up at the doorway.
15. Exit through the bottom doorway → back outside in front of the brown house, facing down.
16. Spam the interact key during a transition → only one transition happens.

## Save / load
17. Inside the room, use the bed → "Game saved" message. Quit to main menu → "Continue" is enabled → continue → same room, same position and facing.
18. F5 outdoors, walk away, F9 → back at the saved spot. Story flags (Mara met, door seen) survive.
19. Close the game, delete or corrupt `slot_1.json` in the user data folder (`%APPDATA%/Godot/app_userdata/Echoes of the Veil/saves`), continue → the backup loads with a notice; the corrupt file is kept as `slot_1.corrupt-*.json` after the next save.

## Pause
20. Esc → game freezes, menu appears. Resume, Save, Load, Language, Main menu and Quit all work. Esc closes the menu. Esc during dialogue does nothing.

## Exit gate (from roadmap)
Clean launch, repeatable movement and interactions, save/load round-trip, no parser/runtime errors in the Output panel during steps 1–20.
