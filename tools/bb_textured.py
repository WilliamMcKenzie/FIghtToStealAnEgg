"""Draw a Blockbench model with its painted textures, texel by texel, the way
Blockbench shows it. Our converter gives every Roblox part one colour, so this is
the reference to hold the converted model up against.

    from bb_textured import render_textured
    im = render_textured(model, eye=(-40, 40, -60), target=(0, 15, 0))  # model units

Cubes only (with inflate and per-face UVs; face UV rotation 0 only), bones at rest.
Blockbench's rotation order (Z, then Y, then X) is used for elements and bones.
"""

import base64
import io
import math

import numpy as np
from PIL import Image, ImageDraw


def _rotm(deg):
    x, y, z = (math.radians(a) for a in deg)
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rz @ Ry @ Rx


# Each face's top-left, top-right and bottom-left corners (as (i, j, k) picks of
# from/to per axis), which its UV's (u0, v0), (u1, v0) and (u0, v1) land on.
FACE_CORNERS = {
    "north": ((1, 1, 0), (0, 1, 0), (1, 0, 0)),
    "south": ((0, 1, 1), (1, 1, 1), (0, 0, 1)),
    "east": ((1, 1, 1), (1, 1, 0), (1, 0, 1)),
    "west": ((0, 1, 0), (0, 1, 1), (0, 0, 0)),
    "up": ((0, 1, 0), (1, 1, 0), (0, 1, 1)),
    "down": ((0, 0, 1), (1, 0, 1), (0, 0, 0)),
}
NORMALS = {"north": (0, 0, -1), "south": (0, 0, 1), "east": (1, 0, 0), "west": (-1, 0, 0), "up": (0, 1, 0), "down": (0, -1, 0)}


def textures(model):
    res = model.get("resolution") or {"width": 16, "height": 16}
    out = []
    for t in model["textures"]:
        im = Image.open(io.BytesIO(base64.b64decode(t["source"].split(",", 1)[1]))).convert("RGBA")
        out.append((np.array(im), t.get("uv_width") or res["width"], t.get("uv_height") or res["height"]))
    return out


def bone_frames(model):
    """{element uuid: 4x4 bone transform at rest} for every element in the outliner."""
    out = {}

    def walk(node, M):
        if isinstance(node, str):
            out[node] = M
            return
        o = np.array(node.get("origin") or (0, 0, 0), float)
        R = _rotm(node.get("rotation") or (0, 0, 0))
        L = np.eye(4)
        L[:3, :3] = R
        L[:3, 3] = o - R @ o
        for c in node["children"]:
            walk(c, M @ L)

    for n in model["outliner"]:
        walk(n, np.eye(4))
    return out


def texel_quads(model):
    """[(4x3 corners in model units, rgb, normal)] for every painted texel."""
    texs = textures(model)
    frames = bone_frames(model)
    quads = []
    for e in model["elements"]:
        if e.get("type", "cube") != "cube" or e.get("visibility") is False or e["uuid"] not in frames:
            continue
        inf = e.get("inflate") or 0
        lo = np.array(e["from"], float) - inf
        hi = np.array(e["to"], float) + inf
        R = _rotm(e.get("rotation") or (0, 0, 0))
        o = np.array(e.get("origin") or (0, 0, 0), float)
        M = frames[e["uuid"]]

        def place(p):
            q = R @ (p - o) + o
            return M[:3, :3] @ q + M[:3, 3]

        for fname, f in e["faces"].items():
            if f.get("texture") is None:
                continue
            arr, uw, uh = texs[f["texture"]]
            H, W = arr.shape[:2]
            sx, sy = W / uw, H / uh
            pick = lambda c: np.array([(lo, hi)[c[a]][a] for a in range(3)])  # noqa: E731
            tl, tr, bl = (place(pick(c)) for c in FACE_CORNERS[fname])
            n = M[:3, :3] @ R @ np.array(NORMALS[fname], float)
            u0, v0, u1, v1 = f["uv"]
            px0, px1 = u0 * sx, u1 * sx
            py0, py1 = v0 * sy, v1 * sy
            cols = range(int(math.floor(min(px0, px1) + 1e-6)), int(math.ceil(max(px0, px1) - 1e-6)))
            rows = range(int(math.floor(min(py0, py1) + 1e-6)), int(math.ceil(max(py0, py1) - 1e-6)))
            if px0 == px1 or py0 == py1:
                continue
            for cx in cols:
                for cy in rows:
                    if not (0 <= cx < W and 0 <= cy < H) or arr[cy, cx, 3] == 0:
                        continue
                    s0, s1 = sorted(((cx - px0) / (px1 - px0), (cx + 1 - px0) / (px1 - px0)))
                    t0, t1 = sorted(((cy - py0) / (py1 - py0), (cy + 1 - py0) / (py1 - py0)))
                    s0, s1, t0, t1 = max(s0, 0), min(s1, 1), max(t0, 0), min(t1, 1)
                    P = lambda s, t: tl + s * (tr - tl) + t * (bl - tl)  # noqa: E731
                    quads.append((np.array([P(s0, t0), P(s1, t0), P(s1, t1), P(s0, t1)]), tuple(arr[cy, cx, :3]), n))
    return quads


def render_textured(model, eye, target, W=640, H=640, fov=35, bg=(235, 240, 245), ss=3):
    eye = np.array(eye, float)
    f = np.array(target, float) - eye
    f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    focal = (H * ss / 2) / math.tan(math.radians(fov) / 2)
    light = np.array([-0.4, 0.8, -0.45])
    light /= np.linalg.norm(light)
    items = []
    for q, rgb, n in texel_quads(model):
        c = q.mean(0)
        if np.dot(n, eye - c) <= 0:
            continue  # back face
        d = q - eye
        z = d @ f
        if (z <= 0.1).any():
            continue
        xs = W * ss / 2 + focal * (d @ r) / z
        ys = H * ss / 2 - focal * (d @ u) / z
        shade = 0.72 + 0.28 * max(0.0, float(np.dot(n, light)))
        items.append((float(np.linalg.norm(c - eye)), list(zip(xs, ys)), tuple(int(min(255, v * shade)) for v in rgb)))
    items.sort(key=lambda it: -it[0])
    im = Image.new("RGB", (W * ss, H * ss), bg)
    dr = ImageDraw.Draw(im)
    for _, pts, col in items:
        dr.polygon(pts, fill=col, outline=col)
    return im.resize((W, H), Image.LANCZOS)
