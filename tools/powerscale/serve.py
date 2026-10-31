"""The powerscaling dashboard (QM, Oct 31): every item, pet and Strength curve in
src/shared/Config.luau as a graph, with presets and baselines to edit, saved straight into
Config.luau (only the values you changed; comments and everything else stay as they are)
and loaded into the open Studio place.

Run: python3 tools/powerscale/serve.py [port]     (default 3001; http://localhost:3001)
     or double-click "Powerscaling.command" in the project folder, which starts it if it
     isn't running and opens the page.

  GET  /            the dashboard (dashboard.html)
  GET  /config      Config.luau as JSON: { tree, paths (the values it can write), version }
  POST /save        { edits: { "Bosses.MotherHen.Health": 250, ... }, base: version }
"""

import hashlib
import json
import os
import subprocess
import sys
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
CONFIG = os.path.join(ROOT, "src", "shared", "Config.luau")
STUDIO = os.path.join(ROOT, "tools", "studio")
sys.path.insert(0, HERE)
import luaconfig  # noqa: E402


def version(text):
    return hashlib.sha1(text.encode()).hexdigest()[:12]


def run(*args):
    try:
        r = subprocess.run(["python3", *args], cwd=ROOT, capture_output=True, text=True, timeout=120)
    except Exception as e:  # (no Studio tools on this machine)
        return False, str(e)
    return r.returncode == 0, (r.stdout + r.stderr).strip()


def to_studio():
    """Syncs src/ into the open Studio place (Edit mode); a message saying how it went."""
    if not os.path.exists(os.path.join(STUDIO, "lu.py")):
        return "Saved to Config.luau."
    load = os.path.join(tempfile.gettempdir(), "powerscale_load.luau")
    ok, out = run(os.path.join(STUDIO, "mkload.py"), load)
    if ok:
        ok, out = run(os.path.join(STUDIO, "lu.py"), load, "Edit")
    if ok and "loaded" in out:
        return "Saved and loaded into Studio. Save the place there to keep it."
    if "playing" in out.lower():
        return "Saved to Config.luau. Studio is in Play: stop it and it picks the change up on the next sync."
    return "Saved to Config.luau. Studio didn't take it (is it open?): it loads on the next sync."


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
        if path in ("/", "/index.html", "/power"):
            self.send(200, open(os.path.join(HERE, "dashboard.html"), "rb").read(), "text/html; charset=utf-8")
        elif path == "/config":
            text = open(CONFIG).read()
            try:
                tree, spans = luaconfig.parse(text)
            except ValueError as e:
                return self.send(500, "Couldn't read Config.luau: %s" % e)
            body = {"tree": tree, "paths": {p: s[2] for p, s in spans.items()}, "version": version(text)}
            self.send(200, json.dumps(body), "application/json")
        elif path == "/ping":
            self.send(200, "powerscale")
        else:
            self.send(404, "not found")

    def do_POST(self):
        if self.path != "/save":
            return self.send(404, "not found")
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))).decode())
            edits = body["edits"]
        except (ValueError, KeyError):
            return self.send(400, "That isn't a save.")
        # (written into the file as it is now: anything else changed in it since the page
        # loaded stays; only these values change)
        text = open(CONFIG).read()
        try:
            new = luaconfig.write(text, edits)
        except KeyError as e:
            return self.send(400, "Config.luau has no plain value at %s any more. Reload the page." % e)
        luaconfig.parse(new)  # (still reads: raises before anything is written if not)
        tmp = CONFIG + ".tmp"
        open(tmp, "w").write(new)
        os.replace(tmp, CONFIG)
        self.send(200, json.dumps({"message": to_studio(), "count": len(edits)}), "application/json")

    def log_message(self, fmt, *args):
        sys.stderr.write("%s\n" % (fmt % args))


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 3001
    print("powerscaling dashboard on http://localhost:%d" % port)
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
