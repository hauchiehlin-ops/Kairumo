#!/usr/bin/env bash
#
# scripts/bump-version.sh
# 自動更新語意化版本號與 Bundle/Build 號
#
# 用法：
#   ./scripts/bump-version.sh [patch|minor|major|<specific-version>] [bundle-number]
#
# 範例：
#   ./scripts/bump-version.sh              # patch 升級 (1.0.0 -> 1.0.1)，bundle + 1
#   ./scripts/bump-version.sh minor        # minor 升級 (1.0.0 -> 1.1.0)，bundle + 1
#   ./scripts/bump-version.sh major        # major 升級 (1.0.0 -> 2.0.0)，bundle + 1
#   ./scripts/bump-version.sh minor 10     # minor 升級，並強制指定 bundle 號為 10
#

set -euo pipefail

# 腳本輸出含中文。使用者的終端機若不是 UTF-8 locale，內嵌 python3 印中文會
# UnicodeEncodeError 直接中止（實際踩過）。強制輸出編碼，與終端機 locale 脫鉤。
export PYTHONIOENCODING=utf-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CARGO_TOML="${REPO_ROOT}/Cargo.toml"
APPLE_PROJECT_YML="${REPO_ROOT}/apple/project.yml"
APPLE_PBXPROJ="${REPO_ROOT}/apple/Kairumo.xcodeproj/project.pbxproj"
ANDROID_GRADLE="${REPO_ROOT}/android/app/build.gradle.kts"
DOC_MANUAL="${REPO_ROOT}/docs/manual/manual.js"
DOC_PRIVACY="${REPO_ROOT}/docs/legal/privacy.html"

BUMP_TYPE="${1:-patch}"
EXPLICIT_BUNDLE="${2:-}"

if [[ ! -f "$CARGO_TOML" ]]; then
    echo "❌ 找不到 Cargo.toml：$CARGO_TOML" >&2
    exit 1
fi

# 1. 取得當前版本號與 Bundle 號
#
# 版本號的來源刻意取「所有來源的最大值」，而不是只信 Cargo.toml。
# 踩過的坑：v1.5.0 那次發版只改了 Apple 專案檔、沒動 Cargo.toml，
# 腳本下次再跑就會從 1.4.0 重新算，永遠追不上真實版本，tag 也停在 v1.4.0。
# 來源包含：Cargo.toml、apple/project.yml、project.pbxproj、android/app/build.gradle.kts、最新的 git tag。
VERSION_INFO=$(python3 -c '
import re, sys, os, subprocess

cargo, yml, pbx, gradle, repo_root = sys.argv[1:6]

def read(path):
    if not os.path.isfile(path):
        return ""
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

versions = []   # (版本元組, 來源說明)
bundles = []

cargo_text = read(cargo)
m = re.search(r"\[workspace\.package\][\s\S]*?version\s*=\s*\"([^\"]+)\"", cargo_text)
if m:
    versions.append((m.group(1), "Cargo.toml"))

yml_text = read(yml)
m = re.search(r"MARKETING_VERSION:\s*\"?([0-9]+\.[0-9]+\.[0-9]+)\"?", yml_text)
if m:
    versions.append((m.group(1), "apple/project.yml"))
m = re.search(r"CURRENT_PROJECT_VERSION:\s*\"?(\d+)\"?", yml_text)
if m:
    bundles.append(int(m.group(1)))

pbx_text = read(pbx)
m = re.search(r"MARKETING_VERSION\s*=\s*([0-9]+\.[0-9]+\.[0-9]+)", pbx_text)
if m:
    versions.append((m.group(1), "project.pbxproj"))
m = re.search(r"CURRENT_PROJECT_VERSION\s*=\s*(\d+);", pbx_text)
if m:
    bundles.append(int(m.group(1)))

gradle_text = read(gradle)
m = re.search(r"versionName\s*=\s*\"([0-9]+\.[0-9]+\.[0-9]+)\"", gradle_text)
if m:
    versions.append((m.group(1), "android/app/build.gradle.kts"))
m = re.search(r"versionCode\s*=\s*(\d+)", gradle_text)
if m:
    bundles.append(int(m.group(1)))

try:
    tags = subprocess.run(
        ["git", "-C", repo_root, "tag", "--list", "v[0-9]*"],
        capture_output=True, text=True, check=True,
    ).stdout.split()
    # 只取最新的一個 tag：把所有歷史 tag 都列進來，漂移訊息會長到看不出重點
    tag_versions = [
        (m.group(1), "git tag " + t)
        for t in tags
        if (m := re.fullmatch(r"v([0-9]+\.[0-9]+\.[0-9]+)", t))
    ]
    if tag_versions:
        versions.append(max(tag_versions, key=lambda i: tuple(int(x) for x in i[0].split("."))))
except Exception:
    pass

if not versions:
    sys.exit(1)

def key(item):
    return tuple(int(x) for x in item[0].split("."))

best = max(versions, key=key)
distinct = {v for v, _ in versions}

print("CURRENT=" + best[0])
print("SOURCE=" + best[1])
print("BUNDLE=" + str(max(bundles) if bundles else 1))
if len(distinct) > 1:
    detail = ", ".join(sorted({f"{v} ({src})" for v, src in versions}))
    print("DRIFT=" + detail)
' "$CARGO_TOML" "$APPLE_PROJECT_YML" "$APPLE_PBXPROJ" "$ANDROID_GRADLE" "$REPO_ROOT") || {
    echo "❌ 無法解析目前的版本號" >&2
    exit 1
}

CURRENT_VERSION=$(echo "$VERSION_INFO" | sed -n 's/^CURRENT=//p')
VERSION_SOURCE=$(echo "$VERSION_INFO" | sed -n 's/^SOURCE=//p')
CURRENT_BUNDLE_VERSION=$(echo "$VERSION_INFO" | sed -n 's/^BUNDLE=//p')
DRIFT_DETAIL=$(echo "$VERSION_INFO" | sed -n 's/^DRIFT=//p')

if [[ -z "$CURRENT_VERSION" ]]; then
    echo "❌ 無法解析目前的版本號" >&2
    exit 1
fi

if [[ -n "$DRIFT_DETAIL" ]]; then
    echo "⚠️ 各來源的版本號不一致：$DRIFT_DETAIL"
    echo "   以最大者 v${CURRENT_VERSION}（來自 ${VERSION_SOURCE}）為準，本次升級後會全部對齊。"
fi

# 3. 計算新版本號
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
PATCH="${PATCH%%-*}"
PATCH="${PATCH%%+*}"

case "$BUMP_TYPE" in
    patch)
        NEW_PATCH=$((PATCH + 1))
        NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"
        ;;
    minor)
        NEW_MINOR=$((MINOR + 1))
        NEW_VERSION="${MAJOR}.${NEW_MINOR}.0"
        ;;
    major)
        NEW_MAJOR=$((MAJOR + 1))
        NEW_VERSION="${NEW_MAJOR}.0.0"
        ;;
    *)
        if [[ "$BUMP_TYPE" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            NEW_VERSION="$BUMP_TYPE"
        else
            echo "❌ 不支援的版本更新類型：'$BUMP_TYPE'。請使用 patch、minor、major 或直接指定版號（如 1.1.0）。" >&2
            exit 1
        fi
        ;;
esac

# 4. 計算新 Bundle 號
#
# **build 號的唯一性是 Apple 那邊的狀態，不是 repo 裡的狀態。**
#
# 只看本機來源算下一個號碼，就會出現「本機以為 24、ASC 上早就有 24」——
# 實際發生過：build 24 被 3.2.0 / 2.10.1 / 2.10.0 三個版本用過，
# 22 被 3.0.0 與 2.9.0 用過。那是用不同指令、不同路徑打包造成的。
# 把 ASC 的最大值一起納入，號碼就只會單調遞增，撞號在結構上不可能發生。
#
# 沒有 API 金鑰時查詢回 0，等於只用本機來源 —— 少一層保護但仍然能用。
ASC_HIGHEST="$("${SCRIPT_DIR}/asc-latest-build.py" 2>/dev/null || echo 0)"
[[ "$ASC_HIGHEST" =~ ^[0-9]+$ ]] || ASC_HIGHEST=0

BASELINE_BUNDLE="$CURRENT_BUNDLE_VERSION"
if (( ASC_HIGHEST > BASELINE_BUNDLE )); then
    echo "ℹ️  ASC 上已有 build $ASC_HIGHEST，比本機的 $CURRENT_BUNDLE_VERSION 高 —— 以 ASC 為準。"
    BASELINE_BUNDLE="$ASC_HIGHEST"
fi

if [[ -n "$EXPLICIT_BUNDLE" ]]; then
    NEW_BUNDLE_VERSION="$EXPLICIT_BUNDLE"
    # 明確指定的號碼也要擋。手動指定一個已經用過的號碼，
    # 上傳會被 Apple 拒絕，而那時你已經等了十幾分鐘的打包。
    if (( ASC_HIGHEST > 0 && NEW_BUNDLE_VERSION <= ASC_HIGHEST )); then
        echo "❌ 指定的 build 號 $NEW_BUNDLE_VERSION 不大於 ASC 上已有的 $ASC_HIGHEST。" >&2
        echo "   上傳一定會被 Apple 拒收。請指定 $((ASC_HIGHEST + 1)) 或更大。" >&2
        exit 1
    fi
else
    NEW_BUNDLE_VERSION=$((BASELINE_BUNDLE + 1))
fi

echo "📦 版本與 Bundle 號升級："
echo "   版本號 (Marketing Version): v$CURRENT_VERSION -> v$NEW_VERSION ($BUMP_TYPE)"
echo "   Bundle 號 (Build Number):    $CURRENT_BUNDLE_VERSION -> $NEW_BUNDLE_VERSION"
if (( ASC_HIGHEST > 0 )); then
    echo "   （ASC 上最大為 $ASC_HIGHEST，新號碼已確保更高）"
fi

# 5. 更新 Cargo.toml
python3 -c '
import re, sys
cargo_file = sys.argv[1]
new_ver = sys.argv[2]
with open(cargo_file, "r", encoding="utf-8") as f:
    content = f.read()

def repl(m):
    return m.group(1) + f"version = \"{new_ver}\""

new_content = re.sub(
    r"(\[workspace\.package\][\s\S]*?)version\s*=\s*\"[^\"]+\"",
    repl,
    content,
    count=1
)

with open(cargo_file, "w", encoding="utf-8") as f:
    f.write(new_content)
' "$CARGO_TOML" "$NEW_VERSION"

# 6. 同步更新 Apple Xcode 專案 (project.pbxproj & project.yml)
python3 -c '
import re, sys, os

pbxproj_file = sys.argv[1]
yml_file = sys.argv[2]
new_ver = sys.argv[3]
new_bundle = sys.argv[4]

# 更新 project.pbxproj
if os.path.isfile(pbxproj_file):
    with open(pbxproj_file, "r", encoding="utf-8") as f:
        pbx = f.read()

    pbx = re.sub(r"(MARKETING_VERSION\s*=\s*)[^;]+;", r"\g<1>" + new_ver + ";", pbx)
    pbx = re.sub(r"(INFOPLIST_KEY_CFBundleShortVersionString\s*=\s*)[^;]+;", r"\g<1>" + new_ver + ";", pbx)
    pbx = re.sub(r"(CURRENT_PROJECT_VERSION\s*=\s*)[^;]+;", r"\g<1>" + new_bundle + ";", pbx)
    pbx = re.sub(r"(INFOPLIST_KEY_CFBundleVersion\s*=\s*)[^;]+;", r"\g<1>" + new_bundle + ";", pbx)

    with open(pbxproj_file, "w", encoding="utf-8") as f:
        f.write(pbx)

# 更新 project.yml
if os.path.isfile(yml_file):
    with open(yml_file, "r", encoding="utf-8") as f:
        yml = f.read()

    def replace_val(pattern, val, text):
        return re.sub(pattern, lambda m: m.group(1) + "\"" + val + "\"", text)

    yml = replace_val(r"(MARKETING_VERSION:\s*)\"[^\"]*\"", new_ver, yml)
    yml = replace_val(r"(INFOPLIST_KEY_CFBundleShortVersionString:\s*)\"[^\"]*\"", new_ver, yml)
    yml = replace_val(r"(CURRENT_PROJECT_VERSION:\s*)\"[^\"]*\"", new_bundle, yml)
    yml = replace_val(r"(INFOPLIST_KEY_CFBundleVersion:\s*)\"[^\"]*\"", new_bundle, yml)

    with open(yml_file, "w", encoding="utf-8") as f:
        f.write(yml)
' "$APPLE_PBXPROJ" "$APPLE_PROJECT_YML" "$NEW_VERSION" "$NEW_BUNDLE_VERSION"

# 6.2 同步更新 Android（Gradle）
#
# Android 一開始沒被納進來 —— 那正是當年 Apple 版漂移到 1.4.0 的同一個坑，
# 差別只在平台。新增平台就要同時進這支腳本。
python3 -c '
import re, sys, os
gradle_file, new_ver, new_bundle = sys.argv[1], sys.argv[2], sys.argv[3]
if os.path.isfile(gradle_file):
    with open(gradle_file, "r", encoding="utf-8") as f:
        t = f.read()
    t = re.sub(r"(versionName\s*=\s*)\"[^\"]*\"", lambda m: m.group(1) + "\"" + new_ver + "\"", t)
    t = re.sub(r"(versionCode\s*=\s*)\d+", lambda m: m.group(1) + new_bundle, t)
    with open(gradle_file, "w", encoding="utf-8") as f:
        f.write(t)
' "$ANDROID_GRADLE" "$NEW_VERSION" "$NEW_BUNDLE_VERSION"

# 6.3 同步更新使用者看得到的文件
#
# 手冊與隱私權政策上都印著「適用版本」。沒被納進來的後果已經發生過：
# 英文版停在 2.1.1、其他語言停在 2.3.0，而程式是 2.3.4 —— 使用者拿到的
# 說明書標示的版本跟手上的 App 對不起來。
python3 -c '
import re, sys, os
manual, privacy, new_ver, new_bundle = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

def bump(path):
    if not os.path.isfile(path):
        return
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    out = []
    for line in lines:
        # 只動「適用版本」那幾行與行文中明確寫出的 "Kairumo vX.Y.Z" 範例，
        # 不要全檔盲目替換數字 —— 文件裡還有日期、尺寸、快捷鍵之類的數字。
        if re.search(r"\b(version|appver)\s*:", line):
            line = re.sub(r"\d+\.\d+\.\d+", new_ver, line)
            line = re.sub(r"(bundle\s*)\d+", r"\g<1>" + new_bundle, line)
        line = re.sub(r"(Kairumo\s+v)\d+\.\d+\.\d+", r"\g<1>" + new_ver, line)
        out.append(line)
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(out)

bump(manual)
bump(privacy)
' "$DOC_MANUAL" "$DOC_PRIVACY" "$NEW_VERSION" "$NEW_BUNDLE_VERSION"

# 6.5 寫入後驗證：確認每個檔案都真的帶上新版本號。
# 沒有這一步的話，任何一個正則沒對上都會靜默跳過，接著又是一次版本漂移。
python3 -c '
import re, sys, os

cargo, yml, pbx, gradle, manual, privacy, new_ver, new_bundle = sys.argv[1:9]
problems = []

def read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

m = re.search(r"\[workspace\.package\][\s\S]*?version\s*=\s*\"([^\"]+)\"", read(cargo))
if not m or m.group(1) != new_ver:
    problems.append(f"Cargo.toml 的 workspace 版本沒有更新成 {new_ver}")

if os.path.isfile(yml):
    t = read(yml)
    for key in ("MARKETING_VERSION", "INFOPLIST_KEY_CFBundleShortVersionString"):
        m = re.search(key + r":\s*\"?([0-9]+\.[0-9]+\.[0-9]+)\"?", t)
        if not m or m.group(1) != new_ver:
            problems.append(f"project.yml 的 {key} 沒有更新成 {new_ver}")
    for key in ("CURRENT_PROJECT_VERSION", "INFOPLIST_KEY_CFBundleVersion"):
        m = re.search(key + r":\s*\"?(\d+)\"?", t)
        if not m or m.group(1) != new_bundle:
            problems.append(f"project.yml 的 {key} 沒有更新成 {new_bundle}")

if os.path.isfile(pbx):
    t = read(pbx)
    for key in ("MARKETING_VERSION", "INFOPLIST_KEY_CFBundleShortVersionString"):
        if not re.search(key + r"\s*=\s*" + re.escape(new_ver) + r"\s*;", t):
            problems.append(f"project.pbxproj 的 {key} 沒有更新成 {new_ver}")
    for key in ("CURRENT_PROJECT_VERSION", "INFOPLIST_KEY_CFBundleVersion"):
        if not re.search(key + r"\s*=\s*" + re.escape(new_bundle) + r"\s*;", t):
            problems.append(f"project.pbxproj 的 {key} 沒有更新成 {new_bundle}")

if os.path.isfile(gradle):
    t = read(gradle)
    m = re.search(r"versionName\s*=\s*\"([0-9]+\.[0-9]+\.[0-9]+)\"", t)
    if not m or m.group(1) != new_ver:
        problems.append(f"android/app/build.gradle.kts 的 versionName 沒有更新成 {new_ver}")
    m = re.search(r"versionCode\s*=\s*(\d+)", t)
    if not m or m.group(1) != new_bundle:
        problems.append(f"android/app/build.gradle.kts 的 versionCode 沒有更新成 {new_bundle}")

for doc, label in ((manual, "docs/manual/manual.js"), (privacy, "docs/legal/privacy.html")):
    if not os.path.isfile(doc):
        continue
    text = read(doc)
    stale = set()
    for line in text.splitlines():
        if re.search(r"\b(version|appver)\s*:", line):
            stale.update(v for v in re.findall(r"\d+\.\d+\.\d+", line) if v != new_ver)
    if stale:
        problems.append(f"{label} 還有沒更新的版本號：{sorted(stale)}")

if problems:
    for p in problems:
        print("❌ " + p, file=sys.stderr)
    sys.exit(1)
print("✅ 版本號已在 Cargo.toml / project.yml / project.pbxproj / build.gradle.kts / 使用者文件 全數對齊")
' "$CARGO_TOML" "$APPLE_PROJECT_YML" "$APPLE_PBXPROJ" "$ANDROID_GRADLE" "$DOC_MANUAL" "$DOC_PRIVACY" "$NEW_VERSION" "$NEW_BUNDLE_VERSION"

# 7. 同步更新 Cargo.lock
echo "🔄 同步 Cargo.lock..."
(cd "$REPO_ROOT" && cargo check --workspace --quiet 2>/dev/null || true)

echo "CURRENT_VERSION=$CURRENT_VERSION"
echo "NEW_VERSION=$NEW_VERSION"
echo "CURRENT_BUNDLE_VERSION=$CURRENT_BUNDLE_VERSION"
echo "NEW_BUNDLE_VERSION=$NEW_BUNDLE_VERSION"

