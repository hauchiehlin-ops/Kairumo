# 開發日誌

> 反序排列（最新在上）。每個開發階段結束時追加一筆。
> 記錄**為什麼**這樣做，而不只是做了什麼 —— 「做了什麼」看 git log 就好。

---

## 2026-09-13 (18) · WP8：出得了可安裝的檔案

### 文件的版本號原本沒人管

WP8 的驗收條件是「`bump-version.sh` 一次更新四處版本（Cargo、Apple、Android、
文件）且無漂移」。檢查的時候發現文件那一處從來沒被納入，而且**已經漂了**：
手冊的英文版停在 2.1.1、其他語言停在 2.3.0，程式是 2.3.4 —— 使用者拿到的
說明書標示的版本跟手上的 App 對不起來。

現在腳本會更新 `manual.js` 與 `privacy.html` 的「適用版本」，並在寫入後驗證
沒有殘留的舊版本號。替換刻意只針對那幾行與行文中明確的 `Kairumo vX.Y.Z`
範例 —— 全檔盲目換數字會動到日期、尺寸與快捷鍵。pre-push hook 也一起提交這兩份。

### 簽章：不做的事比做的事重要

`build.gradle.kts` 從 `keystore.properties`（已忽略）或 `KAIRUMO_*` 環境變數
讀簽章設定。沒設定時 release 版就是未簽章的 —— 這比「靜默用 debug 金鑰簽下去」
好：用 debug 金鑰簽的 AAB 上傳 Play Console 會被拒絕，而錯誤訊息不會告訴你原因。

這支腳本不會替使用者產生正式金鑰，也不把任何密碼寫進版控。上架金鑰弄丟等於
這個 applicationId 再也更新不了，那把鑰匙必須是他自己的。

`--test-sign` 會產一把**拋棄式**金鑰，只為了在本機驗證「簽章 → 安裝 → 啟動」
這條路是通的。它的密碼就寫在腳本裡，所以用完立刻刪掉設定檔 —— 留在原地的話，
之後任何一次 `./gradlew bundleRelease` 都會靜默用它簽，而簽出來的東西
看起來跟正式版一模一樣。

### 不開混淆，而且這是有意識的選擇

UniFFI 的 Kotlin 綁定透過 JNA 以**名稱**對應原生符號。被 R8 重新命名之後
會在執行期才炸開，而且是在使用者手上炸。體積的代價（約 2MB）換一個不會在
半夜出事的發佈版本，值得。

AAB 依 ABI 與密度切分，但**語言不切** —— 六國語系在同一份字串表裡，
切了會缺字。

### 踩到的坑

把 `docs/` 複製進 assets 的那個工作只掛在 `merge*Assets` 上，release 建置直接
被 Gradle 擋下來：lint 會在檔案還沒到位時去讀那個目錄。改成所有會碰到 assets
或 lint 的工作都依賴它。

另外：裝過 release 簽章的版本之後，`connectedDebugAndroidTest` 會以
`INSTALL_FAILED_UPDATE_INCOMPATIBLE` 失敗（簽章不同）。先移除再跑即可，
但錯誤訊息本身看起來像測試壞了。

### 驗證
- `./scripts/android-release.sh --test-sign` 產出 AAB 27MB、通用 APK 81MB
- **release 簽章的 APK 實際安裝到模擬器、啟動、寫得出字**，
  `versionCode=15 / versionName=2.3.4` 與其他所有來源一致
- `./scripts/bump-version.sh` 現在回報「Cargo.toml / project.yml /
  project.pbxproj / build.gradle.kts / 使用者文件 全數對齊」
- Android instrumented 51/51、`cargo test --workspace` 799、
  iOS 與 Mac Catalyst 建置成功

### CI
既有的 Android job 加上「組不簽章的 AAB」與 AAB 產物上傳；另外新增一個跑
instrumented 測試的 job（需要模擬器與 KVM，所以獨立）。**CI 設定沒辦法在本機
驗證**，第一次推上去可能要調。

### 下一步
剩下的都是人要做的：產生正式上傳金鑰、Play Console 建立應用程式、上傳 AAB 到
內部測試軌、隱私權政策填現成那份的網址。以及 `TODO.md` 裡那批實機待測。

---

## 2026-09-13 (17) · WP7：ML Kit 手寫辨識

### 辨識結果只進索引，不碰筆跡

辨識出來的文字寫進核心的搜尋索引（`index_handwriting`），**不會**取代或修改
任何一筆畫。手寫筆記的價值就在那個手寫，辨識只是讓它搜得到。

### 分組：逐筆會垮、整頁會糊

一個中文字往往是好幾筆，逐筆送去辨識會整個垮掉；整頁一次送則會把相隔很遠的
內容硬湊成一句。依**書寫停頓**切分是最接近人怎麼寫字的切法（門檻 700ms，
起點值，需實機以真實書寫節奏調整）。

一個容易寫錯的細節：停頓要從上一筆的**結束**時刻量，不是開始時刻。一筆長橫畫
寫了 600ms、下一筆 100ms 後落下，那是連著寫的；從開始時刻量會算成停了 700ms
而錯誤切開。有測試專門釘這一條。

每一組的文字只掛在該組的**第一筆**上。掛在每一筆的話，搜一個詞會回報好幾個
命中，使用者看到的是一堆重複結果。

### 沒有 Google Play 服務就要講清楚

架構決策 D2 原則上不引入 Google 服務相依，手寫辨識是已接受的例外 ——
裝置端沒有同等品質的替代。代價是沒有 Play 服務的裝置用不了，那種情況
必須明確講出來：靜默失敗的話，使用者會以為是自己的字太醜。

四種失敗各有自己的說法（沒有服務／沒有該語言的模型／下載失敗／辨識失敗），
有測試確認每一句都講得出使用者能據以行動的內容。模型只在 Wi-Fi 下下載 ——
數 MB 的模型用行動網路默默抓，不是我們該替使用者做的決定。

### 踩到的坑

`RecognitionContext.builder().build()` 看起來像個合理的預設值，實際上辨識時會丟
`Missing required properties: preContext`。我們本來也沒有前文可給（這是整頁
手寫，不是輸入法的接續輸入），改用不帶 context 的多載。

**這個錯是使用者自己看到的** —— 訊息直接出現在畫面上，而不是靜默什麼都沒發生。
那個設計當場就回本了。

### 驗證
- Android instrumented **51/51**（新增分組 4、Ink 轉換 2、語言模型 2、失敗訊息 1、
  索引與搜尋 1）
- 模擬器實機操作：寫三筆 → 選單「辨識手寫」→ 模型自動下載 → 回報
  `Indexed 3 group(s): 1l1`（三條斜線辨識成 1、l、1，合理）
- 「辨識結果進入索引且搜得到」用固定文字走同一條回填路徑做成確定性測試 ——
  自動化測試裡不去測 Google 的服務
- `cargo test --workspace` 799、iOS 與 Mac Catalyst 建置成功

### 待實機
中英文各 20 句的辨識率要在實機用真的筆寫才算數，已列入 `TODO.md`。

---

## 2026-09-13 (16) · WP6：Android 平台功能

### 先問清楚核心到底還給不給得出東西

Android 版關掉了 `asr` 與 `pdf` 兩個 feature。「綁定裡有這個函式」不等於
「它在這台裝置上會動」，所以先寫了 `CoreCapabilityTest` 實測而不是從函式名單
推論。結果：

| 能力 | 狀態 |
|---|---|
| 匯出 PDF／單頁 PDF | 可用（`%PDF` 檔頭、內容 > 500 位元組） |
| 匯出 PNG | 可用（合法 PNG 簽章） |
| 匯出 Markdown | 可用 |
| 列印資料 | 可用 |
| **錄音** | **可用** |
| 全文搜尋 | 可用 |

**關鍵發現：`asr` 關掉的是轉錄，不是錄音。** libopus 有交叉編譯進來，
`feed_audio` 確實寫得出音框。所以「第一版不含語音轉錄」不該連錄音都做不了 ——
差點就照字面把錄音一起砍掉。

`pdf` feature 關掉的是 PDFium（**讀** PDF），與匯出 PDF 不是同一件事 ——
匯出是 `padnote-export` 自己產的。

### 匯出全部走核心

PDF、PNG、Markdown、列印資料都是核心產生的，平台層只負責落檔與交給系統面板。
理由是 Apple 端剛踩過的坑：匯出若在平台層另外畫一次，畫出來的東西遲早會跟
畫布上的不一樣（那次是整頁空白）。

分享的兩個細節各有測試守著：URI 必須走 `FileProvider`（`file://` 丟給別的 App
在 Android 7 之後直接丟例外），以及 `FLAG_GRANT_READ_URI_PERMISSION` 不能漏
（漏了的話接收方拿到一個開不起來的連結，而寄件者這邊完全看不出問題）。
匯出檔只放 App 私有 cache，不落外部儲存 —— 那是使用者的筆記內容。

### 說明文件：一份來源，兩個平台

手冊與隱私權政策由 Gradle 在建置時從 repo 的 `docs/` 複製進 assets。

第一版直接把整個 `docs/` 掛成 assets 目錄 —— 結果 DEVLOG、TODO、STATE、ADR、
內部計畫全都進了 APK。改成只複製 `manual/` 與 `legal/` 兩個子目錄，
並加一條測試專門擋這次手滑。

另一件事：這兩份文件是為了網頁發佈而寫的**片段**（沒有 `<html>`，也沒有
viewport meta）。直接 `loadUrl` 的話 WebView 會用桌面寬度排版，手機上整頁縮成
看不清的小字。`DocsViewer` 補上最小外框與 viewport，並保留 asset 的 base URL
讓 `manual.js` 與 `img/` 的相對路徑還找得到。

### 工具列重做：功能點不到就等於沒做

第一版把所有動作排成一列再讓它水平捲動。在 320dp 寬的螢幕上，錄音、匯出、
列印、手冊全部被推到畫面外，而且捲不太動 —— 也就是 WP6 做的東西一個都碰不到。
改成兩個切換留在列上、其餘進溢位選單。過程中還發現「兩個切換 + 兩個按鈕」
就足以把最右邊那個擠出畫面，而被擠掉的永遠是最後加上去的那個。

說明文件也從 `AlertDialog` 改成全螢幕 `Dialog`：文件是要「讀」的，
塞進固定高度的小框裡，使用者看到的是一小條白色。

### 驗證
- Android instrumented **41/41** 通過（新增能力探測 7、匯出 7、文件打包 5）
- 模擬器實機操作：開選單 → 匯出 PDF，畫面回報
  `Exported: kairumo-….pdf`，檔案確實落在私有 cache（2,809 位元組）；
  手冊在全螢幕下正確排版，語言下拉與目錄都在
- `cargo test --workspace` 799、iOS 與 Mac Catalyst 建置成功

### 待實機
錄音在模擬器上沒有麥克風可測。程式路徑（權限請求 → `AudioRecord` 16kHz 單聲道
float → `feed_audio`）已就緒，核心端有實測憑據，實機驗證列在 `TODO.md` 的 A-07。

---

## 2026-09-13 (15) · 修正：實機上畫布全白

### 先更正一件事

上一則把「模擬器截圖是白的」解釋成「`screencap` 抓不到前緩衝圖層」。
**那個判斷是錯的。** 實機回報一模一樣的徵狀 —— 畫布全白 —— 證明前緩衝路徑
根本沒把墨跡顯示出來，而我當時把一個真實的失敗合理化掉了。

### 真正的原因：Kotlin 的名稱遮蔽

`drawStroke` 是寫在 `Canvas` 上的擴充函式。函式內的 `density` 解析到的是
**`Canvas.density`**（接收者的成員蓋過外層類別的屬性），而不是建構子傳進來的
螢幕密度。未設定的 `Canvas.density` 是 0，於是：

```
drawLine(a.x * density, …)   // 全部乘成 0 —— 整條筆畫塌到原點
paint.strokeWidth = … * density   // 線寬 0
```

編譯器不會有任何警告，畫面上就是一片空白。

找出來的方式不是讀程式碼，是把多重緩衝層的底色暫時改成淡黃色 ——
畫布變黃就代表表面看得見、問題在筆畫；還是白的就代表表面被蓋住。
一次建置就把可能性砍半。接著印出 `paint.strokeWidth`，`sw=0.0` 直接指到兇手。

欄位已改名為 `pxPerDp`，這個遮蔽陷阱不會再犯第二次。

### 另外兩個實機才看得到的問題

**SurfaceView 預設在視窗底下。** 靠在視窗上打洞才看得見，而 Compose 的
`Surface` 會畫一層不透明底色把洞蓋住。加上 `setZOrderOnTop(true)` 與
半透明格式才顯示得出來。（這是「白色」那一層；上面那個 bug 是「空白」那一層 ——
兩個問題疊在一起，所以單改一個都看不出進展。）

**「ⓘ」不是每個裝置的字型都有。** 沒有的話按鈕變成一塊看不見的區域 ——
實機上使用者就是「找不到右上角的按鈕」。改成文字 `Info`。

### 預設改回一般畫布

低延遲預設**關閉**。它還沒在實機上驗過，不能擋在使用者與「能不能寫字」之間；
已經驗過會動的那條路才該是預設值。要試的人自己打開，兩條路徑可以直接互比。

### 畫面上加了診斷列

`tool=1 r=0.0dp p=0.00 d=1.0 draw=1 rej=0 ges=0`

使用者手上的裝置我碰不到，所以一張截圖必須要能告訴我平台回報了什麼 ——
工具類型、換算後的接觸半徑、壓感、密度、仲裁結果。沒有這條線，遠端除錯只能用猜的。
順帶把「事件回報」改成每個事件都報，不是只有畫得出東西時 ——
被拒絕的那些才是要診斷的。

### 驗證
- 模擬器逐像素檢查：修正前畫布區只有一種顏色（底色），修正後出現 1,056 個
  純黑像素與抗鋸齒灰階 —— 兩條路徑都真的畫得出墨跡
- Android instrumented 22/22、`cargo test --workspace` 799、iOS 與 Mac Catalyst 建置成功

### 仍未解釋
實機回報「Stylus Only 按不動」。低延遲預設關閉之後畫面上不會有 SurfaceView，
若仍然按不動就是另一回事 —— 新增的診斷列會顯示觸控事件有沒有進到畫布。

---

## 2026-09-13 (14) · WP5c/d：前緩衝渲染與預測筆跡

### 預測筆跡只進畫面，永不進資料

`MotionEventPredictor` 猜的是「筆接下來大概會到哪」，用來補「手已經到了、
畫面還沒跟上」的視覺落差。它是**猜測**，不是使用者真的寫下的東西。所以
預測點只畫到前緩衝，絕不餵給 `InkEngine`、絕不進 `.padnote` —— 寫進去的話，
使用者的筆記裡會混進他沒寫過的線條。這是既有的架構不變式，不是這裡的臨時決定。

實作上還有一個容易漏的細節：畫完預測線**不更新**「最後一個點」。更新的話，
下一段真實軌跡會從猜測的位置接續，誤差一路累積下去。

### 延遲量測：先說清楚它量的是什麼

新的 `InkLatencyMeter` 量的是「取樣點在硬體上發生的時刻
（`getEventTimeNanos`）→ App 把它交給合成器」。**這不是筆尖到光子的完整延遲**，
面板本身的掃描與亮起時間量不到，那要靠高速攝影機。

說清楚比給一個好看的數字重要：拿它去跟別家 App 的「延遲」比較，只有在對方
用同一個定義時才有意義。它真正有用的是**同一台裝置上開關前緩衝的前後對比**。

量測器本身也有測試守著三件事：`percentile(100)` 不能越界（那正是最該看的
最差情況）、時鐘不同源算出的負延遲要丟掉而不是汙染統計、緩衝區不能無上限
成長（連續書寫十分鐘不該讓量測器自己變成記憶體問題）。

### 失敗時要退回去，不是黑畫面

各家 OEM 對前緩衝的支援不一致。建不起來就回報 `false`，UI 自動退回一般的
Compose 畫布並顯示一行說明。手寫可以比較鈍，但不能不能用。使用者也能手動
切換開關，直接比較兩條路徑。

### 踩到的坑

**按「清除」只清資料不夠。** 前緩衝與多重緩衝各自持有已經畫上去的像素，
不主動清的話，按了清除畫面還是舊的墨跡，要等下一次抬筆才更新。

**多重緩衝層每次 commit 都是全新的緩衝。** 只畫「這次新增的」的話，抬筆瞬間
先前的筆畫會整片消失 —— 要重畫全部內容。

**窄螢幕上工具列把畫布推下去。** 標題加了 `weight(1f)` 被擠成一欄一個字，
整個版面塌掉。工具列改成水平捲動，而資訊鈕留在捲動區外 —— 它被推出畫面的
時候，正好就是使用者要看延遲數字的時候。

### 驗證（模擬器能驗的部分）
- Android instrumented 測試 **22/22** 通過（新增 4 條延遲量測）
- 模擬器實測：前緩衝渲染器成功建立、線段與多重緩衝重畫都確實被呼叫、
  筆畫數正確、「清除」會清空
- iOS 與 Mac Catalyst 建置皆 **BUILD SUCCEEDED**

**模擬器驗不了的部分**：前緩衝圖層不會出現在 `screencap` 的畫面裡，而延遲數字
在模擬器上（p50 44ms）反映的是 `adb input` 的注入速率與模擬器的合成，
不是真實硬體的表現。實機加觸控筆的實測結果待補。

---

## 2026-09-13 (13) · WP5a/b：Android 筆跡輸入與畫布

### 掌拒不寫第二份

核心早就有 `padnote-input` 的 `PointerArbiter`，而且已經透過 `InkArbiter`
開到 FFI。Android 沒有理由再寫一套判定邏輯 —— 那會變成「同一支筆在兩個平台
行為不一樣」，而且是那種只有使用者會發現的不一樣。所以 Kotlin 這一層只做
**如實轉換**：`MotionEvent` → `FfiPointerEvent`。

### 轉換層有三個錯了不會當掉的地方

1. **只讀 `getX()` 會掉點。** S Pen 取樣率遠高於畫面更新率，一個
   `ACTION_MOVE` 裡通常塞著好幾個歷史取樣點。不讀 `getHistorical*`，
   快速書寫就會變成折線。測試裡塞了三個歷史樣本，斷言四個點一個都不能少。
2. **接觸半徑要換成 dp。** 核心的手掌門檻是 22「點」。直接餵 px，在 3x 螢幕上
   連筆尖都會被當成手掌 —— 而在 1x 的模擬器上完全正常。這種錯最難在開發機上
   發現，所以測試直接釘住 1x 與 3x 兩組數字。順帶：`touchMajor` 是**直徑**，
   核心要的是長半徑。
3. **`AXIS_ORIENTATION` 是 -π..π，核心要 0..2π。** 負值會被核心夾成 0，
   於是扁筆頭的方向在螢幕左半邊全部錯，而且不會有任何錯誤訊息。

### 測試抓到核心的一個真實缺口

原本寫的掌拒測試是「手掌碰一下、抬起、筆才落下」，結果失敗 ——
`retract_suspects` 只看 `active`，而已經抬起的指標在 `on_ended` 就被移除了，
收不回來。

這不是測試寫錯。使用者把手放上螢幕時，手掌常常是「碰一下、滑一小段、
隨著手安定下來抬起」，接著筆才落下 —— 那一小段在筆落下之前就結束了，
畫面上留下一道誰也不知道哪來的短線。模組註解自己寫著「只擋得住一半的情況」，
指的就是這個。

修法：`PointerArbiter` 多留一個 `recent_draws`，記住**剛結束**且被採納為墨跡的
非筆指標，收回時間窗內一併回報。配套四條測試：超出時間窗的舊筆畫不能被抹掉、
同一筆畫不能被收回兩次（平台層會去刪第二次，可能誤刪別的）、已經被擋掉的
不該回報（去刪一個不存在的東西）、換頁後要忘記上一頁。

### 畫布走原始事件，不走 Compose 手勢

`pointerInteropFilter` 而不是 Compose 的指標事件：Compose 的手勢層已經把歷史
取樣點合併成「這一幀的位置」了。手寫必須拿原始 `MotionEvent`。

寬度用核心 `half_width()` 的同一條公式 `base × (0.35 + 0.65 × pressure)`，
與 Apple 端的轉換器同源 —— 同一筆畫在兩個平台粗細才一樣。

### 驗證
- `cargo test --workspace`：799 通過（`padnote-input` 由 33 增為 38）
- Android instrumented 測試 **18/18** 在模擬器上通過，含：
  手掌（接觸半徑 45dp）不產生任何筆畫、筆畫寫進 `.padnote` 後重開讀得回來、
  被收回的筆畫重開後不會復活、歷史取樣點不掉點、dt 夾在 65535µs
- 模擬器實機操作：畫 6 筆有 6 筆；開啟「僅限觸控筆」後手指畫出 0 筆
- iOS 與 Mac Catalyst 建置皆 **BUILD SUCCEEDED**

instrumented 測試而非純 JVM 測試是刻意的：`MotionEvent` 的建構與歷史點機制
只有真的 Android runtime 才有，用 mock 測這一層等於在測自己寫的假物件。

### 還沒做
- **WP5c 前緩衝渲染**（`androidx.graphics.lowlatency`）與 **WP5d 預測筆跡**
  （`MotionEventPredictor`）。這兩項的效果是**延遲**，模擬器上量不出來，
  各家 OEM 對前緩衝的支援也不一致。沒有實機與觸控筆就驗不了，
  所以先不寫 —— 寫一段驗不了的程式碼，只是把風險藏起來。

---

## 2026-09-13 (12) · WP4c：儲存層遷移（先寫回滾，再動資料）

### 這一步的規則寫死，不留彈性

這是整個 WP4 裡唯一會碰到使用者真實資料的一步，所以 `NotebookMigration`
的每一條規則都是硬性的：

1. **原始檔案一律不覆蓋、不刪除。** 遷移只讀 `notebooks_v1.json` 與
   `Drawings/`，產物寫到 `Documents/Packages/`。有一條測試逐檔比對位元組，
   確認遷移前後原檔完全相同。
2. **動手前先備份。** 備份失敗就整個停手 —— 沒有退路的遷移不該開始。
3. **每一本都要驗過才算數。** 匯出完立刻讀回來，逐頁比筆畫數、逐筆比取樣點數、
   逐點比座標。驗不過的那一本把套件**刪掉**並記成失敗：留下一份看起來成功、
   其實內容不對的檔案，比明確失敗更危險 —— 使用者會信任它。
4. **一本失敗不影響其餘**，報告逐本交代結果與原因。
5. **可重入**：重跑不會產生重複，也不會白做已經遷好的。
6. **可回滾**：從備份還原並清掉產物。

### 指紋不能只看修改時間

可重入要靠內容指紋判斷「這本變了沒」。第一版想用 `lastModifiedDate` ——
錯的。手繪是存在獨立的 `.drawing` 檔，改手繪**不會**更新那個日期，
所以使用者畫了一整頁之後重跑會被判定成「沒變」而跳過。指紋改成
修改時間 + 每頁筆畫數 + 附件數，並有一條測試專門釘住這件事。

另一個相關的坑：核心是 append-only 的，舊套件沒清掉就重匯，內容會**疊起來**
（2 筆 + 3 筆變成 5 筆）。重跑前先刪舊套件，也有測試守著。

### 測試自己寫錯的那一條

`testRerunningSkipsUnchangedNotebooks` 第一次是紅的。原因是測試每次呼叫
`sampleDocuments()` 都產生新的 `lastModifiedDate`（預設 `Date()`），
兩次各叫一次等於資料真的變了 —— 那樣測到的是「有變就重做」，
不是這條要測的「沒變就跳過」。改成兩次餵同一批文件。

### 有按鈕，使用者才碰得到

能力建好卻沒開到使用者面前，等於沒建 —— 這個坑先前踩過。所以在
「系統診斷與版本資訊」裡加了「跨平台格式」區塊：狀態、轉換按鈕、
失敗逐本說明、還原備份、以及一句說明「原始筆記不會被更動」。
放診斷頁而不是主畫面：這是進階動作，不該是使用者第一天就會按到的東西。

遷移**不會在啟動時自動執行**。在啟動路徑上偷偷跑一次會動到使用者的資料，
而且出事時他們連自己做過什麼都不知道。

UI 測試從選單一路按到轉換完成，確認狀態列真的變成「已轉換 N 本」且無失敗。
過程中順手把首頁選單與轉換按鈕加上 accessibility identifier —— 原本靠
`label CONTAINS 'ellipsis'` 去猜，會先命中筆記卡片上的那個「⋯」。

### 型別名稱長度（iOS 閃退的那個舊帳）

新增的區塊會進 `AppDiagnosticsSheet.body` 的型別名稱，所以量了一次：
editor 7,102、home 6,523、diagnostics 1,988 字元。當初造成 iOS 閃退的是
89,768，距離很遠。

### 驗證
- `cargo test --workspace`：794 通過、0 失敗
- `KairumoTests`：40 條全過（遷移與回滾 16 條）
- `KairumoUITests`：含新增的遷移流程，全過
- iOS 與 Mac Catalyst 建置皆 **BUILD SUCCEEDED**
- Android `assembleDebug` 成功（字串表同步到 440 條）

### 還沒做的
App 的**讀取路徑**仍走既有的 JSON + `.drawing`。把讀取切到核心格式是另一件事，
而且要在使用者實際跑過遷移、確認產物無誤之後才值得談 —— 在同一次改動裡
既搬資料又換讀取來源，回滾就失去意義了。

---

## 2026-09-13 (11) · WP4b：iOS 匯出的 `.padnote`，在 Android 上打得開

### 驗收條件達成了

「iOS 建立的多頁筆記（含手寫、文字方塊）在 Android 開啟後，筆畫數、座標、
顏色與頁面高度與原稿一致。」這句話現在有實測憑據，不是推論：

| 項目 | iOS 原稿 | Android 讀到 |
|---|---|---|
| 標題 | 跨平台測試筆記 | 跨平台測試筆記 |
| 頁數 | 2 | 2 |
| 第 1 頁 | 2 筆畫、預設高 | 筆畫 2、高 1800pt |
| 第 1 頁首筆 | 紅、起點 (10, 200)、12 點 | RGBA(255,0,0,255)、(10.0, 200.0)、12 點 |
| 第 2 頁 | 1 筆畫、拉長到 3200pt | 筆畫 1、高 3200pt |
| 第 2 頁首筆 | 綠、起點 (40, 200)、12 點 | RGBA(0,255,0,255)、(40.0, 200.0)、12 點 |

流程是完整的那條：Swift 的 `NotebookDocument` → 核心 `.padnote` 套件 → 落到
磁碟 → 搬到 Android 模擬器 → Kotlin 用同一個核心開起來。

### 補上格式的兩個缺口

做到一半才發現核心格式根本存不下兩樣東西，而且兩樣都在驗收條件裡：

**頁面尺寸。** `Page.size` 存在，但沒有任何 `DocOp` 寫得進去。Kairumo 的畫布
可以向下延長，使用者拉到 3200pt 的那一頁若沒落盤，另一個平台會看到一頁被截短
的筆記。新增 `SetPageSize`（op 30）。

**區塊座標。** `Block.position` 同樣存在卻沒有對應操作 —— 文字方塊與圖片的擺放
位置進不了 op-log，跨平台打開會全部擠在一起。而且**在原本的平台上看不出來**，
因為位置是另外存在 JSON 裡的。新增 `SetBlockPosition`（op 31）。

還補了 `page_id_at(index)`：在此之前平台層只拿得到第一頁的 id，多頁筆記走不完。

`format-spec.md` 的操作清單同步更新（順帶補上先前漏記的六個表格操作，實際是
31 種而非文件寫的 21 種）。`covers_all_op_tags` 這條測試在我加完 op 卻沒更新
清單時立刻紅了 —— 它就是為此存在的。

### 匯出是新增的路徑，不是替換

`NotebookPackageBridge` 只讀 `NotebookDocument` 與 `PKDrawing`，另外寫一份套件。
現有的 JSON + `.drawing` 讀寫一行都沒改，使用者手上的資料不會被動到。
儲存層的正式遷移（含備份與回滾）排在下一步 —— 那才是會碰到真實資料的改動，
不該跟轉換器的對錯混在同一次。

### 踩到的坑

**adb push 進 App 專屬外部目錄，App 自己反而讀不到。** 推進去的檔案屬於 shell，
App 得到的錯誤訊息是「不是 .padnote 套件」—— 看起來像檔案壞了，其實是權限。
改用 `adb shell run-as` 解壓進內部 `filesDir`。

**讀不到某張圖不該讓整本筆記匯不出去。** 缺一張圖，跟整份匯出失敗，對使用者是
完全不同等級的損失。缺的附件略過，其餘照常匯出，並在摘要裡回報實際帶出去幾張。

**Swift 型別推導在內嵌算式上會直接放棄。** 測試資料裡一行 `CGSize(width: 6 -
CGFloat(i) * 0.25, …)` 就讓編譯器丟出 "unable to type-check this expression in
reasonable time"。把中間值先算出來即可。

### 驗證
- `cargo test --workspace`：794 通過、0 失敗
- `KairumoTests`：23 條全過（`InkInterop` 14 + `NotebookPackageBridge` 9）
- Android 模擬器實測：見上表
- iOS 與 Mac Catalyst 建置皆 **BUILD SUCCEEDED**

### 下一步
WP4c：儲存層遷移。先寫遷移與回滾的測試，再動 `NotebookStore` —— 這一步會碰到
使用者手上的真實資料，備份與可回滾是前提。

---

## 2026-09-13 (10) · WP4a：筆畫轉換器與往返保真度

### 這一步只做「證明得了」的部分

WP4 的驗收條件是「iOS 建立的筆記在 Android 打開後，筆畫數、座標、顏色與原稿
一致」。要能檢查這句話，得先有兩樣東西：核心能把筆畫**完整**吐回來，以及
Apple 端有一個 PKDrawing ⇄ 核心格式的轉換器。這一步先把這兩樣做出來並釘上
測試；儲存層的實際遷移（含備份與回滾）留到下一步，因為那會動到使用者手上的
真實資料，不該和轉換器的對錯混在同一次改動裡。

### 核心：`FullStroke` 與 `visible_stroke_details`

原本的 `visible_strokes` 刻意只回傳摘要（id、點數、外框）—— 一頁數萬個點過
FFI 很慢，渲染路徑本來就不該走那裡。但摘要驗不出座標錯位、壓感遺失、筆刷對應
寫反這些錯，所以另開一條互通專用的出口 `FullStroke`，把每個取樣點原樣帶出來。
兩者的分工寫進了註解，免得日後有人拿 `FullStroke` 去做渲染。

### 壓感不從 `PKStrokePoint.force` 取

直覺寫法是 force 夾到 0–1 當壓感。實際上 PencilKit 沒有公開 force 的數值範圍，
手指與 Apple Pencil 也不一致，硬夾的結果是重壓的筆畫整段飽和。改成從
PencilKit **實際畫出來的每點寬度**回推 —— 依核心 `half_width()` 的
`width = base × (0.35 + 0.65 × pressure)` 反解。這樣 Android 端用同一條公式
畫出來的粗細，才會跟 iPad 上看到的一樣。測試逐格掃過 0–1 確認兩個方向互為反函數。

### 踩到的坑

**tilt 與 altitude 是互補角，不是同一個東西。** PencilKit 的 altitude 是
「筆與螢幕平面的夾角」（π/2 為垂直握筆），核心的 tilt 是「偏離垂直的角度」。
直接對接的話，筆越立起來核心會以為越躺平 —— 而且畫面上完全看不出來。

**第一版 Rust 測試紅在測試自己身上。** 我把 pressure / tilt / azimuth 也寫成
位元組相等，結果失敗。格式規格 §5.4 明訂這三個欄位各用一個 u16 定點數儲存
（整點 16 bytes），本來就有量化誤差。把期望改成「誤差不超過一個量化格」，
這條測試才擋得住真正的錯（欄位接錯、角度用錯最大值）。同樣地，Swift 端的
altitude 容差要放到 1e-4：PKStrokePoint 存 0.6 讀回來是 0.60001…，那是
PencilKit 的儲存精度，收得比它還小只會紅在一個不能也不該修的地方。

### 新增 Apple 單元測試 target

轉換器是純邏輯，塞進 UI 測試裡跑很浪費。新開 `KairumoTests`（`apple/Tests`），
14 條測試在 0.02 秒內跑完。UI 測試維持原樣。

### 對現有 Apple 功能的影響：無

`InkInterop` 是一組純函式，沒有被畫布或 `NotebookStore` 呼叫 —— 現有的
iOS / iPadOS / macOS 路徑一行都沒改。核心那邊是新增兩個方法，既有 API 不動。

### 驗證
- `cargo test --workspace`：790 通過（新增 5 條 `s47_ink_interop`）、0 失敗
- `KairumoTests`：14 條全過
- iOS 與 Mac Catalyst 建置皆 **BUILD SUCCEEDED**
- Android `assembleDebug` 成功（`.so` 與 Kotlin 綁定已用新 FFI 重新產生）

### 下一步
WP4b：把轉換器接上實際的匯出／匯入 —— 從 `NotebookStore` 產生一份 `.padnote`
套件，並在 Android 端開起來比對。儲存層的正式遷移排在那之後。

---

## 2026-09-13 (9) · WP3c：介面字串收斂成單一來源

### 為什麼要動這 430 條字串

它們原本只活在 `LocalizationManager.swift` 的字典字面值裡。Android 一旦自己
再寫一份，同一句話就有兩個版本 —— 改了一邊忘了另一邊只是時間問題，而且是那種
上架後才被使用者發現的錯。所以收斂成 `i18n/ui-strings.json`，由
`scripts/i18n_tool.py` 同時產生 Swift 與 Kotlin 兩份表。

硬前提是不影響 Apple 現有行為，所以做法刻意保守：**產生出來的字與原本逐字相同**，
`LocalizationManager.localized(_:)` 的公開簽名與回退順序（目前語系 → en → 繁中 →
key 本身）一個字都沒動，只是字典改從產生檔取。

### 憑據不是「我覺得一樣」

`i18n_tool.py verify` 把產生的 Swift 檔與 Kotlin 檔各自**讀回來**再跟 catalog
逐條比對，三者必須完全相同才算過。這條檢查也進了 pre-push hook —— 有人手改產生檔
就會在推送前被擋下來。

### 踩到的坑：跳脫被做了兩次

第一次 verify 就抓到 4 條不一致。原因是從 Swift 抽出來時把 `\"` 當成兩個字元
原樣收進 catalog，輸出時 `swift_escape` 又跳脫一次，變成 `\\"` —— 畫面上會多出
反斜線。修法是讓「還原跳脫」只發生在讀取端、「跳脫」只發生在輸出端，各一次。
這正是為什麼要有 verify：肉眼看 430 條 JSON 不會看出這種差別。

### 順手補掉的漏洞：Android 沒進版本腳本

`bump-version.sh` 當初只顧 Cargo 與 Apple 專案檔。新加的 `build.gradle.kts`
沒被納入，就會重演 v1.4.0 那次的版本漂移，只是換個平台。現在版本來源、寫入與
寫入後驗證都包含 Android，pre-push hook 也會一起提交它。Android 畫面上的版本號
改讀 `BuildConfig`，不再是手寫的字串。

### 驗證
- `cargo test --workspace`：785 通過、0 失敗
- iOS（generic/platform=iOS）與 Mac Catalyst 建置皆 **BUILD SUCCEEDED**
- Android `assembleDebug` 成功，裝到模擬器實測畫面顯示「字串表：430 條」、
  示例字串正確取到 `about_app`
- `i18n_tool.py verify`：Swift 與 Kotlin 產生表都與 catalog 完全一致（430 條）
- XCUITest 冒煙測試：4 項全過（**TEST SUCCEEDED**）

順帶修掉一件會讓上面這條驗證形同虛設的事：`KairumoUITests` 少了
`GENERATE_INFOPLIST_FILE`，`xcodebuild test` 會在簽章階段就失敗 —— 那不是
「測試失敗」，是測試根本沒跑，而錯誤訊息長得很像單純一則 build 警告。

### 下一步
WP4 檔案互通：把 Apple 端的儲存層換成核心格式（含 PKDrawing → `add_stroke`
轉換器與資料遷移），兩邊的筆記檔才真的能互開。

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
