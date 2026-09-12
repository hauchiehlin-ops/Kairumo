# 模型清單與授權稽核

> 決策 D4：模型按需下載，託管於 Hugging Face / GitHub Releases，SHA-256 驗證 + 斷點續傳。
> 決策 D6：**程式碼授權與模型權重授權不同，必須分別確認**。每次升級模型須重審本表。

> 📋 **完整稽核與判讀見 [`LICENSE-AUDIT.md`](LICENSE-AUDIT.md)。**
> 其中 Paraformer-zh / ct-punc 的雙通路授權衝突是目前唯一的阻擋項（D-07），
> 且**影響 P0 功能 C5 中文標點還原**。

## 稽核狀態圖例
- ✅ 已確認可商用/可自由散布
- ⚠️ **待確認** —— M0/S4 工作項
- ❌ 不可用

## 語音辨識（ASR）

| 模型 | 用途 | 大小(約) | 程式碼授權 | **權重授權** | 狀態 |
|---|---|---|---|---|---|
| `whisper-large-v3-turbo` (q5_0, ggml) | 多語備援 | 800 MB | whisper.cpp MIT | MIT | ✅ |
| `Paraformer-zh` | 中文主力、串流 | 220 MB | sherpa-onnx Apache-2.0 | ⚠️ **雙通路衝突** | ⚠️ **待決策 D-07** |
| ~~`SenseVoice-Small`~~ | ~~中英夾雜 (C9)~~ | — | — | ❌ FunASR Model License v1.1 | ❌ **已排除**，C9 改用 whisper-turbo |
| `Silero VAD v4` | 語音端點偵測 | 1.8 MB | MIT | **MIT（已驗證）** | ✅ **已採用** |
| `CT-Transformer punc` | 中文標點還原 | 280 MB | Apache-2.0 | ⚠️ **雙通路衝突** | ⚠️ **待決策 D-07** |
| speaker-diarization (C8) | 語者分離 | 90 MB | sherpa-onnx Apache-2.0 | ⚠️ **高風險**，pyannote 系模型條款嚴格 | ⚠️ |

## OCR 與手寫辨識

| 模型 | 用途 | 大小 | 程式碼授權 | 權重授權 | 狀態 |
|---|---|---|---|---|---|
| `PP-OCRv5` (ONNX) | 掃描 PDF OCR (D4)、HWR fallback | 16 MB | Apache-2.0 | Apache-2.0 | ✅ |
| Apple Vision | HWR 主力 (Apple 平台) | 0（系統內建） | 專有 | — | ✅ 決策 D2 明示例外；**免申請、免 key** |
| ML Kit Digital Ink | HWR 主力 (Android) | 按語言下載 | 專有 | — | ✅ 同上 |

## 本機 LLM

| 模型 | 用途 | 大小 | 程式碼授權 | 權重授權 | 狀態 |
|---|---|---|---|---|---|
| `Qwen3-4B-Instruct` (Q4_K_M) | 摘要、待辦抽取 (D5) | 2.5 GB | llama.cpp MIT | Apache-2.0 | ✅ |
| `bge-small-zh` | 語意搜尋 (F5, P3) | 95 MB | MIT | MIT | ✅ |

## 非模型的原生依賴

| 元件 | 授權 | 備註 |
|---|---|---|
| PDFium | BSD-3 | ✅ **PDF 引擎唯一選項** |
| ~~MuPDF~~ | ❌ AGPL-3.0 | **禁用**，已寫入 `deny.toml` |
| libopus | BSD-3 | ✅ |
| SQLite | Public Domain | ✅ |

## 下載清單格式

每個模型在 `models/manifest.json` 中須登記：
```json
{
  "id": "paraformer-zh-v1",
  "url": "https://huggingface.co/.../model.onnx",
  "sha256": "...",
  "size_bytes": 230686720,
  "license": "...",
  "required_for": ["asr.zh"]
}
```
下載器必須：驗證 SHA-256、支援斷點續傳、允許使用者刪除以釋放空間（I2）。
