"""Pet and egg icons (QM, Oct 25: every pet and egg drawn once like the weapon icons, flat
and unlit with the same thick black outline). Each pet in Config.Pets
(src/shared/Animals/<Kind>Model.luau) stands in its rest pose seen three-quarters from the
front and a little above; each egg (src/shared/Eggs/<Kind>EggModel.luau) the same way.
Drawn by tools/render_weapon_icons.py's renderer and outline.

Run: python3 tools/render_pet_icons.py
     writes assets/pets/icons/<Kind>.png and assets/eggs/icons/<Kind>.png (128 x 128).

Upload them (on the Mac, through Studio):
  cd tools/studio && OUT=../../assets/pets/icons/ids.json python3 imgup.py ../../assets/pets/icons/*.png
  cd tools/studio && OUT=../../assets/eggs/icons/ids.json python3 imgup.py ../../assets/eggs/icons/*.png
then run python3 tools/item_icon_ids.py (writes src/shared/ItemIcons.luau).
"""

import glob
import json
import math
import os
import re
import subprocess
import sys
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, HERE)
import render_weapon_icons as W  # noqa: E402
from render3d import find_three  # noqa: E402
from render_sleep import entries, mesh_obj, nums, table_at  # noqa: E402

TURN = math.pi - 0.6  # faces -Z: turned to face the camera, a little to one side
PITCH = 0.35  # tipped toward the camera, so it's seen from a little above


def angles(x, y, z):
    """Roblox's CFrame.Angles(x, y, z): Rx * Ry * Rz."""
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return rx @ ry @ rz


def mat(c):
    m = np.eye(4)
    m[:3, 3] = c[:3]
    if len(c) == 12:
        m[:3, :3] = np.array(c[3:]).reshape(3, 3)
    return m


def parts(path, mesh_dir):
    """The model's parts at rest: each bone's rest rotation (about its pivot, down the
    chain, as Shared/Rig does) applied to the parts on it."""
    src = open(path).read()
    field = lambda e, key: re.search(r"\b" + key + r' = "([^"]+)"', e)
    bones = {}
    for e in entries(table_at(src, src.index("{", src.index("bones = {")))):
        pivot = nums(re.search(r"pivot = Vector3\.new\(([^)]*)\)", e).group(1))
        rest = re.search(r"rest = CFrame\.Angles\(([^)]*)\)", e)
        bones[field(e, "name").group(1)] = {
            "parent": (field(e, "parent") or [None, None])[1],
            "pivot": pivot,
            "rest": nums(rest.group(1)) if rest else None,
        }
    world = {}

    def at(name):
        if name not in world:
            b = bones[name]
            m = at(b["parent"]) if b["parent"] in bones else np.eye(4)
            if b["rest"]:
                r = np.eye(4)
                r[:3, :3] = angles(*b["rest"])
                p = np.eye(4)
                p[:3, 3] = b["pivot"]
                m = m @ p @ r @ np.linalg.inv(p)
            world[name] = m
        return world[name]

    out = []
    for e in entries(table_at(src, src.index("{", src.index("parts = {")))):
        if re.search(r"\btransparency = 1\b", e):
            continue
        mesh = field(e, "mesh")
        bone = field(e, "bone")
        m = at(bone.group(1)) @ mat(nums(re.search(r"cframe = CFrame\.new\((.*?)\)", e, re.S).group(1)))
        out.append({
            "class": (field(e, "class") or [None, "Part"])[1],
            "mesh": mesh_obj(mesh_dir, mesh.group(1)) if mesh else None,
            "size": nums(re.search(r"size = Vector3\.new\(([^)]*)\)", e).group(1)),
            "cframe": [round(v, 5) for v in list(m[:3, 3]) + list(m[:3, :3].reshape(-1))],
            "color": nums(re.search(r"color = Color3\.fromRGB\(([^)]*)\)", e).group(1)),
        })
    return out


def pet_kinds():
    src = open(os.path.join(ROOT, "src", "shared", "Config.luau")).read()
    table = table_at(src, src.index("{", src.index("\tPets = {")))
    return re.findall(r"\n\t\t(\w+) = \{", table)


def main():
    jobs = []  # (kind, out dir, model path, mesh dir)
    for kind in pet_kinds():
        path = os.path.join(ROOT, "src", "shared", "Animals", kind + "Model.luau")
        if os.path.exists(path):
            jobs.append((kind, os.path.join(ROOT, "assets", "pets", "icons"), path, kind))
    for path in sorted(glob.glob(os.path.join(ROOT, "src", "shared", "Eggs", "*EggModel.luau"))):
        kind = os.path.basename(path)[: -len("EggModel.luau")]
        jobs.append((kind, os.path.join(ROOT, "assets", "eggs", "icons"), path, kind + "Egg"))
    tmp = tempfile.mkdtemp()
    items = []
    for i, (kind, out, path, mesh_dir) in enumerate(jobs):
        items.append({"id": "%03d" % i, "parts": parts(path, mesh_dir), "tilt": 0, "turn": TURN, "pitch": PITCH})
    data_path = os.path.join(tmp, "items.json")
    json.dump({"weapons": items, "draw": W.DRAW, "tilt": 0, "turn": TURN}, open(data_path, "w"))
    js = os.path.join(tmp, "render.js")
    open(js, "w").write(W.RENDER_JS)
    env = dict(os.environ)
    env["NODE_PATH"] = os.pathsep.join(filter(None, [subprocess.run(["npm", "root", "-g"], capture_output=True, text=True).stdout.strip(), env.get("NODE_PATH", "")]))
    subprocess.run(["node", js, data_path, tmp, find_three()], check=True, env=env)
    for item, (kind, out, _, _) in zip(items, jobs):
        os.makedirs(out, exist_ok=True)
        W.outline(os.path.join(tmp, item["id"] + ".png"), os.path.join(out, kind + ".png"))
        print("wrote", os.path.relpath(os.path.join(out, kind + ".png"), ROOT))


if __name__ == "__main__":
    main()
