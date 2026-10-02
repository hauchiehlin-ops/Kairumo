# 平板優先的驗證方式

> **狀態（2026-10-03）：五層全部落地。** 入口：`./scripts/verify-ipad.sh`（L1–L4 + 日誌閘門 + 全部單元測試）、
> `./scripts/differential-audit.sh`（L5）。各層的位置見文末「落地對照表」。

> 起因（2026-10-02）：實機上愈來愈多「Mac 正常、iPad 不正常」的問題 —— 資料夾打不開、
> 錄音卡片刪不掉、同步後播不出來／名字與秒數不同、檔案選擇器第二次不跳出。
> 而這個專案的主體是平板。這份文件說明**為什麼這些問題單元測試抓不到**，以及補哪幾層。

## 一、為什麼 Mac 好好的、iPad 不行

這些不是「iPad 的 bug」，而是 Mac 剛好**遮住了**的差異：

| 差異 | Mac（Catalyst）| iPad | 這次的實例 |
|---|---|---|---|
| 檔案可見度 | 使用者有 Finder，能挑任何路徑 | 沙盒；只有「檔案」App 的「Kairumo」資料夾 | 「開啟 Kairumo Record」 |
| 音訊 session | 沒有 `AVAudioSession` 類別切換問題 | 錄音後 `.playAndRecord` 還黏著，切 `.playback` 會失敗 | 錄完按播放沒聲音 |
| 輸入 | 滑鼠點擊精準、沒有觸控手勢仲裁 | 手指／Pencil 與 PencilKit、SwiftUI 手勢互相搶 | 播放鈕被外層點擊吃掉 |
| 呈現階層 | 視窗各自獨立 | 一個 presenter 同時只能呈現一個 sheet／picker | 檔案選擇器第二次不出現 |
| 同步節奏 | 長時間前景，一輪一輪慢慢來 | 前景／背景頻繁切換，焦點通道 1 秒就跑一輪 | 刪掉又「秒出現」 |
| 版面 | 大視窗 | 11"／13"、直／橫、分割檢視 | 畫布兩側留灰、工具列太擠 |

共同點：**測試都在同一台模擬的、單一裝置、單一模式、預設視窗大小上跑**，而使用者的問題發生在
「兩台裝置之間」「某個模式下」「做了兩次」「錄完立刻」這些組合上。

## 二、要補的幾層（由便宜到貴）

### L1　多裝置情境矩陣（已開始，最划算）
同步的錯誤全是「兩台裝置 × 一連串操作」才會出現。`PackageMultiDeviceTests` 已有兩台裝置輪流匯入匯出的
測試台（`syncRound`）。規則：

- **每種物件 × 每種操作（新增／刪除／移動／改名） × 誰寫的（自己／對方） × 輪流同步 ≥ 4 趟**。
  新增物件種類時，必須把它加進 `testDeletingAnyForeignObjectKindSticksAcrossSyncRounds` 的表。
- 斷言的是**不變式**（刪掉的不復活、數量不增生、名字與秒數兩邊相同），不是某個實作細節。
- 下一步：把「錄音」整條（錄 → 命名 → 同步 → 對方掃描 → 顯示名稱／秒數）做成同一個情境；
  這次的「名字沒同步」就是「名字在掃描之前就匯入了」的順序問題，單點測試永遠測不到。

### L2　互動矩陣（iPad 模擬器 XCUITest）
列出 `物件種類 × 編輯模式（手寫／打字） × 動作（點選、主要動作、刪除、搬移）`，每格一個斷言，
識別碼用 `accessibilityIdentifier`。目前 `ScreenAudit` 只檢查「畫面上有沒有這個元件」，沒有檢查
「點下去有沒有發生事」。這次的播放鈕、貼紙確認鈕、刪除鈕全是「元件在，但點不到／點了沒反應」。
- 11" 與 13"、直式與橫式各跑一輪（`-destination` 參數化）。
- 失敗要附截圖與可及性樹，否則看不出是「沒點到」還是「點到了沒反應」。

### L3　平台能力契約測試
把「這個平台一定要做到的事」寫成可重複執行的測試，**每個都做兩次**（第二次才是使用者的第一次抱怨）：
- 檔案選擇器：呈現 → 取消 → 再呈現 → 選檔 → 再呈現。
- 錄音後播放：同一個行程內錄 1 秒（模擬器無麥克風時以合成 PCM 餵核心）→ 立刻播放，斷言 `isPlaying` 且時間前進。
- 開啟資料夾：回傳值要有「開成功／退回」兩種結果可斷言，不能只是 fire-and-forget。

### L4　裝置上的一鍵自檢
模擬器永遠缺：真實麥克風、「檔案」App 的真實 provider、背景／前景切換、記憶體壓力。
在「診斷」面板加一顆「平板自檢」，在**使用者的實機上**跑 L3 的那幾項並顯示通過／失敗與原因
（例如：audio session 目前類別、錄音資料夾是否出現在「檔案」、檔案選擇器是否能再次呈現）。
使用者回報問題時附上這份結果，比描述症狀有用得多。

### L5　Mac / iPad 差分
同一份 UI 稽核在 `Mac Catalyst` 與 `iPad` 兩個 destination 各跑一次，**比對結果**而不是各自通過就算。
任何「Mac 過、iPad 不過」的項目自動列成清單 —— 這正是這次反覆發生的形狀。

## 三、每個歷史問題該被哪一層抓到

| 問題 | 該抓到的層 |
|---|---|
| 刪掉的錄音卡片復活 | L1（已加：別台寫的物件刪除矩陣；匯出後刪除的競態）|
| 播放鈕沒反應 | L2（點擊後斷言播放狀態）|
| 錄完不能播 | L3 + L4 |
| 檔案選擇器只能用一次 | L3 |
| 名字、秒數不一致 | L1（錄音整條情境）|
| 資料夾打不開 | L3 + L4 |
| 兩側留灰、工具列太小 | L2（量測元件尺寸、橫直式各一）|

## 四、做法上的紀律

1. **修一個 bug 就補一格矩陣**，而不是只補一個測試。矩陣的空格比單點測試更能預告下一個 bug。
2. 重建後先 `simctl terminate` 再 `launch`，否則量到的是舊版（見 memory：simulator-launch-keeps-old-process）。
3. 「模擬器上重現不了」要寫進回報，不要用「已修正」帶過 —— 這類問題交給 L4 在實機上驗。

## 五、落地對照表

| 層 | 內容 | 位置 |
|---|---|---|
| L1 | 多裝置情境矩陣：每種物件「別台寫的、這台刪掉」×4 趟輪流同步；文字／圖片／形狀；錄音整條（名字、檔名、秒數、雙向改名）；匯出後刪除的競態 | `apple/Tests/PackageRoundTripTests.swift`（`PackageMultiDeviceTests`）|
| L2 | 互動矩陣：5 種物件 ×（直式／橫式）× 存在、尺寸、可點、選取後有刪除、刪得掉且不復活、控制項有標籤；音訊卡播放鈕真的會播 | `apple/UITests/InteractionMatrixAudit.swift`，種子見 `NotebookStore.injectInteractionFixturesIfRequested`，節點見 `View.objectProbe` |
| L3 | 平台能力契約：播放連兩次、錄完（session 還在 playAndRecord）立刻播、失敗不靜默、「檔案」App 網址、檔案選擇器連開三次、轉錄語系 | `apple/Tests/PlatformContractTests.swift`、`apple/UITests/PlatformContractUITests.swift`、`android/.../PlatformSelfCheckTest.kt` |
| L4 | 裝置上的一鍵自檢：診斷面板「裝置自檢」，Apple（`PlatformSelfCheck.swift`）與 Android（`PlatformSelfCheck.kt`）同一組問題、同一個報告格式，可複製 | 首頁右上「診斷」▸「裝置自檢」|
| L5 | Mac / iPad 差分：同一份 UI 稽核在兩個 destination 各跑，列出「Mac 過、iPad 不過」 | `scripts/differential-audit.sh` |
| 補 | 執行期日誌閘門：從系統日誌挖出『畫面與測試都看不到』的錯誤，硬規則出現一次就失敗 | `scripts/runtime-log-gate.sh` |

## 六、第一輪跑起來就抓到的東西

這是這套方法最有說服力的地方 —— 落地當天就找出以前沒人看見的問題：

1. **播放在 iPad 上失敗的真正原因**（日誌閘門）：`.playback` 類別帶了 `.defaultToSpeaker`，
   系統回 `category option 'defaultToSpeaker' is only applicable with category 'playAndRecord'`，
   `setCategory` 失敗、引擎起不來。Mac 的分支沒帶這個選項，所以 Mac 一直是好的 ——
   完全吻合「Mac 可以播、iPad 不行」。
2. **「在畫面更新途中改狀態」**（日誌閘門）：`updateUIView` 每次更新都把 `PKCanvasView` 寫進 `@State`，
   每個工作階段幾十次；量大到會讓 XCTest 把 App 弄崩潰。
3. **圖片的刪除鈕沒有無障礙標籤**（L2）：VoiceOver 只念「按鈕」。
4. **圖示不存在**（日誌閘門）：`point.3.filled.connected.trianglepath` 在系統圖示庫裡找不到，畫面上是空白。
5. **測試手法本身的陷阱**：對整棵無障礙樹做 `descendants(matching: .any)` 連續幾十次，XCTest 自己的
   log 量就能讓受測 App 被系統隔離而崩潰（`__LIBTRACE_CLIENT_QUARANTINED_DUE_TO_HIGH_LOGGING_VOLUME__`）。
   互動矩陣的查詢一律用型別查詢 + 謂詞，不逐顆列舉。

7. **Android 的『檔案選擇器』自檢誤報**：Android 11+ 沒在 manifest 宣告 `<queries>`，
   `queryIntentActivities` 一律回空。已補上宣告；自檢（與 Android 連兩次的契約測試）現在通過。

### 已知存量（日誌閘門的『軟規則』，尚未修）
- `Accessing FocusState's value outside of the body of a View`：就地編輯文字方塊的 `.task` 在 `await` 之後寫
  `@FocusState`，SwiftUI 說這會變成常數綁定 —— 也就是「鍵盤時有時無」的可能原因（程式碼裡的註解早就提過這個症狀）。
- `Unable to render flattened version of PlatformViewRepresentableAdaptor<PlatformTextFieldAdaptor>`：
  某處把含 `TextField` 的視圖拿去算繪成圖片（縮圖／匯出）。

### 還沒做到的
- Android 的 L2 目前只涵蓋錄音卡片（`AudioLayerInteractionTest`：播放鈕、刪除鈕點得動、連點兩次）；
  其他物件種類與 L5 差分還沒有。下一步是把 Apple 那張物件表搬過去。
- 形狀的刪除鈕：XCUITest 送出的點擊到不了它（真實觸控可以，已手動驗證），所以矩陣對形狀只斷言
  「選取後有可點的刪除控制項」。這是工具限制，已在測試裡註明。
- L4 的『檔案』App provider、真實麥克風、背景／前景切換，只有在使用者的實機上跑自檢才驗得到。
