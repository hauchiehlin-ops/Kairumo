#!/usr/bin/env bash
# 清掉 .git 底下 macOS 在 exFAT 上產生的 `._*`（AppleDouble）附屬檔。
#
# 這些檔案 git 不會用，但 `._pack-*.idx` 之類會讓 git 每個指令都噴
# `non-monotonic index` 錯誤。只刪檔名以 `._` 開頭的一般檔案，
# 不碰任何真正的 git 物件。由 .githooks/pre-commit、pre-push 呼叫，也可手動執行。
set -euo pipefail

GIT_DIR="$(git rev-parse --git-dir 2>/dev/null)" || exit 0
n=$(find "$GIT_DIR" -name '._*' -type f 2>/dev/null | wc -l | tr -d ' ')
if [[ "$n" -gt 0 ]]; then
    find "$GIT_DIR" -name '._*' -type f -delete 2>/dev/null || true
    echo "🧹 已清除 .git 內 $n 個 macOS ._ 附屬檔"
fi
