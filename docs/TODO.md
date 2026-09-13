# 待辦事項

> 分三類：**🔴 被硬體/資料卡住**（程式已就緒，等外部條件）、
> **🟡 待實作**（純軟體，可直接做）、**⚪ 待決策**（需要人拍板）。

---

## 🔴 被硬體或資料卡住（程式已就緒）

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

### H8. libpdfium 執行期庫
- **卡在**：`pdfium-render` 只是綁定，實際的 `libpdfium` 動態庫需另外提供
- **要做**：iOS 靜態連結、macOS/Windows 隨 App 附帶；取得或自建 libpdfium
- **備註**：**建構成功不代表能執行** —— 目前只驗證了介面與邊界檢查
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
| S-13 | WP5 | Opus 編碼整合 | 需 `libopus` 綁定，**無法在此驗證** |
| S-15 | WP5 | sherpa-onnx / whisper.cpp 實作 `AsrEngine` | 管線編排已就緒，插進去即可 |
| S-23 | — | 文字 op 寫入 `doc/ops/` 持久化 | CRDT 與編碼已完成，缺落盤 |
| S-19 | WP20 | iCloud `CloudProvider` 實作 | Swift 側；演算法已由 S3 驗證 |
| S-20 | WP23 | llama.cpp 整合（摘要、待辦抽取） | P2 |
| S-21 | WP7 | PDFium 綁定（`pdfium-render`）| 介面與快取已完成，**需原生庫，實機驗證見 H6** |
| S-22 | WP12 | Apple Vision / ML Kit 的 `HwrEngine` 實作 | 註冊表與 fallback 鏈已完成 |

## 🆕 需求檢視新增項目（2026-09-12）

> 完整分析見 [`docs/requirements-review.md`](requirements-review.md)。

| ID | 項目 | 備註 |
|---|---|---|
| ~~S-41~~ ✅ | Office / Google 文件的嵌入與編輯（D-10 已拍板為「嵌入＋可編輯」） | 見 ADR-0009。docx/xlsx 可做，pptx 只做預覽 |
| ~~S-42~~ ✅ | PDF 標註的雙向保真（ADR-0008 第一層的核心） | 10 款競品都讀寫 PDF，這是唯一真正通用的互通途徑 |
| ~~S-45~~ ✅ | 平台層依 `Decision::retract` 實作筆畫收回 | **兩平台皆已實作**：Android 在 `InkEngine`；Apple 新增 `PalmRejectionCoordinator`（偵測到筆就切 `.pencilOnly`，並收回筆落下前 500ms 內的筆畫）。原本 Apple 在手寫模式下是 `.anyInput`，手掌畫得出東西 |
| ~~S-43~~ ✅ | 把標註寫進真實 PDF（PDFium 的 annotation API） | `create_annotated_pdf` 實作完成，經測試驗證 |
| S-44 | 用其他 App 驗證標註互通 | **需要你來測**（我裝不了那些 App）。先知道一件事：目前匯出的 PDF 是**點陣合成**（`page.image.draw`），不含 `/Ink` 標註 —— 在別的 App 裡「開得起來、可以在上面加註」成立，但我們的筆畫不是可編輯的標註物件。核心的 `padnote_pdf` 已有 `FfiPdfAnnotation` 與 quad points，要做真正的向量標註互通得把它接上匯出路徑 |
| S-44b | 匯出真正的 PDF `/Ink` 標註 | 前提是 S-44 的驗證結果顯示你需要「在別的 App 裡繼續編輯我們的筆畫」。若只需要「看得到、能在上面加註」，目前的點陣匯出已經夠用 |
| S-35 | **Windows 低延遲墨跡** | **目前沒有 Windows 版**，這一條在有 Windows 版之前不成立。內容本身是結論不是待辦：Compose MP Desktop 走 Skia/JVM 做不到 9ms，要原生 Windows Ink / DirectComposition。建議轉成 ADR 記著，等真的要做 Windows 時才重新評估 |
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
| S-54b | **素材庫的 58 個中文名稱** | `AssetLibraryManager` 的齒輪組、軸承等技術名稱是**資料**不是介面文字，要另外處理（每個名稱都要六國語系的正確技術術語，不是直譯） |
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


## ⚪ 待決策（需要人拍板）

| ID | 問題 | 背景 |
|---|---|---|
| D-01 | 附件（PDF）是否納入內容定址 blob | 傾向是，可跨筆記本去重 |
| D-02 | 墓碑 GC 策略 | 保留期 vs 快照後清除；影響檔案成長速度 |
| D-03 | 大型筆記本的 strokes 檔分片閾值 | |
| D-04 | 自訂筆（`tool_id` 100+）的參數序列化格式 | |
| D-05 | 長期維護與營收模式 | 見 `plans/sustainability-evaluation.md`。**先算錢：每年約 US$99（僅 Apple 開發者帳號）**，其餘全部 US$0。建議「不營收 + 捐贈連結」，付費選項隨時可加且不需後端。要拍板：接受嗎、捐贈放哪個平台 |
| D-06 | 多裝置金鑰首次配對的 UX | QR code 傳遞 DEK 的具體流程 |
| **D-08** | **壓感觸發的語意** | 按壓深度要觸發什麼？切換筆刷？橡皮擦？這是產品決策不是實作細節 |
| **D-09** | **格式互通策略** | ⛔ 「與 10 款競品完全相容互通」**無法達成**（多數為專有未公開格式，且互通需對方也讀我們的格式）。建議改為「PDF/MD 為主 + 盡力而為的單向匯入」，見 requirements-review.md §6 |
| **D-10** | **Office／Google 文件的呈現方式** | 試算表與簡報放進手寫筆記本要長什麼樣？唯讀嵌入／可編輯／轉文字 |
| ~~D-07~~ | ~~是否採用 Paraformer-zh 與 ct-punc？~~ ✅ **已決議：選 C 自行匯出**（ADR-0006） | 官方 HF repo 有完整 Apache-2.0 LICENSE 檔，但 FunASR GitHub 的 MODEL_LICENSE v1.1 寫「僅供參考與學習」且含不得詆毀/自動終止條款。**影響 P0 功能 C5 中文標點還原**。四個選項與建議見 `models/LICENSE-AUDIT.md` §5 |
