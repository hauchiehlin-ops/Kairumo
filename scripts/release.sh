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

# 腳本輸出含中文。使用者的終端機若不是 UTF-8 locale，內嵌 python3 印中文會
# UnicodeEncodeError 直接中止（實際踩過）。強制輸出編碼，與終端機 locale 脫鉤。
export PYTHONIOENCODING=utf-8

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

# 升版會改動九個檔案。中途 Ctrl-C 或任何一步失敗，半套的版本號就會留在
# 工作目錄裡，下次發版被閘門擋下還得自己收拾（實際踩過）。
# 除了「真的發版成功並已建立 commit」以外，一律還原。
BUMPED=0
RELEASED=0
cleanup() {
    if [[ "$BUMPED" -eq 1 && "$RELEASED" -eq 0 ]]; then
        echo ""
        echo "↩️  發版未完成，還原版本號改動…"
        git -C "$REPO_ROOT" checkout -- . 2>/dev/null || true
    fi
}
trap cleanup EXIT
# INT/TERM 要另外接：只掛在 trap 上的話，handler 跑完會回到原處繼續執行，
# Ctrl-C 之後腳本還會若無其事地往下跑。這裡明確結束。
trap 'trap - EXIT; cleanup; echo "   已中斷。"; exit 130' INT TERM

# 工作目錄必須乾淨。混著未提交的改動發版，事後根本分不清送出去的是哪個版本。
if [[ -n "$(git status --porcelain)" ]]; then
    echo "❌ 工作目錄有未提交的改動，發版中止：" >&2
    git status --short >&2
    exit 1
fi

step "1/5 升版本號"
BUMPED=1
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
    echo "   --dry-run：不建立 commit，版本號改動會在結束時自動還原。"
else
    # 沿用 chore(release): bump version to vX.Y.Z 的訊息格式，發版紀錄好辨認。
    git add -A
    git commit -q -m "chore(release): bump version to v${NEW_VERSION} (bundle ${NEW_BUNDLE})"
    git tag -f "v${NEW_VERSION}" >/dev/null
    RELEASED=1
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
