# `.padnote` 格式規格 v0.1

> 狀態：**M0 定稿候選**　|　日期：2026-09-12
> 本規格**公開發佈**（`features.md` H4）。任何人皆可依此解析 Padnote 筆記，不需要 Padnote 程式。
> 這是履行「資料主權」承諾的technical contract，破壞相容性需經 ADR。

---

## 1. 設計約束

| 約束 | 來源 | 規格上的體現 |
|---|---|---|
| 零衝突同步（無伺服器） | `architecture.md` §4 | 每裝置單寫者、append-only 檔案 |
| 筆跡↔音訊時間軸互跳 | `features.md` C1/C4 | 全域 `notebook_time_us` 單調時間軸 |
| 未來可重新渲染／訓練模型 | `architecture.md` §3.2 | 儲存**原始取樣點**，不存擬合後曲線 |
| 資料主權 | `features.md` H4 | 目錄式套件、標準容器、規格公開 |
| E2EE 上雲 | `features.md` G6 | 加密只作用於 `sync/` 下的 chunk |

---

## 2. 套件結構

```
MyNotebook.padnote/
├── manifest.json                 # 必要。UTF-8 JSON，唯一的明文中繼資料
├── doc/
│   ├── snapshot-<seq>.automerge  # CRDT 快照（二進位，Automerge 格式）
│   └── ops/
│       └── <lamport>-<device_id>.oplog
├── ink/
│   └── <page_uuid>.strokes       # 筆畫二進位（見 §4）
├── media/
│   ├── audio/<session_uuid>.opus # Ogg-Opus 容器
│   └── blobs/<aa>/<sha256>       # 內容定址，<aa>=sha256 前 2 個 hex 字元
├── sync/                         # 僅同步用；內容為加密後的 chunk
│   └── <device_id>/log-<seq>.bin
└── index/                        # 本機衍生，**永不同步**，可安全刪除重建
    ├── search.tantivy/
    └── cache.sqlite
```

**規則**
- `index/` 必須被同步引擎忽略（衍生資料，重建成本低於同步成本）。
- `doc/ops/` 與 `sync/` 下的檔案**一旦寫入即不可修改**，只能新增或整檔刪除（GC）。
- 檔名中的 `device_id` 保證單一寫者 ⇒ 檔案層級衝突在雲端硬碟上不可能發生。

---

## 3. `manifest.json`

```json
{
  "format": "padnote",
  "spec_version": 1,
  "notebook_id": "0193f2a1-7c4e-7000-8000-000000000001",
  "created_at_unix_ms": 1757635200000,
  "time_origin_unix_us": 1757635200000000,
  "title": "線性代數 第三週",
  "min_reader_version": 1,
  "encryption": {
    "scheme": "none"
  }
}
```

加密時 `encryption` 為：
```json
{
  "scheme": "xchacha20poly1305-argon2id",
  "kdf": { "algo": "argon2id", "m_cost_kib": 65536, "t_cost": 3, "p_cost": 1, "salt_b64": "..." },
  "wrapped_dek_b64": "...",
  "recovery": { "algo": "bip39", "words": 24 }
}
```

- `spec_version`：格式版本，遞增。
- `min_reader_version`：低於此版本的讀取器**必須拒絕開啟**而非嘗試解析（防止靜默資料損毀）。
- `time_origin_unix_us`：時間軸原點（見 §4.1）。

---

## 4. 統一時間軸（★本規格最核心的部分★）

### 4.1 定義
```
notebook_time_us : u64
  = 自 manifest.time_origin_unix_us 起算的微秒數
  單調遞增，不受系統時鐘調整影響（以 monotonic clock 取樣後換算）
```

**所有帶時間的內容一律以此為唯一座標系**：

| 內容 | 欄位 | 說明 |
|---|---|---|
| 筆畫 | `Stroke.started_at_us` | 落筆瞬間 |
| 筆畫內取樣點 | `InkPoint.t_us` | 相對該筆畫起點的偏移（u32，上限約 71 分鐘/筆畫） |
| 文字編輯 | CRDT op 的 `ts_us` | |
| 錄音 session | `AudioSession.started_at_us` | |
| 轉錄詞 | `Word.start_us` / `Word.end_us` | 相對 notebook 時間軸，**非相對音檔** |

> ⚠️ **設計要點**：轉錄詞的時間戳直接記在 notebook 時間軸上，而不是音檔內偏移。這樣即使使用者剪輯、合併多段錄音，筆跡↔文字↔音訊的對應關係仍然成立。

### 4.2 為什麼必須在 M0 定稿
C1（筆跡↔錄音跳轉）、C4（詞級時間戳）、A10（筆跡重播）、B6（版本回溯）四個功能全部建立在此座標系上。時間軸語意事後變更 = 所有既有筆記的時間資料失效。

### 4.3 多錄音 session
一個筆記本可有多個不重疊或重疊的 `AudioSession`。查詢「某筆畫當時的錄音」＝ 在 session 區間樹中以 `started_at_us` 做點查詢。

---

## 5. 筆畫二進位格式（`ink/<page_uuid>.strokes`）

小端序（little-endian）。檔案為 append-only 的筆畫記錄串流。

### 5.1 檔頭（32 bytes）
| 位移 | 型別 | 欄位 |
|---|---|---|
| 0 | `[u8;8]` | magic = `PADNINK\0` |
| 8 | `u16` | version = 1 |
| 10 | `u16` | flags（bit0 = zstd 壓縮 payload） |
| 12 | `u32` | reserved |
| 16 | `[u8;16]` | page_uuid |

### 5.2 筆畫記錄
| 型別 | 欄位 | 說明 |
|---|---|---|
| `u32` | `record_len` | 本記錄後續位元組數 |
| `u8` | `record_kind` | 1=AddStroke, 2=RemoveStroke |
| `[u8;16]` | `stroke_id` | UUIDv7（自帶時間序） |
| `u64` | `started_at_us` | notebook 時間軸 |
| `u16` | `tool_id` | 見 §5.3 |
| `[u8;4]` | `color_rgba8` | |
| `f32` | `base_width` | 頁面單位 |
| `u32` | `point_count` | |
| `[InkPoint; n]` | `points` | 見 §5.4 |

`RemoveStroke` 記錄僅含 `stroke_id`（墓碑，tombstone）。**擦除不是刪除位元組**，而是追加墓碑 —— 保持 append-only 不變式，同時讓時間軸重播與版本回溯成為可能。

### 5.3 `tool_id`
| 值 | 工具 |
|---|---|
| 1 | 鋼筆（壓感寬度） |
| 2 | 原子筆（固定寬度） |
| 3 | 螢光筆（乘法混色、扁筆頭） |
| 4 | 鉛筆（紋理） |
| 100+ | 保留給自訂筆 |

### 5.4 `InkPoint`（16 bytes，緊密排列）
| 位移 | 型別 | 欄位 | 範圍 |
|---|---|---|---|
| 0 | `f32` | `x` | 頁面座標（非螢幕座標，縮放無損） |
| 4 | `f32` | `y` | |
| 8 | `u16` | `pressure` | 0–65535 映射 0.0–1.0 |
| 10 | `u16` | `tilt` | 0–65535 映射 0–π/2 弧度 |
| 12 | `u16` | `azimuth` | 0–65535 映射 0–2π 弧度 |
| 14 | `u16` | `t_us_delta` | 距前一點的微秒差（>65535 時插入重複點） |

> **不做破壞性平滑**。Catmull-Rom 擬合、寬度調變、抗鋸齒全部在渲染期進行。理由：未來換渲染演算法或訓練手寫辨識模型時，歷史筆記能回溯受益。競品多數存已擬合的貝茲曲線，資訊一去不回。

---

## 6. CRDT 文件層（`doc/`）

- **結構**（頁面樹、區塊、屬性）：Automerge 3
- **富文本**：Yrs（y-crdt）text type，嵌在 Automerge 節點內
- 筆畫**不放進 CRDT**。筆畫走 §5 的 append-only 串流，CRDT 只持有 `page_uuid → strokes 檔` 的引用。
  - 理由：一筆畫數百個點，放進 CRDT 會讓 op 數量爆炸、合併成本失控。append-only + 墓碑已足以保證收斂（新增/刪除可交換）。

### 6.1 文件操作日誌

`doc/ops/` 下的每個檔案是一串 `DocOp` 記錄，逐筆緊密排列：

```
[1B 操作類型][操作內容…]
```

32 種操作：

**文件結構**：`SetTitle` / `AddPage` / `RemovePage` / `SetPageSize`
**內容區塊**：`AddTextBlock` / `AddTranscriptBlock` / `AddImageBlock` /
`RemoveBlock` / `SetBlockStyle` / `SetBlockPosition` / `SetBlockAppearance` / `TextEdit`
**錄音**：`StartAudio` / `EndAudio` / `AddWord`
**物件**（ADR-0010）：`AddObject` / `RemoveObject` / `SetObjectTransform` /
`Group` / `Ungroup` / `SetZIndex`
**表格**：`AddTableBlock` / `SetTableCell` / `InsertTableRow` / `DeleteTableRow` /
`InsertTableColumn` / `DeleteTableColumn` / `MergeTableCells` / `UnmergeTableCell`
**嵌入文件**（ADR-0009）：`AddEmbeddedBlock`

字串以 `u32` **位元組**長度前綴（非字元數）。UUID 為原始 16 bytes。
時間為 `u64` 微秒，落在統一時間軸上（§4）。

`TextEdit` 內嵌文字 CRDT 操作（ADR-0004）：插入記錄 `(id, origin, 字元碼位)`，
刪除記錄 `(id)`。**位置以 origin 參照表示，不是索引** —— 索引在併發編輯下會錯位。

### 6.2 區塊外觀（`SetBlockAppearance`）

`SetBlockAppearance` 帶的是一段 **JSON 字串，核心不解讀內容**。

理由：核心不需要知道「淡黃色」或「圓角 12」是什麼意思 —— 那是平台的 UI 詞彙。
但那些值**必須跨得過平台**：使用者在 iPad 上把文字方塊設成透明底、加了行距，
換到 Android 打開卻變回白底無行距，那不是「還沒支援」，是資料遺失。

**兩個平台必須用同一組鍵名。** 目前定義如下（全部可省略，省略即採平台預設）：

| 鍵 | 型別 | 說明 |
|---|---|---|
| `fontSize` | number | 字級（點） |
| `bold` / `italic` / `underline` / `strikethrough` | bool | 字形 |
| `alignment` | string | `left` / `center` / `right` / `justified` |
| `textColorHex` | string | `#RRGGBB` |
| `backgroundColorHex` | string | `#RRGGBB`，或 **`"clear"`（透明）** |
| `hasBorder` | bool | |
| `borderColorHex` | string | `#RRGGBB` |
| `borderWidth` | number | 點 |
| `cornerRadius` | number | 點 |
| `width` / `height` | number | 方框尺寸（點）。**兩者都是權威值**，不是「建議值」—— 高度由內容決定的話，同一個方塊在兩個平台高度不同 |
| `lineSpacing` | number | 行距（點） |
| `paragraphSpacing` | number | 段落間距（點） |
| `firstLineIndent` | number | 首行縮排（點） |
| `paragraphIndent` | number | 整段縮排（點） |

物件的 `x` / `y` 是**未旋轉版面框的左上角**，與 `width` / `height` 同一個座標系。

寫下來是因為它被誤解過：Apple 端曾經把文字方塊的垂直中心定在 `y + 60`
（等同假設方塊高 120）而不是 `y + height / 2`，於是同一份筆記的文字方塊
在 iPad 與 Android 上落在不同的位置，且高度一改就錯位。

### 6.2.1 堆疊順序（`objectOrder`，Apple 端過渡欄位）

Apple 的筆記 JSON 帶一個 `objectOrder`：由後到前的物件 id 清單，決定誰疊在
誰上面。不在清單裡的 id 排在最後（最上層），順序照型別預設 —— 舊筆記沒有
這個欄位，疊放結果與過去完全相同。

**這是過渡做法，不是最終格式。** 核心的物件樹本來就有
`bring_to_front` / `send_to_back` / `z_index` / `draw_order`，而且 FFI 已經
開出來、Android 的物件也直接活在那棵樹上。長期應該由核心當唯一的順序來源；
Apple 因為附件 id 與核心物件 id 只在匯出時建立對應，暫時走自己的清單。
細節與收斂計畫見 `docs/TODO.md` 的 Z-01 / Z-02。

`"clear"` 是**哨符**，不是顏色：它與 `#FFFFFF` 是兩回事，而且不能走顏色轉換
（多數 hex 轉換會丟掉 alpha，透明就變成黑色）。

新增鍵時只要兩個平台一起加即可，核心不必動。

#### 圖片區塊的外觀：數字製圖

圖片區塊的外觀用一個**帶標記的外層**，不是把設定直接攤在頂層：

```json
{ "object": "chart", "chart": { …ChartSpec… } }
```

`object` 是判別欄位。沒有它的話，讀的人只能靠猜 JSON 的形狀來判斷「這張圖是不是
一張圖表」—— 而圖片區塊日後還會有別的外觀資訊（邊框、濾鏡），猜錯的代價是把一張
普通照片當成圖表打開。

`chart` 的內容是圖表設定，欄位由 `padnote-chart` 的 `ChartSpec` 定義
（`kind`、`title`、`categories`、`series`、`legend`、`dataLabels`、`xAxis`／`yAxis`、
`barWidthRatio`、`doughnutHoleRatio`），全部 camelCase、全部可省略。

**為什麼存設定而不是只存那張圖。** 圖片區塊的 blob 裡本來就有一張算繪好的點陣圖，
匯出 PDF 與尚未支援圖表的讀取器都靠它。但點陣圖是**最終產物** —— 只有它的話，
使用者插入圖表之後，裡面的數字就再也拿不回來，想改一個值只能整張刪掉重做。
設定跟著區塊走，圖表才改得動，而且在另一個平台上一樣改得動。

版面**不在**這份設定裡：幾何由核心的 `chart_layout()` 從設定即時算出來，
兩個平台因此得到同一張圖。把算好的座標寫進檔案反而會讓兩邊有機會不一致。

### 頁面尺寸與區塊座標

`SetPageSize` 記錄頁面的寬高（點）。頁面高度是**內容的一部分**，不是顯示偏好：
使用者向下延長過的長畫布若沒有落盤，換一個平台打開會回到預設高度，
畫在下半部的內容看起來就像被截掉了。

`SetBlockPosition` 記錄區塊在頁面上的絕對座標。沒有這個操作時 `Block.position`
永遠是 `None`，所有絕對定位的物件（文字方塊、圖片）跨平台開啟後會擠在一起 ——
而且在原本的平台上看不出來，因為位置是另外存的。

### 堆疊順序

`SetZIndex` 記錄的是**絕對索引**，不是「上移一層」。相對操作在併發下會疊加：
兩台裝置各按一次「移到最上層」，合併後會得出誰也沒預期的順序。
索引**只在同層內有效** —— 跨層移動等於改變父子關係，那是 `Group`／`Ungroup`
的職責。讀取端必須把越界索引夾到合法範圍，不得拒絕整份 oplog。

### 表格

`AddTableBlock` 的 `cells` 以**列為主**扁平展開，長度必為 `rows × cols`；
長度不符時讀取端補空白或截斷，不得丟棄整個表格。

`SetTableCell` **逐格**記錄。整表覆寫會讓兩人同時編輯不同格時互相蓋掉。

### 物件與變換（ADR-0010）

物件持有 2×3 仿射矩陣（6 個 `f32`，row-major：`a b c d tx ty`）。

**取樣點永不因變換而改寫。** 縮放、旋轉、移動都只改矩陣，渲染與命中測試時
把變換套用在讀取端。直接改寫座標會讓「存原始取樣點」的性質消失（ADR-0002），
而且反覆縮放會累積浮點誤差讓筆跡走樣。

群組只記錄成員 id，**不搬動筆畫資料** —— 因此群組與解散是 O(1) 且完全可逆。

⚠️ 寫入物件操作時 `min_reader_version` 必須提升為 **2**：
舊讀取器遇到未知的 op 類型會靜默丟失群組與變換資訊。

重開筆記本時依檔名順序重播全部記錄即得目前狀態。損毀的記錄會**回報錯誤而非
略過** —— 靜默略過會讓使用者以為只是「某些內容不見了」。

### 6.2 oplog 檔名
```
<lamport:016x>-<device_id>.oplog
例：0000000000001a2f-7c4e9b12.oplog
```
Lamport 時戳前置 ⇒ 檔名字典序即因果序，掃描目錄即可得到套用順序。

---

## 7. 同步層（`sync/`）

### 7.1 chunk 格式

chunk 是**框架串流**。每次推送追加一個框架：

```
[4B 長度(u32 LE)][payload...]

payload（加密時） = [24B nonce][ciphertext][16B Poly1305 tag]
payload（未加密） = zstd(序列化後的 op 批次)
```

**為什麼需要長度前綴**：兩次推送之間只拉取一次時，讀到的位元組範圍會橫跨
兩個獨立的密文塊。沒有框架邊界，解密必然失敗。

**部分框架**：寫到一半當機會留下不完整的尾巴。讀取端只消耗完整框架並據此
推進游標，殘缺的部分留待下次補齊 —— 不當成損毀資料丟棄。

**AAD**：加密時以 chunk 路徑作為 additional authenticated data，防止攻擊者把
A 檔的密文搬到 B 檔的位置。內容雖然仍讀不懂，但重排本身就足以破壞資料。

### 7.2 provider 能力差異
| Provider | append 支援 | 策略 |
|---|---|---|
| 本機資料夾 / Syncthing / Dropbox | ✅ | 直接 append 至 `log-<seq>.bin`，超過 4 MiB 換新檔 |
| iCloud Drive | ✅（經 NSFileCoordinator） | 同上；需處理未下載（evicted）狀態 |
| Google Drive | ❌ 無 append API | 每次同步寫新檔 `log-<seq>.bin`，達 N 個檔後合併 |

### 7.3 收斂保證
1. 每裝置只寫 `sync/<自己的 device_id>/` ⇒ 無跨裝置寫入競爭
2. 檔案 append-only ⇒ 雲端不會判定為修改衝突
3. CRDT 合併滿足交換律與冪等 ⇒ 套用順序無關，最終一致

---

## 8. 版本遷移策略

| 情況 | 行為 |
|---|---|
| `spec_version` > 讀取器支援 且 `min_reader_version` ≤ 讀取器 | 允許開啟，忽略未知欄位（向前相容） |
| `min_reader_version` > 讀取器 | **拒絕開啟**並提示升級（絕不嘗試解析） |
| 讀取器升級後開啟舊檔 | 執行 `migrations/v<N>_to_v<N+1>.rs`，**先備份原檔**再就地升級 |

每次 schema 變更必須附：遷移程式 ＋ 舊版樣本檔 ＋ 回歸測試。此為 CI 強制項。

---

## 9. 保留與未決

- [ ] 附件（PDF）是否納入內容定址 blob — 傾向是，可跨筆記本去重
- [ ] 墓碑 GC 策略（保留期 vs 快照後清除）
- [ ] 大型筆記本的 strokes 檔分片閾值
- [ ] `tool_id` 100+ 自訂筆的參數序列化格式
