#!/usr/bin/env python3
"""
Minimal REST backend for the CN project (Python standard library only).

  python3 server.py --name A --port 3001     # on Mac 3
  python3 server.py --name B --port 3002     # on Mac 4

Endpoints
  GET /             small HTML page (no-store, so browser refresh shows LB)
  GET /api/status   JSON {backend, status, ...}  (no-store)
  GET /api/catalog  cacheable JSON: Cache-Control max-age=60 + ETag -> 304
  GET /health       plain "ok" (for nginx / scripts)
Every response carries the header  X-Backend: A|B
"""
import argparse, hashlib, json, socket, time
from email.utils import formatdate
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

ap = argparse.ArgumentParser()
ap.add_argument("--name", required=True, help="backend id, e.g. A or B")
ap.add_argument("--port", type=int, required=True)
ap.add_argument("--host", default="0.0.0.0",
                help="0.0.0.0 = all interfaces (do NOT use 127.0.0.1)")
args = ap.parse_args()

HOSTNAME = socket.gethostname()
STARTED = time.time()

# Cacheable resource: identical on A and B, so its ETag is identical too.
# (If each backend produced a different ETag, conditional requests would
#  miss every time the load balancer switched backends.)
CATALOG = {"version": 1, "items": [
    {"id": 1, "name": "DNS"}, {"id": 2, "name": "TCP"},
    {"id": 3, "name": "TLS"}, {"id": 4, "name": "HTTP"}]}
CATALOG_BODY = json.dumps(CATALOG, sort_keys=True, indent=2).encode()
CATALOG_ETAG = '"' + hashlib.sha256(CATALOG_BODY).hexdigest()[:16] + '"'
CATALOG_LASTMOD = formatdate(1735689600, usegmt=True)  # fixed date


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "TeamBackend/1.0"

    def _send(self, code, body=b"", ctype="application/json", headers=None):
        self.send_response(code)
        self.send_header("X-Backend", args.name)
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        if code != 304:  # 304 must not carry a body
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body and code != 304 and self.command != "HEAD":
            self.wfile.write(body)

    def _json(self, code, obj, headers=None):
        self._send(code, json.dumps(obj, indent=2).encode() + b"\n",
                   headers=headers)

    def do_GET(self):
        path = self.path.split("?", 1)[0]

        if path == "/":
            html = (f"<!doctype html><title>Backend {args.name}</title>"
                    f"<h1>Served by Backend {args.name}</h1>"
                    f"<p>host: {HOSTNAME}, port: {args.port}</p>"
                    f"<p>Refresh to watch the load balancer alternate.</p>")
            self._send(200, html.encode(), "text/html; charset=utf-8",
                       {"Cache-Control": "no-store"})

        elif path == "/api/status":
            self._json(200, {
                "backend": args.name,
                "status": "ok",
                "host": HOSTNAME,
                "port": args.port,
                "uptime_s": round(time.time() - STARTED, 1),
                # TCP peer = the EDGE (nginx), not the real client:
                "tcp_peer_ip": self.client_address[0],
                # the real client, as reported by nginx:
                "x_forwarded_for": self.headers.get("X-Forwarded-For"),
                "x_forwarded_proto": self.headers.get("X-Forwarded-Proto"),
                "host_header": self.headers.get("Host"),
            }, {"Cache-Control": "no-store"})

        elif path == "/api/catalog":
            cache_hdrs = {"Cache-Control": "public, max-age=60",
                          "ETag": CATALOG_ETAG,
                          "Last-Modified": CATALOG_LASTMOD}
            inm = self.headers.get("If-None-Match", "")
            tags = [t.strip().removeprefix("W/") for t in inm.split(",")]
            if CATALOG_ETAG in tags or inm.strip() == "*":
                self._send(304, headers=cache_hdrs)        # not modified
            else:
                self._send(200, CATALOG_BODY, headers=cache_hdrs)

        elif path == "/health":
            self._send(200, b"ok\n", "text/plain")

        else:
            self._json(404, {"error": "not found", "path": path})

    do_HEAD = do_GET   # so `curl -I` works

    def log_message(self, fmt, *a):
        print(f"[{args.name}] {self.client_address[0]}:{self.client_address[1]}"
              f" {fmt % a}", flush=True)


if __name__ == "__main__":
    srv = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"Backend {args.name} listening on {args.host}:{args.port} "
          f"(host {HOSTNAME})", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped")
