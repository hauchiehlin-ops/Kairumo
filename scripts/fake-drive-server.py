#!/usr/bin/env python3
"""本機的假 Google Drive（appDataFolder 子集），給模擬器上的多裝置測試用。

# 為什麼需要它

多裝置的行為（A 刪除 → B 確認 → 期滿後雲端清除、更名有沒有傳到另一台、還原…）
只能用兩個真正在跑的 App 驗證，但模擬器上沒辦法登入 Google。核心的
`FfiDriveHttp` 是平台實作的傳輸層，所以只要平台在**測試模式**下把
`https://www.googleapis.com` 換成這個伺服器，兩個（或三個）模擬器上真實的 App、
真實的核心同步碼就能共用同一份「雲端」。

只實作核心實際會打的那幾個端點（見 `crates/padnote-sync/src/gdrive.rs`）：

  GET    /drive/v3/files?q=…                      列舉（`name = '…'`／`name contains '…'`）
  GET    /drive/v3/files/{id}?alt=media           讀內容（支援 Range）
  DELETE /drive/v3/files/{id}
  POST   /drive/v3/files                           建立空檔案，回 {"id": …}
  PATCH  /upload/drive/v3/files/{id}?uploadType=media       上傳（小檔）
  POST   /upload/drive/v3/files/{id}?uploadType=resumable   開續傳工作階段（Location 標頭）
  PUT    /upload/session/{id}                      續傳的位元組
  GET    /drive/v3/changes/startPageToken
  GET    /drive/v3/changes?pageToken=…             變更游標

管理用（測試腳本看雲端現況）：
  GET  /_admin/files            [{name,size,id,modified}]
  GET  /_admin/read?name=…      檔案內容（例如 sync/<device>/ack.json）
  POST /_admin/reset            清空

用法：  python3 scripts/fake-drive-server.py [port]     （預設 8765）
Android 模擬器用 http://10.0.2.2:<port> 連到這台 Mac 的 127.0.0.1。
"""
import json
import re
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urlparse

LOCK = threading.Lock()
# 位置就是 id（"id-<index>"）。刪除只清空名字與內容，位置保留 —— 與真的 Drive 一樣，
# id 不會被重用；變更游標就是 LOG 的長度。
FILES = []  # {"name": str, "data": bytes, "modified": str}
LOG = []  # 變更序列：檔案位置


def now_rfc3339():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def note_change(index):
    LOG.append(index)


def unescape_literal(text):
    """Drive 查詢字面值的跳脫：`\\'` 與 `\\\\`。"""
    return re.sub(r"\\(['\\])", r"\1", text)


def matches_query(name, q):
    m = re.search(r"name = '((?:[^'\\]|\\.)*)'", q)
    if m:
        return name == unescape_literal(m.group(1))
    m = re.search(r"name contains '((?:[^'\\]|\\.)*)'", q)
    if m:
        return unescape_literal(m.group(1)).lower() in name.lower()
    return True


def file_json(i):
    f = FILES[i]
    return {
        "id": f"id-{i}",
        "name": f["name"],
        "size": str(len(f["data"])),
        "modifiedTime": f["modified"],
        "trashed": False,
    }


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # 安靜
        pass

    # ── 小工具 ──
    def _send(self, code, body=b"", ctype="application/json", headers=None):
        if isinstance(body, (dict, list)):
            body = json.dumps(body).encode()
        elif isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n) if n else b""

    def _file_index(self, path):
        m = re.search(r"/files/id-(\d+)", path) or re.search(r"/session/(\d+)", path)
        return int(m.group(1)) if m else None

    def _alive(self, i):
        return i is not None and 0 <= i < len(FILES) and FILES[i]["name"] != ""

    # ── GET ──
    def do_GET(self):
        u = urlparse(self.path)
        q = {k: v[0] for k, v in parse_qs(u.query, keep_blank_values=True).items()}
        with LOCK:
            if u.path == "/drive/v3/changes/startPageToken":
                return self._send(200, {"startPageToken": str(len(LOG))})
            if u.path == "/drive/v3/changes":
                return self._send(200, self._changes(int(q.get("pageToken") or 0)))
            if u.path == "/drive/v3/files":
                query = q.get("q", "")
                files = [
                    file_json(i)
                    for i, f in enumerate(FILES)
                    if f["name"] and matches_query(f["name"], query)
                ]
                return self._send(200, {"files": files})
            if u.path.startswith("/drive/v3/files/id-"):
                i = self._file_index(u.path)
                if not self._alive(i):
                    return self._send(404, {"error": {"code": 404, "message": "File not found"}})
                data = FILES[i]["data"]
                rng = self.headers.get("Range")
                if rng:
                    m = re.match(r"bytes=(\d+)-(\d*)", rng)
                    if m:
                        start = int(m.group(1))
                        end = int(m.group(2)) if m.group(2) else len(data) - 1
                        return self._send(206, data[start : end + 1], "application/octet-stream")
                if q.get("alt") == "media":
                    return self._send(200, data, "application/octet-stream")
                return self._send(200, file_json(i))
            if u.path == "/_admin/files":
                return self._send(
                    200,
                    [
                        {"name": f["name"], "size": len(f["data"]), "id": f"id-{i}", "modified": f["modified"]}
                        for i, f in enumerate(FILES)
                        if f["name"]
                    ],
                )
            if u.path == "/_admin/read":
                name = q.get("name", "")
                for f in FILES:
                    if f["name"] == name:
                        return self._send(200, f["data"], "application/octet-stream")
                return self._send(404, {"error": "no such file"})
        return self._send(404, {"error": f"unhandled GET {u.path}"})

    def _changes(self, token):
        seen, out = set(), []
        for index in LOG[token:]:
            if index in seen:
                continue
            seen.add(index)
            f = FILES[index]
            if not f["name"]:
                out.append({"fileId": f"id-{index}", "removed": True})
            else:
                out.append({"fileId": f"id-{index}", "removed": False, "file": file_json(index)})
        return {"changes": out, "newStartPageToken": str(len(LOG))}

    # ── POST ──
    def do_POST(self):
        u = urlparse(self.path)
        body = self._body()
        with LOCK:
            if u.path == "/drive/v3/files":
                meta = json.loads(body or b"{}")
                FILES.append({"name": meta.get("name", ""), "data": b"", "modified": now_rfc3339()})
                idx = len(FILES) - 1
                note_change(idx)
                return self._send(200, {"id": f"id-{idx}"})
            if u.path.startswith("/upload/drive/v3/files/id-") and "resumable" in u.query:
                i = self._file_index(u.path)
                if not self._alive(i):
                    return self._send(404, {"error": {"code": 404}})
                host = self.headers.get("Host", "127.0.0.1")
                return self._send(200, b"{}", headers={"Location": f"http://{host}/upload/session/{i}"})
            if u.path == "/_admin/reset":
                FILES.clear()
                LOG.clear()
                return self._send(200, {"ok": True})
        return self._send(404, {"error": f"unhandled POST {u.path}"})

    # ── PATCH / PUT ──
    def _write(self, i, data):
        if not self._alive(i):
            return self._send(404, {"error": {"code": 404}})
        FILES[i]["data"] = data
        FILES[i]["modified"] = now_rfc3339()
        note_change(i)
        return self._send(200, {"id": f"id-{i}"})

    def do_PATCH(self):
        u = urlparse(self.path)
        body = self._body()
        with LOCK:
            if u.path.startswith("/upload/drive/v3/files/id-"):
                return self._write(self._file_index(u.path), body)
        return self._send(404, {"error": f"unhandled PATCH {u.path}"})

    def do_PUT(self):
        u = urlparse(self.path)
        body = self._body()
        with LOCK:
            if u.path.startswith("/upload/session/"):
                return self._write(self._file_index(u.path), body)
        return self._send(404, {"error": f"unhandled PUT {u.path}"})

    # ── DELETE ──
    def do_DELETE(self):
        u = urlparse(self.path)
        with LOCK:
            if u.path.startswith("/drive/v3/files/id-"):
                i = self._file_index(u.path)
                if not self._alive(i):
                    return self._send(404, {"error": {"code": 404}})
                FILES[i]["name"] = ""
                FILES[i]["data"] = b""
                note_change(i)
                return self._send(204)
        return self._send(404, {"error": f"unhandled DELETE {u.path}"})


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"fake drive on http://127.0.0.1:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
