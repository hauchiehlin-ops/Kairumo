#!/usr/bin/env bash
#
# scripts/release.sh
# 發版的**單一入口**：升版本號 → 打包 → 上傳 → 建立發版 commit 與 tag。
#
# 用法：
#   ./scripts/release.sh                    # 升 patch，Apple + Android 一起（最常用）
#   ./scripts/release.sh apple              # 只發 Apple（iOS / iPadOS / macOS）
#   ./scripts/release.sh android            # 只發 Android
#   ./scripts/release.sh all minor          # 升 minor，兩個平台
#   ./scripts/release.sh all 3.7.0          # 指定版本號
#   ./scripts/release.sh all 3.7.0 31       # 指定版本號與 build 號
#   ./scripts/release.sh bump minor         # 只升版號，不打包
#   ./scripts/release.sh --dry-run          # 不上傳、Android 不簽章、不留 commit
#
# ⚠️ **一次發版只升一次版本號。**
#
# 這是整個腳本最重要的規則，也是 ASC 上那堆混亂號碼的成因：
# 過去 Apple 與 Android 各自用不同指令打包，各自升號，於是同一個 build 號
# 被不同版本重複使用（build 24 被 3.2.0 / 2.10.1 / 2.10.0 三個版本用過）。
#
# 現在的規則：
#   - `apple` / `android` 單獨執行時**不升版**，打包的是 repo 目前的版本。
#     想先發 Apple 再發 Android？跑兩次，兩邊拿到同一個號碼。
#   - 要升版就用 `all`（預設）或 `bump`。
#   - build 號由 bump-version.sh 取「本機來源與 ASC 的最大值 + 1」，
#     只會單調遞增，撞號在結構上不可能發生。
#
set -euo pipefail

# 腳本輸出含中文。終端機若不是 UTF-8 locale，內嵌 python3 印中文會直接中止。
export PYTHONIOENCODING=utf-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=0
TARGET=""          # apple | android | all | bump
BUMP_ARGS=()

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) sed -n '5,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        apple|android|all|bump)
            if [[ -n "$TARGET" ]]; then
                echo "❌ 一次只能指定一個目標（已經有 '$TARGET'，又出現 '$arg'）" >&2
                exit 2
            fi
            TARGET="$arg" ;;
        # 舊旗標保留但明確導向新寫法 —— 直接移除的話，既有筆記與 CI 會靜默失效。
        --ios-only|--apple-only)
            echo "❌ $arg 已由 'apple' 取代：./scripts/release.sh apple" >&2
            exit 2 ;;
        -*)
            echo "❌ 未知參數：$arg" >&2
            echo "   用法：./scripts/release.sh [apple|android|all|bump] [patch|minor|major|X.Y.Z] [build]" >&2
            exit 2 ;;
        *) BUMP_ARGS+=("$arg") ;;
    esac
done

TARGET="${TARGET:-all}"

case "$TARGET" in
    all|bump) DO_BUMP=1; DO_APPLE=$([[ "$TARGET" == all ]] && echo 1 || echo 0)
              DO_ANDROID=$([[ "$TARGET" == all ]] && echo 1 || echo 0) ;;
    apple)    DO_BUMP=0; DO_APPLE=1; DO_ANDROID=0 ;;
    android)  DO_BUMP=0; DO_APPLE=0; DO_ANDROID=1 ;;
esac

# 單平台模式下給了升版參數，幾乎一定是誤會 —— 那會讓兩個平台的號碼分家，
# 正是要根除的問題。寧可在這裡停下來解釋。
if [[ "$DO_BUMP" -eq 0 && ${#BUMP_ARGS[@]} -gt 0 ]]; then
    echo "❌ '$TARGET' 不升版號，所以不接受 '${BUMP_ARGS[*]}'。" >&2
    echo "   單平台打包用的是 repo 目前的版本 —— 那是刻意的：" >&2
    echo "   Apple 與 Android 各自升號，就會出現同一個 build 號被不同版本用過。" >&2
    echo "   要升版請用：./scripts/release.sh all ${BUMP_ARGS[*]}" >&2
    exit 2
fi

step() { echo ""; echo "━━━ $* ━━━"; }

# 升版會改動九個檔案。中途 Ctrl-C 或任何一步失敗，半套的版本號就會留在
# 工作目錄裡，下次發版被閘門擋下還得自己收拾（實際踩過）。
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
# INT/TERM 要另外接：只掛 EXIT 的話，handler 跑完會回到原處繼續執行。
trap 'trap - EXIT; cleanup; echo "   已中斷。"; exit 130' INT TERM

if [[ -n "$(git status --porcelain)" ]]; then
    echo "❌ 工作目錄有未提交的改動，發版中止：" >&2
    git status --short >&2
    exit 1
fi

TOTAL=5
[[ "$TARGET" == bump ]] && TOTAL=3

if [[ "$DO_BUMP" -eq 1 ]]; then
    step "1/$TOTAL 升版本號"
    BUMPED=1
    BUMP_OUT="$("${SCRIPT_DIR}/bump-version.sh" "${BUMP_ARGS[@]:-patch}")"
    echo "$BUMP_OUT"
    NEW_VERSION="$(echo "$BUMP_OUT" | sed -n 's/^NEW_VERSION=//p')"
    NEW_BUNDLE="$(echo "$BUMP_OUT"  | sed -n 's/^NEW_BUNDLE_VERSION=//p')"
else
    step "1/$TOTAL 使用 repo 目前的版本（$TARGET 不升版）"
    NEW_VERSION="$(python3 -c "import re;print(re.search(r'version\s*=\s*\"([^\"]+)\"',open('Cargo.toml').read()).group(1))")"
    NEW_BUNDLE="$(python3 -c "import re;print(re.search(r'CURRENT_PROJECT_VERSION\s*=\s*(\d+)',open('apple/Kairumo.xcodeproj/project.pbxproj').read()).group(1))")"
    echo "   v${NEW_VERSION} (build ${NEW_BUNDLE})"
fi

step "2/$TOTAL 介面字串與版本一致性"
python3 "${SCRIPT_DIR}/i18n_tool.py" verify
"${SCRIPT_DIR}/check-version-consistency.sh"

if [[ "$TARGET" == bump ]]; then
    step "3/$TOTAL 發版 commit"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "   --dry-run：不建立 commit，版本號改動會在結束時自動還原。"
    else
        "${SCRIPT_DIR}/release-commit.sh" "$NEW_VERSION" "$NEW_BUNDLE"
        RELEASED=1
    fi
    echo ""
    echo "✅ 版本已升到 v${NEW_VERSION} (build ${NEW_BUNDLE})，尚未打包。"
    echo "   接著：./scripts/release.sh apple　與／或　./scripts/release.sh android"
    exit 0
fi

if [[ "$DO_APPLE" -eq 1 ]]; then
    step "3/$TOTAL Apple（iPhone / iPad / Mac）"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        "${SCRIPT_DIR}/apple-release.sh" --validate-only
    else
        "${SCRIPT_DIR}/apple-release.sh"
    fi
else
    step "3/$TOTAL Apple（略過）"
fi

if [[ "$DO_ANDROID" -eq 1 ]]; then
    step "4/$TOTAL Android"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        "${SCRIPT_DIR}/android-release.sh" --unsigned
    else
        "${SCRIPT_DIR}/android-release.sh"
    fi
else
    step "4/$TOTAL Android（略過）"
fi

step "5/$TOTAL 發版 commit"
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "   --dry-run：不建立 commit，版本號改動會在結束時自動還原。"
elif [[ "$DO_BUMP" -eq 0 ]]; then
    echo "   $TARGET 不升版，沒有版本號改動要提交。"
else
    "${SCRIPT_DIR}/release-commit.sh" "$NEW_VERSION" "$NEW_BUNDLE"
    RELEASED=1
fi

cat <<NEXT

════════════════════════════════════════════
✅ v${NEW_VERSION} (build ${NEW_BUNDLE}) 完成
════════════════════════════════════════════

接下來要人做的：
NEXT
[[ "$DO_BUMP" -eq 1 && "$DRY_RUN" -eq 0 ]] && echo "  git push origin main --tags"
[[ "$DO_ANDROID" -eq 1 ]] && echo "  Play Console → 內部測試 → 上傳 android/app/build/outputs/bundle/release/app-release.aab"
[[ "$DO_APPLE" -eq 1 ]] && echo "  App Store Connect → 等建置版本處理完 → 加入測試群組"
exit 0
