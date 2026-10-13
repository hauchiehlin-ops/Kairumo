#!/usr/bin/env python3
"""多設定檔的「不准漏分類」門禁（Apple + Android）。

# 為什麼需要它

多設定檔的正確性靠一條紀律撐著：**每一份使用者狀態都必須經過設定檔層**。
只要有一個地方直接讀 `UserDefaults.standard`、直接用 `context.filesDir`、或是一個單例把
上一個使用者的資料留在記憶體裡，切換之後 B 就看得到 A 的東西 —— 而且單機、單使用者測試
**完全看不出來**。紀律靠人記不住，所以用腳本守。做法與 `check-hardcoded-strings.py` 相同：
新增一個沒分類的狀態，提交就被擋下，並且告訴你要加什麼。

# 規則

Apple（`apple/Sources/*.swift`，不含 `Profile*.swift` 與產生檔）：
  A1. 不可以直接用 `UserDefaults.standard` / `UserDefaults(suiteName:`。
      使用者偏好用 `ProfileDefaults.current`；整台裝置共用的用 `ProfileDefaults.device`。
  A2. `@AppStorage("…")` 不可以用字串字面值，要 `@AppStorage(ProfileContext.scopedKey("…"))`。
  A3. `.documentDirectory` / `.applicationSupportDirectory` 必須在前三行內有
      `// profile-scope: device|profile|default` 標記，說明它為什麼是對的。
  A4. 每個 `static let shared` 必須在前三行內標明 `// profile-scope: device` 或 `profile`。
      標 `profile` 的類別，同一個檔案裡必須有 `resetForProfileSwitch`（切換時重設它）。
  A5. 可變的 `static var`（全域快取）必須標明 `// profile-scope: device|profile`。
  A6. 不可以把 `ProfileDefaults.current` 存成屬性（它是值，切換之後仍指著舊的設定檔）。
  A7. `static let` 不可以在載入時就算定設定檔相關的位置（ProfileContext／libraryRootURL…）。

Android（`android/app/src/main/java/**/*.kt`，不含 `profile/` 與產生檔）：
  K1. 不可以直接呼叫 `getSharedPreferences(` —— 用 `ProfileContext.prefs` / `devicePrefs`
      （檔名已經自己套用設定檔的，前面加 `// profile-scope: profile 說明`）。
  K2. `filesDir` / `cacheDir` 必須在前三行內有 `// profile-scope:` 標記
      （使用者資料要改用 `ProfileContext.dataDir` / `cacheDir`）。
  K3. 持有可變狀態的 `object`（`MutableStateFlow`、`mutableStateOf`、`@Volatile`、`private var`、
      `mutableMapOf`、`LruCache`…）必須在前三行內標明 `// profile-scope: device` 或 `profile`；
      標 `profile` 的，同一個檔案裡必須有 `resetForProfileSwitch`。

標記格式：`// profile-scope: device` 或 `profile`（可附說明，例如 `// profile-scope: device 模型是整台裝置共用`）。

用法：`python3 scripts/check-profile-scope.py`（有違規時結束碼 1）。
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APPLE = ROOT / "apple" / "Sources"
ANDROID = ROOT / "android" / "app" / "src" / "main" / "java" / "com" / "kairumo" / "padnote"

# Apple 切換設定檔是**就地重設**（iOS 不能自己重啟 App），所以每個標成 profile 的單例都必須實作
# `resetForProfileSwitch`。Android 切換時整個行程重啟（見 `ProfileSwitcher`）—— 記憶體裡的東西全部
# 消失，不需要逐個重設，所以不要求。
REQUIRE_RESET_APPLE = True
REQUIRE_RESET_ANDROID = False

MARK = re.compile(r"profile-scope:\s*(device|profile|default)")
STATE_HINT = re.compile(
    r"MutableStateFlow\(|mutableStateOf\(|@Volatile|^\s*(?:private |internal )?var \w+|mutableMapOf|"
    r"mutableListOf|mutableSetOf|ConcurrentHashMap|LruCache|lateinit var ", re.M)


def has_mark(lines: list[str], index: int, window: int = 3) -> str | None:
    for i in range(max(0, index - window), index + 1):
        m = MARK.search(lines[i])
        if m:
            return m.group(1)
    return None


def code_part(line: str) -> str:
    """去掉行尾 // 註解（簡化版，字串裡的 // 不處理 —— 這個門禁寧可多報）。"""
    stripped = line.lstrip()
    if stripped.startswith("//") or stripped.startswith("*") or stripped.startswith("/*"):
        return ""
    return line


def check_apple(problems: list[str]) -> None:
    for path in sorted(APPLE.glob("*.swift")):
        name = path.name
        # `._*` 是 macOS 在 exFAT 上生出來的 AppleDouble 附屬檔，不是原始碼。
        if name.startswith("._") or name.startswith("Profile") or name.endswith(".generated.swift"):
            continue
        text = path.read_text(encoding="utf-8")
        lines = text.split("\n")
        for i, raw in enumerate(lines):
            line = code_part(raw)
            where = f"apple/Sources/{name}:{i + 1}"
            if "UserDefaults.standard" in line or "UserDefaults(suiteName" in line:
                problems.append(
                    f"{where}  A1 直接用了 UserDefaults —— 改用 ProfileDefaults.current（使用者偏好）"
                    "或 ProfileDefaults.device（整台裝置共用）")
            if re.search(r'@AppStorage\(\s*"', line):
                problems.append(f"{where}  A2 @AppStorage 的鍵是字串字面值 —— 改用 ProfileContext.scopedKey(\"…\")")
            if (".documentDirectory" in line or ".applicationSupportDirectory" in line) and not has_mark(lines, i):
                problems.append(
                    f"{where}  A3 直接取用 Documents／Application Support，沒有標記 —— "
                    "加 `// profile-scope: device|profile|default` 說明它屬於誰")
            # A5: 可變的 static（全域快取）。範例筆記的 id 在每個設定檔都一樣，以 id 為鍵的快取會串味。
            if re.search(r"static var \w+\s*(?::[^={]+)?(?:=|$)", line) and "{" not in line and not has_mark(lines, i):
                problems.append(
                    f"{where}  A5 全域可變狀態（static var）沒有分類 —— 加 `// profile-scope: device|profile 說明`；"
                    "profile 的要接進 ProfileManager.defaultExtraResets()")
            # A6: 把 ProfileDefaults.current 存成屬性 = 永遠指著建立當下的設定檔。
            if re.match(r"\s{4}(?:private |fileprivate |public |internal )*(?:let|var)\s+\w+\s*(?::[^=]+)?=\s*ProfileDefaults\.current", line):
                problems.append(
                    f"{where}  A6 把 ProfileDefaults.current 存成屬性 —— 它是值，切換設定檔之後仍指著舊的。"
                    "改成計算屬性：`private var defaults: ProfileDefaults { .current }`")
            # A7: 單例或型別常數在載入時就算定了「設定檔相關的位置」。
            if re.search(r"static let \w+[^=]*=.*(ProfileContext\.|libraryRootURL|corePackagesDirectory|documentsDirectory)", line):
                problems.append(
                    f"{where}  A7 static let 在載入時就算定了設定檔相關的位置 —— 改成計算屬性，每次取用才問現在是誰")
            if re.search(r"static let shared\b", line):
                mark = has_mark(lines, i)
                if mark is None:
                    problems.append(
                        f"{where}  A4 單例沒有分類 —— 在前面加 `// profile-scope: device` 或 `profile`")
                elif REQUIRE_RESET_APPLE and mark == "profile" and "resetForProfileSwitch" not in text:
                    problems.append(
                        f"{where}  A4 標成 profile 的單例必須實作 resetForProfileSwitch()（切換設定檔時重設）")


def check_android(problems: list[str]) -> None:
    for path in sorted(ANDROID.rglob("*.kt")):
        rel = path.relative_to(ANDROID)
        if path.name.startswith("._") or rel.parts[0] == "profile" or path.name in ("LocalizationStrings.kt", "CoreMessagePatterns.kt"):
            continue
        text = path.read_text(encoding="utf-8")
        lines = text.split("\n")
        where_base = f"android/.../padnote/{rel}"
        for i, raw in enumerate(lines):
            line = code_part(raw)
            where = f"{where_base}:{i + 1}"
            if "getSharedPreferences(" in line and not has_mark(lines, i):
                problems.append(
                    f"{where}  K1 直接呼叫 getSharedPreferences —— 改用 ProfileContext.prefs／devicePrefs")
            if re.search(r"(?<!ProfileContext\.)\b(filesDir|cacheDir)\b", line) and not has_mark(lines, i):
                problems.append(
                    f"{where}  K2 直接用 filesDir／cacheDir，沒有標記 —— 使用者資料改用 "
                    "ProfileContext.dataDir／cacheDir，裝置共用的加 `// profile-scope: device`")
            m = re.match(r"\s*(?:internal |private |public )?object\s+(\w+)", line)
            if m:
                # 只看 object **本體第一層**的成員：函式裡的區域變數（`val out = mutableListOf()`）不是單例狀態。
                state_lines = []
                depth = 0
                started = False
                for j in range(i, len(lines)):
                    text_j = code_part(lines[j])
                    if started and depth == 1 and STATE_HINT.search(text_j):
                        state_lines.append(j)
                    depth += text_j.count("{") - text_j.count("}")
                    if "{" in text_j:
                        started = True
                    if started and depth <= 0:
                        break
                if state_lines:
                    mark = has_mark(lines, i)
                    if mark is None:
                        problems.append(
                            f"{where}  K3 object {m.group(1)} 持有可變狀態卻沒有分類 —— "
                            "在前面加 `// profile-scope: device` 或 `profile`")
                    elif REQUIRE_RESET_ANDROID and mark == "profile" and "resetForProfileSwitch" not in text:
                        problems.append(
                            f"{where}  K3 標成 profile 的 object {m.group(1)} 必須實作 resetForProfileSwitch()")


def main() -> int:
    problems: list[str] = []
    check_apple(problems)
    check_android(problems)
    if problems:
        print(f"❌ 多設定檔分類：{len(problems)} 處沒有處理好\n")
        for p in problems:
            print("  " + p)
        print("\n這些狀態切換設定檔之後會漏給下一個使用者。說明見 scripts/check-profile-scope.py 檔頭。")
        return 1
    print("✅ 多設定檔分類：Apple 與 Android 都沒有漏分類的狀態")
    return 0


if __name__ == "__main__":
    sys.exit(main())
