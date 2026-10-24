"""Top-down sprites for the map editor (QM, Oct 24: meshes rendered from straight above so
the editor looks like the game's top view): every prop in each style, the fixed pillars
and arches, nests and the sleeping bosses, built as tools/render3d.py builds them and
drawn with three.js (orthographic, looking down, north up) in headless Chromium.

Run: python3 tools/mapeditor/sprites.py
     writes tools/mapeditor/sprites/: for each sprite NAME_shade.png (lit, every surface
     white) and NAME_id.png (which colour key each pixel is: red = 8 x (its index + 1)),
     so the editor can paint them in any colours (QM, Oct 24: tweak colours globally);
     and sprites.json ({ name: [x0, z0, x1, z1, [keys]] }, the picture's extent in studs
     from the object's origin). Needs what render3d needs.
"""

import json
import os
import subprocess
import sys
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import map_gen as M  # noqa: E402
import render3d as R  # noqa: E402

OUT = os.path.join(HERE, "sprites")
PX = 8  # pixels a stud
MAX_PX = 640
STYLES = ["Base"] + [b["name"] for b in M.BIOMES] + ["Dungeon", "Castle", "Forest", "Ocean"]  # (past the Lava: tools/map_fork.py)
NEW_DECOR = ["Torch", "WallTorch", "Shackles", "HumanSkull", "Candelabra", "Candles", "CandlePodium", "ForestCandle",
             "PalmTree", "PalmTreeSmall", "Kelp", "Starfish", "Sponges", "Coral"]


def sprites():
    """(name, scene) for everything the editor draws from a picture."""
    out = []
    items = sorted({it for d in M.DRESSING.values() for it, _ in d["top"] + d["floor"]} | {d["ring"] for d in M.DRESSING.values()} | {"PineTall", "PineShort", "Femur", "Ribcage", "Skull"} | set(NEW_DECOR))
    for it in items:
        stony = any(R.prop_key(it, p["colour"], "Meadow") != p["colour"] for p in R.PIECES[it])
        for st in STYLES if stony else ["Base"]:
            sc = R.Scene()
            R.prop(sc, it, 0, 0, 0, 0, 1, st)
            out.append(("%s_%s" % (it, st) if stony else it, sc))
    _, _, pillars, arches, _ = M.walls_and_pillars()
    # (every style of each pillar: they're objects in the editor, any style can go anywhere)
    for size, height, kind in sorted({(p[3], p[4], p[5]) for p in pillars}):
        for st in STYLES:
            sc = R.Scene()
            R.pillar(sc, np.random.default_rng(int(size) * 7 + len(st)), st, 0, 0, size, height, kind)
            out.append(("Pillar_%s_%s_%g" % (st, kind, size), sc))
    for st in STYLES:
        sc = R.Scene()
        R.arch(sc, np.random.default_rng(3), st, 0, 0)
        out.append(("Arch_%s" % st, sc))
    bosses = R.boss_settings()
    extra = {}
    for b in M.BIOMES:
        sc = R.Scene()
        R.nest(sc, np.random.default_rng(5), 0, 0, "Egg" + b["name"])
        out.append(("Nest_%s" % b["name"], sc))
        sc = R.Scene()
        model, size = bosses[b["name"]]
        R.animal(sc, model, np.zeros(3), size, 0, extra)
        out.append(("Boss_%s" % b["name"], sc))
    return out, extra


JS = r"""
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const [jobPath, outDir, threePath] = process.argv.slice(2);
(async () => {
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage();
  page.on('pageerror', e => console.log('page error:', e.message));
  await page.setContent('<html><body></body></html>');
  await page.addScriptTag({ content: 'var module = { exports: {} }; var exports = module.exports;\n' + fs.readFileSync(threePath, 'utf8') + '\nwindow.THREE = module.exports;' });
  const job = JSON.parse(fs.readFileSync(jobPath, 'utf8'));
  await page.evaluate(() => {
    const T = window.THREE;
    // (two: the shading is antialiased, the key ids must not be blended)
    window.shadeR = new T.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
    window.idR = new T.WebGLRenderer({ antialias: false, alpha: true, preserveDrawingBuffer: true });
    for (const r of [shadeR, idR]) { r.setClearColor(0x000000, 0); r.outputColorSpace = T.SRGBColorSpace; }
    idR.outputColorSpace = T.LinearSRGBColorSpace;
  });
  for (const s of job.sprites) {
    const urls = await page.evaluate((s) => {
      const T = window.THREE;
      const out = [];
      for (const pass of ['shade', 'id']) {
        const scene = new T.Scene();
        // (Roblox at noon, shadows off: a top face comes out about its own colour)
        scene.add(new T.AmbientLight(0xffffff, 0.42 * Math.PI));
        const sun = new T.DirectionalLight(0xffffff, 0.7 * Math.PI);
        sun.position.set(-0.35, 1, -0.45); scene.add(sun);
        for (const g of s.groups) {
          const geo = new T.BufferGeometry();
          geo.setAttribute('position', new T.Float32BufferAttribute(g.pos, 3));
          geo.setAttribute('normal', new T.Float32BufferAttribute(g.nrm, 3));
          const k = s.keys.indexOf(g.key) + 1;
          const mat = pass === 'id' ? new T.MeshBasicMaterial({ color: new T.Color(k * 8 / 255, 0, 0), side: T.DoubleSide })
            : g.mode === 'glow' ? new T.MeshBasicMaterial({ color: 0xffffff })
            : new T.MeshLambertMaterial({ color: 0xffffff, flatShading: true, side: T.DoubleSide });
          scene.add(new T.Mesh(geo, mat));
        }
        const [x0, z0, x1, z1] = s.bounds;
        const cam = new T.OrthographicCamera(x0, x1, -z0, -z1, 0.1, 1000);
        cam.position.set(0, 500, 0); cam.up.set(0, 0, -1); cam.lookAt(0, 0, 0);
        const r = pass === 'id' ? idR : shadeR;
        r.setSize(s.w, s.h);
        r.render(scene, cam);
        out.push(r.domElement.toDataURL('image/png'));
      }
      return out;
    }, s);
    fs.writeFileSync(path.join(outDir, s.name + '_shade.png'), Buffer.from(urls[0].split(',')[1], 'base64'));
    fs.writeFileSync(path.join(outDir, s.name + '_id.png'), Buffer.from(urls[1].split(',')[1], 'base64'));
  }
  await browser.close();
})();
"""


def main():
    os.makedirs(OUT, exist_ok=True)
    items, extra = sprites()
    cols = R.colours()
    cols.update(extra)
    job, meta = [], {}
    for name, sc in items:
        groups = sc.export()
        P = np.concatenate([np.array(g["pos"]).reshape(-1, 3) for g in groups])
        x0, z0 = P[:, 0].min() - 0.5, P[:, 2].min() - 0.5
        x1, z1 = P[:, 0].max() + 0.5, P[:, 2].max() + 0.5
        px = min(PX, MAX_PX / max(x1 - x0, z1 - z0))
        w, h = int(round((x1 - x0) * px)), int(round((z1 - z0) * px))
        keys = sorted({g["key"] for g in groups})
        assert len(keys) < 31, name
        job.append({"name": name, "groups": groups, "keys": keys, "bounds": [x0, z0, x1, z1], "w": w, "h": h})
        meta[name] = [round(float(v), 2) for v in (x0, z0, x1, z1)] + [keys]
    tmp = tempfile.mkdtemp()
    jp = os.path.join(tmp, "job.json")
    json.dump({"sprites": job}, open(jp, "w"))
    for f in os.listdir(OUT):
        os.remove(os.path.join(OUT, f))
    js = os.path.join(tmp, "sprites.js")
    open(js, "w").write(JS)
    env = dict(os.environ)
    env["NODE_PATH"] = os.pathsep.join(filter(None, [subprocess.run(["npm", "root", "-g"], capture_output=True, text=True).stdout.strip(), env.get("NODE_PATH", "")]))
    subprocess.run(["node", js, jp, OUT, R.find_three()], check=True, env=env)
    json.dump({"sprites": meta, "colours": cols}, open(os.path.join(OUT, "sprites.json"), "w"), indent=1)
    print("wrote", len(meta), "sprites to", os.path.relpath(OUT))


if __name__ == "__main__":
    main()
