# 交接：模組管線守門與 UX 流程優化（2026-10-27）

分支：`claude/trusting-sammet-4649b4`（基於 origin/main c19fe460 + origin/fix/android-parity-and-samples）
**尚未 push。** 提交：`1ac9dc1` 飛梭工具盤自訂、`edc77ef` 手冊、`62701e0` P0 守門＋旅程測試。

## 已完成

- 飛梭工具盤可自訂（核心 `crates/padnote-toolbar/src/radial.rs`，2–8 格，跟帳號同步；Apple／Android 設定畫面都有）。
- 守門腳本 `scripts/check-state-entrypoints.py`（已掛 pre-push 與 CI）：換工具、切模式只准走正門
  （Android `applyInkTool`；Apple `applyEditorTool`／`selectEditorTool`、`transitionToMode`），正門那一行標 `// state-entry:`。
- 修掉的斷鏈：Android 主工具列與 Ctrl+數字繞過 `applyInkTool`（單頁模式選橡皮擦還在畫）；Apple 兩份「插入／更多」選單分岔
  （iPad 全寬版找不到自訂工具列等 7 項）；Android 畫布 `strokes:N` 讀數不會更新、連續模式沒有讀數；
  Android 工具列叫出的飛梭工具盤位置錯；Android 飛梭「平滑防抖」標籤用錯字。
- 旅程測試：Android `screens/UserJourneyTest.kt`（3 條，平板模擬器全過；放回舊 bug 會紅）、
  Apple `UITests/UserJourneyUITests.swift`（2 條；橡皮擦旅程已過，**飛梭自訂旅程在選單合併後尚未重跑確認**）。

## 待辦（依優先序）

### P0 收尾
1. 重跑 Apple `UserJourneyUITests`，確認 `testCustomizedRadialMenuIsWhatTheMenuShows` 通過
   （上一次失敗原因是 iPad 全寬版選單沒有「自訂工具列」，已合併選單修正）。指令見下方「環境」。
2. 既有稽核測試把斷言包在「找得到按鈕才檢查」裡（`InkInvariantMatrixAudit*` 兩端都是）：改成找不到就失敗，
   並在 Android 端加跑連續頁面模式（平板預設）。
3. Android `editor/EditorStateManager.kt` 是寫好卻**沒有任何地方使用**的模式狀態機：決定接上或刪除（目前模式靠
   `LaunchedEffect(editorMode)` 收尾，見 `EditorCanvasContext.kt`）。
4. 守門腳本擴充：選取（`selectedTextId` 等）與頁面切換（`pageIndex`）也定義正門。
5. Apple 連續頁面模式也補一條橡皮擦旅程（Android 已兩種模式都跑）。

### P1 資訊架構（「好用」的順序與位置）
6. Android「插入」選單混入備份、同步、縮放、協作、自訂工具列（`EditorTopBar.kt` 約 860–1000 行）：
   比照 Apple 新的分區（插入／工具／設定／危險動作）拆開；兩端順序一致（Apple 是圖片→PDF→文件，Android 是文件→PDF）。
7. 核心畫面規格 `crates/padnote-core/src/ffi_screens.rs` 只驗「有沒有」：加上分區與順序，`scripts/check-screen-parity.py` 一併比對。
8. 名詞統一：同一功能有「飛梭工具盤／徑向飛輪快捷盤／環形快捷工具盤／Radial Mark Menu」等多種叫法；
   「匯入 PDF／匯入文件／匯入筆記／匯入快照」意思不同但名字相近。建一份詞彙表（i18n catalog 旁），檢查同義詞。

### P2 PDF 批註流程（使用者點名的案例）
9. 首頁「新增筆記」加「從 PDF 開始」；系統分享／「用 Kairumo 開啟」直接建立筆記（目前只能先開一本空白筆記 → 更多 → 匯入 PDF，5–6 步）。
10. 由 PDF 建立的筆記，頁面尺寸跟隨 PDF 每一頁（橫式投影片＝橫式頁），不縮進 A4（現行規則見 `ffi_pdf_import.rs` `pdf_page_placement`）。
11. 匯入完成停在第 1 頁手寫模式，給一次性提示：PDF 是鎖定的底稿、筆跡直接寫在上面、匯出可得到帶註記的 PDF。
12. 「匯入文件」改名為「匯入 Word／Excel／Markdown」，與 PDF 分開說清楚。
13. 匯出 PDF 時保留原始頁面尺寸。

### P3 出現時機
14. 首次啟動按「繼續」就跳出系統麥克風權限，但說明文字寫「現在或之後再允許都可以」：改成第一次錄音時才要（Android 已確認；Apple 待查）。
15. 情境提示目前只有 4 個（`hint.comment_pin/refine_sketch/tabletop/recognize`）：補 PDF 匯入、物件鎖定、套索、飛梭工具盤的首次提示。
16. 範例筆記全是唯讀：第一次在範例上下筆時，引導「複製一份來編輯」。

## 環境（exFAT 外接碟）

- Android：`scripts/gradle.sh :app:testDebugUnitTest`；旅程：
  `scripts/gradle.sh :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.kairumo.padnote.screens.UserJourneyTest`
  （需要模擬器；`connectedAndroidTest` 跑完會移除 App）。
- 核心改過就要重產綁定：`scripts/build-xcframework.sh`、`scripts/build-android-libs.sh`（產物不進版控）。
- Apple：新增測試檔後在 `apple/` 跑 `xcodegen generate`；UI 測試：
  `xcodebuild -project Kairumo.xcodeproj -scheme Kairumo -destination "id=<模擬器>" test -only-testing:KairumoUITests/UserJourneyUITests CODE_SIGNING_ALLOWED=NO`
  （模擬器 id：`python3 scripts/pick-ios-simulator.py`）。
- Android 測試要畫筆跡：用 `input touchscreen swipe`（手指），不要用 Compose `performTouchInput`（觸控類型 UNKNOWN，仲裁不收）。
