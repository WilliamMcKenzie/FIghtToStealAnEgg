"""Every boss model made in Python (tools/boss_forge.py has the rules and the format).
The roster and each attack's windup: /mnt/project-files/boss-roster/design.md (QM, Oct 30).

  python3 tools/boss_designs.py [Name ...]   # writes src/shared/Animals/<Name>Model.luau
  python3 tools/render_boss.py [Name ...]    # draws previews/bosses/<name>.png and .gif
"""

import sys

from boss_forge import Model, bob, wave

DARK = (30, 22, 34)  # eyes and mouths, as the Cactus Boss's
WHITE = (250, 246, 236)
GOLD = (255, 200, 60)
GOLD_DARK = (214, 150, 40)


def gallop_from(m, walk_tracks, length):
    """A boss's gallop: its walk, quicker (bosses barely gallop; Horse needs one)."""
    k = length / m.anims["walk"]["length"]
    tracks = {}
    for bone, tr in walk_tracks.items():
        tracks[bone] = {key: [(t * k, x * 1.3, y * 1.3, z * 1.3) for t, x, y, z in keys] for key, keys in tr.items()}
    m.anim("gallop", length, tracks)


# ---------------------------------------------------------------------------------------
# Desert: Scorpion King (Archero's scorpion). Low and wide, two big pincers, a tail arched
# over its back to a red stinger, a little gold crown. Stab: the tail curls back, then whips
# over its head down the red line. Pinch: both pincers open wide and snap shut.
# ---------------------------------------------------------------------------------------
def scorpion_king():
    m = Model("ScorpionKing", "Scorpion King: Desert boss. Bones: root, ClawL, ClawR, Tail, Stinger.")
    SAND = (226, 152, 80)
    PLATE = (180, 104, 54)
    BELLY = (246, 206, 140)
    RED = (206, 52, 44)
    m.bone("root", None, (0, 3, 0))
    m.bone("ClawL", "root", (-3.1, 2.6, -4.4))
    m.bone("ClawR", "root", (3.1, 2.6, -4.4))
    m.bone("Tail", "root", (0, 4.2, 4.2))
    m.bone("Stinger", "Tail", (0, 11.2, 4.8))

    # body: one wide block, a lighter belly, three dark plates across its back, a head block
    m.block("Body", "root", (7.6, 3.2, 9), (0, 3.2, 0), SAND)
    m.block("Belly", "root", (7, 0.7, 8.4), (0, 1.5, 0), BELLY)
    for i, z in enumerate((-2.6, 0, 2.6)):
        m.block("Plate%d" % i, "root", (8, 0.5, 1.3), (0, 4.85, z), PLATE)
    m.block("Head", "root", (5.4, 2.6, 2), (0, 3, -5.2), SAND)
    m.eyes("root", 1.3, 3.5, -6.2, 0.9, 1.1, DARK)
    m.block("Brow", "root", (4.4, 0.5, 0.4), (0, 4.25, -6.3), PLATE)
    # (the crown: a gold band and three points)
    m.block("Crown", "root", (2.8, 0.6, 1.6), (0, 4.6, -5.1), GOLD)
    for i, x in enumerate((-1, 0, 1)):
        m.wedge("CrownPt%d" % i, "root", (0.5, 0.8 if x else 1.1, 0.5), (x, 5.3 if x else 5.45, -5.6), GOLD, r=(0, 180, 0))
    # six legs, no bones: they stay planted and the body sways over them
    for i, z in enumerate((-2.8, 0, 2.8)):
        m.pair(m.block, "Leg%d" % i, "root", (3.2, 0.9, 0.9), (-4.9, 2.3, z), PLATE, r=(0, 0, 32))
        m.pair(m.block, "Foot%d" % i, "root", (0.9, 1.9, 0.9), (-6.2, 0.95, z), PLATE)

    # pincers: an arm angled out and forward, a palm, two fingers with a gap between
    for side, s in (("L", -1), ("R", 1)):
        b = "Claw" + side
        m.block("Arm" + side, b, (1.5, 1.3, 3.4), (s * 3.9, 2.6, -5.8), SAND, r=(0, -s * 22, 0))
        m.block("Palm" + side, b, (2.8, 2.2, 3), (s * 5.1, 2.6, -8.4), SAND)
        m.block("FingerOut" + side, b, (1, 1.6, 2.6), (s * 5.95, 2.7, -11.1), PLATE)
        m.block("FingerIn" + side, b, (0.9, 1.3, 2), (s * 4.35, 2.6, -10.8), PLATE)

    # tail: three blocks arching up and over the back, then the stinger bulb and its barb
    m.block("Tail1", "Tail", (2.7, 2.6, 3), (0, 5.3, 5.4), SAND, r=(-35, 0, 0))
    m.block("Tail2", "Tail", (2.5, 3, 2.5), (0, 7.8, 6.3), PLATE)
    m.block("Tail3", "Tail", (2.3, 2.6, 2.5), (0, 10.2, 5.7), SAND, r=(30, 0, 0))
    m.block("Bulb", "Stinger", (2.4, 2.2, 2.6), (0, 11.6, 3.8), RED)
    m.wedge("Barb", "Stinger", (0.9, 1.3, 2.2), (0, 11, 1.8), DARK, r=(-30, 0, 0))

    m.anim("idle", 2.4, {
        "root": {"p": bob(2.4, 0.12)},
        "ClawL": {"r": wave(2.4, (4, 5, 0))},
        "ClawR": {"r": wave(2.4, (4, -5, 0), 0.5)},
        "Tail": {"r": wave(2.4, (3, 0, 4), 0.25)},
        "Stinger": {"r": wave(2.4, (8, 0, 0), 0.4)},
    })
    walk = {
        "root": {"p": bob(0.8, 0.25, double=True), "r": wave(0.8, (0, 3, 3))},
        "ClawL": {"r": wave(0.8, (8, 4, 0))},
        "ClawR": {"r": wave(0.8, (-8, 4, 0))},
        "Tail": {"r": wave(0.8, (4, 0, -5), 0.25)},
        "Stinger": {"r": wave(0.8, (6, 0, 0), 0.5)},
    }
    m.anim("walk", 0.8, walk)
    gallop_from(m, walk, 0.5)
    # stab (0.8s windup): the tail curls back and up, then at the hit whips forward over
    # its head, stinger first, and holds there a moment before easing back
    m.anim("stab", 1.5, {
        "root": {"r": [(0, 0, 0, 0), (0.65, 6, 0, 0), (0.8, -8, 0, 0), (1.05, -6, 0, 0), (1.5, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.65, 0, 0, 0.5), (0.8, 0, -0.3, -0.8), (1.5, 0, 0, 0)]},
        "Tail": {"r": [(0, 0, 0, 0), (0.5, 24, 0, 0), (0.68, 28, 0, 0), (0.8, -52, 0, 0), (1.05, -46, 0, 0), (1.5, 0, 0, 0)]},
        "Stinger": {"r": [(0, 0, 0, 0), (0.5, 34, 0, 0), (0.68, 40, 0, 0), (0.8, -70, 0, 0), (1.05, -60, 0, 0), (1.5, 0, 0, 0)]},
        "ClawL": {"r": [(0, 0, 0, 0), (0.68, 0, 18, 0), (0.8, 0, -6, 0), (1.5, 0, 0, 0)]},
        "ClawR": {"r": [(0, 0, 0, 0), (0.68, 0, -18, 0), (0.8, 0, 6, 0), (1.5, 0, 0, 0)]},
    }, hit=0.8)
    # pinch (0.5s windup): pincers raised and flung wide, then snapped together at the hit
    m.anim("pinch", 0.95, {
        "ClawL": {"r": [(0, 0, 0, 0), (0.4, 14, 32, 0), (0.5, -6, -20, 0), (0.65, -4, -16, 0), (0.95, 0, 0, 0)]},
        "ClawR": {"r": [(0, 0, 0, 0), (0.4, 14, -32, 0), (0.5, -6, 20, 0), (0.65, -4, 16, 0), (0.95, 0, 0, 0)]},
        "root": {"r": [(0, 0, 0, 0), (0.4, 4, 0, 0), (0.5, -4, 0, 0), (0.95, 0, 0, 0)]},
    }, hit=0.5)
    return m


# ---------------------------------------------------------------------------------------
# Tundra: Frost Golem (Archero's stone golem). A chunky glacier block with a small head sunk
# into its chest, two huge arms hanging to the ground and ice crystals on its shoulders.
# Leap: crouches with its arms swung back, launches arms up, comes down fists first. Slam:
# both fists raised overhead and smashed into the ground in front of it.
# ---------------------------------------------------------------------------------------
def frost_golem():
    m = Model("FrostGolem", "Frost Golem: Tundra boss. Bones: root, ArmL, ArmR, LegL, LegR.")
    ICE = (178, 208, 248)
    ICE_DARK = (132, 168, 224)
    SNOW = (236, 242, 250)
    CRYSTAL = (196, 238, 255)
    m.bone("root", None, (0, 4.4, 0))
    m.bone("ArmL", "root", (-5.2, 10.4, 0))
    m.bone("ArmR", "root", (5.2, 10.4, 0))
    m.bone("LegL", "root", (-2.3, 4.2, 0.2))
    m.bone("LegR", "root", (2.3, 4.2, 0.2))

    m.block("Body", "root", (8.2, 6.6, 5.8), (0, 8.1, 0.2), ICE)
    m.block("Chest", "root", (6.2, 3.4, 0.5), (0, 7.4, -2.85), ICE_DARK)  # (a darker plate down its front)
    m.block("Hips", "root", (6.4, 1.6, 4.8), (0, 4.6, 0.2), ICE_DARK)
    m.block("Snow", "root", (8.6, 0.8, 6.2), (0, 11.6, 0.2), SNOW)  # (snow settled on its back)
    m.block("Head", "root", (3.6, 2.9, 3.2), (0, 11.2, -2.5), ICE)
    m.block("Brow", "root", (4, 0.8, 0.8), (0, 12.2, -4.1), ICE_DARK)
    m.eyes("root", 0.85, 11.2, -4.1, 0.9, 0.5, CRYSTAL, name="Glow")
    for part in m.parts[-2:]:
        part["neon"] = True
    for side, s in (("L", -1), ("R", 1)):
        b = "Arm" + side
        m.block("Shoulder" + side, b, (3.8, 2.4, 3.8), (s * 5.6, 10.6, 0), ICE_DARK)
        m.block("Upper" + side, b, (2.8, 4.8, 3), (s * 5.8, 7.6, 0), ICE)
        m.block("Fist" + side, b, (3.8, 3.4, 4), (s * 6, 4.1, -0.3), ICE)
        m.block("Knuckle" + side, b, (3.9, 0.9, 1.4), (s * 6, 4.9, -2), SNOW)
        m.block("Crystal" + side, b, (1.3, 3, 1.3), (s * 5.2, 12.6, 0.4), CRYSTAL, r=(10, 45, s * -14))
        m.block("Crystal2" + side, b, (1, 2, 1), (s * 6.6, 12.2, -0.6), CRYSTAL, r=(-12, 45, s * -30))
        m.block("Leg" + side, "Leg" + side, (2.8, 4.2, 3.2), (s * 2.3, 2.1, 0.2), ICE_DARK)
        m.block("Toe" + side, "Leg" + side, (3, 0.8, 1.2), (s * 2.3, 0.4, -1.6), SNOW)

    m.anim("idle", 2.8, {
        "root": {"p": bob(2.8, 0.18)},
        "ArmL": {"r": wave(2.8, (3, 0, 2))},
        "ArmR": {"r": wave(2.8, (3, 0, -2), 0.1)},
    })
    walk = {
        "root": {"p": bob(1.0, 0.35, 0.25, double=True), "r": wave(1.0, (0, 4, 3))},
        "LegL": {"r": wave(1.0, (22, 0, 0))},
        "LegR": {"r": wave(1.0, (-22, 0, 0))},
        "ArmL": {"r": wave(1.0, (-16, 0, 0))},
        "ArmR": {"r": wave(1.0, (16, 0, 0))},
    }
    m.anim("walk", 1.0, walk)
    gallop_from(m, walk, 0.65)
    # leap (0.7s windup): sinks into a crouch with its arms swung back, then launches with its
    # arms flung up (the hit: it leaves the ground), holds them up through the jump, and
    # comes down fists first
    m.anim("leap", 1.8, {
        "root": {"p": [(0, 0, 0, 0), (0.55, 0, -1.2, 0), (0.7, 0, 1.2, 0), (1.15, 0, 0.6, 0), (1.35, 0, -0.8, 0), (1.8, 0, 0, 0)],
                 "r": [(0, 0, 0, 0), (0.55, -12, 0, 0), (0.7, 6, 0, 0), (1.15, 4, 0, 0), (1.35, -14, 0, 0), (1.8, 0, 0, 0)]},
        "ArmL": {"r": [(0, 0, 0, 0), (0.55, -40, 0, 0), (0.7, 150, 0, 10), (1.15, 160, 0, 10), (1.35, 60, 0, 0), (1.8, 0, 0, 0)]},
        "ArmR": {"r": [(0, 0, 0, 0), (0.55, -40, 0, 0), (0.7, 150, 0, -10), (1.15, 160, 0, -10), (1.35, 60, 0, 0), (1.8, 0, 0, 0)]},
        "LegL": {"r": [(0, 0, 0, 0), (0.55, 12, 0, 0), (0.7, -20, 0, 0), (1.15, 10, 0, 0), (1.35, 0, 0, 0)]},
        "LegR": {"r": [(0, 0, 0, 0), (0.55, 12, 0, 0), (0.7, -20, 0, 0), (1.15, 10, 0, 0), (1.35, 0, 0, 0)]},
    }, hit=0.7)
    # slam (0.9s windup): both fists rise overhead, it leans back, then smashes them into the
    # ground in front at the hit and stays bent over a moment
    m.anim("slam", 1.6, {
        "root": {"r": [(0, 0, 0, 0), (0.75, 10, 0, 0), (0.9, -16, 0, 0), (1.2, -14, 0, 0), (1.6, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.75, 0, 0.4, 0.6), (0.9, 0, -0.6, -0.8), (1.2, 0, -0.5, -0.6), (1.6, 0, 0, 0)]},
        "ArmL": {"r": [(0, 0, 0, 0), (0.6, 160, 0, -8), (0.75, 170, 0, -8), (0.9, 62, 0, 14), (1.2, 58, 0, 12), (1.6, 0, 0, 0)]},
        "ArmR": {"r": [(0, 0, 0, 0), (0.6, 160, 0, 8), (0.75, 170, 0, 8), (0.9, 62, 0, -14), (1.2, 58, 0, -12), (1.6, 0, 0, 0)]},
        "LegL": {"r": [(0, 0, 0, 0), (0.75, -8, 0, 0), (0.9, 14, 0, 0), (1.2, 12, 0, 0), (1.6, 0, 0, 0)]},
        "LegR": {"r": [(0, 0, 0, 0), (0.75, -8, 0, 0), (0.9, 14, 0, 0), (1.2, 12, 0, 0), (1.6, 0, 0, 0)]},
    }, hit=0.9)
    return m


# ---------------------------------------------------------------------------------------
# Tundra: Blizzard Owl. A round snow-white owl hovering off the ground: a ball of a body, a
# pale face with big amber eyes and a cross brow, ear tufts, two wing slabs. Flap (ice
# lances): wings swept wide and back, then one big beat forward. Throw (snowballs): wings
# up overhead, then flung forward.
# ---------------------------------------------------------------------------------------
def blizzard_owl():
    m = Model("BlizzardOwl", "Blizzard Owl: Tundra boss, hovers. Bones: root, WingL, WingR.")
    WHITE_ = (240, 244, 250)
    FACE = (208, 222, 244)
    BLUE = (120, 160, 220)
    AMBER = (255, 190, 50)
    BEAK = (250, 168, 40)
    m.bone("root", None, (0, 7.5, 0))
    m.bone("WingL", "root", (-3.5, 9.4, 0.4))
    m.bone("WingR", "root", (3.5, 9.4, 0.4))

    m.block("Body", "root", (7, 7.4, 6.6), (0, 7.6, 0), WHITE_)
    m.block("Face", "root", (5.8, 3.6, 0.4), (0, 8.9, -3.4), FACE)
    for i, (x, y) in enumerate(((-1.4, 6.2), (1.4, 6.2), (0, 5.2))):
        m.block("Speck%d" % i, "root", (0.9, 0.35, 0.2), (x, y, -3.35), BLUE)
    for side, s_ in (("L", -1), ("R", 1)):
        m.block("Eye" + side, "root", (1.8, 1.8, 0.1), (s_ * 1.45, 8.7, -3.65), AMBER, plain=True)
        m.block("Pupil" + side, "root", (0.9, 1.1, 0.1), (s_ * 1.3, 8.6, -3.72), DARK, plain=True)
        m.block("Brow" + side, "root", (2.6, 0.55, 0.3), (s_ * 1.35, 10.05, -3.65), BLUE, r=(0, 0, s_ * 16))
        m.wedge("Tuft" + side, "root", (1.4, 2.2, 1.6), (s_ * 2.6, 12.3, -0.8), WHITE_, r=(0, 0, s_ * 14))
        m.block("Talon" + side, "root", (0.9, 0.6, 1.3), (s_ * 1.3, 3.65, -1.2), BEAK)
        b = "Wing" + side
        m.block("Wing" + side, b, (0.9, 6.2, 4.6), (s_ * 3.95, 7.2, 0.6), WHITE_)
        m.block("WingTip" + side, b, (0.95, 1.6, 4.6), (s_ * 3.95, 4.4, 0.6), BLUE)
    m.wedge("Beak", "root", (1, 1.1, 0.9), (0, 7.75, -3.9), BEAK, r=(180, 0, 0))
    m.wedge("Tail", "root", (3, 0.8, 2), (0, 4.6, 3.8), BLUE, r=(0, 180, 0))

    m.anim("idle", 1.6, {
        "root": {"p": wave(1.6, (0, 0.5, 0))},
        "WingL": {"r": wave(1.6, (0, 0, -12), 0.15)},
        "WingR": {"r": wave(1.6, (0, 0, 12), 0.15)},
    })
    walk = {
        "root": {"p": wave(0.8, (0, 0.6, 0)), "r": [(0, -8, 0, 0), (0.8, -8, 0, 0)]},
        "WingL": {"r": wave(0.8, (0, 0, -32), 0.15, offset=(0, 0, -14))},
        "WingR": {"r": wave(0.8, (0, 0, 32), 0.15, offset=(0, 0, 14))},
    }
    m.anim("walk", 0.8, walk)
    gallop_from(m, walk, 0.5)
    # flap (0.8s windup): rises and leans back with its wings swept wide and back, then one
    # big beat forward at the hit (the ice lances fly), and settles
    m.anim("flap", 1.4, {
        "root": {"p": [(0, 0, 0, 0), (0.65, 0, 1.4, 0.6), (0.8, 0, 0.4, -0.8), (1.0, 0, 0.2, -0.6), (1.4, 0, 0, 0)],
                 "r": [(0, 0, 0, 0), (0.65, 12, 0, 0), (0.8, -14, 0, 0), (1.0, -10, 0, 0), (1.4, 0, 0, 0)]},
        "WingL": {"r": [(0, 0, 0, 0), (0.5, 0, 30, -100), (0.65, 0, 38, -110), (0.8, 0, -45, -40), (1.0, 0, -35, -35), (1.4, 0, 0, 0)]},
        "WingR": {"r": [(0, 0, 0, 0), (0.5, 0, -30, 100), (0.65, 0, -38, 110), (0.8, 0, 45, 40), (1.0, 0, 35, 35), (1.4, 0, 0, 0)]},
    }, hit=0.8)
    # throw (0.5s windup): both wings raised high over its head, then flung forward and down
    m.anim("throw", 1.0, {
        "root": {"p": [(0, 0, 0, 0), (0.4, 0, 0.8, 0), (0.5, 0, 0, -0.4), (1.0, 0, 0, 0)],
                 "r": [(0, 0, 0, 0), (0.4, 8, 0, 0), (0.5, -10, 0, 0), (1.0, 0, 0, 0)]},
        "WingL": {"r": [(0, 0, 0, 0), (0.4, 0, 0, -160), (0.5, -50, 0, -70), (0.7, -40, 0, -60), (1.0, 0, 0, 0)]},
        "WingR": {"r": [(0, 0, 0, 0), (0.4, 0, 0, 160), (0.5, -50, 0, 70), (0.7, -40, 0, 60), (1.0, 0, 0, 0)]},
    }, hit=0.5)
    return m


# ---------------------------------------------------------------------------------------
# Lava Valley: Magma Slime (Archero's slimes). One black crust cube with glowing cracks, a
# glowing face and a crust lid sitting on top, magma oozing out round its foot. No legs:
# it hops, squashing and stretching (its root sinks and rises, the lid lags behind).
# Leap: squashes flat, springs up with its lid flying, lands squashed and wobbles back.
# ---------------------------------------------------------------------------------------
def magma_slime():
    m = Model("MagmaSlime", "Magma Slime: Lava Valley boss. Bones: root, Lid.")
    CRUST = (62, 48, 50)
    CRUST2 = (84, 64, 62)
    GLOW = (255, 128, 28)
    HOT = (255, 206, 70)
    m.bone("root", None, (0, 3.5, 0))
    m.bone("Lid", "root", (0, 7.4, 0))

    m.block("Body", "root", (9, 7, 9), (0, 3.6, 0), CRUST)
    m.block("Ooze", "root", (9.8, 0.9, 9.8), (0, 0.45, 0), GLOW, neon=True)
    # glowing cracks running over its faces
    m.block("CrackF", "root", (0.35, 3, 0.1), (-3, 2.6, -4.53), GLOW, neon=True, r=(0, 0, 18))
    m.block("CrackF2", "root", (2, 0.35, 0.1), (3.1, 5.6, -4.53), GLOW, neon=True, r=(0, 0, -10))
    m.block("CrackL", "root", (0.1, 4, 0.35), (-4.53, 3.4, 1.4), GLOW, neon=True, r=(24, 0, 0))
    m.block("CrackR", "root", (0.1, 0.35, 3.4), (4.53, 4.6, -0.8), GLOW, neon=True, r=(14, 0, 0))
    m.block("CrackB", "root", (0.35, 3.6, 0.1), (1.6, 3.2, 4.53), GLOW, neon=True, r=(0, 0, -20))
    # the face: angry glowing eyes and a wide mouth
    for side, s_ in (("L", -1), ("R", 1)):
        m.block("Eye" + side, "root", (1.5, 1.3, 0.1), (s_ * 1.7, 4.6, -4.54), HOT, neon=True)
        m.block("Brow" + side, "root", (2.2, 0.55, 0.3), (s_ * 1.6, 5.65, -4.6), CRUST2, r=(0, 0, s_ * -18))
    m.block("Mouth", "root", (3.4, 0.9, 0.1), (0, 2.6, -4.54), GLOW, neon=True)
    # the lid: a crust slab with a glowing seam under it and two rocks on top
    m.block("Seam", "Lid", (8.6, 0.3, 8.6), (0, 7.25, 0), GLOW, neon=True)
    m.block("Lid", "Lid", (9.6, 1.6, 9.6), (0, 8.2, 0), CRUST2)
    m.block("Rock", "Lid", (2.6, 1.4, 2.4), (-2, 9.6, 1.2), CRUST, r=(0, 20, 0))
    m.block("Rock2", "Lid", (1.6, 1.0, 1.6), (2.4, 9.4, -1.4), CRUST, r=(0, -15, 0))

    m.anim("idle", 1.4, {
        "root": {"p": wave(1.4, (0, 0.25, 0), offset=(0, -0.25, 0))},
        "Lid": {"p": wave(1.4, (0, 0.3, 0), -0.12, offset=(0, 0, 0))},
    })
    # it hops along: down, spring up, land, each step a little hop
    walk = {
        "root": {"p": [(0, 0, -0.5, 0), (0.15, 0, 0.6, 0), (0.35, 0, 1.6, 0), (0.55, 0, 0.3, 0), (0.7, 0, -0.5, 0)],
                 "r": [(0, 0, 0, 0), (0.2, -5, 0, 0), (0.45, 4, 0, 0), (0.7, 0, 0, 0)]},
        "Lid": {"p": [(0, 0, -0.3, 0), (0.2, 0, -0.2, 0), (0.4, 0, 0.6, 0), (0.6, 0, -0.3, 0), (0.7, 0, -0.3, 0)]},
    }
    m.anim("walk", 0.7, walk)
    gallop_from(m, walk, 0.45)
    # leap (0.6s windup): squashes right down (the lid pressed on), springs at the hit with
    # its lid flying off its top, comes down squashed and wobbles back
    m.anim("leap", 1.7, {
        "root": {"p": [(0, 0, 0, 0), (0.45, 0, -1.8, 0), (0.6, 0, 2.6, 0), (0.95, 0, 1.6, 0), (1.15, 0, -1.4, 0), (1.35, 0, 0.4, 0), (1.7, 0, 0, 0)],
                 "r": [(0, 0, 0, 0), (0.45, -8, 0, 0), (0.6, 6, 0, 0), (0.95, 0, 0, 0), (1.15, -4, 0, 0), (1.7, 0, 0, 0)]},
        "Lid": {"p": [(0, 0, 0, 0), (0.45, 0, -0.5, 0), (0.6, 0, 0.4, 0), (0.8, 0, 1.6, 0), (1.15, 0, -0.4, 0), (1.35, 0, 0.5, 0), (1.7, 0, 0, 0)],
                "r": [(0, 0, 0, 0), (0.8, 6, 0, 8), (1.15, 0, 0, 0)]},
    }, hit=0.6)
    return m


BUILDERS = [scorpion_king, frost_golem, blizzard_owl, magma_slime]


def models():
    return [b() for b in BUILDERS]


if __name__ == "__main__":
    for m in models():
        if len(sys.argv) < 2 or m.name in sys.argv[1:]:
            m.write()
