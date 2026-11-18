# Written by AI on 2026.11.18 by model claude fable 5.2. Serves the iPhone design prototype with real data.
#   python3 design/iphone/serve.py [port]      then open http://<this Mac's Tailscale name>:<port>/
# - `/latest` and `/runs/*` are passed through from the live server, Range header included (as site/serve.py).
# - `/saved/latest` and `/saved/runs/*` are the KNMI run kept for the App Store pictures (a heavy shower
#   crossing Friesland, design/captures/store/run), with its time moved to `?age=` minutes ago (10 if absent).
# - `/map?lat=&lon=&km=&w=&h=&mode=dark|light` is Apple's own map for that region, made on this Mac by
#   snap.swift (MapKit), kept in /tmp. The pictures are Apple's and are not committed.
import json, os, re, subprocess, sys, urllib.request, urllib.error
from datetime import datetime, timedelta, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
SAVED = REPO / "design/captures/store/run"
LIVE = "https://rain.jjpcodes.com"
CACHE = Path("/tmp/rainwatch-iphone-design")
PASSED = ("Content-Type", "Content-Length", "Content-Range", "Cache-Control", "Accept-Ranges", "ETag", "Last-Modified")


def snap_tool():
    CACHE.mkdir(exist_ok=True)
    tool, source = CACHE / "snap", HERE / "snap.swift"
    if not tool.exists() or tool.stat().st_mtime < source.stat().st_mtime:
        subprocess.run(["swiftc", "-O", str(source), "-o", str(tool)], check=True, capture_output=True)
    return tool


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(HERE), **kwargs)

    def send(self, status, body, content_type, extra=()):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        for name, value in extra:
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        url = urlparse(self.path)
        query = {k: v[0] for k, v in parse_qs(url.query).items()}
        if url.path == "/rain.js":
            return self.send(200, (REPO / "site/rain.js").read_bytes(), "text/javascript")
        if url.path == "/latest" or url.path.startswith("/runs/"):
            return self.live()
        if url.path == "/saved/latest":
            age = int(query.get("age", 10))
            moment = datetime.now(timezone.utc) - timedelta(minutes=age)
            run = moment.replace(minute=moment.minute - moment.minute % 5, second=0, microsecond=0)
            text = re.sub(r'"run":"[^"]*"', f'"run":"{run:%Y-%m-%dT%H:%MZ}"', (SAVED / "latest").read_text())
            return self.send(200, text.encode(), "application/json")
        if url.path.startswith("/saved/runs/"):
            return self.ranged(SAVED / url.path.removeprefix("/saved/"))
        if url.path == "/map":
            return self.map(query)
        return super().do_GET()

    def live(self):
        request = urllib.request.Request(LIVE + self.path)
        if self.headers.get("Range"):
            request.add_header("Range", self.headers["Range"])
        try:
            response = urllib.request.urlopen(request, timeout=20)
        except urllib.error.HTTPError as error:
            response = error
        body = response.read()
        self.send_response(response.status)
        for name in PASSED:
            if response.headers.get(name):
                self.send_header(name, response.headers[name])
        self.end_headers()
        self.wfile.write(body)

    def ranged(self, path):
        data = path.read_bytes()
        match = re.fullmatch(r"bytes=(\d+)-(\d+)", self.headers.get("Range", ""))
        if not match:
            return self.send(200, data, "application/octet-stream")
        first, last = int(match[1]), int(match[2])
        self.send(206, data[first:last + 1], "application/octet-stream", [("Content-Range", f"bytes {first}-{last}/{len(data)}")])

    def map(self, q):
        name = "map-{lat}-{lon}-{km}-{w}-{h}-{mode}".format(**q)
        picture, facts = CACHE / f"{name}.png", CACHE / f"{name}.json"
        if not facts.exists():
            done = subprocess.run([str(snap_tool()), q["lat"], q["lon"], q["km"], q["w"], q["h"], q["mode"], str(picture)],
                                  capture_output=True, text=True, timeout=60)
            if done.returncode:
                return self.send(502, done.stderr.encode(), "text/plain")
            facts.write_text(done.stdout)
        if q.get("facts"):
            return self.send(200, facts.read_bytes(), "application/json")
        self.send(200, picture.read_bytes(), "image/png", [("Cache-Control", "max-age=86400")])

    def end_headers(self):
        if not any(b"Cache-Control" in line for line in getattr(self, "_headers_buffer", [])):
            self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8793
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
