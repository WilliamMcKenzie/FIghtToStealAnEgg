"""Model data for pets and eggs as Python, read from and written back to the Luau model
files (src/shared/Animals/<Kind>Model.luau, src/shared/Eggs/<Kind>EggModel.luau).

The later biomes' pets (tools/later_pets.py) are built with it: an existing pet recoloured
and tweaked (like QM's Sandworm -> Rockworm), or a new one put together from boxes and
wedges with its own idle, walk and gallop.

Part: { name, bone, class, size (x, y, z), cf (x, y, z, r00..r22), color (r, g, b),
        flags: plain / neon / hidden }
Wedges are Roblox's: full bottom and back (+Z) faces, the slope rising from the front
bottom edge to the back top edge.
"""

import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, HERE)
from render_sleep import entries, nums, table_at  # noqa: E402

ANIMALS = os.path.join(ROOT, "src", "shared", "Animals")
EGGS = os.path.join(ROOT, "src", "shared", "Eggs")


def fmt(v):
    v = round(float(v), 5)
    if v == 0:
        v = 0.0
    s = ("%.5f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def angles(x, y, z):
    """Roblox's CFrame.Angles(x, y, z) (radians) as a row-major 3x3: Rx * Ry * Rz."""
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    return mul(mul(rx, ry), rz)


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def deg(x=0, y=0, z=0):
    return angles(math.radians(x), math.radians(y), math.radians(z))


IDENT = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


class Model:
    def __init__(self, bones, parts, animations):
        self.bones = bones  # [{name, parent, pivot, rest(text or None)}]
        self.parts = parts
        self.animations = animations  # Luau text "animations = { ... }" (no trailing comma)

    # ---- reading -----------------------------------------------------------------------
    @classmethod
    def load(cls, path, meshes=False):
        """meshes: True drops any MeshPart (otherwise it's an error: they can't be recoloured
        or reshaped here, and the game draws pets from blocks)."""
        if not os.path.isabs(path):
            path = os.path.join(ANIMALS, path + "Model.luau")
        src = open(path).read()
        bones = []
        for e in entries(table_at(src, src.index("{", src.index("bones = {")))):
            rest = re.search(r"rest = (CFrame\.Angles\([^)]*\))", e)
            parent = re.search(r'parent = "([^"]+)"', e)
            bones.append({
                "name": re.search(r'name = "([^"]+)"', e).group(1),
                "parent": parent.group(1) if parent else None,
                "pivot": nums(re.search(r"pivot = Vector3\.new\(([^)]*)\)", e).group(1)),
                "rest": rest.group(1) if rest else None,
            })
        parts = []
        for e in entries(table_at(src, src.index("{", src.index("parts = {")))):
            p = {
                "name": re.search(r'name = "([^"]+)"', e).group(1),
                "bone": re.search(r'bone = "([^"]+)"', e).group(1),
                "class": re.search(r'class = "([^"]+)"', e).group(1),
                "size": nums(re.search(r"size = Vector3\.new\(([^)]*)\)", e).group(1)),
                "cf": nums(re.search(r"cframe = CFrame\.new\((.*?)\)", e, re.S).group(1)),
                "color": [int(v) for v in nums(re.search(r"color = Color3\.fromRGB\(([^)]*)\)", e).group(1))],
            }
            for flag in ("plain", "neon", "hidden"):
                if re.search(r"\b" + flag + r" = true", e):
                    p[flag] = True
            if re.search(r"\bmesh = ", e):
                if meshes:
                    continue
                raise ValueError("meshes aren't supported: " + path)
            if len(p["cf"]) == 3:
                p["cf"] = p["cf"] + [1, 0, 0, 0, 1, 0, 0, 0, 1]
            parts.append(p)
        i = src.index("animations = {")
        anims = "animations = " + table_at(src, src.index("{", i))
        return cls(bones, parts, anims)

    def copy(self):
        import copy
        return copy.deepcopy(self)

    # ---- looking things up -----------------------------------------------------------
    def find(self, pattern):
        rx = re.compile(pattern)
        return [p for p in self.parts if rx.fullmatch(p["name"])]

    def bone(self, name):
        return next(b for b in self.bones if b["name"] == name)

    def box(self, pattern=".*"):
        """(lo, hi) of the matching parts' world boxes (rest pose, ignoring bone rests)."""
        lo, hi = [math.inf] * 3, [-math.inf] * 3
        for p in self.find(pattern):
            r = p["cf"][3:]
            h = [s / 2 for s in p["size"]]
            for a in range(3):
                e = sum(abs(r[a * 3 + k]) * h[k] for k in range(3))
                lo[a] = min(lo[a], p["cf"][a] - e)
                hi[a] = max(hi[a], p["cf"][a] + e)
        return lo, hi

    # ---- changing it -----------------------------------------------------------------
    def recolor(self, mapping, pattern=".*"):
        """mapping: {(r, g, b): (r, g, b) or (colour, {flags})}"""
        for p in self.find(pattern):
            to = mapping.get(tuple(p["color"]))
            if to is None:
                continue
            if isinstance(to[0], (tuple, list)):
                to, flags = to
                self._flags(p, flags)
            p["color"] = list(to)
        return self

    def _flags(self, p, flags):
        for k, v in flags.items():
            if v:
                p[k] = True
            else:
                p.pop(k, None)

    def paint(self, pattern, color, **flags):
        for p in self.find(pattern):
            p["color"] = list(color)
            self._flags(p, flags)
        return self

    def drop(self, pattern):
        rx = re.compile(pattern)
        self.parts = [p for p in self.parts if not rx.fullmatch(p["name"])]
        return self

    def move(self, pattern, d):
        for p in self.find(pattern):
            for a in range(3):
                p["cf"][a] += d[a]
        return self

    def grow(self, pattern, k, about=None):
        """Scale the matching parts' sizes by k (number or (x, y, z), in their own axes) and,
        if about is given, their positions away from that point."""
        ks = k if isinstance(k, (tuple, list)) else (k, k, k)
        for p in self.find(pattern):
            r = p["cf"][3:]
            # a part's own axes picked up the world scale through its rotation
            p["size"] = [p["size"][i] * math.sqrt(sum((r[a * 3 + i] * ks[a]) ** 2 for a in range(3))) for i in range(3)]
            if about is not None:
                for a in range(3):
                    p["cf"][a] = about[a] + (p["cf"][a] - about[a]) * ks[a]
        return self

    def spread(self, pattern, k, about):
        """Move the matching parts away from a point (k per axis), keeping their sizes."""
        ks = k if isinstance(k, (tuple, list)) else (k, k, k)
        for p in self.find(pattern):
            for a in range(3):
                p["cf"][a] = about[a] + (p["cf"][a] - about[a]) * ks[a]
        return self

    def add(self, name, bone, size, pos, color, cls="Part", rot=IDENT, **flags):
        p = {"name": name, "bone": bone, "class": cls, "size": list(size),
             "cf": list(pos) + [v for row in rot for v in row], "color": list(color)}
        self._flags(p, flags)
        self.parts.append(p)
        return p

    def mirror(self, pattern):
        """Add an X-mirrored copy of each matching part: the last L in its name (and its
        bone's, if that bone exists) becomes R."""
        def swap(n):
            i = n.rfind("L")
            return n if i < 0 else n[:i] + "R" + n[i + 1:]
        names = {b["name"] for b in self.bones}
        for p in list(self.find(pattern)):
            q = {k: (list(v) if isinstance(v, list) else v) for k, v in p.items()}
            q["name"] = swap(p["name"])
            q["bone"] = swap(p["bone"]) if swap(p["bone"]) in names else p["bone"]
            c = q["cf"]
            c[0] = -c[0]
            # reflect the rotation: S M S with S = diag(-1, 1, 1) (a box or a wedge is
            # symmetric across its own X, so it stays the same shape)
            r = c[3:]
            sgn = [[1, -1, -1], [-1, 1, 1], [-1, 1, 1]]
            c[3:] = [r[i * 3 + j] * sgn[i][j] for i in range(3) for j in range(3)]
            self.parts.append(q)
        return self

    def add_bone(self, name, parent, pivot, like=None):
        """A new bone; like: an existing bone whose animation tracks it copies."""
        self.bones.append({"name": name, "parent": parent, "pivot": list(pivot), "rest": None})
        if like:
            rx = re.compile(r"(\t\t\t\t)%s = \{\n(.*?)\n\t\t\t\t\},\n" % re.escape(like), re.S)
            self.animations = rx.sub(lambda m: m.group(0) + "%s%s = {\n%s\n\t\t\t\t},\n" % (m.group(1), name, m.group(2)), self.animations)
        return self

    def drop_bone(self, name):
        """Remove a bone with its parts and animation tracks (it must have no child bones)."""
        assert not any(b["parent"] == name for b in self.bones), name
        self.bones = [b for b in self.bones if b["name"] != name]
        self.parts = [p for p in self.parts if p["bone"] != name]
        self.animations = re.sub(r"\t\t\t\t%s = \{\n.*?\n\t\t\t\t\},\n" % re.escape(name), "", self.animations, flags=re.S)
        return self

    # ---- writing -----------------------------------------------------------------------
    def luau(self, header):
        out = [header.rstrip("\n"), "", "return {", "\tbones = {"]
        for b in self.bones:
            parent = '"%s"' % b["parent"] if b["parent"] else "nil"
            rest = ", rest = " + b["rest"] if b["rest"] else ""
            out.append('\t\t{ name = "%s", parent = %s, pivot = Vector3.new(%s)%s },' % (
                b["name"], parent, ", ".join(fmt(v) for v in b["pivot"]), rest))
        out.append("\t},")
        out.append("\tparts = {")
        for p in self.parts:
            flags = "".join(", %s = true" % f for f in ("plain", "neon", "hidden") if p.get(f))
            out.append('\t\t{ name = "%s", bone = "%s", class = "%s", size = Vector3.new(%s), cframe = CFrame.new(%s), color = Color3.fromRGB(%s)%s },' % (
                p["name"], p["bone"], p["class"], ", ".join(fmt(v) for v in p["size"]),
                ", ".join(fmt(v) for v in p["cf"]), ", ".join(str(int(round(v))) for v in p["color"]), flags))
        out.append("\t},")
        out.append("\t-- keys: { time, x, y, z }; rotation in radians, position in studs, scale as a factor")
        out.append("\t" + self.animations + ",")
        out.append("}")
        return "\n".join(out) + "\n"

    def write(self, path, header):
        open(path, "w").write(self.luau(header))


def anims(spec):
    """Luau animations text from { anim: (length, { bone: { "rotation"/"position"/"scale":
    [(t, x, y, z), ...] (rotation in degrees), "smooth": bool } }) }."""
    out = ["animations = {"]
    for name, (length, tracks) in spec.items():
        out.append("\t\t%s = {" % name)
        out.append("\t\t\tlength = %s," % fmt(length))
        out.append("\t\t\ttracks = {")
        for bone, chans in tracks.items():
            out.append("\t\t\t\t%s = {" % bone)
            smooth = "true" if chans.get("smooth", True) else "false"
            for ch in ("rotation", "position", "scale"):
                if ch not in chans:
                    continue
                keys = []
                for k in chans[ch]:
                    t, v = k[0], list(k[1:])
                    if ch == "rotation":
                        v = [math.radians(a) for a in v]
                    keys.append("{%s}" % ",".join(fmt(x) for x in [t] + v))
                # (packed: Studio refuses a script over 200k characters, and a big school hits that)
                out.append("\t\t\t\t\t%s = { smooth = %s, keys = { %s } }," % (ch, smooth, ",".join(keys)))
            out.append("\t\t\t\t},")
        out.append("\t\t\t},")
        out.append("\t\t},")
    out.append("\t}")
    return "\n".join(out)


def cycle(length, frames):
    """Keys (t, x, y, z) for values spread evenly over a loop; frames: [(x, y, z), ...],
    the first repeated at the end."""
    n = len(frames)
    return [(length * i / n, *f) for i, f in enumerate(frames)] + [(length, *frames[0])]
