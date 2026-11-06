# Kairumo 公開中繼（Cloudflare Workers + Durable Objects）

雲端共享（跨網路）協作用的中繼。協定與 `crates/padnote-relay`（Rust，App 內建的本機中繼）完全相同，
改協定時兩邊一起改。

- 每個房間是一個 Durable Object；連線網址帶 `?room=<房號>`（App 會自動加）。
- 使用 WebSocket Hibernation：沒有人在送訊息時不計時長費用。
- 只轉送端對端加密的內容，中繼看不到筆跡與物件。
- 斷線補發暫存放在物件的 SQLite（每房 2000 筆／32 MB，最後一人離開即清空）。

## 費用（Workers 免費方案）

- 每天 100,000 次請求；WebSocket 訊息每 20 則算 1 次（只算收到的，不算轉送出去的）。
- 超過當天額度時當天的請求會失敗，**不會自動收費**；每天 00:00 UTC 重置。
- 數字以 Cloudflare 官方頁面為準：<https://developers.cloudflare.com/durable-objects/platform/pricing/>

## 目前部署

- 網址：`wss://kairumo-relay.kairumo-relay.workers.dev`（專案擁有者的 Cloudflare 帳號）
- 實測（台灣 HiNet → 聖荷西 SJC 機房）：訊息單向延遲中位數約 150 ms。

## 一鍵部署到你自己的 Cloudflare 帳號（不用寫程式）

[![Deploy to Cloudflare](https://deploy.workers.cloudflare.com/button)](https://deploy.workers.cloudflare.com/?url=https://github.com/hauchiehlin-ops/Kairumo/tree/main/deploy/relay-cloudflare)

需要免費的 Cloudflare 與 GitHub 帳號；Cloudflare 會把這個資料夾複製到你的 GitHub 並部署。
完成後把網址的 `https://` 改成 `wss://`，貼到 App「線上協同 → 中繼伺服器位址 → 雲端共享中繼」並儲存
（App 裡的「如何取得自己的中繼位址？」有完整步驟）。只有房主需要設定，邀請會帶上這個位址。

## 額度的用法（免費方案）

- 每筆存進補發暫存的操作只寫 1 列；筆數、容量、序號放在記憶體，物件醒來時才從資料表重算一次。
- 書寫中預覽每秒送 20 次（App 端設定），每 20 則訊息才算 1 次請求。

## 用命令列部署（開發者）

```bash
cd deploy/relay-cloudflare
npm install
npx wrangler login      # 用瀏覽器登入你的 Cloudflare 帳號（第一次）
npx wrangler deploy
```

部署完成時會印出網址，例如 `https://kairumo-relay.<你的子網域>.workers.dev`。
App 用的是 `wss://` 開頭的同一個網址，填進兩個地方（兩邊要相同）：

- Apple：`apple/Sources/CollaborationManager.swift` 的 `publicRelayURL`
- Android：`android/app/src/main/java/com/kairumo/padnote/collab/CollaborationManager.kt` 的 `PUBLIC_RELAY_URL`

## 本機測試

```bash
npx wrangler dev --port 8799
# 另一個終端機：瀏覽 http://127.0.0.1:8799/ 會看到 "Kairumo relay"
```

## 設定

`wrangler.toml` 的 `[vars]`：

- `MAX_PEERS`：每間房的人數上限（預設 16）。
