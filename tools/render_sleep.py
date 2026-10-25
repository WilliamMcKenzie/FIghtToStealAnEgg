"""A sleeping boss, without Studio (QM, Oct 25: see how it looks before the rest get one):
its Blockbench model (src/shared/Animals/<Model>Model.luau) posed the way
Client/BossView poses it from Config.BossSleep.Poses, drawn with three.js in headless
Chromium. Plays it awake, nodding off, two breaths asleep with its Zzz, and getting up.

Run: python3 tools/render_sleep.py [Model] [out_dir]
     writes previews/sleep_<model>.gif and previews/sleep_<model>.png (awake | asleep).

Needs node with `playwright` (Chromium) and `three` (as tools/render3d.py), and ffmpeg.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, HERE)
from render3d import find_three  # noqa: E402

NUM = r"-?[\d.]+(?:e-?\d+)?"


def nums(text):
    return [float(v) for v in re.findall(NUM, text)]


def model_data(model):
    src = open(os.path.join(ROOT, "src", "shared", "Animals", model + "Model.luau")).read()
    bones = []
    for m in re.finditer(r'\{ name = "(\w+)", parent = (?:"(\w+)"|nil), pivot = Vector3\.new\(([^)]*)\)', src):
        bones.append({"name": m.group(1), "parent": m.group(2), "pivot": nums(m.group(3))})
    parts = []
    body = src[src.index("parts = {"):src.index("animations = {")]
    for block in re.split(r"\n\t\t\{\n", body)[1:]:
        get = lambda key: re.search(key + r" = ([^\n]*?)(?:,\n|$)", block, re.S)
        cf = re.search(r"cframe = CFrame\.new\((.*?)\)", block, re.S).group(1)
        parts.append({
            "name": re.search(r'name = "(\w+)"', block).group(1),
            "bone": re.search(r'bone = "(\w+)"', block).group(1),
            "size": nums(re.search(r"size = Vector3\.new\(([^)]*)\)", block).group(1)),
            "cframe": nums(cf),
            "color": nums(re.search(r"color = Color3\.fromRGB\(([^)]*)\)", block).group(1)),
            "plain": get("plain") is not None,
        })
    return bones, parts


def table_at(src, start):
    """The text of the { ... } that opens at src[start]."""
    depth = 0
    for i in range(start, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return src[start:i + 1]
    raise ValueError("unbalanced")


def sleep_settings(model):
    src = open(os.path.join(ROOT, "src", "shared", "Config.luau")).read()
    sleep = table_at(src, src.index("{", src.index("BossSleep = {")))
    pose = table_at(sleep, sleep.index("{", sleep.index("\t\t\t" + model + " = {")))

    def bones(key):
        t = table_at(pose, pose.index("{", pose.index(key + " = {")))
        return {m.group(1): nums(m.group(2)) for m in re.finditer(r"(\w+) = \{([^}]*)\}", t[1:])}

    def names(key):
        return re.findall(r'"(\w+)"', table_at(pose, pose.index("{", pose.index(key + " = {"))))

    zzz = table_at(sleep, sleep.index("{", sleep.index("\t\tZzz = {")))
    num = lambda text, key: float(re.search(key + r" = (" + NUM + ")", text).group(1))
    return {
        "bones": bones("Bones"), "breathe": bones("Breathe"), "shut": names("Shut"), "hide": names("Hide"),
        "zzzAt": nums(re.search(r"Zzz = Vector3\.new\(([^)]*)\)", pose).group(1)),
        "breath": num(sleep, "Breath"), "settle": num(sleep, "Settle"),
        "zzz": {k: num(zzz, k) for k in ("Count", "Gap", "Size", "Rise", "Life")},
    }


RENDER_JS = r"""
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const [dataPath, outDir, threePath] = process.argv.slice(2);
(async () => {
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const W = 720, H = 560;
  const page = await browser.newPage({ viewport: { width: W, height: H } });
  page.on('console', m => console.log('page:', m.text()));
  page.on('pageerror', e => console.log('page error:', e.message));
  await page.setContent('<html><body style="margin:0"></body></html>');
  await page.addScriptTag({ content: 'var module = { exports: {} }; var exports = module.exports;\n' + fs.readFileSync(threePath, 'utf8') + '\nwindow.THREE = module.exports;' });
  await page.addStyleTag({ url: 'https://fonts.googleapis.com/css2?family=Montserrat:wght@800&display=block' }).catch(() => {});
  await page.evaluate(() => document.fonts.load('800 64px Montserrat').catch(() => {}));
  const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
  await page.evaluate(([data, W, H]) => {
    const T = window.THREE;
    const renderer = new T.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
    renderer.setSize(W, H);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = T.PCFSoftShadowMap;
    renderer.outputColorSpace = T.SRGBColorSpace;
    document.body.appendChild(renderer.domElement);
    const scene = new T.Scene();
    scene.background = new T.Color(0x9cc8ee);
    scene.add(new T.HemisphereLight(0xdcecff, 0x6a7a48, 1.4));
    const sun = new T.DirectionalLight(0xfff2dc, 2.0);
    sun.position.set(-14, 30, -18); sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    Object.assign(sun.shadow.camera, { left: -15, right: 15, top: 15, bottom: -15, near: 1, far: 80 });
    sun.shadow.bias = -0.0005;
    scene.add(sun);
    const rgb = (c) => new T.Color().setRGB(c[0] / 255, c[1] / 255, c[2] / 255, T.SRGBColorSpace);
    // the Meadow's checkered grass under it
    const cv = document.createElement('canvas'); cv.width = cv.height = 64;
    const g = cv.getContext('2d');
    for (let i = 0; i < 2; i++) for (let j = 0; j < 2; j++) { g.fillStyle = (i + j) % 2 ? '#6fbf4a' : '#7cc955'; g.fillRect(i * 32, j * 32, 32, 32); }
    const tex = new T.CanvasTexture(cv); tex.wrapS = tex.wrapT = T.RepeatWrapping; tex.repeat.set(10, 10);
    tex.magFilter = T.NearestFilter; tex.colorSpace = T.SRGBColorSpace;
    const floor = new T.Mesh(new T.PlaneGeometry(80, 80), new T.MeshLambertMaterial({ map: tex }));
    floor.rotation.x = -Math.PI / 2; floor.receiveShadow = true; scene.add(floor);

    // the rig, as Shared/Rig builds it: each bone hangs off its parent at its pivot
    // (C0 = pivot - parent pivot) and Motor6D.Transform turns it there; each part sits
    // at its cframe from its bone's pivot
    const pivots = {}, parentOf = {}, order = [];
    for (const b of data.bones) { pivots[b.name] = new T.Vector3(...b.pivot); parentOf[b.name] = b.parent; order.push(b.name); }
    const meshes = [];
    for (const p of data.parts) {
      const mat = new T.MeshLambertMaterial({ color: rgb(p.color) });
      const mesh = new T.Mesh(new T.BoxGeometry(1, 1, 1), mat);
      mesh.castShadow = true; mesh.receiveShadow = true; mesh.matrixAutoUpdate = false;
      const c = p.cframe, local = new T.Matrix4();
      if (c.length === 12) local.set(c[3], c[4], c[5], c[0], c[6], c[7], c[8], c[1], c[9], c[10], c[11], c[2], 0, 0, 0, 1);
      else local.makeTranslation(c[0], c[1], c[2]);
      const pv = pivots[p.bone];
      local.premultiply(new T.Matrix4().makeTranslation(-pv.x, -pv.y, -pv.z));
      scene.add(mesh);
      meshes.push({ p, mesh, mat, local, size: new T.Vector3(...p.size), colour: rgb(p.color) });
    }
    const S = data.sleep;
    const shut = new Set(S.shut), hide = new Set(S.hide);
    const lerp = (a, b, k) => a + (b - a) * k;
    const xf = (v) => new T.Matrix4().makeTranslation(v[0], v[1], v[2]).multiply(new T.Matrix4().makeRotationFromEuler(new T.Euler(v[3], v[4], v[5], 'XYZ')));
    function pose(s, breath) {
      const world = {};
      for (const name of order) {
        const v = [0, 0, 0, 0, 0, 0], a = S.bones[name], b = S.breathe[name];
        for (let i = 0; i < 6; i++) v[i] = lerp(0, (a ? a[i] : 0) + (b ? b[i] * breath : 0), s);
        const par = parentOf[name], pp = par ? pivots[par] : new T.Vector3();
        const c0 = new T.Matrix4().makeTranslation(pivots[name].x - pp.x, pivots[name].y - pp.y, pivots[name].z - pp.z);
        world[name] = (par ? world[par].clone() : new T.Matrix4()).multiply(c0).multiply(xf(v));
      }
      const closed = s > 0.5;
      for (const m of meshes) {
        const sz = m.size.clone();
        if (closed && shut.has(m.p.name)) { sz.y *= 0.18; m.mat.color.setRGB(0.12, 0.09, 0.16); }
        else m.mat.color.copy(m.colour);
        m.mesh.visible = !(closed && hide.has(m.p.name));
        m.mesh.matrix.copy(world[m.p.bone]).multiply(m.local).multiply(new T.Matrix4().makeScale(sz.x, sz.y, sz.z));
      }
      return world;
    }
    // Zzz: Montserrat ExtraBold, outlined, a hue-shifted gradient (warm light top, cool bottom)
    function zSprite() {
      const c = document.createElement('canvas'); c.width = c.height = 128;
      const x = c.getContext('2d');
      x.font = '800 104px Montserrat, sans-serif'; x.textAlign = 'center'; x.textBaseline = 'middle';
      x.lineJoin = 'round'; x.lineWidth = 16; x.strokeStyle = '#1b1f4a'; x.strokeText('Z', 64, 68);
      const gr = x.createLinearGradient(0, 20, 0, 116); gr.addColorStop(0, '#fff6e8'); gr.addColorStop(1, '#8fb4ff');
      x.fillStyle = gr; x.fillText('Z', 64, 68);
      const t = new T.CanvasTexture(c); t.colorSpace = T.SRGBColorSpace;
      return t;
    }
    const zTex = zSprite();
    const zs = [];
    for (let i = 0; i < 12; i++) { const sp = new T.Sprite(new T.SpriteMaterial({ map: zTex, transparent: true, depthWrite: false })); sp.visible = false; scene.add(sp); zs.push(sp); }
    const cam = new T.PerspectiveCamera(32, W / H, 1, 400);
    window.frame = (f) => {
      const world = pose(f.s, f.breath);
      const neck = world[data.neckBone];
      let used = 0;
      for (const z of f.zs) {
        const sp = zs[used++];
        const at = new T.Vector3(...S.zzzAt).applyMatrix4(new T.Matrix4().setPosition(new T.Vector3().setFromMatrixPosition(neck)));
        const k = z.age / S.zzz.Life;
        const size = S.zzz.Size * (1 + 0.25 * z.i) * (0.5 + 0.5 * Math.min(1, k * 4));
        sp.position.set(at.x + S.zzz.Rise / 2 * k + 0.3 * Math.sin(k * 8), at.y + S.zzz.Rise * k, at.z);
        sp.scale.set(size, size, 1);
        sp.material.opacity = Math.min(1, k * 6, (1 - k) * 3);
        sp.visible = true;
      }
      for (let i = used; i < zs.length; i++) zs[i].visible = false;
      cam.position.set(...f.eye); cam.lookAt(...f.at);
      renderer.render(scene, cam);
      return renderer.domElement.toDataURL('image/png');
    };
  }, [data, W, H]);
  let n = 0;
  for (const f of data.frames) {
    const url = await page.evaluate((f) => window.frame(f), f);
    fs.writeFileSync(path.join(outDir, f.name || ('f' + String(n++).padStart(4, '0')) + '.png'), Buffer.from(url.split(',')[1], 'base64'));
  }
  await browser.close();
})();
"""


def frames(sleep, fps=15):
    """Awake a moment, nods off, sleeps two breaths, gets up: the sleep weight and breath
    as BossView works them out (smoothstep of an eased weight; 0.5 - 0.5 cos of the clock)."""
    import math

    B, settle, Z = sleep["breath"], sleep["settle"], sleep["zzz"]
    awake, asleep = 0.6, 2 * B
    total = awake + settle + asleep + settle + 0.4
    out, w, runs = [], 0.0, []
    eye, at = (16, 11, -21), (0, 5, 0)
    for i in range(int(total * fps)):
        t = i / fps
        want = 1 if awake <= t < awake + settle + asleep else 0
        w += max(-1 / fps / settle, min(1 / fps / settle, want - w))
        s = w * w * (3 - 2 * w)
        breath = 0.5 - 0.5 * math.cos(t / B * 2 * math.pi)
        # a run of Zs as each breath goes out (the top of the breath), while it's asleep
        prev = (t - 1 / fps) / B
        if want and math.floor(prev + 0.5) != math.floor(t / B + 0.5) and s > 0.5:
            runs.append(t)
        zs = []
        for r in runs:
            for j in range(int(Z["Count"])):
                age = t - (r + j * Z["Gap"])
                if 0 <= age < Z["Life"]:
                    zs.append({"age": age, "i": j})
        out.append({"s": s, "breath": breath, "zs": zs, "eye": eye, "at": at})
    return out


def main():
    model = sys.argv[1] if len(sys.argv) > 1 else "Chicken"
    out_dirs = [os.path.join(ROOT, "previews")] + sys.argv[2:]
    bones, parts = model_data(model)
    sleep = sleep_settings(model)
    neck = next(b["name"] for b in bones if b["name"] in ("neck", "Head", "Flower"))
    fs = frames(sleep)
    stills = [
        {"name": "awake.png", "s": 0, "breath": 0, "zs": [], "eye": (13, 9, -17), "at": (0, 3.4, 0)},
        {"name": "asleep.png", "s": 1, "breath": 0.4, "zs": [{"age": 0.5, "i": 0}, {"age": 0.15, "i": 1}],
         "eye": (13, 9, -17), "at": (0, 3.4, 0)},
    ]
    tmp = tempfile.mkdtemp()
    data_path = os.path.join(tmp, "data.json")
    json.dump({"bones": bones, "parts": parts, "sleep": sleep, "neckBone": neck, "frames": fs + stills}, open(data_path, "w"))
    js = os.path.join(tmp, "render.js")
    open(js, "w").write(RENDER_JS)
    env = dict(os.environ)
    env["NODE_PATH"] = os.pathsep.join(filter(None, [subprocess.run(["npm", "root", "-g"], capture_output=True, text=True).stdout.strip(), env.get("NODE_PATH", "")]))
    subprocess.run(["node", js, data_path, tmp, find_three()], check=True, env=env)
    name = model.lower()
    gif, png = os.path.join(tmp, "sleep_%s.gif" % name), os.path.join(tmp, "sleep_%s.png" % name)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "15", "-i", os.path.join(tmp, "f%04d.png"),
                    "-vf", "split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer", "-loop", "0", gif], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", os.path.join(tmp, "awake.png"), "-i", os.path.join(tmp, "asleep.png"),
                    "-filter_complex", "hstack", png], check=True)
    for od in out_dirs:
        os.makedirs(od, exist_ok=True)
        shutil.copy(gif, od)
        shutil.copy(png, od)
    print("wrote", os.path.basename(gif), os.path.basename(png))


if __name__ == "__main__":
    main()
