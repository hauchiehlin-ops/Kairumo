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
| ~~S-44b~~ ✅ | 匯出真正的 PDF `/Ink` 標註 | **兩平台皆已達成**。Apple 的匯出改走核心的匯出器（原本是點陣合成）；核心同時輸出向量筆畫與 `/Subtype /Ink` + `/InkList` + `/BS`。3D 模型與連結卡片核心沒有那兩種型別，改以算繪後的圖片帶進去，內容不會掉 |
| S-44 | 用其他 App 實測 | **需要你來測**（我裝不了那些 App）。已產出範例 PDF（兩頁、三筆畫、三個獨立 Ink 標註）。判準：那三條線能不能在 Goodnotes / Notability / PDF Expert 裡被**選取、搬動、刪除** |
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
| C-07 | Android 同樣一套 | **尚未開始**。Android 目前連頁面導覽都沒有（見 A-02），要等那邊做完 |

**做法**：連續模式是**另一棵視圖樹**，共用同一組元件
（`CanvasRepresentable`、`objectLayer(forPage:)`）。整頁模式那條路
一行都沒有改 —— 它綁著存檔、協同 oplog、掌拒與套索，是最沒本錢壞掉的地方。
前置的 `objectLayer(forPage:)` 抽取單獨提交（933e40f）當回退點。

**已知限制**：
- 頁面縮放用 `scaleEffect` 套在整頁上（800pt 固定寬 → 縮到視窗放得下）。
  只縮不放，放大會讓筆跡變糊。
- 手指在畫布上是畫畫不是捲動（與整頁模式一致）；捲動用兩指。
  這在沒有觸控筆的裝置上不直覺，但改掉會讓兩個模式的手寫行為不一致。


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
| A-05 | 第二階段 | 物件通用能力：框線樣式選單、對齊、圖層面板補齊跨型別 | 未開始 |
| A-06 | 第三階段 | 協同、資產庫、3D、數學、討論串、文件檢視、專業色票、草圖美化 | 未開始 |
| A-07 | 第三階段 | 連續頁面模式（C-07） | 等 A-02 完成後可做 |

**第一階段（A-00～A-03）已完成** —— 那是「能不能當筆記 App 用」的分界：
Android 現在有首頁、翻得動頁、分得清手寫與打字。

**A-01 尚未涵蓋 Apple 有的**：資料夾階層、素材圖庫、最近錄音清單、
繼續區塊的縮圖預覽。那些各自需要底層支援，排在 A-05 之後。

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
| Z-01 | Android 端的圖層面板 | 資料格式已經就緒，缺的是 Android 的 UI |

順序現在存在筆記本中繼資料裡（`objectOrderByPage`），那份 JSON 會寫進
`.padnote` 並跟著同步走，所以兩個平台讀的是同一份。Android 還缺的是讀寫
它的圖層面板 UI。

核心的物件樹另有一套 `bring_to_front` / `draw_order`，那是給**形狀**用的
（形狀是核心的原生物件）。文字與圖片是 block 不是 object，不在那棵樹上，
所以跨型別的順序仍然需要中繼資料這一層。


## ⚪ 待決策（需要人拍板）

| ID | 問題 | 背景 |
|---|---|---|
| D-01 | 附件（PDF）是否納入內容定址 blob | 傾向是，可跨筆記本去重 |
| D-02 | 墓碑 GC 策略 | 保留期 vs 快照後清除；影響檔案成長速度 |
| D-03 | 大型筆記本的 strokes 檔分片閾值 | |
| D-04 | 自訂筆（`tool_id` 100+）的參數序列化格式 | |
| ~~D-05~~ | ~~長期維護與營收模式~~ ✅ **已決議：不營收 + 捐贈連結**（2026-09-13）。`.github/FUNDING.yml` 已備妥，**待填入你自己的 GitHub Sponsors 或 Ko-fi 帳號**；`docs/SUPPORT.md` 說明了每年約 US$99 的實際支出與不會做的三件事 |
| D-06 | 多裝置金鑰首次配對的 UX | QR code 傳遞 DEK 的具體流程 |
| **D-08** | **壓感觸發的語意** | 按壓深度要觸發什麼？切換筆刷？橡皮擦？這是產品決策不是實作細節 |
| **D-09** | **格式互通策略** | ⛔ 「與 10 款競品完全相容互通」**無法達成**（多數為專有未公開格式，且互通需對方也讀我們的格式）。建議改為「PDF/MD 為主 + 盡力而為的單向匯入」，見 requirements-review.md §6 |
| **D-10** | **Office／Google 文件的呈現方式** | 試算表與簡報放進手寫筆記本要長什麼樣？唯讀嵌入／可編輯／轉文字 |
| ~~D-07~~ | ~~是否採用 Paraformer-zh 與 ct-punc？~~ ✅ **已決議：選 C 自行匯出**（ADR-0006） | 官方 HF repo 有完整 Apache-2.0 LICENSE 檔，但 FunASR GitHub 的 MODEL_LICENSE v1.1 寫「僅供參考與學習」且含不得詆毀/自動終止條款。**影響 P0 功能 C5 中文標點還原**。四個選項與建議見 `models/LICENSE-AUDIT.md` §5 |
