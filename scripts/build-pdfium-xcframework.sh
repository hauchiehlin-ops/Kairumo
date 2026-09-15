#!/usr/bin/env bash
#
# 把抓下來的 libpdfium 組成 XCFramework（docs/TODO.md H8）。
#
# 先跑 ./scripts/fetch-pdfium.sh all 把二進位檔抓下來（版本釘死、逐檔驗雜湊）。
#
# # Mac Catalyst 沒有對應的二進位檔
#
# bblanchon 發佈的 mac 版是 **平台 1（macOS）**，不是平台 6（MACCATALYST）。
# `xcodebuild -create-xcframework` 會把它標成 `macos-arm64`，而 Catalyst 的
# 建置不會去選那一片 —— 連結階段找不到，或是執行期 dlopen 失敗。
#
# 所以這支腳本只組 **iOS 裝置 + iOS 模擬器**。Catalyst 要嘛自己用
# depot_tools + gn + ninja 建一份 Catalyst 的 PDFium，要嘛在 Mac 上
# 走另一條 PDF 路徑。那是一個還沒做的決定，不要讓它靜靜地少一片。
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${PDFIUM_DIR:-$ROOT/third_party/pdfium}"
OUT="$ROOT/apple/PDFium.xcframework"

for pkg in pdfium-ios-device-arm64 pdfium-ios-simulator-arm64; do
    if [[ ! -f "$SRC/$pkg/lib/libpdfium.dylib" ]]; then
        echo "❌ 找不到 $SRC/$pkg/lib/libpdfium.dylib" >&2
        echo "   先跑：./scripts/fetch-pdfium.sh all" >&2
        exit 1
    fi
done

# install_name 必須是 @rpath/…，否則 App 啟動時會去找絕對路徑 `./libpdfium.dylib`
# 而那個位置在裝置上不存在 —— 症狀是一開 App 就閃退，而且訊息指向
# dyld 而不是我們的程式。
STAGE="$ROOT/target/pdfium-stage"
rm -rf "$STAGE" && mkdir -p "$STAGE/device" "$STAGE/simulator"
cp "$SRC/pdfium-ios-device-arm64/lib/libpdfium.dylib"    "$STAGE/device/"
cp "$SRC/pdfium-ios-simulator-arm64/lib/libpdfium.dylib" "$STAGE/simulator/"
for f in "$STAGE/device/libpdfium.dylib" "$STAGE/simulator/libpdfium.dylib"; do
    install_name_tool -id "@rpath/libpdfium.dylib" "$f"
done

HEADERS="$STAGE/include"
cp -R "$SRC/pdfium-ios-device-arm64/include" "$HEADERS"

rm -rf "$OUT"
xcodebuild -create-xcframework \
    -library "$STAGE/device/libpdfium.dylib"    -headers "$HEADERS" \
    -library "$STAGE/simulator/libpdfium.dylib" -headers "$HEADERS" \
    -output "$OUT"

echo
echo "✅ $OUT"
echo
echo "接下來要在 Xcode 裡做的（還沒自動化）："
echo "  1. 把 PDFium.xcframework 拖進專案，Embed 選 **Embed & Sign**"
echo "     （只 Link 不 Embed 的話，開發機上跑得動、裝到裝置上一開就閃退）"
echo "  2. Mac Catalyst 目標仍然沒有可用的二進位檔，見這支腳本開頭的說明"
