#!/usr/bin/env bash
#
# scripts/release.sh
# 一鍵發版：升版本號 → Apple 打包並上傳 ASC → Android 打包 AAB/APK → 建立發版 commit。
#
# 用法：
#   ./scripts/release.sh                  # patch 升版（2.8.0 -> 2.8.1），bundle +1
#   ./scripts/release.sh minor            # 2.8.0 -> 2.9.0
#   ./scripts/release.sh major
#   ./scripts/release.sh 2.9.0 25         # 指定版本號與 bundle 號
#   ./scripts/release.sh minor --dry-run  # 只驗證不上傳、Android 不簽章
#   ./scripts/release.sh minor --ios-only # 跳過 Android
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=0
SKIP_ANDROID=0
BUMP_ARGS=()

for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY_RUN=1 ;;
        --ios-only)  SKIP_ANDROID=1 ;;
        -h|--help)
            sed -n '5,13p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        -*)
            echo "❌ 未知參數：$arg" >&2
            exit 2
            ;;
        *)  BUMP_ARGS+=("$arg") ;;
    esac
done

step() { echo ""; echo "━━━ $* ━━━"; }

# 工作目錄必須乾淨。混著未提交的改動發版，事後根本分不清送出去的是哪個版本。
if [[ -n "$(git status --porcelain)" ]]; then
    echo "❌ 工作目錄有未提交的改動，發版中止：" >&2
    git status --short >&2
    exit 1
fi

step "1/5 升版本號"
BUMP_OUT="$("${SCRIPT_DIR}/bump-version.sh" "${BUMP_ARGS[@]:-patch}")"
echo "$BUMP_OUT"
NEW_VERSION="$(echo "$BUMP_OUT"  | sed -n 's/^NEW_VERSION=//p')"
NEW_BUNDLE="$(echo "$BUMP_OUT"   | sed -n 's/^NEW_BUNDLE_VERSION=//p')"

step "2/5 介面字串與版本一致性"
python3 "${SCRIPT_DIR}/i18n_tool.py" verify
"${SCRIPT_DIR}/check-version-consistency.sh"

step "3/5 Apple（iPhone / iPad / Mac）"
if [[ "$DRY_RUN" -eq 1 ]]; then
    "${SCRIPT_DIR}/apple-release.sh" --validate-only
else
    "${SCRIPT_DIR}/apple-release.sh"
fi

if [[ "$SKIP_ANDROID" -eq 0 ]]; then
    step "4/5 Android"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        "${SCRIPT_DIR}/android-release.sh" --unsigned
    else
        "${SCRIPT_DIR}/android-release.sh"
    fi
else
    step "4/5 Android（--ios-only，略過）"
fi

step "5/5 發版 commit"
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "   --dry-run：不建立 commit，版本號改動仍留在工作目錄。"
    echo "   要還原：git checkout -- ."
else
    # 訊息格式必須是 chore(release): bump version to vX.Y.Z ——
    # pre-push hook 認這個字串才會跳過自動升版，否則 push 時會再偷升一版，
    # repo 就跟剛送上去的 build 對不上了。
    git add -A
    git commit -q -m "chore(release): bump version to v${NEW_VERSION} (bundle ${NEW_BUNDLE})"
    git tag -f "v${NEW_VERSION}" >/dev/null
    echo "   ✅ 已建立 commit 與 tag v${NEW_VERSION}"
fi

cat <<NEXT

════════════════════════════════════════════
✅ v${NEW_VERSION} (bundle ${NEW_BUNDLE}) 完成
════════════════════════════════════════════

接下來要人做的：
  git push origin main --tags
  Play Console → 內部測試 → 上傳 android/app/build/outputs/bundle/release/app-release.aab
  App Store Connect → 等建置版本處理完 → 加入測試群組
NEXT
