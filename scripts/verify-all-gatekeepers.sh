#!/usr/bin/env bash
#
# scripts/verify-all-gatekeepers.sh
# Kairumo 四大自動化守門機制（Gatekeepers）一鍵完整檢驗腳本。
# 遵循專案最高原則：「不要改了這個、壞了那個」，嚴格卡控「穩定」、「即時」、「正確」。
#
# 用法：./scripts/verify-all-gatekeepers.sh [--fast] [--force]
#

set -euo pipefail
export PYTHONIOENCODING=utf-8

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FORCE=0
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
    esac
done

calc_fingerprint() {
    local head_sha diff_head untracked
    head_sha="$(git rev-parse HEAD 2>/dev/null || echo "no-head")"
    diff_head="$(git diff HEAD 2>/dev/null || echo "no-diff")"
    untracked="$(git status --porcelain 2>/dev/null | grep '^\?\?' || true)"
    printf "%s\n%s\n%s" "$head_sha" "$diff_head" "$untracked" | shasum -a 256 | awk '{print $1}'
}

CACHE_FILE="${REPO_ROOT}/.git/gatekeepers.passed"
if [ "$FORCE" -eq 0 ] && [ -f "$CACHE_FILE" ]; then
    CACHED_FP="$(cat "$CACHE_FILE" 2>/dev/null || true)"
    CURRENT_FP="$(calc_fingerprint)"
    if [ -n "$CACHED_FP" ] && [ "$CACHED_FP" = "$CURRENT_FP" ]; then
        echo "════════════════════════════════════════════════════════════════════════"
        echo "  ℹ️  四大守門機制先前已全數通過驗證（程式碼狀態未變更），略過重複執行。"
        echo "════════════════════════════════════════════════════════════════════════"
        exit 0
    fi
fi

# exFAT 磁碟環境下先清理 macOS 衍生的 ._* 與 .DS_Store
"${REPO_ROOT}/scripts/clean-appledouble.sh" --git-only >/dev/null 2>&1 || true

echo "════════════════════════════════════════════════════════════════════════"
echo "  🛡️  Kairumo 四大守門機制（Gatekeepers）全維度檢驗開始"
echo "════════════════════════════════════════════════════════════════════════"

FAILURES=0

run_check() {
    local name="$1"
    shift
    echo -n "👉 檢驗中：${name}... "
    if "$@" >/dev/null 2>&1; then
        echo "✅ 通過"
    else
        echo "❌ 失敗！"
        echo "   指令：$*"
        FAILURES=$((FAILURES + 1))
    fi
}

echo ""
echo "── [Layer 1] 編輯器狀態正門管制 ──"
run_check "狀態唯一正門（換工具、切模式、切頁面嚴禁繞過）" python3 "${REPO_ROOT}/scripts/check-state-entrypoints.py"

echo ""
echo "── [Layer 2] 筆跡單一真相與不變式矩陣（ADR-0015）──"
run_check "Rust 核心與筆跡引擎單元測試（740+ 項不變式）" cargo test -p padnote-core -p padnote-ink
run_check "彈性邊界守門（性質不變式與可調手感參數分離）" python3 "${REPO_ROOT}/scripts/check-tunable-invariants.py"
run_check "介面字串產生檔與 catalog 一致性" python3 "${REPO_ROOT}/scripts/i18n_tool.py" verify
run_check "名詞規範與詞彙表一致性" python3 "${REPO_ROOT}/scripts/check-glossary.py"

echo ""
echo "── [Layer 3] 主執行緒非阻塞與執行緒安全 ──"
run_check "主執行緒無 lstat 磁碟 I/O" python3 "${REPO_ROOT}/scripts/check-main-thread-io.py"
run_check "無 MainActor.assumeIsolated 裸呼叫" python3 "${REPO_ROOT}/scripts/check-assume-isolated.py"
run_check "無未經防護的彈窗延遲常數" python3 "${REPO_ROOT}/scripts/check-transition-delays.py"
run_check "無被默默忽略的參數" python3 "${REPO_ROOT}/scripts/check-unused-params.py"

echo ""
echo "── [Layer 4] 多設定檔隔離與跨平台衛生規範 ──"
run_check "多設定檔狀態分類無遺漏" python3 "${REPO_ROOT}/scripts/check-profile-scope.py"
run_check "介面無硬寫死字串" python3 "${REPO_ROOT}/scripts/check-hardcoded-strings.py"
run_check "全平台版本號一致性" "${REPO_ROOT}/scripts/check-version-consistency.sh"
run_check "無未被引用的孤兒實作" python3 "${REPO_ROOT}/scripts/check-orphans.py"

echo ""
echo "── [Layer 5] 畫布核心純度與重型次系統隔離（Canvas Isolation）──"
run_check "手寫關鍵路徑與畫布次系統解耦守門" python3 "${REPO_ROOT}/scripts/check-canvas-isolation.py"
run_check "延遲預算量測點守門" python3 "${REPO_ROOT}/scripts/check-latency-budget.py"

echo ""
echo "════════════════════════════════════════════════════════════════════════"
if [ "$FAILURES" -eq 0 ]; then
    mkdir -p "${REPO_ROOT}/.git"
    calc_fingerprint > "$CACHE_FILE" 2>/dev/null || true
    echo "  🎉 五大守門機制全數通過！符合「穩定」、「即時」、「正確」標準。"
    echo "════════════════════════════════════════════════════════════════════════"
    exit 0
else
    echo "  ⚠️  檢驗發現 $FAILURES 項違規！請依上述指示修正後再行提交。"
    echo "════════════════════════════════════════════════════════════════════════"
    exit 1
fi
