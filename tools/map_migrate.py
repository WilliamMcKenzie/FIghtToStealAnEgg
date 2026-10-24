"""Brings an older .map up to date, keeping its edits (QM, Oct 24): pillars and arches move
from `fixed` into `objects`, where the editor can move, turn, scale, recolour and delete them.

Run: python3 tools/map_migrate.py [file.map]    (default maps/world.map; rewrites it in place)
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from map_gen import dump_map  # noqa: E402


def migrate(d):
    f = d["fixed"]
    for st, x, z, size, h, kind in f.pop("pillars", []):
        d["objects"].append({"type": "Pillar", "style": st, "kind": kind, "x": x, "z": z, "size": size, "height": h})
    for st, x, z in f.pop("arches", []):
        d["objects"].append({"type": "Arch", "style": st, "x": x, "z": z})
    return d


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "maps", "world.map")
    d = migrate(json.load(open(path)))
    open(path, "w").write(dump_map(d))
    print("migrated", path)
