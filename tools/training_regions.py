"""Training grounds become regions (QM, Oct 30): the four yards in the base are gone and
each ground is the region QM painted beside the spawn (Ice and Meadow west, Lava and
Desert east), joined to it by a corridor through the base wall. One-off migration of
maps/world.map:

- the Base area's `training` becomes [name, x0, z0, x1, z1]: each region's bounds (its
  floor past the base wall's inner face, corridor and all), found by flood-filling from a
  spot in it; `trainSize` goes
- a `Barrier` object with `training: true` at each corridor's base end (its blocker)
- the old yards' floors are painted over with the base grass, and their decor props move
  into their regions

Run: python3 tools/training_regions.py   (then python3 tools/map_bake.py)
"""

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "mapeditor"))
from serve import WORLD, dump  # noqa: E402

FACE = 176  # the base wall's inner face, x either side
SEEDS = {"Ice": (-300, -130), "Meadow": (-280, -30), "Lava": (300, -150), "Desert": (300, -20)}
OLD = {"Ice": (-140, -112, 2), "Meadow": (-140, -52, 0), "Lava": (142, -114, 3), "Desert": (142, -50, 1)}  # x, z, Grow


def main():
    m = json.load(open(WORLD))
    x0, z0 = m["origin"]
    cols, nrows = m["size"]
    rows = [list(r) for r in m["rows"]]
    tiles = {t["id"]: t for t in m["tiles"]}
    base = next(a for a in m["areas"] if a["name"] == "Base")
    if base["training"] and len(base["training"][0]) == 5:
        print("already migrated")
        return
    walk = lambda r, c: 0 <= r < nrows and 0 <= c < cols and rows[r][c] in tiles and not tiles[rows[r][c]].get("wall")
    zones, gates = [], []
    for name, (sx, sz) in SEEDS.items():
        west = sx < 0
        inside = lambda c: (x0 + c * 4 + 4 <= -FACE) if west else (x0 + c * 4 >= FACE)
        start = ((sz - z0) // 4, (sx - x0) // 4)
        seen, todo = {start}, [start]
        while todo:
            r, c = todo.pop()
            for nr, nc in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)):
                if (nr, nc) not in seen and walk(nr, nc) and inside(nc):
                    seen.add((nr, nc))
                    todo.append((nr, nc))
        rs = [r for r, _ in seen]
        cs = [c for _, c in seen]
        box = [x0 + min(cs) * 4, z0 + min(rs) * 4, x0 + max(cs) * 4 + 4, z0 + max(rs) * 4 + 4]
        # the corridor: its cells at the face
        edge = (min(cs) if not west else max(cs))
        mouth = [r for r, c in seen if c == edge]
        mz0, mz1 = z0 + min(mouth) * 4, z0 + max(mouth) * 4 + 4
        gx = -FACE - 1 if west else FACE + 1
        print(name, "bounds", box, "cells", len(seen), "corridor z", mz0, mz1)
        zones.append([name] + box)
        gates.append({"type": "Barrier", "region": name, "training": True, "x": gx, "z": (mz0 + mz1) // 2,
                      "yaw": 90 if west else -90, "width": mz1 - mz0, "height": 40})
        # the old yard: grass over it, its props into the region
        ox, oz, grow = OLD[name]
        half = 24 + grow * 2 + 4
        for r in range(nrows):
            for c in range(cols):
                x, z = x0 + c * 4 + 2, z0 + r * 4 + 2
                if abs(x - ox) < half and abs(z - oz) < half and rows[r][c] in tiles and not tiles[rows[r][c]].get("wall") and rows[r][c] != "d":
                    rows[r][c] = "d"
        cx = (box[0] + box[2]) / 2 + (-12 if not west else 12)  # (the region's middle, off the corridor's side)
        cz = (box[1] + box[3]) / 2
        for o in m["objects"]:
            if o["type"] == "Prop" and abs(o["x"] - ox) < half and abs(o["z"] - oz) < half:
                o["x"], o["z"] = round(o["x"] - ox + cx), round(o["z"] - oz + cz)
                print("  moved", o["item"], "to", o["x"], o["z"])
    base["training"] = zones
    base.pop("trainSize", None)
    m["objects"] += gates
    m["rows"] = ["".join(r) for r in rows]
    open(WORLD, "w").write(dump(m))


if __name__ == "__main__":
    main()
