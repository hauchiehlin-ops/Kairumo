/*
 * Kairumo 操作手冊（Apple 平台版）
 * 適用：iOS · iPadOS · macOS
 * 本檔案由 scripts/build-platform-docs.py 自動產生，請勿手動修改。
 * 來源：docs/manual/manual.js
 */

window.KAIRUMO_MANUAL = {
  "figsets": {
    "zh": [
      "zh-Hant",
      "zh-Hans"
    ],
    "en": [
      "en",
      "ja",
      "ko",
      "th"
    ]
  },
  "zh-Hant": {
    "name": "繁體中文",
    "figset": "zh",
    "ui": {
      "docTitle": "Kairumo 操作手冊",
      "tagline": "手寫、打字、錄音三合一的筆記本。零基礎也能一步一步跟著做。",
      "version": "適用版本 v4.8.0（build 58）· 2026 年 9 月 19 日",
      "tocTitle": "目錄",
      "tocHint": "點任一項目直接跳到該段落",
      "stepsLabel": "操作步驟",
      "tipLabel": "小提醒",
      "buttonsLabel": "會用到的按鈕",
      "figNote": "截圖為繁體中文介面",
      "backToTop": "回到目錄",
      "langLabel": "語言",
      "privacyLink": "隱私權政策"
    },
    "sections": [
      {
        "id": "start",
        "title": "開始之前",
        "lead": "Kairumo 是一本把手寫、打字與錄音放在同一條時間軸上的筆記本。完全免費、開放原始碼，資料留在你自己的裝置上。",
        "buttons": [],
        "steps": [
          "平板、手機與桌機都能用；手寫用觸控筆最順，用手指或滑鼠一樣可以寫。",
          "第一次打開不需要註冊帳號，也不需要網路連線。",
          "第一次打開會有兩本範例筆記（「歡迎使用 Kairumo」與「課堂與會議記錄」），裡面是可以直接改的圖、文、表範例。不需要就整本刪掉。",
          "你寫下的每一筆都存在這台裝置裡。要在多台裝置之間同步，就挑一個自己的雲端硬碟資料夾（見「資料備份與同步」）。",
          "桌機版視窗左上角會顯示版本號（例如 Kairumo v4.8.0），回報問題時請附上它。"
        ],
        "tip": "沒有伺服器、沒有帳號，就沒有「忘記密碼」這回事 —— 但也代表裝置遺失時沒有雲端副本，請自己做備份。",
        "fig": null
      },
      {
        "id": "firstrun",
        "title": "第一次打開",
        "lead": "第一次啟動會先用一頁講清楚要哪一個權限、為什麼要。看完就進首頁，之後不會再出現。",
        "buttons": [
          "允許使用麥克風",
          "稍後再說",
          "開始使用"
        ],
        "steps": [
          "這一頁講三件事：Kairumo 是什麼、不需要帳號也沒有我們的伺服器、以及唯一會用到的那一個權限。",
          "只有**麥克風**一個權限，而且只有錄音會用到。不給也可以 —— 手寫、打字、匯出、同步全都不受影響。",
          "按「允許使用麥克風」才會跳出系統的權限對話框。那個對話框**一個 App 一輩子只會出現一次**。",
          "如果當下按了不允許，按鈕會換成「前往設定」。那之後只能從系統設定裡把權限打開，App 自己沒有辦法再問你一次。",
          "按「開始使用」進入首頁。這一頁之後不會再出現。"
        ],
        "tip": "權限不會在安裝的時候就要 —— 系統一律等到真的要用那個功能才問。所以還沒給權限就按錄音的話，會在那個當下再引導一次。",
        "fig": null
      },
      {
        "id": "home",
        "title": "首頁：你的工作台",
        "lead": "打開 App 看到的第一個畫面。所有筆記、錄音、素材與匯入檔都從這裡進入。",
        "buttons": [
          "編輯身分",
          "新增筆記",
          "開始錄音",
          "素材圖庫",
          "匯入筆記"
        ],
        "steps": [
          "最上方是你的顯示身分 —— 協同時隊友看到的就是這個名字，點右邊的「編輯身分」可以修改。",
          "搜尋列可以同時搜尋筆記標題、打字內容與錄音轉錄出來的文字。",
          "中間四張大卡片是主要動作：新增筆記、開始錄音、素材圖庫、匯入筆記。",
          "「匯入筆記」可以選一個 .padnote 檔，把別人分享給你的原始筆記放進筆記庫。",
          "「繼續」列出最近開過的筆記，點一下就回到上次的位置。",
          "「全部筆記」依資料夾分類顯示；右上角可以切換排序方式。",
          "首頁往下捲到底有「操作說明」與「隱私權政策」兩張卡片 —— 你現在看的就是前者。",
          "首頁錄音列每一列右邊的「⋯」裡有「插入至筆記本」，可以挑筆記本與頁次，把這段錄音放到那一頁上。"
        ],
        "tip": "每張筆記卡片右上角的「⋯」裡有重新命名、移動到資料夾與刪除。",
        "fig": "home",
        "cap": "首頁：身分、搜尋、四個主要動作、繼續、全部筆記"
      },
      {
        "id": "newnote",
        "title": "建立第一則筆記",
        "lead": "三十三種筆記頁樣板，分成七組；版面顏色也可以自己挑。",
        "buttons": [
          "新增筆記",
          "筆記頁樣板",
          "版面色彩",
          "確認"
        ],
        "steps": [
          "在首頁點「新增筆記」。",
          "在「筆記標題」欄輸入名稱。不填也可以，之後隨時能改。",
          "「筆記頁樣板」上排是主題膠囊，七組一次全部列出來、不必左右滑：通用基礎、筆記方法、規劃排程、清單追蹤、美學視覺、工程製程、數位體驗。",
          "點一個主題，下面就換成那一組的樣板清單，每一種都有一行說明它適合做什麼。",
          "「筆記方法」那一組是有結構的記法：康乃爾（提示欄／筆記欄／摘要）、四象限（重點／問題／決議／行動）、大綱（三層縮排）、雙欄對照、一問一答、KWL、心智圖。",
          "「規劃排程」與「清單追蹤」是月計畫、週計畫、日程表、24 小時時間軸、學習計畫、專案時程、待辦清單、勾選清單、習慣追蹤、作業追蹤、家事分工、21 天挑戰。",
          "最下面是「版面色彩」六個色點：石墨、靛藍、青綠、玫瑰、琥珀、森綠。選哪一個，版面的線條、標題底色與欄位名稱就跟著換。",
          "點右上角「確認」，筆記會立刻打開，可以直接開始寫。"
        ],
        "tip": "樣板只是版面，換掉不會影響已經寫下的內容。而且進去之後**每一頁還可以各用各的樣板** —— 見「頁面與資料夾」。版面色彩是整本一個調子，隨時在編輯畫面上排改得動。",
        "fig": "newnote",
        "cap": "新增筆記本視窗：標題、主題膠囊、樣板清單與版面色彩"
      },
      {
        "id": "editor",
        "title": "認識編輯畫面",
        "lead": "先花一分鐘認位置，後面每一步都會用到。",
        "buttons": [
          "首頁",
          "筆記結構",
          "手繪模式",
          "打字模式"
        ],
        "steps": [
          "最上排由左到右：回首頁、筆記結構、手繪／打字切換、筆記標題、頁碼、尺規、素材圖庫、插入、討論圖釘、線上協同、錄音、匯出與列印。",
          "第二排是目前模式的工具列：手繪模式顯示筆刷與顏色，打字模式顯示文字排版。",
          "畫布右上角有一張模式徽章，寫著現在是手寫還是打字，以及這個模式下筆會不會畫線、物件動不動得了。",
          "左側是結構欄，可切換「頁面結構」與「資料夾目錄」。",
          "中間是畫布。頁面高度固定，寫到底會自動準備下一頁；右下角也可以手動按「新增下一頁」。",
          "視窗變窄時工具列會自動換行，不會有按鈕被擠到畫面外。",
          "上排右側有兩個小按鈕：**頁面規格**（A4 直式／橫式、A5、Letter、Legal、簡報 16:9、正方形）與**版面色彩**（六個色點）。換規格會同時改畫布、分頁與匯出的尺寸；換顏色只影響版面的線條與標題。",
          "換成比較小的規格時，原本落在新頁面外的物件會自動被收回頁內 —— 不收的話那些東西在畫布上看得到、列印出來卻不見。",
          "頁面上那一圈虛線是**可列印範圍**，也就是編輯區域。完全寫在框線外的筆畫會被收回並提醒你；跨在線上的會留著，但也會提醒一次。",
          "長按或點擊畫布上的快捷圖示可喚起「徑向飛輪快捷盤」，向八個方向輕輕一揮即可盲切常用工具（筆刷、橡皮擦、套索、復原、重做、進階調色與平滑防抖），手指不需抬回螢幕頂端。"
        ],
        "tip": "螢幕不夠寬時，點「筆記結構」把左欄收起來，畫布立刻變寬。",
        "fig": "editor",
        "cap": "編輯畫面：上排主工具列、手繪工具列、左側結構欄與畫布"
      },
      {
        "id": "write",
        "title": "手寫",
        "lead": "七種筆、四段粗細、可自訂顏色。寫錯可以擦，也可以整段圈起來搬家。",
        "buttons": [
          "鋼筆",
          "橡皮擦",
          "套索選取",
          "筆跡粗細",
          "筆跡磁吸對齊與尺規",
          "進階調色"
        ],
        "steps": [
          "確認上排停在「手繪模式」。",
          "從工具列挑一支筆：鋼筆、原子筆、毛筆、麥克筆、螢光筆、鉛筆、水彩筆。",
          "工具列中間的四顆圓點選粗細，右邊的色盤選顏色；點色盤旁的滑桿圖示可自訂任何顏色。",
          "寫錯時選「橡皮擦」擦掉；想搬動或複製一整段筆跡，用「套索選取」圈起來再操作。",
          "最右邊是復原、重做與清除本頁。",
          "寫到頁面底部時會自動新增下一頁，不必手動延長。",
          "支援的觸控筆可以不必回工具列換橡皮擦：有的筆**雙擊筆桿**、有的筆**按住筆桿上的側鍵**，也有的筆倒過來用就是橡皮擦。擦完再敲一次或放開側鍵，就回到你剛才那支筆。雙擊要做什麼是系統設定裡的偏好，這裡照它走。",
          "繪製直線與線段時開啟「筆跡磁吸對齊與尺規」，筆尖接近 0°、45°、90°、135°、180° 等幾何角度或格線時會自動磁吸對齊，畫面投射青色雷射導引線並給予微震反饋。",
          "工具列支援四段「筆跡平滑防抖」濾波，大幅消除書寫微抖；點「進階調色」可開啟環形色相飽和度調色盤，支援互補與三角色等和諧配色。",
          "「畫布極致極簡模式」：點擊工具列收折按鈕可將工具列收納為螢幕角落的單一懸浮膠囊（Floating Tool Pill），享受無干擾全螢幕書寫。需要恢復時，點擊頂部常駐的高亮「退出畫布極簡模式」按鈕、點擊懸浮氣泡展開迷你工具箱、或在鍵盤上按下 Esc 鍵，即可立刻展開完整工具列。"
        ],
        "tip": "用觸控筆書寫時可以直接把手掌放在螢幕上 —— 掌拒會忽略手掌，只認筆尖。手繪模式下畫布上的物件是鎖住的（不會被拖到）；要搬動或編輯物件請切到打字模式。",
        "fig": "editor",
        "cap": "手繪工具列：筆刷、粗細、色盤與更多"
      },
      {
        "id": "type",
        "title": "打字",
        "lead": "在畫布上任何位置放文字方塊，和手寫混排。",
        "buttons": [
          "打字模式",
          "文字排版",
          "特殊符號",
          "插入連結",
          "錨定至文字"
        ],
        "steps": [
          "點上排的鍵盤圖示，切換到「打字模式」。",
          "在畫布空白處**點兩下**，該位置就會出現文字方塊並跳出鍵盤。（是點兩下不是點一下 —— 單擊留給捲動與選取物件。）",
          "點「文字排版」可以調字級、粗體、斜體、底線、對齊與文字顏色。",
          "「特殊符號」可插入數學與常用符號；「插入連結」貼上網址後會變成可點擊的預覽卡片。",
          "文字方塊可以直接拖曳移動，拖右下角的把手可以改變大小。",
          "「框選」可以拉一個框把多個物件一次選起來，接著整組搬移、複製、貼上、建立副本或刪除。在選取範圍裡拖曳就是整組搬移。",
          "「動態流式錨定」：選取文字方塊或框選周邊手寫筆畫後點「錨定至文字」，手寫批註將牢牢錨定在文字旁；拖曳文字方塊或增刪文字排版時，手寫筆劃會即時自動平移跟隨，絕不脫節跑位。"
        ],
        "tip": "打字模式下**筆也不會畫線** —— 這個模式只處理文字與物件。要寫字請切回手繪模式。連結卡片插入後選取它，左下角的鉛筆可以改網址、標題與說明。",
        "fig": "typing",
        "cap": "打字模式工具列：文字排版、特殊符號、插入連結與更多"
      },
      {
        "id": "pages",
        "title": "頁面與資料夾",
        "lead": "一則筆記可以有很多頁，每一頁可以用不同的樣板；很多則筆記可以放進資料夾。",
        "buttons": [
          "筆記結構",
          "頁面結構",
          "資料夾目錄",
          "選取頁面"
        ],
        "steps": [
          "點上排「筆記結構」開關左欄。",
          "「頁面結構」列出這則筆記每一頁的縮圖，點縮圖就跳到那一頁。",
          "**在縮圖上按右鍵或長按**會叫出快顯選單 —— 內容與每頁右上角那顆「⋯」完全一樣，用哪個都可以。",
          "選單裡有：在後方插入新頁面、插入其他樣板頁面、建立此頁副本、複製到其他筆記本、移動到其他筆記本、上移一頁、下移一頁、移到最前、移到最後、刪除此頁。",
          "**插入其他樣板頁面**：先選主題，再選樣板，新的一頁就會插在這一頁後面 —— 同一本筆記裡可以一頁四象限、一頁日程表。",
          "**換頁面順序**有兩種做法：選單裡的上移／下移／移到最前／最後，或直接把縮圖拖到目標位置（拖曳時會出現一條落點指示線）。",
          "**把幾頁搬到別本筆記**：點側欄標題列的勾選鈕進入多選，勾好要的幾頁（或按「全選」），再按底下的「複製到…」或「移動到…」，然後挑目的筆記本。",
          "側欄底部的「−／＋」調整縮圖大小；放大到比側欄寬時，側欄會自己跟著拉開。",
          "側欄與畫布之間的界線**可以左右拖曳**改變寬度，側欄裡的文字會跟著放大；連點兩下回到預設寬度。",
          "切到「資料夾目錄」可以看到所有資料夾與筆記；可新增子資料夾、重新命名、把筆記搬到別的資料夾。",
          "**把筆記拖進資料夾**：按住筆記往資料夾那一列放開。要拿出來，就拖到最上面的根目錄那一列，或拖到「未分類檔案」那一段（空的時候也在，會顯示一行提示）。不想拖曳的話，筆記右邊的「⋯」裡也有「移出資料夾」。",
          "在資料夾目錄直接點另一則筆記，就會在同一個視窗切換過去，不用先回首頁。"
        ],
        "tip": "一本筆記至少要留一頁 —— 所以整本全選之後，「移動到…」會停用（「複製到…」仍然可用）。複製過去的頁面連同上面的表格、圖形與文字方塊一起走，而且會拿到新的身分，之後改其中一份不會動到另一份。",
        "fig": "folders",
        "cap": "左側結構欄的「資料夾目錄」：根資料夾、子資料夾與筆記清單"
      },
      {
        "id": "insert",
        "title": "插入圖片、素材與圖表",
        "lead": "照片、實體規格素材、算式、圖表與 3D 模型都能放進畫布。",
        "buttons": [
          "插入",
          "插入圖片",
          "素材圖庫",
          "算式計算"
        ],
        "steps": [
          "點上排「插入」。視窗較窄時，這些項目會收在「⋯」選單裡。",
          "「插入圖片」從相簿挑一張照片；插入後可拖曳、縮放、加圓角與外框。",
          "「素材圖庫」內含機械、3C、汽機車、家具等實體規格素材，下載後即可插入畫布。",
          "「數字製圖」有 11 種圖型（直條、堆疊、橫條、折線、平滑曲線、區域、圓餅、環圈、散佈、雷達）。插入之後選取它，編修浮層裡有「編修圖表」—— 裡面的數字隨時改得動。",
          "「表格」可以增刪列欄、合併儲存格、設定表頭；點兩下表格就回到編修面板。",
          "「形狀與流程圖」有 55 種形狀：基本圖形、箭頭方塊、對話框、旗幟，以及 ISO 5807 的流程圖符號；另有內建範本會一次放好節點與連接線。選單裡的圖只是示意，插進畫布後可以自由縮放、旋轉、改標籤與配色。",
          "「算式計算」把算式變成卡片放進筆記。",
          "「插入 3D 模型」放進可 360° 旋轉的立體模型。",
          "「插入錄音」把既有的錄音放到這一頁上，變成一張可播放的卡片 —— 可以搬、可以縮放、可以改名，也可以刪掉。",
          "圖片也可以**直接從別的 App 拖進來** —— 兩個 App 並排時把圖拖到畫布上就好，見「並排與拖放」。"
        ],
        "tip": "圖表存的是你輸入的數字，不是一張圖片 —— 所以它永遠改得動，換一台裝置打開也一樣。素材圖庫的檔案下載在本機，可以在圖庫裡刪除以釋放空間。",
        "fig": "insertmenu",
        "cap": "插入選單：素材圖庫、插入圖片、算式計算、3D 模型、討論圖釘與線上協同",
        "fig2": "assetlib",
        "cap2": "素材圖庫：依分類瀏覽，點「下載」後即可插入"
      },
      {
        "id": "data",
        "title": "資料備份與同步",
        "lead": "不需要帳號，也沒有我們的伺服器。備份是一個檔案，同步是一個你自己的雲端資料夾。",
        "buttons": [
          "建立備份",
          "從備份復原",
          "選擇資料夾",
          "立即同步"
        ],
        "steps": [
          "首頁的「資料與同步」區塊裡有四張卡片，點任一張會開啟該功能的專屬說明與操作視窗。",
          "「雲端同步」顯示目前是否登入，點進去可以登入、查看同步位置並立即同步。",
          "「建立備份」把所有筆記、圖片與錄音打包成一個檔案，存到你指定的位置。",
          "「從備份復原」挑一個備份檔還原。復原前會先自動備份目前的資料，選錯檔案也救得回來。",
          "資料夾同步：先在自己的雲端硬碟裡建一個資料夾（例如叫 Kairumo），按「選擇資料夾」指到它。",
          "在另一台裝置上做同樣的事，指到**同一個**資料夾。",
          "兩邊各按一次「立即同步」。A 裝置寫的東西，B 裝置按下同步之後就會出現。",
          "Kairumo 採用嚴格的「同目錄暫存檔 ＋ 實體磁區同步（fsync）＋ 原子覆蓋」存檔流程，退出筆記或切換到後台時自動即時落盤，即使裝置突然沒電或意外中斷，也不會損壞檔案或丟失筆跡。",
          "智慧雙軌同步與即時差異核實：同步啟動前，系統會即時核實本機現存筆記本與雲端差異樣態，主動排除並清理已刪除的殘留套件，絕不對已刪除檔案發送無效請求；前台極速軌優先同步當前作用中筆記，其餘筆記本於背景並行收斂。在雲端同步視窗與系統診斷面板中，更提供「一鍵複製」與「匯出文字檔」功能，方便完整儲存工程診斷日誌。"
        ],
        "tip": "檔案的搬運交給你原本就在用的雲端硬碟。我們不碰網路，也沒有你的資料 —— 這也是為什麼找不到「登入 Kairumo」。同步只會新增檔案，不會覆蓋別台裝置寫的內容。",
        "fig": null
      },
      {
        "id": "comment",
        "title": "討論圖釘",
        "lead": "把留言釘在畫布的特定位置上，自己備忘或跟隊友討論都適用。",
        "buttons": [
          "新增討論圖釘",
          "標記為已解決"
        ],
        "steps": [
          "點「插入 →　新增討論圖釘」。",
          "在畫布上想討論的位置點一下，圖釘就釘在那裡，對話框會跟著打開。",
          "在下方輸入框打字，按右邊的箭頭送出，就成為一則留言。",
          "對話框擋到內容時，按住最左邊的「≡」握把把它拖到旁邊。",
          "按「−」可以縮小成一條標題列（縮小後一樣可以拖曳）；按「✕」關閉。",
          "討論完成後按「標記為已解決」，圖釘會變成灰色打勾。"
        ],
        "tip": "圖釘會跟著筆記一起匯出與同步；協同時所有人都看得到同一批圖釘。",
        "fig": "comment",
        "cap": "討論圖釘對話框：拖曳握把、已解決、刪除、縮小與關閉",
        "fig2": "pin_min",
        "cap2": "縮小後的精簡標題列 —— 仍然可以拖曳移動"
      },
      {
        "id": "collab",
        "title": "線上協同（手把手）",
        "lead": "多人即時共筆。沒有雲端伺服器 —— 中繼永遠是你自己掌握的那一台。分成兩種情況：大家在同一個網路，或散在不同網域。兩種都可以，只是設定的那一行不一樣。",
        "buttons": [
          "線上協同",
          "開始多人協同",
          "複製加密邀請連結",
          "加入協同房間",
          "協同伺服器位址",
          "結束協同會議"
        ],
        "steps": [
          "**先決定是哪一種情況。** 同一間辦公室、同一個 Wi-Fi → 走「情況 A」。有人在家、有人在公司、甚至在國外 → 走「情況 B」。",
          "── **情況 A：大家在同一個網路** ──",
          "**A1｜由其中一人當房主。** 打開要共筆的那本筆記 → 點上排的「線上協同」→ 按「開始多人協同」。",
          "**A2｜房主畫面上會出現三樣東西：**（一）房間識別碼，例如 kairumo-a1b2c3；（二）綠色的「端對端加密保護」；（三）一行「本機正在提供協同中繼　ws://192.168.x.x:9002」。第三行等一下隊友要用，先不要關掉。",
          "**A3｜隊友先設定伺服器位址。** 隊友打開任一本筆記 → 「線上協同」→ 展開最下面的「協同伺服器位址」→ 把 ws://127.0.0.1:9002 改成**房主畫面上那一行位址**。127.0.0.1 的意思是「我自己這台」，不改的話隊友是在連自己。",
          "── **情況 B：不在同一個網路** ──",
          "**協同沒有被綁在同一個網路上。** 你需要的只是一個雙方都連得到的中繼位址，而且它必須是 **wss://**（加密）。房號與成員名單是明文傳送的，所以公開網路上不接受 ws://。三種取得方式，由易到難：",
          "**B-1｜虛擬區域網路（最省事，不必自架）。** 所有裝置裝上 Tailscale（或 ZeroTier）並登入同一個帳號，它們就像在同一個網段。房主把自己的 Tailscale 位址告訴隊友，大家填 ws://100.x.y.z:9002 就好 —— 那是私有網段，不需要 TLS。",
          "**B-2｜把房主那台的中繼打通道出去（不必伺服器、不必帳號）。** 在房主那台電腦上執行：cloudflared tunnel --url http://localhost:9002　它會印出一個 https://xxxx.trycloudflare.com。隊友把「協同伺服器位址」填成 wss://xxxx.trycloudflare.com（把 https 換成 wss）。關掉終端機通道就結束。",
          "**B-3｜自己架一台（長期使用）。** 在任何有公開位址的機器上執行 padnote-relay（HOST=0.0.0.0 PORT=9002），前面用 Caddy 或 nginx 上 TLS，大家填 wss://relay.你的網域。做法見專案裡的 docs/relay-hosting.md。",
          "── **兩種情況接下來都一樣** ──",
          "**步驟 1｜房主按「複製加密邀請連結」，把連結傳給隊友。** 連結長這樣：kairumo://collab?room=kairumo-a1b2c3#key=…",
          "⚠️ **只傳房號是不夠的。** 井號後面那一段 key 才是解密用的金鑰。只拿到房號的人連得上、也看得到成員名單，但**對方寫的每一個字都解不開**，畫面上什麼都不會發生（這時會出現一則橘色提醒）。一定要傳整條連結。",
          "**步驟 2｜隊友貼上連結加入。** 在「加入協同房間」的欄位貼上整條邀請連結 → 按「加入協同房間」。",
          "**步驟 3｜確認真的連上了。** 兩台裝置的「在線成員」都要看到對方的名字，房主那台會標示「房主（擁有者）」。看到兩個人，就成功了。",
          "**步驟 4｜開始共筆。** 現在任何一台的筆畫、文字方塊、表格、圖形與討論圖釘，都會即時出現在另一台上。",
          "**步驟 5｜結束。** 房主按「結束協同會議」，房間關閉；隊友按「中斷連線」則只有自己離開。"
        ],
        "tip": "裝置種類沒有差別：所有裝置用的是同一套房號、同一套金鑰、同一個中繼協定，誰當房主都可以。內容以 AES-256-GCM 端對端加密，中繼點只轉發看不懂的密文 —— 就算用的是別人的通道服務，它也讀不到你的筆記。離線期間的操作會先暫存，連線恢復後自動補送。",
        "fig": "collab",
        "cap": "尚未連線：開始多人協同、加入協同房間、協同伺服器位址",
        "fig2": "collab_on",
        "cap2": "已連線：房間識別碼、端對端加密、本機正在提供中繼、線上參與者"
      },
      {
        "id": "record",
        "title": "錄音與轉錄",
        "lead": "錄音與筆跡走同一條時間軸 —— 點文字就能跳回當時寫下的那一筆。",
        "buttons": [
          "開始錄音",
          "暫停錄音",
          "繼續錄音",
          "完成錄音",
          "最近錄音與轉錄",
          "轉錄文字",
          "聲筆動態同步"
        ],
        "steps": [
          "在首頁點「開始錄音」，或在筆記裡點上排的麥克風圖示。",
          "第一次使用會詢問麥克風權限，請選擇允許。",
          "錄音中畫面上方會顯示即時波形；此時寫下的筆跡會自動與聲音對齊。",
          "需要停一下時按「暫停錄音」；要接著錄就按「繼續錄音」。按「完成錄音」才會結束並儲存。",
          "停止後，該段錄音會出現在首頁的「最近錄音與轉錄」。",
          "播放時點某一段轉錄文字，畫面會跳到當時寫下的筆跡；反過來點筆跡也可以跳到對應的聲音。",
          "要把某段錄音放進某一頁：在筆記裡點「更多 → 插入錄音」，或在首頁的錄音列點「⋯ → 插入至筆記本」。",
          "選取頁面上的錄音卡片後，點左上角的「轉錄文字」按鈕，Kairumo 會把音訊轉成文字方塊並放在卡片下方。",
          "支援「聲筆動態同步」卡拉 OK：回放錄音時，當時書寫的筆畫會伴隨語音進度發光高亮；直接在畫布上點擊任一筆跡，錄音進度條會立刻跳轉至該筆畫書寫時的精確時間點。"
        ],
        "tip": "錄音與轉錄都在這台裝置上完成，不會上傳到任何伺服器。轉錄需要一個在裝置上跑的引擎，而**不是每台裝置都有** —— 沒有的話錄音照常運作，只是首頁的錄音列不會出現轉錄文字，錄音卡片也可能無法產生文字方塊。",
        "fig": "home",
        "cap": "首頁的「開始錄音」與「最近錄音與轉錄」"
      },
      {
        "id": "export",
        "title": "匯出、列印與分享",
        "lead": "四種輸出方式，依對方需要選一種。",
        "buttons": [
          "匯出與列印",
          "匯出 PDF",
          "匯出為圖片",
          "列印筆記",
          "分享筆記"
        ],
        "steps": [
          "點右上角的「匯出與列印」。",
          "「匯出 PDF」把整本筆記轉成 PDF，適合寄給別人或存檔。",
          "「匯出為圖片」輸出目前這一頁的圖檔。",
          "「列印筆記」走系統列印流程。",
          "「分享筆記」傳出 .padnote 原始檔，對方用 Kairumo 打開可以繼續編輯。"
        ],
        "tip": "PDF 內的標註座標與原稿一致，用其他 App 打開也不會跑位。",
        "fig": "export",
        "cap": "匯出與列印選單：匯出 PDF、匯出為圖片、列印筆記、分享筆記"
      },
      {
        "id": "keys",
        "title": "鍵盤快捷鍵",
        "lead": "接上實體鍵盤時，常用的動作都有快捷鍵。",
        "buttons": [],
        "steps": [
          "下面寫的「⌘」，在有 Command 鍵的鍵盤上就是 Command；其餘鍵盤請改按 **Ctrl**。",
          "**⇧⌘N**：新增筆記。是加上 Shift 的 —— 不加的 ⌘N 是系統的「開新視窗」，兩個撞在一起的話兩邊都會失效。",
          "**⌘F**：游標直接跳進首頁的搜尋列。",
          "**⌘E**：手繪與打字兩個模式互換。",
          "**⌘1** 起算：依工具列上的順序切換筆刷與工具。工具比數字少的時候，多出來的數字沒有作用。"
        ],
        "tip": "游標在文字方塊裡的時候，⌘A、⌘C、⌘V 仍然是全選、複製、貼上 —— 這些快捷鍵不會把它們搶走。",
        "fig": null
      },
      {
        "id": "multi",
        "title": "並排與拖放",
        "lead": "把 Kairumo 與另一個 App 並排，可以把圖片直接拖進畫布。",
        "buttons": [],
        "steps": [
          "在平板或桌機上，用系統的分割畫面把 Kairumo 與相簿（或檔案、瀏覽器）並排。",
          "從另一邊按住一張圖片，拖到 Kairumo 的畫布上。畫布會浮現一圈虛線，表示可以放下了。",
          "放開之後，圖片會落在你放手的位置，並且自動縮到適合頁面的大小、保持原比例。",
          "拖到頁面邊緣時圖片會自動往內靠 —— 不會有一半跑到頁面外（跑出去的那一半在匯出與列印時會被裁掉）。",
          "放進來之後會自動切到打字模式，這樣可以馬上拖動與縮放它。",
          "並排時視窗變窄，工具列會自動換行，不會有按鈕被擠到看不見的地方。"
        ],
        "tip": "拖進來的圖片與從「插入圖片」放進來的完全一樣 —— 一樣可以縮放、旋轉、加圓角與外框。",
        "fig": null
      },
      {
        "id": "language",
        "title": "語言與顯示身分",
        "lead": "介面支援六種語言，隨時切換、立即生效。",
        "buttons": [
          "介面語系",
          "編輯身分"
        ],
        "steps": [
          "在首頁右上角點「介面語系」—— 地球圖示旁邊就是這四個字。",
          "從清單中選擇：繁體中文、English、简体中文、日本語、한국어、ไทย。",
          "介面會立刻切換，不需要重新啟動 App。",
          "回到首頁上方點「編輯身分」，可以修改協同時顯示的名字與代表色。"
        ],
        "tip": "顯示身分只存在這台裝置上，不會上傳到任何地方。",
        "fig": "language",
        "cap": "語言選單：六種語言即時切換"
      },
      {
        "id": "faq",
        "title": "常見問題",
        "lead": "遇到狀況時先看這裡。",
        "buttons": [],
        "faq": [
          [
            "為什麼打字模式下筆畫不出東西？",
            "那是刻意的。打字模式只處理文字與物件 —— 手指與觸控筆都不會畫線，這樣點選、拖曳物件才不會每次都留下一條筆跡。畫布右上角的徽章會寫著目前是哪個模式。要寫字就切回手繪模式。"
          ],
          [
            "線上協同連不上怎麼辦？",
            "看你是哪一種情況。**同一個網路**：（一）確認兩台真的在同一個網路；（二）隊友的「協同伺服器位址」已改成房主畫面上顯示的 ws://…:9002，而不是預設的 127.0.0.1；（三）首次連線時系統會詢問區域網路權限，要選允許。**不同網域**：協同沒有被綁在同一個網路 —— 但公開網路上的位址必須是 wss://（加密），填 ws:// 會被擋下並顯示「這個中繼在公開網路上，必須用 wss://」。取得 wss:// 位址的三種方式見上面「線上協同」那一節。"
          ],
          [
            "連上了，但對方寫的東西看不到？",
            "八成是加入時只貼了房號，沒有貼整條邀請連結。金鑰在連結井號後面那一段，少了它就解不開對方的內容 —— 這時畫面上會出現一則橘色提醒。請向房主要完整的邀請連結，重新加入一次。"
          ],
          [
            "筆記會不會不見？",
            "每一筆都即時寫入本機檔案。同步檔案只新增不修改，每台裝置只寫自己的檔案，所以不會互相覆蓋。"
          ],
          [
            "需要註冊帳號嗎？",
            "不需要。Kairumo 沒有帳號系統，也沒有後端伺服器。"
          ],
          [
            "手寫可以轉成文字嗎？",
            "可以。使用系統內建的裝置端辨識，不會把筆跡送上網。"
          ],
          [
            "怎麼回報問題？",
            "請附上桌機版視窗左上角顯示的版本號（例如 Kairumo v4.8.0）與操作步驟。"
          ],
          [
            "同一本筆記可以混用不同的頁面格式嗎？",
            "可以。在「頁面結構」的縮圖上按右鍵或長按 → 「插入其他樣板頁面」→ 選主題與樣板，新的一頁就會用那一種版面，其餘頁面不受影響。建立筆記時選的那一個只是**預設值**。"
          ],
          [
            "寫到框線外面會怎樣？",
            "那一圈虛線是可列印範圍，也是編輯區域。完全寫在外面的筆畫會被收回並跳出一則提醒 —— 因為它印不出來也匯不出去，留著只會讓人以為它還在。跨在線上的筆畫會留著，但也會提醒一次。"
          ]
        ],
        "fig": null
      }
    ]
  },
  "en": {
    "name": "English",
    "figset": "en",
    "ui": {
      "docTitle": "Kairumo User Manual",
      "tagline": "Handwriting, typing and audio in one notebook. Step by step, from zero.",
      "version": "For version 4.8.0 (build 58) · 19 September 2026",
      "tocTitle": "Contents",
      "tocHint": "Tap any entry to jump straight to it",
      "stepsLabel": "Steps",
      "tipLabel": "Good to know",
      "buttonsLabel": "Buttons you'll use",
      "figNote": "Screenshots show the English interface",
      "backToTop": "Back to contents",
      "langLabel": "Language",
      "privacyLink": "Privacy Policy"
    },
    "sections": [
      {
        "id": "start",
        "title": "Before you start",
        "lead": "Kairumo is a notebook that puts handwriting, typing and audio on one shared timeline. Free, open source, and your notes stay on your own device.",
        "buttons": [],
        "steps": [
          "Works on tablets, phones and desktops. A stylus feels best, but a finger or a mouse works too.",
          "No account and no internet connection are needed to start.",
          "On first launch you get two sample notebooks (“Welcome to Kairumo” and “Lectures & Meetings”) with editable text, tables, charts and shapes. Delete them if you do not want them.",
          "Everything you write is stored on this device. To sync across devices, point them at a folder in your own cloud drive (see “Backup and sync”).",
          "On desktop the window title shows the version (for example Kairumo v4.8.0) — include it when you report a problem."
        ],
        "tip": "No server and no account means there is no password to forget — and no cloud copy if you lose the device, so make your own backup.",
        "fig": null
      },
      {
        "id": "firstrun",
        "title": "The first time you open it",
        "lead": "One page explains which permission is needed and why. Read it, and it never appears again.",
        "buttons": [
          "Allow Microphone",
          "Later",
          "Get Started"
        ],
        "steps": [
          "The page covers three things: what Kairumo is, that there is no account and no server of ours, and the one permission it can use.",
          "There is only **one** permission — the microphone — and only recording uses it. Decline it and handwriting, typing, export and sync all still work.",
          "Tapping “Allow Microphone” is what brings up the system permission dialog. That dialog appears **only once in an app's lifetime**.",
          "If you decline, the button changes to “Open Settings”. From then on the permission can only be switched on in the system settings — the app cannot ask you again.",
          "Tap “Get Started” to go to the home screen. This page will not come back."
        ],
        "tip": "Permissions are never requested at install time — the system only asks when a feature actually needs one. So if you start recording before granting it, you will be guided through it right then.",
        "fig": null
      },
      {
        "id": "home",
        "title": "Home: your workbench",
        "lead": "The first screen you see. Every note, recording, asset and imported file starts here.",
        "buttons": [
          "Edit Identity",
          "New Note",
          "Start Recording",
          "Asset Library",
          "Import Note"
        ],
        "steps": [
          "At the top is your display identity — the name teammates see while collaborating. Tap “Edit Identity” to change it.",
          "The search field searches note titles, typed text and transcribed speech at the same time.",
          "The four large cards are the main actions: New Note, Start Recording, Asset Library and Import Note.",
          "“Import Note” lets you choose a .padnote file and add a shared original note to your library.",
          "“Continue” lists the notes you opened recently; one tap returns you to where you left off.",
          "“All Notebooks” groups everything by folder; the control on the right changes the sort order.",
          "Scroll to the bottom of the home screen for the “User Manual” and “Privacy Policy” cards — this document is the former.",
          "Each row in the home recordings list has a “⋯” menu with “Insert into Notebook” — pick the notebook and the page to place that recording on."
        ],
        "tip": "The “⋯” on each note card holds Rename, Move to folder and Delete.",
        "fig": "home",
        "cap": "Home: identity, search, four main actions, Continue, All Notebooks"
      },
      {
        "id": "newnote",
        "title": "Create your first note",
        "lead": "Thirty-three page templates in seven groups — and you pick the guide colour.",
        "buttons": [
          "New Note",
          "Page Templates",
          "Guide Colour",
          "OK"
        ],
        "steps": [
          "Tap New Note on the home screen.",
          "Type a name in Notebook Title. You can leave it blank and rename it later.",
          "Under Page Templates the top row is a set of theme chips — all seven are listed at once, with no sideways scrolling: General, Note-taking Methods, Planning & Schedule, Lists & Trackers, Aesthetic & Visual, Engineering & Process, Digital Experience.",
          "Tap a theme and the list below switches to that group. Every template carries one line saying what it is for.",
          "Note-taking Methods are the structured ones: Cornell (cues / notes / summary), Quadrant (points / questions / decisions / actions), Outline (three indent levels), Two-Column Compare, Question & Answer, K-W-L and Mind Map.",
          "Planning & Schedule and Lists & Trackers cover month, week, daily schedule, 24-hour timeline, study planner, project milestones, to-do list, checklist, habit tracker, assignment tracker, chore roster and the 21-day challenge.",
          "At the bottom, Guide Colour offers six swatches: Graphite, Indigo, Teal, Rose, Amber and Forest. The lines, header bands and field labels all follow your choice.",
          "Tap OK. The note opens straight away and you can start writing."
        ],
        "tip": "A template is only the layout, so changing it never touches what you have already written. And once inside, **each page can use a different template** — see “Pages and folders”. The guide colour is one tone for the whole notebook and can be changed any time from the editor’s top bar.",
        "fig": "newnote",
        "cap": "New notebook: title, theme chips, template list and guide colour"
      },
      {
        "id": "editor",
        "title": "The editor at a glance",
        "lead": "One minute here saves you looking for buttons later.",
        "buttons": [
          "Home",
          "Structure",
          "Handwriting",
          "Typing"
        ],
        "steps": [
          "Top row, left to right: Home, note structure, handwriting/typing switch, title, page number, ruler, Asset Library, Insert, Comment Pins, Collaborate, Record, Export & Print.",
          "The second row is the toolbar for the current mode: brushes and colours for handwriting, text formatting for typing.",
          "A mode badge sits at the top right of the canvas: it says whether you are in handwriting or typing mode, and whether the pen draws and objects can be moved.",
          "The left column is the structure panel, switching between Pages and Folders.",
          "The canvas is in the middle. Page height is fixed — writing to the bottom prepares the next page automatically, and “Add Next Page” at the bottom right does it manually.",
          "When the window gets narrow the toolbars wrap onto more rows — no button is ever pushed off screen.",
          "Two small buttons sit at the right of the top bar: **page format** (A4 portrait/landscape, A5, Letter, Legal, 16:9 slide, square) and **guide colour** (six swatches). Changing the format changes the canvas, the page breaks and the exported size together; changing the colour only affects the guide lines and headings.",
          "When you switch to a smaller format, anything that would fall outside the new page is pulled back inside — otherwise it stays visible on the canvas but disappears when printed.",
          "The dashed rectangle on the page is the **printable area**, which is also the editing area. A stroke drawn entirely outside it is taken back and you are told why; one that straddles the line is kept, with a single reminder.",
          "Long-press or tap the canvas shortcut to summon the “Radial Mark Menu”; flick in 8 directions to blind-switch tools (pens, eraser, lasso, undo, redo, color studio, stabilizer) without reaching for the top bar."
        ],
        "tip": "Short on width? Tap “Structure” to collapse the left column and the canvas widens immediately.",
        "fig": "editor",
        "cap": "The editor: top bar, handwriting toolbar, structure panel and canvas"
      },
      {
        "id": "write",
        "title": "Handwriting",
        "lead": "Seven pens, four thicknesses, any colour. Erase what's wrong, or lasso a whole passage and move it.",
        "buttons": [
          "Fountain Pen",
          "Eraser",
          "Lasso",
          "Stroke Width",
          "Magnetic Snap & Ruler",
          "Advanced Color Studio"
        ],
        "steps": [
          "Make sure the top bar is set to handwriting mode.",
          "Pick a pen: fountain pen, ballpoint, brush, marker, highlighter, pencil or watercolour.",
          "The four dots in the middle set thickness; the swatches set colour. The slider icon opens a full colour picker.",
          "Use the eraser to remove strokes. To move or copy a whole passage, circle it with the lasso first.",
          "Undo, redo and clear page sit at the right end of the toolbar.",
          "Write to the bottom of a page and the next one is added automatically.",
          "With a supported stylus you do not have to go back to the toolbar to erase: some pens **double-tap on the barrel**, some have a **side button you hold**, and some erase when you turn them over. Tap again, or let the button go, and you are back on the pen you were using. What the double-tap does is a system-wide preference, and this follows it.",
          "Turn on “Magnetic Snap & Ruler” while drawing lines or geometric contours; strokes snap automatically to canonical angles (0°, 45°, 90°, 135°, 180°) and page grids with a cyan laser guideline and haptic feedback.",
          "The toolbar provides 4-level stroke stabilization to smooth out hand jitters; tap “Advanced Color Studio” to open a full hue-saturation wheel with complementary and triadic harmonies.",
          "“Minimalist Canvas Mode”: Click the collapse button on the toolbar to fold it into a floating tool pill in the screen corner for immersive distraction-free writing. To restore the full toolbar anytime, click the prominent “Exit Minimalist Canvas” button pinned to the top navigation bar, tap the floating bubble to expand the mini-toolbox, or press the Esc key on your physical keyboard."
        ],
        "tip": "Rest your palm on the screen while writing with a stylus — palm rejection ignores it and follows only the tip. In handwriting mode the objects on the canvas are locked so you cannot drag them by accident; switch to typing mode to move or edit them.",
        "fig": "editor",
        "cap": "Handwriting toolbar: brushes, thickness, colours and More"
      },
      {
        "id": "type",
        "title": "Typing",
        "lead": "Drop a text box anywhere on the canvas and mix it with handwriting.",
        "buttons": [
          "Typing",
          "Text Studio",
          "Special Symbols",
          "Insert Link",
          "Anchor to Text"
        ],
        "steps": [
          "Tap the keyboard icon in the top bar to switch to typing mode.",
          "Double-tap an empty spot on the canvas — a text box appears there and the keyboard opens. (Double, not single: a single tap is reserved for scrolling and selecting objects.)",
          "“Text Studio” sets size, bold, italic, underline, alignment and colour.",
          "“Special Symbols” inserts maths and common symbols; “Insert Link” turns a pasted URL into a tappable preview card.",
          "Drag a text box to move it; drag the handle at its bottom-right corner to resize it.",
          "“Select” lets you drag a box around several objects at once, then move, copy, paste, duplicate or delete them together. Dragging inside the selection moves the whole group.",
          "“Fluid Sticky Annotations”: select a text box or lasso overlapping strokes and tap “Anchor to Text”; handwriting binds to the text box so that dragging the text or reflowing paragraphs automatically carries the handwritten annotations along."
        ],
        "tip": "In typing mode **the pen does not draw either** — this mode only handles text and objects. Switch back to handwriting mode to write. Select an inserted link card and the pencil at its bottom left edits the URL, title and description.",
        "fig": "typing",
        "cap": "Typing toolbar: Text Studio, Special Symbols, Insert Link and More"
      },
      {
        "id": "pages",
        "title": "Pages and folders",
        "lead": "A note can have many pages, each with its own template; many notes can live in folders.",
        "buttons": [
          "Structure",
          "Pages",
          "Folders",
          "Select Pages"
        ],
        "steps": [
          "Tap Structure in the top bar to show or hide the left column.",
          "Pages lists a thumbnail of every page in this note. Tap one to jump to it.",
          "**Right-click or press and hold a thumbnail** to open its menu — it holds exactly the same items as the “⋯” button at the top right of each page, so use whichever you reach first.",
          "The menu has: Insert Page After, Insert Page with Template…, Duplicate Page, Copy to Another Notebook…, Move to Another Notebook…, Move Page Up, Move Page Down, Move to First, Move to Last, Delete Page.",
          "**Insert Page with Template…** asks for a theme and then a template, and drops the new page in right after this one — so one notebook can hold a quadrant page and a daily schedule page side by side.",
          "**Reordering** works two ways: the Move items in the menu, or simply drag a thumbnail to where you want it (a line shows where it will land).",
          "**Moving pages to another notebook**: tap the tick button in the sidebar header to start selecting, tick the pages you want (or use Select All), then tap Copy to… or Move to… and pick the destination.",
          "The − and + buttons at the bottom of the sidebar change the thumbnail size. Ask for one wider than the sidebar and the sidebar widens to match.",
          "The divider between the sidebar and the canvas **can be dragged sideways**; the text in the sidebar grows with it. Double-tap the divider to go back to the default width.",
          "Switch to Folders to see every folder and note: add subfolders, rename them, move notes between them.",
          "**To file a note**, drag it onto a folder row. To take it out again, drag it to the root row at the very top, or to the Unfiled Notes section (which is always there — when empty it shows a line telling you so). If you would rather not drag, the “⋯” next to each note also has Move Out of Folder.",
          "Tapping another note in Folders switches to it in the same window; no need to go home first."
        ],
        "tip": "A notebook must keep at least one page, so Move to… is disabled once every page is selected (Copy to… still works). A copied page brings its tables, shapes and text boxes with it and they are given fresh identities, so editing one copy never disturbs the other.",
        "fig": "folders",
        "cap": "The Folders tab: root folder, subfolders and the note list"
      },
      {
        "id": "insert",
        "title": "Images, assets and charts",
        "lead": "Photos, engineering assets, equations, charts and 3D models all go on the canvas.",
        "buttons": [
          "Insert",
          "Insert Image",
          "Asset Library",
          "Math Calculator"
        ],
        "steps": [
          "Tap “Insert” in the top bar. On a narrow window these items move into the “⋯” menu.",
          "“Insert Image” picks a photo from your library; once placed you can drag, resize, round its corners and add a border.",
          "“Asset Library” holds real-world specification assets — mechanical parts, electronics, vehicles, furniture — to download and place.",
          "“Chart Studio” offers 11 chart types (column, stacked, bar, line, smooth line, area, pie, doughnut, scatter, radar). After inserting one, select it and choose “Edit Chart” — the numbers inside stay editable.",
          "“Table” adds and removes rows and columns, merges cells and marks a header row; double-tap a table to reopen its editor.",
          "“Shapes & Flowcharts” has 55 shapes: basic figures, block arrows, speech bubbles, banners and the ISO 5807 flowchart symbols, plus templates that lay out nodes and connectors in one go. The gallery icons are just hints — once on the canvas you can resize, rotate, relabel and recolour freely.",
          "“Math Calculator” turns an equation into a card on the page.",
          "“Insert 3D Model” places a model you can rotate a full 360°.",
          "“Insert Recording” puts an existing recording on this page as a playable card — you can move it, resize it, rename it and delete it.",
          "Pictures can also be **dragged straight in from another app** — put the two side by side and drop the picture on the canvas. See “Side by side, and drag and drop”."
        ],
        "tip": "A chart stores the numbers you typed, not a picture of them — so it stays editable forever, including on another device. Asset files are downloaded to this device; delete them from the library to free space.",
        "fig": "insertmenu",
        "cap": "Insert menu: Asset Library, Insert Image, Math Calculator, 3D Model, Comment Pin, Collaborate",
        "fig2": "assetlib",
        "cap2": "Asset Library: browse by category, tap Download, then place it"
      },
      {
        "id": "data",
        "title": "Backup and sync",
        "lead": "No account, and no server of ours. A backup is one file; syncing is a folder in your own cloud drive.",
        "buttons": [
          "Create Backup",
          "Restore from Backup",
          "Choose Folder",
          "Sync Now"
        ],
        "steps": [
          "The “Data & Sync” block on the home screen has four cards; tapping one opens that feature’s own detail and action sheet.",
          "“Google Drive” shows whether you are signed in, and opens sign-in, sync location and Sync Now controls.",
          "“Create Backup” packs every note, image and recording into a single file and saves it where you choose.",
          "“Restore from Backup” restores from one of those files. Your current data is backed up first, so picking the wrong file is recoverable.",
          "Folder sync: create a folder in your own cloud drive (call it Kairumo, say) and point “Choose Folder” at it.",
          "Do the same on your other device, pointing at the **same** folder.",
          "Tap “Sync Now” on each. What you wrote on one device shows up on the other after it syncs.",
          "Kairumo employs strict atomic saves with temp files and physical fsync; notes save automatically when exiting or switching to the background, preventing corruption or data loss even during sudden power loss.",
          "Dual-track sync and real-time diff reconciliation: Before syncing, the system reconciles existing local notebooks with remote cloud indexes, actively excluding and cleaning up deleted orphaned packages without wasting bandwidth; the foreground track prioritizes your active notebook while the background queue processes remaining notebooks concurrently. Furthermore, the Cloud Sync sheet and App Diagnostics panel offer “One-click Copy” and “Export Log File” buttons to easily preserve engineering diagnostic logs."
        ],
        "tip": "Moving the files is your cloud drive's job — the one you already use. We never touch the network and never hold your data, which is why there is no “Sign in to Kairumo”. Syncing only adds files; it never overwrites what another device wrote.",
        "fig": null
      },
      {
        "id": "comment",
        "title": "Comment pins",
        "lead": "Pin a note to an exact spot on the canvas — for yourself or for the people you're working with.",
        "buttons": [
          "Add Comment Pin",
          "Resolved"
        ],
        "steps": [
          "Tap “Insert → Add Comment Pin”.",
          "Tap the spot you want to discuss. The pin lands there and its thread opens.",
          "Type in the field at the bottom and tap the arrow to post a message.",
          "If the dialog covers what you're discussing, drag it aside by the “≡” handle on its left.",
          "“−” shrinks it to a single title bar — still draggable. “✕” closes it.",
          "When the discussion is settled, tap “Resolved” and the pin turns grey with a checkmark."
        ],
        "tip": "Pins travel with the note when you export or sync, and everyone in a collaboration session sees the same set.",
        "fig": "comment",
        "cap": "Comment thread: drag handle, Resolved, delete, minimise and close",
        "fig2": "pin_min",
        "cap2": "Minimised to a title bar — and still draggable"
      },
      {
        "id": "collab",
        "title": "Real-time collaboration (step by step)",
        "lead": "Write together in real time. There is no cloud server — the relay is always one you control. There are two situations: everyone on one network, or people spread across different ones. Both work; only one line of setup differs.",
        "buttons": [
          "Collaborate",
          "Start Collaboration",
          "Copy Encrypted Invite Link",
          "Join Room",
          "Relay Server Address",
          "End Collaboration"
        ],
        "steps": [
          "**Decide which situation you are in.** Same office, same Wi-Fi → case A. Someone at home, someone at the office, someone abroad → case B.",
          "── **Case A: everyone on the same network** ──",
          "**A1 — one person hosts.** Open the note to work on, tap “Collaborate” in the top bar, then “Start Collaboration”.",
          "**A2 — three things appear on the host's screen:** the Room ID (e.g. kairumo-a1b2c3), a green “End-to-End Encrypted” badge, and a line reading “Hosting relay on this device  ws://192.168.x.x:9002”. Teammates need that third line shortly, so leave it open.",
          "**A3 — each teammate sets the relay address first.** Open any note → “Collaborate” → expand “Relay Server Address” → replace ws://127.0.0.1:9002 with **the address on the host's screen**. 127.0.0.1 means “this device”; left unchanged, the teammate is calling their own machine.",
          "── **Case B: not on the same network** ──",
          "**Collaboration is not tied to one network.** All you need is a relay address both sides can reach, and it has to be **wss://** (TLS). Room IDs and membership travel in the clear, so plain ws:// is not accepted on the public internet. Three ways, easiest first:",
          "**B-1 — a virtual private network (least effort, nothing to host).** Install Tailscale (or ZeroTier) on every device and sign them into the same account; they behave as if they were on one network. The host shares their Tailscale address and everyone enters ws://100.x.y.z:9002 — that range is private, so no TLS is needed.",
          "**B-2 — tunnel the host's built-in relay (no server, no account).** On the host's computer run: cloudflared tunnel --url http://localhost:9002 — it prints a https://xxxx.trycloudflare.com URL. Teammates set “Relay Server Address” to wss://xxxx.trycloudflare.com (swap https for wss). Closing the terminal ends the tunnel.",
          "**B-3 — host your own (for regular use).** Run padnote-relay on any machine with a public address (HOST=0.0.0.0 PORT=9002), put Caddy or nginx in front for TLS, and everyone enters wss://relay.yourdomain. See docs/relay-hosting.md in the project.",
          "── **From here both cases are identical** ──",
          "**Step 1 — the host taps “Copy Encrypted Invite Link” and sends it.** It looks like: kairumo://collab?room=kairumo-a1b2c3#key=…",
          "⚠️ **The room ID alone is not enough.** The part after the # is the decryption key. Someone who joins with the ID only will connect and see the participant list, but **nothing the others write can be decrypted** — their screen simply stays empty (an orange warning appears in that case). Always send the whole link.",
          "**Step 2 — paste the link and join.** Paste the whole invite link into “Join Room” and tap Join Room.",
          "**Step 3 — confirm it worked.** Both devices should list each other under “Online Participants”, with the host marked “Host (Owner)”. Two names means you are connected.",
          "**Step 4 — write.** Strokes, text boxes, tables, shapes and comment pins from either device now appear on the other in real time.",
          "**Step 5 — finish.** The host taps “End Collaboration” to close the room; a guest tapping “Disconnect” only leaves themselves."
        ],
        "tip": "The kind of device makes no difference: every device shares the same room IDs, the same keys and the same relay protocol, and any of them can host. Content is end-to-end encrypted with AES-256-GCM and the relay only forwards ciphertext it cannot read — so even a third-party tunnel service cannot see your notes. Edits made while offline are queued and sent automatically once the connection returns.",
        "fig": "collab",
        "cap": "Not connected: Start Collaboration, Join Room, Relay Server Address",
        "fig2": "collab_on",
        "cap2": "Connected: room ID, end-to-end encryption, relay hosted on this device, participants"
      },
      {
        "id": "record",
        "title": "Recording and transcription",
        "lead": "Audio and ink share one timeline — tap a word and jump to the stroke you wrote at that moment.",
        "buttons": [
          "Start Recording",
          "Pause Recording",
          "Resume Recording",
          "Finish Recording",
          "Recent Recordings & Transcripts",
          "Transcribe Audio",
          "Audio-Ink Sync"
        ],
        "steps": [
          "Tap “Start Recording” on Home, or the microphone in a note's top bar.",
          "The first time, the system asks for microphone permission — allow it.",
          "While recording, a live waveform appears at the top and anything you write is aligned to the audio.",
          "Need a break? Tap “Pause Recording”. Tap “Resume Recording” to continue, and “Finish Recording” when you want to save and end it.",
          "When you stop, the recording appears under “Recent Recordings & Transcripts” on Home.",
          "During playback, tap a line of transcript to jump to the ink written at that time — and the other way round.",
          "To place a recording on a page: inside a notebook choose “More → Insert Recording”, or on the home screen use “⋯ → Insert into Notebook” on the recording row.",
          "Select a recording card on the page and tap “Transcribe Audio” at its top left. Kairumo turns the audio into a text box under the card.",
          "Supports “Audio-Ink Sync” karaoke playback: during playback, strokes written at that exact moment glow dynamically in sync with the audio; tap any stroke on the canvas to immediately seek the recording to that stroke’s timestamp."
        ],
        "tip": "Recording and transcription both run on this device; nothing is uploaded. Transcription needs an on-device engine, and **not every device has one** — without it recording still works, but the recordings list has no transcript text and a recording card may not be able to create a text box.",
        "fig": "home",
        "cap": "“Start Recording” and “Recent Recordings & Transcripts” on Home"
      },
      {
        "id": "export",
        "title": "Export, print and share",
        "lead": "Four outputs — pick the one the other side needs.",
        "buttons": [
          "Export & Print",
          "Export PDF",
          "Export Image",
          "Print Notebook",
          "Share Note"
        ],
        "steps": [
          "Tap “Export & Print” at the top right.",
          "“Export PDF” turns the whole notebook into a PDF to send or archive.",
          "“Export Image” saves the current page as an image file.",
          "“Print Notebook” hands the note to the system print dialog.",
          "“Share Note” sends the original .padnote file, which another Kairumo user can keep editing."
        ],
        "tip": "Annotation coordinates in the PDF match the original, so they stay in place in other apps too.",
        "fig": "export",
        "cap": "Export & Print menu: Export PDF, Export Image, Print Notebook, Share Note"
      },
      {
        "id": "keys",
        "title": "Keyboard shortcuts",
        "lead": "With a hardware keyboard attached, the common actions all have a shortcut.",
        "buttons": [],
        "steps": [
          "Where “⌘” is written below, use Command on keyboards that have it, and **Ctrl** on the ones that do not.",
          "**⇧⌘N** — new note. The Shift matters: plain ⌘N is the system's “New Window”, and if the two collide neither of them works.",
          "**⌘F** — puts the cursor straight into the search field on the home screen.",
          "**⌘E** — swaps between handwriting and typing mode.",
          "**⌘1** onwards — picks a brush or tool, in the same order as the toolbar. Where there are fewer tools than digits, the extra digits do nothing."
        ],
        "tip": "While the cursor is inside a text box, ⌘A, ⌘C and ⌘V are still select-all, copy and paste — these shortcuts do not take them away.",
        "fig": null
      },
      {
        "id": "multi",
        "title": "Side by side, and drag and drop",
        "lead": "Put Kairumo next to another app and you can drag pictures straight onto the canvas.",
        "buttons": [],
        "steps": [
          "On a tablet or a desktop, use the system's split screen to put Kairumo next to your photo library (or files, or a browser).",
          "Press and hold a picture on the other side and drag it onto Kairumo's canvas. A dashed outline appears to show you can let go.",
          "When you release, the picture lands where you let go, scaled to fit the page with its proportions kept.",
          "Drop near an edge and the picture is nudged back inside — no half of it ends up off the page (the part that hangs off would be cut away on export and print).",
          "After it lands the app switches to typing mode, so you can move and resize it right away.",
          "Side by side the window is narrower, so the toolbars wrap onto more rows rather than pushing buttons out of sight."
        ],
        "tip": "A dragged-in picture is exactly the same as one added with “Insert Picture” — it can be resized, rotated, and given rounded corners and a border.",
        "fig": null
      },
      {
        "id": "language",
        "title": "Language and identity",
        "lead": "Six interface languages, switched instantly.",
        "buttons": [
          "Language",
          "Edit Identity"
        ],
        "steps": [
          "On the home screen, tap “Language” in the top right — the word sits next to the globe.",
          "Choose 繁體中文, English, 简体中文, 日本語, 한국어 or ไทย.",
          "The interface changes immediately — no restart needed.",
          "Back on Home, “Edit Identity” changes the name and colour teammates see while collaborating."
        ],
        "tip": "Your display identity is stored on this device only and is never uploaded.",
        "fig": "language",
        "cap": "Language menu: six languages, switched live"
      },
      {
        "id": "faq",
        "title": "Troubleshooting",
        "lead": "Check here first.",
        "buttons": [],
        "faq": [
          [
            "Why doesn’t the pen draw in typing mode?",
            "That is deliberate. Typing mode only handles text and objects — neither finger nor stylus draws, so selecting and dragging objects never leaves a stray stroke behind. The badge at the top right of the canvas says which mode you are in. Switch back to handwriting mode to write."
          ],
          [
            "Collaboration won't connect",
            "Make sure both devices are on the same Wi-Fi. The guest's “Relay Server Address” must be the ws://…:9002 address shown on the host's screen, not the default 127.0.0.1. On the first connection the system asks for local network permission — allow it."
          ],
          [
            "Can my notes get lost?",
            "Every stroke is written to a local file as you go. Sync files are append-only and each device only ever writes its own file, so nothing overwrites anything."
          ],
          [
            "Do I need an account?",
            "No. Kairumo has no accounts and no backend server."
          ],
          [
            "Can handwriting become text?",
            "Yes, using the on-device recognition built into the system. Your ink never leaves the device."
          ],
          [
            "How do I report a problem?",
            "Include the version shown in the desktop window title (for example Kairumo v4.8.0) and the steps you took."
          ],
          [
            "Can one notebook mix different page formats?",
            "Yes. Right-click or press and hold a thumbnail in Pages → Insert Page with Template… → pick a theme and a template. The new page uses that layout and the others are untouched. What you choose when creating the notebook is only the **default**."
          ],
          [
            "What happens if I write outside the frame?",
            "The dashed rectangle is the printable area, which is also the editing area. A stroke drawn entirely outside it is taken back and you get a notice — it would neither print nor export, and leaving it there would only make you think it still exists. A stroke that straddles the line is kept, with a single reminder."
          ]
        ],
        "fig": null
      }
    ]
  },
  "zh-Hans": {
    "name": "简体中文",
    "figset": "zh",
    "ui": {
      "docTitle": "Kairumo 操作手册",
      "tagline": "手写、打字、录音三合一的笔记本。零基础也能一步一步跟着做。",
      "version": "适用版本 v4.8.0（build 58）· 2026 年 9 月 19 日",
      "tocTitle": "目录",
      "tocHint": "点任一项目直接跳到该段落",
      "stepsLabel": "操作步骤",
      "tipLabel": "小提示",
      "buttonsLabel": "会用到的按钮",
      "figNote": "截图为繁体中文界面",
      "backToTop": "回到目录",
      "langLabel": "语言",
      "privacyLink": "隐私政策"
    },
    "sections": [
      {
        "id": "start",
        "title": "开始之前",
        "lead": "Kairumo 是一本把手写、打字与录音放在同一条时间轴上的笔记本。完全免费、开放源代码，数据留在你自己的设备上。",
        "buttons": [],
        "steps": [
          "平板、手机与台式机都能用；手写用触控笔最顺手，用手指或鼠标同样可以写。",
          "第一次打开不需要注册账号，也不需要联网。",
          "第一次打开会有两本范例笔记（「欢迎使用 Kairumo」与「课堂与会议记录」），里面是可以直接改的图、文、表范例。不需要就整本删掉。",
          "你写下的每一笔都存在这台设备里。要在多台设备之间同步，就挑一个自己的云端硬盘文件夹（见「数据备份与同步」）。",
          "台式机版窗口左上角会显示版本号（例如 Kairumo v4.8.0），反馈问题时请附上它。"
        ],
        "tip": "没有服务器、没有账号，就没有“忘记密码”这回事 —— 但也意味着设备丢失时没有云端副本，请自己做备份。",
        "fig": null
      },
      {
        "id": "firstrun",
        "title": "第一次打开",
        "lead": "第一次启动会先用一页讲清楚要哪一个权限、为什么要。看完就进首页，之后不会再出现。",
        "buttons": [
          "允许使用麦克风",
          "稍后再说",
          "开始使用"
        ],
        "steps": [
          "这一页讲三件事：Kairumo 是什么、不需要账号也没有我们的服务器、以及唯一会用到的那一个权限。",
          "只有**麦克风**一个权限，而且只有录音会用到。不给也可以 —— 手写、打字、导出、同步全都不受影响。",
          "按「允许使用麦克风」才会弹出系统的权限对话框。那个对话框**一个 App 一辈子只会出现一次**。",
          "如果当时按了不允许，按钮会换成「前往设置」。那之后只能从系统设置里把权限打开，App 自己没有办法再问你一次。",
          "按「开始使用」进入首页。这一页之后不会再出现。"
        ],
        "tip": "权限不会在安装的时候就要 —— 系统一律等到真的要用那个功能才问。所以还没给权限就按录音的话，会在那个当下再引导一次。",
        "fig": null
      },
      {
        "id": "home",
        "title": "首页：你的工作台",
        "lead": "打开 App 看到的第一个画面。所有笔记、录音、素材与导入文件都从这里进入。",
        "buttons": [
          "编辑身份",
          "新增笔记",
          "开始录音",
          "素材图库",
          "导入笔记"
        ],
        "steps": [
          "最上方是你的显示身份 —— 协作时队友看到的就是这个名字，点右边的“编辑身份”可以修改。",
          "搜索栏可以同时搜索笔记标题、打字内容与录音转写出来的文字。",
          "中间四张大卡片是主要操作：新增笔记、开始录音、素材图库、导入笔记。",
          "“导入笔记”可以选择一个 .padnote 文件，把别人分享给你的原始笔记放进笔记库。",
          "“继续”列出最近打开过的笔记，点一下就回到上次的位置。",
          "“全部笔记”按文件夹分类显示；右上角可以切换排序方式。",
          "首页往下滚到底有「操作说明」与「隐私权政策」两张卡片 —— 你现在看的就是前者。",
          "首页录音列每一行右边的「⋯」里有「插入至笔记本」，可以挑笔记本与页次，把这段录音放到那一页上。"
        ],
        "tip": "每张笔记卡片右上角的“⋯”里有重命名、移动到文件夹与删除。",
        "fig": "home",
        "cap": "首页：身份、搜索、四个主要操作、继续、全部笔记"
      },
      {
        "id": "newnote",
        "title": "创建第一则笔记",
        "lead": "三十三种笔记页样板，分成七组；版面颜色也可以自己挑。",
        "buttons": [
          "新增笔记",
          "笔记页样板",
          "版面色彩",
          "确认"
        ],
        "steps": [
          "在首页点「新增笔记」。",
          "在「笔记标题」栏输入名称。不填也可以，之后随时能改。",
          "「笔记页样板」上排是主题胶囊，七组一次全部列出来、不必左右滑：通用基础、笔记方法、规划排程、清单追踪、美学视觉、工程制程、数字体验。",
          "点一个主题，下面就换成那一组的样板清单，每一种都有一行说明它适合做什么。",
          "「笔记方法」那一组是有结构的记法：康乃尔（提示栏／笔记栏／摘要）、四象限（重点／问题／决议／行动）、大纲（三层缩排）、双栏对照、一问一答、KWL、心智图。",
          "「规划排程」与「清单追踪」是月计划、周计划、日程表、24 小时时间轴、学习计划、专案时程、待办清单、勾选清单、习惯追踪、作业追踪、家事分工、21 天挑战。",
          "最下面是「版面色彩」六个色点：石墨、靛蓝、青绿、玫瑰、琥珀、森绿。选哪一个，版面的线条、标题底色与栏位名称就跟着换。",
          "点右上角「确认」，笔记会立刻打开，可以直接开始写。"
        ],
        "tip": "样板只是版面，换掉不会影响已经写下的内容。而且进去之后**每一页还可以各用各的样板** —— 见「页面与文件夹」。版面色彩是整本一个调子，随时在编辑画面上排改得动。",
        "fig": "newnote",
        "cap": "新增笔记本窗口：标题、主题胶囊、样板清单与版面色彩"
      },
      {
        "id": "editor",
        "title": "认识编辑界面",
        "lead": "先花一分钟认位置，后面每一步都会用到。",
        "buttons": [
          "首页",
          "笔记结构",
          "手绘模式",
          "打字模式"
        ],
        "steps": [
          "最上排从左到右：回首页、笔记结构、手绘／打字切换、笔记标题、页码、标尺、素材图库、插入、讨论图钉、在线协作、录音、导出与打印。",
          "第二排是当前模式的工具栏：手绘模式显示笔刷与颜色，打字模式显示文字排版。",
          "画布右上角有一张模式徽章，写着现在是手写还是打字，以及这个模式下笔会不会画线、物件动不动得了。",
          "左侧是结构栏，可切换“页面结构”与“文件夹目录”。",
          "中间是画布。页面高度固定，写到底会自动准备下一页；右下角也可以手动按「新增下一页」。",
          "窗口变窄时工具栏会自动换行，不会有按钮被挤到画面外。",
          "上排右侧有两个小按钮：**页面规格**（A4 竖式／横式、A5、Letter、Legal、演示 16:9、正方形）与**版面色彩**（六个色点）。换规格会同时改画布、分页与导出的尺寸；换颜色只影响版面的线条与标题。",
          "换成比较小的规格时，原本落在新页面外的物件会自动被收回页内 —— 不收的话那些东西在画布上看得到、打印出来却不见。",
          "页面上那一圈虚线是**可打印范围**，也就是编辑区域。完全写在框线外的笔画会被收回并提醒你；跨在线上的会留着，但也会提醒一次。",
          "长按或点击画布上的快捷图标可唤起“径向飞轮快捷盘”，向八个方向轻轻一挥即可盲切常用工具（笔刷、橡皮擦、套索、撤销、重做、进阶调色与平滑防抖），手指无需抬回屏幕顶端。"
        ],
        "tip": "屏幕不够宽时，点“笔记结构”把左栏收起来，画布立刻变宽。",
        "fig": "editor",
        "cap": "编辑界面：上排主工具栏、手绘工具栏、左侧结构栏与画布"
      },
      {
        "id": "write",
        "title": "手写",
        "lead": "七种笔、四挡粗细、可自定义颜色。写错可以擦，也可以整段圈起来搬家。",
        "buttons": [
          "钢笔",
          "橡皮擦",
          "套索选取",
          "笔迹粗细",
          "笔迹磁吸对齐与尺规",
          "进阶调色"
        ],
        "steps": [
          "确认上排停在“手绘模式”。",
          "从工具栏挑一支笔：钢笔、圆珠笔、毛笔、马克笔、荧光笔、铅笔、水彩笔。",
          "工具栏中间的四颗圆点选粗细，右边的色盘选颜色；点色盘旁的滑杆图标可自定义任何颜色。",
          "写错时选“橡皮擦”擦掉；想搬动或复制一整段笔迹，用“套索选取”圈起来再操作。",
          "最右边是撤销、重做与清除本页。",
          "写到页面底部时会自动新增下一页，不必手动延长。",
          "支持的触控笔可以不必回工具栏换橡皮擦：有的笔**双击笔杆**、有的笔**按住笔杆上的侧键**，也有的笔倒过来用就是橡皮擦。擦完再敲一次或松开侧键，就回到你刚才那支笔。双击要做什么是系统设置里的偏好，这里照它走。",
          "绘制直线与线段时开启“笔迹磁吸对齐与尺规”，笔尖接近 0°、45°、90°、135°、180° 等几何角度或网格线时会自动磁吸对齐，画面投射青色激光引导线并给予微震反馈。",
          "工具栏支持四段“笔迹平滑防抖”滤波，大幅消除书写微抖；点“进阶调色”可开启环形色相饱和度调色盘，支持互补与三角色等和谐配色。",
          "“画布极致极简模式”：点击工具栏收折按钮可将工具栏收纳为屏幕角落的单一悬浮胶囊（Floating Tool Pill），享受无干扰全屏书写。需要恢复时，点击顶部常驻的高亮“退出画布极简模式”按钮、点击悬浮气泡展开迷你工具箱、或在键盘上按下 Esc 键，即可立刻展开完整工具栏。"
        ],
        "tip": "用触控笔书写时可以直接把手掌放在屏幕上 —— 掌拒会忽略手掌，只认笔尖。手绘模式下画布上的物件是锁住的（不会被拖到）；要搬动或编辑物件请切到打字模式。",
        "fig": "editor",
        "cap": "手绘工具栏：笔刷、粗细、色盘与更多"
      },
      {
        "id": "type",
        "title": "打字",
        "lead": "在画布上任何位置放文本框，和手写混排。",
        "buttons": [
          "打字模式",
          "文字排版",
          "特殊符号",
          "插入链接",
          "锚定至文本"
        ],
        "steps": [
          "点上排的键盘图标，切换到“打字模式”。",
          "在画布空白处**点两下**，该位置就会出现文本框并弹出键盘。（是点两下不是点一下 —— 单击留给滚动与选取物件。）",
          "点“文字排版”可以调字号、粗体、斜体、下划线、对齐与文字颜色。",
          "“特殊符号”可插入数学与常用符号；“插入链接”粘贴网址后会变成可点击的预览卡片。",
          "文本框可以直接拖动，拖右下角的把手可以改变大小。",
          "「框选」可以拉一个框把多个物件一次选起来，接着整组搬移、复制、粘贴、创建副本或删除。在选取范围里拖曳就是整组搬移。",
          "“动态流式锚定”：选取文本框或框选周边手写笔画后点“锚定至文本”，手写批注将牢牢锚定在文字旁；拖曳文本框或增删文字排版时，手写笔画会即时自动平移跟随，绝不脱节跑位。"
        ],
        "tip": "打字模式下**笔也不会画线** —— 这个模式只处理文字与物件。要写字请切回手绘模式。链接卡片插入后选取它，左下角的铅笔可以改网址、标题与说明。",
        "fig": "typing",
        "cap": "打字模式工具栏：文字排版、特殊符号、插入链接与更多"
      },
      {
        "id": "pages",
        "title": "页面与文件夹",
        "lead": "一则笔记可以有很多页，每一页可以用不同的样板；很多则笔记可以放进文件夹。",
        "buttons": [
          "笔记结构",
          "页面结构",
          "文件夹目录",
          "选取页面"
        ],
        "steps": [
          "点上排「笔记结构」开关左栏。",
          "「页面结构」列出这则笔记每一页的缩图，点缩图就跳到那一页。",
          "**在缩图上按右键或长按**会叫出快显菜单 —— 内容与每页右上角那颗「⋯」完全一样，用哪个都可以。",
          "菜单里有：在后方插入新页面、插入其他样板页面、创建此页副本、复制到其他笔记本、移动到其他笔记本、上移一页、下移一页、移到最前、移到最后、删除此页。",
          "**插入其他样板页面**：先选主题，再选样板，新的一页就会插在这一页后面 —— 同一本笔记里可以一页四象限、一页日程表。",
          "**换页面顺序**有两种做法：菜单里的上移／下移／移到最前／最后，或直接把缩图拖到目标位置（拖曳时会出现一条落点指示线）。",
          "**把几页搬到别本笔记**：点侧栏标题列的勾选钮进入多选，勾好要的几页（或按「全选」），再按底下的「复制到…」或「移动到…」，然后挑目的笔记本。",
          "侧栏底部的「−／＋」调整缩图大小；放大到比侧栏宽时，侧栏会自己跟着拉开。",
          "侧栏与画布之间的界线**可以左右拖曳**改变宽度，侧栏里的文字会跟着放大；连点两下回到默认宽度。",
          "切到「文件夹目录」可以看到所有文件夹与笔记；可新增子文件夹、重新命名、把笔记搬到别的文件夹。",
          "**把笔记拖进文件夹**：按住笔记往文件夹那一列放开。要拿出来，就拖到最上面的根目录那一列，或拖到「未分类文件」那一段（空的时候也在，会显示一行提示）。不想拖曳的话，笔记右边的「⋯」里也有「移出文件夹」。",
          "在文件夹目录直接点另一则笔记，就会在同一个窗口切换过去，不用先回首页。"
        ],
        "tip": "一本笔记至少要留一页 —— 所以整本全选之后，「移动到…」会停用（「复制到…」仍然可用）。复制过去的页面连同上面的表格、图形与文字方块一起走，而且会拿到新的身分，之后改其中一份不会动到另一份。",
        "fig": "folders",
        "cap": "左侧结构栏的「文件夹目录」：根文件夹、子文件夹与笔记清单"
      },
      {
        "id": "insert",
        "title": "插入图片、素材与图表",
        "lead": "照片、实体规格素材、算式、图表与 3D 模型都能放进画布。",
        "buttons": [
          "插入",
          "插入图片",
          "素材图库",
          "算式计算"
        ],
        "steps": [
          "点上排“插入”。窗口较窄时，这些项目会收在“⋯”菜单里。",
          "“插入图片”从相册挑一张照片；插入后可拖动、缩放、加圆角与边框。",
          "“素材图库”内含机械、3C、汽摩、家具等实体规格素材，下载后即可插入画布。",
          "“算式计算”与“数字制图”可以把算式或图表变成卡片放进笔记。",
          "“插入 3D 模型”放进可 360° 旋转的立体模型。",
          "「插入录音」把既有的录音放到这一页上，变成一张可播放的卡片 —— 可以搬、可以缩放、可以改名，也可以删掉。",
          "图片也可以**直接从别的 App 拖进来** —— 两个 App 并排时把图拖到画布上就好，见「并排与拖放」。"
        ],
        "tip": "素材图库的文件下载在本机，可以在图库里删除以释放空间；已插入画布的图不会受影响。",
        "fig": "insertmenu",
        "cap": "插入菜单：素材图库、插入图片、算式计算、3D 模型、讨论图钉与在线协作",
        "fig2": "assetlib",
        "cap2": "素材图库：按分类浏览，点“下载”后即可插入"
      },
      {
        "id": "data",
        "title": "数据备份与同步",
        "lead": "不需要账号，也没有我们的服务器。备份是一个文件，同步是一个你自己的云端文件夹。",
        "buttons": [
          "创建备份",
          "从备份恢复",
          "选择文件夹",
          "立即同步"
        ],
        "steps": [
          "首页的“数据与同步”区块里有四张卡片，点任一张会打开该功能的专属说明与操作窗口。",
          "“云端同步”会显示目前是否登录，点进去可以登录、查看同步位置并立即同步。",
          "“创建备份”把所有笔记、图片与录音打包成一个文件，存到你指定的位置。",
          "“从备份恢复”挑一个备份文件还原。恢复前会先自动备份当前数据，选错文件也救得回来。",
          "文件夹同步：先在自己的云端硬盘里建一个文件夹（例如叫 Kairumo），按“选择文件夹”指到它。",
          "在另一台设备上做同样的事，指到**同一个**文件夹。",
          "两边各按一次“立即同步”。A 设备写的东西，B 设备按下同步之后就会出现。",
          "Kairumo 采用严格的“同目录暂存文件 ＋ 实体磁盘同步（fsync）＋ 原子覆盖”存盘流程，退出笔记或切换到后台时自动即时存盘，即使设备突然断电或意外中断，也不会损坏文件或丢失笔迹。",
          "智能双轨同步与即时差异核实：同步启动前，系统会即时核实本机现存笔记本与云端差异样态，主动排除并清理已删除的残留套件，绝不对已删除档案发送无效请求；前台极速轨优先同步当前作用中笔记，其余笔记本于背景并行收敛。在云端同步窗口与系统诊断面板中，更提供“一键复制”与“导出文本档”功能，方便完整保存工程诊断日志。"
        ],
        "tip": "文件搬运交给你原本就在用的云端硬盘。我们不碰网络，也没有你的数据 —— 这也是为什么找不到“登录 Kairumo”。同步只会新增文件，不会覆盖别台设备写的内容。",
        "fig": null
      },
      {
        "id": "comment",
        "title": "讨论图钉",
        "lead": "把留言钉在画布的特定位置上，自己备忘或跟队友讨论都适用。",
        "buttons": [
          "新增讨论图钉",
          "标记为已解决"
        ],
        "steps": [
          "点“插入 → 新增讨论图钉”。",
          "在画布上想讨论的位置点一下，图钉就钉在那里，对话框会跟着打开。",
          "在下方输入框打字，按右边的箭头发送，就成为一条留言。",
          "对话框挡到内容时，按住最左边的“≡”握把把它拖到旁边。",
          "按“−”可以缩小成一条标题栏（缩小后一样可以拖动）；按“✕”关闭。",
          "讨论完成后按“标记为已解决”，图钉会变成灰色打勾。"
        ],
        "tip": "图钉会跟着笔记一起导出与同步；协作时所有人都看得到同一批图钉。",
        "fig": "comment",
        "cap": "讨论图钉对话框：拖动握把、已解决、删除、缩小与关闭",
        "fig2": "pin_min",
        "cap2": "缩小后的精简标题栏 —— 仍然可以拖动"
      },
      {
        "id": "collab",
        "title": "在线协作（手把手）",
        "lead": "多人实时共笔。没有云端服务器 —— 中继永远是你自己掌握的那一台。分成两种情况：大家在同一个网络，或散在不同网域。两种都可以，只是设定的那一行不一样。",
        "buttons": [
          "在线协作",
          "开始多人协作",
          "复制加密邀请链接",
          "加入协作房间",
          "协作服务器地址",
          "结束协作会议"
        ],
        "steps": [
          "**先决定是哪一种情况。** 同一间办公室、同一个 Wi-Fi → 走“情况 A”。有人在家、有人在公司、甚至在国外 → 走“情况 B”。",
          "── **情况 A：大家在同一个网络** ──",
          "**A1｜由其中一人当房主。** 打开要共笔的那本笔记 → 点上排的“在线协作”→ 按“开始多人协作”。",
          "**A2｜房主画面上会出现三样东西：**（一）房间标识码，例如 kairumo-a1b2c3；（二）绿色的“端到端加密保护”；（三）一行“本机正在提供协作中继　ws://192.168.x.x:9002”。第三行队友等下要用，先别关掉。",
          "**A3｜队友先设置服务器地址。** 队友打开任一本笔记 → “在线协作”→ 展开最下面的“协作服务器地址”→ 把 ws://127.0.0.1:9002 改成**房主画面上那一行地址**。127.0.0.1 的意思是“我自己这台”，不改的话队友是在连自己。",
          "── **情况 B：不在同一个网络** ──",
          "**协作没有被绑在同一个网络上。** 你需要的只是一个双方都连得到的中继地址，而且它必须是 **wss://**（加密）。房号与成员名单是明文传送的，所以公开网络上不接受 ws://。三种取得方式，由易到难：",
          "**B-1｜虚拟局域网（最省事，不必自架）。** 所有设备装上 Tailscale（或 ZeroTier）并登录同一个账号，它们就像在同一个网段。房主把自己的 Tailscale 地址告诉队友，大家填 ws://100.x.y.z:9002 就好 —— 那是私有网段，不需要 TLS。",
          "**B-2｜把房主那台的中继打通道出去（不必服务器、不必账号）。** 在房主那台电脑上执行：cloudflared tunnel --url http://localhost:9002　它会打印一个 https://xxxx.trycloudflare.com。队友把“协作服务器地址”填成 wss://xxxx.trycloudflare.com（把 https 换成 wss）。关掉终端通道就结束。",
          "**B-3｜自己架一台（长期使用）。** 在任何有公开地址的机器上执行 padnote-relay（HOST=0.0.0.0 PORT=9002），前面用 Caddy 或 nginx 上 TLS，大家填 wss://relay.你的网域。做法见项目里的 docs/relay-hosting.md。",
          "── **两种情况接下来都一样** ──",
          "**步骤 1｜房主按“复制加密邀请链接”，把链接发给队友。** 链接长这样：kairumo://collab?room=kairumo-a1b2c3#key=…",
          "⚠️ **只发房号是不够的。** 井号后面那一段 key 才是解密用的密钥。只拿到房号的人连得上、也看得到成员列表，但**对方写的每一个字都解不开**，画面上什么都不会发生（这时会出现一则橙色提醒）。一定要发整条链接。",
          "**步骤 2｜队友粘贴链接加入。** 在“加入协作房间”的输入框粘贴整条邀请链接 → 按“加入协作房间”。",
          "**步骤 3｜确认真的连上了。** 两台设备的“在线成员”都要看到对方的名字，房主那台会标注“房主（拥有者）”。看到两个人，就成功了。",
          "**步骤 4｜开始共笔。** 现在任何一台的笔画、文本框、表格、图形与讨论图钉，都会实时出现在另一台上。",
          "**步骤 5｜结束。** 房主按“结束协作会议”，房间关闭；队友按“断开连接”则只有自己离开。"
        ],
        "tip": "设备种类没有差别：所有设备用的是同一套房号、同一套密钥、同一个中继协议，谁当房主都可以。内容以 AES-256-GCM 端到端加密，中继点只转发看不懂的密文 —— 就算用的是别人的通道服务，它也读不到你的笔记。离线期间的操作会先暂存，连接恢复后自动补发。",
        "fig": "collab",
        "cap": "尚未连接：开始多人协作、加入协作房间、协作服务器地址",
        "fig2": "collab_on",
        "cap2": "已连接：房间标识码、端到端加密、本机正在提供中继、在线参与者"
      },
      {
        "id": "record",
        "title": "录音与转写",
        "lead": "录音与笔迹走同一条时间轴 —— 点文字就能跳回当时写下的那一笔。",
        "buttons": [
          "开始录音",
          "暂停录音",
          "继续录音",
          "完成录音",
          "最近录音与转写",
          "转录文字",
          "声笔动态同步"
        ],
        "steps": [
          "在首页点“开始录音”，或在笔记里点上排的麦克风图标。",
          "第一次使用会询问麦克风权限，请选择允许。",
          "录音中画面上方会显示实时波形；此时写下的笔迹会自动与声音对齐。",
          "需要停一下时按“暂停录音”；要接着录就按“继续录音”。按“完成录音”才会结束并保存。",
          "停止后，该段录音会出现在首页的“最近录音与转写”。",
          "播放时点某一段转写文字，画面会跳到当时写下的笔迹；反过来点笔迹也可以跳到对应的声音。",
          "要把某段录音放进某一页：在笔记里点「更多 → 插入录音」，或在首页的录音列点「⋯ → 插入至笔记本」。",
          "选取页面上的录音卡片后，点左上角的“转录文字”按钮，Kairumo 会把音频转成文本框并放在卡片下方。",
          "支持“声笔动态同步”卡拉 OK：回放录音时，当时书写的笔画会伴随语音进度发光高亮；直接在画布上点击任一笔迹，录音进度条会立刻跳转至该笔画书写时的精确时间点。"
        ],
        "tip": "录音与转录都在这台设备上完成，不会上传到任何服务器。转录需要一个在设备上跑的引擎，而**不是每台设备都有** —— 没有的话录音照常运作，只是首页的录音列不会出现转录文字，录音卡片也可能无法产生文本框。",
        "fig": "home",
        "cap": "首页的“开始录音”与“最近录音与转写”"
      },
      {
        "id": "export",
        "title": "导出、打印与分享",
        "lead": "四种输出方式，按对方需要选一种。",
        "buttons": [
          "导出与打印",
          "导出 PDF",
          "导出为图片",
          "打印笔记",
          "分享笔记"
        ],
        "steps": [
          "点右上角的“导出与打印”。",
          "“导出 PDF”把整本笔记转成 PDF，适合发给别人或存档。",
          "“导出为图片”输出当前这一页的图片文件。",
          "“打印笔记”走系统打印流程。",
          "“分享笔记”发出 .padnote 原始文件，对方用 Kairumo 打开可以继续编辑。"
        ],
        "tip": "PDF 内的批注坐标与原稿一致，用其他 App 打开也不会跑位。",
        "fig": "export",
        "cap": "导出与打印菜单：导出 PDF、导出为图片、打印笔记、分享笔记"
      },
      {
        "id": "keys",
        "title": "键盘快捷键",
        "lead": "接上实体键盘时，常用的动作都有快捷键。",
        "buttons": [],
        "steps": [
          "下面写的「⌘」，在有 Command 键的键盘上就是 Command；其余键盘请改按 **Ctrl**。",
          "**⇧⌘N**：新增笔记。是加上 Shift 的 —— 不加的 ⌘N 是系统的「新建窗口」，两个撞在一起的话两边都会失效。",
          "**⌘F**：光标直接跳进首页的搜索栏。",
          "**⌘E**：手绘与打字两个模式互换。",
          "**⌘1** 起算：依工具栏上的顺序切换笔刷与工具。工具比数字少的时候，多出来的数字没有作用。"
        ],
        "tip": "光标在文本框里的时候，⌘A、⌘C、⌘V 仍然是全选、复制、粘贴 —— 这些快捷键不会把它们抢走。",
        "fig": null
      },
      {
        "id": "multi",
        "title": "并排与拖放",
        "lead": "把 Kairumo 与另一个 App 并排，可以把图片直接拖进画布。",
        "buttons": [],
        "steps": [
          "在平板或桌面设备上，用系统的分屏把 Kairumo 与相册（或文件、浏览器）并排。",
          "从另一边按住一张图片，拖到 Kairumo 的画布上。画布会浮现一圈虚线，表示可以放下了。",
          "放开之后，图片会落在你放手的位置，并且自动缩到适合页面的大小、保持原比例。",
          "拖到页面边缘时图片会自动往内靠 —— 不会有一半跑到页面外（跑出去的那一半在导出与打印时会被裁掉）。",
          "放进来之后会自动切到打字模式，这样可以马上拖动与缩放它。",
          "并排时窗口变窄，工具栏会自动换行，不会有按钮被挤到看不见的地方。"
        ],
        "tip": "拖进来的图片与从「插入图片」放进来的完全一样 —— 一样可以缩放、旋转、加圆角与外框。",
        "fig": null
      },
      {
        "id": "language",
        "title": "语言与显示身份",
        "lead": "界面支持六种语言，随时切换、立即生效。",
        "buttons": [
          "界面语言",
          "编辑身份"
        ],
        "steps": [
          "在首页右上角点「界面语言」—— 地球图标旁边就是这几个字。",
          "从列表中选择：繁體中文、English、简体中文、日本語、한국어、ไทย。",
          "界面会立刻切换，不需要重启 App。",
          "回到首页上方点“编辑身份”，可以修改协作时显示的名字与代表色。"
        ],
        "tip": "显示身份只存在这台设备上，不会上传到任何地方。",
        "fig": "language",
        "cap": "语言菜单：六种语言即时切换"
      },
      {
        "id": "faq",
        "title": "常见问题",
        "lead": "遇到状况时先看这里。",
        "buttons": [],
        "faq": [
          [
            "为什么打字模式下笔画不出东西？",
            "那是刻意的。打字模式只处理文字与物件 —— 手指与触控笔都不会画线，这样点选、拖曳物件才不会每次都留下一条笔迹。画布右上角的徽章会写着目前是哪个模式。要写字就切回手绘模式。"
          ],
          [
            "在线协作连不上怎么办？",
            "先确认两台设备在同一个 Wi-Fi。队友的“协作服务器地址”必须填房主画面上显示的 ws://…:9002，而不是默认的 127.0.0.1。首次连接时系统会询问局域网权限，要选允许。"
          ],
          [
            "笔记会不会丢失？",
            "每一笔都实时写入本机文件。同步文件只新增不修改，每台设备只写自己的文件，所以不会互相覆盖。"
          ],
          [
            "需要注册账号吗？",
            "不需要。Kairumo 没有账号系统，也没有后端服务器。"
          ],
          [
            "手写可以转成文字吗？",
            "可以。使用系统内置的设备端识别，不会把笔迹传上网。"
          ],
          [
            "怎么反馈问题？",
            "请附上台式机版窗口左上角显示的版本号（例如 Kairumo v4.8.0）与操作步骤。"
          ],
          [
            "同一本笔记可以混用不同的页面格式吗？",
            "可以。在「页面结构」的缩图上按右键或长按 →「插入其他样板页面」→ 选主题与样板，新的一页就会用那一种版面，其余页面不受影响。创建笔记时选的那一个只是**默认值**。"
          ],
          [
            "写到框线外面会怎样？",
            "那一圈虚线是可打印范围，也是编辑区域。完全写在外面的笔画会被收回并跳出一则提醒 —— 因为它打印不出来也导不出去，留着只会让人以为它还在。跨在线上的笔画会留着，但也会提醒一次。"
          ]
        ],
        "fig": null
      }
    ]
  },
  "ja": {
    "name": "日本語",
    "figset": "en",
    "ui": {
      "docTitle": "Kairumo 操作マニュアル",
      "tagline": "手書き・タイピング・録音をひとつにしたノート。はじめての方でも順番どおりに進められます。",
      "version": "対象バージョン v4.8.0（build 58）· 2026年9月19日",
      "tocTitle": "目次",
      "tocHint": "項目をタップすると該当セクションへ移動します",
      "stepsLabel": "手順",
      "tipLabel": "ヒント",
      "buttonsLabel": "使うボタン",
      "figNote": "スクリーンショットは英語表示です",
      "backToTop": "目次へ戻る",
      "langLabel": "言語",
      "privacyLink": "プライバシーポリシー"
    },
    "sections": [
      {
        "id": "start",
        "title": "はじめる前に",
        "lead": "Kairumo は手書き・タイピング・録音を同じタイムライン上に置くノートです。完全無料、オープンソース、データは端末内に留まります。",
        "buttons": [],
        "steps": [
          "タブレット・スマートフォン・デスクトップに対応。スタイラスが最適ですが、指やマウスでも書けます。",
          "アカウント登録もインターネット接続も不要です。",
          "初回起動時にサンプルノートが2冊（「Kairumo へようこそ」と「授業と会議の記録」）入っています。そのまま編集できる文章・表・グラフ・図形の例です。不要なら削除してください。",
          "書いた内容はこの端末に保存されます。複数の端末で同期するには、ご自身のクラウドのフォルダを指定してください（「バックアップと同期」参照）。",
          "デスクトップ版ではウインドウのタイトルにバージョン（例：Kairumo v4.8.0）が表示されます。不具合報告の際は添えてください。"
        ],
        "tip": "サーバーもアカウントもないためパスワードを忘れる心配はありません。その代わりクラウド上の控えもないので、バックアップはご自身で。",
        "fig": null
      },
      {
        "id": "firstrun",
        "title": "はじめて開いたとき",
        "lead": "最初の起動時に、必要な権限とその理由を 1 ページで説明します。読み終えるとホームに進み、以降は表示されません。",
        "buttons": [
          "マイクを許可",
          "あとで",
          "はじめる"
        ],
        "steps": [
          "このページでは 3 つを説明します。Kairumo とは何か、アカウントも当方のサーバーも不要であること、そして使う可能性のある唯一の権限です。",
          "権限は**マイク**の 1 つだけで、使うのは録音のときだけです。許可しなくても手書き・入力・書き出し・同期はすべて動きます。",
          "「マイクを許可」を押してはじめてシステムの権限ダイアログが出ます。このダイアログは**アプリの一生で一度しか表示されません**。",
          "そこで拒否すると、ボタンは「設定を開く」に変わります。以降はシステム設定からしか有効にできず、アプリ側から再度たずねることはできません。",
          "「はじめる」を押すとホームに進みます。このページが再び出ることはありません。"
        ],
        "tip": "権限はインストール時には要求されません。システムは機能が実際に必要とするまでたずねない仕組みです。許可せずに録音を始めた場合は、そのときにあらためて案内されます。",
        "fig": null
      },
      {
        "id": "home",
        "title": "ホーム：作業台",
        "lead": "アプリを開いて最初に表示される画面です。ノート・録音・素材・読み込んだファイルはすべてここから。",
        "buttons": [
          "表示名を編集",
          "新規ノート",
          "録音開始",
          "アセットライブラリ",
          "ノートを読み込む"
        ],
        "steps": [
          "上部は表示名です。共同編集中に相手に見える名前で、「表示名を編集」から変更できます。",
          "検索欄はノートのタイトル・入力した文字・文字起こしをまとめて検索します。",
          "大きな4つのカードが主な操作です：新規ノート、録音開始、素材ライブラリ、ノートを読み込む。",
          "「ノートを読み込む」は .padnote ファイルを選び、共有された元のノートをライブラリに追加します。",
          "「続きから」には最近開いたノートが並び、タップすると続きから再開します。",
          "「すべてのノート」はフォルダ別の一覧です。右上で並び順を変えられます。",
          "ホーム画面を一番下までスクロールすると「操作マニュアル」と「プライバシーポリシー」のカードがあります。いま読んでいるのが前者です。",
          "ホームの録音一覧の各行にある「⋯」に「ノートに挿入」があります。ノートとページを選んでその録音を置けます。"
        ],
        "tip": "各ノートカード右上の「⋯」に、名前の変更・フォルダへ移動・削除があります。",
        "fig": "home",
        "cap": "ホーム：表示名、検索、4つの主要操作、Continue、All Notebooks"
      },
      {
        "id": "newnote",
        "title": "最初のノートを作る",
        "lead": "7 グループ 33 種類のページテンプレート。罫線の色も選べます。",
        "buttons": [
          "新規ノート",
          "ページテンプレート",
          "罫線の色",
          "OK"
        ],
        "steps": [
          "ホームで「新規ノート」をタップします。",
          "「ノートのタイトル」に名前を入力します。空欄のままでも、あとから変更できます。",
          "「ページテンプレート」の上段はテーマのチップです。7 つすべてが折り返して並ぶので、横スワイプは不要です：汎用、ノート術、計画・スケジュール、リスト・記録、ビジュアル、エンジニアリング、デジタル。",
          "テーマをタップすると下の一覧がそのグループに切り替わります。どれにも「何に向くか」が 1 行で書いてあります。",
          "「ノート術」は構造のある記法です：コーネル（キーワード／ノート／まとめ）、4 象限（要点／疑問／決定／行動）、アウトライン（3 段インデント）、2 カラム対照、一問一答、KWL、マインドマップ。",
          "「計画・スケジュール」「リスト・記録」には、月間・週間・1 日のスケジュール・24 時間タイムライン・学習プランナー・プロジェクト工程・ToDo・チェックリスト・習慣トラッカー・課題トラッカー・家事分担表・21 日チャレンジがあります。",
          "いちばん下の「罫線の色」は 6 色：グラファイト、インディゴ、ティール、ローズ、アンバー、フォレスト。線・見出しの帯・項目名がすべて選んだ色に変わります。",
          "右上の「OK」をタップすると、そのままノートが開きます。"
        ],
        "tip": "テンプレートはレイアウトだけなので、変えてもすでに書いた内容には影響しません。しかもノートを開いたあとは**ページごとに別のテンプレートを使えます**（「ページとフォルダ」参照）。罫線の色はノート全体で 1 つ、編集画面の上段からいつでも変更できます。",
        "fig": "newnote",
        "cap": "新規ノート：タイトル、テーマ、テンプレート一覧、罫線の色"
      },
      {
        "id": "editor",
        "title": "編集画面の見取り図",
        "lead": "最初に位置を覚えておくと、以降の操作が迷いません。",
        "buttons": [
          "ホーム",
          "ノート構造",
          "手描き",
          "タイピング"
        ],
        "steps": [
          "最上段は左から：ホーム、ノート構成、手書き／入力の切り替え、タイトル、ページ番号、定規、素材ライブラリ、挿入、コメントピン、共同編集、録音、書き出しと印刷。",
          "2段目は現在のモードのツールバーです（手書きならブラシと色、入力なら文字書式）。",
          "キャンバス右上にモードバッジがあります。手書きか入力か、そのモードでペンが描くか、オブジェクトを動かせるかが書いてあります。",
          "左側は構成パネルで、ページ一覧とフォルダ一覧を切り替えられます。",
          "中央がキャンバスです。ページの高さは固定で、下端まで書くと次のページが自動で用意されます。右下の「次のページを追加」で手動でも追加できます。",
          "ウインドウが狭いとツールバーは自動で折り返し、ボタンが画面外に消えることはありません。",
          "上段の右側に小さなボタンが 2 つあります：**ページ規格**（A4 縦／横、A5、レター、リーガル、16:9 スライド、正方形）と**罫線の色**（6 色）。規格を変えると、キャンバス・改ページ・書き出しサイズが一緒に変わります。色はレイアウトの線と見出しだけに効きます。",
          "小さい規格に変えると、新しいページからはみ出す位置にあったものは自動的にページ内へ戻されます。戻さないと、画面では見えているのに印刷すると消えてしまいます。",
          "ページ上の破線は**印刷可能範囲**、つまり編集領域です。完全に枠外に書かれたストロークは取り消され、理由が表示されます。枠にまたがるものは残りますが、一度だけ知らせます。",
          "キャンバスのショートカットを長押しまたはタップすると「ラジアルマークメニュー」が開き、8方向にフリックするだけで主要ツール（ペン、消しゴム、投げ縄、取り消し、やり直し、高度な調色、手ぶれ補正）をブラインド操作で切り替えられます。"
        ],
        "tip": "幅が足りないときは「ノート構造」で左の列をたたむと、キャンバスが広がります。",
        "fig": "editor",
        "cap": "編集画面：上部ツールバー、手書きツールバー、構成パネル、キャンバス"
      },
      {
        "id": "write",
        "title": "手書き",
        "lead": "7種類のペン、4段階の太さ、自由な色。消すことも、まとめて囲んで動かすこともできます。",
        "buttons": [
          "ペン",
          "消しゴム",
          "投げ縄",
          "線の太さ",
          "磁気スナップと定規",
          "高度な調色"
        ],
        "steps": [
          "上部が手書きモードになっていることを確認します。",
          "ペンを選びます：万年筆、ボールペン、筆、マーカー、蛍光ペン、鉛筆、水彩。",
          "中央の4つの丸が太さ、右側が色です。スライダーのアイコンで自由に色を作れます。",
          "消すときは消しゴム。まとめて移動・複製するときは投げ縄で囲みます。",
          "右端に取り消し・やり直し・ページ消去があります。",
          "ページの下端まで書くと自動的に次のページが追加されます。",
          "対応するスタイラスなら、消すたびにツールバーへ戻る必要はありません。**ペン軸をダブルタップ**するもの、**軸のサイドボタンを押している間**だけ切り替わるもの、**逆さにする**と消しゴムになるものがあります。もう一度タップするかボタンを離せば、さっきまで使っていたペンに戻ります。ダブルタップの動作はシステム設定の設定に従います。",
          "直線や幾何線画を描く際に「磁気スナップと定規」をオンにすると、0°・45°・90°・135°・180° などの標準角度やグリッドに自動吸着し、シアンのレーザー誘導線と触覚フィードバックでお知らせします。",
          "ツールバーでは4段階の「手ぶれ補正」でペンの微細な震えを抑えられます。「高度な調色」を開くと、補色やトライアドなどの配色調和に対応した色相・彩度サークルで色を作れます。",
          "「キャンバス極小ミニマルモード」：ツールバーの折りたたみボタンをタップすると、画面隅のフローティングカプセルに収納され、邪魔のない全画面手書きを楽しめます。復帰したい時は、上部バーに常駐する強調「キャンバス極小モードを終了」ボタンを押すか、フローティングバブルをタップしてミニツールボックスを展開するか、キーボードの Esc キーを押すだけで瞬時にツールバーが再展開されます。"
        ],
        "tip": "スタイラスで書くときは手のひらを画面に置いて構いません。パームリジェクションが手のひらを無視してペン先だけを拾います。手書きモードではキャンバス上のオブジェクトはロックされていて誤って動きません。移動や編集は入力モードで行ってください。",
        "fig": "editor",
        "cap": "手書きツールバー：ブラシ、太さ、色、ページ延長、その他"
      },
      {
        "id": "type",
        "title": "タイピング",
        "lead": "キャンバスの好きな位置にテキストボックスを置き、手書きと混在させられます。",
        "buttons": [
          "タイピング",
          "文字スタイル",
          "特殊記号",
          "リンク挿入",
          "テキストに固定"
        ],
        "steps": [
          "上部のキーボードアイコンで入力モードに切り替えます。",
          "キャンバスの空いている場所を**ダブルタップ**すると、その位置にテキストボックスが現れてキーボードが開きます。（シングルタップはスクロールとオブジェクト選択に使うため、ダブルタップです。）",
          "「文字スタイル」で文字サイズ・太字・斜体・下線・揃え・色を設定します。",
          "「特殊記号」は数式や記号、「リンク挿入」は貼り付けた URL をプレビューカードにします。",
          "テキストボックスはドラッグで移動、右下のハンドルでサイズ変更できます。",
          "「範囲選択」で枠をドラッグすると複数のオブジェクトをまとめて選べます。そのあと一括で移動・コピー・貼り付け・複製・削除ができます。選択範囲の中をドラッグすると全体が動きます。",
          "「動的フロー固定」：テキストボックスや周辺の手書きを選択して「テキストに固定」をタップすると、手書き注記がテキストに固定されます。テキストボックスを移動したり文字を編集して段落が変化しても、手書きが自動で追従し位置ずれを防ぎます。"
        ],
        "tip": "入力モードでは**ペンでも描けません**。このモードは文字とオブジェクト専用です。書くときは手書きモードに戻してください。挿入したリンクカードを選ぶと、左下の鉛筆で URL・タイトル・説明を編集できます。",
        "fig": "typing",
        "cap": "入力モードのツールバー：Text Studio、記号、リンク挿入、その他、ページ延長"
      },
      {
        "id": "pages",
        "title": "ページとフォルダ",
        "lead": "1 冊のノートに複数ページ、ページごとに別のテンプレート。ノートはフォルダにまとめられます。",
        "buttons": [
          "ノート構造",
          "ページ",
          "フォルダ",
          "ページを選択"
        ],
        "steps": [
          "上段の「ノート構造」で左の欄を開閉します。",
          "「ページ」はこのノートの各ページのサムネイルです。タップするとそのページへ移動します。",
          "**サムネイルを右クリック、または長押し**するとメニューが出ます。各ページ右上の「⋯」とまったく同じ内容なので、押しやすいほうで構いません。",
          "メニューの項目：後ろにページを挿入、テンプレートを選んでページを挿入、このページを複製、別のノートへコピー、別のノートへ移動、ページを上へ／下へ、先頭へ／末尾へ、ページを削除。",
          "**テンプレートを選んでページを挿入**：テーマ → テンプレートの順に選ぶと、このページの直後に新しいページが入ります。1 冊の中に 4 象限のページと 1 日のスケジュールのページを混在させられます。",
          "**並べ替え**は 2 通り：メニューの「上へ／下へ／先頭へ／末尾へ」か、サムネイルを直接ドラッグ（落ちる位置に線が出ます）。",
          "**別のノートへページを移す**：サイドバー見出しのチェックボタンで選択モードに入り、必要なページにチェック（「すべて選択」もあります）、下の「コピー先…」または「移動先…」を押して、行き先のノートを選びます。",
          "サイドバー下部の「−／＋」でサムネイルの大きさを変えられます。サイドバーより大きくすると、サイドバーの幅も一緒に広がります。",
          "サイドバーとキャンバスの**境界線は左右にドラッグ**できます。サイドバー内の文字も一緒に大きくなります。ダブルタップで既定の幅に戻ります。",
          "「フォルダ」に切り替えると、すべてのフォルダとノートが見えます。サブフォルダの追加、名前の変更、ノートの移動ができます。",
          "**ノートをフォルダへ入れる**には、ノートをフォルダの行にドラッグします。**出す**には、いちばん上のルートの行、または「未分類」の区画（空でも常に表示され、案内が 1 行出ます）へドラッグします。ドラッグを使いたくなければ、ノート右の「⋯」にも「フォルダから出す」があります。",
          "フォルダ一覧で別のノートをタップすると、同じウインドウのまま切り替わります。ホームに戻る必要はありません。"
        ],
        "tip": "ノートには最低 1 ページ必要なので、全ページを選ぶと「移動先…」は無効になります（「コピー先…」は使えます）。コピーしたページは表・図形・テキストボックスごと移り、新しい識別子が付くため、片方を編集しても、もう片方は変わりません。",
        "fig": "folders",
        "cap": "フォルダ一覧：ルート、サブフォルダ、ノート"
      },
      {
        "id": "insert",
        "title": "画像・素材・図表の挿入",
        "lead": "写真、実物の仕様素材、数式、グラフ、3Dモデルをキャンバスに置けます。",
        "buttons": [
          "挿入",
          "画像を挿入",
          "アセットライブラリ",
          "数式計算"
        ],
        "steps": [
          "上部の「挿入」をタップします。ウインドウが狭いときは「⋯」の中にまとまります。",
          "「画像を挿入」で写真を選びます。配置後はドラッグ・拡大縮小・角丸・枠線が設定できます。",
          "「アセットライブラリ」には機械、電子機器、車両、家具などの仕様素材があり、ダウンロードして配置できます。",
          "「数式計算」「グラフ作成」は数式やグラフをカードにしてページに置きます。",
          "「3Dモデルを挿入」は 360° 回転できる立体モデルを配置します。",
          "「録音を挿入」は既存の録音をこのページに再生できるカードとして置きます。移動・サイズ変更・名前変更・削除ができます。",
          "画像は**別のアプリから直接ドラッグして**入れることもできます。2 つを並べてキャンバスに落とすだけです。「並べて表示とドラッグ＆ドロップ」を参照してください。"
        ],
        "tip": "素材ファイルは端末にダウンロードされます。ライブラリから削除すれば容量を戻せます（配置済みの素材は影響を受けません）。",
        "fig": "insertmenu",
        "cap": "挿入メニュー：素材ライブラリ、画像、数式、3Dモデル、コメントピン、共同編集",
        "fig2": "assetlib",
        "cap2": "素材ライブラリ：カテゴリから探し、ダウンロードして配置"
      },
      {
        "id": "data",
        "title": "バックアップと同期",
        "lead": "アカウントも当方のサーバーも不要です。バックアップは 1 つのファイル、同期はご自身のクラウドフォルダです。",
        "buttons": [
          "バックアップを作成",
          "バックアップから復元",
          "同期フォルダを選択",
          "今すぐ同期"
        ],
        "steps": [
          "ホーム画面の「データと同期」には 4 枚のカードがあります。どれかをタップすると、その機能専用の説明と操作画面が開きます。",
          "「クラウド同期」は現在サインインしているかを表示し、サインイン・同期先・今すぐ同期の操作を開きます。",
          "「バックアップを作成」はノート・画像・録音を 1 つのファイルにまとめ、指定した場所へ保存します。",
          "「バックアップから復元」はバックアップファイルを選んで復元します。復元前に現在のデータを自動でバックアップするため、間違えても戻せます。",
          "フォルダ同期：ご自身のクラウドにフォルダ（例：Kairumo）を作り、「同期フォルダを選択」で指定します。",
          "もう一方の端末でも同じフォルダを指定します。",
          "両方で「今すぐ同期」を押します。一方で書いた内容は、もう一方が同期したあとに表示されます。",
          "Kairumo は「一時ファイル ＋ 物理ディスク同期（fsync）＋ 不可分な置換」による厳格な保存処理を採用しており、ノートを閉じた際やバックグラウンド移行時にも即時保存されます。電源喪失時でも破損やデータの消失を防ぎます。",
          "デュアルトラック同期とリアルタイム差分照合：同期開始前にローカルの既存ノートとクラウドインデックスの差分を即時照合し、削除済みの不要パッケージを自動除外・クリーンアップします。フォアグラウンド高速レーンで編集中ノートを最優先同期し、残りはバックグラウンド並行キューで処理します。さらにクラウド同期シートや診断ツールでは「ワンクリックコピー」と「ログファイル書き出し」を提供し、エンジニアリングログを簡単に保存できます。"
        ],
        "tip": "ファイルの運搬は普段お使いのクラウドが担当します。当方はネットワークに触れず、データも保持しません。だから「Kairumo にサインイン」はありません。同期はファイルを追加するだけで、別の端末が書いた内容を上書きしません。",
        "fig": null
      },
      {
        "id": "comment",
        "title": "コメントピン",
        "lead": "キャンバスの特定の位置にコメントを留めます。自分用のメモにも、共同編集の議論にも。",
        "buttons": [
          "コメントピンを追加",
          "解決済み"
        ],
        "steps": [
          "「Insert → Add Comment Pin」をタップします。",
          "話題にしたい位置をタップすると、そこにピンが立ちスレッドが開きます。",
          "下の入力欄に書いて矢印を押すと投稿されます。",
          "内容が隠れるときは、左端の「≡」ハンドルをつかんでダイアログを移動します。",
          "「−」でタイトルバーだけに縮小（縮小後もドラッグ可）、「✕」で閉じます。",
          "解決したら「解決済み」を押すと、ピンがグレーのチェックに変わります。"
        ],
        "tip": "ピンは書き出しや同期でもノートと一緒に移動し、共同編集中は全員が同じピンを見ます。",
        "fig": "comment",
        "cap": "コメントスレッド：ドラッグハンドル、解決、削除、縮小、閉じる",
        "fig2": "pin_min",
        "cap2": "タイトルバーに縮小した状態 —— そのままドラッグできます"
      },
      {
        "id": "collab",
        "title": "リアルタイム共同編集（手順つき）",
        "lead": "複数人で同時に書けます。クラウドサーバーはありません —— 中継は常にあなたが管理するものです。状況は2つ：全員が同じネットワークにいる場合と、別々のネットワークにいる場合。どちらでも使えます。違うのは設定の1行だけです。",
        "buttons": [
          "共同編集",
          "共同編集を開始",
          "暗号化招待リンクをコピー",
          "ルームに参加",
          "中継サーバーアドレス",
          "共同編集を終了"
        ],
        "steps": [
          "**まずどちらの状況か決めます。** 同じオフィス・同じ Wi-Fi なら「ケースA」。自宅・職場・海外などに分かれているなら「ケースB」。",
          "── **ケースA：全員が同じネットワーク** ──",
          "**A1 — 誰か1人がホストになります。** 対象のノートを開き、上部の「共同編集」→「共同編集を開始」。",
          "**A2 — ホストの画面に3つ表示されます。** ルームID（例：kairumo-a1b2c3）、緑の「エンドツーエンド暗号化」、そして「この端末が中継中　ws://192.168.x.x:9002」の行。3つめは参加者が使うので閉じないでください。",
          "**A3 — 参加者はまず中継アドレスを設定します。** 任意のノート →「共同編集」→ 下部の「中継サーバーアドレス」を開き、ws://127.0.0.1:9002 を**ホスト画面のアドレス**に置き換えます。127.0.0.1 は「自分自身」の意味で、変えないと自分に接続してしまいます。",
          "── **ケースB：同じネットワークではない** ──",
          "**共同編集は1つのネットワークに縛られていません。** 必要なのは双方から到達できる中継アドレスだけで、それは **wss://**（TLS）でなければなりません。ルームIDと参加者は平文で流れるため、公開インターネット上では ws:// を受け付けません。方法は3つ、簡単な順に：",
          "**B-1 — 仮想プライベートネットワーク（最も手軽、構築不要）。** 全端末に Tailscale（または ZeroTier）を入れ同じアカウントでログインすると、同一ネットワーク上にいるかのように扱われます。ホストの Tailscale アドレスを共有し、全員が ws://100.x.y.z:9002 と入力するだけ。私有アドレス帯なので TLS は不要です。",
          "**B-2 — ホスト端末の中継をトンネルで外に出す（サーバーもアカウントも不要）。** ホストのパソコンで cloudflared tunnel --url http://localhost:9002 を実行すると https://xxxx.trycloudflare.com が表示されます。参加者は「中継サーバーアドレス」に wss://xxxx.trycloudflare.com と入力（https を wss に置換）。ターミナルを閉じればトンネルは終了します。",
          "**B-3 — 自分で立てる（継続利用向け）。** 公開アドレスを持つ任意のマシンで padnote-relay を実行し（HOST=0.0.0.0 PORT=9002）、前段に Caddy か nginx を置いて TLS を終端、全員が wss://relay.あなたのドメイン を入力します。手順はプロジェクトの docs/relay-hosting.md に。",
          "── **ここからは両方とも同じ** ──",
          "**手順1 — ホストが「暗号化招待リンクをコピー」を押し、共有します。** 形式：kairumo://collab?room=kairumo-a1b2c3#key=…",
          "⚠️ **ルームIDだけでは足りません。** # の後ろが復号鍵です。IDだけで参加した人は接続でき参加者一覧も見えますが、**ほかの人の内容を一切復号できず**画面には何も出ません（その場合オレンジの警告が出ます）。必ずリンク全体を送ってください。",
          "**手順2 — リンクを貼って参加します。** 「ルームに参加」に招待リンク全体を貼り、参加を押します。",
          "**手順3 — 接続を確認します。** 両端末の「参加者」に互いの名前が出て、ホスト側に「ホスト（オーナー）」と表示されれば成功です。",
          "**手順4 — 書き始めます。** どちらの筆跡・テキストボックス・表・図形・コメントピンも相手の画面にリアルタイムで現れます。",
          "**手順5 — 終了。** ホストが「共同編集を終了」でルームを閉じます。参加者の「切断」は自分だけ退出します。"
        ],
        "tip": "端末の種類による違いはありません。すべての端末が同じルームID、同じ鍵、同じ中継プロトコルを使い、どれでもホストになれます。内容は AES-256-GCM でエンドツーエンド暗号化され、中継は読めない暗号文を転送するだけ —— 第三者のトンネルサービスを使ってもノートの中身は見られません。オフライン中の編集は保留され、再接続時に自動送信されます。",
        "fig": "collab",
        "cap": "未接続：共同編集を開始、ルームに参加、中継サーバーのアドレス",
        "fig2": "collab_on",
        "cap2": "接続中：ルームID、暗号化、この端末が中継、参加者一覧"
      },
      {
        "id": "record",
        "title": "録音と文字起こし",
        "lead": "音声と手書きは同じタイムライン上にあります。単語をタップすれば、その瞬間の筆跡へ移動します。",
        "buttons": [
          "録音開始",
          "録音を一時停止",
          "録音を再開",
          "録音を完了",
          "最近の録音と文字起こし",
          "音声を文字起こし",
          "音声・手書き同期"
        ],
        "steps": [
          "ホームの「録音開始」、またはノート上部のマイクをタップします。",
          "初回はマイクの許可を求められます。許可してください。",
          "録音中は上部に波形が表示され、書いた内容が音声と同期します。",
          "いったん止めたいときは「録音を一時停止」。続けるときは「録音を再開」。保存して終えるときに「録音を完了」を押します。",
          "停止すると、ホームの「最近の録音と文字起こし」に追加されます。",
          "再生中に文字起こしの一行をタップすると、その時間に書いた筆跡へ移動します（逆方向も可能）。",
          "録音をページに置くには、ノート内で「その他 → 録音を挿入」、またはホームの録音行で「⋯ → ノートに挿入」を選びます。",
          "ページ上の録音カードを選択し、左上の「音声を文字起こし」を押すと、Kairumo が音声をテキストボックスにしてカードの下に置きます。",
          "「音声・手書き同期」カラオケ再生に対応：録音の再生中、その瞬間に書かれた筆跡が音声に合わせて光ります。キャンバス上の手書きを直接タップすれば、その筆跡を書いた正確な再生位置へ即座にスキップします。"
        ],
        "tip": "録音も文字起こしも、この端末の中で完結します。アップロードはありません。文字起こしには端末内で動くエンジンが必要で、**すべての端末にあるわけではありません** —— ない場合でも録音は使えますが、録音一覧に文字起こしは出ず、録音カードからテキストボックスを作れないことがあります。",
        "fig": "home",
        "cap": "ホームの「録音開始」と「最近の録音と文字起こし」"
      },
      {
        "id": "export",
        "title": "書き出し・印刷・共有",
        "lead": "用途に合わせて4つの出力から選べます。",
        "buttons": [
          "書き出しと印刷",
          "PDF を書き出す",
          "画像として書き出し",
          "ノートを印刷",
          "ノートを共有"
        ],
        "steps": [
          "右上の「書き出しと印刷」をタップします。",
          "「PDF を書き出す」はノート全体を PDF にします。",
          "「画像として書き出し」は現在のページを画像として保存します。",
          "「ノートを印刷」はシステムの印刷画面に渡します。",
          "「ノートを共有」は .padnote の原本を送ります。相手は Kairumo で編集を続けられます。"
        ],
        "tip": "PDF 内の注釈座標は原本と一致するため、他のアプリで開いてもずれません。",
        "fig": "export",
        "cap": "書き出しメニュー：PDF、画像、印刷、ノートを共有"
      },
      {
        "id": "keys",
        "title": "キーボードショートカット",
        "lead": "外付けキーボードをつないでいるとき、よく使う操作にはショートカットがあります。",
        "buttons": [],
        "steps": [
          "以下の「⌘」は、Command キーのあるキーボードでは Command、それ以外では **Ctrl** を押してください。",
          "**⇧⌘N**：新規ノート。Shift を足すのが重要です。Shift なしの ⌘N はシステムの「新規ウインドウ」で、ぶつかると両方とも効かなくなります。",
          "**⌘F**：ホーム画面の検索欄にカーソルを移します。",
          "**⌘E**：手書きモードと入力モードを切り替えます。",
          "**⌘1** から：ツールバーの並び順でブラシやツールを選びます。ツールの数より大きい数字は何もしません。"
        ],
        "tip": "カーソルがテキストボックスの中にあるときは、⌘A・⌘C・⌘V は従来どおり全選択・コピー・ペーストです。これらのショートカットが奪うことはありません。",
        "fig": null
      },
      {
        "id": "multi",
        "title": "並べて表示とドラッグ＆ドロップ",
        "lead": "Kairumo を別のアプリと並べると、画像をキャンバスへ直接ドラッグできます。",
        "buttons": [],
        "steps": [
          "タブレットやデスクトップでは、システムの分割表示で Kairumo と写真（またはファイル、ブラウザ）を並べます。",
          "反対側の画像を長押しして Kairumo のキャンバスへドラッグします。点線の枠が現れたら離して大丈夫です。",
          "離すと、画像は手を離した位置に配置され、比率を保ったままページに収まる大きさへ自動で縮小されます。",
          "端の近くで離しても内側へ寄せられます。半分がページ外にはみ出すことはありません（はみ出した部分は書き出しや印刷で切り落とされます）。",
          "配置されると入力モードに切り替わるので、そのまま移動やサイズ変更ができます。",
          "並べるとウインドウが狭くなりますが、ツールバーは折り返して表示され、ボタンが見えなくなることはありません。"
        ],
        "tip": "ドラッグして入れた画像は「画像を挿入」で入れたものとまったく同じです。サイズ変更・回転・角丸・枠線もそのまま使えます。",
        "fig": null
      },
      {
        "id": "language",
        "title": "言語と表示名",
        "lead": "6言語に対応し、その場で切り替わります。",
        "buttons": [
          "表示言語",
          "表示名を編集"
        ],
        "steps": [
          "ホーム画面の右上にある「表示言語」をタップします。地球のアイコンの隣に文字が出ています。",
          "繁體中文・English・简体中文・日本語・한국어・ไทย から選びます。",
          "再起動なしで表示が切り替わります。",
          "ホームの「表示名を編集」で、共同編集中に表示される名前と色を変更できます。"
        ],
        "tip": "表示名はこの端末にのみ保存され、送信されることはありません。",
        "fig": "language",
        "cap": "言語メニュー：6言語を即時切り替え"
      },
      {
        "id": "faq",
        "title": "困ったときは",
        "lead": "まずここを確認してください。",
        "buttons": [],
        "faq": [
          [
            "入力モードでペンが描けないのはなぜですか",
            "意図的な動作です。入力モードは文字とオブジェクト専用で、指もスタイラスも線を描きません。そのため選択やドラッグのたびに余計な筆跡が残りません。現在のモードはキャンバス右上のバッジに表示されます。書くときは手書きモードに戻してください。"
          ],
          [
            "共同編集に接続できない",
            "両方の端末が同じ Wi-Fi にあるか確認します。参加側の「中継サーバーアドレス」には、ホスト画面に表示された ws://…:9002 を入力します（既定の 127.0.0.1 ではありません）。初回接続時、システムがローカルネットワークの許可を求めるので許可してください。"
          ],
          [
            "ノートが消えることは？",
            "書いたそばからローカルファイルに保存されます。同期ファイルは追記のみで、各端末は自分のファイルしか書かないため上書きは起こりません。"
          ],
          [
            "アカウントは必要？",
            "不要です。Kairumo にはアカウントもバックエンドサーバーもありません。"
          ],
          [
            "手書きを文字にできますか？",
            "できます。端末内蔵の認識機能を使うため、筆跡が外部に出ることはありません。"
          ],
          [
            "不具合はどう報告しますか？",
            "デスクトップ版のウインドウタイトルに表示されるバージョン（例：Kairumo v4.8.0）と、操作手順を添えてください。"
          ],
          [
            "1 冊のノートでページ規格を混ぜられますか？",
            "できます。「ページ」のサムネイルを右クリックまたは長押し →「テンプレートを選んでページを挿入」→ テーマとテンプレートを選びます。その新しいページだけがそのレイアウトになり、ほかのページは変わりません。ノート作成時に選んだものは**既定値**にすぎません。"
          ],
          [
            "枠の外に書くとどうなりますか？",
            "破線の枠は印刷可能範囲であり、編集領域でもあります。完全に枠外に書かれたストロークは取り消され、通知が出ます。印刷も書き出しもできないので、残しておくと「まだある」と思わせてしまうからです。枠にまたがるストロークは残りますが、一度だけ知らせます。"
          ]
        ],
        "fig": null
      }
    ]
  },
  "ko": {
    "name": "한국어",
    "figset": "en",
    "ui": {
      "docTitle": "Kairumo 사용 설명서",
      "tagline": "손글씨·타이핑·녹음을 하나로 묶은 노트. 처음이어도 순서대로 따라 하면 됩니다.",
      "version": "대상 버전 v4.8.0 (build 58) · 2026년 9월 19일",
      "tocTitle": "목차",
      "tocHint": "항목을 누르면 해당 섹션으로 이동합니다",
      "stepsLabel": "따라 하기",
      "tipLabel": "알아두기",
      "buttonsLabel": "사용하는 버튼",
      "figNote": "스크린샷은 영어 화면입니다",
      "backToTop": "목차로",
      "langLabel": "언어",
      "privacyLink": "개인정보 처리방침"
    },
    "sections": [
      {
        "id": "start",
        "title": "시작하기 전에",
        "lead": "Kairumo는 손글씨·타이핑·녹음을 하나의 타임라인에 올려 두는 노트입니다. 무료이며 오픈 소스이고, 데이터는 기기에 남습니다.",
        "buttons": [],
        "steps": [
          "태블릿, 스마트폰, 데스크톱에서 사용할 수 있습니다. 스타일러스가 가장 자연스럽지만 손가락이나 마우스로도 됩니다.",
          "계정 가입도, 인터넷 연결도 필요 없습니다.",
          "처음 실행하면 샘플 노트 두 권(“Kairumo에 오신 것을 환영합니다”, “수업·회의 기록”)이 들어 있습니다. 바로 고칠 수 있는 글·표·차트·도형 예시입니다. 필요 없으면 지우세요.",
          "작성한 내용은 이 기기에 저장됩니다. 여러 기기에서 동기화하려면 본인 클라우드의 폴더를 지정하세요(「백업 및 동기화」 참고).",
          "데스크톱에서는 창 제목에 버전(예: Kairumo v4.8.0)이 표시됩니다. 문제를 알릴 때 함께 적어 주세요."
        ],
        "tip": "서버도 계정도 없으므로 비밀번호를 잊을 일이 없습니다. 대신 클라우드 사본도 없으니 백업은 직접 해 두세요.",
        "fig": null
      },
      {
        "id": "firstrun",
        "title": "처음 열었을 때",
        "lead": "첫 실행에서 어떤 권한이 왜 필요한지 한 페이지로 설명합니다. 확인하면 홈으로 넘어가며 다시 나타나지 않습니다.",
        "buttons": [
          "마이크 허용",
          "나중에",
          "시작하기"
        ],
        "steps": [
          "이 페이지는 세 가지를 설명합니다. Kairumo가 무엇인지, 계정도 저희 서버도 필요 없다는 점, 그리고 사용할 수 있는 단 하나의 권한입니다.",
          "권한은 **마이크** 하나뿐이며 녹음할 때만 사용합니다. 허용하지 않아도 손글씨·입력·내보내기·동기화는 모두 그대로 동작합니다.",
          "「마이크 허용」을 눌러야 시스템 권한 대화상자가 나타납니다. 이 대화상자는 **앱당 평생 한 번만** 표시됩니다.",
          "그때 거부하면 버튼이 「설정 열기」로 바뀝니다. 이후에는 시스템 설정에서만 켤 수 있으며 앱이 다시 물어볼 수 없습니다.",
          "「시작하기」를 누르면 홈으로 이동합니다. 이 페이지는 다시 나오지 않습니다."
        ],
        "tip": "권한은 설치 시점에 요청되지 않습니다. 시스템은 기능이 실제로 필요할 때만 묻습니다. 허용하지 않은 채 녹음을 시작하면 바로 그 시점에 다시 안내합니다.",
        "fig": null
      },
      {
        "id": "home",
        "title": "홈: 작업대",
        "lead": "앱을 열면 처음 보이는 화면입니다. 노트·녹음·에셋·가져온 파일이 모두 여기에서 시작됩니다.",
        "buttons": [
          "표시 정보 편집",
          "새 노트",
          "녹음 시작",
          "에셋 라이브러리",
          "노트 가져오기"
        ],
        "steps": [
          "맨 위는 표시 이름입니다. 협업 중 상대에게 보이는 이름이며 “표시 정보 편집”에서 바꿀 수 있습니다.",
          "검색창은 노트 제목, 입력한 글자, 녹음 전사 결과를 함께 찾습니다.",
          "가운데 큰 카드 네 개가 주요 동작입니다: 새 노트, 녹음 시작, 에셋 라이브러리, 노트 가져오기.",
          "“노트 가져오기”로 .padnote 파일을 골라 공유받은 원본 노트를 라이브러리에 추가합니다.",
          "“이어서”에는 최근 연 노트가 있고, 누르면 이어서 작업합니다.",
          "“모든 노트”는 폴더별 목록이며, 오른쪽에서 정렬 방식을 바꿉니다.",
          "홈 화면을 맨 아래로 내리면 “사용 설명서”와 “개인정보 처리방침” 카드가 있습니다. 지금 보고 있는 것이 전자입니다.",
          "홈 녹음 목록의 각 행 “⋯” 메뉴에 “노트에 삽입”이 있습니다. 노트와 페이지를 골라 그 녹음을 놓을 수 있습니다."
        ],
        "tip": "각 노트 카드 오른쪽 위 “⋯”에 이름 변경·폴더로 이동·삭제가 있습니다.",
        "fig": "home",
        "cap": "홈: 표시 이름, 검색, 주요 동작 4개, Continue, All Notebooks"
      },
      {
        "id": "newnote",
        "title": "첫 노트 만들기",
        "lead": "일곱 그룹, 서른세 가지 페이지 템플릿. 안내선 색도 직접 고릅니다.",
        "buttons": [
          "새 노트",
          "페이지 템플릿",
          "안내선 색",
          "확인"
        ],
        "steps": [
          "홈에서 ‘새 노트’를 누릅니다.",
          "‘노트 제목’에 이름을 입력합니다. 비워 두고 나중에 바꿔도 됩니다.",
          "‘페이지 템플릿’ 윗줄은 테마 칩입니다. 일곱 개가 줄바꿈되어 한 번에 모두 보이므로 옆으로 밀 필요가 없습니다: 일반, 노트 기법, 계획·일정, 목록·기록, 시각 디자인, 엔지니어링, 디지털.",
          "테마를 누르면 아래 목록이 그 그룹으로 바뀝니다. 항목마다 어떤 용도인지 한 줄로 적혀 있습니다.",
          "‘노트 기법’은 구조가 있는 방식입니다: 코넬(단서/노트/요약), 4분면(요점/질문/결정/실행), 아웃라인(3단 들여쓰기), 2단 대조, 질문과 답, K-W-L, 마인드맵.",
          "‘계획·일정’과 ‘목록·기록’에는 월간, 주간, 하루 일정, 24시간 타임라인, 학습 플래너, 프로젝트 일정, 할 일 목록, 체크리스트, 습관 기록, 과제 추적, 집안일 분담표, 21일 챌린지가 있습니다.",
          "맨 아래 ‘안내선 색’은 여섯 가지입니다: 그래파이트, 인디고, 틸, 로즈, 앰버, 포레스트. 선과 머리글 띠, 항목 이름이 모두 고른 색을 따릅니다.",
          "오른쪽 위 ‘확인’을 누르면 노트가 바로 열립니다."
        ],
        "tip": "템플릿은 배치일 뿐이라 바꿔도 이미 쓴 내용은 그대로입니다. 그리고 노트 안에서는 **페이지마다 다른 템플릿을 쓸 수 있습니다**(‘페이지와 폴더’ 참고). 안내선 색은 노트 전체에 하나이며 편집 화면 위쪽에서 언제든 바꿀 수 있습니다.",
        "fig": "newnote",
        "cap": "새 노트: 제목, 테마 칩, 템플릿 목록, 안내선 색"
      },
      {
        "id": "editor",
        "title": "편집 화면 살펴보기",
        "lead": "위치를 한 번 익혀 두면 이후가 편합니다.",
        "buttons": [
          "홈",
          "노트 구조",
          "손글씨",
          "타이핑"
        ],
        "steps": [
          "맨 윗줄은 왼쪽부터: 홈, 노트 구조, 손글씨/타이핑 전환, 제목, 페이지 번호, 자, 에셋 라이브러리, 삽입, 댓글 핀, 협업, 녹음, 내보내기·인쇄.",
          "둘째 줄은 현재 모드의 도구 모음입니다(손글씨는 펜과 색, 타이핑은 문자 서식).",
          "캔버스 오른쪽 위에 모드 배지가 있습니다. 지금이 필기인지 입력인지, 그 모드에서 펜이 그려지는지, 객체를 옮길 수 있는지 알려 줍니다.",
          "왼쪽은 구조 패널이며 페이지 목록과 폴더 목록을 전환합니다.",
          "가운데가 캔버스입니다. 페이지 높이는 고정이며, 아래까지 쓰면 다음 페이지가 자동으로 준비됩니다. 오른쪽 아래 “다음 페이지 추가”로 직접 추가할 수도 있습니다.",
          "창이 좁아지면 도구 모음이 자동으로 줄바꿈되어 버튼이 화면 밖으로 밀리지 않습니다.",
          "위쪽 막대 오른쪽에 작은 버튼이 두 개 있습니다: **페이지 규격**(A4 세로/가로, A5, 레터, 리걸, 16:9 슬라이드, 정사각형)과 **안내선 색**(여섯 가지). 규격을 바꾸면 캔버스, 쪽 나눔, 내보내기 크기가 함께 바뀝니다. 색은 안내선과 머리글에만 적용됩니다.",
          "더 작은 규격으로 바꾸면 새 페이지 밖으로 나가는 요소는 자동으로 안쪽으로 들어옵니다. 그러지 않으면 화면에는 보이지만 인쇄하면 사라집니다.",
          "페이지의 점선 사각형은 **인쇄 가능 영역**이자 편집 영역입니다. 완전히 바깥에 그린 획은 되돌려지고 이유를 알려 줍니다. 경계에 걸친 획은 남기되 한 번 알려 줍니다.",
          "캔버스의 바로가기를 길게 누르거나 탭하면 “원형 마크 메뉴”가 나타나며, 8개 방향으로 가볍게 밀어 주요 도구(펜, 지우개, 올가미, 실행 취소, 다시 실행, 고급 색상 조색, 손떨림 보정)를 화면 상단으로 손을 뻗지 않고도 전환할 수 있습니다."
        ],
        "tip": "폭이 부족하면 “노트 구조”로 왼쪽 열을 접으세요. 캔버스가 바로 넓어집니다.",
        "fig": "editor",
        "cap": "편집 화면: 상단 바, 손글씨 도구 모음, 구조 패널, 캔버스"
      },
      {
        "id": "write",
        "title": "손글씨",
        "lead": "펜 7종, 굵기 4단계, 원하는 색. 지우거나, 올가미로 묶어 통째로 옮길 수 있습니다.",
        "buttons": [
          "만년필",
          "지우개",
          "올가미",
          "선 굵기",
          "자석 스냅 및 눈금자",
          "고급 색상 조색"
        ],
        "steps": [
          "상단이 손글씨 모드인지 확인합니다.",
          "펜을 고릅니다: 만년필, 볼펜, 붓, 마커, 형광펜, 연필, 수채.",
          "가운데 점 네 개가 굵기, 오른쪽이 색입니다. 슬라이더 아이콘으로 색을 직접 만들 수 있습니다.",
          "잘못 쓴 부분은 지우개로 지웁니다. 한 덩어리를 옮기거나 복사하려면 올가미로 감싸세요.",
          "오른쪽 끝에 실행 취소·다시 실행·페이지 지우기가 있습니다.",
          "페이지 아래쪽까지 쓰면 다음 페이지가 자동으로 추가됩니다.",
          "지원되는 스타일러스라면 지우려고 도구 모음으로 돌아갈 필요가 없습니다. **펜대를 두 번 두드리는** 방식, **펜대의 측면 버튼을 누르고 있는** 방식, **뒤집으면** 지우개가 되는 방식이 있습니다. 다시 두드리거나 버튼을 놓으면 쓰던 펜으로 돌아옵니다. 두 번 두드렸을 때의 동작은 시스템 설정을 따릅니다.",
          "직선이나 도형 윤곽을 그릴 때 “자석 스냅 및 눈금자”를 켜면 펜 끝이 0°, 45°, 90°, 135°, 180° 등의 표준 각도나 격자에 자동으로 달라붙으며 청록색 레이저 가이드선과 햅틱 피드백이 표시됩니다.",
          "도구 모음에서 4단계 “손떨림 보정”으로 손떨림을 깔끔하게 잡아줄 수 있습니다. “고급 색상 조색”을 열면 보색 및 삼각 조화 등 색채 조화가 지원되는 원형 색상환으로 색을 고를 수 있습니다.",
          "“캔버스 미니멀 모드”: 도구 모음의 접기 버튼을 누르면 화면 구석의 단일 플로팅 캡슐(Floating Tool Pill)로 접혀 방해 없는 전체 화면 필기를 즐길 수 있습니다. 언제든지 복구하려면 상단 탐색 표시줄에 상주하는 강조된 “캔버스 미니멀 모드 종료” 버튼을 클릭하거나 플로팅 버블을 탭하여 미니 도구 상자를 펼치거나 물리 키보드의 Esc 키를 누르면 전체 도구 모음이 즉시 다시 열립니다."
        ],
        "tip": "스타일러스로 쓸 때 손바닥을 화면에 올려도 됩니다. 팜 리젝션이 손바닥을 무시하고 펜 끝만 인식합니다. 필기 모드에서는 캔버스의 객체가 잠겨 있어 실수로 끌리지 않습니다. 옮기거나 고치려면 입력 모드로 바꾸세요.",
        "fig": "editor",
        "cap": "손글씨 도구 모음: 펜, 굵기, 색, 페이지 늘리기, 더 보기"
      },
      {
        "id": "type",
        "title": "타이핑",
        "lead": "캔버스 어디에나 텍스트 상자를 놓고 손글씨와 섞어 쓸 수 있습니다.",
        "buttons": [
          "타이핑",
          "텍스트 서식",
          "특수 기호",
          "링크 삽입",
          "텍스트에 고정"
        ],
        "steps": [
          "상단의 키보드 아이콘으로 타이핑 모드로 전환합니다.",
          "캔버스의 빈 곳을 **두 번 누르면** 그 자리에 텍스트 상자가 생기고 키보드가 열립니다. (한 번 누르기는 스크롤과 객체 선택에 쓰기 때문에 두 번입니다.)",
          "“텍스트 서식”에서 크기·굵게·기울임·밑줄·정렬·색을 정합니다.",
          "“특수 기호”는 수식과 기호를, “링크 삽입”는 붙여넣은 주소를 미리보기 카드로 만듭니다.",
          "텍스트 상자는 끌어서 옮기고, 오른쪽 아래 손잡이로 크기를 바꿉니다.",
          "“범위 선택”으로 상자를 끌면 여러 객체를 한 번에 고를 수 있습니다. 이후 함께 옮기고 복사·붙여넣기·복제·삭제할 수 있습니다. 선택 영역 안을 끌면 전체가 움직입니다.",
          "“동적 플로우 고정”: 텍스트 상자나 주변 필기를 선택하고 “텍스트에 고정”을 누르면 손글씨 메모가 텍스트에 단단히 고정됩니다. 텍스트 상자를 이동하거나 내용을 수정하여 줄바꿈이 바뀌어도 필기가 자동으로 따라 움직여 어긋나지 않습니다."
        ],
        "tip": "타이핑 모드에서는 **펜으로도 그려지지 않습니다**. 이 모드는 글과 객체만 다룹니다. 쓰려면 필기 모드로 돌아가세요. 삽입한 링크 카드를 선택하면 왼쪽 아래 연필로 주소·제목·설명을 고칠 수 있습니다.",
        "fig": "typing",
        "cap": "타이핑 도구 모음: Text Studio, 기호, 링크 삽입, 더 보기, 페이지 늘리기"
      },
      {
        "id": "pages",
        "title": "페이지와 폴더",
        "lead": "한 노트에 여러 페이지, 페이지마다 다른 템플릿. 노트는 폴더로 정리합니다.",
        "buttons": [
          "노트 구조",
          "페이지",
          "폴더",
          "페이지 선택"
        ],
        "steps": [
          "위쪽 ‘노트 구조’로 왼쪽 열을 열고 닫습니다.",
          "‘페이지’에는 이 노트의 페이지 미리보기가 나옵니다. 누르면 그 페이지로 이동합니다.",
          "**미리보기에서 오른쪽 클릭하거나 길게 누르면** 메뉴가 열립니다. 각 페이지 오른쪽 위 ‘⋯’와 내용이 똑같으니 편한 쪽을 쓰면 됩니다.",
          "메뉴 항목: 뒤에 페이지 삽입, 템플릿을 골라 페이지 삽입, 이 페이지 복제, 다른 노트로 복사, 다른 노트로 이동, 페이지 위로/아래로, 맨 앞으로/맨 뒤로, 페이지 삭제.",
          "**템플릿을 골라 페이지 삽입**: 테마를 고르고 템플릿을 고르면 이 페이지 바로 뒤에 새 페이지가 들어갑니다. 한 노트 안에 4분면 페이지와 하루 일정 페이지를 함께 둘 수 있습니다.",
          "**순서 바꾸기**는 두 가지입니다: 메뉴의 위로/아래로/맨 앞/맨 뒤, 또는 미리보기를 직접 끌어다 놓기(놓일 자리에 선이 보입니다).",
          "**페이지를 다른 노트로 옮기기**: 사이드바 머리글의 체크 버튼으로 선택 모드에 들어가 원하는 페이지를 고르고(‘전체 선택’도 있습니다), 아래의 ‘복사 위치…’ 또는 ‘이동 위치…’를 누른 뒤 대상 노트를 고릅니다.",
          "사이드바 아래의 ‘−/＋’로 미리보기 크기를 바꿉니다. 사이드바보다 크게 하면 사이드바가 따라서 넓어집니다.",
          "사이드바와 캔버스 사이의 **경계선은 좌우로 끌 수 있습니다**. 사이드바 안의 글자도 함께 커집니다. 두 번 누르면 기본 너비로 돌아갑니다.",
          "‘폴더’로 바꾸면 모든 폴더와 노트가 보입니다. 하위 폴더 추가, 이름 변경, 노트 이동이 가능합니다.",
          "**노트를 폴더에 넣으려면** 노트를 폴더 줄로 끌어다 놓습니다. **꺼내려면** 맨 위 루트 줄이나 ‘미분류’ 구역으로 끌어다 놓습니다(비어 있어도 항상 보이며 안내 한 줄이 나옵니다). 끌기가 번거로우면 노트 오른쪽 ‘⋯’에도 ‘폴더에서 꺼내기’가 있습니다.",
          "폴더 목록에서 다른 노트를 누르면 같은 창에서 바로 전환됩니다. 홈으로 돌아갈 필요가 없습니다."
        ],
        "tip": "노트에는 최소 한 페이지가 있어야 하므로 전부 선택하면 ‘이동 위치…’는 꺼집니다(‘복사 위치…’는 그대로 씁니다). 복사한 페이지는 표·도형·텍스트 상자까지 함께 옮겨지고 새 식별자를 받으므로, 한쪽을 고쳐도 다른 쪽은 그대로입니다.",
        "fig": "folders",
        "cap": "폴더 탭: 루트 폴더, 하위 폴더, 노트 목록"
      },
      {
        "id": "insert",
        "title": "이미지·에셋·차트 넣기",
        "lead": "사진, 실물 규격 에셋, 수식, 차트, 3D 모델을 캔버스에 놓을 수 있습니다.",
        "buttons": [
          "삽입",
          "이미지 삽입",
          "에셋 라이브러리",
          "수식 계산"
        ],
        "steps": [
          "상단 “삽입”를 누릅니다. 창이 좁으면 “⋯” 메뉴 안에 들어갑니다.",
          "“이미지 삽입”로 사진을 고릅니다. 배치 후 이동·크기 조절·모서리 둥글게·테두리가 가능합니다.",
          "“에셋 라이브러리”에는 기계, 전자, 차량, 가구 등 실물 규격 에셋이 있어 내려받아 배치합니다.",
          "“수식 계산”와 “데이터 차트”는 수식이나 차트를 카드로 만들어 페이지에 놓습니다.",
          "“3D 모델 삽입”은 360° 회전하는 모델을 배치합니다.",
          "“녹음 삽입”은 기존 녹음을 이 페이지에 재생 가능한 카드로 놓습니다. 옮기고 크기를 바꾸고 이름을 고치고 지울 수 있습니다.",
          "사진은 **다른 앱에서 바로 끌어다 놓을** 수도 있습니다. 두 앱을 나란히 두고 캔버스에 놓기만 하면 됩니다. 「나란히 보기와 끌어다 놓기」를 참고하세요."
        ],
        "tip": "에셋 파일은 기기에 저장됩니다. 라이브러리에서 지우면 용량이 확보되며, 이미 배치한 에셋은 그대로 남습니다.",
        "fig": "insertmenu",
        "cap": "삽입 메뉴: 에셋 라이브러리, 이미지, 수식, 3D 모델, 댓글 핀, 협업",
        "fig2": "assetlib",
        "cap2": "에셋 라이브러리: 분류에서 찾아 내려받고 배치"
      },
      {
        "id": "data",
        "title": "백업 및 동기화",
        "lead": "계정도, 저희 서버도 필요 없습니다. 백업은 파일 하나, 동기화는 본인의 클라우드 폴더입니다.",
        "buttons": [
          "백업 만들기",
          "백업에서 복원",
          "동기화 폴더 선택",
          "지금 동기화"
        ],
        "steps": [
          "홈 화면의 “데이터 및 동기화”에는 카드 네 개가 있습니다. 카드를 누르면 해당 기능의 설명과 작업 화면이 열립니다.",
          "“클라우드 동기화”는 로그인 상태를 보여 주며 로그인, 동기화 위치, 지금 동기화 동작을 엽니다.",
          "“백업 만들기”는 노트·이미지·녹음을 파일 하나로 묶어 원하는 위치에 저장합니다.",
          "“백업에서 복원”은 백업 파일을 골라 복원합니다. 복원 전 현재 데이터를 자동으로 백업하므로 잘못 골라도 되돌릴 수 있습니다.",
          "폴더 동기화: 본인 클라우드에 폴더(예: Kairumo)를 만들고 “동기화 폴더 선택”로 지정합니다.",
          "다른 기기에서도 같은 폴더를 지정합니다.",
          "양쪽에서 “지금 동기화”를 누릅니다. 한 기기에서 쓴 내용은 다른 기기가 동기화한 뒤 나타납니다.",
          "Kairumo는 “임시 파일 ＋ 물리 디스크 동기화(fsync) ＋ 원자적 교체”의 철저한 저장 방식을 사용하여, 노트를 나가거나 백그라운드로 전환할 때 즉시 저장됩니다. 배터리가 방전되더라도 파일 손상이나 필기 유실이 발생하지 않습니다.",
          "듀얼 트랙 동기화 및 실시간 차이 검증: 동기화가 시작되기 전 시스템이 로컬에 실제로 존재하는 전자노트와 클라우드 인덱스를 즉시 대조하여 삭제된 잔여 패키지를 자동으로 배제하고 정리합니다. 전경 고속 트랙이 현재 편집 중인 노트를 최우선 동기화하며 나머지는 백그라운드 병렬 큐에서 수렴합니다. 또한 클라우드 동기화 시트와 진단 패널에서 “원클릭 복사” 및 “로그 파일 내보내기” 기능을 제공하여 진단 로그를 간편하게 저장할 수 있습니다."
        ],
        "tip": "파일 이동은 이미 쓰고 계신 클라우드가 맡습니다. 저희는 네트워크를 건드리지 않고 데이터도 보관하지 않습니다. 그래서 “Kairumo 로그인”이 없습니다. 동기화는 파일을 추가만 하며 다른 기기의 내용을 덮어쓰지 않습니다.",
        "fig": null
      },
      {
        "id": "comment",
        "title": "댓글 핀",
        "lead": "캔버스의 특정 위치에 메모를 고정합니다. 혼자 쓰는 메모에도, 함께 하는 논의에도 좋습니다.",
        "buttons": [
          "댓글 핀 추가",
          "해결됨"
        ],
        "steps": [
          "“Insert → Add Comment Pin”을 누릅니다.",
          "이야기할 위치를 누르면 그 자리에 핀이 꽂히고 스레드가 열립니다.",
          "아래 입력란에 쓰고 화살표를 누르면 글이 등록됩니다.",
          "대화창이 내용을 가리면 왼쪽 “≡” 손잡이를 잡고 옆으로 옮기세요.",
          "“−”를 누르면 제목 줄만 남게 축소되고(축소 후에도 끌 수 있습니다), “✕”로 닫습니다.",
          "정리되면 “해결됨”를 눌러 핀을 회색 체크로 바꿉니다."
        ],
        "tip": "핀은 내보내기와 동기화 때 노트와 함께 이동하며, 협업 중에는 모두가 같은 핀을 봅니다.",
        "fig": "comment",
        "cap": "댓글 스레드: 끌기 손잡이, 해결, 삭제, 축소, 닫기",
        "fig2": "pin_min",
        "cap2": "제목 줄로 축소한 상태 —— 그대로 끌 수 있습니다"
      },
      {
        "id": "collab",
        "title": "실시간 협업 (단계별 안내)",
        "lead": "여러 사람이 동시에 필기합니다. 클라우드 서버는 없습니다 —— 중계는 언제나 여러분이 관리하는 기기입니다. 상황은 두 가지: 모두 같은 네트워크에 있거나, 서로 다른 네트워크에 흩어져 있거나. 둘 다 됩니다. 다른 것은 설정 한 줄뿐입니다.",
        "buttons": [
          "공동 편집",
          "공동 편집 시작",
          "암호화된 초대 링크 복사",
          "방 참가",
          "중계 서버 주소",
          "공동 편집 종료"
        ],
        "steps": [
          "**먼저 어느 상황인지 정하세요.** 같은 사무실, 같은 Wi-Fi → 사례 A. 집·회사·해외 등으로 흩어져 있다면 → 사례 B.",
          "── **사례 A: 모두 같은 네트워크** ──",
          "**A1 — 한 사람이 호스트가 됩니다.** 작업할 노트를 열고 상단 “공동 편집” → “공동 편집 시작”.",
          "**A2 — 호스트 화면에 세 가지가 나타납니다.** 룸 ID(예: kairumo-a1b2c3), 초록색 “종단 간 암호화”, 그리고 “이 기기에서 중계 중　ws://192.168.x.x:9002” 한 줄. 세 번째 줄은 곧 참여자가 쓰니 닫지 마세요.",
          "**A3 — 참여자는 먼저 중계 주소를 설정합니다.** 아무 노트 → “공동 편집” → 아래쪽 “중계 서버 주소”를 펼쳐 ws://127.0.0.1:9002 을 **호스트 화면의 주소**로 바꿉니다. 127.0.0.1 은 “이 기기 자신”이라는 뜻이라, 바꾸지 않으면 자기 자신에게 연결합니다.",
          "── **사례 B: 같은 네트워크가 아닐 때** ──",
          "**협업은 하나의 네트워크에 묶여 있지 않습니다.** 필요한 것은 양쪽이 닿을 수 있는 중계 주소 하나이며, 반드시 **wss://**(TLS)여야 합니다. 룸 ID와 참여자 목록은 평문으로 오가므로 공개 인터넷에서는 ws:// 를 받지 않습니다. 쉬운 순서로 세 가지:",
          "**B-1 — 가상 사설망(가장 간단, 직접 구축 불필요).** 모든 기기에 Tailscale(또는 ZeroTier)을 설치하고 같은 계정으로 로그인하면 한 네트워크에 있는 것처럼 동작합니다. 호스트가 자신의 Tailscale 주소를 알려 주면 모두 ws://100.x.y.z:9002 을 입력하면 됩니다. 사설 대역이라 TLS가 필요 없습니다.",
          "**B-2 — 호스트 기기의 중계를 터널로 외부에 노출(서버도 계정도 불필요).** 호스트 컴퓨터에서 cloudflared tunnel --url http://localhost:9002 을 실행하면 https://xxxx.trycloudflare.com 주소가 출력됩니다. 참여자는 “중계 서버 주소”에 wss://xxxx.trycloudflare.com 을 입력합니다(https 를 wss 로). 터미널을 닫으면 터널이 끝납니다.",
          "**B-3 — 직접 운영(상시 사용).** 공개 주소가 있는 아무 머신에서 padnote-relay 를 실행하고(HOST=0.0.0.0 PORT=9002) 앞단에 Caddy 나 nginx 로 TLS 를 두면, 모두 wss://relay.내도메인 을 입력합니다. 방법은 프로젝트의 docs/relay-hosting.md 참고.",
          "── **여기서부터는 두 경우가 같습니다** ──",
          "**1단계 — 호스트가 “암호화된 초대 링크 복사”를 눌러 전달합니다.** 형식: kairumo://collab?room=kairumo-a1b2c3#key=…",
          "⚠️ **룸 ID만으로는 부족합니다.** # 뒤가 복호화 키입니다. ID만으로 들어온 사람은 연결도 되고 참여자 목록도 보이지만 **다른 사람이 쓴 내용을 전혀 복호화하지 못해** 화면에 아무것도 나타나지 않습니다(이때 주황색 경고가 뜹니다). 반드시 링크 전체를 보내세요.",
          "**2단계 — 링크를 붙여 넣고 참여합니다.** “방 참가” 칸에 초대 링크 전체를 붙여 넣고 참가를 누릅니다.",
          "**3단계 — 연결을 확인합니다.** 두 기기 모두 “참여자”에 서로의 이름이 보이고 호스트 쪽에 “호스트(소유자)”가 표시되면 성공입니다.",
          "**4단계 — 함께 필기합니다.** 어느 기기의 필기·텍스트 상자·표·도형·코멘트 핀이든 상대 화면에 실시간으로 나타납니다.",
          "**5단계 — 종료.** 호스트가 “공동 편집 종료”를 누르면 방이 닫히고, 참여자의 “연결 해제”는 본인만 나갑니다."
        ],
        "tip": "기기 종류는 상관없습니다. 모든 기기가 같은 룸 ID, 같은 키, 같은 중계 프로토콜을 쓰며 어느 기기든 호스트가 될 수 있습니다. 내용은 AES-256-GCM 으로 종단 간 암호화되고 중계는 읽을 수 없는 암호문만 전달합니다 —— 타사 터널 서비스를 거쳐도 노트 내용은 볼 수 없습니다. 오프라인 중 편집은 대기했다가 연결이 돌아오면 자동 전송됩니다.",
        "fig": "collab",
        "cap": "연결 전: 협업 시작, 룸 참여, 중계 서버 주소",
        "fig2": "collab_on",
        "cap2": "연결됨: 룸 ID, 종단 간 암호화, 이 기기가 중계, 참여자"
      },
      {
        "id": "record",
        "title": "녹음과 전사",
        "lead": "소리와 필기가 같은 타임라인 위에 있습니다. 단어를 누르면 그때 쓴 획으로 이동합니다.",
        "buttons": [
          "녹음 시작",
          "녹음 일시정지",
          "녹음 재개",
          "녹음 완료",
          "최근 녹음 및 필사",
          "오디오 전사",
          "음성-필기 동기화"
        ],
        "steps": [
          "홈의 “녹음 시작” 또는 노트 상단의 마이크를 누릅니다.",
          "처음에는 마이크 권한을 묻습니다. 허용하세요.",
          "녹음 중에는 위쪽에 실시간 파형이 보이고, 쓰는 내용이 소리와 맞춰집니다.",
          "잠시 멈추려면 “녹음 일시정지”를 누릅니다. 이어서 녹음하려면 “녹음 재개”, 저장하고 끝내려면 “녹음 완료”를 누릅니다.",
          "중지하면 홈의 “최근 녹음 및 필사”에 추가됩니다.",
          "재생 중 전사된 줄을 누르면 그 시각에 쓴 필기로 이동합니다(반대 방향도 됩니다).",
          "녹음을 페이지에 놓으려면 노트에서 “더 보기 → 녹음 삽입”을 고르거나, 홈 녹음 행에서 “⋯ → 노트에 삽입”을 쓰세요.",
          "페이지의 녹음 카드를 선택하고 왼쪽 위 “오디오 전사”를 누르면 Kairumo가 소리를 텍스트 상자로 바꿔 카드 아래에 놓습니다.",
          "“음성-필기 동기화” 노래방 재생 지원: 녹음을 재생하면 그 순간 작성된 필기 획이 음성에 맞춰 빛나며 하이라이트됩니다. 캔버스의 필기를 직접 탭하면 해당 획을 작성했던 정확한 녹음 시점으로 즉시 이동합니다."
        ],
        "tip": "녹음과 전사 모두 이 기기 안에서 끝나며 업로드하지 않습니다. 전사에는 기기에서 동작하는 엔진이 필요하고 **모든 기기에 있는 것은 아닙니다** —— 없어도 녹음은 그대로 되지만 녹음 목록에 전사 텍스트가 없고, 녹음 카드가 텍스트 상자를 만들지 못할 수 있습니다.",
        "fig": "home",
        "cap": "홈의 “녹음 시작”과 “최근 녹음 및 필사”"
      },
      {
        "id": "export",
        "title": "내보내기·인쇄·공유",
        "lead": "상대가 필요로 하는 형식을 고르세요.",
        "buttons": [
          "내보내기 및 인쇄",
          "PDF 내보내기",
          "이미지로 내보내기",
          "노트 인쇄",
          "노트 공유"
        ],
        "steps": [
          "오른쪽 위 “내보내기 및 인쇄”를 누릅니다.",
          "“PDF 내보내기”는 노트 전체를 PDF로 만듭니다.",
          "“이미지로 내보내기”는 현재 페이지를 이미지 파일로 저장합니다.",
          "“노트 인쇄”은 시스템 인쇄 화면으로 넘깁니다.",
          "“노트 공유”는 .padnote 원본을 보냅니다. 상대는 Kairumo에서 이어서 편집할 수 있습니다."
        ],
        "tip": "PDF 안의 주석 좌표가 원본과 같아 다른 앱에서 열어도 위치가 틀어지지 않습니다.",
        "fig": "export",
        "cap": "내보내기 메뉴: PDF, 이미지, 인쇄, 노트 공유"
      },
      {
        "id": "keys",
        "title": "키보드 단축키",
        "lead": "물리 키보드를 연결하면 자주 쓰는 동작에 단축키가 있습니다.",
        "buttons": [],
        "steps": [
          "아래의 “⌘”는 Command 키가 있는 키보드에서는 Command, 그 외에는 **Ctrl**을 누르세요.",
          "**⇧⌘N** — 새 노트. Shift가 중요합니다. Shift 없는 ⌘N은 시스템의 “새 창”이며, 둘이 충돌하면 양쪽 모두 동작하지 않습니다.",
          "**⌘F** — 홈 화면의 검색창으로 커서를 옮깁니다.",
          "**⌘E** — 손글씨 모드와 입력 모드를 전환합니다.",
          "**⌘1**부터 — 도구 모음의 순서대로 브러시와 도구를 고릅니다. 도구 수보다 큰 숫자는 아무 일도 하지 않습니다."
        ],
        "tip": "커서가 텍스트 상자 안에 있을 때 ⌘A, ⌘C, ⌘V는 그대로 전체 선택·복사·붙여넣기입니다. 이 단축키들이 가로채지 않습니다.",
        "fig": null
      },
      {
        "id": "multi",
        "title": "나란히 보기와 끌어다 놓기",
        "lead": "Kairumo를 다른 앱과 나란히 두면 사진을 캔버스로 바로 끌어다 놓을 수 있습니다.",
        "buttons": [],
        "steps": [
          "태블릿이나 데스크톱에서 시스템의 화면 분할로 Kairumo와 사진 보관함(또는 파일, 브라우저)을 나란히 둡니다.",
          "반대쪽에서 사진을 길게 눌러 Kairumo 캔버스로 끕니다. 점선 테두리가 나타나면 놓아도 됩니다.",
          "놓으면 사진이 손을 뗀 자리에 들어가고, 비율을 유지한 채 페이지에 맞는 크기로 자동 축소됩니다.",
          "가장자리에 놓아도 안쪽으로 밀어 넣습니다. 절반이 페이지 밖으로 나가는 일은 없습니다(밖으로 나간 부분은 내보내기와 인쇄에서 잘립니다).",
          "들어온 뒤에는 입력 모드로 바뀌므로 곧바로 옮기고 크기를 조절할 수 있습니다.",
          "나란히 두면 창이 좁아지지만 도구 모음이 여러 줄로 접혀 버튼이 가려지지 않습니다."
        ],
        "tip": "끌어다 놓은 사진은 「사진 삽입」으로 넣은 것과 완전히 같습니다. 크기 조절, 회전, 둥근 모서리, 테두리 모두 그대로 쓸 수 있습니다.",
        "fig": null
      },
      {
        "id": "language",
        "title": "언어와 표시 이름",
        "lead": "여섯 가지 언어를 즉시 전환합니다.",
        "buttons": [
          "인터페이스 언어",
          "표시 정보 편집"
        ],
        "steps": [
          "홈 화면 오른쪽 위의 「인터페이스 언어」를 누릅니다. 지구본 아이콘 옆에 글자가 있습니다.",
          "繁體中文, English, 简体中文, 日本語, 한국어, ไทย 중에서 고릅니다.",
          "다시 시작하지 않아도 화면이 바로 바뀝니다.",
          "홈의 “표시 정보 편집”에서 협업 중 보이는 이름과 색을 바꿀 수 있습니다."
        ],
        "tip": "표시 이름은 이 기기에만 저장되며 전송되지 않습니다.",
        "fig": "language",
        "cap": "언어 메뉴: 여섯 언어 즉시 전환"
      },
      {
        "id": "faq",
        "title": "문제 해결",
        "lead": "먼저 여기를 확인하세요.",
        "buttons": [],
        "faq": [
          [
            "타이핑 모드에서 펜이 그려지지 않는 이유는?",
            "의도한 동작입니다. 타이핑 모드는 글과 객체만 다루며 손가락도 스타일러스도 선을 그리지 않습니다. 그래서 객체를 고르고 끌 때마다 불필요한 획이 남지 않습니다. 현재 모드는 캔버스 오른쪽 위 배지에 표시됩니다. 쓰려면 필기 모드로 돌아가세요."
          ],
          [
            "협업이 연결되지 않아요",
            "두 기기가 같은 Wi-Fi에 있는지 확인하세요. 참여자의 “중계 서버 주소”에는 호스트 화면에 표시된 ws://…:9002를 넣어야 하며 기본값 127.0.0.1이 아닙니다. 첫 연결 때 시스템이 로컬 네트워크 권한을 물으면 허용하세요."
          ],
          [
            "노트가 사라질 수 있나요?",
            "쓰는 즉시 로컬 파일에 저장됩니다. 동기화 파일은 추가만 하며 각 기기는 자기 파일만 쓰기 때문에 덮어쓰기가 일어나지 않습니다."
          ],
          [
            "계정이 필요한가요?",
            "아니요. Kairumo에는 계정도, 백엔드 서버도 없습니다."
          ],
          [
            "손글씨를 글자로 바꿀 수 있나요?",
            "가능합니다. 기기 내장 인식 기능을 사용하므로 필기가 외부로 나가지 않습니다."
          ],
          [
            "문제는 어떻게 알리나요?",
            "데스크톱 창 제목에 보이는 버전(예: Kairumo v4.8.0)과 진행한 단계를 함께 알려 주세요."
          ],
          [
            "한 노트에서 페이지 규격을 섞어 쓸 수 있나요?",
            "가능합니다. ‘페이지’의 미리보기에서 오른쪽 클릭 또는 길게 누르기 → ‘템플릿을 골라 페이지 삽입’ → 테마와 템플릿을 고르면 그 페이지만 해당 배치를 씁니다. 노트를 만들 때 고른 것은 **기본값**일 뿐입니다."
          ],
          [
            "테두리 밖에 쓰면 어떻게 되나요?",
            "점선 사각형은 인쇄 가능 영역이자 편집 영역입니다. 완전히 바깥에 그린 획은 되돌려지고 알림이 뜹니다. 인쇄도 내보내기도 되지 않는데 남겨 두면 아직 있다고 착각하게 되기 때문입니다. 경계에 걸친 획은 남기되 한 번 알려 줍니다."
          ]
        ],
        "fig": null
      }
    ]
  },
  "th": {
    "name": "ไทย",
    "figset": "en",
    "ui": {
      "docTitle": "คู่มือการใช้งาน Kairumo",
      "tagline": "สมุดจดที่รวมลายมือ การพิมพ์ และการอัดเสียงไว้ด้วยกัน ทำตามทีละขั้นได้แม้เพิ่งเริ่มใช้",
      "version": "สำหรับเวอร์ชัน v4.8.0 (build 58) · 19 กันยายน 2026",
      "tocTitle": "สารบัญ",
      "tocHint": "แตะหัวข้อเพื่อไปยังส่วนนั้นทันที",
      "stepsLabel": "ขั้นตอน",
      "tipLabel": "ข้อควรรู้",
      "buttonsLabel": "ปุ่มที่ใช้",
      "figNote": "ภาพหน้าจอเป็นภาษาอังกฤษ",
      "backToTop": "กลับไปที่สารบัญ",
      "langLabel": "ภาษา",
      "privacyLink": "นโยบายความเป็นส่วนตัว"
    },
    "sections": [
      {
        "id": "start",
        "title": "ก่อนเริ่มต้น",
        "lead": "Kairumo คือสมุดจดที่วางลายมือ ข้อความ และเสียงไว้บนไทม์ไลน์เดียวกัน ใช้ฟรี เป็นโอเพนซอร์ส และข้อมูลอยู่ในเครื่องของคุณ",
        "buttons": [],
        "steps": [
          "ใช้ได้บนแท็บเล็ต โทรศัพท์ และเดสก์ท็อป เขียนด้วยสไตลัสลื่นที่สุด แต่ใช้นิ้วหรือเมาส์ก็ได้",
          "ไม่ต้องสมัครบัญชีและไม่ต้องต่ออินเทอร์เน็ต",
          "เมื่อเปิดครั้งแรกจะมีสมุดตัวอย่างสองเล่ม (“ยินดีต้อนรับสู่ Kairumo” และ “บันทึกการเรียนและการประชุม”) ซึ่งมีข้อความ ตาราง แผนภูมิ และรูปทรงที่แก้ไขได้ทันที ลบทิ้งได้ถ้าไม่ต้องการ",
          "ทุกอย่างที่คุณเขียนถูกเก็บไว้ในเครื่องนี้ หากต้องการซิงค์ระหว่างหลายเครื่อง ให้ชี้ไปที่โฟลเดอร์บนคลาวด์ของคุณเอง (ดู “สำรองข้อมูลและซิงค์”)",
          "บนเดสก์ท็อป ชื่อหน้าต่างจะแสดงเวอร์ชัน (เช่น Kairumo v4.8.0) โปรดแจ้งมาด้วยเมื่อรายงานปัญหา"
        ],
        "tip": "เมื่อไม่มีเซิร์ฟเวอร์และไม่มีบัญชี ก็ไม่มีรหัสผ่านให้ลืม แต่ก็ไม่มีสำเนาบนคลาวด์เช่นกัน จึงควรสำรองข้อมูลเอง",
        "fig": null
      },
      {
        "id": "firstrun",
        "title": "เมื่อเปิดครั้งแรก",
        "lead": "หน้าแรกจะอธิบายว่าต้องใช้สิทธิ์ใดและเพราะอะไร อ่านจบแล้วจะเข้าสู่หน้าแรกและไม่แสดงอีก",
        "buttons": [
          "อนุญาตไมโครโฟน",
          "ไว้ทีหลัง",
          "เริ่มใช้งาน"
        ],
        "steps": [
          "หน้านี้อธิบายสามเรื่อง คือ Kairumo คืออะไร ไม่ต้องมีบัญชีและไม่มีเซิร์ฟเวอร์ของเรา และสิทธิ์เพียงหนึ่งเดียวที่อาจถูกใช้",
          "มีสิทธิ์เพียง **ไมโครโฟน** อย่างเดียว และใช้เฉพาะตอนบันทึกเสียง ไม่อนุญาตก็ได้ การเขียนด้วยลายมือ การพิมพ์ การส่งออก และการซิงค์ยังทำงานได้ทั้งหมด",
          "การแตะ “อนุญาตไมโครโฟน” คือสิ่งที่ทำให้กล่องโต้ตอบของระบบปรากฏ กล่องนี้จะปรากฏ**เพียงครั้งเดียวตลอดอายุของแอป**",
          "หากตอนนั้นเลือกไม่อนุญาต ปุ่มจะเปลี่ยนเป็น “เปิดการตั้งค่า” หลังจากนั้นจะเปิดสิทธิ์ได้จากการตั้งค่าของระบบเท่านั้น แอปไม่สามารถถามซ้ำได้",
          "แตะ “เริ่มใช้งาน” เพื่อเข้าสู่หน้าแรก หน้านี้จะไม่กลับมาอีก"
        ],
        "tip": "ระบบจะไม่ขอสิทธิ์ตอนติดตั้ง แต่จะถามเมื่อฟีเจอร์นั้นต้องใช้จริง ๆ ดังนั้นหากเริ่มบันทึกเสียงก่อนให้สิทธิ์ ระบบจะแนะนำให้อีกครั้งในตอนนั้น",
        "fig": null
      },
      {
        "id": "home",
        "title": "หน้าแรก: โต๊ะทำงานของคุณ",
        "lead": "หน้าจอแรกที่เห็นเมื่อเปิดแอป โน้ต เสียง วัสดุ และไฟล์ที่นำเข้าเริ่มจากที่นี่",
        "buttons": [
          "แก้ไขตัวตน",
          "สร้างบันทึกใหม่",
          "เริ่มบันทึกเสียง",
          "คลังแอสเซท",
          "นำเข้าโน้ต"
        ],
        "steps": [
          "ด้านบนคือชื่อที่แสดง ซึ่งเพื่อนร่วมงานจะเห็นตอนทำงานร่วมกัน แตะ “แก้ไขตัวตน” เพื่อแก้ไข",
          "ช่องค้นหาจะค้นทั้งชื่อโน้ต ข้อความที่พิมพ์ และข้อความที่ถอดจากเสียง",
          "การ์ดใหญ่สี่ใบคือการทำงานหลัก: สร้างโน้ต อัดเสียง คลังวัสดุ และนำเข้าโน้ต",
          "“นำเข้าโน้ต” ให้เลือกไฟล์ .padnote แล้วเพิ่มโน้ตต้นฉบับที่ผู้อื่นแชร์เข้าคลังของคุณ",
          "“ทำต่อ” แสดงโน้ตที่เพิ่งเปิด แตะครั้งเดียวก็กลับไปทำต่อได้",
          "“บันทึกทั้งหมด” จัดกลุ่มตามโฟลเดอร์ และเปลี่ยนการเรียงลำดับได้ทางขวา",
          "เลื่อนหน้าแรกลงจนสุดจะพบการ์ด “คู่มือการใช้งาน” และ “นโยบายความเป็นส่วนตัว” เอกสารที่คุณอ่านอยู่คืออันแรก",
          "แต่ละแถวในรายการเสียงบันทึกที่หน้าแรกมีเมนู “⋯” พร้อมคำสั่ง “แทรกลงในสมุดบันทึก” เลือกสมุดและหน้าที่จะวางเสียงนั้นได้"
        ],
        "tip": "ปุ่ม “⋯” บนการ์ดแต่ละใบมีเปลี่ยนชื่อ ย้ายโฟลเดอร์ และลบ",
        "fig": "home",
        "cap": "หน้าแรก: ชื่อที่แสดง ค้นหา การทำงานหลักสี่อย่าง Continue และ All Notebooks"
      },
      {
        "id": "newnote",
        "title": "สร้างโน้ตแรก",
        "lead": "เทมเพลตหน้า 33 แบบใน 7 กลุ่ม และเลือกสีเส้นนำได้เอง",
        "buttons": [
          "โน้ตใหม่",
          "เทมเพลตหน้า",
          "สีเส้นนำ",
          "ตกลง"
        ],
        "steps": [
          "แตะ “โน้ตใหม่” ที่หน้าแรก",
          "พิมพ์ชื่อในช่อง “ชื่อสมุดโน้ต” จะเว้นว่างไว้แล้วเปลี่ยนภายหลังก็ได้",
          "ใต้ “เทมเพลตหน้า” แถวบนเป็นชิปหมวด ทั้งเจ็ดหมวดแสดงครบพร้อมกันโดยไม่ต้องเลื่อนด้านข้าง: ทั่วไป, วิธีจดบันทึก, วางแผนและตาราง, รายการและติดตาม, งานออกแบบ, วิศวกรรม, ดิจิทัล",
          "แตะหมวดหนึ่ง รายการด้านล่างจะเปลี่ยนเป็นกลุ่มนั้น แต่ละแบบมีคำอธิบายหนึ่งบรรทัดว่าเหมาะกับอะไร",
          "กลุ่ม “วิธีจดบันทึก” คือแบบที่มีโครงสร้าง: คอร์เนล (คำใบ้/บันทึก/สรุป), สี่ช่อง (ประเด็น/คำถาม/ข้อสรุป/สิ่งที่ต้องทำ), โครงร่างสามระดับ, สองคอลัมน์เทียบ, ถาม–ตอบ, K-W-L และผังความคิด",
          "กลุ่ม “วางแผนและตาราง” กับ “รายการและติดตาม” มีแผนรายเดือน รายสัปดาห์ ตารางรายวัน ไทม์ไลน์ 24 ชม. แผนการเรียน หมุดหมายโครงการ รายการสิ่งที่ต้องทำ เช็กลิสต์ ติดตามนิสัย ติดตามงาน ตารางงานบ้าน และชาเลนจ์ 21 วัน",
          "ด้านล่างสุดคือ “สีเส้นนำ” หกสี: กราไฟต์ คราม เขียวน้ำทะเล กุหลาบ อำพัน และเขียวป่า เส้น แถบหัวข้อ และชื่อช่องจะเปลี่ยนตามสีที่เลือก",
          "แตะ “ตกลง” มุมขวาบน โน้ตจะเปิดขึ้นทันที"
        ],
        "tip": "เทมเพลตเป็นเพียงเลย์เอาต์ เปลี่ยนแล้วไม่กระทบสิ่งที่เขียนไว้ และเมื่อเข้าไปแล้ว **แต่ละหน้าใช้เทมเพลตต่างกันได้** (ดู “หน้าและโฟลเดอร์”) ส่วนสีเส้นนำใช้ทั้งเล่มหนึ่งสี เปลี่ยนได้ตลอดจากแถบบนของหน้าจอแก้ไข",
        "fig": "newnote",
        "cap": "หน้าต่างโน้ตใหม่: ชื่อ ชิปหมวด รายการเทมเพลต และสีเส้นนำ"
      },
      {
        "id": "editor",
        "title": "รู้จักหน้าจอแก้ไข",
        "lead": "ใช้เวลาหนึ่งนาทีจำตำแหน่งปุ่ม แล้วขั้นตอนถัดไปจะง่ายขึ้น",
        "buttons": [
          "หน้าแรก",
          "โครงสร้างสมุด",
          "วาดเขียน",
          "พิมพ์ข้อความ"
        ],
        "steps": [
          "แถวบนสุดจากซ้ายไปขวา: หน้าแรก โครงสร้างโน้ต สลับลายมือ/พิมพ์ ชื่อโน้ต เลขหน้า ไม้บรรทัด คลังวัสดุ แทรก หมุดสนทนา ทำงานร่วมกัน อัดเสียง ส่งออกและพิมพ์",
          "แถวที่สองคือแถบเครื่องมือของโหมดปัจจุบัน",
          "มุมขวาบนของผืนผ้าใบมีป้ายบอกโหมด ระบุว่าอยู่ในโหมดเขียนหรือพิมพ์ ปากกาจะวาดหรือไม่ และย้ายวัตถุได้หรือไม่",
          "ด้านซ้ายคือแผงโครงสร้าง สลับระหว่างรายการหน้าและโฟลเดอร์ได้",
          "ตรงกลางคือผืนผ้าใบ ความสูงของหน้าคงที่ เขียนจนสุดล่างระบบจะเตรียมหน้าถัดไปให้เอง และปุ่ม “เพิ่มหน้าถัดไป” ที่มุมขวาล่างใช้เพิ่มเองได้",
          "เมื่อหน้าต่างแคบ แถบเครื่องมือจะขึ้นบรรทัดใหม่เอง ไม่มีปุ่มหลุดออกนอกจอ",
          "ทางขวาของแถบบนมีปุ่มเล็กสองปุ่ม: **ขนาดหน้า** (A4 แนวตั้ง/แนวนอน, A5, Letter, Legal, สไลด์ 16:9, จัตุรัส) และ **สีเส้นนำ** (หกสี) การเปลี่ยนขนาดจะเปลี่ยนผืนผ้าใบ การแบ่งหน้า และขนาดที่ส่งออกไปพร้อมกัน ส่วนสีมีผลเฉพาะเส้นและหัวข้อของเลย์เอาต์",
          "เมื่อเปลี่ยนเป็นขนาดที่เล็กลง สิ่งที่จะหลุดออกนอกหน้าใหม่จะถูกดึงกลับเข้ามา ไม่เช่นนั้นจะเห็นบนจอแต่หายไปตอนพิมพ์",
          "กรอบเส้นประบนหน้าคือ **พื้นที่ที่พิมพ์ได้** ซึ่งก็คือพื้นที่แก้ไข เส้นที่วาดนอกกรอบทั้งหมดจะถูกดึงกลับพร้อมคำอธิบาย ส่วนเส้นที่คร่อมกรอบจะคงไว้แต่แจ้งเตือนหนึ่งครั้ง",
          "กดค้างหรือแตะปุ่มลัดบนผืนผ้าใบเพื่อเปิด “เมนูวงกลม” สะบัดไปใน 8 ทิศทางเพื่อสลับเครื่องมือหลัก (ปากกา ยางลบ บ่วงบาศก์ เลิกทำ ทำซ้ำ สตูดิโอสีขั้นสูง การลดการสั่น) โดยไม่ต้องยกมือไปที่แถบด้านบน"
        ],
        "tip": "ถ้าพื้นที่ไม่พอ แตะ “โครงสร้างสมุด” เพื่อพับคอลัมน์ซ้าย ผืนผ้าใบจะกว้างขึ้นทันที",
        "fig": "editor",
        "cap": "หน้าจอแก้ไข: แถบบน แถบเครื่องมือลายมือ แผงโครงสร้าง และผืนผ้าใบ"
      },
      {
        "id": "write",
        "title": "เขียนด้วยลายมือ",
        "lead": "ปากกา 7 แบบ ความหนา 4 ระดับ เลือกสีได้อิสระ ลบได้ และใช้บ่วงคล้องเพื่อย้ายทั้งกลุ่มได้",
        "buttons": [
          "ปากกาหมึกซึม",
          "ยางลบ",
          "บ่วงบาศก์",
          "ความหนาของเส้น",
          "สแน็ปแม่เหล็กและไม้บรรทัด",
          "สตูดิโอสีขั้นสูง"
        ],
        "steps": [
          "ตรวจว่าแถบบนอยู่ในโหมดลายมือ",
          "เลือกปากกา: ปากกาหมึกซึม ลูกลื่น พู่กัน มาร์กเกอร์ ไฮไลต์ ดินสอ หรือสีน้ำ",
          "จุดสี่จุดตรงกลางคือความหนา ถัดไปคือสี ส่วนไอคอนสไลเดอร์เปิดตัวเลือกสีแบบละเอียด",
          "ลบด้วยยางลบ ถ้าจะย้ายหรือคัดลอกทั้งกลุ่ม ให้ใช้บ่วงคล้องวงรอบก่อน",
          "ปลายขวาสุดคือเลิกทำ ทำซ้ำ และล้างหน้านี้",
          "เขียนจนถึงขอบล่างของหน้า ระบบจะเพิ่มหน้าถัดไปให้อัตโนมัติ",
          "หากใช้สไตลัสที่รองรับ ไม่ต้องกลับไปที่แถบเครื่องมือเพื่อลบ ปากกาบางรุ่น**แตะสองครั้งที่ด้ามปากกา** บางรุ่นมี**ปุ่มข้างด้ามให้กดค้าง** และบางรุ่นกลับหัวปากกาก็กลายเป็นยางลบ แตะอีกครั้งหรือปล่อยปุ่มก็กลับไปใช้ปากกาเดิม ส่วนการแตะสองครั้งจะทำอะไรนั้นเป็นค่าที่ตั้งไว้ในระบบ และที่นี่ทำตามค่านั้น",
          "เปิด “สแน็ปแม่เหล็กและไม้บรรทัด” ขณะวาดเส้นตรงหรือรูปทรงเรขาคณิต ลายเส้นจะดูดเข้ากับมุมมาตรฐาน (0°, 45°, 90°, 135°, 180°) และเส้นตารางอัตโนมัติ พร้อมเส้นนำเลเซอร์สีฟ้าและการสั่นตอบสนอง",
          "แถบเครื่องมือมีระบบลดการสั่น 4 ระดับเพื่อช่วยให้เส้นนิ่งขึ้น และแตะ “สตูดิโอสีขั้นสูง” เพื่อเปิดวงล้อสีแบบวงกลมพร้อมชุดสีคู่ตรงข้ามและสามเฉดสีที่กลมกลืน",
          "“โหมดแคนวาสมินิมอล”: แตะปุ่มยุบแถบเครื่องมือเพื่อพับเก็บเป็นแคปซูลลอย (Floating Tool Pill) ที่มุมจอ เพื่อการเขียนแบบเต็มจอที่ไร้สิ่งรบกวน เมื่อต้องการกู้คืน ให้คลิกปุ่มเน้นเด่นชัด “ออกจากโหมดแคนวาสมินิมอล” บนแถบนำทางด้านบน แตะฟองลอยเพื่อขยายกล่องเครื่องมือขนาดเล็ก หรือกดปุ่ม Esc บนแป้นพิมพ์เพื่อเปิดแถบเครื่องมือแบบเต็มทันที"
        ],
        "tip": "วางฝ่ามือบนจอขณะเขียนด้วยสไตลัสได้ ระบบตัดการสัมผัสฝ่ามือจะรับเฉพาะปลายปากกา ในโหมดเขียนด้วยลายมือ วัตถุบนผืนผ้าใบถูกล็อกไว้จึงไม่ถูกลากโดยบังเอิญ หากต้องการย้ายหรือแก้ไข ให้สลับไปโหมดพิมพ์",
        "fig": "editor",
        "cap": "แถบเครื่องมือลายมือ: ปากกา ความหนา สี ต่อหน้า และเพิ่มเติม"
      },
      {
        "id": "type",
        "title": "พิมพ์ข้อความ",
        "lead": "วางกล่องข้อความตรงไหนก็ได้บนผืนผ้าใบ และผสมกับลายมือได้",
        "buttons": [
          "พิมพ์ข้อความ",
          "จัดรูปแบบข้อความ",
          "สัญลักษณ์พิเศษ",
          "แทรกลิงก์",
          "ตรึงกับข้อความ"
        ],
        "steps": [
          "แตะไอคอนแป้นพิมพ์ที่แถบบนเพื่อเข้าสู่โหมดพิมพ์",
          "**แตะสองครั้ง** ที่พื้นที่ว่างบนผืนผ้าใบ กล่องข้อความจะปรากฏพร้อมแป้นพิมพ์ (ต้องสองครั้ง เพราะแตะครั้งเดียวสงวนไว้สำหรับเลื่อนและเลือกวัตถุ)",
          "“จัดรูปแบบข้อความ” ใช้ตั้งขนาด ตัวหนา ตัวเอียง ขีดเส้นใต้ การจัดแนว และสี",
          "“สัญลักษณ์พิเศษ” แทรกสัญลักษณ์คณิตศาสตร์ ส่วน “แทรกลิงก์” เปลี่ยนลิงก์ที่วางเป็นการ์ดพรีวิว",
          "ลากกล่องข้อความเพื่อย้าย และลากมุมขวาล่างเพื่อปรับขนาด",
          "“เลือกพื้นที่” ให้ลากกรอบครอบวัตถุหลายชิ้นพร้อมกัน จากนั้นย้าย คัดลอก วาง ทำสำเนา หรือลบพร้อมกันได้ ลากภายในพื้นที่ที่เลือกเพื่อย้ายทั้งกลุ่ม",
          "“การตรึงแบบไหลลื่น”: เลือกกล่องข้อความหรือวงรอบลายมือใกล้เคียงแล้วแตะ “ตรึงกับข้อความ” ลายมือจะถูกผูกเข้ากับข้อความ เมื่อย้ายกล่องข้อความหรือแก้ไขข้อความ ลายมือจะเคลื่อนที่ตามไปโดยอัตโนมัติไม่เลื่อนหลุดตำแหน่ง"
        ],
        "tip": "ในโหมดพิมพ์ **ปากกาก็ไม่วาดเช่นกัน** โหมดนี้จัดการเฉพาะข้อความและวัตถุ หากต้องการเขียนให้กลับไปโหมดเขียนด้วยลายมือ เลือกการ์ดลิงก์ที่แทรกไว้แล้วใช้ดินสอที่มุมซ้ายล่างแก้ URL ชื่อ และคำอธิบาย",
        "fig": "typing",
        "cap": "แถบเครื่องมือโหมดพิมพ์: Text Studio สัญลักษณ์ ลิงก์ เพิ่มเติม ต่อหน้า"
      },
      {
        "id": "pages",
        "title": "หน้าและโฟลเดอร์",
        "lead": "โน้ตหนึ่งเล่มมีได้หลายหน้า แต่ละหน้าใช้เทมเพลตต่างกันได้ และโน้ตหลายเล่มเก็บในโฟลเดอร์ได้",
        "buttons": [
          "โครงสร้างโน้ต",
          "หน้า",
          "โฟลเดอร์",
          "เลือกหน้า"
        ],
        "steps": [
          "แตะ “โครงสร้างโน้ต” บนแถบบนเพื่อเปิดหรือปิดคอลัมน์ซ้าย",
          "แท็บ “หน้า” แสดงภาพย่อของทุกหน้าในโน้ตนี้ แตะเพื่อไปยังหน้านั้น",
          "**คลิกขวาหรือกดค้างที่ภาพย่อ** จะเปิดเมนู ซึ่งมีรายการเหมือนปุ่ม “⋯” มุมขวาบนของแต่ละหน้าทุกประการ",
          "เมนูมี: แทรกหน้าถัดไป, แทรกหน้าด้วยเทมเพลต…, ทำสำเนาหน้านี้, คัดลอกไปยังสมุดอื่น…, ย้ายไปยังสมุดอื่น…, เลื่อนหน้าขึ้น/ลง, ย้ายไปหน้าแรก/หน้าสุดท้าย, ลบหน้านี้",
          "**แทรกหน้าด้วยเทมเพลต…** ให้เลือกหมวดแล้วเลือกเทมเพลต หน้าใหม่จะแทรกต่อจากหน้านี้ ทำให้สมุดเล่มเดียวมีทั้งหน้าสี่ช่องและหน้าตารางรายวันได้",
          "**การจัดลำดับ** ทำได้สองแบบ: ใช้รายการเลื่อนในเมนู หรือลากภาพย่อไปยังตำแหน่งที่ต้องการ (จะมีเส้นบอกจุดที่จะวาง)",
          "**ย้ายหลายหน้าไปสมุดอื่น**: แตะปุ่มเครื่องหมายถูกบนหัวแถบข้างเพื่อเข้าโหมดเลือก ติ๊กหน้าที่ต้องการ (มี “เลือกทั้งหมด”) แล้วแตะ “คัดลอกไปยัง…” หรือ “ย้ายไปยัง…” จากนั้นเลือกสมุดปลายทาง",
          "ปุ่ม “−/＋” ด้านล่างแถบข้างปรับขนาดภาพย่อ ถ้าขอขนาดกว้างกว่าแถบข้าง แถบข้างจะขยายตาม",
          "**เส้นแบ่ง**ระหว่างแถบข้างกับผืนผ้าใบลากซ้ายขวาได้ ตัวอักษรในแถบข้างจะใหญ่ขึ้นตาม แตะสองครั้งเพื่อกลับสู่ความกว้างเริ่มต้น",
          "สลับไปแท็บ “โฟลเดอร์” เพื่อดูโฟลเดอร์และโน้ตทั้งหมด เพิ่มโฟลเดอร์ย่อย เปลี่ยนชื่อ และย้ายโน้ตได้",
          "**การเก็บโน้ตเข้าโฟลเดอร์** ให้ลากโน้ตไปวางบนแถวของโฟลเดอร์ **การนำออก** ให้ลากไปยังแถวรากบนสุด หรือส่วน “ยังไม่จัดหมวด” (มีอยู่เสมอ แม้ว่างก็จะมีข้อความบอกหนึ่งบรรทัด) หากไม่อยากลาก ปุ่ม “⋯” ข้างโน้ตก็มี “นำออกจากโฟลเดอร์”",
          "แตะโน้ตอื่นในแท็บโฟลเดอร์จะสลับไปในหน้าต่างเดิม ไม่ต้องกลับหน้าแรก"
        ],
        "tip": "สมุดต้องเหลืออย่างน้อยหนึ่งหน้า ดังนั้นเมื่อเลือกทุกหน้า ปุ่ม “ย้ายไปยัง…” จะถูกปิด (แต่ “คัดลอกไปยัง…” ยังใช้ได้) หน้าที่คัดลอกจะพาตาราง รูปทรง และกล่องข้อความไปด้วย และได้ตัวระบุใหม่ การแก้ไขฉบับหนึ่งจึงไม่กระทบอีกฉบับ",
        "fig": "folders",
        "cap": "แท็บโฟลเดอร์: โฟลเดอร์ราก โฟลเดอร์ย่อย และรายการโน้ต"
      },
      {
        "id": "insert",
        "title": "แทรกรูป วัสดุ และแผนภูมิ",
        "lead": "รูปถ่าย วัสดุสเปกจริง สมการ แผนภูมิ และโมเดล 3 มิติ วางลงบนผืนผ้าใบได้ทั้งหมด",
        "buttons": [
          "แทรก",
          "แทรกรูปภาพ",
          "คลังแอสเซท",
          "คำนวณคณิตศาสตร์"
        ],
        "steps": [
          "แตะ “แทรก” ที่แถบบน หากหน้าต่างแคบ รายการเหล่านี้จะย้ายไปอยู่ในเมนู “⋯”",
          "“แทรกรูปภาพ” เลือกรูปจากคลังภาพ วางแล้วลาก ย่อขยาย ทำมุมมน และใส่กรอบได้",
          "“คลังแอสเซท” มีวัสดุสเปกจริง เช่น ชิ้นส่วนเครื่องกล อุปกรณ์อิเล็กทรอนิกส์ ยานพาหนะ เฟอร์นิเจอร์ ดาวน์โหลดแล้ววางได้เลย",
          "“คำนวณคณิตศาสตร์” และ “สร้างแผนภูมิ” เปลี่ยนสมการหรือแผนภูมิให้เป็นการ์ดบนหน้า",
          "“แทรกโมเดล 3 มิติ” วางโมเดลที่หมุนได้รอบ 360°",
          "“แทรกเสียงบันทึก” วางเสียงที่มีอยู่ลงในหน้านี้เป็นการ์ดที่เล่นได้ ย้าย ปรับขนาด เปลี่ยนชื่อ และลบได้",
          "รูปภาพยัง**ลากเข้ามาจากแอปอื่นได้โดยตรง** เพียงวางสองแอปคู่กันแล้วปล่อยรูปลงบนผืนผ้าใบ ดูที่ “แสดงคู่กันและการลากวาง”"
        ],
        "tip": "ไฟล์วัสดุถูกดาวน์โหลดไว้ในเครื่อง ลบออกจากคลังเพื่อคืนพื้นที่ได้ โดยวัสดุที่วางบนหน้าแล้วจะไม่หายไป",
        "fig": "insertmenu",
        "cap": "เมนูแทรก: คลังวัสดุ รูปภาพ สมการ โมเดล 3 มิติ หมุดสนทนา และทำงานร่วมกัน",
        "fig2": "assetlib",
        "cap2": "คลังวัสดุ: เลือกตามหมวด กดดาวน์โหลด แล้ววางลงหน้า"
      },
      {
        "id": "data",
        "title": "สำรองข้อมูลและซิงค์",
        "lead": "ไม่ต้องมีบัญชี และไม่มีเซิร์ฟเวอร์ของเรา การสำรองข้อมูลคือไฟล์เดียว ส่วนการซิงค์คือโฟลเดอร์บนคลาวด์ของคุณเอง",
        "buttons": [
          "สร้างไฟล์สำรอง",
          "กู้คืนจากไฟล์สำรอง",
          "เลือกโฟลเดอร์ซิงก์",
          "ซิงก์เดี๋ยวนี้"
        ],
        "steps": [
          "บล็อก “ข้อมูลและการซิงค์” บนหน้าแรกมีการ์ดสี่ใบ แตะการ์ดเพื่อเปิดหน้ารายละเอียดและปุ่มของฟังก์ชันนั้น",
          "“ซิงก์คลาวด์” แสดงสถานะการลงชื่อเข้าใช้ และเปิดการลงชื่อเข้าใช้ ตำแหน่งซิงก์ และปุ่มซิงก์เดี๋ยวนี้",
          "“สร้างไฟล์สำรอง” รวมโน้ต รูปภาพ และเสียงไว้ในไฟล์เดียว แล้วบันทึกไปยังตำแหน่งที่เลือก",
          "“กู้คืนจากไฟล์สำรอง” เลือกไฟล์สำรองเพื่อกู้คืน โดยจะสำรองข้อมูลปัจจุบันก่อนเสมอ",
          "ซิงค์โฟลเดอร์: สร้างโฟลเดอร์บนคลาวด์ของคุณ เช่น Kairumo แล้วกด “เลือกโฟลเดอร์ซิงก์” เพื่อชี้ไปที่โฟลเดอร์นั้น",
          "ทำแบบเดียวกันบนอีกเครื่องโดยชี้ไปโฟลเดอร์เดียวกัน",
          "กด “ซิงก์เดี๋ยวนี้” ทั้งสองเครื่อง สิ่งที่เขียนบนเครื่องหนึ่งจะปรากฏบนอีกเครื่องหลังซิงก์",
          "Kairumo ใช้กระบวนการบันทึกแบบอะตอมมิกด้วยไฟล์ชั่วคราวและการซิงค์ดิสก์จริง (fsync) เมื่อออกจากบันทึกหรือสลับไปพื้นหลังจะบันทึกลงเครื่องทันที ป้องกันไฟล์เสียหายหรือข้อมูลสูญหายแม้ไฟดับกะทันหัน",
          "การซิงค์แทร็กคู่และการกระทบยอดความแตกต่างแบบเรียลไทม์: ก่อนเริ่มการซิงค์ ระบบจะกระทบยอดความแตกต่างระหว่างสมุดบันทึกในเครื่องกับดัชนีบนคลาวด์ พร้อมทั้งคัดแยกและล้างแพ็กเกจที่ถูกลบออกไปโดยอัตโนมัติ แทร็กเบื้องหน้าจะให้ความสำคัญกับสมุดบันทึกที่กำลังเปิดใช้งานเป็นอันดับแรก ในขณะที่คิวเบื้องหลังจะซิงค์ส่วนที่เหลือพร้อมกัน นอกจากนี้ยังมีปุ่ม “คัดลอกในคลิกเดียว” และ “ส่งออกไฟล์บันทึก” เพื่อบันทึกข้อมูลการวินิจฉัยทางวิศวกรรมได้อย่างง่ายดาย"
        ],
        "tip": "การย้ายไฟล์เป็นหน้าที่ของคลาวด์ที่คุณใช้อยู่แล้ว เราไม่แตะเครือข่ายและไม่เก็บข้อมูลของคุณ จึงไม่มีปุ่ม “ลงชื่อเข้าใช้ Kairumo” การซิงก์เพิ่มไฟล์เท่านั้น ไม่เขียนทับสิ่งที่เครื่องอื่นเขียนไว้",
        "fig": null
      },
      {
        "id": "comment",
        "title": "หมุดสนทนา",
        "lead": "ปักข้อความไว้ตรงจุดที่ต้องการบนผืนผ้าใบ ใช้เตือนตัวเองหรือคุยกับทีมก็ได้",
        "buttons": [
          "เพิ่มหมุดความคิดเห็น",
          "แก้ไขแล้ว"
        ],
        "steps": [
          "แตะ “Insert → Add Comment Pin”",
          "แตะตำแหน่งที่ต้องการคุย หมุดจะปักลงตรงนั้นและเปิดกล่องสนทนา",
          "พิมพ์ในช่องด้านล่างแล้วแตะลูกศรเพื่อส่ง",
          "ถ้ากล่องบังเนื้อหา ให้ลากที่จับ “≡” ทางซ้ายเพื่อย้าย",
          "แตะ “−” เพื่อย่อเหลือแถบชื่อ (ย่อแล้วยังลากได้) และแตะ “✕” เพื่อปิด",
          "เมื่อคุยจบ แตะ “แก้ไขแล้ว” หมุดจะเปลี่ยนเป็นเครื่องหมายถูกสีเทา"
        ],
        "tip": "หมุดจะติดไปกับโน้ตทั้งตอนส่งออกและตอนซิงก์ และทุกคนในเซสชันจะเห็นหมุดชุดเดียวกัน",
        "fig": "comment",
        "cap": "กล่องสนทนา: ที่จับสำหรับลาก แก้ไขแล้ว ลบ ย่อ และปิด",
        "fig2": "pin_min",
        "cap2": "ย่อเหลือแถบชื่อ —— และยังลากย้ายได้"
      },
      {
        "id": "collab",
        "title": "ทำงานร่วมกันแบบเรียลไทม์ (ทีละขั้น)",
        "lead": "เขียนพร้อมกันหลายคนแบบเรียลไทม์ ไม่มีเซิร์ฟเวอร์คลาวด์ —— ตัวส่งต่อเป็นเครื่องที่คุณดูแลเองเสมอ มีสองกรณี: ทุกคนอยู่เครือข่ายเดียวกัน หรืออยู่คนละเครือข่าย ใช้ได้ทั้งคู่ ต่างกันแค่การตั้งค่าบรรทัดเดียว",
        "buttons": [
          "การทำงานร่วมกัน",
          "เริ่มการทำงานร่วมกัน",
          "คัดลอกลิงก์คำเชิญที่เข้ารหัส",
          "เข้าร่วมห้อง",
          "ที่อยู่เซิร์ฟเวอร์รีเลย์",
          "สิ้นสุดการทำงานร่วมกัน"
        ],
        "steps": [
          "**เลือกก่อนว่าเป็นกรณีไหน** ออฟฟิศเดียวกัน Wi-Fi เดียวกัน → กรณี A. บางคนอยู่บ้าน บางคนอยู่ที่ทำงาน หรือต่างประเทศ → กรณี B",
          "── **กรณี A: ทุกคนอยู่เครือข่ายเดียวกัน** ──",
          "**A1 — ให้คนหนึ่งเป็นผู้เปิดห้อง** เปิดโน้ตที่จะทำร่วมกัน แตะ “การทำงานร่วมกัน” แล้วแตะ “เริ่มการทำงานร่วมกัน”",
          "**A2 — หน้าจอผู้เปิดห้องจะแสดงสามอย่าง:** Room ID (เช่น kairumo-a1b2c3), ป้ายสีเขียว “เข้ารหัสแบบ end-to-end” และบรรทัด “เครื่องนี้กำลังเป็นตัวส่งต่อ　ws://192.168.x.x:9002” อย่าเพิ่งปิดบรรทัดที่สาม",
          "**A3 — ผู้เข้าร่วมตั้งที่อยู่รีเลย์ก่อน** เปิดโน้ตใดก็ได้ → “การทำงานร่วมกัน” → กาง “ที่อยู่เซิร์ฟเวอร์รีเลย์” แล้วแก้ ws://127.0.0.1:9002 เป็น**ที่อยู่บนหน้าจอผู้เปิดห้อง** เพราะ 127.0.0.1 แปลว่า “เครื่องตัวเอง”",
          "── **กรณี B: ไม่ได้อยู่เครือข่ายเดียวกัน** ──",
          "**การทำงานร่วมกันไม่ได้ผูกกับเครือข่ายเดียว** สิ่งที่ต้องมีคือที่อยู่รีเลย์ที่ทั้งสองฝั่งเข้าถึงได้ และต้องเป็น **wss://** (TLS) เพราะ Room ID และรายชื่อผู้เข้าร่วมส่งแบบไม่เข้ารหัส จึงไม่รับ ws:// บนอินเทอร์เน็ตสาธารณะ มีสามวิธี เรียงจากง่ายไปยาก:",
          "**B-1 — เครือข่ายส่วนตัวเสมือน (ง่ายที่สุด ไม่ต้องตั้งเซิร์ฟเวอร์)** ติดตั้ง Tailscale (หรือ ZeroTier) บนทุกเครื่องและล็อกอินบัญชีเดียวกัน ทุกเครื่องจะเสมือนอยู่เครือข่ายเดียวกัน ผู้เปิดห้องบอกที่อยู่ Tailscale ของตน แล้วทุกคนกรอก ws://100.x.y.z:9002 เพราะเป็นช่วงที่อยู่ส่วนตัว จึงไม่ต้องใช้ TLS",
          "**B-2 — ทำอุโมงค์ให้รีเลย์ของผู้เปิดห้องออกสู่ภายนอก (ไม่ต้องมีเซิร์ฟเวอร์หรือบัญชี)** บนคอมพิวเตอร์ของผู้เปิดห้องรัน cloudflared tunnel --url http://localhost:9002 จะได้ URL https://xxxx.trycloudflare.com ผู้เข้าร่วมกรอก “ที่อยู่เซิร์ฟเวอร์รีเลย์” เป็น wss://xxxx.trycloudflare.com (เปลี่ยน https เป็น wss) ปิดเทอร์มินัลก็จบอุโมงค์",
          "**B-3 — ตั้งเองถาวร (ใช้ประจำ)** รัน padnote-relay บนเครื่องที่มีที่อยู่สาธารณะ (HOST=0.0.0.0 PORT=9002) วาง Caddy หรือ nginx ไว้ด้านหน้าเพื่อทำ TLS แล้วทุกคนกรอก wss://relay.โดเมนของคุณ ดูวิธีได้ที่ docs/relay-hosting.md ในโปรเจกต์",
          "── **จากนี้ไปเหมือนกันทั้งสองกรณี** ──",
          "**ขั้นที่ 1 — ผู้เปิดห้องแตะ “คัดลอกลิงก์คำเชิญที่เข้ารหัส” แล้วส่งให้เพื่อน** รูปแบบ: kairumo://collab?room=kairumo-a1b2c3#key=…",
          "⚠️ **ส่งแค่ Room ID ไม่พอ** ส่วนหลัง # คือกุญแจถอดรหัส คนที่เข้าด้วย ID อย่างเดียวจะเชื่อมต่อได้และเห็นรายชื่อ แต่**ถอดรหัสสิ่งที่คนอื่นเขียนไม่ได้เลย** หน้าจอจะว่าง (จะมีคำเตือนสีส้มขึ้น) ต้องส่งลิงก์ทั้งเส้นเสมอ",
          "**ขั้นที่ 2 — วางลิงก์แล้วเข้าร่วม** วางลิงก์คำเชิญทั้งเส้นในช่อง “เข้าร่วมห้อง” แล้วแตะเข้าร่วม",
          "**ขั้นที่ 3 — ยืนยันว่าเชื่อมต่อแล้ว** ทั้งสองเครื่องต้องเห็นชื่อกันในรายการ “ผู้เข้าร่วม” และฝั่งผู้เปิดห้องมีป้าย “เจ้าของห้อง”",
          "**ขั้นที่ 4 — เริ่มเขียน** ลายเส้น กล่องข้อความ ตาราง รูปทรง และหมุดความเห็นจากเครื่องใดก็ตามจะปรากฏบนอีกเครื่องทันที",
          "**ขั้นที่ 5 — จบงาน** ผู้เปิดห้องแตะ “สิ้นสุดการทำงานร่วมกัน” เพื่อปิดห้อง ส่วนผู้เข้าร่วมที่แตะ “ตัดการเชื่อมต่อ” จะออกเฉพาะตัวเอง"
        ],
        "tip": "ชนิดของเครื่องไม่มีผล ทุกเครื่องใช้ Room ID เดียวกัน กุญแจเดียวกัน และโปรโตคอลรีเลย์เดียวกัน เครื่องใดก็เป็นผู้เปิดห้องได้ เนื้อหาเข้ารหัสแบบ end-to-end ด้วย AES-256-GCM และตัวส่งต่อเพียงส่งข้อความที่อ่านไม่ออก —— แม้ใช้บริการอุโมงค์ของผู้อื่นก็อ่านโน้ตของคุณไม่ได้ การแก้ไขระหว่างออฟไลน์จะถูกพักไว้และส่งอัตโนมัติเมื่อกลับมาเชื่อมต่อ",
        "fig": "collab",
        "cap": "ยังไม่เชื่อมต่อ: เริ่มทำงานร่วมกัน เข้าร่วมห้อง ที่อยู่เซิร์ฟเวอร์รีเลย์",
        "fig2": "collab_on",
        "cap2": "เชื่อมต่อแล้ว: Room ID การเข้ารหัส เครื่องนี้เป็นตัวส่งต่อ และผู้เข้าร่วม"
      },
      {
        "id": "record",
        "title": "อัดเสียงและถอดความ",
        "lead": "เสียงกับลายมืออยู่บนไทม์ไลน์เดียวกัน แตะคำหนึ่งแล้วกระโดดไปยังเส้นที่เขียนในวินาทีนั้น",
        "buttons": [
          "เริ่มบันทึกเสียง",
          "หยุดชั่วคราว",
          "บันทึกต่อ",
          "เสร็จสิ้นการบันทึก",
          "การบันทึกและการถอดเสียงล่าสุด",
          "ถอดเสียง",
          "การซิงค์เสียงกับลายมือ"
        ],
        "steps": [
          "แตะ “เริ่มบันทึกเสียง” ที่หน้าแรก หรือไอคอนไมโครโฟนในโน้ต",
          "ครั้งแรกระบบจะขออนุญาตใช้ไมโครโฟน ให้กดอนุญาต",
          "ระหว่างอัด จะเห็นคลื่นเสียงด้านบน และสิ่งที่เขียนจะถูกจัดให้ตรงกับเสียง",
          "หากต้องการพัก ให้แตะ “หยุดชั่วคราว” แตะ “บันทึกต่อ” เพื่ออัดต่อ และแตะ “เสร็จสิ้นการบันทึก” เพื่อบันทึกและจบ",
          "เมื่อหยุด ไฟล์จะไปอยู่ใน “การบันทึกและการถอดเสียงล่าสุด” ที่หน้าแรก",
          "ระหว่างเล่น แตะบรรทัดของข้อความที่ถอดไว้ เพื่อไปยังลายมือในช่วงเวลานั้น (และย้อนกลับได้)",
          "หากต้องการวางเสียงบันทึกลงในหน้า ให้เลือก “เพิ่มเติม → แทรกเสียงบันทึก” ในสมุดบันทึก หรือใช้ “⋯ → แทรกลงในสมุดบันทึก” ที่แถวเสียงบนหน้าแรก",
          "เลือกการ์ดเสียงบนหน้าแล้วแตะ “ถอดเสียง” ที่มุมซ้ายบน Kairumo จะเปลี่ยนเสียงเป็นกล่องข้อความใต้การ์ด",
          "รองรับการเล่นแบบ “การซิงค์เสียงกับลายมือ”: ขณะเล่นเสียง ลายมือที่เขียนในขณะนั้นจะสว่างขึ้นตามจังหวะเสียง และสามารถแตะที่ลายมือบนผืนผ้าใบเพื่อข้ามไปยังช่วงเวลาที่เขียนลายมือนั้นได้ทันที"
        ],
        "tip": "ทั้งการบันทึกเสียงและการถอดความทำงานในเครื่องนี้ ไม่มีการอัปโหลด การถอดความต้องใช้เอนจินที่ทำงานในเครื่อง และ**ไม่ใช่ทุกเครื่องจะมี** — ถ้าไม่มี การบันทึกเสียงยังใช้ได้ แต่อาจไม่มีข้อความถอดความในรายการเสียง และการ์ดเสียงอาจสร้างกล่องข้อความไม่ได้",
        "fig": "home",
        "cap": "“เริ่มบันทึกเสียง” และ “การบันทึกและการถอดเสียงล่าสุด” ที่หน้าแรก"
      },
      {
        "id": "export",
        "title": "ส่งออก พิมพ์ และแชร์",
        "lead": "มีสี่ทางเลือก เลือกตามที่ปลายทางต้องการ",
        "buttons": [
          "ส่งออกและพิมพ์",
          "ส่งออก PDF",
          "ส่งออกเป็นรูปภาพ",
          "พิมพ์สมุดบันทึก",
          "แชร์บันทึก"
        ],
        "steps": [
          "แตะ “ส่งออกและพิมพ์” ที่มุมขวาบน",
          "“ส่งออก PDF” เปลี่ยนทั้งเล่มเป็นไฟล์ PDF",
          "“ส่งออกเป็นรูปภาพ” บันทึกหน้าปัจจุบันเป็นไฟล์รูป",
          "“พิมพ์สมุดบันทึก” ส่งต่อไปยังหน้าต่างพิมพ์ของระบบ",
          "“แชร์บันทึก” ส่งไฟล์ .padnote ต้นฉบับ ผู้รับเปิดด้วย Kairumo แล้วแก้ไขต่อได้"
        ],
        "tip": "พิกัดของคำอธิบายใน PDF ตรงกับต้นฉบับ เปิดในแอปอื่นก็ไม่เคลื่อน",
        "fig": "export",
        "cap": "เมนูส่งออก: PDF รูปภาพ พิมพ์ และแชร์โน้ต"
      },
      {
        "id": "keys",
        "title": "แป้นพิมพ์ลัด",
        "lead": "เมื่อต่อแป้นพิมพ์จริง การกระทำที่ใช้บ่อยมีแป้นลัดทั้งหมด",
        "buttons": [],
        "steps": [
          "“⌘” ที่เขียนด้านล่าง หมายถึงปุ่ม Command บนแป้นพิมพ์ที่มีปุ่มนี้ ส่วนแป้นพิมพ์อื่นให้กด **Ctrl** แทน",
          "**⇧⌘N** — สร้างโน้ตใหม่ ปุ่ม Shift สำคัญ เพราะ ⌘N เปล่า ๆ คือ “หน้าต่างใหม่” ของระบบ ถ้าชนกันจะใช้ไม่ได้ทั้งคู่",
          "**⌘F** — ย้ายเคอร์เซอร์ไปที่ช่องค้นหาบนหน้าแรกทันที",
          "**⌘E** — สลับระหว่างโหมดเขียนด้วยลายมือกับโหมดพิมพ์",
          "**⌘1** เป็นต้นไป — เลือกหัวแปรงหรือเครื่องมือตามลำดับบนแถบเครื่องมือ หากมีเครื่องมือน้อยกว่าตัวเลข ตัวเลขที่เกินมาจะไม่ทำอะไร"
        ],
        "tip": "ขณะที่เคอร์เซอร์อยู่ในกล่องข้อความ ⌘A, ⌘C และ ⌘V ยังคงเป็นเลือกทั้งหมด คัดลอก และวาง แป้นลัดเหล่านี้จะไม่แย่งไป",
        "fig": null
      },
      {
        "id": "multi",
        "title": "แสดงคู่กันและการลากวาง",
        "lead": "วาง Kairumo ไว้ข้างแอปอื่น แล้วลากรูปภาพมาวางบนผืนผ้าใบได้โดยตรง",
        "buttons": [],
        "steps": [
          "บนแท็บเล็ตหรือเครื่องตั้งโต๊ะ ใช้การแบ่งหน้าจอของระบบเพื่อวาง Kairumo ไว้ข้างคลังรูปภาพ (หรือไฟล์ หรือเบราว์เซอร์)",
          "แตะค้างที่รูปภาพฝั่งตรงข้ามแล้วลากมาที่ผืนผ้าใบของ Kairumo เมื่อเห็นกรอบเส้นประแสดงว่าปล่อยได้แล้ว",
          "เมื่อปล่อย รูปจะไปอยู่ตรงตำแหน่งที่ปล่อย และย่อให้พอดีกับหน้าโดยคงสัดส่วนเดิม",
          "หากปล่อยใกล้ขอบ รูปจะถูกดันกลับเข้าด้านใน จะไม่มีครึ่งหนึ่งเลยออกนอกหน้า (ส่วนที่เลยออกไปจะถูกตัดตอนส่งออกและพิมพ์)",
          "หลังวางแล้วแอปจะสลับไปโหมดพิมพ์ ทำให้ย้ายและปรับขนาดได้ทันที",
          "เมื่อแสดงคู่กัน หน้าต่างจะแคบลง แถบเครื่องมือจะขึ้นบรรทัดใหม่แทนที่จะดันปุ่มจนมองไม่เห็น"
        ],
        "tip": "รูปที่ลากเข้ามาเหมือนกับรูปที่ใส่ผ่าน “แทรกรูปภาพ” ทุกประการ ปรับขนาด หมุน ใส่มุมมน และใส่เส้นขอบได้เช่นกัน",
        "fig": null
      },
      {
        "id": "language",
        "title": "ภาษาและชื่อที่แสดง",
        "lead": "รองรับหกภาษา สลับได้ทันที",
        "buttons": [
          "ภาษาของอินเทอร์เฟซ",
          "แก้ไขตัวตน"
        ],
        "steps": [
          "บนหน้าแรก แตะ “ภาษาของอินเทอร์เฟซ” ที่มุมขวาบน ข้อความอยู่ถัดจากไอคอนลูกโลก",
          "เลือก 繁體中文, English, 简体中文, 日本語, 한국어 หรือ ไทย",
          "หน้าจอเปลี่ยนทันทีโดยไม่ต้องเปิดแอปใหม่",
          "ที่หน้าแรก “แก้ไขตัวตน” ใช้เปลี่ยนชื่อและสีที่เพื่อนร่วมงานเห็น"
        ],
        "tip": "ชื่อที่แสดงถูกเก็บไว้ในเครื่องนี้เท่านั้น และไม่ถูกส่งออกไปที่ใด",
        "fig": "language",
        "cap": "เมนูภาษา: สลับหกภาษาได้ทันที"
      },
      {
        "id": "faq",
        "title": "แก้ปัญหาที่พบบ่อย",
        "lead": "ตรวจที่นี่ก่อน",
        "buttons": [],
        "faq": [
          [
            "ทำไมปากกาไม่วาดในโหมดพิมพ์",
            "เป็นการออกแบบไว้เช่นนั้น โหมดพิมพ์จัดการเฉพาะข้อความและวัตถุ ทั้งนิ้วและสไตลัสจะไม่วาดเส้น การเลือกและลากวัตถุจึงไม่ทิ้งรอยขีดไว้ ป้ายที่มุมขวาบนของผืนผ้าใบบอกว่าอยู่โหมดใด หากต้องการเขียนให้กลับไปโหมดเขียนด้วยลายมือ"
          ],
          [
            "เชื่อมต่อการทำงานร่วมกันไม่ได้",
            "ตรวจว่าทั้งสองเครื่องอยู่บน Wi-Fi เดียวกัน ช่อง “ที่อยู่เซิร์ฟเวอร์รีเลย์” ของผู้เข้าร่วมต้องเป็น ws://…:9002 ตามที่แสดงบนหน้าจอผู้เริ่ม ไม่ใช่ค่าเริ่มต้น 127.0.0.1 และเมื่อเชื่อมต่อครั้งแรก ระบบจะขออนุญาตใช้เครือข่ายท้องถิ่น ให้กดอนุญาต"
          ],
          [
            "โน้ตหายได้ไหม",
            "ทุกเส้นถูกบันทึกลงไฟล์ในเครื่องทันทีที่เขียน ไฟล์ซิงก์เป็นแบบเพิ่มอย่างเดียว และแต่ละเครื่องเขียนเฉพาะไฟล์ของตัวเอง จึงไม่ทับกัน"
          ],
          [
            "ต้องมีบัญชีไหม",
            "ไม่ต้อง Kairumo ไม่มีระบบบัญชีและไม่มีเซิร์ฟเวอร์เบื้องหลัง"
          ],
          [
            "แปลงลายมือเป็นข้อความได้ไหม",
            "ได้ โดยใช้การรู้จำที่ทำงานในเครื่อง ลายมือไม่ถูกส่งออกไปที่ใด"
          ],
          [
            "รายงานปัญหาอย่างไร",
            "โปรดแจ้งเวอร์ชันที่แสดงบนชื่อหน้าต่างของเดสก์ท็อป (เช่น Kairumo v4.8.0) พร้อมขั้นตอนที่ทำ"
          ],
          [
            "สมุดเล่มเดียวใช้ขนาด/เทมเพลตหน้าต่างกันได้ไหม",
            "ได้ คลิกขวาหรือกดค้างที่ภาพย่อในแท็บ “หน้า” → “แทรกหน้าด้วยเทมเพลต…” → เลือกหมวดและเทมเพลต หน้าใหม่จะใช้เลย์เอาต์นั้นโดยหน้าอื่นไม่เปลี่ยน สิ่งที่เลือกตอนสร้างสมุดเป็นเพียง **ค่าเริ่มต้น**"
          ],
          [
            "ถ้าเขียนออกนอกกรอบจะเป็นอย่างไร",
            "กรอบเส้นประคือพื้นที่ที่พิมพ์ได้ และเป็นพื้นที่แก้ไขด้วย เส้นที่วาดนอกกรอบทั้งหมดจะถูกดึงกลับพร้อมข้อความแจ้ง เพราะพิมพ์และส่งออกไม่ได้ หากปล่อยไว้จะทำให้เข้าใจผิดว่ายังอยู่ ส่วนเส้นที่คร่อมกรอบจะคงไว้และแจ้งหนึ่งครั้ง"
          ]
        ],
        "fig": null
      }
    ]
  }
};
