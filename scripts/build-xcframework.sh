#!/usr/bin/env bash
# 建置 iOS/macOS 用的 XCFramework（工作項 S-12，需 Xcode）。
#
# ⚠️ 尚未在實機驗證 —— 見 docs/TODO.md H1。
set -euo pipefail

cd "$(dirname "$0")/.."

TARGETS=(
  aarch64-apple-ios          # 實機
  aarch64-apple-ios-sim      # Apple Silicon 模擬器
  aarch64-apple-darwin       # macOS
)

echo "==> 確認 target 已安裝"
for t in "${TARGETS[@]}"; do
  rustup target add "$t" >/dev/null 2>&1 || true
done

echo "==> 編譯 release 靜態庫"
for t in "${TARGETS[@]}"; do
  cargo build -p padnote-core --release --target "$t"
done

echo "==> 產生綁定"
./scripts/generate-bindings.sh

OUT="apple/PadnoteCore.xcframework"
rm -rf "$OUT"

# UniFFI 產生的 modulemap 要改名為 module.modulemap 才能被 Xcode 當成模組
HEADERS="target/xcf-headers"
rm -rf "$HEADERS" && mkdir -p "$HEADERS"
cp apple/Generated/padnote_coreFFI.h "$HEADERS/"
cp apple/Generated/padnote_coreFFI.modulemap "$HEADERS/module.modulemap"

echo "==> 組裝 XCFramework"
xcodebuild -create-xcframework \
  -library "target/aarch64-apple-ios/release/libpadnote_core.a"     -headers "$HEADERS" \
  -library "target/aarch64-apple-ios-sim/release/libpadnote_core.a" -headers "$HEADERS" \
  -library "target/aarch64-apple-darwin/release/libpadnote_core.a"  -headers "$HEADERS" \
  -output "$OUT"

echo "==> 完成：$OUT"
echo "   把 $OUT 與 apple/Generated/padnote_core.swift 加入 Xcode 專案即可。"
