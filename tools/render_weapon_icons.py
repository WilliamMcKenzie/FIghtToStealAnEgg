"""Weapon icons (QM, Oct 25: render each weapon once to a PNG with a black outline, as the
eggs and pets were in Lasso A Pet, instead of a live 3D view in the spin and the chip).
Each weapon's model (src/shared/Weapons/<Name>Model.luau, the one Weapons.luau's DRAWN
lists for it) is drawn flat, unlit like the held ones, tilted as the spin shows it, with
three.js in headless Chromium, then given a thick black outline.

Run: python3 tools/render_weapon_icons.py
     writes assets/weapons/icons/<Id>.png (512 x 512, transparent).

Upload them (on the Mac, through Studio):
  cd tools/studio && OUT=../../assets/weapons/icons/ids.json python3 imgup.py ../../assets/weapons/icons/*.png
then copy the ids into src/shared/Weapons/WeaponIcons.luau (client/WeaponSpin shows an
icon where there is one, the live model where there isn't).

Needs node with `playwright` (Chromium) and `three` (as tools/render3d.py), and Pillow.
"""

import json
import math
import os
import re
import subprocess
import sys
import tempfile

from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, HERE)
from render3d import find_three  # noqa: E402
from render_sleep import entries, nums, table_at  # noqa: E402

OUT = os.path.join(ROOT, "assets", "weapons", "icons")
SIZE = 512  # the icon, px
DRAW = 1024  # rendered at this, then shrunk (smooth edges)
OUTLINE = 22  # px of black round it, at DRAW size
TILT = -40  # degrees round Z, as client/WeaponSpin tilts the live one
TURN = 0.3  # radians round Y, so it isn't dead flat on


def drawn():
    """{ weapon id: model module name } from Weapons.luau's DRAWN table."""
    src = open(os.path.join(ROOT, "src", "shared", "Weapons", "Weapons.luau")).read()
    table = table_at(src, src.index("{", src.index("local DRAWN = {")))
    return dict(re.findall(r"\n\t(\w+) = (?:centred\()?(\w+)Model\b", table))


def mesh_obj(name):
    """An assets/meshes .obj as flat triangles in a unit box (a MeshPart stretches its mesh
    to its Size)."""
    path = os.path.join(ROOT, "assets", "meshes", name.split("_")[0], name + ".obj")
    V, tris = [], []
    for line in open(path):
        t = line.split()
        if t and t[0] == "v":
            V.append([float(x) for x in t[1:4]])
        elif t and t[0] == "f":
            ids = [int(x.split("/")[0]) - 1 for x in t[1:]]
            for k in range(1, len(ids) - 1):
                tris.append((ids[0], ids[k], ids[k + 1]))
    lo = [min(v[i] for v in V) for i in range(3)]
    hi = [max(v[i] for v in V) for i in range(3)]
    unit = [[(v[i] - (lo[i] + hi[i]) / 2) / max(hi[i] - lo[i], 1e-6) for i in range(3)] for v in V]
    return [round(x, 4) for tri in tris for idx in tri for x in unit[idx]]


def parts(module):
    src = open(os.path.join(ROOT, "src", "shared", "Weapons", module + "Model.luau")).read()
    field = lambda e, key: re.search(r"\b" + key + r' = "([^"]+)"', e)
    out = []
    for e in entries(table_at(src, src.index("{", src.index("parts = {")))):
        mesh = field(e, "mesh")
        out.append({
            "class": (field(e, "class") or [None, "Part"])[1],
            "mesh": mesh_obj(mesh.group(1)) if mesh else None,
            "size": nums(re.search(r"size = Vector3\.new\(([^)]*)\)", e).group(1)),
            "cframe": nums(re.search(r"cframe = CFrame\.new\((.*?)\)", e, re.S).group(1)),
            "color": nums(re.search(r"color = Color3\.fromRGB\(([^)]*)\)", e).group(1)),
        })
    return out


RENDER_JS = r"""
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const [dataPath, outDir, threePath] = process.argv.slice(2);
(async () => {
  const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
  const W = data.draw;
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: W, height: W } });
  page.on('pageerror', e => console.log('page error:', e.message));
  await page.setContent('<html><body style="margin:0;background:transparent"></body></html>');
  await page.addScriptTag({ content: 'var module = { exports: {} }; var exports = module.exports;\n' + fs.readFileSync(threePath, 'utf8') + '\nwindow.THREE = module.exports;' });
  await page.evaluate(([W]) => {
    const T = window.THREE;
    const renderer = new T.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
    renderer.setSize(W, W);
    renderer.setClearColor(0x000000, 0);
    renderer.outputColorSpace = T.SRGBColorSpace;
    document.body.appendChild(renderer.domElement);
    window.R = renderer;
  }, [W]);
  for (const w of data.weapons) {
    const png = await page.evaluate(([w, tilt, turn, pitch]) => {
      const T = window.THREE;
      const scene = new T.Scene();
      const rgb = (c) => new T.Color().setRGB(c[0] / 255, c[1] / 255, c[2] / 255, T.SRGBColorSpace);
      const tri = (pts) => { const g = new T.BufferGeometry(); g.setAttribute('position', new T.Float32BufferAttribute(pts.flat(), 3)); return g; };
      const faces = (V, F) => tri(F.flatMap(f => { const out = []; for (let k = 1; k < f.length - 1; k++) out.push(V[f[0]], V[f[k]], V[f[k + 1]]); return out; }));
      const h = 0.5;
      // Roblox's wedges in a unit box (as tools/render_sleep.py)
      const WEDGE = faces([[-h, -h, -h], [h, -h, -h], [h, -h, h], [-h, -h, h], [-h, h, h], [h, h, h]],
        [[0, 1, 2, 3], [3, 2, 5, 4], [0, 4, 5, 1], [0, 3, 4], [1, 5, 2]]);
      const CORNER = faces([[-h, -h, -h], [h, -h, -h], [h, -h, h], [-h, -h, h], [h, h, -h]],
        [[0, 1, 2, 3], [0, 4, 1], [1, 4, 2], [2, 4, 3], [3, 4, 0]]);
      const group = new T.Group();
      for (const p of w.parts) {
        const g = p.mesh ? (() => { const g = new T.BufferGeometry(); g.setAttribute('position', new T.Float32BufferAttribute(p.mesh, 3)); return g; })()
          : p.class === 'WedgePart' ? WEDGE : p.class === 'CornerWedgePart' ? CORNER : new T.BoxGeometry(1, 1, 1);
        // (flat, unlit: each colour as it is, like the held weapons)
        const mesh = new T.Mesh(g, new T.MeshBasicMaterial({ color: rgb(p.color), side: T.DoubleSide }));
        const c = p.cframe, m = new T.Matrix4();
        if (c.length === 12) m.set(c[3], c[4], c[5], c[0], c[6], c[7], c[8], c[1], c[9], c[10], c[11], c[2], 0, 0, 0, 1);
        else m.makeTranslation(c[0], c[1], c[2]);
        m.multiply(new T.Matrix4().makeScale(p.size[0], p.size[1], p.size[2]));
        mesh.matrixAutoUpdate = false; mesh.matrix.copy(m);
        group.add(mesh);
      }
      // centred on its box, tilted as the spin shows it
      group.updateMatrixWorld(true);
      const box = new T.Box3().setFromObject(group);
      const centre = box.getCenter(new T.Vector3());
      const holder = new T.Group();
      group.position.sub(centre);
      holder.add(group);
      holder.rotation.set(0, 0, tilt * Math.PI / 180);
      // (turned round Y, then tipped toward the camera by pitch: a pet seen from above)
      const spin = new T.Group(); spin.add(holder); spin.rotation.set(pitch, turn, 0);
      scene.add(spin);
      scene.updateMatrixWorld(true);
      const b = new T.Box3().setFromObject(spin);
      const half = Math.max(b.max.x - b.min.x, b.max.y - b.min.y) / 2 * 1.12;
      const cx = (b.max.x + b.min.x) / 2, cy = (b.max.y + b.min.y) / 2;
      const cam = new T.OrthographicCamera(cx - half, cx + half, cy + half, cy - half, -100, 100);
      cam.position.set(0, 0, 50); cam.lookAt(0, 0, 0);
      window.R.render(scene, cam);
      return window.R.domElement.toDataURL('image/png');
    }, [w, w.tilt ?? data.tilt, w.turn ?? data.turn, w.pitch ?? 0]);
    fs.writeFileSync(path.join(outDir, w.id + '.png'), Buffer.from(png.split(',')[1], 'base64'));
    console.log('drew', w.id);
  }
  await browser.close();
})();
"""


def outline(path, out_path):
    im = Image.open(path).convert("RGBA")
    a = im.getchannel("A")
    # round, thick: grow the silhouette OUTLINE px (MaxFilter takes odd sizes), then soften
    grown = a
    step = 9
    for _ in range(OUTLINE // (step // 2)):
        grown = grown.filter(ImageFilter.MaxFilter(step))
    grown = grown.filter(ImageFilter.GaussianBlur(1.2)).point(lambda v: 255 if v > 128 else int(v * 2))
    back = Image.new("RGBA", im.size, (0, 0, 0, 0))
    back.putalpha(grown)
    back.alpha_composite(im)
    back.resize((SIZE, SIZE), Image.LANCZOS).save(out_path)


def main():
    os.makedirs(OUT, exist_ok=True)
    weapons = [{"id": wid, "parts": parts(module)} for wid, module in sorted(drawn().items())]
    tmp = tempfile.mkdtemp()
    data_path = os.path.join(tmp, "weapons.json")
    json.dump({"weapons": weapons, "draw": DRAW, "tilt": TILT, "turn": TURN}, open(data_path, "w"))
    js = os.path.join(tmp, "render.js")
    open(js, "w").write(RENDER_JS)
    env = dict(os.environ)
    env["NODE_PATH"] = os.pathsep.join(filter(None, [subprocess.run(["npm", "root", "-g"], capture_output=True, text=True).stdout.strip(), env.get("NODE_PATH", "")]))
    subprocess.run(["node", js, data_path, tmp, find_three()], check=True, env=env)
    for w in weapons:
        outline(os.path.join(tmp, w["id"] + ".png"), os.path.join(OUT, w["id"] + ".png"))
        print("wrote", os.path.relpath(os.path.join(OUT, w["id"] + ".png"), ROOT))


if __name__ == "__main__":
    main()
