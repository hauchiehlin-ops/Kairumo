#!/usr/bin/env bash
# 產生 Swift 與 Kotlin 綁定（工作項 S-12）。
#
# 產出是**衍生檔案**，不進版控 —— 與 core 的 API 不同步的綁定比沒有更危險。
# 修改 crates/padnote-core/src/ffi.rs 之後重跑這支腳本。
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> 編譯 padnote-core"
cargo build -p padnote-core

LIB="target/debug/libpadnote_core.dylib"
[[ -f "$LIB" ]] || LIB="target/debug/libpadnote_core.so"

echo "==> 產生 Swift 綁定 → apple/Generated"
mkdir -p apple/Generated
cargo run -q -p padnote-core --bin uniffi-bindgen -- generate \
  --library "$LIB" --language swift --out-dir apple/Generated

echo "==> 產生 Kotlin 綁定 → android/Generated"
mkdir -p android/Generated
cargo run -q -p padnote-core --bin uniffi-bindgen -- generate \
  --library "$LIB" --language kotlin --out-dir android/Generated

# ⚠️ 這裡產生的 Kotlin 綁定**不要**複製進 android/app/src/main/java。
# 那份必須由 scripts/build-android-libs.sh 產生：Android 版用的是不同的
# feature 組合（--no-default-features 再加 relay），用預設 feature 產出的
# 綁定會少掉 RelayServer 之類的型別，Kotlin 端就編不過。
# --- XCFramework 同步檢查 -------------------------------------------------
#
# **綁定改了、XCFramework 沒重建 = App 執行到那支 FFI 就當掉。**
#
# 症狀完全不像 ABI 問題：編譯 SUCCEEDED、測試看起來只是「失敗」，
# 實際是 `UniffiInternalError.rustPanic("junk data left in buffer after
# lifting (count: 4)")` —— Swift 端多送了新欄位的位元組，舊的
# XCFramework 不認得。實際踩過：`FfiShape` 加了 rotation_degrees 之後。
#
# CI 抓不到這個：XCFramework 不進版控，CI 每次都重新建，永遠是同步的。
# 這是**本機開發專屬**的坑，所以防線得放在這裡。
STAMP="apple/PadnoteCore.xcframework/.bindings-sha256"
if [[ -f "$STAMP" ]]; then
    CURRENT="$(shasum -a 256 apple/Generated/padnote_core.swift | awk '{print $1}')"
    if [[ "$CURRENT" != "$(cat "$STAMP")" ]]; then
        echo ""
        echo "❌ 綁定與 PadnoteCore.xcframework 不同步。"
        echo "   直接跑的話，App 會在呼叫到改動過的 FFI 時當掉，"
        echo "   而且編譯完全不會報錯（錯誤長這樣："
        echo "   rustPanic \"junk data left in buffer after lifting\"）。"
        echo ""
        echo "   請接著執行：./scripts/build-xcframework.sh"
        exit 1
    fi
else
    echo "⚠️ XCFramework 沒有綁定指紋（可能是舊版建的）——"
    echo "   保險起見請跑一次 ./scripts/build-xcframework.sh"
fi

echo "==> 完成"
ls -1 apple/Generated android/Generated/uniffi/padnote_core 2>/dev/null
