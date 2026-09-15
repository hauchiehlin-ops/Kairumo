# 待辦事項

> 分三類：**🔴 被硬體/資料卡住**（程式已就緒，等外部條件）、
> **🟡 待實作**（純軟體，可直接做）、**⚪ 待決策**（需要人拍板）。

---

## 🔴 被硬體或資料卡住（程式已就緒）

### H0. iOS 實機驗證（`--ios-install` 那條路尚未實測）
- **卡在**：目前沒有任何實體 iPhone / iPad 連著這台 Mac。
  帳號裡也只登錄了一支 iPhone 16 Pro Max，**沒有任何 iPad**。
- **已就緒**：`./scripts/dist.sh --ios-install` 全部寫好，裝置偵測與
  「沒接線就在編譯前中止」都已實測通過；但**「真的裝進裝置」那一步沒驗過**。
- **要做**：接上 iPad → 解鎖 → 信任這台 Mac → 跑 `--ios-install`。
- **判定**：主畫面出現 Kairumo 且能開啟 = 通過。
- **備註**：要發給**別人**的話不走這條 —— 走 TestFlight（`scripts/release.sh`），
  不需要 UDID、對方也不需要 Mac。v2.10.1 (24) 已上傳，等 Apple 處理完
  就能在 App Store Connect 加測試人員。
  `.ipa` 那條路（Apple Configurator + 事先登錄 UDID）實務上不建議給非技術使用者。

### H1. S1 墨跡延遲實機量測 —— **M0 Go/No-Go，最高優先**
- **卡在**：實體 iPad（模擬器 Metal 路徑不同，數字無意義）＋ 240fps 攝影機
- **已就緒**：`apple/InkSpike/` 全部原始碼、`apple/README.md` 量測協定
- **要做**：Xcode 建 iOS target → 部署實機 → 依協定量 20 次取中位數與 p95
- **判定**：中位數 ≤9ms 且 p95 ≤12ms = Go；>12ms = 改用 PencilKit（會改變跨平台策略）
- **影響**：決定自建墨跡引擎是否成立

### H2. S2 中文 ASR 測試集 —— **M0 Go/No-Go**
- **卡在**：需錄製 ≥3 小時真實台灣場景音檔（M2 前擴到 10 小時）
- **已就緒**：`cargo run -p padnote-bench --bin asr-score`、分場景門檻、TSV 格式
- **要做**：依 `crates/padnote-bench/fixtures/README.md` 錄製並人工標註
- **判定**：quiet ≤8% / noisy ≤18% / codeswitch ≤15%
- **備註**：這份測試集是競品抄不走的資產，越早開始累積越好

### H3. 模型權重授權確認（M0/S4 殘留）
- **卡在**：需人工逐一查閱模型發布頁的授權條款
- ✅ **已確認**：silero-vad-v4（MIT，URL 與雜湊皆經實際下載驗證）、
  whisper-large-v3-turbo（MIT）、ppocr-v5（Apache-2.0）、qwen3-4b（Apache-2.0）
- ❌ **已排除**：SenseVoice-Small（FunASR Model License v1.1，非 OSI 開源；
  商用釐清 issue 數月無回覆）。C9 中英夾雜改由 whisper-turbo 承擔
- ✅ **已解決**：Paraformer-zh-streaming 自行從官方權重匯出（repo 內含完整
  Apache-2.0 授權原文，11,358 bytes，雜湊已記入 PROVENANCE.json）
- ⚠️ **ct-punc 證據較弱**：repo 內**無** LICENSE 檔，僅 model card 標籤
- ⏸️ **延後**：speaker-diarization（P2）
- **完整稽核**：`models/LICENSE-AUDIT.md`
- ⚠️ **另一個教訓**：原本 silero 的 HuggingFace URL 需要登入，`curl` 只拿到
  29 bytes 的 "Invalid username or password"。**清單裡沒被驗證過的 URL 等於沒有**
- **高風險**：語者分離模型（pyannote 系條款嚴格）
- **記錄於**：`models/MODELS.md`

### H8. libpdfium 執行期庫 —— **取得與執行已驗證，出貨方式待你拍板**
- **原本卡在**：`pdfium-render` 只是綁定，`libpdfium` 動態庫要另外提供
- ✅ **已做（2026-09-16）**：`./scripts/fetch-pdfium.sh [all]`。
  來源 bblanchon/pdfium-binaries（Google 沒有發佈官方二進位檔），
  版本**釘死** `chromium/8057`，七個平台的 SHA-256 **逐一驗證**，
  與 `models/manifest.json` 同一套規矩。抓下來的東西不進版控
  （每個 3～4 MB、可重抓，`/third_party/pdfium/` 已加進 .gitignore）
- ✅ **「能不能執行」已經驗過**（這才是這一條真正的問題）：
  新增 `cargo run -p padnote-pdf-pdfium --example probe`。
  沒有設 `DYLD_LIBRARY_PATH` 時 `bound=false`，設了之後 `bound=true`；
  設了之後 `padnote-pdf-pdfium` 的 4 項測試**真的走到實作**
  （原本 libpdfium 不在時它們會自己跳過，看起來一樣是綠的）
- ✅ **已拍板：隨 App 出貨**（2026-09-16，D-11）。授權面沒有問題 ——
  PDFium 是 BSD-3-Clause（Google），打包腳本是 MIT（Benoit Blanchon），
  兩者都相容於本專案的 Apache-2.0
- ✅ **Android 已接好**：`build-android-libs.sh` 會把 `libpdfium.so` 複製進
  `jniLibs/<abi>/`（arm64-v8a 6.2 MB、x86_64 6.4 MB）。沒抓過時會**明講**
  並說下一步，不會靜靜略過 —— 靜靜略過的話，下一個發現的人是使用者
- ✅ **iOS 的 XCFramework 已產生**：`./scripts/build-pdfium-xcframework.sh`。
  `install_name` 改成 `@rpath/libpdfium.dylib`（維持 `./libpdfium.dylib` 的話
  App 一啟動就閃退，而訊息指向 dyld，不指向我們）
- ⚠️ **還沒做 1：Xcode 專案的嵌入**。要把 `PDFium.xcframework` 加進專案並選
  **Embed & Sign**。只 Link 不 Embed 的話，開發機上跑得動、裝到裝置上
  一開就閃退。這一步我沒有動 `project.pbxproj` —— 手改嵌入階段弄壞專案檔的
  風險，高過它省下的時間
- ✅ **Catalyst 的缺口已解，選了 (b)**（D-11b，2026-09-16）：
  **Apple 整條線改走 PDFKit，完全不用 PDFium。**
  bblanchon 的 mac 版是平台 1（macOS）不是平台 6（MACCATALYST），
  Catalyst 建置不會選它 —— 與其為了四個平台裡的一個去自建 PDFium
  （depot_tools + gn + ninja，而且要長期維護），不如讓 Apple 走系統那一套：
  PDFKit 在 iOS / iPadOS / macOS / Catalyst 全都有，`ExportPrintManager`
  早就在用它列印。
  - `apple/Sources/PdfKitDocument.swift`：頁數、頁面幾何、旋轉正規化、
    文字層、算繪成 PNG。7 項測試跑在**真的 PDF** 上（用
    `UIGraphicsPDFRenderer` 現產一份，不餵自己拼的位元組）
  - `build-xcframework.sh` 改成 `--no-default-features --features asr`，
    Apple 端不再連進 `padnote-pdf-pdfium`
  - 少 6 MB × 2 的二進位、少一個第三方供應鏈、少一個會隨系統更新壞掉的東西
  - **libpdfium 只出貨給 Android**（Android 沒有能讀文字層的系統 API，
    `PdfRenderer` 只能算繪）。兩邊後端不同，**介面與座標約定同一份** ——
    Swift 那 7 項測試裡有一組就是逐條對應核心 `padnote_pdf::PdfPage` 的
    同名測試（Y 軸翻轉、來回轉換、旋轉換寬高）
  - `apple/PDFium.xcframework` 與 `build-pdfium-xcframework.sh` 不再需要
- **另注意**：PDFium 的 C API 非執行緒安全，多頁渲染實際是序列化的，
  J2 的效能預算只能靠 `PageCache` 的預抓，不能靠平行渲染

### H9. whisper 轉錄品質實測
- **卡在**：模型檔 574 MB 需下載；且中文品質必須用 H2 的測試集驗證
- **已就緒**：`padnote-asr-whisper` 編譯通過、錯誤路徑已測
- **備註**：whisper 定位是**多語備援**。中文主力應是 Paraformer-zh（S-24），
  但其模型權重授權尚未確認（H3）

### H4. Apple Pencil 實機行為驗證
- 壓感曲線調校、懸停（hover）、雙擊切換工具
- `coalescedTouches` 在 120Hz 下的實際取樣數
- 熱節流與長時間書寫的延遲漂移

### H5. iCloud Drive provider 實機測試
- Ubiquity Container 的未下載（evicted）檔案處理
- `NSFileCoordinator` 在多裝置併發下的實際行為
- **注意**：S3 已證明演算法收斂，這裡驗證的是 Apple API 的實際語意

### H6. 大型 PDF 效能驗證（J2）
- 500 頁 PDF 開啟 ≤1.5s、捲動 60fps
- 需要真實的大型 PDF 樣本與實機

### H7. App Store 審核相關
- 大型模型按需下載的審核說明
- 隱私標籤（目標：不收集任何資料）
- 背景錄音 `UIBackgroundModes` 的審核理由

---

## 🟡 待實作（純軟體，可直接進行）

### ✅ 已完成
| ID | 工作包 | 內容 |
|---|---|---|
| S-01 | WP4 | `padnote-storage`：manifest、套件讀寫、內容定址 blob（去重/完整性/GC） |
| S-02 | WP1 | `padnote-doc`：頁面樹、區塊模型、統一時間軸 |
| S-03 | WP2 | `padnote-ink`：編解碼 + 幾何（平滑、簡化、命中測試、dirty rect） |
| S-04 | WP11 | `padnote-search`：CJK bigram 索引、AND 查詢、增量更新 |
| S-05 | WP5 | `padnote-asr`：環形緩衝、VAD 分段狀態機、工作佇列 |
| S-07 | WP21 | `padnote-crypto`：信封加密（Argon2id + XChaCha20）、BIP39 復原碼 |
| S-08 | WP10 | `padnote-sync`：SyncEngine、框架化 chunk、增量游標、加密整合 |
| S-09 | H1/H2 | `padnote-export`：Markdown + SVG 匯出 |
| S-11 | — | `padnote-core`：NotebookSession 門面（含 C1 筆跡↔錄音跳轉） |
| S-06 | WP12 | `padnote-recognize::registry`：引擎註冊表與 fallback 鏈 |
| S-10 | WP7 | `padnote-pdf`：文件介面、座標轉換、LRU 頁面快取與預抓 |
| S-14 | D4 | `padnote-models`：清單、SHA-256 驗證、斷點續傳、可刪除 |
| S-17 | WP13 | `padnote-core::setup`：引擎與權限中心狀態機 |
| S-16 | WP1 | `padnote-doc::text`：文字 CRDT + 二進位編碼，**端到端同步已驗證** |
| S-12 | — | UniFFI：Swift/Kotlin 綁定、產生腳本、XCFramework 腳本、CI 閘門 |
| S-23 | — | 文件 op-log 持久化：12 種 DocOp、落盤、`open()` 重播還原 |
| S-13 | WP5 | `padnote-audio`：Opus 編碼 + Ogg 容器（**ffprobe 驗證通過**）|
| S-15 | WP5 | `padnote-asr-whisper`：whisper.cpp `AsrEngine`（**轉錄品質待實測**）|
| S-21 | WP7 | `padnote-pdf-pdfium`：PDFium 適配層（**執行期需 libpdfium**）|
| S-25 | WP5/6 | `padnote-recorder`：錄音編排。管線與 ASR 引擎型別上分離，
音檔優先落地。**ffprobe 驗證端到端產出為 3.00 秒合法 Ogg-Opus** |
| S-26 | WP5 | `padnote-vad-silero`：Silero VAD（ort）。**實測白噪音下
EnergyVad 誤判 100/100、Silero 0/100**。模型缺失時降級不失敗 |
| S-29 | WP5 | **ct-punc 體積問題已解**：量化納入 `Gather`（嵌入表占 86.4%
體積），1,074 MB → **269 MB**，argmax 一致率 100% |
| S-30 | WP5 | `padnote-punct-ct`：中文標點還原。**詞表是簡體**，
故管線順序必須是「先標點、再轉繁體」。標點接在詞尾以保留時間戳 |
| S-24 | WP5 | `padnote-asr-paraformer`：fbank（與 FunASR 參考特徵逐點吻合）
+ LFR + CMVN + CIF + encoder/decoder。**fp32 輸出與 FunASR 完全吻合** |
| S-34 | WP5 | `padnote-text` + `core::transcript`：簡繁轉換與完整中文管線。
**無標點簡體 → 有標點台灣正體**，時間戳全程不變 |
| S-18 | H1/H2 | `padnote-export`：PDF 匯出（含底紋模板、富文本、表格、圖片、向量筆畫與 `/Ink` 標註）|
| S-43 | WP7 | `padnote-pdf-pdfium`：以 PDFium 寫入真實標註（`create_annotated_pdf` 實作與回讀驗證）|
| S-55 | — | 列印流程：`print_data` + Apple (UIPrintInteractionController/NSPrintOperation) 與 Android (PrintManager) 整合 |

### 待做
| ID | 工作包 | 內容 | 備註 |
|---|---|---|---|
| ~~S-13~~ ✅ | WP5 | Opus 編碼整合 | 已由 `padnote-audio` + `padnote-recorder` 完成，Ogg-Opus 端到端樣本已驗 |
| ~~S-15~~ ✅ | WP5 | whisper.cpp 實作 `AsrEngine` | `padnote-asr-whisper` 已實作；品質實測仍列 H9 |
| ~~S-23~~ ✅ | — | 文字 op 寫入 `doc/ops/` 持久化 | `NotebookSession::record` 會寫 `doc/ops/<lamport>-<device>.oplog`；重開 replay 已有測試 |
| ~~S-19~~ ✅ | WP20 | iCloud `CloudProvider` 實作 | **不需要另一個 provider** —— ubiquity container 就是一個檔案系統路徑，核心的 `LocalFolderProvider` 直接能用。真正的差別只有「檔案可能還沒下載」：iCloud 用 `.原檔名.icloud` 佔位檔。核心已認得佔位檔（列舉時還原成邏輯檔名、讀取時回 `NotMaterialized` 而不是 `NotFound`），Apple 端 `ICloudSyncFolder.swift` 負責觸發下載並等它完成。實機行為仍列 H5 |
| ~~S-20~~ ✅ | WP23 | llama.cpp 整合（摘要、待辦抽取） | `padnote-llm`（切塊 + 提示詞 + **解析**，18 項測試）＋ `padnote-llm-llama`（llama.cpp 後端）＋ `ffi_llm`（平台介面，4 項測試）。**llama.cpp 不是 `padnote-core` 的相依** —— 連進去會讓行動端每個使用者都下載好幾十 MB，不管他用不用得到摘要（與 reqwest 那次同一個判斷）。行動端由平台提供後端。仍待做：兩邊的 UI 入口、實際跑一份 2.4 GB 的 Qwen3-4B 驗真實輸出 |
| ~~S-21~~ ✅ | WP7 | PDFium 綁定（`pdfium-render`）| `padnote-pdf-pdfium` 已實作；執行期庫與大型 PDF 實測仍列 H8/H6 |
| ~~S-22~~ ✅ | WP12 | Apple Vision / ML Kit 的 `HwrEngine` 實作 | Android 的 ML Kit 本來就有；**Apple 端原本完全沒有手寫辨識**（iPad 上寫的字搜不到）。新增 `HandwritingRecognizer.swift`：把每一組筆畫算繪成白底黑字的圖再送 `VNRecognizeTextRequest`。分組規則下沉核心（`padnote-recognize::grouping`），兩邊同一份 —— 切法不同會讓同一頁在兩台裝置上搜到不一樣的東西。辨識率需實機以真實筆跡驗（A-09）|

## 🆕 需求檢視新增項目（2026-09-12）

> 完整分析見 [`docs/requirements-review.md`](requirements-review.md)。

| ID | 項目 | 備註 |
|---|---|---|
| ~~S-41~~ ✅ | Office / Google 文件的嵌入與編輯（D-10 已拍板為「嵌入＋可編輯」） | 見 ADR-0009。docx/xlsx 可做，pptx 只做預覽 |
| ~~S-42~~ ✅ | PDF 標註的雙向保真（ADR-0008 第一層的核心） | 10 款競品都讀寫 PDF，這是唯一真正通用的互通途徑 |
| ~~S-45~~ ✅ | 平台層依 `Decision::retract` 實作筆畫收回 | **兩平台皆已實作**：Android 在 `InkEngine`；Apple 新增 `PalmRejectionCoordinator`（偵測到筆就切 `.pencilOnly`，並收回筆落下前 500ms 內的筆畫）。原本 Apple 在手寫模式下是 `.anyInput`，手掌畫得出東西 |
| ~~S-43~~ ✅ | 把標註寫進真實 PDF（PDFium 的 annotation API） | `create_annotated_pdf` 實作完成，經測試驗證 |
| ~~S-44b~~ ✅ | 匯出真正的 PDF `/Ink` 標註 | **兩平台皆已達成**。Apple 的匯出改走核心的匯出器（原本是點陣合成）；核心同時輸出向量筆畫與 `/Subtype /Ink` + `/InkList` + `/BS`。3D 模型與連結卡片核心沒有那兩種型別，改以算繪後的圖片帶進去，內容不會掉 |
| S-44 | 用其他 App 實測 | **需要你來測**（我裝不了那些 App）。已產出範例 PDF（兩頁、三筆畫、三個獨立 Ink 標註）。判準：那三條線能不能在 Goodnotes / Notability / PDF Expert 裡被**選取、搬動、刪除** |
| ~~S-35~~ ➡️ | **Windows 低延遲墨跡** | **已轉成 [ADR-0012](adr/0012-windows-low-latency-ink.md)，不再排期。** 它不是待辦：目前沒有 Windows 版，這一條在有 Windows 版之前不成立。結論（Compose MP Desktop 走 Skia/JVM 做不到 9ms，要原生 Windows Ink / DirectComposition）連同重新評估的時機都記在那份 ADR |
| ~~S-36~~ ✅ | **掌拒與輸入分流** | 🔴 完全未設計。**手寫 App 的生死線**：手掌靠螢幕會畫出大片塗鴉 |
| ~~S-37~~ ✅ | UI/UX 設計 | 🔴 完全未開始。可與 M0 並行，不依賴 S1 |
| ~~S-38~~ ✅ | 物件模型：群組／對齊／吸附／變換 | 需 ADR —— 會影響 `.padnote` 格式。目前 `Stroke` 沒有「物件」概念 |
| ~~S-39~~ ✅ | Markdown 匯入、JSON 匯入匯出 | 容易，可立即做 |
| S-40 | 各平台數位板協定與藍牙筆按鈕 | **需要實體硬體才驗得了**（Wacom/XP-Pen 數位板、有按鈕的藍牙筆）。程式面已備妥的部分：核心的 `InkArbiter` 已區分 `Pen`/`Eraser`/`Mouse`，Android 的 `InkInput` 已對應 `TOOL_TYPE_ERASER`。缺的是按鈕事件的對應與實機校準 |

## 🆕 畫布與介面需求（2026-09-12）

| ID | 項目 | 備註 |
|---|---|---|
| ~~S-46~~ ✅ | 物件堆疊順序（需求 1：畫布物件可自由排列） | `SetZIndex` 記絕對索引；只在同層內移動 |
| ~~S-47~~ ✅ | 形狀、連接線與流程圖範本（需求 3） | ISO 5807 九個符號 + 4 份內建範本；連接線跟著圖形走 |
| ~~S-48~~ ✅ | 表格作為畫布物件（需求 2：嵌入試算表圖形） | xlsx 現在展開成 `BlockKind::Table`，逐格可編輯 |
| ~~S-49~~ ✅ | 工具列模組化與自訂顯示（需求 4） | 18 個工具 / 5 組；設定可序列化、可還原 |
| ~~S-50~~ ✅ | 六國語系（需求 5） | 型別強制完整性：少一個語言就編不過 |
| ~~S-51~~ ✅ | 表格的插入／刪除列欄與合併儲存格 | `DocOp` 已覆蓋列欄插刪、合併與取消合併，FFI 可呼叫 |
| ~~S-52~~ ✅ | 形狀與連接線落盤為 `DocOp` | 新增 `AddShapeObject` / `AddConnectionObject`，重開可還原 |
| ~~S-53~~ ✅ | 平台層的工具列 UI 與語言切換畫面 | Apple SwiftUI 範例已接 `FfiToolbar` / `supported_locales` |
| ~~S-54~~ ✅ | 其餘 UI 字串的在地化 | 字串表 **512 條**（清單原本寫的 44 早已過期）。錯誤訊息已在地化並有測試；`LocalizationManager.localizedUnsafe` 供背景執行緒查表 |
| ~~S-54b~~ ✅ | **素材庫的 58 個中文名稱** | 58 條 `asset_<id>_title` 已進共用 i18n catalog（英／繁中／簡中／日／韓／泰），Android/Apple 圖庫標題、搜尋與 Apple 素材 PNG 底部標題都改走語系鍵；核心繁中 title 保留為 fallback |
| ~~S-55~~ ✅ | 列印流程 | 核心 `print_data` 產出列印 PDF，已串接 Apple 與 Android 系統列印面板 |

## 📱 Android 實機待測（2026-09-13）

模擬器驗得完的都已經驗過（instrumented 22/22）。以下幾項**只有實機加觸控筆
才驗得出來**，等整體架構完成後一次回頭測。每一項都寫成可以當場判定的條件，
不要「大致可用」。

| ID | 待測項目 | 判定條件 | 現況 |
|---|---|---|---|
| A-01 | 筆寫得出墨跡 | 用筆畫一筆，畫布上出現對應的線 | 模擬器已過；實機曾回報全白，`Canvas.density` 遮蔽已修，待複測 |
| A-02 | 掌拒 | 手掌貼在螢幕上書寫，不產生任何筆畫 | 核心邏輯已測；門檻（手掌半徑 22dp、收回窗 500ms）是**起點值**，需依實機姿勢調整 |
| A-03 | 「僅限觸控筆」開關 | 開啟後手指完全畫不出東西；關閉後可以 | 實機曾回報「按不動」，**原因未明**，待複測 |
| A-04 | 快速書寫不掉點 | 快速畫弧線，線條平滑而非折線 | 歷史取樣點已處理並有測試，待實機感受 |
| A-05 | 前緩衝低延遲 | 開關 Low Latency 各記一次 p50/p95，差值為正 | 模擬器上兩條路徑都畫得出墨跡；延遲數字在模擬器無意義 |
| A-06 | 診斷列讀數 | `tool=` 是 2（觸控筆）、`rej=` 為 0 | 新增的診斷列供遠端判讀 |
| A-07 | 錄音 | 錄一段後波形時間軸與筆跡對得上 | WP6 |
| A-08 | 匯出與列印 | 匯出的檔案內容與畫布一致 | WP6（模擬器已驗檔案格式，實機驗內容） |
| A-09 | 手寫辨識率 | 中英文各 20 句，辨識結果搜得到 | WP7（模擬器已驗端到端可用；辨識率要真的筆跡才算數） |
| A-11 | 雲端同步端到端 | 兩台真實裝置指到同一個雲端資料夾，A 寫的字在 B 上打得開 | 檔案層級的邏輯已測；雲端傳輸是 OS 與服務的事 |
| A-12 | 同步資料夾權限存活 | 重啟 App 後仍有存取權，不需重選資料夾 | Apple 用 security-scoped bookmark、Android 用 persistable URI permission |
| A-10 | 分組門檻 | 正常書寫節奏下，一個詞不會被切成兩組 | 停頓門檻 700ms 是起點值 |

**測試方式**：`cd android && ANDROID_HOME="$HOME/Library/Android/sdk" ./gradlew :app:installDebug`，
寫字時截圖那條診斷列即可，它會顯示平台回報的工具類型、接觸半徑、壓感、密度與仲裁結果。


## ☁️ Google Drive 自動同步（2026-09-15，D11 已接受）

目標：不同作業平台或設備只要登入同一個 Google 帳號，Kairumo 內的筆記本、
資料夾結構與可同步設定會自動收斂到同一狀態。正式同步使用 Google Drive
`appDataFolder`；既有「選同步資料夾」保留為手動備份／匯入匯出。

| ID | 項目 | 判定條件 |
|---|---|---|
| G-01 | Google OAuth 設定與登入 | **程式已完成，等實機驗證。** OAuth client 已建立（Apple / Android 各一）。PKCE、授權網址、權杖交換與更新、撤銷全在核心 `ffi_oauth`（13 項測試）；平台只做「開系統瀏覽器 + 打 HTTP + 存進安全儲存區」：Apple `ASWebAuthenticationSession` + Keychain、Android Custom Tabs + EncryptedSharedPreferences。URL scheme 兩邊都註冊好了（Apple 的 `Info.plist`、Android 的 `OAuthRedirectActivity`）。模擬器實測到「開啟系統瀏覽器 → 載入 Google 授權頁」為止，**還沒有真的登入過**（要真實 Google 帳號）。中途抓到一個外部設定問題，見下方「Android 還要開一個開關」|
| ~~G-02~~ ✅ | appDataFolder Provider 完整化 | `crates/padnote-sync/src/gdrive.rs`。**原本這個檔案根本沒有被編譯**（`lib.rs` 裡沒有 `pub mod gdrive;`），所以裡面的 `unimplemented!()`、少掉的分頁、沒跳脫的查詢字串都沒人發現。已補：分頁跟到底、`trashed = false`、查詢字串跳脫、前綴（而非子字串）比對、同名取最新、append 回錯誤而不是 panic、401/403 分類成權限錯誤。HTTP 抽成 trait，9 項測試用假的 Drive 驗分頁與查詢邏輯 |
| ~~G-03~~ ✅ | 同步資料佈局 | `format-spec.md` §7.0 |
| ~~G-04~~ ✅ | 全域設定同步 | `padnote-sync::settings` + `ffi_account_sync`。`SyncedSettings` 與 `DeviceSettings` 是**兩個型別**，「不要同步」寫在型別上而不是註解裡；有一項測試專門確認低延遲、掌拒門檻、SAF 權限權杖連序列化都不會出現在同步 JSON 裡。逐欄位帶 Lamport 時戳合併（整包 LWW 的話，A 改語言、B 改工具列會互相蓋掉）。**已接上兩邊 UI**：Apple 的 `LocalizationManager.setLanguage` 與 Android 新增的語言選擇器（Android 原本只能跟著系統語系走）都寫進同步設定，啟動時跨裝置設定優先於本機記錄。模擬器實測：選日文 → 介面變日文 → 重啟仍是日文，SharedPreferences 裡就是核心產生的那份 JSON |
| ~~G-05~~ ✅ | 筆記本與資料夾同步 | `padnote-sync::library` + `ffi_account_sync`。刪除是**墓碑**不是「不在清單裡」—— 靠比對清單的話，還沒同步到刪除的那台會把筆記本傳回去，每同步一次復活一次。另含：已刪資料夾底下的項目一起隱藏（否則變成打不開也刪不掉的幽靈）、父子環的迴圈保護（兩台各自把 A 搬進 B、B 搬進 A 會凍住 App）、搬移前先問會不會成環。12 項測試含「離線兩台各自增改刪後收斂」。**已接上兩邊 UI**：兩邊的新增／改名／搬移／刪除、資料夾的建立／改名／刪除都會記進索引（`AccountSyncStore`），刪除留墓碑，列表濾掉已刪項。模擬器實測：新增 → 索引出現該筆；刪除 → 同一筆變成 `deleted: true` 而不是消失 |
| ~~G-02d~~ ✅ | 媒體檔同步 | `ffi_gdrive::gdrive_sync_media`。**blob 與錄音的同步方式不一樣，因為命名保證不一樣**：blob 是內容定址（檔名＝SHA-256），同名必定同內容，比存在就夠，下載後**驗雜湊**；錄音是 uuid 命名且**錄製中會變長**，所以要比長度。順帶補上 Drive 的**可續傳上傳** —— 單次上傳上限 5 MB，而 blob 存的是原始位元組（`putBlob` 只縮顯示尺寸不縮檔案），手機照片 3–8 MB 是常態，不處理的話「一放照片同步就壞」|
| ~~G-02c~~ ✅ | 筆記本**內容**同步 | `ffi_gdrive::gdrive_sync_notebook`：以 **oplog 檔**為同步單位鏡像到 `notebooks/<id>/doc/ops/`。檔名 `<lamport:016x>-<device:08x>.oplog` 本來就唯一、不可變、字典序即因果序、重複覆寫冪等 —— 再包一層 chunk 只是把「哪些還沒傳」換個地方問。核心測試含「兩台裝置收斂」與「第二次同步不重傳」。**順帶修掉 SyncEngine 一個資料遺失 bug**，見下 |
| ~~G-02b~~ ✅ | Drive provider 接上授權 | `ffi_gdrive::gdrive_sync_metadata`：讀雲端 → 合併 → 寫回。**HTTP 由平台出**（`FfiDriveHttp` callback interface）而不是核心用 reqwest —— 後者會把整個 rustls 堆疊連進行動端函式庫（`libpadnote_core.so` 8.1 MB → 13 MB），而且與 `ffi_collab` 已定下的「socket 留在平台層」不一致。查詢字串、分頁、合併規則仍全在核心 |
| ~~G-07~~ ✅ | 同步要**自己發生**，還有雲端獨有的筆記本 | 兩個缺口，都是「機制寫好了但接不起來」：<br>**(a) Apple 端整條 Google 路沒有入口** —— `GoogleAuth` 與 `CloudSync` 在 Apple 上**沒有任何呼叫端**，設定頁進不去，等於不存在。已補 `AppDiagnosticsSheet.googleAccountSection`（登入／登出／立即同步）與 `NotebookSyncCoordinator.runDrive`（匯出 → Drive → 匯入，三步順序與資料夾同步一致）。<br>**(b) 只有手動按鈕會觸發** —— Android 只有選單那一項，Apple 連那一項都沒有。已加自動觸發：Apple `scenePhase == .active`、Android 首頁 `ON_RESUME`。自動同步**失敗不出訊息**（背景行為，每次跳「同步失敗」使用者只會把功能關掉）。<br>**(c) 別台新建的筆記本抓不下來** —— `gdrive_sync_notebook` 第一件事是 `NotebookPackage::open`，而雲端獨有的那本在本機連目錄都沒有，它會以「開不了套件」失敗。症狀：索引同步成功、清單上有標題、點進去是空的，而且每輪重複同樣的失敗。已補 `gdrive_clone_notebook`（先建空套件再走一般下載，重跑安全）與 `sync_live_notebooks`（攤平的清單；用 `sync_children_of` 只拿得到一層，資料夾裡的筆記本會被漏掉）。抓失敗時把空殼**刪掉** —— 留著的話下一輪 `exists` 為真，這本再也不會被重抓 |
| G-06 | 實機矩陣 | iPad + macOS + Android 同一 Google 帳號端到端測試：新增、編輯、刪除、改設定、重啟、離線再上線皆通過 |

**目前的狀態**：G-02～G-05 的核心與兩邊 UI 都完成了，但**還沒有真的上傳下載** ——
那要等 G-01。先把記錄做對是有意義的：記錄漏掉的東西，之後接上雲端也補不回來。
最典型的是刪除 —— 沒有墓碑的話，等雲端接上，另一台裝置會把已經刪掉的筆記本
原封不動傳回來。

**外部前置（已完成）**：Google Cloud OAuth client 已建立。
`drive.appdata` 在同意畫面上標示為 **sensitive**（不是 restricted）——
代表上 Production 要做 OAuth 驗證（填表、錄操作影片），但**不需要**
restricted scope 那種要付費的第三方安全評估。

**Android 的 SHA-1 要三筆，目前只登錄了兩筆**：

| 用途 | 指紋 | 狀態 |
|---|---|---|
| debug | `BB:79:DA:…:61:3F` | 已登錄 |
| release 上傳金鑰 | `D1:94:14:…:A6:25` | 已登錄 |
| Play App Signing | 上傳到 Play Console 之後才拿得到 | **尚未** |

第三筆最容易漏：Play 會用**它自己的**金鑰重新簽 App，所以使用者裝到的版本
用的是那個憑證。只登錄前兩筆的話，自己測都正常，上架之後所有人登入都失敗。

**Android 還要開一個開關（實測踩到）**：Google 對 **Android** 型別的 client
預設**關閉**自訂 URI scheme —— 授權頁會載入（代表 client id 有效），
但直接回 `Error 400: invalid_request`，詳細訊息是
「Custom URI scheme is not enabled for your Android client」。

開啟位置：Google Cloud Console → 憑證 → 點進 Android 的 OAuth client →
**進階設定（Advanced Settings）** → 把「啟用自訂 URI 配置
（Enable Custom URI scheme）」打開 → 儲存。改完可能要等幾分鐘生效。

iOS 型別**不受影響**，自訂 scheme 在那邊本來就是標準做法。

**修掉的一個資料遺失 bug（SyncEngine 的非 append 路徑）**：
`current_chunk` 從 0 重來，所以重開 App 之後第一次推送又寫 `log-1.bin`，
把上一個 session 的第一塊直接**蓋掉** —— 沒有任何錯誤：檔案數不變、
上傳成功、cursors 也對得上，只是內容沒了。只有不支援 append 的 provider
（正是 Google Drive）會踩到；既有測試全用支援 append 的 `LocalFolderProvider`，
所以那條路一行都沒被測過。已改成從雲端接續序號，並補上不支援 append 的
假 provider 與兩項回歸測試（驗證過：移除修正後測試會紅）。

**Testing 狀態的陷阱**：專案維持在 `Testing` 且使用 sensitive 範圍時，
refresh token **七天就過期**。長期測試時會以為是自己的程式壞了。
程式面已經把這個狀況與「網路壞了」分開（`oauth_needs_reauth`），
會要求重新登入而不是無限重試。


## 📄 固定頁面模型（2026-09-13，問題 3＋5）

問題 3（取消延長頁面、超出自動新增下一頁）與問題 5（畫布四周要有頁面界線、
匯出與列印一致）是同一件事：**頁面必須有與視窗無關的固定座標空間**。

現況的根因：畫布的座標寬度就是「視窗寬度」（`contentSize = canvas.bounds.width`）。
同一則筆記在 Mac 寬視窗寫的物件，座標可能在 x=1400，到了 iPhone 就在畫面外。
匯出對不起來的根本原因在這裡，不是在繪圖程式碼。

**已決定的尺寸：800 × 1132 pt（A4 直式比例）**，已寫進核心
`padnote_doc::{PAGE_WIDTH, PAGE_HEIGHT}` 並透過 `standard_page_size()` 開到 FFI ——
兩個平台唯一的來源。維持 800 寬是為了讓既有內容的**水平位置完全不動**；
改成真正的 A4 595×842 會讓所有東西水平縮放，動得比需要的多。

| ID | 項目 | 判定條件 |
|---|---|---|
| ~~P-01~~ ✅ | 固定頁面座標空間（800×1132，來源在核心） | 頁面尺寸與視窗無關 |
| ~~P-02~~ ✅ | 畫布畫出頁面與可列印區界線 | 界線位置 = 匯出邊界 |
| ~~P-03~~ ✅ | 移除「延長本頁」，寫到頁尾自動準備下一頁 | 四個按鈕入口已移除 |
| ~~P-04~~ ✅ | 既有過長頁面重新分頁（備份、驗證、可回滾） | 13 條測試；診斷頁有按鈕 |
| ~~P-05~~ ✅ | Android 採用同一個頁面模型 | 尺寸同源，界線已畫出 |
| ~~P-06~~ ✅ | 匯出以頁面為準，不再依畫布寬度 | `PageThumbnailRenderer` 已改 |
| P-07 | 實機確認：重新分頁後的版面符合預期 | 只有真實資料才驗得出來 |
| B-01 | 實機確認：備份→重裝 App→復原，資料完整回來 | 只有真的重裝才驗得出來 |
| B-02 | 跨平台確認：iPad 做的備份在 Android 復原得回來 | 容器格式同源，但沒有實測過 |

**風險**：P-04 會動到使用者手上的真實資料。做法比照 WP4c：先寫遷移與回滾測試、
動手前備份、每一本驗過才算數、一本失敗不影響其餘。


## 🪢 套索選取重寫（2026-09-16，使用者回報「按鍵全部無效」）

原本整個套索建在 PencilKit 的**私有內部**上：用 `_hasSelection` 這個私有
選擇器（`unsafeBitCast` 硬轉函式指標）判斷有沒有選取，再把
`UIResponderStandardEditActions` 送給名稱含 `PKTiledView` 的私有子視圖。
送給不是 first responder 的視圖，那些 action 根本不會執行；Mac Catalyst
的 responder chain 與 PencilKit 的套索實作又都與 iOS 不同。
使用者看到的就是五顆按鈕全部沒有反應。

已改成自己做（`apple/Sources/LassoSelection.swift`）：手勢自己收、
多邊形自己算、`PKDrawing.strokes` 自己改，全部公開 API。判定規則
（`lasso_encloses`）在核心，與 Android 同一段程式碼。

| ID | 項目 | 狀態 |
|---|---|---|
| ~~L-01~~ ✅ | 核心的多邊形套索幾何 | `padnote-ink::is_enclosed_by_polygon`，5 項測試含「L 形套索不會抓到凹角外面的東西」與「開放套索自動封閉」|
| ~~L-02~~ ✅ | 核心的 session 套索操作 | `lasso_select` / `delete` / `copy` / `paste` / `translate`，5 項測試。**Android 從此也有套索能力**（原本完全沒有）|
| ~~L-03~~ ✅ | 移除私有 API | `_hasSelection` 與 `PKTiledView` 的 responder 戳法全部拿掉 |
| ~~L-04~~ ✅ | 重複的工具列 | 工具列上那一排移除，只留畫布上的浮動列，且改成**只在真的有東西可以做時**才出現 |
| **L-05** | **Apple 端的手勢實測** | ⚠️ **沒有驗過。** 模擬器上圈選沒有任何反應：沒有虛線框、沒有選取。試過把畫布捲動改成兩指、讓辨識器可同時成立，都沒有效果，而且分不出是「手勢沒觸發」還是「觸發了但選不到」。**需要在真機上手動確認**，或改用 UIKit 的觸控回呼而不是 `UIPanGestureRecognizer` |
| **L-06** | **Android 的套索 UI** | 核心能力已經在，但 Android 還沒有套索工具的介面 |

**現況要講清楚**：這一版把一個**已知壞掉而且用私有 API** 的實作，換成一個
**公開 API、幾何有測試、但端到端沒驗過**的實作。前者確定不能用，後者
至少沒有審核風險；但「現在能用了」這句話我還不能說。

## 📜 連續頁面模式（2026-09-15，使用者需求）

需求：開啟筆記本預設維持**整頁模式**（現況即是），頁尾加一個「連續頁面」
選項，切過去之後可以一路往下捲，不必按上一頁／下一頁。

**這不是小修，是編輯器核心的結構改動**，所以先記在這裡而不是硬做。

現況：整個編輯器繞著**單一** `CanvasRepresentable` 打轉 ——
`currentDrawing` 一個綁定、`currentPageIndex` 一個索引，
存檔、協同 oplog（`page_index`）、掌拒、套索、捲軸比例全部以它為單位。
好消息是 P-01 已經把頁面尺寸固定成 800 × 1132 並下沉到核心，
連續模式只是「把 N 個固定高度的頁面疊起來捲」，座標不必再動。

要做的事（Apple 與 Android 各一份）：

| ID | 項目 | 狀態 |
|---|---|---|
| ~~C-01~~ ✅ | `CanvasRepresentable` 加 `isScrollEnabled` | 單頁模式一行未改 |
| ~~C-02~~ ✅ | 連續容器：`LazyVStack` 疊 N 頁，每頁自己的畫布與物件層 | 模擬器確認 |
| ~~C-03~~ ✅ | 每頁各自載入／儲存筆跡 | 在第 2 頁畫的筆畫只寫進 `_p1.drawing`，`_p0` 沒被動到（檔案層級驗過） |
| ~~C-04~~ ✅ | 焦點頁由畫面中央決定 | 捲到第 2 頁，頁碼自動變 2/2、焦點框跟著移動 |
| C-05 | 協同、掌拒、套索逐頁接上 | 協同廣播、掌拒、套索狀態、canvasRef 都已接上，但**只有單機驗過**；兩台裝置同時寫沒有實測 |
| ~~C-06~~ ✅ | 模式切換與記住選擇 | 在頁碼旁；AppStorage 記住，重啟後仍在連續模式 |
| ~~C-07~~ ✅ | Android 同樣一套 | 新增 `ContinuousPagesView`：`LazyColumn` 疊 N 頁、每頁自己的 `InkEngine` 與物件 store；`./gradlew :app:compileDebugKotlin` 通過。實機觸控筆手勢仍列入 Android 實機待測 |

**做法**：連續模式是**另一棵視圖樹**，共用同一組元件
（`CanvasRepresentable`、`objectLayer(forPage:)`）。整頁模式那條路
一行都沒有改 —— 它綁著存檔、協同 oplog、掌拒與套索，是最沒本錢壞掉的地方。
前置的 `objectLayer(forPage:)` 抽取單獨提交（933e40f）當回退點。

**已知限制**：
- 頁面縮放用 `scaleEffect` 套在整頁上（800pt 固定寬 → 縮到視窗放得下）。
  只縮不放，放大會讓筆跡變糊。
- 手指在畫布上是畫畫不是捲動（與整頁模式一致）；捲動用兩指。
  這在沒有觸控筆的裝置上不直覺，但改掉會讓兩個模式的手寫行為不一致。
- Android 連續模式刻意改成 pen-only：筆交給畫布，手指交給 `LazyColumn` 捲動。
  沒有觸控筆的 Android 裝置若要用手指畫，切回整頁模式。


## 🧱 Android 介面落後（2026-09-15，使用者回報「完全不可用」）

Android 目前是**單一畫面**（`MainActivity.InkScreen()`）：兩個切換鈕、一列
筆刷、一行診斷字、一塊畫布，其餘功能全部塞在一個「...」下拉選單裡。
沒有首頁、沒有筆記本清單、沒有頁面切換、沒有手寫／打字模式切換。
檔案開頭的註解寫得很誠實：「現階段的唯一任務：證明 Kotlin ⇄ UniFFI ⇄
libpadnote_core.so 這條路是通的」—— 它至今仍是那個雛形，只是長出了幾個功能。

規模：Apple 31,574 行 / Android 12,444 行。Apple 有、Android 沒有的畫面：

HomeWorkbenchView（首頁與筆記庫）、頁面導覽、CollaborationSheet（協同）、
AssetLibraryView、Model3DStudioView、MathCalculatorSheet、CommentThreadView、
ThemeSpecificToolsView、WordTextStudioView（文字排版面板）、
ObjectFrameStyleMenu、CanvasScrollbar、DocumentViewerSheet、
ProColorPickerSheet、SketchRefineEngine、ImageEditControls、
PageRepagination、NotebookMigration、圖片插入與編修。

另外：診斷列（`tool=1 r=27.0dp p=0.41 …`）**在正式介面上永遠顯示**。
那一行是給開發看的，使用者看到的是「這是個測試程式」。

| ID | 階段 | 內容 | 狀態 |
|---|---|---|---|
| ~~A-00~~ ✅ | 立刻 | 診斷列預設隱藏，選單可開 | 實機驗證 |
| ~~A-01~~ ✅ | 第一階段 | 首頁／筆記本清單／搜尋／身分／備份 | 模擬器驗證 |
| ~~A-02~~ ✅ | 第一階段 | 分頁導覽（上一頁／下一頁／頁碼／新增／刪除） | 模擬器驗證 |
| ~~A-03~~ ✅ | 第一階段 | 手寫／打字模式切換 | 模擬器驗證 |
| ~~A-04~~ ✅ | 第二階段 | 圖片插入與編修、文字排版面板補齊 | 模擬器驗證 |
| ~~A-05~~ ✅ | 第二階段 | 物件通用能力 | 調色盤下沉核心、跨型別圖層面板、對齊與等距分佈 |
| ~~A-06~~ ✅ | 第三階段 | 剩餘功能 | 九項全部完成（見下方「A-06 收尾」） |
| ~~A-07~~ ✅ | 第三階段 | 連續頁面模式（C-07） | Android 已接上並通過 Kotlin 編譯；實機觸控筆/手指捲動體感另列待測 |

### A-06 收尾（2026-09-15）

九項全部完成，做法一致：**平台無關的那一半下沉核心**，兩邊各留一層薄 UI。

| 項目 | 核心模組 | 備註 |
|---|---|---|
| 數學 | `ffi_math` | 順帶擺脫 `NSExpression`（錯誤輸入會丟 ObjC 例外，Swift 攔不到）|
| 專業色票 | `ffi::designer_palette` | 原本兩平台的「淡藍」是不同的 hex |
| 文件檢視 | —— | Android 本來就有（Gradle `copyUserDocs`）|
| 討論串 | —— | `CommentPin` / `CommentLayer` |
| 草圖美化 | `padnote-ink::refine` + `ffi_sketch` | 順帶修掉「畫方框被美化成橢圓」|
| 主題工具 | `ffi_theme_tools` | 名稱改走語系鍵（原本是寫死的繁體中文）|
| 3D 模型 | `ffi_model3d` | 網格／旋轉／投影／明暗做成純數學，Android 用 Compose Canvas 畫 |
| 素材圖庫 | `ffi_assets` + `ffi_asset_art` | 58 件目錄 + 線圖變成路徑指令；Apple 端因此少了 1,833 行 |
| 協同編輯 | `ffi_collab` | 房號、邀請連結、AES-256-GCM 都在核心，**有 CryptoKit 實際產出的密文當測試向量** |

**沒有做、而且是刻意的**：

- Apple 素材圖庫那套「下載／快取／容量統計」Android 沒做。它的實質是把
  本機算繪的圖存成 PNG，沒有遠端伺服器；即時算繪又快又不會糊，
  少一套快取就少一個會過期、會對不上的狀態。
- 協同的 WebSocket 沒有下沉核心。搬進去要帶一整個 async runtime 與跨語言
  callback，換來的只是少寫幾十行連線樣板。協定與密碼學下沉就夠了。

### A-07 連續頁面：一個刻意的平台差異

Apple 的連續模式是「手指畫畫、兩指捲動」。Android 做不到同一套：
`LazyColumn` 的捲動手勢在滑動超過 touch slop 時就把事件攔走，
底下的畫布只收得到前幾個點。試過「偵測到筆就關掉 userScrollEnabled」——
**沒有用**，重組要等到下一幀，捲動手勢在那之前已經接手。

現在的做法是把判定交回核心的輸入仲裁器：連續模式下每一頁的引擎一律
**pen-only**。筆 → 判為墨跡，畫布吃掉事件；手指 → 判為手勢，畫布放行，
清單照常捲動。

代價要講清楚：**連續模式下手指畫不出東西**。沒有觸控筆的裝置要畫就切回
整頁模式（整頁模式的手指仍然可以畫，那條路一行都沒有改）。
### 已完成（2026-09-16，第二次）—— 順帶抓到 ANR 的真正原因

**ANR 的根因不是手勢，是重組風暴。** `InkCanvas` 的 `onInkChanged` 每收到
一個觸控取樣就呼叫一次，而連續模式把墨跡與物件**共用同一個計數器**，
底下五個物件圖層全部 `key(revision)` —— 寫一筆字（120Hz 下每秒上百個取樣）
就把圖片、形狀、表格、圖表、文字五個圖層整個丟掉重建，一秒好幾百次，
而且頁數越多越糟。

整頁模式看不出來：那邊本來就是分開的計數器（`imageRevision`、
`textRevision`…）。連續模式抄過來時合成了一個。

拆成 `inkRevision` / `objectRevision` 之後，手勢那一段才敢開。

實測（模擬器）：
- 一指作畫 → 筆畫出現、計數 9 → 10、`.strokes` 檔 6851 → 10620 bytes（真的落盤）
- 連續快速畫 10 筆 → 計數 10 → 20，**ANR 次數 0**
- 一指拖曳不會捲動（捲動已交給兩指）

**還沒驗的**：兩指捲動。`adb shell input` 只送得出單一指標，模擬器也沒有
真的多點觸控 —— 那一項要實機。

### 第一次嘗試的紀錄（已被上面取代）

照上面那條路實作過一次：`userScrollEnabled` **靜態**關掉（不是動態切換，
所以沒有差一幀的問題），捲動改由一個 `pointerInput` 在 Main pass 上偵測
兩指拖曳、用 `dispatchRawDelta` 自己推。每頁的引擎不再強制 pen-only。

**退回的理由，兩個都要講清楚**：

1. **驗不了。** 兩指手勢在這裡做不出來 —— `adb shell input` 只送得出
   單一指標，模擬器也沒有真的多點觸控。核心功能驗不了就不能出。
2. **觀察到一次 ANR。** 切進連續模式後第一次觸控，輸入派送逾時
   （`Waited 5973ms for MotionEvent ... action=UP`），App 當場沒有反應。
   **沒有證明**那就是這個改動造成的（沒有做對照組），但也沒有排除。

所以現在仍然是 pen-only 那一版。要重做的話，**前置條件是一台真的
觸控裝置**：先確認兩指捲動會動、一指畫得出來，再確認連續按幾分鐘
不會 ANR。程式面的做法上面寫完了，照著寫就好。

### 順帶修掉的嚴重缺陷：Android 從來沒有把存檔的墨跡讀回來

`InkEngine` 只裝「這一次開啟期間畫的」筆畫。寫進核心是有的、`.padnote` 裡
也真的有資料，但**重開筆記本之後畫面是空的** —— 使用者寫的字看起來憑空消失。
物件（文字方塊、表格、形狀、圖表）都有各自的 `load()`，只有墨跡沒有，
所以症狀是「圖還在、字不見了」，看起來像渲染壞掉而不是少讀一份資料。

已補上 `InkEngine.load()`（走核心既有的 `visible_stroke_details`）並在開頁時
呼叫。模擬器實測：修正前「0 strokes」、畫面空白；修正後「8 strokes」、
筆跡正常顯示。

**還沒驗證的**：

- 58 張線圖的**視覺結果**：2026-09-16 補了一個對照表產生器，
  `cargo run -p padnote-core --example asset_contact_sheet -- out.svg`，
  一張 SVG 畫完 58 件。人眼看過一輪，58 件全部畫得出來且認得出是什麼。
  **它證明的只有「核心產生的形狀本身對不對」** —— 平台層如果把路徑畫錯
  （線寬、填色、座標縮放），這張圖看不出來。那一項仍然要兩台裝置
  開同一件素材並排比對。
  幾件偏抽象、可以再畫細一點（判斷留給你）：CNC 狗骨清角、
  iOS/Material 雙系統導覽列、設計語意色彩矩陣。
- 協同編輯只有單機建置驗證，**沒有兩台裝置實際連過**。
  判定方式：一台 iPad 建房、一台 Android 用邀請連結加入，
  A 畫的筆畫要出現在 B 上，且 B 的成員清單看得到 A。
- Android 的 `usesCleartextTraffic` 是為了 ws:// 的區域網路中繼。
  oplog 本身是端對端加密的，但走公開網路時仍應改用 wss://。

**第一階段（A-00～A-03）已完成** —— 那是「能不能當筆記 App 用」的分界：
Android 現在有首頁、翻得動頁、分得清手寫與打字。

**A-01 原本尚未涵蓋 Apple 有的四項，2026-09-16 全部補齊**：

| 項目 | 現況 |
|---|---|
| 素材圖庫 | 早就有了（`asset/AssetLibrarySheet.kt`）。原本這一行是過期的 |
| 資料夾階層 | `library/FolderTree.kt` + 首頁的麵包屑、資料夾列、搬移對話框。資料夾住在同步索引裡，不另存一份本機清單 |
| 最近錄音清單 | `library/RecordingIndex.kt`。掃套件裡的 `media/audio`，不另外維護索引 —— 另外維護的話，從別台同步過來的錄音不會出現，而那正是最該顯示的東西 |
| 繼續區塊的縮圖預覽 | `library/NotebookThumbnails.kt`。算繪走核心既有的 `export_page_png`，與匯出同一條路；快取的鍵帶上修改時間，不必另做失效判斷。**縮圖裡沒有畫布物件**（文字方塊、表格、圖表、圖片），所以一本只打字沒手寫的筆記縮圖是空白頁 —— 那不是壞掉 |

**A-04 過程中修掉的既有缺陷**（都不是新功能，是本來就壞的）：
- 物件座標單位錯誤：ShapeLayer / TableLayer / ChartLayer 把頁面點當成像素，
  在 density = 1.0 的模擬器上看不出來，真實手機（2～3.5 倍）會縮到三分之一
  並擠向左上角，而同一份筆記在 iPad 上位置是對的。
- 文字排版面板只有新增時開得起來，既有方塊再也改不到樣式。
- 文字方塊只有拖曳才選得到，點一下沒反應。
- 卡片「淡藍」兩個平台是不同的 hex。


## 🗂 物件堆疊順序（2026-09-15）

已完成（Apple）：`NotebookDocument.objectOrder`＋`CanvasStackPanel`，
七種型別（圖片／文字／表格／圖表／3D／連結／形狀）共用同一份順序，
四個動作（移到最上／上移／下移／移到最下）11 項邏輯測試通過。

**尚未收斂**：

| ID | 項目 | 說明 |
|---|---|---|
| ~~Z-02~~ ✅ | 順序改放在筆記本中繼資料 | `objectOrderByPage` 走 `SetNotebookMeta`，跨得過平台（format-spec §6.2.1） |
| Z-03 ✅ | v3.8.0 的逐頁 bug | 那一版在第 2 頁調順序會清掉第 1 頁的。已改成逐頁，並保留舊欄位當退路（直接改型別會讓整本筆記解不開） |
| ~~Z-01~~ ✅ | Android 端的圖層面板 | `CanvasStackPanel` + `NotebookMeta.kt`，13 項 JUnit 測試 |

順序現在存在筆記本中繼資料裡（`objectOrderByPage`），那份 JSON 會寫進
`.padnote` 並跟著同步走，所以兩個平台讀的是同一份。
（2026-09-16 更正：原本這裡寫「Android 還缺圖層面板 UI」，那已經過期 ——
`canvas/CanvasStackPanel.kt` 早就在了，見上表 Z-01。）

核心的物件樹另有一套 `bring_to_front` / `draw_order`，那是給**形狀**用的
（形狀是核心的原生物件）。文字與圖片是 block 不是 object，不在那棵樹上，
所以跨型別的順序仍然需要中繼資料這一層。


## ⚪ 待決策（需要人拍板）

| ID | 問題 | 背景 |
|---|---|---|
| ~~D-01~~ | ~~附件（PDF）是否納入內容定址 blob~~ ✅ **取預設：納入**（2026-09-16，我方決定，可推翻）。同一份講義插進五本筆記只存一份；完整性檢查與 GC 也沿用既有那一套，不必為附件另寫一份 |
| ~~D-02~~ | ~~墓碑 GC 策略~~ ✅ **取預設：永不自動清除**（2026-09-16，我方決定，可推翻）。墓碑是一筆 id + 時戳 + 裝置 id，一萬筆也才幾百 KB；而清早了的代價是**刪除復活** —— 一台離線超過保留期的裝置再上線，會把它那份「還活著」的舊紀錄推回去。省那幾百 KB 不值得換這個 |
| ~~D-03~~ | ~~大型筆記本的 strokes 檔分片閾值~~ ✅ **取預設：不分片**（2026-09-16，我方決定，可推翻）。同步的單位已經是 **oplog 檔**（G-02c），不是 strokes 檔 —— 分片要解決的「整檔重傳」問題在那一層就不存在了。等真的量到讀取延遲再說 |
| ~~D-04~~ | ~~自訂筆（`tool_id` 100+）的參數序列化格式~~ ✅ **取預設：JSON 物件，未知鍵原樣保留**（2026-09-16，我方決定，可推翻）。關鍵是**保留**而不是格式本身：舊版讀到新版寫的筆，不認得的鍵要原封不動存回去，否則在舊裝置上開一次筆記，新參數就被靜靜清空了 |
| ~~D-05~~ | ~~長期維護與營收模式~~ ✅ **已決議：不營收，也不收捐贈**（2026-09-13 決定不營收；2026-09-16 補：**連捐贈連結都不放**）。App 標榜免費，不會有帳號要填，`.github/FUNDING.yml` 已移除。`docs/SUPPORT.md` 保留，說明每年約 US$99 的實際支出與不會做的三件事 |
| ~~D-06~~ | ~~多裝置金鑰首次配對的 UX~~ ⛔ **取消**（2026-09-16）。不做 QR code 配對流程。要重開的話，前提是先確定端對端加密的筆記本要不要跨裝置共享金鑰 |
| ~~D-08~~ | ~~壓感觸發的語意~~ ✅ **已決議：由硬體決定，核心不寫死**（2026-09-16）。核心只回報**正規化後的壓感**與**這支筆實際回報的能力**（有無壓感、有無側鍵、幾段）；行為是一張可設定的對應表。預設：**壓感只影響筆畫粗細與濃度，不觸發任何模式切換** —— 不同筆的壓感曲線差很多，把切換綁在深度上，在某些筆上會變成寫字寫到一半突然換工具。等有實際的筆再把那張表填成要的樣子，不必改程式 |
| ~~D-09~~ | ~~格式互通策略~~ ✅ **已決議：PDF/MD 為主 + 盡力而為的單向匯入**（2026-09-16）。「與 10 款競品完全相容互通」無法達成：多數是專有未公開格式，而且真正的互通需要**對方也讀我們的格式**。細節見 requirements-review.md §6 |
| ~~D-10~~ | ~~Office／Google 文件的呈現方式~~ ✅ **已於 ADR-0009 拍板為「嵌入＋可編輯」**（docx/xlsx 可編輯，pptx 只做預覽）。這一列是遺留的重複條目，S-41 早已完成 |
| ~~D-07~~ | ~~是否採用 Paraformer-zh 與 ct-punc？~~ ✅ **已決議：選 C 自行匯出**（ADR-0006） | 官方 HF repo 有完整 Apache-2.0 LICENSE 檔，但 FunASR GitHub 的 MODEL_LICENSE v1.1 寫「僅供參考與學習」且含不得詆毀/自動終止條款。**影響 P0 功能 C5 中文標點還原**。四個選項與建議見 `models/LICENSE-AUDIT.md` §5 |
