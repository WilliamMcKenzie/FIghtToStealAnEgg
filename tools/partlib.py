"""Tiny part-model toolkit for designing studded Roblox models outside Studio.

Build a list of parts (Block or Wedge) with 4x4 transforms, then:
  - write_rbxmx(parts, name, path)  -> a Model file you can Insert into Studio
  - render(parts, ...)              -> a PIL image preview (flat shading + studs)

Coordinates follow Roblox: Y up, models face -Z.
Roblox WedgePart geometry: full faces on Bottom (-Y) and Back (+Z); the slope
runs from the top-back edge down to the bottom-front edge, so it faces up and
forward (-Z, +Y). Left/Right faces are triangles.
"""

import math
import numpy as np
from PIL import Image

# Classic stud decal, tiled at half-stud size (same as Rig.luau).
STUD_IMAGE = "rbxassetid://7447638591"
STUD_TILE = 0.5


# ---------------------------------------------------------------- transforms

def T(x=0, y=0, z=0):
    m = np.eye(4)
    m[:3, 3] = (x, y, z)
    return m


def Rx(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    m = np.eye(4)
    m[1, 1], m[1, 2], m[2, 1], m[2, 2] = c, -s, s, c
    return m


def Ry(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    m = np.eye(4)
    m[0, 0], m[0, 2], m[2, 0], m[2, 2] = c, s, -s, c
    return m


def Rz(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    m = np.eye(4)
    m[0, 0], m[0, 1], m[1, 0], m[1, 1] = c, -s, s, c
    return m


def mirror_x(cf):
    """Mirror a transform across the X=0 plane, keeping it a proper rotation."""
    s = np.diag([-1.0, 1, 1, 1])
    m = s @ cf @ s
    return m


# ---------------------------------------------------------------- parts

class Part:
    def __init__(self, name, size, cf, color, shape="Block", plain=False):
        self.name = name
        self.size = np.array(size, float)
        self.cf = np.array(cf, float)
        self.color = color
        self.shape = shape
        self.plain = plain

    def mirrored(self, name):
        cf = mirror_x(self.cf)
        if self.shape == "Wedge":
            # A wedge's triangle sides are on +/-X, so mirroring in X keeps its shape.
            pass
        return Part(name, self.size, cf, self.color, self.shape, self.plain)


class Builder:
    def __init__(self):
        self.parts = []

    def add(self, name, size, cf, color, shape="Block", plain=False, mirror=False):
        p = Part(name, size, cf, color, shape, plain)
        if mirror:
            # name given for the left (-X) side; right is mirrored
            p.name = name + "L"
            self.parts.append(p)
            self.parts.append(p.mirrored(name + "R"))
        else:
            self.parts.append(p)
        return p

    def box(self, name, size, cf, color, **kw):
        return self.add(name, size, cf, color, "Block", **kw)

    def wedge(self, name, size, cf, color, **kw):
        return self.add(name, size, cf, color, "Wedge", **kw)


# Local-space geometry: list of faces, each face = list of vertex coords (in +-1 units)
# plus the Roblox NormalId it corresponds to.
_BOX_FACES = [
    ("Right", [(1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)]),
    ("Left", [(-1, -1, 1), (-1, 1, 1), (-1, 1, -1), (-1, -1, -1)]),
    ("Top", [(-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)]),
    ("Bottom", [(-1, -1, 1), (-1, -1, -1), (1, -1, -1), (1, -1, 1)]),
    ("Back", [(1, -1, 1), (1, 1, 1), (-1, 1, 1), (-1, -1, 1)]),
    ("Front", [(-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1)]),
]
_WEDGE_FACES = [
    ("Bottom", [(-1, -1, 1), (-1, -1, -1), (1, -1, -1), (1, -1, 1)]),
    ("Back", [(1, -1, 1), (1, 1, 1), (-1, 1, 1), (-1, -1, 1)]),
    ("Front", [(-1, -1, -1), (-1, 1, 1), (1, 1, 1), (1, -1, -1)]),  # slope
    ("Right", [(1, -1, -1), (1, 1, 1), (1, -1, 1)]),
    ("Left", [(-1, -1, 1), (-1, 1, 1), (-1, -1, -1)]),
]

# CornerWedgePart: peak over the (+X, -Z) corner of the base
_CORNER_FACES = [
    ("Bottom", [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)]),
    ("Front", [(-1, -1, -1), (1, -1, -1), (1, 1, -1)]),
    ("Right", [(1, -1, -1), (1, -1, 1), (1, 1, -1)]),
    ("SlopeBack", [(1, -1, 1), (-1, -1, 1), (1, 1, -1)]),
    ("SlopeLeft", [(-1, -1, 1), (-1, -1, -1), (1, 1, -1)]),
]


def part_faces(p):
    """World-space polygons for a part: list of (verts Nx3, normal).
    A "Poly" part carries its own polygons in p.polys (part-local coordinates)."""
    if p.shape == "Poly":
        polys = [np.array(v, float) for v in p.polys]
        center = p.cf[:3, :3] @ np.concatenate(polys).mean(0) + p.cf[:3, 3]
    else:
        half = p.size / 2
        polys = [np.array(v, float) * half for _, v in {"Wedge": _WEDGE_FACES, "CornerWedge": _CORNER_FACES}.get(p.shape, _BOX_FACES)]
        center = p.cf[:3, 3]
    out = []
    for local in polys:
        world = (p.cf[:3, :3] @ local.T).T + p.cf[:3, 3]
        n = np.cross(world[1] - world[0], world[2] - world[0])
        ln = np.linalg.norm(n)
        if ln < 1e-9:
            continue
        # make normals point outward (away from part center)
        n = n / ln
        if np.dot(n, world.mean(0) - center) < 0:
            n = -n
            world = world[::-1]  # keep vertices counter-clockwise seen from outside
        out.append((world, n))
    return out


# ---------------------------------------------------------------- rbxmx

def _xml_color(c):
    r, g, b = c
    return (255 << 24) | (r << 16) | (g << 8) | b


def write_rbxmx(parts, name, path, pivot_y=0.0):
    ref = [0]

    def nref():
        ref[0] += 1
        return f"RBX{ref[0]:08X}"

    lines = ['<roblox version="4">', f'<Item class="Model" referent="{nref()}">', "<Properties>",
             f'<string name="Name">{name}</string>', "</Properties>"]
    for p in parts:
        cls = "WedgePart" if p.shape == "Wedge" else "Part"
        R = p.cf[:3, :3]
        x, y, z = p.cf[:3, 3]
        cf = "".join(f"<{k}>{v:.5f}</{k}>" for k, v in [("X", x), ("Y", y), ("Z", z)])
        for i in range(3):
            for j in range(3):
                cf += f"<R{i}{j}>{R[i, j]:.6f}</R{i}{j}>"
        lines += [f'<Item class="{cls}" referent="{nref()}">', "<Properties>",
                  f'<string name="Name">{p.name}</string>',
                  f'<CoordinateFrame name="CFrame">{cf}</CoordinateFrame>',
                  f'<Vector3 name="size"><X>{p.size[0]:.4f}</X><Y>{p.size[1]:.4f}</Y><Z>{p.size[2]:.4f}</Z></Vector3>',
                  f'<Color3uint8 name="Color3uint8">{_xml_color(p.color)}</Color3uint8>',
                  '<token name="Material">272</token>',  # SmoothPlastic
                  '<bool name="Anchored">true</bool>',
                  '<bool name="CanCollide">false</bool>']
        for face in ("Top", "Bottom", "Front", "Back", "Left", "Right"):
            lines.append(f'<token name="{face}Surface">0</token>')
        lines.append("</Properties>")
        if not p.plain:
            for fid in range(6):
                lines += [f'<Item class="Texture" referent="{nref()}">', "<Properties>",
                          '<string name="Name">Studs</string>',
                          f'<Content name="Texture"><url>{STUD_IMAGE}</url></Content>',
                          f'<float name="StudsPerTileU">{STUD_TILE}</float>',
                          f'<float name="StudsPerTileV">{STUD_TILE}</float>',
                          f'<token name="Face">{fid}</token>',
                          "</Properties>", "</Item>"]
        lines.append("</Item>")
    lines += ["</Item>", "</roblox>"]
    with open(path, "w") as f:
        f.write("\n".join(lines))


# ---------------------------------------------------------------- render

SKY_TOP = np.array([70, 150, 245.0])
SKY_BOT = np.array([175, 215, 255.0])
GROUND = np.array([96, 196, 70.0])
GROUND2 = np.array([88, 184, 64.0])
LIGHT = np.array([-0.45, 0.8, -0.35])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def look_at(eye, target):
    eye = np.array(eye, float)
    f = np.array(target, float) - eye
    f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return eye, r, u, f


def render(parts, eye, target, W=640, H=640, fov=32, studs=True, offset=(0, 0, 0), ground=True, transparent=False, fog=True,
           outline=True):
    """Render parts with a z-buffer; returns a PIL image (RGBA with a clear
    background when transparent, which also drops the ground). outline=False skips
    the dark edge lines (Roblox draws none). Parts with .neon set are lit flat and
    bright, like Neon."""
    ground = ground and not transparent
    eye, r, u, f = look_at(eye, target)
    focal = (H / 2) / math.tan(math.radians(fov) / 2)
    off = np.array(offset, float)

    def proj(P):
        d = P - eye
        x, y, z = d @ r, d @ u, d @ f
        return np.stack([W / 2 + focal * x / z, H / 2 - focal * y / z, z], -1)

    img = np.zeros((H, W, 3))
    ys = np.linspace(0, 1, H)[:, None]
    img[:] = (SKY_TOP * (1 - ys) + SKY_BOT * ys)[:, None, :]
    zbuf = np.full((H, W), np.inf)
    shadow = np.zeros((H, W), bool)

    # ground plane: per-pixel ray cast
    if ground:
        px, py = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
        dirs = (r[None, None] * ((px - W / 2) / focal)[..., None]
                - u[None, None] * ((py - H / 2) / focal)[..., None] + f[None, None])
        t = -eye[1] / np.where(dirs[..., 1] < -1e-6, dirs[..., 1], np.nan)
        hit = np.isfinite(t) & (t > 0)
        gx = eye[0] + t * dirs[..., 0]
        gz = eye[2] + t * dirs[..., 2]
        chk = ((np.floor(gx / 4) + np.floor(gz / 4)) % 2 == 0)
        col = np.where(chk[..., None], GROUND, GROUND2)
        if fog:
            haze = np.clip((t - 30) / 120, 0, 1)[..., None]
            col = col * (1 - haze) + SKY_BOT * haze
        img[hit] = col[hit]
        zdepth = t * np.einsum("ijk,k->ij", dirs, f)
        zbuf[hit] = zdepth[hit] + 1e-3  # ground depth

    tris = []  # (screen 3x3, world 3x3, normal, color, face axes, plain)
    shadow_tris = []
    for p in parts:
        for poly, n in part_faces(p):
            poly = poly + off
            # face tangent axes for stud pattern
            if getattr(p, "stud_axes", None):  # shared axes per plane (mesh rocks: no seams)
                e1, e2 = p.stud_axes(n)
                origin = np.zeros(3)
            else:
                e1 = poly[1] - poly[0]
                e1 /= np.linalg.norm(e1)
                e2 = np.cross(n, e1)
                origin = poly[0]
            for i in range(1, len(poly) - 1):
                w3 = np.array([poly[0], poly[i], poly[i + 1]])
                tris.append((proj(w3), w3, n, np.array(p.color, float), (origin, e1, e2), 2 if getattr(p, "neon", False) else p.plain))
                # shadow: project onto y=0 along light
                s = w3 - LIGHT[None] * (w3[:, 1:2] / LIGHT[1])
                s[:, 1] = 0.01
                shadow_tris.append(proj(s))

    def raster(s):
        x0, x1 = int(max(0, np.floor(s[:, 0].min()))), int(min(W - 1, np.ceil(s[:, 0].max())))
        y0, y1 = int(max(0, np.floor(s[:, 1].min()))), int(min(H - 1, np.ceil(s[:, 1].max())))
        if x0 > x1 or y0 > y1 or (s[:, 2] <= 0.1).any():
            return None
        X, Y = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        (ax, ay), (bx, by), (cx, cy) = s[0, :2], s[1, :2], s[2, :2]
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9:
            return None
        l0 = ((by - cy) * (X - cx) + (cx - bx) * (Y - cy)) / den
        l1 = ((cy - ay) * (X - cx) + (ax - cx) * (Y - cy)) / den
        l2 = 1 - l0 - l1
        m = (l0 >= -1e-4) & (l1 >= -1e-4) & (l2 >= -1e-4)
        return x0, y0, X, Y, l0, l1, l2, m

    if ground:
        for s in shadow_tris:
            rr = raster(s)
            if rr is None:
                continue
            x0, y0, X, Y, l0, l1, l2, m = rr
            sub = shadow[y0:y0 + m.shape[0], x0:x0 + m.shape[1]]
            sub |= m
        img[shadow & np.isfinite(zbuf)] *= 0.72

    pos = np.zeros((H, W, 3))
    info = np.full((H, W), -1, int)
    for ti, (s, w3, n, color, axes, plain) in enumerate(tris):
        if np.dot(n, w3[0] - eye) >= 0:  # backface
            continue
        rr = raster(s)
        if rr is None:
            continue
        x0, y0, X, Y, l0, l1, l2, m = rr
        # perspective-correct depth
        iz = l0 / s[0, 2] + l1 / s[1, 2] + l2 / s[2, 2]
        z = 1 / iz
        zb = zbuf[y0:y0 + m.shape[0], x0:x0 + m.shape[1]]
        mm = m & (z < zb)
        if not mm.any():
            continue
        zb[mm] = z[mm]
        wp = (l0[..., None] * w3[0] / s[0, 2] + l1[..., None] * w3[1] / s[1, 2] + l2[..., None] * w3[2] / s[2, 2]) * z[..., None]
        pos[y0:y0 + m.shape[0], x0:x0 + m.shape[1]][mm] = wp[mm]
        info[y0:y0 + m.shape[0], x0:x0 + m.shape[1]][mm] = ti

    # shade
    for ti in np.unique(info[info >= 0]):
        s, w3, n, color, (o, e1, e2), plain = tris[ti]
        m = info == ti
        lam = max(0.0, float(np.dot(n, LIGHT)))
        shade = 1.2 if plain == 2 else 0.62 + 0.45 * lam
        c = np.tile(color * shade, (m.sum(), 1))
        if studs and not plain:
            d = pos[m] - o
            uu, vv = d @ e1, d @ e2
            fu = (uu / STUD_TILE) % 1 - 0.5
            fv = (vv / STUD_TILE) % 1 - 0.5
            rad = np.sqrt(fu ** 2 + fv ** 2)
            ring = (rad < 0.3) & (rad > 0.2)
            inner = rad <= 0.2
            # light rim on one side, dark on the other, like the stud decal
            side = (fu - fv)
            c[ring & (side < 0)] *= 1.12
            c[ring & (side >= 0)] *= 0.86
            c[inner] *= 1.03
        img[m] = c

    # outline: depth / face discontinuities
    edge = np.zeros((H, W), bool)
    obj = info >= 0
    for dy, dx in ((0, 1), (1, 0)):
        a = info[: H - dy, : W - dx]
        b = info[dy:, dx:]
        za = zbuf[: H - dy, : W - dx]
        zb2 = zbuf[dy:, dx:]
        oa, ob = obj[: H - dy, : W - dx], obj[dy:, dx:]
        # the gap that counts as an edge grows with distance, so far-off floors at a
        # grazing angle don't outline every pixel
        gap = np.maximum(0.35, 0.02 * np.minimum(za, zb2))
        e = (oa != ob) | ((oa & ob) & (np.abs(za - zb2) > gap))
        edge[: H - dy, : W - dx] |= e & oa
        edge[dy:, dx:] |= e & ob
    if outline:
        img[edge] *= 0.35
    else:
        edge[:] = False
    rgb = np.clip(img, 0, 255).astype(np.uint8)
    if transparent:
        alpha = ((obj | edge) * 255).astype(np.uint8)
        return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")
    return Image.fromarray(rgb)


# ---------------------------------------------------------------- Blockbench

MESH_UV3 = ((0.1, 0.1), (0.9, 0.1), (0.5, 0.9))  # mesh face UVs inside one palette pixel
MESH_UV4 = ((0.1, 0.1), (0.9, 0.1), (0.9, 0.9), (0.1, 0.9))


def write_bbmodel(parts, name, path, scale=10, bones=None):
    """Blockbench 'Generic Model' project. Axis-aligned blocks become cubes,
    wedges and rotated blocks become meshes. Colours come from a small palette
    texture, one 2x2 cell per colour. `scale` = Blockbench units per stud.
    bones: optional list of (name, parent or None, pivot in studs); each part's
    `bone` attribute picks its group. Returns (model dict, groups by name)."""
    import base64
    import io
    import json
    import uuid

    colors = []
    for p in parts:
        if p.color not in colors:
            colors.append(p.color)
    res = 16
    img = Image.new("RGBA", (res, res), (0, 0, 0, 0))
    cell = {}
    for i, c in enumerate(colors):
        cx, cy = (i % 8) * 2, (i // 8) * 2
        for dx in range(2):
            for dy in range(2):
                img.putpixel((cx + dx, cy + dy), tuple(c) + (255,))
        cell[c] = (cx + 0.5, cy + 0.5)
    buf = io.BytesIO()
    img.save(buf, "PNG")
    tex_uuid = str(uuid.uuid4())

    def uv_box(c):
        u, v = cell[c]
        return [u, v, u + 1, v + 1]

    elements = []
    for p in parts:
        R = p.cf[:3, :3]
        axis_aligned = p.shape == "Block" and np.allclose(np.abs(R), np.eye(3), atol=1e-6)
        eid = str(uuid.uuid4())
        if axis_aligned:
            half = np.abs(R) @ (p.size / 2)
            lo = (p.cf[:3, 3] - half) * scale
            hi = (p.cf[:3, 3] + half) * scale
            faces = {f: {"uv": uv_box(p.color), "texture": 0}
                     for f in ("north", "east", "south", "west", "up", "down")}
            elements.append({
                "name": p.name, "type": "cube", "uuid": eid, "box_uv": False,
                "from": [round(x, 4) for x in lo], "to": [round(x, 4) for x in hi],
                "origin": [round(x, 4) for x in p.cf[:3, 3] * scale], "rotation": [0, 0, 0],
                "autouv": 0, "color": 0, "faces": faces,
            })
        else:
            verts, faces = {}, {}
            keys = {}
            u, v = cell[p.color]
            polys = []
            for poly, _ in part_faces(p):
                # Blockbench mesh faces hold at most 4 vertices: fan the rest
                if len(poly) <= 4:
                    polys.append(poly)
                else:
                    polys += [np.array([poly[0], poly[i], poly[i + 1]]) for i in range(1, len(poly) - 1)]
            for fi, poly in enumerate(polys):
                vk = []
                for pt in poly:
                    k = tuple(np.round(pt * scale, 4))
                    if k not in keys:
                        keys[k] = f"v{len(keys)}"
                        verts[keys[k]] = [float(x) for x in k]
                    vk.append(keys[k])
                # spread over the colour's pixel (not one point) so Blockbench's paint tools can hit it
                corners = MESH_UV3 if len(vk) == 3 else MESH_UV4
                faces[f"f{fi}"] = {"uv": {k: [u + cu, v + cv] for k, (cu, cv) in zip(vk, corners)}, "vertices": vk, "texture": 0}
            elements.append({
                "name": p.name, "type": "mesh", "uuid": eid, "origin": [0, 0, 0],
                "rotation": [0, 0, 0], "color": 0, "vertices": verts, "faces": faces,
            })

    groups, outliner = {}, [e["uuid"] for e in elements]
    if bones:
        nodes = {}
        outliner = []
        for bname, parent, pivot in bones:
            g = {"name": bname, "uuid": str(uuid.uuid4()), "export": True, "locked": False, "scope": 0,
                 "visibility": True, "origin": [round(float(x) * scale, 4) for x in pivot],
                 "rotation": [0, 0, 0], "color": 0, "children": [], "reset": False, "shade": True,
                 "mirror_uv": False, "autouv": 0, "isOpen": True}
            groups[bname] = g
            nodes[bname] = {"uuid": g["uuid"], "isOpen": True, "children": []}
            (nodes[parent]["children"] if parent else outliner).append(nodes[bname])
        for p, e in zip(parts, elements):
            nodes[getattr(p, "bone", bones[0][0])]["children"].append(e["uuid"])

    model = {
        "meta": {"format_version": "4.10", "model_format": "free", "box_uv": False},
        "name": name,
        "model_identifier": "",
        "visible_box": [1, 1, 0],
        "resolution": {"width": res, "height": res},
        "elements": elements,
        "groups": list(groups.values()),
        "outliner": outliner,
        "textures": [{
            "name": "palette.png", "id": "0", "uuid": tex_uuid, "width": res, "height": res,
            "uv_width": res, "uv_height": res, "particle": False, "render_mode": "default",
            "render_sides": "auto", "frame_time": 1, "saved": False, "mode": "bitmap",
            "source": "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode(),
        }],
    }
    if path:
        with open(path, "w") as f:
            json.dump(model, f, indent=1)
    return model, groups
