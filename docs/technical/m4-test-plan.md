# M4 Test Plan — Narrative and NPC Foundation

Automated (`tests/test_runner.tscn`, 31 tests): quest graphs (every stage reachable, transitions point to real stages), every NPC memory has text, gossip timing and audiences, relationship milestones, faction conditions and tiers, fail-forward of a stalled case, Lantern Row clues remain obtainable after fail-forward, v3→v4 save migration. The smoke test now also plays Mara's archive story and opens the People tab.

## Manual
1. **Gossip**: report the door to Pike in the morning. Mara and Nadiya do *not* react until the afternoon; Pike knows at once.
2. **Milestones**: raise Mara to 3 → toast "now considers you a friend"; she asks for a favour once the door case is closed.
3. **People tab** (Journal → People): factions with standing and tier; everyone you met, their relationship tier and what they remember about you.
4. **Fail-forward**: accept Jonah's radio and ignore it for two in-game days → note that Mrs Halloway collected it; Jonah still gives the map; Mrs Halloway can still be asked about Lantern Row.
5. **The Eleventh House** (Mara): at night, enter the teal archive building with her key; Mara waits at the desk; drawer L in the grey cabinet; choose *show* (flyer appears on the plaza next visit; Open Hand up, Civic down), *read together and seal* (Keepers up) or *lie* (if the file later reaches Civic Renewal via Pike, Mara learns from gossip and confronts you, −4).
6. **The Bell at Harbour Stop** (Jonah, after you told him the truth about Rosalind): clapper on the Lantern Row platform, wire from Mrs Halloway, relay from Pike (needs Civic ≥ 1) or after 3 days Jonah finds one. Ring the bell at night at the harbour; answer Rosalind.
7. **Letters to No One** (Nadiya, after the door case): deliver to Mrs Halloway (her forgotten sister Bea), the emergency box on the ghost platform (a reply appears on your desk), and Ivo (press him to learn about his winter letters). Report to Nadiya: respect the echoes' choice or keep going.
8. **World changes**: MISSING poster for Rosalind by the shop after you tell Jonah; OPEN THE RECORDS flyer after Mara publishes; Pike also patrols in the evening once the door is reported.
