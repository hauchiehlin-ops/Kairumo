#!/usr/bin/env bash
#
# scripts/push.sh
# 自動更新版本（預設 patch）並推送到 GitHub
#
# 用法：
#   ./scripts/push.sh                        # 預設 patch 升級，自動建立 commit 與 tag 並 push
#   ./scripts/push.sh minor                  # minor 升級並 push
#   ./scripts/push.sh major                  # major 升級並 push
#   ./scripts/push.sh patch "feat: 新功能"    # 附帶自訂 commit 訊息

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BUMP_TYPE="patch"
CUSTOM_MSG=""

# 參數解析
if [[ $# -ge 1 ]]; then
    case "$1" in
        patch|minor|major)
            BUMP_TYPE="$1"
            shift
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
                BUMP_TYPE="$1"
                shift
            else
                # 如果第一個參數不是 patch/minor/major/版本號，當作 commit message
                CUSTOM_MSG="$1"
                shift
            fi
            ;;
    esac
fi

BUNDLE_ARG=""
if [[ $# -ge 1 ]]; then
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        BUNDLE_ARG="$1"
        shift
    fi
fi

if [[ $# -ge 1 && -z "$CUSTOM_MSG" ]]; then
    CUSTOM_MSG="$1"
fi

cd "$REPO_ROOT"

# 1. 取得當前分支與 remote
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
REMOTE_NAME=$(git config branch."${CURRENT_BRANCH}".remote || echo "origin")

echo "=================================================="
echo "🚀 準備更新版本並推送到 GitHub ($REMOTE_NAME/$CURRENT_BRANCH)"
echo "=================================================="

# 2. 執行版本升級（預設 patch）
OUTPUT=$("${SCRIPT_DIR}/bump-version.sh" "$BUMP_TYPE" "$BUNDLE_ARG")
echo "$OUTPUT"

NEW_VERSION=$(echo "$OUTPUT" | grep '^NEW_VERSION=' | cut -d'=' -f2)
NEW_BUNDLE_VERSION=$(echo "$OUTPUT" | grep '^NEW_BUNDLE_VERSION=' | cut -d'=' -f2)

if [[ -z "$NEW_VERSION" ]]; then
    echo "❌ 無法取得新版本號" >&2
    exit 1
fi

# 3. 準備提交
git add -A

# 如果工作目錄有其他已修改的檔案，一併加入提交
if ! git diff --cached --quiet; then
    BUNDLE_INFO=""
    if [[ -n "$NEW_BUNDLE_VERSION" ]]; then
        BUNDLE_INFO=" (bundle ${NEW_BUNDLE_VERSION})"
    fi

    if [[ -n "$CUSTOM_MSG" ]]; then
        COMMIT_MSG="chore(release): bump version to v${NEW_VERSION}${BUNDLE_INFO} - ${CUSTOM_MSG}"
    else
        COMMIT_MSG="chore(release): bump version to v${NEW_VERSION}${BUNDLE_INFO}"
    fi

    echo "📝 建立提交：$COMMIT_MSG"
    git commit -m "$COMMIT_MSG"
else
    echo "ℹ️ 無版本變更需提交"
fi

# 4. 建立 Git Tag
TAG_NAME="v${NEW_VERSION}"
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo "⚠️ 標籤 $TAG_NAME 已存在，略過建立 tag"
else
    echo "🏷️ 建立標籤：$TAG_NAME"
    git tag -a "$TAG_NAME" -m "Release $TAG_NAME"
fi

# 5. 推送到遠端
echo "⬆️ 推送到遠端倉庫：$REMOTE_NAME $CURRENT_BRANCH (含標籤)..."
git push "$REMOTE_NAME" "$CURRENT_BRANCH" --follow-tags

echo "=================================================="
echo "✅ 成功完成！目前倉庫最新版本為：v${NEW_VERSION}"
echo "=================================================="
