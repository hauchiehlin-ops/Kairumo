#!/usr/bin/env bash
# 部署 Kairumo **內建的試用中繼**（wss://kairumo-relay.kairumo-relay.workers.dev）。
#
# 內建中繼由所有 Kairumo 使用者共用一份 Cloudflare 免費額度，所以設定得比較保守：
#   - 會議室沒人之後只保留 1 天（自己部署的中繼預設 7 天，見 wrangler.toml）；
#   - 寄存的整份狀態最多 160 段（約 64 MB 內容；自己部署的預設 256 段，約 100 MB）。
# App 的卡片說明（cloud_relay_* 字串）寫的就是這兩個數字，改這裡要一起改字串。
#
# 使用者按「一鍵申請自己的中繼」部署的是 wrangler.toml 的預設值，不受這支腳本影響。
#
# 用法：在這個資料夾執行 `./deploy-public.sh`（需先 `npx wrangler login`）。
set -euo pipefail
cd "$(dirname "$0")"
npx tsc --noEmit -p .
npx wrangler deploy \
  --var RETENTION_HOURS:24 \
  --var STORE_PARTS_MAX:160
