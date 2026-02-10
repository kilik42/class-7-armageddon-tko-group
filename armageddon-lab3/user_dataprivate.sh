#!/bin/bash
set -euxo pipefail

dnf -y install nginx python3

# Remove nginx default site if it exists (prevents duplicate default_server errors)
rm -f /etc/nginx/conf.d/default.conf || true

mkdir -p /opt/armageddon
mkdir -p /usr/share/nginx/html/static

# ----- Static files (fixes /static/example.txt and /static/index.html) -----
cat >/usr/share/nginx/html/static/example.txt <<'TXT'
hello from static
TXT

cat >/usr/share/nginx/html/static/index.html <<'HTML'
<!doctype html>
<html>
  <head><meta charset="utf-8"><title>Static OK</title></head>
  <body><h1>Static index.html OK</h1></body>
</html>
HTML

# ----- Mini API server (adds do_HEAD so curl -I won't 501) -----
cat >/opt/armageddon/api_server.py <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer
import json, time, datetime, random

def utc_iso():
    return datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00","Z")

class Handler(BaseHTTPRequestHandler):
    def _send_json(self, code, body_dict, cache_control):
        body = json.dumps(body_dict).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", cache_control)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_headers_only(self, code, cache_control):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", cache_control)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_HEAD(self):
        # Same routing as GET, but no body
        if self.path == "/api/public-feed":
            self._send_headers_only(200, "public, s-maxage=30, max-age=0")
            return
        if self.path in ("/api/list", "/api/user-feed"):
            self._send_headers_only(200, "private, no-store")
            return
        self._send_headers_only(404, "no-store")

    def do_GET(self):
        if self.path == "/api/public-feed":
            minute = int(time.time() // 60)
            self._send_json(200, {
                "server_time_utc": utc_iso(),
                "message_of_the_minute": f"minute-{minute}"
            }, "public, s-maxage=30, max-age=0")
            return

        if self.path in ("/api/list", "/api/user-feed"):
            self._send_json(200, {
                "server_time_utc": utc_iso(),
                "request_id": f"{time.time_ns()}-{random.randint(1000,9999)}",
                "items": ["alpha","bravo","charlie"]
            }, "private, no-store")
            return

        self._send_json(404, {"error":"not found"}, "no-store")

HTTPServer(("127.0.0.1", 9000), Handler).serve_forever()
PY

cat >/etc/systemd/system/armageddon-api.service <<'UNIT'
[Unit]
Description=Armageddon mini API
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/armageddon/api_server.py
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now armageddon-api

# ----- Nginx: keep your existing endpoints + add /static/ serving -----
cat >/etc/nginx/conf.d/armageddon.conf <<'NGINX'
server {
  listen 80 default_server;
  listen [::]:80 default_server;
  server_name _;

  root /usr/share/nginx/html;
  index index.html;

  location = /health {
    default_type text/plain;
    return 200 "ok\n";
  }

  location = / {
    default_type text/plain;
    return 200 "armageddon target OK\n";
  }

  # Serve /static/* from disk (now includes example.txt + index.html)
  location /static/ {
    try_files $uri =404;
    add_header Cache-Control "public, max-age=86400, immutable" always;
  }

  # Proxy API to python
  location = /api/public-feed {
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_pass http://127.0.0.1:9000;
  }

  location = /api/list {
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_pass http://127.0.0.1:9000;
  }

  location = /api/user-feed {
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_pass http://127.0.0.1:9000;
  }
}
NGINX

nginx -t
systemctl enable --now nginx
PY
