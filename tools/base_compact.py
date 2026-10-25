"""The compact base (QM, Oct 25): five pens in a row along the south wall, four training
grounds down the sides (Meadow and Desert west, Ice and Lava east), the spawn in a dirt
yard between them, close to the gateway. Lays it into maps/world.map (the Base area's
cells, its walls, its pens, training grounds and spawn) and leaves everything else as it is.

Run: python3 tools/base_compact.py && python3 tools/map_bake.py maps/world.map
"""

import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "mapeditor"))
from quasicrystal import value  # noqa: E402
from serve import dump  # noqa: E402

WORLD = os.path.join(HERE, "..", "maps", "world.map")

HALF = 176  # inside: x -176..176, as before (the side walls stay where they were)
NORTH, SOUTH = -152, 56  # its north edge (the Meadow's south wall) and south edge (was 152)
WALL = 48  # the outer walls' thickness
OLD_SOUTH = 152  # (the old south wall, cleared)
GATE_HALF = 24
PEN_SIZE, TRAIN_SIZE = 56, 48
PENS = [(x, 16) for x in (-136, -68, 0, 68, 136)]  # a row along the south wall
TRAINING = [("Meadow", -140, -112), ("Desert", -140, -52), ("Ice", 140, -112), ("Lava", 140, -52)]
SPAWN = (0, -72)


def main():
    m = json.load(open(WORLD))
    cell, (ox, oz) = m["cell"], m["origin"]
    ids = {(t["area"], t["key"]): t["id"] for t in m["tiles"]}
    grass, dirt, wall = ids[("Base", "Grass")], ids[("Base", "Dirt")], ids[("Base", "WallDirt")]
    rows = [list(r) for r in m["rows"]]

    def cells(x0, x1, z0, z1):
        for r in range(max(0, (z0 - oz) // cell), min(len(rows), (z1 - oz) // cell)):
            for c in range(max(0, (x0 - ox) // cell), min(len(rows[0]), (x1 - ox) // cell)):
                yield r, c, ox + c * cell + cell / 2, oz + r * cell + cell / 2

    # clear the old base south of its north edge (and its old south wall), then walls
    for r, c, x, z in cells(-HALF - WALL, HALF + WALL, NORTH, OLD_SOUTH + WALL):
        rows[r][c] = "."
    for r, c, x, z in cells(-HALF - WALL, HALF + WALL, NORTH, SOUTH + WALL):
        rows[r][c] = wall
    # the floor: grass, a ragged dirt yard round the spawn, lanes to the gateway, to each
    # training ground's gate and along the front of the pens
    sx, sz = SPAWN
    for r, c, x, z in cells(-HALF, HALF, NORTH, SOUTH):
        oval = ((x - sx) / 60) ** 2 + ((z - sz) / 50) ** 2
        d = oval + 0.9 * (float(value(np.array(x), np.array(z), 7, 6)) - 0.5) < 1
        d |= abs(x) < GATE_HALF and z < sz
        d |= any(abs(z - tz) < 8 and abs(x) < abs(tx) - TRAIN_SIZE / 2 for _, tx, tz in TRAINING)
        d |= abs(x) < 12 and sz < z < 0
        d |= -28 < z < -12 and abs(x) < 164
        inside = any(abs(x - px) < PEN_SIZE / 2 and abs(z - pz) < PEN_SIZE / 2 for px, pz in PENS)
        inside |= any(abs(x - tx) < TRAIN_SIZE / 2 and abs(z - tz) < TRAIN_SIZE / 2 for _, tx, tz in TRAINING)
        edge = abs(x) > HALF - 4 or z > SOUTH - 4 or (z < NORTH + 4 and abs(x) >= GATE_HALF)
        rows[r][c] = dirt if d and not inside and not edge else grass
    m["rows"] = ["".join(r) for r in rows]
    for a in m["areas"]:
        if a.get("name") == "Base":
            a["spawn"] = list(SPAWN)
            a["pens"] = [list(p) for p in PENS]
            a["penSize"] = PEN_SIZE
            a["training"] = [list(t) for t in TRAINING]
            a["trainSize"] = TRAIN_SIZE
    # props left on the old south wall or past the new one
    gone = [o for o in m["objects"] if "x" in o and abs(o["x"]) < HALF + WALL and SOUTH + WALL <= o["z"] < OLD_SOUTH + WALL]
    m["objects"] = [o for o in m["objects"] if o not in gone]
    open(WORLD, "w").write(dump(m))
    print("base laid:", len(PENS), "pens,", len(TRAINING), "training grounds; removed", len(gone), "objects off the old south wall")


if __name__ == "__main__":
    main()
