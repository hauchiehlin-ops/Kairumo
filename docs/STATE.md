# 專案狀態與交接記憶

> **每次開發階段開始前先讀這份。** 目的是讓不同的開發階段／不同的人／不同的 AI
> 不必重新推導已經決定過的事。
> 最後更新：2026-09-29

---

## 這是什麼專案

Kairumo —— 手寫、打字、錄音轉文字三合一的筆記 App。
技術套件與開放格式暫保留 `padnote-*` / `.padnote` 命名，避免破壞既有 crate、
文件格式與工具鏈相容性。品牌圖標位於 `assets/brand/kairumo-icon-v1.png`。
**免費 · 全開源（一個明示例外）· 無後端伺服器 · 本地優先 · 同步走使用者自己的雲端。**

切入點來自市調結論：**沒有任何競品同時做到一流手寫 + 一流錄音轉錄 + 中文 AI + 資料主權 + 免費。**

## 不要重新討論的事（已拍板，見 architecture.md §0）

| 決策 | 結論 |
|---|---|
| D1 平台 | Phase 1 iPadOS/macOS 優先；核心 Rust，為跨平台鋪路 |
| D2 HWR | **接受** Apple Vision / ML Kit 等免費非開源系統 API 作為例外 |
| D3/D11 雲端 | Google Drive `appDataFolder` 作正式自動同步；本機資料夾保留為手動備份/匯入匯出 |
| D4 模型 | 按需下載，HF / GitHub Releases + SHA-256 + 續傳 |
| D5 無後端 | 即時協作／Web 版／遙測／金鑰託管 = **產品定位，非待辦** |
| D6 PDF | PDFium (BSD-3)。**MuPDF 是 AGPL，已在 deny.toml 封鎖** |

## 三條不可違反的架構不變式

1. **Append-only**：同步檔案只新增不修改；每裝置只寫自己 `device_id` 的檔案。
   ⇒ 檔案層級衝突在數學上不可能發生。破壞這條 = 使用者資料損毀。
2. **統一時間軸**：筆畫、文字、錄音、轉錄詞全部用 `notebook_time_us` 定位。
   ⇒ 改動它 = 所有既有筆記的時間資料失效。
3. **原始取樣點**：筆畫存原始點，平滑/擬合只在渲染期做。
   ⇒ 預測筆跡（predicted touches）**永不寫入持久化資料**。

## 常犯的錯（已經踩過或已預見）

- ❌ 把預測點寫進 `.padnote` —— 那是視覺補償，不是真實輸入
- ❌ `presentsWithTransaction = true` —— 直覺上正確，實際多一整幀延遲
- ❌ 只讀 `touches.first` —— 120Hz Pencil 每幀多個取樣，必須用 `coalescedTouches`
- ❌ 把筆畫放進 CRDT —— op 數量爆炸，見 ADR-0002
- ❌ 混合場景算 CER —— 安靜語句會把嘈雜場景的失敗平均掉
- ❌ 引入 MuPDF —— AGPL 污染
- ❌ 平台端自己決定同步輪詢間隔 —— 節奏在核心的 `SyncScheduler`，
  平台只負責「發生了什麼」與「現在該不該跑」。計時器照
  `syncHeartbeatIntervalMs()`（最快的那一檔），不是照 `PERIODIC_MS`
- ❌ **把「同步慢」當成輪詢間隔的問題** —— 慢在結構：整庫一輪的成本跟筆記本
  數量成正比，一輪跑完才能跑下一輪。調短週期只會讓整輪更常空跑。開著的那一本走
  焦點通道（`padnote_sync::focus`），整庫通道降級成背景維護
- ❌ 焦點通道與整庫通道各拿一個 `FfiSyncSession` —— 兩份快照、兩個游標，
  一邊剛建立的檔案另一邊不知道，於是再建一次，Drive 允許同名檔案，雲端多一份重複。
  行程內**只有一個**（`CloudSync.makeSession`）
- ❌ 拿 `changes.list` 的原始變更數當「對方動了」—— 自己剛上傳的檔案也會出現在裡面。
  要用 `FfiRefreshResult.effective`（真的改變了快照的）
- ❌ 兩條通道同時動同一本筆記本的套件目錄 —— 要拿每本一把的鎖
  （`notebook_lock_*`）。整庫通道遇到就**略過**，但匯入要**等**（略過的話
  那份下載到的內容就沒有人會再去匯入）
- ❌ 區網雙方都主動連 —— 「保留一條、關掉另一條」在雙方同時做時會挑到不同的那條，
  兩條都關了。由裝置 id 較小的一方連（`should_initiate`）
- ❌ 區網收到的檔名不驗證就寫進套件 —— 那是網路輸入，`../` 會寫到套件外面。
  `LanStore::write` 的實作端要再驗一次
- ❌ 區網要回**自己這台裝置**寫的檔案，或已被本機壓實吃掉的碎檔 —— 壓實與下載會
  形成死循環（與 Drive 下載路徑同一條規則，`LanStore::accepts`）
- ❌ iOS 瀏覽 Bonjour 卻沒在 Info.plist 宣告 `NSBonjourServices` —— `NWBrowser`
  不報錯，只是永遠找不到任何裝置，而那與「附近沒有裝置」長得一模一樣
- ❌ 編輯器把增量寫進套件的去抖動放太長 —— 那是「另一台看得到」之前必經的第一段
  （1.2 秒），再加上排程器的去抖動，一筆畫要兩秒多才開始往外送
- ❌ Android 編輯器不反應遠端更新 —— 下載的 oplog 已寫進套件，但記憶體裡的
  session 還是同步前的。要重開 session，而且**等這一筆畫完**再換
- ❌ 把「跑完一輪」當成「對方在改」—— 空轉是常態，這樣快檔會永遠開著
- ❌ 自訂 `Display` 用 `write_str` —— 會忽略 `{:<12}` 的寬度指定，要用 `f.pad()`
- ❌ `CloudProvider::list` 當成「列單層目錄」—— 正確語意是**依前綴遞迴**
- ❌ 加密 chunk 不加框架邊界 —— 跨兩次 push 的讀取範圍會解不開
- ❌ 能力狀態預設為 Ready —— 未回報者一律當 `Unsupported`，否則執行期才爆
- ❌ 模型清單填假雜湊佔位 —— 用 `"pending"` 讓下載器直接拒絕
- ❌ 併發測試忘記讓兩端先套用自己的操作 —— 會誤判成不收斂
- ❌ 平台層把預測筆跡送進 `add_stroke` —— 那是視覺補償，不是真實輸入
- ❌ UniFFI 建構子命名為 `open` —— Swift 關鍵字，**會被靜默略過**
- ❌ 以為 PDFium 可以多執行緒渲染 —— 它的 C API 不是執行緒安全的
- ❌ 先套用再落盤 —— 當機會造成「有效果但沒存到」
- ❌ 只跑測試不跑程式 —— `recorded_audio_us` 停止後歸零，只有真的跑一次才發現
- ❌ `#[cfg(test)] impl` 放在 `mod tests` 之後 —— clippy 會擋
- ❌ 相信 manifest 裡沒下載驗證過的 URL —— 可能拿到 29 bytes 的登入錯誤頁
- ❌ 以為純 Rust 的 tract 能跑 Silero —— 它處理不了模型裡的 `If` 節點
- ❌ 把整段式 encoder 當串流用 —— 匯出的 Paraformer encoder 沒有 cache 輸入
- ❌ 核心的清單與畫面上實際有的東西各長各的 —— 拿它做設定畫面，一半的開關
  控制不到東西，另一半該關的關不掉（S-261 的工具列清單）
- ❌ 會同步到別台裝置的 JSON 用 `unwrap_or_default()` 解析 —— 舊版讀到新版
  多出來的一個名字，整份設定就回到預設，而使用者沒有動過任何東西
- ❌ 新設定帶著「比較好的預設」上線 —— 那等於升級之後有東西從畫面上消失，
  而使用者沒有動過設定
- ❌ 識別字用字串插值組出來 —— 跨平台對照閘門掃的是字面值，插值它看不見
- ❌ 以為 SwiftUI `Menu` 的項目不在無障礙樹裡 —— 它們在，只是
  `.accessibilityIdentifier` 沒跟進 UIKit 的 `UIAction`，**標籤還在**
- ❌ 診斷工具自己有上限還拿它下結論 —— `presentIdentifiers` 掃到 20 個就停，
  於是「前 20 個都不是選單項目」被讀成「選單項目一個都沒有」
- ❌ 用 `frame.intersects(視窗)` 判斷「在畫面上」—— 被邊緣切掉一半的東西
  也會過，然後被誤判成「點不到」。要用 `contains`
- ❌ 本機與 CI 跑不同機型的 UI 測試 —— 螢幕尺寸不同，被切掉的控制項就不同，
  本機全綠而 CI 紅得莫名其妙
- ❌ **UI 測試只跑 iPhone** —— iPad 走的是另一條版面分支，而它一啟動就當掉
  了都沒有人知道（`BGTaskScheduler` 註冊時機，見下一條）
- ❌ `BGTaskScheduler.register` 放在 `scenePhase` 變 active 之後 ——
  它必須在 App 啟動完成**前**註冊，晚一步就是未捕捉的 ObjC 例外＝直接當掉
- ❌ UI 測試用 `descendants(matching: .any)` 反覆掃整棵樹 —— XCTest 每次
  查詢都發 signpost，量大到系統把行程**隔離**，然後在 strcmp(NULL) 上 SIGSEGV
- ❌ 用 `find` 抓 DerivedData 裡的 .app —— 機器上可能有多個，抓到舊的那個
  症狀是「修了沒用」，而那會讓人去改一個本來就對的東西。
  用 `xcodebuild -showBuildSettings` 問 BUILT_PRODUCTS_DIR
- ❌ 連續跑多輪 UI 測試把模擬器操到拒絕啟動 —— 錯誤訊息是
  `Application failed preflight checks`，看起來完全像 App 有問題
- ❌ 先轉繁體再標點 —— ct-punc 的詞表是簡體的，順序反了會大量 `<unk>`
- ❌ 相信自己寫的測試期望 —— CIF 那兩條是測試錯、實作對
- ❌ `cargo add zhconv` —— 預設綁 MediaWiki 的 **GPL-2.0** 轉換表，
  必須 `default-features = false, features = ["opencc"]`
- ❌ PDF 標註忘記翻轉 Y 軸 —— **在自己的 App 裡看起來正常**，
  因為匯出與匯入用了同一個錯誤轉換；只有在別的 App 打開才會發現
- ❌ 解析 docx 只讀第一個 run —— 粗體會把段落切成多個 run，句子會殘缺
- ❌ 逐詞做簡繁轉換 —— 詞組上下文會消失（「下周三」的「周」轉不成「週」）
- ❌ `project.yml` 沒宣告 `INFOPLIST_FILE` —— `xcodegen generate` 會把 pbxproj 裡
  手加的那一行抹掉，`apple/Info.plist` 整份不進 bundle。**沒有編譯錯誤**：
  OAuth 回不來、Catalyst 的文件視窗按了沒反應
- ❌ Catalyst 少了 `UIApplicationSupportsMultipleScenes` —— `openWindow(id:)` 靜默失效
- ❌ 種子筆記只寫中繼資料 —— 「範例」打開是一片白，比沒有範例更糟
- ❌ 插入物件時忘記設 `pageIndex` —— 物件落在第 1 頁，使用者以為沒插進去
- ❌ SwiftUI 的 `Grid` 放進雙向 `ScrollView` —— **Catalyst 上會塌成一格**，
  iPad 上卻正常，所以會活很久
- ❌ 以為 `.pencilOnly` 等於「不能畫」—— 它擋手指不擋 Pencil。要「誰都不能畫」
  得關掉 `drawingGestureRecognizer`（Android 是在 `onTouchEvent` 讓出事件）
- ❌ 縮圖／匯出的合成器漏畫某個型別 —— 畫布上有、預覽裡沒有，
  使用者會以為內容掉了。加新型別時七個 `for` 迴圈要一起加
- ❌ 改 `ShapeKind` 既有的 u8 編號 —— 那些號碼在使用者的 `.padnote` 裡，
  動一個就是把他的圖形換成別的形狀。只能往後加
- ❌ 自適應圖示的前景直接用整張原圖 —— 系統遮罩會把原圖自己的圓角底板
  切出一圈缺角
- ❌ 拿 `ShapeKind` 的識別字當顯示名稱 —— 中文介面會出現「arrowblockright」
- ❌ Kotlin 寫 `x?.let { null } ?: 錯誤訊息` —— 成功時那個運算式是 null，
  而 `null ?: e` 就是 e：成功卻回報失敗
- ❌ 跨筆記本「引用」音檔 —— 套件是同步的單位，另一台只會拿到一張播不出來的卡片
- ❌ 兩個平台各自問系統 API 算錄音長度 —— 同一段錄音顯示不同秒數，
  使用者會以為同步壞了。長度走核心算
- ❌ Android 的動作卡用固定寬度 —— 手機上會疊成幾顆佔半個螢幕的大按鈕，
  同一個 App 在兩台裝置上長得像兩個產品
- ❌ 兩個模式的工具同時列著 —— 使用者在打字模式下看到一整排筆，
  點下去卻畫不出東西。第二排要跟著模式換
- ❌ 只看 `cargo check` 的錯誤行就以為過了 —— CI 是 `RUSTFLAGS: -D warnings`，
  警告在那裡就是錯誤。本機要跑
  `RUSTFLAGS="-D warnings" cargo clippy --workspace --all-targets`
- ❌ 用 `grep -E "^error"` 過濾建置輸出 —— 會把警告濾掉，而 CI 不會
- ❌ 用 `grep 'l("'` 之類的字面樣式盤點功能 —— 參數化的呼叫（`l(key)`）
  會整段漏掉。S-63 就是這樣誤判 Android「少了四個符號盤」，其實一直都有
- ❌ 相信 Gradle 說的 instrumented 測試失敗 —— 它的串流被截斷時會把當下
  在跑的那一條記成 FAILED。先看裝置的 logcat（`run finished: N tests`）
  與 crash buffer，再決定要不要改程式
- ❌ 靠註解維持兩個平台的資料一致（「與 Apple 端逐字相同」）—— 註解攔不住
  任何東西。要一致就下沉到核心
- ❌ 以為 `.help(...)` 等於無障礙標籤 —— 它給的是**提示**，標籤仍然會退回
  SF Symbol 的名字（VoiceOver 念「arrow uturn backward」而不是「復原」）
- ❌ 相信「編得過就會動」的快捷鍵。SwiftUI 的 `keyboardShortcut` 與掛在
  容器上的 `UIKeyCommand` **都不會報錯，也都沒有作用**；要按下去才知道
- ❌ 讓多個 `UIKeyCommand` 共用同一個 selector —— UIKit 會算出重複的選單
  識別碼並在 `buildMenu` 當下丟例外，崩潰堆疊只停在 UIKitCore
- ❌ 跟系統搶鍵位。⌘N 是「新增視窗」（`requestNewScene:`）。走 delegate 的
  `buildMenu` 時 UIKit 把**整組**命令默默丟掉（連沒衝突的 ⌘F 一起消失），
  走 `.commands` 時同一個衝突直接丟例外。新增類的動作用 ⇧⌘N
- ❌ 用 delegate 的 `buildMenu` 往「檔案」選單插東西 —— 那個選單整個是
  SwiftUI 從 `WindowGroup` 產生的，delegate 先跑、它後重建，插進去的
  會被蓋掉。「顯示」選單它不碰，插得進去
- ❌ 種子／遷移只在「資料是空的」時才跑 —— 舊版留下的**空殼**不是空的，
  補內容那個分支一輩子不會執行。實機七個容器裡有四個是
  「歡迎使用 Kairumo：23 頁、0 個物件」
- ❌ 在 sheet 裡用 `horizontalSizeClass` 判斷「是不是手機」—— iPad 的
  form sheet 自己就是 compact 寬度，整台 iPad 會被判成手機。要問裝置
- ❌ 以為 `preferredContentSize` 調得動 sheet —— iOS 18 的
  `PresentationHostingController` 不理它（值套進去了，外框紋風不動）。
  `presentationSizing(.fitted)` 則會把整張表攤成全螢幕。**會動的是 detent**
- ❌ 兩個獨立的選擇同時生效 —— 「文件範本」與「紙張」各選各的，
  於是公文「簽」鋪在行動端線框紙上，本文底下壓著兩個手機外框。
  資料裡本來就有 `pageStyle`，兩端卻都只解析、不使用
- ❌ 會變的東西排在螢幕外 —— 「主題分類」換的是下面那份清單，而清單被排在
  一整棵可展開的樹之後。使用者按下去看不到反應，結論就是「這個壞了」
- ❌ 為每一種附件各寫一份「刪掉這一頁的、後面的往前移」—— 新增型別時
  沒有人記得回來加。表格、形狀、連接線與錄音整組漏掉，症狀是
  「刪了一頁，那一頁的表格卻還在，而且跑到別頁去了」
- ❌ 刪頁只改 `pageCount` 不縮 `pagesData` —— 匯出時那一頁會復活
- ❌ 畫出來的頁面框線沒有人強制 —— `fitsInPage`／`clamp` 寫好了卻從來
  沒被呼叫過。使用者在框線外寫的東西，匯出的 PDF 裡整段不見
- ❌ 畫布把可用寬度吃滿而頁面只有 800pt —— 右邊那塊空白**在頁面之外**，
  寫上去不會被印出來。側欄一收更明顯，看起來像畫布破了一個洞
- ❌ 同一組插入功能放兩個入口（工具列的「更多」與右上角的選單）——
  右上角那個是嚴格超集，左下角那份只是讓人多一個地方要找
- ❌ 插入頁面與複製頁面**也**各自漏掉了附件的頁碼平移 —— 與刪頁同一個
  病灶。`insertPage` 只做了五種（表格、形狀、連接線、錄音整組漏掉），
  `duplicatePage` 一種都沒做：複製第 1 頁之後，第 2 頁以後的東西全部
  留在舊頁碼上，於是落到那張複本上，而原本那一頁空了
- ❌ 唯一能「移出資料夾」的落點寫成 `if !rootNotes.isEmpty` —— 把最後
  一本筆記歸檔之後，落點跟著消失，再也拖不出來。而落點只有標題列那條
  26pt 的細長條，用手指拖著瞄，瞄不中的表現是「放開之後什麼也沒發生」
- ❌ 在 `.environment(...)` 的**同一個 View 結構**裡用 `@Environment`
  讀那個值 —— 讀到的永遠是預設值，因為那個修飾子只影響子樹。編得過、
  跑起來縮圖永遠停在同一個寬度，而看起來像「按鈕沒作用」
- ❌ 一頁上的操作只掛在卡片右上角那顆 `...` —— 縮圖縮小時它只有十幾點寬，
  而且看起來像裝飾。真正會被嘗試的手勢是長按與右鍵
- ❌ 版面用「每種紙一段繪圖程式碼」寫 —— Apple 有十三段、Android 一段都沒有，
  同一本筆記在兩台裝置上長得不一樣。**底紋是重複的材質（留在平台端鋪），
  版面是這張紙的結構（核心送圖元）** —— 分錯邊的代價：5mm 點陣是兩千多個點，
  一顆顆送過 FFI 只是浪費
- ❌ 版面用畫布高度算而不是頁面高度 —— 畫布比頁面高（它要捲動），
  四象限的十字會落在頁面下緣之外：畫面上看得到，列印出來不在紙上
- ❌ 同一份版面在畫布與縮圖各畫一次 —— 側欄縮圖上看不到康乃爾的分區線，
  使用者分不出哪一頁是哪一種紙
- ❌ `.buttonStyle(.plain)` 的按鈕沒有 `.contentShape(Rectangle())` ——
  可以按的只有「文字與圖示的筆畫」，那一圈底色是純裝飾。實機上按下去
  完全沒有反應，而畫面上它看起來就是一顆按鈕
- ❌ 跨筆記本複製物件時沿用原本的 `id` —— 看起來沒事，直到使用者把那一頁
  再複製回來：同一本筆記裡有兩個相同 id 的物件，而選取、刪除、堆疊順序
  全部是照 id 找的，點其中一個、另一個跟著動
- ❌ 搬移多頁時由小到大刪來源 —— 刪掉第 1 頁之後第 3 頁已經變成第 2 頁，
  接著刪「第 3 頁」就刪到了別人。**由大到小**不是偏好，是正確性
- ❌ 樣板做成「整本一個」—— 一本會議紀錄的第一頁想用四象限、後面想用橫線，
  這件事以前只能靠「另外開一本筆記」。逐頁的欄位（`pagePaperIds`）要跟著
  插入／刪除／搬動／複製／跨本轉移一起維護，漏掉其中一條的症狀是
  「我搬了一頁，它的版面留在原地」
- ❌ 把 `@MainActor` 與被註解的宣告拆開 —— 在屬性與宣告之間插入新的程式碼，
  那個屬性就落到新宣告上了（症狀：`has multiple actor-isolation attributes`）。
  與 Android 端 `@OptIn` 被插斷是同一種錯
- ❌ 以為捏合縮放「本來就有」—— `PKCanvasView` 是 scroll view，而
  `minimumZoomScale`/`maximumZoomScale` 預設**都是 1.0**（不准縮放）。
  這兩行從來沒設過，所以捏合在任何 Apple 裝置上都沒有反應
- ❌ Android 整頁模式的畫布沒有捲動也沒有縮放 —— 連續模式只是剛好外面
  包了 `LazyColumn`。「手指沒辦法捲動」不是設定錯了，是根本沒做
- ❌ 夾平移範圍時把「內容尺寸」填成視窗尺寸 —— `scaled <= viewport`
  永遠成立、可拖範圍一律 0，畫面完全不動，看起來像手勢沒接上
- ❌ `graphicsLayer` 平移不加 `clip = true` —— 內容會畫到範圍外蓋住工具列
- ❌ 在 `open()` 裡「順便把第一頁換成指定的紙張」—— 一次新增筆記會呼叫
  `open()` 三次，其中兩次帶的是預設值，第一次設好的紙張會被換回去。
  **核心建立筆記本時已經先放了一頁 `Lined`**，所以 `firstPageId() ?: addPage()`
  永遠走前半段，使用者挑的紙張從來沒有生效過
- ❌ 用完整套件名呼叫 Kotlin 的擴充函式 —— 編不過，一定要 import
- ❌ Compose 裡 `fillMaxSize()` 之後再 `widthIn(max:)` —— **沒有作用**，
  因為 `fillMaxSize` 把最小寬度也設成父層最大值，最小值贏。
  要先 `widthIn(max:)` 再 `fillMaxWidth()`
- ❌ 以為「協同＝同一個 Wi-Fi」—— 核心一直允許 `wss://` 連任何主機，
  也允許 Tailscale 的 100.64/10。擋的只有**公開網路上的明文 ws://**。
  介面與手冊把能力講窄了，使用者就永遠不會發現
- ❌ 側欄一律並排 —— iPhone 上 280pt 的側欄配 393pt 的螢幕，畫布只剩
  113pt，比工具列還窄。並排與否要看**實際寬度**，不是尺寸級別查表
- ❌ 解不開的訊息回傳「信封」而不是 nil —— 加密 payload 是
  `{"ciphertext": ...}`，下游每個 `guard let page_index` 都會靜靜 return。
  症狀：兩台都顯示已連線、成員清單也對，**對方畫的東西永遠不出現**
- ❌ 把「套用遠端資料」整段包在 `if let canvas = canvasView` 裡 ——
  那個 @State 是在 `makeUIView` 裡回填的，寫入會被 SwiftUI 丟掉。
  落盤與畫面是兩件事：先無條件落盤，畫布在不在都不影響資料
- ❌ `presentationDetents` 不給 selection —— 系統挑**最小**的那一個，
  於是每張表都開在半高，而主要動作都在最下面（看起來像按鈕被切掉）
- ❌ 版面估算「估剛好」—— 估矮了不會擠，是**最後一行被裁掉補刪節號**，
  而那看起來像「範本本來就只寫這麼多」。段落間距、字寬、方塊留白都要算
- ❌ 同一個入口放兩個地方 —— 首頁頭像選單四個項目全部在別處已經有了，
  多的那份不增加能力，只多一個地方要找
- ❌ `set -u` 下展開空陣列 `"${ARR[@]}"` —— macOS 內建的 bash 3.2 會當成
  未設定變數直接中止。要寫 `${ARR[@]+"${ARR[@]}"}`
- ❌ 用整個 scheme 跑來做「反向驗證」（故意改壞、看測試有沒有抓到）——
  Catalyst 上 UI 測試本來就會失敗，`TEST FAILED` 根本不是你的測試抓到的。
  要用 `-only-testing:` 指到那一個類別
- ❌ 加了新測試檔卻沒重跑 `xcodegen` —— 測試**不會被執行**，而整體是綠的
  （`Executed 0 tests` 藏在幾十行輸出裡）
- ✅ Catalyst 的無障礙樹只到外層：選單列讀得到、筆記卡片點得開，但面板
  內容是空的。點不到也讀不到時，改用 `ImageRenderer` 把畫面**算繪出來量**
- ✅ Android 的快捷鍵可以用 adb 實按驗完整段（`input keycombination
  CTRL_LEFT KEYCODE_E`）—— 數字鍵要寫 `KEYCODE_3`，直接寫 `3` 會被系統
  當成別的東西，App 會莫名其妙退到背景
- ✅ 快捷鍵要驗**兩段**（系統有沒有送到、送到之後有沒有反應）。模擬器沒有
  硬體鍵盤，但 **Mac Catalyst 的選單列可以**：啟動就會建構選單，用
  AppleScript 讀得到項目與鍵位，也點得下去看處理常式有沒有被呼叫
- ❌ 把「畫在紙上的顏色」襯在介面底色上。墨黑 `#1C1F24` 對上深色卡片底
  `#1C1E1E`，那顆色票在深色模式下整個看不見。色票要襯一張白紙 ——
  順帶也才是它在頁面上真正的樣子
- ❌ 只靠測試判斷版面對不對 —— 把成品**畫出來看**。S-61 的範本測試全綠，
  一算繪就看到不換行、表格整張不見、Markdown 星號原樣印出三個問題
- ❌ 以為 `format_pdf_text` 的半形字是半形 —— 整段只要有一個非 ASCII 字元，
  整段走 CJK 字型，數字與英文也照全形前進。估寬要跟著切換（`glyph_width`）
- ❌ 新增一種畫布物件卻沒有在 `NotebookPackageBridge` 兩邊都接上 ——
  表格漏了，於是 Apple 的表格從來沒進過 `.padnote`，而畫面上還在
- ❌ 用「有沒有暗像素」判斷字有沒有畫出來 —— 灰條、豆腐框（▯）與真字形
  三者都有墨。要問**筆畫密度**：「一」與「鬱」墨量差 6.8 倍才是真字形
- ❌ 在共用手冊裡寫「某某平台沒有某功能」—— 六個語系所有平台共用一份，
  而且那句話在該平台補上功能的那天就變成謊話。改寫成「你這台裝置有沒有」
- ❌ 加了不是筆刷的新工具（套索）卻沒更新 `everyBrushMapsToACoreTool...`
  —— 那條測試會把新工具誤判成「漏接核心」
- ❌ 以為 `page.blocks()` 就是一頁的全部 —— 形狀與連接線住在**物件樹**裡，
  只走 blocks 的算繪會少掉整張流程圖
- ❌ 以為 Paraformer 的串流是靠 encoder cache —— 官方匯出本來就沒有 cache 輸入，
  分塊狀態封在圖內，目前只能段級串流
- ❌ 以為「安裝時就能要到權限」—— iOS 與 Android 13+ 都不會在安裝時跳任何
  對話框，而系統的權限對話框**一個 App 一輩子只跳一次**。能做的是第一次
  打開時把話講清楚並當場給按鈕；已被拒絕過的話唯一還走得通的路是設定頁
- ❌ 在 Catalyst 上想用截圖或 AX 驗畫面 —— AX 樹是空的，截圖會抓到別的視窗。
  **改用 iOS 模擬器**：`xcrun simctl io <udid> screenshot` 拍的一定是那台
  模擬器，不跟視窗管理員打架，而且同一份程式碼跑的是同一套 SwiftUI
- ❌ 把 `didSet` 掛在 `@State` 上 —— 透過 binding（`$foo`）改值時不會觸發，
  結果是「用某些 UI 改會記到、用另一些不會」。要用 `.onChange(of:)`
- ✅ 硬體事件驗不到時，把**規則**抽成純函式來驗。Apple Pencil 雙擊要實體
  二代筆、觸控筆側鍵要實體筆（`adb input` 送不出 `buttonState`）。不抽出來
  的話那段邏輯就是完全沒驗過 —— 而「切過去」容易寫對，「切回哪裡」才是
  會錯的地方
- ❌ Android 跨 App 拖放忘了 `requestDragAndDropPermissions` —— 拖進來的 URI
  預設讀不到，`openInputStream` 丟 SecurityException，症狀是「從相簿拖過來
  什麼也沒發生」，畫面上沒有任何提示指向這裡

- ❌ 以為「格式加一個欄位就得升版本號」—— 記錄自帶長度、而讀取器照長度
  跳過去的話，**點之後多出來的位元組舊讀取器本來就會忽略**。升版本號的代價
  是舊裝置直接拒絕整個檔案（見 `EXT_ROLL` 的延伸區塊做法）
- ❌ 把「硬體回報得出來」當成「存得下來」—— `UITouch` 有 `rollAngle`，
  但 `PKStrokePoint` 沒有。PencilKit 自己把觸控收成筆畫，中間不經過我們，
  沒有任何地方能把角度對應回某一個控制點
- ❌ `UIHoverGestureRecognizer` 忘了設 `allowedTouchTypes` 含 `.pencil`
  —— 預設只認滑鼠指標，觸控筆懸停時整個 recognizer 不會被呼叫，而且不會有
  任何錯誤，看起來就只是「懸停沒有做」
- ❌ 把「這台裝置沒有這個功能」與「暫時失敗」混成一種錯誤 —— 前者的人會
  一直按重試。`ModelNotLoaded` 與 `Backend` 分開就是為了這件事
- ✅ 同一張規則表要下沉核心。S-67 當時在 Swift 與 Kotlin 各寫了一份筆身
  按鍵規則，兩份很快就會分家 —— 同一支筆在兩台裝置上行為不同，而使用者買的
  是同一支筆

- ❌ **浮動編輯面板掛在畫布內部、沒給層級**（2026-10-02 修）—— 手寫模式下
  PencilKit 畫布（zIndex 2）、打字模式下全頁文字輸入層（2）與物件層（3）都在它上面，
  點關閉鈕等於在畫布上畫一筆或新增文字方塊：症狀是「編輯視窗出現了卻關不掉」。
  連續頁面模式根本不走那一段程式，症狀是「編輯鈕沒有作用」。面板現在掛在
  `canvasWorkArea`（兩種模式共用）的最上層（`objectEditPanels`）
- ❌ 「單擊選取」寫在 `DragGesture(minimumDistance: 5)` 的 `onEnded` 位移 < 4 分支裡
  —— 那條路徑永遠走不到，形狀因此**從來選不起來**，縮放／旋轉／樣式把手也就都出不來。
  選取要有自己的 `.onTapGesture`
- ❌ 以為 `translate_object`／`scale_object`／`rotate_object` 是**疊加**。底下是
  `SetObjectTransform`，後一次**取代**前一次：Android 拖曳每一幀呼叫一次平移，重開之後
  只剩最後一幀的位移；縮放後再旋轉，縮放就不見了。要存「縮放＋旋轉＋位移」用
  `set_object_transform`（完整矩陣，2026-10-02 新增的 FFI）
- ❌ 核心的形狀物件建立之後**沒有「改外框／文字／顏色」的 API**，所以形狀的樣式、
  連接線的連接點與端點樣式放在**逐物件信封**（`shapestyle`／`connstyle` 衍生圖片區塊）；
  位置、大小、旋轉走物件變換。不要放回筆記本中繼資料 —— 那是整本一個暫存器（最後寫入者贏），
  兩台裝置改不同形狀會互相覆蓋
- ❌ 多個 `NotebookMeta` 實例各自把**整份** `root` 寫回去 —— 後寫的洗掉先寫的
  （編輯器本體、連續模式每一頁、形狀儲存各有一個）。現在落盤只寫「自己動過的鍵」，
  其餘以磁碟上最新的為準（Android `NotebookMeta.flush`）
- ❌ Compose 把手放在父容器範圍**外面**（負的偏移）—— 命中測試只把事件交給落在
  父容器範圍內的子節點，那一塊就點不到，而且只在某些角度才點不到。形狀的把手
  全部畫在「外層多留一圈邊」的正座標裡（`HANDLE_MARGIN`）
- ❌ `AlertDialog` 的 `text` 槽是 **Box**：`Column(...)` 後面直接放 `DialogResizeHandle`
  兩個兄弟會疊在一起，把手蓋住內容最上面 24dp（那一排點不到）。一律包進同一個 `Column`
- ❌ `pointerInput` 區塊裡讀「目前」的物件再加一小步 —— 兩幀之間還沒重組時「目前」
  是舊的，每一步都從同一個起點算起，結果是拖了沒動。要用「手勢開始時的物件 ＋ 累計位移」
  （與 Apple 的 `base + translation` 同一個形狀）；進行中的手勢也不能放在 `key(revision)`
  底下 —— 整層重建會把它拆掉
- ❌ 拿 UUIDv7 的**整個字串**比建立順序 —— 同一毫秒內產生的 id 後面是隨機位元。
  只比前 48 位元（毫秒），同一毫秒維持核心原本的順序（匯入文件用它排回文件順序）
- ❌ 匯入文件：傳給核心的是**檔名**而不是完整路徑（讀不到檔、`catch` 只 `print`）、
  用去掉副檔名的 `displayName` 判斷副檔名（`md`／`json` 永遠認不出）、核心建立區塊
  **不給位置**（十個文字方塊疊成一團）、編輯器持有自己的 `notebook` 副本而不會從
  store 重讀。現在是暫存套件解析 → 依文件順序由上往下排版 → 合併進編輯器自己的筆記
- ❌ 新插入的物件沒有明確順序時，疊放由「型別預設層級」決定 —— 新貼的圖片被舊文字
  蓋住。偵測「物件數量變了」一處處理，不要改每一個插入路徑
- ✅ 手寫模式下物件不吃觸控，本機插入物件之後切到打字模式（兩端同一條規則）

## 文件地圖

| 讀什麼 | 何時 |
|---|---|
| `STATE.md`（本檔） | **每次開工第一件事** |
| `DEVLOG.md` | 想知道「上次做到哪、為什麼這樣做」 |
| `TODO.md` | 想知道「還有什麼沒做、什麼被卡住」 |
| `architecture.md` | 要改架構或選型 |
| `format-spec.md` | 要碰資料格式或同步 |
| `features.md` | 要確認某功能的優先序與競品對照 |
| `roadmap.md` | 要知道階段與 Go 門檻 |
| `adr/` | 想知道某個決策的理由 |
| `manual/index.html` | 使用者操作手冊（六國語系、實機截圖、可連結目錄） |
| `legal/privacy.html` | 隱私權政策（六國語系；App Store 送審需要這份的公開網址） |

## ⚠️ 需求檢視（2026-09-12）

八項新需求的涵蓋度分析見 [`requirements-review.md`](requirements-review.md)。
**兩項完全未涵蓋**（UI/UX、工具列與物件對齊），**一項無法照原描述達成**
（與 10 款競品格式完全互通 —— 多數是專有未公開格式，且互通需要對方
也讀我們的格式）。最嚴重的單一缺口是**掌拒**，那是手寫 App 的生死線。

## ⚠️ 目前唯一的阻擋項

**D-07：Paraformer-zh / ct-punc 的授權決策。**
官方 HF repo 有完整 Apache-2.0 LICENSE 檔，但 FunASR GitHub 的 MODEL_LICENSE
v1.1 寫「僅供參考與學習」。**影響 P0 功能 C5 中文標點還原。**
四個選項與建議見 `models/LICENSE-AUDIT.md` §5 —— 需要專案擁有者拍板。

## 目前進度一句話

Apple 版（iOS / iPadOS / macOS）已在使用者手上穩定運作，v2.3.4。
**Android 版 WP1–WP8 全部完成**：核心可交叉編譯、Compose 外殼、共用邏輯下沉、
檔案互通、筆跡引擎、平台功能、手寫辨識、上架檔產出 —— 模擬器上端到端可用，
release 簽章的 APK 裝得起來也寫得出字。

剩下的是**只有實機才驗得了的那批**（見 `TODO.md` §Android 實機待測 A-01～A-10）
與上架的人工步驟（正式金鑰、Play Console）。

## 跨平台的現況（2026-09-13）

| 面向 | 狀況 |
|---|---|
| 核心測試 | `cargo test --workspace` **799 通過** |
| Apple | `KairumoTests` 40、`KairumoUITests` 5，iOS 與 Mac Catalyst 建置綠 |
| Android | instrumented **51 通過**（需真的 Android runtime） |
| 介面字串 | 單一來源 `i18n/ui-strings.json` **456 條**，產生 Swift 與 Kotlin 兩份表 |
| 版本號 | `bump-version.sh` 同時更新 Cargo / Apple 專案 / Android Gradle / 使用者文件並驗證 |
| 檔案互通 | iOS 匯出的 `.padnote` 在 Android 開啟後筆畫數、座標、顏色、頁高一致（實測） |

### Android 這一版刻意沒有的東西

- **語音轉錄**（`asr` feature 關閉，ONNX Runtime 沒有 Android 預編譯檔）。
  但**錄音本身可用** —— 關掉的是轉錄不是錄音，兩者常被搞混。
- **讀 PDF**（`pdf` feature 關閉，PDFium 需各 ABI 的 .so）。
  但**匯出 PDF 可用** —— 匯出是 `padnote-export` 自己產的。
- **多筆記本管理**：Android 目前是單一本 `notebook.padnote`。

### Apple 的儲存層還沒切過去

WP4c 做的是**遷移**（原檔不動、可回滾），不是切換讀取路徑。App 讀的仍是既有的
JSON + `.drawing`。在同一次改動裡既搬資料又換讀取來源的話，回滾就失去意義了。

## 已可運作的能力（皆有測試覆蓋）

手寫落盤與擦除（墓碑）· 頁面/區塊文件模型 · 統一時間軸與**筆跡↔錄音跳轉**·
中文全文搜尋（打字/轉錄/手寫辨識）· 音訊環形緩衝與 VAD 分段 ·
端對端加密與 BIP39 復原碼 · 無伺服器同步（本機資料夾 provider）·
Markdown / SVG 匯出 · 手寫辨識 fallback 鏈 · 引擎與權限中心狀態機 ·
模型下載（驗證 + 續傳 + 可刪除）· PDF 座標轉換與 LRU 頁面快取 ·
**文字 CRDT 與端到端同步** · **Swift / Kotlin FFI 綁定** ·
**完整文件持久化與重播還原** · **Opus 錄音編碼（ffprobe 驗證）** ·
**完整錄音→分段→轉錄→筆記的編排流程** · **Silero 神經網路 VAD** ·
**中文 ASR（Paraformer，fp32 輸出與 FunASR 吻合）** · **中文標點還原** ·
**簡繁轉換（台灣正體）** · **完整中文管線：無標點簡體 → 有標點正體** ·
**掌拒與輸入仲裁** · **物件群組/變換/對齊/吸附** · **Markdown/JSON 匯入** ·
**Office 嵌入與編輯（docx/xlsx）** · **PDF 標註的座標轉換與往返** ·
**堆疊順序（z 序，可重開還原）** · **表格物件（試算表逐格可編輯）** ·
**頁面上的錄音物件（可播放／搬移／縮放／改名／刪除，兩平台同一組 JSON 鍵）** ·
**跨型別框選（拉框選取、整組搬移、複製／貼上／建立副本／刪除）** ·
**55 種形狀（含 ISO 5807 流程圖符號，六國語系名稱）** ·
**手繪／打字兩個模式的明確分界（模式徽章＋打字模式下筆不畫線）** ·
**錄音長度由核心解析 Ogg-Opus（兩平台同一個數字）** ·
**Android 首頁比照 Apple 版面（動作卡、橫向「繼續」、縮圖格狀、說明與條款）** ·
**純 Rust 縮圖畫得出圖片／表格／形狀（文字為灰條，見 S-60）** ·
**Android 編輯器工具列分兩排，第二排跟著模式換** ·
**有實際內容的內建範例筆記（兩本各三頁，圖文表混排，兩平台同一份文案）** ·
**流程圖形狀／連接線／範本（ISO 5807）** · **可自訂的模組化工具列** ·
**六國語系介面（英／繁中／簡中／日／韓／泰）** ·
**完整的 FFI 曝露（Swift 綁定 178 個公開 API，語法檢查通過）**

## 圖學（工程製圖）套件

筆畫帶**圖層**（1 底層原題／2 中層輔助／3 頂層答案，0＝一般筆跡）與**工程線型**（實線／隱藏線／中心線／假想線），
存在 ink 格式的 `EXT_DRAFT` 擴充區塊（舊讀者略過未知區塊，向後相容）。虛線由核心的筆點陣依線型挖出，兩平台畫得一樣。
- 核心：`padnote-ink::draft`（長按吸附：直線／圓／矩形／三角形／鎖角度折線）、`padnote-solid`（草圖拉伸、
  三視圖／等角圖＋隱藏線、全剖／階梯／旋轉／平行剖面＋剖面線、第一／第三角法排版）、
  `ffi_draft.rs`（圖層、線型、製圖筆組、圖學套件、步驟編號）、`ffi_solid.rs`、`ffi_draft_example.rs`（《圖學範例》）。
- 兩平台：「圖學」工具（Apple `Drafting*.swift`／`SolidStudio.swift`、Android `ink/Drafting*.kt`／`SolidStudio.kt`）：
  製圖筆組、圖層顯示／鎖定／目標、角度鎖定、改圖層、步驟編號①②③、立體輔助。圖層顯示／鎖定是**本機逐本**的檢視狀態，不同步。
- 頁面：A3／A2／自訂尺寸（`custom_<寬>x<高>`，300–6000）取代「無限畫布」；作圖步驟紙、圖學錯誤陷阱頁；新增筆記本時可一次建立「圖學套件」。
- 使用者體驗（兩平台一致）：製圖面板可收合（手機／輔助使用字級預設收合，選擇存本機）、首次使用跳出四則提示
  （「？」可再叫出）；插入立體圖紙時放在**目前看得見範圍的正中央**並自動用套索選住，拖一下就能搬；
  長按吸附在 Android 也有即時預覽（停 0.55 秒就把筆畫換成吸附後的圖形，抬筆即為所見）；
  深色模式下近黑的製圖墨水提亮（畫面與頁面縮圖；匯出仍是原色）。
- 立體輔助可標註總長／總高／總深（尺寸線＋箭頭＋筆畫數字）與剖面字母「A」「A–A」；數字與字母是 `padnote-solid::glyph`
  的**筆畫字形**（跟著圖層、隱藏圖層時一起隱藏、匯出帶得走），不是文字方塊。
- 效能（release）：預設形狀 ≤10 ms；200 邊外框＋20 個 32 邊孔的極端輪廓約 0.8 s（`padnote-solid/tests/perf.rs`）。
  debug 組建（Android 開發版 .so）慢很多，不代表正式版。
- 已知限制：Android 手機寬度下編輯器標題列會換成多排、畫布偏矮（既有行為，非圖學專屬）；
  VoiceOver 沒跑過（模擬器不支援）；TalkBack 已在 Android 模擬器上開過，但朗讀文字不會寫進 logcat，改以無障礙節點樹（uiautomator）逐一檢查製圖面板每個控制項的名稱
  （標籤與 contentDescription 已補、`AccessibilityLabelTests` 通過）；多語系文案未經母語者審閱（由使用者自行處理）。
  （2026-10-06 已解決：階梯／旋轉剖面現在畫出切口後面的形狀、斜切面已支援、Android「改圖層」可復原。）

### 圖學學習工具（2026-10-06 起，計畫書：`docs/plans/drafting-learning-tools.md`）

對象是大學工程圖學課。全部幾何在核心（`padnote-drafting`、`padnote-solid`），兩平台只畫與收手勢；同一個操作兩邊產生同樣的線。
入口都在製圖列的「圖學工具」與「立體輔助」。

| 功能 | 核心 | 重點 |
|---|---|---|
| 尺寸標註（線性／直徑／半徑／角度） | `dim.rs` | 點兩個點再拖出尺寸線；數字依比例尺換算；數字是筆畫字形 |
| 圖學符號、圖框與標題欄 | `symbols.rs`、`gdt.rs`、`fastener.rs`、`frame.rs` | 表面粗度、焊接、螺紋、幾何公差、緊固件；A4／A3／A2 圖框＋投影法符號 |
| 實尺與比例尺 | `UNITS_PER_MM`（800/210） | 頁面＝紙上毫米；比例尺逐本記在本機 |
| 投影對齊 | `align.rs` | 長對正、高平齊、經 45° 轉折點的寬相等；虛線導引；可關閉 |
| 虛擬尺規 | `instruments.rs` | 直尺、丁字尺、兩種三角板、量角器（讀角度、可畫出讀數線）；靠邊畫線、拖動、旋轉；圓規 |
| 編輯工具 | `edit.rs` | 修剪、延伸、圓角（直線）、偏移、鏡射、矩形／環形陣列；沿用原筆畫的筆與圖層；一次復原 |
| 題庫與批改 | `problems.rs`、`check.rs` | 五題型：補第三視圖、等角圖畫三視圖、判斷第一／第三角法、挑錯、剖視圖；種子可重現；批改指出缺線／多線／線型錯／沒對齊／剖面線 |
| 玻璃盒展開、旋轉檢視 | `padnote-solid::glass` | 第一／第三角法；進度可拖；拖曳轉視角 |
| 2D 匯出 | `export2d.rs` | SVG、DXF（R12、毫米、圖層與線型） |
| 3D 匯出 | `export3d.rs` | STL、OBJ（毫米）、GLB、USDZ（公尺）；有洞的輪廓以耳切三角化；Apple 可用 Quick Look 的 AR 預覽 |

- 驗證：核心單元測試（`padnote-drafting` 103、`padnote-solid` 84）；Android 儀器測試（`ink/Drafting*Test.kt`）；
  Apple 單元測試（`DraftingEditTests`、`DraftingPracticeTests`、`DraftingExportTests`，後者用 Model I/O 把匯出的 USDZ／STL／OBJ 讀回來驗尺寸）
  與 UI 測試（`DraftingToolsUITests`）。
- 已知限制：
  - 圓角只支援直線（曲線會提示做不到）；偏移的轉角用尖角（銳角過長時改斜接）。
  - 題庫的立體是輪廓拉伸的柱體（沒有曲面立體）；剖面題只有垂直全剖；剖面線只檢查有沒有畫夠與角度，不檢查間距；
    批改只看作答範圍內、頂層的線，中心線與假想線不批改。
  - 量角器只有一組刻度（0° 在右端）；尺規沒有「量長度」的讀數。
  - 玻璃盒沒有隱藏線消除（畫各面的線、立體稜線與投射線，用來說明展開的概念）。
  - 3D 匯出沒有材質貼圖（淺灰單色）；Android 沒有 AR 預覽（USDZ 的 AR Quick Look 是 Apple 專屬），沒有在真機上放置 USDZ 驗證過。
  - 使用手冊（`docs/manual`）已新增獨立的「圖學」章（零基礎、手把手，12 步＋逐項說明，六語系、中英截圖），隱私權政策已加「圖學工具與匯出」一節（2026-10-07）。《Kairumo手冊》預載筆記本（手繪）尚未涵蓋圖學。
  - Apple UI 測試常被系統層崩潰（XCTAutomationSupport 在日誌量過大時崩在 `os_log` 路徑）打斷，重跑即過；
    跑法用 `xcodebuild test -retry-tests-on-failure -test-iterations 3`。CI 若跑這類測試也要同樣重試。

## 預載筆記本《Kairumo手冊》（手繪）

四頁（封面＋一、二、三、總結）全部是筆畫，沒有文字方塊。標題與內文用 **Make Me a Hanzi** 的標準筆順中線逐字手寫
（`scripts/manual_ink/hanzi.py`），插圖是一筆一筆畫的。產物 `assets/seed/kairumo-manual-ink.json`，兩平台讀同一份。
- 內文在 `scripts/manual_ink/manual_text.py`（對照 `docs/manual/manual.js` 實際有的功能，不寫做不到的事）。改了文字要先跑
  `build_hanzi_subset.py`（把新字放進子集）再跑 `manual.py`。
- 筆順資料授權 **Arphic Public License**（`third_party/makemeahanzi/`：README 有評估、`ARPHICPL.TXT` 全文逐位元組未改、
  `NOTICE.txt` 修改聲明）。授權全文與聲明**隨 App 打包**（Android `assets/seed/`、Apple `Templates/`），兩平台各有測試守著。
  不取用 `dictionary.txt`（LGPL-3.0）。

## 多語系（非繁中）檢查結果與已知缺口（2026-10-06）

開發一直用繁中驗證，用其他語系（en／簡中／日／韓／泰）操作時查出並修了：
- **搜尋**：泰文詞間沒有空白，整句成一個 token 查不到；聲調／母音符號被當標點把詞切斷。現在泰文與中日韓一樣走 bigram，
  符號黏在前一個字上；全形英數折成半形；日文 々、半形片假名納入。索引每次開啟重建，不必遷移。
- **PDF 匯出**：韓文原本整句變亂碼（簡中字型沒有諺文）。現在中日韓各用自己的 CID 字型（簡中 GB1、繁中 CNS1、日 Japan1、韓 Korea1），
  漢字依假名／諺文／文件語言挑字型；泰文換行允許字間斷行且符號不離開子音。
- **Android 打字模式文字框**：行高原本固定 = 字級（1.0 倍），泰文聲調會疊到上一行。改為交給字型（有額外行距時 = 1.2 倍 + 額外）。
- **介面字串**：補齊缺的翻譯（ja／ko／簡中 12 條、泰 19 條，皆為筆設定與同步訊息）。
- 打字輸入法（注音、拼音、日文、韓文組字）：兩平台的文字輸入都用框架內建的 TextField／BasicTextField 且狀態同步更新，沒有自己改寫輸入中的文字。
- **PDF 裡的泰文**：PDF 沒有可以不嵌入的標準泰文字型，所以內嵌 Noto Sans Thai（SIL OFL，`third_party/notosansthai/`），
  **只有文件裡有泰文時才嵌**（約 +45 KB）。聲調符號疊在子音／上母音之上、ำ 拆開等排版由字型自己的 GSUB／GPOS 決定，
  `crates/padnote-export/src/otl.rs` 是 OpenType 排版引擎：GSUB 1–8（含擴充型別）、GPOS 1–9、GDEF（lookup 旗標、markFilteringSet、markAttachmentType），字型內的規則照表執行；泰文只有字碼序列的前處理（ำ 拆成 ํ＋า 並排在聲調之前、結合符號依結合類別排序）寫在程式裡，因為那是 Unicode 規則、不在字型裡；附 ToUnicode，複製與搜尋拿得到字碼。
  用 macOS 預覽實際看過：ไม่、มี、ช่อง、ระหว่าง、ประชุม、บันทึก 全部正確。
- **簡繁互查**：搜尋前把漢字**逐字**折成簡體（OpenCC 表，Apache-2.0；不用 GPL 的 MediaWiki 表），所以搜「笔记」找得到「筆記」，反之亦然。
  逐字而不是整句，是因為整句轉換看上下文，查詢（兩三個字）與文件（整段）的上下文不同會轉出不同的字而查不到。
  代價：少數一對多的字（乾／干）會互相查得到；日文漢字（国）也會查得到繁體（國）。
- 泰文字型沒有做子集化（嵌入整份 72 KB，壓縮後約 45 KB）；要更小可以之後做。

## 已實作但**尚未驗證**（不要當成完成）

- whisper.cpp ASR：編譯與錯誤路徑已測，**轉錄品質未實測**（需模型 + 中文測試集）
- PDFium：介面與邊界檢查已測，**實際解析未驗證**（需 libpdfium 執行期庫）
- 墨跡 Swift 層：語法檢查通過，**延遲未量測**
- VAD：已換成 Silero（白噪音誤判 0/100，EnergyVad 為 100/100）
- ASR 串流粒度：**段級**（VAD 段，上限 5 秒），非幀級。幀級需重新匯出計算圖（S-32）

## 介面多語系稽核（2026-10-06）

範圍：程式介面、工具快顯提示（tooltip／無障礙標籤）、警告與錯誤、通知、診斷畫面、同步日誌、預載手冊。
- **做法**：所有使用者看得到的文字走 `i18n/ui-strings.json`（六語，約 2450 條），Swift 用 `L10n.t/f`（`apple/Sources/LocalizedMessages.swift`），
  Kotlin 用 `L10n`（`LocalizedMessages.kt`）；同步訊息走 `SyncText`。錯誤訊息以「⚠️ 」前綴標記，不再用中文子字串判斷是否為錯誤。
- **閘門**：`check-hardcoded-strings.py`（訊息接收端、log、持久化 id、英文呼叫；刻意不翻的用 `i18n-ok`）、
  `i18n_tool.py verify`、`core_messages.py check`、`i18n_review.py lint`，都在 CI。

### 核心（Rust）的診斷訊息 —— 已解決
核心的錯誤訊息仍是繁體中文（開發語言），但**不再退成通用錯誤**：`i18n/core-patterns.json` 登記了 222 條樣式（`{}` = 動態片段），
譯文在 `ui-strings.json`（鍵 `core_msg_NNN`，六語）。兩端在介面邊界（`L10n.coreText`／`errorText`）依樣式比對、換成使用者語言：
動態片段（檔名、數字）原樣帶入，內層若又是核心訊息就遞迴翻譯，「、」連起來的清單逐項翻。
`scripts/core_messages.py check` 掃 Rust 原始碼，**新增一條中文訊息沒登記就紅**；整句比不到而且含漢字（只會是系統或第三方函式庫的字串）才退成通用訊息。
簡體中文也走這套（原本直接顯示繁體）。

### 同步日誌 —— 已解決
日誌行仍以中文寫進 `SyncLogger`，**顯示時**才依樣式翻（`L10n.logText`；81 條，另含授權流程訊息），比不到就原樣（不像錯誤訊息退成通用句）。
`core_messages.py check` 也掃日誌來源檔（`LOG_SOURCES`）：每一條中文字面值都必須是某個樣式的一段。匯出日誌檔（給開發者）保留原文。

### 區網／中繼協定訊息 —— 使用者看不到
中繼伺服器（Rust `padnote-relay`、Apple 的 `LocalRelayServer`）回的 `error`／`reason` 文字是中文，但兩端客戶端**從來不顯示它**
（`CollaborationManager` 收到 `error` 型別直接忽略；`room_closed` 只斷線），行為由 `code`／`type` 決定。所以這些中文只存在於協定與服務端日誌，不是使用者介面。
若日後要把伺服器訊息顯示出來，必須走 `L10n.coreText`（樣式已收錄）。

### 診斷畫面 —— 已解決
Android 核心狀態畫面與兩端的筆輸入診斷（壓力、傾角、延遲）改用 `diag_*` 鍵（34 條）。

### 《Kairumo手冊》—— 部分解決
- **繁體中文、簡體中文**：手寫版（筆順來自 makemeahanzi；簡體字資料集同一份，2026-10-06 經使用者同意再下載一次，SHA-256 與先前記錄相同）。
  `kairumo-manual-ink.json`（繁）與 `kairumo-manual-ink-zhHans.json`（簡）；繁中版逐位元組沒變。子集 229 字（`strokes-subset.json`）。
- **英／日／韓／泰**：同一套手繪插圖 + 該語言排版的文字方塊（`assets/seed/kairumo-manual-typed.json`，由 `manual.py` 的 `build_typed` 產生；
  文字在 `manual_text.py` 的 `TYPED`）。插圖逐點相同（腳本斷言），文字位置與繁中版的手寫字一一對應、放不下會自動縮字級。
- **名稱與摘要跟著語言**（`seed_manual_title`／`seed_manual_snippet`），舊使用者的「Kairumo手冊」也會認出來補上語系鍵。
- **做不到的部分**：英／日／韓／泰**不是手寫**。手寫需要筆順中線資料，makemeahanzi 只有漢字、沒有假名／諺文／泰文。
  已經植入過的手冊內容不會隨語言切換重做（那是使用者的筆記）；只有名稱會變。

### 母語者審閱 —— **尚未發生**
所有非繁中譯文都是開發者撰寫、機器輔助，**沒有任何母語者審閱過**（`python3 scripts/i18n_review.py status` 全部 0%）。
能由機器做的檢查已經做了：`i18n_review.py lint`（佔位符與原文一致、沒有混入別種文字、沒有缺譯文；抓到並修了一處韓文裡混入的「筆」）。
審閱流程已備好：`export <語言>` 產生 `docs/i18n-review/<語言>.tsv` 給審閱者填，`apply` 把修改寫回並登記審閱者與日期；繁中原文改了，舊審閱自動視為過期。

### 仍然是中文／未翻的地方（刻意或無法）
- Rust 微服務 `padnote-relay` 的 stdout 日誌、核心的 `expect`／`panic` 訊息（給開發者）。
- 匯出 Markdown 裡的標記（「[手寫內容 — 見 PDF 匯出]」等）：App 目前沒有任何地方呼叫 Markdown 匯出。
- 系統或第三方函式庫丟出來的錯誤字串（作業系統本身的語言）。

### PDF 排版引擎與 CoreText 比對
PDF 排版引擎只用 Noto Sans Thai 在正式輸出路徑上；其他字型（含 CFF／OTTO）引擎讀得動，但 PDF 寫出端還只會嵌 TrueType 外框，要嵌其他字型須再做 FontFile3。
`scripts/verify-otl-coretext.py`（僅 macOS，不在 CI）把引擎輸出與 CoreText 逐字形比對：28 組全部一致；可變字型只比字形編號、希伯來文（從右到左）只比字形，引擎沒有雙向排版。

### UI 測試的已知不穩（不是程式碼問題）
- 整批跑 `xcodebuild test` 時，`KairumoUITests` 會因 **XCTAutomationSupport 在日誌被系統隔離時崩潰**（堆疊：`runtime_issue_os_log_fault_callback` → `_platform_strcmp`）而掉一批測試
  （Smoke／Responsive／InteractionMatrix／InsertTools 的個別項目）；單獨跑通常通過。原因是 XCUITest 取整棵無障礙樹，單頁有數萬個元素，日誌量爆掉。
  純 HEAD 也一樣有（Sidebar／Toolbar／Trash／Ink 本來就紅），不是這次改動造成的。
- `testTextModeSharesThePaperAndItsTextBoxesStayEditableInDrawMode` 單獨跑會失敗（純 HEAD 也是），整批跑時靠前面測試留下的狀態才過。
- `MultiDeviceUITests` 需要 Android 同時配合，單獨跑必紅；跑整批時要 `-skip-testing:KairumoUITests/MultiDeviceUITests`。

### 擦除／改圖層的跨裝置同步（2026-10）
- **規則**：同步只傳**變大**的檔案（`ffi_gdrive.rs` 筆畫檔上傳／下載都比大小），所以「擦掉」不能是「少寫」，要是**追加的墓碑**；
  重寫自己的筆畫檔時用 `pad_ink_to` 補位，檔案不比重寫前小。
- **專業筆畫**：套件身分穩定（`add_stroke_drafted_with_id`），帳本 `ProInkLedger`（每頁 `*_pN.proink-ledger.json`，在文件庫目錄）記墓碑；
  匯入時只在套件裡**有墓碑**才拿掉自己的那一筆（`removed_stroke_ids`），不能只憑「合併結果裡沒有」。
- **PencilKit 筆畫**：沒有 id，身分 = SHA-256(內容指紋｜第幾筆｜世代)；擦除在**匯出當下**用三份快照比對偵測
  （上次匯出的自己／這次的自己／別台基準線），墓碑與被擦掉的自己的筆畫（連資料）永遠留在帳本；擦掉別台的筆畫到套件裡依內容指紋找核心 id。
- **升級**：帳本 `schema < 2` 的頁面第一次同步會強制重寫並讓檔案多一點，雲端舊身分的檔案才會被換掉。
  已知殘餘：升級前的舊筆畫在**原作者還沒升級重寫之前**被別台擦掉，墓碑指向的是舊的隨機 id，原作者重寫後那一筆會在第三台重現（本機仍濾掉）。
