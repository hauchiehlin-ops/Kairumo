#!/usr/bin/env python3
"""UI 測試之前先把剛抹掉的模擬器「預熱」一次（畫面稽核閘門用）。

# 為什麼需要

CI 每次都 `simctl erase` 再冷開機。這樣的模擬器在**第一次啟動 App** 之後一兩分鐘內，
模擬器的繪製伺服器 `backboardd` 會在 Metal 建表面時中止
（`MTLTextureDescriptor has invalid pixelFormat (0)`，崩在 MTLSimDriver 裡），
SpringBoard 跟著重啟，正在跑的 App 與 XCUITest 執行器一起被殺掉。測試看到的是
`Application … is not running` / `Test crashed with signal kill`，紅的永遠是字母序第一條
（InsertToolsAudit/testEveryInsertToolOpensSomething），其他全綠。

這不是 App 的問題：改動前後的版本在全新模擬器上都會觸發一次，崩過一次之後同一台
模擬器就穩定了（同一份程式碼在開機一陣子的模擬器上整組通過）。所以在跑測試**之前**
自己先啟動一次，等那次重啟過去、SpringBoard 穩定下來，再把 App 移除，讓測試從乾淨的
狀態開始。

# 判斷「穩定」

看模擬器裡 SpringBoard 的 PID：換過一次（重啟了）之後連續 `--settle` 秒不變就算穩定；
一直沒換的話等到 `--timeout` 為止（有的機器不會崩，那就只是多等一下）。
預熱本身出任何狀況都只警告、不讓閘門變紅 —— 預熱是為了減少誤紅，不能自己變成誤紅的來源。

用法：
    python3 scripts/warm-ios-simulator.py <udid> <Kairumo.app 路徑>
"""

import argparse
import os
import plistlib
import subprocess
import sys
import time
from pathlib import Path


def simctl(*args: str, env_extra: dict | None = None, check: bool = False) -> subprocess.CompletedProcess:
    env = dict(os.environ)
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        ["xcrun", "simctl", *args], capture_output=True, text=True, env=env, check=check
    )


def springboard_pid(udid: str) -> str | None:
    out = simctl("spawn", udid, "launchctl", "list").stdout
    for line in out.splitlines():
        parts = line.split()
        if len(parts) == 3 and parts[2] == "com.apple.SpringBoard":
            return parts[0] if parts[0] != "-" else None
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("udid")
    parser.add_argument("app", type=Path)
    parser.add_argument("--timeout", type=int, default=180, help="最多等幾秒")
    parser.add_argument("--settle", type=int, default=20, help="重啟後要穩定幾秒")
    args = parser.parse_args()

    if not args.app.is_dir():
        print(f"⚠️ 預熱略過：找不到 {args.app}")
        return 0
    with open(args.app / "Info.plist", "rb") as f:
        bundle_id = plistlib.load(f)["CFBundleIdentifier"]

    simctl("bootstatus", args.udid, "-b")
    if simctl("install", args.udid, str(args.app)).returncode != 0:
        print("⚠️ 預熱略過：安裝失敗")
        return 0
    # 與 UI 測試同一個環境變數：走的是測試會走的那條啟動路徑。
    launched = simctl(
        "launch", args.udid, bundle_id, env_extra={"SIMCTL_CHILD_KAIRUMO_UITEST": "1"}
    )
    if launched.returncode != 0:
        print(f"⚠️ 預熱：App 沒有啟動起來（{launched.stderr.strip()}），照常跑測試")

    start = time.monotonic()
    first = springboard_pid(args.udid)
    last = first
    stable_since = start
    restarted = False
    while time.monotonic() - start < args.timeout:
        time.sleep(3)
        pid = springboard_pid(args.udid)
        if pid != last:
            restarted = restarted or (last is not None)
            print(f"SpringBoard {last} → {pid}（第 {time.monotonic() - start:.0f} 秒）")
            last = pid
            stable_since = time.monotonic()
        elif restarted and pid and time.monotonic() - stable_since >= args.settle:
            break

    elapsed = time.monotonic() - start
    if restarted:
        print(f"✅ 模擬器重啟過一次，已穩定（共 {elapsed:.0f} 秒）")
    else:
        print(f"✅ {elapsed:.0f} 秒內沒有重啟，照常跑測試")

    # 移除 App（連同資料容器）：測試要從乾淨的狀態開始，種子筆記本由測試自己的那次啟動建立。
    simctl("terminate", args.udid, bundle_id)
    simctl("uninstall", args.udid, bundle_id)
    return 0


if __name__ == "__main__":
    sys.exit(main())
