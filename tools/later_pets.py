"""The pets of the biomes past the Lava Valley (QM, Oct 30: "for other biomes also create new
pets with eggs, in the elegant style of meadow/desert, recolor some maybe when appropriate
(like how i did sandworm->rockworm) and do slight modifications/resizing to make them fit").

  Abandoned Dungeon (Dungeon)   Dungeon Rat, Slime, Cave Spider, Bone Steed, Mimic, Bone Wyrm
  Red Castle (Castle)           War Boar, Royal Steed, Chess Knight, Royal Peacock, Living Armor,
                                Crimson Drake, Royal Griffin
  Magic Circle (Forest)         Shroom, Spirit Fox, Spirit Deer, Treant, Mystic Owl,
                                Crystal Tortoise, Spirit Loong
  Ocean Trench (Ocean)          Pufferfish, Seahorse, King Crab, Shark, Octopus, Abyss Whale

Most are an existing pet recoloured and tweaked (parts added, dropped or resized); the
Slime, Mimic, Chess Knight, Shroom, Seahorse and Octopus are new. Each pet's egg is drawn
in the same layered style as the others (tools/later_eggs.py).

Run: python3 tools/later_pets.py
     writes src/shared/Animals/<Kind>Model.luau (and <Kind>.luau, its class) for each.
Their rarity, cash, odds and hatch times are in Config (Pets, Eggs.Kinds, Hatch.Time).
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from petlib import ANIMALS, Model, anims, cycle, deg  # noqa: E402

PETS = {}  # kind -> dict(model=fn, base=..., note=..., seat=..., neck=..., size=...)


def pet(kind, note, base=None, **points):
    def wrap(fn):
        PETS[kind] = dict(build=fn, note=note, base=base, **points)
        return fn
    return wrap


# palettes -------------------------------------------------------------------------------
BONE, BONE_DK, BONE_SH = (236, 230, 210), (200, 192, 168), (170, 162, 140)
CRYPT, CRYPT_DK = (64, 70, 72), (44, 48, 52)
GHOST = (90, 255, 140)  # the dungeon's runes
CRIMSON, CRIMSON_DK, GOLD, GOLD_DK = (176, 28, 48), (120, 18, 36), (255, 200, 60), (210, 150, 40)
STEEL, STEEL_DK, STEEL_LT = (150, 156, 170), (96, 100, 116), (200, 206, 218)
TEAL, TEAL_DK, MAGIC = (56, 196, 168), (34, 140, 126), (110, 220, 255)
NAVY, DEEP, ABYSS = (40, 64, 150), (24, 34, 90), (90, 240, 255)
EYE_W, PUPIL = (255, 255, 255), (30, 30, 45)


# ---- Abandoned Dungeon -------------------------------------------------------------------
@pet("BoneSteed", "The Horse as a skeleton: bone white, a crypt-dark mane and hooves, ribs\n"
     "-- down its sides and the dungeon's green glowing in its eye sockets.", base="Horse")
def bone_steed():
    m = Model.load("Horse")
    m.recolor({(226, 130, 50): BONE, (92, 54, 34): CRYPT, (70, 44, 36): CRYPT_DK,
               (74, 78, 102): CRYPT_DK, (242, 150, 192): CRYPT_DK,
               (255, 255, 255): CRYPT_DK, (30, 30, 45): (GHOST, {"neon": True, "plain": None})})
    lo, hi = m.box("Body")
    # ribs: dark bands across each side of the body
    for i, z in enumerate([lo[2] + 1.0, lo[2] + 1.8, lo[2] + 2.6]):
        for s, side in ((-1, "L"), (1, "R")):
            x = (hi[0] if s > 0 else lo[0]) + s * 0.03
            m.add("Rib%d%s" % (i, side), "root", (0.06, (hi[1] - lo[1]) * 0.62, 0.32),
                  (x, (lo[1] + hi[1]) / 2 - 0.1, z), CRYPT, plain=True)
    return m


@pet("BoneWyrm", "The Rockworm as a skeleton (as QM made the Rockworm from the Sandworm):\n"
     "-- bone segments, crypt plates and the dungeon's green glowing in its fins and horns.",
     base="Rockworm", size_of=("Rockworm", 1.1))
def bone_wyrm():
    m = Model.load("Rockworm")
    m.recolor({(120, 130, 162): BONE_DK, (88, 98, 128): BONE, (54, 58, 82): CRYPT,
               (255, 120, 20): GHOST})
    return m


# ---- Red Castle ----------------------------------------------------------------------------
@pet("RoyalPeacock", "The Firebird as the castle garden's peacock: royal blue with a teal\n"
     "-- breast, gold claws and a gold crest.", base="Firebird")
def royal_peacock():
    m = Model.load("Firebird")
    m.recolor({(255, 128, 32): (38, 86, 196), (232, 98, 22): (40, 170, 160),
               (64, 62, 70): (60, 54, 70), (232, 224, 204): GOLD, (34, 32, 38): GOLD,
               (255, 214, 60): (255, 240, 200)})
    # a small beak (no teeth) and a fan of tail feathers with eyes instead of its tail spikes
    m.drop("Tooth.*|Mouth|Tail[0-9]")
    m.grow("Beak|BeakHook|Jaw", 0.55, about=(0, 11.0, -6.4))
    m.paint("Beak|BeakHook|Jaw", (230, 190, 90))
    centre = (0, 6.8, 3.4)
    for i, a in enumerate((-64, -32, 0, 32, 64)):
        r = math.radians(a)
        up = (-math.sin(r), math.cos(r), 0)
        at = lambda d, dz=0: (centre[0] + up[0] * d, centre[1] + up[1] * d, centre[2] + dz)
        m.add("Fan%d" % i, "Tail", (1.5, 7.0, 0.3), at(3.6), (40, 170, 160), rot=deg(0, 0, a))
        m.add("FanEye%d" % i, "Tail", (1.1, 1.3, 0.05), at(6.0, -0.18), GOLD, rot=deg(0, 0, a), plain=True)
        m.add("FanPupil%d" % i, "Tail", (0.6, 0.75, 0.05), at(6.0, -0.22), (38, 86, 196), rot=deg(0, 0, a), plain=True)
    return m


@pet("LivingArmor", "The Icebringer as an empty suit of the castle's armour: steel plates over\n"
     "-- crimson cloth, gold trim and red eyes glowing inside.", base="Icebringer", size=3)
def living_armor():
    m = Model.load("Icebringer")
    m.recolor({(49, 162, 242): STEEL, (25, 118, 237): STEEL_DK, (170, 228, 248): STEEL_LT,
               (110, 220, 245): CRIMSON, (196, 240, 252): GOLD, (243, 243, 243): GOLD,
               (157, 157, 157): CRIMSON_DK, (103, 103, 103): (70, 20, 30),
               (255, 255, 255): (40, 36, 44), (30, 30, 45): ((255, 60, 70), {"neon": True})})
    return m


@pet("CrimsonDrake", "The Spine Lizard as the castle's drake: crimson scales, a gold belly and\n"
     "-- sail, black crests and two horns.", base="SpineLizard")
def crimson_drake():
    m = Model.load("SpineLizard")
    m.recolor({(236, 178, 84): CRIMSON, (206, 132, 60): CRIMSON_DK, (252, 234, 186): (255, 210, 130),
               (170, 50, 78): (40, 30, 36), (250, 150, 52): GOLD, (252, 204, 76): (255, 236, 150)})
    lo, hi = m.box("Head")
    cx, top, z = (lo[0] + hi[0]) / 2, hi[1], (lo[2] + hi[2]) / 2 + (hi[2] - lo[2]) * 0.25
    for s, side in ((-1, "L"), (1, "R")):
        x = cx + s * (hi[0] - lo[0]) * 0.32
        # a horn sweeping back: a base block and a wedge leaning back
        m.add("Horn" + side, "neck", (0.6, 0.7, 0.7), (x, top + 0.3, z), (40, 30, 36))
        m.add("HornTip" + side, "neck", (0.5, 1.2, 1.3), (x, top + 1.25, z + 0.3), (40, 30, 36), "WedgePart",
              rot=deg(0, 180, 0))
    return m


@pet("RoyalEagle", "The Phoenix as the castle's heraldic eagle: white and gold feathers on\n"
     "-- a crimson body, no flame.", base="Phoenix")
def royal_eagle():
    m = Model.load("Phoenix")
    m.recolor({(240, 72, 32): (250, 246, 236), (255, 232, 84): ((255, 220, 110), {"neon": None}),
               (255, 188, 36): GOLD, (255, 132, 24): (250, 246, 236), (206, 34, 40): CRIMSON})
    return m


# ---- Magic Circle ------------------------------------------------------------------------
@pet("Treant", "The Ice Golem grown from the Magic Circle's trees: bark limbs, a turquoise\n"
     "-- mossy cap and shoulders, and leafy shoots where its crystals were.", base="IceGolem")
def treant():
    m = Model.load("IceGolem")
    m.recolor({(82, 150, 226): (96, 66, 48), (160, 218, 250): (140, 100, 66),
               (252, 253, 255): TEAL, (96, 222, 255): (110, 210, 120)})
    m.paint("Pupil.*", MAGIC, neon=True)
    return m


@pet("CrystalTortoise", "The Volcano Tortoise from the Magic Circle: a blue stone shell with a\n"
     "-- crystal mound glowing where the volcano was, mossy turquoise skin.", base="VolcanoTortoise")
def crystal_tortoise():
    m = Model.load("VolcanoTortoise")
    m.recolor({(178, 150, 102): (88, 170, 150), (150, 122, 82): (60, 136, 120), (236, 214, 170): (210, 240, 230),
               (92, 50, 36): (52, 70, 160), (122, 66, 44): (96, 124, 214), (118, 78, 62): (112, 140, 222),
               (112, 96, 90): (150, 220, 255), (92, 78, 74): (110, 180, 240),
               (255, 116, 24): MAGIC, (191, 101, 44): (80, 170, 240), (255, 186, 60): (220, 250, 255)})
    return m


@pet("SpiritLoong", "The Snake as the Magic Circle's spirit dragon: turquoise and white with\n"
     "-- violet bands, glowing blue whiskers and crest.", base="Snake")
def spirit_loong():
    m = Model.load("Snake")
    m.recolor({(240, 186, 72): (240, 248, 255), (252, 234, 186): TEAL, (168, 48, 78): (130, 80, 220),
               (48, 196, 214): (MAGIC, {"neon": True}), (212, 150, 70): (130, 80, 220),
               (255, 214, 64): MAGIC})
    return m


@pet("MysticOwl", "The Penguin as the Magic Circle's owl: night blue, a pale violet front,\n"
     "-- gold beak and feet, ear tufts and big glowing eyes.", base="Penguin")
def mystic_owl():
    m = Model.load("Penguin")
    m.recolor({(40, 46, 64): (58, 66, 150), (250, 250, 250): (214, 206, 250), (255, 150, 30): GOLD,
               (255, 140, 30): GOLD, (230, 100, 30): GOLD_DK, (255, 170, 40): (110, 120, 200),
               (255, 200, 60): MAGIC})
    m.paint("Eye.", (255, 230, 120))
    m.grow("Eye.|Pupil.", (1.5, 1.5, 1))
    lo, hi = m.box("Head|Crown")
    for s, side in ((-1, "L"), (1, "R")):
        m.add("Tuft" + side, "neck", (0.8, 1.4, 1.1), (s * 1.05, hi[1] + 0.7, -0.2), (58, 66, 150),
              "WedgePart", rot=deg(0, 180, 0))
    return m


# ---- Ocean Trench -----------------------------------------------------------------------
@pet("AbyssWhale", "The Lava Whale from the bottom of the trench: navy hide, a pale belly and\n"
     "-- its glyphs glowing cyan like deep-sea lights.", base="LavaWhale")
def abyss_whale():
    m = Model.load("LavaWhale")
    m.recolor({(182, 100, 62): NAVY, (246, 196, 140): (170, 210, 240), (255, 140, 30): ABYSS,
               (136, 74, 50): DEEP})
    return m


@pet("KingCrab", "The King Crab of the Ocean Trench (its model shared with the trench's boss).",
     base=None, seat=(0, 4.3, -0.6), neck=((0, 3.0, -2.6), 2.4))
def king_crab():
    return None  # (KingCrabModel as it is)


# ---- tweaked pets ------------------------------------------------------------------------
@pet("DungeonRat", "The Pig as a dungeon rat: grey fur, round pink ears, a pointed pink\n"
     "-- nose with buck teeth and a long bare tail.", base="Pig")
def dungeon_rat():
    m = Model.load("Pig")
    fur, pink = (150, 148, 162), (240, 160, 182)
    m.recolor({(246, 164, 184): fur, (176, 96, 116): (104, 100, 116), (250, 196, 208): (196, 194, 206),
               (196, 96, 126): (210, 110, 140)})
    m.drop("Ear.*|Tail.*")
    for s_, side in ((-1, "L"), (1, "R")):
        m.add("Ear" + side, "Ear" + side, (1.4, 1.4, 0.3), (s_ * 1.05, 6.15, -3.7), fur)
        m.add("EarIn" + side, "Ear" + side, (0.9, 0.9, 0.05), (s_ * 1.05, 6.1, -3.87), pink, plain=True)
    # a pointed nose past the snout, and two teeth under it
    m.drop("Nostril.")
    m.find("Snout")[0]["size"] = [1.5, 1.1, 1.1]
    m.move("Snout", (0, -0.05, -0.25))
    m.add("NoseTip", "neck", (0.6, 0.5, 0.3), (0, 4.05, -6.1), pink)
    for s_, side in ((-1, "L"), (1, "R")):
        for i, dy in enumerate((0.15, -0.2)):
            m.add("Whisker%s%d" % (side, i), "neck", (1.1, 0.08, 0.08), (s_ * 1.1, 3.75 + dy, -5.6), (60, 56, 70), plain=True)
    for s_, side in ((-1, "L"), (1, "R")):
        m.add("Tooth" + side, "neck", (0.28, 0.4, 0.08), (s_ * 0.16, 3.0, -5.85), (255, 255, 255), plain=True)
    # the tail: back and down off the rump, then curling up
    m.add("Tail", "Tail", (0.45, 0.45, 2.6), (0, 3.9, 4.0), pink, rot=deg(40, 0, 0))
    m.add("Tail2", "Tail", (0.35, 0.35, 2.4), (0, 2.85, 5.85), pink, rot=deg(10, 0, 0))
    return m


@pet("CaveSpider", "The Scorpion as a cave spider: no claws or tail but a big round abdomen,\n"
     "-- a fourth pair of legs, slate black with the dungeon's green glowing in its eyes and back.",
     base="Scorpion")
def cave_spider():
    m = Model.load("Scorpion")
    m.drop("Tail.*|Bulb|Stinger|Shoulder.|Arm.|Hand.|Finger.*|Eye.|Pupil.")
    m.recolor({(230, 160, 74): (58, 62, 74), (184, 110, 50): (40, 42, 52), (160, 70, 60): (78, 82, 100)})
    m.add("Abdomen", "root", (4.4, 3.6, 4.6), (0, 4.3, 5.4), (58, 62, 74))
    m.add("AbdomenBack", "root", (3.4, 2.8, 1.0), (0, 4.2, 8.1), (40, 42, 52))
    m.add("Mark", "root", (1.0, 0.06, 3.0), (0, 6.12, 5.4), GHOST, neon=True)
    m.add("MarkBar", "root", (2.6, 0.06, 0.6), (0, 6.12, 4.6), GHOST, neon=True)
    for i, (x, y) in enumerate(((-1.1, 3.35), (-0.45, 3.5), (0.45, 3.5), (1.1, 3.35))):
        m.add("Eye%d" % i, "neck", (0.45, 0.45, 0.05), (x, y, -4.7), GHOST, neon=True)
    for s_, side in ((-1, "L"), (1, "R")):
        m.add("Fang" + side, "neck", (0.4, 0.8, 0.4), (s_ * 0.6, 1.8, -4.4), BONE)
    # the front pair of legs, in step with the middle pair
    for s_, side in ((-1, "L"), (1, "R")):
        m.add_bone("Leg%s3" % side, "root", (s_ * 2.34, 3.185, -3.3), like="Leg%s1" % side)
        m.add("Thigh%s3" % side, "Leg%s3" % side, (1.56, 0.65, 0.78), (s_ * 3.12, 3.19, -3.4), (78, 82, 100))
        m.add("Shin%s3" % side, "Leg%s3" % side, (0.52, 2.86, 0.78), (s_ * 3.64, 1.43, -3.4), (40, 42, 52))
    return m


@pet("SpiritFox", "The Bunny as the Magic Circle's spirit fox: white, pointed ears and a big\n"
     "-- bushy tail glowing blue at the tips.", base="Bunny")
def spirit_fox():
    m = Model.load("Bunny")
    white = (236, 246, 255)
    m.recolor({(206, 150, 98): white, (250, 236, 212): (255, 255, 255), (240, 110, 150): (40, 50, 90),
               (242, 150, 192): MAGIC})
    m.drop("Ear.*|Tail|Teeth")
    m.paint("Hoof.*", MAGIC)
    # pointed ears: two wedges making a triangle, as the Pig's
    for s_, side in ((-1, "L"), (1, "R")):
        x = s_ * 0.85
        m.add("Ear%sA" % side, "Ear" + side, (0.5, 0.8, 1.6), (x - 0.4, 6.4, -3.3), white, "WedgePart",
              rot=[[0, -1, 0], [0, 0, -1], [1, 0, 0]])
        m.add("Ear%sB" % side, "Ear" + side, (0.5, 1.6, 0.8), (x + 0.4, 6.4, -3.3), white, "WedgePart",
              rot=[[0, 0, -1], [0, 1, 0], [1, 0, 0]])
        m.add("Ear%sIn" % side, "Ear" + side, (0.06, 0.9, 0.6), (x, 6.3, -3.58), MAGIC, plain=True)
    m.add("Tail", "Tail", (1.6, 1.6, 3.0), (0, 4.9, 4.1), white, rot=deg(-28, 0, 0))
    m.add("TailTip", "Tail", (1.3, 1.3, 1.2), (0, 5.85, 5.9), MAGIC, rot=deg(-28, 0, 0), neon=True)
    return m


@pet("SpiritDeer", "The Unicorn as the Magic Circle's spirit deer: turquoise with a darker mane,\n"
     "-- white spots and glowing crystal antlers.", base="Unicorn")
def spirit_deer():
    m = Model.load("Unicorn")
    m.drop("Horn.*")
    m.recolor({(252, 250, 255): (150, 214, 200), (255, 200, 60): (52, 92, 108), (242, 150, 192): TEAL_DK})
    m.paint("Cap.*|Mane|Tail.*|Stripe", TEAL_DK)
    m.paint("TailTip", (255, 255, 255))
    for s_, side in ((-1, "L"), (1, "R")):
        x = s_ * 0.6
        m.add("Antler" + side, "neck", (0.35, 1.8, 0.35), (x, 11.4, -2.9), MAGIC, neon=True)
        m.add("AntlerUp" + side, "neck", (0.3, 1.2, 0.3), (x + s_ * 0.55, 12.7, -2.9), MAGIC, rot=deg(0, 0, -s_ * 30), neon=True)
        m.add("AntlerBranch" + side, "neck", (0.3, 0.3, 1.0), (x, 11.9, -3.35), MAGIC, neon=True)
        m.add("AntlerTop" + side, "neck", (0.3, 0.9, 0.3), (x - s_ * 0.05, 12.65, -2.85), MAGIC, neon=True)
        for i, (y, z) in enumerate(((5.6, -1.4), (4.9, 0.3), (5.7, 1.6), (4.8, 2.4))):
            m.add("Spot%d%s" % (i, side), "root", (0.06, 0.55, 0.55), (s_ * 1.63, y, z), (255, 255, 255), plain=True)
    return m


@pet("Pufferfish", "The Fish puffed up: round and yellow with brown spots and white spines.",
     base="Fish", seat=(0, 7.1, -0.54), neck=((0, 3.6, -3.51), 3.0))
def pufferfish():
    m = Model.load("Fish")
    m.recolor({(60, 132, 232): (250, 210, 70), (36, 88, 184): (220, 150, 40), (222, 240, 255): (255, 246, 214)})
    # fatter: the body and head taller and wider
    m.grow("Body|Belly", (1.25, 1.3, 1.0), about=(0, 0, 0))
    m.grow("Head|HeadBelly|Snout", (1.2, 1.2, 1.0), about=(0, 0, -4.3))
    m.spread("Eye.|Pupil.|Mouth", (1.2, 1.2, 1.0), about=(0, 0, -4.3))
    m.drop("Dorsal")
    lo, hi = m.box("Body|Belly")
    # spines: little wedges standing out of its top and sides
    for i, z in enumerate((-1.8, 0, 1.8)):
        m.add("SpineTop%d" % i, "root", (0.4, 1.0, 0.7), (0, hi[1] + 0.4, z), (255, 255, 255), "WedgePart")
        for s_, side in ((-1, "L"), (1, "R")):
            m.add("Spine%s%d" % (side, i), "root", (0.3, 0.8, 0.6), (s_ * (hi[0] + 0.4), 3.4, z), (255, 255, 255),
                  "WedgePart", rot=deg(0, 0, -s_ * 90))
            m.add("Spot%s%d" % (side, i), "root", (0.06, 0.6, 0.6), (s_ * (hi[0] + 0.03), 2.3 + (i % 2) * 1.6, z + 0.6),
                  (170, 110, 50), plain=True)
    return m


@pet("Shark", "The Fish as a shark: grey with a white belly, a tall dorsal fin and teeth.",
     base="Fish")
def shark():
    m = Model.load("Fish")
    m.recolor({(60, 132, 232): (110, 126, 146), (36, 88, 184): (84, 98, 118), (222, 240, 255): (236, 240, 244),
               (28, 40, 84): (40, 24, 30)})
    m.drop("Eye.")
    m.paint("Pupil.", (12, 12, 16))
    m.grow("Pupil.", (1, 1.2, 1.3))
    m.grow("Dorsal", (1, 1.6, 1.4), about=(0, 4.3, 3.98))
    m.move("Dorsal", (0, 0, -4.6))
    m.find("Dorsal")[0]["bone"] = "root"
    m.grow("Mouth", (1, 2.2, 1))
    for i, x in enumerate((-0.6, -0.2, 0.2, 0.6)):
        m.add("Tooth%d" % i, "neck", (0.25, 0.35, 0.06), (x, 1.65, -7.09), (255, 255, 255), "WedgePart",
              rot=deg(0, 0, 180), plain=True)
    return m


@pet("RoyalSteed", "The Horse dressed for the Red Castle: white, a crimson caparison with gold\n"
     "-- trim, a steel face plate and a red plume.", base="Horse")
def royal_steed():
    m = Model.load("Horse")
    m.recolor({(226, 130, 50): (246, 244, 240), (92, 54, 34): (60, 50, 60), (74, 78, 102): GOLD_DK,
               (242, 150, 192): (220, 200, 200)})
    m.paint("Stripe", CRIMSON)
    # the caparison: a crimson cloth over the body, gold along its bottom edge
    m.add("Cloth", "root", (3.5, 2.2, 6.3), (0, 5.2, 0.3), CRIMSON)
    m.add("ClothTrim", "root", (3.56, 0.35, 6.36), (0, 4.2, 0.3), GOLD)
    m.add("Saddle", "root", (2.0, 0.4, 2.2), (0, 6.6, 0.9), (70, 30, 36))
    # the face plate and plume
    m.add("Chanfron", "neck", (1.4, 0.15, 2.6), (0, 10.55, -3.4), STEEL)
    m.add("Plume", "neck", (0.5, 1.4, 0.9), (0, 11.4, -2.2), CRIMSON)
    m.add("PlumeTip", "neck", (0.5, 0.8, 0.9), (0, 12.5, -1.95), CRIMSON, "WedgePart", rot=deg(0, 180, 0))
    return m


@pet("WarBoar", "The Boar in the Red Castle's barding: dark bristles, a crimson mane, a\n"
     "-- steel helm on its brow and gold tusks.", base="Boar")
def war_boar():
    m = Model.load("Boar")
    m.recolor({(176, 108, 68): (92, 84, 92), (112, 66, 46): CRIMSON, (86, 60, 52): (50, 44, 52),
               (236, 190, 136): STEEL, (254, 246, 222): GOLD, (248, 150, 158): (200, 150, 150)})
    # a helm over the top of its head and a steel plate down its back
    m.add("Helm", "neck", (4.9, 0.7, 3.0), (0, 7.3, -5.4), STEEL)
    m.add("HelmCrest", "neck", (0.6, 1.0, 2.6), (0, 8.1, -5.3), GOLD)
    m.add("BackPlate", "root", (3.6, 0.5, 4.4), (0, 6.5, 1.4), STEEL_DK)
    m.add("BackTrim", "root", (3.66, 0.2, 4.46), (0, 6.25, 1.4), GOLD)
    return m

# ---- new pets ----------------------------------------------------------------------------
def bone(name, parent, pivot, rest=None):
    return {"name": name, "parent": parent, "pivot": list(pivot), "rest": rest}


def hop(length, height, tilt, extra=None):
    """A whole-body hop: up and down once a cycle, tipping forward on the way up."""
    tracks = {"root": {"position": cycle(length, [(0, 0, 0), (0, height, 0), (0, height * 0.6, 0), (0, 0, 0)]),
                       "rotation": cycle(length, [(0, 0, 0), (tilt, 0, 0), (-tilt * 0.4, 0, 0), (0, 0, 0)])}}
    tracks.update(extra or {})
    return (length, tracks)


@pet("Slime", "A dungeon slime: a stepped green cube that squashes and hops, two big\n"
     "-- eyes and a little smile. You ride on its top.", seat=(0, 4.9, 0.4), neck=((0, 3.6, -0.5), 3.2),
     gallopOnly=None)
def slime():
    g, lt, dk = (110, 214, 96), (168, 240, 140), (70, 160, 70)
    m = Model([bone("root", None, (0, 0, 0)), bone("neck", "root", (0, 2.4, 0)), bone("top", "neck", (0, 2.4, 0))],
              [], "")
    m.add("Base", "root", (5.6, 1.2, 5.6), (0, 0.6, 0), dk)
    m.add("Body", "neck", (6.0, 2.0, 6.0), (0, 2.2, 0), g)
    m.add("Top", "top", (5.2, 1.0, 5.2), (0, 3.7, 0), g)
    m.add("Crown", "top", (3.8, 0.6, 3.8), (0, 4.5, 0), lt)
    m.add("Shine", "top", (1.0, 0.06, 1.6), (-1.2, 4.83, -0.6), (230, 255, 220), plain=True)
    m.add("Core", "neck", (2.0, 1.6, 0.05), (0, 2.2, 3.02), dk, plain=True)
    for s_, side in ((-1, "L"), (1, "R")):
        m.add("Eye" + side, "neck", (0.9, 1.5, 0.05), (s_ * 1.1, 2.6, -3.02), (30, 40, 30), plain=True)
        m.add("Glint" + side, "neck", (0.35, 0.45, 0.03), (s_ * 1.1 - 0.15, 2.95, -3.06), (255, 255, 255), plain=True)
        m.add("Drip" + side, "root", (0.8, 0.9, 0.8), (s_ * 2.4, 0.45, -2.4), g)
    m.add("Smile", "neck", (0.9, 0.2, 0.05), (0, 1.75, -3.02), (30, 40, 30), plain=True)
    squash = lambda L, h: {"top": {"position": cycle(L, [(0, -0.35, 0), (0, 0.3, 0), (0, 0.1, 0), (0, -0.35, 0)])},
                           "neck": {"position": cycle(L, [(0, -0.25, 0), (0, 0.2, 0), (0, 0.05, 0), (0, -0.25, 0)])}}
    m.animations = anims({
        "idle": (2.0, {"top": {"position": cycle(2.0, [(0, 0, 0), (0, -0.2, 0)])},
                       "neck": {"position": cycle(2.0, [(0, 0, 0), (0, -0.1, 0)])}}),
        "walk": hop(0.8, 1.2, -6, squash(0.8, 1.2)),
        "gallop": hop(0.55, 2.4, -10, squash(0.55, 2.4)),
    })
    return m


@pet("Mimic", "A treasure chest that bit back: wood and gold bands, a lid that chomps\n"
     "-- over rows of teeth, a long tongue and glowing eyes in the dark, on four stubby legs.",
     seat=(0, 5.6, 1.0), neck=((0, 3.6, -0.4), 3.2))
def mimic():
    wood, wood_dk, band, inside = (156, 98, 56), (112, 68, 40), GOLD, (70, 14, 30)
    legc = (96, 60, 110)
    m = Model([bone("root", None, (0, 1.2, 0)), bone("neck", "root", (0, 3.4, 1.7), "CFrame.Angles(0.45, 0, 0)")]
              + [bone("Leg" + k, "root", (sx * 1.5, 1.2, sz * 1.0)) for k, sx, sz in
                 (("FL", -1, -1), ("FR", 1, -1), ("HL", -1, 1), ("HR", 1, 1))], [], "")
    # the chest
    m.add("Box", "root", (4.6, 2.2, 3.4), (0, 2.3, 0), wood)
    m.add("BoxFloor", "root", (4.64, 0.3, 3.44), (0, 1.35, 0), wood_dk)
    for i, x in enumerate((-1.6, 1.6)):
        m.add("Band%d" % i, "root", (0.5, 2.24, 3.48), (x, 2.3, 0), band)
    m.add("Inside", "root", (4.2, 0.05, 3.0), (0, 3.36, 0), inside, plain=True)
    m.add("Tongue", "root", (1.2, 0.3, 3.0), (0, 3.4, -1.6), (232, 92, 124))
    m.add("TongueTip", "root", (1.0, 0.25, 0.8), (0, 3.0, -3.2), (232, 92, 124), rot=deg(-45, 0, 0))
    for i in range(5):
        x = -1.8 + i * 0.9
        m.add("ToothLow%d" % i, "root", (0.4, 0.5, 0.4), (x, 3.6, -1.45), (250, 246, 230), "WedgePart", rot=deg(0, 180, 0))
        m.add("ToothUp%d" % i, "neck", (0.4, 0.5, 0.4), (x + 0.45 if i < 4 else x - 0.45, 3.65, -1.45), (250, 246, 230), "WedgePart", rot=deg(180, 0, 0))
    # the lid, hinged at the back
    m.add("Lid", "neck", (4.6, 1.1, 3.4), (0, 3.95, 0), wood)
    m.add("LidTop", "neck", (4.0, 0.5, 3.0), (0, 4.75, 0), wood)
    for i, x in enumerate((-1.6, 1.6)):
        m.add("LidBand%d" % i, "neck", (0.5, 1.14, 3.48), (x, 3.95, 0), band)
        m.add("LidBandTop%d" % i, "neck", (0.5, 0.54, 3.04), (x, 4.75, 0), band)
    m.add("Lock", "neck", (0.7, 0.8, 0.2), (0, 3.75, -1.78), band)
    m.add("Keyhole", "neck", (0.2, 0.35, 0.05), (0, 3.7, -1.9), (40, 24, 20), plain=True)
    m.add("LidInside", "neck", (4.2, 0.05, 3.0), (0, 3.42, 0), inside, plain=True)
    for s_, side in ((-1, "L"), (1, "R")):
        m.add("Eye" + side, "neck", (0.7, 0.5, 0.05), (s_ * 1.05, 4.15, -1.73), (255, 220, 80), neon=True)
        m.add("Pupil" + side, "neck", (0.2, 0.5, 0.03), (s_ * 1.05, 4.15, -1.77), (60, 20, 10), plain=True)
    for k, sx, sz in (("FL", -1, -1), ("FR", 1, -1), ("HL", -1, 1), ("HR", 1, 1)):
        m.add("Leg" + k, "Leg" + k, (0.9, 1.2, 0.9), (sx * 1.5, 0.6, sz * 1.0), legc)
        m.add("Foot" + k, "Leg" + k, (1.0, 0.3, 1.2), (sx * 1.5, 0.15, sz * 1.0 - 0.15), (70, 42, 82))
    def legs(L, a):
        f = cycle(L, [(a, 0, 0), (0, 0, 0), (-a, 0, 0), (0, 0, 0)])
        b = cycle(L, [(-a, 0, 0), (0, 0, 0), (a, 0, 0), (0, 0, 0)])
        return {"LegFL": {"rotation": f}, "LegHR": {"rotation": f}, "LegFR": {"rotation": b}, "LegHL": {"rotation": b}}
    def chomp(L, a):
        return {"neck": {"rotation": cycle(L, [(0, 0, 0), (a, 0, 0), (0, 0, 0), (a * 0.6, 0, 0)])}}
    walk = legs(0.6, 30)
    walk.update(chomp(0.6, 12))
    walk["root"] = {"position": cycle(0.6, [(0, 0, 0), (0, 0.25, 0), (0, 0, 0), (0, 0.25, 0)])}
    run = legs(0.4, 45)
    run.update(chomp(0.4, 22))
    run["root"] = {"position": cycle(0.4, [(0, 0, 0), (0, 0.6, 0), (0, 0, 0), (0, 0.6, 0)]),
                   "rotation": cycle(0.4, [(-4, 0, 0), (2, 0, 0)])}
    m.animations = anims({
        "idle": (3.0, {"neck": {"rotation": [(0, 0, 0, 0), (1.9, 0, 0, 0), (2.1, 25, 0, 0), (2.3, 0, 0, 0), (2.45, 15, 0, 0), (2.6, 0, 0, 0), (3.0, 0, 0, 0)]}}),
        "walk": (0.6, walk),
        "gallop": (0.4, run),
    })
    return m


@pet("ChessKnight", "A giant chess knight from the Red Castle's hall: ivory, a crimson mane\n"
     "-- and gold rings, hopping on its round base like the piece it is.",
     seat=(0, 5.6, 1.5), neck=((0, 5.6, -0.6), 2.0))
def chess_knight():
    ivory, ivory_dk, mane = (242, 234, 216), (214, 202, 180), CRIMSON
    m = Model([bone("root", None, (0, 0, 0)), bone("neck", "root", (0, 4.2, 0))], [], "")
    m.add("Base", "root", (5.0, 0.8, 5.0), (0, 0.4, 0), ivory_dk)
    m.add("BaseRing", "root", (4.4, 0.4, 4.4), (0, 1.0, 0), GOLD)
    m.add("Base2", "root", (3.8, 0.7, 3.8), (0, 1.55, 0), ivory)
    m.add("Column", "root", (3.0, 2.4, 3.6), (0, 3.1, 0.3), ivory)
    m.add("Collar", "root", (3.3, 0.4, 3.9), (0, 4.4, 0.3), GOLD)
    m.add("Back", "root", (2.8, 0.8, 2.0), (0, 5.0, 1.3), ivory)
    m.add("Neck", "neck", (2.6, 3.4, 2.2), (0, 6.2, -0.1), ivory)
    m.add("Head", "neck", (2.6, 2.0, 2.6), (0, 7.8, -1.2), ivory)
    m.add("Snout", "neck", (2.2, 1.4, 1.8), (0, 7.3, -3.2), ivory)
    m.add("Bridge", "neck", (2.2, 0.6, 1.2), (0, 8.3, -3.5), ivory, "WedgePart")
    m.add("Jaw", "neck", (2.0, 0.6, 1.6), (0, 6.4, -2.6), ivory_dk)
    m.add("NostrilL", "neck", (0.4, 0.3, 0.05), (-0.5, 7.4, -4.12), (90, 80, 70), plain=True)
    m.add("NostrilR", "neck", (0.4, 0.3, 0.05), (0.5, 7.4, -4.12), (90, 80, 70), plain=True)
    for s_, side in ((-1, "L"), (1, "R")):
        m.add("Eye" + side, "neck", (0.05, 0.7, 0.7), (s_ * 1.32, 8.0, -1.9), (40, 30, 40), plain=True)
        m.add("Ear" + side, "neck", (0.6, 1.1, 0.8), (s_ * 0.8, 9.3, -0.6), ivory, "WedgePart", rot=deg(0, 180, 0))
    for i in range(5):
        m.add("Mane%d" % i, "neck", (0.8, 0.9, 0.9), (0, 8.9 - i * 0.85, 0.2 + i * 0.32), mane)
    m.animations = anims({
        "idle": (2.4, {"neck": {"rotation": cycle(2.4, [(0, 0, 0), (4, 0, 0)])}}),
        "walk": hop(0.7, 1.4, -8, {"neck": {"rotation": cycle(0.7, [(0, 0, 0), (-6, 0, 0), (4, 0, 0), (0, 0, 0)])}}),
        "gallop": hop(0.5, 2.6, -12, {"neck": {"rotation": cycle(0.5, [(0, 0, 0), (-10, 0, 0), (6, 0, 0), (0, 0, 0)])}}),
    })
    return m


@pet("Shroom", "A walking mushroom from the Magic Circle: a blue stepped cap with glowing\n"
     "-- spots over a cream stem with a face, on two little feet.",
     seat=(0, 8.0, 0.2), neck=((0, 4.0, 0), 2.0))
def shroom():
    cap, cap_lt, stem, gill = (92, 112, 236), (130, 150, 250), (246, 238, 220), (214, 206, 236)
    m = Model([bone("root", None, (0, 1.0, 0)), bone("neck", "root", (0, 4.4, 0)),
               bone("LegL", "root", (-0.8, 1.0, 0)), bone("LegR", "root", (0.8, 1.0, 0))], [], "")
    m.add("Stem", "root", (2.8, 3.6, 2.8), (0, 2.8, 0), stem)
    m.add("StemTop", "root", (2.4, 0.6, 2.4), (0, 4.9, 0), stem)
    for s_, side in ((-1, "L"), (1, "R")):
        m.add("Eye" + side, "root", (0.5, 0.8, 0.05), (s_ * 0.6, 3.4, -1.42), (40, 40, 60), plain=True)
        m.add("Glint" + side, "root", (0.2, 0.25, 0.03), (s_ * 0.6 - 0.1, 3.6, -1.45), (255, 255, 255), plain=True)
        m.add("Cheek" + side, "root", (0.5, 0.3, 0.05), (s_ * 1.0, 2.8, -1.42), (250, 170, 190), plain=True)
        m.add("Foot" + side, "Leg" + side, (1.1, 1.0, 1.6), (s_ * 0.8, 0.5, -0.2), stem)
    m.add("Mouth", "root", (0.5, 0.15, 0.05), (0, 2.75, -1.42), (40, 40, 60), plain=True)
    m.add("Gills", "neck", (5.6, 0.2, 5.6), (0, 5.25, 0), gill)
    m.add("Cap", "neck", (6.2, 1.2, 6.2), (0, 5.95, 0), cap)
    m.add("Cap2", "neck", (5.0, 0.8, 5.0), (0, 6.95, 0), cap)
    m.add("Cap3", "neck", (3.4, 0.5, 3.4), (0, 7.6, 0), cap_lt)
    for i, (x, y, z, w) in enumerate(((-2.0, 6.2, -3.12, 0.9), (1.4, 6.0, -3.12, 0.7), (0.0, 7.1, -2.52, 0.8))):
        m.add("Spot%d" % i, "neck", (w, w * 0.7, 0.06), (x, y, z), MAGIC, neon=True)
        m.add("SpotBack%d" % i, "neck", (w, w * 0.7, 0.06), (-x, y, -z), MAGIC, neon=True)
    for i, (x, z) in enumerate(((-2.0, 0.8), (1.1, -0.6), (0.4, 2.0))):
        m.add("SpotTop%d" % i, "neck", (0.8, 0.06, 0.8), (x, 7.36 if abs(x) > 1.7 or abs(z) > 1.7 else 7.88, z), MAGIC, neon=True)
    def steps(L, a, h):
        return {"LegL": {"rotation": cycle(L, [(a, 0, 0), (-a, 0, 0)])},
                "LegR": {"rotation": cycle(L, [(-a, 0, 0), (a, 0, 0)])},
                "root": {"position": cycle(L, [(0, 0, 0), (0, h, 0), (0, 0, 0), (0, h, 0)]),
                         "rotation": cycle(L, [(0, 0, 4), (0, 0, 0), (0, 0, -4), (0, 0, 0)])},
                "neck": {"rotation": cycle(L, [(0, 0, -3), (0, 0, 0), (0, 0, 3), (0, 0, 0)])}}
    m.animations = anims({
        "idle": (2.6, {"neck": {"rotation": cycle(2.6, [(0, 0, 0), (0, 0, 3), (0, 0, 0), (0, 0, -3)])}}),
        "walk": (0.7, steps(0.7, 30, 0.3)),
        "gallop": (0.45, steps(0.45, 45, 0.8)),
    })
    return m


@pet("Seahorse", "A big coral seahorse from the Ocean Trench: a curled tail, a long snout,\n"
     "-- a crown of spines and little fins. It swims upright, bobbing; you ride behind its head.",
     seat=(0, 7.4, 1.6), neck=((0, 7.0, -0.4), 1.8))
def seahorse():
    body, belly, fin = (250, 146, 84), (255, 214, 150), (220, 96, 66)
    m = Model([bone("root", None, (0, 4.6, 0)), bone("neck", "root", (0, 6.0, 0)), bone("Tail", "root", (0, 3.2, 0.4)),
               bone("FinL", "root", (-1.3, 5.6, 0.2)), bone("FinR", "root", (1.3, 5.6, 0.2))], [], "")
    m.add("Body", "root", (2.8, 3.2, 2.6), (0, 4.6, 0.2), body)
    m.add("Belly", "root", (2.0, 2.6, 0.3), (0, 4.5, -1.2), belly)
    m.add("Saddle", "root", (2.2, 0.8, 1.8), (0, 6.6, 1.4), body)
    for i, y in enumerate((3.6, 4.4, 5.2)):
        m.add("Ring%d" % i, "root", (2.06, 0.15, 0.32), (0, y, -1.22), (240, 180, 120), plain=True)
    m.add("Dorsal", "root", (0.3, 1.8, 1.2), (0, 4.6, 2.05), fin, "WedgePart", rot=deg(0, 180, 0))
    m.add("Tail1", "Tail", (2.0, 1.8, 1.8), (0, 2.4, 0.9), body)
    m.add("Tail2", "Tail", (1.6, 1.4, 1.5), (0, 1.1, 1.5), body)
    m.add("Tail3", "Tail", (1.3, 1.1, 1.2), (0, 0.55, 0.5), body)
    m.add("Tail4", "Tail", (1.0, 1.0, 1.0), (0, 0.9, -0.4), body)
    m.add("Tail5", "Tail", (0.8, 0.8, 0.8), (0, 1.7, -0.6), fin)
    m.add("Chest", "neck", (2.4, 1.8, 2.3), (0, 6.9, -0.2), body)
    m.add("Head", "neck", (2.4, 2.2, 2.8), (0, 8.6, -0.7), body)
    m.add("Snout", "neck", (1.0, 1.0, 2.4), (0, 8.3, -3.2), body)
    m.add("SnoutTip", "neck", (1.3, 1.3, 0.5), (0, 8.3, -4.5), fin)
    for i, z in enumerate((-1.2, -0.2, 0.6)):
        m.add("Crown%d" % i, "neck", (0.5, 1.0 - i * 0.15, 0.6), (0, 10.15 - i * 0.1, z), fin, "WedgePart", rot=deg(0, 180, 0))
    for s_, side in ((-1, "L"), (1, "R")):
        m.add("Eye" + side, "neck", (0.05, 0.9, 0.9), (s_ * 1.22, 8.9, -1.2), (255, 255, 255), plain=True)
        m.add("Pupil" + side, "neck", (0.08, 0.55, 0.45), (s_ * 1.24, 8.8, -1.4), PUPIL, plain=True)
        m.add("Fin" + side, "Fin" + side, (0.15, 1.0, 1.2), (s_ * 1.48, 5.6, 0.4), fin)
    def swim(L, h, pitch, fin_a):
        return {"root": {"position": cycle(L, [(0, 0, 0), (0, h, 0)]),
                         "rotation": cycle(L, [(pitch, 0, 0), (pitch * 0.4, 0, 0)])},
                "Tail": {"rotation": cycle(L, [(0, 0, 0), (-14, 0, 0)])},
                "neck": {"rotation": cycle(L, [(0, 0, 0), (5, 0, 0)])},
                "FinL": {"rotation": cycle(L / 2, [(0, -fin_a, 0), (0, fin_a, 0)])},
                "FinR": {"rotation": cycle(L / 2, [(0, fin_a, 0), (0, -fin_a, 0)])}}
    m.animations = anims({
        "idle": (2.4, swim(2.4, 0.4, 0, 20)),
        "walk": (1.0, swim(1.0, 0.8, -8, 35)),
        "gallop": (0.6, swim(0.6, 1.4, -16, 45)),
    })
    return m


@pet("Octopus", "A deep violet octopus from the Ocean Trench: a big round mantle with pale\n"
     "-- spots, wide eyes and eight curling arms that ripple as it walks.",
     seat=(0, 7.6, 0.6), neck=((0, 3.4, -0.2), 3.0))
def octopus():
    skin, skin_lt, under = (150, 70, 200), (204, 150, 236), (236, 196, 240)
    bones = [bone("root", None, (0, 2.6, 0)), bone("neck", "root", (0, 2.6, 0))]
    arms = []
    for k in range(8):
        a = 22.5 + 45 * k
        r = math.radians(a)
        pivot = (1.7 * math.sin(r), 1.6, 1.7 * math.cos(r))
        bones.append(bone("Arm%d" % k, "root", pivot, "CFrame.Angles(0, %s, 0)" % ("%.5f" % r)))
        arms.append(("Arm%d" % k, pivot))
    m = Model(bones, [], "")
    m.add("Mantle", "neck", (4.6, 3.6, 4.8), (0, 4.4, 0.4), skin)
    m.add("MantleTop", "neck", (3.8, 1.4, 4.0), (0, 6.6, 0.6), skin)
    m.add("MantleBack", "neck", (3.2, 2.6, 1.2), (0, 5.2, 3.2), skin)
    m.add("Skirt", "root", (4.2, 1.4, 4.2), (0, 2.0, 0), skin)
    for i, (x, y, z) in enumerate(((-1.4, 5.6, 2.83), (1.0, 6.4, 2.6), (0.6, 4.6, 2.83))):
        m.add("Spot%d" % i, "neck", (0.8, 0.8, 0.05), (x, y, z + 0.0), skin_lt, plain=True)
    for s_, side in ((-1, "L"), (1, "R")):
        m.add("Spot" + side, "neck", (0.05, 0.9, 0.9), (s_ * 2.33, 5.4, 1.4), skin_lt, plain=True)
        m.add("Eye" + side, "neck", (1.3, 1.4, 0.05), (s_ * 1.05, 4.7, -2.02), (255, 255, 255), plain=True)
        m.add("Pupil" + side, "neck", (0.9, 0.4, 0.03), (s_ * 1.05, 4.6, -2.06), PUPIL, plain=True)
    for name, (px, py, pz) in arms:
        # each arm laid out along +Z from its pivot; the bone's rest turns it outward
        m.add(name + "A", name, (1.0, 0.9, 2.4), (px, 1.1, pz + 1.0), skin)
        m.add(name + "B", name, (0.8, 0.7, 1.8), (px, 0.4, pz + 2.9), skin, rot=deg(-12, 0, 0))
        m.add(name + "Tip", name, (0.6, 0.6, 0.8), (px, 0.9, pz + 3.9), skin_lt, rot=deg(-45, 0, 0))
        m.add(name + "Under", name, (0.7, 0.05, 2.0), (px, 0.62, pz + 1.0), under, plain=True)
    def ripple(L, a, h):
        tr = {"root": {"position": cycle(L, [(0, 0, 0), (0, h, 0)])}}
        for k in range(8):
            ph = k % 2
            keys = cycle(L, [(-a, 0, 0), (a, 0, 0)] if ph else [(a, 0, 0), (-a, 0, 0)])
            tr["Arm%d" % k] = {"rotation": keys}
        tr["neck"] = {"rotation": cycle(L, [(3, 0, 0), (-3, 0, 0)])}
        return tr
    m.animations = anims({
        "idle": (2.4, ripple(2.4, 6, 0.3)),
        "walk": (0.8, ripple(0.8, 16, 0.5)),
        "gallop": (0.5, ripple(0.5, 24, 1.0)),
    })
    return m


def write_all(only=None):
    for kind, spec in PETS.items():
        if only and kind not in only:
            continue
        m = spec["build"]()
        if m is not None:
            source = spec["base"] or "new"
            m.write(os.path.join(ANIMALS, kind + "Model.luau"),
                    "-- GENERATED by tools/later_pets.py (%s). Don't edit by hand: change it there\n"
                    "-- and rerun. Units are studs, rest pose, feet on Y = 0, facing -Z." % (
                        "from the %s" % source if spec["base"] else "a new pet"))
        write_class(kind, spec)
        print("wrote", kind)


def vec(v):
    return "Vector3.new(%s)" % ", ".join(("%g" % x) for x in v)


def write_class(kind, spec):
    base = spec["base"]
    lines = ["-- %s: %s" % (kind, spec["note"]), "-- Made by tools/later_pets.py.", ""]
    lines.append("local Horse = require(script.Parent.Horse)")
    if spec.get("size_of"):
        lines.append("local %s = require(script.Parent.%s)" % (spec["size_of"][0], spec["size_of"][0]))
    lines.append("local %sModel = require(script.Parent.%sModel)" % (kind, kind))
    lines.append("")
    pts = []
    if spec.get("seat"):
        pts.append("\tseat = %s," % vec(spec["seat"]))
    if spec.get("neck"):
        c, r = spec["neck"]
        pts.append("\tneck = { center = %s, radius = %g }," % (vec(c), r))
    if not spec.get("seat") and base:
        # the base pet's seat and neck loop, read from its class
        src = open(os.path.join(ANIMALS, base + ".luau")).read()
        for line in src.splitlines():
            s = line.strip()
            if s.startswith("seat =") or s.startswith("neck ="):
                pts.append("\t" + s)
    if spec.get("size"):
        pts.append("\tsize = %g," % spec["size"])
    if spec.get("size_of"):
        pts.append("\tsize = %s.size * %g," % spec["size_of"])
    for k in ("seatOnNeck", "gallopOnly"):
        if spec.get(k):
            pts.append("\t%s = true," % k)
    rarity = rarity_of(kind)
    if pts:
        lines.append('return Horse.variant("%s", %sModel, "%s", {' % (kind, kind, rarity))
        lines += pts
        lines.append("})")
    else:
        lines.append('return Horse.variant("%s", %sModel, "%s")' % (kind, kind, rarity))
    open(os.path.join(ANIMALS, kind + ".luau"), "w").write("\n".join(lines) + "\n")


def rarity_of(kind):
    import re
    src = open(os.path.join(HERE, "..", "src", "shared", "Config.luau")).read()
    m = re.search(r"\n\t\t%s = \{ Rarity = \"(\w+)\"" % kind, src)
    return m.group(1) if m else "Common"


if __name__ == "__main__":
    write_all(sys.argv[1:] or None)
