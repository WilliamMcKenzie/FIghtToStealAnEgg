"""The whole map (QM, Oct 24): the base and the first four biome arenas, laid out here and
built in game by Server/Map.luau from the data this writes (src/shared/MapData.luau).

Run: python3 tools/map_gen.py [preview_dir]
     writes src/shared/MapData.luau and previews/map_*.png (and copies to preview_dir).

Layout (studs, y up, north is -z):
- The base: a circle (BASE_R) round the spawn plaza. Three pens down each side, the two
  training grounds at the south end, and the gateway out at the north end, where a short
  corridor runs to the first biome.
- The biomes, in a line north: Meadow, Desert, Ice, Lava. Each is a roughly square arena,
  wider than deep, bigger the further you go. The boss's dais is in the middle (a flush
  floor ringed by a raised stone ring), egg nests sit in the corners and along the sides.
  A wall (a raised plateau, its cap the top) runs round each; a divider between two
  biomes has a gateway: two big stone pillars and an arch, in LassoAPet's portal style.
  Pillars also stand at every wall corner and joint, so walls of different widths meet.
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

BASE_R = 264  # the base's inner radius
RING_SEGMENTS = 40  # its wall, as straight pieces (two left out at the north: the gateway)
RING_T = 40  # the base wall's thickness (a plateau round the circle)
GATE_HALF = 24  # every gateway's opening: 48 wide
CORRIDOR_END = -BASE_R - 48  # the corridor from the base runs to the Meadow's south wall
DIV_T = 24  # a divider (the wall between two biomes) is this thick
OUT_T = 48  # outer walls: a wide plateau
WALL_H = 10  # walls stand this high above the floor (their cap the last stud)

# QM, Oct 24: 6 players a server, so two rows of 3 pens either side of the spawn, LassoAPet's
# pen size (14 tiles of 4 studs); the training grounds lined up at the south "head of the
# table" (one per biome, each about a pen's size, plus the free dummies), the way out to
# the biomes at the north head.
PENS = [(sx * 160, z) for sx in (-1, 1) for z in (-80, 0, 80)]  # pen centres
PEN_SIZE = 56
TRAINING = [("Dummies", -112), ("Meadow", -56), ("Desert", 0), ("Ice", 56), ("Lava", 112)]  # (name, centre x)
TRAIN_Z = 184  # their centres' z
TRAIN_SIZE = 48
TRAIN_FLOOR = {"Dummies": "TrainFloor", "Meadow": "MeadowGround", "Desert": "DesertGround", "Ice": "IceGround", "Lava": "LavaGround"}
PLAZA_R = 40
PATH_RING = (112, 128)  # the base's ring path (inner, outer radius)
TRAIN_PATH = (148, 160)  # the path along the training grounds' gates (z from, to)

# Each biome: interior width (x) and depth (z), its quasicrystal (angles, scale), the bands'
# cuts (rising: below the first is the low tile, above the last the high one), how much
# the floor rises toward the walls, the boss dais's radius, its egg nests.
BIOMES = [
    dict(name="Meadow", W=352, D=288, angles=5, scale=11, cuts=(0.18, 0.66), bowl=0.18, dais=48, nests=4),
    dict(name="Desert", W=400, D=320, angles=7, scale=13, cuts=(0.16, 0.62), bowl=0.2, dais=56, nests=6),
    dict(name="Ice", W=448, D=352, angles=8, scale=14, cuts=(0.22, 0.7), bowl=0.18, dais=64, nests=6),
    dict(name="Lava", W=512, D=384, angles=9, scale=15, cuts=(0.2, 0.64), bowl=-0.16, dais=72, nests=8),
]
RING_W = 16  # the raised ring round each dais
NEST_CLEAR = 24  # flat ground round a nest
NEST_PAD = 12  # its straw patch
GATE_CLEAR = 40  # flat ground inside each gateway

# biome tiles by index: (suffix, ladder step); heights are step - 1 (-1, 0, +1)
TILES = [("Low", 0), ("Ground", 1), ("High", 2), ("Arena", 1), ("Inlay", 1), ("Ring", 2), ("Nest", 1)]
LADDER = [t[1] for t in TILES]
FIXED_FROM = 3  # tiles from here on are stamped features (the terrain works round them)
# the base's tiles: (key, top)
BASE_TILES = [("Grass", 0), ("BaseGrassLight", 0), ("Dirt", 0), ("Plaza", 1), ("PlazaInlay", 1), ("PenFloor", 1)] + [
    (TRAIN_FLOOR[name], 1) for name, _ in TRAINING]

# where each biome sits: its south (near) interior edge, north (far) edge
z = CORRIDOR_END - DIV_T
for b in BIOMES:
    b["zs"] = z
    b["zn"] = z - b["D"]
    b["cz"] = (b["zs"] + b["zn"]) / 2
    z = b["zn"] - DIV_T


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
    g = Grid(-BASE_R - 8, BASE_R + 8, BASE_R + 8, CORRIDOR_END)
    r = np.hypot(g.x, g.z)
    corridor = (np.abs(g.x) < GATE_HALF) & (g.z < -BASE_R + 48)
    g.inside = (r < BASE_R + 10) | corridor
    # grass in two shades: a rosette round the spawn (8 angles)
    q = value(g.x, g.z, 8, 15)
    g.tile[:] = np.where(q > np.quantile(q[g.inside], 0.7), 1, 0)
    g.tile = blocky(tidy(g.tile, g.inside), g.inside)
    # paths (flush): north to the gateway, south between the training grounds, the ring
    # path past the pens and a spoke to each pen's gate
    path = (np.abs(g.x) < 12) & (g.z < TRAIN_PATH[1])
    path |= (g.z >= TRAIN_PATH[0]) & (g.z < TRAIN_PATH[1]) & (np.abs(g.x) < TRAINING[-1][1] + TRAIN_SIZE / 2)
    path |= (r >= PATH_RING[0]) & (r < PATH_RING[1])
    for px, pz in PENS:
        ring_x = math.sqrt(max(0, PATH_RING[0] ** 2 - pz ** 2))
        inner = abs(px) - PEN_SIZE / 2
        path |= (np.abs(g.z - pz) < 8) & (np.abs(g.x) >= ring_x) & (np.abs(g.x) < inner) & (np.sign(g.x) == np.sign(px))
    path |= corridor
    g.tile[path] = 2
    # the raised plaza round the spawn, a quasicrystal inlay in it
    plaza = r < PLAZA_R
    inlay = value(g.x, g.z, 5, 4) > 0.62
    g.tile[plaza] = np.where(inlay[plaza], 4, 3)
    for px, pz in PENS:
        g.tile[(np.abs(g.x - px) < PEN_SIZE / 2) & (np.abs(g.z - pz) < PEN_SIZE / 2)] = 5
    for k, (_, tx) in enumerate(TRAINING):
        g.tile[(np.abs(g.x - tx) < TRAIN_SIZE / 2) & (np.abs(g.z - TRAIN_Z) < TRAIN_SIZE / 2)] = 6 + k
    # everything inside, clear of the wall's pillars
    for cx, cz, h in [(x, z, PEN_SIZE / 2) for x, z in PENS] + [(x, TRAIN_Z, TRAIN_SIZE / 2) for _, x in TRAINING]:
        assert math.hypot(abs(cx) + h, abs(cz) + h) < BASE_R - 10, (cx, cz)
    check("Base", np.array([t[1] for t in BASE_TILES])[g.tile], g.inside)
    return g


# ---- a biome ---------------------------------------------------------------------------

def nests(b):
    W, zs, zn, cz = b["W"], b["zs"], b["zn"], b["cz"]
    inset = 40
    out = [(sx * (W / 2 - inset), z) for z in (zs - inset, zn + inset) for sx in (-1, 1)]
    if b["nests"] >= 6:
        out += [(sx * (W / 2 - 32), cz) for sx in (-1, 1)]
    if b["nests"] >= 8:
        out += [(sx * W / 4, zn + 32) for sx in (-1, 1)]
    return out


def biome(b, index):
    W = b["W"]
    # (its south gateway's floor too: the gap in the wall it shares with the last area)
    g = Grid(-W // 2, W // 2, b["zs"] + DIV_T, b["zn"])
    dx, dz = g.x, g.z - b["cz"]
    r = np.hypot(dx, dz)
    room = g.z < b["zs"]
    g.inside = room | (np.abs(g.x) < GATE_HALF)
    # the quasicrystal, centred on the boss; the floor rising toward the walls
    edge = np.maximum(np.abs(dx) / (W / 2), np.abs(dz) / (b["D"] / 2))
    q = value(dx, dz, b["angles"], b["scale"]) + b["bowl"] * (edge - 0.5)
    qs = np.quantile(q[room], b["cuts"])
    g.tile = np.searchsorted(qs, q).astype(int)
    g.tile = blocky(tidy(g.tile, g.inside), g.inside)
    g.tile = despeck(lower(g.tile, g.inside), g.inside)
    # stamped features: flat ground inside the gateways and round the nests, the dais
    # (an inlaid floor: a finer quasicrystal) and the raised ring round it
    fixed = np.zeros_like(g.inside)
    clear = (np.hypot(g.x, g.z - b["zs"]) < GATE_CLEAR) | ~room
    if index < len(BIOMES) - 1:
        clear |= np.hypot(g.x, g.z - b["zn"]) < GATE_CLEAR
    for nx_, nz_ in nests(b):
        d = np.hypot(g.x - nx_, g.z - nz_)
        clear |= d < NEST_CLEAR
        g.tile[d < NEST_PAD] = 6
        fixed |= d < NEST_PAD
    g.tile[clear & ~fixed] = 1
    fixed |= clear
    ring = (r >= b["dais"]) & (r < b["dais"] + RING_W)
    dais = r < b["dais"]
    inlay = value(dx, dz, b["angles"] * 2, 3.2) > 0.6
    g.tile[dais] = np.where(inlay[dais], 4, 3)
    g.tile[ring] = 5
    fixed |= ring | dais
    step = np.array(LADDER)[g.tile]
    step = raise_(step, g.inside, fixed)
    g.tile = np.where(fixed, g.tile, step)  # (terrain tiles are their own steps: 0, 1, 2)
    free = g.inside & ~fixed
    g.tile = np.where(free, despeck(g.tile.copy(), free), g.tile)
    check(b["name"], np.array(LADDER)[g.tile], g.inside)
    return g


# ---- walls and pillars -------------------------------------------------------------------

def walls_and_pillars():
    """Walls: (key, x0, z0, x1, z1) axis-aligned boxes (z0 > z1), plus the base ring's
    rotated pieces (key, cx, cz, length, thick, yaw). Pillars: (style, x, z, size, height, kind)."""
    walls, ring, pillars, arches, barriers = [], [], [], [], []
    # the base ring
    step = 2 * math.pi / RING_SEGMENTS
    for k in range(RING_SEGMENTS):
        if k in (0, RING_SEGMENTS - 1):
            continue  # (the two either side of north: the gateway)
        a = (k + 0.5) * step  # from north, clockwise seen from above
        rc = BASE_R + RING_T / 2
        length = 2 * (BASE_R + RING_T) * math.tan(step / 2) + 1
        ring.append(("Base", round(math.sin(a) * rc, 3), round(-math.cos(a) * rc, 3), round(length, 3), RING_T, round(-a, 6)))
    for k in range(2, RING_SEGMENTS - 1, 2):
        a = k * step
        rp = BASE_R + 4
        pillars.append(("Base", round(math.sin(a) * rp, 2), round(-math.cos(a) * rp, 2), 14, 15, "joint"))
    # the corridor to the Meadow, and the base's gateway pillars at its mouth
    top = -BASE_R + 48
    for sx in (-1, 1):
        x0, x1 = sorted((sx * GATE_HALF, sx * (GATE_HALF + 48)))
        walls.append(("Base", x0, top, x1, CORRIDOR_END))
        pillars.append(("Base", sx * (GATE_HALF + 12), -BASE_R - 2, 24, 34, "gate"))
    arches.append(("Base", 0, -BASE_R - 2))
    # the biomes
    prev_half = GATE_HALF + 48  # (the corridor's outer edge)
    for i, b in enumerate(BIOMES):
        name, half, zs, zn = b["name"], b["W"] / 2, b["zs"], b["zn"]
        # its south wall (shared with the last area), a gateway in it
        span = max(half, prev_half) + OUT_T
        for sx in (-1, 1):
            x0, x1 = sorted((sx * GATE_HALF, sx * span))
            walls.append((name, x0, zs + DIV_T, x1, zs))
            pillars.append((name, sx * (GATE_HALF + 12), zs + DIV_T / 2, 24, 36, "gate"))
        arches.append((name, 0, zs + DIV_T / 2))
        barriers.append(((BIOMES[i - 1]["name"] if i else "Base"), name, 0, zs + DIV_T / 2))
        # inner corners where it meets the walls either side (covering the step in width)
        for sx in (-1, 1):
            pillars.append((name, sx * half, zs, 22, 26, "corner"))
            if i and BIOMES[i - 1]["W"] / 2 != half:
                pillars.append((BIOMES[i - 1]["name"], sx * BIOMES[i - 1]["W"] / 2, zs + DIV_T, 22, 26, "corner"))
        # its side walls, in pieces with a pillar at each joint
        n = max(1, round(b["D"] / 112))
        for sx in (-1, 1):
            x0, x1 = sorted((sx * half, sx * (half + OUT_T)))
            walls.append((name, x0, zs, x1, zn))
            for k in range(1, n):
                pillars.append((name, sx * (half + 3), zs - k * b["D"] / n, 14, 18, "joint"))
        # joints along the south divider, between the corner and the gateway
        for sx in (-1, 1):
            mid = (GATE_HALF + 24 + half) / 2
            if half - GATE_HALF > 150:
                pillars.append((name, sx * mid, zs + DIV_T / 2, 16, 20, "joint"))
        prev_half = half
        if i == len(BIOMES) - 1:
            # the far wall: a gateway for the next world, sealed with rubble for now
            for sx in (-1, 1):
                x0, x1 = sorted((sx * GATE_HALF, sx * (half + OUT_T)))
                walls.append((name, x0, zn, x1, zn - OUT_T))
                pillars.append((name, sx * (GATE_HALF + 12), zn - DIV_T / 2, 24, 36, "gate"))
                pillars.append((name, sx * half, zn, 22, 26, "corner"))
            walls.append((name, -GATE_HALF, zn - 4, GATE_HALF, zn - OUT_T))
            arches.append((name, 0, zn - DIV_T / 2))
            pillars.append((name, 0, zn - 6, 20, 12, "rubble"))
    return walls, ring, pillars, arches, barriers


# ---- props -------------------------------------------------------------------------------

def props():
    """Pines on the base's wall and the Meadow's and Ice's plateaus: (item, x, z, top, yaw, scale)."""
    rng = np.random.default_rng(24)
    out = []
    for k in range(48):
        a = (k + 0.5) / 48 * 2 * math.pi
        if abs(math.sin(a)) * (BASE_R + 20) < GATE_HALF + 60 and math.cos(a) > 0:
            continue  # (clear of the gateway)
        rr = BASE_R + 14 + rng.uniform(0, 20)
        out.append(("PineTall" if k % 3 else "PineShort", math.sin(a) * rr, -math.cos(a) * rr, WALL_H, rng.uniform(0, 360), rng.uniform(1.1, 1.7)))
    for b in BIOMES:
        if b["name"] not in ("Meadow", "Ice"):
            continue
        for sx in (-1, 1):
            z = b["zs"] - 16
            while z > b["zn"] + 16:
                x = sx * (b["W"] / 2 + 16 + rng.uniform(0, 24))
                out.append(("PineTall" if rng.random() < 0.6 else "PineShort", x, z, WALL_H, rng.uniform(0, 360), rng.uniform(1.1, 1.8)))
                z -= rng.uniform(22, 38)
    return [(i, round(x, 2), round(z, 2), t, round(y, 1), round(s, 2)) for i, x, z, t, y, s in out]


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


def write(g_base, grids, walls, ring, pillars, arches, barriers, prop_list):
    L = []
    w = L.append
    w("-- GENERATED by tools/map_gen.py (QM, Oct 24): edit that and re-run it, not this.")
    w("-- The map's layout, built in game by Server/Map.luau. Studs; y up; north is -z.")
    w("-- Floor = { tile, x0, z0 (south edge), size x, size z }: the part runs from x0 east")
    w("-- and z0 north. Tiles = { ColorKey, top }: Key .. \"Checker\" is its checker's colour.")
    w("return {")
    w("\tWallHeight = %d," % WALL_H)
    w("\tGateHalf = %d," % GATE_HALF)
    w("\tAreas = {")

    def area(name, tiles, g, extra):
        w("\t\t{")
        w('\t\t\tName = "%s",' % name)
        for line in extra:
            w("\t\t\t" + line)
        w("\t\t\tTiles = { %s }," % ", ".join('{ "%s", %d }' % t for t in tiles))
        w("\t\t\tFloor = {")
        for p in g.floor():
            w("\t\t\t\t{ %d, %s, %s, %s, %s }," % (p[0] + 1, *(lua_num(v) for v in p[1:])))
        w("\t\t\t},")
        w("\t\t},")

    area("Base", BASE_TILES, g_base, [
        "Spawn = { 0, 0 },",
        "Pens = { %s }," % ", ".join("{ %s, %s }" % (lua_num(x), lua_num(z)) for x, z in PENS),
        "PenSize = %d," % PEN_SIZE,
        "Training = { %s }," % ", ".join('{ "%s", %s, %s }' % (n, x, TRAIN_Z) for n, x in TRAINING),
        "TrainSize = %d," % TRAIN_SIZE,
    ])
    for b, g in zip(BIOMES, grids):
        area(b["name"], [(b["name"] + s, LADDER[i] - 1) for i, (s, _) in enumerate(TILES)], g, [
            "Boss = { 0, %s }," % lua_num(b["cz"]),
            "DaisRadius = %d," % b["dais"],
            "RingWidth = %d," % RING_W,
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
    w("\t-- each gateway's barrier (for egg holders): { south area, north area, x, z }")
    w("\tBarriers = { %s }," % ", ".join('{ "%s", "%s", %s, %s }' % (a[0], a[1], lua_num(a[2]), lua_num(a[3])) for a in barriers))
    w("\t-- { item, x, z, ground y, yaw (degrees), scale }: ServerStorage.WorldAssets meshes")
    w("\tProps = {")
    for p in prop_list:
        w('\t\t{ "%s", %s },' % (p[0], ", ".join(lua_num(v) for v in p[1:])))
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

def preview(g_base, grids, walls, ring, pillars, arches, prop_list, colours, s=1.0, crop=None):
    xs = [-(b["W"] / 2 + OUT_T) for b in BIOMES] + [-BASE_R - RING_T]
    X0, X1 = min(xs) - 8, -min(xs) + 8
    Z0, Z1 = BASE_R + RING_T + 8, BIOMES[-1]["zn"] - OUT_T - 8
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
        tiles_of(b["name"], g, [(b["name"] + t[0], LADDER[i] - 1) for i, t in enumerate(TILES)])
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
    for it, x, z, top, yaw, sc in prop_list:
        r = (5 if it == "PineTall" else 4) * sc
        cx, cy = P(x, z)
        d.ellipse([cx - r * s, cy - r * s, cx + r * s, cy + r * s], fill=colours["PineNeedlesB"], outline=colours["PineNeedlesA"])
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
    cx, cy = P(0, 0)
    d.ellipse([cx - 5 * s, cy - 5 * s, cx + 5 * s, cy + 5 * s], fill=(40, 120, 255))
    return im


def main():
    out_dirs = [os.path.join(ROOT, "previews")] + sys.argv[1:]
    g_base = base()
    grids = [biome(b, i) for i, b in enumerate(BIOMES)]
    walls, ring, pillars, arches, barriers = walls_and_pillars()
    prop_list = props()
    path = write(g_base, grids, walls, ring, pillars, arches, barriers, prop_list)
    n = len(g_base.floor()) + sum(len(g.floor()) for g in grids)
    print("wrote", os.path.relpath(path, ROOT), "-", n, "floor parts,", len(walls) + len(ring), "walls,", len(pillars), "pillars,", len(prop_list), "props")
    for b, g in zip(BIOMES, grids):
        counts = {TILES[k][0]: int(((g.tile == k) & g.inside).sum()) for k in range(len(TILES))}
        print(" ", b["name"], "z", b["zs"], "to", b["zn"], "parts", len(g.floor()), counts)
    colours = config_colours()
    whole = preview(g_base, grids, walls, ring, pillars, arches, prop_list, colours, s=0.5)
    near = preview(g_base, grids, walls, ring, pillars, arches, prop_list, colours, s=2.0,
                   crop=(BASE_R + RING_T + 8, BIOMES[0]["zn"] - DIV_T - 8))
    for od in out_dirs:
        os.makedirs(od, exist_ok=True)
        whole.save(os.path.join(od, "map_overview.png"))
        near.save(os.path.join(od, "map_base_meadow.png"))
    for i, b in enumerate(BIOMES):
        im = preview(g_base, grids[:], walls, ring, pillars, arches, prop_list, colours, s=1.5,
                     crop=(b["zs"] + DIV_T + 16, b["zn"] - DIV_T - 16))
        for od in out_dirs:
            im.save(os.path.join(od, "map_%d_%s.png" % (i + 1, b["name"].lower())))


if __name__ == "__main__":
    main()
