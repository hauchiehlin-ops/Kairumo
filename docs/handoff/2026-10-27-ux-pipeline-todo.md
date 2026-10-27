# 交接：模組管線守門與 UX 流程優化（2026-10-27）

分支：`claude/trusting-sammet-4649b4`（基於 origin/main c19fe460 + origin/fix/android-parity-and-samples）
**尚未 push。** 提交：`1ac9dc1` 飛梭工具盤自訂、`edc77ef` 手冊、`62701e0` P0 守門＋旅程測試。

## 已完成

- 飛梭工具盤可自訂（核心 `crates/padnote-toolbar/src/radial.rs`，2–8 格，跟帳號同步；Apple／Android 設定畫面都有）。
- 守門腳本 `scripts/check-state-entrypoints.py`（已掛 pre-push 與 CI）：換工具、切模式、選取、切頁只准走正門，正門標 `// state-entry:`。
- 修掉的斷鏈：Android 主工具列與 Ctrl+數字繞過 `applyInkTool`；Apple 兩份「插入／更多」選單分岔合併；Android 畫布 `strokes:N` 讀數更新；連續模式無障礙讀數；Android 工具列飛梭位置修正；防抖標籤用字對齊。
- 旅程測試：
  - Android `screens/UserJourneyTest.kt`（3 條全過：單頁模式橡皮擦、連續模式橡皮擦、自訂飛梭工具盤）。
  - Apple `UITests/UserJourneyUITests.swift`（3 條全過：單頁模式橡皮擦、連續模式橡皮擦、自訂飛梭工具盤）。
- P1 資訊架構：選單分區、順序對齊、雙端畫面規格 `screens.json`、名詞統一詞彙表 `i18n/glossary.json` 與 `scripts/check-glossary.py` 檢查通過。
- P2 PDF 批註流程：首頁「從 PDF 開始」、系統分享／「用 Kairumo 開啟」直接建本、頁面尺寸跟隨 PDF、底稿提示與匯出註記提示、「匯入文件」名詞拆分清楚。
- P3 出現時機：麥克風權限延遲至第一次錄音；補齊 4 個新情境提示（`hint.pdf_underlay`、`hint.object_lock`、`hint.lasso`、`hint.radial_menu`）；範例筆記唯讀下筆引導「複製一份來編輯」；UI 測試模式下自動抑制情境提示彈窗。

## 待辦（依優先序）

### P0 收尾後續
1. 既有稽核測試把斷言包在「找得到按鈕才檢查」裡（`InkInvariantMatrixAudit*` 兩端都是）：改成找不到就失敗，並在 Android 端加跑連續頁面模式（平板預設）。
2. Android `editor/EditorStateManager.kt` 是寫好卻**沒有任何地方使用**的模式狀態機：決定接上或刪除（目前模式靠 `LaunchedEffect(editorMode)` 收尾，見 `EditorCanvasContext.kt`）。

## 環境（exFAT 外接碟）

- Android：`scripts/gradle.sh :app:testDebugUnitTest`；旅程：
  `scripts/gradle.sh :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=com.kairumo.padnote.screens.UserJourneyTest`
  （需要模擬器；`connectedAndroidTest` 跑完會移除 App）。
- 核心改過就要重產綁定：`scripts/build-xcframework.sh`、`scripts/build-android-libs.sh`（產物不進版控）。
- Apple：新增測試檔後在 `apple/` 跑 `xcodegen generate`；UI 測試：
  `xcodebuild -project Kairumo.xcodeproj -scheme Kairumo -destination "id=<模擬器>" test -only-testing:KairumoUITests/UserJourneyUITests CODE_SIGNING_ALLOWED=NO`
  （模擬器 id：`python3 scripts/pick-ios-simulator.py`）。
- Android 測試要畫筆跡：用 `input touchscreen swipe`（手指），不要用 Compose `performTouchInput`（觸控類型 UNKNOWN，仲裁不收）。
