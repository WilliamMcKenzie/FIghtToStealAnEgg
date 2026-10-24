"""3D renders of the map (QM, Oct 24: see it in perspective, not just the top-down
previews), without Studio: the same layout as tools/map_gen.py, built roughly the way
Server/Map.luau builds it (floors with their checkers and studs, walls, stone-block
pillars and arches, ruins, props from assets/meshes, nests and eggs, pens and training
fences, the sleeping bosses), drawn with three.js in headless Chromium.

Run: python3 tools/render3d.py [out_dir ...]
     writes previews/3d_*.png (and copies to each out_dir).

Needs node with `playwright` (Chromium) and `three` (npm i three, anywhere on
NODE_PATH or under tools/node_modules). Pillars, ruins and fences use their own random
numbers, so stones sit a little differently than in game; the layout is exact.
"""

import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, HERE)
import map_gen as M  # noqa: E402

FLOOR_BOTTOM = -2
LIP = 0.25
ARCH_SPRING = 36
ARCH_SQUASH = 0.7
LIQUID_SINK = 1


def rot_y(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_xyz(rx, ry, rz):
    """Roblox CFrame.Angles(rx, ry, rz) (radians): X, then Y, then Z, applied as Rx*Ry*Rz."""
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rx @ Ry @ Rz


class Scene:
    """Triangles grouped by material: (colour key, mode). Modes: tex (checker and studs,
    world-aligned), plain (flat colour), glass (see-through liquid), glow (Neon)."""

    def __init__(self):
        self.groups = {}

    def add(self, key, mode, tris, uv=True):
        """tris: (n, 3, 3) world positions."""
        g = self.groups.setdefault((key, mode), [])
        g.append(np.asarray(tris, np.float32).reshape(-1, 3, 3))

    def box(self, key, centre, size, R=None, mode="tex", faces=None):
        R = np.eye(3) if R is None else R
        h = np.asarray(size, float) / 2
        corners = np.array([[sx, sy, sz] for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)], float) * h
        P = corners @ R.T + np.asarray(centre, float)
        # faces as quads of corner indices (outward winding), by normal name
        quads = {
            "top": (2, 3, 7, 6), "bottom": (0, 4, 5, 1), "right": (4, 6, 7, 5),
            "left": (0, 1, 3, 2), "back": (1, 5, 7, 3), "front": (0, 2, 6, 4),
        }
        tris = []
        for name, (a, b, c, d) in quads.items():
            if faces is not None and name not in faces:
                continue
            tris.append([P[a], P[b], P[c]])
            tris.append([P[a], P[c], P[d]])
        if tris:
            self.add(key, mode, tris)

    def aabb(self, key, x0, y0, z0, x1, y1, z1, mode="tex", faces=None):
        x0, x1 = sorted((x0, x1))
        y0, y1 = sorted((y0, y1))
        z0, z1 = sorted((z0, z1))
        self.box(key, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), mode=mode, faces=faces)

    def mesh(self, key, V, F, scale, R, t, mode="plain"):
        P = (V * scale) @ R.T + t
        self.add(key, mode, P[F])

    def cylinder_y(self, key, centre, radius, height, n=20, mode="plain"):
        cx, cy, cz = centre
        tris = []
        for i in range(n):
            a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
            p0 = (cx + math.cos(a0) * radius, cz + math.sin(a0) * radius)
            p1 = (cx + math.cos(a1) * radius, cz + math.sin(a1) * radius)
            b, t = cy - height / 2, cy + height / 2
            tris += [[(p0[0], b, p0[1]), (p1[0], t, p1[1]), (p1[0], b, p1[1])],
                     [(p0[0], b, p0[1]), (p0[0], t, p0[1]), (p1[0], t, p1[1])],
                     [(cx, t, cz), (p1[0], t, p1[1]), (p0[0], t, p0[1])]]
        self.add(key, mode, tris)

    def ellipsoid(self, key, centre, radii, n=12, mode="plain"):
        tris = []
        c = np.asarray(centre, float)
        r = np.asarray(radii, float)

        def p(i, j):
            th, ph = math.pi * i / n, 2 * math.pi * j / n
            return c + r * np.array([math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph)])

        for i in range(n):
            for j in range(n):
                a, b, cc, d = p(i, j), p(i + 1, j), p(i + 1, j + 1), p(i, j + 1)
                tris += [[a, cc, b], [a, d, cc]]
        self.add(key, mode, tris)

    def export(self):
        out = []
        for (key, mode), parts in self.groups.items():
            T = np.concatenate(parts)
            n = np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0])
            n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
            # (consistent outward faces aren't guaranteed for meshes: three draws both sides)
            N = np.repeat(n[:, None, :], 3, axis=1)
            P = T.reshape(-1, 3)
            # world-aligned UVs on the face's dominant axis (16 studs = one 2x2 checker)
            ax = np.abs(N.reshape(-1, 3)).argmax(1)
            U = np.where(ax == 0, P[:, 2], P[:, 0])
            Vv = np.where(ax == 1, P[:, 2], P[:, 1])
            out.append({"key": key, "mode": mode,
                        "pos": np.round(P, 3).ravel().tolist(),
                        "nrm": np.round(N.reshape(-1, 3), 3).ravel().tolist(),
                        "uv": np.round(np.stack([U, Vv], 1) / 16, 4).ravel().tolist()})
        return out


# ---- assets ----------------------------------------------------------------------------

def load_obj(name):
    V, F = [], []
    for line in open(os.path.join(ROOT, "assets", "meshes", name + ".obj")):
        if line.startswith("v "):
            V.append([float(v) for v in line.split()[1:4]])
        elif line.startswith("f "):
            idx = [int(v.split("/")[0]) - 1 for v in line.split()[1:]]
            for k in range(1, len(idx) - 1):
                F.append([idx[0], idx[k], idx[k + 1]])
    return np.array(V), np.array(F)


PIECES = json.load(open(os.path.join(ROOT, "assets", "meshes", "pieces.json")))
OBJS = {}


def obj(name):
    if name not in OBJS:
        OBJS[name] = load_obj(name)
    return OBJS[name]


# the stone block, centred on its box and 1x1x1 (Map's stone() sizes it)
_bv, _bf = load_obj("StoneBlock_Block")
_lo, _hi = _bv.min(0), _bv.max(0)
BLOCK = ((_bv - (_lo + _hi) / 2) / (_hi - _lo), _bf)


def stone(scene, key, centre, size, R=None):
    R = np.eye(3) if R is None else R
    scene.mesh(key, BLOCK[0], BLOCK[1], np.asarray(size, float), R, np.asarray(centre, float))


def pillar_keys(style):
    return ("Stone", "StoneDark") if style == "Base" else (style + "Pillar", style + "PillarDark")


def wall_keys(style):
    return ("WallDirt", "Grass") if style == "Base" else (style + "Wall", style + "Cap")


def colours():
    src = open(os.path.join(ROOT, "src", "shared", "Config.luau")).read()
    out = {k: (int(r), int(g), int(b)) for k, r, g, b in re.findall(r"(\w+) = Color3\.fromRGB\((\d+), (\d+), (\d+)\)", src[src.index("WorldColors = {"):])}
    eggs = src[src.index("Eggs = {"):]
    eggs = eggs[eggs.index("Colors = {"):eggs.index("},")]
    for k, r, g, b in re.findall(r"(\w+) = Color3\.fromRGB\((\d+), (\d+), (\d+)\)", eggs):
        out["Egg" + k] = (int(r), int(g), int(b))
    return out


def boss_settings():
    src = open(os.path.join(ROOT, "src", "shared", "Config.luau")).read()
    src = src[src.index("Bosses = {"):]
    out = {}
    for b in M.BIOMES:
        block = src[src.index("\t\t%s = {" % b["name"]):]
        out[b["name"]] = (re.search(r'Model = "(\w+)"', block).group(1), float(re.search(r"Size = ([\d.]+)", block).group(1)))
    return out


def animal(scene, model, at, scale, yaw, extra_colours):
    src = open(os.path.join(ROOT, "src", "shared", "Animals", model + "Model.luau")).read()
    src = src[src.index("parts = {"):]
    R0 = rot_y(yaw)
    for m in re.finditer(r"size = Vector3\.new\(([^)]*)\),\s*cframe = CFrame\.new\(([^)]*)\),\s*color = Color3\.fromRGB\(([^)]*)\)", src):
        size = np.array([float(v) for v in m.group(1).split(",")]) * scale
        cf = [float(v) for v in m.group(2).split(",")]
        pos = np.array(cf[:3]) * scale
        R = np.array(cf[3:12]).reshape(3, 3) if len(cf) == 12 else np.eye(3)
        rgb = tuple(int(v) for v in m.group(3).split(","))
        key = "_rgb_%d_%d_%d" % rgb
        extra_colours[key] = rgb
        scene.box(key, R0 @ pos + at, size, R0 @ R, mode="plain")


# ---- pieces (as Server/Map.luau's), also the map editor's sprites (tools/mapeditor) ----------

def pillar(scene, rng, st, x, z, size, height, kind):
    """A pillar of rough stone blocks, as Map.luau's pillar()."""
    J = lambda a: (rng.random() * 2 - 1) * a  # noqa: E731
    U = lambda a, b: rng.uniform(a, b)  # noqa: E731
    light, dark = pillar_keys(st)
    pick = lambda: dark if rng.random() < 0.3 else light  # noqa: E731
    if kind == "gate":
        height = ARCH_SPRING + 6
    if kind == "rubble":
        for _ in range(9):
            s = U(6, 11)
            stone(scene, pick(), (x + J(M.GATE_HALF - 6), s * 0.35 + U(0, max(0.1, height - s * 0.6)), z + J(4)),
                  (s, s * U(0.7, 1), s * U(0.8, 1.1)), rot_xyz(math.radians(J(25)), math.radians(U(0, 90)), math.radians(J(25))))
        return
    plinth = max(2, height * 0.12)
    stone(scene, dark, (x, plinth / 2, z), (size + 3, plinth, size + 3))
    y = plinth
    capH = max(2, size * 0.15)
    shaftTop = height - capH * 2
    course = 0
    while y < shaftTop - 0.5:
        hh = min(10, max(3, size * U(0.45, 0.7)))
        if shaftTop - (y + hh) < 2.5:
            hh = shaftTop - y
        tilt = rot_xyz(math.radians(J(1.5)), math.radians(J(4)), math.radians(J(1.5)))
        if size >= 18:
            cut = 0.5 + J(0.12)
            for side in (0, 1):
                a0, a1 = (0, cut) if side == 0 else (cut, 1)
                w = (a1 - a0) * size - 0.15
                mid = -size / 2 + (a0 + a1) / 2 * size
                along = course % 2 == 0
                off = np.array([mid, 0, 0]) if along else np.array([0, 0, mid])
                s = np.array([w, hh, size]) if along else np.array([size, hh, w])
                inset = U(0, 0.6)
                stone(scene, pick(), np.array([x + J(0.3), y + hh / 2, z + J(0.3)]) + off, s - [inset, 0, inset], tilt)
        else:
            stone(scene, pick(), (x + J(0.4), y + hh / 2, z + J(0.4)), (size * U(0.94, 1), hh, size * U(0.94, 1)), tilt)
        y += hh
        course += 1
    stone(scene, light, (x, y + capH / 2, z), (size + 1.5, capH, size + 1.5), rot_y(J(3)))
    y += capH
    stone(scene, dark, (x, y + capH / 2, z), (size + 3, capH, size + 3), rot_y(J(3)))
    y += capH
    if kind == "gate":
        stone(scene, light, (x, y + 1.5, z), (size * 0.55, 3, size * 0.55), rot_y(45 + J(4)))


def arch(scene, rng, st, x, z):
    """An arch over a gateway, as Map.luau's arch()."""
    light, dark = pillar_keys(st)
    rIn, n, depth = M.GATE_HALF, 7, 14
    rOut = rIn + 9
    for i in range(n):
        a0, a1 = math.pi * i / n + 0.012, math.pi * (i + 1) / n - 0.012
        am, rm = (a0 + a1) / 2, (rIn + rOut) / 2
        key_ = i == (n - 1) // 2
        pos = (x + math.cos(am) * rm, ARCH_SPRING + 10 + math.sin(am) * rm * ARCH_SQUASH, z)
        tan = np.array([-math.sin(am), math.cos(am) * ARCH_SQUASH, 0])
        tan /= np.linalg.norm(tan)
        up = np.cross([0, 0, 1], tan)
        R = np.stack([tan, up, np.cross(tan, up)], 1)
        length = (a1 - a0) * rm * (1 + ARCH_SQUASH) / 2 + 1.2
        size = (length, rOut - rIn + (3 if key_ else rng.uniform(-0.4, 0.6)), depth + (2 if key_ else 0))
        stone(scene, dark if key_ or rng.random() < 0.3 else light, pos, size, R)


def nest(scene, rng, x, z, egg=None):
    """A straw nest (and its egg), as Map.luau's nest()."""
    J = lambda a: (rng.random() * 2 - 1) * a  # noqa: E731
    scene.cylinder_y("Straw", (x, 0.5, z), 5.5, 1)
    for i in range(14):
        a = (i + rng.uniform(-0.3, 0.3)) / 14 * 2 * math.pi
        r = 5.6 + rng.uniform(-0.3, 0.3)
        R = rot_y(math.degrees(-a)) @ rot_xyz(math.radians(J(20)), 0, math.radians(J(12)))
        scene.box("Wood" if i % 3 == 0 else "StrawDark", (x + math.cos(a) * r, 1.1 + rng.uniform(0, 0.5), z + math.sin(a) * r), (0.8, 0.8, rng.uniform(4, 5.5)), R, mode="plain")
    if egg:
        scene.ellipsoid(egg, (x, 1 + 3.3 / 2, z), (1.3, 1.65, 1.3))


def prop_key(item, key, st):
    """A prop piece's colour in its style (as Server/Map propKey): boulders and monoliths
    have each biome's own colours, other grey stone the biome's pillar colours."""
    pre = "" if st == "Base" else st
    if item == "Boulders" and key in ("Stone", "StoneDark"):
        return pre + ("Boulder" if key == "Stone" else "BoulderDark")
    if item == "Monolith":
        if key == "Rune":
            return pre + "Rune"
        if key in ("LavaPillar", "Stone"):
            return pre + "Monolith"
        if key in ("LavaPillarDark", "StoneDark"):
            return pre + "MonolithDark"
    elif st != "Base" and key in ("Stone", "StoneDark"):
        return st + ("Pillar" if key == "Stone" else "PillarDark")
    return key


def prop(scene, item, x, z, gy, yaw, scale, st):
    """A prop from assets/meshes (pieces.json), its stone in its style's colours."""
    R = rot_y(yaw)
    for p in PIECES[item]:
        key = prop_key(item, p["colour"], st)
        V, F = obj(p["obj"])
        scene.mesh(key, V, F, scale, R, np.array([x, gy, z]), mode="glow" if key.endswith(("Rune", "Flame")) else "plain")


# ---- the build (as Server/Map.luau) ------------------------------------------------------

def build():
    rng = np.random.default_rng(1024)
    J = lambda a: (rng.random() * 2 - 1) * a  # noqa: E731
    U = lambda a, b: rng.uniform(a, b)  # noqa: E731
    scene = Scene()
    extra = {}
    g_base = M.base()
    grids = [M.biome(b, i) for i, b in enumerate(M.BIOMES)]
    walls, ring, pillars, arches, barriers = M.walls_and_pillars()
    props, ruins = M.props(grids)

    # floors
    areas = [("Base", [(k, t) for k, t in M.BASE_TILES], g_base)] + [
        (b["name"], [(b["name"] + s, st - 1, wet) for s, st, wet in b["tiles"]], g) for b, g in zip(M.BIOMES, grids)]
    for name, tiles, g in areas:
        lowest = min(t[1] for t in tiles)
        for k, x0, z0, sx, sz in g.floor():
            t = tiles[k]
            key, top = t[0], t[1]
            if len(t) > 2 and t[2]:
                bed = top - LIQUID_SINK
                scene.aabb(key, x0, FLOOR_BOTTOM - 2, z0, x0 + sx, bed, z0 - sz, faces=["top"])
                scene.aabb(key, x0, bed, z0, x0 + sx, top - 0.2, z0 - sz, mode="glow" if name == "Lava" else "glass", faces=["top"])
                continue
            faces = None if top > lowest else ["top"]
            scene.aabb(key, x0, FLOOR_BOTTOM, z0, x0 + sx, top, z0 - sz, faces=faces)

    # walls
    h = M.WALL_H
    for st, x0, z0, x1, z1 in walls:
        key, cap = wall_keys(st)
        scene.aabb(key, x0, FLOOR_BOTTOM, z0, x1, h - 1, z1, faces=["left", "right", "front", "back"])
        scene.aabb(cap, x0 - LIP, h - 1, z0 + LIP, x1 + LIP, h, z1 - LIP)
    for st, cx, cz, length, thick, yaw in ring:
        key, cap = wall_keys(st)
        R = rot_y(math.degrees(yaw))
        scene.box(key, (cx, (FLOOR_BOTTOM + h - 1) / 2, cz), (length, h - 1 - FLOOR_BOTTOM, thick), R, faces=["left", "right", "front", "back"])
        scene.box(cap, (cx, h - 0.5, cz), (length + 2 * LIP, 1, thick + 2 * LIP), R)

    # pillars and arches
    for st, x, z, size, height, kind in pillars:
        pillar(scene, rng, st, x, z, size, height, kind)
    for st, x, z in arches:
        arch(scene, rng, st, x, z)

    # ruins
    for st, x, z, length, yaw, height, seed in ruins:
        light, dark = pillar_keys(st)
        r2 = np.random.default_rng(seed)
        R0 = rot_y(yaw)
        at = np.array([x, -1, z])
        peak = r2.uniform(-0.3, 0.3)

        def top(u):
            return max(1.8, height * (1 - abs(u - peak) * 1.4) + r2.uniform(-1.2, 1.2))

        for c in range(math.ceil(height / 1.8) + 1):
            y = c * 1.8
            u = -length / 2 + (0 if c % 2 == 0 else -r2.uniform(1, 2))
            while u < length / 2:
                w = r2.uniform(3, 4.6)
                u0, u1 = max(u, -length / 2), min(u + w, length / 2)
                mid = (u0 + u1) / 2
                if u1 - u0 > 1 and y + 1.8 <= top(mid / length):
                    stone(scene, dark if r2.random() < 0.35 else light, at + R0 @ np.array([mid, y + 0.9, r2.uniform(-0.2, 0.2)]),
                          (u1 - u0 - 0.15, 1.72, 3 * r2.uniform(0.9, 1)), R0 @ rot_y(r2.uniform(-3, 3)))
                u += w

    # props
    for item, x, z, gy, yaw, scale, st in props:
        prop(scene, item, x, z, gy, yaw, scale, st)

    # nests and their eggs
    for b in M.BIOMES:
        for x, z in M.nests(b):
            nest(scene, rng, x, z, "Egg" + b["name"])

    # pens and training grounds: fences, dummies, the spawn pad
    def fence(cx, cz, size, top, gate):
        half = size / 2 - 1
        sides = [((-half, -half), (half, -half)), ((half, -half), (half, half)), ((half, half), (-half, half)), ((-half, half), (-half, -half))]
        for a, b in sides:
            a, b = np.array(a, float), np.array(b, float)
            mid = (a + b) / 2
            is_gate = (gate[0] != 0 and np.sign(mid[0]) == gate[0] and abs(mid[0]) > 1) or (gate[1] != 0 and np.sign(mid[1]) == gate[1] and abs(mid[1]) > 1)

            def run(p0, p1):
                length = np.linalg.norm(p1 - p0)
                n = max(1, math.ceil(length / 6))
                for i in range(n + 1):
                    p = p0 + (p1 - p0) * i / n
                    scene.box("WoodDark", (cx + p[0], top + 2, cz + p[1]), (1.2, 4, 1.2))
                d = (p1 - p0) / length
                yaw = math.degrees(math.atan2(d[0], d[1]))
                for y in (1.2, 3.2):
                    m = (p0 + p1) / 2
                    scene.box("Wood", (cx + m[0], top + y, cz + m[1]), (0.5, 0.5, length), rot_y(yaw), faces=["left", "right", "front", "back", "top"])

            if is_gate:
                d = (b - a) / np.linalg.norm(b - a)
                run(a, mid - d * 5)
                run(mid + d * 5, b)
            else:
                run(a, b)

    for x, z in M.PENS:
        fence(x, z, M.PEN_SIZE, 0, (1 if x < 0 else -1, 0))
    for name, x in M.TRAINING:
        fence(x, M.TRAIN_Z, M.TRAIN_SIZE, 0, (0, -1))
        if name == "Dummies":
            for k in (-1, 0, 1):
                for row in (0, 1):
                    px, pz = x + k * 12 + row * 6 - 3, M.TRAIN_Z - 4 + row * 12
                    R = rot_y(k * -10)
                    for off, size, key in [((0, 2.5, 0), (1, 5, 1), "WoodDark"), ((0, 5.5, 0), (3, 4, 2), "Straw"),
                                           ((0, 6.6, 0), (7, 0.8, 0.8), "WoodDark"), ((0, 8.6, 0), (2.2, 2.2, 2.2), "StrawDark")]:
                        scene.box(key, np.array([px, 0, pz]) + R @ np.array(off), size, R)
    sx, sz = M.SPAWN
    scene.aabb("Dirt", sx - 5, -1, sz - 5, sx + 5, 0, sz + 5)

    # the bosses, asleep on their spots; a few mobs in the training grounds
    bosses = boss_settings()
    for b in M.BIOMES:
        model, size = bosses[b["name"]]
        animal(scene, model, np.array([0, 0, b["cz"]]), size, 0, extra)
    mobs = {"Meadow": ("Pig", 0.55), "Desert": ("KingCrab", 1), "Ice": ("Penguin", 0.6), "Lava": ("RockHog", 0.5)}
    for name, x in M.TRAINING:
        if name in mobs:
            for k in range(3):
                animal(scene, mobs[name][0], np.array([x + U(-14, 14), 0, M.TRAIN_Z + U(-14, 14)]), mobs[name][1], U(0, 360), extra)
    return scene, extra


# ---- views -------------------------------------------------------------------------------

def views():
    out = [("3d_spawn", (0, 260, 380), (0, 0, -28), 42)]
    for i, b in enumerate(M.BIOMES):
        W, D = b["W"], b["D"]
        out.append(("3d_%d_%s" % (i + 1, b["name"].lower()), (W * 0.42, D * 0.9, b["zs"] + D * 0.55), (0, 0, b["cz"] - D * 0.05), 45))
    zmid = (M.BASE_S + M.BIOMES[-1]["zn"]) / 2
    out.append(("3d_overview", (900, 1100, zmid + 900), (0, 0, zmid - 60), 50))
    return out


RENDER_JS = r"""
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const [scenePath, outDir, threePath] = process.argv.slice(2);
(async () => {
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });
  page.on('console', m => console.log('page:', m.text()));
  page.on('pageerror', e => console.log('page error:', e.message));
  await page.setContent('<html><body style="margin:0;background:#9cc8ee"></body></html>');
  await page.addScriptTag({ content: 'var module = { exports: {} }; var exports = module.exports;\n' + fs.readFileSync(threePath, 'utf8') + '\nwindow.THREE = module.exports;' });
  const data = JSON.parse(fs.readFileSync(scenePath, 'utf8'));
  await page.evaluate((data) => {
    const T = window.THREE;
    const renderer = new T.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
    renderer.setSize(1600, 1000);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = T.PCFSoftShadowMap;
    renderer.outputColorSpace = T.SRGBColorSpace;
    renderer.toneMapping = T.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.05;
    document.body.appendChild(renderer.domElement);
    const scene = new T.Scene();
    scene.background = new T.Color(0x9cc8ee);
    scene.fog = new T.Fog(0x9cc8ee, 900, 3200);
    scene.add(new T.HemisphereLight(0xdcecff, 0x6a5a48, 1.25));
    const sun = new T.DirectionalLight(0xfff2dc, 2.2);
    sun.castShadow = true;
    sun.shadow.mapSize.set(4096, 4096);
    sun.shadow.bias = -0.0004;
    sun.shadow.normalBias = 0.4;
    scene.add(sun); scene.add(sun.target);
    const rgb = (c) => new T.Color().setRGB(c[0] / 255, c[1] / 255, c[2] / 255, T.SRGBColorSpace);
    const texCache = {};
    function checker(key) {
      if (texCache[key]) return texCache[key];
      const a = data.colours[key] || [255, 0, 255], b = data.colours[key + 'Checker'] || a;
      const cv = document.createElement('canvas'); cv.width = cv.height = 256;
      const g = cv.getContext('2d');
      for (let i = 0; i < 2; i++) for (let j = 0; j < 2; j++) {
        const c = (i + j) % 2 ? b : a;
        g.fillStyle = `rgb(${c[0]},${c[1]},${c[2]})`; g.fillRect(i * 128, j * 128, 128, 128);
      }
      // studs: a soft light top-left and dark bottom-right rim on every stud
      for (let i = 0; i < 16; i++) for (let j = 0; j < 16; j++) {
        const x = i * 16 + 8, y = j * 16 + 8;
        g.strokeStyle = 'rgba(255,255,255,0.10)'; g.lineWidth = 1.5;
        g.beginPath(); g.arc(x, y, 4.5, Math.PI * 0.9, Math.PI * 1.9); g.stroke();
        g.strokeStyle = 'rgba(0,0,0,0.10)';
        g.beginPath(); g.arc(x, y, 4.5, Math.PI * -0.1, Math.PI * 0.9); g.stroke();
      }
      const t = new T.CanvasTexture(cv);
      t.wrapS = t.wrapT = T.RepeatWrapping; t.colorSpace = T.SRGBColorSpace;
      t.anisotropy = 8; t.magFilter = T.NearestFilter;
      return texCache[key] = t;
    }
    for (const g of data.groups) {
      const geo = new T.BufferGeometry();
      geo.setAttribute('position', new T.Float32BufferAttribute(g.pos, 3));
      geo.setAttribute('normal', new T.Float32BufferAttribute(g.nrm, 3));
      geo.setAttribute('uv', new T.Float32BufferAttribute(g.uv, 2));
      const col = rgb(data.colours[g.key] || [255, 0, 255]);
      let mat;
      if (g.mode === 'tex') mat = new T.MeshLambertMaterial({ map: checker(g.key) });
      else if (g.mode === 'glass') mat = new T.MeshLambertMaterial({ map: checker(g.key), transparent: true, opacity: 0.7 });
      else if (g.mode === 'glow') mat = new T.MeshBasicMaterial({ color: col.clone().multiplyScalar(1.6) });
      else mat = new T.MeshLambertMaterial({ color: col, flatShading: true });
      mat.side = g.mode === 'plain' ? T.DoubleSide : T.FrontSide;
      const mesh = new T.Mesh(geo, mat);
      mesh.castShadow = g.mode !== 'glass' && g.mode !== 'glow';
      mesh.receiveShadow = true;
      scene.add(mesh);
    }
    const cam = new T.PerspectiveCamera(45, 1.6, 2, 6000);
    window.shot = (v) => {
      cam.position.set(...v.eye); cam.fov = v.fov; cam.updateProjectionMatrix(); cam.lookAt(...v.at);
      const span = v.span;
      sun.position.set(v.at[0] + span * 0.5, span * 1.2, v.at[2] + span * 0.8);
      sun.target.position.set(...v.at);
      const sc = sun.shadow.camera;
      sc.left = sc.bottom = -span; sc.right = sc.top = span; sc.near = 1; sc.far = span * 4;
      sc.updateProjectionMatrix();
      renderer.render(scene, cam);
      return renderer.domElement.toDataURL('image/png');
    };
  }, data);
  for (const v of data.views) {
    const url = await page.evaluate((v) => window.shot(v), v);
    fs.writeFileSync(path.join(outDir, v.name + '.png'), Buffer.from(url.split(',')[1], 'base64'));
    console.log('rendered', v.name);
  }
  await browser.close();
})();
"""


def find_three():
    for d in [os.path.join(HERE, "node_modules")] + os.environ.get("NODE_PATH", "").split(os.pathsep):
        p = os.path.join(d, "three", "build", "three.cjs")
        if d and os.path.exists(p):
            return p
    sys.exit("three.js not found: npm i three (in tools/, or set NODE_PATH)")


def main():
    out_dirs = [os.path.join(ROOT, "previews")] + sys.argv[1:]
    scene, extra = build()
    cols = colours()
    cols.update(extra)
    vs = []
    for name, eye, at, fov in views():
        span = max(200, 0.75 * math.dist(eye, at))
        vs.append({"name": name, "eye": eye, "at": at, "fov": fov, "span": span})
    tmp = tempfile.mkdtemp()
    scene_path = os.path.join(tmp, "scene.json")
    json.dump({"groups": scene.export(), "colours": cols, "views": vs}, open(scene_path, "w"))
    js = os.path.join(tmp, "render.js")
    open(js, "w").write(RENDER_JS)
    env = dict(os.environ)
    env["NODE_PATH"] = os.pathsep.join(filter(None, [subprocess.run(["npm", "root", "-g"], capture_output=True, text=True).stdout.strip(), env.get("NODE_PATH", "")]))
    subprocess.run(["node", js, scene_path, tmp, find_three()], check=True, env=env)
    for v in vs:
        for od in out_dirs:
            os.makedirs(od, exist_ok=True)
            shutil.copy(os.path.join(tmp, v["name"] + ".png"), os.path.join(od, v["name"] + ".png"))
    print("wrote", ", ".join(v["name"] + ".png" for v in vs))


if __name__ == "__main__":
    main()
