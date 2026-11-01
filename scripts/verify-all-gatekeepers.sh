#!/usr/bin/env bash
#
# scripts/verify-all-gatekeepers.sh
# Kairumo 四大自動化守門機制（Gatekeepers）一鍵完整檢驗腳本。
# 遵循專案最高原則：「不要改了這個、壞了那個」，嚴格卡控「穩定」、「即時」、「正確」。
#
# 用法：./scripts/verify-all-gatekeepers.sh [--fast]
#

set -euo pipefail
export PYTHONIOENCODING=utf-8

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

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

echo ""
echo "════════════════════════════════════════════════════════════════════════"
if [ "$FAILURES" -eq 0 ]; then
    echo "  🎉 四大守門機制全數通過！符合「穩定」、「即時」、「正確」標準。"
    echo "════════════════════════════════════════════════════════════════════════"
    exit 0
else
    echo "  ⚠️  檢驗發現 $FAILURES 項違規！請依上述指示修正後再行提交。"
    echo "════════════════════════════════════════════════════════════════════════"
    exit 1
fi
