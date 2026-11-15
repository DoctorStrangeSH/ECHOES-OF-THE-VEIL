# Art & Asset Pipeline

## Source assets

The project intends to use the user's purchased LimeZu packs. The ZIP archives have not yet been supplied to this repository or audited. Until they are received, do not assume exact pack contents, tile sizes, animation sets, or license terms.

## Intake checklist

For every purchased pack:
1. Preserve the original archive outside the runtime project as a source backup.
2. Record pack title, creator, purchase/source URL, version/date, license text, attribution requirement, and permitted commercial use.
3. Inspect directory structure, file formats, tile dimensions, sprite dimensions, frame layouts, pivots, and animation naming.
4. Create a manifest mapping source files to intended project use.
5. Identify duplicates, optional variants, and files that should not ship.
6. Never commit the original purchased archive or redistribute raw pack contents unless the specific license explicitly permits it.

## Import conventions

- Keep source art unchanged where practical; create derived files in a separate project directory.
- Do not resize pixel art with smooth filtering.
- Configure nearest-neighbor texture filtering and pixel-aligned camera/rendering.
- Document tile size, character footprint, sorting origin, collision footprint, and animation frame timing.
- Use consistent pivots and feet/ground anchors for characters.
- Separate visual layers from collision/navigation data.
- Name imported assets by stable semantic IDs, not arbitrary archive paths.
- Track source-to-derived provenance.

## Visual direction

Everyday Greyford should feel welcoming, lived-in, and legible. The Veil should retain recognizable architectural echoes but introduce impossible geometry, restrained luminous accents, layered parallax, and a more unsettling palette. Avoid mixing incompatible perspectives or tile scales.

New original art must match:
- camera angle and pixel density;
- outline weight and palette logic;
- character-to-door / furniture scale;
- light direction and shadow softness;
- ground contact and sorting conventions.

## Character customization feasibility

Before building a large editor, audit whether purchased character sheets support modular body, hair, clothing, and accessory layers with aligned frames. If not, define a limited set of complete outfit variants for the first slice and commission/create modular pieces later.

## License and credits

A pack's commercial-use permission does not automatically permit redistribution of source files. Keep license records private if required, add required attribution to in-game credits and store page, and ensure no raw pack archives are included in public releases. Review each pack separately; do not infer terms from another LimeZu pack.
