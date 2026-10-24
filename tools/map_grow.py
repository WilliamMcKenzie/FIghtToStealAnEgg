"""Grow a .map's grid (QM, Oct 24: the map outgrew it at the fork past the Lava).

  grow(d, west=0, east=0, north=0, south=0, fill=".") -> d, with that many 4-stud cells
  added on each side (north is -z: the origin moves), new cells `fill`.
  reframe(d, origin, size) -> d laid into a bigger grid that holds it (serve.py's merge).

Run: python3 tools/map_grow.py maps/world.map west east north south
"""

import json
import sys


def grow(d, west=0, east=0, north=0, south=0, fill="."):
    cols, rows = d["size"]
    cell = d["cell"]
    d["rows"] = ([fill * (west + cols + east)] * north
                 + [fill * west + r + fill * east for r in d["rows"]]
                 + [fill * (west + cols + east)] * south)
    d["origin"] = [d["origin"][0] - west * cell, d["origin"][1] - north * cell]
    d["size"] = [west + cols + east, north + rows + south]
    return d


def reframe(d, origin, size):
    """`d` grown to `origin` and `size`, when that grid holds all of d's (else None)."""
    cell = d["cell"]
    west = (d["origin"][0] - origin[0]) // cell
    north = (d["origin"][1] - origin[1]) // cell
    east = size[0] - d["size"][0] - west
    south = size[1] - d["size"][1] - north
    if min(west, north, east, south) < 0 or (d["origin"][0] - origin[0]) % cell or (d["origin"][1] - origin[1]) % cell:
        return None
    return grow(d, west, east, north, south)


if __name__ == "__main__":
    sys.path.insert(0, __import__("os").path.dirname(__file__))
    from map_gen import dump_map
    path, w, e, n, s = sys.argv[1], *map(int, sys.argv[2:6])
    d = grow(json.loads(open(path).read()), w, e, n, s)
    open(path, "w").write(dump_map(d))
    print("%s: %d x %d cells, origin %s" % (path, *d["size"], d["origin"]))
