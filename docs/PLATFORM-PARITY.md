# Apple 與 Android 的功能落差清查

> 對應規則：**對應用程式所有的修改都應該要同時滿足不同平台的需求。**
> 這份清查是那條規則的對帳單 —— 從核心到應用層逐項比對，不用印象。
>
> **最後查證：2026-09-21（v4.8.1），逐項對著 Android 原始碼點名。**
> 上一版寫於 2026-09-13（v2.4.1），此後的十幾個版本補上了幾乎整個第 3 層，
> 但這份文件沒有跟著改 —— 下面的「這一版改了什麼」記錄了落差有多大。

---

## 一句話結論

**Android 已經不是「一本筆記、一頁、一支筆」的殼了。**
量一下：Android 130 個 Kotlin 檔、30,836 行（不含 9,894 行產生的字串表），
對上 Apple 105 個 Swift 檔、43,386 行（不含 9,827 行產生的）。

**v2.4.1 列出的 23 項「Android 完全沒有」，現在只剩 1 項（A19 里程碑快照）。**
B 段五項裡有兩項已補齊，剩下三項中有兩項**兩個平台都缺**，
也就是說那不是跨平台落差，是待辦功能。

---

## 這一版改了什麼（2026-09-21）

| 上一版寫的 | 查證結果 |
|---|---|
| 「18 個 Kotlin 檔、約 2,900 行」 | **130 個檔、30,836 行**（相差十倍） |
| 「核心 104 個 FFI，Android 只用 29 個」 | 核心現在是 199 個 `#[uniffi::export`；使用量已不是瓶頸 |
| A1–A14、A16–A18、A20–A23「完全沒有」 | **全部有了**，逐項位置見下表 |
| B1「不能拖曳縮放、沒有特殊符號」 | 特殊符號有了（`text/SymbolPickerDialog.kt`） |
| B2「不能捲動到整頁」 | 有了（`canvas/ContinuousPages.kt` 依可用寬度縮放 + `CanvasStackPanel` 捲動） |

**這種規模的失準本身就是一個教訓：**清單型文件如果沒有跟著 commit 更新，
它下一次被讀到的時候，會讓人去重做一次已經存在的功能 —— 那比不做更糟，
會蓋掉現有實作，而且沒有人會發現是怎麼壞的。這一週已經發生兩次
（S-71 的 Android 雙欄編輯器、紙張底紋）。

---

## 第 1 層：核心（Rust）—— **沒有落差**

兩個平台走同一個 `padnote-core`，同一組 FFI。

| 核心能力 | Apple | Android |
|---|---|---|
| 筆畫（新增／擦除／讀回） | ✅ | ✅ |
| 多頁（`add_page` / `page_id_at` / `page_size`） | ✅ | ✅ `canvas/PageSidebar.kt` |
| 文字區塊（內容／位置／外觀） | ✅ | ✅ `text/`（5 檔 1,037 行） |
| 圖片區塊（`add_image` / `put_blob`） | ✅ | ✅ `image/`（9 檔 1,339 行） |
| 表格（新增／改格／插刪列欄／合併） | ✅ | ✅ `table/`（5 檔 1,005 行） |
| 形狀與連接線（ISO 5807 九符號 + 流程圖範本） | ✅ | ✅ `shape/`（7 檔 1,358 行） |
| 物件堆疊順序、群組、變換 | ✅ 圖層面板 | ✅ 圖層面板 |
| 錄音與轉錄 | ✅ | ✅ `audio/AudioTranscriber.kt`（走核心 whisper） |
| 搜尋索引 | ✅ `NotebookSearchIndex` | ✅ `library/NotebookSearch.kt` |
| 匯出（PDF／PNG／Markdown／列印） | ✅ | ✅ |
| 協同中繼（`RelayServer`） | ✅ | ✅ `collab/CollaborationManager.kt`（415 行，含自動重連與自建中繼） |
| 工具列設定、六國語系 | ✅ | ✅ `ui/LocalAppLanguage.kt` + `setAppLanguage` |

---

## 第 2 層：資料與檔案 —— **落差小**

| 項目 | Apple | Android | 說明 |
|---|---|---|---|
| `.padnote` 讀寫 | ✅（匯出／同步用） | ✅（主要儲存） | |
| 文字方塊外觀跨平台 | ✅ | ✅ | `SetBlockAppearance`，鍵名共用 |
| 雲端資料夾同步 | ✅ | ✅ | 策略在核心，I/O 各自實作 |
| 備份與一鍵復原 | ✅ | ✅ | 容器格式在核心，互通 |
| 頁面幾何 800×1132 | ✅ | ✅ | 尺寸來源在核心 |
| 掌拒判定 | ✅ | ✅ | 同一個 `InkArbiter` |
| **主要儲存格式** | JSON + `.drawing` | `.padnote` | ⚠️ **仍然兩邊不同。** Apple 的工作副本在 `Documents/notebooks_v1.json` 與 `Drawings/*.drawing`，`.padnote` 只在同步與匯出時產生。**這件事有後果**：套件加密在 Apple 端保護的是同步出去的套件，不是本機工作副本（見 `TODO.md` H-CRYPTO-2） |

---

## 第 3 層：應用層

### A. v2.4.1 說「Android 完全沒有」的 23 項 —— 現況

| # | 功能 | Android 現況 |
|---|---|---|
| A1 | 多筆記本 | ✅ `library/NotebookLibrary.kt`（339） |
| A2 | 資料夾與子資料夾 | ✅ `library/FolderTree.kt`（148） |
| A3 | 多頁 UI | ✅ `canvas/PageSidebar.kt`（452） |
| A4 | 頁面縮圖 | ✅ `PageSidebar` 走 `platform/PageImageRenderer` |
| A5 | 頁面樣板 | ✅ `canvas/PageBackground.kt`（292），十三種紙走核心 `paper_templates` |
| A6 | 筆刷選擇 | ✅ `MainActivity.kt` 工具列 + `ink/InkEngine.kt` |
| A7 | 顏色選擇 | ✅ 同上 + `canvas/ProColorPicker.kt`（125） |
| A8 | 筆寬選擇 | ✅ 同上 |
| A9 | 圖片附件 | ✅ `image/`（9 檔 1,339 行） |
| A10 | 3D 模型 | ✅ `model3d/`（4 檔 564 行） |
| A11 | 連結預覽卡片 | ✅ `MainActivity.kt` + `library/NotebookMeta.kt` |
| A12 | 討論圖釘與留言串 | ✅ `comment/`（2 檔 414 行） |
| A13 | 即時協同 | ✅ `collab/CollaborationManager.kt`：建房／加入／自動重連／必要時自建中繼 |
| A14 | 素材庫 | ✅ `asset/`（2 檔 368 行） |
| A15 | 數字製圖 | ✅ `chart/ChartStudio.kt`（434），同一份 `ChartSpec` |
| A16 | 數學計算 | ✅ `math/`（1 檔 101 行） |
| A17 | 草圖優化 | ✅ `ink/SketchRefineBar.kt` |
| A18 | 主題專用工具 | ✅ `theme/`（2 檔 419 行） |
| **A19** | **里程碑快照（時光機）** | ❌ **仍然沒有** —— 見下方 |
| A20 | 個人資料／協同身分 | ✅ `account/AccountManager.kt`（54） |
| A21 | 語言切換 UI | ✅ `ui/LocalAppLanguage.kt` + `setAppLanguage` |
| A22 | 搜尋 | ✅ `library/NotebookSearch.kt` → `library/HomeScreen.kt` |
| A23 | 語音轉錄 | ✅ 走核心 `whisperTranscribePcm`；`asr-whisper` 編得出 Android 的 `.so`（實機驗證見 `TODO.md` H-ASR-ANDROID-VERIFY） |

### B. 有但不完整

| # | 功能 | 現況 |
|---|---|---|
| B1 | 文字方塊 | ✅ 特殊符號已補（`text/SymbolPickerDialog.kt`） |
| B2 | 頁面捲動 | ✅ `canvas/ContinuousPages.kt` 依可用寬度縮放，`CanvasStackPanel` 垂直捲動 |
| B3 | 匯出預覽 | ❌ **兩個平台都沒有**（Apple 也搜不到 `exportPreview`）—— 是待辦功能，不是跨平台落差 |
| B4 | 掌拒門檻調整 UI | ❌ **兩個平台都沒有**，只有 `ink/InkEngine.kt` 內部呼叫 `setPalmThresholds` |
| B5 | 低延遲開關 | Android 有（`ink/LowLatencyInkCanvas.kt` + 工具列開關）；Apple 沒有對應開關，**這是刻意的** —— PencilKit 自己處理前緩衝 |

### C. Android 有而 Apple 沒有

| # | 功能 | 說明 |
|---|---|---|
| C1 | ~~輸入診斷列~~ | v2.7.0 起 Apple 也有，演算法與格式一致 |
| C2 | 延遲量測 | `InkLatencyMeter`。Apple 沒有對應的東西（PencilKit 不給原始時間戳） |
| C3 | 低延遲開關 | 見 B5，刻意的平台差異 |

---

## 真正還開著的落差

只剩三項，而且性質不同：

| # | 項目 | 誰缺 | 下一步 |
|---|---|---|---|
| A19 | 里程碑快照（時光機） | **只有 Android 缺** | Apple 那份寫在 `NotebookStore.swift` + `CollaborationSheet.swift`，**核心裡沒有**。補 Android 之前應該先把快照的建立／列出／還原下沉到核心，否則會變成第二份平台實作 —— 與「session 加密兩份實作」同一類錯誤 |
| B3 | 匯出預覽 | **兩邊都缺** | 產品待辦，不是 parity 問題 |
| B4 | 掌拒門檻調整 UI | **兩邊都缺** | 同上；門檻的判定邏輯本身已在核心的 `InkArbiter` |

---

## 怎麼維持這份對帳單

新增功能時，在 `docs/DEVLOG.md` 的驗證段落**逐平台交代**。某個平台沒做到就
明講並回到這裡加一列 —— 不要略過。

**反過來也一樣重要：做完了就把這裡的 ❌ 改掉。**
這份文件過期了十幾個版本，代價是有人差點照著它重做一次已經能用的功能。
清單型文件的錯誤不是中性的 —— 它會主動誤導。

---

## 第 0 層：核心開好但沒人用 / 只有一邊用（2026-09-21 決議）

盤點見 `docs/plans/unrealised-features-audit.md`。這裡只記**決定**：
每一項要嘛「下沉」（兩邊都改走核心），要嘛「明確是平台差異」，
不留在中間狀態 —— 中間狀態的代價是下一個人得重新推導一次。

### 已經處理掉的

| 項目 | 決定 | 結果 |
|---|---|---|
| Android 假轉錄 | **下沉** | 走核心 `whisperTranscribePcm`，四種失敗各有明確訊息 |
| Android 的 Whisper 引擎 | **下沉** | `asr-whisper` 已經編得出 Android 的 `.so`（見 `TODO.md` H-ASR-ANDROID-VERIFY）。擋住的從來只有 ONNX，而 Whisper 不碰它 |
| 模型下載 | **下沉** | 兩平台走 `padnote-models`（SHA-256 + 續傳），Apple 原本那條沒驗證沒續傳的路已移除 |
| session 加密兩份實作 | **下沉** | `collab_encrypt` 改呼叫 `padnote_crypto::session`，重複的 FFI 門面刪掉 |
| Apple 搜尋搜不到轉錄／PDF／OCR | **下沉** | 新增 `NotebookSearchIndex`，與 Android 同一組規則（兩字才查、快取、跳過壞的） |
| 壓感曲線的常數（Apple 手抄 0.35 / 0.65 與「哪些筆吃壓感」） | **下沉** | 改呼叫 `ink_width_scale` / `ink_pressure_for_width_scale` / `ink_tool_is_pressure_sensitive`，核心加測試釘住那兩個數字 |
| 版面常數（1040 / 420 / 900 在三個地方各存一份） | **下沉** | 兩平台的 `DesignSystem` 改呼叫 `layout_metrics` / `layout_gutter` / `layout_columns` |
| 頁面搬移時的逐頁資料（Android 沒有搬） | **下沉** | `NotebookMeta.movePageData` 逐頁問核心的 `page_index_after_move`。**這是一個真的 bug**：搬完之後紙張樣板與物件堆疊順序留在原地 |
| 已無呼叫端的同步 FFI | **刪除** | 見 commit `3840b6d` |
| 套件加密 | **已實作** | 選擇性開啟，Argon2id + XChaCha20-Poly1305，frame 層封裝讓 append-only 同步與免金鑰壓實都還能用（`TODO.md` H-CRYPTO-2 記著剩下的解鎖畫面） |

### 決定要下沉，但還沒做

| 項目 | 為什麼要下沉 | 卡在哪 |
|---|---|---|
| 里程碑快照（A19） | Apple 那份是純 Swift，Android 補的時候不該再寫第二份 | 要先決定快照存哪（套件內的另一組 oplog？還是獨立檔？）以及與同步的互動 |

### 決定**不**下沉（明確的平台差異）

| 項目 | 為什麼 |
|---|---|
| 文字編輯、表格儲存格、套索 | Apple 走 PencilKit / SwiftUI 的原生編輯，Android 走核心 op。兩邊的**結果**（存進 oplog 的內容）已經一致，而編輯手感本來就該用各自平台的慣例。下沉會讓 Apple 失去原生的選字與撤銷行為 |
| 縮放平移夾制、掌拒門檻 | 手勢的物理量（DPI、觸控取樣率、系統手勢邊界）本來就不一樣。核心那份留給 Android，Apple 用 `PKCanvasView` 自己的 |
| 語系清單 | Apple 用系統的 `Locale`，Android 用產生的字串表 —— 兩邊都由 `i18n/ui-strings.json` 生成，真相來源已經是同一個 |
| AI 摘要後端 | Apple 有系統語言模型，Android 沒有對等的東西且不值得為它多背幾 MB 或要使用者下載 2.4 GB。Android **誠實回報沒有**（`NoteIntelligence.kt` 有完整的取捨說明） |
| PDF 匯出走不同函式 | Apple 需要 `/Ink` 標註（讓 Goodnotes 能繼續編輯），Android 走版面算繪。**輸出的 PDF 兩邊都打得開**，差別在附加能力 |
| 低延遲開關（B5） | Android 需要明確的前緩衝與預測；PencilKit 自己就做了，多一個開關只會讓人以為關掉會變快 |

### 還沒決定（不要假裝已經決定）

- 觸控筆懸停（`is_pen_hovering` / `hover_position`）：核心有，**兩邊都沒有任何介面用得到它**。
  要嘛做出懸停預覽，要嘛把它從 FFI 拿掉。
- 可設定的壓感曲線（`set_pressure_curve` / `FfiPressureAction` 的
  「影響線寬還是濃度」）：**曲線的常數已經下沉**（見上表），但「讓使用者調整」
  這件事還沒有任何介面。要先決定它該不該是一個設定，再決定要不要接。
- PDF 座標互通（`page_point_to_pdf` / `highlight_quad_points`）：PDF 標註功能本身還沒有完整的入口。
- 匯入（`import_json` / `import_markdown` / `import_embedded`）：兩邊都沒有匯入入口。
- 轉錄進度（`transcription_backlog_us`）與 VAD 切換（`set_vad_model`）：
  串流轉錄還沒有畫面，等 H-ASR-ANDROID-VERIFY 之後一起決定。
