"""Quasicrystal patterns, as QM's map maker draws its tiles (github.com/studio-imperium/atlas,
modifier.go NewPattern and NewSelectiveBorder, used by WilliamMcKenzie/MapMaker mapgen.go).

At a point, add up cos(x cos a + y sin a) for `angles` directions spread round the circle,
and scale the sum to 0..1: the waves interfere into rings and stars that never quite
repeat. pattern() cuts that 0..1 into equal bands, one per value, like atlas does, so the
middle values cover most of the floor and the end ones show as rarer rings and spots.
Coordinates are in pattern units; `scale` studs make one unit (atlas: one tile).
"""
import numpy as np


def value(x, z, angles, scale=1.0):
    """The 0..1 quasicrystal value at (x, z) (arrays fine)."""
    x, z = np.asarray(x, float) / scale, np.asarray(z, float) / scale
    total = np.zeros(np.broadcast(x, z).shape)
    a = 2.0 * 3.14156  # (atlas's own pi)
    delta = a / angles
    i = 0
    while i < angles:
        total += np.cos(np.cos(a) * x + np.sin(a) * z)
        a -= delta
        i += 1
    return (total / angles + 1.0) / 2.0


def pattern(q, values):
    """Each 0..1 value q picks one of values (equal bands, as atlas NewPattern)."""
    idx = np.maximum(0, np.floor(np.asarray(q) * len(values))).astype(int) % len(values)
    return np.asarray(values)[idx]


def selective_border(grid, border, around):
    """Cells of `around` touching (4-way) anything else or the grid edge become `border`
    (atlas NewSelectiveBorder): a rim round each patch of `around`."""
    g = np.asarray(grid)
    pad = np.pad(g, 1, constant_values=-999)
    edge = np.zeros(g.shape, bool)
    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        edge |= pad[1 + dx:1 + dx + g.shape[0], 1 + dz:1 + dz + g.shape[1]] != around
    out = g.copy()
    out[(g == around) & edge] = border
    return out
