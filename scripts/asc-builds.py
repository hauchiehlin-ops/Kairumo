#!/usr/bin/env python3
"""
scripts/asc-builds.py
列出 App Store Connect 上每一顆 build 的真實狀態，用來抓「幽靈 build」——
清單看得到、測試者按安裝卻得到「要求的 App 無法使用或不存在」的那種。

用法：
    ./scripts/asc-builds.py              # 列出所有 build
    ./scripts/asc-builds.py --groups     # 一併列出每顆 build 指派到哪些測試群組

憑證從 apple/ExportConfig.env 讀（方式 A 的三個欄位）：
    APP_STORE_CONNECT_API_KEY_ID / _ISSUER_ID / _KEY_PATH

這裡不用 PyJWT —— 本機沒有那個套件，也不想為了查個狀態就要求裝相依。
ES256 直接用 openssl 簽，再把 DER 簽章轉成 JOSE 要的 r||s 原始格式。
"""
import base64, json, os, re, subprocess, sys, time, urllib.request, urllib.error

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_config():
    cfg, path = {}, os.path.join(REPO, "apple", "ExportConfig.env")
    if os.path.exists(path):
        for line in open(path):
            m = re.match(r'\s*([A-Z_]+)\s*=\s*"?([^"\n#]*)"?', line)
            if m:
                cfg[m.group(1)] = m.group(2).strip()
    for k in ("APP_STORE_CONNECT_API_KEY_ID", "APP_STORE_CONNECT_ISSUER_ID",
              "APP_STORE_CONNECT_KEY_PATH"):
        cfg[k] = os.environ.get(k) or cfg.get(k, "")
    return cfg


def b64u(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    """DER 的 SEQUENCE{INTEGER r, INTEGER s} → 64 bytes 的 r||s。

    openssl 輸出 DER，JOSE 的 ES256 要的是定長原始格式。直接把 DER 塞進 JWT
    的話 Apple 一律回 401，而且訊息只說 NOT_AUTHORIZED，不會告訴你是簽章格式錯。
    """
    assert der[0] == 0x30
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)

    def take(idx):
        assert der[idx] == 0x02
        ln = der[idx + 1]
        val = der[idx + 2: idx + 2 + ln]
        return val.lstrip(b"\x00").rjust(32, b"\x00"), idx + 2 + ln

    r, i = take(i)
    s, _ = take(i)
    return r + s


def token(cfg) -> str:
    header = {"alg": "ES256", "kid": cfg["APP_STORE_CONNECT_API_KEY_ID"], "typ": "JWT"}
    now = int(time.time())
    payload = {"iss": cfg["APP_STORE_CONNECT_ISSUER_ID"], "iat": now,
               "exp": now + 900, "aud": "appstoreconnect-v1"}
    signing_input = f"{b64u(json.dumps(header).encode())}.{b64u(json.dumps(payload).encode())}"
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", cfg["APP_STORE_CONNECT_KEY_PATH"], "-binary"],
        input=signing_input.encode(), capture_output=True, check=True).stdout
    return f"{signing_input}.{b64u(der_to_raw(der))}"


def api(cfg, path):
    url = path if path.startswith("http") else f"https://api.appstoreconnect.apple.com{path}"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token(cfg)}"})
    try:
        return json.load(urllib.request.urlopen(req, timeout=60))
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        print(f"❌ API {e.code}: {url}\n{body}", file=sys.stderr)
        sys.exit(1)


def main():
    show_groups = "--groups" in sys.argv
    cfg = load_config()
    missing = [k for k in ("APP_STORE_CONNECT_API_KEY_ID", "APP_STORE_CONNECT_ISSUER_ID",
                           "APP_STORE_CONNECT_KEY_PATH") if not cfg.get(k)]
    if missing:
        print("❌ apple/ExportConfig.env 缺少：" + "、".join(missing), file=sys.stderr)
        print("   ASC → 使用者與存取權 → 整合／API 金鑰 → 產生 App Manager 金鑰，", file=sys.stderr)
        print("   下載 .p8（只能下載一次），把絕對路徑填進 APP_STORE_CONNECT_KEY_PATH。", file=sys.stderr)
        sys.exit(2)
    if not os.path.exists(cfg["APP_STORE_CONNECT_KEY_PATH"]):
        print(f"❌ 找不到金鑰檔：{cfg['APP_STORE_CONNECT_KEY_PATH']}", file=sys.stderr)
        sys.exit(2)

    bundle = cfg.get("BUNDLE_ID") or "com.kairumo.padnote"
    apps = api(cfg, f"/v1/apps?filter[bundleId]={bundle}")["data"]
    if not apps:
        print(f"❌ 這把金鑰看不到 bundleId {bundle} 的 App。", file=sys.stderr)
        sys.exit(1)
    app = apps[0]
    print(f"App：{app['attributes']['name']}　id={app['id']}　{bundle}\n")

    data = api(cfg, f"/v1/apps/{app['id']}/builds"
                    "?limit=100&include=preReleaseVersion&sort=-uploadedDate")
    included = {(i["type"], i["id"]): i for i in data.get("included", [])}

    print(f"{'版本':>10} {'build':>6} {'平台':<8} {'處理狀態':<12} {'已過期':<7} {'上傳時間':<22} {'可測試'}")
    print("─" * 92)
    suspects = []
    for b in data["data"]:
        a = b["attributes"]
        pre = b.get("relationships", {}).get("preReleaseVersion", {}).get("data")
        pv = included.get(("preReleaseVersions", pre["id"])) if pre else None
        ver = pv["attributes"]["version"] if pv else "?"
        plat = pv["attributes"]["platform"] if pv else "?"
        state = a.get("processingState", "?")
        expired = a.get("expired")
        # 這一欄才是「測試者按下安裝會不會拿到東西」。
        # VALID 但 expired 的 build 仍然列在 TestFlight 裡。
        usable = "✅" if (state == "VALID" and not expired) else "❌"
        print(f"{ver:>10} {a.get('version',''):>6} {plat:<8} {state:<12} "
              f"{str(bool(expired)):<7} {str(a.get('uploadedDate',''))[:19]:<22} {usable}")
        if state != "VALID" or expired:
            suspects.append((ver, a.get("version"), state, bool(expired), b["id"]))
        if show_groups:
            gs = api(cfg, f"/v1/builds/{b['id']}/betaGroups")["data"]
            names = [g["attributes"]["name"] for g in gs] or ["（未指派任何群組）"]
            print(f"{'':>10} └─ 群組：{'、'.join(names)}")

    print()
    if suspects:
        print("⚠️ 以下 build 在 TestFlight 清單裡看得到，但測試者裝不了：")
        for ver, bn, state, exp, bid in suspects:
            why = "已過期" if exp else f"處理狀態 {state}"
            print(f"   • {ver} ({bn})　{why}　id={bid}")
        print()
        print("   到 ASC → TestFlight → 該 build → 停止測試（Expire），")
        print("   再把可用的那顆明確加進測試群組。")
    else:
        print("✅ 沒有異常 build。若測試者仍裝不了，問題在群組指派或 Beta App Review。")


if __name__ == "__main__":
    main()
