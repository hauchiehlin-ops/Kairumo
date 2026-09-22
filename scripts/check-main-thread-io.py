#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""擋掉會在主執行緒上打 syscall 的路徑組法。

`URL.appendingPathComponent(_:)`（不帶 `isDirectory:` 的那個多載）的
`directoryHint` 預設是 `.checkFileSystem` —— **每呼叫一次就 lstat 一次**。
在 iCloud／檔案提供者撐起來的目錄上，那一次 lstat 可能要等一輪 IPC。

實機上踩到的樣子：v4.8.2 build 60，iPhone 17，按下雲端同步之後
scene-update 看門狗 10 秒到期，SIGKILL 0x8BADF00D，主執行緒的堆疊頂端
就停在 `lstat` ← `_SwiftURL.isDirectory(_:)` ← `URL.appendingPathComponent`。

`appending(path:)` 預設 `.inferFromPath`，只看字串，不碰檔案系統。
帶 `isDirectory:` 的舊多載也不碰，所以一併放行。

Android 沒有這個問題：`File(parent, child)` 與 `Path.resolve` 都是純字串運算。
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
# 測試跑在自己的暫存目錄上，那一次 lstat 不痛，也不值得為它製造改動。
SCAN = [ROOT / "apple" / "Sources"]
# NSString 的同名方法是純字串運算，不碰檔案系統 —— 只有 URL 的那個會 lstat。
BAD = re.compile(r"(?<!NSString\))\.appendingPathComponent\((?!\s*[^)]*isDirectory\s*:)")

hits = []
for root in SCAN:
    for path in sorted(root.rglob("*.swift")):
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if BAD.search(line):
                hits.append((path.relative_to(ROOT), lineno, line.strip()))

if hits:
    print("❌ 主執行緒上會 lstat 的路徑組法：")
    for rel, lineno, text in hits:
        print(f"   {rel}:{lineno}  {text}")
    print()
    print("   改用 .appending(path:)，或給 appendingPathComponent 一個 isDirectory: 參數。")
    sys.exit(1)

print("✅ apple/Sources 沒有會 lstat 的 appendingPathComponent")
