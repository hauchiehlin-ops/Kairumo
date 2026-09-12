# 模型權重授權稽核

> 日期：2026-09-12　|　對應 `docs/TODO.md` H3、決策 D6
> **免責**：以下是工程稽核，不是法律意見。有商業風險的項目已標明，需由專案擁有者決定。

---

## 1. 結論摘要

| 模型 | 權重授權 | 可用於 Padnote？ |
|---|---|---|
| `silero-vad-v4` | MIT | ✅ **已採用**（S-26） |
| `whisper-large-v3-turbo` | MIT | ✅ 可用 |
| `ppocr-v5` | Apache-2.0 | ✅ 可用 |
| `qwen3-4b-instruct` | Apache-2.0 | ✅ 可用 |
| `paraformer-zh-streaming` | Apache-2.0（**repo 內含完整授權原文**） | ✅ **已自行匯出**（D-07 選 C） |
| `ct-punc`（中文標點） | Apache-2.0（**僅 model card 標籤**） | ⚠️ 證據較弱，且**體積不可行**（見 §6） |
| `sensevoice-small` | ❌ FunASR Model License v1.1 | ❌ **不採用** |
| speaker-diarization | 未確認 | ⏸️ 延後（P2） |

---

## 2. Paraformer-zh 與 ct-punc 的雙通路衝突 ★核心問題★

同一份權重，經由兩個通路散布，授權條款**不一致**：

### 通路 A：HuggingFace `funasr/*`（官方組織）

⚠️ **實際查驗後發現三個 repo 的證據強度不同**（`curl` HF API 逐一確認）：

| repo | metadata 標籤 | repo 內 LICENSE 檔 | 證據強度 |
|---|---|---|---|
| `funasr/paraformer-zh-streaming` | apache-2.0 | ✅ **有**（11,358 bytes 的 Apache-2.0 全文） | **最強** |
| `funasr/paraformer-zh` | apache-2.0 | ❌ 無 | 較弱 |
| `funasr/ct-punc` | apache-2.0 | ❌ 無 | 較弱 |

**只有 streaming 版內含完整授權原文。** 幸運的是 streaming 正是功能 C2
（邊錄邊出字）需要的形態 —— 授權證據與功能需求剛好一致。
- README 明文：「This repository publishes the model weights and accompanying
  files under the Apache License 2.0, unless an individual file carries a
  different notice.」

### 通路 B：FunASR GitHub 的 `MODEL_LICENSE`
「FunASR Model Open Source License Agreement, Version 1.1」，關鍵條款：
- 授予使用、複製、修改、分享的權利，但限定 **"for reference and learning
  purposes only"（僅供參考與學習使用）**
- 必須標註來源與作者，保留模型名稱
- 含「不得無理詆毀、惡意抹黑」條款，違反者**授權自動終止**

### 判讀
- 著作權人在自己的 HF repo 放上完整 Apache-2.0 授權檔，是明確的授權讓與。
  同一權利人本來就可以對不同通路採不同授權（雙重授權是常見做法）。
- 但通路 B 的「僅供參考與學習」若被主張適用，商業／產品使用就有疑義。
- 「不得詆毀 + 自動終止」**不是 OSI 認可的開源授權**，與專案宣稱的
  「全開源」定位不一致（見 `features.md` §4 賣點 3、4）。

### ⚠️ 另一層：ONNX 從哪來
官方 `funasr/*` repo **只有 PyTorch 權重（`model.pt`），沒有 ONNX**。
目前 manifest 指向的是 `csukuangfj/sherpa-onnx-*` 的第三方轉換版，
該 repo 自行宣告 `apache-2.0`。Apache-2.0 允許衍生作品，但 provenance
多了一層：轉換者的宣告不能高於上游授予的權利。

**若要 provenance 完全乾淨**：從 `funasr/*` 取 `model.pt`，用 FunASR 的匯出
腳本自行產生 ONNX，並保留匯出紀錄。成本是多一條建置流程。

---

## 3. SenseVoice-Small —— 不採用

- 權重走 **FunASR Model License v1.1**，非 Apache-2.0
- 社群開的商用釐清 issue（[FunAudioLLM/SenseVoice#279](https://github.com/FunAudioLLM/SenseVoice/issues/279)，
  2026-01-16）詢問「付費 App 可否使用」，**至今無維護者回覆**
- 「不得詆毀 + 自動終止」條款不符合專案的開源定位

**替代方案**：C9（中英夾雜）改用 `whisper-large-v3-turbo`（MIT）。
Whisper 原生支援 code-switching，品質待 H2 測試集實測，但授權完全乾淨。

---

## 4. 已確認可用的項目

| 模型 | 授權 | 驗證方式 |
|---|---|---|
| `silero-vad-v4` | MIT | 實際下載，雜湊 `a35ebf52…` 已記入 manifest |
| `whisper-large-v3-turbo` | MIT | whisper.cpp 與 Whisper 權重皆為 MIT |
| `ppocr-v5` | Apache-2.0 | PaddleOCR 專案授權 |
| `qwen3-4b-instruct` | Apache-2.0 | Qwen3 系列採 Apache-2.0 |

---

## 6. ⚠️ ct-punc 的體積問題（新發現）

自行匯出後的實測大小：

| 模型 | FP32 | int8 量化 |
|---|---|---|
| `paraformer-zh-streaming` (encoder) | 606.9 MB | **158.6 MB** |
| `paraformer-zh-streaming` (decoder) | 217.9 MB | **68.5 MB** |
| `ct-punc` | 1,073.6 MB | **965.0 MB** ⚠️ |

Paraformer 量化後合計約 **227 MB**，完全可行。

但 **ct-punc 量化幾乎沒有效果**（1,074 → 965 MB）。原因是它的體積由
**詞嵌入表**主導（vocab 272,727），而動態 int8 量化只處理 MatMul 權重，
不碰 embedding。

**965 MB 的標點模型在行動裝置上不可行。** C5 是 P0 功能，因此這是新的阻擋項：

- 可能有較小的變體（sherpa-onnx 的轉換版約 280 MB，值得查是不是不同 checkpoint）
- 或需要詞表裁剪 / 知識蒸餾
- 或改用規則式 + 輕量模型的混合方案

→ 記為 `docs/TODO.md` **S-29**。

---

## 5. 待決策：D-07

> **是否採用 Paraformer-zh 與 ct-punc？**

| 選項 | 優 | 劣 |
|---|---|---|
| **A. 不採用** | 授權零風險，全線 MIT/Apache | 中文 ASR 只能靠 Whisper；**失去中文標點還原（C5，P0 功能）** |
| **B. 採用，用第三方 ONNX** | 成本最低，立刻可整合 | provenance 多一層；通路 B 的疑義未解 |
| **C. 採用，自行從官方權重匯出 ONNX** | provenance 乾淨，直接受 HF 的 Apache-2.0 LICENSE 涵蓋 | 多一條匯出流程；需 Python + FunASR 環境 |
| **D. 先寄信詢問 FunASR 團隊** | 得到明確答覆最保險 | 等待時間不可控（SenseVoice 的 issue 等了數月無回應） |

**工程上的建議：C**。官方 repo 的 Apache-2.0 LICENSE 檔是最強的授權依據，
自行匯出讓整條鏈都落在那份授權底下。但這是**帶法律性質的判斷，應由專案擁有者決定**。

### ✅ 已決議（2026-09-12）：選擇 C

見 `docs/adr/0006-self-export-funasr-onnx.md`。匯出流程為
`scripts/export-funasr-onnx.py`，產出的 `PROVENANCE.json` 記錄：
來源 repo 與**實際 commit sha**、授權證據及其雜湊、匯出工具版本、產出檔雜湊。
Rust 端有 `padnote-models::Provenance` 驗證這些紀錄的完整性（測試釘住）。

### ⚠️ C5 是 P0 功能
中文標點還原（`features.md` C5）被列為 **P0 —— 中文轉錄沒有標點等於沒用**。
若選 A，需要另找開源的中文標點模型，或接受無標點的轉錄品質。
這個影響必須在決策時一併考慮。
