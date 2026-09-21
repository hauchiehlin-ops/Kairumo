# 雲端同步改善計畫（Google Drive 跨平台）

> **狀態：P0–P4 已於 2026-09-21 全部實作完成**（commits `4888968`、`e68096a`、
> `11c948d`、`446ea1d`）。實作細節見 `docs/DEVLOG.md` 2026-09-21 那一筆；
> 規格落在 `docs/format-spec.md` §7.4–7.9；**尚未實機驗證的項目**在
> `docs/TODO.md` 的 H-SYNC。這份文件留作決策紀錄，不再更新。

診斷對象：`crates/padnote-sync`、`crates/padnote-core/src/ffi_gdrive.rs`、
`apple/Sources/NotebookSyncCoordinator.swift`、`android/.../library/CloudSync.kt`。
目標：即時、迅速、正確、穩定，四項都要，而且兩個平台同一套規則。

---

## 0. 先釐清「以存檔時間為戳記」這件事

使用者描述的模型是對的，但**戳記不能用存檔時間（牆上時鐘）**：

- Apple 與 Android 的檔案時間精度不同，Drive 回的 `modifiedTime` 又是
  **上傳時間**而非編輯時間。三個時間沒有一個對得起來。
- 裝置時鐘差幾分鐘是常態。用牆上時間比大小，「時鐘快的那台」永遠贏，
  使用者在慢的那台寫的東西會無聲消失。

核心用的是 **Lamport 邏輯時戳 + 檔案長度**（append-only ⇒ 較長者是超集），
那是正確的選擇。改的是「怎麼知道哪些檔案變了」這一層。
牆上時間只留給**顯示**，不參與任何比較。

---

## 1. 現況診斷

### 1.1 每一輪同步都在重新盤點整個雲端（慢的根因）

`gdrive_sync_notebook` 的第一件事是 `drive.list(prefix)`，而它會打一次
Drive `files.list`（`name contains`）—— **每一本筆記本一次 HTTP 列舉**。
20 本筆記 20 次往返，而其中 20 次的答案都是「沒事」。上傳既有檔案更貴：
`put` 會先 `find_file_id`，那又是一次列舉。

Drive 早就有正確的工具：`changes.list` + `startPageToken`。Joplin、
Obsidian Sync、rclone 的 Drive 後端全部走 delta，沒有人每次列整棵樹。

另外，`padnote-sync::SyncEngine` 那套增量游標**只有測試在用**，
正式的 Drive 路徑完全沒走它。

### 1.2 觸發點太少

Apple 端有「App 進前景」與首頁三顆按鈕；Android 端有「回到首頁」與選單。
缺的是：寫入後去抖動推送、前景週期拉取、網路恢復、登入完成、背景任務。
使用者在編輯器裡寫完一段切到另一台，什麼也不會發生。

### 1.3 一個會掉資料的順序錯誤

`gdrive_sync_notebook` 的順序是：壓實 → 列舉 → **刪除雲端舊碎檔** → 上傳。
中間斷網、逾時或被系統殺掉，那些操作就只剩本機一份，而且沒有任何錯誤訊息。

同一段的第二個隱患：「這個雲端碎檔已被涵蓋」是用
`lamport < 本機該裝置最大 lamport` **推論**出來的。壓實是本機行為，
本機可能根本沒下載過中間那個碎檔 —— 刪掉的是一份自己從來沒有過的操作。

### 1.4 `manifest.json` 永遠收斂不了

`plan_folder_sync` 把它丟進 `needs_attention`，於是每次同步都跳一句
「需要注意」，而使用者無論做什麼都不會消失。

### 1.5 跨平台差異盤點

| 面向 | Apple | Android | 風險 | 共通基準 |
|---|---|---|---|---|
| 檔名大小寫 | APFS 預設**不分** | ext4/f2fs **分** | 已經爆過（uuid case mismatch） | 雲端物件名一律 ASCII 小寫，核心單一函式產生 |
| Unicode 正規化 | 歷史上 NFD | NFC | 一個中文字進路徑就對不上 | 雲端路徑只准 `[0-9a-z._/-]`，標題放 JSON 內容 |
| 套件形態 | package，可能有 iCloud 佔位檔 | 就是目錄 | `NotMaterialized` 只有 Apple 處理 | 資料夾同步兩邊都要處理「還沒下載」 |
| 原子寫入 | 同容器 rename 原子 | SAF 不保證 | 半個檔是**合法**的 append-only 前綴 | 一律 `.part` → fsync → rename |
| 背景執行 | iOS 直接凍結 | Doze | 沒有背景同步 | 排程策略下沉核心，平台只提供喚醒 |

結論：**雲端上的一切由核心決定，平台層只負責搬位元組。**

---

## 2. 改善計畫（四階段）

| 階段 | 內容 | 效果 |
|---|---|---|
| P0 | 路徑單一來源、`write_atomic`、身分規則寫進 format-spec | 兩平台不再互相打架 |
| P1 | change token + `RemoteIndex`，同步計畫全在本機算 | 無變動的一輪 = 1 次 HTTP |
| P2 | `SyncScheduler` 下沉核心 + 兩平台對齊觸發點 + 背景任務 | 即時 |
| P3 | 刪除順序、壓實範圍明示化、manifest 規則、錄音節流 | 正確 + 穩定 |
| P4 | 同步醫生 + 一致性測試 | 不再退化 |

---

## 3. 明確不做的事

- 不架伺服器、不做 `changes.watch` 的 webhook（需要公開端點，違反 D5）。
  用輪詢 `changes.list` 取代，P1 之後成本已經夠低。
- 不改 Lamport / CRDT 收斂規則 —— 那一層是對的。
- 不引入 Google Play Services 原生登入（會多背一個依賴）。
