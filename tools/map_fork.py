"""The left fork past the Lava (QM, Oct 24): QM painted two corridors north out of the
Lava, off the top of the grid. This grows the grid and lays the left branch's floors and
walls: the Abandoned Dungeon (green tinged stone with patches of blue tinged slate), then,
through a corridor in its north wall, the Red Castle (dark purplish grey stone, a crimson
carpet runner up to a rug round the boss). The right branch's first biome is the Magic Forest
(turquoise grass, a blue stone plaza round the boss and a path in, blue stone walls), then
the Ocean Trench (pale blue sand, outcrops of darker blue stone, dark blue stone walls). Run once on maps/world.map; it refuses
a map already forked.

Run: python3 tools/map_fork.py && python3 tools/map_bake.py maps/world.map
"""

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from map_gen import dump_map  # noqa: E402
from map_grow import grow  # noqa: E402

PATH = os.path.join(HERE, "..", "maps", "world.map")
EDGE = 388  # the grid's half width (x), wall bands included
NORTH = -1704  # the grid's north edge
LAVA_NORTH = -1064  # where QM's corridors leave the old grid
DUNGEON = dict(x0=-340, x1=-20, south=-1096, north=-1336)
CASTLE = dict(x0=-340, x1=-20, south=-1368, north=-1656)
FOREST = dict(x0=20, x1=340, south=-1096, north=-1336)
OCEAN = dict(x0=20, x1=340, south=-1368, north=-1656)
CORRIDOR_O = (140, 220)  # (Forest -> Ocean)
CORRIDOR_1 = (-128, -48)  # (QM's left corridor, carried on north)
CORRIDOR_R = (52, 136)  # (QM's right corridor)
WAY = (82, 106)  # the Forest's stone path in
PLAZA = 64  # the stone plaza's radius, round the Forest's centre
CORRIDOR_2 = (-220, -140)  # (Dungeon -> Castle)
RUNNER = (-192, -168)  # the Castle's carpet runner
RUG = (-228, -132, -1548, -1476)  # x0, x1, north, south: round the boss

TILES = [
    {"id": "t", "area": "Dungeon", "key": "DungeonStone", "top": 0},
    {"id": "u", "area": "Dungeon", "key": "DungeonSlate", "top": 0},
    {"id": "v", "area": "Dungeon", "key": "DungeonWall", "cap": "DungeonCap", "top": 30, "wall": True},
    {"id": "w", "area": "Castle", "key": "CastleFloor", "top": 0},
    {"id": "x", "area": "Castle", "key": "CastleCarpet", "top": 0.5},
    {"id": "y", "area": "Castle", "key": "CastleWall", "cap": "CastleCap", "top": 30, "wall": True},
    {"id": "z", "area": "Forest", "key": "ForestGrass", "top": 0.5},
    {"id": "A", "area": "Forest", "key": "ForestStone", "top": 0},
    {"id": "B", "area": "Forest", "key": "ForestWall", "cap": "ForestCap", "top": 30, "wall": True},
    {"id": "C", "area": "Ocean", "key": "OceanSand", "top": 0},
    {"id": "D", "area": "Ocean", "key": "OceanStone", "top": 0.5},
    {"id": "E", "area": "Ocean", "key": "OceanWall", "cap": "OceanCap", "top": 30, "wall": True},
]


def slate(x, z):
    """Patches of slate through the Dungeon's stone: a few crossed waves."""
    v = (math.sin(x * 0.045 + 1.3) + math.sin(z * 0.05 + 0.4) + math.sin((x + z) * 0.031 + 2.1)
         + 0.6 * math.sin((x - z) * 0.09 + 0.7))
    return v > 1.15


def outcrop(x, z):
    """The Ocean's stone outcrops: other waves than the Dungeon's slate."""
    v = (math.sin(x * 0.06 + 0.2) + math.sin(z * 0.055 + 2.6) + math.sin((x - z) * 0.035 + 1.0)
         + 0.7 * math.sin((x + z) * 0.11 + 0.3))
    return v > 1.5


def main():
    d = json.loads(open(PATH).read())
    if any(a["name"] == "Dungeon" for a in d["areas"]):
        sys.exit("already forked")
    used = {t["id"] for t in d["tiles"]}
    assert not used & {t["id"] for t in TILES}, "tile ids taken"
    cell = d["cell"]
    west = (d["origin"][0] + EDGE) // cell
    east = (EDGE - (d["origin"][0] + d["size"][0] * cell)) // cell
    north = (d["origin"][1] - NORTH) // cell
    grow(d, west, east, north, 0)
    X0, Z0 = d["origin"]
    rows = [list(r) for r in d["rows"]]

    def inside(x, z, b):
        return b["x0"] <= x < b["x1"] and b["north"] <= z < b["south"]

    for r in range(len(rows)):
        z = Z0 + r * cell + cell / 2
        if z > LAVA_NORTH:
            break
        for c in range(len(rows[r])):
            x = X0 + c * cell + cell / 2
            if inside(x, z, DUNGEON) or (CORRIDOR_1[0] <= x < CORRIDOR_1[1] and z >= DUNGEON["south"]):
                ch = "u" if slate(x, z) else "t"
            elif inside(x, z, CASTLE) or (CORRIDOR_2[0] <= x < CORRIDOR_2[1] and CASTLE["south"] <= z < DUNGEON["north"]):
                rug = RUG[0] <= x < RUG[1] and RUG[2] <= z < RUG[3]
                runner = RUNNER[0] <= x < RUNNER[1] and z >= RUG[2]
                ch = "x" if rug or runner else "w"
            elif inside(x, z, FOREST) or (CORRIDOR_R[0] <= x < CORRIDOR_R[1] and z >= FOREST["south"]):
                cx, cz = (FOREST["x0"] + FOREST["x1"]) / 2, (FOREST["south"] + FOREST["north"]) / 2
                plaza = math.hypot(x - cx, z - cz) < PLAZA
                path = (WAY[0] <= x < WAY[1] and z >= cz) or z >= FOREST["south"]  # (stone in the corridor: grass is a stud above the Lava's magma)
                ch = "A" if plaza or path else "z"
            elif inside(x, z, OCEAN) or (CORRIDOR_O[0] <= x < CORRIDOR_O[1] and OCEAN["south"] <= z < FOREST["north"]):
                ch = "D" if outcrop(x, z) else "C"
            elif x >= 0:
                ch = "B" if z > (FOREST["north"] + OCEAN["south"]) / 2 else "E"
            else:
                ch = "v" if z > (DUNGEON["north"] + CASTLE["south"]) / 2 else "y"
            rows[r][c] = ch
    d["rows"] = ["".join(r) for r in rows]
    d["tiles"] += TILES
    d["areas"] += [
        {"name": "Dungeon", "bounds": [DUNGEON["x0"], DUNGEON["south"], DUNGEON["x1"], DUNGEON["north"]], "daisRadius": 44},
        {"name": "Castle", "bounds": [CASTLE["x0"], CASTLE["south"], CASTLE["x1"], CASTLE["north"]], "daisRadius": 48},
        {"name": "Forest", "bounds": [FOREST["x0"], FOREST["south"], FOREST["x1"], FOREST["north"]], "daisRadius": 44},
        {"name": "Ocean", "bounds": [OCEAN["x0"], OCEAN["south"], OCEAN["x1"], OCEAN["north"]], "daisRadius": 48},
    ]
    open(PATH, "w").write(dump_map(d))
    print("world.map: %d x %d cells, origin %s" % (*d["size"], d["origin"]))


if __name__ == "__main__":
    main()
