# Padnote 完整功能表列（含競品對照）

> 日期：2026-09-12　|　依據：`market-research.md`、`architecture.md`
> 優先序定義：**P0**＝不做就不成立 ／ **P1**＝Beta 必備 ／ **P2**＝1.0 必備 ／ **P3**＝1.0 之後
> 圖例：✅ 完整支援　🟡 部分/品質差　❌ 無　💰 需付費　🔒 平台鎖定

---

## 1. 十大關鍵維度總覽

| 維度 | Goodnotes 6 | Notability | OneNote | Apple Notes | Samsung Notes | Noteshelf 3 | Nebo | Notion | Obsidian | Granola | **Padnote** |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 手寫品質/低延遲 | ✅ 最佳 | ✅ | 🟡 | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ **≤9ms 目標** |
| 打字/富文本 | 🟡 | 🟡 | ✅ | 🟡 | 🟡 | 🟡 | ✅ | ✅ 最佳 | ✅ | ✅ | ✅ **與手寫同檔共存** |
| 錄音 + 筆跡時間軸 | ❌ | ✅ 最佳 | ❌ | ❌ | 🟡 | 🟡 | ❌ | ❌ | ❌ | 🟡 無手寫 | ✅ **P0 核心** |
| 即時串流轉錄 | ❌ | 🟡 慢/常失敗 | ❌ | 🟡 | 🟡 | ❌ | ❌ | 🟡 | ❌ | ✅ | ✅ **≤2s 部分結果** |
| 中文 AI 支援 | ❌ 不支援 | 🟡 | 🟡 | 🟡 | ✅ | 🟡 | 🟡 | 🟡 | ❌ | 🟡 | ✅ **一等公民** |
| PDF 標註 | ✅ 最佳 | ✅ | 🟡 | ❌ | 🟡 | ✅ | 🟡 | ❌ | 🟡 | ❌ | ✅ **500頁 ≤1.5s** |
| 跨平台對等 | 🟡 Android 弱 | ❌ 🔒Apple | ✅ | ❌ 🔒Apple | ❌ 🔒三星 | 💰 分開收費 | 🟡 | ✅ | ✅ | ❌ 🔒Mac | ✅ **架構保證** |
| 離線可用 | 🟡 | ✅ | 🟡 | ✅ | ✅ | ✅ | 🟡 | ❌ | ✅ | 🟡 | ✅ **100% 離線** |
| 資料主權/開放格式 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ 只能自家雲 | ❌ | ✅ 最佳 | ❌ | ✅ **規格公開+E2EE** |
| 價格模式 | 💰 訂閱 | 💰 訂閱 | 免費 | 免費 | 免費 | 💰 分平台 | 💰 訂閱 | 💰 | 免費 | 💰 | **完全免費** |

**結論**：沒有任何一列是全綠的。Padnote 的機會不在單點超越，而在於**同時滿足手寫＋錄音轉錄＋中文 AI＋資料主權＋免費**這五項 —— 目前無人做到。

---

## 2. 分類功能清單

### A. 手寫與墨跡

| # | 功能 | 標竿／來源 | 競品痛點 | Padnote 規格 | 優先 |
|---|---|---|---|---|---|
| A1 | 低延遲筆跡渲染 | Goodnotes | OneNote 手感差 | 預測筆跡＋前緩衝渲染，**≤9ms motion-to-photon** | **P0** |
| A2 | 壓感／傾斜／方位筆刷 | Goodnotes, Samsung | — | 原始取樣點全存（含 pressure/tilt/azimuth/µs 時間戳） | **P0** |
| A3 | 筆類：鋼筆/原子筆/螢光筆/鉛筆 | 全體 | — | 4 種基礎筆＋自訂粗細透明度 | **P0** |
| A4 | 橡皮擦（筆畫級 / 像素級） | Goodnotes | — | 兩種模式可切換 | **P0** |
| A5 | 套索選取（移動/縮放/複製/轉文字） | Goodnotes | — | 含跨頁搬移 | **P1** |
| A6 | **Zoom-write 放大書寫框** | Goodnotes ⭐留存第一功能 | 多數競品沒有 | 第二 viewport 綁同一 page buffer | **P2** |
| A7 | 無限捲動 ＋ 固定分頁雙模式 | Notability(捲動) / Goodnotes(分頁) | 兩家各只有一種 | **兩種都給**，逐筆記本切換 | **P1** |
| A8 | 形狀辨識／尺規／對齊 | Goodnotes, Samsung | — | 直線、矩形、圓、箭頭自動吸附 | **P2** |
| A9 | 無限畫布／白板 | OneNote, Goodnotes 6 | — | 與分頁模式並存 | **P3** |
| A10 | 筆跡重播（依時間軸動畫） | 少數有 | — | 時間軸資料模型天然支援，近乎免費 | **P2** |
| A11 | 雷射筆／簡報模式 | Goodnotes | — | 外接螢幕輸出 | **P3** |

### B. 文字與編輯

| # | 功能 | 標竿 | 競品痛點 | Padnote 規格 | 優先 |
|---|---|---|---|---|---|
| B1 | 手寫與打字**同文件共存** | Nebo, Goodnotes 6 | 多數 App 文字是貼上去的浮動框 | 統一文件模型，文字塊與筆畫同層排版 | **P0** |
| B2 | 富文本（標題/清單/待辦/表格/程式碼） | Notion, Obsidian | 手寫 App 文字能力普遍陽春 | Yrs CRDT 富文本 | **P1** |
| B3 | Markdown 輸入與往返 | Obsidian | 手寫 App 全無 | 輸入即轉換，匯出無損 | **P1** |
| B4 | 數學公式（LaTeX + 手寫辨識） | Nebo, Apple Math Notes | — | KaTeX 渲染；手寫公式辨識 P3 | **P2** |
| B5 | 雙向連結 `[[note]]` | Obsidian | 手寫 App 全無 | 建立筆記網絡 | **P2** |
| B6 | 版本歷史／時光機 | 少數有 | — | CRDT oplog 天然支援，可回溯任一時點 | **P2** |

### C. 錄音與轉錄 ★最大差異化★

| # | 功能 | 標竿 | 競品痛點 | Padnote 規格 | 優先 |
|---|---|---|---|---|---|
| C1 | 錄音與筆跡/文字**時間軸雙向跳轉** | Notability ⭐殺手功能 | Goodnotes 完全沒有錄音 | 統一 `notebook_time_us` 時間軸 | **P0** |
| C2 | **串流即時轉錄**（邊錄邊出字） | Granola | Notability 15分音檔要3分鐘、常報 Transcription Failed | Silero VAD＋Paraformer-zh，**≤2s 部分結果** | **P0** |
| C3 | 音檔優先落地、轉錄可無限重試 | — | Notability 轉錄失敗＝體驗崩壞 | Opus 先寫盤；轉錄為衍生物，狀態存 SQLite 可續傳 | **P0** |
| C4 | 詞級時間戳 | Granola | — | 點轉錄文字即跳播 | **P0** |
| C5 | 中文標點還原＋繁體轉換 | 幾乎無 | 中文轉錄無標點＝不可用 | CT-Transformer punc → OpenCC `s2twp` | **P0** |
| C6 | 背景錄音／App 切換不中斷 | Notability | — | iOS `UIBackgroundModes: audio`＋中斷回復 | **P0** |
| C7 | 匯入既有音訊/影片轉錄 | Notta 類 | 手寫 App 全無 | 拖入 m4a/mp3/mp4 即轉錄 | **P1** |
| C8 | 語者分離（誰說了什麼） | Granola, Otter | 手寫 App 全無 | sherpa-onnx diarization（⚠️模型授權待確認） | **P2** |
| C9 | 中英夾雜（code-switching） | AssemblyAI 類 | 中文 App 普遍差 | SenseVoice-Small 備援引擎 | **P1** |
| C10 | 錄音書籤／重點標記 | Notability | — | 錄音中一鍵打點 | **P1** |
| C11 | 速度調整／降噪播放 | — | — | 0.5–3×、靜音跳過 | **P2** |

### D. 辨識與 AI（全本機、全離線）

| # | 功能 | 標竿 | 競品痛點 | Padnote 規格 | 優先 |
|---|---|---|---|---|---|
| D1 | 手寫轉文字（中文） | Nebo 最佳 | **Goodnotes AI 不支援中文** | `HwrEngine` trait：Apple Vision → ML Kit → OCR fallback | **P1** |
| D2 | 即時轉寫並可當下修正 | Nebo | 事後修正心理成本高 | 轉寫候選即時顯示、一鍵採用 | **P2** |
| D3 | 手寫全庫搜尋 | Goodnotes, Noteshelf | — | HWR 結果進 Tantivy 索引 | **P1** |
| D4 | 掃描 PDF OCR（可搜尋） | 少數有 | — | RapidOCR / PP-OCRv5 (ONNX) | **P2** |
| D5 | AI 摘要／待辦抽取 | Granola, Notion AI | **競品 AI 幾乎不支援中文** | llama.cpp + Qwen3-4B 本機推論 | **P2** |
| D6 | 筆記問答（RAG） | Notion AI | 需付費且上雲 | 本機 embedding + sqlite-vec | **P3** |
| D7 | 自訓開源中文 HWR | — | 開源方案不存在 | 保留插槽（見架構書缺口#1） | **P3** |

### E. 文件與 PDF

| # | 功能 | 標竿 | 競品痛點 | Padnote 規格 | 優先 |
|---|---|---|---|---|---|
| E1 | PDF 匯入與標註 | Goodnotes, Flexcil | **Goodnotes 大檔卡頓閃退＝最高頻負評** | PDFium＋tile 快取，**500頁 ≤1.5s、捲動 60fps** | **P0** |
| E2 | PDF 文字層選取/highlight | Goodnotes | — | 原生文字層，非畫線模擬 | **P1** |
| E3 | 標註寫回標準 PDF | Flexcil | 多數只能匯出平面圖 | 標準 PDF annotation，他家軟體可讀 | **P1** |
| E4 | 圖片插入／裁切／相機掃描 | 全體 | — | 內容定址去重 | **P1** |
| E5 | 紙張模板庫 | Goodnotes ⭐情感黏著 | — | 橫線/點陣/Cornell/方格/五線譜/手帳 | **P1** |
| E6 | 自訂模板匯入 | Goodnotes | — | PDF/圖片當底 | **P2** |
| E7 | 分割畫面／雙文件並排 | Goodnotes, Flexcil | — | iPad 多視窗 | **P2** |

### F. 組織與搜尋

| # | 功能 | 標竿 | 競品痛點 | Padnote 規格 | 優先 |
|---|---|---|---|---|---|
| F1 | 資料夾／巢狀結構 | Goodnotes | **Apple Notes 組織能力弱** | 無限層級 | **P1** |
| F2 | 標籤／多重分類 | Obsidian | — | 跨資料夾標籤 | **P1** |
| F3 | 全文搜尋（打字+轉錄+PDF+OCR+HWR） | Goodnotes | — | Tantivy＋jieba 中文斷詞，毫秒級 | **P1** |
| F4 | 我的最愛／最近／釘選 | 全體 | — | — | **P1** |
| F5 | 語意搜尋 | Notion AI | 需付費上雲 | bge-small-zh + sqlite-vec，本機 | **P3** |

### G. 同步、儲存與安全 ★架構性差異化★

| # | 功能 | 標竿 | 競品痛點 | Padnote 規格 | 優先 |
|---|---|---|---|---|---|
| G1 | 本機優先儲存、100% 離線可用 | Obsidian, Samsung | Notion 離線差 | 所有操作先寫本機 <1ms | **P0** |
| G2 | **本機資料夾同步 provider** | — | — | 使用者放進 Dropbox/OneDrive/Syncthing/NAS 即自動支援 | **P1** |
| G3 | iCloud Drive 同步 | Apple Notes | — | Ubiquity Container＋NSFileCoordinator | **P2** |
| G4 | Google Drive 同步 | — | — | Drive v3＋OAuth PKCE＋`drive.file` scope | **P3** |
| G5 | **零衝突同步** | — | **同步丟資料是全行業痛點** | Append-only single-writer log＋CRDT ⇒ 衝突數學上不可能 | **P0** |
| G6 | 端對端加密 | — | **Nebo 只能存自家雲** | XChaCha20-Poly1305＋Argon2id，上雲前加密 | **P2** |
| G7 | 復原碼（BIP39 24 字） | — | — | 無後端＝無託管，建立時強制抄寫確認 | **P2** |
| G8 | 多裝置金鑰配對 | — | — | QR code 傳遞 DEK | **P2** |
| G9 | 版本回溯／誤刪救援 | — | — | oplog 保留期＋垃圾桶 | **P1** |

### H. 匯出與互通（解「資料被綁架」）

| # | 功能 | 標竿 | 競品痛點 | Padnote 規格 | 優先 |
|---|---|---|---|---|---|
| H1 | 匯出 PDF（含標註） | 全體 | — | — | **P0** |
| H2 | 匯出 Markdown | Obsidian | 手寫 App 全無 | 文字＋轉錄＋圖片附件 | **P1** |
| H3 | 匯出圖片 / 單頁 | 全體 | — | PNG/SVG | **P1** |
| H4 | **`.padnote` 格式規格公開** | — | 全行業皆黑箱 | 發佈 `format-spec.md`，任何人可自行解析 | **P1** |
| H5 | 匯入 Goodnotes/Notability 備份 | — | — | 降低遷移成本（.goodnotes/.note 解析） | **P3** |
| H6 | 分享單篇（唯讀檔案） | — | 無後端無法做連結分享 | 匯出加密檔或 PDF，由使用者自己的雲分享 | **P2** |

### I. 平台整合與「引擎與權限中心」

| # | 功能 | 說明 | 優先 |
|---|---|---|---|
| I1 | **引擎與權限中心**（統一設定頁） | 一頁列出所有引擎/權限狀態，需要動作時一鍵跳轉：<br>• 手寫辨識引擎（Apple Vision ✓／ML Kit／OCR fallback）<br>• ASR 模型（未下載／下載中／就緒，顯示大小與來源）<br>• 麥克風・語音辨識權限<br>• iCloud 容器狀態<br>• Google Drive 授權<br>• 本機同步資料夾路徑<br>⚠️ Apple Vision 與 ML Kit **免申請、免 key**，僅需權限授予 | **P1** |
| I2 | 模型按需下載管理 | HF/GitHub Releases、SHA-256 驗證、斷點續傳、可刪除釋放空間 | **P1** |
| I3 | Apple Pencil 雙擊/懸停 | 切換工具、懸停預覽 | **P1** |
| I4 | 鍵盤快捷鍵 / 外接鍵盤 | — | **P2** |
| I5 | Handoff / 多視窗 / 拖放 | iPad 系統整合 | **P2** |
| I6 | 快速備忘（鎖定畫面／小工具） | — | **P3** |
| I7 | Shortcuts / URL Scheme | 自動化 | **P3** |
| I8 | 無障礙（VoiceOver、動態字級） | 上架合規 | **P1** |

### J. 非功能需求（穩定性當功能賣）

| # | 指標 | 目標 | 對應競品痛點 |
|---|---|---|---|
| J1 | 墨跡 motion-to-photon | ≤ 9ms | 手感是第一印象 |
| J2 | 500 頁 PDF 開啟 / 捲動 | ≤1.5s / 60fps | **Goodnotes 卡頓閃退最高頻負評** |
| J3 | 串流轉錄延遲 | ≤ 2s | Notability 慢 |
| J4 | 冷啟動 | ≤ 800ms | |
| J5 | 記憶體（100 頁） | ≤ 400MB | iPad 背景被殺臨界 |
| J6 | 閃退率 | < 0.1% session | |
| J7 | 資料遺失事件 | **0 容忍** | 同步丟資料是行業原罪 |
| J8 | 遙測 | **零上傳**，僅本機日誌可主動匯出 | 隱私即賣點 |

---

## 3. 明確不做（Non-goals，寫進產品定位）

| 不做的事 | 原因 |
|---|---|
| 即時多人協作（共享游標） | 無後端結構上不可能，需 relay server |
| Web 版 | 無法存取本機檔案系統與本機模型 |
| 帳號系統／雲端登入 | 無後端；改以「無帳號」為隱私賣點 |
| 忘記密語的救援 | 無金鑰託管；以 BIP39 復原碼替代 |
| 使用行為遙測／A-B 測試 | 隱私優先 |
| 模板市集／內購 | 維持完全免費、無 IAP |

---

## 4. 五個對外賣點（行銷語言）

1. **唯一的三合一**：手寫、打字、錄音轉文字在同一份文件、同一條時間軸上。
2. **中文是一等公民**：AI 辨識、標點、摘要全支援繁中 —— Goodnotes 的 AI 至今不支援中文。
3. **你的筆記在你自己的硬碟上**：無帳號、無伺服器、端對端加密，格式規格公開。
4. **永遠免費，且不可能反悔**：開源＋無後端，結構上沒有收回功能的可能。
5. **不卡、不閃退、不丟資料**：效能預算寫進 CI，違反就擋 PR。
