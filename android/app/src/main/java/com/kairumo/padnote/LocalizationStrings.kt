package com.kairumo.padnote

/**
 * ⚠️ 這是產生檔，不要手改。
 *
 * 來源：i18n/ui-strings.json —— 改字串請改那裡，再跑：
 *     python3 scripts/i18n_tool.py generate
 *
 * 與 Apple 版共用同一份來源，所以兩個平台的用語永遠一致。
 */
object LocalizationStrings {
    val table: Map<String, Map<String, String>> by lazy {
        buildMap {
            putAll(part0())
            putAll(part1())
            putAll(part2())
            putAll(part3())
            putAll(part4())
            putAll(part5())
            putAll(part6())
            putAll(part7())
            putAll(part8())
            putAll(part9())
            putAll(part10())
            putAll(part11())
            putAll(part12())
            putAll(part13())
            putAll(part14())
            putAll(part15())
            putAll(part16())
            putAll(part17())
            putAll(part18())
            putAll(part19())
            putAll(part20())
            putAll(part21())
            putAll(part22())
            putAll(part23())
            putAll(part24())
            putAll(part25())
            putAll(part26())
            putAll(part27())
            putAll(part28())
            putAll(part29())
            putAll(part30())
        }
    }

    private fun part0(): Map<String, Map<String, String>> = mapOf(
        "NSLocalNetworkUsageDescription" to mapOf(
            "zh-Hant" to "Kairumo 需要區域網路權限，以便在同一個 Wi-Fi 下讓您自己的裝置秒級同步筆記，並與同網路的協同夥伴共同編輯。所有傳輸均經端對端加密且不經外部伺服器。",
            "en" to "Kairumo uses the local network to sync your own devices on the same Wi-Fi within a second, and to edit notes together with people on that network. Everything is end-to-end encrypted and never passes through a server.",
            "zh-Hans" to "Kairumo 需要局域网权限，以便在同一个 Wi-Fi 下让您自己的设备秒级同步笔记，并与同网络的协作伙伴共同编辑。所有传输均经端到端加密且不经外部服务器。",
            "ja" to "Kairumo は、同じ Wi-Fi 上のご自身のデバイス間でノートを瞬時に同期し、同じネットワーク上の相手と一緒に編集するためにローカルネットワークを使用します。通信はすべてエンドツーエンドで暗号化され、サーバーを経由しません。",
            "ko" to "Kairumo는 같은 Wi-Fi에 있는 내 기기끼리 노트를 즉시 동기화하고, 같은 네트워크의 사람과 함께 편집하기 위해 로컬 네트워크를 사용합니다. 모든 전송은 종단간 암호화되며 서버를 거치지 않습니다.",
            "th" to "Kairumo ใช้เครือข่ายภายในเพื่อซิงค์โน้ตระหว่างอุปกรณ์ของคุณบน Wi-Fi เดียวกันได้ในไม่กี่วินาที และแก้ไขร่วมกับผู้ที่อยู่ในเครือข่ายเดียวกัน ทุกการส่งข้อมูลเข้ารหัสแบบปลายทางถึงปลายทางและไม่ผ่านเซิร์ฟเวอร์"
        ),
        "NSMicrophoneUsageDescription" to mapOf(
            "zh-Hant" to "Kairumo 需要使用麥克風，以便在課堂或會議中錄製語音筆記，並讓手寫筆劃與錄音時間軸即時動態對齊。",
            "en" to "Kairumo uses the microphone to record voice notes in class or meetings, keeping your handwriting in sync with the recording timeline.",
            "zh-Hans" to "Kairumo 需要使用麦克风，以便在课堂或会议中录制语音笔记，并让手写笔划与录音时间轴实时动态对齐。",
            "ja" to "Kairumo は、授業や会議で音声メモを録音し、手書きと録音のタイムラインを同期させるためにマイクを使用します。",
            "ko" to "Kairumo는 수업이나 회의에서 음성 메모를 녹음하고 필기와 녹음 타임라인을 맞추기 위해 마이크를 사용합니다.",
            "th" to "Kairumo ใช้ไมโครโฟนเพื่อบันทึกเสียงในชั้นเรียนหรือการประชุม และซิงค์ลายมือกับไทม์ไลน์ของเสียง"
        ),
        "NSPhotoLibraryAddUsageDescription" to mapOf(
            "zh-Hant" to "Kairumo 需要儲存圖片權限，以便將您導出的筆記頁面或繪圖成果儲存至相片圖庫。",
            "en" to "Kairumo saves pages and drawings you export to your photo library.",
            "zh-Hans" to "Kairumo 需要保存图片权限，以便将您导出的笔记页面或绘图成果保存至相片图库。",
            "ja" to "Kairumo は、書き出したページや描画を写真ライブラリに保存します。",
            "ko" to "Kairumo는 내보낸 페이지나 그림을 사진 보관함에 저장합니다.",
            "th" to "Kairumo บันทึกหน้าและภาพวาดที่คุณส่งออกไปยังคลังรูปภาพ"
        ),
        "NSPhotoLibraryUsageDescription" to mapOf(
            "zh-Hant" to "Kairumo 需要存取您的相片圖庫，以便您挑選圖片插入筆記頁面進行批註與繪製。",
            "en" to "Kairumo accesses your photo library so you can place pictures into a note and annotate them.",
            "zh-Hans" to "Kairumo 需要访问您的相片图库，以便您挑选图片插入笔记页面进行批注与绘制。",
            "ja" to "Kairumo は、写真をノートに挿入して書き込めるようにするために写真ライブラリにアクセスします。",
            "ko" to "Kairumo는 사진을 노트에 넣고 주석을 달 수 있도록 사진 보관함에 접근합니다.",
            "th" to "Kairumo เข้าถึงคลังรูปภาพเพื่อให้คุณใส่รูปลงในโน้ตและเขียนกำกับได้"
        ),
        "NSSpeechRecognitionUsageDescription" to mapOf(
            "zh-Hant" to "Kairumo 需要語音辨識權限，以便在您的裝置端將錄音語音即時轉錄為文字稿，並直接插入筆記畫布。",
            "en" to "Kairumo uses speech recognition to transcribe your recordings into text on your device and place the transcript in your notes.",
            "zh-Hans" to "Kairumo 需要语音识别权限，以便在您的设备端将录音语音实时转录为文字稿，并直接插入笔记画布。",
            "ja" to "Kairumo は、録音した音声を端末内で文字起こしし、ノートに挿入するために音声認識を使用します。",
            "ko" to "Kairumo는 녹음을 기기 내에서 텍스트로 변환해 노트에 넣기 위해 음성 인식을 사용합니다.",
            "th" to "Kairumo ใช้การรู้จำเสียงเพื่อถอดเสียงที่บันทึกไว้เป็นข้อความบนเครื่องของคุณ และใส่ลงในโน้ต"
        ),
        "about_app" to mapOf(
            "zh-Hant" to "關於 Kairumo",
            "en" to "About Kairumo",
            "zh-Hans" to "关于 Kairumo",
            "ja" to "Kairumo について",
            "ko" to "Kairumo 정보",
            "th" to "เกี่ยวกับ Kairumo"
        ),
        "about_license" to mapOf(
            "zh-Hant" to "授權",
            "en" to "License",
            "zh-Hans" to "授权",
            "ja" to "ライセンス",
            "ko" to "라이선스",
            "th" to "สัญญาอนุญาต"
        ),
        "about_stack" to mapOf(
            "zh-Hant" to "技術架構",
            "en" to "Stack",
            "zh-Hans" to "技术架构",
            "ja" to "技術スタック",
            "ko" to "기술 스택",
            "th" to "สแตกเทคโนโลยี"
        ),
        "account_settings" to mapOf(
            "zh-Hant" to "使用者帳號與設定",
            "en" to "Account & Settings",
            "zh-Hans" to "用户账号与设置",
            "ja" to "アカウントと設定",
            "ko" to "계정 및 설정",
            "th" to "บัญชีและการตั้งค่า"
        ),
        "action_copy" to mapOf(
            "zh-Hant" to "複製",
            "en" to "Copy",
            "zh-Hans" to "复制",
            "ja" to "コピー",
            "ko" to "복사",
            "th" to "คัดลอก"
        ),
        "action_delete" to mapOf(
            "zh-Hant" to "刪除",
            "en" to "Delete",
            "zh-Hans" to "删除",
            "ja" to "削除",
            "ko" to "삭제",
            "th" to "ลบ"
        ),
        "action_duplicate" to mapOf(
            "zh-Hant" to "建立副本",
            "en" to "Duplicate",
            "zh-Hans" to "创建副本",
            "ja" to "複製を作成",
            "ko" to "복제본 만들기",
            "th" to "ทำสำเนา"
        ),
        "action_open" to mapOf(
            "zh-Hant" to "開啟編輯",
            "en" to "Open Editor",
            "zh-Hans" to "打开编辑",
            "ja" to "編集を開く",
            "ko" to "편집 열기",
            "th" to "เปิดตัวแก้ไข"
        ),
        "action_paste" to mapOf(
            "zh-Hant" to "貼上",
            "en" to "Paste",
            "zh-Hans" to "粘贴",
            "ja" to "貼り付け",
            "ko" to "붙여넣기",
            "th" to "วาง"
        ),
        "action_rename" to mapOf(
            "zh-Hant" to "重新命名",
            "en" to "Rename",
            "zh-Hans" to "重命名",
            "ja" to "名前を変更",
            "ko" to "이름 변경",
            "th" to "เปลี่ยนชื่อ"
        ),
        "add_comment_pin" to mapOf(
            "zh-Hant" to "新增討論圖釘",
            "en" to "Add Comment Pin",
            "zh-Hans" to "添加讨论图钉",
            "ja" to "コメントピンを追加",
            "ko" to "댓글 핀 추가",
            "th" to "เพิ่มหมุดความคิดเห็น"
        ),
        "add_data_entry" to mapOf(
            "zh-Hant" to "新增項目",
            "en" to "Add Entry",
            "zh-Hans" to "添加项目",
            "ja" to "項目を追加",
            "ko" to "항목 추가",
            "th" to "เพิ่มรายการ"
        ),
        "add_favorite_color" to mapOf(
            "zh-Hant" to "收藏此色彩",
            "en" to "Add to Favorites",
            "zh-Hans" to "收藏此色彩",
            "ja" to "お気に入りに追加",
            "ko" to "즐겨찾기에 추가",
            "th" to "เพิ่มในรายการโปรด"
        ),
        "add_next_page" to mapOf(
            "zh-Hant" to "＋ 新增下一頁",
            "en" to "+ Add Next Page",
            "zh-Hans" to "＋ 新增下一页",
            "ja" to "＋ 次のページを追加",
            "ko" to "＋ 다음 페이지 추가",
            "th" to "＋ เพิ่มหน้าถัดไป"
        ),
        "add_note_to_folder" to mapOf(
            "zh-Hant" to "在此資料夾新增筆記",
            "en" to "New Note in Folder",
            "zh-Hans" to "在此文件夹新建笔记",
            "ja" to "このフォルダに新規ノート",
            "ko" to "이 폴더에 새 노트 추가",
            "th" to "สร้างบันทึกใหม่ในโฟลเดอร์นี้"
        ),
        "add_page" to mapOf(
            "zh-Hant" to "新增一頁",
            "en" to "Add Page",
            "zh-Hans" to "新建一页",
            "ja" to "ページを追加",
            "ko" to "페이지 추가",
            "th" to "เพิ่มหน้า"
        ),
        "add_page_desc" to mapOf(
            "zh-Hant" to "在筆記本中新增一頁空白頁面",
            "en" to "Append a new blank page to notebook",
            "zh-Hans" to "在笔记本中新增一页空白页面",
            "ja" to "ノートブックの末尾に新しいページを追加",
            "ko" to "노트북에 새로운 페이지 추가",
            "th" to "เพิ่มหน้าใหม่ในสมุดบันทึก"
        ),
        "add_page_large" to mapOf(
            "zh-Hant" to "＋ 新增頁面",
            "en" to "+ Add Page",
            "zh-Hans" to "＋ 新增页面",
            "ja" to "＋ ページを追加",
            "ko" to "＋ 페이지 추가",
            "th" to "＋ เพิ่มหน้าใหม่"
        ),
        "add_text_box" to mapOf(
            "zh-Hant" to "新增文字方塊",
            "en" to "Add Text Box",
            "zh-Hans" to "新增文字方块",
            "ja" to "テキストボックスを追加",
            "ko" to "텍스트 상자 추가",
            "th" to "เพิ่มกล่องข้อความ"
        ),
        "add_text_box_desc" to mapOf(
            "zh-Hant" to "在畫布任意位置插入專業排版文字方塊",
            "en" to "Insert a freeform Word-grade text box on canvas",
            "zh-Hans" to "在画布任意位置插入专业排版文本框",
            "ja" to "キャンバスにWord形式のテキストボックスを挿入",
            "ko" to "캔버스에 자유로운 텍스트 상자 삽입",
            "th" to "แทรกกล่องข้อความระดับ Word บนผืนผ้าใบ"
        ),
        "advanced_pen_settings" to mapOf(
            "zh-Hant" to "進階畫筆設定",
            "en" to "Advanced Pen Settings",
            "zh-Hans" to "高级画笔设置",
            "ja" to "詳細なペン設定",
            "ko" to "고급 펜 설정",
            "th" to "การตั้งค่าปากกาขั้นสูง"
        ),
        "ai_insert" to mapOf(
            "zh-Hant" to "插入筆記",
            "en" to "Insert into note",
            "zh-Hans" to "插入笔记",
            "ja" to "ノートに挿入",
            "ko" to "노트에 삽입",
            "th" to "แทรกลงในโน้ต"
        ),
        "ai_key_points" to mapOf(
            "zh-Hant" to "重點",
            "en" to "Key points",
            "zh-Hans" to "重点",
            "ja" to "要点",
            "ko" to "요점",
            "th" to "ประเด็นสำคัญ"
        ),
        "ai_no_todos" to mapOf(
            "zh-Hant" to "這則筆記裡沒有待辦事項。",
            "en" to "No to-dos in this note.",
            "zh-Hans" to "这则笔记里没有待办事项。",
            "ja" to "このノートにTo-Doはありません。",
            "ko" to "이 노트에는 할 일이 없습니다.",
            "th" to "ไม่มีสิ่งที่ต้องทำในโน้ตนี้"
        ),
        "ai_not_ready" to mapOf(
            "zh-Hant" to "裝置端模型還沒準備好（可能還在下載，或在系統設定裡被關掉了）。稍後再試一次。",
            "en" to "The on-device model is not ready yet — it may still be downloading, or turned off in system settings. Try again later.",
            "zh-Hans" to "设备端模型还没准备好（可能还在下载，或在系统设置里被关掉了）。稍后再试一次。",
            "ja" to "オンデバイスモデルの準備ができていません（ダウンロード中か、システム設定でオフになっている可能性があります）。しばらくしてからお試しください。",
            "ko" to "온디바이스 모델이 아직 준비되지 않았습니다(다운로드 중이거나 시스템 설정에서 꺼져 있을 수 있습니다). 잠시 후 다시 시도하세요.",
            "th" to "โมเดลบนเครื่องยังไม่พร้อม (อาจกำลังดาวน์โหลด หรือถูกปิดไว้ในการตั้งค่าระบบ) ลองใหม่ภายหลัง"
        ),
        "ai_nothing_to_summarize" to mapOf(
            "zh-Hant" to "這則筆記還沒有文字內容。手寫的字要先辨識過才整理得出摘要。",
            "en" to "There is no text in this note yet. Handwriting has to be recognised first before it can be summarised.",
            "zh-Hans" to "这则笔记还没有文字内容。手写的字要先识别过才整理得出摘要。",
            "ja" to "このノートにはまだ文字がありません。手書きは先に認識しないと要約できません。",
            "ko" to "이 노트에는 아직 텍스트가 없습니다. 손글씨는 먼저 인식해야 요약할 수 있습니다.",
            "th" to "โน้ตนี้ยังไม่มีข้อความ ลายมือต้องผ่านการรู้จำก่อนจึงจะสรุปได้"
        ),
        "ai_on_device_note" to mapOf(
            "zh-Hant" to "文字不會離開這台裝置。",
            "en" to "Your text never leaves this device.",
            "zh-Hans" to "文字不会离开这台设备。",
            "ja" to "テキストがこの端末の外に出ることはありません。",
            "ko" to "텍스트는 이 기기를 벗어나지 않습니다.",
            "th" to "ข้อความจะไม่ออกจากเครื่องนี้"
        ),
        "ai_run" to mapOf(
            "zh-Hant" to "開始整理",
            "en" to "Summarize",
            "zh-Hans" to "开始整理",
            "ja" to "要約する",
            "ko" to "요약하기",
            "th" to "เริ่มสรุป"
        ),
        "ai_running" to mapOf(
            "zh-Hant" to "整理中…",
            "en" to "Working…",
            "zh-Hans" to "整理中…",
            "ja" to "処理中…",
            "ko" to "처리 중…",
            "th" to "กำลังทำ…"
        ),
        "ai_summary" to mapOf(
            "zh-Hant" to "摘要與待辦",
            "en" to "Summary & To-dos",
            "zh-Hans" to "摘要与待办",
            "ja" to "要約とTo-Do",
            "ko" to "요약과 할 일",
            "th" to "สรุปและสิ่งที่ต้องทำ"
        ),
        "ai_summary_desc" to mapOf(
            "zh-Hant" to "讀過這則筆記，整理出重點與待辦事項。全程在這台裝置上完成。",
            "en" to "Reads this note and pulls out the key points and any to-dos. Everything stays on this device.",
            "zh-Hans" to "读过这则笔记，整理出重点与待办事项。全程在这台设备上完成。",
            "ja" to "このノートを読み、要点とTo-Doを整理します。すべてこの端末内で完結します。",
            "ko" to "이 노트를 읽고 요점과 할 일을 정리합니다. 모든 처리는 이 기기 안에서 이루어집니다.",
            "th" to "อ่านโน้ตนี้แล้วสรุปประเด็นสำคัญและสิ่งที่ต้องทำ ทุกอย่างทำบนเครื่องนี้"
        ),
        "ai_todos" to mapOf(
            "zh-Hant" to "待辦事項",
            "en" to "To-dos",
            "zh-Hans" to "待办事项",
            "ja" to "To-Do",
            "ko" to "할 일",
            "th" to "สิ่งที่ต้องทำ"
        ),
        "ai_unsupported" to mapOf(
            "zh-Hant" to "這台裝置上沒有可用的裝置端模型，所以做不了摘要。這一段完全在本機執行 —— 不會為了它把你的筆記傳出去。",
            "en" to "This device has no on-device model available, so summarising is not possible here. This runs entirely on the device — your notes are never sent anywhere for it.",
            "zh-Hans" to "这台设备上没有可用的设备端模型，所以做不了摘要。这一段完全在本机执行 —— 不会为了它把你的笔记传出去。",
            "ja" to "この端末には利用できるオンデバイスモデルがないため、要約はできません。この処理は端末内で完結します。要約のためにノートを送信することはありません。",
            "ko" to "이 기기에는 사용할 수 있는 온디바이스 모델이 없어 요약할 수 없습니다. 이 기능은 전부 기기 안에서 동작하며, 요약을 위해 노트를 외부로 보내지 않습니다.",
            "th" to "เครื่องนี้ไม่มีโมเดลบนเครื่องที่ใช้ได้ จึงสรุปไม่ได้ ฟีเจอร์นี้ทำงานบนเครื่องทั้งหมด และจะไม่ส่งโน้ตของคุณออกไป"
        ),
        "align_bottom" to mapOf(
            "zh-Hant" to "靠下對齊",
            "en" to "Align bottom",
            "zh-Hans" to "靠下对齐",
            "ja" to "下揃え",
            "ko" to "아래쪽 정렬",
            "th" to "ชิดล่าง"
        ),
        "align_center_h" to mapOf(
            "zh-Hant" to "水平置中",
            "en" to "Center horizontally",
            "zh-Hans" to "水平居中",
            "ja" to "左右中央",
            "ko" to "가로 가운데",
            "th" to "กึ่งกลางแนวนอน"
        ),
        "align_distribute_h" to mapOf(
            "zh-Hant" to "水平等距",
            "en" to "Distribute horizontally",
            "zh-Hans" to "水平等距",
            "ja" to "左右に等間隔",
            "ko" to "가로 균등 배치",
            "th" to "กระจายแนวนอน"
        ),
        "align_distribute_v" to mapOf(
            "zh-Hant" to "垂直等距",
            "en" to "Distribute vertically",
            "zh-Hans" to "垂直等距",
            "ja" to "上下に等間隔",
            "ko" to "세로 균등 배치",
            "th" to "กระจายแนวตั้ง"
        ),
        "align_left" to mapOf(
            "zh-Hant" to "靠左對齊",
            "en" to "Align left",
            "zh-Hans" to "靠左对齐",
            "ja" to "左揃え",
            "ko" to "왼쪽 정렬",
            "th" to "ชิดซ้าย"
        ),
        "align_middle_v" to mapOf(
            "zh-Hant" to "垂直置中",
            "en" to "Center vertically",
            "zh-Hans" to "垂直居中",
            "ja" to "上下中央",
            "ko" to "세로 가운데",
            "th" to "กึ่งกลางแนวตั้ง"
        ),
        "align_needs_two" to mapOf(
            "zh-Hant" to "選兩個以上的物件才能對齊",
            "en" to "Select two or more objects to align",
            "zh-Hans" to "选两个以上的物件才能对齐",
            "ja" to "整列するには 2 つ以上選択してください",
            "ko" to "정렬하려면 두 개 이상 선택하세요",
            "th" to "เลือกตั้งแต่ 2 ชิ้นขึ้นไปเพื่อจัดแนว"
        ),
        "align_objects" to mapOf(
            "zh-Hant" to "對齊",
            "en" to "Align",
            "zh-Hans" to "对齐",
            "ja" to "整列",
            "ko" to "정렬",
            "th" to "จัดแนว"
        ),
        "align_right" to mapOf(
            "zh-Hant" to "靠右對齊",
            "en" to "Align right",
            "zh-Hans" to "靠右对齐",
            "ja" to "右揃え",
            "ko" to "오른쪽 정렬",
            "th" to "ชิดขวา"
        ),
        "align_top" to mapOf(
            "zh-Hant" to "靠上對齊",
            "en" to "Align top",
            "zh-Hans" to "靠上对齐",
            "ja" to "上揃え",
            "ko" to "위쪽 정렬",
            "th" to "ชิดบน"
        ),
        "alignment" to mapOf(
            "zh-Hant" to "對齊",
            "en" to "Alignment",
            "zh-Hans" to "对齐",
            "ja" to "配置",
            "ko" to "정렬",
            "th" to "การจัดวาง"
        ),
        "all_asset_types" to mapOf(
            "zh-Hant" to "全部型態",
            "en" to "All Types",
            "zh-Hans" to "全部类型",
            "ja" to "すべてのタイプ",
            "ko" to "모든 유형",
            "th" to "ทุกประเภท"
        ),
        "all_folders" to mapOf(
            "zh-Hant" to "全部檔案",
            "en" to "All Files",
            "zh-Hans" to "全部文件",
            "ja" to "すべてのファイル",
            "ko" to "모든 파일",
            "th" to "ไฟล์ทั้งหมด"
        ),
        "all_notebooks" to mapOf(
            "zh-Hant" to "全部筆記",
            "en" to "All Notebooks",
            "zh-Hans" to "全部笔记",
            "ja" to "すべてのノート",
            "ko" to "모든 노트",
            "th" to "บันทึกทั้งหมด"
        ),
        "all_pages" to mapOf(
            "zh-Hant" to "全部頁面",
            "en" to "All Pages",
            "zh-Hans" to "全部页面",
            "ja" to "全ページ",
            "ko" to "전체 페이지",
            "th" to "ทุกหน้า"
        ),
        "all_themes" to mapOf(
            "zh-Hant" to "全部主題",
            "en" to "All Themes",
            "zh-Hans" to "全部主题",
            "ja" to "すべてのテーマ",
            "ko" to "모든 테마",
            "th" to "ทุกธีม"
        ),
        "anchor_auto" to mapOf(
            "zh-Hant" to "自動",
            "en" to "Auto",
            "zh-Hans" to "自动",
            "ja" to "自動",
            "ko" to "자동",
            "th" to "อัตโนมัติ"
        ),
        "anchor_bottom" to mapOf(
            "zh-Hant" to "下",
            "en" to "Bottom",
            "zh-Hans" to "下",
            "ja" to "下",
            "ko" to "아래",
            "th" to "ล่าง"
        ),
        "anchor_left" to mapOf(
            "zh-Hant" to "左",
            "en" to "Left",
            "zh-Hans" to "左",
            "ja" to "左",
            "ko" to "왼쪽",
            "th" to "ซ้าย"
        ),
        "anchor_right" to mapOf(
            "zh-Hant" to "右",
            "en" to "Right",
            "zh-Hans" to "右",
            "ja" to "右",
            "ko" to "오른쪽",
            "th" to "ขวา"
        ),
        "anchor_top" to mapOf(
            "zh-Hant" to "上",
            "en" to "Top",
            "zh-Hans" to "上",
            "ja" to "上",
            "ko" to "위",
            "th" to "บน"
        ),
        "app_slogan" to mapOf(
            "zh-Hant" to "手寫與錄音雙向對齊 · 離線優先 · 開源透明",
            "en" to "Dual Ink & Audio Sync · Offline First · Open Source",
            "zh-Hans" to "手写与录音对齐 · 离线优先 · 开源透明",
            "ja" to "手書きと録音の同期 · オフライン優先 · オープンソース",
            "ko" to "필기와 녹음 동기화 · 오프라인 우선 · 오픈 소스",
            "th" to "ซิงค์ลายมือและเสียง · ออฟไลน์ก่อน · โอเพ่นซอร์ส"
        ),
        "app_version_info" to mapOf(
            "zh-Hant" to "應用程式版本資訊",
            "en" to "Application Version Info",
            "zh-Hans" to "应用程序版本信息",
            "ja" to "アプリバージョン情報",
            "ko" to "앱 버전 정보",
            "th" to "ข้อมูลเวอร์ชันแอปพลิเคชัน"
        ),
        "apply_hex" to mapOf(
            "zh-Hant" to "套用色碼",
            "en" to "Apply hex",
            "zh-Hans" to "应用色码",
            "ja" to "カラーコードを適用",
            "ko" to "색상 코드 적용",
            "th" to "ใช้รหัสสี"
        ),
        "apply_refine" to mapOf(
            "zh-Hant" to "一鍵修飾",
            "en" to "Auto Refine",
            "zh-Hans" to "一键修饰",
            "ja" to "自動補正",
            "ko" to "자동 보정",
            "th" to "ปรับแต่งอัตโนมัติ"
        ),
        "arch_mode" to mapOf(
            "zh-Hant" to "架構模式",
            "en" to "Architecture Mode",
            "zh-Hans" to "架构模式",
            "ja" to "アーキテクチャモード",
            "ko" to "아키텍처 모드",
            "th" to "โหมดสถาปัตยกรรม"
        ),
        "asr_banner_download_hint" to mapOf(
            "zh-Hant" to "點擊下載離線模型 (574 MB)；未下載時自動降級以系統聽寫轉錄",
            "en" to "Download offline model (574 MB); system dictation is used when not downloaded",
            "zh-Hans" to "点击下载离线模型 (574 MB)；未下载时自动降级以系统听写转录",
            "ja" to "オフラインモデルをダウンロード（574 MB）。未ダウンロード時はシステム音声入力を使用します",
            "ko" to "오프라인 모델 다운로드(574 MB). 내려받지 않은 경우 시스템 받아쓰기로 대체됩니다",
            "th" to "ดาวน์โหลดโมเดลออฟไลน์ (574 MB) หากยังไม่ได้ดาวน์โหลดจะใช้การพิมพ์ด้วยเสียงของระบบแทน"
        ),
        "asr_banner_whisper_desc" to mapOf(
            "zh-Hant" to "100% 離線高精準辨識 (574 MB)，支援多國語自動偵測與智慧標點",
            "en" to "100% offline high accuracy (574 MB), with auto language detection and punctuation",
            "zh-Hans" to "100% 离线高精尖识别 (574 MB)，支持多国语自动检测与智能标点",
            "ja" to "100% オフライン高精度認識（574 MB）、言語自動判定と句読点付与に対応",
            "ko" to "100% 오프라인 고정밀 인식(574 MB), 언어 자동 감지 및 문장 부호 복원 지원",
            "th" to "การรู้จำความแม่นยำสูงแบบออฟไลน์ 100% (574 MB) พร้อมการตรวจภาษาและวรรคตอนอัตโนมัติ"
        ),
        "asr_cancel_download" to mapOf(
            "zh-Hant" to "取消下載 Whisper 模型",
            "en" to "Cancel the Whisper download",
            "zh-Hans" to "取消下载 Whisper 模型",
            "ja" to "Whisper のダウンロードをキャンセル",
            "ko" to "Whisper 다운로드 취소",
            "th" to "ยกเลิกการดาวน์โหลด Whisper"
        ),
        "asr_download_btn" to mapOf(
            "zh-Hant" to "下載 Whisper 離線模型（574 MB）",
            "en" to "Download the offline Whisper model (574 MB)",
            "zh-Hans" to "下载 Whisper 离线模型（574 MB）",
            "ja" to "オフライン Whisper モデルをダウンロード（574 MB）",
            "ko" to "오프라인 Whisper 모델 다운로드(574 MB)",
            "th" to "ดาวน์โหลดโมเดล Whisper ออฟไลน์ (574 MB)"
        ),
        "asr_err_buffer" to mapOf(
            "zh-Hant" to "無法配置音訊緩衝區",
            "en" to "Could not allocate the audio buffer",
            "zh-Hans" to "无法分配音频缓冲区",
            "ja" to "音声バッファを確保できませんでした",
            "ko" to "오디오 버퍼를 할당할 수 없습니다",
            "th" to "จัดสรรบัฟเฟอร์เสียงไม่ได้"
        ),
        "asr_err_converter" to mapOf(
            "zh-Hant" to "無法建立音訊格式轉換器",
            "en" to "Could not create the audio converter",
            "zh-Hans" to "无法创建音频格式转换器",
            "ja" to "音声フォーマット変換器を作成できませんでした",
            "ko" to "오디오 형식 변환기를 만들 수 없습니다",
            "th" to "สร้างตัวแปลงรูปแบบเสียงไม่ได้"
        ),
        "asr_err_decoder" to mapOf(
            "zh-Hant" to "無法啟動音訊解碼器",
            "en" to "Could not start the audio decoder",
            "zh-Hans" to "无法启动音频解码器",
            "ja" to "音声デコーダを起動できませんでした",
            "ko" to "오디오 디코더를 시작할 수 없습니다",
            "th" to "เริ่มตัวถอดรหัสเสียงไม่ได้"
        ),
        "asr_err_file_missing" to mapOf(
            "zh-Hant" to "音訊檔案不存在：%@",
            "en" to "The audio file does not exist: %@",
            "zh-Hans" to "音频文件不存在：%@",
            "ja" to "音声ファイルが存在しません：%@",
            "ko" to "오디오 파일이 없습니다: %@",
            "th" to "ไม่พบไฟล์เสียง: %@"
        ),
        "asr_err_format_init" to mapOf(
            "zh-Hant" to "無法初始化 16kHz 目標格式",
            "en" to "Could not set up the 16 kHz target format",
            "zh-Hans" to "无法初始化 16kHz 目标格式",
            "ja" to "16kHz の出力形式を初期化できませんでした",
            "ko" to "16kHz 대상 형식을 초기화할 수 없습니다",
            "th" to "ตั้งค่ารูปแบบเป้าหมาย 16kHz ไม่ได้"
        ),
        "asr_err_locale_unavailable" to mapOf(
            "zh-Hant" to "目前語系不支援語音辨識",
            "en" to "Speech recognition isn't available for the current language",
            "zh-Hans" to "当前语言不支持语音识别",
            "ja" to "現在の言語では音声認識を利用できません",
            "ko" to "현재 언어에서는 음성 인식을 사용할 수 없습니다",
            "th" to "ไม่รองรับการรู้จำเสียงสำหรับภาษาปัจจุบัน"
        ),
        "asr_err_model_size" to mapOf(
            "zh-Hant" to "模型檔案大小異常（僅 %@ MB），請確認選取的是完整的 Whisper ggml 權重檔",
            "en" to "The model file is unexpectedly small (only %@ MB). Make sure you selected the complete Whisper ggml weights file.",
            "zh-Hans" to "模型文件大小异常（仅 %@ MB），请确认选取的是完整的 Whisper ggml 权重文件",
            "ja" to "モデルファイルのサイズが異常です（%@ MB のみ）。完全な Whisper ggml 重みファイルを選択してください。",
            "ko" to "모델 파일 크기가 비정상적입니다 (%@ MB뿐). 완전한 Whisper ggml 가중치 파일을 선택했는지 확인하세요.",
            "th" to "ขนาดไฟล์โมเดลผิดปกติ (เพียง %@ MB) โปรดตรวจสอบว่าเลือกไฟล์น้ำหนัก Whisper ggml ที่สมบูรณ์"
        ),
        "asr_err_no_result" to mapOf(
            "zh-Hant" to "轉錄無結果",
            "en" to "The transcription returned no result",
            "zh-Hans" to "转录无结果",
            "ja" to "文字起こしの結果がありません",
            "ko" to "받아쓰기 결과가 없습니다",
            "th" to "การถอดเสียงไม่มีผลลัพธ์"
        ),
        "asr_err_no_track" to mapOf(
            "zh-Hant" to "找不到音訊軌道",
            "en" to "No audio track found",
            "zh-Hans" to "找不到音频轨道",
            "ja" to "音声トラックが見つかりません",
            "ko" to "오디오 트랙을 찾을 수 없습니다",
            "th" to "ไม่พบแทร็กเสียง"
        ),
        "asr_err_output_buffer" to mapOf(
            "zh-Hant" to "無法配置輸出音訊緩衝區",
            "en" to "Could not allocate the output audio buffer",
            "zh-Hans" to "无法分配输出音频缓冲区",
            "ja" to "出力用の音声バッファを確保できませんでした",
            "ko" to "출력 오디오 버퍼를 할당할 수 없습니다",
            "th" to "จัดสรรบัฟเฟอร์เสียงขาออกไม่ได้"
        ),
        "asr_err_permission" to mapOf(
            "zh-Hant" to "語音辨識權限被拒絕",
            "en" to "Speech recognition permission was denied",
            "zh-Hans" to "语音识别权限被拒绝",
            "ja" to "音声認識の権限が拒否されました",
            "ko" to "음성 인식 권한이 거부되었습니다",
            "th" to "สิทธิ์การรู้จำเสียงถูกปฏิเสธ"
        ),
        "asr_err_timeout" to mapOf(
            "zh-Hant" to "語音辨識超時（15 秒）。請檢查網路連線或系統聽寫模型。",
            "en" to "Speech recognition timed out (15 s). Check your connection or the system dictation model.",
            "zh-Hans" to "语音识别超时（15 秒）。请检查网络连接或系统听写模型。",
            "ja" to "音声認識がタイムアウトしました（15 秒）。ネットワーク接続またはシステムの音声入力モデルを確認してください。",
            "ko" to "음성 인식 시간이 초과되었습니다 (15초). 네트워크 연결 또는 시스템 받아쓰기 모델을 확인하세요.",
            "th" to "การรู้จำเสียงหมดเวลา (15 วินาที) โปรดตรวจสอบการเชื่อมต่อหรือโมเดลการสั่งงานด้วยเสียงของระบบ"
        )
    )

    private fun part1(): Map<String, Map<String, String>> = mapOf(
        "asr_err_unavailable" to mapOf(
            "zh-Hant" to "語音辨識目前無法使用",
            "en" to "Speech recognition is currently unavailable",
            "zh-Hans" to "语音识别目前无法使用",
            "ja" to "音声認識は現在利用できません",
            "ko" to "음성 인식을 현재 사용할 수 없습니다",
            "th" to "ขณะนี้ใช้การรู้จำเสียงไม่ได้"
        ),
        "asr_err_wav_init" to mapOf(
            "zh-Hant" to "無法初始化 WAV 格式",
            "en" to "Could not set up the WAV format",
            "zh-Hans" to "无法初始化 WAV 格式",
            "ja" to "WAV 形式を初期化できませんでした",
            "ko" to "WAV 형식을 초기화할 수 없습니다",
            "th" to "ตั้งค่ารูปแบบ WAV ไม่ได้"
        ),
        "asr_model_not_listed" to mapOf(
            "zh-Hant" to "清單裡沒有 %@",
            "en" to "%@ is not in the list",
            "zh-Hans" to "清单里没有 %@",
            "ja" to "%@ は一覧にありません",
            "ko" to "목록에 %@이(가) 없습니다",
            "th" to "ไม่มี %@ ในรายการ"
        ),
        "asr_open_settings_btn" to mapOf(
            "zh-Hant" to "到系統設定下載聽寫模型",
            "en" to "Download the dictation model in System Settings",
            "zh-Hans" to "到系统设置下载听写模型",
            "ja" to "システム設定で音声入力モデルをダウンロード",
            "ko" to "시스템 설정에서 받아쓰기 모델 다운로드",
            "th" to "ดาวน์โหลดโมเดลการพิมพ์ด้วยเสียงในการตั้งค่าระบบ"
        ),
        "asr_remove_model" to mapOf(
            "zh-Hant" to "移除以釋放空間",
            "en" to "Remove to free up space",
            "zh-Hans" to "移除以释放空间",
            "ja" to "削除して空き容量を確保",
            "ko" to "삭제하여 공간 확보",
            "th" to "ลบเพื่อคืนพื้นที่"
        ),
        "asr_section_title" to mapOf(
            "zh-Hant" to "語音轉文字與離線模型",
            "en" to "Speech to text and offline models",
            "zh-Hans" to "语音转文字与离线模型",
            "ja" to "音声認識とオフラインモデル",
            "ko" to "음성 인식 및 오프라인 모델",
            "th" to "การถอดเสียงและโมเดลออฟไลน์"
        ),
        "asr_section_title2" to mapOf(
            "zh-Hant" to "語音轉錄與離線模型",
            "en" to "Transcription and offline models",
            "zh-Hans" to "语音转录与离线模型",
            "ja" to "文字起こしとオフラインモデル",
            "ko" to "전사 및 오프라인 모델",
            "th" to "การถอดเสียงและโมเดลออฟไลน์"
        ),
        "asr_state_downloading" to mapOf(
            "zh-Hant" to "Whisper 模型下載中：%@\n下載完成後會自動啟用多語言偵測與標點。",
            "en" to "Downloading the Whisper model: %@\nLanguage detection and punctuation turn on automatically when it finishes.",
            "zh-Hans" to "Whisper 模型下载中：%@\n下载完成后会自动启用多语言检测与标点。",
            "ja" to "Whisper モデルをダウンロード中：%@\n完了すると多言語判定と句読点付与が自動で有効になります。",
            "ko" to "Whisper 모델 다운로드 중: %@\n완료되면 다국어 감지와 문장 부호가 자동으로 켜집니다.",
            "th" to "กำลังดาวน์โหลดโมเดล Whisper: %@\nเมื่อเสร็จแล้วระบบจะเปิดการตรวจภาษาและวรรคตอนให้อัตโนมัติ"
        ),
        "asr_state_interrupted" to mapOf(
            "zh-Hant" to "上次下載中斷：%@\n請確認網路，或改用「鏡像來源」下載。",
            "en" to "The last download was interrupted: %@\nCheck your connection, or download from the mirror instead.",
            "zh-Hans" to "上次下载中断：%@\n请确认网络，或改用「镜像来源」下载。",
            "ja" to "前回のダウンロードが中断されました：%@\n接続を確認するか、ミラーからダウンロードしてください。",
            "ko" to "지난 다운로드가 중단되었습니다: %@\n연결을 확인하거나 미러에서 내려받으세요.",
            "th" to "การดาวน์โหลดครั้งก่อนถูกขัดจังหวะ: %@\nโปรดตรวจสอบการเชื่อมต่อ หรือดาวน์โหลดจากมิเรอร์แทน"
        ),
        "asr_state_not_downloaded" to mapOf(
            "zh-Hant" to "尚未下載 Whisper 離線模型，目前改用系統聽寫。\n下載之後辨識會更準。",
            "en" to "The offline Whisper model has not been downloaded, so system dictation is used instead.\nDownloading it improves accuracy.",
            "zh-Hans" to "尚未下载 Whisper 离线模型，目前改用系统听写。\n下载之后识别会更准。",
            "ja" to "オフラインの Whisper モデルが未ダウンロードのため、システムの音声入力を使用しています。\nダウンロードすると精度が上がります。",
            "ko" to "오프라인 Whisper 모델이 없어 시스템 받아쓰기를 사용합니다.\n내려받으면 정확도가 올라갑니다.",
            "th" to "ยังไม่ได้ดาวน์โหลดโมเดล Whisper แบบออฟไลน์ จึงใช้การพิมพ์ด้วยเสียงของระบบแทน\nดาวน์โหลดแล้วจะแม่นยำขึ้น"
        ),
        "asr_state_ready_long" to mapOf(
            "zh-Hant" to "Whisper 端側模型已就緒。\n\n自動偵測 99 種語言、自動補標點，全程在這台裝置上運算，內容不離開裝置。",
            "en" to "The on-device Whisper model is ready.\n\nIt detects 99 languages automatically and restores punctuation. Everything runs on this device; nothing leaves it.",
            "zh-Hans" to "Whisper 端侧模型已就绪。\n\n自动检测 99 种语言、自动补标点，全程在这台设备上运算，内容不离开设备。",
            "ja" to "端末内 Whisper モデルの準備ができました。\n\n99 言語を自動判定し、句読点も自動で補います。すべてこの端末で処理され、外部には送信されません。",
            "ko" to "기기 내 Whisper 모델이 준비되었습니다.\n\n99개 언어를 자동 감지하고 문장 부호를 복원합니다. 모든 처리는 이 기기에서 이루어지며 외부로 나가지 않습니다.",
            "th" to "โมเดล Whisper ในเครื่องพร้อมใช้งานแล้ว\n\nตรวจจับได้ 99 ภาษาโดยอัตโนมัติและเติมวรรคตอนให้ ทุกอย่างประมวลผลบนอุปกรณ์นี้ ไม่มีข้อมูลออกไปข้างนอก"
        ),
        "asr_state_ready_short" to mapOf(
            "zh-Hant" to "Whisper 端側模型已就緒。",
            "en" to "The on-device Whisper model is ready.",
            "zh-Hans" to "Whisper 端侧模型已就绪。",
            "ja" to "端末内 Whisper モデルの準備ができました。",
            "ko" to "기기 내 Whisper 모델이 준비되었습니다.",
            "th" to "โมเดล Whisper ในเครื่องพร้อมใช้งานแล้ว"
        ),
        "asr_state_standard" to mapOf(
            "zh-Hant" to "目前使用系統的標準語音服務轉錄。",
            "en" to "Transcribing with the system's standard speech service.",
            "zh-Hans" to "目前使用系统的标准语音服务转录。",
            "ja" to "システム標準の音声サービスで文字起こししています。",
            "ko" to "시스템 표준 음성 서비스로 전사하고 있습니다.",
            "th" to "กำลังถอดเสียงด้วยบริการเสียงมาตรฐานของระบบ"
        ),
        "asr_state_system_only" to mapOf(
            "zh-Hant" to "系統聽寫已就緒（依介面語言轉錄）。\n想要自動偵測語言與自動標點，請下載 Whisper 離線模型。",
            "en" to "System dictation is ready (it transcribes in the interface language).\nFor automatic language detection and punctuation, download the offline Whisper model.",
            "zh-Hans" to "系统听写已就绪（依界面语言转录）。\n想要自动检测语言与自动标点，请下载 Whisper 离线模型。",
            "ja" to "システムの音声入力が利用できます（インターフェイスの言語で文字起こし）。\n言語の自動判定と句読点が必要な場合は、オフラインの Whisper モデルをダウンロードしてください。",
            "ko" to "시스템 받아쓰기를 사용할 수 있습니다(인터페이스 언어로 전사). 언어 자동 감지와 문장 부호가 필요하면 오프라인 Whisper 모델을 내려받으세요.",
            "th" to "การพิมพ์ด้วยเสียงของระบบพร้อมใช้งาน (ถอดเสียงตามภาษาของอินเทอร์เฟซ)\nหากต้องการตรวจภาษาและวรรคตอนอัตโนมัติ ให้ดาวน์โหลดโมเดล Whisper แบบออฟไลน์"
        ),
        "asr_state_title" to mapOf(
            "zh-Hant" to "離線語音模型狀態",
            "en" to "Offline speech model",
            "zh-Hans" to "离线语音模型状态",
            "ja" to "オフライン音声モデルの状態",
            "ko" to "오프라인 음성 모델 상태",
            "th" to "สถานะโมเดลเสียงออฟไลน์"
        ),
        "asr_whisper_model_not_downloaded" to mapOf(
            "zh-Hant" to "未下載 Whisper 離線語音模型",
            "en" to "Whisper Offline Speech Model Not Downloaded",
            "zh-Hans" to "未下载 Whisper 离线语音模型",
            "ja" to "Whisper オフライン音声モデル未ダウンロード",
            "ko" to "Whisper 오프라인 음성 모델 미다운로드",
            "th" to "ยังไม่ได้ดาวน์โหลดโมเดลเสียงออฟไลน์ Whisper"
        ),
        "asr_whisper_model_ready" to mapOf(
            "zh-Hant" to "Whisper 端側神經語音模型已就緒",
            "en" to "Whisper On-Device Neural Speech Model Ready",
            "zh-Hans" to "Whisper 端侧神经语音模型已就绪",
            "ja" to "Whisper 端末内音声モデルの準備完了",
            "ko" to "Whisper 기기 내 음성 모델 준비됨",
            "th" to "โมเดลเสียง Whisper ในเครื่องพร้อมใช้งาน"
        ),
        "asset_aes_comp_01_title" to mapOf(
            "zh-Hant" to "黃金螺旋對數構圖尺標",
            "en" to "Golden-Spiral Logarithmic Composition Guide",
            "zh-Hans" to "黄金螺旋对数构图尺标",
            "ja" to "黄金螺旋の対数構図ガイド",
            "ko" to "황금나선 로그 구성 가이드",
            "th" to "ไม้บรรทัดจัดองค์ประกอบเกลียวทองคำแบบลอการิทึม"
        ),
        "asset_aes_comp_02_title" to mapOf(
            "zh-Hant" to "經典攝影三分法則九宮格",
            "en" to "Classic Rule-of-Thirds Photography Grid",
            "zh-Hans" to "经典摄影三分法九宫格",
            "ja" to "写真用クラシック三分割グリッド",
            "ko" to "클래식 사진 삼분할 그리드",
            "th" to "ตารางกฎสามส่วนสำหรับการถ่ายภาพแบบคลาสสิก"
        ),
        "asset_aes_comp_03_title" to mapOf(
            "zh-Hant" to "動態對稱菱形構圖引導",
            "en" to "Dynamic-Symmetry Armature Composition Guide",
            "zh-Hans" to "动态对称菱形构图引导",
            "ja" to "動的対称アーマチュア構図ガイド",
            "ko" to "동적 대칭 아마추어 구성 가이드",
            "th" to "ไกด์จัดองค์ประกอบโครงสร้างสมมาตรไดนามิก"
        ),
        "asset_auto_01_title" to mapOf(
            "zh-Hant" to "跑車空氣動力學流線側影",
            "en" to "Sports Car Aerodynamic Side Profile",
            "zh-Hans" to "跑车空气动力学流线侧影",
            "ja" to "スポーツカー空力サイドプロファイル",
            "ko" to "스포츠카 공기역학 사이드 프로파일",
            "th" to "โปรไฟล์ด้านข้างเชิงอากาศพลศาสตร์ของรถสปอร์ต"
        ),
        "asset_auto_02_title" to mapOf(
            "zh-Hant" to "五輻雙柱鍛造運動輪框",
            "en" to "Five-Spoke Split Forged Sport Wheel Rim",
            "zh-Hans" to "五辐双柱锻造运动轮毂",
            "ja" to "5スポーク・スプリット鍛造スポーツホイールリム",
            "ko" to "5스포크 듀얼 스플릿 단조 스포츠 휠 림",
            "th" to "ล้อสปอร์ตฟอร์จแบบห้าก้านคู่"
        ),
        "asset_auto_03_title" to mapOf(
            "zh-Hant" to "雙 A 臂獨立懸吊機構",
            "en" to "Double-Wishbone Independent Suspension Mechanism",
            "zh-Hans" to "双 A 臂独立悬架机构",
            "ja" to "ダブルウィッシュボーン独立懸架機構",
            "ko" to "더블 위시본 독립 현가 장치",
            "th" to "ระบบกันสะเทือนอิสระแบบปีกนกคู่"
        ),
        "asset_auto_04_title" to mapOf(
            "zh-Hant" to "三輻運動賽車方向盤",
            "en" to "Three-Spoke Sport Racing Steering Wheel",
            "zh-Hans" to "三辐运动赛车方向盘",
            "ja" to "3スポーク・スポーツレーシングステアリングホイール",
            "ko" to "3스포크 스포츠 레이싱 스티어링 휠",
            "th" to "พวงมาลัยแข่งสปอร์ตสามก้าน"
        ),
        "asset_auto_05_title" to mapOf(
            "zh-Hant" to "純電滑板底盤電池模組架構",
            "en" to "EV Skateboard Chassis Battery Module Architecture",
            "zh-Hans" to "纯电滑板底盘电池模组架构",
            "ja" to "EVスケートボードシャシー電池モジュール構成",
            "ko" to "전기차 스케이트보드 섀시 배터리 모듈 구조",
            "th" to "สถาปัตยกรรมโมดูลแบตเตอรี่บนแชสซีสเกตบอร์ด EV"
        ),
        "asset_auto_06_title" to mapOf(
            "zh-Hant" to "未來星際懸浮穿梭載具",
            "en" to "Futuristic Orbital Hover Shuttle",
            "zh-Hans" to "未来星际悬浮穿梭载具",
            "ja" to "未来型軌道ホバーシャトル",
            "ko" to "미래형 궤도 호버 셔틀",
            "th" to "ยานรับส่งโฮเวอร์วงโคจรแนวอนาคต"
        ),
        "asset_digi_01_title" to mapOf(
            "zh-Hant" to "旗艦智慧型手機 UI 向量線框",
            "en" to "Flagship Smartphone UI Vector Wireframe",
            "zh-Hans" to "旗舰智能手机 UI 向量线框",
            "ja" to "フラッグシップスマートフォンUIベクターワイヤーフレーム",
            "ko" to "플래그십 스마트폰 UI 벡터 와이어프레임",
            "th" to "ไวร์เฟรมเวกเตอร์ UI สมาร์ตโฟนเรือธง"
        ),
        "asset_digi_02_title" to mapOf(
            "zh-Hant" to "平板手繪多視窗佈局",
            "en" to "Hand-Drawn Tablet Multi-Window Layout",
            "zh-Hans" to "平板手绘多窗口布局",
            "ja" to "タブレット用手描きマルチウィンドウレイアウト",
            "ko" to "태블릿 손그림 멀티윈도우 레이아웃",
            "th" to "เลย์เอาต์หลายหน้าต่างแบบวาดมือสำหรับแท็บเล็ต"
        ),
        "asset_digi_03_title" to mapOf(
            "zh-Hant" to "極簡瀏覽器視窗框架",
            "en" to "Minimal Browser Window Frame",
            "zh-Hans" to "极简浏览器窗口框架",
            "ja" to "ミニマルなブラウザウィンドウフレーム",
            "ko" to "미니멀 브라우저 창 프레임",
            "th" to "กรอบหน้าต่างเบราว์เซอร์มินิมอล"
        ),
        "asset_digi_04_title" to mapOf(
            "zh-Hant" to "行動端 8 種核心手勢符號包",
            "en" to "Mobile 8-Core-Gesture Annotation Set",
            "zh-Hans" to "移动端 8 种核心手势符号包",
            "ja" to "モバイル向け8種基本ジェスチャー注釈セット",
            "ko" to "모바일 8대 핵심 제스처 주석 세트",
            "th" to "ชุดสัญลักษณ์ 8 ท่าทางหลักสำหรับมือถือ"
        ),
        "asset_elec_01_title" to mapOf(
            "zh-Hant" to "旗艦手機鋁合金中框結構",
            "en" to "Flagship Smartphone Aluminum Mid-Frame Structure",
            "zh-Hans" to "旗舰手机铝合金中框结构",
            "ja" to "フラッグシップスマートフォン用アルミ合金ミッドフレーム構造",
            "ko" to "플래그십 스마트폰 알루미늄 합금 미드프레임 구조",
            "th" to "โครงกลางอะลูมิเนียมอัลลอยสำหรับสมาร์ตโฟนเรือธง"
        ),
        "asset_elec_02_title" to mapOf(
            "zh-Hant" to "真無線降噪耳機聲學腔體",
            "en" to "TWS Noise-Cancelling Earbud Acoustic Chamber",
            "zh-Hans" to "真无线降噪耳机声学腔体",
            "ja" to "完全ワイヤレスノイズキャンセリングイヤホン音響チャンバー",
            "ko" to "TWS 노이즈 캔슬링 이어버드 음향 챔버",
            "th" to "โพรงอะคูสติกหูฟังไร้สายตัดเสียงรบกวน TWS"
        ),
        "asset_elec_03_title" to mapOf(
            "zh-Hant" to "大光圈相機鏡頭光學鏡組",
            "en" to "Large-Aperture Camera Lens Optical Assembly",
            "zh-Hans" to "大光圈相机镜头光学镜组",
            "ja" to "大口径カメラレンズ光学アセンブリ",
            "ko" to "대구경 카메라 렌즈 광학 어셈블리",
            "th" to "ชุดเลนส์กล้องรูรับแสงกว้าง"
        ),
        "asset_elec_04_title" to mapOf(
            "zh-Hant" to "75% 客製化機械鍵盤 Gasket 結構",
            "en" to "75% Custom Mechanical Keyboard Gasket Structure",
            "zh-Hans" to "75% 客制化机械键盘 Gasket 结构",
            "ja" to "75% カスタムメカニカルキーボード用ガスケット構造",
            "ko" to "75% 커스텀 기계식 키보드 가스켓 구조",
            "th" to "โครงสร้างแกสเก็ตคีย์บอร์ดกลไกคัสตอม 75%"
        ),
        "asset_elec_05_title" to mapOf(
            "zh-Hant" to "曲面未來感智慧座艙 HUD",
            "en" to "Curved Futuristic Smart-Cockpit HUD",
            "zh-Hans" to "曲面未来感智能座舱 HUD",
            "ja" to "曲面型フューチャリスティック・スマートコックピットHUD",
            "ko" to "곡면형 미래형 스마트 콕핏 HUD",
            "th" to "HUD ห้องโดยสารอัจฉริยะทรงโค้งแนวอนาคต"
        ),
        "asset_furn_01_title" to mapOf(
            "zh-Hant" to "經典伊姆斯休閒躺椅",
            "en" to "Classic Eames Lounge Chair Geometry",
            "zh-Hans" to "经典伊姆斯休闲躺椅",
            "ja" to "クラシック・イームズラウンジチェア形状",
            "ko" to "클래식 임스 라운지 체어 형상",
            "th" to "รูปทรงเก้าอี้เลานจ์ Eames คลาสสิก"
        ),
        "asset_furn_02_title" to mapOf(
            "zh-Hant" to "人體工學升降辦公桌幾何",
            "en" to "Ergonomic Height-Adjustable Desk Geometry",
            "zh-Hans" to "人体工学升降办公桌几何",
            "ja" to "人間工学昇降デスク形状",
            "ko" to "인체공학 높이 조절 책상 형상",
            "th" to "รูปทรงโต๊ะทำงานปรับระดับตามหลักสรีรศาสตร์"
        ),
        "asset_furn_03_title" to mapOf(
            "zh-Hant" to "包浩斯懸臂可調護眼檯燈",
            "en" to "Bauhaus Adjustable Cantilever Task Lamp",
            "zh-Hans" to "包豪斯悬臂可调护眼台灯",
            "ja" to "バウハウス調整式カンチレバータスクランプ",
            "ko" to "바우하우스 조절식 캔틸레버 작업등",
            "th" to "โคมไฟทำงานแขนยื่นปรับได้สไตล์ Bauhaus"
        ),
        "asset_furn_04_title" to mapOf(
            "zh-Hant" to "北歐極簡模組收納櫃",
            "en" to "Nordic Minimal Modular Credenza",
            "zh-Hans" to "北欧极简模块收纳柜",
            "ja" to "北欧ミニマル・モジュラー収納キャビネット",
            "ko" to "북유럽 미니멀 모듈형 수납장",
            "th" to "ตู้เก็บของโมดูลาร์มินิมอลสไตล์นอร์ดิก"
        ),
        "asset_hard_01_title" to mapOf(
            "zh-Hant" to "ISO 4762 內六角圓柱頭螺栓",
            "en" to "ISO 4762 Hex Socket Head Cap Screw",
            "zh-Hans" to "ISO 4762 内六角圆柱头螺栓",
            "ja" to "ISO 4762 六角穴付きボルト",
            "ko" to "ISO 4762 육각 소켓 헤드 캡 스크루",
            "th" to "สกรูหัวจมทรงกระบอกหกเหลี่ยม ISO 4762"
        ),
        "asset_hard_02_title" to mapOf(
            "zh-Hant" to "DIN 7991 沉頭內六角螺釘",
            "en" to "DIN 7991 Hex Socket Countersunk Screw",
            "zh-Hans" to "DIN 7991 沉头内六角螺钉",
            "ja" to "DIN 7991 六角穴付き皿ねじ",
            "ko" to "DIN 7991 육각 소켓 접시머리 나사",
            "th" to "สกรูหัวฝังหกเหลี่ยม DIN 7991"
        ),
        "asset_hard_03_title" to mapOf(
            "zh-Hant" to "六角法蘭面防鬆螺母",
            "en" to "Hex Flange Lock Nut",
            "zh-Hans" to "六角法兰面防松螺母",
            "ja" to "六角フランジロックナット",
            "ko" to "육각 플랜지 잠금 너트",
            "th" to "น็อตล็อกหน้าแปลนหกเหลี่ยม"
        ),
        "asset_hard_04_title" to mapOf(
            "zh-Hant" to "封閉型抽芯盲鉚釘",
            "en" to "Closed-End Blind Rivet",
            "zh-Hans" to "封闭型抽芯盲铆钉",
            "ja" to "密閉型ブラインドリベット",
            "ko" to "폐쇄형 블라인드 리벳",
            "th" to "รีเวทตาบอดปลายปิด"
        ),
        "asset_hard_05_title" to mapOf(
            "zh-Hant" to "圓柱螺旋壓縮彈簧",
            "en" to "Cylindrical Helical Compression Spring",
            "zh-Hans" to "圆柱螺旋压缩弹簧",
            "ja" to "円筒コイル圧縮ばね",
            "ko" to "원통형 헬리컬 압축 스프링",
            "th" to "สปริงอัดขดเกลียวทรงกระบอก"
        ),
        "asset_hard_06_title" to mapOf(
            "zh-Hant" to "90° 強化沖壓直角固定角鐵",
            "en" to "90° Reinforced Stamped L-Bracket",
            "zh-Hans" to "90° 强化冲压直角固定角码",
            "ja" to "90° 補強プレスL字ブラケット",
            "ko" to "90° 보강 프레스 L 브래킷",
            "th" to "ฉากยึดตัว L ปั๊มขึ้นรูปเสริมแรง 90°"
        ),
        "asset_ia_01_title" to mapOf(
            "zh-Hant" to "階層式站點地圖與樹狀導航節點",
            "en" to "Hierarchical Sitemap and Tree Navigation Nodes",
            "zh-Hans" to "层级式站点地图与树状导航节点",
            "ja" to "階層型サイトマップとツリーナビゲーションノード",
            "ko" to "계층형 사이트맵 및 트리 내비게이션 노드",
            "th" to "แผนผังเว็บไซต์แบบลำดับชั้นและโหนดนำทางแบบต้นไม้"
        ),
        "asset_ia_02_title" to mapOf(
            "zh-Hant" to "使用者狀態機躍遷流程圖",
            "en" to "User Journey State-Machine Transition Flowchart",
            "zh-Hans" to "用户状态机跃迁流程图",
            "ja" to "ユーザージャーニー状態遷移フローチャート",
            "ko" to "사용자 여정 상태 머신 전이 흐름도",
            "th" to "ผังงานการเปลี่ยนสถานะของผู้ใช้แบบ State Machine"
        ),
        "asset_library" to mapOf(
            "zh-Hant" to "素材圖庫",
            "en" to "Asset Library",
            "zh-Hans" to "素材图库",
            "ja" to "アセットライブラリ",
            "ko" to "에셋 라이브러리",
            "th" to "คลังแอสเซท"
        ),
        "asset_library_desc" to mapOf(
            "zh-Hant" to "涵蓋機構設計、實體產品 (3C、汽車、家具)、五金零件與數位線框",
            "en" to "Mechanisms, Physical Products (3C, Auto, Furniture), Hardware & Digital",
            "zh-Hans" to "涵盖机构设计、实体产品 (3C、汽车、家具)、五金零件与数字线框",
            "ja" to "機構設計、製品(3C、自動車、家具)、金物、デジタルUI部品",
            "ko" to "기구 설계, 실제 제품(3C, 자동차, 가구), 하드웨어 부품 및 디지털 와이어프레임",
            "th" to "ครอบคลุมการออกแบบกลไก, ผลิตภัณฑ์จริง (3C, รถยนต์, เฟอร์นิเจอร์), ฮาร์ดแวร์ และดิจิทัล"
        ),
        "asset_mech_01_title" to mapOf(
            "zh-Hant" to "漸開線正齒輪組",
            "en" to "Involute Spur Gear Set",
            "zh-Hans" to "渐开线直齿轮组",
            "ja" to "インボリュート平歯車セット",
            "ko" to "인벌류트 평기어 세트",
            "th" to "ชุดเฟืองตรงอินโวลูต"
        ),
        "asset_mech_02_title" to mapOf(
            "zh-Hant" to "平面圓柱滾子軸承",
            "en" to "Cylindrical Roller Bearing",
            "zh-Hans" to "平面圆柱滚子轴承",
            "ja" to "円筒ころ軸受",
            "ko" to "원통 롤러 베어링",
            "th" to "ตลับลูกปืนลูกกลิ้งทรงกระบอก"
        ),
        "asset_mech_03_title" to mapOf(
            "zh-Hant" to "精密微型滾珠螺桿滑軌",
            "en" to "Precision Miniature Ball-Screw Linear Guide",
            "zh-Hans" to "精密微型滚珠丝杠滑轨",
            "ja" to "精密ミニチュアボールねじリニアガイド",
            "ko" to "정밀 소형 볼스크루 리니어 가이드",
            "th" to "รางสไลด์บอลสกรูขนาดเล็กความแม่นยำสูง"
        ),
        "asset_mech_04_title" to mapOf(
            "zh-Hant" to "等徑盤形凸輪連桿機構",
            "en" to "Constant-Diameter Disk Cam and Follower Mechanism",
            "zh-Hans" to "等径盘形凸轮连杆机构",
            "ja" to "等径円板カム・フォロワ機構",
            "ko" to "등경 원판 캠 및 종동절 기구",
            "th" to "กลไกจานแคมเส้นผ่านศูนย์กลางคงที่และลูกตาม"
        ),
        "asset_mech_05_title" to mapOf(
            "zh-Hant" to "NEMA 17 混合式步進馬達",
            "en" to "NEMA 17 Hybrid Stepper Motor",
            "zh-Hans" to "NEMA 17 混合式步进电机",
            "ja" to "NEMA 17 ハイブリッドステッピングモーター",
            "ko" to "NEMA 17 하이브리드 스테핑 모터",
            "th" to "สเต็ปเปอร์มอเตอร์ไฮบริด NEMA 17"
        ),
        "asset_mech_06_title" to mapOf(
            "zh-Hant" to "動態外骨骼關節連桿",
            "en" to "Dynamic Exoskeleton Joint Linkage",
            "zh-Hans" to "动态外骨骼关节连杆",
            "ja" to "動的外骨格ジョイントリンク機構",
            "ko" to "동적 외골격 관절 링크 기구",
            "th" to "ชุดข้อเชื่อมข้อต่อโครงกระดูกภายนอกแบบไดนามิก"
        ),
        "asset_mold_01_title" to mapOf(
            "zh-Hant" to "注塑模具 1.5° 拔模角與分模線剖面",
            "en" to "Injection Mold 1.5° Draft Angle and Parting-Line Section",
            "zh-Hans" to "注塑模具 1.5° 拔模角与分型线剖面",
            "ja" to "射出成形金型の1.5°抜き勾配とパーティングライン断面",
            "ko" to "사출 금형 1.5° 드래프트 각도 및 파팅 라인 단면",
            "th" to "หน้าตัดแม่พิมพ์ฉีด 1.5° มุมถอดแบบและเส้นแบ่งแม่พิมพ์"
        ),
        "asset_mold_02_title" to mapOf(
            "zh-Hant" to "塑膠件均勻壁厚與加強筋規範",
            "en" to "Plastic Part Uniform Wall Thickness and Rib Design Rules",
            "zh-Hans" to "塑胶件均匀壁厚与加强筋规范",
            "ja" to "樹脂部品の均一肉厚とリブ設計規則",
            "ko" to "플라스틱 부품 균일 벽두께 및 리브 설계 규칙",
            "th" to "ข้อกำหนดความหนาผนังสม่ำเสมอและซี่เสริมแรงของชิ้นส่วนพลาสติก"
        ),
        "asset_mold_03_title" to mapOf(
            "zh-Hant" to "螺絲自攻牙注塑凸柱結構",
            "en" to "Self-Tapping Screw Boss and Gusset Structure",
            "zh-Hans" to "螺丝自攻牙注塑凸柱结构",
            "ja" to "タッピンねじ用樹脂ボス・ガセット構造",
            "ko" to "셀프 태핑 나사용 사출 보스 및 거싯 구조",
            "th" to "โครงสร้างบอสฉีดขึ้นรูปและค้ำยันสำหรับสกรูปล่อยเกลียว"
        ),
        "asset_motif_01_title" to mapOf(
            "zh-Hant" to "包浩斯幾何構成裝飾組",
            "en" to "Bauhaus Geometric Motif Set",
            "zh-Hans" to "包豪斯几何构成装饰组",
            "ja" to "バウハウス幾何構成モチーフセット",
            "ko" to "바우하우스 기하 구성 모티프 세트",
            "th" to "ชุดลวดลายเรขาคณิตแบบ Bauhaus"
        ),
        "asset_motif_02_title" to mapOf(
            "zh-Hant" to "參數化 Voronoi 泰森多邊形紋樣",
            "en" to "Parametric Voronoi Tessellation Pattern",
            "zh-Hans" to "参数化 Voronoi 泰森多边形纹样",
            "ja" to "パラメトリックVoronoiボロノイ分割パターン",
            "ko" to "파라메트릭 보로노이 테셀레이션 패턴",
            "th" to "ลวดลายเทสเซลเลชัน Voronoi แบบพาราเมตริก"
        ),
        "asset_motif_03_title" to mapOf(
            "zh-Hant" to "未來賽博賽道光軌幾何",
            "en" to "Futuristic Cyber Circuit Light-Track Geometry",
            "zh-Hans" to "未来赛博赛道光轨几何",
            "ja" to "未来的サイバー回路ライトトラック幾何",
            "ko" to "미래형 사이버 회로 라이트 트랙 기하",
            "th" to "เรขาคณิตเส้นแสงวงจรไซเบอร์แนวอนาคต"
        ),
        "asset_motion_01_title" to mapOf(
            "zh-Hant" to "三次貝茲曲線動效時間函數",
            "en" to "Cubic Bezier Animation Timing Function",
            "zh-Hans" to "三次贝塞尔曲线动效时间函数",
            "ja" to "3次ベジェ曲線のアニメーションタイミング関数",
            "ko" to "3차 베지어 애니메이션 타이밍 함수",
            "th" to "ฟังก์ชันเวลาแอนิเมชันเส้นโค้งคิวบิกเบซิเยร์"
        ),
        "asset_motion_02_title" to mapOf(
            "zh-Hant" to "彈簧阻尼系統動態示意",
            "en" to "Spring-Mass-Damper System Dynamics Diagram",
            "zh-Hans" to "弹簧阻尼系统动态示意",
            "ja" to "ばね・質量・ダンパ系の動的模式図",
            "ko" to "스프링-질량-댐퍼 시스템 동역학 도식",
            "th" to "แผนภาพพลวัตระบบสปริง-มวล-แดมเปอร์"
        ),
        "asset_pipe_01_title" to mapOf(
            "zh-Hant" to "雙作用氣動滑台氣缸規格",
            "en" to "Dual-Acting Pneumatic Slide Cylinder Specification",
            "zh-Hans" to "双作用气动滑台气缸规格",
            "ja" to "複動形空圧スライドシリンダ仕様",
            "ko" to "복동식 공압 슬라이드 실린더 규격",
            "th" to "สเปกกระบอกลมสไลด์แบบสองทาง"
        ),
        "asset_pipe_02_title" to mapOf(
            "zh-Hant" to "快插式直角節流閥管路接頭",
            "en" to "One-Touch Elbow Speed-Controller Fitting",
            "zh-Hans" to "快插式直角节流阀管路接头",
            "ja" to "ワンタッチエルボスピードコントローラ継手",
            "ko" to "원터치 엘보 스피드 컨트롤러 피팅",
            "th" to "ข้อต่อควบคุมความเร็วแบบงอฉากชนิดเสียบเร็ว"
        ),
        "asset_sheet_01_title" to mapOf(
            "zh-Hant" to "鈑金 90° V 型折彎 K-Factor 計算展開圖",
            "en" to "Sheet-Metal 90° V-Bend K-Factor Flat-Pattern Calculation",
            "zh-Hans" to "钣金 90° V 型折弯 K-Factor 计算展开图",
            "ja" to "板金90°V曲げKファクター展開計算図",
            "ko" to "판금 90° V 벤딩 K-Factor 전개 계산도",
            "th" to "แบบคลี่คำนวณ K-Factor งานพับโลหะแผ่น V 90°"
        ),
        "asset_sheet_02_title" to mapOf(
            "zh-Hant" to "CNC 銑削內直角狗骨狀清角結構",
            "en" to "CNC-Milled Internal-Corner Dogbone Relief",
            "zh-Hans" to "CNC 铣削内直角狗骨状清角结构",
            "ja" to "CNC切削内角用ドッグボーン逃げ形状",
            "ko" to "CNC 밀링 내부 직각 도그본 릴리프 구조",
            "th" to "โครงสร้างเว้นมุม Dogbone สำหรับมุมในงานกัด CNC"
        ),
        "asset_sheet_03_title" to mapOf(
            "zh-Hant" to "沖孔自鉚壓鉚螺母柱",
            "en" to "Punched Self-Clinching Standoff",
            "zh-Hans" to "冲孔自铆压铆螺母柱",
            "ja" to "打抜き穴用セルフクリンチングスタンドオフ",
            "ko" to "펀칭 홀용 셀프 클린칭 스탠드오프",
            "th" to "เสารองสกรูแบบอัดย้ำตัวเองสำหรับรูเจาะ"
        ),
        "asset_surf_01_title" to mapOf(
            "zh-Hant" to "陽極氧化膜厚與表面噴砂目數對照",
            "en" to "Anodizing Film Thickness and Sandblast Grit Reference",
            "zh-Hans" to "阳极氧化膜厚与表面喷砂目数对照",
            "ja" to "アルマイト皮膜厚とブラスト番手の対応表",
            "ko" to "아노다이징 피막 두께와 샌드블라스트 입도 기준",
            "th" to "ตารางเทียบความหนาฟิล์มอโนไดซ์กับเบอร์เม็ดทรายพ่น"
        ),
        "asset_surf_02_title" to mapOf(
            "zh-Hant" to "表面粗糙度 Ra 算術平均標註規",
            "en" to "Surface Roughness Ra Arithmetic-Mean Reference Gauge",
            "zh-Hans" to "表面粗糙度 Ra 算术平均标注规",
            "ja" to "表面粗さRa算術平均表示ゲージ",
            "ko" to "표면 거칠기 Ra 산술평균 표기 게이지",
            "th" to "เกจอ้างอิงค่าความขรุขระผิว Ra แบบค่าเฉลี่ยเลขคณิต"
        ),
        "asset_token_01_title" to mapOf(
            "zh-Hant" to "8pt 空間網格與間距度量尺",
            "en" to "8-Point Spacing Grid and Scale Ruler",
            "zh-Hans" to "8pt 空间网格与间距度量尺",
            "ja" to "8ptスペーシンググリッドと間隔スケール定規",
            "ko" to "8pt 공간 그리드 및 간격 스케일 자",
            "th" to "กริดระยะ 8pt และไม้บรรทัดสเกลระยะห่าง"
        ),
        "asset_token_02_title" to mapOf(
            "zh-Hant" to "設計語意色彩層級與對比度矩陣",
            "en" to "Semantic Color Token Hierarchy and Contrast Matrix",
            "zh-Hans" to "设计语义色彩层级与对比度矩阵",
            "ja" to "セマンティックカラー階層とコントラスト行列",
            "ko" to "시맨틱 컬러 토큰 계층 및 대비 매트릭스",
            "th" to "ลำดับชั้นโทเคนสีเชิงความหมายและเมทริกซ์คอนทราสต์"
        ),
        "asset_typo_01_title" to mapOf(
            "zh-Hant" to "拉丁字體排印五線度量基準",
            "en" to "Latin Typeface Anatomy and Baseline Metrics",
            "zh-Hans" to "拉丁字体排印五线度量基准",
            "ja" to "ラテン書体の字形構造とベースライン指標",
            "ko" to "라틴 서체 구조와 기준선 메트릭",
            "th" to "เมตริกโครงสร้างตัวอักษรละตินและเส้นฐาน"
        ),
        "asset_typo_02_title" to mapOf(
            "zh-Hant" to "中文字型永字八法九宮格",
            "en" to "Chinese Glyph Nine-Grid for Eight Principles of Yong",
            "zh-Hans" to "中文字体永字八法九宫格",
            "ja" to "永字八法の漢字九分割グリッド",
            "ko" to "영자팔법 한자 글리프 9분할 그리드",
            "th" to "ตารางเก้าช่องตัวอักษรจีนตามหลักแปดวิธีของหย่ง"
        ),
        "asset_typo_03_title" to mapOf(
            "zh-Hant" to "版面編排字級模矩比例尺",
            "en" to "Modular Type-Scale Layout Ruler",
            "zh-Hans" to "版面编排字号模数比例尺",
            "ja" to "組版用モジュラータイプスケール定規",
            "ko" to "편집 디자인용 모듈러 타입 스케일 자",
            "th" to "ไม้บรรทัดสเกลตัวอักษรแบบโมดูลาร์สำหรับจัดหน้า"
        ),
        "asset_ui_01_title" to mapOf(
            "zh-Hant" to "iOS 與 Material 3 雙系統導航列對照",
            "en" to "iOS and Material 3 Navigation Bar Comparison",
            "zh-Hans" to "iOS 与 Material 3 双系统导航栏对照",
            "ja" to "iOSとMaterial 3のナビゲーションバー比較",
            "ko" to "iOS와 Material 3 내비게이션 바 비교",
            "th" to "การเปรียบเทียบแถบนำทาง iOS และ Material 3"
        ),
        "asset_ui_02_title" to mapOf(
            "zh-Hant" to "底部操作卡片 Bottom Sheet 手勢容器",
            "en" to "Bottom Sheet Gesture Container",
            "zh-Hans" to "底部操作卡片 Bottom Sheet 手势容器",
            "ja" to "ボトムシート・ジェスチャーコンテナ",
            "ko" to "바텀 시트 제스처 컨테이너",
            "th" to "คอนเทนเนอร์ Bottom Sheet สำหรับท่าทางสัมผัส"
        ),
        "attach_none" to mapOf(
            "zh-Hant" to "不附加（僅儲存為獨立錄音）",
            "en" to "None (Save as standalone audio)",
            "zh-Hans" to "不附加（仅保存为独立录音）",
            "ja" to "添付しない（独立した音声として保存）",
            "ko" to "첨부 안 함 (단독 오디오로 저장)",
            "th" to "ไม่แนบ (บันทึกเป็นไฟล์เสียงเดี่ยว)"
        ),
        "attach_picker_label" to mapOf(
            "zh-Hant" to "附加至筆記",
            "en" to "Attach to Note",
            "zh-Hans" to "附加至笔记",
            "ja" to "ノートに添付",
            "ko" to "노트에 첨부",
            "th" to "แนบกับบันทึก"
        ),
        "attach_to_note" to mapOf(
            "zh-Hant" to "附加至指定筆記（錄音即時同步至筆記畫布）",
            "en" to "Attach to Note (Instant sync to note canvas)",
            "zh-Hans" to "附加至指定笔记（录音即时同步至笔记画布）",
            "ja" to "指定ノートに添付（筆跡キャンバスに即時同期）",
            "ko" to "지정 노트에 첨부 (캔버스에 실시간 동기화)",
            "th" to "แนบกับบันทึกที่กำหนด (ซิงค์กับผืนผ้าใบทันที)"
        )
    )

    private fun part2(): Map<String, Map<String, String>> = mapOf(
        "attached_audio" to mapOf(
            "zh-Hant" to "筆記隨附錄音",
            "en" to "Attached Audio",
            "zh-Hans" to "笔记随附录音",
            "ja" to "ノート添付音声",
            "ko" to "노트 첨부 오디오",
            "th" to "เสียงที่แนบมากับบันทึก"
        ),
        "audio_empty_hint" to mapOf(
            "zh-Hant" to "錄音長度為零或未偵測到聲音。",
            "en" to "The recording contains no audio or is empty.",
            "zh-Hans" to "录音长度为零或未检测到声音。",
            "ja" to "録音の長さがゼロか、音声が検出されませんでした。",
            "ko" to "녹음 길이가 0이거나 음성이 감지되지 않았습니다.",
            "th" to "การบันทึกไม่มีเสียงหรือว่างเปล่า"
        ),
        "audio_file_missing" to mapOf(
            "zh-Hant" to "找不到音訊檔",
            "en" to "Audio file not found",
            "zh-Hans" to "找不到音讯档",
            "ja" to "音声ファイルが見つかりません",
            "ko" to "오디오 파일을 찾을 수 없습니다",
            "th" to "ไม่พบไฟล์เสียง"
        ),
        "audio_hint" to mapOf(
            "zh-Hant" to "點擊播放 · 筆劃時間精確對齊",
            "en" to "Tap to Play · Ink & Audio Aligned",
            "zh-Hans" to "点击播放 · 笔划时间精确对齐",
            "ja" to "タップして再生 · 筆跡と音声の完全同期",
            "ko" to "탭하여 재생 · 필기와 오디오 정밀 동기화",
            "th" to "แตะเพื่อเล่น · การเขียนและเสียงตรงกันอย่างแม่นยำ"
        ),
        "audio_karaoke_sync" to mapOf(
            "zh-Hant" to "聲筆動態同步",
            "en" to "Audio-Ink Sync",
            "zh-Hans" to "声笔动态同步",
            "ja" to "音声・手書き同期",
            "ko" to "음성-필기 동기화",
            "th" to "การซิงค์เสียงกับลายมือ"
        ),
        "audio_pause" to mapOf(
            "zh-Hant" to "暫停",
            "en" to "Pause",
            "zh-Hans" to "暂停",
            "ja" to "一時停止",
            "ko" to "일시정지",
            "th" to "หยุดชั่วคราว"
        ),
        "audio_play" to mapOf(
            "zh-Hant" to "播放",
            "en" to "Play",
            "zh-Hans" to "播放",
            "ja" to "再生",
            "ko" to "재생",
            "th" to "เล่น"
        ),
        "audio_playback_align" to mapOf(
            "zh-Hant" to "真實音訊播放與對齊",
            "en" to "Real Audio Playback & Alignment",
            "zh-Hans" to "真实音频播放与对齐",
            "ja" to "リアル音声再生と同期",
            "ko" to "실시간 오디오 재생 및 동기화",
            "th" to "เล่นเสียงจริงและจัดตำแหน่ง"
        ),
        "audio_playback_failed" to mapOf(
            "zh-Hant" to "這段錄音無法播放。請關閉其他占用麥克風或喇叭的 App 後再試一次。",
            "en" to "This recording could not be played. Close other apps that use the microphone or speaker and try again.",
            "zh-Hans" to "这段录音无法播放。请关闭其他占用麦克风或扬声器的 App 后再试一次。",
            "ja" to "この録音を再生できませんでした。マイクやスピーカーを使用している他のアプリを閉じて、もう一度お試しください。",
            "ko" to "이 녹음을 재생할 수 없습니다. 마이크나 스피커를 사용하는 다른 앱을 닫고 다시 시도하세요.",
            "th" to "ไม่สามารถเล่นการบันทึกเสียงนี้ได้ ปิดแอปอื่นที่ใช้ไมโครโฟนหรือลำโพงแล้วลองอีกครั้ง"
        ),
        "audio_playing" to mapOf(
            "zh-Hant" to "同步播放中",
            "en" to "Playing Synced Audio",
            "zh-Hans" to "同步播放中",
            "ja" to "同期再生中",
            "ko" to "동기화 재생 중",
            "th" to "กำลังเล่นเสียงซิงค์"
        ),
        "audio_rec_title" to mapOf(
            "zh-Hant" to "語音錄音與對齊",
            "en" to "Audio Recording & Alignment",
            "zh-Hans" to "语音录音与对齐",
            "ja" to "音声録音と同期",
            "ko" to "오디오 녹음 및 동기화",
            "th" to "การบันทึกเสียงและการจัดตำแหน่ง"
        ),
        "audio_seek_ink" to mapOf(
            "zh-Hant" to "點擊筆跡跳轉錄音時間",
            "en" to "Tap ink to jump audio timestamp",
            "zh-Hans" to "点击笔迹跳转录音时间",
            "ja" to "手書きをタップして音声をシーク",
            "ko" to "필기를 탭하여 오디오 탐색",
            "th" to "แตะลายมือเพื่อไปยังเวลาเสียง"
        ),
        "auth_busy" to mapOf(
            "zh-Hant" to "登入處理中，請勿重複點擊",
            "en" to "Sign-in is in progress. Please don't tap again.",
            "zh-Hans" to "登录处理中，请勿重复点击",
            "ja" to "サインイン処理中です。もう一度タップしないでください。",
            "ko" to "로그인 처리 중입니다. 다시 누르지 마세요.",
            "th" to "กำลังลงชื่อเข้าใช้ โปรดอย่าแตะซ้ำ"
        ),
        "auth_cannot_present" to mapOf(
            "zh-Hant" to "無法啟動系統登入視窗，請重試",
            "en" to "Could not open the system sign-in window. Please try again.",
            "zh-Hans" to "无法启动系统登录窗口，请重试",
            "ja" to "システムのサインインウィンドウを開けませんでした。もう一度お試しください。",
            "ko" to "시스템 로그인 창을 열 수 없습니다. 다시 시도하세요.",
            "th" to "เปิดหน้าต่างลงชื่อเข้าใช้ของระบบไม่ได้ โปรดลองอีกครั้ง"
        ),
        "auth_timeout" to mapOf(
            "zh-Hant" to "登入逾時，請重新嘗試",
            "en" to "Sign-in timed out. Please try again.",
            "zh-Hans" to "登录超时，请重新尝试",
            "ja" to "サインインがタイムアウトしました。もう一度お試しください。",
            "ko" to "로그인 시간이 초과되었습니다. 다시 시도하세요.",
            "th" to "การลงชื่อเข้าใช้หมดเวลา โปรดลองอีกครั้ง"
        ),
        "back_to_home" to mapOf(
            "zh-Hant" to "回到首頁",
            "en" to "Back to home",
            "zh-Hans" to "回到首页",
            "ja" to "ホームに戻る",
            "ko" to "홈으로",
            "th" to "กลับหน้าหลัก"
        ),
        "backup_corrupted" to mapOf(
            "zh-Hant" to "%@ 個檔案損毀，未寫入（其餘已復原）",
            "en" to "%@ files were corrupted and skipped (the rest were restored)",
            "zh-Hans" to "%@ 个文件损坏，未写入（其余已恢复）",
            "ja" to "%@ 件が破損していたためスキップしました（残りは復元済み）",
            "ko" to "%@개 파일이 손상되어 건너뛰었습니다(나머지는 복원됨)",
            "th" to "%@ ไฟล์เสียหายจึงข้ามไป (ที่เหลือกู้คืนแล้ว)"
        ),
        "backup_create" to mapOf(
            "zh-Hant" to "建立備份檔",
            "en" to "Create Backup",
            "zh-Hans" to "创建备份文件",
            "ja" to "バックアップを作成",
            "ko" to "백업 만들기",
            "th" to "สร้างไฟล์สำรอง"
        ),
        "backup_create_desc" to mapOf(
            "zh-Hant" to "把筆記、手繪、錄音與設定存成一個檔案",
            "en" to "Save notes, handwriting, recordings and settings into one file",
            "zh-Hans" to "把笔记、手绘、录音与设置存成一个文件",
            "ja" to "ノート・手書き・録音・設定を 1 つのファイルに保存",
            "ko" to "노트·손글씨·녹음·설정을 파일 하나로 저장",
            "th" to "บันทึกโน้ต ลายมือ เสียง และการตั้งค่าเป็นไฟล์เดียว"
        ),
        "backup_created" to mapOf(
            "zh-Hant" to "已建立備份：%1@ 個檔案、%2@",
            "en" to "Backup created: %1@ files, %2@",
            "zh-Hans" to "已创建备份：%1@ 个文件、%2@",
            "ja" to "バックアップを作成しました：%1@ 件、%2@",
            "ko" to "백업을 만들었습니다: %1@개 파일, %2@",
            "th" to "สร้างไฟล์สำรองแล้ว: %1@ ไฟล์ %2@"
        ),
        "backup_err_read_file" to mapOf(
            "zh-Hant" to "無法讀取選取的檔案",
            "en" to "Could not read the selected file",
            "zh-Hans" to "无法读取选取的文件",
            "ja" to "選択したファイルを読み取れませんでした",
            "ko" to "선택한 파일을 읽을 수 없습니다",
            "th" to "อ่านไฟล์ที่เลือกไม่ได้"
        ),
        "backup_explainer" to mapOf(
            "zh-Hant" to "備份檔包含筆記本、筆記頁、手繪、圖片、錄音、資料夾結構與 App 設定。把它存到雲端或電腦，App 毀損時可一鍵復原。",
            "en" to "The backup contains notebooks, pages, handwriting, images, recordings, folder structure and app settings. Keep it in the cloud or on a computer — one tap restores everything if the app breaks.",
            "zh-Hans" to "备份文件包含笔记本、笔记页、手绘、图片、录音、文件夹结构与 App 设置。把它存到云端或电脑，App 损坏时可一键恢复。",
            "ja" to "バックアップにはノート、ページ、手書き、画像、録音、フォルダ構成、アプリ設定が含まれます。クラウドやパソコンに保存しておけば、アプリが壊れてもワンタップで復元できます。",
            "ko" to "백업에는 노트북, 페이지, 손글씨, 이미지, 녹음, 폴더 구조, 앱 설정이 들어 있습니다. 클라우드나 컴퓨터에 보관해 두면 앱이 손상돼도 한 번에 복원할 수 있습니다.",
            "th" to "ไฟล์สำรองมีสมุดบันทึก หน้า ลายมือ รูปภาพ ไฟล์เสียง โครงสร้างโฟลเดอร์ และการตั้งค่าแอป เก็บไว้บนคลาวด์หรือคอมพิวเตอร์ แล้วกู้คืนทั้งหมดได้ในคลิกเดียวหากแอปเสียหาย"
        ),
        "backup_invalid" to mapOf(
            "zh-Hant" to "這不是 Kairumo 的備份檔",
            "en" to "This is not a Kairumo backup file",
            "zh-Hans" to "这不是 Kairumo 的备份文件",
            "ja" to "Kairumo のバックアップファイルではありません",
            "ko" to "Kairumo 백업 파일이 아닙니다",
            "th" to "นี่ไม่ใช่ไฟล์สำรองของ Kairumo"
        ),
        "backup_restore" to mapOf(
            "zh-Hant" to "從備份復原",
            "en" to "Restore from Backup",
            "zh-Hans" to "从备份恢复",
            "ja" to "バックアップから復元",
            "ko" to "백업에서 복원",
            "th" to "กู้คืนจากไฟล์สำรอง"
        ),
        "backup_restore_desc" to mapOf(
            "zh-Hant" to "App 毀損或換裝置時，一鍵把資料放回來",
            "en" to "One tap to put everything back after a crash or a new device",
            "zh-Hans" to "App 损坏或换设备时，一键把数据放回来",
            "ja" to "アプリの破損や機種変更時にワンタップで復元",
            "ko" to "앱 손상이나 기기 변경 시 한 번에 복원",
            "th" to "กู้คืนทุกอย่างได้ในคลิกเดียวเมื่อแอปเสียหรือเปลี่ยนเครื่อง"
        ),
        "backup_restored" to mapOf(
            "zh-Hant" to "已復原 %@ 個檔案，請重新啟動 App",
            "en" to "%@ files restored — please restart the app",
            "zh-Hans" to "已恢复 %@ 个文件，请重新启动 App",
            "ja" to "%@ 件を復元しました。アプリを再起動してください",
            "ko" to "%@개 파일을 복원했습니다. 앱을 다시 시작해 주세요",
            "th" to "กู้คืนแล้ว %@ ไฟล์ โปรดเปิดแอปใหม่"
        ),
        "backup_safety_note" to mapOf(
            "zh-Hant" to "復原之前會自動把目前的資料另存一份，出事時回得去。",
            "en" to "Your current data is backed up automatically before restoring, so you can go back.",
            "zh-Hans" to "恢复之前会自动把当前数据另存一份，出事时回得去。",
            "ja" to "復元の前に現在のデータを自動でバックアップするので、元に戻せます。",
            "ko" to "복원 전에 현재 데이터를 자동으로 백업하므로 되돌릴 수 있습니다.",
            "th" to "ระบบจะสำรองข้อมูลปัจจุบันอัตโนมัติก่อนกู้คืน คุณจึงย้อนกลับได้"
        ),
        "backup_section" to mapOf(
            "zh-Hant" to "備份與復原",
            "en" to "Backup & Restore",
            "zh-Hans" to "备份与恢复",
            "ja" to "バックアップと復元",
            "ko" to "백업 및 복원",
            "th" to "สำรองและกู้คืน"
        ),
        "backup_snapshot" to mapOf(
            "zh-Hant" to "備份快照",
            "en" to "Backup Snapshot",
            "zh-Hans" to "备份快照",
            "ja" to "バックアップスナップショット",
            "ko" to "백업 스냅샷",
            "th" to "สแนปช็อตสำรอง"
        ),
        "backup_snapshot_desc" to mapOf(
            "zh-Hant" to "將單本筆記匯出成一個 .padnote 檔，可放到雲端硬碟、本機檔案或給另一套 viewer app 讀取",
            "en" to "Export one notebook as a single .padnote file for cloud drives, local storage or another viewer app",
            "zh-Hans" to "将单本笔记导出成一个 .padnote 文件，可放到云端硬盘、本机档案或给另一套 viewer app 读取",
            "ja" to "1 冊のノートを単一の .padnote ファイルとして書き出し、クラウドドライブ、ローカル保存、別のビューアアプリで使えます",
            "ko" to "노트북 하나를 단일 .padnote 파일로 내보내 클라우드 드라이브, 로컬 저장소 또는 다른 뷰어 앱에서 사용할 수 있습니다",
            "th" to "ส่งออกสมุดบันทึกหนึ่งเล่มเป็นไฟล์ .padnote ไฟล์เดียว สำหรับคลาวด์ไดรฟ์ พื้นที่ในเครื่อง หรือแอปดูไฟล์อื่น"
        ),
        "backup_snapshot_picker_title" to mapOf(
            "zh-Hant" to "選擇要建立快照的筆記",
            "en" to "Choose a notebook to snapshot",
            "zh-Hans" to "选择要建立快照的笔记",
            "ja" to "スナップショットにするノートを選択",
            "ko" to "스냅샷으로 만들 노트북 선택",
            "th" to "เลือกสมุดบันทึกที่จะทำสแนปช็อต"
        ),
        "bonjour_permission_hint_ios" to mapOf(
            "zh-Hant" to "若需同 Wi-Fi 下其他裝置自動看見此房間，請前往「設定」>「Kairumo」>開啟「區域網路」。",
            "en" to "To let nearby devices discover this room automatically, please enable Local Network in Settings > Kairumo.",
            "zh-Hans" to "若需同 Wi-Fi 下其他设备自动发现此房间，请前往“设置”>“Kairumo”>开启“本地网络”。",
            "ja" to "近くの端末がこのルームを自動検出できるようにするには、「設定」>「Kairumo」>「ローカルネットワーク」をオンにしてください。",
            "ko" to "주변 기기가 이 방을 자동으로 찾을 수 있도록 '설정' > 'Kairumo' > '로컬 네트워크'를 켜주세요.",
            "th" to "หากต้องการให้อุปกรณ์ใกล้เคียงค้นพบห้องนี้โดยอัตโนมัติ โปรดเปิด เครือข่ายภายใน ใน การตั้งค่า > Kairumo"
        ),
        "bonjour_permission_hint_mac" to mapOf(
            "zh-Hant" to "若需同 Wi-Fi 下其他裝置自動看見此房間，請前往「系統設定」>「隱私權與安全性」>「區域網路」，確認 Kairumo 為開啟狀態。",
            "en" to "To let nearby devices discover this room automatically, go to System Settings > Privacy & Security > Local Network and allow Kairumo.",
            "zh-Hans" to "若需同 Wi-Fi 下其他设备自动发现此房间，请前往“系统设置”>“隐私与安全性”>“本地网络”，允许 Kairumo。",
            "ja" to "近くの端末がこのルームを自動検出できるようにするには、「システム設定」>「プライバシーとセキュリティ」>「ローカルネットワーク」で Kairumo を許可してください。",
            "ko" to "주변 기기가 이 방을 자동으로 찾을 수 있도록 '시스템 설정' > '개인정보 보호 및 보안' > '로컬 네트워크'에서 Kairumo를 허용하세요.",
            "th" to "หากต้องการให้อุปกรณ์ใกล้เคียงค้นพบห้องนี้โดยอัตโนมัติ ให้ไปที่ การตั้งค่าระบบ > ความเป็นส่วนตัวและความปลอดภัย > เครือข่ายภายใน แล้วอนุญาต Kairumo"
        ),
        "bonjour_permission_title" to mapOf(
            "zh-Hant" to "跨裝置自動發現提示",
            "en" to "Local Network Discovery Required",
            "zh-Hans" to "跨设备自动发现提示",
            "ja" to "ローカルネットワーク検出の設定",
            "ko" to "로컬 네트워크 자동 감지 안내",
            "th" to "การค้นหาอุปกรณ์ในเครือข่ายภายใน"
        ),
        "border_color" to mapOf(
            "zh-Hant" to "邊框顏色",
            "en" to "Border color",
            "zh-Hans" to "边框颜色",
            "ja" to "枠線の色",
            "ko" to "테두리 색",
            "th" to "สีกรอบ"
        ),
        "border_style" to mapOf(
            "zh-Hant" to "邊框樣式",
            "en" to "Border",
            "zh-Hans" to "边框样式",
            "ja" to "枠線スタイル",
            "ko" to "테두리 스타일",
            "th" to "รูปแบบกรอบ"
        ),
        "border_width" to mapOf(
            "zh-Hant" to "邊框粗細",
            "en" to "Border width",
            "zh-Hans" to "边框粗细",
            "ja" to "枠線の太さ",
            "ko" to "테두리 두께",
            "th" to "ความหนาขอบ"
        ),
        "box_width" to mapOf(
            "zh-Hant" to "方塊寬度",
            "en" to "Box width",
            "zh-Hans" to "方块宽度",
            "ja" to "ボックス幅",
            "ko" to "상자 너비",
            "th" to "ความกว้างกล่อง"
        ),
        "bridge_err_keep_audio" to mapOf(
            "zh-Hant" to "無法保留錄音與轉錄內容：%@",
            "en" to "Could not keep the recordings and transcripts: %@",
            "zh-Hans" to "无法保留录音与转录内容：%@",
            "ja" to "録音と文字起こしを保持できませんでした：%@",
            "ko" to "녹음과 받아쓰기 내용을 보존할 수 없습니다: %@",
            "th" to "เก็บการบันทึกเสียงและข้อความถอดเสียงไม่ได้: %@"
        ),
        "bridge_err_read_other" to mapOf(
            "zh-Hant" to "無法讀取其他裝置寫的內容",
            "en" to "Could not read content written by another device",
            "zh-Hans" to "无法读取其他设备写入的内容",
            "ja" to "他の端末で書かれた内容を読み取れませんでした",
            "ko" to "다른 기기에서 작성한 내용을 읽을 수 없습니다",
            "th" to "อ่านเนื้อหาที่เขียนจากอุปกรณ์อื่นไม่ได้"
        ),
        "brush_family_marking" to mapOf(
            "zh-Hant" to "標記",
            "en" to "Marking",
            "zh-Hans" to "标记",
            "ja" to "マーキング",
            "ko" to "표시",
            "th" to "ไฮไลต์"
        ),
        "brush_family_painting" to mapOf(
            "zh-Hant" to "繪畫",
            "en" to "Painting",
            "zh-Hans" to "绘画",
            "ja" to "描画",
            "ko" to "그리기",
            "th" to "วาดภาพ"
        ),
        "brush_family_writing" to mapOf(
            "zh-Hant" to "書寫",
            "en" to "Writing",
            "zh-Hans" to "书写",
            "ja" to "筆記",
            "ko" to "필기",
            "th" to "เขียน"
        ),
        "bullet_list" to mapOf(
            "zh-Hant" to "項目符號",
            "en" to "Bulleted List",
            "zh-Hans" to "项目符号",
            "ja" to "箇条書き",
            "ko" to "글머리 기호",
            "th" to "รายการสัญลักษณ์"
        ),
        "cancel" to mapOf(
            "zh-Hant" to "取消",
            "en" to "Cancel",
            "zh-Hans" to "取消",
            "ja" to "キャンセル",
            "ko" to "취소",
            "th" to "ยกเลิก"
        ),
        "cancel_selection_hint" to mapOf(
            "zh-Hant" to "取消框選，回到上一個工具",
            "en" to "Cancel the selection and go back to the previous tool",
            "zh-Hans" to "取消框选，回到上一个工具",
            "ja" to "選択を解除して前のツールに戻る",
            "ko" to "선택을 해제하고 이전 도구로 돌아가기",
            "th" to "ยกเลิกการเลือกและกลับไปยังเครื่องมือก่อนหน้า"
        ),
        "cap_arrow" to mapOf(
            "zh-Hant" to "箭頭",
            "en" to "Arrow",
            "zh-Hans" to "箭头",
            "ja" to "矢印",
            "ko" to "화살표",
            "th" to "ลูกศร"
        ),
        "cap_circle" to mapOf(
            "zh-Hant" to "圓點",
            "en" to "Circle",
            "zh-Hans" to "圆点",
            "ja" to "丸",
            "ko" to "원",
            "th" to "วงกลม"
        ),
        "cap_diamond" to mapOf(
            "zh-Hant" to "菱形",
            "en" to "Diamond",
            "zh-Hans" to "菱形",
            "ja" to "ひし形",
            "ko" to "마름모",
            "th" to "ข้าวหลามตัด"
        ),
        "cap_hollow" to mapOf(
            "zh-Hant" to "空心箭頭",
            "en" to "Hollow arrow",
            "zh-Hans" to "空心箭头",
            "ja" to "白抜き矢印",
            "ko" to "빈 화살표",
            "th" to "ลูกศรกลวง"
        ),
        "cap_none" to mapOf(
            "zh-Hant" to "無",
            "en" to "None",
            "zh-Hans" to "无",
            "ja" to "なし",
            "ko" to "없음",
            "th" to "ไม่มี"
        ),
        "card_style" to mapOf(
            "zh-Hant" to "卡片樣式",
            "en" to "Card Style",
            "zh-Hans" to "卡片样式",
            "ja" to "カードスタイル",
            "ko" to "카드 스타일",
            "th" to "รูปแบบการ์ด"
        ),
        "cat_aesthetic_comp" to mapOf(
            "zh-Hant" to "美學構圖與黃金比例",
            "en" to "Aesthetic Composition",
            "zh-Hans" to "美学构图与黄金比例",
            "ja" to "構図と黄金比",
            "ko" to "미학 구도 및 황금비율",
            "th" to "องค์ประกอบความงามและสัดส่วนทองคำ"
        ),
        "cat_all" to mapOf(
            "zh-Hant" to "全部素材",
            "en" to "All Assets",
            "zh-Hans" to "全部素材",
            "ja" to "すべて",
            "ko" to "전체 에셋",
            "th" to "ทั้งหมด"
        ),
        "cat_automotive" to mapOf(
            "zh-Hant" to "汽車載具",
            "en" to "Automotive",
            "zh-Hans" to "汽车载具",
            "ja" to "自動車・車体",
            "ko" to "자동차 및 운송",
            "th" to "ยานยนต์"
        ),
        "cat_crossplatform_ui" to mapOf(
            "zh-Hant" to "跨平台系統標準件",
            "en" to "Cross-Platform UI Kit",
            "zh-Hans" to "跨平台系统标准件",
            "ja" to "クロスプラットフォームUI",
            "ko" to "크로스 플랫폼 시스템 표준 컴포넌트",
            "th" to "ชุด UI ข้ามแพลตฟอร์ม"
        ),
        "cat_design_motifs" to mapOf(
            "zh-Hant" to "造型語彙與工藝紋樣",
            "en" to "Design Motifs & Form",
            "zh-Hans" to "造型语汇与工艺纹样",
            "ja" to "造形言語・装飾パターン",
            "ko" to "조형 어휘 및 공예 문양",
            "th" to "ภาษาการออกแบบและลวดลาย"
        ),
        "cat_design_tokens" to mapOf(
            "zh-Hant" to "設計系統原子元件",
            "en" to "Design System Tokens",
            "zh-Hans" to "设计系统原子元件",
            "ja" to "デザインシステム・アトム",
            "ko" to "디자인 시스템 원자 컴포넌트",
            "th" to "ส่วนประกอบระบบการออกแบบ"
        ),
        "cat_digital" to mapOf(
            "zh-Hant" to "數位產品",
            "en" to "Digital Wireframes",
            "zh-Hans" to "数字产品",
            "ja" to "デジタルUI",
            "ko" to "디지털 제품",
            "th" to "ผลิตภัณฑ์ดิจิทัล"
        ),
        "cat_electronics" to mapOf(
            "zh-Hant" to "3C 電子",
            "en" to "3C Electronics",
            "zh-Hans" to "3C 电子",
            "ja" to "3C・電器",
            "ko" to "3C 전자",
            "th" to "อุปกรณ์อิเล็กทรอนิกส์ 3C"
        ),
        "cat_furniture" to mapOf(
            "zh-Hant" to "工業家具",
            "en" to "Furniture",
            "zh-Hans" to "工业家具",
            "ja" to "家具・インテリア",
            "ko" to "산업 가구",
            "th" to "เฟอร์นิเจอร์"
        ),
        "cat_hardware" to mapOf(
            "zh-Hant" to "五金零件",
            "en" to "Hardware",
            "zh-Hans" to "五金零件",
            "ja" to "金物・ネジ",
            "ko" to "하드웨어 부품",
            "th" to "ฮาร์ดแวร์"
        ),
        "cat_info_arch" to mapOf(
            "zh-Hant" to "資訊架構與服務流程",
            "en" to "Information Architecture",
            "zh-Hans" to "信息架构与服务流程",
            "ja" to "情報設計とユーザーフロー",
            "ko" to "정보 구조 및 서비스 흐름",
            "th" to "สถาปัตยกรรมสารสนเทศและแผนผังงาน"
        ),
        "cat_mechanism" to mapOf(
            "zh-Hant" to "機構設計",
            "en" to "Mechanism",
            "zh-Hans" to "机构设计",
            "ja" to "機構設計",
            "ko" to "기구 설계",
            "th" to "กลไก"
        ),
        "cat_pneumatics_piping" to mapOf(
            "zh-Hant" to "機構傳動與流體管路",
            "en" to "Drive Mechanisms & Piping",
            "zh-Hans" to "机构传动与流体管路",
            "ja" to "伝動機構・流体配管",
            "ko" to "구동 기구 및 유체 배관",
            "th" to "กลไกขับเคลื่อนและท่อของไหล"
        ),
        "cat_sheetmetal_cnc" to mapOf(
            "zh-Hant" to "鈑金折彎與 CNC 加工",
            "en" to "Sheet Metal & CNC",
            "zh-Hans" to "钣金折弯与 CNC 加工",
            "ja" to "板金・CNC切削加工",
            "ko" to "판금 절곡 및 CNC 가공",
            "th" to "แผ่นโลหะและเครื่องซีเอ็นซี"
        ),
        "cat_surface_finishing" to mapOf(
            "zh-Hant" to "表面處理與材料工藝",
            "en" to "Surface Finishing",
            "zh-Hans" to "表面处理与材料工艺",
            "ja" to "表面処理・材料工芸",
            "ko" to "표면 처리 및 재료 공정",
            "th" to "การปรับสภาพผิวและวิศวกรรมวัสดุ"
        ),
        "cat_tooling_molding" to mapOf(
            "zh-Hant" to "模具與注塑成型",
            "en" to "Tooling & Molding",
            "zh-Hans" to "模具与注塑成型",
            "ja" to "金型・射出成形",
            "ko" to "금형 및 사출 성형",
            "th" to "แม่พิมพ์และการฉีดขึ้นรูป"
        ),
        "cat_typography" to mapOf(
            "zh-Hant" to "字體排印與版面網格",
            "en" to "Typography & Layout",
            "zh-Hans" to "字体排印与版面网格",
            "ja" to "タイポグラフィとグリッド",
            "ko" to "타이포그래피 및 레이아웃 그리드",
            "th" to "การจัดพิมพ์และตารางเค้าโครง"
        ),
        "cat_ux_motion" to mapOf(
            "zh-Hant" to "互動手勢與動效軌跡",
            "en" to "UX Gestures & Motion",
            "zh-Hans" to "交互手势与动效轨迹",
            "ja" to "ジェスチャーと動的軌跡",
            "ko" to "인터랙션 제스처 및 모션 궤적",
            "th" to "ท่าทางสัมผัสและภาพเคลื่อนไหว"
        ),
        "chart_add_row" to mapOf(
            "zh-Hant" to "新增列",
            "en" to "Add Row",
            "zh-Hans" to "新增行",
            "ja" to "行を追加",
            "ko" to "행 추가",
            "th" to "เพิ่มแถว"
        ),
        "chart_add_series" to mapOf(
            "zh-Hant" to "新增數列",
            "en" to "Add Series",
            "zh-Hans" to "新增系列",
            "ja" to "系列を追加",
            "ko" to "계열 추가",
            "th" to "เพิ่มชุดข้อมูล"
        ),
        "chart_axis_auto" to mapOf(
            "zh-Hant" to "自動",
            "en" to "Automatic",
            "zh-Hans" to "自动",
            "ja" to "自動",
            "ko" to "자동",
            "th" to "อัตโนมัติ"
        ),
        "chart_axis_max" to mapOf(
            "zh-Hant" to "最大值",
            "en" to "Maximum",
            "zh-Hans" to "最大值",
            "ja" to "最大値",
            "ko" to "최댓값",
            "th" to "ค่าสูงสุด"
        ),
        "chart_axis_min" to mapOf(
            "zh-Hant" to "最小值",
            "en" to "Minimum",
            "zh-Hans" to "最小值",
            "ja" to "最小値",
            "ko" to "최솟값",
            "th" to "ค่าต่ำสุด"
        ),
        "chart_axis_step" to mapOf(
            "zh-Hant" to "刻度間距",
            "en" to "Major Unit",
            "zh-Hans" to "刻度间距",
            "ja" to "目盛間隔",
            "ko" to "주 단위",
            "th" to "ระยะขีด"
        ),
        "chart_bar" to mapOf(
            "zh-Hant" to "長條圖",
            "en" to "Bar Chart",
            "zh-Hans" to "柱状图",
            "ja" to "棒グラフ",
            "ko" to "막대형",
            "th" to "แผนภูมิแท่ง"
        ),
        "chart_bar_width" to mapOf(
            "zh-Hant" to "長條寬度",
            "en" to "Bar Width",
            "zh-Hans" to "柱形宽度",
            "ja" to "棒の幅",
            "ko" to "막대 너비",
            "th" to "ความกว้างแท่ง"
        ),
        "chart_category_column" to mapOf(
            "zh-Hant" to "類別",
            "en" to "Category",
            "zh-Hans" to "类别",
            "ja" to "カテゴリ",
            "ko" to "항목",
            "th" to "หมวดหมู่"
        ),
        "chart_data_labels" to mapOf(
            "zh-Hant" to "資料標籤",
            "en" to "Data Labels",
            "zh-Hans" to "数据标签",
            "ja" to "データラベル",
            "ko" to "데이터 레이블",
            "th" to "ป้ายกำกับข้อมูล"
        )
    )

    private fun part3(): Map<String, Map<String, String>> = mapOf(
        "chart_delete_row" to mapOf(
            "zh-Hant" to "刪除此列",
            "en" to "Delete Row",
            "zh-Hans" to "删除此行",
            "ja" to "この行を削除",
            "ko" to "이 행 삭제",
            "th" to "ลบแถวนี้"
        ),
        "chart_delete_series" to mapOf(
            "zh-Hant" to "刪除此數列",
            "en" to "Delete Series",
            "zh-Hans" to "删除此系列",
            "ja" to "この系列を削除",
            "ko" to "이 계열 삭제",
            "th" to "ลบชุดข้อมูลนี้"
        ),
        "chart_doughnut_hole" to mapOf(
            "zh-Hant" to "環圈孔徑",
            "en" to "Doughnut Hole Size",
            "zh-Hans" to "圆环孔径",
            "ja" to "ドーナツの穴の大きさ",
            "ko" to "도넛 구멍 크기",
            "th" to "ขนาดรูโดนัท"
        ),
        "chart_edit" to mapOf(
            "zh-Hant" to "編修圖表",
            "en" to "Edit Chart",
            "zh-Hans" to "编辑图表",
            "ja" to "グラフを編集",
            "ko" to "차트 편집",
            "th" to "แก้ไขแผนภูมิ"
        ),
        "chart_insert" to mapOf(
            "zh-Hant" to "插入圖表",
            "en" to "Insert Chart",
            "zh-Hans" to "插入图表",
            "ja" to "グラフを挿入",
            "ko" to "차트 삽입",
            "th" to "แทรกแผนภูมิ"
        ),
        "chart_kind_area" to mapOf(
            "zh-Hant" to "區域圖",
            "en" to "Area",
            "zh-Hans" to "面积图",
            "ja" to "面グラフ",
            "ko" to "영역형",
            "th" to "แผนภูมิพื้นที่"
        ),
        "chart_kind_bar" to mapOf(
            "zh-Hant" to "直條圖",
            "en" to "Column",
            "zh-Hans" to "柱形图",
            "ja" to "縦棒グラフ",
            "ko" to "세로 막대",
            "th" to "แผนภูมิแท่ง"
        ),
        "chart_kind_doughnut" to mapOf(
            "zh-Hant" to "環圈圖",
            "en" to "Doughnut",
            "zh-Hans" to "圆环图",
            "ja" to "ドーナツグラフ",
            "ko" to "도넛형",
            "th" to "แผนภูมิโดนัท"
        ),
        "chart_kind_horizontalBar" to mapOf(
            "zh-Hant" to "橫條圖",
            "en" to "Bar",
            "zh-Hans" to "条形图",
            "ja" to "横棒グラフ",
            "ko" to "가로 막대",
            "th" to "แผนภูมิแท่งแนวนอน"
        ),
        "chart_kind_line" to mapOf(
            "zh-Hant" to "折線圖",
            "en" to "Line",
            "zh-Hans" to "折线图",
            "ja" to "折れ線グラフ",
            "ko" to "꺾은선형",
            "th" to "กราฟเส้น"
        ),
        "chart_kind_pie" to mapOf(
            "zh-Hant" to "圓餅圖",
            "en" to "Pie",
            "zh-Hans" to "饼图",
            "ja" to "円グラフ",
            "ko" to "원형",
            "th" to "แผนภูมิวงกลม"
        ),
        "chart_kind_radar" to mapOf(
            "zh-Hant" to "雷達圖",
            "en" to "Radar",
            "zh-Hans" to "雷达图",
            "ja" to "レーダーチャート",
            "ko" to "방사형",
            "th" to "แผนภูมิเรดาร์"
        ),
        "chart_kind_scatter" to mapOf(
            "zh-Hant" to "散佈圖",
            "en" to "Scatter",
            "zh-Hans" to "散点图",
            "ja" to "散布図",
            "ko" to "분산형",
            "th" to "แผนภูมิกระจาย"
        ),
        "chart_kind_smoothLine" to mapOf(
            "zh-Hant" to "平滑曲線圖",
            "en" to "Smooth Line",
            "zh-Hans" to "平滑曲线图",
            "ja" to "平滑曲線",
            "ko" to "부드러운 선",
            "th" to "เส้นโค้ง"
        ),
        "chart_kind_stackedArea" to mapOf(
            "zh-Hant" to "堆疊區域圖",
            "en" to "Stacked Area",
            "zh-Hans" to "堆积面积图",
            "ja" to "積み上げ面",
            "ko" to "누적 영역형",
            "th" to "พื้นที่ซ้อน"
        ),
        "chart_kind_stackedBar" to mapOf(
            "zh-Hant" to "堆疊直條圖",
            "en" to "Stacked Column",
            "zh-Hans" to "堆积柱形图",
            "ja" to "積み上げ縦棒",
            "ko" to "누적 세로 막대",
            "th" to "แท่งซ้อน"
        ),
        "chart_label_decimals" to mapOf(
            "zh-Hant" to "小數位數",
            "en" to "Decimal Places",
            "zh-Hans" to "小数位数",
            "ja" to "小数点以下の桁数",
            "ko" to "소수 자릿수",
            "th" to "ตำแหน่งทศนิยม"
        ),
        "chart_labels_center" to mapOf(
            "zh-Hant" to "置中",
            "en" to "Center",
            "zh-Hans" to "居中",
            "ja" to "中央",
            "ko" to "가운데",
            "th" to "ตรงกลาง"
        ),
        "chart_labels_inside" to mapOf(
            "zh-Hant" to "內側",
            "en" to "Inside End",
            "zh-Hans" to "内侧",
            "ja" to "内側",
            "ko" to "안쪽 끝",
            "th" to "ด้านใน"
        ),
        "chart_labels_none" to mapOf(
            "zh-Hant" to "不顯示",
            "en" to "None",
            "zh-Hans" to "不显示",
            "ja" to "なし",
            "ko" to "없음",
            "th" to "ไม่แสดง"
        ),
        "chart_labels_outside" to mapOf(
            "zh-Hant" to "外側",
            "en" to "Outside End",
            "zh-Hans" to "外侧",
            "ja" to "外側",
            "ko" to "바깥쪽 끝",
            "th" to "ด้านนอก"
        ),
        "chart_legend_bottom" to mapOf(
            "zh-Hant" to "下方",
            "en" to "Bottom",
            "zh-Hans" to "下方",
            "ja" to "下",
            "ko" to "아래쪽",
            "th" to "ด้านล่าง"
        ),
        "chart_legend_none" to mapOf(
            "zh-Hant" to "不顯示",
            "en" to "Hidden",
            "zh-Hans" to "不显示",
            "ja" to "非表示",
            "ko" to "숨김",
            "th" to "ซ่อน"
        ),
        "chart_legend_position" to mapOf(
            "zh-Hant" to "圖例位置",
            "en" to "Legend Position",
            "zh-Hans" to "图例位置",
            "ja" to "凡例の位置",
            "ko" to "범례 위치",
            "th" to "ตำแหน่งคำอธิบาย"
        ),
        "chart_legend_right" to mapOf(
            "zh-Hant" to "右側",
            "en" to "Right",
            "zh-Hans" to "右侧",
            "ja" to "右",
            "ko" to "오른쪽",
            "th" to "ด้านขวา"
        ),
        "chart_legend_top" to mapOf(
            "zh-Hant" to "上方",
            "en" to "Top",
            "zh-Hans" to "上方",
            "ja" to "上",
            "ko" to "위쪽",
            "th" to "ด้านบน"
        ),
        "chart_line" to mapOf(
            "zh-Hant" to "折線圖",
            "en" to "Line Chart",
            "zh-Hans" to "折线图",
            "ja" to "折れ線",
            "ko" to "꺾은선형",
            "th" to "แผนภูมิเส้น"
        ),
        "chart_pie" to mapOf(
            "zh-Hant" to "圓餅圖",
            "en" to "Pie Chart",
            "zh-Hans" to "饼状图",
            "ja" to "円グラフ",
            "ko" to "원형",
            "th" to "แผนภูมิวงกลม"
        ),
        "chart_section_axes" to mapOf(
            "zh-Hant" to "座標軸",
            "en" to "Axes",
            "zh-Hans" to "坐标轴",
            "ja" to "軸",
            "ko" to "축",
            "th" to "แกน"
        ),
        "chart_section_legend" to mapOf(
            "zh-Hant" to "圖例與標籤",
            "en" to "Legend & Labels",
            "zh-Hans" to "图例与标签",
            "ja" to "凡例とラベル",
            "ko" to "범례 및 레이블",
            "th" to "คำอธิบายและป้ายกำกับ"
        ),
        "chart_section_series" to mapOf(
            "zh-Hant" to "資料數列",
            "en" to "Series",
            "zh-Hans" to "数据系列",
            "ja" to "データ系列",
            "ko" to "데이터 계열",
            "th" to "ชุดข้อมูล"
        ),
        "chart_section_style" to mapOf(
            "zh-Hant" to "樣式",
            "en" to "Style",
            "zh-Hans" to "样式",
            "ja" to "スタイル",
            "ko" to "스타일",
            "th" to "สไตล์"
        ),
        "chart_series_color" to mapOf(
            "zh-Hant" to "數列顏色",
            "en" to "Series Color",
            "zh-Hans" to "系列颜色",
            "ja" to "系列の色",
            "ko" to "계열 색상",
            "th" to "สีชุดข้อมูล"
        ),
        "chart_series_name" to mapOf(
            "zh-Hant" to "數列名稱",
            "en" to "Series Name",
            "zh-Hans" to "系列名称",
            "ja" to "系列名",
            "ko" to "계열 이름",
            "th" to "ชื่อชุดข้อมูล"
        ),
        "chart_show_axis_labels" to mapOf(
            "zh-Hant" to "顯示刻度標籤",
            "en" to "Axis Labels",
            "zh-Hans" to "显示刻度标签",
            "ja" to "軸ラベル",
            "ko" to "축 레이블",
            "th" to "ป้ายกำกับแกน"
        ),
        "chart_show_grid" to mapOf(
            "zh-Hant" to "顯示格線",
            "en" to "Gridlines",
            "zh-Hans" to "显示网格线",
            "ja" to "目盛線",
            "ko" to "눈금선",
            "th" to "เส้นตาราง"
        ),
        "chart_single_series_hint" to mapOf(
            "zh-Hant" to "這個類型只會畫第一個數列。",
            "en" to "This chart type draws only the first series.",
            "zh-Hans" to "此类型只会绘制第一个系列。",
            "ja" to "この種類は最初の系列のみ描画します。",
            "ko" to "이 차트 종류는 첫 번째 계열만 그립니다.",
            "th" to "แผนภูมิชนิดนี้จะวาดเฉพาะชุดข้อมูลแรก"
        ),
        "chart_studio" to mapOf(
            "zh-Hant" to "數字製圖",
            "en" to "Chart Studio",
            "zh-Hans" to "数字制图",
            "ja" to "グラフ作成",
            "ko" to "데이터 차트",
            "th" to "สร้างแผนภูมิ"
        ),
        "chart_tab_data" to mapOf(
            "zh-Hant" to "資料",
            "en" to "Data",
            "zh-Hans" to "数据",
            "ja" to "データ",
            "ko" to "데이터",
            "th" to "ข้อมูล"
        ),
        "chart_tab_format" to mapOf(
            "zh-Hant" to "格式",
            "en" to "Format",
            "zh-Hans" to "格式",
            "ja" to "書式",
            "ko" to "서식",
            "th" to "รูปแบบ"
        ),
        "chart_tab_type" to mapOf(
            "zh-Hant" to "類型",
            "en" to "Type",
            "zh-Hans" to "类型",
            "ja" to "種類",
            "ko" to "종류",
            "th" to "ประเภท"
        ),
        "chart_title" to mapOf(
            "zh-Hant" to "圖表標題",
            "en" to "Chart Title",
            "zh-Hans" to "图表标题",
            "ja" to "グラフタイトル",
            "ko" to "차트 제목",
            "th" to "ชื่อแผนภูมิ"
        ),
        "chart_type" to mapOf(
            "zh-Hant" to "圖表類型",
            "en" to "Chart Type",
            "zh-Hans" to "图表类型",
            "ja" to "グラフの種類",
            "ko" to "차트 유형",
            "th" to "ประเภทแผนภูมิ"
        ),
        "chart_update" to mapOf(
            "zh-Hant" to "更新圖表",
            "en" to "Update Chart",
            "zh-Hans" to "更新图表",
            "ja" to "グラフを更新",
            "ko" to "차트 업데이트",
            "th" to "อัปเดตแผนภูมิ"
        ),
        "chart_x_axis_title" to mapOf(
            "zh-Hant" to "水平軸標題",
            "en" to "Horizontal Axis Title",
            "zh-Hans" to "水平轴标题",
            "ja" to "横軸のタイトル",
            "ko" to "가로 축 제목",
            "th" to "ชื่อแกนนอน"
        ),
        "chart_y_axis_title" to mapOf(
            "zh-Hant" to "垂直軸標題",
            "en" to "Vertical Axis Title",
            "zh-Hans" to "垂直轴标题",
            "ja" to "縦軸のタイトル",
            "ko" to "세로 축 제목",
            "th" to "ชื่อแกนตั้ง"
        ),
        "choose_destination_notebook" to mapOf(
            "zh-Hant" to "目的筆記本",
            "en" to "Destination",
            "zh-Hans" to "目的笔记本",
            "ja" to "移動先のノート",
            "ko" to "대상 노트",
            "th" to "สมุดปลายทาง"
        ),
        "clear_cache" to mapOf(
            "zh-Hant" to "清除快取",
            "en" to "Clear Cache",
            "zh-Hans" to "清除缓存",
            "ja" to "キャッシュ削除",
            "ko" to "캐시 지우기",
            "th" to "ล้างแคช"
        ),
        "clear_cache_confirm" to mapOf(
            "zh-Hant" to "確定要清除所有本機素材快取以釋放硬碟空間嗎？已插入筆記中的內容不受影響。",
            "en" to "Are you sure you want to clear all local asset cache? Items already inserted into notes will not be affected.",
            "zh-Hans" to "确定要清除所有本地素材缓存以释放存储空间吗？已插入笔记中的内容不受影响。",
            "ja" to "すべてのローカルアセットキャッシュを消去しますか？ノートに挿入済みのコンテンツには影響しません。",
            "ko" to "모든 로컬 에셋 캐시를 지우시겠습니까? 노트에 이미 삽입된 콘텐츠에는 영향을 주지 않습니다.",
            "th" to "คุณแน่ใจหรือไม่ว่าต้องการล้างแคชเนื้อหาในเครื่องทั้งหมด? เนื้อหาที่แทรกลงในบันทึกแล้วจะไม่ได้รับผลกระทบ"
        ),
        "clear_confirm" to mapOf(
            "zh-Hant" to "確定清除",
            "en" to "Clear All",
            "zh-Hans" to "确定清空",
            "ja" to "消去する",
            "ko" to "지우기 확인",
            "th" to "ยืนยันการล้าง"
        ),
        "clear_page" to mapOf(
            "zh-Hant" to "清除本頁內容",
            "en" to "Clear Current Page",
            "zh-Hans" to "清空本页内容",
            "ja" to "このページを消去",
            "ko" to "현재 페이지 지우기",
            "th" to "ล้างหน้านี้"
        ),
        "clear_page_confirm" to mapOf(
            "zh-Hant" to "此操作將清空當前頁面之所有手寫筆劃。",
            "en" to "This action will remove all ink strokes on the current page.",
            "zh-Hans" to "此操作将清空当前页面之所有手写笔画。",
            "ja" to "この操作により、現在のページのすべての手書きストロークが消去されます。",
            "ko" to "이 작업은 현재 페이지의 모든 필기 획을 지웁니다.",
            "th" to "การดำเนินการนี้จะลบลายเส้นการเขียนทั้งหมดในหน้านี้"
        ),
        "close" to mapOf(
            "zh-Hant" to "關閉",
            "en" to "Close",
            "zh-Hans" to "关闭",
            "ja" to "閉じる",
            "ko" to "닫기",
            "th" to "ปิด"
        ),
        "close_ruler" to mapOf(
            "zh-Hant" to "關閉尺規",
            "en" to "Close Ruler",
            "zh-Hans" to "关闭标尺",
            "ja" to "定規を閉じる",
            "ko" to "자 닫기",
            "th" to "ปิดไม้บรรทัด"
        ),
        "cloud_sync" to mapOf(
            "zh-Hant" to "雲端同步",
            "en" to "Cloud sync",
            "zh-Hans" to "云端同步",
            "ja" to "クラウド同期",
            "ko" to "클라우드 동기화",
            "th" to "ซิงค์บนคลาวด์"
        ),
        "cloud_sync_explainer" to mapOf(
            "zh-Hant" to "登入一次，筆記本、資料夾與設定就會在所有裝置上保持一致。資料存在你 Google 雲端硬碟的應用程式專屬資料夾裡——你在檔案清單看不到它，我們也看不到。",
            "en" to "Sign in once and your notebooks, folders and settings stay in sync on every device. Data goes to a private app folder in your Google Drive — you won't see it among your files, and neither will we.",
            "zh-Hans" to "登录一次，笔记本、资料夹与设定就会在所有装置上保持一致。资料存在你 Google 云端硬碟的应用专属资料夹里——你在档案列表看不到它，我们也看不到。",
            "ja" to "一度ログインすれば、ノート・フォルダ・設定がすべての端末で同期されます。データは Google ドライブのアプリ専用フォルダに保存されます —— ファイル一覧には表示されず、こちらからも見えません。",
            "ko" to "한 번 로그인하면 노트·폴더·설정이 모든 기기에서 동기화됩니다. 데이터는 Google 드라이브의 앱 전용 폴더에 저장됩니다 —— 파일 목록에는 보이지 않으며, 저희도 볼 수 없습니다.",
            "th" to "ลงชื่อเข้าใช้ครั้งเดียว สมุดบันทึก โฟลเดอร์ และการตั้งค่าจะซิงค์กันทุกอุปกรณ์ ข้อมูลถูกเก็บในโฟลเดอร์เฉพาะแอปใน Google Drive ของคุณ — ไม่ปรากฏในรายการไฟล์ และเราก็มองไม่เห็น"
        ),
        "collab_advanced_panel" to mapOf(
            "zh-Hant" to "進階協作控制面板",
            "en" to "Advanced Collaboration Panel",
            "zh-Hans" to "进阶协作控制面板",
            "ja" to "高度な共同編集パネル",
            "ko" to "고급 협업 패널",
            "th" to "แผงการทำงานร่วมกันขั้นสูง"
        ),
        "collab_err_bad_address" to mapOf(
            "zh-Hant" to "無效的協同伺服器位址：%@",
            "en" to "Invalid collaboration server address: %@",
            "zh-Hans" to "无效的协同服务器地址：%@",
            "ja" to "共同編集サーバーのアドレスが無効です：%@",
            "ko" to "잘못된 협업 서버 주소: %@",
            "th" to "ที่อยู่เซิร์ฟเวอร์การทำงานร่วมกันไม่ถูกต้อง: %@"
        ),
        "collab_err_unreachable" to mapOf(
            "zh-Hant" to "無法連上協同伺服器 %@，已停止重試。",
            "en" to "Could not reach the collaboration server %@. Retrying has stopped.",
            "zh-Hans" to "无法连接协同服务器 %@，已停止重试。",
            "ja" to "共同編集サーバー %@ に接続できません。再試行を停止しました。",
            "ko" to "협업 서버 %@에 연결할 수 없습니다. 재시도를 중단했습니다.",
            "th" to "เชื่อมต่อเซิร์ฟเวอร์การทำงานร่วมกัน %@ ไม่ได้ หยุดลองใหม่แล้ว"
        ),
        "collab_history_playback" to mapOf(
            "zh-Hant" to "歷史回溯",
            "en" to "History Playback",
            "zh-Hans" to "历史回溯",
            "ja" to "履歴再生",
            "ko" to "기록 재생",
            "th" to "เล่นประวัติ"
        ),
        "collab_key_missing" to mapOf(
            "zh-Hant" to "你只用房號加入。少了邀請連結裡的金鑰，別人寫的內容在這裡一個字都解不開。請向房主要完整的邀請連結再加入一次。",
            "en" to "You joined with the room code only. Without the key in the invite link, everything the others write stays unreadable here. Ask the host for the full invite link and join again.",
            "zh-Hans" to "你只用房号加入。少了邀请连结里的金钥，别人写的内容在这里一个字都解不开。请向房主要完整的邀请连结再加入一次。",
            "ja" to "ルームコードだけで参加しています。招待リンクに含まれる鍵がないと、ほかの人が書いた内容はここでは読めません。ホストに招待リンク全体をもらい、入り直してください。",
            "ko" to "방 코드만으로 참여했습니다. 초대 링크에 들어 있는 키가 없으면 다른 사람이 쓴 내용을 여기서 읽을 수 없습니다. 호스트에게 전체 초대 링크를 받아 다시 참여하세요。",
            "th" to "คุณเข้าร่วมด้วยรหัสห้องเท่านั้น หากไม่มีกุญแจในลิงก์เชิญ สิ่งที่คนอื่นเขียนจะอ่านไม่ได้ที่นี่ ขอลิงก์เชิญฉบับเต็มจากผู้เปิดห้องแล้วเข้าร่วมใหม่"
        ),
        "collab_notification_title" to mapOf(
            "zh-Hant" to "Kairumo 協同訊息",
            "en" to "Kairumo collaboration",
            "zh-Hans" to "Kairumo 协同消息",
            "ja" to "Kairumo の共同編集",
            "ko" to "Kairumo 공동 편집",
            "th" to "การทำงานร่วมกันของ Kairumo"
        ),
        "collab_p2p_scan" to mapOf(
            "zh-Hant" to "掃描區網",
            "en" to "Scan LAN",
            "zh-Hans" to "扫描局域网",
            "ja" to "LANをスキャン",
            "ko" to "LAN 스캔",
            "th" to "สแกน LAN"
        ),
        "collab_p2p_stop" to mapOf(
            "zh-Hant" to "停止掃描",
            "en" to "Stop Scan",
            "zh-Hans" to "停止扫描",
            "ja" to "スキャン停止",
            "ko" to "스캔 중지",
            "th" to "หยุดสแกน"
        ),
        "collab_p2p_test" to mapOf(
            "zh-Hant" to "連線測試",
            "en" to "Test Connection",
            "zh-Hans" to "连线测试",
            "ja" to "接続テスト",
            "ko" to "연결 테스트",
            "th" to "ทดสอบการเชื่อมต่อ"
        ),
        "collab_snapshot" to mapOf(
            "zh-Hant" to "協同快照",
            "en" to "Shared snapshot",
            "zh-Hans" to "协同快照",
            "ja" to "共同スナップショット",
            "ko" to "협업 스냅샷",
            "th" to "สแนปช็อตร่วม"
        ),
        "collab_time_machine" to mapOf(
            "zh-Hant" to "時光機回溯",
            "en" to "Time Machine Replay",
            "zh-Hans" to "时光机回溯",
            "ja" to "タイムマシンリプレイ",
            "ko" to "타임머신 리플레이",
            "th" to "การเล่นซ้ำไทม์แมชชีน"
        ),
        "collab_voice_room" to mapOf(
            "zh-Hant" to "協作語音房間",
            "en" to "Voice Room",
            "zh-Hans" to "协作语音房间",
            "ja" to "ボイスルーム",
            "ko" to "음성 룸",
            "th" to "ห้องเสียง"
        ),
        "collaborate" to mapOf(
            "zh-Hant" to "線上協同",
            "en" to "Collaborate",
            "zh-Hans" to "线上协同",
            "ja" to "共同編集",
            "ko" to "공동 편집",
            "th" to "การทำงานร่วมกัน"
        ),
        "collaborate_desc" to mapOf(
            "zh-Hant" to "查看並管理線上多人即時協同畫布",
            "en" to "Open real-time multiplayer P2P collaboration session",
            "zh-Hans" to "查看并管理线上多人即时协同画布",
            "ja" to "リアルタイム複数人共同編集セッションを管理",
            "ko" to "실시간 다중 접속 공동 작업 세션 관리",
            "th" to "จัดการเซสชันการทำงานร่วมกันแบบเรียลไทม์"
        ),
        "collapse" to mapOf(
            "zh-Hant" to "收合",
            "en" to "Collapse",
            "zh-Hans" to "收起",
            "ja" to "折りたたむ",
            "ko" to "접기",
            "th" to "ยุบ"
        ),
        "collapse_minimal_toolbox" to mapOf(
            "zh-Hant" to "收合迷你工具列",
            "en" to "Collapse mini toolbar",
            "zh-Hans" to "收合迷你工具栏",
            "ja" to "ミニツールバーを折りたたむ",
            "ko" to "미니 도구 막대 접기",
            "th" to "ยุบแถบเครื่องมือย่อ"
        ),
        "color_black" to mapOf(
            "zh-Hant" to "深黑",
            "en" to "Near Black",
            "zh-Hans" to "深黑",
            "ja" to "ほぼ黒",
            "ko" to "거의 검정",
            "th" to "ดำเกือบสนิท"
        ),
        "color_blue" to mapOf(
            "zh-Hant" to "淡藍",
            "en" to "Pale Blue",
            "zh-Hans" to "淡蓝",
            "ja" to "淡い青",
            "ko" to "연파랑",
            "th" to "ฟ้าอ่อน"
        ),
        "color_gray" to mapOf(
            "zh-Hant" to "淺灰",
            "en" to "Light Gray",
            "zh-Hans" to "浅灰",
            "ja" to "ライトグレー",
            "ko" to "밝은 회색",
            "th" to "เทาอ่อน"
        ),
        "color_green" to mapOf(
            "zh-Hant" to "淡綠",
            "en" to "Pale Green",
            "zh-Hans" to "淡绿",
            "ja" to "淡い緑",
            "ko" to "연초록",
            "th" to "เขียวอ่อน"
        ),
        "color_ink_black" to mapOf(
            "zh-Hant" to "墨黑",
            "en" to "Ink Black",
            "zh-Hans" to "墨黑",
            "ja" to "インクブラック",
            "ko" to "먹색",
            "th" to "ดำหมึก"
        ),
        "color_ink_blue" to mapOf(
            "zh-Hant" to "鋼筆藍",
            "en" to "Pen Blue",
            "zh-Hans" to "钢笔蓝",
            "ja" to "万年筆ブルー",
            "ko" to "만년필 블루",
            "th" to "น้ำเงินปากกา"
        ),
        "color_ink_gray" to mapOf(
            "zh-Hant" to "鉛筆灰",
            "en" to "Pencil Grey",
            "zh-Hans" to "铅笔灰",
            "ja" to "ペンシルグレー",
            "ko" to "펜슬 그레이",
            "th" to "เทาดินสอ"
        ),
        "color_ink_green" to mapOf(
            "zh-Hant" to "森林綠",
            "en" to "Forest Green",
            "zh-Hans" to "森林绿",
            "ja" to "フォレストグリーン",
            "ko" to "포레스트 그린",
            "th" to "เขียวป่า"
        )
    )

    private fun part4(): Map<String, Map<String, String>> = mapOf(
        "color_ink_red" to mapOf(
            "zh-Hant" to "紅筆紅",
            "en" to "Pen Red",
            "zh-Hans" to "红笔红",
            "ja" to "レッドペン",
            "ko" to "레드 펜",
            "th" to "แดงปากกา"
        ),
        "color_ink_yellow" to mapOf(
            "zh-Hant" to "螢光黃",
            "en" to "Highlighter Yellow",
            "zh-Hans" to "荧光黄",
            "ja" to "蛍光イエロー",
            "ko" to "형광 옐로",
            "th" to "เหลืองไฮไลต์"
        ),
        "color_mode" to mapOf(
            "zh-Hant" to "調色模式",
            "en" to "Color Mode",
            "zh-Hans" to "调色模式",
            "ja" to "カラーモード",
            "ko" to "색상 모드",
            "th" to "โหมดสี"
        ),
        "color_pink" to mapOf(
            "zh-Hant" to "淡粉",
            "en" to "Pale Pink",
            "zh-Hans" to "淡粉",
            "ja" to "淡いピンク",
            "ko" to "연분홍",
            "th" to "ชมพูอ่อน"
        ),
        "color_transparent" to mapOf(
            "zh-Hant" to "透明",
            "en" to "Transparent",
            "zh-Hans" to "透明",
            "ja" to "透明",
            "ko" to "투명",
            "th" to "โปร่งใส"
        ),
        "color_white" to mapOf(
            "zh-Hant" to "白",
            "en" to "White",
            "zh-Hans" to "白",
            "ja" to "白",
            "ko" to "흰색",
            "th" to "ขาว"
        ),
        "color_yellow" to mapOf(
            "zh-Hant" to "淡黃",
            "en" to "Pale Yellow",
            "zh-Hans" to "淡黄",
            "ja" to "淡い黄",
            "ko" to "연노랑",
            "th" to "เหลืองอ่อน"
        ),
        "comment_empty" to mapOf(
            "zh-Hant" to "還沒有留言",
            "en" to "No messages yet",
            "zh-Hans" to "还没有留言",
            "ja" to "まだコメントはありません",
            "ko" to "아직 댓글이 없습니다",
            "th" to "ยังไม่มีข้อความ"
        ),
        "comment_pin" to mapOf(
            "zh-Hant" to "討論圖釘",
            "en" to "Comment Pin",
            "zh-Hans" to "讨论图钉",
            "ja" to "コメントピン",
            "ko" to "댓글 핀",
            "th" to "หมุดความคิดเห็น"
        ),
        "comment_pin_desc" to mapOf(
            "zh-Hant" to "在畫布指定位置圖釘打卡，展開多人協同討論串",
            "en" to "Place a threaded collaboration comment pin on canvas",
            "zh-Hans" to "在画布指定位置图钉打卡，展开多人协同讨论串",
            "ja" to "キャンバス上の特定位置にコメントピンを配置",
            "ko" to "캔버스 특정 위치에 토론 댓글 핀 꽂기",
            "th" to "ปักหมุดข้อคิดเห็นเพื่อการทำงานร่วมกันบนผืนผ้าใบ"
        ),
        "comment_placeholder" to mapOf(
            "zh-Hant" to "輸入留言或回覆...",
            "en" to "Type a comment or reply...",
            "zh-Hans" to "输入留言或回复...",
            "ja" to "コメントまたは返信を入力...",
            "ko" to "댓글이나 답글을 입력하세요...",
            "th" to "พิมพ์ความคิดเห็นหรือตอบกลับ..."
        ),
        "comment_send" to mapOf(
            "zh-Hant" to "送出",
            "en" to "Send",
            "zh-Hans" to "送出",
            "ja" to "送信",
            "ko" to "보내기",
            "th" to "ส่ง"
        ),
        "composition_golden_spiral" to mapOf(
            "zh-Hant" to "黃金螺旋 (Φ 1.618)",
            "en" to "GOLDEN SPIRAL (Φ 1.618)",
            "zh-Hans" to "黄金螺旋 (Φ 1.618)",
            "ja" to "黄金螺旋 (Φ 1.618)",
            "ko" to "황금 나선 (Φ 1.618)",
            "th" to "เกลียวทองคำ (Φ 1.618)"
        ),
        "composition_overlay" to mapOf(
            "zh-Hant" to "構圖輔助線",
            "en" to "Composition HUD",
            "zh-Hans" to "构图辅助线",
            "ja" to "構図補助線",
            "ko" to "구도 가이드",
            "th" to "เส้นไกด์การจัดองค์ประกอบ"
        ),
        "composition_rule_of_thirds" to mapOf(
            "zh-Hant" to "三分構圖 (3×3)",
            "en" to "RULE OF THIRDS (3×3)",
            "zh-Hans" to "三分构图 (3×3)",
            "ja" to "三分割構図 (3×3)",
            "ko" to "삼분할 구도 (3×3)",
            "th" to "กฎสามส่วน (3×3)"
        ),
        "confirm" to mapOf(
            "zh-Hant" to "確認",
            "en" to "OK",
            "zh-Hans" to "确认",
            "ja" to "OK",
            "ko" to "확인",
            "th" to "ตกลง"
        ),
        "connection_edit" to mapOf(
            "zh-Hant" to "編修連接線",
            "en" to "Edit Connector",
            "zh-Hans" to "编辑连接线",
            "ja" to "コネクタを編集",
            "ko" to "커넥터 편집",
            "th" to "แก้ไขเส้นเชื่อม"
        ),
        "connection_end_cap" to mapOf(
            "zh-Hant" to "終點端點",
            "en" to "End end",
            "zh-Hans" to "终点端点",
            "ja" to "終点",
            "ko" to "끝점",
            "th" to "ปลายสิ้นสุด"
        ),
        "connection_from_anchor" to mapOf(
            "zh-Hant" to "出線位置",
            "en" to "Exit point",
            "zh-Hans" to "出线位置",
            "ja" to "出発点",
            "ko" to "시작 위치",
            "th" to "จุดออก"
        ),
        "connection_handle" to mapOf(
            "zh-Hant" to "拖曳到另一個形狀以連接",
            "en" to "Drag to another shape to connect",
            "zh-Hans" to "拖到另一个形状以连接",
            "ja" to "別の図形へドラッグして接続",
            "ko" to "다른 도형으로 드래그하여 연결",
            "th" to "ลากไปยังรูปร่างอื่นเพื่อเชื่อมต่อ"
        ),
        "connection_reverse" to mapOf(
            "zh-Hant" to "反轉方向",
            "en" to "Reverse direction",
            "zh-Hans" to "反转方向",
            "ja" to "向きを反転",
            "ko" to "방향 반전",
            "th" to "กลับทิศทาง"
        ),
        "connection_route" to mapOf(
            "zh-Hant" to "走線方式",
            "en" to "Routing",
            "zh-Hans" to "走线方式",
            "ja" to "ルーティング",
            "ko" to "경로 방식",
            "th" to "รูปแบบเส้นทาง"
        ),
        "connection_start_cap" to mapOf(
            "zh-Hant" to "起點端點",
            "en" to "Start end",
            "zh-Hans" to "起点端点",
            "ja" to "始点",
            "ko" to "시작점",
            "th" to "ปลายเริ่มต้น"
        ),
        "connection_status" to mapOf(
            "zh-Hant" to "連線狀態",
            "en" to "Connection Status",
            "zh-Hans" to "连接状态",
            "ja" to "接続状態",
            "ko" to "연결 상태",
            "th" to "สถานะการเชื่อมต่อ"
        ),
        "connection_to_anchor" to mapOf(
            "zh-Hant" to "入線位置",
            "en" to "Entry point",
            "zh-Hans" to "入线位置",
            "ja" to "到達点",
            "ko" to "도착 위치",
            "th" to "จุดเข้า"
        ),
        "continue" to mapOf(
            "zh-Hant" to "繼續",
            "en" to "Continue",
            "zh-Hans" to "继续",
            "ja" to "続ける",
            "ko" to "계속하기",
            "th" to "ทำต่อ"
        ),
        "continue_working" to mapOf(
            "zh-Hant" to "繼續",
            "en" to "Continue",
            "zh-Hans" to "继续",
            "ja" to "続きから",
            "ko" to "이어서",
            "th" to "ทำต่อ"
        ),
        "copy_encrypted_link" to mapOf(
            "zh-Hant" to "複製加密邀請連結",
            "en" to "Copy Encrypted Invite Link",
            "zh-Hans" to "复制加密邀请链接",
            "ja" to "暗号化招待リンクをコピー",
            "ko" to "암호화된 초대 링크 복사",
            "th" to "คัดลอกลิงก์คำเชิญที่เข้ารหัส"
        ),
        "copy_pages_to_title" to mapOf(
            "zh-Hant" to "把選取的頁面複製到",
            "en" to "Copy the selected pages into",
            "zh-Hans" to "把选取的页面复制到",
            "ja" to "選択したページのコピー先",
            "ko" to "선택한 페이지를 복사할 곳",
            "th" to "คัดลอกหน้าที่เลือกไปยัง"
        ),
        "copy_room_id" to mapOf(
            "zh-Hant" to "複製房間碼",
            "en" to "Copy Room ID",
            "zh-Hans" to "复制房间码",
            "ja" to "ルームIDをコピー",
            "ko" to "방 ID 복사",
            "th" to "คัดลอกรหัสห้อง"
        ),
        "copy_selected" to mapOf(
            "zh-Hant" to "複製選取",
            "en" to "Copy Selection",
            "zh-Hans" to "复制选中",
            "ja" to "選択範囲をコピー",
            "ko" to "선택 항목 복사",
            "th" to "คัดลอกส่วนที่เลือก"
        ),
        "copy_selected_hint" to mapOf(
            "zh-Hant" to "複製到剪貼簿，之後用「貼上」放到想要的位置",
            "en" to "Copy to the clipboard; use Paste to place it where you want",
            "zh-Hans" to "复制到剪贴板，之后用“粘贴”放到想要的位置",
            "ja" to "クリップボードにコピーします。「ペースト」で好きな位置に置けます",
            "ko" to "클립보드로 복사합니다. “붙여넣기”로 원하는 위치에 놓으세요",
            "th" to "คัดลอกไปยังคลิปบอร์ด แล้วใช้ “วาง” เพื่อวางในตำแหน่งที่ต้องการ"
        ),
        "copy_suffix" to mapOf(
            "zh-Hant" to "%@（副本）",
            "en" to "%@ (copy)",
            "zh-Hans" to "%@（副本）",
            "ja" to "%@（コピー）",
            "ko" to "%@(사본)",
            "th" to "%@ (สำเนา)"
        ),
        "copy_to" to mapOf(
            "zh-Hant" to "複製到…",
            "en" to "Copy to…",
            "zh-Hans" to "复制到…",
            "ja" to "コピー先…",
            "ko" to "복사 위치…",
            "th" to "คัดลอกไปยัง…"
        ),
        "copy_to_notebook" to mapOf(
            "zh-Hant" to "複製到其他筆記本…",
            "en" to "Copy to Another Notebook…",
            "zh-Hans" to "复制到其他笔记本…",
            "ja" to "別のノートへコピー…",
            "ko" to "다른 노트로 복사…",
            "th" to "คัดลอกไปยังสมุดอื่น…"
        ),
        "core_engine" to mapOf(
            "zh-Hant" to "Rust Core 引擎",
            "en" to "Rust Core Engine",
            "zh-Hans" to "Rust Core 引擎",
            "ja" to "Rust Core エンジン",
            "ko" to "Rust Core 엔진",
            "th" to "เอนจิน Rust Core"
        ),
        "core_msg_001" to mapOf(
            "zh-Hant" to "模型尚未下載或載入",
            "en" to "The model has not been downloaded or loaded yet",
            "zh-Hans" to "模型尚未下载或加载",
            "ja" to "モデルがまだダウンロードまたは読み込まれていません",
            "ko" to "모델이 아직 다운로드되거나 로드되지 않았습니다",
            "th" to "ยังไม่ได้ดาวน์โหลดหรือโหลดโมเดล"
        ),
        "core_msg_002" to mapOf(
            "zh-Hant" to "不支援的語言：%1@",
            "en" to "Unsupported language: %1@",
            "zh-Hans" to "不支持的语言：%1@",
            "ja" to "サポートされていない言語: %1@",
            "ko" to "지원하지 않는 언어: %1@",
            "th" to "ไม่รองรับภาษา: %1@"
        ),
        "core_msg_003" to mapOf(
            "zh-Hant" to "後端錯誤：%1@",
            "en" to "Backend error: %1@",
            "zh-Hans" to "后端错误：%1@",
            "ja" to "バックエンドのエラー: %1@",
            "ko" to "백엔드 오류: %1@",
            "th" to "ข้อผิดพลาดของส่วนหลังบ้าน: %1@"
        ),
        "core_msg_004" to mapOf(
            "zh-Hant" to "標點模型尚未下載或載入",
            "en" to "The punctuation model has not been downloaded or loaded yet",
            "zh-Hans" to "标点模型尚未下载或加载",
            "ja" to "句読点モデルがまだダウンロードまたは読み込まれていません",
            "ko" to "문장 부호 모델이 아직 다운로드되거나 로드되지 않았습니다",
            "th" to "ยังไม่ได้ดาวน์โหลดหรือโหลดโมเดลเครื่องหมายวรรคตอน"
        ),
        "core_msg_005" to mapOf(
            "zh-Hant" to "標點還原失敗：%1@",
            "en" to "Punctuation restoration failed: %1@",
            "zh-Hans" to "标点还原失败：%1@",
            "ja" to "句読点の復元に失敗しました: %1@",
            "ko" to "문장 부호 복원에 실패했습니다: %1@",
            "th" to "คืนค่าเครื่องหมายวรรคตอนไม่สำเร็จ: %1@"
        ),
        "core_msg_006" to mapOf(
            "zh-Hant" to "找不到模型檔：%1@",
            "en" to "Model file not found: %1@",
            "zh-Hans" to "找不到模型文件：%1@",
            "ja" to "モデルファイルが見つかりません: %1@",
            "ko" to "모델 파일을 찾을 수 없습니다: %1@",
            "th" to "ไม่พบไฟล์โมเดล: %1@"
        ),
        "core_msg_007" to mapOf(
            "zh-Hant" to "模型資源格式錯誤：%1@",
            "en" to "Invalid model resource format: %1@",
            "zh-Hans" to "模型资源格式错误：%1@",
            "ja" to "モデルリソースの形式が正しくありません: %1@",
            "ko" to "모델 리소스 형식이 올바르지 않습니다: %1@",
            "th" to "รูปแบบทรัพยากรโมเดลไม่ถูกต้อง: %1@"
        ),
        "core_msg_008" to mapOf(
            "zh-Hant" to "ONNX Runtime 錯誤：%1@",
            "en" to "ONNX Runtime error: %1@",
            "zh-Hans" to "ONNX Runtime 错误：%1@",
            "ja" to "ONNX Runtime のエラー: %1@",
            "ko" to "ONNX Runtime 오류: %1@",
            "th" to "ข้อผิดพลาดของ ONNX Runtime: %1@"
        ),
        "core_msg_009" to mapOf(
            "zh-Hant" to "am.mvn 解析失敗",
            "en" to "Failed to parse am.mvn",
            "zh-Hans" to "am.mvn 解析失败",
            "ja" to "am.mvn の解析に失敗しました",
            "ko" to "am.mvn 파싱에 실패했습니다",
            "th" to "แยกวิเคราะห์ am.mvn ไม่สำเร็จ"
        ),
        "core_msg_010" to mapOf(
            "zh-Hant" to "Opus 編碼失敗：%1@",
            "en" to "Opus encoding failed: %1@",
            "zh-Hans" to "Opus 编码失败：%1@",
            "ja" to "Opus のエンコードに失敗しました: %1@",
            "ko" to "Opus 인코딩에 실패했습니다: %1@",
            "th" to "เข้ารหัส Opus ไม่สำเร็จ: %1@"
        ),
        "core_msg_011" to mapOf(
            "zh-Hant" to "音框長度錯誤：得到 %1@ 個樣本，應為 %2@",
            "en" to "Wrong audio frame length: got %1@ samples, expected %2@",
            "zh-Hans" to "音频帧长度错误：得到 %1@ 个样本，应为 %2@",
            "ja" to "オーディオフレームの長さが正しくありません: %1@ サンプル（期待値 %2@）",
            "ko" to "오디오 프레임 길이가 올바르지 않습니다: %1@개 샘플(필요: %2@개)",
            "th" to "ความยาวเฟรมเสียงไม่ถูกต้อง: ได้ %1@ ตัวอย่าง ควรเป็น %2@"
        ),
        "core_msg_012" to mapOf(
            "zh-Hant" to "IO 錯誤：%1@",
            "en" to "I/O error: %1@",
            "zh-Hans" to "IO 错误：%1@",
            "ja" to "入出力エラー: %1@",
            "ko" to "입출력 오류: %1@",
            "th" to "ข้อผิดพลาดการอ่าน/เขียน: %1@"
        ),
        "core_msg_013" to mapOf(
            "zh-Hant" to "圖表設定格式錯誤：%1@",
            "en" to "Invalid chart settings: %1@",
            "zh-Hans" to "图表设置格式错误：%1@",
            "ja" to "グラフの設定形式が正しくありません: %1@",
            "ko" to "차트 설정 형식이 올바르지 않습니다: %1@",
            "th" to "รูปแบบการตั้งค่าแผนภูมิไม่ถูกต้อง: %1@"
        ),
        "core_msg_014" to mapOf(
            "zh-Hant" to "圖表沒有任何資料數列",
            "en" to "The chart has no data series",
            "zh-Hans" to "图表没有任何数据数列",
            "ja" to "グラフにデータ系列がありません",
            "ko" to "차트에 데이터 계열이 없습니다",
            "th" to "แผนภูมิไม่มีชุดข้อมูล"
        ),
        "core_msg_015" to mapOf(
            "zh-Hant" to "圖表的資料數列都是空的",
            "en" to "All data series in the chart are empty",
            "zh-Hans" to "图表的数据数列都是空的",
            "ja" to "グラフのデータ系列がすべて空です",
            "ko" to "차트의 데이터 계열이 모두 비어 있습니다",
            "th" to "ชุดข้อมูลในแผนภูมิว่างเปล่าทั้งหมด"
        ),
        "core_msg_016" to mapOf(
            "zh-Hant" to "已經在錄音中",
            "en" to "Already recording",
            "zh-Hans" to "已经在录音中",
            "ja" to "すでに録音中です",
            "ko" to "이미 녹음 중입니다",
            "th" to "กำลังบันทึกเสียงอยู่แล้ว"
        ),
        "core_msg_017" to mapOf(
            "zh-Hant" to "目前沒有錄音",
            "en" to "Not recording",
            "zh-Hans" to "目前没有录音",
            "ja" to "録音していません",
            "ko" to "녹음 중이 아닙니다",
            "th" to "ไม่ได้บันทึกเสียงอยู่"
        ),
        "core_msg_018" to mapOf(
            "zh-Hant" to "找不到頁面：%1@",
            "en" to "Page not found: %1@",
            "zh-Hans" to "找不到页面：%1@",
            "ja" to "ページが見つかりません: %1@",
            "ko" to "페이지를 찾을 수 없습니다: %1@",
            "th" to "ไม่พบหน้า: %1@"
        ),
        "core_msg_019" to mapOf(
            "zh-Hant" to "找不到區塊：%1@",
            "en" to "Block not found: %1@",
            "zh-Hans" to "找不到区块：%1@",
            "ja" to "ブロックが見つかりません: %1@",
            "ko" to "블록을 찾을 수 없습니다: %1@",
            "th" to "ไม่พบบล็อก: %1@"
        ),
        "core_msg_020" to mapOf(
            "zh-Hant" to "找不到里程碑：%1@",
            "en" to "Milestone not found: %1@",
            "zh-Hans" to "找不到里程碑：%1@",
            "ja" to "マイルストーンが見つかりません: %1@",
            "ko" to "마일스톤을 찾을 수 없습니다: %1@",
            "th" to "ไม่พบจุดสำคัญ: %1@"
        ),
        "core_msg_021" to mapOf(
            "zh-Hant" to "不支援的格式：%1@",
            "en" to "Unsupported format: %1@",
            "zh-Hans" to "不支持的格式：%1@",
            "ja" to "サポートされていない形式: %1@",
            "ko" to "지원하지 않는 형식: %1@",
            "th" to "ไม่รองรับรูปแบบ: %1@"
        ),
        "core_msg_022" to mapOf(
            "zh-Hant" to "簡報（%1@ 張投影片）",
            "en" to "Presentation (%1@ slides)",
            "zh-Hans" to "演示文稿（%1@ 张投视频）",
            "ja" to "プレゼンテーション（%1@ 枚のスライド）",
            "ko" to "프레젠테이션(슬라이드 %1@장)",
            "th" to "งานนำเสนอ (%1@ สไลด์)"
        ),
        "core_msg_023" to mapOf(
            "zh-Hant" to "簡報（無法讀取：%1@）",
            "en" to "Presentation (cannot be read: %1@)",
            "zh-Hans" to "演示文稿（无法读取：%1@）",
            "ja" to "プレゼンテーション（読み取れません: %1@）",
            "ko" to "프레젠테이션(읽을 수 없음: %1@)",
            "th" to "งานนำเสนอ (อ่านไม่ได้: %1@)"
        ),
        "core_msg_024" to mapOf(
            "zh-Hant" to "blob id 無法解析：%1@",
            "en" to "Cannot parse blob id: %1@",
            "zh-Hans" to "blob id 无法解析：%1@",
            "ja" to "blob id を解析できません: %1@",
            "ko" to "blob id를 해석할 수 없습니다: %1@",
            "th" to "แยกวิเคราะห์ blob id ไม่ได้: %1@"
        ),
        "core_msg_025" to mapOf(
            "zh-Hant" to "變換矩陣必須是 6 個數字",
            "en" to "The transform matrix must have 6 numbers",
            "zh-Hans" to "变换矩阵必须是 6 个数字",
            "ja" to "変換行列は 6 つの数値である必要があります",
            "ko" to "변환 행렬은 숫자 6개여야 합니다",
            "th" to "เมทริกซ์การแปลงต้องมีตัวเลข 6 ตัว"
        ),
        "core_msg_026" to mapOf(
            "zh-Hant" to "變換矩陣無效",
            "en" to "Invalid transform matrix",
            "zh-Hans" to "变换矩阵无效",
            "ja" to "変換行列が無効です",
            "ko" to "변환 행렬이 올바르지 않습니다",
            "th" to "เมทริกซ์การแปลงไม่ถูกต้อง"
        ),
        "core_msg_027" to mapOf(
            "zh-Hant" to "找不到指定頁面：%1@",
            "en" to "The specified page was not found: %1@",
            "zh-Hans" to "找不到指定页面：%1@",
            "ja" to "指定されたページが見つかりません: %1@",
            "ko" to "지정한 페이지를 찾을 수 없습니다: %1@",
            "th" to "ไม่พบหน้าที่ระบุ: %1@"
        ),
        "core_msg_028" to mapOf(
            "zh-Hant" to "不是合法的 id：%1@",
            "en" to "Not a valid id: %1@",
            "zh-Hans" to "不是合法的 id：%1@",
            "ja" to "有効な id ではありません: %1@",
            "ko" to "올바른 id가 아닙니다: %1@",
            "th" to "ไม่ใช่ id ที่ถูกต้อง: %1@"
        ),
        "core_msg_029" to mapOf(
            "zh-Hant" to "模型檔案不存在或無法載入: %1@",
            "en" to "The model file does not exist or cannot be loaded: %1@",
            "zh-Hans" to "模型文件不存在或无法加载: %1@",
            "ja" to "モデルファイルが存在しないか読み込めません: %1@",
            "ko" to "모델 파일이 없거나 로드할 수 없습니다: %1@",
            "th" to "ไม่มีไฟล์โมเดลหรือโหลดไม่ได้: %1@"
        ),
        "core_msg_030" to mapOf(
            "zh-Hant" to "轉錄處理失敗: %1@",
            "en" to "Transcription failed: %1@",
            "zh-Hans" to "转录处理失败: %1@",
            "ja" to "文字起こしの処理に失敗しました: %1@",
            "ko" to "받아쓰기 처리에 실패했습니다: %1@",
            "th" to "ถอดเสียงไม่สำเร็จ: %1@"
        ),
        "core_msg_031" to mapOf(
            "zh-Hant" to "音訊資料無效: %1@",
            "en" to "Invalid audio data: %1@",
            "zh-Hans" to "音频数据无效: %1@",
            "ja" to "オーディオデータが無効です: %1@",
            "ko" to "오디오 데이터가 올바르지 않습니다: %1@",
            "th" to "ข้อมูลเสียงไม่ถูกต้อง: %1@"
        ),
        "core_msg_032" to mapOf(
            "zh-Hant" to "音訊資料長度為零",
            "en" to "The audio data is empty",
            "zh-Hans" to "音频数据长度为零",
            "ja" to "オーディオデータの長さが 0 です",
            "ko" to "오디오 데이터 길이가 0입니다",
            "th" to "ข้อมูลเสียงมีความยาวเป็นศูนย์"
        ),
        "core_msg_033" to mapOf(
            "zh-Hant" to "此平台版本未啟用 Whisper 語音引擎",
            "en" to "The Whisper speech engine is not enabled in this build",
            "zh-Hans" to "此平台版本未启用 Whisper 语音引擎",
            "ja" to "このビルドでは Whisper 音声エンジンが有効になっていません",
            "ko" to "이 버전에서는 Whisper 음성 엔진을 사용할 수 없습니다",
            "th" to "เวอร์ชันนี้ไม่ได้เปิดใช้เอนจินเสียง Whisper"
        ),
        "core_msg_034" to mapOf(
            "zh-Hant" to "不是 Kairumo 備份檔",
            "en" to "This is not a Kairumo backup file",
            "zh-Hans" to "不是 Kairumo 备份文件",
            "ja" to "Kairumo のバックアップファイルではありません",
            "ko" to "Kairumo 백업 파일이 아닙니다",
            "th" to "ไม่ใช่ไฟล์สำรองข้อมูลของ Kairumo"
        ),
        "core_msg_035" to mapOf(
            "zh-Hant" to "備份檔版本 %1@ 比這個版本的 App 新（支援到 %2@），請先更新 App",
            "en" to "This backup (version %1@) is newer than this app supports (up to %2@). Please update the app first",
            "zh-Hans" to "备份文件版本 %1@ 比这个版本的 App 新（支持到 %2@），请先更新 App",
            "ja" to "このバックアップ（バージョン %1@）はこのアプリより新しい形式です（対応: %2@ まで）。先にアプリを更新してください",
            "ko" to "이 백업(버전 %1@)은 이 앱보다 최신입니다(지원: %2@까지). 먼저 앱을 업데이트하세요",
            "th" to "ไฟล์สำรองนี้ (เวอร์ชัน %1@) ใหม่กว่าที่แอปนี้รองรับ (สูงสุด %2@) โปรดอัปเดตแอปก่อน"
        ),
        "core_msg_036" to mapOf(
            "zh-Hant" to "備份檔已損毀：%1@",
            "en" to "The backup file is corrupted: %1@",
            "zh-Hans" to "备份文件已损毁：%1@",
            "ja" to "バックアップファイルが壊れています: %1@",
            "ko" to "백업 파일이 손상되었습니다: %1@",
            "th" to "ไฟล์สำรองข้อมูลเสียหาย: %1@"
        ),
        "core_msg_037" to mapOf(
            "zh-Hant" to "讀寫失敗：%1@",
            "en" to "Read/write failed: %1@",
            "zh-Hans" to "读写失败：%1@",
            "ja" to "読み書きに失敗しました: %1@",
            "ko" to "읽기/쓰기에 실패했습니다: %1@",
            "th" to "อ่าน/เขียนไม่สำเร็จ: %1@"
        ),
        "core_msg_038" to mapOf(
            "zh-Hant" to "索引長度超出檔案",
            "en" to "The index length exceeds the file",
            "zh-Hans" to "索引长度超出文件",
            "ja" to "インデックスの長さがファイルを超えています",
            "ko" to "인덱스 길이가 파일 크기를 초과합니다",
            "th" to "ความยาวดัชนีเกินขนาดไฟล์"
        ),
        "core_msg_039" to mapOf(
            "zh-Hant" to "索引解析失敗：%1@",
            "en" to "Failed to parse the index: %1@",
            "zh-Hans" to "索引解析失败：%1@",
            "ja" to "インデックスの解析に失敗しました: %1@",
            "ko" to "인덱스 해석에 실패했습니다: %1@",
            "th" to "แยกวิเคราะห์ดัชนีไม่สำเร็จ: %1@"
        ),
        "core_msg_040" to mapOf(
            "zh-Hant" to "開不了舊套件：%1@",
            "en" to "Cannot open the old package: %1@",
            "zh-Hans" to "开不了旧套件：%1@",
            "ja" to "旧パッケージを開けません: %1@",
            "ko" to "이전 패키지를 열 수 없습니다: %1@",
            "th" to "เปิดแพ็กเกจเก่าไม่ได้: %1@"
        ),
        "core_msg_041" to mapOf(
            "zh-Hant" to "讀不到舊套件的操作：%1@",
            "en" to "Cannot read the old package's operations: %1@",
            "zh-Hans" to "读不到旧套件的操作：%1@",
            "ja" to "旧パッケージの操作を読み取れません: %1@",
            "ko" to "이전 패키지의 작업을 읽을 수 없습니다: %1@",
            "th" to "อ่านการดำเนินการของแพ็กเกจเก่าไม่ได้: %1@"
        ),
        "core_msg_042" to mapOf(
            "zh-Hant" to "開不了新套件：%1@",
            "en" to "Cannot open the new package: %1@",
            "zh-Hans" to "开不了新套件：%1@",
            "ja" to "新しいパッケージを開けません: %1@",
            "ko" to "새 패키지를 열 수 없습니다: %1@",
            "th" to "เปิดแพ็กเกจใหม่ไม่ได้: %1@"
        ),
        "core_msg_043" to mapOf(
            "zh-Hant" to "寫不進新套件：%1@",
            "en" to "Cannot write to the new package: %1@",
            "zh-Hans" to "写不进新套件：%1@",
            "ja" to "新しいパッケージに書き込めません: %1@",
            "ko" to "새 패키지에 쓸 수 없습니다: %1@",
            "th" to "เขียนลงแพ็กเกจใหม่ไม่ได้: %1@"
        ),
        "core_msg_044" to mapOf(
            "zh-Hant" to "密碼錯誤或資料已被竄改",
            "en" to "Wrong password, or the data has been tampered with",
            "zh-Hans" to "密码错误或数据已被窜改",
            "ja" to "パスワードが違うか、データが改ざんされています",
            "ko" to "비밀번호가 틀렸거나 데이터가 변조되었습니다",
            "th" to "รหัสผ่านไม่ถูกต้องหรือข้อมูลถูกแก้ไข"
        )
    )

    private fun part5(): Map<String, Map<String, String>> = mapOf(
        "core_msg_045" to mapOf(
            "zh-Hant" to "復原碼不正確：%1@",
            "en" to "Incorrect recovery phrase: %1@",
            "zh-Hans" to "恢复码不正确：%1@",
            "ja" to "復元フレーズが正しくありません: %1@",
            "ko" to "복구 문구가 올바르지 않습니다: %1@",
            "th" to "วลีกู้คืนไม่ถูกต้อง: %1@"
        ),
        "core_msg_046" to mapOf(
            "zh-Hant" to "金鑰長度不對（要 32 位元組）",
            "en" to "Wrong key length (32 bytes required)",
            "zh-Hans" to "密钥长度不对（要 32 字节）",
            "ja" to "鍵の長さが正しくありません（32 バイト必要）",
            "ko" to "키 길이가 올바르지 않습니다(32바이트 필요)",
            "th" to "ความยาวคีย์ไม่ถูกต้อง (ต้องเป็น 32 ไบต์)"
        ),
        "core_msg_047" to mapOf(
            "zh-Hant" to "起不了區網節點：%1@",
            "en" to "Cannot start the local network node: %1@",
            "zh-Hans" to "起不了局域网节点：%1@",
            "ja" to "ローカルネットワークのノードを起動できません: %1@",
            "ko" to "로컬 네트워크 노드를 시작할 수 없습니다: %1@",
            "th" to "เริ่มโหนดเครือข่ายภายในไม่ได้: %1@"
        ),
        "core_msg_048" to mapOf(
            "zh-Hant" to "找不到：%1@",
            "en" to "Not found: %1@",
            "zh-Hans" to "找不到：%1@",
            "ja" to "見つかりません: %1@",
            "ko" to "찾을 수 없습니다: %1@",
            "th" to "ไม่พบ: %1@"
        ),
        "core_msg_049" to mapOf(
            "zh-Hant" to "權限不足：%1@",
            "en" to "Permission denied: %1@",
            "zh-Hans" to "权限不足：%1@",
            "ja" to "権限がありません: %1@",
            "ko" to "권한이 없습니다: %1@",
            "th" to "ไม่มีสิทธิ์: %1@"
        ),
        "core_msg_050" to mapOf(
            "zh-Hant" to "網路或伺服器錯誤：%1@",
            "en" to "Network or server error: %1@",
            "zh-Hans" to "网络或服务器错误：%1@",
            "ja" to "ネットワークまたはサーバーのエラー: %1@",
            "ko" to "네트워크 또는 서버 오류: %1@",
            "th" to "ข้อผิดพลาดของเครือข่ายหรือเซิร์ฟเวอร์: %1@"
        ),
        "core_msg_051" to mapOf(
            "zh-Hant" to "Drive 回應不是合法 JSON：%1@",
            "en" to "The Drive response is not valid JSON: %1@",
            "zh-Hans" to "Drive 回应不是合法 JSON：%1@",
            "ja" to "Drive の応答が正しい JSON ではありません: %1@",
            "ko" to "Drive 응답이 올바른 JSON이 아닙니다: %1@",
            "th" to "คำตอบจาก Drive ไม่ใช่ JSON ที่ถูกต้อง: %1@"
        ),
        "core_msg_052" to mapOf(
            "zh-Hant" to "開不了套件：%1@",
            "en" to "Cannot open the package: %1@",
            "zh-Hans" to "开不了套件：%1@",
            "ja" to "パッケージを開けません: %1@",
            "ko" to "패키지를 열 수 없습니다: %1@",
            "th" to "เปิดแพ็กเกจไม่ได้: %1@"
        ),
        "core_msg_053" to mapOf(
            "zh-Hant" to "讀不到本機 oplog：%1@",
            "en" to "Cannot read the local oplog: %1@",
            "zh-Hans" to "读不到本机 oplog：%1@",
            "ja" to "ローカルの oplog を読み取れません: %1@",
            "ko" to "로컬 oplog를 읽을 수 없습니다: %1@",
            "th" to "อ่าน oplog ในเครื่องไม่ได้: %1@"
        ),
        "core_msg_054" to mapOf(
            "zh-Hant" to "讀不到 %1@：%2@",
            "en" to "Cannot read %1@: %2@",
            "zh-Hans" to "读不到 %1@：%2@",
            "ja" to "%1@ を読み取れません: %2@",
            "ko" to "%1@을(를) 읽을 수 없습니다: %2@",
            "th" to "อ่าน %1@ ไม่ได้: %2@"
        ),
        "core_msg_055" to mapOf(
            "zh-Hant" to "寫不進 %1@：%2@",
            "en" to "Cannot write %1@: %2@",
            "zh-Hans" to "写不进 %1@：%2@",
            "ja" to "%1@ に書き込めません: %2@",
            "ko" to "%1@에 쓸 수 없습니다: %2@",
            "th" to "เขียน %1@ ไม่ได้: %2@"
        ),
        "core_msg_056" to mapOf(
            "zh-Hant" to "讀不到本機筆跡：%1@",
            "en" to "Cannot read the local ink data: %1@",
            "zh-Hans" to "读不到本机笔迹：%1@",
            "ja" to "ローカルの手書きデータを読み取れません: %1@",
            "ko" to "로컬 필기 데이터를 읽을 수 없습니다: %1@",
            "th" to "อ่านลายเส้นในเครื่องไม่ได้: %1@"
        ),
        "core_msg_057" to mapOf(
            "zh-Hant" to "讀不到筆跡 %1@：%2@",
            "en" to "Cannot read ink data %1@: %2@",
            "zh-Hans" to "读不到笔迹 %1@：%2@",
            "ja" to "手書きデータ %1@ を読み取れません: %2@",
            "ko" to "필기 데이터 %1@을(를) 읽을 수 없습니다: %2@",
            "th" to "อ่านลายเส้น %1@ ไม่ได้: %2@"
        ),
        "core_msg_058" to mapOf(
            "zh-Hant" to "寫不進筆跡 %1@：%2@",
            "en" to "Cannot write ink data %1@: %2@",
            "zh-Hans" to "写不进笔迹 %1@：%2@",
            "ja" to "手書きデータ %1@ に書き込めません: %2@",
            "ko" to "필기 데이터 %1@에 쓸 수 없습니다: %2@",
            "th" to "เขียนลายเส้น %1@ ไม่ได้: %2@"
        ),
        "core_msg_059" to mapOf(
            "zh-Hant" to "網路錯誤：%1@",
            "en" to "Network error: %1@",
            "zh-Hans" to "网络错误：%1@",
            "ja" to "ネットワークエラー: %1@",
            "ko" to "네트워크 오류: %1@",
            "th" to "ข้อผิดพลาดของเครือข่าย: %1@"
        ),
        "core_msg_060" to mapOf(
            "zh-Hant" to "清單裡沒有這個模型：%1@",
            "en" to "This model is not in the list: %1@",
            "zh-Hans" to "清单里没有这个模型：%1@",
            "ja" to "このモデルは一覧にありません: %1@",
            "ko" to "목록에 이 모델이 없습니다: %1@",
            "th" to "ไม่มีโมเดลนี้ในรายการ: %1@"
        ),
        "core_msg_061" to mapOf(
            "zh-Hant" to "空白紙張",
            "en" to "Blank paper",
            "zh-Hans" to "空白纸张",
            "ja" to "白紙",
            "ko" to "백지",
            "th" to "กระดาษเปล่า"
        ),
        "core_msg_062" to mapOf(
            "zh-Hant" to "方格點陣",
            "en" to "Dot grid",
            "zh-Hans" to "方格点阵",
            "ja" to "ドット方眼",
            "ko" to "점 격자",
            "th" to "ตารางจุด"
        ),
        "core_msg_063" to mapOf(
            "zh-Hant" to "橫線筆記",
            "en" to "Lined notes",
            "zh-Hans" to "横线笔记",
            "ja" to "罫線ノート",
            "ko" to "줄 노트",
            "th" to "สมุดบรรทัด"
        ),
        "core_msg_064" to mapOf(
            "zh-Hant" to "康乃爾",
            "en" to "Cornell",
            "zh-Hans" to "康乃尔",
            "ja" to "コーネル式",
            "ko" to "코넬식",
            "th" to "แบบคอร์เนลล์"
        ),
        "core_msg_065" to mapOf(
            "zh-Hant" to "極細點陣 (5mm)",
            "en" to "Fine dot grid (5 mm)",
            "zh-Hans" to "极细点阵 (5mm)",
            "ja" to "極細ドット（5 mm）",
            "ko" to "초미세 점 격자(5mm)",
            "th" to "ตารางจุดละเอียด (5 มม.)"
        ),
        "core_msg_066" to mapOf(
            "zh-Hant" to "黃金比例與三分構圖",
            "en" to "Golden ratio and rule of thirds",
            "zh-Hans" to "黄金比例与三分构图",
            "ja" to "黄金比と三分割構図",
            "ko" to "황금비와 삼분할 구도",
            "th" to "สัดส่วนทองคำและกฎสามส่วน"
        ),
        "core_msg_067" to mapOf(
            "zh-Hant" to "情緒板與色卡矩陣",
            "en" to "Mood board and color swatch matrix",
            "zh-Hans" to "情绪板与色卡矩阵",
            "ja" to "ムードボードとカラーチップ",
            "ko" to "무드보드와 색상 견본 매트릭스",
            "th" to "มูดบอร์ดและตารางตัวอย่างสี"
        ),
        "core_msg_068" to mapOf(
            "zh-Hant" to "工程藍圖坐標紙",
            "en" to "Engineering blueprint grid paper",
            "zh-Hans" to "工程蓝图坐标纸",
            "ja" to "設計図用の方眼紙",
            "ko" to "공학 청사진 좌표지",
            "th" to "กระดาษกราฟพิมพ์เขียววิศวกรรม"
        ),
        "core_msg_069" to mapOf(
            "zh-Hant" to "30° 等角立體軸測網格",
            "en" to "30° isometric grid",
            "zh-Hans" to "30° 等角立体轴测网格",
            "ja" to "30° アイソメトリックグリッド",
            "ko" to "30° 등각 격자",
            "th" to "ตารางไอโซเมตริก 30°"
        ),
        "core_msg_070" to mapOf(
            "zh-Hant" to "三視圖與剖面範本",
            "en" to "Three-view and section templates",
            "zh-Hans" to "三视图与剖面模板",
            "ja" to "三面図と断面図のテンプレート",
            "ko" to "삼면도 및 단면 템플릿",
            "th" to "แม่แบบภาพสามมุมมองและภาพตัด"
        ),
        "core_msg_071" to mapOf(
            "zh-Hant" to "行動端線框 (8pt Grid)",
            "en" to "Mobile wireframe (8 pt grid)",
            "zh-Hans" to "行动端线框 (8pt Grid)",
            "ja" to "モバイル ワイヤーフレーム（8pt グリッド）",
            "ko" to "모바일 와이어프레임(8pt 그리드)",
            "th" to "ไวร์เฟรมมือถือ (กริด 8pt)"
        ),
        "core_msg_072" to mapOf(
            "zh-Hant" to "響應式 Web 12 欄網格",
            "en" to "Responsive web 12-column grid",
            "zh-Hans" to "响应式 Web 12 栏网格",
            "ja" to "レスポンシブ Web 12 カラムグリッド",
            "ko" to "반응형 웹 12열 그리드",
            "th" to "กริด 12 คอลัมน์สำหรับเว็บตอบสนอง"
        ),
        "core_msg_073" to mapOf(
            "zh-Hant" to "使用者旅程與流程圖",
            "en" to "User journey and flowchart",
            "zh-Hans" to "使用者旅程与流程图",
            "ja" to "ユーザージャーニーとフローチャート",
            "ko" to "사용자 여정과 순서도",
            "th" to "เส้นทางผู้ใช้และผังงาน"
        ),
        "core_msg_074" to mapOf(
            "zh-Hant" to "無法建立執行緒池：%1@",
            "en" to "Cannot create the thread pool: %1@",
            "zh-Hans" to "无法建立线程池：%1@",
            "ja" to "スレッドプールを作成できません: %1@",
            "ko" to "스레드 풀을 만들 수 없습니다: %1@",
            "th" to "สร้างเธรดพูลไม่ได้: %1@"
        ),
        "core_msg_075" to mapOf(
            "zh-Hant" to "無效的埠號 %1@",
            "en" to "Invalid port number %1@",
            "zh-Hans" to "无效的埠号 %1@",
            "ja" to "無効なポート番号 %1@",
            "ko" to "잘못된 포트 번호 %1@",
            "th" to "หมายเลขพอร์ตไม่ถูกต้อง %1@"
        ),
        "core_msg_076" to mapOf(
            "zh-Hant" to "無法綁定 %1@：%2@",
            "en" to "Cannot bind %1@: %2@",
            "zh-Hans" to "无法绑定 %1@：%2@",
            "ja" to "%1@ にバインドできません: %2@",
            "ko" to "%1@에 바인딩할 수 없습니다: %2@",
            "th" to "ผูกกับ %1@ ไม่ได้: %2@"
        ),
        "core_msg_077" to mapOf(
            "zh-Hant" to "取不到綁定的埠：%1@",
            "en" to "Cannot get the bound port: %1@",
            "zh-Hans" to "取不到绑定的埠：%1@",
            "ja" to "バインドしたポートを取得できません: %1@",
            "ko" to "바인딩된 포트를 가져올 수 없습니다: %1@",
            "th" to "อ่านพอร์ตที่ผูกไว้ไม่ได้: %1@"
        ),
        "core_msg_078" to mapOf(
            "zh-Hant" to "設定非阻塞失敗：%1@",
            "en" to "Failed to set non-blocking mode: %1@",
            "zh-Hans" to "设置非阻塞失败：%1@",
            "ja" to "ノンブロッキングの設定に失敗しました: %1@",
            "ko" to "논블로킹 설정에 실패했습니다: %1@",
            "th" to "ตั้งค่าโหมดไม่บล็อกไม่สำเร็จ: %1@"
        ),
        "core_msg_079" to mapOf(
            "zh-Hant" to "中繼狀態鎖已毀損",
            "en" to "The relay state is corrupted",
            "zh-Hans" to "中继状态锁已毁损",
            "ja" to "中継の状態が壊れています",
            "ko" to "릴레이 상태가 손상되었습니다",
            "th" to "สถานะของรีเลย์เสียหาย"
        ),
        "core_msg_080" to mapOf(
            "zh-Hant" to "麥克風",
            "en" to "Microphone",
            "zh-Hans" to "麦克风",
            "ja" to "マイク",
            "ko" to "마이크",
            "th" to "ไมโครโฟน"
        ),
        "core_msg_081" to mapOf(
            "zh-Hant" to "語音辨識權限",
            "en" to "Speech recognition permission",
            "zh-Hans" to "语音辨识权限",
            "ja" to "音声認識の権限",
            "ko" to "음성 인식 권한",
            "th" to "สิทธิ์การรู้จำเสียงพูด"
        ),
        "core_msg_082" to mapOf(
            "zh-Hant" to "手寫辨識",
            "en" to "Handwriting recognition",
            "zh-Hans" to "手写辨识",
            "ja" to "手書き認識",
            "ko" to "필기 인식",
            "th" to "การรู้จำลายมือ"
        ),
        "core_msg_083" to mapOf(
            "zh-Hant" to "語音模型（%1@）",
            "en" to "Speech model (%1@)",
            "zh-Hans" to "语音模型（%1@）",
            "ja" to "音声モデル（%1@）",
            "ko" to "음성 모델(%1@)",
            "th" to "โมเดลเสียง (%1@)"
        ),
        "core_msg_084" to mapOf(
            "zh-Hant" to "AI 模型（%1@）",
            "en" to "AI model (%1@)",
            "zh-Hans" to "AI 模型（%1@）",
            "ja" to "AI モデル（%1@）",
            "ko" to "AI 모델(%1@)",
            "th" to "โมเดล AI (%1@)"
        ),
        "core_msg_085" to mapOf(
            "zh-Hant" to "本機同步資料夾",
            "en" to "Local sync folder",
            "zh-Hans" to "本机同步数据夹",
            "ja" to "ローカル同期フォルダ",
            "ko" to "로컬 동기화 폴더",
            "th" to "โฟลเดอร์ซิงก์ในเครื่อง"
        ),
        "core_msg_086" to mapOf(
            "zh-Hant" to "可以使用",
            "en" to "Ready to use",
            "zh-Hans" to "可以使用",
            "ja" to "利用できます",
            "ko" to "사용할 수 있습니다",
            "th" to "พร้อมใช้งาน"
        ),
        "core_msg_087" to mapOf(
            "zh-Hant" to "需要：%1@",
            "en" to "Needs: %1@",
            "zh-Hans" to "需要：%1@",
            "ja" to "必要なもの: %1@",
            "ko" to "필요: %1@",
            "th" to "ต้องมี: %1@"
        ),
        "core_msg_088" to mapOf(
            "zh-Hant" to "解密失敗：密語錯誤或資料已被竄改",
            "en" to "Decryption failed: wrong passphrase, or the data has been tampered with",
            "zh-Hans" to "解密失败：密码短语错误或数据已被窜改",
            "ja" to "復号に失敗しました: パスフレーズが違うか、データが改ざんされています",
            "ko" to "복호화에 실패했습니다: 암호가 틀렸거나 데이터가 변조되었습니다",
            "th" to "ถอดรหัสไม่สำเร็จ: รหัสผ่านไม่ถูกต้องหรือข้อมูลถูกแก้ไข"
        ),
        "core_msg_089" to mapOf(
            "zh-Hant" to "金鑰匯出失敗：%1@",
            "en" to "Key derivation failed: %1@",
            "zh-Hans" to "密钥汇出失败：%1@",
            "ja" to "鍵の導出に失敗しました: %1@",
            "ko" to "키 파생에 실패했습니다: %1@",
            "th" to "สร้างคีย์ไม่สำเร็จ: %1@"
        ),
        "core_msg_090" to mapOf(
            "zh-Hant" to "亂數來源失敗：%1@",
            "en" to "Random number source failed: %1@",
            "zh-Hans" to "随机数来源失败：%1@",
            "ja" to "乱数源でエラーが発生しました: %1@",
            "ko" to "난수 생성기 오류: %1@",
            "th" to "แหล่งตัวเลขสุ่มล้มเหลว: %1@"
        ),
        "core_msg_091" to mapOf(
            "zh-Hant" to "資料格式錯誤：%1@",
            "en" to "Invalid data format: %1@",
            "zh-Hans" to "数据格式错误：%1@",
            "ja" to "データ形式が正しくありません: %1@",
            "ko" to "데이터 형식이 올바르지 않습니다: %1@",
            "th" to "รูปแบบข้อมูลไม่ถูกต้อง: %1@"
        ),
        "core_msg_092" to mapOf(
            "zh-Hant" to "DEK 長度錯誤",
            "en" to "Wrong DEK length",
            "zh-Hans" to "DEK 长度错误",
            "ja" to "DEK の長さが正しくありません",
            "ko" to "DEK 길이가 올바르지 않습니다",
            "th" to "ความยาว DEK ไม่ถูกต้อง"
        ),
        "core_msg_093" to mapOf(
            "zh-Hant" to "資料過短",
            "en" to "The data is too short",
            "zh-Hans" to "数据过短",
            "ja" to "データが短すぎます",
            "ko" to "데이터가 너무 짧습니다",
            "th" to "ข้อมูลสั้นเกินไป"
        ),
        "core_msg_094" to mapOf(
            "zh-Hant" to "chunk 過短",
            "en" to "The chunk is too short",
            "zh-Hans" to "chunk 过短",
            "ja" to "チャンクが短すぎます",
            "ko" to "청크가 너무 짧습니다",
            "th" to "ชังก์สั้นเกินไป"
        ),
        "core_msg_095" to mapOf(
            "zh-Hant" to "詞表必須是 %1@ 個詞，實得 %2@",
            "en" to "The word list must have %1@ words, got %2@",
            "zh-Hans" to "词表必须是 %1@ 个词，实得 %2@",
            "ja" to "単語リストは %1@ 語である必要があります（実際: %2@）",
            "ko" to "단어 목록은 %1@개여야 합니다(실제: %2@개)",
            "th" to "รายการคำต้องมี %1@ คำ แต่ได้ %2@"
        ),
        "core_msg_096" to mapOf(
            "zh-Hant" to "熵長度須為 16 或 32 bytes，實得 %1@",
            "en" to "Entropy length must be 16 or 32 bytes, got %1@",
            "zh-Hans" to "熵长度须为 16 或 32 bytes，实得 %1@",
            "ja" to "エントロピーの長さは 16 または 32 バイトである必要があります（実際: %1@）",
            "ko" to "엔트로피 길이는 16 또는 32바이트여야 합니다(실제: %1@)",
            "th" to "ความยาวเอนโทรปีต้องเป็น 16 หรือ 32 ไบต์ แต่ได้ %1@"
        ),
        "core_msg_097" to mapOf(
            "zh-Hant" to "無法辨識的詞：%1@",
            "en" to "Unrecognized word: %1@",
            "zh-Hans" to "无法辨识的词：%1@",
            "ja" to "認識できない単語: %1@",
            "ko" to "인식할 수 없는 단어: %1@",
            "th" to "ไม่รู้จักคำ: %1@"
        ),
        "core_msg_098" to mapOf(
            "zh-Hant" to "詞數須為 12 或 24，實得 %1@",
            "en" to "The phrase must have 12 or 24 words, got %1@",
            "zh-Hans" to "词数须为 12 或 24，实得 %1@",
            "ja" to "フレーズは 12 語または 24 語である必要があります（実際: %1@）",
            "ko" to "문구는 12개 또는 24개 단어여야 합니다(실제: %1@개)",
            "th" to "วลีต้องมี 12 หรือ 24 คำ แต่ได้ %1@"
        ),
        "core_msg_099" to mapOf(
            "zh-Hant" to "復原碼校驗失敗，請檢查是否抄錯字或順序有誤",
            "en" to "The recovery phrase checksum failed. Check for a typo or a wrong word order",
            "zh-Hans" to "恢复码校验失败，请检查是否抄错字或顺序有误",
            "ja" to "復元フレーズのチェックに失敗しました。誤字や語順の間違いがないか確認してください",
            "ko" to "복구 문구 검증에 실패했습니다. 오타나 단어 순서가 틀리지 않았는지 확인하세요",
            "th" to "ตรวจสอบวลีกู้คืนไม่ผ่าน โปรดตรวจดูว่าพิมพ์ผิดหรือเรียงคำผิดลำดับหรือไม่"
        ),
        "core_msg_100" to mapOf(
            "zh-Hant" to "房間金鑰格式錯誤（需要 base64 的 32 位元組）",
            "en" to "Invalid room key format (a base64-encoded 32-byte key is required)",
            "zh-Hans" to "房间密钥格式错误（需要 base64 的 32 字节）",
            "ja" to "ルームキーの形式が正しくありません（base64 の 32 バイトが必要）",
            "ko" to "방 키 형식이 올바르지 않습니다(base64로 인코딩된 32바이트 필요)",
            "th" to "รูปแบบคีย์ห้องไม่ถูกต้อง (ต้องเป็น base64 ขนาด 32 ไบต์)"
        ),
        "core_msg_101" to mapOf(
            "zh-Hant" to "密文長度不足，不可能是有效的訊息",
            "en" to "The ciphertext is too short to be a valid message",
            "zh-Hans" to "密文长度不足，不可能是有效的消息",
            "ja" to "暗号文が短すぎて、有効なメッセージではありません",
            "ko" to "암호문이 너무 짧아 올바른 메시지일 수 없습니다",
            "th" to "ข้อความเข้ารหัสสั้นเกินกว่าจะเป็นข้อความที่ถูกต้อง"
        ),
        "core_msg_102" to mapOf(
            "zh-Hant" to "加密失敗",
            "en" to "Encryption failed",
            "zh-Hans" to "加密失败",
            "ja" to "暗号化に失敗しました",
            "ko" to "암호화에 실패했습니다",
            "th" to "เข้ารหัสไม่สำเร็จ"
        ),
        "core_msg_103" to mapOf(
            "zh-Hant" to "解密失敗（金鑰不符或內容被竄改）",
            "en" to "Decryption failed (wrong key, or the content has been tampered with)",
            "zh-Hans" to "解密失败（密钥不符或内容被窜改）",
            "ja" to "復号に失敗しました（鍵が一致しないか、内容が改ざんされています）",
            "ko" to "복호화에 실패했습니다(키가 맞지 않거나 내용이 변조되었습니다)",
            "th" to "ถอดรหัสไม่สำเร็จ (คีย์ไม่ตรงหรือเนื้อหาถูกแก้ไข)"
        ),
        "core_msg_104" to mapOf(
            "zh-Hant" to "取不到亂數",
            "en" to "Cannot get random numbers",
            "zh-Hans" to "取不到随机数",
            "ja" to "乱数を取得できません",
            "ko" to "난수를 가져올 수 없습니다",
            "th" to "สร้างตัวเลขสุ่มไม่ได้"
        ),
        "core_msg_105" to mapOf(
            "zh-Hant" to "找不到物件：%1@",
            "en" to "Object not found: %1@",
            "zh-Hans" to "找不到对象：%1@",
            "ja" to "オブジェクトが見つかりません: %1@",
            "ko" to "개체를 찾을 수 없습니다: %1@",
            "th" to "ไม่พบวัตถุ: %1@"
        ),
        "core_msg_106" to mapOf(
            "zh-Hant" to "群組會形成迴圈",
            "en" to "This grouping would create a loop",
            "zh-Hans" to "群组会形成回圈",
            "ja" to "このグループ化はループになります",
            "ko" to "이 그룹은 순환을 만듭니다",
            "th" to "การจัดกลุ่มนี้จะวนเป็นลูป"
        ),
        "core_msg_107" to mapOf(
            "zh-Hant" to "物件已屬於其他群組：%1@",
            "en" to "The object already belongs to another group: %1@",
            "zh-Hans" to "对象已属於其他群组：%1@",
            "ja" to "オブジェクトはすでに別のグループに属しています: %1@",
            "ko" to "개체가 이미 다른 그룹에 속해 있습니다: %1@",
            "th" to "วัตถุอยู่ในกลุ่มอื่นแล้ว: %1@"
        ),
        "core_msg_108" to mapOf(
            "zh-Hant" to "文件操作資料被截斷",
            "en" to "The document operation data is truncated",
            "zh-Hans" to "文件操作数据被截断",
            "ja" to "ドキュメント操作のデータが途中で切れています",
            "ko" to "문서 작업 데이터가 잘렸습니다",
            "th" to "ข้อมูลการดำเนินการของเอกสารถูกตัดทอน"
        ),
        "core_msg_109" to mapOf(
            "zh-Hant" to "未知的操作類型：%1@",
            "en" to "Unknown operation type: %1@",
            "zh-Hans" to "未知的操作类型：%1@",
            "ja" to "不明な操作の種類: %1@",
            "ko" to "알 수 없는 작업 유형: %1@",
            "th" to "ไม่รู้จักประเภทการดำเนินการ: %1@"
        ),
        "core_msg_110" to mapOf(
            "zh-Hant" to "未知的頁面模板：%1@",
            "en" to "Unknown page template: %1@",
            "zh-Hans" to "未知的页面模板：%1@",
            "ja" to "不明なページテンプレート: %1@",
            "ko" to "알 수 없는 페이지 템플릿: %1@",
            "th" to "ไม่รู้จักแม่แบบหน้า: %1@"
        ),
        "core_msg_111" to mapOf(
            "zh-Hant" to "未知的文字樣式：%1@",
            "en" to "Unknown text style: %1@",
            "zh-Hans" to "未知的文字样式：%1@",
            "ja" to "不明な文字スタイル: %1@",
            "ko" to "알 수 없는 텍스트 스타일: %1@",
            "th" to "ไม่รู้จักรูปแบบข้อความ: %1@"
        ),
        "core_msg_112" to mapOf(
            "zh-Hant" to "未知的物件類型：%1@",
            "en" to "Unknown object type: %1@",
            "zh-Hans" to "未知的对象类型：%1@",
            "ja" to "不明なオブジェクトの種類: %1@",
            "ko" to "알 수 없는 개체 유형: %1@",
            "th" to "ไม่รู้จักประเภทวัตถุ: %1@"
        ),
        "core_msg_113" to mapOf(
            "zh-Hant" to "未知的形狀類型：%1@",
            "en" to "Unknown shape type: %1@",
            "zh-Hans" to "未知的形状类型：%1@",
            "ja" to "不明な図形の種類: %1@",
            "ko" to "알 수 없는 도형 유형: %1@",
            "th" to "ไม่รู้จักประเภทรูปทรง: %1@"
        ),
        "core_msg_114" to mapOf(
            "zh-Hant" to "未知的連接點：%1@",
            "en" to "Unknown connection point: %1@",
            "zh-Hans" to "未知的连接点：%1@",
            "ja" to "不明な接続点: %1@",
            "ko" to "알 수 없는 연결점: %1@",
            "th" to "ไม่รู้จักจุดเชื่อมต่อ: %1@"
        ),
        "core_msg_115" to mapOf(
            "zh-Hant" to "未知的連接線路由：%1@",
            "en" to "Unknown connector routing: %1@",
            "zh-Hans" to "未知的连接线路由：%1@",
            "ja" to "不明なコネクタの経路: %1@",
            "ko" to "알 수 없는 연결선 경로: %1@",
            "th" to "ไม่รู้จักการเดินเส้นเชื่อม: %1@"
        ),
        "core_msg_116" to mapOf(
            "zh-Hant" to "未知的線端樣式：%1@",
            "en" to "Unknown line-end style: %1@",
            "zh-Hans" to "未知的线端样式：%1@",
            "ja" to "不明な線端のスタイル: %1@",
            "ko" to "알 수 없는 선 끝 스타일: %1@",
            "th" to "ไม่รู้จักรูปแบบปลายเส้น: %1@"
        ),
        "core_msg_117" to mapOf(
            "zh-Hant" to "字串不是合法的 UTF-8",
            "en" to "The string is not valid UTF-8",
            "zh-Hans" to "字符串不是合法的 UTF-8",
            "ja" to "文字列が正しい UTF-8 ではありません",
            "ko" to "문자열이 올바른 UTF-8이 아닙니다",
            "th" to "สตริงไม่ใช่ UTF-8 ที่ถูกต้อง"
        ),
        "core_msg_118" to mapOf(
            "zh-Hant" to "非法的 Unicode 碼位：%1@",
            "en" to "Invalid Unicode code point: %1@",
            "zh-Hans" to "非法的 Unicode 码位：%1@",
            "ja" to "無効な Unicode コードポイント: %1@",
            "ko" to "잘못된 유니코드 코드 포인트: %1@",
            "th" to "โค้ดพอยต์ยูนิโคดไม่ถูกต้อง: %1@"
        ),
        "core_msg_119" to mapOf(
            "zh-Hant" to "分欄",
            "en" to "Columns",
            "zh-Hans" to "分栏",
            "ja" to "段組み",
            "ko" to "단 나누기",
            "th" to "คอลัมน์"
        ),
        "core_msg_120" to mapOf(
            "zh-Hant" to "浮動圖文",
            "en" to "Floating text and images",
            "zh-Hans" to "浮动图文",
            "ja" to "フローティングの図と文章",
            "ko" to "떠 있는 그림과 텍스트",
            "th" to "รูปภาพและข้อความลอย"
        ),
        "core_msg_121" to mapOf(
            "zh-Hant" to "追蹤修訂",
            "en" to "Track changes",
            "zh-Hans" to "修订",
            "ja" to "変更履歴",
            "ko" to "변경 내용 추적",
            "th" to "ติดตามการเปลี่ยนแปลง"
        ),
        "core_msg_122" to mapOf(
            "zh-Hant" to "頁首頁尾",
            "en" to "Headers and footers",
            "zh-Hans" to "页眉页脚",
            "ja" to "ヘッダーとフッター",
            "ko" to "머리글과 바닥글",
            "th" to "ส่วนหัวและส่วนท้าย"
        ),
        "core_msg_123" to mapOf(
            "zh-Hant" to "註腳",
            "en" to "Footnotes",
            "zh-Hans" to "脚注",
            "ja" to "脚注",
            "ko" to "각주",
            "th" to "เชิงอรรถ"
        ),
        "core_msg_124" to mapOf(
            "zh-Hant" to "巨集",
            "en" to "Macros",
            "zh-Hans" to "宏",
            "ja" to "マクロ",
            "ko" to "매크로",
            "th" to "มาโคร"
        )
    )

    private fun part6(): Map<String, Map<String, String>> = mapOf(
        "core_msg_125" to mapOf(
            "zh-Hant" to "樞紐分析",
            "en" to "Pivot tables",
            "zh-Hans" to "数据透视表",
            "ja" to "ピボットテーブル",
            "ko" to "피벗 테이블",
            "th" to "พิวอตเทเบิล"
        ),
        "core_msg_126" to mapOf(
            "zh-Hant" to "圖表",
            "en" to "Charts",
            "zh-Hans" to "图表",
            "ja" to "グラフ",
            "ko" to "차트",
            "th" to "แผนภูมิ"
        ),
        "core_msg_127" to mapOf(
            "zh-Hant" to "條件式格式",
            "en" to "Conditional formatting",
            "zh-Hans" to "条件格式",
            "ja" to "条件付き書式",
            "ko" to "조건부 서식",
            "th" to "การจัดรูปแบบตามเงื่อนไข"
        ),
        "core_msg_128" to mapOf(
            "zh-Hant" to "資料驗證",
            "en" to "Data validation",
            "zh-Hans" to "数据验证",
            "ja" to "データの入力規則",
            "ko" to "데이터 유효성 검사",
            "th" to "การตรวจสอบข้อมูล"
        ),
        "core_msg_129" to mapOf(
            "zh-Hant" to "編輯（僅預覽）",
            "en" to "Editing (preview only)",
            "zh-Hans" to "编辑（仅预览）",
            "ja" to "編集（プレビューのみ）",
            "ko" to "편집(미리보기 전용)",
            "th" to "การแก้ไข (ดูตัวอย่างเท่านั้น)"
        ),
        "core_msg_130" to mapOf(
            "zh-Hant" to "動畫",
            "en" to "Animations",
            "zh-Hans" to "动画",
            "ja" to "アニメーション",
            "ko" to "애니메이션",
            "th" to "แอนิเมชัน"
        ),
        "core_msg_131" to mapOf(
            "zh-Hant" to "轉場",
            "en" to "Transitions",
            "zh-Hans" to "切换",
            "ja" to "画面切り替え",
            "ko" to "전환",
            "th" to "การเปลี่ยนสไลด์"
        ),
        "core_msg_132" to mapOf(
            "zh-Hant" to "備忘稿",
            "en" to "Speaker notes",
            "zh-Hans" to "备注",
            "ja" to "スピーカーノート",
            "ko" to "발표자 노트",
            "th" to "บันทึกผู้บรรยาย"
        ),
        "core_msg_133" to mapOf(
            "zh-Hant" to "表單欄位",
            "en" to "Form fields",
            "zh-Hans" to "表单字段",
            "ja" to "フォームフィールド",
            "ko" to "양식 필드",
            "th" to "ช่องแบบฟอร์ม"
        ),
        "core_msg_134" to mapOf(
            "zh-Hant" to "數位簽章",
            "en" to "Digital signatures",
            "zh-Hans" to "数字签名",
            "ja" to "電子署名",
            "ko" to "디지털 서명",
            "th" to "ลายเซ็นดิจิทัล"
        ),
        "core_msg_135" to mapOf(
            "zh-Hant" to "找不到檔案：%1@",
            "en" to "File not found: %1@",
            "zh-Hans" to "找不到文件：%1@",
            "ja" to "ファイルが見つかりません: %1@",
            "ko" to "파일을 찾을 수 없습니다: %1@",
            "th" to "ไม่พบไฟล์: %1@"
        ),
        "core_msg_136" to mapOf(
            "zh-Hant" to "%1@ 目前不支援：%2@",
            "en" to "%1@ is not supported yet: %2@",
            "zh-Hans" to "%1@ 目前不支持：%2@",
            "ja" to "%1@ はまだサポートされていません: %2@",
            "ko" to "%1@은(는) 아직 지원하지 않습니다: %2@",
            "th" to "ยังไม่รองรับ %1@: %2@"
        ),
        "core_msg_137" to mapOf(
            "zh-Hant" to "檔案格式錯誤：%1@",
            "en" to "Invalid file format: %1@",
            "zh-Hans" to "文件格式错误：%1@",
            "ja" to "ファイル形式が正しくありません: %1@",
            "ko" to "파일 형식이 올바르지 않습니다: %1@",
            "th" to "รูปแบบไฟล์ไม่ถูกต้อง: %1@"
        ),
        "core_msg_138" to mapOf(
            "zh-Hant" to "不是 ZIP 容器，無法作為 pptx",
            "en" to "Not a ZIP container, so it cannot be a pptx",
            "zh-Hans" to "不是 ZIP 容器，无法作为 pptx",
            "ja" to "ZIP コンテナではないため pptx として扱えません",
            "ko" to "ZIP 컨테이너가 아니므로 pptx로 처리할 수 없습니다",
            "th" to "ไม่ใช่คอนเทนเนอร์ ZIP จึงใช้เป็น pptx ไม่ได้"
        ),
        "core_msg_139" to mapOf(
            "zh-Hant" to "找不到投影片；可能不是 pptx 或已加密",
            "en" to "No slides found; the file may not be a pptx, or it may be encrypted",
            "zh-Hans" to "找不到投视频；可能不是 pptx 或已加密",
            "ja" to "スライドが見つかりません。pptx ではないか、暗号化されている可能性があります",
            "ko" to "슬라이드를 찾을 수 없습니다. pptx가 아니거나 암호화되었을 수 있습니다",
            "th" to "ไม่พบสไลด์ ไฟล์อาจไม่ใช่ pptx หรืออาจถูกเข้ารหัส"
        ),
        "core_msg_140" to mapOf(
            "zh-Hant" to "第 %1@ 個區塊缺少 source",
            "en" to "Block %1@ is missing source",
            "zh-Hans" to "第 %1@ 个区块缺少 source",
            "ja" to "%1@ 番目のブロックに source がありません",
            "ko" to "%1@번째 블록에 source가 없습니다",
            "th" to "บล็อกที่ %1@ ไม่มี source"
        ),
        "core_msg_141" to mapOf(
            "zh-Hant" to "第 %1@ 個區塊缺少 content",
            "en" to "Block %1@ is missing content",
            "zh-Hans" to "第 %1@ 个区块缺少 content",
            "ja" to "%1@ 番目のブロックに content がありません",
            "ko" to "%1@번째 블록에 content가 없습니다",
            "th" to "บล็อกที่ %1@ ไม่มี content"
        ),
        "core_msg_142" to mapOf(
            "zh-Hant" to "第 %1@ 個區塊的類型未知：%2@",
            "en" to "Block %1@ has an unknown type: %2@",
            "zh-Hans" to "第 %1@ 个区块的类型未知：%2@",
            "ja" to "%1@ 番目のブロックの種類が不明です: %2@",
            "ko" to "%1@번째 블록의 유형을 알 수 없습니다: %2@",
            "th" to "บล็อกที่ %1@ มีประเภทที่ไม่รู้จัก: %2@"
        ),
        "core_msg_143" to mapOf(
            "zh-Hant" to "筆記本內無任何頁面可匯出",
            "en" to "The notebook has no pages to export",
            "zh-Hans" to "笔记本内无任何页面可汇出",
            "ja" to "書き出せるページがノートにありません",
            "ko" to "내보낼 페이지가 노트에 없습니다",
            "th" to "สมุดบันทึกไม่มีหน้าให้ส่งออก"
        ),
        "core_msg_144" to mapOf(
            "zh-Hant" to "儲存讀取錯誤：%1@",
            "en" to "Storage read error: %1@",
            "zh-Hans" to "保存读取错误：%1@",
            "ja" to "ストレージの読み取りエラー: %1@",
            "ko" to "저장소 읽기 오류: %1@",
            "th" to "ข้อผิดพลาดในการอ่านที่เก็บข้อมูล: %1@"
        ),
        "core_msg_145" to mapOf(
            "zh-Hant" to "圖片編碼錯誤：%1@",
            "en" to "Image encoding error: %1@",
            "zh-Hans" to "图片编码错误：%1@",
            "ja" to "画像のエンコードエラー: %1@",
            "ko" to "이미지 인코딩 오류: %1@",
            "th" to "ข้อผิดพลาดในการเข้ารหัสรูปภาพ: %1@"
        ),
        "core_msg_146" to mapOf(
            "zh-Hant" to "資料無效：%1@",
            "en" to "Invalid data: %1@",
            "zh-Hans" to "数据无效：%1@",
            "ja" to "データが無効です: %1@",
            "ko" to "데이터가 올바르지 않습니다: %1@",
            "th" to "ข้อมูลไม่ถูกต้อง: %1@"
        ),
        "core_msg_147" to mapOf(
            "zh-Hant" to "不是 PADNINK 筆畫檔",
            "en" to "Not a PADNINK ink file",
            "zh-Hans" to "不是 PADNINK 笔画文件",
            "ja" to "PADNINK の手書きファイルではありません",
            "ko" to "PADNINK 필기 파일이 아닙니다",
            "th" to "ไม่ใช่ไฟล์ลายเส้น PADNINK"
        ),
        "core_msg_148" to mapOf(
            "zh-Hant" to "不支援的格式版本：%1@",
            "en" to "Unsupported format version: %1@",
            "zh-Hans" to "不支持的格式版本：%1@",
            "ja" to "サポートされていない形式のバージョン: %1@",
            "ko" to "지원하지 않는 형식 버전: %1@",
            "th" to "ไม่รองรับรูปแบบเวอร์ชัน: %1@"
        ),
        "core_msg_149" to mapOf(
            "zh-Hant" to "檔案被截斷",
            "en" to "The file is truncated",
            "zh-Hans" to "文件被截断",
            "ja" to "ファイルが途中で切れています",
            "ko" to "파일이 잘렸습니다",
            "th" to "ไฟล์ถูกตัดทอน"
        ),
        "core_msg_150" to mapOf(
            "zh-Hant" to "未知的 tool_id：%1@",
            "en" to "Unknown tool_id: %1@",
            "zh-Hans" to "未知的 tool_id：%1@",
            "ja" to "不明な tool_id: %1@",
            "ko" to "알 수 없는 tool_id: %1@",
            "th" to "ไม่รู้จัก tool_id: %1@"
        ),
        "core_msg_151" to mapOf(
            "zh-Hant" to "未知的記錄類型：%1@",
            "en" to "Unknown record type: %1@",
            "zh-Hans" to "未知的记录类型：%1@",
            "ja" to "不明なレコードの種類: %1@",
            "ko" to "알 수 없는 레코드 유형: %1@",
            "th" to "ไม่รู้จักประเภทระเบียน: %1@"
        ),
        "core_msg_152" to mapOf(
            "zh-Hant" to "沒有可以處理的文字",
            "en" to "There is no text to process",
            "zh-Hans" to "没有可以处理的文字",
            "ja" to "処理できるテキストがありません",
            "ko" to "처리할 텍스트가 없습니다",
            "th" to "ไม่มีข้อความให้ประมวลผล"
        ),
        "core_msg_153" to mapOf(
            "zh-Hant" to "載入模型失敗：%1@",
            "en" to "Failed to load the model: %1@",
            "zh-Hans" to "加载模型失败：%1@",
            "ja" to "モデルの読み込みに失敗しました: %1@",
            "ko" to "모델 로드에 실패했습니다: %1@",
            "th" to "โหลดโมเดลไม่สำเร็จ: %1@"
        ),
        "core_msg_154" to mapOf(
            "zh-Hant" to "模型狀態已損毀",
            "en" to "The model state is corrupted",
            "zh-Hans" to "模型状态已损毁",
            "ja" to "モデルの状態が壊れています",
            "ko" to "모델 상태가 손상되었습니다",
            "th" to "สถานะของโมเดลเสียหาย"
        ),
        "core_msg_155" to mapOf(
            "zh-Hant" to "提示詞轉 token 失敗：%1@",
            "en" to "Failed to tokenize the prompt: %1@",
            "zh-Hans" to "提示词转 token 失败：%1@",
            "ja" to "プロンプトのトークン化に失敗しました: %1@",
            "ko" to "프롬프트 토큰화에 실패했습니다: %1@",
            "th" to "แปลงพรอมต์เป็นโทเค็นไม่สำเร็จ: %1@"
        ),
        "core_msg_156" to mapOf(
            "zh-Hant" to "建立 context 失敗：%1@",
            "en" to "Failed to create the context: %1@",
            "zh-Hans" to "建立 context 失败：%1@",
            "ja" to "コンテキストの作成に失敗しました: %1@",
            "ko" to "컨텍스트 생성에 실패했습니다: %1@",
            "th" to "สร้างคอนเท็กซ์ไม่สำเร็จ: %1@"
        ),
        "core_msg_157" to mapOf(
            "zh-Hant" to "decode 失敗：%1@",
            "en" to "Decode failed: %1@",
            "zh-Hans" to "decode 失败：%1@",
            "ja" to "デコードに失敗しました: %1@",
            "ko" to "디코딩에 실패했습니다: %1@",
            "th" to "ถอดรหัสไม่สำเร็จ: %1@"
        ),
        "core_msg_158" to mapOf(
            "zh-Hant" to "模型校驗失敗：期望 %1@…，實得 %2@…（檔案已刪除）",
            "en" to "Model verification failed: expected %1@…, got %2@… (the file was deleted)",
            "zh-Hans" to "模型校验失败：期望 %1@…，实得 %2@…（文件已删除）",
            "ja" to "モデルの検証に失敗しました: 期待値 %1@…、実際 %2@…（ファイルは削除されました）",
            "ko" to "모델 검증에 실패했습니다: 기대값 %1@…, 실제 %2@…(파일이 삭제되었습니다)",
            "th" to "ตรวจสอบโมเดลไม่ผ่าน: คาดว่า %1@… แต่ได้ %2@… (ลบไฟล์แล้ว)"
        ),
        "core_msg_159" to mapOf(
            "zh-Hant" to "大小不符：期望 %1@ bytes，實得 %2@",
            "en" to "Size mismatch: expected %1@ bytes, got %2@",
            "zh-Hans" to "大小不符：期望 %1@ bytes，实得 %2@",
            "ja" to "サイズが一致しません: 期待値 %1@ バイト、実際 %2@",
            "ko" to "크기가 맞지 않습니다: 기대값 %1@바이트, 실제 %2@",
            "th" to "ขนาดไม่ตรงกัน: คาดว่า %1@ ไบต์ แต่ได้ %2@"
        ),
        "core_msg_160" to mapOf(
            "zh-Hant" to "模型清單格式錯誤：%1@",
            "en" to "Invalid model list format: %1@",
            "zh-Hans" to "模型清单格式错误：%1@",
            "ja" to "モデル一覧の形式が正しくありません: %1@",
            "ko" to "모델 목록 형식이 올바르지 않습니다: %1@",
            "th" to "รูปแบบรายการโมเดลไม่ถูกต้อง: %1@"
        ),
        "core_msg_161" to mapOf(
            "zh-Hant" to "revision 必須是實際的 commit sha，不能是浮動參照：%1@",
            "en" to "revision must be an actual commit sha, not a floating reference: %1@",
            "zh-Hans" to "revision 必须是实际的 commit sha，不能是浮动参照：%1@",
            "ja" to "revision は実際の commit sha である必要があり、可変の参照は使えません: %1@",
            "ko" to "revision은 실제 commit sha여야 하며 유동 참조는 안 됩니다: %1@",
            "th" to "revision ต้องเป็น commit sha จริง ไม่ใช่การอ้างอิงที่เปลี่ยนได้: %1@"
        ),
        "core_msg_162" to mapOf(
            "zh-Hant" to "授權檔雜湊格式錯誤：%1@",
            "en" to "Invalid licence file hash format: %1@",
            "zh-Hans" to "授权文件杂凑格式错误：%1@",
            "ja" to "ライセンスファイルのハッシュ形式が正しくありません: %1@",
            "ko" to "라이선스 파일 해시 형식이 올바르지 않습니다: %1@",
            "th" to "รูปแบบแฮชของไฟล์สัญญาอนุญาตไม่ถูกต้อง: %1@"
        ),
        "core_msg_163" to mapOf(
            "zh-Hant" to "授權檔只有 %1@ bytes，多半不是授權文本而是錯誤頁",
            "en" to "The licence file is only %1@ bytes; it is probably an error page, not licence text",
            "zh-Hans" to "授权文件只有 %1@ bytes，多半不是授权文本而是错误页",
            "ja" to "ライセンスファイルは %1@ バイトしかありません。ライセンス本文ではなくエラーページの可能性があります",
            "ko" to "라이선스 파일이 %1@바이트뿐입니다. 라이선스 본문이 아니라 오류 페이지일 가능성이 큽니다",
            "th" to "ไฟล์สัญญาอนุญาตมีเพียง %1@ ไบต์ น่าจะเป็นหน้าแสดงข้อผิดพลาดไม่ใช่ข้อความสัญญาอนุญาต"
        ),
        "core_msg_164" to mapOf(
            "zh-Hant" to "model card 未宣告授權名稱",
            "en" to "The model card does not declare a licence name",
            "zh-Hans" to "model card 未宣告授权名称",
            "ja" to "モデルカードにライセンス名が記載されていません",
            "ko" to "모델 카드에 라이선스 이름이 명시되어 있지 않습니다",
            "th" to "โมเดลการ์ดไม่ได้ระบุชื่อสัญญาอนุญาต"
        ),
        "core_msg_165" to mapOf(
            "zh-Hant" to "沒有任何產出檔案",
            "en" to "There are no output files",
            "zh-Hans" to "没有任何产出文件",
            "ja" to "出力ファイルがありません",
            "ko" to "출력 파일이 없습니다",
            "th" to "ไม่มีไฟล์ผลลัพธ์"
        ),
        "core_msg_166" to mapOf(
            "zh-Hant" to "產出檔案雜湊格式錯誤：%1@",
            "en" to "Invalid output file hash format: %1@",
            "zh-Hans" to "产出文件杂凑格式错误：%1@",
            "ja" to "出力ファイルのハッシュ形式が正しくありません: %1@",
            "ko" to "출력 파일 해시 형식이 올바르지 않습니다: %1@",
            "th" to "รูปแบบแฮชของไฟล์ผลลัพธ์ไม่ถูกต้อง: %1@"
        ),
        "core_msg_167" to mapOf(
            "zh-Hant" to "缺少工具版本紀錄：%1@",
            "en" to "Missing tool version record: %1@",
            "zh-Hans" to "缺少工具版本纪录：%1@",
            "ja" to "ツールのバージョン記録がありません: %1@",
            "ko" to "도구 버전 기록이 없습니다: %1@",
            "th" to "ไม่มีบันทึกเวอร์ชันของเครื่องมือ: %1@"
        ),
        "core_msg_168" to mapOf(
            "zh-Hant" to "不是有效的 PDF 檔",
            "en" to "Not a valid PDF file",
            "zh-Hans" to "不是有效的 PDF 文件",
            "ja" to "有効な PDF ファイルではありません",
            "ko" to "올바른 PDF 파일이 아닙니다",
            "th" to "ไม่ใช่ไฟล์ PDF ที่ถูกต้อง"
        ),
        "core_msg_169" to mapOf(
            "zh-Hant" to "這份 PDF 需要密碼",
            "en" to "This PDF requires a password",
            "zh-Hans" to "这份 PDF 需要密码",
            "ja" to "この PDF にはパスワードが必要です",
            "ko" to "이 PDF에는 비밀번호가 필요합니다",
            "th" to "PDF นี้ต้องใช้รหัสผ่าน"
        ),
        "core_msg_170" to mapOf(
            "zh-Hant" to "頁碼 %1@ 超出範圍（共 %2@ 頁）",
            "en" to "Page number %1@ is out of range (%2@ pages in total)",
            "zh-Hans" to "页码 %1@ 超出范围（共 %2@ 页）",
            "ja" to "ページ番号 %1@ が範囲外です（全 %2@ ページ）",
            "ko" to "페이지 번호 %1@이(가) 범위를 벗어났습니다(총 %2@페이지)",
            "th" to "หมายเลขหน้า %1@ เกินช่วง (ทั้งหมด %2@ หน้า)"
        ),
        "core_msg_171" to mapOf(
            "zh-Hant" to "PDF 引擎錯誤：%1@",
            "en" to "PDF engine error: %1@",
            "zh-Hans" to "PDF 引擎错误：%1@",
            "ja" to "PDF エンジンのエラー: %1@",
            "ko" to "PDF 엔진 오류: %1@",
            "th" to "ข้อผิดพลาดของเอนจิน PDF: %1@"
        ),
        "core_msg_172" to mapOf(
            "zh-Hant" to "找不到 libpdfium：%1@",
            "en" to "libpdfium not found: %1@",
            "zh-Hans" to "找不到 libpdfium：%1@",
            "ja" to "libpdfium が見つかりません: %1@",
            "ko" to "libpdfium을 찾을 수 없습니다: %1@",
            "th" to "ไม่พบ libpdfium: %1@"
        ),
        "core_msg_173" to mapOf(
            "zh-Hant" to "找不到標點模型：%1@",
            "en" to "Punctuation model not found: %1@",
            "zh-Hans" to "找不到标点模型：%1@",
            "ja" to "句読点モデルが見つかりません: %1@",
            "ko" to "문장 부호 모델을 찾을 수 없습니다: %1@",
            "th" to "ไม่พบโมเดลเครื่องหมายวรรคตอน: %1@"
        ),
        "core_msg_174" to mapOf(
            "zh-Hant" to "找不到詞表：%1@",
            "en" to "Vocabulary not found: %1@",
            "zh-Hans" to "找不到词表：%1@",
            "ja" to "語彙リストが見つかりません: %1@",
            "ko" to "어휘 목록을 찾을 수 없습니다: %1@",
            "th" to "ไม่พบรายการคำศัพท์: %1@"
        ),
        "core_msg_175" to mapOf(
            "zh-Hant" to "詞表格式錯誤：%1@",
            "en" to "Invalid vocabulary format: %1@",
            "zh-Hans" to "词表格式错误：%1@",
            "ja" to "語彙リストの形式が正しくありません: %1@",
            "ko" to "어휘 목록 형식이 올바르지 않습니다: %1@",
            "th" to "รูปแบบรายการคำศัพท์ไม่ถูกต้อง: %1@"
        ),
        "core_msg_176" to mapOf(
            "zh-Hant" to "詞表缺少 <unk>",
            "en" to "The vocabulary is missing <unk>",
            "zh-Hans" to "词表缺少 <unk>",
            "ja" to "語彙リストに <unk> がありません",
            "ko" to "어휘 목록에 <unk>가 없습니다",
            "th" to "รายการคำศัพท์ไม่มี <unk>"
        ),
        "core_msg_177" to mapOf(
            "zh-Hant" to "logits 維度為 0",
            "en" to "The logits dimension is 0",
            "zh-Hans" to "logits 维度为 0",
            "ja" to "logits の次元が 0 です",
            "ko" to "logits 차원이 0입니다",
            "th" to "มิติของ logits เป็น 0"
        ),
        "core_msg_178" to mapOf(
            "zh-Hant" to "辨識後端不可用：%1@",
            "en" to "Recognition backend unavailable: %1@",
            "zh-Hans" to "辨识后端不可用：%1@",
            "ja" to "認識バックエンドを利用できません: %1@",
            "ko" to "인식 백엔드를 사용할 수 없습니다: %1@",
            "th" to "ส่วนหลังบ้านการรู้จำใช้ไม่ได้: %1@"
        ),
        "core_msg_179" to mapOf(
            "zh-Hant" to "無候選結果",
            "en" to "No candidate results",
            "zh-Hans" to "无候选结果",
            "ja" to "候補がありません",
            "ko" to "후보 결과가 없습니다",
            "th" to "ไม่มีผลลัพธ์ตัวเลือก"
        ),
        "core_msg_180" to mapOf(
            "zh-Hant" to "密碼錯誤，無法加入房間",
            "en" to "Wrong password; cannot join the room",
            "zh-Hans" to "密码错误，无法加入房间",
            "ja" to "パスワードが違うため、ルームに参加できません",
            "ko" to "비밀번호가 틀려 방에 참가할 수 없습니다",
            "th" to "รหัสผ่านไม่ถูกต้อง เข้าร่วมห้องไม่ได้"
        ),
        "core_msg_181" to mapOf(
            "zh-Hant" to "僅房主有權關閉此房間",
            "en" to "Only the host can close this room",
            "zh-Hans" to "仅房主有权关闭此房间",
            "ja" to "このルームを閉じられるのはホストだけです",
            "ko" to "방장만 이 방을 닫을 수 있습니다",
            "th" to "เฉพาะเจ้าของห้องเท่านั้นที่ปิดห้องนี้ได้"
        ),
        "core_msg_182" to mapOf(
            "zh-Hant" to "房主已結束本次線上協同會議",
            "en" to "The host has ended this collaboration session",
            "zh-Hans" to "房主已结束本次线上协同会议",
            "ja" to "ホストがこの共同編集セッションを終了しました",
            "ko" to "방장이 이번 공동 편집 세션을 종료했습니다",
            "th" to "เจ้าของห้องได้จบการแก้ไขร่วมกันครั้งนี้แล้ว"
        ),
        "core_msg_183" to mapOf(
            "zh-Hant" to "房間不存在",
            "en" to "The room does not exist",
            "zh-Hans" to "房间不存在",
            "ja" to "ルームが存在しません",
            "ko" to "방이 없습니다",
            "th" to "ไม่มีห้องนี้"
        ),
        "core_msg_184" to mapOf(
            "zh-Hant" to "無法解析之訊息格式",
            "en" to "The message format could not be parsed",
            "zh-Hans" to "无法解析之消息格式",
            "ja" to "メッセージの形式を解析できませんでした",
            "ko" to "메시지 형식을 해석할 수 없습니다",
            "th" to "แยกวิเคราะห์รูปแบบข้อความไม่ได้"
        ),
        "core_msg_185" to mapOf(
            "zh-Hant" to "找不到 blob：%1@",
            "en" to "Blob not found: %1@",
            "zh-Hans" to "找不到 blob：%1@",
            "ja" to "blob が見つかりません: %1@",
            "ko" to "blob을 찾을 수 없습니다: %1@",
            "th" to "ไม่พบ blob: %1@"
        ),
        "core_msg_186" to mapOf(
            "zh-Hant" to "blob 損毀：期望 %1@，實得 %2@",
            "en" to "Blob is corrupted: expected %1@, got %2@",
            "zh-Hans" to "blob 损毁：期望 %1@，实得 %2@",
            "ja" to "blob が壊れています: 期待値 %1@、実際 %2@",
            "ko" to "blob이 손상되었습니다: 기대값 %1@, 실제 %2@",
            "th" to "blob เสียหาย: คาดว่า %1@ แต่ได้ %2@"
        ),
        "core_msg_187" to mapOf(
            "zh-Hant" to "不是 .padnote 套件：%1@",
            "en" to "Not a .padnote package: %1@",
            "zh-Hans" to "不是 .padnote 套件：%1@",
            "ja" to ".padnote パッケージではありません: %1@",
            "ko" to ".padnote 패키지가 아닙니다: %1@",
            "th" to "ไม่ใช่แพ็กเกจ .padnote: %1@"
        ),
        "core_msg_188" to mapOf(
            "zh-Hant" to "此筆記本需要版本 %1@ 的讀取器，本程式為 %2@，請升級",
            "en" to "This notebook needs a reader of version %1@; this app is %2@. Please update",
            "zh-Hans" to "此笔记本需要版本 %1@ 的读取器，本程序为 %2@，请升级",
            "ja" to "このノートにはバージョン %1@ のリーダーが必要です（このアプリは %2@）。アップデートしてください",
            "ko" to "이 노트는 버전 %1@ 리더가 필요합니다(이 앱은 %2@). 업데이트하세요",
            "th" to "สมุดบันทึกนี้ต้องใช้ตัวอ่านเวอร์ชัน %1@ แต่แอปนี้เป็น %2@ โปรดอัปเดต"
        ),
        "core_msg_189" to mapOf(
            "zh-Hant" to "manifest 解析失敗：%1@",
            "en" to "Failed to parse the manifest: %1@",
            "zh-Hans" to "manifest 解析失败：%1@",
            "ja" to "manifest の解析に失敗しました: %1@",
            "ko" to "manifest 해석에 실패했습니다: %1@",
            "th" to "แยกวิเคราะห์ manifest ไม่สำเร็จ: %1@"
        ),
        "core_msg_190" to mapOf(
            "zh-Hant" to "文件操作日誌損毀：%1@",
            "en" to "The document operation log is corrupted: %1@",
            "zh-Hans" to "文件操作日志损毁：%1@",
            "ja" to "ドキュメント操作ログが壊れています: %1@",
            "ko" to "문서 작업 로그가 손상되었습니다: %1@",
            "th" to "บันทึกการดำเนินการของเอกสารเสียหาย: %1@"
        ),
        "core_msg_191" to mapOf(
            "zh-Hant" to "筆畫檔錯誤：%1@",
            "en" to "Ink file error: %1@",
            "zh-Hans" to "笔画文件错误：%1@",
            "ja" to "手書きファイルのエラー: %1@",
            "ko" to "필기 파일 오류: %1@",
            "th" to "ข้อผิดพลาดของไฟล์ลายเส้น: %1@"
        ),
        "core_msg_192" to mapOf(
            "zh-Hant" to "封裝壓縮錯誤：%1@",
            "en" to "Package compression error: %1@",
            "zh-Hans" to "封装压缩错误：%1@",
            "ja" to "パッケージの圧縮エラー: %1@",
            "ko" to "패키지 압축 오류: %1@",
            "th" to "ข้อผิดพลาดในการบีบอัดแพ็กเกจ: %1@"
        ),
        "core_msg_193" to mapOf(
            "zh-Hant" to "這個套件沒有加密",
            "en" to "This package is not encrypted",
            "zh-Hans" to "这个套件没有加密",
            "ja" to "このパッケージは暗号化されていません",
            "ko" to "이 패키지는 암호화되어 있지 않습니다",
            "th" to "แพ็กเกจนี้ไม่ได้เข้ารหัส"
        ),
        "core_msg_194" to mapOf(
            "zh-Hant" to "salt 不是合法 base64：%1@",
            "en" to "salt is not valid base64: %1@",
            "zh-Hans" to "salt 不是合法 base64：%1@",
            "ja" to "salt が正しい base64 ではありません: %1@",
            "ko" to "salt가 올바른 base64가 아닙니다: %1@",
            "th" to "salt ไม่ใช่ base64 ที่ถูกต้อง: %1@"
        ),
        "core_msg_195" to mapOf(
            "zh-Hant" to "這本筆記是在復原碼還不能解鎖的版本建立的 —— 它的復原碼從來沒有被用來包住金鑰，只有密碼開得了",
            "en" to "This notebook was created by a version that could not yet unlock with a recovery phrase — its recovery phrase was never used to wrap the key, so only the password opens it",
            "zh-Hans" to "这本笔记是在恢复码还不能解锁的版本建立的 —— 它的恢复码从来没有被用来包住密钥，只有密码开得了",
            "ja" to "このノートは、復元フレーズでロック解除できない旧バージョンで作成されました。復元フレーズで鍵を包んだことがないため、パスワードでのみ開けます",
            "ko" to "이 노트는 복구 문구로 잠금을 풀 수 없던 버전에서 만들어졌습니다. 복구 문구로 키를 감싼 적이 없어 비밀번호로만 열 수 있습니다",
            "th" to "สมุดบันทึกนี้สร้างจากเวอร์ชันที่ยังปลดล็อกด้วยวลีกู้คืนไม่ได้ วลีกู้คืนไม่เคยถูกใช้ห่อหุ้มคีย์ จึงเปิดได้ด้วยรหัสผ่านเท่านั้น"
        ),
        "core_msg_196" to mapOf(
            "zh-Hant" to "不合法的裝置 id：%1@",
            "en" to "Invalid device id: %1@",
            "zh-Hans" to "不合法的装置 id：%1@",
            "ja" to "無効なデバイス id: %1@",
            "ko" to "잘못된 기기 id: %1@",
            "th" to "id อุปกรณ์ไม่ถูกต้อง: %1@"
        ),
        "core_msg_197" to mapOf(
            "zh-Hant" to "不合法的錄音檔名：%1@",
            "en" to "Invalid recording file name: %1@",
            "zh-Hans" to "不合法的录音文件名：%1@",
            "ja" to "無効な録音ファイル名: %1@",
            "ko" to "잘못된 녹음 파일 이름: %1@",
            "th" to "ชื่อไฟล์บันทึกเสียงไม่ถูกต้อง: %1@"
        ),
        "core_msg_198" to mapOf(
            "zh-Hant" to "不合法的 oplog 檔名：%1@",
            "en" to "Invalid oplog file name: %1@",
            "zh-Hans" to "不合法的 oplog 文件名：%1@",
            "ja" to "無効な oplog ファイル名: %1@",
            "ko" to "잘못된 oplog 파일 이름: %1@",
            "th" to "ชื่อไฟล์ oplog ไม่ถูกต้อง: %1@"
        ),
        "core_msg_199" to mapOf(
            "zh-Hant" to "這個套件已加密，需要先解鎖才讀得出內容",
            "en" to "This package is encrypted; unlock it first to read its contents",
            "zh-Hans" to "这个套件已加密，需要先解锁才读得出内容",
            "ja" to "このパッケージは暗号化されています。内容を読むには先にロックを解除してください",
            "ko" to "이 패키지는 암호화되어 있습니다. 내용을 읽으려면 먼저 잠금을 해제하세요",
            "th" to "แพ็กเกจนี้เข้ารหัสอยู่ ต้องปลดล็อกก่อนจึงจะอ่านเนื้อหาได้"
        ),
        "core_msg_200" to mapOf(
            "zh-Hant" to "oplog 操作筆數超過上限，已終止載入以防止記憶體溢出",
            "en" to "The number of oplog operations exceeds the limit; loading was stopped to prevent running out of memory",
            "zh-Hans" to "oplog 操作笔数超过上限，已终止加载以防止内存溢出",
            "ja" to "oplog の操作数が上限を超えました。メモリ不足を防ぐため読み込みを中止しました",
            "ko" to "oplog 작업 수가 한도를 초과하여 메모리 부족을 막기 위해 로드를 중단했습니다",
            "th" to "จำนวนการดำเนินการใน oplog เกินขีดจำกัด จึงหยุดโหลดเพื่อป้องกันหน่วยความจำไม่พอ"
        ),
        "core_msg_201" to mapOf(
            "zh-Hant" to "路徑包含非法穿越",
            "en" to "The path contains an illegal traversal",
            "zh-Hans" to "路径包含非法穿越",
            "ja" to "パスに不正な階層移動が含まれています",
            "ko" to "경로에 허용되지 않는 상위 이동이 포함되어 있습니다",
            "th" to "เส้นทางมีการย้อนขึ้นที่ไม่อนุญาต"
        ),
        "core_msg_202" to mapOf(
            "zh-Hant" to "Drive 沒有回傳 startPageToken",
            "en" to "Drive did not return a startPageToken",
            "zh-Hans" to "Drive 没有回传 startPageToken",
            "ja" to "Drive が startPageToken を返しませんでした",
            "ko" to "Drive가 startPageToken을 반환하지 않았습니다",
            "th" to "Drive ไม่ส่ง startPageToken กลับมา"
        ),
        "core_msg_203" to mapOf(
            "zh-Hant" to "建立 %1@ 之後 Drive 沒有回傳 id",
            "en" to "Drive did not return an id after creating %1@",
            "zh-Hans" to "建立 %1@ 之后 Drive 没有回传 id",
            "ja" to "%1@ の作成後に Drive が id を返しませんでした",
            "ko" to "%1@을(를) 만든 뒤 Drive가 id를 반환하지 않았습니다",
            "th" to "หลังสร้าง %1@ Drive ไม่ส่ง id กลับมา"
        ),
        "core_msg_204" to mapOf(
            "zh-Hant" to "Google Drive 不支援 append（%1@）；請改用分塊檔策略",
            "en" to "Google Drive does not support append (%1@); use the chunked-file strategy instead",
            "zh-Hans" to "Google Drive 不支持 append（%1@）；请改用分块文件策略",
            "ja" to "Google Drive は追記（%1@）をサポートしていません。分割ファイル方式に切り替えてください",
            "ko" to "Google Drive는 이어쓰기(%1@)를 지원하지 않습니다. 분할 파일 방식을 사용하세요",
            "th" to "Google Drive ไม่รองรับการต่อท้าย (%1@) โปรดใช้วิธีแบ่งไฟล์แทน"
        )
    )

    private fun part7(): Map<String, Map<String, String>> = mapOf(
        "core_msg_205" to mapOf(
            "zh-Hant" to "Drive API 速率限制（HTTP 403），稍後重試：%1@",
            "en" to "Drive API rate limit (HTTP 403); try again later: %1@",
            "zh-Hans" to "Drive API 速率限制（HTTP 403），稍后重试：%1@",
            "ja" to "Drive API のレート制限（HTTP 403）です。しばらくしてからやり直してください: %1@",
            "ko" to "Drive API 속도 제한(HTTP 403)입니다. 잠시 후 다시 시도하세요: %1@",
            "th" to "ถึงขีดจำกัดอัตราของ Drive API (HTTP 403) โปรดลองใหม่ภายหลัง: %1@"
        ),
        "core_msg_206" to mapOf(
            "zh-Hant" to "可續傳上傳沒有回傳 Location",
            "en" to "The resumable upload did not return a Location",
            "zh-Hans" to "可续传上传没有回传 Location",
            "ja" to "再開可能なアップロードが Location を返しませんでした",
            "ko" to "이어서 올리기가 Location을 반환하지 않았습니다",
            "th" to "การอัปโหลดแบบต่อได้ไม่ส่ง Location กลับมา"
        ),
        "core_msg_207" to mapOf(
            "zh-Hant" to "訊框太大",
            "en" to "The frame is too large",
            "zh-Hans" to "帧太大",
            "ja" to "フレームが大きすぎます",
            "ko" to "프레임이 너무 큽니다",
            "th" to "เฟรมใหญ่เกินไป"
        ),
        "core_msg_208" to mapOf(
            "zh-Hant" to "訊框超過上限",
            "en" to "The frame exceeds the limit",
            "zh-Hans" to "帧超过上限",
            "ja" to "フレームが上限を超えています",
            "ko" to "프레임이 한도를 초과했습니다",
            "th" to "เฟรมเกินขีดจำกัด"
        ),
        "core_msg_209" to mapOf(
            "zh-Hant" to "訊框太短",
            "en" to "The frame is too short",
            "zh-Hans" to "帧太短",
            "ja" to "フレームが短すぎます",
            "ko" to "프레임이 너무 짧습니다",
            "th" to "เฟรมสั้นเกินไป"
        ),
        "core_msg_210" to mapOf(
            "zh-Hant" to "方向不符（疑似反射）",
            "en" to "Wrong direction (possible reflection)",
            "zh-Hans" to "方向不符（疑似反射）",
            "ja" to "方向が一致しません（反射の疑い）",
            "ko" to "방향이 맞지 않습니다(반사 의심)",
            "th" to "ทิศทางไม่ตรง (สงสัยว่าเป็นการสะท้อนกลับ)"
        ),
        "core_msg_211" to mapOf(
            "zh-Hant" to "標頭超出訊框",
            "en" to "The header extends beyond the frame",
            "zh-Hans" to "标头超出帧",
            "ja" to "ヘッダーがフレームをはみ出しています",
            "ko" to "헤더가 프레임을 벗어났습니다",
            "th" to "ส่วนหัวเกินขอบเฟรม"
        ),
        "core_msg_212" to mapOf(
            "zh-Hant" to "標頭不是合法訊息",
            "en" to "The header is not a valid message",
            "zh-Hans" to "标头不是合法消息",
            "ja" to "ヘッダーが有効なメッセージではありません",
            "ko" to "헤더가 올바른 메시지가 아닙니다",
            "th" to "ส่วนหัวไม่ใช่ข้อความที่ถูกต้อง"
        ),
        "core_msg_213" to mapOf(
            "zh-Hant" to "解析不到位址",
            "en" to "Cannot resolve the address",
            "zh-Hans" to "解析不到位址",
            "ja" to "アドレスを解決できません",
            "ko" to "주소를 확인할 수 없습니다",
            "th" to "แปลงที่อยู่ไม่ได้"
        ),
        "core_msg_214" to mapOf(
            "zh-Hant" to "魔數不符",
            "en" to "Magic number mismatch",
            "zh-Hans" to "魔数不符",
            "ja" to "マジックナンバーが一致しません",
            "ko" to "매직 넘버가 일치하지 않습니다",
            "th" to "เลขมายากลไม่ตรงกัน"
        ),
        "core_msg_215" to mapOf(
            "zh-Hant" to "對端裝置 id 不符",
            "en" to "The peer device id does not match",
            "zh-Hans" to "对端装置 id 不符",
            "ja" to "相手デバイスの id が一致しません",
            "ko" to "상대 기기 id가 일치하지 않습니다",
            "th" to "id ของอุปกรณ์ปลายทางไม่ตรงกัน"
        ),
        "core_msg_216" to mapOf(
            "zh-Hant" to "金鑰不符",
            "en" to "Key mismatch",
            "zh-Hans" to "密钥不符",
            "ja" to "鍵が一致しません",
            "ko" to "키가 일치하지 않습니다",
            "th" to "คีย์ไม่ตรงกัน"
        ),
        "core_msg_217" to mapOf(
            "zh-Hant" to "第一個訊框不是 Ready",
            "en" to "The first frame is not Ready",
            "zh-Hans" to "第一个帧不是 Ready",
            "ja" to "最初のフレームが Ready ではありません",
            "ko" to "첫 프레임이 Ready가 아닙니다",
            "th" to "เฟรมแรกไม่ใช่ Ready"
        ),
        "core_msg_218" to mapOf(
            "zh-Hant" to "標籤不符",
            "en" to "Tag mismatch",
            "zh-Hans" to "标签不符",
            "ja" to "タグが一致しません",
            "ko" to "태그가 일치하지 않습니다",
            "th" to "แท็กไม่ตรงกัน"
        ),
        "core_msg_219" to mapOf(
            "zh-Hant" to "不該由這一方連過來",
            "en" to "This side should not have been the one to connect",
            "zh-Hans" to "不该由这一方连过来",
            "ja" to "この側から接続すべきではありません",
            "ko" to "이쪽에서 연결하면 안 됩니다",
            "th" to "ฝั่งนี้ไม่ควรเป็นฝ่ายเชื่อมต่อ"
        ),
        "core_msg_220" to mapOf(
            "zh-Hant" to "檔案尚未從雲端下載：%1@",
            "en" to "The file has not been downloaded from the cloud yet: %1@",
            "zh-Hans" to "文件尚未从云端下载：%1@",
            "ja" to "ファイルはまだクラウドからダウンロードされていません: %1@",
            "ko" to "파일이 아직 클라우드에서 다운로드되지 않았습니다: %1@",
            "th" to "ยังไม่ได้ดาวน์โหลดไฟล์จากคลาวด์: %1@"
        ),
        "core_msg_221" to mapOf(
            "zh-Hant" to "停止門檻必須低於開始門檻，否則遲滯失效",
            "en" to "The stop threshold must be lower than the start threshold, otherwise hysteresis does not work",
            "zh-Hans" to "停止门槛必须低於开始门槛，否则迟滞失效",
            "ja" to "停止のしきい値は開始のしきい値より低くする必要があります。そうでないとヒステリシスが機能しません",
            "ko" to "중지 임계값은 시작 임계값보다 낮아야 합니다. 그렇지 않으면 히스테리시스가 작동하지 않습니다",
            "th" to "เกณฑ์หยุดต้องต่ำกว่าเกณฑ์เริ่ม ไม่เช่นนั้นฮิสเทอรีซิสจะไม่ทำงาน"
        ),
        "core_msg_222" to mapOf(
            "zh-Hant" to "找不到 VAD 模型：%1@",
            "en" to "VAD model not found: %1@",
            "zh-Hans" to "找不到 VAD 模型：%1@",
            "ja" to "VAD モデルが見つかりません: %1@",
            "ko" to "VAD 모델을 찾을 수 없습니다: %1@",
            "th" to "ไม่พบโมเดล VAD: %1@"
        ),
        "corner_style" to mapOf(
            "zh-Hant" to "圓角",
            "en" to "Corners",
            "zh-Hans" to "圆角",
            "ja" to "角丸",
            "ko" to "모서리",
            "th" to "มุมโค้ง"
        ),
        "cp_blue" to mapOf(
            "zh-Hant" to "B（藍）",
            "en" to "B (blue)",
            "zh-Hans" to "B（蓝）",
            "ja" to "B（青）",
            "ko" to "B(파랑)",
            "th" to "B (น้ำเงิน)"
        ),
        "cp_brightness2" to mapOf(
            "zh-Hant" to "明度",
            "en" to "Brightness",
            "zh-Hans" to "明度",
            "ja" to "明度",
            "ko" to "명도",
            "th" to "ความสว่าง"
        ),
        "cp_green" to mapOf(
            "zh-Hant" to "G（綠）",
            "en" to "G (green)",
            "zh-Hans" to "G（绿）",
            "ja" to "G（緑）",
            "ko" to "G(초록)",
            "th" to "G (เขียว)"
        ),
        "cp_hue" to mapOf(
            "zh-Hant" to "色相",
            "en" to "Hue",
            "zh-Hans" to "色相",
            "ja" to "色相",
            "ko" to "색상",
            "th" to "เฉดสี"
        ),
        "cp_red" to mapOf(
            "zh-Hant" to "R（紅）",
            "en" to "R (red)",
            "zh-Hans" to "R（红）",
            "ja" to "R（赤）",
            "ko" to "R(빨강)",
            "th" to "R (แดง)"
        ),
        "cp_saturation2" to mapOf(
            "zh-Hant" to "飽和度",
            "en" to "Saturation",
            "zh-Hans" to "饱和度",
            "ja" to "彩度",
            "ko" to "채도",
            "th" to "ความอิ่มตัว"
        ),
        "create_snapshot" to mapOf(
            "zh-Hant" to "建立協同快照",
            "en" to "Create Snapshot",
            "zh-Hans" to "创建协同快照",
            "ja" to "スナップショットを作成",
            "ko" to "스냅샷 생성",
            "th" to "สร้างสแนปช็อต"
        ),
        "created_on" to mapOf(
            "zh-Hant" to "建立於 %@",
            "en" to "Created %@",
            "zh-Hans" to "创建于 %@",
            "ja" to "作成：%@",
            "ko" to "만든 날짜: %@",
            "th" to "สร้างเมื่อ %@"
        ),
        "current_notebook" to mapOf(
            "zh-Hant" to "目前這本",
            "en" to "Current",
            "zh-Hans" to "目前这本",
            "ja" to "このノート",
            "ko" to "현재 노트",
            "th" to "สมุดปัจจุบัน"
        ),
        "current_user" to mapOf(
            "zh-Hant" to "目前使用者",
            "en" to "Current User",
            "zh-Hans" to "当前用户",
            "ja" to "現在のユーザー",
            "ko" to "현재 사용자",
            "th" to "ผู้ใช้ปัจจุบัน"
        ),
        "custom_color" to mapOf(
            "zh-Hant" to "自訂顏色",
            "en" to "Custom color",
            "zh-Hans" to "自定义颜色",
            "ja" to "カスタムカラー",
            "ko" to "사용자 색상",
            "th" to "สีกำหนดเอง"
        ),
        "customize_toolbar" to mapOf(
            "zh-Hant" to "自訂工具列",
            "en" to "Customize Toolbar",
            "zh-Hans" to "自定义工具栏",
            "ja" to "ツールバーをカスタマイズ",
            "ko" to "도구 모음 사용자화",
            "th" to "ปรับแต่งแถบเครื่องมือ"
        ),
        "cut_selected" to mapOf(
            "zh-Hant" to "剪下選取",
            "en" to "Cut Selection",
            "zh-Hans" to "剪切选中",
            "ja" to "選択範囲を切り取り",
            "ko" to "선택 항목 잘라내기",
            "th" to "ตัดส่วนที่เลือก"
        ),
        "cut_selected_hint" to mapOf(
            "zh-Hant" to "把選取的筆劃剪下放進剪貼簿（原處移除）",
            "en" to "Cut the selected strokes to the clipboard (removed from the page)",
            "zh-Hans" to "把选取的笔画剪切到剪贴板（原处移除）",
            "ja" to "選択した筆跡を切り取ってクリップボードへ（元の場所からは消えます）",
            "ko" to "선택한 필기를 잘라 클립보드에 넣습니다(원래 위치에서 삭제)",
            "th" to "ตัดเส้นที่เลือกไปยังคลิปบอร์ด (ลบออกจากหน้า)"
        ),
        "cw_analogous" to mapOf(
            "zh-Hant" to "類似色",
            "en" to "Analogous",
            "zh-Hans" to "类似色",
            "ja" to "類似色",
            "ko" to "유사색",
            "th" to "สีใกล้เคียง"
        ),
        "cw_analogous_1" to mapOf(
            "zh-Hant" to "類似色 1",
            "en" to "Analogous 1",
            "zh-Hans" to "类似色 1",
            "ja" to "類似色 1",
            "ko" to "유사색 1",
            "th" to "สีใกล้เคียง 1"
        ),
        "cw_analogous_2" to mapOf(
            "zh-Hant" to "類似色 2",
            "en" to "Analogous 2",
            "zh-Hans" to "类似色 2",
            "ja" to "類似色 2",
            "ko" to "유사색 2",
            "th" to "สีใกล้เคียง 2"
        ),
        "cw_brightness" to mapOf(
            "zh-Hant" to "明度",
            "en" to "Brightness",
            "zh-Hans" to "明度",
            "ja" to "明度",
            "ko" to "명도",
            "th" to "ความสว่าง"
        ),
        "cw_complement" to mapOf(
            "zh-Hant" to "互補色",
            "en" to "Complementary",
            "zh-Hans" to "互补色",
            "ja" to "補色",
            "ko" to "보색",
            "th" to "สีตรงข้าม"
        ),
        "cw_harmonies" to mapOf(
            "zh-Hant" to "配色建議",
            "en" to "Colour harmonies",
            "zh-Hans" to "配色建议",
            "ja" to "配色の候補",
            "ko" to "색 조화 추천",
            "th" to "ชุดสีที่เข้ากัน"
        ),
        "cw_primary" to mapOf(
            "zh-Hant" to "主色",
            "en" to "Base",
            "zh-Hans" to "主色",
            "ja" to "ベース",
            "ko" to "기본색",
            "th" to "สีหลัก"
        ),
        "cw_saturation" to mapOf(
            "zh-Hant" to "彩度",
            "en" to "Saturation",
            "zh-Hans" to "彩度",
            "ja" to "彩度",
            "ko" to "채도",
            "th" to "ความอิ่มตัว"
        ),
        "cw_triadic" to mapOf(
            "zh-Hant" to "三等分",
            "en" to "Triadic",
            "zh-Hans" to "三等分",
            "ja" to "三色配色",
            "ko" to "3색 배색",
            "th" to "สามสีเท่ากัน"
        ),
        "dash_dashed" to mapOf(
            "zh-Hant" to "虛線",
            "en" to "Dashed",
            "zh-Hans" to "虚线",
            "ja" to "破線",
            "ko" to "파선",
            "th" to "เส้นประ"
        ),
        "dash_dotted" to mapOf(
            "zh-Hant" to "點線",
            "en" to "Dotted",
            "zh-Hans" to "点线",
            "ja" to "点線",
            "ko" to "점선",
            "th" to "เส้นจุด"
        ),
        "dash_solid" to mapOf(
            "zh-Hant" to "實線",
            "en" to "Solid",
            "zh-Hans" to "实线",
            "ja" to "実線",
            "ko" to "실선",
            "th" to "เส้นทึบ"
        ),
        "data_and_sync" to mapOf(
            "zh-Hant" to "資料與同步",
            "en" to "Data & Sync",
            "zh-Hans" to "数据与同步",
            "ja" to "データと同期",
            "ko" to "데이터 및 동기화",
            "th" to "ข้อมูลและการซิงก์"
        ),
        "data_list" to mapOf(
            "zh-Hant" to "數據列表",
            "en" to "Data Entries",
            "zh-Hans" to "数据列表",
            "ja" to "データ一覧",
            "ko" to "데이터 목록",
            "th" to "รายการข้อมูล"
        ),
        "default_root_folder" to mapOf(
            "zh-Hant" to "我的筆記",
            "en" to "My Notes",
            "zh-Hans" to "我的笔记",
            "ja" to "マイノート",
            "ko" to "내 노트",
            "th" to "บันทึกของฉัน"
        ),
        "default_user_name" to mapOf(
            "zh-Hant" to "使用者",
            "en" to "You",
            "zh-Hans" to "用户",
            "ja" to "ユーザー",
            "ko" to "사용자",
            "th" to "ผู้ใช้"
        ),
        "delete" to mapOf(
            "zh-Hant" to "刪除",
            "en" to "Delete",
            "zh-Hans" to "删除",
            "ja" to "削除",
            "ko" to "삭제",
            "th" to "ลบ"
        ),
        "delete_comment" to mapOf(
            "zh-Hant" to "刪除圖釘",
            "en" to "Delete Pin",
            "zh-Hans" to "删除图钉",
            "ja" to "ピンを削除",
            "ko" to "핀 삭제",
            "th" to "ลบหมุด"
        ),
        "delete_folder" to mapOf(
            "zh-Hant" to "刪除資料夾",
            "en" to "Delete Folder",
            "zh-Hans" to "删除文件夹",
            "ja" to "フォルダを削除",
            "ko" to "폴더 삭제",
            "th" to "ลบโฟลเดอร์"
        ),
        "delete_folder_explainer" to mapOf(
            "zh-Hant" to "裡面的筆記本不會被刪除，會在所有裝置上回到最上層。",
            "en" to "The notebooks inside are not deleted. They move back to the top level on every device.",
            "zh-Hans" to "里面的笔记本不会被删除，会在所有装置上回到最上层。",
            "ja" to "中のノートは削除されません。すべての端末で最上位フォルダに戻ります。",
            "ko" to "안에 있는 노트는 삭제되지 않습니다. 모든 기기에서 최상위로 이동합니다.",
            "th" to "สมุดบันทึกข้างในจะไม่ถูกลบ แต่จะย้ายกลับไปที่ระดับบนสุดในทุกอุปกรณ์"
        ),
        "delete_item" to mapOf(
            "zh-Hant" to "刪除項目",
            "en" to "Delete Item",
            "zh-Hans" to "删除项目",
            "ja" to "項目を削除",
            "ko" to "항목 삭제",
            "th" to "ลบรายการ"
        ),
        "delete_message" to mapOf(
            "zh-Hant" to "刪除這則留言",
            "en" to "Delete this message",
            "zh-Hans" to "删除这条留言",
            "ja" to "このメッセージを削除",
            "ko" to "이 메시지 삭제",
            "th" to "ลบข้อความนี้"
        ),
        "delete_notebook_confirm" to mapOf(
            "zh-Hant" to "要將「%@」移到回收桶嗎？在永久刪除之前，你可以從回收桶還原。",
            "en" to "Move “%@” to the Trash? You can restore it from the Trash until it is permanently removed.",
            "zh-Hans" to "要将“%@”移到回收站吗？在永久删除之前，你可以从回收站还原。",
            "ja" to "「%@」をゴミ箱に移動しますか？完全に削除されるまでは、ゴミ箱から元に戻せます。",
            "ko" to "“%@”을(를) 휴지통으로 이동할까요? 영구 삭제되기 전까지는 휴지통에서 복원할 수 있습니다.",
            "th" to "ย้าย “%@” ไปยังถังขยะหรือไม่? คุณสามารถกู้คืนจากถังขยะได้จนกว่าจะถูกลบถาวร"
        ),
        "delete_page" to mapOf(
            "zh-Hant" to "刪除此頁",
            "en" to "Delete Page",
            "zh-Hans" to "删除此页",
            "ja" to "ページを削除",
            "ko" to "페이지 삭제",
            "th" to "ลบหน้านี้"
        ),
        "delete_page_confirm" to mapOf(
            "zh-Hant" to "確定要刪除第 %@ 頁嗎？這一頁的手寫與物件都會消失。",
            "en" to "Delete page %@? Its handwriting and objects will be gone.",
            "zh-Hans" to "确定要删除第 %@ 页吗？这一页的手写与物件都会消失。",
            "ja" to "%@ ページ目を削除しますか？そのページの手書きとオブジェクトは消えます。",
            "ko" to "%@ 페이지를 삭제할까요? 해당 페이지의 필기와 객체가 사라집니다.",
            "th" to "ลบหน้า %@ ไหม? ลายมือและวัตถุในหน้านี้จะหายไป"
        ),
        "delete_page_confirm_msg" to mapOf(
            "zh-Hant" to "確定要刪除第 %d 頁嗎？此動作無法復原。",
            "en" to "Are you sure you want to delete Page %d? This cannot be undone.",
            "zh-Hans" to "确定要删除第 %d 页吗？此操作无法撤销。",
            "ja" to "%d ページを削除してもよろしいですか？元に戻せません。",
            "ko" to "%d페이지를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.",
            "th" to "คุณแน่ใจหรือไม่ว่าต้องการลบหน้า %d? การดำเนินการนี้ไม่สามารถยกเลิกได้"
        ),
        "delete_recording" to mapOf(
            "zh-Hant" to "刪除錄音檔",
            "en" to "Delete Recording",
            "zh-Hans" to "删除录音",
            "ja" to "録音を削除",
            "ko" to "녹음 삭제",
            "th" to "ลบเสียงบันทึก"
        ),
        "delete_selected" to mapOf(
            "zh-Hant" to "刪除選取筆劃",
            "en" to "Delete Selection",
            "zh-Hans" to "删除选中笔画",
            "ja" to "選択ストロークを削除",
            "ko" to "선택된 획 삭제",
            "th" to "ลบลายเส้นที่เลือก"
        ),
        "deselect_all" to mapOf(
            "zh-Hant" to "取消全選",
            "en" to "Deselect All",
            "zh-Hans" to "取消全选",
            "ja" to "選択を解除",
            "ko" to "선택 해제",
            "th" to "ยกเลิกเลือกทั้งหมด"
        ),
        "designer_palette" to mapOf(
            "zh-Hant" to "設計師色系",
            "en" to "Designer Palette",
            "zh-Hans" to "设计师色系",
            "ja" to "デザイナーパレット",
            "ko" to "디자이너 팔레트",
            "th" to "จานสีนักออกแบบ"
        ),
        "diag_azimuth" to mapOf(
            "zh-Hant" to "方位",
            "en" to "Azimuth",
            "zh-Hans" to "方位",
            "ja" to "方位角",
            "ko" to "방위각",
            "th" to "ทิศทาง"
        ),
        "diag_coalesced" to mapOf(
            "zh-Hant" to "聯合取樣點",
            "en" to "Coalesced samples",
            "zh-Hans" to "合并取样点",
            "ja" to "結合サンプル",
            "ko" to "병합 샘플",
            "th" to "ตัวอย่างที่รวมกัน"
        ),
        "diag_collab_crypto" to mapOf(
            "zh-Hant" to "協同加密",
            "en" to "Collaboration encryption",
            "zh-Hans" to "协同加密",
            "ja" to "共同編集の暗号化",
            "ko" to "공동 편집 암호화",
            "th" to "การเข้ารหัสการแก้ไขร่วมกัน"
        ),
        "diag_collab_relay" to mapOf(
            "zh-Hant" to "協同中繼",
            "en" to "Collaboration relay",
            "zh-Hans" to "协同中继",
            "ja" to "共同編集の中継",
            "ko" to "공동 편집 릴레이",
            "th" to "รีเลย์การแก้ไขร่วมกัน"
        ),
        "diag_core_load_failed" to mapOf(
            "zh-Hant" to "核心載入失敗",
            "en" to "Core failed to load",
            "zh-Hans" to "核心载入失败",
            "ja" to "コアの読み込みに失敗",
            "ko" to "코어 로드 실패",
            "th" to "โหลดแกนหลักไม่สำเร็จ"
        ),
        "diag_core_version" to mapOf(
            "zh-Hant" to "核心版本",
            "en" to "Core version",
            "zh-Hans" to "核心版本",
            "ja" to "コアのバージョン",
            "ko" to "코어 버전",
            "th" to "เวอร์ชันแกนหลัก"
        ),
        "diag_crypto_empty" to mapOf(
            "zh-Hant" to "加密回傳空字串",
            "en" to "Encryption returned an empty string",
            "zh-Hans" to "加密回传空字串",
            "ja" to "暗号化の結果が空の文字列でした",
            "ko" to "암호화 결과가 빈 문자열입니다",
            "th" to "การเข้ารหัสส่งสตริงว่างกลับมา"
        ),
        "diag_crypto_mismatch" to mapOf(
            "zh-Hant" to "內容不符",
            "en" to "Content mismatch",
            "zh-Hans" to "内容不符",
            "ja" to "内容が一致しません",
            "ko" to "내용이 일치하지 않습니다",
            "th" to "เนื้อหาไม่ตรงกัน"
        ),
        "diag_crypto_ok" to mapOf(
            "zh-Hant" to "AES-256-GCM round-trip 通過",
            "en" to "AES-256-GCM round trip passed",
            "zh-Hans" to "AES-256-GCM round-trip 通过",
            "ja" to "AES-256-GCM の往復テストに合格",
            "ko" to "AES-256-GCM 왕복 테스트 통과",
            "th" to "การทดสอบ AES-256-GCM ไป-กลับผ่าน"
        ),
        "diag_failed" to mapOf(
            "zh-Hant" to "失敗：%1@",
            "en" to "Failed: %1@",
            "zh-Hans" to "失败：%1@",
            "ja" to "失敗: %1@",
            "ko" to "실패: %1@",
            "th" to "ล้มเหลว: %1@"
        ),
        "diag_first_stroke" to mapOf(
            "zh-Hant" to "　首筆",
            "en" to "  First stroke",
            "zh-Hans" to "　首笔",
            "ja" to "　最初のストローク",
            "ko" to "  첫 획",
            "th" to "  เส้นแรก"
        ),
        "diag_first_stroke_value" to mapOf(
            "zh-Hant" to "RGBA(%1@)、起點(%2@, %3@)、%4@ 點",
            "en" to "RGBA(%1@), start (%2@, %3@), %4@ points",
            "zh-Hans" to "RGBA(%1@)、起点(%2@, %3@)、%4@ 点",
            "ja" to "RGBA(%1@)、始点(%2@, %3@)、%4@ 点",
            "ko" to "RGBA(%1@), 시작점(%2@, %3@), %4@개 점",
            "th" to "RGBA(%1@) จุดเริ่ม (%2@, %3@) %4@ จุด"
        ),
        "diag_handoff_note" to mapOf(
            "zh-Hant" to "跨平台筆記",
            "en" to "Cross-platform note",
            "zh-Hans" to "跨平台笔记",
            "ja" to "クロスプラットフォームのノート",
            "ko" to "크로스 플랫폼 노트",
            "th" to "สมุดบันทึกข้ามแพลตฟอร์ม"
        ),
        "diag_input_device" to mapOf(
            "zh-Hant" to "輸入裝置",
            "en" to "Input device",
            "zh-Hans" to "输入装置",
            "ja" to "入力デバイス",
            "ko" to "입력 장치",
            "th" to "อุปกรณ์อินพุต"
        ),
        "diag_not_supported" to mapOf(
            "zh-Hant" to "不支援",
            "en" to "Not supported",
            "zh-Hans" to "不支援",
            "ja" to "非対応",
            "ko" to "지원 안 함",
            "th" to "ไม่รองรับ"
        ),
        "diag_open_failed" to mapOf(
            "zh-Hant" to "開啟失敗：%1@",
            "en" to "Failed to open: %1@",
            "zh-Hans" to "开启失败：%1@",
            "ja" to "開けませんでした: %1@",
            "ko" to "열기 실패: %1@",
            "th" to "เปิดไม่สำเร็จ: %1@"
        ),
        "diag_page_n" to mapOf(
            "zh-Hant" to "第 %1@ 頁",
            "en" to "Page %1@",
            "zh-Hans" to "第 %1@ 页",
            "ja" to "%1@ ページ目",
            "ko" to "%1@페이지",
            "th" to "หน้า %1@"
        )
    )

    private fun part8(): Map<String, Map<String, String>> = mapOf(
        "diag_page_value" to mapOf(
            "zh-Hant" to "筆畫 %1@、高 %2@pt",
            "en" to "%1@ strokes, %2@ pt tall",
            "zh-Hans" to "笔画 %1@、高 %2@pt",
            "ja" to "ストローク %1@、高さ %2@pt",
            "ko" to "획 %1@개, 높이 %2@pt",
            "th" to "%1@ เส้น สูง %2@pt"
        ),
        "diag_pages" to mapOf(
            "zh-Hant" to "頁數",
            "en" to "Pages",
            "zh-Hans" to "页数",
            "ja" to "ページ数",
            "ko" to "페이지 수",
            "th" to "จำนวนหน้า"
        ),
        "diag_predicted" to mapOf(
            "zh-Hant" to "預測取樣點",
            "en" to "Predicted samples",
            "zh-Hans" to "预测取样点",
            "ja" to "予測サンプル",
            "ko" to "예측 샘플",
            "th" to "ตัวอย่างที่คาดการณ์"
        ),
        "diag_pressure" to mapOf(
            "zh-Hant" to "壓力",
            "en" to "Pressure",
            "zh-Hans" to "压力",
            "ja" to "筆圧",
            "ko" to "압력",
            "th" to "แรงกด"
        ),
        "diag_relay_start_failed" to mapOf(
            "zh-Hant" to "啟動失敗",
            "en" to "Failed to start",
            "zh-Hans" to "启动失败",
            "ja" to "起動に失敗",
            "ko" to "시작 실패",
            "th" to "เริ่มไม่สำเร็จ"
        ),
        "diag_relay_started" to mapOf(
            "zh-Hant" to "已啟動於埠 %1@（已停止）",
            "en" to "Started on port %1@ (now stopped)",
            "zh-Hans" to "已启动於埠 %1@（已停止）",
            "ja" to "ポート %1@ で起動しました（現在は停止済み）",
            "ko" to "포트 %1@에서 시작됨(현재 중지됨)",
            "th" to "เริ่มที่พอร์ต %1@ แล้ว (ตอนนี้หยุดแล้ว)"
        ),
        "diag_roll" to mapOf(
            "zh-Hant" to "滾動",
            "en" to "Roll",
            "zh-Hans" to "滚动",
            "ja" to "ロール",
            "ko" to "롤",
            "th" to "การกลิ้ง"
        ),
        "diag_sample_string" to mapOf(
            "zh-Hant" to "示例字串",
            "en" to "Sample string",
            "zh-Hans" to "示例字符串",
            "ja" to "サンプル文字列",
            "ko" to "예시 문자열",
            "th" to "สตริงตัวอย่าง"
        ),
        "diag_samples" to mapOf(
            "zh-Hant" to "p50 %1@ms · p95 %2@ms · %3@ 樣本",
            "en" to "p50 %1@ms · p95 %2@ms · %3@ samples",
            "zh-Hans" to "p50 %1@ms · p95 %2@ms · %3@ 样本",
            "ja" to "p50 %1@ms · p95 %2@ms · %3@ サンプル",
            "ko" to "p50 %1@ms · p95 %2@ms · 샘플 %3@개",
            "th" to "p50 %1@ms · p95 %2@ms · %3@ ตัวอย่าง"
        ),
        "diag_string_table" to mapOf(
            "zh-Hant" to "字串表",
            "en" to "String table",
            "zh-Hans" to "字符串表",
            "ja" to "文字列テーブル",
            "ko" to "문자열 표",
            "th" to "ตารางสตริง"
        ),
        "diag_string_table_value" to mapOf(
            "zh-Hant" to "%1@ 條（與 Apple 版同源）",
            "en" to "%1@ entries (shared with the Apple app)",
            "zh-Hans" to "%1@ 条（与 Apple 版同源）",
            "ja" to "%1@ 件（Apple 版と共通）",
            "ko" to "%1@개(Apple 앱과 동일 출처)",
            "th" to "%1@ รายการ (ใช้ร่วมกับแอป Apple)"
        ),
        "diag_target_platform" to mapOf(
            "zh-Hant" to "目標平台",
            "en" to "Target platform",
            "zh-Hans" to "目标平台",
            "ja" to "ターゲットプラットフォーム",
            "ko" to "대상 플랫폼",
            "th" to "แพลตฟอร์มเป้าหมาย"
        ),
        "diag_tilt" to mapOf(
            "zh-Hant" to "傾角",
            "en" to "Tilt",
            "zh-Hans" to "倾角",
            "ja" to "傾き",
            "ko" to "기울기",
            "th" to "มุมเอียง"
        ),
        "diag_tip_latency" to mapOf(
            "zh-Hant" to "筆尖延遲",
            "en" to "Pen-tip latency",
            "zh-Hans" to "笔尖延迟",
            "ja" to "ペン先の遅延",
            "ko" to "펜촉 지연",
            "th" to "ความหน่วงปลายปากกา"
        ),
        "diag_touches" to mapOf(
            "zh-Hant" to "同時觸控",
            "en" to "Simultaneous touches",
            "zh-Hans" to "同时触控",
            "ja" to "同時タッチ数",
            "ko" to "동시 터치",
            "th" to "การแตะพร้อมกัน"
        ),
        "diag_ui_language" to mapOf(
            "zh-Hant" to "介面語系",
            "en" to "Interface language",
            "zh-Hans" to "界面语言",
            "ja" to "表示言語",
            "ko" to "인터페이스 언어",
            "th" to "ภาษาของอินเทอร์เฟซ"
        ),
        "diag_ui_version" to mapOf(
            "zh-Hant" to "介面版本",
            "en" to "App version",
            "zh-Hans" to "界面版本",
            "ja" to "アプリのバージョン",
            "ko" to "앱 버전",
            "th" to "เวอร์ชันแอป"
        ),
        "diagnostics" to mapOf(
            "zh-Hant" to "診斷",
            "en" to "Diagnostics",
            "zh-Hans" to "诊断",
            "ja" to "診断",
            "ko" to "진단",
            "th" to "การวินิจฉัย"
        ),
        "dimension_callout" to mapOf(
            "zh-Hant" to "工程引線標註",
            "en" to "Dimension Callout",
            "zh-Hans" to "工程引线标注",
            "ja" to "寸法引出線",
            "ko" to "치수 인출선",
            "th" to "บอลลูนระบุขนาด"
        ),
        "dimension_callout_balloon1" to mapOf(
            "zh-Hant" to "零件球標 ①",
            "en" to "Part balloon ①",
            "zh-Hans" to "零件球标 ①",
            "ja" to "部品バルーン ①",
            "ko" to "부품 번호 ①",
            "th" to "หมายเลขชิ้นส่วน ①"
        ),
        "dimension_callout_balloon2" to mapOf(
            "zh-Hant" to "零件球標 ②",
            "en" to "Part balloon ②",
            "zh-Hans" to "零件球标 ②",
            "ja" to "部品バルーン ②",
            "ko" to "부품 번호 ②",
            "th" to "หมายเลขชิ้นส่วน ②"
        ),
        "dimension_callout_diameter" to mapOf(
            "zh-Hant" to "外徑圓標註",
            "en" to "Diameter callout",
            "zh-Hans" to "外径圆标注",
            "ja" to "直径記号",
            "ko" to "지름 표기",
            "th" to "บอกเส้นผ่านศูนย์กลาง"
        ),
        "dimension_callout_flatness" to mapOf(
            "zh-Hant" to "平面度公差",
            "en" to "Flatness tolerance",
            "zh-Hans" to "平面度公差",
            "ja" to "平面度公差",
            "ko" to "평면도 공차",
            "th" to "ค่าความราบ"
        ),
        "dimension_callout_linear" to mapOf(
            "zh-Hant" to "線性長度標註",
            "en" to "Linear dimension",
            "zh-Hans" to "线性长度标注",
            "ja" to "直線寸法",
            "ko" to "선형 치수",
            "th" to "บอกขนาดเชิงเส้น"
        ),
        "dimension_callout_radius" to mapOf(
            "zh-Hant" to "圓弧半徑標註",
            "en" to "Radius callout",
            "zh-Hans" to "圆弧半径标注",
            "ja" to "半径記号",
            "ko" to "반지름 표기",
            "th" to "บอกรัศมี"
        ),
        "disconnect" to mapOf(
            "zh-Hant" to "中斷連線",
            "en" to "Disconnect",
            "zh-Hans" to "断开连接",
            "ja" to "切断",
            "ko" to "연결 끊기",
            "th" to "ตัดการเชื่อมต่อ"
        ),
        "display_name" to mapOf(
            "zh-Hant" to "顯示名稱",
            "en" to "Display Name",
            "zh-Hans" to "显示名称",
            "ja" to "表示名",
            "ko" to "표시 이름",
            "th" to "ชื่อที่แสดง"
        ),
        "doc_template" to mapOf(
            "zh-Hant" to "套用的範本",
            "en" to "Template in use",
            "zh-Hans" to "套用的范本",
            "ja" to "使用するテンプレート",
            "ko" to "적용할 서식",
            "th" to "แม่แบบที่ใช้"
        ),
        "doc_template_clear" to mapOf(
            "zh-Hant" to "取消",
            "en" to "Clear",
            "zh-Hans" to "取消",
            "ja" to "解除",
            "ko" to "해제",
            "th" to "ล้าง"
        ),
        "doc_template_hint" to mapOf(
            "zh-Hant" to "套用後內容就是你的，改得動也刪得掉。",
            "en" to "Once applied, the content is yours — edit or delete any of it.",
            "zh-Hans" to "套用后内容就是你的，改得动也删得掉。",
            "ja" to "適用後の内容はあなたのものです。自由に編集・削除できます。",
            "ko" to "적용한 내용은 자유롭게 수정하거나 삭제할 수 있습니다.",
            "th" to "เมื่อใช้แล้ว เนื้อหาเป็นของคุณ แก้ไขหรือลบได้ทั้งหมด"
        ),
        "doc_template_none" to mapOf(
            "zh-Hant" to "不套用，只要空白頁",
            "en" to "None — just a blank page",
            "zh-Hans" to "不套用，只要空白页",
            "ja" to "使用しない（白紙のみ）",
            "ko" to "사용 안 함 (빈 페이지)",
            "th" to "ไม่ใช้ — หน้าว่างเท่านั้น"
        ),
        "doc_template_section" to mapOf(
            "zh-Hant" to "文件範本",
            "en" to "Document Template",
            "zh-Hans" to "文件范本",
            "ja" to "文書テンプレート",
            "ko" to "문서 서식",
            "th" to "แม่แบบเอกสาร"
        ),
        "doc_variant_blank" to mapOf(
            "zh-Hant" to "空白範本",
            "en" to "Blank form",
            "zh-Hans" to "空白范本",
            "ja" to "白紙様式",
            "ko" to "빈 양식",
            "th" to "แบบฟอร์มเปล่า"
        ),
        "doc_variant_example" to mapOf(
            "zh-Hant" to "完整案例",
            "en" to "Worked example",
            "zh-Hans" to "完整案例",
            "ja" to "記入例",
            "ko" to "작성 예시",
            "th" to "ตัวอย่างที่กรอกแล้ว"
        ),
        "doctor_auto_sync" to mapOf(
            "zh-Hant" to "自動同步",
            "en" to "Auto sync",
            "zh-Hans" to "自动同步",
            "ja" to "自動同期",
            "ko" to "자동 동기화",
            "th" to "ซิงก์อัตโนมัติ"
        ),
        "doctor_cloud_snapshot" to mapOf(
            "zh-Hant" to "雲端快照",
            "en" to "Cloud snapshot",
            "zh-Hans" to "云端快照",
            "ja" to "クラウドスナップショット",
            "ko" to "클라우드 스냅샷",
            "th" to "สแนปช็อตบนคลาวด์"
        ),
        "doctor_idle" to mapOf(
            "zh-Hant" to "待命",
            "en" to "Idle",
            "zh-Hans" to "待命",
            "ja" to "待機中",
            "ko" to "대기 중",
            "th" to "พร้อมทำงาน"
        ),
        "doctor_last_result" to mapOf(
            "zh-Hant" to "最後結果",
            "en" to "Last result",
            "zh-Hans" to "最后结果",
            "ja" to "直近の結果",
            "ko" to "마지막 결과",
            "th" to "ผลล่าสุด"
        ),
        "doctor_paused_sign_in" to mapOf(
            "zh-Hant" to "已暫停，請重新登入",
            "en" to "Paused — please sign in again",
            "zh-Hans" to "已暂停，请重新登录",
            "ja" to "一時停止中です。再度サインインしてください",
            "ko" to "일시 중지됨 — 다시 로그인하세요",
            "th" to "หยุดชั่วคราว โปรดลงชื่อเข้าใช้อีกครั้ง"
        ),
        "doctor_pending_count" to mapOf(
            "zh-Hant" to "%1@ / %2@ 本",
            "en" to "%1@ of %2@",
            "zh-Hans" to "%1@ / %2@ 本",
            "ja" to "%1@ / %2@ 冊",
            "ko" to "%1@ / %2@권",
            "th" to "%1@ / %2@ เล่ม"
        ),
        "doctor_pending_none" to mapOf(
            "zh-Hant" to "無（已檢查 %@ 本）",
            "en" to "None (%@ checked)",
            "zh-Hans" to "无（已检查 %@ 本）",
            "ja" to "なし（%@ 冊を確認）",
            "ko" to "없음 (%@권 확인함)",
            "th" to "ไม่มี (ตรวจแล้ว %@ เล่ม)"
        ),
        "doctor_pending_notes" to mapOf(
            "zh-Hant" to "待同步筆記",
            "en" to "Notes waiting to sync",
            "zh-Hans" to "待同步笔记",
            "ja" to "同期待ちのノート",
            "ko" to "동기화 대기 중인 노트",
            "th" to "โน้ตที่รอซิงก์"
        ),
        "doctor_reset" to mapOf(
            "zh-Hant" to "重置",
            "en" to "Reset",
            "zh-Hans" to "重置",
            "ja" to "リセット",
            "ko" to "초기화",
            "th" to "รีเซ็ต"
        ),
        "doctor_running" to mapOf(
            "zh-Hant" to "進行中",
            "en" to "Running",
            "zh-Hans" to "进行中",
            "ja" to "実行中",
            "ko" to "진행 중",
            "th" to "กำลังทำงาน"
        ),
        "doctor_snapshot_built" to mapOf(
            "zh-Hant" to "已建立（追蹤 %@ 個檔案）",
            "en" to "Built (tracking %@ files)",
            "zh-Hans" to "已建立（追踪 %@ 个文件）",
            "ja" to "作成済み（%@ 件のファイルを追跡）",
            "ko" to "생성됨 (파일 %@개 추적 중)",
            "th" to "สร้างแล้ว (ติดตาม %@ ไฟล์)"
        ),
        "doctor_snapshot_missing" to mapOf(
            "zh-Hant" to "尚未建立，下次同步會重新盤點一次",
            "en" to "Not built yet; the next sync will take inventory again",
            "zh-Hans" to "尚未建立，下次同步会重新盘点一次",
            "ja" to "未作成です。次回の同期で再度確認します",
            "ko" to "아직 생성되지 않았습니다. 다음 동기화 때 다시 점검합니다",
            "th" to "ยังไม่ได้สร้าง การซิงก์ครั้งถัดไปจะตรวจสอบใหม่"
        ),
        "document_missing" to mapOf(
            "zh-Hant" to "找不到打包的文件檔案，請回報這個問題。",
            "en" to "The bundled document is missing. Please report this.",
            "zh-Hans" to "找不到打包的文档文件，请反馈这个问题。",
            "ja" to "同梱ドキュメントが見つかりません。ご報告ください。",
            "ko" to "동봉된 문서를 찾을 수 없습니다. 알려 주세요.",
            "th" to "ไม่พบเอกสารที่มากับแอป โปรดแจ้งปัญหานี้"
        ),
        "done" to mapOf(
            "zh-Hant" to "完成",
            "en" to "Done",
            "zh-Hans" to "完成",
            "ja" to "完了",
            "ko" to "완료",
            "th" to "เสร็จสิ้น"
        ),
        "download_all" to mapOf(
            "zh-Hant" to "下載全部",
            "en" to "Download All",
            "zh-Hans" to "全部下载",
            "ja" to "すべてDL",
            "ko" to "전체 다운로드",
            "th" to "ดาวน์โหลดทั้งหมด"
        ),
        "download_all_category" to mapOf(
            "zh-Hant" to "下載本類全部",
            "en" to "Download All in Category",
            "zh-Hans" to "下载本类全部",
            "ja" to "このカテゴリをすべてダウンロード",
            "ko" to "이 카테고리 모두 다운로드",
            "th" to "ดาวน์โหลดทั้งหมดในหมวดหมู่นี้"
        ),
        "download_interrupted" to mapOf(
            "zh-Hant" to "下載中斷：%@",
            "en" to "Download interrupted: %@",
            "zh-Hans" to "下载中断：%@",
            "ja" to "ダウンロードが中断されました：%@",
            "ko" to "다운로드가 중단되었습니다: %@",
            "th" to "การดาวน์โหลดหยุดชะงัก: %@"
        ),
        "download_item" to mapOf(
            "zh-Hant" to "下載",
            "en" to "Download",
            "zh-Hans" to "下载",
            "ja" to "ダウンロード",
            "ko" to "다운로드",
            "th" to "ดาวน์โหลด"
        ),
        "download_model" to mapOf(
            "zh-Hant" to "下載模型",
            "en" to "Download Model",
            "zh-Hans" to "下载模型",
            "ja" to "モデルをダウンロード",
            "ko" to "모델 다운로드",
            "th" to "ดาวน์โหลดโมเดล"
        ),
        "download_tailscale" to mapOf(
            "zh-Hant" to "下載 Tailscale",
            "en" to "Download Tailscale",
            "zh-Hans" to "下载 Tailscale",
            "ja" to "Tailscale をダウンロード",
            "ko" to "Tailscale 다운로드",
            "th" to "ดาวน์โหลด Tailscale"
        ),
        "download_tailscale_link" to mapOf(
            "zh-Hant" to "前往下載 Tailscale (tailscale.com/download)",
            "en" to "Download Tailscale (tailscale.com/download)",
            "zh-Hans" to "前往下载 Tailscale (tailscale.com/download)",
            "ja" to "Tailscale をダウンロード (tailscale.com/download)",
            "ko" to "Tailscale 다운로드 (tailscale.com/download)",
            "th" to "ดาวน์โหลด Tailscale (tailscale.com/download)"
        ),
        "downloaded" to mapOf(
            "zh-Hant" to "已下載",
            "en" to "Downloaded",
            "zh-Hans" to "已下载",
            "ja" to "DL済",
            "ko" to "다운로드됨",
            "th" to "ดาวน์โหลดแล้ว"
        ),
        "downloading" to mapOf(
            "zh-Hant" to "下載中...",
            "en" to "Downloading...",
            "zh-Hans" to "下载中...",
            "ja" to "ダウンロード中...",
            "ko" to "다운로드 중...",
            "th" to "กำลังดาวน์โหลด..."
        ),
        "draft_angle_free" to mapOf(
            "zh-Hant" to "自由",
            "en" to "Free",
            "zh-Hans" to "自由",
            "ja" to "自由",
            "ko" to "자유",
            "th" to "อิสระ"
        ),
        "draft_angle_lock" to mapOf(
            "zh-Hant" to "角度鎖定",
            "en" to "Angle lock",
            "zh-Hans" to "角度锁定",
            "ja" to "角度ロック",
            "ko" to "각도 잠금",
            "th" to "ล็อกมุม"
        ),
        "draft_bar_collapse" to mapOf(
            "zh-Hant" to "收合面板",
            "en" to "Collapse panel",
            "zh-Hans" to "收合面板",
            "ja" to "パネルを閉じる",
            "ko" to "패널 접기",
            "th" to "ย่อแผง"
        ),
        "draft_bar_expand" to mapOf(
            "zh-Hant" to "展開圖學面板",
            "en" to "Show drafting panel",
            "zh-Hans" to "展开图学面板",
            "ja" to "製図パネルを開く",
            "ko" to "도면 패널 펼치기",
            "th" to "แสดงแผงเขียนแบบ"
        ),
        "draft_draw_on_layer" to mapOf(
            "zh-Hant" to "畫在此圖層",
            "en" to "Draw on this layer",
            "zh-Hans" to "画在此图层",
            "ja" to "このレイヤーに描く",
            "ko" to "이 레이어에 그리기",
            "th" to "วาดบนเลเยอร์นี้"
        ),
        "draft_help" to mapOf(
            "zh-Hant" to "使用提示",
            "en" to "Tips",
            "zh-Hans" to "使用提示",
            "ja" to "ヒント",
            "ko" to "도움말",
            "th" to "เคล็ดลับ"
        ),
        "draft_hide_layer" to mapOf(
            "zh-Hant" to "隱藏圖層",
            "en" to "Hide layer",
            "zh-Hans" to "隐藏图层",
            "ja" to "レイヤーを隠す",
            "ko" to "레이어 숨기기",
            "th" to "ซ่อนเลเยอร์"
        ),
        "draft_layer_aux" to mapOf(
            "zh-Hant" to "中層・輔助",
            "en" to "Aux (construction)",
            "zh-Hans" to "中层·辅助",
            "ja" to "中層・補助",
            "ko" to "중층·보조",
            "th" to "ชั้นกลาง·เส้นช่วย"
        ),
        "draft_layer_base" to mapOf(
            "zh-Hant" to "底層・原題",
            "en" to "Base (given)",
            "zh-Hans" to "底层·原题",
            "ja" to "下層・与件",
            "ko" to "하층·원문제",
            "th" to "ชั้นล่าง·โจทย์"
        ),
        "draft_layer_plain" to mapOf(
            "zh-Hant" to "一般筆跡",
            "en" to "Plain ink",
            "zh-Hans" to "普通笔迹",
            "ja" to "通常の筆跡",
            "ko" to "일반 필기",
            "th" to "ลายมือทั่วไป"
        ),
        "draft_layer_top" to mapOf(
            "zh-Hant" to "頂層・答案",
            "en" to "Top (answer)",
            "zh-Hans" to "顶层·答案",
            "ja" to "上層・解答",
            "ko" to "상층·정답",
            "th" to "ชั้นบน·คำตอบ"
        ),
        "draft_layers" to mapOf(
            "zh-Hant" to "圖層",
            "en" to "Layers",
            "zh-Hans" to "图层",
            "ja" to "レイヤー",
            "ko" to "레이어",
            "th" to "เลเยอร์"
        ),
        "draft_line_center" to mapOf(
            "zh-Hant" to "中心線",
            "en" to "Center",
            "zh-Hans" to "中心线",
            "ja" to "中心線",
            "ko" to "중심선",
            "th" to "เส้นศูนย์กลาง"
        ),
        "draft_line_hidden" to mapOf(
            "zh-Hant" to "隱藏線",
            "en" to "Hidden",
            "zh-Hans" to "隐藏线",
            "ja" to "かくれ線",
            "ko" to "숨은선",
            "th" to "เส้นประซ่อน"
        ),
        "draft_line_phantom" to mapOf(
            "zh-Hant" to "假想線",
            "en" to "Phantom",
            "zh-Hans" to "假想线",
            "ja" to "想像線",
            "ko" to "가상선",
            "th" to "เส้นสมมติ"
        ),
        "draft_line_solid" to mapOf(
            "zh-Hant" to "實線",
            "en" to "Solid",
            "zh-Hans" to "实线",
            "ja" to "実線",
            "ko" to "실선",
            "th" to "เส้นทึบ"
        ),
        "draft_lock_layer" to mapOf(
            "zh-Hant" to "鎖定圖層",
            "en" to "Lock layer",
            "zh-Hans" to "锁定图层",
            "ja" to "レイヤーをロック",
            "ko" to "레이어 잠금",
            "th" to "ล็อกเลเยอร์"
        ),
        "draft_pen_aux" to mapOf(
            "zh-Hant" to "輔助線",
            "en" to "Auxiliary",
            "zh-Hans" to "辅助线",
            "ja" to "補助線",
            "ko" to "보조선",
            "th" to "เส้นช่วย"
        ),
        "draft_pen_center" to mapOf(
            "zh-Hant" to "中心線",
            "en" to "Center line",
            "zh-Hans" to "中心线",
            "ja" to "中心線",
            "ko" to "중심선",
            "th" to "เส้นศูนย์กลาง"
        ),
        "draft_pen_given" to mapOf(
            "zh-Hant" to "原題線",
            "en" to "Given outline",
            "zh-Hans" to "原题线",
            "ja" to "与件線",
            "ko" to "원문제선",
            "th" to "เส้นโจทย์"
        ),
        "draft_pen_hidden" to mapOf(
            "zh-Hant" to "隱藏線",
            "en" to "Hidden line",
            "zh-Hans" to "隐藏线",
            "ja" to "かくれ線",
            "ko" to "숨은선",
            "th" to "เส้นซ่อน"
        ),
        "draft_pen_phantom" to mapOf(
            "zh-Hant" to "假想線",
            "en" to "Phantom line",
            "zh-Hans" to "假想线",
            "ja" to "想像線",
            "ko" to "가상선",
            "th" to "เส้นสมมติ"
        ),
        "draft_pen_thick" to mapOf(
            "zh-Hant" to "粗實線",
            "en" to "Thick solid",
            "zh-Hans" to "粗实线",
            "ja" to "太実線",
            "ko" to "굵은 실선",
            "th" to "เส้นหนา"
        )
    )

    private fun part9(): Map<String, Map<String, String>> = mapOf(
        "draft_pen_thin" to mapOf(
            "zh-Hant" to "細實線",
            "en" to "Thin solid",
            "zh-Hans" to "细实线",
            "ja" to "細実線",
            "ko" to "가는 실선",
            "th" to "เส้นบาง"
        ),
        "draft_pens" to mapOf(
            "zh-Hant" to "製圖筆",
            "en" to "Drafting pens",
            "zh-Hans" to "制图笔",
            "ja" to "製図ペン",
            "ko" to "제도 펜",
            "th" to "ปากกาเขียนแบบ"
        ),
        "draft_reassign" to mapOf(
            "zh-Hant" to "移到圖層",
            "en" to "Move to layer",
            "zh-Hans" to "移到图层",
            "ja" to "レイヤーへ移動",
            "ko" to "레이어로 이동",
            "th" to "ย้ายไปเลเยอร์"
        ),
        "draft_show_layer" to mapOf(
            "zh-Hant" to "顯示圖層",
            "en" to "Show layer",
            "zh-Hans" to "显示图层",
            "ja" to "レイヤーを表示",
            "ko" to "레이어 표시",
            "th" to "แสดงเลเยอร์"
        ),
        "draft_snap" to mapOf(
            "zh-Hant" to "形狀吸附",
            "en" to "Shape snap",
            "zh-Hans" to "形状吸附",
            "ja" to "図形スナップ",
            "ko" to "도형 스냅",
            "th" to "จัดรูปทรงอัตโนมัติ"
        ),
        "draft_step_hint" to mapOf(
            "zh-Hant" to "點頁面放上編號",
            "en" to "Tap the page to place the number",
            "zh-Hans" to "点页面放上编号",
            "ja" to "ページをタップして番号を配置",
            "ko" to "페이지를 눌러 번호 배치",
            "th" to "แตะหน้าเพื่อวางเลข"
        ),
        "draft_step_marker" to mapOf(
            "zh-Hant" to "步驟編號",
            "en" to "Step numbers",
            "zh-Hans" to "步骤编号",
            "ja" to "手順番号",
            "ko" to "단계 번호",
            "th" to "เลขขั้นตอน"
        ),
        "draft_step_next" to mapOf(
            "zh-Hant" to "下一個編號",
            "en" to "Next number",
            "zh-Hans" to "下一个编号",
            "ja" to "次の番号",
            "ko" to "다음 번호",
            "th" to "เลขถัดไป"
        ),
        "draft_step_prev" to mapOf(
            "zh-Hant" to "上一個編號",
            "en" to "Previous number",
            "zh-Hans" to "上一个编号",
            "ja" to "前の番号",
            "ko" to "이전 번호",
            "th" to "เลขก่อนหน้า"
        ),
        "draft_step_reset" to mapOf(
            "zh-Hant" to "從 ① 重來",
            "en" to "Start from ①",
            "zh-Hans" to "从 ① 重来",
            "ja" to "① からやり直す",
            "ko" to "①부터 다시",
            "th" to "เริ่มจาก ①"
        ),
        "draft_tip_1" to mapOf(
            "zh-Hant" to "選一支筆：線型與圖層跟著它走（隱藏線＝虛線、輔助線＝淺藍）。",
            "en" to "Pick a pen: its line type and layer come with it (hidden line = dashed, aux = light blue).",
            "zh-Hans" to "选一支笔：线型与图层跟着它走（隐藏线＝虚线、辅助线＝浅蓝）。",
            "ja" to "ペンを選ぶと線種とレイヤーも決まります（かくれ線＝破線、補助線＝水色）。",
            "ko" to "펜을 고르면 선 종류와 레이어가 함께 정해집니다(숨은선=점선, 보조선=연한 파랑).",
            "th" to "เลือกปากกา: ชนิดเส้นและเลเยอร์มาพร้อมกัน (เส้นซ่อน=เส้นประ, เส้นช่วย=ฟ้าอ่อน)"
        ),
        "draft_tip_2" to mapOf(
            "zh-Hant" to "畫一條線，在終點停住半秒：會自動變直線、圓或矩形。",
            "en" to "Draw a line and hold still for half a second at the end: it snaps straight, to a circle or a rectangle.",
            "zh-Hans" to "画一条线，在终点停住半秒：会自动变直线、圆或矩形。",
            "ja" to "線を描き、終点で0.5秒止めると直線・円・長方形にそろいます。",
            "ko" to "선을 긋고 끝에서 0.5초 멈추면 직선·원·사각형으로 정리됩니다.",
            "th" to "วาดเส้นแล้วหยุดค้างครึ่งวินาทีที่ปลาย: จะกลายเป็นเส้นตรง วงกลม หรือสี่เหลี่ยม"
        ),
        "draft_tip_3" to mapOf(
            "zh-Hant" to "點眼睛可隱藏圖層（例如輔助線）、點鎖頭保護圖層。",
            "en" to "Tap the eye to hide a layer (for example the construction lines) and the lock to protect it.",
            "zh-Hans" to "点眼睛可隐藏图层（例如辅助线）、点锁头保护图层。",
            "ja" to "目のアイコンでレイヤー（補助線など）を隠し、鍵で保護します。",
            "ko" to "눈 아이콘으로 레이어(보조선 등)를 숨기고 자물쇠로 보호합니다.",
            "th" to "แตะรูปตาเพื่อซ่อนเลเยอร์ (เช่นเส้นช่วย) แตะกุญแจเพื่อป้องกัน"
        ),
        "draft_tip_4" to mapOf(
            "zh-Hant" to "立體輔助：畫一個封閉輪廓，就能拉伸成三視圖、等角圖與剖面。",
            "en" to "Solid helper: draw a closed outline, then extrude it into three views, an isometric view and sections.",
            "zh-Hans" to "立体辅助：画一个封闭轮廓，就能拉伸成三视图、等角图与剖面。",
            "ja" to "立体ヘルパー：閉じた輪郭を描くと、三面図・等角図・断面図に押し出せます。",
            "ko" to "입체 도우미: 닫힌 윤곽을 그리면 3면도·등각도·단면도로 돌출시킵니다.",
            "th" to "ตัวช่วยสามมิติ: วาดโครงร่างปิด แล้วดึงเป็นสามมุมมอง ภาพไอโซเมตริก และภาพตัด"
        ),
        "draft_tip_dismiss" to mapOf(
            "zh-Hant" to "知道了",
            "en" to "Got it",
            "zh-Hans" to "知道了",
            "ja" to "わかりました",
            "ko" to "확인",
            "th" to "เข้าใจแล้ว"
        ),
        "draft_tip_title" to mapOf(
            "zh-Hant" to "圖學使用提示",
            "en" to "Drafting tips",
            "zh-Hans" to "图学使用提示",
            "ja" to "製図のヒント",
            "ko" to "도면 도움말",
            "th" to "เคล็ดลับงานเขียนแบบ"
        ),
        "draft_unlock_layer" to mapOf(
            "zh-Hant" to "解除鎖定",
            "en" to "Unlock layer",
            "zh-Hans" to "解除锁定",
            "ja" to "ロック解除",
            "ko" to "잠금 해제",
            "th" to "ปลดล็อก"
        ),
        "drafting_example_notebook" to mapOf(
            "zh-Hant" to "圖學範例",
            "en" to "Drafting Example",
            "zh-Hans" to "图学范例",
            "ja" to "製図の例",
            "ko" to "도면 예제",
            "th" to "ตัวอย่างงานเขียนแบบ"
        ),
        "drafting_example_p1_hint" to mapOf(
            "zh-Hant" to "用圖層面板可以顯示／隱藏每一層：底層是原題、中層是輔助線、頂層是答案。接下來的步驟都畫在中層。",
            "en" to "Use the layer panel to show or hide each layer: base (given), middle (construction lines), top (answer). The steps below are drawn on the middle layer.",
            "zh-Hans" to "用图层面板可以显示／隐藏每一层：底层是原题、中层是辅助线、顶层是答案。接下来的步骤都画在中层。",
            "ja" to "レイヤーパネルで各レイヤーの表示／非表示を切り替えられます。下層＝与件、中層＝補助線、上層＝解答。以降の手順は中層に描きます。",
            "ko" to "레이어 패널에서 각 레이어를 표시/숨길 수 있습니다. 하층=원문제, 중층=보조선, 상층=정답. 이후 단계는 중층에 그립니다.",
            "th" to "ใช้แผงเลเยอร์เพื่อแสดง/ซ่อนแต่ละชั้น: ชั้นล่าง=โจทย์ ชั้นกลาง=เส้นช่วย ชั้นบน=คำตอบ ขั้นตอนต่อไปวาดบนชั้นกลาง"
        ),
        "drafting_example_p1_sub" to mapOf(
            "zh-Hant" to "已知：正視圖與俯視圖（底層・原題）。求：右側視圖。",
            "en" to "Given: front view and top view (base layer). Find: the right side view.",
            "zh-Hans" to "已知：正视图与俯视图（底层·原题）。求：右侧视图。",
            "ja" to "与件：正面図と平面図（下層）。求めるもの：右側面図。",
            "ko" to "주어진 것: 정면도와 평면도(하층). 구할 것: 우측면도.",
            "th" to "กำหนด: ภาพด้านหน้าและด้านบน (ชั้นล่าง) หา: ภาพด้านขวา"
        ),
        "drafting_example_p2_sub" to mapOf(
            "zh-Hant" to "步驟 ①②：45° 轉向線與水平投射線",
            "en" to "Steps ①②: the 45° line and the horizontal projection lines",
            "zh-Hans" to "步骤 ①②：45° 转向线与水平投射线",
            "ja" to "手順 ①②：45°線と水平投影線",
            "ko" to "단계 ①②: 45° 선과 수평 투사선",
            "th" to "ขั้นตอน ①②: เส้น 45° และเส้นโครงแนวนอน"
        ),
        "drafting_example_p3_sub" to mapOf(
            "zh-Hant" to "步驟 ③④：向下的垂直線與向右的水平線",
            "en" to "Steps ③④: vertical lines down, horizontal lines across",
            "zh-Hans" to "步骤 ③④：向下的垂直线与向右的水平线",
            "ja" to "手順 ③④：下への垂直線と右への水平線",
            "ko" to "단계 ③④: 아래로 수직선, 오른쪽으로 수평선",
            "th" to "ขั้นตอน ③④: เส้นดิ่งลงและเส้นนอนไปทางขวา"
        ),
        "drafting_example_p4_sub" to mapOf(
            "zh-Hant" to "步驟 ⑤：頂層的答案",
            "en" to "Step ⑤: the answer on the top layer",
            "zh-Hans" to "步骤 ⑤：顶层的答案",
            "ja" to "手順 ⑤：上層の解答",
            "ko" to "단계 ⑤: 상층의 정답",
            "th" to "ขั้นตอน ⑤: คำตอบบนชั้นบน"
        ),
        "drafting_example_p5_body" to mapOf(
            "zh-Hant" to "開啟圖層面板（圖學筆組），點中層旁邊的眼睛。輔助線與步驟編號就收起來，只剩原題與你的答案；想複習步驟時再點一次。",
            "en" to "Open the layer panel (the Drafting tool) and tap the eye next to the middle layer. The construction lines and step numbers disappear; only the given views and your answer remain. Tap it again whenever you want to review the steps.",
            "zh-Hans" to "打开图层面板（图学笔组），点中层旁边的眼睛。辅助线与步骤编号就收起来，只剩原题与你的答案；想复习步骤时再点一次。",
            "ja" to "レイヤーパネル（製図ツール）を開き、中層の目のアイコンをタップ。補助線と手順番号が隠れ、与件と解答だけが残ります。復習したいときはもう一度タップ。",
            "ko" to "레이어 패널(도면 도구)을 열고 중층의 눈 아이콘을 누르세요. 보조선과 단계 번호가 사라지고 원문제와 정답만 남습니다. 복습할 때 다시 누르세요.",
            "th" to "เปิดแผงเลเยอร์ (ชุดปากกาเขียนแบบ) แล้วแตะรูปตาของชั้นกลาง เส้นช่วยและเลขขั้นตอนจะหายไป เหลือเพียงโจทย์และคำตอบ แตะอีกครั้งเมื่อต้องการทบทวน"
        ),
        "drafting_example_p5_sub" to mapOf(
            "zh-Hant" to "完成 — 把輔助線收起來",
            "en" to "Done — now hide the construction lines",
            "zh-Hans" to "完成 — 把辅助线收起来",
            "ja" to "完成 — 補助線を隠す",
            "ko" to "완료 — 보조선 숨기기",
            "th" to "เสร็จแล้ว — ซ่อนเส้นช่วย"
        ),
        "drafting_example_right" to mapOf(
            "zh-Hant" to "✓ 對：畫成虛線，因為它在右臂後面",
            "en" to "✓ Right: dashed, because it is behind the arm",
            "zh-Hans" to "✓ 对：画成虚线，因为它在右臂后面",
            "ja" to "✓ 正：腕の後ろなので破線",
            "ko" to "✓ 정답: 팔 뒤에 있으므로 점선",
            "th" to "✓ ถูก: เส้นประ เพราะอยู่หลังแขน"
        ),
        "drafting_example_s12" to mapOf(
            "zh-Hant" to "① 在俯視圖右上角畫 45° 轉向線。\n② 從俯視圖的前緣與後緣向右畫水平投射線，碰到 45° 線為止。",
            "en" to "① Draw the 45° line at the top-right corner of the top view.\n② From the front and back edges of the top view, draw horizontal lines to the right until they meet the 45° line.",
            "zh-Hans" to "① 在俯视图右上角画 45° 转向线。\n② 从俯视图的前缘与后缘向右画水平投射线，碰到 45° 线为止。",
            "ja" to "① 平面図の右上に45°線を引く。\n② 平面図の前縁・後縁から右へ水平線を引き、45°線に当てる。",
            "ko" to "① 평면도 오른쪽 위에 45° 선을 긋습니다.\n② 평면도의 앞·뒤 가장자리에서 오른쪽으로 수평선을 45° 선까지 긋습니다.",
            "th" to "① ลากเส้น 45° ที่มุมขวาบนของภาพด้านบน\n② จากขอบหน้า/หลังของภาพด้านบน ลากเส้นแนวนอนไปทางขวาจนชนเส้น 45°"
        ),
        "drafting_example_s34" to mapOf(
            "zh-Hant" to "③ 從水平線碰到 45° 線的地方向下畫垂直線，決定右側視圖的深度。\n④ 從正視圖的每個高度向右畫水平線，決定右側視圖的高度。",
            "en" to "③ From where the horizontal lines meet the 45° line, draw vertical lines downward. They fix the depth of the right view.\n④ From each height on the front view, draw horizontal lines to the right. They fix the height of the right view.",
            "zh-Hans" to "③ 从水平线碰到 45° 线的地方向下画垂直线，决定右侧视图的深度。\n④ 从正视图的每个高度向右画水平线，决定右侧视图的高度。",
            "ja" to "③ 水平線が45°線に当たる点から下へ垂直線を引く。右側面図の奥行きが決まる。\n④ 正面図の各高さから右へ水平線を引く。右側面図の高さが決まる。",
            "ko" to "③ 수평선이 45° 선에 닿는 곳에서 아래로 수직선을 긋습니다. 우측면도의 깊이가 정해집니다.\n④ 정면도의 각 높이에서 오른쪽으로 수평선을 긋습니다. 우측면도의 높이가 정해집니다.",
            "th" to "③ จากจุดที่เส้นนอนชนเส้น 45° ลากเส้นดิ่งลง กำหนดความลึกของภาพด้านขวา\n④ จากทุกระดับความสูงของภาพด้านหน้า ลากเส้นนอนไปทางขวา กำหนดความสูงของภาพด้านขวา"
        ),
        "drafting_example_s5" to mapOf(
            "zh-Hant" to "⑤ 垂直線與水平線的交點就是右側視圖的頂點。依序連線：看得見的邊畫粗實線，被擋住的邊畫虛線。",
            "en" to "⑤ The intersections of the vertical and horizontal lines are the vertices of the right view. Connect them: thick solid lines for edges you can see, dashed lines for edges hidden behind other material.",
            "zh-Hans" to "⑤ 垂直线与水平线的交点就是右侧视图的顶点。依序连线：看得见的边画粗实线，被挡住的边画虚线。",
            "ja" to "⑤ 垂直線と水平線の交点が右側面図の頂点。順に結ぶ：見える辺は太い実線、隠れた辺は破線。",
            "ko" to "⑤ 수직선과 수평선의 교점이 우측면도의 꼭짓점입니다. 이어서 그립니다: 보이는 모서리는 굵은 실선, 가려진 모서리는 점선.",
            "th" to "⑤ จุดตัดของเส้นดิ่งและเส้นนอนคือจุดยอดของภาพด้านขวา ลากเชื่อม: ขอบที่เห็นใช้เส้นหนาทึบ ขอบที่ถูกบังใช้เส้นประ"
        ),
        "drafting_example_title" to mapOf(
            "zh-Hant" to "三視圖輔助線求交點",
            "en" to "Three views: finding points with construction lines",
            "zh-Hans" to "三视图辅助线求交点",
            "ja" to "三面図：補助線で交点を求める",
            "ko" to "3면도: 보조선으로 교점 찾기",
            "th" to "สามมุมมอง: หาจุดตัดด้วยเส้นช่วย"
        ),
        "drafting_example_trap_rule" to mapOf(
            "zh-Hant" to "口訣：從這個方向看過去，邊的前面還有零件的別的面擋著，它就是隱藏線 — 畫虛線。",
            "en" to "Rule of thumb: if another surface of the part is in front of an edge when you look from that side, the edge is hidden — draw it dashed.",
            "zh-Hans" to "口诀：从这个方向看过去，边的前面还有零件的别的面挡着，它就是隐藏线 — 画虚线。",
            "ja" to "コツ：その方向から見て、辺の手前に部品の別の面があれば隠れ線 — 破線で描く。",
            "ko" to "요령: 그 방향에서 볼 때 모서리 앞을 부품의 다른 면이 가리면 숨은선입니다 — 점선으로 그립니다.",
            "th" to "เคล็ดลับ: มองจากทิศนั้นแล้วมีผิวอื่นของชิ้นงานบังอยู่หน้าขอบ ขอบนั้นคือเส้นประ — วาดเป็นเส้นประ"
        ),
        "drafting_example_trap_sub" to mapOf(
            "zh-Hant" to "常見陷阱：忘了畫隱藏線",
            "en" to "Common trap: forgetting hidden lines",
            "zh-Hans" to "常见陷阱：忘了画隐藏线",
            "ja" to "よくある落とし穴：隠れ線を忘れる",
            "ko" to "흔한 함정: 숨은선을 빼먹기",
            "th" to "กับดักที่พบบ่อย: ลืมเส้นประ"
        ),
        "drafting_example_wrong" to mapOf(
            "zh-Hant" to "✗ 錯：被擋住的邊畫成實線",
            "en" to "✗ Wrong: the hidden edge drawn as a solid line",
            "zh-Hans" to "✗ 错：被挡住的边画成实线",
            "ja" to "✗ 誤：隠れた辺を実線で描いた",
            "ko" to "✗ 오답: 가려진 모서리를 실선으로 그림",
            "th" to "✗ ผิด: วาดขอบที่ถูกบังเป็นเส้นทึบ"
        ),
        "drag_card_hint" to mapOf(
            "zh-Hant" to "拖曳移動卡片",
            "en" to "Drag to move card",
            "zh-Hans" to "拖拽移动卡片",
            "ja" to "ドラッグして移動",
            "ko" to "드래그하여 이동",
            "th" to "ลากเพื่อย้ายการ์ด"
        ),
        "drive_auth_expired" to mapOf(
            "zh-Hant" to "Google 帳號憑證已失效或過期，請重新登入 (HTTP 401)",
            "en" to "Your Google sign-in has expired. Please sign in again (HTTP 401).",
            "zh-Hans" to "Google 帐号凭证已失效或过期，请重新登录 (HTTP 401)",
            "ja" to "Google のサインインの有効期限が切れました。再度サインインしてください（HTTP 401）",
            "ko" to "Google 로그인이 만료되었습니다. 다시 로그인하세요 (HTTP 401).",
            "th" to "การลงชื่อเข้าใช้ Google หมดอายุ โปรดลงชื่อเข้าใช้อีกครั้ง (HTTP 401)"
        ),
        "drive_cred_refresh_failed" to mapOf(
            "zh-Hant" to "暫時無法更新 Google 憑證（網路不通？），稍後重試",
            "en" to "Could not refresh your Google sign-in right now (offline?). Try again later.",
            "zh-Hans" to "暂时无法更新 Google 凭证（网络不通？），稍后重试",
            "ja" to "Google のサインインを更新できませんでした（オフライン？）。後でもう一度お試しください。",
            "ko" to "지금은 Google 로그인을 갱신할 수 없습니다 (오프라인?). 나중에 다시 시도하세요.",
            "th" to "ไม่สามารถต่ออายุการลงชื่อเข้าใช้ Google ได้ในขณะนี้ (ออฟไลน์?) โปรดลองใหม่ภายหลัง"
        ),
        "drive_permission_denied" to mapOf(
            "zh-Hant" to "Google 帳號權限不足 (HTTP 403)",
            "en" to "Your Google account does not have permission (HTTP 403).",
            "zh-Hans" to "Google 帐号权限不足 (HTTP 403)",
            "ja" to "Google アカウントに権限がありません（HTTP 403）",
            "ko" to "Google 계정에 권한이 없습니다 (HTTP 403).",
            "th" to "บัญชี Google ไม่มีสิทธิ์เพียงพอ (HTTP 403)"
        ),
        "drive_rate_limited" to mapOf(
            "zh-Hant" to "Drive 速率限制（HTTP 403），稍後重試",
            "en" to "Drive rate limit reached (HTTP 403). Try again later.",
            "zh-Hans" to "Drive 速率限制（HTTP 403），稍后重试",
            "ja" to "Drive のレート制限に達しました（HTTP 403）。後でもう一度お試しください。",
            "ko" to "Drive 속도 제한에 도달했습니다 (HTTP 403). 나중에 다시 시도하세요.",
            "th" to "ถึงขีดจำกัดอัตราของ Drive (HTTP 403) โปรดลองใหม่ภายหลัง"
        ),
        "drive_resume_no_location" to mapOf(
            "zh-Hant" to "可續傳上傳沒有回傳 Location",
            "en" to "The resumable upload returned no Location header",
            "zh-Hans" to "可续传上传没有返回 Location",
            "ja" to "再開可能なアップロードが Location を返しませんでした",
            "ko" to "이어 올리기 업로드가 Location을 반환하지 않았습니다",
            "th" to "การอัปโหลดแบบต่อได้ไม่ส่ง Location กลับมา"
        ),
        "drive_timeout_download" to mapOf(
            "zh-Hant" to "下載逾時（超過 300 秒）",
            "en" to "Download timed out (over 300 s)",
            "zh-Hans" to "下载超时（超过 300 秒）",
            "ja" to "ダウンロードがタイムアウトしました（300 秒超過）",
            "ko" to "다운로드 시간 초과(300초 초과)",
            "th" to "การดาวน์โหลดหมดเวลา (เกิน 300 วินาที)"
        ),
        "drive_timeout_generic" to mapOf(
            "zh-Hant" to "同步逾時（超過 %@ 秒）",
            "en" to "Sync timed out (over %@ s)",
            "zh-Hans" to "同步超时（超过 %@ 秒）",
            "ja" to "同期がタイムアウトしました（%@ 秒超過）",
            "ko" to "동기화 시간 초과(%@초 초과)",
            "th" to "การซิงก์หมดเวลา (เกิน %@ วินาที)"
        ),
        "drive_timeout_snapshot" to mapOf(
            "zh-Hant" to "更新雲端快照逾時（超過 %@ 秒）",
            "en" to "Timed out updating the cloud snapshot (over %@ s)",
            "zh-Hans" to "更新云端快照超时（超过 %@ 秒）",
            "ja" to "クラウドのスナップショット更新がタイムアウトしました（%@ 秒超過）",
            "ko" to "클라우드 스냅샷 업데이트 시간 초과(%@초 초과)",
            "th" to "อัปเดตสแนปช็อตคลาวด์หมดเวลา (เกิน %@ วินาที)"
        ),
        "drive_timeout_sync" to mapOf(
            "zh-Hant" to "同步逾時（超過 120 秒），請檢查網路後重試",
            "en" to "Sync timed out (over 120 s). Check your connection and try again.",
            "zh-Hans" to "同步超时（超过 120 秒），请检查网络后重试",
            "ja" to "同期がタイムアウトしました（120 秒超過）。接続を確認して再試行してください。",
            "ko" to "동기화 시간 초과(120초 초과). 연결을 확인한 뒤 다시 시도하세요.",
            "th" to "การซิงก์หมดเวลา (เกิน 120 วินาที) โปรดตรวจสอบการเชื่อมต่อแล้วลองใหม่"
        ),
        "drive_user_cancelled" to mapOf(
            "zh-Hant" to "使用者中斷同步",
            "en" to "Sync was stopped by the user",
            "zh-Hans" to "用户中断同步",
            "ja" to "ユーザーが同期を中断しました",
            "ko" to "사용자가 동기화를 중단했습니다",
            "th" to "ผู้ใช้หยุดการซิงก์"
        ),
        "drop_here_to_unfile" to mapOf(
            "zh-Hant" to "把筆記拖到這裡即可移出資料夾",
            "en" to "Drag a note here to take it out of its folder",
            "zh-Hans" to "把笔记拖到这里即可移出资料夹",
            "ja" to "ノートをここにドラッグするとフォルダから出せます",
            "ko" to "노트를 여기로 끌어 놓으면 폴더에서 꺼냅니다",
            "th" to "ลากโน้ตมาที่นี่เพื่อนำออกจากโฟลเดอร์"
        ),
        "duplicate_note" to mapOf(
            "zh-Hant" to "建立副本",
            "en" to "Duplicate Note",
            "zh-Hans" to "创建副本",
            "ja" to "複製を作成",
            "ko" to "사본 생성",
            "th" to "ทำซ้ำบันทึก"
        ),
        "duplicate_page" to mapOf(
            "zh-Hant" to "建立此頁副本",
            "en" to "Duplicate Page",
            "zh-Hans" to "建立此页副本",
            "ja" to "ページを複製",
            "ko" to "페이지 복제",
            "th" to "ทำซ้ำหน้านี้"
        ),
        "duplicate_selected" to mapOf(
            "zh-Hant" to "再製",
            "en" to "Duplicate",
            "zh-Hans" to "再制",
            "ja" to "複製を作成",
            "ko" to "복제",
            "th" to "ทำซ้ำ"
        ),
        "duplicate_selected_hint" to mapOf(
            "zh-Hant" to "直接在旁邊多做一份，不經過剪貼簿",
            "en" to "Make a second copy right next to it, without using the clipboard",
            "zh-Hans" to "直接在旁边多做一份，不经过剪贴板",
            "ja" to "クリップボードを使わず、すぐ隣にもう一つ作ります",
            "ko" to "클립보드를 거치지 않고 바로 옆에 하나 더 만듭니다",
            "th" to "สร้างสำเนาอีกชุดไว้ข้าง ๆ ทันที โดยไม่ผ่านคลิปบอร์ด"
        ),
        "e2ee_protected" to mapOf(
            "zh-Hant" to "端對端加密保護",
            "en" to "End-to-End Encrypted",
            "zh-Hans" to "端对端加密保护",
            "ja" to "エンドツーエンド暗号化",
            "ko" to "종단간 암호화",
            "th" to "การเข้ารหัสจากต้นทางถึงปลายทาง"
        ),
        "e2ee_protected_desc" to mapOf(
            "zh-Hant" to "筆劃、附件與討論皆在本地完成硬體加密，中繼伺服器無法窺探。",
            "en" to "Strokes, attachments, and comments are encrypted locally. Relay server cannot inspect contents.",
            "zh-Hans" to "笔划、附件与讨论均在本地完成硬件加密，中继服务器无法窥探。",
            "ja" to "ストローク、添付ファイル、コメントはローカルで暗号化され、リレーサーバーは内容を閲覧できません。",
            "ko" to "획, 첨부 파일 및 댓글은 로컬에서 암호화되며 릴레이 서버는 내용을 볼 수 없습니다.",
            "th" to "เส้นวาด ไฟล์แนบ และความคิดเห็นได้รับการเข้ารหัสบนเครื่อง เซิร์ฟเวอร์รีเลย์ไม่สามารถตรวจสอบเนื้อหาได้"
        ),
        "ed_cancel_selection" to mapOf(
            "zh-Hant" to "取消框選",
            "en" to "Cancel selection",
            "zh-Hans" to "取消框选",
            "ja" to "選択を解除",
            "ko" to "선택 해제",
            "th" to "ยกเลิกการเลือก"
        ),
        "ed_done_back_to_doc" to mapOf(
            "zh-Hant" to "完成，回到文件",
            "en" to "Done, back to the document",
            "zh-Hans" to "完成，回到文档",
            "ja" to "完了して書類に戻る",
            "ko" to "완료하고 문서로 돌아가기",
            "th" to "เสร็จแล้ว กลับไปที่เอกสาร"
        ),
        "ed_done_back_to_ink" to mapOf(
            "zh-Hant" to "完成，回到手繪",
            "en" to "Done, back to handwriting",
            "zh-Hans" to "完成，回到手绘",
            "ja" to "完了して手書きに戻る",
            "ko" to "완료하고 필기로 돌아가기",
            "th" to "เสร็จแล้ว กลับไปที่ลายมือ"
        ),
        "ed_ink_toolbar_hint" to mapOf(
            "zh-Hant" to "手繪工具 · 正在文件內的畫布上作畫",
            "en" to "Handwriting tools · drawing on the canvas inside the document",
            "zh-Hans" to "手绘工具 · 正在文档内的画布上作画",
            "ja" to "手書きツール · 書類内のキャンバスに描画中",
            "ko" to "필기 도구 · 문서 안 캔버스에 그리는 중",
            "th" to "เครื่องมือลายมือ · กำลังวาดบนผืนผ้าใบในเอกสาร"
        ),
        "ed_symmetry_axis" to mapOf(
            "zh-Hant" to "對稱軸",
            "en" to "Symmetry axis",
            "zh-Hans" to "对称轴",
            "ja" to "対称軸",
            "ko" to "대칭축",
            "th" to "แกนสมมาตร"
        ),
        "ed_text_toolbar_hint" to mapOf(
            "zh-Hant" to "文字排版工具 · 正在編輯文字方塊",
            "en" to "Text tools · editing a text box",
            "zh-Hans" to "文字排版工具 · 正在编辑文本框",
            "ja" to "テキストツール · テキストボックスを編集中",
            "ko" to "텍스트 도구 · 텍스트 상자 편집 중",
            "th" to "เครื่องมือข้อความ · กำลังแก้ไขกล่องข้อความ"
        ),
        "edit" to mapOf(
            "zh-Hant" to "編修",
            "en" to "Edit",
            "zh-Hans" to "编辑",
            "ja" to "編集",
            "ko" to "편집",
            "th" to "แก้ไข"
        ),
        "edit_identity" to mapOf(
            "zh-Hant" to "編輯身分",
            "en" to "Edit Identity",
            "zh-Hans" to "编辑身份",
            "ja" to "表示名を編集",
            "ko" to "표시 정보 편집",
            "th" to "แก้ไขตัวตน"
        ),
        "edit_in_place" to mapOf(
            "zh-Hant" to "就地編輯文字",
            "en" to "Edit text here",
            "zh-Hans" to "就地编辑文字",
            "ja" to "その場で編集",
            "ko" to "여기에서 편집",
            "th" to "แก้ไขข้อความตรงนี้"
        ),
        "edit_root_folder" to mapOf(
            "zh-Hant" to "編輯最上層資料夾名稱",
            "en" to "Rename Root Folder",
            "zh-Hans" to "编辑最上层文件夹名称",
            "ja" to "ルートフォルダ名を変更",
            "ko" to "최상위 폴더 이름 변경",
            "th" to "แก้ไขชื่อโฟลเดอร์ระดับบนสุด"
        ),
        "email" to mapOf(
            "zh-Hant" to "電子郵件",
            "en" to "Email",
            "zh-Hans" to "电子邮件",
            "ja" to "メールアドレス",
            "ko" to "이메일",
            "th" to "อีเมล"
        ),
        "encrypt_covers_images" to mapOf(
            "zh-Hant" to "圖片",
            "en" to "Images",
            "zh-Hans" to "图片",
            "ja" to "画像",
            "ko" to "이미지",
            "th" to "รูปภาพ"
        ),
        "encrypt_covers_notes" to mapOf(
            "zh-Hant" to "筆記內容（文字、手寫、表格、圖形）",
            "en" to "Note content (text, ink, tables, shapes)",
            "zh-Hans" to "笔记内容（文字、手写、表格、图形）",
            "ja" to "ノートの内容（文字・手書き・表・図形）",
            "ko" to "노트 내용(텍스트, 필기, 표, 도형)",
            "th" to "เนื้อหาโน้ต (ข้อความ ลายมือ ตาราง รูปทรง)"
        ),
        "encrypt_enabled" to mapOf(
            "zh-Hant" to "已加密",
            "en" to "Encrypted",
            "zh-Hans" to "已加密",
            "ja" to "暗号化済み",
            "ko" to "암호화됨",
            "th" to "เข้ารหัสแล้ว"
        ),
        "encrypt_local_copy_warning" to mapOf(
            "zh-Hant" to "在這台裝置上，工作副本仍以明文存放。目前加密保護的是會同步到你雲端的筆記本套件。",
            "en" to "On this device, the working copy is still stored unencrypted. Encryption currently protects the notebook package — the copy that syncs to your cloud.",
            "zh-Hans" to "在这台设备上，工作副本仍以明文存放。目前加密保护的是会同步到你云端的笔记本套件。",
            "ja" to "この端末では作業用コピーは暗号化されていません。暗号化が保護するのは、クラウドに同期されるノートパッケージです。",
            "ko" to "이 기기의 작업 사본은 아직 암호화되지 않습니다. 현재 암호화는 클라우드로 동기화되는 노트 패키지를 보호합니다.",
            "th" to "บนอุปกรณ์นี้ สำเนาที่ใช้งานยังไม่ถูกเข้ารหัส การเข้ารหัสปกป้องแพ็กเกจที่ซิงก์ไปยังคลาวด์"
        ),
        "encrypt_not_recordings" to mapOf(
            "zh-Hant" to "錄音不加密 —— 這是刻意的",
            "en" to "Recordings are not encrypted — on purpose",
            "zh-Hans" to "录音不加密 —— 这是刻意的",
            "ja" to "録音は暗号化されません —— 意図的です",
            "ko" to "녹음은 암호화되지 않습니다 —— 의도적입니다",
            "th" to "การบันทึกเสียงไม่ถูกเข้ารหัส —— เป็นความตั้งใจ"
        ),
        "encrypt_notebook" to mapOf(
            "zh-Hant" to "加密這本筆記",
            "en" to "Encrypt this notebook",
            "zh-Hans" to "加密这本笔记",
            "ja" to "このノートを暗号化",
            "ko" to "이 노트 암호화",
            "th" to "เข้ารหัสสมุดบันทึกนี้"
        ),
        "encrypt_only_new" to mapOf(
            "zh-Hant" to "只有新建的筆記本可以加密，既有的筆記本維持原樣。",
            "en" to "Only new notebooks can be encrypted. Existing notebooks stay as they are.",
            "zh-Hans" to "只有新建的笔记本可以加密，既有的笔记本维持原样。",
            "ja" to "暗号化できるのは新しいノートだけです。既存のノートはそのままです。",
            "ko" to "새 노트만 암호화할 수 있습니다. 기존 노트는 그대로 유지됩니다.",
            "th" to "เข้ารหัสได้เฉพาะสมุดใหม่ สมุดเดิมจะคงเดิม"
        ),
        "encrypt_passphrase" to mapOf(
            "zh-Hant" to "密碼",
            "en" to "Passphrase",
            "zh-Hans" to "密码",
            "ja" to "パスフレーズ",
            "ko" to "암호",
            "th" to "รหัสผ่าน"
        ),
        "encrypt_passphrase_again" to mapOf(
            "zh-Hant" to "再輸入一次密碼",
            "en" to "Repeat passphrase",
            "zh-Hans" to "再输入一次密码",
            "ja" to "パスフレーズを再入力",
            "ko" to "암호 다시 입력",
            "th" to "ยืนยันรหัสผ่าน"
        ),
        "encrypt_passphrase_mismatch" to mapOf(
            "zh-Hant" to "兩次輸入不一致",
            "en" to "The two entries do not match",
            "zh-Hans" to "两次输入不一致",
            "ja" to "入力が一致しません",
            "ko" to "입력이 일치하지 않습니다",
            "th" to "สองรายการไม่ตรงกัน"
        ),
        "encrypt_passphrase_too_short" to mapOf(
            "zh-Hant" to "至少 8 個字元",
            "en" to "Use at least 8 characters",
            "zh-Hans" to "至少 8 个字元",
            "ja" to "8 文字以上にしてください",
            "ko" to "8자 이상 입력하세요",
            "th" to "ใช้อย่างน้อย 8 ตัวอักษร"
        ),
        "encrypt_recordings_why" to mapOf(
            "zh-Hant" to "加密之後，VLC 之類的播放器就打不開你自己的錄音了。你的檔案要一直是你自己打得開的檔案。",
            "en" to "Encrypting them would stop VLC and other players from opening your own recordings. Your files stay files you can open yourself.",
            "zh-Hans" to "加密之后，VLC 之类的播放器就打不开你自己的录音了。你的文件要一直是你自己打得开的文件。",
            "ja" to "暗号化すると、VLC などのプレーヤーで自分の録音を開けなくなります。あなたのファイルは、あなた自身が開けるファイルのままにします。",
            "ko" to "암호화하면 VLC 같은 플레이어로 자기 녹음을 열 수 없게 됩니다. 당신의 파일은 당신이 직접 열 수 있는 파일로 남습니다.",
            "th" to "การเข้ารหัสจะทำให้ VLC และโปรแกรมเล่นอื่นเปิดไฟล์บันทึกเสียงของคุณไม่ได้ ไฟล์ของคุณจะยังคงเป็นไฟล์ที่คุณเปิดเองได้"
        ),
        "encrypt_scope_title" to mapOf(
            "zh-Hant" to "加密涵蓋的範圍",
            "en" to "What encryption covers",
            "zh-Hans" to "加密涵盖的范围",
            "ja" to "暗号化の対象",
            "ko" to "암호화 범위",
            "th" to "สิ่งที่การเข้ารหัสครอบคลุม"
        ),
        "encrypt_unlock" to mapOf(
            "zh-Hant" to "解鎖",
            "en" to "Unlock",
            "zh-Hans" to "解锁",
            "ja" to "ロック解除",
            "ko" to "잠금 해제",
            "th" to "ปลดล็อก"
        ),
        "encrypt_wrong_passphrase" to mapOf(
            "zh-Hant" to "密碼錯誤",
            "en" to "Wrong passphrase",
            "zh-Hans" to "密码错误",
            "ja" to "パスフレーズが違います",
            "ko" to "암호가 올바르지 않습니다",
            "th" to "รหัสผ่านไม่ถูกต้อง"
        ),
        "encryption" to mapOf(
            "zh-Hant" to "資料去了哪裡",
            "en" to "Where your data goes",
            "zh-Hans" to "资料去了哪里",
            "ja" to "データの行き先",
            "ko" to "데이터가 가는 곳",
            "th" to "ข้อมูลของคุณไปที่ไหน"
        ),
        "encryption_desc" to mapOf(
            "zh-Hant" to "只在這台裝置與你自己的雲端，不經過我們的伺服器",
            "en" to "This device and your own cloud only — never our servers",
            "zh-Hans" to "只在这台设备与你自己的云端，不经过我们的服务器",
            "ja" to "この端末とあなた自身のクラウドのみ。当社のサーバーは経由しません",
            "ko" to "이 기기와 사용자 본인의 클라우드에만 저장되며, 당사 서버를 거치지 않습니다",
            "th" to "เฉพาะอุปกรณ์นี้และคลาวด์ของคุณเอง ไม่ผ่านเซิร์ฟเวอร์ของเรา"
        ),
        "end_collaboration" to mapOf(
            "zh-Hant" to "結束協同會議",
            "en" to "End Collaboration",
            "zh-Hans" to "结束协同会议",
            "ja" to "共同編集を終了",
            "ko" to "공동 편집 종료",
            "th" to "สิ้นสุดการทำงานร่วมกัน"
        )
    )

    private fun part10(): Map<String, Map<String, String>> = mapOf(
        "end_session_confirm" to mapOf(
            "zh-Hant" to "確認結束多人協同會議？所有在線成員將被中斷連線。",
            "en" to "End collaborative session? All online participants will be disconnected.",
            "zh-Hans" to "确认结束多人协同会议？所有在线成员将被断开连接。",
            "ja" to "共同編集を終了しますか？全メンバーの接続が切断されます。",
            "ko" to "공동 편집 세션을 종료하시겠습니까? 모든 참여자의 연결이 끊어집니다.",
            "th" to "สิ้นสุดเซสชันหรือไม่? ผู้เข้าร่วมทั้งหมดจะถูกตัดการเชื่อมต่อ"
        ),
        "engineering_dim_tip" to mapOf(
            "zh-Hant" to "點擊一鍵貼入畫布零件旁",
            "en" to "Tap to insert dimension next to parts",
            "zh-Hans" to "点击一键贴入画布零件旁",
            "ja" to "タップで部品の横に寸法を挿入",
            "ko" to "탭하여 부품 옆에 치수 삽입",
            "th" to "แตะเพื่อแทรกขนาดข้างชิ้นส่วน"
        ),
        "enter_canvas_minimal_mode" to mapOf(
            "zh-Hant" to "進入畫布極簡模式",
            "en" to "Enter minimal canvas mode",
            "zh-Hans" to "进入画布极简模式",
            "ja" to "キャンバス最小モードに切り替え",
            "ko" to "캔버스 미니멀 모드로 전환",
            "th" to "เข้าสู่โหมดผืนผ้าใบแบบย่อ"
        ),
        "enter_recording_title" to mapOf(
            "zh-Hant" to "輸入錄音標題",
            "en" to "Enter recording title",
            "zh-Hans" to "输入录音标题",
            "ja" to "録音タイトルを入力",
            "ko" to "녹음 제목 입력",
            "th" to "ใส่ชื่อการบันทึก"
        ),
        "enter_room_id" to mapOf(
            "zh-Hant" to "貼上邀請連結（或房號）",
            "en" to "Paste the invite link (or room code)",
            "zh-Hans" to "贴上邀请连结（或房号）",
            "ja" to "招待リンク（またはルームコード）を貼り付け",
            "ko" to "초대 링크(또는 방 코드)를 붙여넣기",
            "th" to "วางลิงก์เชิญ (หรือรหัสห้อง)"
        ),
        "enter_title" to mapOf(
            "zh-Hant" to "輸入新標題",
            "en" to "Enter New Title",
            "zh-Hans" to "输入新标题",
            "ja" to "新しいタイトルを入力",
            "ko" to "새 제목 입력",
            "th" to "ใส่ชื่อเรื่องใหม่"
        ),
        "enter_url" to mapOf(
            "zh-Hant" to "輸入網址 (URL)",
            "en" to "Enter URL",
            "zh-Hans" to "输入网址 (URL)",
            "ja" to "URLを入力",
            "ko" to "URL 입력",
            "th" to "ป้อน URL"
        ),
        "err_backup_failed" to mapOf(
            "zh-Hant" to "備份失敗，未進行：%@",
            "en" to "Backup failed, nothing was changed: %@",
            "zh-Hans" to "备份失败，未进行：%@",
            "ja" to "バックアップに失敗したため、何も変更していません：%@",
            "ko" to "백업에 실패하여 아무것도 변경하지 않았습니다: %@",
            "th" to "สำรองข้อมูลไม่สำเร็จ จึงไม่มีการเปลี่ยนแปลง: %@"
        ),
        "err_coordinate_drift" to mapOf(
            "zh-Hant" to "第 %1@ 頁第 %2@ 筆的座標對不上",
            "en" to "Coordinates do not match for stroke %2@ on page %1@",
            "zh-Hans" to "第 %1@ 页第 %2@ 笔的坐标对不上",
            "ja" to "%1@ ページ目 %2@ 本目のストロークの座標が一致しません",
            "ko" to "%1@쪽 %2@번째 획의 좌표가 맞지 않습니다",
            "th" to "พิกัดของเส้นที่ %2@ บนหน้า %1@ ไม่ตรงกัน"
        ),
        "err_core_not_ready" to mapOf(
            "zh-Hant" to "核心未就緒",
            "en" to "The core engine is not ready",
            "zh-Hans" to "核心未就绪",
            "ja" to "コアエンジンの準備ができていません",
            "ko" to "코어 엔진이 준비되지 않았습니다",
            "th" to "เครื่องยนต์หลักยังไม่พร้อม"
        ),
        "err_hwr_download" to mapOf(
            "zh-Hant" to "手寫模型下載失敗（請連上 Wi-Fi）：%@",
            "en" to "Handwriting model download failed (please connect to Wi-Fi): %@",
            "zh-Hans" to "手写模型下载失败（请连上 Wi-Fi）：%@",
            "ja" to "手書きモデルのダウンロードに失敗しました（Wi-Fi に接続してください）：%@",
            "ko" to "손글씨 모델 다운로드에 실패했습니다(Wi-Fi에 연결해 주세요): %@",
            "th" to "ดาวน์โหลดโมเดลลายมือไม่สำเร็จ (โปรดเชื่อมต่อ Wi-Fi): %@"
        ),
        "err_hwr_failed" to mapOf(
            "zh-Hant" to "辨識失敗：%@",
            "en" to "Recognition failed: %@",
            "zh-Hans" to "识别失败：%@",
            "ja" to "認識に失敗しました：%@",
            "ko" to "인식에 실패했습니다: %@",
            "th" to "การรู้จำล้มเหลว: %@"
        ),
        "err_hwr_no_model" to mapOf(
            "zh-Hant" to "沒有「%@」的手寫模型",
            "en" to "No handwriting model for “%@”",
            "zh-Hans" to "没有「%@」的手写模型",
            "ja" to "「%@」の手書きモデルがありません",
            "ko" to "‘%@’용 손글씨 모델이 없습니다",
            "th" to "ไม่มีโมเดลลายมือสำหรับ “%@”"
        ),
        "err_hwr_unsupported" to mapOf(
            "zh-Hant" to "這台裝置無法使用手寫辨識（需要 Google Play 服務）：%@",
            "en" to "Handwriting recognition is unavailable on this device (Google Play services required): %@",
            "zh-Hans" to "这台设备无法使用手写识别（需要 Google Play 服务）：%@",
            "ja" to "この端末では手書き認識を利用できません（Google Play 開発者サービスが必要）：%@",
            "ko" to "이 기기에서는 손글씨 인식을 사용할 수 없습니다(Google Play 서비스 필요): %@",
            "th" to "อุปกรณ์นี้ใช้การรู้จำลายมือไม่ได้ (ต้องมี Google Play services): %@"
        ),
        "err_image_read_failed" to mapOf(
            "zh-Hant" to "讀不到這張圖片",
            "en" to "Could not read that image",
            "zh-Hans" to "读不到这张图片",
            "ja" to "その画像を読み込めません",
            "ko" to "이미지를 읽을 수 없습니다",
            "th" to "อ่านรูปภาพนี้ไม่ได้"
        ),
        "err_insert_recording_failed" to mapOf(
            "zh-Hant" to "插入錄音失敗，音檔可能已被移除",
            "en" to "Could not insert the recording — the audio file may have been removed",
            "zh-Hans" to "插入录音失败，音档可能已被移除",
            "ja" to "録音を挿入できませんでした。音声ファイルが削除されている可能性があります",
            "ko" to "녹음을 삽입하지 못했습니다. 오디오 파일이 삭제되었을 수 있습니다",
            "th" to "แทรกเสียงบันทึกไม่สำเร็จ ไฟล์เสียงอาจถูกลบไปแล้ว"
        ),
        "err_mic_open_failed" to mapOf(
            "zh-Hant" to "無法開啟麥克風：%@",
            "en" to "Could not open the microphone: %@",
            "zh-Hans" to "无法开启麦克风：%@",
            "ja" to "マイクを開けませんでした：%@",
            "ko" to "마이크를 열 수 없습니다: %@",
            "th" to "เปิดไมโครโฟนไม่ได้: %@"
        ),
        "err_mic_unsupported" to mapOf(
            "zh-Hant" to "這台裝置不支援 16kHz 單聲道錄音",
            "en" to "This device does not support 16 kHz mono recording",
            "zh-Hans" to "这台设备不支持 16kHz 单声道录音",
            "ja" to "この端末は 16kHz モノラル録音に対応していません",
            "ko" to "이 기기는 16kHz 모노 녹음을 지원하지 않습니다",
            "th" to "อุปกรณ์นี้ไม่รองรับการบันทึกเสียงแบบโมโน 16 kHz"
        ),
        "err_no_mic_permission" to mapOf(
            "zh-Hant" to "沒有麥克風權限",
            "en" to "No microphone permission",
            "zh-Hans" to "没有麦克风权限",
            "ja" to "マイクの権限がありません",
            "ko" to "마이크 권한이 없습니다",
            "th" to "ไม่ได้รับสิทธิ์ไมโครโฟน"
        ),
        "err_no_pages" to mapOf(
            "zh-Hant" to "這本筆記沒有任何頁面",
            "en" to "This notebook has no pages",
            "zh-Hans" to "这本笔记没有任何页面",
            "ja" to "このノートにはページがありません",
            "ko" to "이 노트에는 페이지가 없습니다",
            "th" to "สมุดบันทึกนี้ไม่มีหน้า"
        ),
        "err_page_count_mismatch" to mapOf(
            "zh-Hant" to "頁數不符：原稿 %1@ 頁、套件 %2@ 頁",
            "en" to "Page count differs: %1@ in the original, %2@ in the package",
            "zh-Hans" to "页数不符：原稿 %1@ 页、套件 %2@ 页",
            "ja" to "ページ数が一致しません：原本 %1@ ページ、パッケージ %2@ ページ",
            "ko" to "페이지 수가 다릅니다: 원본 %1@쪽, 패키지 %2@쪽",
            "th" to "จำนวนหน้าไม่ตรงกัน: ต้นฉบับ %1@ หน้า แพ็กเกจ %2@ หน้า"
        ),
        "err_stroke_count_mismatch" to mapOf(
            "zh-Hant" to "第 %1@ 頁筆畫數不符：原稿 %2@ 筆、套件 %3@ 筆",
            "en" to "Page %1@ stroke count differs: %2@ in the original, %3@ in the package",
            "zh-Hans" to "第 %1@ 页笔画数不符：原稿 %2@ 笔、套件 %3@ 笔",
            "ja" to "%1@ ページ目のストローク数が一致しません：原本 %2@、パッケージ %3@",
            "ko" to "%1@쪽의 획 수가 다릅니다: 원본 %2@, 패키지 %3@",
            "th" to "จำนวนเส้นของหน้า %1@ ไม่ตรงกัน: ต้นฉบับ %2@ แพ็กเกจ %3@"
        ),
        "err_sync_folder_failed" to mapOf(
            "zh-Hant" to "無法在同步資料夾建立 %@",
            "en" to "Could not create %@ in the sync folder",
            "zh-Hans" to "无法在同步文件夹创建 %@",
            "ja" to "同期フォルダに %@ を作成できませんでした",
            "ko" to "동기화 폴더에 %@을(를) 만들 수 없습니다",
            "th" to "สร้าง %@ ในโฟลเดอร์ซิงก์ไม่ได้"
        ),
        "error_generic" to mapOf(
            "zh-Hant" to "發生錯誤，請稍後再試。詳細資訊在同步日誌裡。",
            "en" to "Something went wrong. Please try again; details are in the sync log.",
            "zh-Hans" to "发生错误，请稍后再试。详细信息在同步日志里。",
            "ja" to "エラーが発生しました。もう一度お試しください。詳細は同期ログにあります。",
            "ko" to "오류가 발생했습니다. 다시 시도하세요. 자세한 내용은 동기화 로그에 있습니다.",
            "th" to "เกิดข้อผิดพลาด โปรดลองอีกครั้ง รายละเอียดอยู่ในบันทึกการซิงก์"
        ),
        "exit_canvas_minimal_mode" to mapOf(
            "zh-Hant" to "退出畫布極簡模式",
            "en" to "Exit minimal canvas mode",
            "zh-Hans" to "退出画布极简模式",
            "ja" to "キャンバス最小モードを終了",
            "ko" to "캔버스 미니멀 모드 종료",
            "th" to "ออกจากโหมดผืนผ้าใบแบบย่อ"
        ),
        "expand" to mapOf(
            "zh-Hant" to "展開",
            "en" to "Expand",
            "zh-Hans" to "展开",
            "ja" to "展開",
            "ko" to "펼치기",
            "th" to "ขยาย"
        ),
        "expand_minimal_toolbox" to mapOf(
            "zh-Hant" to "展開迷你工具列",
            "en" to "Open mini toolbar",
            "zh-Hans" to "展开迷你工具栏",
            "ja" to "ミニツールバーを開く",
            "ko" to "미니 도구 막대 열기",
            "th" to "เปิดแถบเครื่องมือย่อ"
        ),
        "export_done" to mapOf(
            "zh-Hant" to "已匯出：%@",
            "en" to "Exported: %@",
            "zh-Hans" to "已导出：%@",
            "ja" to "書き出しました：%@",
            "ko" to "내보냈습니다: %@",
            "th" to "ส่งออกแล้ว: %@"
        ),
        "export_err_no_pages" to mapOf(
            "zh-Hant" to "這本筆記沒有任何頁面",
            "en" to "This notebook has no pages",
            "zh-Hans" to "这本笔记没有任何页面",
            "ja" to "このノートにはページがありません",
            "ko" to "이 노트에는 페이지가 없습니다",
            "th" to "สมุดบันทึกเล่มนี้ไม่มีหน้า"
        ),
        "export_failed" to mapOf(
            "zh-Hant" to "匯出失敗：%@",
            "en" to "Export failed: %@",
            "zh-Hans" to "导出失败：%@",
            "ja" to "書き出しに失敗しました：%@",
            "ko" to "내보내기 실패: %@",
            "th" to "ส่งออกไม่สำเร็จ: %@"
        ),
        "export_image" to mapOf(
            "zh-Hant" to "匯出為圖片",
            "en" to "Export Image",
            "zh-Hans" to "导出为图片",
            "ja" to "画像として書き出し",
            "ko" to "이미지로 내보내기",
            "th" to "ส่งออกเป็นรูปภาพ"
        ),
        "export_markdown" to mapOf(
            "zh-Hant" to "匯出 Markdown",
            "en" to "Export Markdown",
            "zh-Hans" to "导出 Markdown",
            "ja" to "Markdown を書き出す",
            "ko" to "Markdown 내보내기",
            "th" to "ส่งออก Markdown"
        ),
        "export_now" to mapOf(
            "zh-Hant" to "匯出",
            "en" to "Export",
            "zh-Hans" to "导出",
            "ja" to "書き出す",
            "ko" to "내보내기",
            "th" to "ส่งออก"
        ),
        "export_pdf" to mapOf(
            "zh-Hant" to "匯出 PDF",
            "en" to "Export PDF",
            "zh-Hans" to "导出 PDF",
            "ja" to "PDF を書き出す",
            "ko" to "PDF 내보내기",
            "th" to "ส่งออก PDF"
        ),
        "export_preview" to mapOf(
            "zh-Hant" to "匯出預覽",
            "en" to "Export preview",
            "zh-Hans" to "导出预览",
            "ja" to "書き出しプレビュー",
            "ko" to "내보내기 미리보기",
            "th" to "ตัวอย่างการส่งออก"
        ),
        "export_preview_hint" to mapOf(
            "zh-Hant" to "這就是匯出後的樣子。左右滑動看其他頁。",
            "en" to "This is what the export will look like. Swipe to see other pages.",
            "zh-Hans" to "这就是导出后的样子。左右滑动看其他页。",
            "ja" to "書き出し後の見た目です。スワイプで他のページを確認できます。",
            "ko" to "내보낸 결과의 모습입니다. 넘겨서 다른 쪽을 볼 수 있습니다.",
            "th" to "นี่คือหน้าตาหลังส่งออก ปัดเพื่อดูหน้าอื่น"
        ),
        "export_preview_page" to mapOf(
            "zh-Hant" to "第 %@ 頁",
            "en" to "Page %@",
            "zh-Hans" to "第 %@ 页",
            "ja" to "%@ ページ",
            "ko" to "%@쪽",
            "th" to "หน้า %@"
        ),
        "export_preview_unavailable" to mapOf(
            "zh-Hant" to "預覽算不出來，但匯出本身不受影響",
            "en" to "Preview could not be rendered; the export itself still works",
            "zh-Hans" to "预览算不出来，但导出本身不受影响",
            "ja" to "プレビューを生成できませんでしたが、書き出しは可能です",
            "ko" to "미리보기를 만들지 못했지만 내보내기는 정상 동작합니다",
            "th" to "สร้างตัวอย่างไม่ได้ แต่การส่งออกยังใช้งานได้"
        ),
        "export_print" to mapOf(
            "zh-Hant" to "匯出與列印",
            "en" to "Export & Print",
            "zh-Hans" to "导出与打印",
            "ja" to "書き出しと印刷",
            "ko" to "내보내기 및 인쇄",
            "th" to "ส่งออกและพิมพ์"
        ),
        "export_save_as" to mapOf(
            "zh-Hant" to "儲存到…",
            "en" to "Save to Files…",
            "zh-Hans" to "保存到…",
            "ja" to "ファイルに保存…",
            "ko" to "파일로 저장…",
            "th" to "บันทึกไปยังไฟล์…"
        ),
        "extend_page" to mapOf(
            "zh-Hant" to "延長此頁",
            "en" to "Extend Page",
            "zh-Hans" to "延长此页",
            "ja" to "ページを延長",
            "ko" to "페이지 연장",
            "th" to "ขยายหน้านี้"
        ),
        "extend_page_amount" to mapOf(
            "zh-Hant" to "向下延長此頁 (+800pt)",
            "en" to "Extend Downwards (+800pt)",
            "zh-Hans" to "向下延长此页 (+800pt)",
            "ja" to "下へページ延長 (+800pt)",
            "ko" to "아래로 페이지 연장 (+800pt)",
            "th" to "ขยายหน้าลงด้านล่าง (+800pt)"
        ),
        "favorite_colors" to mapOf(
            "zh-Hant" to "收藏色盤",
            "en" to "Favorites",
            "zh-Hans" to "收藏色盘",
            "ja" to "お気に入り",
            "ko" to "즐겨찾는 색상",
            "th" to "สีที่ชอบ"
        ),
        "fetch_preview" to mapOf(
            "zh-Hant" to "解析預覽",
            "en" to "Fetch Preview",
            "zh-Hans" to "解析预览",
            "ja" to "プレビュー取得",
            "ko" to "미리보기 가져오기",
            "th" to "ดึงตัวอย่าง"
        ),
        "fill_color" to mapOf(
            "zh-Hant" to "填滿顏色",
            "en" to "Fill color",
            "zh-Hans" to "填充颜色",
            "ja" to "塗りつぶし",
            "ko" to "채우기 색",
            "th" to "สีพื้น"
        ),
        "filter_ai" to mapOf(
            "zh-Hant" to "AI 概念渲染",
            "en" to "AI Concepts",
            "zh-Hans" to "AI 概念渲染",
            "ja" to "AI コンセプト",
            "ko" to "AI 개념 렌더",
            "th" to "คอนเซ็ปต์ AI"
        ),
        "filter_contrast" to mapOf(
            "zh-Hant" to "清晰",
            "en" to "Sharp",
            "zh-Hans" to "清晰",
            "ja" to "シャープ",
            "ko" to "선명",
            "th" to "คมชัด"
        ),
        "filter_mono" to mapOf(
            "zh-Hant" to "黑白",
            "en" to "Mono",
            "zh-Hans" to "黑白",
            "ja" to "モノクロ",
            "ko" to "흑백",
            "th" to "ขาวดำ"
        ),
        "filter_original" to mapOf(
            "zh-Hant" to "原圖",
            "en" to "Original",
            "zh-Hans" to "原图",
            "ja" to "オリジナル",
            "ko" to "원본",
            "th" to "ต้นฉบับ"
        ),
        "filter_physical" to mapOf(
            "zh-Hant" to "實體規格圖",
            "en" to "Physical Specs",
            "zh-Hans" to "实体规格图",
            "ja" to "実体規格図",
            "ko" to "실제 사양도",
            "th" to "ภาพสเปกจริง"
        ),
        "filter_vintage" to mapOf(
            "zh-Hant" to "復古",
            "en" to "Vintage",
            "zh-Hans" to "复古",
            "ja" to "ヴィンテージ",
            "ko" to "빈티지",
            "th" to "วินเทจ"
        ),
        "filter_warm" to mapOf(
            "zh-Hant" to "柔光",
            "en" to "Warm",
            "zh-Hans" to "柔光",
            "ja" to "ソフト",
            "ko" to "부드럽게",
            "th" to "นวลตา"
        ),
        "finish_recording" to mapOf(
            "zh-Hant" to "完成錄音",
            "en" to "Finish Recording",
            "zh-Hans" to "完成录音",
            "ja" to "録音完了",
            "ko" to "녹음 완료",
            "th" to "เสร็จสิ้นการบันทึก"
        ),
        "first_line_indent" to mapOf(
            "zh-Hant" to "首行",
            "en" to "First",
            "zh-Hans" to "首行",
            "ja" to "字下げ",
            "ko" to "첫 줄",
            "th" to "บรรทัดแรก"
        ),
        "folder_contains_notes" to mapOf(
            "zh-Hant" to "包含檔案",
            "en" to "Notes count",
            "zh-Hans" to "包含文件",
            "ja" to "ファイル件数",
            "ko" to "포함된 파일 수",
            "th" to "จำนวนไฟล์"
        ),
        "folder_name" to mapOf(
            "zh-Hant" to "資料夾名稱",
            "en" to "Folder Name",
            "zh-Hans" to "文件夹名称",
            "ja" to "フォルダ名",
            "ko" to "폴더 이름",
            "th" to "ชื่อโฟลเดอร์"
        ),
        "folder_new_default" to mapOf(
            "zh-Hant" to "新增資料夾",
            "en" to "New folder",
            "zh-Hans" to "新建文件夹",
            "ja" to "新しいフォルダ",
            "ko" to "새 폴더",
            "th" to "โฟลเดอร์ใหม่"
        ),
        "folder_sync_inaccessible" to mapOf(
            "zh-Hant" to "無法存取資料夾",
            "en" to "Folder inaccessible",
            "zh-Hans" to "无法访问文件夹",
            "ja" to "フォルダにアクセスできません",
            "ko" to "폴더에 접근할 수 없습니다",
            "th" to "เข้าถึงโฟลเดอร์ไม่ได้"
        ),
        "folder_sync_not_set" to mapOf(
            "zh-Hant" to "未設定同步資料夾",
            "en" to "Sync folder not set",
            "zh-Hans" to "未设置同步文件夹",
            "ja" to "同期フォルダが設定されていません",
            "ko" to "동기화 폴더가 설정되지 않았습니다",
            "th" to "ยังไม่ได้ตั้งค่าโฟลเดอร์ซิงก์"
        ),
        "folder_unlink" to mapOf(
            "zh-Hant" to "解除連結",
            "en" to "Unlink",
            "zh-Hans" to "解除链接",
            "ja" to "リンクを解除",
            "ko" to "연결 해제",
            "th" to "ยกเลิกการเชื่อมโยง"
        ),
        "folders" to mapOf(
            "zh-Hant" to "資料夾",
            "en" to "Folders",
            "zh-Hans" to "文件夹",
            "ja" to "フォルダ",
            "ko" to "폴더",
            "th" to "โฟลเดอร์"
        ),
        "font_bold" to mapOf(
            "zh-Hant" to "粗體",
            "en" to "Bold",
            "zh-Hans" to "粗体",
            "ja" to "太字",
            "ko" to "굵게",
            "th" to "ตัวหนา"
        ),
        "font_italic" to mapOf(
            "zh-Hant" to "斜體",
            "en" to "Italic",
            "zh-Hans" to "斜体",
            "ja" to "斜体",
            "ko" to "기울임",
            "th" to "ตัวเอียง"
        ),
        "font_mono" to mapOf(
            "zh-Hant" to "等寬",
            "en" to "Mono",
            "zh-Hans" to "等宽",
            "ja" to "等幅",
            "ko" to "고정폭",
            "th" to "ความกว้างคงที่"
        ),
        "font_rounded" to mapOf(
            "zh-Hant" to "圓體",
            "en" to "Rounded",
            "zh-Hans" to "圆体",
            "ja" to "丸ゴシック",
            "ko" to "둥근체",
            "th" to "ตัวมน"
        ),
        "font_serif" to mapOf(
            "zh-Hant" to "襯線",
            "en" to "Serif",
            "zh-Hans" to "衬线",
            "ja" to "セリフ",
            "ko" to "세리프",
            "th" to "มีเชิง"
        ),
        "font_size" to mapOf(
            "zh-Hant" to "字級大小",
            "en" to "Font Size",
            "zh-Hans" to "字号大小",
            "ja" to "文字サイズ",
            "ko" to "글꼴 크기",
            "th" to "ขนาดตัวอักษร"
        ),
        "font_style" to mapOf(
            "zh-Hant" to "字形",
            "en" to "Font style",
            "zh-Hans" to "字形",
            "ja" to "文字スタイル",
            "ko" to "글자 스타일",
            "th" to "ลักษณะอักษร"
        ),
        "font_system" to mapOf(
            "zh-Hant" to "系統字型",
            "en" to "System",
            "zh-Hans" to "系统字体",
            "ja" to "システム",
            "ko" to "시스템",
            "th" to "ระบบ"
        ),
        "font_system_default" to mapOf(
            "zh-Hant" to "系統預設",
            "en" to "System default",
            "zh-Hans" to "系统默认",
            "ja" to "システム標準",
            "ko" to "시스템 기본",
            "th" to "ค่าเริ่มต้นของระบบ"
        ),
        "footer_tagline" to mapOf(
            "zh-Hant" to "筆跡與錄音同步 · 本地優先 · 開放原始碼",
            "en" to "Dual Ink & Audio Sync · Offline First · Open Source",
            "zh-Hans" to "笔迹与录音同步 · 本地优先 · 开放源码",
            "ja" to "筆跡と音声の同期 · オフライン優先 · オープンソース",
            "ko" to "필기·음성 동기화 · 오프라인 우선 · 오픈소스",
            "th" to "ซิงค์ลายมือกับเสียง · ออฟไลน์เป็นหลัก · โอเพนซอร์ส"
        ),
        "geom_preview" to mapOf(
            "zh-Hant" to "3D 預覽",
            "en" to "3D Preview",
            "zh-Hans" to "3D 预览",
            "ja" to "3D プレビュー",
            "ko" to "3D 미리보기",
            "th" to "ดูตัวอย่าง 3D"
        ),
        "geom_shape" to mapOf(
            "zh-Hant" to "幾何形狀",
            "en" to "Geometric Shape",
            "zh-Hans" to "几何形状",
            "ja" to "幾何学形状",
            "ko" to "기하학적 도형",
            "th" to "รูปทรงเรขาคณิต"
        ),
        "gesture_decision" to mapOf(
            "zh-Hant" to "條件判斷分支",
            "en" to "Decision (if/else)",
            "zh-Hans" to "条件判断分支",
            "ja" to "条件分岐（if/else）",
            "ko" to "조건 분기 (if/else)",
            "th" to "เงื่อนไขแยกทาง (if/else)"
        ),
        "gesture_loading" to mapOf(
            "zh-Hant" to "載入更新狀態",
            "en" to "Loading / refresh",
            "zh-Hans" to "加载更新状态",
            "ja" to "読み込み・更新",
            "ko" to "로딩·새로고침",
            "th" to "กำลังโหลด / รีเฟรช"
        ),
        "gesture_long_press" to mapOf(
            "zh-Hant" to "長按觸發選單",
            "en" to "Long press for menu",
            "zh-Hans" to "长按触发菜单",
            "ja" to "長押しでメニュー",
            "ko" to "길게 눌러 메뉴",
            "th" to "กดค้างเพื่อเปิดเมนู"
        ),
        "gesture_success" to mapOf(
            "zh-Hant" to "成功驗證回饋",
            "en" to "Success feedback",
            "zh-Hans" to "成功验证反馈",
            "ja" to "成功フィードバック",
            "ko" to "성공 피드백",
            "th" to "แจ้งผลสำเร็จ"
        ),
        "gesture_swipe" to mapOf(
            "zh-Hant" to "左右滑動切換",
            "en" to "Swipe to switch",
            "zh-Hans" to "左右滑动切换",
            "ja" to "スワイプで切り替え",
            "ko" to "스와이프로 전환",
            "th" to "ปัดเพื่อสลับ"
        ),
        "gesture_tap" to mapOf(
            "zh-Hant" to "點擊跳轉",
            "en" to "Tap → next",
            "zh-Hans" to "点击跳转",
            "ja" to "タップで遷移",
            "ko" to "탭하여 이동",
            "th" to "แตะเพื่อไปต่อ"
        ),
        "golden_spiral_desc" to mapOf(
            "zh-Hant" to "以 1:1.618 斐波那契螺旋疊加於畫布，引導視覺焦點",
            "en" to "1:1.618 Fibonacci spiral overlay to guide focal point",
            "zh-Hans" to "以 1:1.618 斐波那契螺旋叠加于画布，引导视觉焦点",
            "ja" to "1:1.618のフィボナッチ螺旋で視線を自然に誘導",
            "ko" to "1:1.618 피보나치 나선 오버레이로 시선 유도",
            "th" to "ซ้อนทับเกลียวฟีโบนัชชี 1:1.618 เพื่อนำสายตา"
        )
    )

    private fun part11(): Map<String, Map<String, String>> = mapOf(
        "golden_spiral_ref" to mapOf(
            "zh-Hant" to "黃金螺旋參考線 (Golden Spiral)",
            "en" to "Golden Spiral Guide",
            "zh-Hans" to "黄金螺旋参考线 (Golden Spiral)",
            "ja" to "黄金螺旋ガイド",
            "ko" to "황금 나선 가이드",
            "th" to "เส้นนำเกลียวทอง"
        ),
        "google_sign_out" to mapOf(
            "zh-Hant" to "登出 Google",
            "en" to "Sign out of Google",
            "zh-Hans" to "登出 Google",
            "ja" to "Google からサインアウト",
            "ko" to "Google 로그아웃",
            "th" to "ออกจากระบบ Google"
        ),
        "guide_action" to mapOf(
            "zh-Hant" to "行為",
            "en" to "Action",
            "zh-Hans" to "行为",
            "ja" to "行動",
            "ko" to "행동",
            "th" to "การกระทำ"
        ),
        "guide_actions" to mapOf(
            "zh-Hant" to "行動",
            "en" to "Actions",
            "zh-Hans" to "行动",
            "ja" to "アクション",
            "ko" to "실행 항목",
            "th" to "สิ่งที่ต้องทำ"
        ),
        "guide_am" to mapOf(
            "zh-Hant" to "上午",
            "en" to "AM",
            "zh-Hans" to "上午",
            "ja" to "午前",
            "ko" to "오전",
            "th" to "ช่วงเช้า"
        ),
        "guide_answer" to mapOf(
            "zh-Hant" to "答",
            "en" to "A",
            "zh-Hans" to "答",
            "ja" to "答",
            "ko" to "답",
            "th" to "ตอบ"
        ),
        "guide_area" to mapOf(
            "zh-Hant" to "區域",
            "en" to "Area",
            "zh-Hans" to "区域",
            "ja" to "場所",
            "ko" to "구역",
            "th" to "พื้นที่"
        ),
        "guide_center_idea" to mapOf(
            "zh-Hant" to "核心概念",
            "en" to "Central Idea",
            "zh-Hans" to "核心概念",
            "ja" to "中心テーマ",
            "ko" to "중심 생각",
            "th" to "แนวคิดหลัก"
        ),
        "guide_content" to mapOf(
            "zh-Hant" to "內容",
            "en" to "Content",
            "zh-Hans" to "内容",
            "ja" to "内容",
            "ko" to "내용",
            "th" to "เนื้อหา"
        ),
        "guide_cue" to mapOf(
            "zh-Hant" to "提示欄",
            "en" to "Cues",
            "zh-Hans" to "提示栏",
            "ja" to "キーワード",
            "ko" to "단서",
            "th" to "คำใบ้"
        ),
        "guide_date" to mapOf(
            "zh-Hant" to "日期",
            "en" to "Date",
            "zh-Hans" to "日期",
            "ja" to "日付",
            "ko" to "날짜",
            "th" to "วันที่"
        ),
        "guide_day" to mapOf(
            "zh-Hant" to "日",
            "en" to "Day",
            "zh-Hans" to "日",
            "ja" to "日",
            "ko" to "일",
            "th" to "วัน"
        ),
        "guide_decisions" to mapOf(
            "zh-Hant" to "決議",
            "en" to "Decisions",
            "zh-Hans" to "决议",
            "ja" to "決定事項",
            "ko" to "결정 사항",
            "th" to "ข้อสรุป"
        ),
        "guide_detail" to mapOf(
            "zh-Hant" to "細節",
            "en" to "Detail",
            "zh-Hans" to "细节",
            "ja" to "詳細",
            "ko" to "세부",
            "th" to "รายละเอียด"
        ),
        "guide_done" to mapOf(
            "zh-Hant" to "完成",
            "en" to "Done",
            "zh-Hans" to "完成",
            "ja" to "完了",
            "ko" to "완료",
            "th" to "เสร็จ"
        ),
        "guide_drawing_area" to mapOf(
            "zh-Hant" to "作圖區",
            "en" to "Drawing area",
            "zh-Hans" to "作图区",
            "ja" to "作図エリア",
            "ko" to "작도 영역",
            "th" to "พื้นที่วาด"
        ),
        "guide_due" to mapOf(
            "zh-Hant" to "期限",
            "en" to "Due",
            "zh-Hans" to "期限",
            "ja" to "期日",
            "ko" to "기한",
            "th" to "กำหนดส่ง"
        ),
        "guide_feeling" to mapOf(
            "zh-Hant" to "感受",
            "en" to "Feeling",
            "zh-Hans" to "感受",
            "ja" to "感情",
            "ko" to "감정",
            "th" to "ความรู้สึก"
        ),
        "guide_fri" to mapOf(
            "zh-Hant" to "五",
            "en" to "Fri",
            "zh-Hans" to "五",
            "ja" to "金",
            "ko" to "금",
            "th" to "ศ."
        ),
        "guide_front_view" to mapOf(
            "zh-Hant" to "正視圖",
            "en" to "Front",
            "zh-Hans" to "正视图",
            "ja" to "正面図",
            "ko" to "정면도",
            "th" to "ด้านหน้า"
        ),
        "guide_goals" to mapOf(
            "zh-Hant" to "目標",
            "en" to "Goals",
            "zh-Hans" to "目标",
            "ja" to "目標",
            "ko" to "목표",
            "th" to "เป้าหมาย"
        ),
        "guide_habit" to mapOf(
            "zh-Hant" to "習慣",
            "en" to "Habit",
            "zh-Hans" to "习惯",
            "ja" to "習慣",
            "ko" to "습관",
            "th" to "นิสัย"
        ),
        "guide_iso_view" to mapOf(
            "zh-Hant" to "立體軸測",
            "en" to "Isometric",
            "zh-Hans" to "立体轴测",
            "ja" to "等角図",
            "ko" to "등각도",
            "th" to "ไอโซเมตริก"
        ),
        "guide_key_points" to mapOf(
            "zh-Hant" to "重點",
            "en" to "Key Points",
            "zh-Hans" to "重点",
            "ja" to "要点",
            "ko" to "핵심",
            "th" to "ประเด็นหลัก"
        ),
        "guide_know" to mapOf(
            "zh-Hant" to "已知",
            "en" to "Know",
            "zh-Hans" to "已知",
            "ja" to "知っている",
            "ko" to "안다",
            "th" to "รู้แล้ว"
        ),
        "guide_learned" to mapOf(
            "zh-Hant" to "學到了",
            "en" to "Learned",
            "zh-Hans" to "学到了",
            "ja" to "学んだ",
            "ko" to "배웠다",
            "th" to "ได้เรียนรู้"
        ),
        "guide_main" to mapOf(
            "zh-Hant" to "主標題",
            "en" to "Main",
            "zh-Hans" to "主标题",
            "ja" to "大項目",
            "ko" to "대항목",
            "th" to "หลัก"
        ),
        "guide_milestone" to mapOf(
            "zh-Hant" to "里程碑",
            "en" to "Milestone",
            "zh-Hans" to "里程碑",
            "ja" to "マイルストーン",
            "ko" to "마일스톤",
            "th" to "หมุดหมาย"
        ),
        "guide_mon" to mapOf(
            "zh-Hant" to "一",
            "en" to "Mon",
            "zh-Hans" to "一",
            "ja" to "月",
            "ko" to "월",
            "th" to "จ."
        ),
        "guide_month" to mapOf(
            "zh-Hant" to "月份",
            "en" to "Month",
            "zh-Hans" to "月份",
            "ja" to "月",
            "ko" to "월",
            "th" to "เดือน"
        ),
        "guide_my_notes" to mapOf(
            "zh-Hant" to "我的筆記",
            "en" to "My Notes",
            "zh-Hans" to "我的笔记",
            "ja" to "自分の言葉",
            "ko" to "내 메모",
            "th" to "บันทึกของฉัน"
        ),
        "guide_notes" to mapOf(
            "zh-Hant" to "筆記",
            "en" to "Notes",
            "zh-Hans" to "笔记",
            "ja" to "ノート",
            "ko" to "노트",
            "th" to "บันทึก"
        ),
        "guide_owner" to mapOf(
            "zh-Hant" to "負責人",
            "en" to "Owner",
            "zh-Hans" to "负责人",
            "ja" to "担当",
            "ko" to "담당",
            "th" to "ผู้รับผิดชอบ"
        ),
        "guide_palette" to mapOf(
            "zh-Hant" to "版面色彩",
            "en" to "Guide Colour",
            "zh-Hans" to "版面色彩",
            "ja" to "罫線の色",
            "ko" to "안내선 색",
            "th" to "สีเส้นนำ"
        ),
        "guide_palette_desc" to mapOf(
            "zh-Hant" to "切換全文件紙張底紋格線與點陣色彩調性",
            "en" to "Select document grid background style and accent palette",
            "zh-Hans" to "切换全文档纸张底纹格线与点阵配色方案",
            "ja" to "背景のグリッド・罫線カラーパレットを変更",
            "ko" to "페이지 배경 격자 스타일 및 톤 팔레트 선택",
            "th" to "เลือกสไตล์และชุดสีของเส้นตารางพื้นหลัง"
        ),
        "guide_pm" to mapOf(
            "zh-Hant" to "下午",
            "en" to "PM",
            "zh-Hans" to "下午",
            "ja" to "午後",
            "ko" to "오후",
            "th" to "ช่วงบ่าย"
        ),
        "guide_project" to mapOf(
            "zh-Hant" to "專案",
            "en" to "Project",
            "zh-Hans" to "专案",
            "ja" to "プロジェクト",
            "ko" to "프로젝트",
            "th" to "โครงการ"
        ),
        "guide_question" to mapOf(
            "zh-Hant" to "題目",
            "en" to "Question",
            "zh-Hans" to "题目",
            "ja" to "問題",
            "ko" to "문제",
            "th" to "คำถาม"
        ),
        "guide_questions" to mapOf(
            "zh-Hant" to "問題",
            "en" to "Questions",
            "zh-Hans" to "问题",
            "ja" to "疑問",
            "ko" to "질문",
            "th" to "คำถาม"
        ),
        "guide_reflection" to mapOf(
            "zh-Hant" to "回顧",
            "en" to "Reflection",
            "zh-Hans" to "回顾",
            "ja" to "振り返り",
            "ko" to "돌아보기",
            "th" to "สะท้อนคิด"
        ),
        "guide_review" to mapOf(
            "zh-Hant" to "回顧",
            "en" to "Review",
            "zh-Hans" to "回顾",
            "ja" to "振り返り",
            "ko" to "회고",
            "th" to "ทบทวน"
        ),
        "guide_right_way" to mapOf(
            "zh-Hant" to "✓ 正確畫法",
            "en" to "✓ Right way",
            "zh-Hans" to "✓ 正确画法",
            "ja" to "✓ 正しい描き方",
            "ko" to "✓ 올바른 작도",
            "th" to "✓ วาดถูก"
        ),
        "guide_sat" to mapOf(
            "zh-Hant" to "六",
            "en" to "Sat",
            "zh-Hans" to "六",
            "ja" to "土",
            "ko" to "토",
            "th" to "ส."
        ),
        "guide_screen" to mapOf(
            "zh-Hant" to "畫面",
            "en" to "Screen",
            "zh-Hans" to "画面",
            "ja" to "画面",
            "ko" to "화면",
            "th" to "หน้าจอ"
        ),
        "guide_side_view" to mapOf(
            "zh-Hant" to "側視圖",
            "en" to "Side",
            "zh-Hans" to "侧视图",
            "ja" to "側面図",
            "ko" to "측면도",
            "th" to "ด้านข้าง"
        ),
        "guide_solution" to mapOf(
            "zh-Hant" to "正確解法",
            "en" to "Correct Solution",
            "zh-Hans" to "正确解法",
            "ja" to "正しい解法",
            "ko" to "올바른 풀이",
            "th" to "วิธีแก้ที่ถูกต้อง"
        ),
        "guide_source" to mapOf(
            "zh-Hant" to "原文",
            "en" to "Source",
            "zh-Hans" to "原文",
            "ja" to "原文",
            "ko" to "원문",
            "th" to "ต้นฉบับ"
        ),
        "guide_stage" to mapOf(
            "zh-Hant" to "階段",
            "en" to "Stage",
            "zh-Hans" to "阶段",
            "ja" to "ステージ",
            "ko" to "단계",
            "th" to "ขั้น"
        ),
        "guide_step_1" to mapOf(
            "zh-Hant" to "①",
            "en" to "①",
            "zh-Hans" to "①",
            "ja" to "①",
            "ko" to "①",
            "th" to "①"
        ),
        "guide_step_2" to mapOf(
            "zh-Hant" to "②",
            "en" to "②",
            "zh-Hans" to "②",
            "ja" to "②",
            "ko" to "②",
            "th" to "②"
        ),
        "guide_step_3" to mapOf(
            "zh-Hant" to "③",
            "en" to "③",
            "zh-Hans" to "③",
            "ja" to "③",
            "ko" to "③",
            "th" to "③"
        ),
        "guide_step_4" to mapOf(
            "zh-Hant" to "④",
            "en" to "④",
            "zh-Hans" to "④",
            "ja" to "④",
            "ko" to "④",
            "th" to "④"
        ),
        "guide_step_5" to mapOf(
            "zh-Hant" to "⑤",
            "en" to "⑤",
            "zh-Hans" to "⑤",
            "ja" to "⑤",
            "ko" to "⑤",
            "th" to "⑤"
        ),
        "guide_step_6" to mapOf(
            "zh-Hant" to "⑥",
            "en" to "⑥",
            "zh-Hans" to "⑥",
            "ja" to "⑥",
            "ko" to "⑥",
            "th" to "⑥"
        ),
        "guide_sub" to mapOf(
            "zh-Hant" to "次重點",
            "en" to "Sub",
            "zh-Hans" to "次重点",
            "ja" to "中項目",
            "ko" to "중항목",
            "th" to "รอง"
        ),
        "guide_subject" to mapOf(
            "zh-Hant" to "科目",
            "en" to "Subject",
            "zh-Hans" to "科目",
            "ja" to "科目",
            "ko" to "과목",
            "th" to "วิชา"
        ),
        "guide_summary" to mapOf(
            "zh-Hant" to "摘要",
            "en" to "Summary",
            "zh-Hans" to "摘要",
            "ja" to "まとめ",
            "ko" to "요약",
            "th" to "สรุป"
        ),
        "guide_sun" to mapOf(
            "zh-Hant" to "日",
            "en" to "Sun",
            "zh-Hans" to "日",
            "ja" to "日",
            "ko" to "일",
            "th" to "อา."
        ),
        "guide_task" to mapOf(
            "zh-Hant" to "事項",
            "en" to "Task",
            "zh-Hans" to "事项",
            "ja" to "内容",
            "ko" to "할 일",
            "th" to "งาน"
        ),
        "guide_thu" to mapOf(
            "zh-Hant" to "四",
            "en" to "Thu",
            "zh-Hans" to "四",
            "ja" to "木",
            "ko" to "목",
            "th" to "พฤ."
        ),
        "guide_time" to mapOf(
            "zh-Hant" to "時間",
            "en" to "Time",
            "zh-Hans" to "时间",
            "ja" to "時間",
            "ko" to "시간",
            "th" to "เวลา"
        ),
        "guide_top_view" to mapOf(
            "zh-Hant" to "俯視圖",
            "en" to "Top",
            "zh-Hans" to "俯视图",
            "ja" to "平面図",
            "ko" to "평면도",
            "th" to "ด้านบน"
        ),
        "guide_topic" to mapOf(
            "zh-Hant" to "主題",
            "en" to "Topic",
            "zh-Hans" to "主题",
            "ja" to "テーマ",
            "ko" to "주제",
            "th" to "หัวข้อ"
        ),
        "guide_trap_rule" to mapOf(
            "zh-Hant" to "陷阱與口訣",
            "en" to "Trap & rule of thumb",
            "zh-Hans" to "陷阱与口诀",
            "ja" to "落とし穴とコツ",
            "ko" to "함정과 요령",
            "th" to "กับดักและเคล็ดลับ"
        ),
        "guide_tue" to mapOf(
            "zh-Hant" to "二",
            "en" to "Tue",
            "zh-Hans" to "二",
            "ja" to "火",
            "ko" to "화",
            "th" to "อ."
        ),
        "guide_want" to mapOf(
            "zh-Hant" to "想知道",
            "en" to "Want to Know",
            "zh-Hans" to "想知道",
            "ja" to "知りたい",
            "ko" to "알고 싶다",
            "th" to "อยากรู้"
        ),
        "guide_wed" to mapOf(
            "zh-Hant" to "三",
            "en" to "Wed",
            "zh-Hans" to "三",
            "ja" to "水",
            "ko" to "수",
            "th" to "พ."
        ),
        "guide_week" to mapOf(
            "zh-Hant" to "週次",
            "en" to "Week",
            "zh-Hans" to "週次",
            "ja" to "週",
            "ko" to "주",
            "th" to "สัปดาห์"
        ),
        "guide_wrong_way" to mapOf(
            "zh-Hant" to "✗ 錯誤畫法",
            "en" to "✗ Wrong way",
            "zh-Hans" to "✗ 错误画法",
            "ja" to "✗ 誤った描き方",
            "ko" to "✗ 잘못된 작도",
            "th" to "✗ วาดผิด"
        ),
        "handwriting_err_bitmap" to mapOf(
            "zh-Hant" to "無法取得點陣圖",
            "en" to "Could not get the bitmap",
            "zh-Hans" to "无法获取位图",
            "ja" to "ビットマップを取得できませんでした",
            "ko" to "비트맵을 가져올 수 없습니다",
            "th" to "รับบิตแมปไม่ได้"
        ),
        "handwriting_mode" to mapOf(
            "zh-Hant" to "手繪模式",
            "en" to "Handwriting",
            "zh-Hans" to "手绘模式",
            "ja" to "手描き",
            "ko" to "손글씨",
            "th" to "วาดเขียน"
        ),
        "handwriting_mode_desc" to mapOf(
            "zh-Hant" to "手繪創作模式：畫布接收手寫與繪畫筆刷輸入",
            "en" to "Handwriting & drawing mode: Full canvas ink active for Apple Pencil and stylus",
            "zh-Hans" to "手绘创作模式：画布接收手写与素描笔刷输入",
            "ja" to "手描きモード：Apple Pencil やスタイラスによるペン描画が有効",
            "ko" to "손글씨/드로잉 모드: 애플 펜슬 필기 및 스케치 활성화",
            "th" to "โหมดวาดเขียน: เปิดใช้งานหมึกวาดภาพเต็มรูปแบบสำหรับ Apple Pencil"
        ),
        "heading_1" to mapOf(
            "zh-Hant" to "標題 1",
            "en" to "Heading 1",
            "zh-Hans" to "标题 1",
            "ja" to "見出し 1",
            "ko" to "제목 1",
            "th" to "หัวเรื่อง 1"
        ),
        "heading_2" to mapOf(
            "zh-Hant" to "標題 2",
            "en" to "Heading 2",
            "zh-Hans" to "标题 2",
            "ja" to "見出し 2",
            "ko" to "제목 2",
            "th" to "หัวเรื่อง 2"
        ),
        "heading_3" to mapOf(
            "zh-Hant" to "標題 3",
            "en" to "Heading 3",
            "zh-Hans" to "标题 3",
            "ja" to "見出し 3",
            "ko" to "제목 3",
            "th" to "หัวเรื่อง 3"
        ),
        "help_and_legal" to mapOf(
            "zh-Hant" to "說明與條款",
            "en" to "Help & Legal",
            "zh-Hans" to "说明与条款",
            "ja" to "ヘルプと規約",
            "ko" to "도움말 및 약관",
            "th" to "ความช่วยเหลือและข้อกำหนด"
        ),
        "hex_code" to mapOf(
            "zh-Hant" to "十六進位色碼",
            "en" to "HEX Code",
            "zh-Hans" to "十六进制色码",
            "ja" to "16進数コード",
            "ko" to "HEX 코드",
            "th" to "รหัส HEX"
        ),
        "hide_item" to mapOf(
            "zh-Hant" to "隱藏此項目",
            "en" to "Hide",
            "zh-Hans" to "隐藏此项",
            "ja" to "非表示",
            "ko" to "숨기기",
            "th" to "ซ่อนรายการนี้"
        ),
        "highlight_color" to mapOf(
            "zh-Hant" to "螢光筆顏色",
            "en" to "Highlight color",
            "zh-Hans" to "荧光笔颜色",
            "ja" to "ハイライトの色",
            "ko" to "형광펜 색상",
            "th" to "สีไฮไลต์"
        ),
        "hint_comment_pin_body" to mapOf(
            "zh-Hant" to "接著**點頁面上任何一處**就會放下圖釘。再按一次工具列上的圖示即可離開放置模式。",
            "en" to "Now tap anywhere on the page to drop a pin there. Tap the toolbar icon again to leave placement mode.",
            "zh-Hans" to "接着**点页面上任何一处**就会放下图钉。再按一次工具栏上的图标即可离开放置模式。",
            "ja" to "次に、ページ上の**好きな場所をタップ**するとピンが置かれます。ツールバーのアイコンをもう一度押すと配置モードを終了します。",
            "ko" to "이제 페이지의 **아무 곳이나 탭**하면 핀이 놓입니다. 도구 모음 아이콘을 다시 누르면 배치 모드를 벗어납니다.",
            "th" to "จากนั้น**แตะที่ใดก็ได้บนหน้า**เพื่อวางหมุด แตะไอคอนบนแถบเครื่องมืออีกครั้งเพื่อออกจากโหมดวาง"
        )
    )

    private fun part12(): Map<String, Map<String, String>> = mapOf(
        "hint_comment_pin_title" to mapOf(
            "zh-Hant" to "新增討論圖釘",
            "en" to "Add Comment Pin",
            "zh-Hans" to "新增讨论图钉",
            "ja" to "コメントピンを追加",
            "ko" to "댓글 핀 추가",
            "th" to "เพิ่มหมุดความคิดเห็น"
        ),
        "hint_dont_show_again" to mapOf(
            "zh-Hant" to "不要再顯示這則提示",
            "en" to "Don't show this again",
            "zh-Hans" to "不要再显示这则提示",
            "ja" to "今後このヒントを表示しない",
            "ko" to "이 안내를 다시 표시하지 않기",
            "th" to "ไม่ต้องแสดงคำแนะนำนี้อีก"
        ),
        "hint_got_it" to mapOf(
            "zh-Hant" to "知道了",
            "en" to "Got it",
            "zh-Hans" to "知道了",
            "ja" to "わかりました",
            "ko" to "알겠습니다",
            "th" to "เข้าใจแล้ว"
        ),
        "hint_recognize_body" to mapOf(
            "zh-Hant" to "這會讀**目前這一頁**的手寫字並轉成文字。空白頁不會有結果 —— 先寫一點東西。",
            "en" to "This reads the handwriting on the current page and turns it into text. An empty page gives no result — draw or write something first.",
            "zh-Hans" to "这会读**目前这一页**的手写字并转成文字。空白页不会有结果 —— 先写一点东西。",
            "ja" to "**現在のページ**の手書きを読み取ってテキストにします。空のページでは結果が出ません —— まず何か書いてください。",
            "ko" to "**현재 페이지**의 손글씨를 읽어 텍스트로 바꿉니다. 빈 페이지는 결과가 없습니다 —— 먼저 무언가 쓰세요.",
            "th" to "อ่านลายมือใน**หน้าปัจจุบัน**แล้วแปลงเป็นข้อความ หน้าว่างจะไม่ได้ผลลัพธ์ —— เขียนอะไรสักอย่างก่อน"
        ),
        "hint_recognize_title" to mapOf(
            "zh-Hant" to "辨識手寫",
            "en" to "Recognise Handwriting",
            "zh-Hans" to "识别手写",
            "ja" to "手書きを認識",
            "ko" to "손글씨 인식",
            "th" to "รู้จำลายมือ"
        ),
        "hint_refine_sketch_body" to mapOf(
            "zh-Hant" to "先畫一些東西，再用畫布上方那條控制列把線條拉直、把形狀變規則。強度可以調，也可以還原。",
            "en" to "Draw something first, then use the bar at the top of the canvas to straighten lines and regularise shapes. You can dial the strength down or undo it.",
            "zh-Hans" to "先画一些东西，再用画布上方那条控制栏把线条拉直、把形状变规则。强度可以调，也可以还原。",
            "ja" to "まず何か描いてから、キャンバス上部のバーで線をまっすぐにし、図形を整えます。強度の調整も取り消しもできます。",
            "ko" to "먼저 무언가를 그린 다음, 캔버스 위쪽 막대로 선을 곧게 펴고 도형을 정리하세요. 강도 조절과 되돌리기가 가능합니다.",
            "th" to "วาดอะไรสักอย่างก่อน แล้วใช้แถบด้านบนผืนผ้าใบเพื่อจัดเส้นให้ตรงและปรับรูปทรงให้เรียบร้อย ปรับความเข้มหรือเลิกทำได้"
        ),
        "hint_refine_sketch_title" to mapOf(
            "zh-Hant" to "草圖修飾",
            "en" to "Refine Sketch",
            "zh-Hans" to "草图修饰",
            "ja" to "スケッチを整える",
            "ko" to "스케치 다듬기",
            "th" to "ปรับแต่งภาพร่าง"
        ),
        "hint_tabletop_body" to mapOf(
            "zh-Hant" to "把畫面分成兩半：畫布在上，工具移到下半部。這是給立在桌上的裝置用的 —— 上面看、下面寫。",
            "en" to "Splits the screen: the canvas goes on top, the tools move to the bottom half. Made for a device standing on a desk — look at the top, write on the bottom.",
            "zh-Hans" to "把画面分成两半：画布在上，工具移到下半部。这是给立在桌上的设备用的 —— 上面看、下面写。",
            "ja" to "画面を上下に分割します：上がキャンバス、下がツールです。机に立てた端末向け —— 上を見ながら下で書きます。",
            "ko" to "화면을 둘로 나눕니다: 위는 캔버스, 아래는 도구입니다. 책상에 세워 둔 기기를 위한 모드 —— 위를 보며 아래에 씁니다.",
            "th" to "แบ่งหน้าจอเป็นสองส่วน: ผืนผ้าใบอยู่บน เครื่องมืออยู่ล่าง ออกแบบมาสำหรับอุปกรณ์ที่ตั้งบนโต๊ะ —— ดูด้านบน เขียนด้านล่าง"
        ),
        "hint_tabletop_title" to mapOf(
            "zh-Hant" to "立起懸停模式",
            "en" to "Tabletop / Flex Mode",
            "zh-Hans" to "立起悬停模式",
            "ja" to "卓上／フレックスモード",
            "ko" to "탁상 / 플렉스 모드",
            "th" to "โหมดตั้งโต๊ะ / เฟล็กซ์"
        ),
        "home" to mapOf(
            "zh-Hant" to "首頁",
            "en" to "Home",
            "zh-Hans" to "首页",
            "ja" to "ホーム",
            "ko" to "홈",
            "th" to "หน้าแรก"
        ),
        "hosting_local_relay" to mapOf(
            "zh-Hant" to "本機正在提供協同中繼",
            "en" to "Hosting relay on this device",
            "zh-Hans" to "本机正在提供协同中继",
            "ja" to "この端末が中継を提供中",
            "ko" to "이 기기에서 릴레이 호스팅 중",
            "th" to "อุปกรณ์นี้กำลังเป็นรีเลย์"
        ),
        "hue_aurora_orange" to mapOf(
            "zh-Hant" to "極光鮮橘",
            "en" to "Aurora Orange",
            "zh-Hans" to "极光鲜橘",
            "ja" to "オーロラオレンジ",
            "ko" to "오로라 오렌지",
            "th" to "ส้มออโรรา"
        ),
        "hue_burgundy" to mapOf(
            "zh-Hant" to "勃艮第酒紅",
            "en" to "Burgundy",
            "zh-Hans" to "勃艮第酒红",
            "ja" to "バーガンディ",
            "ko" to "버건디",
            "th" to "เบอร์กันดี"
        ),
        "hue_business_blue" to mapOf(
            "zh-Hant" to "商務藍",
            "en" to "Business Blue",
            "zh-Hans" to "商务蓝",
            "ja" to "ビジネスブルー",
            "ko" to "비즈니스 블루",
            "th" to "น้ำเงินธุรกิจ"
        ),
        "hue_caramel_brown" to mapOf(
            "zh-Hant" to "焦糖棕",
            "en" to "Caramel Brown",
            "zh-Hans" to "焦糖棕",
            "ja" to "キャラメルブラウン",
            "ko" to "캐러멜 브라운",
            "th" to "น้ำตาลคาราเมล"
        ),
        "hue_caramel_pink" to mapOf(
            "zh-Hant" to "焦糖粉",
            "en" to "Caramel Pink",
            "zh-Hans" to "焦糖粉",
            "ja" to "キャラメルピンク",
            "ko" to "캐러멜 핑크",
            "th" to "ชมพูคาราเมล"
        ),
        "hue_chestnut" to mapOf(
            "zh-Hant" to "深栗褐",
            "en" to "Deep Chestnut",
            "zh-Hans" to "深栗褐",
            "ja" to "ディープチェスナット",
            "ko" to "딥 체스트넛",
            "th" to "น้ำตาลเกาลัด"
        ),
        "hue_cold_stone" to mapOf(
            "zh-Hant" to "冷石灰",
            "en" to "Cold Stone",
            "zh-Hans" to "冷石灰",
            "ja" to "コールドストーン",
            "ko" to "콜드 스톤",
            "th" to "หินเย็น"
        ),
        "hue_deep_navy" to mapOf(
            "zh-Hant" to "深海軍",
            "en" to "Deep Navy",
            "zh-Hans" to "深海军",
            "ja" to "ディープネイビー",
            "ko" to "딥 네이비",
            "th" to "กรมท่าเข้ม"
        ),
        "hue_electric_magenta" to mapOf(
            "zh-Hant" to "電光玫紅",
            "en" to "Electric Magenta",
            "zh-Hans" to "电光玫红",
            "ja" to "エレクトリックマゼンタ",
            "ko" to "일렉트릭 마젠타",
            "th" to "มาเจนต้าไฟฟ้า"
        ),
        "hue_fallen_leaf" to mapOf(
            "zh-Hant" to "落葉黃",
            "en" to "Fallen Leaf",
            "zh-Hans" to "落叶黄",
            "ja" to "フォールンリーフ",
            "ko" to "낙엽색",
            "th" to "ใบไม้ร่วง"
        ),
        "hue_fir_green" to mapOf(
            "zh-Hant" to "冷杉綠",
            "en" to "Fir Green",
            "zh-Hans" to "冷杉绿",
            "ja" to "ファーグリーン",
            "ko" to "전나무 초록",
            "th" to "เขียวเฟอร์"
        ),
        "hue_fluoro_cyan" to mapOf(
            "zh-Hant" to "螢光青藍",
            "en" to "Fluoro Cyan",
            "zh-Hans" to "荧光青蓝",
            "ja" to "フルオロシアン",
            "ko" to "형광 시안",
            "th" to "ฟ้าเรืองแสง"
        ),
        "hue_grape_gray" to mapOf(
            "zh-Hant" to "葡萄灰",
            "en" to "Grape Grey",
            "zh-Hans" to "葡萄灰",
            "ja" to "グレープグレー",
            "ko" to "그레이프 그레이",
            "th" to "เทาองุ่น"
        ),
        "hue_graphite_blue" to mapOf(
            "zh-Hant" to "石墨藍",
            "en" to "Graphite Blue",
            "zh-Hans" to "石墨蓝",
            "ja" to "グラファイトブルー",
            "ko" to "그래파이트 블루",
            "th" to "น้ำเงินกราไฟต์"
        ),
        "hue_gray_cardamom" to mapOf(
            "zh-Hant" to "灰豆蔻",
            "en" to "Grey Cardamom",
            "zh-Hans" to "灰豆蔻",
            "ja" to "グレーカルダモン",
            "ko" to "그레이 카다몸",
            "th" to "กระวานเทา"
        ),
        "hue_green_apple" to mapOf(
            "zh-Hant" to "青蘋綠",
            "en" to "Green Apple",
            "zh-Hans" to "青苹绿",
            "ja" to "グリーンアップル",
            "ko" to "그린 애플",
            "th" to "เขียวแอปเปิล"
        ),
        "hue_haze_blue" to mapOf(
            "zh-Hant" to "霧霾藍",
            "en" to "Haze Blue",
            "zh-Hans" to "雾霾蓝",
            "ja" to "ヘイズブルー",
            "ko" to "헤이즈 블루",
            "th" to "ฟ้าหมอก"
        ),
        "hue_high_energy_red" to mapOf(
            "zh-Hant" to "高能熾紅",
            "en" to "High-Energy Red",
            "zh-Hans" to "高能炽红",
            "ja" to "ハイエナジーレッド",
            "ko" to "하이에너지 레드",
            "th" to "แดงพลังสูง"
        ),
        "hue_ink_green" to mapOf(
            "zh-Hant" to "墨綠色",
            "en" to "Ink Green",
            "zh-Hans" to "墨绿色",
            "ja" to "インクグリーン",
            "ko" to "잉크 그린",
            "th" to "เขียวหมึก"
        ),
        "hue_iridescent_purple" to mapOf(
            "zh-Hant" to "幻彩紫",
            "en" to "Iridescent Purple",
            "zh-Hans" to "幻彩紫",
            "ja" to "イリデセントパープル",
            "ko" to "이리데센트 퍼플",
            "th" to "ม่วงเหลือบ"
        ),
        "hue_lavender" to mapOf(
            "zh-Hant" to "薰衣草",
            "en" to "Lavender",
            "zh-Hans" to "薰衣草",
            "ja" to "ラベンダー",
            "ko" to "라벤더",
            "th" to "ลาเวนเดอร์"
        ),
        "hue_midnight" to mapOf(
            "zh-Hant" to "極夜黑",
            "en" to "Midnight",
            "zh-Hans" to "极夜黑",
            "ja" to "ミッドナイト",
            "ko" to "미드나이트",
            "th" to "ดำเที่ยงคืน"
        ),
        "hue_milk_tea" to mapOf(
            "zh-Hant" to "奶茶駝",
            "en" to "Milk Tea",
            "zh-Hans" to "奶茶驼",
            "ja" to "ミルクティー",
            "ko" to "밀크티",
            "th" to "ชานม"
        ),
        "hue_mint_green" to mapOf(
            "zh-Hant" to "薄荷綠",
            "en" to "Mint Green",
            "zh-Hans" to "薄荷绿",
            "ja" to "ミントグリーン",
            "ko" to "민트 그린",
            "th" to "เขียวมิ้นต์"
        ),
        "hue_mustard" to mapOf(
            "zh-Hant" to "芥末黃",
            "en" to "Mustard",
            "zh-Hans" to "芥末黄",
            "ja" to "マスタード",
            "ko" to "머스터드",
            "th" to "มัสตาร์ด"
        ),
        "hue_neon_green" to mapOf(
            "zh-Hant" to "霓虹亮綠",
            "en" to "Neon Green",
            "zh-Hans" to "霓虹亮绿",
            "ja" to "ネオングリーン",
            "ko" to "네온 그린",
            "th" to "เขียวนีออน"
        ),
        "hue_oat_gray" to mapOf(
            "zh-Hant" to "燕麥灰",
            "en" to "Oat Grey",
            "zh-Hans" to "燕麦灰",
            "ja" to "オートグレー",
            "ko" to "오트 그레이",
            "th" to "เทาโอ๊ต"
        ),
        "hue_peach_apricot" to mapOf(
            "zh-Hant" to "蜜桃杏",
            "en" to "Peach Apricot",
            "zh-Hans" to "蜜桃杏",
            "ja" to "ピーチアプリコット",
            "ko" to "피치 애프리콧",
            "th" to "พีชแอปริคอต"
        ),
        "hue_periwinkle" to mapOf(
            "zh-Hant" to "淡紫藍",
            "en" to "Periwinkle",
            "zh-Hans" to "淡紫蓝",
            "ja" to "ペリウィンクル",
            "ko" to "페리윙클",
            "th" to "ม่วงอ่อน"
        ),
        "hue_premium_gray" to mapOf(
            "zh-Hant" to "高級灰",
            "en" to "Premium Grey",
            "zh-Hans" to "高级灰",
            "ja" to "プレミアムグレー",
            "ko" to "프리미엄 그레이",
            "th" to "เทาพรีเมียม"
        ),
        "hue_retro_teal" to mapOf(
            "zh-Hant" to "復古青",
            "en" to "Retro Teal",
            "zh-Hans" to "复古青",
            "ja" to "レトロティール",
            "ko" to "레트로 틸",
            "th" to "เขียวเรโทร"
        ),
        "hue_rose_dusk" to mapOf(
            "zh-Hant" to "玫瑰暮",
            "en" to "Rose Dusk",
            "zh-Hans" to "玫瑰暮",
            "ja" to "ローズダスク",
            "ko" to "로즈 더스크",
            "th" to "กุหลาบสนธยา"
        ),
        "hue_rust_red" to mapOf(
            "zh-Hant" to "鐵鏽紅",
            "en" to "Rust Red",
            "zh-Hans" to "铁锈红",
            "ja" to "ラストレッド",
            "ko" to "러스트 레드",
            "th" to "แดงสนิม"
        ),
        "hue_sage_green" to mapOf(
            "zh-Hant" to "鼠尾綠",
            "en" to "Sage Green",
            "zh-Hans" to "鼠尾绿",
            "ja" to "セージグリーン",
            "ko" to "세이지 그린",
            "th" to "เขียวเสจ"
        ),
        "hue_sakura_pink" to mapOf(
            "zh-Hant" to "櫻花粉",
            "en" to "Sakura Pink",
            "zh-Hans" to "樱花粉",
            "ja" to "さくらピンク",
            "ko" to "사쿠라 핑크",
            "th" to "ชมพูซากุระ"
        ),
        "hue_sky_ultra_blue" to mapOf(
            "zh-Hant" to "天空極藍",
            "en" to "Sky Ultra Blue",
            "zh-Hans" to "天空极蓝",
            "ja" to "スカイウルトラブルー",
            "ko" to "스카이 울트라 블루",
            "th" to "ฟ้าสุดขอบ"
        ),
        "hue_slate_blue" to mapOf(
            "zh-Hant" to "黛藍色",
            "en" to "Slate Blue",
            "zh-Hans" to "黛蓝色",
            "ja" to "スレートブルー",
            "ko" to "슬레이트 블루",
            "th" to "น้ำเงินหินชนวน"
        ),
        "hue_terracotta" to mapOf(
            "zh-Hant" to "陶土紅",
            "en" to "Terracotta",
            "zh-Hans" to "陶土红",
            "ja" to "テラコッタ",
            "ko" to "테라코타",
            "th" to "ดินเผา"
        ),
        "hue_vivid_yellow" to mapOf(
            "zh-Hant" to "奪目亮黃",
            "en" to "Vivid Yellow",
            "zh-Hans" to "夺目亮黄",
            "ja" to "ビビッドイエロー",
            "ko" to "비비드 옐로",
            "th" to "เหลืองสดใส"
        ),
        "hue_warm_almond" to mapOf(
            "zh-Hant" to "暖杏色",
            "en" to "Warm Almond",
            "zh-Hans" to "暖杏色",
            "ja" to "ウォームアーモンド",
            "ko" to "웜 아몬드",
            "th" to "อัลมอนด์อุ่น"
        ),
        "hw_asr_download_failed" to mapOf(
            "zh-Hant" to "下載失敗：%@",
            "en" to "Download failed: %@",
            "zh-Hans" to "下载失败：%@",
            "ja" to "ダウンロードに失敗しました：%@",
            "ko" to "다운로드 실패: %@",
            "th" to "ดาวน์โหลดไม่สำเร็จ: %@"
        ),
        "hw_asr_download_official" to mapOf(
            "zh-Hant" to "下載 Whisper 端側模型（574 MB）",
            "en" to "Download the on-device Whisper model (574 MB)",
            "zh-Hans" to "下载 Whisper 端侧模型（574 MB）",
            "ja" to "端末内 Whisper モデルをダウンロード（574 MB）",
            "ko" to "기기 내 Whisper 모델 다운로드(574 MB)",
            "th" to "ดาวน์โหลดโมเดล Whisper ในเครื่อง (574 MB)"
        ),
        "hw_asr_explainer" to mapOf(
            "zh-Hant" to "優先使用端側 Whisper 模型（自動偵測 99 種語言、自動標點，全程離線）。沒有模型時會自動改用系統聽寫。",
            "en" to "Prefers the on-device Whisper model (99 languages detected automatically, punctuation restored, fully offline). Falls back to system dictation when no model is present.",
            "zh-Hans" to "优先使用端侧 Whisper 模型（自动检测 99 种语言、自动标点，全程离线）。没有模型时会自动改用系统听写。",
            "ja" to "端末内の Whisper モデルを優先します（99 言語を自動判定、句読点を自動付与、完全オフライン）。モデルが無い場合はシステムの音声入力に切り替わります。",
            "ko" to "기기 내 Whisper 모델을 우선 사용합니다(99개 언어 자동 감지, 문장 부호 자동 복원, 완전 오프라인). 모델이 없으면 시스템 받아쓰기로 전환됩니다.",
            "th" to "ใช้โมเดล Whisper ในเครื่องเป็นหลัก (ตรวจ 99 ภาษาอัตโนมัติ เติมวรรคตอน ทำงานออฟไลน์ทั้งหมด) หากไม่มีโมเดลจะสลับไปใช้การพิมพ์ด้วยเสียงของระบบ"
        ),
        "hw_asr_import_file" to mapOf(
            "zh-Hant" to "從「檔案」匯入離線模型（.bin）",
            "en" to "Import an offline model (.bin) from Files",
            "zh-Hans" to "从「文件」导入离线模型（.bin）",
            "ja" to "「ファイル」からオフラインモデル（.bin）を読み込む",
            "ko" to "“파일”에서 오프라인 모델(.bin) 가져오기",
            "th" to "นำเข้าโมเดลออฟไลน์ (.bin) จาก “ไฟล์”"
        ),
        "hw_asr_model_ready_size" to mapOf(
            "zh-Hant" to "本機神經模型已就緒（574 MB）",
            "en" to "On-device neural model ready (574 MB)",
            "zh-Hans" to "本机神经模型已就绪（574 MB）",
            "ja" to "端末内ニューラルモデル準備完了（574 MB）",
            "ko" to "기기 내 신경망 모델 준비됨(574 MB)",
            "th" to "โมเดลประสาทในเครื่องพร้อม (574 MB)"
        ),
        "hw_asr_no_model" to mapOf(
            "zh-Hant" to "尚未下載模型（改用線上服務）",
            "en" to "No model downloaded (uses the online service)",
            "zh-Hans" to "尚未下载模型（改用在线服务）",
            "ja" to "モデル未ダウンロード（オンラインを使用）",
            "ko" to "모델이 없습니다(온라인 서비스 사용)",
            "th" to "ยังไม่ได้ดาวน์โหลดโมเดล (ใช้บริการออนไลน์)"
        ),
        "hw_asr_onboard" to mapOf(
            "zh-Hant" to "本機神經離線辨識",
            "en" to "On-device neural recognition",
            "zh-Hans" to "本机神经离线识别",
            "ja" to "端末内ニューラル認識",
            "ko" to "기기 내 신경망 인식",
            "th" to "การรู้จำด้วยโครงข่ายประสาทในเครื่อง"
        ),
        "hw_asr_retry_official" to mapOf(
            "zh-Hant" to "重試下載",
            "en" to "Retry the download",
            "zh-Hans" to "重试下载",
            "ja" to "ダウンロードを再試行",
            "ko" to "다운로드 다시 시도",
            "th" to "ลองดาวน์โหลดอีกครั้ง"
        ),
        "hw_asr_system_ready" to mapOf(
            "zh-Hant" to "系統聽寫就緒（免連網）",
            "en" to "System dictation ready (no network needed)",
            "zh-Hans" to "系统听写就绪（免联网）",
            "ja" to "システムの音声入力が利用可能（オフライン）",
            "ko" to "시스템 받아쓰기 준비됨(오프라인)",
            "th" to "การพิมพ์ด้วยเสียงของระบบพร้อม (ไม่ต้องต่อเน็ต)"
        ),
        "hw_asr_system_settings" to mapOf(
            "zh-Hant" to "到系統設定開啟「聽寫」，下載離線語音包",
            "en" to "Open Dictation in System Settings to download the offline language pack",
            "zh-Hans" to "到系统设置开启「听写」，下载离线语音包",
            "ja" to "システム設定で「音声入力」を有効にし、オフライン言語パックをダウンロード",
            "ko" to "시스템 설정에서 “받아쓰기”를 켜고 오프라인 언어 팩을 받으세요",
            "th" to "เปิด “การพิมพ์ด้วยเสียง” ในการตั้งค่าระบบเพื่อดาวน์โหลดแพ็กภาษาออฟไลน์"
        ),
        "hw_asr_unsupported" to mapOf(
            "zh-Hant" to "這台裝置不支援",
            "en" to "Not supported on this device",
            "zh-Hans" to "这台设备不支持",
            "ja" to "この端末では利用できません",
            "ko" to "이 기기에서는 지원되지 않습니다",
            "th" to "อุปกรณ์นี้ไม่รองรับ"
        ),
        "hw_asr_whisper_ready" to mapOf(
            "zh-Hant" to "Whisper 就緒（自動偵測語言）",
            "en" to "Whisper ready (automatic language detection)",
            "zh-Hans" to "Whisper 就绪（自动检测语言）",
            "ja" to "Whisper 準備完了（言語自動判定）",
            "ko" to "Whisper 준비됨(언어 자동 감지)",
            "th" to "Whisper พร้อมใช้งาน (ตรวจภาษาอัตโนมัติ)"
        ),
        "hw_diag_a11y" to mapOf(
            "zh-Hant" to "系統診斷與日誌",
            "en" to "System diagnostics and logs",
            "zh-Hans" to "系统诊断与日志",
            "ja" to "システム診断とログ",
            "ko" to "시스템 진단 및 로그",
            "th" to "การวินิจฉัยระบบและบันทึก"
        ),
        "hw_folder_still_linked" to mapOf(
            "zh-Hant" to "目前仍連著這個同步資料夾：",
            "en" to "This sync folder is still connected:",
            "zh-Hans" to "目前仍连着这个同步文件夹：",
            "ja" to "この同期フォルダはまだ接続されています：",
            "ko" to "이 동기화 폴더가 아직 연결되어 있습니다:",
            "th" to "ยังเชื่อมต่อกับโฟลเดอร์ซิงก์นี้อยู่:"
        ),
        "hw_google_still_signed_in" to mapOf(
            "zh-Hant" to "Google 帳號目前仍是登入狀態：",
            "en" to "This Google account is still signed in:",
            "zh-Hans" to "Google 账号目前仍是登录状态：",
            "ja" to "Google アカウントは現在もサインインしています：",
            "ko" to "Google 계정이 아직 로그인되어 있습니다:",
            "th" to "บัญชี Google ยังลงชื่อเข้าใช้อยู่:"
        ),
        "hw_local_only_explainer" to mapOf(
            "zh-Hant" to "在這個模式下，你的筆記、手寫與錄音只存在這台裝置的沙盒裡，不會有任何網路或雲端傳輸。",
            "en" to "In this mode your notes, handwriting and recordings stay in this device's sandbox. Nothing is sent over the network or to any cloud.",
            "zh-Hans" to "在这个模式下，你的笔记、手写与录音只存在这台设备的沙盒里，不会有任何网络或云端传输。",
            "ja" to "このモードでは、ノート・手書き・録音はこの端末のサンドボックス内にのみ保存され、ネットワークやクラウドへの送信は一切行われません。",
            "ko" to "이 모드에서는 노트·필기·녹음이 이 기기의 샌드박스에만 저장되며 네트워크나 클라우드로 전송되지 않습니다.",
            "th" to "ในโหมดนี้ โน้ต ลายมือ และการบันทึกเสียงจะอยู่ในแซนด์บ็อกซ์ของอุปกรณ์นี้เท่านั้น ไม่มีการส่งผ่านเครือข่ายหรือคลาวด์"
        ),
        "hw_local_only_mode" to mapOf(
            "zh-Hant" to "僅本機",
            "en" to "On this device only",
            "zh-Hans" to "仅本机",
            "ja" to "この端末のみ",
            "ko" to "이 기기에서만",
            "th" to "เฉพาะอุปกรณ์นี้"
        ),
        "hw_local_only_sub" to mapOf(
            "zh-Hant" to "只存在這台裝置（沒有開啟雲端同步）",
            "en" to "Stored on this device only (cloud sync is off)",
            "zh-Hans" to "只存在这台设备（没有开启云端同步）",
            "ja" to "この端末にのみ保存（クラウド同期はオフ）",
            "ko" to "이 기기에만 저장됨(클라우드 동기화 꺼짐)",
            "th" to "เก็บไว้ในอุปกรณ์นี้เท่านั้น (ปิดการซิงก์คลาวด์)"
        ),
        "hw_signing_in" to mapOf(
            "zh-Hant" to "登入中…",
            "en" to "Signing in…",
            "zh-Hans" to "登录中…",
            "ja" to "サインイン中…",
            "ko" to "로그인 중…",
            "th" to "กำลังลงชื่อเข้าใช้…"
        ),
        "hw_sync_choose_service" to mapOf(
            "zh-Hant" to "選擇同步方式",
            "en" to "Choose how to sync",
            "zh-Hans" to "选择同步方式",
            "ja" to "同期方法を選択",
            "ko" to "동기화 방식 선택",
            "th" to "เลือกวิธีซิงก์"
        ),
        "hw_sync_disconnect" to mapOf(
            "zh-Hant" to "中斷同步",
            "en" to "Disconnect",
            "zh-Hans" to "中断同步",
            "ja" to "同期を解除",
            "ko" to "동기화 해제",
            "th" to "ยกเลิกการซิงก์"
        ),
        "hw_sync_gdrive_option" to mapOf(
            "zh-Hant" to "Google Drive（跨平台）",
            "en" to "Google Drive (cross-platform)",
            "zh-Hans" to "Google Drive（跨平台）",
            "ja" to "Google Drive（クロスプラットフォーム）",
            "ko" to "Google Drive(플랫폼 간)",
            "th" to "Google Drive (ข้ามแพลตฟอร์ม)"
        ),
        "hw_sync_how_it_works" to mapOf(
            "zh-Hant" to "同步怎麼運作、跨裝置怎麼連動",
            "en" to "How syncing works across your devices",
            "zh-Hans" to "同步怎么运作、跨设备怎么联动",
            "ja" to "同期の仕組みと端末間の連携",
            "ko" to "동기화 방식과 기기 간 연동",
            "th" to "การซิงก์ทำงานอย่างไรระหว่างอุปกรณ์ของคุณ"
        ),
        "hw_sync_off_option" to mapOf(
            "zh-Hant" to "關閉同步",
            "en" to "Sync off",
            "zh-Hans" to "关闭同步",
            "ja" to "同期しない",
            "ko" to "동기화 끔",
            "th" to "ปิดการซิงก์"
        ),
        "hw_sync_running_folder" to mapOf(
            "zh-Hant" to "iCloud／資料夾同步正在背景執行",
            "en" to "iCloud / folder sync is running in the background",
            "zh-Hans" to "iCloud／文件夹同步正在后台执行",
            "ja" to "iCloud／フォルダ同期をバックグラウンドで実行中",
            "ko" to "iCloud/폴더 동기화가 백그라운드에서 실행 중입니다",
            "th" to "การซิงก์ iCloud / โฟลเดอร์กำลังทำงานเบื้องหลัง"
        ),
        "hw_sync_running_gdrive" to mapOf(
            "zh-Hant" to "Google Drive 同步正在背景執行",
            "en" to "Google Drive sync is running in the background",
            "zh-Hans" to "Google Drive 同步正在后台执行",
            "ja" to "Google Drive 同期をバックグラウンドで実行中",
            "ko" to "Google Drive 동기화가 백그라운드에서 실행 중입니다",
            "th" to "การซิงก์ Google Drive กำลังทำงานเบื้องหลัง"
        ),
        "hw_sync_status" to mapOf(
            "zh-Hant" to "同步狀態",
            "en" to "Sync status",
            "zh-Hans" to "同步状态",
            "ja" to "同期の状態",
            "ko" to "동기화 상태",
            "th" to "สถานะการซิงก์"
        ),
        "hw_system" to mapOf(
            "zh-Hant" to "系統",
            "en" to "System",
            "zh-Hans" to "系统",
            "ja" to "システム",
            "ko" to "시스템",
            "th" to "ระบบ"
        ),
        "hwr_no_model" to mapOf(
            "zh-Hant" to "手寫辨識不支援「%@」",
            "en" to "Handwriting recognition does not support “%@”",
            "zh-Hans" to "手写辨识不支持「%@」",
            "ja" to "手書き認識は「%@」に対応していません",
            "ko" to "필기 인식이 “%@”를 지원하지 않습니다",
            "th" to "การรู้จำลายมือไม่รองรับ “%@”"
        )
    )

    private fun part13(): Map<String, Map<String, String>> = mapOf(
        "identity_color" to mapOf(
            "zh-Hant" to "身分顏色",
            "en" to "Identity Colour",
            "zh-Hans" to "身份颜色",
            "ja" to "表示カラー",
            "ko" to "표시 색상",
            "th" to "สีประจำตัว"
        ),
        "identity_desc" to mapOf(
            "zh-Hant" to "這個名稱與顏色只用於多人協作時顯示「誰在編輯」。它存在這台裝置上，不是帳號，不需要註冊，也不會連到任何雲端或系統帳號。",
            "en" to "This name and colour are only used to show who is editing during collaboration. They live on this device — not an account, no sign-up, and never linked to any cloud or system account.",
            "zh-Hans" to "这个名称与颜色仅用于多人协作时显示“谁在编辑”。它存在这台设备上，不是账号，无需注册，也不会连接任何云端或系统账号。",
            "ja" to "この名前と色は共同編集中に「誰が編集しているか」を示すためだけに使われます。この端末内に保存され、アカウントではなく、登録も不要で、クラウドやシステムアカウントとは一切連携しません。",
            "ko" to "이 이름과 색상은 공동 작업 중 '누가 편집 중인지' 표시하는 데만 사용됩니다. 이 기기에만 저장되며 계정이 아니고 가입도 필요 없으며 클라우드나 시스템 계정과 연결되지 않습니다.",
            "th" to "ชื่อและสีนี้ใช้เพื่อแสดงว่าใครกำลังแก้ไขขณะทำงานร่วมกันเท่านั้น ข้อมูลอยู่ในเครื่องนี้ ไม่ใช่บัญชี ไม่ต้องสมัคร และไม่เชื่อมต่อกับคลาวด์หรือบัญชีระบบใด ๆ"
        ),
        "identity_desc_short" to mapOf(
            "zh-Hant" to "協作時顯示的身分 · 僅存於本機",
            "en" to "Shown while collaborating · stored on this device",
            "zh-Hans" to "协作时显示的身份 · 仅存于本机",
            "ja" to "共同編集時の表示名 · 端末内に保存",
            "ko" to "공동 작업 시 표시 · 이 기기에만 저장",
            "th" to "แสดงขณะทำงานร่วมกัน · เก็บในเครื่องนี้"
        ),
        "identity_preview_hint" to mapOf(
            "zh-Hant" to "協作時其他人看到的樣子",
            "en" to "How others see you while collaborating",
            "zh-Hans" to "协作时其他人看到的样子",
            "ja" to "共同編集中に相手に見える表示",
            "ko" to "공동 작업 중 상대에게 보이는 모습",
            "th" to "สิ่งที่คนอื่นเห็นขณะทำงานร่วมกัน"
        ),
        "identity_title" to mapOf(
            "zh-Hant" to "協作身分",
            "en" to "Collaboration Identity",
            "zh-Hans" to "协作身份",
            "ja" to "共同編集の表示名",
            "ko" to "공동 작업 표시 정보",
            "th" to "ตัวตนสำหรับทำงานร่วมกัน"
        ),
        "image" to mapOf(
            "zh-Hant" to "圖片",
            "en" to "Image",
            "zh-Hans" to "图片",
            "ja" to "画像",
            "ko" to "이미지",
            "th" to "รูปภาพ"
        ),
        "image_beautify" to mapOf(
            "zh-Hant" to "美化圖片",
            "en" to "Beautify Image",
            "zh-Hans" to "美化图片",
            "ja" to "画像を加工",
            "ko" to "이미지 보정",
            "th" to "ตกแต่งรูปภาพ"
        ),
        "image_border" to mapOf(
            "zh-Hant" to "邊框裝飾",
            "en" to "Border",
            "zh-Hans" to "边框装饰",
            "ja" to "フレーム枠線",
            "ko" to "테두리 스타일",
            "th" to "ขอบตกแต่ง"
        ),
        "image_corner_radius" to mapOf(
            "zh-Hant" to "圓角",
            "en" to "Corner radius",
            "zh-Hans" to "圆角",
            "ja" to "角の丸み",
            "ko" to "모서리 둥글기",
            "th" to "ความมนมุม"
        ),
        "image_filter" to mapOf(
            "zh-Hant" to "風格濾鏡",
            "en" to "Style Filter",
            "zh-Hans" to "风格滤镜",
            "ja" to "スタイルフィルター",
            "ko" to "스타일 필터",
            "th" to "ฟิลเตอร์สไตล์"
        ),
        "image_rotate" to mapOf(
            "zh-Hant" to "旋轉",
            "en" to "Rotate",
            "zh-Hans" to "旋转",
            "ja" to "回転",
            "ko" to "회전",
            "th" to "หมุน"
        ),
        "image_rounded" to mapOf(
            "zh-Hant" to "柔和圓角",
            "en" to "Corner Radius",
            "zh-Hans" to "柔和圆角",
            "ja" to "角丸加工",
            "ko" to "부드러운 곡률",
            "th" to "มุมโค้งมน"
        ),
        "image_shadow" to mapOf(
            "zh-Hant" to "立體陰影",
            "en" to "Drop Shadow",
            "zh-Hans" to "立体阴影",
            "ja" to "立体シャドウ",
            "ko" to "입체 그림자",
            "th" to "เงาสามมิติ"
        ),
        "image_style" to mapOf(
            "zh-Hant" to "圖片樣式",
            "en" to "Image style",
            "zh-Hans" to "图片样式",
            "ja" to "画像スタイル",
            "ko" to "이미지 스타일",
            "th" to "สไตล์รูปภาพ"
        ),
        "img_count" to mapOf(
            "zh-Hant" to "圖片",
            "en" to "Images",
            "zh-Hans" to "图片",
            "ja" to "画像",
            "ko" to "이미지",
            "th" to "รูปภาพ"
        ),
        "import_audio_from_files" to mapOf(
            "zh-Hant" to "匯入音訊檔",
            "en" to "Import an audio file",
            "zh-Hans" to "导入音频文件",
            "ja" to "音声ファイルを読み込む",
            "ko" to "오디오 파일 가져오기",
            "th" to "นำเข้าไฟล์เสียง"
        ),
        "import_builtin_shapes" to mapOf(
            "zh-Hant" to "內建形狀",
            "en" to "Built-in shapes",
            "zh-Hans" to "内置形状",
            "ja" to "組み込みの図形",
            "ko" to "기본 도형",
            "th" to "รูปทรงในตัว"
        ),
        "import_document" to mapOf(
            "zh-Hant" to "匯入文件",
            "en" to "Import Document",
            "zh-Hans" to "导入文件",
            "ja" to "ドキュメントをインポート",
            "ko" to "문서 가져오기",
            "th" to "นำเข้าเอกสาร"
        ),
        "import_document_done" to mapOf(
            "zh-Hant" to "已匯入文件到這本筆記",
            "en" to "Document imported into this note",
            "zh-Hans" to "已导入文档到这本笔记",
            "ja" to "ドキュメントをこのノートに取り込みました",
            "ko" to "문서를 이 노트로 가져왔습니다",
            "th" to "นำเข้าเอกสารลงในโน้ตนี้แล้ว"
        ),
        "import_empty_file" to mapOf(
            "zh-Hant" to "這個檔案是空的 —— 它可能還在從雲端下載",
            "en" to "That file is empty — it may still be downloading from your cloud",
            "zh-Hans" to "这个文件是空的 —— 它可能还在从云端下载",
            "ja" to "このファイルは空です —— クラウドからまだダウンロード中かもしれません",
            "ko" to "이 파일은 비어 있습니다 —— 클라우드에서 아직 다운로드 중일 수 있습니다",
            "th" to "ไฟล์นี้ว่างเปล่า —— อาจกำลังดาวน์โหลดจากคลาวด์อยู่"
        ),
        "import_failed" to mapOf(
            "zh-Hant" to "匯入失敗：%@",
            "en" to "Import failed: %@",
            "zh-Hans" to "导入失败：%@",
            "ja" to "読み込みに失敗しました：%@",
            "ko" to "가져오기 실패: %@",
            "th" to "นำเข้าไม่สำเร็จ: %@"
        ),
        "import_failed_read" to mapOf(
            "zh-Hant" to "這個檔案讀不出來",
            "en" to "That file could not be read",
            "zh-Hans" to "这个文件读不出来",
            "ja" to "このファイルは読み込めませんでした",
            "ko" to "이 파일을 읽을 수 없습니다",
            "th" to "อ่านไฟล์นี้ไม่ได้"
        ),
        "import_from_files" to mapOf(
            "zh-Hant" to "從檔案選擇",
            "en" to "Choose from Files",
            "zh-Hans" to "从文件选择",
            "ja" to "ファイルから選択",
            "ko" to "파일에서 선택",
            "th" to "เลือกจากไฟล์"
        ),
        "import_from_photos" to mapOf(
            "zh-Hant" to "從相簿選擇",
            "en" to "Choose from Photos",
            "zh-Hans" to "从相册选择",
            "ja" to "写真から選ぶ",
            "ko" to "사진에서 선택",
            "th" to "เลือกจากรูปภาพ"
        ),
        "import_limit_note" to mapOf(
            "zh-Hant" to "上限 %@ MB —— 插入的東西都會跟著筆記本同步",
            "en" to "Up to %@ MB — everything you insert syncs with the notebook",
            "zh-Hans" to "上限 %@ MB —— 插入的东西都会跟着笔记本同步",
            "ja" to "上限 %@ MB —— 挿入したものはノートと一緒に同期されます",
            "ko" to "최대 %@ MB —— 삽입한 것은 노트와 함께 동기화됩니다",
            "th" to "สูงสุด %@ MB —— สิ่งที่แทรกจะซิงก์ไปพร้อมกับสมุดบันทึก"
        ),
        "import_model_android_note" to mapOf(
            "zh-Hant" to "匯入的模型會跟著筆記本儲存與同步，但這台裝置還畫不出來 —— 目前顯示的是檔名。",
            "en" to "Imported models are stored with the notebook and sync, but this device cannot render them yet — it shows the file name instead.",
            "zh-Hans" to "导入的模型会跟着笔记本储存与同步，但这台设备还画不出来 —— 目前显示的是文件名。",
            "ja" to "読み込んだモデルはノートと共に保存・同期されますが、この端末ではまだ描画できません —— ファイル名を表示しています。",
            "ko" to "가져온 모델은 노트와 함께 저장·동기화되지만 이 기기에서는 아직 그릴 수 없습니다 —— 파일 이름을 표시합니다.",
            "th" to "โมเดลที่นำเข้าจะถูกเก็บและซิงก์ไปกับสมุดบันทึก แต่อุปกรณ์นี้ยังแสดงผลไม่ได้ —— จะแสดงชื่อไฟล์แทน"
        ),
        "import_my_files" to mapOf(
            "zh-Hant" to "我的檔案",
            "en" to "My files",
            "zh-Hans" to "我的文件",
            "ja" to "マイファイル",
            "ko" to "내 파일",
            "th" to "ไฟล์ของฉัน"
        ),
        "import_note" to mapOf(
            "zh-Hant" to "匯入筆記",
            "en" to "Import Note",
            "zh-Hans" to "导入笔记",
            "ja" to "ノートを読み込む",
            "ko" to "노트 가져오기",
            "th" to "นำเข้าสมุดบันทึก"
        ),
        "import_note_desc" to mapOf(
            "zh-Hant" to "將 .padnote 筆記檔匯入至筆記清單",
            "en" to "Import a .padnote file into your library",
            "zh-Hans" to "将 .padnote 文件导入至笔记本列表",
            "ja" to ".padnote ファイルをライブラリに読み込みます",
            "ko" to ".padnote 파일을 보관함으로 가져옵니다",
            "th" to "นำเข้าไฟล์ .padnote เข้าสู่คลังบันทึก"
        ),
        "import_success" to mapOf(
            "zh-Hant" to "已匯入：%@",
            "en" to "Imported: %@",
            "zh-Hans" to "已导入：%@",
            "ja" to "読み込みました：%@",
            "ko" to "가져왔습니다: %@",
            "th" to "นำเข้าแล้ว: %@"
        ),
        "import_too_large" to mapOf(
            "zh-Hant" to "這個檔案太大，同步會很痛苦",
            "en" to "That file is too big to sync comfortably",
            "zh-Hans" to "这个文件太大，同步会很痛苦",
            "ja" to "このファイルは大きすぎて同期に支障が出ます",
            "ko" to "이 파일은 너무 커서 동기화에 부담이 됩니다",
            "th" to "ไฟล์นี้ใหญ่เกินไปสำหรับการซิงก์"
        ),
        "import_unsupported_type" to mapOf(
            "zh-Hant" to "這種檔案不能放進這裡",
            "en" to "This kind of file can't go here",
            "zh-Hans" to "这种文件不能放进这里",
            "ja" to "この種類のファイルはここに入れられません",
            "ko" to "이 종류의 파일은 여기에 넣을 수 없습니다",
            "th" to "ไฟล์ชนิดนี้ใส่ตรงนี้ไม่ได้"
        ),
        "ink_change_colour" to mapOf(
            "zh-Hant" to "換色",
            "en" to "Change colour",
            "zh-Hans" to "换色",
            "ja" to "色を変更",
            "ko" to "색 변경",
            "th" to "เปลี่ยนสี"
        ),
        "ink_clear" to mapOf(
            "zh-Hant" to "清除",
            "en" to "Clear",
            "zh-Hans" to "清除",
            "ja" to "消去",
            "ko" to "지우기",
            "th" to "ล้าง"
        ),
        "ink_input_debug" to mapOf(
            "zh-Hant" to "顯示輸入診斷",
            "en" to "Show input diagnostics",
            "zh-Hans" to "显示输入诊断",
            "ja" to "入力診断を表示",
            "ko" to "입력 진단 표시",
            "th" to "แสดงการวินิจฉัยอินพุต"
        ),
        "ink_latency_label" to mapOf(
            "zh-Hant" to "輸入延遲",
            "en" to "Input latency",
            "zh-Hans" to "输入延迟",
            "ja" to "入力遅延",
            "ko" to "입력 지연",
            "th" to "ความหน่วงอินพุต"
        ),
        "ink_low_latency" to mapOf(
            "zh-Hant" to "低延遲",
            "en" to "Low Latency",
            "zh-Hans" to "低延迟",
            "ja" to "低遅延",
            "ko" to "저지연",
            "th" to "หน่วงต่ำ"
        ),
        "ink_low_latency_unavailable" to mapOf(
            "zh-Hant" to "這台裝置不支援前緩衝渲染，已改用一般畫布",
            "en" to "Front-buffered rendering is unavailable on this device; using the standard canvas",
            "zh-Hans" to "这台设备不支持前缓冲渲染，已改用一般画布",
            "ja" to "この端末はフロントバッファ描画に対応していないため、通常のキャンバスを使用します",
            "ko" to "이 기기는 프런트 버퍼 렌더링을 지원하지 않아 일반 캔버스를 사용합니다",
            "th" to "อุปกรณ์นี้ไม่รองรับการเรนเดอร์แบบ front-buffer จึงใช้ผืนผ้าใบมาตรฐานแทน"
        ),
        "ink_pen_only" to mapOf(
            "zh-Hant" to "僅限觸控筆",
            "en" to "Stylus Only",
            "zh-Hans" to "仅限触控笔",
            "ja" to "スタイラスのみ",
            "ko" to "스타일러스 전용",
            "th" to "ปากกาสไตลัสเท่านั้น"
        ),
        "ink_pro_wheel" to mapOf(
            "zh-Hant" to "專業 HSV 色環與和諧配色",
            "en" to "Pro HSV wheel and colour harmonies",
            "zh-Hans" to "专业 HSV 色环与和谐配色",
            "ja" to "プロ向け HSV ホイールと配色",
            "ko" to "전문가용 HSV 휠과 색 조화",
            "th" to "วงล้อ HSV ระดับโปรและชุดสีที่เข้ากัน"
        ),
        "ink_stroke_count" to mapOf(
            "zh-Hant" to "%@ 筆",
            "en" to "%@ strokes",
            "zh-Hans" to "%@ 笔",
            "ja" to "%@ ストローク",
            "ko" to "%@획",
            "th" to "%@ เส้น"
        ),
        "ink_write_here" to mapOf(
            "zh-Hant" to "在這裡書寫",
            "en" to "Write here",
            "zh-Hans" to "在这里书写",
            "ja" to "ここに書いてください",
            "ko" to "여기에 쓰세요",
            "th" to "เขียนที่นี่"
        ),
        "input_diagnostics" to mapOf(
            "zh-Hant" to "輸入診斷",
            "en" to "Input Diagnostics",
            "zh-Hans" to "输入诊断",
            "ja" to "入力診断",
            "ko" to "입력 진단",
            "th" to "การวินิจฉัยอินพุต"
        ),
        "input_diagnostics_explainer" to mapOf(
            "zh-Hant" to "量到的是「事件在硬體上發生 → 交給畫面」，不是筆尖到光子（面板的掃描時間量不到）。它的用途是同一台裝置上開關某個選項的前後對比。",
            "en" to "Measures hardware event time to frame delivery — not pen-to-photon (panel scan time cannot be measured here). Use it to compare before and after toggling a setting on the same device.",
            "zh-Hans" to "测量的是「事件在硬件上发生 → 交给画面」，不是笔尖到光子（面板扫描时间测不到）。用途是同一台设备上开关某个选项的前后对比。",
            "ja" to "計測するのは「ハードウェアでのイベント発生 → 画面への引き渡し」で、ペン先から発光までではありません（パネルの走査時間は計測できません）。同一端末で設定を切り替えた前後の比較に使います。",
            "ko" to "하드웨어 이벤트 발생부터 화면 전달까지를 측정합니다. 펜 끝에서 빛까지가 아닙니다(패널 주사 시간은 측정 불가). 같은 기기에서 설정을 켜고 끈 전후 비교에 사용하세요.",
            "th" to "วัดจากเวลาที่เหตุการณ์เกิดขึ้นในฮาร์ดแวร์จนถึงการส่งเฟรม ไม่ใช่จากปลายปากกาถึงแสง (วัดเวลาสแกนหน้าจอไม่ได้) ใช้เปรียบเทียบก่อนและหลังเปิดปิดการตั้งค่าบนเครื่องเดียวกัน"
        ),
        "insert" to mapOf(
            "zh-Hant" to "插入",
            "en" to "Insert",
            "zh-Hans" to "插入",
            "ja" to "挿入",
            "ko" to "삽입",
            "th" to "แทรก"
        ),
        "insert_3d" to mapOf(
            "zh-Hant" to "插入3D模型",
            "en" to "Insert 3D Model",
            "zh-Hans" to "插入3D模型",
            "ja" to "3Dモデルを挿入",
            "ko" to "3D 모델 삽입",
            "th" to "แทรกโมเดล 3 มิติ"
        ),
        "insert_audio" to mapOf(
            "zh-Hant" to "插入錄音",
            "en" to "Insert Recording",
            "zh-Hans" to "插入录音",
            "ja" to "録音を挿入",
            "ko" to "녹음 삽입",
            "th" to "แทรกเสียงที่บันทึก"
        ),
        "insert_audio_page" to mapOf(
            "zh-Hant" to "插入到第幾頁",
            "en" to "Page to insert on",
            "zh-Hans" to "插入到第几页",
            "ja" to "挿入するページ",
            "ko" to "삽입할 페이지",
            "th" to "หน้าที่จะแทรก"
        ),
        "insert_chart" to mapOf(
            "zh-Hant" to "插入圖表至筆記",
            "en" to "Insert Chart to Note",
            "zh-Hans" to "插入图表至笔记",
            "ja" to "ノートにグラフを挿入",
            "ko" to "노트에 차트 삽입",
            "th" to "แทรกแผนภูมิในบันทึก"
        ),
        "insert_image" to mapOf(
            "zh-Hant" to "插入圖片",
            "en" to "Insert Image",
            "zh-Hans" to "插入图片",
            "ja" to "画像を挿入",
            "ko" to "이미지 삽입",
            "th" to "แทรกรูปภาพ"
        ),
        "insert_link" to mapOf(
            "zh-Hant" to "插入連結",
            "en" to "Insert Link",
            "zh-Hans" to "插入链接",
            "ja" to "リンク挿入",
            "ko" to "링크 삽입",
            "th" to "แทรกลิงก์"
        ),
        "insert_needs_canvas" to mapOf(
            "zh-Hant" to "請先切到手寫模式 —— 這個東西是貼在畫布上的",
            "en" to "Switch to drawing mode first — that is where this goes",
            "zh-Hans" to "请先切到手写模式 —— 这个东西是贴在画布上的",
            "ja" to "先に手書きモードに切り替えてください —— これはキャンバスに貼られます",
            "ko" to "먼저 필기 모드로 전환하세요 —— 이것은 캔버스에 붙습니다",
            "th" to "สลับไปโหมดเขียนก่อน —— สิ่งนี้วางบนผืนผ้าใบ"
        ),
        "insert_object" to mapOf(
            "zh-Hant" to "插入",
            "en" to "Insert",
            "zh-Hans" to "插入",
            "ja" to "挿入",
            "ko" to "삽입",
            "th" to "แทรก"
        ),
        "insert_page_after" to mapOf(
            "zh-Hant" to "在後方插入新頁面",
            "en" to "Insert Page After",
            "zh-Hans" to "在后方插入新页面",
            "ja" to "後ろに新規ページを挿入",
            "ko" to "뒤에 새 페이지 삽입",
            "th" to "แทรกหน้าใหม่หลังจากนี้"
        ),
        "insert_page_with_template" to mapOf(
            "zh-Hant" to "插入其他樣板頁面…",
            "en" to "Insert Page with Template…",
            "zh-Hans" to "插入其他样板页面…",
            "ja" to "テンプレートを選んでページを挿入…",
            "ko" to "템플릿을 골라 페이지 삽입…",
            "th" to "แทรกหน้าด้วยเทมเพลต…"
        ),
        "insert_pdf" to mapOf(
            "zh-Hant" to "插入 PDF 頁面",
            "en" to "Insert PDF Page",
            "zh-Hans" to "插入 PDF 页面",
            "ja" to "PDF ページを挿入",
            "ko" to "PDF 페이지 삽입",
            "th" to "แทรกหน้า PDF"
        ),
        "insert_swatch" to mapOf(
            "zh-Hant" to "插入色票卡",
            "en" to "Insert Color Swatch",
            "zh-Hans" to "插入色票卡",
            "ja" to "スウォッチカードを挿入",
            "ko" to "색상 견본 카드 삽입",
            "th" to "แทรกการ์ดตัวอย่างสี"
        ),
        "insert_text_box" to mapOf(
            "zh-Hant" to "插入文字方塊",
            "en" to "Insert Text Box",
            "zh-Hans" to "插入文本框",
            "ja" to "テキストボックスを挿入",
            "ko" to "텍스트 상자 삽입",
            "th" to "แทรกกล่องข้อความ"
        ),
        "insert_text_box_hint" to mapOf(
            "zh-Hant" to "點兩下畫布空白處新增文字方塊",
            "en" to "Double-tap empty canvas to add a text box",
            "zh-Hans" to "双击画布空白处新增文字方块",
            "ja" to "空白部分をダブルタップでテキストボックスを追加",
            "ko" to "빈 캔버스를 두 번 탭하면 텍스트 상자 추가",
            "th" to "แตะสองครั้งบนพื้นที่ว่างเพื่อเพิ่มกล่องข้อความ"
        ),
        "insert_to_canvas" to mapOf(
            "zh-Hant" to "插入至目前畫布",
            "en" to "Insert to Canvas",
            "zh-Hans" to "插入至当前画布",
            "ja" to "キャンバスに挿入",
            "ko" to "캔버스에 삽입",
            "th" to "แทรกลงในผืนผ้าใบ"
        ),
        "insert_to_notebook" to mapOf(
            "zh-Hant" to "插入至筆記本",
            "en" to "Insert into Notebook",
            "zh-Hans" to "插入至笔记本",
            "ja" to "ノートに挿入",
            "ko" to "노트에 삽입",
            "th" to "แทรกลงในสมุดบันทึก"
        ),
        "insert_vertical_space" to mapOf(
            "zh-Hant" to "插入空白區域",
            "en" to "Insert Space",
            "zh-Hans" to "插入空白区域",
            "ja" to "スペースを挿入",
            "ko" to "공백 삽입",
            "th" to "แทรกช่องว่าง"
        ),
        "interaction_arrow" to mapOf(
            "zh-Hant" to "手勢流程跳轉",
            "en" to "Interaction Flows",
            "zh-Hans" to "手势流程跳转",
            "ja" to "遷移フロー",
            "ko" to "인터랙션 플로우",
            "th" to "ผังกระบวนการ"
        ),
        "interaction_flow_tip" to mapOf(
            "zh-Hant" to "標示使用者點擊與滑動流向",
            "en" to "Mark user tap & interaction flow directions",
            "zh-Hans" to "标示用户点击与滑动流向",
            "ja" to "タップやスワイプの操作フローを指示",
            "ko" to "사용자 탭 및 인터랙션 흐름 표시",
            "th" to "ระบุทิศทางการแตะและการโต้ตอบของผู้ใช้"
        ),
        "invalid_folder_padnote" to mapOf(
            "zh-Hant" to "請選擇同步目錄的根資料夾，不可選擇單本 .padnote 筆記包。",
            "en" to "Please choose a root folder, not a .padnote file.",
            "zh-Hans" to "请选择同步目录的根文件夹，不可选择单本 .padnote 笔记包。",
            "ja" to "ルートフォルダを選択してください。.padnote ファイルではありません。",
            "ko" to ".padnote 파일이 아닌 루트 폴더를 선택하십시오.",
            "th" to "โปรดเลือกโฟลเดอร์หลัก ไม่ใช่ไฟล์ .padnote"
        ),
        "invalid_server" to mapOf(
            "zh-Hant" to "這個中繼位址無法使用。",
            "en" to "That relay address can't be used.",
            "zh-Hans" to "这个中继位址无法使用。",
            "ja" to "その中継サーバーのアドレスは使えません。",
            "ko" to "그 중계 서버 주소는 사용할 수 없습니다.",
            "th" to "ใช้ที่อยู่รีเลย์นี้ไม่ได้"
        ),
        "join_room" to mapOf(
            "zh-Hant" to "加入協同房間",
            "en" to "Join Room",
            "zh-Hans" to "加入协同房间",
            "ja" to "ルームに参加",
            "ko" to "방 참가",
            "th" to "เข้าร่วมห้อง"
        ),
        "keep_border" to mapOf(
            "zh-Hant" to "保留邊框",
            "en" to "Keep Border",
            "zh-Hans" to "保留边框",
            "ja" to "枠線を維持",
            "ko" to "테두리 유지",
            "th" to "เก็บเส้นขอบ"
        ),
        "kit_create" to mapOf(
            "zh-Hant" to "建立套件",
            "en" to "Create kit",
            "zh-Hans" to "创建套件",
            "ja" to "セットを作成",
            "ko" to "세트 만들기",
            "th" to "สร้างชุด"
        ),
        "kit_created" to mapOf(
            "zh-Hant" to "套件已建立",
            "en" to "Kit created",
            "zh-Hans" to "套件已创建",
            "ja" to "セットを作成しました",
            "ko" to "세트를 만들었습니다",
            "th" to "สร้างชุดแล้ว"
        ),
        "kit_drafting" to mapOf(
            "zh-Hant" to "圖學套件",
            "en" to "Engineering Drawing Kit",
            "zh-Hans" to "图学套件",
            "ja" to "製図セット",
            "ko" to "공학 도면 세트",
            "th" to "ชุดวิชาเขียนแบบ"
        ),
        "kit_drafting_class" to mapOf(
            "zh-Hant" to "圖學－課堂筆記",
            "en" to "Drafting – Class Notes",
            "zh-Hans" to "图学－课堂笔记",
            "ja" to "製図－授業ノート",
            "ko" to "도면 – 수업 노트",
            "th" to "เขียนแบบ – จดบทเรียน"
        ),
        "kit_drafting_desc" to mapOf(
            "zh-Hant" to "課堂筆記、作圖練習、錯誤陷阱本，並備好圖學筆組",
            "en" to "Class notes, drawing practice and a mistake-trap book, with the drafting pens ready",
            "zh-Hans" to "课堂笔记、作图练习、错误陷阱本，并备好图学笔组",
            "ja" to "授業ノート・作図練習・ミス集をまとめて作成",
            "ko" to "수업 노트, 작도 연습, 오답 함정 노트를 한 번에",
            "th" to "สมุดจดบทเรียน ฝึกวาด และสมุดกับดัก พร้อมชุดปากกาเขียนแบบ"
        ),
        "kit_drafting_practice" to mapOf(
            "zh-Hant" to "圖學－作圖練習",
            "en" to "Drafting – Drawing Practice",
            "zh-Hans" to "图学－作图练习",
            "ja" to "製図－作図練習",
            "ko" to "도면 – 작도 연습",
            "th" to "เขียนแบบ – ฝึกวาด"
        ),
        "kit_drafting_trap" to mapOf(
            "zh-Hant" to "圖學－錯誤陷阱本",
            "en" to "Drafting – Mistake Traps",
            "zh-Hans" to "图学－错误陷阱本",
            "ja" to "製図－ミスの落とし穴",
            "ko" to "도면 – 오답 함정",
            "th" to "เขียนแบบ – กับดักข้อผิดพลาด"
        ),
        "language" to mapOf(
            "zh-Hant" to "介面語系",
            "en" to "Language",
            "zh-Hans" to "界面语言",
            "ja" to "表示言語",
            "ko" to "인터페이스 언어",
            "th" to "ภาษาของอินเทอร์เฟซ"
        ),
        "lasso_active_hint" to mapOf(
            "zh-Hant" to "已圈選筆劃：可拖曳移動，或點擊刪除 / 剪下 / 複製",
            "en" to "Strokes Selected: Drag to move, or tap Delete / Cut / Copy",
            "zh-Hans" to "已圈选笔画：可拖曳移动，或点击删除 / 剪切 / 复制",
            "ja" to "ストローク選択中：ドラッグで移動、または削除/切り取り/コピー",
            "ko" to "획 선택됨: 드래그하여 이동 또는 삭제/잘라내기/복사",
            "th" to "เลือกลายเส้นแล้ว: ลากเพื่อย้าย หรือแตะลบ / ตัด / คัดลอก"
        ),
        "layer_bring_forward" to mapOf(
            "zh-Hant" to "上移一層",
            "en" to "Bring Forward",
            "zh-Hans" to "上移一层",
            "ja" to "前面へ",
            "ko" to "앞으로",
            "th" to "เลื่อนขึ้น"
        ),
        "layer_bring_forward_desc" to mapOf(
            "zh-Hant" to "將選取的物件向上移動一層",
            "en" to "Bring selected object one layer forward",
            "zh-Hans" to "将选中的物件向上移动一层",
            "ja" to "選択したオブジェクトを前面へ移動",
            "ko" to "선택한 개체를 한 단계 앞으로 가져오기",
            "th" to "เลื่อนวัตถุที่เลือกขึ้นหนึ่งชั้น"
        ),
        "layer_bring_front" to mapOf(
            "zh-Hant" to "移到最上層",
            "en" to "Bring to Front",
            "zh-Hans" to "移到最上层",
            "ja" to "最前面へ",
            "ko" to "맨 앞으로",
            "th" to "ไปหน้าสุด"
        )
    )

    private fun part14(): Map<String, Map<String, String>> = mapOf(
        "layer_group" to mapOf(
            "zh-Hant" to "群組",
            "en" to "Group",
            "zh-Hans" to "组合",
            "ja" to "グループ化",
            "ko" to "그룹",
            "th" to "จัดกลุ่ม"
        ),
        "layer_group_name" to mapOf(
            "zh-Hant" to "群組（%@ 個物件）",
            "en" to "Group (%@ objects)",
            "zh-Hans" to "组合（%@ 个对象）",
            "ja" to "グループ（%@ 個）",
            "ko" to "그룹(%@개)",
            "th" to "กลุ่ม (%@ รายการ)"
        ),
        "layer_kind_audio" to mapOf(
            "zh-Hant" to "錄音",
            "en" to "Recording",
            "zh-Hans" to "录音",
            "ja" to "録音",
            "ko" to "녹음",
            "th" to "เสียงที่บันทึก"
        ),
        "layer_kind_image" to mapOf(
            "zh-Hant" to "圖片",
            "en" to "Image",
            "zh-Hans" to "图片",
            "ja" to "画像",
            "ko" to "이미지",
            "th" to "รูปภาพ"
        ),
        "layer_kind_link" to mapOf(
            "zh-Hant" to "連結卡片",
            "en" to "Link card",
            "zh-Hans" to "链接卡片",
            "ja" to "リンクカード",
            "ko" to "링크 카드",
            "th" to "การ์ดลิงก์"
        ),
        "layer_kind_model3d" to mapOf(
            "zh-Hant" to "3D 模型",
            "en" to "3D model",
            "zh-Hans" to "3D 模型",
            "ja" to "3D モデル",
            "ko" to "3D 모델",
            "th" to "โมเดล 3 มิติ"
        ),
        "layer_kind_pin" to mapOf(
            "zh-Hant" to "討論圖釘",
            "en" to "Comment pin",
            "zh-Hans" to "讨论图钉",
            "ja" to "コメントピン",
            "ko" to "댓글 핀",
            "th" to "หมุดความคิดเห็น"
        ),
        "layer_kind_shape" to mapOf(
            "zh-Hant" to "形狀",
            "en" to "Shape",
            "zh-Hans" to "形状",
            "ja" to "図形",
            "ko" to "도형",
            "th" to "รูปทรง"
        ),
        "layer_kind_table" to mapOf(
            "zh-Hant" to "表格",
            "en" to "Table",
            "zh-Hans" to "表格",
            "ja" to "表",
            "ko" to "표",
            "th" to "ตาราง"
        ),
        "layer_kind_text" to mapOf(
            "zh-Hant" to "文字方塊",
            "en" to "Text box",
            "zh-Hans" to "文字方块",
            "ja" to "テキストボックス",
            "ko" to "텍스트 상자",
            "th" to "กล่องข้อความ"
        ),
        "layer_select_two" to mapOf(
            "zh-Hant" to "選兩個以上的物件才能群組",
            "en" to "Select two or more objects to group",
            "zh-Hans" to "选两个以上的对象才能组合",
            "ja" to "2 つ以上選ぶとグループ化できます",
            "ko" to "두 개 이상 선택해야 그룹으로 묶을 수 있습니다",
            "th" to "เลือกตั้งแต่สองรายการขึ้นไปจึงจะจัดกลุ่มได้"
        ),
        "layer_send_back" to mapOf(
            "zh-Hant" to "移到最下層",
            "en" to "Send to Back",
            "zh-Hans" to "移到最下层",
            "ja" to "最背面へ",
            "ko" to "맨 뒤로",
            "th" to "ไปหลังสุด"
        ),
        "layer_send_backward" to mapOf(
            "zh-Hant" to "下移一層",
            "en" to "Send Backward",
            "zh-Hans" to "下移一层",
            "ja" to "背面へ",
            "ko" to "뒤로",
            "th" to "เลื่อนลง"
        ),
        "layer_send_backward_desc" to mapOf(
            "zh-Hant" to "將選取的物件向下移動一層",
            "en" to "Send selected object one layer backward",
            "zh-Hans" to "将选中的物件向下移动一层",
            "ja" to "選択したオブジェクトを背面へ移動",
            "ko" to "선택한 개체를 한 단계 뒤로 보내기",
            "th" to "เลื่อนวัตถุที่เลือกลงหนึ่งชั้น"
        ),
        "layer_ungroup" to mapOf(
            "zh-Hant" to "解散群組",
            "en" to "Ungroup",
            "zh-Hans" to "取消组合",
            "ja" to "グループ解除",
            "ko" to "그룹 해제",
            "th" to "ยกเลิกกลุ่ม"
        ),
        "layer_unnamed" to mapOf(
            "zh-Hant" to "未命名形狀",
            "en" to "Untitled shape",
            "zh-Hans" to "未命名形状",
            "ja" to "名称未設定の図形",
            "ko" to "이름 없는 도형",
            "th" to "รูปร่างไม่มีชื่อ"
        ),
        "layers_empty" to mapOf(
            "zh-Hant" to "這一頁還沒有形狀",
            "en" to "No shapes on this page yet",
            "zh-Hans" to "这一页还没有形状",
            "ja" to "このページにはまだ図形がありません",
            "ko" to "이 페이지에는 아직 도형이 없습니다",
            "th" to "ยังไม่มีรูปร่างในหน้านี้"
        ),
        "layers_hint" to mapOf(
            "zh-Hant" to "清單由上到下＝由前到後",
            "en" to "Top of the list is in front",
            "zh-Hans" to "列表由上到下＝由前到后",
            "ja" to "リストの上が手前です",
            "ko" to "목록 위쪽이 앞입니다",
            "th" to "รายการด้านบนคือด้านหน้า"
        ),
        "layers_panel" to mapOf(
            "zh-Hant" to "圖層",
            "en" to "Layers",
            "zh-Hans" to "图层",
            "ja" to "レイヤー",
            "ko" to "레이어",
            "th" to "เลเยอร์"
        ),
        "line_endpoint_handle" to mapOf(
            "zh-Hant" to "拖曳端點",
            "en" to "Drag endpoint",
            "zh-Hans" to "拖动端点",
            "ja" to "端点をドラッグ",
            "ko" to "끝점 드래그",
            "th" to "ลากปลายเส้น"
        ),
        "line_spacing" to mapOf(
            "zh-Hant" to "行距",
            "en" to "Line",
            "zh-Hans" to "行距",
            "ja" to "行間",
            "ko" to "줄 간격",
            "th" to "ระยะบรรทัด"
        ),
        "line_width" to mapOf(
            "zh-Hant" to "線條粗細",
            "en" to "Line width",
            "zh-Hans" to "线条粗细",
            "ja" to "線の太さ",
            "ko" to "선 두께",
            "th" to "ความหนาเส้น"
        ),
        "link_description" to mapOf(
            "zh-Hant" to "說明",
            "en" to "Description",
            "zh-Hans" to "说明",
            "ja" to "説明",
            "ko" to "설명",
            "th" to "คำอธิบาย"
        ),
        "link_edit" to mapOf(
            "zh-Hant" to "編修連結",
            "en" to "Edit Link",
            "zh-Hans" to "编修链接",
            "ja" to "リンクを編集",
            "ko" to "링크 편집",
            "th" to "แก้ไขลิงก์"
        ),
        "link_fetching" to mapOf(
            "zh-Hant" to "正在讀取網頁…",
            "en" to "Reading the page…",
            "zh-Hans" to "正在读取网页…",
            "ja" to "ページを読み込み中…",
            "ko" to "페이지를 읽는 중…",
            "th" to "กำลังอ่านหน้าเว็บ…"
        ),
        "link_preview" to mapOf(
            "zh-Hant" to "網頁預覽",
            "en" to "Link Preview",
            "zh-Hans" to "网页预览",
            "ja" to "リンクプレビュー",
            "ko" to "링크 미리보기",
            "th" to "ดูตัวอย่างลิงก์"
        ),
        "link_preview_hint" to mapOf(
            "zh-Hant" to "輸入網址後點選「解析預覽」以產生卡片",
            "en" to "Enter a URL, then tap Preview to build the card",
            "zh-Hans" to "输入网址后点选「解析预览」以生成卡片",
            "ja" to "URL を入力して「プレビュー」を押すとカードを作成します",
            "ko" to "URL을 입력한 뒤 ‘미리보기’를 누르면 카드가 만들어집니다",
            "th" to "ป้อน URL แล้วแตะ ‘ดูตัวอย่าง’ เพื่อสร้างการ์ด"
        ),
        "link_preview_insert" to mapOf(
            "zh-Hant" to "將連結預覽卡片插入筆記",
            "en" to "Insert the link card into the note",
            "zh-Hans" to "将链接预览卡片插入笔记",
            "ja" to "リンクカードをノートに挿入",
            "ko" to "링크 카드를 노트에 삽입",
            "th" to "แทรกการ์ดลิงก์ลงในบันทึก"
        ),
        "link_site_name" to mapOf(
            "zh-Hant" to "站台名稱",
            "en" to "Site name",
            "zh-Hans" to "站点名称",
            "ja" to "サイト名",
            "ko" to "사이트 이름",
            "th" to "ชื่อเว็บไซต์"
        ),
        "link_title" to mapOf(
            "zh-Hant" to "標題",
            "en" to "Title",
            "zh-Hans" to "标题",
            "ja" to "タイトル",
            "ko" to "제목",
            "th" to "ชื่อเรื่อง"
        ),
        "link_url_hint" to mapOf(
            "zh-Hant" to "貼上網址",
            "en" to "Paste a link",
            "zh-Hans" to "粘贴网址",
            "ja" to "リンクを貼り付け",
            "ko" to "링크 붙여넣기",
            "th" to "วางลิงก์"
        ),
        "llm_no_response" to mapOf(
            "zh-Hant" to "沒有回應",
            "en" to "No response",
            "zh-Hans" to "没有回应",
            "ja" to "応答がありません",
            "ko" to "응답이 없습니다",
            "th" to "ไม่มีการตอบกลับ"
        ),
        "local_relay_failed" to mapOf(
            "zh-Hant" to "這台裝置開不成房間：%@。請改用別台裝置發起，或填入一個中繼位址。",
            "en" to "This device could not host the room: %@. Start the session from another device, or enter a relay address.",
            "zh-Hans" to "这台设备开不成房间：%@。请改用别台设备发起，或填入一个中继地址。",
            "ja" to "この端末ではルームを開けませんでした：%@。別の端末から開始するか、中継アドレスを入力してください。",
            "ko" to "이 기기에서는 방을 열지 못했습니다: %@. 다른 기기에서 시작하거나 중계 주소를 입력하세요.",
            "th" to "อุปกรณ์นี้เปิดห้องไม่ได้: %@ ให้เริ่มจากอุปกรณ์อื่น หรือกรอกที่อยู่รีเลย์"
        ),
        "local_relay_hint" to mapOf(
            "zh-Hant" to "位址指向 127.0.0.1 時，App 會直接在這台裝置上開啟協同中繼；同一網路的隊友請改填房主畫面顯示的區域網路位址。",
            "en" to "Pointing at 127.0.0.1 makes this device host the relay; teammates on the same network enter the local address shown on the host's screen.",
            "zh-Hans" to "地址指向 127.0.0.1 时，App 会直接在这台设备上开启协作中继；同一网络的队友请改填房主画面显示的局域网地址。",
            "ja" to "127.0.0.1 を指している間はこの端末が中継を担当します。同じネットワークの参加者はホスト画面に表示されたローカルアドレスを入力してください。",
            "ko" to "127.0.0.1 을 가리키는 동안에는 이 기기가 중계를 맡습니다. 같은 네트워크의 참여자는 호스트 화면에 표시된 로컬 주소를 입력하세요.",
            "th" to "เมื่อชี้ไปที่ 127.0.0.1 เครื่องนี้จะทำหน้าที่รีเลย์เอง ผู้ร่วมงานในเครือข่ายเดียวกันให้กรอกที่อยู่ในเครือข่ายที่แสดงบนหน้าจอผู้เปิดห้อง"
        ),
        "log_clear" to mapOf(
            "zh-Hant" to "清除",
            "en" to "Clear",
            "zh-Hans" to "清除",
            "ja" to "消去",
            "ko" to "지우기",
            "th" to "ล้าง"
        ),
        "log_copied" to mapOf(
            "zh-Hant" to "已複製",
            "en" to "Copied",
            "zh-Hans" to "已复制",
            "ja" to "コピーしました",
            "ko" to "복사됨",
            "th" to "คัดลอกแล้ว"
        ),
        "log_copy" to mapOf(
            "zh-Hant" to "複製日誌",
            "en" to "Copy Logs",
            "zh-Hans" to "复制日志",
            "ja" to "ログをコピー",
            "ko" to "로그 복사",
            "th" to "คัดลอกบันทึก"
        ),
        "log_empty" to mapOf(
            "zh-Hant" to "尚無日誌紀錄",
            "en" to "No logs recorded",
            "zh-Hans" to "尚无日志记录",
            "ja" to "ログの記録はありません",
            "ko" to "기록된 로그가 없습니다",
            "th" to "ไม่มีบันทึกข้อมูล"
        ),
        "log_export" to mapOf(
            "zh-Hant" to "匯出日誌",
            "en" to "Export Logs",
            "zh-Hans" to "导出日志",
            "ja" to "ログをエクスポート",
            "ko" to "로그 내보내기",
            "th" to "ส่งออกบันทึก"
        ),
        "log_filter" to mapOf(
            "zh-Hant" to "日誌篩選",
            "en" to "Filter Logs",
            "zh-Hans" to "日志筛选",
            "ja" to "ログの絞り込み",
            "ko" to "로그 필터",
            "th" to "ตัวกรองบันทึก"
        ),
        "log_filter_all" to mapOf(
            "zh-Hant" to "全部",
            "en" to "All",
            "zh-Hans" to "全部",
            "ja" to "すべて",
            "ko" to "전체",
            "th" to "ทั้งหมด"
        ),
        "log_filter_current" to mapOf(
            "zh-Hant" to "當前分頁",
            "en" to "Current Tab",
            "zh-Hans" to "当前标签",
            "ja" to "現在のタブ",
            "ko" to "현재 탭",
            "th" to "แท็บปัจจุบัน"
        ),
        "log_msg_001" to mapOf(
            "zh-Hant" to "Google 帳號授權成功！已儲存憑證。",
            "en" to "Google account authorized. Credentials saved.",
            "zh-Hans" to "Google 账号授权成功！已储存凭据。",
            "ja" to "Google アカウントの認証に成功しました。認証情報を保存しました。",
            "ko" to "Google 계정 인증에 성공했습니다. 자격 증명을 저장했습니다.",
            "th" to "อนุญาตบัญชี Google สำเร็จ บันทึกข้อมูลรับรองแล้ว"
        ),
        "log_msg_002" to mapOf(
            "zh-Hant" to "Google 授權取消或失敗：%1@",
            "en" to "Google authorization was cancelled or failed: %1@",
            "zh-Hans" to "Google 授权取消或失败：%1@",
            "ja" to "Google の認証がキャンセルされたか失敗しました: %1@",
            "ko" to "Google 인증이 취소되었거나 실패했습니다: %1@",
            "th" to "การอนุญาต Google ถูกยกเลิกหรือล้มเหลว: %1@"
        ),
        "log_msg_003" to mapOf(
            "zh-Hant" to "Google 授權失敗：缺少 Code 或 Verifier",
            "en" to "Google authorization failed: missing Code or Verifier",
            "zh-Hans" to "Google 授权失败：缺少 Code 或 Verifier",
            "ja" to "Google の認証に失敗しました: Code または Verifier がありません",
            "ko" to "Google 인증 실패: Code 또는 Verifier가 없습니다",
            "th" to "การอนุญาต Google ล้มเหลว: ไม่มี Code หรือ Verifier"
        ),
        "log_msg_004" to mapOf(
            "zh-Hant" to "Google 授權驗證失敗：State 不符合",
            "en" to "Google authorization check failed: State mismatch",
            "zh-Hans" to "Google 授权验证失败：State 不符合",
            "ja" to "Google の認証の検証に失敗しました: State が一致しません",
            "ko" to "Google 인증 검증 실패: State가 일치하지 않습니다",
            "th" to "ตรวจสอบการอนุญาต Google ล้มเหลว: State ไม่ตรงกัน"
        ),
        "log_msg_005" to mapOf(
            "zh-Hant" to "授權失敗：未收到重導向資料",
            "en" to "Authorization failed: no redirect data received",
            "zh-Hans" to "授权失败：未收到重导向数据",
            "ja" to "認証に失敗しました: リダイレクトのデータを受け取っていません",
            "ko" to "인증 실패: 리디렉션 데이터를 받지 못했습니다",
            "th" to "การอนุญาตล้มเหลว: ไม่ได้รับข้อมูลการเปลี่ยนเส้นทาง"
        ),
        "log_msg_006" to mapOf(
            "zh-Hant" to "正在向 Google 交換授權憑證...",
            "en" to "Exchanging the authorization code with Google…",
            "zh-Hans" to "正在向 Google 交换授权凭据...",
            "ja" to "Google と認証情報を交換しています…",
            "ko" to "Google과 인증 정보를 교환하는 중…",
            "th" to "กำลังแลกเปลี่ยนข้อมูลรับรองกับ Google…"
        ),
        "log_msg_007" to mapOf(
            "zh-Hant" to "交換權杖失敗：%1@",
            "en" to "Token exchange failed: %1@",
            "zh-Hans" to "交换令牌失败：%1@",
            "ja" to "トークンの交換に失敗しました: %1@",
            "ko" to "토큰 교환에 실패했습니다: %1@",
            "th" to "แลกเปลี่ยนโทเค็นไม่สำเร็จ: %1@"
        ),
        "log_msg_008" to mapOf(
            "zh-Hant" to "無法取得有效權杖，Google Drive 同步中止",
            "en" to "Cannot get a valid token; Google Drive sync stopped",
            "zh-Hans" to "无法取得有效令牌，Google Drive 同步中止",
            "ja" to "有効なトークンを取得できないため、Google Drive の同期を中止しました",
            "ko" to "유효한 토큰을 가져올 수 없어 Google Drive 동기화를 중단했습니다",
            "th" to "ขอโทเค็นที่ใช้ได้ไม่ได้ จึงหยุดซิงก์ Google Drive"
        ),
        "log_msg_009" to mapOf(
            "zh-Hant" to "【同步中斷】已送出中斷要求，正在終止進行中的任務...",
            "en" to "[Sync stopped] Stop requested; ending the running tasks…",
            "zh-Hans" to "【同步中断】已送出中断要求，正在终止进行中的任务...",
            "ja" to "【同期の中断】中断を要求しました。実行中のタスクを終了しています…",
            "ko" to "[동기화 중단] 중단을 요청했습니다. 진행 중인 작업을 끝내는 중…",
            "th" to "[หยุดซิงก์] ส่งคำขอหยุดแล้ว กำลังยุติงานที่ทำอยู่…"
        ),
        "log_msg_010" to mapOf(
            "zh-Hant" to "【資料夾同步】等待上一輪結束逾時，已保留待同步狀態",
            "en" to "[Folder sync] Timed out waiting for the previous round to finish; the pending state is kept",
            "zh-Hans" to "【文件夹同步】等待上一轮结束逾时，已保留待同步状态",
            "ja" to "【フォルダ同期】前回の同期の終了待ちがタイムアウトしました。同期待ちの状態は保持しています",
            "ko" to "[폴더 동기화] 이전 회차가 끝나기를 기다리다 시간이 초과되었습니다. 대기 상태는 유지됩니다",
            "th" to "[ซิงก์โฟลเดอร์] รอรอบก่อนหน้าเสร็จหมดเวลา เก็บสถานะที่รอซิงก์ไว้แล้ว"
        ),
        "log_msg_011" to mapOf(
            "zh-Hant" to "【資料夾同步】上一輪（%1@）卡了 %2@ 秒沒收尾，接手",
            "en" to "[Folder sync] The previous round (%1@) was stuck for %2@ s; taking over",
            "zh-Hans" to "【文件夹同步】上一轮（%1@）卡了 %2@ 秒没收尾，接手",
            "ja" to "【フォルダ同期】前回（%1@）が %2@ 秒間終了しなかったため、引き継ぎました",
            "ko" to "[폴더 동기화] 이전 회차(%1@)가 %2@초 동안 끝나지 않아 이어받습니다",
            "th" to "[ซิงก์โฟลเดอร์] รอบก่อนหน้า (%1@) ค้างอยู่ %2@ วินาที จึงเข้ารับช่วงต่อ"
        ),
        "log_msg_012" to mapOf(
            "zh-Hant" to "【資料夾同步】開始執行，目標：%1@",
            "en" to "[Folder sync] Started; target: %1@",
            "zh-Hans" to "【文件夹同步】开始执行，目标：%1@",
            "ja" to "【フォルダ同期】開始しました。対象: %1@",
            "ko" to "[폴더 동기화] 시작했습니다. 대상: %1@",
            "th" to "[ซิงก์โฟลเดอร์] เริ่มทำงาน เป้าหมาย: %1@"
        ),
        "log_msg_013" to mapOf(
            "zh-Hant" to "【資料夾同步】已手動中斷。",
            "en" to "[Folder sync] Stopped manually.",
            "zh-Hans" to "【文件夹同步】已手动中断。",
            "ja" to "【フォルダ同期】手動で中断しました。",
            "ko" to "[폴더 동기화] 수동으로 중단했습니다.",
            "th" to "[ซิงก์โฟลเดอร์] หยุดด้วยตนเองแล้ว"
        ),
        "log_msg_014" to mapOf(
            "zh-Hant" to "【資料夾同步】全部完成。",
            "en" to "[Folder sync] All done.",
            "zh-Hans" to "【文件夹同步】全部完成。",
            "ja" to "【フォルダ同期】すべて完了しました。",
            "ko" to "[폴더 동기화] 모두 완료했습니다.",
            "th" to "[ซิงก์โฟลเดอร์] เสร็จสมบูรณ์"
        ),
        "log_msg_015" to mapOf(
            "zh-Hant" to "【資料夾同步】失敗：無法在遠端建立套件目錄 %1@",
            "en" to "[Folder sync] Failed: cannot create the package folder %1@ at the destination",
            "zh-Hans" to "【文件夹同步】失败：无法在远端建立套件目录 %1@",
            "ja" to "【フォルダ同期】失敗: 同期先にパッケージのフォルダ %1@ を作成できません",
            "ko" to "[폴더 동기화] 실패: 대상에 패키지 폴더 %1@을(를) 만들 수 없습니다",
            "th" to "[ซิงก์โฟลเดอร์] ล้มเหลว: สร้างโฟลเดอร์แพ็กเกจ %1@ ที่ปลายทางไม่ได้"
        ),
        "log_msg_016" to mapOf(
            "zh-Hant" to "【資料夾同步】%1@ 完成。上傳: %2@, 下載: %3@, 失敗: %4@",
            "en" to "[Folder sync] %1@ finished. Uploaded: %2@, downloaded: %3@, failed: %4@",
            "zh-Hans" to "【文件夹同步】%1@ 完成。上传: %2@, 下载: %3@, 失败: %4@",
            "ja" to "【フォルダ同期】%1@ が完了しました。アップロード: %2@、ダウンロード: %3@、失敗: %4@",
            "ko" to "[폴더 동기화] %1@ 완료. 업로드: %2@, 다운로드: %3@, 실패: %4@",
            "th" to "[ซิงก์โฟลเดอร์] %1@ เสร็จแล้ว อัปโหลด: %2@ ดาวน์โหลด: %3@ ล้มเหลว: %4@"
        ),
        "log_msg_017" to mapOf(
            "zh-Hant" to "【Google Drive 同步】等待上一輪結束逾時，已保留待同步狀態",
            "en" to "[Google Drive sync] Timed out waiting for the previous round to finish; the pending state is kept",
            "zh-Hans" to "【Google Drive 同步】等待上一轮结束逾时，已保留待同步状态",
            "ja" to "【Google Drive 同期】前回の同期の終了待ちがタイムアウトしました。同期待ちの状態は保持しています",
            "ko" to "[Google Drive 동기화] 이전 회차가 끝나기를 기다리다 시간이 초과되었습니다. 대기 상태는 유지됩니다",
            "th" to "[ซิงก์ Google Drive] รอรอบก่อนหน้าเสร็จหมดเวลา เก็บสถานะที่รอซิงก์ไว้แล้ว"
        ),
        "log_msg_018" to mapOf(
            "zh-Hant" to "【Google Drive 同步】上一輪（%1@）卡了 %2@ 秒沒收尾，接手",
            "en" to "[Google Drive sync] The previous round (%1@) was stuck for %2@ s; taking over",
            "zh-Hans" to "【Google Drive 同步】上一轮（%1@）卡了 %2@ 秒没收尾，接手",
            "ja" to "【Google Drive 同期】前回（%1@）が %2@ 秒間終了しなかったため、引き継ぎました",
            "ko" to "[Google Drive 동기화] 이전 회차(%1@)가 %2@초 동안 끝나지 않아 이어받습니다",
            "th" to "[ซิงก์ Google Drive] รอบก่อนหน้า (%1@) ค้างอยู่ %2@ วินาที จึงเข้ารับช่วงต่อ"
        ),
        "log_msg_019" to mapOf(
            "zh-Hant" to "【Google Drive 同步】開始執行",
            "en" to "[Google Drive sync] Started",
            "zh-Hans" to "【Google Drive 同步】开始执行",
            "ja" to "【Google Drive 同期】開始しました",
            "ko" to "[Google Drive 동기화] 시작했습니다",
            "th" to "[ซิงก์ Google Drive] เริ่มทำงาน"
        ),
        "log_msg_020" to mapOf(
            "zh-Hant" to "【Google Drive 同步】已手動中斷。",
            "en" to "[Google Drive sync] Stopped manually.",
            "zh-Hans" to "【Google Drive 同步】已手动中断。",
            "ja" to "【Google Drive 同期】手動で中断しました。",
            "ko" to "[Google Drive 동기화] 수동으로 중단했습니다.",
            "th" to "[ซิงก์ Google Drive] หยุดด้วยตนเองแล้ว"
        ),
        "log_msg_021" to mapOf(
            "zh-Hant" to "【Google Drive 同步】全部完成。",
            "en" to "[Google Drive sync] All done.",
            "zh-Hans" to "【Google Drive 同步】全部完成。",
            "ja" to "【Google Drive 同期】すべて完了しました。",
            "ko" to "[Google Drive 동기화] 모두 완료했습니다.",
            "th" to "[ซิงก์ Google Drive] เสร็จสมบูรณ์"
        ),
        "log_msg_022" to mapOf(
            "zh-Hant" to "步驟 1：匯出本機筆記 (%1@ 本)...",
            "en" to "Step 1: exporting local notebooks (%1@)…",
            "zh-Hans" to "步骤 1：导出本机笔记 (%1@ 本)...",
            "ja" to "手順 1: ローカルのノートを書き出しています（%1@ 冊）…",
            "ko" to "1단계: 로컬 노트 내보내는 중(%1@개)…",
            "th" to "ขั้นตอนที่ 1: กำลังส่งออกสมุดบันทึกในเครื่อง (%1@ เล่ม)…"
        ),
        "log_msg_023" to mapOf(
            "zh-Hant" to "步驟 1 完成，成功匯出 %1@ 本",
            "en" to "Step 1 done: %1@ notebooks exported",
            "zh-Hans" to "步骤 1 完成，成功导出 %1@ 本",
            "ja" to "手順 1 完了: %1@ 冊を書き出しました",
            "ko" to "1단계 완료: %1@개 내보냈습니다",
            "th" to "ขั้นตอนที่ 1 เสร็จ: ส่งออกสำเร็จ %1@ เล่ม"
        ),
        "log_msg_024" to mapOf(
            "zh-Hant" to "步驟 1：同步中繼資料與索引 (連線中)...",
            "en" to "Step 1: syncing metadata and the index (connecting)…",
            "zh-Hans" to "步骤 1：同步元数据与索引 (连线中)...",
            "ja" to "手順 1: メタデータとインデックスを同期しています（接続中）…",
            "ko" to "1단계: 메타데이터와 색인을 동기화하는 중(연결 중)…",
            "th" to "ขั้นตอนที่ 1: กำลังซิงก์เมทาดาทาและดัชนี (กำลังเชื่อมต่อ)…"
        ),
        "log_msg_025" to mapOf(
            "zh-Hant" to "步驟 2：搬移雲端檔案 (雙軌並行排程)...",
            "en" to "Step 2: moving cloud files (two lanes in parallel)…",
            "zh-Hans" to "步骤 2：搬移云端文件 (双轨并行排程)...",
            "ja" to "手順 2: クラウドのファイルを移動しています（2 系統を並行処理）…",
            "ko" to "2단계: 클라우드 파일 이동 중(두 경로 병렬 처리)…",
            "th" to "ขั้นตอนที่ 2: กำลังย้ายไฟล์บนคลาวด์ (สองเลนพร้อมกัน)…"
        ),
        "log_msg_026" to mapOf(
            "zh-Hant" to "步驟 2：更新雲端快照（changes.list）...",
            "en" to "Step 2: updating the cloud snapshot (changes.list)…",
            "zh-Hans" to "步骤 2：更新云端快照（changes.list）...",
            "ja" to "手順 2: クラウドのスナップショットを更新しています（changes.list）…",
            "ko" to "2단계: 클라우드 스냅샷 업데이트 중(changes.list)…",
            "th" to "ขั้นตอนที่ 2: กำลังอัปเดตสแนปช็อตคลาวด์ (changes.list)…"
        ),
        "log_msg_027" to mapOf(
            "zh-Hant" to "步驟 2 完成。上傳: %1@, 下載: %2@, 新增: %3@, 失敗: %4@",
            "en" to "Step 2 done. Uploaded: %1@, downloaded: %2@, new: %3@, failed: %4@",
            "zh-Hans" to "步骤 2 完成。上传: %1@, 下载: %2@, 新增: %3@, 失败: %4@",
            "ja" to "手順 2 完了。アップロード: %1@、ダウンロード: %2@、新規: %3@、失敗: %4@",
            "ko" to "2단계 완료. 업로드: %1@, 다운로드: %2@, 신규: %3@, 실패: %4@",
            "th" to "ขั้นตอนที่ 2 เสร็จ อัปโหลด: %1@ ดาวน์โหลด: %2@ ใหม่: %3@ ล้มเหลว: %4@"
        ),
        "log_msg_028" to mapOf(
            "zh-Hant" to "步驟 2 完成。上傳: %1@, 下載: %2@, 新增: %3@",
            "en" to "Step 2 done. Uploaded: %1@, downloaded: %2@, new: %3@",
            "zh-Hans" to "步骤 2 完成。上传: %1@, 下载: %2@, 新增: %3@",
            "ja" to "手順 2 完了。アップロード: %1@、ダウンロード: %2@、新規: %3@",
            "ko" to "2단계 완료. 업로드: %1@, 다운로드: %2@, 신규: %3@",
            "th" to "ขั้นตอนที่ 2 เสร็จ อัปโหลด: %1@ ดาวน์โหลด: %2@ ใหม่: %3@"
        ),
        "log_msg_029" to mapOf(
            "zh-Hant" to "步驟 3：匯入套件回本機筆記...",
            "en" to "Step 3: importing the packages back into local notebooks…",
            "zh-Hans" to "步骤 3：导入套件回本机笔记...",
            "ja" to "手順 3: パッケージをローカルのノートに取り込んでいます…",
            "ko" to "3단계: 패키지를 로컬 노트로 가져오는 중…",
            "th" to "ขั้นตอนที่ 3: กำลังนำเข้าแพ็กเกจกลับเป็นสมุดบันทึกในเครื่อง…"
        ),
        "log_msg_030" to mapOf(
            "zh-Hant" to "📊【同步前核實】本機現存: %1@ 本，待同步活躍筆記: %2@ 本",
            "en" to "📊 [Pre-sync check] Local notebooks: %1@; active notebooks waiting to sync: %2@",
            "zh-Hans" to "📊【同步前核实】本机现存: %1@ 本，待同步活跃笔记: %2@ 本",
            "ja" to "📊【同期前の確認】ローカルのノート: %1@ 冊、同期待ちのアクティブなノート: %2@ 冊",
            "ko" to "📊 [동기화 전 확인] 로컬 노트: %1@개, 동기화 대기 중인 활성 노트: %2@개",
            "th" to "📊 [ตรวจสอบก่อนซิงก์] สมุดบันทึกในเครื่อง: %1@ เล่ม สมุดที่ใช้งานรอซิงก์: %2@ เล่ม"
        ),
        "log_msg_031" to mapOf(
            "zh-Hant" to "📊【同步前核實】本機 %1@ 本，清理 %2@ 本，有差異待同步 %3@ 本（跳過 %4@ 本）",
            "en" to "📊 [Pre-sync check] Local: %1@, cleaned up: %2@, with differences to sync: %3@ (skipped %4@)",
            "zh-Hans" to "📊【同步前核实】本机 %1@ 本，清理 %2@ 本，有差异待同步 %3@ 本（跳过 %4@ 本）",
            "ja" to "📊【同期前の確認】ローカル %1@ 冊、整理 %2@ 冊、差分があり同期待ち %3@ 冊（スキップ %4@ 冊）",
            "ko" to "📊 [동기화 전 확인] 로컬 %1@개, 정리 %2@개, 차이가 있어 동기화 대기 %3@개(건너뜀 %4@개)",
            "th" to "📊 [ตรวจสอบก่อนซิงก์] ในเครื่อง %1@ เล่ม ล้างทิ้ง %2@ เล่ม มีความต่างรอซิงก์ %3@ เล่ม (ข้าม %4@ เล่ม)"
        ),
        "log_msg_032" to mapOf(
            "zh-Hant" to "【前台極速軌】優先同步當前作用中筆記 (%1@...)...",
            "en" to "[Foreground fast lane] Syncing the active notebook first (%1@…)…",
            "zh-Hans" to "【前台极速轨】优先同步当前活动笔记 (%1@...)...",
            "ja" to "【フォアグラウンド優先】現在開いているノート（%1@…）を優先して同期しています…",
            "ko" to "[전면 우선 처리] 현재 열려 있는 노트(%1@…)를 먼저 동기화하는 중…",
            "th" to "[เลนด่วนด้านหน้า] กำลังซิงก์สมุดที่เปิดอยู่ก่อน (%1@…)…"
        ),
        "log_msg_033" to mapOf(
            "zh-Hant" to "【前台極速軌】當前筆記 (%1@...) 完成（上傳: %2@, 下載: %3@）",
            "en" to "[Foreground fast lane] Active notebook (%1@…) done (uploaded: %2@, downloaded: %3@)",
            "zh-Hans" to "【前台极速轨】当前笔记 (%1@...) 完成（上传: %2@, 下载: %3@）",
            "ja" to "【フォアグラウンド優先】現在のノート（%1@…）が完了しました（アップロード: %2@、ダウンロード: %3@）",
            "ko" to "[전면 우선 처리] 현재 노트(%1@…) 완료(업로드: %2@, 다운로드: %3@)",
            "th" to "[เลนด่วนด้านหน้า] สมุดที่เปิดอยู่ (%1@…) เสร็จแล้ว (อัปโหลด: %2@ ดาวน์โหลด: %3@)"
        ),
        "log_msg_034" to mapOf(
            "zh-Hant" to "【背景佇列】開始同步其餘 %1@ 本非作用中筆記...",
            "en" to "[Background queue] Syncing the other %1@ inactive notebooks…",
            "zh-Hans" to "【后台队列】开始同步其余 %1@ 本非活动笔记...",
            "ja" to "【バックグラウンド】残りの %1@ 冊の非アクティブなノートを同期しています…",
            "ko" to "[백그라운드 대기열] 나머지 비활성 노트 %1@개를 동기화하는 중…",
            "th" to "[คิวเบื้องหลัง] กำลังซิงก์สมุดที่ไม่ได้ใช้งานที่เหลือ %1@ เล่ม…"
        ),
        "log_msg_035" to mapOf(
            "zh-Hant" to "【背景佇列】開始同步筆記本 (%1@...)...",
            "en" to "[Background queue] Syncing notebook (%1@…)…",
            "zh-Hans" to "【后台队列】开始同步笔记本 (%1@...)...",
            "ja" to "【バックグラウンド】ノート（%1@…）の同期を開始しました…",
            "ko" to "[백그라운드 대기열] 노트(%1@…) 동기화 시작…",
            "th" to "[คิวเบื้องหลัง] เริ่มซิงก์สมุดบันทึก (%1@…)…"
        ),
        "log_msg_036" to mapOf(
            "zh-Hant" to "【背景佇列】筆記本 (%1@...) 完成（上傳: %2@, 下載: %3@）",
            "en" to "[Background queue] Notebook (%1@…) done (uploaded: %2@, downloaded: %3@)",
            "zh-Hans" to "【后台队列】笔记本 (%1@...) 完成（上传: %2@, 下载: %3@）",
            "ja" to "【バックグラウンド】ノート（%1@…）が完了しました（アップロード: %2@、ダウンロード: %3@）",
            "ko" to "[백그라운드 대기열] 노트(%1@…) 완료(업로드: %2@, 다운로드: %3@)",
            "th" to "[คิวเบื้องหลัง] สมุดบันทึก (%1@…) เสร็จแล้ว (อัปโหลด: %2@ ดาวน์โหลด: %3@)"
        ),
        "log_msg_037" to mapOf(
            "zh-Hant" to "匯出失敗 (%1@)：%2@",
            "en" to "Export failed (%1@): %2@",
            "zh-Hans" to "导出失败 (%1@)：%2@",
            "ja" to "書き出しに失敗しました（%1@）: %2@",
            "ko" to "내보내기 실패(%1@): %2@",
            "th" to "ส่งออกไม่สำเร็จ (%1@): %2@"
        ),
        "log_msg_038" to mapOf(
            "zh-Hant" to "無法取得 Google Drive 工作階段！",
            "en" to "Cannot get a Google Drive session!",
            "zh-Hans" to "无法取得 Google Drive 会话！",
            "ja" to "Google Drive のセッションを取得できません！",
            "ko" to "Google Drive 세션을 가져올 수 없습니다!",
            "th" to "เปิดเซสชัน Google Drive ไม่ได้!"
        )
    )

    private fun part15(): Map<String, Map<String, String>> = mapOf(
        "log_msg_039" to mapOf(
            "zh-Hant" to "無法取得 Google Drive 索引！",
            "en" to "Cannot get the Google Drive index!",
            "zh-Hans" to "无法取得 Google Drive 索引！",
            "ja" to "Google Drive のインデックスを取得できません！",
            "ko" to "Google Drive 색인을 가져올 수 없습니다!",
            "th" to "อ่านดัชนี Google Drive ไม่ได้!"
        ),
        "log_msg_040" to mapOf(
            "zh-Hant" to "雲端快照更新失敗：%1@",
            "en" to "Cloud snapshot update failed: %1@",
            "zh-Hans" to "云端快照更新失败：%1@",
            "ja" to "クラウドのスナップショットの更新に失敗しました: %1@",
            "ko" to "클라우드 스냅샷 업데이트 실패: %1@",
            "th" to "อัปเดตสแนปช็อตคลาวด์ไม่สำเร็จ: %1@"
        ),
        "log_msg_041" to mapOf(
            "zh-Hant" to "雲端快照重建完成（%1@ 個檔案）",
            "en" to "Cloud snapshot rebuilt (%1@ files)",
            "zh-Hans" to "云端快照重建完成（%1@ 个文件）",
            "ja" to "クラウドのスナップショットを再構築しました（%1@ ファイル）",
            "ko" to "클라우드 스냅샷을 다시 만들었습니다(파일 %1@개)",
            "th" to "สร้างสแนปช็อตคลาวด์ใหม่เสร็จ (%1@ ไฟล์)"
        ),
        "log_msg_042" to mapOf(
            "zh-Hant" to "雲端變動 %1@ 筆，快照共 %2@ 個檔案",
            "en" to "%1@ cloud changes; the snapshot has %2@ files",
            "zh-Hans" to "云端变动 %1@ 笔，快照共 %2@ 个文件",
            "ja" to "クラウドの変更 %1@ 件、スナップショットは計 %2@ ファイル",
            "ko" to "클라우드 변경 %1@건, 스냅샷은 총 파일 %2@개",
            "th" to "การเปลี่ยนแปลงบนคลาวด์ %1@ รายการ สแนปช็อตมีทั้งหมด %2@ ไฟล์"
        ),
        "log_msg_043" to mapOf(
            "zh-Hant" to "元資料同步失敗：%1@",
            "en" to "Metadata sync failed: %1@",
            "zh-Hans" to "元数据同步失败：%1@",
            "ja" to "メタデータの同期に失敗しました: %1@",
            "ko" to "메타데이터 동기화 실패: %1@",
            "th" to "ซิงก์เมทาดาทาไม่สำเร็จ: %1@"
        ),
        "log_msg_044" to mapOf(
            "zh-Hant" to "中繼資料同步失敗：%1@",
            "en" to "Metadata sync failed: %1@",
            "zh-Hans" to "元数据同步失败：%1@",
            "ja" to "メタデータの同期に失敗しました: %1@",
            "ko" to "메타데이터 동기화 실패: %1@",
            "th" to "ซิงก์เมทาดาทาไม่สำเร็จ: %1@"
        ),
        "log_msg_045" to mapOf(
            "zh-Hant" to "筆記本 %1@… 完成（上傳 %2@、下載 %3@）",
            "en" to "Notebook %1@… done (uploaded %2@, downloaded %3@)",
            "zh-Hans" to "笔记本 %1@… 完成（上传 %2@、下载 %3@）",
            "ja" to "ノート %1@… が完了しました（アップロード %2@、ダウンロード %3@）",
            "ko" to "노트 %1@… 완료(업로드 %2@, 다운로드 %3@)",
            "th" to "สมุดบันทึก %1@… เสร็จแล้ว (อัปโหลด %2@ ดาวน์โหลด %3@)"
        ),
        "log_msg_046" to mapOf(
            "zh-Hant" to "筆記本 %1@… 同步失敗：%2@",
            "en" to "Notebook %1@… sync failed: %2@",
            "zh-Hans" to "笔记本 %1@… 同步失败：%2@",
            "ja" to "ノート %1@… の同期に失敗しました: %2@",
            "ko" to "노트 %1@… 동기화 실패: %2@",
            "th" to "ซิงก์สมุดบันทึก %1@… ไม่สำเร็จ: %2@"
        ),
        "log_msg_047" to mapOf(
            "zh-Hant" to "筆記本 %1@… 正在被焦點同步佔用，這一輪略過匯入",
            "en" to "Notebook %1@… is in use by Focus sync; skipping its import this round",
            "zh-Hans" to "笔记本 %1@… 正在被焦点同步占用，这一轮略过导入",
            "ja" to "ノート %1@… はフォーカス同期で使用中のため、今回は取り込みをスキップします",
            "ko" to "노트 %1@…은(는) 집중 동기화에서 사용 중이라 이번 회차 가져오기를 건너뜁니다",
            "th" to "สมุดบันทึก %1@… ถูกซิงก์โฟกัสใช้อยู่ จึงข้ามการนำเข้ารอบนี้"
        ),
        "log_msg_048" to mapOf(
            "zh-Hant" to "筆記本 %1@… %2@",
            "en" to "Notebook %1@… %2@",
            "zh-Hans" to "笔记本 %1@… %2@",
            "ja" to "ノート %1@… %2@",
            "ko" to "노트 %1@… %2@",
            "th" to "สมุดบันทึก %1@… %2@"
        ),
        "log_msg_049" to mapOf(
            "zh-Hant" to "筆記本 %1@ 同步中斷",
            "en" to "Notebook %1@ sync stopped",
            "zh-Hans" to "笔记本 %1@ 同步中断",
            "ja" to "ノート %1@ の同期を中断しました",
            "ko" to "노트 %1@ 동기화가 중단되었습니다",
            "th" to "หยุดซิงก์สมุดบันทึก %1@"
        ),
        "log_msg_050" to mapOf(
            "zh-Hant" to "筆記本 %1@ 同步失敗：%2@",
            "en" to "Notebook %1@ sync failed: %2@",
            "zh-Hans" to "笔记本 %1@ 同步失败：%2@",
            "ja" to "ノート %1@ の同期に失敗しました: %2@",
            "ko" to "노트 %1@ 동기화 실패: %2@",
            "th" to "ซิงก์สมุดบันทึก %1@ ไม่สำเร็จ: %2@"
        ),
        "log_msg_051" to mapOf(
            "zh-Hant" to "筆記本 %1@ %2@",
            "en" to "Notebook %1@ %2@",
            "zh-Hans" to "笔记本 %1@ %2@",
            "ja" to "ノート %1@ %2@",
            "ko" to "노트 %1@ %2@",
            "th" to "สมุดบันทึก %1@ %2@"
        ),
        "log_msg_052" to mapOf(
            "zh-Hant" to "發現新筆記「%1@」(%2@)，開始自雲端下載...",
            "en" to "Found a new notebook “%1@” (%2@); downloading it from the cloud…",
            "zh-Hans" to "发现新笔记「%1@」(%2@)，开始自云端下载...",
            "ja" to "新しいノート「%1@」（%2@）を見つけました。クラウドからダウンロードしています…",
            "ko" to "새 노트 “%1@”(%2@)을(를) 찾았습니다. 클라우드에서 다운로드하는 중…",
            "th" to "พบสมุดบันทึกใหม่ “%1@” (%2@) กำลังดาวน์โหลดจากคลาวด์…"
        ),
        "log_msg_053" to mapOf(
            "zh-Hant" to "筆記本「%1@」成功自雲端下載完成",
            "en" to "Notebook “%1@” was downloaded from the cloud",
            "zh-Hans" to "笔记本「%1@」成功自云端下载完成",
            "ja" to "ノート「%1@」をクラウドからダウンロードしました",
            "ko" to "노트 “%1@”을(를) 클라우드에서 다운로드했습니다",
            "th" to "ดาวน์โหลดสมุดบันทึก “%1@” จากคลาวด์สำเร็จ"
        ),
        "log_msg_054" to mapOf(
            "zh-Hant" to "筆記本「%1@」自雲端下載失敗：%2@",
            "en" to "Downloading notebook “%1@” from the cloud failed: %2@",
            "zh-Hans" to "笔记本「%1@」自云端下载失败：%2@",
            "ja" to "ノート「%1@」のクラウドからのダウンロードに失敗しました: %2@",
            "ko" to "노트 “%1@”을(를) 클라우드에서 다운로드하지 못했습니다: %2@",
            "th" to "ดาวน์โหลดสมุดบันทึก “%1@” จากคลาวด์ไม่สำเร็จ: %2@"
        ),
        "log_msg_055" to mapOf(
            "zh-Hant" to "已清理已刪除筆記本殘留套件：%1@",
            "en" to "Cleaned up the leftover package of a deleted notebook: %1@",
            "zh-Hans" to "已清理已删除笔记本残留套件：%1@",
            "ja" to "削除済みノートの残ったパッケージを整理しました: %1@",
            "ko" to "삭제된 노트의 남은 패키지를 정리했습니다: %1@",
            "th" to "ล้างแพ็กเกจที่ตกค้างของสมุดบันทึกที่ลบแล้ว: %1@"
        ),
        "log_msg_056" to mapOf(
            "zh-Hant" to "【回收桶】確認檔沒發布成功：%1@",
            "en" to "[Trash] The confirmation file was not published: %1@",
            "zh-Hans" to "【回收站】确认档没发布成功：%1@",
            "ja" to "【ゴミ箱】確認ファイルを公開できませんでした: %1@",
            "ko" to "[휴지통] 확인 파일을 게시하지 못했습니다: %1@",
            "th" to "[ถังขยะ] เผยแพร่ไฟล์ยืนยันไม่สำเร็จ: %1@"
        ),
        "log_msg_057" to mapOf(
            "zh-Hant" to "【回收桶】已永久清理雲端 %1@ 個過期檔案",
            "en" to "[Trash] Permanently removed %1@ expired files from the cloud",
            "zh-Hans" to "【回收站】已永久清理云端 %1@ 个过期文件",
            "ja" to "【ゴミ箱】期限切れのクラウドのファイル %1@ 件を完全に削除しました",
            "ko" to "[휴지통] 만료된 클라우드 파일 %1@개를 영구 삭제했습니다",
            "th" to "[ถังขยะ] ลบไฟล์หมดอายุบนคลาวด์ %1@ ไฟล์ถาวรแล้ว"
        ),
        "log_msg_058" to mapOf(
            "zh-Hant" to "【回收桶】已永久清理本機 %1@ 本過期筆記本",
            "en" to "[Trash] Permanently removed %1@ expired notebooks from this device",
            "zh-Hans" to "【回收站】已永久清理本机 %1@ 本过期笔记本",
            "ja" to "【ゴミ箱】期限切れのノート %1@ 冊をこのデバイスから完全に削除しました",
            "ko" to "[휴지통] 만료된 노트 %1@개를 이 기기에서 영구 삭제했습니다",
            "th" to "[ถังขยะ] ลบสมุดบันทึกหมดอายุ %1@ เล่มออกจากอุปกรณ์นี้ถาวรแล้ว"
        ),
        "log_msg_059" to mapOf(
            "zh-Hant" to "【回收桶】%1@ 本已期滿，等待這些裝置確認：%2@",
            "en" to "[Trash] %1@ notebooks have expired and are waiting for these devices to confirm: %2@",
            "zh-Hans" to "【回收站】%1@ 本已期满，等待这些设备确认：%2@",
            "ja" to "【ゴミ箱】期限切れのノート %1@ 冊が、次のデバイスの確認を待っています: %2@",
            "ko" to "[휴지통] 만료된 노트 %1@개가 다음 기기의 확인을 기다리고 있습니다: %2@",
            "th" to "[ถังขยะ] สมุดบันทึกหมดอายุ %1@ เล่มกำลังรออุปกรณ์เหล่านี้ยืนยัน: %2@"
        ),
        "log_msg_060" to mapOf(
            "zh-Hant" to "【回收桶】%1@ 本已期滿，等待這些裝置確認：",
            "en" to "[Trash] %1@ notebooks have expired and are waiting for these devices to confirm:",
            "zh-Hans" to "【回收站】%1@ 本已期满，等待这些设备确认：",
            "ja" to "【ゴミ箱】期限切れのノート %1@ 冊が、次のデバイスの確認を待っています:",
            "ko" to "[휴지통] 만료된 노트 %1@개가 다음 기기의 확인을 기다리고 있습니다:",
            "th" to "[ถังขยะ] สมุดบันทึกหมดอายุ %1@ เล่มกำลังรออุปกรณ์เหล่านี้ยืนยัน:"
        ),
        "log_msg_061" to mapOf(
            "zh-Hant" to "【回收】等待上一輪結束逾時，請稍後重試",
            "en" to "[Cleanup] Timed out waiting for the previous round to finish; please try again later",
            "zh-Hans" to "【回收】等待上一轮结束逾时，请稍后重试",
            "ja" to "【整理】前回の処理の終了待ちがタイムアウトしました。しばらくしてからやり直してください",
            "ko" to "[정리] 이전 회차가 끝나기를 기다리다 시간이 초과되었습니다. 잠시 후 다시 시도하세요",
            "th" to "[ล้างข้อมูล] รอรอบก่อนหน้าเสร็จหมดเวลา โปรดลองใหม่ภายหลัง"
        ),
        "log_msg_062" to mapOf(
            "zh-Hant" to "【回收】完成，刪除 %1@ 個檔案",
            "en" to "[Cleanup] Done; deleted %1@ files",
            "zh-Hans" to "【回收】完成，删除 %1@ 个文件",
            "ja" to "【整理】完了しました。%1@ ファイルを削除しました",
            "ko" to "[정리] 완료. 파일 %1@개를 삭제했습니다",
            "th" to "[ล้างข้อมูล] เสร็จแล้ว ลบ %1@ ไฟล์"
        ),
        "log_msg_063" to mapOf(
            "zh-Hant" to "【回收】完成，刪除 %1@ 個檔案；%2@ 本在等這些裝置確認：%3@",
            "en" to "[Cleanup] Done; deleted %1@ files; %2@ notebooks are waiting for these devices to confirm: %3@",
            "zh-Hans" to "【回收】完成，删除 %1@ 个文件；%2@ 本在等这些设备确认：%3@",
            "ja" to "【整理】完了しました。%1@ ファイルを削除しました。%2@ 冊が次のデバイスの確認を待っています: %3@",
            "ko" to "[정리] 완료. 파일 %1@개를 삭제했습니다. 노트 %2@개가 다음 기기의 확인을 기다립니다: %3@",
            "th" to "[ล้างข้อมูล] เสร็จแล้ว ลบ %1@ ไฟล์ สมุดบันทึก %2@ เล่มรออุปกรณ์เหล่านี้ยืนยัน: %3@"
        ),
        "log_msg_064" to mapOf(
            "zh-Hant" to "【回收】刪除 %1@ 個，失敗 %2@ 個：%3@",
            "en" to "[Cleanup] Deleted %1@, failed %2@: %3@",
            "zh-Hans" to "【回收】删除 %1@ 个，失败 %2@ 个：%3@",
            "ja" to "【整理】%1@ 件を削除、%2@ 件が失敗しました: %3@",
            "ko" to "[정리] %1@개 삭제, %2@개 실패: %3@",
            "th" to "[ล้างข้อมูล] ลบ %1@ รายการ ล้มเหลว %2@ รายการ: %3@"
        ),
        "log_msg_065" to mapOf(
            "zh-Hant" to "【回收】刪除 %1@ 個，失敗 %2@ 個：%3@；%4@ 本在等這些裝置確認：%5@",
            "en" to "[Cleanup] Deleted %1@, failed %2@: %3@; %4@ notebooks are waiting for these devices to confirm: %5@",
            "zh-Hans" to "【回收】删除 %1@ 个，失败 %2@ 个：%3@；%4@ 本在等这些设备确认：%5@",
            "ja" to "【整理】%1@ 件を削除、%2@ 件が失敗しました: %3@。%4@ 冊が次のデバイスの確認を待っています: %5@",
            "ko" to "[정리] %1@개 삭제, %2@개 실패: %3@. 노트 %4@개가 다음 기기의 확인을 기다립니다: %5@",
            "th" to "[ล้างข้อมูล] ลบ %1@ รายการ ล้มเหลว %2@ รายการ: %3@ สมุดบันทึก %4@ เล่มรออุปกรณ์เหล่านี้ยืนยัน: %5@"
        ),
        "log_msg_066" to mapOf(
            "zh-Hant" to "【重置雲端】開始刪除雲端資料…",
            "en" to "[Reset cloud] Deleting the cloud data…",
            "zh-Hans" to "【重置云端】开始删除云端数据…",
            "ja" to "【クラウドのリセット】クラウドのデータを削除しています…",
            "ko" to "[클라우드 초기화] 클라우드 데이터를 삭제하는 중…",
            "th" to "[รีเซ็ตคลาวด์] กำลังลบข้อมูลบนคลาวด์…"
        ),
        "log_msg_067" to mapOf(
            "zh-Hant" to "【重置雲端】等待上一輪結束逾時，請稍後重試",
            "en" to "[Reset cloud] Timed out waiting for the previous round to finish; please try again later",
            "zh-Hans" to "【重置云端】等待上一轮结束逾时，请稍后重试",
            "ja" to "【クラウドのリセット】前回の処理の終了待ちがタイムアウトしました。しばらくしてからやり直してください",
            "ko" to "[클라우드 초기화] 이전 회차가 끝나기를 기다리다 시간이 초과되었습니다. 잠시 후 다시 시도하세요",
            "th" to "[รีเซ็ตคลาวด์] รอรอบก่อนหน้าเสร็จหมดเวลา โปรดลองใหม่ภายหลัง"
        ),
        "log_msg_068" to mapOf(
            "zh-Hant" to "【重置雲端】完成，刪除 %1@ 個檔案",
            "en" to "[Reset cloud] Done; deleted %1@ files",
            "zh-Hans" to "【重置云端】完成，删除 %1@ 个文件",
            "ja" to "【クラウドのリセット】完了しました。%1@ ファイルを削除しました",
            "ko" to "[클라우드 초기화] 완료. 파일 %1@개를 삭제했습니다",
            "th" to "[รีเซ็ตคลาวด์] เสร็จแล้ว ลบ %1@ ไฟล์"
        ),
        "log_msg_069" to mapOf(
            "zh-Hant" to "【重置雲端】刪除 %1@ 個，失敗 %2@ 個：%3@",
            "en" to "[Reset cloud] Deleted %1@, failed %2@: %3@",
            "zh-Hans" to "【重置云端】删除 %1@ 个，失败 %2@ 个：%3@",
            "ja" to "【クラウドのリセット】%1@ 件を削除、%2@ 件が失敗しました: %3@",
            "ko" to "[클라우드 초기화] %1@개 삭제, %2@개 실패: %3@",
            "th" to "[รีเซ็ตคลาวด์] ลบ %1@ รายการ ล้มเหลว %2@ รายการ: %3@"
        ),
        "log_msg_070" to mapOf(
            "zh-Hant" to "【焦點同步】%1@… 失敗：%2@",
            "en" to "[Focus sync] %1@… failed: %2@",
            "zh-Hans" to "【焦点同步】%1@… 失败：%2@",
            "ja" to "【フォーカス同期】%1@… が失敗しました: %2@",
            "ko" to "[집중 동기화] %1@… 실패: %2@",
            "th" to "[ซิงก์โฟกัส] %1@… ล้มเหลว: %2@"
        ),
        "log_msg_071" to mapOf(
            "zh-Hant" to "【焦點同步】%1@… 上傳 %2@、下載 %3@",
            "en" to "[Focus sync] %1@… uploaded %2@, downloaded %3@",
            "zh-Hans" to "【焦点同步】%1@… 上传 %2@、下载 %3@",
            "ja" to "【フォーカス同期】%1@… アップロード %2@、ダウンロード %3@",
            "ko" to "[집중 동기화] %1@… 업로드 %2@, 다운로드 %3@",
            "th" to "[ซิงก์โฟกัส] %1@… อัปโหลด %2@ ดาวน์โหลด %3@"
        ),
        "log_msg_072" to mapOf(
            "zh-Hant" to "【焦點同步】%1@… 上傳 %2@、下載 %3@（匯出 %4@ms、雲端 %5@ms、匯入 %6@ms）",
            "en" to "[Focus sync] %1@… uploaded %2@, downloaded %3@ (export %4@ ms, cloud %5@ ms, import %6@ ms)",
            "zh-Hans" to "【焦点同步】%1@… 上传 %2@、下载 %3@（导出 %4@ms、云端 %5@ms、导入 %6@ms）",
            "ja" to "【フォーカス同期】%1@… アップロード %2@、ダウンロード %3@（書き出し %4@ms、クラウド %5@ms、取り込み %6@ms）",
            "ko" to "[집중 동기화] %1@… 업로드 %2@, 다운로드 %3@(내보내기 %4@ms, 클라우드 %5@ms, 가져오기 %6@ms)",
            "th" to "[ซิงก์โฟกัส] %1@… อัปโหลด %2@ ดาวน์โหลด %3@ (ส่งออก %4@ ms คลาวด์ %5@ ms นำเข้า %6@ ms)"
        ),
        "log_msg_073" to mapOf(
            "zh-Hant" to "【焦點同步】%1@… 上傳 %2@、下載 %3@（雲端 %4@ms）",
            "en" to "[Focus sync] %1@… uploaded %2@, downloaded %3@ (cloud %4@ ms)",
            "zh-Hans" to "【焦点同步】%1@… 上传 %2@、下载 %3@（云端 %4@ms）",
            "ja" to "【フォーカス同期】%1@… アップロード %2@、ダウンロード %3@（クラウド %4@ms）",
            "ko" to "[집중 동기화] %1@… 업로드 %2@, 다운로드 %3@(클라우드 %4@ms)",
            "th" to "[ซิงก์โฟกัส] %1@… อัปโหลด %2@ ดาวน์โหลด %3@ (คลาวด์ %4@ ms)"
        ),
        "log_msg_074" to mapOf(
            "zh-Hant" to "【焦點同步】%1@… %2@",
            "en" to "[Focus sync] %1@… %2@",
            "zh-Hans" to "【焦点同步】%1@… %2@",
            "ja" to "【フォーカス同期】%1@… %2@",
            "ko" to "[집중 동기화] %1@… %2@",
            "th" to "[ซิงก์โฟกัส] %1@… %2@"
        ),
        "log_msg_075" to mapOf(
            "zh-Hant" to "【區網直連】%1@… 忙碌中，稍後再匯入",
            "en" to "[Local link] %1@… is busy; will import it later",
            "zh-Hans" to "【局域网直连】%1@… 忙碌中，稍后再导入",
            "ja" to "【ローカル直接接続】%1@… は処理中のため、後で取り込みます",
            "ko" to "[로컬 직접 연결] %1@…은(는) 사용 중이라 나중에 가져옵니다",
            "th" to "[เชื่อมต่อตรงในเครือข่ายภายใน] %1@… กำลังไม่ว่าง จะนำเข้าภายหลัง"
        ),
        "log_msg_076" to mapOf(
            "zh-Hant" to "【區網直連】%1@… 收到並匯入（%2@ms）",
            "en" to "[Local link] %1@… received and imported (%2@ ms)",
            "zh-Hans" to "【局域网直连】%1@… 收到并导入（%2@ms）",
            "ja" to "【ローカル直接接続】%1@… を受信して取り込みました（%2@ms）",
            "ko" to "[로컬 직접 연결] %1@… 수신 및 가져오기 완료(%2@ms)",
            "th" to "[เชื่อมต่อตรงในเครือข่ายภายใน] %1@… รับและนำเข้าแล้ว (%2@ ms)"
        ),
        "log_msg_077" to mapOf(
            "zh-Hant" to "【區網直連】%1@… 收到對端的更新",
            "en" to "[Local link] %1@… received an update from the peer",
            "zh-Hans" to "【局域网直连】%1@… 收到对端的更新",
            "ja" to "【ローカル直接接続】%1@… で相手からの更新を受信しました",
            "ko" to "[로컬 직접 연결] %1@… 상대방의 업데이트를 받았습니다",
            "th" to "[เชื่อมต่อตรงในเครือข่ายภายใน] %1@… ได้รับการอัปเดตจากปลายทาง"
        ),
        "log_msg_078" to mapOf(
            "zh-Hant" to "【區網直連】啟動失敗：%1@",
            "en" to "[Local link] Failed to start: %1@",
            "zh-Hans" to "【局域网直连】启动失败：%1@",
            "ja" to "【ローカル直接接続】起動に失敗しました: %1@",
            "ko" to "[로컬 직접 연결] 시작 실패: %1@",
            "th" to "[เชื่อมต่อตรงในเครือข่ายภายใน] เริ่มไม่สำเร็จ: %1@"
        ),
        "log_msg_079" to mapOf(
            "zh-Hant" to "【區網直連】已連上 %1@ 台裝置",
            "en" to "[Local link] Connected to %1@ devices",
            "zh-Hans" to "【局域网直连】已连上 %1@ 台设备",
            "ja" to "【ローカル直接接続】%1@ 台のデバイスに接続しました",
            "ko" to "[로컬 직접 연결] 기기 %1@대에 연결되었습니다",
            "th" to "[เชื่อมต่อตรงในเครือข่ายภายใน] เชื่อมต่ออุปกรณ์แล้ว %1@ เครื่อง"
        ),
        "log_msg_080" to mapOf(
            "zh-Hant" to "自動清理：%1@ 項（%2@ MB），回收桶期滿 %3@ 本",
            "en" to "Auto cleanup: %1@ items (%2@ MB); %3@ expired notebooks removed from the trash",
            "zh-Hans" to "自动清理：%1@ 项（%2@ MB），回收站期满 %3@ 本",
            "ja" to "自動整理: %1@ 件（%2@ MB）、ゴミ箱の期限切れ %3@ 冊",
            "ko" to "자동 정리: %1@개 항목(%2@MB), 휴지통 만료 노트 %3@개",
            "th" to "ล้างอัตโนมัติ: %1@ รายการ (%2@ MB) สมุดบันทึกในถังขยะหมดอายุ %3@ เล่ม"
        ),
        "log_msg_081" to mapOf(
            "zh-Hant" to "自動清理：暫存 %1@ 項、模型殘檔 %2@ 項（共 %3@ MB），回收桶期滿 %4@ 本",
            "en" to "Auto cleanup: %1@ temp items, %2@ leftover model files (%3@ MB in total); %4@ expired notebooks removed from the trash",
            "zh-Hans" to "自动清理：临时 %1@ 项、模型残留文件 %2@ 项（共 %3@ MB），回收站期满 %4@ 本",
            "ja" to "自動整理: 一時ファイル %1@ 件、モデルの残りファイル %2@ 件（合計 %3@ MB）、ゴミ箱の期限切れ %4@ 冊",
            "ko" to "자동 정리: 임시 항목 %1@개, 모델 잔여 파일 %2@개(총 %3@MB), 휴지통 만료 노트 %4@개",
            "th" to "ล้างอัตโนมัติ: ไฟล์ชั่วคราว %1@ รายการ ไฟล์โมเดลที่เหลือ %2@ รายการ (รวม %3@ MB) สมุดบันทึกในถังขยะหมดอายุ %4@ เล่ม"
        ),
        "magnetic_snap_active" to mapOf(
            "zh-Hant" to "幾何角度與格線磁吸對齊中",
            "en" to "Snapping to geometric angles and grid",
            "zh-Hans" to "几何角度与网格磁吸对齐中",
            "ja" to "角度とグリッドにスナップ中",
            "ko" to "각도 및 격자에 스냅 중",
            "th" to "กำลังสแน็ปกับมุมเรขาคณิตและเส้นตาราง"
        ),
        "magnetic_snap_ruler" to mapOf(
            "zh-Hant" to "筆跡磁吸對齊與尺規",
            "en" to "Magnetic Snap & Ruler",
            "zh-Hans" to "笔迹磁吸对齐与尺规",
            "ja" to "磁気スナップと定規",
            "ko" to "자석 스냅 및 눈금자",
            "th" to "สแน็ปแม่เหล็กและไม้บรรทัด"
        ),
        "manage" to mapOf(
            "zh-Hant" to "管理",
            "en" to "Manage",
            "zh-Hans" to "管理",
            "ja" to "管理",
            "ko" to "관리",
            "th" to "จัดการ"
        ),
        "marquee_hint" to mapOf(
            "zh-Hant" to "拖曳拉框選取物件；在選取範圍內拖曳＝整組搬移",
            "en" to "Drag to select objects. Drag inside the selection to move them together.",
            "zh-Hans" to "拖曳拉框选取物件；在选取范围内拖曳＝整组搬移",
            "ja" to "ドラッグで範囲選択。選択範囲の中をドラッグするとまとめて移動できます。",
            "ko" to "끌어서 범위를 선택하세요. 선택 영역 안을 끌면 함께 이동합니다.",
            "th" to "ลากเพื่อเลือกวัตถุ ลากภายในพื้นที่ที่เลือกเพื่อย้ายพร้อมกัน"
        ),
        "marquee_select" to mapOf(
            "zh-Hant" to "框選",
            "en" to "Select",
            "zh-Hans" to "框选",
            "ja" to "範囲選択",
            "ko" to "범위 선택",
            "th" to "เลือกพื้นที่"
        ),
        "marquee_selected" to mapOf(
            "zh-Hant" to "已選 %@ 個",
            "en" to "%@ selected",
            "zh-Hans" to "已选 %@ 个",
            "ja" to "%@ 個選択中",
            "ko" to "%@개 선택됨",
            "th" to "เลือกแล้ว %@ รายการ"
        ),
        "mat_copper" to mapOf(
            "zh-Hant" to "紅銅",
            "en" to "Copper",
            "zh-Hans" to "红铜",
            "ja" to "カッパー (銅)",
            "ko" to "구리 (동)",
            "th" to "ทองแดง"
        ),
        "mat_gold" to mapOf(
            "zh-Hant" to "黃金",
            "en" to "Gold",
            "zh-Hans" to "黄金",
            "ja" to "ゴールド",
            "ko" to "골드 (금)",
            "th" to "ทองคำ"
        ),
        "mat_granite" to mapOf(
            "zh-Hant" to "花崗岩",
            "en" to "Granite",
            "zh-Hans" to "花岗岩",
            "ja" to "花崗岩",
            "ko" to "화강암",
            "th" to "หินแกรนิต"
        ),
        "mat_iron" to mapOf(
            "zh-Hant" to "鋼鐵",
            "en" to "Steel",
            "zh-Hans" to "钢铁",
            "ja" to "スチール (鉄)",
            "ko" to "강철",
            "th" to "เหล็กกล้า"
        ),
        "mat_marble" to mapOf(
            "zh-Hant" to "大理石",
            "en" to "Marble",
            "zh-Hans" to "大理石",
            "ja" to "大理石",
            "ko" to "대리석",
            "th" to "หินอ่อน"
        ),
        "mat_none" to mapOf(
            "zh-Hant" to "無特殊材質",
            "en" to "None",
            "zh-Hans" to "无特殊材质",
            "ja" to "なし",
            "ko" to "없음",
            "th" to "ไม่มี"
        ),
        "mat_obsidian" to mapOf(
            "zh-Hant" to "黑曜石",
            "en" to "Obsidian",
            "zh-Hans" to "黑曜石",
            "ja" to "黒曜石",
            "ko" to "흑요석",
            "th" to "หินออบซิเดียน"
        ),
        "mat_plastic" to mapOf(
            "zh-Hant" to "塑膠",
            "en" to "Plastic",
            "zh-Hans" to "塑料",
            "ja" to "プラスチック",
            "ko" to "플라스틱",
            "th" to "พาสติก"
        ),
        "mat_silver" to mapOf(
            "zh-Hant" to "白銀",
            "en" to "Silver",
            "zh-Hans" to "白银",
            "ja" to "シルバー",
            "ko" to "실버 (은)",
            "th" to "เงิน"
        ),
        "mat_wood" to mapOf(
            "zh-Hant" to "原木",
            "en" to "Wood",
            "zh-Hans" to "原木",
            "ja" to "ウッド (木材)",
            "ko" to "목재",
            "th" to "ไม้"
        ),
        "material_al6061_spec" to mapOf(
            "zh-Hant" to "抗拉強度 ≥290 MPa / 12μm 硬質陽極氧化",
            "en" to "Tensile ≥290 MPa / 12 µm hard anodising",
            "zh-Hans" to "抗拉强度 ≥290 MPa / 12μm 硬质阳极氧化",
            "ja" to "引張強さ ≥290 MPa／硬質アルマイト 12μm",
            "ko" to "인장강도 ≥290 MPa / 경질 아노다이징 12 µm",
            "th" to "ความต้านแรงดึง ≥290 MPa / อโนไดซ์แข็ง 12 ไมครอน"
        ),
        "material_al6061_trait" to mapOf(
            "zh-Hant" to "航空高剛性",
            "en" to "Aerospace-grade stiffness",
            "zh-Hans" to "航空高刚性",
            "ja" to "航空機グレード・高剛性",
            "ko" to "항공용 고강성",
            "th" to "เกรดอากาศยาน แข็งแกร่งสูง"
        ),
        "material_card_process" to mapOf(
            "zh-Hant" to "工藝指標",
            "en" to "Process",
            "zh-Hans" to "工艺指标",
            "ja" to "加工仕様",
            "ko" to "공정 지표",
            "th" to "กระบวนการผลิต"
        ),
        "material_card_title" to mapOf(
            "zh-Hant" to "材料規格",
            "en" to "Material spec",
            "zh-Hans" to "材料规格",
            "ja" to "材料仕様",
            "ko" to "재료 사양",
            "th" to "ข้อมูลจำเพาะวัสดุ"
        ),
        "material_card_trait" to mapOf(
            "zh-Hant" to "特性",
            "en" to "Properties",
            "zh-Hans" to "特性",
            "ja" to "特性",
            "ko" to "특성",
            "th" to "คุณสมบัติ"
        ),
        "material_desc_copper" to mapOf(
            "zh-Hant" to "偏紅的金屬光澤，高光柔和。",
            "en" to "Warm reddish metallic sheen with soft specular tone.",
            "zh-Hans" to "偏红的金属光泽，高光柔和。",
            "ja" to "赤みのある金属光沢。やわらかなハイライト。",
            "ko" to "붉은빛 금속 광택, 부드러운 하이라이트.",
            "th" to "ประกายโลหะอมแดง ไฮไลต์นุ่มนวล"
        ),
        "material_desc_gold" to mapOf(
            "zh-Hant" to "100% 純金屬金，帶暖調鏡面反射。",
            "en" to "100% metallic gold with warm mirror specular reflection.",
            "zh-Hans" to "100% 纯金属金，带暖调镜面反射。",
            "ja" to "100% 金属の金。温かみのある鏡面反射。",
            "ko" to "100% 금속 금, 따뜻한 거울 반사.",
            "th" to "ทองคำโลหะ 100% สะท้อนเงาแบบกระจกโทนอุ่น"
        ),
        "material_desc_granite" to mapOf(
            "zh-Hant" to "有顆粒質感的礦石，自然漫反射。",
            "en" to "Textured mineral rock with natural granular diffusion.",
            "zh-Hans" to "有颗粒质感的矿石，自然漫反射。",
            "ja" to "粒状の質感を持つ鉱石。自然な拡散反射。",
            "ko" to "알갱이 질감의 광물 암석, 자연스러운 확산.",
            "th" to "หินแร่ผิวหยาบเป็นเม็ด สะท้อนแสงกระจายตามธรรมชาติ"
        ),
        "material_desc_iron" to mapOf(
            "zh-Hant" to "深色霧面工業鋼，質感厚重。",
            "en" to "Dark matte industrial steel with robust weight appearance.",
            "zh-Hans" to "深色哑光工业钢，质感厚重。",
            "ja" to "ダークなマット仕上げの工業用鋼。重厚な見た目。",
            "ko" to "어두운 무광 산업용 강철, 묵직한 느낌.",
            "th" to "เหล็กอุตสาหกรรมสีเข้มผิวด้าน ดูหนักแน่น"
        ),
        "material_desc_marble" to mapOf(
            "zh-Hant" to "拋光石材，微透光並帶細緻紋路。",
            "en" to "Polished stone with subtle translucency and delicate veins.",
            "zh-Hans" to "抛光石材，微透光并带细致纹路。",
            "ja" to "磨かれた石材。わずかな透明感と繊細な模様。",
            "ko" to "광택 처리된 석재, 은은한 투명감과 섬세한 결.",
            "th" to "หินขัดมัน โปร่งแสงเล็กน้อย มีลายเส้นละเอียด"
        ),
        "material_desc_obsidian" to mapOf(
            "zh-Hant" to "火山玻璃，對比強烈、光澤明亮。",
            "en" to "Volcanic glass with deep contrast and glossy sheen.",
            "zh-Hans" to "火山玻璃，对比强烈、光泽明亮。",
            "ja" to "火山ガラス。深いコントラストと艶やかな光沢。",
            "ko" to "화산 유리, 깊은 대비와 윤기 나는 광택.",
            "th" to "แก้วภูเขาไฟ คอนทราสต์เข้มและเงางาม"
        ),
        "material_desc_plastic" to mapOf(
            "zh-Hant" to "表面平滑的合成高分子，高光均衡。",
            "en" to "Smooth synthetic polymer with balanced specular highlights.",
            "zh-Hans" to "表面平滑的合成高分子，高光均衡。",
            "ja" to "なめらかな合成樹脂。ハイライトのバランスが良い質感。",
            "ko" to "매끄러운 합성 고분자, 균형 잡힌 하이라이트.",
            "th" to "พอลิเมอร์สังเคราะห์ผิวเรียบ ไฮไลต์สมดุล"
        ),
        "material_desc_silver" to mapOf(
            "zh-Hant" to "高反射率純銀，帶光亮鉻質感。",
            "en" to "High-reflectance pure silver with radiant chrome finish.",
            "zh-Hans" to "高反射率纯银，带光亮铬质感。",
            "ja" to "高反射率の純銀。輝くクロームの仕上げ。",
            "ko" to "반사율이 높은 순은, 빛나는 크롬 마감.",
            "th" to "เงินแท้สะท้อนแสงสูง ผิวโครเมียมแวววาว"
        ),
        "material_desc_wood" to mapOf(
            "zh-Hant" to "天然有機紋理，柔和漫反射。",
            "en" to "Natural organic grain with warm diffuse scattering.",
            "zh-Hans" to "天然有机纹理，柔和漫反射。",
            "ja" to "自然な木目。やわらかな拡散反射。",
            "ko" to "자연스러운 나뭇결, 따뜻한 확산 반사.",
            "th" to "ลายไม้ธรรมชาติ สะท้อนแสงกระจายนุ่มนวล"
        ),
        "material_pcabs_spec" to mapOf(
            "zh-Hant" to "UL94 V0 耐燃 / 模具咬花皮紋表面",
            "en" to "UL94 V-0 / textured mould finish",
            "zh-Hans" to "UL94 V0 耐燃 / 模具咬花皮纹表面",
            "ja" to "UL94 V-0／シボ加工表面",
            "ko" to "UL94 V-0 / 시보 텍스처 표면",
            "th" to "UL94 V-0 / ผิวลายหนังจากแม่พิมพ์"
        ),
        "material_pcabs_trait" to mapOf(
            "zh-Hant" to "阻燃抗衝擊",
            "en" to "Flame-retardant, impact-resistant",
            "zh-Hans" to "阻燃抗冲击",
            "ja" to "難燃・耐衝撃",
            "ko" to "난연·내충격",
            "th" to "หน่วงไฟ ทนแรงกระแทก"
        ),
        "material_pom_spec" to mapOf(
            "zh-Hant" to "摩擦係數 0.25 / 齒輪與軸承滑塊專用",
            "en" to "Friction 0.25 / gears, bearings, sliders",
            "zh-Hans" to "摩擦系数 0.25 / 齿轮与轴承滑块专用",
            "ja" to "摩擦係数 0.25／歯車・軸受・スライダー向け",
            "ko" to "마찰계수 0.25 / 기어·베어링·슬라이더용",
            "th" to "สัมประสิทธิ์แรงเสียดทาน 0.25 / เฟือง แบริ่ง สไลเดอร์"
        ),
        "material_pom_trait" to mapOf(
            "zh-Hant" to "耐磨自潤滑",
            "en" to "Wear-resistant, self-lubricating",
            "zh-Hans" to "耐磨自润滑",
            "ja" to "耐摩耗・自己潤滑",
            "ko" to "내마모·자기윤활",
            "th" to "ทนสึกหรอ หล่อลื่นในตัว"
        ),
        "material_skd11_spec" to mapOf(
            "zh-Hant" to "淬火回火硬度 HRC 58-62 / 精密沖壓沖頭",
            "en" to "HRC 58–62 quenched and tempered / precision punches",
            "zh-Hans" to "淬火回火硬度 HRC 58-62 / 精密冲压冲头",
            "ja" to "焼入焼戻し HRC 58–62／精密プレスパンチ",
            "ko" to "담금질·뜨임 HRC 58–62 / 정밀 프레스 펀치",
            "th" to "ชุบแข็งและอบคืนตัว HRC 58–62 / พันช์ปั๊มความแม่นยำสูง"
        ),
        "material_skd11_trait" to mapOf(
            "zh-Hant" to "極高耐磨性",
            "en" to "Very high wear resistance",
            "zh-Hans" to "极高耐磨性",
            "ja" to "極めて高い耐摩耗性",
            "ko" to "초고내마모성",
            "th" to "ทนการสึกหรอสูงมาก"
        ),
        "material_specs_card" to mapOf(
            "zh-Hant" to "材料規格卡",
            "en" to "Material Specs Card",
            "zh-Hans" to "材料规格卡",
            "ja" to "材料仕様カード",
            "ko" to "재료 사양 카드",
            "th" to "การ์ดสเปกวัสดุ"
        )
    )

    private fun part16(): Map<String, Map<String, String>> = mapOf(
        "material_specs_tip" to mapOf(
            "zh-Hant" to "插入工程材質與表面工藝標籤",
            "en" to "Insert Engineering Material & Specs Label",
            "zh-Hans" to "插入工程材质与表面工艺标签",
            "ja" to "材質・表面処理仕様ラベルを挿入",
            "ko" to "엔지니어링 재질 및 표면 사양 라벨 삽입",
            "th" to "แทรกฉลากวัสดุและข้อกำหนดทางวิศวกรรม"
        ),
        "material_style" to mapOf(
            "zh-Hant" to "外觀材質",
            "en" to "Material",
            "zh-Hans" to "外观材质",
            "ja" to "マテリアル",
            "ko" to "재질 특성",
            "th" to "คุณสมบัติวัสดุ"
        ),
        "material_sus304_spec" to mapOf(
            "zh-Hant" to "抗拉強度 ≥520 MPa / 表面拉絲鈍化處理",
            "en" to "Tensile ≥520 MPa / brushed and passivated",
            "zh-Hans" to "抗拉强度 ≥520 MPa / 表面拉丝钝化处理",
            "ja" to "引張強さ ≥520 MPa／ヘアライン・不動態化",
            "ko" to "인장강도 ≥520 MPa / 헤어라인·부동태 처리",
            "th" to "ความต้านแรงดึง ≥520 MPa / ขัดลายเส้นและพาสซิเวต"
        ),
        "material_sus304_trait" to mapOf(
            "zh-Hant" to "奧氏體防蝕",
            "en" to "Austenitic, corrosion-resistant",
            "zh-Hans" to "奥氏体防蚀",
            "ja" to "オーステナイト系・耐食",
            "ko" to "오스테나이트계 내식",
            "th" to "ออสเทนนิติก ทนการกัดกร่อน"
        ),
        "math_backspace" to mapOf(
            "zh-Hant" to "退格",
            "en" to "Delete",
            "zh-Hans" to "退格",
            "ja" to "一文字削除",
            "ko" to "삭제",
            "th" to "ลบ"
        ),
        "math_calc" to mapOf(
            "zh-Hant" to "算式計算",
            "en" to "Math Calculator",
            "zh-Hans" to "算式计算",
            "ja" to "数式計算",
            "ko" to "수식 계산",
            "th" to "คำนวณคณิตศาสตร์"
        ),
        "math_calculate" to mapOf(
            "zh-Hant" to "計算求解",
            "en" to "Calculate",
            "zh-Hans" to "计算求解",
            "ja" to "計算実行",
            "ko" to "계산하기",
            "th" to "คำนวณผลลัพธ์"
        ),
        "math_card_border" to mapOf(
            "zh-Hant" to "保留卡片邊框",
            "en" to "Keep Card Border",
            "zh-Hans" to "保留卡片边框",
            "ja" to "カードの枠線を維持",
            "ko" to "카드 테두리 유지",
            "th" to "เก็บเส้นขอบการ์ด"
        ),
        "math_clear" to mapOf(
            "zh-Hant" to "清除",
            "en" to "Clear",
            "zh-Hans" to "清除",
            "ja" to "クリア",
            "ko" to "지우기",
            "th" to "ล้าง"
        ),
        "math_const_01" to mapOf(
            "zh-Hant" to "圓周率 π",
            "en" to "Pi π",
            "zh-Hans" to "圆周率 π",
            "ja" to "円周率 π",
            "ko" to "원주율 π",
            "th" to "ค่าพาย π"
        ),
        "math_const_02" to mapOf(
            "zh-Hant" to "自然常數 e",
            "en" to "Euler's number e",
            "zh-Hans" to "自然常数 e",
            "ja" to "自然対数の底 e",
            "ko" to "자연상수 e",
            "th" to "ค่าคงที่ธรรมชาติ e"
        ),
        "math_const_03" to mapOf(
            "zh-Hant" to "黃金比例 φ",
            "en" to "Golden ratio φ",
            "zh-Hans" to "黄金比例 φ",
            "ja" to "黄金比 φ",
            "ko" to "황금비 φ",
            "th" to "อัตราส่วนทองคำ φ"
        ),
        "math_const_04" to mapOf(
            "zh-Hant" to "光速 c",
            "en" to "Speed of light c",
            "zh-Hans" to "光速 c",
            "ja" to "光速 c",
            "ko" to "광속 c",
            "th" to "ความเร็วแสง c"
        ),
        "math_const_05" to mapOf(
            "zh-Hant" to "重力加速度 g",
            "en" to "Gravitational acceleration g",
            "zh-Hans" to "重力加速度 g",
            "ja" to "重力加速度 g",
            "ko" to "중력 가속도 g",
            "th" to "ความเร่งโน้มถ่วง g"
        ),
        "math_const_06" to mapOf(
            "zh-Hant" to "普朗克常數 h",
            "en" to "Planck constant h",
            "zh-Hans" to "普朗克常数 h",
            "ja" to "プランク定数 h",
            "ko" to "플랑크 상수 h",
            "th" to "ค่าคงที่ของพลังค์ h"
        ),
        "math_const_07" to mapOf(
            "zh-Hant" to "波茲曼常數 k",
            "en" to "Boltzmann constant k",
            "zh-Hans" to "玻尔兹曼常数 k",
            "ja" to "ボルツマン定数 k",
            "ko" to "볼츠만 상수 k",
            "th" to "ค่าคงที่โบลต์ซมันน์ k"
        ),
        "math_const_08" to mapOf(
            "zh-Hant" to "亞佛加厥常數 Na",
            "en" to "Avogadro constant Nₐ",
            "zh-Hans" to "阿伏伽德罗常数 Nₐ",
            "ja" to "アボガドロ定数 Nₐ",
            "ko" to "아보가드로 상수 Nₐ",
            "th" to "ค่าคงที่อาโวกาโดร Nₐ"
        ),
        "math_error" to mapOf(
            "zh-Hant" to "算式格式無效或無法計算",
            "en" to "Invalid formula or syntax error",
            "zh-Hans" to "算式格式无效或无法计算",
            "ja" to "無効な数式または構文エラー",
            "ko" to "잘못된 수식 형식",
            "th" to "รูปแบบสูตรไม่ถูกต้อง"
        ),
        "math_error_bad_expression" to mapOf(
            "zh-Hant" to "看不懂這個算式",
            "en" to "Can’t read that expression",
            "zh-Hans" to "看不懂这个算式",
            "ja" to "この式は解釈できません",
            "ko" to "이 수식을 이해할 수 없습니다",
            "th" to "ไม่เข้าใจนิพจน์นี้"
        ),
        "math_error_empty" to mapOf(
            "zh-Hant" to "算式不可為空",
            "en" to "Enter an expression",
            "zh-Hans" to "算式不可为空",
            "ja" to "式を入力してください",
            "ko" to "수식을 입력하세요",
            "th" to "กรุณาใส่นิพจน์"
        ),
        "math_error_not_finite" to mapOf(
            "zh-Hant" to "算不出有限的結果（可能除以零）",
            "en" to "No finite result (division by zero?)",
            "zh-Hans" to "算不出有限的结果（可能除以零）",
            "ja" to "有限の結果になりません（0 除算？）",
            "ko" to "유한한 결과가 없습니다 (0으로 나눔?)",
            "th" to "ไม่ได้ผลลัพธ์จำกัด (หารด้วยศูนย์?)"
        ),
        "math_expression" to mapOf(
            "zh-Hant" to "輸入或手寫算式（例如: 125 * 8 + 45 或 sqrt(144)）",
            "en" to "Enter formula (e.g. 125 * 8 + 45 or sqrt(144))",
            "zh-Hans" to "输入或手写算式（例如: 125 * 8 + 45 或 sqrt(144)）",
            "ja" to "数式を入力（例: 125 * 8 + 45 または sqrt(144)）",
            "ko" to "수식 입력 (예: 125 * 8 + 45 또는 sqrt(144))",
            "th" to "ป้อนสูตร (เช่น 125 * 8 + 45 หรือ sqrt(144))"
        ),
        "math_input_hint" to mapOf(
            "zh-Hant" to "請在上方輸入算式後點擊「計算求解」",
            "en" to "Enter formula above and click 'Calculate Solution'",
            "zh-Hans" to "请在上方输入算式后点击“计算求解”",
            "ja" to "上部に計算式を入力して「計算実行」をクリックしてください",
            "ko" to "위에 수식을 입력한 후 '계산 실행'을 클릭하세요",
            "th" to "ป้อนสูตรด้านบนแล้วคลิก 'คำนวณผลลัพธ์'"
        ),
        "math_insert" to mapOf(
            "zh-Hant" to "將算式貼入畫布",
            "en" to "Insert to Canvas",
            "zh-Hans" to "将算式贴入画布",
            "ja" to "キャンバスに貼付",
            "ko" to "캔버스에 삽입",
            "th" to "แทรกลงในผืนผ้าใบ"
        ),
        "math_insert_card" to mapOf(
            "zh-Hant" to "插入算式卡片",
            "en" to "Insert Formula Card",
            "zh-Hans" to "插入算式卡片",
            "ja" to "数式カードとして挿入",
            "ko" to "수식 카드로 삽입",
            "th" to "แทรกเป็นการ์ดสูตร"
        ),
        "math_insert_editable" to mapOf(
            "zh-Hant" to "插入可編輯文字",
            "en" to "Insert Editable Text",
            "zh-Hans" to "插入可编辑文字",
            "ja" to "編集可能なテキストとして挿入",
            "ko" to "편집 가능한 텍스트로 삽입",
            "th" to "แทรกเป็นข้อความที่แก้ไขได้"
        ),
        "math_placeholder" to mapOf(
            "zh-Hant" to "例如: 125 * 8 + 45",
            "en" to "e.g., 125 * 8 + 45",
            "zh-Hans" to "例如: 125 * 8 + 45",
            "ja" to "例: 125 * 8 + 45",
            "ko" to "예: 125 * 8 + 45",
            "th" to "เช่น: 125 * 8 + 45"
        ),
        "math_sec_01" to mapOf(
            "zh-Hant" to "微積分與微分方程",
            "en" to "Calculus & differential equations",
            "zh-Hans" to "微积分与微分方程",
            "ja" to "微積分と微分方程式",
            "ko" to "미적분과 미분방정식",
            "th" to "แคลคูลัสและสมการเชิงอนุพันธ์"
        ),
        "math_sec_02" to mapOf(
            "zh-Hant" to "工數、向量與場論",
            "en" to "Engineering math, vectors & fields",
            "zh-Hans" to "工数、向量与场论",
            "ja" to "工業数学・ベクトル・場の理論",
            "ko" to "공업수학·벡터·장론",
            "th" to "คณิตศาสตร์วิศวกรรม เวกเตอร์ และสนาม"
        ),
        "math_sec_03" to mapOf(
            "zh-Hant" to "運算子與關係",
            "en" to "Operators & relations",
            "zh-Hans" to "运算符与关系",
            "ja" to "演算子と関係",
            "ko" to "연산자와 관계",
            "th" to "ตัวดำเนินการและความสัมพันธ์"
        ),
        "math_sec_04" to mapOf(
            "zh-Hant" to "集合與邏輯",
            "en" to "Sets & logic",
            "zh-Hans" to "集合与逻辑",
            "ja" to "集合と論理",
            "ko" to "집합과 논리",
            "th" to "เซตและตรรกศาสตร์"
        ),
        "math_sec_05" to mapOf(
            "zh-Hant" to "希臘字母 (小寫)",
            "en" to "Greek letters (lowercase)",
            "zh-Hans" to "希腊字母（小写）",
            "ja" to "ギリシャ文字（小文字）",
            "ko" to "그리스 문자 (소문자)",
            "th" to "ตัวอักษรกรีก (ตัวพิมพ์เล็ก)"
        ),
        "math_sec_06" to mapOf(
            "zh-Hant" to "希臘字母 (大寫)",
            "en" to "Greek letters (uppercase)",
            "zh-Hans" to "希腊字母（大写）",
            "ja" to "ギリシャ文字（大文字）",
            "ko" to "그리스 문자 (대문자)",
            "th" to "ตัวอักษรกรีก (ตัวพิมพ์ใหญ่)"
        ),
        "math_sec_07" to mapOf(
            "zh-Hant" to "括號與矩陣符號",
            "en" to "Brackets & matrix symbols",
            "zh-Hans" to "括号与矩阵符号",
            "ja" to "括弧と行列の記号",
            "ko" to "괄호와 행렬 기호",
            "th" to "วงเล็บและสัญลักษณ์เมทริกซ์"
        ),
        "math_symbols" to mapOf(
            "zh-Hant" to "數學代號",
            "en" to "Math Symbols",
            "zh-Hans" to "数学代号",
            "ja" to "数学記号",
            "ko" to "수학 기호",
            "th" to "สัญลักษณ์ทางคณิตศาสตร์"
        ),
        "math_tab_calc" to mapOf(
            "zh-Hant" to "科學計算機",
            "en" to "Calculator",
            "zh-Hans" to "科学计算器",
            "ja" to "関数電卓",
            "ko" to "공학용 계산기",
            "th" to "เครื่องคิดเลขวิทยาศาสตร์"
        ),
        "math_tab_calculus" to mapOf(
            "zh-Hant" to "微積分與工數",
            "en" to "Calculus & Eng",
            "zh-Hans" to "微积分与工数",
            "ja" to "微積分・工学数学",
            "ko" to "미적분 및 공학수학",
            "th" to "แคลคูลัสและวิศวกรรม"
        ),
        "math_tab_symbols" to mapOf(
            "zh-Hant" to "數學符號庫",
            "en" to "All Math Symbols",
            "zh-Hans" to "数学符号库",
            "ja" to "数学記号一覧",
            "ko" to "전체 수학 기호",
            "th" to "สัญลักษณ์ทั้งหมด"
        ),
        "math_tab_units" to mapOf(
            "zh-Hant" to "常數與單位",
            "en" to "Constants & Units",
            "zh-Hans" to "常数与单位",
            "ja" to "定数・単位",
            "ko" to "상수 및 단위",
            "th" to "ค่าคงที่และหน่วย"
        ),
        "math_tpl_01" to mapOf(
            "zh-Hant" to "微積分 - 多項式導數表列",
            "en" to "Calculus – derivative of a polynomial",
            "zh-Hans" to "微积分 - 多项式导数列表",
            "ja" to "微積分 – 多項式の導関数",
            "ko" to "미적분 – 다항식의 도함수",
            "th" to "แคลคูลัส – อนุพันธ์ของพหุนาม"
        ),
        "math_tpl_02" to mapOf(
            "zh-Hant" to "微積分 - 定積分求值",
            "en" to "Calculus – definite integral",
            "zh-Hans" to "微积分 - 定积分求值",
            "ja" to "微積分 – 定積分の値",
            "ko" to "미적분 – 정적분 계산",
            "th" to "แคลคูลัส – ปริพันธ์จำกัดเขต"
        ),
        "math_tpl_03" to mapOf(
            "zh-Hant" to "微積分 - 瑕積分",
            "en" to "Calculus – improper integral",
            "zh-Hans" to "微积分 - 瑕积分",
            "ja" to "微積分 – 広義積分",
            "ko" to "미적분 – 이상적분",
            "th" to "แคลคูลัส – ปริพันธ์ไม่ตรงแบบ"
        ),
        "math_tpl_04" to mapOf(
            "zh-Hant" to "工數 - 傅立葉級數表列",
            "en" to "Engineering math – Fourier series",
            "zh-Hans" to "工数 - 傅立叶级数",
            "ja" to "工業数学 – フーリエ級数",
            "ko" to "공업수학 – 푸리에 급수",
            "th" to "คณิตศาสตร์วิศวกรรม – อนุกรมฟูริเยร์"
        ),
        "math_tpl_05" to mapOf(
            "zh-Hant" to "工數 - 拉普拉斯轉換",
            "en" to "Engineering math – Laplace transform",
            "zh-Hans" to "工数 - 拉普拉斯变换",
            "ja" to "工業数学 – ラプラス変換",
            "ko" to "공업수학 – 라플라스 변환",
            "th" to "คณิตศาสตร์วิศวกรรม – การแปลงลาปลาซ"
        ),
        "math_tpl_06" to mapOf(
            "zh-Hant" to "工數 - 二階常微分ODE",
            "en" to "Engineering math – 2nd-order ODE",
            "zh-Hans" to "工数 - 二阶常微分方程",
            "ja" to "工業数学 – 2 階常微分方程式",
            "ko" to "공업수학 – 2계 상미분방정식",
            "th" to "คณิตศาสตร์วิศวกรรม – ODE อันดับสอง"
        ),
        "math_tpl_07" to mapOf(
            "zh-Hant" to "向量分析 - 梯度運算",
            "en" to "Vector calculus – gradient",
            "zh-Hans" to "向量分析 - 梯度运算",
            "ja" to "ベクトル解析 – 勾配",
            "ko" to "벡터 해석 – 기울기",
            "th" to "แคลคูลัสเวกเตอร์ – เกรเดียนต์"
        ),
        "math_tpl_08" to mapOf(
            "zh-Hant" to "向量分析 - 散度運算",
            "en" to "Vector calculus – divergence",
            "zh-Hans" to "向量分析 - 散度运算",
            "ja" to "ベクトル解析 – 発散",
            "ko" to "벡터 해석 – 발산",
            "th" to "แคลคูลัสเวกเตอร์ – ไดเวอร์เจนซ์"
        ),
        "math_tpl_09" to mapOf(
            "zh-Hant" to "向量分析 - 旋度運算",
            "en" to "Vector calculus – curl",
            "zh-Hans" to "向量分析 - 旋度运算",
            "ja" to "ベクトル解析 – 回転",
            "ko" to "벡터 해석 – 회전",
            "th" to "แคลคูลัสเวกเตอร์ – เคิร์ล"
        ),
        "math_tpl_10" to mapOf(
            "zh-Hant" to "線性代數 - 特徵方程式",
            "en" to "Linear algebra – characteristic equation",
            "zh-Hans" to "线性代数 - 特征方程",
            "ja" to "線形代数 – 特性方程式",
            "ko" to "선형대수 – 특성방정식",
            "th" to "พีชคณิตเชิงเส้น – สมการลักษณะเฉพาะ"
        ),
        "math_tpl_11" to mapOf(
            "zh-Hant" to "複變數 - 歐拉公式",
            "en" to "Complex analysis – Euler's formula",
            "zh-Hans" to "复变函数 - 欧拉公式",
            "ja" to "複素解析 – オイラーの公式",
            "ko" to "복소해석 – 오일러 공식",
            "th" to "การวิเคราะห์เชิงซ้อน – สูตรของออยเลอร์"
        ),
        "math_tpl_12" to mapOf(
            "zh-Hant" to "高斯積分",
            "en" to "Gaussian integral",
            "zh-Hans" to "高斯积分",
            "ja" to "ガウス積分",
            "ko" to "가우스 적분",
            "th" to "ปริพันธ์เกาส์เซียน"
        ),
        "math_tpl_13" to mapOf(
            "zh-Hant" to "泰勒展開式",
            "en" to "Taylor expansion",
            "zh-Hans" to "泰勒展开式",
            "ja" to "テイラー展開",
            "ko" to "테일러 전개",
            "th" to "การกระจายเทย์เลอร์"
        ),
        "math_tpl_14" to mapOf(
            "zh-Hant" to "工數 - 熱傳導方程式",
            "en" to "Engineering math – heat equation",
            "zh-Hans" to "工数 - 热传导方程",
            "ja" to "工業数学 – 熱伝導方程式",
            "ko" to "공업수학 – 열전도 방정식",
            "th" to "คณิตศาสตร์วิศวกรรม – สมการความร้อน"
        ),
        "math_tpl_15" to mapOf(
            "zh-Hant" to "工數 - 波動方程式",
            "en" to "Engineering math – wave equation",
            "zh-Hans" to "工数 - 波动方程",
            "ja" to "工業数学 – 波動方程式",
            "ko" to "공업수학 – 파동방정식",
            "th" to "คณิตศาสตร์วิศวกรรม – สมการคลื่น"
        ),
        "math_value_prefix" to mapOf(
            "zh-Hant" to "數值",
            "en" to "Value",
            "zh-Hans" to "数值",
            "ja" to "値",
            "ko" to "값",
            "th" to "ค่า"
        ),
        "mic_permission_blocked" to mapOf(
            "zh-Hant" to "麥克風權限被拒。要錄音的話，請到系統設定裡打開。",
            "en" to "Microphone permission is denied. To record, turn it on in system settings.",
            "zh-Hans" to "麦克风权限被拒。要录音的话，请到系统设置里打开。",
            "ja" to "マイクの権限が拒否されています。録音するには設定でオンにしてください。",
            "ko" to "마이크 권한이 거부되었습니다. 녹음하려면 시스템 설정에서 켜 주세요.",
            "th" to "สิทธิ์ไมโครโฟนถูกปฏิเสธ หากต้องการบันทึกเสียง โปรดเปิดในการตั้งค่าระบบ"
        ),
        "mic_permission_denied" to mapOf(
            "zh-Hant" to "沒有麥克風權限，無法錄音",
            "en" to "Microphone permission denied; cannot record",
            "zh-Hans" to "没有麦克风权限，无法录音",
            "ja" to "マイクの権限がないため録音できません",
            "ko" to "마이크 권한이 없어 녹음할 수 없습니다",
            "th" to "ไม่ได้รับสิทธิ์ไมโครโฟน จึงบันทึกเสียงไม่ได้"
        ),
        "mic_permission_msg" to mapOf(
            "zh-Hant" to "Kairumo 需要麥克風權限以進行課堂與會議錄音，並與手寫筆記同步對齊。請點擊「前往系統設定」開啟權限。",
            "en" to "Kairumo needs microphone access to record lectures and sync audio with your handwriting. Tap 'Open Settings' to grant permission.",
            "zh-Hans" to "Kairumo 需要麦克风权限以进行课堂与会议录音，并与手写笔记同步对齐。请点击“前往系统设置”开启权限。",
            "ja" to "Kairumo は授業や会議の録音と筆跡を同期させるためにマイクへのアクセス権が必要です。「設定を開く」をタップして許可してください。",
            "ko" to "Kairumo 는 수업 및 회의 녹음을 손글씨와 동기화하기 위해 마이크 권한이 필요합니다. '설정 열기'를 눌러 권한을 허용해주세요.",
            "th" to "Kairumo ต้องการสิทธิ์เข้าถึงไมโครโฟนเพื่อบันทึกเสียงและจัดตำแหน่งให้ตรงกับการเขียนของคุณ แตะ 'เปิดการตั้งค่า' เพื่ออนุญาต"
        ),
        "mic_permission_title" to mapOf(
            "zh-Hant" to "需要麥克風使用權限",
            "en" to "Microphone Access Required",
            "zh-Hans" to "需要麦克风使用权限",
            "ja" to "マイクへのアクセス権が必要です",
            "ko" to "마이크 접근 권한 필요",
            "th" to "จำเป็นต้องได้รับอนุญาตให้ใช้ไมโครโฟน"
        ),
        "migration_converted_count" to mapOf(
            "zh-Hant" to "已轉換 %@ 本",
            "en" to "%@ notebooks converted",
            "zh-Hans" to "已转换 %@ 本",
            "ja" to "%@ 冊を変換済み",
            "ko" to "%@권 변환됨",
            "th" to "แปลงแล้ว %@ เล่ม"
        ),
        "migration_explainer" to mapOf(
            "zh-Hant" to "轉換後的檔案可在 Android 版開啟。原始筆記不會被更動，轉換前會自動備份，隨時可以還原。",
            "en" to "Converted files open in the Android version. Your original notes are never modified; a backup is made first and you can restore it at any time.",
            "zh-Hans" to "转换后的文件可在 Android 版打开。原始笔记不会被更动，转换前会自动备份，随时可以还原。",
            "ja" to "変換後のファイルは Android 版で開けます。元のノートは変更されません。変換前に自動でバックアップを作成し、いつでも復元できます。",
            "ko" to "변환된 파일은 Android 버전에서 열 수 있습니다. 원본 노트는 변경되지 않으며, 변환 전에 백업이 만들어져 언제든 복원할 수 있습니다.",
            "th" to "ไฟล์ที่แปลงแล้วเปิดได้ในเวอร์ชัน Android ข้อมูลบันทึกต้นฉบับจะไม่ถูกแก้ไข และจะสำรองข้อมูลก่อนแปลงเสมอ คุณกู้คืนได้ทุกเมื่อ"
        ),
        "migration_never_run" to mapOf(
            "zh-Hant" to "尚未轉換",
            "en" to "Not converted yet",
            "zh-Hans" to "尚未转换",
            "ja" to "未変換",
            "ko" to "아직 변환하지 않음",
            "th" to "ยังไม่ได้แปลง"
        ),
        "migration_result_summary" to mapOf(
            "zh-Hant" to "成功 %@、略過 %@、失敗 %@",
            "en" to "%@ succeeded, %@ skipped, %@ failed",
            "zh-Hans" to "成功 %@、跳过 %@、失败 %@",
            "ja" to "成功 %@、スキップ %@、失敗 %@",
            "ko" to "성공 %@, 건너뜀 %@, 실패 %@",
            "th" to "สำเร็จ %@ ข้าม %@ ล้มเหลว %@"
        ),
        "migration_rollback" to mapOf(
            "zh-Hant" to "還原備份",
            "en" to "Restore Backup",
            "zh-Hans" to "还原备份",
            "ja" to "バックアップを復元",
            "ko" to "백업 복원",
            "th" to "กู้คืนข้อมูลสำรอง"
        ),
        "migration_rollback_done" to mapOf(
            "zh-Hant" to "已從備份還原",
            "en" to "Restored from backup",
            "zh-Hans" to "已从备份还原",
            "ja" to "バックアップから復元しました",
            "ko" to "백업에서 복원했습니다",
            "th" to "กู้คืนจากข้อมูลสำรองแล้ว"
        ),
        "migration_run" to mapOf(
            "zh-Hant" to "轉換為跨平台格式",
            "en" to "Convert to Cross-Platform Format",
            "zh-Hans" to "转换为跨平台格式",
            "ja" to "クロスプラットフォーム形式に変換",
            "ko" to "크로스플랫폼 형식으로 변환",
            "th" to "แปลงเป็นรูปแบบข้ามแพลตฟอร์ม"
        ),
        "migration_running" to mapOf(
            "zh-Hant" to "轉換中…",
            "en" to "Converting…",
            "zh-Hans" to "转换中…",
            "ja" to "変換中…",
            "ko" to "변환 중…",
            "th" to "กำลังแปลง…"
        ),
        "migration_section" to mapOf(
            "zh-Hant" to "跨平台格式",
            "en" to "Cross-Platform Format",
            "zh-Hans" to "跨平台格式",
            "ja" to "クロスプラットフォーム形式",
            "ko" to "크로스플랫폼 형식",
            "th" to "รูปแบบข้ามแพลตฟอร์ม"
        ),
        "migration_status" to mapOf(
            "zh-Hant" to "狀態",
            "en" to "Status",
            "zh-Hans" to "状态",
            "ja" to "状態",
            "ko" to "상태",
            "th" to "สถานะ"
        ),
        "milestone_automatic" to mapOf(
            "zh-Hant" to "自動",
            "en" to "Automatic",
            "zh-Hans" to "自动",
            "ja" to "自動",
            "ko" to "자동",
            "th" to "อัตโนมัติ"
        ),
        "milestone_before_restore" to mapOf(
            "zh-Hant" to "還原「%@」之前",
            "en" to "Before restoring “%@”",
            "zh-Hans" to "还原「%@」之前",
            "ja" to "「%@」に戻す前",
            "ko" to "“%@” 복원 전",
            "th" to "ก่อนกู้คืน “%@”"
        ),
        "milestone_empty" to mapOf(
            "zh-Hant" to "還沒有里程碑。選「建立協同快照」記下現在這一刻。",
            "en" to "No milestones yet. Choose “Create Snapshot” to mark this moment.",
            "zh-Hans" to "还没有里程碑。选「创建协同快照」记下现在这一刻。",
            "ja" to "マイルストーンはまだありません。「スナップショットを作成」で今を記録できます。",
            "ko" to "아직 마일스톤이 없습니다. “스냅샷 생성”을 선택해 지금을 기록하세요.",
            "th" to "ยังไม่มีเหตุการณ์สำคัญ เลือก “สร้างสแนปช็อต” เพื่อบันทึกช่วงเวลานี้"
        ),
        "milestone_legacy" to mapOf(
            "zh-Hant" to "舊版",
            "en" to "Legacy",
            "zh-Hans" to "旧版",
            "ja" to "旧形式",
            "ko" to "이전 형식",
            "th" to "รูปแบบเดิม"
        ),
        "milestone_restore_confirm" to mapOf(
            "zh-Hant" to "還原到「%@」？之後的變更會被收起來，但不會消失 —— 系統會自動留一個「還原之前」的里程碑讓你回來。",
            "en" to "Restore to “%@”? Later changes are set aside, not deleted — an automatic “before restore” milestone lets you come back.",
            "zh-Hans" to "还原到「%@」？之后的更改会被收起来，但不会消失 —— 系统会自动留一个「还原之前」的里程碑让你回来。",
            "ja" to "「%@」に戻しますか？以降の変更は削除されず、脇に置かれます。自動で「復元前」のマイルストーンが残るので戻せます。",
            "ko" to "“%@”(으)로 복원할까요? 이후 변경 사항은 삭제되지 않고 보관되며, 자동 “복원 전” 마일스톤으로 되돌아올 수 있습니다.",
            "th" to "กู้คืนไปยัง “%@” หรือไม่ การเปลี่ยนแปลงหลังจากนั้นจะถูกเก็บไว้ ไม่ได้ถูกลบ และมีเหตุการณ์สำคัญ “ก่อนกู้คืน” อัตโนมัติให้ย้อนกลับได้"
        ),
        "milestone_restore_failed" to mapOf(
            "zh-Hant" to "還原失敗，內容沒有被改動",
            "en" to "Restore failed; nothing was changed",
            "zh-Hans" to "还原失败，内容没有被改动",
            "ja" to "復元に失敗しました。内容は変更されていません",
            "ko" to "복원하지 못했습니다. 내용은 그대로입니다",
            "th" to "กู้คืนไม่สำเร็จ เนื้อหาไม่ถูกเปลี่ยน"
        ),
        "milestone_restored" to mapOf(
            "zh-Hant" to "已還原。要回到還原前，選「%@」",
            "en" to "Restored. To undo, choose “%@”",
            "zh-Hans" to "已还原。要回到还原前，选「%@」",
            "ja" to "復元しました。元に戻すには「%@」を選択",
            "ko" to "복원했습니다. 되돌리려면 “%@”를 선택하세요",
            "th" to "กู้คืนแล้ว หากต้องการย้อนกลับ ให้เลือก “%@”"
        ),
        "milestone_snapshots" to mapOf(
            "zh-Hant" to "里程碑快照時光機",
            "en" to "Milestone Snapshots",
            "zh-Hans" to "里程碑快照时光机",
            "ja" to "マイルストーンスナップショット",
            "ko" to "마일스톤 스냅샷",
            "th" to "สแนปช็อตเหตุการณ์สำคัญ"
        ),
        "minimal_toolbox" to mapOf(
            "zh-Hant" to "迷你工具列",
            "en" to "Mini toolbar",
            "zh-Hans" to "迷你工具栏",
            "ja" to "ミニツールバー",
            "ko" to "미니 도구 막대",
            "th" to "แถบเครื่องมือย่อ"
        ),
        "minimize_dialog" to mapOf(
            "zh-Hant" to "縮小視窗",
            "en" to "Minimize",
            "zh-Hans" to "缩小窗口",
            "ja" to "最小化",
            "ko" to "최소화",
            "th" to "ย่อหน้าต่าง"
        ),
        "mode_draw" to mapOf(
            "zh-Hant" to "手寫",
            "en" to "Draw",
            "zh-Hans" to "手写",
            "ja" to "手書き",
            "ko" to "필기",
            "th" to "เขียน"
        )
    )

    private fun part17(): Map<String, Map<String, String>> = mapOf(
        "mode_draw_badge" to mapOf(
            "zh-Hant" to "手寫模式",
            "en" to "Handwriting",
            "zh-Hans" to "手写模式",
            "ja" to "手書き",
            "ko" to "필기",
            "th" to "เขียนด้วยลายมือ"
        ),
        "mode_draw_hint" to mapOf(
            "zh-Hant" to "可以寫字。物件已鎖定，不會被拖到。",
            "en" to "Pen writes. Objects are locked.",
            "zh-Hans" to "可以写字。物件已锁定，不会被拖到。",
            "ja" to "ペンで書けます。オブジェクトは固定されています。",
            "ko" to "펜으로 씁니다. 객체는 고정됩니다.",
            "th" to "เขียนด้วยปากกาได้ วัตถุถูกล็อก"
        ),
        "mode_type" to mapOf(
            "zh-Hant" to "打字",
            "en" to "Type",
            "zh-Hans" to "打字",
            "ja" to "入力",
            "ko" to "입력",
            "th" to "พิมพ์"
        ),
        "mode_type_badge" to mapOf(
            "zh-Hant" to "打字與物件",
            "en" to "Typing & objects",
            "zh-Hans" to "打字与物件",
            "ja" to "入力とオブジェクト",
            "ko" to "입력·객체",
            "th" to "พิมพ์และวัตถุ"
        ),
        "mode_type_hint" to mapOf(
            "zh-Hant" to "筆不會畫線。點物件即可編輯，點兩下空白處新增文字方塊。",
            "en" to "Pen won't draw. Tap objects to edit; double-tap empty space for a text box.",
            "zh-Hans" to "笔不会画线。点物件即可编辑，双击空白处新增文字框。",
            "ja" to "ペンでは描けません。オブジェクトをタップして編集、空白をダブルタップでテキストボックス。",
            "ko" to "펜으로 그려지지 않습니다. 객체를 눌러 편집하고, 빈 곳을 두 번 눌러 텍스트 상자를 만드세요.",
            "th" to "ปากกาจะไม่วาด แตะวัตถุเพื่อแก้ไข แตะสองครั้งที่พื้นที่ว่างเพื่อสร้างกล่องข้อความ"
        ),
        "model3d_count" to mapOf(
            "zh-Hant" to "3D 模型",
            "en" to "3D",
            "zh-Hans" to "3D 模型",
            "ja" to "3D",
            "ko" to "3D",
            "th" to "3D"
        ),
        "model3d_default_title" to mapOf(
            "zh-Hant" to "3D 幾何模型",
            "en" to "3D geometric model",
            "zh-Hans" to "3D 几何模型",
            "ja" to "3D 幾何モデル",
            "ko" to "3D 기하 모델",
            "th" to "โมเดลเรขาคณิต 3 มิติ"
        ),
        "model3d_rotate_mode" to mapOf(
            "zh-Hant" to "旋轉",
            "en" to "Rotate",
            "zh-Hans" to "旋转",
            "ja" to "回転",
            "ko" to "회전",
            "th" to "หมุน"
        ),
        "model3d_studio" to mapOf(
            "zh-Hant" to "3D 模型工作室",
            "en" to "3D Model Studio",
            "zh-Hans" to "3D 模型工作室",
            "ja" to "3D モデルスタジオ",
            "ko" to "3D 모델 스튜디오",
            "th" to "สตูดิโอโมเดล 3D"
        ),
        "model3d_title" to mapOf(
            "zh-Hant" to "3D 幾何模型",
            "en" to "3D Model",
            "zh-Hans" to "3D 几何模型",
            "ja" to "3D 幾何モデル",
            "ko" to "3D 기하 모델",
            "th" to "โมเดลเรขาคณิต 3D"
        ),
        "model_3d" to mapOf(
            "zh-Hant" to "3D模型",
            "en" to "3D Model",
            "zh-Hans" to "3D模型",
            "ja" to "3Dモデル",
            "ko" to "3D 모델",
            "th" to "โมเดล 3 มิติ"
        ),
        "model_dl_bad_url" to mapOf(
            "zh-Hant" to "網址無效：%@",
            "en" to "Invalid address: %@",
            "zh-Hans" to "网址无效：%@",
            "ja" to "無効なアドレス：%@",
            "ko" to "잘못된 주소: %@",
            "th" to "ที่อยู่ไม่ถูกต้อง: %@"
        ),
        "model_dl_no_response" to mapOf(
            "zh-Hant" to "沒有 HTTP 回應",
            "en" to "No HTTP response",
            "zh-Hans" to "没有 HTTP 响应",
            "ja" to "HTTP 応答がありません",
            "ko" to "HTTP 응답이 없습니다",
            "th" to "ไม่มีการตอบกลับ HTTP"
        ),
        "model_download" to mapOf(
            "zh-Hant" to "下載",
            "en" to "Download",
            "zh-Hans" to "下载",
            "ja" to "ダウンロード",
            "ko" to "다운로드",
            "th" to "ดาวน์โหลด"
        ),
        "model_download_paused" to mapOf(
            "zh-Hant" to "下載已中斷，再按一次可續傳",
            "en" to "Download paused — tap again to resume",
            "zh-Hans" to "下载已中断，再按一次可续传",
            "ja" to "ダウンロードを中断しました。もう一度タップで再開",
            "ko" to "다운로드가 중단되었습니다. 다시 누르면 이어받습니다",
            "th" to "การดาวน์โหลดหยุดชั่วคราว แตะอีกครั้งเพื่อดำเนินต่อ"
        ),
        "model_downloading" to mapOf(
            "zh-Hant" to "下載中…",
            "en" to "Downloading…",
            "zh-Hans" to "下载中…",
            "ja" to "ダウンロード中…",
            "ko" to "다운로드 중…",
            "th" to "กำลังดาวน์โหลด…"
        ),
        "model_no_geometry" to mapOf(
            "zh-Hant" to "這個模型檔裡沒有任何形狀",
            "en" to "That model file has no shapes in it",
            "zh-Hans" to "这个模型文件里没有任何形状",
            "ja" to "このモデルファイルには形状が入っていません",
            "ko" to "이 모델 파일에는 도형이 없습니다",
            "th" to "ไฟล์โมเดลนี้ไม่มีรูปทรงอยู่เลย"
        ),
        "model_optional" to mapOf(
            "zh-Hant" to "可選",
            "en" to "Optional",
            "zh-Hans" to "可选",
            "ja" to "任意",
            "ko" to "선택",
            "th" to "ไม่บังคับ"
        ),
        "model_ready" to mapOf(
            "zh-Hant" to "已就緒",
            "en" to "Ready",
            "zh-Hans" to "已就绪",
            "ja" to "利用可能",
            "ko" to "사용 가능",
            "th" to "พร้อมใช้งาน"
        ),
        "model_remove" to mapOf(
            "zh-Hant" to "刪除",
            "en" to "Remove",
            "zh-Hans" to "删除",
            "ja" to "削除",
            "ko" to "삭제",
            "th" to "ลบ"
        ),
        "model_scale" to mapOf(
            "zh-Hant" to "縮放",
            "en" to "Scale",
            "zh-Hans" to "缩放",
            "ja" to "スケール",
            "ko" to "크기",
            "th" to "ขนาด"
        ),
        "model_title" to mapOf(
            "zh-Hant" to "物件名稱",
            "en" to "Object Title",
            "zh-Hans" to "物体名称",
            "ja" to "オブジェクト名",
            "ko" to "개체 이름",
            "th" to "ชื่อวัตถุ"
        ),
        "model_too_many_faces" to mapOf(
            "zh-Hant" to "這個模型太細緻，轉起來會卡",
            "en" to "That model is too detailed to rotate smoothly",
            "zh-Hans" to "这个模型太细致，转起来会卡",
            "ja" to "このモデルは精細すぎて滑らかに回転できません",
            "ko" to "이 모델은 너무 정밀해서 부드럽게 회전할 수 없습니다",
            "th" to "โมเดลนี้ละเอียดเกินไป หมุนแล้วจะไม่ลื่น"
        ),
        "model_unavailable" to mapOf(
            "zh-Hant" to "尚未提供下載來源",
            "en" to "No download source yet",
            "zh-Hans" to "尚未提供下载来源",
            "ja" to "入手先が未確定",
            "ko" to "다운로드 경로 미정",
            "th" to "ยังไม่มีแหล่งดาวน์โหลด"
        ),
        "model_unsupported_format" to mapOf(
            "zh-Hant" to "這裡只畫得出 OBJ 與 STL 模型",
            "en" to "Only OBJ and STL models can be drawn here",
            "zh-Hans" to "这里只画得出 OBJ 与 STL 模型",
            "ja" to "ここで描けるのは OBJ と STL のモデルだけです",
            "ko" to "여기서는 OBJ와 STL 모델만 그릴 수 있습니다",
            "th" to "ที่นี่วาดได้เฉพาะโมเดล OBJ และ STL"
        ),
        "models_desc" to mapOf(
            "zh-Hant" to "下載後即可在本機使用語音轉錄與 OCR，資料不離開這台裝置。",
            "en" to "Download models to enable on-device transcription and OCR. Everything stays on this device.",
            "zh-Hans" to "下载后即可在本机使用语音转录与 OCR，资料不离开这台设备。",
            "ja" to "モデルをダウンロードすると、端末内で文字起こしと OCR が使えます。データは端末から出ません。",
            "ko" to "다운로드하면 기기에서 음성 인식과 OCR을 사용할 수 있습니다. 데이터는 기기를 벗어나지 않습니다.",
            "th" to "ดาวน์โหลดโมเดลเพื่อใช้การถอดเสียงและ OCR บนอุปกรณ์ ข้อมูลไม่ออกจากเครื่อง"
        ),
        "models_title" to mapOf(
            "zh-Hant" to "端側模型",
            "en" to "On-Device Models",
            "zh-Hans" to "端侧模型",
            "ja" to "端末モデル",
            "ko" to "온디바이스 모델",
            "th" to "โมเดลบนอุปกรณ์"
        ),
        "more_tools" to mapOf(
            "zh-Hant" to "更多",
            "en" to "More",
            "zh-Hans" to "更多",
            "ja" to "その他",
            "ko" to "더 보기",
            "th" to "เพิ่มเติม"
        ),
        "move_cycle_refused" to mapOf(
            "zh-Hant" to "不能把資料夾搬進它自己裡面。",
            "en" to "Can't move a folder into itself.",
            "zh-Hans" to "不能把资料夹搬进它自己里面。",
            "ja" to "フォルダを自身の中へは移動できません。",
            "ko" to "폴더를 자기 자신 안으로 옮길 수 없습니다.",
            "th" to "ย้ายโฟลเดอร์เข้าไปในตัวเองไม่ได้"
        ),
        "move_done" to mapOf(
            "zh-Hant" to "已移動",
            "en" to "Moved",
            "zh-Hans" to "已移动",
            "ja" to "移動しました",
            "ko" to "이동했습니다",
            "th" to "ย้ายแล้ว"
        ),
        "move_out_of_folder" to mapOf(
            "zh-Hant" to "移出資料夾",
            "en" to "Move Out of Folder",
            "zh-Hans" to "移出文件夹",
            "ja" to "フォルダから出す",
            "ko" to "폴더에서 꺼내기",
            "th" to "นำออกจากโฟลเดอร์"
        ),
        "move_page_down" to mapOf(
            "zh-Hant" to "下移一頁",
            "en" to "Move Page Down",
            "zh-Hans" to "下移一页",
            "ja" to "ページを下へ",
            "ko" to "페이지 아래로",
            "th" to "เลื่อนหน้าลง"
        ),
        "move_page_to_bottom" to mapOf(
            "zh-Hant" to "移到最後",
            "en" to "Move to Last",
            "zh-Hans" to "移到最后",
            "ja" to "末尾へ移動",
            "ko" to "맨 뒤로 이동",
            "th" to "ย้ายไปหน้าสุดท้าย"
        ),
        "move_page_to_top" to mapOf(
            "zh-Hant" to "移到最前",
            "en" to "Move to First",
            "zh-Hans" to "移到最前",
            "ja" to "先頭へ移動",
            "ko" to "맨 앞으로 이동",
            "th" to "ย้ายไปหน้าแรก"
        ),
        "move_page_up" to mapOf(
            "zh-Hant" to "上移一頁",
            "en" to "Move Page Up",
            "zh-Hans" to "上移一页",
            "ja" to "ページを上へ",
            "ko" to "페이지 위로",
            "th" to "เลื่อนหน้าขึ้น"
        ),
        "move_pages_to_title" to mapOf(
            "zh-Hant" to "把選取的頁面移動到",
            "en" to "Move the selected pages into",
            "zh-Hans" to "把选取的页面移动到",
            "ja" to "選択したページの移動先",
            "ko" to "선택한 페이지를 이동할 곳",
            "th" to "ย้ายหน้าที่เลือกไปยัง"
        ),
        "move_to" to mapOf(
            "zh-Hant" to "移動到…",
            "en" to "Move to…",
            "zh-Hans" to "移动到…",
            "ja" to "移動先…",
            "ko" to "이동 위치…",
            "th" to "ย้ายไปยัง…"
        ),
        "move_to_folder" to mapOf(
            "zh-Hant" to "移動至資料夾",
            "en" to "Move to Folder",
            "zh-Hans" to "移动至文件夹",
            "ja" to "フォルダへ移動",
            "ko" to "폴더로 이동",
            "th" to "ย้ายไปยังโฟลเดอร์"
        ),
        "move_to_notebook" to mapOf(
            "zh-Hant" to "移動到其他筆記本…",
            "en" to "Move to Another Notebook…",
            "zh-Hans" to "移动到其他笔记本…",
            "ja" to "別のノートへ移動…",
            "ko" to "다른 노트로 이동…",
            "th" to "ย้ายไปยังสมุดอื่น…"
        ),
        "multi_window_drop_hint" to mapOf(
            "zh-Hant" to "拖曳至側邊以分頁或多視窗開啟",
            "en" to "Drag to side to open in split view",
            "zh-Hans" to "拖拽至侧边以分屏或多窗口打开",
            "ja" to "サイドにドラッグして分割表示で開く",
            "ko" to "측면으로 드래그하여 분할 화면으로 열기",
            "th" to "ลากไปด้านข้างเพื่อเปิดแบบแบ่งหน้าจอ"
        ),
        "new_note" to mapOf(
            "zh-Hant" to "新增筆記",
            "en" to "New Note",
            "zh-Hans" to "新建笔记",
            "ja" to "新規ノート",
            "ko" to "새 노트",
            "th" to "สร้างบันทึกใหม่"
        ),
        "new_note_desc" to mapOf(
            "zh-Hant" to "空白紙張、網格、康乃爾",
            "en" to "Blank, Grid, Cornell",
            "zh-Hans" to "空白纸张、网格、康奈尔",
            "ja" to "白紙、グリッド、コーネル式",
            "ko" to "빈 용지, 모눈, 코넬",
            "th" to "กระดาษเปล่า, ตาราง, คอร์เนลล์"
        ),
        "new_notebook" to mapOf(
            "zh-Hant" to "新增筆記本",
            "en" to "New Notebook",
            "zh-Hans" to "新建笔记本",
            "ja" to "新規ノートブック",
            "ko" to "새 노트북",
            "th" to "สมุดบันทึกใหม่"
        ),
        "new_subfolder" to mapOf(
            "zh-Hant" to "新增子資料夾",
            "en" to "New Subfolder",
            "zh-Hans" to "新建子文件夹",
            "ja" to "サブフォルダを追加",
            "ko" to "하위 폴더 추가",
            "th" to "สร้างโฟลเดอร์ย่อยใหม่"
        ),
        "next_page" to mapOf(
            "zh-Hant" to "下一頁",
            "en" to "Next page",
            "zh-Hans" to "下一页",
            "ja" to "次のページ",
            "ko" to "다음 페이지",
            "th" to "หน้าถัดไป"
        ),
        "next_step" to mapOf(
            "zh-Hant" to "下一步",
            "en" to "Next",
            "zh-Hans" to "下一步",
            "ja" to "次へ",
            "ko" to "다음",
            "th" to "ถัดไป"
        ),
        "no_account_needed" to mapOf(
            "zh-Hant" to "不需要帳號，也沒有我們的伺服器",
            "en" to "No account, and no server of ours",
            "zh-Hans" to "不需要账号，也没有我们的服务器",
            "ja" to "アカウント不要、当方のサーバーもありません",
            "ko" to "계정이 필요 없고, 저희 서버도 없습니다",
            "th" to "ไม่ต้องมีบัญชี และไม่มีเซิร์ฟเวอร์ของเรา"
        ),
        "no_account_no_server" to mapOf(
            "zh-Hant" to "沒有帳號，也沒有我們的伺服器",
            "en" to "No account, and no server of ours",
            "zh-Hans" to "没有账号，也没有我们的服务器",
            "ja" to "アカウントも、当方のサーバーもありません",
            "ko" to "계정도 없고 저희 서버도 없습니다",
            "th" to "ไม่มีบัญชี และไม่มีเซิร์ฟเวอร์ของเรา"
        ),
        "no_assets_found" to mapOf(
            "zh-Hant" to "未找到符合條件的素材",
            "en" to "No matching assets found",
            "zh-Hans" to "未找到符合条件的素材",
            "ja" to "一致するアセットが見つかりません",
            "ko" to "일치하는 에셋을 찾을 수 없습니다",
            "th" to "ไม่พบเนื้อหาที่ตรงกัน"
        ),
        "no_assets_hint" to mapOf(
            "zh-Hant" to "嘗試更換搜尋關鍵字或切換主題分類標籤",
            "en" to "Try different keywords or switch theme tabs",
            "zh-Hans" to "尝试更换搜索关键字或切换主题分类标签",
            "ja" to "検索キーワードを変更するか、テーマタブを切り替えてください",
            "ko" to "다른 검색어를 입력하거나 테마 탭을 전환해 보세요",
            "th" to "ลองเปลี่ยนคำค้นหาหรือสลับแท็บธีม"
        ),
        "no_highlight" to mapOf(
            "zh-Hant" to "不加醒目提示",
            "en" to "No highlight",
            "zh-Hans" to "不加醒目提示",
            "ja" to "ハイライトなし",
            "ko" to "강조 없음",
            "th" to "ไม่ไฮไลต์"
        ),
        "no_notes_empty" to mapOf(
            "zh-Hant" to "尚無筆記，點選「新增筆記」開始繪製",
            "en" to "No notes yet. Tap 'New Note' to start.",
            "zh-Hans" to "尚无笔记，点击“新建笔记”开始绘制",
            "ja" to "ノートがありません。「新規ノート」をタップして開始。",
            "ko" to "노트가 없습니다. '새 노트'를 눌러 시작하세요.",
            "th" to "ยังไม่มีบันทึก แตะ 'สร้างบันทึกใหม่' เพื่อเริ่ม"
        ),
        "no_notes_hint" to mapOf(
            "zh-Hant" to "尚無筆記或皆已隱藏，點選「新增筆記」開始繪製",
            "en" to "No notes found. Tap \"New Note\" to get started.",
            "zh-Hans" to "暂无笔记，点击“新建笔记”开始绘制",
            "ja" to "ノートがありません。「新規ノート」をクリックして作成",
            "ko" to "노트가 없습니다. \"새 노트\"를 클릭하여 시작하세요.",
            "th" to "ยังไม่มีบันทึก แตะ \"บันทึกใหม่\" เพื่อเริ่มต้น"
        ),
        "no_notes_match" to mapOf(
            "zh-Hant" to "找不到符合的筆記",
            "en" to "No matching notes found",
            "zh-Hans" to "未找到符合的笔记",
            "ja" to "一致するノートが見つかりません",
            "ko" to "일치하는 노트를 찾을 수 없습니다",
            "th" to "ไม่พบบันทึกที่ตรงกัน"
        ),
        "no_recognition_result" to mapOf(
            "zh-Hant" to "這一頁沒有辨識出文字",
            "en" to "No text recognised on this page",
            "zh-Hans" to "这一页没有辨识出文字",
            "ja" to "このページから文字を認識できませんでした",
            "ko" to "이 페이지에서 글자를 인식하지 못했습니다",
            "th" to "ไม่พบข้อความที่อ่านได้ในหน้านี้"
        ),
        "no_recordings_hint" to mapOf(
            "zh-Hant" to "目前尚無錄音檔或皆已隱藏，點擊「開始錄音」即可即時收音",
            "en" to "No audio recordings yet. Tap \"Start Recording\" to record audio.",
            "zh-Hans" to "暂无录音文件，点击“开始录音”即可录音",
            "ja" to "録音がありません。「録音開始」で音声を録音します",
            "ko" to "녹음 파일이 없습니다. \"녹음 시작\"을 탭하여 녹음하세요.",
            "th" to "ยังไม่มีเสียงบันทึก แตะ \"เริ่มบันทึก\" เพื่อบันทึกเสียง"
        ),
        "no_search_results" to mapOf(
            "zh-Hant" to "找不到符合「%@」的筆記",
            "en" to "No notes matching \"%@\"",
            "zh-Hans" to "未找到匹配“%@”的笔记",
            "ja" to "「%@」に一致するノートは見つかりません",
            "ko" to "\"%@\"에 일치하는 노트가 없습니다",
            "th" to "ไม่พบบันทึกที่ตรงกับ \"%@\""
        ),
        "no_stickers" to mapOf(
            "zh-Hant" to "還沒有貼紙",
            "en" to "No Stickers Yet",
            "zh-Hans" to "还没有贴纸",
            "ja" to "ステッカーがありません",
            "ko" to "아직 스티커가 없습니다",
            "th" to "ยังไม่มีสติกเกอร์"
        ),
        "no_stickers_hint" to mapOf(
            "zh-Hant" to "用套索圈選筆劃，即可儲存為自訂貼紙。",
            "en" to "Select strokes with lasso tool to save custom stickers.",
            "zh-Hans" to "用套索圈选笔画，即可保存为自定义贴纸。",
            "ja" to "なげなわツールでストロークを選択し、カスタムステッカーを保存します。",
            "ko" to "올가미 도구로 스트로크를 선택하여 사용자 정의 스티커를 저장합니다.",
            "th" to "เลือกจังหวะด้วยเครื่องมือบ่วงบาศเพื่อบันทึกสติกเกอร์แบบกำหนดเอง"
        ),
        "no_strokes" to mapOf(
            "zh-Hant" to "這一頁還沒有手寫內容",
            "en" to "Nothing handwritten on this page yet",
            "zh-Hans" to "这一页还没有手写内容",
            "ja" to "このページにはまだ手書きがありません",
            "ko" to "이 페이지에는 아직 손글씨가 없습니다",
            "th" to "หน้านี้ยังไม่มีลายมือ"
        ),
        "normal_text" to mapOf(
            "zh-Hant" to "內文",
            "en" to "Normal text",
            "zh-Hans" to "正文",
            "ja" to "標準テキスト",
            "ko" to "일반 텍스트",
            "th" to "ข้อความปกติ"
        ),
        "not_downloaded" to mapOf(
            "zh-Hant" to "隨需下載",
            "en" to "On Demand",
            "zh-Hans" to "随需下载",
            "ja" to "未DL",
            "ko" to "필요 시 다운",
            "th" to "ตามต้องการ"
        ),
        "not_signed_in" to mapOf(
            "zh-Hant" to "未登入",
            "en" to "Not signed in",
            "zh-Hans" to "未登录",
            "ja" to "未ログイン",
            "ko" to "로그인되지 않음",
            "th" to "ยังไม่ได้ลงชื่อเข้าใช้"
        ),
        "note_title" to mapOf(
            "zh-Hant" to "筆記標題",
            "en" to "Notebook Title",
            "zh-Hans" to "笔记标题",
            "ja" to "ノートのタイトル",
            "ko" to "노트 제목",
            "th" to "ชื่อบันทึก"
        ),
        "notebook_empty" to mapOf(
            "zh-Hant" to "還沒有任何筆記。點「新增筆記」開始。",
            "en" to "No notes yet. Tap “New note” to start.",
            "zh-Hans" to "还没有任何笔记。点「新增笔记」开始。",
            "ja" to "まだノートがありません。「新規ノート」から始めましょう。",
            "ko" to "아직 노트가 없습니다. ‘새 노트’로 시작하세요.",
            "th" to "ยังไม่มีโน้ต แตะ “โน้ตใหม่” เพื่อเริ่ม"
        ),
        "notebook_title_label" to mapOf(
            "zh-Hant" to "筆記本名稱",
            "en" to "Notebook name",
            "zh-Hans" to "笔记本名称",
            "ja" to "ノート名",
            "ko" to "노트 이름",
            "th" to "ชื่อสมุดบันทึก"
        ),
        "nothing_to_refine" to mapOf(
            "zh-Hant" to "沒有可修飾的筆跡 —— 請先寫點東西",
            "en" to "Nothing to refine — draw something first",
            "zh-Hans" to "没有可修饰的笔迹 —— 请先写点东西",
            "ja" to "補正できる筆跡がありません。先に何か書いてください",
            "ko" to "보정할 필기가 없습니다. 먼저 무언가를 써 보세요",
            "th" to "ยังไม่มีลายเส้นให้ปรับแต่ง — ลองเขียนอะไรสักอย่างก่อน"
        ),
        "numbered_list" to mapOf(
            "zh-Hant" to "編號清單",
            "en" to "Numbered List",
            "zh-Hans" to "编号列表",
            "ja" to "番号付きリスト",
            "ko" to "번호 매기기 목록",
            "th" to "รายการลำดับเลข"
        ),
        "object_background_color" to mapOf(
            "zh-Hant" to "底色",
            "en" to "Background",
            "zh-Hans" to "底色",
            "ja" to "背景色",
            "ko" to "배경색",
            "th" to "สีพื้นหลัง"
        ),
        "object_border_color" to mapOf(
            "zh-Hant" to "邊框顏色",
            "en" to "Border Color",
            "zh-Hans" to "边框颜色",
            "ja" to "枠線の色",
            "ko" to "테두리 색상",
            "th" to "สีเส้นขอบ"
        ),
        "object_border_width" to mapOf(
            "zh-Hant" to "邊框粗細",
            "en" to "Border Width",
            "zh-Hans" to "边框粗细",
            "ja" to "枠線の太さ",
            "ko" to "테두리 두께",
            "th" to "ความหนาเส้นขอบ"
        ),
        "object_corner_radius" to mapOf(
            "zh-Hant" to "圓角",
            "en" to "Corner Radius",
            "zh-Hans" to "圆角",
            "ja" to "角の丸み",
            "ko" to "모서리 둥글기",
            "th" to "ความมนของมุม"
        ),
        "object_corner_square" to mapOf(
            "zh-Hant" to "直角",
            "en" to "Square",
            "zh-Hans" to "直角",
            "ja" to "直角",
            "ko" to "직각",
            "th" to "มุมฉาก"
        ),
        "object_frame_style" to mapOf(
            "zh-Hant" to "外框與底色",
            "en" to "Frame & Background",
            "zh-Hans" to "外框与底色",
            "ja" to "枠と背景",
            "ko" to "테두리 및 배경",
            "th" to "กรอบและพื้นหลัง"
        ),
        "object_locked_by" to mapOf(
            "zh-Hant" to "正在編輯中",
            "en" to "is editing",
            "zh-Hans" to "正在编辑中",
            "ja" to "が編集中",
            "ko" to "편집 중",
            "th" to "กำลังแก้ไข"
        ),
        "object_show_border" to mapOf(
            "zh-Hant" to "顯示邊框",
            "en" to "Show Border",
            "zh-Hans" to "显示边框",
            "ja" to "枠線を表示",
            "ko" to "테두리 표시",
            "th" to "แสดงเส้นขอบ"
        ),
        "object_use_default" to mapOf(
            "zh-Hant" to "回復預設",
            "en" to "Use Default",
            "zh-Hans" to "恢复默认",
            "ja" to "既定に戻す",
            "ko" to "기본값으로",
            "th" to "ใช้ค่าเริ่มต้น"
        ),
        "offline_queue_hint" to mapOf(
            "zh-Hant" to "目前離線，已暫存 %d 筆操作，連線恢復時將自動同步。",
            "en" to "Offline mode: %d operations queued. Will auto-sync once reconnected.",
            "zh-Hans" to "目前离线，已暂存 %d 笔操作，连接恢复时将自动同步。",
            "ja" to "オフラインです：%d 件の操作が保留中です。再接続時に自動同期されます。",
            "ko" to "오프라인 상태입니다: %d개 작업 대기 중. 다시 연결되면 자동 동기화됩니다.",
            "th" to "ออฟไลน์อยู่: รอคิว %d รายการ จะซิงค์อัตโนมัติเมื่อเชื่อมต่อใหม่"
        ),
        "onboarding_continue" to mapOf(
            "zh-Hant" to "繼續",
            "en" to "Continue",
            "zh-Hans" to "继续",
            "ja" to "続ける",
            "ko" to "계속",
            "th" to "ดำเนินการต่อ"
        ),
        "onboarding_microphone_granted" to mapOf(
            "zh-Hant" to "麥克風已允許",
            "en" to "Microphone allowed",
            "zh-Hans" to "麦克风已允许",
            "ja" to "マイクを許可しました",
            "ko" to "마이크가 허용되었습니다",
            "th" to "อนุญาตไมโครโฟนแล้ว"
        )
    )

    private fun part18(): Map<String, Map<String, String>> = mapOf(
        "onboarding_next" to mapOf(
            "zh-Hant" to "下一步",
            "en" to "Next",
            "zh-Hans" to "下一步",
            "ja" to "次へ",
            "ko" to "다음",
            "th" to "ถัดไป"
        ),
        "onboarding_permission_body" to mapOf(
            "zh-Hant" to "錄音需要麥克風。不錄音就用不到 —— 現在允許或之後再說都可以，其餘功能不受影響。",
            "en" to "Recording needs the microphone. Nothing else does — allow it now or later; everything else works either way.",
            "zh-Hans" to "录音需要麦克风。不录音就用不到 —— 现在允许或之后再说都可以，其余功能不受影响。",
            "ja" to "録音にはマイクが必要です。それ以外では使いません。今許可しても後でもかまいません。他の機能には影響しません。",
            "ko" to "녹음에는 마이크가 필요합니다. 그 외에는 쓰지 않습니다. 지금 허용하든 나중에 하든 다른 기능은 그대로 작동합니다.",
            "th" to "การบันทึกเสียงต้องใช้ไมโครโฟน นอกจากนี้ไม่ใช้เลย จะอนุญาตตอนนี้หรือภายหลังก็ได้ ฟังก์ชันอื่นไม่ได้รับผลกระทบ"
        ),
        "onboarding_permission_title" to mapOf(
            "zh-Hant" to "只有一項權限",
            "en" to "Just one permission",
            "zh-Hans" to "只有一项权限",
            "ja" to "必要な権限はひとつだけ",
            "ko" to "필요한 권한은 하나뿐",
            "th" to "มีสิทธิ์เพียงอย่างเดียว"
        ),
        "onboarding_privacy_body" to mapOf(
            "zh-Hant" to "不必註冊就能開始用。要跨裝置同步時，你指定自己的雲端資料夾，檔案不會經過我們。",
            "en" to "Start without signing up. To sync across devices you pick your own cloud folder — files never pass through us.",
            "zh-Hans" to "不必注册就能开始用。要跨设备同步时，你指定自己的云端文件夹，文件不会经过我们。",
            "ja" to "登録なしで始められます。端末間で同期するときは、ご自分のクラウドフォルダを指定します。ファイルが当方を経由することはありません。",
            "ko" to "가입 없이 바로 시작할 수 있습니다. 기기 간 동기화는 본인의 클라우드 폴더를 지정하며, 파일이 저희를 거치지 않습니다.",
            "th" to "เริ่มใช้ได้โดยไม่ต้องสมัคร หากต้องการซิงก์ข้ามอุปกรณ์ คุณเลือกโฟลเดอร์คลาวด์ของคุณเอง ไฟล์ไม่ผ่านเรา"
        ),
        "onboarding_privacy_title" to mapOf(
            "zh-Hant" to "沒有帳號，也沒有我們的伺服器",
            "en" to "No account, and no server of ours",
            "zh-Hans" to "没有账号，也没有我们的服务器",
            "ja" to "アカウントも、当方のサーバーもありません",
            "ko" to "계정도, 저희 서버도 없습니다",
            "th" to "ไม่มีบัญชี และไม่มีเซิร์ฟเวอร์ของเรา"
        ),
        "onboarding_start" to mapOf(
            "zh-Hant" to "開始使用",
            "en" to "Get Started",
            "zh-Hans" to "开始使用",
            "ja" to "はじめる",
            "ko" to "시작하기",
            "th" to "เริ่มใช้งาน"
        ),
        "onboarding_welcome_body" to mapOf(
            "zh-Hant" to "手寫、打字與錄音在同一頁。離線可用，資料留在這台裝置上。",
            "en" to "Handwriting, typing and audio on one page. Works offline; your notes stay on this device.",
            "zh-Hans" to "手写、打字与录音在同一页。离线可用，数据留在这台设备上。",
            "ja" to "手書き・入力・録音を同じページに。オフラインで使え、データはこの端末に残ります。",
            "ko" to "손글씨, 입력, 녹음을 한 페이지에. 오프라인으로 작동하며 데이터는 이 기기에 남습니다.",
            "th" to "เขียนด้วยลายมือ พิมพ์ และบันทึกเสียงในหน้าเดียว ใช้ได้แบบออฟไลน์ และข้อมูลอยู่ในเครื่องนี้"
        ),
        "onboarding_welcome_title" to mapOf(
            "zh-Hant" to "歡迎使用 Kairumo",
            "en" to "Welcome to Kairumo",
            "zh-Hans" to "欢迎使用 Kairumo",
            "ja" to "Kairumo へようこそ",
            "ko" to "Kairumo에 오신 것을 환영합니다",
            "th" to "ยินดีต้อนรับสู่ Kairumo"
        ),
        "online" to mapOf(
            "zh-Hant" to "線上",
            "en" to "Online",
            "zh-Hans" to "在线",
            "ja" to "オンライン",
            "ko" to "온라인",
            "th" to "ออนไลน์"
        ),
        "online_participants" to mapOf(
            "zh-Hant" to "在線成員",
            "en" to "Online Participants",
            "zh-Hans" to "在线成员",
            "ja" to "オンラインメンバー",
            "ko" to "온라인 참여자",
            "th" to "ผู้เข้าร่วมออนไลน์"
        ),
        "opacity" to mapOf(
            "zh-Hant" to "不透明度",
            "en" to "Opacity",
            "zh-Hans" to "不透明度",
            "ja" to "不透明度",
            "ko" to "불투명도",
            "th" to "ความทึบแสง"
        ),
        "open" to mapOf(
            "zh-Hant" to "開啟",
            "en" to "Open",
            "zh-Hans" to "打开",
            "ja" to "開く",
            "ko" to "열기",
            "th" to "เปิด"
        ),
        "open_comments" to mapOf(
            "zh-Hant" to "討論圖釘列表",
            "en" to "Comments",
            "zh-Hans" to "讨论图钉列表",
            "ja" to "コメント一覧",
            "ko" to "댓글 목록",
            "th" to "รายการความคิดเห็น"
        ),
        "open_editor" to mapOf(
            "zh-Hant" to "開啟編輯",
            "en" to "Open Editor",
            "zh-Hans" to "打开编辑",
            "ja" to "編集を開く",
            "ko" to "편집 열기",
            "th" to "เปิดแก้ไข"
        ),
        "open_folder" to mapOf(
            "zh-Hant" to "開啟 Kairumo Record 資料夾",
            "en" to "Open Kairumo Record Folder",
            "zh-Hans" to "打开 Kairumo Record 文件夹",
            "ja" to "Kairumo Record フォルダを開く",
            "ko" to "Kairumo Record 폴더 열기",
            "th" to "เปิดโฟลเดอร์ Kairumo Record"
        ),
        "open_in_browser" to mapOf(
            "zh-Hant" to "在瀏覽器中開啟",
            "en" to "Open in Browser",
            "zh-Hans" to "在浏览器中打开",
            "ja" to "ブラウザで開く",
            "ko" to "브라우저에서 열기",
            "th" to "เปิดในเบราว์เซอร์"
        ),
        "open_link" to mapOf(
            "zh-Hant" to "開啟連結",
            "en" to "Open Link",
            "zh-Hans" to "打开链接",
            "ja" to "リンクを開く",
            "ko" to "링크 열기",
            "th" to "เปิดลิงก์"
        ),
        "open_note" to mapOf(
            "zh-Hant" to "開啟",
            "en" to "Open",
            "zh-Hans" to "开启",
            "ja" to "開く",
            "ko" to "열기",
            "th" to "เปิด"
        ),
        "open_record_folder" to mapOf(
            "zh-Hant" to "開啟 Kairumo Record 資料夾",
            "en" to "Open Kairumo Record Folder",
            "zh-Hans" to "打开 Kairumo Record 文件夹",
            "ja" to "Kairumo Record フォルダを開く",
            "ko" to "Kairumo Record 폴더 열기",
            "th" to "เปิดโฟลเดอร์ Kairumo Record"
        ),
        "open_settings" to mapOf(
            "zh-Hant" to "前往系統設定開啟",
            "en" to "Open Settings",
            "zh-Hans" to "前往系统设置开启",
            "ja" to "設定を開く",
            "ko" to "설정 열기",
            "th" to "เปิดการตั้งค่า"
        ),
        "outside_printable_clamped" to mapOf(
            "zh-Hant" to "已移回可列印範圍內。虛線框以外的內容不會被列印，也不會進入匯出檔。",
            "en" to "Moved back inside the printable area. Anything beyond the dashed frame is not printed or exported.",
            "zh-Hans" to "已移回可打印范围内。虚线框以外的内容不会被打印，也不会进入导出档。",
            "ja" to "印刷範囲の内側に戻しました。破線の枠の外は印刷にも書き出しにも含まれません。",
            "ko" to "인쇄 영역 안으로 되돌렸습니다. 점선 테두리 바깥은 인쇄와 내보내기에 포함되지 않습니다.",
            "th" to "ย้ายกลับเข้ามาในพื้นที่พิมพ์แล้ว สิ่งที่อยู่นอกกรอบเส้นประจะไม่ถูกพิมพ์หรือส่งออก"
        ),
        "outside_printable_rejected" to mapOf(
            "zh-Hant" to "這一筆畫在可列印範圍之外，已經撤銷。虛線框以外的內容不會被列印，也不會進入匯出檔。",
            "en" to "That stroke landed outside the printable area, so it was removed. Anything beyond the dashed frame is not printed or exported.",
            "zh-Hans" to "这一笔画在可打印范围之外，已经撤销。虚线框以外的内容不会被打印，也不会进入导出档。",
            "ja" to "印刷範囲の外に書かれたため取り消しました。破線の枠の外は印刷にも書き出しにも含まれません。",
            "ko" to "인쇄 영역 밖에 그려져 취소했습니다. 점선 테두리 바깥은 인쇄와 내보내기에 포함되지 않습니다.",
            "th" to "เส้นนี้อยู่นอกพื้นที่พิมพ์จึงถูกลบออก สิ่งที่อยู่นอกกรอบเส้นประจะไม่ถูกพิมพ์หรือส่งออก"
        ),
        "p2p_sync_tailscale_explainer" to mapOf(
            "zh-Hant" to "跨裝置直連同步：Kairumo 使用 WebRTC 進行跨網際網路的點對點極速同步。為達到最穩定的無伺服器穿透效果，強烈建議在您的裝置上安裝 Tailscale。",
            "en" to "Cross-device Direct Sync: Kairumo uses WebRTC for peer-to-peer fast syncing across the internet. For the most stable connection without public relays, we highly recommend installing Tailscale on your devices.",
            "zh-Hans" to "跨设备直连同步：Kairumo 使用 WebRTC 进行跨互联网的点对点极速同步。为达到最稳定的无服务器穿透效果，强烈建议在您的设备上安装 Tailscale。",
            "ja" to "端末間直接同期：Kairumo は WebRTC を利用してインターネット経由で高速 P2P 同期を行います。最も安定した接続のために、お使いの端末に Tailscale をインストールすることを強く推奨します。",
            "ko" to "기기간 직접 동기화: Kairumo는 WebRTC를 사용하여 인터넷을 통한 빠른 P2P 동기화를 제공합니다. 가장 안정적인 연결을 위해 기기에 Tailscale을 설치하는 것을 권장합니다.",
            "th" to "การซิงก์โดยตรงระหว่างอุปกรณ์: Kairumo ใช้ WebRTC สำหรับการซิงก์ P2P ความเร็วสูง เพื่อการเชื่อมต่อที่เสถียรที่สุด ขอแนะนำให้ติดตั้ง Tailscale บนอุปกรณ์ของคุณ"
        ),
        "p2p_sync_tailscale_title" to mapOf(
            "zh-Hant" to "Tailscale 點對點直連同步",
            "en" to "Tailscale Direct P2P Sync",
            "zh-Hans" to "Tailscale 点对点直连同步",
            "ja" to "Tailscale P2P 直接同期",
            "ko" to "Tailscale P2P 직접 동기화",
            "th" to "การซิงก์แบบ P2P โดยตรงด้วย Tailscale"
        ),
        "page_extended_hint" to mapOf(
            "zh-Hant" to "已向下延長畫布長度 (+800pt)",
            "en" to "Page length extended (+800pt)",
            "zh-Hans" to "已向下延长画布长度 (+800pt)",
            "ja" to "キャンバス長を延長しました (+800pt)",
            "ko" to "캔버스 길이가 연장되었습니다 (+800pt)",
            "th" to "ขยายความยาวของผืนผ้าใบแล้ว (+800pt)"
        ),
        "page_format" to mapOf(
            "zh-Hant" to "頁面規格",
            "en" to "Page format",
            "zh-Hans" to "页面规格",
            "ja" to "用紙サイズ",
            "ko" to "용지 크기",
            "th" to "ขนาดหน้ากระดาษ"
        ),
        "page_format_a2" to mapOf(
            "zh-Hant" to "A2（直式）",
            "en" to "A2 (portrait)",
            "zh-Hans" to "A2（竖式）",
            "ja" to "A2（縦）",
            "ko" to "A2 (세로)",
            "th" to "A2 (แนวตั้ง)"
        ),
        "page_format_a2_landscape" to mapOf(
            "zh-Hant" to "A2（橫式）",
            "en" to "A2 (landscape)",
            "zh-Hans" to "A2（横式）",
            "ja" to "A2（横）",
            "ko" to "A2 (가로)",
            "th" to "A2 (แนวนอน)"
        ),
        "page_format_a3" to mapOf(
            "zh-Hant" to "A3（直式）",
            "en" to "A3 (portrait)",
            "zh-Hans" to "A3（竖式）",
            "ja" to "A3（縦）",
            "ko" to "A3 (세로)",
            "th" to "A3 (แนวตั้ง)"
        ),
        "page_format_a3_landscape" to mapOf(
            "zh-Hant" to "A3（橫式）",
            "en" to "A3 (landscape)",
            "zh-Hans" to "A3（横式）",
            "ja" to "A3（横）",
            "ko" to "A3 (가로)",
            "th" to "A3 (แนวนอน)"
        ),
        "page_format_a4" to mapOf(
            "zh-Hant" to "A4 直式",
            "en" to "A4",
            "zh-Hans" to "A4 直式",
            "ja" to "A4",
            "ko" to "A4",
            "th" to "A4"
        ),
        "page_format_a4_landscape" to mapOf(
            "zh-Hant" to "A4 橫式",
            "en" to "A4 landscape",
            "zh-Hans" to "A4 横式",
            "ja" to "A4 横",
            "ko" to "A4 가로",
            "th" to "A4 แนวนอน"
        ),
        "page_format_a5" to mapOf(
            "zh-Hant" to "A5 直式",
            "en" to "A5",
            "zh-Hans" to "A5 直式",
            "ja" to "A5",
            "ko" to "A5",
            "th" to "A5"
        ),
        "page_format_change_warning" to mapOf(
            "zh-Hant" to "更改規格會同時改變畫布與匯出檔。超出新頁面的內容會被移回頁內。",
            "en" to "Changing the format resizes the canvas and the export. Content already outside the new page is moved back inside.",
            "zh-Hans" to "更改规格会同时改变画布与导出档。超出新页面的内容会被移回页内。",
            "ja" to "用紙サイズを変えるとキャンバスと書き出しの両方が変わります。新しい紙からはみ出した内容は内側に戻します。",
            "ko" to "용지 크기를 바꾸면 캔버스와 내보내기가 함께 바뀝니다. 새 페이지를 벗어난 내용은 안쪽으로 되돌립니다.",
            "th" to "การเปลี่ยนขนาดจะเปลี่ยนทั้งผืนผ้าใบและไฟล์ที่ส่งออก เนื้อหาที่เลยขอบหน้าใหม่จะถูกย้ายกลับเข้ามา"
        ),
        "page_format_custom" to mapOf(
            "zh-Hant" to "自訂尺寸",
            "en" to "Custom size",
            "zh-Hans" to "自定义尺寸",
            "ja" to "カスタムサイズ",
            "ko" to "사용자 지정 크기",
            "th" to "ขนาดกำหนดเอง"
        ),
        "page_format_custom_apply" to mapOf(
            "zh-Hant" to "套用",
            "en" to "Apply",
            "zh-Hans" to "应用",
            "ja" to "適用",
            "ko" to "적용",
            "th" to "ใช้"
        ),
        "page_format_custom_height" to mapOf(
            "zh-Hant" to "高",
            "en" to "Height",
            "zh-Hans" to "高",
            "ja" to "高さ",
            "ko" to "높이",
            "th" to "สูง"
        ),
        "page_format_custom_hint" to mapOf(
            "zh-Hant" to "寬與高，300–6000",
            "en" to "Width and height, 300–6000",
            "zh-Hans" to "宽与高，300–6000",
            "ja" to "幅と高さ（300〜6000）",
            "ko" to "너비와 높이, 300–6000",
            "th" to "กว้างและสูง 300–6000"
        ),
        "page_format_custom_title" to mapOf(
            "zh-Hant" to "自訂頁面尺寸",
            "en" to "Custom page size",
            "zh-Hans" to "自定义页面尺寸",
            "ja" to "カスタムページサイズ",
            "ko" to "사용자 지정 페이지 크기",
            "th" to "ขนาดหน้ากำหนดเอง"
        ),
        "page_format_custom_width" to mapOf(
            "zh-Hant" to "寬",
            "en" to "Width",
            "zh-Hans" to "宽",
            "ja" to "幅",
            "ko" to "너비",
            "th" to "กว้าง"
        ),
        "page_format_desc" to mapOf(
            "zh-Hant" to "變更頁面紙張規格與長寬比例（A4、信紙、16:9 等）",
            "en" to "Change canvas page format and aspect ratio (A4, Letter, 16:9)",
            "zh-Hans" to "更改页面纸张规格与长宽比例（A4、信纸、16:9 等）",
            "ja" to "ページ用紙サイズと縦横比を変更 (A4, Letter, 16:9)",
            "ko" to "페이지 용지 규격 및 비율 변경 (A4, Letter, 16:9)",
            "th" to "เปลี่ยนรูปแบบขนาดหน้าและอัตราส่วน (A4, Letter, 16:9)"
        ),
        "page_format_legal" to mapOf(
            "zh-Hant" to "Legal 直式",
            "en" to "Legal",
            "zh-Hans" to "Legal 直式",
            "ja" to "リーガル",
            "ko" to "리걸",
            "th" to "Legal"
        ),
        "page_format_letter" to mapOf(
            "zh-Hant" to "Letter 直式",
            "en" to "Letter",
            "zh-Hans" to "Letter 直式",
            "ja" to "レター",
            "ko" to "레터",
            "th" to "Letter"
        ),
        "page_format_letter_landscape" to mapOf(
            "zh-Hant" to "Letter 橫式",
            "en" to "Letter landscape",
            "zh-Hans" to "Letter 横式",
            "ja" to "レター 横",
            "ko" to "레터 가로",
            "th" to "Letter แนวนอน"
        ),
        "page_format_slide" to mapOf(
            "zh-Hant" to "簡報 16:9",
            "en" to "Slide 16:9",
            "zh-Hans" to "简报 16:9",
            "ja" to "スライド 16:9",
            "ko" to "슬라이드 16:9",
            "th" to "สไลด์ 16:9"
        ),
        "page_format_square" to mapOf(
            "zh-Hant" to "正方形",
            "en" to "Square",
            "zh-Hans" to "正方形",
            "ja" to "正方形",
            "ko" to "정사각형",
            "th" to "สี่เหลี่ยมจัตุรัส"
        ),
        "page_label" to mapOf(
            "zh-Hant" to "頁次",
            "en" to "Page",
            "zh-Hans" to "页次",
            "ja" to "ページ",
            "ko" to "페이지",
            "th" to "หน้า"
        ),
        "page_mode" to mapOf(
            "zh-Hant" to "頁面模式",
            "en" to "Page mode",
            "zh-Hans" to "页面模式",
            "ja" to "ページ表示",
            "ko" to "페이지 모드",
            "th" to "โหมดหน้า"
        ),
        "page_mode_continuous" to mapOf(
            "zh-Hant" to "連續頁面",
            "en" to "Continuous",
            "zh-Hans" to "连续页面",
            "ja" to "連続ページ",
            "ko" to "연속 페이지",
            "th" to "เลื่อนต่อเนื่อง"
        ),
        "page_mode_single" to mapOf(
            "zh-Hant" to "整頁",
            "en" to "Single page",
            "zh-Hans" to "整页",
            "ja" to "単一ページ",
            "ko" to "한 페이지",
            "th" to "หน้าเดียว"
        ),
        "page_model_done" to mapOf(
            "zh-Hant" to "已重新分頁 %@ 本",
            "en" to "%@ notebooks repaginated",
            "zh-Hans" to "已重新分页 %@ 本",
            "ja" to "%@ 冊を再分割しました",
            "ko" to "%@권을 다시 나눴습니다",
            "th" to "แบ่งหน้าใหม่แล้ว %@ เล่ม"
        ),
        "page_model_explainer" to mapOf(
            "zh-Hant" to "每一頁改成固定高度，畫布上會畫出頁面與可列印區界線。內容寫到頁尾會自動準備下一頁。原始資料已備份。",
            "en" to "Every page becomes a fixed height, and the canvas shows the page and printable-area boundaries. Writing to the bottom prepares the next page. Your original data is backed up.",
            "zh-Hans" to "每一页改成固定高度，画布上会画出页面与可打印区界线。内容写到页尾会自动准备下一页。原始数据已备份。",
            "ja" to "各ページが固定の高さになり、キャンバスにページと印刷可能領域の境界が表示されます。ページ末尾まで書くと次のページが用意されます。元のデータはバックアップ済みです。",
            "ko" to "모든 페이지가 고정 높이가 되고, 캔버스에 페이지와 인쇄 가능 영역 경계가 표시됩니다. 페이지 끝까지 쓰면 다음 페이지가 준비됩니다. 원본 데이터는 백업되었습니다.",
            "th" to "ทุกหน้าจะมีความสูงคงที่ และผืนผ้าใบจะแสดงขอบเขตหน้าและพื้นที่พิมพ์ได้ เมื่อเขียนถึงท้ายหน้าจะเตรียมหน้าถัดไปให้ ข้อมูลเดิมได้รับการสำรองไว้แล้ว"
        ),
        "page_model_failed" to mapOf(
            "zh-Hant" to "%@ 本重新分頁失敗，已保留原樣",
            "en" to "%@ notebooks failed and were left unchanged",
            "zh-Hans" to "%@ 本重新分页失败，已保留原样",
            "ja" to "%@ 冊が失敗したため、そのままにしました",
            "ko" to "%@권이 실패하여 원래대로 두었습니다",
            "th" to "%@ เล่มล้มเหลว จึงคงไว้ตามเดิม"
        ),
        "page_model_needs_repagination" to mapOf(
            "zh-Hant" to "有筆記還在用舊版的可延長頁面，匯出與列印無法對齊紙張",
            "en" to "Some notes still use the old extendable pages, so export and printing cannot match paper",
            "zh-Hans" to "有笔记还在用旧版的可延长页面，导出与打印无法对齐纸张",
            "ja" to "一部のノートが旧来の可変長ページのままで、書き出しと印刷が用紙に合いません",
            "ko" to "일부 노트가 예전의 늘어나는 페이지를 사용하고 있어 내보내기와 인쇄가 용지에 맞지 않습니다",
            "th" to "บางบันทึกยังใช้หน้าที่ยืดได้แบบเดิม การส่งออกและการพิมพ์จึงไม่ตรงกับกระดาษ"
        ),
        "page_model_repaginate" to mapOf(
            "zh-Hant" to "重新分頁",
            "en" to "Repaginate",
            "zh-Hans" to "重新分页",
            "ja" to "ページを再分割",
            "ko" to "페이지 다시 나누기",
            "th" to "แบ่งหน้าใหม่"
        ),
        "page_model_section" to mapOf(
            "zh-Hant" to "頁面格式",
            "en" to "Page Format",
            "zh-Hans" to "页面格式",
            "ja" to "ページ形式",
            "ko" to "페이지 형식",
            "th" to "รูปแบบหน้า"
        ),
        "pages" to mapOf(
            "zh-Hant" to "頁",
            "en" to "pages",
            "zh-Hans" to "页",
            "ja" to "ページ",
            "ko" to "페이지",
            "th" to "หน้า"
        ),
        "pages_copied" to mapOf(
            "zh-Hant" to "已複製 %@ 頁到「%@」",
            "en" to "Copied %@ pages to “%@”",
            "zh-Hans" to "已复制 %@ 页到「%@」",
            "ja" to "%@ ページを「%@」にコピーしました",
            "ko" to "%@페이지를 ‘%@’(으)로 복사했습니다",
            "th" to "คัดลอก %@ หน้าไปยัง “%@” แล้ว"
        ),
        "pages_count_suffix" to mapOf(
            "zh-Hant" to "頁",
            "en" to "Pages",
            "zh-Hans" to "页",
            "ja" to "ページ",
            "ko" to "페이지",
            "th" to "หน้า"
        ),
        "pages_moved" to mapOf(
            "zh-Hant" to "已移動 %@ 頁到「%@」",
            "en" to "Moved %@ pages to “%@”",
            "zh-Hans" to "已移动 %@ 页到「%@」",
            "ja" to "%@ ページを「%@」に移動しました",
            "ko" to "%@페이지를 ‘%@’(으)로 이동했습니다",
            "th" to "ย้าย %@ หน้าไปยัง “%@” แล้ว"
        ),
        "pages_selected" to mapOf(
            "zh-Hant" to "已選取 %@ 頁",
            "en" to "%@ pages selected",
            "zh-Hans" to "已选取 %@ 页",
            "ja" to "%@ ページを選択中",
            "ko" to "%@페이지 선택됨",
            "th" to "เลือกไว้ %@ หน้า"
        ),
        "pages_unit" to mapOf(
            "zh-Hant" to "頁",
            "en" to "pages",
            "zh-Hans" to "页",
            "ja" to "ページ",
            "ko" to "페이지",
            "th" to "หน้า"
        ),
        "palette_amber" to mapOf(
            "zh-Hant" to "琥珀",
            "en" to "Amber",
            "zh-Hans" to "琥珀",
            "ja" to "アンバー",
            "ko" to "앰버",
            "th" to "อำพัน"
        ),
        "palette_business" to mapOf(
            "zh-Hant" to "經典商務",
            "en" to "Business",
            "zh-Hans" to "经典商务",
            "ja" to "ビジネス",
            "ko" to "비즈니스",
            "th" to "ธุรกิจ"
        ),
        "palette_forest" to mapOf(
            "zh-Hant" to "森綠",
            "en" to "Forest",
            "zh-Hans" to "森绿",
            "ja" to "フォレスト",
            "ko" to "포레스트",
            "th" to "เขียวป่า"
        ),
        "palette_graphite" to mapOf(
            "zh-Hant" to "石墨",
            "en" to "Graphite",
            "zh-Hans" to "石墨",
            "ja" to "グラファイト",
            "ko" to "그래파이트",
            "th" to "กราไฟต์"
        ),
        "palette_indigo" to mapOf(
            "zh-Hant" to "靛藍",
            "en" to "Indigo",
            "zh-Hans" to "靛蓝",
            "ja" to "インディゴ",
            "ko" to "인디고",
            "th" to "คราม"
        ),
        "palette_morandi" to mapOf(
            "zh-Hant" to "莫蘭迪系",
            "en" to "Morandi",
            "zh-Hans" to "莫兰迪系",
            "ja" to "モランディ",
            "ko" to "모란디",
            "th" to "โมรันดี"
        ),
        "palette_neon" to mapOf(
            "zh-Hant" to "鮮豔霓虹",
            "en" to "Neon Vivid",
            "zh-Hans" to "鲜艳霓虹",
            "ja" to "ネオン",
            "ko" to "네온",
            "th" to "นีออน"
        ),
        "palette_pastel" to mapOf(
            "zh-Hant" to "柔和粉彩",
            "en" to "Pastel",
            "zh-Hans" to "柔和粉彩",
            "ja" to "パステル",
            "ko" to "파스텔",
            "th" to "พาสเทล"
        ),
        "palette_rose" to mapOf(
            "zh-Hant" to "玫瑰",
            "en" to "Rose",
            "zh-Hans" to "玫瑰",
            "ja" to "ローズ",
            "ko" to "로즈",
            "th" to "กุหลาบ"
        ),
        "palette_swatches" to mapOf(
            "zh-Hant" to "經典色卡庫",
            "en" to "Color Palettes",
            "zh-Hans" to "经典色卡库",
            "ja" to "配色パレット",
            "ko" to "색상 팔레트",
            "th" to "จานสีคลาสสิก"
        ),
        "palette_teal" to mapOf(
            "zh-Hant" to "青綠",
            "en" to "Teal",
            "zh-Hans" to "青绿",
            "ja" to "ティール",
            "ko" to "틸",
            "th" to "เขียวน้ำทะเล"
        ),
        "palette_tip" to mapOf(
            "zh-Hant" to "點選色彩可吸取 / 點「插入」貼至畫布",
            "en" to "Tap color to sample / Tap insert to paste swatch",
            "zh-Hans" to "点击颜色可吸取 / 点“插入”贴至画布",
            "ja" to "タップで色取得 /「挿入」で配置",
            "ko" to "색상 탭하여 추출 / \"삽입\"으로 배치",
            "th" to "แตะสีเพื่อเลือก / แตะ \"แทรก\" เพื่อวาง"
        ),
        "palette_vintage" to mapOf(
            "zh-Hant" to "復古手帳",
            "en" to "Vintage",
            "zh-Hans" to "复古手帐",
            "ja" to "ヴィンテージ",
            "ko" to "빈티지",
            "th" to "วินเทจ"
        ),
        "palm_rejection_settings" to mapOf(
            "zh-Hant" to "掌拒靈敏度",
            "en" to "Palm rejection",
            "zh-Hans" to "掌拒灵敏度",
            "ja" to "パームリジェクション",
            "ko" to "손바닥 인식 차단",
            "th" to "การปฏิเสธฝ่ามือ"
        ),
        "palm_threshold_hint" to mapOf(
            "zh-Hant" to "調高比較不會被手掌誤觸，但細的筆尖也可能被當成手掌。改壞了按「恢復預設」。",
            "en" to "Higher values reject palms more aggressively, but a fine nib may also be rejected. Use “Restore defaults” if it goes wrong.",
            "zh-Hans" to "调高比较不会被手掌误触，但细的笔尖也可能被当成手掌。改坏了按「恢复默认」。",
            "ja" to "高くすると手のひらを弾きやすくなりますが、細いペン先も弾かれることがあります。おかしくなったら「既定に戻す」を押してください。",
            "ko" to "값을 높이면 손바닥을 더 잘 걸러내지만 가는 펜촉도 걸러질 수 있습니다. 잘못되면 “기본값 복원”을 누르세요.",
            "th" to "ค่าสูงขึ้นจะกันฝ่ามือได้ดีขึ้น แต่ปลายปากกาที่เล็กอาจถูกกันไปด้วย หากผิดพลาดให้กด “คืนค่าเริ่มต้น”"
        ),
        "palm_threshold_radius" to mapOf(
            "zh-Hant" to "接觸半徑門檻",
            "en" to "Touch radius threshold",
            "zh-Hans" to "接触半径阈值",
            "ja" to "接触半径のしきい値",
            "ko" to "접촉 반경 임계값",
            "th" to "เกณฑ์รัศมีการสัมผัส"
        ),
        "palm_threshold_reset" to mapOf(
            "zh-Hant" to "恢復預設",
            "en" to "Restore defaults",
            "zh-Hans" to "恢复默认",
            "ja" to "既定に戻す",
            "ko" to "기본값 복원",
            "th" to "คืนค่าเริ่มต้น"
        ),
        "palm_threshold_retract" to mapOf(
            "zh-Hant" to "筆落下時的收回時間窗",
            "en" to "Retract window when the pen lands",
            "zh-Hans" to "笔落下时的收回时间窗",
            "ja" to "ペンが触れたときの取り消し時間",
            "ko" to "펜이 닿을 때 되돌릴 시간",
            "th" to "ช่วงเวลาย้อนกลับเมื่อปากกาแตะ"
        )
    )

    private fun part19(): Map<String, Map<String, String>> = mapOf(
        "palm_threshold_retract_hint" to mapOf(
            "zh-Hant" to "手掌常常比筆先碰到螢幕。這段時間內畫出來的手掌筆畫會在筆落下時收回。",
            "en" to "Your palm usually lands before the pen. Palm marks drawn within this window are taken back when the pen touches down.",
            "zh-Hans" to "手掌常常比笔先碰到屏幕。这段时间内画出来的手掌笔画会在笔落下时收回。",
            "ja" to "手のひらはペンより先に触れがちです。この時間内に描かれた手のひらの線は、ペンが触れた時点で取り消されます。",
            "ko" to "보통 펜보다 손바닥이 먼저 닿습니다. 이 시간 안에 그려진 손바닥 자국은 펜이 닿을 때 되돌립니다.",
            "th" to "ฝ่ามือมักแตะก่อนปากกา รอยที่เกิดในช่วงเวลานี้จะถูกย้อนกลับเมื่อปากกาแตะ"
        ),
        "paper_content" to mapOf(
            "zh-Hant" to "這張紙的內容",
            "en" to "Content on this paper",
            "zh-Hans" to "这张纸的内容",
            "ja" to "この用紙の内容",
            "ko" to "이 용지의 내용",
            "th" to "เนื้อหาบนกระดาษนี้"
        ),
        "paper_content_none" to mapOf(
            "zh-Hant" to "不套用，只要空白頁",
            "en" to "Empty page",
            "zh-Hans" to "不套用，只要空白页",
            "ja" to "白紙のまま",
            "ko" to "빈 페이지",
            "th" to "หน้าว่าง"
        ),
        "paper_drafting_steps" to mapOf(
            "zh-Hant" to "作圖步驟紙",
            "en" to "Drafting Steps",
            "zh-Hans" to "作图步骤纸",
            "ja" to "作図ステップ紙",
            "ko" to "작도 단계지",
            "th" to "กระดาษขั้นตอนเขียนแบบ"
        ),
        "paper_drafting_steps_desc" to mapOf(
            "zh-Hant" to "左欄寫 ①②③ 步驟，右邊整片作圖",
            "en" to "Numbered steps ①②③ on the left, a big drawing area on the right",
            "zh-Hans" to "左栏写 ①②③ 步骤，右边整片作图",
            "ja" to "左に①②③の手順、右に広い作図スペース",
            "ko" to "왼쪽에 ①②③ 단계, 오른쪽은 넓은 작도 공간",
            "th" to "ขั้นตอน ①②③ ด้านซ้าย พื้นที่วาดด้านขวา"
        ),
        "paper_drafting_trap" to mapOf(
            "zh-Hant" to "圖學錯誤陷阱頁",
            "en" to "Drafting Trap Page",
            "zh-Hans" to "图学错误陷阱页",
            "ja" to "製図の落とし穴ページ",
            "ko" to "제도 함정 페이지",
            "th" to "หน้าข้อผิดพลาดงานเขียนแบบ"
        ),
        "paper_drafting_trap_desc" to mapOf(
            "zh-Hant" to "錯誤與正確畫法並排，底下記口訣",
            "en" to "Wrong vs. right drawings side by side, with a rule of thumb below",
            "zh-Hans" to "错误与正确画法并排，底下记口诀",
            "ja" to "誤りと正解の描き方を並べ、下にコツを記録",
            "ko" to "틀린 작도와 맞는 작도를 나란히, 아래에 요령 기록",
            "th" to "วาดผิด/ถูกเทียบกัน พร้อมจดเคล็ดลับด้านล่าง"
        ),
        "paper_english_3line" to mapOf(
            "zh-Hant" to "英文三線格",
            "en" to "English Ruled (3-Line)",
            "zh-Hans" to "英文三线格",
            "ja" to "英語罫線（3本線）",
            "ko" to "영어 줄 노트 (3선)",
            "th" to "บรรทัดภาษาอังกฤษ (3 เส้น)"
        ),
        "paper_english_3line_desc" to mapOf(
            "zh-Hant" to "帶有四線三格的英文手寫練習紙",
            "en" to "English handwriting practice paper with ascender, x-height, baseline, descender lines",
            "zh-Hans" to "带有四线三格的英文手写练习纸",
            "ja" to "アセンダー、xハイト、ベースライン、ディセンダーの線が引かれた英語の手書き練習用紙",
            "ko" to "어센더, x-높이, 베이스라인, 디센더 선이 있는 영어 필기 연습지",
            "th" to "กระดาษฝึกเขียนภาษาอังกฤษ มีเส้น ascender, x-height, baseline, descender"
        ),
        "paper_error_book" to mapOf(
            "zh-Hant" to "錯題本",
            "en" to "Error Correction Book",
            "zh-Hans" to "错题本",
            "ja" to "間違い直しノート",
            "ko" to "오답 노트",
            "th" to "สมุดบันทึกข้อผิดพลาด"
        ),
        "paper_error_book_desc" to mapOf(
            "zh-Hant" to "用於記錄錯題與正確解法的分隔排版",
            "en" to "Split layout for recording mistakes and correct solutions",
            "zh-Hans" to "用于记录错题和正确解法的分隔排版",
            "ja" to "間違いと正しい解決策を記録するための分割レイアウト",
            "ko" to "실수와 올바른 풀이를 기록하는 분할 레이아웃",
            "th" to "เลย์เอาต์แบ่งส่วนสำหรับบันทึกข้อผิดพลาดและวิธีแก้ที่ถูกต้อง"
        ),
        "paper_locked_by_doc" to mapOf(
            "zh-Hant" to "紙張由文件範本決定。",
            "en" to "Paper is set by the document template.",
            "zh-Hans" to "纸张由文件范本决定。",
            "ja" to "用紙は文書テンプレートに従います。",
            "ko" to "용지는 문서 서식이 결정합니다.",
            "th" to "กระดาษกำหนดโดยเทมเพลตเอกสาร"
        ),
        "paper_templates_section" to mapOf(
            "zh-Hant" to "紙張樣板",
            "en" to "Paper Templates",
            "zh-Hans" to "纸张样板",
            "ja" to "用紙テンプレート",
            "ko" to "용지 서식",
            "th" to "เทมเพลตกระดาษ"
        ),
        "paragraph_align" to mapOf(
            "zh-Hant" to "段落對齊",
            "en" to "Paragraph Alignment",
            "zh-Hans" to "段落对齐",
            "ja" to "段落の配置",
            "ko" to "단락 정렬",
            "th" to "การจัดแนวข้อความ"
        ),
        "paragraph_indent" to mapOf(
            "zh-Hant" to "縮排",
            "en" to "Indent",
            "zh-Hans" to "缩排",
            "ja" to "インデント",
            "ko" to "들여쓰기",
            "th" to "เยื้อง"
        ),
        "paragraph_spacing" to mapOf(
            "zh-Hant" to "段距",
            "en" to "Para",
            "zh-Hans" to "段距",
            "ja" to "段落間",
            "ko" to "단락 간격",
            "th" to "ระยะย่อหน้า"
        ),
        "paragraph_style" to mapOf(
            "zh-Hant" to "段落",
            "en" to "Paragraph",
            "zh-Hans" to "段落",
            "ja" to "段落",
            "ko" to "단락",
            "th" to "ย่อหน้า"
        ),
        "paste_strokes" to mapOf(
            "zh-Hant" to "貼上",
            "en" to "Paste",
            "zh-Hans" to "粘贴",
            "ja" to "ペースト",
            "ko" to "붙여넣기",
            "th" to "วาง"
        ),
        "paste_strokes_hint" to mapOf(
            "zh-Hant" to "把剪貼簿中的筆劃貼到這一頁",
            "en" to "Paste the strokes from the clipboard onto this page",
            "zh-Hans" to "把剪贴板中的笔画粘贴到这一页",
            "ja" to "クリップボードの筆跡をこのページに貼り付けます",
            "ko" to "클립보드의 필기를 이 페이지에 붙여넣습니다",
            "th" to "วางเส้นจากคลิปบอร์ดลงในหน้านี้"
        ),
        "pause_recording" to mapOf(
            "zh-Hant" to "暫停錄音",
            "en" to "Pause Recording",
            "zh-Hans" to "暂停录音",
            "ja" to "録音を一時停止",
            "ko" to "녹음 일시정지",
            "th" to "หยุดการบันทึกชั่วคราว"
        ),
        "pdf_choose_page" to mapOf(
            "zh-Hant" to "要插入第幾頁？",
            "en" to "Which page?",
            "zh-Hans" to "要插入第几页？",
            "ja" to "何ページ目を挿入しますか？",
            "ko" to "몇 번째 페이지를 넣을까요?",
            "th" to "หน้าไหน?"
        ),
        "pdf_not_a_pdf" to mapOf(
            "zh-Hant" to "這個檔案不是 PDF，或者已經損壞。",
            "en" to "This file isn't a PDF, or it's damaged.",
            "zh-Hans" to "这个文件不是 PDF，或者已经损坏。",
            "ja" to "このファイルは PDF ではないか、壊れています。",
            "ko" to "이 파일은 PDF가 아니거나 손상되었습니다.",
            "th" to "ไฟล์นี้ไม่ใช่ PDF หรือเสียหาย"
        ),
        "pdf_page_out_of_range" to mapOf(
            "zh-Hant" to "第 %1@ 頁不存在，這個 PDF 共 %2@ 頁。",
            "en" to "Page %1@ doesn't exist — this PDF has %2@ pages.",
            "zh-Hans" to "第 %1@ 页不存在，这个 PDF 共 %2@ 页。",
            "ja" to "%1@ ページは存在しません。この PDF は %2@ ページです。",
            "ko" to "%1@ 페이지는 없습니다. 이 PDF는 %2@ 페이지입니다.",
            "th" to "ไม่มีหน้า %1@ — PDF นี้มี %2@ หน้า"
        ),
        "pdf_page_range" to mapOf(
            "zh-Hant" to "這份 PDF 共 %@ 頁",
            "en" to "This PDF has %@ pages",
            "zh-Hans" to "这份 PDF 共 %@ 页",
            "ja" to "この PDF は全 %@ ページです",
            "ko" to "이 PDF는 총 %@페이지입니다",
            "th" to "PDF นี้มี %@ หน้า"
        ),
        "pdf_password_required" to mapOf(
            "zh-Hant" to "這個 PDF 需要密碼。",
            "en" to "This PDF needs a password.",
            "zh-Hans" to "这个 PDF 需要密码。",
            "ja" to "この PDF にはパスワードが必要です。",
            "ko" to "이 PDF는 비밀번호가 필요합니다.",
            "th" to "PDF นี้ต้องใช้รหัสผ่าน"
        ),
        "pdf_render_failed" to mapOf(
            "zh-Hant" to "這一頁畫不出來",
            "en" to "That page could not be drawn",
            "zh-Hans" to "这一页画不出来",
            "ja" to "このページは描画できませんでした",
            "ko" to "이 페이지를 그릴 수 없습니다",
            "th" to "วาดหน้านี้ไม่ได้"
        ),
        "pen_action_eraser" to mapOf(
            "zh-Hant" to "橡皮擦",
            "en" to "Eraser",
            "zh-Hans" to "橡皮擦",
            "ja" to "消しゴム",
            "ko" to "지우개",
            "th" to "ยางลบ"
        ),
        "pen_action_inkAttributes" to mapOf(
            "zh-Hant" to "顯示調色盤",
            "en" to "Show Ink Palette",
            "zh-Hans" to "显示调色盘",
            "ja" to "カラーパレットを表示",
            "ko" to "색상 팔레트 표시",
            "th" to "แสดงจานสี"
        ),
        "pen_action_lasso" to mapOf(
            "zh-Hant" to "套索工具",
            "en" to "Lasso Tool",
            "zh-Hans" to "套索工具",
            "ja" to "なげなわツール",
            "ko" to "올가미 도구",
            "th" to "เครื่องมือบ่วงบาศ"
        ),
        "pen_action_lastBrush" to mapOf(
            "zh-Hant" to "上一個使用的筆刷",
            "en" to "Last Used Brush",
            "zh-Hans" to "上一个使用的笔刷",
            "ja" to "前回使用したブラシ",
            "ko" to "마지막으로 사용한 브러시",
            "th" to "แปรงที่ใช้ล่าสุด"
        ),
        "pen_action_none" to mapOf(
            "zh-Hant" to "無",
            "en" to "None",
            "zh-Hans" to "无",
            "ja" to "なし",
            "ko" to "없음",
            "th" to "ไม่มี"
        ),
        "pen_action_redo" to mapOf(
            "zh-Hant" to "重做",
            "en" to "Redo",
            "zh-Hans" to "重做",
            "ja" to "やり直す",
            "ko" to "다시 실행",
            "th" to "ทำซ้ำ"
        ),
        "pen_action_ruler" to mapOf(
            "zh-Hant" to "顯示尺規",
            "en" to "Show Ruler",
            "zh-Hans" to "显示尺规",
            "ja" to "定規を表示",
            "ko" to "눈금자 표시",
            "th" to "แสดงไม้บรรทัด"
        ),
        "pen_action_undo" to mapOf(
            "zh-Hant" to "復原",
            "en" to "Undo",
            "zh-Hans" to "撤销",
            "ja" to "取り消す",
            "ko" to "실행 취소",
            "th" to "เลิกทำ"
        ),
        "pen_controls_title" to mapOf(
            "zh-Hant" to "側鍵與手勢",
            "en" to "Side Buttons & Gestures",
            "zh-Hans" to "侧键与手势",
            "ja" to "サイドボタンとジェスチャー",
            "ko" to "측면 버튼 및 제스처",
            "th" to "ปุ่มด้านข้างและท่าทาง"
        ),
        "pen_double_tap" to mapOf(
            "zh-Hant" to "雙擊",
            "en" to "Double Tap",
            "zh-Hans" to "双击",
            "ja" to "ダブルタップ",
            "ko" to "두 번 탭하기",
            "th" to "แตะสองครั้ง"
        ),
        "pen_only_toast" to mapOf(
            "zh-Hant" to "已開啟「僅限觸控筆」，手指觸控會被忽略。要用手指寫字請把它關掉。",
            "en" to "“Pen only” is on, so finger touches are ignored. Turn it off to write with your finger.",
            "zh-Hans" to "已开启「仅限触控笔」，手指触控会被忽略。要用手指写字请把它关掉。",
            "ja" to "「ペンのみ」がオンです。指のタッチは無視されます。指で書くにはオフにしてください。",
            "ko" to "“펜 전용”이 켜져 있어 손가락 터치는 무시됩니다. 손가락으로 쓰려면 끄세요.",
            "th" to "เปิด “ปากกาเท่านั้น” อยู่ การแตะด้วยนิ้วจะถูกละเว้น หากต้องการเขียนด้วยนิ้วให้ปิดตัวเลือกนี้"
        ),
        "pen_pressure_apple_note" to mapOf(
            "zh-Hant" to "Apple Pencil 的壓感曲線由系統原生最佳化接管，不支援手動覆寫。",
            "en" to "Apple Pencil pressure curves are optimized natively by the system and cannot be manually overridden.",
            "zh-Hans" to "Apple Pencil 的压感曲线由系统原生优化接管，不支持手动覆盖。",
            "ja" to "Apple Pencil の筆圧カーブはシステムが最適化しており、手動で上書きすることはできません。",
            "ko" to "Apple Pencil의 필압 곡선은 시스템이 기본적으로 최적화하며 수동으로 바꿀 수 없습니다.",
            "th" to "เส้นโค้งแรงกดของ Apple Pencil ถูกระบบปรับให้เหมาะสมอยู่แล้ว ไม่สามารถกำหนดเองได้"
        ),
        "pen_settings_title" to mapOf(
            "zh-Hant" to "進階畫筆設定",
            "en" to "Advanced Pen Settings",
            "zh-Hans" to "高级画笔设置",
            "ja" to "詳細なペン設定",
            "ko" to "고급 펜 설정",
            "th" to "การตั้งค่าปากกาขั้นสูง"
        ),
        "pen_squeeze" to mapOf(
            "zh-Hant" to "擠壓 (Pencil Pro)",
            "en" to "Squeeze (Pencil Pro)",
            "zh-Hans" to "挤压 (Pencil Pro)",
            "ja" to "スクイーズ (Pencil Pro)",
            "ko" to "쥐기 (Pencil Pro)",
            "th" to "บีบ (Pencil Pro)"
        ),
        "permission_open_settings" to mapOf(
            "zh-Hant" to "開啟設定",
            "en" to "Open Settings",
            "zh-Hans" to "打开设置",
            "ja" to "設定を開く",
            "ko" to "설정 열기",
            "th" to "เปิดการตั้งค่า"
        ),
        "place_sticker" to mapOf(
            "zh-Hant" to "放置貼紙",
            "en" to "Place Sticker",
            "zh-Hans" to "放置贴纸",
            "ja" to "ステッカーを配置",
            "ko" to "스티커 배치",
            "th" to "วางสติกเกอร์"
        ),
        "platform_desc" to mapOf(
            "zh-Hant" to "執行平台",
            "en" to "Platform",
            "zh-Hans" to "运行平台",
            "ja" to "プラットフォーム",
            "ko" to "플랫폼",
            "th" to "แพลตฟอร์ม"
        ),
        "posture_tabletop_mode" to mapOf(
            "zh-Hant" to "立起懸停模式 (上觀看下創作)",
            "en" to "Tabletop / Flex Mode",
            "zh-Hans" to "立起悬停模式 (上观看下创作)",
            "ja" to "テーブルトップ／フレックスモード",
            "ko" to "테이블탑 / 플렉스 모드",
            "th" to "โหมดตั้งโต๊ะ / เฟล็กซ์"
        ),
        "posture_tabletop_mode_desc" to mapOf(
            "zh-Hant" to "切換上屏瀏覽、下屏書寫的懸停雙屏模式",
            "en" to "Toggle dual-screen tabletop viewing and editing mode",
            "zh-Hans" to "切换上屏浏览、下屏书写的悬停双屏模式",
            "ja" to "見開き・テーブルトップ表示モードを切り替え",
            "ko" to "상하 듀얼 화면 테이블탑 모드 켜기/끄기",
            "th" to "สลับโหมดโต๊ะทำงานแบบสองหน้าจอ (ดูด้านบน เขียนด้านล่าง)"
        ),
        "preferences_lang" to mapOf(
            "zh-Hant" to "偏好設定與介面語言",
            "en" to "Preferences & Language",
            "zh-Hans" to "偏好设置与界面语言",
            "ja" to "環境設定と表示言語",
            "ko" to "환경설정 및 언어",
            "th" to "การตั้งค่าและภาษา"
        ),
        "pressure_floor" to mapOf(
            "zh-Hant" to "下筆起始壓力",
            "en" to "Pressure Floor",
            "zh-Hans" to "下笔起始压力",
            "ja" to "最小筆圧",
            "ko" to "최소 필압",
            "th" to "แรงกดเริ่มต้น"
        ),
        "pressure_gamma" to mapOf(
            "zh-Hant" to "壓力敏感度曲線",
            "en" to "Pressure Gamma",
            "zh-Hans" to "压力敏感度曲线",
            "ja" to "筆圧感度カーブ",
            "ko" to "필압 감도 곡선",
            "th" to "เส้นโค้งความไวต่อแรงกด"
        ),
        "preview_chart" to mapOf(
            "zh-Hant" to "圖表即時預覽",
            "en" to "Live Chart Preview",
            "zh-Hans" to "图表实时预览",
            "ja" to "プレビュー",
            "ko" to "실시간 미리보기",
            "th" to "ดูตัวอย่างแผนภูมิ"
        ),
        "previous_page" to mapOf(
            "zh-Hant" to "上一頁",
            "en" to "Previous page",
            "zh-Hans" to "上一页",
            "ja" to "前のページ",
            "ko" to "이전 페이지",
            "th" to "หน้าก่อน"
        ),
        "print_err_create" to mapOf(
            "zh-Hant" to "建立列印操作失敗",
            "en" to "Could not start the print job",
            "zh-Hans" to "创建打印任务失败",
            "ja" to "印刷ジョブを作成できませんでした",
            "ko" to "인쇄 작업을 만들지 못했습니다",
            "th" to "สร้างงานพิมพ์ไม่สำเร็จ"
        ),
        "print_err_parse" to mapOf(
            "zh-Hant" to "無法解析 PDF 資料",
            "en" to "Could not read the PDF data",
            "zh-Hans" to "无法解析 PDF 数据",
            "ja" to "PDF データを読み取れませんでした",
            "ko" to "PDF 데이터를 읽을 수 없습니다",
            "th" to "อ่านข้อมูล PDF ไม่ได้"
        ),
        "print_job_title" to mapOf(
            "zh-Hant" to "Kairumo 文件",
            "en" to "Kairumo Document",
            "zh-Hans" to "Kairumo 文档",
            "ja" to "Kairumo ドキュメント",
            "ko" to "Kairumo 문서",
            "th" to "เอกสาร Kairumo"
        ),
        "print_note" to mapOf(
            "zh-Hant" to "列印筆記",
            "en" to "Print Notebook",
            "zh-Hans" to "打印笔记",
            "ja" to "ノートを印刷",
            "ko" to "노트 인쇄",
            "th" to "พิมพ์สมุดบันทึก"
        ),
        "privacy_policy" to mapOf(
            "zh-Hant" to "隱私權政策",
            "en" to "Privacy Policy",
            "zh-Hans" to "隐私政策",
            "ja" to "プライバシーポリシー",
            "ko" to "개인정보 처리방침",
            "th" to "นโยบายความเป็นส่วนตัว"
        ),
        "privacy_policy_desc" to mapOf(
            "zh-Hant" to "沒有帳號、沒有伺服器、沒有追蹤",
            "en" to "No accounts, no servers, no tracking",
            "zh-Hans" to "没有账号、没有服务器、没有追踪",
            "ja" to "アカウントもサーバーも追跡もなし",
            "ko" to "계정도 서버도 추적도 없음",
            "th" to "ไม่มีบัญชี ไม่มีเซิร์ฟเวอร์ ไม่มีการติดตาม"
        ),
        "pro_color" to mapOf(
            "zh-Hant" to "進階調色",
            "en" to "Advanced Color Studio",
            "zh-Hans" to "进阶调色",
            "ja" to "高度な調色",
            "ko" to "고급 색상 조색",
            "th" to "สตูดิโอสีขั้นสูง"
        ),
        "punctuation_marks" to mapOf(
            "zh-Hant" to "標點符號",
            "en" to "Punctuation",
            "zh-Hans" to "标点符号",
            "ja" to "句読点",
            "ko" to "문장 부호",
            "th" to "เครื่องหมายวรรคตอน"
        ),
        "punctuation_symbols" to mapOf(
            "zh-Hant" to "標點符號",
            "en" to "Punctuation",
            "zh-Hans" to "标点符号",
            "ja" to "句読点",
            "ko" to "문장 부호",
            "th" to "เครื่องหมายวรรคตอน"
        ),
        "quick_record" to mapOf(
            "zh-Hant" to "快速錄音",
            "en" to "Quick Record",
            "zh-Hans" to "快速录音",
            "ja" to "クイック録音",
            "ko" to "빠른 녹음",
            "th" to "บันทึกเสียงด่วน"
        ),
        "quick_record_title" to mapOf(
            "zh-Hant" to "語音錄音與對齊",
            "en" to "Audio Recording & Sync",
            "zh-Hans" to "语音录音与对齐",
            "ja" to "音声録音と同期",
            "ko" to "음성 녹음 및 동기화",
            "th" to "การบันทึกเสียงและการซิงค์"
        ),
        "radial_menu" to mapOf(
            "zh-Hant" to "環形快捷工具盤",
            "en" to "Radial tool menu",
            "zh-Hans" to "环形快捷工具盘",
            "ja" to "放射状ツールメニュー",
            "ko" to "방사형 도구 메뉴",
            "th" to "เมนูเครื่องมือแบบวงกลม"
        ),
        "rec_err_convert" to mapOf(
            "zh-Hant" to "音訊轉換失敗：%@",
            "en" to "Audio conversion failed: %@",
            "zh-Hans" to "音频转换失败：%@",
            "ja" to "音声の変換に失敗しました：%@",
            "ko" to "오디오 변환 실패: %@",
            "th" to "แปลงเสียงไม่สำเร็จ: %@"
        ),
        "rec_err_core_start" to mapOf(
            "zh-Hant" to "無法開始錄音：%@",
            "en" to "Could not start recording: %@",
            "zh-Hans" to "无法开始录音：%@",
            "ja" to "録音を開始できませんでした：%@",
            "ko" to "녹음을 시작할 수 없습니다: %@",
            "th" to "เริ่มบันทึกเสียงไม่ได้: %@"
        ),
        "rec_err_engine_start" to mapOf(
            "zh-Hant" to "音訊引擎啟動失敗：%@",
            "en" to "The audio engine failed to start: %@",
            "zh-Hans" to "音频引擎启动失败：%@",
            "ja" to "オーディオエンジンを起動できませんでした：%@",
            "ko" to "오디오 엔진을 시작하지 못했습니다: %@",
            "th" to "เริ่มเครื่องมือเสียงไม่สำเร็จ: %@"
        ),
        "rec_err_feed" to mapOf(
            "zh-Hant" to "餵音訊失敗：%@",
            "en" to "Could not pass audio to the recorder: %@",
            "zh-Hans" to "向录音引擎送入音频失败：%@",
            "ja" to "録音エンジンに音声を渡せませんでした：%@",
            "ko" to "녹음 엔진에 오디오를 전달하지 못했습니다: %@",
            "th" to "ส่งเสียงให้ตัวบันทึกไม่สำเร็จ: %@"
        ),
        "rec_err_no_channels" to mapOf(
            "zh-Hant" to "音訊輸入節點無可用聲道，請確認麥克風連線與系統權限",
            "en" to "The audio input has no usable channel. Check the microphone connection and system permission.",
            "zh-Hans" to "音频输入没有可用声道，请确认麦克风连接与系统权限",
            "ja" to "音声入力に使えるチャンネルがありません。マイクの接続とシステムの権限を確認してください。",
            "ko" to "오디오 입력에 사용할 수 있는 채널이 없습니다. 마이크 연결과 시스템 권한을 확인하세요.",
            "th" to "อินพุตเสียงไม่มีช่องสัญญาณที่ใช้ได้ โปรดตรวจสอบการเชื่อมต่อไมโครโฟนและสิทธิ์ของระบบ"
        ),
        "rec_err_no_mic" to mapOf(
            "zh-Hant" to "裝置未連接麥克風或無可用音訊輸入設備",
            "en" to "No microphone is connected, or no audio input is available",
            "zh-Hans" to "设备未连接麦克风或没有可用的音频输入设备",
            "ja" to "マイクが接続されていないか、使用できる音声入力がありません",
            "ko" to "마이크가 연결되어 있지 않거나 사용할 수 있는 오디오 입력이 없습니다",
            "th" to "ไม่ได้เชื่อมต่อไมโครโฟน หรือไม่มีอุปกรณ์รับเสียงที่ใช้ได้"
        ),
        "rec_err_not_ready" to mapOf(
            "zh-Hant" to "麥克風尚未就緒（取樣率：%1@、聲道：%2@）",
            "en" to "The microphone isn't ready (sample rate: %1@, channels: %2@)",
            "zh-Hans" to "麦克风尚未就绪（采样率：%1@，声道：%2@）",
            "ja" to "マイクの準備ができていません（サンプルレート：%1@、チャンネル：%2@）",
            "ko" to "마이크가 아직 준비되지 않았습니다 (샘플 레이트: %1@, 채널: %2@)",
            "th" to "ไมโครโฟนยังไม่พร้อม (อัตราสุ่มตัวอย่าง: %1@, ช่องสัญญาณ: %2@)"
        ),
        "rec_title_input" to mapOf(
            "zh-Hant" to "錄音標題",
            "en" to "Recording Title",
            "zh-Hans" to "录音标题",
            "ja" to "録音タイトル",
            "ko" to "녹음 제목",
            "th" to "ชื่อการบันทึก"
        ),
        "recent_colors" to mapOf(
            "zh-Hant" to "最近使用",
            "en" to "Recent",
            "zh-Hans" to "最近使用",
            "ja" to "最近使用した色",
            "ko" to "최근 사용",
            "th" to "สีที่ใช้ล่าสุด"
        ),
        "recent_opened" to mapOf(
            "zh-Hant" to "最近開啟",
            "en" to "Recently Opened",
            "zh-Hans" to "最近打开",
            "ja" to "最近開いた",
            "ko" to "최근 열림",
            "th" to "เปิดล่าสุด"
        ),
        "recent_recordings" to mapOf(
            "zh-Hant" to "最近錄音與轉錄",
            "en" to "Recent Recordings & Transcripts",
            "zh-Hans" to "最近录音与转录",
            "ja" to "最近の録音と文字起こし",
            "ko" to "최근 녹음 및 필사",
            "th" to "การบันทึกและการถอดเสียงล่าสุด"
        ),
        "recent_templates" to mapOf(
            "zh-Hant" to "常用樣板",
            "en" to "Recently used",
            "zh-Hans" to "常用样板",
            "ja" to "最近使った",
            "ko" to "최근 사용",
            "th" to "ใช้ล่าสุด"
        ),
        "recognize_handwriting" to mapOf(
            "zh-Hant" to "辨識手寫",
            "en" to "Recognize Handwriting",
            "zh-Hans" to "识别手写",
            "ja" to "手書きを認識",
            "ko" to "손글씨 인식",
            "th" to "รู้จำลายมือ"
        ),
        "recognized_result" to mapOf(
            "zh-Hant" to "已索引 %1@ 組：%2@",
            "en" to "Indexed %1@ group(s): %2@",
            "zh-Hans" to "已索引 %1@ 组：%2@",
            "ja" to "%1@ 組を索引に登録：%2@",
            "ko" to "%1@개 그룹 색인됨: %2@",
            "th" to "จัดทำดัชนี %1@ กลุ่ม: %2@"
        ),
        "recognizing" to mapOf(
            "zh-Hant" to "辨識中…",
            "en" to "Recognizing…",
            "zh-Hans" to "识别中…",
            "ja" to "認識中…",
            "ko" to "인식 중…",
            "th" to "กำลังรู้จำ…"
        ),
        "reconnect_now" to mapOf(
            "zh-Hant" to "立即重連",
            "en" to "Reconnect Now",
            "zh-Hans" to "立即重连",
            "ja" to "今すぐ再接続",
            "ko" to "지금 다시 연결",
            "th" to "เชื่อมต่อใหม่ทันที"
        ),
        "reconnected_sync_complete" to mapOf(
            "zh-Hant" to "已重新連線，離線變更已同步完成",
            "en" to "Reconnected. Offline changes synced.",
            "zh-Hans" to "已重新连接，离线变更已同步完成",
            "ja" to "再接続されました。オフラインの変更が同期されました",
            "ko" to "다시 연결되었습니다. 오프라인 변경 사항이 동기화되었습니다",
            "th" to "เชื่อมต่อใหม่แล้ว ซิงค์การเปลี่ยนแปลงออฟไลน์เรียบร้อยแล้ว"
        ),
        "reconnecting_status" to mapOf(
            "zh-Hant" to "連線中斷，正在自動重新連線 (第 %d/%d 次)...",
            "en" to "Connection lost. Reconnecting (%d/%d)...",
            "zh-Hans" to "连接中断，正在自动重新连接 (第 %d/%d 次)...",
            "ja" to "接続が切断されました。再接続中 (%d/%d)...",
            "ko" to "연결이 끊어졌습니다. 다시 연결하는 중 (%d/%d)...",
            "th" to "การเชื่อมต่อขาดหาย กำลังเชื่อมต่อใหม่ (%d/%d)..."
        )
    )

    private fun part20(): Map<String, Map<String, String>> = mapOf(
        "record" to mapOf(
            "zh-Hant" to "錄音",
            "en" to "Record",
            "zh-Hans" to "录音",
            "ja" to "録音",
            "ko" to "녹음",
            "th" to "บันทึก"
        ),
        "recorded_duration" to mapOf(
            "zh-Hant" to "已錄 %@ 秒",
            "en" to "Recorded %@s",
            "zh-Hans" to "已录 %@ 秒",
            "ja" to "%@ 秒録音",
            "ko" to "%@초 녹음됨",
            "th" to "บันทึกแล้ว %@ วินาที"
        ),
        "recording_advice_clipping" to mapOf(
            "zh-Hant" to "聲音過大並出現破音，請把裝置移遠一些或調低輸入增益。",
            "en" to "The sound was too loud and distorted. Move the device farther away or lower the input gain.",
            "zh-Hans" to "声音过大并出现破音，请把设备移远一些或调低输入增益。",
            "ja" to "音が大きすぎて歪んでいます。端末を少し離すか、入力ゲインを下げてください。",
            "ko" to "소리가 너무 커서 왜곡되었습니다. 기기를 조금 더 멀리 두거나 입력 게인을 낮추세요.",
            "th" to "เสียงดังเกินไปจนแตก โปรดวางอุปกรณ์ให้ไกลขึ้นหรือลดเกนขาเข้า"
        ),
        "recording_advice_noisy" to mapOf(
            "zh-Hant" to "背景雜訊偏高，請把裝置靠近講者，或關閉附近的冷氣或風扇。",
            "en" to "Background noise was high. Move closer to the speaker or turn off nearby air conditioning or fans.",
            "zh-Hans" to "背景噪声偏高，请把设备靠近说话者，或关闭附近的空调或风扇。",
            "ja" to "周囲の雑音が大きめです。話者に近づけるか、近くの空調や扇風機を止めてください。",
            "ko" to "배경 소음이 높습니다. 발표자에게 더 가까이 두거나 주변의 에어컨 또는 선풍기를 끄세요.",
            "th" to "เสียงรบกวนพื้นหลังค่อนข้างดัง โปรดวางอุปกรณ์ใกล้ผู้พูดขึ้น หรือปิดเครื่องปรับอากาศหรือพัดลมที่อยู่ใกล้ ๆ"
        ),
        "recording_advice_quiet" to mapOf(
            "zh-Hant" to "聲音偏小，請把裝置靠近講者。",
            "en" to "The sound was quiet. Move the device closer to the speaker.",
            "zh-Hans" to "声音偏小，请把设备靠近说话者。",
            "ja" to "音が小さめです。端末を話者に近づけてください。",
            "ko" to "소리가 작습니다. 기기를 발표자에게 더 가까이 두세요.",
            "th" to "เสียงค่อนข้างเบา โปรดวางอุปกรณ์ให้ใกล้ผู้พูดขึ้น"
        ),
        "recording_advice_title" to mapOf(
            "zh-Hant" to "錄音品質提示",
            "en" to "Recording quality tip",
            "zh-Hans" to "录音质量提示",
            "ja" to "録音品質のヒント",
            "ko" to "녹음 품질 안내",
            "th" to "คำแนะนำคุณภาพการบันทึก"
        ),
        "recording_default_title" to mapOf(
            "zh-Hant" to "語音錄音",
            "en" to "Voice recording",
            "zh-Hans" to "语音录音",
            "ja" to "音声録音",
            "ko" to "음성 녹음",
            "th" to "บันทึกเสียง"
        ),
        "recording_failed" to mapOf(
            "zh-Hant" to "錄音啟動失敗",
            "en" to "Recording could not start",
            "zh-Hans" to "录音启动失败",
            "ja" to "録音を開始できませんでした",
            "ko" to "녹음을 시작할 수 없습니다",
            "th" to "เริ่มบันทึกเสียงไม่ได้"
        ),
        "recording_inbox" to mapOf(
            "zh-Hant" to "錄音收件匣",
            "en" to "Recording Inbox",
            "zh-Hans" to "录音收件匣",
            "ja" to "録音インボックス",
            "ko" to "녹음 받은함",
            "th" to "กล่องขาเข้าการบันทึก"
        ),
        "recording_mic_mode" to mapOf(
            "zh-Hant" to "收音模式",
            "en" to "Mic Mode",
            "zh-Hans" to "收音模式",
            "ja" to "マイクモード",
            "ko" to "마이크 모드",
            "th" to "โหมดไมโครโฟน"
        ),
        "recording_paused" to mapOf(
            "zh-Hant" to "錄音已暫停",
            "en" to "Recording Paused",
            "zh-Hans" to "录音已暂停",
            "ja" to "録音一時停止中",
            "ko" to "녹음 일시정지됨",
            "th" to "หยุดการบันทึกชั่วคราวแล้ว"
        ),
        "recording_suffix" to mapOf(
            "zh-Hant" to "錄音",
            "en" to "Recording",
            "zh-Hans" to "录音",
            "ja" to "録音",
            "ko" to "녹음",
            "th" to "การบันทึก"
        ),
        "recording_title" to mapOf(
            "zh-Hant" to "錄音標題",
            "en" to "Recording Title",
            "zh-Hans" to "录音标题",
            "ja" to "録音タイトル",
            "ko" to "녹음 제목",
            "th" to "ชื่อการบันทึก"
        ),
        "recovery_confirm_prompt" to mapOf(
            "zh-Hant" to "請把復原碼輸入一次，確認你真的抄下來了",
            "en" to "Type the recovery code back to confirm you wrote it down",
            "zh-Hans" to "请把复原码输入一次，确认你真的抄下来了",
            "ja" to "書き留めたことを確認するため、リカバリーコードを入力してください",
            "ko" to "적어 두었는지 확인하기 위해 복구 코드를 입력하세요",
            "th" to "พิมพ์รหัสกู้คืนอีกครั้งเพื่อยืนยันว่าคุณจดไว้แล้ว"
        ),
        "recovery_copy" to mapOf(
            "zh-Hant" to "複製",
            "en" to "Copy",
            "zh-Hans" to "复制",
            "ja" to "コピー",
            "ko" to "복사",
            "th" to "คัดลอก"
        ),
        "recovery_mismatch" to mapOf(
            "zh-Hant" to "與剛才顯示的不一致",
            "en" to "That does not match the code shown",
            "zh-Hans" to "與剛才顯示的不一致",
            "ja" to "表示されたコードと一致しません",
            "ko" to "표시된 코드와 일치하지 않습니다",
            "th" to "ไม่ตรงกับรหัสที่แสดง"
        ),
        "recovery_title" to mapOf(
            "zh-Hant" to "請抄下你的復原碼",
            "en" to "Write down your recovery code",
            "zh-Hans" to "请抄下你的复原码",
            "ja" to "リカバリーコードを書き留めてください",
            "ko" to "복구 코드를 적어 두세요",
            "th" to "จดรหัสกู้คืนของคุณไว้"
        ),
        "recovery_warning" to mapOf(
            "zh-Hant" to "沒有「忘記密碼」這回事。忘了密碼時，這組碼是唯一的後路，而且只顯示這一次。",
            "en" to "There is no password reset. If you forget your passphrase, this code is the ONLY way back. It is shown once.",
            "zh-Hans" to "没有「忘记密码」这回事。忘了密码时，这组码是唯一的后路，而且只显示这一次。",
            "ja" to "パスワードの再設定はできません。パスフレーズを忘れた場合、このコードだけが唯一の手段です。表示は一度きりです。",
            "ko" to "비밀번호 재설정이 없습니다. 암호를 잊으면 이 코드가 유일한 방법입니다. 한 번만 표시됩니다.",
            "th" to "ไม่มีการรีเซ็ตรหัสผ่าน หากลืมรหัส โค้ดนี้คือทางเดียว และแสดงเพียงครั้งเดียว"
        ),
        "redo" to mapOf(
            "zh-Hant" to "重做",
            "en" to "Redo",
            "zh-Hans" to "重做",
            "ja" to "やり直し",
            "ko" to "다시 실행",
            "th" to "ทำซ้ำ"
        ),
        "redo_desc" to mapOf(
            "zh-Hant" to "重做上一步被復原的操作",
            "en" to "Redo previously undone action",
            "zh-Hans" to "重做上一步被撤销的操作",
            "ja" to "取り消した操作をやり直す",
            "ko" to "실행 취소한 작업 다시 실행",
            "th" to "ทำซ้ำการกระทำที่เลิกทำไป"
        ),
        "redo_refine" to mapOf(
            "zh-Hant" to "重做修飾",
            "en" to "Redo Refine",
            "zh-Hans" to "重做修饰",
            "ja" to "やり直す",
            "ko" to "다시 실행",
            "th" to "ทำซ้ำการปรับแต่ง"
        ),
        "refine_sketch" to mapOf(
            "zh-Hant" to "草圖修飾",
            "en" to "Refine Sketch",
            "zh-Hans" to "草图修饰",
            "ja" to "スケッチ補正",
            "ko" to "스케치 보정",
            "th" to "ปรับแต่งภาพร่าง"
        ),
        "refine_strength" to mapOf(
            "zh-Hant" to "修飾強度",
            "en" to "Intensity",
            "zh-Hans" to "修饰强度",
            "ja" to "補正強度",
            "ko" to "보정 강도",
            "th" to "ความเข้มข้น"
        ),
        "relay_invalid_port" to mapOf(
            "zh-Hant" to "無效的埠號 %@",
            "en" to "Invalid port number %@",
            "zh-Hans" to "无效的端口号 %@",
            "ja" to "ポート番号 %@ は無効です",
            "ko" to "잘못된 포트 번호 %@",
            "th" to "หมายเลขพอร์ต %@ ไม่ถูกต้อง"
        ),
        "relay_needs_tls" to mapOf(
            "zh-Hant" to "這個中繼在公開網路上，必須用 wss://（加密）。ws:// 只允許用在你自己的區域網路裡。",
            "en" to "This relay is on the public internet, so it must use wss:// (encrypted). Plain ws:// is only allowed on your own local network.",
            "zh-Hans" to "这个中继在公开网络上，必须用 wss://（加密）。ws:// 只允许用在你自己的局域网里。",
            "ja" to "この中継サーバーはインターネット上にあるため、wss://（暗号化）が必要です。ws:// はローカルネットワーク内でのみ使えます。",
            "ko" to "이 중계 서버는 인터넷에 있으므로 wss://(암호화)를 써야 합니다. ws://는 같은 로컬 네트워크에서만 허용됩니다.",
            "th" to "เซิร์ฟเวอร์รีเลย์นี้อยู่บนอินเทอร์เน็ต จึงต้องใช้ wss:// (เข้ารหัส) ส่วน ws:// ใช้ได้เฉพาะในเครือข่ายภายในเท่านั้น"
        ),
        "relay_remote_hint" to mapOf(
            "zh-Hant" to "不在同一個網路？協同並不限於單一網路。把你自己掌握的中繼填成 wss://…（TLS 位址），所有人就能從任何地方加入。明文 ws:// 只允許用在你自己的私有網路裡 —— 內容雖然已加密，房號與成員名單仍是明文。三種取得方式見操作手冊。",
            "en" to "Not on the same network? Collaboration is not limited to one network. Enter any relay you control as wss://… (a TLS address) and everyone can join from anywhere. Plain ws:// is only accepted inside your own private network, because the room ID and membership travel in the clear even though the content does not. See the manual for three ways to get one.",
            "zh-Hans" to "不在同一个网络？协作并不限于单一网络。把你自己掌握的中继填成 wss://…（TLS 地址），所有人就能从任何地方加入。明文 ws:// 只允许用在你自己的私有网络里 —— 内容虽然已加密，房号与成员名单仍是明文。三种取得方式见操作手册。",
            "ja" to "同じネットワークでなくても使えます。共同編集は1つのネットワークに縛られません。自分で用意した中継を wss://…（TLS）で指定すれば、どこからでも参加できます。内容は暗号化されていてもルームIDや参加者は平文で流れるため、ws:// は自分のプライベートネットワーク内でのみ許可されます。入手方法は3通り、手引きを参照してください。",
            "ko" to "같은 네트워크가 아니어도 됩니다. 협업은 한 네트워크에 묶여 있지 않습니다. 직접 운영하는 중계를 wss://…(TLS)로 입력하면 어디서든 참여할 수 있습니다. 내용은 암호화되지만 룸 ID와 참여자 정보는 평문으로 흐르므로 ws:// 는 자신의 사설 네트워크 안에서만 허용됩니다. 준비하는 세 가지 방법은 설명서를 참고하세요.",
            "th" to "ไม่ได้อยู่เครือข่ายเดียวกันก็ใช้ได้ การทำงานร่วมกันไม่ได้ผูกกับเครือข่ายเดียว กรอกที่อยู่รีเลย์ที่คุณดูแลเองเป็น wss://… (TLS) แล้วทุกคนเข้าร่วมจากที่ไหนก็ได้ ws:// ธรรมดาอนุญาตเฉพาะในเครือข่ายส่วนตัวของคุณ เพราะ Room ID และรายชื่อผู้เข้าร่วมส่งแบบไม่เข้ารหัสแม้เนื้อหาจะเข้ารหัสแล้ว ดูสามวิธีได้ในคู่มือ"
        ),
        "relay_server_address" to mapOf(
            "zh-Hant" to "協同伺服器位址",
            "en" to "Relay Server Address",
            "zh-Hans" to "协同服务器地址",
            "ja" to "中継サーバーアドレス",
            "ko" to "중계 서버 주소",
            "th" to "ที่อยู่เซิร์ฟเวอร์รีเลย์"
        ),
        "relay_url_empty" to mapOf(
            "zh-Hant" to "請先填入中繼位址。",
            "en" to "Enter a relay address first.",
            "zh-Hans" to "请先填入中继位址。",
            "ja" to "先に中継サーバーのアドレスを入力してください。",
            "ko" to "먼저 중계 서버 주소를 입력하세요.",
            "th" to "กรุณาใส่ที่อยู่รีเลย์ก่อน"
        ),
        "relay_url_scheme" to mapOf(
            "zh-Hant" to "中繼位址必須以 ws:// 或 wss:// 開頭。",
            "en" to "The relay address must start with ws:// or wss://.",
            "zh-Hans" to "中继位址必须以 ws:// 或 wss:// 开头。",
            "ja" to "中継サーバーのアドレスは ws:// または wss:// で始まる必要があります。",
            "ko" to "중계 서버 주소는 ws:// 또는 wss:// 로 시작해야 합니다.",
            "th" to "ที่อยู่รีเลย์ต้องขึ้นต้นด้วย ws:// หรือ wss://"
        ),
        "remove_border" to mapOf(
            "zh-Hant" to "刪除邊框",
            "en" to "Remove Border",
            "zh-Hans" to "删除边框",
            "ja" to "枠線を削除",
            "ko" to "테두리 제거",
            "th" to "ลบเส้นขอบ"
        ),
        "remove_cache" to mapOf(
            "zh-Hant" to "移除本機快取",
            "en" to "Remove Local Cache",
            "zh-Hans" to "移除本地缓存",
            "ja" to "ローカルキャッシュを削除",
            "ko" to "로컬 캐시 제거",
            "th" to "ลบแคชในเครื่อง"
        ),
        "remove_image_from_canvas" to mapOf(
            "zh-Hant" to "從畫布移除",
            "en" to "Remove from canvas",
            "zh-Hans" to "从画布移除",
            "ja" to "キャンバスから削除",
            "ko" to "캔버스에서 제거",
            "th" to "ลบออกจากผืนผ้าใบ"
        ),
        "rename_audio_card" to mapOf(
            "zh-Hant" to "重新命名錄音卡片",
            "en" to "Rename recording card",
            "zh-Hans" to "重新命名录音卡片",
            "ja" to "録音カードの名前を変更",
            "ko" to "녹음 카드 이름 바꾸기",
            "th" to "เปลี่ยนชื่อการ์ดเสียง"
        ),
        "rename_folder" to mapOf(
            "zh-Hant" to "重新命名資料夾",
            "en" to "Rename Folder",
            "zh-Hans" to "重命名文件夹",
            "ja" to "フォルダ名を変更",
            "ko" to "폴더 이름 변경",
            "th" to "เปลี่ยนชื่อโฟลเดอร์"
        ),
        "rename_note" to mapOf(
            "zh-Hant" to "重新命名筆記",
            "en" to "Rename Notebook",
            "zh-Hans" to "重命名笔记",
            "ja" to "ノートの名前を変更",
            "ko" to "노트 이름 바꾸기",
            "th" to "เปลี่ยนชื่อสมุดบันทึก"
        ),
        "reopen" to mapOf(
            "zh-Hant" to "重新開啟",
            "en" to "Reopen",
            "zh-Hans" to "重新开启",
            "ja" to "再オープン",
            "ko" to "다시 열기",
            "th" to "เปิดใหม่"
        ),
        "repagination_mismatch" to mapOf(
            "zh-Hant" to "重新分頁前後內容不符：筆畫 %1@→%2@、物件 %3@→%4@",
            "en" to "Content changed during repagination: strokes %1@→%2@, objects %3@→%4@",
            "zh-Hans" to "重新分页前后内容不符：笔画 %1@→%2@、对象 %3@→%4@",
            "ja" to "ページ再分割の前後で内容が一致しません：筆跡 %1@→%2@、オブジェクト %3@→%4@",
            "ko" to "페이지 다시 나누기 전후의 내용이 다릅니다: 획 %1@→%2@, 개체 %3@→%4@",
            "th" to "เนื้อหาไม่ตรงกันก่อนและหลังแบ่งหน้าใหม่: ลายเส้น %1@→%2@ วัตถุ %3@→%4@"
        ),
        "reply" to mapOf(
            "zh-Hant" to "回覆",
            "en" to "Reply",
            "zh-Hans" to "回复",
            "ja" to "返信",
            "ko" to "답글",
            "th" to "ตอบกลับ"
        ),
        "reset" to mapOf(
            "zh-Hant" to "重設",
            "en" to "Reset",
            "zh-Hans" to "重置",
            "ja" to "リセット",
            "ko" to "초기화",
            "th" to "รีเซ็ต"
        ),
        "resize" to mapOf(
            "zh-Hant" to "調整大小",
            "en" to "Resize",
            "zh-Hans" to "调整大小",
            "ja" to "サイズ変更",
            "ko" to "크기 조절",
            "th" to "ปรับขนาด"
        ),
        "resize_audio_card" to mapOf(
            "zh-Hant" to "調整錄音卡片大小",
            "en" to "Resize recording card",
            "zh-Hans" to "调整录音卡片大小",
            "ja" to "録音カードのサイズを変更",
            "ko" to "녹음 카드 크기 조정",
            "th" to "ปรับขนาดการ์ดเสียง"
        ),
        "resize_handle" to mapOf(
            "zh-Hant" to "調整大小把手",
            "en" to "Resize handle",
            "zh-Hans" to "调整大小把手",
            "ja" to "サイズ変更ハンドル",
            "ko" to "크기 조절 핸들",
            "th" to "ที่จับปรับขนาด"
        ),
        "resize_link" to mapOf(
            "zh-Hant" to "調整連結卡片大小",
            "en" to "Resize link card",
            "zh-Hans" to "调整链接卡片大小",
            "ja" to "リンクカードのサイズを変更",
            "ko" to "링크 카드 크기 조정",
            "th" to "ปรับขนาดการ์ดลิงก์"
        ),
        "resize_shape" to mapOf(
            "zh-Hant" to "調整形狀大小",
            "en" to "Resize shape",
            "zh-Hans" to "调整形状大小",
            "ja" to "図形のサイズを変更",
            "ko" to "도형 크기 조절",
            "th" to "ปรับขนาดรูปทรง"
        ),
        "resize_sidebar" to mapOf(
            "zh-Hant" to "拖曳調整側欄寬度",
            "en" to "Drag to Resize Sidebar",
            "zh-Hans" to "拖曳调整侧栏宽度",
            "ja" to "ドラッグでサイドバーの幅を変更",
            "ko" to "드래그하여 사이드바 너비 조절",
            "th" to "ลากเพื่อปรับความกว้างแถบข้าง"
        ),
        "resize_text_box" to mapOf(
            "zh-Hant" to "拖曳調整文字方塊大小",
            "en" to "Drag to resize the text box",
            "zh-Hans" to "拖曳调整文字方块大小",
            "ja" to "ドラッグしてテキストボックスのサイズを変更",
            "ko" to "끌어서 텍스트 상자 크기 조절",
            "th" to "ลากเพื่อปรับขนาดกล่องข้อความ"
        ),
        "resolve" to mapOf(
            "zh-Hant" to "標記為已解決",
            "en" to "Resolve",
            "zh-Hans" to "标记为已解决",
            "ja" to "解決済みにする",
            "ko" to "해결됨으로 표시",
            "th" to "ทำเครื่องหมายว่าแก้ไขแล้ว"
        ),
        "resolved" to mapOf(
            "zh-Hant" to "已解決",
            "en" to "Resolved",
            "zh-Hans" to "已解决",
            "ja" to "解決済み",
            "ko" to "해결됨",
            "th" to "แก้ไขแล้ว"
        ),
        "responsive_asset_desc" to mapOf(
            "zh-Hant" to "隨需下載高解析實體規格圖與 3D 零組件",
            "en" to "Download on-demand physical specs & 3D models",
            "zh-Hans" to "随需下载高解析实体规格图与 3D 零部件",
            "ja" to "高解像度の仕様書と3DモデルをオンデマンドDL",
            "ko" to "고해상도 실제 사양도 및 3D 부품 온디맨드 다운로드",
            "th" to "ดาวน์โหลดสเปกจริงและชิ้นส่วน 3D ตามความต้องการ"
        ),
        "restore_original" to mapOf(
            "zh-Hant" to "恢復原草圖",
            "en" to "Restore Original",
            "zh-Hans" to "恢复原草图",
            "ja" to "元に戻す",
            "ko" to "원본 복원",
            "th" to "กู้คืนต้นฉบับ"
        ),
        "restore_snapshot" to mapOf(
            "zh-Hant" to "回滾至此版本",
            "en" to "Rollback to Snapshot",
            "zh-Hans" to "回滚至此版本",
            "ja" to "このバージョンに復元",
            "ko" to "이 버전으로 롤백",
            "th" to "ย้อนกลับไปยังเวอร์ชันนี้"
        ),
        "restore_snapshot_confirm" to mapOf(
            "zh-Hant" to "確認要將筆記回滾至此快照？當前未保存的內容將被取代。",
            "en" to "Roll back notebook to this snapshot? Current unsaved changes will be replaced.",
            "zh-Hans" to "确认要将笔记回滚至此快照？当前未保存的内容将被替换。",
            "ja" to "ノートをこのスナップショットにロールバックしますか？現在の未保存内容は置換されます。",
            "ko" to "노트를 이 스냅샷으로 롤백하시겠습니까? 저장되지 않은 변경 사항은 대체됩니다.",
            "th" to "ย้อนกลับสมุดบันทึกเป็นสแนปช็อตนี้หรือไม่? การเปลี่ยนแปลงปัจจุบันจะถูกแทนที่"
        ),
        "resume_recording" to mapOf(
            "zh-Hant" to "繼續錄音",
            "en" to "Resume Recording",
            "zh-Hans" to "继续录音",
            "ja" to "録音を再開",
            "ko" to "녹음 재개",
            "th" to "บันทึกต่อ"
        ),
        "revert_confirm_action" to mapOf(
            "zh-Hant" to "捨棄並恢復",
            "en" to "Discard & Revert",
            "zh-Hans" to "舍弃并恢复",
            "ja" to "破棄して復元",
            "ko" to "버리고 복원",
            "th" to "ละทิ้งและย้อนกลับ"
        ),
        "revert_to_initial_state" to mapOf(
            "zh-Hant" to "一鍵恢復初始狀態",
            "en" to "Revert to Initial State",
            "zh-Hans" to "一键恢复初始状态",
            "ja" to "開いた時の状態に戻す",
            "ko" to "열었을 때 상태로 복원",
            "th" to "ย้อนกลับเป็นสถานะเริ่มต้น"
        ),
        "revert_to_initial_state_confirm" to mapOf(
            "zh-Hant" to "確定要捨棄打開筆記本以來的所有編輯內容，恢復到打開前的初始狀態嗎？",
            "en" to "Are you sure you want to discard all edits made since opening this notebook and revert to its initial state?",
            "zh-Hans" to "确定要舍弃打开笔记本以来的所有编辑内容，恢复到打开前的初始状态吗？",
            "ja" to "このノートを開いてからのすべての編集を破棄し、開いた直後の初期状態に戻しますか？",
            "ko" to "이 노트를 연 이후의 모든 편집 내용을 버리고 초기 상태로 되돌리시겠습니까?",
            "th" to "คุณแน่ใจหรือไม่ว่าต้องการละทิ้งการแก้ไขทั้งหมดนับตั้งแต่เปิดสมุดบันทึกนี้และย้อนกลับเป็นสถานะเริ่มต้น?"
        ),
        "role_editor" to mapOf(
            "zh-Hant" to "編輯者",
            "en" to "Editor",
            "zh-Hans" to "编辑者",
            "ja" to "編集者",
            "ko" to "편집자",
            "th" to "ผู้แก้ไข"
        ),
        "role_owner" to mapOf(
            "zh-Hant" to "房主 (擁有者)",
            "en" to "Host (Owner)",
            "zh-Hans" to "房主 (拥有者)",
            "ja" to "ホスト (所有者)",
            "ko" to "방장 (소유자)",
            "th" to "เจ้าของห้อง"
        ),
        "role_viewer" to mapOf(
            "zh-Hant" to "檢視者",
            "en" to "Viewer",
            "zh-Hans" to "查看者",
            "ja" to "閲覧者",
            "ko" to "뷰어",
            "th" to "ผู้ชม"
        ),
        "roman_numerals" to mapOf(
            "zh-Hant" to "羅馬符號",
            "en" to "Roman Numerals",
            "zh-Hans" to "罗马符号",
            "ja" to "ローマ数字",
            "ko" to "로마 숫자",
            "th" to "ตัวเลขโรมัน"
        ),
        "roman_symbols" to mapOf(
            "zh-Hant" to "羅馬符號",
            "en" to "Roman Numerals",
            "zh-Hans" to "罗马符号",
            "ja" to "ローマ数字",
            "ko" to "로마 숫자",
            "th" to "เลขโรมัน"
        ),
        "room_id" to mapOf(
            "zh-Hant" to "房間識別碼",
            "en" to "Room ID",
            "zh-Hans" to "房间识别码",
            "ja" to "ルームID",
            "ko" to "방 ID",
            "th" to "รหัสห้อง"
        ),
        "room_id_copied" to mapOf(
            "zh-Hant" to "已複製房間識別碼",
            "en" to "Room ID Copied",
            "zh-Hans" to "已复制房间识别码",
            "ja" to "ルームIDをコピーしました",
            "ko" to "방 ID가 복사되었습니다",
            "th" to "คัดลอกรหัสห้องแล้ว"
        ),
        "root_folder" to mapOf(
            "zh-Hant" to "最上層資料夾",
            "en" to "Root Folder",
            "zh-Hans" to "最上层文件夹",
            "ja" to "ルートフォルダ",
            "ko" to "최상위 폴더",
            "th" to "โฟลเดอร์ระดับบนสุด"
        ),
        "rotate_handle" to mapOf(
            "zh-Hant" to "旋轉把手",
            "en" to "Rotate handle",
            "zh-Hans" to "旋转把手",
            "ja" to "回転ハンドル",
            "ko" to "회전 핸들",
            "th" to "ที่จับหมุน"
        ),
        "rotate_hint" to mapOf(
            "zh-Hant" to "拖曳旋轉3D視角",
            "en" to "Drag to Rotate",
            "zh-Hans" to "拖拽旋转3D视角",
            "ja" to "ドラッグして回転",
            "ko" to "드래그하여 회전",
            "th" to "ลากเพื่อหมุน"
        ),
        "rotate_right_90" to mapOf(
            "zh-Hant" to "向右轉 90°",
            "en" to "Rotate 90°",
            "zh-Hans" to "向右转 90°",
            "ja" to "90° 回転",
            "ko" to "90° 회전",
            "th" to "หมุน 90°"
        ),
        "rotation_free_hint" to mapOf(
            "zh-Hant" to "拖曳把手旋轉，靠近 15° 的倍數會自動吸附",
            "en" to "Drag the handle to rotate; hold near 15° steps to snap",
            "zh-Hans" to "拖动把手旋转，靠近 15° 的倍数会自动吸附",
            "ja" to "ハンドルをドラッグして回転。15°付近でスナップします",
            "ko" to "핸들을 끌어 회전하세요. 15° 부근에서 스냅됩니다",
            "th" to "ลากที่จับเพื่อหมุน จะดูดเข้าทุก 15°"
        ),
        "route_elbow" to mapOf(
            "zh-Hant" to "直角折線",
            "en" to "Elbow",
            "zh-Hans" to "直角折线",
            "ja" to "直角",
            "ko" to "꺾은선",
            "th" to "เส้นหักมุม"
        ),
        "route_straight" to mapOf(
            "zh-Hant" to "直線",
            "en" to "Straight",
            "zh-Hans" to "直线",
            "ja" to "直線",
            "ko" to "직선",
            "th" to "เส้นตรง"
        ),
        "rule_of_thirds_desc" to mapOf(
            "zh-Hant" to "標準三等分縱橫輔助線與交會四點焦點指示",
            "en" to "Standard 3x3 grid lines with 4 intersection power points",
            "zh-Hans" to "标准三等分纵横辅助线与交会四点焦点指示",
            "ja" to "標準3分割ラインと4つの交点フォーカス表示",
            "ko" to "표준 3분할 라인 및 4개 교차점 초점 가이드",
            "th" to "เส้นกริดมาตรฐาน 3x3 พร้อมจุดโฟกัส 4 จุด"
        ),
        "rule_of_thirds_ref" to mapOf(
            "zh-Hant" to "九宮格三分構圖線 (Rule of Thirds)",
            "en" to "Rule of Thirds Grid",
            "zh-Hans" to "九宫格三分构图线 (Rule of Thirds)",
            "ja" to "三分割構図ガイド",
            "ko" to "3등분 법칙 격자",
            "th" to "ตารางกฎสามส่วน"
        ),
        "ruler" to mapOf(
            "zh-Hant" to "尺規輔助線",
            "en" to "Ruler Guide",
            "zh-Hans" to "标尺辅助线",
            "ja" to "定規ガイド",
            "ko" to "자 가이드",
            "th" to "เส้นบรรทัดนำสายตา"
        ),
        "ruler_desc" to mapOf(
            "zh-Hant" to "切換顯示精密虛擬尺規輔助線",
            "en" to "Toggle virtual precision ruler guide",
            "zh-Hans" to "切换显示精密虚拟尺规辅助线",
            "ja" to "仮想ルーラー（定規）ガイドを表示・非表示",
            "ko" to "가상 정밀 눈금자 가이드라인 켜기/끄기",
            "th" to "สลับการแสดงไม้บรรทัดนำทางเสมือนจริง"
        ),
        "ruler_hint" to mapOf(
            "zh-Hant" to "• 提示：觸控板兩指旋轉，或按住 Option 鍵滑動旋轉",
            "en" to "• Hint: Rotate with two fingers on trackpad or hold Option while dragging",
            "zh-Hans" to "• 提示：触控板两指旋转，或按住 Option 键滑动旋转",
            "ja" to "• ヒント：トラックパッドを2本指で回転、またはOptionキーを押しながら回転",
            "ko" to "• 힌트: 트랙패드 두 손가락 회전, 또는 Option 키를 누른 채 드래그하여 회전",
            "th" to "• คำแนะนำ: หมุนด้วยสองนิ้วบนแทร็กแพด หรือกด Option ค้างไว้ขณะลาก"
        ),
        "ruler_mode" to mapOf(
            "zh-Hant" to "尺規量測模式",
            "en" to "Ruler & Measurement Mode",
            "zh-Hans" to "标尺量测模式",
            "ja" to "定規・測定モード",
            "ko" to "자 및 측정 모드",
            "th" to "โหมดไม้บรรทัดและการวัด"
        ),
        "sample_data" to mapOf(
            "zh-Hant" to "載入範例數據",
            "en" to "Load Sample Data",
            "zh-Hans" to "载入范例数据",
            "ja" to "サンプル読込",
            "ko" to "샘플 불러오기",
            "th" to "โหลดข้อมูลตัวอย่าง"
        ),
        "sample_lectures" to mapOf(
            "zh-Hant" to "課堂與會議記錄",
            "en" to "Lectures & Meetings",
            "zh-Hans" to "课堂与会议记录",
            "ja" to "講義と会議のノート",
            "ko" to "강의 및 회의",
            "th" to "การบรรยายและการประชุม"
        ),
        "sample_meeting_agenda_table" to mapOf(
            "zh-Hant" to "時間|議題|負責\n10:00|上週進度回顧|文萱\n10:15|手寫延遲量測結果|建豪\n10:35|上架時程與待補項目|佩宜\n10:50|下週分工|全員",
            "en" to "Time|Topic|Owner\n10:00|Last week in review|Wen\n10:15|Ink latency measurements|Chien\n10:35|Release timeline and gaps|Pei\n10:50|Next week's split|Everyone",
            "zh-Hans" to "时间|议题|负责\n10:00|上周进度回顾|文萱\n10:15|手写延迟量测结果|建豪\n10:35|上架时程与待补项目|佩宜\n10:50|下周分工|全员",
            "ja" to "時間|議題|担当\n10:00|先週の振り返り|ウェン\n10:15|手書き遅延の計測結果|チェン\n10:35|リリース日程と未対応項目|ペイ\n10:50|来週の分担|全員",
            "ko" to "시간|주제|담당\n10:00|지난주 회고|원\n10:15|필기 지연 측정 결과|치엔\n10:35|출시 일정과 남은 항목|페이\n10:50|다음 주 분담|전원",
            "th" to "เวลา|หัวข้อ|ผู้รับผิดชอบ\n10:00|ทบทวนสัปดาห์ที่แล้ว|เหวิน\n10:15|ผลวัดความหน่วงลายมือ|เชียน\n10:35|กำหนดการปล่อยและสิ่งที่ยังขาด|เผย\n10:50|แบ่งงานสัปดาห์หน้า|ทุกคน"
        ),
        "sample_meeting_chart_categories" to mapOf(
            "zh-Hant" to "第35週|第36週|第37週|第38週",
            "en" to "W35|W36|W37|W38",
            "zh-Hans" to "第35周|第36周|第37周|第38周",
            "ja" to "第35週|第36週|第37週|第38週",
            "ko" to "35주|36주|37주|38주",
            "th" to "สัปดาห์ 35|สัปดาห์ 36|สัปดาห์ 37|สัปดาห์ 38"
        )
    )

    private fun part21(): Map<String, Map<String, String>> = mapOf(
        "sample_meeting_chart_series" to mapOf(
            "zh-Hant" to "已完成",
            "en" to "Completed",
            "zh-Hans" to "已完成",
            "ja" to "完了",
            "ko" to "완료",
            "th" to "เสร็จแล้ว"
        ),
        "sample_meeting_chart_title" to mapOf(
            "zh-Hant" to "每週完成的工作項目",
            "en" to "Items completed per week",
            "zh-Hans" to "每周完成的工作项目",
            "ja" to "週ごとの完了項目",
            "ko" to "주별 완료 항목",
            "th" to "งานที่เสร็จต่อสัปดาห์"
        ),
        "sample_meeting_flow_decide" to mapOf(
            "zh-Hant" to "能重現？",
            "en" to "Reproducible?",
            "zh-Hans" to "能重现？",
            "ja" to "再現する？",
            "ko" to "재현되나?",
            "th" to "ทำซ้ำได้ไหม"
        ),
        "sample_meeting_flow_end" to mapOf(
            "zh-Hant" to "排進下一版",
            "en" to "Schedule for next release",
            "zh-Hans" to "排进下一版",
            "ja" to "次版に計上",
            "ko" to "다음 버전에 배정",
            "th" to "จัดลงรุ่นถัดไป"
        ),
        "sample_meeting_flow_start" to mapOf(
            "zh-Hant" to "收到回報",
            "en" to "Report comes in",
            "zh-Hans" to "收到回报",
            "ja" to "報告を受領",
            "ko" to "보고 접수",
            "th" to "ได้รับรายงาน"
        ),
        "sample_meeting_p1_body" to mapOf(
            "zh-Hant" to "重點\n• 延遲在 iPad Pro 上量到 11ms，符合門檻；Android 中階機還沒量。\n• 上架卡在正式簽章金鑰，不是程式問題。\n• 下週把錄音插入頁面的操作寫進手冊。\n\n（這一頁是範例。整頁內容都改得動，也可以整本刪掉。）",
            "en" to "Key points\n• 11 ms measured on iPad Pro — within threshold. Mid-range Android not measured yet.\n• Release is blocked on the production signing key, not on code.\n• Next week: document how to insert a recording into a page.\n\n(This page is a sample. Everything on it is editable, and the whole notebook can be deleted.)",
            "zh-Hans" to "重点\n• 延迟在 iPad Pro 上量到 11ms，符合门槛；Android 中阶机还没量。\n• 上架卡在正式签章金钥，不是程式问题。\n• 下周把录音插入页面的操作写进手册。\n\n（这一页是范例。整页内容都改得动，也可以整本删掉。）",
            "ja" to "要点\n• iPad Pro で 11ms を計測、基準内。ミドルレンジ Android は未計測。\n• リリースは本番署名鍵待ちで、コードの問題ではない。\n• 来週：録音をページに挿入する手順をマニュアルに追記。\n\n（このページはサンプルです。すべて編集でき、ノートごと削除もできます。）",
            "ko" to "요점\n• iPad Pro에서 11ms 측정, 기준 내. 중급 안드로이드는 미측정.\n• 출시는 코드가 아니라 정식 서명 키 때문에 막혀 있음.\n• 다음 주: 녹음을 페이지에 삽입하는 절차를 설명서에 추가.\n\n(이 페이지는 예시입니다. 모두 수정할 수 있고 노트 전체를 삭제할 수도 있습니다.)",
            "th" to "ประเด็นสำคัญ\n• วัดได้ 11 ms บน iPad Pro อยู่ในเกณฑ์ ส่วน Android รุ่นกลางยังไม่ได้วัด\n• การปล่อยติดที่คีย์เซ็นชื่อจริง ไม่ใช่ปัญหาโค้ด\n• สัปดาห์หน้า: เขียนขั้นตอนแทรกเสียงลงในหน้าไว้ในคู่มือ\n\n(หน้านี้เป็นตัวอย่าง แก้ไขได้ทั้งหมด และลบทั้งเล่มได้)"
        ),
        "sample_meeting_p1_title" to mapOf(
            "zh-Hant" to "產品週會 — 第 38 週",
            "en" to "Product weekly — week 38",
            "zh-Hans" to "产品周会 — 第 38 周",
            "ja" to "プロダクト定例 — 第38週",
            "ko" to "제품 주간 회의 — 38주차",
            "th" to "ประชุมผลิตภัณฑ์ประจำสัปดาห์ — สัปดาห์ที่ 38"
        ),
        "sample_meeting_p2_body" to mapOf(
            "zh-Hant" to "這張圖是「數字製圖」：點選後可以重新編修，看到的是當初輸入的數字，不是一張只能刪掉重做的點陣圖。",
            "en" to "This chart keeps its data. Select it and edit — you get the numbers you typed, not a bitmap you can only delete and redo.",
            "zh-Hans" to "这张图是「数字制图」：点选后可以重新编修，看到的是当初输入的数字，不是一张只能删掉重做的点阵图。",
            "ja" to "このグラフはデータを保持しています。選んで編集すれば、入力した数値がそのまま出てきます。消して作り直すしかないビットマップではありません。",
            "ko" to "이 차트는 데이터를 그대로 갖고 있습니다. 선택해 편집하면 입력한 숫자가 그대로 나옵니다. 지우고 다시 만들어야 하는 비트맵이 아닙니다.",
            "th" to "แผนภูมินี้เก็บข้อมูลไว้ เลือกแล้วแก้ไขได้ คุณจะเห็นตัวเลขที่พิมพ์ไว้ ไม่ใช่ภาพบิตแมปที่ต้องลบแล้วทำใหม่"
        ),
        "sample_meeting_p2_title" to mapOf(
            "zh-Hant" to "四週進度對照",
            "en" to "Four-week progress",
            "zh-Hans" to "四周进度对照",
            "ja" to "4週間の進捗",
            "ko" to "4주간 진행 상황",
            "th" to "ความคืบหน้า 4 สัปดาห์"
        ),
        "sample_meeting_p3_body" to mapOf(
            "zh-Hant" to "下面的流程圖是三個獨立的形狀加兩條連接線。拖動任一個，連接線會跟著重算 —— 它們是真的物件，不是一張圖。",
            "en" to "The flowchart below is three separate shapes and two connectors. Drag any of them and the connectors recompute — they are real objects, not a picture.",
            "zh-Hans" to "下面的流程图是三个独立的形状加两条连接线。拖动任一个，连接线会跟着重算 —— 它们是真的对象，不是一张图。",
            "ja" to "下のフローチャートは3つの独立した図形と2本の接続線です。どれかを動かすと接続線が計算し直されます。画像ではなく本物のオブジェクトです。",
            "ko" to "아래 순서도는 별개의 도형 세 개와 연결선 두 개입니다. 아무거나 끌면 연결선이 다시 계산됩니다. 그림이 아니라 진짜 객체입니다.",
            "th" to "ผังงานด้านล่างคือรูปทรงสามชิ้นกับเส้นเชื่อมสองเส้น ลากชิ้นใดก็ได้แล้วเส้นเชื่อมจะคำนวณใหม่ เพราะเป็นวัตถุจริง ไม่ใช่รูปภาพ"
        ),
        "sample_meeting_p3_title" to mapOf(
            "zh-Hant" to "決議與後續",
            "en" to "Decisions and follow-ups",
            "zh-Hans" to "决议与后续",
            "ja" to "決定事項とフォロー",
            "ko" to "결정 사항과 후속 조치",
            "th" to "ข้อสรุปและงานต่อเนื่อง"
        ),
        "sample_meeting_todo_table" to mapOf(
            "zh-Hant" to "待辦|負責|期限\n量測 Android 中階機延遲|建豪|9/22\n補手冊「插入錄音」章節|文萱|9/20\n申請正式簽章金鑰|佩宜|9/19",
            "en" to "To-do|Owner|Due\nMeasure latency on mid-range Android|Chien|Sep 22\nWrite the “insert recording” chapter|Wen|Sep 20\nRequest the production signing key|Pei|Sep 19",
            "zh-Hans" to "待办|负责|期限\n量测 Android 中阶机延迟|建豪|9/22\n补手册「插入录音」章节|文萱|9/20\n申请正式签章金钥|佩宜|9/19",
            "ja" to "タスク|担当|期限\nミドルレンジ Android の遅延計測|チェン|9/22\nマニュアルに「録音の挿入」章を追加|ウェン|9/20\n本番署名鍵の申請|ペイ|9/19",
            "ko" to "할 일|담당|기한\n중급 안드로이드 지연 측정|치엔|9/22\n설명서 “녹음 삽입” 장 추가|원|9/20\n정식 서명 키 신청|페이|9/19",
            "th" to "สิ่งที่ต้องทำ|ผู้รับผิดชอบ|กำหนด\nวัดความหน่วงบน Android รุ่นกลาง|เชียน|22 ก.ย.\nเขียนบท “แทรกเสียงบันทึก” ในคู่มือ|เหวิน|20 ก.ย.\nขอคีย์เซ็นชื่อจริง|เผย|19 ก.ย."
        ),
        "sample_showcase_audio_title" to mapOf(
            "zh-Hant" to "語音導覽：Kairumo 設計理念與核心架構",
            "en" to "Audio Guide: Kairumo Design Philosophy and Core Architecture",
            "zh-Hans" to "语音导览：Kairumo 设计理念与核心架构",
            "ja" to "音声ガイド：Kairumoの設計思想とコアアーキテクチャ",
            "ko" to "음성 가이드: Kairumo 설계 철학과 핵심 아키텍처",
            "th" to "เสียงบรรยาย: ปรัชญาการออกแบบและสถาปัตยกรรมหลักของ Kairumo"
        ),
        "sample_showcase_calc_typed_desc" to mapOf(
            "zh-Hant" to "使用方式：\n1. 自由手繪：直接用手寫筆書寫微積分算式（包括積分號、分式、上標、三角函數）。\n2. 公式識別：套索選中後點擊【識別為公式】，瞬間轉換為標準化 LaTeX 排版。\n3. 分步解析：融合打字解析卡，手寫推導步驟與打字說明無縫並列呈現。",
            "en" to "How to use:\n1. Handwrite formulas using Apple Pencil (integral signs, limits, radicals).\n2. Lasso or tap Math OCR to convert into formatted LaTeX text.\n3. The built-in solver renders the step-by-step derivation card below.",
            "zh-Hans" to "使用方式：\n1. 自由手绘：直接用手写笔书写微积分算式（包括积分号、分式、上标、三角函数）。\n2. 公式识别：套索选中后点击【识别为公式】，瞬间转换为标准化 LaTeX 排版。\n3. 分步解析：融合打字解析卡，手写推导步骤与打字说明无缝并列呈现。",
            "ja" to "使用方法：\n1. Apple Pencilで数式（積分記号、極限、根号など）を手描きします。\n2. なわぞうツールまたは数式OCRで整形されたLaTeXテキストへ瞬時に変換。\n3. 内蔵ソルバーが連携し、ステップごとの解説カードを自動生成します。",
            "ko" to "사용 방법:\n1. Apple Pencil로 적분 기호, 극한, 제곱근 등의 수식을 자연스럽게 손글씨로 작성합니다.\n2. 올가미 도구 또는 수식 OCR을 탭하여 단정한 LaTeX 텍스트로 즉시 변환합니다.\n3. 내장 솔버가 수식을 해석하여 단계별 유도 과정 카드를 캔버스에 생성합니다.",
            "th" to "วิธีใช้งาน:\n1. เขียนสูตรคณิตศาสตร์ด้วย Apple Pencil (อินทิกรัล, ลิมิต, สแควร์รูท)\n2. ใช้บ่วงบาศหรือแตะ Math OCR เพื่อแปลงเป็นข้อความ LaTeX ที่สวยงาม\n3. กลไกในตัวจะประมวลผลและสร้างการ์ดวิธีทำเป็นขั้นตอนลงบนผืนผ้าใบ"
        ),
        "sample_showcase_calc_typed_title" to mapOf(
            "zh-Hant" to "★ 數學引擎：手繪筆跡與 LaTeX 打字方程的深度融合解析",
            "en" to "★ Math Engine: Hybrid Handwriting & LaTeX Equation Solver",
            "zh-Hans" to "★ 数学引擎：手绘笔迹与 LaTeX 打字方程的深度融合解析",
            "ja" to "★ 数式エンジン：手描きとLaTeXの融合によるステップ解析",
            "ko" to "★ 수학 엔진: 손글씨 및 LaTeX 수식 하이브리드 단계별 풀이",
            "th" to "★ กลไกคณิตศาสตร์: ผสานลายมือและ LaTeX พร้อมแสดงวิธีทำเป็นขั้นตอน"
        ),
        "sample_showcase_card_audio_body" to mapOf(
            "zh-Hant" to "🎙️ 語音導覽卡片\n長度: 03:04\n筆跡與聲音精準時間軸對齊同步回放",
            "en" to "🎙️ Audio Guide Card\nDuration: 03:04\nSynchronized ink and voice timeline playback",
            "zh-Hans" to "🎙️ 语音导览卡片\n长度: 03:04\n笔迹与声音精准时间轴对齐同步回放",
            "ja" to "🎙️ 音声ガイドカード\n長さ: 03:04\n筆跡と音声の精密タイムライン同期再生",
            "ko" to "🎙️ 음성 가이드 카드\n길이: 03:04\n필적과 오디오의 정밀 타임라인 동기화 재생",
            "th" to "🎙️ การ์ดบันทึกเสียงบรรยาย\nความยาว: 03:04\nเล่นลายมือและเสียงซิงค์ตามไทม์ไลน์อย่างแม่นยำ"
        ),
        "sample_showcase_card_link_body" to mapOf(
            "zh-Hant" to "🔗 GitHub 開源庫\nKairumo\n100% 開源無拘束，Rust + UniFFI 高性能內核",
            "en" to "🔗 GitHub Repository\nKairumo\n100% open source & unconstrained, Rust + UniFFI high-perf core",
            "zh-Hans" to "🔗 GitHub 开源库\nKairumo\n100% 开源无拘束，Rust + UniFFI 高性能内核",
            "ja" to "🔗 GitHub オープンソース\nKairumo\n100%オープンソース、Rust + UniFFI 高性能コア",
            "ko" to "🔗 GitHub 오픈소스 저장소\nKairumo\n100% 오픈소스, Rust + UniFFI 고성능 코어 탑재",
            "th" to "🔗 คลัง GitHub โอเพนซอร์ส\nKairumo\nโอเพนซอร์ส 100% ขับเคลื่อนด้วย Rust + UniFFI ประสิทธิภาพสูง"
        ),
        "sample_showcase_card_model_body" to mapOf(
            "zh-Hant" to "🧊 3D 空間幾何體\n正十二面體模型\n支援手指 360° 空間自由旋轉視角檢視",
            "en" to "🧊 3D Geometry Model\nDodecahedron shape\nSupports 360° touch rotation in 3D space",
            "zh-Hans" to "🧊 3D 空间几何体\n正十二面体模型\n支持手指 360° 空间自由旋转视角检视",
            "ja" to "🧊 3D 空間幾何モデル\n正十二面体モデル\n指先で360°自由回転ビューに対応",
            "ko" to "🧊 3D 공간 기하 모델\n정십이면체 모델\n360° 제스처 회전 공간 뷰 완벽 지원",
            "th" to "🧊 โมเดลเรขาคณิตสามมิติ\nรูปทรงสิบสองหน้า\nรองรับการหมุนดูมุมมอง 360° ด้วยนิ้วมือ"
        ),
        "sample_showcase_chart_series_top3" to mapOf(
            "zh-Hant" to "商業付費競品平均",
            "en" to "Commercial Paid Competitors Average",
            "zh-Hans" to "商业付费竞品平均",
            "ja" to "有料商用アプリ平均",
            "ko" to "상용 유료 경쟁 제품 평균",
            "th" to "ค่าเฉลี่ยของคู่แข่งเชิงพาณิชย์แบบชำระเงิน"
        ),
        "sample_showcase_chart_spec_title" to mapOf(
            "zh-Hant" to "2026 手寫繪圖效能與自由度指標對比 (滿分 100)",
            "en" to "2026 Handwriting Performance & Flexibility Score (Max 100)",
            "zh-Hans" to "2026 手写绘图效能与自由度指标对比 (满分 100)",
            "ja" to "2026年 手書き・描画性能と自由度指標比較 (100点満点)",
            "ko" to "2026 필기 드로잉 성능 및 자유도 지표 비교 (100점 만점)",
            "th" to "การเปรียบเทียบประสิทธิภาพการวาดเขียนและความยืดหยุ่นปี 2026 (เต็ม 100)"
        ),
        "sample_showcase_chart_typed_desc" to mapOf(
            "zh-Hant" to "功能用法：\n• 數字製圖：點擊工具欄【＋】->【數字製圖】，輸入分類與數值即可生成向量圖表，雙擊隨時重新修改數據與配色。\n• 討論圖釘：在圖表特定柱狀或推導難點處釘入圖釘，建立上下文關聯的討論串，手繪箭頭配合圖釘批注，團隊協作一目了然。",
            "en" to "Feature Guide:\n• Digital Charting: Insert vector charts via the toolbar (+) -> Chart. Double-tap to customize series data, colors, and layout anytime.\n• Discussion Pins: Drop a pin on any chart bar or formula step to leave contextual review comments and collaborate with peers.",
            "zh-Hans" to "功能用法：\n• 数字制图：点击工具栏【＋】->【数字制图】，输入分类与数值即可生成矢量图表，双击随时重新修改数据与配色。\n• 讨论图钉：在图表特定柱状或推导难点处钉入图钉，建立上下文关联的讨论串，手绘箭头配合图钉批注，团队协作一目了然。",
            "ja" to "機能の利用方法：\n• デジタル作図：ツールバーの (+) -> [グラフ] から挿入。ダブルタップで系列データや色、凡例をいつでも再編集可能。\n• 議論ピン：グラフの特定要素や計算ステップ上にピンを配置し、文脈に沿ったコメントを残して共同推敲を行えます。",
            "ko" to "기능 활용 안내:\n• 디지털 차트: 툴바의 (+) -> [차트]에서 벡터 차트를 삽입합니다. 언제든 더블 탭하여 데이터, 색상, 범례를 재편집할 수 있습니다.\n• 토론 핀: 차트의 특정 막대나 수식 단계 위에 핀을 꽂아 맥락에 맞는 피드백을 기록하고 협업할 수 있습니다.",
            "th" to "คำแนะนำการใช้งาน:\n• แผนภูมิข้อมูล: แทรกแผนภูมิเวกเตอร์ผ่านแถบเครื่องมือ (+) -> แผนภูมิ แตะสองครั้งเพื่อปรับแต่งชุดข้อมูล สี และรูปแบบได้ตลอดเวลา\n• หมุดอภิปราย: ปักหมุดลงบนแท่งกราฟหรือขั้นตอนการคำนวณ เพื่อแสดงความคิดเห็นและทำงานร่วมกันได้อย่างแม่นยำ"
        ),
        "sample_showcase_chart_typed_title" to mapOf(
            "zh-Hant" to "★ 數字製圖（Chart Studio）與討論圖釘（Comment Pins）用法介紹",
            "en" to "★ Digital Charting & Spatial Discussion Pins",
            "zh-Hans" to "★ 数字制图（Chart Studio）与讨论图钉（Comment Pins）用法介绍",
            "ja" to "★ デジタル作図 ＆ 空間座標ピン議論機能",
            "ko" to "★ 디지털 차트 제작 & 공간 토론 핀 기능",
            "th" to "★ การสร้างแผนภูมิข้อมูลตัวเลข & หมุดอภิปรายเชิงพื้นที่"
        ),
        "sample_showcase_comparison_table" to mapOf(
            "zh-Hant" to "核心比較維度|Kairumo (Padnote)|GoodNotes 6|Notability|Microsoft OneNote\n向量手繪手寫|超低延遲，真實鉛筆/鋼筆/毛筆動態壓感提按|向量墨水，缺乏真實毛筆書法起伏|平滑墨水，筆刷可定制參數較少|跨平台墨跡，筆畫偶有卡頓延遲\n打字與原生表格|原生 Markdown 高級樣式表格，自由拉伸對齊|僅基礎文字框，表格調整能力有限|文字輸入平順，表格樣式較簡陋|自由浮動文字塊，排版易散亂\n微積分方程融合|手繪筆跡 + OCR LaTeX 識別 + 步進推導融合|手寫公式轉換（需訂閱高級版）|基礎公式轉換插件（識別率普通）|內建公式編輯器，更偏向桌面鍵入\n數字製圖圖表|內建可隨時重新編輯向量圖表（柱狀/折線/餅圖）|依賴外部第三方截圖導入|僅支援靜態貼圖，無法再改數據|可關聯 Excel，但行動端體驗沈重\n圖釘與協作討論|空間定位圖釘（NoteCommentPin）與留言蓋樓|連結分享批註，僅支援簡易標註|錄音軌跡對齊，無精準空間圖釘|多人協同畫布，缺乏精細錨點圖釘\n收費模式與自由度|100% 完全開源、無廣告、終身永久免費|訂閱制 / 買斷功能限制多|強制年費訂閱制|基本免費但深度綁定 365 訂閱",
            "en" to "Core Dimension|Kairumo (Padnote)|GoodNotes 6|Notability|Microsoft OneNote\nVector Handwriting|Ultra-low latency, Pencil/Pen/Brush pressure|Vector stroke, lack of true calligraphic lift|Smooth ink, limited brush customization|Cross-platform ink, noticeable latency\nTyping & Tables|Native resizable Markdown & styled data tables|Basic text boxes, tables lack fluid styling|Basic text, simple table formatting|Freeform text frames, flexible canvas\nEquations & Math|Hybrid Handwriting + OCR LaTeX + Step solver|Math handwriting conversion (paid tier)|Basic math conversion addon|Built-in Equation editor, desktop-focused\nData Charting|Editable built-in charts (Bar/Line/Pie/Scatter)|Requires third-party image imports|Image-only diagrams, static|Excel chart link, slow mobile interaction\nPins & Collaboration|Embedded Comment Pins & discussion threads|Shared links with basic comments|Audio note sync, no spatial pins|Multi-user co-authoring, complex layout\nPricing & Freedom|100% Open Source, Ad-Free, Lifetime Free|Subscription / In-App purchase tier|Yearly subscription required|Freemium with Office 365 upsell",
            "zh-Hans" to "核心比较维度|Kairumo (Padnote)|GoodNotes 6|Notability|Microsoft OneNote\n向量手绘手写|超低延迟，真实铅笔/钢笔/毛笔动态压感提按|矢量墨水，缺乏真实毛笔书法起伏|平滑墨水，笔刷可定制参数较少|跨平台墨迹，笔画偶有卡顿延迟\n打字与原生表格|原生 Markdown 高级样式表格，自由拉伸对齐|仅基础文本框，表格调整能力有限|文本输入平顺，表格样式较简陋|自由浮动文本块，排版易散乱\n微积分方程融合|手绘笔迹 + OCR LaTeX 识别 + 步进推导融合|手写公式转换（需订阅高级版）|基础公式转换插件（识别率普通）|内置公式编辑器，更偏向桌面键入\n数字制图图表|内置可随时重新编辑矢量图表（柱状/折线/饼图）|依赖外部第三方截图导入|仅支持静态贴图，无法再改数据|可关联 Excel，但移动端体验沉重\n图钉与协作讨论|空间定位图钉（NoteCommentPin）与留言盖楼|链接分享批注，仅支持简易标注|录音轨迹对齐，无精准空间图钉|多人协同画布，缺乏精细锚点图钉\n收费模式与自由度|100% 完全开源、无广告、终身永久免费|订阅制 / 买断功能限制多|强制年费订阅制|基本免费但深度绑定 365 订阅",
            "ja" to "評価軸|Kairumo (Padnote)|GoodNotes 6|Notability|Microsoft OneNote\nベクター手描き|超低遅延、鉛筆・万年筆・毛筆の筆圧再現|ベクター描画対応、毛筆の緩急表現は限定的|滑らかな筆跡、ブラシカスタマイズは少なめ|クロスプラットフォーム対応、遅延やや高め\nタイピングと表|Markdown対応・スタイル自在なネイティブ表|基本テキスト枠、表の柔軟性は限定的|テキスト中心、シンプルな表作成|自由配置テキスト枠、キャンバス無限\n数式と計算|手描き＋OCR LaTeX＋ステップ解説の融合|手描き数式変換（上位プラン対応）|手描き数式変換アドオン|数式エディタ搭載、デスクトップ重視\nデータ作図|編集可能な内蔵グラフ（棒・折線・円・散布）|外部画像インポート頼り|静止画のみ、動的編集不可|Excel連携対応、モバイルでの操作は重い\nピンと協働議論|座標連動の議論ピン・スレッド内蔵|共有リンクと基本コメント|音声録音同期、空間ピンなし|共同編集対応、レイアウトが崩れやすい\n料金とオープン性|完全オープンソース・広告なし・完全無料|サブスクリプション／買い切り課金|年額サブスクリプション制|基本無料だがOffice 365推奨",
            "ko" to "핵심 평가축|Kairumo (Padnote)|GoodNotes 6|Notability|Microsoft OneNote\n벡터 손글씨|초저지연, 연필·만년필·붓 완벽 필압|벡터 필기 지원, 붓글씨 동적 표현 제한적|부드러운 필기감, 브러시 커스텀 한계|크로스플랫폼 지원, 지연시간 다소 체감\n타이핑 및 표|Markdown 및 서식 지원 네이티브 데이터 표|기본 텍스트 상자, 표 편집 유연성 부족|기본 텍스트 위주, 단순 표 생성|자유 배치 텍스트 프레임, 무한 캔버스\n수식 및 수학|손글씨 + LaTeX 수식 + 단계별 풀이 융합|손글씨 수식 변환 (유료 등급)|수식 변환 애드온 지원|수식 편집기 지원, 데스크톱 중심\n데이터 차트|재편집 가능한 내장 차트(막대/선/파이/분산)|외부 이미지 삽입에 의존|정적 이미지만 지원, 편집 불가|Excel 차트 연동, 모바일 편집 무거움\n핀 토론 협업|좌표 기반 토론 핀 및 댓글 스레드|공유 링크 및 기본 댓글 기능|음성 녹음 싱크, 공간 핀 미지원|다중 사용자 협업, 레이아웃 깨짐 잦음\n가격 및 개방성|100% 오픈소스, 광고 없음, 완전 무료|구독형 및 인앱 결제 유도|연간 정기 구독 필수|무료 제공이나 Office 365 유도",
            "th" to "มิติเปรียบเทียบ|Kairumo (Padnote)|GoodNotes 6|Notability|Microsoft OneNote\nลายมือเวกเตอร์|หน่วงต่ำมาก, แรงกดดินสอ/ปากกา/พู่กันสมจริง|ลายเส้นเวกเตอร์, ขาดน้ำหนักพู่กันแท้|ลายเส้นลื่นไหล, ปรับแต่งพู่กันจำกัด|รองรับหลายระบบ, ความหน่วงสัมผัสได้\nการพิมพ์และตาราง|ตารางข้อมูลพร้อมสไตล์ จัดขนาดได้สมบูรณ์|กล่องข้อความพื้นฐาน, ตารางปรับแต่งจำกัด|เน้นพิมพ์ข้อความ, รูปแบบตารางเรียบง่าย|กรอบข้อความอิสระ, ผืนผ้าใบกว้าง\nสมการคณิตศาสตร์|ผสานลายมือ + OCR LaTeX + เฉลยเป็นขั้นตอน|แปลงลายมือคณิตศาสตร์ (ต้องจ่ายเพิ่ม)|ส่วนเสริมแปลงคณิตศาสตร์|มีตัวแก้ไขสมการ, เน้นใช้งานบนเดสก์ท็อป\nแผนภูมิข้อมูล|กราฟในตัวแก้ไขได้ (แท่ง/เส้น/วงกลม/กระจาย)|ต้องนำเข้ารูปภาพจากภายนอก|ภาพนิ่งเท่านั้น ไม่สามารถแก้ไขข้อมูลได้|เชื่อมโยง Excel, ทำงานบนมือถือช้า\nหมุดอภิปราย|หมุดความคิดเห็นแบบฝังพิกัดและเธรดสนทนา|แชร์ลิงก์พร้อมความคิดเห็นพื้นฐาน|ซิงค์เสียงบันทึก, ไม่มีหมุดเชิงพื้นที่|ทำงานร่วมกันหลายคน, เลย์เอาต์มักเลื่อน\nราคาและความอิสระ|โอเพนซอร์ส 100%, ไม่มีโฆษณา, ฟรีตลอดชีพ|สมัครสมาชิก / จ่ายครั้งเดียวแบบมีเงื่อนไข|ระบบสมัครสมาชิกรายปี|ใช้งานฟรีเบื้องต้น เน้นขาย Office 365"
        ),
        "sample_showcase_flow_aligned" to mapOf(
            "zh-Hant" to "<- [ 智慧拓撲對齊 ]",
            "en" to "<- [ Smart Topology ]",
            "zh-Hans" to "<- [ 智能拓扑对齐 ]",
            "ja" to "<- [ スマートトポロジー ]",
            "ko" to "<- [ 스마트 토폴로지 정렬 ]",
            "th" to "<- [ การจัดเรียงโครงสร้างอัจฉริยะ ]"
        ),
        "sample_showcase_handwriting_note" to mapOf(
            "zh-Hant" to "★ 真實手繪筆跡呈現：\n下方列出的段落文字與裝飾皆以真實向量筆劃繪製（鉛筆質感顆粒、鋼筆動態壓感、毛筆提按書法起伏）。",
            "en" to "★ Authentic Ink Strokes:\nThe lists and calligraphic flourishes below are rendered with authentic vector strokes (Pencil texture, Fountain Pen dynamic pressure, Brush calligraphic variation).",
            "zh-Hans" to "★ 真实手绘笔迹呈现：\n下方列出的段落文字与装饰皆以真实矢量笔画绘制（铅笔质感颗粒、钢笔动态压感、毛笔提按书法起伏）。",
            "ja" to "★ 本物の手描き筆跡：\n以下のリストと装飾文字は、本物のベクター筆跡（鉛筆の質感、万年筆の筆圧応答、毛筆の緩急）で描かれています。",
            "ko" to "★ 진정한 벡터 손글씨:\n아래의 목록 및 캘리그래피는 연필의 질감, 만년필의 필압, 붓의 강약 조절이 적용된 실제 벡터 획으로 생성되었습니다.",
            "th" to "★ ลายมือหมึกเวกเตอร์แท้:\nรายการและลายเส้นด้านล่างถูกวาดด้วยเส้นเวกเตอร์จริง (ดินสอ, ปากกาหมึกซึมปรับแรงกด, พู่กันตัวเขียน)"
        ),
        "sample_showcase_math_ink_title" to mapOf(
            "zh-Hant" to "【 手繪積分真跡 】",
            "en" to "[ Hand-drawn Integral ]",
            "zh-Hans" to "【 手绘积分真迹 】",
            "ja" to "【 手描き積分筆跡 】",
            "ko" to "【 손글씨 적분 필적 】",
            "th" to "【 ลายมือการอินทิเกรตจริง 】"
        ),
        "sample_showcase_model3d_title" to mapOf(
            "zh-Hant" to "3D 正十二面體空間幾何模型",
            "en" to "3D Regular Dodecahedron Spatial Geometry Model",
            "zh-Hans" to "3D 正十二面体空间几何模型",
            "ja" to "3D 正十二面体 空間幾何モデル",
            "ko" to "3D 정십이면체 공간 기하학 모델",
            "th" to "แบบจำลองเรขาคณิตสามมิติรูปทรงสิบสองหน้าปกติ"
        ),
        "sample_showcase_p1_mission_body" to mapOf(
            "zh-Hant" to "市面上絕大多數商業筆記應用將思考鎖在昂貴的訂閱制、私有雲儲存和僵化的排版模式中。Kairumo 重新發明數位紙張：超低延遲的數學級向量筆跡、專業桌面級打字排版、動態可編修圖表、多維空間討論圖釘，以及 100% 開放透明的隱私主權。",
            "en" to "Mainstream digital note apps lock creative thoughts into rigid formats, heavy subscriptions, and proprietary cloud silos. Kairumo reimagines digital paper from the ground up: zero latency vector inking, native desktop-grade typography, dynamic interactive charts, spatial discussion pins, and true open-format privacy.",
            "zh-Hans" to "市面上绝大多数商业笔记应用将思考锁在昂贵的订阅制、私有云存储和僵化的排版模式中。Kairumo 重新发明数字纸张：超低延迟的数学级矢量笔迹、专业桌面级打字排版、动态可编修图表、多维空间讨论图钉，以及 100% 开放透明的隐私主权。",
            "ja" to "市販のノートアプリは定期購読や独自クラウドによる囲い込み、固定された枠組みで自由な思考を制限してきました。Kairumoはデジタルペーパーを一から再定義します。超低遅延ベクター筆記、高度なタイピング組版、動的グラフ、空間議論ピン、そして完全オープンなデータ主権を統合しました。",
            "ko" to "기존 상용 필기 앱들은 강제 구독료, 폐쇄적인 클라우드 종속, 경직된 서식으로 자유로운 발상을 가두어 왔습니다. Kairumo는 디지털 노트를 근본부터 다시 설계했습니다. 초저지연 벡터 잉크, 데스크톱급 타이핑 조판, 동적 인터랙티브 차트, 공간 토론 핀, 완전한 오픈 포맷 데이터 주권을 제공합니다.",
            "th" to "แอปจดบันทึกทั่วไปมักผูกมัดผู้ใช้ด้วยค่าบริการรายเดือนและระบบคลาวด์แบบปิด Kairumo กำหนดนิยามใหม่ของกระดาษดิจิทัล: หมึกเวกเตอร์ความหน่วงต่ำเป็นศูนย์, การจัดวางข้อความระดับมืออาชีพ, แผนภูมิข้อมูลแบบโต้ตอบได้, หมุดอภิปรายเชิงพื้นที่ และความเป็นส่วนตัวอย่างแท้จริง"
        ),
        "sample_showcase_p1_mission_title" to mapOf(
            "zh-Hant" to "為什麼打造 Kairumo：打破傳統筆記桎梏",
            "en" to "Why Kairumo was Created",
            "zh-Hans" to "为什么打造 Kairumo：打破传统笔记桎梏",
            "ja" to "Kairumo が誕生した理由と設計思想",
            "ko" to "Kairumo의 탄생 배경과 설계 철학",
            "th" to "ทำไม Kairumo จึงถูกสร้างขึ้น"
        ),
        "sample_showcase_p1_pillar1_body" to mapOf(
            "zh-Hant" to "零廣告、零訂閱、零廠商鎖定。所有筆記以標準 JSON 與 SQLite 開放包儲存於本機，數據永遠屬於你。",
            "en" to "No ads, no subscriptions, no vendor lock-in. Your notebook data is stored locally in pure open JSON packages with SQLite indexing.",
            "zh-Hans" to "零广告、零订阅、零厂商锁定。所有笔记以标准 JSON 与 SQLite 开放包存储于本地，数据永远属于你。",
            "ja" to "広告なし、課金なし、ベンダーロックインなし。ノートデータは純粋なオープンJSONとSQLiteで端末内に安全に保存されます。",
            "ko" to "광고 없음, 구독료 없음, 종속 없음. 모든 데이터는 순수 오픈 JSON 패키지와 SQLite로 로컬에 안전하게 보관됩니다.",
            "th" to "ไม่มีโฆษณา ไม่มีการเก็บค่าบริการ ข้อมูลจัดเก็บในเครื่องด้วยรูปแบบเปิด JSON และ SQLite อย่างปลอดภัย"
        ),
        "sample_showcase_p1_pillar1_title" to mapOf(
            "zh-Hant" to "1. 完全開源・終身免費",
            "en" to "1. 100% Open & Free",
            "zh-Hans" to "1. 完全开源・终身免费",
            "ja" to "1. 完全オープン・永年無料",
            "ko" to "1. 100% 오픈소스 & 무료",
            "th" to "1. โอเพนซอร์ส 100% ฟรีตลอดชีพ"
        ),
        "sample_showcase_p1_pillar2_body" to mapOf(
            "zh-Hant" to "16 種物理級手繪筆刷、桌面級豐富文字樣式、動態公式 OCR 識別及可連接流程圖在同一畫卷自由共存。",
            "en" to "Seamless coexistence of 16 natural handwriting brush types, Word-grade rich text blocks, dynamic math OCR, and interactive shapes.",
            "zh-Hans" to "16 种物理级手绘笔刷、桌面级丰富文字样式、动态公式 OCR 识别及可连接流程图在同一画卷自由共存。",
            "ja" to "16種類のアナログ質感ブラシ、Word級のリッチテキスト枠、数式OCRソルバー、自由な幾何図形が同一キャンバスで共存。",
            "ko" to "16가지의 섬세한 자연 브러시, 고품격 리치 텍스트 블록, 동적 수학 OCR 및 인터랙티브 도형이 한 화면에 공존합니다.",
            "th" to "ผสานพู่กันธรรมชาติ 16 แบบ, บล็อกข้อความจัดรูปแบบระดับสูง, OCR แปลงสูตรคณิต และรูปทรงไดนามิกไว้ในหน้าเดียว"
        ),
        "sample_showcase_p1_pillar2_title" to mapOf(
            "zh-Hant" to "2. 手繪與排版無縫融合",
            "en" to "2. High-Fidelity Hybrid",
            "zh-Hans" to "2. 手绘与排版无缝融合",
            "ja" to "2. ハイブリッド描画統合",
            "ko" to "2. 하이브리드 엔진 통합",
            "th" to "2. ไฮบริดลายมือและข้อความสมบูรณ์แบบ"
        ),
        "sample_showcase_p1_pillar3_body" to mapOf(
            "zh-Hant" to "內建原生向量圖表工坊。拒絕靜態截圖拼貼，隨時輕點即可重新輸入系列數值、修改配色與切換圖表類型。",
            "en" to "Built-in vector charting engine. Never paste static screenshots again—double tap to change numbers, colors, and series instantly.",
            "zh-Hans" to "内置原生矢量图表工坊。拒绝静态截图拼贴，随时轻点即可重新输入系列数值、修改配色与切换图表类型。",
            "ja" to "ネイティブベクターグラフ機能を内蔵。静止画の貼り付けは不要、タップひとつで数値や配色をその場で即座に再編集。",
            "ko" to "네이티브 벡터 차트 엔진 내장. 멈춰있는 캡처 이미지는 이제 그만, 더블 탭으로 수치와 색상을 언제든 즉시 수정하세요.",
            "th" to "เอนจินแผนภูมิเวกเตอร์ในตัว ไม่ต้องแปะภาพหน้าจออีกต่อไป แตะสองครั้งเพื่อแก้ไขตัวเลข สี และชุดข้อมูลได้ทันที"
        ),
        "sample_showcase_p1_pillar3_title" to mapOf(
            "zh-Hant" to "3. 可隨時重新編輯的圖表",
            "en" to "3. Live Data Studio",
            "zh-Hans" to "3. 可随时重新编辑的图表",
            "ja" to "3. ライブデータ作図スタジオ",
            "ko" to "3. 라이브 데이터 스튜디오",
            "th" to "3. สตูดิโอแผนภูมิข้อมูลสด"
        ),
        "sample_showcase_p1_pillar4_body" to mapOf(
            "zh-Hant" to "將多人討論圖釘精確釘在公式難點、表格儲存格或圖表柱狀上，更能將麥克風錄音軌跡與手繪筆跡時間軸精確定位。",
            "en" to "Anchor multi-user review pins directly onto formulas, table cells, or chart bars. Synchronize live audio with pen stroke timelines.",
            "zh-Hans" to "将多人讨论图钉精确钉在公式难点、表格单元格或图表柱状上，更能将麦克风录音轨迹与手绘笔迹时间轴精确定位。",
            "ja" to "数式、表のセル、グラフのバー上に直接ピンを固定してレビュー。音声録音と手描きストロークの時間同期も完備。",
            "ko" to "수식, 표의 셀, 차트 막대 위에 직접 토론 핀을 꽂아 피드백을 기록하세요. 실시간 음성 녹음과 펜 궤적이 완벽 동기화됩니다.",
            "th" to "ปักหมุดข้อคิดเห็นลงบนสูตร ช่องตาราง หรือแท่งกราฟได้โดยตรง พร้อมซิงค์เสียงบันทึกเข้ากับไทม์ไลน์ลายเส้นปากกา"
        ),
        "sample_showcase_p1_pillar4_title" to mapOf(
            "zh-Hant" to "4. 空間圖釘與時間軸協同",
            "en" to "4. Spatial Collaboration",
            "zh-Hans" to "4. 空间图钉与时间轴协同",
            "ja" to "4. 空間座標ピン協働",
            "ko" to "4. 공간 좌표 핀 협업",
            "th" to "4. การทำงานร่วมกันด้วยหมุดเชิงพื้นที่"
        ),
        "sample_showcase_p1_pillars_title" to mapOf(
            "zh-Hant" to "Kairumo 四大核心支柱與技術優勢",
            "en" to "Four Foundational Pillars of Kairumo",
            "zh-Hans" to "Kairumo 四大核心支柱与技术优势",
            "ja" to "Kairumoを支える4大コア基盤",
            "ko" to "Kairumo를 정의하는 4대 핵심 가치",
            "th" to "4 เสาหลักพื้นฐานของ Kairumo"
        ),
        "sample_showcase_p1_subtitle" to mapOf(
            "zh-Hant" to "第一章：應用定位、核心使命與市面主流筆記軟體全景深度評測",
            "en" to "Chapter 1: Purpose & Comprehensive Market Benchmark",
            "zh-Hans" to "第一章：应用定位、核心使命与市面主流笔记软件全景深度评测",
            "ja" to "第1章：アプリケーションの使命と主要アプリ総合比較",
            "ko" to "제1장: 앱의 핵심 사명 및 주요 필기 앱 종합 벤치마크",
            "th" to "บทที่ 1: วัตถุประสงค์และการเปรียบเทียบเชิงลึกกับแอปชั้นนำ"
        ),
        "sample_showcase_p1_table_title" to mapOf(
            "zh-Hant" to "全景對比：Kairumo 與市面主流前三大商業筆記應用（GoodNotes、Notability、OneNote）",
            "en" to "Comprehensive Comparison: Kairumo vs. Industry Giants",
            "zh-Hans" to "全景对比：Kairumo 与市面主流前三大商业笔记应用（GoodNotes、Notability、OneNote）",
            "ja" to "市販主要3大ノートアプリ vs Kairumo 総合性能マトリクス",
            "ko" to "시판 주요 3대 필기 앱 vs Kairumo 종합 벤치마크 매트릭스",
            "th" to "ตารางเปรียบเทียบ Kairumo กับ 3 แอปจดบันทึกชั้นนำในอุตสาหกรรม"
        ),
        "sample_showcase_p1_title" to mapOf(
            "zh-Hant" to "Kairumo — 新一代高自由度向量手寫與思考中樞",
            "en" to "Kairumo — The Next-Gen Vector Note & Thinking Studio",
            "zh-Hans" to "Kairumo — 新一代高自由度矢量手写与思考中枢",
            "ja" to "Kairumo — 次世代ベクター思考・ノート統合スタジオ",
            "ko" to "Kairumo — 차세대 벡터 노트 & 싱킹 스튜디오",
            "th" to "Kairumo — สตูดิโอจดบันทึกและระบบคิดเวกเตอร์ยุคใหม่"
        ),
        "sample_showcase_p2_family_mark" to mapOf(
            "zh-Hant" to "第三家族：標注與版面輔助（記號筆、螢光筆、橡皮擦、套索、遮蔽膠帶、直尺）",
            "en" to "Family III: Marking & Geometry (Marker, Highlighter, Eraser, Lasso, Masking Tape, Ruler)",
            "zh-Hans" to "第三家族：标注与版面辅助（记号笔、荧光笔、橡皮擦、套索、遮蔽胶带、直尺）",
            "ja" to "第3グループ：標識・ユーティリティ（マーカー、蛍光ペン、消しゴム、投げ縄、マスキングテープ、定規）",
            "ko" to "제3계열: 마킹 및 유틸리티 (마커, 형광펜, 지우개, 올가미, 마스킹 테이프, 눈금자)",
            "th" to "กลุ่มที่ 3: การเน้นข้อความและเครื่องมือเสริม (มาร์กเกอร์, ไฮไลท์, ยางลบ, บ่วงบาศ, เทปกาว, ไม้บรรทัด)"
        ),
        "sample_showcase_p2_family_paint" to mapOf(
            "zh-Hant" to "第二家族：藝術彩繪族（炭筆、蠟筆、噴槍、油畫、水彩）",
            "en" to "Family II: Expressive Art Tools (Charcoal, Crayon, Airbrush, Oil Paint, Watercolor)",
            "zh-Hans" to "第二家族：艺术彩绘族（炭笔、蜡笔、喷枪、油画、水彩）",
            "ja" to "第2グループ：芸術表現ツール（木炭、クレヨン、エアブラシ、油絵、水彩）",
            "ko" to "제2계열: 예술 표현 도구 (목탄, 크레용, 에어브러시, 유채, 수채화)",
            "th" to "กลุ่มที่ 2: เครื่องมือระบายศิลปะ (ชาร์โคล, เครยอน, แอร์บรัช, สีน้ำมัน, สีน้ำ)"
        ),
        "sample_showcase_p2_family_write" to mapOf(
            "zh-Hant" to "第一家族：精密書寫族（鋼筆、針筆、原子筆、毛筆、書法筆、鉛筆）",
            "en" to "Family I: Precision Writing Tools (Pen, Fineliner, Ballpoint, Brush, Calligraphy, Pencil)",
            "zh-Hans" to "第一家族：精密书写族（钢笔、针笔、原子笔、毛笔、书法笔、铅笔）",
            "ja" to "第1グループ：精密筆記ツール（万年筆、ミリペン、ボールペン、筆、カリグラフィ、鉛筆）",
            "ko" to "제1계열: 정밀 필기 도구 (만년필, 세밀펜, 볼펜, 붓, 캘리그래피, 연필)",
            "th" to "กลุ่มที่ 1: เครื่องมือเขียนความแม่นยำสูง (ปากกาหมึกซึม, หัวเข็ม, ลูกลื่น, พู่กัน, ตัวเขียน, ดินสอ)"
        ),
        "sample_showcase_p2_subtitle" to mapOf(
            "zh-Hant" to "第二章：超低延遲壓感物理引擎與全套筆刷實戰筆跡全景陳列",
            "en" to "Chapter 2: Authentic Pressure-Sensitive Physics & Live Stroke Showcase",
            "zh-Hans" to "第二章：超低延迟压感物理引擎与全套笔刷实战笔迹全景陈列",
            "ja" to "第2章：物理筆圧シミュレーションと全ツールの生きた筆跡ギャラリー",
            "ko" to "제2장: 물리적 필압 반응 및 16종 도구의 생생한 필적 갤러리",
            "th" to "บทที่ 2: การตอบสนองแรงกดจริงและแกลเลอรีเส้นสายครบทุกเครื่องมือ"
        ),
        "sample_showcase_p2_tape_desc" to mapOf(
            "zh-Hant" to "可互動遮蔽膠帶：輕點下方黃色膠帶即可瞬間顯示或隱藏關鍵背誦答案！考研與背單字背公式的神器。",
            "en" to "Interactive Masking Tape: Tap the colored tape strip below to reveal hidden study answers! Perfect for memorization and exam review.",
            "zh-Hans" to "可交互遮蔽胶带：轻点下方黄色胶带即可瞬间显示或隐藏关键背诵答案！考研与背单字背公式的神器。",
            "ja" to "インタラクティブ・マスキングテープ：下のテープをタップすると隠された答えが表示されます！暗記や試験対策に最適。",
            "ko" to "인터랙티브 마스킹 테이프: 아래의 테이프를 탭하면 가려진 정답이 드러납니다! 암기 학습과 시험 대비에 탁월합니다.",
            "th" to "เทปปิดบังแบบโต้ตอบ: แตะแถบเทปด้านล่างเพื่อเปิดคำตอบที่ซ่อนอยู่! เหมาะสำหรับการท่องจำและทบทวนบทเรียน"
        ),
        "sample_showcase_p2_title" to mapOf(
            "zh-Hant" to "手繪模式：十六大專業繪畫與標注工具全景實作實測",
            "en" to "Handwriting Studio: All 16 Inking Tools in Action",
            "zh-Hans" to "手绘模式：十六大专业绘画与标注工具全景实作实测",
            "ja" to "手描きスタジオ：全16種描画ツールの完全実演",
            "ko" to "손글씨 스튜디오: 16종 전 툴 실습 및 필적 쇼케이스",
            "th" to "สตูดิโอลายมือ: สาธิตการใช้งานเครื่องมือวาดเขียนครบทั้ง 16 ชนิด"
        ),
        "sample_showcase_p3_flow_decision" to mapOf(
            "zh-Hant" to "結構化驗證？",
            "en" to "Structured?",
            "zh-Hans" to "结构化验证？",
            "ja" to "構造化完了？",
            "ko" to "구조화 완료?",
            "th" to "จัดโครงสร้างแล้ว?"
        ),
        "sample_showcase_p3_flow_end" to mapOf(
            "zh-Hant" to "精緻成稿輸出",
            "en" to "Published Note",
            "zh-Hans" to "精致成稿输出",
            "ja" to "ノート完成",
            "ko" to "노트 발행 완료",
            "th" to "บันทึกเสร็จสมบูรณ์"
        ),
        "sample_showcase_p3_flow_process" to mapOf(
            "zh-Hant" to "核心向量解算",
            "en" to "Vector Engine",
            "zh-Hans" to "核心矢量解算",
            "ja" to "ベクター処理",
            "ko" to "벡터 엔진 처리",
            "th" to "ประมวลผลเวกเตอร์"
        ),
        "sample_showcase_p3_flow_start" to mapOf(
            "zh-Hant" to "靈感鍵入",
            "en" to "Input Thought",
            "zh-Hans" to "灵感键入",
            "ja" to "発想の入力",
            "ko" to "아이디어 입력",
            "th" to "เริ่มป้อนความคิด"
        ),
        "sample_showcase_p3_flow_title" to mapOf(
            "zh-Hant" to "3. 幾何圖形庫與自適應拓撲連接線",
            "en" to "3. Geometry Shapes & Dynamic Smart Connectors",
            "zh-Hans" to "3. 几何图形库与自适应拓扑连接线",
            "ja" to "3. 幾何図形とスマート接続コネクタ",
            "ko" to "3. 기하 도형 및 스마트 자동 연결선",
            "th" to "3. รูปทรงเรขาคณิตและเส้นเชื่อมโยงอัจฉริยะ"
        ),
        "sample_showcase_p3_media_title" to mapOf(
            "zh-Hant" to "4. 智慧網頁預覽卡片、錄音時間軸卡片與 3D 空間立體模型",
            "en" to "4. Interactive Web Links, Audio Cards & 3D Spatial Models",
            "zh-Hans" to "4. 智能网页预览卡片、录音时间轴卡片与 3D 空间立体模型",
            "ja" to "4. Webリンクカード・音声録音・3D空間オブジェクト",
            "ko" to "4. 웹 링크 카드, 오디오 녹음 카드 & 3D 공간 모델",
            "th" to "4. การ์ดลิงก์เว็บ, การ์ดบันทึกเสียง และโมเดล 3D เชิงพื้นที่"
        ),
        "sample_showcase_p3_richtext_body" to mapOf(
            "zh-Hant" to "每一個文字框均具備完整的獨立版面參數：支援字型、字號、粗體、斜體、底線、刪除線、行距、段落間距、背景填色、邊框寬度與自適應圓角，輕鬆搭建雜誌級排版。",
            "en" to "Each text frame supports individual typography parameters: font family, point sizes, bold, italic, underline, strikethrough, paragraph spacing, line height, background fills, border styles, and rounded corners.",
            "zh-Hans" to "每一个文本框均具备完整的独立版面参数：支持字型、字号、粗体、斜体、底线、删除线、行距、段落间距、背景填色、边框宽度与自适应圆角，轻松搭建杂志级排版。",
            "ja" to "各テキスト枠は独立したスタイル設定を完全サポート：フォント種類、文字サイズ、太字、斜体、下線、打消し線、段落余白、行送り、背景塗りつぶし、枠線、角丸調整。",
            "ko" to "각 텍스트 프레임은 독립적인 조판 파라미터를 완벽히 지원합니다: 글꼴 패밀리, 폰트 크기, 굵게, 기울임, 밑줄, 취소선, 단락 여백, 행간, 배경색 채우기, 테두리 및 둥근 모서리.",
            "th" to "แต่ละกล่องข้อความรองรับการตั้งค่าการพิมพ์อย่างอิสระ: รูปแบบอักษร, ขนาด, ตัวหนา, ตัวเอียง, ขีดเส้นใต้, ขีดฆ่า, ระยะห่างย่อหน้า, สีพื้นหลัง, เส้นขอบ และมุมมน"
        ),
        "sample_showcase_p3_richtext_title" to mapOf(
            "zh-Hant" to "1. 桌面級富文字文字排版引擎",
            "en" to "Word-Grade Rich Text Formatting",
            "zh-Hans" to "1. 桌面级富文本文字排版引擎",
            "ja" to "Wordクラスの高度なリッチテキスト組版",
            "ko" to "워드급 정밀 리치 텍스트 조판 시스템",
            "th" to "การจัดรูปแบบข้อความระดับโปรแกรมประมวลผลคำ"
        ),
        "sample_showcase_p3_subtitle" to mapOf(
            "zh-Hant" to "第三章：桌面級排版、高階樣式表格、自適應流程圖、3D模型與多媒體錄音卡片",
            "en" to "Chapter 3: Rich Text Formatting, Data Tables, Connectors, 3D Models & Audio Cards",
            "zh-Hans" to "第三章：桌面级排版、高阶样式表格、自适应流程图、3D模型与多媒体录音卡片",
            "ja" to "第3章：リッチテキスト装飾、データ表、コネクタ付き図形、3Dモデル、音声カードの実装",
            "ko" to "제3장: 리치 텍스트 서식, 데이터 표, 연결선 도형, 3D 모델, 오디오 카드 완벽 구현",
            "th" to "บทที่ 3: การจัดรูปแบบข้อความ, ตารางข้อมูล, รูปทรงเชื่อมโยง, โมเดล 3D และการ์ดเสียง"
        ),
        "sample_showcase_p3_table_data" to mapOf(
            "zh-Hant" to "核心模組|類型|渲染幀率|架構特性說明\n排版引擎|原生核心|60 FPS 無卡頓|次像素抗鋸齒字型渲染，極速鍵入響應\n數據表格|柵格矩陣|O(1) 瞬時查詢|儲存格寬高自適應，支援表頭自訂色帶\n流程連接線|智慧向量|即時重繪|節點移動時自動重算正交正弦拓撲連接",
            "en" to "Module|Type|Performance|Description\nText Engine|Native Core|60 FPS|Sub-pixel font rendering with zero stutter\nVector Table|Grid Matrix|O(1) Access|Adaptive cell resizing with custom borders\nFlow Connect|Smart Vector|Instant|Dynamic orthogonal routing between nodes",
            "zh-Hans" to "核心模块|类型|渲染帧率|架构特性说明\n排版引擎|原生核心|60 FPS 无卡顿|亚像素抗锯齿字体渲染，极速键入响应\n数据表格|栅格矩阵|O(1) 瞬时查询|单元格宽高自适应，支持表头自定义色带\n流程连接线|智能矢量|实时重绘|节点移动时自动重算正交正弦拓扑连接",
            "ja" to "モジュール|種類|パフォーマンス|機能詳細\nテキストエンジン|ネイティブコア|60 FPS|サブピクセル描画による滑らかなタイピング\nベクター表|グリッド配列|O(1) アクセス|セルの自動リサイズとカスタム罫線対応\nフロー接続線|スマートベクター|瞬時応答|ノード間を自動ルーティングする接続線",
            "ko" to "모듈|종류|성능|기능 상세\n텍스트 엔진|네이티브 코어|60 FPS|서브픽셀 렌더링으로 렉 없는 타이핑 지원\n벡터 표|그리드 매트릭스|O(1) 접근|셀 크기 자동 조절 및 맞춤형 테두리\n흐름 연결선|스마트 벡터|즉시 반응|도형 노드 간 자동 직교 라우팅 연결",
            "th" to "โมดูล|ชนิด|ประสิทธิภาพ|รายละเอียด\nเอนจินข้อความ|แกนเนทีฟ|60 FPS|เรนเดอร์ตัวอักษรคมชัด ลื่นไหลไม่กระตุก\nตารางเวกเตอร์|เมทริกซ์กริด|เข้าถึง O(1)|ปรับขนาดช่องตารางอัตโนมัติพร้อมเส้นขอบ\nเส้นเชื่อมผังงาน|เวกเตอร์อัจฉริยะ|ทันที|ค้นหาเส้นทางเชื่อมโยงระหว่างโหนดอัตโนมัติ"
        ),
        "sample_showcase_p3_table_title" to mapOf(
            "zh-Hant" to "2. 原生高性能數據表格（支援表頭填色與儲存格自適應）",
            "en" to "2. High-Performance Data Table with Styled Columns",
            "zh-Hans" to "2. 原生高性能数据表格（支持表头填色与单元格自适应）",
            "ja" to "2. 高性能データ表（ヘッダー背景＆罫線スタイル）",
            "ko" to "2. 고성능 데이터 표 (헤더 배경색 & 맞춤형 격자선)",
            "th" to "2. ตารางข้อมูลประสิทธิภาพสูงพร้อมสไตล์คอลัมน์"
        ),
        "sample_showcase_p3_title" to mapOf(
            "zh-Hant" to "文字與版面模式：專業排版、原生表格、流程圖與多媒體物件全實作",
            "en" to "Typography & Structure Studio: Desktop-Grade Object Engine",
            "zh-Hans" to "文字与版面模式：专业排版、原生表格、流程图与多媒体物件全实作",
            "ja" to "タイポグラフィ＆構造化スタジオ：高度オブジェクト機能",
            "ko" to "타이포그래피 & 구조화 스튜디오: 데스크톱급 객체 엔진",
            "th" to "สตูดิโอการจัดพิมพ์และโครงสร้าง: เอนจินออบเจกต์ระดับเดสก์ท็อป"
        ),
        "sample_showcase_p4_chart_card_desc" to mapOf(
            "zh-Hant" to "下方長條圖絕非死板圖片，而是原生活動的向量圖表組件。雙擊即可重新錄入數據或修改調色盤。圖表上的討論圖釘更實現了數據維度的空間上下文協作，徹底顛覆傳統筆記體驗。",
            "en" to "The chart below is a live vector component. Double-tap to open the data inspector, modify series figures, or switch palettes. Notice the discussion pin dropped on the leading metric—true context-first teamwork.",
            "zh-Hans" to "下方长条图绝非死板图片，而是原生活动的矢量图表组件。双击即可重新录入数据或修改调色盘。图表上的讨论图钉更实现了数据维度的空间上下文协作，彻底颠覆传统笔记体验。",
            "ja" to "下のグラフは生きたベクター要素です。ダブルタップでデータ編集画面が開き、数値や配色をその場で修正可能。最上位指標に配置された議論ピンによる、文脈重視のコラボレーションを体感してください。",
            "ko" to "아래 차트는 정적 이미지가 아닌 라이브 벡터 컴포넌트입니다. 더블 탭하여 수치를 수정하거나 테마를 변경할 수 있습니다. 1위 지표 위에 꽂힌 토론 핀을 통해 맥락 중심의 협업을 경험해 보세요.",
            "th" to "แผนภูมิด้านล่างเป็นเวกเตอร์สด แตะสองครั้งเพื่อเปิดตัวแก้ไขข้อมูล เปลี่ยนตัวเลข หรือเปลี่ยนชุดสี สังเกตหมุดอภิปรายที่ปักไว้บนข้อมูลสำคัญเพื่อการทำงานร่วมกันที่ตรงจุด"
        ),
        "sample_showcase_p4_chart_card_title" to mapOf(
            "zh-Hant" to "動態圖表工坊：拒絕死板貼圖，隨時雙擊重調數據與色彩",
            "en" to "Editable Chart Studio: Live Vector Data Integration",
            "zh-Hans" to "动态图表工坊：拒绝死板贴图，随时双击重调数据与色彩",
            "ja" to "編集可能なグラフ工房：生きたベクターデータの可視化",
            "ko" to "재편집 가능한 차트 스튜디오: 실시간 벡터 데이터 통합",
            "th" to "สตูดิโอแผนภูมิที่แก้ไขได้: รวมข้อมูลเวกเตอร์แบบโต้ตอบ"
        ),
        "sample_showcase_p4_conclusion_body" to mapOf(
            "zh-Hant" to "因為 Kairumo 拒絕妥協！當你渴望傳統紙張的靈性觸感，16 種物理級筆刷提供無與倫比的細膩回饋；當你需要構建嚴密的工程與學術知識庫，原生表格、LaTeX 微積分引擎、動編圖表與空間圖釘賦予你超凡生產力——更關鍵的是，這一切永遠屬於你，100% 免費開源，永無拘束。",
            "en" to "Because it refuses to compromise. When you need the fluidity of analog paper, our 16 brushes deliver perfection. When you need the structure of desktop documents, our tables, LaTeX formulas, editable charts, and spatial pins give you superpowers—all wrapped in 100% open source freedom.",
            "zh-Hans" to "因为 Kairumo 拒绝妥协！当你渴望传统纸张的灵性触感，16 种物理级笔刷提供无与伦比的细腻回馈；当你需要构建严密的工程与学术知识库，原生表格、LaTeX 微积分引擎、动编图表与空间图钉赋予你超凡生产力——更关键的是，这一切永远属于你，100% 免费开源，永无拘束。",
            "ja" to "一切の妥協を排したからです。紙のような直感的な筆記が必要な時は16種のブラシが完璧に応え、ドキュメントの厳密な構造化が必要な時は表、数式、動的グラフ、空間ピンが圧倒的な生産性をもたらします。すべてが完全オープンソースの自由の中に。",
            "ko" to "타협하지 않는 완벽함을 추구하기 때문입니다. 아날로그 종이의 자연스러움이 필요할 땐 16종 브러시가 완벽한 필기감을 선사하고, 문서의 체계적 구조화가 필요할 땐 표, LaTeX 수식, 동적 차트, 공간 핀이 독보적인 생산성을 발휘합니다. 이 모든 것이 100% 오픈소스의 자유 속에 담겨 있습니다.",
            "th" to "เพราะ Kairumo ไม่ยอมประนีประนอมกับข้อจำกัดใดๆ เมื่อคุณต้องการความลื่นไหลของกระดาษจริง พู่กันทั้ง 16 ชนิดพร้อมมอบประสบการณ์ที่ดีที่สุด และเมื่อคุณต้องการโครงสร้างเอกสาร ตาราง สูตร LaTeX กราฟสด และหมุดอภิปรายจะมอบพลังการสร้างสรรค์อันไร้ขีดจำกัด ทั้งหมดนี้ฟรีและเปิดเผยซอร์สโค้ด 100%"
        ),
        "sample_showcase_p4_conclusion_title" to mapOf(
            "zh-Hant" to "為什麼創作者、工程師與學者一致讚嘆 Kairumo？",
            "en" to "Why Creators, Engineers & Scholars Choose Kairumo",
            "zh-Hans" to "为什么创作者、工程师与学者一致赞叹 Kairumo？",
            "ja" to "世界中の創作者・技術者・研究者が Kairumo を選ぶ理由",
            "ko" to "전 세계의 창작자, 엔지니어, 연구자들이 Kairumo를 선택하는 이유",
            "th" to "เหตุผลที่นักสร้างสรรค์ วิศวกร และนักวิชาการเลือก Kairumo"
        ),
        "sample_showcase_p4_hero_badge" to mapOf(
            "zh-Hant" to "★ Kairumo 殺手級體驗：手寫自由與打字秩序的無界融合",
            "en" to "★ Kairumo Superpower: Zero Friction Synthesis of Hand & Type",
            "zh-Hans" to "★ Kairumo 杀手级体验：手写自由与打字秩序的无界融合",
            "ja" to "★ Kairumoの真骨頂：手描きとタイピングの完全融合",
            "ko" to "★ Kairumo의 독보적 강점: 손글씨와 타이핑의 완벽한 융합",
            "th" to "★ พลังพิเศษของ Kairumo: การผสานลายมือและการพิมพ์อย่างไร้รอยต่อ"
        ),
        "sample_showcase_p4_math_card_desc" to mapOf(
            "zh-Hant" to "左側為手寫筆真實書寫的微積分積分題，右側為系統排版的解析步驟。教師用筆手寫推導、套索一鍵轉為標準 LaTeX，助教與學生直接在公式易錯點釘入討論圖釘，打造前所未有的思考閉環。",
            "en" to "Watch how effortlessly handwritten strokes (left) pair with structured typed derivations (right). An instructor writes equations with Apple Pencil, lasso-converts them to LaTeX, while colleagues drop review pins directly onto critical steps.",
            "zh-Hans" to "左侧为手写笔真实书写的微积分积分题，右侧为系统排版的解析步骤。教师用笔手写推导、套索一键转为标准 LaTeX，助教与学生直接在公式易错点钉入讨论图钉，打造前所未有的思考闭环。",
            "ja" to "左手の手描き筆跡と右側の整然としたタイピング解説の調和をご覧ください。教員が手描きで公式を展開し、投げ縄でLaTeXへ変換。共同研究者はステップ上に直接ピンを配置して議論できます。",
            "ko" to "왼편의 자연스러운 손글씨 필적과 우측의 정돈된 타이핑 해설의 조화를 확인하세요. 펜으로 수식을 유도하고, 올가미로 LaTeX로 변환하며, 동료는 유도 단계 위에 직접 토론 핀을 꽂아 피드백을 남깁니다.",
            "th" to "ชมการผสานกันอย่างลงตัวระหว่างลายมือ (ซ้าย) และขั้นตอนการคำนวณที่พิมพ์อย่างเป็นระเบียบ (ขวา) ผู้สอนเขียนสูตรด้วยปากกา แปลงเป็น LaTeX และผู้ร่วมงานปักหมุดข้อคิดเห็นลงบนขั้นตอนสำคัญได้ทันที"
        ),
        "sample_showcase_p4_math_card_title" to mapOf(
            "zh-Hant" to "深度實戰示範：從手寫微積分筆跡到 LaTeX 轉化與步驟解算",
            "en" to "Real-Time Calculus Derivation: From Pen Strokes to LaTeX & Step Solver",
            "zh-Hans" to "深度实战示范：从手写微积分笔迹到 LaTeX 转化与步骤解算",
            "ja" to "リアルタイム微積分推導：手描き筆跡からLaTeX整形とステップ解説へ",
            "ko" to "실시간 미적분 풀이: 펜 필적에서 LaTeX 변환 및 단계별 솔버까지",
            "th" to "การแก้โจทย์แคลคูลัสแบบเรียลไทม์: จากลายมือสู่ LaTeX และเฉลยเป็นขั้นตอน"
        ),
        "sample_showcase_p4_subtitle" to mapOf(
            "zh-Hant" to "第四章：微積分公式推導、動態圖表工坊與空間討論圖釘的終極融合範例",
            "en" to "Chapter 4: Ultimate Synergy of STEM Math, Dynamic Charting & Collaborative Pins",
            "zh-Hans" to "第四章：微积分公式推导、动态图表工坊与空间讨论图钉的终极融合范例",
            "ja" to "第4章：STEM微積分・動的グラフ・空間ピン協働の究極の相乗効果",
            "ko" to "제4장: STEM 미적분·동적 차트·공간 핀 협업의 궁극적 시너지",
            "th" to "บทที่ 4: พลังการผสานคณิตศาสตร์ STEM แผนภูมิไดนามิก และหมุดอภิปราย"
        ),
        "sample_showcase_p4_title" to mapOf(
            "zh-Hant" to "終極交響樂：手繪＋打字合奏，展現 Kairumo 無與倫比的顛覆優勢",
            "en" to "The Grand Symphony: Why Kairumo Outshines the Rest",
            "zh-Hans" to "终极交响乐：手绘＋打字合奏，展现 Kairumo 无与伦比的颠覆优势",
            "ja" to "グランドシンフォニー：Kairumoが選ばれる真の理由",
            "ko" to "그랜드 심포니: Kairumo가 모든 앱을 압도하는 이유",
            "th" to "สุดยอดการผสานพลัง: ทำไม Kairumo จึงโดดเด่นเหนือใคร"
        ),
        "sample_showcase_pin1_msg" to mapOf(
            "zh-Hant" to "重點關注第三季度的爆發增長：Kairumo 原生向量核心帶來的書寫流暢度獲得了壓倒性的好評！",
            "en" to "Notice the Q3 growth surge: Kairumo's native vector engine provides significantly higher user satisfaction than traditional raster apps.",
            "zh-Hans" to "重点关注第三季度的爆发增长：Kairumo 原生矢量内核带来的书写流畅度获得了压倒性的好评！",
            "ja" to "第3四半期の急伸に注目：Kairumoのネイティブベクターエンジンは、従来のラスター系アプリを上回る満足度を記録しています。",
            "ko" to "3분기 급성장 주목: Kairumo의 네이티브 벡터 엔진은 기존 래스터 앱 대비 월등한 사용자 만족도를 제공합니다.",
            "th" to "สังเกตการเติบโตในไตรมาสที่ 3: เอนจินเวกเตอร์ของ Kairumo มอบความพึงพอใจที่สูงกว่าแอปแบบเดิมอย่างเห็นได้ชัด"
        ),
        "sample_showcase_pin2_msg" to mapOf(
            "zh-Hant" to "分部積分第一步的邊界代入驗證：[ -x cos(x) ] 從 0 代入至 π，精確得到 +π，沒有漏掉負號。",
            "en" to "Verify the boundary term when applying integration by parts: [ -x cos(x) ] evaluated from 0 to pi cleanly evaluates to +pi.",
            "zh-Hans" to "分部积分第一步的边界代入验证：[ -x cos(x) ] 从 0 代入至 π，精确得到 +π，没有漏掉负号。",
            "ja" to "部分積分の境界値を再確認：[ -x cos(x) ] を 0 から π まで代入すると、正確に +π が導出されます。",
            "ko" to "부분적분 경계값 대입 검증: [ -x cos(x) ]에 0부터 π까지 대입하면 정확히 +π가 깔끔하게 도출됩니다.",
            "th" to "ตรวจสอบค่าขอบเขตเมื่อใช้อินทิเกรตทีละส่วน: [ -x cos(x) ] จาก 0 ถึง pi ให้ค่าเท่ากับ +pi อย่างลงตัว"
        ),
        "sample_showcase_pin_hint" to mapOf(
            "zh-Hant" to "<- [ 點擊圖釘看即時討論串 ]",
            "en" to "<- [ Tap pin for thread ]",
            "zh-Hans" to "<- [ 点击图钉看即时讨论串 ]",
            "ja" to "<- [ ピンをタップしてスレッド確認 ]",
            "ko" to "<- [ 핀 탭하여 실시간 스레드 확인 ]",
            "th" to "<- [ แตะหมุดเพื่อดูเธรดการสนทนา ]"
        ),
        "sample_showcase_table_title" to mapOf(
            "zh-Hant" to "Kairumo 與市面主流前三大筆記應用核心功能優缺點全景對比",
            "en" to "Kairumo vs. Top 3 Mainstream Note Apps Comparison",
            "zh-Hans" to "Kairumo 与市面主流前三大笔记应用核心功能优缺点全景对比",
            "ja" to "Kairumo vs 市販トップ3ノートアプリ 総合比較表",
            "ko" to "Kairumo vs 시장 3대 주요 노트 앱 종합 비교표",
            "th" to "ตารางเปรียบเทียบ Kairumo กับ 3 แอปจดบันทึกชั้นนำในตลาด"
        ),
        "sample_showcase_tape_answer" to mapOf(
            "zh-Hant" to "重點背誦答案：[ Kairumo 採用 UniFFI + Rust 核心，達到零延遲 60FPS 極致流暢！ ]",
            "en" to "Key recitation answer: [ Kairumo uses UniFFI + Rust core to achieve zero-latency 60FPS fluid performance! ]",
            "zh-Hans" to "重点背诵答案：[ Kairumo 采用 UniFFI + Rust 核心，达到零延迟 60FPS 极致流畅！ ]",
            "ja" to "暗記ポイント：[ Kairumo は UniFFI + Rust コアを採用し、遅延ゼロの60FPS描画を実現！ ]",
            "ko" to "핵심 암기 정답: [ Kairumo는 UniFFI + Rust 코어를 채택하여 제로 레이턴시 60FPS의 극강 유연성을 제공합니다! ]",
            "th" to "คำตอบสำคัญ: [ Kairumo ใช้ UniFFI + Rust core เพื่อความลื่นไหลระดับ 60FPS แบบไร้ความหน่วง! ]"
        ),
        "sample_showcase_tool_10_oilpaint" to mapOf(
            "zh-Hant" to "10. Oil Paint (油畫):",
            "en" to "10. Oil Paint:",
            "zh-Hans" to "10. Oil Paint (油画):",
            "ja" to "10. Oil Paint (油絵):",
            "ko" to "10. Oil Paint (유화):",
            "th" to "10. Oil Paint (สีน้ำมัน):"
        ),
        "sample_showcase_tool_11_watercolor" to mapOf(
            "zh-Hant" to "11. Watercolor (水彩):",
            "en" to "11. Watercolor:",
            "zh-Hans" to "11. Watercolor (水彩):",
            "ja" to "11. Watercolor (水彩):",
            "ko" to "11. Watercolor (수채화):",
            "th" to "11. Watercolor (สีน้ำ):"
        ),
        "sample_showcase_tool_12_marker" to mapOf(
            "zh-Hant" to "12. Marker (記號筆):",
            "en" to "12. Marker:",
            "zh-Hans" to "12. Marker (记号笔):",
            "ja" to "12. Marker (マーカー):",
            "ko" to "12. Marker (마커):",
            "th" to "12. Marker (ปากกามาร์กเกอร์):"
        ),
        "sample_showcase_tool_13_highlighter" to mapOf(
            "zh-Hant" to "13. Highlighter (螢光筆):",
            "en" to "13. Highlighter:",
            "zh-Hans" to "13. Highlighter (荧光笔):",
            "ja" to "13. Highlighter (蛍光ペン):",
            "ko" to "13. Highlighter (형광펜):",
            "th" to "13. Highlighter (ปากกาเน้นข้อความ):"
        ),
        "sample_showcase_tool_14_ruler" to mapOf(
            "zh-Hant" to "14. Ruler (尺規引導):",
            "en" to "14. Ruler:",
            "zh-Hans" to "14. Ruler (尺规引导):",
            "ja" to "14. Ruler (定規ガイド):",
            "ko" to "14. Ruler (자 안내선):",
            "th" to "14. Ruler (ไม้บรรทัด):"
        ),
        "sample_showcase_tool_15_lasso" to mapOf(
            "zh-Hant" to "15. Lasso (幾何套索圈選):",
            "en" to "15. Lasso:",
            "zh-Hans" to "15. Lasso (几何套索圈选):",
            "ja" to "15. Lasso (なげなわ選択):",
            "ko" to "15. Lasso (올가미 선택):",
            "th" to "15. Lasso (บ่วงบาศเลือก):"
        ),
        "sample_showcase_tool_1_pen" to mapOf(
            "zh-Hant" to "1. Pen (鋼筆):",
            "en" to "1. Pen:",
            "zh-Hans" to "1. Pen (钢笔):",
            "ja" to "1. Pen (万年筆):",
            "ko" to "1. Pen (만년필):",
            "th" to "1. Pen (ปากกาหมึกซึม):"
        )
    )

    private fun part22(): Map<String, Map<String, String>> = mapOf(
        "sample_showcase_tool_2_fineliner" to mapOf(
            "zh-Hant" to "2. Fineliner (針筆):",
            "en" to "2. Fineliner:",
            "zh-Hans" to "2. Fineliner (针笔):",
            "ja" to "2. Fineliner (製図ペン):",
            "ko" to "2. Fineliner (파인라이너):",
            "th" to "2. Fineliner (ปากกาหัวเข็ม):"
        ),
        "sample_showcase_tool_3_ballpoint" to mapOf(
            "zh-Hant" to "3. Ballpoint (原子筆):",
            "en" to "3. Ballpoint:",
            "zh-Hans" to "3. Ballpoint (原子笔):",
            "ja" to "3. Ballpoint (ボールペン):",
            "ko" to "3. Ballpoint (볼펜):",
            "th" to "3. Ballpoint (ปากกาลูกลื่น):"
        ),
        "sample_showcase_tool_4_brush" to mapOf(
            "zh-Hant" to "4. Brush (毛筆):",
            "en" to "4. Brush:",
            "zh-Hans" to "4. Brush (毛笔):",
            "ja" to "4. Brush (筆):",
            "ko" to "4. Brush (붓):",
            "th" to "4. Brush (พู่กัน):"
        ),
        "sample_showcase_tool_5_calligraphy" to mapOf(
            "zh-Hant" to "5. Calligraphy (書法):",
            "en" to "5. Calligraphy:",
            "zh-Hans" to "5. Calligraphy (书法):",
            "ja" to "5. Calligraphy (カリグラフィー):",
            "ko" to "5. Calligraphy (캘리그래피):",
            "th" to "5. Calligraphy (ประดิษฐ์อักษร):"
        ),
        "sample_showcase_tool_6_pencil" to mapOf(
            "zh-Hant" to "6. Pencil (鉛筆):",
            "en" to "6. Pencil:",
            "zh-Hans" to "6. Pencil (铅笔):",
            "ja" to "6. Pencil (鉛筆):",
            "ko" to "6. Pencil (연필):",
            "th" to "6. Pencil (ดินสอ):"
        ),
        "sample_showcase_tool_7_charcoal" to mapOf(
            "zh-Hant" to "7. Charcoal (炭筆):",
            "en" to "7. Charcoal:",
            "zh-Hans" to "7. Charcoal (炭笔):",
            "ja" to "7. Charcoal (木炭):",
            "ko" to "7. Charcoal (목탄):",
            "th" to "7. Charcoal (ถ่านชาร์โคล):"
        ),
        "sample_showcase_tool_8_crayon" to mapOf(
            "zh-Hant" to "8. Crayon (蠟筆):",
            "en" to "8. Crayon:",
            "zh-Hans" to "8. Crayon (蜡笔):",
            "ja" to "8. Crayon (クレヨン):",
            "ko" to "8. Crayon (크레용):",
            "th" to "8. Crayon (สีเทียน):"
        ),
        "sample_showcase_tool_9_airbrush" to mapOf(
            "zh-Hant" to "9. Airbrush (噴槍):",
            "en" to "9. Airbrush:",
            "zh-Hans" to "9. Airbrush (喷枪):",
            "ja" to "9. Airbrush (エアブラシ):",
            "ko" to "9. Airbrush (에어브러시):",
            "th" to "9. Airbrush (แอร์บรัช):"
        ),
        "sample_welcome" to mapOf(
            "zh-Hant" to "歡迎使用 Kairumo",
            "en" to "Welcome to Kairumo",
            "zh-Hans" to "欢迎使用 Kairumo",
            "ja" to "Kairumo へようこそ",
            "ko" to "Kairumo에 오신 것을 환영합니다",
            "th" to "ยินดีต้อนรับสู่ Kairumo"
        ),
        "sample_welcome_p1_body" to mapOf(
            "zh-Hant" to "這是一本可以直接改的說明筆記。\n\n• 手寫：用觸控筆、手指或滑鼠都寫得了，寫下的是原始取樣點。\n• 打字：插入文字方塊，字型、行距、對齊都調得動。\n• 錄音：錄下的聲音與筆跡在同一條時間軸上，點筆跡就跳到當時的聲音。\n\n這一頁上的每一個方塊、表格與圖形都可以搬、可以改、可以刪。試著拖一下看看。",
            "en" to "This is a help note you can edit directly.\n\n• Handwriting: pen, finger or mouse — raw sample points are what get stored.\n• Typing: insert a text box and adjust font, line spacing and alignment.\n• Recording: audio and ink share one timeline — tap a stroke to jump to that moment.\n\nEvery box, table and shape on this page can be moved, edited and deleted. Try dragging one.",
            "zh-Hans" to "这是一本可以直接改的说明笔记。\n\n• 手写：用触控笔、手指或鼠标都写得了，写下的是原始采样点。\n• 打字：插入文字框，字体、行距、对齐都调得动。\n• 录音：录下的声音与笔迹在同一条时间轴上，点笔迹就跳到当时的声音。\n\n这一页上的每一个方块、表格与图形都可以搬、可以改、可以删。试着拖一下看看。",
            "ja" to "これはそのまま編集できる説明ノートです。\n\n• 手書き：ペン・指・マウスのいずれでも書けます。保存されるのは生のサンプル点です。\n• 入力：テキストボックスを挿入し、フォント・行間・配置を調整できます。\n• 録音：音声と筆跡は同じタイムライン上にあり、筆跡をタップするとその瞬間の音声に飛びます。\n\nこのページのボックス・表・図形はすべて移動・編集・削除できます。ドラッグしてみてください。",
            "ko" to "바로 편집할 수 있는 설명 노트입니다.\n\n• 필기: 펜, 손가락, 마우스 모두 가능하며 원본 샘플 점이 저장됩니다.\n• 입력: 텍스트 상자를 넣고 글꼴·줄 간격·정렬을 조정할 수 있습니다.\n• 녹음: 음성과 필기가 같은 타임라인에 있어 획을 누르면 그 순간의 소리로 이동합니다.\n\n이 페이지의 상자·표·도형은 모두 옮기고 고치고 지울 수 있습니다. 한번 끌어보세요.",
            "th" to "นี่คือสมุดคำอธิบายที่แก้ไขได้ทันที\n\n• เขียนด้วยลายมือ: ใช้ปากกา นิ้ว หรือเมาส์ได้ ระบบเก็บจุดตัวอย่างดิบไว้\n• พิมพ์: แทรกกล่องข้อความแล้วปรับฟอนต์ ระยะบรรทัด และการจัดวาง\n• บันทึกเสียง: เสียงกับลายเส้นอยู่บนไทม์ไลน์เดียวกัน แตะเส้นเพื่อข้ามไปยังช่วงเสียงนั้น\n\nทุกกล่อง ตาราง และรูปทรงบนหน้านี้ ย้าย แก้ไข และลบได้ ลองลากดู"
        ),
        "sample_welcome_p1_title" to mapOf(
            "zh-Hant" to "歡迎使用 Kairumo",
            "en" to "Welcome to Kairumo",
            "zh-Hans" to "欢迎使用 Kairumo",
            "ja" to "Kairumo へようこそ",
            "ko" to "Kairumo에 오신 것을 환영합니다",
            "th" to "ยินดีต้อนรับสู่ Kairumo"
        ),
        "sample_welcome_p2_body" to mapOf(
            "zh-Hant" to "這張表是真的表格物件：點兩下任一格就能改字，拖右下角可以調大小。",
            "en" to "This is a real table object — double-tap any cell to edit it, drag the corner to resize.",
            "zh-Hans" to "这张表是真的表格对象：点两下任一格就能改字，拖右下角可以调大小。",
            "ja" to "これは実際の表オブジェクトです。セルをダブルタップで編集、角をドラッグでサイズ変更できます。",
            "ko" to "이것은 실제 표 객체입니다. 셀을 두 번 눌러 수정하고, 모서리를 끌어 크기를 조절하세요.",
            "th" to "นี่คือวัตถุตารางจริง แตะสองครั้งที่ช่องใดก็ได้เพื่อแก้ไข ลากมุมเพื่อปรับขนาด"
        ),
        "sample_welcome_p2_title" to mapOf(
            "zh-Hant" to "工具列怎麼用",
            "en" to "Using the toolbar",
            "zh-Hans" to "工具栏怎么用",
            "ja" to "ツールバーの使い方",
            "ko" to "도구 모음 사용법",
            "th" to "วิธีใช้แถบเครื่องมือ"
        ),
        "sample_welcome_p3_body" to mapOf(
            "zh-Hant" to "沒有伺服器，也沒有帳號。你的筆記存在這台裝置上。\n\n• 同步：登入你自己的 Google 雲端硬碟，資料放在應用程式專屬資料夾，檔案清單看不到它。\n• 備份：匯出成 .padnote、PDF、Markdown 或 SVG，放到任何你信得過的地方。\n• 隱私：沒有分析、沒有追蹤、沒有帳號可以連結到你。細節看首頁的「隱私權政策」。\n\n沒有帳號就沒有「忘記密碼」—— 但也代表裝置遺失時沒有雲端副本，請自己做備份。",
            "en" to "No server, no account. Your notes live on this device.\n\n• Sync: sign in to your own Google Drive; data goes to an app-private folder you won't see in your file list.\n• Backup: export to .padnote, PDF, Markdown or SVG and keep it anywhere you trust.\n• Privacy: no analytics, no tracking, no account to link back to you. See “Privacy Policy” on the home screen.\n\nNo account means no “forgot password” — but it also means no cloud copy if you lose the device. Make your own backups.",
            "zh-Hans" to "没有服务器，也没有账号。你的笔记存在这台装置上。\n\n• 同步：登录你自己的 Google 云端硬碟，资料放在应用程式专属资料夹，档案清单看不到它。\n• 备份：汇出成 .padnote、PDF、Markdown 或 SVG，放到任何你信得过的地方。\n• 隐私：没有分析、没有追踪、没有账号可以连结到你。细节看首页的「隐私权政策」。\n\n没有账号就没有「忘记密码」—— 但也代表装置遗失时没有云端副本，请自己做备份。",
            "ja" to "サーバーもアカウントもありません。ノートはこの端末の中にあります。\n\n• 同期：ご自身の Google ドライブにログインすると、アプリ専用フォルダに保存されます（ファイル一覧には表示されません）。\n• バックアップ：.padnote、PDF、Markdown、SVG に書き出して、信頼できる場所に保管できます。\n• プライバシー：解析も追跡もアカウントもありません。詳しくはホーム画面の「プライバシーポリシー」をご覧ください。\n\nアカウントがないので「パスワードを忘れた」はありません。ただし端末を失うとクラウドの控えもありません。必ずご自身でバックアップを。",
            "ko" to "서버도 계정도 없습니다. 노트는 이 기기에 저장됩니다.\n\n• 동기화: 본인의 Google 드라이브에 로그인하면 앱 전용 폴더에 저장되며 파일 목록에는 보이지 않습니다.\n• 백업: .padnote, PDF, Markdown, SVG로 내보내 믿을 수 있는 곳에 보관하세요.\n• 개인정보: 분석도 추적도 없고, 연결될 계정도 없습니다. 홈 화면의 “개인정보 처리방침”을 보세요.\n\n계정이 없으니 “비밀번호 찾기”도 없습니다. 대신 기기를 잃으면 클라우드 사본도 없으니 직접 백업하세요.",
            "th" to "ไม่มีเซิร์ฟเวอร์ ไม่มีบัญชี บันทึกของคุณอยู่ในเครื่องนี้\n\n• ซิงค์: ลงชื่อเข้าใช้ Google Drive ของคุณเอง ข้อมูลจะอยู่ในโฟลเดอร์เฉพาะแอปที่ไม่ปรากฏในรายการไฟล์\n• สำรองข้อมูล: ส่งออกเป็น .padnote, PDF, Markdown หรือ SVG แล้วเก็บไว้ที่ใดก็ได้ที่คุณไว้ใจ\n• ความเป็นส่วนตัว: ไม่มีการวิเคราะห์ ไม่มีการติดตาม ไม่มีบัญชีที่โยงถึงคุณ ดูรายละเอียดที่ “นโยบายความเป็นส่วนตัว” บนหน้าแรก\n\nไม่มีบัญชีก็ไม่มี “ลืมรหัสผ่าน” แต่ก็แปลว่าถ้าเครื่องหายก็ไม่มีสำเนาบนคลาวด์ กรุณาสำรองข้อมูลเอง"
        ),
        "sample_welcome_p3_title" to mapOf(
            "zh-Hant" to "備份、同步與隱私",
            "en" to "Backup, sync and privacy",
            "zh-Hans" to "备份、同步与隐私",
            "ja" to "バックアップ・同期・プライバシー",
            "ko" to "백업, 동기화, 개인정보",
            "th" to "สำรองข้อมูล ซิงค์ และความเป็นส่วนตัว"
        ),
        "sample_welcome_pill_record" to mapOf(
            "zh-Hant" to "錄音",
            "en" to "Recording",
            "zh-Hans" to "录音",
            "ja" to "録音",
            "ko" to "녹음",
            "th" to "บันทึกเสียง"
        ),
        "sample_welcome_pill_type" to mapOf(
            "zh-Hant" to "打字",
            "en" to "Typing",
            "zh-Hans" to "打字",
            "ja" to "入力",
            "ko" to "입력",
            "th" to "พิมพ์"
        ),
        "sample_welcome_pill_write" to mapOf(
            "zh-Hant" to "手寫",
            "en" to "Handwriting",
            "zh-Hans" to "手写",
            "ja" to "手書き",
            "ko" to "필기",
            "th" to "ลายมือ"
        ),
        "sample_welcome_tools_table" to mapOf(
            "zh-Hant" to "工具|它做什麼\n筆與螢光筆|粗細與顏色各自記住，換回來還是原本那一支\n橡皮擦|整筆擦或局部擦，擦掉的筆畫留有墓碑，同步得回去\n套索|圈起來就能整組搬、縮放、旋轉\n插入|圖片、表格、圖表、形狀、連結、3D、錄音\n更多|次要工具收在這裡：圖層、算式、素材庫、主題工具",
            "en" to "Tool|What it does\nPen & highlighter|Each remembers its own width and colour\nEraser|Whole-stroke or partial; erased strokes leave tombstones so they sync\nLasso|Circle a group to move, scale and rotate it together\nInsert|Image, table, chart, shape, link, 3D, recording\nMore|Secondary tools live here: layers, formulas, asset library, theme tools",
            "zh-Hans" to "工具|它做什么\n笔与荧光笔|粗细与颜色各自记住，换回来还是原本那一支\n橡皮擦|整笔擦或局部擦，擦掉的笔画留有墓碑，同步得回去\n套索|圈起来就能整组搬、缩放、旋转\n插入|图片、表格、图表、形状、链接、3D、录音\n更多|次要工具收在这里：图层、算式、素材库、主题工具",
            "ja" to "ツール|はたらき\nペンと蛍光ペン|太さと色をそれぞれ記憶します\n消しゴム|一筆消しと部分消し。消した筆跡は墓標が残り同期されます\n投げ縄|囲めばまとめて移動・拡大縮小・回転できます\n挿入|画像・表・グラフ・図形・リンク・3D・録音\nその他|副次的なツール：レイヤー、数式、素材ライブラリ、テーマツール",
            "ko" to "도구|하는 일\n펜과 형광펜|각각 굵기와 색을 따로 기억합니다\n지우개|획 전체 또는 부분 지우기. 지운 획은 툼스톤이 남아 동기화됩니다\n올가미|묶어서 함께 옮기고 크기 조절하고 회전합니다\n삽입|이미지, 표, 차트, 도형, 링크, 3D, 녹음\n더 보기|보조 도구: 레이어, 수식, 소재 라이브러리, 테마 도구",
            "th" to "เครื่องมือ|ทำอะไร\nปากกาและปากกาเน้น|จำความหนาและสีของตัวเองแยกกัน\nยางลบ|ลบทั้งเส้นหรือบางส่วน เส้นที่ลบมีทูมสโตนจึงซิงค์ได้\nบ่วงบาศ|ล้อมไว้แล้วย้าย ย่อขยาย และหมุนพร้อมกัน\nแทรก|รูปภาพ ตาราง แผนภูมิ รูปทรง ลิงก์ 3D เสียงบันทึก\nเพิ่มเติม|เครื่องมือรอง: เลเยอร์ สูตรคำนวณ คลังวัสดุ เครื่องมือธีม"
        ),
        "save" to mapOf(
            "zh-Hant" to "儲存",
            "en" to "Save",
            "zh-Hans" to "保存",
            "ja" to "保存",
            "ko" to "저장",
            "th" to "บันทึก"
        ),
        "save_as_sticker" to mapOf(
            "zh-Hant" to "儲存為貼紙",
            "en" to "Save as Sticker",
            "zh-Hans" to "保存为贴纸",
            "ja" to "ステッカーとして保存",
            "ko" to "스티커로 저장",
            "th" to "บันทึกเป็นสติกเกอร์"
        ),
        "sd_loading" to mapOf(
            "zh-Hant" to "讀取中…",
            "en" to "Loading…",
            "zh-Hans" to "读取中…",
            "ja" to "読み込み中…",
            "ko" to "불러오는 중…",
            "th" to "กำลังโหลด…"
        ),
        "search_assets_placeholder" to mapOf(
            "zh-Hant" to "搜尋機構、3C、零件、規格、色彩...",
            "en" to "Search mechanisms, 3C, components, specs, colors...",
            "zh-Hans" to "搜索机构、3C、零件、规格、色彩...",
            "ja" to "機構、3C、パーツ、仕様、カラーを検索...",
            "ko" to "기구, 3C, 부품, 사양, 색상 검색...",
            "th" to "ค้นหากลไก, 3C, ชิ้นส่วน, สเปก, สี..."
        ),
        "search_no_result" to mapOf(
            "zh-Hant" to "找不到符合的筆記",
            "en" to "No matching notes",
            "zh-Hans" to "找不到符合的笔记",
            "ja" to "一致するノートがありません",
            "ko" to "일치하는 노트가 없습니다",
            "th" to "ไม่พบโน้ตที่ตรงกัน"
        ),
        "search_placeholder" to mapOf(
            "zh-Hant" to "搜尋筆記標題、草稿或內容…",
            "en" to "Search note titles, drafts, or transcripts…",
            "zh-Hans" to "搜索笔记标题、草稿或内容…",
            "ja" to "ノートのタイトル、下書き、内容を検索…",
            "ko" to "노트 제목, 초안 또는 내용 검색…",
            "th" to "ค้นหาชื่อบันทึก ร่าง หรือเนื้อหา…"
        ),
        "security" to mapOf(
            "zh-Hant" to "帳號與安全",
            "en" to "Account & Security",
            "zh-Hans" to "账号与安全",
            "ja" to "アカウントとセキュリティ",
            "ko" to "계정 및 보안",
            "th" to "บัญชีและความปลอดภัย"
        ),
        "seed_chart_cat_1" to mapOf(
            "zh-Hant" to "向量書寫延遲",
            "en" to "Ink latency",
            "zh-Hans" to "矢量书写延迟",
            "ja" to "筆記の遅延",
            "ko" to "필기 지연",
            "th" to "ความหน่วงของการเขียน"
        ),
        "seed_chart_cat_2" to mapOf(
            "zh-Hant" to "圖表動態可編修",
            "en" to "Editable charts",
            "zh-Hans" to "图表动态可编辑",
            "ja" to "編集できるグラフ",
            "ko" to "편집 가능한 차트",
            "th" to "แผนภูมิแก้ไขได้"
        ),
        "seed_chart_cat_3" to mapOf(
            "zh-Hant" to "空間圖釘協作",
            "en" to "Pin collaboration",
            "zh-Hans" to "空间图钉协作",
            "ja" to "ピンで共同作業",
            "ko" to "핀 협업",
            "th" to "ทำงานร่วมกันด้วยหมุด"
        ),
        "seed_chart_cat_4" to mapOf(
            "zh-Hant" to "開源與無訂閱限制",
            "en" to "Open source, no subscription",
            "zh-Hans" to "开源与无订阅限制",
            "ja" to "オープンソース・サブスクなし",
            "ko" to "오픈소스, 구독 없음",
            "th" to "โอเพนซอร์ส ไม่ต้องสมัครสมาชิก"
        ),
        "seed_feature_showcase_snippet" to mapOf(
            "zh-Hant" to "手繪（鉛筆/鋼筆/毛筆）、表格打字、微積分方程與數字製圖圖釘討論功能全方位實戰範例",
            "en" to "Deep integration showcase: pencil, fountain pen & brush handwriting, comparison table, calculus solver, digital chart & discussion pins",
            "zh-Hans" to "手绘（铅笔/钢笔/毛笔）、表格打字、微积分方程与数字制图图钉讨论功能全方位实战范例",
            "ja" to "鉛筆・万年筆・毛筆の手描き、比較表、微積分方程式、デジタル作図とピン議論を網羅した機能活用サンプル",
            "ko" to "연필·만년필·붓 손글씨, 비교 표, 미적분 방정식, 디지털 차트 및 토론 핀이 통합된 기능 활용 예제",
            "th" to "ตัวอย่างการใช้งานฟีเจอร์: ลายมือดินสอ/ปากกา/พู่กัน, ตารางเปรียบเทียบ, สมการแคลคูลัส, กราฟตัวเลข และหมุดอภิปราย"
        ),
        "seed_feature_showcase_title" to mapOf(
            "zh-Hant" to "Kairumo(功能範例)",
            "en" to "Kairumo (Feature Showcase)",
            "zh-Hans" to "Kairumo(功能范例)",
            "ja" to "Kairumo(機能の例)",
            "ko" to "Kairumo (기능 예시)",
            "th" to "Kairumo (ตัวอย่างฟังก์ชัน)"
        ),
        "seed_manual_snippet" to mapOf(
            "zh-Hant" to "Kairumo 優勢：結構化、視覺化、多語言 —— 全部手繪",
            "en" to "Kairumo’s advantages: structured, visual and multilingual",
            "zh-Hans" to "Kairumo 优势：结构化、视觉化、多语言 —— 全部手绘",
            "ja" to "Kairumo の強み: 構造化・視覚化・多言語",
            "ko" to "Kairumo의 강점: 체계적 구성, 시각화, 다국어",
            "th" to "จุดเด่นของ Kairumo: เป็นระบบ เห็นภาพ หลายภาษา"
        ),
        "seed_manual_title" to mapOf(
            "zh-Hant" to "Kairumo手冊",
            "en" to "Kairumo Manual",
            "zh-Hans" to "Kairumo手册",
            "ja" to "Kairumo マニュアル",
            "ko" to "Kairumo 매뉴얼",
            "th" to "คู่มือ Kairumo"
        ),
        "seed_meeting_snippet" to mapOf(
            "zh-Hant" to "支援麥克風即時收音，聲音與筆跡精確對齊",
            "en" to "Live microphone capture with audio precisely aligned to your ink",
            "zh-Hans" to "支持麦克风实时收音，声音与笔迹精确对齐",
            "ja" to "マイクでのリアルタイム録音、音声と筆跡を正確に同期",
            "ko" to "마이크 실시간 녹음, 음성과 필기를 정확히 정렬",
            "th" to "บันทึกเสียงสดจากไมโครโฟน พร้อมจัดเรียงเสียงให้ตรงกับลายมือ"
        ),
        "seed_meeting_title" to mapOf(
            "zh-Hant" to "課堂與會議記錄",
            "en" to "Lectures & Meetings",
            "zh-Hans" to "课堂与会议记录",
            "ja" to "授業と会議の記録",
            "ko" to "강의 및 회의 기록",
            "th" to "บันทึกการเรียนและการประชุม"
        ),
        "seed_pill_01" to mapOf(
            "zh-Hant" to "100% 完全開源免費",
            "en" to "100% free & open source",
            "zh-Hans" to "100% 完全开源免费",
            "ja" to "100% 無料・オープンソース",
            "ko" to "100% 무료 오픈소스",
            "th" to "ฟรีและโอเพนซอร์ส 100%"
        ),
        "seed_pill_02" to mapOf(
            "zh-Hant" to "零廣告無廠商鎖定",
            "en" to "No ads, no lock-in",
            "zh-Hans" to "零广告无厂商锁定",
            "ja" to "広告なし・ロックインなし",
            "ko" to "광고 없음, 종속 없음",
            "th" to "ไม่มีโฆษณา ไม่ผูกมัด"
        ),
        "seed_pill_03" to mapOf(
            "zh-Hant" to "次世代多維思考架構",
            "en" to "Next-gen way to think",
            "zh-Hans" to "次世代多维思考架构",
            "ja" to "次世代の思考スタイル",
            "ko" to "차세대 사고 구조",
            "th" to "แนวคิดยุคใหม่หลายมิติ"
        ),
        "seed_pill_04" to mapOf(
            "zh-Hant" to "原生高效向量核心",
            "en" to "Fast native vector core",
            "zh-Hans" to "原生高效矢量核心",
            "ja" to "高速ネイティブ描画",
            "ko" to "빠른 네이티브 벡터 코어",
            "th" to "แกนเวกเตอร์เนทีฟเร็วแรง"
        ),
        "seed_pill_05" to mapOf(
            "zh-Hant" to "16 種物理級筆刷",
            "en" to "16 realistic brushes",
            "zh-Hans" to "16 种物理级笔刷",
            "ja" to "リアルなブラシ 16 種",
            "ko" to "사실적인 브러시 16종",
            "th" to "แปรงสมจริง 16 แบบ"
        ),
        "seed_pill_06" to mapOf(
            "zh-Hant" to "真實壓感與毛筆提按",
            "en" to "True pressure & brush feel",
            "zh-Hans" to "真实压感与毛笔提按",
            "ja" to "本物の筆圧と筆の運び",
            "ko" to "실제 필압과 붓 터치",
            "th" to "แรงกดจริงและสัมผัสพู่กัน"
        ),
        "seed_pill_07" to mapOf(
            "zh-Hant" to "互動考點遮蔽膠帶",
            "en" to "Study masking tape",
            "zh-Hans" to "互动考点遮蔽胶带",
            "ja" to "暗記用マスキングテープ",
            "ko" to "암기용 마스킹 테이프",
            "th" to "เทปปิดคำตอบสำหรับท่องจำ"
        ),
        "seed_pill_08" to mapOf(
            "zh-Hant" to "尺規與套索精準幾何",
            "en" to "Precise ruler & lasso",
            "zh-Hans" to "尺规与套索精准几何",
            "ja" to "定規と投げ縄で正確に",
            "ko" to "자와 올가미로 정밀하게",
            "th" to "ไม้บรรทัดและบ่วงบาศแม่นยำ"
        ),
        "seed_pill_09" to mapOf(
            "zh-Hant" to "桌面級專業排版",
            "en" to "Desktop-grade layout",
            "zh-Hans" to "桌面级专业排版",
            "ja" to "デスクトップ級のレイアウト",
            "ko" to "데스크톱급 편집",
            "th" to "จัดหน้าระดับมืออาชีพ"
        ),
        "seed_pill_10" to mapOf(
            "zh-Hant" to "原生高格自適應表",
            "en" to "Adaptive native tables",
            "zh-Hans" to "原生高格自适应表",
            "ja" to "自動調整できる表",
            "ko" to "자동 조정되는 표",
            "th" to "ตารางที่ปรับอัตโนมัติ"
        ),
        "seed_pill_11" to mapOf(
            "zh-Hant" to "智慧拓撲流程圖",
            "en" to "Smart flowcharts",
            "zh-Hans" to "智能拓扑流程图",
            "ja" to "スマートなフローチャート",
            "ko" to "스마트 순서도",
            "th" to "ผังงานอัจฉริยะ"
        ),
        "seed_pill_12" to mapOf(
            "zh-Hant" to "3D 與音訊多媒體",
            "en" to "3D & audio media",
            "zh-Hans" to "3D 与音频多媒体",
            "ja" to "3D とオーディオ",
            "ko" to "3D와 오디오",
            "th" to "3 มิติและเสียง"
        ),
        "seed_pill_13" to mapOf(
            "zh-Hant" to "STEM 微積分深度解析",
            "en" to "In-depth STEM calculus",
            "zh-Hans" to "STEM 微积分深度解析",
            "ja" to "STEM 微積分を深く解説",
            "ko" to "STEM 미적분 심층 해설",
            "th" to "แคลคูลัส STEM เชิงลึก"
        ),
        "seed_pill_14" to mapOf(
            "zh-Hant" to "動態可編修圖表工坊",
            "en" to "Live editable charts",
            "zh-Hans" to "动态可编辑图表工坊",
            "ja" to "編集できるライブチャート",
            "ko" to "편집 가능한 실시간 차트",
            "th" to "แผนภูมิแก้ไขได้สด"
        ),
        "seed_pill_15" to mapOf(
            "zh-Hant" to "空間討論圖釘協作",
            "en" to "Pin-based discussion",
            "zh-Hans" to "空间讨论图钉协作",
            "ja" to "ピンで議論・共同作業",
            "ko" to "핀으로 토론·협업",
            "th" to "พูดคุยด้วยหมุด"
        ),
        "seed_pill_16" to mapOf(
            "zh-Hant" to "終極無界數位紙張",
            "en" to "Boundless digital paper",
            "zh-Hans" to "终极无界数字纸张",
            "ja" to "無限に広がるデジタル紙",
            "ko" to "끝없는 디지털 종이",
            "th" to "กระดาษดิจิทัลไร้ขอบเขต"
        ),
        "seed_welcome_snippet" to mapOf(
            "zh-Hant" to "點擊進入畫布即可隨心手寫、繪製圖形、插入錄音並導出 PDF",
            "en" to "Open the canvas to handwrite, draw, record audio and export to PDF",
            "zh-Hans" to "点击进入画布即可随心手写、绘制图形、插入录音并导出 PDF",
            "ja" to "キャンバスを開いて手書き、作図、録音、PDF 書き出しができます",
            "ko" to "캔버스를 열어 손글씨, 도형, 녹음, PDF 내보내기를 사용해 보세요",
            "th" to "เปิดผืนผ้าใบเพื่อเขียนด้วยลายมือ วาดรูป บันทึกเสียง และส่งออกเป็น PDF"
        ),
        "seed_welcome_title" to mapOf(
            "zh-Hant" to "歡迎使用 Kairumo",
            "en" to "Welcome to Kairumo",
            "zh-Hans" to "欢迎使用 Kairumo",
            "ja" to "Kairumo へようこそ",
            "ko" to "Kairumo에 오신 것을 환영합니다",
            "th" to "ยินดีต้อนรับสู่ Kairumo"
        ),
        "select_all" to mapOf(
            "zh-Hant" to "全選",
            "en" to "Select All",
            "zh-Hans" to "全选",
            "ja" to "すべて選択",
            "ko" to "전체 선택",
            "th" to "เลือกทั้งหมด"
        ),
        "select_destination_folder" to mapOf(
            "zh-Hant" to "選擇目標資料夾",
            "en" to "Select Target Folder",
            "zh-Hans" to "选择目标文件夹",
            "ja" to "移動先フォルダを選択",
            "ko" to "대상 폴더 선택",
            "th" to "เลือกโฟลเดอร์ปลายทาง"
        ),
        "select_language" to mapOf(
            "zh-Hant" to "選擇介面語言",
            "en" to "Select Language",
            "zh-Hans" to "选择界面语言",
            "ja" to "言語を選択",
            "ko" to "언어 선택",
            "th" to "เลือกภาษา"
        ),
        "select_pages" to mapOf(
            "zh-Hant" to "選取頁面",
            "en" to "Select Pages",
            "zh-Hans" to "选取页面",
            "ja" to "ページを選択",
            "ko" to "페이지 선택",
            "th" to "เลือกหน้า"
        ),
        "select_template" to mapOf(
            "zh-Hant" to "筆記頁樣板",
            "en" to "Page Templates",
            "zh-Hans" to "笔记页样板",
            "ja" to "ページテンプレート",
            "ko" to "페이지 템플릿",
            "th" to "เทมเพลตหน้า"
        ),
        "selected" to mapOf(
            "zh-Hant" to "已選取",
            "en" to "Selected",
            "zh-Hans" to "已选取",
            "ja" to "選択中",
            "ko" to "선택됨",
            "th" to "เลือกอยู่"
        ),
        "selfcheck_copy" to mapOf(
            "zh-Hant" to "複製報告",
            "en" to "Copy report",
            "zh-Hans" to "复制报告",
            "ja" to "レポートをコピー",
            "ko" to "보고서 복사",
            "th" to "คัดลอกรายงาน"
        ),
        "selfcheck_run" to mapOf(
            "zh-Hant" to "執行自檢",
            "en" to "Run self-check",
            "zh-Hans" to "运行自检",
            "ja" to "セルフチェックを実行",
            "ko" to "자가 점검 실행",
            "th" to "เริ่มตรวจสอบ"
        ),
        "selfcheck_running" to mapOf(
            "zh-Hant" to "檢查中…",
            "en" to "Checking…",
            "zh-Hans" to "检查中…",
            "ja" to "確認中…",
            "ko" to "점검 중…",
            "th" to "กำลังตรวจสอบ…"
        ),
        "selfcheck_title" to mapOf(
            "zh-Hant" to "裝置自檢",
            "en" to "Device self-check",
            "zh-Hans" to "设备自检",
            "ja" to "端末セルフチェック",
            "ko" to "기기 자가 점검",
            "th" to "ตรวจสอบอุปกรณ์"
        ),
        "settings" to mapOf(
            "zh-Hant" to "設定",
            "en" to "Settings",
            "zh-Hans" to "设置",
            "ja" to "設定",
            "ko" to "설정",
            "th" to "การตั้งค่า"
        ),
        "shape_change_kind" to mapOf(
            "zh-Hant" to "形狀種類",
            "en" to "Shape type",
            "zh-Hans" to "形状种类",
            "ja" to "図形の種類",
            "ko" to "도형 종류",
            "th" to "ชนิดรูปร่าง"
        ),
        "shape_corner" to mapOf(
            "zh-Hant" to "圓角",
            "en" to "Corner radius",
            "zh-Hans" to "圆角",
            "ja" to "角丸",
            "ko" to "모서리 반경",
            "th" to "รัศมีมุม"
        ),
        "shape_depth" to mapOf(
            "zh-Hant" to "深度",
            "en" to "Depth",
            "zh-Hans" to "深度",
            "ja" to "奥行き",
            "ko" to "깊이",
            "th" to "ความลึก"
        ),
        "shape_duplicate" to mapOf(
            "zh-Hant" to "複製",
            "en" to "Duplicate",
            "zh-Hans" to "复制",
            "ja" to "複製",
            "ko" to "복제",
            "th" to "ทำสำเนา"
        ),
        "shape_edit" to mapOf(
            "zh-Hant" to "編修形狀",
            "en" to "Edit Shape",
            "zh-Hans" to "编辑形状",
            "ja" to "図形を編集",
            "ko" to "도형 편집",
            "th" to "แก้ไขรูปร่าง"
        ),
        "shape_fill" to mapOf(
            "zh-Hant" to "填滿顏色",
            "en" to "Fill",
            "zh-Hans" to "填充颜色",
            "ja" to "塗りつぶし",
            "ko" to "채우기",
            "th" to "สีพื้น"
        ),
        "shape_flowchart_hint" to mapOf(
            "zh-Hant" to "點選形狀後，從四邊的「+」拖到另一個形狀即可連線",
            "en" to "Select a shape, then drag from a “+” on its edge to another shape to connect them",
            "zh-Hans" to "选中形状后，从四边的“+”拖到另一个形状即可连线",
            "ja" to "図形を選び、辺の「+」から別の図形へドラッグすると接続できます",
            "ko" to "도형을 선택한 뒤 가장자리의 “+”에서 다른 도형으로 드래그하면 연결됩니다",
            "th" to "เลือกรูปร่าง แล้วลากจาก “+” ที่ขอบไปยังรูปร่างอื่นเพื่อเชื่อมต่อ"
        ),
        "shape_geometry_section" to mapOf(
            "zh-Hant" to "位置與大小",
            "en" to "Position & size",
            "zh-Hans" to "位置与大小",
            "ja" to "位置とサイズ",
            "ko" to "위치 및 크기",
            "th" to "ตำแหน่งและขนาด"
        ),
        "shape_height" to mapOf(
            "zh-Hant" to "高",
            "en" to "Height",
            "zh-Hans" to "高",
            "ja" to "高さ",
            "ko" to "높이",
            "th" to "สูง"
        ),
        "shape_kind_alternateprocess" to mapOf(
            "zh-Hant" to "替代處理",
            "en" to "Alternate process",
            "zh-Hans" to "替代处理",
            "ja" to "代替処理",
            "ko" to "대체 처리",
            "th" to "กระบวนการทางเลือก"
        ),
        "shape_kind_annotation" to mapOf(
            "zh-Hant" to "註解",
            "en" to "Annotation",
            "zh-Hans" to "注释",
            "ja" to "注釈",
            "ko" to "주석",
            "th" to "หมายเหตุ"
        ),
        "shape_kind_arrow" to mapOf(
            "zh-Hant" to "箭頭",
            "en" to "Arrow",
            "zh-Hans" to "箭头",
            "ja" to "矢印",
            "ko" to "화살표",
            "th" to "ลูกศร"
        ),
        "shape_kind_arrowblockdown" to mapOf(
            "zh-Hant" to "下箭頭",
            "en" to "Down arrow",
            "zh-Hans" to "下箭头",
            "ja" to "下矢印",
            "ko" to "아래쪽 화살표",
            "th" to "ลูกศรลง"
        ),
        "shape_kind_arrowblockleft" to mapOf(
            "zh-Hant" to "左箭頭",
            "en" to "Left arrow",
            "zh-Hans" to "左箭头",
            "ja" to "左矢印",
            "ko" to "왼쪽 화살표",
            "th" to "ลูกศรซ้าย"
        ),
        "shape_kind_arrowblockright" to mapOf(
            "zh-Hant" to "右箭頭",
            "en" to "Right arrow",
            "zh-Hans" to "右箭头",
            "ja" to "右矢印",
            "ko" to "오른쪽 화살표",
            "th" to "ลูกศรขวา"
        )
    )

    private fun part23(): Map<String, Map<String, String>> = mapOf(
        "shape_kind_arrowblockup" to mapOf(
            "zh-Hant" to "上箭頭",
            "en" to "Up arrow",
            "zh-Hans" to "上箭头",
            "ja" to "上矢印",
            "ko" to "위쪽 화살표",
            "th" to "ลูกศรขึ้น"
        ),
        "shape_kind_banner" to mapOf(
            "zh-Hant" to "旗幟",
            "en" to "Banner",
            "zh-Hans" to "旗帜",
            "ja" to "バナー",
            "ko" to "배너",
            "th" to "แบนเนอร์"
        ),
        "shape_kind_bolt" to mapOf(
            "zh-Hant" to "閃電",
            "en" to "Lightning bolt",
            "zh-Hans" to "闪电",
            "ja" to "稲妻",
            "ko" to "번개",
            "th" to "สายฟ้า"
        ),
        "shape_kind_chevron" to mapOf(
            "zh-Hant" to "箭號",
            "en" to "Chevron",
            "zh-Hans" to "箭号",
            "ja" to "山形",
            "ko" to "갈매기형",
            "th" to "ลูกศรเชฟรอน"
        ),
        "shape_kind_cloud" to mapOf(
            "zh-Hant" to "雲朵",
            "en" to "Cloud",
            "zh-Hans" to "云朵",
            "ja" to "雲",
            "ko" to "구름",
            "th" to "เมฆ"
        ),
        "shape_kind_collate" to mapOf(
            "zh-Hant" to "對照",
            "en" to "Collate",
            "zh-Hans" to "对照",
            "ja" to "照合",
            "ko" to "대조",
            "th" to "เรียงเทียบ"
        ),
        "shape_kind_communicationlink" to mapOf(
            "zh-Hant" to "通訊連結",
            "en" to "Communication link",
            "zh-Hans" to "通信链路",
            "ja" to "通信リンク",
            "ko" to "통신 링크",
            "th" to "การเชื่อมต่อสื่อสาร"
        ),
        "shape_kind_cone" to mapOf(
            "zh-Hant" to "圓錐體",
            "en" to "Cone",
            "zh-Hans" to "圆锥体",
            "ja" to "円錐",
            "ko" to "원뿔",
            "th" to "กรวย"
        ),
        "shape_kind_connector" to mapOf(
            "zh-Hant" to "連接點",
            "en" to "Connector",
            "zh-Hans" to "连接点",
            "ja" to "結合子",
            "ko" to "연결점",
            "th" to "จุดเชื่อม"
        ),
        "shape_kind_cross" to mapOf(
            "zh-Hant" to "十字",
            "en" to "Cross",
            "zh-Hans" to "十字",
            "ja" to "十字",
            "ko" to "십자",
            "th" to "กากบาท"
        ),
        "shape_kind_cube" to mapOf(
            "zh-Hant" to "立方體",
            "en" to "Cube",
            "zh-Hans" to "立方体",
            "ja" to "立方体",
            "ko" to "정육면체",
            "th" to "ลูกบาศก์"
        ),
        "shape_kind_cylinder" to mapOf(
            "zh-Hant" to "圓柱體",
            "en" to "Cylinder",
            "zh-Hans" to "圆柱体",
            "ja" to "円柱",
            "ko" to "원기둥",
            "th" to "ทรงกระบอก"
        ),
        "shape_kind_data" to mapOf(
            "zh-Hant" to "資料",
            "en" to "Data",
            "zh-Hans" to "资料",
            "ja" to "データ",
            "ko" to "데이터",
            "th" to "ข้อมูล"
        ),
        "shape_kind_database" to mapOf(
            "zh-Hant" to "資料庫",
            "en" to "Database",
            "zh-Hans" to "数据库",
            "ja" to "データベース",
            "ko" to "데이터베이스",
            "th" to "ฐานข้อมูล"
        ),
        "shape_kind_decision" to mapOf(
            "zh-Hant" to "判斷",
            "en" to "Decision",
            "zh-Hans" to "判断",
            "ja" to "判断",
            "ko" to "판단",
            "th" to "การตัดสินใจ"
        ),
        "shape_kind_delay" to mapOf(
            "zh-Hant" to "延遲",
            "en" to "Delay",
            "zh-Hans" to "延迟",
            "ja" to "遅延",
            "ko" to "지연",
            "th" to "หน่วงเวลา"
        ),
        "shape_kind_diamond" to mapOf(
            "zh-Hant" to "菱形",
            "en" to "Diamond",
            "zh-Hans" to "菱形",
            "ja" to "ひし形",
            "ko" to "마름모",
            "th" to "ข้าวหลามตัด"
        ),
        "shape_kind_directaccessstorage" to mapOf(
            "zh-Hant" to "直接存取儲存",
            "en" to "Direct access storage",
            "zh-Hans" to "直接存取存储",
            "ja" to "直接アクセス記憶",
            "ko" to "직접 접근 저장소",
            "th" to "ที่เก็บแบบเข้าถึงโดยตรง"
        ),
        "shape_kind_display" to mapOf(
            "zh-Hant" to "顯示",
            "en" to "Display",
            "zh-Hans" to "显示",
            "ja" to "表示",
            "ko" to "표시",
            "th" to "แสดงผล"
        ),
        "shape_kind_document" to mapOf(
            "zh-Hant" to "文件",
            "en" to "Document",
            "zh-Hans" to "文件",
            "ja" to "文書",
            "ko" to "문서",
            "th" to "เอกสาร"
        ),
        "shape_kind_doublearrow" to mapOf(
            "zh-Hant" to "雙箭頭",
            "en" to "Double arrow",
            "zh-Hans" to "双箭头",
            "ja" to "両矢印",
            "ko" to "양방향 화살표",
            "th" to "ลูกศรสองหัว"
        ),
        "shape_kind_ellipse" to mapOf(
            "zh-Hant" to "橢圓",
            "en" to "Ellipse",
            "zh-Hans" to "椭圆",
            "ja" to "楕円",
            "ko" to "타원",
            "th" to "วงรี"
        ),
        "shape_kind_extract" to mapOf(
            "zh-Hant" to "抽取",
            "en" to "Extract",
            "zh-Hans" to "抽取",
            "ja" to "抽出",
            "ko" to "추출",
            "th" to "แยก"
        ),
        "shape_kind_heart" to mapOf(
            "zh-Hant" to "心形",
            "en" to "Heart",
            "zh-Hans" to "心形",
            "ja" to "ハート",
            "ko" to "하트",
            "th" to "หัวใจ"
        ),
        "shape_kind_hemisphere" to mapOf(
            "zh-Hant" to "半球",
            "en" to "Hemisphere",
            "zh-Hans" to "半球",
            "ja" to "半球",
            "ko" to "반구",
            "th" to "ซีกโลก"
        ),
        "shape_kind_heptagon" to mapOf(
            "zh-Hant" to "七邊形",
            "en" to "Heptagon",
            "zh-Hans" to "七边形",
            "ja" to "七角形",
            "ko" to "칠각형",
            "th" to "เจ็ดเหลี่ยม"
        ),
        "shape_kind_hexagon" to mapOf(
            "zh-Hant" to "六邊形",
            "en" to "Hexagon",
            "zh-Hans" to "六边形",
            "ja" to "六角形",
            "ko" to "육각형",
            "th" to "หกเหลี่ยม"
        ),
        "shape_kind_internalstorage" to mapOf(
            "zh-Hant" to "內部儲存",
            "en" to "Internal storage",
            "zh-Hans" to "内部存储",
            "ja" to "内部記憶",
            "ko" to "내부 저장소",
            "th" to "ที่เก็บภายใน"
        ),
        "shape_kind_line" to mapOf(
            "zh-Hant" to "直線",
            "en" to "Line",
            "zh-Hans" to "直线",
            "ja" to "直線",
            "ko" to "직선",
            "th" to "เส้นตรง"
        ),
        "shape_kind_looplimitend" to mapOf(
            "zh-Hant" to "迴圈結束",
            "en" to "Loop limit (end)",
            "zh-Hans" to "循环结束",
            "ja" to "ループ終了",
            "ko" to "반복 종료",
            "th" to "สิ้นสุดลูป"
        ),
        "shape_kind_looplimitstart" to mapOf(
            "zh-Hant" to "迴圈開始",
            "en" to "Loop limit (start)",
            "zh-Hans" to "循环开始",
            "ja" to "ループ開始",
            "ko" to "반복 시작",
            "th" to "เริ่มลูป"
        ),
        "shape_kind_lshape" to mapOf(
            "zh-Hant" to "L 形",
            "en" to "L-shape",
            "zh-Hans" to "L 形",
            "ja" to "L字形",
            "ko" to "L자형",
            "th" to "รูปตัวแอล"
        ),
        "shape_kind_manualinput" to mapOf(
            "zh-Hant" to "人工輸入",
            "en" to "Manual input",
            "zh-Hans" to "人工输入",
            "ja" to "手入力",
            "ko" to "수동 입력",
            "th" to "ป้อนด้วยมือ"
        ),
        "shape_kind_manualoperation" to mapOf(
            "zh-Hant" to "人工作業",
            "en" to "Manual operation",
            "zh-Hans" to "人工作业",
            "ja" to "手作業",
            "ko" to "수동 작업",
            "th" to "งานที่ทำด้วยมือ"
        ),
        "shape_kind_merge" to mapOf(
            "zh-Hant" to "彙整",
            "en" to "Merge",
            "zh-Hans" to "汇整",
            "ja" to "併合",
            "ko" to "병합",
            "th" to "รวม"
        ),
        "shape_kind_moon" to mapOf(
            "zh-Hant" to "月牙",
            "en" to "Moon",
            "zh-Hans" to "月牙",
            "ja" to "月",
            "ko" to "달",
            "th" to "พระจันทร์เสี้ยว"
        ),
        "shape_kind_multidocument" to mapOf(
            "zh-Hant" to "多份文件",
            "en" to "Multiple documents",
            "zh-Hans" to "多份文档",
            "ja" to "複数書類",
            "ko" to "다중 문서",
            "th" to "เอกสารหลายฉบับ"
        ),
        "shape_kind_octagon" to mapOf(
            "zh-Hant" to "八邊形",
            "en" to "Octagon",
            "zh-Hans" to "八边形",
            "ja" to "八角形",
            "ko" to "팔각형",
            "th" to "แปดเหลี่ยม"
        ),
        "shape_kind_offlinestorage" to mapOf(
            "zh-Hant" to "離線儲存",
            "en" to "Offline storage",
            "zh-Hans" to "离线存储",
            "ja" to "オフライン記憶",
            "ko" to "오프라인 저장소",
            "th" to "ที่เก็บออฟไลน์"
        ),
        "shape_kind_offpageconnector" to mapOf(
            "zh-Hant" to "跨頁連接",
            "en" to "Off-page connector",
            "zh-Hans" to "跨页连接",
            "ja" to "他ページ結合子",
            "ko" to "페이지 간 연결",
            "th" to "เชื่อมข้ามหน้า"
        ),
        "shape_kind_orjunction" to mapOf(
            "zh-Hant" to "或（OR）接點",
            "en" to "OR junction",
            "zh-Hans" to "或（OR）接点",
            "ja" to "OR接合",
            "ko" to "OR 접합",
            "th" to "จุดเชื่อม OR"
        ),
        "shape_kind_parallelmode" to mapOf(
            "zh-Hant" to "平行模式",
            "en" to "Parallel mode",
            "zh-Hans" to "并行模式",
            "ja" to "並列モード",
            "ko" to "병렬 모드",
            "th" to "โหมดขนาน"
        ),
        "shape_kind_parallelogram" to mapOf(
            "zh-Hant" to "平行四邊形",
            "en" to "Parallelogram",
            "zh-Hans" to "平行四边形",
            "ja" to "平行四辺形",
            "ko" to "평행사변형",
            "th" to "สี่เหลี่ยมด้านขนาน"
        ),
        "shape_kind_pentagon" to mapOf(
            "zh-Hant" to "五邊形",
            "en" to "Pentagon",
            "zh-Hans" to "五边形",
            "ja" to "五角形",
            "ko" to "오각형",
            "th" to "ห้าเหลี่ยม"
        ),
        "shape_kind_pie" to mapOf(
            "zh-Hant" to "扇形",
            "en" to "Pie",
            "zh-Hans" to "扇形",
            "ja" to "扇形",
            "ko" to "부채꼴",
            "th" to "รูปพาย"
        ),
        "shape_kind_plaque" to mapOf(
            "zh-Hant" to "匾額",
            "en" to "Plaque",
            "zh-Hans" to "匾额",
            "ja" to "プレート",
            "ko" to "명판",
            "th" to "แผ่นป้าย"
        ),
        "shape_kind_predefinedprocess" to mapOf(
            "zh-Hant" to "預先定義的處理",
            "en" to "Predefined process",
            "zh-Hans" to "预定义处理",
            "ja" to "定義済み処理",
            "ko" to "정의된 처리",
            "th" to "กระบวนการที่กำหนดไว้ล่วงหน้า"
        ),
        "shape_kind_preparation" to mapOf(
            "zh-Hant" to "預備",
            "en" to "Preparation",
            "zh-Hans" to "预备",
            "ja" to "準備",
            "ko" to "준비",
            "th" to "การเตรียม"
        ),
        "shape_kind_process" to mapOf(
            "zh-Hant" to "處理",
            "en" to "Process",
            "zh-Hans" to "处理",
            "ja" to "処理",
            "ko" to "처리",
            "th" to "กระบวนการ"
        ),
        "shape_kind_punchedcard" to mapOf(
            "zh-Hant" to "打孔卡",
            "en" to "Punched card",
            "zh-Hans" to "打孔卡",
            "ja" to "パンチカード",
            "ko" to "천공 카드",
            "th" to "บัตรเจาะรู"
        ),
        "shape_kind_punchedtape" to mapOf(
            "zh-Hant" to "打孔紙帶",
            "en" to "Punched tape",
            "zh-Hans" to "打孔纸带",
            "ja" to "紙テープ",
            "ko" to "천공 테이프",
            "th" to "เทปเจาะรู"
        ),
        "shape_kind_pyramid" to mapOf(
            "zh-Hant" to "角錐",
            "en" to "Pyramid",
            "zh-Hans" to "棱锥",
            "ja" to "角錐",
            "ko" to "각뿔",
            "th" to "พีระมิด"
        ),
        "shape_kind_rectangle" to mapOf(
            "zh-Hant" to "矩形",
            "en" to "Rectangle",
            "zh-Hans" to "矩形",
            "ja" to "長方形",
            "ko" to "직사각형",
            "th" to "สี่เหลี่ยมผืนผ้า"
        ),
        "shape_kind_righttriangle" to mapOf(
            "zh-Hant" to "直角三角形",
            "en" to "Right triangle",
            "zh-Hans" to "直角三角形",
            "ja" to "直角三角形",
            "ko" to "직각삼각형",
            "th" to "สามเหลี่ยมมุมฉาก"
        ),
        "shape_kind_roundedrectangle" to mapOf(
            "zh-Hant" to "圓角矩形",
            "en" to "Rounded rectangle",
            "zh-Hans" to "圆角矩形",
            "ja" to "角丸長方形",
            "ko" to "둥근 직사각형",
            "th" to "สี่เหลี่ยมมุมมน"
        ),
        "shape_kind_sequentialaccessstorage" to mapOf(
            "zh-Hant" to "循序存取儲存",
            "en" to "Sequential access storage",
            "zh-Hans" to "顺序存取存储",
            "ja" to "順次アクセス記憶",
            "ko" to "순차 접근 저장소",
            "th" to "ที่เก็บแบบเข้าถึงตามลำดับ"
        ),
        "shape_kind_sort" to mapOf(
            "zh-Hant" to "排序",
            "en" to "Sort",
            "zh-Hans" to "排序",
            "ja" to "並べ替え",
            "ko" to "정렬",
            "th" to "เรียงลำดับ"
        ),
        "shape_kind_speechbubble" to mapOf(
            "zh-Hant" to "對話框",
            "en" to "Speech bubble",
            "zh-Hans" to "对话框",
            "ja" to "吹き出し",
            "ko" to "말풍선",
            "th" to "กรอบคำพูด"
        ),
        "shape_kind_sphere" to mapOf(
            "zh-Hant" to "球體",
            "en" to "Sphere",
            "zh-Hans" to "球体",
            "ja" to "球",
            "ko" to "구",
            "th" to "ทรงกลม"
        ),
        "shape_kind_star" to mapOf(
            "zh-Hant" to "五角星",
            "en" to "Star",
            "zh-Hans" to "五角星",
            "ja" to "星",
            "ko" to "별",
            "th" to "ดาว"
        ),
        "shape_kind_star4" to mapOf(
            "zh-Hant" to "四角星",
            "en" to "4-point star",
            "zh-Hans" to "四角星",
            "ja" to "4光星",
            "ko" to "4각 별",
            "th" to "ดาวสี่แฉก"
        ),
        "shape_kind_star6" to mapOf(
            "zh-Hant" to "六角星",
            "en" to "6-point star",
            "zh-Hans" to "六角星",
            "ja" to "6光星",
            "ko" to "6각 별",
            "th" to "ดาวหกแฉก"
        ),
        "shape_kind_star8" to mapOf(
            "zh-Hant" to "八角星",
            "en" to "8-point star",
            "zh-Hans" to "八角星",
            "ja" to "8光星",
            "ko" to "8각 별",
            "th" to "ดาวแปดแฉก"
        ),
        "shape_kind_storeddata" to mapOf(
            "zh-Hant" to "已儲存資料",
            "en" to "Stored data",
            "zh-Hans" to "已存储数据",
            "ja" to "保存データ",
            "ko" to "저장된 데이터",
            "th" to "ข้อมูลที่เก็บไว้"
        ),
        "shape_kind_summingjunction" to mapOf(
            "zh-Hant" to "加總接點",
            "en" to "Summing junction",
            "zh-Hans" to "汇总接点",
            "ja" to "和接合",
            "ko" to "합산 접합",
            "th" to "จุดรวมผลรวม"
        ),
        "shape_kind_sun" to mapOf(
            "zh-Hant" to "太陽",
            "en" to "Sun",
            "zh-Hans" to "太阳",
            "ja" to "太陽",
            "ko" to "해",
            "th" to "ดวงอาทิตย์"
        ),
        "shape_kind_teardrop" to mapOf(
            "zh-Hant" to "水滴",
            "en" to "Teardrop",
            "zh-Hans" to "水滴",
            "ja" to "しずく",
            "ko" to "물방울",
            "th" to "หยดน้ำ"
        ),
        "shape_kind_terminator" to mapOf(
            "zh-Hant" to "起終點",
            "en" to "Terminator",
            "zh-Hans" to "起终点",
            "ja" to "開始／終了",
            "ko" to "시작·종료",
            "th" to "จุดเริ่ม/จบ"
        ),
        "shape_kind_tetrahedron" to mapOf(
            "zh-Hant" to "四面體",
            "en" to "Tetrahedron",
            "zh-Hans" to "四面体",
            "ja" to "正四面体",
            "ko" to "사면체",
            "th" to "จัตุรมุข"
        ),
        "shape_kind_torus" to mapOf(
            "zh-Hant" to "圓環體",
            "en" to "Torus",
            "zh-Hans" to "圆环体",
            "ja" to "トーラス",
            "ko" to "토러스",
            "th" to "ทอรัส"
        ),
        "shape_kind_trapezoid" to mapOf(
            "zh-Hant" to "梯形",
            "en" to "Trapezoid",
            "zh-Hans" to "梯形",
            "ja" to "台形",
            "ko" to "사다리꼴",
            "th" to "สี่เหลี่ยมคางหมู"
        ),
        "shape_kind_triangle" to mapOf(
            "zh-Hant" to "三角形",
            "en" to "Triangle",
            "zh-Hans" to "三角形",
            "ja" to "三角形",
            "ko" to "삼각형",
            "th" to "สามเหลี่ยม"
        ),
        "shape_kind_triangularprism" to mapOf(
            "zh-Hant" to "三角柱",
            "en" to "Triangular prism",
            "zh-Hans" to "三棱柱",
            "ja" to "三角柱",
            "ko" to "삼각기둥",
            "th" to "ปริซึมสามเหลี่ยม"
        ),
        "shape_label" to mapOf(
            "zh-Hant" to "標籤文字",
            "en" to "Label",
            "zh-Hans" to "标签文字",
            "ja" to "ラベル",
            "ko" to "레이블",
            "th" to "ป้ายกำกับ"
        ),
        "shape_line_style" to mapOf(
            "zh-Hant" to "線條樣式",
            "en" to "Line style",
            "zh-Hans" to "线条样式",
            "ja" to "線のスタイル",
            "ko" to "선 스타일",
            "th" to "ลักษณะเส้น"
        ),
        "shape_line_width" to mapOf(
            "zh-Hant" to "線條粗細",
            "en" to "Line Width",
            "zh-Hans" to "线条粗细",
            "ja" to "線の太さ",
            "ko" to "선 두께",
            "th" to "ความหนาเส้น"
        ),
        "shape_node_count" to mapOf(
            "zh-Hant" to "%@ 個節點",
            "en" to "%@ nodes",
            "zh-Hans" to "%@ 个节点",
            "ja" to "%@ 個のノード",
            "ko" to "노드 %@개",
            "th" to "%@ โหนด"
        ),
        "shape_rotation" to mapOf(
            "zh-Hant" to "旋轉角度",
            "en" to "Rotation",
            "zh-Hans" to "旋转角度",
            "ja" to "回転角度",
            "ko" to "회전 각도",
            "th" to "มุมหมุน"
        ),
        "shape_section_basic" to mapOf(
            "zh-Hant" to "基本形狀",
            "en" to "Basic Shapes",
            "zh-Hans" to "基本形状",
            "ja" to "基本図形",
            "ko" to "기본 도형",
            "th" to "รูปร่างพื้นฐาน"
        ),
        "shape_section_flow_control" to mapOf(
            "zh-Hant" to "流程圖：流程控制（ISO 5807）",
            "en" to "Flowchart: Flow control (ISO 5807)",
            "zh-Hans" to "流程图：流程控制（ISO 5807）",
            "ja" to "フローチャート：フロー制御（ISO 5807）",
            "ko" to "순서도: 흐름 제어(ISO 5807)",
            "th" to "ผังงาน: การควบคุมการไหล (ISO 5807)"
        )
    )

    private fun part24(): Map<String, Map<String, String>> = mapOf(
        "shape_section_flow_data" to mapOf(
            "zh-Hant" to "流程圖：資料與儲存（ISO 5807）",
            "en" to "Flowchart: Data & storage (ISO 5807)",
            "zh-Hans" to "流程图：数据与存储（ISO 5807）",
            "ja" to "フローチャート：データと記憶（ISO 5807）",
            "ko" to "순서도: 데이터와 저장소(ISO 5807)",
            "th" to "ผังงาน: ข้อมูลและที่เก็บ (ISO 5807)"
        ),
        "shape_section_flow_process" to mapOf(
            "zh-Hant" to "流程圖：處理（ISO 5807）",
            "en" to "Flowchart: Process (ISO 5807)",
            "zh-Hans" to "流程图：处理（ISO 5807）",
            "ja" to "フローチャート：処理（ISO 5807）",
            "ko" to "순서도: 처리(ISO 5807)",
            "th" to "ผังงาน: การประมวลผล (ISO 5807)"
        ),
        "shape_section_flow_special" to mapOf(
            "zh-Hant" to "流程圖：特殊符號（ISO 5807）",
            "en" to "Flowchart: Special symbols (ISO 5807)",
            "zh-Hans" to "流程图：特殊符号（ISO 5807）",
            "ja" to "フローチャート：特殊記号（ISO 5807）",
            "ko" to "순서도: 특수 기호(ISO 5807)",
            "th" to "ผังงาน: สัญลักษณ์พิเศษ (ISO 5807)"
        ),
        "shape_section_flowchart" to mapOf(
            "zh-Hant" to "流程圖符號（ISO 5807）",
            "en" to "Flowchart Symbols (ISO 5807)",
            "zh-Hans" to "流程图符号（ISO 5807）",
            "ja" to "フローチャート記号（ISO 5807）",
            "ko" to "순서도 기호(ISO 5807)",
            "th" to "สัญลักษณ์ผังงาน (ISO 5807)"
        ),
        "shape_section_solid" to mapOf(
            "zh-Hant" to "立體圖（可調深度）",
            "en" to "Solids (3D, adjustable depth)",
            "zh-Hans" to "立体图（可调深度）",
            "ja" to "立体図形（奥行き調整可）",
            "ko" to "입체 도형(깊이 조절)",
            "th" to "รูปทรง 3 มิติ (ปรับความลึกได้)"
        ),
        "shape_section_templates" to mapOf(
            "zh-Hant" to "範本",
            "en" to "Templates",
            "zh-Hans" to "模板",
            "ja" to "テンプレート",
            "ko" to "템플릿",
            "th" to "แม่แบบ"
        ),
        "shape_stroke" to mapOf(
            "zh-Hant" to "線條顏色",
            "en" to "Stroke",
            "zh-Hans" to "线条颜色",
            "ja" to "線の色",
            "ko" to "선 색상",
            "th" to "สีเส้น"
        ),
        "shape_studio" to mapOf(
            "zh-Hant" to "形狀與流程圖",
            "en" to "Shapes & Flowcharts",
            "zh-Hans" to "形状与流程图",
            "ja" to "図形とフローチャート",
            "ko" to "도형 및 순서도",
            "th" to "รูปร่างและผังงาน"
        ),
        "shape_style" to mapOf(
            "zh-Hant" to "形狀樣式",
            "en" to "Shape style",
            "zh-Hans" to "形状样式",
            "ja" to "図形スタイル",
            "ko" to "도형 스타일",
            "th" to "สไตล์รูปทรง"
        ),
        "shape_template_flow_approval" to mapOf(
            "zh-Hant" to "簽核審核",
            "en" to "Approval",
            "zh-Hans" to "签核审核",
            "ja" to "承認フロー",
            "ko" to "결재 승인",
            "th" to "การอนุมัติ"
        ),
        "shape_template_flow_basic" to mapOf(
            "zh-Hant" to "基本流程",
            "en" to "Basic flow",
            "zh-Hans" to "基本流程",
            "ja" to "基本フロー",
            "ko" to "기본 흐름",
            "th" to "ผังงานพื้นฐาน"
        ),
        "shape_template_flow_decision" to mapOf(
            "zh-Hant" to "判斷分支",
            "en" to "Decision branch",
            "zh-Hans" to "判断分支",
            "ja" to "判断分岐",
            "ko" to "판단 분기",
            "th" to "การตัดสินใจแตกแขนง"
        ),
        "shape_template_flow_documents" to mapOf(
            "zh-Hant" to "文件處理",
            "en" to "Document handling",
            "zh-Hans" to "文档处理",
            "ja" to "書類処理",
            "ko" to "문서 처리",
            "th" to "การจัดการเอกสาร"
        ),
        "shape_template_flow_io" to mapOf(
            "zh-Hant" to "輸入處理輸出",
            "en" to "Input, process, output",
            "zh-Hans" to "输入处理输出",
            "ja" to "入力・処理・出力",
            "ko" to "입력·처리·출력",
            "th" to "รับเข้า ประมวลผล แสดงผล"
        ),
        "shape_template_flow_login" to mapOf(
            "zh-Hant" to "登入驗證",
            "en" to "Login & authentication",
            "zh-Hans" to "登录验证",
            "ja" to "ログイン認証",
            "ko" to "로그인 인증",
            "th" to "การเข้าสู่ระบบและยืนยันตัวตน"
        ),
        "shape_template_flow_loop" to mapOf(
            "zh-Hant" to "迴圈",
            "en" to "Loop",
            "zh-Hans" to "循环",
            "ja" to "ループ",
            "ko" to "반복",
            "th" to "ลูป"
        ),
        "shape_template_flow_parallel" to mapOf(
            "zh-Hant" to "平行處理",
            "en" to "Parallel processing",
            "zh-Hans" to "并行处理",
            "ja" to "並列処理",
            "ko" to "병렬 처리",
            "th" to "การประมวลผลแบบขนาน"
        ),
        "shape_template_flow_pipeline" to mapOf(
            "zh-Hant" to "資料處理管線",
            "en" to "Data pipeline (ETL)",
            "zh-Hans" to "数据处理管线",
            "ja" to "データパイプライン",
            "ko" to "데이터 파이프라인",
            "th" to "ไปป์ไลน์ข้อมูล"
        ),
        "shape_template_flow_retry" to mapOf(
            "zh-Hant" to "錯誤處理與重試",
            "en" to "Error handling & retry",
            "zh-Hans" to "错误处理与重试",
            "ja" to "エラー処理と再試行",
            "ko" to "오류 처리와 재시도",
            "th" to "จัดการข้อผิดพลาดและลองใหม่"
        ),
        "shape_text_section" to mapOf(
            "zh-Hant" to "文字",
            "en" to "Text",
            "zh-Hans" to "文字",
            "ja" to "テキスト",
            "ko" to "텍스트",
            "th" to "ข้อความ"
        ),
        "shape_width" to mapOf(
            "zh-Hant" to "寬",
            "en" to "Width",
            "zh-Hans" to "宽",
            "ja" to "幅",
            "ko" to "너비",
            "th" to "กว้าง"
        ),
        "share_invite_link" to mapOf(
            "zh-Hant" to "分享邀請連結",
            "en" to "Share Invite Link",
            "zh-Hans" to "分享邀请链接",
            "ja" to "招待リンクを共有",
            "ko" to "초대 링크 공유",
            "th" to "แชร์ลิงก์คำเชิญ"
        ),
        "share_note" to mapOf(
            "zh-Hant" to "分享筆記",
            "en" to "Share Note",
            "zh-Hans" to "分享笔记",
            "ja" to "ノートを共有",
            "ko" to "노트 공유",
            "th" to "แชร์บันทึก"
        ),
        "show_all" to mapOf(
            "zh-Hant" to "全部",
            "en" to "All",
            "zh-Hans" to "全部",
            "ja" to "すべて",
            "ko" to "전체",
            "th" to "ทั้งหมด"
        ),
        "show_in_folder" to mapOf(
            "zh-Hant" to "在資料夾中顯示",
            "en" to "Show in Folder",
            "zh-Hans" to "在文件夹中显示",
            "ja" to "フォルダで表示",
            "ko" to "폴더에서 보기",
            "th" to "แสดงในโฟลเดอร์"
        ),
        "sign_in_google" to mapOf(
            "zh-Hant" to "連結 Google 雲端硬碟",
            "en" to "Connect Google Drive",
            "zh-Hans" to "关联 Google 云端硬盘",
            "ja" to "Google ドライブを接続",
            "ko" to "Google 드라이브 연결",
            "th" to "เชื่อมต่อ Google ไดรฟ์"
        ),
        "sign_out" to mapOf(
            "zh-Hant" to "登出",
            "en" to "Sign out",
            "zh-Hans" to "登出",
            "ja" to "ログアウト",
            "ko" to "로그아웃",
            "th" to "ออกจากระบบ"
        ),
        "signed_in" to mapOf(
            "zh-Hant" to "已登入",
            "en" to "Signed in",
            "zh-Hans" to "已登录",
            "ja" to "ログイン済み",
            "ko" to "로그인됨",
            "th" to "ลงชื่อเข้าใช้แล้ว"
        ),
        "snap_to_grid" to mapOf(
            "zh-Hant" to "吸附格線",
            "en" to "Snap to Grid",
            "zh-Hans" to "吸附格线",
            "ja" to "グリッドに吸着",
            "ko" to "격자에 맞춤",
            "th" to "จัดชิดเส้นตาราง"
        ),
        "snap_to_grid_desc" to mapOf(
            "zh-Hant" to "隨點隨寫時自動對齊頁面行線或方格",
            "en" to "Snap click-to-type text to page grid or lines",
            "zh-Hans" to "随点随写时自动对齐页面行线或方格",
            "ja" to "随時入力をページの罫線や方眼に自動吸着します",
            "ko" to "페이지의 격자나 줄에 맞춰 텍스트를 정렬합니다",
            "th" to "จัดตำแหน่งข้อความให้ชิดเส้นหรือตารางในหน้ากระดาษโดยอัตโนมัติ"
        ),
        "snap_to_grid_off_notice" to mapOf(
            "zh-Hant" to "吸附格線已關閉：文字會放在你點的位置。",
            "en" to "Snap to grid off: text is placed exactly where you tap.",
            "zh-Hans" to "吸附格线已关闭：文字会放在你点的位置。",
            "ja" to "グリッド吸着オフ：テキストはタップした位置にそのまま置かれます。",
            "ko" to "격자 맞춤 꺼짐: 텍스트가 탭한 위치에 그대로 놓입니다.",
            "th" to "ปิดจัดชิดเส้นตาราง: ข้อความจะวางตรงตำแหน่งที่แตะ"
        ),
        "snap_to_grid_on_notice" to mapOf(
            "zh-Hant" to "吸附格線已開啟：隨點隨寫的文字會對齊頁面行線或方格。",
            "en" to "Snap to grid on: tap-to-write text aligns to the page's lines or grid.",
            "zh-Hans" to "吸附格线已开启：随点随写的文字会对齐页面行线或方格。",
            "ja" to "グリッド吸着オン：タップで書くテキストがページの罫線や方眼に揃います。",
            "ko" to "격자 맞춤 켜짐: 탭해서 쓰는 텍스트가 페이지의 줄이나 격자에 맞춰집니다.",
            "th" to "เปิดจัดชิดเส้นตาราง: ข้อความที่แตะเพื่อเขียนจะชิดเส้นหรือตารางของหน้า"
        ),
        "snapshot_created" to mapOf(
            "zh-Hant" to "快照已成功建立",
            "en" to "Snapshot Created",
            "zh-Hans" to "快照已成功创建",
            "ja" to "スナップショットが作成されました",
            "ko" to "스냅샷이 생성되었습니다",
            "th" to "สร้างสแนปช็อตเรียบร้อยแล้ว"
        ),
        "snapshot_name" to mapOf(
            "zh-Hant" to "快照名稱或備註",
            "en" to "Snapshot Name",
            "zh-Hans" to "快照名称或备注",
            "ja" to "スナップショット名",
            "ko" to "스냅샷 이름",
            "th" to "ชื่อสแนปช็อต"
        ),
        "solid_angle" to mapOf(
            "zh-Hant" to "切線方向",
            "en" to "Cut direction",
            "zh-Hans" to "切线方向",
            "ja" to "切断線の向き",
            "ko" to "절단선 방향",
            "th" to "ทิศทางเส้นตัด"
        ),
        "solid_centerlines" to mapOf(
            "zh-Hant" to "中心線",
            "en" to "Center lines",
            "zh-Hans" to "中心线",
            "ja" to "中心線",
            "ko" to "중심선",
            "th" to "เส้นศูนย์กลาง"
        ),
        "solid_delta" to mapOf(
            "zh-Hant" to "第二段角度",
            "en" to "Second leg angle",
            "zh-Hans" to "第二段角度",
            "ja" to "2段目の角度",
            "ko" to "두 번째 각도",
            "th" to "มุมช่วงที่สอง"
        ),
        "solid_depth" to mapOf(
            "zh-Hant" to "深",
            "en" to "Depth",
            "zh-Hans" to "深",
            "ja" to "奥行き",
            "ko" to "깊이",
            "th" to "ลึก"
        ),
        "solid_depth_pos" to mapOf(
            "zh-Hant" to "切入深度",
            "en" to "Cut depth",
            "zh-Hans" to "切入深度",
            "ja" to "切断の深さ",
            "ko" to "절단 깊이",
            "th" to "ความลึกที่ตัด"
        ),
        "solid_dimensions" to mapOf(
            "zh-Hant" to "標註尺寸",
            "en" to "Dimensions",
            "zh-Hans" to "标注尺寸",
            "ja" to "寸法を記入",
            "ko" to "치수 기입",
            "th" to "ใส่ขนาด"
        ),
        "solid_first_angle" to mapOf(
            "zh-Hant" to "第一角法",
            "en" to "First-angle projection",
            "zh-Hans" to "第一角法",
            "ja" to "第一角法",
            "ko" to "제1각법",
            "th" to "การฉายมุมที่หนึ่ง"
        ),
        "solid_flip" to mapOf(
            "zh-Hant" to "從另一側看",
            "en" to "Look from the other side",
            "zh-Hans" to "从另一侧看",
            "ja" to "反対側から見る",
            "ko" to "반대쪽에서 보기",
            "th" to "มองจากอีกด้าน"
        ),
        "solid_from_sketch" to mapOf(
            "zh-Hant" to "使用這一頁上的封閉圖形",
            "en" to "Use the closed shapes on this page",
            "zh-Hans" to "使用这一页上的封闭图形",
            "ja" to "このページの閉じた図形を使う",
            "ko" to "이 페이지의 닫힌 도형 사용",
            "th" to "ใช้รูปปิดบนหน้านี้"
        ),
        "solid_height" to mapOf(
            "zh-Hant" to "高",
            "en" to "Height",
            "zh-Hans" to "高",
            "ja" to "高さ",
            "ko" to "높이",
            "th" to "สูง"
        ),
        "solid_insert" to mapOf(
            "zh-Hant" to "插入頁面",
            "en" to "Insert into page",
            "zh-Hans" to "插入页面",
            "ja" to "ページに挿入",
            "ko" to "페이지에 삽입",
            "th" to "แทรกลงหน้า"
        ),
        "solid_inserted" to mapOf(
            "zh-Hant" to "已插入：輪廓在頂層，投射線在中層",
            "en" to "Views inserted on the Top layer; construction lines are on the Middle layer",
            "zh-Hans" to "已插入：轮廓在顶层，投射线在中层",
            "ja" to "挿入しました：輪郭は上層、投影線は中層",
            "ko" to "삽입됨: 윤곽은 상층, 투사선은 중층",
            "th" to "แทรกแล้ว: เส้นขอบอยู่ชั้นบน เส้นโครงอยู่ชั้นกลาง"
        ),
        "solid_iso" to mapOf(
            "zh-Hant" to "等角圖",
            "en" to "Isometric view",
            "zh-Hans" to "等角图",
            "ja" to "等角図",
            "ko" to "등각도",
            "th" to "ภาพไอโซเมตริก"
        ),
        "solid_offset" to mapOf(
            "zh-Hant" to "切線位置",
            "en" to "Cut position",
            "zh-Hans" to "切线位置",
            "ja" to "切断位置",
            "ko" to "절단 위치",
            "th" to "ตำแหน่งตัด"
        ),
        "solid_offset2" to mapOf(
            "zh-Hant" to "第二段位置",
            "en" to "Second cut position",
            "zh-Hans" to "第二段位置",
            "ja" to "2段目の位置",
            "ko" to "두 번째 위치",
            "th" to "ตำแหน่งที่สอง"
        ),
        "solid_pitch" to mapOf(
            "zh-Hant" to "垂直傾斜",
            "en" to "Tilt",
            "zh-Hans" to "垂直倾斜",
            "ja" to "垂直傾斜",
            "ko" to "상하 기울기",
            "th" to "เอียงขึ้นลง"
        ),
        "solid_place_hint" to mapOf(
            "zh-Hant" to "已插入——拖曳可移動位置，點空白處完成。",
            "en" to "Inserted — drag to move it, tap empty space when done.",
            "zh-Hans" to "已插入——拖曳可移动位置，点空白处完成。",
            "ja" to "挿入しました。ドラッグで移動、空白をタップで完了。",
            "ko" to "삽입됨 — 끌어서 이동하고 빈 곳을 눌러 완료합니다.",
            "th" to "แทรกแล้ว — ลากเพื่อย้าย แตะที่ว่างเมื่อเสร็จ"
        ),
        "solid_preset_circle" to mapOf(
            "zh-Hant" to "圓形",
            "en" to "Circle",
            "zh-Hans" to "圆形",
            "ja" to "円",
            "ko" to "원",
            "th" to "วงกลม"
        ),
        "solid_preset_hexagon" to mapOf(
            "zh-Hant" to "六邊形",
            "en" to "Hexagon",
            "zh-Hans" to "六边形",
            "ja" to "六角形",
            "ko" to "육각형",
            "th" to "หกเหลี่ยม"
        ),
        "solid_preset_l_shape" to mapOf(
            "zh-Hant" to "L 形",
            "en" to "L shape",
            "zh-Hans" to "L 形",
            "ja" to "L字形",
            "ko" to "L자형",
            "th" to "รูปตัว L"
        ),
        "solid_preset_plate_holes" to mapOf(
            "zh-Hant" to "四孔板",
            "en" to "Plate with holes",
            "zh-Hans" to "四孔板",
            "ja" to "4穴プレート",
            "ko" to "4구멍 판",
            "th" to "แผ่นสี่รู"
        ),
        "solid_preset_rect" to mapOf(
            "zh-Hant" to "矩形",
            "en" to "Rectangle",
            "zh-Hans" to "矩形",
            "ja" to "長方形",
            "ko" to "직사각형",
            "th" to "สี่เหลี่ยม"
        ),
        "solid_preset_ring" to mapOf(
            "zh-Hant" to "墊圈（有孔）",
            "en" to "Washer (hole)",
            "zh-Hans" to "垫圈（有孔）",
            "ja" to "ワッシャー（穴あり）",
            "ko" to "와셔(구멍)",
            "th" to "แหวน (มีรู)"
        ),
        "solid_preset_t_shape" to mapOf(
            "zh-Hant" to "T 形",
            "en" to "T shape",
            "zh-Hans" to "T 形",
            "ja" to "T字形",
            "ko" to "T자형",
            "th" to "รูปตัว T"
        ),
        "solid_preset_u_shape" to mapOf(
            "zh-Hant" to "U 形槽",
            "en" to "U channel",
            "zh-Hans" to "U 形槽",
            "ja" to "U字溝",
            "ko" to "U자 홈",
            "th" to "รางตัว U"
        ),
        "solid_profile" to mapOf(
            "zh-Hant" to "輪廓",
            "en" to "Profile",
            "zh-Hans" to "轮廓",
            "ja" to "断面形状",
            "ko" to "단면 형상",
            "th" to "โครงร่าง"
        ),
        "solid_projection" to mapOf(
            "zh-Hant" to "投射線",
            "en" to "Projection lines",
            "zh-Hans" to "投射线",
            "ja" to "投影線",
            "ko" to "투사선",
            "th" to "เส้นโครง"
        ),
        "solid_section" to mapOf(
            "zh-Hant" to "剖面",
            "en" to "Section",
            "zh-Hans" to "剖面",
            "ja" to "断面",
            "ko" to "단면",
            "th" to "ภาพตัด"
        ),
        "solid_section_full" to mapOf(
            "zh-Hant" to "全剖面",
            "en" to "Full section",
            "zh-Hans" to "全剖面",
            "ja" to "全断面",
            "ko" to "온단면",
            "th" to "ตัดเต็ม"
        ),
        "solid_section_label" to mapOf(
            "zh-Hant" to "標示剖面（A–A）",
            "en" to "Label the section (A–A)",
            "zh-Hans" to "标示剖面（A–A）",
            "ja" to "断面を表示（A–A）",
            "ko" to "단면 표시(A–A)",
            "th" to "ระบุภาพตัด (A–A)"
        ),
        "solid_section_none" to mapOf(
            "zh-Hant" to "不剖",
            "en" to "No section",
            "zh-Hans" to "不剖",
            "ja" to "断面なし",
            "ko" to "단면 없음",
            "th" to "ไม่ตัด"
        ),
        "solid_section_parallel" to mapOf(
            "zh-Hant" to "平行正面的剖面",
            "en" to "Section parallel to the front",
            "zh-Hans" to "平行正面的剖面",
            "ja" to "正面に平行な断面",
            "ko" to "정면에 평행한 단면",
            "th" to "ตัดขนานด้านหน้า"
        ),
        "solid_section_rotated" to mapOf(
            "zh-Hant" to "旋轉剖面",
            "en" to "Rotated section",
            "zh-Hans" to "旋转剖面",
            "ja" to "回転断面",
            "ko" to "회전 단면",
            "th" to "ตัดแบบหมุน"
        ),
        "solid_section_stepped" to mapOf(
            "zh-Hant" to "階梯剖面",
            "en" to "Stepped section",
            "zh-Hans" to "阶梯剖面",
            "ja" to "階段断面",
            "ko" to "계단 단면",
            "th" to "ตัดแบบขั้นบันได"
        ),
        "solid_sketch_none" to mapOf(
            "zh-Hant" to "找不到封閉的圖形。請畫一個頭尾相接的輪廓（長按吸附的矩形或圓都可以）再試一次。",
            "en" to "No closed shape found. Draw an outline whose end meets its start (a hold-to-snap rectangle or circle works well), then try again.",
            "zh-Hans" to "找不到封闭的图形。请画一个头尾相接的轮廓（长按吸附的矩形或圆都可以）再试一次。",
            "ja" to "閉じた図形が見つかりません。始点と終点がつながる輪郭（長押しスナップの長方形や円など）を描いて再度お試しください。",
            "ko" to "닫힌 도형을 찾지 못했습니다. 시작점과 끝점이 만나는 윤곽(길게 눌러 스냅한 사각형이나 원)을 그린 뒤 다시 시도하세요.",
            "th" to "ไม่พบรูปปิด กรุณาวาดโครงร่างที่ปลายชนต้น (สี่เหลี่ยมหรือวงกลมที่กดค้างจัดรูป) แล้วลองใหม่"
        ),
        "solid_sketch_used" to mapOf(
            "zh-Hant" to "已用你的草圖拉伸",
            "en" to "Extruded from your sketch",
            "zh-Hans" to "已用你的草图拉伸",
            "ja" to "スケッチから押し出しました",
            "ko" to "스케치에서 돌출했습니다",
            "th" to "ดึงจากสเก็ตช์ของคุณแล้ว"
        ),
        "solid_step" to mapOf(
            "zh-Hant" to "轉折位置",
            "en" to "Step at",
            "zh-Hans" to "转折位置",
            "ja" to "段差の位置",
            "ko" to "꺾임 위치",
            "th" to "ตำแหน่งขั้น"
        ),
        "solid_studio" to mapOf(
            "zh-Hant" to "立體輔助",
            "en" to "Solid helper",
            "zh-Hans" to "立体辅助",
            "ja" to "立体ヘルパー",
            "ko" to "입체 도우미",
            "th" to "ตัวช่วยงานสามมิติ"
        ),
        "solid_studio_desc" to mapOf(
            "zh-Hant" to "把草圖拉伸成立體，畫出三視圖、等角圖與剖面",
            "en" to "Extrude a sketch, then draw its three views, isometric view and sections",
            "zh-Hans" to "把草图拉伸成立体，画出三视图、等角图与剖面",
            "ja" to "スケッチを押し出し、三面図・等角図・断面図を作成",
            "ko" to "스케치를 돌출시켜 3면도, 등각도, 단면도 만들기",
            "th" to "ดึงสเก็ตช์เป็นชิ้นงาน แล้ววาดสามมุมมอง ภาพไอโซเมตริก และภาพตัด"
        ),
        "solid_tab_rotate" to mapOf(
            "zh-Hant" to "旋轉對照",
            "en" to "Rotate",
            "zh-Hans" to "旋转对照",
            "ja" to "回転",
            "ko" to "회전",
            "th" to "หมุน"
        ),
        "solid_tab_sheet" to mapOf(
            "zh-Hant" to "視圖",
            "en" to "Views",
            "zh-Hans" to "视图",
            "ja" to "図面",
            "ko" to "도면",
            "th" to "ภาพ"
        ),
        "solid_width" to mapOf(
            "zh-Hant" to "寬",
            "en" to "Width",
            "zh-Hans" to "宽",
            "ja" to "幅",
            "ko" to "너비",
            "th" to "กว้าง"
        ),
        "solid_yaw" to mapOf(
            "zh-Hant" to "水平旋轉",
            "en" to "Turn",
            "zh-Hans" to "水平旋转",
            "ja" to "水平回転",
            "ko" to "좌우 회전",
            "th" to "หมุนซ้ายขวา"
        ),
        "sort_by_date" to mapOf(
            "zh-Hant" to "依修改時間排序",
            "en" to "Sort by Date Modified",
            "zh-Hans" to "按修改时间排序",
            "ja" to "更新日時順",
            "ko" to "수정 날짜순",
            "th" to "เรียงตามวันที่แก้ไข"
        ),
        "sort_by_pages" to mapOf(
            "zh-Hant" to "依頁數排序",
            "en" to "Sort by pages",
            "zh-Hans" to "依页数排序",
            "ja" to "ページ数順",
            "ko" to "페이지 수순",
            "th" to "เรียงตามจำนวนหน้า"
        ),
        "sort_by_title" to mapOf(
            "zh-Hant" to "依名稱排序",
            "en" to "Sort by Name",
            "zh-Hans" to "按名称排序",
            "ja" to "名前順",
            "ko" to "이름순",
            "th" to "เรียงตามชื่อ"
        )
    )

    private fun part25(): Map<String, Map<String, String>> = mapOf(
        "sort_date" to mapOf(
            "zh-Hant" to "依修改時間排序",
            "en" to "Sort by Date Modified",
            "zh-Hans" to "按修改时间排序",
            "ja" to "変更日順で並べ替え",
            "ko" to "수정일순 정렬",
            "th" to "เรียงตามวันที่แก้ไข"
        ),
        "sort_only_recordings" to mapOf(
            "zh-Hant" to "僅顯示含錄音筆記",
            "en" to "Recordings Only",
            "zh-Hans" to "仅显示含录音笔记",
            "ja" to "録音付きのみ",
            "ko" to "녹음 포함만",
            "th" to "เฉพาะที่มีเสียงบันทึก"
        ),
        "sort_recordings" to mapOf(
            "zh-Hant" to "僅顯示含錄音筆記",
            "en" to "Only Notes with Audio",
            "zh-Hans" to "仅显示含录音笔记",
            "ja" to "録音付きノートのみ表示",
            "ko" to "녹음 포함 노트만 표시",
            "th" to "เฉพาะบันทึกที่มีเสียง"
        ),
        "sort_title" to mapOf(
            "zh-Hant" to "依名稱排序",
            "en" to "Sort by Title",
            "zh-Hans" to "按名称排序",
            "ja" to "名前順で並べ替え",
            "ko" to "이름순 정렬",
            "th" to "เรียงตามชื่อ"
        ),
        "spec_dimensions" to mapOf(
            "zh-Hant" to "參考尺寸：",
            "en" to "Reference Dimensions: ",
            "zh-Hans" to "参考尺寸：",
            "ja" to "参考寸法：",
            "ko" to "참고 치수: ",
            "th" to "ขนาดอ้างอิง: "
        ),
        "spec_filesize" to mapOf(
            "zh-Hant" to "檔案大小：",
            "en" to "File Size: ",
            "zh-Hans" to "文件大小：",
            "ja" to "ファイルサイズ：",
            "ko" to "파일 크기: ",
            "th" to "ขนาดไฟล์: "
        ),
        "spec_materials" to mapOf(
            "zh-Hant" to "材質工藝：",
            "en" to "Material & Finish: ",
            "zh-Hans" to "材质工艺：",
            "ja" to "材質・仕上げ：",
            "ko" to "소재 및 공정: ",
            "th" to "วัสดุและกระบวนการ: "
        ),
        "spec_specs" to mapOf(
            "zh-Hant" to "主要規格：",
            "en" to "Main Specs: ",
            "zh-Hans" to "主要规格：",
            "ja" to "主要仕様：",
            "ko" to "주요 사양: ",
            "th" to "สเปกหลัก: "
        ),
        "special_symbols" to mapOf(
            "zh-Hant" to "特殊符號",
            "en" to "Special Symbols",
            "zh-Hans" to "特殊符号",
            "ja" to "特殊記号",
            "ko" to "특수 기호",
            "th" to "สัญลักษณ์พิเศษ"
        ),
        "specs_info" to mapOf(
            "zh-Hant" to "實體規格與材料建議",
            "en" to "Specs & Material Suggestions",
            "zh-Hans" to "实体规格与材料建议",
            "ja" to "仕様・材料の提案",
            "ko" to "사양 및 재료 권장사항",
            "th" to "ข้อมูลจำเพาะและคำแนะนำวัสดุ"
        ),
        "stab_desc" to mapOf(
            "zh-Hant" to "線條即時平滑防抖，消除手寫抖動與毛邊",
            "en" to "Real-time stroke stabilisation smoothing for jitter-free writing and drawing",
            "zh-Hans" to "线条实时平滑防抖，消除手写抖动与毛刺",
            "ja" to "ストロークの手ブレを抑えて滑らかに補正します",
            "ko" to "손떨림을 보정하여 매끄러운 선을 그립니다",
            "th" to "ลดการสั่นของเส้นแบบเรียลไทม์เพื่อการเขียนและวาดที่ลื่นไหล"
        ),
        "stab_light" to mapOf(
            "zh-Hant" to "輕微防抖",
            "en" to "Light stabiliser",
            "zh-Hans" to "轻微防抖",
            "ja" to "弱い手ブレ補正",
            "ko" to "약한 손떨림 보정",
            "th" to "กันสั่นเบา"
        ),
        "stab_medium" to mapOf(
            "zh-Hant" to "中度防抖",
            "en" to "Medium stabiliser",
            "zh-Hans" to "中度防抖",
            "ja" to "中程度の手ブレ補正",
            "ko" to "보통 손떨림 보정",
            "th" to "กันสั่นปานกลาง"
        ),
        "stab_off" to mapOf(
            "zh-Hant" to "關閉防抖",
            "en" to "Stabiliser off",
            "zh-Hans" to "关闭防抖",
            "ja" to "手ブレ補正オフ",
            "ko" to "손떨림 보정 끔",
            "th" to "ปิดการกันสั่น"
        ),
        "stab_strong" to mapOf(
            "zh-Hant" to "強力防抖",
            "en" to "Strong stabiliser",
            "zh-Hans" to "强力防抖",
            "ja" to "強い手ブレ補正",
            "ko" to "강한 손떨림 보정",
            "th" to "กันสั่นแรง"
        ),
        "stab_title" to mapOf(
            "zh-Hant" to "線條平滑防抖",
            "en" to "Stroke stabiliser",
            "zh-Hans" to "线条平滑防抖",
            "ja" to "線の手ブレ補正",
            "ko" to "선 손떨림 보정",
            "th" to "การกันสั่นของเส้น"
        ),
        "standalone_recording" to mapOf(
            "zh-Hant" to "不附加（僅儲存為獨立錄音）",
            "en" to "Standalone (Save as separate audio file)",
            "zh-Hans" to "不附加（仅保存为独立录音）",
            "ja" to "添付しない（独立ファイルとして保存）",
            "ko" to "첨부 안 함 (독립 오디오로 저장)",
            "th" to "ไม่แนบ (บันทึกเป็นไฟล์เสียงแยก)"
        ),
        "start_collaboration" to mapOf(
            "zh-Hant" to "開啟多人協同",
            "en" to "Start Collaboration",
            "zh-Hans" to "开启多人协同",
            "ja" to "共同編集を開始",
            "ko" to "공동 편집 시작",
            "th" to "เริ่มการทำงานร่วมกัน"
        ),
        "start_recording" to mapOf(
            "zh-Hant" to "開始錄音",
            "en" to "Start Recording",
            "zh-Hans" to "开始录音",
            "ja" to "録音開始",
            "ko" to "녹음 시작",
            "th" to "เริ่มบันทึกเสียง"
        ),
        "start_recording_desc" to mapOf(
            "zh-Hant" to "同步語音轉錄與書寫對齊",
            "en" to "Sync voice transcription & strokes",
            "zh-Hans" to "同步语音转录与书写对齐",
            "ja" to "音声書き起こしと筆跡の同期",
            "ko" to "음성 필사 및 필기 동기화",
            "th" to "การถอดเสียงและการจัดตำแหน่งการเขียน"
        ),
        "startup_logs_title" to mapOf(
            "zh-Hant" to "啟動與效能日誌 (工程除錯)",
            "en" to "Startup & Performance Logs (Engineering)",
            "zh-Hans" to "启动与性能日志 (工程调试)",
            "ja" to "起動とパフォーマンスログ（エンジニアリング）",
            "ko" to "시작 및 성능 로그 (엔지니어링)",
            "th" to "บันทึกการเริ่มต้นและประสิทธิภาพ (วิศวกรรม)"
        ),
        "status_connected" to mapOf(
            "zh-Hant" to "已連線",
            "en" to "Connected",
            "zh-Hans" to "已连接",
            "ja" to "接続中",
            "ko" to "연결됨",
            "th" to "เชื่อมต่อแล้ว"
        ),
        "status_connecting" to mapOf(
            "zh-Hant" to "連線中...",
            "en" to "Connecting...",
            "zh-Hans" to "连接中...",
            "ja" to "接続試行中...",
            "ko" to "연결 중...",
            "th" to "กำลังเชื่อมต่อ..."
        ),
        "status_disconnected" to mapOf(
            "zh-Hant" to "未連線",
            "en" to "Disconnected",
            "zh-Hans" to "未连接",
            "ja" to "未接続",
            "ko" to "연결 끊김",
            "th" to "ไม่ได้เชื่อมต่อ"
        ),
        "sticker_arrow_curve" to mapOf(
            "zh-Hant" to "曲線箭頭",
            "en" to "Curved arrow",
            "zh-Hans" to "曲线箭头",
            "ja" to "曲線矢印",
            "ko" to "곡선 화살표",
            "th" to "ลูกศรโค้ง"
        ),
        "sticker_arrow_down" to mapOf(
            "zh-Hant" to "向下箭頭",
            "en" to "Arrow down",
            "zh-Hans" to "向下箭头",
            "ja" to "下矢印",
            "ko" to "아래쪽 화살표",
            "th" to "ลูกศรลง"
        ),
        "sticker_arrow_left" to mapOf(
            "zh-Hant" to "向左箭頭",
            "en" to "Arrow left",
            "zh-Hans" to "向左箭头",
            "ja" to "左矢印",
            "ko" to "왼쪽 화살표",
            "th" to "ลูกศรซ้าย"
        ),
        "sticker_arrow_right" to mapOf(
            "zh-Hant" to "向右箭頭",
            "en" to "Arrow right",
            "zh-Hans" to "向右箭头",
            "ja" to "右矢印",
            "ko" to "오른쪽 화살표",
            "th" to "ลูกศรขวา"
        ),
        "sticker_arrow_up" to mapOf(
            "zh-Hant" to "向上箭頭",
            "en" to "Arrow up",
            "zh-Hans" to "向上箭头",
            "ja" to "上矢印",
            "ko" to "위쪽 화살표",
            "th" to "ลูกศรขึ้น"
        ),
        "sticker_badge" to mapOf(
            "zh-Hant" to "徽章",
            "en" to "Badge",
            "zh-Hans" to "徽章",
            "ja" to "バッジ",
            "ko" to "배지",
            "th" to "เหรียญตรา"
        ),
        "sticker_blocked" to mapOf(
            "zh-Hant" to "卡住",
            "en" to "Blocked",
            "zh-Hans" to "卡住",
            "ja" to "ブロック中",
            "ko" to "막힘",
            "th" to "ติดขัด"
        ),
        "sticker_book" to mapOf(
            "zh-Hant" to "書",
            "en" to "Book",
            "zh-Hans" to "书",
            "ja" to "本",
            "ko" to "책",
            "th" to "หนังสือ"
        ),
        "sticker_bookmark" to mapOf(
            "zh-Hant" to "書籤",
            "en" to "Bookmark",
            "zh-Hans" to "书签",
            "ja" to "ブックマーク",
            "ko" to "북마크",
            "th" to "ที่คั่นหนังสือ"
        ),
        "sticker_bracket" to mapOf(
            "zh-Hant" to "方括號",
            "en" to "Bracket",
            "zh-Hans" to "方括号",
            "ja" to "角括弧",
            "ko" to "대괄호",
            "th" to "วงเล็บเหลี่ยม"
        ),
        "sticker_branch" to mapOf(
            "zh-Hant" to "分支",
            "en" to "Branch",
            "zh-Hans" to "分支",
            "ja" to "分岐",
            "ko" to "분기",
            "th" to "แยกสาขา"
        ),
        "sticker_bubble" to mapOf(
            "zh-Hant" to "對話泡",
            "en" to "Speech bubble",
            "zh-Hans" to "对话泡",
            "ja" to "吹き出し",
            "ko" to "말풍선",
            "th" to "กรอบคำพูด"
        ),
        "sticker_builtin" to mapOf(
            "zh-Hant" to "內建",
            "en" to "Built-in",
            "zh-Hans" to "内置",
            "ja" to "組み込み",
            "ko" to "기본 제공",
            "th" to "ในตัว"
        ),
        "sticker_bullet" to mapOf(
            "zh-Hant" to "項目點",
            "en" to "Bullet",
            "zh-Hans" to "项目点",
            "ja" to "箇条書き",
            "ko" to "글머리 기호",
            "th" to "จุดนำ"
        ),
        "sticker_calendar" to mapOf(
            "zh-Hant" to "日期",
            "en" to "Date",
            "zh-Hans" to "日期",
            "ja" to "日付",
            "ko" to "날짜",
            "th" to "วันที่"
        ),
        "sticker_cat_annotate" to mapOf(
            "zh-Hant" to "標註",
            "en" to "Annotate",
            "zh-Hans" to "标注",
            "ja" to "注釈",
            "ko" to "주석",
            "th" to "ทำเครื่องหมาย"
        ),
        "sticker_cat_flow" to mapOf(
            "zh-Hant" to "流程",
            "en" to "Flow",
            "zh-Hans" to "流程",
            "ja" to "フロー",
            "ko" to "흐름",
            "th" to "ผังงาน"
        ),
        "sticker_cat_label" to mapOf(
            "zh-Hant" to "標籤",
            "en" to "Labels",
            "zh-Hans" to "标签",
            "ja" to "ラベル",
            "ko" to "라벨",
            "th" to "ป้ายกำกับ"
        ),
        "sticker_cat_mood" to mapOf(
            "zh-Hant" to "心情",
            "en" to "Reactions",
            "zh-Hans" to "心情",
            "ja" to "リアクション",
            "ko" to "반응",
            "th" to "อารมณ์"
        ),
        "sticker_cat_study" to mapOf(
            "zh-Hant" to "學習",
            "en" to "Study",
            "zh-Hans" to "学习",
            "ja" to "学習",
            "ko" to "학습",
            "th" to "การเรียน"
        ),
        "sticker_cat_task" to mapOf(
            "zh-Hant" to "待辦",
            "en" to "Tasks",
            "zh-Hans" to "待办",
            "ja" to "タスク",
            "ko" to "할 일",
            "th" to "งานที่ต้องทำ"
        ),
        "sticker_check" to mapOf(
            "zh-Hant" to "勾",
            "en" to "Check",
            "zh-Hans" to "勾",
            "ja" to "チェック",
            "ko" to "체크",
            "th" to "เครื่องหมายถูก"
        ),
        "sticker_checkbox" to mapOf(
            "zh-Hant" to "待辦",
            "en" to "To do",
            "zh-Hans" to "待办",
            "ja" to "未完了",
            "ko" to "할 일",
            "th" to "ยังไม่ทำ"
        ),
        "sticker_checkbox_done" to mapOf(
            "zh-Hant" to "已完成",
            "en" to "Done",
            "zh-Hans" to "已完成",
            "ja" to "完了",
            "ko" to "완료",
            "th" to "เสร็จแล้ว"
        ),
        "sticker_circle_mark" to mapOf(
            "zh-Hant" to "圈選",
            "en" to "Circle",
            "zh-Hans" to "圈选",
            "ja" to "丸で囲む",
            "ko" to "동그라미",
            "th" to "วงกลม"
        ),
        "sticker_clock" to mapOf(
            "zh-Hant" to "時間",
            "en" to "Time",
            "zh-Hans" to "时间",
            "ja" to "時間",
            "ko" to "시간",
            "th" to "เวลา"
        ),
        "sticker_cross" to mapOf(
            "zh-Hant" to "叉",
            "en" to "Cross",
            "zh-Hans" to "叉",
            "ja" to "バツ",
            "ko" to "가위표",
            "th" to "กากบาท"
        ),
        "sticker_exclaim" to mapOf(
            "zh-Hant" to "驚嘆號",
            "en" to "Important",
            "zh-Hans" to "惊叹号",
            "ja" to "感嘆符",
            "ko" to "느낌표",
            "th" to "เครื่องหมายอัศเจรีย์"
        ),
        "sticker_flag" to mapOf(
            "zh-Hant" to "旗標",
            "en" to "Flag",
            "zh-Hans" to "旗标",
            "ja" to "フラグ",
            "ko" to "깃발",
            "th" to "ธง"
        ),
        "sticker_formula" to mapOf(
            "zh-Hant" to "公式",
            "en" to "Formula",
            "zh-Hans" to "公式",
            "ja" to "数式",
            "ko" to "수식",
            "th" to "สูตร"
        ),
        "sticker_frown" to mapOf(
            "zh-Hant" to "不滿",
            "en" to "Unhappy",
            "zh-Hans" to "不满",
            "ja" to "不満",
            "ko" to "아쉬움",
            "th" to "ไม่พอใจ"
        ),
        "sticker_half_done" to mapOf(
            "zh-Hant" to "進行中",
            "en" to "In progress",
            "zh-Hans" to "进行中",
            "ja" to "進行中",
            "ko" to "진행 중",
            "th" to "กำลังดำเนินการ"
        ),
        "sticker_heart" to mapOf(
            "zh-Hant" to "喜歡",
            "en" to "Love",
            "zh-Hans" to "喜欢",
            "ja" to "お気に入り",
            "ko" to "좋아요",
            "th" to "ถูกใจ"
        ),
        "sticker_hot" to mapOf(
            "zh-Hant" to "重點",
            "en" to "Key point",
            "zh-Hans" to "重点",
            "ja" to "重要",
            "ko" to "핵심",
            "th" to "จุดสำคัญ"
        ),
        "sticker_idea" to mapOf(
            "zh-Hant" to "靈感",
            "en" to "Idea",
            "zh-Hans" to "灵感",
            "ja" to "アイデア",
            "ko" to "아이디어",
            "th" to "ไอเดีย"
        ),
        "sticker_library" to mapOf(
            "zh-Hant" to "貼紙庫",
            "en" to "Sticker Library",
            "zh-Hans" to "贴纸库",
            "ja" to "ステッカーライブラリ",
            "ko" to "스티커 라이브러리",
            "th" to "คลังสติกเกอร์"
        ),
        "sticker_loop" to mapOf(
            "zh-Hant" to "循環",
            "en" to "Loop",
            "zh-Hans" to "循环",
            "ja" to "ループ",
            "ko" to "반복",
            "th" to "วนซ้ำ"
        ),
        "sticker_mine" to mapOf(
            "zh-Hant" to "我存的",
            "en" to "Saved by me",
            "zh-Hans" to "我存的",
            "ja" to "保存したもの",
            "ko" to "내가 저장한 것",
            "th" to "ที่ฉันบันทึก"
        ),
        "sticker_neutral" to mapOf(
            "zh-Hant" to "普通",
            "en" to "Neutral",
            "zh-Hans" to "普通",
            "ja" to "ふつう",
            "ko" to "보통",
            "th" to "เฉย ๆ"
        ),
        "sticker_note" to mapOf(
            "zh-Hant" to "便利貼",
            "en" to "Sticky note",
            "zh-Hans" to "便利贴",
            "ja" to "付箋",
            "ko" to "포스트잇",
            "th" to "กระดาษโน้ต"
        ),
        "sticker_pencil" to mapOf(
            "zh-Hant" to "鉛筆",
            "en" to "Pencil",
            "zh-Hans" to "铅笔",
            "ja" to "鉛筆",
            "ko" to "연필",
            "th" to "ดินสอ"
        ),
        "sticker_placed_hint" to mapOf(
            "zh-Hant" to "貼紙已放置。點一下即可移動、縮放、旋轉或刪除。",
            "en" to "Sticker placed. Tap it to move, resize, rotate or delete.",
            "zh-Hans" to "贴纸已放置。点一下即可移动、缩放、旋转或删除。",
            "ja" to "ステッカーを配置しました。タップすると移動・拡大縮小・回転・削除ができます。",
            "ko" to "스티커를 배치했습니다. 탭하면 이동, 크기 조절, 회전, 삭제할 수 있습니다.",
            "th" to "วางสติกเกอร์แล้ว แตะเพื่อย้าย ปรับขนาด หมุน หรือลบ"
        ),
        "sticker_qa" to mapOf(
            "zh-Hant" to "問與答",
            "en" to "Q & A",
            "zh-Hans" to "问与答",
            "ja" to "質疑応答",
            "ko" to "질문과 답변",
            "th" to "ถาม-ตอบ"
        ),
        "sticker_question" to mapOf(
            "zh-Hant" to "問號",
            "en" to "Question",
            "zh-Hans" to "问号",
            "ja" to "疑問符",
            "ko" to "물음표",
            "th" to "เครื่องหมายคำถาม"
        ),
        "sticker_ribbon" to mapOf(
            "zh-Hant" to "緞帶",
            "en" to "Ribbon",
            "zh-Hans" to "绶带",
            "ja" to "リボン",
            "ko" to "리본",
            "th" to "ริบบิ้น"
        ),
        "sticker_smile" to mapOf(
            "zh-Hant" to "開心",
            "en" to "Happy",
            "zh-Hans" to "开心",
            "ja" to "うれしい",
            "ko" to "좋음",
            "th" to "ยิ้ม"
        ),
        "sticker_star" to mapOf(
            "zh-Hant" to "星星",
            "en" to "Star",
            "zh-Hans" to "星星",
            "ja" to "星",
            "ko" to "별",
            "th" to "ดาว"
        ),
        "sticker_tag" to mapOf(
            "zh-Hant" to "標籤",
            "en" to "Tag",
            "zh-Hans" to "标签",
            "ja" to "タグ",
            "ko" to "태그",
            "th" to "แท็ก"
        ),
        "sticker_thumb_up" to mapOf(
            "zh-Hant" to "讚",
            "en" to "Good",
            "zh-Hans" to "赞",
            "ja" to "いいね",
            "ko" to "좋아요",
            "th" to "ดี"
        ),
        "sticker_underline" to mapOf(
            "zh-Hant" to "波浪底線",
            "en" to "Squiggle",
            "zh-Hans" to "波浪下划线",
            "ja" to "波線",
            "ko" to "물결 밑줄",
            "th" to "ขีดเส้นหยัก"
        ),
        "sticky_anchor_ink" to mapOf(
            "zh-Hant" to "錨定重疊筆跡",
            "en" to "Anchor Overlapping Ink",
            "zh-Hans" to "锚定重叠笔迹",
            "ja" to "重なる手書きを固定",
            "ko" to "겹치는 필기 고정",
            "th" to "ตรึงลายมือที่ซ้อนทับ"
        ),
        "sticky_anchor_text" to mapOf(
            "zh-Hant" to "錨定至文字",
            "en" to "Anchor to Text",
            "zh-Hans" to "锚定至文本",
            "ja" to "テキストに固定",
            "ko" to "텍스트에 고정",
            "th" to "ตรึงกับข้อความ"
        ),
        "sticky_anchored_hint" to mapOf(
            "zh-Hant" to "手寫筆跡已錨定至文字方塊，將隨文字移動同步平移",
            "en" to "Handwriting anchored to text box and will follow its movement.",
            "zh-Hans" to "手写笔迹已锚定至文本框，将随文本移动同步平移",
            "ja" to "手書きがテキストボックスに固定され、連動して移動します",
            "ko" to "필기가 텍스트 상자에 고정되어 함께 이동합니다",
            "th" to "ลายมือถูกตรึงกับกล่องข้อความแล้วและจะเคลื่อนที่ตาม"
        ),
        "stop_and_save_record" to mapOf(
            "zh-Hant" to "停止並儲存至 Kairumo Record",
            "en" to "Stop & Save to Kairumo Record",
            "zh-Hans" to "停止并保存至 Kairumo Record",
            "ja" to "停止して Kairumo Record に保存",
            "ko" to "정지 및 Kairumo Record에 저장",
            "th" to "หยุดและบันทึกไปยัง Kairumo Record"
        ),
        "stop_and_save_to_folder" to mapOf(
            "zh-Hant" to "停止並儲存至 Kairumo Record",
            "en" to "Stop & Save to Kairumo Record",
            "zh-Hans" to "停止并保存至 Kairumo Record",
            "ja" to "停止して Kairumo Record に保存",
            "ko" to "중지하고 Kairumo Record 에 저장",
            "th" to "หยุดและบันทึกลงใน Kairumo Record"
        ),
        "stop_recording" to mapOf(
            "zh-Hant" to "停止錄音",
            "en" to "Stop Recording",
            "zh-Hans" to "停止录音",
            "ja" to "録音停止",
            "ko" to "녹음 중지",
            "th" to "หยุดบันทึก"
        )
    )

    private fun part26(): Map<String, Map<String, String>> = mapOf(
        "storage_caches" to mapOf(
            "zh-Hant" to "快取",
            "en" to "Caches",
            "zh-Hans" to "缓存",
            "ja" to "キャッシュ",
            "ko" to "캐시",
            "th" to "แคช"
        ),
        "storage_cannot_create" to mapOf(
            "zh-Hant" to "無法在 %@ 建立 Kairumo 文件資料夾。",
            "en" to "Cannot create the Kairumo document folder at %@.",
            "zh-Hans" to "无法在 %@ 创建 Kairumo 文档文件夹。",
            "ja" to "%@ に Kairumo のドキュメントフォルダを作成できません。",
            "ko" to "%@에 Kairumo 문서 폴더를 만들 수 없습니다.",
            "th" to "สร้างโฟลเดอร์เอกสาร Kairumo ที่ %@ ไม่ได้"
        ),
        "storage_cannot_move" to mapOf(
            "zh-Hant" to "Kairumo 無法移動文件庫：%@",
            "en" to "Kairumo could not move the document library: %@",
            "zh-Hans" to "Kairumo 无法移动文档库：%@",
            "ja" to "Kairumo はドキュメントライブラリを移動できませんでした：%@",
            "ko" to "Kairumo가 문서 라이브러리를 이동하지 못했습니다: %@",
            "th" to "Kairumo ย้ายคลังเอกสารไม่ได้: %@"
        ),
        "storage_cannot_remember" to mapOf(
            "zh-Hant" to "Kairumo 無法保留所選資料夾的存取權，請重新選擇。",
            "en" to "Kairumo could not retain access to the selected folder. Please choose it again.",
            "zh-Hans" to "Kairumo 无法保留所选文件夹的访问权限，请重新选择。",
            "ja" to "Kairumo は選択したフォルダへのアクセスを保持できませんでした。もう一度選択してください。",
            "ko" to "Kairumo가 선택한 폴더에 대한 접근 권한을 유지하지 못했습니다. 다시 선택하세요.",
            "th" to "Kairumo เก็บสิทธิ์เข้าถึงโฟลเดอร์ที่เลือกไว้ไม่ได้ โปรดเลือกอีกครั้ง"
        ),
        "storage_choose_parent" to mapOf(
            "zh-Hant" to "選擇文件資料夾…",
            "en" to "Choose Document Folder…",
            "zh-Hans" to "选择文件文件夹…",
            "ja" to "書類フォルダを選択…",
            "ko" to "문서 폴더 선택…",
            "th" to "เลือกโฟลเดอร์เอกสาร…"
        ),
        "storage_clean_now" to mapOf(
            "zh-Hant" to "立即清理",
            "en" to "Clean up now",
            "zh-Hans" to "立即清理",
            "ja" to "今すぐ整理",
            "ko" to "지금 정리",
            "th" to "ล้างข้อมูลตอนนี้"
        ),
        "storage_cleaned" to mapOf(
            "zh-Hant" to "已釋放 %@。你的筆記與錄音不會被動到。",
            "en" to "Freed %@. Your notes and recordings are not touched.",
            "zh-Hans" to "已释放 %@。你的笔记与录音不会被动到。",
            "ja" to "%@ を解放しました。ノートと録音には触れていません。",
            "ko" to "%@ 확보했습니다. 노트와 녹음은 그대로입니다.",
            "th" to "คืนพื้นที่ %@ แล้ว โน้ตและการบันทึกเสียงของคุณไม่ถูกแตะต้อง"
        ),
        "storage_current_location" to mapOf(
            "zh-Hant" to "目前主要資料庫",
            "en" to "Current primary library",
            "zh-Hans" to "当前主要资料库",
            "ja" to "現在のメインライブラリ",
            "ko" to "현재 기본 라이브러리",
            "th" to "คลังหลักปัจจุบัน"
        ),
        "storage_has_library" to mapOf(
            "zh-Hant" to "%@ 已經有另一個 Kairumo 文件庫。請選擇空的資料夾，以免覆蓋既有文件。",
            "en" to "%@ already contains another Kairumo library. Choose an empty folder so existing documents are not overwritten.",
            "zh-Hans" to "%@ 已有另一个 Kairumo 文档库。请选择空文件夹，以免覆盖现有文档。",
            "ja" to "%@ にはすでに別の Kairumo ライブラリがあります。既存のドキュメントが上書きされないよう、空のフォルダを選んでください。",
            "ko" to "%@에 이미 다른 Kairumo 라이브러리가 있습니다. 기존 문서를 덮어쓰지 않도록 빈 폴더를 선택하세요.",
            "th" to "%@ มีคลัง Kairumo อื่นอยู่แล้ว โปรดเลือกโฟลเดอร์ว่างเพื่อไม่ให้เอกสารเดิมถูกเขียนทับ"
        ),
        "storage_icloud_continue" to mapOf(
            "zh-Hant" to "仍要使用",
            "en" to "Use it anyway",
            "zh-Hans" to "仍要使用",
            "ja" to "このまま使う",
            "ko" to "그래도 사용",
            "th" to "ใช้ต่อไป"
        ),
        "storage_icloud_current" to mapOf(
            "zh-Hant" to "這個位置會被 iCloud 雲碟同步，已刪除的檔案可能被還原；建議改放 iCloud 不會同步的資料夾。",
            "en" to "This location is synced by iCloud Drive. Deleted files may come back; consider a folder iCloud doesn't sync.",
            "zh-Hans" to "这个位置会被 iCloud 云盘同步，已删除的文件可能被恢复；建议改放 iCloud 不会同步的文件夹。",
            "ja" to "この場所は iCloud Drive で同期されます。削除したファイルが復元されることがあります。iCloud で同期されないフォルダをおすすめします。",
            "ko" to "이 위치는 iCloud Drive로 동기화됩니다. 삭제한 파일이 복원될 수 있으니 iCloud가 동기화하지 않는 폴더를 권장합니다.",
            "th" to "ตำแหน่งนี้ซิงก์ผ่าน iCloud Drive ไฟล์ที่ลบอาจกลับมา แนะนำให้ใช้โฟลเดอร์ที่ iCloud ไม่ซิงก์"
        ),
        "storage_icloud_message" to mapOf(
            "zh-Hant" to "Kairumo 的資料庫由數千個小檔組成，而且已經透過 Google Drive 或同步資料夾同步。若再讓 iCloud 雲碟同步它，已刪除的檔案可能被還原，兩邊也可能互相衝突。建議選擇 iCloud 不會同步的資料夾，或仍要使用這個位置。",
            "en" to "Kairumo's library is made of thousands of small files and already syncs through Google Drive or a sync folder. If iCloud Drive syncs it too, deleted files can come back and the two can conflict. Choose a folder that iCloud does not sync, or continue anyway.",
            "zh-Hans" to "Kairumo 的资料库由数千个小文件组成，并且已经通过 Google Drive 或同步文件夹同步。若再让 iCloud 云盘同步它，已删除的文件可能被恢复，两边也可能互相冲突。建议选择 iCloud 不会同步的文件夹，或仍要使用这个位置。",
            "ja" to "Kairumo のライブラリは数千の小さなファイルでできており、すでに Google Drive または同期フォルダで同期されます。iCloud Drive でも同期すると、削除したファイルが復元されたり、競合が起きたりすることがあります。iCloud で同期されないフォルダを選ぶか、そのまま続行してください。",
            "ko" to "Kairumo 라이브러리는 수천 개의 작은 파일로 이루어져 있으며 이미 Google Drive 또는 동기화 폴더로 동기화됩니다. iCloud Drive로도 동기화하면 삭제한 파일이 복원되거나 충돌이 생길 수 있습니다. iCloud가 동기화하지 않는 폴더를 선택하거나 그대로 계속하세요.",
            "th" to "คลังของ Kairumo ประกอบด้วยไฟล์เล็กๆ หลายพันไฟล์ และซิงก์ผ่าน Google Drive หรือโฟลเดอร์ซิงก์อยู่แล้ว หาก iCloud Drive ซิงก์ด้วย ไฟล์ที่ลบไปอาจกลับมาและอาจเกิดความขัดแย้งได้ ควรเลือกโฟลเดอร์ที่ iCloud ไม่ซิงก์ หรือดำเนินการต่อ"
        ),
        "storage_icloud_title" to mapOf(
            "zh-Hant" to "這個資料夾會被 iCloud 雲碟同步",
            "en" to "This folder is synced by iCloud Drive",
            "zh-Hans" to "这个文件夹会被 iCloud 云盘同步",
            "ja" to "このフォルダは iCloud Drive で同期されます",
            "ko" to "이 폴더는 iCloud Drive로 동기화됩니다",
            "th" to "โฟลเดอร์นี้ซิงก์ผ่าน iCloud Drive"
        ),
        "storage_library" to mapOf(
            "zh-Hant" to "筆記與錄音",
            "en" to "Notes & recordings",
            "zh-Hans" to "笔记与录音",
            "ja" to "ノートと録音",
            "ko" to "노트 및 녹음",
            "th" to "โน้ตและการบันทึกเสียง"
        ),
        "storage_library_explainer" to mapOf(
            "zh-Hant" to "請選擇可在 Finder 或「檔案」中存取的資料夾。Kairumo 會在其中建立「Kairumo Doc」，安全搬移目前資料庫，並持續將筆記本、錄音與附件儲存到該位置。",
            "en" to "Choose a folder you can access in Finder or Files. Kairumo creates “Kairumo Doc” there, moves the current library safely, and continuously saves notebooks, recordings, and attachments to that location.",
            "zh-Hans" to "请选择可在 Finder 或“文件”中访问的文件夹。Kairumo 会在其中建立“Kairumo Doc”，安全迁移当前资料库，并持续将笔记本、录音和附件保存到该位置。",
            "ja" to "Finder またはファイルからアクセスできるフォルダを選択してください。Kairumo はその中に「Kairumo Doc」を作成し、現在のライブラリを安全に移動して、ノート、録音、添付ファイルを継続的に保存します。",
            "ko" to "Finder 또는 파일 앱에서 접근할 수 있는 폴더를 선택하세요. Kairumo는 그 안에 ‘Kairumo Doc’을 만들고 현재 라이브러리를 안전하게 이동한 뒤 노트, 녹음 및 첨부 파일을 계속 저장합니다.",
            "th" to "เลือกโฟลเดอร์ที่คุณเข้าถึงได้ใน Finder หรือแอปไฟล์ Kairumo จะสร้าง “Kairumo Doc” ที่นั่น ย้ายคลังปัจจุบันอย่างปลอดภัย และบันทึกสมุดบันทึก เสียงบันทึก และไฟล์แนบลงในตำแหน่งนั้นอย่างต่อเนื่อง"
        ),
        "storage_library_subtitle" to mapOf(
            "zh-Hant" to "選擇 Kairumo 持續儲存文件的位置",
            "en" to "Choose where Kairumo continuously stores your documents",
            "zh-Hans" to "选择 Kairumo 持续保存文件的位置",
            "ja" to "Kairumo が書類を継続的に保存する場所を選択",
            "ko" to "Kairumo가 문서를 계속 저장할 위치 선택",
            "th" to "เลือกตำแหน่งที่ Kairumo ใช้บันทึกเอกสารอย่างต่อเนื่อง"
        ),
        "storage_library_title" to mapOf(
            "zh-Hant" to "主要文件資料庫",
            "en" to "Primary Document Library",
            "zh-Hans" to "主要文件资料库",
            "ja" to "メイン書類ライブラリ",
            "ko" to "기본 문서 라이브러리",
            "th" to "คลังเอกสารหลัก"
        ),
        "storage_location" to mapOf(
            "zh-Hant" to "資料儲存位置",
            "en" to "Data Storage Location",
            "zh-Hans" to "数据存储位置",
            "ja" to "データ保存先",
            "ko" to "데이터 저장 위치",
            "th" to "ตำแหน่งจัดเก็บข้อมูล"
        ),
        "storage_models" to mapOf(
            "zh-Hant" to "已下載的模型",
            "en" to "Downloaded models",
            "zh-Hans" to "已下载的模型",
            "ja" to "ダウンロード済みモデル",
            "ko" to "다운로드한 모델",
            "th" to "โมเดลที่ดาวน์โหลด"
        ),
        "storage_move_cancelled" to mapOf(
            "zh-Hant" to "已取消搬移，沒有任何改動。",
            "en" to "Move cancelled. Nothing was changed.",
            "zh-Hans" to "已取消搬移，没有任何更改。",
            "ja" to "移動をキャンセルしました。変更はありません。",
            "ko" to "이동을 취소했습니다. 변경된 내용이 없습니다.",
            "th" to "ยกเลิกการย้ายแล้ว ไม่มีการเปลี่ยนแปลง"
        ),
        "storage_move_complete" to mapOf(
            "zh-Hant" to "主要資料庫現已持續儲存到所選位置。",
            "en" to "The primary library is now continuously saved at the selected location.",
            "zh-Hans" to "主要资料库现已持续保存到所选位置。",
            "ja" to "メインライブラリは選択した場所に継続的に保存されます。",
            "ko" to "이제 기본 라이브러리가 선택한 위치에 계속 저장됩니다.",
            "th" to "ขณะนี้คลังหลักจะถูกบันทึกอย่างต่อเนื่องในตำแหน่งที่เลือก"
        ),
        "storage_nested" to mapOf(
            "zh-Hant" to "請選擇目前 Kairumo 文件資料夾以外的資料夾。",
            "en" to "Choose a folder outside the current Kairumo Doc folder.",
            "zh-Hans" to "请选择当前 Kairumo 文档文件夹以外的文件夹。",
            "ja" to "現在の Kairumo ドキュメントフォルダの外にあるフォルダを選んでください。",
            "ko" to "현재 Kairumo 문서 폴더 밖의 폴더를 선택하세요.",
            "th" to "เลือกโฟลเดอร์ที่อยู่นอกโฟลเดอร์เอกสาร Kairumo ปัจจุบัน"
        ),
        "storage_progress_cleaning" to mapOf(
            "zh-Hant" to "移除舊的資料庫…",
            "en" to "Removing the old copy…",
            "zh-Hans" to "移除旧的资料库…",
            "ja" to "古いライブラリを削除しています…",
            "ko" to "이전 라이브러리를 삭제하는 중…",
            "th" to "กำลังลบคลังเดิม…"
        ),
        "storage_progress_copying" to mapOf(
            "zh-Hant" to "複製中：%1\$d／%2\$d 個檔案…",
            "en" to "Copying %1\$d of %2\$d files…",
            "zh-Hans" to "复制中：%1\$d／%2\$d 个文件…",
            "ja" to "コピー中：%1\$d／%2\$d ファイル…",
            "ko" to "복사 중: %1\$d/%2\$d 파일…",
            "th" to "กำลังคัดลอก %1\$d จาก %2\$d ไฟล์…"
        ),
        "storage_progress_verifying" to mapOf(
            "zh-Hant" to "驗證複製結果…",
            "en" to "Verifying the copy…",
            "zh-Hans" to "验证复制结果…",
            "ja" to "コピーを検証しています…",
            "ko" to "복사본을 확인하는 중…",
            "th" to "กำลังตรวจสอบสำเนา…"
        ),
        "storage_progress_waiting" to mapOf(
            "zh-Hant" to "等待同步結束…",
            "en" to "Waiting for sync to finish…",
            "zh-Hans" to "等待同步结束…",
            "ja" to "同期の完了を待っています…",
            "ko" to "동기화가 끝나기를 기다리는 중…",
            "th" to "กำลังรอการซิงก์ให้เสร็จ…"
        ),
        "storage_reset_button" to mapOf(
            "zh-Hant" to "重設本機資料…",
            "en" to "Reset local data…",
            "zh-Hans" to "重置本机数据…",
            "ja" to "ローカルデータをリセット…",
            "ko" to "로컬 데이터 초기화…",
            "th" to "รีเซ็ตข้อมูลในเครื่อง…"
        ),
        "storage_reset_cloud_failed" to mapOf(
            "zh-Hant" to "雲端資料沒有清成功，所以本機沒有動任何東西。請再試一次，或關掉這個選項。",
            "en" to "Could not erase the cloud data, so nothing local was removed. Try again or turn the option off.",
            "zh-Hans" to "云端数据没有清成功，所以本机没有动任何东西。请再试一次，或关掉这个选项。",
            "ja" to "クラウドのデータを削除できなかったため、ローカルは何も変更していません。もう一度試すか、このオプションをオフにしてください。",
            "ko" to "클라우드 데이터를 지우지 못해 로컬은 아무것도 변경하지 않았습니다. 다시 시도하거나 이 옵션을 끄세요.",
            "th" to "ลบข้อมูลบนคลาวด์ไม่สำเร็จ จึงไม่ได้ลบอะไรในเครื่อง ลองอีกครั้งหรือปิดตัวเลือกนี้"
        ),
        "storage_reset_cloud_note" to mapOf(
            "zh-Hant" to "清掉本 App 在 Google Drive 或同步資料夾裡的資料，其他裝置就不會把檔案帶回來。其他裝置本機的副本要等你在那些裝置上也重設才會清掉。",
            "en" to "Clears this app's Google Drive or sync-folder data so other devices cannot bring the files back. Other devices keep their own local copies until you reset them too.",
            "zh-Hans" to "清掉本 App 在 Google Drive 或同步文件夹里的数据，其他设备就不会把文件带回来。其他设备本机的副本要等你在那些设备上也重置才会清掉。",
            "ja" to "このアプリの Google Drive または同期フォルダのデータを消去し、他の端末がファイルを戻せないようにします。他の端末のローカルコピーは、その端末でもリセットするまで残ります。",
            "ko" to "이 앱의 Google Drive 또는 동기화 폴더 데이터를 지워 다른 기기가 파일을 다시 가져오지 못하게 합니다. 다른 기기의 로컬 사본은 그 기기에서도 초기화하기 전까지 남아 있습니다.",
            "th" to "ล้างข้อมูลของแอปนี้ใน Google Drive หรือโฟลเดอร์ซิงก์ เพื่อไม่ให้อุปกรณ์อื่นนำไฟล์กลับมา สำเนาในเครื่องของอุปกรณ์อื่นจะยังอยู่จนกว่าคุณจะรีเซ็ตที่เครื่องนั้นด้วย"
        ),
        "storage_reset_cloud_toggle" to mapOf(
            "zh-Hant" to "先清除雲端同步資料",
            "en" to "Also erase the cloud sync data first",
            "zh-Hans" to "先清除云端同步数据",
            "ja" to "先にクラウド同期データも削除する",
            "ko" to "먼저 클라우드 동기화 데이터도 삭제",
            "th" to "ลบข้อมูลซิงก์บนคลาวด์ก่อนด้วย"
        ),
        "storage_reset_confirm_action" to mapOf(
            "zh-Hant" to "重設",
            "en" to "Reset",
            "zh-Hans" to "重置",
            "ja" to "リセット",
            "ko" to "초기화",
            "th" to "รีเซ็ต"
        ),
        "storage_reset_confirm_message" to mapOf(
            "zh-Hant" to "這會移除這台裝置上所有的筆記本、錄音與附件。垃圾桶清空之後就無法復原。",
            "en" to "This removes all notebooks, recordings and attachments on this device. Once the Trash is emptied it cannot be undone.",
            "zh-Hans" to "这会移除这台设备上所有的笔记本、录音与附件。废纸篓清空之后就无法恢复。",
            "ja" to "この端末のノート、録音、添付ファイルをすべて削除します。ゴミ箱を空にすると元に戻せません。",
            "ko" to "이 기기의 모든 노트, 녹음, 첨부 파일이 삭제됩니다. 휴지통을 비우면 되돌릴 수 없습니다.",
            "th" to "การดำเนินการนี้จะลบสมุดบันทึก การบันทึกเสียง และไฟล์แนบทั้งหมดในอุปกรณ์นี้ เมื่อล้างถังขยะแล้วจะกู้คืนไม่ได้"
        ),
        "storage_reset_confirm_title" to mapOf(
            "zh-Hant" to "要重設本機資料嗎？",
            "en" to "Reset local data?",
            "zh-Hans" to "要重置本机数据吗？",
            "ja" to "ローカルデータをリセットしますか？",
            "ko" to "로컬 데이터를 초기화할까요?",
            "th" to "รีเซ็ตข้อมูลในเครื่องหรือไม่?"
        ),
        "storage_reset_done" to mapOf(
            "zh-Hant" to "已重設本機資料。",
            "en" to "Local data was reset.",
            "zh-Hans" to "已重置本机数据。",
            "ja" to "ローカルデータをリセットしました。",
            "ko" to "로컬 데이터를 초기화했습니다.",
            "th" to "รีเซ็ตข้อมูลในเครื่องแล้ว"
        ),
        "storage_reset_explainer" to mapOf(
            "zh-Hant" to "移除這台裝置上所有的筆記本、錄音與附件，從乾淨的資料庫重新開始。已下載的語音模型會保留。可以的話會先移到垃圾桶。",
            "en" to "Removes every notebook, recording and attachment stored on this device and starts from a clean library. Downloaded speech models are kept. Items go to the Trash where possible.",
            "zh-Hans" to "移除这台设备上所有的笔记本、录音与附件，从干净的资料库重新开始。已下载的语音模型会保留。可以的话会先移到废纸篓。",
            "ja" to "この端末に保存されているノート、録音、添付ファイルをすべて削除し、空のライブラリから始めます。ダウンロード済みの音声モデルは残ります。可能な場合はゴミ箱に移動します。",
            "ko" to "이 기기에 저장된 모든 노트, 녹음, 첨부 파일을 삭제하고 깨끗한 라이브러리로 시작합니다. 다운로드한 음성 모델은 유지됩니다. 가능하면 휴지통으로 이동합니다.",
            "th" to "ลบสมุดบันทึก การบันทึกเสียง และไฟล์แนบทั้งหมดในอุปกรณ์นี้ แล้วเริ่มต้นคลังใหม่ โมเดลเสียงที่ดาวน์โหลดไว้จะยังอยู่ และจะย้ายไปถังขยะเมื่อทำได้"
        ),
        "storage_reset_progress_cloud" to mapOf(
            "zh-Hant" to "清除雲端同步資料…",
            "en" to "Erasing cloud sync data…",
            "zh-Hans" to "清除云端同步数据…",
            "ja" to "クラウド同期データを削除しています…",
            "ko" to "클라우드 동기화 데이터를 지우는 중…",
            "th" to "กำลังลบข้อมูลซิงก์บนคลาวด์…"
        ),
        "storage_reset_progress_local" to mapOf(
            "zh-Hant" to "移除本機資料…",
            "en" to "Removing local data…",
            "zh-Hans" to "移除本机数据…",
            "ja" to "ローカルデータを削除しています…",
            "ko" to "로컬 데이터를 삭제하는 중…",
            "th" to "กำลังลบข้อมูลในเครื่อง…"
        ),
        "storage_reset_title" to mapOf(
            "zh-Hant" to "重設本機資料",
            "en" to "Reset local data",
            "zh-Hans" to "重置本机数据",
            "ja" to "ローカルデータをリセット",
            "ko" to "로컬 데이터 초기화",
            "th" to "รีเซ็ตข้อมูลในเครื่อง"
        ),
        "storage_sync_explainer" to mapOf(
            "zh-Hant" to "此位置僅屬於本裝置。跨設備更新會使用穩定的筆記本 ID，以及您設定的 Google Drive 或資料夾同步，因此 Mac、iPhone、iPad 與 Android 都不依賴其他裝置的本機路徑。",
            "en" to "This location is local to this device. Cross-device updates use stable notebook IDs and your configured Google Drive or folder sync, so Mac, iPhone, iPad, and Android never depend on another device’s local path.",
            "zh-Hans" to "此位置仅属于本设备。跨设备更新会使用稳定的笔记本 ID，以及您设置的 Google Drive 或文件夹同步，因此 Mac、iPhone、iPad 和 Android 都不依赖其他设备的本机路径。",
            "ja" to "この場所はこの端末専用です。端末間の更新には安定したノート ID と、設定済みの Google Drive またはフォルダ同期を使用するため、Mac、iPhone、iPad、Android が別端末のローカルパスに依存することはありません。",
            "ko" to "이 위치는 이 기기에만 적용됩니다. 기기 간 업데이트는 안정적인 노트 ID와 설정된 Google Drive 또는 폴더 동기화를 사용하므로 Mac, iPhone, iPad 및 Android는 다른 기기의 로컬 경로에 의존하지 않습니다.",
            "th" to "ตำแหน่งนี้ใช้เฉพาะอุปกรณ์เครื่องนี้ การอัปเดตข้ามอุปกรณ์ใช้รหัสสมุดบันทึกที่คงที่และ Google Drive หรือการซิงค์โฟลเดอร์ที่คุณตั้งค่าไว้ ดังนั้น Mac, iPhone, iPad และ Android จะไม่พึ่งพาพาธภายในของอุปกรณ์อื่น"
        ),
        "storage_sync_running" to mapOf(
            "zh-Hant" to "同步仍在進行中，請等它結束後再試一次。",
            "en" to "A sync operation is still running. Please try again after it finishes.",
            "zh-Hans" to "同步仍在进行中，请等它结束后再试一次。",
            "ja" to "同期がまだ実行中です。終了してからもう一度お試しください。",
            "ko" to "동기화가 아직 진행 중입니다. 끝난 후 다시 시도하세요.",
            "th" to "การซิงก์ยังทำงานอยู่ โปรดลองอีกครั้งหลังจากเสร็จสิ้น"
        ),
        "storage_temp" to mapOf(
            "zh-Hant" to "暫存檔",
            "en" to "Temporary files",
            "zh-Hans" to "临时文件",
            "ja" to "一時ファイル",
            "ko" to "임시 파일",
            "th" to "ไฟล์ชั่วคราว"
        ),
        "storage_title" to mapOf(
            "zh-Hant" to "儲存空間",
            "en" to "Storage",
            "zh-Hans" to "存储空间",
            "ja" to "ストレージ",
            "ko" to "저장 공간",
            "th" to "พื้นที่จัดเก็บ"
        ),
        "storage_verify_failed" to mapOf(
            "zh-Hant" to "複製後驗證失敗：%@",
            "en" to "Verification after copying failed: %@",
            "zh-Hans" to "复制后验证失败：%@",
            "ja" to "コピー後の検証に失敗しました：%@",
            "ko" to "복사 후 검증에 실패했습니다: %@",
            "th" to "การตรวจสอบหลังคัดลอกล้มเหลว: %@"
        ),
        "stroke_color" to mapOf(
            "zh-Hant" to "線條顏色",
            "en" to "Stroke color",
            "zh-Hans" to "线条颜色",
            "ja" to "線の色",
            "ko" to "선 색",
            "th" to "สีเส้น"
        ),
        "stroke_width" to mapOf(
            "zh-Hant" to "筆畫粗細",
            "en" to "Stroke Width",
            "zh-Hans" to "笔画粗细",
            "ja" to "線の太さ",
            "ko" to "선 굵기",
            "th" to "ความหนาของเส้น"
        ),
        "structure_folders" to mapOf(
            "zh-Hant" to "資料夾目錄",
            "en" to "Folders",
            "zh-Hans" to "文件夹目录",
            "ja" to "フォルダ一覧",
            "ko" to "폴더 목록",
            "th" to "โครงสร้างโฟลเดอร์"
        ),
        "structure_pages" to mapOf(
            "zh-Hant" to "頁面結構",
            "en" to "Pages",
            "zh-Hans" to "页面结构",
            "ja" to "ページ構成",
            "ko" to "페이지 구성",
            "th" to "โครงสร้างหน้า"
        ),
        "structure_sidebar" to mapOf(
            "zh-Hant" to "筆記結構",
            "en" to "Structure",
            "zh-Hans" to "笔记结构",
            "ja" to "ノート構造",
            "ko" to "노트 구조",
            "th" to "โครงสร้างสมุด"
        ),
        "structure_sidebar_desc" to mapOf(
            "zh-Hant" to "展開或收起頁面縮圖與目錄結構側邊欄",
            "en" to "Toggle page thumbnails and folder structure outline sidebar",
            "zh-Hans" to "展开或收起页面缩略图与目录结构侧边栏",
            "ja" to "ページサムネイルとフォルダ階層サイドバーを表示・非表示",
            "ko" to "페이지 썸네일 및 폴더 구조 아웃라인 사이드바 전환",
            "th" to "สลับแถบข้างโครงสร้างหน้าและโฟลเดอร์"
        ),
        "structure_summary" to mapOf(
            "zh-Hant" to "%1\$@ 個資料夾 · %2\$@ 本筆記",
            "en" to "%1\$@ folders · %2\$@ notebooks",
            "zh-Hans" to "%1\$@ 个文件夹 · %2\$@ 本笔记",
            "ja" to "フォルダ %1\$@ · ノート %2\$@",
            "ko" to "폴더 %1\$@ · 노트 %2\$@",
            "th" to "%1\$@ โฟลเดอร์ · %2\$@ สมุด"
        ),
        "style_blueprint" to mapOf(
            "zh-Hant" to "線框圖",
            "en" to "Blueprint",
            "zh-Hans" to "线框图",
            "ja" to "線画",
            "ko" to "선화",
            "th" to "ภาพลายเส้น"
        ),
        "style_solid" to mapOf(
            "zh-Hant" to "實物",
            "en" to "Solid",
            "zh-Hans" to "实物",
            "ja" to "実物",
            "ko" to "실물",
            "th" to "ภาพทึบ"
        ),
        "symmetry_guide" to mapOf(
            "zh-Hant" to "鏡像對稱輔助線",
            "en" to "Mirror symmetry guide",
            "zh-Hans" to "镜像对称辅助线",
            "ja" to "左右対称ガイド",
            "ko" to "좌우 대칭 안내선",
            "th" to "เส้นนำสมมาตรกระจก"
        ),
        "symmetry_guide_desc" to mapOf(
            "zh-Hant" to "鏡像對稱輔助尺規，即時繪製平衡對稱圖案",
            "en" to "Mirror symmetry guide for perfectly balanced illustrations and graphics",
            "zh-Hans" to "镜像对称辅助尺规，实时绘制平衡对称图形",
            "ja" to "左右対称の描画ガイドで均整のとれたイラストを作成",
            "ko" to "좌우 대칭 가이드라인으로 완벽한 균형의 드로잉 완성",
            "th" to "เส้นนำสายตาสมมาตรกระจกเพื่อการวาดที่สมดุลสมบูรณ์แบบ"
        ),
        "sync_a_how" to mapOf(
            "zh-Hant" to "在您的其他 iPad 或 Mac 上，只要在「雲端同步」指定「同一個上層根目錄」（不要點進個別的 .padnote），App 即會自動掃描所有筆記並進行雙向合併更新。",
            "en" to "On your other iPad or Mac, just point “Cloud sync” at the same top-level root folder (not an individual .padnote). The app scans every notebook and merges changes in both directions.",
            "zh-Hans" to "在您的其他 iPad 或 Mac 上，只要在“云端同步”中指定“同一个上层根目录”（不要点进单个 .padnote），App 就会自动扫描所有笔记并进行双向合并更新。",
            "ja" to "ほかの iPad や Mac では、「クラウド同期」で同じ最上位のルートフォルダを指定するだけです（個別の .padnote は選ばないでください）。アプリがすべてのノートを自動で調べ、双方向にマージします。",
            "ko" to "다른 iPad나 Mac에서 '클라우드 동기화'에 같은 최상위 루트 폴더를 지정하기만 하면 됩니다(개별 .padnote는 선택하지 마세요). 앱이 모든 노트를 자동으로 검사하고 양방향으로 병합합니다.",
            "th" to "บน iPad หรือ Mac เครื่องอื่นของคุณ เพียงชี้ “ซิงก์คลาวด์” ไปที่โฟลเดอร์รากระดับบนสุดเดียวกัน (อย่าเลือก .padnote ทีละเล่ม) แอปจะสแกนโน้ตทั้งหมดและผสานการเปลี่ยนแปลงสองทางให้อัตโนมัติ"
        ),
        "sync_a_platform" to mapOf(
            "zh-Hant" to "支援 Android、iPadOS 與 macOS 雙向增量筆跡與圖表合併，各平台均可無縫協同編輯。",
            "en" to "Android, iPadOS and macOS merge ink and charts incrementally in both directions, so you can keep editing seamlessly on any of them.",
            "zh-Hans" to "支持 Android、iPadOS 与 macOS 双向增量笔迹与图表合并，各平台均可无缝协同编辑。",
            "ja" to "Android・iPadOS・macOS の間で、筆跡とグラフを双方向に差分マージします。どのプラットフォームでもシームレスに編集を続けられます。",
            "ko" to "Android, iPadOS, macOS 간에 필기와 차트를 양방향으로 증분 병합하여 어느 플랫폼에서든 끊김 없이 편집할 수 있습니다.",
            "th" to "Android, iPadOS และ macOS ผสานลายเส้นและแผนภูมิแบบเพิ่มทีละส่วนสองทาง คุณจึงแก้ไขต่อได้อย่างราบรื่นบนทุกแพลตฟอร์ม"
        ),
        "sync_a_privacy" to mapOf(
            "zh-Hant" to "沒有第三方伺服器儲存您的手繪或筆記，同步直接由 Apple 系統的 iCloud 傳輸，確保 100% 隱私與資料主權。",
            "en" to "No third-party server stores your drawings or notes. Sync travels directly through Apple's iCloud, keeping your data private and in your own hands.",
            "zh-Hans" to "没有第三方服务器存储您的手绘或笔记，同步直接通过 Apple 系统的 iCloud 传输，确保 100% 隐私与数据主权。",
            "ja" to "手描きやノートをサードパーティのサーバーに保存することはありません。同期は Apple の iCloud を直接経由するので、プライバシーとデータの主権が守られます。",
            "ko" to "손글씨나 노트를 저장하는 외부 서버는 없습니다. 동기화는 Apple iCloud를 통해 직접 전달되므로 개인정보와 데이터 주권이 보장됩니다.",
            "th" to "ไม่มีเซิร์ฟเวอร์ของบุคคลที่สามเก็บลายเส้นหรือโน้ตของคุณ การซิงก์ส่งผ่าน iCloud ของ Apple โดยตรง ข้อมูลของคุณจึงเป็นส่วนตัวและอยู่ในมือคุณเอง"
        ),
        "sync_a_what" to mapOf(
            "zh-Hant" to "本功能採用去中心化的架構。設定 iCloud Drive 或自選資料夾後，每一本筆記都會自動產生對應的 `.padnote` 專屬資料夾（內含手寫向量筆畫與錄音檔等）。這些多出來的 `.padnote` 是維持同步的正常結構，請勿隨意刪除。",
            "en" to "Sync is decentralized. Once you set up iCloud Drive or a folder of your choice, every notebook gets its own `.padnote` folder (holding vector ink, recordings and more). These extra `.padnote` folders are how sync works — please don't delete them.",
            "zh-Hans" to "本功能采用去中心化的架构。设置 iCloud Drive 或自选文件夹后，每一本笔记都会自动生成对应的 `.padnote` 专属文件夹（内含手写矢量笔画与录音文件等）。这些多出来的 `.padnote` 是维持同步的正常结构，请勿随意删除。",
            "ja" to "同期は分散型の仕組みです。iCloud Drive または任意のフォルダを設定すると、ノートごとに専用の `.padnote` フォルダ（ベクター筆跡や録音などを格納）が自動で作られます。この `.padnote` は同期に必要な正常な構成なので、むやみに削除しないでください。",
            "ko" to "동기화는 분산형 구조입니다. iCloud Drive 또는 원하는 폴더를 설정하면 노트마다 전용 `.padnote` 폴더(벡터 필기와 녹음 파일 등 포함)가 자동으로 만들어집니다. 이 `.padnote` 폴더는 동기화를 유지하는 정상적인 구조이므로 함부로 삭제하지 마세요.",
            "th" to "การซิงก์ใช้สถาปัตยกรรมแบบกระจายศูนย์ เมื่อตั้งค่า iCloud Drive หรือโฟลเดอร์ที่คุณเลือก โน้ตแต่ละเล่มจะสร้างโฟลเดอร์ `.padnote` ของตัวเองโดยอัตโนมัติ (เก็บลายเส้นเวกเตอร์ ไฟล์เสียง ฯลฯ) โฟลเดอร์ `.padnote` เหล่านี้เป็นโครงสร้างปกติที่ใช้ซิงก์ โปรดอย่าลบทิ้ง"
        ),
        "sync_account" to mapOf(
            "zh-Hant" to "帳號",
            "en" to "Account",
            "zh-Hans" to "账号",
            "ja" to "アカウント",
            "ko" to "계정",
            "th" to "บัญชี"
        ),
        "sync_already_running" to mapOf(
            "zh-Hant" to "已有一輪同步在進行中",
            "en" to "Another sync is already running",
            "zh-Hans" to "已有一轮同步在进行中",
            "ja" to "別の同期が実行中です",
            "ko" to "다른 동기화가 실행 중입니다",
            "th" to "กำลังซิงค์อยู่แล้ว"
        ),
        "sync_audit_breakdown" to mapOf(
            "zh-Hant" to "使用中 %1@ · 可回收 %2@ · 尚未辨識 %3@",
            "en" to "%1@ in use · %2@ reclaimable · %3@ not yet identified",
            "zh-Hans" to "使用中 %1@ · 可回收 %2@ · 尚未辨識 %3@",
            "ja" to "使用中 %1@ 件・回収可能 %2@ 件・未識別 %3@ 件",
            "ko" to "사용 중 %1@ · 회수 가능 %2@ · 미식별 %3@",
            "th" to "ใช้งาน %1@ · กู้คืนได้ %2@ · ยังระบุไม่ได้ %3@"
        ),
        "sync_audit_files" to mapOf(
            "zh-Hant" to "雲端檔案",
            "en" to "Cloud files",
            "zh-Hans" to "云端档案",
            "ja" to "クラウドのファイル",
            "ko" to "클라우드 파일",
            "th" to "ไฟล์บนคลาวด์"
        ),
        "sync_audit_unknown_hint" to mapOf(
            "zh-Hant" to "「尚未辨識」通常代表這些是別台裝置建立的，而這台還沒拉到索引。系統絕不會自動刪除它們。",
            "en" to "Not yet identified usually means another device created these and this device has not pulled the index yet. They are never deleted automatically.",
            "zh-Hans" to "「尚未辨识」通常代表这些是别台设备建立的，而这台还没拉到索引。系统绝不会自动删除它们。",
            "ja" to "未識別は通常、他の端末が作成したものをこの端末がまだ取得していない状態です。自動削除されることはありません。",
            "ko" to "미식별은 보통 다른 기기가 만든 것을 이 기기가 아직 받지 못한 상태입니다. 자동으로 삭제되지 않습니다.",
            "th" to "ยังระบุไม่ได้ มักหมายถึงอุปกรณ์อื่นสร้างไว้และเครื่องนี้ยังไม่ได้ดึงดัชนีมา ระบบจะไม่ลบอัตโนมัติ"
        ),
        "sync_cancelled" to mapOf(
            "zh-Hant" to "已中斷同步",
            "en" to "Sync stopped",
            "zh-Hans" to "已中断同步",
            "ja" to "同期を中断しました",
            "ko" to "동기화를 중단했습니다",
            "th" to "หยุดการซิงก์แล้ว"
        ),
        "sync_choose_folder" to mapOf(
            "zh-Hant" to "iCloud 或本機資料夾同步",
            "en" to "Choose Sync Folder",
            "zh-Hans" to "选择同步文件夹",
            "ja" to "同期フォルダを選択",
            "ko" to "동기화 폴더 선택",
            "th" to "เลือกโฟลเดอร์ซิงก์"
        ),
        "sync_configured_pending" to mapOf(
            "zh-Hant" to "已設定（待同步）",
            "en" to "Set up (waiting to sync)",
            "zh-Hans" to "已设置（待同步）",
            "ja" to "設定済み（同期待ち）",
            "ko" to "설정됨 (동기화 대기)",
            "th" to "ตั้งค่าแล้ว (รอซิงก์)"
        ),
        "sync_destination" to mapOf(
            "zh-Hant" to "同步目的地",
            "en" to "Destination",
            "zh-Hans" to "同步目的地",
            "ja" to "保存先",
            "ko" to "저장 위치",
            "th" to "ปลายทาง"
        ),
        "sync_destination_appdata" to mapOf(
            "zh-Hant" to "Google Drive · 應用程式資料夾（只有這個 App 看得到）",
            "en" to "Google Drive · app data folder (only this app can see it)",
            "zh-Hans" to "Google Drive · 应用数据文件夹（只有这个 App 看得到）",
            "ja" to "Google ドライブ · アプリデータフォルダ（このアプリだけが見えます）",
            "ko" to "Google 드라이브 · 앱 데이터 폴더(이 앱만 볼 수 있음)",
            "th" to "Google ไดรฟ์ · โฟลเดอร์ข้อมูลแอป (มีเพียงแอปนี้ที่เห็น)"
        ),
        "sync_done" to mapOf(
            "zh-Hant" to "同步完成",
            "en" to "Sync complete",
            "zh-Hans" to "同步完成",
            "ja" to "同期が完了しました",
            "ko" to "동기화 완료",
            "th" to "ซิงค์เสร็จแล้ว"
        ),
        "sync_explainer" to mapOf(
            "zh-Hant" to "同步由你自己的雲端硬碟負責（iCloud Drive、Google Drive、Dropbox…）。沒有帳號、沒有我們的伺服器。兩台裝置指到同一個資料夾就會互相同步。",
            "en" to "Syncing is handled by your own cloud drive (iCloud Drive, Google Drive, Dropbox…). No account, no server of ours. Point two devices at the same folder and they stay in sync.",
            "zh-Hans" to "同步由你自己的云端硬盘负责（iCloud Drive、Google Drive、Dropbox…）。没有账号、没有我们的服务器。两台设备指到同一个文件夹就会互相同步。",
            "ja" to "同期はお使いのクラウドドライブ（iCloud Drive、Google Drive、Dropbox など）が行います。アカウントも当方のサーバーもありません。2 台の端末を同じフォルダに向けるだけで同期されます。",
            "ko" to "동기화는 사용자의 클라우드 드라이브(iCloud Drive, Google Drive, Dropbox 등)가 담당합니다. 계정도, 저희 서버도 없습니다. 두 기기를 같은 폴더로 지정하면 서로 동기화됩니다.",
            "th" to "การซิงก์ทำโดยคลาวด์ไดรฟ์ของคุณเอง (iCloud Drive, Google Drive, Dropbox ฯลฯ) ไม่มีบัญชีและไม่มีเซิร์ฟเวอร์ของเรา ตั้งให้สองอุปกรณ์ชี้ไปยังโฟลเดอร์เดียวกันก็ซิงก์กันได้"
        ),
        "sync_explainer_folder" to mapOf(
            "zh-Hant" to "透過你指定的 iCloud 或本機資料夾雙向同步筆記與手寫，內容不經過我們。",
            "en" to "Two-way sync of notes and handwriting through the iCloud or local folder you chose — nothing passes through us.",
            "zh-Hans" to "通过你指定的 iCloud 或本地文件夹双向同步笔记与手写，内容不经过我们。",
            "ja" to "指定した iCloud またはローカルのフォルダを介してノートと手書きを双方向に同期します。当方を経由することはありません。",
            "ko" to "선택한 iCloud 또는 로컬 폴더를 통해 노트와 필기를 양방향으로 동기화합니다. 내용은 당사를 거치지 않습니다.",
            "th" to "ซิงก์โน้ตและลายมือสองทางผ่านโฟลเดอร์ iCloud หรือโฟลเดอร์ในเครื่องที่คุณเลือก โดยไม่ผ่านเรา"
        ),
        "sync_explainer_none" to mapOf(
            "zh-Hant" to "支援 Google Drive 跨平台同步，或 iCloud Drive 資料夾免帳號同步。",
            "en" to "Sync across platforms with Google Drive, or use an iCloud Drive folder with no account at all.",
            "zh-Hans" to "支持 Google Drive 跨平台同步，或 iCloud Drive 文件夹免账号同步。",
            "ja" to "Google Drive でのクロスプラットフォーム同期、または iCloud Drive フォルダを使ったアカウント不要の同期に対応しています。",
            "ko" to "Google Drive로 플랫폼 간 동기화하거나, 계정 없이 iCloud Drive 폴더를 사용할 수 있습니다.",
            "th" to "ซิงก์ข้ามแพลตฟอร์มด้วย Google Drive หรือใช้โฟลเดอร์ iCloud Drive โดยไม่ต้องมีบัญชี"
        ),
        "sync_fail_cannot_read" to mapOf(
            "zh-Hant" to "無法讀取 %@",
            "en" to "Cannot read %@",
            "zh-Hans" to "无法读取 %@",
            "ja" to "%@ を読み込めません",
            "ko" to "%@을(를) 읽을 수 없습니다",
            "th" to "อ่าน %@ ไม่ได้"
        ),
        "sync_fail_cannot_write" to mapOf(
            "zh-Hant" to "無法寫入 %@",
            "en" to "Cannot write %@",
            "zh-Hans" to "无法写入 %@",
            "ja" to "%@ に書き込めません",
            "ko" to "%@에 쓸 수 없습니다",
            "th" to "เขียน %@ ไม่ได้"
        ),
        "sync_fail_delete" to mapOf(
            "zh-Hant" to "刪除失敗：%@",
            "en" to "Delete failed: %@",
            "zh-Hans" to "删除失败：%@",
            "ja" to "削除に失敗しました：%@",
            "ko" to "삭제 실패: %@",
            "th" to "ลบไม่สำเร็จ: %@"
        ),
        "sync_fail_export" to mapOf(
            "zh-Hant" to "匯出失敗（%1@）：%2@",
            "en" to "Export failed (%1@): %2@",
            "zh-Hans" to "导出失败（%1@）：%2@",
            "ja" to "書き出しに失敗しました（%1@）：%2@",
            "ko" to "내보내기 실패 (%1@): %2@",
            "th" to "ส่งออกไม่สำเร็จ (%1@): %2@"
        ),
        "sync_fail_file_downloading" to mapOf(
            "zh-Hant" to "檔案正在從 iCloud 雲端下載中，請稍候重試",
            "en" to "The file is being downloaded from iCloud. Try again in a moment.",
            "zh-Hans" to "文件正在从 iCloud 云端下载中，请稍候重试",
            "ja" to "ファイルを iCloud からダウンロード中です。しばらくしてからもう一度お試しください。",
            "ko" to "파일을 iCloud에서 다운로드하는 중입니다. 잠시 후 다시 시도하세요.",
            "th" to "กำลังดาวน์โหลดไฟล์จาก iCloud โปรดลองอีกครั้งในอีกสักครู่"
        ),
        "sync_fail_icloud_downloading" to mapOf(
            "zh-Hant" to "iCloud 雲端檔案下載中，請稍候重試",
            "en" to "The iCloud file is still downloading. Try again in a moment.",
            "zh-Hans" to "iCloud 云端文件下载中，请稍候重试",
            "ja" to "iCloud のファイルをダウンロード中です。しばらくしてからもう一度お試しください。",
            "ko" to "iCloud 파일을 다운로드하는 중입니다. 잠시 후 다시 시도하세요.",
            "th" to "กำลังดาวน์โหลดไฟล์จาก iCloud โปรดลองอีกครั้งในอีกสักครู่"
        ),
        "sync_fail_no_manifest" to mapOf(
            "zh-Hant" to "套件缺少 manifest.json，已清理無效殘留目錄",
            "en" to "The package has no manifest.json; the invalid leftover folder was removed",
            "zh-Hans" to "套件缺少 manifest.json，已清理无效残留目录",
            "ja" to "パッケージに manifest.json がないため、不要なフォルダを削除しました",
            "ko" to "패키지에 manifest.json이 없어 남은 잘못된 폴더를 정리했습니다",
            "th" to "แพ็กเกจไม่มี manifest.json จึงลบโฟลเดอร์ที่ไม่ถูกต้องที่เหลืออยู่แล้ว"
        ),
        "sync_fail_unpack" to mapOf(
            "zh-Hant" to "解開套件失敗：%@",
            "en" to "Could not unpack the package: %@",
            "zh-Hans" to "解开套件失败：%@",
            "ja" to "パッケージを展開できませんでした：%@",
            "ko" to "패키지를 풀지 못했습니다: %@",
            "th" to "แตกแพ็กเกจไม่สำเร็จ: %@"
        )
    )

    private fun part27(): Map<String, Map<String, String>> = mapOf(
        "sync_fail_unpack_cloud" to mapOf(
            "zh-Hant" to "解開雲端 .padnote 失敗：%@",
            "en" to "Could not unpack the cloud .padnote: %@",
            "zh-Hans" to "解开云端 .padnote 失败：%@",
            "ja" to "クラウド上の .padnote を展開できませんでした：%@",
            "ko" to "클라우드 .padnote를 풀지 못했습니다: %@",
            "th" to "แตก .padnote บนคลาวด์ไม่สำเร็จ: %@"
        ),
        "sync_failed" to mapOf(
            "zh-Hant" to "同步失敗：%@",
            "en" to "Sync failed: %@",
            "zh-Hans" to "同步失败：%@",
            "ja" to "同期に失敗しました：%@",
            "ko" to "동기화 실패: %@",
            "th" to "ซิงค์ไม่สำเร็จ: %@"
        ),
        "sync_folder_cancel_setting" to mapOf(
            "zh-Hant" to "取消已設定的資料夾",
            "en" to "Unlink Configured Folder",
            "zh-Hans" to "取消已设置的文件夹",
            "ja" to "設定済みフォルダの解除",
            "ko" to "설정된 폴더 해제",
            "th" to "ยกเลิกการตั้งค่าโฟลเดอร์"
        ),
        "sync_folder_desc" to mapOf(
            "zh-Hant" to "指到 iCloud Drive 或 Google Drive 的資料夾，兩台裝置就會互相同步",
            "en" to "Point two devices at the same iCloud Drive or Google Drive folder",
            "zh-Hans" to "指到 iCloud Drive 或 Google Drive 的文件夹，两台设备就会互相同步",
            "ja" to "iCloud Drive や Google Drive の同じフォルダを 2 台の端末に指定",
            "ko" to "두 기기를 같은 iCloud Drive 또는 Google Drive 폴더로 지정",
            "th" to "ตั้งให้สองอุปกรณ์ชี้ไปยังโฟลเดอร์ iCloud Drive หรือ Google Drive เดียวกัน"
        ),
        "sync_folder_label" to mapOf(
            "zh-Hant" to "iCloud／資料夾",
            "en" to "iCloud / folder",
            "zh-Hans" to "iCloud／文件夹",
            "ja" to "iCloud／フォルダ",
            "ko" to "iCloud/폴더",
            "th" to "iCloud / โฟลเดอร์"
        ),
        "sync_folder_manual_while_drive" to mapOf(
            "zh-Hant" to "自動同步由 Google Drive 負責。這個資料夾是手動備份 —— 按「立即同步」才會更新。",
            "en" to "Automatic sync is handled by Google Drive. This folder is a manual backup — tap Sync now to update it.",
            "zh-Hans" to "自动同步由 Google Drive 负责。这个文件夹是手动备份 —— 按「立即同步」才会更新。",
            "ja" to "自動同期は Google Drive が担当します。このフォルダは手動バックアップです —「今すぐ同期」で更新してください。",
            "ko" to "자동 동기화는 Google Drive가 담당합니다. 이 폴더는 수동 백업입니다 — ‘지금 동기화’로 갱신하세요.",
            "th" to "การซิงค์อัตโนมัติใช้ Google Drive โฟลเดอร์นี้เป็นสำรองแบบแมนนวล — แตะ ซิงค์ทันที เพื่ออัปเดต"
        ),
        "sync_folder_path" to mapOf(
            "zh-Hant" to "資料夾路徑",
            "en" to "Folder",
            "zh-Hans" to "资料夹路径",
            "ja" to "フォルダ",
            "ko" to "폴더",
            "th" to "โฟลเดอร์"
        ),
        "sync_folder_pending" to mapOf(
            "zh-Hant" to "已設定資料夾（待同步）",
            "en" to "Folder set (waiting to sync)",
            "zh-Hans" to "已设置文件夹（待同步）",
            "ja" to "フォルダ設定済み（同期待ち）",
            "ko" to "폴더 설정됨 (동기화 대기)",
            "th" to "ตั้งค่าโฟลเดอร์แล้ว (รอซิงก์)"
        ),
        "sync_folder_placeholder" to mapOf(
            "zh-Hant" to "<資料夾>",
            "en" to "<folder>",
            "zh-Hans" to "<文件夹>",
            "ja" to "<フォルダ>",
            "ko" to "<폴더>",
            "th" to "<โฟลเดอร์>"
        ),
        "sync_folder_syncing" to mapOf(
            "zh-Hant" to "iCloud / 資料夾同步中...",
            "en" to "Syncing iCloud / folder…",
            "zh-Hans" to "iCloud / 文件夹同步中…",
            "ja" to "iCloud / フォルダを同期中…",
            "ko" to "iCloud / 폴더 동기화 중…",
            "th" to "กำลังซิงก์ iCloud / โฟลเดอร์…"
        ),
        "sync_folder_unlink_confirm_desc" to mapOf(
            "zh-Hant" to "這只會取消與該資料夾的同步連結，不會刪除您本機或該資料夾內的任何筆記檔案。",
            "en" to "This will only unlink the folder from syncing. It will not delete any notes on your device or in the folder.",
            "zh-Hans" to "这只会取消与该文件夹的同步链接，不会删除您本机或该文件夹内的任何笔记文件。",
            "ja" to "同期のリンクを解除するだけで、端末内やフォルダ内のノートが削除されることはありません。",
            "ko" to "동기화 연결만 해제되며 기기나 해당 폴더의 노트 파일은 삭제되지 않습니다.",
            "th" to "การดำเนินการนี้จะยกเลิกการเชื่อมโยงการซิงก์เท่านั้น และจะไม่ลบโน้ตในเครื่องหรือในโฟลเดอร์ของคุณ"
        ),
        "sync_folder_unlink_confirm_title" to mapOf(
            "zh-Hant" to "取消設定同步資料夾？",
            "en" to "Unlink Sync Folder?",
            "zh-Hans" to "取消设置同步文件夹？",
            "ja" to "同期フォルダの設定を解除しますか？",
            "ko" to "동기화 폴더 설정을 해제하시겠습니까?",
            "th" to "ยกเลิกการตั้งค่าโฟลเดอร์ซิงก์หรือไม่?"
        ),
        "sync_gdrive_syncing" to mapOf(
            "zh-Hant" to "Google Drive 同步中…",
            "en" to "Syncing Google Drive…",
            "zh-Hans" to "Google Drive 同步中…",
            "ja" to "Google ドライブを同期中…",
            "ko" to "Google 드라이브 동기화 중…",
            "th" to "กำลังซิงก์ Google Drive…"
        ),
        "sync_google_authorized" to mapOf(
            "zh-Hant" to "Google 帳號授權成功，正在同步...",
            "en" to "Google account authorized. Syncing…",
            "zh-Hans" to "Google 帐号授权成功，正在同步…",
            "ja" to "Google アカウントを承認しました。同期中…",
            "ko" to "Google 계정 인증 완료. 동기화 중…",
            "th" to "อนุญาตบัญชี Google แล้ว กำลังซิงก์…"
        ),
        "sync_interrupted" to mapOf(
            "zh-Hant" to "已中斷同步",
            "en" to "Sync interrupted",
            "zh-Hans" to "已中断同步",
            "ja" to "同期が中断されました",
            "ko" to "동기화가 중단되었습니다",
            "th" to "การซิงก์ถูกขัดจังหวะ"
        ),
        "sync_last_at" to mapOf(
            "zh-Hant" to "上次同步",
            "en" to "Last synced",
            "zh-Hans" to "上次同步",
            "ja" to "最終同期",
            "ko" to "마지막 동기화",
            "th" to "ซิงค์ล่าสุด"
        ),
        "sync_logs_title" to mapOf(
            "zh-Hant" to "同步日誌 (工程診斷)",
            "en" to "Sync Logs (Diagnostics)",
            "zh-Hans" to "同步日志 (工程诊断)",
            "ja" to "同期ログ（診断）",
            "ko" to "동기화 로그 (진단)",
            "th" to "บันทึกการซิงค์ (การวินิจฉัย)"
        ),
        "sync_needs_attention" to mapOf(
            "zh-Hant" to "%@ 在兩台裝置上都被改過，已保留雲端那份，請自行確認",
            "en" to "%@ was changed on both devices; the cloud copy was kept — please check",
            "zh-Hans" to "%@ 在两台设备上都被改过，已保留云端那份，请自行确认",
            "ja" to "%@ は両方の端末で変更されています。クラウド側を残しました。ご確認ください",
            "ko" to "%@ 이(가) 양쪽 기기에서 모두 변경되었습니다. 클라우드 사본을 유지했습니다. 확인해 주세요",
            "th" to "%@ ถูกแก้ไขบนทั้งสองอุปกรณ์ ระบบเก็บสำเนาบนคลาวด์ไว้ โปรดตรวจสอบ"
        ),
        "sync_needs_reauth" to mapOf(
            "zh-Hant" to "登入狀態已過期，請重新登入",
            "en" to "Session expired — please sign in again",
            "zh-Hans" to "登录状态已过期，请重新登录",
            "ja" to "セッションの有効期限が切れました。もう一度ログインしてください",
            "ko" to "세션이 만료되었습니다. 다시 로그인해 주세요",
            "th" to "เซสชันหมดอายุ โปรดลงชื่อเข้าใช้ใหม่"
        ),
        "sync_never" to mapOf(
            "zh-Hant" to "尚未同步過",
            "en" to "Not yet",
            "zh-Hans" to "尚未同步过",
            "ja" to "まだありません",
            "ko" to "아직 없음",
            "th" to "ยังไม่เคย"
        ),
        "sync_not_configured" to mapOf(
            "zh-Hant" to "尚未選擇資料夾",
            "en" to "No folder chosen yet",
            "zh-Hans" to "尚未选择文件夹",
            "ja" to "フォルダ未選択",
            "ko" to "폴더를 아직 선택하지 않음",
            "th" to "ยังไม่ได้เลือกโฟลเดอร์"
        ),
        "sync_not_set_up" to mapOf(
            "zh-Hant" to "尚未設定同步（點一下設定）",
            "en" to "Sync not set up yet (tap to set it up)",
            "zh-Hans" to "尚未设置同步（点一下设置）",
            "ja" to "同期は未設定です（タップして設定）",
            "ko" to "동기화가 아직 설정되지 않았습니다(탭하여 설정)",
            "th" to "ยังไม่ได้ตั้งค่าการซิงก์ (แตะเพื่อตั้งค่า)"
        ),
        "sync_now" to mapOf(
            "zh-Hant" to "立即同步",
            "en" to "Sync Now",
            "zh-Hans" to "立即同步",
            "ja" to "今すぐ同期",
            "ko" to "지금 동기화",
            "th" to "ซิงก์เดี๋ยวนี้"
        ),
        "sync_q_how" to mapOf(
            "zh-Hant" to "如何與其他裝置雙向連動？",
            "en" to "How does it link my devices together?",
            "zh-Hans" to "如何与其他设备双向联动？",
            "ja" to "他の端末とどのように連携しますか？",
            "ko" to "다른 기기와 어떻게 연동되나요?",
            "th" to "เชื่อมกับอุปกรณ์อื่นอย่างไร"
        ),
        "sync_q_privacy" to mapOf(
            "zh-Hant" to "完全隱私，無須註冊帳號",
            "en" to "Fully private, no account needed",
            "zh-Hans" to "完全隐私，无须注册账号",
            "ja" to "完全にプライベート、アカウント不要",
            "ko" to "완전한 프라이버시, 계정 불필요",
            "th" to "เป็นส่วนตัวทั้งหมด ไม่ต้องสมัครบัญชี"
        ),
        "sync_q_what" to mapOf(
            "zh-Hant" to "這個功能在同步什麼？",
            "en" to "What does this sync?",
            "zh-Hans" to "这个功能在同步什么？",
            "ja" to "何が同期されますか？",
            "ko" to "무엇이 동기화되나요?",
            "th" to "ฟังก์ชันนี้ซิงก์อะไรบ้าง"
        ),
        "sync_reclaim" to mapOf(
            "zh-Hant" to "回收已刪除的檔案",
            "en" to "Reclaim deleted files",
            "zh-Hans" to "回收已删除的档案",
            "ja" to "削除済みファイルを回収",
            "ko" to "삭제된 파일 회수",
            "th" to "เรียกคืนไฟล์ที่ลบแล้ว"
        ),
        "sync_reclaim_confirm_body" to mapOf(
            "zh-Hant" to "這會在你的其他所有裝置確認之後，刪除回收桶保留期已過的筆記本留在雲端的檔案。仍在回收桶裡的筆記本會保留。這台裝置尚未辨識的檔案絕不會被動到 —— 它們通常屬於別台裝置剛建立的筆記本。",
            "en" to "This deletes the cloud files of notebooks whose time in the Trash has run out, once all your other devices have confirmed. Notebooks still in the Trash are kept. Files this device has not identified yet are never touched — they usually belong to a notebook another device just created.",
            "zh-Hans" to "这会在你的其他所有设备确认之后，删除回收站保留期已过的笔记本留在云端的文件。仍在回收站里的笔记本会保留。这台设备尚未识别的文件绝不会被动到 —— 它们通常属于别的设备刚创建的笔记本。",
            "ja" to "ゴミ箱での保持期間が過ぎたノートのクラウド上のファイルを、他のすべてのデバイスが確認した後に削除します。ゴミ箱に残っているノートはそのまま保持されます。このデバイスがまだ識別していないファイルには一切触れません — 多くは別のデバイスが作成したばかりのノートのものです。",
            "ko" to "휴지통 보관 기간이 지난 노트의 클라우드 파일을, 다른 모든 기기가 확인한 후에 삭제합니다. 휴지통에 남아 있는 노트는 그대로 유지됩니다. 이 기기가 아직 식별하지 못한 파일은 절대 건드리지 않습니다 — 대부분 다른 기기가 방금 만든 노트의 파일입니다.",
            "th" to "การดำเนินการนี้จะลบไฟล์บนคลาวด์ของสมุดบันทึกที่หมดเวลาในถังขยะแล้ว หลังจากอุปกรณ์อื่นทั้งหมดของคุณยืนยันแล้ว สมุดบันทึกที่ยังอยู่ในถังขยะจะถูกเก็บไว้ ไฟล์ที่อุปกรณ์นี้ยังไม่รู้จักจะไม่ถูกแตะต้อง — มักเป็นของสมุดบันทึกที่อุปกรณ์อื่นเพิ่งสร้าง"
        ),
        "sync_reclaim_done" to mapOf(
            "zh-Hant" to "已回收 %1@ 個檔案。",
            "en" to "Reclaimed %1@ files.",
            "zh-Hans" to "已回收 %1@ 个档案。",
            "ja" to "%1@ 件を回収しました。",
            "ko" to "%1@개를 회수했습니다.",
            "th" to "เรียกคืน %1@ ไฟล์แล้ว"
        ),
        "sync_reclaim_nothing" to mapOf(
            "zh-Hant" to "暫時沒有可回收的檔案。回收桶裡的筆記本會保留到保留期結束。",
            "en" to "Nothing to reclaim yet. Notebooks in the Trash are kept until their time runs out.",
            "zh-Hans" to "暂时没有可回收的文件。回收站里的笔记本会保留到保留期结束。",
            "ja" to "まだ回収するものはありません。ゴミ箱のノートは保持期間が過ぎるまで残ります。",
            "ko" to "아직 회수할 항목이 없습니다. 휴지통의 노트는 보관 기간이 끝날 때까지 유지됩니다.",
            "th" to "ยังไม่มีอะไรให้เก็บกู้ สมุดบันทึกในถังขยะจะถูกเก็บไว้จนกว่าจะหมดเวลา"
        ),
        "sync_reclaim_partial" to mapOf(
            "zh-Hant" to "已回收 %1@ 個、失敗 %2@ 個 —— 其餘下一輪再試。",
            "en" to "Reclaimed %1@, failed %2@ — the rest will be retried.",
            "zh-Hans" to "已回收 %1@ 个、失败 %2@ 个 —— 其余下一轮再试。",
            "ja" to "%1@ 件回収、%2@ 件失敗 —— 残りは次回再試行します。",
            "ko" to "%1@개 회수, %2@개 실패 — 나머지는 다시 시도합니다.",
            "th" to "เรียกคืน %1@ ล้มเหลว %2@ — ที่เหลือจะลองใหม่"
        ),
        "sync_reclaim_running" to mapOf(
            "zh-Hant" to "回收中…",
            "en" to "Reclaiming…",
            "zh-Hans" to "回收中…",
            "ja" to "回収中…",
            "ko" to "회수 중…",
            "th" to "กำลังเรียกคืน…"
        ),
        "sync_recording_in_progress" to mapOf(
            "zh-Hant" to "同步錄音中",
            "en" to "Sync Recording",
            "zh-Hans" to "同步录音中",
            "ja" to "同期録音中",
            "ko" to "동기화 녹음 중",
            "th" to "กำลังบันทึกเสียงพร้อมกัน"
        ),
        "sync_reset_cloud" to mapOf(
            "zh-Hant" to "重置雲端同步",
            "en" to "Reset cloud sync",
            "zh-Hans" to "重置云端同步",
            "ja" to "クラウド同期をリセット",
            "ko" to "클라우드 동기화 초기화",
            "th" to "รีเซ็ตการซิงค์คลาวด์"
        ),
        "sync_reset_cloud_busy" to mapOf(
            "zh-Hant" to "有一輪同步正在跑，等它結束再試。",
            "en" to "A sync is running — wait for it to finish, then try again.",
            "zh-Hans" to "有一轮同步正在跑，等它结束再试。",
            "ja" to "同期の実行中です。終わってからもう一度お試しください。",
            "ko" to "동기화가 실행 중입니다. 끝난 뒤 다시 시도하세요.",
            "th" to "กำลังซิงค์อยู่ โปรดรอให้เสร็จแล้วลองใหม่"
        ),
        "sync_reset_cloud_confirm_body" to mapOf(
            "zh-Hant" to "這會永久刪除本 App 存放在你 Drive 裡的所有資料。本機的筆記不會被動到，下一輪同步會重新上傳。只存在雲端的內容（某台你之後沒再打開過的裝置上的修改）會消失。",
            "en" to "This permanently deletes everything this app stores in your Drive. Notes on this device are not touched and will be re-uploaded on the next sync. Anything that exists only in the cloud — edits from a device you have not opened since — will be lost.",
            "zh-Hans" to "这会永久删除本应用存放在你 Drive 里的所有资料。本机的笔记不会被动到，下一轮同步会重新上传。只存在云端的内容（某台你之后没再打开过的设备上的修改）会消失。",
            "ja" to "このアプリが Drive に保存したデータをすべて完全に削除します。この端末のノートは変更されず、次回の同期で再アップロードされます。クラウドにしかない内容（その後開いていない端末での編集）は失われます。",
            "ko" to "이 앱이 Drive에 저장한 모든 데이터를 영구 삭제합니다. 이 기기의 노트는 그대로이며 다음 동기화에서 다시 업로드됩니다. 클라우드에만 있는 내용은 사라집니다.",
            "th" to "การดำเนินการนี้จะลบข้อมูลทั้งหมดที่แอปเก็บไว้ใน Drive อย่างถาวร บันทึกในเครื่องนี้จะไม่ถูกแตะต้องและจะอัปโหลดใหม่ในการซิงค์ครั้งถัดไป สิ่งที่มีอยู่เฉพาะบนคลาวด์จะสูญหาย"
        ),
        "sync_reset_cloud_confirm_title" to mapOf(
            "zh-Hant" to "要重置雲端同步嗎？",
            "en" to "Reset cloud sync?",
            "zh-Hans" to "要重置云端同步吗？",
            "ja" to "クラウド同期をリセットしますか？",
            "ko" to "클라우드 동기화를 초기화할까요?",
            "th" to "รีเซ็ตการซิงค์คลาวด์?"
        ),
        "sync_reset_cloud_done" to mapOf(
            "zh-Hant" to "雲端已清空（%1@ 個檔案）。下一輪同步會把本機的筆記當成新的基準傳上去。",
            "en" to "Cloud cleared (%1@ files). The next sync uploads this device's notes as the new baseline.",
            "zh-Hans" to "云端已清空（%1@ 个档案）。下一轮同步会把本机的笔记当成新的基准传上去。",
            "ja" to "クラウドを消去しました（%1@ 件）。次の同期でこの端末のノートが新しい基準になります。",
            "ko" to "클라우드를 지웠습니다(%1@개). 다음 동기화에서 이 기기의 노트가 새 기준이 됩니다.",
            "th" to "ล้างคลาวด์แล้ว (%1@ ไฟล์) การซิงค์ครั้งถัดไปจะอัปโหลดบันทึกของเครื่องนี้เป็นค่าตั้งต้นใหม่"
        ),
        "sync_reset_cloud_partial" to mapOf(
            "zh-Hant" to "已刪除 %1@ 個、失敗 %2@ 個 —— 雲端是半清空的狀態，請再跑一次。",
            "en" to "Deleted %1@, failed %2@ — the cloud is half-cleared. Run it again.",
            "zh-Hans" to "已删除 %1@ 个、失败 %2@ 个 —— 云端是半清空的状态，请再跑一次。",
            "ja" to "%1@ 件削除、%2@ 件失敗 —— クラウドは中途半端な状態です。もう一度実行してください。",
            "ko" to "%1@개 삭제, %2@개 실패 — 클라우드가 절반만 지워졌습니다. 다시 실행하세요.",
            "th" to "ลบแล้ว %1@ ล้มเหลว %2@ — คลาวด์ถูกล้างเพียงบางส่วน โปรดลองอีกครั้ง"
        ),
        "sync_reset_cloud_running" to mapOf(
            "zh-Hant" to "正在清除雲端資料…",
            "en" to "Clearing cloud data…",
            "zh-Hans" to "正在清除云端资料…",
            "ja" to "クラウドデータを削除中…",
            "ko" to "클라우드 데이터 삭제 중…",
            "th" to "กำลังลบข้อมูลคลาวด์…"
        ),
        "sync_result" to mapOf(
            "zh-Hant" to "上傳 %1@、下載 %2@",
            "en" to "%1@ uploaded, %2@ downloaded",
            "zh-Hans" to "上传 %1@、下载 %2@",
            "ja" to "%1@ 件アップロード、%2@ 件ダウンロード",
            "ko" to "%1@개 업로드, %2@개 다운로드",
            "th" to "อัปโหลด %1@ ดาวน์โหลด %2@"
        ),
        "sync_section" to mapOf(
            "zh-Hant" to "雲端同步",
            "en" to "Cloud Sync",
            "zh-Hans" to "云端同步",
            "ja" to "クラウド同期",
            "ko" to "클라우드 동기화",
            "th" to "ซิงก์คลาวด์"
        ),
        "sync_signed_in_busy" to mapOf(
            "zh-Hant" to "已登入成功（目前正有其他同步執行中）",
            "en" to "Signed in (another sync is already running)",
            "zh-Hans" to "已登录成功（目前有其他同步正在执行）",
            "ja" to "サインインしました（別の同期が実行中です）",
            "ko" to "로그인했습니다 (다른 동기화가 실행 중입니다)",
            "th" to "ลงชื่อเข้าใช้แล้ว (มีการซิงก์อื่นกำลังทำงานอยู่)"
        ),
        "sync_snapshot_timeout" to mapOf(
            "zh-Hant" to "雲端快照更新逾時",
            "en" to "Timed out refreshing the cloud snapshot",
            "zh-Hans" to "云端快照更新超时",
            "ja" to "クラウドスナップショットの更新がタイムアウトしました",
            "ko" to "클라우드 스냅샷 갱신 시간이 초과되었습니다",
            "th" to "การอัปเดตสแนปช็อตบนคลาวด์หมดเวลา"
        ),
        "sync_status" to mapOf(
            "zh-Hant" to "狀態",
            "en" to "Status",
            "zh-Hans" to "状态",
            "ja" to "状態",
            "ko" to "상태",
            "th" to "สถานะ"
        ),
        "sync_status_error" to mapOf(
            "zh-Hant" to "同步發生錯誤",
            "en" to "Sync error",
            "zh-Hans" to "同步发生错误",
            "ja" to "同期エラーが発生しました",
            "ko" to "동기화 오류가 발생했습니다",
            "th" to "เกิดข้อผิดพลาดในการซิงก์"
        ),
        "sync_status_failed" to mapOf(
            "zh-Hant" to "同步失敗",
            "en" to "Sync failed",
            "zh-Hans" to "同步失败",
            "ja" to "同期に失敗しました",
            "ko" to "동기화 실패",
            "th" to "ซิงก์ล้มเหลว"
        ),
        "sync_timeout_folder" to mapOf(
            "zh-Hant" to "同步逾時，請確認網路連線或 iCloud 狀態後重試",
            "en" to "Sync timed out. Check your connection or iCloud status and try again.",
            "zh-Hans" to "同步超时，请确认网络连接或 iCloud 状态后重试",
            "ja" to "同期がタイムアウトしました。ネットワーク接続または iCloud の状態を確認して、もう一度お試しください。",
            "ko" to "동기화 시간이 초과되었습니다. 네트워크 연결 또는 iCloud 상태를 확인한 후 다시 시도하세요.",
            "th" to "การซิงก์หมดเวลา โปรดตรวจสอบการเชื่อมต่อหรือสถานะ iCloud แล้วลองอีกครั้ง"
        ),
        "sync_timeout_network" to mapOf(
            "zh-Hant" to "同步逾時，請確認網路連線後重試",
            "en" to "Sync timed out. Check your connection and try again.",
            "zh-Hans" to "同步超时，请确认网络连接后重试",
            "ja" to "同期がタイムアウトしました。ネットワーク接続を確認して、もう一度お試しください。",
            "ko" to "동기화 시간이 초과되었습니다. 네트워크 연결을 확인한 후 다시 시도하세요.",
            "th" to "การซิงก์หมดเวลา โปรดตรวจสอบการเชื่อมต่ออินเทอร์เน็ตแล้วลองอีกครั้ง"
        ),
        "sync_transcript_lag" to mapOf(
            "zh-Hant" to "轉錄落後 %@ 秒",
            "en" to "transcript %@ s behind",
            "zh-Hans" to "转录落后 %@ 秒",
            "ja" to "文字起こしが %@ 秒遅れ",
            "ko" to "받아쓰기 %@초 지연",
            "th" to "การถอดเสียงช้ากว่า %@ วินาที"
        ),
        "sync_up_to_date" to mapOf(
            "zh-Hant" to "已是最新",
            "en" to "Already up to date",
            "zh-Hans" to "已是最新",
            "ja" to "最新の状態です",
            "ko" to "이미 최신 상태",
            "th" to "เป็นเวอร์ชันล่าสุดแล้ว"
        ),
        "sync_x_platform_title" to mapOf(
            "zh-Hant" to "跨平台同步支援",
            "en" to "Cross-platform sync",
            "zh-Hans" to "跨平台同步支持",
            "ja" to "クロスプラットフォーム同期",
            "ko" to "플랫폼 간 동기화",
            "th" to "การซิงก์ข้ามแพลตฟอร์ม"
        ),
        "syncing" to mapOf(
            "zh-Hant" to "同步中…",
            "en" to "Syncing…",
            "zh-Hans" to "同步中…",
            "ja" to "同期中…",
            "ko" to "동기화 중…",
            "th" to "กำลังซิงค์…"
        ),
        "system_diagnostics" to mapOf(
            "zh-Hant" to "系統診斷與版本資訊",
            "en" to "Diagnostics & Version Info",
            "zh-Hans" to "系统诊断与版本信息",
            "ja" to "システム診断とバージョン情報",
            "ko" to "시스템 진단 및 버전 정보",
            "th" to "ข้อมูลการวินิจฉัยและเวอร์ชัน"
        ),
        "table" to mapOf(
            "zh-Hant" to "表格",
            "en" to "Table",
            "zh-Hans" to "表格",
            "ja" to "テーブル",
            "ko" to "표",
            "th" to "ตาราง"
        ),
        "table_add_column" to mapOf(
            "zh-Hant" to "新增欄",
            "en" to "Add Column",
            "zh-Hans" to "新增列",
            "ja" to "列を追加",
            "ko" to "열 추가",
            "th" to "เพิ่มคอลัมน์"
        ),
        "table_add_row" to mapOf(
            "zh-Hant" to "新增列",
            "en" to "Add Row",
            "zh-Hans" to "新增行",
            "ja" to "行を追加",
            "ko" to "행 추가",
            "th" to "เพิ่มแถว"
        ),
        "table_delete_column" to mapOf(
            "zh-Hant" to "刪除欄",
            "en" to "Delete Column",
            "zh-Hans" to "删除列",
            "ja" to "列を削除",
            "ko" to "열 삭제",
            "th" to "ลบคอลัมน์"
        ),
        "table_delete_row" to mapOf(
            "zh-Hant" to "刪除列",
            "en" to "Delete Row",
            "zh-Hans" to "删除行",
            "ja" to "行を削除",
            "ko" to "행 삭제",
            "th" to "ลบแถว"
        ),
        "table_edit" to mapOf(
            "zh-Hant" to "編修表格",
            "en" to "Edit Table",
            "zh-Hans" to "编辑表格",
            "ja" to "表を編集",
            "ko" to "표 편집",
            "th" to "แก้ไขตาราง"
        ),
        "table_font_size" to mapOf(
            "zh-Hant" to "文字大小",
            "en" to "Font Size",
            "zh-Hans" to "文字大小",
            "ja" to "文字サイズ",
            "ko" to "글자 크기",
            "th" to "ขนาดตัวอักษร"
        ),
        "table_header_row" to mapOf(
            "zh-Hant" to "第一列為表頭",
            "en" to "Header Row",
            "zh-Hans" to "第一行为表头",
            "ja" to "先頭行を見出しに",
            "ko" to "머리글 행",
            "th" to "แถวหัวตาราง"
        ),
        "table_insert" to mapOf(
            "zh-Hant" to "插入表格",
            "en" to "Insert Table",
            "zh-Hans" to "插入表格",
            "ja" to "表を挿入",
            "ko" to "표 삽입",
            "th" to "แทรกตาราง"
        ),
        "table_merge_down" to mapOf(
            "zh-Hant" to "向下合併",
            "en" to "Merge Down",
            "zh-Hans" to "向下合并",
            "ja" to "下へ結合",
            "ko" to "아래쪽 병합",
            "th" to "ผสานลงล่าง"
        ),
        "table_merge_right" to mapOf(
            "zh-Hant" to "向右合併",
            "en" to "Merge Right",
            "zh-Hans" to "向右合并",
            "ja" to "右へ結合",
            "ko" to "오른쪽 병합",
            "th" to "ผสานไปทางขวา"
        ),
        "table_preview" to mapOf(
            "zh-Hant" to "預覽",
            "en" to "Preview",
            "zh-Hans" to "预览",
            "ja" to "プレビュー",
            "ko" to "미리보기",
            "th" to "ตัวอย่าง"
        ),
        "table_rows_cols" to mapOf(
            "zh-Hant" to "%@ 列 × %@ 欄",
            "en" to "%@ × %@",
            "zh-Hans" to "%@ 行 × %@ 列",
            "ja" to "%@ 行 × %@ 列",
            "ko" to "%@행 × %@열",
            "th" to "%@ แถว × %@ คอลัมน์"
        ),
        "table_studio" to mapOf(
            "zh-Hant" to "表格",
            "en" to "Table",
            "zh-Hans" to "表格",
            "ja" to "表",
            "ko" to "표",
            "th" to "ตาราง"
        ),
        "table_unmerge" to mapOf(
            "zh-Hant" to "取消合併",
            "en" to "Unmerge",
            "zh-Hans" to "取消合并",
            "ja" to "結合を解除",
            "ko" to "병합 해제",
            "th" to "ยกเลิกการผสาน"
        ),
        "table_update" to mapOf(
            "zh-Hant" to "更新表格",
            "en" to "Update Table",
            "zh-Hans" to "更新表格",
            "ja" to "表を更新",
            "ko" to "표 업데이트",
            "th" to "อัปเดตตาราง"
        ),
        "table_width" to mapOf(
            "zh-Hant" to "表格寬度",
            "en" to "Table Width",
            "zh-Hans" to "表格宽度",
            "ja" to "表の幅",
            "ko" to "표 너비",
            "th" to "ความกว้างตาราง"
        ),
        "tailscale_not_connected" to mapOf(
            "zh-Hant" to "Tailscale 未連線",
            "en" to "Tailscale Not Connected",
            "zh-Hans" to "Tailscale 未连接",
            "ja" to "Tailscale 未接続",
            "ko" to "Tailscale 연결 안 됨",
            "th" to "ไม่ได้เชื่อมต่อ Tailscale"
        ),
        "tailscale_p2p_ready" to mapOf(
            "zh-Hant" to "Tailscale 直連就緒 (%@)",
            "en" to "Tailscale P2P Ready (%@)",
            "zh-Hans" to "Tailscale 直连就绪 (%@)",
            "ja" to "Tailscale 直結準備完了 (%@)",
            "ko" to "Tailscale P2P 준비됨 (%@)",
            "th" to "Tailscale P2P พร้อมใช้งาน (%@)"
        ),
        "tap_to_place_pin" to mapOf(
            "zh-Hant" to "請在畫布上輕點以放置圖釘",
            "en" to "Tap on canvas to place pin",
            "zh-Hans" to "请在画布上轻点以放置图钉",
            "ja" to "キャンバスをタップしてピンを配置",
            "ko" to "캔버스를 탭하여 핀을 배치하세요",
            "th" to "แตะบนผืนผ้าใบเพื่อปักหมุด"
        ),
        "tap_to_type_hint" to mapOf(
            "zh-Hant" to "點選畫布任意處即可開始打字輸入",
            "en" to "Tap anywhere on the canvas to type",
            "zh-Hans" to "点击画布任意处即可开始打字输入",
            "ja" to "キャンバスをタップして文字を入力",
            "ko" to "캔버스를 탭하여 텍스트 입력",
            "th" to "แตะที่ใดก็ได้บนผืนผ้าใบเพื่อพิมพ์"
        ),
        "tape_delete" to mapOf(
            "zh-Hant" to "刪除膠帶",
            "en" to "Delete tape",
            "zh-Hans" to "删除胶带",
            "ja" to "テープを削除",
            "ko" to "테이프 삭제",
            "th" to "ลบเทป"
        ),
        "tape_toggle" to mapOf(
            "zh-Hant" to "翻開或遮回",
            "en" to "Reveal or cover",
            "zh-Hans" to "翻开或遮回",
            "ja" to "めくる／隠す",
            "ko" to "열기/가리기",
            "th" to "เปิดหรือปิดคลุม"
        ),
        "text_bold" to mapOf(
            "zh-Hant" to "粗體",
            "en" to "Bold",
            "zh-Hans" to "粗体",
            "ja" to "太字",
            "ko" to "굵게",
            "th" to "ตัวหนา"
        ),
        "text_color" to mapOf(
            "zh-Hant" to "文字顏色",
            "en" to "Text color",
            "zh-Hans" to "文字颜色",
            "ja" to "文字色",
            "ko" to "글자 색",
            "th" to "สีข้อความ"
        ),
        "text_default_content" to mapOf(
            "zh-Hant" to "請在此輸入文字...",
            "en" to "Type here…",
            "zh-Hans" to "请在此输入文字…",
            "ja" to "ここに入力…",
            "ko" to "여기에 입력…",
            "th" to "พิมพ์ที่นี่…"
        )
    )

    private fun part28(): Map<String, Map<String, String>> = mapOf(
        "text_italic" to mapOf(
            "zh-Hant" to "斜體",
            "en" to "Italic",
            "zh-Hans" to "斜体",
            "ja" to "斜体",
            "ko" to "기울임꼴",
            "th" to "ตัวเอียง"
        ),
        "text_placeholder" to mapOf(
            "zh-Hant" to "在此輸入文字…",
            "en" to "Type your text here…",
            "zh-Hans" to "在此输入文字…",
            "ja" to "ここにテキストを入力…",
            "ko" to "여기에 텍스트를 입력…",
            "th" to "พิมพ์ข้อความที่นี่…"
        ),
        "text_slash_bullet" to mapOf(
            "zh-Hant" to "項目清單 (•)",
            "en" to "Bulleted List (•)",
            "zh-Hans" to "项目清单 (•)",
            "ja" to "箇条書きリスト (•)",
            "ko" to "글머리 기호 목록 (•)",
            "th" to "รายการสัญลักษณ์แสดงหัวข้อย่อย (•)"
        ),
        "text_slash_h1" to mapOf(
            "zh-Hant" to "H1 標題",
            "en" to "Heading 1",
            "zh-Hans" to "H1 标题",
            "ja" to "見出し 1",
            "ko" to "제목 1",
            "th" to "หัวข้อ 1"
        ),
        "text_slash_h2" to mapOf(
            "zh-Hant" to "H2 次標題",
            "en" to "Heading 2",
            "zh-Hans" to "H2 次标题",
            "ja" to "見出し 2",
            "ko" to "제목 2",
            "th" to "หัวข้อ 2"
        ),
        "text_slash_quote" to mapOf(
            "zh-Hant" to "引言區塊 (│)",
            "en" to "Blockquote (│)",
            "zh-Hans" to "引言区块 (│)",
            "ja" to "引用ブロック (│)",
            "ko" to "인용 블록 (│)",
            "th" to "บล็อกคำพูด (│)"
        ),
        "text_slash_todo" to mapOf(
            "zh-Hant" to "待辦核取方塊 (☐)",
            "en" to "To-do Checkbox (☐)",
            "zh-Hans" to "待办复选框 (☐)",
            "ja" to "チェックボックス (☐)",
            "ko" to "체크박스 (☐)",
            "th" to "กล่องกาเครื่องหมาย (☐)"
        ),
        "text_strikethrough" to mapOf(
            "zh-Hant" to "刪除線",
            "en" to "Strikethrough",
            "zh-Hans" to "删除线",
            "ja" to "取り消し線",
            "ko" to "취소선",
            "th" to "ขีดทับ"
        ),
        "text_studio" to mapOf(
            "zh-Hant" to "文字排版",
            "en" to "Text Studio",
            "zh-Hans" to "文字排版",
            "ja" to "文字スタイル",
            "ko" to "텍스트 서식",
            "th" to "จัดรูปแบบข้อความ"
        ),
        "text_style" to mapOf(
            "zh-Hant" to "文字格式",
            "en" to "Text Style",
            "zh-Hans" to "文字格式",
            "ja" to "テキスト書式",
            "ko" to "텍스트 서식",
            "th" to "รูปแบบข้อความ"
        ),
        "text_tab_font" to mapOf(
            "zh-Hant" to "字體",
            "en" to "Font",
            "zh-Hans" to "字体",
            "ja" to "フォント",
            "ko" to "글꼴",
            "th" to "แบบอักษร"
        ),
        "text_tab_style" to mapOf(
            "zh-Hant" to "樣式",
            "en" to "Style",
            "zh-Hans" to "样式",
            "ja" to "スタイル",
            "ko" to "스타일",
            "th" to "สไตล์"
        ),
        "text_tab_symbols" to mapOf(
            "zh-Hant" to "符號",
            "en" to "Symbols",
            "zh-Hans" to "符号",
            "ja" to "記号",
            "ko" to "기호",
            "th" to "สัญลักษณ์"
        ),
        "text_underline" to mapOf(
            "zh-Hant" to "底線",
            "en" to "Underline",
            "zh-Hans" to "下划线",
            "ja" to "下線",
            "ko" to "밑줄",
            "th" to "ขีดเส้นใต้"
        ),
        "theme_aesthetic" to mapOf(
            "zh-Hant" to "美學視覺",
            "en" to "Aesthetic & Visual",
            "zh-Hans" to "美学视觉",
            "ja" to "美的・視覚デザイン",
            "ko" to "미학 및 시각 디자인",
            "th" to "สุนทรียศาสตร์และการมองเห็น"
        ),
        "theme_category" to mapOf(
            "zh-Hant" to "主題分類",
            "en" to "Theme",
            "zh-Hans" to "主题分类",
            "ja" to "テーマ",
            "ko" to "테마 분류",
            "th" to "หมวดธีม"
        ),
        "theme_digital" to mapOf(
            "zh-Hant" to "數位體驗",
            "en" to "Digital Experience",
            "zh-Hans" to "数字化体验",
            "ja" to "デジタル体験・UI",
            "ko" to "디지털 경험 및 UI",
            "th" to "ประสบการณ์ดิจิทัลและ UI"
        ),
        "theme_engineering" to mapOf(
            "zh-Hant" to "工程製程",
            "en" to "Engineering & Process",
            "zh-Hans" to "工程制程",
            "ja" to "工学・製造設計",
            "ko" to "엔지니어링 및 공정",
            "th" to "วิศวกรรมและกระบวนการผลิต"
        ),
        "theme_general" to mapOf(
            "zh-Hant" to "通用基礎",
            "en" to "General",
            "zh-Hans" to "通用基础",
            "ja" to "基本スタイル",
            "ko" to "기본 스타일",
            "th" to "ทั่วไป"
        ),
        "theme_method" to mapOf(
            "zh-Hant" to "筆記方法",
            "en" to "Note-taking Methods",
            "zh-Hans" to "笔记方法",
            "ja" to "ノート術",
            "ko" to "노트 기법",
            "th" to "วิธีจดบันทึก"
        ),
        "theme_palette_bauhaus" to mapOf(
            "zh-Hant" to "包浩斯復古工業",
            "en" to "Bauhaus Industrial",
            "zh-Hans" to "包豪斯复古工业",
            "ja" to "バウハウス インダストリアル",
            "ko" to "바우하우스 인더스트리얼",
            "th" to "เบาเฮาส์ อินดัสเทรียล"
        ),
        "theme_palette_cyberpunk" to mapOf(
            "zh-Hant" to "賽博霓虹",
            "en" to "Cyberpunk Neon",
            "zh-Hans" to "赛博霓虹",
            "ja" to "サイバーパンク ネオン",
            "ko" to "사이버펑크 네온",
            "th" to "ไซเบอร์พังก์ นีออน"
        ),
        "theme_palette_morandi" to mapOf(
            "zh-Hant" to "莫蘭迪高級灰",
            "en" to "Morandi Serene",
            "zh-Hans" to "莫兰迪高级灰",
            "ja" to "モランディ グレージュ",
            "ko" to "모란디 뮤트 톤",
            "th" to "โทนมอรันดี"
        ),
        "theme_palette_trend" to mapOf(
            "zh-Hant" to "Pantone 季節潮流色",
            "en" to "Pantone Trend Palette",
            "zh-Hans" to "Pantone 季节潮流色",
            "ja" to "パントン トレンドカラー",
            "ko" to "팬톤 트렌드 컬러",
            "th" to "พาเลตต์เทรนด์ Pantone"
        ),
        "theme_planner" to mapOf(
            "zh-Hant" to "規劃排程",
            "en" to "Planning & Schedule",
            "zh-Hans" to "规划排程",
            "ja" to "計画・スケジュール",
            "ko" to "계획·일정",
            "th" to "วางแผนและตาราง"
        ),
        "theme_tools" to mapOf(
            "zh-Hant" to "主題工具",
            "en" to "Theme Tools",
            "zh-Hans" to "主题工具",
            "ja" to "テーマ別ツール",
            "ko" to "테마 도구",
            "th" to "เครื่องมือธีม"
        ),
        "theme_tracker" to mapOf(
            "zh-Hant" to "清單追蹤",
            "en" to "Lists & Trackers",
            "zh-Hans" to "清单追踪",
            "ja" to "リスト・記録",
            "ko" to "목록·기록",
            "th" to "รายการและติดตาม"
        ),
        "thread_resolved" to mapOf(
            "zh-Hant" to "此討論已標記為已解決",
            "en" to "This thread is resolved",
            "zh-Hans" to "此讨论已标记为已解决",
            "ja" to "このスレッドは解決済みです",
            "ko" to "이 스레드는 해결됨으로 표시되었습니다",
            "th" to "การสนทนานี้ถูกทำเครื่องหมายว่าแก้ไขแล้ว"
        ),
        "thumbnail_larger" to mapOf(
            "zh-Hant" to "放大預覽",
            "en" to "Larger Previews",
            "zh-Hans" to "放大预览",
            "ja" to "プレビューを大きく",
            "ko" to "미리보기 확대",
            "th" to "ขยายภาพตัวอย่าง"
        ),
        "thumbnail_smaller" to mapOf(
            "zh-Hant" to "縮小預覽",
            "en" to "Smaller Previews",
            "zh-Hans" to "缩小预览",
            "ja" to "プレビューを小さく",
            "ko" to "미리보기 축소",
            "th" to "ย่อภาพตัวอย่าง"
        ),
        "tmpl_assignment_tracker" to mapOf(
            "zh-Hant" to "作業追蹤表",
            "en" to "Assignment Tracker",
            "zh-Hans" to "作业追踪表",
            "ja" to "課題トラッカー",
            "ko" to "과제 추적",
            "th" to "ติดตามงานที่ได้รับ"
        ),
        "tmpl_assignment_tracker_desc" to mapOf(
            "zh-Hant" to "科目、任務、期限與勾選框",
            "en" to "Subject, task, due date and a box to tick",
            "zh-Hans" to "科目、任务、期限与勾选框",
            "ja" to "科目・課題・期日・チェック欄",
            "ko" to "과목·과제·기한·체크",
            "th" to "วิชา งาน กำหนดส่ง และช่องติ๊ก"
        ),
        "tmpl_blank" to mapOf(
            "zh-Hant" to "空白紙張",
            "en" to "Blank Paper",
            "zh-Hans" to "空白纸张",
            "ja" to "白紙",
            "ko" to "빈 용지",
            "th" to "กระดาษเปล่า"
        ),
        "tmpl_blank_desc" to mapOf(
            "zh-Hant" to "適合自由手繪、心智圖與草稿",
            "en" to "Best for sketching, mind maps & free drafting",
            "zh-Hans" to "适合自由手绘、思维导图与草稿",
            "ja" to "自由な手描き、マインドマップ、スケッチに最適",
            "ko" to "자유 스케치, 마인드맵, 초안 작성에 최적",
            "th" to "เหมาะสำหรับการวาดภาพ แผนผังความคิด และร่างแบบอิสระ"
        ),
        "tmpl_blueprint" to mapOf(
            "zh-Hant" to "工程藍圖坐標紙",
            "en" to "Engineering Metric Blueprint",
            "zh-Hans" to "工程蓝图坐标纸",
            "ja" to "工学製図ブループリント",
            "ko" to "엔지니어링 청사진",
            "th" to "พิมพ์เขียววิศวกรรม"
        ),
        "tmpl_blueprint_desc" to mapOf(
            "zh-Hant" to "青藍精密毫米網格，含右下角標準 Title Block 標題欄",
            "en" to "Cyan metric millimeter grid with standard Title Block",
            "zh-Hans" to "青蓝精密毫米网格，含右下角标准 Title Block 标题栏",
            "ja" to "シアン系ミリ方眼と標準図面表題欄",
            "ko" to "시안 밀리미터 방안 및 표준 표제란",
            "th" to "กริดมิลลิเมตรสีฟ้าครามพร้อมบล็อกชื่อมาตรฐาน"
        ),
        "tmpl_challenge_21" to mapOf(
            "zh-Hant" to "21 天挑戰",
            "en" to "21-Day Challenge",
            "zh-Hans" to "21 天挑战",
            "ja" to "21日チャレンジ",
            "ko" to "21일 챌린지",
            "th" to "ชาเลนจ์ 21 วัน"
        ),
        "tmpl_challenge_21_desc" to mapOf(
            "zh-Hant" to "二十二個編號格：一個習慣，三週",
            "en" to "Twenty-two numbered boxes — one habit, three weeks",
            "zh-Hans" to "二十二个编号格：一个习惯，三周",
            "ja" to "番号つき22マス。ひとつの習慣を3週間",
            "ko" to "번호 22칸. 한 가지 습관, 3주",
            "th" to "ยี่สิบสองช่องมีเลขกำกับ"
        ),
        "tmpl_checklist_two" to mapOf(
            "zh-Hant" to "雙欄勾選清單",
            "en" to "Two-Column Checklist",
            "zh-Hans" to "双栏勾选清单",
            "ja" to "2列チェックリスト",
            "ko" to "2열 체크리스트",
            "th" to "เช็กลิสต์สองคอลัมน์"
        ),
        "tmpl_checklist_two_desc" to mapOf(
            "zh-Hant" to "一頁四十項，分成兩欄",
            "en" to "Forty items on one page, split into two columns",
            "zh-Hans" to "一页四十项，分成两栏",
            "ja" to "1ページに40項目、2列に分割",
            "ko" to "한 페이지 40항목, 2열",
            "th" to "สี่สิบรายการในหน้าเดียว"
        ),
        "tmpl_chore_roster" to mapOf(
            "zh-Hant" to "家事分工表",
            "en" to "Chore Roster",
            "zh-Hans" to "家事分工表",
            "ja" to "家事分担表",
            "ko" to "집안일 분담표",
            "th" to "ตารางงานบ้าน"
        ),
        "tmpl_chore_roster_desc" to mapOf(
            "zh-Hant" to "左側區域、上方星期",
            "en" to "Rooms down the side, days across the top",
            "zh-Hans" to "左侧区域、上方星期",
            "ja" to "左に場所、上に曜日",
            "ko" to "왼쪽 구역, 위쪽 요일",
            "th" to "พื้นที่ด้านซ้าย วันด้านบน"
        ),
        "tmpl_cornell" to mapOf(
            "zh-Hant" to "康乃爾樣板",
            "en" to "Cornell Notes",
            "zh-Hans" to "康奈尔模板",
            "ja" to "コーネル式",
            "ko" to "코넬 양식",
            "th" to "คอร์เนลล์"
        ),
        "tmpl_cornell_desc" to mapOf(
            "zh-Hant" to "左側提綱摘要、右側主體筆記、底部總結",
            "en" to "Cues on left, notes on right, summary at bottom",
            "zh-Hans" to "左侧提纲摘要、右侧主体笔记、底部总结",
            "ja" to "左にキーワード、右にノート本文、下にまとめ",
            "ko" to "왼쪽 핵심 요약, 오른쪽 본문, 하단 총괄 요약",
            "th" to "ประเด็นหลักด้านซ้าย โน้ตด้านขวา และสรุปด้านล่าง"
        ),
        "tmpl_cornell_grid" to mapOf(
            "zh-Hant" to "康乃爾（方格）",
            "en" to "Cornell (Grid)",
            "zh-Hans" to "康乃尔（方格）",
            "ja" to "コーネル（方眼）",
            "ko" to "코넬(모눈)",
            "th" to "คอร์เนล (ตาราง)"
        ),
        "tmpl_cornell_grid_desc" to mapOf(
            "zh-Hant" to "方格底紋上的康乃爾三區，適合圖解與公式",
            "en" to "Cornell zones over a grid, for diagrams and formulas",
            "zh-Hans" to "方格底纹上的康乃尔三区，适合图解与公式",
            "ja" to "方眼の上にコーネルの3区画。図や数式向き",
            "ko" to "모눈 위 코넬 3구역. 도표·수식에 적합",
            "th" to "โซนคอร์เนลบนตาราง เหมาะกับแผนภาพและสูตร"
        ),
        "tmpl_daily_schedule" to mapOf(
            "zh-Hant" to "日程表",
            "en" to "Daily Schedule",
            "zh-Hans" to "日程表",
            "ja" to "1日のスケジュール",
            "ko" to "하루 일정",
            "th" to "ตารางรายวัน"
        ),
        "tmpl_daily_schedule_desc" to mapOf(
            "zh-Hant" to "早到晚每半小時一列，另有事項欄",
            "en" to "Half-hour rows from morning to night, with a task column",
            "zh-Hans" to "早到晚每半小时一列，另有事项栏",
            "ja" to "朝から夜まで30分刻み＋予定欄",
            "ko" to "아침부터 밤까지 30분 간격 + 일정 칸",
            "th" to "ช่วงครึ่งชั่วโมงตลอดวัน"
        ),
        "tmpl_dot_grid_fine" to mapOf(
            "zh-Hant" to "極細點陣 (5mm)",
            "en" to "Fine Dot Grid (5mm)",
            "zh-Hans" to "极细点阵 (5mm)",
            "ja" to "極細ドット方眼 (5mm)",
            "ko" to "극세 도트 방안 (5mm)",
            "th" to "ดอทกริดละเอียด (5 มม.)"
        ),
        "tmpl_dot_grid_fine_desc" to mapOf(
            "zh-Hant" to "視覺藝術與版面設計師專用暖灰精密點陣",
            "en" to "Warm gray precision dots for visual & layout designers",
            "zh-Hans" to "视觉艺术与版面设计师专用暖灰精密点阵",
            "ja" to "視覚・レイアウトデザイナー向け精密ドット",
            "ko" to "시각 및 레이아웃 디자이너를 위한 온회색 정밀 도트",
            "th" to "ดอทกริดสีเทาอบอุ่นสำหรับนักออกแบบ"
        ),
        "tmpl_golden_ratio" to mapOf(
            "zh-Hant" to "黃金比例與三分構圖",
            "en" to "Golden Ratio & Thirds",
            "zh-Hans" to "黄金比例与三分构图",
            "ja" to "黄金比と三分分割構図",
            "ko" to "황금비 및 3분할 구도",
            "th" to "สัดส่วนทองคำและกฎสามส่วน"
        ),
        "tmpl_golden_ratio_desc" to mapOf(
            "zh-Hant" to "經典黃金分割線與九宮格參考輔助線",
            "en" to "Classical golden spiral & rule-of-thirds composition guides",
            "zh-Hans" to "经典黄金分割线与九宫格参考辅助线",
            "ja" to "黄金比螺旋と三分割構図ガイドライン",
            "ko" to "황금비 나선 및 3분할 가이드라인",
            "th" to "เส้นนำเกลียวทองคำและกฎสามส่วน"
        ),
        "tmpl_grid" to mapOf(
            "zh-Hant" to "方格點陣",
            "en" to "Grid & Dots",
            "zh-Hans" to "方格点阵",
            "ja" to "グリッド・ドット",
            "ko" to "모눈 점선",
            "th" to "ตารางจุด"
        ),
        "tmpl_grid_desc" to mapOf(
            "zh-Hant" to "幾何繪圖、公式推導與圖表繪製",
            "en" to "Geometry, formulas & precise diagrams",
            "zh-Hans" to "几何绘图、公式推导与图表绘制",
            "ja" to "幾何学、数式展開、精密図形描画",
            "ko" to "기하학, 공식 유도 및 정밀 도표 작성",
            "th" to "เรขาคณิต สูตร และแผนภาพที่แม่นยำ"
        ),
        "tmpl_habit_month" to mapOf(
            "zh-Hant" to "習慣追蹤",
            "en" to "Habit Tracker",
            "zh-Hans" to "习惯追踪",
            "ja" to "習慣トラッカー",
            "ko" to "습관 기록",
            "th" to "ติดตามนิสัย"
        ),
        "tmpl_habit_month_desc" to mapOf(
            "zh-Hant" to "31 天 × 14 項習慣格，另有回顧欄",
            "en" to "31 day columns by 14 habit rows, with room to reflect",
            "zh-Hans" to "31 天 × 14 项习惯格，另有回顾栏",
            "ja" to "31日×14習慣の格子と振り返り欄",
            "ko" to "31일 × 14습관 격자와 회고 칸",
            "th" to "31 วัน × 14 นิสัย"
        ),
        "tmpl_isometric" to mapOf(
            "zh-Hant" to "30° 等角立體軸測網格",
            "en" to "30° Isometric 3D Grid",
            "zh-Hans" to "30° 等角立体轴测网格",
            "ja" to "30° 等角投影立体グリッド",
            "ko" to "30° 등각 투영 그리드",
            "th" to "กริดไอโซเมตริก 30°"
        ),
        "tmpl_isometric_desc" to mapOf(
            "zh-Hant" to "機械構件、三維產品外觀與爆炸透視專用",
            "en" to "Dedicated for mechanism components, 3D products & exploded views",
            "zh-Hans" to "机械构件、三维产品外观与爆炸透视专用",
            "ja" to "機構部品、3D製品外観、分解斜視図専用",
            "ko" to "기구 부품, 3D 제품 외관 및 분해 투시도 전용",
            "th" to "สำหรับชิ้นส่วนกลไก ผลิตภัณฑ์ 3 มิติ และภาพระเบิด"
        ),
        "tmpl_kwl" to mapOf(
            "zh-Hant" to "KWL 表",
            "en" to "K-W-L Chart",
            "zh-Hans" to "KWL 表",
            "ja" to "KWL表",
            "ko" to "K-W-L 표",
            "th" to "ตาราง K-W-L"
        ),
        "tmpl_kwl_desc" to mapOf(
            "zh-Hant" to "已知／想知道／學到了，同一主題三欄",
            "en" to "Know / Want to know / Learned — three columns across one topic",
            "zh-Hans" to "已知／想知道／學到了，同一主題三栏",
            "ja" to "知っている／知りたい／学んだ の3列",
            "ko" to "안다/알고 싶다/배웠다 3열",
            "th" to "รู้แล้ว/อยากรู้/ได้เรียนรู้"
        ),
        "tmpl_lined" to mapOf(
            "zh-Hant" to "橫線筆記",
            "en" to "Ruled Lines",
            "zh-Hans" to "横线笔记",
            "ja" to "罫線ノート",
            "ko" to "줄 노트",
            "th" to "เส้นบรรทัด"
        ),
        "tmpl_lined_desc" to mapOf(
            "zh-Hant" to "課堂筆記、會議逐字與行文撰寫",
            "en" to "Lectures, meeting transcripts & writing",
            "zh-Hans" to "课堂笔记、会议逐字与文稿撰写",
            "ja" to "講義ノート、議事録、文章作成",
            "ko" to "강의 노트, 회의록 및 글쓰기",
            "th" to "บันทึกการบรรยาย รายงานการประชุม และการเขียน"
        ),
        "tmpl_mind_map" to mapOf(
            "zh-Hant" to "心智圖",
            "en" to "Mind Map",
            "zh-Hans" to "心智图",
            "ja" to "マインドマップ",
            "ko" to "마인드맵",
            "th" to "ผังความคิด"
        ),
        "tmpl_mind_map_desc" to mapOf(
            "zh-Hant" to "中心方塊與四向分支起點，點陣底紋",
            "en" to "A centre box and four branch stubs on a dot grid",
            "zh-Hans" to "中心方块与四向分支起点，点阵底纹",
            "ja" to "中心と4方向の枝の起点。点方眼つき",
            "ko" to "중앙 상자와 네 갈래 시작점, 점 모눈",
            "th" to "กล่องกลางและกิ่งสี่ทิศบนจุดตาราง"
        ),
        "tmpl_mobile_wireframe" to mapOf(
            "zh-Hant" to "行動端線框 (8pt Grid)",
            "en" to "Mobile Wireframe (8pt)",
            "zh-Hans" to "移动端线框 (8pt Grid)",
            "ja" to "モバイルワイヤーフレーム (8pt)",
            "ko" to "모바일 와이어프레임 (8pt)",
            "th" to "ไวร์เฟรมมือถือ (กริด 8pt)"
        ),
        "tmpl_mobile_wireframe_desc" to mapOf(
            "zh-Hant" to "內建雙手機螢幕輪廓框與 8pt 像素網格",
            "en" to "Dual phone frame outlines with 8pt pixel snap grid",
            "zh-Hans" to "内建双手机屏幕轮廓框与 8pt 像素网格",
            "ja" to "デュアルスマホ枠と8ptグリッド内蔵",
            "ko" to "듀얼 스마트폰 프레임 및 8pt 픽셀 그리드",
            "th" to "กรอบมือถือคู่พร้อมกริด 8pt"
        ),
        "tmpl_monthly_grid" to mapOf(
            "zh-Hant" to "月計畫",
            "en" to "Month at a Glance",
            "zh-Hans" to "月计划",
            "ja" to "月間プランナー",
            "ko" to "한 달 계획",
            "th" to "แผนรายเดือน"
        ),
        "tmpl_monthly_grid_desc" to mapOf(
            "zh-Hant" to "雙欄日期列，一個月一頁看完",
            "en" to "Two columns of dated rows — a whole month on one page",
            "zh-Hans" to "双栏日期列，一个月一页看完",
            "ja" to "日付欄つき2列。1か月が1ページに収まる",
            "ko" to "날짜 칸 2열. 한 달이 한 페이지에",
            "th" to "สองคอลัมน์พร้อมช่องวันที่"
        ),
        "tmpl_moodboard" to mapOf(
            "zh-Hant" to "情緒板與色卡矩陣",
            "en" to "Moodboard & Palette",
            "zh-Hans" to "情绪板与色卡矩阵",
            "ja" to "ムードボードと配色",
            "ko" to "무드보드 및 색상 매트릭스",
            "th" to "มู้ดบอร์ดและตารางจานสี"
        ),
        "tmpl_moodboard_desc" to mapOf(
            "zh-Hant" to "頂部 5 格代表色票位，中央大尺寸靈感畫布",
            "en" to "Top 5-color swatch strip with central inspiration canvas",
            "zh-Hans" to "顶部5格代表色票位，中央大尺寸灵感画布",
            "ja" to "上部に5色のカラースウォッチ、中央にインスピレーション空間",
            "ko" to "상단 5색 스와치 및 중앙 영감 캔버스",
            "th" to "แถบสี 5 สีด้านบนพร้อมผืนผ้าใบสร้างแรงบันดาลใจ"
        ),
        "tmpl_orthographic" to mapOf(
            "zh-Hant" to "三視圖與剖面範本",
            "en" to "Orthographic Multi-View",
            "zh-Hans" to "三视图与剖面范本",
            "ja" to "三面図と断面図テンプレート",
            "ko" to "3면도 및 단면도 템플릿",
            "th" to "แม่แบบภาพฉายสามด้าน"
        ),
        "tmpl_orthographic_desc" to mapOf(
            "zh-Hant" to "正視、俯視、側視與立體軸測四象限分區引導",
            "en" to "Front, Top, Side views & isometric quadrant guides",
            "zh-Hans" to "正视、俯视、侧视与立体轴测四象限分区引导",
            "ja" to "正面・平面・側面・立体の4象限分割ガイド",
            "ko" to "정면도, 평면도, 측면도 및 입체 4분면 가이드",
            "th" to "แบ่ง 4 ส่วน: ด้านหน้า ด้านบน ด้านข้าง และภาพสามมิติ"
        ),
        "tmpl_outline" to mapOf(
            "zh-Hant" to "大綱筆記",
            "en" to "Outline Method",
            "zh-Hans" to "大纲笔记",
            "ja" to "アウトライン",
            "ko" to "아웃라인",
            "th" to "โครงร่าง"
        ),
        "tmpl_outline_desc" to mapOf(
            "zh-Hant" to "三層縮排導引，不必先畫線就有層次",
            "en" to "Three indent guides — structure without drawing lines first",
            "zh-Hans" to "三层缩排导引，不必先画线就有层次",
            "ja" to "3段のインデント目安。線を引かずに階層が見える",
            "ko" to "3단 들여쓰기 안내선. 선을 긋지 않아도 구조가 보임",
            "th" to "เส้นนำย่อหน้าสามระดับ"
        ),
        "tmpl_project_timeline" to mapOf(
            "zh-Hant" to "專案時程",
            "en" to "Project Milestones",
            "zh-Hans" to "专案时程",
            "ja" to "プロジェクト工程",
            "ko" to "프로젝트 일정",
            "th" to "หมุดหมายโครงการ"
        ),
        "tmpl_project_timeline_desc" to mapOf(
            "zh-Hant" to "里程碑、負責人、期限三欄",
            "en" to "Milestone, owner and due date in three columns",
            "zh-Hans" to "里程碑、负责人、期限三栏",
            "ja" to "マイルストーン・担当・期日の3列",
            "ko" to "마일스톤·담당·기한 3열",
            "th" to "หมุดหมาย ผู้รับผิดชอบ กำหนดส่ง"
        ),
        "tmpl_qa" to mapOf(
            "zh-Hant" to "問答筆記",
            "en" to "Question & Answer",
            "zh-Hans" to "问答笔记",
            "ja" to "一問一答",
            "ko" to "질문과 답",
            "th" to "ถาม–ตอบ"
        ),
        "tmpl_qa_desc" to mapOf(
            "zh-Hant" to "六組問答：先寫問題，事後回想作答",
            "en" to "Six Q&A blocks — write the question first, answer from memory later",
            "zh-Hans" to "六组问答：先写问题，事后回想作答",
            "ja" to "6組の問答。先に問い、あとで思い出して答える",
            "ko" to "6개 문답 블록. 질문 먼저, 답은 나중에",
            "th" to "หกบล็อกถามตอบ"
        ),
        "tmpl_quadrant" to mapOf(
            "zh-Hant" to "四象限筆記",
            "en" to "Quadrant Method",
            "zh-Hans" to "四象限笔记",
            "ja" to "4象限メモ",
            "ko" to "4분면 노트",
            "th" to "บันทึกสี่ช่อง"
        ),
        "tmpl_quadrant_desc" to mapOf(
            "zh-Hant" to "重點、問題、決議、行動 —— 以下一步收尾的會議紀錄",
            "en" to "Points, questions, decisions, actions — meeting notes that end in a next step",
            "zh-Hans" to "重点、问题、决议、行动——以下一步收尾的会议纪录",
            "ja" to "要点・疑問・決定・行動。次の一手で終わる議事録",
            "ko" to "요점·질문·결정·실행. 다음 할 일로 끝나는 회의록",
            "th" to "ประเด็น คำถาม ข้อสรุป การกระทำ"
        )
    )

    private fun part29(): Map<String, Map<String, String>> = mapOf(
        "tmpl_study_planner" to mapOf(
            "zh-Hant" to "學習計畫",
            "en" to "Study Planner",
            "zh-Hans" to "学习计划",
            "ja" to "学習プランナー",
            "ko" to "학습 플래너",
            "th" to "แผนการเรียน"
        ),
        "tmpl_study_planner_desc" to mapOf(
            "zh-Hant" to "上方目標、科目列與勾選框、底部回顧",
            "en" to "Goals on top, subject rows with checkboxes, review at the bottom",
            "zh-Hans" to "上方目标、科目列与勾选框、底部回顾",
            "ja" to "上に目標、科目ごとの行、下に振り返り",
            "ko" to "위 목표, 과목별 행, 아래 회고",
            "th" to "เป้าหมาย รายวิชา และทบทวน"
        ),
        "tmpl_timeline_24h" to mapOf(
            "zh-Hant" to "24 小時時間軸",
            "en" to "24-Hour Timeline",
            "zh-Hans" to "24 小时时间轴",
            "ja" to "24時間タイムライン",
            "ko" to "24시간 타임라인",
            "th" to "ไทม์ไลน์ 24 ชม."
        ),
        "tmpl_timeline_24h_desc" to mapOf(
            "zh-Hant" to "上午下午並列，一整天一眼看完",
            "en" to "AM and PM side by side — a full day without scrolling",
            "zh-Hans" to "上午下午并列，一整天一眼看完",
            "ja" to "午前と午後を左右に。1日を一望",
            "ko" to "오전·오후를 좌우로. 하루 한눈에",
            "th" to "เช้าและบ่ายเคียงกัน"
        ),
        "tmpl_todo_list" to mapOf(
            "zh-Hant" to "待辦清單",
            "en" to "To-Do List",
            "zh-Hans" to "待办清单",
            "ja" to "ToDoリスト",
            "ko" to "할 일 목록",
            "th" to "รายการสิ่งที่ต้องทำ"
        ),
        "tmpl_todo_list_desc" to mapOf(
            "zh-Hant" to "二十行勾選框，沒有別的東西擋路",
            "en" to "Twenty checkbox rows, nothing else in the way",
            "zh-Hans" to "二十行勾选框，没有别的东西挡路",
            "ja" to "チェックボックス20行だけ",
            "ko" to "체크박스 20줄, 그뿐",
            "th" to "ยี่สิบบรรทัดพร้อมช่องติ๊ก"
        ),
        "tmpl_two_column" to mapOf(
            "zh-Hant" to "雙欄對照",
            "en" to "Two-Column Compare",
            "zh-Hans" to "双栏对照",
            "ja" to "2カラム対照",
            "ko" to "2단 대조",
            "th" to "สองคอลัมน์เทียบ"
        ),
        "tmpl_two_column_desc" to mapOf(
            "zh-Hant" to "左側原文、右側自己的話",
            "en" to "Source on the left, your own words on the right",
            "zh-Hans" to "左侧原文、右侧自己的话",
            "ja" to "左に原文、右に自分の言葉",
            "ko" to "왼쪽 원문, 오른쪽 내 말로",
            "th" to "ต้นฉบับซ้าย ความคิดขวา"
        ),
        "tmpl_user_journey" to mapOf(
            "zh-Hant" to "使用者旅程與流程圖",
            "en" to "User Journey & Flow",
            "zh-Hans" to "用户旅程与流程图",
            "ja" to "ユーザージャーニーとフロー",
            "ko" to "사용자 여정 및 플로우",
            "th" to "แผนผังการเดินทางของผู้ใช้"
        ),
        "tmpl_user_journey_desc" to mapOf(
            "zh-Hant" to "階段泳道、步驟節點與決策條件分支引導",
            "en" to "Swimlanes, step nodes & decision branch guides",
            "zh-Hans" to "阶段泳道、步骤节点与决策条件分支引导",
            "ja" to "スイムレーン、ステップノード、分岐条件ガイド",
            "ko" to "스윔레인, 단계 노드 및 의사결정 분기 가이드",
            "th" to "เลนว่ายน้ำ โหนดขั้นตอน และการแยกการตัดสินใจ"
        ),
        "tmpl_web_grid" to mapOf(
            "zh-Hant" to "響應式 Web 12 欄網格",
            "en" to "Responsive Web 12-Column",
            "zh-Hans" to "响应式 Web 12 栏网格",
            "ja" to "レスポンシブWeb 12カラム",
            "ko" to "반응형 웹 12컬럼",
            "th" to "กริดเว็บ 12 คอลัมน์"
        ),
        "tmpl_web_grid_desc" to mapOf(
            "zh-Hant" to "標準 12 欄格線、間距 (Gutter) 與安全邊距引導",
            "en" to "Standard 12-column layout, gutters & safe margins",
            "zh-Hans" to "标准 12 栏格线、间距与安全边距引导",
            "ja" to "標準12カラム、ガター、マージンレイアウト",
            "ko" to "표준 12컬럼, 거터 및 안전 여백 가이드",
            "th" to "เลย์เอาต์ 12 คอลัมน์มาตรฐานพร้อมระยะขอบ"
        ),
        "tmpl_weekly_columns" to mapOf(
            "zh-Hant" to "週計畫七欄",
            "en" to "Weekly Columns",
            "zh-Hans" to "周计划七栏",
            "ja" to "週間7列",
            "ko" to "주간 7열",
            "th" to "เจ็ดคอลัมน์รายสัปดาห์"
        ),
        "tmpl_weekly_columns_desc" to mapOf(
            "zh-Hant" to "週一到週日七欄，含橫線",
            "en" to "Seven day columns with ruled rows",
            "zh-Hans" to "周一到周日七栏，含横线",
            "ja" to "月曜から日曜までの7列と罫線",
            "ko" to "월~일 7열과 괘선",
            "th" to "เจ็ดคอลัมน์วันพร้อมเส้นบรรทัด"
        ),
        "todo_list" to mapOf(
            "zh-Hant" to "待辦事項清單",
            "en" to "To-do list",
            "zh-Hans" to "待办列表",
            "ja" to "To-Do リスト",
            "ko" to "할 일 목록",
            "th" to "รายการที่ต้องทำ"
        ),
        "toggle_border" to mapOf(
            "zh-Hant" to "邊框開關 (保留/刪除)",
            "en" to "Toggle Border (Keep/Remove)",
            "zh-Hans" to "边框开关 (保留/删除)",
            "ja" to "枠線の切替 (維持/削除)",
            "ko" to "테두리 전환 (유지/제거)",
            "th" to "สลับเส้นขอบ (เก็บ/ลบ)"
        ),
        "tool_airbrush" to mapOf(
            "zh-Hant" to "噴槍",
            "en" to "Airbrush",
            "zh-Hans" to "喷枪",
            "ja" to "エアブラシ",
            "ko" to "에어브러시",
            "th" to "แอร์บรัช"
        ),
        "tool_anchor_short" to mapOf(
            "zh-Hant" to "錨定",
            "en" to "Anchor",
            "zh-Hans" to "锚定",
            "ja" to "アンカー",
            "ko" to "앵커",
            "th" to "ยึดตำแหน่ง"
        ),
        "tool_ballpoint" to mapOf(
            "zh-Hant" to "原子筆",
            "en" to "Ballpoint",
            "zh-Hans" to "圆珠笔",
            "ja" to "ボールペン",
            "ko" to "볼펜",
            "th" to "ปากกาลูกลื่น"
        ),
        "tool_brush" to mapOf(
            "zh-Hant" to "毛筆",
            "en" to "Calligraphy Brush",
            "zh-Hans" to "毛笔",
            "ja" to "毛筆",
            "ko" to "붓",
            "th" to "พู่กัน"
        ),
        "tool_calligraphy" to mapOf(
            "zh-Hant" to "書法筆",
            "en" to "Calligraphy Pen",
            "zh-Hans" to "书法笔",
            "ja" to "カリグラフィーペン",
            "ko" to "캘리그래피 펜",
            "th" to "ปากกาคัดลายมือ"
        ),
        "tool_charcoal" to mapOf(
            "zh-Hant" to "炭筆",
            "en" to "Charcoal",
            "zh-Hans" to "炭笔",
            "ja" to "木炭",
            "ko" to "목탄",
            "th" to "ถ่าน"
        ),
        "tool_crayon" to mapOf(
            "zh-Hant" to "蠟筆",
            "en" to "Crayon",
            "zh-Hans" to "蜡笔",
            "ja" to "クレヨン",
            "ko" to "크레용",
            "th" to "สีเทียน"
        ),
        "tool_drafting" to mapOf(
            "zh-Hant" to "圖學筆組",
            "en" to "Drafting",
            "zh-Hans" to "图学笔组",
            "ja" to "製図",
            "ko" to "제도",
            "th" to "งานเขียนแบบ"
        ),
        "tool_eraser" to mapOf(
            "zh-Hant" to "橡皮擦",
            "en" to "Eraser",
            "zh-Hans" to "橡皮擦",
            "ja" to "消しゴム",
            "ko" to "지우개",
            "th" to "ยางลบ"
        ),
        "tool_fineliner" to mapOf(
            "zh-Hant" to "針筆",
            "en" to "Fineliner",
            "zh-Hans" to "针笔",
            "ja" to "ファインライナー",
            "ko" to "파인라이너",
            "th" to "ปากกาหัวเข็ม"
        ),
        "tool_highlighter" to mapOf(
            "zh-Hant" to "螢光筆",
            "en" to "Highlighter",
            "zh-Hans" to "荧光笔",
            "ja" to "蛍光ペン",
            "ko" to "형광펜",
            "th" to "ปากกาเน้นข้อความ"
        ),
        "tool_lasso" to mapOf(
            "zh-Hant" to "套索選取",
            "en" to "Lasso",
            "zh-Hans" to "套索选取",
            "ja" to "投げ縄",
            "ko" to "올가미",
            "th" to "บ่วงบาศก์"
        ),
        "tool_marker" to mapOf(
            "zh-Hant" to "麥克筆",
            "en" to "Marker",
            "zh-Hans" to "马克笔",
            "ja" to "マーカー",
            "ko" to "마커펜",
            "th" to "ปากกามาร์กเกอร์"
        ),
        "tool_masking_tape" to mapOf(
            "zh-Hant" to "膠帶",
            "en" to "Masking Tape",
            "zh-Hans" to "胶带",
            "ja" to "マスキングテープ",
            "ko" to "마스킹 테이프",
            "th" to "กระดาษกาว"
        ),
        "tool_oilpaint" to mapOf(
            "zh-Hant" to "油畫筆",
            "en" to "Oil Brush",
            "zh-Hans" to "油画笔",
            "ja" to "油彩筆",
            "ko" to "유화 붓",
            "th" to "พู่กันสีน้ำมัน"
        ),
        "tool_pen" to mapOf(
            "zh-Hant" to "鋼筆",
            "en" to "Pen",
            "zh-Hans" to "钢笔",
            "ja" to "ペン",
            "ko" to "만년필",
            "th" to "ปากกาหมึกซึม"
        ),
        "tool_pencil" to mapOf(
            "zh-Hant" to "鉛筆",
            "en" to "Pencil",
            "zh-Hans" to "铅笔",
            "ja" to "鉛筆",
            "ko" to "연필",
            "th" to "ดินสอ"
        ),
        "tool_radial_short" to mapOf(
            "zh-Hant" to "放射狀",
            "en" to "Radial",
            "zh-Hans" to "放射状",
            "ja" to "放射状",
            "ko" to "방사형",
            "th" to "รัศมี"
        ),
        "tool_text" to mapOf(
            "zh-Hant" to "文字排版",
            "en" to "Text Studio",
            "zh-Hans" to "文字排版",
            "ja" to "テキスト編集",
            "ko" to "텍스트 편집",
            "th" to "สตูดิโอข้อความ"
        ),
        "tool_watercolor" to mapOf(
            "zh-Hant" to "水彩筆",
            "en" to "Watercolor",
            "zh-Hans" to "水彩笔",
            "ja" to "水彩筆",
            "ko" to "수채화 붓",
            "th" to "พู่กันสีน้ำ"
        ),
        "toolbar_all_hidden" to mapOf(
            "zh-Hant" to "所有工具都已隱藏。畫布仍會沿用你最後選的那一支。",
            "en" to "Every tool is hidden. The canvas keeps the tool you were last using.",
            "zh-Hans" to "所有工具都已隐藏。画布仍会沿用你最后选的那一支。",
            "ja" to "すべてのツールが非表示です。キャンバスは最後に使ったツールのままです。",
            "ko" to "모든 도구가 숨겨졌습니다. 캔버스는 마지막에 쓰던 도구를 그대로 사용합니다.",
            "th" to "เครื่องมือทั้งหมดถูกซ่อนไว้ ผืนผ้าใบจะยังคงใช้เครื่องมือที่คุณใช้ล่าสุด"
        ),
        "toolbar_collapsed_hint" to mapOf(
            "zh-Hant" to "收合會把整列藏起來，只留下浮動的工具丸。",
            "en" to "Collapsed hides the bar entirely — only the floating tool bubble stays.",
            "zh-Hans" to "收合会把整列藏起来，只留下浮动的工具丸。",
            "ja" to "折りたたむとバー全体が消え、フローティングのツールバブルだけが残ります。",
            "ko" to "접으면 막대가 완전히 숨겨지고 떠 있는 도구 버블만 남습니다.",
            "th" to "การย่อเก็บจะซ่อนแถบทั้งหมด เหลือเพียงปุ่มเครื่องมือลอย"
        ),
        "toolbar_customize_hint" to mapOf(
            "zh-Hant" to "把用不到的工具關掉，剩下的順序不變。",
            "en" to "Turn off the tools you don't use. The rest keep their order.",
            "zh-Hans" to "把用不到的工具关掉，剩下的顺序不变。",
            "ja" to "使わないツールをオフにします。残りの並び順は変わりません。",
            "ko" to "사용하지 않는 도구를 끄세요. 나머지 순서는 그대로입니다.",
            "th" to "ปิดเครื่องมือที่ไม่ได้ใช้ ลำดับของที่เหลือจะไม่เปลี่ยน"
        ),
        "toolbar_labels_hint" to mapOf(
            "zh-Hant" to "關掉之後工具列只顯示圖示，放得下更多工具。",
            "en" to "Turned off, the toolbar shows icons only and fits more tools.",
            "zh-Hans" to "关掉之后工具栏只显示图标，放得下更多工具。",
            "ja" to "オフにするとアイコンのみになり、より多くのツールが収まります。",
            "ko" to "끄면 아이콘만 표시되어 더 많은 도구가 들어갑니다.",
            "th" to "ปิดแล้วแถบเครื่องมือจะแสดงเฉพาะไอคอน และใส่เครื่องมือได้มากขึ้น"
        ),
        "toolbar_place_bottom" to mapOf(
            "zh-Hant" to "下方",
            "en" to "Bottom",
            "zh-Hans" to "下方",
            "ja" to "下",
            "ko" to "아래",
            "th" to "ด้านล่าง"
        ),
        "toolbar_place_collapsed" to mapOf(
            "zh-Hant" to "收合",
            "en" to "Collapsed",
            "zh-Hans" to "收合",
            "ja" to "折りたたむ",
            "ko" to "접기",
            "th" to "ย่อเก็บ"
        ),
        "toolbar_place_left" to mapOf(
            "zh-Hant" to "左側",
            "en" to "Left",
            "zh-Hans" to "左侧",
            "ja" to "左",
            "ko" to "왼쪽",
            "th" to "ด้านซ้าย"
        ),
        "toolbar_place_right" to mapOf(
            "zh-Hant" to "右側",
            "en" to "Right",
            "zh-Hans" to "右侧",
            "ja" to "右",
            "ko" to "오른쪽",
            "th" to "ด้านขวา"
        ),
        "toolbar_place_top" to mapOf(
            "zh-Hant" to "上方",
            "en" to "Top",
            "zh-Hans" to "上方",
            "ja" to "上",
            "ko" to "위",
            "th" to "ด้านบน"
        ),
        "toolbar_placement" to mapOf(
            "zh-Hant" to "工具列的位置",
            "en" to "Where the toolbar sits",
            "zh-Hans" to "工具栏的位置",
            "ja" to "ツールバーの位置",
            "ko" to "도구 모음 위치",
            "th" to "ตำแหน่งแถบเครื่องมือ"
        ),
        "toolbar_placement_hint" to mapOf(
            "zh-Hant" to "擺在左側或右側，工具列就不會擋到你寫字的那隻手。",
            "en" to "Left or right keeps the toolbar out of your writing hand's way.",
            "zh-Hans" to "摆在左侧或右侧，工具栏就不会挡到你写字的那只手。",
            "ja" to "左右に置くと、書く手にツールバーが重なりません。",
            "ko" to "왼쪽이나 오른쪽에 두면 필기하는 손을 가리지 않습니다.",
            "th" to "วางไว้ซ้ายหรือขวาเพื่อไม่ให้แถบเครื่องมือบังมือที่เขียน"
        ),
        "toolbar_reset" to mapOf(
            "zh-Hant" to "還原預設工具列",
            "en" to "Restore Default Toolbar",
            "zh-Hans" to "还原默认工具栏",
            "ja" to "ツールバーを初期設定に戻す",
            "ko" to "기본 도구 모음으로 되돌리기",
            "th" to "คืนค่าแถบเครื่องมือเริ่มต้น"
        ),
        "toolbar_show_labels" to mapOf(
            "zh-Hant" to "顯示文字標籤",
            "en" to "Show text labels",
            "zh-Hans" to "显示文字标签",
            "ja" to "文字ラベルを表示",
            "ko" to "텍스트 레이블 표시",
            "th" to "แสดงป้ายข้อความ"
        ),
        "transcribe_audio" to mapOf(
            "zh-Hant" to "音訊轉文字",
            "en" to "Audio to Text",
            "zh-Hans" to "音频转文字",
            "ja" to "音声からテキストへ",
            "ko" to "음성을 텍스트로 변환",
            "th" to "แปลงเสียงเป็นข้อความ"
        ),
        "transcribe_audio_unreadable" to mapOf(
            "zh-Hant" to "無法讀取這段錄音（格式不支援或太長）。",
            "en" to "Could not read this recording (unsupported format or too long).",
            "zh-Hans" to "无法读取这段录音（格式不支持或太长）。",
            "ja" to "この録音を読み取れません（非対応の形式、または長すぎます）。",
            "ko" to "이 녹음을 읽을 수 없습니다(지원되지 않는 형식이거나 너무 깁니다).",
            "th" to "อ่านไฟล์บันทึกนี้ไม่ได้ (รูปแบบไม่รองรับหรือยาวเกินไป)"
        ),
        "transcribe_engine_unavailable" to mapOf(
            "zh-Hant" to "此版本未包含語音引擎。",
            "en" to "This build does not include the speech engine.",
            "zh-Hans" to "此版本未包含语音引擎。",
            "ja" to "このビルドには音声エンジンが含まれていません。",
            "ko" to "이 빌드에는 음성 엔진이 포함되어 있지 않습니다.",
            "th" to "บิลด์นี้ไม่มีเครื่องมือถอดเสียง"
        ),
        "transcribe_failed" to mapOf(
            "zh-Hant" to "轉錄失敗",
            "en" to "Transcription failed",
            "zh-Hans" to "转录失败",
            "ja" to "文字起こしに失敗しました",
            "ko" to "변환 실패",
            "th" to "การแปลงเสียงล้มเหลว"
        ),
        "transcribe_needs_model" to mapOf(
            "zh-Hant" to "端側轉錄需要先下載模型，請到設定下載。",
            "en" to "On-device transcription needs a model. Download it in Settings.",
            "zh-Hans" to "端侧转录需要先下载模型，请到设定下载。",
            "ja" to "端末内の文字起こしにはモデルが必要です。設定からダウンロードしてください。",
            "ko" to "기기 내 음성 인식에는 모델이 필요합니다. 설정에서 다운로드하세요.",
            "th" to "การถอดเสียงบนอุปกรณ์ต้องใช้โมเดล ดาวน์โหลดได้ในการตั้งค่า"
        ),
        "transcribe_no_speech" to mapOf(
            "zh-Hant" to "未偵測到清晰人聲語音",
            "en" to "No clear speech detected",
            "zh-Hans" to "未检测到清晰人声语音",
            "ja" to "明瞭な音声が検出されませんでした",
            "ko" to "선명한 음성이 감지되지 않았습니다",
            "th" to "ตรวจไม่พบเสียงพูดที่ชัดเจน"
        ),
        "transcribe_success" to mapOf(
            "zh-Hant" to "轉錄完成，已插入文字方塊",
            "en" to "Transcription complete, text box added",
            "zh-Hans" to "转录完成，已插入文本框",
            "ja" to "文字起こし完了、テキストボックスを追加しました",
            "ko" to "변환 완료, 텍스트 상자가 추가되었습니다",
            "th" to "แปลงข้อความเสร็จสิ้น เพิ่มกล่องข้อความแล้ว"
        ),
        "transcribing" to mapOf(
            "zh-Hant" to "正在轉錄文字…",
            "en" to "Transcribing audio…",
            "zh-Hans" to "正在转录文字…",
            "ja" to "文字起こし中…",
            "ko" to "텍스트 변환 중…",
            "th" to "กำลังแปลงเสียง…"
        ),
        "transcription_done" to mapOf(
            "zh-Hant" to "已完成",
            "en" to "Done",
            "zh-Hans" to "已完成",
            "ja" to "完了",
            "ko" to "완료",
            "th" to "เสร็จสิ้น"
        ),
        "transcription_ready" to mapOf(
            "zh-Hant" to "轉錄就緒",
            "en" to "Transcript ready",
            "zh-Hans" to "转录就绪",
            "ja" to "文字起こし完了",
            "ko" to "받아쓰기 준비됨",
            "th" to "ถอดเสียงพร้อมแล้ว"
        ),
        "transfer_failed" to mapOf(
            "zh-Hant" to "沒有任何頁面被轉移",
            "en" to "Nothing was transferred",
            "zh-Hans" to "没有任何页面被转移",
            "ja" to "何も移動しませんでした",
            "ko" to "아무것도 옮기지 않았습니다",
            "th" to "ไม่มีอะไรถูกย้าย"
        ),
        "transfer_no_pages" to mapOf(
            "zh-Hant" to "請先選取至少一頁",
            "en" to "Select at least one page first",
            "zh-Hans" to "请先选取至少一页",
            "ja" to "ページを1つ以上選んでください",
            "ko" to "페이지를 하나 이상 선택하세요",
            "th" to "เลือกอย่างน้อยหนึ่งหน้า"
        ),
        "transfer_same_notebook" to mapOf(
            "zh-Hant" to "同一本筆記內換順序請用「上移／下移一頁」",
            "en" to "Use Move Page Up/Down to reorder within a notebook",
            "zh-Hans" to "同一本笔记内换顺序请用「上移／下移一页」",
            "ja" to "同じノート内での並べ替えは「ページを上へ／下へ」",
            "ko" to "같은 노트 안에서는 ‘페이지 위로/아래로’를 쓰세요",
            "th" to "จัดลำดับในสมุดเดียวกันให้ใช้เลื่อนหน้าขึ้น/ลง"
        ),
        "transfer_would_empty_source" to mapOf(
            "zh-Hant" to "一本筆記至少要留一頁",
            "en" to "A notebook must keep at least one page",
            "zh-Hans" to "一本笔记至少要留一页",
            "ja" to "ノートには最低1ページ必要です",
            "ko" to "노트에는 최소 한 페이지가 있어야 합니다",
            "th" to "สมุดต้องเหลืออย่างน้อยหนึ่งหน้า"
        ),
        "trash_clock_pending" to mapOf(
            "zh-Hant" to "倒數將在下次同步後開始",
            "en" to "Countdown starts after the next sync",
            "zh-Hans" to "倒计时将在下次同步后开始",
            "ja" to "カウントダウンは次回の同期後に始まります",
            "ko" to "다음 동기화 후 카운트다운이 시작됩니다",
            "th" to "การนับถอยหลังจะเริ่มหลังการซิงค์ครั้งถัดไป"
        ),
        "trash_days_left" to mapOf(
            "zh-Hant" to "還剩 %@ 天",
            "en" to "%@ days left",
            "zh-Hans" to "还剩 %@ 天",
            "ja" to "残り%@日",
            "ko" to "%@일 남음",
            "th" to "เหลืออีก %@ วัน"
        ),
        "trash_delete_forever" to mapOf(
            "zh-Hant" to "永久刪除",
            "en" to "Delete Permanently",
            "zh-Hans" to "永久删除",
            "ja" to "完全に削除",
            "ko" to "영구 삭제",
            "th" to "ลบถาวร"
        ),
        "trash_delete_forever_confirm_message" to mapOf(
            "zh-Hant" to "「%@」將從此裝置刪除，且無法復原。",
            "en" to "“%@” will be removed from this device and can’t be recovered.",
            "zh-Hans" to "“%@”将从此设备中删除，且无法恢复。",
            "ja" to "「%@」はこのデバイスから削除され、元に戻せません。",
            "ko" to "“%@”이(가) 이 기기에서 삭제되며 복구할 수 없습니다.",
            "th" to "“%@” จะถูกลบออกจากอุปกรณ์นี้และไม่สามารถกู้คืนได้"
        ),
        "trash_delete_forever_confirm_title" to mapOf(
            "zh-Hant" to "要永久刪除嗎？",
            "en" to "Delete permanently?",
            "zh-Hans" to "要永久删除吗？",
            "ja" to "完全に削除しますか？",
            "ko" to "영구 삭제할까요?",
            "th" to "ลบถาวรหรือไม่?"
        ),
        "trash_empty" to mapOf(
            "zh-Hant" to "回收桶是空的",
            "en" to "The trash is empty",
            "zh-Hans" to "回收站是空的",
            "ja" to "ゴミ箱は空です",
            "ko" to "휴지통이 비어 있습니다",
            "th" to "ถังขยะว่างเปล่า"
        ),
        "trash_empty_action" to mapOf(
            "zh-Hant" to "清空回收桶",
            "en" to "Empty Trash",
            "zh-Hans" to "清空回收站",
            "ja" to "ゴミ箱を空にする",
            "ko" to "휴지통 비우기",
            "th" to "ล้างถังขยะ"
        ),
        "trash_empty_confirm_message" to mapOf(
            "zh-Hant" to "回收桶中的所有內容將從此裝置永久刪除。雲端副本會在你的其他裝置確認後刪除。",
            "en" to "Everything in the trash will be permanently deleted from this device. Cloud copies are removed once your other devices have confirmed.",
            "zh-Hans" to "回收站中的所有内容将从此设备永久删除。云端副本会在你的其他设备确认后删除。",
            "ja" to "ゴミ箱の中身はすべてこのデバイスから完全に削除されます。クラウド上のコピーは、他のデバイスが確認した後に削除されます。",
            "ko" to "휴지통의 모든 항목이 이 기기에서 영구 삭제됩니다. 클라우드 사본은 다른 기기에서 확인한 후 삭제됩니다.",
            "th" to "ทุกอย่างในถังขยะจะถูกลบถาวรจากอุปกรณ์นี้ สำเนาบนคลาวด์จะถูกลบหลังจากอุปกรณ์อื่นของคุณยืนยันแล้ว"
        ),
        "trash_empty_confirm_title" to mapOf(
            "zh-Hant" to "要清空回收桶嗎？",
            "en" to "Empty the trash?",
            "zh-Hans" to "要清空回收站吗？",
            "ja" to "ゴミ箱を空にしますか？",
            "ko" to "휴지통을 비울까요?",
            "th" to "ล้างถังขยะหรือไม่?"
        ),
        "trash_expired" to mapOf(
            "zh-Hant" to "已到期 — 即將永久刪除",
            "en" to "Expired — will be removed soon",
            "zh-Hans" to "已到期 — 即将永久删除",
            "ja" to "期限切れ — まもなく完全に削除されます",
            "ko" to "기간 만료 — 곧 영구 삭제됩니다",
            "th" to "หมดอายุแล้ว — เร็วๆ นี้จะถูกลบถาวร"
        ),
        "trash_keep_forever_row" to mapOf(
            "zh-Hant" to "保留到你手動刪除為止",
            "en" to "Kept until you remove it",
            "zh-Hans" to "保留到你手动删除为止",
            "ja" to "手動で削除するまで保持されます",
            "ko" to "직접 삭제할 때까지 보관됩니다",
            "th" to "เก็บไว้จนกว่าคุณจะลบเอง"
        ),
        "trash_restore" to mapOf(
            "zh-Hant" to "還原",
            "en" to "Restore",
            "zh-Hans" to "还原",
            "ja" to "元に戻す",
            "ko" to "복원",
            "th" to "กู้คืน"
        ),
        "trash_restored_notice" to mapOf(
            "zh-Hant" to "已還原「%@」",
            "en" to "Restored “%@”",
            "zh-Hans" to "已还原“%@”",
            "ja" to "「%@」を元に戻しました",
            "ko" to "“%@”을(를) 복원했습니다",
            "th" to "กู้คืน “%@” แล้ว"
        ),
        "trash_retention_days" to mapOf(
            "zh-Hant" to "%@ 天",
            "en" to "%@ days",
            "zh-Hans" to "%@ 天",
            "ja" to "%@日",
            "ko" to "%@일",
            "th" to "%@ วัน"
        ),
        "trash_retention_footer" to mapOf(
            "zh-Hant" to "超過這段時間後，已刪除的筆記本會從此裝置永久刪除，並在你的所有裝置確認後從雲端刪除。",
            "en" to "After this period, deleted notebooks are permanently removed from this device, and from the cloud once all your devices have confirmed.",
            "zh-Hans" to "超过这段时间后，已删除的笔记本会从此设备永久删除，并在你的所有设备确认后从云端删除。",
            "ja" to "この期間を過ぎると、削除したノートはこのデバイスから完全に削除され、すべてのデバイスが確認した後にクラウドからも削除されます。",
            "ko" to "이 기간이 지나면 삭제한 노트가 이 기기에서 영구 삭제되며, 모든 기기에서 확인한 후 클라우드에서도 삭제됩니다.",
            "th" to "เมื่อพ้นช่วงเวลานี้ สมุดบันทึกที่ลบจะถูกลบถาวรจากอุปกรณ์นี้ และจากคลาวด์หลังจากอุปกรณ์ทั้งหมดของคุณยืนยันแล้ว"
        ),
        "trash_retention_forever" to mapOf(
            "zh-Hant" to "直到我手動刪除",
            "en" to "Until I delete them",
            "zh-Hans" to "直到我手动删除",
            "ja" to "手動で削除するまで",
            "ko" to "직접 삭제할 때까지",
            "th" to "จนกว่าฉันจะลบเอง"
        ),
        "trash_retention_title" to mapOf(
            "zh-Hant" to "已刪除的筆記本保留時間",
            "en" to "Keep deleted notebooks for",
            "zh-Hans" to "已删除的笔记本保留时间",
            "ja" to "削除したノートを保持する期間",
            "ko" to "삭제한 노트를 보관할 기간",
            "th" to "เก็บสมุดบันทึกที่ลบไว้เป็นเวลา"
        )
    )

    private fun part30(): Map<String, Map<String, String>> = mapOf(
        "trash_title" to mapOf(
            "zh-Hant" to "回收桶",
            "en" to "Trash",
            "zh-Hans" to "回收站",
            "ja" to "ゴミ箱",
            "ko" to "휴지통",
            "th" to "ถังขยะ"
        ),
        "trash_waiting_devices" to mapOf(
            "zh-Hant" to "正在等待這些裝置確認：%@",
            "en" to "Waiting for these devices to confirm: %@",
            "zh-Hans" to "正在等待这些设备确认：%@",
            "ja" to "次のデバイスの確認を待っています: %@",
            "ko" to "다음 기기의 확인을 기다리는 중: %@",
            "th" to "กำลังรออุปกรณ์เหล่านี้ยืนยัน: %@"
        ),
        "txt_count" to mapOf(
            "zh-Hant" to "文字",
            "en" to "Text",
            "zh-Hans" to "文本",
            "ja" to "テキスト",
            "ko" to "텍스트",
            "th" to "ข้อความ"
        ),
        "type_mode_active" to mapOf(
            "zh-Hant" to "打字模式已就緒（畫筆已鎖定）",
            "en" to "Typing Mode Ready (Pen Locked)",
            "zh-Hans" to "打字模式已就绪（画笔已锁定）",
            "ja" to "入力モード準備完了（ペンロック）",
            "ko" to "타이핑 모드 준비 완료 (펜 잠금)",
            "th" to "โหมดการพิมพ์พร้อมใช้งาน (ล็อคปากกา)"
        ),
        "typing_mode" to mapOf(
            "zh-Hant" to "打字模式",
            "en" to "Typing",
            "zh-Hans" to "打字模式",
            "ja" to "タイピング",
            "ko" to "타이핑",
            "th" to "พิมพ์ข้อความ"
        ),
        "typing_mode_desc" to mapOf(
            "zh-Hant" to "打字排版模式：點按畫布隨點隨打，自由選取、移動與編輯物件",
            "en" to "Type & layout mode: Click canvas to type, select, move, and edit objects",
            "zh-Hans" to "文字排版模式：点按画布随点随打，自由选中、移动与编辑物件",
            "ja" to "タイピングモード：キャンバスをクリックして文字入力・オブジェクト操作",
            "ko" to "타이핑/편집 모드: 클릭하여 글쓰기 및 개체 선택·이동·편집",
            "th" to "โหมดพิมพ์และจัดหน้า: แตะผืนผ้าใบเพื่อพิมพ์ เลือก และย้ายวัตถุ"
        ),
        "ui_wireframe_tip" to mapOf(
            "zh-Hant" to "快速貼上標準 UI 元件線框",
            "en" to "Quickly insert standard UI wireframe components",
            "zh-Hans" to "快速贴上标准 UI 组件线框",
            "ja" to "標準UIワイヤーフレームを素早く配置",
            "ko" to "표준 UI 와이어프레임 컴포넌트 빠른 삽입",
            "th" to "แทรกไวร์เฟรมคอมโพเนนต์ UI มาตรฐานอย่างรวดเร็ว"
        ),
        "undo" to mapOf(
            "zh-Hant" to "復原",
            "en" to "Undo",
            "zh-Hans" to "撤销",
            "ja" to "取り消す",
            "ko" to "실행 취소",
            "th" to "เลิกทำ"
        ),
        "undo_desc" to mapOf(
            "zh-Hant" to "復原上一步操作或筆跡",
            "en" to "Undo previous drawing or edit action",
            "zh-Hans" to "撤销上一步操作或笔画",
            "ja" to "直前の操作を取り消す",
            "ko" to "이전 작업 실행 취소",
            "th" to "เลิกทำการกระทำก่อนหน้า"
        ),
        "unfiled_notes" to mapOf(
            "zh-Hant" to "未分類檔案",
            "en" to "Unfiled Notes",
            "zh-Hans" to "未分类文件",
            "ja" to "未分類ノート",
            "ko" to "미분류 노트",
            "th" to "บันทึกที่ไม่ได้จัดหมวดหมู่"
        ),
        "unhide_items" to mapOf(
            "zh-Hant" to "重置隱藏項目",
            "en" to "Reset Hidden",
            "zh-Hans" to "重置隐藏项",
            "ja" to "非表示を解除",
            "ko" to "숨김 초기화",
            "th" to "รีเซ็ตที่ซ่อน"
        ),
        "unlock_desc" to mapOf(
            "zh-Hant" to "輸入你加密時設定的密碼。",
            "en" to "Enter the passphrase you chose when you encrypted it.",
            "zh-Hans" to "输入你加密时设置的密码。",
            "ja" to "暗号化したときに設定したパスフレーズを入力してください。",
            "ko" to "암호화할 때 설정한 암호를 입력하세요.",
            "th" to "ป้อนรหัสผ่านที่คุณตั้งไว้ตอนเข้ารหัส"
        ),
        "unlock_recovery_prompt" to mapOf(
            "zh-Hant" to "輸入全部 24 個詞，以空白分隔",
            "en" to "Type all 24 words, separated by spaces",
            "zh-Hans" to "输入全部 24 个词，以空格分隔",
            "ja" to "24 個の単語をすべてスペース区切りで入力してください",
            "ko" to "24개 단어를 모두 공백으로 구분해 입력하세요",
            "th" to "พิมพ์ครบทั้ง 24 คำ คั่นด้วยเว้นวรรค"
        ),
        "unlock_recovery_unavailable" to mapOf(
            "zh-Hant" to "這本筆記是在復原碼還不能解鎖的版本建立的。它的復原碼從來沒有被用來包住金鑰 —— 只有密碼開得了。",
            "en" to "This notebook was created before recovery codes could unlock anything. Its recovery code was never used to wrap the key — only the passphrase opens it.",
            "zh-Hans" to "这本笔记是在恢复码还不能解锁的版本建立的。它的恢复码从来没有被用来包住密钥 —— 只有密码开得了。",
            "ja" to "このノートは、復元コードでロック解除できない時期に作成されました。復元コードは鍵の保護に使われていません —— パスフレーズでのみ開けます。",
            "ko" to "이 노트는 복구 코드로 잠금 해제할 수 없던 버전에서 만들어졌습니다. 복구 코드는 키를 감싸는 데 쓰인 적이 없습니다 —— 암호로만 열 수 있습니다.",
            "th" to "สมุดบันทึกนี้สร้างขึ้นก่อนที่รหัสกู้คืนจะปลดล็อกได้ รหัสกู้คืนไม่เคยถูกใช้ห่อหุ้มกุญแจ —— เปิดได้ด้วยรหัสผ่านเท่านั้น"
        ),
        "unlock_slow_hint" to mapOf(
            "zh-Hant" to "這會花幾秒鐘，是刻意的 —— 正是它讓別人猜你的密碼變得昂貴。",
            "en" to "This takes a few seconds on purpose — it is what makes guessing your passphrase expensive.",
            "zh-Hans" to "这会花几秒钟，是刻意的 —— 正是它让别人猜你的密码变得昂贵。",
            "ja" to "数秒かかるのは意図的です —— パスフレーズの総当たりを高くつくものにしています。",
            "ko" to "몇 초 걸리는 것은 의도적입니다 —— 암호를 추측하는 비용을 크게 만듭니다.",
            "th" to "ใช้เวลาสองสามวินาทีโดยตั้งใจ —— นี่คือสิ่งที่ทำให้การเดารหัสผ่านมีต้นทุนสูง"
        ),
        "unlock_title" to mapOf(
            "zh-Hant" to "這本筆記已上鎖",
            "en" to "This notebook is locked",
            "zh-Hans" to "这本笔记已上锁",
            "ja" to "このノートはロックされています",
            "ko" to "이 노트는 잠겨 있습니다",
            "th" to "สมุดบันทึกนี้ถูกล็อกอยู่"
        ),
        "unlock_use_passphrase" to mapOf(
            "zh-Hant" to "改用密碼",
            "en" to "Use the passphrase instead",
            "zh-Hans" to "改用密码",
            "ja" to "パスフレーズを使う",
            "ko" to "암호 사용",
            "th" to "ใช้รหัสผ่านแทน"
        ),
        "unlock_use_recovery" to mapOf(
            "zh-Hant" to "忘記了？改用復原碼",
            "en" to "Forgot it? Use your recovery code",
            "zh-Hans" to "忘记了？改用恢复码",
            "ja" to "忘れた場合は復元コードを使う",
            "ko" to "잊으셨나요? 복구 코드 사용",
            "th" to "ลืมรหัสผ่าน? ใช้รหัสกู้คืน"
        ),
        "unlock_working" to mapOf(
            "zh-Hant" to "解鎖中…",
            "en" to "Unlocking…",
            "zh-Hans" to "解锁中…",
            "ja" to "ロック解除中…",
            "ko" to "잠금 해제 중…",
            "th" to "กำลังปลดล็อก…"
        ),
        "unlock_wrong_recovery" to mapOf(
            "zh-Hant" to "這組復原碼開不了這本筆記",
            "en" to "That recovery code does not open this notebook",
            "zh-Hans" to "这组恢复码开不了这本笔记",
            "ja" to "この復元コードではこのノートを開けません",
            "ko" to "이 복구 코드로는 이 노트를 열 수 없습니다",
            "th" to "รหัสกู้คืนนี้เปิดสมุดบันทึกนี้ไม่ได้"
        ),
        "untitled_note" to mapOf(
            "zh-Hant" to "未命名筆記",
            "en" to "Untitled Note",
            "zh-Hans" to "未命名笔记",
            "ja" to "無題のノート",
            "ko" to "제목 없는 노트",
            "th" to "บันทึกที่ไม่มีชื่อ"
        ),
        "user_manual" to mapOf(
            "zh-Hant" to "操作手冊",
            "en" to "User Manual",
            "zh-Hans" to "操作手册",
            "ja" to "操作マニュアル",
            "ko" to "사용 설명서",
            "th" to "คู่มือการใช้งาน"
        ),
        "user_manual_desc" to mapOf(
            "zh-Hant" to "逐步教學，每一章都配實機截圖",
            "en" to "Step-by-step chapters, each with real screenshots",
            "zh-Hans" to "逐步教程，每一章都配实机截图",
            "ja" to "手順ごとの各章に実機のスクリーンショット付き",
            "ko" to "단계별 각 장마다 실제 화면 스크린샷 제공",
            "th" to "บทเรียนทีละขั้น พร้อมภาพหน้าจอจริงในทุกบท"
        ),
        "user_profile" to mapOf(
            "zh-Hant" to "個人基本資訊",
            "en" to "Profile Information",
            "zh-Hans" to "个人基本信息",
            "ja" to "プロフィール情報",
            "ko" to "프로필 정보",
            "th" to "ข้อมูลส่วนตัว"
        ),
        "version_number" to mapOf(
            "zh-Hant" to "版本號",
            "en" to "Version",
            "zh-Hans" to "版本号",
            "ja" to "バージョン",
            "ko" to "버전",
            "th" to "เวอร์ชัน"
        ),
        "voice_connected" to mapOf(
            "zh-Hant" to "連線中",
            "en" to "Connected",
            "zh-Hans" to "连线中",
            "ja" to "接続中",
            "ko" to "연결됨",
            "th" to "เชื่อมต่ออยู่"
        ),
        "voice_disconnected" to mapOf(
            "zh-Hant" to "已中斷",
            "en" to "Disconnected",
            "zh-Hans" to "已中断",
            "ja" to "切断されました",
            "ko" to "연결 끊김",
            "th" to "ตัดการเชื่อมต่อแล้ว"
        ),
        "wd_a4_layout" to mapOf(
            "zh-Hant" to "A4 標準版面 · 100%",
            "en" to "A4 layout · 100%",
            "zh-Hans" to "A4 标准版面 · 100%",
            "ja" to "A4 レイアウト · 100%",
            "ko" to "A4 레이아웃 · 100%",
            "th" to "เลย์เอาต์ A4 · 100%"
        ),
        "wd_add_table" to mapOf(
            "zh-Hant" to "＋表格",
            "en" to "+ Table",
            "zh-Hans" to "＋表格",
            "ja" to "＋表",
            "ko" to "＋표",
            "th" to "＋ตาราง"
        ),
        "wd_char_count" to mapOf(
            "zh-Hant" to "字數：%@ 字元",
            "en" to "%@ characters",
            "zh-Hans" to "字数：%@ 字符",
            "ja" to "文字数：%@ 文字",
            "ko" to "글자 수: %@자",
            "th" to "จำนวนอักขระ: %@"
        ),
        "wd_clear_format" to mapOf(
            "zh-Hant" to "清除格式",
            "en" to "Clear formatting",
            "zh-Hans" to "清除格式",
            "ja" to "書式をクリア",
            "ko" to "서식 지우기",
            "th" to "ล้างการจัดรูปแบบ"
        ),
        "wd_editing_ink_mode" to mapOf(
            "zh-Hant" to "編輯中（工具列已切到手繪）",
            "en" to "Editing (the toolbar switched to handwriting)",
            "zh-Hans" to "编辑中（工具栏已切到手绘）",
            "ja" to "編集中（ツールバーは手書きに切り替わっています）",
            "ko" to "편집 중(도구 막대가 필기로 전환됨)",
            "th" to "กำลังแก้ไข (แถบเครื่องมือสลับเป็นลายมือแล้ว)"
        ),
        "wd_highlight_color" to mapOf(
            "zh-Hant" to "螢光色",
            "en" to "Highlight colour",
            "zh-Hans" to "荧光色",
            "ja" to "蛍光色",
            "ko" to "형광색",
            "th" to "สีไฮไลต์"
        ),
        "wd_ink_block" to mapOf(
            "zh-Hant" to "手繪區塊",
            "en" to "Handwriting block",
            "zh-Hans" to "手绘区块",
            "ja" to "手書きブロック",
            "ko" to "필기 블록",
            "th" to "บล็อกลายมือ"
        ),
        "wd_inline_canvas" to mapOf(
            "zh-Hant" to "文件內的手繪畫布",
            "en" to "Handwriting canvas inside the document",
            "zh-Hans" to "文档内的手绘画布",
            "ja" to "書類内の手書きキャンバス",
            "ko" to "문서 안의 필기 캔버스",
            "th" to "ผืนผ้าใบลายมือในเอกสาร"
        ),
        "wd_insert_divider" to mapOf(
            "zh-Hant" to "插入分隔線",
            "en" to "Insert divider",
            "zh-Hans" to "插入分隔线",
            "ja" to "区切り線を挿入",
            "ko" to "구분선 삽입",
            "th" to "แทรกเส้นคั่น"
        ),
        "wd_insert_divider_desc" to mapOf(
            "zh-Hant" to "在文件中插入整行水平分隔線",
            "en" to "Insert horizontal divider line in text document",
            "zh-Hans" to "在文档中插入整行水平分隔线",
            "ja" to "テキストドキュメントに水平区切り線を挿入",
            "ko" to "문서에 수평 구분선 삽입",
            "th" to "แทรกเส้นคั่นแนวนอนในเอกสาร"
        ),
        "wd_insert_inline_canvas" to mapOf(
            "zh-Hant" to "插入文件內手繪畫布",
            "en" to "Insert a handwriting canvas",
            "zh-Hans" to "插入文档内手绘画布",
            "ja" to "手書きキャンバスを挿入",
            "ko" to "필기 캔버스 삽입",
            "th" to "แทรกผืนผ้าใบลายมือ"
        ),
        "wd_placeholder" to mapOf(
            "zh-Hant" to "在這裡輸入文件內容…",
            "en" to "Type the document here…",
            "zh-Hans" to "在这里输入文档内容…",
            "ja" to "ここに書類の内容を入力…",
            "ko" to "여기에 문서 내용을 입력하세요…",
            "th" to "พิมพ์เนื้อหาเอกสารที่นี่…"
        ),
        "wd_tap_to_draw" to mapOf(
            "zh-Hant" to "點這裡或用觸控筆，直接在文件裡手寫推導",
            "en" to "Tap here, or use a stylus, to write directly inside the document",
            "zh-Hans" to "点这里或用触控笔，直接在文档里手写推导",
            "ja" to "ここをタップするか、スタイラスで書類に直接手書きできます",
            "ko" to "여기를 탭하거나 스타일러스로 문서 안에 바로 필기하세요",
            "th" to "แตะที่นี่หรือใช้ปากกาสไตลัสเพื่อเขียนในเอกสารได้ทันที"
        ),
        "whisper_downloading" to mapOf(
            "zh-Hant" to "下載中...",
            "en" to "Downloading…",
            "zh-Hans" to "下载中…",
            "ja" to "ダウンロード中…",
            "ko" to "다운로드 중…",
            "th" to "กำลังดาวน์โหลด…"
        ),
        "whisper_downloading_status" to mapOf(
            "zh-Hant" to "Whisper 模型下載中：%@",
            "en" to "Downloading Whisper model: %@",
            "zh-Hans" to "Whisper 模型下载中：%@",
            "ja" to "Whisper モデルをダウンロード中：%@",
            "ko" to "Whisper 모델 다운로드 중: %@",
            "th" to "กำลังดาวน์โหลดโมเดล Whisper: %@"
        ),
        "whisper_import_failed" to mapOf(
            "zh-Hant" to "匯入失敗：%@",
            "en" to "Import failed: %@",
            "zh-Hans" to "导入失败：%@",
            "ja" to "読み込みに失敗しました：%@",
            "ko" to "가져오기 실패: %@",
            "th" to "นำเข้าไม่สำเร็จ: %@"
        ),
        "whisper_import_ok" to mapOf(
            "zh-Hant" to "成功匯入 Whisper 離線模型！",
            "en" to "Whisper offline model imported.",
            "zh-Hans" to "成功导入 Whisper 离线模型！",
            "ja" to "Whisper オフラインモデルを読み込みました。",
            "ko" to "Whisper 오프라인 모델을 가져왔습니다.",
            "th" to "นำเข้าโมเดล Whisper แบบออฟไลน์สำเร็จ"
        ),
        "whisper_pick_failed" to mapOf(
            "zh-Hant" to "選取檔案失敗：%@",
            "en" to "Could not select the file: %@",
            "zh-Hans" to "选取文件失败：%@",
            "ja" to "ファイルを選択できませんでした：%@",
            "ko" to "파일을 선택하지 못했습니다: %@",
            "th" to "เลือกไฟล์ไม่สำเร็จ: %@"
        ),
        "wireframe_button" to mapOf(
            "zh-Hant" to "主要行動按鈕 (CTA)",
            "en" to "Primary action button (CTA)",
            "zh-Hans" to "主要行动按钮 (CTA)",
            "ja" to "主要アクションボタン（CTA）",
            "ko" to "주요 행동 버튼 (CTA)",
            "th" to "ปุ่มหลัก (CTA)"
        ),
        "wireframe_card" to mapOf(
            "zh-Hant" to "內容資訊卡片",
            "en" to "Content card",
            "zh-Hans" to "内容信息卡片",
            "ja" to "コンテンツカード",
            "ko" to "콘텐츠 카드",
            "th" to "การ์ดเนื้อหา"
        ),
        "wireframe_input" to mapOf(
            "zh-Hant" to "搜尋輸入文字框",
            "en" to "Search input field",
            "zh-Hans" to "搜索输入文本框",
            "ja" to "検索入力フィールド",
            "ko" to "검색 입력 필드",
            "th" to "ช่องค้นหา"
        ),
        "wireframe_kit" to mapOf(
            "zh-Hant" to "UI 原型線框",
            "en" to "UI Wireframes",
            "zh-Hans" to "UI 原型线框",
            "ja" to "UI ワイヤーフレーム",
            "ko" to "UI 와이어프레임",
            "th" to "ไวร์เฟรม UI"
        ),
        "wireframe_modal" to mapOf(
            "zh-Hant" to "對話框彈窗 (Modal)",
            "en" to "Modal dialog",
            "zh-Hans" to "对话框弹窗 (Modal)",
            "ja" to "モーダルダイアログ",
            "ko" to "모달 대화상자",
            "th" to "กล่องโต้ตอบแบบโมดัล"
        ),
        "wireframe_navbar" to mapOf(
            "zh-Hant" to "行動端頂部導航列",
            "en" to "Mobile top nav bar",
            "zh-Hans" to "移动端顶部导航栏",
            "ja" to "モバイル ナビゲーションバー",
            "ko" to "모바일 상단 내비게이션 바",
            "th" to "แถบนำทางด้านบนบนมือถือ"
        ),
        "wireframe_tabbar" to mapOf(
            "zh-Hant" to "底部五分頁 TabBar",
            "en" to "Bottom tab bar (5 tabs)",
            "zh-Hans" to "底部五分页 TabBar",
            "ja" to "ボトムタブバー（5 タブ）",
            "ko" to "하단 탭 바 (5개 탭)",
            "th" to "แถบแท็บด้านล่าง (5 แท็บ)"
        ),
        "word_studio" to mapOf(
            "zh-Hant" to "Word文字編修",
            "en" to "Word Text Studio",
            "zh-Hans" to "Word文字编修",
            "ja" to "文書テキスト編集",
            "ko" to "워드 텍스트 편집",
            "th" to "การแก้ไขข้อความ Word"
        ),
        "word_studio_desc" to mapOf(
            "zh-Hant" to "打開字型、字級、段落與版面樣式面板",
            "en" to "Open typography styling and document studio inspector",
            "zh-Hans" to "打开字体、字号、段落与版式调色面板",
            "ja" to "テキスト書式・タイポグラフィ編集パネルを開く",
            "ko" to "텍스트 서식 및 서체 편집 스튜디오 열기",
            "th" to "เปิดแผงจัดรูปแบบข้อความและการจัดพิมพ์"
        ),
        "word_style_body" to mapOf(
            "zh-Hant" to "本文",
            "en" to "Body",
            "zh-Hans" to "正文",
            "ja" to "本文",
            "ko" to "본문",
            "th" to "เนื้อหา"
        ),
        "word_table_label" to mapOf(
            "zh-Hant" to "表格（%1@ × %2@）",
            "en" to "Table (%1@ × %2@)",
            "zh-Hans" to "表格（%1@ × %2@）",
            "ja" to "表（%1@ × %2@）",
            "ko" to "표 (%1@ × %2@)",
            "th" to "ตาราง (%1@ × %2@)"
        )
    )

    /** 取字串：找不到語系就退回英文，再退回繁中，最後回傳 key 本身。 */
    fun localized(key: String, language: String): String {
        val entry = table[key] ?: return key
        return entry[language] ?: entry["en"] ?: entry["zh-Hant"] ?: key
    }
}
