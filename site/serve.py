# Written by AI on 2026.11.18 by model claude fable 5.2. Serves the website prototype on this machine as
# it would be served at rain.jjpcodes.com: the page and the forecast files from one address. `latest`
# and `runs/*` are passed through from the live server byte for byte, Range header included, so the
# page's two requests are the ones a browser would make there.
#   python3 serve.py [port]
import sys, urllib.request, urllib.error
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

LIVE = "https://rain.jjpcodes.com"
PASSED = ("Content-Type", "Content-Length", "Content-Range", "Cache-Control", "Accept-Ranges", "ETag", "Last-Modified")


class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/latest" and not self.path.startswith("/runs/"):
            return super().do_GET()
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

    def end_headers(self):
        if not (self.path == "/latest" or self.path.startswith("/runs/")):
            self.send_header("Cache-Control", "no-store")
        super().end_headers()


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8791
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
