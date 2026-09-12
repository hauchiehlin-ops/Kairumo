# ADR-0005：推論執行期選用 ONNX Runtime 而非 tract

- 狀態：**已接受**（2026-09-12）
- 相關：S-26（Silero VAD）、S-24（Paraformer-zh）、D4（PP-OCRv5）

## 背景
專案偏好純 Rust、零原生相依。`tract-onnx`（Sonos，MIT）是純 Rust 的 ONNX
推論引擎，理論上最符合約束。

## 實測結果
tract **無法載入 Silero VAD**，v4 與 v5 皆然：

```
Translating node #72 "If_25" If ToTypedTranslator
  Condition failed: then_body.output_fact == else_body.output_fact
  (1,1,704,F32 vs 1,1,1,704,F32)
```

模型內含 8 kHz / 16 kHz 的條件分支，兩個分支的輸出秩不一致，
tract 的 `ToTypedTranslator` 直接失敗。這不是設定問題，是 tract 的能力邊界。

## 決策
採用 **`ort`**（ONNX Runtime 綁定，Apache-2.0），以 `download-binaries`
取得預編譯執行期。

## 理由
- 這是唯一能真正跑起來的選項
- 同一個執行期之後還要服務 Paraformer-zh（S-24）與 PP-OCRv5（D4），
  **一套推論庫服務三個用途**，比每個模型各帶一套划算
- 與既有的原生相依（whisper.cpp、PDFium、libopus）一致，不增加新的性質

## 後果
- 多一個原生執行期庫要隨各平台打包（iOS 靜態、其他動態）
- `download-binaries` 在建置時需要網路；離線建置需改用系統安裝的 ONNX Runtime
- 純 Rust 的目標未達成。若 tract 日後支援這些運算元，介面
  （`VoiceActivityDetector`）不需改動即可換回
