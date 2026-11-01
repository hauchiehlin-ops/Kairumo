# Kairumo 專案核心開發原則與四大自動化守門機制（Gatekeepers）

> **最高指導原則**：
> 1. **「不要改了這個、壞了那個」**：任何功能的擴充、重構、修正或效能調優，嚴禁以破壞既有機制或引發附帶損害為代價。任何修改都必須全面審視對關聯系統的影響。
> 2. **開發終極目標三要素**：
>    - **穩定（Stability）**：零崩潰、無 ANR、無看門狗超時（0x8BADF00D）、容錯降級。
>    - **即時（Immediacy）**：120Hz/60Hz 手寫超低延遲（<16ms），連續書寫無延遲累積，$O(1)$ 增量繪圖，工具切換零停滯。
>    - **正確（Correctness）**：筆跡單一真相（ADR-0015），畫布與預覽縮圖同源同版，擦除必成墓碑永不復活，跨平台模型完全對齊。

---

## 四大自動化守門機制（Gatekeepers）—— 任何程式改動必須受其約束

在進行任何功能修改、問題修復或效能優化時，AI 助理與開發者必須將下列四大守門機制列為**最高優先原則**：

### 🚪 Layer 1：狀態正門管制（Entry Points Gatekeeper）
- **約束工具**：`python3 scripts/check-state-entrypoints.py`
- **卡控邏輯**：
  - 換工具、切換模式、跳轉頁面、選取/取消選取等所有編輯器狀態變更，**必須且只能走指定正門函式**：
    - **Apple 端**：`applyEditorTool`、`selectEditorTool`、`transitionToMode`、`switchToPage`、`focusContinuousPage`
    - **Android 端**：`applyInkTool`、`switchToPage`、`selectText`、`selectImage`、`clearSelection`
  - **嚴禁繞過正門直接指派全域狀態變數**。繞過正門會直接導致副作用斷裂（例如橡皮擦旗標遺漏、選取框殘留、筆刷快取未清空、未完成筆跡丟失等連鎖災難）。

### 🖋️ Layer 2：筆跡單一真相與不變式矩陣（Ink Single Source of Truth: ADR-0015）
- **約束工具**：
  - 核心測試：`cargo test -p padnote-core -p padnote-ink`（740+ 項不變式）
  - Apple 矩陣測試：`InkInvariantMatrixAudit.swift`
  - Android 矩陣測試：`InkInvariantMatrixAuditTest.kt`
- **六大不變式（I1–I6）**：
  - **I1 唯一真相**：一頁的筆跡＝核心事件串流（InkLog）materialize 結果。快取僅為純表現層，可隨時丟棄重建。
  - **I2 即時落地**：筆畫新增、擦除、位移必須在手勢結束當下生成穩定事件（`Add`/`Remove`/`Replace`）寫入串流，嚴禁依賴事後比對推論。
  - **I3 墓碑優先**：被標記 `Remove` 的筆畫 id 永遠不得被任何舊資料或同步匯入復活。復原刪除一律以新 id 寫入。
  - **I4 畫面同源**：畫布與側欄縮圖讀取同一個版本號（`revision`）。畫布有筆跡，縮圖必須有；預覽頁有筆跡，畫布切換後絕不可消失。
  - **I5 事件同步**：同步傳輸裝置事件區塊，無全量檔案覆蓋。
  - **I6 跨端對齊**：Apple 與 Android 底層資料模型與行為完全同構。
- **快取一致性硬指標**：
  - Android `InkSurfaceView` 的增量烘焙底圖必須具備 `bakedStrokes` 內容檢驗（`baked !== curr && baked != curr`）與 `pageKey` 換頁追蹤，嚴防換頁殘影或非末端筆畫變動時烘焙層未更新。
  - Apple `ProInk` 必須以穩定 `stroke.id` 鍵入快取，禁止裸寫座標反轉的 `backingImage`。

### ⚡ Layer 3：主執行緒非阻塞與執行緒安全（Non-blocking UI & Thread Safety）
- **約束工具**：
  - `python3 scripts/check-main-thread-io.py`
  - `python3 scripts/check-assume-isolated.py`
  - `python3 scripts/check-transition-delays.py`
- **卡控邏輯**：
  - 主執行緒嚴禁同步執行磁碟 I/O（禁止在主執行緒使用會觸發 `lstat` 的路徑 API）。
  - 主執行緒嚴禁同步執行耗時的 Rust FFI 筆點陣計算（計算必須在背景完成或於 `endStroke` 平滑預熱）。
  - 所有驅動 UI 重組的狀態更新（如 `revision++`、`thumb` 更新），**必須透過 `Dispatchers.Main.immediate` 或 `MainActor` 在主執行緒調度**。
  - 嚴禁在無 Looper 的背景執行緒中直接推進 Compose 快照，且 UI 清單需具備 Looper 缺失降級能力（如 `Looper.myLooper() == null` 降級為標準 `Column`）。

### 🛡️ Layer 4：多設定檔隔離與跨平台規範（Profile Scope, Parity & Hygiene）
- **約束工具**：
  - `python3 scripts/check-profile-scope.py`（多設定檔狀態隔離）
  - `python3 scripts/check-hardcoded-strings.py`（介面無硬寫死文字）
  - `python3 scripts/check-glossary.py`（專有名詞詞彙表一致性）
  - `python3 scripts/check-unused-params.py`（無默默忽略參數）
  - `./scripts/check-version-consistency.sh`（全端版本號一致性）
- **卡控邏輯**：
  - 所有使用者資料、快取、設定檔操作，必須嚴格收納於 active profile，嚴防跨設定檔污染。
  - 介面所有文字一律走 `L10n` / `localized()`，禁止硬編碼。
  - 變更提交前必須保證各平台產物（manual, privacy, templates, bindings）自動同步。

---

## 驗證流程標準作業規範（SOP）

> **唯一執行入口（Antigravity / Claude Code / 人類通用）**：`./scripts/sop-verify.sh`
> - 完整三道防線：`./scripts/sop-verify.sh`（commit / push 前必跑，任一失敗即禁止提交）
> - 改碼中途快檢（僅第 1 道）：`./scripts/sop-verify.sh --fast`
> - 無法跑某平台時須明確 `--skip-android` / `--skip-apple`，並在回報中註明「未驗證」，不得視為通過。
> - 本節只定義規範；實際指令以腳本為準，`GEMINI.md` 為指向 `AGENTS.md` 的符號連結，兩邊讀到的是同一份規範。

任何程式碼修改在提交與推送前，必須完成以下三道防線驗證：
1. **CI 預防性檢查與四大守門驗證（CI Preflight & Auto-Remediation）**：
   - 執行 `./scripts/check-ci-preflight.sh`（或 `./scripts/verify-all-gatekeepers.sh`），針對開發歷程中 GitHub Actions 常見崩潰與卡控點進行預防性檢查與自動矯正：
     - 自動清除 macOS 在外接磁碟（exFAT）衍生的 `._*` 與 `.DS_Store`，防止 non-monotonic index 與 Gradle/codesign 污染。
     - 自動驗證並同步衍生平台手冊、隱私權政策與範本產物（`build-platform-docs.py`、`build-privacy-docs.py`、`doc_templates_tool.py`）。
     - 自動防護 Android CI 測試組態（`leaveApksInstalledAfterRun=true` 與 `uninstallInstrumentsAfterTesting=false`），杜絕 UTP teardown 反安裝崩潰。
     - 驗證 UniFFI 跨端綁定同步性與可用磁碟空間健康度。
     - 全維度通過 Layer 1 至 Layer 4 四大守門機制（正門管制、筆跡不變式矩陣、非阻塞 UI、跨平台規範）。
2. **雙平台單元測試**：
   - Android: `./scripts/gradle.sh testDebugUnitTest`（等同 `cd android && ./gradlew testDebugUnitTest`，另處理 exFAT 清理）
   - Apple: `cd apple && xcodebuild -scheme Kairumo build`
3. **Git Pre-Push 門禁**：推送時自動觸發 `.githooks/pre-push`，任何一項失敗立即阻擋。
