# LimeZu Asset Intake Audit — 2026-11-14

**Status:** archive metadata and license review completed. No third-party artwork or binaries committed. This report is based on the eight files supplied in chat; these are not stored in GitHub.

## Received archives

| Archive | Entries | Uncompressed size approx. | Main contents | License |
|---|---:|---:|---|---|
| Modern_Office_Revamped_v1.2.zip | 1,068 | 2.83 MiB | office rooms, furnishings, 16/32/48 scale variants | LICENSE.txt |
| modernexteriors-win.zip | 40,615 | 233.40 MiB | exterior tiles, streets, buildings, vehicles, train/subway areas, animated sheets | Modern_Exteriors_License.pdf |
| moderninteriors-win.zip | 53,329 | 155.84 MiB | interiors, themed rooms, character generator source and premade characters, animated objects | LICENSE.txt |
| modernuserinterface-win.zip | 1,004 | 4.89 MiB | UI and portrait generator art, animations | LICENSE.txt |
| Modern_Farm_v1.3.zip | 8,827 | 48.66 MiB | crops, terrain, animals, farmer art and activity animation sheets | LICENSE.txt |

These are **archive entry counts**, not counts of unique game-ready sprites. Many items are multiple resolutions, cropped singles, animated frames, alternate sorting/shadow variants, GIF previews, and directories. Do not bulk-import everything.

### Separate tools received

- `Character Generator 2.0 Setup.exe` (~70 MiB)
- `Portrait_Generator_Setup.exe` (~25 MiB)
- `Farmer Generator Setup.exe` (~28 MiB)

**Security policy:** these are executable installers, not art archives. They were **not executed**. Use only in an isolated, trusted Windows environment after publisher/signature/hash checks, malware scanning, and a clear need. The included PNG generator layers may be sufficient without running any installer.

## Observations relevant to ECHOES OF THE VEIL

- The archives include 16x16, 32x32, and 48x48 material in various layouts. Choose **one canonical world base scale** for M1/M2; do not mix variants accidentally. Provisional recommendation is 16x16 base tiles with integer upscale for rendering, to be confirmed by in-engine samples.
- Interiors include `2_Characters/Character_Generator/`, premade characters, hairstyles, outfits, and animation reference art. Custom character creation is feasible to prototype, but actual compatible combinations and animation coverage still need a visual alignment test.
- Exteriors include street/building themes and substantial transit material such as subway/train assets, useful for Greyford's tram/transit mystery. Asset evidence does not prove a complete ready-to-play city layout.
- Farm archive provides crops, terrain, animals, and farmer activities, supporting the later life-simulation milestone.
- UI archive provides visual building blocks and portrait layers; it is not necessarily a complete functional UI.

## License findings from included files

- **Modern Interiors:** commercial and non-commercial project use/editing permitted; reselling or redistributing the asset prohibited; **credits required** (limezu.itch.io).
- **Modern Exteriors:** embedded one-page PDF permits commercial/non-commercial use, edits, and use in open-source projects (e.g., GitHub), but prohibits reselling/distributing the asset to others and edited resale (including NFT minting); **credits required**. Treat permission for use in open-source projects as distinct from permission to redistribute raw purchased packs. Keep raw assets out of this public repo.
- **Modern User Interface:** commercial/non-commercial use/editing permitted **except NFT minting**; resale/distribution prohibited; **credits required**.
- **Modern Farm:** commercial/non-commercial use/editing permitted; resale/distribution prohibited; credit appreciated.
- **Modern Office:** commercial/non-commercial use/editing permitted; resale/distribution prohibited; credit appreciated.

This is an implementation-oriented summary, not a substitute for keeping the original license files alongside internal asset records. Credit LimeZu in game credits and store materials where required.

## Recommended import plan

1. Keep the original ZIPs in a private source-art store outside the public repository.
2. Create a private license manifest recording pack, version, license filename, attribution, original archive hash and source URL.
3. Extract a **minimal selected set** for M1/M2 (one outdoor tileset, one indoor tileset, character/base + hair + outfit sample, one UI sheet).
4. Use nearest-neighbor filtering, pixel-aligned movement/camera decisions, consistent y-sort anchors and collision footprints.
5. Build a small visual test scene with day/night exterior, one house interior and a customizable character (e.g., two hairstyles + two outfits) and verify all directions/animations.
6. Do not commit asset ZIPs or installers to GitHub; for public source distribution, prefer source-free placeholders or a documented private asset import step.
7. Create original Veil, monsters, portal effects and boss assets separately; these were not verified as present in the supplied packs.

## Next technical gate

**M1** needs a pinned Godot 4.x version, project scaffold, player controller, camera, collision, interaction, scene transition, and versioned save/load. Build a minimal assets-optional prototype first, then integrate a carefully selected LimeZu subset privately. The archive audit does not count as a playable milestone.
