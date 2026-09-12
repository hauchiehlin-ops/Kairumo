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
- **待確認**：Paraformer-zh、SenseVoice-Small、CT-Transformer punc、speaker-diarization
- **高風險**：語者分離模型（pyannote 系條款嚴格）
- **記錄於**：`models/MODELS.md`

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

進度見 `DEVLOG.md`。依 `roadmap.md` 的工作包編號。

| ID | 工作包 | 內容 |
|---|---|---|
| S-01 | WP4 | `padnote-storage`：manifest、`.padnote` 套件讀寫、內容定址 blob |
| S-02 | WP1 | `padnote-doc`：頁面樹、區塊模型、文字區塊 |
| S-03 | WP2 | `padnote-ink`：幾何（擬合、命中測試、dirty rect、簡化） |
| S-04 | WP11 | `padnote-search`：CJK 索引與增量更新 |
| S-05 | WP5 | `padnote-asr`：管線編排（環形緩衝、VAD 介面、工作佇列、優先權） |
| S-06 | WP12 | `padnote-recognize`：引擎註冊表與 fallback 鏈 |
| S-07 | WP21 | `padnote-crypto`：信封加密、BIP39 復原碼 |
| S-08 | WP10 | `padnote-sync`：SyncEngine 編排、非 append provider 的分塊策略 |
| S-09 | H1/H2 | `padnote-export`：Markdown 匯出（可完整實作）、PDF 匯出介面 |
| S-10 | WP7 | `padnote-pdf`：PDFium 介面層 |
| S-11 | — | `padnote-core`：UniFFI 門面 API（App 層操作全集） |

---

## ⚪ 待決策（需要人拍板）

| ID | 問題 | 背景 |
|---|---|---|
| D-01 | 附件（PDF）是否納入內容定址 blob | 傾向是，可跨筆記本去重 |
| D-02 | 墓碑 GC 策略 | 保留期 vs 快照後清除；影響檔案成長速度 |
| D-03 | 大型筆記本的 strokes 檔分片閾值 | |
| D-04 | 自訂筆（`tool_id` 100+）的參數序列化格式 | |
| D-05 | 長期維護與營收模式 | 全免費無後端 ⇒ 無營收；捐贈？桌面版買斷？ |
| D-06 | 多裝置金鑰首次配對的 UX | QR code 傳遞 DEK 的具體流程 |
