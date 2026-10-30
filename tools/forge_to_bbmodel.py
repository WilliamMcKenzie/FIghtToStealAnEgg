"""Writes a boss made in Python (tools/boss_designs.py) out as a Blockbench .bbmodel, so it
can be opened and looked at or tweaked in Blockbench (QM, Oct 30: "send blizard owl bbmodel").

  python3 tools/forge_to_bbmodel.py BlizzardOwl [out.bbmodel]   # default designs/bosses/<Name>.bbmodel

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


def bbmodel(m):
    colors, textures, elements = {}, [], []
    for p in m.parts:
        rgb = tuple(int(c) for c in p["color"])
        if rgb not in colors:
            colors[rgb] = len(textures)
            textures.append(texture(rgb, len(textures)))
        elements.append((p["bone"], element(p, colors[rgb])))

    groups, nodes = [], {}
    for name, parent, pivot in m.bones:
        g = {"name": name, "uuid": uid(), "origin": [round(v * UNIT, 4) + 0.0 for v in pivot], "rotation": [0, 0, 0],
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

    name = sys.argv[1]
    m = next(m for m in boss_designs.models() if m.name == name)
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "designs", "bosses", name + ".bbmodel")
    json.dump(bbmodel(m), open(out, "w"), indent=1)
    print("wrote", out, "-", len(m.bones), "bones,", len(m.parts), "blocks,", len(m.anims), "animations")
