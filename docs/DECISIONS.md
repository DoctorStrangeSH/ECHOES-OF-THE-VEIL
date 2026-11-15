# Project Decision Log

Decisions are recorded with date, status, and rationale. Revisit only when evidence or constraints materially change.

| ID | Decision | Status | Rationale |
|---|---|---|---|
| D-001 | Build a standalone ECHOES OF THE VEIL project; do not mix with other game repositories. | Accepted | Independent identity and clean production history. |
| D-002 | Godot 4.x, top-down 2D pixel art. | Accepted | Matches the intended asset workflow and scope. Exact minor version remains to be pinned. |
| D-003 | Single-player, offline-first, Windows / Steam as first target. | Accepted | Keeps production focused and avoids MMO/network complexity. |
| D-004 | Modern everyday setting collides with ancient supernatural mystery. | Accepted | Makes use of modern LimeZu environment packs while creating a distinctive narrative hook. |
| D-005 | Customizable player character. | Accepted, feasibility-gated | Scope of customization depends on the actual purchased sprite layers and animation coverage. |
| D-006 | Purchased LimeZu packs are third-party assets with pack-specific license terms. | Accepted | Audit each archive and license before import or distribution. |
| D-007 | Build a polished Greyford vertical slice before expanding to multiple regions. | Accepted | Validates the core hook and production pipeline early. |
| D-008 | Main story centers on the Lattice, the Quiet Census, and the ethics of restoring erased memories/communities. | Proposed canon v0.1 | Provides a mystery with human stakes and multiple defensible resolutions. |
| D-009 | No runtime generative-AI dependency for NPC dialogue or core progression. | Accepted for launch | Protects offline play, authorial consistency, cost, and reliability. |
| D-010 | Premium single-player business model; no mandatory online monetization. | Proposed | Best fit for a complete narrative RPG; price to be validated later. |

## Open questions

- Which LimeZu packs and exact versions are owned?
- What tile sizes, character sheets, and animation formats do those archives contain?
- Which Godot 4 minor version is installed on the development machine?
- What minimum PC specification should be targeted?
- Is controller support required for the first demo or only full release?
- Which languages beyond English and Russian are commercially justified?
