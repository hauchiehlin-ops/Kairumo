# 雲端協作（跨網路一鍵連線）— 交接工作清單

> 交接對象：Antigravity
> 分支：`claude/cloud-collab`（工作樹：`/Volumes/Mobil/GitMobil/Kairumo-cloudcollab`）
> 基準：`main` 已合併 PR #195（形狀把手、編修面板避讓、協同 QR、Mac 錄音、色調、吸附格線）
> 規範：一律遵守 `AGENTS.md` 五大守門；提交前跑 `./scripts/sop-verify.sh`

---

## 0. 背景與目標

使用者回報「線上協同兩個連結都連不上」。實測找出四個根因：
1. Tailscale 連結要雙方都開 Tailscale，實測客端裝置離線。
2. v6.4.8 沒註冊 `kairumo://` 邀請連結（PR #195 已修）。
3. 加入要好幾步（開筆記 → 開面板 → 貼連結 → 按加入）。
4. **最嚴重**：客端沒有房主那本筆記；協同只傳開會後的新操作，頁面 id 對不上，客端什麼都看不到。

使用者核准的方案（四階段全做、Apple 與 Android 都要）：
- 房主把筆記放進**自己 Google 雲端硬碟的一般資料夾**（`drive.file` 權限），分享給協作者（編輯者）。
- 雲端資料夾 = 共同底稿與跨網路通道；同一網路時自動加上區網中繼（混合模式）。
- 延遲優化：本機優先、自適應輪詢、合併送出、在場檔；再加 WebRTC 點對點直連。

---

## 1. 已完成（本分支，**尚未提交前全部未經完整 SOP 驗證**）

### Rust 核心（已通過單元測試與 clippy）
| 檔案 | 內容 |
|---|---|
| `crates/padnote-sync/src/gdrive.rs` | `DriveSpace { AppData, Folder(id) }`；查詢、`spaces`、建立檔案的父資料夾都依空間決定；共享資料夾的變更清單依 `parents` 過濾；新增 `create_folder`、`grant`、`grant_anyone_with_link`、`members`、`revoke`、`probe_folder` |
| `crates/padnote-core/src/ffi_gdrive.rs` | `FfiSyncSession::create_shared(http, folder_id, index_json)`；`put_aux`／`read_aux`（在場檔、信令檔）；`ForeignHttp` 改 `pub(crate)` |
| `crates/padnote-core/src/ffi_cloud_collab.rs`（新） | 分享操作 FFI、權限探測 `collab_drive_probe`（`FfiDriveAccess`）、挑選器授權網址 `oauth_collab_authorize_url`（`trigger_onepick=true`、`file_ids=`）、`oauth_parse_picked_ids`、邀請連結 v2（`collab_invite_link_v2`／`collab_parse_invite_v2`，向下相容 v1）、`collab_order_servers`、`collab_cloud_poll_ms`（自適應輪詢）、`collab_cloud_flush_delay_ms`、在場檔 encode/decode/path、共享筆記清單（registry）函式。8 項測試通過 |
| `crates/padnote-core/src/ffi_p2p.rs`（新，feature `p2p`） | webrtc-rs 0.10：`p2p_new_link`、`FfiPeerLink.create_offer／accept_offer／apply_answer／send／close`、`FfiPeerListener`（平台實作）、`p2p_signal_path`、`p2p_should_offer`。**同行程兩端回環測試通過（真的建立連線並收到訊框）** |
| `crates/padnote-core/src/ffi_p2p_frames.rs`（新） | 點對點訊框（事件檔 `KOP1`、在場 `KPR1`）、`package_op_file_sizes`／`package_read_op_file`／`package_ingest_op_file`（只在變長時寫入、擋路徑逃逸）。測試通過 |
| `crates/padnote-core/Cargo.toml` | 新 feature `p2p = [webrtc, tokio, bytes]`，加入 `default` |
| `scripts/build-xcframework.sh`、`build-android-libs.sh`、`generate-bindings.sh` | 三處都加上 `p2p` feature |

### Apple（**編譯中，尚未確認通過**）
- `apple/Sources/CloudCollab.swift`（新）：`CollabKeychainTokens`（獨立 Keychain 帳號 `collab-drive-tokens`）、`CollabDriveAuth`（`ASWebAuthenticationSession`＋挑選器）、`CloudCollabManager`（分享、加入、自適應輪詢迴圈、在場、P2P 信令與事件檔推送、`importReceived` 匯入）。
- `apple/Sources/CloudCollabViews.swift`（新）：協同面板的 `CloudShareSection`、一鍵加入 `CloudCollabJoinSheet`／`CloudCollabInviteHost`、編輯器 `CloudPresenceBar`。
- 掛勾：`FocusSyncController.setFocus／noteLocalEdit`、`HomeWorkbenchUsage` 的 `onOpenURL` 與 `.modifier(CloudCollabInviteHost())`、`CollaborationSheet` 插入 `CloudShareSection`、`EditorCanvasContainer` 加在場列、`NotebookEditorView` 回報頁碼／選取、`ProfileManager.defaultParticipants` 加入兩個單例。
- `DriveHttpClient` 可注入 `refresher`（協作憑證換證失敗不會登出主帳號）。
- `NotebookSyncCoordinator.importSharedClone(...)`（協作者整本下載後匯入書庫）。
- 已跑 `xcodegen generate` 把新檔加進專案。

### Android（**尚未編譯**）
- `collab/CollabDriveAuth.kt`（新）：加密偏好儲存、Custom Tabs 授權／挑選器、`ownsState` 分辨重導向。
- `collab/CloudCollab.kt`（新）：與 Apple 同規則的管理器（分享、加入、輪詢、在場、P2P、`connectRelay`）。
- `collab/CloudCollabUi.kt`（新）：`CloudShareSection`、`CloudJoinHost`、`CloudPresenceBar`、`CloudQrCode`。
- 掛勾：`OAuthRedirectActivity`（依 state 分流）、`FocusSync`（init、焦點、編輯、前景／背景）、`MainActivity`（`CloudCollab.offer` 優先、`CloudJoinHost`）、`CollaborationSheet`（插入區塊、`notebookTitle` 參數）、`EditorFloatingPanels`（在場列、回報頁碼）、`EditorCanvasContext`（自動接上中繼、`relayConnected`）。

### 多語系
- `i18n/ui-strings.json` 新增 `cloud_collab_*` 共 31 鍵（六語系），已跑 `python3 scripts/i18n_tool.py generate`。

---

## 2. 待執行工作清單（依順序）

### A. 讓兩個平台編譯通過
- [ ] **A1** 確認 Android 原生庫重建完成：`./scripts/build-android-libs.sh`（`KAIRUMO_ANDROID_FEATURES` 預設已含 `p2p`）。綁定已由 `generate-bindings.sh` 產生到 `android/app/src/main/java/uniffi/`。
- [ ] **A2** Apple：`cd apple && xcodebuild -scheme Kairumo -destination 'platform=macOS,variant=Mac Catalyst' build`，修正所有編譯錯誤。重點檢查：
  - `CloudCollab.swift` 裡 `nonisolated(unsafe) var data` 的寫法、`Task.detached` 捕捉 `FfiSyncSession` 的 Sendable 警告。
  - `PeerListener.onFrame(frame:)` 參數型別（uniffi 產生的是 `Data`）。
  - `FfiSharedNotebook` 欄位是否為 `var`（`entry.roomId = …`）。
  - `NotebookSyncCoordinator.FocusReport` 的存取層級（`CloudCollabManager` 有用到）。
- [ ] **A3** Android：`./scripts/gradle.sh compileDebugKotlin`，修正錯誤。重點檢查：
  - `FfiPeerListener.onFrame(frame: ByteArray)` 的簽章、`FfiP2pFrame` sealed class 的成員名稱。
  - `FfiSharedNotebook.copy(...)`（uniffi 的 data class 才有 copy）。
  - `ProfileContext`、`AccountManager.load(...)`、`L10n.t(...)` 的套件路徑。
  - `EditorFloatingPanels` 裡 `selectedShapeIds`、`selectedImageId`、`selectedTableId` 是否存在。
- [ ] **A4** iOS 模擬器也編一次（`CloudCollab.swift` 用了 `UIApplication.shared.applicationState`）。

### B. 守門與測試
- [ ] **B1** `python3 scripts/check-profile-scope.py`：新單例已標 `profile-scope`；Apple 的 `CloudCollabManager`、`CollabDriveAuth` 標成 `profile` 並實作 `resetForProfileSwitch`，確認 `ProfileManagerTests` 的單例清單也同步。
- [ ] **B2** `check-main-thread-io.py`、`check-assume-isolated.py`（`CloudCollab.swift` 已移除 `assumeIsolated` 寫法，確認無殘留）、`check-hardcoded-strings.py`、`check-glossary.py`、`check-unused-params.py`。
- [ ] **B3** `cargo test -p padnote-core -p padnote-ink`（全部）、`cargo clippy -p padnote-core --all-targets`。注意：**不要同時跑兩組 Rust 測試**，會互搶埠與暫存檔而卡住。
- [ ] **B4** `./scripts/gradle.sh testDebugUnitTest`。
- [ ] **B5** 補單元測試：
  - Rust：`GDriveProvider` 在 `DriveSpace::Folder` 下的查詢與 `parents` 過濾（用檔內既有的 FakeDrive）。
  - Android：`CloudCollab.offer` 只認帶 `drive=` 與 `nb=` 的連結。

### C. 必須實機驗證（Google 權限的關鍵風險）
- [ ] **C1 決策閘門**：用**兩個不同的 Google 帳號**實測。房主分享後，協作者經挑選器選取資料夾，`collab_drive_probe` 是否回 `Ready`（看得到房主建立的事件檔）。
  - 若回 `ContentsHidden`：`drive.file` 不足，需要改申請 `drive` 權限（受限權限，要通過 Google 的 CASA 安全審查），或改成「每位參與者各自一個資料夾、互相選取」的設計。**這一步沒過，後面都不成立。**
- [ ] **C2** Google Cloud Console：OAuth 同意畫面加入 `drive.file` 權限；啟用 Google Picker API。確認 Apple 與 Android 的 OAuth 用戶端都允許 `trigger_onepick` 流程（Android 官方文件建議用 `AuthorizationRequest` 的 `PICKER_OAUTH_TRIGGER`；目前實作是 Custom Tabs 網址流程，需實測）。
- [ ] **C3** 隱私權政策與操作手冊更新（`build-privacy-docs.py`、`build-platform-docs.py`）：說明共享資料夾存在房主的雲端硬碟、`drive.file` 權限用途。

### D. 功能驗收（實機兩台以上，Apple 與 Android 交叉）
- [ ] **D1** 房主：協同面板 →「雲端共享（跨網路）」→ 輸入 Email 分享／或「改用連結分享」→ 出現 QR Code 與邀請連結。
- [ ] **D2** 協作者（不同網路、沒開 Tailscale）：相機掃碼或點連結 → 「加入」→ Google 確認 → 筆記自動下載並打開，**頁面與內容與房主一致**。
- [ ] **D3** 雙向編輯：雲端模式下延遲應落在約 3–8 秒（依自適應輪詢）；在場列顯示對方在第幾頁。
- [ ] **D4** 點對點：同一網路或可穿透的網路下，在場列出現 ⚡／「直連中」，延遲應降到 1 秒內；斷網後自動退回雲端。
- [ ] **D5** 混合模式：同一 Wi‑Fi 時自動接上區網中繼（即時筆跡與游標），雲端輪詢放慢到 15 秒。
- [ ] **D6** 房主撤銷成員後，對方不再同步但保留本機副本；「這台裝置不再同步這本共享筆記」可正常運作。
- [ ] **D7** 筆跡不變式（ADR-0015）：擦除在三條管道下都不會復活（I3）；畫布與縮圖同源（I4）。

### E. 已知限制與後續（可另開工作）
- [ ] **E1** 共享資料夾裡的事件檔目前**未用房間金鑰加密**（Google 看得到內容）。規劃：上傳前以 `key_base64` 加密、下載後解密。
- [ ] **E2** 信令檔（`signal/…`）不會被刪除，只會被覆寫；可加清理。
- [ ] **E3** Android 連續頁模式下的編修面板與在場列位置要再檢查。
- [ ] **E4** 打不通的 NAT（對稱型）目前直接退回雲端；若要更高成功率需 TURN（違反「不架後端」原則，需使用者決策）。
- [ ] **E5** 長時間協作的事件檔壓實（`padnote-sync/src/compaction.rs` 只有骨架）需納入共享資料夾。

---

## 3. 提交與 PR

1. 完成 A、B 後：`./scripts/sop-verify.sh` 全綠才可提交。
2. 推送：`git push -u origin claude/cloud-collab`（pre-push 門禁會跑完整驗證）。
3. 開 PR 到 `main`，內文註明 **C1 決策閘門的實測結果**，未實測不可合併。
