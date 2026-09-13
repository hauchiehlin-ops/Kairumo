# 開發日誌

> 反序排列（最新在上）。每個開發階段結束時追加一筆。
> 記錄**為什麼**這樣做，而不只是做了什麼 —— 「做了什麼」看 git log 就好。

---

## 2026-09-13 (8) · WP3b：協同中繼進核心 FFI，但**預設關閉**

### 為什麼是 feature 而不是直接換掉 Apple 的那份

Apple 版的 Swift 中繼（Network.framework）已經在使用者手上穩定運作。
把 tokio 拉進 iOS 的二進位不但沒有好處，還會動到已經穩定的功能 ——
硬前提就是不准這樣。所以 `relay` 這個 feature **預設關閉**：Android 建置時開，
Apple 不開。兩邊仍然共用 `padnote-relay` 的同一份 JSON 協定，
加密走 WP3a 的 `padnote_crypto::session`，所以 iOS 與 Android 能進同一個房間。

驗證這件事本身也要有憑據：`cargo tree -p padnote-core` 在未開 feature 時
**tokio 出現 0 次**，開了才是 3 次。

### bind 與 serve 拆開

`padnote-relay` 原本的 `run_server` 是「綁定完就進迴圈」，沒有機會回報實際埠號。
App 端常常用 port 0 讓系統挑，然後必須把**實際**綁到的埠顯示給使用者（邀請隊友
要填）。所以拆成 `bind()` / `serve(listener, hub, shutdown)`。

### 踩到的坑：不要在 FFI 裡 block_on

第一版 `RelayServer::start` 用 `runtime.block_on(bind(addr))`，測試立刻炸：
`Cannot start a runtime from within a runtime` —— 呼叫端本身在 async runtime 的
執行緒上。改成用同步的 `std::net::TcpListener` 綁定（順便就拿到埠號），
設成非阻塞後再交給 runtime。這樣不管呼叫端在什麼執行緒上都安全。

### 另一個坑：綁定要用相同的 feature 組合產生

Kotlin 端出現 `Unresolved reference: RelayServer` —— 因為產生綁定那一步用的是
預設 feature 的函式庫，裡面根本沒有 relay 的型別。建置腳本已改為用與 Android
相同的 feature 組合產生綁定。

### 驗收

- `crates/padnote-core/tests/relay_ffi.rs`：起中繼 → 兩個 WebSocket 客戶端加入
  同一房間 → 驗 joined / peers / peer_joined / oplog 轉發 → 停止。2 個測試通過。
- Android 模擬器實機：畫面顯示「協同中繼：已啟動於埠 36451（已停止）」。
- 硬前提回歸：`cargo test --workspace` 785 通過、iOS 建置 BUILD SUCCEEDED。

---

## 2026-09-13 (7) · WP3a：協同加密下沉到核心，並用跨語言測試證明相容

### 兩邊的加密其實是兩套演算法

盤點發現核心與 Apple 版用的根本不是同一個東西：

| | 演算法 | 用途 |
|---|---|---|
| `padnote-crypto::envelope` | XChaCha20-Poly1305 + Argon2id | **落盤**的同步檔案 |
| Swift `CollaborationManager` | AES-256-GCM（CryptoKit） | **即時協同訊息** |

也就是說協同訊息這條路，核心從來沒有實作過。Android 若自己再寫一份，
兩邊要在同一個房間裡互相解得開就得逐位元組對齊 —— 那是典型的安靜失敗。

### 做法：核心實作「與已上線 Apple 版相同」的那一套

新增 `padnote_crypto::session`，AES-256-GCM，位元組佈局照抄 CryptoKit 的
`AES.GCM.seal(...).combined`：

```text
combined = nonce(12) || ciphertext || tag(16)
```

**刻意不動 Swift。** 硬前提是不影響已穩定的 Apple 版，而且使用者手上已經有
在跑的 iOS 版 —— 讓核心去配合既有格式，Android 就能直接與它互通，Apple 端
一行都不用改。日後 iOS 要改走核心也不會有 wire 格式變動。

### 相容性不是用推論的，是測出來的

`crates/padnote-crypto/tests/cryptokit_interop.rs`：Rust 加密 → 真的叫 `swift`
用 CryptoKit 解；CryptoKit 加密 → Rust 解。雙向都通過。
沒有 Swift 工具鏈的機器（Linux CI）自動跳過，不會因此變紅。

FFI 曝露 `session_key_generate` / `session_seal` / `session_open` 三個函式，
Android 端在模擬器上實機跑過 round-trip：畫面顯示「AES-256-GCM round-trip 通過」。

新增相依 `aes-gcm`（連同 aes / ctr / ghash / polyval）皆為 MIT OR Apache-2.0，
符合 deny.toml 的白名單。

### 硬前提回歸

`cargo test --workspace` 785 通過、0 失敗；iOS 建置 BUILD SUCCEEDED。

---

## 2026-09-13 (6) · Android WP1–WP2：核心可編、APK 跑起來了

決策（專案擁有者拍板）：**路線 2（一次到位，Apple 儲存層改用核心格式）**、
**minSdk 29**、**第一版不含語音轉錄**。硬前提：不得影響現有 iOS / iPadOS / macOS。

### WP1 · 讓核心在 Android 編得出來

三個真實阻擋，逐一解掉：

**1. ONNX Runtime 沒有 Android 預編譯檔。** `ort-sys` 的 build.rs 直接 panic。
`padnote-core` 切出 `asr`（Silero VAD + 中文標點）與 `pdf`（PDFium）兩個 feature，
**預設全開 → Apple 端相依與行為完全不變**；Android 用 `--no-default-features` 建置。
VAD 在 feature 關閉時退回內建的能量式 VAD，錄音本身照常。

**2. libopus 缺席。** 這個最陰險：第一顆 APK 裝起來、跑起來，然後畫面顯示
`dlopen failed: cannot locate symbol "opus_encoder_destroy"` —— `.so` 帶著未定義
符號出貨了。Android 沒有系統 libopus，而 `audiopus-sys` 交叉編譯時不會自己建。
新增 `scripts/build-android-opus.sh`：用 NDK 的 CMake 工具鏈把 libopus 編成靜態庫
（下載後比對 xiph 官方 SHA256SUMS，符合 D4 的下載驗證規則），再由
`OPUS_LIB_DIR` 指給 audiopus-sys 靜態連結。

**3. audiopus-sys 沒有宣告 `rerun-if-env-changed`。** 換 ABI 時 cargo 會沿用上一個
ABI 的建置結果，於是 x86_64 的 .so 又帶著未定義符號。建置腳本改為逐 ABI
先 `cargo clean -p audiopus_sys` 再編。

驗收：`llvm-readelf --dyn-syms` 對兩個 ABI 的 `libpadnote_core.so` 查未定義 opus
符號，皆為 **0**；`NEEDED` 只剩 libc / libm / libdl。

### WP2 · Gradle 骨架與綁定整合

`android/`（Compose、minSdk 29、targetSdk 35、AGP 8.7.3 / Gradle 8.11.1），
UniFFI Kotlin 綁定經 JNA 呼叫 `.so`。CI 新增 android job：建 .so → 組 APK → 上傳產物。

驗收：模擬器（Pixel / Android 15）安裝執行，畫面顯示 **由 Rust 回傳的**
核心版本 2.3.0 與 `android/aarch64` —— Kotlin ⇄ UniFFI ⇄ Rust 這條路確認打通。

### 硬前提的回歸驗證

| 檢查 | 結果 |
|---|---|
| `cargo test --workspace` | 778 通過 · 0 失敗 |
| iOS 模擬器建置 | BUILD SUCCEEDED |
| Mac Catalyst 建置 | BUILD SUCCEEDED |

（clippy 有 4 個既有警告，位於 `ffi.rs` 的 insert_shape/insert_connection 與
`app.rs` 的表格迴圈，與本次改動無關；STATE.md 說的「零警告」已經過時。）

---

## 2026-09-13 (5) · 匯出是空白的，以及文字方塊的互動重做

### 匯出 PDF／圖片全是空白

`exportAsPdf` 寫死 `CGRect(0, 0, 612, 792)`（信紙尺寸）並且**只畫 PKDrawing**。
但畫布的座標系是「視圖寬度 × 頁面高度」，在 Mac 上常常是 1500×1800 以上 ——
所以那個框只截到左上角一小塊，使用者寫在中間的內容完全落在框外，
匯出檔看起來就是一片空白。文字方塊、圖片、3D 與圖釘也從來沒被畫進去。

這跟先前「側邊欄縮圖只畫 PKDrawing」是同一個錯誤，只是這次還多了尺寸寫死。

修法：把縮圖用的整頁合成抽成 `PageThumbnailRenderer.renderFullPage`
（不裁切、不取快取、可指定 scale），匯出 PDF／PNG／列印三條路徑共用它，
並且**每一頁用自己的尺寸開 PDF 頁** —— 頁面可以被「向下延長」，高度不一定相同。

驗證方式（`KAIRUMO_EXPORT_AUDIT=1`）：在模擬器裡合成一份帶手繪筆劃（刻意畫在
舊版取圖框之外的 y≈1000）、文字方塊（自訂底色＋紅色 3pt 邊框）與討論圖釘的頁面，
走匯出路徑輸出 PNG。結果三種內容都在圖裡，位置與畫布一致。

### 文字方塊：刪不掉、莫名的雙向箭頭、不能就地編輯

- 刪除鍵原本是三顆**無標示的小圓點**，壓在方塊右上角、還往外偏移 —— 難點也看不懂。
  改成帶文字的按鈕列（編輯／邊框／刪除）浮在方塊上方，並補上**右鍵／長按選單**
  （就地編輯、文字排版、邊框、刪除）—— 那是大家最先嘗試的操作。
- 移除右下角的「雙向箭頭」縮放把手：它只能改寬度、又小又會擋住文字。
  寬度改到「文字排版」面板裡用滑桿調。
- **點兩下＝就地編輯**：直接在畫布上改字，不必先開面板。
- 文字排版面板補上：自訂底色（ColorPicker）、邊框顏色（六色 + 自訂）、
  邊框粗細（三段）、圓角（直角／圓角／大圓角）、方塊寬度滑桿。
  `NoteTextAttachment` 新增 `borderColorHex` / `borderWidth` 兩個可選欄位
  （舊檔解碼時落到預設值，不影響相容性），匯出算繪也會套用同樣的邊框樣式。

---

## 2026-09-13 (4) · 畫布自適應、可拖曳捲軸、筆記拖放分類、套索工具列

### 收合側欄後畫布沒有變寬

`updateUIView` 是在 SwiftUI 狀態改變時呼叫，那個時間點 `bounds.width` 還是
**版面變動前**的舊值 —— 所以收合結構欄之後 contentSize 仍停在「扣掉側欄」的
寬度，右側空出一塊灰色。真正知道新寬度的時機是 `layoutSubviews`。

改用 `AdaptiveCanvasView`（PKCanvasView 子類）在 `layoutSubviews` 重算
contentSize 與樣板背景的尺寸。順帶拿掉寫死的 800pt 下限 —— 畫布內容寬度
就是視圖寬度，縮圖算繪也改用同一個基準。

UI 測試驗證：開啟筆記 → 收合側欄 → 斷言畫布寬度 > 視窗寬度的 85%。

### 游標拖不動捲軸

iOS 的捲動指示器是**純顯示**的，不接受互動。在 iPad 上沒差，但在 Mac 上跑時
使用者會很自然地想用游標去拖它。新增 `CanvasScrollbar`：自己畫一條捲軸，
接受拖曳與點擊軌道，直接設定 `contentOffset`；捲動狀態由
`scrollViewDidScroll` 回報給 SwiftUI。

### 未分類筆記可以拖進資料夾

側欄的筆記列加上 `.draggable(note.id)`，資料夾列與「未分類檔案」標題加上
`.dropDestination`，懸停時高亮。拖進資料夾即分類，拖回「未分類」即移出。

### Copy 與 Duplicate 的差別，以及缺少的「貼上」

畫布上長按出現的 Cut / Copy / Delete / Duplicate / Insert Space Above 是
**PencilKit 自己的系統選單**，不是我們畫的，也改不了它的文字。差別是：
Copy 進剪貼簿等你貼上，Duplicate 直接在旁邊多一份。

問題在於**那個選單只在有選取時出現**，複製完取消選取就沒有貼上的入口了。
所以在我們自己的套索工具列補上「貼上」與「再製」，並把純圖示按鈕改成
圖示＋文字＋說明提示（游標停留會顯示「複製到剪貼簿，之後用『貼上』放到
想要的位置」這類說明）。

---

## 2026-09-13 (3) · iOS 實機閃退：SwiftUI 型別名稱把主執行緒堆疊撐爆

### 症狀與當機記錄

實機（iPhone 17 Pro / iOS 27）一碰筆記或頁面就閃退，模擬器（iOS 18 與 27、
Debug 與 Release）與 Mac 上都正常。當機記錄：

```
Exception Type:  EXC_BAD_ACCESS (SIGSEGV)
Exception Subtype: KERN_PROTECTION_FAILURE ... Stack Guard
Thread 0 Crashed:
0..56  swift::Demangle::TypeDecoder::decodeMangledType / decodeGenericArgs  ← 遞迴 57 層
57     swift_getTypeByMangledName
58     swift_getTypeByMangledNameInContext
59-60  Kairumo
61     SwiftUICore ViewBodyAccessor.updateBody
```

不是我們的程式碼在崩，是 **Swift runtime 解析型別名稱時遞迴到爆堆疊**。

### 根因：body 的 mangled 型別名稱長達 89,768 字元

SwiftUI 把 `body` 整棵子樹的型別（包含每個 `.sheet` 內容的完整型別）編進
外層的 mangled 名稱。量測結果：

| | 修正前 | 修正後 |
|---|---|---|
| `NotebookEditorView.Body` | **89,768** 字元 | **6,478** |
| `HomeWorkbenchView.Body` | 31,977 | 6,002 |

**為什麼只在實機當：iOS 主執行緒堆疊只有 1MB，模擬器有 8MB。** 同一份程式碼
在模擬器上解析得完，在實機上遞迴到一半就撞上 Stack Guard。這也解釋了為什麼
使用者在 Mac 上跑同一個 iOS 二進位（Designed for iPad）不會當 —— 那裡的
主執行緒堆疊同樣寬裕。

### 修法：在大型子視圖插入型別邊界

把 20 個大型子視圖改成回傳 `AnyView`（`editorTopBar`、`drawingToolbar`、
`canvasWorkArea`、`allNotebooksSection` …），並用 `erasedView { }` 包住每個
`.sheet` / `.fullScreenCover` 的內容。父視圖的型別裡只剩 `AnyView` 三個字，
子樹的型別各自獨立解析。

代價是那些子樹失去結構化 diff，多一點重繪成本 —— 相對於實機必當，這個交換
很划算。

**量測方式留在程式裡**：`KAIRUMO_TYPE_AUDIT=1` 啟動時會印出兩個 body 的
型別名稱長度。這是唯一能在模擬器上看見這個問題的方法，改大型視圖後應該複查。

### 一併修掉

- 版本號：`MacWindowTitle` 原本包在 `#if targetEnvironment(macCatalyst)` 裡，
  但使用者在 Mac 上跑的是 **iOS 版**（`otool -l` → `platform 2`），整段程式
  沒被編譯進去 —— 這是版本號改三次都沒出現的真正原因。拿掉條件編譯，
  並在編輯器工具列直接畫上版本標籤，不再只依賴系統視窗標題。
- 討論串可以刪除單一則留言；已解決時多一條明顯的狀態列。
- 操作手冊與隱私權政策打包進 App，首頁「說明與條款」離線可讀（WKWebView）。
- 兩份文件的語言切換改成下拉式選單。

---

## 2026-09-13 (2) · 拖曳抖動、視窗標題守門員，與一個會覆蓋筆記的 Binding

### 圖釘浮層拖曳抖動：又是 .local 座標系的回授迴圈

拖曳手勢用預設的 `.local` 座標系，而手勢掛在被 `.offset` 位移的視圖上：
位移改變 → 手勢座標系跟著動 → translation 重算 → 位移再變，一個迴圈。
畫面就是劇烈抖動。改用 `DragGesture(coordinateSpace: .global)`，
全域座標不受自身位移影響。

這與 ADR 之外那條「畫布物件拖曳晃動」的成因是同一類 —— 值得記成通則：
**手勢若會改變自己所在視圖的位置，座標系就不能用 .local。**

順帶修好對話框標題列被擠壓（作者名稱直排、「標記為已解決」變成直書）：
寬度 320→360，名稱與按鈕文字加上 `lineLimit(1)` 與 `fixedSize()`。

### Mac 視窗標題：加上守門員計時器

上一版加了重試與場景通知，但使用者在**編輯器**裡仍看不到版本號 ——
`fullScreenCover` 推上來時 SwiftUI 會重設 `scene.title`，而那個時機
沒有對應的通知可掛。補上每秒一次、只在值不同時才寫入的守門員。
實測（Mac Catalyst 執行 + `CGWindowListCopyWindowInfo` 讀標題）：
首頁與編輯器都穩定顯示 `Kairumo v2.1.0`。

### ⚠️ 編輯器切換筆記會覆蓋掉目前這一則

測試途中在編輯器的資料夾目錄點另一則筆記，畫面整片空白。追下去發現：

```swift
// 舊的 switchToNotebook
self.notebook = updatedTarget   // notebook 是 $store.notebooks[index] 的 Binding
```

`notebook` 是 `$store.notebooks[index]`，index 在浮層呈現當下就算好了。
把另一份文件寫進這個 Binding，等於**把目前這則筆記在陣列裡的那一格
覆蓋成目標筆記** —— 原本那則的紀錄消失，陣列裡出現兩筆相同 id，
`ForEach` 的識別壞掉，畫面整片空白。

三層修正：
1. 編輯器不再自己寫 Binding，改為回呼 `onRequestSwitch`
2. 新增 `NotebookEditorHost` 持有「現在是哪一則」的 id，每次重算索引 ——
   切換只是換 id，不動任何一則筆記的內容，也不必關掉再重開浮層
3. `loadData` 載入時依 id 去重（保留最後修改的一筆），讓已經寫壞的檔案
   下次啟動自己痊癒，而不是一直卡在空白畫面

本機測試資料確認 5 則筆記都還在（記憶體中的覆蓋沒有落盤）。

---

## 2026-09-13 · UI 缺陷修正：結構側欄、圖釘浮層、內建協同中繼

三個實機回報的缺陷。

### 線上協同連不上，是因為後面根本沒有人在聽

預設位址 `ws://127.0.0.1:9002` 是 Rust 版 `padnote-relay` 監聽的埠，
但 App 從來不會去啟動那支程式，使用者手上也沒有可連的服務 ——
於是每次都停在「連線中斷，正在自動重新連線 (第 4/5 次)」。

改成由 App 自己提供中繼：`LocalRelayServer`（Network.framework 的
`NWListener` + `NWProtocolWebSocket`）在位址指向本機時自動啟動，
協定與 `crates/padnote-relay/src/hub.rs` 完全一致（第一位加入者為房主、
presence/oplog 轉發、最近 200 筆 oplog 供斷線追趕、房空自動回收）。

這不違反 D5。D5 說的是「我們不營運雲端後端」，不是「裝置不能開房間」——
發起協同的那台裝置當中繼點，資料仍然不經過任何我們的伺服器。
埠被占用時不當成錯誤：那通常代表已經有一個 `cargo run -p padnote-relay`
在聽，照常連過去就好。

順帶把失敗原因顯示出來。原本連不上只剩無聲的轉圈，使用者無從判斷是
位址錯、埠沒開、還是對方關機了。

### 圖釘對話框固定在圖釘旁邊，等於擋住要討論的東西

對話框原本用 `.position()` 釘在圖釘附近、完全不能移動 —— 而圖釘一定
就插在要討論的那塊內容上。加上標題列拖曳與「縮小成標題列」，
縮小後整條列仍可拖曳（縮小卻不能移動只是換個地方擋住畫面）。

### Mac 視窗標題看不到版本號

標題原本在 `onAppear` 裡 `DispatchQueue.main.async` 設一次。那個時間點
`connectedScenes` 可能還是空的（視窗場景尚未接上），設定就靜靜地掉了 ——
標題退回 App 名稱「Kairumo」。SwiftUI 的 `navigationTitle` 之後也可能覆蓋
`scene.title`。

改成 `MacWindowTitle`：場景還沒出現就短暫重試，並在場景／視窗／App
重新啟用時再確認一次，只有目前值不同才寫入（不會閃爍）。
順便把版本字串收斂成單一來源 `AppVersion` —— 先前三個檔案各自從
`infoDictionary` 撈，還各寫了不同的硬編碼 fallback（1.0.0 / 1.2.0 / 1.4.0），
版本一升級就互相對不起來。

驗證：實際建置 Mac Catalyst 版執行，用 `CGWindowListCopyWindowInfo`
讀回視窗標題為 `Kairumo v2.0.0`，等待數秒後仍未被覆蓋。

### 窄寬度的工具列：ViewThatFits 需要一個「一定塞得下」的候選

`ViewThatFits` 在所有候選都放不下時，會**無條件採用最後一個**，並以它的
理想寬度算繪 —— 於是工具列比視窗還寬、左右對稱被裁掉。iPad 直向與 iPhone
上「首頁」與「匯出與列印」直接消失，連退出筆記都做不到。

補上 `WrapLayout`（SwiftUI `Layout`）當最後一個候選：由左至右排、放不下就換行，
所以永遠有一個塞得下的版本。退讓順序刻意是「收文字標籤 → 收進『更多』選單 →
才換行」——換行會移動按鈕位置，是最後手段，不是第一選擇。

關鍵是**每顆按鈕都要是 Layout 的直接子視圖**：舊的 FlowLayout 版本把筆刷群組
包在 `HStack` 裡，那一整段變成單一子視圖，永遠不換行、照樣溢出。所以工具列
內容抽成 `@ViewBuilder` 的一串攤平項目，單行版與換行版共用同一份；
只有真的需要整組一起移動的（色盤、undo 群組）才刻意包成一個 `HStack`。

驗證：iPad 直向工具列換成兩行、iPhone 上主工具列兩行＋繪圖工具列四行，
所有按鈕都在畫面內；iPhone 維持側欄收合。

### 側邊欄縮圖的比例對不上畫布

縮圖固定用 800pt 寬算繪、卡片固定 130pt 高。但畫布的實際內容寬度是
`max(視圖寬度, 800)` —— 在 Mac 上是 1500 左右，物件的 x/y 存的又是畫布座標，
所以縮圖不只比例不對，位置也偏。再加上頁面預設 1800pt 高，`scaledToFit`
進 130pt 高的卡片後整頁只剩約 50pt 寬，物件小到看不出是什麼。

改成：縮圖用畫布的實際寬度算繪（由 GeometryReader 回報），卡片改為維持
同樣的長寬比、寬度撐滿側邊欄；頁面高度超過寬度 1.25 倍的部分裁掉，
底部畫一道漸層表示還有內容。物件在縮圖裡放大約 5 倍，且與畫布等比。

### 「打字」切不過去，是分段控制項把選項拆平了

模式切換用 `.pickerStyle(.segmented)`，每個選項裡卻放 `HStack { Image; Text }`。
UIKit 的分段控制項只吃單一 Text 或單一 Image —— HStack 會被拆成好幾段，
`.tag()` 跟著失效：畫面上看得到「打字」，點下去永遠回到手繪。
改成兩顆自己畫的按鈕，狀態由 `editorMode` 直接驅動。
切換前先 `saveCurrentPageDrawing()`，否則切模式時的畫布重建會吃掉未落盤的筆跡。

### 結構側欄預設展開

開啟筆記時看不到資料夾目錄，等於把「這則筆記放在哪裡」藏起來。
改為進入編輯器就展開，分頁選擇（頁面／資料夾）用 `@AppStorage` 記住。
iPhone（compact 寬度）維持收合 —— 280pt 側欄會把畫布擠到不能用。

### 驗證到哪裡
中繼服務有獨立的端到端煙霧測試（兩三個 WebSocket 客戶端實際加入同一
房間，驗證 joined / peer_joined / oplog 轉發 / catchup / peer_left），全數通過。
兩項純 UI 行為只驗證到可建置，實機互動待確認。

---

## 2026-09-12 (12) · 畫布物件、流程圖、工具列與六國語系（S-46 ～ S-50）

五項需求一次做完：物件自由排列、插入圖片與試算表圖形、流程圖範本、
工具列模組化、六國語系。

### 堆疊順序記「絕對索引」而不是「上移一層」

`SetZIndex` 存的是目標位置，不是相對動作。相對操作在無伺服器的 CRDT 下會疊加：
兩台裝置各按一次「移到最上層」，合併後誰也說不準結果。改成絕對索引後，
後到的 op 直接覆蓋，結果與套用順序無關。

移動**只在同層內**。跨層移動等於改變父子關係，那是 `Group`／`Ungroup` 的職責；
混在一起會讓「上移一層」偶爾把物件丟出群組，使用者完全無法預期。

### 連接線要「連」而不是「畫」

流程圖的價值在於線會跟著方塊走。把箭頭存成獨立線段，移動方塊時線就斷了 ——
那只是畫圖。因此 `Connection` 存的是「從哪個圖形的哪個連接點到哪個」，
路徑在渲染時才算。測試驗的也是這件事：移動後線的端點仍落在形狀邊緣上。

形狀用 ISO 5807 的標準語意（菱形＝判斷、平行四邊形＝輸入輸出），不自創圖形，
並把 `semantic()` 的說明帶到 UI —— 使用者看得懂符號才有意義。

### 試算表變成表格物件，而不是一段 Markdown 文字

原本 xlsx 匯入後變成兩個文字區塊（表名 + Markdown 表格）。那能看不能編：
改一格要去編輯一長串 `|` 分隔的文字。現在展開成 `BlockKind::Table`，
逐格編輯、整塊可搬動。

`SetTableCell` 逐格記錄而非整表覆寫 —— 整表覆寫會讓兩人同時編輯不同格時互相蓋掉。
`cells` 用扁平陣列而非巢狀 `Vec`：增刪欄只要 splice，巢狀結構容易出現長度不一致的列。

順帶把舊測試 `xlsx_becomes_a_markdown_table` 改寫成
`xlsx_becomes_an_editable_table_object` —— 它斷言的是舊契約，留著會擋住正確行為。

### 語系完整性交給型別系統

字串表若放在各平台的 `.strings` / `strings.xml`，就有五份要各自維護的表，
漏翻譯只有跑到那一頁才發現。放在 core 並以 `[&str; LOCALE_COUNT]` 表達，
**少一個語言就編不過**。

測試不只檢查「非空」，還檢查每個語言沒有偷懶照抄英文（重疊率 < 30%）、
日文有假名、韓文有諺文、泰文是泰文字母、繁簡至少有 15 個字不同。

### 抓到的兩個真缺口

1. `ToolGroup::Extras` 的標籤鍵指到 `Key::Record` —— UI 上整個「進階」分組
   會顯示成「錄音」。補了 `GroupExtras` 鍵。發現它的是 `ALL_KEYS.len()` 的
   數量守衛，這種看似笨拙的檢查真的會抓到東西。
2. `sibling_count` 一開始用 `draw_order().len()`，那是**整棵樹**的數量。
   群組內的物件「移到最上層」會算出錯誤上界。改成同層計數並補了對應測試。

### 平台層真的碰得到

上一輪的教訓是「能力建在 core 裡卻沒開 FFI，等於沒建」。這次同批完成：
`ffi_shapes.rs`（形狀／連接線／範本）、`ffi_ui.rs`（語系／工具列）、
session 上的 z 序與表格方法。`tests/s46_canvas_objects.rs` 刻意走平台層那條路，
其中 `z_order_survives_a_reopen` 驗的是**重開後順序還在** —— 只測記憶體內的狀態
會漏掉「沒落盤」這種最尷尬的缺陷。

Swift 綁定 178 個公開 API，`swiftc -parse` 通過。763 個測試、clippy 零警告。

### 尚未完成（已記入 TODO）

- **S-52**：形狀與連接線還沒有自己的 `DocOp` —— 幾何算得出來，但插入的流程圖
  還不會落盤，重開會消失。這是這批裡最明顯的缺口。
- **S-51**：表格只能建立固定尺寸並改格內文字，不能插入／刪除列欄或合併儲存格。
- **S-53**：工具列與語言切換的實際 UI 在平台層，Rust 端只是把資料準備好。

---

## 2026-09-12 (11) · 串流調查（S-32）

### 結論：改用段級串流，幀級串流需要重新匯出計算圖

原本以為要「重新匯出帶 cache 的 encoder」。查 FunASR 的原始碼才發現
**官方的串流 encoder 匯出本來就沒有 cache 輸入**：

```python
def export_encoder_input_names(self):
    return ["speech", "speech_lengths"]
```

串流是靠兩件事達成的：
1. 餵入帶重疊的特徵窗（`overlap_feats = cat(cache["feats"], feats)`，
   保留 `chunk_size[0] + chunk_size[2]` 幀）
2. decoder 的 16 個 cache 跨呼叫保留

我把兩者都實作了：`StreamingFrontend`（fbank 與 LFR 的跨塊邊界狀態）
與 `CifState`（跨塊的積分狀態，有測試證明分塊結果等同整段）。

**但幀級串流仍然不正確。** 實測不同的特徵上下文長度：

```text
整段處理      : 欢迎大家来体验达摩院推出的语音识别模型      ← 與 FunASR 吻合
幀級串流 ctx=5 : 嗯迎你迎来家来到看体验摩摩院推的的语音式模模式
幀級串流 ctx=15: 嗯迎你迎来家来到体验达摩院的的的音音频式识模式式
幀級串流 ctx=30: 嗯迎你迎大家来体验达摩院推的的语音式式模式
幀級串流 ctx=60: 嗯迎你迎大家来体验达摩院的的的音音音式模模式
```

加大上下文能緩解但無法解決。原因是 `online: True` 匯出的 encoder
把**分塊注意力遮罩的狀態封在計算圖內**，從外部餵特徵時它無從得知
自己處於哪一個分塊位置。

### 採取的作法
**預設段級串流**：`feed()` 只累積，`finish()` 才辨識。這與
`padnote-recorder` 天然契合 —— 它給的就是 VAD 切好的語音段。

延遲因此由 VAD 的 `MAX_SEGMENT_MS` 決定，已從 8 秒調到 **5 秒**。
這是取捨：太長延遲高、太短 ASR 上下文少。⚠️ 真正的甜蜜點要用 H2 的
中文測試集實測不同長度的 CER 後才能定。

幀級串流的基礎設施留著且有測試，等能匯出暴露分塊狀態的圖時可以直接接上。

### 為什麼不硬做
繼續加大上下文只是在猜，而且每次都要人工看輸出判斷好壞 ——
沒有 H2 的測試集，我無法量化「好一點」是真的好還是我在自我說服。

---

## 2026-09-12 (10) · 簡繁轉換與完整中文管線

### 做了什麼
463 → **487 個測試**。`padnote-text`（簡繁轉換）與
`padnote-core::transcript`（後處理管線），串起完整的中文鏈：

```
ASR 輸出 : 下周三下午三点在研讨室开会请大家准时参加
管線輸出 : 下週三下午三點在研討室開會，請大家準時參加。
```

### 為什麼這是必要的一步
Paraformer 與 ct-punc 都是**簡體模型**。在此之前整條管線的輸出是
沒有標點的簡體中文 —— 對台灣使用者等於不能用。

### 授權：差一點把 GPL 拉進來
`zhconv` 的 `Cargo.toml` 宣告 `license = "GPL-2.0-or-later"`。
直接 `cargo add zhconv` 會讓專案的 Apache-2.0 立場崩掉。

但讀 README 才發現那是因為**預設綁了 MediaWiki 的轉換表**：

> The library itself is licensed under MIT OR Apache-2.0 … BUT it may bundle
> conversion tables from MediaWiki … For MIT compatibility, disable the
> default `mediawiki` feature and enable `opencc`.

改用 `default-features = false, features = ["opencc"]` 後，綁的是 OpenCC 詞典
（Apache-2.0）。**而且品質取捨剛好相反**：OpenCC 表把「下周三」正確轉成
「下週三」，MediaWiki 表沒有。授權乾淨的選項同時也是比較好的選項。

### 兩個真實缺陷

**OpenCC 表在上下文中會誤判。**
「里面」單獨轉換是對的（→裡面），但在「代數里面」中，最長匹配先吃掉
「数里」，剩下的「面」被單獨轉成食物的「麵」。以專案維護的修正表補救，
**每一條修正都有測試**，且有反向測試確保不誤傷真正的「麵條」。

**逐詞轉換會失去詞組上下文 —— 這是測試抓到的。**
ASR 的詞多半是單字。「下」「周」「三」分開轉，「周」永遠不會變「週」，
因為那需要看到整個「下周三」。改成**整段轉換後再依字數分回各詞**；
字數改變時（少數詞彙替換會）退回逐詞轉換 ——
寧可少一點上下文，也不能讓時間戳錯位。

C1（點文字跳回錄音）完全依賴時間戳不變，這條不能妥協。

---

## 2026-09-12 (9) · 中文 ASR 與標點（S-24 / S-30）

### 做了什麼
411 → **463 個測試**。`padnote-punct-ct`（中文標點）與
`padnote-asr-paraformer`（fbank + LFR + CMVN + CIF + encoder/decoder）。

### 驗證方式：每一層都有獨立的真值來源
- **fbank**：用 FunASR 產生參考特徵，Rust 實作逐點比對（最大差異 <0.05）
- **CIF**：純數學，以 one-hot 幀追蹤每一幀的貢獻
- **整體**：用 FunASR 官方範例音檔比對 Python 與 Rust 的輸出

### 關鍵發現

**fp32 的輸出與 FunASR 完全吻合，證明管線正確。**
```
FunASR (fp32 PyTorch): 欢迎大家来体验达摩院推出的语音识别模型这ca
本實作 (fp32 ONNX)   : 欢迎大家来体验达摩院推出的语音识别模型
本實作 (int8 ONNX)   : 欢迎大家来体验达摩院推出的语音识别识别模型cia
```

**int8 量化明顯降低中文辨識品質。** 出現重複字（「识别识别」）與結尾雜訊。
進一步測試排除嵌入表（只量化 MatMul）得到**相同的劣化**，體積幾乎不變
（157.4 vs 157.6 MB）—— 問題出在量化 transformer 權重本身，不是嵌入表。
⚠️ 這是 **n=1 的觀察不是測量**，真正的取捨要等 H2 的測試集。

**匯出的 encoder 沒有 cache 輸入 —— 它不是真串流模型。**
一開始我按 0.6 秒切塊送進 encoder，輸出是
「嗯迎欢们大家来关注的来体验摩的的的的推一个语语音识模模一式型模型」——
每塊各自缺少上下文。改成整段處理後立刻正確。
幸好 `padnote-recorder` 給的就是 VAD 切好的語音段，天然符合這個模型的形態。

**FunASR 的 `dither=1.0` 讓特徵非確定性。**
同一段音訊兩次呼叫的特徵相差 0.27。轉錄結果必須可重現，因此前端關掉抖動。

**ct-punc 的詞表是簡體的。**
471,067 個 token 中僅 1.3% 是單字；繁體字（線、數、點）不在詞表內。
實測簡體 0/31 未知詞、繁體 3/18。因此管線順序必須是
**先標點、再轉繁體**，這不是實作細節而是正確性需求。

### 踩到的坑
- LFR 的輸出幀數要用**補齊前**的長度算，用補齊後會多一幀
- CIF 的測試期望算錯（alphas 總和 2.0 會發射兩次，我寫成一次）——
  實作是對的，測試是錯的
- `ort` 的混合型別輸入清單需要 `.into_dyn()`

---

## 2026-09-12 (8) · 模型授權稽核

### 做了什麼
在動手接 Paraformer-zh 之前先查授權（決策 D6 要求權重與程式碼分別確認）。
產出 `models/LICENSE-AUDIT.md`，排除一個模型，把另外兩個升級為待決策事項。

### 查到什麼

**Paraformer-zh 與 ct-punc 有雙通路授權衝突。**
同一份權重，兩個散布通路條款不一致：
- HF `funasr/*` 官方 repo：metadata 標 apache-2.0，且 **repo 內含完整的
  Apache-2.0 LICENSE 檔**，README 明文宣告以 Apache-2.0 發布權重
- FunASR GitHub 的 `MODEL_LICENSE`（v1.1）：授權「**僅供參考與學習使用**」，
  另含「不得詆毀」條款與違反即自動終止

著作權人對不同通路採不同授權是常見做法，HF 那份 LICENSE 檔是明確的授權讓與。
但通路 B 的措辭若被主張適用，產品使用就有疑義。**這是帶法律性質的判斷，
不該由我單方面決定** → 列為待決策 D-07。

**SenseVoice-Small 直接排除。**
權重走 FunASR Model License v1.1，不是 Apache-2.0。社群 2026-01 開的商用釐清
issue 至今**無維護者回覆**。「不得詆毀 + 自動終止」不是 OSI 開源授權，
與 `features.md` §4 賣點 3、4 宣稱的「開源、永遠免費且不可能反悔」直接衝突。
C9（中英夾雜）改由 whisper-large-v3-turbo 承擔 —— 它本來就支援 code-switching，
授權是乾淨的 MIT。

**官方 repo 沒有 ONNX。**
`funasr/*` 只有 PyTorch `model.pt`。目前 manifest 指的是第三方轉換版。
Apache-2.0 允許衍生作品，但轉換者的宣告不能高於上游授予的權利 ——
provenance 多了一層。

### 為什麼停在這裡而不直接接
C5（中文標點還原）是 **P0** —— 「中文轉錄沒有標點等於沒用」是市調寫進規格的
結論。若 D-07 選擇不採用，這個 P0 功能需要另找方案。
換句話說，D-07 不只是「要不要多一個 ASR 引擎」，而是**會不會少一個 P0 功能**。
這種等級的取捨應該由專案擁有者決定。

### 這次稽核的方法論
不只看 metadata 標籤，而是**實際抓 LICENSE 檔、讀 README 原文、查未結的
issue**。silero 那次的教訓（URL 指向需登入頁面）已經證明：
沒被實際驗證過的宣告等於沒有。

---

## 2026-09-12 (7) · Silero VAD（S-26）

### 做了什麼
376 → **395 個測試**。`padnote-vad-silero`（ort + Silero v4）、
遲滯開關邏輯、接進 `NotebookSession` 與 FFI、修正 manifest 的壞 URL。

### 為什麼換掉 EnergyVad —— 有數字
白噪音（振幅與語音相當）餵進兩個 VAD，100 個音框：

```
EnergyVad 誤判 100 個為語音
Silero    誤判   0 個
```

能量門檻法在真實教室（冷氣、投影機風扇）等於完全不可用。

### 選型過程

**先試純 Rust 的 tract，失敗了（ADR-0005）。**
`tract-onnx` 無法載入 Silero —— v4 與 v5 都含 8k/16k 的條件分支，
兩個分支輸出秩不一致，`ToTypedTranslator` 直接失敗。這是 tract 的能力邊界，
不是設定問題。

改用 `ort` 其實是**更好的架構決定**：同一個執行期之後還要服務
Paraformer-zh（S-24）與 PP-OCRv5（D4），一套推論庫服務三個用途。

**遲滯邏輯與模型推論分離。**
`SpeechGate` 是純邏輯、零相依、完整可測。用單門檻會在機率貼近臨界時
來回跳動，把一句話切成碎片 —— 有測試明確驗證遲滯區間內零狀態切換。

**內部緩衝而非要求對齊。**
Silero v4 只吃 512 樣本，但 `Segmenter` 用 20 ms（320 樣本）。
讓 VAD 內部緩衝，呼叫端不必為了模型改變粒度。

**模型缺失時降級而非失敗。**
錄音不該因為 VAD 用不了就停擺（S-25 的音檔優先原則）。
`uses_neural_vad()` 讓 UI 能提示使用者分段品質會下降。

### 踩到的坑

**manifest 裡的 URL 從來沒被驗證過。**
原本 silero 指向的 HuggingFace 路徑需要登入，`curl` 拿到的是 29 bytes 的
`Invalid username or password`，副檔名還是 `.onnx`。
**清單裡沒被實際下載過的 URL 等於沒有。** 已改用官方 repo 並補上真實雜湊，
同時加測試要求「已填雜湊的項目不得仍標記授權待審」。

**`ort` 2.0-rc 的 API 與舊版差異大**：`session.inputs` 變成 `inputs()`、
`name` 變成 `name()`、`to_array_view` 變成 `try_extract_tensor` 回傳
`(shape, slice)` 元組。

---

## 2026-09-12 (6) · 錄音編排（S-25）

### 做了什麼
348 → **376 個測試**。`padnote-recorder`（管線 + 轉錄 worker）、
接進 `NotebookSession`、FFI 曝露、端到端整合測試、可執行的示範程式。

### 為什麼這樣做

**把「音檔優先落地」做成型別層次的保證，而不是註解裡的承諾。**
`RecordingPipeline` **完全不持有 `AsrEngine`** —— 想在 `feed()` 裡呼叫模型？
沒有那個欄位可以呼叫。這讓「轉錄拖慢錄音」與「轉錄失敗丟音訊」在結構上
不可能發生，而不是靠紀律維持。這正是 Notability 最大差評的解法。

**`feed()` 內的順序不可調換。**
先把音訊寫進 Opus 檔，再做 VAD 分段。VAD 或分段出錯時，音訊已經安全了。

**開檔先於記錄 session。**
顛倒的話，當機會留下「有 session 記錄但沒有音檔」的孤兒。

**佇列溢位丟最舊的段，但音檔照寫。**
ASR 完全跟不上時，掉的只是待辨識的副本；錄音本身不受影響，
而且 `segments_dropped` 會回報給 UI 提示換小模型。

### 踩到的坑

**實際跑一次才發現的回報缺陷。**
示範程式印出「音檔時長: 0 ms」—— 因為 `recorded_audio_us()` 讀的是 pipeline，
而停止錄音後 pipeline 已被取走。單元測試沒抓到，因為它們都在錄音中查詢。
改成累計保存並補上測試。**這就是為什麼要真的跑一次，而不只是跑測試。**

**`#[cfg(test)] impl` 放在 `mod tests` 之後會觸發 clippy 的
`items_after_test_module`。**

### 外部驗證
`cargo run -p padnote-core --example record_session` 產出真實的 `.padnote` 套件，
`ffprobe` 確認音檔為 `Duration: 00:00:03.00, opus, mono` —— 完整流程的產出
是任何播放器都能開的標準檔案。

### 仍未驗證
- VAD 目前是**能量門檻法**，有背景噪音時會把冷氣聲當語音（S-26 待換 Silero）
- 背景 worker 的低優先權執行緒尚未實作（S-27，屬平台層）
- 真實 ASR 品質仍待 H2 的中文測試集

---

## 2026-09-12 (5) · 文件持久化與原生相依

### 做了什麼
325 → **348 個測試**。文件 op-log 持久化（S-23）、Opus 音訊編碼（S-13）、
whisper.cpp ASR 引擎（S-15）、PDFium 適配層（S-21）。

### 為什麼這樣做

**S-23 的範圍比原本大。**
原本只要把文字 op 落盤，但一查才發現**頁面、區塊、錄音 session 從來沒有
持久化過** —— 只有筆畫會落盤。所以做成完整的 12 種 `DocOp` 與 `open()` 重播，
而不是只補文字那一塊。

**record() 先落盤再套用。**
反過來的話，中途當機會讓記憶體與磁碟不一致，使用者看到的是
「有效果但沒存到」—— 那比直接失敗更糟。

**先實測哪些原生相依能編譯，再決定要不要寫。**
pdfium-render、audiopus、whisper-rs 都先用 probe 專案試編。能編譯才動手，
避免寫完一堆無法驗證的程式碼。

**Opus 用 ffprobe 做外部驗證。**
自己寫的測試只能證明「跟我想的一樣」。`ffprobe` 回報
`Duration: 00:00:02.00, 32 kb/s, mono` —— granule 算錯的話時長會顯示成 1/3，
這是真正獨立的驗證。

### 踩到的坑

**UniFFI 會靜默略過名為 `open` 的建構子。**
`open` 是 Swift 的存取修飾關鍵字。Rust 端編譯正常、綁定產生正常，
但 Swift 端就是看不到那個方法。改名為 `open_existing` 並加測試釘住。
**這類無聲失敗是 FFI 最危險的地方。**

**PDFium 不是執行緒安全的。**
`Pdfium` 持有的綁定既非 `Send` 也非 `Sync`，連 `thread_safe` feature 也不足以
滿足我們 trait 的約束。改成每次操作重新綁定（dlopen 有快取，成本遠低於渲染）。
更重要的影響是：**多頁渲染無法平行化**，J2 的效能預算只能靠 `PageCache`
的預抓，不能靠開執行緒。

### 誠實標記
- Opus：**已驗證**（ffprobe 外部確認）
- 文件持久化：**已驗證**（往返測試涵蓋頁面/文字/錄音/索引/墓碑）
- whisper：**編譯與錯誤路徑已測，轉錄品質未驗證**（需模型 + 中文測試集）
- PDFium：**介面與邊界檢查已測，實際解析未驗證**（需 libpdfium 執行期庫）

---

## 2026-09-12 (4) · 文字 CRDT 與 UniFFI 綁定

### 做了什麼
265 → **299 個測試**。`padnote-doc::text`（CRDT + 二進位編碼）、
文字同步端到端驗證（S-16）、`padnote-core::ffi`（UniFFI 門面）、
Swift/Kotlin 綁定產生腳本、XCFramework 建置腳本、CI 綁定閘門。

### 為什麼這樣做

**先做 CRDT 再做 UniFFI。**
CRDT 會改變 core 的 API 表面，反過來做等於要重弄一次綁定。

**自行實作 CRDT 而非引入 yrs（ADR-0004）。**
需求是純文字 —— 粗體、標題、待辦這些屬性住在 `Block` 層級，不在字元流裡。
換到的是與既有 oplog／Lamport 一致、零額外相依、每條收斂性質都有測試。

**FFI 獨立一層，不直接匯出內部型別。**
`Uuid`、`NotebookTime`、trait 物件都過不了 FFI 邊界；更重要的是，
內部重構不該逼著兩個平台的 UI 一起改。這一層是穩定契約。

**`visible_strokes` 只回傳摘要，不回傳取樣點。**
一頁數萬個點跨 FFI 邊界會很慢。渲染資料由平台層直接讀 `.strokes` 檔。

**綁定不進版控。**
與 core API 不同步的綁定比沒有更危險。改 `ffi.rs` 後跑
`scripts/generate-bindings.sh`，CI 也會驗證產得出來。

### 踩到的坑
- **併發插入的測試一開始就寫錯**：忘記讓兩端先套用自己的操作，
  結果是「兩邊各缺一半」而非不收斂。**測試本身錯了比實作錯更難發現** ——
  修正後補上「各自本地結果」的中間斷言，這樣下次失敗會指向正確的地方
- `uniffi` 的 bindgen 需要 `features = ["cli"]`，否則 `uniffi_bindgen_main` 找不到
- `#[derive(uniffi::Object)]` 的結構仍受 `missing_debug_implementations` 檢查

### 驗證結果
S-16 端到端：三站 300 次併發編輯（插入 430 字、刪除 105 字），
經二進位編碼 → 加密 → SyncEngine → 本機資料夾 → 拉取 → 解密 → 解碼 → 套用，
**三台文字完全一致、緩衝區歸零**。另含「刪除與插入交錯」「離線追平」
「同位置併發輸入兩邊都保留」「磁碟上為密文」等迴歸測試。

Swift 綁定已產生並通過 iOS SDK 語法檢查，API 為慣用的 camelCase + throws。

### 下一步
剩下的幾乎都需要原生相依或實機：PDFium、Opus、sherpa-onnx、
Apple Vision 的 `HwrEngine` 實作。

---

## 2026-09-12 (3) · 引擎、模型與 PDF 層

### 做了什麼
205 → **265 個測試**。新增 `recognize::registry`（HWR fallback 鏈）、
`core::setup`（引擎與權限中心）、`padnote-models`（下載器）、
`padnote-pdf`（介面 + LRU 頁面快取），以及機器可讀的 `models/manifest.json`。

### 為什麼這樣做

**權限與引擎狀態機放在 core 而非各平台 UI。**
「錄音要不要麥克風權限」「轉錄缺哪個模型」若寫在 Swift，Android 版要重寫一遍，
兩邊必然長歪。core 判斷、UI 只負責畫。

**`Feature::CoreNotes` 的需求清單刻意是空的。**
手寫與打字不依賴任何權限或模型 —— 全新安裝、零權限的狀態下就該能用。
這是產品定位的基石，用測試把它釘住。

**未回報過的能力預設為 `Unsupported` 而非 `Ready`。**
樂觀假設會讓功能在執行期才爆炸，那時已經來不及給使用者好的錯誤訊息。

**模型清單用 `"sha256": "pending"` 而不是填假雜湊。**
填佔位雜湊看起來「完成度高」，但有人會誤以為可以出貨。現在的行為是
**下載器直接拒絕**，而且有測試確保它連網路請求都不發出。

**網路 IO 抽象成 `Fetcher` trait。**
續傳與驗證邏輯是最容易寫錯、又最難在真機上重現的部分。抽象掉之後，
「伺服器不支援 Range」「回傳空資料」「本機半檔比宣告還大」這些情境
全部可以離線測。

### 踩到的坑
- `OpenOptions::create(true).write(true)` 未指定 `truncate` 會觸發 clippy 警告；
  續傳情境必須明示 `truncate(false)`，否則會毀掉既有進度
- `RenderKey` 用 f32 當 HashMap key 不可行，改存 ×100 的整數

### 下一步
剩下的幾乎都需要原生相依或實機：UniFFI 綁定（S-12）可以做，
PDFium / Opus / sherpa-onnx（S-21/S-13/S-15）能編譯但**無法在此驗證正確性**。

---

## 2026-09-12 (2) · 核心邏輯層

### 做了什麼
新增 6 個實作完整的模組，workspace 從 55 → **205 個測試**：
storage（套件/blob）、ink::geometry、search（CJK 索引）、asr::pipeline、
crypto（信封加密 + 復原碼）、sync::engine、export（MD/SVG）、
core::app（NotebookSession 門面）。

同時建立 `STATE.md` / `DEVLOG.md` / `TODO.md` 交接文件。

### 為什麼這樣做

**先把純邏輯層做完，UI 與模型整合往後放。**
使用者的方針是「先把所有功能建起來再 debug」。純 Rust 邏輯當場可驗證，
而 UI 與 ASR 模型需要實機迭代 —— 先做能驗證的，把不能驗證的變成明確的接手點。

**搜尋自己實作而不直接上 Tantivy。**
中文斷詞才是難點，不是倒排索引。bigram 免詞典、免模型、對未登錄詞（「特徵值」）
不會切錯，代價只是索引較大 —— 本機單機搜尋完全可接受。
`SearchIndex` 介面不變，P2 想換 Tantivy 隨時可以。

**加密用信封而非直接以密語加密內容。**
換密語時只需重新包裹 DEK，不必重新加密整本筆記。測試明確驗證了這點。

### 踩到的坑

**`CloudProvider::list` 的語意錯了。**
原本實作成「列單層目錄」，導致 `SyncEngine::pull` 永遠看不到其他裝置的目錄，
5 個測試同時失敗。正確語意是**依前綴遞迴列舉**（物件儲存語意）。已修正並補測試。

**加密 chunk 少了框架邊界 —— 這是真實缺陷。**
兩次 push 之間只 pull 一次時，讀取範圍會橫跨兩個獨立密文塊，解密必然失敗。
加上 `u32` 長度前綴解決，並讓讀取端只消耗**完整框架**，
寫到一半當機的尾巴留待下次補齊而非當成損毀丟棄。`format-spec.md` §7.1 已更新。

**`b"中文"` 不是合法的 byte string。** 要用 `"中文".as_bytes()`。

### 下一步
S-06/S-10/S-12（辨識註冊表、PDFium、UniFFI 綁定），
以及 S-13/S-15（Opus、ASR 引擎）—— 後者需引入原生相依。

---

## 2026-09-12 · M0 工程地基

### 做了什麼
- `docs/format-spec.md` v0.1 定稿
- Rust workspace 11 crates，55 測試通過、clippy 零警告
- CI：三平台 fmt/clippy/test + cargo-deny + 格式相容性
- S3 同步收斂驗證 **Go**；S4 授權稽核完成
- S1（Swift 墨跡 spike）與 S2（CER 評測工具）程式就緒，待硬體與資料

### 為什麼這樣做

**先做 format-spec 而非先寫 UI。**
統一時間軸是 C1/C4/A10/B6 四個功能的共同地基，事後更動等於重寫文件層。
在還沒有任何程式依賴它之前定稿，成本最低。

**S3 排在 S1 之前完成。**
風險登記簿上 S3 是唯一標「影響極高」的項目 —— 它決定整個「用雲端硬碟同步」
的架構是否成立。而且它純軟體、當場可驗證，不像 S1 要等硬體。先殲滅可驗證的最大風險。

**筆畫不進 CRDT（ADR-0002）。**
一筆畫數百個點，全進 CRDT 會讓 op 爆炸。改用 append-only + 墓碑 —— 新增與刪除
天生可交換冪等，這正是收斂所需的全部性質，不需要完整 CRDT 的機制。

**刻意先不引入外部相依。**
M0 全程零 crates.io 相依，確保任何環境都能 build。等真正需要（serde/sha2）
才引入，且每個都要過 `deny.toml` 白名單。

### 踩到的坑
- 自訂 `Display` 用 `f.write_str` 會忽略 `{:<12}` 寬度 → 必須用 `f.pad()`
- doc comment 裡放真實 Tab 會觸發 clippy 警告
- `cargo` workspace 成員缺 `src/lib.rs` 會讓整個 workspace 無法載入

### 下一步
依「先把功能全部建起來、之後再 debug」的方針，推進 storage / doc / search /
asr 編排 / export 等純邏輯層。需要實機的一律記進 `TODO.md`。
