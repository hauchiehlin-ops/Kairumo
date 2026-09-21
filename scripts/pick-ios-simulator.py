#!/usr/bin/env python3
"""挑一台可用的 iOS 模擬器，印出它的 udid（一致性閘門 2）。

# 為什麼不直接在 CI 裡寫 `name=iPhone 16`

Xcode 一升版，寫死的名字就找不到，閘門會因為**與程式碼無關**的理由變紅。
而一個會無故變紅的閘門，第三次紅的時候就會被關掉 ——
`scripts/check-screen-parity.py` 的說明裡已經寫過一次這個教訓。

# 為什麼回傳 udid 而不是名字

`-destination "platform=iOS Simulator,name=…"` 在同名裝置有多個 runtime
版本時會挑到哪一台並不明確；udid 是唯一的。

用法：
    xcodebuild test -destination "id=$(python3 scripts/pick-ios-simulator.py)" …
"""

import json
import subprocess
import sys


def main() -> int:
    out = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available", "-j"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    devices = json.loads(out)["devices"]

    best: tuple[str, str, str] | None = None
    for runtime, entries in devices.items():
        if "iOS" not in runtime:
            continue
        for d in entries:
            if not d.get("isAvailable") or "iPhone" not in d.get("name", ""):
                continue
            # runtime 字串長這樣：com.apple.CoreSimulator.SimRuntime.iOS-27-0
            # 字典序在同一個大版本系列裡與版本序一致，夠用來挑「比較新的那個」。
            if best is None or runtime > best[0]:
                best = (runtime, d["udid"], d["name"])

    if best is None:
        print("找不到任何可用的 iPhone 模擬器", file=sys.stderr)
        return 1

    print(best[1])
    print(f"挑到：{best[2]}（{best[0].rsplit('.', 1)[-1]}）", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
