"""Convert a rigged Blockbench model into a Luau data module for Rig.luau.

Run: python3 tools/bbmodel_to_luau.py designs/horses/Horse9_Leap.bbmodel src/shared/Animals/HorseModel.luau

1 Blockbench unit = 0.1 stud. Blockbench and Roblox share axes (Y up, front
= -Z) and both rotate right-handed, so rotation keyframes carry over as-is.
Cubes become Parts; six-vertex wedge meshes become WedgeParts. Other meshes
are approximated with blocks and wedges:
  one-face quads (eye plates)   thin plain Parts, stacked in the order they sit
  pyramids (a quad and a tip)   four CornerWedgeParts (see spike())
  ringed spikes (4n + 1 verts)  a block per ring-to-ring segment, then a pyramid tip
Each face picks its colour from its own texture. Group rotations become the
bone's rest rotation. Parts named in NEON glow (Enum.Material.Neon), and parts named in
METAL get the classic Weld texture instead of studs. A group whose name repeats an earlier one (QM's
wyvern has a "Head" inside its "Head") becomes its own bone, <name>_2, so bones and their
animation tracks stay one to one.

Euler order: our own tools write rotations meaning R = Rx * Ry * Rz (Roblox's
CFrame.Angles), the default here. Blockbench itself means R = Rz * Ry * Rx, which only
differs when a rotation turns about two or more axes. For a model built by hand in
Blockbench (QM's King Crab), pass --zyx so those parts come out as Blockbench shows them:
  python3 tools/bbmodel_to_luau.py --zyx designs/ocean/KingCrab.bbmodel src/shared/Animals/KingCrabModel.luau

Meshes (QM, Oct 14: a mesh only where blocks can't make the shape): with --meshes DIR, the
meshes the rules above can't make from blocks (a Garden.hull's low-poly dome) on a bone in
one colour are merged into one mesh, written to DIR/<Kind>_<Part>.obj (flat shaded, or smooth
and studless when a mesh in it is named Smooth...,
planar UVs in 0.5-stud studs, centred on its box) and listed as a MeshPart with
mesh = "<Kind>_<Part>"; Rig.luau clones it from ReplicatedStorage.AnimalMeshes.
  python3 tools/bbmodel_to_luau.py --zyx --meshes assets/meshes/ToadstoolFrog designs/garden/ToadstoolFrog.bbmodel src/shared/Animals/ToadstoolFrogModel.luau
"""

import base64
import io
import json
import math
import sys

import numpy as np
from PIL import Image

SCALE = 0.1
PLAIN = ("Eye", "Pupil", "Nostril", "Plain")  # name prefixes that skip the stud texture
NEON = ("Slit_pupil", "Glow")  # name prefixes that glow
METAL = ("Metal",)  # name prefixes drawn with the classic Weld texture instead of studs
MESHES = False  # set by --meshes
SMOOTH = ("Smooth",)  # name prefixes of meshes shaded smooth (--meshes), with no studs
SMOOTH_ANGLE = 50  # degrees: faces turning more than this keep a hard edge between them
PLATE = 0.04  # studs: thickness of a converted one-face plane
FLUTE = 0.1  # studs: thickness of a stripe on a striped block (see stripes())


def v3(v):
    return "Vector3.new({:g}, {:g}, {:g})".format(*(round(float(x), 4) + 0.0 for x in v))


def cf(pos, R):
    vals = [*pos, *R.flatten()]
    return "CFrame.new({})".format(", ".join("{:g}".format(round(float(x), 6) + 0.0) for x in vals))


ORDER = "XYZ"  # see the module docstring; main() sets "ZYX" for --zyx


def euler(deg):
    x, y, z = (math.radians(a) for a in deg)
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rz @ Ry @ Rx if ORDER == "ZYX" else Rx @ Ry @ Rz


def element_rotation(e):
    return euler(e.get("rotation") or (0, 0, 0))


def num(v):
    """Keyframe value: Blockbench stores numbers, or strings like "-\\n19.6"."""
    v = "".join(str(v).split())
    return float(v) if v else 0.0


def wedge_frame(e):
    """Center, rotation and size of a WedgePart matching a 6-vertex wedge mesh.
    Mesh vertices are relative to the element's origin (and rotation)."""
    R0, o = element_rotation(e), np.array(e.get("origin") or (0, 0, 0), float)
    verts = {k: (R0 @ np.array(v, float) + o) * SCALE for k, v in e["vertices"].items()}
    tris = [f["vertices"] for f in e["faces"].values() if len(f["vertices"]) == 3]
    assert len(tris) == 2 and len(verts) == 6, e["name"] + " is not a wedge"
    t0 = [verts[k] for k in tris[0]]
    t1 = [verts[k] for k in tris[1]]
    # right-angle corner of the first triangle
    for i in range(3):
        a, b, c = t0[i], t0[(i + 1) % 3], t0[(i + 2) % 3]
        if abs(np.dot(b - a, c - a)) < 1e-6:
            break
    else:
        raise ValueError(e["name"] + ": no right angle")
    u, w = b - a, c - a
    # Roblox wedge: corner at bottom-back, legs run up (+Y) and forward (-Z)
    Y = u / np.linalg.norm(u)
    Z = -w / np.linalg.norm(w)
    X = np.cross(Y, Z)
    other = np.mean(t1, axis=0) - np.mean(t0, axis=0)
    width = abs(np.dot(other, X))
    center = a + u / 2 + w / 2 + X * np.dot(other, X) / 2
    R = np.stack([X, Y, Z], axis=1)  # columns = right, up, back
    return center, R, (width, np.linalg.norm(u), np.linalg.norm(w))


def wedge_at(a, u, w, d):
    """WedgePart (center, rotation, size) with its right angle at a, legs u (up) and
    w (back to front reversed), extruded along d."""
    Y = u / np.linalg.norm(u)
    Z = -w / np.linalg.norm(w)
    X = np.cross(Y, Z)
    center = a + u / 2 + w / 2 + X * np.dot(d, X) / 2
    return center, np.stack([X, Y, Z], axis=1), (abs(np.dot(d, X)), np.linalg.norm(u), np.linalg.norm(w))


def prism_wedges(e):
    """A triangular prism whose triangle has no right angle (QM's beak, Oct 11), as two
    WedgeParts split along the altitude from the corner opposite the longest side."""
    verts = mesh_verts(e)
    tris = [f["vertices"] for f in e["faces"].values() if len(f["vertices"]) == 3]
    t0 = [verts[k] for k in tris[0]]
    d = np.mean([verts[k] for k in tris[1]], axis=0) - np.mean(t0, axis=0)
    i = max(range(3), key=lambda i: np.linalg.norm(t0[(i + 2) % 3] - t0[(i + 1) % 3]))
    p, b, c = t0[i], t0[(i + 1) % 3], t0[(i + 2) % 3]
    s = np.dot(p - b, c - b) / np.dot(c - b, c - b)
    f = b + s * (c - b)
    out = []
    for q in (b, c):
        if np.linalg.norm(q - f) > 1e-6:
            center, R, size = wedge_at(f, p - f, q - f, d)
            out.append(("WedgePart", center, R, size))
    return out


def mesh_verts(e):
    """Mesh vertices in model space (studs), in file order."""
    R0, o = element_rotation(e), np.array(e.get("origin") or (0, 0, 0), float)
    return {k: (R0 @ np.array(v, float) + o) * SCALE for k, v in e["vertices"].items()}


def frame(X, Y):
    """Rotation with columns right, up, back from a right (X) and up (Y) guess."""
    Y = Y / np.linalg.norm(Y)
    X = X - Y * np.dot(X, Y)
    X = X / np.linalg.norm(X)
    return np.stack([X, Y, np.cross(X, Y)], axis=1)


def extents(pts, R):
    """Size of pts along R's columns, and the center of that box."""
    local = (np.array(pts) @ R)
    lo, hi = local.min(0), local.max(0)
    return hi - lo, R @ ((lo + hi) / 2)


def plate(e, model_center):
    """A one-face quad as a thin block: its back face on the quad's plane,
    standing out on the side away from the model (so stacked plates keep order)."""
    V = np.array(list(mesh_verts(e).values()))
    c = V.mean(0)
    _, _, vt = np.linalg.svd(V - c)
    long, _, n = vt
    if np.dot(n, c - model_center) < 0:
        n = -n
    R = frame(long, np.cross(n, long))  # right = long axis, up = across, back = normal
    size, center = extents(V, R)
    # a diamond or slanted quad: keep its area, not its bounding box
    area = 0.5 * np.linalg.norm(np.cross(V[2] - V[0], V[3] - V[1]))
    size = np.array([size[0], min(size[1], area / max(size[0], 1e-6)), PLATE])
    return [("Part", center + n * PLATE / 2, R, size)]


def spike(base, apex, lean_ok=True):
    """A pyramid from four CornerWedgeParts, one per quarter of its base, each
    with its peak over the point under the apex. A CornerWedgePart's peak is at
    (+X/2, +Y/2, -Z/2). When the apex leans out past its base, the spike is
    stood straight up on a base square to the apex's axis instead (sunk a
    little so the tilt never opens a gap)."""
    b = np.mean(base, axis=0)
    _, _, vt = np.linalg.svd(np.array(base) - b)
    up = vt[2] if np.dot(vt[2], apex - b) > 0 else -vt[2]
    R = frame(base[1] - base[0], up)
    size, center = extents(base, R)
    local = R.T @ (apex - center)
    half = size / 2
    if abs(local[0]) > half[0] * 0.95 or abs(local[2]) > half[2] * 0.95:
        if not lean_ok:
            raise ValueError("a pyramid whose tip leans out past its base")
        d = apex - b
        up = d / np.linalg.norm(d)
        R = frame(base[1] - base[0], up)
        size, _ = extents(base, R)
        sink = min(0.1, 0.2 * np.linalg.norm(d))
        center = b - up * sink
        local = np.array([0.0, np.linalg.norm(d) + sink, 0.0])
        half = size / 2
    bx, bz = R[:, 0], R[:, 2]
    px, pz, h = local[0], local[2], local[1]
    out = []
    for sx, (x0, x1) in ((1, (-half[0], px)), (-1, (px, half[0]))):
        for sz, (z0, z1) in ((1, (-half[2], pz)), (-1, (pz, half[2]))):
            wx, wz = x1 - x0, z1 - z0
            if wx < 1e-4 or wz < 1e-4:
                continue
            c = center + bx * (x0 + x1) / 2 + bz * (z0 + z1) / 2 + up * h / 2
            # peak on the side toward the apex: +x for the quarter left of it (sx = 1)
            if sx == -sz:
                Rw, sz3 = np.stack([sx * bx, up, -sz * bz], axis=1), (wx, h, wz)
            else:
                Rw, sz3 = np.stack([sz * bz, up, -sx * bx], axis=1), (wz, h, wx)
            out.append(("CornerWedgePart", c, Rw, np.array(sz3)))
    return out


def pyramid(e):
    V = mesh_verts(e)
    quad = next(f["vertices"] for f in e["faces"].values() if len(f["vertices"]) == 4)
    apex = next(v for k, v in V.items() if k not in quad)
    # (a tip leaning out past its base, QM's dragged-vertex mane spikes, Oct 15: a mesh with
    # --meshes, as stood-up wedges lose the lean)
    return spike(order_quad([V[k] for k in quad]), apex, lean_ok=not MESHES)


def order_quad(pts):
    """Quad corners in order round the edge (Blockbench faces can list them crossed)."""
    c = np.mean(pts, axis=0)
    _, _, vt = np.linalg.svd(np.array(pts) - c)
    a = [np.arctan2(np.dot(p - c, vt[1]), np.dot(p - c, vt[0])) for p in pts]
    return [pts[i] for i in np.argsort(a)]


def ringed(e):
    """Rings of four vertices (in file order) and a tip: a block per segment
    between rings, a pyramid from the last ring to the tip."""
    V = list(mesh_verts(e).values())
    rings = [order_quad(V[i:i + 4]) for i in range(0, len(V) - 1, 4)]
    out = []
    for r0, r1 in zip(rings, rings[1:]):
        c0, c1 = np.mean(r0, axis=0), np.mean(r1, axis=0)
        R = frame(r0[1] - r0[0], c1 - c0)
        s0, _ = extents(r0, R)
        s1, _ = extents(r1, R)
        L = np.linalg.norm(c1 - c0)
        grow = 0.35 * (s0[0] + s0[2]) / 2  # overlap at the bends
        size = np.array([(s0[0] + s1[0]) / 2, L + grow, (s0[2] + s1[2]) / 2])
        out.append(("Part", (c0 + c1) / 2, R, size))
    out += spike(rings[-1], V[-1])
    return out


def mesh_parts(e, model_center):
    faces = [len(f["vertices"]) for f in e["faces"].values()]
    n = len(e["vertices"])
    if n == 4 and faces == [4]:
        return plate(e, model_center)
    if n == 6 and sorted(faces) == [3, 3, 4, 4, 4]:
        try:
            center, R, size = wedge_frame(e)
        except ValueError:
            return prism_wedges(e)  # a triangle with no right angle: two wedges back to back
        return [("WedgePart", center, R, size)]
    if n == 5 and sorted(faces) == [3, 3, 3, 3, 4]:
        return pyramid(e)
    if n % 4 == 1 and faces.count(3) == 4:
        return ringed(e)
    if n == 8 and faces == [4] * 6:  # a turned box (e.g. on an octo egg's slanted face)
        V = mesh_verts(e)
        q = order_quad([V[k] for k in next(iter(e["faces"].values()))["vertices"]])
        R = frame(q[1] - q[0], q[3] - q[0])
        size, center = extents(list(V.values()), R)
        # (only a true box: a tapered one, QM's dragged-vertex Treant trunk, Oct 15, would come
        # out as its whole bounding box, burying what's on its face; with --meshes it's a mesh)
        if MESHES:
            for v in V.values():
                local = np.abs(R.T @ (v - center))
                if np.any(np.abs(local - size / 2) > 0.02 * max(size.max(), 1e-6)):
                    raise ValueError(f"{e['name']}: an 8-vertex mesh that isn't a box")
        return [("Part", center, R, size)]
    raise ValueError(f"{e['name']}: mesh with {n} vertices and faces {faces} isn't supported")


def supported(e, model_center):
    """Whether mesh_parts() makes this mesh from blocks and wedges."""
    try:
        mesh_parts(e, model_center)
        return True
    except ValueError:
        return False


def element_tris(e):
    """An element's faces as outward triangles in model space (studs)."""
    if e["type"] == "cube":
        lo, hi = np.array(e["from"]) * SCALE, np.array(e["to"]) * SCALE
        R = element_rotation(e)
        o = np.array(e.get("origin") or (0, 0, 0), float) * SCALE
        c = lambda i, j, k: R @ (np.array([(lo[0], hi[0])[i], (lo[1], hi[1])[j], (lo[2], hi[2])[k]]) - o) + o  # noqa: E731
        polys = [[c(1, 0, 0), c(1, 1, 0), c(1, 1, 1), c(1, 0, 1)], [c(0, 0, 0), c(0, 1, 0), c(0, 1, 1), c(0, 0, 1)],
                 [c(0, 1, 0), c(1, 1, 0), c(1, 1, 1), c(0, 1, 1)], [c(0, 0, 0), c(1, 0, 0), c(1, 0, 1), c(0, 0, 1)],
                 [c(0, 0, 1), c(1, 0, 1), c(1, 1, 1), c(0, 1, 1)], [c(0, 0, 0), c(1, 0, 0), c(1, 1, 0), c(0, 1, 0)]]
    else:
        V = mesh_verts(e)
        polys = [[V[k] for k in f["vertices"]] for f in e["faces"].values()]
        polys = [order_quad(q) if len(q) == 4 else q for q in polys]
    centre = np.mean([v for q in polys for v in q], axis=0)  # (elements are convex)
    tris = []
    for q in polys:
        for t in range(1, len(q) - 1):
            tri = np.array([q[0], q[t], q[t + 1]])
            n = np.cross(tri[1] - tri[0], tri[2] - tri[0])
            if np.linalg.norm(n) < 1e-9:
                continue
            tris.append(tri if np.dot(n, tri.mean(0) - centre) > 0 else tri[::-1])
    return tris


STUD = 0.5  # studs: a mesh's UVs are in these (the animals' StudsHalf studs)


def stud_axes(n):
    """Fixed in-plane axes for a face normal, so the studs run on across a plane's triangles."""
    ref = np.array([0.0, 1.0, 0.0]) if abs(n[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
    e1 = np.cross(ref, n)
    e1 /= np.linalg.norm(e1)
    return e1, np.cross(n, e1)


def write_obj(name, tris, centre, path, smooth=False):
    """One OBJ, vertices relative to `centre`, every face with its own normal (flat shading); with
    smooth, each corner takes the area-weighted mean of the faces round that point that turn less
    than SMOOTH_ANGLE from its own (smooth shading that keeps sharp rims)."""
    lines, vt, vn, faces = [f"# {name}: studs, y up, facing -z, centred on its box", f"o {name}"], [], [], []
    N = [np.cross(t[1] - t[0], t[2] - t[0]) for t in tris]  # length = twice the area
    near = {}
    if smooth:
        for k, t in enumerate(tris):
            for v in t:
                near.setdefault(tuple(np.round(v, 4)), []).append(k)
    for k, t in enumerate(tris):
        n = N[k] / np.linalg.norm(N[k])
        e1, e2 = stud_axes(n)
        for v in t:
            lines.append("v %.4f %.4f %.4f" % tuple(v - centre))
            vt.append("vt %.4f %.4f" % (v @ e1 / STUD, v @ e2 / STUD))
            m = n
            if smooth:
                m = sum(N[j] for j in near[tuple(np.round(v, 4))] if N[j] @ n > math.cos(math.radians(SMOOTH_ANGLE)) * np.linalg.norm(N[j]))
                m = m / np.linalg.norm(m)
            vn.append("vn %.4f %.4f %.4f" % tuple(m))
        a = 3 * k
        faces.append("f {0}/{0}/{0} {1}/{1}/{1} {2}/{2}/{2}".format(a + 1, a + 2, a + 3))
    with open(path, "w") as f:
        f.write("\n".join(lines + vt + vn + faces) + "\n")


def bone_names(model):
    """Group uuid -> bone name, in outliner order; a repeated name gets _2, _3, ..."""
    groups = {g["uuid"]: g for g in model["groups"]}
    names, seen = {}, {}

    def walk(node):
        if isinstance(node, str):
            return
        name = groups[node["uuid"]]["name"]
        seen[name] = seen.get(name, 0) + 1
        names[node["uuid"]] = name if seen[name] == 1 else f"{name}_{seen[name]}"
        for c in node["children"]:
            walk(c)

    for node in model["outliner"]:
        walk(node)
    return names


def convert(model, merge=None):
    """(bones, parts) of a loaded .bbmodel: bones are (name, parent, pivot, rest
    rotation in degrees), parts (name, bone, class, size, center, rotation, rgb,
    plain, neon, metal) in model space at rest (before bone rest rotations).
    merge (a dict): meshes that blocks can't make go into merge[(bone, colour name)] =
    (rgb, triangles) instead, for main() to make into MeshParts."""
    names = bone_names(model)
    res = model.get("resolution") or {"width": 16, "height": 16}
    texs = []
    for t in model["textures"]:
        im = Image.open(io.BytesIO(base64.b64decode(t["source"].split(",", 1)[1]))).convert("RGB")
        texs.append((im, im.width / (t.get("uv_width") or res["width"]), im.height / (t.get("uv_height") or res["height"])))
    groups = {g["uuid"]: g for g in model["groups"]}
    elements = {e["uuid"]: e for e in model["elements"]}
    cubes = [e for e in model["elements"] if e["type"] == "cube"]
    model_center = np.mean([(np.array(e["from"]) + e["to"]) / 2 for e in cubes], axis=0) * SCALE if cubes else np.zeros(3)

    def color(e):
        """The element's colour: its front face (or first textured face) at that face's UV."""
        faces = e["faces"]
        face = faces.get("north") if faces.get("north", {}).get("texture") is not None else None
        face = face or next((f for f in faces.values() if f.get("texture") is not None), None)
        if face is None:
            return 255, 255, 255  # untextured: Blockbench shows it white
        im, sx, sy = texs[face["texture"]]
        uv = face["uv"]
        if isinstance(uv, list) and len(uv) >= 4:
            # the middle of the face's UV, not its corner (QM's Ivory Spider: a pupil's
            # corner pixel was the black outline, so it came out black)
            u, v = (uv[0] + uv[2]) / 2, (uv[1] + uv[3]) / 2
        else:
            u, v = uv[:2] if isinstance(uv, list) else next(iter(uv.values()))
        return im.getpixel((min(int(u * sx), im.width - 1), min(int(v * sy), im.height - 1)))

    def stripes(e):
        """Vertical stripes on an unrotated cube's front face (QM's fluted podium column):
        [(from, to, rgb)] across the face as fractions of its width, or None if it's one colour."""
        face = e["faces"].get("north") or {}
        if face.get("texture") is None or any(e.get("rotation") or (0, 0, 0)):
            return None
        im, sx, sy = texs[face["texture"]]
        u0, v0, u1, v1 = face["uv"]
        xs = range(int(min(u0, u1) * sx), int(max(u0, u1) * sx))
        rows = {int(v * sy) for v in (min(v0, v1) + 0.25, (v0 + v1) / 2, max(v0, v1) - 0.25)}
        lines = [[im.getpixel((min(x, im.width - 1), min(y, im.height - 1))) for x in xs] for y in rows]
        if len(xs) < 2 or any(line != lines[0] for line in lines) or len(set(lines[0])) < 2:
            return None
        runs, start = [], 0
        for i in range(1, len(xs) + 1):
            if i == len(xs) or lines[0][i] != lines[0][start]:
                runs.append((start / len(xs), i / len(xs), lines[0][start]))
                start = i
        return runs

    bones, parts = [], []

    def walk(node, parent):
        if isinstance(node, str):
            e = elements[node]
            if e.get("visibility") is False:
                return
            neon = e["name"].startswith(NEON)
            metal = e["name"].startswith(METAL)
            if merge is not None and e["type"] == "mesh" and not supported(e, model_center):
                face = next(f for f in e["faces"].values() if f.get("texture") is not None)
                key = (parent, model["textures"][face["texture"]]["name"])
                entry = merge.setdefault(key, (color(e), [], [False, False]))
                entry[1].extend(element_tris(e))
                entry[2][0] |= e["name"].startswith(SMOOTH)
                entry[2][1] |= neon
                return
            if e["type"] == "cube":
                lo, hi = np.array(e["from"]) * SCALE, np.array(e["to"]) * SCALE
                R = element_rotation(e)
                o = np.array(e.get("origin") or (0, 0, 0), float) * SCALE
                pieces = [("Part", R @ ((lo + hi) / 2 - o) + o, R, hi - lo)]
            else:
                pieces = mesh_parts(e, model_center)
            rgb = color(e)
            # plates, and the sloped faces of spikes, skip the studs
            flat = e["type"] == "mesh" and len(e["vertices"]) in (4, 5)
            plain = e["name"].startswith(PLAIN) or "In" in e["name"] or neon or flat
            for i, (cls, center, R, size) in enumerate(pieces):
                name = e["name"] if i == 0 else f"{e['name']}_{i + 1}"
                parts.append((name, parent, cls, size, center, R, rgb, plain, neon, metal))
            runs = stripes(e) if e["type"] == "cube" else None
            if runs:
                # the block in its first stripe's colour, and each other stripe as a strip
                # FLUTE thick, half sunk into each of its four sides, the full height
                parts[-1] = parts[-1][:6] + (runs[0][2],) + parts[-1][7:]
                n = 0
                for a, b, c in runs:
                    if c == runs[0][2]:
                        continue
                    for axis, other in ((0, 2), (2, 0)):  # along x on the front and back, along z on the sides
                        for side in (lo[other], hi[other]):
                            size = np.array(hi - lo, float)
                            size[axis] *= b - a
                            size[other] = FLUTE
                            center = (lo + hi) / 2
                            center[axis] = lo[axis] + (hi[axis] - lo[axis]) * (a + b) / 2
                            center[other] = side
                            n += 1
                            parts.append((f"{e['name']}_flute{n}", parent, "Part", size, center, np.eye(3), c, plain, neon, metal))
            return
        g = groups[node["uuid"]]
        name = names[g["uuid"]]
        bones.append((name, parent, np.array(g["origin"]) * SCALE, g.get("rotation") or [0, 0, 0]))
        for c in node["children"]:
            walk(c, name)

    for node in model["outliner"]:
        walk(node, None)
    return bones, parts


def main(src, dst, mesh_dir=None):
    model = json.load(open(src))
    merge = {} if mesh_dir else None
    bones, parts = convert(model, merge)
    names = bone_names(model)
    meshes = {}
    if merge:
        import os
        os.makedirs(mesh_dir, exist_ok=True)
        kind = os.path.basename(dst).replace("Model.luau", "")
        for (bone, col), (rgb, tris, smooth) in merge.items():
            name = col[:1].upper() + col[1:] + "_" + bone
            P = np.concatenate(tris)
            lo, hi = P.min(0), P.max(0)
            centre = (lo + hi) / 2
            meshes[name] = f"{kind}_{name}"
            write_obj(meshes[name], tris, centre, os.path.join(mesh_dir, meshes[name] + ".obj"), smooth[0])
            parts.append((name, bone, "MeshPart", hi - lo, centre, np.eye(3), rgb, smooth[0] or smooth[1], smooth[1], False))  # smooth or Glow: no studs
            print(f"  {meshes[name]}: {len(tris)} tris")

    out = ["-- GENERATED by tools/bbmodel_to_luau.py from " + src + ". Don't edit by hand:",
           "-- change the .bbmodel in Blockbench and regenerate.",
           "-- Units are studs, rest pose, hooves on Y = 0, facing -Z.",
           "",
           "return {",
           "\tbones = {"]
    for name, parent, pivot, rot in bones:
        p = f'"{parent}"' if parent else "nil"
        rest = ""
        if any(rot) and ORDER == "ZYX" and sum(1 for a in rot if a) > 1:
            rest = ", rest = " + cf((0, 0, 0), euler(rot))
        elif any(rot):
            rest = ", rest = CFrame.Angles({:g}, {:g}, {:g})".format(*(round(math.radians(a), 6) + 0.0 for a in rot))
        out.append(f'\t\t{{ name = "{name}", parent = {p}, pivot = {v3(pivot)}{rest} }},')
    out.append("\t},")
    out.append("\tparts = {")
    for name, bone, cls, size, center, R, (r, g, b), plain, neon, metal in parts:
        extra = (", plain = true" if plain else "") + (", neon = true" if neon else "") + (", metal = true" if metal else "")
        mesh = f', mesh = "{meshes[name]}"' if cls == "MeshPart" else ""
        out.append(f'\t\t{{ name = "{name}", bone = "{bone}", class = "{cls}"{mesh}, size = {v3(size)}, '
                   f"cframe = {cf(center, R)}, color = Color3.fromRGB({r}, {g}, {b}){extra} }},")
    out.append("\t},")
    out.append("\t-- keys: { time, x, y, z }; rotation in radians, position in studs, scale as a factor")
    out.append("\tanimations = {")
    for anim in model.get("animations", []):
        out.append(f'\t\t{anim["name"]} = {{')
        out.append(f'\t\t\tlength = {anim["length"]:g},')
        out.append("\t\t\ttracks = {")
        for uid, a in anim["animators"].items():
            if not a.get("keyframes"):
                continue
            chans = {}
            for k in sorted(a["keyframes"], key=lambda k: k["time"]):
                chans.setdefault(k["channel"], []).append(k)
            out.append(f'\t\t\t\t{names.get(uid, a["name"])} = {{')
            for ch, kfs in chans.items():
                f = {"rotation": lambda x: math.radians(float(x)),
                     "position": lambda x: float(x) * SCALE}.get(ch, float)  # scale stays a factor
                interp = kfs[0]["interpolation"]
                keys = ", ".join("{{ {:g}, {:g}, {:g}, {:g} }}".format(
                    k["time"], *(round(f(num(k["data_points"][0][c])), 5) + 0.0 for c in "xyz")) for k in kfs)
                out.append(f'\t\t\t\t\t{ch} = {{ smooth = {"true" if interp == "catmullrom" else "false"}, keys = {{ {keys} }} }},')
            out.append("\t\t\t\t},")
        out.append("\t\t\t},")
        out.append("\t\t},")
    out.append("\t},")
    out.append("}")
    open(dst, "w").write("\n".join(out) + "\n")
    print(len(bones), "bones,", len(parts), "parts,", len(model.get("animations", [])), "animations")


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--zyx" in args:
        args.remove("--zyx")
        ORDER = "ZYX"
    mesh_dir = None
    if "--meshes" in args:
        i = args.index("--meshes")
        mesh_dir = args.pop(i + 1)
        args.pop(i)
        MESHES = True
    main(*args, mesh_dir=mesh_dir)
