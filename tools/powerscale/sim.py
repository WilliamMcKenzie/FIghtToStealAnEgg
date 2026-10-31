"""Rough solo progression sim, read straight from Config.luau (QM, Oct 31: the
powerscaling dashboard's numbers). The successor of tools/balance_sim.py, which had the
numbers copied in by hand.

  python3 tools/powerscale/sim.py [Config.luau] [--side left|right] [--verbose]

A player: fights the boss of the furthest region they own (or the one before, if that takes
over FightCap seconds), steals EggsPerFight eggs there, trains at their best ground through
the nests' cooldown, and buys the cheapest of the next weapon, the next region or a training
ground as soon as they can. Pen = their best 5 pets. Prints when they reach each region and
how fights feel there.
"""

import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import luaconfig  # noqa: E402

FightCap = 120
EggsPerFight = 3
TrainUptime = 0.6


def load(path):
    return luaconfig.parse(open(path).read())[0]


def model(C, side="left"):
    route = ["Meadow", "Desert", "Ice", "Lava"] + (["Dungeon", "Castle"] if side == "left" else ["Forest", "Ocean"])
    P = C["Power"]

    def curve(S):
        x = max(S, 0) / P["Scale"]
        k = P.get("Curve", "Log")
        if k == "Power":
            return x ** P.get("Exponent", 0.5)
        if k == "Linear":
            return x
        if k == "Exp":
            return 1 - math.exp(-x)
        return math.log(1 + x)

    pdmg = lambda S: 1 + P["Damage"] * curve(S)
    pspd = lambda S: min(1 + P["Speed"] * curve(S), P["MaxSpeed"])

    def wdps(id):
        w = C["Weapons"][id]
        if w["Type"] == "Melee":
            cool = (w.get("Slash") or {}).get("Cooldown") or C["Slash"]["Cooldown"]
            n = 1
        else:
            base = C["Shots"].get(w["Type"], {})
            cool = (w.get("Shot") or {}).get("Cooldown") or base.get("Cooldown") or 0.6
            n = (w.get("Shot") or {}).get("Count") or base.get("Count") or 1
        return C["Slash"]["Damage"] * w.get("Damage", 1) * n / cool

    weapons = sorted((w.get("Price", 0), id) for id, w in C["Weapons"].items() if isinstance(w, dict) and w.get("Name"))
    bosses = {b: [C["Bosses"][k] for k in C["BossPools"][b] if k in C["Bosses"]] for b in route}

    def bounty(b):
        nxt = C["BossCash"]["Next"].get(b)
        cost = C["Regions"]["Cost"].get(nxt, 0) if nxt else C["Regions"]["Cost"].get(b, 0) * C["BossCash"]["Last"]
        return max(1, math.floor(cost * C["BossCash"]["Share"]))

    def hit(boss):  # its biggest single hit, and damage a second if every attack lands on time
        top, dps = 0, 0
        for a in boss.get("Attacks") or []:
            d = a.get("Damage", 0)
            if isinstance(a.get("Count"), (int, float)) and a.get("Kind") == "Lob":
                pass
            top = max(top, d)
            dps += d * (a.get("Swings", 1) or 1) / max(a.get("Every", 2), 0.5)
        return top, dps

    return dict(route=route, pdmg=pdmg, pspd=pspd, wdps=wdps, weapons=weapons, bosses=bosses, bounty=bounty, hit=hit)


def petstats(C, kind):
    pet = C["Pets"][kind]
    base = C["PetStats"]["Rarity"].get(pet["Rarity"], C["PetStats"]["Rarity"]["Common"])
    lean = max(-1, min(1, pet.get("Lean", 0))) * C["PetStats"]["Lean"]
    return base["Health"] * (1 + lean)


def run(C, side="left", seed=0, verbose=False, hours=6):
    M = model(C, side)
    route, rnd = M["route"], random.Random(seed)
    T = C["Training"]
    t = cash = S = 0.0
    wi, reg, grounds, pets, hatching = 0, 1, set(), [C["Backpack"]["Starter"]], []
    out, bought = [], []
    dps = lambda: M["wdps"](M["weapons"][wi][1]) * M["pdmg"](S) * M["pspd"](S)
    income = lambda: sum(sorted((C["Pets"][k]["Cash"] for k in pets), reverse=True)[: C["Backpack"]["PenSlots"]])
    hp = lambda b: sum(x["Health"] for x in M["bosses"][b]) / len(M["bosses"][b])

    def arrive(b):
        best = max(pets, key=lambda k: C["Pets"][k]["Cash"])
        out.append(dict(region=b, minutes=t / 60, S=S, weapon=C["Weapons"][M["weapons"][wi][1]]["Name"], dps=dps(),
                        ttk=hp(b) / dps(), income=income(), cash=cash, pet=best))

    arrive(route[0])
    while t < hours * 3600:
        b = route[reg - 1]
        if hp(b) / dps() > FightCap and reg > 1:
            b = route[reg - 2]
        ttk = hp(b) / dps()
        boss = M["bosses"][b][0]
        S += hp(b) * boss.get("Strength", 1) * T["PerDamage"]
        cash += M["bounty"](b) + C["Eggs"]["Reward"].get(b, 0) + income() * ttk
        t += ttk
        kinds = C["Eggs"]["Kinds"][b]
        for _ in range(EggsPerFight):
            if len(hatching) < C["Hatch"]["PenEggs"]:
                k = rnd.choices(list(kinds), weights=list(kinds.values()))[0]
                hatching.append((t + C["Hatch"]["Time"].get(k, C["Hatch"]["Default"]), k))
        cool = C["Eggs"]["Cooldown"].get(b, 60) + 15
        g = max(grounds, key=lambda x: T["Grounds"][x]["Strength"], default=None)
        if g:
            S += dps() * T["Grounds"][g]["Strength"] * T["PerDamage"] * TrainUptime * cool
        cash += income() * cool
        t += cool
        pets += [k for at, k in hatching if at <= t]
        hatching = [x for x in hatching if x[0] > t]
        while True:
            opts = []
            if wi + 1 < len(M["weapons"]):
                opts.append((M["weapons"][wi + 1][0], "w", None))
            if reg < len(route):
                opts.append((C["Regions"]["Cost"][route[reg]], "r", None))
            for gname in route[:reg]:
                if gname in T["Grounds"] and gname not in grounds:
                    opts.append((T["Grounds"][gname]["Cost"], "g", gname))
            if not opts:
                break
            o = min(opts, key=lambda x: x[0])
            if o[0] > cash:
                break
            cash -= o[0]
            if o[1] == "w":
                wi += 1
                bought.append((t, C["Weapons"][M["weapons"][wi][1]]["Name"]))
            elif o[1] == "r":
                reg += 1
                bought.append((t, "REGION " + route[reg - 1]))
                arrive(route[reg - 1])
            else:
                grounds.add(o[2])
                bought.append((t, "ground " + o[2]))
                out.append(dict(region="ground " + o[2], minutes=t / 60, S=S, weapon=C["Weapons"][M["weapons"][wi][1]]["Name"], dps=dps(),
                                ttk=T["Grounds"][o[2]]["Health"] / dps(), income=income(), cash=cash, pet=""))
        if reg == len(route) and cash >= C["Rebirth"]["Cost"] and "rebirth" not in [x["region"] for x in out]:
            out.append(dict(region="rebirth", minutes=t / 60, S=S, weapon=C["Weapons"][M["weapons"][wi][1]]["Name"], dps=dps(), ttk=0, income=income(), cash=cash, pet=""))
    if verbose:
        for at, what in bought:
            print("   %7.1f min  %s" % (at / 60, what))
    return out, M


def report(C, side="left", verbose=False):
    for seed in range(2):
        out, M = run(C, side, seed, verbose and seed == 0)
        for r in out:
            print("%-8s %7.1f min  S=%-9s %-14s dps=%-9s fight %6.1fs  income %s/s  best pet %s" % (
                r["region"], r["minutes"], short(r["S"]), r["weapon"], short(r["dps"]), r["ttk"], short(r["income"]), r["pet"]))
        print()
    # survival: the boss's biggest hit and its damage a second against that biome's pets
    M = model(C, side)
    print("region   boss hit / dps    pet health (worst..best in its eggs)   hits to kill the best pet")
    for b in M["route"]:
        top = max(M["hit"](x)[0] for x in M["bosses"][b])
        hd = max(M["hit"](x)[1] for x in M["bosses"][b])
        hps = sorted(petstats(C, k) for k in C["Eggs"]["Kinds"][b])
        print("%-8s %6s / %-6s     %8s .. %-8s                  %s" % (b, short(top), short(hd), short(hps[0]), short(hps[-1]), short(hps[-1] / max(top, 1))))


def short(v):
    for n, s in ((1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")):
        if abs(v) >= n:
            return "%.3g%s" % (v / n, s)
    return "%.3g" % v


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--") and a not in ("left", "right")]
    path = args[0] if args else os.path.join(HERE, "..", "..", "src", "shared", "Config.luau")
    side = "right" if "right" in sys.argv else "left"
    report(load(path), side, "--verbose" in sys.argv)
