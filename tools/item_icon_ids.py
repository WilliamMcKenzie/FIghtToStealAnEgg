# Writes src/shared/ItemIcons.luau from the uploaded icons' ids (assets/weapons/icons/ids.json,
# assets/eggs/icons/ids.json and assets/pets/icons/ids.json, written by tools/studio/imgup.py). Run after uploading.
import json, os
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def ids(path):
    p = os.path.join(ROOT, path)
    return json.load(open(p)) if os.path.exists(p) else {}


out = [
    "-- Every weapon's, egg's and pet's icon (rendered by tools/render_weapon_icons.py and",
    "-- tools/render_pet_icons.py at 128px, QM Oct 27: all UI pictures of weapons and eggs are",
    "-- these renders). Written by tools/item_icon_ids.py from the uploads' ids.json; don't edit.",
    "-- [id or kind] = \"rbxassetid://...\"",
    "return {",
]
for name, path in (
    ("Weapons", "assets/weapons/icons/ids.json"),
    ("Eggs", "assets/eggs/icons/ids.json"),
    ("Pets", "assets/pets/icons/ids.json"),
):
    out.append("\t%s = {" % name)
    for k, v in sorted(ids(path).items()):
        out.append('\t\t%s = "%s",' % (k, v))
    out.append("\t},")
out.append("}")
open(os.path.join(ROOT, "src", "shared", "ItemIcons.luau"), "w").write("\n".join(out) + "\n")
print("wrote src/shared/ItemIcons.luau")
