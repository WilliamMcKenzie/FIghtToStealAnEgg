"""A boss from tools/boss_designs.py, drawn without Studio: three.js in headless Chromium
(as tools/render_sleep.py), its rig posed exactly as Rig/Horse pose it.

Run: python3 tools/render_boss.py Thornback [more names] [--out DIR]
     writes previews/bosses/<name>.gif (idle, walk, then each attack, labelled) and
     previews/bosses/<name>.png (a still of it at rest, then each attack at its hit).

Needs node with `playwright` (Chromium) and `three` (npm i three@0.160.0 in tools/), and ffmpeg.
"""

import json
import math
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, HERE)
from render3d import find_three  # noqa: E402
from boss_forge import rot  # noqa: E402

FPS = 15


def catmull(p0, p1, p2, p3, u):
    return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u)


def sample(keys, t, smooth=True):
    """Rig.sample."""
    n = len(keys)
    if t <= keys[0][0]:
        return keys[0][1:]
    if t >= keys[-1][0]:
        return keys[-1][1:]
    i = 0
    while keys[i + 1][0] < t:
        i += 1
    a, b = keys[i], keys[i + 1]
    u = (t - a[0]) / (b[0] - a[0])
    if not smooth:
        return tuple(a[j] + (b[j] - a[j]) * u for j in (1, 2, 3))
    k0, k3 = keys[max(i - 1, 0)], keys[min(i + 2, n - 1)]
    return tuple(catmull(k0[j], a[j], b[j], k3[j], u) for j in (1, 2, 3))


def pose_at(model, name, t):
    pose = {}
    for bone, tr in model.anims[name]["tracks"].items():
        p = [0.0] * 6
        if "p" in tr:
            p[0:3] = sample(tr["p"], t, "p" not in tr.get("linear", ()))
        if "r" in tr:
            p[3:6] = [math.radians(v) for v in sample(tr["r"], t, "r" not in tr.get("linear", ()))]
        pose[bone] = p
    return pose


def mix(a, b, w):
    out = {}
    for bone in set(a) | set(b):
        pa, pb = a.get(bone, [0] * 6), b.get(bone, [0] * 6)
        out[bone] = [pa[i] * (1 - w) + pb[i] * w for i in range(6)]
    return out


def scene_data(model):
    rests = getattr(model, "rests", {})
    bones = [{"name": n, "parent": p, "pivot": list(v), "rest": list(rests.get(n, (0, 0, 0)))} for n, p, v in model.bones]
    parts = []
    for p in model.parts:
        R = rot(*p["r"])
        parts.append({"name": p["name"], "bone": p["bone"], "class": p["class"], "size": list(p["size"]),
                      "cframe": p.get("cf") or list(p["at"]) + [R[i][j] for i in range(3) for j in range(3)],
                      "color": list(p["color"]), "neon": p["neon"]})
    return bones, parts


def framing(parts):
    lo = [min(p["cframe"][i] - max(p["size"]) / 2 for p in parts) for i in range(3)]
    hi = [max(p["cframe"][i] + max(p["size"]) / 2 for p in parts) for i in range(3)]
    at = [(lo[i] + hi[i]) / 2 for i in range(3)]
    at[1] = lo[1] + (hi[1] - lo[1]) * 0.5
    r = math.dist(lo, hi) / 2
    d = [float(v) for v in os.environ.get("BOSS_VIEW", "0.5,0.42,-0.76").split(",")]
    k = r * 3.3 / math.hypot(*d)
    return [at[i] + d[i] * k for i in range(3)], at, r


def frames(model, view):
    eye, at, _ = view
    out = []

    def add(pose, label, shake=0.0):
        out.append({"pose": pose, "label": label, "eye": eye, "at": at, "telegraph": shake})

    idle = model.anims["idle"]
    for i in range(int(idle["length"] * FPS)):
        add(pose_at(model, "idle", i / FPS), "idle")
    walk = model.anims["walk"]
    for _ in range(2):
        for i in range(int(walk["length"] * FPS)):
            add(pose_at(model, "walk", i / FPS), "walk")
    for name, a in model.anims.items():
        if name in ("idle", "walk", "gallop"):
            continue
        # fades in over idle and back out, as Horse:playOnce
        n = int(a["length"] * FPS)
        for i in range(n + 6):
            t = min(i / FPS, a["length"])
            w = min(1, t / 0.15, max(0, (a["length"] - t) / 0.3))
            add(mix(pose_at(model, "idle", (i / FPS) % idle["length"]), pose_at(model, name, t), w), name)
        for i in range(4):
            add(pose_at(model, "idle", i / FPS), "idle")
    return out


def stills(model, view):
    eye, at, _ = view
    out = [{"name": "s0.png", "pose": {}, "label": model.name, "eye": eye, "at": at}]
    if getattr(model, "sleeping", None):
        sl = model.sleeping["bones"]
        out.append({"name": "s1.png", "pose": {b: list(v[:3]) + [math.radians(a) for a in v[3:]] for b, v in sl.items()},
                    "label": "asleep", "eye": eye, "at": at})
    for name, a in model.anims.items():
        if name in ("idle", "walk", "gallop"):
            continue
        hit = a["hit"] if a["hit"] is not None else a["length"] / 2
        out.append({"name": "s%d.png" % len(out), "pose": pose_at(model, name, max(0, hit - 0.12)), "label": name + " (windup)", "eye": eye, "at": at})
        out.append({"name": "s%d.png" % len(out), "pose": pose_at(model, name, hit), "label": name + " (hit)", "eye": eye, "at": at})
    return out


RENDER_JS = r"""
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const [dataPath, outDir, threePath] = process.argv.slice(2);
(async () => {
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const W = 560, H = 480;
  const page = await browser.newPage({ viewport: { width: W, height: H } });
  page.on('pageerror', e => console.log('page error:', e.message));
  await page.setContent('<html><body style="margin:0"></body></html>');
  await page.addScriptTag({ content: 'var module = { exports: {} }; var exports = module.exports;\n' + fs.readFileSync(threePath, 'utf8') + '\nwindow.THREE = module.exports;' });
  const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
  await page.evaluate(([data, W, H]) => {
    const T = window.THREE;
    const renderer = new T.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
    renderer.setSize(W, H);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = T.PCFSoftShadowMap;
    renderer.outputColorSpace = T.SRGBColorSpace;
    document.body.appendChild(renderer.domElement);
    const label = document.createElement('div');
    Object.assign(label.style, { position: 'absolute', left: '12px', top: '8px', font: '800 22px sans-serif', color: '#fff', textShadow: '0 0 3px #1b1f4a, 0 0 3px #1b1f4a, 0 0 3px #1b1f4a' });
    document.body.appendChild(label);
    const scene = new T.Scene();
    scene.background = new T.Color(0x9cc8ee);
    scene.add(new T.HemisphereLight(0xdcecff, 0x6a7a48, 1.4));
    const sun = new T.DirectionalLight(0xfff2dc, 2.0);
    const R = data.span * 1.6;
    sun.position.set(-R * 0.9, R * 2, -R * 1.2); sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    Object.assign(sun.shadow.camera, { left: -R, right: R, top: R, bottom: -R, near: 1, far: R * 6 });
    sun.shadow.bias = -0.0005;
    scene.add(sun);
    const rgb = (c) => new T.Color().setRGB(c[0] / 255, c[1] / 255, c[2] / 255, T.SRGBColorSpace);
    const cv = document.createElement('canvas'); cv.width = cv.height = 64;
    const g = cv.getContext('2d');
    for (let i = 0; i < 2; i++) for (let j = 0; j < 2; j++) { g.fillStyle = (i + j) % 2 ? '#6fbf4a' : '#7cc955'; g.fillRect(i * 32, j * 32, 32, 32); }
    const tex = new T.CanvasTexture(cv); tex.wrapS = tex.wrapT = T.RepeatWrapping; tex.repeat.set(data.span / 2, data.span / 2);
    tex.magFilter = T.NearestFilter; tex.colorSpace = T.SRGBColorSpace;
    const floor = new T.Mesh(new T.PlaneGeometry(data.span * 8, data.span * 8), new T.MeshLambertMaterial({ map: tex }));
    floor.rotation.x = -Math.PI / 2; floor.receiveShadow = true; scene.add(floor);
    const pivots = {}, parentOf = {}, order = [];
    const rests = {};
    for (const b of data.bones) { pivots[b.name] = new T.Vector3(...b.pivot); parentOf[b.name] = b.parent; rests[b.name] = b.rest; }
    const placed = new Set();
    while (order.length < data.bones.length) for (const b of data.bones) if (!placed.has(b.name) && (!b.parent || placed.has(b.parent))) { placed.add(b.name); order.push(b.name); }
    const tri = (pts) => { const g = new T.BufferGeometry(); g.setAttribute('position', new T.Float32BufferAttribute(pts.flat(), 3)); g.computeVertexNormals(); return g; };
    const faces = (V, F) => tri(F.flatMap(f => { const out = []; for (let k = 1; k < f.length - 1; k++) out.push(V[f[0]], V[f[k]], V[f[k + 1]]); return out; }));
    const h = 0.5;
    const WEDGE = faces([[-h, -h, -h], [h, -h, -h], [h, -h, h], [-h, -h, h], [-h, h, h], [h, h, h]],
      [[0, 1, 2, 3], [3, 2, 5, 4], [0, 4, 5, 1], [0, 3, 4], [1, 5, 2]]);
    const CORNER = faces([[-h, -h, -h], [h, -h, -h], [h, -h, h], [-h, -h, h], [h, h, -h]],
      [[0, 1, 2, 3], [0, 4, 1], [1, 4, 2], [2, 4, 3], [3, 4, 0]]);
    const geometry = (p) => p.class === 'WedgePart' ? WEDGE : p.class === 'CornerWedgePart' ? CORNER : new T.BoxGeometry(1, 1, 1);
    const meshes = [];
    for (const p of data.parts) {
      const mat = p.neon ? new T.MeshBasicMaterial({ color: rgb(p.color).multiplyScalar(1.4) }) : new T.MeshLambertMaterial({ color: rgb(p.color), flatShading: true, side: T.DoubleSide });
      const mesh = new T.Mesh(geometry(p), mat);
      mesh.castShadow = true; mesh.receiveShadow = true; mesh.matrixAutoUpdate = false;
      const c = p.cframe, local = new T.Matrix4();
      local.set(c[3], c[4], c[5], c[0], c[6], c[7], c[8], c[1], c[9], c[10], c[11], c[2], 0, 0, 0, 1);
      const pv = pivots[p.bone];
      local.premultiply(new T.Matrix4().makeTranslation(-pv.x, -pv.y, -pv.z));
      local.multiply(new T.Matrix4().makeScale(...p.size));
      scene.add(mesh);
      meshes.push({ p, mesh, local });
    }
    const xf = (v) => new T.Matrix4().makeTranslation(v[0], v[1], v[2]).multiply(new T.Matrix4().makeRotationFromEuler(new T.Euler(v[3], v[4], v[5], 'XYZ')));
    const cam = new T.PerspectiveCamera(32, W / H, 0.5, data.span * 40);
    window.frame = (f) => {
      const world = {};
      for (const name of order) {
        const par = parentOf[name], pp = par ? pivots[par] : new T.Vector3();
        const r = rests[name];
        const c0 = new T.Matrix4().makeTranslation(pivots[name].x - pp.x, pivots[name].y - pp.y, pivots[name].z - pp.z)
          .multiply(new T.Matrix4().makeRotationFromEuler(new T.Euler(r[0], r[1], r[2], 'XYZ')));
        world[name] = (par ? world[par].clone() : new T.Matrix4()).multiply(c0).multiply(xf(f.pose[name] || [0, 0, 0, 0, 0, 0]));
      }
      for (const m of meshes) m.mesh.matrix.copy(world[m.p.bone]).multiply(m.local);
      label.textContent = f.label || '';
      cam.position.set(...f.eye); cam.lookAt(...f.at);
      renderer.render(scene, cam);
    };
  }, [data, W, H]);
  let n = 0;
  for (const f of data.frames) {
    await page.evaluate((f) => window.frame(f), f);
    await page.screenshot({ path: path.join(outDir, f.name || ('f' + String(n++).padStart(4, '0') + '.png')) });
  }
  await browser.close();
})();
"""


def render(model, out_dirs, gif=True):
    bones, parts = scene_data(model)
    view = framing(parts)
    fs = (frames(model, view) if gif else []) + stills(model, view)
    tmp = tempfile.mkdtemp()
    data_path = os.path.join(tmp, "data.json")
    json.dump({"bones": bones, "parts": parts, "span": view[2], "frames": fs}, open(data_path, "w"))
    js = os.path.join(tmp, "render.js")
    open(js, "w").write(RENDER_JS)
    env = dict(os.environ)
    env["NODE_PATH"] = os.pathsep.join(filter(None, [subprocess.run(["npm", "root", "-g"], capture_output=True, text=True).stdout.strip(), env.get("NODE_PATH", "")]))
    subprocess.run(["node", js, data_path, tmp, find_three()], check=True, env=env)
    name = model.name.lower()
    png = os.path.join(tmp, name + ".png")
    shots = sorted((f for f in os.listdir(tmp) if f.startswith("s") and f.endswith(".png")), key=lambda f: int(f[1:-4]))
    cols = min(len(shots), 3)
    rows = math.ceil(len(shots) / cols)
    inputs = []
    for s in shots:
        inputs += ["-i", os.path.join(tmp, s)]
    # (pad to a full grid with blank tiles)
    pads = rows * cols - len(shots)
    layout = "|".join("%d_%d" % (560 * (i % cols), 480 * (i // cols)) for i in range(rows * cols))
    graph = "".join("[%d:v]" % i for i in range(len(shots)))
    if pads:
        graph = "color=c=0x9cc8ee:s=560x480:d=1[pad];[pad]split=%d%s;" % (pads, "".join("[p%d]" % i for i in range(pads))) + graph + "".join("[p%d]" % i for i in range(pads))
    graph += "xstack=inputs=%d:layout=%s" % (rows * cols, layout) if rows * cols > 1 else "null"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *inputs, "-filter_complex", graph, "-frames:v", "1", png], check=True)
    outs = [png]
    if gif:
        g = os.path.join(tmp, name + ".gif")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(tmp, "f%04d.png"),
                        "-vf", "scale=420:-1,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer", "-loop", "0", g], check=True)
        outs.append(g)
    for od in out_dirs:
        os.makedirs(od, exist_ok=True)
        for o in outs:
            shutil.copy(o, od)
    print("drew", ", ".join(os.path.basename(o) for o in outs))


def main():
    import boss_designs
    import boss_luau

    args = sys.argv[1:]
    out_dirs = [os.path.join(ROOT, "previews", "bosses")]
    if "--out" in args:
        i = args.index("--out")
        out_dirs.append(args[i + 1])
        del args[i:i + 2]
    gif = "--stills" not in args
    args = [a for a in args if a != "--stills"]
    made = {m.name: m for m in boss_designs.models()}
    for name in args or list(made):
        # (a model not made in Python, e.g. a Blockbench one: read back from its Model.luau)
        render(made.get(name) or boss_luau.load(name), out_dirs, gif)


if __name__ == "__main__":
    main()
