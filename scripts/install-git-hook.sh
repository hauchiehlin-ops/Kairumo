#!/usr/bin/env bash
#
# scripts/install-git-hook.sh
# 安裝 Git pre-push hook，使每次執行 `git push` 時自動更新版本號（預設 patch）
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOOK_FILE="${REPO_ROOT}/.git/hooks/pre-push"

cat << 'HOOK_EOF' > "$HOOK_FILE"
#!/usr/bin/env bash
#
# Padnote 自動版本更新 pre-push hook
# 若欲跳過本次自動升版，可使用：PADNOTE_NO_BUMP=1 git push
#

if [[ "${PADNOTE_NO_BUMP:-0}" == "1" ]]; then
    exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
LAST_COMMIT_MSG="$(git log -1 --pretty=%B 2>/dev/null || echo '')"

# 若最新的 commit 已經是版本升級提交，避免重複觸發
if [[ "$LAST_COMMIT_MSG" =~ ^chore\(release\):\ bump\ version\ to\ v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    exit 0
fi

echo "🔔 [pre-push hook] 偵測到推送操作，正在自動更新版本（預設 patch）..."

BUMP_SCRIPT="${REPO_ROOT}/scripts/bump-version.sh"
if [[ -f "$BUMP_SCRIPT" ]]; then
    OUTPUT=$("$BUMP_SCRIPT" patch)
    echo "$OUTPUT"
    NEW_VERSION=$(echo "$OUTPUT" | grep '^NEW_VERSION=' | cut -d'=' -f2)

    if [[ -n "$NEW_VERSION" ]]; then
        # Apple 專案檔也必須一起提交 —— 只 commit Cargo 檔的話，
        # 被改掉的 MARKETING_VERSION / CURRENT_PROJECT_VERSION 會留在工作目錄裡，
        # 下一次發版就會出現「Cargo 與 Apple 版本不一致」的漂移。
        git add "${REPO_ROOT}/Cargo.toml" "${REPO_ROOT}/Cargo.lock" \
                "${REPO_ROOT}/apple/project.yml" \
                "${REPO_ROOT}/apple/Kairumo.xcodeproj/project.pbxproj"
        git commit -m "chore(release): bump version to v${NEW_VERSION}"
        TAG_NAME="v${NEW_VERSION}"
        if ! git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
            git tag -a "$TAG_NAME" -m "Release $TAG_NAME"
            echo "🏷️ 自動建立標籤：$TAG_NAME"
        fi
        echo "✅ 版本更新完成，繼續執行推送..."
    fi
fi

exit 0
HOOK_EOF

chmod +x "$HOOK_FILE"
echo "✅ Git pre-push hook 安裝成功！"
echo "👉 現在只要執行 'git push' 或 './scripts/push.sh'，都會自動更新 patch 版本並推送到 GitHub。"
