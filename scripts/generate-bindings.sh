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

echo "==> 完成"
ls -1 apple/Generated android/Generated/uniffi/padnote_core 2>/dev/null
