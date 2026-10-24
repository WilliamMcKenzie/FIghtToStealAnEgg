"""Builds the map editor (QM, Oct 24) into one self-contained page: editor.html with the
game's colours (Config.WorldColors), the sprites (sprites.py) and maps/world.map baked in.

Run: python3 tools/mapeditor/build.py     -> tools/mapeditor/MapEditor.html
     (open it in a browser; it also goes up as an Artifact page)
"""

import base64
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")


def data_url(path):
    return "data:image/png;base64," + base64.b64encode(open(path, "rb").read()).decode()


def main():
    meta = json.load(open(os.path.join(HERE, "sprites", "sprites.json")))
    config = open(os.path.join(ROOT, "src", "shared", "Config.luau")).read()
    world = config[config.index("WorldColors = {"):]
    world = world[:world.index("\n\t},")]
    world_keys = sorted(re.findall(r"(\w+) = Color3\.fromRGB", world))
    keys = [k for k in world_keys if not k.endswith("Checker")]
    sprites = {}
    for name, (x0, z0, x1, z1, ks) in meta["sprites"].items():
        sprites[name] = [x0, z0, x1, z1, ks, data_url(os.path.join(HERE, "sprites", name + "_shade.png")),
                         data_url(os.path.join(HERE, "sprites", name + "_id.png"))]
    items = sorted({n.split("_")[0] for n in meta["sprites"] if not n.split("_")[0] in ("Pillar", "Arch", "Nest", "Boss")})
    stud = float(re.search(r"StudTransparency = ([\d.]+)", config).group(1))
    world_map = json.load(open(os.path.join(ROOT, "maps", "world.map")))
    pillars = sorted({(o["kind"], o["size"], o["height"]) for o in world_map["objects"] if o["type"] == "Pillar"},
                     key=lambda p: ("joint", "corner", "transition", "gate", "rubble").index(p[0]) if p[0] in ("joint", "corner", "transition", "gate", "rubble") else 9)
    bundle = {
        "pillars": [list(p) for p in pillars],
        "colours": meta["colours"],
        "keys": keys,
        "world": world_keys,
        "sprites": sprites,
        "items": items,
        "styles": ["Base", "Meadow", "Desert", "Ice", "Lava", "Dungeon", "Castle", "Forest", "Ocean"],
        "studTransparency": stud,
        "map": open(os.path.join(ROOT, "maps", "world.map")).read(),
    }
    page = open(os.path.join(HERE, "editor.html")).read()
    blob = json.dumps(bundle, separators=(",", ":")).replace("</", "<\\/")
    page = page.replace("/*BUNDLE*/null", blob)
    out = os.path.join(HERE, "MapEditor.html")
    open(out, "w").write(page)
    print("wrote", os.path.relpath(out, ROOT), "(%d KB)" % (len(page) // 1024))


if __name__ == "__main__":
    main()
