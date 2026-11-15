extends Node
## Small set of cross-system events. Add a signal only when two systems that
## must not know each other need to talk. Owner: core. Test: tests/run_tests.gd.

## A line-by-line message for the dialogue box. `lines` are localization keys
## or already-translated strings; `speaker` is a key or empty.
signal message_requested(lines: PackedStringArray, speaker: String)
## Emitted by the dialogue box when the last line was dismissed.
signal message_finished
## Short non-blocking notification (e.g. "Game saved").
signal toast_requested(text: String)
## The player used an interactable with a stable ID.
signal interaction_performed(interaction_id: StringName)
## A world/story flag changed.
signal flag_changed(flag_id: StringName, value: Variant)
## The player's best interaction target changed. Empty prompt = nothing in reach.
signal interaction_focus_changed(prompt: String)
## Restore the player's health (e.g. after resting).
signal player_heal_requested
## Player health changed (for the HUD). max_health 0 = hide.
signal player_health_changed(health: int, max_health: int)
## A relationship value changed.
signal relationship_changed(npc_id: StringName, value: int)
