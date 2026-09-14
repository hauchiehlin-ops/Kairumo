#!/usr/bin/env bash
#
# scripts/check-version-consistency.sh
# 發版前的版本一致性閘門，Apple 與 Android 兩條發布線共用。
#
# 為什麼要有這支：
# v2.8.0 那次只有 Cargo.toml 被升到 2.8.0，Apple 專案檔還停在 2.7.0 / bundle 20。
# apple-release.sh 的版本來源是拆開的（marketing 讀 Cargo.toml、build 號讀 pbxproj），
# 於是送出了 2.8.0 (20) —— build 號與已上架的 2.7.0 重複，TestFlight 列得出來卻裝不起來。
# 當時 android-release.sh 有這道檢查、apple-release.sh 沒有，壞 build 就這樣送上去了。
# 邏輯集中在這裡，兩邊各抄一份的話，遲早又是同一種漂移。
#
# 用法：./scripts/check-version-consistency.sh
# 一致則印出版本並回傳 0；不一致印出各來源的值並回傳 1。

set -euo pipefail

# 腳本輸出含中文。使用者的終端機若不是 UTF-8 locale，內嵌 python3 印中文會
# UnicodeEncodeError 直接中止（實際踩過）。強制輸出編碼，與終端機 locale 脫鉤。
export PYTHONIOENCODING=utf-8

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$REPO_ROOT" <<'PY'
import re, sys, pathlib

root = pathlib.Path(sys.argv[1])

def read(p):
    f = root / p
    return f.read_text(encoding="utf-8") if f.is_file() else ""

versions, bundles = {}, {}

m = re.search(r"\[workspace\.package\][\s\S]*?version\s*=\s*\"([^\"]+)\"", read("Cargo.toml"))
if m: versions["Cargo.toml"] = m.group(1)

yml = read("apple/project.yml")
m = re.search(r"MARKETING_VERSION:\s*\"?([0-9.]+)\"?", yml)
if m: versions["apple/project.yml"] = m.group(1)
m = re.search(r"CURRENT_PROJECT_VERSION:\s*\"?(\d+)\"?", yml)
if m: bundles["apple/project.yml"] = m.group(1)

# pbxproj 是 xcodebuild 真正讀的那份。project.yml 對了但忘了重跑 xcodegen
# 的話，只看 yml 會以為沒事 —— 這兩個必須分開檢查。
pbx = read("apple/Kairumo.xcodeproj/project.pbxproj")
m = re.search(r"MARKETING_VERSION\s*=\s*([0-9.]+)\s*;", pbx)
if m: versions["project.pbxproj"] = m.group(1).rstrip(".")
m = re.search(r"CURRENT_PROJECT_VERSION\s*=\s*(\d+)\s*;", pbx)
if m: bundles["project.pbxproj"] = m.group(1)

g = read("android/app/build.gradle.kts")
m = re.search(r"versionName\s*=\s*\"([0-9.]+)\"", g)
if m: versions["android/app/build.gradle.kts"] = m.group(1)
m = re.search(r"versionCode\s*=\s*(\d+)", g)
if m: bundles["android/app/build.gradle.kts"] = m.group(1)

for doc in ("docs/manual/manual.js", "docs/legal/privacy.html"):
    for line in read(doc).splitlines():
        if re.search(r"\b(version|appver)\s*:", line):
            for v in re.findall(r"\d+\.\d+\.\d+", line):
                versions.setdefault(doc, v)

if not versions or not bundles:
    print("❌ 讀不到版本號來源，請確認在 repo 根目錄執行。", file=sys.stderr)
    sys.exit(1)

if len(set(versions.values())) > 1 or len(set(bundles.values())) > 1:
    print("❌ 版本不一致，發版中止：", file=sys.stderr)
    for k, v in sorted(versions.items()):
        print(f"     版本  {v:<10} {k}", file=sys.stderr)
    for k, v in sorted(bundles.items()):
        print(f"     build {v:<10} {k}", file=sys.stderr)
    print("   請先跑 ./scripts/bump-version.sh 對齊後再發版。", file=sys.stderr)
    sys.exit(1)

print(f"   ✅ 版本 v{next(iter(versions.values()))}　build {next(iter(bundles.values()))}（{len(versions)} 處來源一致）")
PY
