#!/usr/bin/env bash
#
# 取得 libpdfium 執行期庫（docs/TODO.md H8）。
#
# # 為什麼需要這個
#
# `pdfium-render` 只是 Rust 綁定，**裡面沒有 PDFium 本身**。少了動態庫，
# `Pdfium::bind_to_system_library()` 會在執行期失敗 —— 而編譯完全不會報錯。
# 症狀是「開發機上跑得好好的，打包出去打不開任何 PDF」。
#
# # 來源與信任
#
# 用 bblanchon/pdfium-binaries 的預建版（Google 沒有發佈官方二進位檔）。
# 版本**釘死**、雜湊**逐一驗證**，與 models/manifest.json 同一套規矩：
# 沒有驗證過的 URL 等於沒有。
#
# PDFium 本身是 BSD-3-Clause（Google），打包腳本是 Apache-2.0。
# 兩者都相容於本專案的 Apache-2.0。授權原文會一起抓下來。
#
# # 抓下來的東西不進版控
#
# 每個平台 3～4 MB，而且是可以重抓的衍生物。輸出目錄在 .gitignore 裡。
# 要不要隨 App 一起出貨是另一個決定 —— 這個腳本只負責把東西弄下來並驗過。
#
#   ./scripts/fetch-pdfium.sh              # 這台 Mac 需要的（mac-arm64）
#   ./scripts/fetch-pdfium.sh all          # 全平台
#
set -euo pipefail

# 釘死版本。改版要連同下面的雜湊一起換 —— 只改版本號會讓驗證失敗，
# 那是刻意的：悄悄換掉一個會進到使用者裝置裡的二進位檔，不該只是改一行。
RELEASE="chromium/8057"
BASE="https://github.com/bblanchon/pdfium-binaries/releases/download/${RELEASE}"
OUT="${PDFIUM_DIR:-$(cd "$(dirname "$0")/.." && pwd)/third_party/pdfium}"

# 檔名 與 SHA-256。`pending` 的會被拒絕，不是靜默通過。
#
# 用函式而不是關聯陣列：macOS 內建的是 **bash 3.2**（2007 年），
# `declare -A` 在那裡直接是語法錯誤，而錯誤訊息（"unbound variable"）
# 完全不會指向這裡。
sha_for() {
  case "$1" in
    pdfium-mac-arm64.tgz)          echo "013ecc9e0a155dabb8dd006a73a028ea542965f80a4990e5f013de283b0e58a6" ;;
    pdfium-mac-x64.tgz)            echo "d726dc3d81445555f92bbee44577c53a9fb6425e1194cfd630403d6840d9ecbf" ;;
    pdfium-ios-device-arm64.tgz)   echo "07f9ef09c6028ebe42f6ff6f2946c26270bdde8d4d51745b81a366cb65ff971d" ;;
    pdfium-ios-simulator-arm64.tgz) echo "1921532106242e36d9e805b46efe03c9d89b16b35adca7c091d1ce92942859a5" ;;
    pdfium-android-arm64.tgz)      echo "78e93fe31a7f77f73e4339ae878a9b0a19a0ed5e9a3b6a4b61c0c595cbebcebc" ;;
    pdfium-android-arm.tgz)        echo "a8e53a24e190d87735ded9b5d6e5bb91bd25a1191a64a38131c5839eab1e4355" ;;
    pdfium-android-x64.tgz)        echo "3d031045e48d392877c12d4805f1f63132107fcb739059bc6018f1cc0d81eb5a" ;;
    *)                             echo "" ;;
  esac
}

ALL="pdfium-mac-arm64.tgz pdfium-mac-x64.tgz pdfium-ios-device-arm64.tgz \
pdfium-ios-simulator-arm64.tgz pdfium-android-arm64.tgz pdfium-android-arm.tgz \
pdfium-android-x64.tgz"

if [ "${1:-}" = "all" ]; then
  targets="$ALL"
else
  targets="pdfium-mac-arm64.tgz"
fi

mkdir -p "$OUT"
for name in $targets; do
  expected="$(sha_for "$name")"
  if [[ -z "$expected" ]]; then
    echo "❌ $name 不在清單裡" >&2
    exit 1
  fi

  archive="$OUT/$name"
  if [[ ! -f "$archive" ]]; then
    echo "==> 下載 $name"
    curl -fsSL "$BASE/$name" -o "$archive"
  fi

  actual="$(shasum -a 256 "$archive" | cut -d' ' -f1)"
  if [[ "$expected" == "pending" ]]; then
    # 第一次取得時用來填表。**不要**讓它就這樣過 —— 否則這個腳本
    # 對「檔案被換掉」毫無防禦力，而那正是它存在的理由。
    echo "❌ $name 的雜湊尚未登錄。實際值："
    echo "   $name → $actual"
    echo "   把它填進這個腳本的 SHA 表裡再跑一次。"
    exit 1
  fi
  if [[ "$actual" != "$expected" ]]; then
    echo "❌ $name 雜湊不符" >&2
    echo "   期望 $expected" >&2
    echo "   實際 $actual" >&2
    exit 1
  fi

  dir="$OUT/${name%.tgz}"
  rm -rf "$dir"
  mkdir -p "$dir"
  tar -xzf "$archive" -C "$dir"
  echo "✅ $name  →  $dir"
done

echo
echo "libpdfium 在：$OUT"
echo "macOS 上要讓 Pdfium::bind_to_system_library() 找得到，執行前設定："
echo "  export DYLD_LIBRARY_PATH=\"$OUT/pdfium-mac-arm64/lib:\$DYLD_LIBRARY_PATH\""
