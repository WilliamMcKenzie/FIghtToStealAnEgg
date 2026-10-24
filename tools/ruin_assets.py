"""Ruins and biome props (QM, Oct 24): broken stone pillars, boulders, runic monoliths,
big cacti, snowy pines, dead trees, bones (femur, ribcage, skull), and the decor of the
biomes past the Lava (torches, shackles, candles, palms, kelp, coral...), in LassoAPet's portal-gate style (chamfered,
slightly-off stone chunks, flat shaded, studded UVs) for the map's biomes.

Like tools/world_assets.py (same OBJ writer and stud UVs), but each piece may be several
convex chunks merged into one mesh, so a whole cactus or monolith is one MeshPart per
colour. Every piece's origin is the item's base centre (y = 0).

Run: python3 tools/ruin_assets.py
Writes assets/meshes/<Item>_<Piece>.obj, adds the items to assets/meshes/pieces.json,
and renders previews/ruin_assets.png. Then, on the Mac with Studio open (Edit):
  cd tools/studio && OUT=../../assets/meshes/ids.json python3 meshup.py ../../assets/meshes/ids.json ../../assets/meshes/*.obj
  python3 tools/make_lineup.py && python3 tools/studio/lu.py tools/lineup.luau Edit
which uploads the new meshes and rebuilds ServerStorage.WorldAssets; Server/Map places
them from there (and builds stone stand-ins until then).
"""

import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from world_assets import hull, stud_axes, STUD  # noqa: E402

OUT = os.path.join(HERE, "..", "assets", "meshes")


# ---- chunks ------------------------------------------------------------------------------

def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def place(pts, R=None, at=(0, 0, 0), pivot=(0, 0, 0)):
    """Rotate points about `pivot` by R, then move them by `at`."""
    p = np.asarray(pts, float) - pivot
    if R is not None:
        p = p @ R.T
    return p + pivot + np.asarray(at, float)


def block(rng, x0, y0, z0, x1, y1, z1, bevel=0.35, jitter=0.1):
    """A chamfered stone block (24 points): every corner cut back along its 3 edges."""
    pts = []
    for sx, xa in ((-1, x0), (1, x1)):
        for sy, ya in ((-1, y0), (1, y1)):
            for sz, za in ((-1, z0), (1, z1)):
                j = rng.uniform(-jitter, jitter, 3)
                b = bevel * rng.uniform(0.7, 1.3)
                c = np.array((xa, ya, za)) + j
                pts.append(c - (sx * b, 0, 0))
                pts.append(c - (0, sy * b, 0))
                pts.append(c - (0, 0, sz * b))
    return np.array(pts)


def prism(rng, y0, y1, r0, r1, sides, top=None, jitter=0.06, bevel=0.0):
    """A faceted column round the y axis; top(x, z) -> y offsets the top ring (broken
    tops). A bevel adds a chamfer ring under the top."""
    pts = []
    a0 = rng.uniform(0, 2 * math.pi)
    for i in range(sides):
        a = a0 + 2 * math.pi * i / sides
        c, s = math.cos(a), math.sin(a)
        rr0 = r0 * (1 + rng.uniform(-jitter, jitter))
        rr1 = r1 * (1 + rng.uniform(-jitter, jitter))
        dy = top(c * rr1, s * rr1) if top else 0
        pts.append((c * rr0, y0, s * rr0))
        if bevel:
            pts.append((c * rr1, y1 + dy - bevel, s * rr1))
            pts.append((c * (rr1 - bevel), y1 + dy, s * (rr1 - bevel)))
        else:
            pts.append((c * rr1, y1 + dy, s * rr1))
    return np.array(pts)


def boulder(rng, r, h, sides=7, squash=(1.0, 1.0)):
    """A chunky rock: base ring, shoulder ring, inset top ring."""
    pts = []
    a0 = rng.uniform(0, 2 * math.pi)
    for i in range(sides):
        a = a0 + 2 * math.pi * i / sides + rng.uniform(-0.2, 0.2)
        rr = r * (1 + rng.uniform(-0.18, 0.18))
        c, s = math.cos(a) * squash[0], math.sin(a) * squash[1]
        pts.append((c * rr, -0.5, s * rr))
        pts.append((c * rr * 1.02, h * rng.uniform(0.55, 0.7), s * rr * 1.02))
        pts.append((c * rr * 0.6, h * rng.uniform(0.92, 1.05), s * rr * 0.6))
    return np.array(pts)


def cone(rng, y0, y1, r, sides, droop):
    """A pine tier (as world_assets.cone): a drooping rim up to a tip."""
    pts = []
    a0 = rng.uniform(0, 2 * math.pi)
    for i in range(sides):
        a = a0 + 2 * math.pi * i / sides + rng.uniform(-0.18, 0.18)
        rr = r * (1 + rng.uniform(-0.1, 0.1))
        pts.append((math.cos(a) * rr, y0 - droop * rng.uniform(0.5, 1.0), math.sin(a) * rr))
        pts.append((math.cos(a) * rr * 0.6, y0 + 0.35, math.sin(a) * rr * 0.6))
    pts.append((rng.uniform(-0.15, 0.15), y1, rng.uniform(-0.15, 0.15)))
    return np.array(pts)


def limb(rng, start, direction, length, r0, r1, sides=5):
    """A tapered branch from `start` along `direction`."""
    d = np.asarray(direction, float)
    d /= np.linalg.norm(d)
    p = prism(rng, 0, length, r0, r1, sides)
    # turn +y onto d
    up = np.array((0, 1, 0))
    v = np.cross(up, d)
    s, c = np.linalg.norm(v), up @ d
    if s < 1e-6:
        R = np.eye(3)
    else:
        k = v / s
        K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
        R = np.eye(3) + s * K + (1 - c) * K @ K
    return place(p, R, start)


# ---- the items ---------------------------------------------------------------------------

def broken_pillar(seed):
    """A ruined column: a square plinth, three octagonal drums, the top one snapped off
    at a slant, and a fallen drum at its foot."""
    rng = np.random.default_rng(seed)
    stone = [block(rng, -3.4, 0, -3.4, 3.4, 1.4, 3.4, 0.4), block(rng, -3, 1.4, -3, 3, 2.2, 3, 0.3)]
    y = 2.2
    for k, h in enumerate((3.2, 3.0)):
        stone.append(place(prism(rng, 0, h - 0.1, 2.4, 2.3, 8, bevel=0.25), rot_y(rng.uniform(0, 1)), (0, y, 0)))
        y += h
    snap = lambda x, z: 1.6 * x / 2.3 + 0.5 * z / 2.3  # noqa: E731
    stone.append(place(prism(rng, 0, 2.2, 2.3, 2.25, 8, top=snap), None, (0, y, 0)))
    fallen = prism(rng, -1.2, 1.2, 2.3, 2.3, 8, bevel=0.2)
    stone.append(place(fallen, rot_y(0.6) @ rot_z(math.pi / 2), (5.6, 2.2, 2.4)))
    stone.append(place(boulder(rng, 0.9, 0.9, 6), None, (-3.8, 0, 3.2)))
    return [("Stone", "Stone", stone)]


def standing_pillar(seed):
    """An intact ruin column: plinth, four drums, a capital (for rows round an arena)."""
    rng = np.random.default_rng(seed)
    stone = [block(rng, -3.4, 0, -3.4, 3.4, 1.4, 3.4, 0.4)]
    y = 1.4
    for h in (3.2, 3.0, 3.1, 2.9):
        stone.append(place(prism(rng, 0, h - 0.1, 2.3, 2.2, 8, bevel=0.25), rot_y(rng.uniform(0, 1)), (0, y, 0)))
        y += h
    stone.append(block(rng, -2.9, y, -2.9, 2.9, y + 1.0, 2.9, 0.3))
    stone.append(block(rng, -3.5, y + 1.0, -3.5, 3.5, y + 2.0, 3.5, 0.35))
    return [("Stone", "Stone", stone)]


def boulders(seed):
    """A cluster of three rocks."""
    rng = np.random.default_rng(seed)
    rocks = [boulder(rng, 3.4, 4.2, 7), place(boulder(rng, 2.0, 2.6, 6), None, (3.6, 0, 1.4)),
             place(boulder(rng, 1.3, 1.5, 6), None, (-2.4, 0, 3.0))]
    return [("Rock", "StoneDark", rocks)]


def monolith(seed, h=16.0):
    """A runic monolith: a leaning, tapering slab with a pointed top, glowing runes cut
    proud of its two broad faces, broken stones round its foot."""
    rng = np.random.default_rng(seed)
    w0, w1, d0, d1 = 3.2, 2.4, 1.7, 1.3
    lean = rot_x(math.radians(4)) @ rot_z(math.radians(-3))
    slab = []
    for y, w, d in ((0, w0, d0), (h * 0.85, w1, d1)):
        for sx in (-1, 1):
            for sz in (-1, 1):
                slab.append((sx * w + rng.uniform(-0.1, 0.1), y, sz * d))
    slab += [(-w1 * 0.4, h, -d1 * 0.7), (w1 * 0.4, h, -d1 * 0.7), (-w1 * 0.4, h, d1 * 0.7), (w1 * 0.4, h, d1 * 0.7)]
    stone = [place(slab, lean), place(block(rng, -4.2, -0.4, -2.8, 4.2, 1.0, 2.8, 0.45), None)]
    stone += [place(boulder(rng, 1.0, 1.0, 6), None, (3.8, 0, 2.2)), place(boulder(rng, 0.8, 0.8, 6), None, (-3.6, 0, -2.0))]
    # runes: glyphs of a few bars, stacked up both broad faces
    runes = []
    glyphs = [((0, 0, 0, 1.8), (-0.6, 1.2, 0.6, 1.8), (-0.6, 0, 0.6, 0.6)),
              ((-0.6, 0, -0.6, 1.8), (0.6, 0, 0.6, 1.8), (-0.6, 0.9, 0.6, 0.9)),
              ((0, 0, 0, 1.8), (-0.7, 1.8, 0, 1.1), (0.7, 1.8, 0, 1.1)),
              ((-0.6, 0, 0.6, 1.8), (-0.6, 1.8, 0.6, 0), (0, 0, 0, 0.4))]
    for side in (-1, 1):
        for k, g in enumerate(glyphs):
            y = 2.6 + k * 3.0
            f = y / (h * 0.85)
            d = d0 + (d1 - d0) * f
            for x0, y0_, x1, y1_ in g:
                a, b = np.array((x0, y + y0_)), np.array((x1, y + y1_))
                length = max(np.linalg.norm(b - a), 0.3)
                ang = math.atan2(b[1] - a[1], b[0] - a[0])
                mid = (a + b) / 2
                bar = block(rng, -length / 2 - 0.18, -0.18, -0.12, length / 2 + 0.18, 0.18, 0.12, 0.04, 0.0)
                bar = place(bar, rot_z(ang), (mid[0], mid[1], side * (d + 0.05)))
                runes.append(place(bar, lean))
    return [("Stone", "LavaPillar", stone), ("Runes", "Rune", runes)]


def cactus(seed, h=17.0):
    """A big saguaro: a ribbed trunk in three drums, two arms, pink flowers on top."""
    rng = np.random.default_rng(seed)
    body = []
    y = 0
    for k, (dh, r) in enumerate(((h * 0.36, 2.0), (h * 0.34, 1.9), (h * 0.3, 1.75))):
        top = h if k == 2 else y + dh
        body.append(place(prism(rng, 0, top - y, r, r * 0.96 if k < 2 else r * 0.75, 8, bevel=0.5 if k == 2 else 0), None, (0, y, 0)))
        y += dh
    flowers = []
    for side, ya, reach, up in ((1, h * 0.38, 4.2, h * 0.36), (-1, h * 0.55, 3.6, h * 0.28)):
        body.append(limb(rng, (0, ya, 0), (side, 0.12, 0), reach, 1.25, 1.15, 7))
        x = side * (reach - 0.3)
        body.append(place(prism(rng, 0, up, 1.2, 1.0, 7, bevel=0.4), None, (x, ya - 0.6, 0)))
        flowers.append(place(prism(rng, 0, 0.7, 0.55, 0.85, 6), None, (x, ya - 0.6 + up - 0.1, 0)))
    flowers.append(place(prism(rng, 0, 0.8, 0.7, 1.0, 6), None, (0, h - 0.1, 0)))
    return [("Body", "CactusGreen", body), ("Flowers", "CactusFlower", flowers)]


def barrel_cactus(seed):
    rng = np.random.default_rng(seed)
    body = [prism(rng, 0, 2.4, 1.9, 1.5, 9, bevel=0.6), place(prism(rng, 0, 1.6, 1.2, 1.0, 8, bevel=0.4), None, (2.6, 0, 0.8))]
    flowers = [place(prism(rng, 0, 0.5, 0.5, 0.7, 6), None, (0, 2.35, 0))]
    return [("Body", "CactusGreen", body), ("Flowers", "CactusFlower", flowers)]


def snow_pine(seed, height=18, tiers=4, base_r=5.0, sides=7):
    """A pine with snow lying on each tier's upper slope."""
    rng = np.random.default_rng(seed)
    trunk = [prism(rng, -0.5, height * 0.55, 0.8, 0.55, 6)]
    needles, snow = [], []
    start = height * 0.22
    span = height - start
    for t in range(tiers):
        f = t / tiers
        y0 = start + span * f * 0.78
        y1 = min(y0 + span * (0.45 if t < tiers - 1 else 0.55), height)
        r = base_r * (1 - f * 0.62)
        tier = cone(rng, y0, y1, r, sides, 0.6)
        needles.append(tier)
        # the snow: the tier's top part, a touch bigger, sitting on it
        ys = y0 + (y1 - y0) * 0.38
        snow.append(cone(rng, ys, y1 + 0.3, r * 0.76, sides, 0.3))
    return [("Trunk", "PineTrunk", trunk), ("Needles", "SnowPineNeedles", needles), ("Snow", "Snow", snow)]


def dead_tree(seed, h=15.0):
    """A dead, charred tree: a leaning trunk, crooked bare branches."""
    rng = np.random.default_rng(seed)
    wood = [prism(rng, -0.5, h * 0.62, 1.2, 0.7, 6)]
    wood.append(place(limb(rng, (0, 0, 0), (0.15, 1, 0.05), h * 0.38, 0.72, 0.35, 5), None, (0, h * 0.6, 0)))
    for k in range(5):
        a = k / 5 * 2 * math.pi + rng.uniform(-0.4, 0.4)
        y = h * rng.uniform(0.35, 0.75)
        d = (math.cos(a), rng.uniform(0.4, 0.9), math.sin(a))
        length = rng.uniform(3.5, 5.5)
        wood.append(limb(rng, (0, y, 0), d, length, 0.45, 0.18, 5))
        tip = np.array((0, y, 0)) + np.array(d) / np.linalg.norm(d) * length * 0.8
        d2 = (math.cos(a + 0.8), rng.uniform(0.6, 1.2), math.sin(a + 0.8))
        wood.append(limb(rng, tip, d2, length * 0.45, 0.22, 0.1, 4))
    roots = [place(limb(rng, (0, 0.6, 0), (math.cos(a), -0.35, math.sin(a)), 2.2, 0.6, 0.25, 5), None)
             for a in (0.3, 2.4, 4.3)]
    return [("Wood", "DeadWood", wood + roots)]


def ball(rng, c, r, squash=(1, 1, 1), n=18):
    """A lumpy ball (a knuckle of bone, a cranium): points round a sphere, jittered."""
    pts = []
    for i in range(n):
        y = 1 - 2 * (i + 0.5) / n
        a = i * math.pi * (3 - math.sqrt(5))
        rr = math.sqrt(1 - y * y) * r * (1 + rng.uniform(-0.06, 0.06))
        pts.append((math.cos(a) * rr * squash[0], y * r * squash[1], math.sin(a) * rr * squash[2]))
    return place(pts, None, c)


def chain(rng, points, r0, r1, sides=6):
    """A bent bone along `points`, one tapered limb a span (they overlap at the joints)."""
    out = []
    n = len(points) - 1
    for k in range(n):
        a, b = np.asarray(points[k], float), np.asarray(points[k + 1], float)
        ra, rb = r0 + (r1 - r0) * k / n, r0 + (r1 - r0) * (k + 1) / n
        out.append(limb(rng, a, b - a, np.linalg.norm(b - a) + rb * 0.5, ra, rb, sides))
    return out


def femur(seed, length=10.0):
    """A giant thigh bone lying on the ground: a shaft with a double knuckle each end
    (QM, Oct 24: bones to decorate the Lava zone)."""
    rng = np.random.default_rng(seed)
    half = length / 2 - 1.0
    tilt = rot_y(math.radians(8))
    bone = [place(limb(rng, (-half, 0.75, 0), (1, 0.04, 0), 2 * half, 0.62, 0.55, 7), tilt)]
    for x in (-half - 0.3, half + 0.3):
        for z in (-0.6, 0.65):
            bone.append(place(ball(rng, (x, 0.9 if z < 0 else 0.8, z), 0.95), tilt))
    return [("Bone", "Bone", bone)]


def ribcage(seed, n=5):
    """A huge ribcage on its back: a spine of vertebrae down the middle, rib pairs arching
    up and in over it, longest in the middle, a gap left along the top."""
    rng = np.random.default_rng(seed)
    spine, ribs = [], []
    xs = np.linspace(-6, 6, n)
    for x in np.linspace(-7.5, 7.5, 9):
        spine.append(ball(rng, (x, 0.5, 0), 0.85, (1.0, 0.75, 1.1), 14))
    for k, x in enumerate(xs):
        R = 4.6 * (1 - 0.35 * abs(k - (n - 1) / 2) / ((n - 1) / 2))
        for side in (-1, 1):
            pts = []
            for f in np.linspace(-90, 55, 7):
                a = math.radians(f)
                sweep = 0.9 * (f + 90) / 145  # (the ribs lean back, toward the tail)
                pts.append((x + sweep, R * 0.95 + R * math.sin(a) + 0.3, side * R * math.cos(a)))
            ribs += chain(rng, pts, 0.42, 0.26, 5)
    return [("Ribs", "Bone", ribs), ("Spine", "BoneDark", spine)]


def skull(seed):
    """A big horned skull resting on the ground, muzzle to the front (-z): dark eye
    sockets and nose, a row of teeth, two curled horns."""
    rng = np.random.default_rng(seed)
    bone = [ball(rng, (0, 3.0, 0.8), 3.0, (1.0, 0.95, 1.05), 26),
            block(rng, -2.0, 0.2, -4.4, 2.0, 3.0, 0.0, 0.6, 0.08),
            block(rng, -1.4, 0.0, -1.2, 1.4, 1.6, 2.2, 0.4, 0.05)]
    for x in np.linspace(-1.5, 1.5, 5):
        bone.append(prism(rng, 0, 0.9, 0.32, 0.12, 5) + (x, -0.05, -4.05))
    dark = [ball(rng, (sx * 1.25, 3.5, -2.05), 0.85, (1.0, 0.8, 0.5), 14) for sx in (-1, 1)]
    dark.append(ball(rng, (0, 2.5, -4.35), 0.5, (1.1, 0.8, 0.4), 12))
    horns = []
    for sx in (-1, 1):
        pts = [(sx * 2.2, 4.6, 0.6), (sx * 3.6, 5.6, 0.9), (sx * 4.3, 7.0, 1.5), (sx * 4.1, 8.3, 2.4), (sx * 3.4, 9.0, 3.2)]
        horns += chain(rng, pts, 0.75, 0.15, 6)
    return [("Bone", "Bone", bone), ("Dark", "BoneDark", dark + horns)]


# ---- the new biomes' decor (QM, Oct 24: past the Lava, the Dungeon, Castle, Forest, Ocean) -

def flame(rng, c, r, h):
    """A teardrop flame on `c`: a narrow ring, a wide one, a point."""
    pts = []
    a0 = rng.uniform(0, 2 * math.pi)
    for i in range(7):
        a = a0 + 2 * math.pi * i / 7
        pts.append((math.cos(a) * r * 0.6, 0, math.sin(a) * r * 0.6))
        pts.append((math.cos(a) * r, h * 0.35, math.sin(a) * r))
    pts.append((rng.uniform(-0.1, 0.1) * r, h, rng.uniform(-0.1, 0.1) * r))
    return place(pts, None, c)


def cyl(rng, c, r0, r1, h, sides=8):
    """A short column standing on `c`."""
    return place(prism(rng, 0, h, r0, r1, sides, jitter=0.02), None, c)


def torch(seed):
    """A standing dungeon torch: a tripod, an iron pole, a bowl, a green flame."""
    rng = np.random.default_rng(seed)
    iron = [cyl(rng, (0, 0.8, 0), 0.28, 0.24, 5.0, 6)]
    for k in range(3):
        a = k * 2 * math.pi / 3
        iron += chain(rng, [(math.cos(a) * 1.4, 0, math.sin(a) * 1.4), (math.cos(a) * 0.5, 1.2, math.sin(a) * 0.5), (0, 2.4, 0)], 0.2, 0.16, 5)
    bowl = [cyl(rng, (0, 5.6, 0), 0.5, 1.05, 0.9, 8), cyl(rng, (0, 5.3, 0), 0.32, 0.5, 0.35, 8)]
    fire = [flame(rng, (0, 6.35, 0), 0.85, 2.4)]
    return [("Iron", "Iron", iron), ("Bowl", "IronDark", bowl), ("Flame", "DungeonFlame", fire)]


def wall_torch(seed):
    """A torch in a bracket on a wall: the back plate is the item's +z edge (z = 0), so it
    goes against a wall facing out (-z), seven studs up."""
    rng = np.random.default_rng(seed)
    plate = [block(rng, -0.6, 6.2, -0.3, 0.6, 8.6, 0, 0.1, 0.02)]
    arm = chain(rng, [(0, 7.0, -0.2), (0, 7.2, -1.0), (0, 7.9, -1.5)], 0.18, 0.15, 5)
    cup = [cyl(rng, (0, 7.8, -1.6), 0.3, 0.7, 0.7, 8)]
    fire = [flame(rng, (0, 8.4, -1.6), 0.6, 1.8)]
    return [("Iron", "Iron", plate + arm), ("Cup", "IronDark", cup), ("Flame", "DungeonFlame", fire)]


def shackles(seed):
    """Shackles on a wall (back at z = 0, as the wall torch): an iron plate, two chains
    hanging down to open cuffs."""
    rng = np.random.default_rng(seed)
    iron = [block(rng, -2.0, 6.0, -0.3, 2.0, 7.0, 0, 0.12, 0.02)]
    links = []
    for sx in (-1, 1):
        x = sx * 1.3
        for k in range(6):
            y = 5.8 - k * 0.55
            sq = (0.45, 1.0, 1.0) if k % 2 else (1.0, 1.0, 0.45)
            links.append(ball(rng, (x, y, -0.35), 0.3, sq, 10))
        cuff = place(prism(rng, -0.3, 0.3, 0.55, 0.55, 8, jitter=0.0), rot_x(math.pi / 2), (x, 2.3, -0.35))
        iron.append(cuff)
    return [("Iron", "Iron", iron), ("Chains", "IronDark", links)]


def human_skull(seed, s=1.4):
    """A human skull (s times life size, as a pet sees it), face to -z."""
    rng = np.random.default_rng(seed)
    bone = [ball(rng, (0, 0.95 * s, 0.15 * s), 0.8 * s, (0.92, 0.95, 1.05), 22),
            block(rng, -0.48 * s, 0.05 * s, -0.78 * s, 0.48 * s, 0.75 * s, 0.0, 0.15 * s, 0.01)]
    for x in np.linspace(-0.3, 0.3, 4):
        bone.append(cyl(rng, (x * s, 0.0, -0.72 * s), 0.07 * s, 0.05 * s, 0.25 * s, 5))
    dark = [ball(rng, (sx * 0.28 * s, 0.98 * s, -0.55 * s), 0.21 * s, (1.0, 0.9, 0.6), 10) for sx in (-1, 1)]
    dark.append(ball(rng, (0, 0.62 * s, -0.78 * s), 0.11 * s, (0.8, 1.2, 0.5), 8))
    return [("Bone", "Bone", bone), ("Dark", "BoneDark", dark)]


def candles_on(rng, tops, wax, fire, r=0.3, h=1.4):
    for x, y, z in tops:
        hh = h * rng.uniform(0.8, 1.15)
        wax.append(cyl(rng, (x, y, z), r, r * 0.95, hh, 7))
        fire.append(flame(rng, (x, y + hh, z), r * 0.9, r * 3))


def candelabra(seed):
    """A three-armed candelabra: a round foot, a knobbed stem, two arms curling up either
    side of the middle, a candle in each cup."""
    rng = np.random.default_rng(seed)
    gold = [cyl(rng, (0, 0, 0), 1.3, 0.9, 0.4, 10), cyl(rng, (0, 0.4, 0), 0.6, 0.22, 0.6, 8),
            cyl(rng, (0, 0.9, 0), 0.2, 0.18, 4.4, 6), ball(rng, (0, 2.2, 0), 0.42, (1, 0.8, 1), 12),
            ball(rng, (0, 3.6, 0), 0.32, (1, 0.8, 1), 12)]
    cups = [(0, 5.4, 0)]
    for sx in (-1, 1):
        gold += chain(rng, [(0, 3.6, 0), (sx * 0.9, 3.4, 0), (sx * 1.7, 3.7, 0), (sx * 2.0, 4.3, 0), (sx * 2.0, 4.7, 0)], 0.17, 0.15, 5)
        cups.append((sx * 2.0, 4.7, 0))
    for x, y, z in cups:
        gold.append(cyl(rng, (x, y - 0.1, z), 0.25, 0.5, 0.35, 8))
    wax, fire = [], []
    candles_on(rng, [(x, y + 0.2, z) for x, y, z in cups], wax, fire, 0.28, 1.6)
    return [("Gold", "Gold", gold), ("Wax", "CandleWax", wax), ("Flame", "CandleFlame", fire)]


def candles(seed):
    """A cluster of four candles of different heights in a puddle of wax."""
    rng = np.random.default_rng(seed)
    wax = [cyl(rng, (0, 0, 0), 1.7, 1.6, 0.12, 10)]
    fire = []
    for (x, z), h, r in (((0, 0), 3.0, 0.5), ((0.95, 0.45), 2.0, 0.4), ((-0.7, 0.75), 1.4, 0.38), ((0.2, -0.95), 1.0, 0.34)):
        wax.append(cyl(rng, (x, 0, z), r * 1.05, r, h, 8))
        fire.append(flame(rng, (x, h, z), r * 0.85, r * 2.8))
    return [("Wax", "CandleWax", wax), ("Flame", "CandleFlame", fire)]


def candle_podium(seed):
    """A small stone podium (the Forest's, after QM's reference braziers) with candles."""
    rng = np.random.default_rng(seed)
    dark = [block(rng, -1.4, 0, -1.4, 1.4, 0.6, 1.4, 0.2, 0.03), block(rng, -1.2, 3.4, -1.2, 1.2, 3.9, 1.2, 0.18, 0.03)]
    stone = [cyl(rng, (0, 0.5, 0), 0.85, 0.75, 3.0, 8)]
    wax, fire = [], []
    candles_on(rng, [(0, 3.9, 0), (0.6, 3.9, 0.45), (-0.55, 3.9, 0.5)], wax, fire, 0.26, 1.1)
    return [("Stone", "ForestPodium", stone), ("Trim", "ForestPodiumDark", dark),
            ("Wax", "ForestCandleWax", wax), ("Flame", "ForestFlame", fire)]


def forest_candle(seed):
    """The Forest's candle: a fat candle with wax drips in a stone dish, a blue flame."""
    rng = np.random.default_rng(seed)
    dish = [cyl(rng, (0, 0, 0), 0.9, 1.25, 0.5, 9)]
    wax = [cyl(rng, (0, 0.45, 0), 0.62, 0.58, 1.9, 9)]
    for k in range(4):
        a = k * math.pi / 2 + rng.uniform(-0.3, 0.3)
        wax.append(ball(rng, (math.cos(a) * 0.6, 1.4 + rng.uniform(0, 0.8), math.sin(a) * 0.6), 0.2, (1, 2.2, 1), 8))
    fire = [flame(rng, (0, 2.35, 0), 0.5, 1.5)]
    return [("Dish", "ForestPodiumDark", dish), ("Wax", "ForestCandleWax", wax), ("Flame", "ForestFlame", fire)]


def palms(small):
    """LassoAPet's palm (tools/pirate_meshes.py), reused (QM, Oct 24): its own meshes are
    already uploaded (ids.json), so these pieces are only for the editor's pictures."""
    lap = os.environ.get("LASSOAPET", os.path.join(HERE, "..", "..", "williammckenzie", "lassoapet"))
    sys.path.insert(0, os.path.join(lap, "tools"))
    import pirate_meshes as PM
    raw = (PM.palm_small if small else PM.palm_tall)(np.random.default_rng(5 if small else 3))
    keys = ["ForestTrunk", "ForestTrunkDark", "ForestFrondDark", "ForestFrond", "ForestFruit"]
    names = ["Trunk", "TrunkRings", "Fronds", "FrondsLight", "Fruit"]
    return [(n, k, pts) for n, k, (_, _, pts) in zip(names, keys, raw)]


def kelp(seed):
    """A clump of kelp: tall wavy blades, two greens."""
    rng = np.random.default_rng(seed)
    blades = [[], []]
    for k in range(5):
        a = k * 2 * math.pi / 5 + rng.uniform(-0.3, 0.3)
        r = rng.uniform(0.3, 1.2)
        h = rng.uniform(5, 9)
        x0, z0 = math.cos(a) * r, math.sin(a) * r
        pts = []
        for j in range(5):
            t = j / 4
            pts.append((x0 + math.cos(a) * t * 1.2 + 0.5 * math.sin(t * 5 + k), h * t, z0 + math.sin(a) * t * 1.2))
        side = np.array((-math.sin(a), 0, math.cos(a)))
        for j in range(4):
            p, q = np.array(pts[j]), np.array(pts[j + 1])
            w0 = 0.7 * math.sin(math.pi * (j / 4 * 0.8 + 0.2))
            w1 = 0.7 * math.sin(math.pi * ((j + 1) / 4 * 0.8 + 0.2)) if j < 3 else 0.08
            seg = [p + side * w0, p - side * w0, q + side * w1, q - side * w1]
            seg += [v + np.array((math.cos(a), 0, math.sin(a))) * 0.2 for v in seg]
            blades[k % 2].append(np.array(seg))
    return [("Blades", "Kelp", blades[0]), ("BladesDark", "KelpDark", blades[1])]


def starfish(seed):
    """An orange starfish lying flat: a domed middle, five tapered arms."""
    rng = np.random.default_rng(seed)
    body = [ball(rng, (0, 0.2, 0), 0.75, (1, 0.45, 1), 12)]
    for k in range(5):
        a = k * 2 * math.pi / 5 + rng.uniform(-0.1, 0.1)
        body += chain(rng, [(0, 0.2, 0), (math.cos(a) * 1.1, 0.22, math.sin(a) * 1.1), (math.cos(a) * 2.0, 0.12, math.sin(a) * 2.0)], 0.42, 0.14, 5)
    return [("Body", "Starfish", body)]


def sponges(seed):
    """Tube sponges, the purple-blue fingers of QM's reference, on a dark flat rock."""
    rng = np.random.default_rng(seed)
    rock = [boulder(rng, 3.0, 1.2, 7, (1.0, 0.75))]
    tubes = []
    for (x, z), h, r in (((0, 0), 4.4, 0.6), ((1.1, 0.4), 3.4, 0.5), ((-1.0, 0.5), 3.8, 0.55),
                         ((0.5, -0.9), 2.8, 0.45), ((-0.6, -0.8), 2.4, 0.42), ((1.7, -0.5), 2.0, 0.4)):
        tubes.append(cyl(rng, (x, 0.6, z), r, r * 0.9, h - 0.4, 8))
        tubes.append(ball(rng, (x, 0.6 + h - 0.4, z), r * 0.9, (1, 0.7, 1), 12))
    return [("Rock", "SpongeRock", rock), ("Tubes", "Sponge", tubes)]


def coral(seed):
    """A pink branching coral: a few trunks forking into upturned fingers."""
    rng = np.random.default_rng(seed)
    out = []

    def branch(p, d, length, r, depth):
        d = np.asarray(d, float) / np.linalg.norm(d)
        q = np.asarray(p, float) + d * length
        out.append(limb(rng, p, d, length + r * 0.5, r, r * 0.8, 6))
        if depth == 0:
            out.append(ball(rng, q, r * 0.85, (1, 1, 1), 10))
            return
        a = rng.uniform(0, 2 * math.pi)
        for turn in (-1.0, 1.0):
            # (a fork in a plane: one finger each way, both turning back up)
            nd = np.array((math.cos(a) * turn * 0.9, 1.0, math.sin(a) * turn * 0.9)) + d * 0.3
            branch(q, nd, length * rng.uniform(0.75, 0.9), r * 0.8, depth - 1)

    for k in range(3):
        a = k * 2 * math.pi / 3 + rng.uniform(-0.3, 0.3)
        branch((math.cos(a) * 0.5, 0, math.sin(a) * 0.5), (math.cos(a) * 0.35, 1, math.sin(a) * 0.35), 3.2, 0.6, 3)
    return [("Coral", "Coral", out)]


ITEMS = {
    "RuinPillarBroken": broken_pillar(41),
    "RuinPillar": standing_pillar(42),
    "Boulders": boulders(43),
    "Monolith": monolith(44),
    "Cactus": cactus(45),
    "CactusBarrel": barrel_cactus(46),
    "SnowPine": snow_pine(47),
    "DeadTree": dead_tree(48),
    "Femur": femur(49),
    "Ribcage": ribcage(50),
    "Skull": skull(51),
    "Torch": torch(52),
    "WallTorch": wall_torch(53),
    "Shackles": shackles(54),
    "HumanSkull": human_skull(55),
    "Candelabra": candelabra(56),
    "Candles": candles(57),
    "CandlePodium": candle_podium(58),
    "ForestCandle": forest_candle(59),
    "PalmTree": palms(False),
    "PalmTreeSmall": palms(True),
    "Kelp": kelp(60),
    "Starfish": starfish(61),
    "Sponges": sponges(62),
    "Coral": coral(63),
}
# (LassoAPet's palm meshes, already uploaded there: tools/pirate_meshes.py's pieces 1-5)
REUSED = {
    "PalmTree_Trunk": 99808729024646, "PalmTree_TrunkRings": 90764732062237, "PalmTree_Fronds": 109196007060782,
    "PalmTree_FrondsLight": 101932241612867, "PalmTree_Fruit": 93187689323776,
    "PalmTreeSmall_Trunk": 122426000934087, "PalmTreeSmall_TrunkRings": 90511748416329,
    "PalmTreeSmall_Fronds": 99500360728648, "PalmTreeSmall_FrondsLight": 71129173459040, "PalmTreeSmall_Fruit": 72799685534058,
}


# ---- output -----------------------------------------------------------------------------

def tris_of(chunks):
    out = []
    for c in chunks:
        c = np.asarray(c, float)
        for t in hull(c):
            out.append(c[list(t)])
    return out


def write_obj(path, tris):
    """One OBJ, every face its own normal (flat), planar stud UVs (as world_assets)."""
    lines = ["# generated by tools/ruin_assets.py"]
    vt, vn, faces = [], [], []
    nv = 0
    for t in tris:
        n = np.cross(t[1] - t[0], t[2] - t[0])
        n /= np.linalg.norm(n)
        su, sv = stud_axes(n)
        for v in t:
            lines.append("v %.4f %.4f %.4f" % tuple(v))
            vt.append("vt %.4f %.4f" % ((v @ su) / STUD, (v @ sv) / STUD))
        vn.append("vn %.4f %.4f %.4f" % tuple(n))
        faces.append((nv + 1, nv + 2, nv + 3, len(vn)))
        nv += 3
    lines += vt + vn
    lines += ["f %d/%d/%d %d/%d/%d %d/%d/%d" % (a, a, k, b, b, k, c, c, k) for a, b, c, k in faces]
    with open(path, "w") as fh:
        fh.write("\n".join(lines) + "\n")


COLOURS = {  # preview colours (in game: Config.WorldColors by key)
    "Stone": (214, 216, 206), "StoneDark": (150, 150, 144), "LavaPillar": (92, 78, 74), "Rune": (255, 120, 40),
    "CactusGreen": (92, 168, 70), "CactusFlower": (255, 120, 170), "PineTrunk": (120, 84, 58),
    "SnowPineNeedles": (52, 112, 96), "Snow": (244, 248, 252), "DeadWood": (70, 56, 50),
    "Bone": (232, 222, 196), "BoneDark": (150, 136, 112),
    "Iron": (84, 88, 96), "IronDark": (52, 54, 60), "DungeonFlame": (90, 255, 130), "Gold": (214, 168, 72),
    "CandleWax": (242, 232, 206), "CandleFlame": (255, 196, 92), "ForestTrunk": (92, 64, 82),
    "ForestTrunkDark": (74, 50, 68), "ForestFrond": (36, 150, 132), "ForestFrondDark": (28, 124, 112),
    "ForestFruit": (150, 96, 200), "ForestPodium": (150, 176, 240), "ForestPodiumDark": (104, 130, 214),
    "ForestCandleWax": (226, 220, 246), "ForestFlame": (96, 196, 255), "Kelp": (60, 168, 128),
    "KelpDark": (44, 136, 108), "Starfish": (255, 112, 64), "Sponge": (92, 92, 230), "SpongeRock": (52, 60, 108),
    "Coral": (226, 72, 170),
}


def render(items, path):
    """A lineup: flat-shaded triangles, painter's order, a 3/4 view, fitted to the image."""
    W, H = 2000, 560
    yaw, pitch = math.radians(30), math.radians(-18)
    R = rot_x(pitch) @ rot_y(yaw)
    light = np.array((-0.4, 0.8, -0.45))
    light /= np.linalg.norm(light)
    polys, labels = [], []
    x = 0
    for name, pieces in items.items():
        for _, key, tris in pieces:
            for t in tris:
                p = (t + (x, 0, 0)) @ R.T
                n = np.cross(t[1] - t[0], t[2] - t[0])
                n /= np.linalg.norm(n)
                shade = 0.55 + 0.45 * max(0, n @ light)
                col = tuple(int(c * shade) for c in COLOURS[key])
                polys.append((p[:, 2].mean(), p[:, :2], col))
        labels.append((name, (np.array((x, 0, 0)) @ R.T)[:2]))
        x += 16
    allp = np.concatenate([q[1] for q in polys])
    lo, hi = allp.min(0), allp.max(0)
    k = min((W - 80) / (hi[0] - lo[0]), (H - 90) / (hi[1] - lo[1]))

    def P(v):
        return (40 + (v[0] - lo[0]) * k, H - 50 - (v[1] - lo[1]) * k)

    im = Image.new("RGB", (W, H), (226, 232, 238))
    d = ImageDraw.Draw(im)
    for _, pts, col in sorted(polys, key=lambda q: -q[0]):
        d.polygon([P(v) for v in pts], fill=col)
    for name, at in labels:
        x0, _ = P(at)
        d.text((x0 - 30, H - 30), name, fill=(0, 0, 0))
    im.save(path)


def main():
    os.makedirs(OUT, exist_ok=True)
    index_path = os.path.join(OUT, "pieces.json")
    index = json.load(open(index_path))
    built = {}
    for item, pieces in ITEMS.items():
        index[item] = []
        built[item] = []
        for piece, key, chunks in pieces:
            name = "%s_%s" % (item, piece)
            tris = tris_of(chunks)
            write_obj(os.path.join(OUT, name + ".obj"), tris)
            index[item].append({"piece": piece, "colour": key, "obj": name})
            built[item].append((piece, key, tris))
            print("%-26s %4d triangles  (%s)" % (name, len(tris), key))
    with open(index_path, "w") as fh:
        json.dump(index, fh, indent=2)
    ids_path = os.path.join(OUT, "ids.json")
    ids = json.load(open(ids_path)) if os.path.exists(ids_path) else {}
    for name, asset in REUSED.items():
        ids.setdefault(name, "rbxassetid://%d" % asset)
    with open(ids_path, "w") as fh:
        json.dump(ids, fh, indent=2)
    os.makedirs(os.path.join(HERE, "..", "previews"), exist_ok=True)
    render(built, os.path.join(HERE, "..", "previews", "ruin_assets.png"))


if __name__ == "__main__":
    main()
