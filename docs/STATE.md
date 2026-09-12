# 專案狀態與交接記憶

> **每次開發階段開始前先讀這份。** 目的是讓不同的開發階段／不同的人／不同的 AI
> 不必重新推導已經決定過的事。
> 最後更新：2026-09-12

---

## 這是什麼專案

Padnote —— 手寫、打字、錄音轉文字三合一的筆記 App。
**免費 · 全開源（一個明示例外）· 無後端伺服器 · 本地優先 · 同步走使用者自己的雲端。**

切入點來自市調結論：**沒有任何競品同時做到一流手寫 + 一流錄音轉錄 + 中文 AI + 資料主權 + 免費。**

## 不要重新討論的事（已拍板，見 architecture.md §0）

| 決策 | 結論 |
|---|---|
| D1 平台 | Phase 1 iPadOS/macOS 優先；核心 Rust，為跨平台鋪路 |
| D2 HWR | **接受** Apple Vision / ML Kit 等免費非開源系統 API 作為例外 |
| D3 雲端 | 本機資料夾 → iCloud Drive → Google Drive（依序） |
| D4 模型 | 按需下載，HF / GitHub Releases + SHA-256 + 續傳 |
| D5 無後端 | 即時協作／Web 版／遙測／金鑰託管 = **產品定位，非待辦** |
| D6 PDF | PDFium (BSD-3)。**MuPDF 是 AGPL，已在 deny.toml 封鎖** |

## 三條不可違反的架構不變式

1. **Append-only**：同步檔案只新增不修改；每裝置只寫自己 `device_id` 的檔案。
   ⇒ 檔案層級衝突在數學上不可能發生。破壞這條 = 使用者資料損毀。
2. **統一時間軸**：筆畫、文字、錄音、轉錄詞全部用 `notebook_time_us` 定位。
   ⇒ 改動它 = 所有既有筆記的時間資料失效。
3. **原始取樣點**：筆畫存原始點，平滑/擬合只在渲染期做。
   ⇒ 預測筆跡（predicted touches）**永不寫入持久化資料**。

## 常犯的錯（已經踩過或已預見）

- ❌ 把預測點寫進 `.padnote` —— 那是視覺補償，不是真實輸入
- ❌ `presentsWithTransaction = true` —— 直覺上正確，實際多一整幀延遲
- ❌ 只讀 `touches.first` —— 120Hz Pencil 每幀多個取樣，必須用 `coalescedTouches`
- ❌ 把筆畫放進 CRDT —— op 數量爆炸，見 ADR-0002
- ❌ 混合場景算 CER —— 安靜語句會把嘈雜場景的失敗平均掉
- ❌ 引入 MuPDF —— AGPL 污染
- ❌ 自訂 `Display` 用 `write_str` —— 會忽略 `{:<12}` 的寬度指定，要用 `f.pad()`
- ❌ `CloudProvider::list` 當成「列單層目錄」—— 正確語意是**依前綴遞迴**
- ❌ 加密 chunk 不加框架邊界 —— 跨兩次 push 的讀取範圍會解不開
- ❌ 能力狀態預設為 Ready —— 未回報者一律當 `Unsupported`，否則執行期才爆
- ❌ 模型清單填假雜湊佔位 —— 用 `"pending"` 讓下載器直接拒絕
- ❌ 併發測試忘記讓兩端先套用自己的操作 —— 會誤判成不收斂
- ❌ 平台層把預測筆跡送進 `add_stroke` —— 那是視覺補償，不是真實輸入
- ❌ UniFFI 建構子命名為 `open` —— Swift 關鍵字，**會被靜默略過**
- ❌ 以為 PDFium 可以多執行緒渲染 —— 它的 C API 不是執行緒安全的
- ❌ 先套用再落盤 —— 當機會造成「有效果但沒存到」
- ❌ 只跑測試不跑程式 —— `recorded_audio_us` 停止後歸零，只有真的跑一次才發現
- ❌ `#[cfg(test)] impl` 放在 `mod tests` 之後 —— clippy 會擋
- ❌ 相信 manifest 裡沒下載驗證過的 URL —— 可能拿到 29 bytes 的登入錯誤頁
- ❌ 以為純 Rust 的 tract 能跑 Silero —— 它處理不了模型裡的 `If` 節點
- ❌ 把整段式 encoder 當串流用 —— 匯出的 Paraformer encoder 沒有 cache 輸入
- ❌ 先轉繁體再標點 —— ct-punc 的詞表是簡體的，順序反了會大量 `<unk>`
- ❌ 相信自己寫的測試期望 —— CIF 那兩條是測試錯、實作對
- ❌ `cargo add zhconv` —— 預設綁 MediaWiki 的 **GPL-2.0** 轉換表，
  必須 `default-features = false, features = ["opencc"]`
- ❌ PDF 標註忘記翻轉 Y 軸 —— **在自己的 App 裡看起來正常**，
  因為匯出與匯入用了同一個錯誤轉換；只有在別的 App 打開才會發現
- ❌ 解析 docx 只讀第一個 run —— 粗體會把段落切成多個 run，句子會殘缺
- ❌ 逐詞做簡繁轉換 —— 詞組上下文會消失（「下周三」的「周」轉不成「週」）
- ❌ 以為 Paraformer 的串流是靠 encoder cache —— 官方匯出本來就沒有 cache 輸入，
  分塊狀態封在圖內，目前只能段級串流

## 文件地圖

| 讀什麼 | 何時 |
|---|---|
| `STATE.md`（本檔） | **每次開工第一件事** |
| `DEVLOG.md` | 想知道「上次做到哪、為什麼這樣做」 |
| `TODO.md` | 想知道「還有什麼沒做、什麼被卡住」 |
| `architecture.md` | 要改架構或選型 |
| `format-spec.md` | 要碰資料格式或同步 |
| `features.md` | 要確認某功能的優先序與競品對照 |
| `roadmap.md` | 要知道階段與 Go 門檻 |
| `adr/` | 想知道某個決策的理由 |

## ⚠️ 需求檢視（2026-09-12）

八項新需求的涵蓋度分析見 [`requirements-review.md`](requirements-review.md)。
**兩項完全未涵蓋**（UI/UX、工具列與物件對齊），**一項無法照原描述達成**
（與 10 款競品格式完全互通 —— 多數是專有未公開格式，且互通需要對方
也讀我們的格式）。最嚴重的單一缺口是**掌拒**，那是手寫 App 的生死線。

## ⚠️ 目前唯一的阻擋項

**D-07：Paraformer-zh / ct-punc 的授權決策。**
官方 HF repo 有完整 Apache-2.0 LICENSE 檔，但 FunASR GitHub 的 MODEL_LICENSE
v1.1 寫「僅供參考與學習」。**影響 P0 功能 C5 中文標點還原。**
四個選項與建議見 `models/LICENSE-AUDIT.md` §5 —— 需要專案擁有者拍板。

## 目前進度一句話

M0 工程地基完成（S3 同步收斂、S4 授權稽核已 Go）；核心邏輯層 11 個 crate、
**665 個測試通過、clippy 零警告**。S1（墨跡延遲）與 S2（中文 ASR）卡在硬體與
資料，**不卡在程式**。UI、PDFium、ASR 模型整合尚未開始 —— 見 `TODO.md`。

## 已可運作的能力（皆有測試覆蓋）

手寫落盤與擦除（墓碑）· 頁面/區塊文件模型 · 統一時間軸與**筆跡↔錄音跳轉**·
中文全文搜尋（打字/轉錄/手寫辨識）· 音訊環形緩衝與 VAD 分段 ·
端對端加密與 BIP39 復原碼 · 無伺服器同步（本機資料夾 provider）·
Markdown / SVG 匯出 · 手寫辨識 fallback 鏈 · 引擎與權限中心狀態機 ·
模型下載（驗證 + 續傳 + 可刪除）· PDF 座標轉換與 LRU 頁面快取 ·
**文字 CRDT 與端到端同步** · **Swift / Kotlin FFI 綁定** ·
**完整文件持久化與重播還原** · **Opus 錄音編碼（ffprobe 驗證）** ·
**完整錄音→分段→轉錄→筆記的編排流程** · **Silero 神經網路 VAD** ·
**中文 ASR（Paraformer，fp32 輸出與 FunASR 吻合）** · **中文標點還原** ·
**簡繁轉換（台灣正體）** · **完整中文管線：無標點簡體 → 有標點正體** ·
**掌拒與輸入仲裁** · **物件群組/變換/對齊/吸附** · **Markdown/JSON 匯入** ·
**Office 嵌入與編輯（docx/xlsx）** · **PDF 標註的座標轉換與往返** ·
**完整的 FFI 曝露（65 個 Swift/Kotlin API）**

## 已實作但**尚未驗證**（不要當成完成）

- whisper.cpp ASR：編譯與錯誤路徑已測，**轉錄品質未實測**（需模型 + 中文測試集）
- PDFium：介面與邊界檢查已測，**實際解析未驗證**（需 libpdfium 執行期庫）
- 墨跡 Swift 層：語法檢查通過，**延遲未量測**
- VAD：已換成 Silero（白噪音誤判 0/100，EnergyVad 為 100/100）
- ASR 串流粒度：**段級**（VAD 段，上限 5 秒），非幀級。幀級需重新匯出計算圖（S-32）
