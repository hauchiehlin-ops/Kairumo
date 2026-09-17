# Padnote 技術架構設計書 v1.0

> 日期：2026-09-12
> 約束：**全開源技術** ／ **零後端伺服器** ／ **本地優先儲存** ／ **同步走使用者自己的雲端**（iCloud Drive / Google Drive）／ **免費**
> 設計依據：`docs/market-research.md` 的競品優缺點分析

---

## 0. 已拍板決策（2026-09-12）

| # | 決策 | 結論 | 影響 |
|---|---|---|---|
| **D1** | 平台策略 | **Phase 1 iPadOS/macOS 優先**，核心以 Rust 撰寫為跨平台鋪路 | 採用「Rust Core + 原生外殼」架構 |
| **D2** | HWR 開源例外 | **接受** Apple Vision / ML Kit 等免費非開源系統 API；App 內提供「引擎與權限中心」統一引導設定 | HWR 以 `HwrEngine` trait 隔離，開源自訓方案降為 P3 選項 |
| **D3** | 雲端優先序 | 已由 **D11** 取代 | 原本是本機資料夾 → iCloud Drive → Google Drive；現改以 Google Drive appDataFolder 作正式自動同步 |
| **D11** | 帳號式跨平台同步 | **Google Drive appDataFolder** 作為正式自動同步主線；手動資料夾保留為備份/匯入匯出 | 使用者登入同一 Google 帳號後，筆記本、資料夾與可同步設定自動收斂 |
| **D4** | 模型分發 | 按需下載，託管於 Hugging Face / GitHub Releases + SHA-256 驗證 + 斷點續傳 | 需維護 `models/MODELS.md` 清單 |
| **D5** | 無後端限制 | 即時協作／Web 版／遙測／金鑰託管 **列為產品定位，非待辦** | 對外訴求「隱私優先、無帳號、無伺服器」 |
| **D6** | PDF 引擎 | **PDFium (BSD-3)**；明確禁用 MuPDF (AGPL) | `cargo deny` 進 CI，另建 `MODELS.md` 稽核模型權重授權 |

> ⚠️ **關於 D2 的更正**：Apple Vision 與 ML Kit Digital Ink 皆為**純裝置端、免費、免註冊**，不需要申請 API key。真正需要使用者授權的是：iCloud 容器、Google Drive OAuth、麥克風/語音權限、模型下載同意。因此設計為 App 內統一的**「引擎與權限中心」**（見 `docs/features.md` §I），列出每個引擎與權限的即時狀態，需要動作時一鍵跳轉系統設定或授權流程。

## 1. 架構總覽

```
┌──────────────────────────────────────────────────────────────────┐
│  Presentation Layer（各平台原生，唯一不共用的一層）                  │
│  ┌────────────────────────┐  ┌──────────────────────────────┐   │
│  │ Apple: SwiftUI + UIKit │  │ Android/Win/Linux:           │   │
│  │  InkView(CAMetalLayer) │  │  Compose MP + wgpu Surface   │   │
│  └────────────────────────┘  └──────────────────────────────┘   │
└──────────────┬───────────────────────────────────────────────────┘
               │  UniFFI / JNI / C-FFI（型別安全綁定，自動產生）
┌──────────────▼───────────────────────────────────────────────────┐
│  padnote-core（Rust，100% 共用）                                  │
│                                                                   │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌──────────────────┐ │
│  │ Document  │ │   Ink     │ │  Audio /  │ │   Recognition    │ │
│  │  Model    │ │  Engine   │ │    ASR    │ │  (HWR/OCR/LLM)   │ │
│  │ (CRDT)    │ │ (geometry)│ │ Pipeline  │ │   可插拔引擎      │ │
│  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └────────┬─────────┘ │
│        │             │             │                │            │
│  ┌─────▼─────────────▼─────────────▼────────────────▼─────────┐ │
│  │              Storage & Index Layer                          │ │
│  │  SQLite(元資料/索引) + Tantivy(全文) + 內容定址 Blob 儲存    │ │
│  └─────────────────────────┬───────────────────────────────────┘ │
│                            │                                      │
│  ┌─────────────────────────▼───────────────────────────────────┐ │
│  │  Sync Engine（無伺服器：CRDT op-log over dumb file sync）     │ │
│  │  + Crypto Layer（XChaCha20-Poly1305 信封加密）               │ │
│  └─────────────────────────┬───────────────────────────────────┘ │
└────────────────────────────┼─────────────────────────────────────┘
                             │  CloudProvider trait（可插拔）
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
  ┌───────────┐       ┌─────────────┐      ┌────────────┐
  │  iCloud   │       │Google Drive │      │ 本機資料夾  │
  │  Drive    │       │  (REST API) │      │(Dropbox 等) │
  │(Ubiquity) │       │             │      │  自動相容   │
  └───────────┘       └─────────────┘      └────────────┘
```

**核心設計原則**
1. **Local-first**：所有操作先寫本機，同步是背景的最終一致過程。斷網 = 零功能損失。
2. **No server truth**：雲端只是**啞檔案桶（dumb bucket）**，不做任何運算，不解析內容（因為是加密的）。
3. **Append-only**：同步檔案只新增不修改，從根本上避開 iCloud/Drive 的檔案衝突機制。
4. **Pluggable everything**：ASR、HWR、OCR、LLM、CloudProvider 全是 trait，可換不可鎖。

---

## 2. 技術選型（全部附授權，皆可商用/免費）

### 2.1 核心與 UI
| 用途 | 選型 | 授權 | 理由 |
|---|---|---|---|
| 核心語言 | **Rust** | - | 無 GC、記憶體安全、可編到所有平台 |
| FFI 綁定 | **UniFFI** (Mozilla) | MPL-2.0 | 自動產生 Swift/Kotlin/Python 綁定，免手寫橋接 |
| Apple UI | SwiftUI + UIKit | 系統 | 原生手感 |
| 其他平台 UI | **Compose Multiplatform** | Apache-2.0 | Android/Desktop 共用 |
| GPU 渲染 | **wgpu** | MIT/Apache-2.0 | 一套 shader 跑 Metal/Vulkan/DX12 |

### 2.2 資料與同步
| 用途 | 選型 | 授權 | 理由 |
|---|---|---|---|
| 富文本 CRDT | **Yrs (y-crdt)** | MIT | Yjs 的 Rust 實作，文字協同最成熟 |
| 結構 CRDT | **Automerge 3** | MIT | 文件樹/屬性的自動合併 |
| 本機 DB | **SQLite** (via `rusqlite`) | Public Domain | 元資料、索引、同步狀態 |
| 全文搜尋 | **Tantivy** | MIT | Rust 版 Lucene，本機毫秒級 |
| 中文斷詞 | **jieba-rs** / **Lindera** | MIT | CJK 檢索必備 |
| 加密 | **RustCrypto**(XChaCha20-Poly1305) + **Argon2id** | MIT/Apache-2.0 | 上雲前 E2EE |
| 壓縮 | **zstd** | BSD | op-log 與 blob 壓縮 |

### 2.3 語音
| 用途 | 選型 | 授權 | 備註 |
|---|---|---|---|
| 音訊編碼 | **libopus** | BSD-3 | 32kbps 語音即足夠，1 小時約 14MB |
| VAD 斷句 | **Silero VAD** | MIT | 決定串流切片邊界 |
| ASR（中文主力） | **sherpa-onnx** + **Paraformer-zh / SenseVoice-Small** | 程式碼 Apache-2.0 | 中文 CER 表現優於 Whisper，且原生串流 |
| ASR（多語/備援） | **whisper.cpp** + `large-v3-turbo` (q5_0) | MIT（含模型） | 比 large-v3 快 4×、WER 僅 +0.3% |
| 標點還原 | **CT-Transformer punc** (via sherpa-onnx) | Apache-2.0 | 中文轉錄沒標點等於沒用 |
| 簡→繁轉換 | **OpenCC** (`s2twp`) | Apache-2.0 | 模型多輸出簡體，必須轉台灣正體用語 |
| 語者分離 | **sherpa-onnx** speaker-diarization | Apache-2.0 | ⚠️ 模型授權需逐一確認 |

### 2.4 辨識與 AI
| 用途 | 選型 | 授權 | 備註 |
|---|---|---|---|
| PDF 渲染/標註 | **PDFium** (via `pdfium-render`) | BSD-3 | ❌ 不要用 MuPDF（AGPL 會污染閉源殼） |
| 印刷體 OCR | **RapidOCR / PP-OCRv5** (ONNX) | Apache-2.0 | 掃描 PDF 轉可搜尋 |
| 手寫辨識 HWR | **可插拔**：Apple Vision ／ ML Kit Digital Ink ／ 自訓模型 | ⚠️ 見 §13 #1 | **最大技術風險** |
| 本機 LLM | **llama.cpp** + **Qwen3-4B-Instruct** (Q4_K_M) | MIT / Apache-2.0 | 摘要、待辦抽取、問答，全離線 |
| 推論後端 | **ONNX Runtime** | MIT | 統一非 LLM 模型的執行環境 |

---

## 3. 資料模型與檔案格式

### 3.1 `.padnote` 筆記本格式（開放、可自行解析）
不用私有黑箱格式 —— 直接解決競品「資料被綁架」的痛點。

```
MyNotebook.padnote/            ← 目錄式套件（macOS 顯示為單一檔案）
├── manifest.json              ← 版本、UUID、加密參數、schema version
├── doc/
│   ├── snapshot.automerge     ← 定期壓縮的 CRDT 快照
│   └── ops/
│       ├── 0191f2a1-<devA>.oplog   ← 每台裝置一個 append-only 檔
│       └── 0191f2b7-<devB>.oplog   ← 永不互相覆寫 ⇒ 零檔案衝突
├── ink/
│   └── <pageId>/strokes.bin   ← 筆畫二進位（見 3.2）
├── media/
│   ├── audio/<sessionId>.opus
│   └── blobs/<sha256前2碼>/<sha256>   ← 內容定址，天然去重
└── index/                     ← 本機衍生資料，**不同步**
    ├── search.tantivy/
    └── cache.sqlite
```

### 3.2 筆畫資料結構（低延遲 + 可重播的關鍵）
```rust
#[repr(C)]
struct InkPoint {
    x: f32, y: f32,          // 頁面座標（非螢幕座標，縮放無損）
    pressure: f16,           // 0.0–1.0
    tilt: f16, azimuth: f16, // Apple Pencil / S Pen 傾斜方位
    t_us: u32,               // 相對筆畫起點的微秒 ⇒ 錄音對齊的基礎
}

struct Stroke {
    id: Uuid,
    tool: ToolId, color: Rgba8, width: f32,
    started_at_us: u64,      // 相對筆記本時間軸原點 ⇒ 與音訊時間戳同軸
    points: Vec<InkPoint>,   // 原始取樣，不做破壞性平滑
}
```
> **關鍵**：儲存**原始取樣點**，平滑/曲線擬合只在渲染期做。這樣未來換渲染演算法或訓練 HWR 模型時，歷史筆記能重新受益。競品多數存的是已擬合的貝茲曲線，資訊一去不回。

### 3.3 統一時間軸（Notability 殺手功能的底層）
所有內容（筆畫、打字、音訊）共用單一 `notebook_time_us` 單調遞增時間軸：
- 筆畫 → `started_at_us`
- 文字 → CRDT op 上附時間戳
- 音訊 → session 起點 + Opus frame 偏移

⇒ 點任一筆畫跳到當時錄音、或拖曳音訊時間軸讓筆跡「重播」，都只是一次區間查詢。**這是必須在 Day 1 就刻進資料模型的東西，事後補做等於重寫。**

---

## 4. 同步引擎（無伺服器的核心技巧）

### 4.1 問題
iCloud Drive / Google Drive 是**啞檔案同步**，沒有交易、沒有鎖。兩台裝置同時改同一個檔案 → 產生 `file (conflicted copy).ext`，使用者資料實質損毀。這是所有「用雲端硬碟同步」的 App 翻車的地方。

### 4.2 解法：Single-Writer Append-Only Log + CRDT
```
規則一：每台裝置只寫自己的檔案（檔名含 device_id），永不修改他人檔案
規則二：所有寫入都是 append，永不 in-place 修改
規則三：合併只在本機做，用 CRDT 保證結果收斂（與合併順序無關）
⇒ 檔案層級的衝突在數學上不可能發生
```

**同步流程**
```
本機編輯 → 寫入 local oplog（立即，<1ms）
         → 標記 dirty
背景任務 → 每 N 秒或閒置時：
           1. 讀取本機 oplog 增量 → zstd 壓縮 → XChaCha20 加密
           2. append 上傳到雲端自己的 log 檔
           3. 拉取其他 device_id 的 log 增量
           4. 解密 → 套用到本機 CRDT → 觸發 UI diff 更新
壓縮任務 → oplog 超過閾值時，由「最近活躍裝置」產生新 snapshot，
           寫成新檔名（snapshot-<seq>.automerge），舊檔延後 GC
```

### 4.3 CloudProvider 抽象
```rust
#[async_trait]
pub trait CloudProvider: Send + Sync {
    async fn list(&self, prefix: &str) -> Result<Vec<RemoteEntry>>;
    async fn get_range(&self, path: &str, range: Range<u64>) -> Result<Bytes>; // 增量拉取
    async fn append(&self, path: &str, data: Bytes) -> Result<()>;
    async fn put(&self, path: &str, data: Bytes) -> Result<()>;
    fn supports_native_append(&self) -> bool; // Drive 不支援 → 退化為分塊檔
}
```
| 實作 | 機制 | 注意事項 |
|---|---|---|
| **iCloud Drive** | Ubiquity Container + `NSFileCoordinator`/`NSFilePresenter` | 檔案可能未下載，需處理 `evict`/materialize 狀態 |
| **Google Drive appDataFolder** | Drive REST v3，`drive.appdata` scope，OAuth 2.0 **PKCE**（原生 App 免 client secret） | 正式自動同步主線；無 append API → 每次同步寫新的 chunk 檔 `log-<seq>.bin` |
| **本機資料夾** | 直接檔案 IO | 手動備份、匯入匯出與進階使用者備援 |

> D11 已拍板：Google Drive `appDataFolder` 是正式自動同步主線。
> 本機資料夾仍保留，但定位是手動備份/匯入匯出，不再是主要同步體驗。

### 4.4 加密（資料放進使用者雲端，E2EE 是責任不是加分）
```
使用者密語 ──Argon2id(m=64MB,t=3)──▶ KEK
                                     │
筆記本 DEK（隨機 256-bit）──加密──────┘  → 存於 manifest.json
每個 chunk：XChaCha20-Poly1305(DEK, nonce=random_24B)
金鑰本體：iOS/macOS Keychain、Android Keystore（硬體支援）
```
⚠️ 無後端 = **無金鑰託管 = 忘記密語資料永久遺失**。必須提供「復原碼」（BIP39 助記詞，24 字）並強制使用者在建立時抄寫確認。

---

## 5. 墨跡引擎（對標 Goodnotes 的護城河）

### 5.1 延遲預算（目標 ≤ 9ms motion-to-photon）
```
觸控事件到達        ~1ms
Rust 幾何處理       ~1ms   ← 曲線擬合、寬度調變
GPU 提交            ~2ms   ← wgpu，只重繪 dirty rect
合成與顯示          ~4ms
─────────────────────────
合計                ~8ms
```
**必要手段**
- **預測筆跡**：Apple `UITouch.predictedTouches`／Android `MotionEventPredictor`，補 1~2 幀視覺延遲
- **前緩衝渲染**：Apple `CAMetalLayer(presentsWithTransaction)`／Android `androidx.graphics.lowlatency` front-buffer，繞過三重緩衝
- **雙層渲染**：已完成筆畫 → 快取為 GPU texture tile；進行中筆畫 → 單獨薄圖層，每幀只重畫它
- **筆畫幾何**：Catmull-Rom 擬合 → 依速度與壓力調變寬度 → 產生 triangle strip；抗鋸齒用 SDF 而非 MSAA（省頻寬）

### 5.2 必做功能（來自市調的「使用者買單清單」）
- **Zoom-write 放大書寫框**（Goodnotes 留存第一功能）→ 架構上只是第二個 viewport 綁同一 page buffer，早做便宜
- 套索選取、筆畫級橡皮擦 vs 像素橡皮擦
- 無限捲動 ＋ 固定分頁，**兩種模式**（速記 vs 手帳兩種心智模型）
- 壓感/傾斜筆刷、雷射筆、尺規/形狀辨識

---

## 6. 語音管線（要贏 Notability 的地方）

### 6.1 串流架構（邊錄邊出字，而非事後批次 3 分鐘）
```
麥克風 ──▶ Ring Buffer ──┬──▶ Opus Encoder ──▶ .opus（原始音檔，永不丟）
   48kHz                  │
                          └──▶ 16kHz 重採樣 ──▶ Silero VAD
                                                    │ 偵測語音段
                                                    ▼
                                          ┌──────────────────┐
                                          │ ASR Worker Pool  │
                                          │ (獨立執行緒,     │
                                          │  低優先權，      │
                                          │  絕不阻塞墨跡)    │
                                          └────────┬─────────┘
                                                   ▼
                                    Paraformer-zh ── 部分結果（灰字即時顯示）
                                                   ▼
                                    CT-Transformer 標點 → OpenCC s2twp
                                                   ▼
                                    最終結果（黑字）＋ 詞級時間戳 → CRDT
```

### 6.2 不可妥協的工程原則
1. **音檔永遠先落地**。轉錄是衍生物，失敗可無限重試，**絕不因為轉錄失敗而丟音訊**（Notability 最大差評來源）。
2. **轉錄任務可中斷、可續傳**，狀態存 SQLite。關 App、當機、換裝置都能接著跑。
3. **ASR 執行緒優先權必須低於 UI/墨跡執行緒**。寧可轉錄慢，不可寫字卡。
4. **詞級時間戳**寫進 CRDT → 點轉錄文字即可跳播，與筆跡共用同一時間軸。
5. **背景錄音**：iOS 需 `UIBackgroundModes: audio` 並處理中斷（來電、其他 App 搶音訊）。

### 6.3 準確度驗收（不信廠商數字）
> 公開 WER 用的是乾淨音檔。真實教室/會議（噪音、口音、多人重疊）可能從 5% 惡化到 15–20%。

建立 `padnote-asr-bench`：自建 **≥10 小時真實中文場景測試集**（台灣口音教室、會議、中英夾雜、遠場），對 Paraformer / SenseVoice / Whisper-turbo 跑 CER，作為 CI 的迴歸門檻。**這個測試集是你最有價值的資產之一，也是競品抄不走的。**

---

## 7. 手寫辨識（HWR）—— 架構上隔離，因為這是最大不確定性

```rust
pub trait HwrEngine: Send + Sync {
    fn recognize(&self, strokes: &[Stroke], lang: Lang) -> Result<Vec<Candidate>>;
    fn supports_streaming(&self) -> bool;
    fn languages(&self) -> &[Lang];
}
```
| 實作 | 品質 | 開源 | 平台 | 定位 |
|---|---|---|---|---|
| `AppleVisionHwr` | 中文可用、良好 | ❌ 系統 API | Apple only | Phase 1 預設 |
| `MlKitInkHwr` | zh-Hant 支援佳、300+ 語言 | ❌ Google 專有 | iOS/Android | Phase 2 預設 |
| `OcrFallbackHwr` | 差~中（筆畫轉圖 → PP-OCRv5） | ✅ Apache-2.0 | 全平台 | 純開源底線方案 |
| `OnlineHwrModel` | 目標最佳 | ✅ 自訓 | 全平台 | **需自行研發，見 §13 #1** |

> 設計上把 HWR 當作**可選增強**而非核心依賴：即使辨識完全不可用，「手寫 + 打字 + 錄音轉文字」三大基本需求仍然成立。這是重要的風險隔離。

---

## 8. 搜尋與 AI（皆本機、皆離線）

**搜尋**：Tantivy 索引「打字文字 + 轉錄文字 + PDF 文字層 + OCR 結果 + HWR 結果」，jieba 斷詞。增量索引在背景執行緒。
**語意搜尋（P2）**：本機小型 embedding 模型（如 `bge-small-zh`）→ 向量存 SQLite + `sqlite-vec`（MIT）。
**AI 功能（P2）**：llama.cpp + Qwen3-4B，離線做會議摘要、待辦抽取、筆記問答。
> 直接打中市調發現的最大空缺：**競品的 AI 幾乎全部不支援中文**。本機模型讓中文與英文一視同仁，且零 API 成本、零隱私疑慮 —— 這正好是免費+無後端架構的天然優勢，把限制變成賣點。

---

## 9. 專案結構

```
padnote/
├── crates/
│   ├── padnote-core/        # 門面，UniFFI 介面定義
│   ├── padnote-doc/         # CRDT 文件模型、時間軸
│   ├── padnote-ink/         # 筆畫幾何、擬合、序列化
│   ├── padnote-render/      # wgpu 渲染管線（非 Apple 平台）
│   ├── padnote-storage/     # SQLite、blob store、.padnote 讀寫
│   ├── padnote-sync/        # oplog、CloudProvider 實作
│   ├── padnote-crypto/      # 信封加密、金鑰管理
│   ├── padnote-asr/         # VAD、串流 ASR、標點、OpenCC
│   ├── padnote-recognize/   # HwrEngine / OcrEngine traits + 實作
│   ├── padnote-search/      # Tantivy 索引
│   └── padnote-bench/       # ASR/HWR 準確度迴歸測試
├── apple/                   # Xcode：SwiftUI + Metal InkView
├── android/                 # Compose Multiplatform
├── models/                  # 模型清單與雜湊（檔案本體走 CDN）
└── docs/
    ├── market-research.md
    ├── architecture.md
    └── format-spec.md       # .padnote 格式公開規格
```

**CI**：GitHub Actions → Rust 全平台編譯測試、`cargo deny`（授權稽核）、ASR/HWR 準確度迴歸、墨跡延遲基準（不得回退）。

---

## 10. 效能預算（寫進 CI，違反就擋 PR）

| 指標 | 目標 | 理由 |
|---|---|---|
| 墨跡 motion-to-photon | ≤ 9ms | 低於此才有「筆黏在螢幕上」的感覺 |
| 500 頁 PDF 開啟 | ≤ 1.5s，捲動 60fps 不掉幀 | **直接打擊競品最高頻負評** |
| 串流轉錄延遲 | ≤ 2s（部分結果） | 「邊錄邊出字」的體感門檻 |
| App 冷啟動 | ≤ 800ms | |
| 記憶體（100 頁筆記本） | ≤ 400MB | iPad 背景被殺的臨界 |
| 閃退率 | < 0.1% session | 穩定性當功能賣 |

---

## 11. 里程碑

| 階段 | 內容 | 驗收 |
|---|---|---|
| **M0 技術驗證**（4–6 週） | 墨跡延遲 spike、Paraformer 中文 CER 實測、oplog 同步 PoC（3 台裝置 × iCloud） | 延遲 <9ms、CER <10%、同步無衝突 |
| **M1 P0**（12–16 週） | 手寫 + 打字 + 錄音串流轉錄 + 時間軸同步 + PDF 匯入標註 + 本機資料夾同步 | 可日常使用 |
| **M2 P1** | iCloud + Google Drive provider、全文搜尋、HWR、E2EE、匯出 PDF/Markdown | 公開 Beta |
| **M3 P2** | Zoom-write、模板庫、本機 LLM 摘要、Android 版 | 1.0 |

---

## 12. 對照市調：每個競品痛點如何被解掉

| 競品痛點 | Padnote 的架構性回應 |
|---|---|
| 買斷改訂閱、信任崩塌 | 免費 + 開源 + 無後端 ⇒ **結構上沒有收回功能的可能** |
| 大 PDF 卡頓閃退 | PDFium + tile 快取 + 效能預算進 CI |
| 同步不可靠、會丟資料 | Append-only + CRDT ⇒ 衝突數學上不可能 |
| AI 只服務英文 | Paraformer-zh + OpenCC + Qwen3 本機推論，中文一等公民 |
| 轉錄慢又失敗 | 串流邊錄邊轉、音檔優先落地、任務可續傳 |
| 資料被綁在自家雲 | 開放 `.padnote` 格式規格 + 三種 provider + 隨時匯出 |
| 跨平台不對等/分開收費 | Rust core 共用 ⇒ 對等是架構保證；免費 ⇒ 無收費問題 |
| 沒有三合一 | 統一時間軸資料模型，Day 1 就內建 |

---

## 13. 🔴 還缺什麼（缺口、風險與待決事項）

### 缺口 #1：中文手寫辨識沒有可用的開源方案 ★最高風險★
- 開源線上（筆畫序列）中文 HWR 模型**實質上不存在**；能用的訓練資料（CASIA-OLHWDB、SCUT-COUCH）**多為學術研究授權，商用受限**。
- **解法選項**：
  1. 接受平台系統 API（Apple Vision / ML Kit）作為開源原則的例外 ← 最務實
  2. 用開源字型 + 筆畫合成產生訓練資料，自訓 CRNN/Transformer 模型（6–12 個月、需 GPU 預算）
  3. 純開源底線：筆畫轉圖 → PP-OCRv5，品質明顯較差但可用
- **需要你決定**：是否接受 #1 的例外。

### 缺口 #2：Google Drive 的隱形成本
- D11 已接受：正式自動同步使用 `drive.appdata` scope 與 `appDataFolder`，
  使用者登入同一 Google 帳號後自動同步 Kairumo 自己的資料。
- 仍需要 Google Cloud 專案、OAuth client、同意畫面設定、token refresh 與撤銷權限處理。
- Drive **沒有 append API**，必須退化成分塊檔策略，檔案數量會膨脹（需設計 chunk 合併）。
- API 配額綁在你的專案，使用者暴增時可能觸頂。
- 使用者可見資料夾不再作為正式同步主線，保留為手動備份、匯入匯出與進階備援。

### 缺口 #3：模型分發仍需靜態託管
- Whisper-turbo q5 ~800MB、Paraformer ~220MB、Qwen3-4B Q4 ~2.5GB，不可能塞進 App Bundle（App Store 限制）。
- **解法**：首次啟動按需下載，走 Hugging Face / GitHub Releases（免費靜態託管）＋ SHA-256 驗證＋斷點續傳。仍需你維護模型清單。

### 缺口 #4：無後端 ⇒ 這些功能結構上做不到
- ~~**即時協作**（多人同時編輯游標）← 需要 relay server。~~ **這一條後來做出來了，而且沒有違反 D5**：
  中繼永遠是**使用者自己掌握的那一台** —— 預設是房主的裝置自己開一個
  （`LocalRelayServer` / `padnote-relay`），跨網域時由使用者自己指定
  `wss://` 位址（自架、通道服務，或 Tailscale 這類覆蓋網路）。
  我們沒有、也不會架一台公用中繼。設定方式見 [`relay-hosting.md`](relay-hosting.md)。
- **Web 版**（無法存取本機檔案系統與模型）
- **崩潰回報與遙測** ← 只能做本機日誌 + 使用者主動匯出
- **帳號、找回密語、跨裝置金鑰託管** ← 忘記復原碼＝資料永久遺失
- **建議**：把這些明確寫進產品定位（「隱私優先、無帳號」），而不是當成待辦。

### 缺口 #5：授權稽核必須制度化
- ❌ **MuPDF 是 AGPL**，會污染整個 App，務必用 PDFium。
- ⚠️ 語者分離、SenseVoice、部分 Paraformer 模型的**模型權重授權與程式碼授權不同**，需逐一確認商用條款。
- **做法**：`cargo deny` 進 CI；另建 `MODELS.md` 逐一記錄每個模型的來源與授權。

### 缺口 #6：產品層面尚未定義的東西
- ~~**商業可持續性**~~ ✅ **已決議（2026-09-13）：不營收 + 捐贈連結。**
  先算實際支出：每年約 US$99（只有 Apple 開發者帳號），其餘全部 US$0。
  這不是需要商業模式的專案，是需要一百美金的專案。付費選項（免費 + 一次性
  解鎖）隨時可加且同樣不需要後端，反過來卻會得罪已付錢的人，所以先不做。
  詳見 `plans/sustainability-evaluation.md` 與 `SUPPORT.md`。
- **iOS 背景錄音 + 背景 ASR 的省電與被系統終止的處理策略**
- **多裝置金鑰首次配對流程**（QR code 傳遞 DEK？）
- **`.padnote` 格式版本遷移策略**（schema v1→v2 如何不破壞舊筆記）
- **無障礙（VoiceOver）與 i18n**
- **App Store 審核**：免費 App 無 IAP 最單純，但「按需下載大型模型」需說明

### 已拍板／仍待拍板
1. **平台策略**：Phase 1 是 iPad/macOS 優先，還是 Day-1 跨平台？
2. **HWR 例外**：是否接受 Apple Vision / ML Kit 這類「免費但非開源」的系統 API？
3. ~~**雲端優先序**~~：D11 已接受，正式自動同步改走 Google Drive `appDataFolder`
