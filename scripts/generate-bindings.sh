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
# Android 的綁定放在 XCFramework 檢查**之前**：那個檢查會 `exit 1`，
# 而它擋住的是 Apple 的問題。放在後面的話，只要 XCFramework 一過期，
# Android 的綁定就跟著不更新 —— 症狀是 Kotlin 端 Unresolved reference，
# 而畫面上只看得到一段叫你去重建 XCFramework 的訊息（實際踩過）。
# ── Android App 真正編譯的那一份綁定 ────────────────────────────────
#
# **這一段是後來補的，因為同一個錯誤在一天之內發生了四次。**
#
# `android/Generated` 是用預設 feature 產的，只給人看。App 真正編譯的是
# `android/app/src/main/java/uniffi/`，而它必須用 **Android 的 feature 組合**
# 產生（`--no-default-features --features relay`）——
# 用預設 feature 產的話會少掉 relay 那批型別，Kotlin 端整片 Unresolved。
#
# 在此之前這一步只存在於 `build-android-libs.sh` 裡，而那支腳本要跑十分鐘
# （整個 NDK 交叉編譯）。於是每次只改 FFI 的人都會跳過它，然後在 Kotlin
# 編譯時撞到一堆 Unresolved reference —— 而那個錯誤訊息完全指不出
# 「你忘了重新產綁定」。
echo "==> 產生 Android App 用的 Kotlin 綁定（Android feature 組合）"
# ⚠️ 順序有意義：**先**把 bindgen 這支執行檔編出來，再編 relay 版的
# 函式庫。反過來的話，`cargo run` 會為了編 bindgen 而用預設 feature
# 重編 padnote-core，把剛產好的 relay 版 dylib 蓋掉 —— 接著 bindgen
# 讀到的是預設 feature 的符號，產出一份看起來正常、但少了東西的綁定。
cargo build -q -p padnote-core --bin uniffi-bindgen
BINDGEN="target/debug/uniffi-bindgen"
cargo build -p padnote-core --no-default-features --features relay >/dev/null 2>&1
ANDROID_LIB="target/debug/libpadnote_core.dylib"
[[ -f "$ANDROID_LIB" ]] || ANDROID_LIB="target/debug/libpadnote_core.so"
if [[ -f "$ANDROID_LIB" && -x "$BINDGEN" ]]; then
    "$BINDGEN" generate \
        --library "$ANDROID_LIB" --language kotlin \
        --out-dir android/app/src/main/java 2>&1 | grep -v "^Warning: Unable to auto-format" || true
    echo "   ✅ android/app/src/main/java/uniffi/"
else
    echo "   ⚠️ 找不到 Android feature 組合的函式庫，這一份綁定沒有更新"
    echo "      Kotlin 端會出現 Unresolved reference —— 手動跑："
    echo "      cargo build -p padnote-core --no-default-features --features relay"
fi

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
# build-xcframework.sh 自己會呼叫這支腳本，然後**立刻**重建 framework ——
# 對它做這個檢查是死結：綁定一改，檢查就 exit 1，而唯一的解法正是跑那支
# 被擋住的腳本。它會設這個變數把檢查關掉（實際卡住過）。
STAMP="apple/PadnoteCore.xcframework/.bindings-sha256"
if [[ -n "${PADNOTE_REBUILDING_XCFRAMEWORK:-}" ]]; then
    echo "   （由 build-xcframework.sh 呼叫，略過同步檢查 —— 它接著就會重建）"
elif [[ -f "$STAMP" ]]; then
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
