#!/usr/bin/env python3
"""Cuts LimeZu's furnished room designs (Modern Interiors / 6_Home_Designs)
into single furniture sprites, so rooms can be furnished object by object
and y-sorted with characters.

Writes PNGs + catalog.json into the PRIVATE art submodule
(assets/limezu/derived/furniture/), never into the public repo.

    python3 tools/art/extract_furniture.py
"""
import json, os
import numpy as np
from PIL import Image
from scipy import ndimage

ART = 'assets/limezu'
SRC = ART + '/modern_interiors/6_Home_Designs'
OUT = ART + '/derived/furniture'

def objects(img):
    a = np.array(img.convert('RGBA'))
    mask = a[:, :, 3] > 0
    # Grow by 1px so a pot and its plant, or a lamp and its shade, stay one object.
    grown = ndimage.binary_dilation(mask, iterations=1)
    lab, n = ndimage.label(grown, structure=np.ones((3, 3)))
    for sl in ndimage.find_objects(lab):
        ys, xs = sl
        crop = a[ys, xs].copy()
        sub = lab[ys, xs] == lab[ys.start + (ys.stop - ys.start) // 2, xs.start + (xs.stop - xs.start) // 2]
        if crop[:, :, 3].sum() == 0:
            continue
        yield xs.start, ys.start, Image.fromarray(crop)

def main():
    os.makedirs(OUT, exist_ok=True)
    catalog = {}
    for root, _, files in os.walk(SRC):
        for f in sorted(files):
            low = f.lower()
            if 'layer' not in low or 'layer_1' in low:
                continue
            design = (os.path.basename(os.path.dirname(root)).replace('_Designs', '').replace('_Home_Designs', '')
                      + '_' + f.split('_layer')[0].split('_Layer')[0].replace('_16x16', '')).lower()
            design = design.replace('__', '_').replace('-', '_')
            img = Image.open(os.path.join(root, f))
            for i, (x, y, crop) in enumerate(objects(img)):
                if crop.size[0] < 4 or crop.size[1] < 4:
                    continue
                name = f'{design}_{low.split("layer_")[1][0]}_{i:02d}'
                crop.save(os.path.join(OUT, name + '.png'))
                catalog[name] = {'design': design, 'x': x, 'y': y, 'w': crop.size[0], 'h': crop.size[1]}
    json.dump(catalog, open(os.path.join(OUT, 'catalog.json'), 'w'), indent=1)
    print(len(catalog), 'objects')

if __name__ == '__main__':
    main()
