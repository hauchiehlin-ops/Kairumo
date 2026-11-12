#!/usr/bin/env bash
#
# scripts/sop-verify.sh
# 《驗證流程標準作業規範（SOP）》的唯一執行入口。
# GEMINI.md / AGENTS.md（Antigravity、Claude Code、人類開發者）一律呼叫這支，不各自手敲指令。
#
#   ./scripts/sop-verify.sh                 # 完整三道防線（commit / push 前）
#   ./scripts/sop-verify.sh --fast          # 只跑第 1 道（CI 預防 + 四大守門），改碼中途用
#   ./scripts/sop-verify.sh --skip-apple    # 略過 Apple 建置（例：Linux 或只改 Android）
#   ./scripts/sop-verify.sh --skip-android  # 略過 Android 單元測試
#
# 防線：
#   1. CI 預防性檢查 + 四大守門機制   scripts/check-ci-preflight.sh
#   2. 雙平台單元測試                 Android testDebugUnitTest／Apple xcodebuild build
#   3. Git Pre-Push 門禁就緒          core.hooksPath 指向 .githooks 且 pre-push 可執行
#
# 任何一道失敗即以非 0 結束；被略過的項目明確標示「略過」，不當成通過。
# 平台工具缺失（無 xcodebuild、無 Android SDK）一律視為失敗，除非明確 --skip-*，避免默默放行。

set -uo pipefail
export PYTHONIOENCODING=utf-8

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RUN_ANDROID=1
RUN_APPLE=1
FAST=0
for arg in "$@"; do
    case "$arg" in
        --fast)         FAST=1 ;;
        --skip-android) RUN_ANDROID=0 ;;
        --skip-apple)   RUN_APPLE=0 ;;
        -h|--help)      sed -n '2,22p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) echo "未知參數：${arg}（見 --help）" >&2; exit 2 ;;
    esac
done

LOG_DIR="${TMPDIR:-/tmp}/kairumo-sop"
mkdir -p "$LOG_DIR"

RESULTS=()
FAILURES=0
pass() { RESULTS+=("✅ $1"); }
skip() { RESULTS+=("⏭️  $1（略過）"); }
fail() { RESULTS+=("❌ $1"); FAILURES=$((FAILURES + 1)); }

# run_step <名稱> <記錄檔> <指令...>：輸出寫入記錄檔，失敗時印出尾段供診斷。
run_step() {
    local name="$1" log="$2"
    shift 2
    echo "👉 ${name}..."
    if "$@" >"$log" 2>&1; then
        pass "$name"
    else
        fail "${name}（記錄：${log}）"
        echo "---- 最後 40 行 ----"
        tail -n 40 "$log"
        echo "--------------------"
    fi
}

echo "════════════════════════════════════════════════════════════════════════"
echo "  📋 Kairumo SOP 驗證（分支：$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')）"
echo "════════════════════════════════════════════════════════════════════════"

# ── 第 1 道：CI 預防 + 四大守門 ───────────────────────────────────────────
echo ""
echo "── [第 1/3 道] CI 預防性檢查與四大守門機制 ──"
echo "👉 執行 check-ci-preflight.sh（輸出直通）..."
if "${REPO_ROOT}/scripts/check-ci-preflight.sh"; then
    pass "第 1 道：CI 預防性檢查與四大守門機制"
else
    fail "第 1 道：CI 預防性檢查與四大守門機制"
fi

# ── 第 2 道：雙平台單元測試 ───────────────────────────────────────────────
echo ""
echo "── [第 2/3 道] 雙平台單元測試 ──"
if [ "$FAST" -eq 1 ]; then
    skip "第 2 道：雙平台單元測試（--fast）"
else
    if [ "$RUN_ANDROID" -eq 1 ]; then
        # gradle.sh 會處理 exFAT 的 ._* 清理與建置目錄；等同 `cd android && ./gradlew testDebugUnitTest`。
        run_step "Android：testDebugUnitTest" "$LOG_DIR/android-test.log" \
            "${REPO_ROOT}/scripts/gradle.sh" testDebugUnitTest
    else
        skip "Android：testDebugUnitTest"
    fi

    if [ "$RUN_APPLE" -eq 1 ]; then
        if command -v xcodebuild >/dev/null 2>&1; then
            run_step "Apple：xcodebuild -scheme Kairumo build" "$LOG_DIR/apple-build.log" \
                bash -c 'cd "$1/apple" && xcodebuild -scheme Kairumo build' _ "$REPO_ROOT"
        else
            fail "Apple：找不到 xcodebuild（非 macOS？請改用 --skip-apple 並在報告中註明）"
        fi
    else
        skip "Apple：xcodebuild build"
    fi
fi

# ── 第 3 道：Pre-Push 門禁就緒 ────────────────────────────────────────────
echo ""
echo "── [第 3/3 道] Git Pre-Push 門禁 ──"
HOOKS_PATH="$(git config core.hooksPath || true)"
if [ "$HOOKS_PATH" = ".githooks" ] && [ -x "${REPO_ROOT}/.githooks/pre-push" ]; then
    pass "第 3 道：pre-push 門禁已啟用（core.hooksPath=.githooks）"
elif [ -x "${REPO_ROOT}/.git/hooks/pre-push" ]; then
    pass "第 3 道：pre-push 門禁已安裝（.git/hooks/pre-push）"
else
    fail "第 3 道：pre-push 門禁未啟用。請執行 git config core.hooksPath .githooks 或 ./scripts/install-git-hook.sh"
fi

# ── 總結 ──────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════════════"
printf '  %s\n' "${RESULTS[@]}"
echo "════════════════════════════════════════════════════════════════════════"
if [ "$FAILURES" -eq 0 ]; then
    GIT_DIR="$(git rev-parse --git-dir 2>/dev/null || echo "${REPO_ROOT}/.git")"
    head_sha="$(git rev-parse HEAD 2>/dev/null || echo "no-head")"
    diff_head="$(git diff HEAD 2>/dev/null || echo "no-diff")"
    staged_head="$(git diff --cached 2>/dev/null || echo "no-staged")"
    mkdir -p "${GIT_DIR}"
    printf "%s\n%s\n%s" "$head_sha" "$diff_head" "$staged_head" | shasum -a 256 | awk '{print $1}' > "${GIT_DIR}/gatekeepers.passed" 2>/dev/null || true
    echo "  🎉 SOP 全數通過，可提交與推送。"
    exit 0
fi
echo "  ⛔ SOP 有 $FAILURES 項未通過，禁止提交／推送。"
exit 1
