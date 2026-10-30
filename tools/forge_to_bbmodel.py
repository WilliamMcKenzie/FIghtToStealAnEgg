"""Writes a boss made in Python (tools/boss_designs.py) out as a Blockbench .bbmodel, so it
can be opened and looked at or tweaked in Blockbench (QM, Oct 30: "send blizard owl bbmodel").

  python3 tools/forge_to_bbmodel.py BlizzardOwl [out.bbmodel]   # default designs/bosses/<Name>.bbmodel
  python3 tools/forge_to_bbmodel.py CastleWyvern                # any other boss too, from its Model.luau

Blocks become cubes, wedges six-vertex wedge meshes, corner wedges five-vertex pyramids
(the shapes tools/bbmodel_to_luau.py reads back), one flat texture per colour. Bones become
groups and every animation comes along (its hit mark too, as an extra "hit" field Blockbench
keeps no use for). Blockbench turns cubes Z, then Y, then X, so their rotations are rewritten
in that order and it shows them as the game does. Animation keys stay as they are, the way
tools/bbmodel_to_luau.py reads them (a key turning about two axes at once, like the owl's
wing beats, looks a little different in Blockbench than in game). Read it back with --zyx:
  python3 tools/bbmodel_to_luau.py --zyx designs/bosses/BlizzardOwl.bbmodel src/shared/Animals/BlizzardOwlModel.luau
"""

import base64
import io
import json
import math
import os
import re
import sys
import uuid

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from boss_forge import ROOT, rot  # noqa: E402

UNIT = 10  # Blockbench units per stud


def uid():
    return str(uuid.uuid4())


def zyx(R):
    """Degrees (x, y, z) with R = Rz * Ry * Rx, Blockbench's order."""
    R = np.array(R)
    y = math.asin(max(-1, min(1, -R[2][0])))
    if abs(R[2][0]) < 0.99999:
        x = math.atan2(R[2][1], R[2][2])
        z = math.atan2(R[1][0], R[0][0])
    else:
        x, z = math.atan2(-R[1][2], R[1][1]), 0
    return [round(math.degrees(a), 4) + 0.0 for a in (x, y, z)]


def texture(rgb, i):
    buf = io.BytesIO()
    Image.new("RGB", (16, 16), tuple(int(c) for c in rgb)).save(buf, "PNG")
    return {"name": "#%02x%02x%02x" % tuple(int(c) for c in rgb), "id": str(i), "width": 16, "height": 16,
            "uv_width": 16, "uv_height": 16, "render_mode": "default", "visible": True, "internal": True,
            "saved": False, "uuid": uid(), "source": "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()}


def mesh(p, tex, verts, faces):
    """A mesh element: verts (studs, model space) placed round the part's centre."""
    c = np.array(p["at"])
    vs = {"v%d" % i: [round(float(x), 4) + 0.0 for x in (np.array(v) - c) * UNIT] for i, v in enumerate(verts)}
    return {"name": p["name"], "type": "mesh", "uuid": uid(), "origin": [round(float(x), 4) + 0.0 for x in c * UNIT],
            "rotation": [0, 0, 0], "export": True, "visibility": True, "locked": False, "shading": "flat",
            "vertices": vs, "faces": {"f%d" % i: {"vertices": ["v%d" % k for k in f], "texture": tex,
                                                  "uv": {"v%d" % k: [8, 8] for k in f}} for i, f in enumerate(faces)}}


def element(p, tex):
    if "cf" in p:  # a part read back from a Model.luau (tools/boss_luau.py)
        R = np.array(p["cf"][3:]).reshape(3, 3)
        c = np.array(p["cf"][:3])
    else:
        R = np.array(rot(*p["r"]))
        c = np.array(p["at"])
    sx, sy, sz = (s / 2 for s in p["size"])

    def at(x, y, z):
        return c + R @ np.array([x, y, z])

    if p["class"] == "WedgePart":
        # Roblox's wedge: full bottom and back (+Z), its slope up from the front bottom edge
        v = [at(-sx, -sy, sz), at(-sx, sy, sz), at(-sx, -sy, -sz), at(sx, -sy, sz), at(sx, sy, sz), at(sx, -sy, -sz)]
        return mesh(p, tex, v, [(0, 1, 2), (3, 5, 4), (0, 2, 5, 3), (0, 3, 4, 1), (1, 4, 5, 2)])
    if p["class"] == "CornerWedgePart":
        # its peak over the (+X, -Z) corner of the top
        v = [at(-sx, -sy, -sz), at(sx, -sy, -sz), at(sx, -sy, sz), at(-sx, -sy, sz), at(sx, sy, -sz)]
        return mesh(p, tex, v, [(0, 1, 2, 3), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)])
    lo = (c - np.array([sx, sy, sz])) * UNIT
    hi = (c + np.array([sx, sy, sz])) * UNIT
    face = {"uv": [0, 0, 16, 16], "texture": tex}
    return {"name": p["name"], "type": "cube", "uuid": uid(), "box_uv": False, "export": True, "visibility": True,
            "locked": False, "from": [round(float(x), 4) + 0.0 for x in lo], "to": [round(float(x), 4) + 0.0 for x in hi],
            "origin": [round(float(x), 4) + 0.0 for x in c * UNIT], "rotation": zyx(R),
            "faces": {s: dict(face) for s in ("north", "east", "south", "west", "up", "down")}}


def corner_points(p):
    R = np.array(p["cf"][3:]).reshape(3, 3) if "cf" in p else np.array(rot(*p["r"]))
    c = np.array(p["cf"][:3] if "cf" in p else p["at"])
    sx, sy, sz = (s / 2 for s in p["size"])
    return [c + R @ np.array(v) for v in ((-sx, -sy, -sz), (sx, -sy, -sz), (sx, -sy, sz), (-sx, -sy, sz), (sx, sy, -sz))]


def pyramid(parts):
    """A spike that tools/bbmodel_to_luau.py split into four CornerWedgeParts (a pyramid's four
    quarters), put back together: its five corners, base first in order round, then the tip."""
    pts = np.concatenate([corner_points(p) for p in parts])
    centre = pts.mean(0)
    apex = max(pts, key=lambda v: np.linalg.norm(v - centre))
    far = [v for v in pts if np.linalg.norm(v - apex) > 1e-4]
    # the base: the points furthest from the tip, its corners the four furthest from their middle
    d = max(np.linalg.norm(v - apex) for v in far)
    n = apex - np.mean(far, 0)
    n /= np.linalg.norm(n)
    base = [v for v in far if abs(np.dot(apex - v, n) - max(np.dot(apex - w, n) for w in far)) < 1e-3]
    mid = np.mean(base, 0)
    corners = []
    for v in sorted(base, key=lambda v: -np.linalg.norm(v - mid)):
        if all(np.linalg.norm(v - w) > 1e-3 for w in corners):
            corners.append(v)
        if len(corners) == 4:
            break
    if len(corners) < 4 or d <= 0:
        return None
    u = corners[0] - mid
    w = np.cross(n, u)
    corners.sort(key=lambda v: math.atan2(np.dot(v - mid, w), np.dot(v - mid, u)))
    return corners + [apex]


def bbmodel(m):
    colors, textures, elements = {}, [], []

    def tex(p):
        rgb = tuple(int(c) for c in p["color"])
        if rgb not in colors:
            colors[rgb] = len(textures)
            textures.append(texture(rgb, len(textures)))
        return colors[rgb]

    # spikes split into quarters go back in as one pyramid each (as they were drawn in Blockbench)
    quarters = {}
    for p in m.parts:
        if p["class"] == "CornerWedgePart":
            quarters.setdefault((p["bone"], re.sub(r"_\d+$", "", p["name"]), tuple(p["color"])), []).append(p)
    merged = {}
    for key, ps in quarters.items():
        v = pyramid(ps) if len(ps) == 4 else None
        if v is not None:
            q = dict(ps[0], name=key[1], at=tuple(np.mean(v[:4], 0)))
            q.pop("cf", None)
            merged[id(ps[0])] = mesh(q, tex(q), v, [(0, 1, 2, 3), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)])
            for p in ps[1:]:
                merged[id(p)] = None
    for p in m.parts:
        if id(p) in merged:
            if merged[id(p)] is not None:
                elements.append((p["bone"], merged[id(p)]))
            continue
        elements.append((p["bone"], element(p, tex(p))))

    groups, nodes = [], {}
    rests = getattr(m, "rests", {})
    for name, parent, pivot in m.bones:
        rest = [math.degrees(a) for a in rests.get(name, (0, 0, 0))]
        g = {"name": name, "uuid": uid(), "origin": [round(v * UNIT, 4) + 0.0 for v in pivot],
             "rotation": zyx(rot(*rest)) if any(rest) else [0, 0, 0],
             "export": True, "visibility": True, "locked": False, "isOpen": True, "color": 0}
        groups.append(g)
        nodes[name] = {"uuid": g["uuid"], "isOpen": True, "children": []}
    for bone, e in elements:
        nodes[bone]["children"].append(e["uuid"])
    outliner = []
    for name, parent, _ in m.bones:
        (nodes[parent]["children"] if parent else outliner).append(nodes[name])

    ids = {g["name"]: g["uuid"] for g in groups}
    animations = []
    for an, a in m.anims.items():
        animators = {}
        for bone, tr in a["tracks"].items():
            kfs = []
            for key, channel in (("r", "rotation"), ("p", "position")):
                for t, x, y, z in tr.get(key, []):
                    v = [round(c * (1 if key == "r" else UNIT), 4) + 0.0 for c in (x, y, z)]
                    kfs.append({"channel": channel, "data_points": [{"x": str(v[0]), "y": str(v[1]), "z": str(v[2])}],
                                "uuid": uid(), "time": round(t, 4), "color": -1, "interpolation": "catmullrom"})
            animators[ids[bone]] = {"name": bone, "type": "bone", "rotation_global": False, "keyframes": kfs}
        entry = {"uuid": uid(), "name": an, "loop": "loop" if an in ("idle", "walk", "gallop") else "once",
                 "override": False, "length": a["length"], "snapping": 24, "animators": animators}
        if a["hit"] is not None:
            entry["hit"] = a["hit"]
        animations.append(entry)

    return {"meta": {"format_version": "4.10", "model_format": "free", "box_uv": False}, "name": m.name,
            "model_identifier": "", "resolution": {"width": 16, "height": 16}, "elements": [e for _, e in elements],
            "groups": groups, "outliner": outliner, "textures": textures, "animations": animations}


if __name__ == "__main__":
    import boss_designs
    import boss_luau

    name = sys.argv[1]
    # a boss made in Python, or any other model by its Model.luau (the Lasso recolours, tools/boss_recolors.py)
    m = next((m for m in boss_designs.models() if m.name == name), None) or boss_luau.load(name)
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "designs", "bosses", name + ".bbmodel")
    json.dump(bbmodel(m), open(out, "w"), indent=1)
    print("wrote", out, "-", len(m.bones), "bones,", len(m.parts), "blocks,", len(m.anims), "animations")
