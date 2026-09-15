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

    # 關聯端點 /v1/apps/{id}/builds 不接受 include 與 sort（實測回 400
    # PARAMETER_ERROR.ILLEGAL）。頂層 /v1/builds 搭 filter[app] 才吃這兩個參數。
    #
    # buildBetaDetail 是這支工具的重點：processingState 只說 Apple 處理完了沒，
    # 真正決定「測試者按下安裝拿不拿得到東西」的是 internal/externalBuildState。
    data = api(cfg, f"/v1/builds?filter[app]={app['id']}"
                    "&limit=200&include=preReleaseVersion,buildBetaDetail"
                    "&sort=-uploadedDate")
    included = {(i["type"], i["id"]): i for i in data.get("included", [])}

    def rel(b, name, typ):
        r = b.get("relationships", {}).get(name, {}).get("data")
        return included.get((typ, r["id"])) if r else None

    # 這些狀態代表「清單看得到，但裝不了」——正是使用者回報的症狀。
    BAD = {
        "PROCESSING_EXCEPTION": "處理失敗（沒有可下載的二進位檔）",
        "MISSING_EXPORT_COMPLIANCE": "缺少出口合規資訊",
        "EXPIRED": "已過期",
        "BETA_REJECTED": "Beta 審核被拒",
        "READY_FOR_BETA_SUBMISSION": "尚未送 Beta 審核（外部測試者拿不到）",
        "IN_BETA_REVIEW": "Beta 審核中（外部測試者還拿不到）",
        "PROCESSING": "仍在處理中",
    }

    hdr = (f"{'版本':>9} {'build':>6} {'平台':<7} {'處理':<10} "
           f"{'內部測試':<26} {'外部測試':<26}")
    print(hdr)
    print("─" * 96)
    suspects = []
    for b in data["data"]:
        a = b["attributes"]
        pv = rel(b, "preReleaseVersion", "preReleaseVersions")
        bd = rel(b, "buildBetaDetail", "buildBetaDetails")
        ver = pv["attributes"]["version"] if pv else "?"
        plat = pv["attributes"]["platform"] if pv else "?"
        state = a.get("processingState", "?")
        expired = bool(a.get("expired"))
        internal = (bd["attributes"].get("internalBuildState") if bd else None) or "?"
        external = (bd["attributes"].get("externalBuildState") if bd else None) or "?"
        if expired:
            internal = external = "EXPIRED"
        print(f"{ver:>9} {str(a.get('version','')):>6} {plat:<7} {state:<10} "
              f"{internal:<26} {external:<26}")
        why = []
        if state != "VALID":
            why.append(f"處理狀態 {state}")
        for label, st in (("內部", internal), ("外部", external)):
            if st in BAD:
                why.append(f"{label}：{BAD[st]}")
        if why:
            suspects.append((ver, a.get("version"), plat, why, b["id"]))
        if show_groups:
            # /v1/builds/{id}/betaGroups 只允許 CREATE/DELETE，GET 會回 403
            # FORBIDDEN_ERROR。要讀就得從 betaGroups 這端反查。
            gs = api(cfg, f"/v1/betaGroups?filter[builds]={b['id']}&limit=200")["data"]
            names = [g["attributes"]["name"] for g in gs] or ["（未指派任何群組）"]
            print(f"{'':>9} └─ 群組：{'、'.join(names)}")

    print()
    if suspects:
        print("⚠️ 以下 build 在 TestFlight 清單裡看得到，但測試者裝不了：")
        for ver, bn, plat, why, bid in suspects:
            print(f"   • {ver} ({bn}) {plat}　{'；'.join(why)}")
            print(f"     build id = {bid}")
        print()
        print("   幽靈 build（PROCESSING_EXCEPTION／卡在 PROCESSING）：")
        print("     ASC → TestFlight → 該 build → 停止測試（Expire），把它擋在清單外。")
        print("   READY_FOR_BETA_SUBMISSION：外部測試群組要先送 Beta App Review。")
    else:
        print("✅ 每顆 build 的狀態都正常。若測試者仍裝不了，"
              "問題在群組指派或測試者本身的帳號。")


if __name__ == "__main__":
    main()
