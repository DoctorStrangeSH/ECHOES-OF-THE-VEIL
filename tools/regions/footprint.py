"""Where a sprite actually touches the ground, read from its pixels.

The ground contact of a LimeZu sprite is its lowest band of solid pixels:
baked shadows are semi-transparent and are left out (alpha <= 200). The
footprint is the x-extent of solid pixels within the bottom `band` pixels of
the solid shape; for a tree that is the trunk, for a bench its legs and seat,
for a building its front wall.
"""
from PIL import Image

_cache = {}


def footprint(path, region=None, band=6):
    """(left, right, bottom, width, height) in sprite pixels, or None."""
    key = (path, tuple(region) if region else None, band)
    if key in _cache:
        return _cache[key]
    im = Image.open(path).convert('RGBA')
    if region:
        im = im.crop((region[0], region[1], region[0] + region[2], region[1] + region[3]))
    w, h = im.size
    a = im.getchannel('A').load()
    solid_rows = [y for y in range(h) if any(a[x, y] > 200 for x in range(w))]
    if not solid_rows:
        _cache[key] = None
        return None
    bottom = solid_rows[-1]
    xs = [x for y in range(max(0, bottom - band + 1), bottom + 1) for x in range(w) if a[x, y] > 200]
    r = (min(xs), max(xs) + 1, bottom + 1, w, h)
    _cache[key] = r
    return r
