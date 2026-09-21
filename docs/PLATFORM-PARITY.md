# Apple 與 Android 的功能落差清查

> **2026-09-21 補：見文末「第 0 層：核心開好但沒人用 / 只有一邊用」。**
> 那一節是 `docs/plans/unrealised-features-audit.md` 的決議版 ——
> 盤點只負責指出「中間狀態」，這裡負責把每一項變成一個決定。


> 對應規則：**對應用程式所有的修改都應該要同時滿足不同平台的需求。**
> 這份清查是那條規則的對帳單 —— 從核心到應用層逐項比對，不用印象。
> 清查於 2026-09-13（v2.4.1）。

---

## 一句話結論

**Android 目前是「一本筆記、一頁、一支筆」的殼。** 核心開出 104 個 FFI 方法，
Android 只用了 **29** 個；Apple 端 43 個 Swift 檔（約 2 萬行）對上 Android 的
18 個 Kotlin 檔（約 2,900 行，其中 4,200 行是產生的字串表）。

落差**不是散在各處的小洞，而是整層都還沒蓋** —— 多筆記本、資料夾、多頁、
以及所有「筆跡以外的物件」。

---

## 第 1 層：核心（Rust）—— **沒有落差**

兩個平台走同一個 `padnote-core`，同一組 FFI。以下能力核心**都已具備**，
是平台層還沒接上：

| 核心能力 | Apple 用了 | Android 用了 |
|---|---|---|
| 筆畫（新增／擦除／讀回） | ✅ | ✅ |
| 多頁（`add_page` / `page_id_at` / `page_size`） | ✅ | ⚠️ 只用 `firstPageId` |
| 文字區塊（內容／位置／外觀） | ✅ | ✅ |
| 圖片區塊（`add_image` / `put_blob`） | ✅ | ❌ |
| 表格（新增／改格／插刪列欄／合併） | ✅ | ✅ |
| 形狀與連接線（ISO 5807 九符號 + 流程圖範本） | ✅ | ✅ |
| 物件堆疊順序、群組、變換 | ✅ 圖層面板 | ✅ 圖層面板 |
| 錄音與轉錄 | ✅ | ⚠️ 錄音有、轉錄關閉 |
| 搜尋索引 | ✅ | ⚠️ 只有手寫辨識回填 |
| 匯出（PDF／PNG／Markdown／列印） | ✅ | ✅ |
| 協同中繼（`RelayServer`） | ⚠️ Swift 另寫一份 | ⚠️ 只在診斷頁測試啟動 |
| 工具列設定、六國語系 | ✅ | ⚠️ 字串有、切換 UI 無 |

**表格與形狀／流程圖在 v2.7.0 補上了，兩個平台都接了同一組核心出口。**

當時卡住的原因不是「沒開 FFI」—— 寫入操作一直都在。缺的是**讀取**：
平台拿不到「這一頁有哪些表格、有哪些物件、形狀長什麼樣、線連到哪裡」。
少了讀取，功能就是單向的 —— 寫得進檔案，畫面上卻列不出來，也就選不到、
編不了。這與圖片區塊、筆記本中繼資料是同一類漏洞，而且在單機測試時
完全看不出來。

堆疊順序與群組的圖層面板在 v2.7.x 補上了，兩個平台同一組規則。
核心也補了絕對索引的 `set_object_z_index`（相對操作在併發下會疊加）與
`object_node`（群組後成員不是根物件，只看根層整組形狀會從畫面消失）。

---

## 第 2 層：資料與檔案 —— **落差小**

| 項目 | Apple | Android | 說明 |
|---|---|---|---|
| `.padnote` 讀寫 | ✅（匯出用） | ✅（主要儲存） | |
| 文字方塊外觀跨平台 | ✅ | ✅ | `SetBlockAppearance`，鍵名共用 |
| 雲端資料夾同步 | ✅ | ✅ | 策略在核心，I/O 各自實作 |
| 備份與一鍵復原 | ✅ | ✅ | 容器格式在核心，互通 |
| 頁面幾何 800×1132 | ✅ | ✅ | 尺寸來源在核心 |
| 掌拒判定 | ✅ | ✅ | 同一個 `InkArbiter` |
| **主要儲存格式** | JSON + `.drawing` | `.padnote` | ⚠️ **兩邊不同**。Apple 的讀取路徑還沒切到 `.padnote`（WP4c 只做了遷移） |

---

## 第 3 層：應用層 —— **落差就在這裡**

### A. 完全沒有的（Android 從零開始）

| # | 功能 | Apple 的實作 | 影響 |
|---|---|---|---|
| A1 | **多筆記本** | `HomeWorkbenchView` + `NotebookStore` | Android 只有一本 `notebook.padnote` |
| A2 | **資料夾與子資料夾、拖曳分類** | 同上 | 完全沒有 |
| A3 | **多頁 UI**（新增／複製／刪除頁、頁面結構側欄） | `NotebookEditorView` | Android 只看得到第一頁 |
| A4 | **頁面縮圖** | `PageThumbnailRenderer` | 沒有側欄就沒有縮圖 |
| A5 | **13 種頁面樣板** | `NoteTemplate` | Android 一律空白頁 |
| A6 | **筆刷選擇**（8 種 + 橡皮擦 + 套索） | 工具列 | **Android 只有一支固定的鋼筆**，連橡皮擦都選不到 |
| A7 | **顏色選擇** | 色票 + `ProColorPickerSheet` | Android 一律黑色 |
| A8 | **筆寬選擇** | 點點 + 滑桿 | Android 固定 3pt |
| A9 | **圖片附件**（濾鏡、材質、旋轉、圓角、陰影） | `AttachmentItemView` / `ImageEditControls` | 完全沒有 |
| A10 | **3D 模型** | `Model3DStudioView`（9 種材質） | 完全沒有 |
| A11 | **連結預覽卡片** | `LinkPreviewEngine` | 完全沒有 |
| A12 | **討論圖釘與留言串** | `CommentThreadView` | 完全沒有 |
| A13 | **即時協同** | `CollaborationManager` + `LocalRelayServer` | Android 只在診斷頁「啟動再關閉」測試過 |
| A14 | **素材庫**（2,401 行） | `AssetLibraryManager` / `View` | 完全沒有 |
| ~~A15~~ | ~~**數字製圖**~~ | `ChartStudioView`（11 種圖型、可重新編修） | ✅ **已對等**：`chart/ChartStudio.kt`，同一份 `ChartSpec`、同一個核心版面引擎 |
| A16 | **數學計算** | `MathCalculatorSheet` / `MathEngine` | 完全沒有 |
| A17 | **草圖優化** | `SketchRefineEngine` | 完全沒有 |
| A18 | **主題專用工具** | `ThemeSpecificToolsView` | 完全沒有 |
| A19 | **里程碑快照**（時光機） | `NotebookStore` | 完全沒有 |
| A20 | **個人資料／協同身分** | `AccountManager` | 完全沒有 |
| A21 | **語言切換 UI** | 下拉選單 | Android 只跟系統語系，**使用者改不了** |
| A22 | **搜尋** | 首頁搜尋列 | 完全沒有 |
| A23 | **語音轉錄** | ✅ | ⚠️ 刻意關閉（`asr` feature，ONNX 沒有 Android 預編譯檔） |

### B. 有但不完整

| # | 功能 | 差在哪 |
|---|---|---|
| B1 | 文字方塊 | Android 有了，但**不能拖曳縮放**、沒有特殊符號插入、沒有清單樣式 |
| B2 | 頁面界線 | 兩邊都畫了，但 Android **不能捲動到整頁**（手機螢幕比 800dp 窄，右半邊看不到） |
| B3 | 匯出 | 功能一致，但 Android **沒有匯出前的預覽** |
| B4 | 掌拒 | 判定一致，但 Android **沒有門檻調整 UI**（Apple 也沒有，兩邊都缺） |
| B5 | 低延遲 | Android 有前緩衝與預測；**Apple 沒有對應的開關**（PencilKit 自己處理） |

### C. Android 有而 Apple 沒有

| # | 功能 | 說明 |
|---|---|---|
| C1 | 輸入診斷列 | 顯示工具類型／接觸半徑／壓感／密度／仲裁結果。**Apple 端沒有** —— 遠端除錯時很有用 |
| C2 | 延遲量測 | `InkLatencyMeter`。Apple 沒有對應的東西 |
| C3 | 低延遲開關 | 見 B5 |

---

## 建議的補齊順序

不是照清單由上而下做，而是**照「少了它就不算筆記 App」排**：

### 第一批 —— 沒有這些，Android 版不能算能用
1. **A6 筆刷與橡皮擦選擇**（只有一支筆的筆記 App 不成立）
2. **A7 顏色、A8 筆寬**（核心已支援，只差 UI）
3. **A3 多頁 UI**（核心已有 `add_page` / `page_id_at`）
4. **A1 多筆記本 + A2 資料夾**（要先有 Android 版的首頁）

### 第二批 —— 內容型物件
5. **A9 圖片附件**（核心已有 `add_image` / `put_blob`）
6. **B1 文字方塊補完**（拖曳縮放、特殊符號）
7. **A22 搜尋**（核心的 `search` 已就緒）
8. **A5 頁面樣板**（核心的 `PageStyle` 已就緒）

### 第三批 —— 協同與進階
9. **A13 即時協同**（核心的 relay 已可用，Apple 端另有一份 Swift 實作待統一）
10. **A12 討論圖釘**
11. **A19 里程碑快照**
12. **A21 語言切換 UI**

### 兩邊都要補（不只 Android）
- ~~表格、形狀與流程圖~~ —— v2.7.0 完成，兩平台接同一組核心出口。
- ~~物件堆疊與群組的 UI~~ —— 已完成，兩平台各有圖層面板。
- **掌拒門檻調整 UI**（B4）
- ~~Apple 端的輸入診斷列~~（C1）—— v2.7.0 完成，演算法與格式與 Android 一致。

---

## 怎麼維持這份對帳單

新增功能時，在 `docs/DEVLOG.md` 的驗證段落**逐平台交代**。某個平台沒做到就
明講並回到這裡加一列 —— 不要略過。這份文件過期的那一天，
「跨平台一致」就退回成一句口號。

---

## 第 0 層：核心開好但沒人用 / 只有一邊用（2026-09-21 決議）

盤點見 `docs/plans/unrealised-features-audit.md`。這裡只記**決定**：
每一項要嘛「下沉」（兩邊都改走核心），要嘛「明確是平台差異」，
不留在中間狀態 —— 中間狀態的代價是下一個人得重新推導一次。

### 已經處理掉的

| 項目 | 決定 | 結果 |
|---|---|---|
| Android 假轉錄 | **下沉** | 走核心 `whisperTranscribePcm`，四種失敗各有明確訊息 |
| 模型下載 | **下沉** | 兩平台走 `padnote-models`（SHA-256 + 續傳），Apple 原本那條沒驗證沒續傳的路已移除 |
| session 加密兩份實作 | **下沉** | `collab_encrypt` 改呼叫 `padnote_crypto::session`，重複的 FFI 門面刪掉 |
| Apple 搜尋搜不到轉錄／PDF／OCR | **下沉** | 新增 `NotebookSearchIndex`，與 Android 同一組規則（兩字才查、快取、跳過壞的） |
| 已無呼叫端的同步 FFI | **刪除** | 見 commit `3840b6d` |
| 套件加密的文案 | **先改文案** | 加密本身列為 `TODO.md` 的 H-CRYPTO，要先回答五個產品問題 |

### 決定要下沉，但還沒做（已排進 TODO）

| 項目 | 為什麼要下沉 | 卡在哪 |
|---|---|---|
| Android 的 Whisper 引擎 | 轉錄的行為必須兩邊一樣 | `whisper-rs-sys` 的 Android cmake 設定，見 `TODO.md` H-ASR-ANDROID |
| 壓感曲線（`width_scale` / `opacity_scale` / `FfiPressureAction`） | 同一支筆在兩台裝置上該畫出同樣的粗細。**Apple 現在在 `InkInterop.swift` 寫死一條曲線**，核心那條可設定的沒人用 | 要動兩邊的算繪路徑；而且「壓感影響線寬還是濃度」目前**沒有任何設定介面**，先補介面還是先下沉要一起決定 |
| 版面尺寸級別（`layout_columns` / `layout_size_class`） | Android 的編輯器沒有雙欄工作區，同一本筆記在平板上兩邊長得不一樣 | 這是 Android 編輯器的版面重做，與 S-71/S-72 同一批 |
| 頁面搬移運算（Apple 走核心、Android 自己算） | 搬移的**正確性**規則（由大到小刪、附件頁碼平移）不該有兩份 | Android 端要改接 `page_index_after_*` / `page_transfer_plan` |

### 決定**不**下沉（明確的平台差異）

| 項目 | 為什麼 |
|---|---|
| 文字編輯、表格儲存格、套索 | Apple 走 PencilKit / SwiftUI 的原生編輯，Android 走核心 op。兩邊的**結果**（存進 oplog 的內容）已經一致，而編輯手感本來就該用各自平台的慣例。下沉會讓 Apple 失去原生的選字與撤銷行為 |
| 縮放平移夾制、掌拒門檻 | 手勢的物理量（DPI、觸控取樣率、系統手勢邊界）本來就不一樣。核心那份留給 Android，Apple 用 `PKCanvasView` 自己的 |
| 語系清單 | Apple 用系統的 `Locale`，Android 用產生的字串表 —— 兩邊都由 `i18n/ui-strings.json` 生成，真相來源已經是同一個 |
| AI 摘要後端 | Apple 有系統語言模型，Android 沒有對等的東西且不值得為它多背幾 MB 或要使用者下載 2.4 GB。Android **誠實回報沒有**（`NoteIntelligence.kt` 有完整的取捨說明） |
| PDF 匯出走不同函式 | Apple 需要 `/Ink` 標註（讓 Goodnotes 能繼續編輯），Android 走版面算繪。**輸出的 PDF 兩邊都打得開**，差別在附加能力 |

### 還沒決定（不要假裝已經決定）

- 觸控筆懸停（`is_pen_hovering` / `hover_position`）：核心有，**兩邊都沒有任何介面用得到它**。
  要嘛做出懸停預覽，要嘛把它從 FFI 拿掉。
- PDF 座標互通（`page_point_to_pdf` / `highlight_quad_points`）：PDF 標註功能本身還沒有完整的入口。
- 匯入（`import_json` / `import_markdown` / `import_embedded`）：兩邊都沒有匯入入口。
- 轉錄進度（`transcription_backlog_us`）與 VAD 切換（`set_vad_model`）：
  串流轉錄還沒有畫面，等 H-ASR-ANDROID 之後一起決定。

