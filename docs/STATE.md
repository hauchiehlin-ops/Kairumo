# 專案狀態與交接記憶

> **每次開發階段開始前先讀這份。** 目的是讓不同的開發階段／不同的人／不同的 AI
> 不必重新推導已經決定過的事。
> 最後更新：2026-09-16

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

## 已實作但**尚未驗證**（不要當成完成）

- whisper.cpp ASR：編譯與錯誤路徑已測，**轉錄品質未實測**（需模型 + 中文測試集）
- PDFium：介面與邊界檢查已測，**實際解析未驗證**（需 libpdfium 執行期庫）
- 墨跡 Swift 層：語法檢查通過，**延遲未量測**
- VAD：已換成 Silero（白噪音誤判 0/100，EnergyVad 為 100/100）
- ASR 串流粒度：**段級**（VAD 段，上限 5 秒），非幀級。幀級需重新匯出計算圖（S-32）
