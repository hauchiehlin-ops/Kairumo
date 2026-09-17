# 待辦事項

> 分三類：**🔴 被硬體/資料卡住**（程式已就緒，等外部條件）、
> **🟡 待實作**（純軟體，可直接做）、**⚪ 待決策**（需要人拍板）。

---

## 🔴 被硬體或資料卡住（程式已就緒）

### H0. iOS 實機驗證（`--ios-install` 那條路尚未實測）
- **卡在**：目前沒有任何實體 iPhone / iPad 連著這台 Mac。
  帳號裡也只登錄了一支 iPhone 16 Pro Max，**沒有任何 iPad**。
- **已就緒**：`./scripts/dist.sh --ios-install` 全部寫好，裝置偵測與
  「沒接線就在編譯前中止」都已實測通過；但**「真的裝進裝置」那一步沒驗過**。
- **要做**：接上 iPad → 解鎖 → 信任這台 Mac → 跑 `--ios-install`。
- **判定**：主畫面出現 Kairumo 且能開啟 = 通過。
- **備註**：要發給**別人**的話不走這條 —— 走 TestFlight（`scripts/release.sh`），
  不需要 UDID、對方也不需要 Mac。v2.10.1 (24) 已上傳，等 Apple 處理完
  就能在 App Store Connect 加測試人員。
  `.ipa` 那條路（Apple Configurator + 事先登錄 UDID）實務上不建議給非技術使用者。

### H1. S1 墨跡延遲實機量測 —— **M0 Go/No-Go，最高優先**
- **卡在**：實體 iPad（模擬器 Metal 路徑不同，數字無意義）＋ 240fps 攝影機
- **已就緒**：`apple/InkSpike/` 全部原始碼、`apple/README.md` 量測協定
- **要做**：Xcode 建 iOS target → 部署實機 → 依協定量 20 次取中位數與 p95
- **判定**：中位數 ≤9ms 且 p95 ≤12ms = Go；>12ms = 改用 PencilKit（會改變跨平台策略）
- **影響**：決定自建墨跡引擎是否成立

### H2. S2 中文 ASR 測試集 —— **M0 Go/No-Go**
- **卡在**：需錄製 ≥3 小時真實台灣場景音檔（M2 前擴到 10 小時）
- **已就緒**：`cargo run -p padnote-bench --bin asr-score`、分場景門檻、TSV 格式
- **要做**：依 `crates/padnote-bench/fixtures/README.md` 錄製並人工標註
- **判定**：quiet ≤8% / noisy ≤18% / codeswitch ≤15%
- **備註**：這份測試集是競品抄不走的資產，越早開始累積越好

### H3. 模型權重授權確認（M0/S4 殘留）
- **卡在**：需人工逐一查閱模型發布頁的授權條款
- ✅ **已確認**：silero-vad-v4（MIT，URL 與雜湊皆經實際下載驗證）、
  whisper-large-v3-turbo（MIT）、ppocr-v5（Apache-2.0）、qwen3-4b（Apache-2.0）
- ❌ **已排除**：SenseVoice-Small（FunASR Model License v1.1，非 OSI 開源；
  商用釐清 issue 數月無回覆）。C9 中英夾雜改由 whisper-turbo 承擔
- ✅ **已解決**：Paraformer-zh-streaming 自行從官方權重匯出（repo 內含完整
  Apache-2.0 授權原文，11,358 bytes，雜湊已記入 PROVENANCE.json）
- ⚠️ **ct-punc 證據較弱**：repo 內**無** LICENSE 檔，僅 model card 標籤
- ⏸️ **延後**：speaker-diarization（P2）
- **完整稽核**：`models/LICENSE-AUDIT.md`
- ⚠️ **另一個教訓**：原本 silero 的 HuggingFace URL 需要登入，`curl` 只拿到
  29 bytes 的 "Invalid username or password"。**清單裡沒被驗證過的 URL 等於沒有**
- **高風險**：語者分離模型（pyannote 系條款嚴格）
- **記錄於**：`models/MODELS.md`

### H8. libpdfium 執行期庫 —— **取得與執行已驗證，出貨方式待你拍板**
- **原本卡在**：`pdfium-render` 只是綁定，`libpdfium` 動態庫要另外提供
- ✅ **已做（2026-09-16）**：`./scripts/fetch-pdfium.sh [all]`。
  來源 bblanchon/pdfium-binaries（Google 沒有發佈官方二進位檔），
  版本**釘死** `chromium/8057`，七個平台的 SHA-256 **逐一驗證**，
  與 `models/manifest.json` 同一套規矩。抓下來的東西不進版控
  （每個 3～4 MB、可重抓，`/third_party/pdfium/` 已加進 .gitignore）
- ✅ **「能不能執行」已經驗過**（這才是這一條真正的問題）：
  新增 `cargo run -p padnote-pdf-pdfium --example probe`。
  沒有設 `DYLD_LIBRARY_PATH` 時 `bound=false`，設了之後 `bound=true`；
  設了之後 `padnote-pdf-pdfium` 的 4 項測試**真的走到實作**
  （原本 libpdfium 不在時它們會自己跳過，看起來一樣是綠的）
- ✅ **已拍板：隨 App 出貨**（2026-09-16，D-11）。授權面沒有問題 ——
  PDFium 是 BSD-3-Clause（Google），打包腳本是 MIT（Benoit Blanchon），
  兩者都相容於本專案的 Apache-2.0
- ✅ **Android 已接好**：`build-android-libs.sh` 會把 `libpdfium.so` 複製進
  `jniLibs/<abi>/`（arm64-v8a 6.2 MB、x86_64 6.4 MB）。沒抓過時會**明講**
  並說下一步，不會靜靜略過 —— 靜靜略過的話，下一個發現的人是使用者
- ✅ **iOS 的 XCFramework 已產生**：`./scripts/build-pdfium-xcframework.sh`。
  `install_name` 改成 `@rpath/libpdfium.dylib`（維持 `./libpdfium.dylib` 的話
  App 一啟動就閃退，而訊息指向 dyld，不指向我們）
- ⚠️ **還沒做 1：Xcode 專案的嵌入**。要把 `PDFium.xcframework` 加進專案並選
  **Embed & Sign**。只 Link 不 Embed 的話，開發機上跑得動、裝到裝置上
  一開就閃退。這一步我沒有動 `project.pbxproj` —— 手改嵌入階段弄壞專案檔的
  風險，高過它省下的時間
- ✅ **Catalyst 的缺口已解，選了 (b)**（D-11b，2026-09-16）：
  **Apple 整條線改走 PDFKit，完全不用 PDFium。**
  bblanchon 的 mac 版是平台 1（macOS）不是平台 6（MACCATALYST），
  Catalyst 建置不會選它 —— 與其為了四個平台裡的一個去自建 PDFium
  （depot_tools + gn + ninja，而且要長期維護），不如讓 Apple 走系統那一套：
  PDFKit 在 iOS / iPadOS / macOS / Catalyst 全都有，`ExportPrintManager`
  早就在用它列印。
  - `apple/Sources/PdfKitDocument.swift`：頁數、頁面幾何、旋轉正規化、
    文字層、算繪成 PNG。7 項測試跑在**真的 PDF** 上（用
    `UIGraphicsPDFRenderer` 現產一份，不餵自己拼的位元組）
  - `build-xcframework.sh` 改成 `--no-default-features --features asr`，
    Apple 端不再連進 `padnote-pdf-pdfium`
  - 少 6 MB × 2 的二進位、少一個第三方供應鏈、少一個會隨系統更新壞掉的東西
  - **libpdfium 只出貨給 Android**（Android 沒有能讀文字層的系統 API，
    `PdfRenderer` 只能算繪）。兩邊後端不同，**介面與座標約定同一份** ——
    Swift 那 7 項測試裡有一組就是逐條對應核心 `padnote_pdf::PdfPage` 的
    同名測試（Y 軸翻轉、來回轉換、旋轉換寬高）
  - `apple/PDFium.xcframework` 與 `build-pdfium-xcframework.sh` 不再需要
- **另注意**：PDFium 的 C API 非執行緒安全，多頁渲染實際是序列化的，
  J2 的效能預算只能靠 `PageCache` 的預抓，不能靠平行渲染

### H9. whisper 轉錄品質實測
- **卡在**：模型檔 574 MB 需下載；且中文品質必須用 H2 的測試集驗證
- **已就緒**：`padnote-asr-whisper` 編譯通過、錯誤路徑已測
- **備註**：whisper 定位是**多語備援**。中文主力應是 Paraformer-zh（S-24），
  但其模型權重授權尚未確認（H3）

### H4. Apple Pencil 實機行為驗證
- 壓感曲線調校
- **懸停（hover）：程式已完成（S-69）**，筆尖靠近時畫出筆頭預覽並照筆桿角度
  傾斜。要驗的是實體筆真的發得出懸停事件（模擬器發不出來）
- **擠壓（Pencil Pro，S-40）：程式已完成**，照 `preferredSqueezeAction` 走，
  只認 `.ended`
- **滾動角（barrel roll）：只到診斷列。** `PKStrokePoint` 沒有這個欄位，
  PencilKit 這條路上存不進筆畫 —— 格式那一層已備好（核心 `EXT_ROLL`），
  要存得下來的前提是不再用 PencilKit 收筆畫。診斷列可確認手上那支筆有沒有回報
- **雙擊切換工具：程式已完成（S-67）**，照 `UIPencilInteraction.preferredTapAction`
  走。要驗的只剩「實體二代筆敲下去真的會收到事件」—— 對應規則本身已有
  單元測試（`PencilDoubleTapTests`）。模擬器發不出這個事件
- `coalescedTouches` 在 120Hz 下的實際取樣數
- 熱節流與長時間書寫的延遲漂移

### H5. iCloud Drive provider 實機測試
- Ubiquity Container 的未下載（evicted）檔案處理
- `NSFileCoordinator` 在多裝置併發下的實際行為
- **注意**：S3 已證明演算法收斂，這裡驗證的是 Apple API 的實際語意

### H6. 大型 PDF 效能驗證（J2）
- 500 頁 PDF 開啟 ≤1.5s、捲動 60fps
- 需要真實的大型 PDF 樣本與實機

### H7. App Store 審核相關
- 大型模型按需下載的審核說明
- 隱私標籤（目標：不收集任何資料）
- 背景錄音 `UIBackgroundModes` 的審核理由

---

## 🟡 待實作（純軟體，可直接進行）

> **Android 對齊 Apple 的整體方案見 [`android-parity-plan.md`](android-parity-plan.md)**
> —— 2026-09-17 已完成階段 0～2 與階段 3／4 的大半，閘門缺口 148 → 8。
> 下表中 S-71、S-72、S-84、S-85、S-86（快顯部分）、S-87、S-88、S-93 已結案；
> 仍未做的是 S-80、S-81、S-90、S-91、S-77（折疊機）、S-92，以及三支筆刷、
> 分享筆記檔、側欄資料夾分頁、特殊符號這四項 Android 缺的功能。
> （2026-09-17）。下表這些 ID 裡與 Android 版面有關的 14 項
> （S-71 剩餘、S-72、S-77、S-80、S-81、S-84、S-85、S-86、S-87、S-88、
> S-90、S-91、S-92、S-93 剩餘）已在那份計劃裡排成五個階段，
> 並補上七項原本沒有條目的缺口（P-01…P-07）。
> **階段 0 是核心規格表＋兩端對照測試＋CI 閘門** —— 前兩次補完就漂回去，
> 差別就在沒有東西守著它。

### 新發現（2026-09-17，對齊計劃執行中）

| ID | 內容 | 說明 |
|---|---|---|
| S-94 | **「分享筆記」送出去的是 PDF，不是筆記檔** | Apple 的 `shareNotebookFile()` 直接呼叫 `exportAsPdf()` —— 按鈕寫著「分享筆記」，對方收到的是一份 PDF，打不開也編不了。真正要做的是把 `.padnote`（一個目錄）打包成單一檔案再分享，兩端都要。Android 目前連這一項都沒有 |
| S-95 | **Android 少三支筆** | 毛筆、麥克筆、水彩是 PencilKit 的墨水類型，核心的 `ToolKind` 只有四種筆刷（鋼筆／原子筆／螢光筆／鉛筆）。要嘛核心補上筆刷模型讓兩端共用，要嘛 Android 自己算 —— 前者才不會又分家 |
| S-96 | **Android 側欄沒有「資料夾目錄」分頁** | Apple 的結構欄有頁面／資料夾兩個分頁，Android 只有頁面 |
| S-97 | **Android 沒有特殊符號面板** | Apple 的打字工具列有數學／標點／羅馬數字三組符號選單 |
| S-98 | **iPhone 上其餘面板還沒逐一檢查擠壓** | 素材圖庫的主題與分類膠囊已改成換行（原本在 390 點寬會被壓成一欄一個字母的直排）。同樣的單行 `HStack` 還可能出現在文字編修、圖表、主題工具、3D、表格這幾個面板 —— 要在 iPhone 上逐一打開看過 |

### 跨平台版面的殘留缺口（2026-09-16）

| ID | 內容 | 卡在什麼 / 要做什麼 |
|---|---|---|
| S-71 | **Android 沒有紙張底紋 / 沒有紙張挑選器** | 核心的 `PageStyle`（方格、橫線、康乃爾、點陣）Android 端**一個都沒畫**，所有頁面看起來都是空白紙。因此 S-70 只把紙張選擇下沉到核心並讓 Android 在建立第一頁時寫對 `PageStyle`（同一份 `.padnote` 在 iPad 上開會正確顯示），Android 自己的畫布還沒有對應的算繪。要做：在 `canvas/ContinuousPages.kt` 的每頁背景加上 13 種樣板的繪製，並與 Apple 的 `NotebookEditorView` 對齊。做完才把「主題分類 + 紙張清單」補進 Android 的新增筆記對話框（核心 `paper_templates()` 已備好）。S-74 為 13 種紙各補了「實務範例 / 空白大綱」，**Android 目前是從「文件範本」樹裡的「紙張樣板」主題進去**（因為它還沒有紙張清單）—— 補上挑選器時要一併把那個主題從樹裡收起來，否則會有兩個入口。 |
| S-72 | **其餘對話框還不能調整大小** | S-70 做了 `ui/ResizableDialog.kt` 並接上「新增筆記本」。Android 另外約二十個內容型對話框（素材圖庫、圖表工作室、表格編輯、3D、協作、圖層…）還是固定高度。要做：逐一把可捲動內容的 `heightIn(max = …)` 換成 `rememberDialogHeight(key)` + `DialogResizeHandle`，key 一個面板一個。 |
| S-84 | **頁面規格只做了 Apple 端** | S-83 把八種規格（A4 直/橫、A5、Letter 直/橫、Legal、簡報 16:9、正方形）下沉核心 `page_formats()`，Apple 端有下拉選單、換規格會同步改畫布與匯出、並把超出新頁面的物件夾回頁內。**Android 還沒有**：`PageGeometry` 的對應物（`ink/PageGeometry.kt`）仍是寫死的單一尺寸。要做：讓它讀筆記本的 `pageFormatId`，並在編輯器工具列加上同一個選單。 |
| S-85 | **編輯區域的限制只擋筆畫，而且只在 Apple** | S-83 在 Apple 端擋掉完全落在可列印範圍外的筆畫（跨在界線上的留著但提醒）。**還沒擋的**：拖曳既有物件到框線外（目前只有換規格時才夾回）、Android 完全沒有。核心的 `is_within_printable` / `clamp_to_printable` 已備好，兩邊照用即可。 |
| S-86 | **頁面搬動與側欄調整只做了 Apple 端** | S-87 讓頁面可以前後搬動（右鍵／長按快顯、拖曳換位）、縮圖大小可調、側欄與畫布之間的界線可以拖。索引算術在核心（`page_index_after_move` / `page_index_after_insert`）、寬度與字級的規則也在核心（`sidebar_clamp_width` / `sidebar_content_scale`），**但 Android 一項都還沒接**：`canvas/PageSidebar.kt` 目前只有點選換頁，沒有選單、沒有搬動、寬度寫死 `DS.Layout.sidebarWidth`。 |
| S-87 | **核心沒有「搬動頁面」這個操作** | Apple 端的頁面順序是它自己的檔案（`{id}_p{n}.drawing` 與 `pageHeights`），所以 S-87 在 Apple 那邊直接重排檔案就成立。Android 的頁面住在核心的 oplog 裡，而 `DocOp` 只有 `AddPage { index }` 與 `RemovePage` —— **沒有搬動**。要做：新增 `DocOp::MovePage { id, index }`（op code 34）、`PadnoteSession::move_page`，Android 才搬得動，而且那樣搬動會跟著同步走到別台裝置。注意這是 oplog 格式的新增：舊版讀到 op 34 會整份拒絕（`UnknownOp`），與先前 33 個 op 的情況相同。 |
| S-88 | **資料夾拖曳只在編輯器的側欄，首頁沒有** | S-87 把「拖出資料夾」補齊（根目錄那一列、整段未分類區、以及落到同資料夾的其他筆記上都接受落下），但那是編輯器側欄的 `foldersStructureView`。首頁 `HomeWorkbenchView` 的筆記卡片格線完全不吃拖曳 —— 而那是使用者最常整理筆記的地方。 |
| ~~S-89~~ | ~~新樣板還沒有「實務範例／空白大綱」內容~~ | ⛔ **取消**（2026-09-18，使用者決定）：新樣板**不需要**實務範例，維持設計大綱與格式即可。改為做「版面配色」（`guide_palettes()` 六組，使用者自選、整本一個調子），讓只有骨架的頁面看起來仍然活潑。 |
| ~~S-90~~ ✅ | **Android 的頁面縮圖不畫版面** | Apple 的 `PageThumbnailRenderer` 這次接上了 `PageGuideRenderer`，側欄縮圖看得出哪一頁是康乃爾。Android 的 `PageImageRenderer` 走的是核心的純 Rust 繪圖（`export_page_png`），那條路上沒有版面 —— 畫布上有、縮圖上沒有。要做：讓核心的頁面算繪也吃 `page_guides`，那樣匯出的 PDF 兩邊也會一致。 |
| ~~S-91~~ ✅ | **跨筆記本的頁面複製／搬移只在 Apple** | S-91 讓頁面結構欄可以多選幾頁，複製或搬到別本筆記。計畫的算術在核心（`page_transfer_plan`：去重排序、目的頁碼、由大到小的刪除順序、以及「一本筆記不能被搬空」），**Android 還沒有任何入口** —— 它的頁面結構欄目前只能點選換頁。 |
| ~~S-92~~ ✅ | **測試會把資料寫進使用者的筆記清單** | `PageDeletionTests` 與 `PageOrderTests` 直接操作 `NotebookStore.shared` 並呼叫到會落盤的路徑（`deletePage` / `transferPages` 內部都會 `persistData()`）。`defer` 只把陣列裡的那幾筆移掉、沒有再存一次，於是測試用的「測試」筆記本留在 `notebooks_v1.json` 裡 —— 模擬器上跑完測試就會看到一堆。要做：測試用一個獨立的 store 實例或暫存目錄。 |
| S-93 | **Android 還不能挑樣板與配色，也還不能逐頁換樣板** | S-93 讓 Apple 端可以在同一本筆記裡逐頁用不同樣板（`pagePaperIds`）、並選版面配色（`guidePaletteId`）。兩者都寫進**同步的**中繼資料（`pageTemplates` / `guidePalette`），Android 的畫布也**讀得到並畫得出來**了 —— 但 Android 沒有任何**設定**入口：新增筆記的對話框沒有配色可選，頁面結構欄也沒有「插入其他樣板頁面」。 |
| S-80 | **Android 整頁模式在 100% 時仍不能上下捲動** | S-79 補上了捏合縮放與「放大之後一指平移」，但**沒放大時單指不接管** —— 一指拖曳會把整頁拉出畫布範圍並蓋掉工具列（實機看過）。正確做法是把畫布放進真正的捲動容器（`verticalScroll`）而不是用 `graphicsLayer` 的位移硬推，但那會與 `InkCanvas` 的 `pointerInteropFilter` 搶手勢，要一起改。目前的替代路徑是連續模式或翻頁鈕。 |
| S-81 | **Android 只畫得出六種底紋** | 核心的 `PageStyle` 就是六種（空白／橫線／方格／點陣／康乃爾／五線譜），而介面上的十三種紙張是它的上層分類。Apple 端另外畫了工程藍圖的標題欄、等角軸測網格、行動端線框的雙手機外框這些**額外裝飾**，Android 還沒有。要做：把那些裝飾也下沉成核心的一份描述（線段／矩形清單），兩端照著畫，而不是各畫一套。 |
| S-77 | **Android 大螢幕只做了三處** | S-78 把斷點下沉核心（`ffi_layout`）、編輯器補上並排的頁面結構欄、導覽頁夾住可讀寬度，並在平板模擬器（1280×800 dp）實測通過。**還沒做的**：折疊機姿態（鉸鏈位置、闔起／展開）完全沒處理；編輯器第二排工具列在寬螢幕仍然只是一路往右排，沒有分組；素材圖庫、圖表工作室、3D 等對話框在平板上仍是滿版或固定寬；結構欄只有「頁面」沒有 Apple 的「資料夾目錄」分頁。要做：逐畫面套 `layoutMetrics`，並用 `kairumo_fold` AVD 驗折疊。 |
| S-76 | **iPhone 上遠端筆跡不重繪** | S-75 修好之後，遠端筆畫已經確實落盤（檔案 64B → 352B），畫布的 binding 也收到了（log：`updateUIView sync ui=0 binding=1`），但模擬器畫面上沒有重繪。同一台模擬器上**用手指自己畫也畫不出來**，所以比較像 iPhone 版畫布的輸入／重繪問題，不是協同的問題 —— 需要實體 iPhone 才分得開。要做：在實機上重跑一次「iPad 開房、iPhone 加入、iPad 畫一筆」，確認是否重繪。 |
| S-73 | **sheet 只能調高度** | Apple 端走 `presentationDetents`，寬度由系統決定（`preferredContentSize` 在 iOS 18 已無效、`presentationSizing(.fitted)` 會攤成全螢幕，兩條都實測過）。真的需要連寬度一起拉的面板，要改用 `FloatingPanel` 那條路重做，不是 sheet。 |

### ✅ 已完成
| ID | 工作包 | 內容 |
|---|---|---|
| ~~S-64~~ ✅ | 無障礙、搜尋、快捷鍵 | **無障礙**：補 54 處標籤＋掃原始碼的回歸測試；Android 補上畫布把手的標籤。**搜尋**：原本只搜得到標題，現在 Android 走核心 bigram 索引、Apple 比對文字方塊／表格／形狀標籤。**快捷鍵**：⌘N／⌘F／⌘E／⌘1–9，走 `buildMenu` App 層級選單（前兩種做法都是「編得過但沒作用」）。順帶修掉深色模式下看不見的墨黑色票。見 DEVLOG 2026-09-16 |
| ~~S-61~~ ✅ | 文件範本 | **39 種文件範本 × 完整案例／空白範本 = 78 份。** 內容寫在 `templates/src/`，版面由 `scripts/doc_templates_tool.py` 算一次，兩平台載入同一份 JSON。Android 一併補上原本沒有的「新增筆記」挑選視窗。順帶修掉兩個先前就存在的資料遺失：PDF 匯出不換行、Apple 表格從未進過 `.padnote`。見 DEVLOG 2026-09-16 |
| ~~S-60~~ ✅ | 縮圖／匯出的字形 | **真字形，而且內嵌 0 位元組字型。** 兩邊都改走「核心產 PDF → 系統算繪」（`PageImageRenderer`）：Apple 用 PDFKit、Android 用系統 `PdfRenderer`，都會替非內嵌字型代換系統字型 —— 原本以為必須做的字型授權決策因此不必做。見 DEVLOG 2026-09-16 |
| S-01 | WP4 | `padnote-storage`：manifest、套件讀寫、內容定址 blob（去重/完整性/GC） |
| S-02 | WP1 | `padnote-doc`：頁面樹、區塊模型、統一時間軸 |
| S-03 | WP2 | `padnote-ink`：編解碼 + 幾何（平滑、簡化、命中測試、dirty rect） |
| S-04 | WP11 | `padnote-search`：CJK bigram 索引、AND 查詢、增量更新 |
| S-05 | WP5 | `padnote-asr`：環形緩衝、VAD 分段狀態機、工作佇列 |
| S-07 | WP21 | `padnote-crypto`：信封加密（Argon2id + XChaCha20）、BIP39 復原碼 |
| S-08 | WP10 | `padnote-sync`：SyncEngine、框架化 chunk、增量游標、加密整合 |
| S-09 | H1/H2 | `padnote-export`：Markdown + SVG 匯出 |
| S-11 | — | `padnote-core`：NotebookSession 門面（含 C1 筆跡↔錄音跳轉） |
| S-06 | WP12 | `padnote-recognize::registry`：引擎註冊表與 fallback 鏈 |
| S-10 | WP7 | `padnote-pdf`：文件介面、座標轉換、LRU 頁面快取與預抓 |
| S-14 | D4 | `padnote-models`：清單、SHA-256 驗證、斷點續傳、可刪除 |
| S-17 | WP13 | `padnote-core::setup`：引擎與權限中心狀態機 |
| S-16 | WP1 | `padnote-doc::text`：文字 CRDT + 二進位編碼，**端到端同步已驗證** |
| S-12 | — | UniFFI：Swift/Kotlin 綁定、產生腳本、XCFramework 腳本、CI 閘門 |
| S-23 | — | 文件 op-log 持久化：12 種 DocOp、落盤、`open()` 重播還原 |
| S-13 | WP5 | `padnote-audio`：Opus 編碼 + Ogg 容器（**ffprobe 驗證通過**）|
| S-15 | WP5 | `padnote-asr-whisper`：whisper.cpp `AsrEngine`（**轉錄品質待實測**）|
| S-21 | WP7 | `padnote-pdf-pdfium`：PDFium 適配層（**執行期需 libpdfium**）|
| S-25 | WP5/6 | `padnote-recorder`：錄音編排。管線與 ASR 引擎型別上分離，
音檔優先落地。**ffprobe 驗證端到端產出為 3.00 秒合法 Ogg-Opus** |
| S-26 | WP5 | `padnote-vad-silero`：Silero VAD（ort）。**實測白噪音下
EnergyVad 誤判 100/100、Silero 0/100**。模型缺失時降級不失敗 |
| S-29 | WP5 | **ct-punc 體積問題已解**：量化納入 `Gather`（嵌入表占 86.4%
體積），1,074 MB → **269 MB**，argmax 一致率 100% |
| S-30 | WP5 | `padnote-punct-ct`：中文標點還原。**詞表是簡體**，
故管線順序必須是「先標點、再轉繁體」。標點接在詞尾以保留時間戳 |
| S-24 | WP5 | `padnote-asr-paraformer`：fbank（與 FunASR 參考特徵逐點吻合）
+ LFR + CMVN + CIF + encoder/decoder。**fp32 輸出與 FunASR 完全吻合** |
| S-34 | WP5 | `padnote-text` + `core::transcript`：簡繁轉換與完整中文管線。
**無標點簡體 → 有標點台灣正體**，時間戳全程不變 |
| S-18 | H1/H2 | `padnote-export`：PDF 匯出（含底紋模板、富文本、表格、圖片、向量筆畫與 `/Ink` 標註）|
| S-43 | WP7 | `padnote-pdf-pdfium`：以 PDFium 寫入真實標註（`create_annotated_pdf` 實作與回讀驗證）|
| S-55 | — | 列印流程：`print_data` + Apple (UIPrintInteractionController/NSPrintOperation) 與 Android (PrintManager) 整合 |

| ~~S-65~~ ✅ | 鍵盤快捷鍵 | **Android 原本完全沒有這一層**（grep 不到任何 `onKeyEvent`／`KeyShortcut`），接鍵盤的平板因此少一整組功能。補上 `AppCommands` 命令匯流排 + `Activity.onKeyDown`：Ctrl+Shift+N 新筆記、Ctrl+F 搜尋、Ctrl+E 切手寫／打字、Ctrl+1–6 選工具。用 `onKeyDown` 而不是 `dispatchKeyEvent` —— 後者會把 Ctrl+A 從文字框手上搶走。adb 端到端驗過 |
| ~~S-66~~ ✅ | 首次啟動引導與權限 | iOS／Android 都不可能「安裝時要權限」，系統對話框一輩子只跳一次。改成第一次打開時把話講清楚（要哪個權限、為什麼、不給會少什麼），當場給按鈕；已被拒絕過就改成送進設定頁。兩端同一套流程。順手移除 Android 沒人用的 `ACCESS_WIFI_STATE` 與 `NEARBY_WIFI_DEVICES` |
| ~~S-67~~ ✅ | 觸控筆快速切橡皮擦 | Apple Pencil 雙擊筆桿（照系統 `preferredTapAction` 走）／Android 筆桿側鍵與反向筆頭。硬體事件不同，「切到哪去、再切回哪裡」同一套規則。實機行為列 H4／A-14 |
| ~~S-68~~ ✅ | 跨 App 拖放圖片 | 分割畫面下把相簿的圖直接拖進畫布。落點與尺寸走共用的 `ImageDropPlacement`（縮到 280pt、不放大小圖、以落點為中心並夾回頁內）。Apple 端已在 iPad 模擬器分割畫面實地驗過；Android 列 A-13 |
| ~~多視窗並排~~ ✅ | — | iPad 分割畫面實測：首頁與編輯器在窄欄下都正常重排，兩個 App 並排運作正常。`UIApplicationSupportsMultipleScenes` 早已開啟（Catalyst 的獨立視窗要用）。Android 的 `MainActivity` 沒有 `singleTask`、`configChanges` already 含 `screenSize\|screenLayout`，分割畫面本來就成立 |

### 待做
| ID | 工作包 | 內容 | 備註 |
|---|---|---|---|
| ~~S-13~~ ✅ | WP5 | Opus 編碼整合 | 已由 `padnote-audio` + `padnote-recorder` 完成，Ogg-Opus 端到端樣本已驗 |
| ~~S-15~~ ✅ | WP5 | whisper.cpp 實作 `AsrEngine` | `padnote-asr-whisper` 已實作；品質實測仍列 H9 |
| ~~S-23~~ ✅ | — | 文字 op 寫入 `doc/ops/` 持久化 | `NotebookSession::record` 會寫 `doc/ops/<lamport>-<device>.oplog`；重開 replay 已有測試 |
| ~~S-19~~ ✅ | WP20 | iCloud `CloudProvider` 實作 | **不需要另一個 provider** —— ubiquity container 就是一個檔案系統路徑，核心的 `LocalFolderProvider` 直接能用。真正的差別只有「檔案可能還沒下載」：iCloud 用 `.原檔名.icloud` 佔位檔。核心已認得佔位檔（列舉時還原成邏輯檔名、讀取時回 `NotMaterialized` 而不是 `NotFound`），Apple 端 `ICloudSyncFolder.swift` 負責觸發下載並等它完成。實機行為仍列 H5 |
| ~~S-20~~ ✅ | WP23 | llama.cpp 整合（摘要、待辦抽取） | `padnote-llm`（切塊 + 提示詞 + **解析**，18 項測試）＋ `padnote-llm-llama`（llama.cpp 後端）＋ `ffi_llm`（平台介面，4 項測試）。**llama.cpp 不是 `padnote-core` 的相依** —— 連進去會讓行動端每個使用者都下載好幾十 MB，不管他用不用得到摘要（與 reqwest 那次同一個判斷）。行動端由平台提供後端。**UI 入口已完成（2026-09-17）**：兩端都有「摘要與待辦」，餵給模型的文字與首頁搜尋同一組來源。後端 Apple 接系統內建語言模型（零下載、零體積），**Android 目前沒有裝置端後端**並誠實回報 —— aicore 是實驗版且會帶進 Guava 與 play-services，llama.cpp + 2.4 GB 模型要使用者下載比 App 大幾十倍的檔案，兩條都違反「平台裝得下不代表使用者該下載它」。仍待做：Android 的裝置端後端、以及實際跑一份模型驗真實輸出 |
| ~~S-21~~ ✅ | WP7 | PDFium 綁定（`pdfium-render`）| `padnote-pdf-pdfium` 已實作；執行期庫與大型 PDF 實測仍列 H8/H6 |
| ~~S-22~~ ✅ | WP12 | Apple Vision / ML Kit 的 `HwrEngine` 實作 | Android 的 ML Kit 本來就有；**Apple 端原本完全沒有手寫辨識**（iPad 上寫的字搜不到）。新增 `HandwritingRecognizer.swift`：把每一組筆畫算繪成白底黑字的圖再送 `VNRecognizeTextRequest`。分組規則下沉核心（`padnote-recognize::grouping`），兩邊同一份 —— 切法不同會讓同一頁在兩台裝置上搜到不一樣的東西。辨識率需實機以真實筆跡驗（A-09）|

## 🆕 需求檢視新增項目（2026-09-12）

> 完整分析見 [`docs/requirements-review.md`](requirements-review.md)。

| ID | 項目 | 備註 |
|---|---|---|
| ~~S-41~~ ✅ | Office / Google 文件的嵌入與編輯（D-10 已拍板為「嵌入＋可編輯」） | 見 ADR-0009。docx/xlsx 可做，pptx 只做預覽 |
| ~~S-42~~ ✅ | PDF 標註的雙向保真（ADR-0008 第一層的核心） | 10 款競品都讀寫 PDF，這是唯一真正通用的互通途徑 |
| ~~S-45~~ ✅ | 平台層依 `Decision::retract` 實作筆畫收回 | **兩平台皆已實作**：Android 在 `InkEngine`；Apple 新增 `PalmRejectionCoordinator`（偵測到筆就切 `.pencilOnly`，並收回筆落下前 500ms 內的筆畫）。原本 Apple 在手寫模式下是 `.anyInput`，手掌畫得出東西 |
| ~~S-43~~ ✅ | 把標註寫進真實 PDF（PDFium 的 annotation API） | `create_annotated_pdf` 實作完成，經測試驗證 |
| ~~S-44b~~ ✅ | 匯出真正的 PDF `/Ink` 標註 | **兩平台皆已達成**。Apple 的匯出改走核心的匯出器（原本是點陣合成）；核心同時輸出向量筆畫與 `/Subtype /Ink` + `/InkList` + `/BS`。3D 模型與連結卡片核心沒有那兩種型別，改以算繪後的圖片帶進去，內容不會掉 |
| S-44 | 用其他 App 實測 | **需要你來測**（我裝不了那些 App）。已產出範例 PDF（兩頁、三筆畫、三個獨立 Ink 標註）。判準：那三條線能不能在 Goodnotes / Notability / PDF Expert 裡被**選取、搬動、刪除** |
| ~~S-35~~ ➡️ | **Windows 低延遲墨跡** | **已轉成 [ADR-0012](adr/0012-windows-low-latency-ink.md)，不再排期。** 它不是待辦：目前沒有 Windows 版，這一條在有 Windows 版之前不成立。結論（Compose MP Desktop 走 Skia/JVM 做不到 9ms，要原生 Windows Ink / DirectComposition）連同重新評估的時機都記在那份 ADR |
| ~~S-36~~ ✅ | **掌拒與輸入分流** | 🔴 完全未設計。**手寫 App 的生死線**：手掌靠螢幕會畫出大片塗鴉 |
| ~~S-37~~ ✅ | UI/UX 設計 | 🔴 完全未開始。可與 M0 並行，不依賴 S1 |
| ~~S-38~~ ✅ | 物件模型：群組／對齊／吸附／變換 | 需 ADR —— 會影響 `.padnote` 格式。目前 `Stroke` 沒有「物件」概念 |
| ~~S-39~~ ✅ | Markdown 匯入、JSON 匯入匯出 | 容易，可立即做 |
| S-40 | 各平台數位板協定與藍牙筆按鈕 | **程式面已完成（2026-09-17）**：`padnote-input::pen` 有一張可設定的對應表（雙擊／擠壓／主鍵／次鍵／反向筆頭 → 橡皮擦／上一支筆／筆刷設定／套索／復原／重做／尺規），兩端共用，11 條測試。Android 接 `BUTTON_STYLUS_PRIMARY`/`SECONDARY` 與 `TOOL_TYPE_ERASER`，Apple 接雙擊與擠壓。**缺的只剩實機校準** —— 側鍵事件要實體筆才發得出來（模擬器沒有、`adb input` 送不出 `buttonState`），數位板要接上才知道它把哪顆鍵送成哪個位元。見 A-14 / A-15 |

## 🆕 畫布與介面需求（2026-09-12）

| ID | 項目 | 備註 |
|---|---|---|
| ~~S-46~~ ✅ | 物件堆疊順序（需求 1：畫布物件可自由排列） | `SetZIndex` 記絕對索引；只在同層內移動 |
| ~~S-47~~ ✅ | 形狀、連接線與流程圖範本（需求 3） | ISO 5807 九個符號 + 4 份內建範本；連接線跟著圖形走 |
| ~~S-48~~ ✅ | 表格作為畫布物件（需求 2：嵌入試算表圖形） | xlsx 現在展開成 `BlockKind::Table`，逐格可編輯 |
| ~~S-49~~ ✅ | 工具列模組化與自訂顯示（需求 4） | 18 個工具 / 5 組；設定可序列化、可還原 |
| ~~S-50~~ ✅ | 六國語系（需求 5） | 型別強制完整性：少一個語言就編不過 |
| ~~S-51~~ ✅ | 表格的插入／刪除列欄與合併儲存格 | `DocOp` 已覆蓋列欄插刪、合併與取消合併，FFI 可呼叫 |
| ~~S-52~~ ✅ | 形狀與連接線落盤為 `DocOp` | 新增 `AddShapeObject` / `AddConnectionObject`，重開可還原 |
| ~~S-53~~ ✅ | 平台層的工具列 UI 與語言切換畫面 | Apple SwiftUI 範例已接 `FfiToolbar` / `supported_locales` |
| ~~S-54~~ ✅ | 其餘 UI 字串的在地化 | 字串表 **512 條**（清單原本寫的 44 早已過期）。錯誤訊息已在地化並有測試；`LocalizationManager.localizedUnsafe` 供背景執行緒查表 |
| ~~S-54b~~ ✅ | **素材庫的 58 個中文名稱** | 58 條 `asset_<id>_title` 已進共用 i18n catalog（英／繁中／簡中／日／韓／泰），Android/Apple 圖庫標題、搜尋與 Apple 素材 PNG 底部標題都改走語系鍵；核心繁中 title 保留為 fallback |
| ~~S-55~~ ✅ | 列印流程 | 核心 `print_data` 產出列印 PDF，已串接 Apple 與 Android 系統列印面板 |

## 📱 Android 實機待測（2026-09-13）

模擬器驗得完的都已經驗過（instrumented 22/22）。以下幾項**只有實機加觸控筆
才驗得出來**，等整體架構完成後一次回頭測。每一項都寫成可以當場判定的條件，
不要「大致可用」。

| ID | 待測項目 | 判定條件 | 現況 |
|---|---|---|---|
| A-01 | 筆寫得出墨跡 | 用筆畫一筆，畫布上出現對應的線 | 模擬器已過；實機曾回報全白，`Canvas.density` 遮蔽已修，待複測 |
| A-02 | 掌拒 | 手掌貼在螢幕上書寫，不產生任何筆畫 | 核心邏輯已測；門檻（手掌半徑 22dp、收回窗 500ms）是**起點值**，需依實機姿勢調整 |
| A-03 | 「僅限觸控筆」開關 | 開啟後手指完全畫不出東西；關閉後可以 | 實機曾回報「按不動」，**原因未明**，待複測 |
| A-04 | 快速書寫不掉點 | 快速畫弧線，線條平滑而非折線 | 歷史取樣點已處理並有測試，待實機感受 |
| A-05 | 前緩衝低延遲 | 開關 Low Latency 各記一次 p50/p95，差值為正 | 模擬器上兩條路徑都畫得出墨跡；延遲數字在模擬器無意義 |
| A-06 | 診斷列讀數 | `tool=` 是 2（觸控筆）、`rej=` 為 0 | 新增的診斷列供遠端判讀 |
| A-07 | 錄音 | 錄一段後波形時間軸與筆跡對得上 | WP6 |
| A-08 | 匯出與列印 | 匯出的檔案內容與畫布一致 | WP6（模擬器已驗檔案格式，實機驗內容） |
| A-09 | 手寫辨識率 | 中英文各 20 句，辨識結果搜得到 | WP7（模擬器已驗端到端可用；辨識率要真的筆跡才算數） |
| A-11 | 雲端同步端到端 | 兩台真實裝置指到同一個雲端資料夾，A 寫的字在 B 上打得開 | 檔案層級的邏輯已測；雲端傳輸是 OS 與服務的事 |
| A-12 | 同步資料夾權限存活 | 重啟 App 後仍有存取權，不需重選資料夾 | Apple 用 security-scoped bookmark、Android 用 persistable URI permission |
| A-10 | 分組門檻 | 正常書寫節奏下，一個詞不會被切成兩組 | 停頓門檻 700ms 是起點值 |
| A-13 | 跨 App 拖放圖片 | 平板分割畫面下，從相簿拖一張圖到畫布：圖落在放開的位置、比例正確 | 程式已完成（`Modifier.dragAndDropTarget` + `requestDragAndDropPermissions`），落點規則有測試。**手上只有 320×640dp 的手機 AVD**，分割畫面拖放不是那個尺寸的真實情境，所以沒在模擬器上驅動過。Apple 端同一套流程已在 iPad 模擬器驗過 |
| A-14 | 觸控筆側鍵切橡皮擦 | 按著側鍵畫過筆跡會擦掉，放開回到原本那支筆；把筆倒過來同樣會擦 | 規則有測試（`StylusButtonTest`）。`buttonState` 要實體觸控筆才發得出來，`adb input` 送不出來。與 S-40 同一批硬體 |
| A-15 | 筆桿次鍵與數位板 | 兩顆鍵的筆：主鍵擦、次鍵套索；接上 Wacom/XP-Pen 數位板，確認它把哪顆鍵送成哪個位元 | 對應表已下沉核心（`padnote-input::pen`，11 條測試），兩端共用。缺的只有實機校準 |
| A-16 | 懸停預覽 | 筆尖靠近但未接觸時，畫布上出現筆頭預覽；碰到螢幕後預覽消失 | 程式已完成。**Android 的預覽沒有畫傾角**（Compose 的懸停事件拿不到 tilt），Apple 有 |

**測試方式**：`cd android && ANDROID_HOME="$HOME/Library/Android/sdk" ./gradlew :app:installDebug`，
寫字時截圖那條診斷列即可，它會顯示平台回報的工具類型、接觸半徑、壓感、密度與仲裁結果。


## ☁️ Google Drive 自動同步（2026-09-15，D11 已接受）

目標：不同作業平台或設備只要登入同一個 Google 帳號，Kairumo 內的筆記本、
資料夾結構與可同步設定會自動收斂到同一狀態。正式同步使用 Google Drive
`appDataFolder`；既有「選同步資料夾」保留為手動備份／匯入匯出。

| ID | 項目 | 判定條件 |
|---|---|---|
| G-01 | Google OAuth 設定與登入 | **程式已完成，等實機驗證。** OAuth client 已建立（Apple / Android 各一）。PKCE、授權網址、權杖交換與更新、撤銷全在核心 `ffi_oauth`（13 項測試）；平台只做「開系統瀏覽器 + 打 HTTP + 存進安全儲存區」：Apple `ASWebAuthenticationSession` + Keychain、Android Custom Tabs + EncryptedSharedPreferences。URL scheme 兩邊都註冊好了（Apple 的 `Info.plist`、Android 的 `OAuthRedirectActivity`）。模擬器實測到「開啟系統瀏覽器 → 載入 Google 授權頁」為止，**還沒有真的登入過**（要真實 Google 帳號）。中途抓到一個外部設定問題，見下方「Android 還要開一個開關」|
| ~~G-02~~ ✅ | appDataFolder Provider 完整化 | `crates/padnote-sync/src/gdrive.rs`。**原本這個檔案根本沒有被編譯**（`lib.rs` 裡沒有 `pub mod gdrive;`），所以裡面的 `unimplemented!()`、少掉的分頁、沒跳脫的查詢字串都沒人發現。已補：分頁跟到底、`trashed = false`、查詢字串跳脫、前綴（而非子字串）比對、同名取最新、append 回錯誤而不是 panic、401/403 分類成權限錯誤。HTTP 抽成 trait，9 項測試用假的 Drive 驗分頁與查詢邏輯 |
| ~~G-03~~ ✅ | 同步資料佈局 | `format-spec.md` §7.0 |
| ~~G-04~~ ✅ | 全域設定同步 | `padnote-sync::settings` + `ffi_account_sync`。`SyncedSettings` 與 `DeviceSettings` 是**兩個型別**，「不要同步」寫在型別上而不是註解裡；有一項測試專門確認低延遲、掌拒門檻、SAF 權限權杖連序列化都不會出現在同步 JSON 裡。逐欄位帶 Lamport 時戳合併（整包 LWW 的話，A 改語言、B 改工具列會互相蓋掉）。**已接上兩邊 UI**：Apple 的 `LocalizationManager.setLanguage` 與 Android 新增的語言選擇器（Android 原本只能跟著系統語系走）都寫進同步設定，啟動時跨裝置設定優先於本機記錄。模擬器實測：選日文 → 介面變日文 → 重啟仍是日文，SharedPreferences 裡就是核心產生的那份 JSON |
| ~~G-05~~ ✅ | 筆記本與資料夾同步 | `padnote-sync::library` + `ffi_account_sync`。刪除是**墓碑**不是「不在清單裡」—— 靠比對清單的話，還沒同步到刪除的那台會把筆記本傳回去，每同步一次復活一次。另含：已刪資料夾底下的項目一起隱藏（否則變成打不開也刪不掉的幽靈）、父子環的迴圈保護（兩台各自把 A 搬進 B、B 搬進 A 會凍住 App）、搬移前先問會不會成環。12 項測試含「離線兩台各自增改刪後收斂」。**已接上兩邊 UI**：兩邊的新增／改名／搬移／刪除、資料夾的建立／改名／刪除都會記進索引（`AccountSyncStore`），刪除留墓碑，列表濾掉已刪項。模擬器實測：新增 → 索引出現該筆；刪除 → 同一筆變成 `deleted: true` 而不是消失 |
| ~~G-02d~~ ✅ | 媒體檔同步 | `ffi_gdrive::gdrive_sync_media`。**blob 與錄音的同步方式不一樣，因為命名保證不一樣**：blob 是內容定址（檔名＝SHA-256），同名必定同內容，比存在就夠，下載後**驗雜湊**；錄音是 uuid 命名且**錄製中會變長**，所以要比長度。順帶補上 Drive 的**可續傳上傳** —— 單次上傳上限 5 MB，而 blob 存的是原始位元組（`putBlob` 只縮顯示尺寸不縮檔案），手機照片 3–8 MB 是常態，不處理的話「一放照片同步就壞」|
| ~~G-02c~~ ✅ | 筆記本**內容**同步 | `ffi_gdrive::gdrive_sync_notebook`：以 **oplog 檔**為同步單位鏡像到 `notebooks/<id>/doc/ops/`。檔名 `<lamport:016x>-<device:08x>.oplog` 本來就唯一、不可變、字典序即因果序、重複覆寫冪等 —— 再包一層 chunk 只是把「哪些還沒傳」換個地方問。核心測試含「兩台裝置收斂」與「第二次同步不重傳」。**順帶修掉 SyncEngine 一個資料遺失 bug**，見下 |
| ~~G-02b~~ ✅ | Drive provider 接上授權 | `ffi_gdrive::gdrive_sync_metadata`：讀雲端 → 合併 → 寫回。**HTTP 由平台出**（`FfiDriveHttp` callback interface）而不是核心用 reqwest —— 後者會把整個 rustls 堆疊連進行動端函式庫（`libpadnote_core.so` 8.1 MB → 13 MB），而且與 `ffi_collab` 已定下的「socket 留在平台層」不一致。查詢字串、分頁、合併規則仍全在核心 |
| ~~G-07~~ ✅ | 同步要**自己發生**，還有雲端獨有的筆記本 | 兩個缺口，都是「機制寫好了但接不起來」：<br>**(a) Apple 端整條 Google 路沒有入口** —— `GoogleAuth` 與 `CloudSync` 在 Apple 上**沒有任何呼叫端**，設定頁進不去，等於不存在。已補 `AppDiagnosticsSheet.googleAccountSection`（登入／登出／立即同步）與 `NotebookSyncCoordinator.runDrive`（匯出 → Drive → 匯入，三步順序與資料夾同步一致）。<br>**(b) 只有手動按鈕會觸發** —— Android 只有選單那一項，Apple 連那一項都沒有。已加自動觸發：Apple `scenePhase == .active`、Android 首頁 `ON_RESUME`。自動同步**失敗不出訊息**（背景行為，每次跳「同步失敗」使用者只會把功能關掉）。<br>**(c) 別台新建的筆記本抓不下來** —— `gdrive_sync_notebook` 第一件事是 `NotebookPackage::open`，而雲端獨有的那本在本機連目錄都沒有，它會以「開不了套件」失敗。症狀：索引同步成功、清單上有標題、點進去是空的，而且每輪重複同樣的失敗。已補 `gdrive_clone_notebook`（先建空套件再走一般下載，重跑安全）與 `sync_live_notebooks`（攤平的清單；用 `sync_children_of` 只拿得到一層，資料夾裡的筆記本會被漏掉）。抓失敗時把空殼**刪掉** —— 留著的話下一輪 `exists` 為真，這本再也不會被重抓 |
| G-06 | 實機矩陣 | iPad + macOS + Android 同一 Google 帳號端到端測試：新增、編輯、刪除、改設定、重啟、離線再上線皆通過 |

**目前的狀態**：G-02～G-05 的核心與兩邊 UI 都完成了，但**還沒有真的上傳下載** ——
那要等 G-01。先把記錄做對是有意義的：記錄漏掉的東西，之後接上雲端也補不回來。
最典型的是刪除 —— 沒有墓碑的話，等雲端接上，另一台裝置會把已經刪掉的筆記本
原封不動傳回來。

**外部前置（已完成）**：Google Cloud OAuth client 已建立。
`drive.appdata` 在同意畫面上標示為 **sensitive**（不是 restricted）——
代表上 Production 要做 OAuth 驗證（填表、錄操作影片），但**不需要**
restricted scope 那種要付費的第三方安全評估。

**Android 的 SHA-1 要三筆，目前只登錄了兩筆**：

| 用途 | 指紋 | 狀態 |
|---|---|---|
| debug | `BB:79:DA:…:61:3F` | 已登錄 |
| release 上傳金鑰 | `D1:94:14:…:A6:25` | 已登錄 |
| Play App Signing | 上傳到 Play Console 之後才拿得到 | **尚未** |

第三筆最容易漏：Play 會用**它自己的**金鑰重新簽 App，所以使用者裝到的版本
用的是那個憑證。只登錄前兩筆的話，自己測都正常，上架之後所有人登入都失敗。

**Android 還要開一個開關（實測踩到）**：Google 對 **Android** 型別的 client
預設**關閉**自訂 URI scheme —— 授權頁會載入（代表 client id 有效），
但直接回 `Error 400: invalid_request`，詳細訊息是
「Custom URI scheme is not enabled for your Android client」。

開啟位置：Google Cloud Console → 憑證 → 點進 Android 的 OAuth client →
**進階設定（Advanced Settings）** → 把「啟用自訂 URI 配置
（Enable Custom URI scheme）」打開 → 儲存。改完可能要等幾分鐘生效。

iOS 型別**不受影響**，自訂 scheme 在那邊本來就是標準做法。

**修掉的一個資料遺失 bug（SyncEngine 的非 append 路徑）**：
`current_chunk` 從 0 重來，所以重開 App 之後第一次推送又寫 `log-1.bin`，
把上一個 session 的第一塊直接**蓋掉** —— 沒有任何錯誤：檔案數不變、
上傳成功、cursors 也對得上，只是內容沒了。只有不支援 append 的 provider
（正是 Google Drive）會踩到；既有測試全用支援 append 的 `LocalFolderProvider`，
所以那條路一行都沒被測過。已改成從雲端接續序號，並補上不支援 append 的
假 provider 與兩項回歸測試（驗證過：移除修正後測試會紅）。

**Testing 狀態的陷阱**：專案維持在 `Testing` 且使用 sensitive 範圍時，
refresh token **七天就過期**。長期測試時會以為是自己的程式壞了。
程式面已經把這個狀況與「網路壞了」分開（`oauth_needs_reauth`），
會要求重新登入而不是無限重試。


## 📄 固定頁面模型（2026-09-13，問題 3＋5）

問題 3（取消延長頁面、超出自動新增下一頁）與問題 5（畫布四周要有頁面界線、
匯出與列印一致）是同一件事：**頁面必須有與視窗無關的固定座標空間**。

現況的根因：畫布的座標寬度就是「視窗寬度」（`contentSize = canvas.bounds.width`）。
同一則筆記在 Mac 寬視窗寫的物件，座標可能在 x=1400，到了 iPhone 就在畫面外。
匯出對不起來的根本原因在這裡，不是在繪圖程式碼。

**已決定的尺寸：800 × 1132 pt（A4 直式比例）**，已寫進核心
`padnote_doc::{PAGE_WIDTH, PAGE_HEIGHT}` 並透過 `standard_page_size()` 開到 FFI ——
兩個平台唯一的來源。維持 800 寬是為了讓既有內容的**水平位置完全不動**；
改成真正的 A4 595×842 會讓所有東西水平縮放，動得比需要的多。

| ID | 項目 | 判定條件 |
|---|---|---|
| ~~P-01~~ ✅ | 固定頁面座標空間（800×1132，來源在核心） | 頁面尺寸與視窗無關 |
| ~~P-02~~ ✅ | 畫布畫出頁面與可列印區界線 | 界線位置 = 匯出邊界 |
| ~~P-03~~ ✅ | 移除「延長本頁」，寫到頁尾自動準備下一頁 | 四個按鈕入口已移除 |
| ~~P-04~~ ✅ | 既有過長頁面重新分頁（備份、驗證、可回滾） | 13 條測試；診斷頁有按鈕 |
| ~~P-05~~ ✅ | Android 採用同一個頁面模型 | 尺寸同源，界線已畫出 |
| ~~P-06~~ ✅ | 匯出以頁面為準，不再依畫布寬度 | `PageThumbnailRenderer` 已改 |
| P-07 | 實機確認：重新分頁後的版面符合預期 | 只有真實資料才驗得出來 |
| B-01 | 實機確認：備份→重裝 App→復原，資料完整回來 | 只有真的重裝才驗得出來 |
| B-02 | 跨平台確認：iPad 做的備份在 Android 復原得回來 | 容器格式同源，但沒有實測過 |

**風險**：P-04 會動到使用者手上的真實資料。做法比照 WP4c：先寫遷移與回滾測試、
動手前備份、每一本驗過才算數、一本失敗不影響其餘。


## 🪢 套索選取重寫（2026-09-16，使用者回報「按鍵全部無效」）

原本整個套索建在 PencilKit 的**私有內部**上：用 `_hasSelection` 這個私有
選擇器（`unsafeBitCast` 硬轉函式指標）判斷有沒有選取，再把
`UIResponderStandardEditActions` 送給名稱含 `PKTiledView` 的私有子視圖。
送給不是 first responder 的視圖，那些 action 根本不會執行；Mac Catalyst
的 responder chain 與 PencilKit 的套索實作又都與 iOS 不同。
使用者看到的就是五顆按鈕全部沒有反應。

已改成自己做（`apple/Sources/LassoSelection.swift`）：手勢自己收、
多邊形自己算、`PKDrawing.strokes` 自己改，全部公開 API。判定規則
（`lasso_encloses`）在核心，與 Android 同一段程式碼。

| ID | 項目 | 狀態 |
|---|---|---|
| ~~L-01~~ ✅ | 核心的多邊形套索幾何 | `padnote-ink::is_enclosed_by_polygon`，5 項測試含「L 形套索不會抓到凹角外面的東西」與「開放套索自動封閉」|
| ~~L-02~~ ✅ | 核心的 session 套索操作 | `lasso_select` / `delete` / `copy` / `paste` / `translate`，5 項測試。**Android 從此也有套索能力**（原本完全沒有）|
| ~~L-03~~ ✅ | 移除私有 API | `_hasSelection` 與 `PKTiledView` 的 responder 戳法全部拿掉 |
| ~~L-04~~ ✅ | 重複的工具列 | 工具列上那一排移除，只留畫布上的浮動列，且改成**只在真的有東西可以做時**才出現 |
| ~~L-05~~ ✅ | Apple 端的手勢 | **原本掛在 `PKCanvasView` 上，怎麼調都不觸發** —— 加 `UIPanGestureRecognizer`、把畫布捲動改成兩指、讓辨識器可同時成立，三樣都做了還是沒反應，而且沒有任何錯誤可以查。PencilKit 在畫布內部還有自己的觸控處理，跟它搶事件是一場沒有把握的仗。<br>改成**疊一層 SwiftUI overlay 在畫布上面**：套索模式下那一層吃掉所有觸控，畫布根本收不到；離開套索模式它就不存在，畫布行為一行未變。`Color.clear` 要配 `contentShape(Rectangle())` 才接得到觸控。<br>模擬器實測（iPad Pro 13"）：畫一筆 → 切套索 → 圈起來 → **虛線框出現且自動封閉** → 浮動列出現（五顆按鈕）→ 按刪除 → **筆畫真的消失、虛線框清掉** |
| ~~L-06~~ ✅ | Android 的套索 UI | `canvas/LassoSelection.kt`（狀態與動作，直接走核心的 `lassoSelect` / `Delete` / `Copy` / `Paste`）＋ `canvas/LassoOverlay.kt`（手勢與虛線、動作列）。工具列多一個「套索」，與 Apple 一樣放在同一列工具裡 —— 分成另一個開關的話會出現「套索開著又選了螢光筆」這種說不清的狀態。<br>模擬器**確認到的**：工具鈕出現、拖曳時虛線框畫得出來、換工具會清掉選取。<br>**沒確認到的**：選取 → 動作列 → 刪除。那台模擬器上**連筆都畫不出來**（換筆、關低延遲、關 Stylus Only、改用 `motionevent` 都試過，畫面完全沒有變化），所以沒有筆畫可以圈。那是既有的模擬器輸入問題（見 A-01／A-03「原因未明」），不是這次改動造成的 |

**現況要講清楚**：這一版把一個**已知壞掉而且用私有 API** 的實作，換成一個
**公開 API、幾何有測試、但端到端沒驗過**的實作。前者確定不能用，後者
至少沒有審核風險；但「現在能用了」這句話我還不能說。

## 📜 連續頁面模式（2026-09-15，使用者需求）

需求：開啟筆記本預設維持**整頁模式**（現況即是），頁尾加一個「連續頁面」
選項，切過去之後可以一路往下捲，不必按上一頁／下一頁。

**這不是小修，是編輯器核心的結構改動**，所以先記在這裡而不是硬做。

現況：整個編輯器繞著**單一** `CanvasRepresentable` 打轉 ——
`currentDrawing` 一個綁定、`currentPageIndex` 一個索引，
存檔、協同 oplog（`page_index`）、掌拒、套索、捲軸比例全部以它為單位。
好消息是 P-01 已經把頁面尺寸固定成 800 × 1132 並下沉到核心，
連續模式只是「把 N 個固定高度的頁面疊起來捲」，座標不必再動。

要做的事（Apple 與 Android 各一份）：

| ID | 項目 | 狀態 |
|---|---|---|
| ~~C-01~~ ✅ | `CanvasRepresentable` 加 `isScrollEnabled` | 單頁模式一行未改 |
| ~~C-02~~ ✅ | 連續容器：`LazyVStack` 疊 N 頁，每頁自己的畫布與物件層 | 模擬器確認 |
| ~~C-03~~ ✅ | 每頁各自載入／儲存筆跡 | 在第 2 頁畫的筆畫只寫進 `_p1.drawing`，`_p0` 沒被動到（檔案層級驗過） |
| ~~C-04~~ ✅ | 焦點頁由畫面中央決定 | 捲到第 2 頁，頁碼自動變 2/2、焦點框跟著移動 |
| C-05 | 協同、掌拒、套索逐頁接上 | 協同廣播、掌拒、套索狀態、canvasRef 都已接上，但**只有單機驗過**；兩台裝置同時寫沒有實測 |
| ~~C-06~~ ✅ | 模式切換與記住選擇 | 在頁碼旁；AppStorage 記住，重啟後仍在連續模式 |
| ~~C-07~~ ✅ | Android 同樣一套 | 新增 `ContinuousPagesView`：`LazyColumn` 疊 N 頁、每頁自己的 `InkEngine` 與物件 store；`./gradlew :app:compileDebugKotlin` 通過。實機觸控筆手勢仍列入 Android 實機待測 |

**做法**：連續模式是**另一棵視圖樹**，共用同一組元件
（`CanvasRepresentable`、`objectLayer(forPage:)`）。整頁模式那條路
一行都沒有改 —— 它綁著存檔、協同 oplog、掌拒與套索，是最沒本錢壞掉的地方。
前置的 `objectLayer(forPage:)` 抽取單獨提交（933e40f）當回退點。

**已知限制**：
- 頁面縮放用 `scaleEffect` 套在整頁上（800pt 固定寬 → 縮到視窗放得下）。
  只縮不放，放大會讓筆跡變糊。
- 手指在畫布上是畫畫不是捲動（與整頁模式一致）；捲動用兩指。
  這在沒有觸控筆的裝置上不直覺，但改掉會讓兩個模式的手寫行為不一致。
- Android 連續模式刻意改成 pen-only：筆交給畫布，手指交給 `LazyColumn` 捲動。
  沒有觸控筆的 Android 裝置若要用手指畫，切回整頁模式。


## 🧱 Android 介面落後（2026-09-15，使用者回報「完全不可用」）

Android 目前是**單一畫面**（`MainActivity.InkScreen()`）：兩個切換鈕、一列
筆刷、一行診斷字、一塊畫布，其餘功能全部塞在一個「...」下拉選單裡。
沒有首頁、沒有筆記本清單、沒有頁面切換、沒有手寫／打字模式切換。
檔案開頭的註解寫得很誠實：「現階段的唯一任務：證明 Kotlin ⇄ UniFFI ⇄
libpadnote_core.so 這條路是通的」—— 它至今仍是那個雛形，只是長出了幾個功能。

規模：Apple 31,574 行 / Android 12,444 行。Apple 有、Android 沒有的畫面：

HomeWorkbenchView（首頁與筆記庫）、頁面導覽、CollaborationSheet（協同）、
AssetLibraryView、Model3DStudioView、MathCalculatorSheet、CommentThreadView、
ThemeSpecificToolsView、WordTextStudioView（文字排版面板）、
ObjectFrameStyleMenu、CanvasScrollbar、DocumentViewerSheet、
ProColorPickerSheet、SketchRefineEngine、ImageEditControls、
PageRepagination、NotebookMigration、圖片插入與編修。

另外：診斷列（`tool=1 r=27.0dp p=0.41 …`）**在正式介面上永遠顯示**。
那一行是給開發看的，使用者看到的是「這是個測試程式」。

| ID | 階段 | 內容 | 狀態 |
|---|---|---|---|
| ~~A-00~~ ✅ | 立刻 | 診斷列預設隱藏，選單可開 | 實機驗證 |
| ~~A-01~~ ✅ | 第一階段 | 首頁／筆記本清單／搜尋／身分／備份 | 模擬器驗證 |
| ~~A-02~~ ✅ | 第一階段 | 分頁導覽（上一頁／下一頁／頁碼／新增／刪除） | 模擬器驗證 |
| ~~A-03~~ ✅ | 第一階段 | 手寫／打字模式切換 | 模擬器驗證 |
| ~~A-04~~ ✅ | 第二階段 | 圖片插入與編修、文字排版面板補齊 | 模擬器驗證 |
| ~~A-05~~ ✅ | 第二階段 | 物件通用能力 | 調色盤下沉核心、跨型別圖層面板、對齊與等距分佈 |
| ~~A-06~~ ✅ | 第三階段 | 剩餘功能 | 九項全部完成（見下方「A-06 收尾」） |
| ~~A-07~~ ✅ | 第三階段 | 連續頁面模式（C-07） | Android 已接上並通過 Kotlin 編譯；實機觸控筆/手指捲動體感另列待測 |

### A-06 收尾（2026-09-15）

九項全部完成，做法一致：**平台無關的那一半下沉核心**，兩邊各留一層薄 UI。

| 項目 | 核心模組 | 備註 |
|---|---|---|
| 數學 | `ffi_math` | 順帶擺脫 `NSExpression`（錯誤輸入會丟 ObjC 例外，Swift 攔不到）|
| 專業色票 | `ffi::designer_palette` | 原本兩平台的「淡藍」是不同的 hex |
| 文件檢視 | —— | Android 本來就有（Gradle `copyUserDocs`）|
| 討論串 | —— | `CommentPin` / `CommentLayer` |
| 草圖美化 | `padnote-ink::refine` + `ffi_sketch` | 順帶修掉「畫方框被美化成橢圓」|
| 主題工具 | `ffi_theme_tools` | 名稱改走語系鍵（原本是寫死的繁體中文）|
| 3D 模型 | `ffi_model3d` | 網格／旋轉／投影／明暗做成純數學，Android 用 Compose Canvas 畫 |
| 素材圖庫 | `ffi_assets` + `ffi_asset_art` | 58 件目錄 + 線圖變成路徑指令；Apple 端因此少了 1,833 行 |
| 協同編輯 | `ffi_collab` | 房號、邀請連結、AES-256-GCM 都在核心，**有 CryptoKit 實際產出的密文當測試向量** |

**沒有做、而且是刻意的**：

- Apple 素材圖庫那套「下載／快取／容量統計」Android 沒做。它的實質是把
  本機算繪的圖存成 PNG，沒有遠端伺服器；即時算繪又快又不會糊，
  少一套快取就少一個會過期、會對不上的狀態。
- 協同的 WebSocket 沒有下沉核心。搬進去要帶一整個 async runtime 與跨語言
  callback，換來的只是少寫幾十行連線樣板。協定與密碼學下沉就夠了。

### A-07 連續頁面：一個刻意的平台差異

Apple 的連續模式是「手指畫畫、兩指捲動」。Android 做不到同一套：
`LazyColumn` 的捲動手勢在滑動超過 touch slop 時就把事件攔走，
底下的畫布只收得到前幾個點。試過「偵測到筆就關掉 userScrollEnabled」——
**沒有用**，重組要等到下一幀，捲動手勢在那之前已經接手。

現在的做法是把判定交回核心的輸入仲裁器：連續模式下每一頁的引擎一律
**pen-only**。筆 → 判為墨跡，畫布吃掉事件；手指 → 判為手勢，畫布放行，
清單照常捲動。

代價要講清楚：**連續模式下手指畫不出東西**。沒有觸控筆的裝置要畫就切回
整頁模式（整頁模式的手指仍然可以畫，那條路一行都沒有改）。
### 已完成（2026-09-16，第二次）—— 順帶抓到 ANR 的真正原因

**ANR 的根因不是手勢，是重組風暴。** `InkCanvas` 的 `onInkChanged` 每收到
一個觸控取樣就呼叫一次，而連續模式把墨跡與物件**共用同一個計數器**，
底下五個物件圖層全部 `key(revision)` —— 寫一筆字（120Hz 下每秒上百個取樣）
就把圖片、形狀、表格、圖表、文字五個圖層整個丟掉重建，一秒好幾百次，
而且頁數越多越糟。

整頁模式看不出來：那邊本來就是分開的計數器（`imageRevision`、
`textRevision`…）。連續模式抄過來時合成了一個。

拆成 `inkRevision` / `objectRevision` 之後，手勢那一段才敢開。

實測（模擬器）：
- 一指作畫 → 筆畫出現、計數 9 → 10、`.strokes` 檔 6851 → 10620 bytes（真的落盤）
- 連續快速畫 10 筆 → 計數 10 → 20，**ANR 次數 0**
- 一指拖曳不會捲動（捲動已交給兩指）

**還沒驗的**：兩指捲動。`adb shell input` 只送得出單一指標，模擬器也沒有
真的多點觸控 —— 那一項要實機。

### 第一次嘗試的紀錄（已被上面取代）

照上面那條路實作過一次：`userScrollEnabled` **靜態**關掉（不是動態切換，
所以沒有差一幀的問題），捲動改由一個 `pointerInput` 在 Main pass 上偵測
兩指拖曳、用 `dispatchRawDelta` 自己推。每頁的引擎不再強制 pen-only。

**退回的理由，兩個都要講清楚**：

1. **驗不了。** 兩指手勢在這裡做不出來 —— `adb shell input` 只送得出
   單一指標，模擬器也沒有真的多點觸控。核心功能驗不了就不能出。
2. **觀察到一次 ANR。** 切進連續模式後第一次觸控，輸入派送逾時
   （`Waited 5973ms for MotionEvent ... action=UP`），App 當場沒有反應。
   **沒有證明**那就是這個改動造成的（沒有做對照組），但也沒有排除。

所以現在仍然是 pen-only 那一版。要重做的話，**前置條件是一台真的
觸控裝置**：先確認兩指捲動會動、一指畫得出來，再確認連續按幾分鐘
不會 ANR。程式面的做法上面寫完了，照著寫就好。

### 順帶修掉的嚴重缺陷：Android 從來沒有把存檔的墨跡讀回來

`InkEngine` 只裝「這一次開啟期間畫的」筆畫。寫進核心是有的、`.padnote` 裡
也真的有資料，但**重開筆記本之後畫面是空的** —— 使用者寫的字看起來憑空消失。
物件（文字方塊、表格、形狀、圖表）都有各自的 `load()`，只有墨跡沒有，
所以症狀是「圖還在、字不見了」，看起來像渲染壞掉而不是少讀一份資料。

已補上 `InkEngine.load()`（走核心既有的 `visible_stroke_details`）並在開頁時
呼叫。模擬器實測：修正前「0 strokes」、畫面空白；修正後「8 strokes」、
筆跡正常顯示。

**還沒驗證的**：

- 58 張線圖的**視覺結果**：2026-09-16 補了一個對照表產生器，
  `cargo run -p padnote-core --example asset_contact_sheet -- out.svg`，
  一張 SVG 畫完 58 件。人眼看過一輪，58 件全部畫得出來且認得出是什麼。
  **它證明的只有「核心產生的形狀本身對不對」** —— 平台層如果把路徑畫錯
  （線寬、填色、座標縮放），這張圖看不出來。那一項仍然要兩台裝置
  開同一件素材並排比對。
  幾件偏抽象、可以再畫細一點（判斷留給你）：CNC 狗骨清角、
  iOS/Material 雙系統導覽列、設計語意色彩矩陣。
- 協同編輯只有單機建置驗證，**沒有兩台裝置實際連過**。
  判定方式：一台 iPad 建房、一台 Android 用邀請連結加入，
  A 畫的筆畫要出現在 B 上，且 B 的成員清單看得到 A。
- Android 的 `usesCleartextTraffic` 是為了 ws:// 的區域網路中繼。
  oplog 本身是端對端加密的，但走公開網路時仍應改用 wss://。

**第一階段（A-00～A-03）已完成** —— 那是「能不能當筆記 App 用」的分界：
Android 現在有首頁、翻得動頁、分得清手寫與打字。

**A-01 原本尚未涵蓋 Apple 有的四項，2026-09-16 全部補齊**：

| 項目 | 現況 |
|---|---|
| 素材圖庫 | 早就有了（`asset/AssetLibrarySheet.kt`）。原本這一行是過期的 |
| 資料夾階層 | `library/FolderTree.kt` + 首頁的麵包屑、資料夾列、搬移對話框。資料夾住在同步索引裡，不另存一份本機清單 |
| 最近錄音清單 | `library/RecordingIndex.kt`。掃套件裡的 `media/audio`，不另外維護索引 —— 另外維護的話，從別台同步過來的錄音不會出現，而那正是最該顯示的東西 |
| 繼續區塊的縮圖預覽 | `library/NotebookThumbnails.kt`。算繪走核心既有的 `export_page_png`，與匯出同一條路；快取的鍵帶上修改時間，不必另做失效判斷。**縮圖裡沒有畫布物件**（文字方塊、表格、圖表、圖片），所以一本只打字沒手寫的筆記縮圖是空白頁 —— 那不是壞掉 |

**A-04 過程中修掉的既有缺陷**（都不是新功能，是本來就壞的）：
- 物件座標單位錯誤：ShapeLayer / TableLayer / ChartLayer 把頁面點當成像素，
  在 density = 1.0 的模擬器上看不出來，真實手機（2～3.5 倍）會縮到三分之一
  並擠向左上角，而同一份筆記在 iPad 上位置是對的。
- 文字排版面板只有新增時開得起來，既有方塊再也改不到樣式。
- 文字方塊只有拖曳才選得到，點一下沒反應。
- 卡片「淡藍」兩個平台是不同的 hex。


## 🗂 物件堆疊順序（2026-09-15）

已完成（Apple）：`NotebookDocument.objectOrder`＋`CanvasStackPanel`，
七種型別（圖片／文字／表格／圖表／3D／連結／形狀）共用同一份順序，
四個動作（移到最上／上移／下移／移到最下）11 項邏輯測試通過。

**尚未收斂**：

| ID | 項目 | 說明 |
|---|---|---|
| ~~Z-02~~ ✅ | 順序改放在筆記本中繼資料 | `objectOrderByPage` 走 `SetNotebookMeta`，跨得過平台（format-spec §6.2.1） |
| Z-03 ✅ | v3.8.0 的逐頁 bug | 那一版在第 2 頁調順序會清掉第 1 頁的。已改成逐頁，並保留舊欄位當退路（直接改型別會讓整本筆記解不開） |
| ~~Z-01~~ ✅ | Android 端的圖層面板 | `CanvasStackPanel` + `NotebookMeta.kt`，13 項 JUnit 測試 |

順序現在存在筆記本中繼資料裡（`objectOrderByPage`），那份 JSON 會寫進
`.padnote` 並跟著同步走，所以兩個平台讀的是同一份。
（2026-09-16 更正：原本這裡寫「Android 還缺圖層面板 UI」，那已經過期 ——
`canvas/CanvasStackPanel.kt` 早就在了，見上表 Z-01。）

核心的物件樹另有一套 `bring_to_front` / `draw_order`，那是給**形狀**用的
（形狀是核心的原生物件）。文字與圖片是 block 不是 object，不在那棵樹上，
所以跨型別的順序仍然需要中繼資料這一層。


## 🔀 跨平台落差盤點（2026-09-16）

逐一比對 Apple（67 檔 / 33,685 行）與 Android（74 檔 / 21,542 行）之後的結論。
**行數差距不代表功能差距** —— Apple 那邊有大量的 SwiftUI 版面樣板。

| 項目 | 結論 |
|---|---|
| 插入選單十三項 | ✅ **已對齊**。素材圖庫、插入圖片、算式、圖表、表格、形狀、圖層、3D、主題工具、草圖修飾、討論圖釘、線上協同、手寫辨識，Android 全部都有 |
| 套索選取 | ✅ 這一輪補上（L-06） |
| 連結卡片 | ✅ 這一輪補上。**而且它原本是一個資料可見性的 bug**：Apple 建的卡片真身在 `linkAttachments` 中繼資料裡（會同步），套件裡另有一張後備 PNG，而 `ImageStore` 會跳過那張 PNG —— 所以在 Android 上那張卡片**整個看不見**：資料同步過來了，畫面上什麼都沒有 |
| 重新分頁（P-04） | ⚪ **N/A，不是落差**。`pageHeights` 是 Apple 專有的舊欄位，只為了把早期那批「頁面可以無限長」的資料搬過來。Android 從第一版就是固定頁高（`PageGeometry`），沒有東西需要被重新分頁 |
| 選同步資料夾 | ✅ 兩邊都有（Apple security-scoped bookmark、Android SAF persistable permission）|
| Google 帳號同步 | ✅ 兩邊都有 |
| 素材圖庫的下載／快取 | ⚪ **刻意不做**，理由見「A-06 收尾」：素材是即時算繪的，沒有遠端伺服器，少一套快取就少一個會過期的狀態 |
| iCloud Drive | ⚪ 平台專有，Android 沒有對應物（它有 SAF 指向任何雲端硬碟）|
| 低延遲畫布 | ⚪ 平台專有（Android `InkSurfaceView` / Apple PencilKit）|

## ☁️ 雲端同步介面對齊（2026-09-16）

使用者回報「Android 的畫面跟 Apple 差蠻大的」。查下來差距不只是長相：

| | Apple（修正前） | Android（修正前） |
|---|---|---|
| 位置 | 設定頁的 Google Drive 區塊 | **編輯器的「⋯」選單裡一項** |
| 首頁看得到嗎 | ❌ 首頁三張卡片講的全是另一條路（自選資料夾）| ❌ |
| 狀態顯示 | 已登入／未登入 | ❌ 沒有 |
| 同步結果 | 上傳 N、下載 M | 只有「同步完成」 |
| 同步中 | 按鈕停用 | ❌ 沒有 |
| **登出** | ✅ | ❌ **完全沒有入口**（`signOut()` 寫好了但沒人呼叫）|

**最嚴重的是登出**：Android 使用者無法解除 Google 帳號授權。

已修正：

| 項目 | 做法 |
|---|---|
| Android 首頁雲端同步卡片 | `HomeScreen.CloudSyncCard`：狀態、訊息、登入／立即同步／登出、說明。位置與 Apple 一致，排在「資料與同步」之前 |
| Android 登出 | 接上 `GoogleAuth.signOut()`（會打撤銷 API，所以在背景執行緒）|
| Android 同步結果 | `CloudSync.runFull` 改回傳 `FullResult`（含 uploaded／downloaded），與 Apple 的 `Report` 對應。只說「完成」的話，使用者分不出「真的傳了東西」與「其實什麼也沒做」|
| Android 同步中狀態 | 按鈕在同步期間停用 |
| Apple 首頁入口 | 「資料與同步」多一張 `googleSyncCard`，描述直接寫**目前狀態**（已登入／未登入）而不是功能介紹 —— 使用者最想知道的是「我到底登入了沒」|
| 兩邊的說明文字 | 新增 `cloud_sync_explainer`，**兩邊同一個語系鍵**。Android 原本誤用了 `sync_explainer`，那一段講的是「自選資料夾」那條路，照著做會去找一個這裡根本不存在的資料夾設定 |

**還沒驗的**：已登入狀態下的畫面（立即同步／登出兩顆按鈕）。要真的 Google
帳號才登得進去，見 G-01。程式面兩邊是同一個 `if`。

## ⚪ 待決策（需要人拍板）

| ID | 問題 | 背景 |
|---|---|---|
| ~~D-01~~ | ~~附件（PDF）是否納入內容定址 blob~~ ✅ **取預設：納入**（2026-09-16，我方決定，可推翻）。同一份講義插進五本筆記只存一份；完整性檢查與 GC 也沿用既有那一套，不必為附件另寫一份 |
| ~~D-02~~ | ~~墓碑 GC 策略~~ ✅ **取預設：永不自動清除**（2026-09-16，我方決定，可推翻）。墓碑是一筆 id + 時戳 + 裝置 id，一萬筆也才幾百 KB；而清早了的代價是**刪除復活** —— 一台離線超過保留期的裝置再上線，會把它那份「還活著」的舊紀錄推回去。省那幾百 KB 不值得換這個 |
| ~~D-03~~ | ~~大型筆記本的 strokes 檔分片閾值~~ ✅ **取預設：不分片**（2026-09-16，我方決定，可推翻）。同步的單位已經是 **oplog 檔**（G-02c），不是 strokes 檔 —— 分片要解決的「整檔重傳」問題在那一層就不存在了。等真的量到讀取延遲再說 |
| ~~D-04~~ | ~~自訂筆（`tool_id` 100+）的參數序列化格式~~ ✅ **取預設：JSON 物件，未知鍵原樣保留**（2026-09-16，我方決定，可推翻）。關鍵是**保留**而不是格式本身：舊版讀到新版寫的筆，不認得的鍵要原封不動存回去，否則在舊裝置上開一次筆記，新參數就被靜靜清空了 |
| ~~D-05~~ | ~~長期維護與營收模式~~ ✅ **已決議：不營收，也不收捐贈**（2026-09-13 決定不營收；2026-09-16 補：**連捐贈連結都不放**）。App 標榜免費，不會有帳號要填，`.github/FUNDING.yml` 已移除。`docs/SUPPORT.md` 保留，說明每年約 US$99 的實際支出與不會做的三件事 |
| ~~D-06~~ | ~~多裝置金鑰首次配對的 UX~~ ⛔ **取消**（2026-09-16）。不做 QR code 配對流程。要重開的話，前提是先確定端對端加密的筆記本要不要跨裝置共享金鑰 |
| ~~D-08~~ | ~~壓感觸發的語意~~ ✅ **已決議：由硬體決定，核心不寫死**（2026-09-16）。核心只回報**正規化後的壓感**與**這支筆實際回報的能力**（有無壓感、有無側鍵、幾段）；行為是一張可設定的對應表。預設：**壓感只影響筆畫粗細與濃度，不觸發任何模式切換** —— 不同筆的壓感曲線差很多，把切換綁在深度上，在某些筆上會變成寫字寫到一半突然換工具。等有實際的筆再把那張表填成要的樣子，不必改程式 |
| ~~D-09~~ | ~~格式互通策略~~ ✅ **已決議：PDF/MD 為主 + 盡力而為的單向匯入**（2026-09-16）。「與 10 款競品完全相容互通」無法達成：多數是專有未公開格式，而且真正的互通需要**對方也讀我們的格式**。細節見 requirements-review.md §6 |
| ~~D-10~~ | ~~Office／Google 文件的呈現方式~~ ✅ **已於 ADR-0009 拍板為「嵌入＋可編輯」**（docx/xlsx 可編輯，pptx 只做預覽）。這一列是遺留的重複條目，S-41 早已完成 |
| ~~D-07~~ | ~~是否採用 Paraformer-zh 與 ct-punc？~~ ✅ **已定案（2026-09-17）：預設改用 Whisper（MIT），ct-punc 退出預設路徑**（[ADR-0013](adr/0013-whisper-as-the-default-asr.md)）。選 C 解決的是 provenance，沒有解決條款衝突本身 —— 同一份權重仍同時掛著 Apache-2.0 與「僅供參考與學習」，而 ct-punc 連 repo 內的授權原文都沒有。**Whisper 自己就會標點**，所以 C5（P0）不再需要 ct-punc，293 MB 的下載與那條最弱的鏈一起消失；而且一個模型覆蓋六個語系。兩個模型沒有移除，改標 `optional`。代價：失去串流 —— 但目前的整合本來就是段級（S-32），今天並沒有真的失去 |
