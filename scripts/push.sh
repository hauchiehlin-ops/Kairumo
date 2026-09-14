#!/usr/bin/env bash
#
# scripts/push.sh（已停用）
#
# 這支腳本原本會自動 patch 升版、git add -A 全部提交、打 tag 再推送。
# 已停用，因為版本號改由 ./scripts/release.sh 單一入口負責 ——
# 多個入口各自升版，正是 2.8.0 (20) 那顆 TestFlight 裝不起來的 build 的來源。
# 它的 git add -A 也會把工作目錄裡所有東西一起包進一個 release commit。
#
set -euo pipefail

cat >&2 <<'MSG'
⛔ scripts/push.sh 已停用。

  要發版（升版 + 兩平台打包 + 上傳）：
      ./scripts/release.sh [patch|minor|major]

  只是要推送一般改動（不升版）：
      git push

版本號現在只有 release.sh 會動。
MSG
exit 1
