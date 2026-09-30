# 物件身分：讓 Apple 的匯出不再讓方塊跨裝置增生

狀態：**第 1～3 步已實作（2026-10-01），與原設計有偏離，見第 9 節**。2026-09-30 草擬。對應 `docs/TODO.md` 的 S-OBJ-IDENTITY。

## 1. 問題（已重現、已量測）

使用者的一本筆記出現 **19,588 個文字方塊**、雲端 oplog 126 MB、附件資料夾 1.6 GB。iPhone 因
「oplog 操作筆數超過上限（100 萬）」載入失敗並每輪重試，Mac 開啟極慢甚至當掉，iPad 點卡片撞
10 秒看門狗。

重現測試：`apple/Tests/PackageRoundTripTests.swift` 的
`testTextBoxesDoNotMultiplyAcrossRepeatedSyncs`。兩台裝置來回匯入、匯出，2 個文字方塊依序變成
4、6、10、16、26、42…（費氏數列）。目前用 `XCTExpectFailure` 釘住，修好後會變紅提醒拿掉。

## 2. 根因

`NotebookPackageBridge.export`（`apple/Sources/NotebookPackageBridge.swift`）是**整本從零重寫**：
對每個文字方塊、表格、圖片、形狀都呼叫 `addText`／`insertTable`／`addImage`／`insertShape`，
核心每次用 `Uuid::now_v7()` 發**新 id**。`exportPreservingOtherDevices` 只會把「這台自己的舊檔」
換掉，別台寫的檔留著。

而 `importDocument` 會把**所有裝置**的方塊讀進工作副本。所以：

1. A 匯出 x（A 的 a1）。
2. B 匯入，看到 a1；B 之後一次匯出就把 a1 當成自己的物件**再寫一份新 id**（b1）。
3. A 匯入，看到 a1、b1；A 下一次匯出把兩個都再寫一遍（a2、a3）。
4. 每一趟都是「上一趟看到的全部」再寫一遍。

頁面不會增生，是因為頁面已經有穩定 id（`addPageWithId`）。其他物件沒有。

**Android 沒有這個問題**：核心是唯一事實來源，方塊 id 就是核心發的 id（例如
`TableStore.persist` 用 `table.id` 直接 `setTableCell`／`setBlockPosition`），只寫差異。
**只有 Apple 用「自己的 JSON 工作副本 + 快照式匯出」**，所以這是 Apple 獨有的缺陷，修法是讓
Apple 的同步改用與 Android 相同的模型。

## 3. 核心已經有的積木

`crates/padnote-doc/src/ops.rs` 的 `DocOp`：

| 需求 | 已有的操作 |
|---|---|
| 方塊有穩定 id | `AddTextBlock{id}`、`AddImageBlock{id}`、`AddTableBlock{id}` 都帶 id（只是 `app.rs` 的入口自己發 id） |
| 刪除 | `RemoveBlock{id}`、`RemoveObject{id}` |
| 位置、外觀 | `SetBlockPosition{id}`、`SetBlockAppearance{id}`（整段覆寫） |
| 文字內容的編輯 | `TextEdit{block, op}`（字元級 CRDT） |
| 頁面 | `addPageWithId` 已是先例 |

**缺的不是資料模型，是兩件事**：(a) FFI 沒有「指定 id 新增」的入口（只有頁面有）；(b) Apple 的匯出沒有
「跟目前文件比對、只寫差異」的步驟。

## 4. 目標與非目標

目標：
- 重複匯出、多裝置來回，物件數量**不變**（冪等）。
- 使用者刪除、編輯、搬動一個物件，會正確傳到別台；別台舊的 oplog 不會讓已刪的物件復活。
- 不破壞既有筆記本（已經有重複物件的那些，要能收斂、能清）。
- Android 行為不變；兩端共用核心邏輯，不各寫一份。

非目標：
- 不重做筆畫（筆畫走 append-only ink log，不在這次範圍）。
- 不改 oplog 格式（沿用現有操作，不加新的 op 種類，避免舊版 App 讀不懂）。

## 5. 設計

### 5.1 身分：附件 id = 核心方塊 id

- Apple 的 `NoteTextAttachment`、`NoteImageAttachment`、`NoteShapeAttachment`…已有 `id` 欄位。
  **匯入時把 `id` 設成方塊（物件）id**（表格與形狀現在已經這樣做，文字與圖片沒有）。
- 匯出時用**同一個 id** 新增。核心新增「指定 id 新增」入口：
  `add_text_block_with_id`、`add_image_block_with_id`、`insert_table_with_id`、
  `insert_shape_with_id`。語意與 `add_page_with_id` 相同：**已存在就不做任何事**。

### 5.2 匯出改成「差異同步」（核心做，不是 Swift 各寫一份）

新增核心入口（暫名）`sync_objects(page, desired: Vec<DesiredObject>, known_ids: Set<Uuid>)`：

1. 取得這一頁目前已存在的方塊 id 集合 `present`（核心已合併所有裝置的 oplog）。
2. 對每個 `desired`：
   - id ∉ `present` → 用該 id 新增，再寫位置、外觀、文字內容。
   - id ∈ `present` → 只在**值不同**時寫：位置／外觀不同就 `SetBlock*`；文字內容不同就用
     字元級 diff 產生 `TextEdit`（不整段覆寫，兩人同時編輯不同處才不會互相蓋掉，與 Android 表格
     「逐格寫」同一個原則）。
3. 刪除：`present` 中、**在 `known_ids` 裡**（這台上次同步時看過）、但 `desired` 沒有 → `RemoveBlock`。
   **不在 `known_ids` 裡的（這台還沒看過的、別台剛加的）一律不動。** 這條是防「復活／誤刪」的關鍵。

`known_ids` 存在哪：這台裝置每次匯入後，把當時看到的方塊 id 集合存在套件旁的 sidecar
（`SyncBaseline/` 底下已有放「別台的筆畫」的先例），匯出後更新。**它是這台的本機狀態，不同步。**

### 5.3 舊資料的遷移與清理

已經增生的筆記本（id 是各裝置各發的、內容重複）：

- 匯入時做一次**內容去重**：同一頁上「類型、位置、文字／圖片雜湊、外觀」完全相同的方塊視為同一個，
  保留 id 最小的那個。
- 被丟掉的重複方塊，匯出時用 `RemoveBlock` 明確刪除（帶著它們的 id），這樣別台不會把它們又讀回來。
  這一步也讓 oplog 在壓實後縮小。
- **護欄**：單頁物件數超過門檻（暫定 2,000）時，匯出前先中止並在診斷畫面顯示「這本筆記的物件數異常，
  已暫停同步」，不要再寫。寧可停，也不要讓雲端再長一個 126 MB 的日誌。

### 5.4 為什麼不用別的做法

- **內容雜湊當 id、只在匯入時去重**：編輯一個文字方塊會換 id，舊的還在別台的 oplog 裡，永遠去不掉，
  而且「刪除」沒辦法表達。**否決**。
- **匯出時略過「別台寫的」物件**：核心沒有每個方塊的作者資訊，而且使用者在 B 編輯了 A 寫的方塊，
  那個編輯必須被寫出去。**否決**。
- **只改 Swift、不動核心**：id 由核心發，Swift 沒辦法指定；差異邏輯各平台各寫一份就是 Android 和
  Apple 行為不同的老問題。**否決**。

## 6. 測試計畫

1. **重現測試翻成通過**：`testTextBoxesDoNotMultiplyAcrossRepeatedSyncs` 拿掉 `XCTExpectFailure`，
   對文字、表格、圖片、形狀各一份。
2. **核心屬性測試**（Rust）：N 台裝置隨機做「新增、編輯、刪除、搬動、同步」，任意順序同步到收斂後，
   (a) 所有裝置的物件集合相同，(b) 物件數 = 使用者實際存在的數量，(c) 重複同步 100 趟數量不變。
3. **刪除不復活**：A 刪掉方塊、B 落後且沒看過刪除，B 同步後該方塊不能回來；B 新增的方塊 A 不能誤刪。
4. **遷移**：拿一個「2 → 42 個重複」的套件匯入，去重後剩 2 個，匯出後 oplog 不再變大。
5. **跨平台**：iPad 寫文字方塊 → Android 收到且只有一份 → Android 改 → iPad 收到一份；
   沿用 `scripts/multi-device-run.sh` 三台劇本，加上文字方塊與表格。
6. **量測**：用一本 19,588 個方塊的壞套件，確認載入與開啟時間、記憶體在合理範圍（護欄觸發前不撞看門狗）。

## 7. 風險與未決問題

- **`known_ids` 遺失**（重裝、清資料）：這台當成「什麼都沒看過」，於是不會刪任何東西（安全方向）；
  代價是使用者在遺失後才刪的東西，要等下一輪才會傳出去。
- **向前相容**：不加新 op 種類，舊版 App 讀得懂；但舊版 App 仍用舊匯出，會繼續增生。
  所以要配合**最低版本提示**（TestFlight 內部先升、再推一般用戶）。
- **文字內容 diff 的成本**：大段文字每次匯出都算 diff；只在 `lastModified` 有變時做，並設上限。
- **未驗證**：Android 的文字方塊是否真的完全走差異寫入。我只確認了表格（`TableStore.persist`）。
  實作前要先審 Android 的文字與圖片路徑，必要時補同一組測試。
- **頁面層級的刪除／搬移**：`RemovePage`、`MovePage` 不在這次範圍，但 `known_ids` 的機制要能擴到它們。

## 8. 建議的實作順序

1. 核心：`*_with_id` 入口與 FFI（兩端綁定重建）。
2. 核心：`sync_objects` 與屬性測試（純 Rust，不碰平台）。
3. Apple：匯入設定 `id = blockId`；匯出改呼叫 `sync_objects`；`known_ids` sidecar。
4. 遷移與護欄。
5. 三台劇本加文字方塊與表格；Android 審查與補測試。
6. 發版前的最低版本提示。

預估：第 1、2 步各約一個工作天的量，第 3 到 5 步是主要風險，需要逐步在模擬器上跑三台劇本驗證。

## 9. 實作紀錄與偏離原設計之處（2026-10-01）

**做了什麼**

- 核心：`add_text_block_with_id`、`add_image_block_with_id`、`insert_table_with_id`、
  `insert_shape_with_id`、`insert_connection_with_id`（已存在就什麼都不寫），與對應的 FFI、兩端綁定。
- Apple 匯出：文字、表格、圖片、形狀、連接線、衍生圖片（3D／連結／錄音）都用附件自己的穩定 id
  新增（`stableBlockId`：UUID 字串原樣小寫，否則 SHA-256 決定性轉成 UUID）；匯入時附件 id ＝ 核心方塊 id。
- **別台裝置已經寫過的方塊不重寫**：`foreignBlocks` 先把套件裡「不是這台的 oplog」複製到暫存目錄開一個
  工作階段，讀出別台寫的 id、位置、外觀；匯出時略過這些 id。這台搬動或改過外觀的別台方塊，
  另外把**差異**寫成這台的操作（`applyForeignEdits`，只比語意，避免每輪都多寫一批）。
- 舊資料：匯入時把同一頁上內容、位置、外觀完全相同的方塊收斂成一份（文字、表格、圖片）。
- 測試（`PackageMultiDeviceTests`）：文字方塊跨裝置 8 趟維持 2 個且內容不重複；文字、表格、形狀、連接線
  8 趟維持不變；別台方塊被搬動後只有一個且在新位置；作者刪掉的方塊別台不會寫回去；舊的重複收斂。

**偏離原設計**

1. **沒有做核心的 `sync_objects`（第 5.2 節）。** 原設計要 Apple 與 Android 共用一個「比對目前文件、
   只寫差異」的核心入口。實作時發現更小的做法就能止血：用「這台自己的舊 oplog 會被整批換掉」這個既有
   事實，把別台的檔案單獨讀出來，**剩下的就是這台寫的**，不需要 `known_ids` sidecar，也不需要核心新 API。
   代價是差異邏輯在 Swift（Android 本來就逐項寫差異，沒有這個問題），見下面的限制。
2. **沒有做 `known_ids` 與跨裝置刪除。** 因為 `RemoveBlock` 在核心沒有墓碑記憶，而作者每次匯出都會
   重寫自己的 `AddBlock`，別台刪掉作者的物件會被作者下一輪寫回來。要真的支援，作者端也得改成
   append-only（不再整批換掉自己的 oplog），那是更大的改動。
3. **沒有做單頁 2,000 個物件的護欄。** 增生的來源已經關掉；護欄留給之後。

**已知限制（誠實列出）**

- 別台寫的**文字內容**，這台編輯了不會傳出去（只傳位置與外觀）。以前是變成重複的方塊，現在是編輯被
  作者那邊的版本蓋掉。
- 別台寫的物件，這台**刪掉**不會傳出去；作者那台仍有，下次匯入會回來。
- 別台的形狀、連接線的搬動不會傳出去（形狀走的是變換，不是區塊外觀）。
- 連接線的一端是別台寫的形狀時，這台不寫那條連接線。
- 舊 App（沒有這個修正的版本）仍會增生；修正要配合最低版本提示。
