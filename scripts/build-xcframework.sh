#!/usr/bin/env bash
# 建置 iOS/macOS 用的 XCFramework（工作項 S-12，需 Xcode）。
#
# ⚠️ 尚未在實機驗證 —— 見 docs/TODO.md H1。
set -euo pipefail

cd "$(dirname "$0")/.."

TARGETS=(
  aarch64-apple-ios          # 實機 (iPhone / iPad)
  aarch64-apple-ios-sim      # Apple Silicon 模擬器
  aarch64-apple-ios-macabi   # Mac Catalyst (Mac 通用)
)

echo "==> 確認 target 已安裝"
for t in "${TARGETS[@]}"; do
  rustup target add "$t" >/dev/null 2>&1 || true
done

# 確保 PATH 包含 Homebrew 工具（如 autoreconf）
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> 編譯 release 靜態庫"
for t in "${TARGETS[@]}"; do
  case "$t" in
    aarch64-apple-ios)
      SDK="iphoneos"
      CLANG_TARGET="arm64-apple-ios"
      ;;
    aarch64-apple-ios-sim)
      SDK="iphonesimulator"
      CLANG_TARGET="arm64-apple-ios-simulator"
      ;;
    aarch64-apple-ios-macabi)
      SDK="macosx"
      CLANG_TARGET="arm64-apple-ios14.0-macabi"
      ;;
    aarch64-apple-darwin)
      SDK="macosx"
      CLANG_TARGET="arm64-apple-macos"
      ;;
    *)
      SDK="macosx"
      CLANG_TARGET="arm64-apple-macos"
      ;;
  esac

  STUB_DIR="${REPO_ROOT}/target/stubs/$t"
  mkdir -p "$STUB_DIR"
  if [[ ! -f "${STUB_DIR}/libonnxruntime.a" || ! -f "${STUB_DIR}/libopus.a" ]]; then
    SDK_PATH="$(xcrun --sdk "$SDK" --show-sdk-path 2>/dev/null || true)"
    if [[ -n "$SDK_PATH" ]]; then
      echo "void _padnote_stub(void) {}" | xcrun clang -x c - -target "$CLANG_TARGET" -isysroot "$SDK_PATH" -c -o "${STUB_DIR}/dummy.o" 2>/dev/null || touch "${STUB_DIR}/dummy.o"
    else
      echo "void _padnote_stub(void) {}" | xcrun clang -x c - -target "$CLANG_TARGET" -c -o "${STUB_DIR}/dummy.o" 2>/dev/null || touch "${STUB_DIR}/dummy.o"
    fi
    ar cr "${STUB_DIR}/libonnxruntime.a" "${STUB_DIR}/dummy.o" 2>/dev/null || true
    ar cr "${STUB_DIR}/libopus.a" "${STUB_DIR}/dummy.o" 2>/dev/null || true
  fi

  echo "  --> 編譯 target: $t"
  ORT_LIB_LOCATION="$STUB_DIR" OPUS_LIB_DIR="$STUB_DIR" \
    cargo rustc -p padnote-core --lib --release --target "$t" --crate-type staticlib
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
  -library "target/aarch64-apple-ios/release/libpadnote_core.a"        -headers "$HEADERS" \
  -library "target/aarch64-apple-ios-sim/release/libpadnote_core.a"    -headers "$HEADERS" \
  -library "target/aarch64-apple-ios-macabi/release/libpadnote_core.a" -headers "$HEADERS" \
  -output "$OUT"

echo "==> 完成：$OUT"
echo "   把 $OUT 與 apple/Generated/padnote_core.swift 加入 Xcode 專案即可。"
