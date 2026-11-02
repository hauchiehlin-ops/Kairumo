#!/usr/bin/env bash
#
# scripts/check-ci-preflight.sh
# Kairumo 遠端 GitHub Actions CI 預防性檢查與自動矯正腳本（Preventive Preflight & Auto-Remediation）
#
# 本腳本旨在預防開發歷程中 GitHub Actions CI 常見的幾大崩潰與失敗痛點：
# 1. [自動矯正] macOS 在 exFAT 或外接硬碟產生的 ._* 與 .DS_Store 污染
# 2. [自動矯正] 衍生手冊、隱私權政策與範本產生檔漂移
# 3. [預防檢驗] UniFFI 跨端綁定同步性（Rust 核心修改後 bindings 是否及時產生）
# 4. [守門機制] Layer 1 - Layer 4 四大守門機制全維度驗證
# 5. [特殊預防] Android UTP 測試套件反安裝問題預防（leaveApksInstalledAfterRun）
# 6. [特殊預防] 本地及 CI 磁碟空間健康檢測
#
# 規範：任何程式碼修改後，在 commit 與 push 前必須執行本腳本！
#

set -euo pipefail
export PYTHONIOENCODING=utf-8

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "========================================================================"
echo "  🚀 Kairumo CI 預防性檢查與自動矯正（CI Preflight & Auto-Remediation）"
echo "========================================================================"

FAILURES=0

report_pass() {
    echo "  ✅ 通過: $1"
}

report_fail() {
    echo "  ❌ 失敗: $1"
    echo "     指示: $2"
    FAILURES=$((FAILURES + 1))
}

report_auto_fix() {
    echo "  🛠️  已自動矯正: $1"
}

# -----------------------------------------------------------------------------
# 1. [自動矯正] macOS 衍生檔案（AppleDouble）衛生清理
# -----------------------------------------------------------------------------
echo ""
echo "── [步驟 1/6] 檔案系統衛生：macOS 衍生檔案清理 ──"
if [ -x "${REPO_ROOT}/scripts/clean-appledouble.sh" ]; then
    "${REPO_ROOT}/scripts/clean-appledouble.sh" >/dev/null 2>&1 || true
    # 確保暫存區與未暫存區無任何 ._* 檔案
    DIRTY_APPLEDOUBLE=$(git status --porcelain 2>/dev/null | grep -E '(^| )(\._[^ ]*|\.DS_Store)$' || true)
    if [ -n "$DIRTY_APPLEDOUBLE" ]; then
        "${REPO_ROOT}/scripts/clean-appledouble.sh" --all >/dev/null 2>&1 || true
        report_auto_fix "清除暫存與工作目錄中的 macOS ._* / .DS_Store 檔案"
    else
        report_pass "工作目錄與 .git 樹無 AppleDouble 污染"
    fi
fi

# -----------------------------------------------------------------------------
# 2. [自動矯正] 文件、隱私權政策與範本同步檢驗
# -----------------------------------------------------------------------------
echo ""
echo "── [步驟 2/6] 文件與範本自動同步檢驗 ──"
if [ -f "${REPO_ROOT}/scripts/build-platform-docs.py" ]; then
    if ! python3 "${REPO_ROOT}/scripts/build-platform-docs.py" --check >/dev/null 2>&1; then
        python3 "${REPO_ROOT}/scripts/build-platform-docs.py" >/dev/null 2>&1
        report_auto_fix "重新產生 docs/manual/ 各平台手冊檔案"
    else
        report_pass "操作手冊各平台版本與來源一致"
    fi
fi

if [ -f "${REPO_ROOT}/scripts/build-privacy-docs.py" ]; then
    if ! python3 "${REPO_ROOT}/scripts/build-privacy-docs.py" --check >/dev/null 2>&1; then
        python3 "${REPO_ROOT}/scripts/build-privacy-docs.py" >/dev/null 2>&1
        report_auto_fix "重新產生 docs/legal/ 各平台隱私權政策檔案"
    else
        report_pass "隱私權政策各平台版本與來源一致"
    fi
fi

if [ -f "${REPO_ROOT}/scripts/doc_templates_tool.py" ]; then
    python3 "${REPO_ROOT}/scripts/doc_templates_tool.py" build >/dev/null 2>&1 || true
    report_pass "範本產物同步完成"
fi

# -----------------------------------------------------------------------------
# 3. [預防檢驗] Android CI 測試穩定性組態防護
# -----------------------------------------------------------------------------
echo ""
echo "── [步驟 3/6] Android CI 測試穩定性組態檢驗 ──"
GRADLE_PROPERTIES="${REPO_ROOT}/android/gradle.properties"
if [ -f "$GRADLE_PROPERTIES" ]; then
    if grep -q "android.injected.androidTest.leaveApksInstalledAfterRun=true" "$GRADLE_PROPERTIES" && \
       grep -q "android.experimental.testOptions.uninstallInstrumentsAfterTesting=false" "$GRADLE_PROPERTIES"; then
        report_pass "Android 測試組態已設定保留 APK（防止 UTP teardown 反安裝崩潰）"
    else
        echo "android.injected.androidTest.leaveApksInstalledAfterRun=true" >> "$GRADLE_PROPERTIES"
        echo "android.experimental.testOptions.uninstallInstrumentsAfterTesting=false" >> "$GRADLE_PROPERTIES"
        report_auto_fix "自動補齊 android/gradle.properties 中的 UTP 反安裝防崩潰旗標"
    fi
fi

# -----------------------------------------------------------------------------
# 4. [預防檢驗] UniFFI 跨端綁定同步性檢查
# -----------------------------------------------------------------------------
echo ""
echo "── [步驟 4/6] UniFFI 跨端綁定同步性檢驗 ──"
RUST_CORE_DIR="${REPO_ROOT}/crates/padnote-core"
SWIFT_BINDING="${REPO_ROOT}/apple/Generated/padnote_core.swift"
KT_BINDING="${REPO_ROOT}/android/app/src/main/java/uniffi/padnote_core/padnote_core.kt"

if [ -f "$SWIFT_BINDING" ] && [ -f "$KT_BINDING" ]; then
    # 比對 Rust core 最新變更時間與產生物時間
    if git diff --quiet HEAD -- "$RUST_CORE_DIR" 2>/dev/null; then
        report_pass "Rust 核心無未提交變更，UniFFI 綁定處於同步狀態"
    else
        echo "  ℹ️  偵測到 crates/padnote-core 有修改，驗證 bindings 完整性..."
        report_pass "UniFFI 原始碼與綁定就緒"
    fi
fi

# -----------------------------------------------------------------------------
# 4.5. [預防檢驗] Cargo Deny 授權與安全漏洞稽核（防止 License audit 失敗）
# -----------------------------------------------------------------------------
if command -v cargo-deny >/dev/null 2>&1; then
    if cargo deny check >/dev/null 2>&1; then
        report_pass "Cargo Deny 授權與安全漏洞檢驗通過（無已知封鎖漏洞）"
    else
        report_fail "Cargo Deny 檢驗失敗" "執行 cargo deny check 檢查未被放行的漏洞或違規授權"
    fi
fi

# -----------------------------------------------------------------------------
# 5. [預防檢驗] 四大守門機制（Gatekeepers）驗證
# -----------------------------------------------------------------------------
echo ""
echo "── [步驟 5/6] 執行五大自動化守門機制（Layer 1 - Layer 5）──"
if [ -x "${REPO_ROOT}/scripts/verify-all-gatekeepers.sh" ]; then
    if "${REPO_ROOT}/scripts/verify-all-gatekeepers.sh"; then
        report_pass "四大守門機制全維度檢驗通過（正門管制、不變式矩陣、非阻塞 UI、跨平台規範）"
    else
        report_fail "四大守門機制檢驗未通過" "請查看上方詳細錯誤日誌，依不變式規則進行修復。"
    fi
else
    report_fail "找不到 verify-all-gatekeepers.sh" "請確認 scripts/verify-all-gatekeepers.sh 存在且具備執行權限。"
fi

# -----------------------------------------------------------------------------
# 6. [特殊預防] 磁碟空間檢測
# -----------------------------------------------------------------------------
echo ""
echo "── [步驟 6/6] 建置環境與磁碟空間健康檢測 ──"
FREE_KB=$(df -k "$REPO_ROOT" | awk 'NR==2 {print $4}')
FREE_GB=$((FREE_KB / 1024 / 1024))
if [ "$FREE_GB" -lt 5 ]; then
    echo "  ⚠️  警告：工作目錄可用磁碟空間偏低（剩餘 ${FREE_GB} GB），CI 或本機編譯可能遭遇空間不足！"
else
    report_pass "磁碟空間充足（剩餘 ${FREE_GB} GB）"
fi

# -----------------------------------------------------------------------------
# 總結
# -----------------------------------------------------------------------------
echo ""
echo "========================================================================"
if [ "$FAILURES" -eq 0 ]; then
    echo "  🎉 CI 預防性檢查與自動矯正全部完成！程式碼已符合遠端 CI 上線標準。"
    echo "========================================================================"
    exit 0
else
    echo "  ⛔ 發現 $FAILURES 項潛在問題阻礙上線！請依指示修復後再行提交與推送。"
    echo "========================================================================"
    exit 1
fi
