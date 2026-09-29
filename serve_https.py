#!/usr/bin/env python3
# Test-only HTTPS server so serial_monitor.html can be opened from an Android phone
# (Web Serial needs a secure context). Serves ONLY serial_monitor.html; key.pem and
# cert.pem live next to it and must never be served.
# Run:  python3 serve_https.py   ->  https://<pc-lan-ip>:8443/serial_monitor.html
# Cert is self-signed, issued for 192.168.0.20 (+localhost), expires ~2026-10-20.
import http.server, ssl, os, functools

here = os.path.dirname(os.path.abspath(__file__))
ALLOWED = {"/serial_monitor.html"}

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/":
            self.send_response(302); self.send_header("Location", "/serial_monitor.html"); self.end_headers(); return
        if path not in ALLOWED:
            self.send_error(404); return
        super().do_GET()
    do_HEAD = do_GET

handler = functools.partial(Handler, directory=here)
srv = http.server.ThreadingHTTPServer(("0.0.0.0", 8443), handler)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(os.path.join(here, "cert.pem"), os.path.join(here, "key.pem"))
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
print("serving serial_monitor.html on https://0.0.0.0:8443", flush=True)
srv.serve_forever()
