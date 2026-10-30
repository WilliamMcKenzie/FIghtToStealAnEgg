"""Attack animations for the bosses whose models came from Blockbench (QM's roster, Oct 30:
/mnt/project-files/boss-roster/design.md). Each keeps its shape, idle and gaits; this adds
the named animations its attacks play (Server/BossAttacks' Anim), each with its `hit`
mark at the end of the attack's windup.

  python3 tools/boss_anims.py [Model ...]   # adds them to src/shared/Animals/<Model>Model.luau
  python3 tools/render_boss.py MajesticUnicorn   # see them

Keys as in tools/boss_designs.py: (t, x, y, z), rotations in degrees, positions in studs.
"""

import sys

import boss_luau


def cycle(model, gait, bones, start, end, fade=0.12, scale=1.0, steps_per_s=20):
    """bones' own `gait` (its gallop, its walk) played from start to end seconds of the
    attack, eased in and out over fade: the legs keep running through a charge (a playOnce
    animation silences its gaits on every bone it doesn't move)."""
    a = model.anims[gait]
    from render_boss import sample

    tracks = {}
    n = max(2, int((end - start) * steps_per_s))
    for bone in bones:
        tr = a["tracks"].get(bone)
        if not tr:
            continue
        out = {}
        for key in ("r", "p"):
            if key not in tr:
                continue
            keys = []
            for i in range(n + 1):
                t = start + (end - start) * i / n
                w = min(1, (t - start) / fade, (end - t) / fade) if fade > 0 else 1
                v = sample(tr[key], (t - start) % a["length"], key not in tr.get("linear", ()))
                keys.append((round(t, 4), *(x * w * scale for x in v)))
            out[key] = keys
        tracks[bone] = out
    return tracks


def merge(*trackses):
    """Several { bone: { r, p } } into one (a bone's later keys add on in time order)."""
    out = {}
    for tracks in trackses:
        for bone, tr in tracks.items():
            dest = out.setdefault(bone, {})
            for key, keys in tr.items():
                dest[key] = sorted(dest.get(key, []) + list(keys), key=lambda k: k[0])
    return out


# ---------------------------------------------------------------------------------------
def majestic_unicorn(m):
    # charge (1.0s windup): rears up pawing the air, drops onto its front hooves with its
    # head down and horn levelled, then at the hit dashes down the red lane at a gallop
    legs = cycle(m, "gallop", ["LegFL", "LegFR", "LegHL", "LegHR"], 1.0, 1.9)
    return {"charge": {"length": 2.1, "hit": 1.0, "tracks": merge(legs, {
        "root": {"r": [(0, 0, 0, 0), (0.35, 24, 0, 0), (0.55, 22, 0, 0), (0.8, -6, 0, 0), (1.0, -8, 0, 0), (1.9, -8, 0, 0), (2.1, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.35, 0, 1.1, 0.4), (0.55, 0, 1.0, 0.4), (0.8, 0, -0.4, 0), (1.0, 0, -0.2, -0.6), (1.9, 0, -0.2, -0.6), (2.1, 0, 0, 0)]},
        "neck": {"r": [(0, 0, 0, 0), (0.35, 14, 0, 0), (0.55, 10, 0, 0), (0.8, -38, 0, 0), (1.0, -42, 0, 0), (1.9, -40, 0, 0), (2.1, 0, 0, 0)]},
        "LegFL": {"r": [(0, 0, 0, 0), (0.2, 70, 0, 0), (0.35, 30, 0, 0), (0.5, 70, 0, 0), (0.75, 0, 0, 0)]},
        "LegFR": {"r": [(0, 0, 0, 0), (0.28, 40, 0, 0), (0.42, 80, 0, 0), (0.58, 30, 0, 0), (0.8, 0, 0, 0)]},
        "LegHL": {"r": [(0, 0, 0, 0), (0.35, -22, 0, 0), (0.6, -20, 0, 0), (0.85, -14, 0, 0)]},
        "LegHR": {"r": [(0, 0, 0, 0), (0.35, -22, 0, 0), (0.6, -20, 0, 0), (0.85, -14, 0, 0)]},
    })}}


def venus_flytrap(m):
    # slam (0.9s windup): its head pulls back up on its stem with the mouth gaping, then
    # snaps forward and down at the hit, jaws shutting, and shakes as it lets go
    return {"slam": {"length": 1.5, "hit": 0.9, "tracks": {
        "root": {"r": [(0, 0, 0, 0), (0.7, 6, 0, 0), (0.9, -6, 0, 0), (1.5, 0, 0, 0)]},
        "neck": {"r": [(0, 0, 0, 0), (0.55, 22, 0, 0), (0.75, 26, 0, 0), (0.9, -34, 0, 0), (1.05, -30, 6, 0), (1.15, -30, -6, 0), (1.25, -28, 0, 0), (1.5, 0, 0, 0)]},
        "group": {"r": [(0, 0, 0, 0), (0.55, -22, 0, 0), (0.75, -26, 0, 0), (0.9, 34, 0, 0), (1.25, 30, 0, 0), (1.5, 0, 0, 0)]},
        "Jaw": {"r": [(0, 0, 0, 0), (0.55, 16, 0, 0), (0.75, 18, 0, 0), (0.9, -4, 0, 0), (1.25, -4, 0, 0), (1.5, 0, 0, 0)]},
    }}}


def elder_boar(m):
    # charge (1.1s windup): drops its head with its tusks levelled and scrapes the ground
    # twice with a front hoof, then at the hit thunders down the red lane at a gallop
    legs = cycle(m, "gallop", ["LegFL", "LegFR", "LegHL", "LegHR"], 1.1, 2.0)
    return {"charge": {"length": 2.2, "hit": 1.1, "tracks": merge(legs, {
        "root": {"r": [(0, 0, 0, 0), (0.3, -6, 0, 0), (0.9, -6, 0, 0), (1.1, -9, 0, 0), (2.0, -8, 0, 0), (2.2, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.3, 0, -0.4, 0.4), (0.9, 0, -0.5, 0.6), (1.1, 0, -0.3, -0.6), (2.0, 0, -0.3, -0.6), (2.2, 0, 0, 0)]},
        "neck": {"r": [(0, 0, 0, 0), (0.3, -6, 0, 0), (0.6, -5, 0, 0), (0.9, -7, 0, 0), (1.1, -8, 0, 0), (2.0, -8, 0, 0), (2.2, 0, 0, 0)]},
        "LegFL": {"r": [(0, 0, 0, 0), (0.25, 0, 0, 0), (0.42, -40, 0, 0), (0.58, 12, 0, 0), (0.75, -40, 0, 0), (0.92, 10, 0, 0), (1.05, 0, 0, 0)]},
        "LegFR": {"r": [(0, 0, 0, 0), (0.3, 8, 0, 0), (1.0, 8, 0, 0), (1.08, 0, 0, 0)]},
        "LegHL": {"r": [(0, 0, 0, 0), (0.3, -10, 0, 0), (1.0, -10, 0, 0), (1.08, 0, 0, 0)]},
        "LegHR": {"r": [(0, 0, 0, 0), (0.3, -10, 0, 0), (1.0, -10, 0, 0), (1.08, 0, 0, 0)]},
        "Tail": {"r": [(0, 0, 0, 0), (0.4, 0, 0, 25), (0.6, 0, 0, -25), (0.8, 0, 0, 25), (1.0, 0, 0, -20), (1.1, 20, 0, 0), (2.0, 24, 0, 0), (2.2, 0, 0, 0)]},
        "EarL": {"r": [(0, 0, 0, 0), (0.3, 30, 0, 0), (2.0, 30, 0, 0), (2.2, 0, 0, 0)]},
        "EarR": {"r": [(0, 0, 0, 0), (0.3, 30, 0, 0), (2.0, 30, 0, 0), (2.2, 0, 0, 0)]},
    })}}


def lava_wyrm(m):
    # breath (1.0s windup): its neck coils up and back with its head high, then at the hit
    # thrusts forward and down along the red lane, jaw wide, holding the flame a moment
    # with a shudder before it coils back
    return {"breath": {"length": 2.3, "hit": 1.0, "tracks": {
        "NeckBase": {"r": [(0, 0, 0, 0), (0.7, 22, 0, 0), (0.85, 24, 0, 0), (1.0, 6, 0, 0), (1.9, 6, 0, 0), (2.3, 0, 0, 0)]},
        "neck": {"r": [(0, 0, 0, 0), (0.7, 26, 0, 0), (0.85, 28, 0, 0), (1.0, 2, 0, 0), (1.9, 2, 0, 0), (2.3, 0, 0, 0)]},
        "NeckTop": {"r": [(0, 0, 0, 0), (0.7, 6, 0, 0), (0.85, 4, 0, 0), (1.0, -4, 0, 0), (1.9, -4, 0, 0), (2.3, 0, 0, 0)]},
        "Head": {"r": [(0, 0, 0, 0), (0.7, -26, 0, 0), (0.85, -28, 0, 0), (1.0, 4, 0, 0), (1.2, 4, 3, 0), (1.4, 4, -3, 0),
                       (1.6, 4, 3, 0), (1.8, 4, -3, 0), (1.9, 4, 0, 0), (2.3, 0, 0, 0)]},
        "Jaw": {"r": [(0, 0, 0, 0), (0.7, -8, 0, 0), (0.85, -10, 0, 0), (1.0, -34, 0, 0), (1.9, -32, 0, 0), (2.3, 0, 0, 0)]},
        "root": {"p": [(0, 0, 0, 0), (0.85, 0, 0, 0.8), (1.0, 0, 0, -0.6), (1.9, 0, 0, -0.5), (2.3, 0, 0, 0)]},
    }}}


def volcano_tortoise(m):
    # erupt (0.8s windup): pulls its head and legs into its shell, the shell shudders and
    # sinks, then at the hit it pops back up as the volcano on its back blows
    shake = [(0.3 + i * 0.06, 0, 0, (4 if i % 2 else -4) * (0.5 + i / 16)) for i in range(9)]
    legs = {}
    for leg in ("LegFL", "LegFR", "LegHL", "LegHR"):
        x = -0.5 if leg[-1] == "L" else 0.5
        legs[leg] = {"p": [(0, 0, 0, 0), (0.3, -x, 0.9, 0), (0.8, -x, 0.9, 0), (0.9, 0, -0.2, 0), (1.1, 0, 0, 0)]}
    return {"erupt": {"length": 1.5, "hit": 0.8, "tracks": dict(legs, **{
        "root": {"p": [(0, 0, 0, 0), (0.3, 0, -0.6, 0), (0.8, 0, -0.8, 0), (0.9, 0, 0.9, 0), (1.1, 0, -0.1, 0), (1.5, 0, 0, 0)],
                 "r": [(0, 0, 0, 0), (0.25, 0, 0, 0)] + shake + [(0.85, 0, 0, 0), (0.9, -4, 0, 0), (1.5, 0, 0, 0)]},
        "neck": {"p": [(0, 0, 0, 0), (0.3, 0, -0.3, 1.6), (0.8, 0, -0.3, 1.7), (0.92, 0, 0.2, -0.2), (1.2, 0, 0, 0)],
                 "r": [(0, 0, 0, 0), (0.8, 0, 0, 0), (0.92, 18, 0, 0), (1.5, 0, 0, 0)]},
        "Tail": {"p": [(0, 0, 0, 0), (0.3, 0, 0, -0.8), (0.8, 0, 0, -0.8), (1.0, 0, 0, 0)]},
    })}}


def king_crab(m):
    # slam (claw smash): both pincers rise high over its shell, then crash down in front
    # at the hit. charge (sideways scuttle): it crouches with its pincers up, then at the
    # hit scuttles off with its legs running (its walk, quick)
    slam = {"length": 1.3, "hit": 0.8, "tracks": {
        "pincer0": {"r": [(0, 0, 0, 0), (0.6, 48, 0, 20), (0.7, 52, 0, 22), (0.8, -24, 0, 0), (1.0, -20, 0, 0), (1.3, 0, 0, 0)]},
        "pincer1": {"r": [(0, 0, 0, 0), (0.6, 48, 0, -20), (0.7, 52, 0, -22), (0.8, -24, 0, 0), (1.0, -20, 0, 0), (1.3, 0, 0, 0)]},
        "top_pincer": {"r": [(0, 0, 0, 0), (0.6, 0, -30, 0), (0.8, 0, 0, 0)]},
        "top_pincer2": {"r": [(0, 0, 0, 0), (0.6, 0, 30, 0), (0.8, 0, 0, 0)]},
        "body": {"r": [(0, 0, 0, 0), (0.7, 8, 0, 0), (0.8, -8, 0, 0), (1.0, -6, 0, 0), (1.3, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.7, 0, 0.3, 0), (0.8, 0, -0.15, 0), (1.3, 0, 0, 0)]},
    }}
    legs = cycle(m, "walk", ["leg0", "bottomleg0", "leg1", "bottomleg1", "leg2", "bottomleg2", "leg3", "bottomleg3"],
                 0.7, 1.6, scale=1.3)
    charge = {"length": 1.8, "hit": 0.7, "tracks": merge(legs, {
        "body": {"p": [(0, 0, 0, 0), (0.5, 0, -0.25, 0), (0.7, 0, -0.2, 0), (1.6, 0, -0.1, 0), (1.8, 0, 0, 0)],
                 "r": [(0, 0, 0, 0), (0.5, -6, 0, 0), (1.6, -4, 0, 0), (1.8, 0, 0, 0)]},
        "pincer0": {"r": [(0, 0, 0, 0), (0.5, 30, 0, 14), (1.6, 26, 0, 12), (1.8, 0, 0, 0)]},
        "pincer1": {"r": [(0, 0, 0, 0), (0.5, 30, 0, -14), (1.6, 26, 0, -12), (1.8, 0, 0, 0)]},
        "top_pincer": {"r": [(0, 0, 0, 0), (0.35, 0, -25, 0), (0.5, 0, 0, 0), (0.65, 0, -25, 0), (0.8, 0, 0, 0)]},
        "top_pincer2": {"r": [(0, 0, 0, 0), (0.35, 0, 25, 0), (0.5, 0, 0, 0), (0.65, 0, 25, 0), (0.8, 0, 0, 0)]},
    })}
    return {"slam": slam, "charge": charge}


def scorpion_king(m):
    # stab (0.8s windup): its tail cocks back over its body, quivering, then at the hit whips
    # over its head, the stinger driving down the red line in front, and pulls back up
    stab = {"length": 1.4, "hit": 0.8, "tracks": {
        "Tail": {"r": [(0, 0, 0, 0), (0.5, 22, 0, 0), (0.6, 25, 0, 2), (0.68, 23, 0, -2), (0.74, 26, 0, 0), (0.8, -40, 0, 0),
                       (1.0, -36, 0, 0), (1.4, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.7, 0, 0, 0), (0.8, 0, 1.6, -0.8), (1.0, 0, 1.4, -0.7), (1.4, 0, 0, 0)]},
        "root": {"r": [(0, 0, 0, 0), (0.7, 6, 0, 0), (0.8, -8, 0, 0), (1.0, -6, 0, 0), (1.4, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.7, 0, 0, 0.3), (0.8, 0, 0, -0.5), (1.4, 0, 0, 0)]},
    }}
    # pinch (0.5s windup): it rears its front up with both pincers flung wide open, then at
    # the hit lunges and snaps them shut together in front of it
    pinch = {"length": 1.0, "hit": 0.5, "tracks": {
        "ClawL": {"r": [(0, 0, 0, 0), (0.4, 18, 34, 0), (0.5, -6, -16, 0), (0.7, -4, -12, 0), (1.0, 0, 0, 0)]},
        "ClawR": {"r": [(0, 0, 0, 0), (0.4, 18, -34, 0), (0.5, -6, 16, 0), (0.7, -4, 12, 0), (1.0, 0, 0, 0)]},
        "root": {"r": [(0, 0, 0, 0), (0.4, 8, 0, 0), (0.5, -4, 0, 0), (1.0, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.4, 0, 0.2, 0.4), (0.5, 0, 0, -0.8), (0.7, 0, 0, -0.6), (1.0, 0, 0, 0)]},
    }}
    return {"stab": stab, "pinch": pinch}


def shark_boss(m):
    # breach (0.8s windup, the red circle filling): under the floor it thrashes, tail beating
    # faster and faster with its nose tipping up, then at the hit it surges up through the
    # circle nose first, upright with its jaws wide, and hangs there a moment as it falls level
    tail = [(0, 0, 0, 0)] + [(0.1 * i, 0, (1 if i % 2 else -1) * (14 + 3 * i), 0) for i in range(1, 8)] + [
        (0.8, 0, 0, 0), (1.0, 0, 18, 0), (1.2, 0, -18, 0), (1.6, 0, 0, 0)]
    breach = {"length": 1.6, "hit": 0.8, "tracks": {
        "root": {"r": [(0, 0, 0, 0), (0.6, 16, 0, 0), (0.8, 72, 0, 0), (1.05, 64, 0, 0), (1.6, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.6, 0, -0.3, 0), (0.8, 0, 1.6, 0.4), (1.05, 0, 1.5, 0.3), (1.6, 0, 0, 0)]},
        "Jaw": {"r": [(0, 0, 0, 0), (0.6, 10, 0, 0), (0.8, 38, 0, 0), (1.1, 34, 0, 0), (1.6, 0, 0, 0)]},
        "Tail": {"r": tail},
        "TailFin": {"r": [(t, x, y * 0.7, z) for t, x, y, z in tail]},
        "FinL": {"r": [(0, 0, 0, 0), (0.6, 0, 0, -20), (0.8, 0, 0, 30), (1.1, 0, 0, 24), (1.6, 0, 0, 0)]},
        "FinR": {"r": [(0, 0, 0, 0), (0.6, 0, 0, 20), (0.8, 0, 0, -30), (1.1, 0, 0, -24), (1.6, 0, 0, 0)]},
    }}
    # bite (0.8s windup, the swipe's): it draws back, nose up and jaws gaping wider, then at
    # the hit lunges forward and snaps them shut, shakes its head, and swims back
    bite = {"length": 1.4, "hit": 0.8, "tracks": {
        "root": {"r": [(0, 0, 0, 0), (0.65, 14, 0, 0), (0.8, -10, 0, 0), (0.95, -6, 0, 0), (1.4, 0, 0, 0)],
                 "p": [(0, 0, 0, 0), (0.65, 0, 0.25, 0.8), (0.8, 0, 0, -1.6), (0.95, 0, 0, -1.4), (1.4, 0, 0, 0)]},
        "neck": {"r": [(0, 0, 0, 0), (0.8, 0, 0, 0), (0.9, 0, 12, 0), (1.0, 0, -12, 0), (1.1, 0, 8, 0), (1.25, 0, 0, 0)]},
        "Jaw": {"r": [(0, 0, 0, 0), (0.5, 26, 0, 0), (0.7, 40, 0, 0), (0.8, 0, 0, 0), (1.1, 0, 0, 0), (1.4, 0, 0, 0)]},
        "Tail": {"r": [(0, 0, 0, 0), (0.65, 0, 20, 0), (0.75, 0, -26, 0), (0.85, 0, 22, 0), (1.0, 0, -12, 0), (1.4, 0, 0, 0)]},
        "FinL": {"r": [(0, 0, 0, 0), (0.65, 0, 0, -16), (0.8, 0, 0, 22), (1.4, 0, 0, 0)]},
        "FinR": {"r": [(0, 0, 0, 0), (0.65, 0, 0, 16), (0.8, 0, 0, -22), (1.4, 0, 0, 0)]},
    }}
    return {"breach": breach, "bite": bite}


ANIMS = {
    "MajesticUnicorn": majestic_unicorn,
    "VenusFlytrap": venus_flytrap,
    "ElderBoar": elder_boar,
    "LavaWyrm": lava_wyrm,
    "VolcanoTortoise": volcano_tortoise,
    "KingCrab": king_crab,
    "SharkBoss": shark_boss,
    "ScorpionKing": scorpion_king,
}


if __name__ == "__main__":
    for name, fn in ANIMS.items():
        if len(sys.argv) < 2 or name in sys.argv[1:]:
            boss_luau.inject(name, fn(boss_luau.load(name)))
