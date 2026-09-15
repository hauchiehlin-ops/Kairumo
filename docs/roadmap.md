# Padnote 階段性執行計畫 v1.0

> 日期：2026-09-12　|　依據：`architecture.md`（D1–D6 已拍板）、`features.md`
> **人力假設**：2 名全職工程師（1 位偏 Rust/系統、1 位偏 Apple/UI）。工時以 **人週（PW）** 表示；日曆時程按 2 人並行推算。單人開發請將日曆時程約 ×1.8。

---

## 0. 總覽

```
M0 技術驗證 ──▶ M1 可用核心 ──▶ M2 公開 Beta ──▶ M3 v1.0 ──▶ M4 跨平台
   5 週          16 週           13 週           12 週        14 週
   ▲                ▲               ▲               ▲
 Go/No-Go        內部日用        外部 Beta        上架
```
**到 1.0 約 46 週（≈11 個月）**；跨平台完成約 60 週。

**關鍵路徑**（延誤直接推遲整體）：
```
墨跡延遲驗證 → 統一時間軸資料模型 → 串流 ASR 管線 → oplog 同步引擎 → Beta
```
> 統一時間軸（`notebook_time_us`）在 M0 就必須定稿。它是 C1/C4/A10/B6 的共同地基，**事後更動等於重寫文件層**。

---

## M0｜技術驗證（5 週・約 9 PW）★風險殲滅階段★

目的：把三個「可能做不到」的假設在投入產品開發前證偽或證實。**任一 spike 失敗就改方案，不進 M1。**

| # | Spike | 工作內容 | PW | **Go 門檻（量化）** |
|---|---|---|---|---|
| S1 | **墨跡延遲** | Swift + CAMetalLayer(`presentsWithTransaction`)＋`predictedTouches`＋雙層渲染最小原型 | 3 | 高速攝影實測 **motion-to-photon ≤ 9ms**；連續書寫 10 分鐘無掉幀 |
| S2 | **中文 ASR 品質** | sherpa-onnx 跑 Paraformer-zh / SenseVoice / Whisper-turbo，自建 **≥3 小時**台灣場景音檔（教室/會議/中英夾雜/遠場） | 3 | 安靜場景 **CER ≤ 8%**、嘈雜場景 **≤ 18%**；串流首字 **≤ 2s** |
| S3 | **無伺服器同步** | Rust oplog + Automerge/Yrs，3 台裝置經 iCloud Drive 與本機資料夾互寫 | 2 | 500 次隨機併發編輯後 **三台狀態完全一致、0 個 conflicted copy、0 資料遺失** |
| S4 | 授權與選型稽核 | `cargo deny` 設定；逐一確認 PDFium/sherpa 模型/diarization 權重授權 → `MODELS.md` | 1 | 清單完成，無 AGPL 依賴 |

### M0 目前進度（2026-09-12）

| Spike | 狀態 | 結果 |
|---|---|---|
| **S1 墨跡延遲** | 🟡 **待實機量測** | Swift 實作完成並通過 iOS SDK 語法檢查（`apple/InkSpike/`）。量測協定見 `apple/README.md`。**需要實體 iPad + 240fps 攝影機**，模擬器數字無意義 |
| **S2 中文 ASR** | 🟡 **待錄製測試集** | CER 評測工具完成（`cargo run -p padnote-bench --bin asr-score`），分場景門檻已設定。**需要 ≥3 小時真實台灣場景音檔** |
| **S3 無伺服器同步** | ✅ **Go** | 三裝置 500 次隨機併發編輯：306 新增 / 92 刪除 / 214 可見、39 個 oplog 檔、**conflicted copy 0 個、三台狀態完全一致、零資料遺失**。含「Remove 先於 Add 抵達」與「離線裝置追平」迴歸測試 |
| **S4 授權稽核** | ✅ **完成** | `deny.toml` 白名單制並封鎖 MuPDF (AGPL)；`models/MODELS.md` 建立，6 項模型權重授權標記待確認 |

**已完成的工程地基**
- `docs/format-spec.md` v0.1 —— `.padnote` 公開格式定稿（統一時間軸、筆畫二進位、oplog 命名、同步收斂保證）
- Rust workspace 11 crates，**55 個測試通過、clippy 零警告**
- CI：三平台 fmt/clippy/test + cargo-deny + 格式相容性測試
- ADR 0001–0003

> ⚠️ **S1 與 S2 卡在硬體與資料，不是程式。** 這兩項是 M0 Go/No-Go 的其餘部分，
> 必須在進入 M1 前完成 —— 尤其 S1，它決定「自建墨跡引擎」的跨平台方案是否成立。

**M0 產出**
- `docs/format-spec.md` v0.1（**統一時間軸與 `.padnote` 格式定稿**）
- `docs/MODELS.md`（模型來源＋授權＋SHA-256）
- `padnote-bench` 測試集 v1 與 CI 基準
- 三份 spike 報告與 Go/No-Go 決議

**No-Go 的備案**
- S1 失敗 → 改用 PencilKit（犧牲跨平台墨跡共用，Rust core 仍保留）
- S2 失敗 → 改以 Whisper-turbo 為主 + 使用者自備 API key（BYOK）為選配
- S3 失敗 → 退為「單一裝置主控＋其他裝置唯讀」，或引入 Syncthing 作為外掛同步層

---

## M1｜可用核心（16 週・約 30 PW）—— 目標：**團隊自己每天用它上課/開會**

實作 `features.md` 全部 **P0**。

| 工作包 | 內容 | PW |
|---|---|---|
| WP1 `padnote-doc` | CRDT 文件模型、頁面樹、**統一時間軸**、版本 schema | 4 |
| WP2 `padnote-ink` | 筆畫資料結構、Catmull-Rom 擬合、寬度調變、序列化（A1–A4） | 4 |
| WP3 Apple InkView | Metal 渲染、預測筆跡、雙層合成、工具列 | 5 |
| WP4 `padnote-storage` | `.padnote` 讀寫、SQLite 元資料、內容定址 blob | 3 |
| WP5 `padnote-asr` | Opus 錄製、Silero VAD、Paraformer 串流、標點、OpenCC（C2–C6） | 5 |
| WP6 時間軸 UI | 錄音條、筆跡↔音訊雙向跳轉、詞級時間戳（C1/C4） | 3 |
| WP7 PDF | PDFium 整合、tile 快取、標註疊層（E1、J2） | 3 |
| WP8 打字塊 | 手寫/文字同檔共存、基礎編輯（B1） | 2 |
| WP9 匯出 PDF | H1 | 1 |

**M1 退出標準（全部要達成）**
- [ ] 以 Padnote 完整記錄一堂 90 分鐘中文課：手寫＋打字＋錄音＋即時轉錄，全程不卡不閃退
- [ ] 點任一筆畫可跳回當時錄音；點轉錄文字可跳播
- [ ] 500 頁 PDF 開啟 ≤1.5s、捲動 60fps（J2）
- [ ] **殺掉 App / 斷電後，筆跡與音訊零遺失**，轉錄任務自動續跑
- [ ] 墨跡延遲 CI 基準未回退
- [ ] 冷啟動 ≤800ms、100 頁記憶體 ≤400MB

---

## M2｜公開 Beta（13 週・約 24 PW）—— 目標：**外部使用者敢拿來用**

實作 **P1**。

| 工作包 | 內容 | PW |
|---|---|---|
| WP10 `padnote-sync` | oplog 引擎、`CloudProvider` trait、**Google Drive appDataFolder provider**（G2/G5/G9） | 5 |
| WP11 `padnote-search` | Tantivy＋jieba 索引，涵蓋打字/轉錄/PDF 文字（F3） | 3 |
| WP12 `padnote-recognize` | `HwrEngine` trait ＋ Apple Vision 實作；HWR 結果進索引（D1/D3） | 3 |
| WP13 **引擎與權限中心** | 統一狀態頁；模型按需下載＋SHA-256＋續傳（I1/I2） | 3 |
| WP14 組織與 UI | 資料夾、標籤、最愛、垃圾桶（F1/F2/F4） | 3 |
| WP15 富文本／Markdown | Yrs 富文本、MD 往返、匯出 MD（B2/B3/H2） | 3 |
| WP16 模板與媒體 | 紙張模板庫、圖片/掃描插入（E5/E4） | 2 |
| WP17 捲動/分頁雙模式・套選 | A7/A5 | 2 |
| WP18 無障礙・i18n | VoiceOver、動態字級、繁中/簡中/英（I8） | 2 |
| WP19 **`format-spec.md` 公開發佈** | 履行資料主權承諾（H4） | 1 |

**M2 退出標準**
- [ ] 50 位外部 Beta 使用者連續使用 4 週，**零資料遺失回報**
- [ ] 三台裝置經 Dropbox/Syncthing 同步 2 週，0 個 conflicted copy
- [ ] 中文手寫搜尋可用（HWR 命中率主觀可接受）
- [ ] 閃退率 < 0.3%（1.0 收斂到 0.1%）
- [ ] `.padnote` 規格公開，第三方可用腳本解析出筆畫與轉錄

---

## M3｜v1.0 上架（12 週・約 22 PW）

實作 **P2**。

| 工作包 | 內容 | PW |
|---|---|---|
| WP20 iCloud Drive provider | Ubiquity Container、NSFileCoordinator、未下載檔處理（G3） | 4 |
| WP21 E2EE ＋ 復原碼 ＋ 金鑰配對 | XChaCha20＋Argon2id、BIP39、QR 配對（G6–G8） | 4 |
| WP22 **Zoom-write** | Goodnotes 留存第一功能（A6） | 2 |
| WP23 本機 LLM | llama.cpp＋Qwen3-4B：摘要、待辦抽取（D5） | 3 |
| WP24 OCR ＋ 語者分離 | RapidOCR、sherpa diarization（D4/C8） | 3 |
| WP25 形狀辨識・筆跡重播・分割畫面 | A8/A10/E7 | 3 |
| WP26 上架準備 | App Store 審核（大型模型下載說明）、隱私標籤、官網、說明文件 | 3 |

**M3 退出標準**
- [ ] 通過 App Store 審核並上架
- [ ] 閃退率 < 0.1%、J1–J7 全部達標
- [ ] 隱私標籤為「不收集任何資料」

---

## M4｜跨平台（14 週・約 26 PW）

| 工作包 | 內容 | PW |
|---|---|---|
| WP27 `padnote-render` | wgpu 渲染管線（Apple 以外平台） | 5 |
| WP28 Android 外殼 | Compose MP、S Pen、`androidx.graphics.lowlatency` 前緩衝 | 6 |
| WP29 ML Kit HWR | Android 的 `HwrEngine` 實作（D1） | 2 |
| WP30 Desktop（Windows/Linux） | Compose MP Desktop | 5 |
| WP31 **Google Drive provider** | OAuth PKCE、`drive.appdata`、appDataFolder、分塊 append 模擬（G2） | 4 |
| WP32 匯入競品備份 | Goodnotes/Notability 遷移（H5） | 4 |

---

## 1. 風險登記簿（含觸發條件與行動）

| 風險 | 影響 | 機率 | 觸發訊號 | 行動 |
|---|---|---|---|---|
| 墨跡延遲達不到 9ms | 高 | 中 | M0/S1 實測 >12ms | 改用 PencilKit；跨平台墨跡另做 |
| 中文 ASR CER 不達標 | 高 | 中 | M0/S2 安靜場景 >10% | 換模型；加 BYOK 雲端選配；擴充自訓資料 |
| 同步仍產生衝突副本 | **極高** | 低 | M0/S3 出現 conflicted copy | 縮小為單主裝置模式；改用 Syncthing 外掛 |
| HWR 中文品質不佳 | 中 | 高 | Beta 使用者抱怨辨識 | HWR 已隔離為「可選增強」，三大核心不受影響 |
| 模型體積導致上架問題 | 中 | 中 | 審核被退 | 預設最小模型集；大模型純選配 |
| 模型權重授權不允許商用 | 中 | 中 | M0/S4 稽核發現 | 換模型；`MODELS.md` 每次升級重審 |
| 2 人力不足以維持進度 | 高 | 中 | 連續 2 個 sprint 燃盡偏離 >20% | 砍 P2 功能，保 P0/P1；1.0 延後 |
| 長期維護動力（全免費） | 中 | 高 | — | 開源社群化、GitHub Sponsors、桌面版買斷選配 |

---

## 2. 工程紀律（從第一天就設定）

| 項目 | 做法 |
|---|---|
| CI 閘門 | Rust 全平台編譯＋測試、`cargo deny` 授權稽核、**墨跡延遲基準不得回退**、**ASR CER 迴歸不得惡化** |
| 資料安全測試 | 每次 PR 跑「隨機殺行程 + 斷電模擬」，驗證零資料遺失（J7） |
| 決策紀錄 | `docs/adr/NNNN-*.md`，每個架構決策一份 |
| 格式版本 | `.padnote` schema 每次變更必附遷移程式與回歸測試 |
| 效能預算 | J1–J6 寫進 CI，違反擋 PR |
| 遙測 | 零上傳；僅本機日誌，使用者可主動匯出附在 issue |

---

## 3. 下一步（本週可以開工的三件事）

1. **建立 Rust workspace 骨架**（`crates/` 11 個 crate + CI + `cargo deny`）
2. **啟動 S1 墨跡延遲 spike**（關鍵路徑起點，最該先知道答案）
3. **開始錄製 `padnote-bench` 中文測試集**（需時間累積，越早開始越好；這是競品抄不走的資產）
