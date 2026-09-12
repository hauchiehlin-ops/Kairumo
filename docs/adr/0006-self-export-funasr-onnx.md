# ADR-0006：自行從官方權重匯出 FunASR 的 ONNX

- 狀態：**已接受**（2026-09-12）
- 決策編號：D-07
- 相關：`models/LICENSE-AUDIT.md`、S-24、功能 C5（P0）

## 背景
Paraformer-zh 與 ct-punc 的權重經由兩個通路散布，授權條款不一致：

| 通路 | 條款 |
|---|---|
| HuggingFace `funasr/*`（官方組織） | **完整的 Apache-2.0 LICENSE 檔案** + README 明文宣告 |
| FunASR GitHub `MODEL_LICENSE` v1.1 | 「僅供參考與學習使用」+ 不得詆毀 + 自動終止 |

同時，官方 HF repo **只有 PyTorch 權重，沒有 ONNX**。既有的 ONNX 來自第三方
轉換（`csukuangfj/sherpa-onnx-*`），該 repo 自行宣告 Apache-2.0 ——
但轉換者的宣告不能高於上游授予的權利，provenance 多了一層。

C5（中文標點還原）是 **P0 功能**，因此「不採用」等於少一個 P0 功能。

## 決策
**自行從 HuggingFace `funasr/*` 的官方權重匯出 ONNX。**

匯出流程必須記錄完整 provenance：
- 來源 repo 與 **commit revision**（不是 `main`，那會浮動）
- 該 repo LICENSE 檔的 SHA-256（證明取得當下的授權條款）
- 匯出工具與版本
- 產出檔案的 SHA-256

## 理由
- 官方 repo 內的 Apache-2.0 LICENSE 檔是**最強的授權依據** ——
  著作權人在自己的散布通路放上完整授權文本，是明確的權利讓與
- 自行匯出讓**整條鏈**都落在那份授權底下，不依賴第三方轉換者的宣告
- 保住 C5 這個 P0 功能

## 後果
- 多一條 Python 匯出流程（`scripts/export-funasr-onnx.py`），不進一般建置路徑
- 產出的 ONNX 需自行託管（GitHub Releases），成為 D4 模型分發的一部分
- **provenance 紀錄檔必須與模型一起發布**，讓下游可以自行核對
- 若 FunASR 日後變更 HF repo 的授權，已匯出的版本仍受當時的授權涵蓋 ——
  這正是要記錄 revision 與 LICENSE 雜湊的原因

## 未解
本 ADR 是工程判斷，不是法律意見。通路 B 的「僅供參考與學習」措辭若被主張
適用，仍有疑義。專案擁有者已在知悉此風險的情況下選擇本方案。
