"""Local AI OS request router.

Serves OpenAI-compatible traffic on 127.0.0.1:8090 by default. Short,
no-tool chat requests go to the desktop-local lane (ask-local --serve), while
larger/tool requests go to an offload endpoint (typically a llama-swap server on
the user's GPU box). Every routing decision is logged to
$XDG_STATE_HOME/llm-router/decisions.jsonl.

Environment:
  LLM_ROUTER_PORT       listen port, default 8090
  LLM_ROUTER_LOCAL      local OpenAI-compatible endpoint, default http://127.0.0.1:8088
  LLM_ROUTER_UPSTREAM   offload OpenAI-compatible endpoint, default http://127.0.0.1:8012
  LLM_ROUTER_TOKEN_CAP  route <= this approximate input token count locally, default 4096
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LOCAL = os.environ.get("LLM_ROUTER_LOCAL", "http://127.0.0.1:8088")
UPSTREAM = os.environ.get("LLM_ROUTER_UPSTREAM", "http://127.0.0.1:8012")
TOKEN_CAP = int(os.environ.get("LLM_ROUTER_TOKEN_CAP", "4096"))
STATE = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
    "llm-router",
)
PASS_HDRS = (
    "authorization",
    "x-api-key",
    "anthropic-version",
    "openai-organization",
    "accept",
)
COPY_HDRS = (
    "content-type",
    "content-length",
    "cache-control",
    "transfer-encoding",
)


def log_decision(rec):
    try:
        os.makedirs(STATE, exist_ok=True)
        with open(os.path.join(STATE, "decisions.jsonl"), "a") as f:
            f.write(json.dumps(rec) + "\n")
    except OSError:
        pass


class Router(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n) if n else b""

    def _target_url(self, base):
        base = base.rstrip("/")
        # Accept both origins (http://host:8012) and /v1 bases.
        if base.endswith("/v1") and self.path.startswith("/v1/"):
            base = base[:-3]
        return base + self.path

    def _forward(self, base, body):
        data = body if body else None
        req = urllib.request.Request(
            self._target_url(base), data=data, method=self.command
        )
        req.add_header(
            "Content-Type", self.headers.get("Content-Type", "application/json")
        )
        for h in PASS_HDRS:
            v = self.headers.get(h)
            if v:
                req.add_header(h, v)
        return urllib.request.urlopen(req, timeout=600)

    def _relay(self, resp):
        self.send_response(resp.status)
        for h in COPY_HDRS:
            v = resp.headers.get(h)
            if v:
                self.send_header(h, v)
        if not resp.headers.get("content-length"):
            self.send_header("Connection", "close")
        self.end_headers()
        while True:
            chunk = resp.read(8192)
            if not chunk:
                break
            self.wfile.write(chunk)
            self.wfile.flush()

    def _choose_lane(self, body):
        lane, tokens = "upstream", 0
        if self.path.startswith("/v1/chat/completions") and body:
            try:
                req = json.loads(body)
                msgs = req.get("messages") or []
                tokens = len(json.dumps(msgs)) // 4
                has_tools = bool(req.get("tools") or req.get("functions"))
                if tokens <= TOKEN_CAP and not has_tools:
                    lane = "local"
            except (TypeError, ValueError):
                pass
        return lane, tokens

    def do_GET(self):
        self.do_POST()

    def do_POST(self):
        body = self._body()
        lane, tokens = self._choose_lane(body)
        t0 = time.monotonic()
        status = 0
        try:
            target = LOCAL if lane == "local" else UPSTREAM
            try:
                resp = self._forward(target, body)
            except urllib.error.URLError:
                if lane != "local":
                    raise
                lane = "local-unavailable"
                resp = self._forward(UPSTREAM, body)
            status = resp.status
            self._relay(resp)
        except urllib.error.HTTPError as e:
            status = e.code
            self._relay(e)
        except (urllib.error.URLError, ConnectionError, TimeoutError) as e:
            status = 502
            msg = json.dumps({"error": str(e)}).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)
        finally:
            log_decision(
                {
                    "ts": time.time(),
                    "lane": lane,
                    "path": self.path,
                    "tokens_in": tokens,
                    "status": status,
                    "latency_ms": int((time.monotonic() - t0) * 1000),
                }
            )

    def log_message(self, fmt, *args):
        sys.stderr.write("llm-router: %s\n" % (fmt % args))


def main():
    addr = ("127.0.0.1", int(os.environ.get("LLM_ROUTER_PORT", "8090")))
    sys.stderr.write(
        "llm-router: %s:%d  local=%s  upstream=%s  cap=%d\n"
        % (addr[0], addr[1], LOCAL, UPSTREAM, TOKEN_CAP)
    )
    ThreadingHTTPServer(addr, Router).serve_forever()


if __name__ == "__main__":
    main()
