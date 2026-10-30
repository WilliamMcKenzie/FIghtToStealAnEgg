"""A lineup of weapon designs, to look over before they go in the game (QM, Oct 30).

Run: python3 tools/weapon_lineup.py OUT.png [Name ...]
     draws tools/weapon_designs.py's designs (all by default) upright, flat and outlined
     like the icons, side by side with their names, rarities and the weapon each replaces.
"""

import json
import math
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import render_weapon_icons as icons  # noqa: E402
from render3d import find_three  # noqa: E402
from weapon_designs import DESIGNS  # noqa: E402

CELL = 300
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
RARITY = {"Celestial": (120, 220, 255), "Cosmic": (220, 120, 255), "Void": (150, 110, 255), "Omega": (190, 255, 120)}


def parts(model):
    out = []
    for cls, size, pos, a, color, _ in model.parts:
        c, s = math.cos(a), math.sin(a)
        out.append({"class": cls, "mesh": None, "size": list(size),
                    "cframe": [pos[0], pos[1], pos[2], c, -s, 0, s, c, 0, 0, 0, 1],
                    "color": [int(color[i:i + 2], 16) for i in (0, 2, 4)]})
    return out


def main():
    out_path = sys.argv[1]
    names = sys.argv[2:] or list(DESIGNS)
    tmp = tempfile.mkdtemp()
    weapons = [{"id": n, "parts": parts(DESIGNS[n][0]())} for n in names]
    data = os.path.join(tmp, "w.json")
    json.dump({"weapons": weapons, "draw": 1024, "tilt": 0, "turn": 0.25}, open(data, "w"))
    js = os.path.join(tmp, "render.js")
    open(js, "w").write(icons.RENDER_JS)
    env = dict(os.environ)
    env["NODE_PATH"] = os.pathsep.join(filter(None, [os.path.join(HERE, "node_modules"), subprocess.run(["npm", "root", "-g"], capture_output=True, text=True).stdout.strip()]))
    subprocess.run(["node", js, data, tmp, find_three()], check=True, env=env)
    icons.SIZE = 1024
    cols = 5
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGBA", (CELL * cols, (CELL + 70) * rows), (34, 36, 48, 255))
    draw = ImageDraw.Draw(sheet)
    big, small = ImageFont.truetype(FONT, 22), ImageFont.truetype(FONT, 16)
    for i, n in enumerate(names):
        icons.outline(os.path.join(tmp, n + ".png"), os.path.join(tmp, n + "_o.png"))
        im = Image.open(os.path.join(tmp, n + "_o.png")).resize((CELL - 20, CELL - 20), Image.LANCZOS)
        x, y = CELL * (i % cols), (CELL + 70) * (i // cols)
        sheet.alpha_composite(im, (x + 10, y + 10))
        rarity, kind = DESIGNS[n][1].split(" ", 1)
        label = {"SunBlade": "Sun Blade", "StarlightBow": "Starlight Bow", "NebulaStaff": "Nebula Staff",
                 "CometLance": "Comet Lance", "GalaxyBow": "Galaxy Bow", "VoidReaver": "Void Reaver",
                 "AbyssStaff": "Abyss Staff", "EclipseBow": "Eclipse Bow", "Worldbreaker": "Worldbreaker",
                 "GenesisStaff": "Genesis Staff"}.get(n, n)
        draw.text((x + CELL / 2, y + CELL + 8), label, font=big, fill=(255, 255, 255), anchor="mt", stroke_width=2, stroke_fill=(0, 0, 0))
        draw.text((x + CELL / 2, y + CELL + 38), f"{rarity} {kind}", font=small, fill=RARITY.get(rarity, (200, 200, 200)), anchor="mt", stroke_width=2, stroke_fill=(0, 0, 0))
    sheet.save(out_path)
    print("wrote", out_path)


if __name__ == "__main__":
    main()
