# 開發日誌

> 反序排列（最新在上）。每個開發階段結束時追加一筆。
> 記錄**為什麼**這樣做，而不只是做了什麼 —— 「做了什麼」看 git log 就好。

---

## 2026-09-12 (8) · 模型授權稽核

### 做了什麼
在動手接 Paraformer-zh 之前先查授權（決策 D6 要求權重與程式碼分別確認）。
產出 `models/LICENSE-AUDIT.md`，排除一個模型，把另外兩個升級為待決策事項。

### 查到什麼

**Paraformer-zh 與 ct-punc 有雙通路授權衝突。**
同一份權重，兩個散布通路條款不一致：
- HF `funasr/*` 官方 repo：metadata 標 apache-2.0，且 **repo 內含完整的
  Apache-2.0 LICENSE 檔**，README 明文宣告以 Apache-2.0 發布權重
- FunASR GitHub 的 `MODEL_LICENSE`（v1.1）：授權「**僅供參考與學習使用**」，
  另含「不得詆毀」條款與違反即自動終止

著作權人對不同通路採不同授權是常見做法，HF 那份 LICENSE 檔是明確的授權讓與。
但通路 B 的措辭若被主張適用，產品使用就有疑義。**這是帶法律性質的判斷，
不該由我單方面決定** → 列為待決策 D-07。

**SenseVoice-Small 直接排除。**
權重走 FunASR Model License v1.1，不是 Apache-2.0。社群 2026-01 開的商用釐清
issue 至今**無維護者回覆**。「不得詆毀 + 自動終止」不是 OSI 開源授權，
與 `features.md` §4 賣點 3、4 宣稱的「開源、永遠免費且不可能反悔」直接衝突。
C9（中英夾雜）改由 whisper-large-v3-turbo 承擔 —— 它本來就支援 code-switching，
授權是乾淨的 MIT。

**官方 repo 沒有 ONNX。**
`funasr/*` 只有 PyTorch `model.pt`。目前 manifest 指的是第三方轉換版。
Apache-2.0 允許衍生作品，但轉換者的宣告不能高於上游授予的權利 ——
provenance 多了一層。

### 為什麼停在這裡而不直接接
C5（中文標點還原）是 **P0** —— 「中文轉錄沒有標點等於沒用」是市調寫進規格的
結論。若 D-07 選擇不採用，這個 P0 功能需要另找方案。
換句話說，D-07 不只是「要不要多一個 ASR 引擎」，而是**會不會少一個 P0 功能**。
這種等級的取捨應該由專案擁有者決定。

### 這次稽核的方法論
不只看 metadata 標籤，而是**實際抓 LICENSE 檔、讀 README 原文、查未結的
issue**。silero 那次的教訓（URL 指向需登入頁面）已經證明：
沒被實際驗證過的宣告等於沒有。

---

## 2026-09-12 (7) · Silero VAD（S-26）

### 做了什麼
376 → **395 個測試**。`padnote-vad-silero`（ort + Silero v4）、
遲滯開關邏輯、接進 `NotebookSession` 與 FFI、修正 manifest 的壞 URL。

### 為什麼換掉 EnergyVad —— 有數字
白噪音（振幅與語音相當）餵進兩個 VAD，100 個音框：

```
EnergyVad 誤判 100 個為語音
Silero    誤判   0 個
```

能量門檻法在真實教室（冷氣、投影機風扇）等於完全不可用。

### 選型過程

**先試純 Rust 的 tract，失敗了（ADR-0005）。**
`tract-onnx` 無法載入 Silero —— v4 與 v5 都含 8k/16k 的條件分支，
兩個分支輸出秩不一致，`ToTypedTranslator` 直接失敗。這是 tract 的能力邊界，
不是設定問題。

改用 `ort` 其實是**更好的架構決定**：同一個執行期之後還要服務
Paraformer-zh（S-24）與 PP-OCRv5（D4），一套推論庫服務三個用途。

**遲滯邏輯與模型推論分離。**
`SpeechGate` 是純邏輯、零相依、完整可測。用單門檻會在機率貼近臨界時
來回跳動，把一句話切成碎片 —— 有測試明確驗證遲滯區間內零狀態切換。

**內部緩衝而非要求對齊。**
Silero v4 只吃 512 樣本，但 `Segmenter` 用 20 ms（320 樣本）。
讓 VAD 內部緩衝，呼叫端不必為了模型改變粒度。

**模型缺失時降級而非失敗。**
錄音不該因為 VAD 用不了就停擺（S-25 的音檔優先原則）。
`uses_neural_vad()` 讓 UI 能提示使用者分段品質會下降。

### 踩到的坑

**manifest 裡的 URL 從來沒被驗證過。**
原本 silero 指向的 HuggingFace 路徑需要登入，`curl` 拿到的是 29 bytes 的
`Invalid username or password`，副檔名還是 `.onnx`。
**清單裡沒被實際下載過的 URL 等於沒有。** 已改用官方 repo 並補上真實雜湊，
同時加測試要求「已填雜湊的項目不得仍標記授權待審」。

**`ort` 2.0-rc 的 API 與舊版差異大**：`session.inputs` 變成 `inputs()`、
`name` 變成 `name()`、`to_array_view` 變成 `try_extract_tensor` 回傳
`(shape, slice)` 元組。

---

## 2026-09-12 (6) · 錄音編排（S-25）

### 做了什麼
348 → **376 個測試**。`padnote-recorder`（管線 + 轉錄 worker）、
接進 `NotebookSession`、FFI 曝露、端到端整合測試、可執行的示範程式。

### 為什麼這樣做

**把「音檔優先落地」做成型別層次的保證，而不是註解裡的承諾。**
`RecordingPipeline` **完全不持有 `AsrEngine`** —— 想在 `feed()` 裡呼叫模型？
沒有那個欄位可以呼叫。這讓「轉錄拖慢錄音」與「轉錄失敗丟音訊」在結構上
不可能發生，而不是靠紀律維持。這正是 Notability 最大差評的解法。

**`feed()` 內的順序不可調換。**
先把音訊寫進 Opus 檔，再做 VAD 分段。VAD 或分段出錯時，音訊已經安全了。

**開檔先於記錄 session。**
顛倒的話，當機會留下「有 session 記錄但沒有音檔」的孤兒。

**佇列溢位丟最舊的段，但音檔照寫。**
ASR 完全跟不上時，掉的只是待辨識的副本；錄音本身不受影響，
而且 `segments_dropped` 會回報給 UI 提示換小模型。

### 踩到的坑

**實際跑一次才發現的回報缺陷。**
示範程式印出「音檔時長: 0 ms」—— 因為 `recorded_audio_us()` 讀的是 pipeline，
而停止錄音後 pipeline 已被取走。單元測試沒抓到，因為它們都在錄音中查詢。
改成累計保存並補上測試。**這就是為什麼要真的跑一次，而不只是跑測試。**

**`#[cfg(test)] impl` 放在 `mod tests` 之後會觸發 clippy 的
`items_after_test_module`。**

### 外部驗證
`cargo run -p padnote-core --example record_session` 產出真實的 `.padnote` 套件，
`ffprobe` 確認音檔為 `Duration: 00:00:03.00, opus, mono` —— 完整流程的產出
是任何播放器都能開的標準檔案。

### 仍未驗證
- VAD 目前是**能量門檻法**，有背景噪音時會把冷氣聲當語音（S-26 待換 Silero）
- 背景 worker 的低優先權執行緒尚未實作（S-27，屬平台層）
- 真實 ASR 品質仍待 H2 的中文測試集

---

## 2026-09-12 (5) · 文件持久化與原生相依

### 做了什麼
325 → **348 個測試**。文件 op-log 持久化（S-23）、Opus 音訊編碼（S-13）、
whisper.cpp ASR 引擎（S-15）、PDFium 適配層（S-21）。

### 為什麼這樣做

**S-23 的範圍比原本大。**
原本只要把文字 op 落盤，但一查才發現**頁面、區塊、錄音 session 從來沒有
持久化過** —— 只有筆畫會落盤。所以做成完整的 12 種 `DocOp` 與 `open()` 重播，
而不是只補文字那一塊。

**record() 先落盤再套用。**
反過來的話，中途當機會讓記憶體與磁碟不一致，使用者看到的是
「有效果但沒存到」—— 那比直接失敗更糟。

**先實測哪些原生相依能編譯，再決定要不要寫。**
pdfium-render、audiopus、whisper-rs 都先用 probe 專案試編。能編譯才動手，
避免寫完一堆無法驗證的程式碼。

**Opus 用 ffprobe 做外部驗證。**
自己寫的測試只能證明「跟我想的一樣」。`ffprobe` 回報
`Duration: 00:00:02.00, 32 kb/s, mono` —— granule 算錯的話時長會顯示成 1/3，
這是真正獨立的驗證。

### 踩到的坑

**UniFFI 會靜默略過名為 `open` 的建構子。**
`open` 是 Swift 的存取修飾關鍵字。Rust 端編譯正常、綁定產生正常，
但 Swift 端就是看不到那個方法。改名為 `open_existing` 並加測試釘住。
**這類無聲失敗是 FFI 最危險的地方。**

**PDFium 不是執行緒安全的。**
`Pdfium` 持有的綁定既非 `Send` 也非 `Sync`，連 `thread_safe` feature 也不足以
滿足我們 trait 的約束。改成每次操作重新綁定（dlopen 有快取，成本遠低於渲染）。
更重要的影響是：**多頁渲染無法平行化**，J2 的效能預算只能靠 `PageCache`
的預抓，不能靠開執行緒。

### 誠實標記
- Opus：**已驗證**（ffprobe 外部確認）
- 文件持久化：**已驗證**（往返測試涵蓋頁面/文字/錄音/索引/墓碑）
- whisper：**編譯與錯誤路徑已測，轉錄品質未驗證**（需模型 + 中文測試集）
- PDFium：**介面與邊界檢查已測，實際解析未驗證**（需 libpdfium 執行期庫）

---

## 2026-09-12 (4) · 文字 CRDT 與 UniFFI 綁定

### 做了什麼
265 → **299 個測試**。`padnote-doc::text`（CRDT + 二進位編碼）、
文字同步端到端驗證（S-16）、`padnote-core::ffi`（UniFFI 門面）、
Swift/Kotlin 綁定產生腳本、XCFramework 建置腳本、CI 綁定閘門。

### 為什麼這樣做

**先做 CRDT 再做 UniFFI。**
CRDT 會改變 core 的 API 表面，反過來做等於要重弄一次綁定。

**自行實作 CRDT 而非引入 yrs（ADR-0004）。**
需求是純文字 —— 粗體、標題、待辦這些屬性住在 `Block` 層級，不在字元流裡。
換到的是與既有 oplog／Lamport 一致、零額外相依、每條收斂性質都有測試。

**FFI 獨立一層，不直接匯出內部型別。**
`Uuid`、`NotebookTime`、trait 物件都過不了 FFI 邊界；更重要的是，
內部重構不該逼著兩個平台的 UI 一起改。這一層是穩定契約。

**`visible_strokes` 只回傳摘要，不回傳取樣點。**
一頁數萬個點跨 FFI 邊界會很慢。渲染資料由平台層直接讀 `.strokes` 檔。

**綁定不進版控。**
與 core API 不同步的綁定比沒有更危險。改 `ffi.rs` 後跑
`scripts/generate-bindings.sh`，CI 也會驗證產得出來。

### 踩到的坑
- **併發插入的測試一開始就寫錯**：忘記讓兩端先套用自己的操作，
  結果是「兩邊各缺一半」而非不收斂。**測試本身錯了比實作錯更難發現** ——
  修正後補上「各自本地結果」的中間斷言，這樣下次失敗會指向正確的地方
- `uniffi` 的 bindgen 需要 `features = ["cli"]`，否則 `uniffi_bindgen_main` 找不到
- `#[derive(uniffi::Object)]` 的結構仍受 `missing_debug_implementations` 檢查

### 驗證結果
S-16 端到端：三站 300 次併發編輯（插入 430 字、刪除 105 字），
經二進位編碼 → 加密 → SyncEngine → 本機資料夾 → 拉取 → 解密 → 解碼 → 套用，
**三台文字完全一致、緩衝區歸零**。另含「刪除與插入交錯」「離線追平」
「同位置併發輸入兩邊都保留」「磁碟上為密文」等迴歸測試。

Swift 綁定已產生並通過 iOS SDK 語法檢查，API 為慣用的 camelCase + throws。

### 下一步
剩下的幾乎都需要原生相依或實機：PDFium、Opus、sherpa-onnx、
Apple Vision 的 `HwrEngine` 實作。

---

## 2026-09-12 (3) · 引擎、模型與 PDF 層

### 做了什麼
205 → **265 個測試**。新增 `recognize::registry`（HWR fallback 鏈）、
`core::setup`（引擎與權限中心）、`padnote-models`（下載器）、
`padnote-pdf`（介面 + LRU 頁面快取），以及機器可讀的 `models/manifest.json`。

### 為什麼這樣做

**權限與引擎狀態機放在 core 而非各平台 UI。**
「錄音要不要麥克風權限」「轉錄缺哪個模型」若寫在 Swift，Android 版要重寫一遍，
兩邊必然長歪。core 判斷、UI 只負責畫。

**`Feature::CoreNotes` 的需求清單刻意是空的。**
手寫與打字不依賴任何權限或模型 —— 全新安裝、零權限的狀態下就該能用。
這是產品定位的基石，用測試把它釘住。

**未回報過的能力預設為 `Unsupported` 而非 `Ready`。**
樂觀假設會讓功能在執行期才爆炸，那時已經來不及給使用者好的錯誤訊息。

**模型清單用 `"sha256": "pending"` 而不是填假雜湊。**
填佔位雜湊看起來「完成度高」，但有人會誤以為可以出貨。現在的行為是
**下載器直接拒絕**，而且有測試確保它連網路請求都不發出。

**網路 IO 抽象成 `Fetcher` trait。**
續傳與驗證邏輯是最容易寫錯、又最難在真機上重現的部分。抽象掉之後，
「伺服器不支援 Range」「回傳空資料」「本機半檔比宣告還大」這些情境
全部可以離線測。

### 踩到的坑
- `OpenOptions::create(true).write(true)` 未指定 `truncate` 會觸發 clippy 警告；
  續傳情境必須明示 `truncate(false)`，否則會毀掉既有進度
- `RenderKey` 用 f32 當 HashMap key 不可行，改存 ×100 的整數

### 下一步
剩下的幾乎都需要原生相依或實機：UniFFI 綁定（S-12）可以做，
PDFium / Opus / sherpa-onnx（S-21/S-13/S-15）能編譯但**無法在此驗證正確性**。

---

## 2026-09-12 (2) · 核心邏輯層

### 做了什麼
新增 6 個實作完整的模組，workspace 從 55 → **205 個測試**：
storage（套件/blob）、ink::geometry、search（CJK 索引）、asr::pipeline、
crypto（信封加密 + 復原碼）、sync::engine、export（MD/SVG）、
core::app（NotebookSession 門面）。

同時建立 `STATE.md` / `DEVLOG.md` / `TODO.md` 交接文件。

### 為什麼這樣做

**先把純邏輯層做完，UI 與模型整合往後放。**
使用者的方針是「先把所有功能建起來再 debug」。純 Rust 邏輯當場可驗證，
而 UI 與 ASR 模型需要實機迭代 —— 先做能驗證的，把不能驗證的變成明確的接手點。

**搜尋自己實作而不直接上 Tantivy。**
中文斷詞才是難點，不是倒排索引。bigram 免詞典、免模型、對未登錄詞（「特徵值」）
不會切錯，代價只是索引較大 —— 本機單機搜尋完全可接受。
`SearchIndex` 介面不變，P2 想換 Tantivy 隨時可以。

**加密用信封而非直接以密語加密內容。**
換密語時只需重新包裹 DEK，不必重新加密整本筆記。測試明確驗證了這點。

### 踩到的坑

**`CloudProvider::list` 的語意錯了。**
原本實作成「列單層目錄」，導致 `SyncEngine::pull` 永遠看不到其他裝置的目錄，
5 個測試同時失敗。正確語意是**依前綴遞迴列舉**（物件儲存語意）。已修正並補測試。

**加密 chunk 少了框架邊界 —— 這是真實缺陷。**
兩次 push 之間只 pull 一次時，讀取範圍會橫跨兩個獨立密文塊，解密必然失敗。
加上 `u32` 長度前綴解決，並讓讀取端只消耗**完整框架**，
寫到一半當機的尾巴留待下次補齊而非當成損毀丟棄。`format-spec.md` §7.1 已更新。

**`b"中文"` 不是合法的 byte string。** 要用 `"中文".as_bytes()`。

### 下一步
S-06/S-10/S-12（辨識註冊表、PDFium、UniFFI 綁定），
以及 S-13/S-15（Opus、ASR 引擎）—— 後者需引入原生相依。

---

## 2026-09-12 · M0 工程地基

### 做了什麼
- `docs/format-spec.md` v0.1 定稿
- Rust workspace 11 crates，55 測試通過、clippy 零警告
- CI：三平台 fmt/clippy/test + cargo-deny + 格式相容性
- S3 同步收斂驗證 **Go**；S4 授權稽核完成
- S1（Swift 墨跡 spike）與 S2（CER 評測工具）程式就緒，待硬體與資料

### 為什麼這樣做

**先做 format-spec 而非先寫 UI。**
統一時間軸是 C1/C4/A10/B6 四個功能的共同地基，事後更動等於重寫文件層。
在還沒有任何程式依賴它之前定稿，成本最低。

**S3 排在 S1 之前完成。**
風險登記簿上 S3 是唯一標「影響極高」的項目 —— 它決定整個「用雲端硬碟同步」
的架構是否成立。而且它純軟體、當場可驗證，不像 S1 要等硬體。先殲滅可驗證的最大風險。

**筆畫不進 CRDT（ADR-0002）。**
一筆畫數百個點，全進 CRDT 會讓 op 爆炸。改用 append-only + 墓碑 —— 新增與刪除
天生可交換冪等，這正是收斂所需的全部性質，不需要完整 CRDT 的機制。

**刻意先不引入外部相依。**
M0 全程零 crates.io 相依，確保任何環境都能 build。等真正需要（serde/sha2）
才引入，且每個都要過 `deny.toml` 白名單。

### 踩到的坑
- 自訂 `Display` 用 `f.write_str` 會忽略 `{:<12}` 寬度 → 必須用 `f.pad()`
- doc comment 裡放真實 Tab 會觸發 clippy 警告
- `cargo` workspace 成員缺 `src/lib.rs` 會讓整個 workspace 無法載入

### 下一步
依「先把功能全部建起來、之後再 debug」的方針，推進 storage / doc / search /
asr 編排 / export 等純邏輯層。需要實機的一律記進 `TODO.md`。
