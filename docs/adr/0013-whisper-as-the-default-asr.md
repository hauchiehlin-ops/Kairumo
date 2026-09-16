# ADR-0013：預設語音辨識改用 Whisper，ct-punc 退出預設路徑

> 狀態：**已採納**（2026-09-17）
> 取代：[ADR-0006](0006-self-export-funasr-onnx.md) 的**預設選擇**（匯出流程本身仍然有效）
> 相關：決策 D-07、`models/LICENSE-AUDIT.md`、功能 C5（中文標點還原，P0）

## 背景

ADR-0006 決議「自行從官方權重匯出 ONNX」（D-07 選 C），把 Paraformer-zh 與
ct-punc 納入**預設**的中文轉錄路徑。匯出流程做完了，`PROVENANCE.json` 也
把來源 commit、授權證據與雜湊都釘住了。

但 D-07 真正的問題沒有因此消失：**同一份權重經由兩條通路散布，條款互相衝突。**

| | HuggingFace `funasr/*` | FunASR GitHub |
|---|---|---|
| 條款 | Apache-2.0 | MODEL_LICENSE v1.1 |
| 用途限制 | 無 | 「僅供參考與學習使用」 |
| 終止條款 | 無 | 有（違反即自動終止） |

而且兩個模型的證據強度不同（`curl` HF API 逐一確認過）：

- `funasr/paraformer-zh-streaming`：repo 內含 **11,358 bytes 的 Apache-2.0 全文**
- `funasr/ct-punc`：**只有 model card 上的一個 metadata 標籤**，repo 內沒有授權原文

ct-punc 是整份清單裡授權證據最弱的一項，而它被放在 P0 功能的必經路徑上。

## 決策

**預設的語音辨識模型改為 `whisper-large-v3-turbo-q5`（MIT）。ct-punc 退出
預設路徑。Paraformer 保留為選用。**

實作上就是 `padnote_models::DEFAULT_ASR_MODEL` 這一個常數，加上清單裡的
`optional` 旗標。

## 理由

1. **授權乾淨。** MIT，單一通路，沒有用途限制，沒有終止條款。不需要
   「工程判斷哪一條通路算數」這種帶法律性質的推論。
2. **Whisper 自己就會標點。** 這是關鍵的一點：C5（中文標點還原）是 P0，
   而原本的做法是「不會標點的 ASR + 一個專門補標點的模型」。換成一個本來
   就會標點的模型之後，**293 MB 的下載與那條最弱的授權鏈一起消失**。
   一個模型能做完的事，不必接兩個。
3. **一個模型覆蓋六個語系。** Paraformer 只做中文。介面有六種語言，另外
   五種原本就得回頭找 Whisper —— 也就是說 Whisper 本來就一定要在清單裡，
   Paraformer + ct-punc 是**額外**的 524 MB，不是替代品。
4. **最廣、最穩。** whisper.cpp 是目前部署最廣的裝置端 ASR，ggml 權重到處
   都有鏡像，社群活躍。授權爭議的模型一旦上游改口，我們沒有第二來源。

## 代價（要講清楚）

- **失去串流。** Paraformer 是串流模型，Whisper 不是。
  但**今天並沒有真的失去** —— 目前的整合本來就是段級（VAD 段、上限 5 秒，
  見 S-32 的紀錄：「分塊狀態封在圖內，目前只能段級串流」）。真的要做到幀級
  逐字浮現時，這一條要重新評估。
- **下載略大。** 574 MB（Whisper）對 524 MB（Paraformer 230 + ct-punc 294）。
  多 50 MB，換掉兩個模型、一條授權爭議，以及五個語系的覆蓋。
- **中文辨識率未實測比較。** Paraformer 是中文專用模型，理論上中文表現可能
  較好。這一點**沒有量過**（H2 的中文測試集還沒建），所以不能當成決策依據 ——
  但它是重新評估這個決策的觸發條件。

## 什麼時候要重新評估

- H2 的中文測試集建好之後，兩個模型跑同一份資料，字錯誤率差距顯著（> 3%）
- 真的要做幀級串流（逐字浮現）時
- FunASR 上游把兩條通路的條款統一

## 沒有做的事

- **沒有移除 Paraformer 與 ct-punc。** 它們仍在清單裡、仍可選用，
  `scripts/export-funasr-onnx.py` 與 `PROVENANCE` 驗證都保留。ADR-0006 描述的
  匯出流程依然是取得那兩個權重的正確方式 —— 改的只是「預設要不要用它」。
- **沒有改核心的管線。** `TranscriptPipeline` 早就接受 `punctuation: None`
  （有測試 `works_without_a_punctuation_model`），因為 Whisper 這條路上的文字
  進來時就已經有標點了。
