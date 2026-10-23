# 接手清單：跨頁拖曳與「物件跑到上一頁」修正（2026-10-23）

給接手的 AI／開發者。先讀「背景」，再依優先序處理「未完成工作」。回報一律用**繁體中文**（使用者偏好）。

---

## 背景（已完成、已推送）

分支 `fix/android-parity-and-samples`，已推送到 `origin`，HEAD = `0d098056`，本機與遠端一致。

| 提交 | 內容 |
|---|---|
| `5092d6ff` | **根因修正**：另一台裝置搬頁／刪頁後同步回來，`NotebookSyncCoordinator.preservingLocalChanges` / `keepNewerLocalObjects` 保留本機物件時連舊頁碼一起保留，物件落到錯的頁。改為經頁面 id 換算（`LocalPages`）；`NotebookDocument.realignPageKeyedObjectLists()` 在開啟與匯入時修復錯位的 `objectOrderByPage` / `underInkObjectIdsByPage` / `lockedObjectIdsByPage`。Android 單頁模式查不到頁 id 時不再退回第一頁。 |
| `006c2272` | **跨頁拖曳**：核心新增 `DocOp::MoveToPage`（op 39）、FFI `move_to_page`、`land_on_page`；Apple 與 Android 連續模式物件可拖到別頁；Apple 匯出時對「別台寫的物件」寫入搬頁。 |
| `836e6343` | Apple：連續模式文字框拖不動（點兩下手勢搶觸控）→ 改 `highPriorityGesture`；形狀、表格放開時補上推回可列印範圍；UI 測試參數 `KAIRUMO_UITEST_SEED_TWO_PAGES=1`。 |
| `9313fcca`（經 `0d098056` 合併） | Android：另存／分享、還原到初始狀態改用筆記 id；辨識手寫改用目前頁。 |

已驗證：核心 `cargo test`（padnote-core 611、padnote-doc 93）、Apple 單元測試 879（1 個本來就跳過）、Android 單元測試 177 全過；**Apple** 已在 iPad Pro 13" 模擬器實測圖片、文字框、形狀、表格拖到第 2 頁，放開後與重開後都在第 2 頁。

關鍵檔案：
- 核心：`crates/padnote-doc/src/ops.rs`（op 39）、`crates/padnote-core/src/app.rs`（`apply_move_to_page`、`move_to_page`）、`crates/padnote-core/src/ffi_geometry.rs`（`land_on_page`）
- Apple：`apple/Sources/TextBoxMetrics.swift`（`PrintableArea.land`、`PageCrossing`）、`apple/Sources/NotebookEditorView.swift`（`pageCrossing(for:)`、`finishPageCrossing`、`moveShapeGroup`、`moveTable`）、`apple/Sources/NotebookPackageBridge.swift`（`applyForeignEdits` 的 `pageMoves`）、`apple/Sources/NotebookSyncCoordinator.swift`（`LocalPages`）
- Android：`android/app/src/main/java/com/kairumo/padnote/canvas/PageCrossing.kt`、`canvas/ContinuousPages.kt`（`moveObjectToPage`、`canMoveAcrossPages`）、`image/ImageLayer.kt`、`text/TextBoxLayer.kt`、`table/TableLayer.kt`、`shape/ShapeLayer.kt`、`chart/ChartLayer.kt`
- 測試：`apple/Tests/PageObjectsReopenTests.swift`

---

## 未完成工作（依優先序）

### 1. Android 跨頁拖曳實機／模擬器驗證 —— **未完成，最優先**

**目標**：Android 連續模式下，把圖片、圖表、文字框、表格、形狀各拖到第 2 頁，確認放開後留在新頁、App 完全關閉重開後也還在。拖不動或會彈回就修掉。

**已備好的工具**：
- 未提交的測試筆記產生器：`android/app/src/androidTest/java/com/kairumo/padnote/canvas/CrossPageDragFixture.kt`。只在帶 `-e seedCrossPage true` 時執行；建立 id 為 `uitest-crosspage` 的兩頁筆記，第 1 頁**底部**（y=1000）放五種物件。
- 用法：
  ```bash
  scripts/gradle.sh :app:installDebug :app:installDebugAndroidTest
  adb shell am instrument -w -e seedCrossPage true -e class com.kairumo.padnote.canvas.CrossPageDragFixture com.kairumo.padnote.test/androidx.test.runner.AndroidJUnitRunner
  adb shell am start -n com.kairumo.padnote/.MainActivity --es open_notebook_id uitest-crosspage
  ```
  打字模式：點 `portal.type`；連續／單頁切換：`editor.page.display_mode`（以 `adb shell uiautomator dump` 取座標）。
- 目前開著的是手機模擬器 `kairumo35`（顯示 1200×1920，density 240）。平板 `kairumo_tablet` 已關。

**已知障礙（平板模擬器，與跨頁邏輯無關，已確認拿掉新加的 `zIndex` 後仍然發生）**：
- 橫向：連續模式在打字模式下單指捲動後，頁面被畫到工具列上方、下方空白，點擊也落到錯位的頁面上（曾因此誤新增一個文字框，已刪除）。
- 直向：`editor.canvas` 只有約 633×1187 像素，頁面沒有縮到畫布寬度，被裁切；轉向後縮放比例沒有重新計算。
- 可能與每頁的 `InkSurfaceView`（`ink/InkCanvas.kt`，SurfaceView）在可捲動、有 `graphicsLayer` 縮放的 `LazyColumn` 裡有關，模擬器用軟體 Vulkan（lavapipe）。**這些應另開議題調查**，不要混進本項。
- 建議：先試手機模擬器（直向、無側欄）；仍不行就改用實機，或以 `uiautomator` 取座標、以資料檔（核心套件）為準來驗證，而不是靠截圖。

**驗收**：五種物件的頁碼在拖曳後與重開後都是第 2 頁（可再寫一個 `seedCrossPage` 類似開關的儀器測試讀出核心套件裡各區塊的頁面 id 來確認）。完成後決定 `CrossPageDragFixture.kt` 要提交還是刪除。

### 2. Android 文字框是否有和 Apple 一樣的拖曳問題 —— 未驗證

Apple 的文字框因「點兩下」手勢先等第二下，捲動搶走拖曳。Android 的 `text/TextBoxLayer.kt` 是兩個獨立 `pointerInput`（`detectTapGestures(onTap, onDoubleTap)` 與 `detectDragGestures`），理論上不會互相阻擋，但**沒實測**。併入第 1 項一起驗。

### 3. 發布注意事項 —— **發版前必看**

- 新增的 `MoveToPage` 是 **op 39**。舊版 App 讀到未知 op 會**整份 oplog 拒絕**（`UnknownOp`），與先前新增 op 相同：**Apple 與 Android 必須同一版發布**，否則舊版裝置打不開被搬過物件的筆記。
- 目前版本號仍是 v5.12.11（build 121），**還沒為這批修改升版**。升版用 `scripts/bump-version.sh`。
- 使用者原始案例的筆記「交大論文教學」：新版開啟時會自動修復錯位的名單。**需在使用者 iPad 上（TestFlight 新版）確認**物件回到正確頁、可拖回第 2 頁。

### 4. 雲端搬移的推送被擋 —— 需要使用者動作

使用者要求執行以下指令，兩次都被 Claude Code 的 auto 模式權限檢查以「Data Exfiltration」擋下，**沒有執行**：
```bash
git push --no-follow-tags https://github.com/hauchiehlin-ops/Kairumo.git +c8ff252fb3e1a78d8184f5fa656181f5f703cd89:refs/claude-teleport/188616cc4c5d6eb0
```
需使用者自行在 repo 根目錄執行，或在設定中加入允許規則後再交辦。不要嘗試繞過。

### 5. 已知限制（刻意不做，可視需要再改）

- 表格裡有手寫筆跡時不跨頁（筆跡屬於頁面，跟不過去）。
- 形狀群組連到群組外形狀時不跨頁；Android 上群組成員一律不跨頁。
- 核心 `MoveToPage` 只搬根層單一物件：**別台裝置寫的、在群組裡的形狀**，在 Apple 上換頁後下一輪同步可能被拉回原頁。
- Android 跨頁搬動不能用「復原」退回（換頁後兩頁的復原基準會重設）。
- 單頁模式維持舊行為：只夾在本頁，不跨頁。

### 6. 順手發現、尚未處理的小問題

- Apple `NotebookStore.addPage` / `insertPage` 把新頁的 `pageHeights` 寫成 **1800**（A4 頁高是 1132），讓設定頁的「重新分頁」按鈕一直顯示（`needsRepagination` 判定為真）。不會搬動物件頁碼，但屬錯誤資料。
- Apple 模擬器上，App 重開後顯示模式回到單頁（連續模式沒記住）——只觀察到一次，未確認是否與測試啟動參數有關。

---

## 工作習慣（本專案）

- 回報用繁體中文。
- 提交訊息結尾加 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`。
- 改了 FFI 要重建：`scripts/build-xcframework.sh`（Apple）與 `scripts/build-android-libs.sh`（Android 原生程式庫＋綁定）；產生的綁定與原生庫不進版控。
- Android 編譯／測試：`scripts/gradle.sh :app:compileDebugKotlin :app:testDebugUnitTest`（產物在 `~/Library/Caches/Kairumo/gradle/<hash>/build/app/`，不在 repo 內）。
- Apple 測試：`xcodebuild test -project apple/Kairumo.xcodeproj -scheme Kairumo -destination "id=<iOS 模擬器>" -only-testing:KairumoTests`；新增測試檔後先 `cd apple && xcodegen generate`。
- 磁碟是 exFAT，git 會出現 `._*` 附屬檔造成的 `non-monotonic index` 訊息，pre-commit hook 會自動清除，可忽略。
