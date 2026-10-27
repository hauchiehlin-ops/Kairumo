# 逐字稿的「轉出文字語言」

> 2026-10-27。前提：不架後台、不付 API 費用、可完全離線；同時要兼顧穩定、降噪、即時、快速。

## 一、使用者看到的

設定（Apple：首頁的語音轉錄區塊；Android：首頁「語音轉錄」卡片）多了兩個選項：

| 選項 | 預設 | 說明 |
|---|---|---|
| 音訊語言 | 跟隨介面語言 | 送給辨識引擎的語言 |
| 轉出文字語言 | 與音訊相同 | 逐字稿最後呈現的語言 |

- **同語言**（含繁 ↔ 簡）：沿用原本的轉錄模組，只做簡繁字體轉換（核心 `localize_transcript_script`）。
- **不同語言**：辨識完的每一句交給裝置上的系統翻譯，再寫進逐字稿。

規則只寫在核心一處（`transcript_needs_translation`／`transcript_output_language`），兩個平台都問它。

## 二、引擎

| 平台 | 引擎 | 成本 | 離線 | 限制 |
|---|---|---|---|---|
| Apple | Translation 框架（`TranslationSession(installedSource:target:)`） | 免費 | ✅ | iOS／Mac Catalyst 26 以上；更早的系統不顯示「轉出文字語言」 |
| Android | ML Kit Translation | 免費 | ✅ 每語言約 30 MB | 中文只有一種（簡體），譯完再由核心轉字體 |

語言包都由使用者在設定裡主動下載（Android 只用 Wi-Fi），**不在錄音中途自動下載** ——
那會讓前幾分鐘的逐字稿卡住。

排除：Whisper 內建 `translate`（只能譯成英文，turbo 版品質差）、NLLB（權重不可商用）、
本機 LLM（2.5 GB、每句數秒，違反「即時、快速」）。

## 三、穩定性的取捨

- **翻譯失敗時保留原文**：語言包沒下載、系統不支援時，逐字稿照常寫入（原語言），
  單次轉錄會提示「翻譯失敗，已保留原文」。即時轉錄不會因此中斷。
- **逐字稿存的是轉出文字語言**，不另外存原文。原始錄音檔永遠保留，要原文時把「轉出文字語言」
  改回「與音訊相同」重新轉錄即可。若日後需要原文與譯文並列，要在逐字稿格式加譯文欄位
  （DocOp + format-spec + 同步相容性），屬於另一個工作項。
- 同一組語言重用同一個翻譯 session，避免每句重新載入語言模型。

## 四、辨識端的效能（翻譯的前提）

翻譯只處理已辨識完的句子，延遲瓶頸在辨識：

- Whisper 模型常駐（`padnote-asr-whisper` 的 `load_shared`）：即時轉錄不再每 5 秒重載 574 MB；
  刪除／匯入模型或系統記憶體不足時釋放（`whisper_release_model`）。
- Apple 版 whisper.cpp 走 Metal（`asr-whisper-metal`），並開啟 flash attention。
- 即時轉錄用 `live_transcribe_options()`：錄音管線已做過高通與慢速 AGC，不再每段重做。
- 降噪（RNNoise）是使用者開關，預設關（理由見 `padnote-denoise`）。

## 五、尚未驗證

- 真實裝置上的 Whisper 速度（本機沒有模型檔，未實測 Metal 前後的差距）；
- 真實教室錄音的翻譯品質與延遲；
- Android 實機上 ML Kit 模型下載與翻譯流程。
