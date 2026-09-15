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
  # coreaudio-sys（cpal 的相依）的 build.rs 只認得 darwin / ios / ios-sim，
  # 碰到 Mac Catalyst 的 aarch64-apple-ios-macabi 會直接 unreachable!() panic。
  # 它會優先讀 COREAUDIO_SDK_PATH，所以把上面已經算好的 SDK 路徑餵給它繞過去。
  CA_SDK_PATH="$(xcrun --sdk "$SDK" --show-sdk-path 2>/dev/null || true)"
  if [[ -n "$CA_SDK_PATH" ]]; then
    export COREAUDIO_SDK_PATH="$CA_SDK_PATH"
  else
    unset COREAUDIO_SDK_PATH
  fi
  # **Apple 不含 pdf feature**（決策 D-11b，2026-09-16）。
  #
  # 那個 feature 會連進 `padnote-pdf-pdfium`，而 PDFium 需要一份預建的原生庫。
  # bblanchon 發佈的 mac 版是**平台 1（macOS）**，不是平台 6（MACCATALYST）——
  # Catalyst 的建置根本不會去選它，所以 Mac 版從一開始就沒有可用的二進位檔。
  #
  # Apple 這邊本來就有 PDFKit（iOS / iPadOS / macOS / Catalyst 全都有，
  # 而且 `ExportPrintManager` 已經在用它列印）。與其為了四個平台裡的一個
  # 去自建 PDFium，不如讓 Apple 走系統的那一套：少 6 MB × 2 的二進位、
  # 少一個第三方供應鏈、少一個會隨系統更新壞掉的東西。
  #
  # 核心裡 pdf feature 唯一的用途是 `export_page_png` 的一段**最佳化**，
  # 而它本來就有純 Rust 的 fallback（Android 一直走那一條）。關掉它
  # 只是讓 Apple 也走同一條路，功能不會少。
  ORT_LIB_LOCATION="$STUB_DIR" OPUS_LIB_DIR="$STUB_DIR" \
    cargo rustc -p padnote-core --lib --release --target "$t" \
    --no-default-features --features asr --crate-type staticlib
done

echo "==> 產生綁定"
# 見 generate-bindings.sh 裡的說明：不關掉同步檢查的話，這一行會被它擋下來。
PADNOTE_REBUILDING_XCFRAMEWORK=1 ./scripts/generate-bindings.sh

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

# 留下這份 XCFramework **是用哪一版綁定建的**的指紋。
#
# generate-bindings.sh 會拿它比對。用內容雜湊而不是檔案時間 ——
# 這支腳本自己最後也會重新產生綁定，比時間的話綁定永遠比 framework 新，
# 變成永久誤報（第一版就是這樣）。
shasum -a 256 apple/Generated/padnote_core.swift | awk '{print $1}' \
    > "$OUT/.bindings-sha256"

echo "==> 完成：$OUT"
echo "   把 $OUT 與 apple/Generated/padnote_core.swift 加入 Xcode 專案即可。"
