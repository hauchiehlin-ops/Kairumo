#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scripts/build-privacy-docs.py
------------------------------
由 docs/legal/privacy.html 產生：
  docs/legal/privacy-apple.html    — iOS · iPadOS · macOS
  docs/legal/privacy-android.html  — Android

# 為什麼要有這支腳本

在此之前這三份是**手動維持的三份副本**，429 行裡只有 6 行不一樣
（頁首的「適用平台」）。一份文件抄成三份、改的時候要記得三份都改 ——
那是這個專案一路在修的同一個形狀，而隱私權政策漂掉的代價比程式碼更高：
使用者讀到的可能是一份描述著舊行為的法律文件。

現在只維護 `privacy.html`，另外兩份由這支腳本產生。

執行：python3 scripts/build-privacy-docs.py
驗證：加 --check，內容不一致就以非零結束（CI 用這條）。
"""

import os
import re
import sys

REPO = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(REPO, "docs/legal/privacy.html")
DEST = {
    "apple": os.path.join(REPO, "docs/legal/privacy-apple.html"),
    "android": os.path.join(REPO, "docs/legal/privacy-android.html"),
}

# 頁首「適用平台」的前綴，逐語系。鍵是 privacy.html 裡 appver 的原文開頭，
# 值是 (Apple 前綴, Android 前綴)。
#
# 用「前綴 + 原文」而不是整句改寫：版本號只寫在 privacy.html 一處，
# 版本一升這裡不必跟著改。之前手冊的產生器就是因為把版本號寫進比對字串，
# 版本一升改寫就靜默失效（見 build-platform-docs.py 的說明）。
PREFIX = {
    "適用版本": ("適用平台：iOS · iPadOS · macOS | ", "適用平台：Android | "),
    "Applies to": ("Platform: iOS · iPadOS · macOS | ", "Platform: Android | "),
    "适用版本": ("适用平台：iOS · iPadOS · macOS | ", "适用平台：Android | "),
    "対象バージョン": ("対象プラットフォーム：iOS · iPadOS · macOS | ", "対象プラットフォーム：Android | "),
    "적용 버전": ("적용 플랫폼: iOS · iPadOS · macOS | ", "적용 플랫폼: Android | "),
    "ใช้กับเวอร์ชัน": ("แพลตฟอร์ม: iOS · iPadOS · macOS | ", "แพลตฟอร์ม: Android | "),
}

APPVER = re.compile(r'(appver:\s*")([^"]+)(")')


def build(src: str, which: str) -> str:
    idx = 0 if which == "apple" else 1

    def patch(m):
        body = m.group(2)
        for key, prefixes in PREFIX.items():
            if body.startswith(key):
                return m.group(1) + prefixes[idx] + body + m.group(3)
        return m.group(0)

    out = APPVER.sub(patch, src)
    if out == src:
        sys.exit(f"❌ {which}：一個 appver 都沒有改到，PREFIX 對照表可能過期了")
    return out


def main() -> int:
    check = "--check" in sys.argv
    src = open(SRC, encoding="utf-8").read()
    stale = []

    for which, path in DEST.items():
        want = build(src, which)
        have = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
        if have == want:
            continue
        if check:
            stale.append(os.path.relpath(path, REPO))
        else:
            open(path, "w", encoding="utf-8").write(want)
            print(f"✅ 已產生 {os.path.relpath(path, REPO)}")

    if stale:
        print("❌ 這幾份與 privacy.html 不一致：" + "、".join(stale), file=sys.stderr)
        print("   隱私權政策只維護 docs/legal/privacy.html，", file=sys.stderr)
        print("   另外兩份請跑 python3 scripts/build-privacy-docs.py 重新產生。", file=sys.stderr)
        return 1

    print("✅ 三份隱私權政策一致")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
