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


BONE = (232, 226, 206)
BONE_DARK = (64, 60, 70)  # (the dark inside of a rib cage, eye sockets)
RUST = (168, 96, 60)
IRON = (92, 88, 92)
GHOST = (110, 255, 150)  # (glowing green eyes)


def skeleton_body(m, k, sword):
    """The Bone Warden and his Skeletons share a body, k times the Skeleton's size: legs,
    pelvis, spine, a rib cage, a skull with glowing eyes, bony arms, iron boots. Bones:
    root, neck, ArmL, ArmR, LegL, LegR. sword(m, k) hangs its weapon on ArmR."""
    m.bone("root", None, (0, 4.6 * k, 0))
    m.bone("neck", "root", (0, 9.6 * k, 0))
    m.bone("ArmL", "root", (-2.6 * k, 9.2 * k, 0))
    m.bone("ArmR", "root", (2.6 * k, 9.2 * k, 0))
    m.bone("LegL", "root", (-1.1 * k, 4.6 * k, 0))
    m.bone("LegR", "root", (1.1 * k, 4.6 * k, 0))
    for side, s in (("L", -1), ("R", 1)):
        leg = "Leg" + side
        m.block("Thigh" + side, leg, (0.9 * k, 3.6 * k, 0.9 * k), (s * 1.1 * k, 2.9 * k, 0), BONE)
        m.block("Boot" + side, leg, (1.6 * k, 1.4 * k, 2.2 * k), (s * 1.1 * k, 0.7 * k, -0.3 * k), IRON)
        arm = "Arm" + side
        m.block("Pauldron" + side, arm, (2 * k, 1.1 * k, 2.2 * k), (s * 2.9 * k, 9.5 * k, 0), RUST)
        m.block("Bone" + side, arm, (0.8 * k, 3.8 * k, 0.8 * k), (s * 2.9 * k, 7.2 * k, 0), BONE)
        m.block("Hand" + side, arm, (1.1 * k, 1.1 * k, 1.1 * k), (s * 2.9 * k, 4.9 * k, 0), BONE)
    m.block("Pelvis", "root", (3.2 * k, 1 * k, 1.8 * k), (0, 4.9 * k, 0), BONE)
    m.block("Spine", "root", (0.8 * k, 2 * k, 0.8 * k), (0, 6.2 * k, 0.4 * k), BONE)
    m.block("Chest", "root", (3.8 * k, 3 * k, 2.2 * k), (0, 8.2 * k, 0), BONE_DARK)
    for i, y in enumerate((7.1, 8.1, 9.1)):
        m.block("Rib%d" % i, "root", (4.4 * k, 0.55 * k, 2.6 * k), (0, y * k, 0), BONE)
    m.block("Sternum", "root", (0.6 * k, 3 * k, 0.3 * k), (0, 8.2 * k, -1.3 * k), BONE)
    m.block("Skull", "neck", (3 * k, 2.6 * k, 2.8 * k), (0, 11.2 * k, 0), BONE)
    m.block("Jaw", "neck", (2.4 * k, 0.8 * k, 2.2 * k), (0, 9.7 * k, -0.2 * k), BONE)
    for side, s in (("L", -1), ("R", 1)):
        m.block("Socket" + side, "neck", (0.9 * k, 0.9 * k, 0.1 * k), (s * 0.7 * k, 11.1 * k, -1.43 * k), BONE_DARK, plain=True)
        m.block("Glow" + side, "neck", (0.4 * k, 0.4 * k, 0.1 * k), (s * 0.7 * k, 11.05 * k, -1.5 * k), GHOST, neon=True)
    m.block("Teeth", "neck", (1.6 * k, 0.35 * k, 0.1 * k), (0, 10.05 * k, -1.33 * k), BONE_DARK, plain=True)
    sword(m, k)


def skeleton_gaits(m, k, lean=0):
    m.anim("idle", 2.4, {
        "root": {"p": bob(2.4, 0.1 * k)},
        "neck": {"r": wave(2.4, (4, 6, 0))},
        "ArmL": {"r": wave(2.4, (4, 0, -3))},
        "ArmR": {"r": wave(2.4, (3, 0, 2), 0.2)},
    })
    walk = {
        "root": {"p": bob(0.9, 0.3 * k, 0.25, double=True), "r": wave(0.9, (0, 5, 0), offset=(lean, 0, 0))},
        "LegL": {"r": wave(0.9, (26, 0, 0))},
        "LegR": {"r": wave(0.9, (-26, 0, 0))},
        "ArmL": {"r": wave(0.9, (-22, 0, 0))},
        "ArmR": {"r": wave(0.9, (12, 0, 0))},
        "neck": {"r": wave(0.9, (0, 0, 6), 0.25)},
    }
    m.anim("walk", 0.9, walk)
    gallop_from(m, walk, 0.6)
    return walk


# ---------------------------------------------------------------------------------------
# Abandoned Dungeon: Bone Warden (Archero's skeleton king). A tall skeleton knight: rib
# cage, skull with glowing green eyes, a rusty crown, rusty pauldrons and one huge rusty
# sword. Cleave: sword raised over his head, then brought down in front. Charge: leans in
# with the sword levelled, then runs down the red lane.
# ---------------------------------------------------------------------------------------
def big_sword(m, k):
    m.block("Grip", "ArmR", (0.45, 0.45, 1.6), (2.9 * k, 4.9, -0.2), BONE_DARK)
    m.block("Guard", "ArmR", (2.8, 0.6, 0.7), (2.9 * k, 4.9, -1.3), IRON)
    m.block("Blade", "ArmR", (0.5, 1.5, 7.6), (2.9 * k, 4.9, -5.4), RUST)
    m.block("Edge", "ArmR", (0.55, 0.4, 7.6), (2.9 * k, 4.15, -5.4), (196, 132, 92))
    m.wedge("Tip", "ArmR", (0.5, 1.5, 1.2), (2.9 * k, 4.9, -9.8), RUST, r=(180, 0, 0))


def bone_warden():
    m = Model("BoneWarden", "Bone Warden: Abandoned Dungeon boss. Bones: root, neck, ArmL, ArmR (his sword), LegL, LegR.")
    k = 1.0
    skeleton_body(m, k, big_sword)
    # (his rusty crown, three points round the top of his skull)
    m.block("Crown", "neck", (3.3, 0.7, 3.1), (0, 12.6, 0), RUST)
    for i, (x, z) in enumerate(((-1.1, -1.1), (1.1, -1.1), (0, -1.2))):
        m.block("CrownPt%d" % i, "neck", (0.6, 1.1 if x else 1.4, 0.4), (x, 13.4 if x else 13.55, z), RUST)
    skeleton_gaits(m, k)
    # cleave (0.9s windup): sword swung up over his head, leaning back, then brought down
    # in front of him at the hit, bent over it a moment
    m.anim("cleave", 1.7, {
        "root": {"r": [(0, 0, 0, 0), (0.7, 10, -10, 0), (0.9, -14, 6, 0), (1.25, -12, 4, 0), (1.7, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.7, 0, 0.2, 0.4), (0.9, 0, -0.5, -0.6), (1.25, 0, -0.4, -0.5), (1.7, 0, 0, 0)]},
        "ArmR": {"r": [(0, 0, 0, 0), (0.55, 165, 0, -10), (0.75, 175, 0, -10), (0.9, 48, 0, 8), (1.25, 44, 0, 6), (1.7, 0, 0, 0)]},
        "ArmL": {"r": [(0, 0, 0, 0), (0.7, 30, 0, -20), (0.9, -20, 0, -10), (1.7, 0, 0, 0)]},
        "neck": {"r": [(0, 0, 0, 0), (0.7, 10, 0, 0), (0.9, -12, 0, 0), (1.7, 0, 0, 0)]},
        "LegL": {"r": [(0, 0, 0, 0), (0.7, 0, 0, 0), (0.9, 18, 0, 0), (1.25, 16, 0, 0), (1.7, 0, 0, 0)]},
        "LegR": {"r": [(0, 0, 0, 0), (0.7, 0, 0, 0), (0.9, -14, 0, 0), (1.25, -12, 0, 0), (1.7, 0, 0, 0)]},
    }, hit=0.9)
    # charge (0.8s windup): crouches and leans in with the sword levelled at you, then at
    # the hit runs down the red lane, sword out in front
    run = {b: dict(v) for b, v in m.anims["gallop"]["tracks"].items() if b in ("LegL", "LegR", "ArmL")}
    for tr in run.values():
        for key in tr:
            tr[key] = [(0.8 + t, x, y, z) for t, x, y, z in tr[key]] + [(0.8 + 0.6 + t, x, y, z) for t, x, y, z in tr[key][1:]]
    for tr in run.values():
        for key in tr:
            tr[key] = [(0, 0, 0, 0), (0.6, 0, 0, 0)] + tr[key] + [(2.2, 0, 0, 0)]
    m.anim("charge", 2.2, dict(run, **{
        "root": {"r": [(0, 0, 0, 0), (0.6, -12, 0, 0), (0.8, -18, 0, 0), (2.0, -16, 0, 0), (2.2, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.6, 0, -0.6, 0), (0.8, 0, -0.3, 0), (2.0, 0, -0.3, 0), (2.2, 0, 0, 0)]},
        "ArmR": {"r": [(0, 0, 0, 0), (0.6, 30, 0, 6), (0.8, 24, 0, 6), (2.0, 24, 0, 6), (2.2, 0, 0, 0)]},
        "neck": {"r": [(0, 0, 0, 0), (0.6, 12, 0, 0), (2.0, 12, 0, 0), (2.2, 0, 0, 0)]},
    }), hit=0.8)
    return m


# the Bone Warden's Skeletons (minions): half his size, a rusty shortsword
def short_sword(m, k):
    m.block("Grip", "ArmR", (0.3, 0.3, 0.8), (2.9 * k, 4.9 * k, -0.1), BONE_DARK)
    m.block("Guard", "ArmR", (1.3, 0.3, 0.35), (2.9 * k, 4.9 * k, -0.6), IRON)
    m.block("Blade", "ArmR", (0.25, 0.7, 3), (2.9 * k, 4.9 * k, -2.2), RUST)


def skeleton():
    m = Model("Skeleton", "Skeleton: the Bone Warden's minion. Bones: root, neck, ArmL, ArmR, LegL, LegR.")
    k = 0.55
    skeleton_body(m, k, short_sword)
    skeleton_gaits(m, k, lean=-4)
    return m


# ---------------------------------------------------------------------------------------
# Abandoned Dungeon: Dungeon Watcher (Archero's eye boss). A floating block of mossy dungeon
# stone round one big eye with a glowing green iris, four stone fins. Its lid is a stone
# slab over the eye. Stare (beams): the lid narrows to a slit as it leans back, then snaps
# wide open at the hit and holds the glare.
# ---------------------------------------------------------------------------------------
def dungeon_watcher():
    m = Model("DungeonWatcher", "Dungeon Watcher: Abandoned Dungeon boss, floats. Bones: root, Lid.")
    STONE = (96, 118, 108)
    STONE_DARK = (66, 82, 78)
    MOSS = (104, 160, 72)
    SCLERA = (238, 234, 220)
    IRIS = (90, 240, 120)
    m.bone("root", None, (0, 8, 0))
    m.bone("Lid", "root", (0, 10.2, -3.6))

    m.block("Shell", "root", (8, 8, 7), (0, 8, 0), STONE)
    m.block("Rim", "root", (6.4, 5.6, 0.6), (0, 8, -3.6), STONE_DARK)
    m.block("Sclera", "root", (5.4, 4.6, 0.3), (0, 8, -3.85), SCLERA, plain=True)
    m.block("Iris", "root", (2.6, 2.6, 0.1), (0, 8, -4.05), IRIS, neon=True)
    m.block("Pupil", "root", (0.9, 1.8, 0.1), (0, 8, -4.12), DARK, plain=True)
    m.block("Lid", "Lid", (6.2, 2.4, 0.8), (0, 11.6, -3.9), STONE)  # (sits above the eye; drops to close it)
    m.block("LidLip", "Lid", (6.2, 0.4, 0.9), (0, 10.5, -3.95), STONE_DARK)
    m.block("Moss", "root", (8.2, 0.5, 7.2), (0, 12.1, 0), MOSS)
    m.block("Moss2", "root", (2.6, 2.4, 0.3), (-2.6, 10.9, 3.6), MOSS)
    m.block("Moss3", "root", (0.3, 2, 2.6), (4.1, 11, 1.6), MOSS)
    # four stone fins, one off each side
    m.pair(m.wedge, "Fin", "root", (2.6, 4, 3), (-5.2, 8, 0.6), STONE_DARK, r=(0, 0, 90))
    m.wedge("FinTop", "root", (1.6, 3, 4), (0, 13.6, 1), STONE_DARK, r=(0, 180, 0))
    m.wedge("FinBottom", "root", (1.6, 3, 4), (0, 2.4, 1), STONE_DARK, r=(180, 0, 0))

    m.anim("idle", 3.2, {
        "root": {"p": wave(3.2, (0, 0.6, 0)), "r": wave(3.2, (3, 6, 2), 0.25)},
        # (a blink now and then)
        "Lid": {"p": [(0, 0, 0, 0), (2.6, 0, 0, 0), (2.7, 0, -2.6, 0), (2.85, 0, 0, 0), (3.2, 0, 0, 0)]},
    })
    walk = {
        "root": {"p": wave(1.2, (0, 0.5, 0)), "r": [(0, -8, 0, 0), (0.6, -8, 0, 3), (1.2, -8, 0, 0)]},
    }
    m.anim("walk", 1.2, walk)
    gallop_from(m, walk, 0.8)
    # stare (1.0s windup): leans back narrowing its lid to a slit, then snaps it wide open
    # at the hit and glares down the beams, trembling, before settling
    m.anim("stare", 2.0, {
        "Lid": {"p": [(0, 0, 0, 0), (0.6, 0, -2.0, 0), (0.9, 0, -2.2, 0), (1.0, 0, 0.7, 0), (1.7, 0, 0.6, 0), (2.0, 0, 0, 0)]},
        "root": {"r": [(0, 0, 0, 0), (0.85, 14, 0, 0), (1.0, -10, 0, 0), (1.1, -9, 1.5, 0), (1.25, -9, -1.5, 0), (1.4, -9, 1.5, 0),
                       (1.55, -9, -1.5, 0), (1.7, -8, 0, 0), (2.0, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.85, 0, 0.8, 0.6), (1.0, 0, 0, -0.8), (1.7, 0, 0, -0.6), (2.0, 0, 0, 0)]},
    }, hit=1.0)
    return m


# ---------------------------------------------------------------------------------------
# Abandoned Dungeon: Treasure Mimic. A wooden treasure chest with gold corners and a gold
# lock, angry eyes on its lid, teeth round its lips and a long tongue, on four stubby legs.
# Charge: lid flung wide, crouched, then chomps all the way down the red lane. Spit (gold
# coins): lid clamps shut, then pops wide open.
# ---------------------------------------------------------------------------------------
def treasure_mimic():
    m = Model("TreasureMimic", "Treasure Mimic: Abandoned Dungeon boss. Bones: root, Lid, Tongue.")
    WOOD = (156, 100, 56)
    WOOD_DARK = (104, 64, 40)
    MOUTH = (110, 22, 40)
    TONGUE = (236, 96, 130)
    m.bone("root", None, (0, 3.6, 0))
    m.bone("Lid", "root", (0, 5.6, 2.7))
    m.bone("Tongue", "root", (0, 5.2, 1.6))

    m.block("Box", "root", (7.6, 4, 5.4), (0, 3.6, 0), WOOD)
    m.block("Band", "root", (7.7, 0.6, 5.5), (0, 2.6, 0), WOOD_DARK)
    m.block("Mouth", "root", (6.8, 0.2, 4.6), (0, 5.55, 0), MOUTH, plain=True)
    m.block("Lock", "root", (1.4, 1.6, 0.3), (0, 4.4, -2.8), GOLD)
    m.block("Keyhole", "root", (0.35, 0.7, 0.1), (0, 4.3, -2.97), DARK, plain=True)
    for i, x in enumerate((-2.8, -1.4, 1.4, 2.8)):
        m.wedge("ToothB%d" % i, "root", (0.7, 0.8, 0.5), (x, 6, -2.4), WHITE, r=(0, 180, 0))
    for side, s in (("L", -1), ("R", 1)):
        for end, z in (("F", -2.35), ("B", 2.35)):
            m.block("Corner" + side + end, "root", (0.9, 4.1, 0.9), (s * 3.45, 3.6, z), GOLD)
            m.block("Leg" + side + end, "root", (1.4, 1.8, 1.4), (s * 2.6, 0.9, z * 0.8), WOOD_DARK)
    # the lid, hinged at the back; teeth along its front lip, angry eyes on its face
    m.block("Lid", "Lid", (7.8, 2.2, 5.6), (0, 6.75, 0), WOOD)
    m.block("LidTop", "Lid", (7.9, 0.5, 5.7), (0, 7.85, 0), WOOD_DARK)
    m.block("LidTrim", "Lid", (7.9, 0.45, 5.7), (0, 5.85, 0), GOLD)
    m.block("LidMouth", "Lid", (6.8, 0.1, 4.6), (0, 5.6, 0), MOUTH, plain=True)
    for i, x in enumerate((-2.1, 0, 2.1)):
        m.wedge("ToothT%d" % i, "Lid", (0.7, 0.8, 0.5), (x, 5.25, -2.4), WHITE, r=(180, 180, 0))
    for side, s in (("L", -1), ("R", 1)):
        m.block("Eye" + side, "Lid", (1.3, 0.9, 0.1), (s * 1.6, 6.85, -2.86), (255, 214, 70), neon=True)
        m.block("Brow" + side, "Lid", (1.8, 0.45, 0.3), (s * 1.55, 7.55, -2.9), WOOD_DARK, r=(0, 0, s * -16))
    m.block("Tongue", "Tongue", (2, 0.5, 4), (0, 5.55, -0.6), TONGUE)

    m.anim("idle", 2.0, {
        "root": {"p": bob(2.0, 0.12)},
        "Lid": {"r": wave(2.0, (5, 0, 0), offset=(9, 0, 0))},
        "Tongue": {"r": wave(2.0, (0, 6, 0), 0.25)},
    })
    # it waddles and chomps as it goes
    walk = {
        "root": {"p": bob(0.6, 0.6, double=True), "r": wave(0.6, (0, 0, 6))},
        "Lid": {"r": wave(0.6, (12, 0, 0), offset=(16, 0, 0))},
        "Tongue": {"r": wave(0.6, (0, 10, 0), 0.25)},
    }
    m.anim("walk", 0.6, walk)
    gallop_from(m, walk, 0.4)
    # charge (0.7s windup): lid flung wide, tongue out, crouched; then from the hit chomps
    # all the way down the lane
    chomp = [(0.7 + i * 0.1, 70 if i % 2 == 0 else 14, 0, 0) for i in range(10)]
    m.anim("charge", 1.9, {
        "Lid": {"r": [(0, 10, 0, 0), (0.45, 75, 0, 0), (0.6, 78, 0, 0)] + chomp + [(1.9, 10, 0, 0)]},
        "Tongue": {"r": [(0, 0, 0, 0), (0.45, -18, 0, 0), (1.6, -18, 0, 0), (1.9, 0, 0, 0)],
                   "p": [(0, 0, 0, 0), (0.45, 0, 0, -1.6), (1.6, 0, 0, -1.6), (1.9, 0, 0, 0)]},
        "root": {"r": [(0, 0, 0, 0), (0.5, -10, 0, 0), (0.7, -8, 0, 0), (1.6, -8, 0, 0), (1.9, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.5, 0, -0.6, 0), (0.7, 0, 0.3, 0)] + [(0.8 + i * 0.1, 0, 0.6 if i % 2 else 0.1, 0) for i in range(8)] + [(1.9, 0, 0, 0)]},
    }, hit=0.7)
    # spit (0.5s windup): clamps shut and squashes, then pops wide open spraying its coins
    m.anim("spit", 1.1, {
        "Lid": {"r": [(0, 10, 0, 0), (0.35, -2, 0, 0), (0.5, 85, 0, 0), (0.75, 80, 0, 0), (1.1, 10, 0, 0)]},
        "Tongue": {"r": [(0, 0, 0, 0), (0.5, 30, 0, 0), (0.75, 20, 0, 0), (1.1, 0, 0, 0)]},
        "root": {"p": [(0, 0, 0, 0), (0.35, 0, -0.6, 0), (0.5, 0, 0.8, 0), (0.75, 0, 0.2, 0), (1.1, 0, 0, 0)],
                 "r": [(0, 0, 0, 0), (0.35, -4, 0, 0), (0.5, 8, 0, 0), (1.1, 0, 0, 0)]},
    }, hit=0.5)
    return m


PINK_GLOW = (255, 110, 200)


# ---------------------------------------------------------------------------------------
# Magic Circle: Rune Mage (Archero's teleporting mage). A robe stepping in like a cone, in
# the Forest's blue, pink runes glowing on it, no face but two glowing eyes under a wide
# pointed hat, a staff with a glowing orb. Cast: rises with the staff drawn back, then
# thrusts it at you at the hit.
# ---------------------------------------------------------------------------------------
def rune_mage():
    m = Model("RuneMage", "Rune Mage: Magic Circle boss, hovers. Bones: root, ArmR (staff), Hat.")
    ROBE = (84, 110, 206)
    ROBE_DARK = (60, 80, 168)
    TRIM = (150, 176, 240)
    STAFF = (120, 84, 60)
    m.bone("root", None, (0, 4, 0))
    m.bone("ArmR", "root", (2.3, 6.6, 0))
    m.bone("Hat", "root", (0, 8.2, 0))

    m.block("Robe1", "root", (5.8, 2.4, 5.8), (0, 1.6, 0), ROBE)
    m.block("Hem", "root", (6, 0.5, 6), (0, 0.55, 0), TRIM)
    m.block("Robe2", "root", (4.8, 2.6, 4.8), (0, 4.1, 0), ROBE)
    m.block("Robe3", "root", (3.8, 2.2, 3.8), (0, 6.5, 0), ROBE)
    m.block("Face", "root", (2.6, 1.6, 0.2), (0, 7.6, -1.85), (34, 28, 54), plain=True)
    for side, s in (("L", -1), ("R", 1)):
        m.block("Eye" + side, "root", (0.6, 0.35, 0.1), (s * 0.6, 7.65, -1.97), PINK_GLOW, neon=True)
    for i, (x, y, z) in enumerate(((-1.4, 2.0, -2.93), (1.2, 4.6, -2.43), (0, 1.5, -2.93), (2.93, 1.8, 0.8))):
        size = (0.1, 0.8, 0.8) if abs(x) > 2.5 else (0.8, 0.8, 0.1)
        m.block("Rune%d" % i, "root", size, (x, y, z), PINK_GLOW, neon=True, r=(0, 0, 45) if abs(x) < 2.5 else (45, 0, 0))
    m.block("SleeveL", "root", (1.5, 3, 1.5), (-2.6, 5.4, -0.4), ROBE_DARK, r=(-15, 0, -14))
    m.block("SleeveR", "ArmR", (1.5, 3, 1.5), (2.6, 5.4, -0.4), ROBE_DARK, r=(-15, 0, 14))
    m.block("Staff", "ArmR", (0.5, 10.5, 0.5), (3.2, 6, -1.2), STAFF)
    m.block("StaffHead", "ArmR", (1.3, 0.6, 1.3), (3.2, 11.3, -1.2), GOLD)
    m.block("Orb", "ArmR", (1.4, 1.4, 1.4), (3.2, 12.3, -1.2), PINK_GLOW, neon=True, r=(45, 45, 0))
    m.block("Brim", "Hat", (6.6, 0.5, 6.6), (0, 8.6, 0.2), ROBE_DARK)
    m.block("HatBand", "Hat", (4.2, 0.6, 4.2), (0, 8.95, 0), PINK_GLOW)
    m.block("Hat1", "Hat", (4, 1.8, 4), (0, 9.8, 0), ROBE)
    m.block("Hat2", "Hat", (2.6, 1.6, 2.6), (0, 11.4, 0.3), ROBE, r=(10, 0, 0))
    m.block("Hat3", "Hat", (1.4, 1.6, 1.4), (0, 12.6, 1), ROBE, r=(28, 0, 0))

    m.anim("idle", 2.6, {
        "root": {"p": wave(2.6, (0, 0.35, 0), offset=(0, 0.35, 0))},
        "Hat": {"r": wave(2.6, (3, 0, 3), 0.2)},
        "ArmR": {"r": wave(2.6, (4, 0, 0), 0.4)},
    })
    walk = {
        "root": {"p": wave(1.0, (0, 0.3, 0), offset=(0, 0.4, 0)), "r": [(0, -8, 0, 0), (0.5, -8, 0, 3), (1.0, -8, 0, 0)]},
        "Hat": {"r": wave(1.0, (6, 0, 0), 0.3, offset=(6, 0, 0))},
        "ArmR": {"r": wave(1.0, (6, 0, 0))},
    }
    m.anim("walk", 1.0, walk)
    gallop_from(m, walk, 0.7)
    # cast (0.6s windup): floats up with the staff drawn back, then thrusts it at you at
    # the hit (its orbs fly) and sinks back
    m.anim("cast", 1.2, {
        "root": {"p": [(0, 0, 0, 0), (0.45, 0, 1.2, 0.3), (0.6, 0, 0.6, -0.4), (0.8, 0, 0.5, -0.3), (1.2, 0, 0, 0)],
                 "r": [(0, 0, 0, 0), (0.45, 8, 0, 0), (0.6, -10, 0, 0), (0.8, -8, 0, 0), (1.2, 0, 0, 0)]},
        "ArmR": {"r": [(0, 0, 0, 0), (0.45, 28, 0, 14), (0.6, -50, 0, 0), (0.85, -44, 0, 0), (1.2, 0, 0, 0)]},
        "Hat": {"r": [(0, 0, 0, 0), (0.45, 10, 0, 0), (0.6, -6, 0, 0), (0.7, 6, 0, 0), (1.2, 0, 0, 0)]},
    }, hit=0.6)
    return m


# ---------------------------------------------------------------------------------------
# Magic Circle: Elder Treant (Archero's tree boss). A thick bark stump rooted in the ground,
# a grumpy face in its trunk, a big turquoise canopy and two branch arms. Roots: arms
# raised high, then driven down into the ground at the hit (the roots erupt along the
# red lines).
# ---------------------------------------------------------------------------------------
def elder_treant():
    m = Model("ElderTreant", "Elder Treant: Magic Circle boss, rooted. Bones: root, ArmL, ArmR, Canopy.")
    BARK = (128, 92, 70)
    BARK_DARK = (90, 62, 48)
    LEAF = (56, 196, 168)
    LEAF_DARK = (36, 156, 136)
    LEAF_LIGHT = (96, 222, 190)
    EYES = (200, 255, 150)
    m.bone("root", None, (0, 4, 0))
    m.bone("ArmL", "root", (-3, 6.4, 0))
    m.bone("ArmR", "root", (3, 6.4, 0))
    m.bone("Canopy", "root", (0, 10.4, 1))

    m.block("Trunk", "root", (6, 10.6, 5.6), (0, 5.3, 0), BARK)
    for i, x in enumerate((-1.8, 0.4, 2.2)):
        m.block("Groove%d" % i, "root", (0.35, 3 + i, 0.15), (x, 2.4 + i * 0.5, -2.85), BARK_DARK)
    for side, s in (("L", -1), ("R", 1)):
        m.block("Eye" + side, "root", (1.1, 0.7, 0.1), (s * 1.2, 7.1, -2.86), EYES, neon=True)
        m.block("Brow" + side, "root", (2, 0.6, 0.5), (s * 1.2, 7.85, -2.95), BARK_DARK, r=(0, 0, s * -18))
        m.block("RootF" + side, "root", (1.8, 1.4, 3), (s * 2.2, 0.7, -3.4), BARK_DARK, r=(0, s * 20, 0))
        m.block("RootS" + side, "root", (3, 1.2, 1.8), (s * 3.6, 0.6, 1.2), BARK_DARK, r=(0, s * -15, 0))
    m.block("Mouth", "root", (2.4, 0.7, 0.1), (0, 5.4, -2.86), (40, 26, 22), plain=True)
    for side, s in (("L", -1), ("R", 1)):
        b = "Arm" + side
        m.block("Branch" + side, b, (4, 1.3, 1.3), (s * 4.8, 6.9, 0), BARK, r=(0, 0, s * 18))
        m.block("Twig" + side, b, (1, 2.6, 1), (s * 6.6, 8.6, 0), BARK, r=(0, 0, s * -12))
        m.block("Tuft" + side, b, (2.4, 2, 2.4), (s * 6.9, 10.4, 0), LEAF)
    m.block("Canopy", "Canopy", (11, 4, 9), (0, 12.4, 1.4), LEAF)
    m.block("Canopy2", "Canopy", (7.6, 3, 6.4), (0, 15.6, 1.6), LEAF_DARK)
    m.block("Canopy3", "Canopy", (3.6, 2.4, 3.6), (-3.6, 13.6, -2.4), LEAF_LIGHT)
    m.block("Canopy4", "Canopy", (3.6, 2.4, 3.6), (4, 14.4, 3.4), LEAF_LIGHT)
    m.block("Canopy5", "Canopy", (3, 2, 3), (1, 17.6, 1.2), LEAF)

    m.anim("idle", 3.0, {
        "Canopy": {"r": wave(3.0, (2, 0, 3))},
        "ArmL": {"r": wave(3.0, (0, 0, 5), 0.1)},
        "ArmR": {"r": wave(3.0, (0, 0, -5), 0.35)},
        "root": {"r": wave(3.0, (0, 0, 1), 0.5)},
    })
    # (rooted: it never walks far; a heavy sway)
    walk = {
        "root": {"r": wave(1.4, (0, 4, 3))},
        "Canopy": {"r": wave(1.4, (3, 0, -4), 0.2)},
        "ArmL": {"r": wave(1.4, (10, 0, 0))},
        "ArmR": {"r": wave(1.4, (-10, 0, 0))},
    }
    m.anim("walk", 1.4, walk)
    gallop_from(m, walk, 1.0)
    # roots (1.0s windup): both branches raised high, canopy thrown back, then at the hit
    # driven down into the ground in front and held there as the roots erupt
    m.anim("roots", 1.9, {
        "ArmL": {"r": [(0, 0, 0, 0), (0.7, 0, 0, -70), (0.85, 0, 0, -78), (1.0, -30, 0, 48), (1.4, -28, 0, 44), (1.9, 0, 0, 0)]},
        "ArmR": {"r": [(0, 0, 0, 0), (0.7, 0, 0, 70), (0.85, 0, 0, 78), (1.0, -30, 0, -48), (1.4, -28, 0, -44), (1.9, 0, 0, 0)]},
        "root": {"r": [(0, 0, 0, 0), (0.85, 6, 0, 0), (1.0, -7, 0, 0), (1.4, -6, 0, 0), (1.9, 0, 0, 0)]},
        "Canopy": {"r": [(0, 0, 0, 0), (0.85, 8, 0, 0), (1.0, -8, 0, 0), (1.15, 4, 0, 0), (1.3, -3, 0, 0), (1.9, 0, 0, 0)]},
    }, hit=1.0)
    return m


# ---------------------------------------------------------------------------------------
# Magic Circle: Toadstool King. A giant mushroom: a pink cap with white spots, a pale stem
# with a sleepy-cross face and rosy cheeks, two stubby feet, a little gold crown on top.
# It hops. Leap: squashes, springs up with its cap lagging, lands squashed. Puff (spores):
# cap pressed down, then bounces up at the hit.
# ---------------------------------------------------------------------------------------
def toadstool_king():
    m = Model("ToadstoolKing", "Toadstool King: Magic Circle boss. Bones: root, Cap.")
    STEM = (244, 232, 206)
    STEM_DARK = (214, 196, 166)
    CAP = (236, 96, 150)
    CAP_DARK = (200, 70, 124)
    CHEEK = (250, 150, 170)
    m.bone("root", None, (0, 3, 0))
    m.bone("Cap", "root", (0, 7.8, 0))

    m.block("Stem", "root", (5, 7.6, 5), (0, 4.2, 0), STEM)
    m.block("Skirt", "root", (6, 0.7, 6), (0, 7.4, 0), STEM_DARK)
    for side, s in (("L", -1), ("R", 1)):
        m.block("Foot" + side, "root", (2, 1.1, 2.8), (s * 1.4, 0.55, -1), STEM_DARK)
        m.block("Eye" + side, "root", (0.8, 1.2, 0.1), (s * 1, 5.2, -2.55), DARK, plain=True)
        m.block("Cheek" + side, "root", (0.9, 0.5, 0.1), (s * 1.8, 4.3, -2.55), CHEEK, plain=True)
    m.block("Mouth", "root", (1, 0.35, 0.1), (0, 4.1, -2.55), DARK, plain=True)
    m.block("Cap", "Cap", (11, 3, 11), (0, 9.2, 0), CAP)
    m.block("CapRim", "Cap", (10.4, 0.4, 10.4), (0, 7.6, 0), CAP_DARK)
    m.block("CapTop", "Cap", (7.6, 1.6, 7.6), (0, 11.5, 0), CAP)
    for i, (x, y, z, w, sx) in enumerate(((-3, 12.32, -1.6, 1.8, 1), (2.2, 12.32, 1.8, 1.4, 1), (1.4, 12.32, -2.6, 1.2, 1),
                                        (-5.53, 9.4, 1.6, 1.6, 0), (5.53, 9.8, -2, 1.4, 0), (-1.8, 9.6, -5.53, 1.8, 2), (3.4, 9.0, -5.53, 1.2, 2))):
        size = (w, 0.1, w) if sx == 1 else (0.1, w, w) if sx == 0 else (w, w, 0.1)
        m.block("Spot%d" % i, "Cap", size, (x, y, z), WHITE, plain=True)
    m.block("Crown", "Cap", (2.8, 0.8, 2.8), (0, 12.7, 0), GOLD)
    for i, (x, z) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        m.block("CrownPt%d" % i, "Cap", (0.6, 0.9, 0.6), (x, 13.5, z), GOLD)
    m.block("Gem", "Cap", (0.6, 0.6, 0.1), (0, 12.7, -1.45), (110, 200, 255), plain=True)

    m.anim("idle", 2.0, {
        "root": {"p": wave(2.0, (0, 0.12, 0))},
        "Cap": {"p": wave(2.0, (0, 0.15, 0), -0.12), "r": wave(2.0, (2, 0, 3), 0.25)},
    })
    walk = {
        "root": {"p": [(0, 0, -0.3, 0), (0.15, 0, 0.5, 0), (0.3, 0, 1.4, 0), (0.48, 0, 0.3, 0), (0.6, 0, -0.3, 0)],
                 "r": [(0, 0, 0, 0), (0.15, -4, 0, 0), (0.4, 4, 0, 0), (0.6, 0, 0, 0)]},
        "Cap": {"p": [(0, 0, -0.4, 0), (0.18, 0, -0.2, 0), (0.36, 0, 0.5, 0), (0.54, 0, -0.4, 0), (0.6, 0, -0.4, 0)]},
    }
    m.anim("walk", 0.6, walk)
    gallop_from(m, walk, 0.4)
    m.anim("leap", 1.7, {
        "root": {"p": [(0, 0, 0, 0), (0.45, 0, -1.4, 0), (0.6, 0, 2.4, 0), (0.95, 0, 1.6, 0), (1.15, 0, -1.2, 0), (1.35, 0, 0.3, 0), (1.7, 0, 0, 0)],
                 "r": [(0, 0, 0, 0), (0.45, -6, 0, 0), (0.6, 5, 0, 0), (1.15, -3, 0, 0), (1.7, 0, 0, 0)]},
        "Cap": {"p": [(0, 0, 0, 0), (0.45, 0, -1.0, 0), (0.6, 0, -0.6, 0), (0.8, 0, 0.9, 0), (1.15, 0, -0.8, 0), (1.35, 0, 0.4, 0), (1.7, 0, 0, 0)]},
    }, hit=0.6)
    # puff (0.5s windup): cap pressed right down onto its face, then bounces up at the hit,
    # wobbling, as its spores burst out
    m.anim("puff", 1.1, {
        "Cap": {"p": [(0, 0, 0, 0), (0.4, 0, -1.2, 0), (0.5, 0, 1.0, 0), (0.65, 0, 0.3, 0), (0.8, 0, 0.5, 0), (1.1, 0, 0, 0)],
                "r": [(0, 0, 0, 0), (0.5, 0, 0, 0), (0.6, 4, 0, 4), (0.75, -3, 0, -4), (0.9, 2, 0, 2), (1.1, 0, 0, 0)]},
        "root": {"p": [(0, 0, 0, 0), (0.4, 0, -0.5, 0), (0.5, 0, 0.3, 0), (1.1, 0, 0, 0)]},
    }, hit=0.5)
    return m


STEEL = (184, 186, 198)
STEEL_DARK = (112, 114, 130)
CRIMSON = (170, 30, 52)
CRIMSON_DARK = (120, 20, 40)


def knight_body(m, k, plume=True):
    """The Crimson Knight and his Castle Guards: steel plate, a crimson tabard, a helm with
    a visor slit, k times the Guard's size. Bones: root, neck, ArmL (shield), ArmR (weapon),
    LegL, LegR."""
    m.bone("root", None, (0, 4.4 * k, 0))
    m.bone("neck", "root", (0, 9.6 * k, 0))
    m.bone("ArmL", "root", (-3 * k, 9.2 * k, 0))
    m.bone("ArmR", "root", (3 * k, 9.2 * k, 0))
    m.bone("LegL", "root", (-1.3 * k, 4.4 * k, 0))
    m.bone("LegR", "root", (1.3 * k, 4.4 * k, 0))
    for side, s in (("L", -1), ("R", 1)):
        leg = "Leg" + side
        m.block("Leg" + side, leg, (1.7 * k, 3.4 * k, 1.9 * k), (s * 1.3 * k, 2.9 * k, 0), STEEL)
        m.block("Boot" + side, leg, (1.9 * k, 1.3 * k, 2.6 * k), (s * 1.3 * k, 0.65 * k, -0.3 * k), STEEL_DARK)
        arm = "Arm" + side
        m.block("Pauldron" + side, arm, (2.4 * k, 1.4 * k, 2.6 * k), (s * 3.3 * k, 9.3 * k, 0), STEEL)
        m.block("Arm" + side, arm, (1.5 * k, 3.6 * k, 1.6 * k), (s * 3.3 * k, 7.2 * k, 0), STEEL_DARK)
        m.block("Gauntlet" + side, arm, (1.7 * k, 1.4 * k, 1.8 * k), (s * 3.3 * k, 5.2 * k, 0), STEEL)
    m.block("Torso", "root", (5 * k, 4.8 * k, 3.2 * k), (0, 7.4 * k, 0), STEEL)
    m.block("Tabard", "root", (3.6 * k, 5.6 * k, 0.3 * k), (0, 6.4 * k, -1.7 * k), CRIMSON)
    m.block("TabardBack", "root", (3.6 * k, 4.4 * k, 0.3 * k), (0, 7 * k, 1.7 * k), CRIMSON)
    m.block("Belt", "root", (5.2 * k, 0.6 * k, 3.4 * k), (0, 5.4 * k, 0), GOLD_DARK)
    m.block("Helm", "neck", (3 * k, 3.1 * k, 3.2 * k), (0, 11.2 * k, 0), STEEL)
    m.block("Visor", "neck", (2.3 * k, 0.4 * k, 0.1 * k), (0, 11.3 * k, -1.63 * k), DARK, plain=True)
    m.block("VisorBar", "neck", (0.4 * k, 1.6 * k, 0.1 * k), (0, 10.5 * k, -1.63 * k), DARK, plain=True)
    if plume:
        m.block("Plume", "neck", (0.7 * k, 1.3 * k, 3.6 * k), (0, 13.3 * k, 0.4 * k), CRIMSON)
        m.block("Plume2", "neck", (0.7 * k, 1.4 * k, 1.2 * k), (0, 12.6 * k, 2.4 * k), CRIMSON)


def knight_gaits(m, k):
    m.anim("idle", 2.6, {
        "root": {"p": bob(2.6, 0.1 * k)},
        "neck": {"r": wave(2.6, (3, 5, 0))},
        "ArmL": {"r": wave(2.6, (3, 0, 0))},
        "ArmR": {"r": wave(2.6, (3, 0, 0), 0.3)},
    })
    walk = {
        "root": {"p": bob(1.0, 0.3 * k, 0.25, double=True), "r": wave(1.0, (0, 4, 2))},
        "LegL": {"r": wave(1.0, (24, 0, 0))},
        "LegR": {"r": wave(1.0, (-24, 0, 0))},
        "ArmL": {"r": wave(1.0, (-8, 0, 0))},
        "ArmR": {"r": wave(1.0, (10, 0, 0))},
    }
    m.anim("walk", 1.0, walk)
    gallop_from(m, walk, 0.65)


def run_after(m, hit, end, bones=("LegL", "LegR")):
    """bones' gallop from hit to end (eased in and out): a charge keeps running."""
    gl = m.anims["gallop"]
    tracks = {}
    for b in bones:
        tr = gl["tracks"][b]
        out = {}
        for key, keys in tr.items():
            seq, t0 = [], hit
            while t0 < end - 0.05:
                seq += [(t0 + t, x, y, z) for t, x, y, z in keys if t0 + t < end - 0.05 and (not seq or t > 0)]
                t0 += gl["length"]
            out[key] = [(0, 0, 0, 0), (max(0, hit - 0.15), 0, 0, 0)] + seq + [(end, 0, 0, 0)]
        tracks[b] = out
    return tracks


# ---------------------------------------------------------------------------------------
# Red Castle: Crimson Knight (the raid boss). A big steel knight in a crimson tabard, a
# plumed helm, a crimson tower shield with a gold diamond, and a long steel lance held
# upright. Charge: couches the lance and leans in, then runs down the lane. Slam: raises
# his shield, then bashes it down. Summon: draws the lance up, then thrusts it at the sky.
# ---------------------------------------------------------------------------------------
def crimson_knight():
    m = Model("CrimsonKnight", "Crimson Knight: Red Castle raid boss. Bones: root, neck, ArmL (shield), ArmR (lance), LegL, LegR.")
    k = 1.0
    knight_body(m, k)
    # tower shield, held on his left facing forward
    m.block("ShieldRim", "ArmL", (4.4, 6.6, 0.5), (-3.4, 6.4, -2.1), GOLD_DARK, r=(0, 20, 0))
    m.block("Shield", "ArmL", (3.8, 6, 0.4), (-3.45, 6.4, -2.3), CRIMSON, r=(0, 20, 0))
    m.block("Emblem", "ArmL", (1.3, 1.3, 0.2), (-3.5, 6.8, -2.55), GOLD, r=(0, 20, 45))
    # lance, upright in his right hand
    m.block("Grip", "ArmR", (0.6, 2, 0.6), (3.3, 5.2, 0), STEEL_DARK)
    m.block("Vamplate", "ArmR", (1.8, 1, 1.8), (3.3, 6.6, 0), STEEL)
    m.block("Shaft", "ArmR", (1, 4, 1), (3.3, 9.1, 0), STEEL)
    m.block("Shaft2", "ArmR", (0.7, 3.6, 0.7), (3.3, 12.9, 0), STEEL)
    m.block("LanceTip", "ArmR", (0.4, 2, 0.4), (3.3, 15.6, 0), STEEL_DARK)
    m.block("Pennant", "ArmR", (0.1, 1.2, 1.8), (3.3, 13.8, 1.2), CRIMSON)
    knight_gaits(m, k)
    # charge (1.0s windup): couches the lance level under his arm, crouches and leans in
    # behind his shield, then runs down the lane from the hit
    m.anim("charge", 2.1, dict(run_after(m, 1.0, 2.0), **{
        "ArmR": {"r": [(0, 0, 0, 0), (0.6, -82, 0, 0), (1.0, -86, 0, 0), (2.0, -84, 0, 0), (2.1, 0, 0, 0)]},
        "ArmL": {"r": [(0, 0, 0, 0), (0.6, 20, -20, 0), (2.0, 20, -20, 0), (2.1, 0, 0, 0)]},
        "root": {"r": [(0, 0, 0, 0), (0.6, -12, 0, 0), (1.0, -16, 0, 0), (2.0, -14, 0, 0), (2.1, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.6, 0, -0.7, 0), (1.0, 0, -0.4, 0), (2.0, 0, -0.4, 0), (2.1, 0, 0, 0)]},
        "neck": {"r": [(0, 0, 0, 0), (0.6, 12, 0, 0), (2.0, 12, 0, 0), (2.1, 0, 0, 0)]},
    }), hit=1.0)
    # slam (0.8s windup): shield hauled up high, then bashed down in front at the hit
    m.anim("slam", 1.5, {
        "ArmL": {"r": [(0, 0, 0, 0), (0.6, 80, 0, 10), (0.7, 86, 0, 10), (0.8, 18, 0, 0), (1.1, 16, 0, 0), (1.5, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.6, 0, 0.8, 0), (0.8, 0, -0.3, 0), (1.5, 0, 0, 0)]},
        "root": {"r": [(0, 0, 0, 0), (0.7, 8, 0, 0), (0.8, -14, 0, 0), (1.1, -12, 0, 0), (1.5, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.7, 0, 0.3, 0), (0.8, 0, -0.6, -0.4), (1.1, 0, -0.5, -0.3), (1.5, 0, 0, 0)]},
        "LegL": {"r": [(0, 0, 0, 0), (0.7, 0, 0, 0), (0.8, 18, 0, 0), (1.1, 16, 0, 0), (1.5, 0, 0, 0)]},
        "LegR": {"r": [(0, 0, 0, 0), (0.7, 0, 0, 0), (0.8, -12, 0, 0), (1.1, -10, 0, 0), (1.5, 0, 0, 0)]},
    }, hit=0.8)
    # summon (1.0s windup): draws the lance back and down, then thrusts it high at the sky
    # at the hit (his guards drop in) and holds it there
    m.anim("summon", 2.0, {
        "ArmR": {"r": [(0, 0, 0, 0), (0.7, 22, 0, 0), (0.85, 24, 0, 0), (1.0, -6, 0, -8), (1.6, -6, 0, -8), (2.0, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.7, 0, -0.6, 0), (1.0, 0, 2.6, 0), (1.6, 0, 2.5, 0), (2.0, 0, 0, 0)]},
        "root": {"r": [(0, 0, 0, 0), (0.7, -4, 0, 0), (1.0, 6, 0, 0), (1.6, 6, 0, 0), (2.0, 0, 0, 0)]},
        "neck": {"r": [(0, 0, 0, 0), (0.7, -8, 0, 0), (1.0, 18, 0, 0), (1.6, 16, 0, 0), (2.0, 0, 0, 0)]},
        "ArmL": {"r": [(0, 0, 0, 0), (1.0, 0, 0, -12), (1.6, 0, 0, -12), (2.0, 0, 0, 0)]},
    }, hit=1.0)
    return m


# the Crimson Knight's Castle Guards (minions): half his size, a spear and a round shield
def castle_guard():
    m = Model("CastleGuard", "Castle Guard: the Crimson Knight's minion. Bones: root, neck, ArmL, ArmR, LegL, LegR.")
    k = 0.55
    knight_body(m, k, plume=False)
    m.block("Shield", "ArmL", (2.2, 2.2, 0.3), (-2.0, 3.6, -1.1), CRIMSON, r=(0, 20, 0))
    m.block("Boss", "ArmL", (0.6, 0.6, 0.2), (-2.05, 3.6, -1.3), GOLD, r=(0, 20, 0))
    m.block("Spear", "ArmR", (0.3, 7, 0.3), (1.8, 4.6, 0), (120, 84, 60))
    m.block("SpearTip", "ArmR", (0.45, 1.2, 0.2), (1.8, 8.6, 0), STEEL, r=(0, 0, 45))
    knight_gaits(m, k)
    return m


# ---------------------------------------------------------------------------------------
# Red Castle: Blood Bat. A round crimson bat hovering on two huge wings, big pointed ears,
# yellow eyes and two little fangs. Screech: spreads its wings wide and throws its head
# back, then screams at the hit, shaking.
# ---------------------------------------------------------------------------------------
def blood_bat():
    m = Model("BloodBat", "Blood Bat: Red Castle boss, hovers. Bones: root, WingL, WingR.")
    MEMBRANE = (196, 54, 72)
    EAR_IN = (236, 120, 140)
    m.bone("root", None, (0, 8, 0))
    m.bone("WingL", "root", (-2.6, 9, 0.2))
    m.bone("WingR", "root", (2.6, 9, 0.2))

    m.block("Body", "root", (5.4, 5.2, 5), (0, 8, 0), CRIMSON)
    m.block("Belly", "root", (3.6, 3, 0.3), (0, 7.2, -2.55), CRIMSON_DARK)
    for side, s in (("L", -1), ("R", 1)):
        m.wedge("Ear" + side, "root", (1.6, 3.2, 1.4), (s * 1.6, 12.1, -0.4), CRIMSON, r=(0, 180, s * 10))
        m.block("EarIn" + side, "root", (0.9, 1.8, 0.1), (s * 1.6, 11.6, -1.13), EAR_IN, plain=True, r=(0, 0, s * -10))
        m.block("Eye" + side, "root", (1.1, 0.8, 0.1), (s * 1.15, 9.2, -2.54), (255, 220, 60), neon=True)
        m.wedge("Fang" + side, "root", (0.4, 0.8, 0.2), (s * 0.6, 7.6, -2.62), WHITE, r=(180, 0, 0))
        m.block("Foot" + side, "root", (0.7, 1, 0.7), (s * 1, 4.9, 0.4), CRIMSON_DARK)
        b = "Wing" + side
        m.block("Spar" + side, b, (7, 0.6, 0.6), (s * 6, 9.6, -0.4), CRIMSON_DARK, r=(0, 0, s * -10))
        m.block("Membrane" + side, b, (6.6, 0.3, 4.4), (s * 6, 9.2, 1.6), MEMBRANE, r=(0, 0, s * -10))
        m.block("Finger" + side, b, (0.5, 0.5, 4.6), (s * 9.2, 8.7, 1.6), CRIMSON_DARK, r=(0, 0, s * -10))
        m.block("Finger2" + side, b, (0.5, 0.5, 3.8), (s * 5.4, 9.3, 2.1), CRIMSON_DARK, r=(0, 0, s * -10))

    m.anim("idle", 0.7, {
        "root": {"p": wave(0.7, (0, 0.4, 0), 0.25)},
        "WingL": {"r": wave(0.7, (0, 0, 32))},
        "WingR": {"r": wave(0.7, (0, 0, -32))},
    })
    walk = {
        "root": {"p": wave(0.5, (0, 0.4, 0), 0.25), "r": [(0, -10, 0, 0), (0.5, -10, 0, 0)]},
        "WingL": {"r": wave(0.5, (0, 0, 38))},
        "WingR": {"r": wave(0.5, (0, 0, -38))},
    }
    m.anim("walk", 0.5, walk)
    gallop_from(m, walk, 0.35)
    # screech (0.6s windup): rises with its wings spread wide and back and its head thrown
    # back, then screams at the hit, wings flared, shaking
    shake = [(0.6 + i * 0.05, -8, (3 if i % 2 else -3), 0) for i in range(8)]
    m.anim("screech", 1.3, {
        "root": {"r": [(0, 0, 0, 0), (0.45, 20, 0, 0), (0.6, -8, 0, 0)] + shake + [(1.3, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.45, 0, 1.2, 0.4), (0.6, 0, 0.6, -0.4), (1.0, 0, 0.6, -0.4), (1.3, 0, 0, 0)]},
        "WingL": {"r": [(0, 0, 0, 0), (0.45, 0, 30, -40), (0.6, 0, -10, 12), (1.0, 0, -10, 10), (1.3, 0, 0, 0)]},
        "WingR": {"r": [(0, 0, 0, 0), (0.45, 0, -30, 40), (0.6, 0, 10, -12), (1.0, 0, 10, -10), (1.3, 0, 0, 0)]},
    }, hit=0.6)
    return m


# ---------------------------------------------------------------------------------------
# Red Castle: Castle Wyvern. A dark red dragon: a body block on four stubby legs, a neck
# rising to a horned head, two big wings folded up, a tail with a spade. Breath: rears its
# head up and back, then thrusts it down the lane at the hit, holding the flame. Leap:
# wings raised, crouched, one big downbeat at the hit, then lands.
# ---------------------------------------------------------------------------------------
def castle_wyvern():
    m = Model("CastleWyvern", "Castle Wyvern: Red Castle boss. Bones: root, neck, WingL, WingR, Tail.")
    RED = (150, 30, 44)
    RED_DARK = (100, 18, 32)
    BELLY = (236, 196, 150)
    WING = (200, 70, 60)
    HORN = (240, 226, 200)
    m.bone("root", None, (0, 5, 0))
    m.bone("neck", "root", (0, 6.4, -3.4))
    m.bone("WingL", "root", (-2.4, 7, -1))
    m.bone("WingR", "root", (2.4, 7, -1))
    m.bone("Tail", "root", (0, 5, 3.8))

    m.block("Body", "root", (5, 4.6, 8), (0, 5.2, 0), RED)
    m.block("Belly", "root", (4, 0.8, 6.6), (0, 2.85, -0.2), BELLY)
    for i, z in enumerate((-2.2, 0, 2.2)):
        m.wedge("Spine%d" % i, "root", (0.5, 1.2, 1.6), (0, 8.1, z), RED_DARK, r=(0, 180, 0))
    for side, s in (("L", -1), ("R", 1)):
        for end, z in (("F", -2.6), ("B", 2.4)):
            m.block("Leg" + side + end, "root", (1.6, 3.2, 1.8), (s * 2, 1.6, z), RED_DARK)
            m.block("Claw" + side + end, "root", (1.7, 0.5, 0.6), (s * 2, 0.25, z - 1.1), HORN)
    m.block("Neck", "neck", (2.4, 2.4, 3.6), (0, 7.9, -4.6), RED, r=(32, 0, 0))
    m.block("Head", "neck", (3.2, 2.6, 3.6), (0, 9.8, -6.8), RED)
    m.block("Snout", "neck", (2.6, 1.6, 2.6), (0, 9.2, -9.6), RED)
    m.block("Chin", "neck", (2.4, 0.6, 2.4), (0, 8.15, -9.4), BELLY)
    for side, s in (("L", -1), ("R", 1)):
        m.block("Eye" + side, "neck", (0.1, 0.5, 1), (s * 1.63, 10.2, -7.8), (255, 210, 60), neon=True)
        m.wedge("Horn" + side, "neck", (0.6, 1, 2.6), (s * 1.1, 11.4, -5.4), HORN, r=(-20, 0, 0))
        m.block("Nostril" + side, "neck", (0.4, 0.3, 0.1), (s * 0.6, 9.6, -10.93), DARK, plain=True)
        b = "Wing" + side
        m.block("WingArm" + side, b, (8, 0.8, 0.8), (s * 5.6, 9.3, -1), RED_DARK, r=(0, 0, s * -35))
        m.block("Wing" + side, b, (7.6, 0.3, 6.4), (s * 5.4, 9.0, 2.2), WING, r=(0, 0, s * -35))
    m.block("Tail1", "Tail", (2.2, 2, 3.4), (0, 4.8, 5.4), RED)
    m.block("Tail2", "Tail", (1.5, 1.4, 3.2), (0, 4.2, 8.6), RED)
    m.wedge("Spade", "Tail", (2.4, 0.5, 1.8), (0, 4.0, 11), RED_DARK, r=(0, 180, 0))

    m.anim("idle", 2.6, {
        "root": {"p": bob(2.6, 0.2)},
        "neck": {"r": wave(2.6, (4, 6, 0), 0.25)},
        "WingL": {"r": wave(2.6, (0, 0, -6))},
        "WingR": {"r": wave(2.6, (0, 0, 6))},
        "Tail": {"r": wave(2.6, (0, 12, 0), 0.4)},
    })
    walk = {
        "root": {"p": bob(0.8, 0.4, double=True), "r": wave(0.8, (0, 5, 4))},
        "neck": {"r": wave(0.8, (6, -6, 0), 0.25)},
        "WingL": {"r": wave(0.8, (0, 0, -10), 0.5)},
        "WingR": {"r": wave(0.8, (0, 0, 10), 0.5)},
        "Tail": {"r": wave(0.8, (0, 18, 0), 0.25)},
    }
    m.anim("walk", 0.8, walk)
    gallop_from(m, walk, 0.55)
    # breath (1.0s windup): head reared up and back, wings half open, then at the hit the
    # head thrusts forward and down the lane and holds the flame, shuddering
    m.anim("breath", 2.2, {
        "neck": {"r": [(0, 0, 0, 0), (0.75, 30, 0, 0), (0.88, 32, 0, 0), (1.0, -16, 0, 0), (1.2, -16, 3, 0), (1.4, -16, -3, 0),
                       (1.6, -16, 3, 0), (1.8, -14, 0, 0), (2.2, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.88, 0, 0, 0.6), (1.0, 0, 0, -0.8), (1.8, 0, 0, -0.6), (2.2, 0, 0, 0)]},
        "root": {"r": [(0, 0, 0, 0), (0.88, 6, 0, 0), (1.0, -6, 0, 0), (1.8, -5, 0, 0), (2.2, 0, 0, 0)]},
        "WingL": {"r": [(0, 0, 0, 0), (0.88, 0, 0, -30), (1.0, 0, 0, 10), (1.8, 0, 0, 8), (2.2, 0, 0, 0)]},
        "WingR": {"r": [(0, 0, 0, 0), (0.88, 0, 0, 30), (1.0, 0, 0, -10), (1.8, 0, 0, -8), (2.2, 0, 0, 0)]},
        "Tail": {"r": [(0, 0, 0, 0), (0.88, -14, 0, 0), (1.0, 8, 0, 0), (2.2, 0, 0, 0)]},
    }, hit=1.0)
    # leap (0.8s windup): wings raised high, crouched; one big downbeat at the hit as it
    # takes off, wings beating through the jump, then lands heavily
    m.anim("leap", 2.0, {
        "root": {"p": [(0, 0, 0, 0), (0.6, 0, -1, 0), (0.8, 0, 2.6, 0), (1.3, 0, 2.2, 0), (1.55, 0, -0.8, 0), (2.0, 0, 0, 0)],
                 "r": [(0, 0, 0, 0), (0.6, -6, 0, 0), (0.8, 8, 0, 0), (1.3, 2, 0, 0), (1.55, -6, 0, 0), (2.0, 0, 0, 0)]},
        "WingL": {"r": [(0, 0, 0, 0), (0.6, 0, 0, -70), (0.8, 0, 0, 30), (1.0, 0, 0, -50), (1.2, 0, 0, 25), (1.4, 0, 0, -40), (1.55, 0, 0, 10), (2.0, 0, 0, 0)]},
        "WingR": {"r": [(0, 0, 0, 0), (0.6, 0, 0, 70), (0.8, 0, 0, -30), (1.0, 0, 0, 50), (1.2, 0, 0, -25), (1.4, 0, 0, 40), (1.55, 0, 0, -10), (2.0, 0, 0, 0)]},
        "neck": {"r": [(0, 0, 0, 0), (0.6, -10, 0, 0), (0.8, 12, 0, 0), (1.55, -12, 0, 0), (2.0, 0, 0, 0)]},
        "Tail": {"r": [(0, 0, 0, 0), (0.6, 10, 0, 0), (0.8, -16, 0, 0), (1.55, 12, 0, 0), (2.0, 0, 0, 0)]},
    }, hit=0.8)
    return m


BUILDERS = [scorpion_king, frost_golem, blizzard_owl, magma_slime, bone_warden, skeleton, dungeon_watcher, treasure_mimic,
            rune_mage, elder_treant, toadstool_king, crimson_knight, castle_guard, blood_bat, castle_wyvern]


def models():
    return [b() for b in BUILDERS]


if __name__ == "__main__":
    for m in models():
        if len(sys.argv) < 2 or m.name in sys.argv[1:]:
            m.write()
