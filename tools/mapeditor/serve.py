"""Serves the map editor on this Mac (QM, Oct 24) and saves straight into the game, so
there's no file to send over.

Run: python3 tools/mapeditor/serve.py [port]     (default 3000; http://localhost:3000)

  GET  /            the editor (MapEditor.html; run build.py after Config or mesh changes)
  GET  /world.map   the game's map as it is now (the editor opens this, not its baked-in copy)
  POST /save        a .map from the editor: merged with any change made to the file since
                    that tab opened it (its X-Map-Base), written to maps/world.map, baked into
                    src/shared/MapData.luau (tools/map_bake.py), synced into the open Studio
                    place and rebuilt there (tools/studio/rebuild.luau) when it's in Edit mode
"""

import hashlib
import json
import os
import subprocess
import sys
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from map_grow import reframe  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
STUDIO = os.path.join(ROOT, "tools", "studio")
WORLD = os.path.join(ROOT, "maps", "world.map")
SERVED = {}  # version -> the text served under it (a tab saves against the version it opened)
PARTS = ("colours", "areas", "tiles", "objects", "fixed", "rows")


def version(text):
    return hashlib.sha1(text.encode()).hexdigest()[:12]


def dump(m):
    """A .map as the editor writes it (dumpMap in editor.html): one row, tile or object a line."""
    j = lambda v: json.dumps(v, separators=(",", ":"), ensure_ascii=False)
    head = {k: v for k, v in m.items() if k not in PARTS}
    out = [j(head)[:-1] + ",", '"colours": {']
    out.append(",\n".join('  "%s": %s' % (k, j(m["colours"][k])) for k in sorted(m["colours"])))
    out.append("},")
    for k in ("areas", "tiles", "objects"):
        out += ['"%s": [' % k, ",\n".join("  " + j(v) for v in m[k]), "],"]
    out.append('"fixed": {')
    items = list(m["fixed"].items())
    for n, (k, v) in enumerate(items):
        comma = "," if n < len(items) - 1 else ""
        if isinstance(v, list):
            out += ['  "%s": [' % k, ",\n".join("    " + j(x) for x in v), "  ]" + comma]
        else:
            out.append('  "%s": %s%s' % (k, j(v), comma))
    out += ["},", '"rows": [', ",\n".join('"%s"' % r for r in m["rows"]), "]}"]
    return "\n".join(out) + "\n"


def merge(base, mine, theirs):
    """Three-way: what the tab changed from the version it opened wins; everything else
    (QM's other tabs, Claude's edits to the file) stays. Rows merge cell by cell."""
    b, m, t = json.loads(base), json.loads(mine), json.loads(theirs)
    if b.get("size") != t.get("size") or b.get("size") != m.get("size"):
        # (the map grew, in the tab or in the file: all three laid into a grid holding both)
        cell = m["cell"]
        x0 = min(m["origin"][0], t["origin"][0])
        z0 = min(m["origin"][1], t["origin"][1])
        x1 = max(d["origin"][0] + d["size"][0] * cell for d in (m, t))
        z1 = max(d["origin"][1] + d["size"][1] * cell for d in (m, t))
        frame = ([x0, z0], [(x1 - x0) // cell, (z1 - z0) // cell])
        grown = [reframe(d, *frame) for d in (b, m, t)]
        if None in grown or cell != t["cell"]:
            return mine  # (a different layout: the tab's map as it is)
        b, m, t = grown
        for d in (b, m):
            d["origin"], d["size"] = t["origin"], t["size"]
    out = dict(t)
    for k in m:
        if k == "rows":
            out["rows"] = ["".join(cm if cm != cb else ct for cm, cb, ct in zip(rm, rb, rt))
                           for rm, rb, rt in zip(m["rows"], b["rows"], t["rows"])]
        elif k == "saved" or m[k] != b.get(k):
            out[k] = m[k]
    return dump(out)


def keep_tops(mine, theirs):
    m, t = json.loads(mine), json.loads(theirs)
    tops = {x["id"]: x["top"] for x in t["tiles"]}
    if all(x.get("top") == tops.get(x["id"], x.get("top")) for x in m["tiles"]):
        return mine
    for x in m["tiles"]:
        x["top"] = tops.get(x["id"], x["top"])
    return dump(m)


def run(*args):
    r = subprocess.run(["python3", *args], cwd=ROOT, capture_output=True, text=True, timeout=300)
    return r.returncode == 0, (r.stdout + r.stderr).strip()


def to_studio():
    """Syncs src/ into Studio and rebuilds workspace.Map there; a message saying how it went."""
    load = os.path.join(tempfile.gettempdir(), "mapeditor_load.luau")
    ok, out = run(os.path.join(STUDIO, "mkload.py"), load)
    if ok:
        ok, out = run(os.path.join(STUDIO, "lu.py"), load, "Edit")
    if not ok or "loaded" not in out:
        return "Saved, but Studio didn't take it (is it open?). Sync and press Map > Rebuild there."
    ok, out = run(os.path.join(STUDIO, "lu.py"), os.path.join(STUDIO, "rebuild.luau"), "Edit")
    last = out.splitlines()[-1] if out else ""
    if ok and last.startswith("baked"):
        return "Saved and rebuilt in Studio. Save the place there to keep it."
    if "playing" in last:
        return "Saved. Studio is in Play: stop it and press Map > Rebuild."
    return "Saved, but the rebuild in Studio failed: " + last[:200]


class Handler(BaseHTTPRequestHandler):
    def send(self, code, body, kind="text/plain; charset=utf-8", headers=None):
        data = body if isinstance(body, bytes) else body.encode()
        self.send_response(code)
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.split("?")[0]
        if path in ("/", "/MapEditor.html"):
            self.send(200, open(os.path.join(HERE, "MapEditor.html"), "rb").read(), "text/html; charset=utf-8")
        elif path == "/world.map":
            text = open(WORLD).read()
            SERVED[version(text)] = text
            self.send(200, text, "application/json", {"X-Map-Version": version(text)})
        else:
            self.send(404, "not found")

    def do_POST(self):
        if self.path != "/save":
            return self.send(404, "not found")
        text = self.rfile.read(int(self.headers.get("Content-Length", 0))).decode()
        try:
            json.loads(text)
        except ValueError:
            return self.send(400, "That isn't a .map.")
        current = open(WORLD).read()
        base = SERVED.get(self.headers.get("X-Map-Base", ""))
        merged = base is not None and base != current
        if merged:
            text = merge(base, text, current)
        elif base is None:
            # (a tab opened before saves were versioned: keep the file's tile heights, which
            # Claude may have changed since that tab opened)
            text = keep_tops(text, current)
        tmp = WORLD + ".tmp"
        open(tmp, "w").write(text)
        os.replace(tmp, WORLD)
        SERVED[version(text)] = text
        ok, out = run(os.path.join(ROOT, "tools", "map_bake.py"))
        if not ok:
            return self.send(500, "Saved maps/world.map, but baking it failed: " + out[-300:])
        # (merged: the tab reloads the file, so it carries the other changes from now on)
        self.send(200, to_studio(), headers={"X-Map-Version": version(text), "X-Map-Merged": "1" if merged else "0"})

    def log_message(self, fmt, *args):
        sys.stderr.write("%s\n" % (fmt % args))


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
    print("map editor on http://localhost:%d" % port)
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
