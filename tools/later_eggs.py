"""Eggs for the later biomes' pets (tools/later_pets.py), in the same layered style as the
others (designs/eggs/c_style; LassoAPet's own pets keep their Lasso eggs, copied as they
are): a pet made from another pet gets that pet's egg recoloured
the same way (and the same tweaks); a new pet gets the plain layered egg in its colours with
a few of its features (ears, eyes, a cap, spines...).

Run: python3 tools/later_eggs.py
     writes src/shared/Eggs/<Kind>EggModel.luau for each.

Egg units: about 2.4 studs wide and 3.2 tall; layers L0..L3 on the bottom bone (up to
y 1.83, where it cracks), L4..L6 on the top bone. Fronts (-Z): L1 and L4 at z -1.1, L2 and
L3 at -1.2, L5 at -0.9, L6 at -0.5.
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from petlib import EGGS, Model, deg  # noqa: E402
from later_pets import (BONE, BONE_DK, BONE_SH, CRIMSON, CRIMSON_DK, CRYPT, CRYPT_DK, DEEP, GHOST, GOLD,  # noqa: E402
                        GOLD_DK, MAGIC, NAVY, ABYSS, STEEL, STEEL_DK, STEEL_LT, TEAL_DK, PUPIL)

EGG = {}


def egg(kind, base=None):
    def wrap(fn):
        EGG[kind] = (fn, base)
        return fn
    return wrap


def load(kind):
    path = os.path.join(EGGS, kind + "EggModel.luau")
    if not os.path.exists(path):  # (LassoAPet's, kept only as a base: tools/bases)
        path = os.path.join(HERE, "bases", kind + "EggModel.luau")
    return Model.load(path)


def plain(layers):
    """The plain layered egg (the Pig's shell without its ears, tail and belly), each layer
    L0..L6 in its colour."""
    m = load("Pig")
    m.parts = [p for p in m.parts if re.match(r"L\d|LInside", p["name"])]
    for i, c in enumerate(layers):
        m.paint("L%d[A-Z].*" % i, c)
    return m


def pair(m, name, bone, size, pos, color, cls="Part", rot=None, **flags):
    """A part and its mirror across X (name + L / R)."""
    for s, side in ((-1, "L"), (1, "R")):
        p = (s * pos[0], pos[1], pos[2])
        r = rot(s) if callable(rot) else rot
        m.add(name + side, bone, size, p, color, cls, **({"rot": r} if r else {}), **flags)


# ---- recoloured from their pets' bases -------------------------------------------------
@egg("BoneSteed", "Horse")
def _():
    m = load("Horse").recolor({(226, 130, 50): BONE, (92, 54, 34): CRYPT, (74, 78, 102): CRYPT_DK,
                               (250, 236, 205): BONE_DK, (205, 205, 200): BONE_SH, (242, 150, 192): CRYPT_DK})
    m.paint("L2[A-Z].*", BONE_DK)
    pair(m, "Socket", "top", (0.35, 0.3, 0.05), (0.35, 2.15, -1.13), GHOST, neon=True)
    return m


@egg("RoyalSteed", "Horse")
def _():
    m = load("Horse").recolor({(226, 130, 50): (246, 244, 240), (92, 54, 34): CRIMSON, (74, 78, 102): GOLD_DK,
                               (250, 236, 205): (226, 222, 214), (205, 205, 200): (226, 222, 214), (242, 150, 192): (220, 200, 200)})
    m.paint("L2[A-Z].*", CRIMSON)
    m.paint("L1[A-Z].*", GOLD)
    return m


@egg("BoneWyrm", "Rockworm")
def _():
    return load("Rockworm").recolor({(120, 130, 162): BONE_DK, (88, 98, 128): BONE, (54, 58, 82): CRYPT,
                                     (255, 120, 20): GHOST})


@egg("DungeonRat", "Pig")
def _():
    fur, pink = (150, 148, 162), (240, 160, 182)
    m = load("Pig").recolor({(214, 112, 142): (104, 100, 116), (246, 164, 184): fur, (250, 196, 208): (196, 194, 206)})
    m.drop("Ear.*")
    m.paint("Tail.", pink)
    pair(m, "Ear", "top", (0.75, 0.75, 0.18), (0.55, 3.45, 0), fur)
    pair(m, "EarIn", "top", (0.45, 0.45, 0.05), (0.55, 3.42, -0.11), pink, plain=True)
    return m


@egg("CaveSpider", "Scorpion")
def _():
    m = load("Scorpion").recolor({(230, 160, 74): (58, 62, 74), (184, 110, 50): (40, 42, 52), (160, 70, 60): (78, 82, 100),
                                  (70, 44, 40): (40, 42, 52)})
    m.drop("Arm.|Hand.|Finger.*|Tail.*|Stinger")
    m.paint("L3[A-Z].*", GHOST, neon=True)
    for i, (x, y) in enumerate(((-0.45, 2.15), (-0.17, 2.25), (0.17, 2.25), (0.45, 2.15))):
        m.add("Eye%d" % i, "top", (0.18, 0.18, 0.05), (x, y, -1.13), GHOST, neon=True)
    for i, z in enumerate((-0.45, 0.0, 0.45)):
        pair(m, "Leg%d" % i, "bottom", (0.6, 0.18, 0.18), (1.32, 0.7, z), (40, 42, 52), rot=lambda s: deg(0, 0, s * 35))
    return m


@egg("SpiritFox", "Bunny")
def _():
    m = load("Bunny").recolor({(206, 150, 98): (236, 246, 255), (250, 236, 212): (255, 255, 255), (242, 150, 192): MAGIC})
    m.drop("Ear.*")
    pair(m, "Ear", "top", (0.55, 0.9, 0.35), (0.42, 3.55, 0), (236, 246, 255), "WedgePart", rot=deg(0, 180, 0))
    pair(m, "EarIn", "top", (0.3, 0.5, 0.05), (0.42, 3.42, -0.19), MAGIC, plain=True)
    m.paint("Tail", MAGIC, neon=True)
    return m


@egg("SpiritDeer", "Unicorn")
def _():
    m = load("Unicorn").recolor({(248, 248, 244): (150, 214, 200), (255, 200, 60): (52, 92, 108), (242, 150, 192): TEAL_DK})
    m.drop("Horn.")
    m.paint("Mane.|Forelock|Crest", TEAL_DK)
    pair(m, "Antler", "top", (0.15, 0.8, 0.15), (0.32, 3.6, -0.15), MAGIC, neon=True)
    pair(m, "AntlerTine", "top", (0.15, 0.45, 0.15), (0.5, 3.85, -0.15), MAGIC, rot=lambda s: deg(0, 0, -s * 35), neon=True)
    for i, (x, y) in enumerate(((-0.6, 1.2), (0.5, 0.75), (0.7, 1.45))):
        m.add("Spot%d" % i, "bottom", (0.25, 0.25, 0.05), (x, y, -1.15 if y < 1 else -1.24), (255, 255, 255), plain=True)
    return m


@egg("WarBoar", "Boar")
def _():
    m = load("Boar").recolor({(176, 108, 68): (92, 84, 92), (112, 66, 46): CRIMSON, (86, 60, 52): (50, 44, 52),
                              (236, 190, 136): STEEL, (254, 246, 222): GOLD})
    return m


@egg("RoyalPeacock", "Firebird")
def _():
    m = load("Firebird").recolor({(255, 128, 32): (38, 86, 196), (232, 98, 22): (40, 170, 160), (64, 62, 70): (60, 54, 70),
                                  (34, 32, 38): GOLD})
    for i, a in enumerate((-40, 0, 40)):
        import math
        r = math.radians(a)
        x, y = -math.sin(r) * 0.9, 2.6 + math.cos(r) * 0.9
        m.add("Fan%d" % i, "top", (0.5, 1.6, 0.1), (x, y, 1.15), (40, 170, 160), rot=deg(0, 0, a))
        m.add("FanEye%d" % i, "top", (0.3, 0.3, 0.05), (x * 1.5, 2.6 + (y - 2.6) * 1.5, 1.22), GOLD, rot=deg(0, 0, a), plain=True)
    return m


@egg("LivingArmor", "Icebringer")
def _():
    m = load("Icebringer").recolor({(56, 206, 238): STEEL, (30, 164, 214): STEEL_DK, (236, 246, 255): STEEL_LT,
                                    (250, 248, 238): GOLD, (206, 222, 236): CRIMSON})
    m.add("Visor", "top", (1.2, 0.15, 0.05), (0, 2.3, -1.13), (255, 60, 70), neon=True)
    return m


@egg("CrimsonDrake", "SpineLizard")
def _():
    return load("SpineLizard").recolor({(236, 178, 84): CRIMSON, (206, 132, 60): CRIMSON_DK, (252, 234, 186): (255, 210, 130),
                                        (170, 50, 78): (40, 30, 36), (246, 112, 40): GOLD})


@egg("RoyalEagle", "Phoenix")
def _():
    return load("Phoenix").recolor({(240, 72, 32): (250, 246, 236), (255, 232, 84): ((255, 220, 110), {"neon": None}),
                                    (255, 188, 36): GOLD, (255, 132, 24): (250, 246, 236), (206, 34, 40): CRIMSON})


@egg("CrystalTortoise", "TreasureTurtle")
def _():
    m = load("TreasureTurtle").recolor({(34, 100, 44): (48, 64, 150), (60, 150, 60): (78, 104, 196),
                                        (250, 222, 150): (112, 140, 222), (255, 196, 36): (MAGIC, {"neon": True})})
    m.drop("Trunk.*|Frond.*|Coconut.*")
    return m


@egg("SpiritLoong", "Loong")
def _():
    return load("Loong").recolor({(121, 146, 53): (228, 240, 255), (233, 197, 115): (176, 228, 244),
                                  (255, 216, 21): (150, 100, 240), (227, 142, 22): (MAGIC, {"neon": True}),
                                  (150, 28, 36): (52, 200, 196), (226, 214, 190): (200, 186, 250)})


@egg("MysticOwl", "Penguin")
def _():
    tawny, cream, rim = (160, 112, 70), (244, 228, 194), (120, 82, 52)
    m = load("Penguin").recolor({(34, 36, 50): tawny, (246, 246, 248): cream, (255, 150, 40): (220, 170, 60),
                                 (226, 110, 24): (170, 120, 40)})
    m.paint("Flipper.*", (112, 76, 48))
    m.paint("L4Front", tawny)
    m.paint("L5Front", (240, 224, 196))
    # its wide face: big amber eyes across the pale disc, the beak below, ear tufts on top
    pair(m, "EyeRim", "top", (0.52, 0.42, 0.04), (0.43, 2.52, -0.92), rim, plain=True)
    pair(m, "Eye", "top", (0.38, 0.32, 0.04), (0.43, 2.52, -0.95), (255, 168, 40), plain=True)
    pair(m, "Pupil", "top", (0.18, 0.18, 0.03), (0.43, 2.52, -0.98), PUPIL, plain=True)
    m.grow("Beak|BeakTip", 0.7)
    m.move("Beak|BeakTip", (0, -0.36, -0.03))
    pair(m, "Tuft", "top", (0.35, 0.6, 0.45), (0.38, 3.45, 0), tawny, "WedgePart", rot=deg(0, 180, 0))
    for i, (x, y) in enumerate(((-0.4, 1.15), (0.4, 1.15), (0, 0.75), (-0.45, 0.45), (0.45, 0.45))):
        m.add("Speck%d" % i, "bottom", (0.22, 0.07, 0.03), (x, y, -1.25 if y > 0.91 else -1.13), (176, 130, 80), plain=True)
    return m


@egg("AncientTreant", "AncientTreant")
def _():
    return load("AncientTreant").recolor({
        (84, 54, 36): (48, 56, 94), (126, 84, 52): (70, 84, 130), (160, 112, 70): (96, 110, 160), (44, 28, 22): (22, 22, 44),
        (255, 190, 60): (MAGIC, {"neon": True}), (96, 170, 60): (56, 196, 168), (34, 112, 46): (100, 70, 196),
        (60, 160, 60): (140, 100, 234), (120, 200, 70): (176, 140, 250), (255, 140, 190): (MAGIC, {"neon": True}),
        (220, 80, 150): (90, 180, 240)})


@egg("AbyssWhale", "LavaWhale")
def _():
    return load("LavaWhale").recolor({(182, 100, 62): NAVY, (246, 196, 140): (170, 210, 240), (216, 156, 104): (70, 100, 190),
                                      (255, 140, 30): ABYSS, (136, 74, 50): DEEP})


# ---- new pets: the plain egg in their colours ------------------------------------------
@egg("Slime")
def _():
    g, lt, dk = (110, 214, 96), (168, 240, 140), (70, 160, 70)
    m = plain([dk, g, g, g, g, lt, lt])
    pair(m, "Eye", "top", (0.28, 0.45, 0.05), (0.35, 2.2, -1.13), (30, 40, 30), plain=True)
    pair(m, "Glint", "top", (0.1, 0.14, 0.03), (0.3, 2.32, -1.16), (255, 255, 255), plain=True)
    m.add("Smile", "bottom", (0.35, 0.09, 0.05), (0, 1.62, -1.23), (30, 40, 30), plain=True)
    m.add("Shine", "top", (0.35, 0.05, 0.25), (-0.15, 3.22, -0.05), (230, 255, 220), plain=True)
    pair(m, "Drip", "bottom", (0.3, 0.35, 0.3), (0.85, 0.35, -0.75), g)
    return m


@egg("Mimic")
def _():
    wood, dk = (156, 98, 56), (112, 68, 40)
    m = plain([dk, wood, wood, GOLD, wood, wood, wood])
    m.add("Lock", "bottom", (0.35, 0.4, 0.1), (0, 1.62, -1.26), GOLD)
    m.add("Keyhole", "bottom", (0.08, 0.16, 0.03), (0, 1.6, -1.32), (40, 24, 20), plain=True)
    pair(m, "Eye", "top", (0.3, 0.2, 0.05), (0.45, 2.2, -1.13), (255, 220, 80), neon=True)
    for i, x in enumerate((-0.75, -0.25, 0.25, 0.75)):
        m.add("Tooth%d" % i, "top", (0.18, 0.22, 0.06), (x, 1.95, -1.14), (250, 246, 230), "WedgePart", rot=deg(180, 0, 0))
    return m


@egg("ChessKnight", "Horse")
def _():
    ivory, ivory_dk = (242, 234, 216), (214, 202, 180)
    m = load("Horse").recolor({(226, 130, 50): ivory, (92, 54, 34): CRIMSON, (74, 78, 102): ivory_dk,
                               (250, 236, 205): ivory, (205, 205, 200): ivory_dk, (242, 150, 192): ivory_dk})
    # a chessboard's two colours in bands, a gold ring at its foot
    m.drop("Blaze.")
    m.paint("L[135][A-Z].*", (44, 40, 50))
    m.paint("L0[A-Z].*", GOLD)
    return m


@egg("Shroom")
def _():
    stem, cap, gill = (246, 238, 220), (92, 112, 236), (214, 206, 236)
    m = plain([stem, stem, stem, stem, cap, cap, (130, 150, 250)])
    m.add("Brim", "top", (2.8, 0.22, 1.6), (0, 1.95, 0), cap)
    m.add("Brim2", "top", (1.6, 0.22, 2.8), (0, 1.95, 0), cap)
    m.add("Gills", "top", (2.6, 0.04, 2.6), (0, 1.83, 0), gill, plain=True)
    for i, (x, y, z) in enumerate(((-0.55, 2.4, -1.13), (0.45, 2.65, -0.93), (0.0, 3.0, -0.53))):
        m.add("Spot%d" % i, "top", (0.3, 0.25, 0.05), (x, y, z), MAGIC, neon=True)
    pair(m, "Eye", "bottom", (0.16, 0.28, 0.05), (0.25, 1.25, -1.23), (40, 40, 60), plain=True)
    pair(m, "Cheek", "bottom", (0.2, 0.12, 0.05), (0.5, 1.0, -1.23), (250, 170, 190), plain=True)
    return m


@egg("Seahorse")
def _():
    body, belly, fin = (250, 146, 84), (255, 214, 150), (220, 96, 66)
    m = plain([fin, body, body, body, body, body, body])
    m.add("Belly1", "bottom", (0.9, 0.46, 0.05), (0, 0.69, -1.12), belly)
    m.add("Belly2", "bottom", (0.9, 0.46, 0.05), (0, 1.14, -1.23), belly)
    m.add("Belly3", "bottom", (0.9, 0.46, 0.05), (0, 1.6, -1.23), belly)
    m.add("Snout", "top", (0.3, 0.3, 0.5), (0, 2.5, -1.15), body)
    m.add("SnoutTip", "top", (0.4, 0.4, 0.15), (0, 2.5, -1.45), fin)
    for i, z in enumerate((-0.25, 0.1, 0.45)):
        m.add("Crown%d" % i, "top", (0.18, 0.4 - i * 0.08, 0.3), (0, 3.38 - i * 0.04, z), fin, "WedgePart", rot=deg(0, 180, 0))
    pair(m, "Fin", "bottom", (0.08, 0.4, 0.5), (1.25, 1.3, 0.2), fin)
    m.add("Dorsal", "bottom", (0.12, 0.7, 0.4), (0, 1.1, 1.35), fin, "WedgePart", rot=deg(0, 180, 0))
    return m


@egg("KingCrab")
def _():
    red, dk, lt = (226, 58, 48), (160, 32, 40), (244, 104, 66)
    m = plain([dk, red, red, red, red, red, lt])
    m.add("Belly", "bottom", (1.2, 0.46, 0.05), (0, 1.14, -1.23), (250, 226, 190))
    pair(m, "Claw", "bottom", (0.45, 0.5, 0.6), (1.35, 1.0, -0.45), lt)
    pair(m, "ClawTip", "bottom", (0.3, 0.25, 0.4), (1.35, 1.38, -0.65), lt)
    pair(m, "Stalk", "top", (0.15, 0.4, 0.15), (0.3, 3.4, -0.2), dk)
    pair(m, "EyeBall", "top", (0.28, 0.28, 0.28), (0.3, 3.7, -0.2), (255, 255, 255))
    pair(m, "Pupil", "top", (0.14, 0.14, 0.05), (0.3, 3.7, -0.36), (20, 20, 24), plain=True)
    return m


def write_all(only=None):
    for kind, (fn, base) in EGG.items():
        if only and kind not in only:
            continue
        m = fn()
        m.write(os.path.join(EGGS, kind + "EggModel.luau"),
                "-- GENERATED by tools/later_eggs.py (%s). Don't edit by hand: change it\n"
                "-- there and rerun. Units are studs, rest pose, base on Y = 0, facing -Z." % (
                    "the %s egg recoloured" % base if base else "the plain layered egg"))
        print("wrote", kind + "Egg")


if __name__ == "__main__":
    write_all(sys.argv[1:] or None)
