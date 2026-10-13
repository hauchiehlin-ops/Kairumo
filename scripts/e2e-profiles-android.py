#!/usr/bin/env python3
"""Android 多設定檔的**端到端**測試（模擬器 / 實機，用 adb + uiautomator）。

單元測試驗得出規則與切換器的順序，驗不出「切換真的重啟了行程、重啟之後是另一個人、
上了鎖的使用者要先過 PIN」—— 那一層只有把 App 真的跑起來才看得到，而且切換會殺掉行程，
所以它沒辦法寫成一般的 instrumented 測試（測試本身就在那個行程裡）。

流程（每一步都檢查，失敗就非零結束）：
  1. 清空資料、裝上 APK、走完首次引導
  2. 首頁按「切換使用者」→ 新增使用者 Alex（設 PIN 2468）→ 行程**真的重啟**（pid 變了）
  3. 重啟後是 Alex 的全新環境（再次出現首次引導），而且**沒有重問 PIN**（剛在選單裡過關）
  4. 切回預設使用者 → 又一次重啟 → 首頁回到原本的名字
  5. 再切到 Alex：要先過 PIN；輸錯有訊息、不會切；輸對才切

用法：
    python3 scripts/e2e-profiles-android.py [--apk path/to/app-debug.apk]
需要一台連著的模擬器或裝置（`adb devices`）。
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ADB = [str(Path.home() / "Library/Android/sdk/platform-tools/adb")]
PKG = "com.kairumo.padnote"


def sh(*args: str) -> str:
    return subprocess.run(ADB + list(args), capture_output=True, text=True).stdout


def dump() -> ET.Element:
    sh("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    return ET.fromstring(sh("exec-out", "cat", "/sdcard/ui.xml"))


def find(root: ET.Element, rid: str | None = None, text: str | None = None):
    for n in root.iter("node"):
        if rid and n.get("resource-id") == rid:
            return n
        if text and text in (n.get("text") or n.get("content-desc") or ""):
            return n
    return None


def center(n: ET.Element) -> tuple[int, int]:
    x1, y1, x2, y2 = map(int, re.findall(r"\d+", n.get("bounds")))
    return (x1 + x2) // 2, (y1 + y2) // 2


def exists(rid=None, text=None, timeout=15) -> bool:
    end = time.time() + timeout
    while time.time() < end:
        if find(dump(), rid, text) is not None:
            return True
        time.sleep(1)
    return False


def tap(rid=None, text=None, timeout=15) -> None:
    end = time.time() + timeout
    while time.time() < end:
        n = find(dump(), rid, text)
        if n is not None:
            x, y = center(n)
            sh("shell", "input", "tap", str(x), str(y))
            return
        time.sleep(1)
    fail(f"找不到 {rid or text}")


def type_text(value: str) -> None:
    sh("shell", "input", "text", value.replace(" ", "%s"))
    sh("shell", "input", "keyevent", "4")  # 收鍵盤
    time.sleep(1)


def pid() -> str:
    return sh("shell", "pidof", PKG).strip()


def fail(message: str) -> None:
    print(f"❌ {message}")
    sys.exit(1)


def check(condition: bool, message: str) -> None:
    if not condition:
        fail(message)
    print(f"✅ {message}")


def onboard() -> None:
    time.sleep(4)
    if find(dump(), text="Continue") is not None:
        tap(text="Continue")
        time.sleep(2)
        for label in ("Don’t allow", "Don't allow"):
            if find(dump(), text=label) is not None:
                tap(text=label)
                break
    check(exists("home.profile.switch", timeout=40), "首頁出現「切換使用者」按鈕")


def wait_restart(old_pid: str) -> None:
    deadline = time.time() + 30
    while time.time() < deadline:
        now = pid()
        if now and now != old_pid:
            return
        time.sleep(1)
    fail("行程沒有重啟")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", default=None)
    args = parser.parse_args()
    if args.apk:
        sh("install", "-r", args.apk)
    sh("shell", "pm", "clear", PKG)
    sh("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    onboard()

    # ── 2. 新增使用者 Alex，設 PIN。
    before = pid()
    tap("home.profile.switch")
    check(exists("profile.picker", timeout=10), "切換選單出現")
    tap("profile.add")
    tap("profile.create.name")
    type_text("Alex")
    tap("profile.create.lock")
    tap("profile.create.pin")
    type_text("2468")
    tap("profile.create.pin2")
    type_text("2468")
    tap("profile.create.confirm")
    wait_restart(before)
    check(True, "切換時行程真的重啟了（pid 變了）")

    # ── 3. 重啟後是 Alex 的全新環境，而且沒有重問 PIN。
    time.sleep(6)
    check(not exists("profile.lock", timeout=5), "剛過關的使用者不會被再問一次 PIN")
    check(find(dump(), text="Welcome to Kairumo") is not None, "Alex 是全新的環境（出現首次引導）")
    onboard()
    check(exists(text="Alex", timeout=10), "首頁的身分是 Alex")

    # ── 4. 切回預設使用者。
    before = pid()
    tap("home.profile.switch")
    check(exists("profile.picker", timeout=10), "切換選單出現")
    tap("profile.row.default")
    wait_restart(before)
    onboard()
    check(exists(text="You", timeout=10), "切回預設使用者：首頁回到原本的名字")

    # ── 5. 再切到 Alex：要先過 PIN。
    tap("home.profile.switch")
    exists("profile.picker", timeout=10)
    other = [n.get("resource-id") for n in dump().iter("node")
             if (n.get("resource-id") or "").startswith("profile.row.") and n.get("resource-id") != "profile.row.default"]
    check(len(other) == 1, "選單裡有預設使用者與 Alex 兩列")
    tap(other[0])
    check(exists("profile.unlock.pin", timeout=10), "鎖住的使用者要求 PIN")
    before = pid()
    tap("profile.unlock.pin")
    type_text("1111")
    tap("profile.unlock.button")
    check(exists("profile.unlock.message", timeout=8), "輸錯 PIN 有訊息")
    check(pid() == before, "輸錯 PIN 沒有切換（行程沒重啟）")
    tap("profile.unlock.pin")
    type_text("2468")
    tap("profile.unlock.button")
    wait_restart(before)
    check(True, "輸對 PIN 才切換")
    print("🎉 Android 多設定檔端到端測試全部通過")


if __name__ == "__main__":
    main()
