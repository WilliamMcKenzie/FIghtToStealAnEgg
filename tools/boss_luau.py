"""Reads a generated src/shared/Animals/<Name>Model.luau back into a boss_forge.Model (so
tools/render_boss.py can draw any model, Blockbench ones too), and adds attack animations to
one (tools/boss_anims.py: the existing bosses keep their Blockbench shape and gaits and
gain the attacks QM's roster gives them, Oct 30).

Added animations go between two marker comments inside its `animations` table, so running
it again replaces them, and regenerating the model from its .bbmodel drops them (run
python3 tools/boss_anims.py again after).
"""

import math
import os
import re

from boss_forge import ROOT, Model, g

NUM = r"-?[\d.]+(?:e-?\d+)?"
BEGIN = "\t\t-- boss attacks: added by tools/boss_anims.py (QM, Oct 30); keep below this line"
END = "\t\t-- end of boss attacks"


def nums(text):
    return [float(v) for v in re.findall(NUM, text)]


def table_at(src, start):
    depth = 0
    for i in range(start, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return src[start:i + 1]
    raise ValueError("unbalanced")


def entries(table):
    out, i = [], 1
    while True:
        i = table.find("{", i)
        if i < 0:
            return out
        e = table_at(table, i)
        out.append(e)
        i += len(e)


def named(table):
    """name = { ... } entries directly inside a table's text."""
    out, i = {}, 1
    while True:
        m = re.compile(r"(\w+) = \{").search(table, i)
        if not m:
            return out
        body = table_at(table, m.end() - 1)
        out[m.group(1)] = body
        i = m.end() - 1 + len(body)


def path(name):
    return os.path.join(ROOT, "src", "shared", "Animals", name + "Model.luau")


def load(name):
    src = open(path(name)).read()
    m = Model(name)
    m.rests = {}
    for e in entries(table_at(src, src.index("{", src.index("bones = {")))):
        bn = re.search(r'name = "([^"]+)"', e).group(1)
        parent = re.search(r'parent = "([^"]+)"', e)
        pivot = nums(re.search(r"pivot = Vector3\.new\(([^)]*)\)", e).group(1))
        rest = re.search(r"rest = CFrame\.Angles\(([^)]*)\)", e)
        m.bone(bn, parent.group(1) if parent else None, pivot)
        m.rests[bn] = nums(rest.group(1)) if rest else [0, 0, 0]
    for e in entries(table_at(src, src.index("{", src.index("parts = {")))):
        cf = nums(re.search(r"cframe = CFrame\.new\((.*?)\)", e, re.S).group(1))
        if len(cf) == 3:
            cf += [1, 0, 0, 0, 1, 0, 0, 0, 1]
        cls = re.search(r'class = "([^"]+)"', e)
        m.parts.append({
            "name": re.search(r'name = "([^"]+)"', e).group(1), "bone": re.search(r'bone = "([^"]+)"', e).group(1),
            "class": cls.group(1) if cls else "Part", "size": tuple(nums(re.search(r"size = Vector3\.new\(([^)]*)\)", e).group(1))),
            "cf": cf, "at": tuple(cf[:3]), "r": (0, 0, 0),
            "color": tuple(nums(re.search(r"color = Color3\.fromRGB\(([^)]*)\)", e).group(1))),
            "plain": "plain = true" in e, "neon": "neon = true" in e,
        })
    anims = table_at(src, src.index("{", src.index("animations = {")))
    for an, body in named(anims).items():
        length = float(re.search(r"length = (" + NUM + ")", body).group(1))
        hit = re.search(r"\bhit = (" + NUM + ")", body)
        tracks = {}
        for bn, tb in named(table_at(body, body.index("{", body.index("tracks = {")))).items():
            tr = {}
            for field, key, k in (("rotation", "r", 180 / math.pi), ("position", "p", 1)):
                mt = re.search(field + r" = \{ smooth = (true|false), keys = \{", tb)
                if mt:
                    keys = table_at(tb, mt.end() - 1)
                    tr[key] = [tuple([v[0], v[1] * k, v[2] * k, v[3] * k]) for v in (nums(x) for x in re.findall(r"\{([^{}]*)\}", keys))]
                    if mt.group(1) == "false":
                        tr.setdefault("linear", set()).add(key)
            tracks[bn] = tr
        m.anim(an, length, tracks, float(hit.group(1)) if hit else None)
    return m


def anim_luau(name, a):
    out = ["\t\t{} = {{".format(name), "\t\t\tlength = {},".format(g(a["length"]))]
    if a["hit"] is not None:
        out.append("\t\t\thit = {},".format(g(a["hit"])))
    out.append("\t\t\ttracks = {")
    for bone, tr in a["tracks"].items():
        out.append("\t\t\t\t{} = {{".format(bone))
        for key, field, k in (("r", "rotation", math.pi / 180), ("p", "position", 1)):
            if key in tr:
                keys = ", ".join("{{ {}, {}, {}, {} }}".format(g(t), g(x * k), g(y * k), g(z * k)) for t, x, y, z in tr[key])
                out.append("\t\t\t\t\t{} = {{ smooth = true, keys = {{ {} }} }},".format(field, keys))
        out.append("\t\t\t\t},")
    out += ["\t\t\t},", "\t\t},"]
    return out


def inject(name, anims):
    """Puts anims ({ name: { length, hit, tracks } }, degrees) into the model's animations."""
    p = path(name)
    src = open(p).read()
    bones = {b[0] for b in load(name).bones}
    for an, a in anims.items():
        for bone in a["tracks"]:
            assert bone in bones, name + ": " + an + " moves unknown bone " + bone
    if BEGIN in src:
        src = src[:src.index(BEGIN)] + src[src.index(END) + len(END) + 1:]
    start = src.index("{", src.index("animations = {"))
    close = start + len(table_at(src, start)) - 1  # its closing brace, on its own line
    line = src.rindex("\n", 0, close) + 1
    block = [BEGIN]
    for an, a in anims.items():
        block += anim_luau(an, a)
    block.append(END)
    src = src[:line] + "\n".join(block) + "\n" + src[line:]
    open(p, "w").write(src)
    print("added", ", ".join(anims), "to", os.path.relpath(p, ROOT))
