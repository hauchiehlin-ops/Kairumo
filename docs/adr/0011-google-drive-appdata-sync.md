# ADR-0011：Google Drive appDataFolder 自動同步

- 狀態：**已接受**（2026-09-15）
- 決策：D-11
- 取代：D-03 的雲端實作優先序
- 相關：`docs/architecture.md` §4、`docs/format-spec.md` §7、`docs/TODO.md` §Google Drive 自動同步

## 背景
產品目標改為：使用者只要在不同作業平台或設備登入同一個 Google 帳號，
應用程式內的筆記本、資料夾結構與可同步設定都應自動收斂到同一個狀態。

原本的同步路線偏向「使用者自己選一個雲端資料夾」。那條路透明、容易除錯，
但體驗上不是帳號式同步：每台裝置都要選資料夾，還要處理 SAF/security-scoped
bookmark 權限存活，使用者也可能手動移動或刪掉同步檔。

Google Drive API 的 `appDataFolder` 是專給 app 存放應用程式資料的隱藏空間。
它只允許建立該資料的 app 存取，適合放設定檔與同步狀態，不適合作為使用者
手動管理檔案的地方。

## 決策
正式自動同步採用 **Google Drive `appDataFolder` + `drive.appdata` scope**。

同步內容：
- 所有筆記本與資料夾結構
- 可跨裝置一致的 app 設定：語言、工具列配置、預設筆刷、協同身分
- 同步游標、裝置資訊、刪除墓碑與重新命名/移動 oplog

不同步內容：
- 本機索引與快取（可重建）
- 裝置能力相關設定：低延遲開關、觸控筆/掌拒門檻、Android SAF 權限
- App Store / Play Console 帳號外部狀態

既有「選擇同步資料夾」保留，但定位改為手動備份、匯入匯出與進階使用者備援，
不是主要同步路徑。

## 設計約束
- 仍維持 local-first：離線可完整編輯，背景同步只做最終一致。
- Drive 只是啞檔案桶：不解析筆記內容，不做合併邏輯。
- Google Drive 沒有 append API，所以 provider 回報 `supports_native_append() = false`，
  同步引擎以每次新增 chunk 檔退化處理。
- 同一個 Google 帳號不等於同一台裝置：每次 app 安裝都要有穩定 device id，
  每台裝置只寫 `sync/<device_id>/`。
- 刪除、重新命名、資料夾移動必須是 oplog 事件或 tombstone，不能靠檔案覆蓋推論。

## 後果
- 需要 Google OAuth client 設定與跨平台登入流程。
- 需要 token refresh、登出、權限撤銷與重新授權處理。
- 需要實機測試 appDataFolder 在 Android/iOS/macOS 的背景同步與離線行為。
- 隱私文案要明確說明：筆記資料存放在使用者自己的 Google Drive app data，
  Kairumo 沒有後端伺服器；若啟用端對端加密，雲端只看到加密 chunk。
