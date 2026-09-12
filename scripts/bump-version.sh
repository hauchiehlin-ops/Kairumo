#!/usr/bin/env bash
#
# scripts/bump-version.sh
# 自動更新版本號（預設為 patch）
#
# 用法：
#   ./scripts/bump-version.sh [patch|minor|major|<specific-version>]
#
# 範例：
#   ./scripts/bump-version.sh        # 0.1.0 -> 0.1.1
#   ./scripts/bump-version.sh minor  # 0.1.0 -> 0.2.0
#   ./scripts/bump-version.sh major  # 0.1.0 -> 1.0.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CARGO_TOML="${REPO_ROOT}/Cargo.toml"

BUMP_TYPE="${1:-patch}"

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

# 2. 計算新版本號
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
            echo "❌ 不支援的版本更新類型：'$BUMP_TYPE'。請使用 patch、minor、major 或直接指定版號（如 0.2.0）。" >&2
            exit 1
        fi
        ;;
esac

echo "📦 版本升級：v$CURRENT_VERSION -> v$NEW_VERSION ($BUMP_TYPE)"

# 3. 更新 Cargo.toml
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

# 4. 同步更新 Cargo.lock
echo "🔄 同步 Cargo.lock..."
(cd "$REPO_ROOT" && cargo check --workspace --quiet 2>/dev/null || true)

echo "CURRENT_VERSION=$CURRENT_VERSION"
echo "NEW_VERSION=$NEW_VERSION"
