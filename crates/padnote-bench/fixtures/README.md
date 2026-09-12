# ASR 測試集

> **這是專案最有價值的資產之一。** 競品能抄 UI，抄不走你手上的台灣口音教室錄音與標註。

## 格式

`*.tsv`，四個欄位以 Tab 分隔：

```
scenario<TAB>id<TAB>reference<TAB>hypothesis
```

| 欄位 | 說明 |
|---|---|
| `scenario` | `quiet` / `noisy` / `codeswitch` |
| `id` | 語句識別碼，對應 `audio/<id>.wav` |
| `reference` | 人工標註的正確文本 |
| `hypothesis` | ASR 引擎輸出 |

`#` 開頭與空行為註解。

## 門檻（M0/S2 Go 條件）

| 場景 | CER 門檻 | 說明 |
|---|---|---|
| `quiet` | ≤ 8% | 安靜教室、近場麥克風 |
| `noisy` | ≤ 18% | 背景噪音、多人交談、遠場 |
| `codeswitch` | ≤ 15% | 中英夾雜（功能 C9） |

門檻依場景分開計算。**混在一起算會掩蓋問題** —— 大量安靜語句會把嘈雜場景的失敗平均掉。

## 目標規模

M0 需 **≥3 小時**；M2 前擴充至 **≥10 小時**。組成建議：

- 台灣口音大學課堂（近場 + 遠場各半）
- 會議室多人交談（含重疊發話）
- 中英夾雜的技術討論
- 專有名詞與數字密集的內容（最容易出錯的地方）

## 為什麼需要自建

公開 WER/CER 基準用的是乾淨、朗讀式的音檔。真實教室與會議（噪音、口音、
專有名詞、重疊發話）可能讓 5% 的帳面數字惡化到 15–20%。**不能信廠商數字。**

## 執行

```bash
cargo run -p padnote-bench --bin asr-score -- crates/padnote-bench/fixtures/sample.tsv
```

音檔本身不入版控（見 `.gitignore`），僅 `.tsv` 標註進 git。
