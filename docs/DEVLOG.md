# 開發日誌

> 反序排列（最新在上）。每個開發階段結束時追加一筆。
> 記錄**為什麼**這樣做，而不只是做了什麼 —— 「做了什麼」看 git log 就好。

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
