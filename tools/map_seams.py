"""Seams for the layered rule (QM, Oct 25): floors that touch (8 ways) sit at most half a stud
apart. Where two cells break it, the higher one becomes its area's tile half a stud lower (a
border round a pool, a step at a seam between biomes), again until nothing breaks it. A cell
whose area has no such tile is left, and reported.

Run: python3 tools/map_seams.py [maps/world.map]   (then tools/map_bake.py)
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from map_gen import dump_map  # noqa: E402

STEP = 0.5


def seams(d):
    tiles = {t["id"]: t for t in d["tiles"]}
    floor = {i: t for i, t in tiles.items() if not t.get("wall")}
    lower = {}  # tile id -> its area's floor tile half a stud lower (not a liquid)
    for i, t in floor.items():
        for j, u in floor.items():
            if u["area"] == t["area"] and not u.get("liquid") and abs(u["top"] - (t["top"] - STEP)) < 1e-6:
                lower.setdefault(i, j)
    rows = [list(r) for r in d["rows"]]
    R, C = len(rows), len(rows[0])
    changed, left = 0, set()
    while True:
        moves = {}
        for r in range(R):
            for c in range(C):
                a = floor.get(rows[r][c])
                if not a:
                    continue
                for dr in (-1, 0, 1):
                    for dc in (-1, 0, 1):
                        rr, cc = r + dr, c + dc
                        if (dr or dc) and 0 <= rr < R and 0 <= cc < C:
                            b = floor.get(rows[rr][cc])
                            if b and a["top"] - b["top"] > STEP + 1e-6:
                                if rows[r][c] in lower:
                                    moves[(r, c)] = lower[rows[r][c]]
                                else:
                                    left.add((a["key"], b["key"]))
        if not moves:
            break
        for (r, c), ch in moves.items():
            rows[r][c] = ch
        changed += len(moves)
    d["rows"] = ["".join(r) for r in rows]
    return changed, left


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "maps", "world.map")
    d = json.loads(open(path).read())
    n, left = seams(d)
    open(path, "w").write(dump_map(d))
    print("%d cells stepped down" % n)
    for a, b in sorted(left):
        print("  still breaks it (no tile half a stud lower in its area): %s above %s" % (a, b))
