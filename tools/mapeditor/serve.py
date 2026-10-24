"""Serves the map editor on this Mac (QM, Oct 24) and saves straight into the game, so
there's no file to send over.

Run: python3 tools/mapeditor/serve.py [port]     (default 3000; http://localhost:3000)

  GET  /            the editor (MapEditor.html; run build.py after Config or mesh changes)
  GET  /world.map   the game's map as it is now (the editor opens this, not its baked-in copy)
  POST /save        a .map from the editor: written to maps/world.map, baked into
                    src/shared/MapData.luau (tools/map_bake.py), synced into the open Studio
                    place and rebuilt there (tools/studio/rebuild.luau) when it's in Edit mode
"""

import json
import os
import subprocess
import sys
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
STUDIO = os.path.join(ROOT, "tools", "studio")
WORLD = os.path.join(ROOT, "maps", "world.map")


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
    def send(self, code, body, kind="text/plain; charset=utf-8"):
        data = body if isinstance(body, bytes) else body.encode()
        self.send_response(code)
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
            self.send(200, open(WORLD, "rb").read(), "application/json")
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
        tmp = WORLD + ".tmp"
        open(tmp, "w").write(text)
        os.replace(tmp, WORLD)
        ok, out = run(os.path.join(ROOT, "tools", "map_bake.py"))
        if not ok:
            return self.send(500, "Saved maps/world.map, but baking it failed: " + out[-300:])
        self.send(200, to_studio())

    def log_message(self, fmt, *args):
        sys.stderr.write("%s\n" % (fmt % args))


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
    print("map editor on http://localhost:%d" % port)
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
