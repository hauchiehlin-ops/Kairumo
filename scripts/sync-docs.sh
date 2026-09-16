#!/usr/bin/env bash
#
# scripts/sync-docs.sh
# 把 docs/ 底下要給使用者看的文件同步進 App 的資源目錄。
#
# 為什麼需要這支腳本：
# apple/Resources/Docs 原本是**手動**複製的。改了 docs/ 卻忘了複製的話，
# App 裡顯示的仍然是舊版 —— 而且兩邊都看不出來，因為兩份檔案都存在。
# 這與 Android 綁定那次是同一類漂移。
#
# 只複製 manual/ 與 legal/。DEVLOG、TODO、ADR 是開發文件，
# 打包進 App 等於把內部紀錄發給使用者（那個 bug 修過一次了）。

set -euo pipefail

# 腳本輸出含中文。使用者的終端機若不是 UTF-8 locale，內嵌 python3 印中文會
# UnicodeEncodeError 直接中止（實際踩過）。強制輸出編碼，與終端機 locale 脫鉤。
export PYTHONIOENCODING=utf-8

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_MANUAL="$ROOT/docs/manual"
SRC_LEGAL="$ROOT/docs/legal"
DEST="$ROOT/apple/Resources/Docs"
# **Android 不在這裡處理。** 它用 Gradle 的 copyUserDocs 在建置時從 docs/
# 直接複製進 assets —— 那樣 repo 裡不會有第二份副本。這支腳本再複製一次的話，
# 兩份會在 mergeAssets 階段撞成 "Duplicate resources" 而整個建置失敗（踩過）。

mkdir -p "$DEST"

echo "==> 同步操作手冊"
cp "$SRC_MANUAL/index.html" "$DEST/manual.html"
cp "$SRC_MANUAL/manual.js" "$DEST/manual.js"
rm -rf "$DEST/img"
cp -R "$SRC_MANUAL/img" "$DEST/img"

echo "==> 同步文件範本目錄"
# 範本目錄是**產物**（由 templates/src/ 排版而來），所以先重建再複製 ——
# 只複製的話，改了 src 卻忘了跑 build，App 裡就是舊的範本。
python3 "$ROOT/scripts/doc_templates_tool.py" build
mkdir -p "$DEST/../Templates"
cp "$ROOT/templates/document-templates.json" "$DEST/../Templates/document-templates.json"

echo "==> 同步隱私權政策"
cp "$SRC_LEGAL/privacy.html" "$DEST/privacy.html"

# 沒有 charset 宣告的話，WKWebView 載入本機檔案時只能猜編碼，
# UTF-8 的中文就會變成一堆亂碼 —— 使用者實際回報過這件事。
echo "==> 檢查編碼宣告"
for file in "$DEST/manual.html" "$DEST/privacy.html"; do
    if ! grep -qi '<meta charset="utf-8">' "$file"; then
        echo "❌ $file 缺少 <meta charset=\"utf-8\">，App 裡會顯示成亂碼" >&2
        exit 1
    fi
done

echo "==> 完成"
ls -1 "$DEST"
