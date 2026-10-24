"""The whole map (QM, Oct 24): the base and the first four biome arenas, laid out here and
built in game by Server/Map.luau from the data this writes (src/shared/MapData.luau).

Run: python3 tools/map_gen.py [preview_dir]
     writes src/shared/MapData.luau and previews/map_*.png (and copies to preview_dir).

Layout (studs, y up, north is -z):
- The base (QM, Oct 24: compact and square, like LassoAPet's spawn): grass with a ragged
  dirt yard (a stud lower) round the spawn. Three pens down each side, the training
  grounds along the south wall, and the gateway out in the north wall, straight into the
  Meadow (its south wall is the base's north wall).
- The biomes, in a line north: Meadow, Desert, Ice, Lava. Each is a roughly square arena,
  wider than deep, bigger the further you go, the boss's circle (plain ground) in the
  middle and egg nests in the corners and along the sides. Walls (raised plateaus) run
  down their sides only: one biome opens straight onto the next, a big stone pillar
  either side where the side walls step out (QM, Oct 24). The Meadow's south wall has a
  gateway from the base: two big pillars and an arch, in LassoAPet's portal style.
- Floors (QM, Oct 24: simple): at most three tiles a biome, a stud apart, and maybe a
  liquid (water, magma) that sinks and slows you.
- Floors, as LassoAPet's World 3 (tools/world3_course.py there): a quasicrystal cut into
  bands (tools/quasicrystal.py), on 8-stud cells, kept to QM's layered rule (tiles only
  ever touch tiles one step either side of them, diagonals too: check() asserts it).
  Here the quasicrystal is centred on the boss, so its rosettes ring the arena, and the
  floor rises a little toward the walls (a bowl round the fight).

Colours live in Config.WorldColors (by ColorKey, tunable in Play); this reads them from
there for the previews, so Config stays the one place they're set.
"""

import math
import os
import re
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, HERE)
from quasicrystal import value  # noqa: E402

CELL = 8

# ---- the layout ------------------------------------------------------------------------

BASE_HALF = 176  # the base's inside: x -176..176 (LassoAPet's base width)
BASE_N, BASE_S = -152, 152  # its north edge (the Meadow's south wall) and south edge
GATE_HALF = 24  # every gateway's opening: 48 wide
DIV_T = 24  # the Meadow's south wall (the base's north wall, the gateway in it) is this thick
OUT_T = 48  # outer walls: a wide plateau
WALL_H = 30  # walls stand this high above the floor (their cap the last stud; QM: 3x, like LassoAPet)

# QM, Oct 24: 6 players a server, so two rows of 3 pens either side of the spawn, LassoAPet's
# pen size (14 tiles of 4 studs); the training grounds lined up at the south "head of the
# table" (one per biome, each about a pen's size, plus the free dummies), the way out to
# the biomes at the north head.
PENS = [(sx * 132, z) for sx in (-1, 1) for z in (-100, -28, 44)]  # pen centres
PEN_SIZE = 56
TRAINING = [("Dummies", -112), ("Meadow", -56), ("Desert", 0), ("Ice", 56), ("Lava", 112)]  # (name, centre x)
TRAIN_Z = 112  # their centres' z
TRAIN_SIZE = 48
SPAWN = (0, -28)  # in the dirt yard, level with the middle pens
YARD = (80, 92)  # the dirt yard's half width and half depth round the spawn (before its ragged edge)
TRAIN_PATH = (72, 88)  # the dirt path along the training grounds' gates (z from, to)

# Each biome (QM, Oct 24: simple floors, at most three tiles and maybe a liquid): its
# interior width (x) and depth (z), its tiles (suffix, ladder step, liquid?) from low to
# high (heights are step - 1: -1, 0, +1), the quasicrystal (angles, scale) and its cuts
# into bands (one per step, rising), the floor rising toward the walls, the boss's circle
# (plain ground: its `centre` tile), its egg nests. `ground` is the everyday tile: the
# circle, the nests and the seams between biomes are flat ground.
# A liquid sinks you a little and slows you (client/Liquid.luau).
# (QM, Oct 24: each 1.6x smaller than first laid out: 352 x 288 .. 512 x 384)
BIOMES = [
    dict(name="Meadow", W=224, D=176, tiles=[("Water", 0, True), ("Grass", 1, False), ("Dirt", 1, False)],
         ground=1, centre=2, angles=5, scale=7, cuts=(0.07,), bowl=0.0, dais=32, nests=4),
    dict(name="Desert", W=248, D=200, tiles=[("DryGrass", 0, False), ("Sand", 1, False), ("Sandstone", 2, False)],
         ground=1, centre=1, angles=7, scale=8, cuts=(0.18, 0.76), bowl=0.2, dais=36, nests=6),
    dict(name="Ice", W=280, D=224, tiles=[("ColdGrass", 0, False), ("Snow", 1, False), ("Glacier", 2, False)],
         ground=1, centre=1, angles=8, scale=9, cuts=(0.2, 0.8), bowl=0.18, dais=40, nests=6),
    dict(name="Lava", W=320, D=240, tiles=[("Magma", 0, True), ("Rock", 1, False), ("Basalt", 2, False)],
         ground=1, centre=1, angles=9, scale=9, cuts=(0.12, 0.74), bowl=-0.16, dais=44, nests=8),
]
NEST_CLEAR = 16  # flat ground round a nest
GATE_CLEAR = 24  # flat ground inside the Meadow's gateway
SEAM = 16  # flat ground either side of the line where two biomes meet

# the base's tiles: (key, top): the lineup's grass, its dirt a stud lower (QM, Oct 24)
BASE_TILES = [("Grass", 0), ("Dirt", -1)]

# where each biome sits: its south (near) interior edge, north (far) edge. Only the Meadow
# has a south wall (shared with the base, the gateway in it); the rest open straight onto
# the biome before (QM, Oct 24: no walls between biomes), each a little wider.
z = BASE_N - DIV_T
for b in BIOMES:
    b["zs"] = z
    b["zn"] = z - b["D"]
    b["cz"] = (b["zs"] + b["zn"]) / 2
    b["steps"] = [t[1] for t in b["tiles"]]
    z = b["zn"]
assert all(a["W"] <= c["W"] <= a["W"] + 2 * OUT_T for a, c in zip(BIOMES, BIOMES[1:]))


# ---- the layered rule (LassoAPet tools/world3_course.py) -----------------------------

def neighbours(a, fill):
    """The 8 neighbours of every cell (padded with fill)."""
    p = np.pad(a, 1, constant_values=fill)
    nx, nz = a.shape
    return [p[1 + dx:1 + dx + nx, 1 + dz:1 + dz + nz] for dx in (-1, 0, 1) for dz in (-1, 0, 1) if dx or dz]


def lower(step, inside):
    """From below: a cell is at most a step above every neighbour (the rim round a pit)."""
    big = 999
    r = np.where(inside, step, big)
    while True:
        m = np.min(neighbours(r, big), axis=0) + 1
        new = np.where(inside, np.minimum(r, m), big)
        if (new == r).all():
            return np.where(inside, new, 0)
        r = new


def raise_(step, inside, fixed):
    """From above, round stamped features: neighbours lift to at most a step below them
    (fixed cells keep theirs)."""
    r = np.where(inside, step, -999)
    while True:
        m = np.max(neighbours(r, -999), axis=0) - 1
        new = np.where(inside & ~fixed, np.maximum(r, m), r)
        if (new == r).all():
            return np.where(inside, new, 0)
        r = new


def tidy(t, inside, passes=2):
    """No lone tiles: a cell unlike 6 or more of its 8 neighbours takes their tile."""
    for _ in range(passes):
        nb = np.array(neighbours(t, -1))
        for k in np.unique(t):
            many = (nb == k).sum(axis=0) >= 6
            t = np.where(inside & many & (t != k), k, t)
    return t


def patches(t, inside):
    """Each joined patch (4-way) of one tile: (tile, cells, the tiles round it)."""
    nx, nz = t.shape
    seen = np.zeros_like(inside)
    for i in range(nx):
        for j in range(nz):
            if seen[i, j] or not inside[i, j]:
                continue
            k, cells, todo, rim = t[i, j], [], [(i, j)], []
            seen[i, j] = True
            while todo:
                a, c = todo.pop()
                cells.append((a, c))
                for da, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    a2, c2 = a + da, c + dc
                    if 0 <= a2 < nx and 0 <= c2 < nz and inside[a2, c2]:
                        if t[a2, c2] == k:
                            if not seen[a2, c2]:
                                seen[a2, c2] = True
                                todo.append((a2, c2))
                        else:
                            rim.append(int(t[a2, c2]))
            yield k, cells, rim


def blocks(t):
    """Every cell that is part of a 2x2 block of its own tile."""
    nx, nz = t.shape
    same = np.zeros((nx, nz), bool)
    same[:-1, :-1] = (t[:-1, :-1] == t[1:, :-1]) & (t[:-1, :-1] == t[:-1, 1:]) & (t[:-1, :-1] == t[1:, 1:])
    out = same.copy()
    out[1:, :] |= same[:-1, :]
    out[:, 1:] |= same[:, :-1]
    out[1:, 1:] |= same[:-1, :-1]
    return out


def blocky(t, inside):
    """No patch smaller than 2x2: a patch with no 2x2 block in it takes the tile most
    common round it."""
    t = t.copy()
    block = blocks(t)
    for k, cells, rim in list(patches(t, inside)):
        if rim and not any(block[a, c] for a, c in cells):
            vals, counts = np.unique(rim, return_counts=True)
            for a, c in cells:
                t[a, c] = vals[np.argmax(counts)]
    return t


def despeck(t, inside, least=0):
    """After the rims are drawn: a peak (or pit) with no 2x2 block in it (or under `least`
    cells), every neighbour one step from it, takes their tile. Keeps the layered rule."""
    while True:
        changed = False
        block = blocks(t)
        for k, cells, rim in list(patches(t, inside)):
            small = len(cells) < least or not any(block[a, c] for a, c in cells)
            if rim and len(set(rim)) == 1 and abs(rim[0] - k) == 1 and small:
                for a, c in cells:
                    t[a, c] = rim[0]
                changed = True
        if not changed:
            return t


def check(name, step, inside):
    """QM's layered rule: no two cells (diagonals too) more than a step apart."""
    big = 10 ** 6
    s = np.where(inside, step, big)
    for nb in neighbours(s, big):
        bad = (s != big) & (nb != big) & (np.abs(s - nb) > 1)
        assert not bad.any(), "%s: tiles two steps apart touch at %s" % (name, np.argwhere(bad)[:5].tolist())


def rects(kind, void=-1):
    """Greedy merge of same-kind cells into rectangles: (k, i0, j0, i1, j1), ends exclusive."""
    nx, nz = kind.shape
    done = np.zeros_like(kind, bool)
    out = []
    for i in range(nx):
        for j in range(nz):
            if done[i, j]:
                continue
            k = kind[i, j]
            j1 = j
            while j1 < nz and kind[i, j1] == k and not done[i, j1]:
                j1 += 1
            i1 = i + 1
            while i1 < nx and all(kind[i1, jj] == k and not done[i1, jj] for jj in range(j, j1)):
                i1 += 1
            done[i:i1, j:j1] = True
            if k != void:
                out.append((int(k), i, j, i1, j1))
    return out


# ---- a grid --------------------------------------------------------------------------

class Grid:
    """Cells over x0..x1, z1..z0 (z0 the south, larger, edge); cell (i, j) runs from
    x0 + 8i east and z0 - 8j north."""

    def __init__(self, x0, x1, z0, z1):
        self.x0, self.z0 = x0, z0
        self.nx, self.nz = (x1 - x0) // CELL, (z0 - z1) // CELL
        xs = x0 + CELL * np.arange(self.nx) + CELL / 2
        zs = z0 - CELL * np.arange(self.nz) - CELL / 2
        self.x, self.z = np.meshgrid(xs, zs, indexing="ij")
        self.inside = np.zeros((self.nx, self.nz), bool)
        self.tile = np.zeros((self.nx, self.nz), int)

    def floor(self):
        """(tile, x0, z0 (south edge), size x, size z) per merged part, at most 512 long."""
        key = np.where(self.inside, self.tile, -1)
        out = []
        rows = 512 // CELL
        for j0 in range(0, self.nz, rows):
            for k, i0, a, i1, c in rects(key[:, j0:j0 + rows]):
                out.append((k, self.x0 + i0 * CELL, self.z0 - (j0 + a) * CELL, (i1 - i0) * CELL, (c - a) * CELL))
        return out


# ---- the base --------------------------------------------------------------------------

def base():
    """Grass (0) and dirt (1, a stud lower), LassoAPet's base: a ragged dirt yard round the
    spawn, lanes from it to the gateway, each pen's gate and the training grounds, a few
    dirt patches in the grass. Pens and training grounds stand on grass; no dirt within a
    tile of a wall except the gateway's lane."""
    g = Grid(-BASE_HALF, BASE_HALF, BASE_S, BASE_N)
    g.inside[:] = True
    sx, sz = SPAWN
    # the yard: an oval with a ragged edge
    q = value(g.x, g.z, 7, 9)
    oval = ((g.x - sx) / YARD[0]) ** 2 + ((g.z - sz) / YARD[1]) ** 2
    dirt = oval + 1.1 * (q - 0.5) < 1
    # lanes: north to the gateway, south to the training path, along the training gates,
    # and out to each pen's gate
    dirt |= (np.abs(g.x) < GATE_HALF) & (g.z < sz)
    dirt |= (np.abs(g.x) < 16) & (g.z > sz) & (g.z < TRAIN_PATH[1])
    dirt |= (g.z >= TRAIN_PATH[0]) & (g.z < TRAIN_PATH[1]) & (np.abs(g.x) < TRAINING[-1][1] + TRAIN_SIZE / 2)
    for px, pz in PENS:
        inner = abs(px) - PEN_SIZE / 2
        dirt |= (np.abs(g.z - pz) < 12) & (np.abs(g.x) < inner) & (np.sign(g.x) == np.sign(px))
    # patches in the grass, a tile clear of the yard
    q2 = value(g.x + 37, g.z - 11, 5, 4)
    near_yard = oval < 1.45
    dirt |= (q2 > np.quantile(q2, 0.86)) & ~near_yard
    t = dirt.astype(int)
    t = blocky(tidy(t, g.inside), g.inside)
    # grass: under the pens and training grounds, and a tile out from the walls
    keep = (np.abs(g.x) > BASE_HALF - 8) | (g.z > BASE_S - 8) | ((g.z < BASE_N + 8) & (np.abs(g.x) >= GATE_HALF))
    for px, pz in PENS:
        keep |= (np.abs(g.x - px) < PEN_SIZE / 2) & (np.abs(g.z - pz) < PEN_SIZE / 2)
    for _, tx in TRAINING:
        keep |= (np.abs(g.x - tx) < TRAIN_SIZE / 2) & (np.abs(g.z - TRAIN_Z) < TRAIN_SIZE / 2)
    t[keep] = 0
    g.tile = blocky(t, g.inside)
    g.tile[keep] = 0
    for cx, cz, h in [(x, z, PEN_SIZE / 2) for x, z in PENS] + [(x, TRAIN_Z, TRAIN_SIZE / 2) for _, x in TRAINING]:
        assert abs(cx) + h <= BASE_HALF - 8 and BASE_N + 8 <= cz - h and cz + h <= BASE_S - 8, (cx, cz)
    check("Base", np.array([t_[1] for t_ in BASE_TILES])[g.tile], g.inside)
    return g


# ---- a biome ---------------------------------------------------------------------------

def nests(b):
    W, zs, zn, cz = b["W"], b["zs"], b["zn"], b["cz"]
    inset = 24
    out = [(sx * (W / 2 - inset), z) for z in (zs - inset, zn + inset) for sx in (-1, 1)]
    if b["nests"] >= 6:
        out += [(sx * (W / 2 - 20), cz) for sx in (-1, 1)]
    if b["nests"] >= 8:
        out += [(sx * W / 4, zn + 20) for sx in (-1, 1)]
    return out


def biome(b, index):
    W = b["W"]
    # (the Meadow's south gateway's floor too: the gap in its wall)
    g = Grid(-W // 2, W // 2, b["zs"] + (DIV_T if index == 0 else 0), b["zn"])
    dx, dz = g.x, g.z - b["cz"]
    r = np.hypot(dx, dz)
    room = g.z < b["zs"]
    g.inside = room | (np.abs(g.x) < GATE_HALF)
    # the quasicrystal, centred on the boss, cut into a band per step; the floor rising
    # (or falling) toward the walls
    edge = np.maximum(np.abs(dx) / (W / 2), np.abs(dz) / (b["D"] / 2))
    q = value(dx, dz, b["angles"], b["scale"]) + b["bowl"] * (edge - 0.5)
    qs = np.quantile(q[room], b["cuts"])
    step = np.searchsorted(qs, q).astype(int)
    step = blocky(tidy(step, g.inside), g.inside)
    step = despeck(lower(step, g.inside), g.inside)
    # flat ground (a step from anything, so nothing round it changes): the boss's
    # circle, round the nests, the gateway, the seams with the biomes either side
    centre = r < b["dais"]
    flat = centre | ~room
    if index == 0:
        flat |= np.hypot(g.x, g.z - b["zs"]) < GATE_CLEAR
    else:
        flat |= g.z > b["zs"] - SEAM
    if index < len(BIOMES) - 1:
        flat |= g.z < b["zn"] + SEAM
    for nx_, nz_ in nests(b):
        flat |= np.hypot(g.x - nx_, g.z - nz_) < NEST_CLEAR
    ground = b["steps"][b["ground"]]
    step[flat] = ground
    free = g.inside & ~flat
    step = np.where(free, despeck(step.copy(), free), step)
    # steps to tiles: each band's tile, the circle its own
    by_step = {}
    for k, s_ in enumerate(b["steps"]):
        by_step.setdefault(s_, k)
    by_step[ground] = b["ground"]
    g.tile = np.vectorize(by_step.get)(step)
    g.tile[centre] = b["centre"]
    check(b["name"], np.array(b["steps"])[g.tile], g.inside)
    return g


# ---- walls and pillars -------------------------------------------------------------------

def walls_and_pillars():
    """Walls: (key, x0, z0, x1, z1) axis-aligned boxes (z0 > z1); `ring` (rotated pieces:
    key, cx, cz, length, thick, yaw) is empty now the base is square. Pillars: (style, x, z,
    size, height, kind)."""
    walls, ring, pillars, arches, barriers = [], [], [], [], []
    # the base: walls west, east and south (its north wall is the Meadow's), a pillar at
    # each joint
    outer = BASE_HALF + OUT_T
    for sx in (-1, 1):
        x0, x1 = sorted((sx * BASE_HALF, sx * outer))
        walls.append(("Base", x0, BASE_S + OUT_T, x1, BASE_N))
        for k in (1, 2):
            pillars.append(("Base", sx * (BASE_HALF + 3), BASE_S - k * (BASE_S - BASE_N) / 3, 14, 36, "joint"))
    walls.append(("Base", -BASE_HALF, BASE_S + OUT_T, BASE_HALF, BASE_S))
    for k in (-1, 1):
        pillars.append(("Base", k * BASE_HALF / 2, BASE_S + 3, 14, 36, "joint"))
    for sx in (-1, 1):
        pillars.append(("Base", sx * BASE_HALF, BASE_S, 22, 40, "corner"))
    # the biomes
    for i, b in enumerate(BIOMES):
        name, half, zs, zn = b["name"], b["W"] / 2, b["zs"], b["zn"]
        if i == 0:
            # the Meadow's south wall, at the corridor's end: a gateway in it
            for sx in (-1, 1):
                # (right across the base too: it's the base's north wall)
                x0, x1 = sorted((sx * GATE_HALF, sx * max(half + OUT_T, BASE_HALF + OUT_T)))
                walls.append((name, x0, zs + DIV_T, x1, zs))
                pillars.append((name, sx * (GATE_HALF + 12), zs + DIV_T / 2, 24, 36, "gate"))
                pillars.append((name, sx * half, zs, 22, 40, "corner"))
                pillars.append(("Base", sx * BASE_HALF, zs + DIV_T, 22, 40, "corner"))
            arches.append((name, 0, zs + DIV_T / 2))
            barriers.append(("Base", name, 0, zs + DIV_T / 2, 2 * GATE_HALF))
        else:
            # open onto the biome before: a big pillar either side, set into the side
            # walls where they step out, and (for the fight) a barrier right across
            prev = BIOMES[i - 1]
            narrow = prev["W"] / 2
            for sx in (-1, 1):
                if half > narrow:
                    # (behind the step: the wider wall's corner, filled in)
                    x0, x1 = sorted((sx * (narrow + OUT_T), sx * (half + OUT_T)))
                    walls.append((prev["name"], x0, zs + OUT_T, x1, zs))
                pillars.append((name, sx * (narrow + 4), zs, 26, 44, "transition"))
            barriers.append((prev["name"], name, 0, zs, 2 * narrow))
        # its side walls, in pieces with a pillar at each joint
        n = max(1, round(b["D"] / 80))
        for sx in (-1, 1):
            x0, x1 = sorted((sx * half, sx * (half + OUT_T)))
            walls.append((name, x0, zs, x1, zn))
            for k in range(1, n):
                pillars.append((name, sx * (half + 3), zs - k * b["D"] / n, 14, 36, "joint"))
        if i == len(BIOMES) - 1:
            # the far wall: a gateway for the next world, sealed with rubble for now
            for sx in (-1, 1):
                x0, x1 = sorted((sx * GATE_HALF, sx * (half + OUT_T)))
                walls.append((name, x0, zn, x1, zn - OUT_T))
                pillars.append((name, sx * (GATE_HALF + 12), zn - DIV_T / 2, 24, 36, "gate"))
                pillars.append((name, sx * half, zn, 22, 40, "corner"))
            walls.append((name, -GATE_HALF, zn - 4, GATE_HALF, zn - OUT_T))
            arches.append((name, 0, zn - DIV_T / 2))
            pillars.append((name, 0, zn - 6, 20, 12, "rubble"))
    return walls, ring, pillars, arches, barriers


# ---- props -------------------------------------------------------------------------------

# Each biome's dressing (QM, Oct 24: ruined stone castle and runic vibes; pines in the
# Meadow, big cacti in the Desert, snowy pines on the Ice, dead trees and runic monoliths
# in the Lava): (item, weight) for the plateau tops round it and for the arena floor.
DRESSING = {
    "Meadow": dict(top=[("PineTall", 5), ("PineShort", 3), ("Boulders", 1), ("RuinPillarBroken", 1)],
                   floor=[("Boulders", 2), ("RuinPillarBroken", 2), ("PineShort", 1)], n=4, ring="RuinPillar"),
    "Desert": dict(top=[("Cactus", 4), ("CactusBarrel", 3), ("Boulders", 2), ("RuinPillarBroken", 1)],
                   floor=[("Cactus", 3), ("CactusBarrel", 2), ("Boulders", 1), ("RuinPillarBroken", 1)], n=5, ring="RuinPillar"),
    "Ice": dict(top=[("SnowPine", 6), ("Boulders", 2), ("RuinPillarBroken", 1)],
                floor=[("SnowPine", 3), ("Boulders", 2), ("RuinPillarBroken", 1)], n=5, ring="RuinPillar"),
    "Lava": dict(top=[("DeadTree", 4), ("Monolith", 2), ("Boulders", 2), ("RuinPillarBroken", 1)],
                 floor=[("DeadTree", 3), ("Monolith", 2), ("Boulders", 2)], n=6, ring="Monolith"),
}
SCALE = {"PineTall": (1.1, 1.7), "PineShort": (1.1, 1.6), "SnowPine": (1.0, 1.5), "Cactus": (0.9, 1.3),
         "CactusBarrel": (1.0, 1.6), "DeadTree": (0.9, 1.3), "Monolith": (0.9, 1.25), "Boulders": (0.8, 1.6),
         "RuinPillarBroken": (1.0, 1.3), "RuinPillar": (1.0, 1.0)}


def pick(rng, table):
    items, w = zip(*table)
    w = np.array(w, float)
    return items[rng.choice(len(items), p=w / w.sum())]


def props(grids):
    """Props on the base's wall, round each biome's plateaus and on its floor, and the
    ruined walls in its corners: (item, x, z, ground y, yaw, scale, style)."""
    rng = np.random.default_rng(24)
    out, ruins = [], []
    # pines along the base's walls (west, east, south) and its north wall either side of
    # the Meadow
    spots = []
    for sx in (-1, 1):
        spots += [(sx * (BASE_HALF + 12 + rng.uniform(0, OUT_T - 22)), z) for z in np.arange(BASE_N + 4, BASE_S + OUT_T - 8, 24)]
        spots += [(sx * x, BASE_N - rng.uniform(6, DIV_T - 6)) for x in np.arange(BIOMES[0]["W"] / 2 + OUT_T + 14, BASE_HALF + 8, 24)]
    spots += [(x, BASE_S + 12 + rng.uniform(0, OUT_T - 22)) for x in np.arange(-BASE_HALF + 12, BASE_HALF - 8, 24)]
    for k, (x, z) in enumerate(spots):
        out.append(("PineTall" if k % 3 else "PineShort", x, z, WALL_H, rng.uniform(0, 360), rng.uniform(1.1, 1.7), "Base"))
    for b, g in zip(BIOMES, grids):
        name, half = b["name"], b["W"] / 2
        dress = DRESSING[name]
        # the plateau tops beside it
        for sx in (-1, 1):
            z = b["zs"] - 12
            while z > b["zn"] + 12:
                x = sx * (half + 12 + rng.uniform(0, OUT_T - 22))
                it = pick(rng, dress["top"])
                out.append((it, x, z, WALL_H, rng.uniform(0, 360), rng.uniform(*SCALE[it]), name))
                z -= rng.uniform(18, 32)
        steps = np.array(b["steps"])[g.tile]

        def ground_y(x, z):
            i = min(g.nx - 1, max(0, int((x - g.x0) // CELL)))
            j = min(g.nz - 1, max(0, int((g.z0 - z) // CELL)))
            return int(steps[i, j]) - 1

        # just outside the boss's circle: standing ruins (or monoliths), cover to kite it round
        r = b["dais"] + 8
        for k in range(6):
            a = (k + 0.5) / 6 * 2 * math.pi
            it = dress["ring"] if k % 2 == 0 or name == "Lava" else "RuinPillarBroken"
            yaw = math.degrees(-a) + 90 if it == "Monolith" else rng.uniform(0, 360)
            x, z = math.cos(a) * r, b["cz"] + math.sin(a) * r
            out.append((it, x, z, ground_y(x, z), yaw, 1.0, name))
        # the floor: on its highest ground (never in a liquid), clear of the circle, nests,
        # gateways and walls
        high = max(s_ for s_, (_, _, wet) in zip(b["steps"], b["tiles"]) if not wet)
        dry = np.array([not t[2] for t in b["tiles"]])[g.tile]
        spots = [(i, j) for i in range(g.nx) for j in range(g.nz)
                 if g.inside[i, j] and steps[i, j] == high and dry[i, j] and g.tile[i, j] != b["centre"]]
        rng.shuffle(spots)
        taken = [(x, z, 18) for x, z in nests(b)] + [(0, b["zs"], 36), (0, b["zn"], 36)]
        placed = 0
        for i, j in spots:
            x, z = float(g.x[i, j]), float(g.z[i, j])
            if math.hypot(x, z - b["cz"]) < b["dais"] + 20:
                continue
            if abs(x) > half - 14 or z > b["zs"] - 14 or z < b["zn"] + 14:
                continue
            if any(math.hypot(x - tx, z - tz) < tr for tx, tz, tr in taken):
                continue
            it = pick(rng, dress["floor"])
            out.append((it, x, z, high - 1, rng.uniform(0, 360), rng.uniform(*SCALE[it]), name))
            taken.append((x, z, 28))
            placed += 1
            if placed >= dress["n"]:
                break
        # ruined brick walls: an L in each corner's diagonal, between the nests and the dais
        for sx in (-1, 1):
            for sz in (-1, 1):
                cx = sx * half * 0.52
                cz = b["cz"] + sz * b["D"] / 2 * 0.5
                yaw = math.degrees(math.atan2(sx, sz))  # (facing the dais)
                ruins.append((name, round(cx, 1), round(cz, 1), round(rng.uniform(14, 20), 1), round(yaw + 90, 1), round(rng.uniform(6, 9), 1), int(rng.integers(1, 10 ** 6))))
    return [(i, round(x, 2), round(z, 2), t, round(y, 1), round(s, 2), st) for i, x, z, t, y, s, st in out], ruins


def mesh_centres():
    """Each world mesh piece's bounding-box centre (studs, from its origin), so the
    builder can place them however Roblox centres an imported mesh."""
    out = {}
    d = os.path.join(ROOT, "assets", "meshes")
    for f in sorted(os.listdir(d)):
        if f.endswith(".obj"):
            v = np.array([list(map(float, l.split()[1:4])) for l in open(os.path.join(d, f)) if l.startswith("v ")])
            out[f[:-4]] = (v.min(0) + v.max(0)) / 2, v.max(0) - v.min(0)
    return out


# ---- colours (from Config, for the previews) -------------------------------------------------

def config_colours():
    src = open(os.path.join(ROOT, "src", "shared", "Config.luau")).read()
    block = src[src.index("WorldColors = {"):]
    block = block[:block.index("\n\t},")]
    return {k: (int(r), int(g_), int(b)) for k, r, g_, b in re.findall(r"(\w+) = Color3\.fromRGB\((\d+), (\d+), (\d+)\)", block)}


# ---- output ------------------------------------------------------------------------------

def lua_num(v):
    v = float(v)
    return str(int(v)) if v == int(v) else ("%.3f" % v).rstrip("0").rstrip(".")


def write(g_base, grids, walls, ring, pillars, arches, barriers, prop_list, ruins):
    L = []
    w = L.append
    w("-- GENERATED by tools/map_gen.py (QM, Oct 24): edit that and re-run it, not this.")
    w("-- The map's layout, built in game by Server/Map.luau. Studs; y up; north is -z.")
    w("-- Floor = { tile, x0, z0 (south edge), size x, size z }: the part runs from x0 east")
    w("-- and z0 north. Tiles = { ColorKey, top, liquid? }: Key .. \"Checker\" is its checker's colour.")
    w("return {")
    w("\tWallHeight = %d," % WALL_H)
    w("\tGateHalf = %d," % GATE_HALF)
    w("\tAreas = {")

    def area(name, tiles, g, extra):
        w("\t\t{")
        w('\t\t\tName = "%s",' % name)
        for line in extra:
            w("\t\t\t" + line)
        w("\t\t\tTiles = { %s }," % ", ".join(
            '{ "%s", %d%s }' % (t[0], t[1], ", true" if len(t) > 2 and t[2] else "") for t in tiles))
        w("\t\t\tFloor = {")
        for p in g.floor():
            w("\t\t\t\t{ %d, %s, %s, %s, %s }," % (p[0] + 1, *(lua_num(v) for v in p[1:])))
        w("\t\t\t},")
        w("\t\t},")

    area("Base", BASE_TILES, g_base, [
        "Spawn = { %s, %s }," % SPAWN,
        "Pens = { %s }," % ", ".join("{ %s, %s }" % (lua_num(x), lua_num(z)) for x, z in PENS),
        "PenSize = %d," % PEN_SIZE,
        "Training = { %s }," % ", ".join('{ "%s", %s, %s }' % (n, x, TRAIN_Z) for n, x in TRAINING),
        "TrainSize = %d," % TRAIN_SIZE,
    ])
    for b, g in zip(BIOMES, grids):
        area(b["name"], [(b["name"] + s, st - 1, wet) for s, st, wet in b["tiles"]], g, [
            "Boss = { 0, %s }," % lua_num(b["cz"]),
            "DaisRadius = %d," % b["dais"],
            "Nests = { %s }," % ", ".join("{ %s, %s }" % (lua_num(x), lua_num(z)) for x, z in nests(b)),
            "Bounds = { %s, %s, %s, %s }," % (lua_num(-b["W"] / 2), lua_num(b["zs"]), lua_num(b["W"] / 2), lua_num(b["zn"])),
        ])
    w("\t},")
    w("\t-- { style, x0, z0, x1, z1 }: from the floor's bottom to WallHeight, capped")
    w("\tWalls = {")
    for p in walls:
        w('\t\t{ "%s", %s },' % (p[0], ", ".join(lua_num(v) for v in p[1:])))
    w("\t},")
    w("\t-- the base's ring wall: { style, centre x, z, length, thickness, yaw (radians) }")
    w("\tRing = {")
    for p in ring:
        w('\t\t{ "%s", %s },' % (p[0], ", ".join(lua_num(v) for v in p[1:])))
    w("\t},")
    w("\t-- { style, x, z, footprint, height, kind (gate, corner, joint, rubble) }")
    w("\tPillars = {")
    for p in pillars:
        w('\t\t{ "%s", %s, %s, %s, %s, "%s" },' % (p[0], *(lua_num(v) for v in p[1:5]), p[5]))
    w("\t},")
    w("\t-- an arch over each gateway, between its pillars: { style, x, z }")
    w("\tArches = { %s }," % ", ".join('{ "%s", %s, %s }' % (a[0], lua_num(a[1]), lua_num(a[2])) for a in arches))
    w("\t-- the barriers between areas (for those in a fight): { south area, north area, x, z, width }")
    w("\tBarriers = { %s }," % ", ".join('{ "%s", "%s", %s }' % (a[0], a[1], ", ".join(lua_num(v) for v in a[2:])) for a in barriers))
    w("\t-- { item, x, z, ground y, yaw (degrees), scale, style }: ServerStorage.WorldAssets meshes")
    w("\tProps = {")
    for p in prop_list:
        w('\t\t{ "%s", %s, "%s" },' % (p[0], ", ".join(lua_num(v) for v in p[1:6]), p[6]))
    w("\t},")
    w("\t-- ruined brick walls: { style, centre x, z, length, yaw (degrees), height, seed }")
    w("\tRuins = {")
    for r in ruins:
        w('\t\t{ "%s", %s },' % (r[0], ", ".join(lua_num(v) for v in r[1:])))
    w("\t},")
    w("\t-- each mesh piece's bounding-box centre from its origin (assets/meshes/*.obj)")
    w("\tMeshCentres = {")
    for k, (c, s) in mesh_centres().items():
        w("\t\t%s = Vector3.new(%s, %s, %s)," % (k, *(lua_num(round(v, 3)) for v in c)))
    w("\t},")
    w("}")
    path = os.path.join(ROOT, "src", "shared", "MapData.luau")
    open(path, "w").write("\n".join(L) + "\n")
    return path


# ---- previews ----------------------------------------------------------------------------

def preview(g_base, grids, walls, ring, pillars, arches, prop_list, ruins, colours, s=1.0, crop=None):
    xs = [-(b["W"] / 2 + OUT_T) for b in BIOMES] + [-BASE_HALF - OUT_T]
    X0, X1 = min(xs) - 8, -min(xs) + 8
    Z0, Z1 = BASE_S + OUT_T + 8, BIOMES[-1]["zn"] - OUT_T - 8
    if crop:
        Z0, Z1 = crop
    W, H = int((X1 - X0) * s), int((Z0 - Z1) * s)
    im = Image.new("RGB", (W, H), (30, 34, 44))
    d = ImageDraw.Draw(im)

    def P(x, z):
        return ((x - X0) * s, (Z0 - z) * s)

    def shade(c, f):
        return tuple(max(0, min(255, int(v * f))) for v in c)

    def tiles_of(name, g, tiles):
        for i in range(g.nx):
            for j in range(g.nz):
                if not g.inside[i, j]:
                    continue
                key, top = tiles[g.tile[i, j]]
                x, z = g.x0 + i * CELL, g.z0 - j * CELL
                for a in range(2):
                    for c in range(2):
                        col = colours[key] if (a + c) % 2 == 0 else colours[key + "Checker"]
                        x0, y0 = P(x + a * 4, z - c * 4)
                        d.rectangle([x0, y0 - 4 * s, x0 + 4 * s - 1, y0 - 1], fill=col)
                # a dark line on the low side of every step: shows the heights
                for di, dj in ((1, 0), (0, 1), (-1, 0), (0, -1)):
                    i2, j2 = i + di, j + dj
                    if 0 <= i2 < g.nx and 0 <= j2 < g.nz and g.inside[i2, j2] and tiles[g.tile[i2, j2]][1] < top:
                        x0, y0 = P(x, z)
                        if di == 1:
                            d.line([(x0 + CELL * s, y0 - CELL * s), (x0 + CELL * s, y0)], fill=(40, 34, 30), width=max(1, int(s)))
                        elif di == -1:
                            d.line([(x0, y0 - CELL * s), (x0, y0)], fill=(40, 34, 30), width=max(1, int(s)))
                        elif dj == 1:
                            d.line([(x0, y0 - CELL * s), (x0 + CELL * s, y0 - CELL * s)], fill=(40, 34, 30), width=max(1, int(s)))
                        else:
                            d.line([(x0, y0), (x0 + CELL * s, y0)], fill=(40, 34, 30), width=max(1, int(s)))

    tiles_of("Base", g_base, BASE_TILES)
    for b, g in zip(BIOMES, grids):
        tiles_of(b["name"], g, [(b["name"] + t[0], t[1] - 1) for t in b["tiles"]])
    wall_key = {"Base": "WallDirt"}
    cap_key = {"Base": "Grass"}
    for b in BIOMES:
        wall_key[b["name"]] = b["name"] + "Wall"
        cap_key[b["name"]] = b["name"] + "Cap"
    for st, cx, cz, length, thick, yaw in ring:
        c, sn = math.cos(yaw), math.sin(yaw)
        pts = []
        for u, v in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            lx, lz = u * length / 2, v * thick / 2
            pts.append(P(cx + lx * c + lz * sn, cz - lx * sn + lz * c))
        d.polygon(pts, fill=colours[cap_key[st]], outline=shade(colours[cap_key[st]], 0.75))
    for st, x0, z0, x1, z1 in walls:
        a, b_ = P(x0, z0), P(x1, z1)
        d.rectangle([min(a[0], b_[0]), min(a[1], b_[1]), max(a[0], b_[0]), max(a[1], b_[1])], fill=colours[cap_key[st]], outline=shade(colours[cap_key[st]], 0.75))
    look = {"PineTall": ("PineNeedlesB", 5), "PineShort": ("PineNeedlesB", 4), "SnowPine": ("SnowPineNeedles", 5),
            "Cactus": ("CactusGreen", 2.5), "CactusBarrel": ("CactusGreen", 2.5), "DeadTree": ("DeadWood", 3),
            "Monolith": ("LavaPillarDark", 3.5), "Boulders": ("StoneDark", 4), "RuinPillar": ("Stone", 3.4),
            "RuinPillarBroken": ("Stone", 3.4)}
    for it, x, z, top, yaw, sc, st in prop_list:
        key, r = look[it]
        r *= sc
        cx, cy = P(x, z)
        d.ellipse([cx - r * s, cy - r * s, cx + r * s, cy + r * s], fill=colours[key], outline=shade(colours[key], 0.6))
    for st, x, z, length, yaw, h, seed in ruins:
        a = math.radians(yaw)
        dx, dz = math.sin(a) * length / 2, math.cos(a) * length / 2
        d.line([P(x - dx, z - dz), P(x + dx, z + dz)], fill=colours[st + "PillarDark"], width=max(2, int(4 * s)))
    for st, x, z, size, h, kind in pillars:
        key = "Stone" if st == "Base" else st + "Pillar"
        a, b_ = P(x - size / 2, z + size / 2), P(x + size / 2, z - size / 2)
        d.rectangle([a[0], a[1], b_[0], b_[1]], fill=colours[key], outline=shade(colours[key], 0.55), width=max(1, int(2 * s)))
    for st, x, z in arches:
        key = "Stone" if st == "Base" else st + "Pillar"
        a, b_ = P(-GATE_HALF, z + 6), P(GATE_HALF, z - 6)
        d.rectangle([a[0], a[1], b_[0], b_[1]], outline=shade(colours[key], 0.7), width=max(1, int(2 * s)))
    # markers: nests, bosses, pens, training, spawn
    for b in BIOMES:
        for x, z in nests(b):
            cx, cy = P(x, z)
            d.ellipse([cx - 7 * s, cy - 7 * s, cx + 7 * s, cy + 7 * s], outline=colours["StrawDark"], width=max(1, int(2 * s)))
            d.ellipse([cx - 2.5 * s, cy - 3.2 * s, cx + 2.5 * s, cy + 3.2 * s], fill=colours["Egg"])
        cx, cy = P(0, b["cz"])
        d.ellipse([cx - 6 * s, cy - 6 * s, cx + 6 * s, cy + 6 * s], fill=(220, 40, 40))
        d.text(P(-b["W"] / 2 + 8, b["zs"] - 4), "%s %dx%d" % (b["name"], b["W"], b["D"]), fill=(0, 0, 0))
    for px, pz in PENS:
        a, b_ = P(px - PEN_SIZE / 2, pz + PEN_SIZE / 2), P(px + PEN_SIZE / 2, pz - PEN_SIZE / 2)
        d.rectangle([a[0], a[1], b_[0], b_[1]], outline=colours["WoodDark"], width=max(1, int(2 * s)))
    for name, tx in TRAINING:
        a, b_ = P(tx - TRAIN_SIZE / 2, TRAIN_Z + TRAIN_SIZE / 2), P(tx + TRAIN_SIZE / 2, TRAIN_Z - TRAIN_SIZE / 2)
        d.rectangle([a[0], a[1], b_[0], b_[1]], outline=colours["WoodDark"], width=max(1, int(2 * s)))
        d.text(P(tx - 20, TRAIN_Z), name, fill=(0, 0, 0))
    cx, cy = P(*SPAWN)
    d.ellipse([cx - 5 * s, cy - 5 * s, cx + 5 * s, cy + 5 * s], fill=(40, 120, 255))
    return im


def main():
    out_dirs = [os.path.join(ROOT, "previews")] + sys.argv[1:]
    g_base = base()
    grids = [biome(b, i) for i, b in enumerate(BIOMES)]
    walls, ring, pillars, arches, barriers = walls_and_pillars()
    prop_list, ruins = props(grids)
    path = write(g_base, grids, walls, ring, pillars, arches, barriers, prop_list, ruins)
    n = len(g_base.floor()) + sum(len(g.floor()) for g in grids)
    print("wrote", os.path.relpath(path, ROOT), "-", n, "floor parts,", len(walls) + len(ring), "walls,", len(pillars), "pillars,", len(prop_list), "props")
    for b, g in zip(BIOMES, grids):
        counts = {t[0]: int(((g.tile == k) & g.inside).sum()) for k, t in enumerate(b["tiles"])}
        print(" ", b["name"], "z", b["zs"], "to", b["zn"], "parts", len(g.floor()), counts)
    colours = config_colours()
    whole = preview(g_base, grids, walls, ring, pillars, arches, prop_list, ruins, colours, s=0.5)
    near = preview(g_base, grids, walls, ring, pillars, arches, prop_list, ruins, colours, s=2.0,
                   crop=(BASE_S + OUT_T + 8, BIOMES[0]["zn"] - 8))
    for od in out_dirs:
        os.makedirs(od, exist_ok=True)
        whole.save(os.path.join(od, "map_overview.png"))
        near.save(os.path.join(od, "map_base_meadow.png"))
    for i, b in enumerate(BIOMES):
        im = preview(g_base, grids[:], walls, ring, pillars, arches, prop_list, ruins, colours, s=1.5,
                     crop=(b["zs"] + DIV_T + 16, b["zn"] - 16))
        for od in out_dirs:
            im.save(os.path.join(od, "map_%d_%s.png" % (i + 1, b["name"].lower())))


if __name__ == "__main__":
    main()
