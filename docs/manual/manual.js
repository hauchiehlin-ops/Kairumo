/*
 * Kairumo 操作手冊內容（六國語系）
 *
 * 每個語系的結構完全一致：sections[] 依實際操作順序排列，
 * fig 對應 img/ 底下的實機截圖。中文語系用繁中介面截圖，
 * 其餘語系用英文介面截圖 —— 圖下方會標明截圖語言。
 */

window.KAIRUMO_MANUAL = {
  figsets: {
    zh: ["zh-Hant", "zh-Hans"],
    en: ["en", "ja", "ko", "th"]
  },

  "zh-Hant": {
    name: "繁體中文",
    figset: "zh",
    ui: {
      docTitle: "Kairumo 操作手冊",
      tagline: "手寫、打字、錄音三合一的筆記本。零基礎也能一步一步跟著做。",
      version: "適用版本 v2.4.1（bundle 17）· 2026 年 9 月 13 日",
      tocTitle: "目錄",
      tocHint: "點任一項目直接跳到該段落",
      stepsLabel: "操作步驟",
      tipLabel: "小提醒",
      buttonsLabel: "會用到的按鈕",
      figNote: "截圖為繁體中文介面（iPad）",
      backToTop: "回到目錄",
      langLabel: "語言",
      privacyLink: "隱私權政策"
    },
    sections: [
      {
        id: "start",
        title: "開始之前",
        lead: "Kairumo 是一本把手寫、打字與錄音放在同一條時間軸上的筆記本。完全免費、開放原始碼，資料留在你自己的裝置上。",
        buttons: [],
        steps: [
          "支援 iPad、iPhone 與 Mac；手寫用 Apple Pencil 最順，用手指或滑鼠一樣可以寫。",
          "第一次打開不需要註冊帳號，也不需要網路連線。",
          "你寫下的每一筆都存在這台裝置裡。要備份就把資料夾放進自己的 iCloud 或 Google Drive。",
          "Mac 版視窗左上角會顯示版本號（例如 Kairumo v2.4.1），回報問題時請附上它。"
        ],
        tip: "沒有伺服器、沒有帳號，就沒有「忘記密碼」這回事 —— 但也代表裝置遺失時沒有雲端副本，請自己做備份。",
        fig: null
      },
      {
        id: "home",
        title: "首頁：你的工作台",
        lead: "打開 App 看到的第一個畫面。所有筆記、錄音與素材都從這裡進入。",
        buttons: ["編輯身分", "新增筆記", "開始錄音", "素材圖庫"],
        steps: [
          "最上方是你的顯示身分 —— 協同時隊友看到的就是這個名字，點右邊的「編輯身分」可以修改。",
          "搜尋列可以同時搜尋筆記標題、打字內容與錄音轉錄出來的文字。",
          "中間三張大卡片是主要動作：新增筆記、開始錄音、素材圖庫。",
          "「繼續」列出最近開過的筆記，點一下就回到上次的位置。",
          "「全部筆記」依資料夾分類顯示；右上角可以切換排序方式。"
        ],
        tip: "每張筆記卡片右上角的「⋯」裡有重新命名、移動到資料夾與刪除。",
        fig: "home",
        cap: "首頁：身分、搜尋、三個主要動作、繼續、全部筆記"
      },
      {
        id: "newnote",
        title: "建立第一則筆記",
        lead: "從空白紙張到康乃爾筆記，四種紙張樣板任選。",
        buttons: ["新增筆記", "確認"],
        steps: [
          "在首頁點「新增筆記」。",
          "在「筆記標題」欄輸入名稱。不填也可以，之後隨時能改。",
          "先選主題分類，再從下方選紙張樣板：空白紙張、方格點陣、橫線筆記、康乃爾筆記。",
          "點右上角「確認」，筆記會立刻打開，可以直接開始寫。"
        ],
        tip: "選錯樣板不用重來 —— 紙張只是背景，換掉不會影響已經寫下的內容。",
        fig: "newnote",
        cap: "新增筆記本視窗：標題、主題分類與四種紙張樣板"
      },
      {
        id: "editor",
        title: "認識編輯畫面",
        lead: "先花一分鐘認位置，後面每一步都會用到。",
        buttons: ["首頁", "筆記結構", "手繪模式", "打字模式"],
        steps: [
          "最上排由左到右：回首頁、筆記結構、手繪／打字切換、筆記標題、頁碼、尺規、素材圖庫、插入、討論圖釘、線上協同、錄音、匯出與列印。",
          "第二排是目前模式的工具列：手繪模式顯示筆刷與顏色，打字模式顯示文字排版。",
          "左側是結構欄，可切換「頁面結構」與「資料夾目錄」。",
          "中間是畫布。右下角可以「新增下一頁」，或把這一頁「向下延長（+800pt）」。",
          "視窗變窄時工具列會自動換行，不會有按鈕被擠到畫面外。"
        ],
        tip: "螢幕不夠寬時，點「筆記結構」把左欄收起來，畫布立刻變寬。",
        fig: "editor",
        cap: "編輯畫面：上排主工具列、手繪工具列、左側結構欄與畫布"
      },
      {
        id: "write",
        title: "手寫",
        lead: "七種筆、四段粗細、可自訂顏色。寫錯可以擦，也可以整段圈起來搬家。",
        buttons: ["鋼筆", "橡皮擦", "套索選取", "延長此頁"],
        steps: [
          "確認上排停在「手繪模式」。",
          "從工具列挑一支筆：鋼筆、原子筆、毛筆、麥克筆、螢光筆、鉛筆、水彩筆。",
          "工具列中間的四顆圓點選粗細，右邊的色盤選顏色；點色盤旁的滑桿圖示可自訂任何顏色。",
          "寫錯時選「橡皮擦」擦掉；想搬動或複製一整段筆跡，用「套索選取」圈起來再操作。",
          "最右邊是復原、重做與清除本頁。",
          "紙不夠用就點「延長此頁」，這一頁會往下長 800pt。"
        ],
        tip: "用 Apple Pencil 書寫時可以直接把手掌放在螢幕上 —— 掌拒會忽略手掌，只認筆尖。",
        fig: "editor",
        cap: "手繪工具列：筆刷、粗細、色盤、延長此頁與更多"
      },
      {
        id: "type",
        title: "打字",
        lead: "在畫布上任何位置放文字方塊，和手寫混排。",
        buttons: ["打字模式", "文字排版", "特殊符號", "插入連結"],
        steps: [
          "點上排的鍵盤圖示，切換到「打字模式」。",
          "在畫布上任何一處點一下，該位置就會出現文字方塊並跳出鍵盤。",
          "點「文字排版」可以調字級、粗體、斜體、底線、對齊與文字顏色。",
          "「特殊符號」可插入數學與常用符號；「插入連結」貼上網址後會變成可點擊的預覽卡片。",
          "文字方塊可以直接拖曳移動，拖右下角的把手可以改變大小。"
        ],
        tip: "打字模式下畫布只認 Apple Pencil，手指的滑動會當成捲動 —— 不會誤畫到線。",
        fig: "typing",
        cap: "打字模式工具列：文字排版、特殊符號、插入連結、更多、延長此頁"
      },
      {
        id: "pages",
        title: "頁面與資料夾",
        lead: "一則筆記可以有很多頁；很多則筆記可以放進資料夾。",
        buttons: ["筆記結構", "頁面結構", "資料夾目錄", "新增頁面"],
        steps: [
          "點上排「筆記結構」開關左欄。",
          "「頁面結構」列出這則筆記每一頁的縮圖，點縮圖就跳到那一頁。",
          "每頁標題右邊的「⋯」可以在後面插入新頁、複製該頁、刪除該頁或延長該頁。",
          "切到「資料夾目錄」可以看到所有資料夾與筆記；可新增子資料夾、重新命名、把筆記搬到別的資料夾。",
          "在資料夾目錄直接點另一則筆記，就會在同一個視窗切換過去，不用先回首頁。"
        ],
        tip: "縮圖與畫布等比例、位置一致，可以直接當成整頁預覽使用。",
        fig: "folders",
        cap: "左側結構欄的「資料夾目錄」：根資料夾、子資料夾與筆記清單"
      },
      {
        id: "insert",
        title: "插入圖片、素材與圖表",
        lead: "照片、實體規格素材、算式、圖表與 3D 模型都能放進畫布。",
        buttons: ["插入", "插入圖片", "素材圖庫", "算式計算"],
        steps: [
          "點上排「插入」。視窗較窄時，這些項目會收在「⋯」選單裡。",
          "「插入圖片」從相簿挑一張照片；插入後可拖曳、縮放、加圓角與外框。",
          "「素材圖庫」內含機械、3C、汽機車、家具等實體規格素材，下載後即可插入畫布。",
          "「算式計算」與「數字製圖」可以把算式或圖表變成卡片放進筆記。",
          "「插入 3D 模型」放進可 360° 旋轉的立體模型。"
        ],
        tip: "素材圖庫的檔案下載在本機，可以在圖庫裡刪除以釋放空間；已插入畫布的圖不會受影響。",
        fig: "insertmenu",
        cap: "插入選單：素材圖庫、插入圖片、算式計算、3D 模型、討論圖釘與線上協同",
        fig2: "assetlib",
        cap2: "素材圖庫：依分類瀏覽，點「下載」後即可插入"
      },
      {
        id: "comment",
        title: "討論圖釘",
        lead: "把留言釘在畫布的特定位置上，自己備忘或跟隊友討論都適用。",
        buttons: ["新增討論圖釘", "標記為已解決"],
        steps: [
          "點「插入 →　新增討論圖釘」。",
          "在畫布上想討論的位置點一下，圖釘就釘在那裡，對話框會跟著打開。",
          "在下方輸入框打字，按右邊的箭頭送出，就成為一則留言。",
          "對話框擋到內容時，按住最左邊的「≡」握把把它拖到旁邊。",
          "按「−」可以縮小成一條標題列（縮小後一樣可以拖曳）；按「✕」關閉。",
          "討論完成後按「標記為已解決」，圖釘會變成灰色打勾。"
        ],
        tip: "圖釘會跟著筆記一起匯出與同步；協同時所有人都看得到同一批圖釘。",
        fig: "comment",
        cap: "討論圖釘對話框：拖曳握把、已解決、刪除、縮小與關閉",
        fig2: "pin_min",
        cap2: "縮小後的精簡標題列 —— 仍然可以拖曳移動"
      },
      {
        id: "collab",
        title: "線上協同",
        lead: "同一個 Wi-Fi 下多人即時共筆。沒有雲端伺服器 —— 發起的那台裝置自己就是中繼點。",
        buttons: ["線上協同", "開始多人協同", "複製加密邀請連結", "結束協同會議"],
        steps: [
          "點上排「線上協同」。",
          "由其中一人按「開始多人協同」。這台裝置會自己擔任中繼服務，不需要任何外部伺服器。",
          "畫面會顯示「房間識別碼」。按「複製加密邀請連結」把連結傳給隊友。",
          "隊友打開同一個畫面，在「加入協同房間」貼上房號或連結，按加入。",
          "若隊友是另一台裝置，請他們展開「協同伺服器位址」，改填房主畫面上顯示的區域網路位址（ws://…:9002）。",
          "結束時由房主按「結束協同會議」。"
        ],
        tip: "內容以 AES-256-GCM 端對端加密傳送，中繼點只轉發看不懂的密文。離線期間的操作會先暫存，連線恢復後自動補送。",
        fig: "collab",
        cap: "尚未連線：開始多人協同、加入協同房間、協同伺服器位址",
        fig2: "collab_on",
        cap2: "已連線：房間識別碼、端對端加密、本機正在提供中繼、線上參與者"
      },
      {
        id: "record",
        title: "錄音與轉錄",
        lead: "錄音與筆跡走同一條時間軸 —— 點文字就能跳回當時寫下的那一筆。",
        buttons: ["開始錄音", "最近錄音與轉錄"],
        steps: [
          "在首頁點「開始錄音」，或在筆記裡點上排的麥克風圖示。",
          "第一次使用會詢問麥克風權限，請選擇允許。",
          "錄音中畫面上方會顯示即時波形；此時寫下的筆跡會自動與聲音對齊。",
          "停止後，該段錄音會出現在首頁的「最近錄音與轉錄」。",
          "播放時點某一段轉錄文字，畫面會跳到當時寫下的筆跡；反過來點筆跡也可以跳到對應的聲音。"
        ],
        tip: "錄音與中文轉錄都在這台裝置上完成，不會上傳到任何伺服器。",
        fig: "home",
        cap: "首頁的「開始錄音」與「最近錄音與轉錄」"
      },
      {
        id: "export",
        title: "匯出、列印與分享",
        lead: "四種輸出方式，依對方需要選一種。",
        buttons: ["匯出與列印", "匯出 PDF", "匯出為圖片", "列印筆記", "分享筆記"],
        steps: [
          "點右上角的「匯出與列印」。",
          "「匯出 PDF」把整本筆記轉成 PDF，適合寄給別人或存檔。",
          "「匯出為圖片」輸出目前這一頁的圖檔。",
          "「列印筆記」走系統列印流程。",
          "「分享筆記」傳出 .padnote 原始檔，對方用 Kairumo 打開可以繼續編輯。"
        ],
        tip: "PDF 內的標註座標與原稿一致，用其他 App 打開也不會跑位。",
        fig: "export",
        cap: "匯出與列印選單：匯出 PDF、匯出為圖片、列印筆記、分享筆記"
      },
      {
        id: "language",
        title: "語言與顯示身分",
        lead: "介面支援六種語言，隨時切換、立即生效。",
        buttons: ["語言", "編輯身分"],
        steps: [
          "在首頁右上角點語言按鈕。",
          "從清單中選擇：繁體中文、English、简体中文、日本語、한국어、ไทย。",
          "介面會立刻切換，不需要重新啟動 App。",
          "回到首頁上方點「編輯身分」，可以修改協同時顯示的名字與代表色。"
        ],
        tip: "顯示身分只存在這台裝置上，不會上傳到任何地方。",
        fig: "language",
        cap: "語言選單：六種語言即時切換"
      },
      {
        id: "faq",
        title: "常見問題",
        lead: "遇到狀況時先看這裡。",
        buttons: [],
        faq: [
          ["線上協同連不上怎麼辦？", "先確認兩台裝置在同一個 Wi-Fi。隊友的「協同伺服器位址」必須填房主畫面上顯示的 ws://…:9002，而不是預設的 127.0.0.1。iOS 首次連線會詢問區域網路權限，要選允許。"],
          ["筆記會不會不見？", "每一筆都即時寫入本機檔案。同步檔案只新增不修改，每台裝置只寫自己的檔案，所以不會互相覆蓋。"],
          ["需要註冊帳號嗎？", "不需要。Kairumo 沒有帳號系統，也沒有後端伺服器。"],
          ["手寫可以轉成文字嗎？", "可以。使用系統內建的裝置端辨識，不會把筆跡送上網。"],
          ["怎麼回報問題？", "請附上 Mac 視窗左上角顯示的版本號（例如 Kairumo v2.4.1）與操作步驟。"]
        ],
        fig: null
      }
    ]
  },

  "en": {
    name: "English",
    figset: "en",
    ui: {
      docTitle: "Kairumo User Manual",
      tagline: "Handwriting, typing and audio in one notebook. Step by step, from zero.",
      version: "For version 2.4.1 (bundle 17) · 13 September 2026",
      tocTitle: "Contents",
      tocHint: "Tap any entry to jump straight to it",
      stepsLabel: "Steps",
      tipLabel: "Good to know",
      buttonsLabel: "Buttons you'll use",
      figNote: "Screenshots show the English interface (iPad)",
      backToTop: "Back to contents",
      langLabel: "Language",
      privacyLink: "Privacy Policy"
    },
    sections: [
      {
        id: "start",
        title: "Before you start",
        lead: "Kairumo is a notebook that puts handwriting, typing and audio on one shared timeline. Free, open source, and your notes stay on your own device.",
        buttons: [],
        steps: [
          "Works on iPad, iPhone and Mac. Apple Pencil feels best, but a finger or a mouse works too.",
          "No account and no internet connection are needed to start.",
          "Everything you write is stored on this device. To back it up, keep the folder in your own iCloud or Google Drive.",
          "On Mac the window title shows the version (for example Kairumo v2.4.1) — include it when you report a problem."
        ],
        tip: "No server and no account means there is no password to forget — and no cloud copy if you lose the device, so make your own backup.",
        fig: null
      },
      {
        id: "home",
        title: "Home: your workbench",
        lead: "The first screen you see. Every note, recording and asset starts here.",
        buttons: ["Edit Identity", "New Note", "Start Recording", "Asset Library"],
        steps: [
          "At the top is your display identity — the name teammates see while collaborating. Tap “Edit Identity” to change it.",
          "The search field searches note titles, typed text and transcribed speech at the same time.",
          "The three large cards are the main actions: New Note, Start Recording, Asset Library.",
          "“Continue” lists the notes you opened recently; one tap returns you to where you left off.",
          "“All Notebooks” groups everything by folder; the control on the right changes the sort order."
        ],
        tip: "The “⋯” on each note card holds Rename, Move to folder and Delete.",
        fig: "home",
        cap: "Home: identity, search, three main actions, Continue, All Notebooks"
      },
      {
        id: "newnote",
        title: "Create your first note",
        lead: "Four paper templates, from blank paper to Cornell notes.",
        buttons: ["New Note", "OK"],
        steps: [
          "On Home, tap “New Note”.",
          "Type a name in “Notebook Title”. You can leave it empty and rename it later.",
          "Pick a theme, then choose the paper: Blank Paper, Grid & Dots, Ruled Lines or Cornell Notes.",
          "Tap “OK”. The note opens right away, ready to write on."
        ],
        tip: "Picking the wrong template is harmless — the paper is only a background and changing it never touches your content.",
        fig: "newnote",
        cap: "New Notebook sheet: title, theme and the four paper templates"
      },
      {
        id: "editor",
        title: "The editor at a glance",
        lead: "One minute here saves you looking for buttons later.",
        buttons: ["Home", "Structure", "Handwriting", "Typing"],
        steps: [
          "Top row, left to right: Home, note structure, handwriting/typing switch, title, page number, ruler, Asset Library, Insert, Comment Pins, Collaborate, Record, Export & Print.",
          "The second row is the toolbar for the current mode: brushes and colours for handwriting, text formatting for typing.",
          "The left column is the structure panel, switching between Pages and Folders.",
          "The middle is the canvas. At the bottom right you can add the next page or extend this page downwards by 800 pt.",
          "When the window gets narrow the toolbars wrap onto more rows — no button is ever pushed off screen."
        ],
        tip: "Short on width? Tap “Structure” to collapse the left column and the canvas widens immediately.",
        fig: "editor",
        cap: "The editor: top bar, handwriting toolbar, structure panel and canvas"
      },
      {
        id: "write",
        title: "Handwriting",
        lead: "Seven pens, four thicknesses, any colour. Erase what's wrong, or lasso a whole passage and move it.",
        buttons: ["Fountain Pen", "Eraser", "Lasso", "Extend Page"],
        steps: [
          "Make sure the top bar is set to handwriting mode.",
          "Pick a pen: fountain pen, ballpoint, brush, marker, highlighter, pencil or watercolour.",
          "The four dots in the middle set thickness; the swatches set colour. The slider icon opens a full colour picker.",
          "Use the eraser to remove strokes. To move or copy a whole passage, circle it with the lasso first.",
          "Undo, redo and clear page sit at the right end of the toolbar.",
          "Running out of paper? “Extend Page” grows this page by 800 pt."
        ],
        tip: "With Apple Pencil you can rest your palm on the screen — palm rejection ignores it and follows only the tip.",
        fig: "editor",
        cap: "Handwriting toolbar: brushes, thickness, colours, Extend Page and More"
      },
      {
        id: "type",
        title: "Typing",
        lead: "Drop a text box anywhere on the canvas and mix it with handwriting.",
        buttons: ["Typing", "Text Studio", "Special Symbols", "Insert Link"],
        steps: [
          "Tap the keyboard icon in the top bar to switch to typing mode.",
          "Tap anywhere on the canvas — a text box appears there and the keyboard opens.",
          "“Text Studio” sets size, bold, italic, underline, alignment and colour.",
          "“Special Symbols” inserts maths and common symbols; “Insert Link” turns a pasted URL into a tappable preview card.",
          "Drag a text box to move it; drag the handle at its bottom-right corner to resize it."
        ],
        tip: "In typing mode the canvas only accepts Apple Pencil strokes, so a finger swipe scrolls instead of drawing a stray line.",
        fig: "typing",
        cap: "Typing toolbar: Text Studio, Special Symbols, Insert Link, More, Extend Page"
      },
      {
        id: "pages",
        title: "Pages and folders",
        lead: "A note can hold many pages; many notes can live in a folder.",
        buttons: ["Structure", "Pages", "Folders", "Add Page"],
        steps: [
          "Tap “Structure” in the top bar to open or close the left column.",
          "“Pages” shows a thumbnail of every page in this note; tap one to jump to it.",
          "The “⋯” next to a page inserts a page after it, duplicates it, deletes it or extends it.",
          "“Folders” lists every folder and note. You can add subfolders, rename them and move notes between them.",
          "Tapping another note in Folders switches to it in the same window — no need to go back Home."
        ],
        tip: "Thumbnails are drawn at the same proportions as the canvas, so they work as a real full-page preview.",
        fig: "folders",
        cap: "The Folders tab: root folder, subfolders and the note list"
      },
      {
        id: "insert",
        title: "Images, assets and charts",
        lead: "Photos, engineering assets, equations, charts and 3D models all go on the canvas.",
        buttons: ["Insert", "Insert Image", "Asset Library", "Math Calculator"],
        steps: [
          "Tap “Insert” in the top bar. On a narrow window these items move into the “⋯” menu.",
          "“Insert Image” picks a photo from your library; once placed you can drag, resize, round its corners and add a border.",
          "“Asset Library” holds real-world specification assets — mechanical parts, electronics, vehicles, furniture — to download and place.",
          "“Math Calculator” and “Chart Studio” turn an equation or a chart into a card on the page.",
          "“Insert 3D Model” places a model you can rotate a full 360°."
        ],
        tip: "Asset files are downloaded to this device. Delete them from the library to free space — assets already on a page are unaffected.",
        fig: "insertmenu",
        cap: "Insert menu: Asset Library, Insert Image, Math Calculator, 3D Model, Comment Pin, Collaborate",
        fig2: "assetlib",
        cap2: "Asset Library: browse by category, tap Download, then place it"
      },
      {
        id: "comment",
        title: "Comment pins",
        lead: "Pin a note to an exact spot on the canvas — for yourself or for the people you're working with.",
        buttons: ["Add Comment Pin", "Resolved"],
        steps: [
          "Tap “Insert → Add Comment Pin”.",
          "Tap the spot you want to discuss. The pin lands there and its thread opens.",
          "Type in the field at the bottom and tap the arrow to post a message.",
          "If the dialog covers what you're discussing, drag it aside by the “≡” handle on its left.",
          "“−” shrinks it to a single title bar — still draggable. “✕” closes it.",
          "When the discussion is settled, tap “Resolved” and the pin turns grey with a checkmark."
        ],
        tip: "Pins travel with the note when you export or sync, and everyone in a collaboration session sees the same set.",
        fig: "comment",
        cap: "Comment thread: drag handle, Resolved, delete, minimise and close",
        fig2: "pin_min",
        cap2: "Minimised to a title bar — and still draggable"
      },
      {
        id: "collab",
        title: "Real-time collaboration",
        lead: "Write together over the same Wi-Fi. There is no cloud server — the device that starts the session is the relay.",
        buttons: ["Collaborate", "Start Collaboration", "Copy Encrypted Invite Link", "End Collaboration"],
        steps: [
          "Tap “Collaborate” in the top bar.",
          "One person taps “Start Collaboration”. That device hosts the relay itself; nothing external is needed.",
          "A Room ID appears. Tap “Copy Encrypted Invite Link” and send it to the others.",
          "Each teammate opens the same screen, pastes the room ID or link under “Join Room”, and joins.",
          "If a teammate is on another device, have them open “Relay Server Address” and enter the local-network address shown on the host's screen (ws://…:9002).",
          "The host ends the session with “End Collaboration”."
        ],
        tip: "Content is end-to-end encrypted with AES-256-GCM; the relay only forwards ciphertext it cannot read. Edits made while offline are queued and sent automatically once the connection returns.",
        fig: "collab",
        cap: "Not connected: Start Collaboration, Join Room, Relay Server Address",
        fig2: "collab_on",
        cap2: "Connected: room ID, end-to-end encryption, relay hosted on this device, participants"
      },
      {
        id: "record",
        title: "Recording and transcription",
        lead: "Audio and ink share one timeline — tap a word and jump to the stroke you wrote at that moment.",
        buttons: ["Start Recording", "Recent Recordings & Transcripts"],
        steps: [
          "Tap “Start Recording” on Home, or the microphone in a note's top bar.",
          "The first time, iOS asks for microphone permission — allow it.",
          "While recording, a live waveform appears at the top and anything you write is aligned to the audio.",
          "When you stop, the recording appears under “Recent Recordings & Transcripts” on Home.",
          "During playback, tap a line of transcript to jump to the ink written at that time — and the other way round."
        ],
        tip: "Recording and transcription both run on this device. Nothing is uploaded.",
        fig: "home",
        cap: "“Start Recording” and “Recent Recordings & Transcripts” on Home"
      },
      {
        id: "export",
        title: "Export, print and share",
        lead: "Four outputs — pick the one the other side needs.",
        buttons: ["Export & Print", "Export PDF", "Export Image", "Print Notebook", "Share Note"],
        steps: [
          "Tap “Export & Print” at the top right.",
          "“Export PDF” turns the whole notebook into a PDF to send or archive.",
          "“Export Image” saves the current page as an image file.",
          "“Print Notebook” hands the note to the system print dialog.",
          "“Share Note” sends the original .padnote file, which another Kairumo user can keep editing."
        ],
        tip: "Annotation coordinates in the PDF match the original, so they stay in place in other apps too.",
        fig: "export",
        cap: "Export & Print menu: Export PDF, Export Image, Print Notebook, Share Note"
      },
      {
        id: "language",
        title: "Language and identity",
        lead: "Six interface languages, switched instantly.",
        buttons: ["Language", "Edit Identity"],
        steps: [
          "Tap the language button at the top right of Home.",
          "Choose 繁體中文, English, 简体中文, 日本語, 한국어 or ไทย.",
          "The interface changes immediately — no restart needed.",
          "Back on Home, “Edit Identity” changes the name and colour teammates see while collaborating."
        ],
        tip: "Your display identity is stored on this device only and is never uploaded.",
        fig: "language",
        cap: "Language menu: six languages, switched live"
      },
      {
        id: "faq",
        title: "Troubleshooting",
        lead: "Check here first.",
        buttons: [],
        faq: [
          ["Collaboration won't connect", "Make sure both devices are on the same Wi-Fi. The guest's “Relay Server Address” must be the ws://…:9002 address shown on the host's screen, not the default 127.0.0.1. On the first connection iOS asks for local network permission — allow it."],
          ["Can my notes get lost?", "Every stroke is written to a local file as you go. Sync files are append-only and each device only ever writes its own file, so nothing overwrites anything."],
          ["Do I need an account?", "No. Kairumo has no accounts and no backend server."],
          ["Can handwriting become text?", "Yes, using the on-device recognition built into the system. Your ink never leaves the device."],
          ["How do I report a problem?", "Include the version shown in the Mac window title (for example Kairumo v2.4.1) and the steps you took."]
        ],
        fig: null
      }
    ]
  },

  "zh-Hans": {
    name: "简体中文",
    figset: "zh",
    ui: {
      docTitle: "Kairumo 操作手册",
      tagline: "手写、打字、录音三合一的笔记本。零基础也能一步一步跟着做。",
      version: "适用版本 v2.4.1（bundle 17）· 2026 年 9 月 13 日",
      tocTitle: "目录",
      tocHint: "点任一项目直接跳到该段落",
      stepsLabel: "操作步骤",
      tipLabel: "小提示",
      buttonsLabel: "会用到的按钮",
      figNote: "截图为繁体中文界面（iPad）",
      backToTop: "回到目录",
      langLabel: "语言",
      privacyLink: "隐私政策"
    },
    sections: [
      { id: "start", title: "开始之前", lead: "Kairumo 是一本把手写、打字与录音放在同一条时间轴上的笔记本。完全免费、开放源代码，数据留在你自己的设备上。", buttons: [], steps: ["支持 iPad、iPhone 与 Mac；手写用 Apple Pencil 最顺手，用手指或鼠标同样可以写。", "第一次打开不需要注册账号，也不需要联网。", "你写下的每一笔都存在这台设备里。要备份就把文件夹放进自己的 iCloud 或 Google Drive。", "Mac 版窗口左上角会显示版本号（例如 Kairumo v2.4.1），反馈问题时请附上它。"], tip: "没有服务器、没有账号，就没有“忘记密码”这回事 —— 但也意味着设备丢失时没有云端副本，请自己做备份。", fig: null },
      { id: "home", title: "首页：你的工作台", lead: "打开 App 看到的第一个画面。所有笔记、录音与素材都从这里进入。", buttons: ["编辑身份", "新增笔记", "开始录音", "素材图库"], steps: ["最上方是你的显示身份 —— 协作时队友看到的就是这个名字，点右边的“编辑身份”可以修改。", "搜索栏可以同时搜索笔记标题、打字内容与录音转写出来的文字。", "中间三张大卡片是主要操作：新增笔记、开始录音、素材图库。", "“继续”列出最近打开过的笔记，点一下就回到上次的位置。", "“全部笔记”按文件夹分类显示；右上角可以切换排序方式。"], tip: "每张笔记卡片右上角的“⋯”里有重命名、移动到文件夹与删除。", fig: "home", cap: "首页：身份、搜索、三个主要操作、继续、全部笔记" },
      { id: "newnote", title: "创建第一则笔记", lead: "从空白纸张到康奈尔笔记，四种纸张模板任选。", buttons: ["新增笔记", "确认"], steps: ["在首页点“新增笔记”。", "在“笔记标题”栏输入名称。不填也可以，之后随时能改。", "先选主题分类，再从下方选纸张模板：空白纸张、方格点阵、横线笔记、康奈尔笔记。", "点右上角“确认”，笔记会立刻打开，可以直接开始写。"], tip: "选错模板不用重来 —— 纸张只是背景，换掉不会影响已经写下的内容。", fig: "newnote", cap: "新增笔记本窗口：标题、主题分类与四种纸张模板" },
      { id: "editor", title: "认识编辑界面", lead: "先花一分钟认位置，后面每一步都会用到。", buttons: ["首页", "笔记结构", "手绘模式", "打字模式"], steps: ["最上排从左到右：回首页、笔记结构、手绘／打字切换、笔记标题、页码、标尺、素材图库、插入、讨论图钉、在线协作、录音、导出与打印。", "第二排是当前模式的工具栏：手绘模式显示笔刷与颜色，打字模式显示文字排版。", "左侧是结构栏，可切换“页面结构”与“文件夹目录”。", "中间是画布。右下角可以“新增下一页”，或把这一页“向下延长（+800pt）”。", "窗口变窄时工具栏会自动换行，不会有按钮被挤到画面外。"], tip: "屏幕不够宽时，点“笔记结构”把左栏收起来，画布立刻变宽。", fig: "editor", cap: "编辑界面：上排主工具栏、手绘工具栏、左侧结构栏与画布" },
      { id: "write", title: "手写", lead: "七种笔、四挡粗细、可自定义颜色。写错可以擦，也可以整段圈起来搬家。", buttons: ["钢笔", "橡皮擦", "套索选取", "延长此页"], steps: ["确认上排停在“手绘模式”。", "从工具栏挑一支笔：钢笔、圆珠笔、毛笔、马克笔、荧光笔、铅笔、水彩笔。", "工具栏中间的四颗圆点选粗细，右边的色盘选颜色；点色盘旁的滑杆图标可自定义任何颜色。", "写错时选“橡皮擦”擦掉；想搬动或复制一整段笔迹，用“套索选取”圈起来再操作。", "最右边是撤销、重做与清除本页。", "纸不够用就点“延长此页”，这一页会往下长 800pt。"], tip: "用 Apple Pencil 书写时可以直接把手掌放在屏幕上 —— 掌拒会忽略手掌，只认笔尖。", fig: "editor", cap: "手绘工具栏：笔刷、粗细、色盘、延长此页与更多" },
      { id: "type", title: "打字", lead: "在画布上任何位置放文本框，和手写混排。", buttons: ["打字模式", "文字排版", "特殊符号", "插入链接"], steps: ["点上排的键盘图标，切换到“打字模式”。", "在画布上任何一处点一下，该位置就会出现文本框并弹出键盘。", "点“文字排版”可以调字号、粗体、斜体、下划线、对齐与文字颜色。", "“特殊符号”可插入数学与常用符号；“插入链接”粘贴网址后会变成可点击的预览卡片。", "文本框可以直接拖动，拖右下角的把手可以改变大小。"], tip: "打字模式下画布只认 Apple Pencil，手指滑动会当成滚动 —— 不会误画出线条。", fig: "typing", cap: "打字模式工具栏：文字排版、特殊符号、插入链接、更多、延长此页" },
      { id: "pages", title: "页面与文件夹", lead: "一则笔记可以有很多页；很多则笔记可以放进文件夹。", buttons: ["笔记结构", "页面结构", "文件夹目录", "新增页面"], steps: ["点上排“笔记结构”开关左栏。", "“页面结构”列出这则笔记每一页的缩略图，点缩略图就跳到那一页。", "每页标题右边的“⋯”可以在后面插入新页、复制该页、删除该页或延长该页。", "切到“文件夹目录”可以看到所有文件夹与笔记；可新增子文件夹、重命名、把笔记移到别的文件夹。", "在文件夹目录直接点另一则笔记，就会在同一个窗口切换过去，不用先回首页。"], tip: "缩略图与画布等比例、位置一致，可以直接当成整页预览使用。", fig: "folders", cap: "左侧结构栏的“文件夹目录”：根文件夹、子文件夹与笔记列表" },
      { id: "insert", title: "插入图片、素材与图表", lead: "照片、实体规格素材、算式、图表与 3D 模型都能放进画布。", buttons: ["插入", "插入图片", "素材图库", "算式计算"], steps: ["点上排“插入”。窗口较窄时，这些项目会收在“⋯”菜单里。", "“插入图片”从相册挑一张照片；插入后可拖动、缩放、加圆角与边框。", "“素材图库”内含机械、3C、汽摩、家具等实体规格素材，下载后即可插入画布。", "“算式计算”与“数字制图”可以把算式或图表变成卡片放进笔记。", "“插入 3D 模型”放进可 360° 旋转的立体模型。"], tip: "素材图库的文件下载在本机，可以在图库里删除以释放空间；已插入画布的图不会受影响。", fig: "insertmenu", cap: "插入菜单：素材图库、插入图片、算式计算、3D 模型、讨论图钉与在线协作", fig2: "assetlib", cap2: "素材图库：按分类浏览，点“下载”后即可插入" },
      { id: "comment", title: "讨论图钉", lead: "把留言钉在画布的特定位置上，自己备忘或跟队友讨论都适用。", buttons: ["新增讨论图钉", "标记为已解决"], steps: ["点“插入 → 新增讨论图钉”。", "在画布上想讨论的位置点一下，图钉就钉在那里，对话框会跟着打开。", "在下方输入框打字，按右边的箭头发送，就成为一条留言。", "对话框挡到内容时，按住最左边的“≡”握把把它拖到旁边。", "按“−”可以缩小成一条标题栏（缩小后一样可以拖动）；按“✕”关闭。", "讨论完成后按“标记为已解决”，图钉会变成灰色打勾。"], tip: "图钉会跟着笔记一起导出与同步；协作时所有人都看得到同一批图钉。", fig: "comment", cap: "讨论图钉对话框：拖动握把、已解决、删除、缩小与关闭", fig2: "pin_min", cap2: "缩小后的精简标题栏 —— 仍然可以拖动" },
      { id: "collab", title: "在线协作", lead: "同一个 Wi-Fi 下多人实时共笔。没有云端服务器 —— 发起的那台设备自己就是中继点。", buttons: ["在线协作", "开始多人协作", "复制加密邀请链接", "结束协作会议"], steps: ["点上排“在线协作”。", "由其中一人按“开始多人协作”。这台设备会自己担任中继服务，不需要任何外部服务器。", "画面会显示“房间标识码”。按“复制加密邀请链接”把链接发给队友。", "队友打开同一个画面，在“加入协作房间”粘贴房号或链接，按加入。", "若队友是另一台设备，请他们展开“协作服务器地址”，改填房主画面上显示的局域网地址（ws://…:9002）。", "结束时由房主按“结束协作会议”。"], tip: "内容以 AES-256-GCM 端到端加密传送，中继点只转发看不懂的密文。离线期间的操作会先暂存，连接恢复后自动补发。", fig: "collab", cap: "尚未连接：开始多人协作、加入协作房间、协作服务器地址", fig2: "collab_on", cap2: "已连接：房间标识码、端到端加密、本机正在提供中继、在线参与者" },
      { id: "record", title: "录音与转写", lead: "录音与笔迹走同一条时间轴 —— 点文字就能跳回当时写下的那一笔。", buttons: ["开始录音", "最近录音与转写"], steps: ["在首页点“开始录音”，或在笔记里点上排的麦克风图标。", "第一次使用会询问麦克风权限，请选择允许。", "录音中画面上方会显示实时波形；此时写下的笔迹会自动与声音对齐。", "停止后，该段录音会出现在首页的“最近录音与转写”。", "播放时点某一段转写文字，画面会跳到当时写下的笔迹；反过来点笔迹也可以跳到对应的声音。"], tip: "录音与中文转写都在这台设备上完成，不会上传到任何服务器。", fig: "home", cap: "首页的“开始录音”与“最近录音与转写”" },
      { id: "export", title: "导出、打印与分享", lead: "四种输出方式，按对方需要选一种。", buttons: ["导出与打印", "导出 PDF", "导出为图片", "打印笔记", "分享笔记"], steps: ["点右上角的“导出与打印”。", "“导出 PDF”把整本笔记转成 PDF，适合发给别人或存档。", "“导出为图片”输出当前这一页的图片文件。", "“打印笔记”走系统打印流程。", "“分享笔记”发出 .padnote 原始文件，对方用 Kairumo 打开可以继续编辑。"], tip: "PDF 内的批注坐标与原稿一致，用其他 App 打开也不会跑位。", fig: "export", cap: "导出与打印菜单：导出 PDF、导出为图片、打印笔记、分享笔记" },
      { id: "language", title: "语言与显示身份", lead: "界面支持六种语言，随时切换、立即生效。", buttons: ["语言", "编辑身份"], steps: ["在首页右上角点语言按钮。", "从列表中选择：繁體中文、English、简体中文、日本語、한국어、ไทย。", "界面会立刻切换，不需要重启 App。", "回到首页上方点“编辑身份”，可以修改协作时显示的名字与代表色。"], tip: "显示身份只存在这台设备上，不会上传到任何地方。", fig: "language", cap: "语言菜单：六种语言即时切换" },
      { id: "faq", title: "常见问题", lead: "遇到状况时先看这里。", buttons: [], faq: [["在线协作连不上怎么办？", "先确认两台设备在同一个 Wi-Fi。队友的“协作服务器地址”必须填房主画面上显示的 ws://…:9002，而不是默认的 127.0.0.1。iOS 首次连接会询问局域网权限，要选允许。"], ["笔记会不会丢失？", "每一笔都实时写入本机文件。同步文件只新增不修改，每台设备只写自己的文件，所以不会互相覆盖。"], ["需要注册账号吗？", "不需要。Kairumo 没有账号系统，也没有后端服务器。"], ["手写可以转成文字吗？", "可以。使用系统内置的设备端识别，不会把笔迹传上网。"], ["怎么反馈问题？", "请附上 Mac 窗口左上角显示的版本号（例如 Kairumo v2.4.1）与操作步骤。"]], fig: null }
    ]
  },

  "ja": {
    name: "日本語",
    figset: "en",
    ui: {
      docTitle: "Kairumo 操作マニュアル",
      tagline: "手書き・タイピング・録音をひとつにしたノート。はじめての方でも順番どおりに進められます。",
      version: "対象バージョン v2.4.1（bundle 17）· 2026年9月13日",
      tocTitle: "目次",
      tocHint: "項目をタップすると該当セクションへ移動します",
      stepsLabel: "手順",
      tipLabel: "ヒント",
      buttonsLabel: "使うボタン",
      figNote: "スクリーンショットは英語表示（iPad）です",
      backToTop: "目次へ戻る",
      langLabel: "言語",
      privacyLink: "プライバシーポリシー"
    },
    sections: [
      { id: "start", title: "はじめる前に", lead: "Kairumo は手書き・タイピング・録音を同じタイムライン上に置くノートです。完全無料、オープンソース、データは端末内に留まります。", buttons: [], steps: ["iPad・iPhone・Mac に対応。Apple Pencil が最適ですが、指やマウスでも書けます。", "アカウント登録もインターネット接続も不要です。", "書いた内容はこの端末に保存されます。バックアップはご自身の iCloud や Google Drive のフォルダへ。", "Mac ではウインドウのタイトルにバージョン（例：Kairumo v2.4.1）が表示されます。不具合報告の際は添えてください。"], tip: "サーバーもアカウントもないためパスワードを忘れる心配はありません。その代わりクラウド上の控えもないので、バックアップはご自身で。", fig: null },
      { id: "home", title: "ホーム：作業台", lead: "アプリを開いて最初に表示される画面です。ノート・録音・素材はすべてここから。", buttons: ["Edit Identity", "New Note", "Start Recording", "Asset Library"], steps: ["上部は表示名です。共同編集中に相手に見える名前で、「Edit Identity」から変更できます。", "検索欄はノートのタイトル・入力した文字・文字起こしをまとめて検索します。", "大きな3つのカードが主な操作です：新規ノート、録音開始、素材ライブラリ。", "「Continue」には最近開いたノートが並び、タップすると続きから再開します。", "「All Notebooks」はフォルダ別の一覧です。右上で並び順を変えられます。"], tip: "各ノートカード右上の「⋯」に、名前の変更・フォルダへ移動・削除があります。", fig: "home", cap: "ホーム：表示名、検索、3つの主要操作、Continue、All Notebooks" },
      { id: "newnote", title: "最初のノートを作る", lead: "白紙からコーネル式まで、4種類の用紙から選べます。", buttons: ["New Note", "OK"], steps: ["ホームで「New Note」をタップします。", "「Notebook Title」に名前を入力します。空欄のままでも後から変更できます。", "テーマを選び、続けて用紙を選びます：白紙、方眼・ドット、罫線、コーネル式。", "「OK」をタップするとノートがすぐ開きます。"], tip: "用紙は背景にすぎません。あとで変えても書いた内容には影響しません。", fig: "newnote", cap: "新規ノート画面：タイトル、テーマ、4種類の用紙" },
      { id: "editor", title: "編集画面の見取り図", lead: "最初に位置を覚えておくと、以降の操作が迷いません。", buttons: ["Home", "Structure", "Handwriting", "Typing"], steps: ["最上段は左から：ホーム、ノート構成、手書き／入力の切り替え、タイトル、ページ番号、定規、素材ライブラリ、挿入、コメントピン、共同編集、録音、書き出しと印刷。", "2段目は現在のモードのツールバーです（手書きならブラシと色、入力なら文字書式）。", "左側は構成パネルで、ページ一覧とフォルダ一覧を切り替えられます。", "中央がキャンバスです。右下から次のページを追加、またはこのページを 800pt 下へ延長できます。", "ウインドウが狭いとツールバーは自動で折り返し、ボタンが画面外に消えることはありません。"], tip: "幅が足りないときは「Structure」で左の列をたたむと、キャンバスが広がります。", fig: "editor", cap: "編集画面：上部ツールバー、手書きツールバー、構成パネル、キャンバス" },
      { id: "write", title: "手書き", lead: "7種類のペン、4段階の太さ、自由な色。消すことも、まとめて囲んで動かすこともできます。", buttons: ["Fountain Pen", "Eraser", "Lasso", "Extend Page"], steps: ["上部が手書きモードになっていることを確認します。", "ペンを選びます：万年筆、ボールペン、筆、マーカー、蛍光ペン、鉛筆、水彩。", "中央の4つの丸が太さ、右側が色です。スライダーのアイコンで自由に色を作れます。", "消すときは消しゴム。まとめて移動・複製するときは投げ縄で囲みます。", "右端に取り消し・やり直し・ページ消去があります。", "紙が足りなくなったら「Extend Page」で 800pt 下に伸ばせます。"], tip: "Apple Pencil なら手のひらを画面に置いたままで大丈夫です。パームリジェクションがペン先だけを拾います。", fig: "editor", cap: "手書きツールバー：ブラシ、太さ、色、ページ延長、その他" },
      { id: "type", title: "タイピング", lead: "キャンバスの好きな位置にテキストボックスを置き、手書きと混在させられます。", buttons: ["Typing", "Text Studio", "Special Symbols", "Insert Link"], steps: ["上部のキーボードアイコンで入力モードに切り替えます。", "キャンバスをタップすると、その位置にテキストボックスが現れてキーボードが開きます。", "「Text Studio」で文字サイズ・太字・斜体・下線・揃え・色を設定します。", "「Special Symbols」は数式や記号、「Insert Link」は貼り付けた URL をプレビューカードにします。", "テキストボックスはドラッグで移動、右下のハンドルでサイズ変更できます。"], tip: "入力モードではキャンバスは Apple Pencil のみを筆記として扱うため、指のスワイプは線にならずスクロールになります。", fig: "typing", cap: "入力モードのツールバー：Text Studio、記号、リンク挿入、その他、ページ延長" },
      { id: "pages", title: "ページとフォルダ", lead: "1つのノートに複数ページ、複数のノートを1つのフォルダに。", buttons: ["Structure", "Pages", "Folders", "Add Page"], steps: ["上部の「Structure」で左の列を開閉します。", "「Pages」には各ページのサムネイルが並び、タップでそのページへ移動します。", "ページ横の「⋯」から、後ろに挿入・複製・削除・延長ができます。", "「Folders」にはすべてのフォルダとノートが並びます。サブフォルダの作成、名前の変更、ノートの移動が可能です。", "「Folders」で別のノートをタップすると、同じウインドウのまま切り替わります。"], tip: "サムネイルはキャンバスと同じ比率で描かれるので、そのままページ全体のプレビューとして使えます。", fig: "folders", cap: "Folders タブ：ルートフォルダ、サブフォルダ、ノート一覧" },
      { id: "insert", title: "画像・素材・図表の挿入", lead: "写真、実物の仕様素材、数式、グラフ、3Dモデルをキャンバスに置けます。", buttons: ["Insert", "Insert Image", "Asset Library", "Math Calculator"], steps: ["上部の「Insert」をタップします。ウインドウが狭いときは「⋯」の中にまとまります。", "「Insert Image」で写真を選びます。配置後はドラッグ・拡大縮小・角丸・枠線が設定できます。", "「Asset Library」には機械、電子機器、車両、家具などの仕様素材があり、ダウンロードして配置できます。", "「Math Calculator」「Chart Studio」は数式やグラフをカードにしてページに置きます。", "「Insert 3D Model」は 360° 回転できる立体モデルを配置します。"], tip: "素材ファイルは端末にダウンロードされます。ライブラリから削除すれば容量を戻せます（配置済みの素材は影響を受けません）。", fig: "insertmenu", cap: "挿入メニュー：素材ライブラリ、画像、数式、3Dモデル、コメントピン、共同編集", fig2: "assetlib", cap2: "素材ライブラリ：カテゴリから探し、ダウンロードして配置" },
      { id: "comment", title: "コメントピン", lead: "キャンバスの特定の位置にコメントを留めます。自分用のメモにも、共同編集の議論にも。", buttons: ["Add Comment Pin", "Resolved"], steps: ["「Insert → Add Comment Pin」をタップします。", "話題にしたい位置をタップすると、そこにピンが立ちスレッドが開きます。", "下の入力欄に書いて矢印を押すと投稿されます。", "内容が隠れるときは、左端の「≡」ハンドルをつかんでダイアログを移動します。", "「−」でタイトルバーだけに縮小（縮小後もドラッグ可）、「✕」で閉じます。", "解決したら「Resolved」を押すと、ピンがグレーのチェックに変わります。"], tip: "ピンは書き出しや同期でもノートと一緒に移動し、共同編集中は全員が同じピンを見ます。", fig: "comment", cap: "コメントスレッド：ドラッグハンドル、解決、削除、縮小、閉じる", fig2: "pin_min", cap2: "タイトルバーに縮小した状態 —— そのままドラッグできます" },
      { id: "collab", title: "リアルタイム共同編集", lead: "同じ Wi-Fi 上で同時に書けます。クラウドサーバーはありません —— 開始した端末自身が中継役です。", buttons: ["Collaborate", "Start Collaboration", "Copy Encrypted Invite Link", "End Collaboration"], steps: ["上部の「Collaborate」をタップします。", "誰か1人が「Start Collaboration」を押します。その端末が中継を担当し、外部サーバーは不要です。", "ルームIDが表示されます。「Copy Encrypted Invite Link」でリンクをコピーして共有します。", "参加者は同じ画面の「Join Room」にIDまたはリンクを貼って参加します。", "別の端末から参加する場合は「Relay Server Address」を開き、ホスト画面に表示されたローカルネットワークのアドレス（ws://…:9002）を入力します。", "終了するときはホストが「End Collaboration」を押します。"], tip: "内容は AES-256-GCM でエンドツーエンド暗号化され、中継役は読めない暗号文を転送するだけです。オフライン中の編集は保留され、再接続時に自動送信されます。", fig: "collab", cap: "未接続：共同編集を開始、ルームに参加、中継サーバーのアドレス", fig2: "collab_on", cap2: "接続中：ルームID、暗号化、この端末が中継、参加者一覧" },
      { id: "record", title: "録音と文字起こし", lead: "音声と手書きは同じタイムライン上にあります。単語をタップすれば、その瞬間の筆跡へ移動します。", buttons: ["Start Recording", "Recent Recordings & Transcripts"], steps: ["ホームの「Start Recording」、またはノート上部のマイクをタップします。", "初回はマイクの許可を求められます。許可してください。", "録音中は上部に波形が表示され、書いた内容が音声と同期します。", "停止すると、ホームの「Recent Recordings & Transcripts」に追加されます。", "再生中に文字起こしの一行をタップすると、その時間に書いた筆跡へ移動します（逆方向も可能）。"], tip: "録音も文字起こしもこの端末の中で完結し、どこにもアップロードされません。", fig: "home", cap: "ホームの「Start Recording」と「Recent Recordings & Transcripts」" },
      { id: "export", title: "書き出し・印刷・共有", lead: "用途に合わせて4つの出力から選べます。", buttons: ["Export & Print", "Export PDF", "Export Image", "Print Notebook", "Share Note"], steps: ["右上の「Export & Print」をタップします。", "「Export PDF」はノート全体を PDF にします。", "「Export Image」は現在のページを画像として保存します。", "「Print Notebook」はシステムの印刷画面に渡します。", "「Share Note」は .padnote の原本を送ります。相手は Kairumo で編集を続けられます。"], tip: "PDF 内の注釈座標は原本と一致するため、他のアプリで開いてもずれません。", fig: "export", cap: "書き出しメニュー：PDF、画像、印刷、ノートを共有" },
      { id: "language", title: "言語と表示名", lead: "6言語に対応し、その場で切り替わります。", buttons: ["Language", "Edit Identity"], steps: ["ホーム右上の言語ボタンをタップします。", "繁體中文・English・简体中文・日本語・한국어・ไทย から選びます。", "再起動なしで表示が切り替わります。", "ホームの「Edit Identity」で、共同編集中に表示される名前と色を変更できます。"], tip: "表示名はこの端末にのみ保存され、送信されることはありません。", fig: "language", cap: "言語メニュー：6言語を即時切り替え" },
      { id: "faq", title: "困ったときは", lead: "まずここを確認してください。", buttons: [], faq: [["共同編集に接続できない", "両方の端末が同じ Wi-Fi にあるか確認します。参加側の「Relay Server Address」には、ホスト画面に表示された ws://…:9002 を入力します（既定の 127.0.0.1 ではありません）。初回接続時、iOS がローカルネットワークの許可を求めるので許可してください。"], ["ノートが消えることは？", "書いたそばからローカルファイルに保存されます。同期ファイルは追記のみで、各端末は自分のファイルしか書かないため上書きは起こりません。"], ["アカウントは必要？", "不要です。Kairumo にはアカウントもバックエンドサーバーもありません。"], ["手書きを文字にできますか？", "できます。端末内蔵の認識機能を使うため、筆跡が外部に出ることはありません。"], ["不具合はどう報告しますか？", "Mac のウインドウタイトルに表示されるバージョン（例：Kairumo v2.4.1）と、操作手順を添えてください。"]], fig: null }
    ]
  },

  "ko": {
    name: "한국어",
    figset: "en",
    ui: {
      docTitle: "Kairumo 사용 설명서",
      tagline: "손글씨·타이핑·녹음을 하나로 묶은 노트. 처음이어도 순서대로 따라 하면 됩니다.",
      version: "대상 버전 v2.4.1 (bundle 17) · 2026년 9월 13일",
      tocTitle: "목차",
      tocHint: "항목을 누르면 해당 섹션으로 이동합니다",
      stepsLabel: "따라 하기",
      tipLabel: "알아두기",
      buttonsLabel: "사용하는 버튼",
      figNote: "스크린샷은 영어 화면(iPad)입니다",
      backToTop: "목차로",
      langLabel: "언어",
      privacyLink: "개인정보 처리방침"
    },
    sections: [
      { id: "start", title: "시작하기 전에", lead: "Kairumo는 손글씨·타이핑·녹음을 하나의 타임라인에 올려 두는 노트입니다. 무료이며 오픈 소스이고, 데이터는 기기에 남습니다.", buttons: [], steps: ["iPad, iPhone, Mac에서 사용할 수 있습니다. Apple Pencil이 가장 자연스럽지만 손가락이나 마우스로도 됩니다.", "계정 가입도, 인터넷 연결도 필요 없습니다.", "작성한 내용은 이 기기에 저장됩니다. 백업하려면 폴더를 본인의 iCloud나 Google Drive에 두세요.", "Mac에서는 창 제목에 버전(예: Kairumo v2.4.1)이 표시됩니다. 문제를 알릴 때 함께 적어 주세요."], tip: "서버도 계정도 없으므로 비밀번호를 잊을 일이 없습니다. 대신 클라우드 사본도 없으니 백업은 직접 해 두세요.", fig: null },
      { id: "home", title: "홈: 작업대", lead: "앱을 열면 처음 보이는 화면입니다. 노트·녹음·에셋이 모두 여기에서 시작됩니다.", buttons: ["Edit Identity", "New Note", "Start Recording", "Asset Library"], steps: ["맨 위는 표시 이름입니다. 협업 중 상대에게 보이는 이름이며 “Edit Identity”에서 바꿀 수 있습니다.", "검색창은 노트 제목, 입력한 글자, 녹음 전사 결과를 함께 찾습니다.", "가운데 큰 카드 세 개가 주요 동작입니다: 새 노트, 녹음 시작, 에셋 라이브러리.", "“Continue”에는 최근 연 노트가 있고, 누르면 이어서 작업합니다.", "“All Notebooks”는 폴더별 목록이며, 오른쪽에서 정렬 방식을 바꿉니다."], tip: "각 노트 카드 오른쪽 위 “⋯”에 이름 변경·폴더로 이동·삭제가 있습니다.", fig: "home", cap: "홈: 표시 이름, 검색, 주요 동작 3개, Continue, All Notebooks" },
      { id: "newnote", title: "첫 노트 만들기", lead: "빈 종이부터 코넬 노트까지 네 가지 서식을 고를 수 있습니다.", buttons: ["New Note", "OK"], steps: ["홈에서 “New Note”를 누릅니다.", "“Notebook Title”에 이름을 입력합니다. 비워 두고 나중에 바꿔도 됩니다.", "테마를 고른 뒤 종이 서식을 선택합니다: 빈 종이, 모눈·점, 줄노트, 코넬 노트.", "“OK”를 누르면 노트가 바로 열립니다."], tip: "서식은 배경일 뿐이라 나중에 바꿔도 이미 쓴 내용에는 영향이 없습니다.", fig: "newnote", cap: "새 노트 화면: 제목, 테마, 네 가지 종이 서식" },
      { id: "editor", title: "편집 화면 살펴보기", lead: "위치를 한 번 익혀 두면 이후가 편합니다.", buttons: ["Home", "Structure", "Handwriting", "Typing"], steps: ["맨 윗줄은 왼쪽부터: 홈, 노트 구조, 손글씨/타이핑 전환, 제목, 페이지 번호, 자, 에셋 라이브러리, 삽입, 댓글 핀, 협업, 녹음, 내보내기·인쇄.", "둘째 줄은 현재 모드의 도구 모음입니다(손글씨는 펜과 색, 타이핑은 문자 서식).", "왼쪽은 구조 패널이며 페이지 목록과 폴더 목록을 전환합니다.", "가운데가 캔버스입니다. 오른쪽 아래에서 다음 페이지를 추가하거나 이 페이지를 800pt 아래로 늘립니다.", "창이 좁아지면 도구 모음이 자동으로 줄바꿈되어 버튼이 화면 밖으로 밀리지 않습니다."], tip: "폭이 부족하면 “Structure”로 왼쪽 열을 접으세요. 캔버스가 바로 넓어집니다.", fig: "editor", cap: "편집 화면: 상단 바, 손글씨 도구 모음, 구조 패널, 캔버스" },
      { id: "write", title: "손글씨", lead: "펜 7종, 굵기 4단계, 원하는 색. 지우거나, 올가미로 묶어 통째로 옮길 수 있습니다.", buttons: ["Fountain Pen", "Eraser", "Lasso", "Extend Page"], steps: ["상단이 손글씨 모드인지 확인합니다.", "펜을 고릅니다: 만년필, 볼펜, 붓, 마커, 형광펜, 연필, 수채.", "가운데 점 네 개가 굵기, 오른쪽이 색입니다. 슬라이더 아이콘으로 색을 직접 만들 수 있습니다.", "잘못 쓴 부분은 지우개로 지웁니다. 한 덩어리를 옮기거나 복사하려면 올가미로 감싸세요.", "오른쪽 끝에 실행 취소·다시 실행·페이지 지우기가 있습니다.", "종이가 모자라면 “Extend Page”로 800pt 늘립니다."], tip: "Apple Pencil을 쓰면 손바닥을 화면에 올려도 됩니다. 팜 리젝션이 펜 끝만 인식합니다.", fig: "editor", cap: "손글씨 도구 모음: 펜, 굵기, 색, 페이지 늘리기, 더 보기" },
      { id: "type", title: "타이핑", lead: "캔버스 어디에나 텍스트 상자를 놓고 손글씨와 섞어 쓸 수 있습니다.", buttons: ["Typing", "Text Studio", "Special Symbols", "Insert Link"], steps: ["상단의 키보드 아이콘으로 타이핑 모드로 전환합니다.", "캔버스를 누르면 그 자리에 텍스트 상자가 생기고 키보드가 열립니다.", "“Text Studio”에서 크기·굵게·기울임·밑줄·정렬·색을 정합니다.", "“Special Symbols”는 수식과 기호를, “Insert Link”는 붙여넣은 주소를 미리보기 카드로 만듭니다.", "텍스트 상자는 끌어서 옮기고, 오른쪽 아래 손잡이로 크기를 바꿉니다."], tip: "타이핑 모드에서 캔버스는 Apple Pencil만 필기로 인식하므로 손가락 스와이프는 선이 아니라 스크롤이 됩니다.", fig: "typing", cap: "타이핑 도구 모음: Text Studio, 기호, 링크 삽입, 더 보기, 페이지 늘리기" },
      { id: "pages", title: "페이지와 폴더", lead: "노트 하나에 여러 페이지를, 폴더 하나에 여러 노트를 담습니다.", buttons: ["Structure", "Pages", "Folders", "Add Page"], steps: ["상단 “Structure”로 왼쪽 열을 열고 닫습니다.", "“Pages”에는 페이지 축소판이 나열되며, 누르면 그 페이지로 이동합니다.", "페이지 옆 “⋯”에서 뒤에 삽입·복제·삭제·늘리기를 할 수 있습니다.", "“Folders”에는 모든 폴더와 노트가 있습니다. 하위 폴더 추가, 이름 변경, 노트 이동이 가능합니다.", "“Folders”에서 다른 노트를 누르면 같은 창에서 바로 전환됩니다."], tip: "축소판은 캔버스와 같은 비율로 그려지므로 전체 페이지 미리보기로 그대로 쓸 수 있습니다.", fig: "folders", cap: "Folders 탭: 루트 폴더, 하위 폴더, 노트 목록" },
      { id: "insert", title: "이미지·에셋·차트 넣기", lead: "사진, 실물 규격 에셋, 수식, 차트, 3D 모델을 캔버스에 놓을 수 있습니다.", buttons: ["Insert", "Insert Image", "Asset Library", "Math Calculator"], steps: ["상단 “Insert”를 누릅니다. 창이 좁으면 “⋯” 메뉴 안에 들어갑니다.", "“Insert Image”로 사진을 고릅니다. 배치 후 이동·크기 조절·모서리 둥글게·테두리가 가능합니다.", "“Asset Library”에는 기계, 전자, 차량, 가구 등 실물 규격 에셋이 있어 내려받아 배치합니다.", "“Math Calculator”와 “Chart Studio”는 수식이나 차트를 카드로 만들어 페이지에 놓습니다.", "“Insert 3D Model”은 360° 회전하는 모델을 배치합니다."], tip: "에셋 파일은 기기에 저장됩니다. 라이브러리에서 지우면 용량이 확보되며, 이미 배치한 에셋은 그대로 남습니다.", fig: "insertmenu", cap: "삽입 메뉴: 에셋 라이브러리, 이미지, 수식, 3D 모델, 댓글 핀, 협업", fig2: "assetlib", cap2: "에셋 라이브러리: 분류에서 찾아 내려받고 배치" },
      { id: "comment", title: "댓글 핀", lead: "캔버스의 특정 위치에 메모를 고정합니다. 혼자 쓰는 메모에도, 함께 하는 논의에도 좋습니다.", buttons: ["Add Comment Pin", "Resolved"], steps: ["“Insert → Add Comment Pin”을 누릅니다.", "이야기할 위치를 누르면 그 자리에 핀이 꽂히고 스레드가 열립니다.", "아래 입력란에 쓰고 화살표를 누르면 글이 등록됩니다.", "대화창이 내용을 가리면 왼쪽 “≡” 손잡이를 잡고 옆으로 옮기세요.", "“−”를 누르면 제목 줄만 남게 축소되고(축소 후에도 끌 수 있습니다), “✕”로 닫습니다.", "정리되면 “Resolved”를 눌러 핀을 회색 체크로 바꿉니다."], tip: "핀은 내보내기와 동기화 때 노트와 함께 이동하며, 협업 중에는 모두가 같은 핀을 봅니다.", fig: "comment", cap: "댓글 스레드: 끌기 손잡이, 해결, 삭제, 축소, 닫기", fig2: "pin_min", cap2: "제목 줄로 축소한 상태 —— 그대로 끌 수 있습니다" },
      { id: "collab", title: "실시간 협업", lead: "같은 Wi-Fi에서 함께 필기합니다. 클라우드 서버는 없습니다 —— 세션을 시작한 기기가 곧 중계기입니다.", buttons: ["Collaborate", "Start Collaboration", "Copy Encrypted Invite Link", "End Collaboration"], steps: ["상단 “Collaborate”를 누릅니다.", "한 사람이 “Start Collaboration”을 누릅니다. 그 기기가 직접 중계를 맡으며 외부 서버는 필요 없습니다.", "룸 ID가 표시됩니다. “Copy Encrypted Invite Link”로 링크를 복사해 전달하세요.", "참여자는 같은 화면의 “Join Room”에 ID나 링크를 붙여 넣고 참여합니다.", "다른 기기에서 참여한다면 “Relay Server Address”를 열어, 호스트 화면에 표시된 로컬 네트워크 주소(ws://…:9002)를 입력합니다.", "끝낼 때는 호스트가 “End Collaboration”을 누릅니다."], tip: "내용은 AES-256-GCM으로 종단 간 암호화되며 중계기는 읽을 수 없는 암호문만 전달합니다. 오프라인 중 편집은 대기했다가 연결이 돌아오면 자동 전송됩니다.", fig: "collab", cap: "연결 전: 협업 시작, 룸 참여, 중계 서버 주소", fig2: "collab_on", cap2: "연결됨: 룸 ID, 종단 간 암호화, 이 기기가 중계, 참여자" },
      { id: "record", title: "녹음과 전사", lead: "소리와 필기가 같은 타임라인 위에 있습니다. 단어를 누르면 그때 쓴 획으로 이동합니다.", buttons: ["Start Recording", "Recent Recordings & Transcripts"], steps: ["홈의 “Start Recording” 또는 노트 상단의 마이크를 누릅니다.", "처음에는 마이크 권한을 묻습니다. 허용하세요.", "녹음 중에는 위쪽에 실시간 파형이 보이고, 쓰는 내용이 소리와 맞춰집니다.", "중지하면 홈의 “Recent Recordings & Transcripts”에 추가됩니다.", "재생 중 전사된 줄을 누르면 그 시각에 쓴 필기로 이동합니다(반대 방향도 됩니다)."], tip: "녹음과 전사는 모두 이 기기 안에서 처리되며 어디에도 올라가지 않습니다.", fig: "home", cap: "홈의 “Start Recording”과 “Recent Recordings & Transcripts”" },
      { id: "export", title: "내보내기·인쇄·공유", lead: "상대가 필요로 하는 형식을 고르세요.", buttons: ["Export & Print", "Export PDF", "Export Image", "Print Notebook", "Share Note"], steps: ["오른쪽 위 “Export & Print”를 누릅니다.", "“Export PDF”는 노트 전체를 PDF로 만듭니다.", "“Export Image”는 현재 페이지를 이미지 파일로 저장합니다.", "“Print Notebook”은 시스템 인쇄 화면으로 넘깁니다.", "“Share Note”는 .padnote 원본을 보냅니다. 상대는 Kairumo에서 이어서 편집할 수 있습니다."], tip: "PDF 안의 주석 좌표가 원본과 같아 다른 앱에서 열어도 위치가 틀어지지 않습니다.", fig: "export", cap: "내보내기 메뉴: PDF, 이미지, 인쇄, 노트 공유" },
      { id: "language", title: "언어와 표시 이름", lead: "여섯 가지 언어를 즉시 전환합니다.", buttons: ["Language", "Edit Identity"], steps: ["홈 오른쪽 위의 언어 버튼을 누릅니다.", "繁體中文, English, 简体中文, 日本語, 한국어, ไทย 중에서 고릅니다.", "다시 시작하지 않아도 화면이 바로 바뀝니다.", "홈의 “Edit Identity”에서 협업 중 보이는 이름과 색을 바꿀 수 있습니다."], tip: "표시 이름은 이 기기에만 저장되며 전송되지 않습니다.", fig: "language", cap: "언어 메뉴: 여섯 언어 즉시 전환" },
      { id: "faq", title: "문제 해결", lead: "먼저 여기를 확인하세요.", buttons: [], faq: [["협업이 연결되지 않아요", "두 기기가 같은 Wi-Fi에 있는지 확인하세요. 참여자의 “Relay Server Address”에는 호스트 화면에 표시된 ws://…:9002를 넣어야 하며 기본값 127.0.0.1이 아닙니다. 첫 연결 때 iOS가 로컬 네트워크 권한을 물으면 허용하세요."], ["노트가 사라질 수 있나요?", "쓰는 즉시 로컬 파일에 저장됩니다. 동기화 파일은 추가만 하며 각 기기는 자기 파일만 쓰기 때문에 덮어쓰기가 일어나지 않습니다."], ["계정이 필요한가요?", "아니요. Kairumo에는 계정도, 백엔드 서버도 없습니다."], ["손글씨를 글자로 바꿀 수 있나요?", "가능합니다. 기기 내장 인식 기능을 사용하므로 필기가 외부로 나가지 않습니다."], ["문제는 어떻게 알리나요?", "Mac 창 제목에 보이는 버전(예: Kairumo v2.4.1)과 진행한 단계를 함께 알려 주세요."]], fig: null }
    ]
  },

  "th": {
    name: "ไทย",
    figset: "en",
    ui: {
      docTitle: "คู่มือการใช้งาน Kairumo",
      tagline: "สมุดจดที่รวมลายมือ การพิมพ์ และการอัดเสียงไว้ด้วยกัน ทำตามทีละขั้นได้แม้เพิ่งเริ่มใช้",
      version: "สำหรับเวอร์ชัน v2.4.1 (bundle 17) · 13 กันยายน 2026",
      tocTitle: "สารบัญ",
      tocHint: "แตะหัวข้อเพื่อไปยังส่วนนั้นทันที",
      stepsLabel: "ขั้นตอน",
      tipLabel: "ข้อควรรู้",
      buttonsLabel: "ปุ่มที่ใช้",
      figNote: "ภาพหน้าจอเป็นภาษาอังกฤษ (iPad)",
      backToTop: "กลับไปที่สารบัญ",
      langLabel: "ภาษา",
      privacyLink: "นโยบายความเป็นส่วนตัว"
    },
    sections: [
      { id: "start", title: "ก่อนเริ่มต้น", lead: "Kairumo คือสมุดจดที่วางลายมือ ข้อความ และเสียงไว้บนไทม์ไลน์เดียวกัน ใช้ฟรี เป็นโอเพนซอร์ส และข้อมูลอยู่ในเครื่องของคุณ", buttons: [], steps: ["ใช้ได้บน iPad, iPhone และ Mac เขียนด้วย Apple Pencil ลื่นที่สุด แต่ใช้นิ้วหรือเมาส์ก็ได้", "ไม่ต้องสมัครบัญชีและไม่ต้องต่ออินเทอร์เน็ต", "ทุกอย่างที่คุณเขียนถูกเก็บไว้ในเครื่องนี้ หากต้องการสำรองข้อมูล ให้เก็บโฟลเดอร์ไว้ใน iCloud หรือ Google Drive ของคุณเอง", "บน Mac ชื่อหน้าต่างจะแสดงเวอร์ชัน (เช่น Kairumo v2.4.1) โปรดแจ้งมาด้วยเมื่อรายงานปัญหา"], tip: "เมื่อไม่มีเซิร์ฟเวอร์และไม่มีบัญชี ก็ไม่มีรหัสผ่านให้ลืม แต่ก็ไม่มีสำเนาบนคลาวด์เช่นกัน จึงควรสำรองข้อมูลเอง", fig: null },
      { id: "home", title: "หน้าแรก: โต๊ะทำงานของคุณ", lead: "หน้าจอแรกที่เห็นเมื่อเปิดแอป ทุกอย่างเริ่มจากที่นี่", buttons: ["Edit Identity", "New Note", "Start Recording", "Asset Library"], steps: ["ด้านบนคือชื่อที่แสดง ซึ่งเพื่อนร่วมงานจะเห็นตอนทำงานร่วมกัน แตะ “Edit Identity” เพื่อแก้ไข", "ช่องค้นหาจะค้นทั้งชื่อโน้ต ข้อความที่พิมพ์ และข้อความที่ถอดจากเสียง", "การ์ดใหญ่สามใบคือการทำงานหลัก: สร้างโน้ต อัดเสียง และคลังวัสดุ", "“Continue” แสดงโน้ตที่เพิ่งเปิด แตะครั้งเดียวก็กลับไปทำต่อได้", "“All Notebooks” จัดกลุ่มตามโฟลเดอร์ และเปลี่ยนการเรียงลำดับได้ทางขวา"], tip: "ปุ่ม “⋯” บนการ์ดแต่ละใบมีเปลี่ยนชื่อ ย้ายโฟลเดอร์ และลบ", fig: "home", cap: "หน้าแรก: ชื่อที่แสดง ค้นหา การทำงานหลักสามอย่าง Continue และ All Notebooks" },
      { id: "newnote", title: "สร้างโน้ตแรก", lead: "เลือกรูปแบบกระดาษได้สี่แบบ ตั้งแต่หน้าว่างจนถึงคอร์เนล", buttons: ["New Note", "OK"], steps: ["ที่หน้าแรก แตะ “New Note”", "พิมพ์ชื่อในช่อง “Notebook Title” จะเว้นว่างไว้แล้วเปลี่ยนทีหลังก็ได้", "เลือกธีม จากนั้นเลือกกระดาษ: หน้าว่าง ตาราง/จุด เส้นบรรทัด หรือคอร์เนล", "แตะ “OK” แล้วโน้ตจะเปิดขึ้นทันที"], tip: "กระดาษเป็นเพียงพื้นหลัง เปลี่ยนภายหลังก็ไม่กระทบเนื้อหาที่เขียนไว้", fig: "newnote", cap: "หน้าต่างสร้างโน้ต: ชื่อ ธีม และกระดาษสี่แบบ" },
      { id: "editor", title: "รู้จักหน้าจอแก้ไข", lead: "ใช้เวลาหนึ่งนาทีจำตำแหน่งปุ่ม แล้วขั้นตอนถัดไปจะง่ายขึ้น", buttons: ["Home", "Structure", "Handwriting", "Typing"], steps: ["แถวบนสุดจากซ้ายไปขวา: หน้าแรก โครงสร้างโน้ต สลับลายมือ/พิมพ์ ชื่อโน้ต เลขหน้า ไม้บรรทัด คลังวัสดุ แทรก หมุดสนทนา ทำงานร่วมกัน อัดเสียง ส่งออกและพิมพ์", "แถวที่สองคือแถบเครื่องมือของโหมดปัจจุบัน", "ด้านซ้ายคือแผงโครงสร้าง สลับระหว่างรายการหน้าและโฟลเดอร์ได้", "ตรงกลางคือผืนผ้าใบ มุมขวาล่างใช้เพิ่มหน้าถัดไป หรือต่อหน้านี้ลงไปอีก 800pt", "เมื่อหน้าต่างแคบ แถบเครื่องมือจะขึ้นบรรทัดใหม่เอง ไม่มีปุ่มหลุดออกนอกจอ"], tip: "ถ้าพื้นที่ไม่พอ แตะ “Structure” เพื่อพับคอลัมน์ซ้าย ผืนผ้าใบจะกว้างขึ้นทันที", fig: "editor", cap: "หน้าจอแก้ไข: แถบบน แถบเครื่องมือลายมือ แผงโครงสร้าง และผืนผ้าใบ" },
      { id: "write", title: "เขียนด้วยลายมือ", lead: "ปากกา 7 แบบ ความหนา 4 ระดับ เลือกสีได้อิสระ ลบได้ และใช้บ่วงคล้องเพื่อย้ายทั้งกลุ่มได้", buttons: ["Fountain Pen", "Eraser", "Lasso", "Extend Page"], steps: ["ตรวจว่าแถบบนอยู่ในโหมดลายมือ", "เลือกปากกา: ปากกาหมึกซึม ลูกลื่น พู่กัน มาร์กเกอร์ ไฮไลต์ ดินสอ หรือสีน้ำ", "จุดสี่จุดตรงกลางคือความหนา ถัดไปคือสี ส่วนไอคอนสไลเดอร์เปิดตัวเลือกสีแบบละเอียด", "ลบด้วยยางลบ ถ้าจะย้ายหรือคัดลอกทั้งกลุ่ม ให้ใช้บ่วงคล้องวงรอบก่อน", "ปลายขวาสุดคือเลิกทำ ทำซ้ำ และล้างหน้านี้", "ถ้ากระดาษไม่พอ แตะ “Extend Page” เพื่อต่อลงไปอีก 800pt"], tip: "เมื่อใช้ Apple Pencil วางฝ่ามือบนจอได้เลย ระบบจะรับเฉพาะปลายปากกา", fig: "editor", cap: "แถบเครื่องมือลายมือ: ปากกา ความหนา สี ต่อหน้า และเพิ่มเติม" },
      { id: "type", title: "พิมพ์ข้อความ", lead: "วางกล่องข้อความตรงไหนก็ได้บนผืนผ้าใบ และผสมกับลายมือได้", buttons: ["Typing", "Text Studio", "Special Symbols", "Insert Link"], steps: ["แตะไอคอนแป้นพิมพ์ที่แถบบนเพื่อเข้าสู่โหมดพิมพ์", "แตะตรงไหนก็ได้บนผืนผ้าใบ กล่องข้อความจะปรากฏพร้อมแป้นพิมพ์", "“Text Studio” ใช้ตั้งขนาด ตัวหนา ตัวเอียง ขีดเส้นใต้ การจัดแนว และสี", "“Special Symbols” แทรกสัญลักษณ์คณิตศาสตร์ ส่วน “Insert Link” เปลี่ยนลิงก์ที่วางเป็นการ์ดพรีวิว", "ลากกล่องข้อความเพื่อย้าย และลากมุมขวาล่างเพื่อปรับขนาด"], tip: "ในโหมดพิมพ์ ผืนผ้าใบรับเฉพาะ Apple Pencil การปัดด้วยนิ้วจึงเป็นการเลื่อน ไม่ใช่การขีดเส้น", fig: "typing", cap: "แถบเครื่องมือโหมดพิมพ์: Text Studio สัญลักษณ์ ลิงก์ เพิ่มเติม ต่อหน้า" },
      { id: "pages", title: "หน้าและโฟลเดอร์", lead: "โน้ตหนึ่งเล่มมีได้หลายหน้า และหลายโน้ตอยู่ในโฟลเดอร์เดียวกันได้", buttons: ["Structure", "Pages", "Folders", "Add Page"], steps: ["แตะ “Structure” ที่แถบบนเพื่อเปิดหรือปิดคอลัมน์ซ้าย", "“Pages” แสดงภาพย่อของทุกหน้า แตะเพื่อไปยังหน้านั้น", "ปุ่ม “⋯” ข้างแต่ละหน้าใช้แทรกหน้าใหม่ ทำสำเนา ลบ หรือต่อหน้านั้น", "“Folders” แสดงโฟลเดอร์และโน้ตทั้งหมด เพิ่มโฟลเดอร์ย่อย เปลี่ยนชื่อ และย้ายโน้ตได้", "แตะโน้ตอื่นใน “Folders” แล้วจะสลับไปในหน้าต่างเดิมได้ทันที"], tip: "ภาพย่อวาดด้วยสัดส่วนเดียวกับผืนผ้าใบ จึงใช้ดูตัวอย่างทั้งหน้าได้จริง", fig: "folders", cap: "แท็บ Folders: โฟลเดอร์หลัก โฟลเดอร์ย่อย และรายการโน้ต" },
      { id: "insert", title: "แทรกรูป วัสดุ และแผนภูมิ", lead: "รูปถ่าย วัสดุสเปกจริง สมการ แผนภูมิ และโมเดล 3 มิติ วางลงบนผืนผ้าใบได้ทั้งหมด", buttons: ["Insert", "Insert Image", "Asset Library", "Math Calculator"], steps: ["แตะ “Insert” ที่แถบบน หากหน้าต่างแคบ รายการเหล่านี้จะย้ายไปอยู่ในเมนู “⋯”", "“Insert Image” เลือกรูปจากคลังภาพ วางแล้วลาก ย่อขยาย ทำมุมมน และใส่กรอบได้", "“Asset Library” มีวัสดุสเปกจริง เช่น ชิ้นส่วนเครื่องกล อุปกรณ์อิเล็กทรอนิกส์ ยานพาหนะ เฟอร์นิเจอร์ ดาวน์โหลดแล้ววางได้เลย", "“Math Calculator” และ “Chart Studio” เปลี่ยนสมการหรือแผนภูมิให้เป็นการ์ดบนหน้า", "“Insert 3D Model” วางโมเดลที่หมุนได้รอบ 360°"], tip: "ไฟล์วัสดุถูกดาวน์โหลดไว้ในเครื่อง ลบออกจากคลังเพื่อคืนพื้นที่ได้ โดยวัสดุที่วางบนหน้าแล้วจะไม่หายไป", fig: "insertmenu", cap: "เมนูแทรก: คลังวัสดุ รูปภาพ สมการ โมเดล 3 มิติ หมุดสนทนา และทำงานร่วมกัน", fig2: "assetlib", cap2: "คลังวัสดุ: เลือกตามหมวด กดดาวน์โหลด แล้ววางลงหน้า" },
      { id: "comment", title: "หมุดสนทนา", lead: "ปักข้อความไว้ตรงจุดที่ต้องการบนผืนผ้าใบ ใช้เตือนตัวเองหรือคุยกับทีมก็ได้", buttons: ["Add Comment Pin", "Resolved"], steps: ["แตะ “Insert → Add Comment Pin”", "แตะตำแหน่งที่ต้องการคุย หมุดจะปักลงตรงนั้นและเปิดกล่องสนทนา", "พิมพ์ในช่องด้านล่างแล้วแตะลูกศรเพื่อส่ง", "ถ้ากล่องบังเนื้อหา ให้ลากที่จับ “≡” ทางซ้ายเพื่อย้าย", "แตะ “−” เพื่อย่อเหลือแถบชื่อ (ย่อแล้วยังลากได้) และแตะ “✕” เพื่อปิด", "เมื่อคุยจบ แตะ “Resolved” หมุดจะเปลี่ยนเป็นเครื่องหมายถูกสีเทา"], tip: "หมุดจะติดไปกับโน้ตทั้งตอนส่งออกและตอนซิงก์ และทุกคนในเซสชันจะเห็นหมุดชุดเดียวกัน", fig: "comment", cap: "กล่องสนทนา: ที่จับสำหรับลาก แก้ไขแล้ว ลบ ย่อ และปิด", fig2: "pin_min", cap2: "ย่อเหลือแถบชื่อ —— และยังลากย้ายได้" },
      { id: "collab", title: "ทำงานร่วมกันแบบเรียลไทม์", lead: "เขียนพร้อมกันบน Wi-Fi เดียวกัน ไม่มีเซิร์ฟเวอร์คลาวด์ —— เครื่องที่เริ่มเซสชันทำหน้าที่เป็นตัวส่งต่อเอง", buttons: ["Collaborate", "Start Collaboration", "Copy Encrypted Invite Link", "End Collaboration"], steps: ["แตะ “Collaborate” ที่แถบบน", "ให้คนหนึ่งแตะ “Start Collaboration” เครื่องนั้นจะทำหน้าที่ส่งต่อข้อมูลเอง ไม่ต้องใช้เซิร์ฟเวอร์ภายนอก", "จะมี Room ID ปรากฏขึ้น แตะ “Copy Encrypted Invite Link” แล้วส่งให้เพื่อน", "เพื่อนเปิดหน้าจอเดียวกัน วาง ID หรือลิงก์ในช่อง “Join Room” แล้วเข้าร่วม", "หากเพื่อนอยู่คนละเครื่อง ให้เปิด “Relay Server Address” แล้วกรอกที่อยู่ในเครือข่ายท้องถิ่นที่แสดงบนหน้าจอของผู้เริ่ม (ws://…:9002)", "เมื่อจบงาน ผู้เริ่มแตะ “End Collaboration”"], tip: "เนื้อหาถูกเข้ารหัสแบบ end-to-end ด้วย AES-256-GCM ตัวส่งต่อเห็นเพียงข้อความที่อ่านไม่ออก การแก้ไขระหว่างออฟไลน์จะถูกพักไว้และส่งอัตโนมัติเมื่อกลับมาเชื่อมต่อ", fig: "collab", cap: "ยังไม่เชื่อมต่อ: เริ่มทำงานร่วมกัน เข้าร่วมห้อง ที่อยู่เซิร์ฟเวอร์รีเลย์", fig2: "collab_on", cap2: "เชื่อมต่อแล้ว: Room ID การเข้ารหัส เครื่องนี้เป็นตัวส่งต่อ และผู้เข้าร่วม" },
      { id: "record", title: "อัดเสียงและถอดความ", lead: "เสียงกับลายมืออยู่บนไทม์ไลน์เดียวกัน แตะคำหนึ่งแล้วกระโดดไปยังเส้นที่เขียนในวินาทีนั้น", buttons: ["Start Recording", "Recent Recordings & Transcripts"], steps: ["แตะ “Start Recording” ที่หน้าแรก หรือไอคอนไมโครโฟนในโน้ต", "ครั้งแรกระบบจะขออนุญาตใช้ไมโครโฟน ให้กดอนุญาต", "ระหว่างอัด จะเห็นคลื่นเสียงด้านบน และสิ่งที่เขียนจะถูกจัดให้ตรงกับเสียง", "เมื่อหยุด ไฟล์จะไปอยู่ใน “Recent Recordings & Transcripts” ที่หน้าแรก", "ระหว่างเล่น แตะบรรทัดของข้อความที่ถอดไว้ เพื่อไปยังลายมือในช่วงเวลานั้น (และย้อนกลับได้)"], tip: "ทั้งการอัดและการถอดความทำงานในเครื่องนี้ ไม่มีการอัปโหลดไปที่ใด", fig: "home", cap: "“Start Recording” และ “Recent Recordings & Transcripts” ที่หน้าแรก" },
      { id: "export", title: "ส่งออก พิมพ์ และแชร์", lead: "มีสี่ทางเลือก เลือกตามที่ปลายทางต้องการ", buttons: ["Export & Print", "Export PDF", "Export Image", "Print Notebook", "Share Note"], steps: ["แตะ “Export & Print” ที่มุมขวาบน", "“Export PDF” เปลี่ยนทั้งเล่มเป็นไฟล์ PDF", "“Export Image” บันทึกหน้าปัจจุบันเป็นไฟล์รูป", "“Print Notebook” ส่งต่อไปยังหน้าต่างพิมพ์ของระบบ", "“Share Note” ส่งไฟล์ .padnote ต้นฉบับ ผู้รับเปิดด้วย Kairumo แล้วแก้ไขต่อได้"], tip: "พิกัดของคำอธิบายใน PDF ตรงกับต้นฉบับ เปิดในแอปอื่นก็ไม่เคลื่อน", fig: "export", cap: "เมนูส่งออก: PDF รูปภาพ พิมพ์ และแชร์โน้ต" },
      { id: "language", title: "ภาษาและชื่อที่แสดง", lead: "รองรับหกภาษา สลับได้ทันที", buttons: ["Language", "Edit Identity"], steps: ["แตะปุ่มภาษาที่มุมขวาบนของหน้าแรก", "เลือก 繁體中文, English, 简体中文, 日本語, 한국어 หรือ ไทย", "หน้าจอเปลี่ยนทันทีโดยไม่ต้องเปิดแอปใหม่", "ที่หน้าแรก “Edit Identity” ใช้เปลี่ยนชื่อและสีที่เพื่อนร่วมงานเห็น"], tip: "ชื่อที่แสดงถูกเก็บไว้ในเครื่องนี้เท่านั้น และไม่ถูกส่งออกไปที่ใด", fig: "language", cap: "เมนูภาษา: สลับหกภาษาได้ทันที" },
      { id: "faq", title: "แก้ปัญหาที่พบบ่อย", lead: "ตรวจที่นี่ก่อน", buttons: [], faq: [["เชื่อมต่อการทำงานร่วมกันไม่ได้", "ตรวจว่าทั้งสองเครื่องอยู่บน Wi-Fi เดียวกัน ช่อง “Relay Server Address” ของผู้เข้าร่วมต้องเป็น ws://…:9002 ตามที่แสดงบนหน้าจอผู้เริ่ม ไม่ใช่ค่าเริ่มต้น 127.0.0.1 และเมื่อเชื่อมต่อครั้งแรก iOS จะขออนุญาตใช้เครือข่ายท้องถิ่น ให้กดอนุญาต"], ["โน้ตหายได้ไหม", "ทุกเส้นถูกบันทึกลงไฟล์ในเครื่องทันทีที่เขียน ไฟล์ซิงก์เป็นแบบเพิ่มอย่างเดียว และแต่ละเครื่องเขียนเฉพาะไฟล์ของตัวเอง จึงไม่ทับกัน"], ["ต้องมีบัญชีไหม", "ไม่ต้อง Kairumo ไม่มีระบบบัญชีและไม่มีเซิร์ฟเวอร์เบื้องหลัง"], ["แปลงลายมือเป็นข้อความได้ไหม", "ได้ โดยใช้การรู้จำที่ทำงานในเครื่อง ลายมือไม่ถูกส่งออกไปที่ใด"], ["รายงานปัญหาอย่างไร", "โปรดแจ้งเวอร์ชันที่แสดงบนชื่อหน้าต่างบน Mac (เช่น Kairumo v2.4.1) พร้อมขั้นตอนที่ทำ"]], fig: null }
    ]
  }
};
