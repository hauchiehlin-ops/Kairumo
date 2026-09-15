#!/usr/bin/env python3
"""
scripts/asc-latest-build.py
印出 App Store Connect 上**已經用過的最大 build 號**。

為什麼需要它：

build 號的唯一性是 Apple 那邊的狀態，不是 repo 裡的狀態。只看本機來源算
下一個號碼，就會發生「本機以為是 24、ASC 上早就有 24」——
實際發生過，而且不只一次：build 24 被 3.2.0 / 2.10.1 / 2.10.0 三個版本用過，
22 被 3.0.0 與 2.9.0 用過。那是有人用不同指令、不同路徑打包造成的。

用法：
    ./scripts/asc-latest-build.py            # 只印數字（沒設定憑證時印 0）
    ./scripts/asc-latest-build.py --verbose  # 連同各版本用過的號碼一起列出

沒有 API 金鑰時**回傳 0 而不是報錯** —— 這支工具是防線，不是必要條件。
沒有憑證的人仍然要能打包，只是少一層保護（呼叫端會自己提醒）。
"""
import sys
import importlib.util
from pathlib import Path

HERE = Path(__file__).resolve().parent


def _load_asc():
    spec = importlib.util.spec_from_file_location("asc", HERE / "asc-builds.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    verbose = "--verbose" in sys.argv
    try:
        asc = _load_asc()
        cfg = asc.load_config()
    except Exception as exc:  # noqa: BLE001 - 任何載入失敗都當成「查不到」
        if verbose:
            print(f"（無法載入 ASC 工具：{exc}）", file=sys.stderr)
        print(0)
        return 0

    missing = [
        k for k in ("APP_STORE_CONNECT_API_KEY_ID", "APP_STORE_CONNECT_ISSUER_ID",
                    "APP_STORE_CONNECT_KEY_PATH") if not cfg.get(k)
    ]
    if missing or not Path(cfg.get("APP_STORE_CONNECT_KEY_PATH", "")).exists():
        if verbose:
            print("（未設定 App Store Connect API 金鑰，跳過查詢）", file=sys.stderr)
        print(0)
        return 0

    bundle = cfg.get("BUNDLE_ID") or "com.kairumo.padnote"
    try:
        apps = asc.api(cfg, f"/v1/apps?filter[bundleId]={bundle}")["data"]
        if not apps:
            print(0)
            return 0
        data = asc.api(
            cfg,
            f"/v1/builds?filter[app]={apps[0]['id']}"
            "&limit=200&include=preReleaseVersion&sort=-uploadedDate",
        )
    except SystemExit:
        # asc.api 查詢失敗時會 sys.exit —— 對這支工具而言那只代表「查不到」。
        print(0)
        return 0

    included = {(i["type"], i["id"]): i for i in data.get("included", [])}
    highest = 0
    per_version: dict[str, set[int]] = {}
    for build in data["data"]:
        try:
            number = int(build["attributes"].get("version") or 0)
        except ValueError:
            continue
        highest = max(highest, number)
        rel = build.get("relationships", {}).get("preReleaseVersion", {}).get("data")
        pre = included.get(("preReleaseVersions", rel["id"])) if rel else None
        version = pre["attributes"]["version"] if pre else "?"
        per_version.setdefault(version, set()).add(number)

    if verbose:
        print(f"ASC 上最大的 build 號：{highest}", file=sys.stderr)
        reused = {v: sorted(n) for v, n in per_version.items() if len(n) > 1}
        for version in sorted(per_version):
            print(f"  {version:>8}  {sorted(per_version[version])}", file=sys.stderr)
        if reused:
            print("⚠️ 有版本用了多個 build 號 —— 那是過去混用不同打包指令的痕跡。",
                  file=sys.stderr)

    print(highest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
