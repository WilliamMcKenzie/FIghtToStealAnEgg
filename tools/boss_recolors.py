"""Bosses that are LassoAPet's models, recoloured (QM, Oct 30: "blood bat make it a recolor of
the actual bat from lasso a pet", the Crimson Knight the Asura, the Castle Wyvern the Rock
Candy Dragon with a tail that isn't candy, the Elder Treant the Ancient Treant, the Trench
Shark Lasso's shark boss, the Scorpion King the Scorpion pet with red-on-black eyes and a red
stinger).

Each starts from its Lasso model, copied as it is into tools/bases/<Kind>Model.luau (the
Scorpion from our own pet), and gets its colours swapped part by part. Meshes keep their
names, so they are the same MeshParts in ReplicatedStorage.AnimalMeshes (tools/animal_meshes.luau).

  python3 tools/boss_recolors.py [Name ...]     # then python3 tools/boss_anims.py for their attacks
"""

import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
BASES = os.path.join(HERE, "bases")
ANIMALS = os.path.join(ROOT, "src", "shared", "Animals")

PART = re.compile(r'^(\t\t\{ name = "([^"]+)", bone = "([^"]+)", .*color = Color3\.fromRGB\()(\d+), (\d+), (\d+)(\).*)$', re.M)


def recolor(src, fn):
    """fn(name, bone, (r, g, b)) -> (r, g, b) or None (keep it) for every part line."""
    def sub(m):
        to = fn(m.group(2), m.group(3), tuple(int(m.group(i)) for i in (4, 5, 6)))
        if to is None:
            return m.group(0)
        return m.group(1) + ", ".join(str(int(c)) for c in to) + m.group(7)
    return PART.sub(sub, src)


def by_color(mapping):
    return lambda name, bone, c: mapping.get(c)


def lift(src, dy):
    """Every bone and part dy studs higher (a flyer's hover, drawn into the model)."""
    src = re.sub(r"(pivot = Vector3\.new\()([^,]+), ([^,]+),", lambda m: "%s%s, %g," % (m.group(1), m.group(2), round(float(m.group(3)) + dy, 5)), src)
    return re.sub(r"(cframe = CFrame\.new\()([^,]+), ([^,]+),", lambda m: "%s%s, %g," % (m.group(1), m.group(2), round(float(m.group(3)) + dy, 5)), src)


def drop(src, pattern):
    """Removes the parts whose names fully match pattern."""
    rx = re.compile(pattern)
    return "".join(l for l in src.splitlines(True) if not ((m := PART.match(l.rstrip("\n"))) and rx.fullmatch(m.group(2))))


def add(src, lines):
    """Adds part lines at the end of the parts table."""
    i = src.index("\tparts = {")
    j = src.index("\n\t},", i)
    return src[:j] + "".join("\n\t\t" + l for l in lines) + src[j:]


BOSSES = {}  # name -> (base path, note, fn or None)


def boss(name, base, note):
    def wrap(fn):
        BOSSES[name] = (base, note, fn)
        return fn
    return wrap


@boss("SharkBoss", os.path.join(BASES, "SharkBossModel.luau"), "LassoAPet's shark boss as it is: the Ocean Trench's Trench Shark (QM, Oct 30).")
def shark_boss(src):
    return src


@boss("ScorpionKing", os.path.join(ANIMALS, "ScorpionModel.luau"),
      "The Desert Scorpion pet with red pupils on black eyes and a red stinger: the Scorpion King (QM, Oct 30).")
def scorpion_king(src):
    return recolor(src, lambda name, bone, c: {"EyeL": (20, 16, 22), "EyeR": (20, 16, 22), "PupilL": (235, 36, 44),
                                               "PupilR": (235, 36, 44), "Stinger": (206, 52, 44)}.get(name))


@boss("BloodBat", os.path.join(BASES, "BatModel.luau"),
      "LassoAPet's Bat in crimson, hovering 4 studs up: the Red Castle's Blood Bat (QM, Oct 30).")
def blood_bat(src):
    return lift(recolor(src, by_color({
        (110, 60, 150): (156, 28, 44),  # fur and ears
        (52, 28, 76): (72, 14, 24),  # wings
        (66, 34, 96): (100, 20, 34),  # legs and snout
        (255, 140, 190): (236, 90, 100),  # nose
        (255, 255, 255): (255, 214, 70),  # eyes, yellow as the old Blood Bat's
    })), 4)


@boss("CrimsonKnight", os.path.join(BASES, "AsuraModel.luau"),
      "LassoAPet's Asura in crimson and gold: the Red Castle's Crimson Knight (QM, Oct 30).")
def crimson_knight(src):
    return recolor(src, by_color({
        (72, 84, 85): (132, 24, 36),  # armour
        (111, 120, 121): (180, 42, 52),  # its lighter plates
        (53, 67, 69): (74, 14, 22),  # its darkest
        (121, 191, 202): (236, 182, 64),  # trim (cyan on the Asura): gold
        (255, 40, 40): (255, 214, 80),  # glowing eyes: gold, to show on the red
    }))


CANDY = {  # the Rock Candy Dragon's rainbow crystals and glass wings as a castle wyvern's horn and hide
    "a": (96, 18, 30), "b": (214, 168, 88), "c": (244, 214, 150),  # each spine's three crystals: dark, gold, pale
}


@boss("CastleWyvern", os.path.join(BASES, "RockCandyDragonModel.luau"),
      "LassoAPet's Rock Candy Dragon, its candy turned to horn and gold and its lollipop tail to a spade:\n"
      "-- the Red Castle's Castle Wyvern (QM, Oct 30).")
def castle_wyvern(src):
    def color(name, bone, c):
        name = re.sub(r"_\d+$", "", name)
        m = re.match(r"(Glow)?(?:Neck|Tail\d)?Spine\d?([abc])\d?(Tip)?\d?$", name)
        if m:  # the crystals down its back, neck and tail: horn spikes, dark, gold and pale
            if m.group(1):
                return (255, 150, 50)  # (its glowing tips: embers)
            base = CANDY[m.group(2)]
            return tuple(min(255, int(v * 1.12)) for v in base) if m.group(3) else base
        if name.startswith("Glow"):
            return (255, 150, 50)
        if re.match(r"(Arm|Finger)[LR]\d*$", name):
            return (112, 16, 32)  # wing bones (candy-cane white on the dragon)
        if re.match(r"(Arm|Finger)Band[LR]\d*$", name):
            return (214, 168, 88)
        if re.match(r"Skull\d*$", name) and c == (255, 252, 246):
            return (200, 40, 56)
        return {
            (236, 36, 72): (176, 28, 46), (168, 18, 50): (112, 16, 32),  # hide
            (255, 240, 206): (236, 204, 156),  # belly
            (70, 196, 255): (150, 28, 44), (120, 222, 50): (150, 28, 44),  # wing membrane
            (34, 132, 230): (104, 16, 30), (66, 168, 34): (104, 16, 30),
            (160, 80, 240): (236, 182, 64), (110, 46, 196): (104, 16, 30),  # wing roots, horn bands, irises
            (236, 246, 255): (54, 44, 50),  # claws
            (241, 101, 126): (64, 50, 54), (243, 123, 145): (84, 66, 70), (247, 167, 181): (84, 66, 70),  # horns, crest
            (255, 92, 150): (150, 28, 44),  # wrists
            (255, 150, 206): (220, 90, 110),  # tongue
        }.get(c)

    src = recolor(drop(src, r"TailStick.*|(Glow)?Lolly.*"), color)
    c, s_ = math.cos(math.pi / 4), math.sin(math.pi / 4)
    rot = ", ".join("%g" % round(v, 6) for v in (c, 0, s_, 0, 1, 0, -s_, 0, c))
    return add(src, ['{ name = "Spade", bone = "Tail3", class = "Part", size = Vector3.new(2.8, 0.6, 2.8), cframe = CFrame.new(0, 6.4, 17.4, %s), color = Color3.fromRGB(112, 16, 32) },' % rot,
                     '{ name = "SpadeRidge", bone = "Tail3", class = "Part", size = Vector3.new(0.7, 0.9, 3.2), cframe = CFrame.new(0, 6.5, 16.9, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(176, 28, 46) },'])


@boss("ElderTreant", os.path.join(BASES, "AncientTreantModel.luau"),
      "LassoAPet's Ancient Treant in the old Elder Treant's teal: the Magic Circle's Elder Treant (QM, Oct 30).")
def elder_treant(src):
    return recolor(src, lambda name, bone, c: {
        (60, 160, 60): (200, 255, 150) if name.startswith("Socket") else (56, 196, 168),  # leaves (eye glow in its sockets)
        (96, 170, 60): (96, 222, 190),  # moss and beard
        (126, 84, 52): (128, 92, 70), (84, 54, 36): (90, 62, 48), (160, 112, 70): (150, 110, 84),  # bark
    }.get(c))


def write(name):
    base, note, fn = BOSSES[name]
    src = open(base).read()
    body = src[src.index("return {"):]
    body = fn(body)
    header = ["-- GENERATED by tools/boss_recolors.py from tools/bases/" + os.path.basename(base) + " (" + name + "). Don't",
              "-- edit by hand: change its recolour there and run python3 tools/boss_recolors.py " + name + ",",
              "-- then python3 tools/boss_anims.py " + name + " for its attacks.",
              "-- Units are studs, rest pose, feet on Y = 0, facing -Z.",
              "-- " + note, ""]
    path = os.path.join(ANIMALS, name + "Model.luau")
    open(path, "w").write("\n".join(header) + body)
    print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    for name in BOSSES:
        if len(sys.argv) < 2 or name in sys.argv[1:]:
            write(name)
