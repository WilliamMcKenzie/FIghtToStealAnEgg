# HUD icons without their outlines (QM, Oct 26: every button's outline was a different width,
# since each icon came out of the pack with its own). The outline goes back on in Roblox, the
# same for all of them (src/client/Outline.luau), so it's tuned in one place.
#
# In: assets/ui/icon_src/<Name>.png, the pack's "1st Outline 256px" icons (from ~/Downloads/icons).
# Out, in assets/ui/icons/:
#   Hud<Name>.png      the icon with its navy outline taken off (same 256 canvas, so it lines up)
#   Hud<Name>Mask.png  its silhouette in white, which Outline.luau tints and rings around the icon
#   preview.png     every icon re-outlined at OUTLINE px, on grass, to check by eye
#
#   python3 tools/ui_icons.py [px]        makes them (px: the preview's outline width)
#   OUT=assets/ui/ids.json python3 tools/studio/imgup.py assets/ui/icons/Hud*.png   (on the Mac)
#   python3 tools/ui_icons.py ids         writes their ids into src/client/HudIcons.luau
import os, sys
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui")
SRC, OUT = os.path.join(ROOT, "icon_src"), os.path.join(ROOT, "icons")
NAVY = np.array([4, 4, 53])  # the pack's outline colour
BAND = 17  # px of the 256 canvas in from the edge where the pack's outline sits (12-13 wide)
NEAR = 110  # how close to navy a pixel is to count as outline (catches its anti-aliased rim)


def disk(r):
    return [(dy, dx) for dy in range(-r, r + 1) for dx in range(-r, r + 1) if dx * dx + dy * dy <= r * r + r]


def dilate(mask, r):
    out = mask.copy()
    h, w = mask.shape
    p = np.pad(mask, r)
    for dy, dx in disk(r):
        out |= p[r + dy : r + dy + h, r + dx : r + dx + w]
    return out


def grow(alpha, r):
    # max of alpha over a disk: an anti-aliased outline r px wide
    h, w = alpha.shape
    p = np.pad(alpha, r)
    out = alpha.copy()
    for dy, dx in disk(r):
        np.maximum(out, p[r + dy : r + dy + h, r + dx : r + dx + w], out=out)
    return out


def strip(path):
    a = np.array(Image.open(path).convert("RGBA")).astype(np.int32)
    rgb, alpha = a[..., :3], a[..., 3]
    outside = alpha < 16
    band = dilate(outside, BAND)
    navy = np.sqrt(((rgb - NAVY) ** 2).sum(-1)) < NEAR
    # the outline: navy pixels in the band that touch the outside through other such pixels
    # (so dark details further in, like the Rebirth arrows' gap, stay)
    cand = band & (navy | (alpha < 250)) & ~outside
    gone = outside.copy()
    while True:
        more = dilate(gone, 1) & cand & ~gone
        if not more.any():
            break
        gone |= more
    a[gone & ~outside, 3] = 0
    # one more pass for the dark half-blended rim left between the outline and the colour
    rim = dilate(gone, 1) & ~gone
    dark = rgb.sum(-1) < 200
    a[rim & dark, 3] = 0
    return a.astype(np.uint8)


def outline(icon, px, color=(4, 4, 53)):
    alpha = icon[..., 3].astype(np.int32)
    ring = grow(alpha, px)
    base = np.zeros_like(icon)
    base[..., :3] = color
    base[..., 3] = ring
    im = Image.fromarray(base)
    im.alpha_composite(Image.fromarray(icon))
    return im


def write_ids():
    import json
    ids = json.load(open(os.path.join(ROOT, "ids.json")))
    names = sorted(os.path.splitext(f)[0] for f in os.listdir(SRC) if f.endswith(".png"))
    lines = [
        "-- The HUD icons' image ids (no outline of their own: client/Outline adds it). Written by",
        "-- tools/ui_icons.py ids after the PNGs in assets/ui/icons are uploaded.",
        "return {",
    ]
    for n in names:
        for k in (n, n + "Mask"):
            lines.append(f'\t{k} = "{ids.get("Hud" + k, "")}",')
    lines.append("}")
    path = os.path.join(ROOT, "..", "..", "src", "client", "HudIcons.luau")
    open(path, "w").write("\n".join(lines) + "\n")
    missing = [k for n in names for k in (n, n + "Mask") if "Hud" + k not in ids]
    print("wrote", os.path.normpath(path), "missing:" if missing else "", *missing)


def main():
    if sys.argv[1:] == ["ids"]:
        return write_ids()
    os.makedirs(OUT, exist_ok=True)
    names = sorted(os.path.splitext(f)[0] for f in os.listdir(SRC) if f.endswith(".png"))
    px = int(sys.argv[1]) if len(sys.argv) > 1 else 11
    tiles = []
    for n in names:
        icon = strip(os.path.join(SRC, n + ".png"))
        Image.fromarray(icon).save(os.path.join(OUT, "Hud" + n + ".png"))
        mask = np.zeros_like(icon)
        mask[..., :3] = 255
        mask[..., 3] = icon[..., 3]
        Image.fromarray(mask).save(os.path.join(OUT, "Hud" + n + "Mask.png"))
        tiles.append((Image.fromarray(icon), outline(icon, px)))
    sheet = Image.new("RGBA", (276 * len(tiles), 552), (120, 200, 90, 255))
    for i, (bare, done) in enumerate(tiles):
        sheet.alpha_composite(bare, (276 * i + 10, 10))
        sheet.alpha_composite(done, (276 * i + 10, 286))
    sheet.save(os.path.join(OUT, "preview.png"))
    print("wrote", ", ".join(names), "to", OUT)


if __name__ == "__main__":
    main()
