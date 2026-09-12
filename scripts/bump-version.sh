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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CARGO_TOML="${REPO_ROOT}/Cargo.toml"
APPLE_PROJECT_YML="${REPO_ROOT}/apple/project.yml"
APPLE_PBXPROJ="${REPO_ROOT}/apple/Kairumo.xcodeproj/project.pbxproj"

BUMP_TYPE="${1:-patch}"
EXPLICIT_BUNDLE="${2:-}"

if [[ ! -f "$CARGO_TOML" ]]; then
    echo "❌ 找不到 Cargo.toml：$CARGO_TOML" >&2
    exit 1
fi

# 1. 取得當前版本號
CURRENT_VERSION=$(python3 -c '
import re, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    content = f.read()
match = re.search(r"\[workspace\.package\][\s\S]*?version\s*=\s*\"([^\"]+)\"", content)
if match:
    print(match.group(1))
else:
    sys.exit(1)
' "$CARGO_TOML")

if [[ -z "$CURRENT_VERSION" ]]; then
    echo "❌ 無法在 $CARGO_TOML 中解析到 [workspace.package] 的版本號" >&2
    exit 1
fi

# 2. 取得當前 Bundle / Build 號
CURRENT_BUNDLE_VERSION=$(python3 -c '
import re, sys, os
pbxproj = sys.argv[1]
project_yml = sys.argv[2]
bundle = None

if os.path.isfile(pbxproj):
    with open(pbxproj, "r", encoding="utf-8") as f:
        content = f.read()
    m = re.search(r"CURRENT_PROJECT_VERSION\s*=\s*(\d+);", content)
    if m:
        bundle = m.group(1)

if not bundle and os.path.isfile(project_yml):
    with open(project_yml, "r", encoding="utf-8") as f:
        content = f.read()
    m = re.search(r"CURRENT_PROJECT_VERSION:\s*\"?(\d+)\"?", content)
    if m:
        bundle = m.group(1)

print(bundle if bundle else "1")
' "$APPLE_PBXPROJ" "$APPLE_PROJECT_YML")

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
if [[ -n "$EXPLICIT_BUNDLE" ]]; then
    NEW_BUNDLE_VERSION="$EXPLICIT_BUNDLE"
else
    NEW_BUNDLE_VERSION=$((CURRENT_BUNDLE_VERSION + 1))
fi

echo "📦 版本與 Bundle 號升級："
echo "   版本號 (Marketing Version): v$CURRENT_VERSION -> v$NEW_VERSION ($BUMP_TYPE)"
echo "   Bundle 號 (Build Number):    $CURRENT_BUNDLE_VERSION -> $NEW_BUNDLE_VERSION"

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

# 7. 同步更新 Cargo.lock
echo "🔄 同步 Cargo.lock..."
(cd "$REPO_ROOT" && cargo check --workspace --quiet 2>/dev/null || true)

echo "CURRENT_VERSION=$CURRENT_VERSION"
echo "NEW_VERSION=$NEW_VERSION"
echo "CURRENT_BUNDLE_VERSION=$CURRENT_BUNDLE_VERSION"
echo "NEW_BUNDLE_VERSION=$NEW_BUNDLE_VERSION"

