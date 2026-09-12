# Apple 平台（Phase 1：iPadOS / macOS）

決策 D1：Phase 1 以 Apple 平台優先，業務邏輯全部在 Rust core，UI 與墨跡渲染原生。

## InkSpike —— M0 / Spike S1

驗證 `docs/roadmap.md` 的 Go 門檻：**motion-to-photon ≤ 9ms**，連續書寫 10 分鐘無掉幀。

### 檔案
| 檔案 | 作用 |
|---|---|
| `Sources/LowLatencyInkView.swift` | CAMetalLayer + 預測筆跡 + 手動 present |
| `Sources/InkRenderer.swift` | 雙層渲染、Catmull-Rom 擬合、壓感寬度 |
| `Sources/LatencyProbe.swift` | 機上量測（**僅供迴歸偵測，不能用來判定門檻**） |
| `Shaders/Ink.metal` | 頂點/片段著色器 |

### 尚待接手（需要實體裝置）
1. 以 Xcode 建立 iOS App target，將上述檔案加入，部署到 **實體 iPad**
   （模擬器的 Metal 路徑與顯示管線都不同，量出來的數字無意義）
2. 執行下方量測協定
3. 把結果填回 `docs/roadmap.md` 的 M0 Go/No-Go 決議

---

## S1 量測協定（motion-to-photon）

`LatencyProbe` 量不到硬體端的觸控取樣延遲與面板發光延遲，因此**不能用它宣告達成門檻**。
真正的判定必須用高速攝影機。

### 器材
- 實體 iPad（ProMotion 120Hz 機型與 60Hz 機型各測一台）
- 高速攝影機 **≥240fps**（近年 iPhone 的 240fps 慢動作即可）
- Apple Pencil

### 步驟
1. 把相機架在能同時拍到**筆尖**與**螢幕筆跡**的角度
2. 以穩定速度畫直線，錄製 10 秒
3. 逐格檢視，找出「筆尖明顯移動的第一幀」與「該位置出現墨跡的第一幀」
4. 計算：

```
延遲(ms) = (墨跡出現的幀號 − 筆尖移動的幀號) / 攝影幀率 × 1000
```

5. 取 **20 次獨立量測**的中位數與 p95

### 判定
| 結果 | 行動 |
|---|---|
| 中位數 ≤ 9ms 且 p95 ≤ 12ms | **Go** —— 自建墨跡引擎，Rust core 跨平台方案成立 |
| 9–12ms | 調校後重測（檢查 `presentsWithTransaction`、預測點數量、drawable 數） |
| > 12ms | **No-Go** —— 改用 PencilKit，跨平台墨跡另做（見 roadmap 風險登記簿） |

### 續航測試
連續書寫 10 分鐘後檢查 `latencyStatistics`：
- `droppedFrames` 應為 **0**
- `p95Millis` 不得比前 1 分鐘惡化超過 20%（偵測記憶體壓力與熱節流）

---

## 已知的三個延遲陷阱

1. **只讀 `touches.first`**：120Hz Pencil 在 60Hz 畫面上每幀有 2+ 個取樣，
   必須用 `coalescedTouches` 才拿得到全部，否則筆跡會有稜角。
2. **`presentsWithTransaction = true`**：直覺上像是「更正確」，實際會等到
   CoreAnimation 交易 commit，白白多一整幀。
3. **把預測點寫進持久化資料**：預測點是視覺補償，不是真實輸入。寫進 `.padnote`
   會污染日後訓練 HWR 模型的資料（format-spec §5.4）。
