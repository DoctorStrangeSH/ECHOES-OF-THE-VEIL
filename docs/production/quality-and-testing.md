# Quality & Testing Strategy

## Quality gates

### Every commit
- project opens in the pinned Godot version;
- GDScript parse/import errors are checked;
- changed scenes can be launched through a documented test path;
- no purchased source archives or secrets are committed.

### Every pull request
- concise purpose and scope;
- screenshots or short capture for visual changes;
- manual test steps;
- automated test results;
- save compatibility note;
- known limitations and follow-up issue references.

### Every milestone
- clean-clone test on a second machine or clean workspace;
- full new-game-to-milestone flow;
- save/load and backup recovery;
- keyboard and controller smoke test where supported;
- performance capture on target hardware;
- localization overflow review;
- regression suite.

## High-risk test areas

1. **Save integrity:** interrupted write, corrupt file, older schema, missing content ID, backup restore.
2. **Quest state:** choices made in different orders, NPC unavailable, player leaves region, time advances, quest fails forward.
3. **NPC schedule:** scene changes, blocked paths, story override, off-screen simulation, sleep / wait.
4. **Inventory/economy:** stack limits, selling/buying, currency bounds, duplicate rewards, crafting exploit loops.
5. **Scene flow:** transition during dialogue/combat, invalid spawn ID, returning from interior, save at transition boundary.
6. **Character customization:** missing sprite layer, invalid palette, animation alignment, saved appearance compatibility.
7. **Localization:** long strings, missing keys, font coverage, pluralization.

## Narrative QA

- clue provenance is preserved;
- at least three clue paths support major revelations;
- testimony is consistent with each NPC's knowledge state;
- choices have documented immediate and delayed consequences;
- journal distinguishes fact, report, record, and hypothesis;
- no critical progression depends on a single missable line.

## Playtest questions

- What did you think the game was about after 10 minutes?
- What made you curious enough to continue?
- Which character did you remember, and why?
- Did you understand what the interaction prompt meant?
- Did you feel your decision mattered? What changed?
- Where did you feel lost, bored, or overwhelmed?
- Would you recommend the demo to a friend? What would you tell them it is?

## Defect severity

- **Blocker:** cannot launch, progress, save/load, or complete critical path.
- **Critical:** data loss, repeatable crash, broken major quest, severe exploit.
- **Major:** feature materially broken or confusing, substantial visual/audio defect.
- **Minor:** cosmetic issue, small text/layout problem, low-impact inconsistency.

No milestone is complete with open Blocker or Critical defects.
